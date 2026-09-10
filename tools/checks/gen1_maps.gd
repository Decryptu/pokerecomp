extends RefCounted

## Every Generation 1 map, tileset, SGB palette and overworld sprite in the
## cache, swept on Red, Blue and Yellow. The counts come from pret's own
## `data/maps`, `gfx/blocksets` and `data/sprites`, and the structural rules are
## the map macros' own assertions: a sign's text id sits above the object ids,
## an object's inside them, and every warp and connection names a real map.

## Real maps of the flat table's 248 or 249 ids, and the tilesets behind them.
const MAP_COUNTS: Dictionary = {&"red": 226, &"blue": 226, &"yellow": 227}
const TILESET_COUNTS: Dictionary = {&"red": 24, &"blue": 24, &"yellow": 25}

## What the corpus holds, which is what says a record's stride is right: a wrong
## one drifts long before the last map.
const CENSUS: Dictionary = {
	&"red": {"warps": 813, "signs": 202, "objects": 924, "connections": 78,
		"items": 106, "trainers": 334},
	&"blue": {"warps": 813, "signs": 202, "objects": 924, "connections": 78,
		"items": 106, "trainers": 334},
	&"yellow": {"warps": 817, "signs": 204, "objects": 949, "connections": 78,
		"items": 111, "trainers": 329},
}

## `PalletTown.asm` and `PalletTown.blk` whole, the one map pinned end to end.
const PALLET_TOWN: int = 0
const PALLET_BLOCKS: Array[int] = [
	0x52, 0x4F, 0x52, 0x52, 0x4F, 0x0B, 0x50, 0x52, 0x52, 0x50,
	0x4E, 0x01, 0x38, 0x39, 0x01, 0x01, 0x38, 0x39, 0x01, 0x4D,
	0x4E, 0x08, 0x3C, 0x3D, 0x01, 0x08, 0x3C, 0x3D, 0x01, 0x4D,
	0x4E, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x4D,
	0x4E, 0x01, 0x77, 0x56, 0x01, 0x0C, 0x0D, 0x0E, 0x01, 0x4D,
	0x4E, 0x01, 0x74, 0x74, 0x01, 0x10, 0x3A, 0x00, 0x01, 0x4D,
	0x4E, 0x01, 0x01, 0x01, 0x01, 0x77, 0x56, 0x77, 0x31, 0x4D,
	0x4E, 0x0A, 0x1D, 0x1E, 0x31, 0x74, 0x74, 0x0A, 0x31, 0x4D,
	0x50, 0x0A, 0x65, 0x64, 0x61, 0x61, 0x61, 0x61, 0x61, 0x4F,
]
const PALLET_WIDTH: int = 10
const PALLET_HEIGHT: int = 9
const PALLET_BORDER: int = 0x0B
const PALLET_MUSIC: int = 186
## Red's house, Blue's house and Oak's lab, by destination map and warp index.
const PALLET_WARPS: Array = [[5, 5, 37, 0], [13, 5, 39, 0], [12, 11, 40, 1]]
const PALLET_SIGNS: Array = [[13, 13, 4], [7, 9, 5], [3, 5, 6], [11, 5, 7]]
## Route 1 to the north and Route 21 to the south, both ten blocks wide.
const PALLET_CONNECTIONS: Array = [["north", 12, 35], ["south", 32, 0]]

## `Tilesets`' first row: `Overworld_Coll`, the grass tile and
## TILEANIM_WATER_FLOWER. The blockset is what every town and route draws from.
const OVERWORLD_TILESET: int = 0
const OVERWORLD_BLOCKS: int = 128
const OVERWORLD_GRASS: int = 0x52
const OVERWORLD_ANIMATION: int = 2
const OVERWORLD_PASSABLE: Array[int] = [
	0x00, 0x10, 0x1B, 0x20, 0x21, 0x23, 0x2C, 0x2D, 0x2E, 0x30,
	0x31, 0x33, 0x39, 0x3C, 0x3E, 0x52, 0x54, 0x58, 0x5B,
]

## Every template `object_event`'s two movement bytes decode to, and how many.
const MOVEMENTS: Array[int] = [
	Gen2WorldObject.MOVEMENT_WANDER, Gen2WorldObject.MOVEMENT_WALK_UP_DOWN,
	Gen2WorldObject.MOVEMENT_WALK_LEFT_RIGHT,
	Gen2WorldObject.MOVEMENT_SPINRANDOM_SLOW,
	Gen2WorldObject.MOVEMENT_STRENGTH_BOULDER, Gen2WorldObject.MOVEMENT_FIXED_DOWN,
	Gen2WorldObject.MOVEMENT_FIXED_UP, Gen2WorldObject.MOVEMENT_FIXED_LEFT,
	Gen2WorldObject.MOVEMENT_FIXED_RIGHT,
]
const MOVEMENT_CENSUS: Dictionary = {
	&"red": [20, 29, 50, 256, 21, 234, 79, 114, 121],
	&"blue": [20, 29, 50, 256, 21, 234, 79, 114, 121],
	&"yellow": [19, 28, 49, 260, 21, 252, 85, 114, 121],
}

## The Power Plant's Voltorbs, Electrodes and Zapdos: an object with the TRAINER
## bit and a byte below `OPP_ID_OFFSET`, which is the only shape a wild one
## takes: six Voltorbs, two Electrodes and Zapdos, as the dex numbers the cache
## stores rather than the internal indexes the cartridge writes.
const POWER_PLANT: int = 83
const POWER_PLANT_WILD: Dictionary = {100: 6, 101: 2, 145: 1}

## `SilphCoElevator_Object`'s two warps name UNUSED_MAP_ED, which has no header:
## the elevator's own script rewrites the destination before either is taken.
const SILPH_CO_ELEVATOR: int = 236

## `NUM_SGB_PALS`, and `PAL_ROUTE`'s own four, the row every route draws in.
const PALETTE_COUNTS: Dictionary = {&"red": 37, &"blue": 37, &"yellow": 40}
const ROUTE_COLORS: Dictionary = {
	&"red": [0x7FBF, 0x2F95, 0x7F54, 0x0843],
	&"blue": [0x7FBF, 0x2F95, 0x7F54, 0x0843],
	&"yellow": [0x7BFF, 0x4F57, 0x7F77, 0x18C6],
}

## Every branch of `SetPal_Overworld`, as map id, `wLastMap` and the row wanted.
## The ids are the same in all three; only the link rooms answer differently.
const PINNED_PALETTES: Array = [
	[0x00, -1, 0x01], [0x0A, -1, 0x0B], [0x0C, -1, 0x00],
	[0x28, 0x00, 0x01], [0x28, 0x0C, 0x00],
	[0x3B, -1, 0x23], [0x8F, -1, 0x19], [0xF7, -1, 0x19],
	[0xE2, -1, 0x23], [0xE4, -1, 0x23], [0xF5, -1, 0x01], [0xF6, -1, 0x23],
]
const LINK_ROOMS: Array[int] = [0xEF, 0xF0]

## What the corpus lands on with no `wLastMap`: eleven cities one each, Lorelei's
## room beside Pallet Town's, twenty caves, the Tower and Agatha grey, and the
## rest the route row. Yellow's extra grey pair is the link rooms.
const PALETTE_CENSUS: Dictionary = {
	&"red": {0: 186, 1: 2, 2: 1, 3: 1, 4: 1, 5: 1, 6: 1, 7: 1, 8: 1, 9: 1, 10: 1,
		11: 1, 25: 8, 35: 20},
	&"blue": {0: 186, 1: 2, 2: 1, 3: 1, 4: 1, 5: 1, 6: 1, 7: 1, 8: 1, 9: 1, 10: 1,
		11: 1, 25: 8, 35: 20},
	&"yellow": {0: 185, 1: 2, 2: 1, 3: 1, 4: 1, 5: 1, 6: 1, 7: 1, 8: 1, 9: 1, 10: 1,
		11: 1, 25: 10, 35: 20},
}

## Every row of `<Map>_TextPointers` the maps' signs and objects reach, by the
## byte that opens it. Yellow's six bare `text_end`s are Jessie and James, whose
## two ids share one on three maps.
const TEXT_CENSUS: Dictionary = {
	&"red": {0x08: 638, 0x17: 528, 0xFF: 12, 0xF6: 12, 0xFE: 14, 0xF5: 3, 0xF7: 3},
	&"blue": {0x08: 638, 0x17: 528, 0xFF: 12, 0xF6: 12, 0xFE: 14, 0xF5: 3, 0xF7: 3},
	&"yellow": {0x08: 691, 0x17: 512, 0xFF: 12, 0xF6: 12, 0xFE: 14, 0x50: 6, 0xF5: 3, 0xF7: 3},
}

## Rows of `script_mart` across the corpus. Yellow's Celadon 5F clerk sells one
## more than Red and Blue's.
const MART_ITEMS: Dictionary = {&"red": 97, &"blue": 97, &"yellow": 98}

