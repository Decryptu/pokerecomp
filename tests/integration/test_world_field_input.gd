extends GutTest

## The overworld's own button funnel, [method Gen2WorldScreen.press_button]: which
## press each box on the map answers, and where the party list's actions land.
## The fixture is synthetic; the world screen and its hosts are the production
## paths.

const Fixture := preload("res://tests/integration/world_trainer_fixture.gd")

## The fixture's coord event, which the script case below is written onto.
const SCRIPT_CELL: Vector2i = Vector2i(4, 5)
const SCRIPT_TEXT: int = 0x6400
## POTION's number, which the fixture's items table carries.
const POTION: int = 7
const OLD_ROD: int = Gen2WorldInventory.ITEM_OLD_ROD

var _data: GameData = null
var _world_screen: Gen2WorldScreen = null


func before_each() -> void:
	_data = Fixture.build()
	_data = GameData.open_directory(Fixture.directory())


func after_each() -> void:
	await get_tree().process_frame
	if is_instance_valid(_world_screen):
		_world_screen.free()
		_world_screen = null
	RomCache.clear(Fixture.directory())
	Gen2ModHost.reset()


func _open_world(cell: Vector2i = Vector2i(7, 6)) -> void:
	var packed: PackedScene = load("res://game/world/world_screen.tscn")
	_world_screen = packed.instantiate() as Gen2WorldScreen
	_world_screen.map_group = Fixture.MAP_GROUP
	_world_screen.map_number = Fixture.MAP_NUMBER
	_world_screen.start_cell = cell
	var state := Gen2WorldState.new({}, {}, {POTION: 1}, {0: 500})
	var world := Gen2WorldAPI.open(
		_data, Fixture.MAP_GROUP, Fixture.MAP_NUMBER, cell, state
	)
	var save := Gen2SaveStore.create_development_save(_data, 0)
	save.world = world.snapshot()
	_world_screen.set_data(_data)
	_world_screen.set_save(save)
	add_child(_world_screen)
	await get_tree().process_frame
	_world_screen.set_process(false)


## `writetext` over a `<CONT>` and a `waitbutton` behind it.
func _write_text_script() -> void:
	var directory: String = Fixture.directory()
	var scripts: Dictionary = RomCache.read_json(RomCache.world_scripts_path(directory))
	scripts[Gen2WorldScript.pointer_key(Fixture.BANK, Fixture.TUTORIAL_SCRIPT)] = [
		Gen2WorldScript.WRITETEXT, SCRIPT_TEXT & 0xFF, SCRIPT_TEXT >> 8,
		Gen2WorldScript.WAITBUTTON,
		Gen2WorldScript.END,
	]
	RomCache.write_json(RomCache.world_scripts_path(directory), scripts)
	var text: Dictionary = RomCache.read_json(RomCache.world_text_path(directory))
	var encoded: Array = [Gen2WorldScript.TEXT_START]
	for byte: int in Gen2Text.encode("AB"):
		encoded.append(byte)
	encoded.append(Gen2TextStream.CHAR_CONT)
	for byte: int in Gen2Text.encode("CD"):
		encoded.append(byte)
	encoded.append(Gen2TextStream.CHAR_DONE)
	text[Gen2WorldScript.pointer_key(Fixture.BANK, SCRIPT_TEXT)] = encoded
	RomCache.write_json(RomCache.world_text_path(directory), text)
	_data = GameData.open_directory(directory)


## Frames until the box is neither revealing nor scrolling, so the next press is
## the one the box waits for rather than the one that skips a reveal.
func _settle_text_box() -> void:
	for _frame: int in 240:
		var settled: bool = not _world_screen._text_box.is_revealing() \
			and not _world_screen._text_box.is_scrolling()
		_world_screen.advance_frame()
		if settled:
			return
		_world_screen._text_box.advance_frame()
		_world_screen._text_box.advance_scroll_frames(1.0)


## `_ContText`'s `ButtonSound` and `WaitButton` both read `A_BUTTON | B_BUTTON`,
## so B scrolls the page and closes the box the way A does.
func test_b_advances_and_closes_a_script_text_box() -> void:
	_write_text_script()
	await _open_world(SCRIPT_CELL)
	_world_screen._show_script_results(
		_world_screen._world.dispatch_script_events(SCRIPT_CELL)
	)
	_settle_text_box()
	assert_true(_world_screen._text_box.visible)

	_world_screen.press_button(PokeButton.B)
	assert_true(_world_screen._text_box.is_scrolling(), "B spends the `<CONT>`")
	_settle_text_box()
	assert_eq(
		StringName(_world_screen._world.pending_script_input().get("type", &"")), &"button"
	)
	_world_screen.press_button(PokeButton.B)
	assert_true(_world_screen._world.pending_script_input().is_empty(), "and the waitbutton")
	assert_false(_world_screen._text_box.visible)


## `Fish`'s `WaitButton` behind a cast reads A or B, so either reels the line in.
func test_b_advances_a_cast_line_the_way_a_does() -> void:
	await _open_world()
	_world_screen._world.state.apply_changes({}, {}, {"items": {OLD_ROD: 1}})
	_world_screen.preview_fishing()
	assert_true(_world_screen._world.fishing_busy())
	var cast: StringName = _world_screen._world.fishing_state()
	_world_screen.press_button(PokeButton.B)
	assert_ne(_world_screen._world.fishing_state(), cast, "B advanced the cast")


## `StartMenu`'s `.MenuData` sets STATICMENU_ENABLE_START, which
## `ContinueGettingMenuJoypad` answers as B: START over the list closes it.
func test_start_closes_an_open_start_menu() -> void:
	await _open_world()
	_world_screen._open_start_menu()
	await get_tree().process_frame
	assert_not_null(_world_screen._start_menu_host)
	_world_screen.press_button(PokeButton.START)
	await get_tree().process_frame
	assert_null(_world_screen._start_menu_host)
	assert_true(_world_screen._objects_may_move())


## `MonMenu_Item`'s TAKE answers 0, which `StartMenu_Pokemon` takes back to
## `.loop` with the member it acted on still chosen. The line it prints closes
## on B as well as A, which is `PrintText`'s own `WaitButton`.
func test_take_returns_to_the_party_list_on_the_member_it_acted_on() -> void:
	await _open_world()
	var save: Gen2SaveData = _world_screen._injected_save
	(save.party[1] as Gen2SaveMon).item = POTION
	_world_screen._open_embedded_party()
	await get_tree().process_frame
	var party: Gen2PartyScreen = _world_screen._party_host
	party.handle_button(PokeButton.DOWN)
	party.handle_button(PokeButton.A)
	var items: Array = (party.submenu_snapshot()["items"] as Array)
	for index: int in items.size():
		if StringName((items[index] as Dictionary).get("option", &"")) \
			== Gen2PartyScreen.OPTION_ITEM:
			party.set("_submenu_cursor", index)
			break
	party.handle_button(PokeButton.A)
	party.handle_button(PokeButton.DOWN)
	party.handle_button(PokeButton.A)
	await get_tree().process_frame
	assert_eq((save.party[1] as Gen2SaveMon).item, 0, "TAKE put it in the bag")
	assert_true(_world_screen._field_move_text, "the took line is up")
	assert_null(_world_screen._party_host, "over the map")

	_world_screen.press_button(PokeButton.B)
	assert_false(_world_screen._field_move_text, "B closed the line")
	assert_not_null(_world_screen._party_host, "and the list is back")
	assert_eq(_world_screen._party_host.get("_member_cursor"), 1, "on the same member")
