extends GutTest

## Generation 1's PC (`ActivatePC`, `BillsPC_`, `PlayerPC`) through the world
## screen and the service host. The fixture is Generation 2's cache read as
## Red and Blue, which is how the start-menu tests reach the same machine.

const Fixture := preload("res://tests/integration/world_trainer_fixture.gd")

const STACK: int = 7
const POTION: int = 0x14
const NICKNAMES: Array[String] = ["ALPHA", "BRAVO", "CHARLIE"]

## `text_ram` slots stand in for `wStringBuffer` and `wNameBuffer`, which is all
## the fill reads; the words are short stand-ins.
const SPECIAL_TEXT: Dictionary = {
	"pc": {"accessed_someones": "Accessed SOMEONE's\nPC.", "accessed_mine": "Accessed my PC."},
	"oaks_pc": {"accessed": "Accessed OAK's PC.", "get_rated": "Get rated?", "closed": "Closed."},
	"bills_pc": {"what": "What?"},
	"bills_pc_sleeping": {"no_response": "There isn't any\nresponse."},
	"print_box": {"no_mon": "There are no\n#MON here!"},
	"bills_pc_2": {
		"once_released": "Once released,\n<RAM_CF4B> is\ngone forever. OK?",
		"mon_was_released": "<RAM_CD6D> was\nreleased.",
	},
	"toss": {
		"ok_to_toss": "Is it OK to toss\n<RAM_CF4B>?",
		"threw_away": "Threw away\n<RAM_CF4B>.",
	},
}

var _data: GameData = null
var _world_screen: Gen2WorldScreen = null


func before_each() -> void:
	Gen2ModHost.reset()
	_data = Fixture.build()
	var items: Array = RomCache.read_json(RomCache.items_path(Fixture.directory()))
	for raw: Dictionary in items:
		match int(raw.get("number", 0)):
			STACK:
				raw["name"] = "ITEM7"
			POTION:
				raw["name"] = "POTION"
	RomCache.write_json(RomCache.items_path(Fixture.directory()), items)
	var manifest: Dictionary = RomCache.read_manifest(Fixture.directory())
	var special: Dictionary = manifest.get("special_text", {})
	special.merge(SPECIAL_TEXT, true)
	manifest["special_text"] = special
	RomCache.write_json(RomCache.manifest_path(Fixture.directory()), manifest)
	_data = GameData.open_directory(Fixture.directory())
	_data.generation = RomRegistry.GEN1


func after_each() -> void:
	if is_instance_valid(_world_screen):
		_world_screen.free()
		_world_screen = null
	RomCache.clear(Fixture.directory())
	Gen2ModHost.reset()


## `ActivatePC`'s top menu over the map, with three mons in the current box and
## two stacks in the PC.
func _open_machine(mons: int = NICKNAMES.size()) -> Gen2WorldServiceScreen:
	var packed: PackedScene = load("res://game/world/world_screen.tscn")
	_world_screen = packed.instantiate() as Gen2WorldScreen
	_world_screen.map_group = Fixture.MAP_GROUP
	_world_screen.map_number = Fixture.MAP_NUMBER
	_world_screen.start_cell = Vector2i(7, 6)
	var state := Gen2WorldState.new({}, {}, {}, {0: 500})
	var world := Gen2WorldAPI.open(
		_data, Fixture.MAP_GROUP, Fixture.MAP_NUMBER, Vector2i(7, 6), state
	)
	var save := Gen2SaveStore.create_development_save(_data, 0)
	save.world = world.snapshot()
	save.party.resize(1)
	for slot: int in mons:
		var mon: Gen2SaveMon = Gen2SaveMon.from_dict(save.party[0].to_dict())
		mon.nickname = NICKNAMES[slot] if slot < NICKNAMES.size() else "MON%d" % slot
		save.boxes[0].slots[slot] = mon
	_world_screen.set_data(_data)
	_world_screen.set_save(save)
	add_child(_world_screen)
	await get_tree().process_frame
	_world_screen._world.state.apply_changes({}, {}, {"pc_items": {STACK: 5, POTION: 3}})
	_world_screen._open_service_overlay(&"pc")
	var host: Gen2WorldServiceScreen = _world_screen._service_host
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC)
	return host


