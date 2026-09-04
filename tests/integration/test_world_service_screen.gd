extends GutTest

## Scene integration for the cache-backed service overlay. The fixture is
## synthetic, but the world screen, script runner, transaction host and UI
## scene are the production paths.

const Fixture := preload("res://tests/integration/world_trainer_fixture.gd")

const APRICORN_RED: int = 0x55
const APRICORN_BLU: int = 0x59

var _data: GameData = null
var _world_screen: Gen2WorldScreen = null


func before_each() -> void:
	Gen2ModHost.reset()
	_data = Fixture.build()
	_write_service_cache()
	_data = GameData.open_directory(Fixture.directory())


func after_each() -> void:
	if is_instance_valid(_world_screen):
		_world_screen.free()
		_world_screen = null
	RomCache.clear(Fixture.directory())
	Gen2ModHost.reset()


func _open_world(items: Dictionary = {7: 1}) -> void:
	var packed: PackedScene = load("res://game/world/world_screen.tscn")
	_world_screen = packed.instantiate() as Gen2WorldScreen
	_world_screen.map_group = Fixture.MAP_GROUP
	_world_screen.map_number = Fixture.MAP_NUMBER
	_world_screen.start_cell = Vector2i(7, 6)
	var state := Gen2WorldState.new({}, {}, items, {0: 500})
	var world := Gen2WorldAPI.open(
		_data, Fixture.MAP_GROUP, Fixture.MAP_NUMBER, Vector2i(7, 6), state
	)
	var save := Gen2SaveStore.create_development_save(_data, 0)
	save.world = world.snapshot()
	_world_screen.set_data(_data)
	_world_screen.set_save(save)
	add_child(_world_screen)
	await get_tree().process_frame


func _queue_service() -> void:
	var waiting: Array = _world_screen._world.dispatch_script_events(Vector2i(7, 6))
	assert_eq(waiting.size(), 1)
	assert_eq(waiting[0]["status"], &"waiting")
	_world_screen._show_script_results(waiting)
	await get_tree().process_frame


## `StandardMart` opens on `.TopMenu`, so every buy in this file starts by
## taking its BUY row. `.Quit` and B are the way out of the shop now; B off the
## buy list is `.AnythingElse`.
func _enter_mart_buy(host: Gen2WorldServiceScreen) -> void:
	assert_eq(host._mart_stage, Gen2WorldServiceScreen.MART_TOP)
	assert_true(host.handle_button(PokeButton.A))
	assert_eq(host._mart_stage, Gen2WorldServiceScreen.MART_LIST)


## B until the shop is shut. The synthetic cache carries none of the mart's own
## words, so `.AnythingElse`'s box and `MartComeAgainText` each advance without a
## press and only the two B's are spent.
func _quit_mart(host: Gen2WorldServiceScreen) -> void:
	if host._mart_stage != Gen2WorldServiceScreen.MART_TOP:
		assert_true(host.handle_button(PokeButton.B))
		assert_eq(host._mart_stage, Gen2WorldServiceScreen.MART_TOP)
	assert_true(host.handle_button(PokeButton.B))


func _write_pc_request() -> void:
	var scripts: Dictionary = RomCache.read_json(RomCache.world_scripts_path(Fixture.directory()))
	scripts["48:6190"] = [Gen2WorldScript.SPECIAL, 29, 0, Gen2WorldScript.END]
	RomCache.write_json(RomCache.world_scripts_path(Fixture.directory()), scripts)
	_data = GameData.open_directory(Fixture.directory())


## `_PlayersHousePC` is the item PC, not box storage: the bedroom's own list is
## the one that ends in TURN OFF.
func test_players_house_pc_opens_the_item_pc_and_resumes_the_waiting_script() -> void:
	_write_pc_request()
	await _open_world()
	_world_screen._world.current_map.events["coord_events"][0]["script"] = 0x6190
	var waiting: Array = _world_screen._world.dispatch_script_events(Vector2i(7, 6))
	assert_eq(waiting.size(), 1)
	assert_eq(waiting[0]["status"], &"waiting")
	_world_screen._show_script_results(waiting)
	await get_tree().process_frame

	var host: Gen2WorldServiceScreen = _world_screen._service_host
	assert_not_null(host)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_ITEMS)
	assert_true(host._pc_house)
	var rows: Array = []
	for row: Dictionary in host._pc_rows:
		rows.append(int(row["row"]))
	assert_eq(rows, [
		Gen2WorldPC.PLAYERSPCITEM_WITHDRAW_ITEM,
		Gen2WorldPC.PLAYERSPCITEM_DEPOSIT_ITEM,
		Gen2WorldPC.PLAYERSPCITEM_TOSS_ITEM,
		Gen2WorldPC.PLAYERSPCITEM_MAIL_BOX,
		Gen2WorldPC.PLAYERSPCITEM_DECORATION,
		Gen2WorldPC.PLAYERSPCITEM_TURN_OFF,
	])

	## DEPOSIT ITEM, then the one item the world was opened with.
	host.handle_button(PokeButton.DOWN)
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_ITEM_LIST)
	host.handle_button(PokeButton.A)
	assert_eq(_world_screen._world.state.pc_item_quantity(7), 1)
	assert_eq(_world_screen._world.state.item_quantity(7), 0)

	host.handle_button(PokeButton.B)
	host.handle_button(PokeButton.B)
	await get_tree().process_frame
	assert_null(_world_screen._service_host)
	assert_false(_world_screen._world.script_input_waiting())


## `special TryQuickSave`, which the cable club and the Battle Tower both ask for
## before they start. `Link_SaveGame` has no question of its own, so the box that
## opens is `AskOverwriteSaveFile`'s; writing with nothing on screen was the
## defect.
func test_try_quick_save_asks_before_it_writes_and_answers_the_script() -> void:
	var scripts: Dictionary = RomCache.read_json(RomCache.world_scripts_path(Fixture.directory()))
	scripts["48:6195"] = [
		Gen2WorldScript.SPECIAL, Gen2WorldScriptRunner.SPECIAL_TRY_QUICK_SAVE, 0,
		Gen2WorldScript.END,
	]
	RomCache.write_json(RomCache.world_scripts_path(Fixture.directory()), scripts)
	_data = GameData.open_directory(Fixture.directory())
	await _open_world()
	_world_screen._world.current_map.events["coord_events"][0]["script"] = 0x6195
	_world_screen._show_script_results(
		_world_screen._world.dispatch_script_events(Vector2i(7, 6))
	)
	await get_tree().process_frame

	var host: Gen2WorldServiceScreen = _world_screen._service_host
	assert_not_null(host)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_SAVE)
	_world_screen._injected_save.world = null
	assert_eq(host._save_prompt.lines, Gen2SavePrompt.OVERWRITE_LINES)
	host.handle_button(PokeButton.A)
	host.handle_button(PokeButton.A)
	assert_eq(host._save_prompt.step, Gen2SavePrompt.Step.SAVING)
	host.advance_save_frames(
		Gen2SavePrompt.SAVING_FRAMES + Gen2SavePrompt.WRITE_FRAMES
		+ Gen2SavePrompt.DONE_FRAMES
	)
	await get_tree().process_frame
	assert_null(_world_screen._service_host)
	assert_not_null(_world_screen._injected_save.world, "the write landed")


## Both questions taken with YES, and every frame the two boxes behind them own.
func _answer_save_prompt(host: Gen2WorldServiceScreen) -> void:
	for _press: int in 4:
		host.handle_button(PokeButton.A)
	host.advance_save_frames(
		Gen2SavePrompt.SAVING_FRAMES + Gen2SavePrompt.WRITE_FRAMES
		+ Gen2SavePrompt.DONE_FRAMES
	)


