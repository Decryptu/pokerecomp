class_name Gen1Importer
extends RefCounted

## Decodes a verified Generation 1 cartridge into the cache under `user://`, the
## counterpart of [RomImporter]. The cache format is shared: a section this
## generation has no table for goes unwritten and [GameData] keeps its default.
## The species, move, type, item and trainer layer is here; the world is not,
## which is why [RomRegistry] marks these cartridges unplayable.

## What the tables are known to say, independently of the cartridge, from pret's
## own data files. A wrong offset reads plausible garbage rather than failing, so
## each is pinned at both ends: a right start with a wrong stride fails too.
const FIRST_SPECIES_NAME: String = "BULBASAUR"
const LAST_SPECIES_NAME: String = "MEW"
const FIRST_MOVE_NAME: String = "POUND"
const LAST_MOVE_NAME: String = "STRUGGLE"
const FIRST_ITEM_NAME: String = "MASTER BALL"
const FIRST_TYPE_NAME: String = "NORMAL"
const LAST_TYPE_NAME: String = "DRAGON"
const FIRST_TRAINER_NAME: String = "YOUNGSTER"

## Bulbasaur's whole `BaseStats` row, which says the record size and member
## order are both right.
const FIRST_STATS: Array[int] = [45, 49, 49, 45, 65]
const FIRST_TYPES: Array[int] = [0x16, 0x03]
const FIRST_CATCH_RATE: int = 45
const FIRST_BASE_EXP: int = 64

## `PokedexOrder` and `PokedexEntryPointers` both open on Rhydon, dex 112.
const FIRST_INDEX_DEX_NUMBER: int = 112
const FIRST_DEX_CATEGORY: String = "SEED"
const FIRST_DEX_HEIGHT_FEET: int = 2
const FIRST_DEX_HEIGHT_INCHES: int = 4
const FIRST_DEX_WEIGHT: int = 150

## `TechnicalMachines`' first and last rows: TM01 is Mega Punch and HM05 is Flash.
const FIRST_TM_MOVE: int = 0x05
const LAST_HM_MOVE: int = 0x94

## `TypeEffects`' first row, water beating fire twice over.
const FIRST_MATCHUP: Array[int] = [0x15, 0x14, 20]

## Bulbasaur's `MonsterPalettes` row, PAL_GREENMON, and the colours
## `SuperPalettes` gives it: two tables in one check, one being an index into
## the other. Yellow retuned them all for the Game Boy Color.
const FIRST_SUPER_PALETTE: int = 0x16
const FIRST_PALETTE_COLORS: Dictionary = {
	RomRegistry.RED: [32703, 17236, 11913, 2115],
	RomRegistry.BLUE: [32703, 17236, 11913, 2115],
	RomRegistry.YELLOW: [31743, 19352, 16045, 6342],
}

## A runaway guard for the terminated name tables, longer than any entry.
const MAX_NAME_LENGTH: int = 20
## `PokedexEntry` descriptions run to two pages of three lines.
const MAX_DEX_TEXT: int = 256
## An `EvosMoves` record cannot outrun this; the longest learnset is well under.
const MAX_EVOS_MOVES: int = 128

## When the import last handed the main loop a frame. See [method _breathe].
var _last_breath: int = 0


## Hands the main loop a frame if one is due, so a launcher keeps drawing.
func _breathe(yield_ms: int) -> void:
	if yield_ms <= 0:
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_breath < yield_ms:
		return
	_last_breath = now
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop != null:
		await loop.process_frame


## The checks a layout has to pass before a byte is decoded for content.
static var LAYOUT_CHECKS: Array[Callable] = [
	_verify_species_names,
	_verify_base_stats,
	_verify_move_names,
	_verify_move_data,
	_verify_type_names,
	_verify_type_effects,
	_verify_item_names,
	_verify_tmhm_moves,
	_verify_dex_order,
	_verify_dex_entries,
	_verify_trainer_names,
	_verify_palettes,
	_verify_wild_constants,
	_verify_pic_pointers,
	_verify_font,
	_verify_text_box,
	_verify_world,
]


static func verify_layout(rom: RomFile) -> Dictionary:
	var layout: Dictionary = Gen1Layout.for_id(rom.id)
	if layout.is_empty():
		return {"ok": false, "message": "No layout for %s." % rom.id}
	for check: Callable in LAYOUT_CHECKS:
		var result: Dictionary = check.call(rom, layout)
		if not bool(result.get("ok", false)):
			return result
	return {"ok": true, "message": "Layout verified."}


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "message": message}


static func _ok() -> Dictionary:
	return {"ok": true, "message": ""}


## `MonsterNames` is by internal index, so both names are found through
## `PokedexOrder` rather than at a fixed row.
static func _verify_species_names(rom: RomFile, layout: Dictionary) -> Dictionary:
	var data: PackedByteArray = rom.bytes()
	var slots: PackedInt32Array = read_index_of_dex(rom, layout)
	if slots.size() != Gen1Layout.SPECIES_COUNT + 1:
		return _fail("PokedexOrder does not name %d species." % Gen1Layout.SPECIES_COUNT)
	var first: String = Gen1Text.decode_fixed(
		data, Gen1Layout.species_name_offset(layout, slots[1]), Gen1Layout.NAME_LENGTH
	)
	var last: String = Gen1Text.decode_fixed(
		data,
		Gen1Layout.species_name_offset(layout, slots[Gen1Layout.SPECIES_COUNT]),
		Gen1Layout.NAME_LENGTH,
	)
	if first != FIRST_SPECIES_NAME or last != LAST_SPECIES_NAME:
		return _fail("Species names read '%s' and '%s'." % [first, last])
	return _ok()


