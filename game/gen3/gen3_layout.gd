class_name Gen3Layout
extends RefCounted

## Dump offsets of each Generation 3 cartridge's tables, from the `.map` and
## `.elf` of pret's byte-exact builds; a symbol is [constant ROM_BASE] plus one.

const ROM_BASE: int = 0x08000000
const ROM_WINDOW: int = 0x02000000

## `NUM_SPECIES` includes 25 unused Unown slots and the Hoenn run out of dex order.
const SPECIES_COUNT: int = 412
const NATIONAL_DEX_COUNT: int = 386
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

## Keys name the table, not one cartridge's spelling (`gBaseStats`, `gSpeciesInfo`).
const RUBY: Dictionary = {
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
}

const SAPPHIRE: Dictionary = {
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
}

const FIRERED: Dictionary = {
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
}

const LEAFGREEN: Dictionary = {
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
}

const EMERALD: Dictionary = {
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