## `BillsPC_ChangeBoxSubmenu`: SWITCH writes `wCurBox`, NAME opens the keyboard
## over `sBoxNames`, and PRINT answers `GetBoxCount` before it reaches the
## printer that is not there.
func test_change_box_switches_names_and_prints_a_box() -> void:
	await _open_pokemon_center_pc()
	var host: Gen2WorldServiceScreen = _world_screen._service_host
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_BOXES)
	for _step: int in 2:
		host.handle_button(PokeButton.DOWN)
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_BOX_LIST)

	## The second box, then SWITCH, which is `ChangeBoxSaveGame`: the question,
	## the overwrite question and the save behind them.
	host.handle_button(PokeButton.DOWN)
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_BOX_SUBMENU)
	host.handle_button(PokeButton.A)
	_answer_save_prompt(host)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_BOX_LIST)
	assert_eq(host._box_index, 1)
	assert_eq(host._save.current_box, 1)
	## `.loop` copies the header again, so the list comes back on its first row
	## rather than on the box that was just switched to.
	assert_eq(host._cursor, 0)
	assert_eq(host._pc_scroll, 0)

	## PRINT over an empty box is `.EmptyBox` rather than a send.
	host.handle_button(PokeButton.DOWN)
	host.handle_button(PokeButton.A)
	for _step: int in 2:
		host.handle_button(PokeButton.DOWN)
	host.handle_button(PokeButton.A)
	assert_eq(host._status, Gen2WorldServiceScreen.BOX_EMPTY_TEXT)

	## NAME opens the keyboard, and what it stores is what the list draws. The
	## submenu is still up with its cursor on PRINT, so one row back reaches it.
	host.handle_button(PokeButton.UP)
	host.handle_button(PokeButton.A)
	assert_not_null(host._naming, host._status)
	host._on_box_named("KANTO")
	await get_tree().process_frame
	assert_null(host._naming)
	assert_eq(host._save.box_name(1), "KANTO")
	assert_eq(String(host._pc_rows[1]["name"]), "KANTO")


## `_HallOfFamePC.MasterLoop`: one stored team at a time, and B is the way out.
func test_the_hall_of_fame_row_walks_the_stored_records() -> void:
	await _open_pokemon_center_pc()
	var host: Gen2WorldServiceScreen = _world_screen._service_host
	host._save.hall_of_fame = Gen2HallOfFame.inducted([], host._save)
	host._world.state.set_engine_flag(Gen2WorldState.ENGINE_POKEDEX, true)
	host._world.state.set_hall_of_fame(true)
	host._open_pc(&"pokemon_center")
	var rows: Array = []
	for row: Dictionary in host._pc_rows:
		rows.append(int(row["row"]))
	assert_true(Gen2WorldPC.PCPCITEM_HALL_OF_FAME in rows)

	host._cursor = rows.find(Gen2WorldPC.PCPCITEM_HALL_OF_FAME)
	host.handle_button(PokeButton.A)
	assert_not_null(host._hof)
	assert_eq(host._hof.remaining(), host._save.hall_of_fame[0]["mons"].size())
	assert_eq(
		int(host._hof.current_page()["win_count"]),
		Gen2HallOfFame.win_count(host._save.hall_of_fame)
	)

	## B leaves the machine's own loop rather than the record.
	host.handle_button(PokeButton.B)
	await get_tree().process_frame
	assert_null(host._hof)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC)


## `PokemonCenterPC`'s top menu, whose BILL'S PC row is the box screen the
## bedroom's PC used to open.
func test_pokemon_center_pc_opens_the_top_menu_and_bills_pc_behind_it() -> void:
	await _open_pokemon_center_pc()
	var host: Gen2WorldServiceScreen = _world_screen._service_host
	assert_not_null(host)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC)
	assert_eq(int(host._pc_rows[0]["row"]), Gen2WorldPC.PCPCITEM_BILLS_PC)

	## `_BillsPC`'s own top menu stands between the machine and the lists, and
	## its DEPOSIT row is what opens the party one.
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_BOXES)
	assert_eq(int(host._pc_rows[0]["row"]), Gen2WorldPC.BILLSPCITEM_WITHDRAW)
	host.handle_button(PokeButton.DOWN)
	host.handle_button(PokeButton.A)
	await _finish_pokemon_center_pc(host)


## `.Switch`: `ChangeBoxSaveGame` asks, saves behind its own box, and puts
## `wCurBox` between the two halves. Silently switching the box was the defect.
func test_change_box_asks_and_saves_before_the_box_moves() -> void:
	await _open_pokemon_center_pc()
	var host: Gen2WorldServiceScreen = _world_screen._service_host
	host.handle_button(PokeButton.A)
	host.handle_button(PokeButton.DOWN)
	host.handle_button(PokeButton.DOWN)
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_BOX_LIST)
	host.handle_button(PokeButton.DOWN)
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_BOX_SUBMENU)
	host.handle_button(PokeButton.A)

	## Three lines, so the question is prompted past before the yes/no is on it.
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_SAVE)
	assert_eq(host._save_prompt.lines, Gen2SavePrompt.CHANGE_BOX_LINES)
	assert_eq(host._save_prompt.cursor, -1)
	host.handle_button(PokeButton.A)
	assert_eq(host._save_prompt.cursor, 0)
	host.handle_button(PokeButton.A)
	assert_eq(host._save_prompt.lines, Gen2SavePrompt.OVERWRITE_LINES)
	host.handle_button(PokeButton.A)
	host.handle_button(PokeButton.A)
	assert_eq(host._save_prompt.step, Gen2SavePrompt.Step.SAVING)
	assert_eq(int(host._save.current_box), 0, "not until the write")

	host.advance_save_frames(Gen2SavePrompt.SAVING_FRAMES)
	assert_eq(int(host._save.current_box), 1, "`wCurBox` sits between the halves")
	host.advance_save_frames(
		Gen2SavePrompt.WRITE_FRAMES + Gen2SavePrompt.DONE_FRAMES
	)
	assert_null(host._save_prompt)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_BOX_LIST)


## `BillsPC_MovePKMNMenu`: `IsAnyMonHoldingMail` refuses the row outright, and
## `StartMoveMonWOMail_SaveGame` is what stands in front of the listing.
func test_move_without_mail_refuses_a_party_holding_mail_and_saves_otherwise() -> void:
	await _open_pokemon_center_pc()
	var host: Gen2WorldServiceScreen = _world_screen._service_host
	host.handle_button(PokeButton.A)
	(host._save.party[0] as Gen2SaveMon).item = Gen2HeldItem.MAIL_ITEMS[0]
	for _step: int in 3:
		host.handle_button(PokeButton.DOWN)
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_TEXT)
	assert_string_contains(host._summary, "holding MAIL")
	host.handle_button(PokeButton.A)
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_BOXES)

	## Without the mail the row asks its own question, and a NO is `.refused`'s
	## carry: back to the machine's menu with no listing opened. `.UseBillsPC`
	## puts that menu back on the row it left, so MOVE is under the cursor still.
	(host._save.party[0] as Gen2SaveMon).item = 0
	assert_eq(host._cursor, Gen2WorldPC.BILLSPCITEM_MOVE_WITHOUT_MAIL)
	host.handle_button(PokeButton.A)
	assert_eq(host._save_prompt.lines, Gen2SavePrompt.MOVE_MON_LINES)
	host.handle_button(PokeButton.A)
	host.handle_button(PokeButton.DOWN)
	host.handle_button(PokeButton.A)
	assert_null(host._save_prompt)
	assert_null(host._boxes)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_BOXES)