static func _verify_base_stats(rom: RomFile, layout: Dictionary) -> Dictionary:
	var stats: int = Gen1Layout.base_stats_offset(layout, 1)
	if rom.u8(stats + Gen1Layout.BASE_DEX_NO) != 1:
		return _fail("BaseStats row 1 does not carry dex number 1.")
	var read: Array[int] = [
		rom.u8(stats + Gen1Layout.BASE_HP),
		rom.u8(stats + Gen1Layout.BASE_ATTACK),
		rom.u8(stats + Gen1Layout.BASE_DEFENSE),
		rom.u8(stats + Gen1Layout.BASE_SPEED),
		rom.u8(stats + Gen1Layout.BASE_SPECIAL),
	]
	if read != FIRST_STATS:
		return _fail("BaseStats row 1 reads %s." % str(read))
	var types: Array[int] = [
		rom.u8(stats + Gen1Layout.BASE_TYPE_1), rom.u8(stats + Gen1Layout.BASE_TYPE_2)
	]
	if types != FIRST_TYPES:
		return _fail("BaseStats row 1 types read %s." % str(types))
	if rom.u8(stats + Gen1Layout.BASE_CATCH_RATE) != FIRST_CATCH_RATE \
		or rom.u8(stats + Gen1Layout.BASE_EXP) != FIRST_BASE_EXP:
		return _fail("BaseStats row 1 catch rate or base experience is wrong.")
	# Mew's own row, wherever this cartridge keeps it.
	if rom.u8(Gen1Layout.base_stats_offset(layout, Gen1Layout.SPECIES_COUNT)) \
		!= Gen1Layout.SPECIES_COUNT:
		return _fail("Mew's BaseStats row does not carry dex number 151.")
	return _ok()


static func _verify_move_names(rom: RomFile, layout: Dictionary) -> Dictionary:
	var names: PackedStringArray = Gen1Text.decode_sequence(
		rom.bytes(), int(layout["move_names"]), Gen1Layout.MOVE_COUNT, MAX_NAME_LENGTH
	)
	if names.size() != Gen1Layout.MOVE_COUNT:
		return _fail("MoveNames holds %d names." % names.size())
	if names[0] != FIRST_MOVE_NAME or names[Gen1Layout.MOVE_COUNT - 1] != LAST_MOVE_NAME:
		return _fail("Move names read '%s' and '%s'." % [names[0], names[names.size() - 1]])
	return _ok()


## Every row's animation byte is its own move number, which pins the stride
## across the table rather than at its ends.
static func _verify_move_data(rom: RomFile, layout: Dictionary) -> Dictionary:
	for move: int in range(1, Gen1Layout.MOVE_COUNT + 1):
		var entry: int = Gen1Layout.move_offset(layout, move)
		if rom.u8(entry + Gen1Layout.MOVE_ANIMATION) != move:
			return _fail("Moves row %d names animation %d." % [
				move, rom.u8(entry + Gen1Layout.MOVE_ANIMATION)
			])
	return _ok()


static func _verify_type_names(rom: RomFile, layout: Dictionary) -> Dictionary:
	var first: String = read_type_name(rom, layout, 0)
	var last: String = read_type_name(rom, layout, Gen1Layout.TYPE_COUNT - 1)
	if first != FIRST_TYPE_NAME or last != LAST_TYPE_NAME:
		return _fail("Type names read '%s' and '%s'." % [first, last])
	return _ok()


static func _verify_type_effects(rom: RomFile, layout: Dictionary) -> Dictionary:
	var table: int = int(layout["type_effects"])
	var read: Array[int] = [rom.u8(table), rom.u8(table + 1), rom.u8(table + 2)]
	if read != FIRST_MATCHUP:
		return _fail("TypeEffects opens on %s." % str(read))
	return _ok()


static func _verify_item_names(rom: RomFile, layout: Dictionary) -> Dictionary:
	var names: PackedStringArray = Gen1Text.decode_sequence(
		rom.bytes(), int(layout["item_names"]), Gen1Layout.ITEM_COUNT, MAX_NAME_LENGTH
	)
	if names.size() != Gen1Layout.ITEM_COUNT or names[0] != FIRST_ITEM_NAME:
		return _fail("Item names open on '%s'." % (names[0] if not names.is_empty() else ""))
	return _ok()


static func _verify_tmhm_moves(rom: RomFile, layout: Dictionary) -> Dictionary:
	var table: int = int(layout["tmhm_moves"])
	var count: int = Gen1Layout.TM_COUNT + Gen1Layout.HM_COUNT
	if rom.u8(table) != FIRST_TM_MOVE or rom.u8(table + count - 1) != LAST_HM_MOVE:
		return _fail("TechnicalMachines reads %d and %d at its ends." % [
			rom.u8(table), rom.u8(table + count - 1)
		])
	return _ok()


