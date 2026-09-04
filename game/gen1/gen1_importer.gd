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

## `PoundAnim` whole: one subanimation row at tileset 0 and delay 8, POUND's own
## sound and `SUBANIM_0_STAR_TWICE`, then the terminator.
const POUND_ANIM: Array[int] = [0x08, 0x00, 0x01, 0xFF]
## `BASECOORD_00`, the corner every frame block is placed from.
const FIRST_BASE_COORD: Array[int] = [0x10, 0x68]

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

## Where a bank-local pointer points: every one of them addresses $4000 up.
const BANK_BASE: int = 0x4000

## The battle animation offsets [method _import_battle_anims] reads, in the one
## order that lets each be checked against the tables it indexes.
const ANIM_TABLES: Array[String] = [
	"special_effects", "frame_blocks", "subanims", "attack_anims", "base_coords",
	"anim_tilesets", "falling_deltas",
]
## Byte position of the tile id in one `dbsprite`, after its y and x offsets.
const FRAME_BLOCK_TILE: int = 2
## `SpecialEffectPointers` is 40 rows and its terminator; both dumps agree.
const MIN_SPECIAL_EFFECTS: int = 32
const MAX_SPECIAL_EFFECTS: int = 64
## A runaway guard for one animation's `battle_anim` rows. The longest in any of
## the three dumps is eleven.
const MAX_ANIM_ROWS: int = 64

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
	_verify_battle_tiles,
	_verify_battle_anims,
	_verify_facility_text,
	_verify_world,
]

## What `LoadHudAndHpBarAndStatusTilePatterns` copies over the text box's own,
## in load order and under the names [Gen2BattleTiles] assembles a page from.
const BATTLE_TILE_SHEETS: Dictionary = {
	"battle_font": {
		"tiles": Gen1Layout.BATTLE_FONT_TILES,
		"first_code": Gen1Layout.BATTLE_FONT_FIRST_CODE,
		"bits": 2,
	},
	"battle_hud_1": {
		"tiles": Gen1Layout.BATTLE_HUD_1_TILES,
		"first_code": Gen1Layout.BATTLE_HUD_1_FIRST_CODE,
		"bits": 1,
	},
	"battle_hud_2": {
		"tiles": Gen1Layout.BATTLE_HUD_2_TILES,
		"first_code": Gen1Layout.BATTLE_HUD_2_FIRST_CODE,
		"bits": 1,
	},
}

## The `text_far` runs a facility's own boxes live in, by the [method
## GameData.special_text] run name each is stored under. The shop's are stored
## under `mart_text` instead, because the shop screen already reads that.
const FACILITY_TEXT_RUNS: Dictionary = {
	"pokecenter": ["pokecenter_text", Gen1Layout.POKECENTER_TEXT_AT],
}


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
	var slots: PackedInt32Array = Gen1Layout.index_of_dex(rom, layout)
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
	var slots: PackedInt32Array = Gen1Layout.index_of_dex(rom, layout)
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


## Those three, pinned on the two shapes nothing beside them repeats:
## `HpBarAndStatusGraphics`' empty bar and `BattleHudTiles3`'s panel edge.
static func _verify_battle_tiles(rom: RomFile, layout: Dictionary) -> Dictionary:
	for sheet: String in BATTLE_TILE_SHEETS:
		var run: Dictionary = BATTLE_TILE_SHEETS[sheet]
		var bytes: int = PokeTiles.TILE_BYTES if int(run["bits"]) == 2 \
			else PokeTiles.TILE_1BPP_BYTES
		if not rom.in_bounds(int(layout[sheet]), int(run["tiles"]) * bytes):
			return _fail("%s runs past the end of the dump." % sheet)

	if _battle_tile_rows(rom, layout, "battle_font", Gen1Layout.HP_BAR_EMPTY_CODE) \
		!= Gen1Layout.HP_BAR_EMPTY_ROWS:
		return _fail("HpBarAndStatusGraphics: $%02X is not the empty bar." % \
			Gen1Layout.HP_BAR_EMPTY_CODE)
	if _battle_tile_rows(rom, layout, "battle_hud_2", Gen1Layout.HUD_BOTTOM_CODE) \
		!= Gen1Layout.HUD_BOTTOM_ROWS:
		return _fail("BattleHudTiles3: $%02X is not the panel's edge." % \
			Gen1Layout.HUD_BOTTOM_CODE)
	return _ok()


