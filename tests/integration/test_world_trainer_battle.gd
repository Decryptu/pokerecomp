extends GutTest

## Scene-level integration for the overworld trainer vertical slice. The cache
## is synthetic, but the scene, world API, script runner, battle adapter and
## battle overlay are the production paths.

const Fixture := preload("res://tests/integration/world_trainer_fixture.gd")
const BattleFixture := preload("res://tests/unit/battle_fixture.gd")

const STORY_CALLBACK: int = 0x6200
const STORY_OBJECT: int = 0x6210
const STORY_TEXT: int = 0x7200
const STORY_EVENT_FLAG: int = 8

## `CatchTutorial` from the first frame of the fight to the last, measured on a
## Crystal cartridge through Route 29's own tutorial: 1,529 hardware frames, of
## which the battle menu is 53. Reading `DudeAutoInputs`' durations as frames
## rather than as `GetJoypad` polls made that menu 2,042 on its own, which is
## half a minute of a fight nobody can play sitting on FIGHT. The ceiling is the
## cartridge's own count; the guard is what says the stream stalled outright.
const DUDE_TUTORIAL_FRAMES: int = 1529
const DUDE_FRAME_GUARD: int = 8000

var _data: GameData = null
var _world_screen: Gen2WorldScreen = null


func before_each() -> void:
	_data = Fixture.build()
	_add_capture_metadata()
	_data = GameData.open_directory(Fixture.directory())
	## The box reveals at the OPTION menu's TEXT SPEED and a press cannot
	## shorten it, so a page count depends on the setting: run on the test
	## path's defaults rather than on whatever an earlier script, or this
	## machine's own installed options, left behind.
	Gen2OptionsStore.use_test_path()
	DirAccess.remove_absolute(Gen2OptionsStore.path())
	Gen2ModHost.reset()


## `<PLAYER>` in `GotMoneyForWinningText`. A battle opened with no save behind it
## has no name to read, so `NewGame`'s own default stands in; the saved fixture
## carries the name [method _open_world] gives it.
const UNSAVED_PLAYER: String = Gen2OakSpeech.DEFAULT_MALE
const SAVED_PLAYER: String = "TEST"


func after_each() -> void:
	## Opening a world installs the rules it was opened under, which is the whole
	## point of them (`Gen2WorldAPI._init`), so a test that opened a Nuzlocke
	## leaves every test after it playing one: its catches ask for no nickname
	## and its faints are permanent. Put back before the next one builds a save.
	Gen2Rules.install(null)
	if is_instance_valid(_world_screen):
		_world_screen.free()
		_world_screen = null
	RomCache.clear(Fixture.directory())
	RomCache.clear(Fixture.directory(&"gold"))
	_clear_mod_root()
	Gen2ModHost.reset()


## [param challenge] is written onto the injected save rather than installed by
## hand: which rules a run is played under belongs to the slot, and the world is
## what reads them off it.
func _open_world(
	with_save: bool = false, seed_value: int = 0, challenge: StringName = &""
) -> void:
	var packed: PackedScene = load("res://game/world/world_screen.tscn")
	_world_screen = packed.instantiate() as Gen2WorldScreen
	_world_screen.map_group = Fixture.MAP_GROUP
	_world_screen.map_number = Fixture.MAP_NUMBER
	_world_screen.start_cell = Vector2i(4, 5)
	_world_screen.encounter_seed = seed_value
	_world_screen.set_data(_data)
	if with_save:
		var player: Gen2BattleMon = Gen2BattleMon.create(
			_data, Fixture.TRAINER_SPECIES, 5, [BattleFixture.TACKLE]
		)
		var save: Gen2SaveData = Gen2SaveBattleAdapter.from_battle_party(
			_data.id, _data.sha1, 0, Gen2Party.of(player), "TEST"
		)
		var snapshot := Gen2WorldSnapshot.new()
		snapshot.map_id = Vector2i(Fixture.MAP_GROUP, Fixture.MAP_NUMBER)
		snapshot.player_cell = Vector2i(4, 5)
		snapshot.world_state = Gen2WorldState.new()
		save.world = snapshot
		if not challenge.is_empty():
			save.run_rules = Gen2Rules.new()
			save.run_rules.challenge = challenge
		_world_screen.set_save(save)
	add_child(_world_screen)
	await get_tree().process_frame


## One cell, however many presses the cartridge needs for it. The player spawns
## facing down, so a press in any other direction is `.CheckTurning`'s turn on the
## spot first and the walk is the press after it; a press in the direction already
## faced walks straight away.
func _walk_one(direction: Vector2i) -> void:
	var before: Vector2i = _world_screen._world.player_cell
	assert_true(_world_screen.move_player(direction))
	for _frame: int in 16:
		if not _world_screen._world.player_step_in_progress():
			break
		_world_screen.advance_frame()
	await get_tree().process_frame
	if _world_screen._world.player_cell == before:
		assert_true(_world_screen.move_player(direction))


## Spends the world's own frames rather than the host's, so the shock emote and
## the approach cost what `SeenByTrainerScript` says they cost however fast this
## machine runs the suite.
func _trigger_trainer() -> void:
	await _walk_one(Vector2i.RIGHT)
	for _frame: int in 400:
		_world_screen.advance_frame()
		if _battle_child() != null:
			break
		var waiting: Dictionary = _world_screen._world.pending_script_input()
		if StringName(waiting.get("type", &"")) in [&"text", &"button"]:
			_world_screen._advance_script_input()
	await get_tree().process_frame
	## Only that the overlay opened: the entrance is left where each test wants
	## it, since driving it here would spend the line one of them reads.
	assert_not_null(_battle_child())


## The battle overlay, once `DoBattleTransition` has been spent.
##
## The encounter is resolved on the frame it fires, and the transition owns
## every frame between that and the battle screen being built, so a test that
## looked for the child on the same frame would find nothing.
func _battle_child() -> Gen2BattleScreen:
	var guard: int = 600
	while guard > 0:
		for child: Node in _world_screen.get_children():
			if child is Gen2BattleScreen:
				return child as Gen2BattleScreen
		if _world_screen.battle_transition_running():
			_world_screen.advance_frame()
			guard -= 1
			continue
		return null
	return null


## The battle overlay, with its opening slide walked to the end.
##
## `BattleIntroSlidingPics` runs before `BattleStartMessage`, so a battle says
## nothing until the pics are in place. In play the screen's own frames spend
## that; a test that read the box without it would read an empty one.
##
## The entrance behind the slide is half frames and half boxes, so both are
## driven: `DoBattle` reaches its first menu only once the ball has been thrown.
func _battle_host() -> Gen2BattleScreen:
	var host: Gen2BattleScreen = _battle_opening()
	if host == null:
		return null
	var guard: int = 4000
	while (host.frames_running() or host.entrance_running()) and guard > 0:
		guard -= 1
		host.advance_frame()
		if host.frames_running() or not host.entrance_running():
			continue
		## The box owes a press rather than frames: the reveal is skipped and the
		## press given, which is what a player does to a `prompt` line. The test
		## is left on the first battle menu, never a press past it.
		host.finish()
		host.advance()
	return host


## The same overlay with the slide spent and nothing else, which is where the
## line `BattleStartMessage` prints is still on screen.
## The frames a screen owes, spent the way the screen's own `_process` spends
## them. A capture owes some now: `PokeBallEffect` draws the throw between the
## text that says it was thrown and the text that says what happened.
func _settle_frames(host: Gen2BattleScreen) -> void:
	var guard: int = 4000
	while host.frames_running() and guard > 0:
		host.advance_frame()
		guard -= 1


func _battle_opening() -> Gen2BattleScreen:
	var host: Gen2BattleScreen = _battle_child()
	if host == null:
		return null
	var guard: int = 4000
	while host.frames_running() and guard > 0:
		host.advance_frame()
		guard -= 1
	return host


## The wild this fixture ships, named out of the cache rather than spelled out.
## Which species number `TRAINER_SPECIES` lands on, and so whether that row
## carries a name of its own or the filler one, is the world fixture's business
## and not something these four messages should pin.
func _wild_name() -> String:
	return String(_data.species(Fixture.TRAINER_SPECIES).get("name", ""))


func test_trainer_sight_reaches_the_real_battle_overlay() -> void:
	await _open_world()
	var before: Dictionary = _world_screen.world_snapshot()
	await _trigger_trainer()

	var host: Gen2BattleScreen = _battle_opening()
	assert_not_null(host)
	assert_eq(before["map"], Vector2i(Fixture.MAP_GROUP, Fixture.MAP_NUMBER))
	assert_eq(before["player_cell"], Vector2i(4, 5))
	assert_eq(_world_screen.world_snapshot()["player_cell"], Vector2i(5, 5))
	assert_eq((_world_screen._world.objects[0] as Gen2WorldObject).cell, Vector2i(5, 4))
	assert_eq(
		(_world_screen._world.objects[0] as Gen2WorldObject).facing,
		Gen2WorldSprite.FACING_DOWN
	)
	assert_eq(_world_screen._world.player_facing, Gen2WorldSprite.FACING_UP)
	assert_true(host.is_ready())
	var snapshot: Dictionary = host.battle_snapshot()
	assert_eq(snapshot["enemy"], Fixture.TRAINER_SPECIES)
	assert_eq(snapshot["message"], "LEADER RIVAL\nwants to battle!")
	assert_eq(snapshot["world_battle_active"], true)


## `BattleStartMessage` and `DoBattle`'s opening, in the order they run: the
## shine, the line the trainer wants to fight on, the enemy's own send-out and
## the player's, each ball being `ANIM_SEND_OUT_MON`.
func test_a_trainer_battle_opens_with_the_source_entrance() -> void:
	await _open_world()
	await _trigger_trainer()
	var host: Gen2BattleScreen = _battle_opening()
	assert_not_null(host)
	assert_true(host.entrance_running())
	assert_eq(host.battle_snapshot()["message"], "LEADER RIVAL\nwants to battle!")

	var lines: Array = []
	## Whose ball is being thrown, in order. The fixture carries no animation
	## tables, so the script itself never runs and the event is what says the
	## cartridge would have played one.
	var balls: Array = []
	var guard: int = 4000
	while (host.frames_running() or host.entrance_running()) and guard > 0:
		guard -= 1
		host.advance_frame()
		var snapshot: Dictionary = host.battle_snapshot()
		if not lines.has(snapshot["message"]) and snapshot["message"] != "":
			lines.append(snapshot["message"])
		var animation: Dictionary = host.animation_snapshot()
		if bool(animation["running"]) \
			and int(animation["index"]) == Gen2Battle.ANIM_SEND_OUT_MON:
			var side: int = Gen2Battle.ENEMY if bool(animation["enemy_turn"]) \
				else Gen2Battle.PLAYER
			if balls.is_empty() or balls[-1] != side:
				balls.append(side)
		if host.frames_running() or not host.entrance_running():
			continue
		host.finish()
		host.advance()

	assert_eq(lines, [
		"LEADER RIVAL\nwants to battle!",
		"LEADER RIVAL\nsent out\n%s!" % _wild_name(),
		"Go! %s!" % _wild_name(),
	])
	assert_eq(balls, [Gen2Battle.ENEMY, Gen2Battle.PLAYER],
		"the trainer throws first, and the player after `DoBattle`'s forty frames")
	## `EmptyBattleTextbox` before the menu `DoBattle` reaches.
	assert_eq(host.battle_snapshot()["message"], "")


## While the trainer object is mid-step, its presentation offset eases toward
## zero instead of snapping.
func test_trainer_approach_step_interpolates_the_objects_position() -> void:
	await _open_world()
	await _walk_one(Vector2i.RIGHT)

	var object := _world_screen._world.objects[0] as Gen2WorldObject
	var saw_step: bool = false
	var was_stepping: bool = false
	var previous_magnitude: int = -1
	var lowest_magnitude: int = Gen2WorldAPI.CELL_PIXELS
	for _frame: int in 400:
		_world_screen.advance_frame()
		if _battle_child() != null:
			break
		if object.is_stepping():
			var offset: Vector2i = object.step_offset(Gen2WorldAPI.CELL_PIXELS)
			var magnitude: int = abs(offset.x) + abs(offset.y)
			if not saw_step:
				# The source's single-step Route 30 fixture path starts at a
				# full cell of offset; a longer path would restart here too.
				assert_eq(magnitude, Gen2WorldAPI.CELL_PIXELS)
			elif was_stepping:
				assert_true(
					magnitude <= previous_magnitude,
					"step offset must ease toward zero within one step, not grow"
				)
			saw_step = true
			was_stepping = true
			previous_magnitude = magnitude
			lowest_magnitude = mini(lowest_magnitude, magnitude)
		else:
			was_stepping = false
		var waiting: Dictionary = _world_screen._world.pending_script_input()
		if StringName(waiting.get("type", &"")) in [&"text", &"button"]:
			_world_screen._advance_script_input()
	await get_tree().process_frame
	assert_not_null(_battle_host())
	assert_true(saw_step)
	# tick_step() spends one hardware frame, the same one the emote and
	# movement-delay counters are spent by; the offset eases down to one
	# STEP_PASSES_WALK-th of a cell on the frame before the step formally ends.
	assert_eq(lowest_magnitude, Gen2WorldAPI.CELL_PIXELS / Gen2WorldAPI.STEP_PASSES_WALK)