static func _verify_dex_order(rom: RomFile, layout: Dictionary) -> Dictionary:
	var order: int = int(layout["dex_order"])
	if rom.u8(order) != FIRST_INDEX_DEX_NUMBER:
		return _fail("PokedexOrder opens on dex number %d." % rom.u8(order))
	return _ok()


## Slot 1 is Rhydon, so the first pointer leads to Rhydon's own entry.
static func _verify_dex_entries(rom: RomFile, layout: Dictionary) -> Dictionary:
	var entry: Dictionary = read_dex_entry(rom, layout, 1)
	if String(entry["category"]) != "DRILL":
		return _fail("The first Pokedex entry is categorised '%s'." % entry["category"])
	return _ok()


static func _verify_palettes(rom: RomFile, layout: Dictionary) -> Dictionary:
	var named: int = rom.u8(Gen1Layout.mon_palette_offset(layout, 1))
	if named != FIRST_SUPER_PALETTE:
		return _fail("Bulbasaur's MonsterPalettes row names palette %d." % named)
	var at: int = Gen1Layout.super_palette_offset(layout, named)
	var colors: Array[int] = []
	for slot: int in Gen1Layout.SUPER_PALETTE_COLORS:
		colors.append(rom.u16le(at + slot * PokePalette.COLOR_BYTES))
	if colors != FIRST_PALETTE_COLORS.get(rom.id, []):
		return _fail("PAL_GREENMON reads %s." % str(colors))
	return _ok()


## The two wild tables this port keeps as constants rather than importing:
## `WildMonEncounterSlotChances`, whose second column is the slot it already is,
## and `GoodRodMons`. Neither is per-map, and reading them back is what says the
## constants still describe the cartridge.
static func _verify_wild_constants(rom: RomFile, layout: Dictionary) -> Dictionary:
	var at: int = int(layout["wild_chances"])
	for slot: int in Gen1Layout.WILD_SLOT_CHANCES.size():
		var row: int = at + slot * Gen1Layout.WILD_CHANCE_SIZE
		if rom.u8(row) != Gen1Layout.WILD_SLOT_CHANCES[slot] or rom.u8(row + 1) != slot * 2:
			return _fail("Wild slot %d wins on %d, not %d." % [
				slot, rom.u8(row), Gen1Layout.WILD_SLOT_CHANCES[slot],
			])
	at = int(layout["good_rod"])
	for slot: int in Gen1Layout.GOOD_ROD_SLOTS.size():
		var row: Array = Gen1Layout.GOOD_ROD_SLOTS[slot]
		if rom.u8(at + slot * 2) != int(row[0]) or rom.u8(at + slot * 2 + 1) != int(row[1]):
			return _fail("GoodRodMons row %d reads level %d, index %d." % [
				slot, rom.u8(at + slot * 2), rom.u8(at + slot * 2 + 1),
			])
	return _ok()


## `BASE_PIC_SIZE` is the first byte of the `.pic` file itself, so comparing it
## with the byte the pointer lands on proves the pointer, the bank rule and the
## stride for every species at once.
static func _verify_pic_pointers(rom: RomFile, layout: Dictionary) -> Dictionary:
	var slots: PackedInt32Array = read_index_of_dex(rom, layout)
	for dex: int in range(1, Gen1Layout.SPECIES_COUNT + 1):
		var stats: int = Gen1Layout.base_stats_offset(layout, dex)
		var front: int = _pic_offset(rom, layout, stats + Gen1Layout.BASE_FRONT_PIC, slots[dex])
		if front < 0:
			return _fail("Species %d has no reachable front pic pointer." % dex)
		if rom.u8(front) != rom.u8(stats + Gen1Layout.BASE_PIC_SIZE):
			return _fail("Species %d's front pic does not open on its own size." % dex)
	return _ok()


## Neither sheet carries a name or a number, so the charmap checks them: one read
## a tile early or late loses a glyph and gains one in the $C0 to $DF hole.
static func _verify_font(rom: RomFile, layout: Dictionary) -> Dictionary:
	var length: int = Gen1Layout.FONT_TILES * PokeTiles.TILE_1BPP_BYTES
	if not rom.in_bounds(int(layout["font"]), length):
		return _fail("FontGraphics runs past the end of the dump.")

	for run: Array in Gen1Layout.FONT_INK_RUNS:
		for code: int in range(int(run[0]), int(run[1]) + 1):
			if _font_rows(rom, layout, code).count(0) == PokeTiles.TILE_1BPP_BYTES:
				return _fail("FontGraphics: code $%02X (%s) has no glyph." % [
					code, Gen1Text.character(code),
				])
	for run: Array in Gen1Layout.FONT_BLANK_RUNS:
		for code: int in range(int(run[0]), int(run[1]) + 1):
			if _font_rows(rom, layout, code).count(0) != PokeTiles.TILE_1BPP_BYTES:
				return _fail("FontGraphics: code $%02X has a glyph but no character." % code)

	# Every character leaves its spacing column clear, so a solid row is graphics.
	for i: int in length:
		if rom.u8(int(layout["font"]) + i) == 0xFF:
			return _fail("FontGraphics: solid row at byte %d; not font data." % i)
	return _ok()


