extends GutTest

## Party transactions run against the same synthetic world and battle cache as
## the scene integration tests. The cache shape is cartridge-shaped, but no ROM
## content is needed to test the atomic host boundary.

const Fixture := preload("res://tests/integration/world_trainer_fixture.gd")

var _data: GameData = null
var _world: Gen2WorldAPI = null
var _save: Gen2SaveData = null
var _random := RandomNumberGenerator.new()
## The fixture trade's two species names, which the boxes name rather than the
## row's nickname.
var _wanted: String = ""
var _offered: String = ""


func before_each() -> void:
	Gen2ModHost.reset()
	_data = Fixture.build()
	_add_party_item_metadata()
	_add_capture_metadata()
	_add_trade_record()
	_add_party_scripts()
	_add_party_evolution_metadata()
	_data = GameData.open_directory(Fixture.directory())
	var state := Gen2WorldState.new(
		{}, {}, {0x08: 1, 0x12: 1, 0x09: 1, 0x14: 1, 0x01: 1, 0x05: 1}
	)
	_world = Gen2WorldAPI.open(_data, Fixture.MAP_GROUP, Fixture.MAP_NUMBER, Vector2i(2, 2), state)
	_save = Gen2SaveStore.create_development_save(_data, 0)
	_save.world = _world.snapshot()
	_random.seed = 7


func after_each() -> void:
	Gen2ModHost.reset()
	RomCache.clear(Fixture.directory())


## `.onlyonemove` reads `wPartyMon1Moves + 1`, the second slot rather than a
## count, so a hole in the list is read as one move whatever stands behind it.
func test_move_deleter_reads_the_second_slot_not_a_move_count() -> void:
	var mon: Gen2SaveMon = _save.party[0]
	mon.is_egg = false
	mon.moves = [1, 0, 5, 0]
	assert_eq(Gen2MoveDeleter.ending_for(mon), Gen2MoveDeleter.ENDING_ONLY_ONE_MOVE)
	mon.moves = [1, 2, 0, 0]
	assert_eq(Gen2MoveDeleter.ending_for(mon), &"")
	mon.is_egg = true
	assert_eq(Gen2MoveDeleter.ending_for(mon), Gen2MoveDeleter.ENDING_EGG)


## `.DeleteMove`: the slots above come down and the last is zeroed, moves and PP
## in the same shape, so the two lists never fall out of step.
func test_deleting_a_move_shifts_its_pp_with_it() -> void:
	var mon: Gen2SaveMon = _save.party[0]
	mon.is_egg = false
	mon.moves = [10, 20, 30, 40]
	mon.pp = [11, 22, 33, 44]
	assert_true(Gen2MoveDeleter.delete_move(mon, 1))
	assert_eq(mon.moves, [10, 30, 40, 0])
	assert_eq(mon.pp, [11, 33, 44, 0])
	assert_true(Gen2MoveDeleter.delete_move(mon, 2))
	assert_eq(mon.moves, [10, 30, 0, 0])
	assert_eq(mon.pp, [11, 33, 0, 0])
	assert_false(Gen2MoveDeleter.delete_move(mon, 2), "an empty slot is not a move")


## `CheckIfMonIsYourOT` compares both halves: a member carrying the player's own
## name but a different ID is still a traded one, which is `.traded`.
func test_name_rater_refuses_a_traded_member_on_either_half() -> void:
	var mon: Gen2SaveMon = _save.party[0]
	mon.is_egg = false
	mon.original_trainer = "GOLD"
	mon.ot_id = 1234
	assert_true(Gen2NameRater.is_your_ot(mon, "GOLD", 1234))
	assert_false(Gen2NameRater.is_your_ot(mon, "GOLD", 4321))
	assert_false(Gen2NameRater.is_your_ot(mon, "KRIS", 1234))
	assert_eq(Gen2NameRater.ending_for(mon, "KRIS", 1234), Gen2NameRater.ENDING_TRADED)
	assert_eq(Gen2NameRater.ending_for(mon, "GOLD", 1234), &"")


## `AnimateMon_CheckIfPokemon`'s own refusal one routine further on: the egg
## check runs before `GetCurNickname`, so an egg never reaches the OT test.
func test_name_rater_refuses_an_egg_before_the_ot_test() -> void:
	var mon: Gen2SaveMon = _save.party[0]
	mon.is_egg = true
	mon.original_trainer = "SOMEONE"
	mon.ot_id = 9
	assert_eq(Gen2NameRater.ending_for(mon, "GOLD", 1234), Gen2NameRater.ENDING_EGG)


## `IsNewNameEmpty` and `CompareNewToOld`, the two refusals that reach
## `.samename` and leave the row's own nickname where it was.
func test_name_rater_treats_an_empty_or_unchanged_entry_as_unchanged() -> void:
	assert_true(Gen2NameRater.is_new_name_empty(""))
	assert_true(Gen2NameRater.is_new_name_empty("     "))
	assert_false(Gen2NameRater.is_new_name_empty(" A "))
	for entered: String in ["", "   ", "SPARKY"]:
		var settled: Dictionary = Gen2NameRater.ending_for_entry(entered, "SPARKY")
		assert_eq(settled["ending"], Gen2NameRater.ENDING_SAME_NAME, entered)
		assert_eq(settled["nickname"], "SPARKY", entered)
	var was_renamed: Dictionary = Gen2NameRater.ending_for_entry("BOLT", "SPARKY")
	assert_eq(was_renamed["ending"], Gen2NameRater.ENDING_FINISHED)
	assert_eq(was_renamed["nickname"], "BOLT")


## `GetNicknamenameLength` stops at MON_NAME_LENGTH - 1, so two entries that
## differ only past ten characters are the same name on the cartridge, and the
## `CopyBytes` that follows moves ten bytes.
func test_name_rater_compares_and_writes_ten_characters() -> void:
	var settled: Dictionary = Gen2NameRater.ending_for_entry(
		"ABCDEFGHIJKL", "ABCDEFGHIJ"
	)
	assert_eq(settled["ending"], Gen2NameRater.ENDING_SAME_NAME)
	var written: Dictionary = Gen2WorldPartyHost.rename_party_mon(
		_save, 0, "ABCDEFGHIJKL"
	)
	assert_true(written["ok"])
	assert_eq(_save.party[0].nickname, "ABCDEFGHIJ")


func test_rename_refuses_a_slot_no_party_row_stands_in() -> void:
	assert_false(Gen2WorldPartyHost.rename_party_mon(_save, -1, "BOLT")["ok"])
	assert_false(
		Gen2WorldPartyHost.rename_party_mon(_save, _save.party.size(), "BOLT")["ok"]
	)
	assert_eq(
		Gen2WorldPartyHost.rename_party_mon(_save, 0, "")["reason"], &"empty_nickname"
	)


func test_givepoke_appends_a_real_save_mon_and_resumes_the_script() -> void:
	_set_script(0x6200)
	var waiting: Array = _world.dispatch_script_events(Vector2i(2, 2))
	assert_eq(waiting[0]["status"], &"waiting")
	assert_eq(_world.pending_runtime_request()["kind"], &"pokemon_requested")

	var result: Dictionary = Gen2WorldHost.complete_runtime_request(
		_world, {}, _save, false, _random
	)
	assert_true(result["ok"])
	assert_eq(result["results"][0]["status"], &"complete")
	assert_eq(_save.party.size(), 3)
	assert_eq(_save.party[2].species, 25)
	assert_eq(_save.party[2].level, 5)
	assert_eq(_save.party[2].item, 0)


func test_giveegg_records_an_egg_without_pretending_it_can_battle() -> void:
	_set_script(0x6210)
	_world.dispatch_script_events(Vector2i(2, 2))
	var result: Dictionary = Gen2WorldHost.complete_runtime_request(
		_world, {}, _save, false, _random
	)
	assert_true(result["ok"])
	assert_eq(result["results"][0]["status"], &"complete")
	assert_true(_save.party[2].is_egg)
	assert_eq(_save.party[2].hp, 0)
	assert_eq(result["transaction"]["kind"], &"egg")


## `GiveANickname_YesNo` answered YES, then `InitNickname`. The screen owns both
## boxes; what the host owes is writing the answer into the row it just made.
func test_a_gift_takes_the_nickname_the_prompt_answered() -> void:
	_set_script(0x6200)
	_world.dispatch_script_events(Vector2i(2, 2))
	var result: Dictionary = Gen2WorldHost.complete_runtime_request(
		_world, {"nickname": "SPARKY"}, _save, false, _random
	)
	assert_true(result["ok"])
	assert_eq(_save.party[2].nickname, "SPARKY")


## `_GiveOddEgg` and `AddMobileMonToParty`: the row it rolls is appended as it
## stands, an egg under `.Odd`'s own OT, and the script carries on.
func test_the_odd_egg_is_appended_as_the_row_it_rolled() -> void:
	_set_script(0x6240)
	_world.dispatch_script_events(Vector2i(2, 2))
	assert_eq(_world.pending_runtime_request()["kind"], &"pokemon_requested")
	var result: Dictionary = Gen2WorldHost.complete_runtime_request(
		_world, {}, _save, false, _random
	)
	assert_true(result["ok"])
	assert_eq(result["results"][0]["status"], &"complete")
	assert_eq(_save.party.size(), 3)
	var egg: Gen2SaveMon = _save.party[2]
	assert_true(egg.is_egg)
	assert_eq(egg.level, Gen2Layout.ODD_EGG_LEVEL)
	assert_eq(egg.nickname, Gen2Layout.ODD_EGG_NICKNAME)
	assert_eq(egg.original_trainer, Gen2Layout.ODD_EGG_OT_NAME)
	assert_eq(result["transaction"]["kind"], &"odd_egg")


## An egg registers nothing in the Pokedex: `AddPartyMon` reads the species byte,
## which `AddMobileMonToParty` wrote EGG into.
func test_the_odd_egg_registers_no_species_as_caught() -> void:
	_set_script(0x6240)
	_world.dispatch_script_events(Vector2i(2, 2))
	Gen2WorldHost.complete_runtime_request(_world, {}, _save, false, _random)
	assert_false(_world.state.has_caught_species(_save.party[2].species))


## `.loop` takes the first cumulative word the roll is no greater than, so the
## edges of a band belong to it and the word above it belongs to the next.
func test_the_odd_egg_roll_takes_the_first_word_it_does_not_exceed() -> void:
	var probabilities: Array = [0x1000, 0x2000, 0xFFFF]
	assert_eq(Gen2WorldPartyHost.odd_egg_row(0, probabilities), 0)
	assert_eq(Gen2WorldPartyHost.odd_egg_row(0x1000, probabilities), 0)
	assert_eq(Gen2WorldPartyHost.odd_egg_row(0x1001, probabilities), 1)
	assert_eq(Gen2WorldPartyHost.odd_egg_row(0x2000, probabilities), 1)
	assert_eq(Gen2WorldPartyHost.odd_egg_row(0xFFFF, probabilities), 2)


## The script's own `readvar VAR_PARTYCOUNT` refuses ahead of the special, so a
## full party is only reachable by calling it directly, and it gives nothing.
func test_a_full_party_is_given_no_odd_egg() -> void:
	while _save.party.size() < Gen2SaveData.MAX_PARTY:
		_save.party.append(Gen2SaveMon.from_dict(_save.party[0].to_dict()))
	_set_script(0x6240)
	_world.dispatch_script_events(Vector2i(2, 2))
	var result: Dictionary = Gen2WorldHost.complete_runtime_request(
		_world, {}, _save, false, _random
	)
	assert_true(result["ok"])
	assert_eq(_save.party.size(), Gen2SaveData.MAX_PARTY)


## `CheckPartyFullAfterContest` is not a question: it copies `wContestMon` into
## the party, names it, writes LANDMARK_NATIONAL_PARK over the caught location
## and clears the stash. BUGCONTEST_CAUGHT_MON is the answer with a party slot.
func test_the_contest_catch_comes_home_and_is_named() -> void:
	_world.state.set_contest_mon({"species": 25, "level": 9, "hp": 4, "dvs": 0x9888})
	_set_script(0x6230)
	var waiting: Array = _world.dispatch_script_events(Vector2i(2, 2))
	assert_eq(waiting[0]["status"], &"waiting")
	assert_eq(_world.pending_runtime_request()["kind"], &"contest_mon_requested")

	var result: Dictionary = Gen2WorldHost.complete_runtime_request(
		_world, {"nickname": "BUZZ"}, _save, false, _random
	)
	assert_true(result["ok"])
	assert_eq(result["script_value"], Gen2WorldPartyHost.BUGCONTEST_CAUGHT_MON)
	assert_eq(_save.party.size(), 3)
	var caught: Gen2SaveMon = _save.party[2]
	assert_eq(caught.species, 25)
	assert_eq(caught.level, 9)
	assert_eq(caught.nickname, "BUZZ")
	assert_eq(caught.hp, 4, "the health it was standing there with")
	assert_eq(
		caught.caught_location, Gen2WorldPartyHost.LANDMARK_NATIONAL_PARK,
		"the map the results are collected on is overwritten"
	)
	assert_true(_world.state.contest_mon().is_empty(), "wContestMon is cleared")


## `.TryAddToBox` with room: the answer is BUGCONTEST_BOXED_MON, which is what
## makes the script print `ContestResults_PartyFullText`. The port used to answer
## BUGCONTEST_CAUGHT_MON here, because it read a full party and a full box.
func test_a_full_party_boxes_the_contest_catch_and_says_so() -> void:
	while _save.party.size() < Gen2SaveData.MAX_PARTY:
		_save.party.append(Gen2SaveMon.from_dict(_save.party[0].to_dict()))
	_world.state.set_contest_mon({"species": 25, "level": 9, "hp": 4, "dvs": 0x9888})
	_set_script(0x6230)
	_world.dispatch_script_events(Vector2i(2, 2))
	var result: Dictionary = Gen2WorldHost.complete_runtime_request(
		_world, {}, _save, false, _random
	)
	assert_true(result["ok"])
	assert_eq(result["script_value"], Gen2WorldPartyHost.BUGCONTEST_BOXED_MON)
	assert_eq(_save.party.size(), Gen2SaveData.MAX_PARTY)
	assert_eq(_save.boxes[0].slots[0].species, 25)
	assert_true(_world.state.contest_mon().is_empty())


## `.DidntCatchAnything`: no `wContestMonSpecies`, BUGCONTEST_NO_CATCH, and
## nothing written.
func test_no_contest_catch_answers_no_catch_and_writes_nothing() -> void:
	_set_script(0x6230)
	_world.dispatch_script_events(Vector2i(2, 2))
	var before: int = _save.party.size()
	var result: Dictionary = Gen2WorldHost.complete_runtime_request(
		_world, {}, _save, false, _random
	)
	assert_true(result["ok"])
	assert_eq(result["script_value"], Gen2WorldPartyHost.BUGCONTEST_NO_CATCH)
	assert_eq(_save.party.size(), before)


## `.skip_nickname` copies `wMonOrItemNameBuffer` over `sBoxMonNicknames` behind
## `InitNickname`, so a boxed gift always ends up with the species name.
func test_a_boxed_gift_keeps_the_species_name_over_the_answer() -> void:
	while _save.party.size() < Gen2SaveData.MAX_PARTY:
		_save.party.append(Gen2SaveMon.from_dict(_save.party[0].to_dict()))
	_set_script(0x6200)
	_world.dispatch_script_events(Vector2i(2, 2))
	var result: Dictionary = Gen2WorldHost.complete_runtime_request(
		_world, {"nickname": "SPARKY"}, _save, false, _random
	)
	assert_true(result["ok"])
	assert_eq(_save.boxes[0].slots[0].nickname, String(_data.species(25)["name"]))
	assert_eq(int(result["results"][0]["events"][0]["result"]["script_value"]), 1)


