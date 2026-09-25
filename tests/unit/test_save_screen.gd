extends GutTest

const Fixture := preload("res://tests/unit/battle_fixture.gd")

var _directory: String = ""
var _data: GameData = null
var _screen: Gen2SaveScreen = null
var _party_screen: Gen2PartyScreen = null
var _box_screen: Gen2BoxScreen = null
var _save_directory: String = ""


func before_each() -> void:
	_directory = RomCache.directory_for(&"screentest", "0123456789abcdef")
	_data = Fixture.build(_directory)
	_save_directory = "%s/testgame_01234567" % Gen2SaveStore.ROOT
	_clear_saves()


func after_each() -> void:
	# Slot refreshes detach the old cards before queueing them so a pressed card
	# is never freed while its own signal is running. Flush that deletion queue
	# before GUT counts objects that no longer belong to the screen tree.
	await get_tree().process_frame
	if is_instance_valid(_screen):
		_screen.free()
	_screen = null
	if is_instance_valid(_party_screen):
		_party_screen.free()
		_party_screen = null
	if is_instance_valid(_box_screen):
		_box_screen.free()
		_box_screen = null
	_clear_saves()
	RomCache.clear(_directory)
	Gen2ModHost.reset()


func _clear_saves() -> void:
	for slot: int in Gen2SaveStore.MAX_SLOTS:
		var path: String = Gen2SaveStore.path_for(_data.id, _data.sha1, slot)
		for copy: String in [path, "%s.bak" % path, "%s.tmp" % path, "%s.bak.tmp" % path]:
			if FileAccess.file_exists(copy):
				DirAccess.remove_absolute(copy)
	if DirAccess.dir_exists_absolute(_save_directory):
		DirAccess.remove_absolute(_save_directory)


func _save() -> Gen2SaveData:
	var mon: Gen2BattleMon = Gen2BattleMon.create(
		_data, Fixture.PIKACHU, 20, [Fixture.TACKLE, Fixture.THUNDERBOLT]
	)
	mon.status = Gen2Status.POISON
	var save: Gen2SaveData = Gen2SaveBattleAdapter.from_battle_party(
		_data.id, _data.sha1, 1, Gen2Party.of(mon), "RED"
	)
	(save.party[0] as Gen2SaveMon).nickname = "SPARKY"
	return save


func _save_with_two() -> Gen2SaveData:
	var save: Gen2SaveData = _save()
	var second: Gen2BattleMon = Gen2BattleMon.create(
		_data, Fixture.GEODUDE, 18, [Fixture.GROWL]
	)
	save.party.append(Gen2SaveBattleAdapter.from_battle_mon(second))
	return save


func _open_save_screen() -> void:
	var packed: PackedScene = load("res://game/save/save_screen.tscn")
	_screen = packed.instantiate()
	_screen.set_data(_data)
	add_child(_screen)
	await get_tree().process_frame


func _open_party_screen(save: Gen2SaveData) -> void:
	var packed: PackedScene = load("res://game/save/party_screen.tscn")
	_party_screen = packed.instantiate()
	_party_screen.set_context(_data, save)
	add_child(_party_screen)
	await get_tree().process_frame


func _open_box_screen(save: Gen2SaveData, mode: int = Gen2BoxScreen.MODE_DEPOSIT) -> void:
	var packed: PackedScene = load("res://game/save/box_screen.tscn")
	_box_screen = packed.instantiate()
	_box_screen.set_context(_data, save, true, false, mode)
	add_child(_box_screen)
	await get_tree().process_frame


## Slots are created on demand, so a game with no saves lists none at all and
## has nothing selected. The old screen preallocated three empty ones.
func test_save_screen_shows_no_slots_before_any_save_exists() -> void:
	await _open_save_screen()
	var snapshot: Dictionary = _screen.save_screen_snapshot()
	assert_eq(snapshot["selected_slot"], -1)
	assert_eq((snapshot["slots"] as Array).size(), 0)
	assert_eq(snapshot["status"], "", "the old bottom slot prompt is gone")
	for node: Node in _screen.find_children("*", "Label", true, false):
		assert_ne((node as Label).text, "Select a save slot.")
		assert_ne((node as Label).text, "SLOTS", "the slots heading is fully removed")
	var save_title: Label = _screen.find_child("SaveScreenTitle", true, false)
	var game_title: Label = _screen.find_child("SaveScreenGameTitle", true, false)
	assert_not_null(save_title)
	assert_not_null(game_title)
	assert_same(save_title.get_parent(), game_title.get_parent(),
		"game name shares the Save data heading row")
	assert_eq(game_title.horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT)
	assert_eq(game_title.autowrap_mode, TextServer.AUTOWRAP_OFF)
	assert_eq(game_title.get_line_count(), 1,
		"the game name stays on one line beside the expanding spacer")


func test_save_screen_distinguishes_an_occupied_slot() -> void:
	var write: Dictionary = Gen2SaveStore.save(_save(), _data)
	assert_true(write["ok"], write["message"])
	await _open_save_screen()
	var snapshot: Dictionary = _screen.save_screen_snapshot()
	# Only occupied slots are listed, so the one save is the only row and its
	# slot number is no longer its index.
	assert_eq((snapshot["slots"] as Array).size(), 1)
	var second: Dictionary = snapshot["slots"][0]
	assert_eq(second["slot"], 1)
	assert_true(second["exists"])
	assert_true(second["valid"])
	assert_true(_screen.select_slot(1))
	assert_eq(_screen.save_screen_snapshot()["selected_slot"], 1)


## A console browsing without a keyboard cannot type a name, so the export
## carries one already. It is also what the system dialogs suggest.
func test_an_exported_slot_is_named_after_the_cartridge_the_slot_and_its_label() -> void:
	assert_true(Gen2SaveStore.save(_save(), _data)["ok"])
	await _open_save_screen()
	assert_true(_screen.select_slot(1))
	assert_eq(_screen.export_file_name(), "testgame-slot-2.json")
	assert_true(Gen2SaveStore.rename_slot(_data.id, _data.sha1, 1, "Run two", _data)["ok"])
	_screen.set_data(_data)
	await get_tree().process_frame
	assert_true(_screen.select_slot(1))
	assert_eq(_screen.export_file_name(), "testgame-slot-2-run-two.json")


func test_save_screen_marks_an_invalid_existing_slot_incompatible() -> void:
	var path: String = Gen2SaveStore.path_for(_data.id, _data.sha1, 0)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"format_version": Gen2SaveData.FORMAT_VERSION,
		"game_id": String(_data.id),
		"rom_sha1": "different",
		"slot": 0,
		"player_name": "RED",
		"party": [],
	}))
	file.close()
	await _open_save_screen()
	var first: Dictionary = _screen.save_screen_snapshot()["slots"][0]
	assert_true(first["exists"])
	assert_false(first["valid"])
	assert_string_contains(first["message"], "different cartridge")


## The launcher no longer writes a save. `NewGame` reaches `InitializeWorld`
## only after the intro has run, so starting one stages the slot and the label
## and leaves the disk alone; [Gen2IntroScreen] writes it once the trainer has a
## name.
func test_starting_a_new_game_stages_the_slot_and_writes_nothing() -> void:
	await _open_save_screen()
	assert_true(_screen.create_new_game("Run one"))
	assert_false(
		Gen2SaveStore.exists(_data.id, _data.sha1, 0),
		"no slot on disk until the intro finishes"
	)
	assert_eq(GameRuntime.selected_game_id, _data.id)
	var waiting: Dictionary = GameRuntime.take_pending_new_game()
	assert_eq(int(waiting["slot"]), 0)
	assert_eq(String(waiting["label"]), "Run one")
	assert_eq(
		StringName(waiting["challenge"]), Gen2Rules.CHALLENGE_VANILLA,
		"the cartridge's own game unless the form said otherwise",
	)


## The one choice the launcher makes that the game cannot take back. It is
## staged with the slot rather than read out of the settings file, because the
## settings file is what the next run starts from and this one is fixed.
func test_the_new_game_form_stages_the_challenge_it_was_started_under() -> void:
	await _open_save_screen()
	assert_true(_screen.create_new_game("Locke", Gen2Rules.CHALLENGE_NUZLOCKE))
	assert_eq(
		StringName(GameRuntime.take_pending_new_game()["challenge"]),
		Gen2Rules.CHALLENGE_NUZLOCKE,
	)

	assert_true(_screen.open_new_slot())
	assert_true(_screen.create_new_game("Typo", &"impossible"))
	assert_eq(
		StringName(GameRuntime.take_pending_new_game()["challenge"]),
		Gen2Rules.CHALLENGE_VANILLA,
		"a challenge this build does not name is the cartridge's own game",
	)


