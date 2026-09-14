extends RefCounted

var _r: RefCounted = null

## Verifies Strength and boulder pushing against freshly imported real caches, for
## both command profiles. Expected values come from the pinned sources:
## StrengthFunction, TryStrengthOW, AskStrengthScript, `.CheckStrengthBoulder`,
## `MovementFunction_Strength` and `CanObjectMoveInDirection`, all byte identical
## between the pins, so nothing here is profile split except the two engine flag
## numbers. The real-cartridge counterpart to the Strength cases in the two world
## unit tests; Cianwood Gym is the acceptance case, its three-boulder wall being
## what a playthrough meets first.


## constants/map_constants.asm, CIANWOOD group. Unlike Dragon's Den, the group
## and number agree between the pins.
const GYM_GROUP: int = 22
const GYM_NUMBER: int = 5
## maps/CianwoodGym.asm's object events: one boulder north at (5,1) and the
## three-boulder wall across the corridor at row 7.
const GYM_WALL_CELLS: Array[Vector2i] = [
	Vector2i(3, 7), Vector2i(4, 7), Vector2i(5, 7),
]
const GYM_LONE_BOULDER: Vector2i = Vector2i(5, 1)
## The wall's middle boulder, approached from below and pushed north.
const GYM_PUSH_CELL: Vector2i = Vector2i(4, 7)
const GYM_PUSH_STAND: Vector2i = Vector2i(4, 8)
const GYM_PUSH_LANDING: Vector2i = Vector2i(4, 6)
## maps/CianwoodGym.asm's first warp event, out to Cianwood City.
const GYM_EXIT_CELL: Vector2i = Vector2i(4, 17)

## Census of the real caches, pinned so a cache change is loud. Both pins ship
## the same 20 boulders over the same 9 maps: Blackthorn Gym 2F 6, Cianwood Gym
## and Ice Path B1F 4 each, and one each in Burned Tower B1F, Mount Mortar B1F,
## Mount Mortar 1F Inside, Union Cave B1F, Slowpoke Well B1F and Whirl Island
## B1F.
const EXPECTED_CENSUS: Dictionary = {
	# game id: [boulder objects, maps carrying one]
	&"gold": [20, 9],
	&"silver": [20, 9],
	&"crystal": [20, 9],
}


## `BOULDER_MOVEMENT_BYTE_2` over the whole Generation 1 corpus, and Victory
## Road 1F's own first boulder as the acceptance case: `maps/VictoryRoad1F.asm`
## stands it at (5, 15) and its switch is the cell the route needs it on.
const GEN1_CENSUS: Dictionary = {
	&"red": [21, 8], &"blue": [21, 8], &"yellow": [21, 8],
}
const GEN1_PUSH_MAP: int = 0x6C
const GEN1_PUSH_CELL := Vector2i(5, 15)


func run(r: RefCounted) -> void:
	_r = r
	_r.each_game_of(RomRegistry.GEN1, _gen1_checks)
	for game_id: StringName in _r.GAME_IDS:
		var data: GameData = GameData.open(game_id)
		if data == null:
			_r.fail("%s cache is unavailable. Import roms/%s.gbc first." % [game_id, game_id])
			continue
		_census(game_id, data)
		_verify_cianwood_gym(game_id, data, Gen2WorldState.is_crystal_profile(data))


## Counts every SPRITEMOVEDATA_STRENGTH_BOULDER object event, so a cache change
## that drops or moves one is loud rather than quietly sealing a route.
func _census(game_id: StringName, data: GameData) -> void:
	var boulders: int = 0
	var maps: Dictionary = {}
	for map: Gen2WorldMap in data.world_maps():
		for row: Dictionary in map.events.get("objects", []):
			if int(row.get("movement", 0)) != Gen2WorldObject.MOVEMENT_STRENGTH_BOULDER:
				continue
			boulders += 1
			maps[Vector2i(map.group, map.number)] = true

	var counts: Array = [boulders, maps.size()]
	print("%s: %d strength boulders across %d maps." % [game_id, counts[0], counts[1]])
	_r.check(
		counts == EXPECTED_CENSUS.get(game_id, []),
		"%s: boulder census is %s, not the pinned %s." % [
			game_id, counts, EXPECTED_CENSUS.get(game_id, []),
		]
	)


