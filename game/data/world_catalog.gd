class_name Gen2WorldCatalog
extends RefCounted

## Every site the cartridge hands something out at, by an id that does not move,
## derived from the cache into a sidecar; a patch changes a field of a row, never
## the script behind it.

const KIND_STARTER: StringName = &"starter"
const KIND_GIFT: StringName = &"gift"
const KIND_STATIC: StringName = &"static"
const KIND_TRADE: StringName = &"trade"
const KIND_PRIZE: StringName = &"prize"
const KIND_ITEM: StringName = &"item"
const KIND_BADGE: StringName = &"badge"
const KIND_SHOP: StringName = &"shop"
## Also the id's own kind nibble, so the order is part of the id and adding a
## kind at the end cannot renumber the ones before it.
const KINDS: Array[StringName] = [
	KIND_STARTER, KIND_GIFT, KIND_STATIC, KIND_TRADE, KIND_PRIZE, KIND_ITEM,
	KIND_BADGE, KIND_SHOP,
]

## `id = kind << 40 | bank << 24 | absolute address`, one per site however many
## blobs overlap it. A map EVENT packs group, number and index behind
## [constant ID_EVENT_BIT].
const ID_KIND_SHIFT: int = 40
const ID_BANK_SHIFT: int = 24
const ID_ADDRESS_MASK: int = 0xFFFFFF
const ID_EVENT_BIT: int = 0x800000

## `ObjectEventTypeArray.itemball`, and `BGEVENT_ITEM` for one under a tile.
const OBJECT_TYPE_ITEMBALL: int = Gen2WorldObject.OBJECTTYPE_ITEMBALL
const BGEVENT_ITEM: int = Gen2WorldAPI.BGEVENT_ITEM

## The guard against a decode that runs away.
const MAX_SCRIPT_COMMANDS: int = 4096

## A cached script is a 512-byte window mostly past its end; the Game Corner's
## vendor, the busiest shape, is five routines.
const MAX_ROUTINES: int = 16

## The sidecar's shape: a bump rebuilds every sidecar, not the cache.
const FORMAT_VERSION: int = 4

## A Generation 1 site's id is its node's linear ROM address `at`; table rows
## are map events whose group byte names the table.
const GEN1_SOURCE_OBJECT: int = 0
const GEN1_SOURCE_HIDDEN: int = 1
const GEN1_SOURCE_TEXT: int = 2
const GEN1_SOURCE_PRIZE: int = 3
## Row fields naming a command of the site's own transaction. See [method link_at].
const LINK_ROLES: Dictionary = {
	"picture_address": &"picture", "check_address": &"price", "take_address": &"price",
	"starter_address": &"starter", "ask_address": &"price", "spend_address": &"price",
}
const GEN1_BRANCHES: Array[String] = ["then", "else", "ok", "full", "yes", "no"]
## `PRIZE_MENUS` rows, each `PRIZE_ROWS` deep, packed into one event index.
const GEN1_PRIZE_MENU_SHIFT: int = 4
## Oak's three balls share one `AddPartyMon`, so each set of numbers at an
## address is a row of its own above it. See [method gen1_site].
const ID_VARIANT_SHIFT: int = 16
const MAX_VARIANTS: int = 8
const ID_VARIANT_MASK: int = (MAX_VARIANTS - 1) << ID_VARIANT_SHIFT
const GEN1_SITE_FIELDS: Array[String] = [
	"species", "level", "item", "quantity", "trade", "badge", "price",
]

const STRING_NAME_FIELDS: Array[String] = ["kind", "role"]
const VECTOR_FIELDS: Array[String] = ["map", "cell"]

var _data: GameData = null
var _rows: Dictionary = {}
var _by_kind: Dictionary = {}
## A command a site's fields also reach to `{id, role}`. See [method link_at].
var _links: Dictionary = {}
var _item_sources: Dictionary = {}
var _field_hms: Array[int] = []
var _story: Gen2WorldStory = Gen2WorldStory.new()
## Generation 1's map script bytes to the map numbers whose table reads them.
var _gen1_owners: Dictionary = {}

## Scripts [method build_reporting] decodes between two checks of the clock.
const SCAN_CHUNK: int = 64


## Walks every imported script and map event once; see [method GameData.catalog].
static func build(data: GameData) -> Gen2WorldCatalog:
	var out := Gen2WorldCatalog.new()
	out._data = data
	if data == null:
		return out
	if data.generation == RomRegistry.GEN1:
		out._scan_gen1()
		return out
	out._scan_keys(out._script_keys(), 0, -1)
	out._scan_map_events()
	out._attribute_maps()
	out._read_flow()
	return out


## The same scan in chunks, handing the main loop a frame between them: this
## walk is seven eighths of an import's wall clock.
static func build_reporting(
	data: GameData, on_progress: Callable = Callable(), yield_ms: int = 0
) -> Gen2WorldCatalog:
	var out := Gen2WorldCatalog.new()
	out._data = data
	if data == null:
		return out
	if data.generation == RomRegistry.GEN1:
		out._scan_gen1()
		return out
	var keys: Array = out._script_keys()
	var last_yield: int = Time.get_ticks_msec()
	var at: int = 0
	while at < keys.size():
		var upto: int = mini(at + SCAN_CHUNK, keys.size())
		out._scan_keys(keys, at, upto)
		at = upto
		if on_progress.is_valid():
			on_progress.call("catalogue", at, keys.size())
		if yield_ms > 0 and Time.get_ticks_msec() - last_yield >= yield_ms:
			last_yield = Time.get_ticks_msec()
			await Engine.get_main_loop().process_frame
	out._scan_map_events()
	out._attribute_maps()
	out._read_flow()
	return out


## The scan's result, for the sidecar. Ids go out as decimal string keys and
## come back as ints; the lazy answers are derived from these rows on demand.
func to_dict() -> Dictionary:
	var stored_rows: Dictionary = {}
	for id: int in _rows:
		stored_rows[str(id)] = _stored_value(_rows[id])
	var links: Dictionary = {}
	for at: int in _links:
		links[str(at)] = _stored_value(_links[at])
	var kinds: Dictionary = {}
	for kind: StringName in _by_kind:
		kinds[String(kind)] = (_by_kind[kind] as Array).duplicate()
	return {
		"version": FORMAT_VERSION, "rows": stored_rows, "links": links, "kinds": kinds,
		"story": _story.to_dict(),
	}


