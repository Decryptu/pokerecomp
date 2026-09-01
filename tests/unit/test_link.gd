extends GutTest

## The cable club without a cartridge: the transport seam, the session's own
## answers, and the trade transaction behind them.
##
## The real-cartridge counterpart is `tools/checks/link.gd`, which drives the
## three receptionists on the real map. What is here is what a synthetic world
## can settle: the rules, the record and the party swap.

const Fixture := preload("res://tests/integration/world_trainer_fixture.gd")
const BattleFixture := preload("res://tests/unit/battle_fixture.gd")

const SPECIES_ONE: int = BattleFixture.BULBASAUR
const SPECIES_TWO: int = BattleFixture.CHARMANDER
const TACKLE: int = BattleFixture.TACKLE

var _data: GameData = null
var _live_world: Gen2WorldAPI = null


func before_each() -> void:
	Gen2ModHost.reset()
	Fixture.build()
	_data = GameData.open_directory(Fixture.directory())
	_live_world = Gen2WorldAPI.open(
		_data, Fixture.MAP_GROUP, Fixture.MAP_NUMBER, Vector2i(2, 2), Gen2WorldState.new()
	)


func after_each() -> void:
	Gen2ModHost.reset()
	RomCache.clear(Fixture.directory())


## A party member the save validator accepts: the development save's own row
## with a species and an HP written over it, rather than a hand-built struct
## with half its fields left at zero.
func _mon(species: int, hp: int = 20, level: int = 5) -> Gen2SaveMon:
	var mon: Gen2SaveMon = Gen2SaveBattleAdapter.from_battle_mon(
		Gen2BattleMon.create(_data, species, level, _data.moves_at_level(species, level))
	)
	mon.hp = hp
	mon.original_trainer = "RED"
	mon.ot_id = 1
	return mon


func _peer(room: int = Gen2LinkSession.CABLECLUBROOM_TRADECENTER) -> Gen2LinkTransport:
	var transport := Gen2LinkTransport.new()
	transport.peer = {
		"name": "BLUE", "id": 4242, "gender": 0,
		"generation": Gen2LinkTransport.GENERATION_2, "room": room,
		"party": [_mon(SPECIES_TWO).to_dict()],
	}
	return transport


## `WaitForLinkedFriend`'s `.done` branch, which is what one console always
## reaches: no peer, no connection, and the receptionist's FALSE.
func test_a_transport_with_no_peer_never_connects() -> void:
	var session := Gen2LinkSession.new()
	var transport := Gen2LinkTransport.new()
	assert_false(transport.connected())
	assert_eq(transport.status(), Gen2LinkTransport.CONNECTION_NOT_ESTABLISHED)
	assert_eq(session.wait_for_linked_friend(transport), 0)
	assert_eq(session.check_link_timeout(transport), 0)
	assert_eq(session.link_mode, Gen2LinkSession.LINK_NULL)


func test_a_peer_connects_as_the_internal_clock() -> void:
	var session := Gen2LinkSession.new()
	var transport: Gen2LinkTransport = _peer()
	assert_eq(session.wait_for_linked_friend(transport), 1)
	assert_eq(transport.status(), Gen2LinkTransport.USING_INTERNAL_CLOCK)
	## `CableClubCheckWhichChris` answers TRUE for the external clock alone.
	assert_eq(session.which_chris(transport), 0)


## `CheckBothSelectedSameRoom`, whose `wLinkMode` is the room plus one.
func test_agreeing_a_room_sets_the_link_mode_and_brings_the_peers_party_back() -> void:
	var session := Gen2LinkSession.new()
	var transport: Gen2LinkTransport = _peer()
	session.request_room(Gen2LinkSession.CABLECLUBROOM_TRADECENTER)
	assert_eq(session.check_both_selected_same_room(transport), 1)
	assert_eq(session.link_mode, Gen2LinkSession.LINK_TRADECENTER)
	assert_eq((session.peer.get("party", []) as Array).size(), 1)


func test_a_peer_at_another_door_is_refused() -> void:
	var session := Gen2LinkSession.new()
	var transport: Gen2LinkTransport = _peer(Gen2LinkSession.CABLECLUBROOM_COLOSSEUM)
	session.request_room(Gen2LinkSession.CABLECLUBROOM_TRADECENTER)
	assert_eq(session.check_both_selected_same_room(transport), 0)
	assert_eq(session.link_mode, Gen2LinkSession.LINK_NULL)


