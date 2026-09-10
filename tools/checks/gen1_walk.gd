extends RefCounted

## Every Generation 1 warp and every ledge, swept on Red, Blue and Yellow. A
## Generation 1 map's collision grid holds the tile a cell draws, so what is
## proved here is the six tables [Gen2WorldCollision] carries for it: the
## tileset's passable list decides a step, `WarpTileIDPointers` and
## `DoorTileIDPointers` decide whether a warp fires, and `LedgeTiles` decides a
## hop. Each is swept against the imported corpus rather than one sampled map.

## `data/maps/objects`' own totals, and the `LAST_MAP` warps inside them.
const WARP_CENSUS: Dictionary = {
	&"red": {"warps": 813, "last_map": 251, "driven": 554, "hops": 758, "edge": 394},
	&"blue": {"warps": 813, "last_map": 251, "driven": 554, "hops": 758, "edge": 394},
	&"yellow": {"warps": 817, "last_map": 253, "driven": 556, "hops": 756, "edge": 397},
}

## `SilphCoElevator_Object`'s two warps name UNUSED_MAP_ED, which has no header;
## its own script rewrites the destination before either is taken.
const SILPH_CO_ELEVATOR: int = 236
## Silph Co. 2F's two card key doors, the block that locks one and the one
## `PrintCardKeyText` opens it with, and the cell below the first.
const SILPH_CO_2F: int = 207
const SILPH_DOOR := Vector2i(2, 2)
const SILPH_SECOND_DOOR := Vector2i(2, 5)
const SILPH_DOOR_APPROACH := Vector2i(4, 5)
const SILPH_LOCKED_BLOCK: int = 0x54
const SILPH_OPEN_BLOCK: int = 0x0E
const CARD_KEY_REFUSED: String = "Darn! It needs a"
const CARD_KEY_OPENED: String = "Bingo!"

const CELADON_MART_1F: int = 122
const CELADON_MART_ELEVATOR: int = 127
const ELEVATOR_DOOR_CELL := Vector2i(1, 1)
const ELEVATOR_DOOR_WARP: int = 5
const ELEVATOR_EXIT_CELL := Vector2i(1, 3)
const ELEVATOR_SIGN_CELL := Vector2i(3, 1)
const ELEVATOR_FLOOR_COUNT: int = 5
const ELEVATOR_CHOSEN_ROW: int = 2

## The warps no facing can fire, as map id and warp index. Every one is a cell
## the player arrives on rather than steps onto: three are pret's own
## `; inaccessible`, four are the upper half of a two-cell gate doorway on
## Routes 7 and 8, and Rock Tunnel's two are the far cell of each tunnel mouth.
const ARRIVAL_ONLY: Array = [
	[6, 8], [18, 0], [18, 2], [19, 0], [19, 2], [82, 1], [82, 3], [181, 4], [235, 2],
]

## Warps whose cell is not passable, which is the same shape: a gate's second
## doorway cell, the Seafoam holes that drop onto water, and the Elite Four
## doors, which are wall until each room's script opens them.
const UNSTANDABLE_WARPS: Array = [
	[6, 8], [17, 0], [18, 2], [27, 3], [47, 0], [49, 0], [50, 0], [82, 3],
	[161, 5], [161, 6], [162, 0], [162, 1], [245, 2], [245, 3],
]

## Viridian City's own cut tree, the first the corpus holds, and the block it
## sits in. Route 10's northern tunnel mouth, Rock Tunnel 1F's stairs down and
## the mouth it comes back out of.
const CUT_TREE_CELL := Vector2i(8, 22)
const CUT_TREE_BLOCK := Vector2i(4, 11)
const ROUTE_10: int = 21
const ROCK_TUNNEL_MOUTH := Vector2i(8, 17)
const ROCK_TUNNEL_B1F: int = 232
const ROCK_TUNNEL_STAIRS := Vector2i(37, 3)
const ROCK_TUNNEL_B1F_STAIRS := Vector2i(33, 25)
const ROCK_TUNNEL_EXIT := Vector2i(15, 3)

## Pallet Town's front door and the mat behind it: the round trip a `LAST_MAP`
## warp is, out through `RedsHouse1F_Object`'s first warp and back.
const PALLET_TOWN: int = 0
const REDS_HOUSE_1F: int = 37
const PALLET_DOOR := Vector2i(5, 5)
const REDS_HOUSE_MAT := Vector2i(2, 7)

## `PalletTown_Object`'s third `bg_event` and its second `object_event`, each
## read from the cell below it.
const PALLET_HOUSE_SIGN := Vector2i(3, 6)
const PALLET_GIRL := Vector2i(3, 9)
const PALLET_GIRL_TEXT: String = "I'm raising\nPOKéMON too!"

## Blue's house and the poster on its wall, which is the one bookshelf row that
## opens a screen. `_TownMapText` is what its own box says.
const BLUES_HOUSE: int = 39
const TOWN_MAP_POSTER_TILE: int = 0x3D
## `text_promptbutton` behind the string, which is the page break the stream
## keeps rather than a second box.
const TOWN_MAP_POSTER_BOX: String = "A TOWN MAP." + Gen2TextStream.PAGE_BREAK
## `Route22GateScriptCoords`' first cell, the `w<Map>CurScript` byte the gate
## dispatches on, and the two states `Route22GateGuardText` leaves behind it.
## `Route5Gate.PlayerInCoordsArray`'s first cell and BIT_GAVE_SAFFRON_GUARDS_DRINK.
const ROUTE_5_GATE: int = 70
const ROUTE_5_GATE_CELL := Vector2i(3, 3)
const SAFFRON_GUARD_THIRSTY: String = "I'm on guard duty."
const SAFFRON_GUARD_PAID: String = "Whoa, boy!"
const SAFFRON_DRINK_BIT: int = 6
const ITEM_FRESH_WATER: int = 0x3C
const ITEM_LEMONADE: int = 0x3E

## `ViridianGymArrowTilePlayerMovement`'s first row, its nine steps up, and a
## cell the table names no row for.
const VIRIDIAN_GYM: int = 45
const VIRIDIAN_GYM_ARROW := Vector2i(19, 11)
const VIRIDIAN_GYM_SPUN := Vector2i(19, 2)
const VIRIDIAN_GYM_STILL := Vector2i(19, 10)

## `Route12DefaultScript`'s fight and `Route12SnorlaxPostBattleScript`'s box.
const ROUTE_12_BYTE: int = 0x34
const ROUTE_12_POST_BATTLE: int = 3
const SNORLAX_SPECIES: int = 143
const SNORLAX_LEVEL: int = 30
const SNORLAX_CALMED: String = "SNORLAX calmed"

const ROUTE_22_GATE: int = 193
const ROUTE_22_GATE_CELL := Vector2i(4, 2)
const ROUTE_22_GATE_BYTE: int = 0x1E
const ROUTE_22_GATE_MOVING: int = 1
const ROUTE_22_GATE_NOOP: int = 2
const ROUTE_22_GATE_PASS: String = "Oh! That is the"
const ROUTE_22_GATE_REFUSED: String = "Only truly skilled"

## Frames enough for the longest walk either check drives, so a trail that never
## drains ends the loop rather than hanging the suite.
const SCRIPTED_WALK_PASSES: int = 256

## `MtMoonB2FMoveSuperNerdScript`: the state it stands at, the nerd's own object
## index, and the cell each coordinate list walks him to. He starts at (12, 8),
## and `MtMoon3FSuperNerdMoveRightMovementData` falls through into the row below
## it, so the dome side is two steps and the helix side one.
const MT_MOON_B2F: int = 61
const MT_MOON_B2F_BYTE: int = 0x17
const MT_MOON_B2F_MOVE_NERD: int = 4
const MT_MOON_B2F_NERD: int = 0
## Yellow puts a Pikachu branch on the cell in front of each fossil, so the walk
## stands on the corner both cartridges share.
const MT_MOON_B2F_WALKS: Array = [
	[Vector2i(11, 6), Vector2i(13, 7)], [Vector2i(14, 6), Vector2i(12, 7)],
]
const MT_MOON_B2F_NERD_BOX: String = "All right. Then\nthis is mine!"

## `HallOfFameDefaultScript` walks the player five cells up out of the room's
## own first warp, and `HallOfFameOakCongratulationsScript` behind it turns Oak
## to face them. Champion's Room's third warp is the way in.
const CHAMPIONS_ROOM: int = 120
const CHAMPIONS_ROOM_STAIRS := Vector2i(3, 0)
const HALL_OF_FAME_LANDING := Vector2i(4, 7)
const HALL_OF_FAME_WALKED := Vector2i(4, 2)
const HALL_OF_FAME_OAK: int = 0
const HALL_OF_FAME_BOX: String = "OAK: Er-hem!"

## A party that knows FLY, and `FlyWarpDataPtr.ViridianCity`'s own tile.
const FLY_SPECIES: Array[int] = [16]
const FLY_MOVES: Array = [[Gen2WorldFieldMove.MOVE_FLY, 0, 0, 0]]
const VIRIDIAN_FLY_CELL := Vector2i(23, 26)

## `ViridianMart_Object`'s clerk, who stands at 0,5 behind the counter at 1,5.
## `.extendRangeOverCounter` is what lets the player at 2,5 reach them.
const MART_COUNTER := Vector2i(2, 5)
const MART_CLERK := Vector2i(0, 5)

## `ViridianPokecenter_Object`'s nurse, reached over her counter from the cell
## two below her, and the party she is handed.
const VIRIDIAN_POKECENTER: int = 41
const NURSE_COUNTER := Vector2i(3, 3)
const NURSE_PARTY: int = 4

## `SPRITE_LINK_RECEPTIONIST` at 11,2, faced from the cell below her, and the 12
## rows the corpus stands at `TX_SCRIPT_CABLE_CLUB`.
const CABLE_CLUB_COUNTER := Vector2i(11, 3)
const CABLE_CLUB_ROWS: int = 12

## `Daycare_Object`'s one object, faced from the cell beside him, and the party
## the row's `wPartyCount` tests are answered with.
## `NAME_RATERS_HOUSE` and its one object, at `object_event 5, 3` facing LEFT.
const NAME_RATER_MAP: int = 0xE5
const NAME_RATER_CELL := Vector2i(6, 3)
const NAME_RATER_TEXT: int = 1
const NAME_RATER_TRAINER: String = "RED"
const NAME_RATER_ID: int = 22222
const NAME_RATER_NICKNAME: String = "BOLT"
const NAME_RATER_SPECIES_NAME: String = "SPARKY"

const DAYCARE: int = 0x48
const DAYCARE_GENTLEMAN := Vector2i(3, 3)
const DAYCARE_PARTY: int = 2
## `SPECIES_PIDGEY` and its own level 5, which the deposited slot is built from,
## and CUT, the HM move `KnowsHMMove` refuses a member for.
const DAYCARE_SPECIES: int = 16
const DAYCARE_LEVEL: int = 5
const DAYCARE_NICKNAME: String = "BIRD"
const MOVE_CUT: int = 15
## `wDayCarePerLevelCost` is $0100 and the loop runs `levels + 1` times.
const DAYCARE_GROWN_LEVEL: int = 8
const DAYCARE_PRICE: int = 400
const DAY_CARE_STEPS: int = 6

## `MtMoonPokecenter_Object`'s fourth object: `HasEnoughMoney`, `GivePokemon`
## and `SubBCDPredef` behind it, with MONEY_BOX standing over the map for the
## question. Museum 1F's scientist is the corpus's other spender.
const MT_MOON_POKECENTER: int = 0x44
const MAGIKARP_SELLER := Vector2i(10, 6)
const MAGIKARP_PRICE: int = 500
const MAGIKARP_DEX: int = 129
const MAGIKARP_LEVEL: int = 5
const MAGIKARP_PURSE: int = 600

## `Museum1F_Object`'s first object, at 12,4: the cell the player stands on
## picks his line, and a refusal walks them one cell down.
const MUSEUM_COUNTER := Vector2i(11, 4)
const MUSEUM_TICKET: int = 50
const MUSEUM_TICKET_FLAG: int = 104
const MUSEUM_OFFER: String = "It's ¥50 for a"
const MUSEUM_REFUSED: String = "Come again!"
const MUSEUM_BOUGHT: String = "Right, ¥50!"
const MUSEUM_BEHIND_COUNTER := Vector2i(13, 4)
const MUSEUM_BACK_WAY: String = "You can't sneak"
const MUSEUM_BELOW_COUNTER := Vector2i(12, 5)
const MUSEUM_OTHER_SIDE: String = "Please go to the"

## `CeladonMartRoof_Object`'s three `bg_event` machines, read from below.
const CELADON_MART_ROOF: int = 126
const VENDING_MACHINE := Vector2i(10, 2)
const VENDING_MACHINES: int = 3
## `VendingPrices`: FRESH_WATER, SODA_POP and LEMONADE at 200, 300 and 350.
const VENDING_PRICES: Array = [[0x3C, 200], [0x3D, 300], [0x3E, 350]]
const VENDING_PURSE: int = 1000

## `GameCornerPrizeRoom_Object`'s three vendors, read from below, and
## `PrizeDifferentMenuPtrs`' lists as [name, cost, level]. All three cartridges
## stock a different set of Pokemon and the same three TMs.
const PRIZE_ROOM: int = 137
const PRIZE_VENDORS: Array = [Vector2i(2, 3), Vector2i(4, 3), Vector2i(6, 3)]
const PRIZE_MENUS: Dictionary = {
	&"red": [
		[["ABRA", 180, 9], ["CLEFAIRY", 500, 8], ["NIDORINA", 1200, 17]],
		[["DRATINI", 2800, 18], ["SCYTHER", 5500, 25], ["PORYGON", 9999, 26]],
		[["TM23", 3300, 0], ["TM15", 5500, 0], ["TM50", 7700, 0]],
	],
	&"blue": [
		[["ABRA", 120, 6], ["CLEFAIRY", 750, 12], ["NIDORINO", 1200, 17]],
		[["PINSIR", 2500, 20], ["DRATINI", 4600, 24], ["PORYGON", 6500, 18]],
		[["TM23", 3300, 0], ["TM15", 5500, 0], ["TM50", 7700, 0]],
	],
	&"yellow": [
		[["ABRA", 230, 15], ["VULPIX", 1000, 18], ["WIGGLYTUFF", 2680, 22]],
		[["SCYTHER", 6500, 30], ["PINSIR", 6500, 30], ["PORYGON", 9999, 26]],
		[["TM23", 3300, 0], ["TM15", 5500, 0], ["TM50", 7700, 0]],
	],
}

## Three `text_asm` rows driven on the world, since a decoded script is only
## worth the box it puts up. `BikeShopYoungsterText` turns on EVENT_GOT_BICYCLE,
## `LavenderTownLittleGirlText` asks and branches on the answer, and
## `GameCornerFishingGuruText` reaches `Has9990Coins` only with the COIN CASE in
## the bag, so its own flag decides which of two boxes it opens.
## Route 16 and the cell its gate's south door lands on, which
## `ForcedBikeOrSurfMaps`' first row names.
const ROUTE_16: int = 27
const ROUTE_16_GATE_DOOR := Vector2i(17, 10)
const BIKE_SHOP: int = 66
const CELADON_LITTLE_GIRL := Vector2i(5, 5)
const DRINK_ROWS: Array[String] = ["FRESH WATER", "LEMONADE"]
const DRINK_QUESTION: String = "Give her which"
const DRINK_THIRSTY: String = "I'm thirsty!"
const TM_ICE_BEAM: int = 0xD5
const TM13_FLAG: int = 396
const MENU_ARM_BOXES: int = 6
const BIKE_CLERK := Vector2i(6, 2)
const BIKE_MENU_ROWS: Array[String] = ["BICYCLE", "CANCEL"]
const BIKE_PRICE: String = "¥1000000"
const CINNABAR_LAB_FOSSIL_ROOM: int = 170
const FOSSIL_SCIENTIST := Vector2i(5, 2)
const DOME_FOSSIL: int = 0x29
const FOSSIL_ROWS: Array[String] = ["DOME FOSSIL", "OLD AMBER"]
const FOSSIL_GIVEN_FLAG: int = 736
const FOSSIL_REVIVING_FLAG: int = 737
const KABUTO_INDEX: int = 0x5A
const KABUTO_DEX: int = 140
const BADGE_HOUSE: int = 230
const BADGE_MAN := Vector2i(5, 3)
const BADGE_COUNT: int = 8
const BADGE_FIRST: String = "BOULDERBADGE"
const BADGE_FAREWELL: String = "Come visit me any"
const BIKE_TOO_DEAR: String = "Sorry!"
const BIKE_COME_AGAIN: String = "Come back again"
const BIKE_YOUNGSTER := Vector2i(1, 4)
const BIKE_FLAG: int = 192
const BIKE_BOXES: Array[String] = ["These BIKEs are", "Wow. Your BIKE is"]
const LAVENDER_TOWN: int = 4
const GHOST_GIRL := Vector2i(15, 10)
const GHOST_ANSWERS: Array[String] = ["Really? So there", "Hahaha, I guess"]
const GAME_CORNER: int = 135
const GAME_CORNER_GURU := Vector2i(5, 12)
const GAME_CORNER_FLAG: int = 442
const GAME_CORNER_BOX: String = "Wins seem to come"
const GAME_CORNER_ASKED: String = "Kid, do you want"

const GAME_CORNER_CLERK := Vector2i(5, 7)
const COIN_CASE_CEILING: int = 9990
const COIN_PRICE: int = 1000
const COINS_BOUGHT: int = 50
const CLERK_SOLD: String = "Thanks! Here are"
const CLERK_NO_CASE: String = "You don't have a"
const CLERK_CASE_FULL: String = "Oops! Your COIN"
const CLERK_SHORT: String = "You can't afford"

## `GameCornerGentlemanText`, whose `jr z` refuses exactly 9990 and pays more.
const GAME_CORNER_GENTLEMAN := Vector2i(17, 14)
const GENTLEMAN_FLAG: int = 443
const COINS_GIVEN: int = 20
const GENTLEMAN_PAID: String = "20 coins!"
const GENTLEMAN_REFUSED: String = "You've got your"

## Celadon City's TM41, whose receipt box names the item out of the buffer
## `CopyToStringBuffer` fills only when the bag took it.
const CELADON_CITY: int = 6
const TM41_CELL := Vector2i(22, 17)
const TM41_ITEM: int = 241
const TM41_NAME: String = "TM41"
const TM41_FLAG: int = 384
const GIFT_OPENING: String = "Hello, there!"
const GIFT_KNOWN: String = "TM41 teaches"
const GIFT_REFUSED: String = "Oh, your pack is"

## Route 4's TM04: an ITEM object on `PickUpItemText` with a toggle row of its own.
const ROUTE_4: int = 15
const GROUND_ITEM_CELL := Vector2i(57, 3)
const GROUND_ITEM_OBJECT: int = 2
const GROUND_ITEM: int = 0xCC
const GROUND_ITEM_NAME: String = "TM04"
const GROUND_ITEM_FOUND: String = "found"
const GROUND_ITEM_REFUSED: String = "No more room for"

## `TOGGLE_PALLET_TOWN_OAK`, row 0 and one of the 32 that start OFF.
const PALLET_OAK_CELL := Vector2i(10, 4)
const PALLET_OAK_OBJECT: int = 0

## `Museum1FScientist2Text`, whose gift ends in `predef HideObject` over the OLD
## AMBER ball beside it. Yellow reaches that text through a `farcall` instead.
const MUSEUM_1F: int = 52
const MUSEUM_SCIENTIST_CELL := Vector2i(15, 2)
const MUSEUM_AMBER_OBJECT: int = 4
const OLD_AMBER: int = 0x1F
const MUSEUM_GIFT_BOX: String = "Take this to a\nPOKéMON LAB"

## `CeladonMansionRoofHouseEeveePokeballText`: `lb bc, EEVEE, 25` and the
## `jr nc` behind `GivePokemon`, which hides the ball only when the gift landed.
const EEVEE_HOUSE: int = 0x84
const EEVEE_BALL_CELL := Vector2i(4, 3)
const EEVEE_BALL_OBJECT: int = 1
const EEVEE_DEX: int = 133
const EEVEE_LEVEL: int = 25

## `FightingDojoHitmonleePokeBallText`, whose `CheckEitherEventSet` reads both
## gift flags out of one `wEventFlags` byte: `DisplayPokedex` and the YES/NO
## behind it are only reached while neither is set. Identical on all three
## cartridges, objects and event indices alike.
const FIGHTING_DOJO: int = 0xB1
const HITMONLEE_BALL_CELL := Vector2i(4, 1)
const HITMONLEE_BALL_OBJECT: int = 5
const HITMONLEE_DEX: int = 106
const HITMONLEE_LEVEL: int = 30
const GOT_HITMONCHAN_FLAG: int = 855
const DOJO_GREEDY_BOX: String = "better not get"

## Yellow's `CeruleanBadgeHouse` melanie, the corpus's one box that owes no
## press: `DisableWaitingAfterTextDisplay` runs before her last `PrintText`.
const MELANIE_MAP: int = 63
const MELANIE_CELL := Vector2i(3, 2)
const MELANIE_FLAG: int = 168
const MELANIE_BOX: String = "Is BULBASAUR"

## `Route11Gate2FYoungsterText`, whose `wWhichTrade` is row 0 on all three
## cartridges: `xor a` on Red and Blue and `ld a, TRADE_FOR_GURIO` on Yellow.
const ROUTE_11_GATE_2F: int = 0x56
const TRADE_YOUNGSTER := Vector2i(4, 3)
const TRADE_ROW: int = 0
## Any species the row does not ask for, which is TRADETEXT_WRONG_MON.
const TRADE_WRONG_SPECIES: int = 25
const TRADE_PARTY_SLOT: int = 2

## `RedsHouse2F`'s SNES and Viridian City's own hidden POTION.
const REDS_HOUSE_2F: int = 0x26
const SNES_CELL := Vector2i(3, 5)
const VIRIDIAN_CITY: int = 0x01
const HIDDEN_POTION_CELL := Vector2i(14, 4)
const HIDDEN_POTION: int = 0x14

## `OpenPokemonCenterPC` at VIRIDIAN_POKECENTER's own cell and `OpenRedsPC` at
## the bedroom's: the two hidden events a `TX_SCRIPT_*` PC stands behind, faced
## from the cell below each.
const POKECENTER_PC_CELL := Vector2i(13, 3)
const REDS_PC_CELL := Vector2i(0, 1)
const PC_MACHINES: Array = [
	[VIRIDIAN_POKECENTER, POKECENTER_PC_CELL, &"gen1_pokemon_center", "pc"],
	[REDS_HOUSE_2F, REDS_PC_CELL, &"gen1_players_pc", "players_pc"],
]

## `MapBadgeFlags`' Pewter row and its two statues, with the two names
## `PewterGym_Script.LoadNames` hands `LoadGymLeaderAndCityName`.
const PEWTER_GYM: int = 0x36
const PEWTER_STATUE_CELL := Vector2i(3, 10)
const PEWTER_STATUE_BOX: String = "PEWTER CITY\n#MON GYM"

## `BenchGuyTextPointers`' first row, which answers a player facing left.
const BENCH_GUY_CELL := Vector2i(0, 4)

## `_RedBedroomSNESText`, which opens on a `<PLAYER>` no walk here has named,
## and the box `BookshelfTileIDs` gives every mart shelf.
const SNES_BOX: String = "%s is\nplaying the SNES!"
const MART_SHELF_BOX: String = "Wow! Tons of\nPOKéMON stuff!"

## `Seafoam1HolesCoords`' first hole and the tile below it, with Victory Road
## 3F's list, whose first row is the switch and carries no pair of its own.
const SEAFOAM_1F: int = 192
const SEAFOAM_B1F: int = 159
const SEAFOAM_HOLE := Vector2i(17, 6)
const SEAFOAM_LANDING := Vector2i(18, 7)
## Seafoam B2F's first hole and the water on B3F it drops into.
const SEAFOAM_B2F: int = 160
const SEAFOAM_B3F: int = 161
const SEAFOAM_B2F_HOLE := Vector2i(19, 6)
const SEAFOAM_B3F_LANDING := Vector2i(18, 7)
const VICTORY_ROAD_3F: int = 198
const VICTORY_ROAD_2F: int = 194
const VICTORY_ROAD_SWITCH := Vector2i(3, 5)
const VICTORY_ROAD_HOLE := Vector2i(23, 15)
const VICTORY_ROAD_LANDING := Vector2i(22, 16)

## `FlyWarpDataPtr.PalletTown`, which a zeroed `wLastBlackoutMap` names.
const PALLET_FLY_CELL := Vector2i(5, 6)
## `AGATHAS_ROOM`, the one map `ItemUseEscapeRope` refuses by name.
const AGATHAS_ROOM_CELL := Vector2i(4, 11)

## `Route12SnorlaxFluteCoords`' last row, one space east of the Snorlax.
const ROUTE_12: int = 0x17
const SNORLAX_CELL := Vector2i(11, 62)
const SNORLAX_FIGHT_FLAG: int = 1166
const SNORLAX_BEAT_FLAG: int = 1167

var _r: RefCounted = null


func run(r: RefCounted) -> void:
	_r = r
	r.each_game_of(RomRegistry.GEN1, _one_game)


