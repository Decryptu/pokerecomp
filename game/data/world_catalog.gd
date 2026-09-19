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

## `id = kind << 40 | bank << 24 | absolute address`: two entry points into one
## routine overlap, so a (blob, offset) address would count a site once per blob.
## A map EVENT has no address and packs its group, map number and event index
## behind [constant ID_EVENT_BIT], so the two spaces cannot collide.
const ID_KIND_SHIFT: int = 40
const ID_BANK_SHIFT: int = 24
const ID_ADDRESS_MASK: int = 0xFFFFFF
const ID_EVENT_BIT: int = 0x800000

## `ObjectEventTypeArray.itemball`, and `BGEVENT_ITEM` for one under a tile.
const OBJECT_TYPE_ITEMBALL: int = Gen2WorldObject.OBJECTTYPE_ITEMBALL
const BGEVENT_ITEM: int = Gen2WorldAPI.BGEVENT_ITEM

## The guard against a decode that runs away.
const MAX_SCRIPT_COMMANDS: int = 4096

## The cache stores every script as a fixed 512-byte window, so a walk over the
## whole window would mostly decode what the ROM put after the script. The Game
## Corner's vendor, the busiest shape, is a loop and three prizes: five routines.
const MAX_ROUTINES: int = 16

## The sidecar's own shape. Bumped when a row, a link or a kind changes meaning,
## which rebuilds every cache's sidecar without touching the cache format.
const FORMAT_VERSION: int = 3

## A Generation 1 site node carries `at`, its instruction's linear ROM address,
## so its id is a Generation 2 command's. Table rows are map events whose group
## byte names the table.
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
## Oak's three balls all reach `OaksLabMonChoiceMenu`'s one `AddPartyMon`, so
## each distinct set of numbers at an address is its own row, numbered in walk
## order above the address. See [method gen1_site].
const ID_VARIANT_SHIFT: int = 16
const MAX_VARIANTS: int = 8
const ID_VARIANT_MASK: int = (MAX_VARIANTS - 1) << ID_VARIANT_SHIFT
const GEN1_SITE_FIELDS: Array[String] = [
	"species", "level", "item", "quantity", "trade", "badge", "price",
]

## The fields whose value is a StringName. See [method _restore_value].
const STRING_NAME_FIELDS: Array[String] = ["kind", "role"]
## The one Vector2i field, written as a two-element array.
const VECTOR_FIELDS: Array[String] = ["map"]

var _data: GameData = null
var _rows: Dictionary = {}
var _by_kind: Dictionary = {}
## `bank << 24 | address` of a command a site's fields also reach, to
## `{id, role}`. See [method link_at].
var _links: Dictionary = {}
## Built on first ask. See [method item_sources].
var _item_sources: Dictionary = {}
## Built on first ask. See [method field_hm_items].
var _field_hms: Array[int] = []

## Scripts [method build_reporting] decodes between two checks of the clock.
const SCAN_CHUNK: int = 64


## Walks every imported script and every map's events once;
## [method GameData.catalog] holds the result.
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
		# Measured rather than counted: one script costs whatever its commands
		# happen to cost, and what matters is a steady screen.
		if yield_ms > 0 and Time.get_ticks_msec() - last_yield >= yield_ms:
			last_yield = Time.get_ticks_msec()
			await Engine.get_main_loop().process_frame
	out._scan_map_events()
	out._attribute_maps()
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
	return {"version": FORMAT_VERSION, "rows": stored_rows, "links": links, "kinds": kinds}


## The counterpart, bound to [param data] so [method check] can still fold a mod
## patch in. Answers null for anything that is not this version's own shape, so
## a stale or truncated sidecar is rebuilt rather than half read.
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
	return out


## JSON has one number type and no StringName; readers compare with `==` against
## typed literals, so whole floats become ints and the two StringName fields
## name themselves.
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


## [param address] is the command's absolute address: the script's base plus the
## command's own offset inside it.
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


## The site a command at [param bank]:[param address] belongs to but is not
## itself, as `{id, role}`, or empty: what makes a patched field effective at the
## whole transaction, so the ball that shows a Bellsprout hands one over.
func link_at(bank: int, address: int) -> Dictionary:
	var value: Variant = _links.get((bank & 0xFF) << ID_BANK_SHIFT | (address & ID_ADDRESS_MASK), null)
	return value if value is Dictionary else {}


func rows(kind: StringName = &"") -> Array:
	var out: Array = []
	for id: int in ids(kind):
		out.append(check(id))
	return out