## The 2bpp half: every tile draws but the space, and the border's own column is
## eight rows of one pattern no neighbouring sheet reproduces.
static func _verify_text_box(rom: RomFile, layout: Dictionary) -> Dictionary:
	if not rom.in_bounds(
		int(layout["text_box"]), Gen1Layout.FONT_EXTRA_TILES * PokeTiles.TILE_BYTES
	):
		return _fail("TextBoxGraphics runs past the end of the dump.")

	var last: int = Gen1Layout.FONT_EXTRA_FIRST_CODE + Gen1Layout.FONT_EXTRA_TILES - 1
	for code: int in range(Gen1Layout.FONT_EXTRA_FIRST_CODE, last + 1):
		var blank: bool = _text_box_rows(rom, layout, code).count(0) \
			== PokeTiles.TILE_1BPP_BYTES
		if blank != (code == Gen1Layout.SPACE_CODE):
			return _fail("TextBoxGraphics: code $%02X is %s." % [
				code, "blank" if blank else "drawn",
			])

	var vertical: Array[int] = _text_box_rows(rom, layout, Gen1Layout.FRAME_VERTICAL_CODE)
	if vertical.count(Gen1Layout.FRAME_VERTICAL_ROW) != PokeTiles.TILE_1BPP_BYTES:
		return _fail("TextBoxGraphics: $%02X is not the border's own column." % \
			Gen1Layout.FRAME_VERTICAL_CODE)
	return _ok()


## Every map and tileset decodes, which is the world layout's own check: a wrong
## table reaches a tileset number, a map size or a block index the cartridge
## cannot hold.
static func _verify_world(rom: RomFile, _layout: Dictionary) -> Dictionary:
	return Gen1WorldImporter.verify_layout(rom)


## One tile as eight row masks, a set bit per lit pixel; the 2bpp sheet folds
## its two planes together.
static func _font_rows(rom: RomFile, layout: Dictionary, code: int) -> Array[int]:
	var at: int = Gen1Layout.font_glyph_offset(layout, code)
	var rows: Array[int] = []
	for row: int in PokeTiles.TILE_1BPP_BYTES:
		rows.append(rom.u8(at + row))
	return rows


static func _text_box_rows(rom: RomFile, layout: Dictionary, code: int) -> Array[int]:
	var at: int = Gen1Layout.text_box_glyph_offset(layout, code)
	var rows: Array[int] = []
	for row: int in PokeTiles.TILE_1BPP_BYTES:
		rows.append(rom.u8(at + 2 * row) | rom.u8(at + 2 * row + 1))
	return rows


static func _verify_trainer_names(rom: RomFile, layout: Dictionary) -> Dictionary:
	var names: PackedStringArray = Gen1Text.decode_sequence(
		rom.bytes(), int(layout["trainer_names"]), Gen1Layout.TRAINER_CLASS_COUNT,
		MAX_NAME_LENGTH,
	)
	if names.size() != Gen1Layout.TRAINER_CLASS_COUNT or names[0] != FIRST_TRAINER_NAME:
		return _fail("Trainer names open on '%s'." % (names[0] if not names.is_empty() else ""))
	return _ok()


## `PokedexOrder` inverted: dex number to internal index, row 0 unused so a dex
## number indexes it directly.
static func read_index_of_dex(rom: RomFile, layout: Dictionary) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	out.resize(Gen1Layout.SPECIES_COUNT + 1)
	var order: int = int(layout["dex_order"])
	for index: int in range(1, Gen1Layout.INDEX_COUNT + 1):
		var dex: int = rom.u8(order + index - 1)
		if dex >= 1 and dex <= Gen1Layout.SPECIES_COUNT:
			out[dex] = index
	return out


static func read_type_name(rom: RomFile, layout: Dictionary, type: int) -> String:
	return Gen1Text.decode(
		rom.bytes(), Gen1Layout.pointer_target(rom, layout, "type_names", type), MAX_NAME_LENGTH
	)


## One `PokedexEntry` by internal index, description included.
static func read_dex_entry(rom: RomFile, layout: Dictionary, index: int) -> Dictionary:
	var data: PackedByteArray = rom.bytes()
	var at: int = Gen1Layout.pointer_target(rom, layout, "dex_entries", index - 1)
	var category: String = Gen1Text.decode(data, at, Gen1Layout.DEX_CATEGORY_MAX)
	var after: int = Gen1Text.terminated_end(data, at, Gen1Layout.DEX_CATEGORY_MAX)
	var feet: int = rom.u8(after)
	var inches: int = rom.u8(after + 1)
	var weight: int = rom.u16le(after + 2)
	var text: String = ""
	if rom.u8(after + 4) == Gen1Layout.DEX_TEXT_FAR:
		var target: int = RomFile.linear(rom.u8(after + 7), rom.u16le(after + 5))
		text = Gen1Text.decode_dex_text(data, target, MAX_DEX_TEXT)
	return {
		"category": category,
		# Feet and inches as one decimal number, the way Generation 2 stores the
		# same measurement: 204 is 2'04".
		"height": feet * 100 + inches,
		"weight": weight,
		"text": text,
	}


