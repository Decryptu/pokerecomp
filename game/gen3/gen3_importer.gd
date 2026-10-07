class_name Gen3Importer
extends RefCounted

## Generation 3's importer: species with dex entries, moves, types, matchups,
## items, abilities and pictures; the registry keeps these cartridges unplayable.

## The `GAME_CODE` and `GAME_REVISION` each pret Makefile hands `gbafix`.
const HEADERS: Dictionary = {
	RomRegistry.RUBY: ["AXVE", 2],
	RomRegistry.SAPPHIRE: ["AXPE", 2],
	RomRegistry.FIRERED: ["BPRE", 1],
	RomRegistry.LEAFGREEN: ["BPGE", 1],
	RomRegistry.EMERALD: ["BPEE", 0],
}

## Endpoints from pret's data files, the same on all five.
const FIRST_SPECIES_NAME: String = "BULBASAUR"
const LAST_SPECIES_NAME: String = "CHIMECHO"
const LAST_SPECIES: int = 411
const DEX_NUMBERS: Dictionary = {1: [1, 203], 277: [252, 1], 411: [358, 151]}
const FIRST_INFO: Array[int] = [45, 49, 49, 45, 65, 65, 12, 3, 45, 64]
const FIRST_MOVE_NAME: String = "POUND"
const LAST_MOVE_NAME: String = "PSYCHO BOOST"
const FIRST_MOVE: Array[int] = [0, 40, 0, 100, 35]
const LAST_MOVE: Array[int] = [140, 14, 90, 5]
const FIRST_TYPE_NAME: String = "NORMAL"
const MYSTERY_TYPE_NAME: String = "???"
const LAST_TYPE_NAME: String = "DARK"
const FIRST_LEARNSET_WORD: int = (1 << Gen3Layout.LEARNSET_LEVEL_SHIFT) | 33
const FIRST_EVOLUTION: Array[int] = [4, 16, 2]
const UNUSED_ITEM_NAME: String = "????????"
const FIRST_ITEM_NAME: String = "MASTER BALL"
const FIRST_ABILITY_NAME: String = "STENCH"
const LAST_ABILITY_NAME: String = "AIR LOCK"
const DEX_ENDPOINTS: Dictionary = {1: ["SEED", 7, 69], 386: ["DNA", 17, 608]}

static var LAYOUT_CHECKS: Array[Callable] = [
	_verify_header,
	_verify_species_names,
	_verify_species_info,
	_verify_dex_numbers,
	_verify_moves,
	_verify_type_names,
	_verify_matchups,
	_verify_learnsets,
	_verify_evolutions,
	_verify_items,
	_verify_abilities,
	_verify_dex_entries,
	Gen3Pics.verify,
]


static func verify_layout(rom: RomFile) -> Dictionary:
	var layout: Dictionary = Gen3Layout.for_id(rom.id)
	if layout.is_empty() or not HEADERS.has(rom.id):
		return _fail("No Generation 3 layout for %s." % rom.id)
	for check: Callable in LAYOUT_CHECKS:
		var result: Dictionary = check.call(rom, layout)
		if not bool(result.get("ok", false)):
			return result
	return {"ok": true, "message": "Layout verified."}


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "message": message}


static func _ok() -> Dictionary:
	return {"ok": true, "message": ""}


static func _verify_header(rom: RomFile, _layout: Dictionary) -> Dictionary:
	var header: GbaHeader = GbaHeader.parse(rom)
	var wanted: Array = HEADERS[rom.id]
	if header.game_code != String(wanted[0]) or header.version != int(wanted[1]):
		return _fail("%s claims to be %s revision %d, not %s revision %d." % [
			RomRegistry.title_for(rom.id), header.game_code, header.version,
			wanted[0], wanted[1],
		])
	return _ok()


static func _species_name(rom: RomFile, layout: Dictionary, species: int) -> String:
	return Gen3Text.decode_fixed(
		rom.bytes(), Gen3Layout.species_name_offset(layout, species),
		Gen3Layout.SPECIES_NAME_SIZE,
	)


