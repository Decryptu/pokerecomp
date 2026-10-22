extends RefCounted

## Generation 3's content, trainer, picture and world tables. Pins come from pret's data files; the sweeps
## catch a stride that reads plausibly.

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
	_map_grids()
	_field_camera()
	_object_events()
	_player_avatars()
	_step_anim_rows()
	_object_sprites()
	_shadows()
	_reflections()
	_weather()
	_object_sprite_frames()
	_held_movements()
	_object_movements(false)
	_object_movements(true)
	_copy_player_movements()
	_disguises()
	_trainer_sight()
	_berries()
	_berry_objects()
	_boulder_landings()
	_rotating_gates()
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


## Trainer and party files pin one member of each stored format; the sweep reads every individual through
## GameData rather than treating IDs as classes.
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


## Each map's backup buffer, `MapGridGet*` and `GetMapBorderIdAt` from one cell outside it, the words
## `DrawMetatileAt` reads for each id met, and the palettes `LoadMapTilesetPalettes` leaves, loading the maps
## in cache order; Unicorn runs of the pret builds agree.
const GRID_DIGESTS: Dictionary = {
	&"ruby": "73999b15622028930ea28c3ea77cb32c933ad07c",
	&"sapphire": "73999b15622028930ea28c3ea77cb32c933ad07c",
	&"firered": "5deba892bfe9c44296f89ea40eccc21d96092e9f",
	&"leafgreen": "5deba892bfe9c44296f89ea40eccc21d96092e9f",
	&"emerald": "91c9bea88f20ff61c8f0165b523ec28a9c71c4f1",
}


func _map_grids() -> void:
	var data: GameData = _r.data
	var lines := PackedStringArray(["map grids"])
	var grid: Gen3MapGrid = null
	for header: Dictionary in data.world_map_headers():
		grid = Gen3MapGrid.open(data, int(header["group"]), int(header["number"]), grid)
		var vram: Gen3FieldVram = Gen3FieldVram.load(grid.primary, grid.secondary)
		var words := PackedByteArray()
		for block: int in grid.blocks:
			words.append_array(_u16(block))
		var readers: Array = [PackedByteArray(), PackedByteArray(), PackedByteArray(),
			PackedByteArray(), PackedByteArray(), PackedByteArray()]
		var ids: Dictionary = {}
		for y: int in range(-1, grid.height + 1):
			for x: int in range(-1, grid.width + 1):
				ids[grid.metatile_id_at(x, y)] = true
				readers[0].append_array(_u16(grid.metatile_id_at(x, y)))
				readers[1].append_array(_u16(grid.collision_at(x, y)))
				readers[2].append_array(_u16(grid.elevation_at(x, y)))
				readers[3].append_array(_u16(grid.behavior_at(x, y)))
				readers[4].append_array(_u16(grid.layer_type_at(x, y)))
				readers[5].append_array(_u16(grid.border_id_at(x, y)))
		var drawn := PackedByteArray()
		var sorted: Array = ids.keys()
		sorted.sort()
		for id: int in sorted:
			drawn.append_array(_u16(id))
			for tile: Dictionary in grid.metatile(id)["tiles"]:
				drawn.append_array(_u16(Gen3FieldVram.entry(tile)))
		var hashes := PackedStringArray([_graphics_hash({"bytes": words})])
		for reader: PackedByteArray in readers + [drawn]:
			hashes.append(_graphics_hash({"bytes": reader}))
		var palettes: int = int(grid.secondary["palette_offset"]) + int(grid.secondary["palette_count"])
		hashes.append(_graphics_hash({"bytes": vram.palette.unfaded.slice(0, palettes * 32)}))
		lines.append("%d:%d|%d|%d|%s" % [header["group"], header["number"], grid.width, grid.height,
			"|".join(hashes)])
	_r.digest_matches("gen3_map_grids", lines, GRID_DIGESTS[data.id])


## Per map, `GetMapConnectionAtPos` from one cell outside the backup map and `CanCameraMoveInDirection` from
## the layout's edge cells; then every step, diagonals included, that `CameraMove` takes off that edge into
## another map, from the map freshly loaded with its view rewritten through the `MapGridSet*`s (Ruby and
## Sapphire lack the impassability one). Unicorn runs of the pret builds agree, `LoadMapFromCameraTransition`
## reduced to `InitMapLayoutData`; `null` is a step whose connection the cartridge reads from address 0.
const CAMERA_DIGESTS: Dictionary = {
	&"ruby": "ec5ee5d414055c5028ec98dd9b5012c7c6f13ce5",
	&"sapphire": "ec5ee5d414055c5028ec98dd9b5012c7c6f13ce5",
	&"firered": "d4663b8087cebfce8245ec7f8e39e7964437d5e8",
	&"leafgreen": "d4663b8087cebfce8245ec7f8e39e7964437d5e8",
	&"emerald": "5d7e7243855373cb52c471df9c584472827caa70",
}


func _field_camera() -> void:
	var data: GameData = _r.data
	var lines := PackedStringArray(["field camera"])
	var camera: Gen3FieldCamera = null
	for header: Dictionary in data.world_map_headers():
		var group: int = int(header["group"])
		var number: int = int(header["number"])
		camera = _camera_at(camera, data, group, number, Vector2i.ZERO)
		var connections := PackedByteArray()
		for y: int in range(-1, camera.grid.height + 1):
			for x: int in range(-1, camera.grid.width + 1):
				connections.append(header["connections"].find(camera.connection_at(x, y)) & 0xFF)
		var moves := PackedByteArray()
		var crossings: Array = []
		for at: Vector2i in _edge_cells(header):
			camera.pos = at
			for direction: int in range(1, Gen3FieldCamera.DIRECTIONS.size()):
				moves.append(int(camera.can_move(direction)))
				var target: Vector2i = at + Gen3FieldCamera.DIRECTIONS[direction] \
					+ Vector2i.ONE * Gen3MapGrid.MAP_OFFSET
				if camera.grid.border_id_at(target.x, target.y) > Gen3MapGrid.Connection.NONE:
					crossings.append([at, direction])
		lines.append("%d:%d|%s|%s" % [group, number, _graphics_hash({"bytes": connections}),
			_graphics_hash({"bytes": moves})])
		for crossing: Array in crossings:
			camera = _camera_at(camera, data, group, number, crossing[0])
			_mark_view(camera)
			if not camera.move(Gen3FieldCamera.DIRECTIONS[crossing[1]]):
				lines.append("%d,%d|%d|null" % [crossing[0].x, crossing[0].y, crossing[1]])
				continue
			lines.append("%d,%d|%d|%d:%d|%d,%d|%d,%d|%s" % [crossing[0].x, crossing[0].y, crossing[1],
				camera.group, camera.number, camera.pos.x, camera.pos.y, camera.shift.x, camera.shift.y,
				_graphics_hash({"bytes": camera.grid.blocks.to_byte_array()})])
	_r.digest_matches("gen3_field_camera", lines, CAMERA_DIGESTS[data.id])


func _camera_at(camera: Gen3FieldCamera, data: GameData, group: int, number: int,
		at: Vector2i) -> Gen3FieldCamera:
	if camera == null:
		return Gen3FieldCamera.open(data, group, number, at)
	camera.load_map(group, number)
	camera.pos = at
	return camera


func _edge_cells(header: Dictionary) -> Array[Vector2i]:
	var width: int = int(header["width"])
	var height: int = int(header["height"])
	var out: Array[Vector2i] = []
	for y: int in height:
		for x: int in width:
			if x == 0 or y == 0 or x == width - 1 or y == height - 1:
				out.append(Vector2i(x, y))
	return out


## Distinct ids with collision over the whole view, one whole word, and one cell's collision cleared.
func _mark_view(camera: Gen3FieldCamera) -> void:
	for y: int in Gen3FieldCamera.VIEW_HEIGHT:
		for x: int in Gen3FieldCamera.VIEW_WIDTH:
			camera.grid.set_metatile_id(camera.pos.x + x, camera.pos.y + y, 0xFC00 | (x + y * 15) * 7)
	camera.grid.set_metatile_entry(camera.pos.x, camera.pos.y, 0xABCD)
	camera.grid.set_impassable(camera.pos.x + 7, camera.pos.y + 7, false)


## Per map: a snake over every fourth layout position spawning and removing objects; `GetCollisionAtCoords`
## and `ObjectEventUpdateElevation` for a probe varied by cell over the whole backup map, and for each object
## left around it; every fourth straight crossing from a fresh spawn. Flags divisible by three below 0x900 are
## set; graphics var v holds 7v + 1. Unicorn runs of the pret builds agree, spawning reduced to
## `InitObjectEventStateFromTemplate` and the camera transition to the header, location, templates, temporary
## clear and grid.
const OBJECT_DIGESTS: Dictionary = {
	&"ruby": "28e50c92a767aba32f76a40356e08d6f29690f93",
	&"sapphire": "28e50c92a767aba32f76a40356e08d6f29690f93",
	&"firered": "e60c99f8a372d163804ef679f1a69aa8f9c06691",
	&"leafgreen": "e60c99f8a372d163804ef679f1a69aa8f9c06691",
	&"emerald": "9182c519b823d158a6b16870c7759709d7d36673",
}
const PROBE_BEHAVIORS: Array[int] = [0, 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0xBE, 0xC0, 0xC1]
const STRAIGHT: Array[int] = [Gen3ObjectEvents.Direction.SOUTH, Gen3ObjectEvents.Direction.NORTH,
	Gen3ObjectEvents.Direction.WEST, Gen3ObjectEvents.Direction.EAST]


