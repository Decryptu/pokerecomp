extends GutTest

## The bedroom PC's WITHDRAW ITEM and TOSS ITEM lists (`PlayerWithdrawItemMenu`,
## `PlayerTossItemMenu`) through the production world screen and service host.

const Fixture := preload("res://tests/integration/world_trainer_fixture.gd")

const STACK: int = 7
const OTHER_STACK: int = 0x14
const KEY_ITEM: int = 8

var _data: GameData = null
var _world_screen: Gen2WorldScreen = null


func before_each() -> void:
	Gen2ModHost.reset()
	_data = Fixture.build()
	_write_cache()
	_data = GameData.open_directory(Fixture.directory())


func after_each() -> void:
	if is_instance_valid(_world_screen):
		_world_screen.free()
		_world_screen = null
	RomCache.clear(Fixture.directory())
	Gen2ModHost.reset()


## `special PlayersHousePC` from the fixture's coord event, and one key item
## `_CheckTossableItem` refuses.
func _write_cache() -> void:
	var scripts: Dictionary = RomCache.read_json(RomCache.world_scripts_path(Fixture.directory()))
	scripts["48:6190"] = [Gen2WorldScript.SPECIAL, 29, 0, Gen2WorldScript.END]
	RomCache.write_json(RomCache.world_scripts_path(Fixture.directory()), scripts)
	var items: Array = RomCache.read_json(RomCache.items_path(Fixture.directory()))
	for raw: Dictionary in items:
		match int(raw.get("number", 0)):
			STACK:
				raw["name"] = "ITEM7"
				raw["description"] = "Item seven."
			KEY_ITEM:
				raw["name"] = "KEYITEM"
				raw["permissions"] = Gen2WorldPack.CANT_TOSS
	RomCache.write_json(RomCache.items_path(Fixture.directory()), items)


## The item PC open on its own menu, with the PC holding two stacks and a key
## item.
func _open_item_pc() -> Gen2WorldServiceScreen:
	var packed: PackedScene = load("res://game/world/world_screen.tscn")
	_world_screen = packed.instantiate() as Gen2WorldScreen
	_world_screen.map_group = Fixture.MAP_GROUP
	_world_screen.map_number = Fixture.MAP_NUMBER
	_world_screen.start_cell = Vector2i(7, 6)
	var state := Gen2WorldState.new({}, {}, {STACK: 1}, {0: 500})
	var world := Gen2WorldAPI.open(
		_data, Fixture.MAP_GROUP, Fixture.MAP_NUMBER, Vector2i(7, 6), state
	)
	var save := Gen2SaveStore.create_development_save(_data, 0)
	save.world = world.snapshot()
	_world_screen.set_data(_data)
	_world_screen.set_save(save)
	add_child(_world_screen)
	await get_tree().process_frame
	_world_screen._world.state.apply_changes({}, {}, {
		"pc_items": {STACK: 5, KEY_ITEM: 1, OTHER_STACK: 3},
	})
	_world_screen._world.current_map.events["coord_events"] = [
		{"x": 7, "y": 6, "script": 0x6190},
	]
	_world_screen._show_script_results(
		_world_screen._world.dispatch_script_events(Vector2i(7, 6))
	)
	await get_tree().process_frame
	var host: Gen2WorldServiceScreen = _world_screen._service_host
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_ITEMS)
	assert_eq(host._summary, _data.pokecenter_pc_text("ask_what_do"), "`_PlayersPC`'s question")
	return host


## WITHDRAW ITEM or TOSS ITEM, by its row on the item PC's own menu.
func _open_list(host: Gen2WorldServiceScreen, row: int) -> void:
	for _step: int in row:
		host.handle_button(PokeButton.DOWN)
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_ITEM_LIST)


func _walk_to(host: Gen2WorldServiceScreen, item: int) -> void:
	for _step: int in host._pc_entries.size():
		if int(host._pc_entries[host._cursor].get("item", 0)) == item:
			return
		host.handle_button(PokeButton.DOWN)


func _state() -> Gen2WorldState:
	return _world_screen._world.state


## `ScrollingMenu` draws CANCEL past `wPCItems`' terminator, and taking it is
## `PCItemsJoypad`'s `.b_1`: back to the item PC's menu with nothing moved. The
## box under the list describes the row the cursor is on.
func test_the_list_ends_in_cancel_which_leaves_it() -> void:
	var host: Gen2WorldServiceScreen = await _open_item_pc()
	_open_list(host, 0)
	assert_eq(host._option_count(), host._pc_entries.size() + 1)
	## `.PCItemsMenuData`'s `UpdateItemDescription` follows the cursor.
	_walk_to(host, STACK)
	assert_eq(host._render_summary(), "Item seven.")
	for _step: int in host._pc_entries.size():
		host.handle_button(PokeButton.DOWN)
	assert_eq(host._cursor, host._pc_entries.size(), "the last row is CANCEL")
	assert_eq(host._render_summary(), "", "which has no description")
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_ITEMS)
	assert_eq(_state().pc_item_quantity(STACK), 5)