## The counterpart, bound to [param data] for patches; null for any other shape,
## so a stale sidecar is rebuilt rather than half read.
static func from_dict(data: GameData, source: Variant) -> Gen2WorldCatalog:
	if not source is Dictionary:
		return null
	var raw: Dictionary = source as Dictionary
	if int(raw.get("version", -1)) != FORMAT_VERSION:
		return null
	for key: String in ["rows", "links", "kinds"]:
		if not raw.get(key, null) is Dictionary:
			return null
	var out := Gen2WorldCatalog.new()
	out._data = data
	for id: String in raw["rows"] as Dictionary:
		var row: Variant = (raw["rows"] as Dictionary)[id]
		if not row is Dictionary:
			return null
		out._rows[id.to_int()] = _restore_value(row)
	for at: String in raw["links"] as Dictionary:
		var link: Variant = (raw["links"] as Dictionary)[at]
		if not link is Dictionary:
			return null
		out._links[at.to_int()] = _restore_value(link)
	for kind: String in raw["kinds"] as Dictionary:
		var kind_ids: Variant = (raw["kinds"] as Dictionary)[kind]
		if not kind_ids is Array:
			return null
		var packed: Array = []
		for id: Variant in kind_ids as Array:
			packed.append(int(id))
		out._by_kind[StringName(kind)] = packed
	out._story = Gen2WorldStory.from_dict(raw.get("story", {}))
	return out


## JSON has one number type and no StringName: whole floats become ints and the
## StringName fields name themselves.
static func _stored_value(value: Variant) -> Variant:
	if value is Array:
		var list: Array = []
		for entry: Variant in value as Array:
			list.append(_stored_value(entry))
		return list
	if not value is Dictionary:
		return value
	var out: Dictionary = {}
	for key: Variant in value as Dictionary:
		var stored: Variant = (value as Dictionary)[key]
		if String(key) in VECTOR_FIELDS and stored is Vector2i:
			out[key] = [(stored as Vector2i).x, (stored as Vector2i).y]
			continue
		out[key] = _stored_value(stored)
	return out


static func _restore_value(value: Variant) -> Variant:
	if value is float:
		var number: float = value as float
		if is_equal_approx(number, floor(number)):
			return int(number)
		return number
	if value is Array:
		var list: Array = []
		for entry: Variant in value as Array:
			list.append(_restore_value(entry))
		return list
	if not value is Dictionary:
		return value
	var out: Dictionary = {}
	for key: Variant in value as Dictionary:
		var restored: Variant = _restore_value((value as Dictionary)[key])
		if String(key) in STRING_NAME_FIELDS and restored is String:
			restored = StringName(restored as String)
		elif String(key) in VECTOR_FIELDS and restored is Array \
			and (restored as Array).size() == 2:
			restored = Vector2i(int((restored as Array)[0]), int((restored as Array)[1]))
		out[key] = restored
	return out


## [param address] is the command's absolute address.
static func pack_id(kind: StringName, bank: int, address: int) -> int:
	var index: int = KINDS.find(kind)
	if index < 0:
		return -1
	return index << ID_KIND_SHIFT | (bank & 0xFF) << ID_BANK_SHIFT \
		| (address & ID_ADDRESS_MASK)


static func pack_event_id(kind: StringName, group: int, number: int, index: int) -> int:
	return pack_id(kind, group, ID_EVENT_BIT | (number & 0xFF) << 8 | (index & 0xFF))


## The row at [param id] with any mod patch already folded in, or empty for an id
## this cartridge has no site for. This is what a runtime reader asks.
func check(id: int) -> Dictionary:
	var row: Variant = _rows.get(id, null)
	if not row is Dictionary:
		return {}
	if _data == null:
		return (row as Dictionary).duplicate(true)
	return _data.overlaid_check(id, (row as Dictionary).duplicate(true))


## Every id of [param kind], in the order the corpus was walked, which is stable
## for one cache. Pass nothing for every id of every kind.
func ids(kind: StringName = &"") -> Array:
	if String(kind).is_empty():
		var all: Array = []
		for name: StringName in KINDS:
			all.append_array(_by_kind.get(name, []))
		return all
	return (_by_kind.get(kind, []) as Array).duplicate()


func size() -> int:
	return _rows.size()


## The site a command belongs to but is not, as `{id, role}`: what makes a patch
## hold across the whole transaction.
func link_at(bank: int, address: int) -> Dictionary:
	var value: Variant = _links.get((bank & 0xFF) << ID_BANK_SHIFT | (address & ID_ADDRESS_MASK), null)
	return value if value is Dictionary else {}


func rows(kind: StringName = &"") -> Array:
	var out: Array = []
	for id: int in ids(kind):
		out.append(check(id))
	return out


## The three species Elm's own balls offer, or none when scripts did not decode.
func possible_starters() -> Array[int]:
	var out: Array[int] = []
	for row: Dictionary in rows(KIND_STARTER):
		var species: int = int(row.get("species", 0))
		if species > 0 and not out.has(species):
			out.append(species)
	return out


## The HM items whose move is a field move, from the cartridge's own TM/HM table:
## the rewards a placement must keep reachable.
func field_hm_items() -> Array[int]:
	if not _field_hms.is_empty():
		return _field_hms
	var out: Array[int] = []
	if _data == null:
		return out
	var count: int = _data.tmhm_moves().size()
	for number: int in count:
		var item: int = Gen2WorldTMHM.item_for_number(_data, number + 1)
		if not Gen2WorldTMHM.is_hm(item, _data.generation):
			continue
		if Gen2WorldFieldMove.is_field_move(_data.tmhm_move(number + 1), _data):
			out.append(item)
	_field_hms = out
	return out


## Which badge an engine flag grants, or -1.
func badge_for_engine_flag(flag: int) -> int:
	return _badge_for_flag(flag)


## The badge [param item]'s move needs in the overworld, or -1 off a field HM.
func badge_for_hm_item(item: int) -> int:
	return badge_for_move(move_for_hm_item(item))


## The badge [param move] needs, in the shared sixteen-badge numbering.
func badge_for_move(move: int) -> int:
	if _data != null and _data.generation == RomRegistry.GEN1:
		var bit: int = int(Gen1Layout.FIELD_MOVE_BADGES.get(move, -1))
		return Gen2WorldState.KANTO_BADGE_FIRST + bit if bit >= 0 else -1
	return Gen2WorldFieldMove.badge_for_move(move)


func move_for_hm_item(item: int) -> int:
	if _data == null or not Gen2WorldTMHM.is_hm(item, _data.generation):
		return 0
	var move: int = Gen2WorldTMHM.move_for_item(_data, item)
	return move if Gen2WorldFieldMove.is_field_move(move, _data) else 0


## The field move a TM or HM teaches, or 0: Rock Smash is a TM.
func field_move_for_item(item: int) -> int:
	if _data == null or not Gen2WorldTMHM.is_tm_hm(item, _data.generation):
		return 0
	var move: int = Gen2WorldTMHM.move_for_item(_data, item)
	return move if Gen2WorldFieldMove.is_field_move(move, _data) else 0