## `_MtMoonPokecenterClipboardText`, the corpus's one empty box.
const EMPTY_TEXTS: Dictionary = {&"red": 1, &"blue": 1, &"yellow": 1}

## The `text_asm` rows read as a script, and the nodes under them.
const SCRIPT_CENSUS: Dictionary = {
	&"red": {"rows": 318, "text": 609, "branch": 158, "choice": 41, "flag": 245,
		"give_item": 44, "has_item": 20, "take_item": 11, "unknown": 0, "pokedex": 13,
		"give_pokemon": 33, "saved_coord_index": 1, "badges_byte": 1, "walk": 20,
		"player_facing": 10, "set_map_script": 113, "npc_movement_script": 2,
		"toggle_object": 49, "trainer_battle_object": 21, "random": 5, "facing": 12,
		"player_in_array": 1, "flag_test": 3, "pick_up_item": 105, "scratch": 37,
		"name_badge": 7, "heal_party": 2, "object_facing": 9, "talking_to": 32,
		"set_starter": 9, "name_species": 14, "dex_rating": 2, "dex_count": 2,
		"map_text": 24, "trade": 9, "name_item": 7, "oaks_aide": 3, "player_coord": 4,
		"money_box": 6, "has_money": 4, "spend_money": 4, "menu": 3, "menu_cancel": 3,
		"menu_row": 1, "guard_drink": 4, "day_care": 1, "random_bit": 2, "volatile": 1,
		"filtered_bag": 2, "menu_item": 4, "elevator": 3, "coin_box": 2, "has_coins": 4,
		"add_coins": 4, "replace_block": 1, "starter": 2, "trainer_battle": 3,
		"safari_balls": 1, "safari_steps": 1, "save_coord_index": 2, "map_load_bit": 2,
		"copy_name": 4, "set_fossil": 6, "party_menu": 1, "name_party_mon": 1, "mon_ot": 1,
		"name_mon": 1, "list_menu": 1},
	&"blue": {"rows": 318, "text": 609, "branch": 158, "choice": 41, "flag": 245,
		"give_item": 44, "has_item": 20, "take_item": 11, "unknown": 0, "pokedex": 13,
		"give_pokemon": 33, "saved_coord_index": 1, "badges_byte": 1, "walk": 20,
		"player_facing": 10, "set_map_script": 113, "npc_movement_script": 2,
		"toggle_object": 49, "trainer_battle_object": 21, "random": 5, "facing": 12,
		"player_in_array": 1, "flag_test": 3, "pick_up_item": 105, "scratch": 37,
		"name_badge": 7, "heal_party": 2, "object_facing": 9, "talking_to": 32,
		"set_starter": 9, "name_species": 14, "dex_rating": 2, "dex_count": 2,
		"map_text": 24, "trade": 9, "name_item": 7, "oaks_aide": 3, "player_coord": 4,
		"money_box": 6, "has_money": 4, "spend_money": 4, "menu": 3, "menu_cancel": 3,
		"menu_row": 1, "guard_drink": 4, "day_care": 1, "random_bit": 2, "volatile": 1,
		"filtered_bag": 2, "menu_item": 4, "elevator": 3, "coin_box": 2, "has_coins": 4,
		"add_coins": 4, "replace_block": 1, "starter": 2, "trainer_battle": 3,
		"safari_balls": 1, "safari_steps": 1, "save_coord_index": 2, "map_load_bit": 2,
		"copy_name": 4, "set_fossil": 6, "party_menu": 1, "name_party_mon": 1, "mon_ot": 1,
		"name_mon": 1, "list_menu": 1},
	&"yellow": {"rows": 373, "text": 608, "branch": 160, "choice": 34, "flag": 221,
		"give_item": 41, "has_item": 15, "take_item": 9, "unknown": 5, "pokedex": 10,
		"give_pokemon": 8, "saved_coord_index": 1, "badges_byte": 1, "walk": 23,
		"set_map_script": 99, "npc_movement_script": 2, "toggle_object": 22,
		"trainer_battle_object": 27, "random": 5, "facing": 12, "player_in_array": 1,
		"name_species": 7, "flag_test": 6, "pick_up_item": 109, "scratch": 29,
		"name_badge": 7, "player_facing": 15, "heal_party": 2, "emote": 7, "dex_rating": 2,
		"dex_count": 6, "map_text": 24, "trade": 7, "name_item": 7, "oaks_aide": 3,
		"player_coord": 4, "money_box": 6, "has_money": 5, "spend_money": 4, "menu": 3,
		"menu_cancel": 3, "menu_row": 1, "guard_drink": 4, "day_care": 1, "random_bit": 2,
		"volatile": 1, "filtered_bag": 2, "menu_item": 4, "elevator": 3, "coin_box": 2,
		"has_coins": 4, "add_coins": 4, "replace_block": 1, "trainer_battle": 1,
		"safari_balls": 3, "safari_steps": 3, "safari_admission": 2, "save_coord_index": 2,
		"map_load_bit": 2, "talking_to": 14, "volatile_test": 6, "copy_name": 4,
		"set_fossil": 6, "party_menu": 1, "name_party_mon": 1, "mon_ot": 1, "name_mon": 1,
		"list_menu": 1},
}
## `SilphCo11FPorygonText` is a `call DisplayPokedex` the disassembly marks
## unreferenced. The `trade` rows are the eight `predef DoInGameTradeDialogue`
## sites plus `CinnabarLabTradeRoom`'s second, whose `jr` shares the first's
## tail; Yellow ships neither trade house.

const ELEVATOR_MAPS: Array[int] = [127, 203, 236]
const ELEVATOR_FLOORS: int = 19

## `ToggleableObjectStates` as the corpus carries it: the objects a row lands on
## and how many start ON. Three rows name an object their map has not got.
const TOGGLE_CENSUS: Dictionary = {
	&"red": {"objects": 226, "on": 194},
	&"blue": {"objects": 226, "on": 194},
	&"yellow": {"objects": 233, "on": 195},
}

## One row of each list stands on UNUSED_MAP_6F, which has no header and so no
## record: the table holds 217 rows on Red and Blue and 213 on Yellow.
const HIDDEN_CENSUS: Dictionary = {
	&"red": {"rows": 216, "silent": 49, "text": 234, "branch": 111, "flag": 72,
		"facing": 62, "name_item": 53, "give_item": 53, "facility": 21,
		"badge": 14, "has_item": 12, "add_coins": 12, "has_coins": 12,
		"map_text": 5, "choice": 9, "unknown": 1, "dex_count": 1, "gym_trash": 15, "scratch": 12, "map_load_bit": 6, "replace_block": 72},
	&"blue": {"rows": 216, "silent": 49, "text": 234, "branch": 111, "flag": 72,
		"facing": 62, "name_item": 53, "give_item": 53, "facility": 21,
		"badge": 14, "has_item": 12, "add_coins": 12, "has_coins": 12,
		"map_text": 5, "choice": 9, "unknown": 1, "dex_count": 1, "gym_trash": 15, "scratch": 12, "map_load_bit": 6, "replace_block": 72},
	&"yellow": {"rows": 212, "silent": 48, "text": 236, "branch": 112, "flag": 73,
		"facing": 58, "name_item": 54, "give_item": 54, "facility": 17,
		"badge": 14, "has_item": 12, "add_coins": 12, "has_coins": 12,
		"map_text": 5, "choice": 9, "unknown": 1, "dex_count": 1, "gym_trash": 15, "scratch": 12, "volatile": 12, "map_load_bit": 6, "replace_block": 72},
}
## Of `BookshelfTileIDs`' 17 rows, all but one decode: the Indigo Plateau
## statues read `wXCoord` for which of their two boxes they answer with.
const BOOKSHELF_COUNTS: Dictionary = {&"red": 16, &"blue": 16, &"yellow": 16}
const CARD_KEY_FLOORS: int = 10
## `gated` is every map `wCurrentMapScriptFlags` changes the script of, `walks`
## its load-time walks, and `blocks` the writes on the walk `EnterMap` runs.
const CALLBACK_CENSUS: Dictionary = {
	&"red": {"gated": 30, "walks": 63, "blocks": 117, "doors": 20, "floors": 10},
	&"blue": {"gated": 30, "walks": 63, "blocks": 117, "doors": 20, "floors": 10},
	&"yellow": {"gated": 29, "walks": 61, "blocks": 114, "doors": 20, "floors": 10},
}

