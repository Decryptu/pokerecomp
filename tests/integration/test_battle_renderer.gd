extends GutTest

## Scene integration for battle presentation through Gen2ModHost. The cache is
## synthetic, but the battle screen, the mod host and the built-in renderer are
## the production paths.

const Fixture := preload("res://tests/integration/world_trainer_fixture.gd")

var _data: GameData = null
var _battle_screen: Gen2BattleScreen = null
var _caught: Array[Dictionary] = []


func before_each() -> void:
	_caught = []
	_forget_view()
	Gen2ModHost.reset()
	_data = Fixture.build()
	_data = GameData.open_directory(Fixture.directory())


func after_each() -> void:
	if is_instance_valid(_battle_screen):
		_battle_screen.free()
		_battle_screen = null
	RomCache.clear(Fixture.directory())
	Gen2ModHost.reset()
	_forget_view()


## Choosing a view writes the installation's own file, so a test that chooses one
## puts it back rather than leaving the player on a renderer a test registered.
func _forget_view() -> void:
	DirAccess.remove_absolute(Gen2ModState.PATH)
	Gen2ModState.reload()


func _open_battle() -> void:
	var packed: PackedScene = load("res://game/battle/battle_screen.tscn")
	_battle_screen = packed.instantiate() as Gen2BattleScreen
	_battle_screen.set_data(_data)
	add_child(_battle_screen)
	await get_tree().process_frame


## `BattleIntroSlidingPics` runs before `BattleStartMessage`, so a battle says
## and does nothing until the pics are in place. In play the screen's own frames
## spend that; a test driving events without it would drive them into the slide.
func _settle_slide() -> void:
	var guard: int = 4000
	while _battle_screen.intro_running() and guard > 0:
		_battle_screen.advance_frame()
		guard -= 1


## The slide and the entrance behind it, which together are what `DoBattle`
## spends before its first menu: a test feeding its own events starts there.
func _settle_intro() -> void:
	var guard: int = 8000
	while (_battle_screen.frames_running() or _battle_screen.entrance_running()) \
		and guard > 0:
		guard -= 1
		_battle_screen.advance_frame()
		if _battle_screen.frames_running() or not _battle_screen.entrance_running():
			continue
		_battle_screen.finish()
		_battle_screen.advance()


func _stub_script(body: String) -> GDScript:
	var script := GDScript.new()
	script.source_code = body
	script.reload()
	return script


func test_the_built_in_renderer_draws_the_matchup_and_reports_ready() -> void:
	await _open_battle()
	assert_true(_battle_screen.is_ready())
	assert_true(_battle_screen._renderer is Gen2BattleRenderer)
	_battle_screen.show_matchup(16, 155, 5, 5)
	assert_true(_battle_screen.battle_snapshot()["ready"])


func test_a_registered_stub_renderer_receives_battle_data_and_a_matching_view() -> void:
	var script: GDScript = _stub_script("""extends Control

var received_data: bool = false
var last_view: Dictionary = {}

func set_battle_data(_data) -> bool:
	received_data = true
	return true

func set_view(view: Dictionary) -> void:
	last_view = view

func refresh() -> void:
	pass
""")
	assert_true(Gen2ModHost.instance().register_battle_renderer(&"stub", script)["ok"])
	assert_true(Gen2ModHost.instance().select_view(&"stub")["ok"])

	await _open_battle()
	assert_true(_battle_screen.is_ready())
	var renderer: Node = _battle_screen._renderer
	assert_true(bool(renderer.get("received_data")))

	_battle_screen.show_matchup(16, 155, 7, 9)
	_battle_screen.set_hp(10, 20, 3, 4)
	var view: Dictionary = renderer.get("last_view")
	assert_eq(int(view.get("enemy_level", -1)), 7)
	assert_eq(int(view.get("player_level", -1)), 9)
	assert_eq(int(view.get("enemy_hp", -1)), 10)
	assert_eq(int(view.get("enemy_max_hp", -1)), 20)
	assert_eq(int(view.get("player_hp", -1)), 3)
	assert_eq(int(view.get("player_max_hp", -1)), 4)


## Where the fight is happening, for a renderer that stages it on the map. It is
## optional on both sides: the screen only calls a renderer that defines it, and
## a battle started outside the world supplies none.
func test_a_registered_renderer_is_handed_the_world_the_battle_was_entered_from() -> void:
	var script: GDScript = _stub_script("""extends Control

var context = null

func set_battle_data(_data) -> bool:
	return true

func set_world_context(value) -> void:
	context = value

func set_view(_view: Dictionary) -> void:
	pass

func refresh() -> void:
	pass
""")
	assert_true(Gen2ModHost.instance().register_battle_renderer(&"staged", script)["ok"])
	assert_true(Gen2ModHost.instance().select_view(&"staged")["ok"])

	var world: Gen2WorldAPI = Gen2WorldAPI.open(_data, 1, 1, Vector2i(4, 4))
	world.player_facing = Gen2WorldSprite.FACING_LEFT
	var packed: PackedScene = load("res://game/battle/battle_screen.tscn")
	_battle_screen = packed.instantiate() as Gen2BattleScreen
	_battle_screen.set_data(_data)
	_battle_screen.set_world_context(
		Gen2BattleWorldContext.capture(world, Gen2WorldPalette.TIME_NIGHT)
	)
	add_child(_battle_screen)
	await get_tree().process_frame

	assert_true(_battle_screen.is_ready())
	var context: Gen2BattleWorldContext = _battle_screen._renderer.get("context")
	assert_not_null(context, "the renderer defines the method, so it is called")
	assert_eq(context.map_id, Vector2i(1, 1))
	assert_eq(context.player_cell, Vector2i(4, 4))
	assert_eq(context.player_facing, Gen2WorldSprite.FACING_LEFT)
	assert_eq(context.time_of_day, Gen2WorldPalette.TIME_NIGHT)


