extends RefCounted

## Every Generation 1 warp and every ledge, swept on Red, Blue and Yellow. A
## Generation 1 map's collision grid holds the tile a cell draws, so what is
## proved here is the six tables [Gen2WorldCollision] carries for it: the
## tileset's passable list decides a step, `WarpTileIDPointers` and
## `DoorTileIDPointers` decide whether a warp fires, and `LedgeTiles` decides a
## hop. Each is swept against the imported corpus rather than one sampled map.

## `data/maps/objects`' own totals, and the `LAST_MAP` warps inside them.
const WARP_CENSUS: Dictionary = {
	&"red": {"warps": 813, "last_map": 251, "driven": 554, "hops": 758},
	&"blue": {"warps": 813, "last_map": 251, "driven": 554, "hops": 758},
	&"yellow": {"warps": 817, "last_map": 253, "driven": 556, "hops": 756},
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

## `ViridianMart_Object`'s clerk, who stands at 0,5 behind the counter at 1,5.
## `.extendRangeOverCounter` is what lets the player at 2,5 reach them.
const VIRIDIAN_MART: int = 42
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
const BIKE_SHOP: int = 66
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

var _r: RefCounted = null


func run(r: RefCounted) -> void:
	_r = r
	r.each_game_of(RomRegistry.GEN1, _one_game)


func _one_game() -> void:
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
	_check_a_gym_statue()
	_check_a_bench_guy()
	_check_a_bookshelf()
	_check_a_card_key_door()
	_check_the_day_care()


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
	world.complete_runtime_request({"ok": true})
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
			_r.check(
				world.player_cell == Vector2i(int(destination["x"]), int(destination["y"])),
				"map %d warp %d landed on %s" % [map.number, index, world.player_cell]
			)
	_r.check(warps == int(pinned["warps"]), "%d warps, wanted %d" % [warps, pinned["warps"]])
	_r.check(last_map == int(pinned["last_map"]),
		"%d LAST_MAP warps, wanted %d" % [last_map, pinned["last_map"]])
	_r.check(driven == int(pinned["driven"]),
		"%d warps taken, wanted %d" % [driven, pinned["driven"]])
	_r.check(arrival_only == ARRIVAL_ONLY, "warps firing from no facing: %s" % [arrival_only])
	_r.check(unstandable == UNSTANDABLE_WARPS, "warps on an impassable tile: %s" % [unstandable])
	_r.note("%d warps, %d back to LAST_MAP, %d taken" % [warps, last_map, driven])


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

	## The floor loaded again: the coordinates become the door's flag and the
	## callback leaves that one alone.
	var again: Gen2WorldAPI = _r.open_world(
		0, SILPH_CO_2F, SILPH_DOOR_APPROACH, world.state
	)
	if again == null:
		return
	again.dispatch_map_entry()
	_r.check(again.state.card_key_door() == Gen2WorldState.NO_CARD_KEY_DOOR,
		"the reloaded floor kept %s." % [again.state.card_key_door()])
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
			world.state.set_engine_flag(Gen2WorldState.BADGE_ENGINE_FLAGS[
				Gen2WorldState.KANTO_BADGE_FIRST
			], true)
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