## `PoundAnim` and `FrameBlockBaseCoords`' first row, which pin the two ends of
## the animation layer: a subanimation entry of the right shape and the flat
## table the frame blocks are placed by. The walk in [method
## _import_battle_anims] checks the rest against each other.
static func _verify_battle_anims(rom: RomFile, layout: Dictionary) -> Dictionary:
	var anims: int = Gen1Layout.banked(Gen1Layout.ANIM_BANK, int(layout["attack_anims"]))
	if not rom.in_bounds(anims, Gen1Layout.anim_count(rom.id) * Gen1Layout.POINTER_SIZE):
		return _fail("AttackAnimationPointers runs past the end of the dump.")
	var pound: int = Gen1Layout.banked(Gen1Layout.ANIM_BANK, rom.u16le(anims))
	for index: int in POUND_ANIM.size():
		if rom.u8(pound + index) != POUND_ANIM[index]:
			return _fail("AttackAnimationPointers: entry 0 is not POUND's animation.")
	var coords: int = Gen1Layout.banked(Gen1Layout.ANIM_BANK, int(layout["base_coords"]))
	if rom.u8(coords) != FIRST_BASE_COORD[0] or rom.u8(coords + 1) != FIRST_BASE_COORD[1]:
		return _fail("FrameBlockBaseCoords: row 0 is not BASECOORD_00.")
	return _ok()


## Every map and tileset decodes, which is the world layout's own check: a wrong
## table reaches a tileset number, a map size or a block index the cartridge
## cannot hold.
## Each run is one contiguous block of `text_far` stubs, so a base offset that
## has slipped shows up as a slot that does not decode at all.
static func _verify_facility_text(rom: RomFile, layout: Dictionary) -> Dictionary:
	var runs: Dictionary = {"mart": ["mart_text", Gen1Layout.MART_TEXT_AT]}
	runs.merge(FACILITY_TEXT_RUNS)
	for run: String in runs:
		var key: String = String((runs[run] as Array)[0])
		var slots: Dictionary = (runs[run] as Array)[1]
		for name: String in slots:
			var at: int = Gen1Layout.facility_text_offset(layout, key, slots, name)
			if facility_text(rom, at).is_empty():
				return _fail("%s's %s box does not decode at $%05X." % [run, name, at])
	if facility_text(rom, int(layout["mart_greeting"])).is_empty():
		return _fail("PokemartGreetingText does not decode.")
	return _ok()


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


## One tile of one battle sheet, in [method _font_rows]' shape. `FarCopyDataDouble`
## writes a 1bpp sheet into both planes, so folding them answers either way.
static func _battle_tile_rows(
	rom: RomFile, layout: Dictionary, sheet: String, code: int
) -> Array[int]:
	var run: Dictionary = BATTLE_TILE_SHEETS[sheet]
	var wide: bool = int(run["bits"]) == 2
	var stride: int = PokeTiles.TILE_BYTES if wide else PokeTiles.TILE_1BPP_BYTES
	var at: int = int(layout[sheet]) + (code - int(run["first_code"])) * stride
	var rows: Array[int] = []
	for row: int in PokeTiles.TILE_1BPP_BYTES:
		rows.append(
			rom.u8(at + 2 * row) | rom.u8(at + 2 * row + 1) if wide else rom.u8(at + row)
		)
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