## The built-in renderer defines no such method and must still come up: the
## cartridge's battle is a white field and has no place in it.
func test_the_built_in_renderer_ignores_a_world_context() -> void:
	var world: Gen2WorldAPI = Gen2WorldAPI.open(_data, 1, 1, Vector2i(4, 4))
	var packed: PackedScene = load("res://game/battle/battle_screen.tscn")
	_battle_screen = packed.instantiate() as Gen2BattleScreen
	_battle_screen.set_data(_data)
	_battle_screen.set_world_context(Gen2BattleWorldContext.capture(world, 0))
	add_child(_battle_screen)
	await get_tree().process_frame

	assert_true(_battle_screen.is_ready())
	assert_false(_battle_screen._renderer.has_method("set_world_context"))
	assert_not_null(_battle_screen.world_context())


## The battle side of Gen2WorldScreen's own renderer-input seam. A Gen2Button is
## claimed by the screen before this and never arrives, so what a renderer is
## offered is the motion the screen has no opinion about.
func test_a_battle_renderer_is_offered_the_input_the_screen_did_not_claim() -> void:
	var script: GDScript = _stub_script("""extends Control

var seen: Array = []
var consume: bool = true

func set_battle_data(_data) -> bool:
	return true

func set_view(_view: Dictionary) -> void:
	pass

func refresh() -> void:
	pass

func handle_battle_input(event) -> bool:
	seen.append(event)
	return consume
""")
	assert_true(Gen2ModHost.instance().register_battle_renderer(&"steered", script)["ok"])
	assert_true(Gen2ModHost.instance().select_view(&"steered")["ok"])
	await _open_battle()
	assert_true(_battle_screen.is_ready())
	var renderer: Node = _battle_screen._renderer

	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(4.0, 0.0)
	_battle_screen._unhandled_input(motion)
	assert_eq((renderer.get("seen") as Array).size(), 1, "the renderer was not offered it")

	# A button belongs to whatever owns the screen, so it never reaches here.
	var press := InputEventAction.new()
	press.action = Gen2Button.ACTIONS[Gen2Button.A]
	press.pressed = true
	_battle_screen._unhandled_input(press)
	assert_eq((renderer.get("seen") as Array).size(), 1, "a button reached the renderer")

	# Ball selection is a modal state: it means something by itself, so the
	# renderer is not offered anything while it is up. Set directly rather than
	# through begin_capture(), which needs a whole hosted wild battle behind it
	# and would test that instead of this.
	_battle_screen._capture_selecting = true
	_battle_screen._unhandled_input(motion)
	assert_eq((renderer.get("seen") as Array).size(), 1, "a modal state let it through")
	_battle_screen._capture_selecting = false
	_battle_screen._unhandled_input(motion)
	assert_eq((renderer.get("seen") as Array).size(), 2, "and it stayed shut afterwards")


## A capture reaches the battle channel on the box that says `Gotcha!`, and a
## line a subscriber asks for from that handler is printed next, in front of the
## nickname prompt.
func test_a_capture_publishes_and_a_mod_line_lands_behind_it() -> void:
	await _open_battle()
	_battle_screen.show_matchup(16, 155, 5, 5)
	_settle_intro()
	var host: Gen2ModHost = Gen2ModHost.instance()
	host.subscribe(Gen2ModHost.CHANNEL_BATTLE, &"catcher", _on_caught_event)

	## Ball 0 is the one throw with no animation to spend, so what is being
	## measured is the order of the boxes and not the frames between them.
	## The throw that this result answers took the battle menu down.
	_battle_screen._menu_stage = &""
	_battle_screen._capture_waiting = true
	_battle_screen.complete_capture({
		"ok": true, "caught": true, "wobbles": 1, "ball": 0, "species": 16,
		"destination": {"ok": true, "destination": &"box"},
	})

	## `Text_GotchaMonWasCaught` is the whole of what a caught throw says: the
	## rocking is the animation, and nothing is published before the line.
	assert_eq(_caught.size(), 0, "published before the line that says why")
	_battle_screen._show_next_capture_message()
	assert_string_contains(String(_battle_screen.battle_snapshot()["message"]), "Gotcha!")
	assert_eq(_caught.size(), 1)
	assert_eq(int(_caught[0]["species"]), 16)
	assert_eq(StringName(_caught[0]["destination"]), &"box")
	assert_false(bool(_caught[0]["tutorial"]))
	assert_false(bool(_caught[0]["contest"]))

	## The press that took the Gotcha line away, and what runs on from it: the
	## asked-for line rather than the naming.
	_battle_screen._message_awaits_press = false
	_battle_screen._continue_after_messages()
	assert_eq(String(_battle_screen.battle_snapshot()["message"]), "One for the DEX!")
	assert_null(_battle_screen._capture_nickname_host, "the prompt waited for it")


func _on_caught_event(event: Dictionary) -> void:
	if StringName(event.get("type", &"")) != Gen2Battle.CAUGHT:
		return
	_caught.append(event)
	Gen2ModHost.instance().request_battle_message(&"catcher", "One for the DEX!")


## A renderer that defines nothing keeps working, and one that answers false
## leaves the event where it was.
func test_a_battle_renderer_without_the_method_changes_nothing() -> void:
	await _open_battle()
	assert_false(_battle_screen._renderer.has_method("handle_battle_input"))
	var motion := InputEventMouseMotion.new()
	_battle_screen._unhandled_input(motion)
	assert_false(motion.is_echo(), "the built-in renderer must not crash on one")


