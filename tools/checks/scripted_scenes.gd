extends RefCounted

## Conversations driven from the imported map events on every cartridge profile:
## two long movement scenes a hardware frame at a time, and every object whose
## script opens on `faceplayer`.
##
##   Godot --headless --path . -s res://tools/validate.gd -- scripted_scenes

const CHERRYGROVE_CITY := Vector2i(26, 3)
const ROUTE_29 := Vector2i(24, 3)
const GUIDE_START := Vector2i(33, 6)
const GUIDE_OBJECT: int = 0
const DUDE_OBJECT: int = 0
const ROUTE_TRIGGERS: Array[Vector2i] = [Vector2i(53, 8), Vector2i(53, 9)]

const GUIDE_WAYPOINTS: Array[Vector2i] = [
	Vector2i(29, 5), Vector2i(23, 5), Vector2i(16, 5),
	Vector2i(10, 7), Vector2i(25, 11), Vector2i(25, 9),
]
const GUIDE_FOLLOWER_WAYPOINTS: Array[Vector2i] = [
	Vector2i(30, 5), Vector2i(24, 5), Vector2i(17, 5),
	Vector2i(10, 6), Vector2i(24, 11), Vector2i(24, 11),
]
const GUIDE_MOVEMENT_FRAMES: Array[int] = [32, 48, 56, 64, 152, 16]
## Which way the player looks at each box: the follow's own answer, then
## `turnobject PLAYER` UP, UP, LEFT and RIGHT. Stream 6 has no box behind it.
const NO_TEXT_AFTER: int = -1
const GUIDE_PLAYER_FACINGS: Array[int] = [
	Gen2WorldSprite.FACING_UP, Gen2WorldSprite.FACING_UP,
	Gen2WorldSprite.FACING_UP, Gen2WorldSprite.FACING_LEFT,
	Gen2WorldSprite.FACING_RIGHT, NO_TEXT_AFTER,
]
const GUIDE_GIFT_FACING: int = Gen2WorldSprite.FACING_LEFT
const DUDE_MOVEMENT_FRAMES: Array[Array] = [[48, 48], [40, 40]]

## Both open on `Script_faceplayer`, named rather than numbered because
## pokegold's is $6A and Crystal's $6B.
const FACE_PLAYER_COMMANDS: Array[StringName] = [&"faceplayer", &"jumptextfaceplayer"]
const TALKABLE_OBJECT_TYPES: Array[int] = [
	Gen2WorldObject.OBJECTTYPE_SCRIPT, Gen2WorldObject.OBJECTTYPE_TRAINER,
]
const MOVEMENT_WAIT_FRAMES: int = 256
const NEIGHBOURS: Dictionary = {
	Gen2WorldSprite.FACING_UP: [Vector2i(0, 1), Gen2WorldSprite.FACING_DOWN],
	Gen2WorldSprite.FACING_DOWN: [Vector2i(0, -1), Gen2WorldSprite.FACING_UP],
	Gen2WorldSprite.FACING_LEFT: [Vector2i(1, 0), Gen2WorldSprite.FACING_RIGHT],
	Gen2WorldSprite.FACING_RIGHT: [Vector2i(-1, 0), Gen2WorldSprite.FACING_LEFT],
}

var _r: RefCounted = null


func run(r: RefCounted) -> void:
	_r = r
	for game_id: StringName in _r.GAME_IDS:
		var data: GameData = GameData.open(game_id)
		if data == null:
			_r.fail("%s cache is unavailable. Import roms/%s.gbc first." % [game_id, game_id])
			continue
		_check_guide(game_id, data)
		for trigger_index: int in ROUTE_TRIGGERS.size():
			_check_tutorial(game_id, data, trigger_index)
		_check_face_player(game_id, data)