## `PC_PlayBootSound`, `PC_PlayChoosePCSound` and `PC_PlayShutdownSound`, the
## three the machine spends on its own: one on the way in, one on every row but
## TURN OFF, and one on `.shutdown`.
func test_the_machine_boots_chooses_and_shuts_down_with_its_own_sounds() -> void:
	await _open_pokemon_center_pc()
	var host: Gen2WorldServiceScreen = _world_screen._service_host
	watch_signals(host)
	assert_true(host.open_pc_machine(
		host._world, _data, host._save, false, &"pokemon_center"
	))
	assert_signal_emitted_with_parameters(
		host, "sfx_requested", [Gen2WorldServiceScreen.SFX_BOOT_PC, true]
	)
	host.handle_button(PokeButton.A)
	assert_signal_emitted_with_parameters(
		host, "sfx_requested", [Gen2WorldServiceScreen.SFX_CHOOSE_PC_OPTION, true]
	)

	## `.loop` is behind the boot sound, so coming back to it plays nothing.
	host.handle_button(PokeButton.B)
	assert_signal_emit_count(host, "sfx_requested", 2)
	host.handle_button(PokeButton.B)
	assert_signal_emitted_with_parameters(
		host, "sfx_requested", [Gen2WorldServiceScreen.SFX_SHUT_DOWN_PC, true]
	)
	await get_tree().process_frame
	assert_null(_world_screen._service_host)


## `ProfOaksPC`: `_OakPCText1`'s question first, `ProfOaksPCBoot` behind a YES,
## and `_OakPCText4` on the way out whichever way it was answered. The row used
## to open on the rating with neither box around it.
func test_the_oak_pc_row_asks_first_and_closes_with_its_own_line() -> void:
	await _open_pokemon_center_pc()
	var host: Gen2WorldServiceScreen = _world_screen._service_host
	host._world.state.set_engine_flag(Gen2WorldState.ENGINE_POKEDEX, true)
	host._open_pc(&"pokemon_center")
	var rows: Array = []
	for row: Dictionary in host._pc_rows:
		rows.append(int(row["row"]))
	host._cursor = rows.find(Gen2WorldPC.PCPCITEM_OAKS_PC)
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_OAK_ASK)
	assert_eq(host._summary, _data.oak_pc_text("ask"))

	## NO is `.shutdown`: the closing line and nothing rated.
	host.handle_button(PokeButton.DOWN)
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_TEXT)
	assert_eq(host._summary, _data.oak_pc_text("closed"))
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC)

	## YES rates first, and the same line is still the last box.
	host._cursor = rows.find(Gen2WorldPC.PCPCITEM_OAKS_PC)
	host.handle_button(PokeButton.A)
	host.handle_button(PokeButton.A)
	var boot: Dictionary = Gen2ProfOaksPC.boot(_data, host._world.state)
	assert_eq(host._summary, String((boot["pages"] as Array)[0]))
	for _page: int in (boot["pages"] as Array).size():
		host.handle_button(PokeButton.A)
	assert_eq(host._summary, _data.oak_pc_text("closed"))
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC)


## The reported defect. The box screen owns the whole screen while BILL'S PC is
## open and the world routes its buttons, so a focus ring put up before
## `set_context` said it was embedded claimed every direction on the way in and
## the listing never left its first row.
func test_the_deposit_list_walks_on_real_presses_with_focus_held_elsewhere() -> void:
	await _open_pokemon_center_pc()
	var host: Gen2WorldServiceScreen = _world_screen._service_host
	host.handle_button(PokeButton.A)
	host.handle_button(PokeButton.DOWN)
	host.handle_button(PokeButton.A)
	var boxes: Gen2BoxScreen = host._boxes
	assert_not_null(boxes)
	assert_null(boxes.get_node_or_null(^"FocusGuard"), "the world routes these buttons")

	var elsewhere := Button.new()
	add_child_autofree(elsewhere)
	elsewhere.grab_focus()
	await get_tree().process_frame
	for step: int in 2:
		var press := InputEventAction.new()
		press.action = PokeButton.action(PokeButton.DOWN)
		press.pressed = true
		get_tree().root.push_input(press)
		await get_tree().process_frame
		assert_eq(int(boxes.box_snapshot()["cursor"]), step + 1)
	boxes.close_embedded()
	await get_tree().process_frame


## `special PokemonCenterPC` from a coord event, which is how every test above
## reaches the machine.
func _open_pokemon_center_pc() -> void:
	var scripts: Dictionary = RomCache.read_json(RomCache.world_scripts_path(Fixture.directory()))
	scripts["48:6195"] = [
		Gen2WorldScript.SPECIAL, Gen2WorldScriptRunner.SPECIAL_POKEMON_CENTER_PC, 0,
		Gen2WorldScript.END,
	]
	RomCache.write_json(RomCache.world_scripts_path(Fixture.directory()), scripts)
	_data = GameData.open_directory(Fixture.directory())
	await _open_world()
	_world_screen._world.current_map.events["coord_events"][0]["script"] = 0x6195
	var waiting: Array = _world_screen._world.dispatch_script_events(Vector2i(7, 6))
	assert_eq(waiting.size(), 1)
	assert_eq(waiting[0]["status"], &"waiting")
	assert_eq(_world_screen._world.pending_runtime_request()["values"]["mode"], &"pokemon_center")
	_world_screen._show_script_results(waiting)
	await get_tree().process_frame


## The DEPOSIT list `_BillsPC` opened, closed, and then B twice: off the
## machine's own menu that is SEE YA!, and off the top one it shuts the PC down.
func _finish_pokemon_center_pc(host: Gen2WorldServiceScreen) -> void:
	var boxes: Gen2BoxScreen = host._boxes
	assert_not_null(boxes)
	assert_eq(int(boxes.box_snapshot()["loaded"]), Gen2BoxScreen.LOADED_PARTY)
	assert_eq(boxes.box_snapshot()["boxes"].size(), Gen2SaveData.BOX_COUNT)
	boxes.close_embedded()
	await get_tree().process_frame
	assert_null(host._boxes)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_BOXES)

	host.handle_button(PokeButton.B)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC)
	host.handle_button(PokeButton.B)
	await get_tree().process_frame
	assert_null(_world_screen._service_host)
	assert_false(_world_screen._world.script_input_waiting())


## `MartDialog` opens on the map: `.HowMayIHelpYou` prints without waiting and
## `MenuHeader_BuySell` is drawn over that box, so nothing of `BuyMenu` is on
## screen until BUY is taken.
func test_the_shop_opens_over_the_map_and_the_buy_screen_only_after_buy() -> void:
	await _open_world()
	await _queue_service()

	var host: Gen2WorldServiceScreen = _world_screen._service_host
	assert_eq(host._mart_stage, Gen2WorldServiceScreen.MART_TOP)
	assert_true(host._mart_over_map, "the top menu stands on the map")
	var over_map: Image = (host._mart_view.texture as ImageTexture).get_image()
	assert_true(
		over_map.detect_alpha() != Image.ALPHA_NONE,
		"the box over the map is a layer rather than a screen"
	)

	assert_true(host.handle_button(PokeButton.A))
	assert_eq(host._mart_stage, Gen2WorldServiceScreen.MART_LIST)
	assert_false(host._mart_over_map)
	var listing: Image = (host._mart_view.texture as ImageTexture).get_image()
	assert_eq(
		listing.detect_alpha(), Image.ALPHA_NONE,
		"`BuyMenu` blanks the screen and owns all of it"
	)