## The three species Elm's own balls offer, which is what a mod proving a seed
## traversable starts from. Empty on a cache whose scripts did not decode.
func possible_starters() -> Array[int]:
	var out: Array[int] = []
	for row: Dictionary in rows(KIND_STARTER):
		var species: int = int(row.get("species", 0))
		if species > 0 and not out.has(species):
			out.append(species)
	return out


## The HM items whose move is a field move, which are the rewards a placement
## must keep reachable. Read off the cartridge's own TM/HM move table rather
## than written down, so Gold and Crystal each answer for themselves.
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


## Which badge an engine flag grants, or -1. Public because a requirement names
## the FLAG and a placement reasons about the badge.
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


## Whether a later check may be gated behind this reward: a badge or a field HM.
func is_progression(row: Dictionary) -> bool:
	if StringName(row.get("kind", &"")) == KIND_BADGE:
		return true
	return field_hm_items().has(int(row.get("item", 0)))


## Every imported script. A command the decoder does not know ends its walk, the
## rule `scan_references` follows: a site past it would be at an invented offset.
func _script_keys() -> Array:
	return _data.world_script_keys()


## Scans `keys[from:upto]`, or all of them when [param upto] is negative. One
## body for both builders, so only how the walk is broken up differs.
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
	## The walk runs past `end` and `sjump`, since a blob holds a routine and the
	## branch bodies behind it, and stops at the first byte no command owns:
	## everything after would be text or a data table read as code.
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
	## A `pokepic` of the species a `givepoke` later hands over is the shape only
	## Elm's three balls take. The price is per SITE: a vendor's three branches
	## each spend their own `takecoins`.
	var pictured: Dictionary = {}
	for command: Dictionary in commands:
		if StringName(command["name"]) == &"pokepic":
			pictured[int(command.get("pokemon", 0))] = true
	for command: Dictionary in commands:
		_record_script_site(
			bank, address, command, commands,
			_coin_price(commands, int(command["offset"]), crystal), pictured, crystal
		)