## One `EvosMoves` record by internal index, as { evolutions, learnset }.
static func read_evos_moves(rom: RomFile, layout: Dictionary, index: int) -> Dictionary:
	var at: int = Gen1Layout.pointer_target(rom, layout, "evos_moves", index - 1)
	var evolutions: Array = []
	var walked: int = 0
	while walked < MAX_EVOS_MOVES:
		var method: int = rom.u8(at)
		if method == 0:
			at += 1
			break
		var size: int = int(Gen1Layout.EVOLVE_SIZES.get(method, 0))
		if size == 0:
			break
		evolutions.append(_evolution_row(rom, layout, at, method, size))
		at += size
		walked += size
	var learnset: Array = []
	while walked < MAX_EVOS_MOVES and rom.u8(at) != 0:
		learnset.append({"level": rom.u8(at), "move": rom.u8(at + 1)})
		at += 2
		walked += 2
	return {"evolutions": evolutions, "learnset": learnset}


## The evolved species is stored as an internal index and the cache speaks dex
## numbers, so it is translated here rather than by every reader.
static func _evolution_row(
	rom: RomFile, layout: Dictionary, at: int, method: int, size: int
) -> Dictionary:
	var target: int = rom.u8(at + size - 1)
	var row: Dictionary = {"method": method, "species": dex_of_index(rom, layout, target)}
	if method == Gen1Layout.EVOLVE_LEVEL:
		row["level"] = rom.u8(at + 1)
	elif method == Gen1Layout.EVOLVE_ITEM:
		row["item"] = rom.u8(at + 1)
		row["level"] = rom.u8(at + 2)
	else:
		row["level"] = rom.u8(at + 1)
	return row


## `PokedexOrder` read forwards: the dex number an internal index carries, or
## zero for a slot no species claims.
static func dex_of_index(rom: RomFile, layout: Dictionary, index: int) -> int:
	if index < 1 or index > Gen1Layout.INDEX_COUNT:
		return 0
	return rom.u8(int(layout["dex_order"]) + index - 1)


## Reads the cartridge into its cache. Answers the same { ok, message, ... }
## shape [method RomImporter.import_rom] does, so the launcher reports either
## generation the same way.
func import_rom(
	rom: RomFile, on_progress: Callable = Callable(), yield_ms: int = 0
) -> Dictionary:
	var started: int = Time.get_ticks_msec()
	_last_breath = started
	var directory: String = RomCache.directory_for(rom.id, rom.sha1)
	var result: Dictionary = {
		"ok": false,
		"message": "",
		"directory": directory,
		"species": 0,
		"moves": 0,
		"items": 0,
		"types": 0,
		"matchups": 0,
		"trainers": 0,
		"evolutions": 0,
		"learnset_moves": 0,
		"maps": 0,
		"tilesets": 0,
		"sprites": 0,
		"encounters": 0,
		"elapsed_ms": 0,
	}

	var layout: Dictionary = Gen1Layout.for_id(rom.id)
	var check: Dictionary = verify_layout(rom)
	if not bool(check["ok"]):
		result["message"] = String(check["message"])
		return result

	# A half-written cache from an interrupted run must not be mistaken for a
	# good one, so the old directory goes before the new one is built and the
	# manifest is only marked complete at the very end.
	RomCache.clear(directory)
	if not RomCache.prepare(directory):
		result["message"] = "Could not create %s." % directory
		return result

	var species: Array = _import_species(rom, layout, on_progress)
	await _breathe(yield_ms)
	var moves: Array = _import_moves(rom, layout, on_progress)
	await _breathe(yield_ms)
	var types: Array = _import_types(rom, layout)
	var matchups: Array = _import_matchups(rom, layout)
	if matchups.is_empty():
		result["message"] = "TypeEffects is outside the cartridge or malformed."
		return result
	await _breathe(yield_ms)
	var items: Array = _import_items(rom, layout)
	var tmhm_moves: Array = _import_tmhm_moves(rom, layout)
	var trainers: Array = _import_trainers(rom, layout)
	await _breathe(yield_ms)
	var pics: Dictionary = _import_pics(rom, layout, species, on_progress)
	if pics.is_empty():
		result["message"] = "Could not decode every picture."
		return result
	await _breathe(yield_ms)
	var tiles: Dictionary = _import_tiles(rom, layout)
	if tiles.is_empty():
		result["message"] = "Could not write the font."
		return result
	await _breathe(yield_ms)
	var world: Dictionary = Gen1WorldImporter.import_to_cache(rom, layout, directory, on_progress)
	if not bool(world["ok"]):
		result["message"] = String(world["message"])
		return result
	await _breathe(yield_ms)

	var sections: Dictionary = {
		RomCache.species_path(directory): species,
		RomCache.moves_path(directory): moves,
		RomCache.types_path(directory): types,
		RomCache.matchups_path(directory): matchups,
		RomCache.items_path(directory): items,
		RomCache.tmhm_moves_path(directory): tmhm_moves,
		RomCache.trainers_path(directory): trainers,
	}
	for path: String in sections:
		if not RomCache.write_json(path, sections[path]):
			result["message"] = "Could not write %s." % path.get_file()
			return result

	var manifest: Dictionary = {
		"format_version": RomCache.FORMAT_VERSION,
		"game_id": String(rom.id),
		"sha1": rom.sha1,
		"generation": RomRegistry.GEN1,
		"species_count": species.size(),
		"move_count": moves.size(),
		"item_count": items.size(),
		"type_count": types.size(),
		"matchup_count": matchups.size(),
		"trainer_count": trainers.size(),
		"map_count": int(world["maps"]),
		"tileset_count": int(world["tilesets"]),
		"overworld_sprite_count": int(world["sprites"]),
		"encounter_count": int(world["encounters"]),
		"atlases": pics,
		"tiles": tiles,
		"complete": true,
	}
	if not RomCache.write_json(RomCache.manifest_path(directory), manifest):
		result["message"] = "Could not write manifest."
		return result

	result["ok"] = true
	result["species"] = species.size()
	result["moves"] = moves.size()
	result["items"] = items.size()
	result["types"] = types.size()
	result["matchups"] = matchups.size()
	result["trainers"] = trainers.size()
	result["evolutions"] = _count_of(species, "evolutions")
	result["learnset_moves"] = _count_of(species, "learnset")
	result["maps"] = int(world["maps"])
	result["tilesets"] = int(world["tilesets"])
	result["sprites"] = int(world["sprites"])
	result["encounters"] = int(world["encounters"])
	result["elapsed_ms"] = Time.get_ticks_msec() - started
	result["message"] = ("%d species, %d moves, %d items, %d type matchups, "
		+ "%d trainer classes, %d evolutions, %d level-up moves, %d maps, "
		+ "%d tilesets, %d overworld sprites and %d wild encounter tables "
		+ "in %d ms.") % [
		species.size(), moves.size(), items.size(), matchups.size(), trainers.size(),
		result["evolutions"], result["learnset_moves"], result["maps"],
		result["tilesets"], result["sprites"], result["encounters"],
		result["elapsed_ms"],
	]
	return result