## `GiveEgg` is `TryAddMonToParty` and nothing else, so a full party boxes no egg
## and `Script_giveegg`'s own `xor a` is what the script reads.
func test_a_full_party_boxes_no_egg_and_answers_zero() -> void:
	while _save.party.size() < Gen2SaveData.MAX_PARTY:
		_save.party.append(Gen2SaveMon.from_dict(_save.party[0].to_dict()))
	var before: Dictionary = _save.to_dict()
	_set_script(0x6210)
	_world.dispatch_script_events(Vector2i(2, 2))
	var result: Dictionary = Gen2WorldHost.complete_runtime_request(
		_world, {}, _save, false, _random
	)
	assert_true(result["ok"])
	assert_false(result["transaction"]["accepted"])
	assert_eq(int(result["results"][0]["events"][0]["result"]["script_value"]), 0)
	assert_eq(_save.to_dict(), before)


## `DoNPCTrade` is `RemoveMonFromPartyOrBox` then `TryAddMonToParty`, so the
## Pokemon that arrives is last in the party and the slots behind the one that
## left move up. Every write after it is `Trade_GetAttributeOfLastPartymon`'s.
func test_npc_trade_uses_the_imported_record_and_appends_the_received_slot() -> void:
	var behind: int = _save.party[1].species
	_set_script(0x6220)
	_world.dispatch_script_events(Vector2i(2, 2))
	var result: Dictionary = Gen2WorldHost.complete_runtime_request(
		_world, {}, _save, false, _random
	)
	assert_true(result["ok"])
	assert_eq(_save.party.size(), 2)
	assert_eq(_save.party[0].species, behind, "the slot behind moved up")
	assert_eq(_save.party[1].species, 74)
	assert_eq(_save.party[1].nickname, "ROCKY")
	assert_eq(_save.party[1].original_trainer, "KYLE")
	assert_eq(_save.party[1].ot_id, 48926)
	## `SetGiftPartyMonCaughtData` with the dialog set's own `b`: zeroed level
	## and time bytes, LANDMARK_GIFT, and the gender bit only for a GIRL trader.
	assert_eq(_save.party[1].caught_level, 0)
	assert_eq(_save.party[1].caught_time, 0)
	assert_eq(_save.party[1].caught_location, Gen2WorldPartyHost.LANDMARK_GIFT)
	assert_eq(_save.party[1].caught_gender, 0)


## `NPCTrade`'s own conversation, which no map script carries: the flag it opens
## on, TRADE_DIALOG_INTRO, the `YesNoBox` over it, `SelectTradeOrDayCareMon` and
## the two boxes behind the swap. A NO is TRADE_DIALOG_CANCEL and writes nothing.
func test_a_refused_trade_prints_the_cancel_box_and_swaps_nothing() -> void:
	_add_trade_texts()
	var before: Dictionary = _save.to_dict()
	_set_script(0x6220)
	var asked: Array = _world.dispatch_script_events(Vector2i(2, 2))
	assert_eq(String(asked[0]["event"]["text"]), "I collect #MON.\nDo you have\n%s?" % _wanted)
	assert_eq(StringName(asked[0]["event"]["type"]), &"choice")
	var refused: Array = _world.run_event_queue(true, 1)
	assert_eq(String(refused[0]["event"]["text"]), "You don't want to\ntrade? Aww…")
	assert_eq(_world.run_event_queue(true)[0]["status"], &"complete")
	assert_eq(_save.to_dict(), before)


## The wrong species out of the list is TRADE_DIALOG_WRONG, and the flag is not
## set: `TradeFlagAction`'s SET_FLAG sits behind both tests.
func test_the_wrong_species_prints_the_wrong_box_and_leaves_the_flag_clear() -> void:
	_add_trade_texts()
	_set_script(0x6220)
	_world.dispatch_script_events(Vector2i(2, 2))
	_world.run_event_queue(true, 0)
	var wrong: Array = _world.complete_runtime_request({
		"ok": true, "party_index": 1, "species": 74, "dvs": [0x96, 0x66],
	})
	assert_eq(String(wrong[0]["event"]["text"]), "Huh? That's not\n%s." % _wanted)
	assert_eq(_world.run_event_queue(true)[0]["status"], &"complete")
	assert_false(_world.state.npc_trade_done(0))


## The whole of a trade that takes: the cable line, the swap, `TradedForText`,
## the three audio steps `PlayMusic MUSIC_NONE`, the fanfare and
## `RestartMapMusic`, then TRADE_DIALOG_COMPLETE. The flag is set in front of all
## of it, so a second visit is TRADE_DIALOG_AFTER and swaps nothing.
func test_a_trade_that_takes_runs_the_whole_conversation_and_sets_its_flag() -> void:
	_add_trade_texts()
	_set_script(0x6220)
	_world.dispatch_script_events(Vector2i(2, 2))
	_world.run_event_queue(true, 0)
	var cable: Array = _world.complete_runtime_request({
		"ok": true, "party_index": 0, "species": 155,
		"dvs": [(_save.party[0].dvs >> 8) & 0xFF, _save.party[0].dvs & 0xFF],
	})
	assert_eq(String(cable[0]["event"]["text"]), "OK, connect the\nGame Link Cable.")
	var swapped: Array = _world.run_event_queue(true)
	assert_eq(
		StringName(swapped[0]["event"]["request"]["kind"]), &"trade_requested",
		JSON.stringify(swapped)
	)
	var traded: Dictionary = Gen2WorldHost.complete_runtime_request(
		_world, {}, _save, false, _random
	)
	assert_eq(
		String(traded["results"][0]["event"]["text"]),
		"%s traded\n%s for\n%s." % [_save.player_name, _wanted, _offered]
	)
	var audio: Array = []
	var spent: Array = _world.run_event_queue(true)
	for _step: int in Gen2WorldScriptRunner.TRADE_AFTER_TEXT_AUDIO.size():
		audio.append(StringName(spent[0]["event"]["request"]["values"]["kind"]))
		spent = _world.complete_runtime_request({"ok": true})
	assert_eq(audio, [&"music", &"sound", &"map_music"] as Array)
	assert_eq(String(spent[0]["event"]["text"]), "Yay! I got myself\n%s!" % _wanted)
	assert_eq(_world.run_event_queue(true)[0]["status"], &"complete")
	assert_true(_world.state.npc_trade_done(0))

	_set_script(0x6220)
	var again: Array = _world.dispatch_script_events(Vector2i(2, 2))
	assert_eq(String(again[0]["event"]["text"]), "Hi, how's my old\n%s doing?" % _offered)
	assert_eq(_world.run_event_queue(true)[0]["status"], &"complete")


func test_explicit_trade_slot_still_checks_the_record_gender() -> void:
	var requested_battle: Gen2BattleMon = Gen2SaveBattleAdapter.to_battle_mon(
		_data, _save.party[0]
	)
	_data.world_trade(0)["gender"] = (
		Gen2Layout.TRADE_GENDER_FEMALE
		if requested_battle.gender() == Gen2BattleMon.GENDER_MALE
		else Gen2Layout.TRADE_GENDER_MALE
	)
	_set_script(0x6220)
	_world.dispatch_script_events(Vector2i(2, 2))
	var before: Dictionary = _save.to_dict()
	var result: Dictionary = Gen2WorldHost.complete_runtime_request(
		_world, {"party_index": 0}, _save, false, _random
	)
	assert_false(result["ok"])
	assert_eq(result["reason"], &"trade_candidate_gender_mismatch")
	assert_eq(_save.to_dict(), before)


func test_full_party_stores_a_gift_in_the_first_pc_box_slot() -> void:
	while _save.party.size() < Gen2SaveData.MAX_PARTY:
		var copy: Gen2SaveMon = Gen2SaveMon.from_dict(_save.party[0].to_dict())
		_save.party.append(copy)
	_set_script(0x6200)
	_world.dispatch_script_events(Vector2i(2, 2))
	var result: Dictionary = Gen2WorldHost.complete_runtime_request(
		_world, {}, _save, false, _random
	)
	assert_true(result["ok"])
	assert_true(result["transaction"]["accepted"])
	assert_eq(_save.party.size(), Gen2SaveData.MAX_PARTY)
	assert_eq(_save.boxes[0].slots[0].species, 25)
	assert_eq(result["transaction"]["destination"]["destination"], &"box")


## `.FailedToGiveMon`'s `ld b, $2`: nothing is written and the script reads 2
## and runs on, which is not a refusal the host may stop the script for.
func test_full_party_and_boxes_leave_a_gift_unwritten_and_answer_two() -> void:
	while _save.party.size() < Gen2SaveData.MAX_PARTY:
		_save.party.append(Gen2SaveMon.from_dict(_save.party[0].to_dict()))
	for box: Gen2SaveBox in _save.boxes:
		for slot: int in Gen2SaveBox.CAPACITY:
			box.slots[slot] = Gen2SaveMon.from_dict(_save.party[0].to_dict())
	var before: Dictionary = _save.to_dict()
	_set_script(0x6200)
	_world.dispatch_script_events(Vector2i(2, 2))
	var result: Dictionary = Gen2WorldHost.complete_runtime_request(
		_world, {}, _save, false, _random
	)
	assert_true(result["ok"])
	assert_false(result["transaction"]["accepted"])
	assert_eq(int(result["results"][0]["events"][0]["result"]["script_value"]), 2)
	assert_eq(_save.to_dict(), before)


func test_potion_cures_a_party_member_and_consumes_one_item() -> void:
	var mon: Gen2SaveMon = _save.party[0]
	mon.hp = 1
	var before_quantity: int = _world.state.item_quantity(0x12)
	var result: Dictionary = Gen2WorldPartyHost.use_item(
		_world, _save, 0x12, 0, false
	)
	assert_true(result["ok"])
	assert_gt(_save.party[0].hp, 1)
	assert_eq(_world.state.item_quantity(0x12), before_quantity - 1)


func test_item_with_no_effect_is_not_consumed() -> void:
	var before_quantity: int = _world.state.item_quantity(0x09)
	var result: Dictionary = Gen2WorldPartyHost.use_item(
		_world, _save, 0x09, 0, false
	)
	assert_false(result["ok"])
	assert_eq(_world.state.item_quantity(0x09), before_quantity)


## `_SacredAsh`: `CheckAnyFaintedMon` first, and then `SacredAshScript`'s
## `special HealParty`, which is the whole party rather than the fainted half.
func test_sacred_ash_heals_the_whole_party_once_one_member_has_fainted() -> void:
	_world.state.apply_changes({}, {}, {"items": {0x9C: 1}})
	_save.party[0].hp = 0
	_save.party[1].hp = 1
	_save.party[1].status = Gen2Status.POISON
	_save.party[1].pp[0] = 0

	var result: Dictionary = Gen2WorldPartyHost.use_item(_world, _save, 0x9C, -1, false)

	assert_true(result["ok"], JSON.stringify(result))
	assert_eq(result["effect"], &"sacred_ash")
	assert_eq(_world.state.item_quantity(0x9C), 0)
	for index: int in 2:
		var mon: Gen2SaveMon = _save.party[index]
		assert_eq(mon.hp, Gen2SaveBattleAdapter.to_battle_mon(_data, mon).max_hp())
		assert_eq(mon.status, Gen2Status.NONE)
	assert_eq(
		_save.party[1].pp[0], int(_data.move(int(_save.party[1].moves[0])).get("pp", 0))
	)


func test_sacred_ash_is_refused_and_kept_while_nothing_has_fainted() -> void:
	_world.state.apply_changes({}, {}, {"items": {0x9C: 1}})
	var result: Dictionary = Gen2WorldPartyHost.use_item(_world, _save, 0x9C, -1, false)
	assert_false(result["ok"])
	assert_eq(StringName(result["reason"]), &"item_has_no_effect")
	assert_eq(_world.state.item_quantity(0x9C), 1)


## `RareCandyEffect`: one level, `CalcExpAtLevel` back onto the experience, and
## the max-HP delta added to the current HP rather than a heal.
func test_a_rare_candy_adds_one_level_and_the_maximum_it_brought_with_it() -> void:
	_world.state.apply_changes({}, {}, {"items": {Gen2WorldPartyHost.ITEM_RARE_CANDY: 1}})
	var mon: Gen2SaveMon = _save.party[0]
	mon.hp = 1
	var level: int = mon.level
	var before_max: int = Gen2SaveBattleAdapter.to_battle_mon(_data, mon).max_hp()

	var result: Dictionary = Gen2WorldPartyHost.use_item(
		_world, _save, Gen2WorldPartyHost.ITEM_RARE_CANDY, 0, false
	)

	assert_true(bool(result["ok"]), JSON.stringify(result))
	assert_eq(_save.party[0].level, level + 1)
	assert_eq(int(result["level"]), level + 1)
	var after_max: int = Gen2SaveBattleAdapter.to_battle_mon(_data, _save.party[0]).max_hp()
	assert_eq(_save.party[0].hp, 1 + (after_max - before_max))
	assert_eq(
		_save.party[0].exp,
		Gen2Experience.total_exp_at(
			int(_data.species(_save.party[0].species).get(
				"growth_rate", Gen2Experience.GROWTH_MEDIUM_FAST
			)),
			level + 1
		)
	)
	assert_eq(_world.state.item_quantity(Gen2WorldPartyHost.ITEM_RARE_CANDY), 0)


## `cp MAX_LEVEL / jp nc, NoEffectMessage`: a refusal, so the candy is kept.
func test_a_rare_candy_is_refused_at_the_level_cap() -> void:
	_world.state.apply_changes({}, {}, {"items": {Gen2WorldPartyHost.ITEM_RARE_CANDY: 1}})
	_save.party[0].level = Gen2Experience.MAX_LEVEL
	_save.party[0].exp = Gen2Experience.total_exp_at(
		int(_data.species(_save.party[0].species).get(
			"growth_rate", Gen2Experience.GROWTH_MEDIUM_FAST
		)),
		Gen2Experience.MAX_LEVEL
	)
	var result: Dictionary = Gen2WorldPartyHost.use_item(
		_world, _save, Gen2WorldPartyHost.ITEM_RARE_CANDY, 0, false
	)
	assert_false(bool(result["ok"]))
	assert_eq(StringName(result["reason"]), &"item_has_no_effect")
	assert_eq(_world.state.item_quantity(Gen2WorldPartyHost.ITEM_RARE_CANDY), 1)