## A top-menu row and the one box `ActivatePC` prints behind it.
func _take_top_row(host: Gen2WorldServiceScreen, row: int) -> void:
	for _step: int in row:
		host.handle_button(PokeButton.DOWN)
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_TEXT)
	Fixture.press_through(host)


## A row of `BillsPCMenu` onto its mon list, and the list walked to [param row].
func _open_mon_list(host: Gen2WorldServiceScreen, menu_row: int, row: int) -> void:
	_take_top_row(host, Gen2WorldPC.GEN1_PC_BILLS)
	for _step: int in menu_row:
		host.handle_button(PokeButton.DOWN)
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_MON_LIST)
	for _step: int in row:
		host.handle_button(PokeButton.DOWN)


func _box_names(host: Gen2WorldServiceScreen) -> Array:
	var out: Array = []
	for entry: Dictionary in Gen2WorldPC.gen1_box_entries(host._save, 0):
		out.append((entry["mon"] as Gen2SaveMon).nickname)
	return out


## `BillsPC_`'s `BillsPCMenu`: the accessed box, then the menu on its first row,
## and B off it is `ExitBillsPC` back to `ActivatePC`'s own menu.
func test_bills_pc_lands_on_its_own_menu() -> void:
	var host: Gen2WorldServiceScreen = await _open_machine()
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_TEXT)
	assert_true(host._box.is_revealing(), "`PCMainMenu` prints with the delay on")
	assert_eq(Fixture.box_words(host), "Accessed SOMEONE's\nPC.")
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_BOXES)
	assert_false(host._box.is_revealing(), "`BillsPC_` sets `BIT_NO_TEXT_DELAY`")
	assert_eq(host._pc_rows, Gen2WorldPC.gen1_bills_pc_menu())
	assert_eq(host._cursor, 0)
	host.handle_button(PokeButton.B)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC)


## Yellow's `BillsPCMenu` has PRINT BOX ahead of SEE YA and no `WhatText`. With no
## printer on the link `PrintPCBox` holds `Printer Error 2` over its first page
## until B, and an empty box answers `NoPokemonText`.
func test_yellow_bills_pc_print_box_holds_the_printer_error_until_b() -> void:
	_data.id = RomRegistry.YELLOW
	var host: Gen2WorldServiceScreen = await _open_machine()
	_take_top_row(host, Gen2WorldPC.GEN1_PC_BILLS)
	assert_eq(host._pc_rows.size(), 6)
	assert_eq(String(host._pc_rows[4]["name"]), "PRINT BOX")
	assert_eq(String(host._pc_rows[5]["name"]), "SEE YA!")
	assert_false(host._box.has_text_left(), "no WhatText")
	for _step: int in 4:
		host.handle_button(PokeButton.DOWN)
	host.handle_button(PokeButton.A)
	assert_true(host._pc_box_print)
	host.handle_button(PokeButton.A)
	assert_true(host._pc_box_print, "only B leaves the printer")
	host.handle_button(PokeButton.B)
	assert_false(host._pc_box_print)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_BOXES)
	assert_eq(host._cursor, 4)
	host.handle_button(PokeButton.DOWN)
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC, "SEE YA is row five now")


func test_yellow_print_box_on_an_empty_box_says_there_are_no_mon() -> void:
	_data.id = RomRegistry.YELLOW
	var host: Gen2WorldServiceScreen = await _open_machine(0)
	_take_top_row(host, Gen2WorldPC.GEN1_PC_BILLS)
	for _step: int in 4:
		host.handle_button(PokeButton.DOWN)
	host.handle_button(PokeButton.A)
	assert_false(host._pc_box_print)
	assert_eq(Fixture.box_words(host), "There are no\n#MON here!")


