extends RefCounted

var _r: RefCounted = null

## Verifies Waterfall against freshly imported real caches, for both command
## profiles. Expected values come from WaterfallFunction, CheckWaterfallTile and
## Script_UsedWaterfall, byte identical between the pins. The real-cartridge half
## of tests/unit/test_world_field_move.gd: it climbs every column shipped.


## Pinned so a cache change is loud. A column is a waterfall cell with none below it.
## An edge column is one drawn up to the map's own top row, where the climb stops
## on the last row rather than on the first cell that is not a waterfall.
const EXPECTED_CENSUS: Dictionary = {
	# game id: [waterfall cells, columns, edge columns, maps carrying one]
	&"gold": [164, 34, 4, 4],
	&"silver": [164, 34, 4, 4],
	&"crystal": [164, 34, 4, 4],
}

## constants/map_constants.asm, DUNGEONS: Crystal's extra maps push it eight later.
const WHIRL_ISLANDS_GROUP: int = 3
const WHIRL_ISLANDS_B2F_CRYSTAL: int = 72
const WHIRL_ISLANDS_B2F_GOLD_SILVER: int = 64
## The fall's foot and the ledge it lands on. Twelve cells, thirteen steps:
## `.CheckContinueWaterfall` spends one more on the cell that ends the column.
const WHIRL_FOOT := Vector2i(12, 25)
const WHIRL_COLUMN: int = 12
const WHIRL_LANDING := Vector2i(12, 13)

const MAX_COLUMN: int = 12


func run(r: RefCounted) -> void:
	_r = r
	for game_id: StringName in _r.GAME_IDS:
		var data: GameData = GameData.open(game_id)
		if data == null:
			_r.fail("%s cache is unavailable. Import roms/%s.gbc first." % [game_id, game_id])
			continue
		var crystal: bool = Gen2WorldState.is_crystal_profile(data)
		_verify_whirl_islands(game_id, data, crystal)
		_sweep_columns(game_id, data, crystal)


func _sweep_columns(game_id: StringName, data: GameData, crystal: bool) -> void:
	var cells: int = 0
	var columns: int = 0
	var edge_columns: int = 0
	var maps: int = 0
	var refused: Array[String] = []
	for map: Gen2WorldMap in data.world_maps():
		var world: Gen2WorldAPI = _climber(data, crystal, map.group, map.number, Vector2i.ZERO)
		if world == null:
			continue
		var here: int = 0
		for foot: Vector2i in _column_feet(world):
			here += 1
			columns += 1
			var climbed: Dictionary = _climb(data, crystal, map, foot)
			if bool(climbed.get("edge", false)):
				edge_columns += 1
			if not bool(climbed.get("ok", false)):
				refused.append("%d/%d %s: %s" % [
					map.group, map.number, foot, climbed.get("reason", "unknown"),
				])
		cells += _waterfall_cells(world)
		if here > 0:
			maps += 1
			if _border_is_waterfall(world, map):
				refused.append("%d/%d: its border block is a waterfall" % [
					map.group, map.number,
				])
	_r.check(
		refused.is_empty(),
		"%s: a real waterfall column did not climb: %s" % [
			game_id, ", ".join(refused.slice(0, 3)),
		]
	)
	var expected: Array = EXPECTED_CENSUS[game_id]
	_r.check(
		[cells, columns, edge_columns, maps] == expected,
		"%s: waterfall census is %s, expected %s." % [
			game_id, [cells, columns, edge_columns, maps], expected,
		]
	)
	print("%s waterfall: %d cells, %d columns over %d maps, all climbed, %d of them to the map's top row." % [
		game_id, cells, columns, maps, edge_columns,
	])