func _object_events() -> void:
	var data: GameData = _r.data
	var lines := PackedStringArray(["object events"])
	var camera: Gen3FieldCamera = null
	for header: Dictionary in data.world_map_headers():
		var group: int = int(header["group"])
		var number: int = int(header["number"])
		camera = _camera_at(camera, data, group, number, Vector2i.ZERO)
		var objects: Gen3ObjectEvents = _fresh_objects(camera)
		var walk := PackedStringArray()
		for at: Vector2i in _snake(header):
			camera.pos = at
			objects.spawn_in_view()
			objects.remove_outside_view()
			walk.append(_objects_state(objects))
		lines.append("%d:%d|%s|%s|%s" % [group, number, "\n".join(walk).sha1_text(),
			_graphics_hash({"bytes": _probe_sweep(objects)}),
			_graphics_hash({"bytes": _object_sweep(objects)})])
		for at: Vector2i in _edge_cells(header):
			if (at.x + at.y) % 4 != 0:
				continue
			for direction: int in STRAIGHT:
				var step: Vector2i = Gen3FieldCamera.DIRECTIONS[direction]
				var target: Vector2i = at + step + Vector2i.ONE * Gen3MapGrid.MAP_OFFSET
				camera = _camera_at(camera, data, group, number, at)
				if camera.grid.border_id_at(target.x, target.y) <= Gen3MapGrid.Connection.NONE:
					continue
				objects = _fresh_objects(camera)
				objects.spawn_in_view()
				objects.remove_outside_view()
				camera.move(step)
				objects.follow_camera()
				lines.append("%d,%d|%d|%d:%d|%s" % [at.x, at.y, direction, camera.group, camera.number,
					_objects_state(objects).sha1_text()])
	_r.digest_matches("gen3_object_events", lines, OBJECT_DIGESTS[data.id])


func _fresh_objects(camera: Gen3FieldCamera) -> Gen3ObjectEvents:
	var events := Gen3EventData.new(camera.data.id)
	for flag: int in range(3, 0x900, 3):
		events.flag_set(flag)
	for slot: int in 16:
		events.var_set(Gen3ObjectEvents.VAR_OBJ_GFX_ID_0 + slot, slot * 7 + 1)
	return Gen3ObjectEvents.new(camera, events)


func _snake(header: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var columns: Array = range(0, int(header["width"]), 4)
	for y: int in range(0, int(header["height"]), 4):
		for x: int in columns:
			out.append(Vector2i(x, y))
		columns.reverse()
	return out


func _objects_state(objects: Gen3ObjectEvents) -> String:
	var out := PackedStringArray()
	for object: Gen3ObjectEvents.ObjectEvent in objects.objects:
		if not object.active:
			out.append("-")
			continue
		out.append(",".join(Array([object.local_id, object.map_number, object.map_group,
			object.graphics_id, object.movement_type, object.trainer_type, object.trainer_range,
			object.initial.x, object.initial.y, object.current.x, object.current.y,
			object.previous.x, object.previous.y, object.current_elevation, object.previous_elevation,
			object.facing, object.movement_direction, object.movement_range.x, object.movement_range.y,
			object.previous_movement_direction]).map(str)))
	var temp: int = 0
	for flag: int in 0x20:
		temp |= int(objects.events.flag_get(flag)) << flag
	out.append(str(temp))
	return "/".join(out)


## One probe step onto every cell from one outside the backup map: the collision, then the elevations
## `ObjectEventUpdateElevation` leaves.
func _probe_sweep(objects: Gen3ObjectEvents) -> PackedByteArray:
	var grid: Gen3MapGrid = objects.camera.grid
	var out := PackedByteArray()
	for y: int in range(-1, grid.height + 1):
		for x: int in range(-1, grid.width + 1):
			var direction: int = 1 + posmod(x + y, 4)
			var probe := Gen3ObjectEvents.ObjectEvent.new()
			var from: Vector2i = Vector2i(x, y) - Gen3FieldCamera.DIRECTIONS[direction]
			probe.initial = Vector2i(x + posmod(x, 5) - 2, y + posmod(y, 5) - 2)
			probe.movement_range = Vector2i(posmod(x + y, 3), posmod(x * y, 3))
			probe.current_elevation = posmod(x + 2 * y, 16)
			probe.current_behavior = PROBE_BEHAVIORS[posmod(x * 5 + y * 3, PROBE_BEHAVIORS.size())]
			probe.tracked_by_camera = posmod(x * y, 2) == 1
			out.append(objects.collision_at(probe, x, y, direction))
			probe.current = Vector2i(x, y)
			probe.previous = from
			objects.update_elevation(probe)
			out.append(probe.current_elevation | probe.previous_elevation << 4)
	return out


## Each object left after the walk stepping onto the 5x5 cells around it.
func _object_sweep(objects: Gen3ObjectEvents) -> PackedByteArray:
	var out := PackedByteArray()
	for object: Gen3ObjectEvents.ObjectEvent in objects.objects:
		if not object.active:
			continue
		for dy: int in range(-2, 3):
			for dx: int in range(-2, 3):
				out.append(objects.collision_at(object, object.current.x + dx, object.current.y + dy,
					STRAIGHT[posmod(dx * 3 + dy, 4)]))
	return out


## `InitPlayerAvatar`, graphics/state queries and player collisions on every backup-map cell. The cartridge
## oracle stubs sprite creation, movement tasks, statistics and rotating gates; it records the collision and
## requested effect.
const AVATAR_DIGESTS: Dictionary = {
	&"ruby": "70c026c1da56b0013580db93ddbe0d392350c547",
	&"sapphire": "70c026c1da56b0013580db93ddbe0d392350c547",
	&"firered": "0db911d2e298eddf74855562006ff21bbcf9373b",
	&"leafgreen": "0db911d2e298eddf74855562006ff21bbcf9373b",
	&"emerald": "607af253e0924fac53aeb378b91761d822cdb1b5",
}


func _player_avatars() -> void:
	var data: GameData = _r.data
	var lines := PackedStringArray(["player avatars"])
	var camera: Gen3FieldCamera = null
	for header: Dictionary in data.world_map_headers():
		var group: int = int(header["group"])
		var number: int = int(header["number"])
		var at := Vector2i(int(header["width"]) >> 1, int(header["height"]) >> 1)
		camera = _camera_at(camera, data, group, number, at)
		var initial := PackedStringArray()
		var avatar: Gen3PlayerAvatar
		for gender: int in 2:
			for direction: int in STRAIGHT:
				var objects: Gen3ObjectEvents = _fresh_objects(camera)
				avatar = Gen3PlayerAvatar.open(objects, at + Vector2i.ONE * Gen3MapGrid.MAP_OFFSET, direction, gender)
				if not _r.check(avatar != null, "player spawn at %d:%d" % [group, number]):
					return
				initial.append("%s|%d|%d|%d" % [_objects_state(objects), avatar.flags, avatar.gender,
					int(avatar.object().is_player)])
		if lines.size() == 1:
			lines.append(_avatar_states(avatar))
		avatar.objects.spawn_in_view()
		avatar.objects.events.flag_set(Gen3EventData.STRENGTH_FLAG[data.id])
		lines.append("%d:%d|%s|%s" % [group, number, "\n".join(initial).sha1_text(),
			_graphics_hash({"bytes": _avatar_sweep(avatar)})])
	_r.digest_matches("gen3_player_avatars", lines, AVATAR_DIGESTS[data.id])


## ARM held-dispatcher traces over cached lists on a uniform synthetic grid. Reset at actions [method
## arm_traced] leaves out; this checks supported runs, not execution.
const MOVEMENT_ORIGIN := Vector2i(256, 256)
const MOVEMENT_DIGESTS: Dictionary = {
	&"ruby": "a8839e8a87ce4510556789871dc4eec714ff61fc",
	&"sapphire": "0e2662533b908e0fa5ee3fdc4c75e8c7e359cb46",
	&"firered": "fd7c7771dd96cce0fc2158812ce8d027afb91502",
	&"leafgreen": "1573c5dd5f93bc7f277431e660e99c2adb9d1f7c",
	&"emerald": "eee953c8504dcf0dc8f7b0c1b60d61a3d37db09b",
}


## Rows (and Mauville rows) `GetStepAnimTable` finds, counted from pret's graphics infos.
const STEP_ANIM_ROWS: Dictionary = {
	&"ruby": [218, 0], &"sapphire": [218, 0], &"firered": [129, 0], &"leafgreen": [129, 0],
	&"emerald": [165, 7],
}
const STEP_POSITIONS: Array = [1, 3, 0, 2]


func _step_anim_rows() -> void:
	var data: GameData = _r.data
	var counts: Array = []
	for mauville: bool in [false, true]:
		var count: int = 0
		var index: int = 0
		while not data.world_object_graphics(index, mauville).is_empty():
			var positions: Array = data.world_object_graphics(index, mauville)["step_positions"]
			_r.check(positions.is_empty() or positions == STEP_POSITIONS,
				"graphics %d steps at %s" % [index, positions])
			count += int(not positions.is_empty())
			index += 1
		counts.append(count)
	_r.check(counts == STEP_ANIM_ROWS[data.id], "step anim rows %s (want %s)" % [counts, STEP_ANIM_ROWS[data.id]])


## Sprite rows, subsprites, frames, berry pics and palette tables; a scratch oracle over pret's sources agrees.
const SPRITE_DIGESTS: Dictionary = {
	&"ruby": "e4d02be8fce5837b763cb3df4f18daee76eea074",
	&"sapphire": "1b3eeb077d91f05010cd89a12a46b32bb4237b70",
	&"firered": "081ed149a755103cd26b8b2f05c2fa27c19f77fd",
	&"leafgreen": "081ed149a755103cd26b8b2f05c2fa27c19f77fd",
	&"emerald": "ace9716dcdc239d5428a0dc15f0fbbf196323427",
}
const SPRITE_FIELDS: Array[String] = ["palette_tag", "reflection_palette_tag", "size", "width", "height",
	"palette_slot", "shadow_size", "inanimate", "disable_reflection_palette_load", "tracks"]


func _object_sprites() -> void:
	var data: GameData = _r.data
	var lines := PackedStringArray(["object sprites"])
	var graphics: Dictionary = {"object_graphics": [], "mauville_graphics": []}
	for mauville: bool in [false, true]:
		var index: int = 0
		while not data.world_object_graphics(index, mauville).is_empty():
			var info: Dictionary = data.world_object_graphics(index, mauville)
			graphics["mauville_graphics" if mauville else "object_graphics"].append(info)
			var fields := PackedStringArray()
			for field: String in SPRITE_FIELDS:
				fields.append(str(int(info[field])))
			lines.append("%d|%s|%s|%s|%s" % [index, ",".join(fields), JSON.stringify(info["oam"]),
				JSON.stringify(info["subsprite_tables"]), _frames_hash(data, info["images"])])
			index += 1
	for berry: int in range(1, 45):
		var row: Dictionary = data.world_berry(berry)
		if row.has("berry_images"):
			lines.append("berry %d|%s" % [berry, _frames_hash(data, data.world_sprite_images(int(row["berry_images"])))])
	var sets: Dictionary = data.world_object_palette_sets()
	if not Gen3World._palette_tags_found(sets, graphics):
		_r.fail("object or reflection palette lookup has no palette")
	for row: Array in sets["rows"]:
		lines.append("palette %d|%s" % [int(row[0]), data.world_object_palette(int(row[0])).hex_encode()])
	for key: String in ["tag_sets", "player_reflections", "special_reflections"]:
		lines.append("%s|%s" % [key, JSON.stringify(sets[key])])
	_r.digest_matches("gen3_object_sprites", lines, SPRITE_DIGESTS[data.id])


## Pins from pret's shadow PNG indices and `metatile_behavior.c`, independently encoded in scratch.
func _shadows() -> void:
	var data: GameData = _r.data
	var pictures := PackedStringArray()
	for size: int in 4:
		var row: Dictionary = data.world_shadow_graphics(size)
		if row.is_empty() or row["images"].size() != 1:
			_r.fail("shadow %d has no frame" % size)
			return
		var frame: Array = row["images"][0]
		var digest := HashingContext.new()
		digest.start(HashingContext.HASH_SHA1)
		digest.update(data.world_sprite_image(int(frame[0]), int(frame[1])))
		pictures.append("%d|%d|%s" % [row["width"], row["height"], digest.finish().hex_encode()])
	_r.digest_matches("gen3_shadow_graphics", pictures, "376e6dcd88c957b744a23552f8581c29ae33fc03")
	var objects: Gen3ObjectEvents = _fresh_objects(_camera_at(null, data, 0, 0, Vector2i.ZERO))
	var object := Gen3ObjectEvents.ObjectEvent.new()
	object.active = true
	object.local_id = 254
	object.has_shadow = true
	object.ground_on_spawn = false
	object.frozen = true
	objects.objects[0] = object
	for slot: int in range(1, Gen3ObjectEvents.COUNT):
		objects.objects[slot].active = false
	var lines := PackedStringArray()
	for behavior: int in 256:
		for previous: bool in [false, true]:
			object.current_behavior = 0 if previous else behavior
			object.previous_behavior = behavior if previous else 0
			var requests: Array = []
			objects.start_effect_sprite(object, 0, Gen3ObjectEvents.FLDEFF_SHADOW, -1, true, requests)
			objects.step_movements()
			lines.append("%d|%d|%d" % [behavior, int(previous), int(objects.field_effect_active(Gen3ObjectEvents.FLDEFF_SHADOW))])
			object.has_shadow = false
			objects.step_movements()
			object.has_shadow = true
	var frlg: bool = data.id in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN]
	_r.digest_matches("gen3_shadow_terrain", lines,
		"c5e1aa6d98c902bc44bfc063531a1574a6eb0c6f" if frlg else (
			"ccf3a9ad0aa72adb76b88e67bcd67ef4c8740273" if data.id == RomRegistry.EMERALD else
			"4661fbb9e10ddc159c17ea1456349ff3c9a36629"))


