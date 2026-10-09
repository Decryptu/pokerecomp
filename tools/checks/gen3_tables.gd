extends RefCounted

## Generation 3's content, trainer, picture and world tables. Pins
## come from pret's data files; the sweeps catch a stride that reads plausibly.

const SPECIES_COUNT: int = 386
const MOVE_COUNT: int = 354
const MATCHUP_COUNT: int = 110
const FORESIGHT_MATCHUPS: int = 2
const HOENN_DEX_COUNT: int = 202
const EVOLUTION_COUNT: int = 184
const NO_FLIP_COUNT: int = 18
## FireRed and LeafGreen each carry their own `sDeoxysLevelUpLearnset`.
const LEARNSET_MOVES: Dictionary = {
	&"ruby": 3947, &"sapphire": 3947, &"firered": 4011, &"leafgreen": 4013, &"emerald": 3947,
}

const PINNED_SPECIES: Dictionary = {
	1: ["BULBASAUR", 1, 203, [45, 49, 49, 45, 65, 65], [12, 3], 45, 64, [0, 0], 31, 20, 3,
		[1, 7], [65, 0]],
	113: ["CHANSEY", 113, 277, [250, 5, 5, 50, 35, 105], [0, 0], 30, 255, [0, 197], 254, 40, 4,
		[6, 6], [30, 32]],
	252: ["TREECKO", 277, 1, [40, 45, 35, 70, 65, 55], [12, 12], 45, 65, [0, 0], 31, 20, 3,
		[1, 14], [65, 0]],
	292: ["SHEDINJA", 303, 44, [1, 90, 45, 40, 30, 30], [6, 7], 45, 95, [0, 0], 255, 15, 1,
		[10, 10], [25, 0]],
}
const WURMPLE: int = 265
const WURMPLE_EVOLUTIONS: Array = [[11, 7, 266], [12, 7, 268]]
const PINNED_MOVES: Dictionary = {
	98: ["QUICK ATTACK", 40, 0, 100, 30, 1],
	182: ["PROTECT", 0, 0, 0, 10, 3],
	264: ["FOCUS PUNCH", 150, 1, 100, 20, -3],
	354: ["PSYCHO BOOST", 140, 14, 90, 5, 0],
}
## Rows whose `itemId` is set: `ITEMS_COUNT` less the 68 `ITEM_NONE` rows.
const NAMED_ITEMS: Dictionary = {
	&"ruby": 281, &"sapphire": 281, &"firered": 307, &"leafgreen": 307, &"emerald": 309,
}
const LEFTOVERS: int = 200
const LEFTOVERS_PIN: Array = ["LEFTOVERS", 200, 43, 10, 1]
## FireRed and LeafGreen's POCKET_KEY_ITEMS is 2; the other three's is 5.
const MACH_BIKE: int = 259
const KEY_ITEMS_POCKET: Dictionary = {
	&"ruby": 5, &"sapphire": 5, &"firered": 2, &"leafgreen": 2, &"emerald": 5,
}
const LEVITATE: Array = [26, "LEVITATE", "Not hit by GROUND attacks."]
const PIKACHU_DEX: Array = ["MOUSE", 4, 60]
const BULBASAUR_SCALES: Dictionary = {
	&"ruby": [356, 17, 256, 0], &"sapphire": [356, 17, 256, 0],
	&"firered": [356, 16, 256, -2], &"leafgreen": [356, 16, 256, -2],
	&"emerald": [356, 17, 256, 0],
}
const DEX_PAGES: Dictionary = {
	&"ruby": 2, &"sapphire": 2, &"firered": 1, &"leafgreen": 1, &"emerald": 1,
}
const TYPE_NAMES: Array = [
	"NORMAL", "FIGHT", "FLYING", "POISON", "GROUND", "ROCK", "BUG", "GHOST", "STEEL",
	"???", "FIRE", "WATER", "GRASS", "ELECTR", "PSYCHC", "ICE", "DRAGON", "DARK",
]

var _r: RefCounted


func run(r: RefCounted) -> void:
	_r = r
	r.each_game_of(RomRegistry.GEN3, _one_game)


