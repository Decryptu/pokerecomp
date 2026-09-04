class_name Gen1Layout
extends RefCounted

## Where the data lives inside each Generation 1 cartridge, the counterpart of
## [Gen2Layout]. Offsets are absolute positions in the 1 MiB dump, so a decoder
## never thinks about banking. Red and Blue share every table here: the 668
## symbols that move between them are all bank $1D's map scripts.
## Every offset was read off pret's own build of the pinned sources, which
## reproduces each dump byte for byte (`roms.sha1` holds the three SHA-1s
## [RomRegistry] does). A table is still a claim about a specific dump, so an
## uncharacterised ROM is refused rather than guessed at.

## `NUM_POKEMON` and `NUM_POKEMON_INDEXES`: 151 dex entries over 190 cartridge
## slots, most of the difference being MISSINGNO. `MonsterNames`,
## `PokedexEntryPointers`, `EvosMovesPointerTable` and `CryData` are indexed by
## the slot; `BaseStats` and `MonsterPalettes` by dex number.
const SPECIES_COUNT: int = 151
const INDEX_COUNT: int = 190
const NAME_LENGTH: int = 10

## `BASE_DATA_SIZE` and the `BASE_*` members of `pokemon_data_constants.asm`.
const BASE_STATS_SIZE: int = 28
const BASE_DEX_NO: int = 0
const BASE_HP: int = 1
const BASE_ATTACK: int = 2
const BASE_DEFENSE: int = 3
const BASE_SPEED: int = 4
## One stat for both halves of the split Generation 2 introduced.
const BASE_SPECIAL: int = 5
const BASE_TYPE_1: int = 6
const BASE_TYPE_2: int = 7
const BASE_CATCH_RATE: int = 8
const BASE_EXP: int = 9
## One byte, width in the high nybble and height in the low one, in tiles.
const BASE_PIC_SIZE: int = 10
const BASE_FRONT_PIC: int = 11
const BASE_BACK_PIC: int = 13
const BASE_MOVES: int = 15
const BASE_MOVE_COUNT: int = 4
const BASE_GROWTH_RATE: int = 19
const BASE_TMHM: int = 20
const BASE_TMHM_BYTES: int = 7

## `NUM_ATTACKS` and the `move` macro's six bytes.
const MOVE_COUNT: int = 165
const MOVE_DATA_SIZE: int = 6
const MOVE_ANIMATION: int = 0
const MOVE_EFFECT: int = 1
const MOVE_POWER: int = 2
const MOVE_TYPE: int = 3
const MOVE_ACCURACY: int = 4
const MOVE_PP: int = 5

## `NUM_TYPES`. $09 to $13 are a hole `TypeNames` fills with NORMAL and nothing
## uses, kept out of the cache by [method is_real_type]. The physical run is $00
## to $08 and the special run starts at $14, deciding Attack or Special.
const TYPE_COUNT: int = 27
const TYPE_UNUSED_FIRST: int = 0x09
const TYPE_UNUSED_LAST: int = 0x13
const TYPE_SPECIAL_FIRST: int = 0x14

## `TypeEffects`: attacker, defender, multiplier, ending in $FF. The multiplier
## is in tenths, the same encoding Generation 2 kept, so the cached chart needs
## no conversion between the two.
const TYPE_EFFECT_SIZE: int = 3
const TYPE_EFFECT_END: int = 0xFF
const TYPE_EFFECT_NEUTRAL: int = 10

## `NUM_ITEMS`, and the three packed-decimal bytes of `bcd3`.
const ITEM_COUNT: int = 83
const ITEM_PRICE_SIZE: int = 3

## `NUM_TMS` and `NUM_HMS`: `TechnicalMachines` is one move number per row and
## the HMs follow the TMs. As items they sit above the named ones, `HM01` at $C4.
const TM_COUNT: int = 50
const HM_COUNT: int = 5
const HM_FIRST_ITEM: int = 0xC4
const TM_FIRST_ITEM: int = HM_FIRST_ITEM + HM_COUNT

## A `PokedexEntry`: category, feet, inches, weight in tenths of a pound, then
## `text_far`'s $17 with a `dab` pointer to the description.
const DEX_TEXT_FAR: int = 0x17
const DEX_CATEGORY_MAX: int = 16