## The only name the launcher takes is the save's own. The field is the slot
## label's, not the trainer's, and it accepts the label's own length rather than
## the trainer name's ten.
func test_the_new_game_form_asks_for_a_save_name_not_a_trainer_name() -> void:
	await _open_save_screen()
	assert_true(_screen.open_new_slot())
	assert_true(_screen.save_screen_snapshot()["new_game_form"])
	assert_true(
		_screen.create_new_game("Second playthrough"),
		"a label past the trainer name's limit is still accepted"
	)
	GameRuntime.take_pending_new_game()


## A finished Nuzlocke is a file to look at rather than a game to walk back
## into. The row says so, and the seam behind the missing Continue button says
## so too, so a driver cannot open one either.
func test_a_finished_nuzlocke_slot_is_never_continued() -> void:
	var save: Gen2SaveData = _save()
	save.run_rules = Gen2Rules.new()
	save.run_rules.challenge = Gen2Rules.CHALLENGE_NUZLOCKE
	Gen2Nuzlocke.end_run(save.nuzlocke, 12, 3)
	var write: Dictionary = Gen2SaveStore.save(save, _data)
	assert_true(write["ok"], write["message"])
	await _open_save_screen()

	var row: Dictionary = (_screen.save_screen_snapshot()["slots"] as Array)[0]
	assert_true(bool(row["run_over"]), "the row carries the verdict")
	assert_eq(String(row["challenge"]), String(Gen2Rules.CHALLENGE_NUZLOCKE))

	assert_true(_screen.select_slot(1))
	_screen._continue_selected()
	assert_eq(
		_screen.save_screen_snapshot()["status"], "This run is over.",
		"and the world is never opened",
	)


func test_a_save_name_past_its_own_limit_is_refused() -> void:
	await _open_save_screen()
	assert_false(_screen.create_new_game("x".repeat(Gen2SaveData.MAX_LABEL + 1)))
	assert_eq(GameRuntime.pending_new_game_slot, -1, "nothing was staged")


func test_save_screen_rejects_an_invalid_sram_without_creating_a_slot() -> void:
	await _open_save_screen()
	var path: String = "user://save-screen-invalid.sav"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(PackedByteArray([0x01, 0x02, 0x03]))
	file.close()
	assert_false(_screen.import_sav_path(path))
	assert_false(Gen2SaveStore.exists(_data.id, _data.sha1, 0))
	DirAccess.remove_absolute(path)


func test_party_screen_exposes_saved_hp_status_and_empty_positions() -> void:
	var save: Gen2SaveData = _save()
	await _open_party_screen(save)
	var snapshot: Dictionary = _party_screen.party_snapshot()
	assert_eq(snapshot["player_name"], "RED")
	assert_eq(snapshot["slot"], 1)
	var members: Array = snapshot["members"]
	assert_eq(members.size(), Gen2SaveData.MAX_PARTY)
	assert_eq((members[0] as Dictionary)["name"], "SPARKY")
	assert_eq((members[0] as Dictionary)["status"], "POISON")
	assert_false((members[0] as Dictionary)["empty"])
	assert_true((members[1] as Dictionary)["empty"])


## `PartyMenuQualityPointers`' `.TMHM`, which `ChooseMonToLearnTMHM` reaches:
## `PlacePartyMonTMHMCompatibility` asks `CanLearnTMHMMove` of every member and
## prints ABLE or NOT ABLE where the bar would be.
func test_the_teach_list_marks_each_member_able_or_not_able() -> void:
	var species: Array = RomCache.read_json(RomCache.species_path(_directory))
	for raw: Dictionary in species:
		if int(raw.get("number", 0)) == Fixture.GEODUDE:
			raw["tmhm"] = [0, 0, 0, 0, 0, 0, 0, 0]
	RomCache.write_json(RomCache.species_path(_directory), species)
	_data = GameData.open_directory(_directory)
	await _open_party_screen(_save_with_two())
	_party_screen.open_selection(Gen2PartyScreen.PROMPT_CHOOSE)
	assert_false(_party_screen._quality_column(), "a plain choice keeps the bar")

	_party_screen.open_selection(
		Gen2PartyScreen.PROMPT_TEACH_WHICH, Gen2PartyScreen.ACTION_TEACH_TMHM,
		Fixture.TM01_MOVE
	)
	assert_true(_party_screen._quality_column())
	var qualities: Array = []
	for row: Dictionary in _party_screen._rows():
		qualities.append(String(row["quality"]))
	assert_eq(qualities, [Gen2PartyMenuPage.ABLE, Gen2PartyMenuPage.NOT_ABLE])


func test_box_screen_exposes_all_fourteen_fixed_boxes_and_slots() -> void:
	var save: Gen2SaveData = _save()
	await _open_box_screen(save)
	var snapshot: Dictionary = _box_screen.box_snapshot()
	var boxes: Array = snapshot["boxes"]
	assert_eq(boxes.size(), Gen2SaveData.BOX_COUNT)
	assert_eq((boxes[0]["slots"] as Array).size(), Gen2SaveBox.CAPACITY)
	assert_true((boxes[0]["slots"][0] as Dictionary)["empty"])


func test_pc_storage_moves_party_to_box_and_back_through_atomic_save() -> void:
	var save: Gen2SaveData = _save_with_two()
	var initial_write: Dictionary = Gen2SaveStore.save(save, _data)
	assert_true(initial_write["ok"], initial_write["message"])
	await _open_box_screen(save)
	assert_true(_box_screen.select_party_member(0))
	assert_true(_box_screen.deposit_selected_party())
	assert_eq(save.party.size(), 1)
	assert_not_null(save.boxes[0].slots[0])
	assert_true(_box_screen.select_box_slot(0))
	assert_true(_box_screen.withdraw_selected_box())
	assert_eq(save.party.size(), 2)
	assert_null(save.boxes[0].slots[0])
	var loaded: Dictionary = Gen2SaveStore.load_result(_data.id, _data.sha1, save.slot, _data)
	assert_true(loaded["ok"], loaded["message"])
	var restored: Gen2SaveData = loaded["save"]
	assert_eq(restored.party.size(), 2)
	assert_null(restored.boxes[0].slots[0])


## `CopyBoxmonSpecies` ends every list with the row its `ld a, -1` terminator
## becomes, and `BillsPC_PressDown` stops the cursor on it.
func test_box_screen_lists_the_party_with_a_cancel_row() -> void:
	var save: Gen2SaveData = _save_with_two()
	await _open_box_screen(save)
	var rows: Array = _box_screen.rows()
	assert_eq(rows.size(), 3)
	assert_eq(String((rows[0] as Dictionary)["name"]), "SPARKY")
	assert_true(bool((rows[2] as Dictionary)["cancel"]))
	for _press: int in 5:
		_box_screen.handle_button(PokeButton.DOWN)
	var snapshot: Dictionary = _box_screen.box_snapshot()
	assert_eq(int(snapshot["cursor"]) + int(snapshot["scroll"]), rows.size() - 1)


## `.a_button` opens `.Submenu` rather than moving anything, and its first row is
## the transfer the loaded list implies. Left and right are `MoveMonWithoutMail_
## DPad`'s alone, so neither reaches this screen.
func test_a_row_opens_the_submenu_and_its_first_row_is_the_transfer() -> void:
	var save: Gen2SaveData = _save_with_two()
	await _open_box_screen(save)
	_box_screen.handle_button(PokeButton.DOWN)
	_box_screen.handle_button(PokeButton.A)
	var open: Dictionary = _box_screen.box_snapshot()
	assert_eq(open["submenu"], Gen2BoxScreen.SUBMENU_ROWS)
	assert_eq(String(open["prompt"]), Gen2BoxScreen.PROMPT_WHATS_UP)
	assert_eq(save.party.size(), 2, "nothing moved on the way in")

	_box_screen.handle_button(PokeButton.A)
	assert_eq(save.party.size(), 1)
	assert_not_null(save.boxes[0].slots[0])
	assert_eq(String(_box_screen.box_snapshot()["prompt"]), "Stored GEODUDE!")

	assert_false(_box_screen.handle_button(PokeButton.RIGHT))
	assert_eq(int(_box_screen.box_snapshot()["loaded"]), Gen2BoxScreen.LOADED_PARTY)