func _one_game() -> void:
	_species()
	_moves()
	_types()
	_items()
	_abilities()
	_dex_entries()
	_pictures()
	_trainers()
	_world_headers()
	_world_events()
	_world_graphics()
	_tileset_animations()
	_world_scripts()
	_world_script_data()
	_wild_encounters()
	_undecoded_text()


func _species() -> void:
	var data: GameData = _r.data
	if not _r.check(data.species_count() == SPECIES_COUNT,
		"%d species, not %d." % [data.species_count(), SPECIES_COUNT]):
		return
	var hoenn: Dictionary = {}
	var evolutions: int = 0
	var learnset_moves: int = 0
	var no_flip: int = 0
	for number: int in range(1, SPECIES_COUNT + 1):
		var entry: Dictionary = data.species(number)
		_r.check(int(entry["number"]) == number, "record %d is numbered %s." % [
			number, entry["number"],
		])
		var index: int = int(entry["index"])
		_r.check(index < 252 or index > 276, "%s is an unused Unown slot." % entry["name"])
		if int(entry["hoenn_number"]) <= HOENN_DEX_COUNT:
			hoenn[int(entry["hoenn_number"])] = true
		evolutions += data.evolutions(number).size()
		learnset_moves += data.learnset(number).size()
		no_flip += 1 if bool(entry["no_flip"]) else 0
	_r.check(hoenn.size() == HOENN_DEX_COUNT, "the Hoenn dex numbers %d species." % hoenn.size())
	_r.check(evolutions == EVOLUTION_COUNT, "%d evolutions." % evolutions)
	_r.check(learnset_moves == int(LEARNSET_MOVES[data.id]),
		"%d level-up moves." % learnset_moves)
	_r.check(no_flip == NO_FLIP_COUNT, "%d species are never flipped." % no_flip)
	for number: int in PINNED_SPECIES:
		_pinned_species(data, number, PINNED_SPECIES[number])
	var wurmple: Array = data.evolutions(WURMPLE).map(func(row: Dictionary) -> Array:
		return _ints([row["method"], row["parameter"], row["target"]]))
	_r.check(wurmple == WURMPLE_EVOLUTIONS, "Wurmple evolves by %s." % str(wurmple))


func _pinned_species(data: GameData, number: int, pin: Array) -> void:
	var entry: Dictionary = data.species(number)
	var stats: Dictionary = entry["stats"]
	var read: Array = [
		entry["name"], entry["index"], entry["hoenn_number"],
		[stats["hp"], stats["attack"], stats["defense"], stats["speed"],
			stats["sp_attack"], stats["sp_defense"]],
		entry["types"], entry["catch_rate"], entry["base_exp"], entry["items"],
		entry["gender_ratio"], entry["egg_cycles"], entry["growth_rate"],
		entry["egg_groups"], entry["abilities"],
	]
	_r.check(_ints(read) == pin, "species %d reads %s." % [number, str(read)])


static func _ints(value: Variant) -> Variant:
	if value is float:
		return int(value)
	if value is Array:
		return (value as Array).map(_ints)
	return value


func _moves() -> void:
	var data: GameData = _r.data
	if not _r.check(data.move_count() == MOVE_COUNT,
		"%d moves, not %d." % [data.move_count(), MOVE_COUNT]):
		return
	for number: int in PINNED_MOVES:
		var move: Dictionary = data.move(number)
		var read: Array = [
			move["name"], move["power"], move["type"], move["accuracy"], move["pp"],
			move["priority"],
		]
		_r.check(_ints(read) == PINNED_MOVES[number], "move %d reads %s." % [
			number, str(read),
		])