## `BillsPCDeposit` refuses the starter when `CheckPikachuFollowingPlayer` says it
## is not following (`jr z` lets a following one through).
func test_yellow_deposit_refuses_a_starter_that_is_not_following() -> void:
	var host: Gen2WorldServiceScreen = await _deposit_starter(false)
	assert_eq(Fixture.box_words(host), "There isn't any\nresponse.")
	host = await _deposit_starter(true)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_MON_ACTION)


## `HandlePartyMenuInput`: A on a starter that is not following prints its line
## and the menu returns as a cancelled one; `RedrawPartyMenu` draws it no icon.
func test_yellow_party_menu_answers_a_starter_that_is_not_following() -> void:
	await _deposit_starter(false)
	_world_screen._refresh_party_summary()
	_world_screen._open_embedded_party()
	var party: Gen2PartyScreen = _world_screen._party_host
	assert_true(bool(party._rows()[0]["hidden"]))
	assert_false(bool(party._rows()[1]["hidden"]))
	party.handle_button(PokeButton.A)
	assert_eq(String(party.submenu_snapshot()["message"]), "There isn't any\nresponse.")
	var box: Gen2TextBox = party.get("_message_box")
	for _frame: int in 600:
		if not box.is_revealing():
			break
		box.advance_frame()
	party.handle_button(PokeButton.A)
	assert_null(_world_screen._party_host, "the party menu closed")
	await get_tree().process_frame


func _deposit_starter(following: bool) -> Gen2WorldServiceScreen:
	if is_instance_valid(_world_screen):
		_world_screen.free()
	_data.id = RomRegistry.YELLOW
	var host: Gen2WorldServiceScreen = await _open_machine()
	var starter: Gen2SaveMon = host._save.party[0]
	starter.species = Gen2WorldFieldMove.SPECIES_PIKACHU
	starter.ot_id = host._save.player_id
	starter.original_trainer = host._save.player_name
	host._save.party.append(Gen2SaveMon.from_dict(starter.to_dict()))
	(host._save.party[1] as Gen2SaveMon).species = 1
	_world_screen._world.pikachu.set_following(following)
	_open_mon_list(host, Gen2WorldPC.GEN1_BILLS_PC_DEPOSIT, 0)
	host.handle_button(PokeButton.A)
	return host


## `BillsPCRelease`: `OnceReleasedText` names the mon under the cursor, its two
## pages are pressed through, and YES releases that one and no other.
func test_release_asks_about_and_releases_the_chosen_mon() -> void:
	var host: Gen2WorldServiceScreen = await _open_machine()
	_open_mon_list(host, Gen2WorldPC.GEN1_BILLS_PC_RELEASE, 1)
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_ASK)
	assert_eq(Fixture.box_words(host), "Once released,\nBRAVO is")
	host.handle_button(PokeButton.DOWN)
	host.handle_button(PokeButton.A)
	assert_eq(Fixture.box_words(host), "gone forever. OK?")
	assert_eq(host._cursor, 0, "the page's DOWN moved nothing")
	host.handle_button(PokeButton.A)
	assert_eq(_box_names(host), NICKNAMES, "the answer is held first")
	for _frame: int in Gen2WorldMenu.ANSWER_HOLD_FRAMES:
		host.advance_frame()
	assert_eq(_box_names(host), ["ALPHA", "CHARLIE"])
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_TEXT)
	assert_eq(Fixture.box_words(host), "BRAVO was\nreleased.")


## NO, and B which is NO's own answer: the list comes back on the row it left
## with every mon still in it.
func test_refusing_the_release_reopens_the_list_on_the_same_row() -> void:
	var host: Gen2WorldServiceScreen = await _open_machine()
	_open_mon_list(host, Gen2WorldPC.GEN1_BILLS_PC_RELEASE, 2)
	for refusal: Array in [[PokeButton.DOWN, PokeButton.A], [PokeButton.B]]:
		host.handle_button(PokeButton.A)
		Fixture.press_through(host)
		Fixture.print_out(host)
		assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_ASK)
		for button: int in refusal:
			host.handle_button(button)
		for _frame: int in Gen2WorldMenu.ANSWER_HOLD_FRAMES:
			host.advance_frame()
		assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_MON_LIST)
		assert_eq(host._cursor, 2)
		assert_eq(_box_names(host), NICKNAMES)