## `RestorePP`: ten for an ETHER and the whole ceiling for a MAX, the ETHERs on
## the slot `MoveSelectionScreen` chose and the ELIXERs on all four. A move
## already full is `.dont_restore`, and nothing restored at all is a refusal.
func test_the_pp_restorers_fill_one_move_or_all_four() -> void:
	_world.state.apply_changes({}, {}, {"items": {
		Gen2WorldPartyHost.ITEM_ETHER: 1, Gen2WorldPartyHost.ITEM_MAX_ETHER: 1,
		Gen2WorldPartyHost.ITEM_ELIXER: 1,
	}})
	var mon: Gen2SaveMon = _save.party[0]
	## The fixture's species carry no learnset, so the development save's party
	## knows nothing: the moves are written here rather than assumed.
	mon.moves = [1, 0, 0, 0]
	var maximum: int = int(_data.move(1).get("pp", 0))
	assert_gt(maximum, 0, "the fixture's first move has PP")

	## An ETHER with no slot chosen is the caller's cue to open the move list.
	mon.pp = [0, 0, 0, 0]
	var asked: Dictionary = Gen2WorldPartyHost.use_item(
		_world, _save, Gen2WorldPartyHost.ITEM_ETHER, 0, false
	)
	assert_eq(StringName(asked["reason"]), &"move_slot_required")
	assert_eq(_world.state.item_quantity(Gen2WorldPartyHost.ITEM_ETHER), 1)

	var ether: Dictionary = Gen2WorldPartyHost.use_item(
		_world, _save, Gen2WorldPartyHost.ITEM_ETHER, 0, false, 0
	)
	assert_true(bool(ether["ok"]), JSON.stringify(ether))
	assert_eq(_save.party[0].pp[0], mini(
		maximum, int(Gen2WorldPartyHost.PP_RESTORE_STEPS[Gen2WorldPartyHost.ITEM_ETHER])
	))

	var maxed: Dictionary = Gen2WorldPartyHost.use_item(
		_world, _save, Gen2WorldPartyHost.ITEM_MAX_ETHER, 0, false, 0
	)
	assert_true(bool(maxed["ok"]), JSON.stringify(maxed))
	assert_eq(_save.party[0].pp[0], maximum)

	## Every move already full is `WontHaveAnyEffectMessage`, and the ELIXER
	## stays in the pack.
	var refused: Dictionary = Gen2WorldPartyHost.use_item(
		_world, _save, Gen2WorldPartyHost.ITEM_ELIXER, 0, false
	)
	assert_false(bool(refused["ok"]))
	assert_eq(StringName(refused["reason"]), &"item_has_no_effect")
	assert_eq(_world.state.item_quantity(Gen2WorldPartyHost.ITEM_ELIXER), 1)


## `RestorePP`'s `cp MYSTERYBERRY / ld c, 5`: the only PP restorer on five, and
## the one `ItemEffects` row easy to miss because the item's own pocket row reads
## as a berry. It takes the same one-slot path as an ETHER.
func test_a_mysteryberry_restores_five_pp_to_the_chosen_move() -> void:
	_world.state.apply_changes({}, {}, {"items": {
		Gen2WorldPartyHost.ITEM_MYSTERYBERRY: 2,
	}})
	var mon: Gen2SaveMon = _save.party[0]
	mon.moves = [1, 0, 0, 0]
	mon.pp = [0, 0, 0, 0]

	var asked: Dictionary = Gen2WorldPartyHost.use_item(
		_world, _save, Gen2WorldPartyHost.ITEM_MYSTERYBERRY, 0, false
	)
	assert_eq(StringName(asked["reason"]), &"move_slot_required")

	var used: Dictionary = Gen2WorldPartyHost.use_item(
		_world, _save, Gen2WorldPartyHost.ITEM_MYSTERYBERRY, 0, false, 0
	)
	assert_true(bool(used["ok"]), JSON.stringify(used))
	assert_eq(_save.party[0].pp[0], mini(int(_data.move(1).get("pp", 0)), 5))
	assert_eq(_world.state.item_quantity(Gen2WorldPartyHost.ITEM_MYSTERYBERRY), 1)


## `UseRepel`'s own `ld a, [wRepelEffect] / and a`: the line is printed in place
## of `UseDisposableItem`, so a second Repel is neither spent nor stacked.
func test_a_repel_over_a_live_one_is_refused_and_kept() -> void:
	_world.state.apply_changes({}, {}, {"items": {
		Gen2WorldPartyHost.ITEM_REPEL: 1, Gen2WorldPartyHost.ITEM_MAX_REPEL: 1,
	}})

	var first: Dictionary = Gen2WorldPartyHost.use_item(
		_world, _save, Gen2WorldPartyHost.ITEM_REPEL, -1, false
	)
	assert_true(bool(first["ok"]), JSON.stringify(first))
	assert_eq(_world.repel_steps(), 100)

	var second: Dictionary = Gen2WorldPartyHost.use_item(
		_world, _save, Gen2WorldPartyHost.ITEM_MAX_REPEL, -1, false
	)
	assert_false(bool(second["ok"]))
	assert_eq(StringName(second["reason"]), &"repel_still_in_effect")
	assert_eq(_world.repel_steps(), 100)
	assert_eq(_world.state.item_quantity(Gen2WorldPartyHost.ITEM_MAX_REPEL), 1)


## `IsMonFainted` in front of `ItemRestoreHP`, `UseStatusHealer` and
## `FullRestoreEffect`. Nothing clears a party member's status byte when it
## faints, so the reachable case is a member poisoned to zero.
func test_a_status_healer_is_refused_on_a_fainted_member() -> void:
	_world.state.apply_changes({}, {}, {"items": {0x09: 1}})
	var mon: Gen2SaveMon = _save.party[0]
	mon.hp = 0
	mon.status = Gen2Status.POISON

	var result: Dictionary = Gen2WorldPartyHost.use_item(_world, _save, 0x09, 0, false)

	assert_false(bool(result["ok"]))
	assert_eq(StringName(result["reason"]), &"item_has_no_effect")
	assert_eq(_save.party[0].status, Gen2Status.POISON)
	assert_eq(_world.state.item_quantity(0x09), 1)


## PP UP raises `PP_UP_MASK`, which [Gen2SaveMon] does not carry: the pack says
## so rather than pretending the item did nothing.
func test_pp_up_names_the_save_field_it_needs() -> void:
	_world.state.apply_changes({}, {}, {"items": {Gen2WorldPartyHost.ITEM_PP_UP: 1}})
	var result: Dictionary = Gen2WorldPartyHost.use_item(
		_world, _save, Gen2WorldPartyHost.ITEM_PP_UP, 0, false
	)
	assert_false(bool(result["ok"]))
	assert_eq(StringName(result["reason"]), &"pp_up_unsupported")
	assert_eq(_world.state.item_quantity(Gen2WorldPartyHost.ITEM_PP_UP), 1)


## `VitaminEffect`: ten added to the high byte of one stat experience word,
## which is 2,560 flat, and HAPPINESS_USEDITEM. `UpdateStatsAfterItem` writes
## MON_MAXHP and the stats, never MON_HP, so the maximum rises and the member is
## no healthier than it was.
func test_a_vitamin_raises_one_stat_experience_and_the_maximum_it_pays_for() -> void:
	_world.state.apply_changes({}, {}, {"items": {0x1A: 2, 0x1B: 1}})
	var mon: Gen2SaveMon = _save.party[0]
	mon.happiness = 100
	mon.hp = 1
	var before_max: int = Gen2SaveBattleAdapter.to_battle_mon(_data, mon).max_hp()

	var result: Dictionary = Gen2WorldPartyHost.use_item(_world, _save, 0x1A, 0, false)

	assert_true(result["ok"], JSON.stringify(result))
	assert_eq(result["effect"], &"vitamin")
	assert_eq(int(_save.party[0].stat_exp["hp"]), 10 << 8)
	assert_gt(_save.party[0].happiness, 100)
	assert_gt(Gen2SaveBattleAdapter.to_battle_mon(_data, _save.party[0]).max_hp(), before_max)
	assert_eq(_save.party[0].hp, 1)
	assert_eq(_world.state.item_quantity(0x1A), 1)

	var other: Dictionary = Gen2WorldPartyHost.use_item(_world, _save, 0x1B, 0, false)
	assert_true(other["ok"], JSON.stringify(other))
	assert_eq(int(_save.party[0].stat_exp["attack"]), 10 << 8)
	assert_eq(int(_save.party[0].stat_exp["hp"]), 10 << 8)


## `cp 100 / jr nc, NoEffectMessage` is a refusal, not a clamp, and it reads the
## high byte alone.
func test_a_vitamin_is_refused_and_kept_once_its_stat_reaches_the_cap() -> void:
	_world.state.apply_changes({}, {}, {"items": {0x1A: 1}})
	_save.party[0].stat_exp["hp"] = 100 << 8

	var result: Dictionary = Gen2WorldPartyHost.use_item(_world, _save, 0x1A, 0, false)

	assert_false(result["ok"])
	assert_eq(StringName(result["reason"]), &"item_has_no_effect")
	assert_eq(int(_save.party[0].stat_exp["hp"]), 100 << 8)
	assert_eq(_world.state.item_quantity(0x1A), 1)


## `RevivalHerbEffect` reaches `RevivePokemon`, whose `cp REVIVE` leaves it on
## `ReviveFullHP`, and then charges HAPPINESS_REVIVALHERB.
func test_a_revival_herb_revives_to_full_health_and_costs_happiness() -> void:
	_world.state.apply_changes({}, {}, {"items": {0x7C: 1}})
	var mon: Gen2SaveMon = _save.party[0]
	mon.hp = 0
	mon.happiness = 100

	var result: Dictionary = Gen2WorldPartyHost.use_item(_world, _save, 0x7C, 0, false)

	assert_true(result["ok"], JSON.stringify(result))
	assert_true(result["bitter"])
	assert_eq(_save.party[0].hp, Gen2SaveBattleAdapter.to_battle_mon(_data, mon).max_hp())
	assert_eq(_save.party[0].happiness, 85)
	assert_eq(_world.state.item_quantity(0x7C), 0)


## `EnergypowderEnergyRootCommon` charges its row only once `ItemRestoreHP`
## reports the item was used, and every item outside those four charges nothing.
func test_an_energy_root_costs_happiness_where_a_potion_costs_none() -> void:
	_world.state.apply_changes({}, {}, {"items": {0x7A: 1}})
	_save.party[0].hp = 1
	_save.party[0].happiness = 100

	var bitter: Dictionary = Gen2WorldPartyHost.use_item(_world, _save, 0x7A, 0, false)
	assert_true(bitter["ok"], JSON.stringify(bitter))
	assert_true(bitter["bitter"])
	assert_eq(_save.party[0].happiness, 90)

	_save.party[0].hp = 1
	var plain: Dictionary = Gen2WorldPartyHost.use_item(_world, _save, 0x12, 0, false)
	assert_true(plain["ok"], JSON.stringify(plain))
	assert_false(plain["bitter"])
	assert_eq(_save.party[0].happiness, 90)


func test_moon_stone_evolves_a_party_member_and_consumes_the_item() -> void:
	var source: Gen2BattleMon = Gen2BattleMon.create(_data, 1, 5)
	source.hp = maxi(source.max_hp() - 3, 1)
	source.happiness = 80
	_save.party[0] = Gen2SaveBattleAdapter.from_battle_mon(source)
	_save.party[0].nickname = "SPROUT"
	var before_quantity: int = _world.state.item_quantity(0x08)
	var before_hp: int = _save.party[0].hp
	var before_max_hp: int = Gen2SaveBattleAdapter.to_battle_mon(
		_data, _save.party[0]
	).max_hp()

	var result: Dictionary = Gen2WorldPartyHost.use_item(
		_world, _save, 0x08, 0, false
	)

	assert_true(result["ok"], JSON.stringify(result))
	assert_eq(result["effect"], &"evolution")
	assert_eq(result["old_species"], 1)
	assert_eq(result["new_species"], 2)
	assert_eq(_save.party[0].species, 2)
	assert_eq(_save.party[0].nickname, "SPROUT")
	assert_eq(_world.state.item_quantity(0x08), before_quantity - 1)
	var evolved: Gen2BattleMon = Gen2SaveBattleAdapter.to_battle_mon(_data, _save.party[0])
	assert_eq(_save.party[0].hp, before_hp + evolved.max_hp() - before_max_hp)


## A mod item naming its evolution method, which is the whole of the seam: no
## callback, and everything past the predicate is the stone path's own.
const CORD_ITEM: int = Gen2ContentOverlay.FIRST_MOD_NUMBER
const CORD_HELD_ITEM: int = 0x12


func test_a_defined_item_may_name_a_trade_evolution_and_spends_the_held_item() -> void:
	Gen2ModHost.instance().register_content(
		Gen2ContentOverlay.KIND_ITEM, &"linkingcordtest", CORD_ITEM, {
			"name": "LINKING CORD",
			"field_menu": Gen2WorldPack.ITEMMENU_PARTY,
			"evolution": {"method": Gen2Layout.EVOLVE_TRADE},
		}
	)
	_world.state.apply_changes({}, {}, {"items": {CORD_ITEM: 1}})
	var source: Gen2BattleMon = Gen2BattleMon.create(_data, 2, 5)
	source.item = CORD_HELD_ITEM
	_save.party[0] = Gen2SaveBattleAdapter.from_battle_mon(source)

	var result: Dictionary = Gen2WorldPartyHost.use_item(_world, _save, CORD_ITEM, 0, false)

	assert_true(result["ok"], JSON.stringify(result))
	assert_eq(result["effect"], &"evolution")
	assert_eq(result["new_species"], 3)
	assert_eq(_save.party[0].species, 3)
	assert_eq(_save.party[0].item, 0, "`.trade` zeroes wTempMonItem")
	assert_eq(_world.state.item_quantity(CORD_ITEM), 0)


## Without the method named, the same item is inert: no cartridge item changes
## behaviour by a byte.
func test_a_defined_item_naming_no_method_evolves_nothing() -> void:
	Gen2ModHost.instance().register_content(
		Gen2ContentOverlay.KIND_ITEM, &"linkingcordtest", CORD_ITEM, {"name": "STRING"}
	)
	_world.state.apply_changes({}, {}, {"items": {CORD_ITEM: 1}})
	var source: Gen2BattleMon = Gen2BattleMon.create(_data, 2, 5)
	source.item = CORD_HELD_ITEM
	_save.party[0] = Gen2SaveBattleAdapter.from_battle_mon(source)

	var result: Dictionary = Gen2WorldPartyHost.use_item(_world, _save, CORD_ITEM, 0, false)

	assert_false(result["ok"])
	assert_eq(_save.party[0].species, 2)


## `EvoStoneEffect` reads MON_ITEM and refuses before `EvolvePokemon`, so the
## pack answers "It won't have any effect." even though `.item` itself would
## have evolved it.
## `.proceed` runs `SetSeenAndCaughtMon` on the new species, and
## `UpdateSpeciesNameIfNotNicknamed` before `GetBaseData`: an un-nicknamed
## Pokemon takes the new name, a nicknamed one keeps its own.
func test_an_evolution_registers_the_new_species_and_renames_only_the_unnamed() -> void:
	var source: Gen2BattleMon = Gen2BattleMon.create(_data, 1, 5)
	_save.party[0] = Gen2SaveBattleAdapter.from_battle_mon(source)
	_save.party[0].nickname = String(_data.species(1).get("name", ""))
	assert_false(_world.state.has_caught_species(2))

	assert_true(Gen2WorldPartyHost.use_item(_world, _save, 0x08, 0, false)["ok"])

	assert_true(_world.state.has_caught_species(2), "SetSeenAndCaughtMon")
	assert_eq(_save.party[0].nickname, String(_data.species(2).get("name", "")))