func _verify_cianwood_gym(game_id: StringName, data: GameData, crystal: bool) -> void:
	var badge: int = Gen2WorldState.badge_flag(Gen2WorldFieldMove.BADGE_PLAIN, crystal)
	var world: Gen2WorldAPI = _gym_world(data, crystal, true)
	if not _r.check(
		world != null, "%s: Cianwood Gym %d/%d is missing." % [game_id, GYM_GROUP, GYM_NUMBER]
	):
		return

	for cell: Vector2i in GYM_WALL_CELLS + [GYM_LONE_BOULDER]:
		var boulder: Gen2WorldObject = world.object_at(cell)
		_r.check(
			boulder != null and boulder.is_strength_boulder(),
			"%s: Cianwood Gym %s carries no strength boulder." % [game_id, cell]
		)

	# .CheckLandPerms passes on the boulder's own cell, so what refuses the step
	# is .CheckNPC alone: the wall is objects, not collision.
	_r.check(
		world.collision_permission_at(GYM_PUSH_CELL) == Gen2WorldCollision.LAND_TILE,
		"%s: Cianwood Gym %s is not walkable ground under its boulder." % [
			game_id, GYM_PUSH_CELL,
		]
	)

	# .CheckNPC's own comment: a movable boulder bumps the player like any other.
	var pushed: Dictionary = world.move_result(Vector2i.UP)
	_r.check(
		not bool(pushed.get("ok", false))
			and StringName(pushed.get("reason", &"")) == &"blocked"
			and world.player_cell == GYM_PUSH_STAND,
		"%s: Cianwood Gym push moved the player instead of bumping them." % game_id
	)
	_r.check(
		pushed.has("boulder_pushed")
			and pushed["boulder_pushed"]["to_cell"] == GYM_PUSH_LANDING,
		"%s: Cianwood Gym boulder at %s did not move to %s." % [
			game_id, GYM_PUSH_CELL, GYM_PUSH_LANDING,
		]
	)
	_r.check(
		world.object_at(GYM_PUSH_CELL) == null
			and world.object_at(GYM_PUSH_LANDING) != null,
		"%s: Cianwood Gym boulder did not free %s." % [game_id, GYM_PUSH_CELL]
	)
	print("%s: Cianwood Gym %d/%d boulder %s -> %s, corridor cell freed." % [
		game_id, GYM_GROUP, GYM_NUMBER, GYM_PUSH_CELL, GYM_PUSH_LANDING,
	])

	# reload_current_map() keeps a moved object where it stands, which is the
	# after-battle rule a trainer relies on, so a boulder pushed before a battle
	# is still out of the way afterwards.
	world.reload_current_map()
	_r.check(
		world.object_at(GYM_PUSH_LANDING) != null and world.object_at(GYM_PUSH_CELL) == null,
		"%s: Cianwood Gym boulder lost its pushed cell on a map reload." % game_id
	)

	# A map change is the other half: ReadObjectEvents rebuilds every object from
	# map data, so the boulder is back on its authored cell on the next visit,
	# the way a cut tree regrows.
	world.player_cell = GYM_EXIT_CELL
	if _r.check(
		bool(world.try_warp().get("ok", false)),
		"%s: Cianwood Gym exit warp at %s did not fire." % [game_id, GYM_EXIT_CELL]
	):
		var returned: Gen2WorldAPI = Gen2WorldAPI.open(
			data, GYM_GROUP, GYM_NUMBER, GYM_PUSH_STAND, world.state
		)
		_r.check(
			returned.object_at(GYM_PUSH_CELL) != null,
			"%s: Cianwood Gym boulder did not return to %s on the next visit." % [
				game_id, GYM_PUSH_CELL,
			]
		)

	# .CheckStrengthBoulder reads BIKEFLAGS_STRENGTH_ACTIVE_F first, so without it
	# the wall is immovable however many badges the player has.
	var inactive: Gen2WorldAPI = _gym_world(data, crystal, false)
	var refused: Dictionary = inactive.move_result(Vector2i.UP)
	_r.check(
		not refused.has("boulder_pushed")
			and inactive.object_at(GYM_PUSH_CELL) != null,
		"%s: Cianwood Gym boulder moved without the strength flag." % game_id
	)

	# .TryStrength tests the badge on whichever engine flag table this profile
	# numbers ENGINE_PLAINBADGE on, and nothing else.
	var unbadged: Gen2WorldAPI = Gen2WorldAPI.open(
		data, GYM_GROUP, GYM_NUMBER, GYM_PUSH_STAND, Gen2WorldState.new()
	)
	_r.check(
		StringName(unbadged.strength_request().get("reason", &"")) == &"badge_required",
		"%s: Cianwood Gym allowed Strength without engine flag %d." % [game_id, badge]
	)
	var wrong := Gen2WorldState.new()
	wrong.set_engine_flag(Gen2WorldState.badge_flag(Gen2WorldFieldMove.BADGE_PLAIN, not crystal))
	var wrong_world: Gen2WorldAPI = Gen2WorldAPI.open(
		data, GYM_GROUP, GYM_NUMBER, GYM_PUSH_STAND, wrong
	)
	_r.check(
		StringName(wrong_world.strength_request().get("reason", &"")) == &"badge_required",
		"%s: Cianwood Gym accepted the other profile's Plain Badge flag." % game_id
	)

	# The badge alone resolves: .TryStrength never looks at a tile or a boulder.
	var badged: Gen2WorldAPI = _gym_world(data, crystal, false)
	badged.state.set_engine_flag(badge)
	_r.check(
		bool(badged.strength_request().get("ok", false))
			and bool(badged.complete_strength().get("ok", false))
			and badged.strength_active(),
		"%s: Cianwood Gym refused Strength with the Plain Badge set." % game_id
	)