## Original `LoadObjectReflectionPalette` plus both paired-palette loaders, compiled in scratch against
## every imported graphics row and the cartridge's palette tables; weather processing is not run here.
const REFLECTION_DIGESTS: Dictionary = {
	&"ruby": "d351a1d98be77430ccdfaea35f9cb4d33fb36818",
	&"sapphire": "d351a1d98be77430ccdfaea35f9cb4d33fb36818",
	&"firered": "37371d78035ae6aabdccde382ca9a96be6a57db2",
	&"leafgreen": "37371d78035ae6aabdccde382ca9a96be6a57db2",
	&"emerald": "42b64dcc0a39d5475548ea68e4f87233a5d5aa8e",
}


func _reflections() -> void:
	var data: GameData = _r.data
	var objects: Gen3ObjectEvents = _fresh_objects(_camera_at(null, data, 0, 0, Vector2i.ZERO))
	var object := Gen3ObjectEvents.ObjectEvent.new()
	objects.objects[0] = object
	var lines := PackedStringArray()
	var row: int = 0
	for mauville: bool in [false, true]:
		var index: int = 0
		while not data.world_object_graphics(index, mauville).is_empty():
			var info: Dictionary = data.world_object_graphics(index, mauville)
			objects._graphics[0] = info
			object.palette_num = int(info["palette_slot"])
			lines.append_array(_reflection_palette_trace(objects, row))
			index += 1
			row += 1
	_r.digest_matches("gen3_reflection_palettes", lines, REFLECTION_DIGESTS[data.id])


## The weather's sprite palette, rain sheet and drought tables against pret's `.pal`, `.png` and `.bin` files,
## then a stream: every weather from a map header through the warp's fade in, a change of weather, a sprite
## palette load and a lightning-style ramp, preserved palettes, and fades out and back in, with every raindrop,
## the thunder and the RNG each frame under a moving sprite offset. Original `field_weather.c`, `palette.c`,
## `trig.c`, the palette and rain weathers' `field_weather_effect.c` callbacks and `sprite.c`'s anim
## interpreter, compiled in scratch with the other sprite weathers reduced to their colour-map targets, give the
## same stream frame for frame.
const WEATHER_DIGESTS: Dictionary = {
	&"ruby": ["b0ccb1578796a90c086bf3ba221a31ff520f3e39", "f44a3a05d5c780b7543c8a4d571009eaa8a5adeb"],
	&"sapphire": ["b0ccb1578796a90c086bf3ba221a31ff520f3e39", "f44a3a05d5c780b7543c8a4d571009eaa8a5adeb"],
	&"firered": ["32365ce37c6575ffadb11b77eb42c9c3c60bbd43", "833d02ac22e31a11285b7d76f946ba6efc6bc6c2"],
	&"leafgreen": ["32365ce37c6575ffadb11b77eb42c9c3c60bbd43", "833d02ac22e31a11285b7d76f946ba6efc6bc6c2"],
	&"emerald": ["290d0144569a630738de246ed43d515edd71f414", "63d8bb6eacb3797d8690175706b3d2b174ec0d16"],
}
const WEATHER_CHANGES: Array[int] = [3, 11, 0, 12, 2, 6]
## Frames after each of the stream's phases.
const WEATHER_PHASES: Array[int] = [150, 100, 10, 30, 60, 20, 40]