## The maps with a state machine, the states reachable from index 0 and from
## every `set_map_script` already read, and the bodies the walker gets whole.
const STATE_CENSUS: Dictionary = {
	&"red": {"tables": 98, "states": 373, "read": 183, "branch": 71, "player_coord": 53,
		"player_facing": 58, "flag": 264, "set_map_script": 313, "save_coord_index": 9,
		"map_text": 142, "toggle_object": 155, "object_facing": 75, "set_player_coord": 1,
		"object_path": 2, "movement_running": 70, "npc_movement_script": 1,
		"movement_script_running": 4, "flag_test": 15, "walk": 41, "badges_byte": 1,
		"wild_battle": 4, "player_in_array": 31, "object_position": 20, "object_move": 67,
		"riding": 4, "coord_index": 18, "starter": 22, "trainer_battle": 30,
		"battle_outcome": 34, "object_stay": 12, "facing": 3, "has_item": 4, "emote": 2,
		"saved_coord_index": 16, "badge_guards": 1, "scratch_test": 4, "set_starter": 3,
		"name_species": 3, "heal_party": 2, "scratch": 13, "give_item": 9,
		"arrow_movement": 3, "guard_drink": 4, "boulder_on": 3, "map_load_bit": 10,
		"hall_of_fame": 1, "set_blackout_map": 1, "save_game": 1, "reset_game": 1,
		"object_coord_move": 1, "warp_to": 1, "set_last_map": 1, "safari_balls": 1,
		"set_riding": 1, "replace_block": 24, "volatile": 1, "volatile_test": 1,
		"coord_lookup": 3, "trainer_battle_object": 1},
	&"blue": {"tables": 98, "states": 373, "read": 183, "branch": 71, "player_coord": 53,
		"player_facing": 58, "flag": 264, "set_map_script": 313, "save_coord_index": 9,
		"map_text": 142, "toggle_object": 155, "object_facing": 75, "set_player_coord": 1,
		"object_path": 2, "movement_running": 70, "npc_movement_script": 1,
		"movement_script_running": 4, "flag_test": 15, "walk": 41, "badges_byte": 1,
		"wild_battle": 4, "player_in_array": 31, "object_position": 20, "object_move": 67,
		"riding": 4, "coord_index": 18, "starter": 22, "trainer_battle": 30,
		"battle_outcome": 34, "object_stay": 12, "facing": 3, "has_item": 4, "emote": 2,
		"saved_coord_index": 16, "badge_guards": 1, "scratch_test": 4, "set_starter": 3,
		"name_species": 3, "heal_party": 2, "scratch": 13, "give_item": 9,
		"arrow_movement": 3, "guard_drink": 4, "boulder_on": 3, "map_load_bit": 10,
		"hall_of_fame": 1, "set_blackout_map": 1, "save_game": 1, "reset_game": 1,
		"object_coord_move": 1, "warp_to": 1, "set_last_map": 1, "safari_balls": 1,
		"set_riding": 1, "replace_block": 24, "volatile": 1, "volatile_test": 1,
		"coord_lookup": 3, "trainer_battle_object": 1},
	&"yellow": {"tables": 98, "states": 408, "read": 223, "branch": 123, "player_coord": 79,
		"flag": 301, "player_facing": 63, "set_map_script": 369, "save_coord_index": 15,
		"map_text": 174, "object_position": 12, "toggle_object": 181, "object_facing": 85,
		"set_player_coord": 1, "object_path": 2, "movement_running": 81, "wild_battle": 6,
		"npc_movement_script": 1, "movement_script_running": 4, "flag_test": 20,
		"walk": 55, "badges_byte": 6, "object_move": 93, "player_in_array": 38,
		"riding": 4, "coord_index": 18, "trainer_battle": 17, "battle_outcome": 38,
		"object_stay": 17, "facing": 4, "has_item": 4, "emote": 2, "saved_coord_index": 18,
		"starter": 1, "set_starter": 4, "badge_guards": 1, "name_species": 1,
		"heal_party": 3, "give_item": 9, "arrow_movement": 3, "guard_drink": 4,
		"volatile_test": 3, "volatile": 8, "random": 1, "boulder_on": 3,
		"map_load_bit": 10, "hall_of_fame": 1, "set_blackout_map": 1, "save_game": 1,
		"reset_game": 1, "warp_to": 1, "set_last_map": 1, "safari_balls": 1,
		"set_riding": 1, "scratch_test": 3, "scratch": 8, "replace_block": 36,
		"coord_lookup": 3, "trainer_battle_object": 2},
}

## The pin on which way a `wCurrentMenuItem` branch reads.
const LAVENDER_TOWN: int = 4
const GHOST_GIRL_TEXT: int = 1
const GHOST_GIRL_BOXES: Array[String] = [
	"Do you believe in\nGHOSTs?",
	"Really? So there\nare believers...",
	"Hahaha, I guess\nnot." + Gen2TextStream.PAGE_BREAK + "That white hand\non your shoulder,"
		+ Gen2TextStream.SCROLL_BREAK + "it's not real.",
]

## `NUM_SPRITES` and `FIRST_STILL_SPRITE`, with `SpriteSheetPointerTable`'s
## first row: `RedSprite`, $C0 bytes in bank $05.
const SPRITE_COUNTS: Dictionary = {&"red": 72, &"blue": 72, &"yellow": 82}
const SPRITE_STILL_FIRST: Dictionary = {&"red": 0x3D, &"blue": 0x3D, &"yellow": 0x47}
const PLAYER_SPRITE: Array = [0x4180, 0x05]
const PLAYER_SPRITE_YELLOW: Array = [0x4571, 0x05]
## `RedBikeSprite`, which no row of that table names: the walking strip
## `INCBIN`'d in front of `RedSprite`'s, cached one picture id past the last.
const BIKE_SPRITE_BYTES: int = 0x180

## `BikeRidingTilesets` and `ForcedBikeOrSurfMaps` as map to its cells. Route
## 16's and Route 18's four force the bike, Seafoam Islands B3F's and B4F's
## force surfing, and `IsBikeRidingAllowed` answers yes on 63 real maps of every
## cartridge, counted from pret's own `data/maps/headers`.
const BIKE_RIDING_TILESETS: Array[int] = [0, 3, 11, 14, 17]
const FORCED_RIDES: Dictionary = {
	27: [[17, 10], [17, 11]], 29: [[33, 8], [33, 9]],
	161: [[18, 7], [19, 7]], 162: [[4, 14], [5, 14]],
}
const BIKE_ALLOWED_MAPS: int = 63
## Route 16 Gate 1F and Route 18 Gate 1F, the only two scripts opening on
## `res BIT_ALWAYS_ON_BIKE, [hl]`.
const BIKE_GATE_MAPS: Array[int] = [186, 190]

## `Route12SnorlaxFluteCoords` and `Route16SnorlaxFluteCoords`: the four cells
## around Route 12's Snorlax and the two either side of Route 16's.
const SNORLAX_FLUTE_CELLS: Dictionary = {
	23: [[10, 61], [9, 62], [11, 62], [10, 63]],
	27: [[25, 10], [27, 10]],
}

## Every `IsPlayerOnDungeonWarp` caller of the corpus, source map to its holes:
## the `dbmapcoord`, the map it drops onto and the `DungeonWarpData` tile it
## lands on. Victory Road 3F's first row is the boulder switch, which
## `DungeonWarpList` names no pair for.
const DUNGEON_HOLES: Dictionary = {
	192: [[6, 17, 159, 7, 18], [6, 24, 159, 7, 23]],
	159: [[6, 18, 160, 7, 19], [6, 23, 160, 7, 22]],
	160: [[6, 19, 161, 7, 18], [6, 22, 161, 7, 19]],
	161: [[16, 3, 162, 14, 4], [16, 6, 162, 14, 5]],
	198: [[5, 3, 194, -1, -1], [15, 23, 194, 16, 22]],
	215: [[14, 16, 165, 14, 16], [14, 17, 165, 14, 16], [14, 19, 214, 14, 18]],
}
## `EscapeRopeTilesets` and `SafariZoneRestHouses`, the two lists the rope and
## `SetLastBlackoutMap` walk.
const ESCAPE_ROPE_TILESETS: Array[int] = [3, 15, 17, 22, 16]
const REST_HOUSES: Array[int] = [223, 224, 225]

var _r: RefCounted = null
var _font: Gen2Font = null
var _maps: Dictionary = {}
var _movements: Array[int] = []


func run(r: RefCounted) -> void:
	_r = r
	r.each_game_of(RomRegistry.GEN1, _one_game)


func _one_game() -> void:
	_maps = {}
	for map: Gen2WorldMap in _r.data.world_maps():
		_maps[map.number] = map
	_counts()
	_tilesets()
	_pallet_town()
	_geometry()
	_movements = []
	_movements.resize(MOVEMENTS.size())
	_events()
	_r.check(_movements == MOVEMENT_CENSUS[_r.game_id],
		"the movement census reads %s." % str(_movements))
	_texts()
	_map_callbacks()
	_map_states()
	_hidden_events()
	_elevators()
	_dungeon_warps()
	_bike()
	_snorlax_flute()
	_toggleables()
	_wild_objects()
	_palettes()
	_sprites()
	_safari()
	_cinnabar_gate_corpus()