func _types() -> void:
	var data: GameData = _r.data
	var names: Array = []
	for type: int in TYPE_NAMES.size():
		names.append(data.type_name(type))
	_r.check(names == TYPE_NAMES, "gTypeNames reads %s." % str(names))
	var rows: Array = RomCache.read_json(RomCache.matchups_path(data.directory))
	_r.check(rows.size() == MATCHUP_COUNT, "%d matchups." % rows.size())
	var foresight: Array = rows.filter(func(row: Dictionary) -> bool:
		return bool(row["negated_by_foresight"]))
	_r.check(foresight.size() == FORESIGHT_MATCHUPS
		and foresight.all(func(row: Dictionary) -> bool: return int(row["defender"]) == 7),
		"Foresight lifts %s." % str(foresight))
	_r.check(data.type_matchup(10, 12) == 20 and data.type_matchup(0, 7) == 0
		and data.type_matchup(0, 7, true) == 10,
		"FIRE on GRASS is %d, NORMAL on GHOST %d and %d under Foresight." % [
			data.type_matchup(10, 12), data.type_matchup(0, 7), data.type_matchup(0, 7, true),
		])


func _items() -> void:
	var data: GameData = _r.data
	var named: int = 0
	for number: int in range(1, data.item_count() + 1):
		named += 0 if bool(data.item(number)["unused"]) else 1
	_r.check(named == int(NAMED_ITEMS[data.id]), "%d named items." % named)
	var leftovers: Dictionary = data.item(LEFTOVERS)
	var read: Array = _ints([
		leftovers["name"], leftovers["price"], leftovers["hold_effect"],
		leftovers["hold_effect_parameter"], leftovers["pocket"],
	])
	_r.check(read == LEFTOVERS_PIN, "item %d reads %s." % [LEFTOVERS, str(read)])
	var pocket: int = int(data.item(MACH_BIKE)["pocket"])
	_r.check(pocket == int(KEY_ITEMS_POCKET[data.id]), "MACH BIKE is in pocket %d." % pocket)


func _abilities() -> void:
	var data: GameData = _r.data
	var levitate: Dictionary = data.ability(int(LEVITATE[0]))
	var read: Array = [int(levitate["number"]), levitate["name"], levitate["description"]]
	_r.check(read == LEVITATE, "ability %d reads %s." % [LEVITATE[0], str(read)])
	_r.check(data.ability_count() == Gen3Layout.ABILITY_COUNT,
		"%d abilities." % data.ability_count())


func _dex_entries() -> void:
	var data: GameData = _r.data
	var pikachu: Dictionary = data.dex_entry(25)
	var read: Array = [pikachu["category"], pikachu["height"], pikachu["weight"]]
	_r.check(read == PIKACHU_DEX, "Pikachu's dex entry reads %s." % str(read))
	var dex: Dictionary = data.species(1)["dex"]
	var scales: Array = _ints([
		dex["pokemon_scale"], dex["pokemon_offset"], dex["trainer_scale"], dex["trainer_offset"],
	])
	_r.check(scales == BULBASAUR_SCALES[data.id], "Bulbasaur's scales read %s." % str(scales))
	for number: int in range(1, SPECIES_COUNT + 1):
		var pages: int = data.dex_entry(number)["pages"].size()
		if not _r.check(pages == int(DEX_PAGES[data.id]), "species %d has %d pages." % [
			number, pages,
		]):
			return


## A code [Gen3Text] has no glyph for decodes as `<$nn>`.
func _undecoded_text() -> void:
	var data: GameData = _r.data
	var texts: Array = []
	for number: int in range(1, data.item_count() + 1):
		texts.append_array([data.item(number)["name"], data.item(number)["description"]])
	for ability: int in data.ability_count():
		texts.append_array([data.ability(ability)["name"], data.ability(ability)["description"]])
	for number: int in range(1, SPECIES_COUNT + 1):
		texts.append(data.species(number)["name"])
		texts.append(data.dex_entry(number)["category"])
		texts.append_array(data.dex_entry(number)["pages"])
	for move: int in range(1, MOVE_COUNT + 1):
		texts.append(data.move(move)["name"])
	for trainer: int in range(1, data.trainer_count() + 1):
		texts.append_array([data.trainer(trainer)["name"], data.trainer(trainer)["class_name"]])
	for offset: int in data.world_script_offsets("texts"):
		var bytes: PackedByteArray = data.world_script_data("texts", offset)["bytes"]
		texts.append(Gen3Text.decode_fixed(data.id, bytes, 0, bytes.size()))
	var undecoded: Array = texts.filter(func(text: String) -> bool: return text.contains("<$"))
	_r.check(undecoded.is_empty(), "%d texts hold codes with no glyph, first %s." % [
		undecoded.size(), str(undecoded.slice(0, 1)),
	])