func test_victory_displays_imported_text_reloads_objects_and_keeps_player_cell() -> void:
	await _open_world()
	await _trigger_trainer()
	var host: Gen2BattleScreen = _battle_child()
	assert_not_null(host)

	## Beaten before the entrance is spent, so `DoBattle` reaches its result
	## rather than its first menu: nothing reads a button between them.
	for _hit: int in 12:
		host.hurt_enemy()
	host = _battle_host()
	var result_text: Dictionary = host.battle_snapshot()
	assert_eq(result_text["message"], "YOU WON.")

	## `.give_money` prints behind `PrintWinLossText`, so the win takes one more
	## press: 25 base times the last member's level of 5, four quarters over.
	host.finish()
	host.advance()
	assert_eq(host.battle_snapshot()["message"], "%s got ¥500\nfor winning!" % UNSAVED_PLAYER)

	host.finish()
	host.advance()
	await get_tree().process_frame
	var world: Dictionary = _world_screen.world_snapshot()
	assert_eq(world["map"], Vector2i(Fixture.MAP_GROUP, Fixture.MAP_NUMBER))
	assert_eq(world["player_cell"], Vector2i(5, 5))
	assert_eq(world["visible_objects"], 0)
	assert_true(world["just_battled"])


## Gold/Silver share one command profile (Gen2WorldScriptRunner._crystal_commands()
## returns false for both), so covering the "gold" game id also covers Silver's
## opcode layout for this flow.
func test_gold_profile_trainer_sight_reaches_the_real_battle_overlay() -> void:
	_data = Fixture.build(&"gold")
	await _open_world()
	var before: Dictionary = _world_screen.world_snapshot()
	await _trigger_trainer()

	var host: Gen2BattleScreen = _battle_opening()
	assert_not_null(host)
	assert_eq(before["player_cell"], Vector2i(4, 5))
	assert_eq(_world_screen.world_snapshot()["player_cell"], Vector2i(5, 5))
	assert_eq((_world_screen._world.objects[0] as Gen2WorldObject).cell, Vector2i(5, 4))
	assert_eq(
		(_world_screen._world.objects[0] as Gen2WorldObject).facing,
		Gen2WorldSprite.FACING_DOWN
	)
	assert_eq(_world_screen._world.player_facing, Gen2WorldSprite.FACING_UP)
	assert_true(host.is_ready())
	var snapshot: Dictionary = host.battle_snapshot()
	assert_eq(snapshot["enemy"], Fixture.TRAINER_SPECIES)
	assert_eq(snapshot["message"], "LEADER RIVAL\nwants to battle!")
	assert_eq(snapshot["world_battle_active"], true)


func test_gold_profile_victory_commits_beaten_flag_and_reloads_objects() -> void:
	_data = Fixture.build(&"gold")
	await _open_world()
	await _trigger_trainer()
	var host: Gen2BattleScreen = _battle_child()
	assert_not_null(host)

	## Beaten before the entrance is spent, so `DoBattle` reaches its result
	## rather than its first menu: nothing reads a button between them.
	for _hit: int in 12:
		host.hurt_enemy()
	host = _battle_host()
	assert_eq(host.battle_snapshot()["message"], "YOU WON.")

	## `.give_money` prints behind `PrintWinLossText`, so the win takes one more
	## press: 25 base times the last member's level of 5, four quarters over.
	host.finish()
	host.advance()
	assert_eq(host.battle_snapshot()["message"], "%s got ¥500\nfor winning!" % UNSAVED_PLAYER)

	host.finish()
	host.advance()
	await get_tree().process_frame
	var world: Dictionary = _world_screen.world_snapshot()
	assert_eq(world["player_cell"], Vector2i(5, 5))
	assert_eq(world["visible_objects"], 0)
	assert_true(world["just_battled"])


## `LostBattle`'s `.not_canlose` prints nothing of its own: the loss text is the
## trainer's, and `_WhitedOutText` belongs to `Script_Whiteout` on the map that
## `Script_reloadmapafterbattle` jumps to. So the battle ends on the imported
## line and the overworld opens the whiteout's own box.
func test_defeat_displays_imported_loss_text_and_then_whites_the_player_out() -> void:
	await _open_world(true)
	await _trigger_trainer()
	var host: Gen2BattleScreen = _battle_child()
	assert_not_null(host)

	for _hit: int in 12:
		host.hurt_player()
	for member: Gen2BattleMon in host._battle.party(Gen2Battle.PLAYER).mons:
		member.hp = 0
	host = _battle_host()
	assert_eq(host.battle_snapshot()["message"], "YOU LOST.")

	host.finish()
	host.advance()
	await get_tree().process_frame
	assert_true(_world_screen._field_move_text, "the whiteout owns the box")
	var lines: PackedStringArray = _world_screen._text_box.text_lines()
	assert_true(
		"".join(lines).contains("whited"),
		"_WhitedOutText, not an invented one: %s" % "".join(lines)
	)
	var world: Dictionary = _world_screen.world_snapshot()
	assert_eq(world["player_cell"], Vector2i(5, 5), "nothing moves before the press")
	assert_false(world["just_battled"])


## The seam `tools/replay_world.gd` closes: a fight inside a walk belongs to the
## world's own clock and the world's own funnel, so it is spent and steered by the
## same two calls the map is, and its own decisions come out of the run's seed.
func test_a_battle_is_spent_and_steered_by_the_world_that_opened_it() -> void:
	await _open_world(true)
	await _trigger_trainer()
	var host: Gen2BattleScreen = _battle_child()
	assert_not_null(host)
	assert_true(_world_screen.battle_active())
	assert_eq(_world_screen.battles_fought(), 1)
	assert_false(host.is_processing(), "the fight does not spend frames of its own")

	## The intro slides on hardware frames, and the only ones it gets are the
	## world's: nothing here waits on real time.
	var slid: bool = false
	for _frame: int in 200:
		_world_screen.advance_frame()
		if host.battle_snapshot()["message"] != "":
			slid = true
			break
	assert_true(slid, "the world's own pump reached the battle's first message")

	## And one press, through the world, reaches the fight rather than the map:
	## the funnel is what makes a recorded log complete.
	_world_screen.record_input()
	assert_true(_world_screen.press_button(Gen2Button.A))
	var recorded: Array = _world_screen.input_recording()
	assert_eq(recorded.size(), 1, "the world recorded the battle's own press")
	assert_eq(int(recorded[0]["button"]), Gen2Button.A)


## Two runs of the same fight from the same seed decide the same things, which is
## what makes a battle inside a replay reproducible without recording any of it.
func test_two_battles_from_one_seed_choose_the_same_enemy_moves() -> void:
	var choices: Array = []
	for _run: int in 2:
		await _open_world(true, 0x5EED)
		await _trigger_trainer()
		var host: Gen2BattleScreen = _battle_host()
		assert_not_null(host)
		var seen: Array = []
		for _frame: int in 900:
			_world_screen.advance_frame()
			if not _world_screen.battle_active():
				break
			var message: String = String(host.battle_snapshot()["message"])
			if message.begins_with("Enemy ") and (seen.is_empty() or seen[-1] != message):
				seen.append(message)
			_world_screen.press_button(Gen2Button.A)
		choices.append(seen)
		_world_screen.queue_free()
		await get_tree().process_frame
	assert_false((choices[0] as Array).is_empty(), "the enemy took at least one turn")
	assert_eq(choices[0], choices[1])


func test_effect_sprite_preview_reaches_the_production_world_renderer() -> void:
	await _open_world()
	_world_screen.preview_effect_sprites()
	await get_tree().process_frame

	assert_eq(_world_screen.world_snapshot()["script_prompt"], "Debug effect sprite preview")
	assert_true((_world_screen._world.objects[0] as Gen2WorldObject).emote_visible)
	assert_eq(_world_screen._effects.sprites().size(), 3,
		"the dust, the rustle and the tree are all staged")


func test_production_world_entry_and_facing_object_story_persist_separate_flags() -> void:
	_install_story_slice()
	await _open_world()
	assert_eq(_world_screen._world.state.map_scene(Fixture.MAP_GROUP, Fixture.MAP_NUMBER), 2)

	_world_screen._world.player_cell = Vector2i(4, 3)
	_world_screen._world.player_facing = Gen2WorldSprite.FACING_RIGHT
	assert_true(_world_screen.interact())
	## The `waitbutton` behind the `writetext`, which is what a text ending in
	## `<DONE>` leaves the script holding on.
	assert_eq(
		StringName(_world_screen._world.pending_script_input().get("type", &"")), &"button"
	)
	assert_false(_world_screen._world.event_flag_active(STORY_EVENT_FLAG))
	assert_false(_world_screen._world.state.hall_of_fame())

	## The box reveals at the OPTION menu's TEXT SPEED, and a press cannot shorten
	## it: `PrintLetterDelay` is all a button reaches while a text is running, and
	## the most it does there is one letter a frame. So the page is spent in
	## frames and then one press acknowledges it.
	_world_screen.advance_frames(_world_screen._text_box.frames_left())
	_world_screen._advance_script_input()
	assert_true(_world_screen._world.event_flag_active(STORY_EVENT_FLAG))
	assert_true(_world_screen._world.state.hall_of_fame())
	## Still on screen: `ReadObjectEvents` tested the flag when the map loaded
	## and nothing re-tests it while the map is up, so the `setevent` this script
	## just ran hides the object on the next load, which is `restored` below.
	assert_eq(_world_screen.world_snapshot()["visible_objects"], 1)

	var snapshot: Gen2WorldSnapshot = _world_screen.world_save_snapshot()
	var restored: Gen2WorldAPI = Gen2WorldAPI.open_snapshot(_data, snapshot)
	assert_not_null(restored)
	assert_eq(restored.state.map_scene(Fixture.MAP_GROUP, Fixture.MAP_NUMBER), 2)
	assert_true(restored.event_flag_active(STORY_EVENT_FLAG))
	assert_true(restored.state.hall_of_fame())
	assert_eq(restored.visible_objects().size(), 0)


func test_resolved_wild_encounter_reaches_the_real_battle_overlay() -> void:
	await _open_world()
	_world_screen.preview_wild_encounter()
	await get_tree().process_frame
	await get_tree().process_frame

	var host: Gen2BattleScreen = _battle_opening()
	assert_not_null(host)
	assert_true(host.is_ready())
	assert_eq(host.battle_snapshot()["enemy"], Fixture.TRAINER_SPECIES)
	assert_eq(host.battle_snapshot()["message"], "Wild %s\nappeared!" % _wild_name())


## `BattleEnd_HandleRoamMons` reached through the screen that owns it: the shape
## the battle overlay reports a finished fight in is what the write-back reads,
## so a roamer run from keeps its HP and one defeated empties its struct.
func test_a_finished_roaming_battle_writes_the_struct_back() -> void:
	await _open_world()
	var state: Gen2WorldState = _world_screen._world.state
	state.ensure_roaming_mons(
		[{"species": Fixture.TRAINER_SPECIES, "level": 40, "map_group": 1, "map_number": 1}]
	)
	var finished: Dictionary = {
		"ok": true,
		"outcome": Gen2WorldBattleAdapter.OUTCOME_RAN,
		"request": {
			"kind": &"wild", "pokemon": Fixture.TRAINER_SPECIES, "level": 40,
			"battle_type": Gen2Battle.BATTLETYPE_ROAMING,
		},
		"enemy": {"species": Fixture.TRAINER_SPECIES, "hp": 12, "dvs": 0x1234},
	}
	_world_screen._on_battle_finished(finished)
	assert_eq(int(state.roaming_mons()[0]["hp"]), 12)
	assert_eq(int(state.roaming_mons()[0]["dvs"]), 0x1234)

	finished["outcome"] = Gen2WorldBattleAdapter.OUTCOME_WON
	finished["enemy"] = {"species": Fixture.TRAINER_SPECIES, "hp": 0, "dvs": 0x1234}
	_world_screen._on_battle_finished(finished)
	assert_eq(int(state.roaming_mons()[0]["species"]), 0)
	assert_eq(state.roaming_mons_on(1, 1).size(), 0)


## `CatchTutorial`: a whole battle, answered by `DudeAutoInputs` rather than by
## the player. Nobody presses anything here, so what this drives is frames.
func test_the_dude_plays_the_catching_tutorial_and_keeps_nothing() -> void:
	await _open_world()
	var balls_before: int = _world_screen._world.state.item_quantity(
		Gen2WorldPartyHost.ITEM_POKE_BALL
	)
	var results: Array = _world_screen._world.dispatch_script_events(Vector2i(4, 5))
	assert_eq(results[0]["status"], &"waiting")
	assert_eq(results[0]["event"]["request"]["kind"], &"catch_tutorial_requested")
	_world_screen._show_script_results(results)
	var host: Gen2BattleScreen = _battle_child()
	assert_not_null(host)
	var party_before: int = _world_screen._active_battle_save.party.size() \
		if _world_screen._active_battle_save != null else 0

	var messages: Array[String] = []
	var throw_frame: int = -1
	var frames: int = 0
	while _world_screen._battle_host != null and frames < DUDE_FRAME_GUARD:
		frames += 1
		var line: String = String(host.battle_snapshot()["message"])
		if messages.is_empty() or messages.back() != line:
			messages.append(line)
			if throw_frame < 0 and line == "DUDE used the\nPOKE BALL.":
				throw_frame = frames
		host.advance_hardware_frame()
	assert_lt(frames, DUDE_FRAME_GUARD, "the tutorial answers itself: %s" % JSON.stringify(messages))
	print("dude: ball thrown on frame %d, tutorial over on %d" % [throw_frame, frames])
	assert_between(throw_frame, 1, DUDE_TUTORIAL_FRAMES,
		"the Dude reached the ball on frame %d" % throw_frame)
	assert_lt(frames, DUDE_FRAME_GUARD, "the tutorial ran %d frames" % frames)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true("DUDE used the\nPOKE BALL." in messages, JSON.stringify(messages))
	assert_true("Gotcha! %s was caught!" % _wild_name() in messages, JSON.stringify(messages))
	assert_eq(
		_world_screen._world.state.item_quantity(Gen2WorldPartyHost.ITEM_POKE_BALL),
		balls_before
	)
	assert_eq(
		_world_screen._active_battle_save.party.size() \
			if _world_screen._active_battle_save != null else 0,
		party_before
	)
	assert_false(_world_screen._world.state.just_battled())