## `takecoins`' own operand, which is the purchase price and is what makes a
## `givepoke` beside it a PRIZE rather than a gift. Read from the give's own
## branch, so a vendor's three prizes get three prices. Zero when the branch
## spends no coins at all, which is what makes a give a gift.
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
	## Each command's own decoded keys, not a positional operand list:
	## `Gen2WorldScript.command_at` names what it read.
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
			## The ball's own picture, and the two coin commands of the branch
			## this give sits in. Absolute addresses, so the runner finds them
			## from its own frame.
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
			## `loadwildmon` then `startbattle` is what a static encounter IS;
			## two bytes that merely decode as one are not.
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
			## `db dialog_id / dw mart_id`, so the dialog is the byte and the
			## mart index the word behind it.
			var mart: int = int(command.get("address", 0))
			## `world_mart` answers an out-of-range index with a default shelf.
			if mart < 0 or mart >= _data.world_mart_count():
				return
			_add(KIND_SHOP, bank, address, offset, {
				"mart": mart,
				"dialog": int(command.get("value", 0)),
				## The inventory this site sells, resolved to `{item, price}` so
				## a mod can move one row of one shop without inventing a mart.
				## Prices are the items' own until a patch names another.
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


## Where a command naming [param species] sits inside the blob, or -1. Used for
## the `pokepic` a starter's `givepoke` answers.
static func _address_of(commands: Array, name: StringName, species: int) -> int:
	for command: Dictionary in commands:
		if StringName(command["name"]) == name and int(command.get("pokemon", -1)) == species:
			return int(command["offset"])
	return -1


## The coin command of the BRANCH [param at] sits in, or -1. A branch is what
## lies between two terminators, which is how the Game Corner's vendor keeps
## three prices in one script: one `.loop` and a label per prize. Bounded that
## way, one coin command belongs to one give site and no two sites claim it.
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


## The offsets bounding the branch [param at] sits in: just past the terminator
## before it, up to and including the terminator after it.
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


## The mart list at [param index] as `{item, price}` rows, which is the shape
## [method Gen2WorldMartHost.entries] already reads.
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


## Stamps every script site with the MAP whose events reach it, following each
## map's scripts through `scall`, `sjump`, `farscall` and the branches. A script
## two maps reach is stamped with the first in map order, so the answer is stable.
func _attribute_maps() -> void:
	var crystal: bool = Gen2WorldState.is_crystal_profile(_data)
	var owner: Dictionary = {}
	## One scan per script for the whole corpus, not one per map that reaches it:
	## the busiest scripts are reached from dozens of maps.
	var references: Dictionary = {}
	for map: Gen2WorldMap in _data.world_maps():
		_walk_map_scripts(map, crystal, owner, references)
	var entries: Array = owner.keys()
	entries.sort()
	for id: Variant in _rows:
		var row: Dictionary = _rows[id]
		if row.has("map") or not row.has("address"):
			continue
		## A blob decodes past `end` into the script behind it, so the entry
		## point a site is reached through is the last one at or before it, no
		## earlier than the blob's own start: Goldenrod Dept Store 2F's clerks.
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


## Whether [param name] is the next few commands after [param at]. The cartridge
## puts `startbattle` immediately behind its `loadwildmon`, with at most a text
## or a flag between them.
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


## Which badge an engine flag grants, or -1. The two profiles number the badge
## block one apart, so the answer is the cartridge's own list rather than a
## constant.
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


## Item balls and hidden items are map EVENTS: `itemball`'s two bytes are the
## object's script pointer read as data, `hiddenitem` a [constant BGEVENT_ITEM].
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
	## The blob this site was decoded from, which is the address a map's own
	## event points at. See [method _attribute_maps].
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
	_store(row)


## A linear walk occasionally reads three bytes of text as a command; a row with
## numbers the cartridge cannot hold is one of those.
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


## The flags and items the script tested BEFORE this site: that the cartridge
## looked, not that the site is unreachable without them.
func _requirements(commands: Array, at: int, crystal: bool) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for command: Dictionary in commands:
		if int(command["offset"]) >= at:
			break
		## A condition before the last terminator guards an earlier routine:
		## reading the whole blob put thirteen conditions on a starter.
		if not Gen2WorldScript.continues_after(int(command["opcode"]), crystal):
			out.clear()
			seen.clear()
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


## Every Generation 1 site, each stamped with the map whose tree it stands in.
func _scan_gen1() -> void:
	for map: Gen2WorldMap in _data.world_maps():
		for index: int in map.texts.size():
			_walk_gen1(map, (map.texts[index] as Dictionary).get("script", []), [])
			_add_gen1_shop(map, index)
		for table: Variant in map.alternate_texts:
			for row: Dictionary in map.alternate_texts[table] as Array:
				_walk_gen1(map, row.get("script", []), [])
		for row: Dictionary in map.events.get("hidden_events", []) as Array:
			_walk_gen1(map, row.get("script", []), [], [], row)
		_walk_gen1(map, map.scripts.get("entry", []), [])
		for key: String in ["states", "callbacks"]:
			for row: Dictionary in map.scripts.get(key, []) as Array:
				_walk_gen1(map, row.get("nodes", []), [])
		_scan_gen1_objects(map)
	_scan_gen1_prizes()


## [param ancestors] is every node the walk is inside, where a site's conditions
## are read; [param scopes] every node list on the way down, where its routine's
## other stores are.
func _walk_gen1(
	map: Gen2WorldMap, nodes: Variant, ancestors: Array, scopes: Array = [],
	hidden: Dictionary = {}
) -> void:
	if not nodes is Array:
		return
	var here: Array = scopes + [nodes]
	for raw: Variant in nodes as Array:
		if not raw is Dictionary:
			continue
		var node: Dictionary = raw
		_record_gen1_site(map, node, ancestors, here, hidden)
		var below: Array = ancestors + [node]
		for branch: String in GEN1_BRANCHES:
			if node.has(branch):
				_walk_gen1(map, node[branch], below, here, hidden)
		for row: Variant in node.get("rows", []) as Array:
			if row is Dictionary:
				_walk_gen1(map, (row as Dictionary).get("then", []), below, here, hidden)


func _record_gen1_site(
	map: Gen2WorldMap, node: Dictionary, ancestors: Array, scopes: Array, hidden: Dictionary
) -> void:
	var at: int = int(node.get("at", -1))
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
			_add_gen1(kind, map, at, row, ancestors)
		"give_item":
			if node.has("hidden"):
				_add_gen1_event(KIND_ITEM, map, GEN1_SOURCE_HIDDEN, int(node["hidden"]), {
					"item": int(node["item"]), "quantity": 1, "hidden": true,
					"engine_flag": int(hidden.get("hidden_item_flag", 0)),
				}, ancestors)
			elif at >= 0:
				_add_gen1(KIND_ITEM, map, at, {
					"item": int(node["item"]), "quantity": maxi(1, int(node["count"])),
					"price": 0, "hidden": false,
				}, ancestors)
		"wild_battle":
			if at >= 0:
				_add_gen1(KIND_STATIC, map, at, {
					"species": int(node["species"]), "level": int(node["level"]),
				}, ancestors)
		"trade":
			if at >= 0:
				var record: Dictionary = _data.world_trade(int(node["trade_id"]))
				_add_gen1(KIND_TRADE, map, at, {
					"trade": int(node["trade_id"]),
					"species": int(record.get("offered_species", 0)),
					"requested_species": int(record.get("requested_species", 0)),
				}, ancestors)
		"flag":
			var badge: int = _badge_for_flag(int(node.get("flag", -1)))
			if at >= 0 and badge >= 0 and bool(node.get("engine", false)) and bool(node.get("set", false)):
				_add_gen1(KIND_BADGE, map, at, {
					"badge": badge, "engine_flag": int(node["flag"]),
				}, ancestors)


## `wPlayerStarter`'s store on the way to the give: Oak's balls, Yellow's Pikachu.
static func _gen1_starter_set(scopes: Array) -> int:
	for nodes: Array in scopes:
		for raw: Variant in nodes:
			if raw is Dictionary and String((raw as Dictionary).get("op", "")) == "set_starter" \
				and String((raw as Dictionary).get("who", "")) == "player":
				return int((raw as Dictionary).get("at", -1))
	return -1


## The `has_money` this give sits under whose price its `ok` branch spends: the
## Magikarp salesman. Empty for a give that costs nothing.
static func _gen1_price(ancestors: Array, node: Dictionary) -> Dictionary:
	for raw: Variant in node.get("ok", []) as Array:
		if not (raw is Dictionary and String((raw as Dictionary).get("op", "")) == "spend_money"):
			continue
		var spend: Dictionary = raw
		for above: Dictionary in ancestors:
			if String(above.get("op", "")) == "has_money" \
				and int(above.get("price", 0)) == int(spend.get("amount", 0)):
				return {
					"price": int(above["price"]),
					"ask_address": int(above.get("at", -1)), "spend_address": int(spend.get("at", -1)),
				}
	return {}


## What the tree tested on the way down: a flag, an item, a badge.
func _gen1_requirements(ancestors: Array) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for node: Dictionary in ancestors:
		match String(node.get("op", "")):
			"branch":
				var key: String = "engine_flag" if bool(node.get("engine", false)) else "event"
				_append_once(out, seen, {key: int(node.get("flag", 0))})
			"has_item":
				_append_once(out, seen, {"item": int(node.get("item", 0))})
			"badge":
				_append_once(out, seen, {
					"engine_flag": Gen2WorldState.gen1_badge_flag(int(node.get("badge", 0))),
				})
	return out


## `PickUpItem`'s item balls and `CheckForEngagingTrainers`' standing wilds.
func _scan_gen1_objects(map: Gen2WorldMap) -> void:
	var objects: Array = map.events.get("objects", [])
	for index: int in objects.size():
		var object: Dictionary = objects[index]
		if int(object.get("item", 0)) > 0:
			_add_gen1_event(KIND_ITEM, map, GEN1_SOURCE_OBJECT, index, {
				"item": int(object["item"]), "quantity": 1, "hidden": false,
			}, [])
		elif int(object.get("species", 0)) > 0 and not object.has("trainer_class"):
			_add_gen1_event(KIND_STATIC, map, GEN1_SOURCE_OBJECT, index, {
				"species": int(object["species"]), "level": int(object.get("level", 0)),
			}, [])


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
	}, [])


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
				KIND_PRIZE, map, GEN1_SOURCE_PRIZE, menu << GEN1_PRIZE_MENU_SHIFT | index, fields, []
			)