## `BillsPCWithdraw`'s `DisplayDepositWithdrawMenu` acts on the mon chosen on
## the list, not on the submenu's own row.
func test_withdraw_takes_the_chosen_mon_out() -> void:
	var host: Gen2WorldServiceScreen = await _open_machine()
	_open_mon_list(host, Gen2WorldPC.GEN1_BILLS_PC_WITHDRAW, 2)
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_MON_ACTION)
	host.handle_button(PokeButton.A)
	assert_eq(_box_names(host), ["ALPHA", "BRAVO"])
	assert_eq(host._save.party.size(), 2)
	assert_eq((host._save.party[1] as Gen2SaveMon).nickname, "CHARLIE")


## `JoypadLowSensitivity` waits thirty frames before the first repeat, and
## `HandleMenuInput_` repeats every five. A move inside the window waits on
## nothing else; a scroll reprints through `DisplayListMenuIDLoop`'s `Delay3` and
## `.loop1`'s, which is six frames. PyBoy on Red measures all three.
func test_a_held_direction_scrolls_the_mon_list_every_six_frames() -> void:
	var host: Gen2WorldServiceScreen = await _open_machine(12)
	_open_mon_list(host, Gen2WorldPC.GEN1_BILLS_PC_WITHDRAW, 0)
	var moves: Array[int] = Fixture.hold_down(
		func() -> void: host.handle_button(PokeButton.DOWN),
		func() -> int: return host._cursor, 62
	)
	assert_eq(moves, [30, 35, 41, 47, 53, 59])


## `PlayerPCToss`: `DisplayChooseQuantityMenu`, then `TossItem_`'s
## `IsItOKToTossItemText` naming the chosen stack, and YES tosses from it.
func test_toss_asks_about_and_tosses_the_chosen_stack() -> void:
	var host: Gen2WorldServiceScreen = await _open_machine()
	_take_top_row(host, Gen2WorldPC.GEN1_PC_PLAYERS)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_ITEMS)
	for _step: int in Gen2WorldPC.GEN1_PLAYERS_PC_TOSS:
		host.handle_button(PokeButton.DOWN)
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_ITEM_LIST)
	host.handle_button(PokeButton.DOWN)
	assert_eq(int(host._pc_entries[host._cursor]["item"]), POTION)
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_ITEM_QUANTITY)
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_ASK)
	assert_eq(Fixture.box_words(host), "Is it OK to toss\nPOTION?")
	## `IsItOKToTossItemText` ends in `prompt`: its press comes before the YES/NO.
	assert_null(host._yes_no_box())
	host.handle_button(PokeButton.A)
	assert_not_null(host._yes_no_box())
	host.handle_button(PokeButton.A)
	for _frame: int in Gen2WorldMenu.ANSWER_HOLD_FRAMES:
		host.advance_frame()
	var state: Gen2WorldState = _world_screen._world.state
	assert_eq(state.pc_item_quantity(POTION), 2)
	assert_eq(state.pc_item_quantity(STACK), 5)
	assert_eq(Fixture.box_words(host), "Threw away\nPOTION.")


## `PlayerPCToss`'s `jp .loop` keeps `wCurrentMenuItem`: a dial backed out of
## comes back on the row it left, and the menu's own cursor is untouched.
func test_the_toss_list_keeps_its_row_across_the_dial() -> void:
	var host: Gen2WorldServiceScreen = await _open_machine()
	_take_top_row(host, Gen2WorldPC.GEN1_PC_PLAYERS)
	for _step: int in Gen2WorldPC.GEN1_PLAYERS_PC_TOSS:
		host.handle_button(PokeButton.DOWN)
	host.handle_button(PokeButton.A)
	host.handle_button(PokeButton.DOWN)
	assert_eq(host._cursor, 1)
	host.handle_button(PokeButton.A)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_ITEM_QUANTITY)
	host.handle_button(PokeButton.B)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_ITEM_LIST)
	assert_eq(host._cursor, 1)
	host.handle_button(PokeButton.B)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_ITEMS)
	assert_eq(host._cursor, Gen2WorldPC.GEN1_PLAYERS_PC_TOSS, "the menu row it was opened from")