func test_fishing_reaches_the_real_battle_overlay() -> void:
	await _open_world()
	_world_screen.start_cell = Vector2i(8, 6)
	_world_screen._world.player_cell = Vector2i(8, 6)
	var started: Dictionary = _world_screen.start_fishing(true)
	assert_true(started["ok"])
	assert_eq(_world_screen._world.advance_fishing()["kind"], &"fishing_bite")
	var battle: Dictionary = _world_screen._world.advance_fishing()
	assert_eq(battle["kind"], &"battle_requested")
	_world_screen._handle_fishing_result(battle)
	await get_tree().process_frame
	var host: Gen2BattleScreen = _battle_host()
	assert_not_null(host)
	assert_eq(host.battle_snapshot()["enemy"], Fixture.TRAINER_SPECIES)


func test_master_ball_capture_runs_through_the_real_battle_overlay() -> void:
	await _open_world()
	var added: Dictionary = _world_screen._world.state.apply_changes(
		{}, {}, {"items": {Gen2WorldPartyHost.ITEM_MASTER_BALL: 1}}
	)
	assert_true(added["ok"])
	assert_eq(_world_screen._world.state.items(), {
		Gen2WorldInventory.ITEM_OLD_ROD: 1,
		Gen2WorldPartyHost.ITEM_POKE_BALL: 1,
		Gen2WorldPartyHost.ITEM_MASTER_BALL: 1,
	})
	_world_screen.preview_wild_encounter()
	await get_tree().process_frame
	await get_tree().process_frame

	var host: Gen2BattleScreen = _battle_host()
	assert_not_null(host)
	assert_eq(host.battle_snapshot()["capture_balls"], [
		Gen2WorldPartyHost.ITEM_POKE_BALL, Gen2WorldPartyHost.ITEM_MASTER_BALL,
	])
	assert_true(host.begin_capture()["ok"])
	assert_true(host.select_capture_ball(1)["ok"])
	assert_true(host.throw_capture_ball()["ok"])
	_settle_frames(host)
	assert_eq(
		host.battle_snapshot()["message"],
		host._item_used_text(Gen2WorldPartyHost.ITEM_MASTER_BALL)
	)

	var caught: String = "Gotcha! %s was caught!" % _wild_name()
	for _message: int in 8:
		if host.battle_snapshot()["message"] == caught:
			break
		host.finish()
		host.advance()

	assert_eq(host.battle_snapshot()["message"], caught)
	host.finish()
	host.advance()
	_refuse_capture_nickname(host)
	await get_tree().process_frame
	assert_null(_battle_host())
	assert_eq(_world_screen._world.state.item_quantity(Gen2WorldPartyHost.ITEM_MASTER_BALL), 0)
	assert_eq(_world_screen.world_snapshot()["script_prompt"], "Caught %s" % _wild_name())


## `PokeBallEffect` reaches `AskGiveNicknameText` only once
## `Text_GotchaMonWasCaught` has finished printing. A Nuzlocke is where an early
## prompt shows, because it skips the question and opens the keyboard outright:
## the naming screen stood over a box halfway through "Gotcha! X was caught!".
func test_the_catch_prompt_waits_for_the_gotcha_line() -> void:
	await _open_world(true, 0, Gen2Rules.CHALLENGE_NUZLOCKE)
	assert_true(bool(_world_screen._world.state.apply_changes(
		{}, {}, {"items": {Gen2WorldPartyHost.ITEM_MASTER_BALL: 1}}
	)["ok"]))
	_world_screen.preview_wild_encounter()
	await get_tree().process_frame
	await get_tree().process_frame

	var host: Gen2BattleScreen = _battle_host()
	assert_not_null(host)
	assert_true(host.begin_capture()["ok"])
	assert_true(host.select_capture_ball(
		host.available_capture_balls().find(Gen2WorldPartyHost.ITEM_MASTER_BALL)
	)["ok"])
	assert_true(host.throw_capture_ball()["ok"])
	_settle_frames(host)

	var caught: String = "Gotcha! %s was caught!" % _wild_name()
	for _message: int in 10:
		if String(host.battle_snapshot()["message"]) == caught:
			break
		host.finish()
		host.advance()
	assert_eq(String(host.battle_snapshot()["message"]), caught)
	var box: Gen2TextBox = host.get("_box")
	assert_true(box.is_revealing(), "the caught line has only just been put up")
	assert_true(
		host._open_capture_nickname(),
		"the prompt is owed, so the pump waits here rather than running on"
	)
	assert_null(
		host.get("_capture_nickname_host"),
		"and nothing is built over a line that is still printing"
	)

	box.finish()
	assert_true(host._open_capture_nickname())
	assert_not_null(
		host.get("_capture_nickname_host"),
		"once the line is done the keyboard opens, no question asked"
	)


func test_failed_capture_shows_break_free_and_returns_to_battle() -> void:
	await _open_world()
	_data.species(Fixture.TRAINER_SPECIES)["catch_rate"] = 1
	_world_screen._encounter_random.seed = 1
	_world_screen.preview_wild_encounter()
	await get_tree().process_frame
	await get_tree().process_frame

	var host: Gen2BattleScreen = _battle_host()
	assert_not_null(host)
	assert_true(host.begin_capture()["ok"])
	assert_true(host.throw_capture_ball()["ok"])
	_settle_frames(host)
	assert_eq(
		host.battle_snapshot()["message"],
		host._item_used_text(Gen2WorldPartyHost.ITEM_POKE_BALL)
	)

	## One of `.shake_and_break_free`'s four lines and nothing else: which one is
	## the rock count's to decide, and no line is said for a rock of its own.
	var saw_break_free: bool = false
	for _message: int in 5:
		host.finish()
		host.advance()
		if Gen2BattleScreen.BREAK_FREE_TEXT.has(host.battle_snapshot()["message"]):
			saw_break_free = true

	assert_true(saw_break_free)
	assert_not_null(_battle_host())
	assert_eq(_world_screen._world.state.item_quantity(Gen2WorldPartyHost.ITEM_POKE_BALL), 0)
	assert_false(host.battle_snapshot()["capture_waiting"])


func test_project_save_can_carry_the_world_snapshot_without_guessing_a_spawn() -> void:
	await _open_world()
	var player: Gen2BattleMon = Gen2BattleMon.create(
		_data, Fixture.TRAINER_SPECIES, 5, [BattleFixture.TACKLE]
	)
	var save: Gen2SaveData = Gen2SaveBattleAdapter.from_battle_party(
		_data.id, _data.sha1, 0, Gen2Party.of(player), "TEST"
	)
	save.world = _world_screen.world_save_snapshot()
	var validation: Dictionary = Gen2SaveValidator.validate(save, _data)
	assert_true(validation["ok"], validation["message"])
	var round_trip: Gen2SaveData = Gen2SaveData.from_dict(save.to_dict())
	assert_not_null(round_trip.world)
	assert_eq(round_trip.world.map_id, Vector2i(Fixture.MAP_GROUP, Fixture.MAP_NUMBER))
	assert_eq(round_trip.world.player_cell, Vector2i(4, 5))


func test_party_heal_special_restores_save_hp_status_and_move_pp() -> void:
	var scripts: Dictionary = RomCache.read_json(RomCache.world_scripts_path(Fixture.directory()))
	var heal_script: int = 0x6300
	scripts[Gen2WorldScript.pointer_key(Fixture.BANK, heal_script)] = [
		Gen2WorldScript.SPECIAL, 27, 0, Gen2WorldScript.END,
	]
	RomCache.write_json(RomCache.world_scripts_path(Fixture.directory()), scripts)
	_data = GameData.open_directory(Fixture.directory())
	await _open_world(true)

	var save: Gen2SaveData = _world_screen._injected_save
	var mon: Gen2SaveMon = save.party[0]
	var battle_mon: Gen2BattleMon = Gen2SaveBattleAdapter.to_battle_mon(_data, mon)
	mon.hp = 1
	mon.status = Gen2Status.POISON
	mon.pp[0] = 0
	_world_screen._world.current_map.events["coord_events"] = [{
		"scene": 0, "x": 4, "y": 5, "script": heal_script,
	}]

	var waiting: Array = _world_screen._world.dispatch_script_events(Vector2i(4, 5))
	assert_eq(waiting[0]["status"], &"waiting", JSON.stringify(waiting))
	assert_eq(_world_screen._world.pending_runtime_request()["kind"], &"party_heal_requested")
	var complete: Dictionary = Gen2WorldHost.complete_runtime_request(
		_world_screen._world, {}, save, false
	)
	assert_true(complete["ok"], JSON.stringify(complete))
	var healed_mon: Gen2SaveMon = save.party[0]
	assert_eq(healed_mon.hp, battle_mon.max_hp())
	assert_eq(healed_mon.status, Gen2Status.NONE)
	assert_eq(healed_mon.pp[0], int(_data.move(BattleFixture.TACKLE).get("pp", 0)))


## A trimmed PokecenterNurseScript: yesorno, HealParty, then HealMachineAnim,
## matching the source's std script call order in
## engine/events/std_scripts.asm.
func test_nurse_script_heals_the_party_after_accepting_and_shows_the_heal_machine() -> void:
	var scripts: Dictionary = RomCache.read_json(RomCache.world_scripts_path(Fixture.directory()))
	var nurse_script: int = 0x6310
	var done_script: int = 0x6320
	scripts[Gen2WorldScript.pointer_key(Fixture.BANK, nurse_script)] = [
		Gen2WorldScript.YESORNO,
		Gen2WorldScript.IFFALSE, done_script & 0xFF, (done_script >> 8) & 0xFF,
		Gen2WorldScript.SPECIAL, 27, 0,
		Gen2WorldScript.SETVAL, 0,
		Gen2WorldScript.SPECIAL, Gen2WorldScriptRunner.SPECIAL_HEAL_MACHINE_ANIM, 0,
		Gen2WorldScript.END,
	]
	scripts[Gen2WorldScript.pointer_key(Fixture.BANK, done_script)] = [Gen2WorldScript.END]
	RomCache.write_json(RomCache.world_scripts_path(Fixture.directory()), scripts)
	_data = GameData.open_directory(Fixture.directory())
	await _open_world(true)

	var save: Gen2SaveData = _world_screen._injected_save
	var mon: Gen2SaveMon = save.party[0]
	var battle_mon: Gen2BattleMon = Gen2SaveBattleAdapter.to_battle_mon(_data, mon)
	mon.hp = 1
	_world_screen._world.current_map.events["coord_events"] = [{
		"scene": 0, "x": 4, "y": 5, "script": nurse_script,
	}]

	var waiting: Array = _world_screen._world.dispatch_script_events(Vector2i(4, 5))
	assert_eq(waiting[0]["status"], &"waiting", JSON.stringify(waiting))
	assert_eq(waiting[0]["event"]["type"], &"choice")

	var after_choice: Array = _world_screen._world.choose_script_input(0)
	assert_eq(after_choice[0]["status"], &"waiting", JSON.stringify(after_choice))
	assert_eq(_world_screen._world.pending_runtime_request()["kind"], &"party_heal_requested")

	var complete: Dictionary = Gen2WorldHost.complete_runtime_request(
		_world_screen._world, {}, save, false
	)
	assert_true(complete["ok"], JSON.stringify(complete))
	var results: Array = complete.get("results", [])
	var last: Dictionary = results[results.size() - 1]
	assert_eq(
		_event_value(last.get("events", []), &"presentation_special_applied", "kind"),
		&"heal_machine_anim",
		JSON.stringify(results),
	)
	var healed_mon: Gen2SaveMon = save.party[0]
	assert_eq(healed_mon.hp, battle_mon.max_hp())

	## `HealMachineAnim` is thirty frames a ball and `.FlashPalettes8Times`'
	## eighty, so the script is still standing in the special rather than past it.
	assert_eq(StringName(last["status"]), &"waiting", JSON.stringify(results))
	assert_eq(
		int(last["event"]["frames"]),
		Gen2WorldScriptRunner.HEAL_MACHINE_BALL_FRAMES
			+ Gen2WorldScriptRunner.HEAL_MACHINE_FLASH_FRAMES,
	)
	assert_eq(
		_event_value(last.get("events", []), &"presentation_special_applied", "sounds"),
		[
			{
				"frame": 0, "kind": &"sound",
				"index": Gen2WorldScriptRunner.SFX_SECOND_PART_OF_ITEMFINDER,
			},
			{
				"frame": Gen2WorldScriptRunner.HEAL_MACHINE_BALL_FRAMES,
				"kind": &"music", "index": Gen2WorldScriptRunner.MUSIC_HEAL,
			},
		],
	)


func test_nurse_script_leaves_the_party_unhealed_on_refusal() -> void:
	var scripts: Dictionary = RomCache.read_json(RomCache.world_scripts_path(Fixture.directory()))
	var nurse_script: int = 0x6330
	var done_script: int = 0x6340
	scripts[Gen2WorldScript.pointer_key(Fixture.BANK, nurse_script)] = [
		Gen2WorldScript.YESORNO,
		Gen2WorldScript.IFFALSE, done_script & 0xFF, (done_script >> 8) & 0xFF,
		Gen2WorldScript.SPECIAL, 27, 0,
		Gen2WorldScript.END,
	]
	scripts[Gen2WorldScript.pointer_key(Fixture.BANK, done_script)] = [Gen2WorldScript.END]
	RomCache.write_json(RomCache.world_scripts_path(Fixture.directory()), scripts)
	_data = GameData.open_directory(Fixture.directory())
	await _open_world(true)

	var save: Gen2SaveData = _world_screen._injected_save
	var mon: Gen2SaveMon = save.party[0]
	mon.hp = 1
	_world_screen._world.current_map.events["coord_events"] = [{
		"scene": 0, "x": 4, "y": 5, "script": nurse_script,
	}]

	var waiting: Array = _world_screen._world.dispatch_script_events(Vector2i(4, 5))
	assert_eq(waiting[0]["status"], &"waiting", JSON.stringify(waiting))

	var after_choice: Array = _world_screen._world.choose_script_input(1)
	assert_eq(after_choice[0]["status"], &"complete", JSON.stringify(after_choice))
	assert_true(_world_screen._world.pending_runtime_request().is_empty())
	assert_eq(save.party[0].hp, 1)