func _one_game() -> void:
	_check_cinnabar_gates()
	_check_warps()
	_check_ledges()
	_check_last_map_round_trip()
	_check_text_boxes()
	_check_scripted_npcs()
	_check_a_gift()
	_check_an_item_is_picked_up()
	_check_an_object_starts_hidden()
	if _r.game_id != RomRegistry.YELLOW:
		_check_a_script_hides_an_object()
	_check_a_script_gives_a_pokemon()
	_check_either_event_set()
	_check_the_nurse_heals()
	_check_the_cable_club()
	_check_the_vending_machine()
	_check_the_prize_counter()
	_check_a_trade()
	_check_the_magikarp_salesman()
	_check_the_museum_ticket()
	_check_the_coin_clerks()
	_check_a_hidden_object()
	_check_a_pc_opens()
	_check_a_hidden_item()
	_check_the_trash_cans()
	_check_a_gym_statue()
	_check_a_bench_guy()
	_check_a_bookshelf()
	_check_a_card_key_door()
	_check_an_elevator()
	_check_a_script_menu()
	_check_the_fossil_lab()
	_check_the_badge_house()
	_check_the_day_care()
	_check_the_name_rater()
	_check_the_town_map_poster()
	_check_flying()
	_check_a_dungeon_fall()
	_check_an_escape_rope()
	_check_the_bicycle()
	_check_the_poke_flute()
	_check_a_cut_tree()
	_check_rock_tunnel_is_dark()
	_check_a_map_script_runs()
	_check_a_scripted_npc_walk()
	_check_a_scripted_player_walk()
	_check_the_saffron_guard()
	_check_an_arrow_tile()
	_check_a_scripted_wild_battle()
	_check_the_ghost_marowak()
	_check_the_catch_training()
	if _r.game_id != RomRegistry.YELLOW:
		_check_the_opening_walk()
	_check_the_route_23_guards()
	_check_the_cycling_road_gate_walk()
	_check_the_viridian_gym_door()
	_check_the_tower_warp()
	if _r.game_id != RomRegistry.YELLOW:
		_check_the_tower_rocket_leaves()
	_check_the_champion()
	_check_the_silph_rival()
	_check_a_seafoam_boulder_hole()
	_check_the_safari_zone()
	_check_a_connection_lands_aligned()
	_check_the_parcel_clerk()
	if _r.game_id != RomRegistry.YELLOW:
		_check_a_gift_lands_in_the_party()
	_check_the_map_script_names_the_nerd()
	_check_the_captains_back()
	_check_the_ship_leaves()
	_check_the_gate_pushes_back()
	_check_cinnabar_settles()
	_check_a_mansion_switch()


## `DisplayPokemonCenterDialogue_` walked whole. `AnimateHealingMachine` is a
## counted wait rather than a box, so what proves it is there is the world
## standing in one for its own frames.
func _check_the_nurse_heals() -> void:
	var world: Gen2WorldAPI = _r.open_world(0, VIRIDIAN_POKECENTER, NURSE_COUNTER)
	if world == null:
		return
	world.set_party_summary(NURSE_PARTY, false)
	world.player_facing = Gen2WorldSprite.FACING_UP
	if not _r.check(not world.interact().is_empty(), "the nurse said nothing."):
		return
	## The welcome, then the YES/NO, then the line in front of the heal.
	world.run_event_queue(true)
	if not _r.check(world.script_input_waiting(), "the nurse asked nothing."):
		return
	world.choose_script_input(0)
	world.run_event_queue(true)
	var request: Dictionary = world.pending_runtime_request()
	if not _r.check(
		StringName(request.get("kind", &"")) == &"party_heal_requested",
		"the nurse asked for %s." % [request.get("kind", &"nothing")]
	):
		return
	var healed: Array = world.complete_runtime_request({"ok": true})
	var machine: Dictionary = _first_event(healed, &"presentation_special_applied")
	var wait: Dictionary = world.pending_script_wait()
	var frames: int = NURSE_PARTY * Gen2WorldEffects.HEAL_MACHINE_BALL_FRAMES \
		+ Gen2WorldEffects.HEAL_MACHINE_FLASHES \
		* Gen2WorldEffects.HEAL_MACHINE_FLASH_INTERVAL
	_r.check(
		StringName(wait.get("kind", &"")) == &"heal_machine_anim"
			and int(wait.get("frames", 0)) == frames,
		"the heal machine waited on %s." % [wait]
	)
	_r.check(world.party_holder() == &"heal_machine", "the machine held no party.")
	## `.partyLoop`'s `ld c, 30` per ball, and `MUSIC_PKMN_HEALED` behind them.
	var sounds: Array = machine.get("sounds", [])
	var wanted: Array = [[0, Gen1SoundEngine.SFX_STOP_ALL_MUSIC]]
	for ball: int in NURSE_PARTY:
		wanted.append([
			ball * Gen2WorldEffects.HEAL_MACHINE_BALL_FRAMES,
			Gen1Layout.SFX_HEALING_MACHINE,
		])
	wanted.append([
		NURSE_PARTY * Gen2WorldEffects.HEAL_MACHINE_BALL_FRAMES,
		Gen1Layout.MUSIC_PKMN_HEALED,
	])
	var played: Array = []
	for row: Dictionary in sounds:
		played.append([int(row["frame"]), int(row["index"])])
	_r.check(played == wanted, "the machine sounded %s." % [played])
	var spent: int = 0
	while not world.pending_script_wait().is_empty() and spent <= frames:
		world.advance_script_wait_frame()
		spent += 1
	_r.check(spent == frames, "the machine ran for %d frames, not %d." % [spent, frames])
	## `PokemonFightingFitText` and `PokemonCenterFarewellText` behind it.
	_r.check(world.script_busy(), "nothing was said once the machine had stopped.")
	world.run_event_queue(true)
	world.run_event_queue(true)
	_r.check(not world.script_busy(), "the nurse never finished.")


## Every warp on every map: its destination resolves, it fires from some facing,
## and taking it lands on the destination map's own warp cell.
func _check_warps() -> void:
	var pinned: Dictionary = WARP_CENSUS[_r.game_id]
	var warps: int = 0
	var last_map: int = 0
	var driven: int = 0
	var edge: int = 0
	var arrival_only: Array = []
	var unstandable: Array = []
	for map: Gen2WorldMap in _r.data.world_maps():
		var tileset: Gen2WorldTileset = _r.data.world_tileset(map.tileset)
		var rows: Array = map.events.get("warps", [])
		for index: int in rows.size():
			var warp: Dictionary = rows[index]
			var cell := Vector2i(int(warp["x"]), int(warp["y"]))
			warps += 1
			if not tileset.tile_passable(map.collision_at(cell.x, cell.y)):
				unstandable.append([map.number, index])
			if int(warp["map_number"]) == Gen1Layout.WARP_TO_LAST_MAP:
				last_map += 1
			var world: Gen2WorldAPI = _r.open_world(0, map.number, cell)
			var facing: int = _firing_facing(world, cell)
			if facing < 0:
				arrival_only.append([map.number, index])
				continue
			## `ExtraWarpCheck`'s own warps: neither a door nor a warp tile, so
			## `CheckWarpsNoCollision` asks the map edge or the carpet in front
			## and `CheckWarpsCollision` takes them on a step that never lands.
			if not Gen2WorldCollision.gen1_is_warp_tile(
				map.tileset, map.collision_at(cell.x, cell.y)
			) and not Gen2WorldCollision.gen1_is_door_tile(
				map.tileset, map.collision_at(cell.x, cell.y)
			):
				edge += 1
				_r.check(world.blocked_step_warps(),
					"map %d warp %d takes no blocked step." % [map.number, index])
			## A `LAST_MAP` warp names no map of its own until one is walked out
			## of, which [method _check_last_map_round_trip] is; the lift's two
			## name a map with no header at all.
			if int(warp["map_number"]) == Gen1Layout.WARP_TO_LAST_MAP \
				or map.number == SILPH_CO_ELEVATOR:
				continue
			world.player_facing = facing
			var taken: Dictionary = world.try_warp()
			if not _r.check(bool(taken.get("ok", false)),
				"map %d warp %d: %s" % [map.number, index, taken.get("reason", &"refused")]):
				continue
			driven += 1
			var destination: Dictionary = taken["destination"]
			## The landing rather than where the player stands: the destination
			## map's own script runs behind `EnterMap` and may walk them off it.
			_r.check(
				Vector2i(taken["to_cell"])
					== Vector2i(int(destination["x"]), int(destination["y"])),
				"map %d warp %d landed on %s" % [map.number, index, taken["to_cell"]]
			)
	_r.check(warps == int(pinned["warps"]), "%d warps, wanted %d" % [warps, pinned["warps"]])
	_r.check(last_map == int(pinned["last_map"]),
		"%d LAST_MAP warps, wanted %d" % [last_map, pinned["last_map"]])
	_r.check(driven == int(pinned["driven"]),
		"%d warps taken, wanted %d" % [driven, pinned["driven"]])
	_r.check(arrival_only == ARRIVAL_ONLY, "warps firing from no facing: %s" % [arrival_only])
	_r.check(unstandable == UNSTANDABLE_WARPS, "warps on an impassable tile: %s" % [unstandable])
	_r.check(edge == int(pinned["edge"]),
		"%d warps need ExtraWarpCheck, wanted %d" % [edge, pinned["edge"]])
	_r.note("%d warps, %d back to LAST_MAP, %d taken, %d off ExtraWarpCheck" % [
		warps, last_map, driven, edge,
	])


## The first facing `CheckWarpsNoCollision` would warp from, or -1.
func _firing_facing(world: Gen2WorldAPI, cell: Vector2i) -> int:
	if world == null:
		return -1
	for facing: int in 4:
		world.player_facing = facing
		if world._warp_tile_allows(cell):
			return facing
	return -1


## `LedgeTiles` against the imported OVERWORLD list: every tile the player hops
## from is passable and every ledge tile is not, which is what makes the hop the
## only way across. The corpus count is what says the table reaches real cells.
func _check_ledges() -> void:
	var overworld: Gen2WorldTileset = _r.data.world_tileset(Gen1Layout.TILESET_OVERWORLD)
	if not _r.check(overworld != null, "no OVERWORLD tileset."):
		return
	for row: Array in Gen2WorldCollision.GEN1_LEDGES:
		_r.check(overworld.tile_passable(int(row[1])),
			"ledge row stands on impassable tile $%02X." % row[1])
		_r.check(not overworld.tile_passable(int(row[2])),
			"ledge tile $%02X is passable." % row[2])
	var hops: int = 0
	for map: Gen2WorldMap in _r.data.world_maps():
		if map.tileset != Gen1Layout.TILESET_OVERWORLD:
			continue
		var world: Gen2WorldAPI = _r.open_world(0, map.number, Vector2i.ZERO)
		if world == null:
			continue
		for y: int in map.collision_height:
			for x: int in map.collision_width:
				hops += _hops_at(world, Vector2i(x, y))
	var wanted: int = int(WARP_CENSUS[_r.game_id]["hops"])
	_r.check(hops == wanted, "%d ledge hops, wanted %d" % [hops, wanted])
	_r.note("%d cells offer a ledge hop" % hops)


func _hops_at(world: Gen2WorldAPI, cell: Vector2i) -> int:
	var out: int = 0
	world.player_cell = cell
	for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if world._allows_hop(direction):
			out += 1
	return out


## Pallet Town to Red's house and back out through `LAST_MAP`, which is the one
## warp shape with no map of its own in the record.
func _check_last_map_round_trip() -> void:
	var world: Gen2WorldAPI = _r.open_world(0, PALLET_TOWN, PALLET_DOOR)
	if world == null:
		return
	world.player_facing = Gen2WorldSprite.FACING_UP
	var inside: Dictionary = world.try_warp()
	if not _r.check(bool(inside.get("ok", false)), "Red's front door refused the warp."):
		return
	_r.check(world.map_id() == Vector2i(0, REDS_HOUSE_1F) and world.player_cell == REDS_HOUSE_MAT,
		"the door led to %s %s." % [world.map_id(), world.player_cell])
	_r.check(world.gen1_last_map() == PALLET_TOWN,
		"wLastMap is %d." % world.gen1_last_map())
	world.player_facing = Gen2WorldSprite.FACING_DOWN
	var outside: Dictionary = world.try_warp()
	if not _r.check(bool(outside.get("ok", false)), "the mat refused the way back."):
		return
	_r.check(world.map_id() == Vector2i(0, PALLET_TOWN) and world.player_cell == PALLET_DOOR,
		"the way back led to %s %s." % [world.map_id(), world.player_cell])


## `DisplayTextID` driven through the world: the box carries the map's own string
## with `<PLAYER>` filled and the press closing it leaves nothing waiting. The
## mart counter is `.extendRangeOverCounter`, whose reach is two cells.
func _check_text_boxes() -> void:
	var world: Gen2WorldAPI = _r.open_world(0, PALLET_TOWN, PALLET_HOUSE_SIGN)
	if world == null:
		return
	world.set_player_name("RED")
	world.player_facing = Gen2WorldSprite.FACING_UP
	var read: String = _box_text(world)
	_r.check(read == "RED's house ", "the house sign read %s." % [read])
	_r.check(world.script_input_waiting(), "the house sign left nothing waiting.")
	world.run_event_queue(true)
	_r.check(not world.script_input_waiting(), "the press left the box open.")

	world.player_cell = PALLET_GIRL
	world.player_facing = Gen2WorldSprite.FACING_UP
	var girl: String = _box_text(world)
	_r.check(girl.begins_with(PALLET_GIRL_TEXT), "the girl said %s." % [girl])

	var mart: Gen2WorldAPI = _r.open_world(0, VIRIDIAN_MART, MART_COUNTER)
	if mart == null:
		return
	mart.player_facing = Gen2WorldSprite.FACING_LEFT
	_r.check(mart.object_facing_cell() == MART_CLERK,
		"the mart counter reaches %s." % [mart.object_facing_cell()])


## `PrintCardKeyText` on Silph Co. 2F, whose door tile is on the map only
## because the floor's own callback put the locked block back.
func _check_a_card_key_door() -> void:
	var refused: Gen2WorldAPI = _silph_door()
	if refused == null:
		return
	_r.check(refused.block_at(SILPH_DOOR.x, SILPH_DOOR.y) == SILPH_LOCKED_BLOCK,
		"Silph Co. 2F draws block $%02X on a locked door." % refused.block_at(
			SILPH_DOOR.x, SILPH_DOOR.y
		))
	var darn: String = _box_text(refused)
	_r.check(darn.begins_with(CARD_KEY_REFUSED), "a door with no CARD KEY said %s." % [darn])
	_r.check(refused.block_at(SILPH_DOOR.x, SILPH_DOOR.y) == SILPH_LOCKED_BLOCK,
		"a refused door opened anyway.")

	var world: Gen2WorldAPI = _silph_door()
	if world == null:
		return
	world.state.apply_changes({}, {}, {"items": {Gen1Layout.ITEM_CARD_KEY: 1}})
	var opened: String = _box_text(world)
	_r.check(opened.begins_with(CARD_KEY_OPENED), "the CARD KEY said %s." % [opened])
	world.run_event_queue(true)
	_r.check(world.block_at(SILPH_DOOR.x, SILPH_DOOR.y) == SILPH_OPEN_BLOCK,
		"the opened door draws block $%02X." % world.block_at(SILPH_DOOR.x, SILPH_DOOR.y))
	_r.check(world.state.card_key_door() == SILPH_DOOR,
		"the door opened at %s was remembered as %s." % [
			SILPH_DOOR, world.state.card_key_door(),
		])
	## `set BIT_CUR_MAP_LOADED_1`: the next frame's callback turns the
	## coordinates into the door's flag before the player takes a step.
	world.dispatch_sight_events()
	var flag: int = int((world.current_map.events["card_key"] as Array)[0]["flag"])
	_r.check(world.state.card_key_door() == Gen2WorldState.NO_CARD_KEY_DOOR
		and world.event_flag_active(flag),
		"the frame after the box kept %s and flag %d %s." % [
			world.state.card_key_door(), flag, world.event_flag_active(flag)])

	## The floor loaded again: the callback leaves the flagged door alone.
	var again: Gen2WorldAPI = _r.open_world(
		0, SILPH_CO_2F, SILPH_DOOR_APPROACH, world.state
	)
	if again == null:
		return
	again.dispatch_map_entry()
	_r.check(again.block_at(SILPH_DOOR.x, SILPH_DOOR.y) == SILPH_OPEN_BLOCK,
		"the reloaded floor blocked the opened door with $%02X." % again.block_at(
			SILPH_DOOR.x, SILPH_DOOR.y
		))
	_r.check(again.block_at(SILPH_SECOND_DOOR.x, SILPH_SECOND_DOOR.y) == SILPH_LOCKED_BLOCK,
		"the floor's other door stands at $%02X." % again.block_at(
			SILPH_SECOND_DOOR.x, SILPH_SECOND_DOOR.y
		))


## Silph Co. 2F opened and entered, standing under its first door facing it.
func _silph_door() -> Gen2WorldAPI:
	var world: Gen2WorldAPI = _r.open_world(0, SILPH_CO_2F, SILPH_DOOR_APPROACH)
	if world == null:
		return null
	world.dispatch_map_entry()
	world.player_facing = Gen2WorldSprite.FACING_UP
	return world


## The string one interaction puts in a box, or "" when it opened none.
func _box_text(world: Gen2WorldAPI) -> String:
	var results: Array = world.interact()
	if results.is_empty():
		return ""
	return String((results[0].get("event", {}) as Dictionary).get("text", ""))


## A decoded `text_asm` row driven on the world, both ways about its own flag.
func _check_scripted_npcs() -> void:
	for set_flag: bool in [false, true]:
		var read: String = _scripted_box(
			BIKE_SHOP, BIKE_YOUNGSTER, BIKE_FLAG if set_flag else 0
		)
		_r.check(read.begins_with(BIKE_BOXES[1 if set_flag else 0]),
			"the bike shop said %s with the bicycle flag %s." % [read, set_flag])
	var asked: String = _scripted_box(GAME_CORNER, GAME_CORNER_GURU, 0)
	_r.check(asked.begins_with(GAME_CORNER_ASKED),
		"the guru said %s with no COIN CASE." % [asked])
	var spoken: String = _scripted_box(
		GAME_CORNER, GAME_CORNER_GURU, GAME_CORNER_FLAG
	)
	_r.check(spoken.begins_with(GAME_CORNER_BOX), "its other side said %s." % [spoken])
	_check_the_ghost_girl()
	if _r.game_id == RomRegistry.YELLOW:
		_check_a_box_owing_no_press()


## `GiveItem` both ways: the bag takes the gift, or it stands in every slot.
func _check_a_gift() -> void:
	var world: Gen2WorldAPI = _r.open_world(0, CELADON_CITY, TM41_CELL)
	if world == null:
		return
	world.player_facing = Gen2WorldSprite.FACING_UP
	var said: Array[String] = _spoken(world)
	_r.check(said.size() == 2 and said[0].begins_with(GIFT_OPENING)
		and said[1].contains(TM41_NAME), "the gift said %s." % [said])
	_r.check(world.state.item_quantity(TM41_ITEM) == 1,
		"the bag holds %d TM41." % world.state.item_quantity(TM41_ITEM))
	_r.check(world.event_flag_active(TM41_FLAG), "the gift left its flag clear.")
	var again: Array[String] = _spoken(world)
	_r.check(again.size() == 1 and again[0].begins_with(GIFT_KNOWN),
		"talked to again he said %s." % [again])
	_check_a_gift_refused()


func _check_a_gift_refused() -> void:
	var world: Gen2WorldAPI = _r.open_world(0, CELADON_CITY, TM41_CELL)
	if world == null:
		return
	world.player_facing = Gen2WorldSprite.FACING_UP
	var stock: Dictionary = {}
	for slot: int in Gen1Layout.BAG_ITEM_CAPACITY:
		stock[slot + 1] = 1
	world.state.apply_changes({}, {}, {"items": stock})
	var said: Array[String] = _spoken(world)
	_r.check(said.size() == 2 and said[1].begins_with(GIFT_REFUSED),
		"a full bag said %s." % [said])
	_r.check(world.state.item_quantity(TM41_ITEM) == 0, "a full bag took the gift.")
	_r.check(not world.event_flag_active(TM41_FLAG), "a refused gift set its flag.")


## `PickUpItem` both ways: the bag takes the item and `HideObject` takes the ball
## off the map, or the bag is full and both stay where they were.
func _check_an_item_is_picked_up() -> void:
	var world: Gen2WorldAPI = _facing_up(ROUTE_4, GROUND_ITEM_CELL + Vector2i.DOWN)
	if world == null:
		return
	var opened: Array = world.interact()
	var event: Dictionary = opened[0].get("event", {}) if not opened.is_empty() else {}
	_r.check(String(event.get("text", "")).contains(GROUND_ITEM_NAME)
		and String(event.get("text", "")).contains(GROUND_ITEM_FOUND)
		and not bool(event.get("prompt", true)),
		"the ground item said %s." % [event])
	world.run_event_queue(true)
	_r.check(world.state.item_quantity(GROUND_ITEM) == 1,
		"the bag holds %d of the ground item." % world.state.item_quantity(GROUND_ITEM))
	_r.check(not _object_active(world, GROUND_ITEM_OBJECT), "the picked ball is still drawn.")
	_r.check(world.interact().is_empty(), "the picked ball still answers.")

	world = _facing_up(ROUTE_4, GROUND_ITEM_CELL + Vector2i.DOWN)
	if world == null:
		return
	var stock: Dictionary = {}
	for slot: int in Gen1Layout.BAG_ITEM_CAPACITY:
		stock[slot + 1] = 1
	world.state.apply_changes({}, {}, {"items": stock})
	_r.check(_box_text(world).begins_with(GROUND_ITEM_REFUSED),
		"a full bag met the ground item with %s." % _box_text(world))
	_r.check(world.state.item_quantity(GROUND_ITEM) == 0, "a full bag took the ground item.")
	_r.check(_object_active(world, GROUND_ITEM_OBJECT), "a refused ball left the map.")


## `InitializeToggleableObjectsFlags` writes the OFF rows on a new game, so Oak
## is in Pallet Town's objects and not on its map until a `ShowObject` runs.
func _check_an_object_starts_hidden() -> void:
	var world: Gen2WorldAPI = _facing_up(PALLET_TOWN, PALLET_OAK_CELL + Vector2i.DOWN)
	if world == null:
		return
	var oak: Gen2WorldObject = world.objects[PALLET_OAK_OBJECT]
	_r.check(oak.toggle_index == 0 and not oak.toggle_on,
		"Pallet Town's Oak carries toggle %d, on %s." % [oak.toggle_index, oak.toggle_on])
	_r.check(not oak.active, "Oak is on the map already.")
	world.gen1_toggle_object(oak.toggle_index, false)
	_r.check(_object_active(world, PALLET_OAK_OBJECT), "ShowObject left Oak off the map.")


## A decoded `predef HideObject`: the OLD AMBER lands and its ball leaves the map.
func _check_a_script_hides_an_object() -> void:
	var world: Gen2WorldAPI = _facing_up(MUSEUM_1F, MUSEUM_SCIENTIST_CELL + Vector2i.DOWN)
	if world == null:
		return
	_r.check(_object_active(world, MUSEUM_AMBER_OBJECT), "the OLD AMBER was never drawn.")
	var said: Array[String] = _spoken(world)
	_r.check(said.size() == 2 and said[0].contains(MUSEUM_GIFT_BOX),
		"the museum scientist said %s." % [said])
	_r.check(world.state.item_quantity(OLD_AMBER) == 1, "the OLD AMBER never landed.")
	_r.check(not _object_active(world, MUSEUM_AMBER_OBJECT), "the OLD AMBER is still drawn.")


## The corpus's one `call GivePokemon` a text row reaches: the request the world
## raises, and the two sides of the caller's own `jr nc`. Both are walked on the
## same map, since only the answer differs.
func _check_a_script_gives_a_pokemon() -> void:
	for accepted: bool in [true, false]:
		var world: Gen2WorldAPI = _facing_up(EEVEE_HOUSE, EEVEE_BALL_CELL + Vector2i.DOWN)
		if world == null:
			return
		var results: Array = world.interact()
		var request: Dictionary = _runtime_request(results)
		_r.check(
			StringName(request.get("kind", &"")) == &"pokemon_requested"
			and int((request.get("values", {}) as Dictionary).get("pokemon", 0)) == EEVEE_DEX
			and int((request.get("values", {}) as Dictionary).get("level", 0)) == EEVEE_LEVEL,
			"the EEVEE ball raised %s." % [request]
		)
		world.complete_runtime_request({"ok": true, "accepted": accepted})
		_r.check(
			_object_active(world, EEVEE_BALL_OBJECT) != accepted,
			"the EEVEE ball is %sdrawn after a gift that was %saccepted." % [
				"" if accepted else "still ", "" if accepted else "not ",
			]
		)


## `CheckEitherEventSet`'s two flags, one `wEventFlags` byte and one mask: the
## ball opens its Pokedex page and its question while neither is set, and the
## greedy line once the other ball has been taken.
func _check_either_event_set() -> void:
	var world: Gen2WorldAPI = _facing_up(
		FIGHTING_DOJO, HITMONLEE_BALL_CELL + Vector2i.DOWN
	)
	if world == null:
		return
	var results: Array = world.interact()
	var request: Dictionary = _runtime_request(results)
	_r.check(
		StringName(request.get("kind", &"")) == &"pokedex_entry_requested"
		and int((request.get("values", {}) as Dictionary).get("species", 0)) == HITMONLEE_DEX,
		"the HITMONLEE ball raised %s." % [request]
	)
	world = _facing_up(FIGHTING_DOJO, HITMONLEE_BALL_CELL + Vector2i.DOWN)
	if world == null:
		return
	world.state.set_event_flag(GOT_HITMONCHAN_FLAG, true)
	_r.check(
		"\n".join(_spoken(world)).to_lower().contains(DOJO_GREEDY_BOX),
		"the taken ball said %s." % [_spoken(world)]
	)
	_r.note("gen1 walk the FIGHTING DOJO ball reads both gift flags at once")