static func _count_of(species: Array, key: String) -> int:
	var out: int = 0
	for entry: Dictionary in species:
		out += (entry[key] as Array).size()
	return out


## Keyed by dex number the way the Generation 2 cache is. Anything the
## cartridge stores per slot is reached through `PokedexOrder`, and the slot is
## kept for a reader that needs the cartridge's own numbering.
func _import_species(rom: RomFile, layout: Dictionary, on_progress: Callable) -> Array:
	var data: PackedByteArray = rom.bytes()
	var slots: PackedInt32Array = read_index_of_dex(rom, layout)
	var out: Array = []

	for dex: int in range(1, Gen1Layout.SPECIES_COUNT + 1):
		var index: int = slots[dex]
		var stats: int = Gen1Layout.base_stats_offset(layout, dex)
		var dimensions: int = rom.u8(stats + Gen1Layout.BASE_PIC_SIZE)
		var evos_moves: Dictionary = read_evos_moves(rom, layout, index)
		var entry: Dictionary = read_dex_entry(rom, layout, index)
		var special: int = rom.u8(stats + Gen1Layout.BASE_SPECIAL)

		out.append({
			"number": dex,
			"index": index,
			"name": Gen1Text.decode_fixed(
				data, Gen1Layout.species_name_offset(layout, index), Gen1Layout.NAME_LENGTH
			),
			# One Special stat: the split into Sp. Attack and Sp. Defense is
			# Generation 2's.
			"stats": {
				"hp": rom.u8(stats + Gen1Layout.BASE_HP),
				"attack": rom.u8(stats + Gen1Layout.BASE_ATTACK),
				"defense": rom.u8(stats + Gen1Layout.BASE_DEFENSE),
				"speed": rom.u8(stats + Gen1Layout.BASE_SPEED),
				"special": special,
			},
			"types": [
				rom.u8(stats + Gen1Layout.BASE_TYPE_1),
				rom.u8(stats + Gen1Layout.BASE_TYPE_2),
			],
			"catch_rate": rom.u8(stats + Gen1Layout.BASE_CATCH_RATE),
			"base_exp": rom.u8(stats + Gen1Layout.BASE_EXP),
			"growth_rate": rom.u8(stats + Gen1Layout.BASE_GROWTH_RATE),
			"tmhm": Array(rom.slice(stats + Gen1Layout.BASE_TMHM, Gen1Layout.BASE_TMHM_BYTES)),
			# The moves a freshly caught one knows, which Generation 2 dropped
			# in favour of reading the learnset back.
			"starting_moves": _starting_moves(rom, stats),
			"evolutions": evos_moves["evolutions"],
			"learnset": evos_moves["learnset"],
			# Width in the high nybble, height in the low one, in tiles.
			"front_tiles": [dimensions >> 4, dimensions & 0x0F],
			# Not `pics`, which is the key a mod's own artwork arrives under.
			"pic_offsets": {
				"front": _pic_offset(rom, layout, stats + Gen1Layout.BASE_FRONT_PIC, index),
				"back": _pic_offset(rom, layout, stats + Gen1Layout.BASE_BACK_PIC, index),
			},
			"dex": {
				"category": entry["category"],
				"height": entry["height"],
				"weight": entry["weight"],
				"pages": [entry["text"]],
			},
			"palette": _import_palette(rom, layout, dex),
		})

		if on_progress.is_valid():
			on_progress.call("species", dex, Gen1Layout.SPECIES_COUNT)

	return out


static func _starting_moves(rom: RomFile, stats: int) -> Array:
	var out: Array = []
	for slot: int in Gen1Layout.BASE_MOVE_COUNT:
		var move: int = rom.u8(stats + Gen1Layout.BASE_MOVES + slot)
		if move != 0:
			out.append(move)
	return out