func test_zephyr_badge_survives_a_snapshot_save_and_reload() -> void:
	await _open_world(true)
	_world_screen._world.state.set_engine_flag(Gen2WorldState.ENGINE_ZEPHYRBADGE)
	assert_eq(_world_screen._world.state.badge_count(), 1)

	var save: Gen2SaveData = _world_screen._injected_save
	save.world = _world_screen._world.snapshot()
	var validation: Dictionary = Gen2SaveValidator.validate(save, _data)
	assert_true(validation["ok"], validation["message"])

	var round_trip: Gen2SaveData = Gen2SaveData.from_dict(save.to_dict())
	assert_not_null(round_trip.world)
	var restored: Gen2WorldAPI = Gen2WorldAPI.open_snapshot(_data, round_trip.world)
	assert_not_null(restored)
	assert_eq(restored.state.badge_count(), 1)
	assert_true(restored.state.is_engine_flag_active(Gen2WorldState.ENGINE_ZEPHYRBADGE))


## The Togepi egg joins the party before Route 32 opens, so every trainer after
## it fights with an egg in a party slot.
func test_a_trainer_battle_fights_and_writes_back_with_an_egg_in_the_party() -> void:
	await _open_world(true)
	var save: Gen2SaveData = _world_screen._injected_save
	# Built the way Gen2WorldPartyHost's GIVEEGG builds one, so the save
	# validator sees a consistent level and experience.
	var egg: Gen2SaveMon = Gen2SaveBattleAdapter.from_battle_mon(
		Gen2BattleMon.create(_data, Fixture.TRAINER_SPECIES, 5, [BattleFixture.TACKLE])
	)
	egg.is_egg = true
	egg.hp = 0
	egg.nickname = "EGG"
	save.party.append(egg)

	await _trigger_trainer()
	var host: Gen2BattleScreen = _battle_child()
	assert_not_null(host, "an egg in the party must not refuse the battle")
	assert_eq(host.battle_snapshot()["world_battle_active"], true)

	for _hit: int in 12:
		host.hurt_enemy()
	host = _battle_host()
	assert_eq(host.battle_snapshot()["message"], "YOU WON.")
	## `.give_money` prints behind `PrintWinLossText`, so the win takes one more
	## press: 25 base times the last member's level of 5, four quarters over.
	host.finish()
	host.advance()
	assert_eq(host.battle_snapshot()["message"], "%s got ¥500\nfor winning!" % SAVED_PLAYER)

	host.finish()
	host.advance()
	await get_tree().process_frame
	assert_true(_world_screen.world_snapshot()["just_battled"])

	var written: Gen2SaveData = Gen2SaveBattleAdapter.from_battle_party(
		_data.id, _data.sha1, save.slot,
		Gen2SaveBattleAdapter.to_battle_party(_data, save), "", save
	)
	assert_not_null(written)
	assert_eq(written.party.size(), 2)
	assert_false((written.party[0] as Gen2SaveMon).is_egg)
	assert_true((written.party[1] as Gen2SaveMon).is_egg)
	assert_eq((written.party[1] as Gen2SaveMon).nickname, "EGG")


## Regression: `Gen2SaveBattleAdapter.from_battle_party` returns a clone, and
## `_save_battle_result` used to write that clone to disk without copying it
## back over `_source_save`, the live save the world screen and the next
## battle both read. A won battle's HP, experience and PP reverted the moment
## a second battle started.
func test_hp_experience_and_pp_survive_into_the_next_wild_battle() -> void:
	await _open_world(true)
	var save: Gen2SaveData = _world_screen._injected_save
	var starting_pp: int = (save.party[0] as Gen2SaveMon).pp[0]

	_world_screen.preview_wild_encounter()
	await get_tree().process_frame
	await get_tree().process_frame
	var host: Gen2BattleScreen = _battle_opening()
	assert_not_null(host)
	assert_eq(host.battle_snapshot()["message"], "Wild %s\nappeared!" % _wild_name())
	host = _battle_host()

	var player_mon: Gen2BattleMon = host._battle.party(Gen2Battle.PLAYER).mons[0]
	var max_hp: int = player_mon.max_hp()
	player_mon.take_damage(1)
	player_mon.pp[0] -= 1

	for _hit: int in 20:
		host.hurt_enemy()
	## A wild victory carries no win text on the cartridge, unlike a trainer's
	## (`_show_world_battle_terminal_text` finds no `win_text` pointer in the
	## wild request and returns false), so the overlay closes silently rather
	## than pausing on a "YOU WON." message the way the trainer tests wait for.
	var guard: int = 10
	while _battle_child() != null and guard > 0:
		host.finish()
		host.advance()
		guard -= 1
	await get_tree().process_frame
	assert_null(_battle_child())

	var after_first: Gen2SaveMon = save.party[0] as Gen2SaveMon
	assert_true(after_first.exp > 0, "a win must award experience into the live save")
	assert_true(after_first.hp < max_hp, "the live save must carry the damage taken")
	assert_eq(after_first.pp[0], starting_pp - 1, "the live save must carry the PP spent")

	_world_screen.preview_wild_encounter()
	await get_tree().process_frame
	await get_tree().process_frame
	var second_host: Gen2BattleScreen = _battle_host()
	assert_not_null(second_host)
	var second_player: Gen2BattleMon = second_host._battle.party(Gen2Battle.PLAYER).mons[0]
	assert_eq(second_player.hp, after_first.hp, "the next battle must start from the carried HP")
	assert_eq(
		second_player.exp, after_first.exp, "the next battle must start from the carried experience"
	)
	assert_eq(
		second_player.pp[0], after_first.pp[0], "the next battle must start from the carried PP"
	)


## `wPartyMon` is the fighting copy, so a run keeps the damage taken and the PP
## spent exactly as a win does; only a blackout puts the pre-battle party back.
## `_save_battle_result` used to refuse every battle the player did not win, so
## a wild encounter walked away from cost nothing.
func test_running_away_keeps_the_damage_taken_and_the_pp_spent() -> void:
	await _open_world(true)
	var save: Gen2SaveData = _world_screen._injected_save
	var starting_pp: int = (save.party[0] as Gen2SaveMon).pp[0]
	var starting_hp: int = (save.party[0] as Gen2SaveMon).hp

	_world_screen.preview_wild_encounter()
	await get_tree().process_frame
	await get_tree().process_frame
	var host: Gen2BattleScreen = _battle_host()
	assert_not_null(host)
	host.finish()
	host.advance()

	var player_mon: Gen2BattleMon = host._battle.party(Gen2Battle.PLAYER).mons[0]
	player_mon.take_damage(3)
	player_mon.pp[0] -= 1

	host.run_from_battle()
	assert_true(host._battle.has_fled())
	var guard: int = 10
	while _battle_child() != null and guard > 0:
		host.finish()
		host.advance()
		guard -= 1
	await get_tree().process_frame
	assert_null(_battle_child())

	var after: Gen2SaveMon = save.party[0] as Gen2SaveMon
	assert_eq(after.hp, starting_hp - 3, "the live save must carry the damage taken")
	assert_eq(after.pp[0], starting_pp - 1, "the live save must carry the PP spent")


## The catch is its own transaction and builds its candidate from the live save,
## so the party that fought the wild down has to reach that save before the ball
## is thrown; otherwise catching gives the HP and PP back.
func test_a_capture_keeps_the_damage_taken_and_the_pp_spent() -> void:
	await _open_world(true)
	var save: Gen2SaveData = _world_screen._injected_save
	var starting_pp: int = (save.party[0] as Gen2SaveMon).pp[0]
	var starting_hp: int = (save.party[0] as Gen2SaveMon).hp
	var added: Dictionary = _world_screen._world.state.apply_changes(
		{}, {}, {"items": {Gen2WorldPartyHost.ITEM_MASTER_BALL: 1}}
	)
	assert_true(added["ok"])

	_world_screen.preview_wild_encounter()
	await get_tree().process_frame
	await get_tree().process_frame
	var host: Gen2BattleScreen = _battle_host()
	assert_not_null(host)
	host.finish()
	host.advance()

	var player_mon: Gen2BattleMon = host._battle.party(Gen2Battle.PLAYER).mons[0]
	player_mon.take_damage(3)
	player_mon.pp[0] -= 1

	assert_true(host.begin_capture()["ok"])
	assert_true(host.select_capture_ball(1)["ok"])
	assert_true(host.throw_capture_ball()["ok"])
	_settle_frames(host)
	var guard: int = 12
	while _battle_child() != null and guard > 0:
		host.finish()
		host.advance()
		if host.get("_capture_nickname_host") != null:
			_refuse_capture_nickname(host)
		guard -= 1
	await get_tree().process_frame
	assert_null(_battle_child())
	assert_eq(_world_screen.world_snapshot()["script_prompt"], "Caught %s" % _wild_name())

	var after: Gen2SaveMon = save.party[0] as Gen2SaveMon
	assert_eq(after.hp, starting_hp - 3, "the caught save must carry the damage taken")
	assert_eq(after.pp[0], starting_pp - 1, "the caught save must carry the PP spent")


## `PokeBallEffect`'s own `AskGiveNicknameText`, which is not
## `GiveANickname_YesNo`'s `_CaughtAskNicknameText`: a caught Pokemon is asked
## about by name alone. YES reaches `NamingScreen` and `InitName` writes what it
## stored into the row `TryAddMonToParty` already added.
func test_a_caught_pokemon_is_named_over_the_battle() -> void:
	await _open_world(true)
	var save: Gen2SaveData = _world_screen._injected_save
	var before: int = save.party.size()
	assert_true(_world_screen._world.state.apply_changes(
		{}, {}, {"items": {Gen2WorldPartyHost.ITEM_MASTER_BALL: 1}}
	)["ok"])
	var host: Gen2BattleScreen = await _catch_the_wild()
	var prompt: Gen2NicknamePromptScreen = host.get("_capture_nickname_host")
	assert_not_null(prompt, "the prompt stands over the battle, not over the map")
	_settle_capture_nickname_text(host, prompt)
	assert_eq(prompt.text_lines(), PackedStringArray([
		"Give a nickname to", "%s?" % _wild_name(),
	]))
	assert_eq(prompt.nickname_cursor(), 0, "YesNoBox opens on YES")

	host.press_button(Gen2Button.A)
	assert_eq(prompt.phase(), Gen2NicknamePromptScreen.Phase.NAMING)
	var model: Gen2NamingScreen = prompt.naming_screen().model()
	assert_eq(model.max_length, Gen2NamingScreen.MON_MAX_LENGTH)
	model.press_a()
	model.column = Gen2NamingScreen.LAST_COLUMN
	model.row = model.command_row()
	host.press_button(Gen2Button.A)
	await get_tree().process_frame

	assert_null(_battle_host(), "and the fight ends behind it")
	assert_eq(save.party.size(), before + 1)
	assert_eq(
		(save.party[before] as Gen2SaveMon).nickname.length(), 1,
		"the one letter that was entered"
	)
	await get_tree().process_frame


## `.skip_nickname` keeps the species name `GetPokemonName` left in
## `wStringBuffer1`, and B is `YesNoBox`'s own NO.
func test_no_keeps_the_caught_species_name() -> void:
	await _open_world(true)
	var save: Gen2SaveData = _world_screen._injected_save
	var before: int = save.party.size()
	assert_true(_world_screen._world.state.apply_changes(
		{}, {}, {"items": {Gen2WorldPartyHost.ITEM_MASTER_BALL: 1}}
	)["ok"])
	var host: Gen2BattleScreen = await _catch_the_wild()
	_refuse_capture_nickname(host)
	await get_tree().process_frame
	assert_null(_battle_host())
	assert_eq(save.party.size(), before + 1)
	assert_eq((save.party[before] as Gen2SaveMon).nickname, _wild_name())
	await get_tree().process_frame


## `.SendToPC` prints `BallSentToPCText` behind the naming, and it reads
## `wMonOrItemNameBuffer`, which `.SkipBoxMonNickname`'s own copy has just filled
## from `sBoxMonNicknames`: the line names the row, not the species.
func test_a_boxed_catch_prints_bills_pc_with_the_name_the_keyboard_stored() -> void:
	await _open_world(true)
	var save: Gen2SaveData = _world_screen._injected_save
	while save.party.size() < Gen2SaveData.MAX_PARTY:
		save.party.append(Gen2SaveMon.from_dict((save.party[0] as Gen2SaveMon).to_dict()))
	assert_true(_world_screen._world.state.apply_changes(
		{}, {}, {"items": {Gen2WorldPartyHost.ITEM_MASTER_BALL: 1}}
	)["ok"])
	var host: Gen2BattleScreen = await _catch_the_wild()
	var prompt: Gen2NicknamePromptScreen = host.get("_capture_nickname_host")
	_settle_capture_nickname_text(host, prompt)
	host.press_button(Gen2Button.A)
	var model: Gen2NamingScreen = prompt.naming_screen().model()
	model.press_a()
	model.column = Gen2NamingScreen.LAST_COLUMN
	model.row = model.command_row()
	host.press_button(Gen2Button.A)
	assert_eq(prompt.phase(), Gen2NicknamePromptScreen.Phase.AFTER_TEXT)
	_settle_capture_nickname_text(host, prompt)
	var entered: String = " ".join(prompt.text_lines()).split(" was")[0]
	assert_eq(entered.length(), 1, "the one letter that was entered, not the species")
	assert_eq(
		" ".join(prompt.text_lines()),
		Gen2WorldPartyHost.sent_to_box_text(entered).replace("\n", " ")
	)
	host.press_button(Gen2Button.A)
	await get_tree().process_frame
	assert_null(_battle_host())
	assert_eq(save.party.size(), Gen2SaveData.MAX_PARTY)
	assert_eq((save.boxes[0].slots[0] as Gen2SaveMon).nickname, entered)
	await get_tree().process_frame