## Every item some check hands over, as a set; asking for any other gates nothing.
func item_sources() -> Dictionary:
	if not _item_sources.is_empty():
		return _item_sources
	for row: Dictionary in rows(KIND_ITEM):
		_item_sources[int(row["item"])] = true
	for kind: StringName in [KIND_STARTER, KIND_GIFT, KIND_PRIZE]:
		for row: Dictionary in rows(kind):
			if int(row.get("item", 0)) > 0:
				_item_sources[int(row["item"])] = true
	return _item_sources


## What the cartridge's scripts set and close. See [Gen2WorldStory].
func story() -> Gen2WorldStory:
	return _story


## Whether a later check may be gated behind this reward: a badge or a field HM.
func is_progression(row: Dictionary) -> bool:
	if StringName(row.get("kind", &"")) == KIND_BADGE:
		return true
	return field_hm_items().has(int(row.get("item", 0)))


## Every item a row's `requires` or the story reads, and every field-move TM or HM.
func progression_items() -> Array[int]:
	var found: Dictionary = {}
	for row: Dictionary in _rows.values():
		for requirement: Dictionary in row.get("requires", []):
			_note_item(found, Gen2WorldStory.condition_of(requirement))
	for setter: Dictionary in _story.setters:
		for condition: String in setter["requires"]:
			_note_item(found, condition)
	for link: Dictionary in _story.links:
		for condition: String in link["requires"]:
			_note_item(found, condition)
	for gate: Dictionary in _story.gates:
		for list: Array in gate["closing"]:
			for condition: String in list:
				_note_item(found, Gen2WorldStory.negate(condition))
	for number: int in (_data.tmhm_moves().size() if _data != null else 0):
		var item: int = Gen2WorldTMHM.item_for_number(_data, number + 1)
		if field_move_for_item(item) > 0:
			found[item] = true
	var out: Array[int] = []
	out.assign(found.keys())
	out.sort()
	return out


static func _note_item(found: Dictionary, condition: String) -> void:
	if condition.begins_with("i:"):
		found[condition.substr(2).to_int()] = true


## Each script site's `requires`, map and cell from [Gen2WorldScriptFlow], and
## the story beside them; a site no event reaches keeps its straight read.
func _read_flow() -> void:
	var flow: Gen2WorldScriptFlow = Gen2WorldScriptFlow.build(_data)
	for id: int in _rows:
		var row: Dictionary = _rows[id]
		if not row.has("address"):
			continue
		var conds: Variant = flow.conditions_at(int(row["bank"]), int(row["address"]))
		if conds != null:
			row["requires"] = _requirements_of(conds)
		if not row.has("map") and flow.map_at(int(row["bank"]), int(row["address"])) != null:
			row["map"] = flow.map_at(int(row["bank"]), int(row["address"]))
		var cell: Variant = flow.cell_at(
			int(row["bank"]), int(row["address"]), row.get("map", Vector2i(-1, -1))
		)
		if cell != null:
			row["cell"] = cell
	flow.write_setters(_story, Gen2WorldProgression.START_MAP)
	flow.write_coord_gates(_story)
	flow.write_block_gates(_story)
	flow.write_links(_story)
	_story.write_objects(_data)
	_story.merge_gates()


static func _requirements_of(conds: Array) -> Array:
	var sorted: Array = conds.duplicate()
	sorted.sort()
	var out: Array = []
	for condition: String in sorted:
		## Not holding an item is no gate a placement can close.
		if not condition.begins_with("!i:"):
			out.append(Gen2WorldStory.requirement_of(condition))
	return out


## Every imported script. A command the decoder does not know ends its walk, the
## rule `scan_references` follows: a site past it would be at an invented offset.
func _script_keys() -> Array:
	return _data.world_script_keys()


## Scans `keys[from:upto]`, all when [param upto] is negative.
func _scan_keys(keys: Array, from: int, upto: int) -> void:
	var crystal: bool = Gen2WorldState.is_crystal_profile(_data)
	var last: int = keys.size() if upto < 0 else upto
	for index: int in range(from, last):
		var parts: PackedStringArray = String(keys[index]).split(":")
		if parts.size() != 2:
			continue
		## `Gen2WorldScript.pointer_key` is a DECIMAL bank and a hex address.
		var bank: int = String(parts[0]).to_int()
		var address: int = String(parts[1]).hex_to_int()
		_scan_one_script(bank, address, _data.world_script(bank, address), crystal)


func _scan_one_script(
	bank: int, address: int, body: PackedByteArray, crystal: bool
) -> void:
	if body.is_empty():
		return

	var commands: Array = []
	var offset: int = 0
	## Past `end` and `sjump` into the branch bodies, up to the first byte no
	## command owns.
	var terminators: int = 0
	for _step: int in MAX_SCRIPT_COMMANDS:
		if offset >= body.size():
			break
		var command: Dictionary = Gen2WorldScript.command_at(body, offset, crystal)
		if not bool(command.get("ok", false)):
			break
		commands.append(command)
		offset += int(command["width"])
		if Gen2WorldScript.is_terminal(int(command["opcode"]), crystal):
			terminators += 1
			if terminators >= MAX_ROUTINES:
				break
	## A `pokepic` of the species a `givepoke` hands over is only Elm's balls.
	var pictured: Dictionary = {}
	for command: Dictionary in commands:
		if StringName(command["name"]) == &"pokepic":
			pictured[int(command.get("pokemon", 0))] = true
	for command: Dictionary in commands:
		_record_script_site(
			bank, address, command, commands,
			_coin_price(commands, int(command["offset"]), crystal), pictured, crystal
		)


## The give's own branch's `takecoins`, the price that makes it a PRIZE; zero
## makes it a gift.
func _coin_price(commands: Array, at: int, crystal: bool) -> int:
	var take: int = _nearest_coin_command(commands, at, &"takecoins", crystal)
	if take < 0:
		return 0
	for command: Dictionary in commands:
		if int(command["offset"]) == take:
			return int(command.get("value", 0))
	return 0