## `ActivatePC` waits for `SFX_ENTER_PC` before each machine's own box and for
## `SFX_TURN_OFF_PC` before LOG OFF returns, where neither effect was requested.
func test_the_top_menu_waits_out_its_enter_and_log_off_effects() -> void:
	var host: Gen2WorldServiceScreen = await _open_machine()
	var sounding: Array[bool] = [false]
	host.sound_busy = func(_watch: Dictionary) -> bool: return sounding[0]
	var played: Array[int] = []
	host.gen1_sfx_requested.connect(func(sound: int) -> void:
		played.append(sound)
		sounding[0] = true)
	host.handle_button(PokeButton.A)
	assert_eq(played, [Gen1Sfx.SFX_ENTER_PC])
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC, "the box waits behind the effect")
	assert_true(host.handle_button(PokeButton.A))
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC)
	sounding[0] = false
	host.advance_frame()
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_TEXT)
	Fixture.press_through(host)
	host.handle_button(PokeButton.B)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC)

	watch_signals(host)
	host.handle_button(PokeButton.B)
	assert_eq(played, [Gen1Sfx.SFX_ENTER_PC, Gen1Sfx.SFX_TURN_OFF_PC])
	assert_signal_not_emitted(host, "completed")
	sounding[0] = false
	host.advance_frame()
	assert_signal_emitted(host, "completed")


## `PlayPokedexRatingSfx`: the music stops, the owned count's own effect plays from
## its own bank, and `PlayDefaultMusic` brings the map's piece back only once it ends.
func test_oaks_rating_plays_its_effect_and_restores_the_map_music_after_it() -> void:
	var host: Gen2WorldServiceScreen = await _open_machine()
	_world_screen._world.state.set_engine_flag(Gen2WorldStartMenu.ENGINE_POKEDEX)
	host._pc_rows = Gen2WorldPC.gen1_top_menu(_data, _world_screen._world.state, "RED")
	var sounding: Array[bool] = [false]
	host.sound_busy = func(_watch: Dictionary) -> bool: return sounding[0]
	watch_signals(host)
	_take_top_row(host, 2)
	Fixture.print_out(host)
	assert_eq(host._mode, Gen2WorldServiceScreen.MODE.PC_OAK_ASK)
	Fixture.print_out(host)
	host.handle_button(PokeButton.A)
	for _frame: int in Gen2WorldMenu.ANSWER_HOLD_FRAMES:
		host.advance_frame()
	Fixture.press_through(host)
	sounding[0] = true
	Fixture.print_out(host)
	assert_signal_emitted_with_parameters(host, "music_requested", [0])
	var effect: Array[int] = Gen1Sfx.rating_effect(_world_screen._world.state.caught_count())
	assert_signal_emitted_with_parameters(host, "gen1_music_requested", [effect])
	assert_signal_not_emitted(host, "map_music_requested")
	assert_true(host.handle_button(PokeButton.A), "no press is read behind the effect")
	sounding[0] = false
	host.advance_frame()
	assert_signal_emitted(host, "map_music_requested")


## `TextScript_PokemonCenterPC` prints its boot line and hands the world a
## `pc_requested`; the machine it opens is `ActivatePC`'s, not Crystal's.
func test_a_scripted_pc_request_opens_activate_pcs_menu() -> void:
	var host: Gen2WorldServiceScreen = await _open_machine()
	host._finish([])
	var world: Gen2WorldAPI = _world_screen._world
	world._gen1_steps = [{"type": &"request", "values": {
		"kind": &"pc_requested", "values": {"mode": &"gen1_pokemon_center"},
	}}]
	var scripted: Gen2WorldServiceScreen = _world_screen._service_overlay()
	assert_true(scripted.open_pending(world, _data, _world_screen._injected_save, false))
	assert_eq(scripted._mode, Gen2WorldServiceScreen.MODE.PC)
	assert_true(scripted._gen1_pc)