## A wild encounter, a Master Ball and the "Gotcha!" line pressed past, which is
## where `AskGiveNicknameText` stands.
func _catch_the_wild() -> Gen2BattleScreen:
	_world_screen.preview_wild_encounter()
	await get_tree().process_frame
	await get_tree().process_frame
	var host: Gen2BattleScreen = _battle_host()
	assert_not_null(host)
	assert_true(host.begin_capture()["ok"])
	assert_true(host.select_capture_ball(
		host.available_capture_balls().find(Gen2WorldPartyHost.ITEM_MASTER_BALL)
	)["ok"])
	assert_true(host.throw_capture_ball()["ok"])
	_settle_frames(host)
	for _message: int in 10:
		if host.get("_capture_nickname_host") != null:
			break
		host.finish()
		host.advance()
	return host


## `PrintText` owing the box frames, and the `YesNoBox` behind it not appearing
## until it owes none: each page the text ends on is a press.
func _settle_capture_nickname_text(
	host: Gen2BattleScreen, prompt: Gen2NicknamePromptScreen
) -> void:
	for _frame: int in 600:
		if prompt.phase() == Gen2NicknamePromptScreen.Phase.ASK:
			if prompt.question_ready():
				return
		elif not prompt._text_box.is_revealing() and not prompt._text_box.has_pages_left():
			return
		if not prompt._text_box.is_revealing() and prompt._text_box.has_pages_left():
			host.press_button(Gen2Button.A)
		host.advance_hardware_frame()


## `AskGiveNicknameText` behind the "Gotcha!" line, which `PokeBallEffect` prints
## whether the catch went to the party or to the box. Spends what the box owes,
## presses past each page it ends on, and answers NO, which is `.skip_nickname`.
func _refuse_capture_nickname(host: Gen2BattleScreen) -> void:
	var prompt: Gen2NicknamePromptScreen = host.get("_capture_nickname_host")
	assert_not_null(prompt, "`AskGiveNicknameText` is drawn over the battle")
	for _frame: int in 600:
		if prompt.question_ready():
			break
		if not prompt._text_box.is_revealing() and prompt._text_box.has_pages_left():
			host.press_button(Gen2Button.A)
		host.advance_hardware_frame()
	host.press_button(Gen2Button.B)


func _event_value(events: Array, event_type: StringName, key: String) -> Variant:
	for event: Dictionary in events:
		if event.get("type", &"") == event_type:
			return event.get(key, null)
	return null


func test_new_game_uses_the_verified_home_spawn_and_source_start_money() -> void:
	var save: Gen2SaveData = Gen2SaveStore.create_new_game(_data, 0, "TEST", 155)
	assert_not_null(save)
	assert_not_null(save.world)
	assert_eq(save.world.map_id, Vector2i(Gen2WorldSpawn.NEW_BARK_GROUP, Gen2WorldSpawn.PLAYERS_HOUSE_2F))
	assert_eq(save.world.player_cell, Gen2WorldSpawn.HOME_CELL)
	assert_eq(save.world.world_state.money(), Gen2WorldSpawn.START_MONEY)
	var validation: Dictionary = Gen2SaveValidator.validate(save, _data)
	assert_true(validation["ok"], validation["message"])


func _add_capture_metadata() -> void:
	var species: Array = RomCache.read_json(RomCache.species_path(Fixture.directory()))
	for raw: Dictionary in species:
		if int(raw["number"]) == Fixture.TRAINER_SPECIES:
			raw["catch_rate"] = 190
	RomCache.write_json(RomCache.species_path(Fixture.directory()), species)
	var items: Array = RomCache.read_json(RomCache.items_path(Fixture.directory()))
	for raw: Dictionary in items:
		if int(raw["number"]) in Gen2WorldPartyHost.capture_ball_items():
			raw["pocket"] = RomLayout.ITEM_POCKET_BALL
	RomCache.write_json(RomCache.items_path(Fixture.directory()), items)


func _install_story_slice() -> void:
	var scripts: Dictionary = RomCache.read_json(RomCache.world_scripts_path(Fixture.directory()))
	scripts[Gen2WorldScript.pointer_key(Fixture.BANK, STORY_CALLBACK)] = [
		Gen2WorldScript.SETSCENE, 2, Gen2WorldScript.END,
	]
	scripts[Gen2WorldScript.pointer_key(Fixture.BANK, STORY_OBJECT)] = [
		Gen2WorldScript.WRITETEXT, STORY_TEXT & 0xFF, STORY_TEXT >> 8,
		## The `waitbutton` every talked-to script carries behind its text:
		## `writetext` itself prints and returns.
		Gen2WorldScript.WAITBUTTON,
		Gen2WorldScript.SETEVENT, STORY_EVENT_FLAG, 0,
		Gen2WorldScript.SETFLAG, Gen2WorldState.ENGINE_HALL_OF_FAME, 0,
		Gen2WorldScript.END,
	]
	RomCache.write_json(RomCache.world_scripts_path(Fixture.directory()), scripts)
	RomCache.write_json(RomCache.world_text_path(Fixture.directory()), {
		Gen2WorldScript.pointer_key(Fixture.BANK, STORY_TEXT): [
			Gen2WorldScript.TEXT_START, 0x41, 0x42, Gen2WorldScript.TEXT_TERMINATOR,
		],
	})
	_data = GameData.open_directory(Fixture.directory())
	var map: Gen2WorldMap = _data.world_map(Fixture.MAP_GROUP, Fixture.MAP_NUMBER)
	map.scripts["callbacks"] = [{"type": 3, "script": STORY_CALLBACK}]
	var object: Dictionary = map.events["objects"][0]
	object["object_type"] = Gen2WorldObject.OBJECTTYPE_SCRIPT
	object["script"] = STORY_OBJECT
	object["event_flag"] = STORY_EVENT_FLAG


## Running from a real wild encounter, through the production overlay: the
## battle ends with nobody having won, the party is untouched, and the world
## comes back rather than blacking out.
##
## The player's Pokémon is faster than the fixture's wild one, so
## `TryToRunAwayFromBattle`'s speed comparison answers and no roll happens.
func test_running_from_a_wild_encounter_returns_to_the_world_without_a_loss() -> void:
	await _open_world()
	_world_screen.preview_wild_encounter()
	await get_tree().process_frame
	await get_tree().process_frame
	var host: Gen2BattleScreen = _battle_host()
	assert_not_null(host)
	var party_before: int = host._battle.party(Gen2Battle.PLAYER).at(0).hp

	host.run_from_battle()

	assert_true(host._battle.has_fled())
	assert_null(host._battle.winner())
	assert_eq(host.battle_snapshot()["message"], "Got away safely!")
	assert_eq(host._battle.party(Gen2Battle.PLAYER).at(0).hp, party_before)

	host.finish()
	host.advance()
	host.finish()
	host.advance()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_null(_battle_host(), "the overlay stayed open after the run")
	var world: Dictionary = _world_screen.world_snapshot()
	assert_eq(world["map"], Vector2i(Fixture.MAP_GROUP, Fixture.MAP_NUMBER))


## A trainer battle answers the same request with its own refusal, and the
## overlay stays open with both sides where they were: `BattleMenu_Run` reopens
## the menu rather than spending the turn.
func test_a_trainer_battle_refuses_the_run_and_the_overlay_stays_open() -> void:
	await _open_world()
	await _trigger_trainer()
	var host: Gen2BattleScreen = _battle_host()
	assert_not_null(host)
	var enemy_before: int = host._battle.mon(Gen2Battle.ENEMY).hp
	var player_before: int = host._battle.mon(Gen2Battle.PLAYER).hp

	host.run_from_battle()

	assert_false(host._battle.has_fled())
	assert_false(host._battle.is_over())
	assert_eq(
		host.battle_snapshot()["message"],
		"No! There's no running from a trainer battle!"
	)
	assert_eq(host._battle.mon(Gen2Battle.ENEMY).hp, enemy_before)
	assert_eq(host._battle.mon(Gen2Battle.PLAYER).hp, player_before, "the turn was spent")
	assert_not_null(_battle_host())


## `PlayBattleMusic` runs inside `FindFirstAliveMonAndStartBattle`, so the track
## is chosen where the fight starts rather than by whatever opened it. The
## fixture's trainer is class 1, FALKNER, on a Johto landmark.
func test_a_trainer_battle_opens_on_the_track_its_class_names() -> void:
	await _open_world()
	await _trigger_trainer()
	var host: Gen2BattleScreen = _battle_host()
	assert_not_null(host)
	assert_eq(host.battle_music(), Gen2Battle.MUSIC_JOHTO_GYM_LEADER_BATTLE)
	assert_false(
		Gen2Battle.region_is_kanto(_world_screen._world.landmark()),
		"the fixture map is in Johto"
	)


## `PlayBattleMusic` runs on frame 791 of the cartridge trace and
## `DoBattleTransition` on 793, so the fight's own track is chosen and started
## before the animation rather than 170 frames after it. The two screens share
## one driver, the way the cartridge has one APU, and both read the one request,
## so the battle screen asks for a piece already playing and the driver continues
## it instead of restarting it.
func test_the_battle_track_is_chosen_before_the_transition_on_one_driver() -> void:
	await _open_world()
	await _walk_one(Vector2i.RIGHT)
	for _frame: int in 400:
		_world_screen.advance_frame()
		if _world_screen.battle_transition_running():
			break
		var waiting: Dictionary = _world_screen._world.pending_script_input()
		if StringName(waiting.get("type", &"")) in [&"text", &"button"]:
			_world_screen._advance_script_input()
	assert_true(_world_screen.battle_transition_running())
	var chosen: int = Gen2WorldBattleAdapter.music_for(
		_world_screen._battle_transition_request,
		_world_screen._world.landmark(),
		_world_screen.time_of_day,
		Gen2WorldState.is_crystal_profile(_world_screen._data)
	)
	assert_eq(chosen, Gen2Battle.MUSIC_JOHTO_GYM_LEADER_BATTLE)
	var driver: Gen2AudioPlayer = _world_screen._audio_player
	assert_not_null(driver)

	## The transition is already running, so the overlay is what the rest of its
	## frames build rather than another encounter.
	for _frame: int in 600:
		if _battle_child() != null:
			break
		_world_screen.advance_frame()
	await get_tree().process_frame
	var host: Gen2BattleScreen = _battle_child()
	assert_not_null(host)
	assert_same(host._audio_player, driver, "one driver, the way there is one APU")
	assert_eq(host.battle_music(), chosen, "and the same piece either side")
	## The driver is the world's child, so the fight leaving cannot take it.
	assert_eq(driver.get_parent(), _world_screen)


## `FindFirstAliveMonAndStartBattle` writes `wBattleMonLevel` from the first
## party member with HP left, and `wEnemyMonLevel` still holds the last battle's
## enemy because `ClearBattleRAM` runs behind the transition. Both are what
## `StartTrainerBattle_DetermineWhichAnimation` reads.
func test_the_transition_reads_the_first_alive_mon_and_the_last_enemy() -> void:
	await _open_world(true)
	var save: Gen2SaveData = _world_screen._injected_save
	while save.party.size() < 2:
		save.party.append(Gen2SaveMon.from_dict((save.party[0] as Gen2SaveMon).to_dict()))
	var lead: Gen2SaveMon = save.party[0]
	var second: Gen2SaveMon = save.party[1]
	lead.level = 50
	second.level = 5

	_world_screen._last_enemy_level = 0
	assert_eq(
		_world_screen._battle_lead_level(), 50, "the lead while it is still standing"
	)
	var request: Dictionary = {"values": {"level": 90, "trainer_class": 1}}
	var first: Gen2BattleTransition = _world_screen._build_battle_transition(request)
	assert_not_null(first)
	assert_eq(
		first.scene(), &"init",
		"nothing has been fought yet, so the enemy level compared against is zero"
	)
	assert_false(_stronger(first), "level 90 in the request never reaches the choice")

	## A fainted lead hands `wBattleMonLevel` to the next slot with HP.
	lead.hp = 0
	assert_eq(_world_screen._battle_lead_level(), 5, "the first alive one")

	_world_screen._on_battle_finished({
		"outcome": Gen2WorldBattleAdapter.OUTCOME_WON,
		"enemy": {"species": 1, "hp": 0, "dvs": 0, "level": 40},
	})
	assert_eq(_world_screen._last_enemy_level, 40, "`wEnemyMon` outlives the fight")
	assert_true(
		_stronger(_world_screen._build_battle_transition(request)),
		"5 + 3 is under the 40 the last battle left behind"
	)


## Which pair of animations a transition took: `TRANS_STRONGER_F` is bit 0 of
## `StartingPoints`' index, so the two stronger runs are rows 1 and 3.
func _stronger(transition: Gen2BattleTransition) -> bool:
	if transition == null:
		return false
	return transition._scene == Gen2BattleTransition.SCENES[1] \
		or transition._scene == Gen2BattleTransition.SCENES[3]