## `BillsPC_CheckMail_PreventBlackout`'s three refusals, in its own order.
## `CheckCurPartyMonFainted` leaves out `wCurPartyMon`, which is the row under
## the cursor, so a party whose only standing Pokemon is the chosen one refuses;
## and `wBillsPC_MonHasMail` is `ItemIsMail` on that same row.
func test_the_party_list_refuses_a_transfer_that_would_leave_nobody_standing() -> void:
	var save: Gen2SaveData = _save_with_two()
	var third: Gen2BattleMon = Gen2BattleMon.create(
		_data, Fixture.GEODUDE, 12, [Fixture.GROWL]
	)
	save.party.append(Gen2SaveBattleAdapter.from_battle_mon(third))
	(save.party[1] as Gen2SaveMon).hp = 0
	(save.party[2] as Gen2SaveMon).hp = 0
	await _open_box_screen(save)

	# The cursor stands on the one Pokemon still up, and it is the one left out.
	_box_screen.handle_button(PokeButton.A)
	_box_screen.handle_button(PokeButton.A)
	assert_eq(String(_box_screen.box_snapshot()["prompt"]), Gen2BoxScreen.PROMPT_NO_USABLE)
	assert_eq(save.party.size(), 3, "nothing moved")

	# A fainted row has two others to fall back on, so only the mail stops it.
	_box_screen.handle_button(PokeButton.DOWN)
	(save.party[1] as Gen2SaveMon).hp = 4
	(save.party[1] as Gen2SaveMon).item = Gen2HeldItem.MAIL_ITEMS[0]
	_box_screen.handle_button(PokeButton.A)
	_box_screen.handle_button(PokeButton.A)
	assert_eq(
		String(_box_screen.box_snapshot()["prompt"]), Gen2BoxScreen.PROMPT_REMOVE_MAIL
	)
	assert_eq(save.party.size(), 3, "nothing moved")
	assert_true(
		bool(_box_screen._mon_state(save.party[1] as Gen2SaveMon)["mail"]),
		"and the listing draws the mail icon rather than the item one"
	)


## `engine/menus/save.asm`'s one sequence, which every save in the game runs:
## the routine's own question, `AskOverwriteSaveFile`, the SAVING box and
## `SavedTheGame`. Only `SaveMenu`'s half of it was built.
func test_the_save_sequence_asks_twice_and_then_spends_its_frames() -> void:
	var written: Array = []
	var prompt: Gen2SavePrompt = Gen2SavePrompt.open(
		Gen2SavePrompt.Kind.CHANGE_BOX, "RED",
		func() -> Dictionary:
			written.append(true)
			return {"ok": true}
	)
	## A three-line question carries no cursor until it has been prompted past.
	assert_eq(prompt.lines, Gen2SavePrompt.CHANGE_BOX_LINES)
	assert_eq(prompt.cursor, -1)
	prompt.confirm(true)
	assert_eq(prompt.cursor, 0)
	prompt.confirm(true)
	assert_eq(prompt.lines, Gen2SavePrompt.CHANGE_BOX_LINES, "the answer is held first")
	assert_false(prompt.reads_joypad(), "and no press is read meanwhile")
	_spend_answer_hold(prompt)
	assert_eq(prompt.lines, Gen2SavePrompt.OVERWRITE_LINES)
	prompt.confirm(true)
	prompt.confirm(true)
	_spend_answer_hold(prompt)
	assert_eq(prompt.step, Gen2SavePrompt.Step.SAVING)

	prompt.frames_elapsed(Gen2SavePrompt.SAVING_FRAMES - 1)
	assert_eq(written.size(), 0, "the box is up for sixteen frames first")
	prompt.frames_elapsed(1)
	assert_eq(written.size(), 1)
	assert_true(prompt.writing_now())
	prompt.frames_elapsed(Gen2SavePrompt.WRITE_FRAMES)
	assert_eq(prompt.step, Gen2SavePrompt.Step.SAVED)
	assert_true(prompt.sfx_owed())
	assert_eq(prompt.lines[0], "RED saved")
	prompt.frames_elapsed(Gen2SavePrompt.DONE_FRAMES)
	assert_true(prompt.finished())
	assert_false(prompt.refused())


## `.refused`'s carry, and `Link_SaveGame`, whose caller `TryQuickSave` asks no
## question of its own.
func test_a_no_refuses_and_the_link_save_opens_on_the_overwrite_question() -> void:
	var refused: Gen2SavePrompt = Gen2SavePrompt.open(
		Gen2SavePrompt.Kind.MOVE_MON, "RED", Callable()
	)
	assert_true(refused.confirm(true), "the first A is the _ContText prompt")
	assert_false(refused.confirm(false))
	_spend_answer_hold(refused)
	assert_true(refused.finished())
	assert_true(refused.refused())

	var quick: Gen2SavePrompt = Gen2SavePrompt.open(
		Gen2SavePrompt.Kind.LINK, "RED", func() -> Dictionary:
			return {"ok": false, "reason": &"disk_full"}
	)
	assert_eq(quick.step, Gen2SavePrompt.Step.OVERWRITE)
	quick.confirm(true)
	quick.confirm(true)
	_spend_answer_hold(quick)
	quick.frames_elapsed(Gen2SavePrompt.SAVING_FRAMES + Gen2SavePrompt.WRITE_FRAMES)
	## A write that failed is this port's own step, and it ends as a NO does.
	assert_eq(quick.step, Gen2SavePrompt.Step.FAILED)
	assert_string_contains(quick.lines[1], "disk_full")
	quick.confirm(true)
	assert_true(quick.refused())


## pokered's `SaveMenu`: `PrintSaveScreenText`'s 30 frames read no press, the
## file's own player is never asked `OlderFileWillBeErasedText`, `SaveGameData`
## runs before `NowSavingString`'s 120 frames, and `GameSavedText` owes `SFX_SAVE`.
func test_the_generation_1_save_holds_asks_once_and_writes_before_its_string() -> void:
	var written: Array = []
	var prompt: Gen2SavePrompt = Gen2SavePrompt.open(
		Gen2SavePrompt.Kind.GEN1_MENU, "RED",
		func() -> Dictionary:
			written.append(true)
			return {"ok": true}
	)
	assert_true(prompt.holding_info())
	assert_false(prompt.reads_joypad())
	assert_true(prompt.lines.is_empty(), "no text box under the info box yet")
	prompt.confirm(true)
	assert_eq(prompt.step, Gen2SavePrompt.Step.ASK, "a press during the hold is dropped")
	prompt.frames_elapsed(30)
	assert_false(prompt.holding_info())
	assert_eq(prompt.lines, Gen2SavePrompt.GEN1_ASK_LINES)
	assert_eq(prompt.cursor, 0)

	prompt.confirm(true)
	_spend_answer_hold(prompt)
	assert_eq(prompt.step, Gen2SavePrompt.Step.SAVING)
	assert_eq(prompt.lines, Gen2SavePrompt.GEN1_SAVING_LINES)
	assert_eq(written.size(), 1, "SaveGameData ran before the string went up")
	assert_true(prompt.writing_now())
	prompt.frames_elapsed(119)
	assert_eq(prompt.step, Gen2SavePrompt.Step.SAVING)
	prompt.frames_elapsed(1)
	assert_eq(prompt.step, Gen2SavePrompt.Step.SAVED)
	assert_true(prompt.sfx_owed())
	assert_eq(prompt.lines, ["RED saved", "the game!"])
	prompt.frames_elapsed(Gen2SavePrompt.DONE_FRAMES)
	assert_true(prompt.finished())

	var refused: Gen2SavePrompt = Gen2SavePrompt.open(
		Gen2SavePrompt.Kind.GEN1_MENU, "RED", Callable()
	)
	refused.frames_elapsed(30)
	refused.confirm(false)
	_spend_answer_hold(refused)
	assert_true(refused.refused())

	## Yellow: `ld c, 10` after the box, `SavingText` for 128 and 10 before
	## `SFX_SAVE`.
	var yellow: Gen2SavePrompt = Gen2SavePrompt.open(
		Gen2SavePrompt.Kind.YELLOW_MENU, "RED", func() -> Dictionary: return {"ok": true}
	)
	yellow.frames_elapsed(39)
	assert_true(yellow.holding_info())
	yellow.frames_elapsed(1)
	assert_eq(yellow.lines, Gen2SavePrompt.GEN1_ASK_LINES)
	yellow.confirm(true)
	_spend_answer_hold(yellow)
	assert_eq(yellow.lines, Gen2SavePrompt.YELLOW_SAVING_LINES)
	yellow.frames_elapsed(128)
	assert_eq(yellow.step, Gen2SavePrompt.Step.SAVED)
	assert_false(yellow.sfx_owed())
	yellow.frames_elapsed(10)
	assert_true(yellow.sfx_owed())
	yellow.frames_elapsed(30)
	assert_true(yellow.finished())


## `InterpretTwoOptionMenu`'s own `DelayFrames` behind an answered YES/NO.
func _spend_answer_hold(prompt: Gen2SavePrompt) -> void:
	prompt.frames_elapsed(Gen2WorldMenu.ANSWER_HOLD_FRAMES)


func _spend_insert_frames() -> void:
	_box_screen.advance_saving_frames(
		Gen2SavePrompt.LEAVE_ON_FRAMES + Gen2SavePrompt.INSERT_SAVED_FRAMES
	)