func _record_script_site(
	bank: int, address: int, command: Dictionary, commands: Array, coins: int,
	pictured: Dictionary, crystal: bool
) -> void:
	var offset: int = int(command["offset"])
	match StringName(command["name"]):
		&"givepoke", &"giveegg":
			var species: int = int(command.get("pokemon", command.get("value", 0)))
			var level: int = int(command.get("level", command.get("value_2", 0)))
			if species <= 0:
				return
			var kind: StringName = KIND_GIFT
			if coins > 0:
				kind = KIND_PRIZE
			elif pictured.has(species):
				kind = KIND_STARTER
			var row: Dictionary = {
				"species": species, "level": level,
				"item": int(command.get("item", 0)), "price": coins,
			}
			## The ball's picture and the branch's coin commands, absolute.
			if kind == KIND_STARTER:
				var picture: int = _address_of(commands, &"pokepic", species)
				if picture >= 0:
					row["picture_address"] = address + picture
			if kind == KIND_PRIZE:
				var check_at: int = _nearest_coin_command(commands, offset, &"checkcoins", crystal)
				var take: int = _nearest_coin_command(commands, offset, &"takecoins", crystal)
				if check_at >= 0:
					row["check_address"] = address + check_at
				if take >= 0:
					row["take_address"] = address + take
			_add(kind, bank, address, offset, row, commands, offset, crystal)
		&"loadwildmon":
			## A static encounter is `loadwildmon` then `startbattle`.
			if not _followed_by(commands, offset, &"startbattle"):
				return
			_add(KIND_STATIC, bank, address, offset, {
				"species": int(command.get("pokemon", 0)),
				"level": int(command.get("level", 0)),
			}, commands, offset, crystal)
		&"trade":
			var index: int = int(command.get("value", 0))
			var record: Dictionary = _data.world_trade(index)
			_add(KIND_TRADE, bank, address, offset, {
				"trade": index,
				"species": int(record.get("offered_species", 0)),
				"requested_species": int(record.get("requested_species", 0)),
			}, commands, offset, crystal)
		&"pokemart":
			## `db dialog_id / dw mart_id`.
			var mart: int = int(command.get("address", 0))
			## `world_mart` answers an out-of-range index with a default shelf.
			if mart < 0 or mart >= _data.world_mart_count():
				return
			_add(KIND_SHOP, bank, address, offset, {
				"mart": mart,
				"dialog": int(command.get("value", 0)),
				## The shelf as `{item, price}`, the items' own prices.
				"items": _mart_items(mart),
			}, commands, offset, crystal)
		&"giveitem", &"verbosegiveitem":
			var item: int = int(command.get("item", command.get("value", 0)))
			if item <= 0:
				return
			_add(KIND_ITEM, bank, address, offset, {
				"item": item,
				"quantity": maxi(1, int(command.get("quantity", command.get("value_2", 1)))),
				"price": coins, "hidden": false,
			}, commands, offset, crystal)
		&"setflag":
			var badge: int = _badge_for_flag(int(command.get("flag", -1)))
			if badge < 0:
				return
			_add(KIND_BADGE, bank, address, offset, {
				"badge": badge, "engine_flag": int(command.get("flag", 0)),
			}, commands, offset, crystal)


## Where a command naming [param species] sits inside the blob, or -1.
static func _address_of(commands: Array, name: StringName, species: int) -> int:
	for command: Dictionary in commands:
		if StringName(command["name"]) == name and int(command.get("pokemon", -1)) == species:
			return int(command["offset"])
	return -1


## The coin command of the branch, between two terminators, [param at] sits in,
## or -1: how the Game Corner's vendor keeps three prices in one script.
static func _nearest_coin_command(
	commands: Array, at: int, name: StringName, crystal: bool
) -> int:
	var bounds: Array = _branch_bounds(commands, at, crystal)
	for command: Dictionary in commands:
		if StringName(command["name"]) != name:
			continue
		var offset: int = int(command["offset"])
		if offset >= int(bounds[0]) and offset < int(bounds[1]):
			return offset
	return -1


## The offsets bounding the branch [param at] sits in, terminator included.
static func _branch_bounds(commands: Array, at: int, crystal: bool) -> Array:
	var start: int = 0
	var end: int = 0x10000
	for command: Dictionary in commands:
		var offset: int = int(command["offset"])
		if Gen2WorldScript.continues_after(int(command["opcode"]), crystal):
			continue
		if offset < at:
			start = offset + int(command["width"])
		else:
			end = offset + int(command["width"])
			break
	return [start, end]


## The mart list at [param index] as `{item, price}` rows.
func _mart_items(index: int) -> Array:
	var out: Array = []
	if _data == null:
		return out
	var mart: Dictionary = _data.world_mart(index)
	for raw: Variant in mart.get("items", []):
		var item: int = int(raw) if not raw is Dictionary else int((raw as Dictionary).get("item", 0))
		if item <= 0:
			continue
		out.append({"item": item, "price": int(_data.item(item).get("price", 0))})
	return out


## Stamps every script site with the first MAP in order whose events reach it.
func _attribute_maps() -> void:
	var crystal: bool = Gen2WorldState.is_crystal_profile(_data)
	var owner: Dictionary = {}
	## One scan per script, however many maps reach it.
	var references: Dictionary = {}
	for map: Gen2WorldMap in _data.world_maps():
		_walk_map_scripts(map, crystal, owner, references)
	var entries: Array = owner.keys()
	entries.sort()
	for id: Variant in _rows:
		var row: Dictionary = _rows[id]
		if row.has("map") or not row.has("address"):
			continue
		## A site's entry is the last one at or before it within its own blob:
		## Goldenrod Dept Store 2F's clerks.
		var bank: int = (int(row["bank"]) & 0xFF) << ID_BANK_SHIFT
		var base: int = int(row.get("script_base", row["address"]))
		var site: int = bank | (int(row["address"]) & ID_ADDRESS_MASK)
		var at: int = entries.bsearch(site, false) - 1
		if at >= 0 and int(entries[at]) >= (bank | (base & ID_ADDRESS_MASK)) \
			and (int(entries[at]) & ~ID_ADDRESS_MASK) == bank:
			row["script_base"] = int(entries[at]) & ID_ADDRESS_MASK
			row["map"] = owner[entries[at]]


func _walk_map_scripts(
	map: Gen2WorldMap, crystal: bool, owner: Dictionary, references: Dictionary
) -> void:
	var bank: int = int(map.events.get("bank", 0))
	var scripts: Dictionary = map.scripts
	var script_bank: int = int(scripts.get("bank", bank))
	var pending: Array = []
	for source: String in ["objects", "bg_events", "coord_events"]:
		_append_scripts(pending, map.events.get(source, []), bank)
	if int(scripts.get("address", 0)) > 0:
		pending.append([script_bank, int(scripts["address"])])
	_append_scripts(pending, scripts.get("callbacks", []), script_bank)
	var seen: Dictionary = {}
	for _step: int in MAX_SCRIPT_COMMANDS:
		if pending.is_empty():
			break
		var entry: Array = pending.pop_back()
		var key: int = (int(entry[0]) & 0xFF) << ID_BANK_SHIFT \
			| (int(entry[1]) & ID_ADDRESS_MASK)
		if seen.has(key):
			continue
		seen[key] = true
		if not owner.has(key):
			owner[key] = Vector2i(map.group, map.number)
		if not references.has(key):
			var body: PackedByteArray = _data.world_script(int(entry[0]), int(entry[1]))
			references[key] = Gen2WorldScript.scan_references(
				body, int(entry[0]), int(entry[1]), crystal
			).get("scripts", []) if not body.is_empty() else []
		for referenced: Variant in references[key]:
			if referenced is Dictionary:
				pending.append([
					int((referenced as Dictionary)["bank"]),
					int((referenced as Dictionary)["address"]),
				])