func test_a_stone_will_not_evolve_an_everstone_holder_from_the_pack() -> void:
	var source: Gen2BattleMon = Gen2BattleMon.create(_data, 1, 5)
	source.item = Gen2Evolution.EVERSTONE
	_save.party[0] = Gen2SaveBattleAdapter.from_battle_mon(source)

	var result: Dictionary = Gen2WorldPartyHost.use_item(_world, _save, 0x08, 0, false)

	assert_false(result["ok"])
	assert_eq(StringName(result["reason"]), &"item_has_no_effect")
	assert_eq(_save.party[0].species, 1)
	assert_eq(_world.state.item_quantity(0x08), 1, "and the stone is not spent")


## `ConvertBerriesToBerryJuice`'s Goldenrod gate. Swept over every seed rather
## than one, since the branch behind the gate is a roll: before the city, no
## draw converts anything.
func test_a_shuckle_holding_a_berry_makes_juice_only_past_goldenrod() -> void:
	var flag: int = Gen2WorldState.engine_flag(
		Gen2WorldState.ENGINE_REACHED_GOLDENROD, true
	)
	assert_false(_world.state.is_engine_flag_active(flag), "the fixture starts short of it")
	var converted_before: int = 0
	var converted_after: int = 0
	for seed_value: int in 64:
		converted_before += 1 if _juice_run(seed_value) else 0
	_world.state.set_engine_flag(flag, true)
	for seed_value: int in 64:
		converted_after += 1 if _juice_run(seed_value) else 0
	assert_eq(converted_before, 0, "nothing converts before Goldenrod")
	assert_gt(converted_after, 0, "and the 1-in-16 roll lands inside 64 seeds")


## One run of the routine over a SHUCKLE holding a BERRY, answering whether it
## became BERRY JUICE.
func _juice_run(seed_value: int) -> bool:
	_save.party[0] = Gen2SaveBattleAdapter.from_battle_mon(
		Gen2BattleMon.create(_data, 1, 5)
	)
	_save.party[0].species = Gen2WorldPartyHost.SHUCKLE
	_save.party[0].item = Gen2WorldPartyHost.ITEM_BERRY
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	Gen2WorldPartyHost.give_pokerus_and_convert_berries(_data, _save, _world, random)
	return _save.party[0].item == Gen2WorldPartyHost.ITEM_BERRY_JUICE


## `.loopMons`: an active infection anywhere in the party is sampled for a
## spread, and nothing is infected de novo while one is standing, so the strain
## every seed can produce is the carrier's own rather than a fresh roll.
func test_a_carrier_spreads_its_own_strain_and_blocks_a_new_infection() -> void:
	_world.state.set_engine_flag(Gen2WorldState.engine_flag(
		Gen2WorldState.ENGINE_REACHED_GOLDENROD, true
	), true)
	var spread: int = 0
	for seed_value: int in 64:
		_save.party[0].pokerus = 0x31
		_save.party[1].pokerus = 0
		var random := RandomNumberGenerator.new()
		random.seed = seed_value
		Gen2WorldPartyHost.give_pokerus_and_convert_berries(_data, _save, _world, random)
		assert_eq(_save.party[0].pokerus, 0x31, "the carrier is never rewritten")
		if _save.party[1].pokerus != 0:
			spread += 1
			assert_eq(_save.party[1].pokerus, 0x34, ".infectMon keeps the strain")
	assert_gt(spread, 0, "the 1-in-3 roll lands inside 64 seeds")


## `ApplyPokerusTick`: the days floor at zero and the STRAIN nibble survives,
## which is what stops a recovered Pokemon from catching it a second time.
func test_the_pokerus_tick_floors_the_days_and_keeps_the_strain() -> void:
	_save.party[0].pokerus = 0x33
	_save.party[1].pokerus = 0x00

	assert_true(Gen2WorldPartyHost.apply_pokerus_tick(_save, 2))
	assert_eq(_save.party[0].pokerus, 0x31)

	assert_true(Gen2WorldPartyHost.apply_pokerus_tick(_save, 9))
	assert_eq(_save.party[0].pokerus, 0x30, "cured, and still carrying its strain")
	assert_eq(_save.party[1].pokerus, 0x00, "an uninfected member is left alone")
	assert_false(Gen2WorldPartyHost.apply_pokerus_tick(_save, 1), "nothing left to spend")


## `.TrySpreadPokerus`'s two `cp`s, both macro results with a byte added: the
## direction roll is `50 percent + 1`, which is 128 rather than 129.
func test_the_two_pokerus_spread_rolls_are_the_macro_values() -> void:
	assert_eq(Gen2WorldPartyHost.POKERUS_SPREAD_ROLL, 33 * 0xFF / 100 + 1)
	assert_eq(Gen2WorldPartyHost.POKERUS_FORWARD_ROLL, 50 * 0xFF / 100 + 1)


## `.randomPokerusLoop` and `.infectMon`, the two pieces of arithmetic a reading
## gets wrong: both durations come off the STRAIN nibble, not off the byte.
func test_the_two_pokerus_bytes_are_the_source_arithmetic() -> void:
	assert_eq(Gen2WorldPartyHost.pokerus_from_roll(0x0F), 0x01, "a zero strain is one day")
	assert_eq(Gen2WorldPartyHost.pokerus_from_roll(0x13), 0x41, "(3 & 7) + 1 = 4")
	assert_eq(Gen2WorldPartyHost.pokerus_from_roll(0xF7), 0x81, "strain 8, and 8 & 3 is 0")
	assert_eq(Gen2WorldPartyHost.pokerus_spread_from(0x31), 0x34)
	assert_eq(Gen2WorldPartyHost.pokerus_spread_from(0x44), 0x41, "4 & 3 is 0")


func _add_party_evolution_metadata() -> void:
	var species: Array = RomCache.read_json(RomCache.species_path(Fixture.directory()))
	for raw: Dictionary in species:
		if int(raw["number"]) != 1:
			continue
		(raw["evolutions"] as Array).append({
			"method": Gen2Layout.EVOLVE_ITEM, "parameter": 0x08,
			"condition": 0, "target": 2,
		})
		break
	for raw: Dictionary in species:
		if int(raw["number"]) != 2:
			continue
		(raw["evolutions"] as Array).append({
			"method": Gen2Layout.EVOLVE_TRADE, "parameter": CORD_HELD_ITEM,
			"condition": 0, "target": 3,
		})
		break
	RomCache.write_json(RomCache.species_path(Fixture.directory()), species)


## TM01 and HM04 in this fixture's cache. The party's first member learns both,
## the second learns neither, so one save covers compatibility both ways.
const TM_ITEM: int = 0xBF
const HM_ITEM: int = 0xF6
const TM_MOVE: int = 0xDF
const HM_MOVE: int = 0x46
## The three rows `add_mt` appends past HM07, which only Crystal carries. The
## first member learns MT01 and MT03 and the second neither.
const MT01_MOVE: int = 0x35
const MT02_MOVE: int = 0x55
const MT03_MOVE: int = 0x3A


func _add_tmhm_metadata() -> void:
	var table: Array = []
	for index: int in Gen2Layout.TMHM_TM_COUNT + Gen2Layout.TMHM_HM_COUNT:
		table.append(0x60 + index)
	table[0] = TM_MOVE
	table[Gen2Layout.TMHM_TM_COUNT + 3] = HM_MOVE
	table.append_array([MT01_MOVE, MT02_MOVE, MT03_MOVE])
	RomCache.write_json(RomCache.tmhm_moves_path(Fixture.directory()), table)

	var species: Array = RomCache.read_json(RomCache.species_path(Fixture.directory()))
	for raw: Dictionary in species:
		var flags: Array = []
		flags.resize(Gen2Layout.TMHM_BYTES)
		for index: int in flags.size():
			flags[index] = 0
		if int(raw["number"]) == _save.party[0].species:
			# TMNUM 1 (TM01) and 54 (HM04), bit index TMNUM - 1 from the low bit.
			flags[0] = 0x01
			flags[6] = 0x20
			# TMNUM 58 (MT01) and 60 (MT03), bit index TMNUM - 1 again.
			flags[7] = 0x02 | 0x08
		raw["tmhm"] = flags
	RomCache.write_json(RomCache.species_path(Fixture.directory()), species)

	var moves: Array = RomCache.read_json(RomCache.moves_path(Fixture.directory()))
	for raw: Dictionary in moves:
		if int(raw["number"]) in [TM_MOVE, HM_MOVE, MT01_MOVE, MT02_MOVE, MT03_MOVE]:
			raw["pp"] = 15
	RomCache.write_json(RomCache.moves_path(Fixture.directory()), moves)

	# The fixture's item table stops short of the TM/HM range, and the save
	# validator rejects a world holding an item the cache does not know, so the
	# rows have to exist before either can sit in the bag.
	var items: Array = RomCache.read_json(RomCache.items_path(Fixture.directory()))
	while items.size() < HM_ITEM:
		var number: int = items.size() + 1
		items.append({
			"number": number, "name": "TM%02d" % number,
			"permissions": 0, "pocket": Gen2WorldPack.TYPE_TM_HM,
			"field_menu": 0, "battle_menu": 0, "status_mask": 0, "heal_amount": 0,
		})
	RomCache.write_json(RomCache.items_path(Fixture.directory()), items)

	_data = GameData.open_directory(Fixture.directory())
	_world.data = _data


func _teachable_save() -> Gen2SaveMon:
	_add_tmhm_metadata()
	var mon: Gen2SaveMon = _save.party[0]
	mon.moves = [1, 0, 0, 0]
	mon.pp = [10, 0, 0, 0]
	return mon


## LearnMove writes the move into the first empty slot and its PP from
## Moves + MOVE_PP, so a freshly taught move arrives at full PP. TeachTMHM
## returns straight after IsHM, so an HM is never consumed.
func test_teaching_an_hm_fills_the_first_empty_slot_and_keeps_the_hm() -> void:
	var mon: Gen2SaveMon = _teachable_save()
	_world.state.apply_changes({}, {}, {"items": {HM_ITEM: 1}})
	var result: Dictionary = Gen2WorldPartyHost.teach_tm_hm(_world, _save, HM_ITEM, 0, -1, false)
	assert_true(result["ok"], JSON.stringify(result))
	assert_eq(int(result["move"]), HM_MOVE)
	assert_eq(int(result["slot"]), 1)
	assert_eq(int(result["pp"]), 15)
	assert_false(bool(result["consumed"]))
	# _copy_save() rebuilds the party from the candidate, so the committed mon is
	# a new object and the one held before the call is stale.
	var taught: Gen2SaveMon = _save.party[0]
	assert_eq(taught.moves[1], HM_MOVE)
	assert_eq(taught.pp[1], 15)
	assert_eq(taught.moves[0], mon.moves[0], "the slot already in use is untouched")
	assert_eq(_world.state.item_quantity(HM_ITEM), 1)


## ConsumeTM runs for a TM, after IsHM lets it through.
func test_teaching_a_tm_consumes_it() -> void:
	_teachable_save()
	_world.state.apply_changes({}, {}, {"items": {TM_ITEM: 2}})
	var result: Dictionary = Gen2WorldPartyHost.teach_tm_hm(_world, _save, TM_ITEM, 0, -1, false)
	assert_true(result["ok"], JSON.stringify(result))
	assert_true(bool(result["consumed"]))
	assert_eq(_world.state.item_quantity(TM_ITEM), 1)


## `ld c, HAPPINESS_LEARNMOVE` sits between IsHM and ConsumeTM, so a TM moves
## happiness and an HM does not. HAPPINESS_LEARNMOVE's row is `+1, +1, +0`, which
## is the one row whose third column is zero: past 200 a TM changes nothing.
func test_teaching_a_tm_raises_happiness_and_teaching_an_hm_does_not() -> void:
	var mon: Gen2SaveMon = _teachable_save()
	mon.happiness = 70
	_world.state.apply_changes({}, {}, {"items": {TM_ITEM: 1, HM_ITEM: 1}})
	var result: Dictionary = Gen2WorldPartyHost.teach_tm_hm(_world, _save, TM_ITEM, 0, -1, false)
	assert_true(result["ok"], JSON.stringify(result))
	assert_eq(int(result["happiness_change"]), 1)
	assert_eq(_save.party[0].happiness, 71)

	_save.party[0].happiness = 240
	var again: Dictionary = Gen2WorldPartyHost.teach_tm_hm(_world, _save, HM_ITEM, 0, -1, false)
	assert_true(again["ok"], JSON.stringify(again))
	assert_eq(int(again["happiness_change"]), 0)
	assert_eq(_save.party[0].happiness, 240)


## `ChangeHappiness` itself: the column HAPPINESS_THRESHOLD_1 and _2 pick, and
## the two saturating branches. Row 6, "Lost to an enemy", is `-1` in all three
## columns and row 14 `+10, +10, +4`, so one rise and one fall cover both ends.
func test_a_happiness_change_picks_its_column_and_saturates() -> void:
	assert_eq(Gen2WorldPartyHost.change_happiness(_data, 99, 14), 109)
	assert_eq(Gen2WorldPartyHost.change_happiness(_data, 100, 14), 110)
	assert_eq(Gen2WorldPartyHost.change_happiness(_data, 200, 14), 204)
	assert_eq(Gen2WorldPartyHost.change_happiness(_data, 254, 14), 255, "no wrap past 255")
	assert_eq(Gen2WorldPartyHost.change_happiness(_data, 0, 6), 0, "no wrap below 0")
	# A row this cartridge does not carry, and no cache at all, both leave the
	# byte alone rather than inventing a change.
	assert_eq(Gen2WorldPartyHost.change_happiness(_data, 70, 99), 70)
	assert_eq(Gen2WorldPartyHost.change_happiness(null, 70, 5), 70)


## The refusal order is CanLearnTMHMMove, then KnowsMove, then LearnMove's slot
## search. Each answers before anything is written.
func test_teaching_refuses_an_incompatible_species_without_writing() -> void:
	_teachable_save()
	_world.state.apply_changes({}, {}, {"items": {HM_ITEM: 1}})
	var before: Dictionary = _save.to_dict()
	var result: Dictionary = Gen2WorldPartyHost.teach_tm_hm(_world, _save, HM_ITEM, 1, -1, false)
	assert_false(result["ok"])
	assert_eq(result["reason"], &"not_compatible")
	assert_eq(_save.to_dict(), before)
	assert_eq(_world.state.item_quantity(HM_ITEM), 1)


func test_teaching_refuses_a_move_the_mon_already_knows() -> void:
	var mon: Gen2SaveMon = _teachable_save()
	mon.moves = [HM_MOVE, 0, 0, 0]
	_world.state.apply_changes({}, {}, {"items": {HM_ITEM: 1}})
	var result: Dictionary = Gen2WorldPartyHost.teach_tm_hm(_world, _save, HM_ITEM, 0, -1, false)
	assert_false(result["ok"])
	assert_eq(result["reason"], &"already_knows_move")
	assert_eq(_world.state.item_quantity(HM_ITEM), 1)


## Where LearnMove opens ForgetMove. With no slot named, this is the call that
## runs the two compatibility checks and then asks; it writes nothing, and it
## carries the moves the menu lists.
func test_teaching_a_full_moveset_asks_rather_than_replacing_one() -> void:
	var mon: Gen2SaveMon = _teachable_save()
	mon.moves = [1, 2, 3, 4]
	mon.pp = [10, 10, 10, 10]
	_world.state.apply_changes({}, {}, {"items": {HM_ITEM: 1}})
	var result: Dictionary = Gen2WorldPartyHost.teach_tm_hm(_world, _save, HM_ITEM, 0, -1, false)
	assert_false(result["ok"])
	assert_eq(result["reason"], &"moveset_full")
	assert_eq(result["details"]["moves"], [1, 2, 3, 4], "the list ForgetMove's menu draws")
	assert_eq(mon.moves, [1, 2, 3, 4])
	assert_eq(_world.state.item_quantity(HM_ITEM), 1)