## `_MovePKMNWithoutMail`: left and right load another list, the submenu drops
## RELEASE, and the second A puts the Pokemon where the insert cursor stands.
func test_move_without_mail_reorders_a_list_and_moves_between_two() -> void:
	var save: Gen2SaveData = _save_with_two()
	var third: Gen2BattleMon = Gen2BattleMon.create(
		_data, Fixture.GEODUDE, 12, [Fixture.GROWL]
	)
	save.party.append(Gen2SaveBattleAdapter.from_battle_mon(third))
	(save.party[2] as Gen2SaveMon).nickname = "THIRD"
	await _open_box_screen(save, Gen2BoxScreen.MODE_MOVE)
	## `.Init` loads `wCurBox`, so the screen opens on the box rather than on the
	## party; left is what walks back to it.
	assert_eq(int(_box_screen.box_snapshot()["loaded"]), 1)
	assert_true(_box_screen.handle_button(PokeButton.LEFT))
	assert_eq(int(_box_screen.box_snapshot()["loaded"]), Gen2BoxScreen.LOADED_PARTY)

	## The third member to the front of the party.
	_box_screen.handle_button(PokeButton.DOWN)
	_box_screen.handle_button(PokeButton.DOWN)
	_box_screen.handle_button(PokeButton.A)
	assert_eq(_box_screen.box_snapshot()["submenu"], Gen2BoxScreen.SUBMENU_ROWS_MOVE)
	_box_screen.handle_button(PokeButton.A)
	assert_eq(
		String(_box_screen.box_snapshot()["prompt"]), Gen2BoxScreen.PROMPT_MOVE_WHERE
	)
	_box_screen.handle_button(PokeButton.UP)
	_box_screen.handle_button(PokeButton.UP)
	_box_screen.handle_button(PokeButton.A)
	## `MovePKMNWithoutMail_InsertMon`'s twenty frames and the twenty-four
	## `MoveMonWOMail_InsertMon_SaveGame` spends behind `SFX_SAVE`, which read no
	## joypad: the list only comes back once both are spent.
	assert_eq(
		String(_box_screen.box_snapshot()["prompt"]), Gen2SavePrompt.SAVING_LEAVE_ON
	)
	assert_true(_box_screen.handle_button(PokeButton.B))
	_spend_insert_frames()
	assert_eq(String((save.party[0] as Gen2SaveMon).nickname), "THIRD")
	assert_eq(save.party.size(), 3)

	## Left and right load another list, which only this mode answers.
	assert_true(_box_screen.handle_button(PokeButton.RIGHT))
	assert_eq(int(_box_screen.box_snapshot()["loaded"]), 1)
	assert_true(_box_screen.handle_button(PokeButton.LEFT))
	assert_eq(int(_box_screen.box_snapshot()["loaded"]), Gen2BoxScreen.LOADED_PARTY)

	## The same Pokemon into the first box, which is a different list.
	_box_screen.handle_button(PokeButton.A)
	_box_screen.handle_button(PokeButton.A)
	_box_screen.handle_button(PokeButton.RIGHT)
	_box_screen.handle_button(PokeButton.A)
	_spend_insert_frames()
	assert_eq(save.party.size(), 2)
	assert_not_null(save.boxes[0].slots[0])
	assert_eq(String((save.boxes[0].slots[0] as Gen2SaveMon).nickname), "THIRD")


## `BillsPC_ChangeBoxSubmenu.Name` writes `sBoxNames`, and `SetDefaultBoxNames`
## spells the default with no space in it.
func test_a_box_keeps_the_name_it_was_given_and_defaults_without_one() -> void:
	var save: Gen2SaveData = _save()
	assert_eq(save.box_name(0), "BOX1")
	assert_eq(save.box_name(Gen2SaveData.BOX_COUNT - 1), "BOX14")
	assert_true(save.set_box_name(0, "KANTO"))
	assert_eq(save.box_name(0), "KANTO")
	assert_eq(Gen2SaveData.from_dict(save.to_dict()).box_name(0), "KANTO")
	## An empty entry is the default again rather than a blank label.
	assert_true(save.set_box_name(0, ""))
	assert_eq(save.box_name(0), "BOX1")


## `_WithdrawPKMN` opens on `wCurBox` and its submenu says WITHDRAW.
func test_the_withdraw_list_opens_on_the_current_box() -> void:
	var save: Gen2SaveData = _save_with_two()
	assert_true(Gen2SaveStorage.deposit_party_to_box(save, _data, 1, 0, -1, false)["ok"])
	await _open_box_screen(save, Gen2BoxScreen.MODE_WITHDRAW)
	assert_eq(int(_box_screen.box_snapshot()["loaded"]), 1)
	assert_eq(String(_box_screen.rows()[0]["name"]), "GEODUDE")
	_box_screen.handle_button(PokeButton.A)
	assert_eq(_box_screen.box_snapshot()["submenu"], Gen2BoxScreen.SUBMENU_ROWS_WITHDRAW)
	_box_screen.handle_button(PokeButton.A)
	assert_eq(save.party.size(), 2)
	assert_null(save.boxes[0].slots[0])
	assert_eq(String(_box_screen.box_snapshot()["prompt"]), "Got GEODUDE!")


## `BillsPC_CheckMail_PreventBlackout` is asked before the transfer, so the last
## party member is refused with `PCString_ItsYourLastPKMN` and no reason symbol
## ever reaches the page.
func test_the_last_party_member_is_refused_with_the_sources_own_line() -> void:
	var save: Gen2SaveData = _save()
	await _open_box_screen(save)
	_box_screen.handle_button(PokeButton.A)
	_box_screen.handle_button(PokeButton.A)
	assert_eq(String(_box_screen.box_snapshot()["prompt"]), Gen2BoxScreen.PROMPT_LAST_MON)
	assert_eq(save.party.size(), 1)
	assert_null(save.boxes[0].slots[0])


## `.release` behind the submenu's third row, and the yes/no `PlaceYesNoBox`
## puts under it: NO leaves the mon where it is, YES is `RemoveMonFromPartyOrBox`.
func test_release_asks_before_it_removes_a_stored_pokemon() -> void:
	var save: Gen2SaveData = _save_with_two()
	assert_true(Gen2SaveStorage.deposit_party_to_box(save, _data, 1, 0, -1, false)["ok"])
	await _open_box_screen(save, Gen2BoxScreen.MODE_WITHDRAW)
	_box_screen.handle_button(PokeButton.A)
	_box_screen.handle_button(PokeButton.DOWN)
	_box_screen.handle_button(PokeButton.DOWN)
	_box_screen.handle_button(PokeButton.A)
	assert_eq(int(_box_screen.box_snapshot()["release"]), 0)
	assert_eq(String(_box_screen.box_snapshot()["prompt"]), Gen2BoxScreen.PROMPT_RELEASE)

	_box_screen.handle_button(PokeButton.B)
	_box_screen.advance_saving_frames(Gen2WorldMenu.ANSWER_HOLD_FRAMES)
	assert_not_null(save.boxes[0].slots[0], "NO leaves it where it is")

	_box_screen.handle_button(PokeButton.A)
	_box_screen.handle_button(PokeButton.A)
	_box_screen.advance_saving_frames(Gen2WorldMenu.ANSWER_HOLD_FRAMES - 1)
	assert_not_null(save.boxes[0].slots[0], "the answer stands for the whole hold")
	_box_screen.advance_saving_frames(1)
	assert_null(save.boxes[0].slots[0])
	assert_eq(String(_box_screen.box_snapshot()["prompt"]), "Bye, GEODUDE!")


## `BillsPC_IsMonAnEgg` stands in front of `PlaceYesNoBox` in both release
## routines, so an egg is refused with `PCString_NoReleasingEGGS` and never asked.
func test_an_egg_is_refused_release_without_a_question() -> void:
	var save: Gen2SaveData = _save_with_two()
	assert_true(Gen2SaveStorage.deposit_party_to_box(save, _data, 1, 0, -1, false)["ok"])
	(save.boxes[0].slots[0] as Gen2SaveMon).is_egg = true
	await _open_box_screen(save, Gen2BoxScreen.MODE_WITHDRAW)
	_box_screen.handle_button(PokeButton.A)
	_box_screen.handle_button(PokeButton.DOWN)
	_box_screen.handle_button(PokeButton.DOWN)
	_box_screen.handle_button(PokeButton.A)
	assert_eq(int(_box_screen.box_snapshot()["release"]), -1)
	assert_eq(String(_box_screen.box_snapshot()["prompt"]), Gen2BoxScreen.PROMPT_NO_EGGS)
	assert_not_null(save.boxes[0].slots[0])