static func _append_scripts(pending: Array, events: Variant, bank: int) -> void:
	for raw: Variant in events:
		if raw is Dictionary and int((raw as Dictionary).get("script", 0)) > 0:
			pending.append([bank, int((raw as Dictionary)["script"])])


## Whether [param name] is within the next few commands after [param at].
static func _followed_by(commands: Array, at: int, name: StringName, within: int = 6) -> bool:
	var seen: int = 0
	for command: Dictionary in commands:
		if int(command["offset"]) <= at:
			continue
		if StringName(command["name"]) == name:
			return true
		seen += 1
		if seen >= within:
			return false
	return false


## Which badge an engine flag grants, or -1, from the profile's own list.
func _badge_for_flag(flag: int) -> int:
	if _data != null and _data.generation == RomRegistry.GEN1:
		for bit: int in Gen1Layout.BADGE_COUNT:
			if Gen2WorldState.gen1_badge_flag(bit) == flag:
				return Gen2WorldState.KANTO_BADGE_FIRST + bit
		return -1
	var flags: Array[int] = Gen2WorldState.BADGE_ENGINE_FLAGS \
		if Gen2WorldState.is_crystal_profile(_data) \
		else Gen2WorldState.BADGE_ENGINE_FLAGS_GOLD_SILVER
	return flags.find(flag)


## Item balls and hidden items are map EVENTS whose pointer is data.
func _scan_map_events() -> void:
	for map: Gen2WorldMap in _data.world_maps():
		var bank: int = int(map.events.get("bank", 0))
		var objects: Array = map.events.get("objects", [])
		for index: int in objects.size():
			var object: Variant = objects[index]
			if not object is Dictionary:
				continue
			if int((object as Dictionary).get("object_type", 0)) != OBJECT_TYPE_ITEMBALL:
				continue
			## `db item, quantity`, which `_item_ball_request_for_event` also reads.
			var raw: PackedByteArray = _data.world_script(
				bank, int((object as Dictionary).get("script", 0))
			)
			if raw.size() < 2 or int(raw[0]) <= 0:
				continue
			_add_event(KIND_ITEM, map, index, {
				"item": int(raw[0]), "quantity": maxi(1, int(raw[1])), "hidden": false,
			})
		var bg_events: Array = map.events.get("bg_events", [])
		for index: int in bg_events.size():
			var event: Variant = bg_events[index]
			if not event is Dictionary:
				continue
			if int((event as Dictionary).get("type", 0)) != BGEVENT_ITEM:
				continue
			## `dwb event, item`: the flag first as a word, the item last.
			var raw: PackedByteArray = _data.world_script(
				bank, int((event as Dictionary).get("script", 0))
			)
			if raw.size() < 3 or int(raw[2]) <= 0:
				continue
			_add_event(KIND_ITEM, map, objects.size() + index, {
				"item": int(raw[2]), "quantity": 1, "hidden": true,
				"event_flag": int(raw[0]) | (int(raw[1]) << 8),
			})


func _add(
	kind: StringName, bank: int, address: int, offset: int, fields: Dictionary,
	commands: Array, at: int, crystal: bool
) -> void:
	var row: Dictionary = fields.duplicate()
	row["id"] = pack_id(kind, bank, address + offset)
	row["kind"] = kind
	row["bank"] = bank
	row["address"] = address + offset
	## The blob decoded from, which a map event points at.
	row["script_base"] = address
	row["requires"] = _requirements(commands, at, crystal)
	_store(row)


func _add_event(
	kind: StringName, map: Gen2WorldMap, index: int, fields: Dictionary
) -> void:
	var row: Dictionary = fields.duplicate()
	row["id"] = pack_event_id(kind, map.group, map.number, index)
	row["kind"] = kind
	row["map"] = Vector2i(map.group, map.number)
	row["event_index"] = index
	row["requires"] = []
	var events: Array = map.events.get("objects", [])
	var source: Array = events if index < events.size() else map.events.get("bg_events", [])
	var event: Dictionary = source[index if index < events.size() else index - events.size()]
	row["cell"] = Vector2i(int(event.get("x", 0)), int(event.get("y", 0)))
	_store(row)


## A row with numbers the cartridge cannot hold is text read as a command.
func _plausible(row: Dictionary) -> bool:
	var species: int = int(row.get("species", 0))
	if row.has("species") and (species < 1 or species > Gen2Layout.SPECIES_COUNT):
		return false
	var level: int = int(row.get("level", 0))
	if row.has("level") and (level < 1 or level > Gen2Layout.MAX_LEVEL):
		return false
	var item: int = int(row.get("item", 0))
	if row.has("item") and item != 0 and _data != null and _data.item(item).is_empty():
		return false
	if row.has("trade") and _data != null and _data.world_trade(int(row["trade"])).is_empty():
		return false
	return true


func _store(row: Dictionary) -> void:
	var id: int = int(row["id"])
	if id < 0 or _rows.has(id) or not _plausible(row):
		return
	_rows[id] = row
	for key: String in LINK_ROLES:
		if not row.has(key):
			continue
		_links[(int(row["bank"]) & 0xFF) << ID_BANK_SHIFT | (int(row[key]) & ID_ADDRESS_MASK)] = {
			"id": id, "role": LINK_ROLES[key],
		}
	var kind: StringName = StringName(row["kind"])
	var list: Array = _by_kind.get(kind, [])
	list.append(id)
	_by_kind[kind] = list


## The tests a straight read of the blob passes on the way to this site, each
## one an `iffalse` falls through on; [method _read_flow] replaces it.
func _requirements(commands: Array, at: int, crystal: bool) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for index: int in commands.size():
		var command: Dictionary = commands[index]
		if int(command["offset"]) >= at:
			break
		## A condition before the last terminator guards an earlier routine.
		if not Gen2WorldScript.continues_after(int(command["opcode"]), crystal):
			out.clear()
			seen.clear()
			continue
		if index + 1 >= commands.size() or StringName(commands[index + 1]["name"]) != &"iffalse":
			continue
		match StringName(command["name"]):
			&"checkevent":
				_append_once(out, seen, {"event": int(command.get("flag", 0))})
			&"checkflag":
				_append_once(out, seen, {"engine_flag": int(command.get("flag", 0))})
			&"checkitem":
				_append_once(out, seen, {"item": int(command.get("value", 0))})
	return out


## One entry per distinct condition: two blobs reaching one routine walk it twice.
static func _append_once(out: Array, seen: Dictionary, entry: Dictionary) -> void:
	var key: String = str(entry)
	if seen.has(key):
		return
	seen[key] = true
	out.append(entry)