## `readmem wOtherPlayerLinkMode` is zero for a Gen 1 game and nothing else,
## which is both the "can't link to the past" branch and the Time Capsule's own
## entry condition.
func test_only_a_gen_1_peer_reads_as_the_past() -> void:
	var session := Gen2LinkSession.new()
	var modern: Gen2LinkTransport = _peer()
	session.check_link_timeout(modern)
	assert_ne(session.other_player_link_mode, 0)
	var old: Gen2LinkTransport = _peer()
	old.peer["generation"] = Gen2LinkTransport.GENERATION_1
	session.check_link_timeout(old)
	assert_eq(session.other_player_link_mode, 0)


func test_leaving_the_receptionist_puts_the_serial_port_back() -> void:
	var session := Gen2LinkSession.new()
	var transport: Gen2LinkTransport = _peer()
	session.request_room(Gen2LinkSession.CABLECLUBROOM_TRADECENTER)
	session.wait_for_linked_friend(transport)
	session.check_both_selected_same_room(transport)
	session.wait_for_other_player_to_exit(transport)
	assert_eq(session.link_mode, Gen2LinkSession.LINK_NULL)
	assert_eq(session.connection_status, Gen2LinkSession.CONNECTION_NOT_ESTABLISHED)
	assert_true(session.peer.is_empty())


## `ValidateOTTrademon`: the party list's species has to match the struct's
## unless the list says EGG, and no level may be above the cap.
func test_an_offer_whose_species_disagrees_with_its_row_is_abnormal() -> void:
	var mon: Dictionary = _mon(SPECIES_TWO).to_dict()
	assert_true(Gen2LinkSession.validate_ot_trademon(
		mon, SPECIES_TWO, false, Gen2LinkSession.LINK_TRADECENTER
	))
	assert_false(Gen2LinkSession.validate_ot_trademon(
		mon, SPECIES_ONE, false, Gen2LinkSession.LINK_TRADECENTER
	))
	## An EGG row names no species, so the test is skipped rather than failed.
	assert_true(Gen2LinkSession.validate_ot_trademon(
		mon, SPECIES_ONE, true, Gen2LinkSession.LINK_TRADECENTER
	))
	var overlevelled: Dictionary = _mon(SPECIES_TWO, 20, 101).to_dict()
	assert_false(Gen2LinkSession.validate_ot_trademon(
		overlevelled, SPECIES_TWO, false, Gen2LinkSession.LINK_TRADECENTER
	))


## The Time Capsule's own type test, which only a Gen 1 peer supplies the
## evidence for, and the two species it excuses by name.
func test_the_time_capsule_refuses_a_species_this_generation_retyped() -> void:
	var mon: Dictionary = _mon(SPECIES_TWO).to_dict()
	mon["types"] = [0, 0]
	assert_true(Gen2LinkSession.validate_ot_trademon(
		mon, SPECIES_TWO, false, Gen2LinkSession.LINK_TIMECAPSULE, [0, 0]
	))
	assert_false(Gen2LinkSession.validate_ot_trademon(
		mon, SPECIES_TWO, false, Gen2LinkSession.LINK_TIMECAPSULE, [0, 3]
	))
	var magnemite: Dictionary = _mon(Gen2LinkSession.TIME_CAPSULE_RETYPED_SPECIES[0]).to_dict()
	magnemite["types"] = [0, 0]
	assert_true(Gen2LinkSession.validate_ot_trademon(
		magnemite, Gen2LinkSession.TIME_CAPSULE_RETYPED_SPECIES[0], false,
		Gen2LinkSession.LINK_TIMECAPSULE, [0, 3]
	))


## `CheckAnyOtherAliveMonsForTrade`, which reads the incoming Pokemon as well as
## the party left behind.
func test_a_trade_that_would_leave_nothing_to_fight_with_is_refused() -> void:
	var party: Array = [_mon(SPECIES_ONE).to_dict(), _mon(SPECIES_ONE, 0).to_dict()]
	var healthy: Dictionary = _mon(SPECIES_TWO).to_dict()
	var fainted: Dictionary = _mon(SPECIES_TWO, 0).to_dict()
	assert_true(Gen2LinkSession.any_other_alive_mons_for_trade(party, 0, healthy))
	assert_false(Gen2LinkSession.any_other_alive_mons_for_trade(party, 0, fainted))
	## Trading the fainted slot leaves the healthy one behind.
	assert_true(Gen2LinkSession.any_other_alive_mons_for_trade(party, 1, fainted))