## `PCMonInfo` hands the list's EGG species to `GetMonFrontpic`, which draws the
## egg's own picture in its own palette rather than the species it carries.
func test_an_egg_in_the_box_shows_the_egg_picture() -> void:
	_write_egg_pic()
	var save: Gen2SaveData = _save_with_two()
	assert_true(Gen2SaveStorage.deposit_party_to_box(save, _data, 1, 0, -1, false)["ok"])
	(save.boxes[0].slots[0] as Gen2SaveMon).is_egg = true
	await _open_box_screen(save, Gen2BoxScreen.MODE_WITHDRAW)
	## This cache carries no PC page to draw the list with, so the picture is
	## asked for directly with the row the cursor stands on.
	_box_screen._refresh_pic(save.boxes[0].slots[0])
	var shown: TextureRect = _box_screen.get("_pic")
	assert_not_null(shown.texture, "the selection has a picture")
	var expected: Image = Gen2PicImage.from_atlas(
		_data.atlas_indices("egg_front"), _data.atlas("egg_front"), _data.egg_pic(),
		_data.egg_palette()
	)
	var image: Image = shown.texture.get_image()
	assert_eq(image.get_size(), Vector2i(EGG_PIC_SIDE, EGG_PIC_SIDE))
	assert_eq(image.get_data(), expected.get_data())


## `EggPic`'s five-tile square, filled with an index the species atlas never
## uses so the two pictures cannot be taken for each other.
const EGG_PIC_SIDE: int = 5 * PokeTiles.TILE_WIDTH


func _write_egg_pic() -> void:
	var indices: PackedByteArray = PackedByteArray()
	indices.resize(EGG_PIC_SIDE * EGG_PIC_SIDE)
	indices.fill(2)
	RomCache.write_indices(RomCache.pic_path(_directory, "egg_front"), indices)
	var manifest: Dictionary = RomCache.read_json(RomCache.manifest_path(_directory))
	var atlases: Dictionary = manifest.get("atlases", {})
	atlases["egg_front"] = {
		"width": EGG_PIC_SIDE, "height": EGG_PIC_SIDE, "cell": EGG_PIC_SIDE,
		"columns": 1, "rows": 1,
	}
	manifest["atlases"] = atlases
	manifest["egg_pic"] = {"tiles": 5, "palette": {"normal": [0x001F, 0x7C00]}}
	RomCache.write_json(RomCache.manifest_path(_directory), manifest)
	_data = GameData.open_directory(_directory)


func test_pc_storage_refuses_depositing_the_last_party_member() -> void:
	var save: Gen2SaveData = _save()
	var result: Dictionary = Gen2SaveStorage.deposit_party_to_box(save, _data, 0, 0)
	assert_false(result["ok"])
	assert_eq(result["reason"], &"last_party_member")
	assert_eq(save.party.size(), 1)
	assert_null(save.boxes[0].slots[0])


## `RestorePPOfDepositedPokemon` behind PC_DEPOSIT, and PC_WITHDRAW's
## `CalcMonStats` with `xor a` over MON_STATUS and MON_MAXHP copied into MON_HP.
func test_a_deposit_restores_pp_and_a_withdrawal_heals() -> void:
	var save: Gen2SaveData = _save_with_two()
	(save.party[0] as Gen2SaveMon).pp[0] = 3
	(save.party[0] as Gen2SaveMon).hp = 5
	assert_true(Gen2SaveStorage.deposit_party_to_box(save, _data, 0, 0, -1, false)["ok"])
	var stored: Gen2SaveMon = save.boxes[0].slots[0]
	assert_eq(int(stored.pp[0]), int(_data.move(Fixture.TACKLE)["pp"]), "PP back on the way in")
	## A `box_struct` has no HP or status: stored, it is what `CalcBufferMonStats`
	## would rebuild.
	assert_eq(stored.hp, Gen2SaveBattleAdapter.to_battle_mon(_data, stored).max_hp())
	assert_eq(stored.status, Gen2Status.NONE)
	assert_true(Gen2SaveStorage.withdraw_box_to_party(save, _data, 0, 0, false)["ok"])
	var out: Gen2SaveMon = save.party[1]
	assert_eq(out.status, Gen2Status.NONE)
	assert_eq(out.hp, Gen2SaveBattleAdapter.to_battle_mon(_data, out).max_hp())


## Generation 1's `_MoveMon` copies BOXMON_STRUCT_LENGTH bytes each way, HP and
## status inside them, and restores nothing.
func test_a_generation_1_box_keeps_health_status_and_pp() -> void:
	_data.generation = RomRegistry.GEN1
	var save: Gen2SaveData = _save_with_two()
	(save.party[0] as Gen2SaveMon).pp[0] = 3
	(save.party[0] as Gen2SaveMon).hp = 5
	assert_true(Gen2SaveStorage.deposit_party_to_box(save, _data, 0, 0, -1, false)["ok"])
	assert_true(Gen2SaveStorage.withdraw_box_to_party(save, _data, 0, 0, false)["ok"])
	var out: Gen2SaveMon = save.party[1]
	assert_eq(int(out.pp[0]), 3)
	assert_eq(out.hp, 5)
	assert_eq(out.status, Gen2Status.POISON)


## Generation 2's `box_struct` stops at the level byte, so a boxed row is what
## `CalcBufferMonStats` rebuilds: full health, no status, and an egg's zero.
## Generation 1's `box_struct` carries both, and keeps them.
func test_a_boxed_pokemon_reads_healed_only_in_generation_2() -> void:
	var hurt: Gen2SaveMon = _save().party[0]
	hurt.hp = 5
	Gen2SaveStorage.boxed(_data, hurt)
	assert_eq(hurt.hp, Gen2SaveBattleAdapter.to_battle_mon(_data, hurt).max_hp())
	assert_eq(hurt.status, Gen2Status.NONE)

	var egg: Gen2SaveMon = _save().party[0]
	egg.is_egg = true
	Gen2SaveStorage.boxed(_data, egg)
	assert_eq(egg.hp, 0, "an egg has no health to restore")
	assert_eq(egg.status, Gen2Status.NONE)

	var untouched: Gen2SaveMon = _save().party[0]
	untouched.hp = 5
	Gen2SaveStorage.boxed(null, untouched)
	assert_eq(untouched.hp, 5, "no data, no stats to rebuild")

	_data.generation = RomRegistry.GEN1
	var gen1: Gen2SaveMon = _save().party[0]
	gen1.hp = 5
	Gen2SaveStorage.boxed(_data, gen1)
	assert_eq(gen1.hp, 5)
	assert_eq(gen1.status, Gen2Status.POISON)


## `SendNewMonToBox` writes a `box_struct` too, so a gift or a catch that lands
## in the box is stored the way a deposit is.
func test_a_pokemon_sent_to_a_full_partys_box_is_stored_healed() -> void:
	var save: Gen2SaveData = _save()
	while save.party.size() < Gen2SaveData.MAX_PARTY:
		save.party.append(Gen2SaveMon.from_dict(save.party[0].to_dict()))
	var sent: Gen2SaveMon = Gen2SaveMon.from_dict(save.party[0].to_dict())
	sent.hp = 5
	var placed: Dictionary = save.add_party_or_box(sent, _data)
	assert_eq(StringName(placed.get("destination", &"")), &"box")
	assert_eq(sent.hp, Gen2SaveBattleAdapter.to_battle_mon(_data, sent).max_hp())
	assert_eq(sent.status, Gen2Status.NONE)


func test_pc_storage_can_commit_in_memory_without_writing_slot() -> void:
	var save: Gen2SaveData = _save_with_two()
	var result: Dictionary = Gen2SaveStorage.deposit_party_to_box(save, _data, 0, 0, -1, false)
	assert_true(result["ok"])
	assert_false(result["persisted"])
	assert_eq(save.party.size(), 1)
	assert_not_null(save.boxes[0].slots[0])
	assert_false(Gen2SaveStore.exists(_data.id, _data.sha1, save.slot))


## Slot management. The store's own rules are covered by test_save_slots.gd;
## these check the screen reaches them and reports what happened.
func test_the_screen_opens_a_new_slot_at_the_lowest_free_number() -> void:
	var write: Dictionary = Gen2SaveStore.save(_save(), _data)
	assert_true(write["ok"], write["message"])
	await _open_save_screen()

	assert_true(_screen.open_new_slot())
	var snapshot: Dictionary = _screen.save_screen_snapshot()
	assert_eq(
		snapshot["selected_slot"], 0,
		"slot 1 is taken, so the new one is slot 0",
	)
	# The slot number alone is not the button working. A free slot has no row in
	# `slots_for`, and a details pane that refuses to draw one leaves the player
	# looking at an empty screen with no way to name a save.
	assert_true(snapshot["new_game"], "the form is asked for")
	assert_true(snapshot["new_game_form"], "and is actually on screen")


## A free slot is not a file, so the four things that act on the file are not
## offered on one. Cancelling back onto it leaves the slot described rather than
## blank.
func test_cancelling_a_new_slot_describes_it_instead_of_blanking_the_pane() -> void:
	assert_true(Gen2SaveStore.save(_save(), _data)["ok"])
	await _open_save_screen()

	assert_true(_screen.open_new_slot())
	_screen.cancel_new_game()
	var snapshot: Dictionary = _screen.save_screen_snapshot()

	assert_false(snapshot["new_game"])
	assert_false(snapshot["new_game_form"])
	assert_eq(snapshot["selected_slot"], 0, "still pointing at the free slot")