## Every near-pointer table in these cartridges is two bytes a row.
const POINTER_SIZE: int = 2

## `MonsterPalettes` names an SGB palette a row, `SuperPalettes` holds the four
## colours of each, and a DMG reads neither and shows four greys.
const SUPER_PALETTE_COLORS: int = 4
const SUPER_PALETTE_BYTES: int = SUPER_PALETTE_COLORS * PokePalette.COLOR_BYTES
## `NUM_SGB_PALS`: Yellow put Pikachu's Beach's three behind `PAL_GAMEFREAK` and
## recoloured every row above them.
const SUPER_PALETTE_COUNT_RED_BLUE: int = 37
const SUPER_PALETTE_COUNT_YELLOW: int = 40
const PAL_ROUTE: int = 0x00
const PAL_PALLET: int = 0x01
const PAL_GRAYMON: int = 0x19
const PAL_CAVE: int = 0x23

## `GBPalNormal`'s `rOBP0`, %11010000: an object's colours 1, 2 and 3 take
## shades 0, 1 and 3, so a sprite never shows the palette's third colour.
const OBJECT_SHADES: Array[int] = [0, 0, 1, 3]

## Evolutions by method until a zero byte, then (level, move) pairs until
## another; `EVOLVE_ITEM` is the only four-byte row.
const EVOLVE_LEVEL: int = 1
const EVOLVE_ITEM: int = 2
const EVOLVE_TRADE: int = 3
const EVOLVE_SIZES: Dictionary = {
	EVOLVE_LEVEL: 3,
	EVOLVE_ITEM: 4,
	EVOLVE_TRADE: 3,
}

## `CryData`: base cry, pitch and length.
const CRY_SIZE: int = 3

## `UncompressMonSprite`'s if-chain, as the first internal index of each bank:
## `TANGELA + 1`, `MOLTRES + 1`, `BEEDRILL + 2`, `STARMIE + 1`. The Kabutops
## fossil stands outside the run everywhere; Mew does too in Red and Blue, where
## it sits in bank 1 beside its own `BaseStats` row.
const PIC_BANK_THRESHOLDS: Array[int] = [0x1F, 0x4A, 0x74, 0x99]
const PIC_BANKS: Array[int] = [0x09, 0x0A, 0x0B, 0x0C, 0x0D]
const PIC_INDEX_MEW: int = 0x15
const PIC_INDEX_FOSSIL_KABUTOPS: int = 0xB6
const PIC_BANK_FOSSIL_KABUTOPS: int = 0x0B

## `FontGraphics` and `TextBoxGraphics`, which `LoadFontTilePatterns` and
## `LoadTextBoxTilePatterns` copy to `vFont` and `vChars2 tile $60`. Both are
## indexed by character code: a byte is already the tile that draws it. The text
## box's six border tiles at $79 are inside the second, where Generation 2 keeps
## a table of eight frames of its own.
const FONT_TILES: int = 128
const FONT_FIRST_CODE: int = 0x80
const FONT_EXTRA_TILES: int = 32
const FONT_EXTRA_FIRST_CODE: int = 0x60

## What checks the two offsets: every code [Gen1Text] draws has ink, the hole
## between "'v" and "'" has none, the space is the text box's only blank tile,
## and the border's column is eight rows of one pattern.
const FONT_INK_RUNS: Array = [[0x80, 0xBF], [0xE0, 0xFF]]
const FONT_BLANK_RUNS: Array = [[0xC0, 0xDF]]
const SPACE_CODE: int = 0x7F
## `TextBoxBorder` prints `┌─┐│└┘`, the six codes `charmap.asm` puts at $79.
## Generation 2 spells them the same way in a table of eight frames.
const FRAME_FIRST_CODE: int = 0x79
const FRAME_LAST_CODE: int = 0x7E
const FRAME_VERTICAL_CODE: int = FRAME_FIRST_CODE + Gen2Layout.FRAME_VERTICAL
const FRAME_VERTICAL_ROW: int = 0b00101000