static func _verify_species_names(rom: RomFile, layout: Dictionary) -> Dictionary:
	var first: String = _species_name(rom, layout, 1)
	var last: String = _species_name(rom, layout, LAST_SPECIES)
	if first != FIRST_SPECIES_NAME or last != LAST_SPECIES_NAME:
		return _fail("gSpeciesNames reads '%s' and '%s'." % [first, last])
	return _ok()


static func _verify_species_info(rom: RomFile, layout: Dictionary) -> Dictionary:
	var at: int = Gen3Layout.species_info_offset(layout, 1)
	var read: Array[int] = []
	for field: int in Gen3Layout.INFO_EXP_YIELD + 1:
		read.append(rom.u8(at + field))
	if read != FIRST_INFO:
		return _fail("Bulbasaur's species info reads %s." % str(read))
	return _ok()


static func _verify_dex_numbers(rom: RomFile, layout: Dictionary) -> Dictionary:
	for species: int in DEX_NUMBERS:
		var read: Array = [
			Gen3Layout.national_number(rom, layout, species),
			Gen3Layout.hoenn_number(rom, layout, species),
		]
		if read != DEX_NUMBERS[species]:
			return _fail("Species %d has dex numbers %s." % [species, str(read)])
	if _species_by_national(rom, layout).size() != Gen3Layout.NATIONAL_DEX_COUNT:
		return _fail("The national dex table does not name %d species once each."
			% Gen3Layout.NATIONAL_DEX_COUNT)
	return _ok()