func _counts() -> void:
	var wanted: int = int(MAP_COUNTS[_r.game_id])
	if not _r.check(_maps.size() == wanted, "the cache holds %d maps, wanted %d." % [
		_maps.size(), wanted,
	]):
		return
	for map_id: int in Gen1Layout.UNUSED_MAPS:
		_r.check(not _maps.has(map_id), "unused map $%02X decoded to a record." % map_id)
	var census: Dictionary = {"warps": 0, "signs": 0, "objects": 0, "connections": 0,
		"items": 0, "trainers": 0}
	for map: Gen2WorldMap in _maps.values():
		census["warps"] += (map.events["warps"] as Array).size()
		census["signs"] += (map.events["bg_events"] as Array).size()
		census["connections"] += map.connections.size()
		for object: Dictionary in map.events["objects"] as Array:
			census["objects"] += 1
			census["items"] += 1 if object.has("item") else 0
			census["trainers"] += 1 if object.has("trainer_class") else 0
	var pinned: Dictionary = CENSUS[_r.game_id]
	for key: String in pinned:
		_r.check(census[key] == int(pinned[key]), "the corpus holds %d %s, pinned %d." % [
			census[key], key, int(pinned[key]),
		])
	_r.note("gen1 maps %s" % census)


## `IsPlayerOnDungeonWarp` over the whole corpus: the six maps that call it and
## nothing else, each hole answering with the tile `.matchedDungeonWarpID` copies.
func _dungeon_warps() -> void:
	_r.check(
		Array(_r.data.gen1_special_warp_list("escape_rope_tilesets")) == ESCAPE_ROPE_TILESETS,
		"EscapeRopeTilesets reads %s." % str(_r.data.gen1_special_warp_list("escape_rope_tilesets"))
	)
	_r.check(
		Array(_r.data.gen1_special_warp_list("rest_houses")) == REST_HOUSES,
		"SafariZoneRestHouses reads %s." % str(_r.data.gen1_special_warp_list("rest_houses"))
	)
	var holes: int = 0
	for map: Gen2WorldMap in _maps.values():
		var rows: Array = map.events.get("dungeon_holes", [])
		if not _r.check(
			rows.is_empty() != DUNGEON_HOLES.has(map.number),
			"map %d decoded %d dungeon holes." % [map.number, rows.size()]
		) or rows.is_empty():
			continue
		_dungeon_holes_of(map, rows)
		holes += rows.size()
	_r.note("gen1 dungeon holes %d over %d maps" % [holes, DUNGEON_HOLES.size()])


func _dungeon_holes_of(map: Gen2WorldMap, rows: Array) -> void:
	var pinned: Array = DUNGEON_HOLES[map.number]
	if not _r.check(rows.size() == pinned.size(), "map %d holds %d holes, pinned %d." % [
		map.number, rows.size(), pinned.size(),
	]):
		return
	for index: int in rows.size():
		var hole: Dictionary = rows[index]
		var want: Array = pinned[index]
		var landing: Dictionary = _r.data.gen1_dungeon_warp(
			int(hole["destination"]), index + 1
		)
		_r.check(
			[int(hole["y"]), int(hole["x"]), int(hole["destination"])] == want.slice(0, 3),
			"map %d hole %d reads (%d, %d) to map %d." % [
				map.number, index + 1, int(hole["y"]), int(hole["x"]),
				int(hole["destination"]),
			]
		)
		var got: Array = [-1, -1] if landing.is_empty() \
			else [int(landing["y"]), int(landing["x"])]
		_r.check(got == want.slice(3), "map %d hole %d lands at %s, pinned %s." % [
			map.number, index + 1, str(got), str(want.slice(3)),
		])
		if landing.is_empty():
			continue
		_r.check(
			_dungeon_landing_stands(int(hole["destination"]), landing),
			"map %d hole %d lands off map %d." % [
				map.number, index + 1, int(hole["destination"]),
			]
		)


## Nothing checks the landing cell, so a tile the destination cannot stand on
## would strand the player. The four Seafoam falls land on `CheckForceBikeOrSurf`'s water.
func _dungeon_landing_stands(number: int, landing: Dictionary) -> bool:
	var map: Gen2WorldMap = _maps.get(number, null)
	if map == null:
		return false
	var cell := Vector2i(int(landing["x"]), int(landing["y"]))
	if cell.x < 0 or cell.y < 0 \
		or cell.x >= map.collision_width or cell.y >= map.collision_height:
		return false
	var tile: int = map.collision_at(cell.x, cell.y)
	var tileset: Gen2WorldTileset = _r.data.world_tileset(map.tileset)
	return tileset != null \
		and (tileset.tile_passable(tile) or tile == Gen1Layout.WATER_TILE)


func _tilesets() -> void:
	var wanted: int = int(TILESET_COUNTS[_r.game_id])
	if not _r.check(_r.data.world_tileset_count() == wanted,
		"the cache holds %d tilesets, wanted %d." % [_r.data.world_tileset_count(), wanted]):
		return
	var blocks: Array[int] = Gen1Layout.tileset_blocks(_r.game_id)
	for number: int in wanted:
		var tileset: Gen2WorldTileset = _r.data.world_tileset(number)
		if not _r.check(tileset != null, "tileset %d is missing." % number):
			continue
		_r.check(tileset.block_count == blocks[number],
			"tileset %d holds %d blocks, pinned %d." % [number, tileset.block_count, blocks[number]])
		_r.check(
			tileset.meta.size() == tileset.block_count * Gen1Layout.TILESET_BLOCK_TILES,
			"tileset %d's blockset is %d bytes for %d blocks." % [
				number, tileset.meta.size(), tileset.block_count,
			]
		)
		_r.check(tileset.tile_count == Gen1Layout.TILESET_TILE_COUNT,
			"tileset %d loads %d tiles, wanted %d." % [
				number, tileset.tile_count, Gen1Layout.TILESET_TILE_COUNT,
			])
		_r.check(not tileset.passable_tiles.is_empty(),
			"tileset %d lists no passable tile." % number)
		_r.check(
			_r.data.world_tileset_indices(number).size()
			== tileset.tile_count * PokeTiles.TILE_PIXELS,
			"tileset %d's graphics strip is the wrong size." % number
		)
	var overworld: Gen2WorldTileset = _r.data.world_tileset(OVERWORLD_TILESET)
	_r.check(overworld.block_count == OVERWORLD_BLOCKS and overworld.grass_tile == OVERWORLD_GRASS
		and overworld.animation == OVERWORLD_ANIMATION and overworld.water,
		"the overworld tileset reads %d blocks, grass $%02X, animation %d, water %s." % [
			overworld.block_count, overworld.grass_tile, overworld.animation, overworld.water,
		])
	_r.check(Array(overworld.passable_tiles) == OVERWORLD_PASSABLE,
		"Overworld_Coll reads %s." % [Array(overworld.passable_tiles)])


func _pallet_town() -> void:
	var map: Gen2WorldMap = _maps.get(PALLET_TOWN, null)
	if not _r.check(map != null, "Pallet Town is missing."):
		return
	_r.check(
		map.width_blocks == PALLET_WIDTH and map.height_blocks == PALLET_HEIGHT
		and map.tileset == OVERWORLD_TILESET and map.border_block == PALLET_BORDER
		and map.music == PALLET_MUSIC,
		"Pallet Town reads %dx%d, tileset %d, border $%02X, music %d." % [
			map.width_blocks, map.height_blocks, map.tileset, map.border_block, map.music,
		]
	)
	_r.check(Array(map.blocks) == PALLET_BLOCKS, "Pallet Town's blocks differ from PalletTown.blk.")
	_r.check(_rows(map.events["warps"], ["x", "y", "map_number", "destination"]) == PALLET_WARPS,
		"Pallet Town's warps read %s." % [_rows(map.events["warps"], ["x", "y", "map_number", "destination"])])
	_r.check(_rows(map.events["bg_events"], ["x", "y", "text"]) == PALLET_SIGNS,
		"Pallet Town's signs read %s." % [_rows(map.events["bg_events"], ["x", "y", "text"])])
	_r.check(
		_rows(map.connections, ["direction", "map_number", "y_alignment"]) == PALLET_CONNECTIONS,
		"Pallet Town's connections read %s." % [
			_rows(map.connections, ["direction", "map_number", "y_alignment"]),
		]
	)
	## `text/PalletTown.asm` as pret writes it: the town sign's `cont` is a
	## scroll and the two house signs keep the names a print fills in.
	var pinned: Array[String] = [
		"OAK POKéMON\nRESEARCH LAB",
		"PALLET TOWN\nShades of your%sjourney await!" % Gen2TextStream.SCROLL_BREAK,
		"<PLAYER>'s house ",
		"<RIVAL>'s house ",
	]
	for index: int in pinned.size():
		var text: String = String(map.text_at(index + 4).get("text", ""))
		_r.check(text == pinned[index], "Pallet Town's text %d reads %s." % [index + 4, text])