## `StartBattle`: `DoBattleTransition` owns every frame between the encounter
## resolving and the battle screen existing, and the map is what it draws over.
func test_a_battle_runs_its_transition_before_the_overlay_exists() -> void:
	await _open_world()
	await _walk_one(Vector2i.RIGHT)
	for _frame: int in 400:
		_world_screen.advance_frame()
		if _world_screen.battle_transition_running():
			break
		var waiting: Dictionary = _world_screen._world.pending_script_input()
		if StringName(waiting.get("type", &"")) in [&"text", &"button"]:
			_world_screen._advance_script_input()
	assert_true(
		_world_screen.battle_transition_running(),
		"the encounter is resolved and the transition is what is on screen"
	)
	var seen: bool = false
	var frames: int = 0
	while _world_screen.battle_transition_running() and frames < 600:
		frames += 1
		seen = seen or _world_screen._battle_transition.cells().count(
			Gen2BattleTransition.CELL_BLACK
		) > 0
		## Nothing is built until the last of its frames is spent.
		for child: Node in _world_screen.get_children():
			assert_false(child is Gen2BattleScreen, "no overlay while the transition runs")
		_world_screen.advance_frame()
	assert_true(seen, "the outro blacks the map out on the way")
	assert_gt(frames, Gen2BattleTransition.LEAD_FRAMES, "the flash and an outro")
	assert_not_null(_battle_child(), "and the battle behind it once it lands")


## `DoBattleTransition` owns every frame between the encounter and the overlay
## with the joypad unread. A press landing in one of them used to reach
## `script_input_waiting()` below it and cancel the request `startbattle` waits
## on, so the script died with `invalid_battle_outcome`: the fight still ran, and
## everything the trainer's script does after it -- its beaten flag, its text and
## a gym leader's badge -- never arrived. A player holding A through the approach
## is what does it.
func test_a_press_during_the_battle_transition_leaves_the_script_running() -> void:
	await _open_world()
	await _walk_one(Vector2i.RIGHT)
	for _frame: int in 400:
		_world_screen.advance_frame()
		if _world_screen.battle_transition_running():
			break
		var waiting: Dictionary = _world_screen._world.pending_script_input()
		if StringName(waiting.get("type", &"")) in [&"text", &"button"]:
			_world_screen._advance_script_input()
	assert_true(_world_screen.battle_transition_running(), "the transition is on screen")
	_world_screen.press_button(Gen2Button.A)
	assert_eq(
		_world_screen.world_snapshot()["script_prompt"], "Battle starting",
		"the press was swallowed rather than answering the script"
	)

	var host: Gen2BattleScreen = _battle_child()
	assert_not_null(host)
	for _hit: int in 12:
		host.hurt_enemy()
	host = _battle_host()
	host.finish()
	host.advance()
	host.finish()
	host.advance()
	await get_tree().process_frame
	var world: Dictionary = _world_screen.world_snapshot()
	assert_true(world["just_battled"])
	assert_eq(
		world["visible_objects"], 0,
		"the script ran on past the fight and set the trainer's beaten flag"
	)


## `ExitBattle`'s `predef EvolveAfterBattle`, which is the pass this screen runs
## on the overworld: the level evolution the fight paid for is presented, and
## the party row is only written when the animation has finished.
const EVOLVING_SPECIES: int = 155
const EVOLVED_SPECIES: int = 156
const EVOLVE_LEVEL: int = 5


func _write_level_evolution() -> void:
	var species: Array = RomCache.read_json(RomCache.species_path(Fixture.directory()))
	for raw: Dictionary in species:
		match int(raw.get("number", 0)):
			EVOLVING_SPECIES:
				raw["name"] = "CHIKORITA"
				raw["evolutions"] = [{
					"method": RomLayout.EVOLVE_LEVEL, "parameter": EVOLVE_LEVEL,
					"condition": 0, "target": EVOLVED_SPECIES,
				}]
			EVOLVED_SPECIES:
				raw["name"] = "BAYLEEF"
	RomCache.write_json(RomCache.species_path(Fixture.directory()), species)
	_data = GameData.open_directory(Fixture.directory())


## Runs the open evolution screen to its end, pressing A for every page it waits
## on, the way the overworld's own pump and funnel do.
func _settle_evolution(cancel: bool = false) -> void:
	for _frame: int in 4000:
		if _world_screen.get("_evolution_host") == null:
			## `queue_free` lands at the end of the frame, so the screen is only
			## gone once one has passed; without this the run reports it orphaned.
			await get_tree().process_frame
			return
		_world_screen.advance_frame()
		var screen: Gen2EvolutionScreen = _world_screen.get("_evolution_host")
		if screen == null:
			await get_tree().process_frame
			return
		if cancel and screen.phase() == Gen2EvolutionScreen.Phase.FLASH:
			_world_screen.press_button(Gen2Button.B)
		elif screen.awaiting_press():
			_world_screen.press_button(Gen2Button.A)
	fail_test("the evolution screen never closed")


func test_a_level_evolution_is_presented_after_the_battle_and_then_applied() -> void:
	_write_level_evolution()
	await _open_world(true)
	var save: Gen2SaveData = _world_screen._injected_save
	save.party[0].species = EVOLVING_SPECIES
	save.party[0].nickname = "CHIKORITA"
	save.party[0].level = EVOLVE_LEVEL

	_world_screen.preview_level_evolution()
	var screen: Gen2EvolutionScreen = _world_screen.get("_evolution_host")
	assert_not_null(screen, "the pass opened its screen")
	assert_eq(screen.remaining(), 1)
	assert_eq(save.party[0].species, EVOLVING_SPECIES, "nothing is written before the animation")

	await _settle_evolution()
	assert_null(_world_screen.get("_evolution_host"), "and it closes on its own")
	assert_eq(save.party[0].species, EVOLVED_SPECIES)
	assert_eq(save.party[0].nickname, "BAYLEEF", "UpdateSpeciesNameIfNotNicknamed")
	assert_true(_world_screen._world.state.has_caught_species(EVOLVED_SPECIES),
		"SetSeenAndCaughtMon")


## `.WaitFrames_CheckPressedB` sets `wEvolutionCanceled` and `.proceed`'s
## `jp c, CancelEvolution` prints `StoppedEvolvingText` instead of writing the
## new species. The flash loop is the only place B is read, which is why the
## press waits for that phase rather than landing on the first frame.
func test_b_during_the_flash_cancels_the_evolution_and_says_so() -> void:
	_write_level_evolution()
	await _open_world(true)
	var save: Gen2SaveData = _world_screen._injected_save
	save.party[0].species = EVOLVING_SPECIES
	save.party[0].nickname = "CHIKORITA"
	save.party[0].level = EVOLVE_LEVEL

	_world_screen.preview_level_evolution()
	await _settle_evolution(true)

	assert_eq(save.party[0].species, EVOLVING_SPECIES, "the species is unchanged")
	assert_eq(save.party[0].nickname, "CHIKORITA")
	assert_false(_world_screen._world.state.has_caught_species(EVOLVED_SPECIES))


## Runs the open hatch screen to its end, pressing A for every page and box it
## waits on, the way the overworld's own pump and funnel do.
func _settle_hatch(nickname: bool = false) -> void:
	for _frame: int in 4000:
		var screen: Gen2EggHatchScreen = _world_screen.get("_hatch_host")
		if screen == null:
			await get_tree().process_frame
			return
		_world_screen.advance_frame()
		screen = _world_screen.get("_hatch_host")
		if screen == null:
			await get_tree().process_frame
			return
		if screen.phase() == Gen2EggHatchScreen.Phase.NAMING:
			var model: Gen2NamingScreen = screen.naming_screen().model()
			if model.length == 0:
				_world_screen.press_button(Gen2Button.A)
			else:
				## END, which is `NamingScreen_StoreEntry`.
				model.column = Gen2NamingScreen.LAST_COLUMN
				model.row = model.command_row()
				_world_screen.press_button(Gen2Button.A)
			continue
		if screen.phase() == Gen2EggHatchScreen.Phase.ASK_NICKNAME and not nickname:
			_world_screen.press_button(Gen2Button.B)
			continue
		if screen.awaiting_press():
			_world_screen.press_button(Gen2Button.A)
	fail_test("the hatch screen never closed")


## `HatchEggs` has already written the row when the sequence opens, so the
## screen is presentation and the nickname alone. `.nonickname` keeps the
## species name `GetPokemonName` put there.
func test_an_egg_hatches_into_the_species_it_was_carrying() -> void:
	await _open_world(true)
	var save: Gen2SaveData = _world_screen._injected_save
	_world_screen.preview_egg_hatch()
	save = _world_screen._injected_save
	var screen: Gen2EggHatchScreen = _world_screen.get("_hatch_host")
	assert_not_null(screen, "the pass opened its screen")
	assert_false(save.party[0].is_egg, "the row is written before the sequence")
	assert_true(save.party[0].hp > 0)
	assert_eq(" ".join(screen.text_lines()).strip_edges(), "Huh?",
		"`Text_BreedHuh` is printed over the map before anything is cleared")
	assert_true(screen.awaiting_press(), "its `para` waits for a press")
	var species_name: String = String(
		_data.species(save.party[0].species).get("name", "")
	)
	for _frame: int in 4000:
		if screen.phase() == Gen2EggHatchScreen.Phase.HATCHED:
			break
		_world_screen.advance_frame()
		if screen.awaiting_press():
			_world_screen.press_button(Gen2Button.A)
	assert_eq(
		" ".join(screen.text_lines()),
		Gen2WorldPartyHost.hatch_text(species_name).replace("\n", " ")
	)

	await _settle_hatch()
	assert_null(_world_screen.get("_hatch_host"), "and it closes on its own")
	assert_eq(
		save.party[0].nickname,
		String(_data.species(save.party[0].species).get("name", "")),
		"NO keeps the species name"
	)
	assert_true(_world_screen._world.state.has_caught_species(save.party[0].species))


## YES reaches `NamingScreen` under NAME_MON, and what it stores is the row's
## nickname. An empty entry keeps the species name, which is `InitName`.
func test_yes_opens_the_naming_screen_and_its_entry_becomes_the_nickname() -> void:
	await _open_world(true)
	_world_screen.preview_egg_hatch()
	var save: Gen2SaveData = _world_screen._injected_save
	var screen: Gen2EggHatchScreen = _world_screen.get("_hatch_host")
	for _frame: int in 4000:
		if screen.phase() == Gen2EggHatchScreen.Phase.ASK_NICKNAME:
			break
		_world_screen.advance_frame()
		if screen.awaiting_press():
			_world_screen.press_button(Gen2Button.A)
	assert_eq(screen.nickname_cursor(), 0, "YesNoBox opens on YES")
	## `YesNoBox` stands behind `PrintText` returning, so the menu is not up
	## while the question is still printing and A spends the text instead.
	for _frame: int in 600:
		if screen._menu.visible:
			break
		_world_screen.advance_frame()
	_world_screen.press_button(Gen2Button.A)
	assert_eq(screen.phase(), Gen2EggHatchScreen.Phase.NAMING)
	var model: Gen2NamingScreen = screen.naming_screen().model()
	assert_eq(model.max_length, Gen2NamingScreen.MON_MAX_LENGTH)
	model.press_a()
	model.column = Gen2NamingScreen.LAST_COLUMN
	model.row = model.command_row()
	_world_screen.press_button(Gen2Button.A)

	await _settle_hatch()
	assert_null(_world_screen.get("_hatch_host"))
	assert_eq(save.party[0].nickname.length(), 1, "the one letter that was entered")


## `givepoke SPECIES, 5` on the cell the player spawns on, so the coord event
## the fixture already carries runs `GivePoke` when the script is dispatched.
func _write_givepoke_script() -> void:
	var directory: String = Fixture.directory()
	var scripts: Dictionary = RomCache.read_json(RomCache.world_scripts_path(directory))
	scripts[Gen2WorldScript.pointer_key(Fixture.BANK, Fixture.TUTORIAL_SCRIPT)] = [
		Gen2WorldScript.GIVEPOKE, Fixture.TRAINER_SPECIES, 5, 0, 0,
		Gen2WorldScript.END,
	]
	RomCache.write_json(RomCache.world_scripts_path(directory), scripts)
	_data = GameData.open_directory(directory)


func _run_givepoke() -> Gen2NicknamePromptScreen:
	_world_screen._show_script_results(
		_world_screen._world.dispatch_script_events(Vector2i(4, 5))
	)
	return _world_screen.get("_nickname_host")


## Spends whatever the box still owes and presses past each page it ends on,
## which is what `PrintText` returning costs: `_CaughtAskNicknameText`'s own
## `cont` is a press, and `YesNoBox` opens only behind the last of them.
func _settle_nickname_text() -> void:
	for _frame: int in 600:
		var host: Gen2NicknamePromptScreen = _world_screen.get("_nickname_host")
		if host == null:
			return
		if not host._text_box.is_revealing():
			if not host._text_box.has_pages_left():
				break
			_world_screen.press_button(Gen2Button.A)
		_world_screen.advance_frame()
	_world_screen.advance_frame()