func _weather() -> void:
	var data: GameData = _r.data
	var imported: Dictionary = data.world_weather()
	var colors: PackedByteArray = imported.get("palette", PackedByteArray())
	var lines := PackedStringArray(["palette|" + colors.hex_encode(),
		"rain|" + _graphics_hash({"bytes": imported.get("rain", PackedByteArray())})])
	var tables: Array = imported.get("drought", [])
	for index: int in tables.size():
		lines.append("drought|%d|%s" % [index, _graphics_hash({"bytes": tables[index]})])
	lines.append("summed|%s" % str(imported.get("summed", false)))
	_r.digest_matches("gen3_weather_tables", lines, WEATHER_DIGESTS[data.id][0])
	var stream := PackedStringArray()
	for weather: int in 22:
		stream.append_array(weather_stream(data, weather))
	_r.digest_matches("gen3_weather_palettes", stream, WEATHER_DIGESTS[data.id][1])


## One run of the weather stream for map weather [param run], every phase [param span] times shorter.
static func weather_stream(data: GameData, pass_index: int, span: int = 1) -> PackedStringArray:
	var palette := Gen3Palette.new()
	var events := Gen3EventData.new(data.id)
	var weather := Gen3FieldWeather.new(data, palette, events)
	events.weather_cycle_stage = pass_index % 4
	events.random.value = 0x5EED0000 + pass_index
	var thunder: Array[int] = [0, 0]
	weather.sprites.thunder.connect(func(second: bool) -> void:
		thunder[0] += 1
		thunder[1] = int(second))
	var x: int = 0x1234 + pass_index
	for index: int in Gen3Palette.COLORS:
		x = (x * 1103515245 + 12345) & 0xFFFFFFFF
		var color: int = Gen3FieldWeather.RUBY_KEPT_COLOR if index % 7 == 3 else (x >> 16) & 0x7FFF
		palette.unfaded.encode_u16(index * 2, color)
	palette.faded = palette.unfaded.duplicate()
	weather.set_saved_from_header({"weather": pass_index})
	weather.start()
	weather.resume_paused()
	palette.faded.fill(0)
	weather.fade_screen(Gen3FieldWeather.Fade.FROM_BLACK, 0)
	weather.run_tasks()
	if weather.locked:
		return PackedStringArray(["%d|hang" % pass_index])
	var lines := PackedStringArray([_weather_frame(weather, pass_index, 0, thunder, false)])
	var phases: Array[Callable] = [
		func() -> void: weather.set_weather(WEATHER_CHANGES[pass_index % WEATHER_CHANGES.size()]),
		func() -> void:
			weather.update_sprite_palette(3)
			weather.apply_if_idle_gradual(19, 3, 5),
		func() -> void:
			weather.preserve_palette(20)
			weather.apply_to_palette(20)
			weather.apply_to_palette(21)
			weather.reset_preserved()
			weather.apply_to_palette(4)
			weather.fade_screen(Gen3FieldWeather.Fade.TO_BLACK, 0),
		func() -> void: weather.update_sprite_palette(5),
		func() -> void:
			weather.fade_screen(Gen3FieldWeather.Fade.FROM_WHITE, 2)
			weather.update_sprite_palette(7),
		func() -> void: weather.fade_screen(Gen3FieldWeather.Fade.TO_WHITE, -2),
		func() -> void:
			weather.fade_screen(Gen3FieldWeather.Fade.FROM_BLACK, 1)
			weather.update_sprite_palette(2),
	]
	lines.append_array(_weather_frames(weather, pass_index, 90 / span - 1, thunder, 1))
	for phase: int in phases.size():
		phases[phase].call()
		lines.append_array(_weather_frames(weather, pass_index, WEATHER_PHASES[phase] / span, thunder))
	weather.update_per_day(pass_index + 1)
	lines.append("%d|end|%d|%d|%d" % [pass_index, events.weather, events.weather_cycle_stage,
		int(events.stats.get(Gen3FieldWeather.GAME_STAT_GOT_RAINED_ON, 0))])
	return lines


static func _weather_frames(weather: Gen3FieldWeather, pass_index: int, count: int, thunder: Array[int],
		first: int = 0) -> PackedStringArray:
	var lines := PackedStringArray()
	for index: int in count:
		lines.append(_weather_frame(weather, pass_index, first + index, thunder))
	return lines


## One field frame's weather task, raindrops, palette fade and VBlank transfer; the faded colours and the rain
## after it.
static func _weather_frame(weather: Gen3FieldWeather, pass_index: int, index: int, thunder: Array[int],
		tasks: bool = true) -> String:
	if tasks:
		weather.run_tasks()
	weather.sprites.animate(Vector2i(index * 7 % 41 - 20, index * 3 % 29 - 14))
	weather.palette.update_fade()
	weather.palette.transfer()
	return "%d|%d|%d|%d|%d|%d|%s|%s" % [pass_index, index, weather.current, weather.state, weather.color_map_index,
		weather.bldalpha, weather.palette.faded.hex_encode(), _rain_state(weather, thunder)]


static func _rain_state(weather: Gen3FieldWeather, thunder: Array[int]) -> String:
	var rain: Gen3WeatherSprites = weather.sprites
	var out: String = "r|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|" % [weather.init_step, weather.finish_step,
		rain.rain_sprite_count, rain.current_rain_index, rain.target_rain_count, rain.visible_counter,
		rain.visible_delay, int(rain.downpour), weather.events.random.value, rain.thunder_timer, rain.thunder_se_timer,
		int(rain.thunder_allow_end), int(rain.thunder_long_bolt), rain.thunder_short_bolts,
		int(rain.thunder_enqueued), thunder[0], thunder[1]]
	for index: int in rain.rain_sprite_count:
		var drop: Gen3WeatherSprites.Raindrop = rain.raindrops[index]
		if drop == null:
			out += "-;"
			continue
		out += "%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d;" % [drop.slot, drop.x, drop.y, int(drop.invisible),
			int(drop.coord_offset), drop.anim.image, int(drop.anim.ended), drop.callback, drop.counter, drop.random,
			drop.pos_x, drop.pos_y, int(drop.splashing), int(drop.active), int(drop.waiting)]
	return out


func _reflection_palette_trace(objects: Gen3ObjectEvents, row: int) -> PackedStringArray:
	var object: Gen3ObjectEvents.ObjectEvent = objects.objects[0]
	var sprites: Gen3ObjectSprites = objects.sprites
	var lines := PackedStringArray()
	for type: int in Gen3ObjectSprites.USED_REFLECTION_TYPES:
		sprites.reflection_type = type
		for previous: bool in [false, true]:
			for behavior: int in [0, 0x70, 0x71, 0x72, 0x73, 0x7A, 0x7B, 0x7C, 0x7D]:
				sprites.palette.unfaded.fill(0)
				sprites.special_tag = Gen3ObjectSprites.PALETTE_TAG_NONE
				sprites.reflections.clear()
				object.current_behavior = 0 if previous else behavior
				object.previous_behavior = behavior if previous else 0
				sprites.start_reflection(objects, object, 0, false)
				var slot: int = Gen3ObjectSprites.REFLECTION_SLOTS[object.palette_num]
				var at: int = (Gen3Palette.OBJ_OFFSET + slot * 16) * 2
				lines.append("%d|%d|%d|%d|%d|%d|%s|%d" % [row, type, int(previous), behavior,
					sprites.reflections[0]["offset"], slot, sprites.palette.unfaded.slice(at, at + 32).hex_encode(),
					sprites.special_tag])
	return lines


func _frames_hash(data: GameData, images: Array) -> String:
	var frames := PackedStringArray()
	for frame: Array in images:
		frames.append("%d,%d,%s" % [int(frame[0]) - int(images[0][0]), int(frame[1]),
			data.world_sprite_image(int(frame[0]), int(frame[1])).hex_encode().sha1_text()])
	return "\n".join(frames).sha1_text()


## Every visible object along each map's snake walk has copied a frame after one step, inanimate ones included.
func _object_sprite_frames() -> void:
	var data: GameData = _r.data
	var camera: Gen3FieldCamera = null
	var drawn: int = 0
	for header: Dictionary in data.world_map_headers():
		camera = _camera_at(camera, data, int(header["group"]), int(header["number"]), Vector2i.ZERO)
		var objects: Gen3ObjectEvents = _fresh_objects(camera)
		for at: Vector2i in _snake(header):
			camera.pos = at
			objects.spawn_in_view()
			objects.remove_outside_view()
			objects.step_movements()
			for object: Gen3ObjectEvents.ObjectEvent in objects.objects:
				if not object.active or object.sprite_invisible:
					continue
				drawn += 1
				_r.check(not object.anim.tiles.is_empty(), "%d:%d object %d (graphics %d) at %s copied no frame" % [
					header["group"], header["number"], object.local_id, object.graphics_id, object.current])
	_r.check(drawn > 0, "no object was drawn")