## Two bytes and no bank; `UncompressMonSprite` picks the bank from the internal
## index. Answers -1 for a pointer outside the banked window.
static func _pic_offset(rom: RomFile, layout: Dictionary, at: int, index: int) -> int:
	var address: int = rom.u16le(at)
	if address < RomFile.BANK_SIZE or address >= RomFile.BANK_SIZE * 2:
		return -1
	return RomFile.linear(Gen1Layout.pic_bank(layout, index), address)


## The four colours a Super Game Boy or a Game Boy Color draws this species in,
## as the cartridge's own packed 15-bit values.
static func _import_palette(rom: RomFile, layout: Dictionary, dex: int) -> Dictionary:
	var named: int = rom.u8(Gen1Layout.mon_palette_offset(layout, dex))
	var at: int = Gen1Layout.super_palette_offset(layout, named)
	var colors: Array = []
	for slot: int in Gen1Layout.SUPER_PALETTE_COLORS:
		colors.append(rom.u16le(at + slot * PokePalette.COLOR_BYTES))
	return {"super": named, "colors": colors}


func _import_moves(rom: RomFile, layout: Dictionary, on_progress: Callable) -> Array:
	var names: PackedStringArray = Gen1Text.decode_sequence(
		rom.bytes(), int(layout["move_names"]), Gen1Layout.MOVE_COUNT, MAX_NAME_LENGTH
	)
	var out: Array = []
	for move: int in range(1, Gen1Layout.MOVE_COUNT + 1):
		var entry: int = Gen1Layout.move_offset(layout, move)
		# The animation byte is dropped: [method _verify_move_data] has already
		# spent it proving the stride.
		out.append({
			"number": move,
			"name": names[move - 1],
			"effect": rom.u8(entry + Gen1Layout.MOVE_EFFECT),
			"power": rom.u8(entry + Gen1Layout.MOVE_POWER),
			"type": rom.u8(entry + Gen1Layout.MOVE_TYPE),
			"accuracy": rom.u8(entry + Gen1Layout.MOVE_ACCURACY),
			"pp": rom.u8(entry + Gen1Layout.MOVE_PP),
		})
		if on_progress.is_valid():
			on_progress.call("moves", move, Gen1Layout.MOVE_COUNT)
	return out


## The 27 rows of `TypeNames` less the $09 to $13 hole, which is filled with
## NORMAL and named by nothing.
func _import_types(rom: RomFile, layout: Dictionary) -> Array:
	var out: Array = []
	for type: int in Gen1Layout.TYPE_COUNT:
		if not Gen1Layout.is_real_type(type):
			continue
		out.append({
			"number": type,
			"name": read_type_name(rom, layout, type),
			"special": Gen1Layout.is_special_type(type),
		})
	return out


## `TypeEffects`, exceptions only: a neutral matchup is an absent row. Empty
## when the table runs off the cartridge without its terminator.
func _import_matchups(rom: RomFile, layout: Dictionary) -> Array:
	var at: int = int(layout["type_effects"])
	var out: Array = []
	while rom.in_bounds(at, Gen1Layout.TYPE_EFFECT_SIZE):
		if rom.u8(at) == Gen1Layout.TYPE_EFFECT_END:
			return out
		out.append({
			"attacker": rom.u8(at),
			"defender": rom.u8(at + 1),
			"multiplier": rom.u8(at + 2),
		})
		at += Gen1Layout.TYPE_EFFECT_SIZE
	return []


## `ItemNames` and `ItemPrices`. A price is three packed-decimal bytes, unpacked
## here rather than stored as it lies.
func _import_items(rom: RomFile, layout: Dictionary) -> Array:
	var names: PackedStringArray = Gen1Text.decode_sequence(
		rom.bytes(), int(layout["item_names"]), Gen1Layout.ITEM_COUNT, MAX_NAME_LENGTH
	)
	var out: Array = []
	for item: int in range(1, Gen1Layout.ITEM_COUNT + 1):
		out.append({
			"number": item,
			"name": names[item - 1],
			"price": _bcd3(rom, Gen1Layout.item_price_offset(layout, item)),
		})
	return out


## `bcd3`, which is how both a price and a trainer's reward money are stored.
static func _bcd3(rom: RomFile, at: int) -> int:
	var out: int = 0
	for byte: int in Gen1Layout.ITEM_PRICE_SIZE:
		var packed: int = rom.u8(at + byte)
		out = out * 100 + (packed >> 4) * 10 + (packed & 0x0F)
	return out


## `TechnicalMachines`: the fifty TMs and the five HMs after them, in TM order.
func _import_tmhm_moves(rom: RomFile, layout: Dictionary) -> Array:
	var out: Array = []
	var at: int = int(layout["tmhm_moves"])
	for row: int in Gen1Layout.TM_COUNT + Gen1Layout.HM_COUNT:
		out.append(rom.u8(at + row))
	return out


func _import_trainers(rom: RomFile, layout: Dictionary) -> Array:
	var names: PackedStringArray = Gen1Text.decode_sequence(
		rom.bytes(), int(layout["trainer_names"]), Gen1Layout.TRAINER_CLASS_COUNT,
		MAX_NAME_LENGTH,
	)
	var out: Array = []
	for trainer_class: int in range(1, Gen1Layout.TRAINER_CLASS_COUNT + 1):
		var row: int = int(layout["trainer_pics"]) \
			+ (trainer_class - 1) * Gen1Layout.TRAINER_PIC_SIZE
		out.append({
			"number": trainer_class,
			"name": names[trainer_class - 1],
			# `GetTrainerInformation`: times the last enemy's level.
			"base_money": _bcd3(rom, row + Gen1Layout.POINTER_SIZE),
		})
	return out