func test_the_time_capsule_runs_its_three_tests_in_the_routines_order() -> void:
	var mail: int = Gen2HeldItem.MAIL_ITEMS[0]
	assert_eq(
		int(Gen2LinkSession.time_capsule_compatibility({
			"species": [1, 4], "held_items": [0, 0], "moves": [[1], [1]],
		})["value"]),
		Gen2LinkSession.TIME_CAPSULE_OK
	)
	assert_eq(
		int(Gen2LinkSession.time_capsule_compatibility({
			"species": [1, 152], "held_items": [0, mail], "moves": [[1], [200]],
		})["value"]),
		Gen2LinkSession.TIME_CAPSULE_MON_TOO_NEW
	)
	assert_eq(
		int(Gen2LinkSession.time_capsule_compatibility({
			"species": [1, 4], "held_items": [0, mail], "moves": [[1], [200]],
		})["value"]),
		Gen2LinkSession.TIME_CAPSULE_MON_HAS_MAIL
	)
	assert_eq(
		int(Gen2LinkSession.time_capsule_compatibility({
			"species": [1, 4], "held_items": [0, 0], "moves": [[1], [200]],
		})["value"]),
		Gen2LinkSession.TIME_CAPSULE_MOVE_TOO_NEW
	)


## `AddLastLinkBattleToLinkRecord`, and `.CheckOverflow` behind it.
func test_the_link_record_counts_totals_and_keeps_a_row_per_opponent() -> void:
	var record: Dictionary = Gen2LinkSession.normalize_record({})
	record = Gen2LinkSession.add_battle_to_record(record, {"name": "BLUE", "id": 1}, &"wins")
	record = Gen2LinkSession.add_battle_to_record(record, {"name": "BLUE", "id": 1}, &"wins")
	record = Gen2LinkSession.add_battle_to_record(record, {"name": "GREEN", "id": 2}, &"draws")
	assert_eq(int(record["wins"]), 2)
	assert_eq(int(record["draws"]), 1)
	assert_eq(String((record["records"] as Array)[0].get("name", "")), "BLUE")
	assert_eq(int((record["records"] as Array)[0].get("wins", 0)), 2)
	var names: Array = []
	for row: Dictionary in record["records"] as Array:
		names.append(String(row.get("name", "")))
	assert_true(names.has("GREEN"))


func test_the_link_record_stops_at_its_cap() -> void:
	var record: Dictionary = Gen2LinkSession.normalize_record({
		"wins": Gen2LinkSession.MAX_LINK_RECORD,
	})
	record = Gen2LinkSession.add_battle_to_record(record, {"name": "BLUE", "id": 1}, &"wins")
	assert_eq(int(record["wins"]), Gen2LinkSession.MAX_LINK_RECORD)


## A slot written before link play reads as one that has never linked, the way
## `mailbox` and `box_names` do.
func test_a_save_without_a_link_record_reads_as_one_that_never_linked() -> void:
	var save := Gen2SaveData.new()
	var restored: Gen2SaveData = Gen2SaveData.from_dict(save.to_dict())
	assert_eq(int(restored.link_record["wins"]), 0)
	assert_eq(
		(restored.link_record["records"] as Array).size(),
		Gen2LinkSession.NUM_LINK_BATTLE_RECORDS
	)


## `.do_trade`: `RemoveMonFromPartyOrBox` then `AddTempmonToParty`, so the
## received Pokemon lands at the END of the party rather than in the slot the
## given one left.
func test_a_link_trade_appends_the_received_mon_and_removes_the_offered_one() -> void:
	var world: Gen2WorldAPI = _world()
	var save: Gen2SaveData = _save()
	save.party = [_mon(SPECIES_ONE), _mon(SPECIES_ONE), _mon(SPECIES_ONE)]
	save.party[1].nickname = "GIVEN"
	var result: Dictionary = Gen2WorldPartyHost.commit_link_trade(
		world, save, 1, _mon(SPECIES_TWO).to_dict(), {"name": "BLUE"}, false
	)
	assert_true(bool(result.get("ok", false)), String(result.get("reason", "")))
	assert_eq(save.party.size(), 3)
	assert_eq((save.party[2] as Gen2SaveMon).species, SPECIES_TWO)
	for mon: Gen2SaveMon in save.party:
		assert_ne(mon.nickname, "GIVEN")


func test_a_link_trade_refuses_a_slot_that_is_not_in_the_party() -> void:
	var world: Gen2WorldAPI = _world()
	var save: Gen2SaveData = _save()
	save.party = [_mon(SPECIES_ONE)]
	var result: Dictionary = Gen2WorldPartyHost.commit_link_trade(
		world, save, 3, _mon(SPECIES_TWO).to_dict(), {}, false
	)
	assert_false(bool(result.get("ok", false)))
	assert_eq(StringName(result.get("reason", &"")), &"invalid_trade_slot")