## The form opens on a game with no saves at all, which is the only way into a
## first playthrough from the launcher.
func test_a_game_with_no_saves_can_still_open_the_new_game_form() -> void:
	await _open_save_screen()
	assert_eq(_screen.save_screen_snapshot()["selected_slot"], -1, "nothing to select")

	assert_true(_screen.open_new_slot())
	var snapshot: Dictionary = _screen.save_screen_snapshot()

	assert_eq(snapshot["selected_slot"], 0)
	assert_true(snapshot["new_game_form"])
	assert_true(_screen.create_new_game())
	assert_eq(int(GameRuntime.take_pending_new_game()["slot"]), 0)


## The reported "the app exits after Create save": every details-pane button
## rebuilds the pane it sits in, so the node emitting `pressed` was one of the
## children `_refresh_details` freed outright, and the engine walked a destroyed
## object on the way back out of the signal. The API-driven cases above cannot
## see it, because nothing is emitting when they call.
func test_a_details_pane_button_survives_the_rebuild_it_triggers() -> void:
	assert_true(Gen2SaveStore.save(_save(), _data)["ok"])
	await _open_save_screen()
	assert_true(_screen.select_slot(1))
	_press_and_outlive("Rename")
	assert_eq(_screen.save_screen_snapshot()["status"], "Renamed slot 2.")

	assert_true(_screen.open_new_game(1))
	_press_and_outlive("Cancel")
	assert_false(_screen.save_screen_snapshot()["new_game_form"], "the form closed")

	assert_true(_screen.open_new_game(1))
	_press_and_outlive("Start game")
	assert_eq(int(GameRuntime.take_pending_new_game()["slot"]), 1, "the press did the work")


## Presses the pane button [param label] and asserts it is still a live object
## when its own `pressed` returns. Reading the pending new game after a frame
## would not: the press hands the tree a deferred scene change.
func _press_and_outlive(label: String) -> void:
	var button: Button = _find_button(_screen, label)
	assert_not_null(button, "%s is on the pane" % label)
	button.pressed.emit()
	assert_true(
		is_instance_valid(button),
		"%s is still alive when its own signal returns" % label,
	)


## First button under [param node] whose text is [param label], or null.
func _find_button(node: Node, label: String) -> Button:
	if node is Button and (node as Button).text == label:
		return node as Button
	for child: Node in node.get_children():
		var found: Button = _find_button(child, label)
		if found != null:
			return found
	return null


## `MonMenu_Stats` and `MonMenu_Move`, the two whole screens the party submenu
## opens over itself. Both are models with no nodes, so they are driven here
## rather than through the screen that embeds them.
func test_the_stats_screen_turns_its_three_pages_and_wraps_both_ways() -> void:
	var screen: Gen2MonStatsScreen = Gen2MonStatsScreen.create(_data, _save().party)
	assert_eq(int(screen.snapshot()["page"]), Gen2StatsScreenPage.PINK_PAGE)
	screen.handle_button(PokeButton.RIGHT)
	assert_eq(int(screen.snapshot()["page"]), Gen2StatsScreenPage.GREEN_PAGE)
	screen.handle_button(PokeButton.RIGHT)
	screen.handle_button(PokeButton.RIGHT)
	assert_eq(int(screen.snapshot()["page"]), Gen2StatsScreenPage.PINK_PAGE)
	screen.handle_button(PokeButton.LEFT)
	assert_eq(int(screen.snapshot()["page"]), Gen2StatsScreenPage.BLUE_PAGE)


func test_the_stats_screen_leaves_on_b_and_on_a_over_its_last_page() -> void:
	var screen: Gen2MonStatsScreen = Gen2MonStatsScreen.create(_data, _save().party)
	watch_signals(screen)
	screen.handle_button(PokeButton.A)
	screen.handle_button(PokeButton.A)
	assert_signal_not_emitted(screen, "closed")
	assert_eq(int(screen.snapshot()["page"]), Gen2StatsScreenPage.BLUE_PAGE)
	screen.handle_button(PokeButton.A)
	assert_signal_emitted(screen, "closed")


## `Gen2ModHost.register_stats_page`: a registered page is turned to after the
## blue one, wraps back to pink, and takes the blue page's job of answering A
## with the exit. The screen asks the host for the count rather than the caller,
## so every screen that embeds it gets the page.
func test_a_registered_page_joins_the_turn_order_and_becomes_the_last() -> void:
	assert_true(bool(Gen2ModHost.instance().register_stats_page(
		&"testmod", {"build": func(_page: Dictionary) -> Array: return []}
	)["ok"]))
	assert_eq(Gen2StatsScreenPage.page_count(), Gen2StatsScreenPage.NUM_PAGES + 1)
	var screen: Gen2MonStatsScreen = Gen2MonStatsScreen.create(_data, _save().party)
	watch_signals(screen)
	screen.handle_button(PokeButton.LEFT)
	assert_eq(int(screen.snapshot()["page"]), Gen2StatsScreenPage.BLUE_PAGE + 1)
	screen.handle_button(PokeButton.RIGHT)
	assert_eq(int(screen.snapshot()["page"]), Gen2StatsScreenPage.PINK_PAGE)
	for _press: int in 3:
		screen.handle_button(PokeButton.A)
	assert_signal_not_emitted(screen, "closed")
	assert_eq(int(screen.snapshot()["page"]), Gen2StatsScreenPage.BLUE_PAGE + 1)
	screen.handle_button(PokeButton.A)
	assert_signal_emitted(screen, "closed")


## `StatusScreen2`'s press turns to a registered page on Generation 1 and the
## next press is the exit. Under the same ceiling of registered pages as
## Generation 2, counted from the cartridge's own two.
func test_a_registered_page_follows_the_moves_page_on_generation_1() -> void:
	var directory: String = RomCache.directory_for(&"gen1screentest", "0123456789abcdef")
	var gen1: GameData = Fixture.build(directory, "testgame", RomRegistry.GEN1)
	assert_true(bool(Gen2ModHost.instance().register_stats_page(
		&"testmod", {"build": func(_page: Dictionary) -> Array: return []}
	)["ok"]))
	assert_eq(Gen2StatsScreenPage.page_count(true), Gen2StatsScreenPage.GEN1_PAGES + 1)
	var screen: Gen2MonStatsScreen = Gen2MonStatsScreen.create(gen1, _save().party)
	watch_signals(screen)
	screen.handle_button(PokeButton.A)
	screen.handle_button(PokeButton.A)
	assert_signal_not_emitted(screen, "closed")
	assert_eq(
		int(screen.snapshot()["page"]),
		Gen2StatsScreenPage.PINK_PAGE + Gen2StatsScreenPage.GEN1_PAGES
	)
	screen.handle_button(PokeButton.A)
	assert_signal_emitted(screen, "closed")
	RomCache.clear(directory)


## The two halves of a Pokémon no cartridge page prints. A registered page is
## handed the snapshot and nothing else, so both are in it whether or not one is
## registered, and the copy is the mon's rather than the mon's own dictionary.
func test_the_snapshot_carries_the_dvs_and_stat_experience_a_page_cannot_reach() -> void:
	var save: Gen2SaveData = _save()
	var mon: Gen2SaveMon = save.party[0]
	mon.stat_exp["attack"] = 25600
	var page: Dictionary = Gen2MonStatsScreen.create(_data, save.party).snapshot()
	assert_eq(int(page["dvs"]), mon.dvs)
	assert_eq(int((page["stat_exp"] as Dictionary)["attack"]), 25600)
	(page["stat_exp"] as Dictionary)["attack"] = 0
	assert_eq(int(mon.stat_exp["attack"]), 25600)


## `_CGB_StatsScreenHPPals`' attrmap: the upper eight rows on the mon's own
## palette, the exp bar's ten cells on the exp palette, one slot per page
## indicator, and everything else on the HP palette `WipeAttrmap` leaves. The
## source's three blocks are fixed columns; a registered page moves the run, so
## the attrmap follows `page_indicators` rather than repeating them.
func test_the_stats_screen_attrmap_colours_the_upper_half_the_bars_and_the_pages() -> void:
	var columns: int = Gen2StatsScreenPage.COLUMNS
	var slots: PackedInt32Array = Gen2StatsScreenPage.attributes()
	assert_eq(slots[7 * columns + 19], Gen2StatsScreenPage.MON_SLOT, "the divider row")
	assert_eq(slots[8 * columns], 0, "the row under it is the HP palette's")
	assert_eq(slots[16 * columns + 10], Gen2StatsScreenPage.EXP_SLOT)
	assert_eq(slots[16 * columns + 9], 0, "the cell before the exp bar's cap")
	for index: int in Gen2StatsScreenPage.NUM_PAGES:
		var at: Vector2i = Gen2StatsScreenPage.page_indicators(
			Gen2StatsScreenPage.NUM_PAGES
		)[index]
		assert_eq(
			slots[at.y * columns + at.x], Gen2StatsScreenPage.FIRST_PAGE_SLOT + index
		)
	var four: PackedInt32Array = Gen2StatsScreenPage.attributes(
		Gen2StatsScreenPage.NUM_PAGES + 1
	)
	var moved: Vector2i = Gen2StatsScreenPage.page_indicators(
		Gen2StatsScreenPage.NUM_PAGES + 1
	)[0]
	assert_eq(
		four[moved.y * columns + moved.x], Gen2StatsScreenPage.FIRST_PAGE_SLOT,
		"a fourth page moves the run left and takes the first slot with it"
	)