func _check_guide(game_id: StringName, data: GameData) -> void:
	var world: Gen2WorldAPI = Gen2WorldAPI.open(
		data, CHERRYGROVE_CITY.x, CHERRYGROVE_CITY.y, GUIDE_START
	)
	if not _r.check(world != null, "%s: Cherrygrove City did not open." % game_id):
		return
	world.player_facing = Gen2WorldSprite.FACING_LEFT
	var run_result: Dictionary = _drain(world, world.interact(), GUIDE_OBJECT)
	if not _r.check(bool(run_result.get("ok", false)), "%s: Guide Gent: %s" % [
		game_id, String(run_result.get("reason", "did not finish")),
	]):
		return
	var movements: Array = run_result.get("movements", [])
	_r.check(movements.size() == GUIDE_WAYPOINTS.size(),
		"%s: Guide Gent ran %d movement streams, expected %d." % [
			game_id, movements.size(), GUIDE_WAYPOINTS.size(),
		])
	for index: int in mini(movements.size(), GUIDE_WAYPOINTS.size()):
		var row: Dictionary = movements[index]
		_r.check(int(row.get("frames", -1)) == GUIDE_MOVEMENT_FRAMES[index],
			"%s: Guide Gent movement %d spent %d frames, expected %d." % [
				game_id, index + 1, int(row.get("frames", -1)), GUIDE_MOVEMENT_FRAMES[index],
			])
		_r.check(row.get("leader", Vector2i(-1, -1)) == GUIDE_WAYPOINTS[index],
			"%s: Guide Gent movement %d ended at %s, expected %s." % [
				game_id, index + 1, row.get("leader"), GUIDE_WAYPOINTS[index],
			])
		_r.check(row.get("player", Vector2i(-1, -1)) == GUIDE_FOLLOWER_WAYPOINTS[index],
			"%s: Guide Gent movement %d left the player at %s, expected %s." % [
				game_id, index + 1, row.get("player"), GUIDE_FOLLOWER_WAYPOINTS[index],
			])
		_r.check(int(row.get("facing", -1)) == GUIDE_PLAYER_FACINGS[index],
			"%s: Guide Gent movement %d ended with the player facing %d, expected %d." % [
				game_id, index + 1, int(row.get("facing", -1)),
				GUIDE_PLAYER_FACINGS[index],
			])
	_r.check(not (world.objects[GUIDE_OBJECT] as Gen2WorldObject).active,
		"%s: Guide Gent did not disappear at his door." % game_id)
	if movements.size() == GUIDE_PLAYER_FACINGS.size():
		_r.check(int((movements[4] as Dictionary).get("leader_facing", -1)) == GUIDE_GIFT_FACING,
			"%s: Guide Gent faces %d for the gift, expected %d." % [
				game_id, int((movements[4] as Dictionary).get("leader_facing", -1)),
				GUIDE_GIFT_FACING,
			])
	print("%s: Guide Gent %d movement frames" % [
		game_id, int(run_result.get("movement_frames", 0)),
	])