## The same refusal `CheckAnyOtherAliveMonsForTrade` makes, at the boundary that
## writes: a caller that skipped the screen's own test must not get past it.
func test_a_link_trade_refuses_to_leave_the_party_unable_to_fight() -> void:
	var world: Gen2WorldAPI = _world()
	var save: Gen2SaveData = _save()
	save.party = [_mon(SPECIES_ONE)]
	var result: Dictionary = Gen2WorldPartyHost.commit_link_trade(
		world, save, 0, _mon(SPECIES_TWO, 0).to_dict(), {}, false
	)
	assert_false(bool(result.get("ok", false)))
	assert_eq(StringName(result.get("reason", &"")), &"trade_would_leave_no_battler")


func test_a_link_battle_writes_the_record_it_produced() -> void:
	var world: Gen2WorldAPI = _world()
	var save: Gen2SaveData = _save()
	save.party = [_mon(SPECIES_ONE)]
	var result: Dictionary = Gen2WorldPartyHost.record_link_battle(
		world, save, {"name": "BLUE", "id": 7}, &"wins", false
	)
	assert_true(bool(result.get("ok", false)), String(result.get("reason", "")))
	assert_eq(int(save.link_record["wins"]), 1)


## `BadgeStatBoosts` and `DoBadgeTypeBoosts` both `ret nz` on `wLinkMode`, so a
## link partner meets an unboosted party however many badges the player has.
func test_a_link_battle_pays_no_badge_boost() -> void:
	var prepared: Dictionary = Gen2WorldBattleAdapter.prepare(
		_data,
		{"values": {
			"kind": &"link_battle", "trainer_name": "BLUE",
			"enemy_party": [_mon(SPECIES_TWO).to_dict()],
		}},
		Gen2WorldBattleAdapter.fallback_party(_data, SPECIES_ONE, 5, 1),
		RandomNumberGenerator.new(), 0xFFFF
	)
	assert_true(bool(prepared.get("ok", false)), String(prepared.get("reason", "")))
	var battle: Gen2Battle = prepared["battle"]
	assert_eq(battle.player_badge_mask, 0)
	assert_eq(battle.player.stat("attack"), int(battle.player.stats["attack"]))


## A link battle is a whole-party exchange with no trainer class behind it,
## which is `battle_tower`'s shape one caller further out.
func test_a_link_battle_request_builds_the_peers_party() -> void:
	var prepared: Dictionary = Gen2WorldBattleAdapter.prepare(
		_data,
		{"kind": &"link_room_requested", "values": {
			"kind": &"link_battle", "trainer_name": "BLUE",
			"enemy_party": [_mon(SPECIES_TWO).to_dict()],
		}},
		Gen2WorldBattleAdapter.fallback_party(_data, SPECIES_ONE, 5, 1),
		RandomNumberGenerator.new()
	)
	assert_true(bool(prepared.get("ok", false)), String(prepared.get("reason", "")))
	assert_eq((prepared["enemy_party"] as Gen2Party).size(), 1)
	assert_eq(int(prepared["trainer_class"]), 0)


func _world() -> Gen2WorldAPI:
	return _live_world


func _save() -> Gen2SaveData:
	var save: Gen2SaveData = Gen2SaveStore.create_development_save(_data, 0)
	save.world = _live_world.snapshot()
	return save


## Mystery Gift is a second peer rather than the cable: `mystery_gift.asm`
## never touches `wLinkMode` and keeps its own SRAM block, so what follows is
## that block and the decision over it. The real-cartridge counterpart is
## `tools/checks/mystery_gift.gd`, which sweeps both gift tables and every box
## on all three dumps.


## `UnlockMysteryGift` is the one thing that clears the locked byte, and the
## main menu reads the backup pair rather than the working one: the row appears
## on the session after Carrie, because only a save copies one into the other.
func test_the_mystery_gift_row_appears_only_after_a_save() -> void:
	var section: Dictionary = Gen2MysteryGift.default_section()
	assert_false(Gen2MysteryGift.menu_row_unlocked(section))
	assert_true(Gen2MysteryGift.unlock(section))
	assert_false(
		Gen2MysteryGift.menu_row_unlocked(section),
		"Carrie clears sMysteryGiftUnlocked, not sNumDailyMysteryGiftPartnerIDs"
	)
	Gen2MysteryGift.backup(section)
	assert_true(Gen2MysteryGift.menu_row_unlocked(section))