func _pictures() -> void:
	var data: GameData = _r.data
	for number: int in range(1, SPECIES_COUNT + 1):
		var entry: Dictionary = data.species(number)
		for back: bool in [false, true]:
			_picture_frames(data, entry, number, back)
		for shiny: bool in [false, true]:
			for form: int in (4 if number == 351 else 1):
				_r.check(data.palette(number, shiny, form).size() == 16,
					"%s palette %d." % [entry["name"], form])
	for back: bool in [false, true]:
		_unown_pictures(data, back)
	_picture_coordinates(data)
	var native: String = "front" if data.id in [RomRegistry.RUBY, RomRegistry.SAPPHIRE] else "front_1"
	_r.check(data.species_pic(386)["atlas"] == native, "Deoxys uses the wrong native picture.")


func _picture_frames(data: GameData, entry: Dictionary, number: int, back: bool) -> void:
	var kind: String = "back" if back else "front"
	var expected: int = 4 if number == 351 else 1
	if data.id == RomRegistry.EMERALD and not back \
		or number == 386 and data.id in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN, RomRegistry.EMERALD]:
		expected = maxi(expected, 2)
	_r.check(int(entry["pic_frames"][kind]) == expected,
		"%s %s frame count." % [entry["name"], kind])
	for frame: int in expected:
		var pic: Dictionary = data.species_pic(number, back, frame)
		var cell: Dictionary = Gen2PicImage.atlas_cell(
			data.atlas_indices(pic["atlas"]), data.atlas(pic["atlas"]), pic)
		_r.check(not cell.is_empty() and cell["indices"].size() == 4096,
			"%s %s frame %d." % [entry["name"], kind, frame])
	_r.check(data.species_pic(number, back, expected).is_empty(),
		"%s has an extra %s frame." % [entry["name"], kind])


func _unown_pictures(data: GameData, back: bool) -> void:
	var forms: Dictionary = {}
	for form: int in 28:
		var pic: Dictionary = data.unown_pic(form, back)
		var cell: Dictionary = Gen2PicImage.atlas_cell(
			data.atlas_indices(pic["atlas"]), data.atlas(pic["atlas"]), pic)
		forms[hash(cell.get("indices", PackedByteArray()))] = true
	_r.check(forms.size() == 28,
		"Unown has %d distinct %s forms." % [forms.size(), "back" if back else "front"])
	_r.check(data.unown_pic(28, back).is_empty(), "Unown has a 29th form.")


func _picture_coordinates(data: GameData) -> void:
	var coordinates: Dictionary = data.species(1)["pic_coordinates"]
	var front: Array = [40, 40, 16] if data.id in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN] else [32, 40, 14]
	for kind: String in ["front", "back"]:
		var row: Dictionary = coordinates[kind]
		var actual: Array = _ints([row["width"], row["height"], row["y_offset"]])
		_r.check(actual == (front if kind == "front" else [48, 32, 16]),
			"Bulbasaur's %s coordinates read %s." % [kind, actual])