## The request the first waiting result of [param results] carries, or empty.
func _runtime_request(results: Array) -> Dictionary:
	for row: Dictionary in results:
		var event: Dictionary = row.get("event", {})
		if StringName(event.get("type", &"")) == &"runtime_request":
			return event.get("request", {})
	return {}


func _facing_up(map: int, cell: Vector2i) -> Gen2WorldAPI:
	var world: Gen2WorldAPI = _r.open_world(0, map, cell)
	if world != null:
		world.player_facing = Gen2WorldSprite.FACING_UP
	return world


func _object_active(world: Gen2WorldAPI, index: int) -> bool:
	return (world.objects[index] as Gen2WorldObject).active


func _spoken(world: Gen2WorldAPI) -> Array[String]:
	var said: Array[String] = []
	var results: Array = world.interact()
	while not results.is_empty() and said.size() < Gen1Layout.MAX_OBJECT_EVENTS:
		said.append(_event_text(results))
		results = world.run_event_queue(true)
	return said


## The string one interaction opens with, or "" when it opened no box at all.
## [param flag] is an event flag to set first, or 0 for none.
func _scripted_box(map: int, cell: Vector2i, flag: int, owned: Dictionary = {}) -> String:
	var world: Gen2WorldAPI = _r.open_world(0, map, cell)
	if world == null:
		return ""
	if flag > 0:
		world.set_event_flag(flag)
	if not owned.is_empty():
		world.state.apply_changes({}, {}, {"items": owned})
	world.player_facing = Gen2WorldSprite.FACING_UP
	return _box_text(world)


## `YesNoChoice` answered both ways, which is the routing rather than the
## strings `tools/checks/gen1_maps.gd` already pins.
func _check_the_ghost_girl() -> void:
	for answer: int in [0, 1]:
		var world: Gen2WorldAPI = _r.open_world(0, LAVENDER_TOWN, GHOST_GIRL)
		if world == null:
			return
		world.player_facing = Gen2WorldSprite.FACING_UP
		world.interact()
		var asked: Dictionary = world.pending_script_input()
		if not _r.check(StringName(asked.get("type", &"")) == &"choice",
			"the ghost girl asked %s." % [asked]):
			return
		var said: String = _event_text(world.choose_script_input(answer))
		_r.check(said.begins_with(GHOST_ANSWERS[answer]),
			"answering %d said %s." % [answer, said])


## `wDoNotWaitForButtonPressAfterDisplayingText`, which is one box in the corpus.
func _check_a_box_owing_no_press() -> void:
	var world: Gen2WorldAPI = _r.open_world(0, MELANIE_MAP, MELANIE_CELL)
	if world == null:
		return
	world.set_event_flag(MELANIE_FLAG)
	world.player_facing = Gen2WorldSprite.FACING_UP
	var results: Array = world.interact()
	if not _r.check(not results.is_empty(), "Melanie said nothing."):
		return
	var event: Dictionary = results[0].get("event", {})
	_r.check(String(event.get("text", "")).begins_with(MELANIE_BOX),
		"Melanie said %s." % [event.get("text", "")])
	_r.check(not bool(event.get("prompt", true)), "her box still owes a press.")


## `CableClubNPC` from both sides of `EVENT_GOT_POKEDEX`, each with its own
## count of frames.
func _check_the_cable_club() -> void:
	var rows: int = 0
	for map: Gen2WorldMap in _r.data.world_maps():
		for row: Dictionary in map.texts:
			rows += 1 if int(row["command"]) == Gen1Layout.TEXT_SCRIPT_CABLE_CLUB else 0
	_r.check(rows == CABLE_CLUB_ROWS, "%d receptionists stand on a TX_SCRIPT row." % rows)
	_walk_the_receptionist(false, Gen1Layout.CABLE_CLUB_PREPARING_FRAMES, "making_preparations")
	_walk_the_receptionist(true, Gen1Layout.CABLE_CLUB_TIMEOUT_FRAMES, "area_reserved")


func _walk_the_receptionist(dex: bool, frames: int, said: String) -> void:
	var world: Gen2WorldAPI = _r.open_world(0, VIRIDIAN_POKECENTER, CABLE_CLUB_COUNTER)
	if world == null:
		return
	world.state.set_engine_flag(Gen2WorldState.ENGINE_POKEDEX, dex)
	world.player_facing = Gen2WorldSprite.FACING_UP
	var opened: Array = world.interact()
	if not _r.check(not opened.is_empty(), "the receptionist said nothing."):
		return
	_r.check(
		_event_text(opened) == _r.data.special_text("cable_club", "welcome"),
		"the receptionist opened with %s." % [_event_text(opened)]
	)
	world.run_event_queue(true)
	var wait: Dictionary = world.pending_script_wait()
	_r.check(int(wait.get("frames", 0)) == frames, "she waited %s frames." % [wait.get("frames", 0)])
	var spent: int = 0
	while not world.pending_script_wait().is_empty() and spent <= frames:
		var landed: Array = world.advance_script_wait_frame()
		spent += 1
		if not landed.is_empty():
			_r.check(
				_event_text(landed) == _r.data.special_text("cable_club", said),
				"she finished with %s." % [_event_text(landed)]
			)
	_r.check(spent == frames, "she waited %d frames rather than %d." % [spent, frames])
	world.run_event_queue(true)
	_r.check(not world.script_busy(), "the receptionist never finished.")


func _event_text(results: Array) -> String:
	return String((results[0].get("event", {}) as Dictionary).get("text", ""))


## `VendingMachineMenu`'s three `VendingPrices` rows and the purchase
## `HasEnoughMoney` gates. The box drawn is the screen's.
func _check_the_vending_machine() -> void:
	var machines: int = 0
	for map: Gen2WorldMap in _r.data.world_maps():
		for row: Dictionary in map.texts:
			machines += 1 if int(row["command"]) \
				== Gen1Layout.TEXT_SCRIPT_VENDING_MACHINE else 0
	_r.check(machines == VENDING_MACHINES, "%d machines stand on the map." % machines)
	var rows: Array = _r.data.vending_rows()
	for index: int in VENDING_PRICES.size():
		var pinned: Array = VENDING_PRICES[index]
		var row: Dictionary = rows[index] if index < rows.size() else {}
		_r.check(
			int(row.get("item", 0)) == int(pinned[0])
				and int(row.get("price", 0)) == int(pinned[1]),
			"machine row %d is %s." % [index, row]
		)
	var world: Gen2WorldAPI = _r.open_world(0, CELADON_MART_ROOF, VENDING_MACHINE)
	if world == null:
		return
	world.player_facing = Gen2WorldSprite.FACING_UP
	if not _r.check(not world.interact().is_empty(), "the machine offered nothing."):
		return
	var request: Dictionary = world.pending_runtime_request()
	_r.check(
		StringName(request.get("kind", &"")) == &"vending_requested"
			and (request.get("values", {}).get("rows", []) as Array).size() == rows.size(),
		"the machine asked for %s." % [request.get("kind", &"nothing")]
	)
	world.state.apply_changes({}, {}, {
		"money": {Gen2WorldMartHost.MONEY_ACCOUNT: VENDING_PURSE},
	})
	var drink: Dictionary = rows[0]
	var bought: Dictionary = Gen2WorldMartHost.vend(world, null, drink, false)
	_r.check(bool(bought.get("ok", false)), "the first drink refused: %s." % [bought])
	_r.check(
		world.state.item_quantity(int(drink["item"])) == 1
			and world.state.money(Gen2WorldMartHost.MONEY_ACCOUNT)
				== VENDING_PURSE - int(drink["price"]),
		"the drink cost %d." % [VENDING_PURSE - world.state.money(
			Gen2WorldMartHost.MONEY_ACCOUNT
		)]
	)
	## `HasEnoughMoney` refuses before `GiveItem` does.
	world.state.apply_changes({}, {}, {"money": {Gen2WorldMartHost.MONEY_ACCOUNT: 0}})
	_r.check(
		StringName(Gen2WorldMartHost.vend(world, null, drink, false).get("reason", &""))
			== &"insufficient_money",
		"an empty purse bought a drink."
	)
	world.complete_runtime_request({"ok": true})
	_r.check(not world.script_busy(), "the machine never closed.")


## `CeladonMartRoofScript_GiveDrinkToGirl` lists `wFilteredBagItems`, so two of
## the three drinks offer two rows; `BikeShopClerkText` lists two fixed strings.
func _check_a_script_menu() -> void:
	var world: Gen2WorldAPI = _facing_up(CELADON_MART_ROOF, CELADON_LITTLE_GIRL + Vector2i.DOWN)
	if world == null:
		return
	world.state.apply_changes({}, {}, {"items": {
		Gen1Layout.ITEM_FRESH_WATER: 1, Gen1Layout.ITEM_LEMONADE: 1,
	}})
	world.interact()
	var request: Dictionary = _runtime_request(world.choose_script_input(0))
	var values: Dictionary = request.get("values", {})
	var rows: Array = values.get("rows", [])
	if not _r.check(
		StringName(request.get("kind", &"")) == &"gen1_menu_requested"
			and _menu_names(rows) == DRINK_ROWS
			and String(values.get("text", "")).begins_with(DRINK_QUESTION),
		"the girl asked %s." % [request]
	):
		return
	world.complete_runtime_request({"ok": true, "row": 0})
	_press_past_boxes(world)
	_r.check(
		int(world.state.items().get(Gen1Layout.ITEM_FRESH_WATER, 0)) == 0
			and int(world.state.items().get(TM_ICE_BEAM, 0)) == 1
			and world.state.is_event_flag_active(TM13_FLAG),
		"the FRESH WATER left %s." % [world.state.items()]
	)
	_check_an_empty_drink_bag()
	_check_the_bike_shop_menu()


func _check_an_empty_drink_bag() -> void:
	var world: Gen2WorldAPI = _facing_up(CELADON_MART_ROOF, CELADON_LITTLE_GIRL + Vector2i.DOWN)
	if world == null:
		return
	var said: Array = world.interact()
	_r.check(
		_runtime_request(said).is_empty()
			and _event_text(said).begins_with(DRINK_THIRSTY),
		"an empty bag was offered %s." % [said]
	)


## `BikeShopMenuText`, its price, and `BikeShopCantAffordText` behind row 0.
func _check_the_bike_shop_menu() -> void:
	var world: Gen2WorldAPI = _facing_up(BIKE_SHOP, BIKE_CLERK + Vector2i.DOWN)
	if world == null:
		return
	world.interact()
	var request: Dictionary = _runtime_request(world.run_event_queue(true))
	var values: Dictionary = request.get("values", {})
	var labels: Array = values.get("labels", [])
	if not _r.check(
		StringName(request.get("kind", &"")) == &"gen1_menu_requested"
			and _menu_names(values.get("rows", [])) == BIKE_MENU_ROWS
			and labels.size() == 1
			and String(((labels[0] as Dictionary)["rows"] as Array)[0]) == BIKE_PRICE,
		"the clerk offered %s." % [request]
	):
		return
	var bought: Array = world.complete_runtime_request({"ok": true, "row": 0})
	_r.check(_event_text(bought).begins_with(BIKE_TOO_DEAR),
		"row 0 said %s." % [_event_text(bought)])
	world = _facing_up(BIKE_SHOP, BIKE_CLERK + Vector2i.DOWN)
	if world == null:
		return
	world.interact()
	world.run_event_queue(true)
	var left: Array = world.complete_runtime_request({"ok": true, "row": -1})
	_r.check(_event_text(left).begins_with(BIKE_COME_AGAIN),
		"the B press said %s." % [_event_text(left)])
	_r.note("gen1 walk the drink menu, the empty bag and the BIKE SHOP's own two rows")


func _press_past_boxes(world: Gen2WorldAPI) -> void:
	for _press: int in MENU_ARM_BOXES:
		var input: Dictionary = world.pending_script_input()
		if input.is_empty() and world.pending_runtime_request().is_empty():
			return
		world.choose_script_input(0 if StringName(input.get("type", &"")) == &"choice" else -1)


## `GiveFossilToCinnabarLab`: the bag's fossils are the rows, the one chosen is
## spent, and `wFossilMon` is what the next visit hands back.
func _check_the_fossil_lab() -> void:
	var world: Gen2WorldAPI = _facing_up(
		CINNABAR_LAB_FOSSIL_ROOM, FOSSIL_SCIENTIST + Vector2i.DOWN
	)
	if world == null:
		return
	world.state.apply_changes({}, {}, {"items": {DOME_FOSSIL: 1, OLD_AMBER: 1}})
	## The box is drawn over `.Text`, so the menu opens on the row's own press.
	var request: Dictionary = _runtime_request(world.interact())
	if not _r.check(
		StringName(request.get("kind", &"")) == &"gen1_menu_requested"
			and _menu_names(request.get("values", {}).get("rows", [])) == FOSSIL_ROWS,
		"the lab offered %s." % [request]
	):
		return
	world.complete_runtime_request({"ok": true, "row": 0})
	_press_past_boxes(world)
	_r.check(
		int(world.state.items().get(DOME_FOSSIL, 0)) == 0
			and world.state.is_event_flag_active(FOSSIL_GIVEN_FLAG)
			and int(world.gen1_fossil.get("mon", 0)) == KABUTO_INDEX,
		"the DOME FOSSIL left %s and %s." % [world.state.items(), world.gen1_fossil]
	)
	_check_the_revived_fossil(world)


func _check_the_revived_fossil(world: Gen2WorldAPI) -> void:
	world.state.set_event_flag(FOSSIL_REVIVING_FLAG, false)
	world.player_facing = Gen2WorldSprite.FACING_UP
	world.interact()
	var request: Dictionary = _runtime_request(world.run_event_queue(true))
	_r.check(
		StringName(request.get("kind", &"")) == &"pokemon_requested"
			and int(request.get("values", {}).get("pokemon", 0)) == KABUTO_DEX,
		"the revived fossil was %s." % [request]
	)
	_r.note("gen1 walk the fossil lab: two fossils listed, one taken, KABUTO back")


## `CeruleanBadgeHouseMiddleAgedManText`: eight badges, and B the way out.
func _check_the_badge_house() -> void:
	var world: Gen2WorldAPI = _facing_up(BADGE_HOUSE, BADGE_MAN + Vector2i.DOWN)
	if world == null:
		return
	world.interact()
	world.run_event_queue(true)
	var request: Dictionary = _runtime_request(world.run_event_queue(true))
	var rows: Array = request.get("values", {}).get("rows", [])
	if not _r.check(
		StringName(request.get("kind", &"")) == &"gen1_list_menu_requested"
			and rows.size() == BADGE_COUNT
			and String((rows[0] as Dictionary)["name"]) == BADGE_FIRST,
		"the badge man offered %s." % [request]
	):
		return
	var said: Array = world.complete_runtime_request({"ok": true, "row": 0})
	if not _r.check(not _event_text(said).is_empty(),
		"the first badge said nothing: %s." % [said]):
		return
	var again: Dictionary = _runtime_request(world.run_event_queue(true))
	_r.check(StringName(again.get("kind", &"")) == &"gen1_list_menu_requested",
		"the list did not reopen: %s." % [again])
	var left: Array = world.complete_runtime_request({"ok": true, "row": -1})
	_r.check(_event_text(left).begins_with(BADGE_FAREWELL),
		"the B press said %s." % [_event_text(left)])
	_r.note("gen1 walk the badge house: %d badges, one read, the list reopened" % BADGE_COUNT)


func _menu_names(rows: Array) -> Array[String]:
	var out: Array[String] = []
	for row: Dictionary in rows:
		out.append(String(row.get("text", "")))
	return out


func _check_an_elevator() -> void:
	var arrived: Gen2WorldAPI = _ride_into_the_elevator()
	if arrived == null:
		return
	_r.check(_elevator_exit(arrived) == [CELADON_MART_1F, ELEVATOR_DOOR_WARP],
		"an unused car opened onto %s." % [_elevator_exit(arrived)])

	var world: Gen2WorldAPI = _ride_into_the_elevator()
	if world == null:
		return
	world.player_cell = ELEVATOR_SIGN_CELL
	world.player_facing = Gen2WorldSprite.FACING_UP
	if not _r.check(not world.interact().is_empty(), "the car offered nothing."):
		return
	var request: Dictionary = world.pending_runtime_request()
	var floors: Array = request.get("values", {}).get("floors", [])
	if not _r.check(
		StringName(request.get("kind", &"")) == &"elevator_requested"
			and floors.size() == ELEVATOR_FLOOR_COUNT,
		"the car asked for %s." % [request.get("kind", &"nothing")]
	):
		return
	world.complete_runtime_request({"ok": true})
	_r.check(_elevator_exit(world) == [CELADON_MART_1F, ELEVATOR_DOOR_WARP],
		"a cancelled ride opened onto %s." % [_elevator_exit(world)])

	world = _ride_into_the_elevator()
	if world == null:
		return
	world.player_cell = ELEVATOR_SIGN_CELL
	world.player_facing = Gen2WorldSprite.FACING_UP
	world.interact()
	var chosen: Dictionary = (world.pending_runtime_request()["values"]
		as Dictionary)["floors"][ELEVATOR_CHOSEN_ROW]
	world.complete_runtime_request({"ok": true, "floor": chosen})
	_r.check(_elevator_exit(world) == [int(chosen["map"]), int(chosen["warp"])],
		"the ride opened onto %s, wanting %s." % [
			_elevator_exit(world), [int(chosen["map"]), int(chosen["warp"])],
		])


func _elevator_exit(world: Gen2WorldAPI) -> Array:
	world.player_cell = ELEVATOR_EXIT_CELL
	world.player_facing = Gen2WorldSprite.FACING_DOWN
	var taken: Dictionary = world.try_warp()
	if not bool(taken.get("ok", false)):
		return [taken.get("reason", &"refused")]
	var landed: Dictionary = taken["destination"]
	return [world.current_map.number, world.warp_index_at(
		Vector2i(int(landed["x"]), int(landed["y"]))
	) - 1]


func _ride_into_the_elevator() -> Gen2WorldAPI:
	var world: Gen2WorldAPI = _r.open_world(0, CELADON_MART_1F, ELEVATOR_DOOR_CELL)
	if world == null:
		return null
	world.player_facing = Gen2WorldSprite.FACING_UP
	var taken: Dictionary = world.try_warp()
	if not _r.check(
		bool(taken.get("ok", false)) and world.current_map.number == CELADON_MART_ELEVATOR,
		"the lift door refused: %s." % [taken.get("reason", &"refused")]
	):
		return null
	return world


## The salesman with the money and without it, and the refusal a bought
## MAGIKARP leaves behind.
func _check_the_magikarp_salesman() -> void:
	var world: Gen2WorldAPI = _magikarp_offer(MAGIKARP_PRICE - 1)
	if world == null:
		return
	var refused: Array = world.choose_script_input(0)
	_r.check(
		_runtime_request(refused).is_empty()
			and world.state.money(Gen2WorldMartHost.MONEY_ACCOUNT) == MAGIKARP_PRICE - 1,
		"a short purse bought a MAGIKARP: %s." % [refused]
	)
	world = _magikarp_offer(MAGIKARP_PURSE)
	if world == null:
		return
	var offer: String = String(world.pending_script_input().get("text", ""))
	var request: Dictionary = _runtime_request(world.choose_script_input(0))
	var values: Dictionary = request.get("values", {})
	_r.check(
		StringName(request.get("kind", &"")) == &"pokemon_requested"
			and int(values.get("pokemon", 0)) == MAGIKARP_DEX
			and int(values.get("level", 0)) == MAGIKARP_LEVEL,
		"the salesman raised %s." % [request]
	)
	world.complete_runtime_request({"ok": true, "accepted": true})
	_r.check(
		world.state.money(Gen2WorldMartHost.MONEY_ACCOUNT) == MAGIKARP_PURSE - MAGIKARP_PRICE,
		"the MAGIKARP cost %d." % [
			MAGIKARP_PURSE - world.state.money(Gen2WorldMartHost.MONEY_ACCOUNT),
		]
	)
	var again: String = _event_text(world.interact())
	_r.check(not again.is_empty() and again != offer,
		"a bought MAGIKARP was offered again: %s." % [again])
	_r.note("gen1 walk the MAGIKARP salesman with %d and with %d" % [
		MAGIKARP_PURSE, MAGIKARP_PRICE - 1,
	])


## `Museum1FScientist1Text`, the corpus's one `StartSimulatingJoypadStates`: a
## refusal is proved by the player standing a cell lower, mid-step.
func _check_the_museum_ticket() -> void:
	var world: Gen2WorldAPI = _museum_offer()
	if world == null:
		return
	var refused: Array = world.choose_script_input(1)
	_r.check(_event_text(refused).begins_with(MUSEUM_REFUSED),
		"the refusal said %s." % [_event_text(refused)])
	var walked: Array = world.run_event_queue(true)
	_r.check(
		world.player_cell == MUSEUM_COUNTER + Vector2i.DOWN
			and world.scripted_movement_in_progress(),
		"the refusal left the player at %s." % [world.player_cell]
	)
	_r.check(world.state.money(Gen2WorldMartHost.MONEY_ACCOUNT) == MUSEUM_TICKET,
		"a refused ticket cost %s." % [walked])
	world = _museum_offer()
	if world == null:
		return
	_r.check(_event_text(world.choose_script_input(0)).begins_with(MUSEUM_BOUGHT),
		"the ticket was not sold.")
	world.run_event_queue(true)
	_r.check(
		world.state.money(Gen2WorldMartHost.MONEY_ACCOUNT) == 0
			and world.state.is_event_flag_active(MUSEUM_TICKET_FLAG)
			and world.player_cell == MUSEUM_COUNTER,
		"the sale left %d and flag %s." % [
			world.state.money(Gen2WorldMartHost.MONEY_ACCOUNT),
			world.state.is_event_flag_active(MUSEUM_TICKET_FLAG),
		]
	)
	_check_the_museum_counter()
	_r.note("gen1 walk the MUSEUM ticket bought and refused")


func _check_the_museum_counter() -> void:
	var world: Gen2WorldAPI = _r.open_world(0, MUSEUM_1F, MUSEUM_BEHIND_COUNTER)
	if world == null:
		return
	world.player_facing = Gen2WorldSprite.FACING_LEFT
	world.interact()
	var back: String = String(world.pending_script_input().get("text", ""))
	_r.check(back.begins_with(MUSEUM_BACK_WAY), "the back way said %s." % [back])
	world = _r.open_world(0, MUSEUM_1F, MUSEUM_BELOW_COUNTER)
	if world == null:
		return
	world.player_facing = Gen2WorldSprite.FACING_UP
	var side: String = _box_text(world)
	_r.check(side.begins_with(MUSEUM_OTHER_SIDE), "the near side said %s." % [side])


func _museum_offer() -> Gen2WorldAPI:
	var world: Gen2WorldAPI = _r.open_world(0, MUSEUM_1F, MUSEUM_COUNTER)
	if world == null:
		return null
	world.player_facing = Gen2WorldSprite.FACING_RIGHT
	world.state.apply_changes({}, {}, {
		"money": {Gen2WorldMartHost.MONEY_ACCOUNT: MUSEUM_TICKET},
	})
	var window: Dictionary = _first_event(world.interact(), &"money_window_opened")
	_r.check(int(window.get("money", -1)) == MUSEUM_TICKET,
		"the ticket drew %s over the map." % [window])
	return world if _r.check(
		String(world.pending_script_input().get("text", "")).begins_with(MUSEUM_OFFER),
		"the ticket asked %s." % [world.pending_script_input()]
	) else null


## The row up to its YES/NO, which the offer itself is the question of, with
## the balance window checked on the way.
func _magikarp_offer(purse: int) -> Gen2WorldAPI:
	var world: Gen2WorldAPI = _r.open_world(
		0, MT_MOON_POKECENTER, MAGIKARP_SELLER + Vector2i.LEFT
	)
	if world == null:
		return null
	world.player_facing = Gen2WorldSprite.FACING_RIGHT
	world.state.apply_changes({}, {}, {
		"money": {Gen2WorldMartHost.MONEY_ACCOUNT: purse},
	})
	var results: Array = world.interact()
	var window: Dictionary = _first_event(results, &"money_window_opened")
	_r.check(int(window.get("money", -1)) == purse,
		"the deal drew %s over the map." % [window])
	return world if _r.check(
		not String(world.pending_script_input().get("text", "")).is_empty(),
		"the deal asked nothing: %s." % [results]
	) else null


func _check_the_coin_clerks() -> void:
	var world: Gen2WorldAPI = _clerk_world(COIN_PRICE, 0, 1)
	if world == null:
		return
	var window: Dictionary = _first_event(world.interact(), &"money_window_opened")
	_r.check(
		StringName(window.get("kind", &"")) == &"game_corner"
			and int(window.get("money", -1)) == COIN_PRICE
			and int(window.get("coins", -1)) == 0,
		"the clerk drew %s over the map." % [window]
	)
	if not _r.check(world.script_input_waiting(), "the clerk asked nothing."):
		return
	var said: String = _event_text(world.choose_script_input(0))
	_r.check(said.begins_with(CLERK_SOLD), "she answered YES with %s." % [said])
	_r.check(
		world.state.coins() == COINS_BOUGHT
			and world.state.money(Gen2WorldMartHost.MONEY_ACCOUNT) == 0,
		"%d coins cost %d." % [world.state.coins(), COIN_PRICE - world.state.money(
			Gen2WorldMartHost.MONEY_ACCOUNT
		)]
	)
	for row: Array in [
		[COIN_PRICE - 1, 0, 1, CLERK_SHORT], [COIN_PRICE, COIN_CASE_CEILING, 1,
		CLERK_CASE_FULL], [COIN_PRICE, 0, 0, CLERK_NO_CASE],
	]:
		_check_a_refused_clerk(int(row[0]), int(row[1]), int(row[2]), String(row[3]))
	_check_the_gentleman()
	_r.note("gen1 walk the coin clerk: %d coins for %d, and three refusals" % [
		COINS_BOUGHT, COIN_PRICE,
	])