## Every Generation 1 site and the story its trees write. A walk's context names
## where it runs (`at`), what it needs (`conds`), whether its walks are gates.
func _scan_gen1() -> void:
	_gen1_owners = _gen1_script_owners()
	for map: Gen2WorldMap in _data.world_maps():
		for index: int in map.texts.size():
			_walk_gen1(map, (map.texts[index] as Dictionary).get("script", []), [], [],
				_gen1_text_context(map, index + 1))
			_add_gen1_shop(map, index)
		for table: Variant in map.alternate_texts:
			for row: Dictionary in map.alternate_texts[table] as Array:
				_walk_gen1(map, row.get("script", []), [], [], {})
		for row: Dictionary in map.events.get("hidden_events", []) as Array:
			_walk_gen1(map, row.get("script", []), [], [], {"hidden": row, "at": [Gen2WorldStory.place(
				Vector2i(map.group, map.number), Vector2i(int(row.get("x", 0)), int(row.get("y", 0)))
			)]})
		_walk_gen1(map, map.scripts.get("entry", []), [], [], {"gates": true})
		for row: Dictionary in map.scripts.get("states", []) as Array:
			var state: int = int(row.get("id", 0))
			_walk_gen1(map, row.get("nodes", []), [], [], {
				"conds": [Gen2WorldStory.scene(map.group, map.number, state)], "gates": state == 0,
			})
		for row: Dictionary in map.scripts.get("callbacks", []) as Array:
			_walk_gen1(map, row.get("nodes", []), [], [], {"gates": true})
		_scan_gen1_objects(map)
	_scan_gen1_prizes()
	_finish_gen1_story()


func _finish_gen1_story() -> void:
	_story.write_objects(_data)
	_story.write_gen1_flutes()
	_story.merge_gates()
	for map: Gen2WorldMap in _data.world_maps():
		for object: Dictionary in map.events.get("objects", []) as Array:
			if object.has("toggle_index") and bool(object.get("toggle_on", true)):
				_story.initial.append("t:%d" % int(object["toggle_index"]))


## Which maps' `map_script_table` reads each script byte.
func _gen1_script_owners() -> Dictionary:
	var out: Dictionary = {}
	for map: Gen2WorldMap in _data.world_maps():
		_gen1_find_tables(map, map.scripts.get("entry", []), out)
	return out


static func _gen1_find_tables(map: Gen2WorldMap, nodes: Variant, out: Dictionary) -> void:
	if not nodes is Array:
		return
	for node: Variant in nodes as Array:
		if not node is Dictionary:
			continue
		if String((node as Dictionary).get("op", "")) == "map_script_table":
			var owners: Array = out.get(int(node.get("byte", -1)), [])
			if not owners.has(map.number):
				owners.append(map.number)
			out[int(node.get("byte", -1))] = owners
		for branch: String in GEN1_BRANCHES:
			_gen1_find_tables(map, (node as Dictionary).get(branch, []), out)


## Where a text runs: the objects and signs showing it, and an object's toggle
## when the text has one object and it starts hidden.
static func _gen1_text_context(map: Gen2WorldMap, text: int) -> Dictionary:
	var here := Vector2i(map.group, map.number)
	var at: Array = []
	var conds: Array = []
	for source: String in ["objects", "bg_events"]:
		for event: Dictionary in map.events.get(source, []) as Array:
			if int(event.get("text", -1)) != text:
				continue
			at.append(Gen2WorldStory.place(here, Vector2i(int(event.get("x", 0)), int(event.get("y", 0)))))
			if event.has("toggle_index") and not bool(event.get("toggle_on", true)):
				conds.append("t:%d" % int(event["toggle_index"]))
	return {"at": at, "conds": conds if at.size() == 1 else []}


## [param ancestors] is `[node, branch]` per node the walk is inside;
## [param scopes] every node list on the way down.
func _walk_gen1(
	map: Gen2WorldMap, nodes: Variant, ancestors: Array, scopes: Array, context: Dictionary
) -> void:
	if not nodes is Array:
		return
	var here: Array = scopes + [nodes]
	for raw: Variant in nodes as Array:
		if not raw is Dictionary:
			continue
		var node: Dictionary = raw
		_record_gen1_site(map, node, ancestors, here, context)
		_record_gen1_story(map, node, ancestors, context, nodes)
		var tested: Dictionary = _gen1_snapshot(here, node) if node.has("snapshot") else node
		for branch: String in GEN1_BRANCHES:
			if node.has(branch):
				_walk_gen1(map, node[branch], ancestors + [[tested, branch]], here, context)
		for row: Variant in node.get("rows", []) as Array:
			if row is Dictionary:
				_walk_gen1(map, (row as Dictionary).get("then", []), ancestors + [[node, "rows"]], here, context)


func _record_gen1_site(
	map: Gen2WorldMap, node: Dictionary, ancestors: Array, scopes: Array, context: Dictionary
) -> void:
	var at: int = int(node.get("at", -1))
	var where: Dictionary = _gen1_where(map, ancestors, context)
	match String(node.get("op", "")):
		"give_pokemon":
			if at < 0 or int(node.get("species", 0)) < 1:
				return
			var row: Dictionary = {
				"species": int(node["species"]), "level": int(node["level"]), "item": 0,
				"price": 0,
			}
			row.merge(_gen1_price(ancestors, node), true)
			var kind: StringName = KIND_GIFT
			if int(row["price"]) > 0:
				kind = KIND_PRIZE
			elif _gen1_starter_set(scopes) >= 0:
				kind = KIND_STARTER
				row["starter_address"] = _gen1_starter_set(scopes)
			_add_gen1(kind, map, at, row, where)
		"give_item":
			if node.has("hidden"):
				_add_gen1_event(KIND_ITEM, map, GEN1_SOURCE_HIDDEN, int(node["hidden"]), {
					"item": int(node["item"]), "quantity": 1, "hidden": true,
					"engine_flag": int((context.get("hidden", {}) as Dictionary).get("hidden_item_flag", 0)),
				}, where)
			elif at >= 0:
				_add_gen1(KIND_ITEM, map, at, {
					"item": int(node["item"]), "quantity": maxi(1, int(node["count"])),
					"price": 0, "hidden": false,
				}, where)
		"wild_battle":
			if at >= 0:
				_add_gen1(KIND_STATIC, map, at, {
					"species": int(node["species"]), "level": int(node["level"]),
				}, where)
		"trade":
			if at >= 0:
				var record: Dictionary = _data.world_trade(int(node["trade_id"]))
				_add_gen1(KIND_TRADE, map, at, {
					"trade": int(node["trade_id"]),
					"species": int(record.get("offered_species", 0)),
					"requested_species": int(record.get("requested_species", 0)),
				}, where)
		"flag":
			var badge: int = _badge_for_flag(int(node.get("flag", -1)))
			if at >= 0 and badge >= 0 and bool(node.get("engine", false)) and bool(node.get("set", false)):
				_add_gen1(KIND_BADGE, map, at, {
					"badge": badge, "engine_flag": int(node["flag"]),
				}, where)