## A world below the wall's middle boulder, facing it, with the Plain Badge set
## and the strength flag set when [param active].
func _gym_world(data: GameData, crystal: bool, active: bool) -> Gen2WorldAPI:
	var state := Gen2WorldState.new()
	state.set_engine_flag(Gen2WorldState.badge_flag(Gen2WorldFieldMove.BADGE_PLAIN, crystal))
	if active:
		state.set_engine_flag(Gen2WorldState.strength_active_flag(crystal))
	var world: Gen2WorldAPI = Gen2WorldAPI.open(
		data, GYM_GROUP, GYM_NUMBER, GYM_PUSH_STAND, state
	)
	if world != null:
		world.player_facing = Gen2WorldSprite.FACING_UP
	return world



func _gen1_checks() -> void:
	var boulders: int = 0
	var maps: Dictionary = {}
	for map: Gen2WorldMap in _r.data.world_maps():
		for row: Dictionary in map.events.get("objects", []):
			if int(row.get("movement", 0)) != Gen2WorldObject.MOVEMENT_STRENGTH_BOULDER:
				continue
			boulders += 1
			maps[map.number] = true
	var counts: Array = [boulders, maps.size()]
	_r.note("%d boulders across %d maps." % counts)
	_r.check(counts == GEN1_CENSUS.get(_r.game_id, []),
		"the Generation 1 boulder census is %s, not the pinned %s." % [
			counts, GEN1_CENSUS.get(_r.game_id, []),
		])
	_gen1_push()