## `.askquantity`: `SelectQuantityToToss` over `.PlayersPCHowManyWithdrawText`,
## A takes the dial's count and B is its carry, which withdraws nothing.
func test_withdraw_asks_how_many_and_moves_that_many() -> void:
	var host: Gen2WorldServiceScreen = await _open_item_pc()
	_open_list(host, 0)
	host.handle_button(PokeButton.A)
	assert_eq(host._pc_item_stage, &"quantity")
	assert_eq(host._summary, _data.pokecenter_pc_text("how_many_withdraw"))
	host.handle_button(PokeButton.B)
	assert_eq(host._pc_item_stage, &"")
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_ITEM_LIST)
	assert_eq(_state().pc_item_quantity(STACK), 5, "B withdrew nothing")

	host.handle_button(PokeButton.A)
	host.handle_button(PokeButton.UP)
	assert_eq(host._quantity_prompt.value, 2)
	host.handle_button(PokeButton.A)
	assert_eq(host._pc_item_stage, &"")
	assert_eq(_state().pc_item_quantity(STACK), 3)
	assert_eq(_state().item_quantity(STACK), 3)
	assert_true(host._status.begins_with("Withdrew 2"), host._status)


## `.Submenu`'s `_CheckTossableItem`: an item with no quantity is always one,
## so a key item asks nothing and moves.
func test_withdrawing_a_key_item_skips_the_dial() -> void:
	var host: Gen2WorldServiceScreen = await _open_item_pc()
	_open_list(host, 0)
	_walk_to(host, KEY_ITEM)
	host.handle_button(PokeButton.A)
	assert_eq(host._pc_item_stage, &"")
	assert_eq(_state().pc_item_quantity(KEY_ITEM), 0)
	assert_eq(_state().item_quantity(KEY_ITEM), 1)


## `TossItemFromPC`: the dial, `.ItemsThrowAwayText`'s `YesNoBox`, the hold,
## and `.ItemsDiscardedText` once the chosen count is gone.
func test_toss_asks_how_many_then_yes_no_and_discards_that_many() -> void:
	var host: Gen2WorldServiceScreen = await _open_item_pc()
	_open_list(host, 2)
	_walk_to(host, OTHER_STACK)
	host.handle_button(PokeButton.A)
	assert_eq(host._pc_item_stage, &"quantity")
	host.handle_button(PokeButton.UP)
	host.handle_button(PokeButton.A)
	assert_eq(host._pc_item_stage, &"toss_ask")
	assert_true(host._summary.begins_with("Throw away 2"), host._summary)

	host.handle_button(PokeButton.A)
	for _frame: int in Gen2WorldMenu.ANSWER_HOLD_FRAMES - 1:
		host.advance_frame()
	assert_eq(_state().pc_item_quantity(OTHER_STACK), 3, "the answer is held first")
	host.advance_frame()
	assert_eq(host._pc_item_stage, &"")
	assert_eq(_state().pc_item_quantity(OTHER_STACK), 1)
	assert_true(host._status.begins_with("Discarded"), host._status)


## The same question's NO, and B, which `YesNoBox` answers as NO: back to the
## list with the stack whole.
func test_no_or_b_on_the_toss_question_keeps_the_stack() -> void:
	var host: Gen2WorldServiceScreen = await _open_item_pc()
	_open_list(host, 2)
	for refusal: Array in [[PokeButton.DOWN, PokeButton.A], [PokeButton.B]]:
		host.handle_button(PokeButton.A)
		host.handle_button(PokeButton.A)
		assert_eq(host._pc_item_stage, &"toss_ask")
		for button: int in refusal:
			host.handle_button(button)
		for _frame: int in Gen2WorldMenu.ANSWER_HOLD_FRAMES:
			host.advance_frame()
		assert_eq(host._pc_item_stage, &"")
		assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_ITEM_LIST)
		assert_eq(_state().pc_item_quantity(STACK), 5)


## `.key_item`'s `.ItemsTooImportantText`: no dial and no question.
func test_tossing_a_key_item_is_refused() -> void:
	var host: Gen2WorldServiceScreen = await _open_item_pc()
	_open_list(host, 2)
	_walk_to(host, KEY_ITEM)
	host.handle_button(PokeButton.A)
	assert_eq(host._pc_item_stage, &"")
	assert_eq(host._status, Gen2WorldPC.ITEMS_TOO_IMPORTANT)
	assert_eq(_state().pc_item_quantity(KEY_ITEM), 1)


## `PCItemsJoypad` restores `wPCItemsCursor` on every pass, and only
## `_PlayersPC` zeroes it: a dial backed out of, a NO, and the list opened again
## off the menu all come back on the row they left.
func test_the_list_keeps_its_row_across_the_dial_the_question_and_the_menu() -> void:
	var host: Gen2WorldServiceScreen = await _open_item_pc()
	_open_list(host, 2)
	_walk_to(host, OTHER_STACK)
	var row: int = host._cursor
	assert_eq(row, 2)
	host.handle_button(PokeButton.A)
	host.handle_button(PokeButton.B)
	assert_eq(host._cursor, row, "B on the dial")
	host.handle_button(PokeButton.A)
	host.handle_button(PokeButton.A)
	host.handle_button(PokeButton.B)
	for _frame: int in Gen2WorldMenu.ANSWER_HOLD_FRAMES:
		host.advance_frame()
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_ITEM_LIST)
	assert_eq(host._cursor, row, "NO on the question")
	host.handle_button(PokeButton.B)
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_ITEM_LIST)
	assert_eq(host._cursor, row, "the list opened again off the menu")