## `CopyMenuHeader` reloads `MenuHeader_BuySell`'s `db 1`, so the cursor is on
## BUY every time `.TopMenu` runs rather than on the row it was left on.
func test_the_top_menu_reopens_on_buy() -> void:
	await _open_world()
	await _queue_service()

	var host: Gen2WorldServiceScreen = _world_screen._service_host
	assert_true(host.handle_button(PokeButton.DOWN))
	assert_eq(host._cursor, Gen2WorldServiceScreen.MART_TOP_SELL)
	assert_true(host.handle_button(PokeButton.A))
	assert_eq(host._mart_stage, Gen2WorldServiceScreen.MART_SELL)
	## B off the list is `SellMenu`'s quit, and `.AnythingElse` asks again.
	assert_true(host.handle_button(PokeButton.B))
	assert_eq(host._mart_stage, Gen2WorldServiceScreen.MART_TOP)
	assert_eq(host._cursor, Gen2WorldServiceScreen.MART_TOP_BUY)


func test_mart_overlay_uses_production_input_and_returns_to_script() -> void:
	await _open_world()
	await _queue_service()

	var host: Gen2WorldServiceScreen = _world_screen._service_host
	assert_not_null(host)
	## `BuyMenu` owns the whole screen, so this host's own layer steps aside.
	assert_false(host._service_view.visible)
	assert_not_null(host._mart_view)
	_enter_mart_buy(host)
	## One item and CANCEL, which is the row `ScrollingMenu` draws past the
	## list's own terminator.
	assert_eq(host._mart_rows().size(), 2)
	assert_true(bool(host._mart_rows()[1].get("cancel", false)))

	assert_true(host.handle_button(PokeButton.A))
	assert_eq(host._mart_stage, Gen2WorldServiceScreen.MART_QUANTITY)
	assert_true(host.handle_button(PokeButton.A))
	assert_eq(host._mart_stage, Gen2WorldServiceScreen.MART_CONFIRM)
	assert_true(host.handle_button(PokeButton.A))
	assert_eq(_world_screen._world.state.money(), 380)
	assert_eq(_world_screen._world.state.item_quantity(7), 2)
	assert_true(host.is_active())

	_quit_mart(host)
	await get_tree().process_frame
	assert_null(_world_screen._service_host)
	assert_false(_world_screen._world.script_input_waiting())


func test_a_registered_mart_row_is_bought_through_the_regular_transaction() -> void:
	assert_true(Gen2ModHost.instance().register_menu_entry(Gen2ModHost.MENU_MART, &"second", {
		"label": "Second item", "item": 8, "price": 25,
	})["ok"])
	await _open_world()
	await _queue_service()

	var host: Gen2WorldServiceScreen = _world_screen._service_host
	assert_eq(host._mart_entries.size(), 2)
	assert_eq(int(host._mart_entries[1]["item"]), 8)
	assert_eq(int(host._mart_entries[1]["price"]), 25)
	_enter_mart_buy(host)
	host.handle_button(PokeButton.DOWN)
	host.handle_button(PokeButton.A)
	host.handle_button(PokeButton.A)
	host.handle_button(PokeButton.A)
	assert_eq(_world_screen._world.state.money(), 475)
	assert_eq(_world_screen._world.state.item_quantity(8), 1)


func test_mart_overlay_purchases_the_selected_quantity() -> void:
	await _open_world()
	await _queue_service()

	var host: Gen2WorldServiceScreen = _world_screen._service_host
	assert_not_null(host)
	_enter_mart_buy(host)
	assert_true(host.handle_button(PokeButton.A))
	## `BuySellToss_InterpretJoypad`: ten on right, one on down, and down off one
	## wraps to `wItemQuantity` rather than stopping.
	assert_true(host.handle_button(PokeButton.RIGHT))
	assert_eq(host._mart_quantity, 11)
	assert_true(host.handle_button(PokeButton.LEFT))
	assert_eq(host._mart_quantity, 1)
	assert_true(host.handle_button(PokeButton.DOWN))
	assert_eq(host._mart_quantity, Gen2WorldMartHost.MAX_ITEM_STACK)
	assert_true(host.handle_button(PokeButton.UP))
	assert_eq(host._mart_quantity, 1)
	assert_true(host.handle_button(PokeButton.UP))

	assert_true(host.handle_button(PokeButton.A))
	assert_true(host.handle_button(PokeButton.A))
	assert_eq(_world_screen._world.state.money(), 260)
	assert_eq(_world_screen._world.state.item_quantity(7), 3)
	assert_true(host.is_active())

	_quit_mart(host)
	await get_tree().process_frame
	assert_null(_world_screen._service_host)
	assert_false(_world_screen._world.script_input_waiting())


## `PlayTransactionSound` is the world screen's own driver, not the inspection
## probe: an overlay is a second surface on one [Gen2AudioPlayer], the way the
## start menu and the party screen already are.
func test_a_purchase_plays_its_sound_through_the_world_driver() -> void:
	await _open_world()
	await _queue_service()

	var host: Gen2WorldServiceScreen = _world_screen._service_host
	assert_not_null(host)
	var played: Array[int] = []
	host.sfx_requested.connect(
		func(index: int, _waited: bool) -> void: played.append(index)
	)
	_enter_mart_buy(host)
	assert_true(host.handle_button(PokeButton.A))
	assert_true(host.handle_button(PokeButton.A))
	assert_true(host.handle_button(PokeButton.A))
	assert_eq(played, [Gen2WorldServiceScreen.SFX_TRANSACTION] as Array[int])
	## The world screen is on the other end of it, which is what stops the
	## overlay reaching for a driver of its own. The synthetic cache carries no
	## effect records, so the engine has nothing to start.
	assert_true(host.sfx_requested.is_connected(_world_screen._play_sfx))


## `MartConfirmPurchase`'s NO, and B off the quantity box: both come back to the
## list with the money untouched.
func test_mart_overlay_refuses_without_taking_money() -> void:
	await _open_world()
	await _queue_service()

	var host: Gen2WorldServiceScreen = _world_screen._service_host
	_enter_mart_buy(host)
	assert_true(host.handle_button(PokeButton.A))
	assert_true(host.handle_button(PokeButton.B))
	assert_eq(host._mart_stage, Gen2WorldServiceScreen.MART_LIST)

	assert_true(host.handle_button(PokeButton.A))
	assert_true(host.handle_button(PokeButton.A))
	assert_true(host.handle_button(PokeButton.DOWN))
	assert_eq(host._mart_confirm, 1)
	assert_true(host.handle_button(PokeButton.A))
	assert_eq(host._mart_stage, Gen2WorldServiceScreen.MART_LIST)
	assert_eq(_world_screen._world.state.money(), 500)
	assert_eq(_world_screen._world.state.item_quantity(7), 1)


## The CANCEL row leaves the buy list the same way B does, which on a standard
## shop is `.AnythingElse` rather than the door.
func test_mart_overlay_cancel_row_leaves_the_buy_list() -> void:
	await _open_world()
	await _queue_service()

	var host: Gen2WorldServiceScreen = _world_screen._service_host
	_enter_mart_buy(host)
	assert_true(host.handle_button(PokeButton.DOWN))
	assert_eq(host.selected_index(), 1)
	assert_true(host._mart_selection().is_empty())
	assert_true(host.handle_button(PokeButton.A))
	assert_eq(host._mart_stage, Gen2WorldServiceScreen.MART_TOP)
	assert_true(host.handle_button(PokeButton.B))
	await get_tree().process_frame
	assert_null(_world_screen._service_host)