## `.d_up` and `.d_down` neither wrap nor reach past the party, and each reload
## is a `PlayMonCry2`. The first member is poisoned rather than asleep or frozen,
## so `CheckFaintedFrzSlp` lets both cries through.
func test_the_stats_screen_walks_the_party_without_wrapping_and_cries() -> void:
	var screen: Gen2MonStatsScreen = Gen2MonStatsScreen.create(_data, _save_with_two().party)
	watch_signals(screen)
	assert_false(screen.handle_button(PokeButton.UP))
	assert_true(screen.handle_button(PokeButton.DOWN))
	assert_eq(screen.cursor(), 1)
	assert_false(screen.handle_button(PokeButton.DOWN))
	assert_eq(get_signal_emit_count(screen, "cry_requested"), 1)


## `PrepMonFrontpic` sets `wBoxAlignment` and `.AnimateEgg` writes TRUE itself,
## so the picture is mirrored. `.unown` and `.unownegg` clear it, because a
## mirrored Unown reads as the wrong letter, and an egg is `wCurPartySpecies`
## EGG rather than UNOWN, so it is mirrored like the rest.
func test_the_stats_pic_is_mirrored_for_everything_but_an_unown() -> void:
	assert_true(Gen2StatsScreenPage.pic_mirrored(Fixture.GEODUDE, false))
	assert_false(Gen2StatsScreenPage.pic_mirrored(Gen2Layout.UNOWN_SPECIES, false))
	assert_true(Gen2StatsScreenPage.pic_mirrored(Gen2Layout.UNOWN_SPECIES, true))


## `StatsScreen_PlaceFrontpic` opens on `GetUnownLetter`, so an Unown is drawn as
## the letter its DVs pick rather than as the species' own picture, and
## `EggStatsScreen` draws `GetEggFrontpic`'s.
func test_the_stats_pic_is_the_letter_for_an_unown_and_the_egg_for_an_egg() -> void:
	var letter: Dictionary = Gen2StatsScreenPage.pic_record(_data, {
		"species": Gen2Layout.UNOWN_SPECIES, "unown_form": 3, "egg": false,
	})
	assert_eq(String(letter.get("atlas", "")), "unown_front")
	assert_eq(int(letter.get("slot", -1)), 2, "the form counts from one")
	assert_eq(
		Gen2StatsScreenPage.pic_record(_data, {"species": Fixture.GEODUDE, "egg": true}),
		_data.egg_pic()
	)


## `.PrintNextLevel` and `.CalcExpToNextLevel` on the pink page: the debt is the
## curve's own next step less what the Pokémon has.
func test_the_pink_page_owes_the_experience_its_next_level_costs() -> void:
	var save: Gen2SaveData = _save()
	var mon: Gen2SaveMon = save.party[0]
	var screen: Gen2MonStatsScreen = Gen2MonStatsScreen.create(_data, save.party)
	var page: Dictionary = screen.snapshot()
	var rate: int = int(_data.species(mon.species).get("growth_rate", 0))
	assert_eq(int(page["next_level"]), mon.level + 1)
	assert_eq(
		int(page["exp_to_next"]),
		Gen2Experience.total_exp_at(rate, mon.level + 1) - mon.exp
	)


## `EggStatsScreen`'s four hints, chosen off the step counter the egg keeps in
## its happiness byte.
func test_the_egg_page_picks_its_hint_off_the_step_counter() -> void:
	assert_eq(Gen2StatsScreenPage.egg_message(0), Gen2StatsScreenPage.EGG_MESSAGES[0])
	assert_eq(Gen2StatsScreenPage.egg_message(6), Gen2StatsScreenPage.EGG_MESSAGES[1])
	assert_eq(Gen2StatsScreenPage.egg_message(11), Gen2StatsScreenPage.EGG_MESSAGES[2])
	assert_eq(Gen2StatsScreenPage.egg_message(41), Gen2StatsScreenPage.EGG_MESSAGES[3])


## `.place_move`: the two rows trade their move and their PP together, which is
## the second `.copy_move` over `wPartyMon1PP`.
func test_the_move_screen_trades_a_moves_pp_with_the_move() -> void:
	var save: Gen2SaveData = _save()
	var mon: Gen2SaveMon = save.party[0]
	mon.pp[1] = 3
	var before: Array = [mon.moves[0], mon.moves[1], mon.pp[0], mon.pp[1]]
	var screen: Gen2MoveScreen = Gen2MoveScreen.create(_data, save.party)
	screen.handle_button(PokeButton.A)
	screen.handle_button(PokeButton.DOWN)
	screen.handle_button(PokeButton.A)
	assert_eq(mon.moves[0], before[1])
	assert_eq(mon.moves[1], before[0])
	assert_eq(mon.pp[0], before[3])
	assert_eq(mon.pp[1], before[2])
	assert_eq(int(screen.snapshot()["held"]), -1)


## `.b_button` with something held is `.loop` again: the cursor goes back to the
## row that was picked up and the screen stays open.
func test_b_puts_a_held_move_back_rather_than_leaving() -> void:
	var save: Gen2SaveData = _save()
	var screen: Gen2MoveScreen = Gen2MoveScreen.create(_data, save.party)
	watch_signals(screen)
	screen.handle_button(PokeButton.DOWN)
	screen.handle_button(PokeButton.A)
	screen.handle_button(PokeButton.B)
	assert_signal_not_emitted(screen, "closed")
	assert_eq(int(screen.snapshot()["held"]), -1)
	assert_eq(int(screen.snapshot()["cursor"]), 1)
	screen.handle_button(PokeButton.B)
	assert_signal_emitted(screen, "closed")
	assert_eq(save.party[0].moves[0], Fixture.TACKLE)


## `.d_left` and `.d_right` return to `.joy_loop` untouched while a move is held,
## and the arrows are only drawn for a neighbour there is one.
func test_the_move_screen_refuses_to_change_pokemon_while_a_move_is_held() -> void:
	var save: Gen2SaveData = _save_with_two()
	var screen: Gen2MoveScreen = Gen2MoveScreen.create(_data, save.party)
	assert_false(screen.has_neighbour(-1))
	assert_true(screen.has_neighbour(1))
	screen.handle_button(PokeButton.A)
	assert_false(screen.handle_button(PokeButton.RIGHT))
	assert_eq(screen.cursor(), 0)
	screen.handle_button(PokeButton.B)
	assert_true(screen.handle_button(PokeButton.RIGHT))
	assert_eq(screen.cursor(), 1)


## `PokemonMenuEntries` and `GetMonFieldMoves` in front of it: Generation 1's
## submenu is the member's own field moves and then those three, with no MOVE
## row and no ITEM row at all.
func test_a_generation_1_member_is_offered_its_field_moves_stats_switch_and_cancel() -> void:
	var gen1: GameData = Fixture.build(
		RomCache.directory_for(&"gen1screentest", "0123456789abcdef"),
		"testgame", RomRegistry.GEN1
	)
	var mon := Gen2SaveMon.new()
	mon.species = Fixture.BULBASAUR
	mon.moves = [
		Gen2WorldFieldMove.MOVE_CUT, Fixture.TACKLE,
		Gen2WorldFieldMove.MOVE_STRENGTH, 0,
	]
	var labels: Array = []
	for row: Dictionary in Gen2PartyScreen.submenu_items_for(gen1, mon):
		labels.append(String(row.get("label", "")))
	assert_eq(labels.slice(2), ["STATS", "SWITCH", "CANCEL"])
	assert_eq(labels.size(), 5)
	RomCache.clear(RomCache.directory_for(&"gen1screentest", "0123456789abcdef"))