## Every decoded text in the corpus: what each row opens with, and that every
## character of a box draws a tile. `FontGraphics` is blank from $c0 to $df, so a
## code from the wrong generation's codec is a hole rather than a wrong letter.
func _texts() -> void:
	var font: Gen2Font = Gen2Font.from_data(_r.data)
	_font = font
	if not _r.check(font != null, "the cache has no font."):
		return
	var census: Dictionary = {}
	var empty: int = 0
	var blank: Array[String] = []
	for map: Gen2WorldMap in _maps.values():
		for row: Dictionary in map.texts:
			var command: int = int(row["command"])
			census[command] = int(census.get(command, 0)) + 1
			var text: String = String(row.get("text", ""))
			if text.is_empty():
				empty += 1 if command in [Gen1Text.TEXT_FAR, Gen1Text.TEXT_START] else 0
				continue
			for line: String in text.split("\n"):
				if not _drawn(font, line) and blank.size() < 4:
					blank.append("map %d: %s" % [map.number, line])
	_r.check(blank.is_empty(), "texts draw a blank tile: %s." % [blank])
	_r.check(census == TEXT_CENSUS[_r.game_id], "the text rows read %s." % [census])
	_r.check(empty == int(EMPTY_TEXTS[_r.game_id]),
		"%d texts decoded to nothing, pinned %d." % [empty, int(EMPTY_TEXTS[_r.game_id])])
	_r.note("gen1 texts %s" % [census])
	_scripts(font)
	_marts()


## Every `text_asm` row the importer read as a script. What is pinned is not the
## count alone but the shape: a branch's flag has to be one `wEventFlags` holds,
## every box has to draw, and the ghost girl has to keep both her answers.
func _scripts(font: Gen2Font) -> void:
	var census: Dictionary = {"rows": 0, "text": 0, "branch": 0, "choice": 0,
		"flag": 0, "give_item": 0, "has_item": 0, "take_item": 0, "unknown": 0,
		"pokedex": 0, "give_pokemon": 0}
	var wrong: Array[String] = []
	for map: Gen2WorldMap in _maps.values():
		for row: Dictionary in map.texts:
			var script: Array = row.get("script", [])
			if script.is_empty():
				continue
			census["rows"] = int(census["rows"]) + 1
			_walk_script(font, script, census, wrong, map.number)
	_r.check(wrong.is_empty(), "script nodes are wrong: %s." % [wrong])
	_r.check(census == SCRIPT_CENSUS[_r.game_id], "the row scripts read %s." % [census])
	_r.note("gen1 scripts %s" % [census])
	_ghost_girl()


func _map_callbacks() -> void:
	var census: Dictionary = {
		"gated": 0, "walks": 0, "blocks": 0, "doors": 0, "floors": 0,
	}
	var wrong: Array[String] = []
	for map: Gen2WorldMap in _maps.values():
		var doors: Array = map.events["card_key"] as Array
		census["floors"] += 1 if not doors.is_empty() else 0
		census["doors"] += doors.size()
		_check_doors(map, doors, wrong)
		var callbacks: Array = map.scripts["callbacks"] as Array
		if callbacks.is_empty():
			continue
		census["gated"] += 1
		census["walks"] += callbacks.size()
		for callback: Dictionary in callbacks:
			_r.check(not (callback["nodes"] as Array).is_empty(),
				"map %d keeps an empty walk for mask %d." % [map.number, int(callback["mask"])])
			if int(callback["mask"]) == Gen1Layout.MAP_LOAD_BOTH:
				census["blocks"] += _blocks_written(callback["nodes"] as Array)
	_r.check(wrong.is_empty(), "card key doors are wrong: %s." % [wrong])
	_r.check(census == CALLBACK_CENSUS[_r.game_id],
		"the map callbacks read %s." % [census])
	_r.note("gen1 map callbacks %s" % [census])


## `RunMapScript`'s own half, swept over the corpus.
func _map_states() -> void:
	var census: Dictionary = {"tables": 0, "states": 0, "read": 0}
	var wrong: Array[String] = []
	for map: Gen2WorldMap in _maps.values():
		var entry: Array = map.scripts["entry"] as Array
		var dispatch: Dictionary = _dispatch_node(entry)
		var states: Array = map.scripts["states"] as Array
		if dispatch.is_empty():
			_r.check(states.is_empty(),
				"map %d holds states with no dispatch." % map.number)
			continue
		census["tables"] += 1
		census["states"] += states.size()
		for row: Dictionary in states:
			var nodes: Array = row["nodes"] as Array
			census["read"] += 1 if not nodes.is_empty() else 0
			_walk_script(_font, nodes, census, wrong, map.number)
	_r.check(wrong.is_empty(), "state nodes are wrong: %s." % [wrong])
	_r.check(census == STATE_CENSUS[_r.game_id], "the map states read %s." % [census])
	_r.note("gen1 map states %s" % [census])


func _dispatch_node(nodes: Array) -> Dictionary:
	for node: Dictionary in nodes:
		if String(node["op"]) == "map_script_table":
			return node
		for key: String in Gen1Layout.SCRIPT_BRANCH_KEYS:
			if not node.has(key):
				continue
			var found: Dictionary = _dispatch_node(node[key] as Array)
			if not found.is_empty():
				return found
	return {}


func _node_count(nodes: Array) -> int:
	var total: int = nodes.size()
	for node: Dictionary in nodes:
		for key: String in Gen1Layout.SCRIPT_BRANCH_KEYS:
			if node.has(key):
				total += _node_count(node[key] as Array)
	return total


func _blocks_written(nodes: Array) -> int:
	var written: int = 0
	for node: Dictionary in nodes:
		written += 1 if String(node["op"]) == "replace_block" else 0
		for side: String in ["then", "else"]:
			if node.has(side):
				written += _blocks_written(node[side] as Array)
	return written


## A floor's doors each stand under their own flag, on a cell the load walk locks.
func _check_doors(map: Gen2WorldMap, doors: Array, wrong: Array[String]) -> void:
	var flags: Dictionary = {}
	var locked: Dictionary = {}
	for callback: Dictionary in map.scripts["callbacks"] as Array:
		if int(callback["mask"]) == Gen1Layout.MAP_LOAD_BOTH:
			_locked_cells(callback["nodes"] as Array, locked)
	for door: Dictionary in doors:
		flags[int(door["flag"])] = true
		if not locked.has(Vector2i(int(door["x"]), int(door["y"]))) and wrong.size() < 4:
			wrong.append("map %d's door at %d,%d is never locked by its load walk" % [
				map.number, int(door["x"]), int(door["y"]),
			])
	if flags.size() != doors.size() and wrong.size() < 4:
		wrong.append("map %d has %d doors under %d flags" % [
			map.number, doors.size(), flags.size(),
		])


func _locked_cells(nodes: Array, locked: Dictionary) -> void:
	for node: Dictionary in nodes:
		if String(node["op"]) == "replace_block":
			locked[Vector2i(int(node["x"]), int(node["y"]))] = true
		for side: String in ["then", "else"]:
			if node.has(side):
				_locked_cells(node[side] as Array, locked)


func _walk_script(
	font: Gen2Font, nodes: Array, census: Dictionary, wrong: Array[String], number: int
) -> void:
	for node: Dictionary in nodes:
		var op: String = String(node["op"])
		census[op] = int(census.get(op, 0)) + 1
		if op == "text" and not _drawn(font, String(node["text"]).replace("\n", "")) \
			and wrong.size() < 4:
			wrong.append("map %d draws a blank tile" % number)
		if node.has("flag") and op in ["flag", "branch", "flag_test"]:
			var flag: int = int(node["flag"])
			if (flag < 0 or flag >= Gen1Layout.EVENT_FLAG_BYTES * 8) and wrong.size() < 4:
				wrong.append("map %d names flag %d" % [number, flag])
		## A marker below zero is a row only the runtime resolves to an item.
		if (op == "give_item" or op == "has_item" or op == "take_item") \
			and int(node["item"]) >= 0:
			_r.check(not _r.data.item_name(int(node["item"])).is_empty(),
				"map %d names item %d, which has no name." % [number, int(node["item"])])
		for side: String in Gen1Layout.SCRIPT_BRANCH_KEYS:
			if node.has(side):
				_walk_script(font, node[side] as Array, census, wrong, number)


func _elevators() -> void:
	var floors: int = 0
	var maps: Array[int] = []
	var wrong: Array[String] = []
	for map: Gen2WorldMap in _maps.values():
		for row: Dictionary in map.texts:
			for node: Dictionary in _elevator_nodes(row.get("script", []) as Array):
				maps.append(map.number)
				floors += _elevator_rows(map.number, node["floors"] as Array, wrong)
	maps.sort()
	_r.check(wrong.is_empty(), "elevator floors are wrong: %s." % [wrong])
	_r.check(maps == ELEVATOR_MAPS, "the elevator maps read %s." % [maps])
	_r.check(floors == ELEVATOR_FLOORS,
		"the elevators offer %d floors, pinned %d." % [floors, ELEVATOR_FLOORS])
	_r.note("gen1 elevators %d over %d maps" % [floors, maps.size()])