## `StandardMart`'s SELL row: `DepositSellPack` over the pack, the halved price
## and `MartBoughtText`.
func test_mart_overlay_sells_a_stack_at_half_price() -> void:
	await _open_world({7: 2})
	await _queue_service()

	var host: Gen2WorldServiceScreen = _world_screen._service_host
	assert_eq(host._mart_stage, Gen2WorldServiceScreen.MART_TOP)
	assert_true(host.handle_button(PokeButton.DOWN))
	assert_true(host.handle_button(PokeButton.A))
	assert_eq(host._mart_stage, Gen2WorldServiceScreen.MART_SELL)
	assert_eq(host._mart_sell_entries.size(), 1, JSON.stringify(host._mart_sell_entries))
	assert_eq(int(host._mart_sell_entries[0]["price"]), 60)

	assert_true(host.handle_button(PokeButton.A))
	assert_eq(host._mart_stage, Gen2WorldServiceScreen.MART_SELL_QUANTITY)
	## The dial is bounded by the stack, so up off the last one wraps to one.
	assert_true(host.handle_button(PokeButton.UP))
	assert_eq(host._mart_quantity, 2)
	assert_true(host.handle_button(PokeButton.UP))
	assert_eq(host._mart_quantity, 1)
	assert_true(host.handle_button(PokeButton.UP))

	assert_true(host.handle_button(PokeButton.A))
	assert_eq(host._mart_stage, Gen2WorldServiceScreen.MART_SELL_CONFIRM)
	assert_true(host.handle_button(PokeButton.A))
	assert_eq(_world_screen._world.state.item_quantity(7), 0)
	assert_eq(_world_screen._world.state.money(), 620)

	## An empty pack has nothing left to sell, so the box lands on the top menu.
	assert_eq(host._mart_stage, Gen2WorldServiceScreen.MART_TOP)
	assert_true(host.handle_button(PokeButton.B))
	await get_tree().process_frame
	assert_null(_world_screen._service_host)


func test_menu_overlay_cancel_resumes_with_false_script_value() -> void:
	_write_menu_request()
	_data = GameData.open_directory(Fixture.directory())
	await _open_world()
	await _queue_service()

	var host: Gen2WorldServiceScreen = _world_screen._service_host
	assert_not_null(host)
	assert_eq(host._title, "MENU")
	assert_eq(host.selected_index(), 0)
	assert_true(host.handle_button(PokeButton.B))
	await get_tree().process_frame
	assert_null(_world_screen._service_host)
	assert_false(_world_screen._world.script_input_waiting())


func test_two_dimensional_menu_uses_cached_grid_and_default_cursor() -> void:
	_write_2d_menu_request()
	_data = GameData.open_directory(Fixture.directory())
	await _open_world()
	await _queue_service()

	var host: Gen2WorldServiceScreen = _world_screen._service_host
	assert_not_null(host)
	assert_eq(host._title, "MENU")
	assert_eq(host.selected_index(), 1)
	assert_eq(host._menu.columns, 2)
	assert_eq(host._menu.options.size(), 4)

	assert_true(host.handle_button(PokeButton.LEFT))
	assert_eq(host.selected_index(), 0)
	assert_true(host.handle_button(PokeButton.DOWN))
	assert_eq(host.selected_index(), 2)
	assert_true(host.handle_button(PokeButton.A))
	await get_tree().process_frame
	assert_null(_world_screen._service_host)
	assert_false(_world_screen._world.script_input_waiting())


func test_pending_special_call_dispatches_the_imported_script() -> void:
	_write_phone_request()
	_data = GameData.open_directory(Fixture.directory())
	await _open_world()
	var staged: Dictionary = _world_screen._world.state.apply_changes({}, {}, {
		"pending_special_phone_call": 1,
	})
	assert_true(staged["ok"])
	var attempt: Dictionary = _world_screen._world.try_special_phone_call()
	assert_true(attempt["attempted"])
	_world_screen._show_script_results(attempt["results"])
	await get_tree().process_frame
	## The screen's own pump is what spends the two rings and shows what
	## finishing them produced.
	_world_screen.advance_frames(4 * Gen2WorldPhoneRing.TOTAL_FRAMES)
	await get_tree().process_frame
	assert_null(_world_screen._service_host)
	assert_true(_world_screen._world.script_input_waiting())
	## `writetext` prints and returns: the `waitbutton` behind it is what the
	## script is holding on, and the words are on the box either way.
	assert_eq(
		StringName(_world_screen._world.pending_script_input().get("type", &"")), &"button"
	)
	assert_eq(" ".join(_world_screen._text_box.text_lines()), "PHONE SCRIPT")
	## The first press completes the revealing page, as holding A does in
	## `PrintLetterDelay`; the second acknowledges it.
	_world_screen._advance_script_input()
	_world_screen._advance_script_input()
	await get_tree().process_frame
	assert_false(_world_screen._world.script_input_waiting())


func test_phone_list_shows_registered_numbers_and_can_close() -> void:
	_write_phone_request()
	_data = GameData.open_directory(Fixture.directory())
	await _open_world()
	var registered: Dictionary = _world_screen._world.state.apply_changes({}, {}, {
		"phone_contacts": {0: true},
	})
	assert_true(registered["ok"])
	_world_screen._open_phone_list()
	await get_tree().process_frame
	var host: Gen2WorldServiceScreen = _world_screen._service_host
	assert_not_null(host)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.CARD)
	assert_eq(host._pokegear.card(), Gen2PokegearScreen.CARD_PHONE)
	assert_eq(host._pokegear.selected_contact(), 0)
	## B on a card is that card's own `.quit`, which leaves the Pokegear.
	assert_true(host.handle_button(PokeButton.B))
	await get_tree().process_frame
	assert_null(_world_screen._service_host)


func test_phone_list_starts_the_source_timed_outgoing_ring() -> void:
	_write_phone_request()
	_data = GameData.open_directory(Fixture.directory())
	await _open_world()
	var registered: Dictionary = _world_screen._world.state.apply_changes({}, {}, {
		"phone_contacts": {0: true},
	})
	assert_true(registered["ok"])
	_world_screen._open_phone_list()
	await get_tree().process_frame
	var host: Gen2WorldServiceScreen = _world_screen._service_host
	assert_not_null(host)
	## The first A opens `PokegearPhoneContactSubmenu`, whose own first row is
	## CALL.
	assert_true(host.handle_button(PokeButton.A))
	assert_true(host.handle_button(PokeButton.A))
	await get_tree().process_frame
	assert_null(_world_screen._service_host)
	assert_true(_world_screen._world.phone_ring_active())
	assert_true(_world_screen._caption.text.contains("PHONE RING"))
	## The screen's own pump is what spends the two rings and shows what
	## finishing them produced.
	_world_screen.advance_frames(4 * Gen2WorldPhoneRing.TOTAL_FRAMES)
	await get_tree().process_frame
	assert_true(_world_screen._world.script_input_waiting())
	## `writetext` prints and returns: the `waitbutton` behind it is what the
	## script is holding on, and the words are on the box either way.
	assert_eq(
		StringName(_world_screen._world.pending_script_input().get("type", &"")), &"button"
	)
	assert_eq(" ".join(_world_screen._text_box.text_lines()), "PHONE SCRIPT")


## `PokegearPhone_MakePhoneCall.no_service`: a map the phone cannot reach refuses
## in front of `MakePhoneCallFromPokegear`, so the card says so over its own list
## and the call never happens. The button behind the `prompt` puts the opening
## question back.
func test_a_map_without_phone_service_refuses_the_call_on_the_card() -> void:
	_write_phone_request()
	_data = GameData.open_directory(Fixture.directory())
	await _open_world()
	var registered: Dictionary = _world_screen._world.state.apply_changes({}, {}, {
		"phone_contacts": {0: true},
	})
	assert_true(registered["ok"])
	_world_screen._world.current_map.phone_flag = 1
	_world_screen._open_phone_list()
	await get_tree().process_frame
	var host: Gen2WorldServiceScreen = _world_screen._service_host
	assert_not_null(host)
	assert_true(host.handle_button(PokeButton.A))
	assert_true(host.handle_button(PokeButton.A))
	await get_tree().process_frame
	assert_not_null(_world_screen._service_host, "the card stays open")
	assert_true(
		_row_text(host._pokegear._tilemap(), Gen2TownMapPage.CARD_TEXT_AT, 19)
			.begins_with(_data.pokegear_text("out_of_service"))
	)
	assert_false(_world_screen._world.phone_ring_active())
	assert_true(host.handle_button(PokeButton.A))
	assert_true(
		_row_text(host._pokegear._tilemap(), Gen2TownMapPage.CARD_TEXT_AT, 19)
			.begins_with(_data.pokegear_text("ask_who"))
	)