## `view` says what is on the field; this says who it is against, which a
## renderer standing the opponent behind their Pokemon needs. A wild battle
## carries class 0, the way `wOtherTrainerClass` is zero there.
func test_the_view_names_the_trainer_the_battle_is_against() -> void:
	var script: GDScript = _stub_script("""extends Control

var last_view: Dictionary = {}

func set_battle_data(_data) -> bool:
	return true

func set_view(view: Dictionary) -> void:
	last_view = view

func refresh() -> void:
	pass
""")
	assert_true(Gen2ModHost.instance().register_battle_renderer(&"named", script)["ok"])
	assert_true(Gen2ModHost.instance().select_view(&"named")["ok"])
	await _open_battle()
	var renderer: Node = _battle_screen._renderer

	_battle_screen.show_matchup(16, 155, 5, 5)
	var wild: Dictionary = renderer.get("last_view")
	assert_eq(StringName(wild.get("battle_kind", &"")), &"wild")
	assert_eq(int(wild.get("trainer_class", -1)), 0)
	assert_eq(String(wild.get("trainer_name", "x")), "")

	_battle_screen.show_trainer(Fixture.TRAINER_CLASS, 0)
	var trainer: Dictionary = renderer.get("last_view")
	assert_eq(StringName(trainer.get("battle_kind", &"")), &"trainer")
	assert_eq(int(trainer.get("trainer_class", -1)), Fixture.TRAINER_CLASS)
	assert_eq(int(trainer.get("trainer_index", -1)), 0)
	assert_eq(
		String(trainer.get("trainer_name", "")),
		String(_data.trainer_party(Fixture.TRAINER_CLASS, 0).get("name", "")),
	)


func test_a_renderer_reporting_missing_data_leaves_the_screen_not_ready() -> void:
	var script: GDScript = _stub_script("""extends Control

func set_battle_data(_data) -> bool:
	return false

func set_view(_view: Dictionary) -> void:
	pass

func refresh() -> void:
	pass
""")
	assert_true(Gen2ModHost.instance().register_battle_renderer(&"broken_data", script)["ok"])
	assert_true(Gen2ModHost.instance().select_view(&"broken_data")["ok"])

	await _open_battle()
	assert_false(_battle_screen.is_ready())
	# Input must stay inert rather than crash on a renderer that never armed.
	_battle_screen._unhandled_input(InputEventKey.new())


func test_a_renderer_choosing_the_native_layer_lands_on_the_screens_native_layer() -> void:
	var script: GDScript = _stub_script("""extends Control

func set_battle_data(_data) -> bool:
	return true

func set_view(_view: Dictionary) -> void:
	pass

func refresh() -> void:
	pass

func uses_hardware_viewport() -> bool:
	return false
""")
	assert_true(Gen2ModHost.instance().register_battle_renderer(&"native", script)["ok"])
	assert_true(Gen2ModHost.instance().select_view(&"native")["ok"])

	await _open_battle()
	assert_true(_battle_screen.is_ready())
	# Hardware pixels live inside the SubViewport; a renderer that opted out of
	# that must not end up there.
	assert_false(_battle_screen._renderer.get_parent() is SubViewport)


## `NormalHit` runs `applydamage` before `criticaltext` and `supereffectivetext`,
## and `DoEnemyDamage` ends with `predef AnimateHPBar`, so the bar drains first
## and the line describing the hit waits for it.
func test_a_hit_drains_the_bar_before_it_says_what_the_hit_was() -> void:
	await _open_battle()
	_battle_screen.show_matchup(16, 155, 7, 9)
	_settle_intro()
	_battle_screen.set_hp(48, 48, 40, 40)

	_battle_screen._pending = [{
		"type": Gen2Battle.HIT, "side": Gen2Battle.PLAYER, "target": Gen2Battle.ENEMY,
		"hp": 24, "max_hp": 48, "critical": false,
		"effectiveness": RomLayout.MATCHUP_SUPER_EFFECTIVE,
	}]
	_battle_screen._show_next_event()

	assert_true(_battle_screen.bars_animating(), "the bar is still on its way down")
	assert_ne(
		_battle_screen.battle_snapshot()["message"], "It's super effective!",
		"and the line has not been printed yet"
	)
	assert_eq(int(_battle_screen.get("_enemy_hp")), 24, "the committed HP is already there")

	## A press during the animation is swallowed, the way AnimateHPBar's own
	## blocking loop swallows one.
	_battle_screen.advance()
	assert_true(_battle_screen.bars_animating())

	var guard: int = 4000
	while _battle_screen.bars_animating() and guard > 0:
		_battle_screen.advance_frame()
		guard -= 1
	assert_eq(_battle_screen.battle_snapshot()["message"], "It's super effective!")


## A Pokemon coming out gets its bar drawn rather than drained: the maximum
## moved under it, so it is not the same bar.
func test_a_new_pokemon_does_not_animate_its_bar_up() -> void:
	await _open_battle()
	_battle_screen.show_matchup(16, 155, 7, 9)
	_battle_screen.set_hp(10, 48, 40, 40)
	_battle_screen._apply_event({
		"type": Gen2Battle.SENT_OUT, "side": Gen2Battle.ENEMY,
		"species": 155, "level": 7, "hp": 30, "max_hp": 30,
	})
	assert_false(_battle_screen.bars_animating())


