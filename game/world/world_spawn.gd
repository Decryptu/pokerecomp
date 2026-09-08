class_name Gen2WorldSpawn
extends RefCounted


const NEW_BARK_GROUP: int = 24
const PLAYERS_HOUSE_2F: int = 7
const HOME_CELL: Vector2i = Vector2i(3, 3)
const HOME_FACING: int = Gen2WorldSprite.FACING_DOWN
const START_MONEY: int = 3000
const GEN1_POTION: int = 0x14
## InitDecorations (engine/overworld/decorations.asm): DECO_FEATHERY_BED and
## DECO_TOWN_MAP. The other two maptile slots remain zero.
const INITIAL_MAPTILE_DECORATIONS: Dictionary = {&"bed": 0x02, &"poster": 0x10}
## `InitializeEventsScript` owns the two flags that say the player *has* those
## two, which is what puts them on `_PlayerDecorationMenu`'s own lists:
## `EVENT_DECO_BED_1` and `EVENT_DECO_POSTER_1`.
const INITIAL_DECORATION_FLAGS: Array[int] = [676, 687]


static func gen1_new_game_snapshot(data: GameData) -> Gen2WorldSnapshot:
	var warp: Dictionary = data.gen1_new_game_warp()
	if warp.is_empty():
		return null
	var map: Gen2WorldMap = data.world_map(0, int(warp["map"]))
	var cell := Vector2i(int(warp["x"]), int(warp["y"]))
	if map == null or data.world_tileset(map.tileset) == null \
		or cell.x < 0 or cell.y < 0 \
		or cell.x >= map.collision_width or cell.y >= map.collision_height:
		return null
	var snapshot := Gen2WorldSnapshot.new()
	snapshot.map_id = Vector2i(0, int(warp["map"]))
	snapshot.player_cell = cell
	snapshot.player_facing = HOME_FACING
	snapshot.movement_mode = Gen2WorldAPI.MOVEMENT_WALK
	snapshot.gen1_last_map = Gen1Layout.PALLET_TOWN
	snapshot.world_state = Gen2WorldState.new({}, {}, {}, {0: START_MONEY})
	snapshot.world_state.apply_changes({}, {}, {"pc_items": {GEN1_POTION: 1}})
	return snapshot


static func new_game_snapshot(data: GameData) -> Gen2WorldSnapshot:
	if data == null:
		return null
	if data.generation == RomRegistry.GEN1:
		return gen1_new_game_snapshot(data)
	var map: Gen2WorldMap = data.world_map(NEW_BARK_GROUP, PLAYERS_HOUSE_2F)
	if map == null or data.world_tileset(map.tileset) == null:
		return null
	if HOME_CELL.x < 0 or HOME_CELL.y < 0 \
		or HOME_CELL.x >= map.collision_width or HOME_CELL.y >= map.collision_height:
		return null
	var snapshot := Gen2WorldSnapshot.new()
	snapshot.map_id = Vector2i(NEW_BARK_GROUP, PLAYERS_HOUSE_2F)
	snapshot.player_cell = HOME_CELL
	snapshot.player_facing = HOME_FACING
	snapshot.movement_mode = Gen2WorldAPI.MOVEMENT_WALK
	snapshot.world_state = Gen2WorldState.new({}, {}, {}, {0: START_MONEY})
	apply_initial_decorations(snapshot.world_state)
	return snapshot


## `InitDecorations` on its own, for a world built without going through
## [method new_game_snapshot]. It runs once at new game and every state the
## game can be in has run it, so a world that skips it stands in a room the
## player's bedroom never is: no bed and no poster, and the `.blk`'s own
## placeholder blocks in their place.
static func apply_initial_decorations(state: Gen2WorldState) -> void:
	if state == null:
		return
	for category: StringName in INITIAL_MAPTILE_DECORATIONS:
		state.set_maptile_decoration(
			category, int(INITIAL_MAPTILE_DECORATIONS[category])
		)
	for flag: int in INITIAL_DECORATION_FLAGS:
		state.set_event_flag(flag, true)