func _check_tutorial(game_id: StringName, data: GameData, trigger_index: int) -> void:
	var trigger: Vector2i = ROUTE_TRIGGERS[trigger_index]
	var state := Gen2WorldState.new({}, {
		Gen2WorldState.map_scene_key(ROUTE_29.x, ROUTE_29.y): 1,
	})
	var world: Gen2WorldAPI = Gen2WorldAPI.open(
		data, ROUTE_29.x, ROUTE_29.y, trigger, state
	)
	if not _r.check(world != null, "%s: Route 29 did not open." % game_id):
		return
	var run_result: Dictionary = _drain(
		world, world.dispatch_script_events(trigger), DUDE_OBJECT
	)
	var label := "Route 29 row %d" % trigger.y
	if not _r.check(bool(run_result.get("ok", false)), "%s: %s: %s" % [
		game_id, label, String(run_result.get("reason", "did not finish")),
	]):
		return
	var movements: Array = run_result.get("movements", [])
	_r.check(movements.size() == 2, "%s: %s ran %d movement streams, expected 2." % [
		game_id, label, movements.size(),
	])
	for index: int in mini(movements.size(), 2):
		_r.check(int((movements[index] as Dictionary).get("frames", -1))
			== int(DUDE_MOVEMENT_FRAMES[trigger_index][index]),
			"%s: %s movement %d spent %d frames, expected %d." % [
				game_id, label, index + 1,
				int((movements[index] as Dictionary).get("frames", -1)),
				int(DUDE_MOVEMENT_FRAMES[trigger_index][index]),
			])
	if movements.size() == 2:
		_r.check((movements[0] as Dictionary).get("leader") == Vector2i(52, trigger.y),
			"%s: %s did not reach the player before the question." % [game_id, label])
		_r.check((movements[1] as Dictionary).get("leader") == Vector2i(50, 12),
			"%s: %s did not return the DUDE to his standing cell." % [game_id, label])
		_r.check((movements[1] as Dictionary).get("player") == Vector2i(50, 11),
			"%s: %s did not leave the player one cell behind the DUDE." % [game_id, label])
	_r.check(int(run_result.get("tutorials", 0)) == 1,
		"%s: %s requested %d catching tutorials, expected 1." % [
			game_id, label, int(run_result.get("tutorials", 0)),
		])
	print("%s: %s %d movement frames" % [
		game_id, label, int(run_result.get("movement_frames", 0)),
	])


func _drain(world: Gen2WorldAPI, initial: Array, tracked_object: int) -> Dictionary:
	if initial.is_empty():
		return {"ok": false, "reason": "no script event was dispatched"}
	var movements: Array = []
	var movement_frames: int = 0
	var tutorials: int = 0
	var results: Array = initial
	for _step: int in 512:
		var wait: Dictionary = world.pending_script_wait()
		if not wait.is_empty():
			var movement: bool = StringName(wait.get("wait", &"")) \
				== Gen2WorldScriptRunner.WAIT_MOVEMENT
			var wait_kind: StringName = StringName(wait.get("wait", &""))
			var frames: int = 0
			while not world.pending_script_wait().is_empty() and frames < 2048:
				results = world.advance_script_presentation_frame()
				frames += 1
				if StringName(world.pending_script_wait().get("wait", &"")) != wait_kind:
					break
			if frames >= 2048 \
				and StringName(world.pending_script_wait().get("wait", &"")) == wait_kind:
				return {"ok": false, "reason": "a script wait exceeded 2048 frames"}
			if movement:
				movement_frames += frames
				movements.append({
					"frames": frames,
					"leader": (world.objects[tracked_object] as Gen2WorldObject).cell,
					"player": world.player_cell,
				})
			continue

		var input: Dictionary = world.pending_script_input()
		var input_type: StringName = StringName(input.get("type", &""))
		if input_type in [&"text", &"button"]:
			## What the `turnobject` before this box left: a dropped turn moves
			## nobody, so no waypoint above can see one.
			if not movements.is_empty() and not (movements[-1] as Dictionary).has("facing"):
				(movements[-1] as Dictionary)["facing"] = world.player_facing
				(movements[-1] as Dictionary)["leader_facing"] = \
					(world.objects[tracked_object] as Gen2WorldObject).facing
			results = world.run_event_queue(true)
			continue
		if input_type in [&"choice", &"menu"]:
			results = world.choose_script_input(0)
			continue

		var request: Dictionary = world.pending_runtime_request()
		if not request.is_empty():
			var kind: StringName = StringName(request.get("kind", &""))
			if kind == &"catch_tutorial_requested":
				tutorials += 1
				results = world.complete_runtime_request({
					"ok": true, "outcome": Gen2WorldBattleAdapter.OUTCOME_CAUGHT,
				})
			elif kind == &"audio_requested":
				results = world.complete_runtime_request({"ok": true})
			else:
				return {"ok": false, "reason": "unsupported request %s" % kind}
			continue

		if not world.script_busy():
			return {
				"ok": true,
				"movements": movements,
				"movement_frames": movement_frames,
				"tutorials": tutorials,
			}
		if results.is_empty():
			results = world.run_event_queue(false)
	return {"ok": false, "reason": "script did not terminate in 512 transitions"}


