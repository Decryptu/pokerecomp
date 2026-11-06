class_name Gen3Layout
extends RefCounted

## Each Generation 3 cartridge's table offsets: ROM pointers less [constant ROM_BASE], evidence recorded below.

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
const SPINDA: int = 308

const SPECIES_NAME_SIZE: int = 11
const MOVE_NAME_SIZE: int = 13
const TYPE_NAME_SIZE: int = 7

## agbcc pads every struct to four bytes: `SpeciesInfo` is 26 bytes in 28, `BattleMove` 9 in 12 and `Evolution` 6 in 8.
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

## `gPokedexEntries` from `NATIONAL_DEX_NONE`; Emerald drops the second page pointer FRLG keep for `unusedDescription`.
const DEX_ENTRY_CATEGORY_SIZE: int = 12
const DEX_ENTRY_HEIGHT: int = 0x0C
const DEX_ENTRY_WEIGHT: int = 0x0E
const DEX_ENTRY_DESCRIPTION: int = 0x10
## Padding follows the last word, so the four start ten bytes from the end.
const DEX_ENTRY_SCALES_FROM_END: int = 10

## The longest pointed-to text is one of Ruby's script texts, 825 bytes.
const TEXT_LIMIT: int = 1024

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

## Map and wild pointers found by exact layout and slot bytes, swept against pret's map and wild JSON, guards included.
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

## gStdScripts and the five trainer-battle entry points come from nm on the matching pret builds (Sapphire's
## scripts shift). `gInitialMovementTypeFacingDirections` follows `gRangedMovementTypes`; the graphics-info
## pointers run `NUM_OBJ_EVENT_GFX` long, Emerald's `gMauvilleOldManGraphicsInfoPointers` after them.