## `PokegearPhoneContactSubmenu`'s DELETE row and the yes/no box behind it:
## MOM is one of the two `CheckCanDeletePhoneNumber` refuses, so the contact the
## fixture registers is offered all three rows and answering YES drops it.
func test_the_phone_submenu_deletes_the_chosen_contact() -> void:
	_write_phone_request()
	_data = GameData.open_directory(Fixture.directory())
	await _open_world()
	assert_true(_world_screen._world.state.apply_changes({}, {}, {
		"phone_contacts": {0: true},
	})["ok"])
	_world_screen._open_phone_list()
	await get_tree().process_frame
	var host: Gen2WorldServiceScreen = _world_screen._service_host
	assert_true(host.handle_button(PokeButton.A))
	assert_eq(host._pokegear._submenu, ["CALL", "DELETE", "CANCEL"])
	host.handle_button(PokeButton.DOWN)
	host.handle_button(PokeButton.A)
	assert_true(host._pokegear._asking_delete)
	## The card's own box carries `PokegearAskDeleteText` while it is up.
	assert_eq(
		_row_text(host._pokegear._tilemap(), Gen2TownMapPage.CARD_TEXT_AT, 19),
		_data.pokegear_text("ask_delete")
	)
	host.handle_button(PokeButton.A)
	assert_false(host._pokegear._asking_delete)
	assert_false(_world_screen._world.state.has_phone_contact(0))
	assert_eq(host._pokegear.selected_contact(), -1)


func test_pokegear_clock_card_renders_source_time_and_returns_to_cards() -> void:
	await _open_world()
	_world_screen._world.set_world_clock(3, 0, 7)
	_world_screen._clock.day = 3
	_world_screen._clock.hour = 0
	_world_screen._clock.minute = 7
	_world_screen._open_pokegear()
	await get_tree().process_frame
	var host: Gen2WorldServiceScreen = _world_screen._service_host
	assert_not_null(host)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.CARD)
	assert_eq(host._pokegear.card(), Gen2PokegearScreen.CARD_CLOCK)
	## `Pokegear_UpdateClock` writes the weekday and `PrintHoursMins`' reading
	## into the card's own tilemap, which is what the screen draws from.
	var map: PackedInt32Array = host._pokegear._tilemap()
	assert_eq(_row_text(map, Gen2TownMapPage.CLOCK_DAY_AT, 9), "WEDNESDAY")
	assert_eq(_row_text(map, Gen2TownMapPage.CLOCK_TIME_AT, 8), "12:07 AM")
	## Any button quits the clock card, and `.quit` leaves the Pokegear.
	assert_true(host.handle_button(PokeButton.A))
	await get_tree().process_frame
	assert_null(_world_screen._service_host)


## The window-resolution panel this host used to keep beside its hardware layer
## is gone, and the layer that is left is shown from one rule rather than set by
## hand at each entrance, which is what left the old one standing behind the
## mode's own boxes. An overlay owns all 160x144, so nothing is drawn under it.
func test_only_one_service_layer_is_ever_on_screen() -> void:
	_write_pc_request()
	await _open_world()
	_world_screen._world.current_map.events["coord_events"][0]["script"] = 0x6190
	await _queue_service()
	var host: Gen2WorldServiceScreen = _world_screen._service_host
	assert_not_null(host)
	assert_true(host._service_view.visible, "the hardware layer draws the mode")
	## DEPOSIT ITEM's own list is still the one layer.
	host.handle_button(PokeButton.DOWN)
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_ITEM_LIST)
	assert_true(host._service_view.visible)
	## A screen of its own owns all 160x144, so nothing is drawn under it.
	host._open_town_map(false)
	assert_false(host._service_view.visible)
	host._town_map.close()
	await get_tree().process_frame


## `MenuTextbox` carries `MENU_BACKUP_TILES`: the map stays visible around the
## box, so the panel is drawn in the screen the map is already in rather than in
## a second one over it. Two screens over one window each pick their own scale
## and their own place for the hardware rectangle, and each paints a surround
## the other did not ask for, which is what cut the map back to 160x144 with
## black bars around it.
func test_a_menu_over_the_map_is_drawn_in_the_maps_own_screen() -> void:
	Gen2OptionsStore.use_test_path()
	Gen2OptionsStore.current().screen_fill = true
	_write_pc_request()
	await _open_world()
	_world_screen._world.current_map.events["coord_events"][0]["script"] = 0x6190
	await _queue_service()
	var host: Gen2WorldServiceScreen = _world_screen._service_host
	assert_not_null(host)
	assert_eq(host._service_hardware, _world_screen._screen, "the map's own screen")
	assert_eq(
		host.find_children("*", "Gen2Screen", true, false), [],
		"and no second one of its own",
	)
	assert_eq(
		Gen2Screen.owner_of(host._service_view), _world_screen._screen,
		"so the panel is laid out on the same 160x144 the map is drawn in",
	)
	## Nothing has said what the world's screen stands on, because the panel is
	## transparent everywhere but its own box. An untold screen paints no
	## surround, so what is around the box is the map.
	assert_false(_world_screen._screen.has_field())


## The other half of the same rule: the radio card is what writes
## `wPokegearRadioMusicPlaying`, so a Pokegear that opened one owes the map its
## music back. Dead air is `NoRadioMusic`, which owes it just as a station does.
func test_the_radio_card_is_what_owes_the_map_its_music_back() -> void:
	await _open_world()
	_world_screen._open_pokegear()
	await get_tree().process_frame
	var host: Gen2WorldServiceScreen = _world_screen._service_host
	assert_not_null(host)
	assert_eq(host.radio_music_playing(), Gen2WorldServiceScreen.RADIO_MUSIC_SILENT)
	host._open_card(Gen2PokegearScreen.CARD_RADIO)
	await get_tree().process_frame
	assert_eq(host._pokegear.card(), Gen2PokegearScreen.CARD_RADIO)
	assert_ne(host.radio_music_playing(), Gen2WorldServiceScreen.RADIO_MUSIC_SILENT)


## A run of a card's tilemap read back as text, which is what the page printed.
func _row_text(map: PackedInt32Array, at: Vector2i, length: int) -> String:
	var out: String = ""
	for column: int in length:
		out += Gen2Text.character(map[at.y * Gen2TownMapPage.COLUMNS + at.x + column])
	return out


func test_audio_request_decodes_and_starts_the_runtime_player() -> void:
	_write_audio_request()
	_data = GameData.open_directory(Fixture.directory())
	await _open_world()
	await _queue_service()

	assert_null(_world_screen._service_host)
	var audio_player: Node = _world_screen.get_node("AudioPlayer") as Node
	assert_not_null(audio_player)
	assert_not_null(audio_player.get_node("MusicPlayer").stream)
	assert_false(_world_screen._world.script_input_waiting())