## `GivePoke`'s `.wildmon` branch, which is the thirteen `givepoke` sites that
## name no OT: every starter among them. NO is `.skip_nickname`, which keeps the
## species name `GetPokemonName` left in the row.
func test_a_gift_asks_for_a_nickname_and_no_keeps_the_species_name() -> void:
	_write_givepoke_script()
	await _open_world(true)
	var save: Gen2SaveData = _world_screen._injected_save
	var before: int = save.party.size()
	var host: Gen2NicknamePromptScreen = _run_givepoke()
	assert_not_null(host, "`GiveANickname_YesNo` is drawn")
	assert_eq(save.party.size(), before, "and nothing is written while it stands")
	var species_name: String = String(
		_data.species(Fixture.TRAINER_SPECIES).get("name", "")
	)
	_settle_nickname_text()
	## `cont` scrolls by one line rather than clearing the box, so the answer's
	## page opens on the line above it rather than on an empty box.
	assert_eq(host.text_lines(), PackedStringArray([
		"Give a nickname to", "the %s you" % species_name,
		"the %s you" % species_name, "received?",
	]))
	assert_eq(host.nickname_cursor(), 0, "YesNoBox opens on YES")
	_world_screen.press_button(Gen2Button.B)
	assert_null(_world_screen.get("_nickname_host"), "and B closes it as NO")
	assert_eq(save.party.size(), before + 1, "the row is written behind the prompt")
	assert_eq(save.party[before].nickname, species_name)
	## `Gen2Screen.drop` is a `queue_free`, spent on a process frame this test
	## otherwise never runs.
	await get_tree().process_frame


## YES reaches `NamingScreen` under NAME_MON, and `InitNickname` writes what it
## stored into the row the request is about to make.
func test_a_gift_takes_the_name_the_keyboard_stored() -> void:
	_write_givepoke_script()
	await _open_world(true)
	var save: Gen2SaveData = _world_screen._injected_save
	var before: int = save.party.size()
	var host: Gen2NicknamePromptScreen = _run_givepoke()
	_settle_nickname_text()
	_world_screen.press_button(Gen2Button.A)
	assert_eq(host.phase(), Gen2NicknamePromptScreen.Phase.NAMING)
	var model: Gen2NamingScreen = host.naming_screen().model()
	assert_eq(model.max_length, Gen2NamingScreen.MON_MAX_LENGTH)
	model.press_a()
	model.column = Gen2NamingScreen.LAST_COLUMN
	model.row = model.command_row()
	_world_screen.press_button(Gen2Button.A)

	assert_null(_world_screen.get("_nickname_host"))
	assert_eq(save.party.size(), before + 1)
	assert_eq(save.party[before].nickname.length(), 1, "the one letter that was entered")
	await get_tree().process_frame


## `.failed`'s box branch: `WasSentToBillsPCText` is printed behind the nickname,
## and `.skip_nickname`'s own copy puts the species name back over whatever the
## keyboard stored.
func test_a_boxed_gift_prints_bills_pc_and_keeps_the_species_name() -> void:
	_write_givepoke_script()
	await _open_world(true)
	var save: Gen2SaveData = _world_screen._injected_save
	while save.party.size() < Gen2SaveData.MAX_PARTY:
		save.party.append(Gen2SaveMon.from_dict(save.party[0].to_dict()))
	var host: Gen2NicknamePromptScreen = _run_givepoke()
	_settle_nickname_text()
	_world_screen.press_button(Gen2Button.B)
	assert_eq(host.phase(), Gen2NicknamePromptScreen.Phase.AFTER_TEXT)
	_settle_nickname_text()
	var species_name: String = String(
		_data.species(Fixture.TRAINER_SPECIES).get("name", "")
	)
	assert_eq(
		" ".join(host.text_lines()),
		Gen2WorldPartyHost.sent_to_box_text(species_name).replace("\n", " ")
	)
	_world_screen.press_button(Gen2Button.A)
	assert_null(_world_screen.get("_nickname_host"))
	assert_eq(save.party.size(), Gen2SaveData.MAX_PARTY)
	assert_eq(save.boxes[0].slots[0].nickname, species_name)
	await get_tree().process_frame


## `.skip_nickname`'s tail runs `PrintText` before its own `CopyBytes`, so
## `_WasSentToBillsPCText` reads the `wStringBuffer1` `InitName` just filled with
## the typed name while the row it names is overwritten with the species. The
## line and the row disagree on the cartridge, and they disagree here.
func test_a_boxed_gift_names_the_typed_nickname_and_stores_the_species() -> void:
	_write_givepoke_script()
	await _open_world(true)
	var save: Gen2SaveData = _world_screen._injected_save
	while save.party.size() < Gen2SaveData.MAX_PARTY:
		save.party.append(Gen2SaveMon.from_dict(save.party[0].to_dict()))
	var host: Gen2NicknamePromptScreen = _run_givepoke()
	_settle_nickname_text()
	_world_screen.press_button(Gen2Button.A)
	var model: Gen2NamingScreen = host.naming_screen().model()
	model.press_a()
	model.column = Gen2NamingScreen.LAST_COLUMN
	model.row = model.command_row()
	_world_screen.press_button(Gen2Button.A)
	assert_eq(host.phase(), Gen2NicknamePromptScreen.Phase.AFTER_TEXT)
	_settle_nickname_text()
	var named: String = " ".join(host.text_lines()).split(" was")[0]
	assert_eq(named.length(), 1, "the line names what the keyboard stored")
	_world_screen.press_button(Gen2Button.A)
	assert_null(_world_screen.get("_nickname_host"))
	var species_name: String = String(
		_data.species(Fixture.TRAINER_SPECIES).get("name", "")
	)
	assert_eq(
		save.boxes[0].slots[0].nickname, species_name,
		"and the row behind it keeps the species, which is the cartridge's own bug"
	)
	await get_tree().process_frame


## `CountStep`'s `cp 4` and the `DoPoisonStep` behind it. Three steps are below
## the compare and the fourth is the pass, and a member the point does not
## finish keeps its status.
func test_the_fourth_step_takes_one_hp_off_a_poisoned_party_member() -> void:
	await _open_world(true)
	var save: Gen2SaveData = _world_screen._injected_save
	var mon: Gen2SaveMon = save.party[0]
	mon.is_egg = false
	mon.hp = 9
	mon.status = Gen2Status.POISON
	var state: Gen2WorldState = _world_screen._world.state
	for _step: int in 3:
		state.count_step()
		assert_false(_world_screen._spend_poison_steps(), "cp 4 has not been reached")
	assert_eq(mon.hp, 9)
	state.count_step()
	assert_false(_world_screen._spend_poison_steps(), "a survivor takes no turn")
	assert_eq(mon.hp, 8)
	assert_eq(state.poison_step_count(), 0, "the pass clears the counter")
	assert_eq(mon.status, Gen2Status.POISON, "a survivor keeps its status")


## `.Script_MonFaintedToPoison`: the fainted member's own line, and then
## `_WhitedOutText` because `CheckPlayerPartyForFitMon` answers zero. The press
## behind the last page is what runs `Script_Whiteout`.
func test_the_last_member_fainting_to_poison_opens_the_whiteout() -> void:
	await _open_world(true)
	var save: Gen2SaveData = _world_screen._injected_save
	var mon: Gen2SaveMon = save.party[0]
	mon.is_egg = false
	mon.hp = 1
	mon.status = Gen2Status.POISON
	var state: Gen2WorldState = _world_screen._world.state
	for _step: int in Gen2WorldState.POISON_STEP_PHASE:
		state.count_step()
	assert_true(_world_screen._spend_poison_steps(), "the pass takes the turn")
	## `.PlayPoisonSFX` floods the background and spends four frames before
	## `.Script_MonFaintedToPoison` reaches its own `opentext`.
	assert_false(_world_screen._field_move_text, "the flash comes first")
	_world_screen.advance_frames(Gen2WorldPalette.POISON_FLASH_FRAMES)
	assert_true(_world_screen._field_move_text, "the faint owns the box")
	assert_eq(mon.hp, 0)
	assert_eq(mon.status, Gen2Status.NONE, "the faint clears the status")
	assert_true(
		"".join(_world_screen._text_box.text_lines()).contains("fainted"),
		"_PoisonFaintText comes first"
	)
	_world_screen.press_button(Gen2Button.A)
	assert_true(
		"".join(_world_screen._text_box.text_lines()).contains("whited"),
		"_WhitedOutText stands behind it"
	)
	## `_WhitedOutText` carries a `para`, so its second page costs a press of its
	## own before the one that runs the script behind it.
	for _press: int in 200:
		if not _world_screen._field_move_text:
			break
		_world_screen.advance_frame()
		_world_screen.press_button(Gen2Button.A)
	assert_false(_world_screen._field_move_text, "and the last press runs it")
	assert_true(mon.hp > 0, "Script_Whiteout's own `special HealParty`")


## The Nuzlocke's own ending, on the same pass the whiteout above walks. A faint
## is a death, so the row leaves the party rather than being healed, and a party
## with nothing left is a wipe: the run is over rather than set back to a Center.
## `Gen2GameRuntime._activate_rules` installs a slot's own rules when the
## launcher chooses one, and nothing does when [method Gen2WorldScreen.set_save]
## injects one, so the world reads them off the save it opened. Without it a
## Nuzlocke slot played as the cartridge's own game: no death was permanent and
## no area was ever spent.
func test_the_world_plays_the_rules_the_save_it_opened_carries() -> void:
	Gen2Rules.install(null)
	await _open_world(true, 0, Gen2Rules.CHALLENGE_NUZLOCKE)
	assert_true(_world_screen._world.rules.is_nuzlocke(), "the world's own set")
	assert_true(
		Gen2Rules.active().is_nuzlocke(),
		"and the installed one every static reads"
	)


func test_a_nuzlocke_wipe_ends_the_run_instead_of_whiting_out() -> void:
	await _open_world(true, 0, Gen2Rules.CHALLENGE_NUZLOCKE)
	var save: Gen2SaveData = _world_screen._injected_save
	var mon: Gen2SaveMon = save.party[0]
	mon.is_egg = false
	mon.hp = 1
	mon.nickname = "CYNDER"
	mon.status = Gen2Status.POISON
	var state: Gen2WorldState = _world_screen._world.state
	for _step: int in Gen2WorldState.POISON_STEP_PHASE:
		state.count_step()

	assert_true(_world_screen._spend_poison_steps(), "the pass takes the turn")
	assert_true(save.party.is_empty(), "the faint took the row off the party")
	assert_eq((save.nuzlocke["graveyard"] as Array).size(), 1)
	assert_eq(String((save.nuzlocke["graveyard"] as Array)[0]["nickname"]), "CYNDER")
	_world_screen.advance_frames(Gen2WorldPalette.POISON_FLASH_FRAMES)
	var said: String = ""
	for _press: int in 200:
		said += "".join(_world_screen._text_box.text_lines())
		if not _world_screen._field_move_text:
			break
		_world_screen.advance_frame()
		_world_screen.press_button(Gen2Button.A)
	assert_true(said.contains("gone"), "the loss is said before the verdict")
	assert_true(said.contains("NUZLOCKE is over"), "and `_WhitedOutText` is replaced")
	assert_false(_world_screen._field_move_text, "the last press runs it")
	assert_true(Gen2Nuzlocke.run_over(save.nuzlocke), "the run is written off")
	assert_true(save.party.is_empty(), "nothing was healed back into it")


## Where a save-bound mod policy is registered from: the manifest `register()`
## was handed is the capability, so the host has to have discovered it.
const MOD_ROOT: String = "user://mod_tests_capture"


func _clear_mod_root() -> void:
	var directory: DirAccess = DirAccess.open("%s/qol" % MOD_ROOT)
	if directory != null:
		for file: String in directory.get_files():
			DirAccess.remove_absolute("%s/qol/%s" % [MOD_ROOT, file])
	DirAccess.remove_absolute("%s/qol" % MOD_ROOT)
	DirAccess.remove_absolute(MOD_ROOT)


func _register_catch_experience() -> void:
	var directory: String = "%s/qol" % MOD_ROOT
	DirAccess.make_dir_recursive_absolute(directory)
	var manifest: FileAccess = FileAccess.open("%s/mod.json" % directory, FileAccess.WRITE)
	manifest.store_string(JSON.stringify({
		"id": "qol", "name": "QoL", "version": "1.0.0",
		"api_version": Gen2ModManifest.API_VERSION, "entry": "mod.gd",
	}))
	manifest.close()
	var entry: FileAccess = FileAccess.open("%s/mod.gd" % directory, FileAccess.WRITE)
	entry.store_string("extends RefCounted\n\nfunc register(_host, _manifest) -> void:\n\tpass\n")
	entry.close()
	var host: Gen2ModHost = Gen2ModHost.instance()
	host.discover(MOD_ROOT)
	host.load_discovered()
	var policy := GDScript.new()
	policy.source_code = "extends RefCounted\nfunc awards_catch_experience() -> bool:\n\treturn true\n"
	policy.reload()
	assert_true(bool(
		host.register_catch_experience(host.manifests()[0], policy.new()).get("ok", false)
	))


## `PokeBallEffect` awards nothing; a registered policy makes the capture worth
## what the faint would have been, and spends the whole award between the Gotcha
## line and the nickname prompt so nothing is filed with a level up still owed.
func test_a_registered_policy_pays_a_capture_between_gotcha_and_the_nickname() -> void:
	_register_catch_experience()
	await _open_world(true)
	assert_true(bool(_world_screen._world.state.apply_changes(
		{}, {}, {"items": {Gen2WorldPartyHost.ITEM_MASTER_BALL: 1}}
	).get("ok", false)))
	_world_screen.preview_wild_encounter()
	await get_tree().process_frame
	await get_tree().process_frame

	var host: Gen2BattleScreen = _battle_host()
	assert_not_null(host)
	var fought: Gen2SaveData = host.get("_source_save")
	var before: int = (fought.party[0] as Gen2SaveMon).exp
	assert_true(host.begin_capture()["ok"])
	assert_true(host.select_capture_ball(1)["ok"])
	assert_true(host.throw_capture_ball()["ok"])
	_settle_frames(host)

	var caught: String = "Gotcha! %s was caught!" % _wild_name()
	var messages: Array = []
	## The award moves the EXP bar, and nothing behind a moving bar is shown, so
	## this spends the screen's own frames the way a player pending does.
	for _frame: int in 900:
		var line: String = String(host.battle_snapshot()["message"])
		if messages.is_empty() or messages.back() != line:
			messages.append(line)
		if host.get("_capture_nickname_host") != null:
			break
		if host.bars_animating() or host.frames_running():
			host.advance_hardware_frame()
			continue
		host.finish()
		host.advance()

	var gotcha_at: int = messages.find(caught)
	assert_gt(gotcha_at, -1, JSON.stringify(messages))
	var paid_at: int = -1
	for index: int in messages.size():
		if String(messages[index]).contains("EXP. Points!"):
			paid_at = index
			break
	assert_gt(paid_at, gotcha_at, "the award is spent after the Gotcha line")
	assert_not_null(host.get("_capture_nickname_host"), "and before the nickname prompt")

	_refuse_capture_nickname(host)
	await get_tree().process_frame
	assert_null(_battle_host())
	## The award landed on the party the battle owns, and the battle synced it
	## back before the world filed the catch.
	assert_gt((fought.party[0] as Gen2SaveMon).exp, before)