## Trainer and party files pin one member of each stored format; the sweep
## reads every individual through GameData rather than treating IDs as classes.
func _trainers() -> void:
	var data: GameData = _r.data
	var layout: Dictionary = Gen3Layout.for_id(data.id)
	var expected: int = int(layout["trainer_count"]) - 1
	if not _r.check(data.trainer_count() == expected, "%d trainers, expected %d." % [data.trainer_count(), expected]):
		return
	var formats: Array[int] = [0, 0, 0, 0]
	for number: int in range(1, expected + 1):
		var trainer: Dictionary = data.trainer_party(number)
		formats[int(trainer["type"])] += 1
		_r.check(trainer["party"].size() >= 1 and trainer["party"].size() <= 6,
			"Trainer %d has an invalid party size." % number)
		_r.check(data.trainer_party_count(number) == 1 and data.trainer_palette(number).size() == 16,
			"Trainer %d loses its individual identity or palette." % number)
		_r.check(int(data.trainer_pic(number)["slot"]) == int(trainer["picture"]),
			"Trainer %d points at the wrong picture." % number)
		for mon: Dictionary in trainer["party"]:
			_r.check(not data.species(int(mon["species"])).is_empty(), "Trainer %d has an unknown species." % number)
	var wanted: Array = [570, 85, 28, 10]
	if data.id in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN]:
		wanted = [591, 103, 33, 15]
	elif data.id == RomRegistry.EMERALD:
		wanted = [672, 87, 31, 64]
	_r.check(formats == wanted, "Trainer formats read %s." % str(formats))
	_trainer_pins(data)
	_trainer_pictures(data, int(layout["trainer_pic_count"]))


func _trainer_pins(data: GameData) -> void:
	var pins: Array = [
		[1, "ARCHIE", 0, 0, 17, 367, 0, []],
		[44, "DUSTY", 1, 50, 24, 28, 0, [91, 163, 28, 40]],
		[114, "CINDY", 2, 0, 7, 263, 110, []],
		[123, "CINDY", 3, 40, 36, 264, 110, [154, 300, 316, 28]],
	]
	if data.id in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN]:
		pins = [
			[1, "", 0, 0, 5, 23, 0, []],
			[142, "LIAM", 1, 0, 10, 74, 0, [33, 111, 0, 0]],
			[317, "KOICHI", 2, 100, 37, 106, 207, []],
			[410, "LORELEI", 3, 250, 52, 87, 0, [58, 57, 258, 219]],
		]
	elif data.id == RomRegistry.EMERALD:
		pins = [
			[1, "SAWYER", 0, 0, 21, 74, 0, []],
			[38, "FELIX", 1, 0, 43, 308, 0, [94, 0, 0, 0]],
			[114, "CINDY", 2, 0, 7, 263, 110, []],
			[71, "RANDALL", 3, 255, 26, 277, 0, [98, 97, 17, 0]],
		]
	for pin: Array in pins:
		var trainer: Dictionary = data.trainer_party(int(pin[0]))
		var mon: Dictionary = trainer["party"][0]
		var read: Array = [trainer["number"], trainer["name"], trainer["type"],
			mon["iv"], mon["level"], mon["species"], mon["item"], mon["moves"]]
		_r.check(read == pin, "Trainer %d reads %s." % [pin[0], str(read)])


func _trainer_pictures(data: GameData, count: int) -> void:
	var atlas: Dictionary = data.atlas("trainers")
	_r.check(int(atlas.get("decoded", 0)) == count, "Trainer picture count is wrong.")
	for picture: int in count:
		var cell: Dictionary = Gen2PicImage.atlas_cell(data.atlas_indices("trainers"), atlas,
			{"slot": picture, "width": 64, "height": 64})
		_r.check(cell.get("indices", PackedByteArray()).size() == 4096,
			"Trainer picture %d has no complete canvas." % picture)


## Digests from pret's JSON, mapjson header macros, dex constants and version guards.
const WORLD_DIGESTS: Dictionary = {
	&"ruby": ["7e225f0558ba3446ca4c02694455bdb977c4e928", "1e5eb99dfe014cbd5596d91619708b2b6f77bc7a"],
	&"sapphire": ["7e225f0558ba3446ca4c02694455bdb977c4e928", "10f9050ad7971179f402a70f2cd221282e37f1c8"],
	&"firered": ["07a7769914957f3ca8659058c77c4192beaf92f3", "a73aff3744fb9c50e3540a0b438bd9b021308cd7"],
	&"leafgreen": ["07a7769914957f3ca8659058c77c4192beaf92f3", "60493acec2418434f26f133ea295a6428c1d3c69"],
	&"emerald": ["600d1953ed36f8bce6e1a7f9fb36faef02577587", "21b81d874fe6e968fcae613b32da081acb9f5948"],
}
const HEADER_FIELDS: Array[String] = [
	"group", "number", "width", "height", "border_width", "border_height", "music",
	"layout_id", "region_map_section", "requires_flash", "weather", "map_type",
	"battle_scene", "show_map_name", "flags", "escape_rope", "allow_cycling",
	"allow_escaping", "allow_running", "floor_number",
]