## `Text_MonGainedExpPoint` is printed before `call AnimateExpBar`, so the EXP.
## Points line leads its bar; `BattleText_StringBuffer1GrewToLevel` is printed
## inside `.LoopLevels` once that level's segment has reached the end of the bar,
## so the level line waits for it.
func test_experience_says_its_line_first_and_the_level_line_after_the_bar() -> void:
	await _open_battle()
	_battle_screen.show_matchup(16, 155, 7, 9)
	_settle_intro()

	var mon: Gen2BattleMon = _battle_screen._battle.player
	var rate: int = mon.growth_rate()
	var index: int = _battle_screen._battle.party(Gen2Battle.PLAYER).active
	mon.exp = Gen2Experience.total_exp_at(rate, mon.level)
	_battle_screen._refresh_exp_bar()
	assert_eq(int(_battle_screen.get("_exp")), 0, "the bar starts at the level's own threshold")

	# What `_give_experience_to` does to the Pokemon before it describes it: an
	# award that carries it over the next level.
	var award: int = Gen2Experience.total_exp_at(rate, mon.level + 1) - mon.exp + 4
	var grown: int = mon.level + 1
	mon.gain_exp(award)
	mon.level_up()

	_battle_screen._pending = [
		{
			"type": Gen2Battle.EXP_GAINED, "side": Gen2Battle.PLAYER, "index": index,
			"species": mon.species, "amount": award, "exp": mon.exp, "exp_share": false,
		},
		{
			"type": Gen2Battle.GREW_LEVEL, "side": Gen2Battle.PLAYER, "index": index,
			"species": mon.species, "old_level": grown - 1, "new_level": grown,
			"old_stats": {}, "new_stats": {},
		},
	]

	_battle_screen._show_next_event()
	assert_true(_battle_screen.bars_animating(), "the bar is filling")
	assert_string_contains(
		String(_battle_screen.battle_snapshot()["message"]), "EXP. Points",
		"and its own line is already on screen"
	)

	# A press during the fill is swallowed, the way AnimateExpBar's own blocking
	# loop swallows one.
	_battle_screen.advance()
	assert_true(_battle_screen.bars_animating())

	# The first segment ends at the end of the bar, where the level line is
	# printed and the walk stops for the button that dismisses it.
	var guard: int = 4000
	while not _battle_screen._exp_bar.paused() and guard > 0:
		_battle_screen.advance_frame()
		guard -= 1
	assert_gt(guard, 0, "the bar reached the end of the level")
	assert_eq(
		_battle_screen._exp_bar.pixels(), Gen2ExpBarAnimation.LENGTH_PX,
		"and it is sitting there full"
	)
	assert_string_contains(
		String(_battle_screen.battle_snapshot()["message"]), "grew to level",
		"the level line waited for the bar to reach the end"
	)

	# The level line has to finish printing before a press can turn its page: a
	# press reaches nothing but `PrintLetterDelay` while a text is running.
	_battle_screen._box.finish()
	_battle_screen._box.advance()
	_battle_screen.advance()
	assert_false(_battle_screen._exp_bar.paused(), "the press let the next fill start")

	guard = 4000
	while _battle_screen.bars_animating() and guard > 0:
		_battle_screen.advance_frame()
		guard -= 1
	assert_gt(guard, 0, "the walk ended")
	assert_eq(
		int(_battle_screen.get("_exp")),
		Gen2ExpBarAnimation.pixels_for(rate, mon.level, mon.exp),
		"and the committed count caught up when it did"
	)


## `AnimateExpBar` returns before it touches the bar when the gainer is not the
## Pokemon on the field, which is every Exp. Share holder on the bench.
func test_a_benched_gainer_animates_no_bar() -> void:
	await _open_battle()
	_battle_screen.show_matchup(16, 155, 7, 9)
	var mon: Gen2BattleMon = _battle_screen._battle.player
	var benched: int = _battle_screen._battle.party(Gen2Battle.PLAYER).active + 1

	_battle_screen._apply_event({
		"type": Gen2Battle.EXP_GAINED, "side": Gen2Battle.PLAYER, "index": benched,
		"species": mon.species, "amount": 40, "exp": mon.exp, "exp_share": true,
	})
	assert_false(_battle_screen.bars_animating())


## `.skip_exp_bar_animation` draws its stats box once per award, after
## `.level_loop` has raised every level: two levels crossed is one box, showing
## what the walk finished on, and it lasts exactly as long as the line beside it.
func test_the_level_up_stats_box_stands_beside_the_last_level_line() -> void:
	await _open_battle()
	_battle_screen.show_matchup(16, 155, 7, 9)
	_settle_intro()

	var mon: Gen2BattleMon = _battle_screen._battle.player
	var benched: int = _battle_screen._battle.party(Gen2Battle.PLAYER).active + 1
	var middle: Dictionary = {"attack": 11, "defense": 12, "sp_attack": 13, "sp_defense": 14, "speed": 15}
	var settled: Dictionary = {"attack": 21, "defense": 22, "sp_attack": 23, "sp_defense": 24, "speed": 25}
	_battle_screen._pending = [
		{
			"type": Gen2Battle.GREW_LEVEL, "side": Gen2Battle.PLAYER, "index": benched,
			"species": mon.species, "old_level": 9, "new_level": 10,
			"old_stats": {}, "new_stats": middle,
		},
		{
			"type": Gen2Battle.GREW_LEVEL, "side": Gen2Battle.PLAYER, "index": benched,
			"species": mon.species, "old_level": 10, "new_level": 11,
			"old_stats": middle, "new_stats": settled,
		},
	]

	## The events are fed by hand, so the menu `_settle_intro` left open has to
	## come down the way a real turn takes it down before a press means "next
	## line" rather than "FIGHT".
	_battle_screen._close_battle_menu()

	_battle_screen._show_next_event()
	assert_eq(
		_battle_screen.battle_snapshot()["level_up_stats"], {},
		"the level in the middle of the walk draws no box"
	)

	_battle_screen._box.finish()
	_battle_screen._box.advance()
	_battle_screen.advance()
	assert_eq(
		_battle_screen.battle_snapshot()["level_up_stats"], settled,
		"the box goes up beside the last level's line, with the stats it settled on"
	)
	assert_true(_battle_screen._level_up_layer.visible, "and it is on screen")

	_battle_screen._box.finish()
	_battle_screen._box.advance()
	_battle_screen.advance()
	assert_eq(
		_battle_screen.battle_snapshot()["level_up_stats"], {},
		"and `SafeLoadTempTilemapToTilemap` takes it away with that line"
	)
	assert_false(_battle_screen._level_up_layer.visible)