## `TX_SCRIPT_*`: a text pointer standing at one of these opens a facility
## rather than a box, `DisplayTextID` dispatching before it prints.
const TEXT_SCRIPT_IDS: Dictionary = {
	0xF5: "vending machine", 0xF6: "cable club receptionist", 0xF7: "prize vendor",
	0xF9: "Pokemon Center PC", 0xFC: "the player's PC", 0xFD: "Bill's PC",
	0xFE: "mart", 0xFF: "Pokemon Center nurse",
}

## `MapHeaderPointers` is flat: one `dw` a map id, with `MapHeaderBanks` beside
## it. `SwitchToMapRomBank` selects that bank once, which is what puts a map's
## blocks, objects, text and script in the bank its header sits in.
const MAP_COUNT_RED_BLUE: int = 248
const MAP_COUNT_YELLOW: int = 249

## `map_header`: tileset, height, width, the blocks, text and script pointers,
## then the connection byte; `end_map_header` puts the object pointer behind
## whatever connection records were emitted.
const MAP_HEADER_SIZE: int = 10
const MAP_CONNECTION_RECORD_SIZE: int = 11
const MAP_OBJECT_POINTER_SIZE: int = 2
const MAP_CONNECTION_FLAG_EAST: int = 1
const MAP_CONNECTION_FLAG_WEST: int = 2
const MAP_CONNECTION_FLAG_SOUTH: int = 4
const MAP_CONNECTION_FLAG_NORTH: int = 8

## `map_constants.asm`'s largest map.
const MAP_MAX_WIDTH_BLOCKS: int = 50
const MAP_MAX_HEIGHT_BLOCKS: int = 72

## The 22 ids `map_header_pointers.asm` marks UNUSED, the same 22 in all three.
## Their `dw` repeats a real header while their bank byte is a $01, $11 or $1D
## placeholder naming a different one, so the pair decodes to noise.
const UNUSED_MAPS: Array[int] = [
	0x0B, 0x69, 0x6A, 0x6B, 0x6D, 0x6E, 0x6F, 0x70, 0x72, 0x73, 0x74, 0x75,
	0xCC, 0xCD, 0xCE, 0xE7, 0xED, 0xEE, 0xF1, 0xF2, 0xF3, 0xF4,
]

## `MapSongBanks`: the map's music id and the bank that music lives in.
const MAP_SONG_SIZE: int = 2

## `<Map>_Object`: a border block, a counted list each of warps, signs and
## objects, then one `warp_to` a warp that names only WRAM.
const WARP_EVENT_SIZE: int = 4
const SIGN_EVENT_SIZE: int = 3
const OBJECT_EVENT_SIZE: int = 6
const WARP_TO_SIZE: int = 4
## `object_event` writes coordinates four higher, as Generation 2 does.
const OBJECT_COORD_BIAS: int = 4
## `TRAINER | text` and `ITEM | text`, each carrying extra bytes behind the row;
## `LoadMapHeader`'s `.loadSpriteLoop` masks the byte with $3F for the text id.
const OBJECT_TRAINER_FLAG: int = 0x40
const OBJECT_ITEM_FLAG: int = 0x80
const OBJECT_TEXT_MASK: int = 0x3F
const OBJECT_TRAINER_BYTES: int = 2
const OBJECT_ITEM_BYTES: int = 1
## `InitBattleEnemyParameters`' `cp OPP_ID_OFFSET`: the extra byte is this plus
## a trainer class, or below it a species, and the next its number or level.
const OPPONENT_ID_OFFSET: int = 200
## `MAX_WARP_EVENTS`, `MAX_BG_EVENTS` and `MAX_OBJECT_EVENTS`.
const MAX_WARP_EVENTS: int = 32
const MAX_SIGN_EVENTS: int = 16
const MAX_OBJECT_EVENTS: int = 16
## `warp_event`'s indoor exit: `wLastMap`, the outdoor map the player came from.
const WARP_TO_LAST_MAP: int = 0xFF
## `ExtraWarpCheck`'s four named maps, which take the warp-carpet test their own
## tileset would not give them, and the two the routine answers by hand:
## SS Anne 3F asks for the map edge instead, and the Bow has one carpet tile.
const WARP_CARPET_MAPS: Array[int] = [0x52, 0xC7, 0xC8, 0xCA]
const MAP_SS_ANNE_3F: int = 0x61
const MAP_SS_ANNE_BOW: int = 0x63
const SS_ANNE_BOW_WARP_TILE: int = 0x15