func _world_headers() -> void:
	var data: GameData = _r.data
	var lines := PackedStringArray(["maps"])
	for row: Dictionary in data.world_map_headers():
		var values := PackedStringArray()
		for field: String in HEADER_FIELDS:
			values.append(str(int(row.get(field, 0 if field == "floor_number" else -1))))
		var line: String = ",".join(values)
		for connection: Dictionary in row["connections"]:
			line += ";%d,%d,%d,%d" % [connection["direction"], connection["offset"],
				connection["group"], connection["number"]]
		lines.append(line)
		_r.check(data.world_map_header(int(row["group"]), int(row["number"])) == row,
			"Map header lookup loses its identity.")
	_r.check(data.map_count() == lines.size() - 1, "Map count omits headers.")
	_r.digest_matches("gen3_maps", lines, WORLD_DIGESTS[data.id][0])


func _wild_encounters() -> void:
	var data: GameData = _r.data
	var lines := PackedStringArray(["encounters"])
	for method: StringName in [&"land", &"water", &"rock_smash", &"old_rod", &"good_rod", &"super_rod"]:
		var table: Dictionary = data._encounters()[String(method)]
		_r.check(data.world_encounter_count(method) == table.size(), "Encounter count loses maps.")
		for key: String in table:
			var pair: PackedStringArray = key.split(":")
			var count: int = data.world_encounter_variant_count(method, int(pair[0]), int(pair[1]))
			for variant: int in count:
				var row: Dictionary = data.world_encounter(method, int(pair[0]), int(pair[1]), variant)
				var line: String = "%s,%s,%d,%d" % [method, key, variant, int(row.get("rate", -1))]
				for slot: Dictionary in row.get("slots", []):
					line += ";%d,%d,%d,%d,%d" % [slot["slot"], slot["min_level"],
						slot["max_level"], slot["species"], slot["chance"]]
				lines.append(line)
	_r.digest_matches("gen3_encounters", lines, WORLD_DIGESTS[data.id][1])


## pret map JSON/macros and script tables, with offsets from matching build symbols.
const EVENT_DIGESTS: Dictionary = {
	&"ruby": "9343b69feaec3595a851a17b99b4ab2cb1064a80",
	&"sapphire": "ace648c4f23fad92c03ba990a560340f3cf18d0d",
	&"firered": "b42f99c767235375dbc95743bfae12610b6534b5",
	&"leafgreen": "2f12017118537da51c0fac4e27707cbc633efd0d",
	&"emerald": "71476d93d1115db1f0b6ecbe88e165204590d5d0",
}


func _event_fields(record: Dictionary) -> String:
	var fields: Array = record.keys()
	fields.erase("conditions")
	fields.sort()
	var values := PackedStringArray()
	for field: String in fields:
		values.append("%s=%d" % [field, int(record[field])])
	return ",".join(values)


func _world_events() -> void:
	var data: GameData = _r.data
	var lines := PackedStringArray(["events"])
	for header: Dictionary in data.world_map_headers():
		var group: int = int(header["group"])
		var number: int = int(header["number"])
		var key: String = "%d:%d" % [group, number]
		var events: Dictionary = data.world_map_events(group, number)
		for kind: String in Gen3Events.KINDS:
			var records: Array = events[kind]
			for slot: int in records.size():
				lines.append("%s,%s,%d;%s" % [key, kind, slot, _event_fields(records[slot])])
		var scripts: Array = data.world_map_script_entries(group, number)
		for slot: int in scripts.size():
			lines.append("%s,scripts,%d;%s" % [key, slot, _event_fields(scripts[slot])])
			var conditions: Array = scripts[slot].get("conditions", [])
			for index: int in conditions.size():
				lines.append("%s,conditions,%d,%d;%s" % [key, slot, index, _event_fields(conditions[index])])
	_r.digest_matches("gen3_events", lines, EVENT_DIGESTS[data.id])