func _elevator_nodes(nodes: Array) -> Array:
	var out: Array = []
	for node: Dictionary in nodes:
		if String(node.get("op", "")) == "elevator":
			out.append(node)
		for side: String in Gen1Layout.SCRIPT_BRANCH_KEYS:
			if node.has(side):
				out.append_array(_elevator_nodes(node[side] as Array))
	return out


func _elevator_rows(number: int, rows: Array, wrong: Array[String]) -> int:
	for row: Dictionary in rows:
		if wrong.size() >= 4:
			break
		var landing: Gen2WorldMap = _maps.get(int(row["map"]), null)
		if _r.data.item_name(int(row["floor"])).is_empty():
			wrong.append("map %d names floor %d" % [number, int(row["floor"])])
		elif landing == null:
			wrong.append("map %d rides to map %d" % [number, int(row["map"])])
		elif int(row["warp"]) >= (landing.events["warps"] as Array).size():
			wrong.append("map %d rides to warp %d of map %d" % [
				number, int(row["warp"]), int(row["map"]),
			])
	return rows.size()


## Every `hidden_event` row of the corpus, the nodes behind it and the bookshelf
## tiles the A button falls through to. `silent` counts the rows whose routine is
## a screen this port has no counterpart for.
func _hidden_events() -> void:
	var census: Dictionary = {"rows": 0, "silent": 0}
	var wrong: Array[String] = []
	var bookshelves: int = 0
	var card_keys: int = 0
	for map: Gen2WorldMap in _maps.values():
		card_keys += 1 if not (map.events["card_key"] as Array).is_empty() else 0
		for row: Dictionary in map.events["hidden_events"] as Array:
			census["rows"] = int(census["rows"]) + 1
			var script: Array = row.get("script", [])
			if script.is_empty():
				census["silent"] = int(census["silent"]) + 1
				continue
			_walk_hidden(script, census, wrong, map.number)
	for number: int in _r.data.world_tileset_count():
		bookshelves += (_r.data.world_tileset(number).bookshelves as Dictionary).size()
	_r.check(wrong.is_empty(), "hidden event nodes are wrong: %s." % [wrong])
	_r.check(census == HIDDEN_CENSUS[_r.game_id], "the hidden events read %s." % [census])
	_r.check(bookshelves == int(BOOKSHELF_COUNTS[_r.game_id]),
		"%d bookshelf tiles decoded, pinned %d." % [
			bookshelves, int(BOOKSHELF_COUNTS[_r.game_id]),
		])
	_r.check(card_keys == CARD_KEY_FLOORS,
		"%d floors carry the card key door, pinned %d." % [card_keys, CARD_KEY_FLOORS])
	_r.note("gen1 hidden events %s, %d bookshelf tiles" % [census, bookshelves])


func _walk_hidden(
	nodes: Array, census: Dictionary, wrong: Array[String], number: int
) -> void:
	for node: Dictionary in nodes:
		var op: String = String(node["op"])
		census[op] = int(census.get(op, 0)) + 1
		if op == "facing" and not Gen1Layout.FACING_STEPS.has(int(node["facing"])) \
			and wrong.size() < 4:
			wrong.append("map %d faces %d" % [number, int(node["facing"])])
		if op == "text" and String(node["text"]).is_empty() and wrong.size() < 4:
			wrong.append("map %d prints nothing" % number)
		if (op == "give_item" or op == "has_item" or op == "name_item") \
			and _r.data.item_name(int(node["item"])).is_empty():
			wrong.append("map %d names item %d" % [number, int(node["item"])])
		for side: String in Gen1Layout.SCRIPT_BRANCH_KEYS:
			if node.has(side):
				_walk_hidden(node[side] as Array, census, wrong, number)


## `LavenderTownLittleGirlText`: the question, then `wCurrentMenuItem` zero for
## YES. Its `ld hl` between `and a` and the `jr nz` is why a branch is decoded
## off the flags rather than off the instruction in front of it.
func _ghost_girl() -> void:
	var map: Gen2WorldMap = _maps.get(LAVENDER_TOWN)
	if not _r.check(map != null, "Lavender Town is missing."):
		return
	var script: Array = map.text_at(GHOST_GIRL_TEXT).get("script", [])
	if not _r.check(script.size() == 2, "the ghost girl has %d nodes." % script.size()):
		return
	var choice: Dictionary = script[1]
	var read: Array[String] = [
		String((script[0] as Dictionary).get("text", "")),
		String(((choice.get("yes", []) as Array)[0] as Dictionary).get("text", "")),
		String(((choice.get("no", []) as Array)[0] as Dictionary).get("text", "")),
	]
	_r.check(read == GHOST_GIRL_BOXES, "the ghost girl says %s." % [read])


## Every `script_mart` row's inline inventory: `LoadItemList` reads the count out
## of the text pointer itself, so a stride that has slipped shows up as a shelf
## naming an item the cartridge has no name for.
func _marts() -> void:
	var shelves: int = 0
	var items: int = 0
	for map: Gen2WorldMap in _maps.values():
		for row: Dictionary in map.texts:
			if int(row["command"]) != Gen1Layout.TEXT_SCRIPT_MART:
				continue
			var shelf: Array = row.get("items", [])
			shelves += 1
			items += shelf.size()
			if not _r.check(not shelf.is_empty(), "map %d's shop is empty." % map.number):
				continue
			for item: Variant in shelf:
				_r.check(not _r.data.item_name(int(item)).is_empty(),
					"map %d's shop sells item %d, which has no name." % [map.number, int(item)])
	_r.check(shelves == int(TEXT_CENSUS[_r.game_id][Gen1Layout.TEXT_SCRIPT_MART]),
		"%d shops carry an inventory." % shelves)
	_r.check(items == int(MART_ITEMS[_r.game_id]),
		"the shops sell %d items, pinned %d." % [items, int(MART_ITEMS[_r.game_id])])
	_r.note("gen1 shops %d selling %d items" % [shelves, items])


## Whether every code [param line] encodes to has ink behind it.
static func _drawn(font: Gen2Font, line: String) -> bool:
	for code: int in font.encode(line):
		if code == Gen1Text.SPACE \
			or (code >= Gen1Layout.FONT_EXTRA_FIRST_CODE and code <= Gen1Layout.FRAME_LAST_CODE):
			continue
		var inked: bool = false
		for ink: Array in Gen1Layout.FONT_INK_RUNS:
			inked = inked or (code >= int(ink[0]) and code <= int(ink[1]))
		if not inked:
			return false
	return true


static func _rows(events: Array, fields: Array) -> Array:
	var out: Array = []
	for event: Dictionary in events:
		var row: Array = []
		for field: String in fields:
			row.append(event[field])
		out.append(row)
	return out


## Every map's own shape, and that a player has somewhere to stand on it.
func _geometry() -> void:
	for map: Gen2WorldMap in _maps.values():
		var cells: int = map.width_blocks * map.height_blocks * 4
		if not _r.check(
			map.blocks.size() == map.width_blocks * map.height_blocks
			and map.collision.size() == cells,
			"map %d is %dx%d blocks with %d blocks and %d cells." % [
				map.number, map.width_blocks, map.height_blocks,
				map.blocks.size(), map.collision.size(),
			]
		):
			continue
		var tileset: Gen2WorldTileset = _r.data.world_tileset(map.tileset)
		if not _r.check(tileset != null, "map %d names tileset %d." % [map.number, map.tileset]):
			continue
		var walkable: int = 0
		for code: int in map.collision:
			walkable += 1 if tileset.tile_passable(code) else 0
		_r.check(walkable > 0, "map %d has no cell a player can stand on." % map.number)


## The map macros' own assertions, plus the tables an event points into.
func _events() -> void:
	for map: Gen2WorldMap in _maps.values():
		var objects: Array = map.events["objects"]
		for warp: Dictionary in map.events["warps"] as Array:
			var destination: int = int(warp["map_number"])
			if destination == Gen1Layout.WARP_TO_LAST_MAP:
				continue
			if map.number == SILPH_CO_ELEVATOR:
				_r.check(not Gen1Layout.is_real_map(destination),
					"the Silph Co elevator now warps to map %d." % destination)
				continue
			var target: Gen2WorldMap = _maps.get(destination, null)
			if not _r.check(target != null, "map %d warps to map %d, which has no header." % [
				map.number, destination,
			]):
				continue
			_r.check(int(warp["destination"]) < (target.events["warps"] as Array).size(),
				"map %d warps to map %d's warp %d, which it does not have." % [
					map.number, destination, int(warp["destination"]),
				])
		for connection: Dictionary in map.connections:
			var neighbour: Gen2WorldMap = _maps.get(int(connection["map_number"]), null)
			if not _r.check(neighbour != null, "map %d connects %s to map %d, which has no header." % [
				map.number, connection["direction"], int(connection["map_number"]),
			]):
				continue
			_r.check(int(connection["target_width_blocks"]) == neighbour.width_blocks,
				"map %d's %s connection calls map %d %d blocks wide, and it is %d." % [
					map.number, connection["direction"], neighbour.number,
					int(connection["target_width_blocks"]), neighbour.width_blocks,
				])
		for board: Dictionary in map.events["bg_events"] as Array:
			_r.check(int(board["text"]) > objects.size(),
				"map %d has a sign with text id %d over %d objects." % [
					map.number, int(board["text"]), objects.size(),
				])
		for object: Dictionary in objects:
			_object(map, object, objects.size())