## The map ids `SetPal_Overworld` splits on; only the link rooms are Yellow's.
const NUM_CITY_MAPS: int = 0x0B
const FIRST_INDOOR_MAP: int = 0x25
const CERULEAN_CAVE_2F: int = 0xE2
const CERULEAN_CAVE_1F: int = 0xE4
const TRADE_CENTER: int = 0xEF
const COLOSSEUM: int = 0xF0
const LORELEIS_ROOM: int = 0xF5
const BRUNOS_ROOM: int = 0xF6

## The `tileset` macro: the bank holding both graphics and blocks, the three
## pointers, three counter tiles, the grass tile and the animation kind, with
## $FF for "none" in all four tile columns.
const TILESET_RECORD_SIZE: int = 12
const TILESET_COUNT_RED_BLUE: int = 24
const TILESET_COUNT_YELLOW: int = 25
const TILESET_COUNTER_TILES: int = 3
const TILESET_NO_TILE: int = 0xFF
## `MAP_TILESET_SIZE`: `LoadTilesetTilePatternData` copies this many tiles to
## `vTileset` whatever the tileset holds, so a short one's tail is whatever
## follows it in the bank.
const TILESET_TILE_COUNT: int = 96
const TILESET_BLOCK_TILES: int = MAP_BLOCK_TILE_WIDTH * MAP_BLOCK_TILE_WIDTH

## Blocks per tileset, in table order. Nothing in the cartridge records it:
## `<Tileset>_Block` is an INCBIN whose length only the assembler knew. Read off
## the pinned checkouts' `.bst` files, and bracketed at import by the blocks the
## maps use and by where the next tileset's graphics start.
const TILESET_BLOCKS_RED_BLUE: Array[int] = [
	128, 19, 37, 128, 19, 116, 37, 116, 35, 128, 128, 17,
	128, 62, 23, 110, 58, 128, 79, 72, 58, 36, 128, 73,
]
## Yellow gave the Mart and Pokemon Center three more and added the Beach House.
const TILESET_BLOCKS_YELLOW: Array[int] = [
	128, 19, 40, 128, 19, 116, 40, 116, 35, 128, 128, 17,
	128, 62, 23, 110, 58, 128, 79, 72, 58, 36, 128, 73, 20,
]

## `WaterTilesets`, a $FF-terminated list, and the tile
## `IsNextTileShoreOrWater` calls water on one of them.
const TILESET_LIST_END: int = 0xFF
const WATER_TILE: int = 0x14

## The two tilesets `SetPal_Overworld` tests before the map id, the two
## `CheckIfInOutsideMap` calls a town or a route, and the two beside them that
## `ExtraWarpCheck` reads a carpet on.
const TILESET_CEMETERY: int = 15
const TILESET_CAVERN: int = 17
const TILESET_OVERWORLD: int = 0
const TILESET_PLATEAU: int = 23
const TILESET_FOREST: int = 3
const TILESET_SHIP: int = 13
const TILESET_SHIP_PORT: int = 14

## `WildDataPointers`, one `dw` a map id and $FFFF behind the last. A block is
## its rate byte alone when the rate is zero and `WILDDATA_LENGTH` otherwise,
## ten (level, species) pairs behind it; grass first, water in the same shape.
const WILD_SLOT_COUNT: int = 10
const WILD_DATA_LENGTH: int = 1 + WILD_SLOT_COUNT * 2
const WILD_POINTERS_END: int = 0xFFFF

## `WildMonEncounterSlotChances`, as the cumulative byte each slot wins on; its
## second column is the slot doubled, and the ten sum to 256.
const WILD_CHANCE_SIZE: int = 2
const WILD_SLOT_CHANCES: Array[int] = [50, 101, 140, 165, 190, 215, 228, 241, 252, 255]