const GRAPHICS_DIGESTS: Dictionary = {
	&"ruby": "2fbd7453413635737c8cbb08c6b8f8fbe75b98eb",
	&"sapphire": "2fbd7453413635737c8cbb08c6b8f8fbe75b98eb",
	&"firered": "c6de08c87281acd3bb6bb2d77f8c7b272df5e421",
	&"leafgreen": "c6de08c87281acd3bb6bb2d77f8c7b272df5e421",
	&"emerald": "b6190121fc3b7936c8d40e67dac86e7b4e7f52b3",
}
const GRAPHICS_FIELDS: Array[String] = ["secondary", "tile_offset", "tile_count",
	"metatile_count", "attribute_size", "palette_offset", "palette_count"]


func _world_graphics() -> void:
	var data: GameData = _r.data
	var lines := PackedStringArray(["graphics"])
	var seen: Dictionary = {}
	for header: Dictionary in data.world_map_headers():
		var group: int = int(header["group"])
		var number: int = int(header["number"])
		var layout: Dictionary = data.world_map_layout(group, number)
		lines.append("%d:%d|%s|%s" % [group, number,
			_graphics_hash(layout["blocks"]), _graphics_hash(layout["border"])])
		for secondary: bool in [false, true]:
			var offset: int = int(header["secondary_tileset_offset" if secondary else "primary_tileset_offset"])
			if seen.has(offset):
				continue
			seen[offset] = true
			var tileset: Dictionary = data.world_map_tileset(group, number, secondary)
			var fields := PackedStringArray()
			for field: String in GRAPHICS_FIELDS:
				fields.append(str(int(tileset[field])))
			var hashes := PackedStringArray()
			for field: String in ["tiles", "palettes", "metatiles", "attributes"]:
				hashes.append(_graphics_hash(tileset[field]))
			lines.append("tileset|%s|%s" % [",".join(fields), "|".join(hashes)])
	_r.digest_matches("gen3_graphics", lines, GRAPHICS_DIGESTS[data.id])


## Each map tileset pair's queued copies; Unicorn runs of the pret builds agree.
const ANIMATION_FRAMES: int = 3840
const ANIMATION_DIGESTS: Dictionary = {
	&"ruby": "1118b45f88345dc03fa06f3a6a5dfac496d57d1b",
	&"sapphire": "fee0acb9fb18121628a09f7c123e52034e6ae80e",
	&"firered": "28c1178aff4a9d2c3f92261453b54a1e7555df87",
	&"leafgreen": "2118a87db78e2704aecf8d7291fdf7d5f4f99213",
	&"emerald": "1bc8ce0710c20ae0a70f8e79cd3b0c80b5b864ae",
}


func _tileset_animations() -> void:
	var data: GameData = _r.data
	var lines := PackedStringArray(["tileset animations"])
	var seen: Dictionary = {}
	for header: Dictionary in data.world_map_headers():
		var group: int = int(header["group"])
		var number: int = int(header["number"])
		var key: String = "%d,%d" % [header["primary_tileset_offset"], header["secondary_tileset_offset"]]
		if seen.has(key):
			continue
		seen[key] = true
		var animations: Array = [data.world_map_tileset(group, number)["animation"],
			data.world_map_tileset(group, number, true)["animation"]]
		lines.append("pair|%s|%s|%s" % [key, animations[0].get("name", ""), animations[1].get("name", "")])
		for animation: Dictionary in animations:
			for frame: String in animation.get("frames", {}):
				lines.append("frame|%s|%s" % [frame, _graphics_hash(animation["frames"][frame])])
		var state: Dictionary = Gen3TilesetAnims.start(animations[0], animations[1])
		for frame: int in ANIMATION_FRAMES:
			for copy: Dictionary in Gen3TilesetAnims.step(state):
				lines.append("%d|%d|%d|%d|%d" % [frame, copy.get("tile", -1), copy.get("palette", -1),
					copy["frame"], copy["bytes"]])
	_r.digest_matches("gen3_tileset_animations", lines, ANIMATION_DIGESTS[data.id])