## Every picture the cartridge draws, through [Gen1SpriteCodec]: the pics
## `BaseStats` names, `TrainerPicAndMoneyPointers`' 47, and the two back ones.
func _import_pics(
	rom: RomFile, layout: Dictionary, species: Array, on_progress: Callable
) -> Dictionary:
	var codec := Gen1SpriteCodec.new()
	var front: Dictionary = PokeTiles.new_atlas(
		Gen1Layout.FRONTPIC_MAX_TILES, Gen1Layout.SPECIES_COUNT
	)
	var back: Dictionary = PokeTiles.new_atlas(
		Gen1Layout.BACKPIC_TILES, Gen1Layout.SPECIES_COUNT
	)
	for entry: Dictionary in species:
		var slot: int = int(entry["number"]) - 1
		var offsets: Dictionary = entry["pic_offsets"]
		_decode_pic(codec, rom, int(offsets["front"]), front, slot)
		_decode_pic(codec, rom, int(offsets["back"]), back, slot)
		if on_progress.is_valid():
			on_progress.call("pics", slot + 1, Gen1Layout.SPECIES_COUNT)

	var trainers: Dictionary = PokeTiles.new_atlas(
		Gen1Layout.TRAINER_PIC_TILES, Gen1Layout.TRAINER_CLASS_COUNT
	)
	for trainer_class: int in range(1, Gen1Layout.TRAINER_CLASS_COUNT + 1):
		_decode_pic(
			codec, rom, Gen1Layout.trainer_pic_offset(rom, layout, trainer_class),
			trainers, trainer_class - 1
		)

	var player_back: Dictionary = PokeTiles.new_atlas(
		Gen1Layout.BACKPIC_TILES, Gen1Layout.PLAYER_BACKPICS.size()
	)
	for slot: int in Gen1Layout.PLAYER_BACKPICS.size():
		_decode_pic(
			codec, rom, int(layout["pic_%s_back" % Gen1Layout.PLAYER_BACKPICS[slot]]),
			player_back, slot
		)

	# A wrong offset decodes nothing, so an atlas short of a cell is a bad pin.
	var wanted: Dictionary = {
		"front": Gen1Layout.SPECIES_COUNT, "back": Gen1Layout.SPECIES_COUNT,
		"trainers": Gen1Layout.TRAINER_CLASS_COUNT,
		"player_back": Gen1Layout.PLAYER_BACKPICS.size(),
	}
	var atlases: Dictionary = {
		"front": front, "back": back, "trainers": trainers, "player_back": player_back,
	}
	var directory: String = RomCache.directory_for(rom.id, rom.sha1)
	var out: Dictionary = {}
	for name: String in atlases:
		var atlas: Dictionary = atlases[name]
		if int(atlas["decoded"]) != int(wanted[name]):
			return {}
		if not RomCache.write_indices(RomCache.pic_path(directory, name), atlas["pixels"]):
			return {}
		out[name] = PokeTiles.atlas_record(atlas)
	return out


## The two sheets as strips, the shape [GameData] reads either generation's
## through: `first_code` is the code the first tile draws.
func _import_tiles(rom: RomFile, layout: Dictionary) -> Dictionary:
	var data: PackedByteArray = rom.bytes()
	var sheets: Dictionary = {
		"font": {
			"offset": int(layout["font"]),
			"tiles": Gen1Layout.FONT_TILES,
			"first_code": Gen1Layout.FONT_FIRST_CODE,
			"bits": 1,
		},
		"font_extra": {
			"offset": int(layout["text_box"]),
			"tiles": Gen1Layout.FONT_EXTRA_TILES,
			"first_code": Gen1Layout.FONT_EXTRA_FIRST_CODE,
			"bits": 2,
		},
	}
	var directory: String = RomCache.directory_for(rom.id, rom.sha1)
	var out: Dictionary = {}
	for name: String in sheets:
		var sheet: Dictionary = sheets[name]
		var count: int = int(sheet["tiles"])
		var indices: PackedByteArray = PokeTiles.decode_strip(
			data, int(sheet["offset"]), count, int(sheet["bits"])
		)
		if not RomCache.write_indices(RomCache.tile_path(directory, name), indices):
			return {}
		out[name] = {
			"width": count * PokeTiles.TILE_WIDTH,
			"height": PokeTiles.TILE_HEIGHT,
			"tiles": count,
			"first_code": int(sheet["first_code"]),
			"bits": int(sheet["bits"]),
		}
	return out


func _decode_pic(
	codec: Gen1SpriteCodec, rom: RomFile, start: int, atlas: Dictionary, slot: int
) -> bool:
	if start < 0:
		return false
	var raw: PackedByteArray = codec.decompress(rom.bytes(), start)
	if codec.failed:
		return false
	PokeTiles.blit_pic(
		PokeTiles.decode_pic(raw, codec.columns, codec.rows), codec.columns, atlas, slot
	)
	return true