## A branch on a snapshot tests the flag the `flag_test` before it read:
## `CheckEventReuseHL` after `CheckEventHL`.
static func _gen1_snapshot(scopes: Array, node: Dictionary) -> Dictionary:
	for index: int in range(scopes.size() - 1, -1, -1):
		var nodes: Array = scopes[index]
		for at: int in range(nodes.size() - 1, -1, -1):
			var raw: Variant = nodes[at]
			if raw is Dictionary and String((raw as Dictionary).get("op", "")) == "flag_test" \
				and int((raw as Dictionary).get("snapshot", -1)) == int(node["snapshot"]):
				return {"op": "branch", "flag": int(raw["flag"]), "engine": bool(raw.get("engine", false))}
	return node


## A site's `requires` and, when its tree runs at one cell, the cell.
func _gen1_where(map: Gen2WorldMap, ancestors: Array, context: Dictionary) -> Dictionary:
	var conds: Array = _gen1_conditions(ancestors, false) + (context.get("conds", []) as Array)
	var requires: Array = []
	for condition: String in conds:
		var requirement: Dictionary = Gen2WorldStory.requirement_of(condition)
		if not requires.has(requirement):
			requires.append(requirement)
	var places: Array = _gen1_places(map, ancestors, context)
	var out: Dictionary = {"requires": requires}
	if places.size() == 1 and (places[0] as Array).size() == 4:
		out["cell"] = Vector2i(int(places[0][2]), int(places[0][3]))
	return out


## A flag, toggle or map script state written is a setter; a walk of the player
## under a coordinate test in a resting script is a gate, its own state change
## no way past.
func _record_gen1_story(
	map: Gen2WorldMap, node: Dictionary, ancestors: Array, context: Dictionary, siblings: Array
) -> void:
	var here := Vector2i(map.group, map.number)
	if String(node.get("op", "")) == "walk":
		var cells: Array = _gen1_cells(ancestors)
		if bool(context.get("gates", false)) and not cells.is_empty():
			_story.add_gate(here, cells, _gen1_conditions(ancestors, true) + (context.get("conds", []) as Array), true)
			for sibling: Variant in siblings:
				if sibling is Dictionary and String((sibling as Dictionary).get("op", "")) == "set_map_script":
					for fact: String in _gen1_facts(map, sibling):
						_story.transient[fact] = true
		return
	var sets: Array = _gen1_facts(map, node)
	if not sets.is_empty():
		_story.add_setter(
			sets, _gen1_conditions(ancestors, false) + (context.get("conds", []) as Array),
			_gen1_places(map, ancestors, context)
		)


func _gen1_facts(map: Gen2WorldMap, node: Dictionary) -> Array:
	match String(node.get("op", "")):
		"flag":
			var engine: bool = bool(node.get("engine", false))
			if engine and _badge_for_flag(int(node.get("flag", -1))) >= 0:
				return []
			var fact: String = "%s:%d" % ["f" if engine else "e", int(node.get("flag", 0))]
			return [fact if bool(node.get("set", false)) else "!" + fact]
		"toggle_object":
			if node.has("index"):
				return [("!t:%d" if bool(node.get("hidden", false)) else "t:%d") % int(node["index"])]
		"set_map_script":
			var owners: Array = _gen1_owners.get(int(node.get("byte", -1)), [])
			var owner: int = map.number if owners.has(map.number) else (owners[0] if owners.size() == 1 else -1)
			if node.has("value") and owner >= 0:
				return [Gen2WorldStory.scene(map.group, owner, int(node["value"]))]
	return []


## The cells a coordinate test on the way down pins the tree to.
static func _gen1_cells(ancestors: Array) -> Array:
	var x: int = -1
	var y: int = -1
	var out: Array = []
	for pair: Array in ancestors:
		var node: Dictionary = pair[0]
		if pair[1] != "then":
			continue
		match String(node.get("op", "")):
			"player_coord":
				if String(node.get("test", "")) != "exactly":
					continue
				if int(node.get("axis", 0)) == 0:
					y = int(node.get("value", 0))
				else:
					x = int(node.get("value", 0))
			"player_in_array":
				for cell: Dictionary in node.get("cells", []) as Array:
					out.append(Vector2i(int(cell.get("x", 0)), int(cell.get("y", 0))))
	if x >= 0 and y >= 0:
		out.append(Vector2i(x, y))
	return out


func _gen1_places(map: Gen2WorldMap, ancestors: Array, context: Dictionary) -> Array:
	var here := Vector2i(map.group, map.number)
	var out: Array = []
	for cell: Vector2i in _gen1_cells(ancestors):
		out.append(Gen2WorldStory.place(here, cell))
	if out.is_empty():
		out = (context.get("at", []) as Array).duplicate()
	return out if not out.is_empty() else [Gen2WorldStory.place(here)]


## `wPlayerStarter`'s store on the way to the give: Oak's balls, Yellow's Pikachu.
static func _gen1_starter_set(scopes: Array) -> int:
	for nodes: Array in scopes:
		for raw: Variant in nodes:
			if raw is Dictionary and String((raw as Dictionary).get("op", "")) == "set_starter" \
				and String((raw as Dictionary).get("who", "")) == "player":
				return int((raw as Dictionary).get("at", -1))
	return -1


## The `has_money` whose price the give's `ok` branch spends: the Magikarp man.
static func _gen1_price(ancestors: Array, node: Dictionary) -> Dictionary:
	for raw: Variant in node.get("ok", []) as Array:
		if not (raw is Dictionary and String((raw as Dictionary).get("op", "")) == "spend_money"):
			continue
		var spend: Dictionary = raw
		for pair: Array in ancestors:
			var above: Dictionary = pair[0]
			if String(above.get("op", "")) == "has_money" \
				and int(above.get("price", 0)) == int(spend.get("amount", 0)):
				return {
					"price": int(above["price"]),
					"ask_address": int(above.get("at", -1)), "spend_address": int(spend.get("at", -1)),
				}
	return {}


## What holds on each branch taken; [param negative_items] keeps an item NOT held.
func _gen1_conditions(ancestors: Array, negative_items: bool) -> Array:
	var out: Array = []
	for pair: Array in ancestors:
		for condition: String in _gen1_condition(pair[0], String(pair[1]), negative_items):
			if not out.has(condition):
				out.append(condition)
	return out


static func _gen1_condition(node: Dictionary, branch: String, negative_items: bool) -> Array:
	var then: bool = branch == "then"
	match String(node.get("op", "")):
		"branch":
			return _gen1_flag_condition(node, then)
		"has_item":
			if then or negative_items:
				return [("i:%d" if then else "!i:%d") % int(node.get("item", 0))]
		"badge":
			var flag: int = Gen2WorldState.gen1_badge_flag(int(node.get("badge", 0)))
			return [("f:%d" if then else "!f:%d") % flag]
		"guard_drink":
			var drinks: Array = []
			if not then and negative_items:
				for item: Variant in node.get("items", []) as Array:
					drinks.append("!i:%d" % int(item))
			return drinks
	return []