## `GoodRodMons`. The Old Rod has no table: `ItemUseOldRod` carries its one pair
## as `lb bc, 5, MAGIKARP`, and neither rod reads the map.
const GOOD_ROD_SLOTS: Array = [[10, 0x9D], [10, 0x47]]

## `SuperRodData`, a map id and a pointer to `count` (level, species) rows that
## `ReadSuperRodData` picks between by rejecting a two-bit roll. Yellow's
## `SuperRodFishingSlots` is one row a map, four (species, level) pairs picked by
## a byte threshold. Both end on $FF where a map id would be.
const SUPER_ROD_ROW_SIZE: int = 3
const SUPER_ROD_ROW_SIZE_YELLOW: int = 9
const SUPER_ROD_SLOTS_YELLOW: int = 4
const SUPER_ROD_THRESHOLDS_YELLOW: Array[int] = [0x65, 0xB1, 0xE4, 0xFF]
const SUPER_ROD_MAX_SLOTS: int = 4
const ROD_LIST_END: int = 0xFF

## A walk cell's collision tile is the bottom-left of its 2x2 quarter of the
## block, the corner Generation 2 also picks. `_GetTileAndCoordsInFrontOfPlayer`
## reads (8, 11), (8, 7), (6, 9) and (10, 9) and the player's cell starts at
## screen (8, 8); reading them as top-left leaves 53 of Red's 226 maps with no
## cell a player can stand on, the Pokemon Centers among them.
const MAP_BLOCK_TILE_WIDTH: int = 4
const MAP_BLOCK_CELL_WIDTH: int = 2

## `SpriteSheetPointerTable`: a CPU address, the bytes of one half and the bank,
## with a picture id one past the row. `LoadMapSpriteTilePatterns` reads a row
## below `FIRST_STILL_SPRITE` twice, the second time $C0 further on, which is the
## `$80` the walking rows of `SpriteFacingAndAnimationTable` add.
const SPRITE_RECORD_SIZE: int = 4
const SPRITE_COUNT_RED_BLUE: int = 72
const SPRITE_COUNT_YELLOW: int = 82
const SPRITE_STILL_FIRST_RED_BLUE: int = 0x3D
const SPRITE_STILL_FIRST_YELLOW: int = 0x47
const SPRITE_WALKING_TILES: int = 12
const SPRITE_STILL_TILES: int = 4

## `NUM_TRAINERS`, the trainer classes rather than the individual trainers.
const TRAINER_CLASS_COUNT: int = 47

## `TrainerPicAndMoneyPointers`: a near pointer and the class's base reward
## money as three packed-decimal bytes. Every trainer picture is in the one bank
## the layout records, and `ChiefPic` and `ScientistPic` are the same address.
const TRAINER_PIC_SIZE: int = 5

## Sides in tiles: `_LoadTrainerPic`'s `ld a, $77`, the widest front pic, and
## every back pic, which `ScaleSpriteByTwo` doubles before a battle draws it.
const TRAINER_PIC_TILES: int = 7
const FRONTPIC_MAX_TILES: int = 7
const BACKPIC_TILES: int = 4

## `GetTrainerBackpic`'s counterpart, in the `player_back` atlas's slot order:
## the player, and the old man who borrows the screen for the catching tutorial.
const PLAYER_BACKPICS: Array[String] = ["player", "old_man"]