## `InitBattleDisplay` runs `BattleIntroSlidingPics` and only then does
## `BattleStartMessage` say anything, so a battle opens on an empty box with the
## background sliding, and the player's back pic is not on the map at all until
## `PlaceGraphic` puts it there after the slide.
func test_a_battle_opens_on_the_slide_and_says_nothing_until_it_is_done() -> void:
	await _open_battle()
	_battle_screen.show_matchup(16, 155, 7, 9)
	_battle_screen.show_message("Wild PIDGEY appeared!")

	assert_true(_battle_screen.intro_running())
	assert_eq(String(_battle_screen.battle_snapshot()["message"]), "", "the box is empty")

	var view: Dictionary = _battle_screen._renderer._view
	## `CopyBackpic` puts the player's own picture on the map before
	## `InitBattleDisplay` ever reaches the slide, and its eighteen sprites carry
	## the rows `ClearBox` took off, so the player comes in from the right while
	## the opponent comes in from the left. Both are drawn without colour:
	## `SCGB_BATTLE_GRAYSCALE` is set where the battle is entered and
	## `SCGB_BATTLE_COLORS` only after the slide returns.
	var entering: Dictionary = view["battlers"]
	assert_gt(
		(entering["player"] as Dictionary)["offset_pixels"].x, 0.0,
		"the back pic slides in too, from the right"
	)
	assert_lt(
		(entering["enemy"] as Dictionary)["offset_pixels"].x, 0.0,
		"and the opponent from the left"
	)
	assert_true(bool(view["grayscale"]), "and the battle has no colour yet")
	assert_eq(
		(view["intro_sprites"] as Array).size(),
		Gen2BattleIntro.SPRITE_COLUMNS * Gen2BattleIntro.SPRITE_ROWS,
		"`.LoadTrainerBackpicAsOAM`'s own eighteen"
	)
	var offsets: PackedInt32Array = PackedInt32Array(view["raster_scx"])
	assert_eq(offsets.size(), Gen2Screen.HEIGHT)
	assert_ne(offsets[0], 0, "and the background is somewhere else entirely")

	# The slide is a run of unconditional `DelayFrame`s with nothing reading a
	# button, so a press does nothing at all.
	_battle_screen.advance()
	assert_true(_battle_screen.intro_running())

	_settle_slide()
	assert_eq(
		String(_battle_screen.battle_snapshot()["message"]), "Wild PIDGEY appeared!",
		"the start message waited for the slide"
	)
	var settled: Dictionary = _battle_screen._renderer._view
	var standing: Dictionary = settled["battlers"]
	assert_eq(
		(standing["player"] as Dictionary)["offset_pixels"], Vector2.ZERO,
		"both are on their squares once the slide has returned"
	)
	assert_eq((standing["enemy"] as Dictionary)["offset_pixels"], Vector2.ZERO)
	assert_false(bool(settled["grayscale"]), "`SCGB_BATTLE_COLORS` runs after the slide")
	assert_true((settled["intro_sprites"] as Array).is_empty(), "`HideSprites`")
	assert_true(PackedInt32Array(settled["raster_scx"]).is_empty(), "and nothing is scrolled")


## The text box is drawn into the background plane like everything else, so
## Gold and Silver's lead frame, which puts the whole screen at the starting
## offset, takes the box with it.
func test_the_text_box_is_scrolled_with_the_rest_of_the_background() -> void:
	await _open_battle()
	_battle_screen.show_matchup(16, 155, 7, 9)

	var box: Gen2TextBox = _battle_screen._box
	assert_eq(box.raster_scx.size(), box.rows * Gen2Font.TILE)
	var offsets: PackedInt32Array = PackedInt32Array(
		_battle_screen._renderer._view["raster_scx"]
	)
	var top: int = Gen2TextBox.STANDARD_TOP * Gen2Font.TILE
	assert_eq(box.raster_scx[0], offsets[top], "the box takes its own rows of the scroll")

	_settle_intro()
	assert_true(box.raster_scx.is_empty())