## LearnMove.learn writes the same way on both branches, so a forgotten slot
## takes the new move at full PP just as an empty one does.
func test_teaching_with_a_forget_slot_replaces_that_move_at_full_pp() -> void:
	var mon: Gen2SaveMon = _teachable_save()
	mon.moves = [1, 2, 3, 4]
	mon.pp = [10, 10, 10, 10]
	_world.state.apply_changes({}, {}, {"items": {TM_ITEM: 1}})
	var result: Dictionary = Gen2WorldPartyHost.teach_tm_hm(_world, _save, TM_ITEM, 0, 2, false)
	assert_true(result["ok"], JSON.stringify(result))
	assert_eq(int(result["slot"]), 2)
	assert_eq(int(result["forgot"]), 3)
	assert_eq(int(result["pp"]), 15)
	var taught: Gen2SaveMon = _save.party[0]
	assert_eq(taught.moves, [1, 2, TM_MOVE, 4])
	assert_eq(taught.pp[2], 15)
	## ConsumeTM still runs: a forgotten move does not change whether the item is
	## used up, only IsHM does.
	assert_true(bool(result["consumed"]))
	assert_eq(_world.state.item_quantity(TM_ITEM), 0)


## ForgetMove's .hmmove branch never returns an HM slot, so one arriving here is
## refused outright rather than honoured.
func test_teaching_refuses_to_forget_an_hm_move_without_writing() -> void:
	var mon: Gen2SaveMon = _teachable_save()
	# Slot 1 is SURF, HM03.
	mon.moves = [1, 0x39, 3, 4]
	mon.pp = [10, 10, 10, 10]
	_world.state.apply_changes({}, {}, {"items": {TM_ITEM: 1}})
	var before: Dictionary = _save.to_dict()
	var result: Dictionary = Gen2WorldPartyHost.teach_tm_hm(_world, _save, TM_ITEM, 0, 1, false)
	assert_false(result["ok"])
	assert_eq(result["reason"], &"cannot_forget_hm")
	assert_eq(int(result["details"]["forgot"]), 0x39)
	assert_eq(_save.to_dict(), before)
	assert_eq(_world.state.item_quantity(TM_ITEM), 1)


func test_teaching_refuses_an_out_of_range_forget_slot_without_writing() -> void:
	var mon: Gen2SaveMon = _teachable_save()
	mon.moves = [1, 2, 3, 4]
	mon.pp = [10, 10, 10, 10]
	_world.state.apply_changes({}, {}, {"items": {TM_ITEM: 1}})
	var before: Dictionary = _save.to_dict()
	var result: Dictionary = Gen2WorldPartyHost.teach_tm_hm(_world, _save, TM_ITEM, 0, 4, false)
	assert_false(result["ok"])
	assert_eq(result["reason"], &"invalid_forget_slot")
	assert_eq(_save.to_dict(), before)


## LearnMove.loop reaches ForgetMove only when its own scan finds no zero, so an
## empty slot wins over a slot the caller named. The save model keeps moves
## contiguous, so the gap is at the end.
func test_an_empty_slot_wins_over_a_passed_forget_slot() -> void:
	var mon: Gen2SaveMon = _teachable_save()
	mon.moves = [1, 2, 0, 0]
	mon.pp = [10, 10, 0, 0]
	_world.state.apply_changes({}, {}, {"items": {HM_ITEM: 1}})
	var result: Dictionary = Gen2WorldPartyHost.teach_tm_hm(_world, _save, HM_ITEM, 0, 0, false)
	assert_true(result["ok"], JSON.stringify(result))
	assert_eq(int(result["slot"]), 2, "the first empty slot, not the named one")
	assert_eq(int(result["forgot"]), 0)
	assert_eq(_save.party[0].moves, [1, 2, HM_MOVE, 0])


func test_teaching_refuses_an_item_that_is_not_a_tm_or_hm_and_an_absent_one() -> void:
	_teachable_save()
	_world.state.apply_changes({}, {}, {"items": {HM_ITEM: 1}})
	assert_eq(
		Gen2WorldPartyHost.teach_tm_hm(_world, _save, 0x12, 0, -1, false)["reason"],
		&"not_a_tm_hm"
	)
	# ConvertCurItemIntoCurTMHM is reached only from the pocket, so an item the
	# bag does not hold fails on the quantity first.
	assert_eq(
		Gen2WorldPartyHost.teach_tm_hm(_world, _save, TM_ITEM, 0, -1, false)["reason"],
		&"insufficient_item_quantity"
	)


func test_master_ball_captures_a_wild_mon_and_records_catch_metadata() -> void:
	var wild: Gen2BattleMon = Gen2BattleMon.create(
		_data, 25, 5, _data.moves_at_level(25, 5), 0x1234
	)
	var result: Dictionary = Gen2WorldPartyHost.capture_wild(
		_world, _save, wild, 0x01, _random, 42, false
	)
	assert_true(result["ok"])
	assert_true(result["caught"])
	assert_eq(result["wobbles"], 3)
	assert_eq(_save.party.size(), 3)
	assert_eq(_save.party[2].species, 25)
	assert_eq(_save.party[2].hp, wild.max_hp())
	assert_eq(_save.party[2].caught_level, 5)
	assert_eq(_save.party[2].caught_location, 42)
	assert_eq(_save.party[2].original_trainer, _save.player_name)
	assert_eq(_world.state.item_quantity(0x01), 0)


## `PokeBallEffect` pushes `wEnemyMonStatus` and `wEnemyMonHP` in front of
## `LoadEnemyMon` and writes them back after it, so a Pokemon caught at three HP
## and asleep joins the party at three HP and asleep. Everything else about the
## row is `GeneratePartyMonStats`': the trainer ID is the player's rather than a
## rolled one, the PP is full because `FillPP` ran over whatever the fight had
## drained, the stat experience is zero and the experience is the minimum for the
## level.
func test_a_caught_pokemon_keeps_its_health_and_its_status() -> void:
	_save.player_id = 0x1234
	var wild: Gen2BattleMon = Gen2BattleMon.create(
		_data, 25, 5, _data.moves_at_level(25, 5), 0x1234
	)
	wild.hp = 3
	wild.status = Gen2Status.SLEEP_MASK & 2
	wild.stat_exp["attack"] = 5000
	for slot: int in wild.pp.size():
		wild.pp[slot] = 0
	assert_true(bool(Gen2WorldPartyHost.capture_wild(
		_world, _save, wild, 0x01, _random, 42, false
	)["caught"]))
	var caught: Gen2SaveMon = _save.party[2]
	assert_eq(caught.hp, 3, "the health it was standing there with")
	assert_eq(caught.status, wild.status, "and the status it was standing there in")
	assert_eq(caught.ot_id, 0x1234, "the player's ID, so it is not a traded mon")
	assert_eq(int(caught.stat_exp["attack"]), 0)
	assert_eq(caught.happiness, Gen2WorldPartyHost.BASE_HAPPINESS)
	assert_eq(caught.exp, Gen2Experience.total_exp_at(
		int(_data.species(25).get("growth_rate", 0)), 5
	))
	for slot: int in Gen2SaveMon.MAX_MOVES:
		var move: int = int(caught.moves[slot])
		assert_eq(
			int(caught.pp[slot]),
			int(_data.move(move).get("pp", 0)) if move > 0 else 0,
			"FillPP fills every slot"
		)


## `.SkipPartyMonFriendBall`: the one thing a FRIEND_BALL does, and the one ball
## with no `BallMultiplierFunctionTable` row.
func test_a_friend_ball_catch_starts_on_two_hundred_happiness() -> void:
	_world.state.apply_changes({}, {}, {"items": {
		Gen2WorldPartyHost.ITEM_FRIEND_BALL: 2, Gen2WorldPartyHost.ITEM_LOVE_BALL: 1,
	}})
	var wild: Gen2BattleMon = Gen2BattleMon.create(
		_data, 25, 5, _data.moves_at_level(25, 5), 0x1234
	)
	wild.hp = 1
	var caught: Dictionary = {}
	for _throw: int in 200:
		_world.state.apply_changes({}, {}, {"items": {
			Gen2WorldPartyHost.ITEM_FRIEND_BALL: 2,
		}})
		caught = Gen2WorldPartyHost.capture_wild(
			_world, _save, wild, Gen2WorldPartyHost.ITEM_FRIEND_BALL, _random, 42, false
		)
		if bool(caught.get("caught", false)):
			break
	assert_true(bool(caught.get("caught", false)), "no friend ball ever landed")
	assert_eq(
		(_save.party[_save.party.size() - 1] as Gen2SaveMon).happiness,
		Gen2WorldPartyHost.FRIEND_BALL_HAPPINESS
	)


## Every row of `BallMultiplierFunctionTable` is reachable, which is the whole of
## what Kurt makes: before this the seven apricorn balls were refused outright
## and the player could carry a ball nothing would throw.
func test_every_ball_kurt_makes_can_be_thrown() -> void:
	var wild: Gen2BattleMon = Gen2BattleMon.create(
		_data, 25, 5, _data.moves_at_level(25, 5), 0x1234
	)
	for ball: int in Gen2WorldApricorn.APRICORN_BALLS.map(
		func(row: Array) -> int: return int(row[1])
	):
		_world.state.apply_changes({}, {}, {"items": {ball: 1}})
		var thrown: Dictionary = Gen2WorldPartyHost.capture_wild(
			_world, _save, wild, ball, _random, 42, false
		)
		assert_true(bool(thrown.get("ok", false)), "%d: %s" % [ball, JSON.stringify(thrown)])
		assert_eq(_world.state.item_quantity(ball), 0, "and the ball was spent")


## Generation 1 numbers its bag its own way, so the balls a battle offers are
## `ItemUsePtrTable`'s rows rather than Crystal's: read off the Crystal list, the
## number that is POKE_BALL there is a TOWN MAP here and the ball itself is not
## offered at all.
func test_generation_one_offers_the_cartridges_own_ball_numbers() -> void:
	_world.state.apply_changes({}, {}, {"items": {0x01: 1, 0x04: 1, 0x05: 1}})
	assert_eq(
		Gen2WorldPartyHost.owned_capture_balls(_world), [0x05, 0x04, 0x01] as Array[int]
	)
	_data.generation = RomRegistry.GEN1
	assert_eq(
		Gen2WorldPartyHost.owned_capture_balls(_world), [0x04, 0x01, 0x08] as Array[int],
		"POKE_BALL is 4, the 5 beside it is a TOWN MAP, and 8 is the SAFARI_BALL"
	)


## `ItemUseBall` has one bag rather than four pockets, so nothing an item row
## says about a pocket may refuse a Generation 1 throw. The seam is what
## `ItemUsePtrTable` says instead, and the cache carries no pocket at all.
func test_a_generation_one_throw_reads_no_pocket() -> void:
	_data.generation = RomRegistry.GEN1
	_world.state.apply_changes({}, {}, {"items": {0x04: 1}})
	var wild: Gen2BattleMon = Gen2BattleMon.create(
		_data, 25, 5, _data.moves_at_level(25, 5), 0x1234
	)
	var thrown: Dictionary = Gen2WorldPartyHost.capture_wild(
		_world, _save, wild, 0x04, _random, 42, false
	)
	assert_true(bool(thrown.get("ok", false)), JSON.stringify(thrown))
	assert_eq(_world.state.item_quantity(0x04), 0, "and the ball was spent")
	var refused: Dictionary = Gen2WorldPartyHost.capture_wild(
		_world, _save, wild, 0x05, _random, 42, false
	)
	assert_eq(
		StringName(refused.get("reason", &"")), &"unsupported_ball_effect",
		"the TOWN MAP has no ItemUseBall row"
	)


## `.loop` rerolls anything over the ball's own ceiling, which is the whole of
## what a Great Ball buys before the arithmetic starts. A roll it refuses costs
## nothing but the number.
func test_a_great_ball_rerolls_a_number_over_two_hundred() -> void:
	var case: Dictionary = {
		"catch_rate": 45, "max_hp": 100, "current_hp": 100, "status": 0,
	}
	assert_eq(
		_gen1_throw(0x03, case, [255, 201, 60, 255]),
		_gen1_throw(0x03, case, [60, 255]),
		"the two refused rolls change nothing"
	)
	assert_ne(
		_gen1_throw(0x04, case, [255, 255]), _gen1_throw(0x03, case, [255, 255]),
		"and a Poke Ball keeps the 255 a Great Ball throws away"
	)


## `.checkForAilments` subtracts before it compares, so a roll under the status
## term is caught with no arithmetic at all: 25 asleep or frozen, 12 otherwise.
func test_a_sleeping_wild_is_caught_outright_below_the_status_term() -> void:
	var case: Dictionary = {
		"catch_rate": 1, "max_hp": 100, "current_hp": 100,
		"status": Gen2Status.SLEEP_MASK & 3,
	}
	assert_true(bool(_gen1_throw(0x04, case, [24, 255])["caught"]))
	assert_false(bool(_gen1_throw(0x04, case, [25, 255])["caught"]))
	case["status"] = Gen2Status.POISON
	assert_true(bool(_gen1_throw(0x04, case, [11, 255])["caught"]))
	assert_false(bool(_gen1_throw(0x04, case, [12, 255])["caught"]))


func _gen1_throw(ball: int, case: Dictionary, rolls: Array) -> Dictionary:
	var queue: Array = rolls.duplicate()
	return Gen2WorldPartyHost.gen1_ball_outcome(
		ball, case,
		func() -> int: return int(queue.pop_front()) if not queue.is_empty() else 0
	)


## `_DoYouWantToNicknameText` and `_ItemUseBallText08`, which are their own
## words. The Generation 1 box line is the one `EVENT_MET_BILL` has not replaced,
## no Generation 1 event model holding that flag.
func test_generation_one_says_its_own_catch_lines() -> void:
	assert_string_contains(
		Gen2WorldPartyHost.capture_nickname_question("PIKACHU", RomRegistry.GEN1),
		"Do you want to"
	)
	assert_string_contains(
		Gen2WorldPartyHost.sent_to_box_text("PIKACHU", RomRegistry.GEN1),
		"someone's PC!"
	)
	assert_string_contains(
		Gen2WorldPartyHost.sent_to_box_text("PIKACHU"), "BILL's PC."
	)


## `GivePokemon`, which the Game Corner's prize counter reaches with a species
## and `GetPrizeMonLevel`'s level. A full party boxes it; neither having room
## writes nothing, which is what leaves the coins alone.
func test_a_prize_pokemon_joins_the_party_and_a_full_one_goes_to_a_box() -> void:
	var given: Dictionary = Gen2WorldPartyHost.give_pokemon(
		_world, _save, 25, 9, false, _random
	)
	assert_true(bool(given.get("ok", false)), JSON.stringify(given))
	assert_eq(_save.party.size(), 3)
	assert_eq(_save.party[2].species, 25)
	assert_eq(_save.party[2].level, 9)
	while _save.party.size() < Gen2SaveData.MAX_PARTY:
		_save.party.append(Gen2SaveMon.from_dict(_save.party[0].to_dict()))
	assert_true(bool(Gen2WorldPartyHost.give_pokemon(
		_world, _save, 25, 9, false, _random
	).get("ok", false)), "a full party boxes it")
	assert_eq(_save.party.size(), Gen2SaveData.MAX_PARTY)
	assert_eq(
		StringName(Gen2WorldPartyHost.give_pokemon(
			_world, _save, 0, 9, false, _random
		).get("reason", &"")), &"unknown_species"
	)


