extends RefCounted

var _r: RefCounted = null

## The imported `cmdqueue` payloads of BlackthornGym2F and IcePathB1F against
## `CmdQueue_StoneTable` and `HandleStoneQueue`, both profiles. The importer skips
## a queue pointer it cannot resolve, since a slice run past its end can decode as
## a `writecmdqueue`; asserting both real tables whole is what makes that safe.


## Blackthorn Gym 2F and Ice Path B1F, the only two maps in either game with a
## MAPCALLBACK_CMDQUEUE (`data/maps/maps.asm` group/number pairs). The gym sits
## at the same pair in both games; Crystal's own extra maps push Ice Path B1F
## eight places down its group.
const BLACKTHORN_GYM_2F: Array = [5, 2]
const ICE_PATH_B1F: Dictionary = {
	&"gold": [3, 54],
	&"silver": [3, 54],
	&"crystal": [3, 62],
}

## The `stonetable` rows verbatim, warp id then object id. Object ids are
## `object_const_def` constants, which start at 2: Blackthorn Gym 2F lists two
## trainers before its boulders, so its first boulder is 4, while Ice Path B1F
## lists boulders first, so its first is 2.
const EXPECTED_ROWS: Dictionary = {
	"blackthorn": [[5, 4], [3, 5], [4, 6]],
	"ice_path": [[3, 2], [4, 3], [5, 4], [6, 5]],
}

## The pit warps each row names, as the cell the boulder has to reach. Read off
## the two maps' own `def_warp_events`, one-based like the source counts them.
const EXPECTED_WARP_CELLS: Dictionary = {
	"blackthorn": {3: Vector2i(2, 5), 4: Vector2i(8, 7), 5: Vector2i(8, 3)},
	"ice_path": {
		3: Vector2i(11, 2), 4: Vector2i(4, 7), 5: Vector2i(5, 12), 6: Vector2i(12, 13),
	},
}

## Slide, `pause 30`, the earthquake and the box: generous for all of them.
const FALL_FRAMES: int = 1200


func run(r: RefCounted) -> void:
	_r = r
	_r.each_game(func() -> void:
		_verify_map(_r.data, _r.game_id, "blackthorn", BLACKTHORN_GYM_2F)
		_verify_map(_r.data, _r.game_id, "ice_path", ICE_PATH_B1F[_r.game_id])
		_drive_blackthorn(_r.game_id)
	)