## `GetSubstitutePic`: the doll is four tiles of the monster overworld sprite in
## an otherwise empty box, at columns 2 and 3 of both boxes and one row higher in
## the player's. What it draws from a real cache is swept by
## `tools/checks/battle_anims.gd`; the placement is arithmetic and is pinned
## here, against a strip whose every pixel says which tile it came from.
func test_the_doll_takes_four_tiles_of_the_monster_sprite_into_a_blank_box() -> void:
	var strip: PackedByteArray = PackedByteArray()
	strip.resize(12 * Gen2Font.TILE * Gen2Font.TILE)
	for index: int in strip.size():
		strip[index] = 1 + (index % (12 * Gen2Font.TILE)) / Gen2Font.TILE

	for player_side: bool in [false, true]:
		var side: int = Gen2BattleScreenMap.PLAYER_SIDE if player_side \
			else Gen2BattleScreenMap.ENEMY_SIDE
		var box: int = side * Gen2Font.TILE
		var pixels: PackedByteArray = Gen2BattleRenderer.substitute_pixels(strip, player_side)
		assert_eq(pixels.size(), box * box)

		# The down-facing frame for the enemy's front picture, the up-facing one
		# for the player's back picture, laid out in reading order.
		var first: int = int(Gen2BattleRenderer.SUBSTITUTE_FIRST_TILE[player_side])
		var at: Vector2i = Gen2BattleRenderer.SUBSTITUTE_AT[player_side]
		var lit: int = 0
		for y: int in box:
			for x: int in box:
				var value: int = int(pixels[y * box + x])
				var cell: Vector2i = Vector2i(x, y) / Gen2Font.TILE - at
				if cell.x < 0 or cell.x > 1 or cell.y < 0 or cell.y > 1:
					assert_eq(value, 0, "outside the doll at %d,%d" % [x, y])
					continue
				lit += 1
				assert_eq(value, 1 + first + cell.y * 2 + cell.x, "tile at %d,%d" % [x, y])
		assert_eq(lit, 16 * 16)


func test_the_doll_is_what_a_substituted_side_draws() -> void:
	await _open_battle()
	_battle_screen.show_matchup(16, 155, 7, 9)
	_settle_intro()
	var renderer: Gen2BattleRenderer = _battle_screen._renderer
	var own: PackedByteArray = renderer._player_pixels.duplicate()

	_battle_screen._apply_event({
		"type": Gen2Battle.SUBSTITUTE_PIC, "side": Gen2Battle.PLAYER, "raised": true,
	})
	assert_ne(renderer._player_pixels, own, "the doll replaced the picture")
	assert_eq(
		renderer._player_pixels,
		Gen2BattleRenderer.substitute_pixels(
			_data.overworld_sprite_indices(Gen2BattleRenderer.SUBSTITUTE_SPRITE), true
		)
	)
	assert_eq(renderer._enemy_pixels_key[1], false, "and only that side's")

	_battle_screen._apply_event({
		"type": Gen2Battle.SUBSTITUTE_PIC, "side": Gen2Battle.PLAYER, "raised": false,
	})
	assert_eq(renderer._player_pixels, own)


## `GetBattleMonBackpic` tests `SUBSTATUS_SUBSTITUTE` before `wPlayerMinimized`,
## so a doll stands in front of the dot and the dot is what is underneath when
## the doll comes off. Nothing takes the dot off but a send-out.
func test_the_dot_is_what_a_minimized_side_draws_and_a_doll_stands_in_front_of_it() -> void:
	await _open_battle()
	_battle_screen.show_matchup(16, 155, 7, 9)
	_settle_intro()
	var renderer: Gen2BattleRenderer = _battle_screen._renderer
	var own: PackedByteArray = renderer._player_pixels.duplicate()
	var dot: PackedByteArray = Gen2BattleRenderer.minimize_pixels(
		_data.tile_indices("minimize"), true
	)

	_battle_screen._apply_event({
		"type": Gen2Battle.MINIMIZED, "side": Gen2Battle.PLAYER,
	})
	assert_ne(renderer._player_pixels, own, "the dot replaced the picture")
	assert_eq(renderer._player_pixels, dot)
	assert_eq(renderer._enemy_pixels_key[4], false, "and only that side's")

	_battle_screen._apply_event({
		"type": Gen2Battle.SUBSTITUTE_PIC, "side": Gen2Battle.PLAYER, "raised": true,
	})
	assert_eq(
		renderer._player_pixels,
		Gen2BattleRenderer.substitute_pixels(
			_data.overworld_sprite_indices(Gen2BattleRenderer.SUBSTITUTE_SPRITE), true
		),
		"the doll is in front"
	)
	_battle_screen._apply_event({
		"type": Gen2Battle.SUBSTITUTE_PIC, "side": Gen2Battle.PLAYER, "raised": false,
	})
	assert_eq(renderer._player_pixels, dot, "and the dot is underneath")


## `BattleCommand_Transform` copies the species and the DVs onto the actor, and
## every reload of the square after it draws the target: the Pokemon on the
## field is the one it copied, not the one that used the move.
func test_a_transformed_side_draws_the_species_it_copied() -> void:
	await _open_battle()
	_battle_screen.show_matchup(16, 155, 7, 9)
	_settle_intro()
	var renderer: Gen2BattleRenderer = _battle_screen._renderer
	assert_eq(int(renderer._player_pixels_key[0]), 155)

	_battle_screen._apply_event({
		"type": Gen2Battle.TRANSFORMED, "side": Gen2Battle.PLAYER, "target": Gen2Battle.ENEMY,
		"species": 16, "unown_form": 0, "shiny": true,
	})
	assert_eq(
		int(renderer._player_pixels_key[0]), 16, "the copied species is what is drawn"
	)
	assert_true(bool(renderer._view["player_shiny"]), "and the copied DVs are what shine")
	assert_false(bool(renderer._view["enemy_shiny"]), "the target's own square is untouched")

	# A send-out is the one thing that puts the user's own picture back.
	_battle_screen._apply_event({
		"type": Gen2Battle.SENT_OUT, "side": Gen2Battle.PLAYER, "species": 155,
		"level": 7, "hp": 20, "max_hp": 20,
	})
	assert_eq(int(renderer._player_pixels_key[0]), 155)
	assert_false(bool(renderer._view["player_shiny"]))


