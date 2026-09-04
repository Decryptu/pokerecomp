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
## the HMs follow the TMs in the same table.
const TM_COUNT: int = 50
const HM_COUNT: int = 5

## `NUM_TRAINERS`, the trainer classes rather than the individual trainers.
const TRAINER_CLASS_COUNT: int = 47

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


## `NUM_POKEMON + 1` rows in dex order with MISSINGNO's first, so the dex number
## is the row.
static func mon_palette_offset(layout: Dictionary, dex: int) -> int:
	return int(layout["mon_palettes"]) + dex


static func super_palette_offset(layout: Dictionary, palette: int) -> int:
	return int(layout["super_palettes"]) + palette * SUPER_PALETTE_BYTES


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