## Every object whose script opens on `faceplayer`, from each side it is
## reachable from and in a world of its own, since a second press would resume
## the standing conversation. Nothing else asks whether the turn survives a
## paused or refused command; the party is there because `readvar VAR_BOXSPACE`,
## `trade` and `GetFirstPokemonHappiness` read one.
func _check_face_player(game_id: StringName, data: GameData) -> void:
	var talked: int = 0
	var missed: int = 0
	var wrong: Array[String] = []
	for map: Gen2WorldMap in data.world_maps():
		var listed: Gen2WorldAPI = Gen2WorldAPI.open(data, map.group, map.number, Vector2i.ZERO)
		if listed == null:
			continue
		for candidate: Gen2WorldObject in listed.objects:
			if not _opens_on_face_player(data, listed, candidate):
				continue
			for facing: int in NEIGHBOURS:
				var world: Gen2WorldAPI = Gen2WorldAPI.open(
					data, map.group, map.number, Vector2i.ZERO
				)
				var object: Gen2WorldObject = world.objects[candidate.index]
				if not _talk_from(world, object, facing):
					continue
				talked += 1
				var turned: int = (world.objects[object.index] as Gen2WorldObject).facing
				var wanted: int = int((NEIGHBOURS[facing] as Array)[1])
				if turned == wanted:
					continue
				missed += 1
				if wrong.size() < 8:
					wrong.append("map %d/%d object %d looking %d, not %d" % [
						map.group, map.number, object.index, turned, wanted,
					])
	for line: String in wrong:
		_r.check(false, "%s: faceplayer left %s" % [game_id, line])
	_r.check(missed == 0, "%s: faceplayer missed %d of %d talks." % [game_id, missed, talked])
	print("%s: faceplayer turned %d of %d talks" % [game_id, talked - missed, talked])


func _opens_on_face_player(
	data: GameData, world: Gen2WorldAPI, object: Gen2WorldObject
) -> bool:
	if not object.object_type in TALKABLE_OBJECT_TYPES or object.event_script <= 0:
		return false
	var bank: int = int(world.current_map.events.get("bank", 0))
	var raw: PackedByteArray = data.world_script(bank, object.event_script)
	if raw.is_empty():
		return false
	return Gen2WorldScript.command_name(
		int(raw[0]), Gen2WorldState.is_crystal_profile(data)
	) in FACE_PLAYER_COMMANDS


## Stands the player on one neighbouring cell looking at [param object] and
## presses A. False where a wall, an object or a counter rules that side out.
func _talk_from(world: Gen2WorldAPI, object: Gen2WorldObject, facing: int) -> bool:
	var cell: Vector2i = object.cell + ((NEIGHBOURS[facing] as Array)[0] as Vector2i)
	if cell.x < 0 or cell.y < 0 \
		or cell.x >= world.current_map.collision_width \
		or cell.y >= world.current_map.collision_height:
		return false
	if world.object_at(cell) != null or not world.can_walk_to(cell):
		return false
	world.player_cell = cell
	world.player_facing = facing
	if world.object_at(world.object_facing_cell()) != object:
		return false
	world.set_party_summary(1, false, [155] as Array[int], [[33]], ["CHIKORITA"], [false])
	world.interact()
	## The Copycat spins between her two `faceplayer`s.
	for _frame: int in MOVEMENT_WAIT_FRAMES:
		if StringName(world.pending_script_wait().get("wait", &"")) \
			!= Gen2WorldScriptRunner.WAIT_MOVEMENT:
			break
		world.advance_script_presentation_frame()
	return true
