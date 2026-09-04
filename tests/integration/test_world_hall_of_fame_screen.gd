extends GutTest

## Scene integration for the Hall of Fame: the overlay `halloffame` opens, the
## pages it walks, the input it blocks while open, and the save it writes when
## it closes. Driven through the production world screen.

const Fixture := preload("res://tests/integration/world_trainer_fixture.gd")
const BattleFixture := preload("res://tests/unit/battle_fixture.gd")

const PLAYER_CELL: Vector2i = Vector2i(2, 2)

## `ProfOaksPCRating`'s two texts print into the player's panel, one box each at
## the fixture's short lengths.
const RATING_PAGES: int = 2

var _data: GameData = null
var _world_screen: Gen2WorldScreen = null


func before_each() -> void:
	Fixture.build()
	_data = GameData.open_directory(Fixture.directory())


func after_each() -> void:
	if is_instance_valid(_world_screen):
		_world_screen.free()
		_world_screen = null
	RomCache.clear(Fixture.directory())


func _open_world(party_size: int = 2) -> void:
	var packed: PackedScene = load("res://game/world/world_screen.tscn")
	_world_screen = packed.instantiate() as Gen2WorldScreen
	_world_screen.map_group = Fixture.MAP_GROUP
	_world_screen.map_number = Fixture.MAP_NUMBER
	_world_screen.start_cell = PLAYER_CELL
	var world: Gen2WorldAPI = Gen2WorldAPI.open(
		_data, Fixture.MAP_GROUP, Fixture.MAP_NUMBER, PLAYER_CELL, Gen2WorldState.new()
	)
	var save: Gen2SaveData = Gen2SaveStore.create_development_save(_data, 0)
	while save.party.size() > party_size:
		save.party.pop_back()
	save.world = world.snapshot()
	_world_screen.set_data(_data)
	_world_screen.set_save(save)
	add_child(_world_screen)
	await get_tree().process_frame


func _host() -> Gen2HallOfFameScreen:
	return _world_screen._hall_of_fame_host


func test_the_overlay_opens_with_one_page_per_party_member_and_the_player() -> void:
	await _open_world(2)
	_world_screen.open_hall_of_fame()
	await get_tree().process_frame
	assert_not_null(_host())
	## `InitDisplayForHallOfFame`'s record box stands in front of the panels and
	## moves on by itself after a hundred frames.
	assert_eq(_host().remaining(), 1 + 2 + RATING_PAGES)
	assert_eq(StringName(_host().current_page()["kind"]), Gen2HallOfFame.PAGE_SAVING)
	_spend_record_box()
	assert_eq(_host().remaining(), 2 + RATING_PAGES)
	assert_eq(StringName(_host().current_page()["kind"]), Gen2HallOfFame.PAGE_MON)


## The overlay hides the map, so the overworld must not move under it. This is
## the sixth overlay the world screen's guards have to know about.
func test_the_overworld_does_not_move_while_the_overlay_is_open() -> void:
	await _open_world(1)
	_world_screen.open_hall_of_fame()
	await get_tree().process_frame
	var before: Vector2i = _world_screen._world.player_cell
	assert_false(_world_screen.move_player(Vector2i.DOWN))
	assert_false(_world_screen.interact())
	assert_eq(_world_screen._world.player_cell, before)


func test_the_panels_time_out_and_the_last_page_closes_the_overlay() -> void:
	await _open_world(1)
	_world_screen.open_hall_of_fame()
	await get_tree().process_frame
	_spend_record_box()
	assert_eq(_host().remaining(), 1 + RATING_PAGES)

	## `.DisplayNewHallOfFamer` reads no joypad either: the panel stands for its
	## own `DelayFrames` and then moves on.
	assert_eq(StringName(_host().current_page()["kind"]), Gen2HallOfFame.PAGE_MON)
	_host().advance_hold_frames(Gen2HallOfFame.panel_frames(_data))
	assert_eq(StringName(_host().current_page()["kind"]), Gen2HallOfFame.PAGE_PLAYER)
	assert_eq(_host().remaining(), RATING_PAGES)

	_advance_to_the_end()
	await get_tree().process_frame
	assert_null(_world_screen._hall_of_fame_host)
	## `AnimateHallOfFame` is followed by `farcall Credits`, so the induction ends
	## into them rather than back onto the map.
	assert_not_null(_world_screen._credits_host)
	assert_false(_world_screen.move_player(Vector2i.DOWN))

	_world_screen._credits_host.close()
	await get_tree().process_frame
	assert_true(_world_screen.move_player(Vector2i.DOWN))