func _check_a_refused_clerk(money: int, coins: int, cases: int, wanted: String) -> void:
	var world: Gen2WorldAPI = _clerk_world(money, coins, cases)
	if world == null:
		return
	world.interact()
	if not _r.check(world.script_input_waiting(), "the clerk asked nothing."):
		return
	var said: String = _event_text(world.choose_script_input(0))
	_r.check(said.begins_with(wanted), "with %d, %d coins and %d cases she said %s." % [
		money, coins, cases, said,
	])
	_r.check(world.state.coins() == coins, "a refusal left %d coins." % world.state.coins())


func _clerk_world(money: int, coins: int, cases: int) -> Gen2WorldAPI:
	var world: Gen2WorldAPI = _r.open_world(0, GAME_CORNER, GAME_CORNER_CLERK)
	if world == null:
		return null
	world.player_facing = Gen2WorldSprite.FACING_UP
	world.state.apply_changes({}, {}, {
		"money": {Gen2WorldMartHost.MONEY_ACCOUNT: money},
		"coins": coins,
		"items": {Gen1Layout.ITEM_COIN_CASE: cases},
	})
	return world


func _check_the_gentleman() -> void:
	for coins: int in [COIN_CASE_CEILING, COIN_CASE_CEILING + 1]:
		var world: Gen2WorldAPI = _r.open_world(0, GAME_CORNER, GAME_CORNER_GENTLEMAN)
		if world == null:
			return
		world.player_facing = Gen2WorldSprite.FACING_UP
		world.state.apply_changes({}, {}, {"coins": coins, "items": {Gen1Layout.ITEM_COIN_CASE: 1}})
		var said: Array[String] = _spoken(world)
		var refused: bool = coins == COIN_CASE_CEILING
		_r.check(
			said.size() == 2 and (said[1].begins_with(GENTLEMAN_REFUSED) if refused
				else said[1].ends_with(GENTLEMAN_PAID)),
			"with %d coins the gentleman said %s." % [coins, said]
		)
		_r.check(
			world.state.coins() == (coins if refused else mini(
				coins + COINS_GIVEN, Gen1Layout.COIN_CEILING
			)) and world.event_flag_active(GENTLEMAN_FLAG) != refused,
			"with %d coins he left %d." % [coins, world.state.coins()]
		)


func _first_event(results: Array, type: StringName) -> Dictionary:
	for row: Dictionary in results:
		for event: Dictionary in row.get("events", []) as Array:
			if StringName(event.get("type", &"")) == type:
				return event
	return {}


## `PrizeDifferentMenuPtrs`' three lists with `PrizeMonLevelDictionary`'s level
## on every Pokemon row, and the vendor whose place picks each one.
func _check_the_prize_counter() -> void:
	var pinned: Array = PRIZE_MENUS[_r.game_id]
	var menus: Array = _r.data.prize_menus()
	if not _r.check(menus.size() == pinned.size(), "%d prize menus." % menus.size()):
		return
	for index: int in pinned.size():
		var menu: Dictionary = menus[index]
		_r.check(
			bool(menu["tms"]) == (index == Gen1Layout.PRIZE_TM_MENU),
			"menu %d is the wrong kind." % index
		)
		var rows: Array = menu["rows"]
		for row: int in (pinned[index] as Array).size():
			var want: Array = (pinned[index] as Array)[row]
			var got: Dictionary = rows[row]
			var name: String = _r.data.item_name(int(got["item"])) if bool(menu["tms"]) \
				else String(_r.data.species(int(got["item"])).get("name", ""))
			_r.check(
				[name, int(got["cost"]), int(got["level"])] == want,
				"prize %d/%d is %s, pinned %s." % [
					index, row, [name, int(got["cost"]), int(got["level"])], want,
				]
			)
	for index: int in PRIZE_VENDORS.size():
		var world: Gen2WorldAPI = _r.open_world(0, PRIZE_ROOM, PRIZE_VENDORS[index])
		if world == null:
			return
		world.player_facing = Gen2WorldSprite.FACING_UP
		if not _r.check(not world.interact().is_empty(), "vendor %d said nothing." % index):
			continue
		var values: Dictionary = world.pending_runtime_request().get("values", {})
		_r.check(
			int(values.get("menu", -1)) == index
				and (values.get("rows", []) as Array).size() == Gen1Layout.PRIZE_ROWS,
			"vendor %d opened menu %s." % [index, values.get("menu", -1)]
		)
		world.complete_runtime_request({"ok": true})
		_r.check(not world.script_busy(), "vendor %d never closed." % index)


## `DoInGameTradeDialogue` walked whole: the offer both mon names fill, the
## refusal, a species the row does not want, the swap and the line the trader has
## once `wCompletedInGameTradeFlags` holds the bit.
func _check_a_trade() -> void:
	var trade: Dictionary = _r.data.world_trade(TRADE_ROW)
	var wanted: int = int(trade.get("requested_species", 0))
	var asked: String = _trade_offer()
	_r.check(
		asked.contains(String(_r.data.species(wanted).get("name", "")))
		and asked.contains(String(_r.data.species(
			int(trade.get("offered_species", 0))
		).get("name", ""))),
		"the trader offered %s." % [asked]
	)
	for row: Array in [
		[1, 0, "cancel_", "a refused trade"],
		[0, 0, "cancel_", "a cancelled list"],
		[0, TRADE_WRONG_SPECIES, "wrong_", "the wrong species"],
	]:
		var said: String = _event_text(_trade_walk(int(row[0]), int(row[1])))
		_r.check(said == _trade_text(String(row[2])), "%s said %s." % [row[3], said])
	_walk_the_swap(wanted)


## The three boxes behind a list that came back with the row's own species, and
## the once-only bit the swap sets in front of them.
func _walk_the_swap(wanted: int) -> void:
	var world: Gen2WorldAPI = _facing_up(ROUTE_11_GATE_2F, TRADE_YOUNGSTER)
	if world == null:
		return
	world.interact()
	world.choose_script_input(0)
	var cable: String = _event_text(world.complete_runtime_request({
		"ok": true, "party_index": TRADE_PARTY_SLOT, "species": wanted,
	}))
	_r.check(
		world.state.npc_trade_done(TRADE_ROW),
		"the swap left `wCompletedInGameTradeFlags` clear."
	)
	_r.check(
		cable == _r.data.special_text("npc_trade", "cable"),
		"the swap opened with %s." % [cable]
	)
	var request: Dictionary = _runtime_request(world.run_event_queue(true))
	if not _r.check(
		StringName(request.get("kind", &"")) == &"trade_requested"
		and int((request.get("values", {}) as Dictionary).get("party_index", -1))
			== TRADE_PARTY_SLOT,
		"the swap raised %s." % [request]
	):
		return
	var receipt: String = _event_text(
		world.complete_runtime_request({"ok": true, "accepted": true})
	)
	_r.check(
		receipt == _trade_filled(_r.data.special_text("npc_trade", "traded_for")),
		"the movie was followed by %s." % [receipt]
	)
	var thanks: String = _event_text(world.run_event_queue(true))
	_r.check(thanks == _trade_text("complete_"), "the trader said %s." % [thanks])
	world.run_event_queue(true)
	var again: String = _trade_offer(world)
	_r.check(again == _trade_text("after_"), "a done trade said %s." % [again])
	_r.note("gen1 walk one in-game trade, both refusals and a wrong species")


## The question the youngster opens with, on a world that may already carry the
## bit.
func _trade_offer(world: Gen2WorldAPI = null) -> String:
	var open: Gen2WorldAPI = world if world != null \
		else _facing_up(ROUTE_11_GATE_2F, TRADE_YOUNGSTER)
	if open == null:
		return ""
	var results: Array = open.interact()
	var asked: Dictionary = open.pending_script_input()
	return String(asked["text"]) if asked.has("text") else _event_text(results)


## One walk of the row: [param answer] is the YES/NO row and [param species] the
## member the party list came back with, or 0 for a list that was cancelled.
func _trade_walk(answer: int, species: int) -> Array:
	var world: Gen2WorldAPI = _facing_up(ROUTE_11_GATE_2F, TRADE_YOUNGSTER)
	if world == null:
		return []
	world.interact()
	var results: Array = world.choose_script_input(answer)
	if answer != 0:
		return results
	return world.complete_runtime_request({
		"ok": true, "party_index": -1 if species < 1 else TRADE_PARTY_SLOT,
		"species": species,
	})


## One `TradeTextPointers` cell of row 0's own dialog set, with both mon names
## already in it.
func _trade_text(prefix: String) -> String:
	var trade: Dictionary = _r.data.world_trade(TRADE_ROW)
	return _trade_filled(_r.data.special_text(
		"npc_trade", "%s%d" % [prefix, int(trade.get("dialog", 0)) + 1]
	))


func _trade_filled(text: String) -> String:
	var trade: Dictionary = _r.data.world_trade(TRADE_ROW)
	var out: String = text
	for row: Array in [
		[Gen1Layout.TRADE_GIVE_NAME, int(trade.get("requested_species", 0))],
		[Gen1Layout.TRADE_RECEIVE_NAME, int(trade.get("offered_species", 0))],
	]:
		out = Gen2TextStream.fill_all_markers(
			out, "%s%04X>" % [Gen2TextStream.RAM_MARKER, int(row[0])],
			String(_r.data.species(int(row[1])).get("name", ""))
		)
	return Gen2TextStream.fill_names(out, {"player": Gen2WorldScriptRunner.UNNAMED})


## `DaycareGentlemanText` walked both ways: the offer, the party list and
## `MoveMon PARTY_TO_DAYCARE`, then the growth, `HasEnoughMoney` and the way
## back out. `IncrementDayCareMonExp` is what makes the second half possible.
## `NameRatersHouseNameRaterText` end to end, and the OT test both ways.
func _check_the_name_rater() -> void:
	var boxes: Dictionary = _name_rater_boxes()
	if boxes.is_empty():
		return
	_check_the_name_rater_refuses(boxes)
	var world: Gen2WorldAPI = _name_rater_world()
	if world == null:
		return
	world.interact()
	_r.check(
		_name_rater_asked(world) == _name_rater_text(boxes, "hello"),
		"the rater opened on something else."
	)
	_r.check(
		_event_text(world.choose_script_input(0)) == _name_rater_text(boxes, "which"),
		"YES asked for no member."
	)
	world.run_event_queue(true)
	_r.check(
		StringName(world.pending_runtime_request().get("kind", &""))
			== &"party_selection_requested",
		"the question opened no party list."
	)
	world.complete_runtime_request(_name_rater_row(true))
	_r.check(
		_name_rater_asked(world)
			== _name_rater_text(boxes, "decent", NAME_RATER_SPECIES_NAME),
		"a member of the player's own was not offered a rename."
	)
	_r.check(
		_event_text(world.choose_script_input(0)) == _name_rater_text(boxes, "what"),
		"YES did not ask for a name."
	)
	world.run_event_queue(true)
	_r.check(
		StringName(world.pending_runtime_request().get("kind", &""))
			== &"gen1_nickname_requested",
		"the question opened no keyboard."
	)
	_r.check(
		_event_text(world.complete_runtime_request({
			"ok": true, "name": NAME_RATER_NICKNAME,
		})) == _name_rater_text(boxes, "renamed", NAME_RATER_NICKNAME),
		"the entry was not read back."
	)
	_r.note("gen1 walk the NAME RATER: a rename, a traded member and three refusals")


func _check_the_name_rater_refuses(boxes: Dictionary) -> void:
	var come_again: String = _name_rater_text(boxes, "come_again")
	var world: Gen2WorldAPI = _name_rater_world()
	if world == null:
		return
	world.interact()
	_r.check(
		_event_text(world.choose_script_input(1)) == come_again,
		"NO said something else."
	)
	for row: Dictionary in [{"ok": true, "party_index": -1}, _name_rater_row(false)]:
		var refused: Gen2WorldAPI = _name_rater_world()
		if refused == null:
			return
		refused.interact()
		refused.choose_script_input(0)
		refused.run_event_queue(true)
		var said: String = _event_text(refused.complete_runtime_request(row))
		var wanted: String = come_again if int(row.get("party_index", -1)) < 0 \
			else _name_rater_text(boxes, "impeccable", NAME_RATER_SPECIES_NAME)
		_r.check(said == wanted, "the list was answered with %s." % said)
	var blank: Gen2WorldAPI = _name_rater_world()
	if blank == null:
		return
	blank.interact()
	blank.choose_script_input(0)
	blank.run_event_queue(true)
	blank.complete_runtime_request(_name_rater_row(true))
	blank.choose_script_input(0)
	blank.run_event_queue(true)
	_r.check(
		_event_text(blank.complete_runtime_request({"ok": true, "name": ""})) == come_again,
		"an empty entry was not refused."
	)


func _name_rater_row(mine: bool) -> Dictionary:
	return {
		"ok": true, "party_index": 0, "nickname": NAME_RATER_SPECIES_NAME,
		"ot_id": NAME_RATER_ID if mine else NAME_RATER_ID + 1,
		"original_trainer": NAME_RATER_TRAINER,
	}


## What the box over a YES/NO says: the pending input's text, not the step's.
func _name_rater_asked(world: Gen2WorldAPI) -> String:
	return String(world.pending_script_input().get("text", ""))


func _name_rater_world() -> Gen2WorldAPI:
	var world: Gen2WorldAPI = _r.open_world(0, NAME_RATER_MAP, NAME_RATER_CELL)
	if world == null:
		return null
	world.player_facing = Gen2WorldSprite.FACING_LEFT
	world.set_player_name(NAME_RATER_TRAINER)
	world.set_player_id(NAME_RATER_ID)
	return world


## The row's own boxes, by where each stands in the tree: the shape is pinned too.
func _name_rater_boxes() -> Dictionary:
	var map: Gen2WorldMap = _r.data.world_map(0, NAME_RATER_MAP)
	var nodes: Variant = map.text_at(NAME_RATER_TEXT).get("script", []) if map != null else []
	if not nodes is Array or (nodes as Array).is_empty():
		_r.fail("the NAME RATER's row decoded to nothing.")
		return {}
	var rows: Array = nodes as Array
	var offer: Dictionary = rows[-1]
	var listed: Dictionary = (offer.get("yes", []) as Array)[-1]
	var ot: Dictionary = (listed.get("else", []) as Array)[-1]
	var nicer: Dictionary = (ot.get("else", []) as Array)[-1]
	var keyboard: Dictionary = (nicer.get("yes", []) as Array)[-1]
	return {
		"hello": (rows[0] as Dictionary).get("text", ""),
		"come_again": ((offer.get("no", []) as Array)[0] as Dictionary).get("text", ""),
		"which": ((offer.get("yes", []) as Array)[0] as Dictionary).get("text", ""),
		"impeccable": ((ot.get("then", []) as Array)[0] as Dictionary).get("text", ""),
		"decent": ((ot.get("else", []) as Array)[0] as Dictionary).get("text", ""),
		"what": ((nicer.get("yes", []) as Array)[0] as Dictionary).get("text", ""),
		"renamed": ((keyboard.get("else", []) as Array)[0] as Dictionary).get("text", ""),
	}


func _name_rater_text(boxes: Dictionary, name: String, ram: String = "") -> String:
	var text: String = Gen2TextStream.fill_names(
		String(boxes.get(name, "")), {"player": NAME_RATER_TRAINER}
	)
	var layout: Dictionary = Gen1Layout.for_id(_r.game_id)
	for buffer: String in ["name_buffer", "entry_buffer"]:
		var marker: String = "%s%04X>" % [
			Gen2TextStream.RAM_MARKER, int(layout[buffer])
		]
		text = Gen2TextStream.fill_all_markers(text, marker, ram)
	return text


func _check_the_day_care() -> void:
	_check_the_day_care_refuses()
	var world: Gen2WorldAPI = _day_care_world(0)
	if world == null:
		return
	var save: Gen2SaveData = Gen2SaveStore.create_development_save(_r.data, 0)
	if not _r.check(save != null, "no development save."):
		return
	world.set_party_summary(save.party.size(), false, [] as Array[int], _party_moves(save))
	world.interact()
	_r.check(
		_event_text(world.choose_script_input(0)) == _day_care_text("which_mon"),
		"the gentleman asked for no member."
	)
	world.run_event_queue(true)
	var deposited: String = Gen2SaveMon.display_name(save.party[0], _r.data)
	_r.check(
		_event_text(world.complete_runtime_request({
			"ok": true, "party_index": 0, "nickname": deposited,
		})) == _day_care_text("will_look_after", deposited),
		"the gentleman took it without saying so."
	)
	world.run_event_queue(true)
	_r.check(
		_event_text(_day_care_move(world, save)) == _day_care_text("come_see_me"),
		"the deposit ended on nothing."
	)
	_r.check(
		world.state.day_care_has_mon(Gen2WorldDayCare.SLOT_MAN)
			and save.party.size() == DAYCARE_PARTY - 1,
		"the deposit left %d in the party." % save.party.size()
	)
	_check_the_day_care_counts_steps(world)
	_check_the_day_care_hands_it_back(save)
	_check_the_day_care_holds_on()
	_r.note("gen1 walk the DAYCARE: a deposit, three refusals and a %d withdrawal"
		% DAYCARE_PRICE)


## The two boxes that end the visit where it stands: a full party never reaches
## the price at all, and a slot that has not grown says so before the question.
func _check_the_day_care_holds_on() -> void:
	for row: Array in [
		[Gen2SaveData.MAX_PARTY, DAYCARE_GROWN_LEVEL, "no_room"],
		[DAYCARE_PARTY, DAYCARE_LEVEL, "needs_more_time"],
	]:
		var world: Gen2WorldAPI = _day_care_world(DAYCARE_PRICE)
		if world == null:
			return
		var mon: Gen2SaveMon = _grown_slot()
		mon.exp = Gen2Experience.total_exp_at(
			int(_r.data.species(DAYCARE_SPECIES).get("growth_rate", 0)), int(row[1])
		)
		world.state.set_day_care_mon(Gen2WorldDayCare.SLOT_MAN, mon)
		world.state.set_day_care_has_mon(Gen2WorldDayCare.SLOT_MAN, true)
		world.set_party_summary(int(row[0]), false)
		var opened: String = _event_text(world.interact())
		if String(row[2]) == "needs_more_time":
			_r.check(
				opened == _day_care_text("needs_more_time", DAYCARE_NICKNAME, "%3d" % 0),
				"an ungrown slot said %s." % opened
			)
			continue
		var said: String = _event_text(world.run_event_queue(true))
		_r.check(said == _day_care_text("no_room"), "a full party said %s." % said)


## The three refusals in the routine's own order: one member, a member that
## knows an HM, and a list that came back empty.
func _check_the_day_care_refuses() -> void:
	for row: Array in [
		[1, [], "only_one_mon"], [DAYCARE_PARTY, [MOVE_CUT], "knows_hm_move"],
		[DAYCARE_PARTY, [], "all_right_then"],
	]:
		var world: Gen2WorldAPI = _day_care_world(0)
		if world == null:
			return
		world.set_party_summary(
			int(row[0]), false, [] as Array[int], [row[1], row[1]]
		)
		world.interact()
		var said: String = _event_text(world.choose_script_input(0))
		if int(row[0]) > 1:
			world.run_event_queue(true)
			said = _event_text(world.complete_runtime_request({
				"ok": true, "party_index": -1 if String(row[2]) == "all_right_then" else 0,
			}))
		_r.check(said == _day_care_text(String(row[2])),
			"the %s refusal said %s." % [String(row[2]), said])
	var refused: Gen2WorldAPI = _day_care_world(0)
	if refused != null:
		refused.set_party_summary(DAYCARE_PARTY, false)
		refused.interact()
		_r.check(
			_event_text(refused.choose_script_input(1)) == _day_care_text("come_again"),
			"a refused offer said something else."
		)


## `IncrementDayCareMonExp` runs off `CountStep`'s own counter here, so what
## proves it is the owed steps turning into experience.
func _check_the_day_care_counts_steps(world: Gen2WorldAPI) -> void:
	var before: int = world.state.day_care_mon(Gen2WorldDayCare.SLOT_MAN).exp
	for _step: int in DAY_CARE_STEPS:
		world.state.count_step()
	for _step: int in world.state.take_pending_day_care_steps():
		Gen2WorldDayCare.gen1_step(world.state)
	_r.check(
		world.state.day_care_mon(Gen2WorldDayCare.SLOT_MAN).exp == before + DAY_CARE_STEPS,
		"%d steps bought no experience." % DAY_CARE_STEPS
	)


## `.daycareInUse` with a slot that has grown: the box says how many levels, the
## price is a hundred a level plus a hundred, and a short purse is refused.
func _check_the_day_care_hands_it_back(save: Gen2SaveData) -> void:
	var grown: Gen2SaveMon = _grown_slot()
	for purse: int in [DAYCARE_PRICE - 1, DAYCARE_PRICE]:
		var world: Gen2WorldAPI = _day_care_world(purse)
		if world == null:
			return
		world.state.set_day_care_mon(Gen2WorldDayCare.SLOT_MAN, grown)
		world.state.set_day_care_has_mon(Gen2WorldDayCare.SLOT_MAN, true)
		world.set_party_summary(save.party.size(), false)
		_r.check(
			_event_text(world.interact()) == _day_care_text(
				"has_grown", DAYCARE_NICKNAME,
				"%3d" % (DAYCARE_GROWN_LEVEL - DAYCARE_LEVEL)
			),
			"the gentleman did not say how much it had grown."
		)
		var asked: Dictionary = world.pending_script_input() 			if not world.run_event_queue(true).is_empty() else {}
		if not _r.check(
			String(asked.get("text", "")) == _day_care_text(
				"owe_money", "", str(DAYCARE_PRICE)
			),
			"the price was asked as %s." % [asked.get("text", "")]
		):
			return
		_day_care_payment(world, save, purse, grown)


func _day_care_payment(
	world: Gen2WorldAPI, save: Gen2SaveData, purse: int, grown: Gen2SaveMon
) -> void:
	var said: String = _event_text(world.choose_script_input(0))
	if purse < DAYCARE_PRICE:
		_r.check(said == _day_care_text("not_enough_money"),
			"a short purse was answered with %s." % said)
		return
	_r.check(said == _day_care_text("heres_your_mon"), "the receipt said %s." % said)
	var taken: Gen2SaveData = Gen2SaveData.from_dict(save.to_dict())
	world.run_event_queue(true)
	var handed: String = _event_text(_day_care_move(world, taken))
	_r.check(
		not world.state.day_care_has_mon(Gen2WorldDayCare.SLOT_MAN)
			and taken.party.size() == save.party.size() + 1
			and (taken.party[-1] as Gen2SaveMon).level == DAYCARE_GROWN_LEVEL,
		"the slot came back as %d members." % taken.party.size()
	)
	_r.check(
		world.state.money(Gen2WorldMartHost.MONEY_ACCOUNT) == purse - DAYCARE_PRICE,
		"the purse stands at %d." % world.state.money(Gen2WorldMartHost.MONEY_ACCOUNT)
	)
	_r.check(
		handed == _day_care_text("got_mon_back", Gen2SaveMon.display_name(grown, _r.data)),
		"the hand-over said %s." % handed
	)


## The `day_care_mon_requested` the row raises, settled the way the world screen
## settles it: the party is the save's and the slot is the world's.
func _day_care_move(world: Gen2WorldAPI, save: Gen2SaveData) -> Array:
	var request: Dictionary = world.pending_runtime_request()
	if not _r.check(
		StringName(request.get("kind", &"")) == &"day_care_mon_requested",
		"the row raised %s." % [request.get("kind", &"nothing")]
	):
		return []
	var moved: Dictionary = Gen2WorldPartyHost.day_care_mon(world, save, request, false)
	_r.check(bool(moved.get("ok", false)), "the move failed: %s." % [moved])
	return moved.get("results", []) as Array


func _day_care_world(purse: int) -> Gen2WorldAPI:
	var world: Gen2WorldAPI = _r.open_world(0, DAYCARE, DAYCARE_GENTLEMAN)
	if world == null:
		return null
	world.player_facing = Gen2WorldSprite.FACING_LEFT
	world.state.apply_changes({}, {}, {
		"money": {Gen2WorldMartHost.MONEY_ACCOUNT: purse},
	})
	return world


## The slot as it stands after enough experience for three levels.
func _grown_slot() -> Gen2SaveMon:
	var mon: Gen2SaveMon = Gen2SaveMon.new()
	mon.species = DAYCARE_SPECIES
	mon.level = DAYCARE_LEVEL
	mon.nickname = DAYCARE_NICKNAME
	mon.moves = [MOVE_CUT, 0, 0, 0]
	mon.pp = [1, 0, 0, 0]
	mon.exp = Gen2Experience.total_exp_at(
		int(_r.data.species(DAYCARE_SPECIES).get("growth_rate", 0)), DAYCARE_GROWN_LEVEL
	)
	return mon


