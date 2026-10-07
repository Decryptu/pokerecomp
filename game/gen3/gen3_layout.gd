class_name Gen3Layout
extends RefCounted

## Dump offsets of each Generation 3 cartridge's tables. An offset is a ROM
## pointer less [constant ROM_BASE]; table evidence is recorded below.

const ROM_BASE: int = 0x08000000
const ROM_WINDOW: int = 0x02000000

## `NUM_SPECIES` includes 25 unused Unown slots and the Hoenn run out of dex order.
const SPECIES_COUNT: int = 412
const NATIONAL_DEX_COUNT: int = 386
const PIC_TABLE_COUNT: int = 440
const PIC_ENTRY_SIZE: int = 8
const PIC_TILES: int = 8
const PIC_BYTES: int = 0x800
const PALETTE_BYTES: int = 32
const SHINY_TAG_BASE: int = 500
const UNOWN_SPECIES: int = 201
const UNOWN_B: int = 413
const UNOWN_FORMS: int = 28
const CASTFORM: int = 385
const DEOXYS: int = 410

const SPECIES_NAME_SIZE: int = 11
const MOVE_NAME_SIZE: int = 13
const TYPE_NAME_SIZE: int = 7

## agbcc pads every struct to four bytes: `SpeciesInfo` is 26 bytes in 28,
## `BattleMove` 9 in 12 and `Evolution` 6 in 8.
const SPECIES_INFO_SIZE: int = 28
const INFO_HP: int = 0x00
const INFO_ATTACK: int = 0x01
const INFO_DEFENSE: int = 0x02
const INFO_SPEED: int = 0x03
const INFO_SP_ATTACK: int = 0x04
const INFO_SP_DEFENSE: int = 0x05
const INFO_TYPES: int = 0x06
const INFO_CATCH_RATE: int = 0x08
const INFO_EXP_YIELD: int = 0x09
const INFO_EV_YIELD: int = 0x0A
const EV_YIELD_STATS: Array[String] = [
	"hp", "attack", "defense", "speed", "sp_attack", "sp_defense",
]
const INFO_ITEMS: int = 0x0C
const INFO_GENDER_RATIO: int = 0x10
const INFO_EGG_CYCLES: int = 0x11
const INFO_FRIENDSHIP: int = 0x12
const INFO_GROWTH_RATE: int = 0x13
const INFO_EGG_GROUPS: int = 0x14
const INFO_ABILITIES: int = 0x16
const INFO_SAFARI_FLEE_RATE: int = 0x18
const INFO_COLOR: int = 0x19
const NO_FLIP_BIT: int = 0x80

const MOVES_COUNT: int = 355
const MOVE_SIZE: int = 12
const MOVE_EFFECT: int = 0
const MOVE_POWER: int = 1
const MOVE_TYPE: int = 2
const MOVE_ACCURACY: int = 3
const MOVE_PP: int = 4
const MOVE_EFFECT_CHANCE: int = 5
const MOVE_TARGET: int = 6
const MOVE_PRIORITY: int = 7
const MOVE_FLAGS: int = 8

## `IS_TYPE_SPECIAL` is above `TYPE_MYSTERY`, which is neither.
const TYPE_COUNT: int = 18
const TYPE_MYSTERY: int = 9

## Unlike Generation 2's one-byte marker, `TYPE_FORESIGHT` is a whole row.
const MATCHUP_SIZE: int = 3
const MATCHUP_FORESIGHT: int = 0xFE
const MATCHUP_END: int = 0xFF
const MATCHUP_MULTIPLIERS: Array[int] = [0, 5, 20]

## `struct Item` is the same on all five; its two function pointers are left out.
const ITEM_SIZE: int = 44
const ITEM_NAME_SIZE: int = 14
const ITEM_ID: int = 0x0E
const ITEM_PRICE: int = 0x10
const ITEM_HOLD_EFFECT: int = 0x12
const ITEM_HOLD_EFFECT_PARAM: int = 0x13
const ITEM_DESCRIPTION: int = 0x14
const ITEM_IMPORTANCE: int = 0x18
const ITEM_REGISTRABILITY: int = 0x19
const ITEM_POCKET: int = 0x1A
const ITEM_TYPE: int = 0x1B
const ITEM_BATTLE_USAGE: int = 0x20
const ITEM_SECONDARY_ID: int = 0x28

## `Trainer` in pret's battle.h/data.h; agbcc rounds party rows to four bytes.
const TRAINER_SIZE: int = 40
const TRAINER_NAME_SIZE: int = 12
const TRAINER_CLASS_NAME_SIZE: int = 13
const PARTY_CUSTOM_MOVES: int = 1
const PARTY_HELD_ITEM: int = 2
const PARTY_STRIDES: Array[int] = [8, 16, 8, 16]
const TRAINER_PARTY_LIMIT: int = 6