## `HOF_AnimatePlayerPic` slides the player's own front pic in beside the name
## box, so the panel behind the rating is not text alone.
func test_the_player_panel_draws_the_trainer_pic() -> void:
	await _open_world(1)
	_world_screen.open_hall_of_fame()
	await get_tree().process_frame
	_spend_record_box()
	_host().advance_hold_frames(Gen2HallOfFame.panel_frames(_data))
	assert_eq(StringName(_host().current_page()["kind"]), Gen2HallOfFame.PAGE_PLAYER)
	assert_not_null(_host()._pic.texture)
	assert_eq(
		_host()._pic.position.x,
		float(Gen2HallOfFamePage.player_pic_position().x),
		"PlaceGraphic at hlcoord 12, 5"
	)


## An induction's panels read no joypad at all, so neither A nor B moves one on.
func test_no_key_advances_an_induction_panel() -> void:
	await _open_world(2)
	_world_screen.open_hall_of_fame()
	await get_tree().process_frame
	_spend_record_box()
	var before: int = _host().remaining()
	assert_true(_host().handle_button(PokeButton.B))
	assert_true(_host().handle_button(PokeButton.A))
	assert_eq(_host().remaining(), before)


## HallOfFame calls SaveGameData around the induction. The screen's save is
## injected here, so the write lands in memory and the world snapshot is the
## one the overlay closed on.
func test_closing_the_overlay_writes_the_world_snapshot() -> void:
	await _open_world(1)
	var save: Gen2SaveData = _world_screen._injected_save
	save.world = null
	_world_screen.open_hall_of_fame()
	await get_tree().process_frame
	_advance_to_the_end()
	await get_tree().process_frame
	assert_null(_world_screen._hall_of_fame_host)
	assert_not_null(save.world)


## `halloffame` is an event, not a runtime request: it commits its own flag and
## the script runs on to `end`, so the overlay opens off the drained results.
func test_the_halloffame_command_opens_the_overlay() -> void:
	await _open_world(1)
	var directory: String = Fixture.directory()
	var scripts: Dictionary = RomCache.read_json(RomCache.world_scripts_path(directory))
	# Raw Crystal bytes: halloffame is source $9f.
	scripts["%d:7000" % Fixture.BANK] = [0xA1, Gen2WorldScript.END]
	RomCache.write_json(RomCache.world_scripts_path(directory), scripts)
	_data = GameData.open_directory(directory)

	# The fixture's own coord event, repointed at the halloffame script and
	# stepped onto the way the overworld reaches one.
	var world: Gen2WorldAPI = _world_screen._world
	world.data = _data
	world.current_map.events["coord_events"][0]["script"] = 0x7000
	var cell := Vector2i(
		int(world.current_map.events["coord_events"][0]["x"]),
		int(world.current_map.events["coord_events"][0]["y"])
	)
	world.player_cell = cell
	_world_screen._show_script_results(world.dispatch_script_events())
	await get_tree().process_frame

	assert_true(world.state.hall_of_fame())
	assert_not_null(_world_screen._hall_of_fame_host)


## An induction reads no joypad until the player's own panel, so every page in
## front of that one is spent as frames and the rating boxes as presses.
func _advance_to_the_end() -> void:
	while _world_screen._hall_of_fame_host != null:
		match StringName(_host().current_page().get("kind", &"")):
			Gen2HallOfFame.PAGE_SAVING:
				_host().advance_hold_frames(Gen2SavePrompt.SAVING_RECORD_FRAMES)
			Gen2HallOfFame.PAGE_MON:
				_host().advance_hold_frames(Gen2HallOfFame.panel_frames(_data))
			_:
				_host().handle_button(PokeButton.A)


## `HallOfFame_FadeOutMusic`'s `ld c, 100` behind `InitDisplayForHallOfFame`.
func _spend_record_box() -> void:
	assert_eq(
		StringName(_host().current_page()["kind"]), Gen2HallOfFame.PAGE_SAVING
	)
	var before: int = _host().remaining()
	assert_true(_host().handle_button(PokeButton.A), "the box reads no joypad")
	assert_eq(_host().remaining(), before, "and does not advance on one")
	_host().advance_hold_frames(Gen2SavePrompt.SAVING_RECORD_FRAMES)