func _party_moves(save: Gen2SaveData) -> Array:
	var out: Array = []
	for mon: Gen2SaveMon in save.party:
		out.append(mon.moves.duplicate())
	return out


func _day_care_text(name: String, ram: String = "", number: String = "") -> String:
	var text: String = Gen2TextStream.fill_names(
		_r.data.day_care_text(name),
		{"player": Gen2WorldScriptRunner.UNNAMED}
	)
	if not ram.is_empty():
		text = Gen2TextStream.fill_all_markers(text, Gen2TextStream.RAM_MARKER, ram)
	if not number.is_empty():
		text = Gen2TextStream.fill_all_markers(text, Gen2TextStream.NUMBER_MARKER, number)
	return text


## The argument column a hidden event hands its routine is not a facing:
## `PrintRedSNESText` answers from either side of its own cell.
func _check_a_hidden_object() -> void:
	for step: Vector2i in [Vector2i.UP, Vector2i.LEFT]:
		var world: Gen2WorldAPI = _r.open_world(0, REDS_HOUSE_2F, SNES_CELL - step)
		if world == null:
			return
		world.player_facing = _facing_for(step)
		var box: String = _box_text(world)
		_r.check(box.begins_with(SNES_BOX % Gen2WorldScriptRunner.UNNAMED),
			"the SNES said %s facing %s." % [box, step])


## `TextScript_PokemonCenterPC` and `TextScript_ItemStoragePC`: each prints the
## machine's own boot line and then hands the world a `pc_requested`.
## `OpenPokemonCenterPC`'s `cp SPRITE_FACING_UP` is what refuses the machine to a
## player standing beside it.
func _check_a_pc_opens() -> void:
	for machine: Array in PC_MACHINES:
		var world: Gen2WorldAPI = _facing_up(
			int(machine[0]), Vector2i(machine[1]) + Vector2i.DOWN
		)
		if world == null:
			return
		var boot: String = world.gen1_filled_text(
			_r.data.special_text(String(machine[3]), "turned_on")
		)
		var said: String = _box_text(world)
		_r.check(not boot.is_empty() and said.begins_with(boot.split("\n")[0]),
			"the %s PC opened with %s." % [machine[2], said])
		world.run_event_queue(true)
		var request: Dictionary = world.pending_runtime_request()
		_r.check(
			StringName(request.get("kind", &"")) == &"pc_requested"
				and StringName(
					(request.get("values", {}) as Dictionary).get("mode", &"")
				) == StringName(machine[2]),
			"the machine asked for %s." % [request]
		)
	_check_the_pc_refuses_a_player_beside_it()


func _check_the_pc_refuses_a_player_beside_it() -> void:
	var world: Gen2WorldAPI = _r.open_world(
		0, VIRIDIAN_POKECENTER, POKECENTER_PC_CELL + Vector2i.LEFT
	)
	if world == null:
		return
	world.player_facing = Gen2WorldSprite.FACING_RIGHT
	world.interact()
	_r.check(
		world.pending_runtime_request().is_empty(),
		"the Pokemon Center PC opened from beside it."
	)


## `HiddenItems`: the receipt names the item `GetItemName` fetched before the
## bag was asked, and the second visit says nothing at all.
func _check_a_hidden_item() -> void:
	var world: Gen2WorldAPI = _facing_up(VIRIDIAN_CITY, HIDDEN_POTION_CELL + Vector2i.DOWN)
	if world == null:
		return
	var said: Array[String] = _spoken(world)
	_r.check(said.size() == 1 and String(said[0]) == _hidden_item_box(),
		"the hidden POTION said %s." % [said])
	_r.check(int(world.state.items().get(HIDDEN_POTION, 0)) == 1,
		"the bag holds %d POTION." % int(world.state.items().get(HIDDEN_POTION, 0)))
	_r.check(world.interact().is_empty(), "the taken POTION answered twice.")


func _check_the_trash_cans() -> void:
	var city: Gen2WorldAPI = _r.open_world(0, VERMILION_CITY, VERMILION_GYM_DOOR)
	if city == null:
		return
	city.script_random = RandomNumberGenerator.new()
	city.script_random.seed = TRASH_SEED
	city.dispatch_map_entry()
	var first: int = city.state.gen1_byte(Gen2WorldAPI.GEN1_FIRST_LOCK)
	_r.check(first % 2 == 0 and first < Gen1Layout.TRASH_CANS,
		"the city rolled can %d for the first lock." % first)
	var gym: Gen2WorldAPI = _r.open_world(0, VERMILION_GYM, VERMILION_GYM_MAT, city.state)
	if gym == null:
		return
	gym.script_random = city.script_random
	gym.dispatch_map_entry()
	_r.check(gym.block_at(VERMILION_GYM_DOOR_BLOCK.x, VERMILION_GYM_DOOR_BLOCK.y)
		== VERMILION_GYM_DOOR_LOCKED, "the gym's door opened before the locks.")
	var cans: Dictionary = _trash_cans(gym)
	if not _r.check(cans.size() == Gen1Layout.TRASH_CANS, "%d cans answer." % cans.size()):
		return
	_r.check(_trash_said(gym, cans, (first + 1) % Gen1Layout.TRASH_CANS) == TRASH_NOTHING,
		"a wrong first can did not say so.")
	_r.check(_trash_said(gym, cans, first).begins_with(TRASH_FIRST_OPENED),
		"the first lock did not open.")
	_r.check(gym.event_flag_active(Gen1Layout.LOCK_1ST_EVENT), "EVENT_1ST_LOCK_OPENED is clear.")
	var second: int = gym.state.gen1_byte(Gen2WorldAPI.GEN1_SECOND_LOCK)
	var wrong: int = (second + 1) % Gen1Layout.TRASH_CANS
	while wrong == gym.state.gen1_byte(Gen2WorldAPI.GEN1_SECOND_LOCK_ALT):
		wrong = (wrong + 1) % Gen1Layout.TRASH_CANS
	_r.check(_trash_said(gym, cans, wrong).begins_with(TRASH_RESET), "a wrong second can did not reset.")
	_r.check(not gym.event_flag_active(Gen1Layout.LOCK_1ST_EVENT), "the reset kept the first lock.")
	first = gym.state.gen1_byte(Gen2WorldAPI.GEN1_FIRST_LOCK)
	_r.check(_trash_said(gym, cans, first).begins_with(TRASH_FIRST_OPENED),
		"the first lock did not open again.")
	second = gym.state.gen1_byte(Gen2WorldAPI.GEN1_SECOND_LOCK)
	if not _r.check(cans.has(second), "the second lock is under can %d." % second):
		return
	_r.check(_trash_said(gym, cans, second).begins_with(TRASH_DONE), "the second lock did not open.")
	_r.check(gym.event_flag_active(Gen1Layout.LOCK_2ND_EVENT), "EVENT_2ND_LOCK_OPENED is clear.")
	_r.check(gym.gen1_map_load_pending(), "the door's own bit was not set back.")
	gym.dispatch_sight_events()
	_r.check(gym.block_at(VERMILION_GYM_DOOR_BLOCK.x, VERMILION_GYM_DOOR_BLOCK.y)
		== VERMILION_GYM_DOOR_OPEN, "the door stayed shut behind the second lock.")
	_r.check(_trash_said(gym, cans, first) == TRASH_NOTHING, "a can still answers after the door.")
	_r.note("gen1 trash cans: first %d, second %d, door open" % [first, second])


func _trash_cans(gym: Gen2WorldAPI) -> Dictionary:
	var cans: Dictionary = {}
	for row: Dictionary in gym.current_map.events["hidden_events"] as Array:
		for node: Dictionary in row.get("script", []) as Array:
			if String(node["op"]) == "gym_trash":
				cans[int(node["can"])] = Vector2i(int(row["x"]), int(row["y"]))
	return cans


func _trash_said(gym: Gen2WorldAPI, cans: Dictionary, can: int) -> String:
	gym.player_cell = (cans[can] as Vector2i) + Vector2i.DOWN
	gym.player_facing = Gen2WorldSprite.FACING_UP
	var said: Array[String] = _spoken(gym)
	return "\n".join(said)


const VERMILION_CITY: int = 5
const VERMILION_GYM: int = 92
const VERMILION_GYM_DOOR := Vector2i(12, 20)
const VERMILION_GYM_MAT := Vector2i(4, 16)
const VERMILION_GYM_DOOR_BLOCK := Vector2i(2, 2)
const VERMILION_GYM_DOOR_LOCKED: int = 0x24
const VERMILION_GYM_DOOR_OPEN: int = 0x05
const TRASH_SEED: int = 7
const TRASH_NOTHING: String = "Nope, there's\nonly trash here."
const TRASH_FIRST_OPENED: String = "Hey! There's a\nswitch under the"
const TRASH_RESET: String = "Nope! There's\nonly trash here."
const TRASH_DONE: String = "The 2nd electric\nlock opened!"


## `GymStatues` reads `wBeatGymFlags`, and Pewter's bit is BOULDERBADGE.
func _check_a_gym_statue() -> void:
	var boxes: Array[String] = []
	for badge: bool in [false, true]:
		var world: Gen2WorldAPI = _facing_up(
			PEWTER_GYM, PEWTER_STATUE_CELL + Vector2i.DOWN
		)
		if world == null:
			return
		if badge:
			world.state.set_engine_flag(
				Gen2WorldState.gen1_badge_flag(Gen1Layout.BOULDERBADGE), true
			)
		boxes.append(_box_text(world))
	_r.check(boxes[0].begins_with(_statue_box()) and boxes[0] != boxes[1],
		"the gym statues read %s." % [boxes])
	## Facing up is the whole of the gate: the cell beside it answers nothing.
	var beside: Gen2WorldAPI = _r.open_world(
		0, PEWTER_GYM, PEWTER_STATUE_CELL + Vector2i.LEFT
	)
	if beside != null:
		beside.player_facing = Gen2WorldSprite.FACING_RIGHT
		_r.check(beside.interact().is_empty(), "the statue answered from the side.")


## `PrintBenchGuyText` compares the row's own facing; the source's missing
## `inc hl` walks off the table from any other side.
func _check_a_bench_guy() -> void:
	var world: Gen2WorldAPI = _r.open_world(
		0, VIRIDIAN_POKECENTER, BENCH_GUY_CELL + Vector2i.RIGHT
	)
	if world == null:
		return
	world.player_facing = Gen2WorldSprite.FACING_LEFT
	_r.check(not _box_text(world).is_empty(), "the bench guy said nothing.")
	var above: Gen2WorldAPI = _facing_up(
		VIRIDIAN_POKECENTER, BENCH_GUY_CELL + Vector2i.DOWN
	)
	if above != null:
		_r.check(above.interact().is_empty(), "the bench guy answered from below.")


## `PrintBookshelfText` runs once no hidden event has, facing up alone.
func _check_a_bookshelf() -> void:
	var shelf: Vector2i = _bookshelf_cell(VIRIDIAN_MART)
	if not _r.check(shelf.x >= 0, "no mart bookshelf tile is on the map."):
		return
	var world: Gen2WorldAPI = _facing_up(VIRIDIAN_MART, shelf + Vector2i.DOWN)
	if world == null:
		return
	var box: String = _box_text(world)
	_r.check(box == MART_SHELF_BOX, "the mart shelf said %s." % [box])
	var beside: Gen2WorldAPI = _r.open_world(0, VIRIDIAN_MART, shelf + Vector2i.LEFT)
	if beside != null:
		beside.player_facing = Gen2WorldSprite.FACING_RIGHT
		_r.check(beside.interact().is_empty(), "the shelf answered from the side.")


## `bookshelf_tile HOUSE, $3D, TownMapText`: the poster in Blue's house, whose
## box is followed by the region map rather than by another line.
func _check_the_town_map_poster() -> void:
	var shelf: Vector2i = _tile_cell(BLUES_HOUSE, [TOWN_MAP_POSTER_TILE])
	if not _r.check(shelf.x >= 0, "no town map poster tile is in Blue's house."):
		return
	var world: Gen2WorldAPI = _facing_up(BLUES_HOUSE, shelf + Vector2i.DOWN)
	if world == null:
		return
	var box: String = _box_text(world)
	if not _r.check(box == TOWN_MAP_POSTER_BOX, "the poster said %s." % [box]):
		return
	world.run_event_queue(true)
	var request: Dictionary = world.pending_runtime_request()
	_r.check(
		StringName(request.get("kind", &"")) == &"town_map_requested",
		"the poster asked for %s." % [request.get("kind", &"nothing")]
	)


## `.fly`: the THUNDERBADGE, `CheckIfInOutsideMap`, and `.usedFlyWarp` landing
## the player on the destination's own `FlyWarpDataPtr` tile.
func _check_flying() -> void:
	var world: Gen2WorldAPI = _r.open_world(0, PALLET_TOWN, PALLET_DOOR)
	if world == null:
		return
	world.set_party_summary(1, false, FLY_SPECIES, FLY_MOVES)
	_r.check(
		StringName(world.fly_request().get("reason", &"")) == &"badge_required",
		"flying was allowed with no THUNDERBADGE."
	)
	world.state.set_engine_flag(Gen2WorldState.gen1_badge_flag(Gen1Layout.THUNDERBADGE), true)
	var request: Dictionary = world.fly_request()
	if not _r.check(bool(request.get("ok", false)), "flying was refused outdoors."):
		return
	var towns: Array = request.get("towns", [])
	_r.check(
		towns.size() == Gen1Layout.NUM_CITY_MAPS and int(towns[0]) == PALLET_TOWN
			and int(towns[1]) == Gen1Layout.TOWN_MAP_NOT_VISITED,
		"the fly list read %s." % [towns]
	)
	var landed: Dictionary = world.gen1_fly_to(VIRIDIAN_CITY)
	_r.check(
		bool(landed.get("ok", false)) and world.player_cell == VIRIDIAN_FLY_CELL,
		"flying to Viridian landed on %s." % [world.player_cell]
	)
	var indoors: Gen2WorldAPI = _r.open_world(0, REDS_HOUSE_1F, REDS_HOUSE_MAT)
	if indoors == null:
		return
	indoors.set_party_summary(1, false, FLY_SPECIES, FLY_MOVES)
	indoors.state.set_engine_flag(Gen2WorldState.gen1_badge_flag(Gen1Layout.THUNDERBADGE), true)
	_r.check(
		StringName(indoors.fly_request().get("reason", &"")) == &"indoors",
		"flying was allowed out of a house."
	)


## `IsPlayerOnDungeonWarp` and `HandleFlyWarpOrDungeonWarp` behind it. Victory
## Road 3F's switch shares the list and is no hole at all.
func _check_a_dungeon_fall() -> void:
	var world: Gen2WorldAPI = _r.open_world(0, SEAFOAM_1F, SEAFOAM_HOLE)
	if world == null:
		return
	if not _r.check(
		not world.gen1_dungeon_hole_at(SEAFOAM_HOLE).is_empty(),
		"Seafoam Islands 1F's first hole is no dungeon warp."
	):
		return
	var fell: Dictionary = world.gen1_dungeon_fall()
	_r.check(
		bool(fell.get("ok", false)) and world.map_id() == Vector2i(0, SEAFOAM_B1F)
			and world.player_cell == SEAFOAM_LANDING,
		"the fall landed on %s at %s." % [world.map_id(), world.player_cell]
	)
	var deeper: Gen2WorldAPI = _r.open_world(0, SEAFOAM_B2F, SEAFOAM_B2F_HOLE)
	if deeper != null:
		deeper.gen1_dungeon_fall()
		_r.check(
			deeper.map_id() == Vector2i(0, SEAFOAM_B3F)
				and deeper.player_cell == SEAFOAM_B3F_LANDING
				and deeper.movement_mode == Gen2WorldAPI.MOVEMENT_SURF
				and deeper.player_sprite_number == Gen2WorldSprite.SPRITE_SEEL,
			"the fall into B3F's water left the player %s on sprite %d." % [
				deeper.movement_mode, deeper.player_sprite_number,
			]
		)
	var road: Gen2WorldAPI = _r.open_world(0, VICTORY_ROAD_3F, VICTORY_ROAD_SWITCH)
	if road == null:
		return
	_r.check(
		road.gen1_dungeon_hole_at(VICTORY_ROAD_SWITCH).is_empty(),
		"Victory Road 3F's boulder switch fell through the floor."
	)
	road.player_cell = VICTORY_ROAD_HOLE
	var dropped: Dictionary = road.gen1_dungeon_fall()
	_r.check(
		bool(dropped.get("ok", false)) and road.map_id() == Vector2i(0, VICTORY_ROAD_2F)
			and road.player_cell == VICTORY_ROAD_LANDING,
		"Victory Road's hole landed on %s at %s." % [road.map_id(), road.player_cell]
	)


## `ItemUseBicycle` and `CheckForceBikeOrSurf` walked together: mounted in Pallet
## Town, refused in Red's house, put away by walking into it, forced by the gate
## door onto Route 16 and refused there, and let go by the gate's own script.
func _check_the_bicycle() -> void:
	var world: Gen2WorldAPI = _r.open_world(0, PALLET_TOWN, PALLET_DOOR)
	if world == null:
		return
	var bike: int = Gen1Layout.bike_sprite(_r.game_id)
	var got_on: Dictionary = world.bike_request()
	if not _r.check(
		bool(got_on.get("ok", false)) and world.movement_mode == Gen2WorldAPI.MOVEMENT_BIKE
			and world.player_sprite_number == bike,
		"the bike left the player %s on sprite %d." % [
			world.movement_mode, world.player_sprite_number,
		]
	):
		return
	world.gen1_fly_to(VIRIDIAN_CITY)
	_r.check(
		world.movement_mode == Gen2WorldAPI.MOVEMENT_WALK
			and world.player_sprite_number == Gen2WorldSprite.SPRITE_PLAYER,
		"flying left the player %s on sprite %d." % [
			world.movement_mode, world.player_sprite_number,
		]
	)
	var indoors: Gen2WorldAPI = _r.open_world(0, PALLET_TOWN, PALLET_DOOR)
	if indoors == null:
		return
	indoors.bike_request()
	indoors.player_facing = Gen2WorldSprite.FACING_UP
	indoors.try_warp()
	_r.check(
		indoors.map_id() == Vector2i(0, REDS_HOUSE_1F)
			and indoors.movement_mode == Gen2WorldAPI.MOVEMENT_WALK,
		"riding into Red's house left the player %s." % indoors.movement_mode
	)
	_r.check(
		StringName(indoors.bike_request().get("reason", &"")) == &"no_cycling_here",
		"the bike was ridden indoors."
	)
	_check_the_cycling_road()


## The gate's south door lands on `ForcedBikeOrSurfMaps`' own cell, and the
## Bicycle is refused for as long as `BIT_ALWAYS_ON_BIKE` stands.
func _check_the_cycling_road() -> void:
	var world: Gen2WorldAPI = _r.open_world(0, ROUTE_16, ROUTE_16_GATE_DOOR)
	if world == null:
		return
	world.player_facing = _firing_facing(world, ROUTE_16_GATE_DOOR)
	if not _r.check(bool(world.try_warp().get("ok", false)),
		"Route 16's gate door refused the warp."):
		return
	_r.check(world.movement_mode == Gen2WorldAPI.MOVEMENT_WALK,
		"the gate left the player %s." % world.movement_mode)
	var inside: Vector2i = world.player_cell
	world.player_facing = _firing_facing(world, inside)
	if not _r.check(bool(world.try_warp().get("ok", false)),
		"the gate refused the way back onto Route 16."):
		return
	_r.check(
		world.player_cell == ROUTE_16_GATE_DOOR and world.always_on_bike()
			and world.movement_mode == Gen2WorldAPI.MOVEMENT_BIKE,
		"leaving the gate left the player %s at %s." % [
			world.movement_mode, world.player_cell,
		]
	)
	_r.check(
		StringName(world.bike_request().get("reason", &"")) == &"cannot_get_off",
		"the Bicycle was put away on Cycling Road."
	)
	world.player_facing = _firing_facing(world, ROUTE_16_GATE_DOOR)
	world.try_warp()
	_r.check(
		not world.always_on_bike()
			and world.movement_mode == Gen2WorldAPI.MOVEMENT_WALK,
		"the gate left the ride %s forced." % ["still" if world.always_on_bike() else "no longer"]
	)
	_r.note("gen1 bike forced on Route 16 at %s" % ROUTE_16_GATE_DOOR)


## `RunMapScript` driven on the world: Route 22 Gate's own state machine opens
## on `ArePlayerCoordsInArray`, the guard's row branches on BOULDERBADGE, and
## the index it leaves behind is what the next step dispatches on.
func _check_a_map_script_runs() -> void:
	for badge: bool in [true, false]:
		var world: Gen2WorldAPI = _r.open_world(0, ROUTE_22_GATE, ROUTE_22_GATE_CELL)
		if world == null:
			return
		if badge:
			world.state.set_engine_flag(
				Gen2WorldState.gen1_badge_flag(Gen1Layout.BOULDERBADGE), true
			)
		var spoken: String = _event_text(world.dispatch_sight_events())
		var wanted: String = ROUTE_22_GATE_PASS if badge else ROUTE_22_GATE_REFUSED
		if not _r.check(spoken.begins_with(wanted),
			"the gate guard said %s with the badge %s." % [spoken, badge]):
			continue
		world.run_event_queue(true)
		_r.check(
			world.state.gen1_map_script(ROUTE_22_GATE_BYTE)
				== (ROUTE_22_GATE_NOOP if badge else ROUTE_22_GATE_MOVING),
			"the guard left the gate on state %d with the badge %s." % [
				world.state.gen1_map_script(ROUTE_22_GATE_BYTE), badge,
			]
		)
		_r.check(world.dispatch_sight_events().is_empty(),
			"the gate spoke twice with the badge %s." % badge)
	_r.note("gen1 walk ROUTE_22_GATE both ways past its guard")


## `MoveSprite` driven on the world: Mt. Moon B2F's super nerd walks to whichever
## fossil is left, and the state behind him holds its line until that walk has
## been drawn.
func _check_a_scripted_npc_walk() -> void:
	for row: Array in MT_MOON_B2F_WALKS:
		var world: Gen2WorldAPI = _r.open_world(0, MT_MOON_B2F, row[0])
		if world == null:
			return
		world.state.set_gen1_map_script(MT_MOON_B2F_BYTE, MT_MOON_B2F_MOVE_NERD)
		_r.check(world.dispatch_sight_events().is_empty(),
			"the nerd said something on the frame he was sent walking.")
		var nerd: Gen2WorldObject = world.objects[MT_MOON_B2F_NERD]
		_r.check(nerd.cell == row[1],
			"the nerd walked to %s from %s, not %s." % [nerd.cell, row[0], row[1]])
		_r.check(world.gen1_object_movement_running(),
			"the nerd's walk was over before a frame had drawn it.")
		_r.check(world.dispatch_sight_events().is_empty(),
			"the nerd spoke while his own walk was still being drawn.")
		var passes: int = 0
		while world.gen1_object_movement_running() and passes < SCRIPTED_WALK_PASSES:
			world.advance_scripted_steps_pass()
			passes += 1
		_r.check(_event_text(world.dispatch_sight_events()) == MT_MOON_B2F_NERD_BOX,
			"the nerd said nothing once his walk had been drawn.")
	_r.note("gen1 walk MT_MOON_B2F both ways past its super nerd")


## `HallOfFameDefaultScript`: the warp in walks the player five cells up on the
## frame the map loads, and the state behind it turns Oak to face them.
func _check_a_scripted_player_walk() -> void:
	var world: Gen2WorldAPI = _r.open_world(0, CHAMPIONS_ROOM, CHAMPIONS_ROOM_STAIRS)
	if world == null:
		return
	world.player_facing = Gen2WorldSprite.FACING_UP
	var taken: Dictionary = world.try_warp()
	if not _r.check(bool(taken.get("ok", false)), "the Hall of Fame door was refused."):
		return
	_r.check(Vector2i(taken["to_cell"]) == HALL_OF_FAME_LANDING,
		"the door landed on %s." % [taken["to_cell"]])
	_r.check(world.player_cell == HALL_OF_FAME_WALKED,
		"the room walked the player to %s, not %s." % [
			world.player_cell, HALL_OF_FAME_WALKED,
		])
	_r.check(world.dispatch_sight_events().is_empty(),
		"Oak spoke while the player was still walking in.")
	var passes: int = 0
	while world.gen1_player_movement_running() and passes < SCRIPTED_WALK_PASSES:
		world.advance_player_step_pass()
		passes += 1
	_r.check(_event_text(world.dispatch_sight_events()).begins_with(HALL_OF_FAME_BOX),
		"Oak said nothing once the walk in had been drawn.")
	var oak: Gen2WorldObject = world.objects[HALL_OF_FAME_OAK]
	_r.check(oak.facing == Gen2WorldSprite.FACING_LEFT,
		"Oak faced %d rather than the player." % oak.facing)
	_r.check(world.player_facing == Gen2WorldSprite.FACING_RIGHT,
		"the player faced %d rather than Oak." % world.player_facing)
	_r.note("gen1 walk HALL_OF_FAME five cells in and Oak turning to meet it")