## The whole entrance as `view["battlers"]` reports it, one side at a time: who
## is standing on each square, and how far off it they are.
##
## This is the field a renderer with no background plane has instead of the
## scanline scroll and the blanking `bg_map` columns, so it is asserted as the
## sequence a fight actually opens with rather than at one sampled frame: two
## trainers slide in, each walks off its own square, and a Pokemon takes it.
##
## The two sides do not pass through the same states, and the reason is one line
## of the source. `ShowBattleTextEnemySentOut` waits on a press, so the
## opponent's square stands empty for as long as the player takes to read it;
## `SendOutMonText` "ends in `done`" and prints with the ball already in the air,
## so the player's square is never empty at the end of a frame. That also costs
## the player's walk its last step at a frame boundary: the ninth column shifts
## and the Pokemon is stamped in the same frame, so what a renderer is handed is
## the eighth, which is what every other field says at that frame too.
func test_the_entrance_says_who_is_on_each_square_and_how_far_off_it() -> void:
	await _open_battle()
	_battle_screen.show_trainer(Fixture.TRAINER_CLASS, 0)

	var kinds: Dictionary = {"player": [], "enemy": []}
	var lows: Dictionary = {"player": 0.0, "enemy": 0.0}
	var highs: Dictionary = {"player": 0.0, "enemy": 0.0}
	var guard: int = 8000
	while (_battle_screen.frames_running() or _battle_screen.entrance_running()) \
		and guard > 0:
		guard -= 1
		for who: String in kinds:
			var side: Dictionary = (
				_battle_screen._renderer._view["battlers"] as Dictionary
			)[who]
			var kind: StringName = StringName(side["kind"])
			if (kinds[who] as Array).is_empty() or (kinds[who] as Array).back() != kind:
				(kinds[who] as Array).append(kind)
			var at: float = (side["offset_pixels"] as Vector2).x
			lows[who] = minf(float(lows[who]), at)
			highs[who] = maxf(float(highs[who]), at)
		_battle_screen.advance_frame()
		if _battle_screen.frames_running() or not _battle_screen.entrance_running():
			continue
		_battle_screen.finish()
		_battle_screen.advance()
	assert_gt(guard, 0, "the entrance finished")

	assert_eq(
		kinds["enemy"], [&"trainer", &"none", &"mon"],
		"a person, then the square they left, then a Pokemon"
	)
	assert_eq(
		kinds["player"], [&"trainer", &"mon"],
		"the player's own empty square has no frame of its own"
	)
	# `SlideBattlePicOut` walks the player's square nine tiles to the left and
	# the opponent's eight to the right, and the opening slide brings each in
	# from the side it later leaves towards.
	var step: int = Gen2Tiles.TILE_WIDTH
	assert_eq(
		lows["player"], -float((int(Gen2BattleScreenMap.SLIDE_STEPS[true]) - 1) * step),
		"the player walks off to the left, all but the step it is replaced on"
	)
	assert_gt(float(highs["player"]), 0.0, "and slid in from the right")
	assert_eq(
		highs["enemy"], float(int(Gen2BattleScreenMap.SLIDE_STEPS[false]) * step),
		"the opponent walks the whole way off, to the right"
	)
	assert_lt(float(lows["enemy"]), 0.0, "and slid in from the left")

	# Nothing is moving once the fight has started, and both squares name the
	# Pokemon standing on them rather than the people who brought them.
	var fighting: Dictionary = _battle_screen._renderer._view["battlers"]
	for who: String in ["player", "enemy"]:
		var side: Dictionary = fighting[who]
		assert_eq(side["offset_pixels"], Vector2.ZERO, who)
		assert_eq(String(side["backpic"]), "", who)
		assert_eq(int(side["trainer_class"]), 0, who)
		assert_gt(int(side["species"]), 0, "%s: and it is a species" % who)


## A wild opponent is never a trainer: it slides in as its own front pic and
## stands on its square for the whole fight, while the player still arrives
## behind a back pic that walks off.
func test_a_wild_opponent_is_its_own_picture_from_the_first_frame() -> void:
	await _open_battle()
	_battle_screen.show_matchup(16, 155, 7, 9)

	var enemy: Dictionary = (
		_battle_screen._renderer._view["battlers"] as Dictionary
	)["enemy"]
	assert_eq(StringName(enemy["kind"]), &"mon")
	assert_eq(int(enemy["species"]), 16)
	assert_lt((enemy["offset_pixels"] as Vector2).x, 0.0, "and it is still sliding in")
	assert_eq(
		StringName((
			(_battle_screen._renderer._view["battlers"] as Dictionary)["player"]
			as Dictionary
		)["kind"]),
		&"trainer",
		"the player is a person at the same moment",
	)