const ABILITY_COUNT: int = 78
const ABILITY_NAME_SIZE: int = 13

## `gPokedexEntries` from `NATIONAL_DEX_NONE`. Emerald drops Ruby's second page
## pointer, which FireRed and LeafGreen keep for an empty `unusedDescription`.
const DEX_ENTRY_CATEGORY_SIZE: int = 12
const DEX_ENTRY_HEIGHT: int = 0x0C
const DEX_ENTRY_WEIGHT: int = 0x0E
const DEX_ENTRY_DESCRIPTION: int = 0x10
## Padding follows the last word, so the four start ten bytes from the end.
const DEX_ENTRY_SCALES_FROM_END: int = 10

## The longest pointed-to text is a dex page of 170 bytes.
const TEXT_LIMIT: int = 512

const LEARNSET_END: int = 0xFFFF
const LEARNSET_MOVE_MASK: int = 0x01FF
const LEARNSET_LEVEL_SHIFT: int = 9
const POINTER_SIZE: int = 4
const LEARNSET_MAX: int = 32  # Medicham carries 18 on FireRed

const EVOS_PER_MON: int = 5
const EVOLUTION_SIZE: int = 8
const EVOLUTION_PARAMETER: int = 2
const EVOLUTION_TARGET: int = 4
const EVOLUTION_METHOD_LAST: int = 15  # EVO_BEAUTY

## Map and wild pointers are located from exact layout/slot bytes, then swept
## against pret's map_groups and wild_encounters JSON, including version guards.
const RS_MAP_GROUP_SIZES: Array[int] = [
	54, 5, 5, 6, 7, 7, 8, 7, 7, 13, 8, 17, 10, 24, 13, 13,
	14, 2, 2, 2, 3, 1, 1, 1, 86, 44, 12, 2, 1, 13, 1, 1,
	3, 1,
]
const FRLG_MAP_GROUP_SIZES: Array[int] = [
	5, 123, 60, 66, 4, 6, 8, 10, 6, 8, 20, 10, 8, 2, 10, 4,
	2, 2, 2, 1, 1, 2, 2, 3, 2, 3, 2, 1, 1, 1, 1, 7,
	5, 5, 8, 8, 5, 5, 1, 1, 1, 2, 1,
]
const EMERALD_MAP_GROUP_SIZES: Array[int] = [
	57, 5, 5, 6, 7, 8, 9, 7, 7, 14, 8, 17, 10, 23, 13, 15,
	15, 2, 2, 2, 3, 1, 1, 1, 108, 61, 89, 2, 1, 13, 1, 1,
	3, 1,
]

const RUBY: Dictionary = {
	"map_groups": 0x3085A0,
	"map_group_sizes": RS_MAP_GROUP_SIZES,
	"wild_headers": 0x39D46C,
	"wild_header_count": 97,

	"trainers": 0x1f0514,
	"trainer_count": 694,
	"trainer_class_names": 0x1f0220,
	"trainer_class_count": 58,
	"trainer_pics": 0x1ec554,
	"trainer_palettes": 0x1ec7ec,
	"trainer_coords": 0x1ec408,
	"trainer_pic_count": 83,
	"trainer_money": 0x1f9908,

	"front_pics": 0x1E836C,
	"back_pics": 0x1E980C,
	"normal_palettes": 0x1EA5CC,
	"shiny_palettes": 0x1EB38C,
	"front_coords": 0x1E7C8C,
	"back_coords": 0x1E912C,
	"species_names": 0x1F7184,  # gSpeciesNames
	"move_names": 0x1F8338,  # gMoveNames
	"type_effectiveness": 0x1F9738,  # gTypeEffectiveness
	"type_names": 0x1F9888,  # gTypeNames
	"moves": 0x1FB144,  # gBattleMoves
	"species_to_hoenn": 0x1FC1F8,  # gSpeciesToHoennPokedexNum
	"species_to_national": 0x1FC52E,  # gSpeciesToNationalPokedexNum
	"species_info": 0x1FEC30,  # gBaseStats
	"evolutions": 0x203B80,  # gEvolutionTable
	"learnsets": 0x207BE0,  # gLevelUpLearnsets
	"ability_descriptions": 0x1FA128,  # gAbilityDescriptions
	"ability_names": 0x1FA260,  # gAbilityNames
	"dex_entries": 0x3B1874,  # gPokedexEntries
	"items": 0x3C5580,  # gItems
	"item_count": 349,  # ITEMS_COUNT
	"dex_entry_size": 36,
	"dex_pages": 2,
}