## `PrintStrengthText` refuses only the badge, and `TryPushingBoulder` arms on the
## first bump and moves on the second.
func _gen1_push() -> void:
	var world: Gen2WorldAPI = _r.open_world(
		0, GEN1_PUSH_MAP, GEN1_PUSH_CELL + Vector2i.DOWN
	)
	if world == null:
		return
	_r.field_move_party(world)
	_r.check(
		StringName(world.strength_request().get("reason", &"")) == &"badge_required",
		"Strength was allowed with no RAINBOWBADGE."
	)
	world.state.set_engine_flag(Gen2WorldState.gen1_badge_flag(Gen1Layout.RAINBOWBADGE), true)
	if not _r.check(bool(world.strength_request().get("ok", false)), "Strength was refused."):
		return
	world.complete_strength()
	_r.check(world.strength_active(), "the Strength flag did not go on.")
	var boulder: Gen2WorldObject = world.object_at(GEN1_PUSH_CELL)
	if not _r.check(boulder != null, "no boulder stands at %s." % GEN1_PUSH_CELL):
		return
	world.player_facing = Gen2WorldSprite.FACING_UP
	world.move_result(Vector2i.UP)
	_r.check(boulder.cell == GEN1_PUSH_CELL, "the first bump moved the boulder.")
	world.move_result(Vector2i.UP)
	_r.check(
		boulder.cell == GEN1_PUSH_CELL + Vector2i.UP,
		"the second bump left the boulder at %s." % boulder.cell
	)
	## `DoBoulderDustAnimation` holds back while `BIT_SCRIPTED_NPC_MOVEMENT`
	## stands, then `AnimateBoulderDust`'s eight `Delay3`s and `SFX_CUT`.
	_r.check(world.dispatch_sight_events().is_empty(), "the dust ran during the slide.")
	var passes: int = 0
	var random := RandomNumberGenerator.new()
	while boulder.is_stepping() and passes < 40:
		world.advance_object_steps_pass(random)
		passes += 1
	var dust: Array = world.dispatch_sight_events()
	var wait: Dictionary = world.pending_script_wait()
	_r.check(
		StringName(wait.get("kind", &"")) == &"gen1_boulder_dust" and int(wait.get("frames", 0)) == 24,
		"the slide's end owed %s, not the dust's 24 frames." % [wait]
	)
	var cut: Array = []
	for result: Dictionary in dust:
		for event: Dictionary in result.get("events", []):
			if StringName(event.get("kind", &"")) == &"gen1_boulder_dust":
				_r.check(int(event.get("facing", -1)) == Gen2WorldSprite.FACING_UP, "the dust faces %s." % [event])
				cut = event.get("sounds", [])
	_r.check(
		cut.size() == 1 and int(cut[0].get("index", 0)) == Gen1Layout.SFX_CUT
			and int(cut[0].get("frame", 0)) == 24,
		"the dust ends on %s." % [cut]
	)
	var effects := Gen2WorldEffects.new()
	effects.start_gen1_boulder_dust(
		Gen1Layout.PLAYER_SPRITE_PIXELS, Gen2WorldSprite.FACING_UP, _r.data.gen1_boulder_dust_offsets()
	)
	var first: Dictionary = effects.sprites()[0]
	_r.check(
		first["tiles"][0]["offset"] == Vector2i(64, 33) and int(first["rotation"]) == 0x80,
		"the dust opens at %s wearing $%02X." % [first["tiles"][0]["offset"], int(first["rotation"])]
	)
	for _frame: int in 23:
		effects.advance_frame()
	var last: Dictionary = effects.sprites()[0]
	_r.check(
		last["tiles"][0]["offset"] == Vector2i(64, 40) and int(last["rotation"]) == 0xE4,
		"the dust ends at %s wearing $%02X." % [last["tiles"][0]["offset"], int(last["rotation"])]
	)
	effects.advance_frame()
	_r.check(effects.sprites().is_empty(), "the dust outlived its twenty-four frames.")