static func _gen1_flag_condition(node: Dictionary, then: bool) -> Array:
	if node.has("snapshot") or node.has("index_source") or node.has("either"):
		return []
	var kind: String = "f" if bool(node.get("engine", false)) else "e"
	if not then:
		return [] if node.has("all") or node.has("clear") else ["!%s:%d" % [kind, int(node["flag"])]]
	var out: Array = ["%s:%d" % [kind, int(node["flag"])]]
	for flag: Variant in node.get("all", []) as Array:
		out.append("%s:%d" % [kind, int(flag)])
	for flag: Variant in node.get("clear", []) as Array:
		out.append("!%s:%d" % [kind, int(flag)])
	return out


## `PickUpItem`'s item balls and `CheckForEngagingTrainers`' standing wilds.
func _scan_gen1_objects(map: Gen2WorldMap) -> void:
	var objects: Array = map.events.get("objects", [])
	for index: int in objects.size():
		var object: Dictionary = objects[index]
		var where: Dictionary = {
			"requires": [], "cell": Vector2i(int(object.get("x", 0)), int(object.get("y", 0))),
		}
		if int(object.get("item", 0)) > 0:
			_add_gen1_event(KIND_ITEM, map, GEN1_SOURCE_OBJECT, index, {
				"item": int(object["item"]), "quantity": 1, "hidden": false,
			}, where)
		elif int(object.get("species", 0)) > 0 and not object.has("trainer_class"):
			_add_gen1_event(KIND_STATIC, map, GEN1_SOURCE_OBJECT, index, {
				"species": int(object["species"]), "level": int(object.get("level", 0)),
			}, where)


## A `TX_SCRIPT_MART` row keeps its shelf; the clerk's own text id is the site.
func _add_gen1_shop(map: Gen2WorldMap, index: int) -> void:
	var row: Dictionary = map.texts[index]
	if int(row.get("command", 0)) != Gen1Layout.TEXT_SCRIPT_MART:
		return
	var items: Array = []
	for item: Variant in row.get("items", []) as Array:
		if int(item) > 0:
			items.append({"item": int(item), "price": int(_data.item(int(item)).get("price", 0))})
	_add_gen1_event(KIND_SHOP, map, GEN1_SOURCE_TEXT, index, {
		"text": index + 1, "items": items,
	}, {})


## `PrizeMenus`' rows, priced in coins, standing where the vendors are.
func _scan_gen1_prizes() -> void:
	var map: Gen2WorldMap = _gen1_prize_map()
	if map == null:
		return
	var menus: Array = _data.prize_menus()
	for menu: int in menus.size():
		var entries: Array = (menus[menu] as Dictionary).get("rows", [])
		var tms: bool = bool((menus[menu] as Dictionary).get("tms", false))
		for index: int in entries.size():
			var row: Dictionary = entries[index]
			var fields: Dictionary = {"price": int(row.get("cost", 0))}
			if tms:
				fields["item"] = int(row.get("item", 0))
			else:
				fields["species"] = int(row.get("item", 0))
				fields["level"] = int(row.get("level", 0))
				fields["item"] = 0
			_add_gen1_event(
				KIND_PRIZE, map, GEN1_SOURCE_PRIZE, menu << GEN1_PRIZE_MENU_SHIFT | index, fields, {}
			)


func _gen1_prize_map() -> Gen2WorldMap:
	for map: Gen2WorldMap in _data.world_maps():
		for row: Dictionary in map.texts:
			if int(row.get("command", 0)) == Gen1Layout.TEXT_SCRIPT_PRIZE_VENDOR:
				return map
	return null


func _add_gen1(
	kind: StringName, map: Gen2WorldMap, at: int, fields: Dictionary, where: Dictionary
) -> void:
	var row: Dictionary = fields.duplicate()
	var bank: int = RomFile.bank_of(at)
	var address: int = _gen1_address(at)
	var id: int = pack_id(kind, bank, address)
	for variant: int in MAX_VARIANTS:
		var held: Variant = _rows.get(id | variant << ID_VARIANT_SHIFT, null)
		if held == null:
			id |= variant << ID_VARIANT_SHIFT
			break
		if _gen1_same_site(held, row, true):
			return
	row["id"] = id
	row["kind"] = kind
	row["bank"] = bank
	row["address"] = address
	row["map"] = Vector2i(map.group, map.number)
	row.merge(where, true)
	for key: String in LINK_ROLES:
		if row.has(key):
			row[key] = _gen1_address(int(row[key]))
	_store(row)


## Every site field the caller named, or every one there is when [param whole].
static func _gen1_same_site(held: Dictionary, fields: Dictionary, whole: bool = false) -> bool:
	for key: String in GEN1_SITE_FIELDS:
		if (whole or fields.has(key)) and held.get(key, null) != fields.get(key, null):
			return false
	return true


## The row at [param kind]'s site [param at] with [param fields], or empty.
func gen1_site(kind: StringName, at: int, fields: Dictionary) -> Dictionary:
	var id: int = pack_id(kind, RomFile.bank_of(at), _gen1_address(at))
	for variant: int in MAX_VARIANTS:
		var held: Variant = _rows.get(id | variant << ID_VARIANT_SHIFT, null)
		if held == null:
			return {}
		if _gen1_same_site(held, fields):
			return check(id | variant << ID_VARIANT_SHIFT)
	return {}


## The site a linked node at [param at] belongs to. See [constant LINK_ROLES].
func gen1_linked(kind: StringName, key: String, at: int, fields: Dictionary) -> Dictionary:
	var address: int = _gen1_address(at)
	for id: int in _by_kind.get(kind, []):
		var held: Dictionary = _rows[id]
		if int(held.get(key, -1)) == address and int(held.get("bank", -1)) == RomFile.bank_of(at) \
			and _gen1_same_site(held, fields):
			return check(id)
	return {}


## The GB address a linear offset is read at, as `Gen1Layout.banked` inverts it.
static func _gen1_address(linear: int) -> int:
	var bank: int = RomFile.bank_of(linear)
	return linear - bank * RomFile.BANK_SIZE + (RomFile.BANK_SIZE if bank > 0 else 0)


func _add_gen1_event(
	kind: StringName, map: Gen2WorldMap, source: int, index: int, fields: Dictionary,
	where: Dictionary
) -> void:
	var row: Dictionary = fields.duplicate()
	row["id"] = pack_event_id(kind, source, map.number, index)
	row["kind"] = kind
	row["map"] = Vector2i(map.group, map.number)
	row["event_index"] = index
	row["requires"] = []
	row.merge(where, true)
	_store(row)