func _object(map: Gen2WorldMap, object: Dictionary, object_count: int) -> void:
	var text: int = int(object["text"])
	_r.check(text >= 1 and text <= object_count,
		"map %d has an object with text id %d over %d objects." % [map.number, text, object_count])
	if object.has("trainer_class"):
		var trainer_class: int = int(object["trainer_class"])
		_r.check(trainer_class >= 1 and trainer_class <= _r.data.trainer_count(),
			"map %d has a trainer of class %d." % [map.number, trainer_class])
	if object.has("species"):
		var species: int = int(object["species"])
		_r.check(species >= 1 and species <= Gen1Layout.INDEX_COUNT,
			"map %d has a wild object of species index %d." % [map.number, species])
	if object.has("item"):
		_r.check(_is_item(int(object["item"])),
			"map %d has an item ball holding item %d." % [map.number, int(object["item"])])
	var movement: int = int(object["movement"])
	var slot: int = MOVEMENTS.find(movement)
	if _r.check(slot >= 0, "map %d has an object on movement %d." % [map.number, movement]):
		_movements[slot] += 1


## An item id an item ball can hold: a named item, or one of the machines above
## them. Blue's house carries two zeroes, which the cartridge never reads: both
## objects are people whose event only sets the ITEM bit.
static func _is_item(item: int) -> bool:
	if item == 0:
		return true
	if item <= Gen1Layout.ITEM_COUNT:
		return true
	return item >= Gen1Layout.HM_FIRST_ITEM \
		and item < Gen1Layout.TM_FIRST_ITEM + Gen1Layout.TM_COUNT


## `SuperPalettes` and the row `SetPal_Overworld` hands each map.
func _palettes() -> void:
	var wanted: int = int(PALETTE_COUNTS[_r.game_id])
	var last: PackedColorArray = _r.data.world_palette(wanted - 1)
	if not _r.check(
		_r.data.world_palette(wanted).is_empty() and last.size() == 4,
		"the cache holds %d SGB palettes, wanted %d." % [_palette_count(), wanted]
	):
		return
	var route: Array = []
	for color: Color in _r.data.world_palette(Gen1Layout.PAL_ROUTE):
		route.append(_packed(color))
	_r.check(route == ROUTE_COLORS[_r.game_id], "PAL_ROUTE reads %s." % [route])

	for row: Array in PINNED_PALETTES:
		_pinned_palette(int(row[0]), int(row[1]), int(row[2]))
	# Yellow gives the two link rooms `PAL_GRAYMON` by name; Red and Blue have
	# the same two maps and let them fall through to `wLastMap`.
	var link: int = Gen1Layout.PAL_GRAYMON if _r.game_id == RomRegistry.YELLOW \
		else Gen1Layout.PAL_PALLET
	for map_id: int in LINK_ROOMS:
		_pinned_palette(map_id, 0x00, link)

	var census: Dictionary = {}
	for map: Gen2WorldMap in _maps.values():
		var palette: int = Gen1Layout.overworld_palette(_r.game_id, map.number, map.tileset)
		if not _r.check(palette >= 0 and palette < wanted,
			"map %d draws in SGB palette %d." % [map.number, palette]):
			continue
		census[palette] = int(census.get(palette, 0)) + 1
	var pinned: Dictionary = PALETTE_CENSUS[_r.game_id]
	for palette: int in pinned:
		_r.check(int(census.get(palette, 0)) == int(pinned[palette]),
			"%d maps draw in SGB palette %d, pinned %d." % [
				int(census.get(palette, 0)), palette, int(pinned[palette]),
			])
	_r.check(census.size() == pinned.size(), "the corpus lands on %d palettes, pinned %d." % [
		census.size(), pinned.size(),
	])
	_r.note("gen1 map palettes %s" % census)


func _pinned_palette(map_id: int, last_map: int, wanted: int) -> void:
	var map: Gen2WorldMap = _maps.get(map_id, null)
	if not _r.check(map != null, "map $%02X is missing." % map_id):
		return
	var got: int = Gen1Layout.overworld_palette(_r.game_id, map_id, map.tileset, last_map)
	_r.check(got == wanted, "map $%02X out of map %d draws in palette %d, wanted %d." % [
		map_id, last_map, got, wanted,
	])


## How many rows the cache really holds, for the message when the count is wrong.
func _palette_count() -> int:
	var out: int = 0
	while not _r.data.world_palette(out).is_empty():
		out += 1
	return out


static func _packed(color: Color) -> int:
	return int(round(color.r * 31.0)) | (int(round(color.g * 31.0)) << 5) \
		| (int(round(color.b * 31.0)) << 10)


## `SpriteSheetPointerTable`'s strips, and the picture id every object names.
func _sprites() -> void:
	var wanted: int = int(SPRITE_COUNTS[_r.game_id])
	var still_first: int = int(SPRITE_STILL_FIRST[_r.game_id])
	if not _r.check(_r.data.overworld_sprite_count() == wanted + 1,
		"the cache holds %d overworld sprites, wanted %d." % [
			_r.data.overworld_sprite_count(), wanted + 1,
		]):
		return
	var player: Array = PLAYER_SPRITE_YELLOW if _r.game_id == RomRegistry.YELLOW \
		else PLAYER_SPRITE
	var red: Gen2WorldSprite = _r.data.overworld_sprite(1)
	_r.check(red.address == int(player[0]) and red.bank == int(player[1]),
		"RedSprite reads $%02X:$%04X." % [red.bank, red.address])
	var bike: Gen2WorldSprite = _r.data.overworld_sprite(
		Gen1Layout.bike_sprite(_r.game_id)
	)
	_r.check(bike != null and bike.bank == red.bank \
		and bike.address == red.address - BIKE_SPRITE_BYTES \
		and bike.tiles == Gen1Layout.SPRITE_WALKING_TILES * 2 and bike.is_walking(),
		"RedBikeSprite reads $%02X:$%04X over %d tiles." % [
			bike.bank, bike.address, bike.tiles,
		])
	_r.check(
		_r.data.overworld_sprite_indices(Gen1Layout.bike_sprite(_r.game_id)).size()
			== Gen1Layout.SPRITE_WALKING_TILES * 2 * PokeTiles.TILE_PIXELS,
		"RedBikeSprite's strip is the wrong size."
	)

	var census: Dictionary = {"walking": 0, "still": 0}
	for number: int in range(1, wanted + 1):
		var sprite: Gen2WorldSprite = _r.data.overworld_sprite(number)
		if not _r.check(sprite != null, "sprite %d is missing." % number):
			continue
		var still: bool = number >= still_first
		var tiles: int = Gen1Layout.SPRITE_STILL_TILES if still \
			else Gen1Layout.SPRITE_WALKING_TILES * 2
		census["still" if still else "walking"] += 1
		_r.check(sprite.tiles == tiles and sprite.is_walking() != still,
			"sprite %d holds %d tiles as type %d, wanted %d." % [
				number, sprite.tiles, sprite.sprite_type, tiles,
			])
		_r.check(
			_r.data.overworld_sprite_indices(number).size() == tiles * PokeTiles.TILE_PIXELS,
			"sprite %d's strip is the wrong size." % number
		)
	_r.check(census == {"walking": still_first - 1, "still": wanted - still_first + 1},
		"the sheets read %s." % [census])

	for map: Gen2WorldMap in _maps.values():
		for object: Dictionary in map.events["objects"] as Array:
			var picture: int = int(object["sprite"])
			_r.check(picture >= 1 and picture <= wanted,
				"map %d has an object drawn with picture id %d." % [map.number, picture])


## `res BIT_ALWAYS_ON_BIKE, [hl]` in a map's per-frame script, which reads
## through the shared engine flag `BIKEFLAGS_ALWAYS_ON_BIKE_F` holds.
func _clears_forced_ride(nodes: Array) -> bool:
	for node: Dictionary in nodes:
		if String(node["op"]) == "flag" and bool(node.get("engine", false)) \
			and not bool(node["set"]) \
			and int(node["flag"]) == Gen2WorldState.ENGINE_ALWAYS_ON_BIKE:
			return true
		for key: String in Gen1Layout.SCRIPT_BRANCH_KEYS:
			if node.has(key) and _clears_forced_ride(node[key] as Array):
				return true
	return false