## `anim_battlergfx_*` stands an object in for the picture's bottom rows, and it
## reads the same padded buffer the tilemap layer draws from. A Crystal front pic
## carries `AnimateFrontpic`'s frames in those same rows, so the buffer is wider
## than the box and the stride is its own: with the box's, every line of the
## object came from further along the line above it and the picture's feet were
## scrambled.
func test_a_battler_object_tile_is_read_over_the_pics_own_strip() -> void:
	await _open_battle()
	var renderer: Gen2BattleRenderer = _battle_screen._renderer
	var side: int = Gen2BattleScreenMap.ENEMY_SIDE
	var box: int = side * Gen2Font.TILE
	# Two animation columns behind the box, and every pixel says where it stands.
	var strip: int = box + 2 * Gen2Font.TILE
	var pixels: PackedByteArray = PackedByteArray()
	pixels.resize(box * strip)
	for y: int in box:
		for x: int in strip:
			pixels[y * strip + x] = (y * strip + x) & 0xFF
	renderer._enemy_pixels = pixels

	assert_eq(Gen2BattleRenderer.pic_stride(pixels, side), strip)
	# The picture's own bottom row, which is `.LoadFeet`'s first enemy tile.
	var tile: int = Gen2BattleScreenMap.ENEMY_BASE_TILE + side - 1
	var read: PackedByteArray = renderer._battler_tile(tile)
	assert_eq(read.size(), Gen2Font.TILE * Gen2Font.TILE)
	for line: int in Gen2Font.TILE:
		for column: int in Gen2Font.TILE:
			assert_eq(
				int(read[line * Gen2Font.TILE + column]),
				int(pixels[((side - 1) * Gen2Font.TILE + line) * strip + column]),
				"pixel %d,%d of the feet" % [column, line]
			)


## `MonFaintedAnimation` sinks a picture a tile row at a time inside `bg_map`,
## which a renderer with no background plane cannot read: seven of those steps
## and a slide off the square are the same columns and rows moving. The block
## says it as one number.
func test_a_faint_sinks_the_battlers_own_offset() -> void:
	await _open_battle()
	_battle_screen.show_matchup(16, 155, 7, 9)
	_settle_intro()

	var before: Vector2 = (
		(_battle_screen._renderer._view["battlers"] as Dictionary)["enemy"]
		as Dictionary
	)["offset_pixels"]
	assert_eq(before, Vector2.ZERO, "the opponent is standing on its square")

	_battle_screen._begin_faint(Gen2Battle.ENEMY)
	var steps: int = 0
	var deepest: float = 0.0
	var guard: int = 200
	while _battle_screen.fainting() and guard > 0:
		_battle_screen.advance_faint()
		guard -= 1
		steps += 1
		deepest = maxf(deepest, float((
			(_battle_screen._renderer._view["battlers"] as Dictionary)["enemy"]
			as Dictionary
		)["offset_pixels"].y))

	assert_gt(steps, 0, "the faint ran")
	assert_eq(
		deepest,
		float((Gen2BattleScreenMap.FAINT_STEPS - 1) * Gen2Tiles.TILE_HEIGHT),
		"the picture sank a tile row a step and never rose",
	)
	assert_eq(
		(
			(_battle_screen._renderer._view["battlers"] as Dictionary)["player"]
			as Dictionary
		)["offset_pixels"],
		Vector2.ZERO,
		"and the other side did not move",
	)


## `BattleBGEffect_HideMon` blanks a battler's own box and `..._RunPicResizeScript`
## restamps it out of smaller subsamplings of itself. Both are `bg_map` edits and
## nothing else, so `visible` and `scale` are the only way a card on a 3D stage
## can know a Fly user is gone or a recall is shrinking.
func test_hiding_and_resizing_a_battler_are_reported_plainly() -> void:
	await _open_battle()
	_battle_screen.show_matchup(16, 155, 7, 9)
	_settle_intro()
	var standing: Dictionary = (
		_battle_screen._renderer._view["battlers"] as Dictionary
	)["enemy"]
	assert_true(bool(standing["visible"]))
	assert_eq(standing["scale"], Vector2.ONE)

	var background := Gen2BattleAnimBackground.new()
	background.report_battler(false, false)
	assert_false(bool(background.battler_visible[false]))
	# `RESIZE_RETURN_ENEMY`'s smallest square is BGSQUARE_THREE against a whole
	# picture of seven, which is the last thing on the square before the clear
	# that ends the script.
	background.report_battler(false, true, 3.0 / 7.0)
	assert_true(bool(background.battler_visible[false]))
	assert_almost_eq(float(background.battler_scale[false]), 3.0 / 7.0, 0.001)
	assert_eq(
		float(background.battler_visible.size()), 2.0,
		"the report is one entry a side and no more",
	)


## Every per-battler deformation moves its picture through one scanline window
## over that side's own rows, which is `SetLCDStatCustoms`' `$2f`..`$5e` for the
## player and `$00`..`$36` for the opponent. A renderer with no background plane
## reads the window's mean instead, and the two sides must not read each other's.
func test_the_scanline_window_reports_the_side_it_is_open_over() -> void:
	var background := Gen2BattleAnimBackground.new()
	background.lcdc_pointer = Gen2BattleAnimBackground.LCDC_SCX
	background.ly_override_start = 0x2F
	background.ly_override_end = 0x5E
	# `Tackle_MoveForward`'s own eight pixels, as the signed byte the window
	# holds: the player lunges right, so the scroll is negative.
	background.fill_ly_backup(0xF8)
	background.push_ly_overrides()

	assert_eq(background.battler_window_offset(true), Vector2(8.0, 0.0))
	assert_eq(
		background.battler_window_offset(false), Vector2.ZERO,
		"the opponent is not in the player's window",
	)

	# `BattleBGEffect_Withdraw` pushes the top of the window off with `$90` and
	# holds the rest at the negated displacement, which reads as a sink.
	var sinking := Gen2BattleAnimBackground.new()
	sinking.lcdc_pointer = Gen2BattleAnimBackground.LCDC_SCY
	sinking.ly_override_start = 0x00
	sinking.ly_override_end = 0x36
	sinking.displace_ly_backup(4)
	sinking.push_ly_overrides()

	var sunk: Vector2 = sinking.battler_window_offset(false)
	assert_eq(sunk.x, 0.0, "a vertical window moves nothing sideways")
	assert_eq(sunk.y, 5.0, "the rows still on screen carry the whole push")