func _held_movements() -> void:
	var data: GameData = _r.data
	var camera := Gen3FieldCamera.new()
	camera.data = data
	camera.grid = Gen3MapGrid.new()
	camera.grid.width = 512
	camera.grid.height = 512
	camera.grid.blocks.resize(512 * 512)
	camera.grid.blocks.fill(0x3000)
	camera.grid._behaviors.resize(1024)
	var objects := Gen3ObjectEvents.new(camera, Gen3EventData.new(data.id))
	var lines := PackedStringArray(["object movements"])
	var refused: Array[int] = []
	for offset: int in data.world_script_offsets("movements"):
		_reset_mover(objects)
		var bytes: PackedByteArray = data.world_script_data("movements", offset)["bytes"]
		for index: int in bytes.size():
			lines.append_array(_held_action_trace(objects, bytes[index], offset, index))
			if bytes[index] != STEP_END and not objects._motions.has(bytes[index]):
				refused.append(bytes[index])
	_r.digest_matches("gen3_object_movements", lines, MOVEMENT_DIGESTS[data.id])
	_r.check(refused.is_empty(), "every cached movement action has a handler (refused %s)" % [refused])
	_held_anim_finishes(objects)


const STEP_END: int = 0xFE
## Frame a hold finishes on, worked out from pret's anims, `sprite.c` and the action's steps: the bow's 8+32+8
## cells end on 50, Rock Smash and Cut blink 32 frames after their cells, the head shake loops its 80 frames
## once, a raised hand hops twice and holds 81. [action, graphics, frame, invisible at the end].
const HOENN_HELD_FINISHES: Array = [[0x4F, 58, 50, false], [0x5A, 86, 67, true],
	[0x5B, 82, 59, true], [0x39, 3, 26, false]]
const FRLG_HELD_FINISHES: Array = [[0x5B, 64, 50, false], [0x68, 96, 67, true],
	[0x69, 95, 59, true], [0x45, 3, 26, false], [0x9F, 0, 162, false], [0x98, 16, 3, false],
	[0x99, 16, 125, false], [0x9A, 16, 65, false], [0x6E, 0, 31, false], [0xA4, 0, 22, false]]
const HELD_ANIM_FINISHES: Dictionary = {
	&"ruby": HOENN_HELD_FINISHES + [[0x60, 0, 31, false]],
	&"sapphire": HOENN_HELD_FINISHES + [[0x60, 0, 31, false]],
	&"emerald": HOENN_HELD_FINISHES + [[0x62, 0, 31, false], [0x96, 0, 8, false],
		[0x9C, 0, 22, false], [0x9D, 0, 22, false], [0x9B, 0, 288, false]],
	&"firered": FRLG_HELD_FINISHES,
	&"leafgreen": FRLG_HELD_FINISHES,
}


func _held_anim_finishes(objects: Gen3ObjectEvents) -> void:
	for row: Array in HELD_ANIM_FINISHES[_r.data.id]:
		_reset_mover(objects)
		var object: Gen3ObjectEvents.ObjectEvent = objects.objects[0]
		objects.set_graphics_id(object, int(row[1]))
		objects.set_held_movement(object, int(row[0]))
		var frame: int = 0
		while not object.held_movement_finished and frame < 400:
			objects.step_movements()
			frame += 1
		_r.check(frame == int(row[2]) and object.invisible == bool(row[3]),
			"held action %02X on graphics %d finishes on frame %d (got %d)" % [int(row[0]), int(row[1]), int(row[2]), frame])


## The actions the ARM held traces ran. Rows added after them (those with options, the obstacle and affine
## kinds, the inanimate and reflection flags) and FLDEFF_SHADOW, whose routines those builds stubbed, stay out
## of their streams.
static func arm_traced(objects: Gen3ObjectEvents, action: int) -> bool:
	var row: Array = objects._motions.get(action, [])
	if row.is_empty() or (row.size() > 3 and row[3] is Dictionary):
		return false
	if int(row[0]) in [Gen3ObjectEvents.Motion.OBSTACLE, Gen3ObjectEvents.Motion.AFFINE]:
		return false
	return int(row[0]) != Gen3ObjectEvents.Motion.SET_FLAG or int(row[2]) not in [
		Gen3ObjectEvents.ObjectFlag.INANIMATE, Gen3ObjectEvents.ObjectFlag.HIDE_REFLECTION]


static func arm_traced_effect(request: Dictionary) -> bool:
	return request["kind"] == "field_effect" and request["effect_id"] != Gen3ObjectEvents.FLDEFF_SHADOW


func _held_action_trace(objects: Gen3ObjectEvents, action: int, offset: int, index: int) -> PackedStringArray:
	var object: Gen3ObjectEvents.ObjectEvent = objects.objects[0]
	var lines := PackedStringArray()
	if not arm_traced(objects, action) or objects.set_held_movement(object, action):
		_reset_mover(objects)
		return lines
	for frame: int in range(1, 41):
		var effects: Array = objects.step_movements().filter(arm_traced_effect)
		var effect: Array = [-1, 0, 0, 0] if effects.is_empty() else [effects[0]["effect_id"],
			effects[0]["local_id"], effects[0]["map_number"], effects[0]["map_group"]]
		var pixels: Vector2i = object.pixel_position - (MOVEMENT_ORIGIN + Vector2i(12, 12)) * 16
		var current: Vector2i = object.current - MOVEMENT_ORIGIN
		var previous: Vector2i = object.previous - MOVEMENT_ORIGIN
		lines.append(",".join([offset, index, frame, current.x, current.y,
			previous.x, previous.y, pixels.x, pixels.y, object.jump_y,
			object.facing, object.movement_direction, object.previous_movement_direction,
			int(object.facing_locked), int(object.held_movement_finished),
			int(object.invisible), int(object.disable_jump_landing_effect), int(object.fixed_priority)] + effect))
		if object.held_movement_finished:
			break
	Gen3ObjectEvents.clear_held_movement(object)
	return lines


static func _reset_mover(objects: Gen3ObjectEvents) -> void:
	var object := Gen3ObjectEvents.ObjectEvent.new()
	object.active = true
	object.local_id = 0
	object.map_number = 0
	object.map_group = 0
	object.current = MOVEMENT_ORIGIN + Vector2i(12, 12)
	object.previous = MOVEMENT_ORIGIN + Vector2i(11, 12)
	object.pixel_position = object.current * 16
	object.facing = Gen3ObjectEvents.Direction.EAST
	object.movement_direction = object.facing
	object.frozen = true
	objects.objects[0] = object


## ARM landing routines over every hole/switch cell on each boulder's map.
const BOULDER_DIGESTS: Dictionary = {
	&"firered": "ee2cd591c7bee7b593f9be4717990bf815f4ca6c",
	&"leafgreen": "c20bfa2f1fb4b51cf3aebd75e8e2bb432d5f5add",
}


func _boulder_landings() -> void:
	var data: GameData = _r.data
	if not BOULDER_DIGESTS.has(data.id):
		return
	var lines := PackedStringArray(["boulder landings"])
	for header: Dictionary in data.world_map_headers():
		var boulders: Array = data.world_map_events(int(header["group"]), int(header["number"])).get("objects", []).filter(
			func(row: Dictionary) -> bool: return int(row["graphics_id"]) == 97 and int(row["kind"]) == 0)
		if boulders.is_empty():
			continue
		var camera: Gen3FieldCamera = Gen3FieldCamera.open(data, int(header["group"]), int(header["number"]), Vector2i.ZERO)
		var objects := Gen3ObjectEvents.new(camera, Gen3EventData.new(data.id))
		var targets: Array[Vector2i] = _boulder_targets(camera.grid)
		for template: Dictionary in boulders:
			for at: Vector2i in targets:
				lines.append(_boulder_landing_trace(objects, template, at))
	_r.digest_matches("gen3_boulder_landings", lines, BOULDER_DIGESTS[data.id])


static func _boulder_targets(grid: Gen3MapGrid) -> Array[Vector2i]:
	var targets: Array[Vector2i] = []
	for y: int in range(Gen3MapGrid.MAP_OFFSET, Gen3MapGrid.MAP_OFFSET + grid.layout_height):
		for x: int in range(Gen3MapGrid.MAP_OFFSET, Gen3MapGrid.MAP_OFFSET + grid.layout_width):
			if grid.behavior_at(x, y) in [0x20, 0x66]:
				targets.append(Vector2i(x, y))
	return targets