func test_town_map_decoration_opens_fullscreen_and_closes_the_script_request() -> void:
	_write_service_cache()
	_write_request_script([
		Gen2WorldScript.raw_opcode(0x99), 0x00, Gen2WorldScript.END,
	], 0x6330)
	_data = GameData.open_directory(Fixture.directory())
	await _open_world()
	_world_screen._world.state.set_maptile_decoration(&"poster", 0x10)
	var waiting: Array = _world_screen._world.dispatch_script_events(Vector2i(7, 6))
	assert_eq(waiting.size(), 1)
	_world_screen._show_script_results(waiting)
	await get_tree().process_frame

	_world_screen._text_box.finish()
	_world_screen._advance_script_input()
	await get_tree().process_frame
	var host: Gen2WorldServiceScreen = _world_screen._service_host
	assert_not_null(host)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.TOWN_MAP)
	assert_not_null(host._town_map)
	assert_true(host._town_map.visible)
	## `_TownMap` touches no music, so nothing is owed on the way out: only the
	## radio card sets `wPokegearRadioMusicPlaying`, and only that restarts the
	## map's own track over the poster.
	assert_eq(
		host.radio_music_playing(), Gen2WorldServiceScreen.RADIO_MUSIC_SILENT
	)
	assert_true(host.handle_button(PokeButton.B))
	await get_tree().process_frame
	assert_null(_world_screen._service_host)
	assert_false(_world_screen._world.script_input_waiting())


func _write_service_cache() -> void:
	var items: Array = RomCache.read_json(RomCache.items_path(Fixture.directory()))
	for raw: Dictionary in items:
		if int(raw.get("number", 0)) == 7:
			raw["name"] = "ITEM7"
			raw["price"] = 120
			## `SellMenu` reads the pack rather than the shop's stock, and
			## `Gen2WorldPack.build` groups by the item's own type byte.
			raw["pocket"] = Gen2WorldPack.TYPE_ITEM
	RomCache.write_json(RomCache.items_path(Fixture.directory()), items)
	RomCache.write_json(RomCache.world_marts_path(Fixture.directory()), {
		"marts": [{"index": 0, "bank": Fixture.BANK, "address": 0x4000, "items": [7]}],
		"default": {"items": [7]}, "special": {},
	})
	RomCache.write_json(RomCache.world_audio_path(Fixture.directory()), {
		"music": [{"index": 0, "bank": Fixture.BANK, "address": 0x4000,
			"bytes": [0x00, 0x03, 0x40, 0xD4, 0x10, 0xFF], "byte_count": 6}],
		"sfx": [],
	})
	_write_request_script([0x94, 0, 0x00, 0x40, 0x91], 0x6320)


func _write_menu_request() -> void:
	_write_request_script([0x4F, 0x34, 0x12, 0x59, 0x91], 0x6320)
	RomCache.write_json(RomCache.world_menus_path(Fixture.directory()), {
		Gen2WorldScript.pointer_key(Fixture.BANK, 0x1234): {
			"bank": Fixture.BANK, "address": 0x1234, "options": ["YES", "NO"],
		},
	})


func _write_2d_menu_request() -> void:
	_write_request_script([0x4F, 0x34, 0x12, 0x58, 0x91], 0x6320)
	RomCache.write_json(RomCache.world_menus_path(Fixture.directory()), {
		Gen2WorldScript.pointer_key(Fixture.BANK, 0x1234): {
			"bank": Fixture.BANK, "address": 0x1234, "kind": "2d",
			"data_flags": 1 << 5, "rows": 2, "columns": 2,
			"options": ["A", "B", "C", "D"], "default": 2,
		},
	})


func _write_phone_request() -> void:
	_write_request_script([0x9C, 0x01, 0x00, 0x91], 0x6320)
	var scripts: Dictionary = RomCache.read_json(RomCache.world_scripts_path(Fixture.directory()))
	scripts[Gen2WorldScript.pointer_key(Fixture.BANK, 0x6400)] = [
		0x4B, Fixture.BANK, 0x00, 0x70, Gen2WorldScript.WAITBUTTON,
		0x9C, 0x00, 0x00, 0x91,
	]
	scripts[Gen2WorldScript.pointer_key(Fixture.BANK, 0x6500)] = [
		0x4B, Fixture.BANK, 0x00, 0x70, Gen2WorldScript.WAITBUTTON,
		0x9C, 0x00, 0x00, 0x91,
	]
	RomCache.write_json(RomCache.world_scripts_path(Fixture.directory()), scripts)
	var phone_text: Array = [Gen2WorldScript.TEXT_START]
	for byte: int in Gen2Text.encode("PHONE SCRIPT"):
		phone_text.append(byte)
	phone_text.append(Gen2WorldScript.TEXT_TERMINATOR)
	RomCache.write_json(RomCache.world_text_path(Fixture.directory()), {
		Gen2WorldScript.pointer_key(Fixture.BANK, 0x7000): phone_text,
	})
	RomCache.write_json(RomCache.world_phone_path(Fixture.directory()), {
		"contacts": [{
			"index": 0, "trainer_class": 1, "trainer_number": 2,
			"map_group": Fixture.MAP_GROUP + 1, "map_number": Fixture.MAP_NUMBER,
			"callee_time": Gen2WorldPhoneHost.TIME_ANY,
			"caller_time": Gen2WorldPhoneHost.TIME_ANY,
			"caller_script": {"bank": Fixture.BANK, "address": 0x6400},
			"callee_script": {"bank": Fixture.BANK, "address": 0x6500},
		}],
		"special_calls": [{
			"index": 0, "condition_kind": "anywhere", "contact": 0,
			"script": {"bank": Fixture.BANK, "address": 0x6500},
		}],
	})


func _write_audio_request() -> void:
	_write_request_script([0x7F, 0x00, 0x40, 0x91], 0x6320)


func _write_apricorn_request() -> void:
	_write_request_script([
		Gen2WorldScript.SPECIAL,
		Gen2WorldScriptRunner.SPECIAL_SELECT_APRICORN_FOR_KURT, 0x00,
		Gen2WorldScript.END,
	], 0x6320)


func test_apricorn_overlay_gives_kurt_the_chosen_quantity_and_resumes() -> void:
	_write_apricorn_request()
	_data = GameData.open_directory(Fixture.directory())
	await _open_world({APRICORN_RED: 4, APRICORN_BLU: 2})
	await _queue_service()

	var host: Gen2WorldServiceScreen = _world_screen._service_host
	assert_not_null(host)
	assert_eq(host._title, "APRICORNS")
	assert_true(host.handle_button(PokeButton.DOWN))
	assert_true(host.handle_button(PokeButton.A))
	assert_true(host.handle_button(PokeButton.UP))
	assert_true(host.handle_button(PokeButton.A))
	await get_tree().process_frame

	assert_null(_world_screen._service_host)
	assert_false(_world_screen._world.script_input_waiting())
	assert_eq(_world_screen._world.state.item_quantity(APRICORN_BLU), 0)
	assert_eq(_world_screen._world.state.item_quantity(APRICORN_RED), 4)
	assert_eq(_world_screen._world.state.kurt_apricorn_quantity(), 2)


func test_apricorn_overlay_cancel_takes_nothing_and_resumes() -> void:
	_write_apricorn_request()
	_data = GameData.open_directory(Fixture.directory())
	await _open_world({APRICORN_RED: 4})
	await _queue_service()

	var host: Gen2WorldServiceScreen = _world_screen._service_host
	assert_not_null(host)
	assert_true(host.handle_button(PokeButton.B))
	await get_tree().process_frame

	assert_null(_world_screen._service_host)
	assert_false(_world_screen._world.script_input_waiting())
	assert_eq(_world_screen._world.state.item_quantity(APRICORN_RED), 4)
	assert_eq(_world_screen._world.state.kurt_apricorn_quantity(), 0)