## The gift lands in the backup pair, which is where a save wrote it from, so
## `RestoreMysteryGift` is what carries a gift received at the menu into the
## file the counter reads.
func test_a_gift_reaches_the_loaded_file_through_the_backup_pair() -> void:
	var section: Dictionary = Gen2MysteryGift.default_section()
	Gen2MysteryGift.unlock(section)
	section["backup_item"] = 0xAD
	assert_eq(Gen2MysteryGift.check_value(section), 0, "nothing is waiting yet")
	Gen2MysteryGift.restore(section)
	assert_eq(
		Gen2MysteryGift.check_value(section), 0xAE,
		"CheckMysteryGift answers the item plus one"
	)
	Gen2MysteryGift.clear_item(section)
	assert_eq(Gen2MysteryGift.check_value(section), 0)


## `DoMysteryGiftIfDayHasPassed`: the limit lifts when the day the countdown
## started on is behind us, and not before. A locked file keeps its -1, or the
## first midnight would put the menu row up on its own.
func test_the_daily_limit_lifts_only_once_a_day_has_passed() -> void:
	var section: Dictionary = Gen2MysteryGift.default_section()
	Gen2MysteryGift.unlock(section)
	Gen2MysteryGift.backup(section)
	section["daily_partners"] = Gen2MysteryGift.MAX_PARTNERS
	Gen2MysteryGift.start_countdown(section, 3)
	assert_false(Gen2MysteryGift.begin_session(section, 3))
	assert_eq(int(section["daily_partners"]), Gen2MysteryGift.MAX_PARTNERS)
	assert_true(Gen2MysteryGift.begin_session(section, 4))
	assert_eq(int(section["daily_partners"]), 0)

	var locked: Dictionary = Gen2MysteryGift.default_section()
	Gen2MysteryGift.start_countdown(locked, 3)
	assert_false(Gen2MysteryGift.begin_session(locked, 5))
	assert_false(
		Gen2MysteryGift.menu_row_unlocked(locked),
		"a midnight does not unlock a file Carrie has never spoken to"
	)


## A window with nobody in it is a real path rather than a stub: the exchange
## times out and `.CommunicationError` puts the prompt back up rather than
## leaving the screen.
func test_an_empty_infrared_window_times_out_into_the_retry_box() -> void:
	var transport := Gen2MysteryGiftTransport.new()
	assert_false(transport.connected())
	assert_eq(transport.status(), Gen2MysteryGift.MG_TIMED_OUT)
	var result: Dictionary = Gen2MysteryGift.exchange(
		Gen2MysteryGift.default_section(), transport, {}, {}
	)
	assert_eq(result["outcome"], Gen2MysteryGift.OUTCOME_COMM_ERROR)
	assert_true(result["retry"], "the routine loops back to its own prompt")


## `.AddMysteryGiftPartnerID` runs in front of the gift rather than behind it,
## so a partner whose decoration this side already owns still counts against
## both daily limits.
func test_a_partner_counts_even_when_the_decoration_was_already_received() -> void:
	var section: Dictionary = Gen2MysteryGift.default_section()
	Gen2MysteryGift.unlock(section)
	section["daily_partners"] = 0
	section["decorations_received"] = [7]
	var transport := Gen2MysteryGiftTransport.new()
	transport.peer = {
		"game_version": 1, "id": 0x0BAD, "name": "KRIS", "sent_deco": 1,
		"which_item": 0, "which_deco": 0, "backup_item": 0,
	}
	var result: Dictionary = Gen2MysteryGift.exchange(
		section, transport, {}, {"items": [0xAD], "decos": [7]}
	)
	assert_eq(result["outcome"], Gen2MysteryGift.OUTCOME_SENT)
	assert_eq(int(section["backup_item"]), 0xAD)
	assert_eq(int(section["daily_partners"]), 1)
	assert_eq(section["partner_ids"], [0x0BAD])
	assert_eq(
		int(section["trainer_house_flag"]), 1,
		"a linked file is what opens the Trainer House"
	)


## A rolled sample is always a row of the table it names, whichever of the four
## weighted bands it lands in: the last band answers 32 or 33 and no band can
## reach past the thirty-seven rows.
func test_every_staged_roll_names_a_row_of_its_own_table() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 7
	var section: Dictionary = Gen2MysteryGift.default_section()
	var save := Gen2SaveData.new()
	save.player_id = 0xBEEF
	var bands: Dictionary = {}
	for _roll: int in 512:
		var staged: Dictionary = Gen2MysteryGift.stage_player_data(
			save, section, 30, random
		)
		for key: String in ["which_item", "which_deco"]:
			var index: int = int(staged[key])
			assert_between(index, 0, RomLayout.MYSTERY_GIFT_TABLE_ROWS - 1)
			bands[index / 8] = true
	assert_true(bands.has(0), "the common band is reached")
	assert_true(bands.has(4), "the rarest band is reached")