## With no policy registered the capture is the cartridge's: no experience line
## between the Gotcha and the nickname.
func test_a_capture_pays_nothing_with_no_policy_registered() -> void:
	await _open_world()
	assert_true(bool(_world_screen._world.state.apply_changes(
		{}, {}, {"items": {Gen2WorldPartyHost.ITEM_MASTER_BALL: 1}}
	).get("ok", false)))
	_world_screen.preview_wild_encounter()
	await get_tree().process_frame
	await get_tree().process_frame

	var host: Gen2BattleScreen = _battle_host()
	assert_true(host.begin_capture()["ok"])
	assert_true(host.select_capture_ball(1)["ok"])
	assert_true(host.throw_capture_ball()["ok"])
	_settle_frames(host)
	for _frame: int in 900:
		assert_false(
			String(host.battle_snapshot()["message"]).contains("EXP. Points!"),
			"nothing is paid"
		)
		if host.get("_capture_nickname_host") != null:
			break
		if host.bars_animating() or host.frames_running():
			host.advance_hardware_frame()
			continue
		host.finish()
		host.advance()
	assert_false(bool(host.get("_capture_experience_spent")))


## `NewDexDataText` and `NewPokedexEntry` behind `Text_GotchaMonWasCaught`: a
## species the dex has not caught yet says a line and opens its page, and the
## catch waits there. `CheckCaughtMon` and `CheckReceivedDex` are both read
## before the throw, because the throw is what registers the catch.
func test_a_first_catch_says_its_dex_line_and_asks_for_the_page() -> void:
	await _open_world()
	_world_screen._world.state.set_engine_flag(Gen2WorldState.ENGINE_POKEDEX, true)
	assert_true(bool(_world_screen._world.state.apply_changes(
		{}, {}, {"items": {Gen2WorldPartyHost.ITEM_MASTER_BALL: 1}}
	).get("ok", false)))
	_world_screen.preview_wild_encounter()
	await get_tree().process_frame
	await get_tree().process_frame

	var host: Gen2BattleScreen = _battle_host()
	assert_not_null(host)
	var asked: Array[int] = []
	host.dex_entry_requested.connect(func(species: int) -> void: asked.append(species))
	assert_false(bool(host.get("_enemy_caught_before")), "the dex has never had one")
	assert_true(host.begin_capture()["ok"])
	assert_true(host.select_capture_ball(
		host.available_capture_balls().find(Gen2WorldPartyHost.ITEM_MASTER_BALL)
	)["ok"])
	assert_true(host.throw_capture_ball()["ok"])
	_settle_frames(host)

	var said: Array[String] = []
	for _message: int in 12:
		var line: String = String(host.battle_snapshot()["message"])
		if said.is_empty() or said.back() != line:
			said.append(line)
		if not asked.is_empty():
			break
		host.finish()
		host.advance()
	var expected: String = Gen2BattleScreen.NEW_DEX_DATA_TEXT % _wild_name()
	assert_true(said.has(expected), JSON.stringify(said))
	assert_gt(said.find(expected), said.find("Gotcha! %s was caught!" % _wild_name()))
	assert_eq(asked.size(), 1, "and the page was asked for once")


## `NewPokedexEntry` stands in front of the fight that asked for it, so the B
## that closes the page has to reach the page. Routed to the battle, that press
## was swallowed by a fight already waiting on the page and neither ever moved:
## a first catch of a species froze with the entry on screen.
func test_the_new_dex_page_takes_the_press_that_closes_it() -> void:
	await _open_world()
	_world_screen._world.state.set_engine_flag(Gen2WorldState.ENGINE_POKEDEX, true)
	assert_true(bool(_world_screen._world.state.apply_changes(
		{}, {}, {"items": {Gen2WorldPartyHost.ITEM_MASTER_BALL: 1}}
	).get("ok", false)))
	_world_screen.preview_wild_encounter()
	await get_tree().process_frame
	await get_tree().process_frame

	var host: Gen2BattleScreen = _battle_host()
	assert_not_null(host)
	assert_true(host.begin_capture()["ok"])
	assert_true(host.select_capture_ball(
		host.available_capture_balls().find(Gen2WorldPartyHost.ITEM_MASTER_BALL)
	)["ok"])
	assert_true(host.throw_capture_ball()["ok"])
	_settle_frames(host)
	for _frame: int in 1200:
		if _world_screen.get("_pokedex_host") != null:
			break
		_world_screen.press_button(Gen2Button.A)
		_world_screen.advance_frame()
	var page: Gen2PokedexScreen = _world_screen.get("_pokedex_host")
	assert_not_null(page, "the page opened over the fight")
	assert_eq(
		page.get("_screen"), host.hardware_screen(),
		"and drew on the fight's own screen rather than under it"
	)

	## `NewPokedexEntry` is two `WaitPressAorB_BlinkCursor` waits either side of
	## page 2, so the first press turns the page and the second closes it.
	_world_screen.press_button(Gen2Button.B)
	assert_not_null(_world_screen.get("_pokedex_host"), "the first press is page 2")
	_world_screen.press_button(Gen2Button.B)
	assert_null(_world_screen.get("_pokedex_host"), "and the second took the page down")
	for _frame: int in 1200:
		if host.get("_capture_nickname_host") != null:
			break
		_world_screen.press_button(Gen2Button.A)
		_world_screen.advance_frame()
	assert_not_null(
		host.get("_capture_nickname_host"),
		"the catch runs on to `AskGiveNicknameText` behind the page"
	)
	await get_tree().process_frame


## A species already in the dex adds no data and opens no page.
func test_a_catch_of_a_known_species_says_no_dex_line() -> void:
	await _open_world()
	_world_screen._world.state.set_engine_flag(Gen2WorldState.ENGINE_POKEDEX, true)
	_world_screen._world.state.set_species_caught(Fixture.TRAINER_SPECIES)
	assert_true(bool(_world_screen._world.state.apply_changes(
		{}, {}, {"items": {Gen2WorldPartyHost.ITEM_MASTER_BALL: 1}}
	).get("ok", false)))
	_world_screen.preview_wild_encounter()
	await get_tree().process_frame
	await get_tree().process_frame

	var host: Gen2BattleScreen = _battle_host()
	assert_not_null(host)
	assert_true(bool(host.get("_enemy_caught_before")))
	assert_true(host.begin_capture()["ok"])
	assert_true(host.select_capture_ball(
		host.available_capture_balls().find(Gen2WorldPartyHost.ITEM_MASTER_BALL)
	)["ok"])
	assert_true(host.throw_capture_ball()["ok"])
	_settle_frames(host)
	for _message: int in 10:
		assert_false(
			String(host.battle_snapshot()["message"]).contains("was newly added"),
			"nothing is added to a dex that already has one",
		)
		if host.get("_capture_nickname_host") != null:
			break
		host.finish()
		host.advance()


## `UseBallInTrainerBattle` is jumped to before `PokeBallEffect` says anything:
## there is no ITEM USED line, the throw is drawn on
## `BattleAnim_ThrowPokeBall`'s own NO_ITEM branch, the refusal is two boxes
## rather than one, and `UseDisposableItem` spends the ball anyway.
func test_a_ball_thrown_at_a_trainer_is_blocked_drawn_and_spent() -> void:
	await _open_world()
	assert_true(bool(_world_screen._world.state.apply_changes(
		{}, {}, {"items": {Gen2WorldPartyHost.ITEM_POKE_BALL: 2}}
	).get("ok", false)))
	await _trigger_trainer()

	var host: Gen2BattleScreen = _battle_host()
	assert_not_null(host)
	host.set_battle_pack(
		[Gen2WorldPartyHost.ITEM_POKE_BALL], {Gen2WorldPartyHost.ITEM_POKE_BALL: 2}
	)
	assert_true(bool(host.open_battle_pack().get("ok", false)))
	var thrown: Dictionary = host.use_selected_pack_item()
	assert_eq(StringName(thrown.get("status", &"")), &"blocked", JSON.stringify(thrown))
	assert_true(host.animation_running(), "the throw is drawn before it is refused")
	assert_eq(
		int(host._anim_event["param"]), Gen2BattleScreen.ANIM_PARAM_NO_ITEM,
		"`anim_if_param_equal NO_ITEM`, the branch the trainer blocks it on",
	)
	assert_eq(
		_world_screen._world.state.item_quantity(Gen2WorldPartyHost.ITEM_POKE_BALL), 1,
		"`jr UseDisposableItem`: the ball is gone whatever the trainer did",
	)
	_settle_frames(host)

	var said: Array[String] = []
	for _message: int in 6:
		var line: String = String(host.battle_snapshot()["message"])
		if said.is_empty() or said.back() != line:
			said.append(line)
		host.finish()
		host.advance()
	assert_true(
		said.has(Gen2BattleScreen.BALL_BLOCKED_TEXT), JSON.stringify(said)
	)
	assert_true(said.has(Gen2BattleScreen.BALL_DONT_BE_A_THIEF_TEXT), JSON.stringify(said))


## `.UseItem` returns with no carry on a ball that did not land, so the enemy
## takes the turn the throw was paid with: `wItemEffectSucceeded` and
## `wBattlePlayerAction` are the same byte, and `_DoItemEffect` wrote
## BATTLEPLAYERACTION_USEITEM into it on the way in.
func test_a_ball_that_missed_costs_the_turn() -> void:
	await _open_world()
	_data.species(Fixture.TRAINER_SPECIES)["catch_rate"] = 1
	assert_true(bool(_world_screen._world.state.apply_changes(
		{}, {}, {"items": {Gen2WorldPartyHost.ITEM_POKE_BALL: 4}}
	).get("ok", false)))
	_world_screen._encounter_random.seed = 1
	_world_screen.preview_wild_encounter()
	await get_tree().process_frame
	await get_tree().process_frame

	var host: Gen2BattleScreen = _battle_host()
	assert_not_null(host)
	var battle: Gen2Battle = host.get("_battle")
	var before: int = battle.mon(Gen2Battle.PLAYER).hp
	assert_true(host.begin_capture()["ok"])
	assert_true(host.throw_capture_ball()["ok"])
	_settle_frames(host)
	for _message: int in 12:
		if battle.mon(Gen2Battle.PLAYER).hp < before:
			break
		if host.bars_animating() or host.frames_running():
			host.advance_hardware_frame()
			continue
		host.finish()
		host.advance()
	assert_lt(
		battle.mon(Gen2Battle.PLAYER).hp, before,
		"the enemy moved in the turn the ball was thrown in",
	)


## `PokeBallEffect` plays `ANIM_THROW_POKE_BALL` between the throw text and the
## result text, and that one script is the whole capture: the ball, the poof, the
## opponent going into it, the wobbles `anim_checkpokeball` counts out, and the
## click or the break free. Nothing played it here, so no renderer could draw a
## capture and the built-in one drew nothing either. This fixture ships no
## animation layer, so what it can say is that the screen asks for the animation
## and spends its frames; what the script then draws is swept against real caches
## by `tools/checks/battle_anims.gd`.
func test_a_thrown_ball_asks_for_the_throw_animation() -> void:
	await _open_world()
	_data.species(Fixture.TRAINER_SPECIES)["catch_rate"] = 1
	_world_screen._encounter_random.seed = 1
	_world_screen.preview_wild_encounter()
	await get_tree().process_frame
	await get_tree().process_frame

	var host: Gen2BattleScreen = _battle_host()
	assert_not_null(host)
	assert_true(host.begin_capture()["ok"])
	assert_true(host.throw_capture_ball()["ok"])

	assert_true(host.animation_running(), "the throw is drawn, not only printed")
	assert_eq(int(host._anim_event["index"]), Gen2BattleScreen.ANIM_THROW_POKE_BALL)
	assert_eq(
		int(host._anim_event["param"]), Gen2WorldPartyHost.ITEM_POKE_BALL,
		"`.not_kurt_ball`: the ball the script is told to draw",
	)
	assert_false(
		bool(host._anim_event["enemy_turn"]),
		"`xor a / ldh [hBattleTurn]`: the throw is the player's",
	)
	# `GetPokeBallWobble` answers `next` for each shake and then `escaped`, which
	# is what `.Loop` branches on. The catch is decided before it is drawn.
	var answers: Array = host._anim_event["wobbles"]
	assert_eq(
		answers.back(), Gen2BattleAnimScript.WOBBLE_ESCAPED,
		"a Pokemon that got out is drawn getting out",
	)
	for step: int in answers.size() - 1:
		assert_eq(int(answers[step]), Gen2BattleAnimScript.WOBBLE_NEXT)

	_settle_frames(host)
	assert_false(host.animation_running(), "and its frames are spent")