const RED_BLUE: Dictionary = {
	"species_names": 0x1C21E,
	"base_stats": 0x383DE,
	## Mew's row and its pic bank stand outside Red and Blue's tables. Yellow
	## put both back in the run, where these are zero.
	"mew_base_stats": 0x0425B,
	"pic_mew_bank": 0x01,
	"dex_order": 0x41024,
	"dex_entries": 0x4047E,
	"dex_entries_bank": 0x10,
	"moves": 0x38000,
	"move_names": 0xB0000,
	"type_names": 0x27DAE,
	"type_names_bank": 0x09,
	"type_effects": 0x3E474,
	"item_names": 0x0472B,
	"item_prices": 0x04608,
	"tmhm_moves": 0x13773,
	"mon_palettes": 0x725C8,
	"super_palettes": 0x72660,
	"trainer_names": 0x399FF,
	"evos_moves": 0x3B05C,
	"evos_moves_bank": 0x0E,
	"cries": 0x39446,
	"trainer_pics": 0x39914,
	"trainer_pics_bank": 0x13,
	"font": 0x11A80,
	"text_box": 0x12288,
	"pic_player_back": 0x33E0A,
	"pic_old_man_back": 0x33E9A,
	"map_headers": 0x001AE,
	"map_header_banks": 0x0C23D,
	"map_songs": 0x0C04D,
	"tilesets": 0x0C7BE,
	"water_tilesets": 0x0E8E0,
	"overworld_sprites": 0x17B27,
	"wild_data": 0x0CEEB,
	"wild_chances": 0x13918,
	"good_rod": 0x0E27F,
	"super_rod": 0x0E919,
	## `_IsTilePassable` and the lists it walks share a bank, and the pointer in
	## a tileset row names no bank of its own. Red and Blue keep both in home.
	"tileset_collision_bank": 0x00,
}

const YELLOW: Dictionary = {
	"species_names": 0xE8000,
	"base_stats": 0x383DE,
	"mew_base_stats": 0,
	"pic_mew_bank": 0,
	"dex_order": 0x410B1,
	"dex_entries": 0x4050B,
	"dex_entries_bank": 0x10,
	"moves": 0x38000,
	"move_names": 0xBC000,
	"type_names": 0x27D63,
	"type_names_bank": 0x09,
	"type_effects": 0x3E5FA,
	"item_names": 0x045B7,
	"item_prices": 0x04494,
	"tmhm_moves": 0x1232D,
	"mon_palettes": 0x72921,
	"super_palettes": 0x729B9,
	"trainer_names": 0x3997E,
	"evos_moves": 0x3B1E5,
	"evos_moves_bank": 0x0E,
	"cries": 0x39462,
	"trainer_pics": 0x39893,
	"trainer_pics_bank": 0x13,
	"font": 0x10600,
	"text_box": 0x10E18,
	## Yellow moved both back pics out of "Pics 4" and into their own bank.
	"pic_player_back": 0xF43B1,
	"pic_old_man_back": 0xF4441,
	"map_headers": 0xFC1F2,
	"map_header_banks": 0xFC3E4,
	"map_songs": 0xFC000,
	"tilesets": 0x0C558,
	"water_tilesets": 0x0E834,
	"overworld_sprites": 0x142A9,
	"wild_data": 0x0CB95,
	"wild_chances": 0x138E2,
	"good_rod": 0x0E12C,
	## Yellow's is a flat slot table rather than an index into groups.
	"super_rod": 0xF5EDA,
	"tileset_collision_bank": 0x01,
}


static func for_id(id: StringName) -> Dictionary:
	match id:
		RomRegistry.RED, RomRegistry.BLUE:
			return RED_BLUE
		RomRegistry.YELLOW:
			return YELLOW
	return {}


static func is_characterised(id: StringName) -> bool:
	return not for_id(id).is_empty()


## A type number the cartridge really uses.
static func is_real_type(type: int) -> bool:
	return type < TYPE_UNUSED_FIRST or type > TYPE_UNUSED_LAST


## Whether a move of this type takes Special rather than Attack: Generation 1
## splits on the type, which is what `SPECIAL EQU const_value` marks.
static func is_special_type(type: int) -> bool:
	return type >= TYPE_SPECIAL_FIRST


## Takes an internal index from 1 to [constant INDEX_COUNT].
static func species_name_offset(layout: Dictionary, index: int) -> int:
	return int(layout["species_names"]) + (index - 1) * NAME_LENGTH


## `GetMonHeader`: the row is the dex number less one, with Mew's own exception.
static func base_stats_offset(layout: Dictionary, dex: int) -> int:
	var mew: int = int(layout["mew_base_stats"])
	if dex == SPECIES_COUNT and mew != 0:
		return mew
	return int(layout["base_stats"]) + (dex - 1) * BASE_STATS_SIZE


static func move_offset(layout: Dictionary, move: int) -> int:
	return int(layout["moves"]) + (move - 1) * MOVE_DATA_SIZE


static func item_price_offset(layout: Dictionary, item: int) -> int:
	return int(layout["item_prices"]) + (item - 1) * ITEM_PRICE_SIZE