## `RemoveGuardDrink` driven on the world: the guard is thirsty with an empty
## bag and takes the first drink of `GuardDrinksList` the bag holds.
func _check_the_saffron_guard() -> void:
	for drink: int in [0, ITEM_LEMONADE, ITEM_FRESH_WATER]:
		var world: Gen2WorldAPI = _r.open_world(0, ROUTE_5_GATE, ROUTE_5_GATE_CELL)
		if world == null:
			return
		if drink > 0:
			world.state.apply_changes({}, {}, {"items": {drink: 1}})
		var spoken: String = _event_text(world.dispatch_sight_events())
		var wanted: String = SAFFRON_GUARD_PAID if drink > 0 else SAFFRON_GUARD_THIRSTY
		if not _r.check(spoken.begins_with(wanted),
			"the Saffron guard said %s for drink %d." % [spoken, drink]):
			continue
		world.run_event_queue(true)
		_r.check(world.state.item_quantity(drink) == 0 if drink > 0 else true,
			"the guard left %d of item %d in the bag." % [
				world.state.item_quantity(drink), drink,
			])
		_r.check(
			world.state.is_engine_flag_active(_saffron_drink_flag()) == (drink > 0),
			"the drink flag stood %s for drink %d." % [
				world.state.is_engine_flag_active(_saffron_drink_flag()), drink,
			]
		)
	_r.note("gen1 walk the SAFFRON guard thirsty and paid")


## `DecodeArrowMovementRLE`: Viridian Gym's first `map_coord_movement` row spins
## the player along its list and a cell with no row of its own spins nobody.
func _check_an_arrow_tile() -> void:
	var world: Gen2WorldAPI = _r.open_world(0, VIRIDIAN_GYM, VIRIDIAN_GYM_ARROW)
	if world == null:
		return
	world.dispatch_sight_events()
	var passes: int = 0
	while world.gen1_player_movement_running() and passes < SCRIPTED_WALK_PASSES:
		world.advance_player_step_pass()
		passes += 1
	_r.check(world.player_cell == VIRIDIAN_GYM_SPUN,
		"the arrow tile spun the player to %s, not %s." % [
			world.player_cell, VIRIDIAN_GYM_SPUN,
		])
	var still: Gen2WorldAPI = _r.open_world(0, VIRIDIAN_GYM, VIRIDIAN_GYM_STILL)
	if still == null:
		return
	still.dispatch_sight_events()
	_r.check(not still.gen1_player_movement_running(),
		"a cell with no arrow row spun the player anyway.")
	_r.note("gen1 walk VIRIDIAN_GYM's arrow tile %s to %s" % [
		VIRIDIAN_GYM_ARROW, VIRIDIAN_GYM_SPUN,
	])


## Route 12's woken Snorlax, fought off the map script and read back by the
## state behind it.
func _check_a_scripted_wild_battle() -> void:
	var world: Gen2WorldAPI = _r.open_world(0, ROUTE_12, SNORLAX_CELL)
	if world == null:
		return
	world.set_event_flag(SNORLAX_FIGHT_FLAG)
	if not _r.check(not world.dispatch_sight_events().is_empty(),
		"the woken Snorlax asked for nothing."):
		return
	var passes: int = 0
	while world.pending_runtime_request().is_empty() and passes < SCRIPTED_WALK_PASSES:
		world.run_event_queue(true)
		passes += 1
	var request: Dictionary = world.pending_runtime_request()
	var values: Dictionary = request.get("values", {}) as Dictionary
	if not _r.check(
		StringName(request.get("kind", &"")) == &"battle_requested"
			and int(values.get("pokemon", 0)) == SNORLAX_SPECIES
			and int(values.get("level", 0)) == SNORLAX_LEVEL,
		"the Snorlax battle asked for %s." % [request]
	):
		return
	world.complete_runtime_request({
		"ok": true, "outcome": Gen2WorldBattleAdapter.OUTCOME_WON,
	})
	_r.check(world.state.gen1_map_script(ROUTE_12_BYTE) == ROUTE_12_POST_BATTLE,
		"the fight left Route 12 on state %d." % world.state.gen1_map_script(ROUTE_12_BYTE))
	_r.check(_event_text(world.dispatch_sight_events()).begins_with(SNORLAX_CALMED),
		"the beaten Snorlax said nothing.")
	while world.script_busy() and passes < SCRIPTED_WALK_PASSES:
		world.run_event_queue(true)
		passes += 1
	_r.check(world.event_flag_active(SNORLAX_BEAT_FLAG),
		"the beaten Snorlax left its own flag clear.")
	_r.note("gen1 walk ROUTE_12's Snorlax fought at level %d" % SNORLAX_LEVEL)


## `PokemonTower6FMarowakBattleScript` reads `wBattleResult` with `and a`: only
## a won fight sets EVENT_BEAT_GHOST_MAROWAK and prints the departure.
const POKEMON_TOWER_6F: int = 147
const POKEMON_TOWER_6F_BYTE: int = 63
const MAROWAK_CELL := Vector2i(10, 16)
const MAROWAK_SPECIES: int = 105
const MAROWAK_LEVEL: int = 30
const MAROWAK_BEAT_FLAG: int = 271
const MAROWAK_DEPARTED: String = "The GHOST was"


func _check_the_ghost_marowak() -> void:
	for outcome: StringName in [Gen2WorldBattleAdapter.OUTCOME_RAN, Gen2WorldBattleAdapter.OUTCOME_WON]:
		var world: Gen2WorldAPI = _r.open_world(0, POKEMON_TOWER_6F, MAROWAK_CELL + Vector2i.RIGHT)
		if world == null:
			return
		world.player_cell = MAROWAK_CELL
		var opened: Array = world.dispatch_sight_events()
		var passes: int = 0
		while world.pending_runtime_request().is_empty() and passes < SCRIPTED_WALK_PASSES:
			world.run_event_queue(true)
			passes += 1
		var values: Dictionary = world.pending_runtime_request().get("values", {}) as Dictionary
		if not _r.check(
			int(values.get("pokemon", 0)) == MAROWAK_SPECIES and int(values.get("level", 0)) == MAROWAK_LEVEL,
			"the ghost asked for %s / %s." % [world.pending_runtime_request(), opened]
		):
			return
		world.complete_runtime_request({"ok": true, "outcome": outcome})
		var after: Array = world.dispatch_sight_events()
		var won: bool = outcome == Gen2WorldBattleAdapter.OUTCOME_WON
		_r.check(world.event_flag_active(MAROWAK_BEAT_FLAG) == won,
			"a fight %s left EVENT_BEAT_GHOST_MAROWAK %s." % [outcome, world.event_flag_active(MAROWAK_BEAT_FLAG)])
		_r.check((not after.is_empty() and _event_text(after).begins_with(MAROWAK_DEPARTED)) == won,
			"a fight %s was answered with %s." % [outcome, after])
	_r.note("gen1 walk POKEMON_TOWER_6F's MAROWAK fought at level %d" % MAROWAK_LEVEL)


## `ViridianCityOldManStartCatchTrainingScript`'s `wBattleType` as the Dude's
## tutorial, and `wCurOpponent` read behind the whole state: Yellow's initial
## training sets EVENT_INITIAL_CATCH_TRAINING after the store and breaks out on it.
const VIRIDIAN_BYTE: int = 4
## Each row: the state to start on, the one it moves to, and whether the ball lands.
const CATCH_TRAINING_STATES: Dictionary = {
	&"red": [[1, 2, true]], &"blue": [[1, 2, true]], &"yellow": [[3, 4, true], [7, 8, false]],
}


func _check_the_catch_training() -> void:
	for row: Array in CATCH_TRAINING_STATES[_r.game_id] as Array:
		var world: Gen2WorldAPI = _r.open_world(0, VIRIDIAN_CITY, Vector2i(23, 10))
		if world == null:
			return
		world.state.set_gen1_map_script(VIRIDIAN_BYTE, int(row[0]))
		var results: Array = world.dispatch_sight_events()
		var request: Dictionary = world.pending_runtime_request()
		var values: Dictionary = request.get("values", {}) as Dictionary
		if not _r.check(
			StringName(request.get("kind", &"")) == &"battle_requested"
				and bool(values.get("tutorial", false))
				and int(values.get("battle_type", -1)) == Gen2Battle.BATTLETYPE_TUTORIAL
				and int(values.get("gen1_battle_type", -1)) == Gen1Layout.BATTLE_TYPE_OLD_MAN,
			"state %d asked for %s / %s." % [row[0], request, results]
		):
			return
		_r.check(world.state.gen1_map_script(VIRIDIAN_BYTE) == int(row[1]),
			"the state behind the old man's battle is %d." % world.state.gen1_map_script(VIRIDIAN_BYTE))
		_r.check(world.gen1_tutorial_ball_lands() == bool(row[2]),
			"the old man's ball from state %d %s." % [
				row[0], "landed" if world.gen1_tutorial_ball_lands() else "broke out"])
		world.complete_runtime_request({
			"ok": true, "outcome": Gen2WorldBattleAdapter.OUTCOME_CAUGHT,
		})
		_r.check(world.pending_runtime_request().is_empty(), "the training left a request standing.")
	_r.note("gen1 walk VIRIDIAN_CITY's catch training from %d states" % (
		CATCH_TRAINING_STATES[_r.game_id] as Array).size())


func _saffron_drink_flag() -> int:
	return Gen1Layout.engine_flag_base("status_flags_1") + SAFFRON_DRINK_BIT


## `ItemUsePokeFlute` outside a battle: the cell beside Route 12's Snorlax sets
## the fight event, a cell away does not, and neither does that cell once the
## beat event stands.
func _check_the_poke_flute() -> void:
	var world: Gen2WorldAPI = _r.open_world(0, ROUTE_12, SNORLAX_CELL)
	if world == null:
		return
	var flute: Dictionary = world.poke_flute_request()
	_r.check(
		bool(flute.get("ok", false)) and bool(flute.get("woke", false))
			and world.event_flag_active(SNORLAX_FIGHT_FLAG),
		"the flute beside the Snorlax answered %s." % [flute]
	)
	world.player_cell = SNORLAX_CELL + Vector2i.LEFT
	world.state.set_event_flag(SNORLAX_FIGHT_FLAG, false)
	_r.check(
		not bool(world.poke_flute_request().get("woke", false))
			and not world.event_flag_active(SNORLAX_FIGHT_FLAG),
		"the flute woke a Snorlax a cell away."
	)
	world.player_cell = SNORLAX_CELL
	world.state.set_event_flag(SNORLAX_BEAT_FLAG, true)
	_r.check(
		not bool(world.poke_flute_request().get("woke", false)),
		"the flute woke a Snorlax that had already been beaten."
	)
	_r.note("gen1 poke flute set flag %d beside the Snorlax" % SNORLAX_FIGHT_FLAG)


## `ItemUseEscapeRope`: refused outdoors and in Agatha's room, taken in a cave,
## landing on `wLastBlackoutMap`'s own `FlyWarpDataPtr` tile.
func _check_an_escape_rope() -> void:
	var outdoors: Gen2WorldAPI = _r.open_world(0, PALLET_TOWN, PALLET_DOOR)
	if outdoors == null:
		return
	_r.check(
		StringName(outdoors.escape_rope_request().get("reason", &"")) == &"not_in_a_cave",
		"an Escape Rope was pulled in Pallet Town."
	)
	var agatha: Gen2WorldAPI = _r.open_world(
		0, Gen1Layout.AGATHAS_ROOM, AGATHAS_ROOM_CELL
	)
	if agatha != null:
		_r.check(
			StringName(agatha.escape_rope_request().get("reason", &"")) == &"not_in_a_cave",
			"an Escape Rope was pulled in Agatha's room."
		)
	var world: Gen2WorldAPI = _r.open_world(0, SEAFOAM_1F, SEAFOAM_HOLE + Vector2i.UP)
	if world == null:
		return
	if not _r.check(
		bool(world.escape_rope_request().get("ok", false)),
		"an Escape Rope was refused in the Seafoam Islands."
	):
		return
	var escaped: Dictionary = world.complete_escape()
	_r.check(
		bool(escaped.get("ok", false)) and world.map_id() == Vector2i(0, PALLET_TOWN)
			and world.player_cell == PALLET_FLY_CELL,
		"the rope landed on %s at %s." % [world.map_id(), world.player_cell]
	)
	_check_the_blackout_map_moves()


## `SetLastBlackoutMap` reads `wLastMap`, so walking in is what moves it.
func _check_the_blackout_map_moves() -> void:
	var city: Gen2WorldAPI = _r.open_world(0, VIRIDIAN_CITY, Vector2i.ZERO)
	if city == null:
		return
	var door: Vector2i = _warp_cell_to(city, VIRIDIAN_POKECENTER)
	if not _r.check(door.x >= 0, "Viridian City has no Pokemon Center door."):
		return
	city.player_cell = door
	city.player_facing = Gen2WorldSprite.FACING_UP
	if not _r.check(
		bool(city.try_warp().get("ok", false)),
		"the Pokemon Center door did not open."
	):
		return
	city.player_cell = NURSE_COUNTER
	city.player_facing = Gen2WorldSprite.FACING_UP
	city.set_party_summary(NURSE_PARTY, false)
	city.interact()
	city.run_event_queue(true)
	city.choose_script_input(0)
	city.run_event_queue(true)
	_r.check(
		city.gen1_last_blackout_map() == VIRIDIAN_CITY,
		"healing left the blackout map at %d." % city.gen1_last_blackout_map()
	)
	_r.note("gen1 blackout map %d" % city.gen1_last_blackout_map())


## The cell of [param world]'s own warp onto [param map], or (-1, -1).
func _warp_cell_to(world: Gen2WorldAPI, map: int) -> Vector2i:
	for warp: Dictionary in world.current_map.events.get("warps", []) as Array:
		if int(warp.get("map_number", -1)) == map:
			return Vector2i(int(warp["x"]), int(warp["y"]))
	return Vector2i(-1, -1)


## The first cell of [param map] drawing a tile `BookshelfTileIDs` names.
func _bookshelf_cell(map: int) -> Vector2i:
	return _tile_cell(map, (_r.data.world_tileset(
		_r.data.world_map(0, map).tileset
	).bookshelves as Dictionary).keys())


func _tile_cell(map: int, tiles: Array) -> Vector2i:
	var world: Gen2WorldAPI = _r.open_world(0, map, Vector2i.ZERO)
	if world == null:
		return Vector2i(-1, -1)
	var record: Gen2WorldMap = world.current_map
	for y: int in record.collision_height - 1:
		for x: int in record.collision_width:
			if tiles.has(world.collision_code_at(Vector2i(x, y))):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


## `_GymStatueText1`'s two `text_ram` markers filled from the map script.
func _statue_box() -> String:
	return PEWTER_STATUE_BOX.replace("#MON", Gen1Text.character(0x54) + "MON")


func _facing_for(step: Vector2i) -> int:
	if step == Vector2i.UP:
		return Gen2WorldSprite.FACING_UP
	return Gen2WorldSprite.FACING_LEFT if step == Vector2i.LEFT \
		else Gen2WorldSprite.FACING_DOWN


## `_FoundHiddenItemText` with `GetItemName`'s own answer in its RAM marker.
func _hidden_item_box() -> String:
	return "%s found\n%s!" % [
		Gen2WorldScriptRunner.UNNAMED, _r.data.item_name(HIDDEN_POTION),
	]


## `UsedCut` and `ReplaceTreeTileBlock` on the corpus's own first cut tree:
## Viridian City's, which hides the path west out of the school's row.
func _check_a_cut_tree() -> void:
	var world: Gen2WorldAPI = _r.open_world(0, VIRIDIAN_CITY, CUT_TREE_CELL + Vector2i.DOWN)
	if world == null:
		return
	world.player_facing = Gen2WorldSprite.FACING_UP
	_r.field_move_party(world)
	_r.check(
		StringName(world.cut_request().get("reason", &"")) == &"badge_required",
		"Cut was allowed with no CASCADEBADGE."
	)
	world.state.set_engine_flag(
		Gen2WorldState.gen1_badge_flag(Gen1Layout.CASCADEBADGE), true
	)
	var before: int = world.block_at(CUT_TREE_BLOCK.x, CUT_TREE_BLOCK.y)
	if not _r.check(bool(world.cut_request().get("ok", false)), "Cut was refused at the tree."):
		return
	world.complete_cut()
	var after: int = world.block_at(CUT_TREE_BLOCK.x, CUT_TREE_BLOCK.y)
	_r.check(
		after == Gen1Layout.cut_block_swap(before) and after != before,
		"cutting turned block $%02X into $%02X." % [before, after]
	)
	world.player_cell = CUT_TREE_CELL + Vector2i.DOWN * 2
	_r.check(
		StringName(world.cut_request().get("reason", &"")) == &"nothing_to_cut",
		"Cut was offered with nothing in front."
	)


## `wMapPalOffset`: the warp into ROCK_TUNNEL_1F darkens both floors, `.flash`
## clears it, and the way back out to Route 10 clears it again.
func _check_rock_tunnel_is_dark() -> void:
	var world: Gen2WorldAPI = _r.open_world(0, ROUTE_10, ROCK_TUNNEL_MOUTH)
	if world == null:
		return
	_r.field_move_party(world)
	world.player_facing = Gen2WorldSprite.FACING_UP
	if not _r.check(bool(world.try_warp().get("ok", false)), "the tunnel mouth refused."):
		return
	_r.check(
		world.map_id() == Vector2i(0, Gen1Layout.ROCK_TUNNEL_1F)
			and world.gen1_map_pal_offset == Gen1Layout.MAP_PAL_OFFSET_DARK,
		"the tunnel is %s at offset %d." % [world.map_id(), world.gen1_map_pal_offset]
	)
	world.player_cell = ROCK_TUNNEL_STAIRS
	world.player_facing = Gen2WorldSprite.FACING_DOWN
	if not _r.check(bool(world.try_warp().get("ok", false)), "the stairs down refused."):
		return
	_r.check(
		world.map_id() == Vector2i(0, ROCK_TUNNEL_B1F)
			and world.gen1_map_pal_offset == Gen1Layout.MAP_PAL_OFFSET_DARK,
		"B1F is %s at offset %d." % [world.map_id(), world.gen1_map_pal_offset]
	)
	_r.check(
		StringName(world.flash_request().get("reason", &"")) == &"badge_required",
		"Flash was allowed with no BOULDERBADGE."
	)
	world.state.set_engine_flag(
		Gen2WorldState.gen1_badge_flag(Gen1Layout.BOULDERBADGE), true
	)
	if not _r.check(bool(world.flash_request().get("ok", false)), "Flash was refused."):
		return
	world.complete_flash()
	_r.check(world.gen1_map_pal_offset == 0, "Flash left the floor dark.")
	world.player_cell = ROCK_TUNNEL_B1F_STAIRS
	world.player_facing = Gen2WorldSprite.FACING_UP
	world.try_warp()
	world.player_cell = ROCK_TUNNEL_EXIT
	world.player_facing = Gen2WorldSprite.FACING_UP
	if not _r.check(bool(world.try_warp().get("ok", false)), "the way out refused."):
		return
	_r.check(
		world.map_id() == Vector2i(0, ROUTE_10) and world.gen1_map_pal_offset == 0,
		"leaving Rock Tunnel landed on %s at offset %d." % [
			world.map_id(), world.gen1_map_pal_offset,
		]
	)


## The opening, from `wYCoord == 1` to Oak's Lab's speech state. Yellow opens
## on Pikachu's own battle instead.
const OAKS_LAB: int = 40
const PALLET_TOWN_BYTE: int = 1
const OAKS_LAB_BYTE: int = 0
const PALLET_NORTH_EXIT := Vector2i(10, 1)
const PALLET_OAK: int = 0
const OAKS_LAB_SPEECH: int = 5
const OAK_APPEARED_FLAG: int = 39
const FOLLOWED_OAK_FLAG: int = 0
const OPENING_PASSES: int = 1200
const OAK_HEY_WAIT: String = "OAK: Hey! Wait!"
const OAK_UNSAFE: String = "OAK: It's unsafe!"


func _check_the_opening_walk() -> void:
	var world: Gen2WorldAPI = _r.open_world(0, PALLET_TOWN, PALLET_NORTH_EXIT)
	if world == null:
		return
	world.player_facing = Gen2WorldSprite.FACING_UP
	var spoken: Array[String] = []
	var passes: int = 0
	while passes < OPENING_PASSES:
		spoken.append_array(_spoken_this_pass(world))
		_drive_one_pass(world)
		passes += 1
		if world.map_id() == Vector2i(0, OAKS_LAB) \
			and world.state.gen1_map_script(OAKS_LAB_BYTE) >= OAKS_LAB_SPEECH:
			break
	var lines: String = "\n".join(spoken)
	_r.check(lines.contains(OAK_HEY_WAIT), "Oak never called out: %s" % lines.left(200))
	_r.check(lines.contains(OAK_UNSAFE), "Oak never said it was unsafe: %s" % lines.left(200))
	_r.check(world.event_flag_active(OAK_APPEARED_FLAG), "EVENT_OAK_APPEARED_IN_PALLET is clear.")
	_r.check(world.map_id() == Vector2i(0, OAKS_LAB),
		"after %d passes the player stands on %s." % [passes, world.map_id()])
	_r.check(world.event_flag_active(FOLLOWED_OAK_FLAG), "EVENT_FOLLOWED_OAK_INTO_LAB is clear.")
	_r.check(not world.gen1_movement_script_running(), "the movement script never ended.")
	_r.check(world.state.gen1_map_script(OAKS_LAB_BYTE) >= OAKS_LAB_SPEECH,
		"Oak's Lab stands on state %d after %d passes." % [
			world.state.gen1_map_script(OAKS_LAB_BYTE), passes,
		])
	_r.note("gen1 walk PALLET_TOWN into OAKS_LAB in %d passes" % passes)
	_check_the_lab_starter(world)


## The lab from the speech to the rival leaving with the Pokedex.
const LAB_RIVAL: int = 0
const LAB_CHARMANDER_BALL: int = 1
const LAB_OAK: int = 4
const LAB_POKEDEXES: Array[int] = [5, 6]
const LAB_BELOW_CHARMANDER := Vector2i(6, 4)
const LAB_LEAVING_ROW: int = 6
const LAB_BELOW_OAK := Vector2i(5, 3)
const LAB_RIVAL_ARRIVES_STATE: int = 15
const LAB_RIVAL_BESIDE_OAK := Vector2i(4, 3)
const LAB_DONT_GO_AWAY: int = 6
const LAB_NOOP: int = 18
const LAB_RIVAL_CLASS: int = 25
## `OaksLabRivalStartBattleScript`: the rival holding SQUIRTLE is party 1.
const LAB_RIVAL_PARTY: int = 1
const CHARMANDER_INDEX: int = 0xB0
const SQUIRTLE_INDEX: int = 0xB1
const CHARMANDER_DEX: int = 4
const OAKS_PARCEL: int = 0x46
const OAK_ASKED_TO_CHOOSE_FLAG: int = 33
const GOT_STARTER_FLAG: int = 34
const BATTLED_RIVAL_FLAG: int = 35
const GOT_POKEDEX_FLAG: int = 37
const OAK_GOT_PARCEL_FLAG: int = 56
const ROUTE22_RIVAL_WANTS_BATTLE_FLAG: int = 1319
const LAB_PASSES: int = 600
const RIVAL_TAKES_THIS_ONE: String = "I'll take"
const RIVAL_SMELL_YOU_LATER: String = "Smell you later"
const RIVAL_LEAVE_IT_TO_ME: String = "Leave it"


func _check_the_lab_starter(world: Gen2WorldAPI) -> void:
	var spoken: Array[String] = []
	_drive_the_lab(world, spoken, LAB_DONT_GO_AWAY)
	if not _r.check(world.state.gen1_map_script(OAKS_LAB_BYTE) == LAB_DONT_GO_AWAY,
		"the speech left the lab on state %d." % world.state.gen1_map_script(OAKS_LAB_BYTE)):
		return
	world.player_cell = LAB_BELOW_CHARMANDER
	world.player_facing = Gen2WorldSprite.FACING_UP
	spoken.append_array(_lab_answers(world, world.interact()))
	_drive_the_lab(world, spoken, LAB_NOOP - 1)
	_r.check(world.state.gen1_starter("player") == CHARMANDER_INDEX
		and world.state.gen1_starter("rival") == SQUIRTLE_INDEX,
		"the starters read %d and %d." % [
			world.state.gen1_starter("player"), world.state.gen1_starter("rival")])
	_r.check(not _object_active(world, LAB_CHARMANDER_BALL), "the CHARMANDER ball is still drawn.")
	_r.check(world.event_flag_active(GOT_STARTER_FLAG), "EVENT_GOT_STARTER is clear.")
	_r.check("\n".join(spoken).contains(RIVAL_TAKES_THIS_ONE),
		"the rival never took his: %s" % ["\n".join(spoken).right(300)])
	world.player_cell = Vector2i(LAB_BELOW_CHARMANDER.x, LAB_LEAVING_ROW)
	_lab_facings.clear()
	_drive_the_lab(world, spoken, LAB_NOOP, LAB_RIVAL_CLASS, LAB_RIVAL_PARTY - 1)
	_r.check(world.event_flag_active(BATTLED_RIVAL_FLAG), "EVENT_BATTLED_RIVAL_IN_OAKS_LAB is clear.")
	## `OaksLabPlayerWatchRivalExitScript`: toward the rival at five steps left, down at four.
	_r.check(_lab_facings.slice(-2) == [Gen2WorldSprite.FACING_LEFT, Gen2WorldSprite.FACING_DOWN],
		"the player watched the rival leave facing %s." % [_lab_facings])
	_r.check("\n".join(spoken).contains(RIVAL_SMELL_YOU_LATER),
		"the rival never left: %s" % ["\n".join(spoken).right(300)])
	_r.check(not _object_active(world, LAB_RIVAL), "the rival is still drawn after leaving.")
	_r.check(world.state.gen1_map_script(OAKS_LAB_BYTE) == LAB_NOOP,
		"the rival's exit left the lab on state %d." % world.state.gen1_map_script(OAKS_LAB_BYTE))
	_check_the_lab_parcel(world, spoken)