func _write_request_script(script: Array, address: int) -> void:
	var scripts: Dictionary = RomCache.read_json(RomCache.world_scripts_path(Fixture.directory()))
	scripts[Gen2WorldScript.pointer_key(Fixture.BANK, address)] = script
	RomCache.write_json(RomCache.world_scripts_path(Fixture.directory()), scripts)
	var maps: Array = RomCache.read_json(RomCache.world_maps_path(Fixture.directory()))
	for raw: Dictionary in maps:
		if int(raw.get("group", -1)) != Fixture.MAP_GROUP \
		or int(raw.get("number", -1)) != Fixture.MAP_NUMBER:
			continue
		var events: Dictionary = raw.get("events", {})
		events["coord_events"] = [{"x": 7, "y": 6, "script": address}]
		raw["events"] = events
	RomCache.write_json(RomCache.world_maps_path(Fixture.directory()), maps)


## `_PlayerDecorationMenu` behind the bedroom PC's DECORATION row: the category
## menu, one category's list, the action, and the machine closing on
## `wChangedDecorations` so the room's own callbacks run again.
func test_the_decoration_row_sets_a_decoration_up_and_closes_the_machine() -> void:
	_write_pc_request()
	await _open_world()
	_world_screen._world.current_map.events["coord_events"][0]["script"] = 0x6190
	_world_screen._world.state.set_event_flag(676, true)
	await _queue_service()

	var host: Gen2WorldServiceScreen = _world_screen._service_host
	assert_not_null(host)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_ITEMS)

	## WITHDRAW, DEPOSIT, TOSS, MAIL BOX, then DECORATION.
	for _step: int in 4:
		host.handle_button(PokeButton.DOWN)
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_DECO)
	assert_eq(host._pc_rows.size(), 2, JSON.stringify(host._pc_rows))

	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_DECO_LIST)
	assert_eq(int(host._pc_rows[0]["deco"]), Fixture.DECO_FEATHERY_BED)

	## The bed, its box, and then EXIT off the category menu.
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_TEXT)
	assert_eq(
		_world_screen._world.state.maptile_decoration(Gen2WorldDecoration.SLOT_BED),
		Fixture.DECO_FEATHERY_BED
	)
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_DECO)
	host.handle_button(PokeButton.DOWN)
	host.handle_button(PokeButton.A)
	await get_tree().process_frame
	assert_null(_world_screen._service_host, "a changed room closes the machine")
	assert_false(_world_screen._world.script_input_waiting())


## `_PlayerMailBoxMenu`: `InitMail` answers zero when the mailbox is empty, so
## the row prints `.EmptyMailboxText` instead of opening a list.
func test_an_empty_mailbox_prints_its_own_line_and_opens_no_list() -> void:
	_write_pc_request()
	await _open_world()
	_world_screen._world.current_map.events["coord_events"][0]["script"] = 0x6190
	await _queue_service()

	var host: Gen2WorldServiceScreen = _world_screen._service_host
	assert_not_null(host)
	for _step: int in 3:
		host.handle_button(PokeButton.DOWN)
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_ITEMS)
	assert_eq(host._status, Gen2WorldPC.MAILBOX_EMPTY)


## `MailboxPC`: the list prints one author a message, the submenu is
## `.SubMenuData`'s four rows, and READ MAIL opens `ReadAnyMail` over it.
func test_the_mailbox_lists_its_authors_and_reads_one() -> void:
	_write_pc_request()
	await _open_world()
	_world_screen._world.current_map.events["coord_events"][0]["script"] = 0x6190
	var save: Gen2SaveData = _world_screen._embedded_party_save()
	save.mailbox.append(Gen2SaveMail.compose(
		Gen2SaveMail.blank_message(), "GOLD", 0x1234, 1, Gen2MailPage.ITEM_NUMBERS[0]
	))
	await _queue_service()

	var host: Gen2WorldServiceScreen = _world_screen._service_host
	assert_not_null(host)
	for _step: int in 3:
		host.handle_button(PokeButton.DOWN)
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_MAILBOX)
	assert_eq(host._pc_rows.size(), 1)
	assert_eq(String(host._pc_rows[0]["name"]), "GOLD")

	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_MAIL_SUBMENU)
	assert_eq(host._pc_rows.size(), Gen2WorldPC.MAILBOX_ROWS.size())

	host.handle_button(PokeButton.A)
	assert_not_null(host._mail_reader)
	## `.loop` returns on A or B and on nothing else.
	assert_false(host.handle_button(PokeButton.DOWN))
	assert_true(host.handle_button(PokeButton.A))
	assert_null(host._mail_reader)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_MAILBOX)


## `.PutInPack`: the question first, then `ReceiveItem`, then the entry is
## deleted and `.MailClearedPutAwayText` printed.
func test_putting_a_message_in_the_pack_empties_the_mailbox() -> void:
	_write_pc_request()
	await _open_world()
	_world_screen._world.current_map.events["coord_events"][0]["script"] = 0x6190
	var save: Gen2SaveData = _world_screen._embedded_party_save()
	var item: int = Gen2MailPage.ITEM_NUMBERS[0]
	save.mailbox.append(Gen2SaveMail.compose(
		Gen2SaveMail.blank_message(), "GOLD", 0x1234, 1, item
	))
	await _queue_service()

	var host: Gen2WorldServiceScreen = _world_screen._service_host
	for _step: int in 3:
		host.handle_button(PokeButton.DOWN)
	host.handle_button(PokeButton.A)
	host.handle_button(PokeButton.A)
	host.handle_button(PokeButton.DOWN)
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_MAIL_CONFIRM)
	assert_eq(host._summary, Gen2WorldPC.MAILBOX_MESSAGE_LOST)

	host.handle_button(PokeButton.A)
	assert_eq(save.mailbox.size(), 0)
	assert_eq(_world_screen._world.state.item_quantity(item), 1)
	assert_eq(host._status, Gen2WorldPC.MAILBOX_CLEARED)


## `PCItemsJoypad`'s `.select_1` and `.moving_stuff_around` (`SwitchItemsInBag`).
## The withdraw and toss lists show `wPCItems` and reach it; a deposit is
## `DepositSellPack`, whose joypad handler has no SELECT in it.
func test_select_reorders_the_pc_item_list_but_not_the_deposit_list() -> void:
	_write_pc_request()
	await _open_world()
	_world_screen._world.state.apply_changes({}, {}, {
		"items": {7: 1}, "pc_items": {7: 1, 0x14: 1},
	})
	_world_screen._world.current_map.events["coord_events"][0]["script"] = 0x6190
	_world_screen._show_script_results(
		_world_screen._world.dispatch_script_events(Vector2i(7, 6))
	)
	await get_tree().process_frame
	var host: Gen2WorldServiceScreen = _world_screen._service_host

	## WITHDRAW ITEM, which is the PC's own list.
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_ITEM_LIST)
	assert_eq(_world_screen._world.state.pc_items().keys(), [7, 0x14])
	host.handle_button(PokeButton.SELECT)
	assert_eq(host._pc_switch, 0)
	host.handle_button(PokeButton.DOWN)
	host.handle_button(PokeButton.A)
	assert_eq(host._pc_switch, -1)
	assert_eq(_world_screen._world.state.pc_items().keys(), [0x14, 7])
	assert_eq(_pc_list_items(host), [0x14, 7], "and the list is drawn the new way")
	assert_eq(_world_screen._world.state.pc_item_quantity(7), 1, "nothing withdrawn")

	## DEPOSIT ITEM's own list answers SELECT with nothing.
	host.handle_button(PokeButton.B)
	host.handle_button(PokeButton.DOWN)
	host.handle_button(PokeButton.A)
	assert_eq(host._pc_action, Gen2WorldPC.PLAYERSPCITEM_DEPOSIT_ITEM)
	assert_false(host.handle_button(PokeButton.SELECT))
	assert_eq(host._pc_switch, -1)


func _pc_list_items(host: Gen2WorldServiceScreen) -> Array:
	var out: Array = []
	for entry: Dictionary in host._pc_entries:
		out.append(int(entry.get("item", 0)))
	return out