## A registered row is offered on Generation 1 after the cartridge's own three
## and before CANCEL, and widens the box the way a long field move does.
func test_a_generation_1_member_is_offered_a_registered_row_before_cancel() -> void:
	var gen1: GameData = Fixture.build(
		RomCache.directory_for(&"gen1screentest", "0123456789abcdef"),
		"testgame", RomRegistry.GEN1
	)
	Gen2ModHost.reset()
	Gen2ModHost.instance().register_party_member_menu(&"follow", {
		"label": func(_slot: int) -> String: return "FOLLOWING",
		"handler": func(_slot: int) -> void: pass,
	})
	var mon := Gen2SaveMon.new()
	mon.species = Fixture.BULBASAUR
	mon.moves = [Fixture.TACKLE, 0, 0, 0]
	var rows: Array = Gen2PartyScreen.submenu_items_for(gen1, mon, 1)
	var labels: Array = []
	for row: Dictionary in rows:
		labels.append(String(row.get("label", "")))
	assert_eq(labels, ["STATS", "SWITCH", "FOLLOWING", "CANCEL"])
	var box: Gen2MenuBox = Gen2PartyScreen.gen1_mon_menu_box(rows)
	assert_eq(Vector2i(box.left, box.top), Vector2i(8, 8))
	Gen2ModHost.reset()
	RomCache.clear(RomCache.directory_for(&"gen1screentest", "0123456789abcdef"))


## `DisplayFieldMoveMonMenu`: `hlcoord 11, 11` with no field move at all, and
## every one after that raising the top two rows and widening the box to the
## smallest `FieldMoveDisplayData` column its moves name. STRENGTH's is $0A.
func test_the_generation_1_submenu_box_grows_with_the_field_moves_in_it() -> void:
	var bare: Gen2MenuBox = Gen2PartyScreen.gen1_mon_menu_box([])
	assert_eq(Vector2i(bare.left, bare.top), Vector2i(11, 11))
	assert_eq(bare.item_position(0), Vector2i(13, 12))
	assert_eq(bare.cursor_position(0), Vector2i(12, 12))

	var cut: Gen2MenuBox = Gen2PartyScreen.gen1_mon_menu_box([
		{"kind": &"field_move", "move": Gen2WorldFieldMove.MOVE_CUT},
	])
	assert_eq(Vector2i(cut.left, cut.top), Vector2i(11, 8))
	assert_eq(cut.item_position(0), Vector2i(13, 10))

	var strength: Gen2MenuBox = Gen2PartyScreen.gen1_mon_menu_box([
		{"kind": &"field_move", "move": Gen2WorldFieldMove.MOVE_CUT},
		{"kind": &"field_move", "move": Gen2WorldFieldMove.MOVE_STRENGTH},
	])
	assert_eq(Vector2i(strength.left, strength.top), Vector2i(9, 6))
	assert_eq(strength.item_position(0), Vector2i(11, 8))
	## Four rows of two, the last landing on the interior's own bottom row.
	assert_eq(strength.item_position(4), Vector2i(11, 16))


## `ManagePokemonMoves`' own `cp EGG`, and `MonMenuOptions`' egg row set, which
## offers STATS and SWITCH and nothing else.
func test_an_egg_is_offered_stats_and_switch_and_no_move_row() -> void:
	var egg := Gen2SaveMon.new()
	egg.is_egg = true
	egg.species = Fixture.PIKACHU
	var rows: Array = Gen2PartyScreen.submenu_items_for(_data, egg)
	var options: Array = []
	for row: Dictionary in rows:
		options.append(StringName(row.get("option", &"")))
	assert_eq(options, [
		Gen2PartyScreen.OPTION_STATS, Gen2PartyScreen.OPTION_SWITCH,
		Gen2PartyScreen.OPTION_CANCEL,
	])
	var screen: Gen2MonStatsScreen = Gen2MonStatsScreen.create(_data, [egg])
	watch_signals(screen)
	## `EggStatsJoypad` answers A with `.quit` rather than with a page.
	screen.handle_button(PokeButton.A)
	assert_signal_emitted(screen, "closed")


## `BillsPCDepositFuncDeposit` ends with `xor a` into both cursor bytes, and
## `DepositPokemon` plays the stored Pokemon's cry on the way.
func test_a_deposit_puts_the_cursor_back_on_the_first_row_and_plays_a_cry() -> void:
	var save: Gen2SaveData = _save_with_two()
	var third: Gen2BattleMon = Gen2BattleMon.create(
		_data, Fixture.GEODUDE, 12, [Fixture.GROWL]
	)
	save.party.append(Gen2SaveBattleAdapter.from_battle_mon(third))
	await _open_box_screen(save)
	watch_signals(_box_screen)
	_box_screen.handle_button(PokeButton.DOWN)
	_box_screen.handle_button(PokeButton.DOWN)
	_box_screen.handle_button(PokeButton.A)
	_box_screen.handle_button(PokeButton.A)

	assert_eq(save.party.size(), 2)
	assert_signal_emitted_with_parameters(_box_screen, "cry_requested", [Fixture.GEODUDE])
	var snapshot: Dictionary = _box_screen.box_snapshot()
	assert_eq(int(snapshot["cursor"]), 0)
	assert_eq(int(snapshot["scroll"]), 0)
	assert_eq(snapshot["submenu"], [], "the submenu went with the row")


## `.box_full` prints and returns to `.Submenu`, which is still on screen; only
## `BillsPC_CheckMail_PreventBlackout` takes `BillsPCDepositFuncCancel` back to
## the list. Neither menu carries `STATICMENU_WRAP`.
func test_a_full_box_refuses_under_the_submenu_which_does_not_wrap() -> void:
	var save: Gen2SaveData = _save_with_two()
	for slot: int in Gen2SaveBox.CAPACITY:
		save.boxes[0].slots[slot] = Gen2SaveBattleAdapter.from_battle_mon(
			Gen2BattleMon.create(_data, Fixture.GEODUDE, 5, [Fixture.GROWL])
		)
	await _open_box_screen(save)
	watch_signals(_box_screen)
	_box_screen.handle_button(PokeButton.A)
	## Four rows, and up on the first stays on it.
	_box_screen.handle_button(PokeButton.UP)
	assert_eq(int(_box_screen.box_snapshot()["submenu_cursor"]), 0)
	for _press: int in 6:
		_box_screen.handle_button(PokeButton.DOWN)
	assert_eq(int(_box_screen.box_snapshot()["submenu_cursor"]), 3)

	for _press: int in 3:
		_box_screen.handle_button(PokeButton.UP)
	_box_screen.handle_button(PokeButton.A)
	assert_eq(save.party.size(), 2, "nothing left the party")
	var snapshot: Dictionary = _box_screen.box_snapshot()
	assert_eq(String(snapshot["prompt"]), Gen2BoxScreen.PROMPT_BOX_FULL)
	assert_eq(snapshot["submenu"], Gen2BoxScreen.SUBMENU_ROWS)
	assert_signal_emitted_with_parameters(
		_box_screen, "sfx_requested", [Gen2Sfx.SFX_WRONG, true]
	)


## `.a_button_2` reaches `.Init` without restoring the backup `.b_button_2` puts
## back, so the first pass resumes on the list the Pokemon was moved into.
func test_a_finished_move_stays_on_the_list_it_moved_into() -> void:
	var save: Gen2SaveData = _save_with_two()
	await _open_box_screen(save, Gen2BoxScreen.MODE_MOVE)
	_box_screen.handle_button(PokeButton.LEFT)
	assert_eq(int(_box_screen.box_snapshot()["loaded"]), Gen2BoxScreen.LOADED_PARTY)
	_box_screen.handle_button(PokeButton.A)
	_box_screen.handle_button(PokeButton.A)
	_box_screen.handle_button(PokeButton.RIGHT)
	_box_screen.handle_button(PokeButton.A)
	_spend_insert_frames()

	assert_eq(save.party.size(), 1)
	assert_eq(int(_box_screen.box_snapshot()["loaded"]), 1, "the box it went into")
	assert_eq(String(_box_screen.box_snapshot()["prompt"]), Gen2BoxScreen.PROMPT_CHOOSE)


## `.CheckTrivialMove`: the row the insert cursor points at has already shifted
## up by the one that left, so a move down the same list lands in front of it.
func test_a_move_down_one_list_lands_in_front_of_the_row_it_points_at() -> void:
	var save: Gen2SaveData = _save_with_two()
	for nickname: String in ["THIRD", "FOURTH"]:
		var extra: Gen2SaveMon = Gen2SaveBattleAdapter.from_battle_mon(
			Gen2BattleMon.create(_data, Fixture.GEODUDE, 12, [Fixture.GROWL])
		)
		extra.nickname = nickname
		save.party.append(extra)
	var moved: Dictionary = Gen2SaveStorage.move_mon(
		save, _data, Gen2BoxScreen.LOADED_PARTY, 0, Gen2BoxScreen.LOADED_PARTY, 2, false
	)
	assert_true(moved["ok"], String(moved.get("reason", "")))
	var order: Array[String] = []
	for mon: Gen2SaveMon in save.party:
		order.append(mon.nickname)
	assert_eq(order, ["", "SPARKY", "THIRD", "FOURTH"], "GEODUDE carries no nickname")