## `OaksLabOak1Text` with OAK'S PARCEL in the bag, then states 15 to 17.
func _check_the_lab_parcel(world: Gen2WorldAPI, spoken: Array[String]) -> void:
	world.state.apply_changes({}, {}, {"items": {OAKS_PARCEL: 1}})
	world.player_cell = LAB_BELOW_OAK
	world.player_facing = Gen2WorldSprite.FACING_UP
	spoken.append_array(_lab_answers(world, world.interact()))
	_r.check(int(world.state.items().get(OAKS_PARCEL, 0)) == 0, "OAK'S PARCEL is still in the bag.")
	_r.check(world.state.gen1_map_script(OAKS_LAB_BYTE) == LAB_RIVAL_ARRIVES_STATE,
		"the parcel left the lab on state %d." % world.state.gen1_map_script(OAKS_LAB_BYTE))
	var rival: Gen2WorldObject = world.objects[LAB_RIVAL]
	var passes: int = 0
	while world.state.gen1_map_script(OAKS_LAB_BYTE) == LAB_RIVAL_ARRIVES_STATE \
		and passes < LAB_PASSES:
		spoken.append_array(_lab_answers(world, world.dispatch_sight_events()))
		passes += 1
	_r.check(rival.active and rival.cell == LAB_RIVAL_BESIDE_OAK
		and world.scripted_movement_in_progress(),
		"the rival walked to %s, drawn %s, walking %s." % [
			rival.cell, rival.active, world.scripted_movement_in_progress()])
	_drive_the_lab(world, spoken, LAB_NOOP)
	_r.check(world.event_flag_active(OAK_GOT_PARCEL_FLAG), "EVENT_OAK_GOT_PARCEL is clear.")
	_r.check(world.event_flag_active(GOT_POKEDEX_FLAG), "EVENT_GOT_POKEDEX is clear.")
	_r.check(world.event_flag_active(ROUTE22_RIVAL_WANTS_BATTLE_FLAG),
		"EVENT_ROUTE22_RIVAL_WANTS_BATTLE is clear.")
	for index: int in LAB_POKEDEXES:
		_r.check(not _object_active(world, index), "Pokedex %d is still on the table." % index)
	_r.check("\n".join(spoken).contains(RIVAL_LEAVE_IT_TO_ME),
		"the rival never took the Pokedex: %s" % ["\n".join(spoken).right(300)])
	_r.check(not rival.active, "the rival is still drawn after leaving with the Pokedex.")
	_r.check(world.state.gen1_map_script(OAKS_LAB_BYTE) == LAB_NOOP,
		"the Pokedex left the lab on state %d." % world.state.gen1_map_script(OAKS_LAB_BYTE))
	_r.note("gen1 walk OAKS_LAB from the speech to the rival leaving with the Pokedex")


## Passes with A held until the lab's byte reaches [param until] and every
## walk has been drawn.
var _lab_facings: Array[int] = []


func _drive_the_lab(
	world: Gen2WorldAPI, spoken: Array[String], until: int, trainer_class: int = -1,
	trainer_id: int = -1
) -> void:
	var passes: int = 0
	while passes < LAB_PASSES:
		if _lab_facings.is_empty() or _lab_facings[-1] != world.player_facing:
			_lab_facings.append(world.player_facing)
		spoken.append_array(_lab_answers(world, world.dispatch_sight_events(), trainer_class, trainer_id))
		spoken.append_array(_lab_answers(world, world.run_event_queue(true), trainer_class, trainer_id))
		world.advance_script_wait_frame()
		world.advance_player_step_pass()
		world.advance_scripted_steps_pass()
		passes += 1
		if world.state.gen1_map_script(OAKS_LAB_BYTE) >= until \
			and not world.scripted_movement_in_progress() and not world.script_busy():
			return


## The boxes in [param results], every request behind them answered.
func _lab_answers(
	world: Gen2WorldAPI, results: Array, trainer_class: int = -1, trainer_id: int = -1
) -> Array[String]:
	var spoken: Array[String] = []
	for _turn: int in LAB_PASSES:
		for row: Dictionary in results:
			var event: Dictionary = row.get("event", {})
			if StringName(event.get("type", &"")) == &"text":
				spoken.append(String(event["text"]))
		var request: Dictionary = world.pending_runtime_request()
		var input: Dictionary = world.pending_script_input()
		if not request.is_empty():
			results = world.complete_runtime_request(_lab_answer(request, trainer_class, trainer_id))
		elif not input.is_empty():
			results = world.choose_script_input(0 if StringName(input.get("type", &"")) == &"choice" else -1)
		else:
			return spoken
	return spoken


func _lab_answer(request: Dictionary, trainer_class: int, trainer_id: int) -> Dictionary:
	var values: Dictionary = request.get("values", {}) as Dictionary
	match StringName(request.get("kind", &"")):
		&"battle_requested":
			_r.check(int(values.get("trainer_class", 0)) == trainer_class
				and int(values.get("trainer_id", -1)) == trainer_id,
				"the lab asked for %s." % [request])
			return {"ok": true, "outcome": Gen2WorldBattleAdapter.OUTCOME_WON}
		&"pokemon_requested":
			_r.check(int(values.get("pokemon", 0)) == CHARMANDER_DEX,
				"the ball gave %s." % [request])
			return {"ok": true, "accepted": true}
	return {"ok": true}


## One overworld pass with nobody at the buttons.
func _drive_one_pass(world: Gen2WorldAPI) -> void:
	var guard: int = 0
	while world.script_busy() and world.pending_runtime_request().is_empty() \
		and world.pending_script_wait().is_empty() and guard < 50:
		world.run_event_queue(true)
		guard += 1
	world.advance_script_wait_frame()
	world.advance_player_step_pass()
	world.advance_scripted_steps_pass()
	if not world.player_step_in_progress() and world.warp_pending():
		world.try_warp()


func _spoken_this_pass(world: Gen2WorldAPI) -> Array[String]:
	var out: Array[String] = []
	for result: Dictionary in world.dispatch_sight_events():
		var event: Dictionary = result.get("event", {})
		if StringName(event.get("type", &"")) == &"text":
			out.append(String(event["text"]))
	return out


const ROUTE_23: int = 34
const ROUTE_23_BYTE: int = 0x77
const ROUTE_23_TOP_GUARD := Vector2i(8, 35)
const ROUTE_23_PAST_TOP := Vector2i(14, 35)
const ROUTE_23_BOTTOM_GUARD := Vector2i(8, 136)
const PASSED_CASCADE_CHECK: int = 1328
const PASSED_EARTH_CHECK: int = 1334


func _check_the_route_23_guards() -> void:
	var rows: Array = [
		[ROUTE_23_TOP_GUARD, PASSED_EARTH_CHECK], [ROUTE_23_BOTTOM_GUARD, PASSED_CASCADE_CHECK],
	]
	for row: Array in rows:
		for passed: bool in [false, true]:
			var world: Gen2WorldAPI = _r.open_world(0, ROUTE_23, row[0])
			if world == null:
				return
			if passed:
				world.set_event_flag(int(row[1]))
			var said: String = _first_text(world.dispatch_sight_events())
			_r.check(said.is_empty() == passed,
				"the guard at %s said %s with the check passed %s." % [row[0], said, passed])
	var past: Gen2WorldAPI = _r.open_world(0, ROUTE_23, ROUTE_23_PAST_TOP)
	if past == null:
		return
	_r.check(_first_text(past.dispatch_sight_events()).is_empty(),
		"the top guard spoke to a player already past him.")
	_r.note("gen1 walk ROUTE_23's guards both ways about their badge checks")


const ROUTE_16_GATE_1F: int = 186
const ROUTE_16_GATE_BYTE: int = 0x70
const ROUTE_16_GATE_MOVING_UP: int = 1
const ROUTE_16_GATE_STOP := Vector2i(4, 9)
const BICYCLE_ITEM: int = 0x06


func _check_the_cycling_road_gate_walk() -> void:
	for owned: bool in [false, true]:
		var world: Gen2WorldAPI = _r.open_world(0, ROUTE_16_GATE_1F, ROUTE_16_GATE_STOP)
		if world == null:
			return
		if owned:
			world.state.apply_changes({}, {}, {"items": {BICYCLE_ITEM: 1}})
		var said: String = _first_text(world.dispatch_sight_events())
		_r.check(said.is_empty() == owned,
			"the gate guard said %s with the Bicycle owned %s." % [said, owned])
		if owned:
			continue
		world.run_event_queue(true)
		_r.check(world.state.gen1_map_script(ROUTE_16_GATE_BYTE) == ROUTE_16_GATE_MOVING_UP,
			"the gate left its byte on %d." % world.state.gen1_map_script(ROUTE_16_GATE_BYTE))
		var passes: int = 0
		while world.gen1_player_movement_running() and passes < SCRIPTED_WALK_PASSES:
			world.advance_player_step_pass()
			passes += 1
		_r.check(world.player_cell == ROUTE_16_GATE_STOP + Vector2i.UP * 2,
			"the guard walked the player to %s." % [world.player_cell])
	_r.note("gen1 walk ROUTE_16_GATE_1F's guard with and without the Bicycle")


const VIRIDIAN_CITY_BYTE: int = 4
const VIRIDIAN_GYM_DOOR := Vector2i(32, 8)
const VIRIDIAN_GYM_OPEN_FLAG: int = 40
const VIRIDIAN_MOVING_DOWN: Dictionary = {&"red": 3, &"blue": 3, &"yellow": 6}
const EARTHBADGE_BIT: int = 7


func _check_the_viridian_gym_door() -> void:
	for earned: bool in [false, true]:
		var world: Gen2WorldAPI = _r.open_world(0, VIRIDIAN_CITY, VIRIDIAN_GYM_DOOR)
		if world == null:
			return
		if earned:
			for bit: int in EARTHBADGE_BIT:
				world.state.set_engine_flag(Gen2WorldState.gen1_badge_flag(bit), true)
		var said: String = _first_text(world.dispatch_sight_events())
		_r.check(said.is_empty() == earned,
			"the gym door said %s with seven badges %s." % [said, earned])
		world.run_event_queue(true)
		_r.check(world.event_flag_active(VIRIDIAN_GYM_OPEN_FLAG) == earned,
			"EVENT_VIRIDIAN_GYM_OPEN reads %s with seven badges %s." % [
				world.event_flag_active(VIRIDIAN_GYM_OPEN_FLAG), earned,
			])
		if not earned:
			_r.check(
				world.state.gen1_map_script(VIRIDIAN_CITY_BYTE)
					== int(VIRIDIAN_MOVING_DOWN[_r.game_id]),
				"the door left Viridian City on state %d." % [
					world.state.gen1_map_script(VIRIDIAN_CITY_BYTE),
				])
	_r.note("gen1 walk VIRIDIAN_CITY's gym door with and without seven badges")


const CINNABAR_ISLAND: int = 8
const CINNABAR_SHORE := Vector2i(19, 13)
const POKEMON_MANSION_3F: int = 215
const MANSION_3F_SWITCH := Vector2i(10, 6)
const MANSION_3F_DOOR := Vector2i(15, 10)
const MANSION_SWITCH_FLAG: int = 632
const MANSION_SWITCH_ASKS: String = "A secret switch!"


## `CinnabarIsland_Script` sets BIT_CUR_MAP_LOADED_1 on every frame and nothing
## on the island reads it, so a walk there is not forever owed a load pass.
func _check_cinnabar_settles() -> void:
	var world: Gen2WorldAPI = _r.open_world(0, CINNABAR_ISLAND, CINNABAR_SHORE)
	if world == null:
		return
	world.dispatch_map_entry()
	for _pass: int in 3:
		world.dispatch_sight_events()
	_r.check(not world.gen1_map_load_pending(),
		"Cinnabar Island still owes a map-load pass after three frames.")
	_r.check(not world.event_flag_active(MANSION_SWITCH_FLAG),
		"the island did not clear EVENT_MANSION_SWITCH_ON.")


## `Mansion3Script_Switches`: the statue's row sits past every object's, asks,
## flips EVENT_MANSION_SWITCH_ON and sets the bit that redraws the doors.
func _check_a_mansion_switch() -> void:
	var world: Gen2WorldAPI = _r.open_world(0, POKEMON_MANSION_3F, MANSION_3F_SWITCH)
	if world == null:
		return
	world.dispatch_map_entry()
	world.player_facing = Gen2WorldSprite.FACING_UP
	var shut: bool = not world.can_walk_to(MANSION_3F_DOOR)
	world.interact()
	var asked: Dictionary = world.pending_script_input()
	if not _r.check(StringName(asked.get("type", &"")) == &"choice"
		and String(asked.get("text", "")).begins_with(MANSION_SWITCH_ASKS),
		"the 3F switch asked %s." % [asked]):
		return
	world.choose_script_input(0)
	world.run_event_queue(true)
	world.dispatch_sight_events()
	_r.check(world.event_flag_active(MANSION_SWITCH_FLAG), "the pressed switch left the event clear.")
	_r.check(shut and world.can_walk_to(MANSION_3F_DOOR),
		"the door at %s stood %s before and %s after." % [
			MANSION_3F_DOOR, "shut" if shut else "open", "open" if world.can_walk_to(MANSION_3F_DOOR) else "shut"])
	_r.note("gen1 walk POKEMON_MANSION_3F's switch opens its door")


const POKEMON_TOWER_7F: int = 148
const TOWER_7F_BYTE: int = 0x40
const TOWER_7F_WARP_STATE: Dictionary = {&"red": 4, &"blue": 4, &"yellow": 11}
const TOWER_7F_FUJI := Vector2i(10, 3)
const TOWER_7F_FUJI_OBJECT: int = 3
const MR_FUJIS_HOUSE: int = 149


func _check_the_tower_warp() -> void:
	var world: Gen2WorldAPI = _r.open_world(0, POKEMON_TOWER_7F, TOWER_7F_FUJI + Vector2i.DOWN)
	if world == null:
		return
	world.state.set_gen1_map_script(TOWER_7F_BYTE, int(TOWER_7F_WARP_STATE[_r.game_id]))
	world.dispatch_sight_events()
	world.run_event_queue(true)
	_r.check(world.map_id() == Vector2i(0, MR_FUJIS_HOUSE),
		"the tower's warp landed on %s." % [world.map_id()])
	_r.check(world.gen1_last_map() == LAVENDER_TOWN,
		"the warp left wLastMap at %d." % world.gen1_last_map())
	_r.check(world.state.gen1_map_script(TOWER_7F_BYTE) == 0,
		"the tower stayed on state %d." % world.state.gen1_map_script(TOWER_7F_BYTE))
	_r.check(world.player_facing == Gen2WorldSprite.FACING_UP,
		"the player faced %d in Mr. Fuji's house." % world.player_facing)
	_r.note("gen1 walk POKEMON_TOWER_7F warped to MR_FUJIS_HOUSE")


const SILPH_CO_7F: int = 212
const SILPH_CO_7F_BYTE: int = 0x58
const SILPH_RIVAL_START: int = 3
const SILPH_RIVAL_AFTER: int = 4
const SILPH_RIVAL_CELL := Vector2i(3, 3)
const SILPH_RIVAL_CLASS: int = 0x2A
const BEAT_SILPH_RIVAL_FLAG: int = 1856
## STARTER2 on Red and Blue, RIVAL_STARTER_FLAREON on Yellow: party 7 and `starter + 4`.
const SILPH_RIVAL_STARTER: Dictionary = {&"red": 0xB1, &"blue": 0xB1, &"yellow": 2}
const SILPH_RIVAL_PARTY: Dictionary = {&"red": 7, &"blue": 7, &"yellow": 6}


func _check_the_silph_rival() -> void:
	var world: Gen2WorldAPI = _r.open_world(0, SILPH_CO_7F, SILPH_RIVAL_CELL)
	if world == null:
		return
	world.state.set_gen1_starter("rival", int(SILPH_RIVAL_STARTER[_r.game_id]))
	world.state.set_gen1_map_script(SILPH_CO_7F_BYTE, SILPH_RIVAL_START)
	world.dispatch_sight_events()
	var passes: int = 0
	while world.pending_runtime_request().is_empty() and passes < SCRIPTED_WALK_PASSES:
		world.run_event_queue(true)
		passes += 1
	var request: Dictionary = world.pending_runtime_request()
	var values: Dictionary = request.get("values", {}) as Dictionary
	if not _r.check(
		StringName(request.get("kind", &"")) == &"battle_requested"
			and int(values.get("trainer_class", 0)) == SILPH_RIVAL_CLASS
			and int(values.get("trainer_id", -1)) == int(SILPH_RIVAL_PARTY[_r.game_id]) - 1,
		"the Silph rival asked for %s." % [request]
	):
		return
	world.complete_runtime_request({
		"ok": true, "outcome": Gen2WorldBattleAdapter.OUTCOME_WON,
	})
	_r.check(world.state.gen1_map_script(SILPH_CO_7F_BYTE) == SILPH_RIVAL_AFTER,
		"the fight left Silph Co. 7F on state %d." % world.state.gen1_map_script(SILPH_CO_7F_BYTE))
	world.dispatch_sight_events()
	passes = 0
	while world.script_busy() and passes < SCRIPTED_WALK_PASSES:
		world.run_event_queue(true)
		passes += 1
	_r.check(world.event_flag_active(BEAT_SILPH_RIVAL_FLAG),
		"the beaten rival left EVENT_BEAT_SILPH_CO_RIVAL clear.")
	_r.note("gen1 walk SILPH_CO_7F's rival fought as party %d" % int(SILPH_RIVAL_PARTY[_r.game_id]))


## `PokemonTower7FEndBattleScript` walks the beaten rocket off along the table
## row the player stands on, and `PokemonTower7FHideNPCScript` hides it.
const TOWER_7F_ROCKET: int = 0
const TOWER_7F_ROCKET_CELL := Vector2i(9, 11)
const TOWER_7F_BESIDE_ROCKET := Vector2i(10, 11)
const TOWER_7F_HIDE_STATE: int = 3


func _check_the_tower_rocket_leaves() -> void:
	var world: Gen2WorldAPI = _r.open_world(0, POKEMON_TOWER_7F, TOWER_7F_BESIDE_ROCKET)
	if world == null:
		return
	world.player_facing = Gen2WorldSprite.FACING_LEFT
	var results: Array = world.interact()
	var passes: int = 0
	while world.pending_runtime_request().is_empty() and not results.is_empty() \
		and passes < SCRIPTED_WALK_PASSES:
		results = world.run_event_queue(true)
		passes += 1
	if not _r.check(StringName(world.pending_runtime_request().get("kind", &"")) == &"battle_requested",
		"the rocket never asked for a fight."):
		return
	world.complete_runtime_request({"ok": true, "outcome": Gen2WorldBattleAdapter.OUTCOME_WON})
	_r.check(world.state.gen1_map_script(TOWER_7F_BYTE) == Gen2WorldAPI.GEN1_END_BATTLE_STATE,
		"the fight left the tower on state %d." % world.state.gen1_map_script(TOWER_7F_BYTE))
	_press_past_boxes(world)
	world.dispatch_sight_events()
	_press_past_boxes(world)
	var rocket: Gen2WorldObject = world.objects[TOWER_7F_ROCKET]
	_r.check(world.scripted_movement_in_progress() or rocket.cell != TOWER_7F_ROCKET_CELL,
		"the beaten rocket stood still.")
	_r.check(world.state.gen1_map_script(TOWER_7F_BYTE) == TOWER_7F_HIDE_STATE,
		"the tower stands on state %d behind the walk." % world.state.gen1_map_script(TOWER_7F_BYTE))
	for _pass: int in SCRIPTED_WALK_PASSES:
		world.advance_scripted_steps_pass()
		world.dispatch_sight_events()
		if not rocket.active:
			break
	_r.check(not rocket.active, "the rocket never left the map.")
	_r.check(world.state.gen1_map_script(TOWER_7F_BYTE) == 0,
		"the tower stayed on state %d." % world.state.gen1_map_script(TOWER_7F_BYTE))
	_r.note("gen1 walk POKEMON_TOWER_7F's rocket walked off and hid")


## `ChampionsRoomPlayerEntersScript`, which Agatha's own end-battle state sets.
const CHAMPIONS_ROOM_BYTE: int = 92
const CHAMPIONS_ROOM_ENTRANCE := Vector2i(3, 7)
const CHAMPIONS_ROOM_WALKED := Vector2i(4, 3)
const CHAMPIONS_ROOM_PLAYER_ENTERS: int = 1
const CHAMPION_CLASS: int = 43
const BEAT_CHAMPION_RIVAL_FLAG: int = 2305


func _check_the_champion() -> void:
	var world: Gen2WorldAPI = _r.open_world(0, CHAMPIONS_ROOM, CHAMPIONS_ROOM_ENTRANCE)
	if world == null:
		return
	world.state.set_gen1_starter("rival", int(SILPH_RIVAL_STARTER[_r.game_id]))
	world.state.set_gen1_map_script(CHAMPIONS_ROOM_BYTE, CHAMPIONS_ROOM_PLAYER_ENTERS)
	world.dispatch_map_entry()
	var passes: int = 0
	while world.pending_runtime_request().is_empty() and passes < SCRIPTED_WALK_PASSES:
		world.advance_player_step_pass()
		world.dispatch_sight_events()
		world.run_event_queue(true)
		passes += 1
	_r.check(world.player_cell == CHAMPIONS_ROOM_WALKED,
		"the player was walked to %s." % [world.player_cell])
	var request: Dictionary = world.pending_runtime_request()
	var values: Dictionary = request.get("values", {}) as Dictionary
	if not _r.check(StringName(request.get("kind", &"")) == &"battle_requested"
		and int(values.get("trainer_class", 0)) == CHAMPION_CLASS,
		"the champion asked for %s." % [request]):
		return
	world.complete_runtime_request({"ok": true, "outcome": Gen2WorldBattleAdapter.OUTCOME_WON})
	passes = 0
	while not world.event_flag_active(BEAT_CHAMPION_RIVAL_FLAG) and passes < SCRIPTED_WALK_PASSES:
		world.dispatch_sight_events()
		world.run_event_queue(true)
		passes += 1
	_r.check(world.event_flag_active(BEAT_CHAMPION_RIVAL_FLAG),
		"EVENT_BEAT_CHAMPION_RIVAL is clear after the win.")
	_r.note("gen1 walk CHAMPIONS_ROOM's rival fought after the entrance walk")


const SEAFOAM_B1F_HOLE := Vector2i(18, 6)
const SEAFOAM_B1F_BOULDER: int = 0
const SEAFOAM2_BOULDER1_FLAG: int = 2496


func _check_a_seafoam_boulder_hole() -> void:
	var world: Gen2WorldAPI = _r.open_world(0, SEAFOAM_B1F, SEAFOAM_B1F_HOLE + Vector2i.LEFT * 2)
	if world == null:
		return
	var boulder: Gen2WorldObject = world.objects[SEAFOAM_B1F_BOULDER]
	world.gen1_toggle_object(boulder.toggle_index, false)
	world.state.set_engine_flag(
		Gen1Layout.engine_flag_base("status_flags_1") + Gen1Layout.STRENGTH_ACTIVE_BIT, true
	)
	world.player_facing = Gen2WorldSprite.FACING_RIGHT
	world.player_input_move(Vector2i.RIGHT)
	world.player_input_move(Vector2i.RIGHT)
	if not _r.check(boulder.cell == SEAFOAM_B1F_HOLE,
		"the boulder stood on %s rather than the hole." % [boulder.cell]):
		return
	world.dispatch_sight_events()
	world.run_event_queue(true)
	_r.check(world.event_flag_active(SEAFOAM2_BOULDER1_FLAG),
		"the boulder on the hole left EVENT_SEAFOAM2_BOULDER1_DOWN_HOLE clear.")
	_r.check(boulder.deleted or not _object_active(world, SEAFOAM_B1F_BOULDER),
		"the fallen boulder is still on B1F.")
	_r.note("gen1 walk SEAFOAM_ISLANDS_B1F's first boulder down its hole")


func _first_text(results: Array) -> String:
	return _event_text(results) if not results.is_empty() else ""


const SAFARI_GATE: int = 0x9C
const SAFARI_GATE_WORKER_CELLS: Array[Vector2i] = [Vector2i(3, 2), Vector2i(4, 2)]
const SAFARI_CENTER: int = 0xDC
const SAFARI_CENTER_CELL := Vector2i(15, 25)
const SAFARI_ADMISSION: int = 500
## `SafariZoneGate_ScriptPointers` by name, which is what the walk drives.
const SAFARI_SCRIPT_JOIN: int = 2
const SAFARI_SCRIPT_MOVING_UP: int = 3
const SAFARI_SCRIPT_MOVING_DOWN: int = 4
const SAFARI_TIMES_UP: String = "PA: Ding-dong!"