## `IsBikeRidingAllowed`'s two answers, `ForcedBikeOrSurfMaps`' eight cells and
## the two gate scripts that clear a forced ride, over the whole corpus.
func _bike() -> void:
	var tilesets: Array = Array(_r.data.gen1_special_warp_list("bike_riding_tilesets"))
	_r.check(tilesets == BIKE_RIDING_TILESETS,
		"BikeRidingTilesets reads %s." % str(tilesets))
	var allowed: int = 0
	for map: Gen2WorldMap in _maps.values():
		var gate: bool = _clears_forced_ride(map.scripts["entry"] as Array)
		_r.check(gate == BIKE_GATE_MAPS.has(map.number),
			"map %d answers %s to clearing a forced ride." % [map.number, gate])
		if BIKE_RIDING_TILESETS.has(map.tileset) \
			or Gen1Layout.BIKE_ALLOWED_MAPS.has(map.number):
			allowed += 1
		_forced_ride_cells(map)
	_r.check(allowed == BIKE_ALLOWED_MAPS,
		"the bike is allowed on %d maps." % allowed)
	_r.note("gen1 bike allowed on %d maps, forced on %d cells" % [
		allowed, FORCED_RIDES.size() * 2,
	])


func _forced_ride_cells(map: Gen2WorldMap) -> void:
	var hits: Array = []
	for y: int in map.collision_height:
		for x: int in map.collision_width:
			if _r.data.gen1_forces_ride(map.number, Vector2i(x, y)):
				hits.append([x, y])
	_r.check(hits == FORCED_RIDES.get(map.number, []),
		"map %d forces a ride on %s." % [map.number, str(hits)])


## Every cell `ItemUsePokeFlute` answers a Snorlax on, over the whole corpus.
func _snorlax_flute() -> void:
	var found: int = 0
	for map: Gen2WorldMap in _maps.values():
		var hits: Array = []
		for y: int in map.collision_height:
			for x: int in map.collision_width:
				if not _r.data.gen1_snorlax_flute(map.number, Vector2i(x, y)).is_empty():
					hits.append([x, y])
		found += hits.size()
		_r.check(hits == SNORLAX_FLUTE_CELLS.get(map.number, []),
			"map %d wakes a Snorlax on %s." % [map.number, str(hits)])
	_r.note("gen1 poke flute answers on %d cells" % found)


## Every object `ShowObject` and `HideObject` can name: one object a global
## index, and a row under every item and every standing wild.
func _toggleables() -> void:
	var indexes: Dictionary = {}
	var on: int = 0
	var missing: Array[String] = []
	var unreachable: Array[String] = []
	for map: Gen2WorldMap in _maps.values():
		for object: Dictionary in map.events["objects"] as Array:
			## `BluesHouse`'s two ITEM rows carry item 0 and a script of their
			## own; every other item object is picked up by `PickUpItemText`.
			if int(object.get("item", 0)) > 0 and unreachable.size() < 4 and not _has_op(
				map.text_at(int(object.get("text", 0))).get("script", []), "pick_up_item"
			):
				unreachable.append("map %d item %d" % [map.number, int(object["item"])])
			if not object.has("toggle_index"):
				## `PickUpItem` and `EndTrainerBattle` both read
				## `wToggleableObjectList` with no answer for a miss.
				if (object.has("item") or object.has("species")) and missing.size() < 4:
					missing.append("map %d object %d" % [map.number, int(object.get("text", 0))])
				continue
			var index: int = int(object["toggle_index"])
			_r.check(not indexes.has(index), "toggleable index %d is on two objects." % index)
			indexes[index] = true
			on += 1 if bool(object.get("toggle_on", true)) else 0
	_r.check(missing.is_empty(), "no toggleable row reaches %s." % ", ".join(missing))
	_r.check(unreachable.is_empty(),
		"no PickUpItem reaches the item on %s." % ", ".join(unreachable))
	var census: Dictionary = {"objects": indexes.size(), "on": on}
	_r.check(census == TOGGLE_CENSUS[_r.game_id],
		"the toggleable objects read %s." % [census])
	_r.note("gen1 toggleables %s" % [census])


static func _has_op(nodes: Variant, op: String) -> bool:
	if not nodes is Array:
		return false
	for node: Dictionary in nodes as Array:
		if String(node["op"]) == op:
			return true
	return false


func _wild_objects() -> void:
	var map: Gen2WorldMap = _maps.get(POWER_PLANT, null)
	if not _r.check(map != null, "the Power Plant is missing."):
		return
	var species: Dictionary = {}
	for object: Dictionary in map.events["objects"] as Array:
		if object.has("species"):
			species[int(object["species"])] = int(species.get(int(object["species"]), 0)) + 1
	_r.check(species == POWER_PLANT_WILD,
		"the Power Plant's standing wild objects read %s." % [species])


## `SafariZoneGate_ScriptPointers`' seven states, the six rows its texts and its
## states reach, and the two map runs `InitBattleVariables` and
## `PrintSafariZoneSteps` read.
const SAFARI_GATE: int = 0x9C
const SAFARI_STATES: int = 7
const SAFARI_TEXTS: int = 6
const SAFARI_BATTLE_MAPS: int = 4
const SAFARI_WINDOW_MAPS: int = 9
const SAFARI_STEPS_LABEL: String = "/500"
const SAFARI_MENU_TOP: String = "BALL×"


func _safari() -> void:
	var gate: Gen2WorldMap = _maps.get(SAFARI_GATE)
	if not _r.check(gate != null, "the SAFARI ZONE gate has no record."):
		return
	_r.check((gate.scripts["states"] as Array).size() == SAFARI_STATES,
		"the gate reads %d states." % (gate.scripts["states"] as Array).size())
	_r.check(gate.texts.size() == SAFARI_TEXTS,
		"the gate reads %d text rows." % gate.texts.size())
	var battle_maps: int = 0
	var window_maps: int = 0
	for number: int in _maps:
		battle_maps += 1 if Gen1Layout.is_safari_battle_map(number) else 0
		window_maps += 1 if Gen1Layout.is_safari_map(number) else 0
	_r.check(battle_maps == SAFARI_BATTLE_MAPS and window_maps == SAFARI_WINDOW_MAPS,
		"the Safari game covers %d battle maps and %d with the window." % [
			battle_maps, window_maps,
		])
	for row: Array in [
		["safari", "times_up"], ["safari", "game_over"],
		["safari_battle", "eating"], ["safari_battle", "angry"],
		["safari_item", "bait"], ["safari_item", "rock"],
		["safari_labels", "out_of_balls"],
	]:
		_r.check(not _r.data.special_text(String(row[0]), String(row[1])).is_empty(),
			"%s/%s is empty." % row)
	_r.check(_r.data.special_text("safari_labels", "steps") == SAFARI_STEPS_LABEL,
		"the step window reads %s." % _r.data.special_text("safari_labels", "steps"))
	var options: Array[String] = Gen2BattleMenu.safari_options(
		_r.data.special_text("safari_labels", "menu_top"),
		_r.data.special_text("safari_labels", "menu_bottom")
	)
	_r.check(options.size() == 4 and options[0] == SAFARI_MENU_TOP,
		"the Safari battle menu reads %s." % [options])
	_r.note("gen1 safari %d zone maps, %d with the step window, %d gate states" % [
		battle_maps, window_maps, SAFARI_STATES,
	])


func _cinnabar_gate_corpus() -> void:
	var map: Gen2WorldMap = _maps[166]
	var callbacks: Array = map.scripts["callbacks"]
	if not _r.check(not callbacks.is_empty(), "Cinnabar has no map-load callback"):
		return
	var lines := PackedStringArray()
	for mask: int in 128:
		var state := Gen2WorldState.new()
		for bit: int in 7:
			state.set_event_flag(0x2A8 + bit, (mask & (1 << bit)) != 0)
		var world: Gen2WorldAPI = _r.open_world(0, 166, Vector2i(17, 3), state)
		if world == null:
			return
		var steps: Array = world._gen1_script_steps({"script": callbacks[0]["nodes"]})
		var writes := PackedStringArray()
		for step: Dictionary in steps:
			if step["type"] == &"block":
				writes.append("%d,%d,%d" % [step["x"], step["y"], step["block"]])
		lines.append("%d:%s" % [mask, ";".join(writes)])
	var digest: String = ("\n".join(lines) + "\n").sha256_text()
	if _r.check(digest == "69f96f320d03eba9bdd86b113c71276a00ebb5bdc1c1770adc1fcf156214a38a",
		"Cinnabar's 128 gate masks differ from the cartridge's block-write trace: %s" % digest):
		_r.note("gen1 Cinnabar: 128 masks, 768 block writes match the cartridge")