const SAPPHIRE: Dictionary = {
	"map_groups": 0x308530,
	"map_group_sizes": RS_MAP_GROUP_SIZES,
	"wild_headers": 0x39D2B4,
	"wild_header_count": 97,

	"trainers": 0x1f04a4,
	"trainer_count": 694,
	"trainer_class_names": 0x1f01b0,
	"trainer_class_count": 58,
	"trainer_pics": 0x1ec4e4,
	"trainer_palettes": 0x1ec77c,
	"trainer_coords": 0x1ec398,
	"trainer_pic_count": 83,
	"trainer_money": 0x1f9898,

	"front_pics": 0x1E82FC,
	"back_pics": 0x1E979C,
	"normal_palettes": 0x1EA55C,
	"shiny_palettes": 0x1EB31C,
	"front_coords": 0x1E7C1C,
	"back_coords": 0x1E90BC,
	"species_names": 0x1F7114,
	"move_names": 0x1F82C8,
	"type_effectiveness": 0x1F96C8,
	"type_names": 0x1F9818,
	"moves": 0x1FB0D4,
	"species_to_hoenn": 0x1FC188,
	"species_to_national": 0x1FC4BE,
	"species_info": 0x1FEBC0,
	"evolutions": 0x203B10,
	"learnsets": 0x207B70,
	"ability_descriptions": 0x1FA0B8,
	"ability_names": 0x1FA1F0,
	"dex_entries": 0x3B18D0,
	"items": 0x3C55DC,
	"item_count": 349,
	"dex_entry_size": 36,
	"dex_pages": 2,
}

const FIRERED: Dictionary = {
	"map_groups": 0x352718,
	"map_group_sizes": FRLG_MAP_GROUP_SIZES,
	"wild_headers": 0x3C9D28,
	"wild_header_count": 132,

	"trainers": 0x23eb38,
	"trainer_count": 743,
	"trainer_class_names": 0x23e5c8,
	"trainer_class_count": 107,
	"trainer_pics": 0x2395ec,
	"trainer_palettes": 0x239a8c,
	"trainer_coords": 0x23939c,
	"trainer_pic_count": 148,
	"trainer_money": 0x24f290,

	"front_pics": 0x23511C,
	"back_pics": 0x2365BC,
	"normal_palettes": 0x23737C,
	"shiny_palettes": 0x23813C,
	"front_coords": 0x234A3C,
	"back_coords": 0x235EDC,
	"species_names": 0x245F50,
	"move_names": 0x247104,
	"type_effectiveness": 0x24F0C0,
	"type_names": 0x24F210,
	"moves": 0x250C74,
	"species_to_hoenn": 0x251D28,  # sSpeciesToHoennPokedexNum
	"species_to_national": 0x25205E,  # sSpeciesToNationalPokedexNum
	"species_info": 0x2547F4,  # gSpeciesInfo
	"evolutions": 0x2597C4,
	"learnsets": 0x25D824,
	"ability_descriptions": 0x24FB78,  # gAbilityDescriptionPointers
	"ability_names": 0x24FCB0,
	"dex_entries": 0x44E8B0,
	"items": 0x3DB098,
	"item_count": 375,
	"dex_entry_size": 36,
	"dex_pages": 1,
}

const LEAFGREEN: Dictionary = {
	"map_groups": 0x3526F8,
	"map_group_sizes": FRLG_MAP_GROUP_SIZES,
	"wild_headers": 0x3C9B64,
	"wild_header_count": 132,

	"trainers": 0x23eb14,
	"trainer_count": 743,
	"trainer_class_names": 0x23e5a4,
	"trainer_class_count": 107,
	"trainer_pics": 0x2395c8,
	"trainer_palettes": 0x239a68,
	"trainer_coords": 0x239378,
	"trainer_pic_count": 148,
	"trainer_money": 0x24f26c,

	"front_pics": 0x2350F8,
	"back_pics": 0x236598,
	"normal_palettes": 0x237358,
	"shiny_palettes": 0x238118,
	"front_coords": 0x234A18,
	"back_coords": 0x235EB8,
	"species_names": 0x245F2C,
	"move_names": 0x2470E0,
	"type_effectiveness": 0x24F09C,
	"type_names": 0x24F1EC,
	"moves": 0x250C50,
	"species_to_hoenn": 0x251D04,
	"species_to_national": 0x25203A,
	"species_info": 0x2547D0,
	"evolutions": 0x2597A4,
	"learnsets": 0x25D804,
	"ability_descriptions": 0x24FB54,
	"ability_names": 0x24FC8C,
	"dex_entries": 0x44E2E0,
	"items": 0x3DAED4,
	"item_count": 375,
	"dex_entry_size": 36,
	"dex_pages": 1,
}

