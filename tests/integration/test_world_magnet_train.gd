extends GutTest

## Scene integration for `special MagnetTrain`, the line from the station
## officer's script to the map the script's own warp reaches afterwards.
##
## The two things a unit test cannot see are covered here: the ride owns the
## screen while it is up, and the script resumes on the frame it ends.
## [Gen2MagnetTrain]'s own counters are `tests/unit/test_magnet_train.gd` and the
## picture is `tools/checks/magnet_train.gd`.

const Fixture := preload("res://tests/integration/world_trainer_fixture.gd")

const PLAYER_CELL: Vector2i = Vector2i(2, 2)
const TALK_CELL: Vector2i = Vector2i(4, 5)
## `GoldenrodMagnetTrainStationOfficerScript`'s own tail: the direction, the
## special, and the flag standing in for the `warpcheck` behind it.
const ARRIVED_FLAG: int = 44

var _data: GameData = null
var _world_screen: Gen2WorldScreen = null


func before_each() -> void:
	Fixture.build()
	_write_ride_script()
	_data = GameData.open_directory(Fixture.directory())
	Gen2OptionsStore.use_test_path()
	DirAccess.remove_absolute(Gen2OptionsStore.path())


func after_each() -> void:
	await get_tree().process_frame
	if is_instance_valid(_world_screen):
		_world_screen.free()
		_world_screen = null
	RomCache.clear(Fixture.directory())


func _write_ride_script() -> void:
	var directory: String = Fixture.directory()
	var scripts: Dictionary = RomCache.read_json(RomCache.world_scripts_path(directory))
	scripts[Gen2WorldScript.pointer_key(Fixture.BANK, Fixture.TUTORIAL_SCRIPT)] = [
		Gen2WorldScript.SETVAL, 0x00,
		Gen2WorldScript.SPECIAL, Gen2WorldScriptRunner.SPECIAL_MAGNET_TRAIN, 0x00,
		Gen2WorldScript.SETEVENT, ARRIVED_FLAG & 0xFF, ARRIVED_FLAG >> 8,
		Gen2WorldScript.END,
	]
	RomCache.write_json(RomCache.world_scripts_path(directory), scripts)


func _open_world() -> void:
	var packed: PackedScene = load("res://game/world/world_screen.tscn")
	_world_screen = packed.instantiate() as Gen2WorldScreen
	_world_screen.map_group = Fixture.MAP_GROUP
	_world_screen.map_number = Fixture.MAP_NUMBER
	_world_screen.start_cell = PLAYER_CELL
	var world: Gen2WorldAPI = Gen2WorldAPI.open(
		_data, Fixture.MAP_GROUP, Fixture.MAP_NUMBER, PLAYER_CELL, Gen2WorldState.new()
	)
	var save: Gen2SaveData = Gen2SaveStore.create_development_save(_data, 0)
	save.world = world.snapshot()
	_world_screen.set_data(_data)
	_world_screen.set_save(save)
	add_child(_world_screen)
	await get_tree().process_frame
	## The ride counts hardware frames, so the ones this test spends have to be
	## the ones it asks for.
	_world_screen.set_process(false)


func _run_script() -> void:
	_world_screen._show_script_results(
		_world_screen._world.dispatch_script_events(TALK_CELL)
	)


func _host() -> Gen2MagnetTrainScreen:
	return _world_screen._magnet_train_host


func test_the_special_opens_the_ride_and_holds_the_world() -> void:
	await _open_world()
	_run_script()
	assert_not_null(_host(), "the special must open the ride")
	assert_true(_host().visible)
	assert_false(_world_screen.move_player(Vector2i.RIGHT))
	assert_false(_world_screen.interact())
	assert_false(
		_world_screen._world.state.is_event_flag_active(ARRIVED_FLAG),
		"the script waits on the ride rather than running past it"
	)


## The ride reads no joypad: a press is spent and the map is nobody's until the
## train has arrived.
func test_a_press_does_not_end_the_ride() -> void:
	await _open_world()
	_run_script()
	_world_screen.press_button(PokeButton.A)
	_world_screen.press_button(PokeButton.B)
	assert_not_null(_host(), "a press must not close the ride")


## The world's own pump is what spends the ride's frames, and the command behind
## the special runs on the frame it finishes.
func test_the_world_pump_drives_the_ride_and_resumes_the_script() -> void:
	await _open_world()
	_run_script()
	for _frame: int in Gen2MagnetTrainScreen.FRAME_CAP:
		if _host() == null:
			break
		_world_screen.advance_frame()
	assert_null(_host(), "the ride must close itself")
	assert_true(
		_world_screen._world.state.is_event_flag_active(ARRIVED_FLAG),
		"the command behind the special must run"
	)
	assert_true(_world_screen.move_player(Vector2i.RIGHT))