static func _boulder_landing_trace(objects: Gen3ObjectEvents, template: Dictionary, at: Vector2i) -> String:
	var boulder := Gen3ObjectEvents.ObjectEvent.new()
	boulder.active = true
	boulder.local_id = int(template["local_id"])
	boulder.map_group = objects.camera.group
	boulder.map_number = objects.camera.number
	boulder.current = at
	objects.objects[0] = boulder
	var hide: int = int(template["flag"])
	var reveal: int = int(template["trainer_type"])
	objects.events.flag_clear(hide)
	objects.events.flag_set(reveal)
	var requests: Array = objects.boulder_landing(boulder)
	var values: Array = [boulder.map_group, boulder.map_number, boulder.local_id, at.x, at.y,
		objects.camera.grid.behavior_at(at.x, at.y), int(boulder.active),
		int(objects.events.flag_get(hide)), int(objects.events.flag_get(reveal))]
	for request: Dictionary in requests:
		if request["kind"] == "script":
			values.append(int(request["offset"]))
	return "|".join(values)


func _avatar_states(avatar: Gen3PlayerAvatar) -> String:
	var out := PackedByteArray()
	for gender: int in 2:
		avatar.gender = gender
		for flags: int in 256:
			avatar.flags = flags
			out.append(avatar.graphics_by_current_state())
			out.append(avatar.state_flag_by_graphics(flags))
			avatar.set_state_mask(flags ^ 0x55)
			out.append(avatar.flags)
	avatar.gender = 1
	return _graphics_hash({"bytes": out})


func _avatar_sweep(avatar: Gen3PlayerAvatar) -> PackedByteArray:
	var grid: Gen3MapGrid = avatar.objects.camera.grid
	var out := PackedByteArray()
	avatar.flags = Gen3PlayerAvatar.Flag.SURFING
	var player: Gen3ObjectEvents.ObjectEvent = avatar.object()
	for y: int in range(-1, grid.height + 1):
		for x: int in range(-1, grid.width + 1):
			var direction: int = 1 + posmod(x + y, 4)
			player.current = Vector2i(x, y) - Gen3FieldCamera.DIRECTIONS[direction]
			player.previous = player.current
			player.current_elevation = posmod(x + 2 * y, 16)
			player.previous_elevation = posmod(x + y, 16)
			player.current_behavior = grid.behavior_at(player.current.x, player.current.y)
			Gen3ObjectEvents.set_direction(player, direction)
			var result: Dictionary = avatar.check_collision(direction)
			out.append(int(result["collision"]))
			out.append(result["requests"].size())
			out.append(int(result["requests"][0].get("object_id", 255)) if not result["requests"].is_empty() else 255)
			out.append(int(avatar.facing_fishable_water()))
			if avatar.objects.camera.data.id == RomRegistry.EMERALD:
				out.append(int(avatar.collision_at(player, Vector2i(x, y), direction, true)["collision"]))
	return out



static func _u16(value: int) -> PackedByteArray:
	return PackedByteArray([value & 0xFF, (value >> 8) & 0xFF])


func _graphics_hash(record: Dictionary) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA1)
	if not record["bytes"].is_empty():
		context.update(record["bytes"])
	return context.finish().hex_encode()


## Exact bytecode streams from pret handlers, with operand boundaries checked by executing the matching ARM
## builds; all map, standard and trainer roots.
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


## Every record starts on a label of the byte-matching pret build and ends where its source list or string
## does; movements and marts reassembled from source.
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


## ARM gate routines on every puzzle cell and orientation, with real layouts.
const GATE_DIGESTS: Dictionary = {
	&"ruby": "d2404bf15714b745fac5a6e0c0651bbd829ced55",
	&"sapphire": "d2404bf15714b745fac5a6e0c0651bbd829ced55",
	&"emerald": "7815a603ccec3a1f13b0cd795d4f3888493696aa",
}


func _rotating_gates() -> void:
	var data: GameData = _r.data
	if not GATE_DIGESTS.has(data.id):
		return
	var lines := PackedStringArray()
	var configs: Dictionary = Gen3PlayerAvatar.EMERALD_GATES if data.id == RomRegistry.EMERALD else Gen3PlayerAvatar.RS_GATES
	for key: String in configs:
		var pair: PackedStringArray = key.split(":")
		var camera: Gen3FieldCamera = Gen3FieldCamera.open(data, int(pair[0]), int(pair[1]), Vector2i.ZERO)
		var avatar: Gen3PlayerAvatar = Gen3PlayerAvatar.open(_fresh_objects(camera), Vector2i(7, 7), 1, 0)
		for word: int in 16:
			avatar.objects.events.var_set(0x4000 + word, 0xA5A5)
		avatar.load_rotating_gates(true)
		var bytes: Array = []
		for byte: int in 16:
			bytes.append(avatar.gate_orientation(byte))
		lines.append("%s|%s" % [key, _script_numbers(bytes)])
		_gate_puzzle_sweep(avatar, configs[key], lines)
	_r.digest_matches("gen3_rotating_gates", lines, GATE_DIGESTS[data.id])


func _gate_puzzle_sweep(avatar: Gen3PlayerAvatar, rows: Array, lines: PackedStringArray) -> void:
	for gate: int in rows.size():
		var center := Vector2i(int(rows[gate][0]) + 7, int(rows[gate][1]) + 7)
		for orientation: int in 4:
			for y: int in range(center.y - 3, center.y + 3):
				for x: int in range(center.x - 3, center.x + 3):
					for direction: int in range(1, 5):
						for read_only: int in (2 if avatar.objects.events.game == RomRegistry.EMERALD else 1):
							lines.append(_gate_probe(avatar, rows.size(), [gate, orientation, x, y, -1, 0, direction, read_only]))


func _gate_probe(avatar: Gen3PlayerAvatar, count: int, prefix: Array) -> String:
	var orientation: int = int(prefix[1])
	for word: int in (count + 1) / 2:
		avatar.objects.events.var_set(0x4000 + word, orientation | (orientation << 8))
	var result: Dictionary = avatar.rotating_gate_collision(int(prefix[6]), Vector2i(int(prefix[2]), int(prefix[3])), int(prefix[7]) != 0)
	var values: Array = prefix + [int(result["collision"] != 0)]
	for gate: int in count:
		values.append(avatar.gate_orientation(gate))
	if result["requests"].is_empty():
		values.append_array([-1, -1, -1])
	else:
		var effect: Dictionary = result["requests"][0]
		values.append_array([effect["gate"], effect["orientation"], effect["rotation"]])
	return _script_numbers(values)


## ARM callbacks over every supported map template on a uniform grid, 512 frames each. The oracle reads
## template bytes and direction tables from ROM.
const RANDOM_MOVEMENT_DIGESTS: Dictionary = {
	&"ruby": "5a72f767d20ea9774a84e40b4c16358225ce8e1f",
	&"sapphire": "5a72f767d20ea9774a84e40b4c16358225ce8e1f",
	&"firered": "db2010a48f1de95decd92a1fd3d6737235ab4f93",
	&"leafgreen": "db2010a48f1de95decd92a1fd3d6737235ab4f93",
	&"emerald": "b65802b9a7ebbe8b39e3dd43ceb4df4eb60d9862",
}
const PATROL_DIGESTS: Dictionary = {
	&"ruby": "2cbcf7f9a589f26fca38c6dde264312ab4585b1a",
	&"sapphire": "2cbcf7f9a589f26fca38c6dde264312ab4585b1a",
	&"firered": "7d7f689cc66ff26242a175f1ad7efbaac0638767",
	&"leafgreen": "7d7f689cc66ff26242a175f1ad7efbaac0638767",
	&"emerald": "1f8001244af2bc6d2d53db53baed1d6a7526d9a8",
}


func _movement_field(data: GameData) -> Gen3ObjectEvents:
	var camera := Gen3FieldCamera.new()
	camera.data = data
	camera.pos = Vector2i(100, 100)
	camera.header = {"map_type": 0}
	camera.grid = Gen3MapGrid.new()
	camera.grid.width = 512
	camera.grid.height = 512
	camera.grid.blocks.resize(512 * 512)
	camera.grid.blocks.fill(0x3000)
	camera.grid._behaviors.resize(1024)
	return Gen3ObjectEvents.new(camera, Gen3EventData.new(data.id))


func _object_movements(random_movement: bool) -> void:
	var data: GameData = _r.data
	var objects: Gen3ObjectEvents = _movement_field(data)
	var camera: Gen3FieldCamera = objects.camera
	var lines := PackedStringArray(["object random movements" if random_movement else "object patrols"])
	for header: Dictionary in data.world_map_headers():
		camera.group = int(header["group"])
		camera.number = int(header["number"])
		var rows: Array = data.world_map_events(camera.group, camera.number)["objects"]
		for index: int in rows.size():
			for object: Gen3ObjectEvents.ObjectEvent in objects.objects:
				object.active = false
			var template: Dictionary = rows[index].duplicate()
			template["x"] = 5
			template["y"] = 5
			var slot: int = objects.spawn(template, camera.number, camera.group)
			if not _r.check(slot == 0, "movement template did not spawn"):
				continue
			var object: Gen3ObjectEvents.ObjectEvent = objects.objects[slot]
			var type: int = object.movement_type
			var supported: bool = type in range(1, 7) + range(0xD, 0x19) if random_movement else \
				type in range(7, 11) + range(0x19, 0x35) + range(0x40, 0x4D) \
				or (data.id == RomRegistry.EMERALD and type in range(0x4D, 0x51))
			if not supported:
				continue
			object.initial += MOVEMENT_ORIGIN
			object.current += MOVEMENT_ORIGIN
			object.previous = MOVEMENT_ORIGIN + Vector2i(11, 12)
			object.pixel_position = object.current * 16
			object.current_elevation = 3
			object.previous_elevation = 3
			objects.events.random.value = 0x1234 + index
			lines.append_array(_autonomous_frames(objects, index, random_movement))
	_r.digest_matches("gen3_object_random_movements" if random_movement else "gen3_object_patrols", lines,
		RANDOM_MOVEMENT_DIGESTS[data.id] if random_movement else PATROL_DIGESTS[data.id])