## `SendMonIntoBox` writes `sBoxCount`, which is the open box and no other, and
## `ShiftBoxMon` puts what it wrote at the head of it. A full open box refuses
## the throw with the other thirteen still empty, which is
## `Ball_BoxIsFullMessage`, and the ball is not spent.
func test_a_full_party_catch_goes_to_the_front_of_the_open_box() -> void:
	while _save.party.size() < Gen2SaveData.MAX_PARTY:
		_save.party.append(Gen2SaveMon.from_dict(_save.party[0].to_dict()))
	_save.current_box = 2
	var resident: Gen2SaveMon = Gen2SaveMon.from_dict(_save.party[0].to_dict())
	(_save.boxes[2] as Gen2SaveBox).put(resident)
	var wild: Gen2BattleMon = Gen2BattleMon.create(
		_data, 25, 5, _data.moves_at_level(25, 5), 0x1234
	)
	var caught: Dictionary = Gen2WorldPartyHost.capture_wild(
		_world, _save, wild, 0x01, _random, 42, false
	)
	assert_true(bool(caught["caught"]))
	assert_eq(int(caught["destination"]["box"]), 2, "the box the player has open")
	assert_eq(int(caught["destination"]["slot"]), 0)
	assert_eq((_save.boxes[2] as Gen2SaveBox).slots[0].species, 25)
	assert_eq(
		(_save.boxes[2] as Gen2SaveBox).slots[1].species, resident.species,
		"and what was there moved down"
	)
	assert_true(_save.boxes[0].slots[0] == null, "box 1 is untouched")

	for slot: int in Gen2SaveBox.CAPACITY:
		(_save.boxes[2] as Gen2SaveBox).put(Gen2SaveMon.from_dict(resident.to_dict()), slot)
	_world.state.apply_changes({}, {}, {"items": {0x01: 1}})
	var refused: Dictionary = Gen2WorldPartyHost.capture_wild(
		_world, _save, wild, 0x01, _random, 42, false
	)
	assert_false(bool(refused["ok"]))
	assert_eq(StringName(refused["reason"]), &"storage_full")
	assert_eq(_world.state.item_quantity(0x01), 1, "and the ball is still in the bag")


## `GetPokeBallWobble` increments its count before it rolls, so the roll that
## ends a throw names how many rocks came before it and not how many there were.
## A throw that escapes on the first roll has rocked no times at all, which is
## `BallBrokeFreeText`'s own case and was unreachable while the answer here was
## the source's count rather than the rocks.
func test_a_failed_throw_counts_the_rocks_and_not_the_rolls() -> void:
	var seen: Dictionary = {}
	for seed_value: int in 200:
		var random := RandomNumberGenerator.new()
		random.seed = seed_value
		seen[Gen2WorldPartyHost._failed_wobbles(1, random)] = true
	assert_true(seen.has(0), "a throw that escapes on the first roll has not rocked")
	assert_eq(seen.keys().min(), 0)
	assert_eq(seen.keys().max(), 3, "the ball rocks three times at most")


## The Nuzlocke's first rule at the one place a ball is ever thrown. The battle
## claims the area when it opens and leaves it on the world; anything else is an
## area that already gave up its encounter, and the ball is refused whole: no
## catch, no dex flag, and the ball still in the bag.
func test_a_nuzlocke_ball_is_only_thrown_at_the_encounter_that_claimed_the_area() -> void:
	_world.rules = Gen2Rules.new()
	_world.rules.challenge = Gen2Rules.CHALLENGE_NUZLOCKE
	var wild: Gen2BattleMon = Gen2BattleMon.create(
		_data, 25, 5, _data.moves_at_level(25, 5), 0x1234
	)
	## The first encounter here claimed the area and got away, which is what a
	## second fight on the same map arrives to.
	assert_true(Gen2Nuzlocke.claim_area(_save.nuzlocke, 42, 19))

	var refused: Dictionary = Gen2WorldPartyHost.capture_wild(
		_world, _save, wild, 0x01, _random, 42, false
	)
	assert_false(bool(refused["ok"]))
	assert_eq(StringName(refused["reason"]), &"nuzlocke_encounter_spent")
	assert_eq(_save.party.size(), 2, "nothing was caught")
	assert_eq(_world.state.item_quantity(0x01), 1, "and the ball is still in the bag")

	_world.nuzlocke_area_open = 42
	var thrown: Dictionary = Gen2WorldPartyHost.capture_wild(
		_world, _save, wild, 0x01, _random, 42, false
	)
	assert_true(bool(thrown["ok"]))
	assert_true(bool(thrown["caught"]))
	assert_eq(_save.party.size(), 3)
	assert_true(
		bool((_save.nuzlocke["areas"] as Dictionary)["42"]["caught"]),
		"and the area records that its Pokemon was taken",
	)


## `BugContest_SetCaughtContestMon`: the first catch is kept outright, and a
## second one is only offered, with the Pokemon already held named by
## `DisplayAlreadyCaughtText` rather than the new one.
func test_a_second_contest_catch_is_offered_and_names_the_one_already_held() -> void:
	_world.state.set_park_balls(20)
	var first: Gen2BattleMon = Gen2BattleMon.create(
		_data, 25, 5, _data.moves_at_level(25, 5), 0x1234
	)
	first.hp = 1
	var caught: Dictionary = Gen2WorldPartyHost.capture_contest(_world, first, _random)
	assert_true(bool(caught["ok"]), JSON.stringify(caught))
	if bool(caught["caught"]):
		assert_false(bool(caught.get("replace_offer", false)), "nothing to replace")
		assert_eq(int(_world.state.contest_mon()["species"]), 25)
	_world.state.set_contest_mon({"species": 10, "level": 5, "max_hp": 21})

	var second: Gen2BattleMon = Gen2BattleMon.create(
		_data, 25, 7, _data.moves_at_level(25, 7), 0x1234
	)
	## A Park Ball on a full-health wild almost never lands; the rate is the
	## catch's own and not what this is about.
	second.hp = 1
	var offered: Dictionary = {}
	for _throw: int in 2000:
		_world.state.set_park_balls(20)
		offered = Gen2WorldPartyHost.capture_contest(_world, second, _random)
		if bool(offered.get("caught", false)):
			break
	assert_true(bool(offered.get("caught", false)), "no park ball ever landed")
	assert_true(bool(offered["replace_offer"]))
	assert_eq(int(offered["stock_species"]), 10, "the line names the one held")
	assert_eq(int(offered["stock_level"]), 5)
	assert_eq(int(offered["stock_max_hp"]), 21)
	assert_eq(
		int(_world.state.contest_mon()["species"]), 10,
		"the state is left alone until the question is answered"
	)


func test_a_full_party_capture_uses_the_first_pc_box_slot() -> void:
	while _save.party.size() < Gen2SaveData.MAX_PARTY:
		_save.party.append(Gen2SaveMon.from_dict(_save.party[0].to_dict()))
	var wild: Gen2BattleMon = Gen2BattleMon.create(
		_data, 25, 5, _data.moves_at_level(25, 5), 0x1234
	)
	var result: Dictionary = Gen2WorldPartyHost.capture_wild(
		_world, _save, wild, 0x01, _random, 42, false
	)
	assert_true(result["ok"])
	assert_true(result["caught"])
	assert_eq(_save.party.size(), Gen2SaveData.MAX_PARTY)
	assert_eq(_save.boxes[0].slots[0].species, 25)
	assert_eq(result["destination"]["destination"], &"box")


## `.SendToPC`'s own `cp MONS_PER_BOX`, which raises BATTLERESULT_BOX_FULL for
## `Script_reloadmapafterbattle` to answer with Bill on the phone. Only the
## catch that fills the box raises it; the one before it does not, and a catch
## that reached the party never does.
func test_the_catch_that_fills_a_box_raises_the_box_full_result() -> void:
	while _save.party.size() < Gen2SaveData.MAX_PARTY:
		_save.party.append(Gen2SaveMon.from_dict(_save.party[0].to_dict()))
	var box: Gen2SaveBox = _save.boxes[0]
	for slot: int in Gen2SaveBox.CAPACITY - 2:
		box.slots[slot] = Gen2SaveMon.from_dict(_save.party[0].to_dict())
	var wild: Gen2BattleMon = Gen2BattleMon.create(
		_data, 25, 5, _data.moves_at_level(25, 5), 0x1234
	)
	_world.state.apply_changes({}, {}, {"items": {0x01: 2}})
	var first: Dictionary = Gen2WorldPartyHost.capture_wild(
		_world, _save, wild, 0x01, _random, 42, false
	)
	assert_true(bool(first["caught"]))
	assert_false(bool(first["box_full"]), "one slot is still free")
	assert_false(_world.state.battle_box_full())
	var second: Dictionary = Gen2WorldPartyHost.capture_wild(
		_world, _save, wild, 0x01, _random, 42, false
	)
	assert_true(bool(second["box_full"]), JSON.stringify(second))
	assert_true(_world.state.battle_box_full())


## `GeneratePartyMonStats`' `.registerunowndex`: the letter comes off the DVs
## that were caught, and it is entered once however many of that form are caught.
func test_catching_an_unown_into_the_party_enters_its_letter_in_the_unown_dex() -> void:
	var dvs: int = Gen2Stats.pack_dvs(2, 0, 0, 0)
	var wild: Gen2BattleMon = Gen2BattleMon.create(
		_data, Gen2Layout.UNOWN_SPECIES, 5,
		_data.moves_at_level(Gen2Layout.UNOWN_SPECIES, 5), dvs
	)
	assert_true(Gen2WorldPartyHost.capture_wild(
		_world, _save, wild, 0x01, _random, 42, false
	)["caught"])
	assert_eq(_world.state.unown_dex(), [Gen2Stats.unown_letter(dvs)] as Array[int])

	_world.state.apply_changes({}, {}, {"items": {0x01: 1}})
	assert_true(Gen2WorldPartyHost.capture_wild(
		_world, _save, wild, 0x01, _random, 42, false
	)["caught"])
	assert_eq(_world.state.unown_caught_count(), 1, "the same letter twice is one entry")


## The routine runs under `wMonType` PARTYMON alone, so an Unown that goes
## straight to the PC is caught without entering the Unown dex.
func test_an_unown_caught_into_a_box_does_not_enter_the_unown_dex() -> void:
	while _save.party.size() < Gen2SaveData.MAX_PARTY:
		_save.party.append(Gen2SaveMon.from_dict(_save.party[0].to_dict()))
	var wild: Gen2BattleMon = Gen2BattleMon.create(
		_data, Gen2Layout.UNOWN_SPECIES, 5,
		_data.moves_at_level(Gen2Layout.UNOWN_SPECIES, 5), Gen2Stats.pack_dvs(2, 0, 0, 0)
	)
	var result: Dictionary = Gen2WorldPartyHost.capture_wild(
		_world, _save, wild, 0x01, _random, 42, false
	)
	assert_eq(result["destination"]["destination"], &"box")
	assert_true(_world.state.has_caught_species(Gen2Layout.UNOWN_SPECIES))
	assert_true(_world.state.unown_dex().is_empty())


func test_full_storage_refuses_a_capture_before_consuming_the_ball() -> void:
	while _save.party.size() < Gen2SaveData.MAX_PARTY:
		_save.party.append(Gen2SaveMon.from_dict(_save.party[0].to_dict()))
	for box: Gen2SaveBox in _save.boxes:
		for slot: int in Gen2SaveBox.CAPACITY:
			box.slots[slot] = Gen2SaveMon.from_dict(_save.party[0].to_dict())
	var before_quantity: int = _world.state.item_quantity(0x01)
	var wild: Gen2BattleMon = Gen2BattleMon.create(
		_data, 25, 5, _data.moves_at_level(25, 5), 0x1234
	)
	var result: Dictionary = Gen2WorldPartyHost.capture_wild(
		_world, _save, wild, 0x01, _random, 42, false
	)
	assert_false(result["ok"])
	assert_eq(result["reason"], &"storage_full")
	assert_eq(_world.state.item_quantity(0x01), before_quantity)


func test_failed_poke_ball_still_consumes_the_ball_without_adding_a_mon() -> void:
	_data.species(25)["catch_rate"] = 1
	var wild: Gen2BattleMon = Gen2BattleMon.create(
		_data, 25, 5, _data.moves_at_level(25, 5), 0xFFFF
	)
	var result: Dictionary = Gen2WorldPartyHost.capture_wild(
		_world, _save, wild, 0x05, _random, 0, false
	)
	assert_true(result["ok"])
	assert_false(result["caught"])
	assert_eq(_save.party.size(), 2)
	assert_eq(_world.state.item_quantity(0x05), 0)


func _set_script(address: int) -> void:
	_world.current_map.events["coord_events"] = [{
		"scene": 0, "x": 2, "y": 2, "script": address,
	}]


func _add_party_scripts() -> void:
	var scripts: Dictionary = RomCache.read_json(
		RomCache.world_scripts_path(Fixture.directory())
	)
	scripts[Gen2WorldScript.pointer_key(Fixture.BANK, 0x6200)] = [0x2D, 25, 5, 0, 0, 0x91]
	scripts[Gen2WorldScript.pointer_key(Fixture.BANK, 0x6210)] = [0x2E, 25, 5, 0x91]
	scripts[Gen2WorldScript.pointer_key(Fixture.BANK, 0x6220)] = [0x96, 0, 0x91]
	## `special CheckPartyFullAfterContest`, which is
	## `BugContestResults_DidNotLeaveMons`' own first command.
	scripts[Gen2WorldScript.pointer_key(Fixture.BANK, 0x6230)] = [
		Gen2WorldScript.SPECIAL, 21, 0, 0x91,
	]
	## `special GiveOddEgg`, `DayCareManScript_Inside`'s own.
	scripts[Gen2WorldScript.pointer_key(Fixture.BANK, 0x6240)] = [
		Gen2WorldScript.SPECIAL, Gen2WorldScriptRunner.SPECIAL_GIVE_ODD_EGG, 0, 0x91,
	]
	RomCache.write_json(RomCache.world_scripts_path(Fixture.directory()), scripts)


func _add_trade_record() -> void:
	RomCache.write_json(RomCache.world_trades_path(Fixture.directory()), [{
		"trade_id": 0,
		"dialog": 0,
		"requested_species": 155,
		"offered_species": 74,
		"nickname": "ROCKY",
		"dvs": 0x9666,
		"item": 0,
		"ot_id": 48926,
		"ot_name": "KYLE",
		"gender": Gen2Layout.TRADE_GENDER_EITHER,
	}])