## `SafariZoneGateWouldYouLikeToJoinScript` and `SafariZoneCheckSteps` behind it:
## the fee buys 30 balls and 502 steps, and running out warps back to the gate.
func _check_the_safari_zone() -> void:
	var world: Gen2WorldAPI = _safari_offer(SAFARI_ADMISSION)
	if world == null:
		return
	_safari_answer(world, 0)
	_r.check(
		world.state.safari_balls() == Gen1Layout.SAFARI_BALLS
			and world.state.safari_steps() == Gen1Layout.SAFARI_STEPS,
		"the fee bought %d balls and %d steps." % [
			world.state.safari_balls(), world.state.safari_steps(),
		]
	)
	_r.check(world.gen1_safari_active(), "the fee left EVENT_IN_SAFARI_ZONE clear.")
	_r.check(
		world.state.money(Gen2WorldMartHost.MONEY_ACCOUNT) == 0,
		"the fee left %d." % world.state.money(Gen2WorldMartHost.MONEY_ACCOUNT)
	)
	_check_the_safari_game_ends(world.state)
	_check_leaving_early()
	_check_the_safari_zone_refuses()
	_r.note("gen1 walk paid the SAFARI ZONE's %d and walked its %d steps out" % [
		SAFARI_ADMISSION, Gen1Layout.SAFARI_STEPS,
	])


func _check_the_safari_game_ends(state: Gen2WorldState) -> void:
	var world: Gen2WorldAPI = _r.open_world(0, SAFARI_CENTER, SAFARI_CENTER_CELL, state)
	if world == null:
		return
	var spent: int = 0
	while world.gen1_count_safari_step() == false and spent <= Gen1Layout.SAFARI_STEPS:
		spent += 1
	_r.check(spent == Gen1Layout.SAFARI_STEPS,
		"the timer ran out after %d steps." % spent)
	var said: Array[String] = _safari_spoken(world, world.dispatch_sight_events())
	_r.check(said.size() == 2 and said[0].begins_with(SAFARI_TIMES_UP),
		"the game over said %s." % [said])
	_r.check(world.map_id() == Vector2i(0, SAFARI_GATE),
		"the game over landed on %s." % [world.map_id()])
	_r.check(
		world.state.gen1_map_script(world.gen1_safari_gate_byte())
			== Gen1Layout.SAFARI_SCRIPT_LEAVING,
		"the gate stands on state %d." % world.state.gen1_map_script(
			world.gen1_safari_gate_byte()
		)
	)
	## `SafariZoneGateLeavingSafariScript` runs on the frame the gate is entered
	## and consumes the event the warp set, which is what says the game ended.
	_r.check(not world.gen1_safari_active(),
		"the gate left EVENT_IN_SAFARI_ZONE standing.")
	var haul: Array[String] = _safari_spoken(world, world.dispatch_sight_events())
	_r.check(haul.size() == 1 and not haul[0].is_empty(),
		"the gate said %s on the way out." % [haul])
	_r.check(world.state.safari_balls() == 0,
		"the gate left %d balls." % world.state.safari_balls())


## `SafariZoneGateSafariZoneWorker1LeavingEarlyText`'s YES: the walk down, both
## events cleared, and `wNextSafariZoneGateScript`'s 0 rather than NO's 5.
const SAFARI_GATE_TOP := Vector2i(3, 0)
const SAFARI_SCRIPT_LEAVE_EARLY_LANDING := Vector2i(3, 3)


func _check_leaving_early() -> void:
	var state := Gen2WorldState.new()
	state.set_event_flag(Gen1Layout.IN_SAFARI_ZONE_EVENT, true)
	state.set_safari_balls(Gen1Layout.SAFARI_BALLS)
	state.set_safari_steps(Gen1Layout.SAFARI_STEPS)
	var world: Gen2WorldAPI = _r.open_world(0, SAFARI_GATE, SAFARI_GATE_TOP, state)
	if world == null:
		return
	world.state.set_gen1_map_script(world.gen1_safari_gate_byte(), SAFARI_SCRIPT_MOVING_UP)
	## `SafariZoneGatePlayerMovingUpScript` hands the question to the next frame.
	world.dispatch_sight_events()
	world.dispatch_sight_events()
	if not _r.check(
		StringName(world.pending_script_input().get("type", &"")) == &"choice",
		"the gate asked %s of a player leaving early." % [world.pending_script_input()]
	):
		return
	_safari_answer(world, 0)
	var passes: int = 0
	while (world.gen1_player_movement_running() or world.player_step_in_progress()) 		and passes < SCRIPTED_WALK_PASSES:
		world.advance_player_step_pass()
		world.dispatch_sight_events()
		passes += 1
	world.dispatch_sight_events()
	_r.check(world.player_cell == SAFARI_SCRIPT_LEAVE_EARLY_LANDING
		and world.state.gen1_map_script(world.gen1_safari_gate_byte()) == 0,
		"leaving early left the player on %s at state %d." % [
			world.player_cell, world.state.gen1_map_script(world.gen1_safari_gate_byte())])
	_r.check(not world.gen1_safari_active() and not world.event_flag_active(Gen1Layout.SAFARI_GAME_OVER_EVENT),
		"leaving early left the game's events standing.")


## Red and Blue walk a short purse back down; Yellow's own two routines hand out
## a reduced admission instead, and nothing at all until the fourth empty visit.
func _check_the_safari_zone_refuses() -> void:
	var world: Gen2WorldAPI = _safari_offer(SAFARI_ADMISSION - 1)
	if world == null:
		return
	_safari_answer(world, 0)
	if _r.game_id != RomRegistry.YELLOW:
		_r.check(world.state.safari_balls() == 0
			and world.state.gen1_map_script(world.gen1_safari_gate_byte())
				== SAFARI_SCRIPT_MOVING_DOWN,
			"a short purse bought %d balls." % world.state.safari_balls())
		return
	@warning_ignore("integer_division")
	var discounted: int = mini(
		(SAFARI_ADMISSION - 1) / Gen1Layout.SAFARI_LOW_COST_DIVISOR
			% Gen1Layout.SAFARI_LOW_COST_DIGITS + 1,
		Gen1Layout.SAFARI_LOW_COST_MAX_BALLS
	)
	_r.check(world.state.safari_balls() == discounted
		and world.state.money(Gen2WorldMartHost.MONEY_ACCOUNT) == 0,
		"¥%d bought %d balls, wanted %d." % [
			SAFARI_ADMISSION - 1, world.state.safari_balls(), discounted,
		])
	_check_the_safari_zone_nags()


func _check_the_safari_zone_nags() -> void:
	var state := Gen2WorldState.new()
	for visit: int in Gen1Layout.SAFARI_NAG_GIFT_VISIT + 1:
		var world: Gen2WorldAPI = _safari_offer(0, state)
		if world == null:
			return
		_safari_answer(world, 0)
		var owed: int = Gen1Layout.SAFARI_NAG_BALLS \
			if visit == Gen1Layout.SAFARI_NAG_GIFT_VISIT else 0
		_r.check(state.safari_balls() == owed,
			"visit %d of an empty purse bought %d balls." % [visit, state.safari_balls()])


func _safari_spoken(world: Gen2WorldAPI, results: Array) -> Array[String]:
	var said: Array[String] = []
	while not results.is_empty() and said.size() < Gen1Layout.MAX_OBJECT_EVENTS:
		var text: String = _event_text(results)
		if not text.is_empty():
			said.append(text)
		results = world.run_event_queue(true)
	return said


func _safari_answer(world: Gen2WorldAPI, choice: int) -> void:
	var results: Array = world.choose_script_input(choice)
	var guard: int = 0
	while not results.is_empty() and guard < Gen1Layout.MAX_OBJECT_EVENTS:
		results = world.run_event_queue(true)
		guard += 1


func _safari_offer(purse: int, state: Gen2WorldState = null) -> Gen2WorldAPI:
	var world: Gen2WorldAPI = _r.open_world(
		0, SAFARI_GATE, SAFARI_GATE_WORKER_CELLS[0], state
	)
	if world == null:
		return null
	world.state.apply_changes({}, {}, {
		"money": {Gen2WorldMartHost.MONEY_ACCOUNT: purse},
	})
	world.state.set_gen1_map_script(world.gen1_safari_gate_byte(), SAFARI_SCRIPT_JOIN)
	world.dispatch_sight_events()
	return world if _r.check(
		not String(world.pending_script_input().get("text", "")).is_empty(),
		"the SAFARI ZONE gate offered nothing on a %d purse." % purse
	) else null


const CINNABAR_GYM: int = 166
const CINNABAR_GATES: Array[Vector2i] = [
	Vector2i(9, 3), Vector2i(6, 3), Vector2i(6, 6),
	Vector2i(3, 8), Vector2i(2, 6), Vector2i(2, 3),
]


func _check_cinnabar_gates() -> void:
	for trainer: int in range(1, 8):
		for won: bool in [false, true]:
			_check_cinnabar_trainer(trainer, won)
	_r.note("gen1 Cinnabar: seven trainers, both battle outcomes, six gates and re-entry")
	_check_the_cinnabar_quiz()


func _check_the_cinnabar_quiz() -> void:
	var world: Gen2WorldAPI = _r.open_world(0, CINNABAR_GYM, Vector2i(17, 3))
	if world == null:
		return
	world.dispatch_map_entry()
	var machines: Array = _quiz_machines(world)
	if not _r.check(machines.size() == CINNABAR_GATES.size(), "%d quiz machines answer." % machines.size()):
		return
	var right: Dictionary = machines[0]
	_r.check(_quiz_asked(world, right).begins_with(QUIZ_INTRO), "the first quiz opened on the wrong box.")
	_r.check(_quiz_answered(world, int(right["answer"])).begins_with(QUIZ_RIGHT),
		"the right answer was not taken.")
	_r.check(world.event_flag_active(CINNABAR_GATE_FLAG), "the first gate's flag is clear.")
	_r.check(world.block_at(CINNABAR_GATES[0].x, CINNABAR_GATES[0].y) == CINNABAR_GATE_OPEN,
		"the first gate did not open on the spot.")
	var wrong: Dictionary = machines[1]
	_r.check(_quiz_asked(world, wrong).begins_with(QUIZ_SHORT_INTRO), "the second quiz opened on the wrong box.")
	_r.check(_quiz_answered(world, 1 - int(wrong["answer"])).begins_with(QUIZ_WRONG),
		"the wrong answer was not refused.")
	_r.check(world.block_at(CINNABAR_GATES[1].x, CINNABAR_GATES[1].y) == CINNABAR_GATE_LOCKED,
		"a wrong answer opened the gate.")
	var trainer: Gen2WorldObject = world.objects[QUIZ_TRAINER_OBJECT]
	var stood: Vector2i = trainer.cell
	world.dispatch_sight_events()
	_r.check(world.scripted_movement_in_progress() or trainer.cell != stood,
		"the trainer did not walk up after a wrong answer.")
	for _pass: int in SCRIPTED_WALK_PASSES:
		if not world.pending_runtime_request().is_empty():
			break
		world.advance_scripted_steps_pass()
		world.dispatch_sight_events()
		world.run_event_queue(true)
	_r.check(StringName(world.pending_runtime_request().get("kind", &"")) == &"battle_requested",
		"the trainer never asked for a fight after the wrong answer.")
	_r.note("gen1 Cinnabar quiz: a right answer opens gate 1, a wrong one brings trainer %d" % [
		QUIZ_TRAINER_OBJECT,
	])


func _quiz_machines(world: Gen2WorldAPI) -> Array:
	var machines: Array = []
	for row: Dictionary in world.current_map.events["hidden_events"] as Array:
		var choice: Dictionary = _first_node(row.get("script", []) as Array, "choice")
		if choice.is_empty():
			continue
		var answer: int = 0 if not _first_node(choice["yes"] as Array, "flag").is_empty() else 1
		machines.append({"cell": Vector2i(int(row["x"]), int(row["y"])), "answer": answer})
	return machines


func _first_node(nodes: Array, op: String) -> Dictionary:
	for node: Dictionary in nodes:
		if String(node["op"]) == op:
			return node
		for key: String in Gen1Layout.SCRIPT_BRANCH_KEYS:
			if node.has(key):
				var found: Dictionary = _first_node(node[key] as Array, op)
				if not found.is_empty():
					return found
	return {}


func _quiz_asked(world: Gen2WorldAPI, machine: Dictionary) -> String:
	world.player_cell = (machine["cell"] as Vector2i) + Vector2i.DOWN
	world.player_facing = Gen2WorldSprite.FACING_UP
	var results: Array = world.interact()
	var said: Array[String] = []
	while not results.is_empty() and StringName(world.pending_script_input().get("type", &"")) != &"choice" \
		and said.size() < Gen1Layout.MAX_OBJECT_EVENTS:
		said.append(_event_text(results))
		results = world.run_event_queue(true)
	return "\n".join(said)


func _quiz_answered(world: Gen2WorldAPI, choice: int) -> String:
	var results: Array = world.choose_script_input(choice)
	var said: Array[String] = []
	while not results.is_empty() and said.size() < Gen1Layout.MAX_OBJECT_EVENTS:
		said.append(_event_text(results))
		results = world.run_event_queue(true)
	return "\n".join(said)


const CINNABAR_GATE_FLAG: int = 681
const CINNABAR_GATE_OPEN: int = 0x0E
const CINNABAR_GATE_LOCKED: int = 0x54
const QUIZ_TRAINER_OBJECT: int = 3
const QUIZ_INTRO: String = "POKéMON Quiz!"
const QUIZ_SHORT_INTRO: String = "POKéMON Quiz!"
const QUIZ_RIGHT: String = "You're absolutely\ncorrect!"
const QUIZ_WRONG: String = "Sorry! Bad call!"


func _check_cinnabar_trainer(trainer: int, won: bool) -> void:
	var world: Gen2WorldAPI = _r.open_world(0, CINNABAR_GYM, Vector2i(17, 3))
	if world == null:
		return
	world.dispatch_map_entry()
	var object: Dictionary = (world.current_map.events["objects"] as Array)[trainer]
	world.player_cell = Vector2i(int(object["x"]), int(object["y"]) + 1)
	world.player_facing = Gen2WorldSprite.FACING_UP
	if _r.game_id == RomRegistry.YELLOW and trainer > 1:
		_r.check(not _event_text(world.interact()).is_empty(), "the quiz requirement has no text")
		world.run_event_queue(true)
		_r.check(world.pending_runtime_request().is_empty(), "a trainer skipped Yellow's quiz gate")
		world._gen1_volatile["gym_quiz_answered"] = true
	world.interact()
	for _pass: int in 12:
		if not world.pending_runtime_request().is_empty():
			break
		world.run_event_queue(true)
	if not _r.check(StringName(world.pending_runtime_request().get("kind", &"")) \
		== &"battle_requested", "Cinnabar trainer %d never requested a battle" % trainer):
		return
	world.complete_runtime_request({"ok": true, "outcome": &"won" if won else &"lost"})
	for _pass: int in 12:
		world.run_event_queue(true)
		world.dispatch_sight_events()
	_r.check(world.event_flag_active(665 + trainer) == won, "the trainer's beaten flag is wrong")
	_r.check(world.event_flag_active(679 + trainer) == won, "the trainer's gate flag is wrong")
	_check_cinnabar_blocks(world, trainer, won)
	var returned: Gen2WorldAPI = _r.open_world(0, CINNABAR_GYM, Vector2i(17, 3), world.state)
	if returned != null:
		returned.dispatch_map_entry()
		_check_cinnabar_blocks(returned, trainer, won)


func _check_cinnabar_blocks(world: Gen2WorldAPI, trainer: int, won: bool) -> void:
	for gate: int in CINNABAR_GATES.size():
		var cell: Vector2i = CINNABAR_GATES[gate]
		var expected: int = 0x5F if gate == 3 else 0x54
		if won and gate == trainer - 2:
			expected = 0x0E
		_r.check(world.block_at(cell.x, cell.y) == expected,
			"trainer %d won=%s gate %d is %02x, expected %02x" % [
				trainer, won, gate + 1, world.block_at(cell.x, cell.y), expected])


## `.checkNorthMap` adds `wNorthConnectedMapXAlignment` to `wXCoord`.
const ROUTE_1: int = 12
const ROUTE_1_ROAD_TOP := Vector2i(11, 0)
const VIRIDIAN_ROAD_BOTTOM := Vector2i(21, 35)
const VIRIDIAN_CITY_ID: int = 1


func _check_a_connection_lands_aligned() -> void:
	var world: Gen2WorldAPI = _r.open_world(0, ROUTE_1, ROUTE_1_ROAD_TOP)
	if world == null:
		return
	var crossed: Dictionary = world.move_result(Vector2i.UP)
	_r.check(bool(crossed.get("ok", false)) and world.map_id() == Vector2i(0, VIRIDIAN_CITY_ID)
		and world.player_cell == VIRIDIAN_ROAD_BOTTOM,
		"Route 1's road crossed onto %s at %s." % [world.map_id(), world.player_cell])
	var back: Dictionary = world.move_result(Vector2i.DOWN)
	_r.check(bool(back.get("ok", false)) and world.player_cell == ROUTE_1_ROAD_TOP,
		"Viridian's road crossed back onto %s at %s." % [world.map_id(), world.player_cell])
	_r.note("gen1 walk ROUTE_1 onto VIRIDIAN_CITY ten cells over and back")


## `ViridianMartDefaultScript`'s two clerk rows sit past the three the objects name.
const VIRIDIAN_MART: int = 42
const VIRIDIAN_MART_MAT := Vector2i(3, 7)
const VIRIDIAN_MART_WALKED := Vector2i(2, 5)
const OAKS_PARCEL_ITEM: int = 0x46
const GOT_OAKS_PARCEL_FLAG: int = 57
const PARCEL_CLERK_GREETS: String = "Hey! You came from"


func _check_the_parcel_clerk() -> void:
	var world: Gen2WorldAPI = _r.open_world(0, VIRIDIAN_MART, VIRIDIAN_MART_MAT)
	if world == null:
		return
	var spoken: Array[String] = []
	for _pass: int in LAB_PASSES:
		spoken.append_array(_lab_answers(world, world.dispatch_sight_events()))
		world.advance_player_step_pass()
		if world.event_flag_active(GOT_OAKS_PARCEL_FLAG):
			break
	_r.check("\n".join(spoken).begins_with(PARCEL_CLERK_GREETS),
		"the clerk opened with %s." % ["\n".join(spoken).left(60)])
	_r.check(world.player_cell == VIRIDIAN_MART_WALKED,
		"the clerk's walk left the player on %s." % [world.player_cell])
	_r.check(world.state.item_quantity(OAKS_PARCEL_ITEM) == 1
		and world.event_flag_active(GOT_OAKS_PARCEL_FLAG),
		"the clerk handed over %d parcels." % world.state.item_quantity(OAKS_PARCEL_ITEM))
	_r.note("gen1 walk VIRIDIAN_MART's clerk walked the player in and handed the parcel over")


## `GivePokemon`'s carry through [Gen2WorldPartyHost], which the screen uses.
func _check_a_gift_lands_in_the_party() -> void:
	var world: Gen2WorldAPI = _r.open_world(0, OAKS_LAB, LAB_BELOW_CHARMANDER)
	if world == null:
		return
	world.state.set_gen1_map_script(OAKS_LAB_BYTE, LAB_DONT_GO_AWAY)
	world.state.set_event_flag(OAK_ASKED_TO_CHOOSE_FLAG)
	world.player_facing = Gen2WorldSprite.FACING_UP
	var save: Gen2SaveData = Gen2SaveStore.create_new_game(_r.data, 0, "RED")
	world.interact()
	var hosted: Dictionary = {}
	for _turn: int in LAB_PASSES:
		var request: Dictionary = world.pending_runtime_request()
		var input: Dictionary = world.pending_script_input()
		if StringName(request.get("kind", &"")) == &"pokemon_requested":
			hosted = Gen2WorldPartyHost.complete_runtime_request(world, {"ok": true}, save, false)
			break
		if not request.is_empty():
			world.complete_runtime_request({"ok": true})
		elif not input.is_empty():
			world.choose_script_input(0 if StringName(input.get("type", &"")) == &"choice" else -1)
		else:
			break
	_r.check(bool(hosted.get("ok", false)), "the host refused the ball: %s" % [hosted])
	_r.check(save.party.size() == 1 and int(save.party[0].species) == CHARMANDER_DEX,
		"the ball left the party as %s." % [save.party.map(func(mon: Gen2SaveMon) -> int: return mon.species)])
	_r.note("gen1 walk OAKS_LAB's ball put CHARMANDER in the party through the host")


## `hTextID` and `hSpriteIndex` are one byte, so the map script's own row fights.
const MT_MOON_NERD_CELL := Vector2i(13, 8)
const SUPER_NERD_CLASS: int = 8


func _check_the_map_script_names_the_nerd() -> void:
	var world: Gen2WorldAPI = _r.open_world(0, MT_MOON_B2F, MT_MOON_NERD_CELL)
	if world == null:
		return
	var results: Array = world.dispatch_sight_events()
	var request: Dictionary = {}
	for _turn: int in LAB_PASSES:
		request = world.pending_runtime_request()
		if not request.is_empty() or results.is_empty():
			break
		results = world.run_event_queue(true)
	var values: Dictionary = request.get("values", {})
	_r.check(int(values.get("trainer_class", 0)) == SUPER_NERD_CLASS,
		"the fossil floor's script fought %s." % [request])
	_r.note("gen1 walk MT_MOON_B2F's script fights the super nerd, not the last trainer met")


## `SSAnneCaptainsRoomRubCaptainsBackText` carries its own `text_asm`.
const SS_ANNE_CAPTAINS_ROOM: int = 101
const BELOW_CAPTAIN := Vector2i(4, 3)
const RUBBED_CAPTAINS_BACK_FLAG: int = 1505
const GOT_HM01_FLAG: int = 1504
const HM01_ITEM: int = 0xC4


func _check_the_captains_back() -> void:
	var world: Gen2WorldAPI = _r.open_world(0, SS_ANNE_CAPTAINS_ROOM, BELOW_CAPTAIN)
	if world == null:
		return
	world.player_facing = Gen2WorldSprite.FACING_UP
	_lab_answers(world, world.interact())
	_r.check(world.event_flag_active(RUBBED_CAPTAINS_BACK_FLAG),
		"EVENT_RUBBED_CAPTAINS_BACK is clear after the rub.")
	_r.check(world.event_flag_active(GOT_HM01_FLAG) and world.state.item_quantity(HM01_ITEM) == 1,
		"the captain handed over %d HM01." % world.state.item_quantity(HM01_ITEM))
	_r.note("gen1 walk SS_ANNE_CAPTAINS_ROOM's rub sets its own flag and pays HM01")


## `VermilionDock_Script` reads `wDestinationWarpID`: off the ship with HM01 it
## runs `VermilionDockSSAnneLeavesScript`, and Vermilion walks the player on.
const SS_ANNE_1F: int = 95
const SS_ANNE_GANGWAY := Vector2i(26, 0)
const VERMILION_DOCK: int = 94
const DOCK_GANGWAY := Vector2i(14, 2)
const SS_ANNE_LEFT_FLAG: int = 1506
const VERMILION_PAST_SAILOR := Vector2i(18, 29)
const SHIP_LEAVES_PASSES: int = 1400


func _check_the_ship_leaves() -> void:
	var snapshot := Gen2WorldSnapshot.new()
	snapshot.map_id = Vector2i(0, SS_ANNE_1F)
	snapshot.player_cell = SS_ANNE_GANGWAY
	snapshot.player_facing = Gen2WorldSprite.FACING_UP
	snapshot.gen1_last_map = VERMILION_CITY
	snapshot.world_state = Gen2WorldState.new()
	snapshot.world_state.set_event_flag(GOT_HM01_FLAG)
	var world: Gen2WorldAPI = Gen2WorldAPI.open_snapshot(_r.data, snapshot)
	if not _r.check(world != null and bool(world.try_warp().get("ok", false)),
		"the gangway did not lead to the dock."):
		return
	for _pass: int in SHIP_LEAVES_PASSES:
		world.dispatch_sight_events()
		_drive_one_pass(world)
		if not world.scripted_movement_in_progress() and world.map_id() == Vector2i(0, VERMILION_CITY) \
			and world.player_cell == VERMILION_PAST_SAILOR:
			break
	_r.check(world.event_flag_active(SS_ANNE_LEFT_FLAG), "EVENT_SS_ANNE_LEFT is clear.")
	_r.check(world.map_id() == Vector2i(0, VERMILION_CITY) and world.player_cell == VERMILION_PAST_SAILOR,
		"the ship left the player on %s at %s." % [world.map_id(), world.player_cell])
	var dock: Gen2WorldAPI = _r.open_world(0, VERMILION_DOCK, DOCK_GANGWAY, world.state)
	if dock == null:
		return
	_r.check(not dock.warp_at(DOCK_GANGWAY).is_empty(),
		"the gangway is gone from a dock loaded fresh.")
	_r.note("gen1 walk the S.S. ANNE left, and the dock walked the player out past the sailor")


## `Route8GateMovePlayerRightScript` fills the joypad buffer by hand.
const ROUTE_8_GATE: int = 79
const ROUTE_8_GATE_CELL := Vector2i(2, 3)


func _check_the_gate_pushes_back() -> void:
	var world: Gen2WorldAPI = _r.open_world(0, ROUTE_8_GATE, ROUTE_8_GATE_CELL)
	if world == null:
		return
	world.player_facing = Gen2WorldSprite.FACING_LEFT
	_lab_answers(world, world.dispatch_sight_events())
	_r.check(world.gen1_player_movement_running() or world.player_cell == ROUTE_8_GATE_CELL + Vector2i.RIGHT,
		"the guard left the player standing on %s." % [world.player_cell])
	for _pass: int in LAB_PASSES:
		_drive_one_pass(world)
		if not world.scripted_movement_in_progress():
			break
	_r.check(world.player_cell == ROUTE_8_GATE_CELL + Vector2i.RIGHT,
		"the push left the player on %s." % [world.player_cell])
	_r.note("gen1 walk ROUTE_8_GATE's guard pushed the player a cell right")