func _autonomous_frames(objects: Gen3ObjectEvents, index: int, random_movement: bool) -> PackedStringArray:
	var object: Gen3ObjectEvents.ObjectEvent = objects.objects[0]
	var lines := PackedStringArray()
	for frame: int in range(1, 513):
		objects.step_movements()
		var pixels: Vector2i = object.pixel_position - (MOVEMENT_ORIGIN + Vector2i(12, 12)) * 16
		var current: Vector2i = object.current - MOVEMENT_ORIGIN
		var previous: Vector2i = object.previous - MOVEMENT_ORIGIN
		var values: Array = [objects.camera.group, objects.camera.number, index, frame,
			current.x, current.y, previous.x, previous.y, pixels.x, pixels.y,
			object.facing, object.movement_direction, object.previous_movement_direction, object.direction_sequence_index,
			object.movement_state, object.movement_action, int(object.single_movement_active),
			int(object.held_movement_active), int(object.held_movement_finished), int(object.frozen), int(object.invisible)]
		if random_movement:
			var waiting: bool = object.movement_state == (2 if object.movement_type >= 0x17 else 3)
			values.append_array([object.movement_delay if waiting else 0, objects.events.random.value])
		lines.append(",".join(values))
	return lines


const COPY_MOVEMENT_DIGESTS: Dictionary = {
	&"ruby": "09408824553560b499a457f07488713c017d26a7", &"sapphire": "09408824553560b499a457f07488713c017d26a7",
	&"firered": "2c98a93be58e257eb9e045c427a6892ede0bcb50",
	&"leafgreen": "2c98a93be58e257eb9e045c427a6892ede0bcb50", &"emerald": "604fe3e775f8d66fcbbadbd4ce5e9217ffc832b9",
}


func _copy_player_movements() -> void:
	var data: GameData = _r.data
	var objects: Gen3ObjectEvents = _movement_field(data)
	var camera: Gen3FieldCamera = objects.camera
	camera.grid.blocks.fill(0x3002)
	camera.grid._behaviors[2] = 2
	var lines := PackedStringArray(["copy player movements"])
	for header: Dictionary in data.world_map_headers():
		camera.group = int(header["group"])
		camera.number = int(header["number"])
		var rows: Array = data.world_map_events(camera.group, camera.number)["objects"]
		for index: int in rows.size():
			for object: Gen3ObjectEvents.ObjectEvent in objects.objects:
				object.active = false
			var template: Dictionary = rows[index].duplicate()
			template["x"] = MOVEMENT_ORIGIN.x + 5
			template["y"] = MOVEMENT_ORIGIN.y + 5
			if not _r.check(objects.spawn(template, camera.number, camera.group) == 0, "copy template did not spawn"):
				continue
			var object: Gen3ObjectEvents.ObjectEvent = objects.objects[0]
			if object.movement_type not in range(0x35, 0x39) + range(0x3B, 0x3F):
				continue
			object.pixel_position = object.current * 16
			object.current_elevation = 3
			object.previous_elevation = 3
			var player := Gen3ObjectEvents.ObjectEvent.new()
			player.active = true
			player.local_id = Gen3ObjectEvents.LOCALID_PLAYER
			player.facing = index % 4 + 1
			player.current = MOVEMENT_ORIGIN + Vector2i(40, 40)
			player.previous = MOVEMENT_ORIGIN + Vector2i(39, 40)
			player.current_elevation = 15
			player.movement_action = 0
			objects.objects[1] = player
			lines.append_array(_copy_player_frames(objects, index))
	_r.digest_matches("gen3_object_copy_movements", lines, COPY_MOVEMENT_DIGESTS[data.id])


func _copy_player_frames(objects: Gen3ObjectEvents, index: int) -> PackedStringArray:
	var object: Gen3ObjectEvents.ObjectEvent = objects.objects[0]
	var player: Gen3ObjectEvents.ObjectEvent = objects.objects[1]
	var lines := PackedStringArray()
	for frame: int in range(1, 513):
		player.movement_direction = (frame / 32) % 4 + 1
		player.player_copyable_movement = (frame / 32) % 9
		objects.events.var_set(0x403A, frame / 32 + 1)
		objects.step_movements(false, frame % 32 == 31)
		var pixels: Vector2i = object.pixel_position - (MOVEMENT_ORIGIN + Vector2i(12, 12)) * 16
		var current: Vector2i = object.current - MOVEMENT_ORIGIN
		var previous: Vector2i = object.previous - MOVEMENT_ORIGIN
		lines.append(",".join([objects.camera.group, objects.camera.number, index, frame,
			current.x, current.y, previous.x, previous.y, pixels.x, pixels.y, object.jump_y,
			object.facing, object.movement_direction, object.previous_movement_direction,
			object.direction_sequence_index, object.movement_state, object.movement_action,
			int(object.single_movement_active), int(object.held_movement_active),
			int(object.held_movement_finished), int(object.frozen), int(object.invisible)]))
	return lines


## Every tree/mountain template from pret's map JSON, including zero FRLG rows.
const DISGUISE_COUNTS: Dictionary = {&"ruby": 5, &"sapphire": 5, &"firered": 0, &"leafgreen": 0, &"emerald": 7}


func _disguises() -> void:
	var data: GameData = _r.data
	var objects: Gen3ObjectEvents = _movement_field(data)
	var count: int = 0
	for header: Dictionary in data.world_map_headers():
		objects.camera.group = int(header["group"])
		objects.camera.number = int(header["number"])
		objects.load_templates()
		for template: Dictionary in objects.templates:
			if int(template["movement_type"]) not in [0x39, 0x3A]:
				continue
			count += 1
			_disguise_frames(objects, header, template)
	_r.check(count == int(DISGUISE_COUNTS[data.id]), "every source disguise template is exercised")
	_r.note("%d disguise templates: frozen initialization and original ARM reveal frames" % count)


func _disguise_frames(objects: Gen3ObjectEvents, header: Dictionary, template: Dictionary) -> void:
	var slot: int = objects.spawn(template, int(header["number"]), int(header["group"]))
	if not _r.check(slot >= 0, "disguised trainer spawns"):
		return
	var object: Gen3ObjectEvents.ObjectEvent = objects.objects[slot]
	object.frozen = true
	var effects: Array = objects.step_movements().filter(
		func(request: Dictionary) -> bool: return request["kind"] == "field_effect")
	_r.check(effects.size() == 1 and int(effects[0]["local_id"]) == object.local_id,
		"frozen disguise initializes with its template identity")
	_r.check(not objects.set_held_movement(object, 0x67 if objects._frlg else 0x59), "reveal hold starts")
	var lines := PackedStringArray()
	for frame: int in range(1, 41):
		objects.step_movements()
		lines.append(",".join([frame, object.direction_sequence_index, object.disguise_state,
			int(object.disguise_ready), int(object.held_movement_finished), int(object.disguise_spawned)]))
	_r.check(("\n".join(lines) + "\n").sha1_text() == DISGUISE_REVEAL_DIGEST,
		"disguise reveal matches the original ARM action, effect callback and sprite animation")
	objects.remove(object.local_id, object.map_number, object.map_group)


const DISGUISE_REVEAL_DIGEST: String = "6ea54dfb378843c69af71ca7d3857b72b9d5cae4"


## Every seeing trainer template, FRLG clones resolved. One with sight opens its script with `trainerbattle`,
## sees the player two cells (or one) ahead, never one past its range, and not once beaten; its approach ends
## beside the player with the script resumed. Sight 0 (Emerald's Space Center grunt runs `lock` first) never
## sees. The uniform grid's elevation is the trainer's.
func _trainer_sight() -> void:
	var data: GameData = _r.data
	var objects: Gen3ObjectEvents = _movement_field(data)
	var see := Gen3TrainerSee.new(objects, Gen3PlayerAvatar.open(objects, SIGHT_ORIGIN, 1, 0))
	var counts: Array[int] = [0, 0]
	for header: Dictionary in data.world_map_headers():
		objects.camera.group = int(header["group"])
		objects.camera.number = int(header["number"])
		objects.camera.header = {"map_type": 0, "layout_id": int(header["layout_id"])}
		objects.load_templates()
		for template: Dictionary in objects.templates.duplicate():
			if int(template["trainer_type"]) & 0xFF in [Gen3TrainerSee.TrainerType.NORMAL, Gen3TrainerSee.TrainerType.BURIED]:
				counts[int(_trainer_sight_case(see, template))] += 1
	_r.check(counts[1] > 0, "seeing trainer templates exist")
	_r.note("%d seeing trainers (script head, sight edge, beaten flag, approach), %d with no sight" % [counts[1], counts[0]])