## The `npc_trade` run and the buffers its boxes name, so the conversation
## `NPCTrade` holds runs in GUT. Crystal's own WRAM addresses, which is what the
## fixture's other `<RAM_` markers already assume, and `StringBufferPointers`'
## order: buffers 3, 4, 5, 2, 1 and the two battle nicknames.
func _add_trade_texts() -> void:
	_wanted = String(_data.species(155).get("name", ""))
	_offered = String(_data.species(74).get("name", ""))
	RomCache.write_json(RomCache.text_buffers_path(Fixture.directory()), [
		0xD099, 0xD0AC, 0xD0BF, 0xD086, 0xD073, 0xC616, 0xC621,
	])
	var manifest: Dictionary = RomCache.read_manifest(Fixture.directory())
	manifest["special_text_ram"] = {"mon_or_item_name": 0xD050}
	manifest["special_text"] = {
		"npc_trade": {
			"cable": "OK, connect the\nGame Link Cable.",
			"traded_for": "<PLAYER> traded\n<RAM_D050> for\n<RAM_D086>.",
			"intro_1": "I collect #MON.\nDo you have\n<RAM_D073>?",
			"cancel_1": "You don't want to\ntrade? Aww…",
			"wrong_1": "Huh? That's not\n<RAM_D073>.",
			"complete_1": "Yay! I got myself\n<RAM_D073>!",
			"after_1": "Hi, how's my old\n<RAM_D086> doing?",
		},
	}
	RomCache.write_json(RomCache.manifest_path(Fixture.directory()), manifest)
	_data = GameData.open_directory(Fixture.directory())
	_world.data = _data
	_world.set_player_name(_save.player_name)


func _add_party_item_metadata() -> void:
	var items: Array = RomCache.read_json(RomCache.items_path(Fixture.directory()))
	for raw: Dictionary in items:
		var number: int = int(raw["number"])
		raw["permissions"] = Gen2Layout.ITEM_ATTRIBUTE_CANT_SELECT
		raw["pocket"] = 0
		raw["field_menu"] = Gen2Layout.ITEMMENU_PARTY
		raw["battle_menu"] = Gen2Layout.ITEMMENU_PARTY
		raw["status_mask"] = 0
		raw["heal_amount"] = 0
		if number == 0x12:
			raw["heal_amount"] = 20
		if number == 0x09:
			raw["status_mask"] = Gen2Status.POISON
		if number == 0x7A:
			raw["heal_amount"] = 200
		if number == 0x14:
			raw["field_menu"] = Gen2Layout.ITEMMENU_CURRENT
		if number == 0x05:
			raw["pocket"] = Gen2Layout.ITEM_POCKET_BALL
			raw["field_menu"] = 0
			raw["battle_menu"] = Gen2Layout.ITEMMENU_CLOSE
	RomCache.write_json(RomCache.items_path(Fixture.directory()), items)


func _add_capture_metadata() -> void:
	var species: Array = RomCache.read_json(RomCache.species_path(Fixture.directory()))
	for raw: Dictionary in species:
		if int(raw["number"]) == 25:
			raw["catch_rate"] = 190
	RomCache.write_json(RomCache.species_path(Fixture.directory()), species)
	var items: Array = RomCache.read_json(RomCache.items_path(Fixture.directory()))
	for raw: Dictionary in items:
		if int(raw["number"]) in [0x01, 0x02, 0x04, 0x05] \
			or int(raw["number"]) in Gen2WorldPartyHost.CAPTURE_BALLS:
			raw["pocket"] = Gen2Layout.ITEM_POCKET_BALL
	RomCache.write_json(RomCache.items_path(Fixture.directory()), items)


## `Softboiled_MilkDrinkFunction`: a fifth of the user's own maximum health moved
## to another party member, and the three refusals `.SelectMilkDrinkRecipient`
## loops on.

func _fifth_of(index: int) -> int:
	return Gen2WorldPartyHost.one_fifth_max_hp(_data, _save.party[index])


func test_softboiled_moves_a_fifth_of_the_users_own_maximum() -> void:
	var amount: int = _fifth_of(0)
	assert_gt(amount, 0)
	_save.party[1].hp = 1
	var before: int = _save.party[0].hp

	var result: Dictionary = Gen2WorldPartyHost.transfer_health(_world, _save, 0, 1, false)
	assert_true(result["ok"], String(result.get("reason", "")))
	assert_eq(int(result["amount"]), amount)
	assert_eq(_save.party[0].hp, before - amount)
	assert_eq(_save.party[1].hp, 1 + int(result["restored"]))


func test_the_healed_member_is_never_taken_past_its_own_maximum() -> void:
	# The user's fifth is what is spent whatever the recipient can hold, which is
	# why the two numbers are reported separately.
	var max_hp: int = Gen2SaveBattleAdapter.to_battle_mon(_data, _save.party[1]).max_hp()
	_save.party[1].hp = max_hp - 1
	var result: Dictionary = Gen2WorldPartyHost.transfer_health(_world, _save, 0, 1, false)
	assert_true(result["ok"], String(result.get("reason", "")))
	assert_eq(_save.party[1].hp, max_hp)
	assert_eq(int(result["restored"]), 1)
	assert_eq(int(result["amount"]), _fifth_of(0))


func test_a_user_on_a_fifth_or_less_cannot_give_health_away() -> void:
	# `.CheckMonHasEnoughHP` wants more than the fifth, not the fifth itself.
	_save.party[1].hp = 1
	_save.party[0].hp = _fifth_of(0)
	var result: Dictionary = Gen2WorldPartyHost.transfer_health(_world, _save, 0, 1, false)
	assert_false(bool(result.get("ok", false)))
	assert_eq(StringName(result["reason"]), &"not_enough_health")
	assert_eq(_save.party[1].hp, 1, "and nothing moved")


func test_the_user_itself_a_fainted_member_and_a_full_one_are_all_refused() -> void:
	assert_eq(
		StringName(Gen2WorldPartyHost.transfer_health(_world, _save, 0, 0, false)["reason"]),
		&"same_member"
	)
	assert_eq(
		StringName(Gen2WorldPartyHost.transfer_health(_world, _save, 0, 1, false)["reason"]),
		&"already_full"
	)
	_save.party[1].hp = 0
	assert_eq(
		StringName(Gen2WorldPartyHost.transfer_health(_world, _save, 0, 1, false)["reason"]),
		&"fainted_member"
	)


## `StepHappiness` reaches no `HappinessChanges` row: it is a flat `inc [hl]`
## per party member, an egg is skipped by `cp EGG / jr z, .next`, and 255 stays
## 255 because the wrap is caught by `ld [hl], $ff`.
func test_step_happiness_raises_every_member_but_an_egg_and_saturates() -> void:
	_save.party[0].happiness = 254
	var second: Gen2SaveMon = Gen2SaveBattleAdapter.from_battle_mon(
		Gen2BattleMon.create(_data, 1, 5)
	)
	second.happiness = 10
	second.is_egg = true
	_save.party = [_save.party[0], second]

	assert_eq(Gen2WorldPartyHost.apply_step_happiness(_save, 1), [0] as Array[int])
	assert_eq(_save.party[0].happiness, 255)
	assert_eq(_save.party[1].happiness, 10, "an egg reaches no point")

	assert_true(Gen2WorldPartyHost.apply_step_happiness(_save, 1).is_empty(),
		"nothing moved once the only eligible member is at 255")
	_save.party[0].happiness = 100
	assert_eq(Gen2WorldPartyHost.apply_step_happiness(_save, 3), [0] as Array[int])
	assert_eq(_save.party[0].happiness, 103, "an owed run of passes is one add")
	assert_true(Gen2WorldPartyHost.apply_step_happiness(null, 1).is_empty())
	assert_true(Gen2WorldPartyHost.apply_step_happiness(_save, 0).is_empty())


func _egg(species: int, cycles: int) -> Gen2SaveMon:
	var egg: Gen2SaveMon = Gen2SaveBattleAdapter.from_battle_mon(
		Gen2BattleMon.create(_data, species, 5)
	)
	egg.is_egg = true
	egg.hp = 0
	egg.happiness = cycles
	egg.nickname = "EGG"
	return egg


## `DoEggStep` walks the party taking one cycle off every egg and stops on the
## first that reaches zero, so an egg behind that one keeps the cycle.
func test_an_egg_step_drains_every_egg_and_stops_on_the_first_ready_one() -> void:
	_save.party = [_save.party[0], _egg(1, 1), _egg(1, 3)]
	assert_eq(Gen2WorldPartyHost.apply_egg_steps(_save, 1), 1)
	assert_eq(_save.party[1].happiness, 0)
	assert_eq(_save.party[2].happiness, 3, "the walk stopped before the second egg")
	assert_eq(_save.party[0].happiness, Gen2SaveStore.create_development_save(
		_data, 0
	).party[0].happiness, "a Pokemon is not an egg and loses nothing")


func test_an_egg_step_answers_minus_one_until_a_counter_runs_out() -> void:
	_save.party = [_egg(1, 3)]
	assert_eq(Gen2WorldPartyHost.apply_egg_steps(_save, 2), -1)
	assert_eq(_save.party[0].happiness, 1)
	assert_eq(Gen2WorldPartyHost.apply_egg_steps(_save, 1), 0)
	assert_eq(Gen2WorldPartyHost.apply_egg_steps(null, 1), -1)
	assert_eq(Gen2WorldPartyHost.apply_egg_steps(_save, 0), -1)


## `HatchEggs`: the row becomes the Pokemon it was carrying, at full health, on
## `$78` happiness, with the player's own ID and name and CAUGHT_EGG_LEVEL.
func test_hatching_writes_the_row_the_source_writes() -> void:
	_save.player_id = 0x1234
	_save.player_name = "KRIS"
	_save.party = [_egg(1, 1)]
	assert_true(Gen2WorldPartyHost.hatch_egg(_world, _save, 0).is_empty(),
		"an egg with cycles left does not hatch")
	assert_eq(Gen2WorldPartyHost.apply_egg_steps(_save, 1), 0)

	var summary: Dictionary = Gen2WorldPartyHost.hatch_egg(_world, _save, 0)
	assert_eq(int(summary.get("party_index", -1)), 0)
	assert_eq(int(summary.get("species", 0)), 1)
	var mon: Gen2SaveMon = _save.party[0]
	assert_false(mon.is_egg)
	assert_eq(mon.happiness, Gen2WorldPartyHost.HATCHED_HAPPINESS)
	assert_eq(mon.status, Gen2Status.NONE)
	assert_true(mon.hp > 0, "the hatchling stands at its own maximum")
	assert_eq(mon.ot_id, 0x1234)
	assert_eq(mon.original_trainer, "KRIS")
	assert_eq(mon.caught_level, Gen2WorldPartyHost.CAUGHT_EGG_LEVEL)
	assert_eq(mon.caught_location, _world.landmark())
	assert_true(_world.state.has_caught_species(1), "SetSeenAndCaughtMon runs here")
	## `HatchEggs` asks for `SCGB_EVOLUTION`, which is a shiny-reading layout, so
	## the row the screen draws from says which colours the hatchling wears. A
	## bred shiny is first seen here and nowhere earlier.
	assert_eq(bool(summary.get("shiny", false)), Gen2Stats.is_shiny(mon.dvs))
	assert_true(Gen2WorldPartyHost.hatch_egg(_world, _save, 0).is_empty(),
		"a hatched row is not an egg any more")


## `SetBoxmonOrEggmonCaughtData` writes the trainer's gender, not the caught
## Pokemon's, and the time of day plus one.
func test_caught_data_is_the_trainers_rather_than_the_pokemons() -> void:
	var mon: Gen2SaveMon = _save.party[0]
	Gen2WorldPartyHost.set_caught_data(mon, 12, Gen2WorldPalette.TIME_NIGHT, true, 9)
	assert_eq(mon.caught_level, 12)
	assert_eq(mon.caught_time, Gen2WorldPalette.TIME_NIGHT + 1)
	assert_eq(mon.caught_gender, 1)
	assert_eq(mon.caught_location, 9)
	Gen2WorldPartyHost.set_caught_data(mon, 0, -1, false, Gen2WorldPartyHost.LANDMARK_GIFT)
	assert_eq(mon.caught_time, 0, "a gift's whole level byte is zeroed")
	assert_eq(mon.caught_gender, 0)
	assert_eq(mon.caught_location, Gen2WorldPartyHost.LANDMARK_GIFT)


## `HaircutOrGrooming`'s `Random` walk: every one of the 256 rolls lands on a
## row, the shares are the table's own `percent` bytes, and the order is the
## table's rather than sorted, which is what a `sub`-and-borrow loop gives.
func test_the_grooming_tables_partition_all_256_rolls() -> void:
	var expected: Dictionary = {
		&"older_haircut": {2: 76, 3: 128, 4: 52},
		&"younger_haircut": {2: 154, 3: 76, 4: 26},
		&"grooming": {2: 255},
	}
	for routine: Variant in expected:
		var counts: Dictionary = {}
		for roll: int in 256:
			var outcome: Dictionary = Gen2WorldPartyHost.groom_outcome(
				StringName(routine), roll, true
			)
			var value: int = int(outcome["script_value"])
			counts[value] = int(counts.get(value, 0)) + 1
		for value: Variant in expected[routine]:
			assert_eq(
				int(counts.get(value, 0)), int(expected[routine][value]),
				"%s answers %d for that many rolls" % [routine, value]
			)


## `docs/bugs_and_glitches.md`: subtracting `$ff` from `$ff` sets no carry, so
## one roll in 256 reads past `HappinessData_DaisysGrooming` into
## `CopyPokemonName_Buffer1_Buffer3`'s `ld hl, wStringBuffer1` and takes that
## address's two bytes as the row. The kind it lands on has no `HappinessChanges`
## entry, so the grooming changes nothing.
func test_daisys_grooming_overruns_its_table_on_a_roll_of_255() -> void:
	var overrun: Dictionary = Gen2WorldPartyHost.groom_outcome(&"grooming", 255, true)
	assert_eq(int(overrun["script_value"]), 0x73, "LOW(wStringBuffer1) on Crystal")
	assert_eq(int(overrun["happiness_kind"]), 0xD0, "HIGH(wStringBuffer1) on Crystal")
	var gold: Dictionary = Gen2WorldPartyHost.groom_outcome(&"grooming", 255, false)
	assert_eq(int(gold["script_value"]), 0x6B, "LOW(wStringBuffer1) on Gold and Silver")
	assert_eq(int(gold["happiness_kind"]), 0xCF)
	assert_eq(
		Gen2WorldPartyHost.change_happiness(_data, 120, int(overrun["happiness_kind"])),
		120,
		"a row past the table leaves the byte alone, which is the bug's own effect",
	)
	var groomed: Dictionary = Gen2WorldPartyHost.groom_outcome(&"grooming", 254, true)
	assert_eq(int(groomed["script_value"]), 2)
	assert_eq(int(groomed["happiness_kind"]), Gen2Battle.HAPPINESS_GROOMING)


## `.GetMoveTutorMove` reads MT01_MOVE through MT03_MOVE, which are TMHMMoves
## entries past HM07 rather than pinned move numbers, and anything outside the
## three MOVETUTOR_* values falls through to ICE_BEAM the way its `cp` chain
## does. A cartridge whose table stops at HM07 answers nothing.
func test_the_tutor_reads_its_three_moves_off_the_imported_table() -> void:
	_add_tmhm_metadata()
	assert_eq(Gen2MoveTutor.move_for_value(_data, Gen2MoveTutor.VALUE_FLAMETHROWER), MT01_MOVE)
	assert_eq(Gen2MoveTutor.move_for_value(_data, Gen2MoveTutor.VALUE_THUNDERBOLT), MT02_MOVE)
	assert_eq(Gen2MoveTutor.move_for_value(_data, Gen2MoveTutor.VALUE_ICE_BEAM), MT03_MOVE)
	assert_eq(Gen2MoveTutor.move_for_value(_data, 0), MT03_MOVE, "the fall-through branch")
	assert_eq(Gen2MoveTutor.move_for_value(_data, 9), MT03_MOVE)
	assert_eq(Gen2MoveTutor.move_for_value(null, 1), 0)