## The rest each match one run of pret's bytes: `gFieldEffectObjectTemplatePointers` and trainer_see.c's icon
## template through their tiled PNGs and pointer runs, surfability (240 bytes, keeping its ROM tail), weather
## palettes, sheets and drought tables, general/grass/ash palettes (Ruby's 00-02.pal), the field-move streaks,
## Spinda's spots, the template with `sOamData_CutGrass`'s 0x1401, the Secret Power templates followed by their
## 0x1003 and 0x1008 palettes. `native_scripts` (only C starts them) and `map_layouts` come from nm on the matching builds.
const RUBY: Dictionary = {
	"movement_types": 0x36DBD4,
	"object_palettes": 0x373794, "object_palette_tags": 0x3739B4,
	"player_reflection_palettes": 0x37388C, "special_reflection_palettes": 0x3738FC,
	"surfable_behaviors": 0x308E44, "shadow_templates": 0x36DFD8, "icon_template": 0x39B528,
	"spinda_spots": 0x1FCB9C, "field_move_streaks": 0x39E92C, "field_move_streaks_indoors": 0x39EDCC,
	"cut_grass_template": 0x3C161C, "secret_power_templates": 0x3D2630,
	"text_box": {"fonts": [[0xEA2C44, 0x1E65AC]], "frame": [0xEA0108, 0x1C0], "frame_palette": 0x1E66CA, "arrow": [0x1E5F08, 0xC0], "std_frame": [0xE9ADDC, 0x120], "std_frame_palette": 0xE9AEFC},
	"door_graphics": 0x30F9CC, "tmhm_moves": 0x37651C,
	"map_layouts": [0x304F30, 332],
	"native_scripts": {
		"trainer_approach": 0x19F82B, "cave_use_secret_power": 0x1A2D06, "tree_use_secret_power": 0x1A2D5E,
		"shrub_use_secret_power": 0x1A2DB6, "blueprint": 0x1A08B1, "book_shelf": 0x1A0884, "brendan_pc": 0x15283E,
		"cable_box_results": 0x1A4383, "cannot_use_waterfall": 0x1B11AA, "closed_sootopolis_door": 0x14D31F,
		"egg_hatch": 0x1B25D2, "fall_down_hole": 0x1C6BDB, "fall_down_hole_mt_pyre": 0x1C6BF4,
		"field_poison": 0x1A14D8, "test_signpost": 0x1C6C18, "hidden_item": 0x19FF9B, "may_pc": 0x152C59, "pc": 0x1A0029,
		"picture_book_shelf": 0x1A087B, "pokeblock_feeder": 0x1C3480, "pokemon_center_book_shelf": 0x1A088D,
		"record_mixing_pc": 0x15F45A, "region_map": 0x1A02F6, "repel_wore_off": 0x1C33FC,
		"running_shoes_manual": 0x1B6E70, "safari_times_up": 0x1C345E, "sand_ornament": 0x15F543,
		"secret_base_pc": 0x15F38C, "select_without_item": 0x1A14CF, "shield_or_toy_tv": 0x15F548,
		"shop_shelf": 0x1A08A8, "ss_tidal_step": 0x15FD2D, "trash_can": 0x1A089F,
		"trick_house_door": 0x161701, "tv": 0x1A6E92, "use_dive": 0x1B1236, "use_dive_underwater": 0x1B127F,
		"use_surf": 0x1A0137, "use_waterfall": 0x1B1170, "vase": 0x1A0896},
	"general_palette": 0x3694A0, "ash_palette": 0x36CA60, "grass_palette": 0x3694C0,
	"weather_palette": 0x397100, "weather_sheets": 0x397120, "drought_palette_pointers": 0x396FC0,
	"object_graphics": 0x36DC70, "object_graphics_count": 218,
	"berries": 0x3CD2E8,
	"berry_graphics": 0x374484, "berry_palettes": 0x3743D8, "berry_pics": 0x37432C,
	"movement_type_count": 77,
	"standard_scripts": 0x14B70C,
	"standard_script_count": 8,
	"trainer_battle_scripts": [0x19F838, 0x19F860, 0x19F898, 0x19F8A7, 0x19F8CE],
	"multichoice_lists": [0x3CDE1C, 73], "std_strings": [0x3CE064, 19], "start_menu": [0x376D3C, 10],
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
	"movement_types": 0x36DB64,
	"object_palettes": 0x373724, "object_palette_tags": 0x373944,
	"player_reflection_palettes": 0x37381C, "special_reflection_palettes": 0x37388C,
	"surfable_behaviors": 0x308DD4, "shadow_templates": 0x36DF68, "icon_template": 0x39B370,
	"spinda_spots": 0x1FCB2C, "field_move_streaks": 0x39E774, "field_move_streaks_indoors": 0x39EC14,
	"cut_grass_template": 0x3C1678, "secret_power_templates": 0x3D268C,
	"text_box": {"fonts": [[0xEA2DF0, 0x1E653C]], "frame": [0xEA02B4, 0x1C0], "frame_palette": 0x1E665A, "arrow": [0x1E5E98, 0xC0], "std_frame": [0xE9ADDC, 0x120], "std_frame_palette": 0xE9AEFC},
	"door_graphics": 0x30F95C, "tmhm_moves": 0x3764AC,
	"map_layouts": [0x304EC0, 332],
	"native_scripts": {
		"trainer_approach": 0x19F7BB, "cave_use_secret_power": 0x1A2C96, "tree_use_secret_power": 0x1A2CEE,
		"shrub_use_secret_power": 0x1A2D46, "blueprint": 0x1A0841, "book_shelf": 0x1A0814, "brendan_pc": 0x1527CE,
		"cable_box_results": 0x1A4313, "cannot_use_waterfall": 0x1B113A, "closed_sootopolis_door": 0x14D2B3,
		"egg_hatch": 0x1B2562, "fall_down_hole": 0x1C6B6B, "fall_down_hole_mt_pyre": 0x1C6B84,
		"field_poison": 0x1A1468, "test_signpost": 0x1C6BA8, "hidden_item": 0x19FF2B, "may_pc": 0x152BE9, "pc": 0x19FFB9,
		"picture_book_shelf": 0x1A080B, "pokeblock_feeder": 0x1C3410, "pokemon_center_book_shelf": 0x1A081D,
		"record_mixing_pc": 0x15F3EA, "region_map": 0x1A0286, "repel_wore_off": 0x1C338C,
		"running_shoes_manual": 0x1B6E00, "safari_times_up": 0x1C33EE, "sand_ornament": 0x15F4D3,
		"secret_base_pc": 0x15F31C, "select_without_item": 0x1A145F, "shield_or_toy_tv": 0x15F4D8,
		"shop_shelf": 0x1A0838, "ss_tidal_step": 0x15FCBD, "trash_can": 0x1A082F,
		"trick_house_door": 0x161691, "tv": 0x1A6E22, "use_dive": 0x1B11C6, "use_dive_underwater": 0x1B120F,
		"use_surf": 0x1A00C7, "use_waterfall": 0x1B1100, "vase": 0x1A0826},
	"general_palette": 0x369430, "ash_palette": 0x36C9F0, "grass_palette": 0x369450,
	"weather_palette": 0x396F48, "weather_sheets": 0x396F68, "drought_palette_pointers": 0x396E08,
	"object_graphics": 0x36DC00, "object_graphics_count": 218,
	"berries": 0x3CD344,
	"berry_graphics": 0x374414, "berry_palettes": 0x374368, "berry_pics": 0x3742BC,
	"movement_type_count": 77,
	"standard_scripts": 0x14B70C,
	"standard_script_count": 8,
	"trainer_battle_scripts": [0x19F7C8, 0x19F7F0, 0x19F828, 0x19F837, 0x19F85E],
	"multichoice_lists": [0x3CDE78, 73], "std_strings": [0x3CE0C0, 19], "start_menu": [0x376CCC, 10],
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
	"movement_types": 0x39FD7C,
	"object_palettes": 0x3A51C8, "object_palette_tags": 0x3A53A0,
	"player_reflection_palettes": 0x3A5278, "special_reflection_palettes": 0x3A52E8,
	"surfable_behaviors": 0x352FE8, "shadow_templates": 0x3A0080, "icon_template": 0x3C73F8,
	"spinda_spots": 0x2526CC, "field_move_streaks": 0x3CB660, "field_move_streaks_indoors": 0x3CBB00,
	"cut_grass_template": 0x3D41BC,
	"general_palette": 0x399018, "ash_palette": 0x39C5F8, "grass_palette": 0x399038,
	"weather_palette": 0x3C2D50, "weather_sheets": 0x3C2D70,
	"object_graphics": 0x39FE20, "object_graphics_count": 152, "step_anims": 0x3A3708,
	"berries": 0x3DF858,
	"movement_type_count": 81,
	"standard_scripts": 0x1604C8,
	"standard_script_count": 10,
	"text_box": {"fonts": [[0x1FF370, 0x207370], [0x20F688, 0x217688], [0x21F9A0, 0x2279A0]], "frame": [0x41F238, 0x280],
		"frame_palette": 0x471E4C, "signpost": [0x470B6C, 0x280], "signpost_palette": 0x471E6C, "arrow": [0x1EA1BC, 0x500], "std_frame": [0x470DCC, 0x120], "std_frame_palette": 0x47196C, "colors": 0x464360, "help": [0x456708, 0x280], "help_palette": 0x471E8C},
	"door_graphics": 0x35B648, "tmhm_moves": 0x45A86C,
	"map_layouts": [0x34EBFC, 383],
	"native_scripts": {
		"cancel_message_box": 0x1A7B53,
		"trainer_approach": 0x1A4F2C, "advertising_poster": 0x1A770E, "battle_records": 0x1BB91A,
		"blinking_lights": 0x1A7744, "blueprint": 0x1A76B4, "book_shelf": 0x1A767E, "burglary": 0x1A76BD,
		"cabinet": 0x1A76CF, "cannot_use_waterfall": 0x1BE372, "computer": 0x1A76A2, "cup": 0x1A7729,
		"current_too_fast": 0x1A6B85, "dresser": 0x1A76E1, "egg_hatch": 0x1BF5B9, "fall_warp": 0x1C13D4,
		"field_poison": 0x1A8E75, "food": 0x1A7690, "test_signpost": 0x1C55CE, "hidden_item": 0x1A68BB, "impressive_machine": 0x1A76AB,
		"indigo_authority": 0x1A7771, "indigo_goal": 0x1A7768, "kitchen": 0x1A76D8, "mart_shelf": 0x1A7687,
		"neatly_lined_up_tools": 0x1A774D, "painting": 0x1A76F3, "pc": 0x1A69CD, "pokecenter_sign": 0x1A775F,
		"pokemart_sign": 0x1A7756, "power_plant_machine": 0x1A76FC, "questionnaire": 0x1A777A,
		"region_map": 0x1A6CAA, "repel_wore_off": 0x1BFBD8, "safari_times_up": 0x1BFC38,
		"select_without_item": 0x1A7818, "snacks": 0x1A76EA, "tasty_food": 0x1A7717, "telephone": 0x1A7705,
		"trainer_tower_time": 0x1C550F, "trash_can": 0x1A7720, "tv": 0x1A76C6,
		"use_surf": 0x1A6B40, "use_waterfall": 0x1BE32A, "video_game": 0x1A7699, "vs_seeker_charged": 0x1A8D65,
		"wireless_monitor": 0x1BC04B},
	"trainer_battle_scripts": [0x1A4F39, 0x1A4F61, 0x1A4F99, 0x1A4FB6, 0x1A4FEB],
	"multichoice_lists": [0x3E0520, 65], "std_strings": [0x3E0728, 29], "start_menu": [0x3A73B4, 9], "start_menu_help": 0x3A7404,
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
	"movement_types": 0x39FD5C,
	"object_palettes": 0x3A51A8, "object_palette_tags": 0x3A5380,
	"player_reflection_palettes": 0x3A5258, "special_reflection_palettes": 0x3A52C8,
	"surfable_behaviors": 0x352FC8, "shadow_templates": 0x3A0060, "icon_template": 0x3C7234,
	"spinda_spots": 0x2526A8, "field_move_streaks": 0x3CB49C, "field_move_streaks_indoors": 0x3CB93C,
	"cut_grass_template": 0x3D3FF8,
	"general_palette": 0x398FF8, "ash_palette": 0x39C5D8, "grass_palette": 0x399018,
	"weather_palette": 0x3C2B8C, "weather_sheets": 0x3C2BAC,
	"object_graphics": 0x39FE00, "object_graphics_count": 152, "step_anims": 0x3A36E8,
	"berries": 0x3DF694,
	"movement_type_count": 81,
	"standard_scripts": 0x1604A4,
	"standard_script_count": 10,
	"text_box": {"fonts": [[0x1FF34C, 0x20734C], [0x20F664, 0x217664], [0x21F97C, 0x22797C]], "frame": [0x41F074, 0x280],
		"frame_palette": 0x471738, "signpost": [0x470458, 0x280], "signpost_palette": 0x471758, "arrow": [0x1EA198, 0x500], "std_frame": [0x4706B8, 0x120], "std_frame_palette": 0x471258, "colors": 0x463D90, "help": [0x456138, 0x280], "help_palette": 0x471778},
	"door_graphics": 0x35B628, "tmhm_moves": 0x45A29C,
	"map_layouts": [0x34EBDC, 383],
	"native_scripts": {
		"cancel_message_box": 0x1A7B2F,
		"trainer_approach": 0x1A4F08, "advertising_poster": 0x1A76EA, "battle_records": 0x1BB8F6,
		"blinking_lights": 0x1A7720, "blueprint": 0x1A7690, "book_shelf": 0x1A765A, "burglary": 0x1A7699,
		"cabinet": 0x1A76AB, "cannot_use_waterfall": 0x1BE34E, "computer": 0x1A767E, "cup": 0x1A7705,
		"current_too_fast": 0x1A6B61, "dresser": 0x1A76BD, "egg_hatch": 0x1BF595, "fall_warp": 0x1C13B0,
		"field_poison": 0x1A8E51, "food": 0x1A766C, "test_signpost": 0x1C55AA, "hidden_item": 0x1A6897, "impressive_machine": 0x1A7687,
		"indigo_authority": 0x1A774D, "indigo_goal": 0x1A7744, "kitchen": 0x1A76B4, "mart_shelf": 0x1A7663,
		"neatly_lined_up_tools": 0x1A7729, "painting": 0x1A76CF, "pc": 0x1A69A9, "pokecenter_sign": 0x1A773B,
		"pokemart_sign": 0x1A7732, "power_plant_machine": 0x1A76D8, "questionnaire": 0x1A7756,
		"region_map": 0x1A6C86, "repel_wore_off": 0x1BFBB4, "safari_times_up": 0x1BFC14,
		"select_without_item": 0x1A77F4, "snacks": 0x1A76C6, "tasty_food": 0x1A76F3, "telephone": 0x1A76E1,
		"trainer_tower_time": 0x1C54EB, "trash_can": 0x1A76FC, "tv": 0x1A76A2,
		"use_surf": 0x1A6B1C, "use_waterfall": 0x1BE306, "video_game": 0x1A7675, "vs_seeker_charged": 0x1A8D41,
		"wireless_monitor": 0x1BC027},
	"trainer_battle_scripts": [0x1A4F15, 0x1A4F3D, 0x1A4F75, 0x1A4F92, 0x1A4FC7],
	"multichoice_lists": [0x3E035C, 65], "std_strings": [0x3E0564, 29], "start_menu": [0x3A7394, 9], "start_menu_help": 0x3A73E4,
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
	"movement_types": 0x50557C,
	"object_palettes": 0x50BBC8, "object_palette_tags": 0x50BE38,
	"player_reflection_palettes": 0x50BD00, "special_reflection_palettes": 0x50BD78,
	"surfable_behaviors": 0x486EFC, "shadow_templates": 0x5059F8, "icon_template": 0x5507B4,
	"spinda_spots": 0x31E2F0, "field_move_streaks": 0x55AE50, "field_move_streaks_indoors": 0x55B2F0,
	"cut_grass_template": 0x57C66C, "secret_power_templates": 0x58E600,
	"text_box": {"fonts": [[0x64C2E4, 0x6542E4]], "frame": [0xDDD748, 0x1C0], "frame_palette": 0xDDD728, "arrow": [0x2E968C, 0xC0], "std_frame": [0x50E87C, 0x120], "std_frame_palette": 0x50FEFC},
	"door_graphics": 0x497174, "tmhm_moves": 0x616040,
	"map_layouts": [0x481DD4, 441],
	"native_scripts": {
		"trainer_approach": 0x271354, "hide_mew_when_grass_cut": 0x267EDB, "cave_use_secret_power": 0x275A86,
		"tree_use_secret_power": 0x275ADF, "shrub_use_secret_power": 0x275B38, "abnormal_weather_end": 0x273D1F,
		"blueprint": 0x272604, "book_shelf": 0x2725D7, "brendan_pc": 0x1F860D, "cable_box_results": 0x277365,
		"cannot_use_waterfall": 0x290A83, "closed_sootopolis_door": 0x1E615D, "egg_hatch": 0x291FC0,
		"fall_down_hole": 0x2A8337, "fall_down_hole_mt_pyre": 0x2A8350, "field_poison": 0x2736BC,
		"test_signpost": 0x2C8436, "hidden_item": 0x271CB7, "may_pc": 0x1F9553, "open_regi_entrance": 0x238EAF, "pc": 0x271D92,
		"picture_book_shelf": 0x2725CE, "pokeblock_feeder": 0x2A4BAC, "pokemon_center_book_shelf": 0x2725E0,
		"questionnaire": 0x27381B, "record_mixing_pc": 0x23B589, "region_map": 0x27208F, "repel_wore_off": 0x2A4B2A,
		"rival_rayquaza_call": 0x224175, "roxanne_call": 0x21307B, "running_shoes_manual": 0x292DE5,
		"safari_times_up": 0x2A4B8A, "sand_ornament": 0x23B684, "scott_fortree_call": 0x1F49EC,
		"scott_frontier_call": 0x1FA4D6, "secret_base_pc": 0x23B4BB, "select_without_item": 0x2736B3,
		"shield_or_toy_tv": 0x23B68C, "shop_shelf": 0x2725FB, "sky_pillar_closed_door": 0x2393F9,
		"ss_tidal_step": 0x23C050, "trainer_hill_timer": 0x2C8393, "trash_can": 0x2725F2,
		"trick_house_door": 0x26A22A, "tv": 0x27EE0B, "use_dive": 0x290B0F, "use_dive_underwater": 0x290B5A,
		"use_surf": 0x271EA0, "use_waterfall": 0x290A49, "vase": 0x2725E9, "wally_call": 0x1DF7BA,
		"wireless_box_results": 0x277B8A},
	"general_palette": 0x4F77B8, "ash_palette": 0x4FACB8, "grass_palette": 0x4F77D8,
	"weather_palette": 0x54C270, "weather_sheets": 0x54C290, "drought_colors": 0x54014C,
	"object_graphics": 0x505620, "object_graphics_count": 239, "step_anims": 0x5094AC,
	"mauville_graphics": 0x5059DC, "mauville_graphics_count": 7,
	"berries": 0x58A670,
	"berry_graphics": 0x50C908, "berry_palettes": 0x50C85C, "berry_pics": 0x50C7B0,
	"movement_type_count": 81,
	"standard_scripts": 0x1DC2A0,
	"standard_script_count": 11,
	"trainer_battle_scripts": [0x271362, 0x27138A, 0x2713C2, 0x2713D1, 0x2713F8],
	"multichoice_lists": [0x58B760, 114], "std_strings": [0x58BAF0, 30], "start_menu": [0x510540, 13],
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