const EMERALD: Dictionary = {
	"map_groups": 0x486578,
	"map_group_sizes": EMERALD_MAP_GROUP_SIZES,
	"wild_headers": 0x552D48,
	"wild_header_count": 124,

	"trainers": 0x310030,
	"trainer_count": 855,
	"trainer_class_names": 0x30fcd4,
	"trainer_class_count": 66,
	"trainer_pics": 0x305654,
	"trainer_palettes": 0x30593c,
	"trainer_coords": 0x3054e0,
	"trainer_pic_count": 93,
	"trainer_money": 0x31aeb8,

	"front_pics": 0x30A18C,
	"back_pics": 0x3028B8,
	"normal_palettes": 0x303678,
	"shiny_palettes": 0x304438,
	"front_coords": 0x300D38,
	"back_coords": 0x3021D8,
	"species_names": 0x3185C8,
	"move_names": 0x31977C,
	"type_effectiveness": 0x31ACE8,
	"type_names": 0x31AE38,
	"moves": 0x31C898,
	"species_to_hoenn": 0x31D94C,
	"species_to_national": 0x31DC82,
	"species_info": 0x3203CC,
	"evolutions": 0x32531C,
	"learnsets": 0x32937C,
	"ability_descriptions": 0x31BAD4,
	"ability_names": 0x31B6DB,
	"dex_entries": 0x56B5B0,
	"items": 0x5839A0,
	"item_count": 377,
	"dex_entry_size": 32,
	"dex_pages": 1,
}


static func for_id(id: StringName) -> Dictionary:
	match id:
		RomRegistry.RUBY:
			return RUBY
		RomRegistry.SAPPHIRE:
			return SAPPHIRE
		RomRegistry.FIRERED:
			return FIRERED
		RomRegistry.LEAFGREEN:
			return LEAFGREEN
		RomRegistry.EMERALD:
			return EMERALD
	return {}


## -1 for a pointer outside the cartridge window.
static func rom_offset(pointer: int) -> int:
	if pointer < ROM_BASE or pointer >= ROM_BASE + ROM_WINDOW:
		return -1
	return pointer - ROM_BASE


static func species_info_offset(layout: Dictionary, species: int) -> int:
	return int(layout["species_info"]) + species * SPECIES_INFO_SIZE


static func species_name_offset(layout: Dictionary, species: int) -> int:
	return int(layout["species_names"]) + species * SPECIES_NAME_SIZE


static func move_offset(layout: Dictionary, move: int) -> int:
	return int(layout["moves"]) + move * MOVE_SIZE


static func move_name_offset(layout: Dictionary, move: int) -> int:
	return int(layout["move_names"]) + move * MOVE_NAME_SIZE


static func type_name_offset(layout: Dictionary, type: int) -> int:
	return int(layout["type_names"]) + type * TYPE_NAME_SIZE


static func item_offset(layout: Dictionary, item: int) -> int:
	return int(layout["items"]) + item * ITEM_SIZE


static func ability_name_offset(layout: Dictionary, ability: int) -> int:
	return int(layout["ability_names"]) + ability * ABILITY_NAME_SIZE


static func ability_description_pointer(layout: Dictionary, ability: int) -> int:
	return int(layout["ability_descriptions"]) + ability * POINTER_SIZE


static func dex_entry_offset(layout: Dictionary, national: int) -> int:
	return int(layout["dex_entries"]) + national * int(layout["dex_entry_size"])


static func evolution_offset(layout: Dictionary, species: int, slot: int) -> int:
	return int(layout["evolutions"]) + (species * EVOS_PER_MON + slot) * EVOLUTION_SIZE


## Both dex tables start at `SPECIES_BULBASAUR`.
static func national_number(rom: RomFile, layout: Dictionary, species: int) -> int:
	return _dex_number(rom, int(layout["species_to_national"]), species)


static func hoenn_number(rom: RomFile, layout: Dictionary, species: int) -> int:
	return _dex_number(rom, int(layout["species_to_hoenn"]), species)


static func _dex_number(rom: RomFile, table: int, species: int) -> int:
	if species <= 0 or species >= SPECIES_COUNT:
		return 0
	return rom.u16le(table + (species - 1) * 2)


static func is_special_type(type: int) -> bool:
	return type > TYPE_MYSTERY


static func read_pointer(rom: RomFile, at: int, length: int, alignment: int = 4) -> int:
	if not rom.in_bounds(at, 4):
		return -1
	var offset: int = Gen3Layout.rom_offset(rom.u32le(at))
	return offset if offset % alignment == 0 and rom.in_bounds(offset, length) else -1


static func valid_map(layout: Dictionary, group: int, number: int) -> bool:
	var sizes: Array = layout["map_group_sizes"]
	return group >= 0 and group < sizes.size() and number >= 0 and number < int(sizes[group])