## `CheckCanLearnMoveTutorMove` is `LearnMove` with `CanLearnTMHMMove` in front
## and `ld c, HAPPINESS_LEARNMOVE` behind, and no item on either side: the coins
## are the map script's `takecoins`.
func test_the_tutor_teaches_at_full_pp_and_charges_happiness_but_no_item() -> void:
	var mon: Gen2SaveMon = _teachable_save()
	mon.happiness = 70
	var result: Dictionary = Gen2WorldPartyHost.teach_tutor_move(
		_world, _save, 0, MT01_MOVE, -1, false
	)
	assert_true(result["ok"], JSON.stringify(result))
	assert_eq(int(result["slot"]), 1)
	assert_eq(int(result["pp"]), 15)
	assert_eq(int(result["happiness_change"]), 1)
	assert_eq(_save.party[0].moves[1], MT01_MOVE)
	assert_eq(_save.party[0].pp[1], 15)
	assert_eq(_save.party[0].happiness, 71)


## The tutor's own `predef CanLearnTMHMMove`, which the plain `LearnMove` an
## evolution offers does not run: the same species and move answer differently
## through the two entry points.
func test_the_tutor_checks_compatibility_where_a_level_up_offer_does_not() -> void:
	_teachable_save()
	var refused: Dictionary = Gen2WorldPartyHost.teach_tutor_move(
		_world, _save, 0, MT02_MOVE, -1, false
	)
	assert_false(refused["ok"])
	assert_eq(refused["reason"], &"not_compatible")
	assert_eq(_save.party[0].moves[1], 0, "nothing was written")

	var offered: Dictionary = Gen2WorldPartyHost.learn_move(
		_world, _save, 0, MT02_MOVE, -1, false
	)
	assert_true(offered["ok"], JSON.stringify(offered))
	assert_eq(int(offered["happiness_change"]), 0, "no item, no happiness row")


## `LearnMove` is still the last of the three, so a full moveset asks rather
## than replacing one, and the happiness row is only charged once the move is
## actually written.
func test_the_tutor_asks_before_replacing_a_full_moveset_and_charges_nothing() -> void:
	var mon: Gen2SaveMon = _teachable_save()
	mon.moves = [1, 2, 3, 4]
	mon.pp = [10, 10, 10, 10]
	mon.happiness = 70
	var asked: Dictionary = Gen2WorldPartyHost.teach_tutor_move(
		_world, _save, 0, MT03_MOVE, -1, false
	)
	assert_false(asked["ok"])
	assert_eq(asked["reason"], &"moveset_full")
	assert_eq(_save.party[0].happiness, 70, "the ask writes nothing")

	var replaced: Dictionary = Gen2WorldPartyHost.teach_tutor_move(
		_world, _save, 0, MT03_MOVE, 2, false
	)
	assert_true(replaced["ok"], JSON.stringify(replaced))
	assert_eq(int(replaced["forgot"]), 3)
	assert_eq(_save.party[0].moves, [1, 2, MT03_MOVE, 4])
	assert_eq(_save.party[0].happiness, 71)


## `ContestDropOffMons` and `ContestReturnMons` (engine/events/bug_contest/
## contest_2.asm): the party masked to its lead for the length of a contest, and
## the count recomputed when it is put back.
func test_the_contest_mask_moves_the_party_aside_and_puts_it_back_in_order() -> void:
	while _save.party.size() > 1:
		_save.party.remove_at(1)
	var second: Gen2SaveMon = Gen2SaveMon.new()
	second.species = 10
	second.level = 7
	var third: Gen2SaveMon = Gen2SaveMon.new()
	third.species = 13
	third.level = 8
	_save.party.append(second)
	_save.party.append(third)
	var lead: Gen2SaveMon = _save.party[0]

	assert_eq(Gen2WorldPartyHost.contest_drop_off_mons(_save), 10, "wPartySpecies + 1")
	assert_eq(_save.party.size(), 1, "wPartyCount is 1 for the whole contest")
	assert_eq(_save.party[0], lead)
	assert_eq(_save.contest_stashed_party.size(), 2)

	## A second call with a stash standing would lose it; the gate cannot reach
	## this twice and a mod calling the special can.
	assert_eq(Gen2WorldPartyHost.contest_drop_off_mons(_save), 0)
	assert_eq(_save.contest_stashed_party.size(), 2)

	assert_eq(Gen2WorldPartyHost.contest_return_mons(_save), 2)
	assert_eq(_save.party, [lead, second, third])
	assert_true(_save.contest_stashed_party.is_empty())
	assert_eq(Gen2WorldPartyHost.contest_return_mons(_save), 0, "nothing owed twice")


func test_a_one_member_party_needs_no_contest_mask() -> void:
	while _save.party.size() > 1:
		_save.party.remove_at(1)
	assert_eq(Gen2WorldPartyHost.contest_drop_off_mons(_save), 0)
	assert_eq(_save.party.size(), 1)
	assert_true(_save.contest_stashed_party.is_empty())


func test_the_masked_party_survives_a_save_round_trip() -> void:
	while _save.party.size() > 1:
		_save.party.remove_at(1)
	var second: Gen2SaveMon = Gen2SaveMon.new()
	second.species = 10
	second.level = 7
	_save.party.append(second)
	Gen2WorldPartyHost.contest_drop_off_mons(_save)
	var restored: Gen2SaveData = Gen2SaveData.from_dict(_save.to_dict())
	assert_eq(restored.party.size(), 1)
	assert_eq(restored.contest_stashed_party.size(), 1)
	assert_eq(int(restored.contest_stashed_party[0].species), 10)
	## A slot written before the mask existed reads as one outside a contest.
	var older: Dictionary = _save.to_dict()
	older.erase("contest_stashed_party")
	assert_true(Gen2SaveData.from_dict(older).contest_stashed_party.is_empty())


## `DoPoisonStep`'s `.DamageMonIfPoisoned`: one HP off a poisoned member that is
## still standing, and nothing at all off one that is already down.
func test_a_poison_step_takes_one_hp_off_every_poisoned_member() -> void:
	var first: Gen2SaveMon = _save.party[0]
	first.is_egg = false
	first.hp = 5
	first.status = Gen2Status.POISON
	var second: Gen2SaveMon = Gen2SaveMon.new()
	second.species = first.species
	second.level = first.level
	second.hp = 9
	second.status = Gen2Status.NONE
	_save.party.append(second)
	var pass_result: Dictionary = Gen2WorldPartyHost.apply_poison_step(_data, _save)
	assert_eq(first.hp, 4)
	assert_eq(second.hp, 9)
	assert_eq(Array(pass_result["damaged"]), [0])
	assert_true(Array(pass_result["fainted"]).is_empty())
	assert_true(bool(pass_result["sfx"]), "%01 alone still plays SFX_POISON")
	assert_false(bool(pass_result["whiteout"]))


## The `%10` branch: the point that finishes a member clears its status, charges
## HAPPINESS_POISONFAINT and prints `_PoisonFaintText`, and the whiteout behind
## it is `CheckPlayerPartyForFitMon` rather than the faint itself.
func test_the_last_member_fainting_to_poison_whites_the_player_out() -> void:
	var mon: Gen2SaveMon = _save.party[0]
	mon.is_egg = false
	mon.hp = 1
	mon.status = Gen2Status.POISON
	mon.happiness = 200
	while _save.party.size() > 1:
		_save.party.remove_at(1)
	var pass_result: Dictionary = Gen2WorldPartyHost.apply_poison_step(_data, _save)
	assert_eq(mon.hp, 0)
	assert_eq(mon.status, Gen2Status.NONE)
	assert_lt(mon.happiness, 200, "HAPPINESS_POISONFAINT subtracts")
	assert_eq(Array(pass_result["fainted"]), [0])
	assert_eq(
		Array(pass_result["texts"]),
		[Gen2WorldPartyHost.poison_faint_text(
			String(_data.species(mon.species).get("name", ""))
		)],
		"an unnicknamed row falls back to its species name"
	)
	assert_true(bool(pass_result["whiteout"]))


## `CheckPlayerPartyForFitMon` ORs HP words and never asks about eggs, and
## `GiveEgg` zeroes an egg's HP, so an egg cannot keep a fainted party standing.
func test_an_egg_is_not_a_fit_mon() -> void:
	while _save.party.size() > 1:
		_save.party.remove_at(1)
	var mon: Gen2SaveMon = _save.party[0]
	mon.is_egg = true
	mon.hp = 0
	assert_false(Gen2WorldPartyHost.party_has_fit_mon(_save))
	mon.hp = 1
	assert_true(Gen2WorldPartyHost.party_has_fit_mon(_save))


## `Script_Whiteout` in its own order: `special HealParty`, then `HalveMoney`,
## and only then the spawn. The fixture cache carries no `SpawnPoints` table, so
## the warp is what fails here and the two writes in front of it are what the
## order is proved by.
func test_the_whiteout_heals_and_halves_the_money_before_it_warps() -> void:
	for mon: Gen2SaveMon in _save.party:
		mon.is_egg = false
		mon.hp = 0
		mon.status = Gen2Status.POISON
	_world.state.apply_changes({}, {}, {"money": {0: 4001}})
	_world.last_spawn_map = Vector2i(-1, -1)
	assert_eq(_world.whiteout_spawn(), Gen2Layout.SPAWN_HOME,
		"no Pokemon Center entered is SPAWN_HOME")
	var result: Dictionary = Gen2WorldPartyHost.whiteout(_world, _save, false)
	assert_false(bool(result["ok"]), "the fixture has no spawn to warp to")
	assert_eq(_world.state.money(0), 2000, "srl/rra over three bytes floors")
	assert_true(Gen2WorldPartyHost.party_has_fit_mon(_save))
	for mon: Gen2SaveMon in _save.party:
		assert_eq(mon.status, Gen2Status.NONE)


## `CalcMagikarpLength`'s own documented table, which is the routine read
## through `.BCLessThanDE`'s bug: the row is picked on b alone, so every value
## of b in a band gives that band's x, y and z. One case per band rather than
## one sampled case, since the bands are what the bug defines.
func test_a_magikarps_length_follows_the_band_its_high_byte_lands_in() -> void:
	for row: Array in [
		[0, 310, 2, 3], [1, 710, 4, 4], [5, 2710, 20, 5], [20, 7710, 50, 6],
		[50, 17710, 100, 7], [100, 32710, 150, 8], [150, 47710, 150, 9],
		[200, 57710, 100, 10], [230, 62710, 50, 11], [248, 64710, 20, 12],
		[253, 65210, 5, 13], [254, 65410, 2, 14],
	]:
		var bc: int = (int(row[0]) << 8) | 0x37
		@warning_ignore("integer_division")
		var millimetres: int = ((bc - int(row[1])) & 0xFFFF) / int(row[2]) & 0xFF
		millimetres += 100 * int(row[3])
		@warning_ignore("integer_division")
		var inches: int = ((millimetres * 10) & 0xFFFF) / 254
		@warning_ignore("integer_division")
		var expected := Vector2i(inches / 12, inches % 12)
		assert_eq(
			Gen2WorldPartyHost.magikarp_length(_dvs_for(bc), 0), expected,
			"b = %d takes x = %d, y = %d, z = %d" % row
		)


## The short branch: `bc` under ten is `c + 190` millimetres and never reaches
## the table at all.
func test_the_shortest_magikarp_skips_the_table() -> void:
	assert_eq(Gen2WorldPartyHost.magikarp_length(_dvs_for(9), 0), Vector2i(0, 7))
	assert_eq(Gen2WorldPartyHost.magikarp_length(_dvs_for(0), 0), Vector2i(0, 7))


## `CompareBytes` over two bytes: an equal length is not a new record, and the
## feet decide before the inches are looked at.
func test_a_magikarp_record_is_beaten_only_by_a_strictly_longer_one() -> void:
	var record: Dictionary = {"feet": 3, "inches": 4}
	assert_false(Gen2WorldPartyHost.magikarp_beats_record(Vector2i(3, 4), record))
	assert_false(Gen2WorldPartyHost.magikarp_beats_record(Vector2i(3, 3), record))
	assert_false(Gen2WorldPartyHost.magikarp_beats_record(Vector2i(2, 11), record))
	assert_true(Gen2WorldPartyHost.magikarp_beats_record(Vector2i(3, 5), record))
	assert_true(Gen2WorldPartyHost.magikarp_beats_record(Vector2i(4, 0), record))


## `PrintMagikarpLength`'s two `PRINTNUM_LEFTALIGN` numbers, which pad neither.
func test_a_magikarp_length_prints_both_numbers_unpadded() -> void:
	assert_eq(Gen2WorldPartyHost.magikarp_length_string(3, 4), "3′4″")
	assert_eq(Gen2WorldPartyHost.magikarp_length_string(0, 11), "0′11″")


## `.CompareLuckyNumberToMonID`'s bands: five digits from the right is a first
## prize, three or four a second, two a third, and one or none is no match. Both
## numbers are `PrintNum`'s five digits over two bytes, so every ID here is one
## the cartridge could hold.
func test_the_lucky_number_bands_by_matching_digits_from_the_right() -> void:
	for row: Array in [
		[12345, 1], [52345, 2], [55345, 2], [55545, 3], [55555, 0], [55550, 0],
	]:
		var matched: Dictionary = Gen2WorldPartyHost.lucky_number_match(
			12345, [int(row[0])], [1], [false], [], []
		)
		assert_eq(int(matched["script_value"]), int(row[1]),
			"%d against 12345" % int(row[0]))


## The best match wins wherever it is, and only a box match prints the PC line.
## `.bettermatch` is reached on an equal score as well as a better one, because
## `cp b / jr c, .nomatch` jumps only when what is already stored is strictly
## better: a box row that ties with a party row takes the prize and the PC line
## with it.
func test_the_lucky_number_keeps_the_best_match_and_says_where_it_was() -> void:
	var tied: Dictionary = Gen2WorldPartyHost.lucky_number_match(
		12345, [52345], [1], [false], [55345], [2]
	)
	assert_eq(int(tied["script_value"]), 2)
	assert_eq(int(tied["species"]), 2, "an equal box match replaces the party one")
	assert_true(bool(tied["in_storage"]))
	var boxed: Dictionary = Gen2WorldPartyHost.lucky_number_match(
		12345, [55545], [1], [false], [12345], [2]
	)
	assert_eq(int(boxed["script_value"]), 1)
	assert_eq(int(boxed["species"]), 2)
	assert_true(bool(boxed["in_storage"]))
	assert_eq(
		int(Gen2WorldPartyHost.lucky_number_match(
			12345, [12345], [1], [true], [], []
		)["script_value"]),
		0,
		"`cp EGG` skips an egg in the party walk"
	)


## MON_DVS for a wanted `bc`, given a zero trainer ID: the routine rotates each
## DV byte right twice, so the byte that produces one is the wanted half rotated
## left twice.
func _dvs_for(bc: int) -> PackedByteArray:
	return PackedByteArray([
		_rotate_left(_rotate_left((bc >> 8) & 0xFF)),
		_rotate_left(_rotate_left(bc & 0xFF)),
	])


func _rotate_left(value: int) -> int:
	return ((value << 1) | (value >> 7)) & 0xFF