func _graphics_hash(record: Dictionary) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA1)
	context.update(record["bytes"])
	return context.finish().hex_encode()


## Exact bytecode streams from pret handlers, with operand boundaries checked
## by executing the matching ARM builds; all map, standard and trainer roots.
const SCRIPT_DIGESTS: Dictionary = {
	&"ruby": "35573e1d144659df9b18056080b7d67609816c34",
	&"sapphire": "33448c15566cb87985d2e473344feb23aced588d",
	&"firered": "287f4afe8f34b99285d0765f3a0fd84d0a470e80",
	&"leafgreen": "8ca3097b0433a71e9c2ad0176fa4e64de3aeba15",
	&"emerald": "2e99da5402e4c038628af9648991935b786d6c09",
}


func _script_numbers(values: Array) -> String:
	var out := PackedStringArray()
	for value: Variant in values:
		out.append(str(int(value)))
	return ",".join(out)


func _world_scripts() -> void:
	var data: GameData = _r.data
	var lines := PackedStringArray(["scripts"])
	var index: int = 0
	while data.world_standard_script_offset(index) >= 0:
		lines.append("standard,%d,%d" % [index, data.world_standard_script_offset(index)])
		index += 1
	for offset: int in data.world_script_offsets():
		var row: Dictionary = data.world_script_instruction(offset)
		var bytes: PackedByteArray = row["bytes"]
		_r.check(bytes.size() == int(row["next_offset"]) - offset,
			"script %d's bytes disagree with its boundary." % offset)
		for target: int in row["script_offsets"]:
			_r.check(not data.world_script_instruction(target).is_empty(),
				"script %d has an uncached target %d." % [offset, target])
		if bool(row["fallthrough"]):
			_r.check(not data.world_script_instruction(int(row["next_offset"])).is_empty(),
				"script %d has no cached successor." % offset)
		lines.append("%d,%d,%s,%d,%d;%s;%s;%s" % [offset, row["opcode"], row["command"],
			row["next_offset"], int(row["fallthrough"]), _script_numbers(row["operands"]),
			_script_numbers(row["script_offsets"]), bytes.hex_encode()])
		_script_data_operands(data, offset, row)
	_r.digest_matches("gen3_scripts", lines, SCRIPT_DIGESTS[data.id])


func _script_data_operands(data: GameData, offset: int, row: Dictionary) -> void:
	for pointer: Array in Gen3Script._data_pointers(row):
		var value: int = int(pointer[1])
		if value != 0 and (value < Gen3Script.RAM_START or value >= Gen3Script.RAM_END):
			_r.check(not data.world_script_data(pointer[0], Gen3Layout.rom_offset(value)).is_empty(),
				"script %d names an uncached %s record." % [offset, pointer[0]])


## Every record starts on a label of the byte-matching pret build and ends where
## its source list or string does; movements and marts reassembled from source.
const SCRIPT_DATA_DIGESTS: Dictionary = {
	&"ruby": "adf843177e3fc84a9e67199835af88391b0052eb",
	&"sapphire": "cbf6d27dddc0ea9a396d63d1bafeeffc75d522ce",
	&"firered": "2e0b76b0898635673fb7b72ba33036e9077a6b25",
	&"leafgreen": "e313963370453f727d429f456889d46b7070d2d8",
	&"emerald": "2dc9c549056906b3dffb7c1d921b817e915a5768",
}


func _world_script_data() -> void:
	var data: GameData = _r.data
	var lines := PackedStringArray(["script data"])
	for table: String in Gen3Script.DATA_TABLES:
		for offset: int in data.world_script_offsets(table):
			var record: Dictionary = data.world_script_data(table, offset)
			lines.append("%s,%d;%s;%s;%s" % [table, offset,
				(record.get("bytes", PackedByteArray()) as PackedByteArray).hex_encode(),
				_script_numbers(record.get("format", [])), _script_numbers(record.get("entries", []))])
	_r.digest_matches("gen3_script_data", lines, SCRIPT_DATA_DIGESTS[data.id])
