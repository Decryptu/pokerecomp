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
## `CeladonGameCornerText5` is half machine code: while EVENT_GOT_10_COINS is
## clear it gives coins instead of speaking, and says nothing here.
const BIKE_SHOP: int = 66
const BIKE_YOUNGSTER := Vector2i(1, 4)
const BIKE_FLAG: int = 192
const BIKE_BOXES: Array[String] = ["These BIKEs are", "Wow. Your BIKE is"]
const LAVENDER_TOWN: int = 4
const GHOST_GIRL := Vector2i(15, 10)
const GHOST_ANSWERS: Array[String] = ["Really? So there", "Hahaha, I guess"]
const GAME_CORNER: int = 135
const GAME_CORNER_GAMBLER := Vector2i(5, 12)
const GAME_CORNER_FLAG: int = 442
const GAME_CORNER_BOX: String = "Wins seem to come"

## Yellow's `CeruleanBadgeHouse` melanie, the corpus's one box that owes no
## press: `DisableWaitingAfterTextDisplay` runs before her last `PrintText`.
const MELANIE_MAP: int = 63
const MELANIE_CELL := Vector2i(3, 2)
const MELANIE_FLAG: int = 168
const MELANIE_BOX: String = "Is BULBASAUR"

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
	_check_the_nurse_heals()
	_check_the_cable_club()
	_check_the_vending_machine()
	_check_the_prize_counter()


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
	var silent: String = _scripted_box(GAME_CORNER, GAME_CORNER_GAMBLER, 0)
	_r.check(silent.is_empty(), "the half-read row said %s." % [silent])
	var spoken: String = _scripted_box(
		GAME_CORNER, GAME_CORNER_GAMBLER, GAME_CORNER_FLAG
	)
	_r.check(spoken.begins_with(GAME_CORNER_BOX), "its other side said %s." % [spoken])
	_check_the_ghost_girl()
	if _r.game_id == RomRegistry.YELLOW:
		_check_a_box_owing_no_press()


## The string one interaction opens with, or "" when it opened no box at all.
## [param flag] is an event flag to set first, or 0 for none.
func _scripted_box(map: int, cell: Vector2i, flag: int) -> String:
	var world: Gen2WorldAPI = _r.open_world(0, map, cell)
	if world == null:
		return ""
	if flag > 0:
		world.set_event_flag(flag)
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