func _gen1_prize_map() -> Gen2WorldMap:
	for map: Gen2WorldMap in _data.world_maps():
		for row: Dictionary in map.texts:
			if int(row.get("command", 0)) == Gen1Layout.TEXT_SCRIPT_PRIZE_VENDOR:
				return map
	return null


func _add_gen1(
	kind: StringName, map: Gen2WorldMap, at: int, fields: Dictionary, ancestors: Array
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
	row["requires"] = _gen1_requirements(ancestors)
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


## The row at [param kind]'s site [param at] whose cartridge numbers are
## [param fields], patches folded in; empty for no such site.
func gen1_site(kind: StringName, at: int, fields: Dictionary) -> Dictionary:
	var id: int = pack_id(kind, RomFile.bank_of(at), _gen1_address(at))
	for variant: int in MAX_VARIANTS:
		var held: Variant = _rows.get(id | variant << ID_VARIANT_SHIFT, null)
		if held == null:
			return {}
		if _gen1_same_site(held, fields):
			return check(id | variant << ID_VARIANT_SHIFT)
	return {}


## The row whose [param key] is the node at [param at]: the site a linked node
## belongs to. See [constant LINK_ROLES].
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
	ancestors: Array
) -> void:
	var row: Dictionary = fields.duplicate()
	row["id"] = pack_event_id(kind, source, map.number, index)
	row["kind"] = kind
	row["map"] = Vector2i(map.group, map.number)
	row["event_index"] = index
	row["requires"] = _gen1_requirements(ancestors)
	_store(row)