## National number to internal species; the unused Unown slots drop out, and
## a number claimed twice empties the answer.
static func _species_by_national(rom: RomFile, layout: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for species: int in range(1, Gen3Layout.SPECIES_COUNT):
		var number: int = Gen3Layout.national_number(rom, layout, species)
		if number < 1 or number > Gen3Layout.NATIONAL_DEX_COUNT:
			continue
		if out.has(number):
			return {}
		out[number] = species
	return out


static func _move_name(rom: RomFile, layout: Dictionary, move: int) -> String:
	return Gen3Text.decode_fixed(
		rom.bytes(), Gen3Layout.move_name_offset(layout, move), Gen3Layout.MOVE_NAME_SIZE
	)


static func _verify_moves(rom: RomFile, layout: Dictionary) -> Dictionary:
	var last_move: int = Gen3Layout.MOVES_COUNT - 1
	var first_name: String = _move_name(rom, layout, 1)
	var last_name: String = _move_name(rom, layout, last_move)
	if first_name != FIRST_MOVE_NAME or last_name != LAST_MOVE_NAME:
		return _fail("gMoveNames reads '%s' and '%s'." % [first_name, last_name])
	var first: int = Gen3Layout.move_offset(layout, 1)
	var last: int = Gen3Layout.move_offset(layout, last_move)
	var read_first: Array[int] = []
	for field: int in Gen3Layout.MOVE_PP + 1:
		read_first.append(rom.u8(first + field))
	var read_last: Array[int] = []
	for field: int in range(Gen3Layout.MOVE_POWER, Gen3Layout.MOVE_PP + 1):
		read_last.append(rom.u8(last + field))
	if read_first != FIRST_MOVE or read_last != LAST_MOVE:
		return _fail("gBattleMoves reads %s and %s." % [str(read_first), str(read_last)])
	return _ok()


static func _type_name(rom: RomFile, layout: Dictionary, type: int) -> String:
	return Gen3Text.decode_fixed(
		rom.bytes(), Gen3Layout.type_name_offset(layout, type), Gen3Layout.TYPE_NAME_SIZE
	)


static func _verify_type_names(rom: RomFile, layout: Dictionary) -> Dictionary:
	var read: Array = [
		_type_name(rom, layout, 0),
		_type_name(rom, layout, Gen3Layout.TYPE_MYSTERY),
		_type_name(rom, layout, Gen3Layout.TYPE_COUNT - 1),
	]
	if read != [FIRST_TYPE_NAME, MYSTERY_TYPE_NAME, LAST_TYPE_NAME]:
		return _fail("gTypeNames reads %s." % str(read))
	return _ok()


static func _verify_matchups(rom: RomFile, layout: Dictionary) -> Dictionary:
	if _read_matchups(rom, layout).is_empty():
		return _fail("gTypeEffectiveness has a row that is not a matchup, or no end.")
	return _ok()


## Empty when a row is not a matchup, which is a wrong offset.
static func _read_matchups(rom: RomFile, layout: Dictionary) -> Array:
	var out: Array = []
	var after_foresight: bool = false
	var at: int = int(layout["type_effectiveness"])
	while rom.in_bounds(at, Gen3Layout.MATCHUP_SIZE):
		var attacker: int = rom.u8(at)
		var defender: int = rom.u8(at + 1)
		var multiplier: int = rom.u8(at + 2)
		at += Gen3Layout.MATCHUP_SIZE
		if attacker == Gen3Layout.MATCHUP_END:
			return out
		if attacker == Gen3Layout.MATCHUP_FORESIGHT:
			after_foresight = true
			continue
		if attacker >= Gen3Layout.TYPE_COUNT or defender >= Gen3Layout.TYPE_COUNT \
			or not Gen3Layout.MATCHUP_MULTIPLIERS.has(multiplier):
			return []
		out.append({
			"attacker": attacker,
			"defender": defender,
			"multiplier": multiplier,
			"negated_by_foresight": after_foresight,
		})
	return []


static func _verify_learnsets(rom: RomFile, layout: Dictionary) -> Dictionary:
	var at: int = _learnset_offset(rom, layout, 1)
	if at < 0 or rom.u16le(at) != FIRST_LEARNSET_WORD:
		return _fail("gLevelUpLearnsets does not open Bulbasaur's list on Tackle.")
	for species: int in range(1, Gen3Layout.SPECIES_COUNT):
		if _read_learnset(rom, layout, species).is_empty():
			return _fail("Species %d's level-up list is empty or has no end." % species)
	return _ok()


static func _learnset_offset(rom: RomFile, layout: Dictionary, species: int) -> int:
	return Gen3Layout.rom_offset(
		rom.u32le(int(layout["learnsets"]) + species * Gen3Layout.POINTER_SIZE)
	)


static func _read_learnset(rom: RomFile, layout: Dictionary, species: int) -> Array:
	var at: int = _learnset_offset(rom, layout, species)
	if at < 0:
		return []
	var out: Array = []
	for row: int in Gen3Layout.LEARNSET_MAX:
		var word: int = rom.u16le(at + row * 2)
		if word == Gen3Layout.LEARNSET_END:
			return out
		out.append({
			"level": word >> Gen3Layout.LEARNSET_LEVEL_SHIFT,
			"move": word & Gen3Layout.LEARNSET_MOVE_MASK,
		})
	return []


static func _verify_evolutions(rom: RomFile, layout: Dictionary) -> Dictionary:
	var at: int = Gen3Layout.evolution_offset(layout, 1, 0)
	var read: Array[int] = [
		rom.u16le(at),
		rom.u16le(at + Gen3Layout.EVOLUTION_PARAMETER),
		rom.u16le(at + Gen3Layout.EVOLUTION_TARGET),
	]
	if read != FIRST_EVOLUTION:
		return _fail("Bulbasaur's evolution reads %s." % str(read))
	for species: int in range(1, Gen3Layout.SPECIES_COUNT):
		for slot: int in Gen3Layout.EVOS_PER_MON:
			var method: int = rom.u16le(Gen3Layout.evolution_offset(layout, species, slot))
			if method > Gen3Layout.EVOLUTION_METHOD_LAST:
				return _fail("Species %d's evolution %d has method %d." % [species, slot, method])
	return _ok()


## Null when the pointer at [param at] leaves the cartridge or its string has no end.
static func _pointed_text(rom: RomFile, at: int) -> Variant:
	var offset: int = Gen3Layout.rom_offset(rom.u32le(at))
	if not Gen3Text.ends_within(rom.bytes(), offset, Gen3Layout.TEXT_LIMIT):
		return null
	return Gen3Text.decode_fixed(rom.bytes(), offset, Gen3Layout.TEXT_LIMIT)


static func _item_name(rom: RomFile, layout: Dictionary, item: int) -> String:
	return Gen3Text.decode_fixed(
		rom.bytes(), Gen3Layout.item_offset(layout, item), Gen3Layout.ITEM_NAME_SIZE
	)


## Each row's `itemId` is its index or `ITEM_NONE`, which no other stride gives.
static func _verify_items(rom: RomFile, layout: Dictionary) -> Dictionary:
	var first: Array = [_item_name(rom, layout, 0), _item_name(rom, layout, 1)]
	if first != [UNUSED_ITEM_NAME, FIRST_ITEM_NAME]:
		return _fail("gItems opens on %s." % str(first))
	for item: int in int(layout["item_count"]):
		var at: int = Gen3Layout.item_offset(layout, item)
		var id: int = rom.u16le(at + Gen3Layout.ITEM_ID)
		if id != 0 and id != item:
			return _fail("Item %d's row names item %d." % [item, id])
		if _pointed_text(rom, at + Gen3Layout.ITEM_DESCRIPTION) == null:
			return _fail("Item %d's description has no end." % item)
	return _ok()


static func _ability_name(rom: RomFile, layout: Dictionary, ability: int) -> String:
	return Gen3Text.decode_fixed(
		rom.bytes(), Gen3Layout.ability_name_offset(layout, ability),
		Gen3Layout.ABILITY_NAME_SIZE,
	)


static func _verify_abilities(rom: RomFile, layout: Dictionary) -> Dictionary:
	var read: Array = [
		_ability_name(rom, layout, 1), _ability_name(rom, layout, Gen3Layout.ABILITY_COUNT - 1),
	]
	if read != [FIRST_ABILITY_NAME, LAST_ABILITY_NAME]:
		return _fail("gAbilityNames reads %s." % str(read))
	for ability: int in Gen3Layout.ABILITY_COUNT:
		if _pointed_text(rom, Gen3Layout.ability_description_pointer(layout, ability)) == null:
			return _fail("Ability %d's description has no end." % ability)
	return _ok()


static func _verify_dex_entries(rom: RomFile, layout: Dictionary) -> Dictionary:
	for number: int in DEX_ENDPOINTS:
		var entry: Dictionary = _read_dex_entry(rom, layout, number)
		var read: Array = [entry.get("category"), entry.get("height"), entry.get("weight")]
		if read != DEX_ENDPOINTS[number]:
			return _fail("Dex entry %d reads %s." % [number, str(read)])
	for number: int in range(1, Gen3Layout.NATIONAL_DEX_COUNT + 1):
		if _read_dex_entry(rom, layout, number).is_empty():
			return _fail("Dex entry %d has a page with no end." % number)
	return _ok()


static func _read_dex_entry(rom: RomFile, layout: Dictionary, number: int) -> Dictionary:
	var at: int = Gen3Layout.dex_entry_offset(layout, number)
	var pages: Array = []
	for page: int in int(layout["dex_pages"]):
		var text: Variant = _pointed_text(
			rom, at + Gen3Layout.DEX_ENTRY_DESCRIPTION + page * Gen3Layout.POINTER_SIZE
		)
		if text == null:
			return {}
		pages.append(text)
	var scales: int = at + int(layout["dex_entry_size"]) - Gen3Layout.DEX_ENTRY_SCALES_FROM_END
	return {
		"category": Gen3Text.decode_fixed(rom.bytes(), at, Gen3Layout.DEX_ENTRY_CATEGORY_SIZE),
		"height": rom.u16le(at + Gen3Layout.DEX_ENTRY_HEIGHT),
		"weight": rom.u16le(at + Gen3Layout.DEX_ENTRY_WEIGHT),
		"pages": pages,
		"pokemon_scale": rom.u16le(scales),
		"pokemon_offset": rom.s16le(scales + 2),
		"trainer_scale": rom.u16le(scales + 4),
		"trainer_offset": rom.s16le(scales + 6),
	}


static func import_rom(rom: RomFile, on_progress: Callable = Callable()) -> Dictionary:
	var started: int = Time.get_ticks_msec()
	var directory: String = RomCache.directory_for(rom.id, rom.sha1)
	var result: Dictionary = {"ok": false, "message": "", "directory": directory}
	var layout: Dictionary = Gen3Layout.for_id(rom.id)
	var check: Dictionary = verify_layout(rom)
	if not bool(check["ok"]):
		result["message"] = String(check["message"])
		return result
	RomCache.clear(directory)
	if not RomCache.prepare(directory):
		result["message"] = "Could not create %s." % directory
		return result

	var species: Array = _import_species(rom, layout, on_progress)
	var pics: Dictionary = Gen3Pics.import_pics(rom, layout, directory, species, on_progress)
	if pics.is_empty():
		result["message"] = "Could not write picture atlases."
		return result
	var moves: Array = _import_moves(rom, layout, on_progress)
	var types: Array = _import_types(rom, layout)
	var matchups: Array = _read_matchups(rom, layout)
	var items: Array = _import_items(rom, layout)
	var abilities: Array = _import_abilities(rom, layout)
	var sections: Dictionary = {
		RomCache.species_path(directory): species,
		RomCache.moves_path(directory): moves,
		RomCache.types_path(directory): types,
		RomCache.matchups_path(directory): matchups,
		RomCache.items_path(directory): items,
		RomCache.abilities_path(directory): abilities,
	}
	for path: String in sections:
		if not RomCache.write_json(path, sections[path]):
			result["message"] = "Could not write %s." % path.get_file()
			return result
	var manifest: Dictionary = {
		"format_version": RomCache.FORMAT_VERSION,
		"game_id": String(rom.id),
		"sha1": rom.sha1,
		"generation": RomRegistry.GEN3,
		"species_count": species.size(),
		"move_count": moves.size(),
		"type_count": types.size(),
		"matchup_count": matchups.size(),
		"item_count": items.size(),
		"ability_count": abilities.size(),
		"atlases": pics,
		"complete": true,
	}
	if not RomCache.write_json(RomCache.manifest_path(directory), manifest):
		result["message"] = "Could not write manifest."
		return result

	var evolutions: int = _count_of(species, "evolutions")
	var learnset_moves: int = _count_of(species, "learnset")
	result.merge({
		"ok": true,
		"species": species.size(),
		"moves": moves.size(),
		"types": types.size(),
		"matchups": matchups.size(),
		"items": items.size(),
		"abilities": abilities.size(),
		"evolutions": evolutions,
		"learnset_moves": learnset_moves,
		"elapsed_ms": Time.get_ticks_msec() - started,
	}, true)
	result["message"] = ("%d species, %d moves, %d type matchups, %d items, %d abilities, "
		+ "%d evolutions and %d level-up moves in %d ms.") % [
		species.size(), moves.size(), matchups.size(), items.size(), abilities.size(),
		evolutions, learnset_moves, int(result["elapsed_ms"]),
	]
	return result


static func _count_of(species: Array, key: String) -> int:
	var total: int = 0
	for entry: Dictionary in species:
		total += (entry[key] as Array).size()
	return total


## By national dex number; `index` is the internal species.
static func _import_species(rom: RomFile, layout: Dictionary, on_progress: Callable) -> Array:
	var by_national: Dictionary = _species_by_national(rom, layout)
	var out: Array = []
	for number: int in range(1, Gen3Layout.NATIONAL_DEX_COUNT + 1):
		var species: int = int(by_national[number])
		var record: Dictionary = _species_info(rom, Gen3Layout.species_info_offset(layout, species))
		record.merge({
			"number": number,
			"index": species,
			"hoenn_number": Gen3Layout.hoenn_number(rom, layout, species),
			"name": _species_name(rom, layout, species),
			"learnset": _read_learnset(rom, layout, species),
			"evolutions": _read_evolutions(rom, layout, species),
			"dex": _read_dex_entry(rom, layout, number),
			"palette": Gen3Pics.palette(rom, layout, species),
			"front_tiles": [Gen3Layout.PIC_TILES, Gen3Layout.PIC_TILES],
			"pic_coordinates": Gen3Pics.coordinates(rom, layout, species),
		})
		out.append(record)
		if on_progress.is_valid():
			on_progress.call("species", number, Gen3Layout.NATIONAL_DEX_COUNT)
	return out


## Abilities, items, egg groups and growth rate keep cartridge numbers;
## Generation 3 reorders Generation 2's growth rates.
static func _species_info(rom: RomFile, at: int) -> Dictionary:
	var ev_word: int = rom.u16le(at + Gen3Layout.INFO_EV_YIELD)
	var ev_yield: Dictionary = {}
	for stat: int in Gen3Layout.EV_YIELD_STATS.size():
		ev_yield[Gen3Layout.EV_YIELD_STATS[stat]] = (ev_word >> (stat * 2)) & 0x3
	var color: int = rom.u8(at + Gen3Layout.INFO_COLOR)
	return {
		"stats": {
			"hp": rom.u8(at + Gen3Layout.INFO_HP),
			"attack": rom.u8(at + Gen3Layout.INFO_ATTACK),
			"defense": rom.u8(at + Gen3Layout.INFO_DEFENSE),
			"speed": rom.u8(at + Gen3Layout.INFO_SPEED),
			"sp_attack": rom.u8(at + Gen3Layout.INFO_SP_ATTACK),
			"sp_defense": rom.u8(at + Gen3Layout.INFO_SP_DEFENSE),
		},
		"types": [rom.u8(at + Gen3Layout.INFO_TYPES), rom.u8(at + Gen3Layout.INFO_TYPES + 1)],
		"catch_rate": rom.u8(at + Gen3Layout.INFO_CATCH_RATE),
		"base_exp": rom.u8(at + Gen3Layout.INFO_EXP_YIELD),
		"ev_yield": ev_yield,
		"items": [rom.u16le(at + Gen3Layout.INFO_ITEMS), rom.u16le(at + Gen3Layout.INFO_ITEMS + 2)],
		"gender_ratio": rom.u8(at + Gen3Layout.INFO_GENDER_RATIO),
		"egg_cycles": rom.u8(at + Gen3Layout.INFO_EGG_CYCLES),
		"friendship": rom.u8(at + Gen3Layout.INFO_FRIENDSHIP),
		"growth_rate": rom.u8(at + Gen3Layout.INFO_GROWTH_RATE),
		"egg_groups": [
			rom.u8(at + Gen3Layout.INFO_EGG_GROUPS), rom.u8(at + Gen3Layout.INFO_EGG_GROUPS + 1),
		],
		"abilities": [
			rom.u8(at + Gen3Layout.INFO_ABILITIES), rom.u8(at + Gen3Layout.INFO_ABILITIES + 1),
		],
		"safari_flee_rate": rom.u8(at + Gen3Layout.INFO_SAFARI_FLEE_RATE),
		"body_color": color & ~Gen3Layout.NO_FLIP_BIT,
		"no_flip": (color & Gen3Layout.NO_FLIP_BIT) != 0,
	}


static func _read_evolutions(rom: RomFile, layout: Dictionary, species: int) -> Array:
	var out: Array = []
	for slot: int in Gen3Layout.EVOS_PER_MON:
		var at: int = Gen3Layout.evolution_offset(layout, species, slot)
		var method: int = rom.u16le(at)
		if method == 0:
			continue
		out.append({
			"method": method,
			"parameter": rom.u16le(at + Gen3Layout.EVOLUTION_PARAMETER),
			"target": Gen3Layout.national_number(
				rom, layout, rom.u16le(at + Gen3Layout.EVOLUTION_TARGET)
			),
		})
	return out


static func _import_moves(rom: RomFile, layout: Dictionary, on_progress: Callable) -> Array:
	var out: Array = []
	for move: int in range(1, Gen3Layout.MOVES_COUNT):
		var at: int = Gen3Layout.move_offset(layout, move)
		out.append({
			"number": move,
			"name": _move_name(rom, layout, move),
			"effect": rom.u8(at + Gen3Layout.MOVE_EFFECT),
			"power": rom.u8(at + Gen3Layout.MOVE_POWER),
			"type": rom.u8(at + Gen3Layout.MOVE_TYPE),
			"accuracy": rom.u8(at + Gen3Layout.MOVE_ACCURACY),
			"pp": rom.u8(at + Gen3Layout.MOVE_PP),
			"effect_chance": rom.u8(at + Gen3Layout.MOVE_EFFECT_CHANCE),
			"target": rom.u8(at + Gen3Layout.MOVE_TARGET),
			"priority": rom.s8(at + Gen3Layout.MOVE_PRIORITY),
			"flags": rom.u8(at + Gen3Layout.MOVE_FLAGS),
		})
		if on_progress.is_valid():
			on_progress.call("moves", move, Gen3Layout.MOVES_COUNT - 1)
	return out


static func _import_types(rom: RomFile, layout: Dictionary) -> Array:
	var out: Array = []
	for type: int in Gen3Layout.TYPE_COUNT:
		out.append({
			"number": type,
			"name": _type_name(rom, layout, type),
			"special": Gen3Layout.is_special_type(type),
		})
	return out


## Cartridge numbers, like [method _species_info]'s; pockets differ between games.
static func _import_items(rom: RomFile, layout: Dictionary) -> Array:
	var out: Array = []
	for item: int in range(1, int(layout["item_count"])):
		var at: int = Gen3Layout.item_offset(layout, item)
		out.append({
			"number": item,
			"name": _item_name(rom, layout, item),
			"unused": rom.u16le(at + Gen3Layout.ITEM_ID) == 0,
			"price": rom.u16le(at + Gen3Layout.ITEM_PRICE),
			"hold_effect": rom.u8(at + Gen3Layout.ITEM_HOLD_EFFECT),
			"hold_effect_parameter": rom.u8(at + Gen3Layout.ITEM_HOLD_EFFECT_PARAM),
			"description": _pointed_text(rom, at + Gen3Layout.ITEM_DESCRIPTION),
			"importance": rom.u8(at + Gen3Layout.ITEM_IMPORTANCE),
			"registrability": rom.u8(at + Gen3Layout.ITEM_REGISTRABILITY),
			"pocket": rom.u8(at + Gen3Layout.ITEM_POCKET),
			"type": rom.u8(at + Gen3Layout.ITEM_TYPE),
			"battle_usage": rom.u8(at + Gen3Layout.ITEM_BATTLE_USAGE),
			"secondary_id": rom.u8(at + Gen3Layout.ITEM_SECONDARY_ID),
		})
	return out


static func _import_abilities(rom: RomFile, layout: Dictionary) -> Array:
	var out: Array = []
	for ability: int in Gen3Layout.ABILITY_COUNT:
		out.append({
			"number": ability,
			"name": _ability_name(rom, layout, ability),
			"description": _pointed_text(
				rom, Gen3Layout.ability_description_pointer(layout, ability)
			),
		})
	return out