static func cry_offset(layout: Dictionary, index: int) -> int:
	return int(layout["cries"]) + (index - 1) * CRY_SIZE


## The pic behind one row of `TrainerPicAndMoneyPointers`.
static func trainer_pic_offset(rom: RomFile, layout: Dictionary, trainer_class: int) -> int:
	var row: int = int(layout["trainer_pics"]) + (trainer_class - 1) * TRAINER_PIC_SIZE
	return RomFile.linear(int(layout["trainer_pics_bank"]), rom.u16le(row))


## The tile one character code draws from: `FontGraphics` is 1bpp from $80,
## `TextBoxGraphics` 2bpp from $60.
static func font_glyph_offset(layout: Dictionary, code: int) -> int:
	return int(layout["font"]) + (code - FONT_FIRST_CODE) * PokeTiles.TILE_1BPP_BYTES


static func text_box_glyph_offset(layout: Dictionary, code: int) -> int:
	return int(layout["text_box"]) + (code - FONT_EXTRA_FIRST_CODE) * PokeTiles.TILE_BYTES


## `NUM_POKEMON + 1` rows in dex order with MISSINGNO's first, so the dex number
## is the row.
static func mon_palette_offset(layout: Dictionary, dex: int) -> int:
	return int(layout["mon_palettes"]) + dex


static func super_palette_offset(layout: Dictionary, palette: int) -> int:
	return int(layout["super_palettes"]) + palette * SUPER_PALETTE_BYTES


## `SetPal_Overworld`: the `SuperPalettes` row a map's four colours come from.
## The two tilesets answer before the map id is read at all. A city's row is its
## map id plus one and every route shares [constant PAL_ROUTE]; an indoor map no
## branch names takes `wLastMap`'s, which is [param last_map].
static func overworld_palette(
	id: StringName, map_id: int, tileset: int, last_map: int = -1
) -> int:
	if tileset == TILESET_CEMETERY:
		return PAL_GRAYMON
	if tileset == TILESET_CAVERN:
		return PAL_CAVE
	if map_id < FIRST_INDOOR_MAP:
		return _town_palette(map_id)
	if map_id >= CERULEAN_CAVE_2F and map_id <= CERULEAN_CAVE_1F:
		return PAL_CAVE
	if map_id == BRUNOS_ROOM:
		return PAL_CAVE
	if map_id == LORELEIS_ROOM:
		return PAL_PALLET
	if id == RomRegistry.YELLOW and (map_id == TRADE_CENTER or map_id == COLOSSEUM):
		return PAL_GRAYMON
	return _town_palette(last_map)


## `.townOrRoute` and the `inc a` behind it: every id past the last city answers
## [constant PAL_ROUTE], the routine's own `ld a, PAL_ROUTE - 1`.
static func _town_palette(map_id: int) -> int:
	return map_id + 1 if map_id >= 0 and map_id < NUM_CITY_MAPS else PAL_ROUTE


## Resolves one row of a near-pointer table whose bank the layout records.
static func pointer_target(rom: RomFile, layout: Dictionary, key: String, row: int) -> int:
	var table: int = int(layout[key])
	var bank: int = int(layout["%s_bank" % key])
	return RomFile.linear(bank, rom.u16le(table + row * POINTER_SIZE))


## `UncompressMonSprite`'s bank for an internal index, so a pic pointer read out
## of `BaseStats` can be turned into an offset.
static func pic_bank(layout: Dictionary, index: int) -> int:
	var mew: int = int(layout["pic_mew_bank"])
	if index == PIC_INDEX_MEW and mew != 0:
		return mew
	if index == PIC_INDEX_FOSSIL_KABUTOPS:
		return PIC_BANK_FOSSIL_KABUTOPS
	for step: int in PIC_BANK_THRESHOLDS.size():
		if index < PIC_BANK_THRESHOLDS[step]:
			return PIC_BANKS[step]
	return PIC_BANKS[PIC_BANKS.size() - 1]


## How many map ids the flat table holds. Yellow added the Summer Beach House
## behind Agatha's room.
static func map_count(id: StringName) -> int:
	return MAP_COUNT_YELLOW if id == RomRegistry.YELLOW else MAP_COUNT_RED_BLUE