const SIGHT_ORIGIN := Vector2i(200, 200)


func _trainer_sight_case(see: Gen3TrainerSee, template: Dictionary) -> bool:
	var objects: Gen3ObjectEvents = see.objects
	var slot: int = objects.spawn(template, objects.camera.number, objects.camera.group)
	if not _r.check(slot >= 0, "seeing trainer spawns"):
		return false
	var trainer: Gen3ObjectEvents.ObjectEvent = objects.objects[slot]
	var direction: int = trainer.facing
	_r.check(direction >= Gen3ObjectEvents.Direction.SOUTH and direction <= Gen3ObjectEvents.Direction.EAST,
		"trainer faces a cardinal direction")
	var facility: Callable = func(_slot: int) -> bool: return false
	_place_for_sight(see, trainer, direction, trainer.trainer_range + 1)
	_r.check(not see.check_trainers(true, facility), "trainer does not see past its range")
	var sighted: bool = trainer.trainer_range > 0
	if sighted:
		var head: Dictionary = objects.camera.data.world_script_instruction(int(template["script_offset"]))
		if _r.check(int(head.get("opcode", -1)) == 0x5C, "a seeing trainer's script opens with trainerbattle"):
			_trainer_approach(see, trainer, direction, Gen3TrainerSee.TRAINER_FLAGS_START + int(head["operands"][1]))
	objects.remove(trainer.local_id, trainer.map_number, trainer.map_group)
	return sighted


func _trainer_approach(see: Gen3TrainerSee, trainer: Gen3ObjectEvents.ObjectEvent, direction: int, flag: int) -> void:
	var facility: Callable = func(_slot: int) -> bool: return false
	var distance: int = mini(trainer.trainer_range, 2)
	_place_for_sight(see, trainer, direction, distance)
	if not _r.check(see.check_trainers(true, facility) and int(see.approaching[0]["radius"]) == distance,
			"trainer sees the player %d cells ahead" % distance):
		return
	_r.check(_approach_finishes(see), "trainer approach resumes the script")
	_r.check(trainer.current == see.avatar.object().current - Gen3FieldCamera.DIRECTIONS[direction],
		"trainer ends beside the player")
	if int(see.objects.camera.header["layout_id"]) in Gen3ObjectEvents.PYRAMID_LAYOUTS \
			+ Gen3ObjectEvents.TRAINER_HILL_LAYOUTS and see.objects.camera.data.id == RomRegistry.EMERALD:
		return
	see.objects.events.flag_set(flag)
	_place_for_sight(see, trainer, direction, 1)
	_r.check(not see.check_trainers(), "a beaten trainer does not see")
	see.objects.events.flag_clear(flag)


func _place_for_sight(see: Gen3TrainerSee, trainer: Gen3ObjectEvents.ObjectEvent, direction: int, distance: int) -> void:
	for object: Gen3ObjectEvents.ObjectEvent in [trainer, see.avatar.object()]:
		Gen3ObjectEvents.clear_held_movement(object)
	trainer.initial = SIGHT_ORIGIN
	trainer.current = SIGHT_ORIGIN
	trainer.previous = SIGHT_ORIGIN
	trainer.current_elevation = see.objects.camera.grid.elevation_at(SIGHT_ORIGIN.x, SIGHT_ORIGIN.y)
	var player: Gen3ObjectEvents.ObjectEvent = see.avatar.object()
	player.current = SIGHT_ORIGIN + Gen3FieldCamera.DIRECTIONS[direction] * distance
	player.previous = player.current


func _approach_finishes(see: Gen3TrainerSee) -> bool:
	see.start_approach()
	for frame: int in 400:
		for request: Dictionary in see.run_tasks() + see.objects.step_movements():
			if request["kind"] == "script_enable":
				return true
	return false


## `gBerries` fields agree with berry.c; stage selections come from each byte-matching build's graphics and
## palette pointer tables.
func _berries() -> void:
	var data: GameData = _r.data
	var lines := PackedStringArray()
	for berry: int in range(1, 44):
		var row: Dictionary = data.world_berry(berry)
		if not _r.check(not row.is_empty(), "berry %d has growth parameters" % berry):
			return
		var values: Array = [berry, row["stage_minutes"], row["min_yield"], row["max_yield"]]
		values.append_array(row.get("berry_graphics", []))
		values.append_array(row.get("berry_palettes", []))
		lines.append(",".join(values))
	var frlg: bool = data.id in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN]
	_r.digest_matches("gen3_berries", lines, "4becd74400492a852a8fa88faeea0e2dff4295e7" if frlg
		else "d0c8182d600f64f5fcc3f523198fafed04691c8c")
	if frlg:
		return
	var reserved: Dictionary = data.world_berry(44)
	_r.check([reserved["berry_graphics"], reserved["berry_palettes"]] == [[61, 61, 62, 62, 62], [61, 61, 62, 62, 62]]
		and data.world_sprite_images(int(reserved["berry_images"])).is_empty(),
		"reserved berry graphics preserve the palette overread, and its pics point into EWRAM")
	lines.clear()
	for berry: int in range(1, 44):
		lines.append_array(_berry_growth_frames(data, berry))
	_r.digest_matches("gen3_berry_growth", lines, "3c71d97347d67067d19dca6917c8a519e1e608c5")


## Original ARM records and shared LCG over every berry and watering mask, ten regrowths, long batches and
## trees frozen until seen.
func _berry_growth_frames(data: GameData, berry: int) -> PackedStringArray:
	var lines := PackedStringArray()
	for scenario: int in 18:
		var trees := Gen3BerryTrees.new(data)
		trees.plant(0, berry, 5 if scenario == 16 else 1, scenario != 17)
		trees.random.value = 0x12345678
		var duration: int = int(trees.record(0)["minutes"]) / (4 if scenario == 16 else 1)
		for turn: int in 101:
			var stage: int = int(trees.record(0)["stage"])
			if scenario < 16 and stage >= 1 and stage <= 4 and scenario & (1 << (stage - 1)):
				trees.water(0)
			var minutes: int = duration if scenario < 16 else int([0, 1, duration - 1, duration,
				duration + 1, duration * 4, duration * 70, duration * 71, -1][turn % 9])
			trees.advance_minutes(minutes)
			var values: Array = [berry, scenario, turn]
			values.append_array(Array(trees._records.slice(0, 6)))
			values.append(trees.random.value)
			lines.append(",".join(values))
	return lines


func _berry_objects() -> void:
	var data: GameData = _r.data
	var count: int = 0
	var objects: Gen3ObjectEvents = _movement_field(data)
	for header: Dictionary in data.world_map_headers():
		objects.camera.group = int(header["group"])
		objects.camera.number = int(header["number"])
		objects.load_templates()
		for template: Dictionary in objects.templates:
			if int(template["movement_type"]) != 12:
				continue
			count += 1
			_berry_object_frames(objects, template)
	_r.check(count == (0 if data.id in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN] else 88),
		"every source berry-tree template is exercised")
	_r.note("%d berry-tree templates: original ARM growth-transition frames" % count)


func _berry_object_frames(objects: Gen3ObjectEvents, template: Dictionary) -> void:
	var slot: int = objects.spawn(template, objects.camera.number, objects.camera.group)
	if not _r.check(slot >= 0, "berry tree spawns"):
		return
	var object: Gen3ObjectEvents.ObjectEvent = objects.objects[slot]
	objects.events.berries.plant(object.trainer_range, 1, 1)
	var lines := PackedStringArray()
	for frame: int in range(1, 401):
		if frame == 81:
			objects.events.berries.plant(object.trainer_range, 1, 2)
		var effects: Array = objects.step_movements().filter(
			func(request: Dictionary) -> bool: return request["kind"] == "field_effect")
		lines.append(",".join([frame, object.graphics_id, int(object.invisible),
			int(object.single_movement_active), object.movement_action & 255, object.movement_state,
			object.movement_delay, 1 + int(objects.berry_tree_sparkling(object.local_id, object.map_number, object.map_group)) * 2,
			object.anim.anim_num, object.palette_num, -1 if effects.is_empty() else int(effects[-1]["effect_id"])]))
	_r.check(("\n".join(lines) + "\n").sha1_text() == "6385b0a01e1037c39ebbf2f45ea8b41d9530498e",
		"berry template %d matches original ARM callbacks and animation clocks" % object.local_id)
	object.active = false