## One column, from the water below its foot. `edge` marks one drawn up to the
## map's own top row, where the climb ends on that row: the cartridge reads the
## border block above it, never a waterfall (asserted below), and stops one row
## further into padding this port has no cell for.
func _climb(
	data: GameData, crystal: bool, map: Gen2WorldMap, foot: Vector2i
) -> Dictionary:
	var stand: Vector2i = foot + Vector2i.DOWN
	var world: Gen2WorldAPI = _climber(data, crystal, map.group, map.number, stand)
	if world == null:
		return {"ok": false, "reason": "the map did not open"}
	if world.player_cell != stand:
		return {"ok": false, "reason": "the cell below the fall is off the map"}
	var staged: Dictionary = world.waterfall_request()
	if not bool(staged.get("ok", false)):
		return {"ok": false, "reason": String(staged.get("reason", "unknown"))}
	if world.player_cell != stand:
		return {"ok": false, "reason": "staging moved the player"}
	var applied: Dictionary = world.complete_waterfall()
	if not bool(applied.get("ok", false)):
		return {"ok": false, "reason": String(applied.get("reason", "unknown"))}
	var edge: bool = int(applied["cell"].y) == 0 \
		and Gen2WorldFieldMove.waterfall_tile(world.collision_code_at(applied["cell"]))
	var paced: Dictionary = _verify_pacing(world, applied, stand, edge)
	paced["edge"] = edge
	return paced


func _verify_pacing(
	world: Gen2WorldAPI, applied: Dictionary, stand: Vector2i, edge: bool = false
) -> Dictionary:
	var steps: int = int(applied["steps"])
	var landing: Vector2i = applied["cell"]
	if steps < 2 or steps > MAX_COLUMN + 1:
		return {"ok": false, "reason": "climbed %d cells" % steps}
	if landing != stand + Vector2i.UP * steps:
		return {"ok": false, "reason": "landed at %s, not %d cells up" % [landing, steps]}
	if not edge and Gen2WorldFieldMove.waterfall_tile(world.collision_code_at(landing)):
		return {"ok": false, "reason": "landed back on the fall"}
	if world.player_cell != landing:
		return {"ok": false, "reason": "the cell did not commit"}
	if not world.player_step_in_progress():
		return {"ok": false, "reason": "the climb spent no frames"}
	if world.player_step_kind() != &"turn_waterfall":
		return {"ok": false, "reason": "drawn as %s" % world.player_step_kind()}
	if world.player_step_offset_cells() != Vector2(0, steps):
		return {"ok": false, "reason": "opened %s behind" % world.player_step_offset_cells()}
	var passes: int = int(applied["passes"])
	if passes != steps * Gen2WorldAPI.STEP_PASSES_FAST:
		return {"ok": false, "reason": "%d passes for %d steps" % [passes, steps]}
	for _pass: int in passes:
		if not world.player_step_in_progress():
			return {"ok": false, "reason": "the climb ended early"}
		world.advance_player_step_pass()
	if world.player_step_in_progress():
		return {"ok": false, "reason": "the climb outlasted its own passes"}
	if world.movement_mode != StringName(applied["movement_mode"]):
		return {"ok": false, "reason": "landed in %s, not %s" % [
			world.movement_mode, applied["movement_mode"],
		]}
	return {"ok": true}


func _climber(
	data: GameData, crystal: bool, group: int, number: int, cell: Vector2i
) -> Gen2WorldAPI:
	var state := Gen2WorldState.new()
	state.set_engine_flag(Gen2WorldState.badge_flag(Gen2WorldFieldMove.BADGE_RISING, crystal))
	var world: Gen2WorldAPI = Gen2WorldAPI.open(data, group, number, cell, state)
	if world == null:
		return null
	world.set_movement_mode(Gen2WorldAPI.MOVEMENT_SURF)
	world.player_facing = Gen2WorldSprite.FACING_UP
	_r.field_move_party(world)
	return world