func _verify_map(data: GameData, game_id: StringName, name: String, id: Array) -> void:
	var world: Gen2WorldAPI = Gen2WorldAPI.open(data, id[0], id[1], Vector2i.ZERO)
	if world == null:
		_r.fail("map %d/%d is missing." % [id[0], id[1]])
		return

	# The queue is written by a MAPCALLBACK_CMDQUEUE, so running the map's own
	# callbacks is what puts it on the world. Nothing else writes one.
	var _entry: Array = world.dispatch_map_entry()
	for _step: int in 8:
		if not world.pending_script_wait().is_empty():
			world.finish_script_waits()
			continue
		if world.pending_script_input().is_empty():
			break
		world.run_event_queue(true)

	var queues: Array = world.command_queues()
	var tables: Array = []
	for queue: Dictionary in queues:
		if int(queue.get("type", 0)) == Gen2WorldScript.CMDQUEUE_STONETABLE:
			tables.append(queue)
	if not _r.check(
		tables.size() == 1,
		"%s: %d stone tables written, not 1." % [name, tables.size()]
	):
		return

	var rows: Array = (tables[0] as Dictionary).get("rows", [])
	var expected: Array = EXPECTED_ROWS[name]
	if not _r.check(
		rows.size() == expected.size(),
		"%s: %d stonetable rows, not the pinned %d." % [
			name, rows.size(), expected.size(),
		]
	):
		return
	for index: int in expected.size():
		var row: Dictionary = rows[index]
		var want: Array = expected[index]
		_r.check(
			int(row["warp"]) == int(want[0]) and int(row["object"]) == int(want[1]),
			"%s row %d is warp %d object %d, not the pinned warp %d object %d." % [
				name, index,
				int(row["warp"]), int(row["object"]), int(want[0]), int(want[1]),
			]
		)
		_r.check(
			int(row["script"]) >= RomFile.BANK_SIZE,
			"%s row %d has script $%04X, which is not a banked address." % [
				name, index, int(row["script"]),
			]
		)

	# Every named warp has to be a real warp event on a pit tile, or the boulder
	# could never satisfy HandleStoneQueue.
	var cells: Dictionary = EXPECTED_WARP_CELLS[name]
	for warp: int in cells:
		var cell: Vector2i = cells[warp]
		_r.check(
			world.warp_index_at(cell) == warp,
			"%s: warp %d is not at %s." % [name, warp, cell]
		)
		_r.check(
			Gen2WorldCollision.is_pit_tile(world.collision_code_at(cell)),
			"%s: warp %d at %s is collision $%02X, not a pit." % [
				name, warp, cell, world.collision_code_at(cell),
			]
		)

	# And every row has to name a boulder object the map actually carries.
	for row: Dictionary in rows:
		var index: int = int(row["object"]) - 2
		if not _r.check(
			index >= 0 and index < world.objects.size(),
			"%s: object id %d is outside the map's object list." % [
				name, int(row["object"]),
			]
		):
			continue
		var object: Gen2WorldObject = world.objects[index]
		_r.check(
			object.is_strength_boulder(),
			"%s: object id %d is not a Strength boulder." % [name, int(row["object"])]
		)
	print("%s %s: %d stonetable rows over %d pit warps verified." % [
		game_id, name, rows.size(), cells.size(),
	])


## Blackthorn Gym 2F's first row pressed on the real screen: BOULDER1 at (8,2)
## pushed south onto warp 5's pit falls once its slide ends, takes its flag and
## hands the map back.
func _drive_blackthorn(game_id: StringName) -> void:
	var screen: Gen2WorldScreen = _r.open_screen(
		BLACKTHORN_GYM_2F[0], BLACKTHORN_GYM_2F[1], Vector2i(8, 1)
	)
	var world: Gen2WorldAPI = screen.world()
	world.state.set_engine_flag(Gen2WorldState.strength_active_flag(_r.crystal))
	world.player_facing = Gen2WorldSprite.FACING_DOWN
	var boulder: Gen2WorldObject = world.object_at(Vector2i(8, 2))
	if _r.check(
		boulder != null and boulder.is_strength_boulder(),
		"no boulder at (8,2) on Blackthorn Gym 2F."
	):
		_push_into_pit(screen, boulder, game_id)
	_r.close_screen(screen)


func _push_into_pit(screen: Gen2WorldScreen, boulder: Gen2WorldObject, game_id: StringName) -> void:
	var world: Gen2WorldAPI = screen.world()
	screen.press_button(PokeButton.DOWN)
	screen.advance_frames(Gen2WorldAPI.FRAMES_PER_OVERWORLD_PASS)
	if not _r.check(
		boulder.cell == Vector2i(8, 3),
		"the boulder at (8,2) was not pushed onto the pit."
	):
		return
	for frame: int in FALL_FRAMES:
		screen.advance_frame()
		if world.script_input_waiting() and frame % 8 == 0:
			screen.press_button(PokeButton.A)
		if not boulder.active and not world.script_busy():
			break
	_r.check(
		not world.script_busy(),
		"the fall script still holds the map %d frames after the push." % FALL_FRAMES
	)
	_r.check(
		world.state.is_event_flag_active(boulder.event_flag) and not boulder.active,
		"the fall script did not take boulder flag %d." % boulder.event_flag
	)
	print("%s blackthorn: the pushed boulder fell through and the map moved on." % game_id)