## `CheckIfInOutsideMap`: which maps write `wLastMap` on the way out of them.
static func is_outside_tileset(tileset: int) -> bool:
	return tileset == TILESET_OVERWORLD or tileset == TILESET_PLATEAU


## `ExtraWarpCheck`: whether a warp the player is not standing on the tile of
## asks for a carpet in front of them rather than for the edge of the map.
static func warp_wants_carpet(map_id: int, tileset: int) -> bool:
	if map_id == MAP_SS_ANNE_3F:
		return false
	if WARP_CARPET_MAPS.has(map_id):
		return true
	return tileset in [TILESET_OVERWORLD, TILESET_SHIP, TILESET_SHIP_PORT, TILESET_PLATEAU]


static func tileset_count(id: StringName) -> int:
	return TILESET_COUNT_YELLOW if id == RomRegistry.YELLOW else TILESET_COUNT_RED_BLUE


## `NUM_SPRITES`. Yellow added ten walking sprites in front of the still ones.
static func sprite_count(id: StringName) -> int:
	return SPRITE_COUNT_YELLOW if id == RomRegistry.YELLOW else SPRITE_COUNT_RED_BLUE


static func super_palette_count(id: StringName) -> int:
	return SUPER_PALETTE_COUNT_YELLOW if id == RomRegistry.YELLOW \
		else SUPER_PALETTE_COUNT_RED_BLUE


## `FIRST_STILL_SPRITE`, the picture id from which a sheet is four tiles.
static func first_still_sprite(id: StringName) -> int:
	return SPRITE_STILL_FIRST_YELLOW if id == RomRegistry.YELLOW \
		else SPRITE_STILL_FIRST_RED_BLUE


static func sprite_offset(layout: Dictionary, number: int) -> int:
	return int(layout["overworld_sprites"]) + (number - 1) * SPRITE_RECORD_SIZE


## Blocks per tileset, in `Tilesets` order.
static func tileset_blocks(id: StringName) -> Array[int]:
	return TILESET_BLOCKS_YELLOW if id == RomRegistry.YELLOW else TILESET_BLOCKS_RED_BLUE


## Whether a map id decodes to a header at all: see [constant UNUSED_MAPS].
static func is_real_map(map_id: int) -> bool:
	return not UNUSED_MAPS.has(map_id)


## Where one map's header sits, through `MapHeaderBanks` and `MapHeaderPointers`
## together. Everything the header points at is in the same bank.
static func map_header_offset(rom: RomFile, layout: Dictionary, map_id: int) -> int:
	return RomFile.linear(
		map_bank(rom, layout, map_id),
		rom.u16le(int(layout["map_headers"]) + map_id * POINTER_SIZE)
	)


static func map_bank(rom: RomFile, layout: Dictionary, map_id: int) -> int:
	return rom.u8(int(layout["map_header_banks"]) + map_id)


static func tileset_offset(layout: Dictionary, number: int) -> int:
	return int(layout["tilesets"]) + number * TILESET_RECORD_SIZE


static func map_song_offset(layout: Dictionary, map_id: int) -> int:
	return int(layout["map_songs"]) + map_id * MAP_SONG_SIZE


## Whether the Super Rod is read as Yellow's flat slot table.
static func flat_super_rod(id: StringName) -> bool:
	return id == RomRegistry.YELLOW


## Which of a block's sixteen tiles decides one walk cell.
static func cell_tile_index(cell_x: int, cell_y: int) -> int:
	return (cell_y * MAP_BLOCK_CELL_WIDTH + 1) * MAP_BLOCK_TILE_WIDTH \
		+ cell_x * MAP_BLOCK_CELL_WIDTH


## `TryDoWildEncounter` reads `hlcoord 9, 9` where everything else reads
## `hlcoord 8, 9`: the bottom right tile of the quarter block the player stands
## in rather than its bottom left, which is why a left shore rolls on grass.
static func cell_encounter_tile_index(cell_x: int, cell_y: int) -> int:
	return cell_tile_index(cell_x, cell_y) + 1