## One facility box, already laid out. Empty for a stub that does not decode.
static func facility_text(rom: RomFile, at: int) -> String:
	if at < 0:
		return ""
	var decoded: Dictionary = Gen1Text.decode_stream(rom, at)
	return String(decoded["text"]) if bool(decoded.get("ok", false)) else ""


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
	var row: Dictionary = {"method": method, "species": Gen1Layout.dex_of_index(rom, layout, target)}
	if method == Gen1Layout.EVOLVE_LEVEL:
		row["level"] = rom.u8(at + 1)
	elif method == Gen1Layout.EVOLVE_ITEM:
		row["item"] = rom.u8(at + 1)
		row["level"] = rom.u8(at + 2)
	else:
		row["level"] = rom.u8(at + 1)
	return row


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
	var anims: Dictionary = _import_battle_anims(rom, layout, directory)
	if anims.is_empty():
		result["message"] = "Could not decode the battle animations."
		return result
	if not RomCache.write_section(
		RomCache.battle_anims_path(directory),
		RomCache.blob_path(RomCache.battle_anims_path(directory)),
		anims["section"]
	):
		result["message"] = "Could not write the battle animations."
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
		"battle_anim_count": int(anims["anims"]),
		"atlases": pics,
		"tiles": tiles,
		"bar_palettes": _import_bar_palettes(rom, layout),
		"mart_text": _import_mart_text(rom, layout),
		"special_text": _import_facility_text(rom, layout),
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
	result["battle_anims"] = int(anims["anims"])
	result["subanim_frames"] = int(anims["subanim_frames"])
	result["frame_block_sprites"] = int(anims["frame_block_sprites"])
	result["elapsed_ms"] = Time.get_ticks_msec() - started
	result["message"] = ("%d species, %d moves, %d items, %d type matchups, "
		+ "%d trainer classes, %d evolutions, %d level-up moves, %d maps, "
		+ "%d tilesets, %d overworld sprites, %d wild encounter tables and "
		+ "%d battle animations in %d ms.") % [
		species.size(), moves.size(), items.size(), matchups.size(), trainers.size(),
		result["evolutions"], result["learnset_moves"], result["maps"],
		result["tilesets"], result["sprites"], result["encounters"],
		result["battle_anims"], result["elapsed_ms"],
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
	var slots: PackedInt32Array = Gen1Layout.index_of_dex(rom, layout)
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
			# One Special stat: Generation 2 split it, and both halves answer
			# with it so a base stat reads the same either way.
			"stats": {
				"hp": rom.u8(stats + Gen1Layout.BASE_HP),
				"attack": rom.u8(stats + Gen1Layout.BASE_ATTACK),
				"defense": rom.u8(stats + Gen1Layout.BASE_DEFENSE),
				"speed": rom.u8(stats + Gen1Layout.BASE_SPEED),
				"special": special,
				"sp_attack": special,
				"sp_defense": special,
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


## `PAL_GREENBAR` and the two rows behind it, whole: `SetPal_Battle` hands an
## HP bar a Super Game Boy palette of its own, so a bar here is four colours.
static func _import_bar_palettes(rom: RomFile, layout: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for name: String in Gen1Layout.HP_BAR_PALETTES:
		var at: int = Gen1Layout.super_palette_offset(
			layout, int(Gen1Layout.HP_BAR_PALETTES[name])
		)
		var colors: Array = []
		for slot: int in Gen1Layout.SUPER_PALETTE_COLORS:
			colors.append(rom.u16le(at + slot * PokePalette.COLOR_BYTES))
		out[name] = colors
	return out


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
		# spent it proving the stride. The effect byte is Crystal's own number
		# by the time it lands, so one battle engine reads either cartridge.
		out.append({
			"number": move,
			"name": names[move - 1],
			"effect": Gen1Layout.move_effect(
				move, rom.u8(entry + Gen1Layout.MOVE_EFFECT)
			),
			"power": Gen1Layout.move_power(
				move, rom.u8(entry + Gen1Layout.MOVE_POWER)
			),
			"type": rom.u8(entry + Gen1Layout.MOVE_TYPE),
			"accuracy": rom.u8(entry + Gen1Layout.MOVE_ACCURACY),
			"pp": rom.u8(entry + Gen1Layout.MOVE_PP),
		})
		if on_progress.is_valid():
			on_progress.call("moves", move, Gen1Layout.MOVE_COUNT)
	return out


## The 27 rows of `TypeNames` less the $09 to $13 hole, which is filled with
## NORMAL and named by nothing.
## The shop's own boxes under the slot names [Gen2WorldServiceScreen] gives
## them. `welcome` is `DisplayPokemartDialogue`'s greeting, which sits in home
## rather than in `engine/events/pokemart.asm`'s run.
func _import_mart_text(rom: RomFile, layout: Dictionary) -> Dictionary:
	var out: Dictionary = {"welcome": facility_text(rom, int(layout["mart_greeting"]))}
	for name: String in Gen1Layout.MART_TEXT_AT:
		out[name] = facility_text(rom, Gen1Layout.facility_text_offset(
			layout, "mart_text", Gen1Layout.MART_TEXT_AT, name
		))
	return out


## The other two runs, in [method GameData.special_text]'s run/slot shape.
func _import_facility_text(rom: RomFile, layout: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for run: String in FACILITY_TEXT_RUNS:
		var key: String = String((FACILITY_TEXT_RUNS[run] as Array)[0])
		var slots: Dictionary = (FACILITY_TEXT_RUNS[run] as Array)[1]
		var boxes: Dictionary = {}
		for name: String in slots:
			boxes[name] = facility_text(
				rom, Gen1Layout.facility_text_offset(layout, key, slots, name)
			)
		out[run] = boxes
	return out


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
	## `GetMachineName` spells an HM's or a TM's name from its own number and
	## `GetMachinePrice` reads a nybble table an HM never reaches, so the two
	## runs above `ItemNames` are built rather than read. The table is dense
	## because [method GameData.item] indexes it by number less one; the ids
	## between the two runs are the ones no `item_constants.asm` row names.
	var out: Array = []
	for item: int in range(1, Gen1Layout.TM_FIRST_ITEM + Gen1Layout.TM_COUNT):
		out.append({
			"number": item,
			"name": _item_name(names, item),
			"price": _item_price(rom, layout, item),
		})
	return out


static func _item_name(names: PackedStringArray, item: int) -> String:
	if item <= Gen1Layout.ITEM_COUNT:
		return names[item - 1]
	if item < Gen1Layout.TM_FIRST_ITEM:
		return "HM%02d" % (item - Gen1Layout.HM_FIRST_ITEM + 1) \
			if item >= Gen1Layout.HM_FIRST_ITEM else ""
	return "TM%02d" % (item - Gen1Layout.TM_FIRST_ITEM + 1)


static func _item_price(rom: RomFile, layout: Dictionary, item: int) -> int:
	if item <= Gen1Layout.ITEM_COUNT:
		return _bcd3(rom, Gen1Layout.item_price_offset(layout, item))
	if item < Gen1Layout.TM_FIRST_ITEM:
		return 0
	var machine: int = item - Gen1Layout.TM_FIRST_ITEM
	@warning_ignore("integer_division")
	var packed: int = rom.u8(int(layout["tm_prices"]) + machine / 2)
	var nybble: int = (packed >> 4) if machine % 2 == 0 else (packed & 0x0F)
	return nybble * Gen1Layout.MACHINE_PRICE_UNIT


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
	for sheet: String in BATTLE_TILE_SHEETS:
		var run: Dictionary = (BATTLE_TILE_SHEETS[sheet] as Dictionary).duplicate()
		run["offset"] = int(layout[sheet])
		sheets[sheet] = run
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


## `AttackAnimationPointers` and the three tables its subanimations reach, plus
## `MoveAnimationTilesPointers`' sheets. Empty when anything fails to walk, so a
## wrong offset refuses the import rather than animating noise.
##
## The four tables and their data are interleaved through bank $1E, so the cache
## holds one region spanning all of them and each table is an address inside it.
func _import_battle_anims(rom: RomFile, layout: Dictionary, directory: String) -> Dictionary:
	var bank: PackedByteArray = rom.slice(
		Gen1Layout.ANIM_BANK * RomFile.BANK_SIZE, RomFile.BANK_SIZE
	)
	if bank.size() != RomFile.BANK_SIZE:
		return {}

	var tables: Dictionary = {}
	for name: String in ANIM_TABLES:
		tables[name] = BANK_BASE + int(layout[name]) % RomFile.BANK_SIZE

	if not _in_bank(int(tables["falling_deltas"]) + Gen1Layout.FALLING_DELTA_BYTES - 1):
		return {}
	var effects: Array = _read_special_effects(bank, int(tables["special_effects"]))
	var frame_blocks: Dictionary = _walk_frame_blocks(bank, int(tables["frame_blocks"]))
	var subanims: Dictionary = _walk_subanims(bank, int(tables["subanims"]), frame_blocks)
	var anims: Dictionary = _walk_anims(
		bank, int(tables["attack_anims"]), Gen1Layout.anim_count(rom.id), effects
	)
	var sheets: Array = _import_anim_tilesets(rom, int(tables["anim_tilesets"]), directory)
	if effects.is_empty() or frame_blocks.is_empty() or subanims.is_empty() \
			or anims.is_empty() or sheets.is_empty():
		return {}

	var spans: Array = [anims, subanims, frame_blocks]
	var lowest: int = int(tables["attack_anims"])
	var highest: int = int(tables["base_coords"]) \
		+ Gen1Layout.BASE_COORD_COUNT * Gen1Layout.BASE_COORD_SIZE
	for span: Dictionary in spans:
		lowest = mini(lowest, int(span["lowest"]))
		highest = maxi(highest, int(span["highest"]))

	return {
		"section": {
			"anims": {
				"bank": Gen1Layout.ANIM_BANK,
				"address": lowest,
				"count": Gen1Layout.anim_count(rom.id),
				"bytes": _bank_bytes(bank, lowest, highest),
			},
			"tables": {
				"subanims": tables["subanims"],
				"frame_blocks": tables["frame_blocks"],
				"base_coords": tables["base_coords"],
			},
			"special_effects": effects,
			"falling_deltas": _bank_bytes(
				bank, int(tables["falling_deltas"]),
				int(tables["falling_deltas"]) + Gen1Layout.FALLING_DELTA_BYTES
			),
			"object_gfx": sheets,
		},
		"anims": Gen1Layout.anim_count(rom.id),
		"subanim_frames": int(subanims["frames"]),
		"frame_block_sprites": int(frame_blocks["sprites"]),
	}


## `SpecialEffectPointers`, as the ids alone: the addresses beside them are
## routines this port answers with its own. Empty when the table never ends.
func _read_special_effects(bank: PackedByteArray, table: int) -> Array:
	var out: Array = []
	var at: int = table
	while out.size() <= MAX_SPECIAL_EFFECTS:
		var id: int = _bank_u8(bank, at)
		if id == Gen1Layout.ANIM_END:
			return out if out.size() >= MIN_SPECIAL_EFFECTS else []
		if id < Gen1Layout.ANIM_FIRST_SE_ID or out.has(id):
			return []
		out.append(id)
		at += Gen1Layout.SPECIAL_EFFECT_ROW_SIZE
	return []


## `FrameBlockPointers` and every `dbsprite` run behind it. Answers
## [code]{ lowest, highest, sprites, tiles }[/code], `tiles` being the highest
## tile id any of them draws, which pins the tileset the sheets have to hold.
func _walk_frame_blocks(bank: PackedByteArray, table: int) -> Dictionary:
	var lowest: int = table
	var highest: int = table + Gen1Layout.FRAME_BLOCK_COUNT * Gen1Layout.POINTER_SIZE
	var sprites: int = 0
	var tiles: int = 0
	for index: int in Gen1Layout.FRAME_BLOCK_COUNT:
		var address: int = _bank_u16(bank, table + index * Gen1Layout.POINTER_SIZE)
		if not _in_bank(address):
			return {}
		var count: int = _bank_u8(bank, address)
		var end: int = address + 1 + count * Gen1Layout.FRAME_BLOCK_SPRITE_SIZE
		if not _in_bank(end - 1):
			return {}
		for sprite: int in count:
			var at: int = address + 1 + sprite * Gen1Layout.FRAME_BLOCK_SPRITE_SIZE
			tiles = maxi(tiles, _bank_u8(bank, at + FRAME_BLOCK_TILE))
		sprites += count
		lowest = mini(lowest, address)
		highest = maxi(highest, end)
	return {"lowest": lowest, "highest": highest, "sprites": sprites, "tiles": tiles + 1}


## `SubanimationPointers` and the three-byte rows behind each header. Every row
## is checked against the two tables it indexes, which is what makes a plausible
## but wrong offset fail here rather than on screen.
func _walk_subanims(
	bank: PackedByteArray, table: int, frame_blocks: Dictionary
) -> Dictionary:
	if frame_blocks.is_empty():
		return {}
	var lowest: int = table
	var highest: int = table + Gen1Layout.SUBANIM_COUNT * Gen1Layout.POINTER_SIZE
	var frames: int = 0
	for index: int in Gen1Layout.SUBANIM_COUNT:
		var address: int = _bank_u16(bank, table + index * Gen1Layout.POINTER_SIZE)
		if not _in_bank(address):
			return {}
		var header: int = _bank_u8(bank, address)
		var count: int = header & Gen1Layout.SUBANIM_COUNT_MASK
		var kind: int = header >> Gen1Layout.SUBANIM_TYPE_SHIFT
		var end: int = address + 1 + count * Gen1Layout.SUBANIM_ROW_SIZE
		if count == 0 or kind >= Gen1Layout.SUBANIMTYPE_COUNT or not _in_bank(end - 1):
			return {}
		for row: int in count:
			var at: int = address + 1 + row * Gen1Layout.SUBANIM_ROW_SIZE
			if _bank_u8(bank, at) >= Gen1Layout.FRAME_BLOCK_COUNT \
					or _bank_u8(bank, at + 1) >= Gen1Layout.BASE_COORD_COUNT \
					or _bank_u8(bank, at + 2) >= Gen1Layout.FRAMEBLOCKMODE_COUNT:
				return {}
		frames += count
		lowest = mini(lowest, address)
		highest = maxi(highest, end)
	return {"lowest": lowest, "highest": highest, "frames": frames}


## `AttackAnimationPointers` and every `battle_anim` row behind it, with each
## row's subanimation id and special effect id checked against its table.
func _walk_anims(
	bank: PackedByteArray, table: int, count: int, effects: Array
) -> Dictionary:
	var lowest: int = table
	var highest: int = table + count * Gen1Layout.POINTER_SIZE
	for index: int in count:
		var address: int = _bank_u16(bank, table + index * Gen1Layout.POINTER_SIZE)
		if not _in_bank(address):
			return {}
		var at: int = address
		var rows: int = 0
		while true:
			rows += 1
			if rows > MAX_ANIM_ROWS or not _in_bank(at):
				return {}
			var byte: int = _bank_u8(bank, at)
			if byte == Gen1Layout.ANIM_END:
				at += 1
				break
			if byte >= Gen1Layout.ANIM_FIRST_SE_ID:
				if not effects.has(byte):
					return {}
				at += Gen1Layout.ANIM_SE_SIZE
				continue
			if _bank_u8(bank, at + 2) >= Gen1Layout.SUBANIM_COUNT:
				return {}
			at += Gen1Layout.ANIM_SUBANIM_SIZE
		lowest = mini(lowest, address)
		highest = maxi(highest, at)
	return {"lowest": lowest, "highest": highest}


## `MoveAnimationTilesPointers`' three rows, decoded as raw 2bpp strips into the
## same files a Generation 2 `AnimObjGFX` sheet uses. Rows 0 and 2 name the same
## bytes, the third being the first cut to 64 tiles, so both are written.
func _import_anim_tilesets(rom: RomFile, table: int, directory: String) -> Array:
	var out: Array = []
	for index: int in Gen1Layout.ANIM_TILESET_COUNT:
		var row: int = Gen1Layout.banked(Gen1Layout.ANIM_BANK, table) \
			+ index * Gen1Layout.ANIM_TILESET_ROW_SIZE
		var tiles: int = rom.u8(row + Gen1Layout.ANIM_TILESET_TILES)
		var address: int = rom.u16le(row + Gen1Layout.ANIM_TILESET_POINTER)
		var start: int = Gen1Layout.banked(Gen1Layout.ANIM_BANK, address)
		if tiles <= 0 or not _in_bank(address) \
				or not rom.in_bounds(start, tiles * PokeTiles.TILE_BYTES):
			return []
		if not RomCache.write_indices(
			RomCache.battle_anim_gfx_path(directory, index),
			PokeTiles.decode_strip(rom.bytes(), start, tiles, 2)
		):
			return []
		out.append({
			"tiles": tiles,
			"bank": Gen1Layout.ANIM_BANK,
			"address": address,
			"sheet": true,
		})
	return out


## The slice of bank $1E between two of its own addresses, as an Array the cache
## moves into the section blob.
func _bank_bytes(bank: PackedByteArray, from: int, to: int) -> Array:
	var slice: PackedByteArray = bank.slice(from - BANK_BASE, to - BANK_BASE)
	var out: Array = []
	out.resize(slice.size())
	for index: int in slice.size():
		out[index] = slice[index]
	return out


func _bank_u8(bank: PackedByteArray, address: int) -> int:
	var at: int = address - BANK_BASE
	return bank[at] if at >= 0 and at < bank.size() else 0


func _bank_u16(bank: PackedByteArray, address: int) -> int:
	return _bank_u8(bank, address) | (_bank_u8(bank, address + 1) << 8)


static func _in_bank(address: int) -> bool:
	return address >= BANK_BASE and address < BANK_BASE + RomFile.BANK_SIZE