func _column_feet(world: Gen2WorldAPI) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var size: Vector2i = world.map_size_cells()
	for y: int in size.y:
		for x: int in size.x:
			var cell := Vector2i(x, y)
			if not Gen2WorldFieldMove.waterfall_tile(world.collision_code_at(cell)):
				continue
			var below := Vector2i(x, y + 1)
			if below.y < size.y and Gen2WorldFieldMove.waterfall_tile(
				world.collision_code_at(below)
			):
				continue
			out.append(cell)
	return out


func _border_is_waterfall(world: Gen2WorldAPI, map: Gen2WorldMap) -> bool:
	for quadrant_y: int in Gen2Layout.MAP_BLOCK_CELL_WIDTH:
		for quadrant_x: int in Gen2Layout.MAP_BLOCK_CELL_WIDTH:
			if Gen2WorldFieldMove.waterfall_tile(world.current_tileset.collision_index(
				map.border_block, quadrant_x, quadrant_y
			)):
				return true
	return false


func _waterfall_cells(world: Gen2WorldAPI) -> int:
	var found: int = 0
	var size: Vector2i = world.map_size_cells()
	for y: int in size.y:
		for x: int in size.x:
			if Gen2WorldFieldMove.waterfall_tile(world.collision_code_at(Vector2i(x, y))):
				found += 1
	return found


## Whirl Islands B2F, the tallest fall either cartridge ships.
func _verify_whirl_islands(game_id: StringName, data: GameData, crystal: bool) -> void:
	var number: int = WHIRL_ISLANDS_B2F_CRYSTAL if crystal else WHIRL_ISLANDS_B2F_GOLD_SILVER
	var world: Gen2WorldAPI = _climber(
		data, crystal, WHIRL_ISLANDS_GROUP, number, WHIRL_FOOT + Vector2i.DOWN
	)
	if not _r.check(
		world != null,
		"%s: Whirl Islands B2F map %d/%d is missing." % [game_id, WHIRL_ISLANDS_GROUP, number]
	):
		return
	var column: int = 0
	for step: int in MAX_COLUMN + 1:
		if not Gen2WorldFieldMove.waterfall_tile(
			world.collision_code_at(WHIRL_FOOT + Vector2i.UP * step)
		):
			break
		column += 1
	_r.check(
		column == WHIRL_COLUMN,
		"%s: Whirl Islands' fall is %d cells, expected %d." % [game_id, column, WHIRL_COLUMN]
	)
	var staged: Dictionary = world.waterfall_request()
	if not _r.check(
		bool(staged.get("ok", false)),
		"%s: Whirl Islands refused Waterfall: %s." % [game_id, staged.get("reason", "unknown")]
	):
		return
	var applied: Dictionary = world.complete_waterfall()
	if not _r.check(
		bool(applied.get("ok", false)),
		"%s: Whirl Islands' climb failed: %s." % [game_id, applied.get("reason", "unknown")]
	):
		return
	_r.check(
		applied.get("cell", Vector2i.ZERO) == WHIRL_LANDING
			and int(applied.get("steps", 0)) == WHIRL_COLUMN + 1,
		"%s: Whirl Islands' climb answered %s, expected %s in %d steps." % [
			game_id, JSON.stringify(applied), WHIRL_LANDING, WHIRL_COLUMN + 1,
		]
	)
	_r.check(
		world.movement_mode == Gen2WorldAPI.MOVEMENT_SURF,
		"%s: Whirl Islands' climb left the water before it finished." % game_id
	)
	var paced: Dictionary = _verify_pacing(world, applied, WHIRL_FOOT + Vector2i.DOWN)
	_r.check(
		bool(paced.get("ok", false)),
		"%s: Whirl Islands' climb is not paced: %s." % [game_id, paced.get("reason", "")]
	)
	print("%s waterfall: Whirl Islands B2F %s to %s, %d steps over %d passes." % [
		game_id, WHIRL_FOOT + Vector2i.DOWN, WHIRL_LANDING,
		int(applied["steps"]), int(applied["passes"]),
	])
