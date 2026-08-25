extends GutTest

## World state has a JSON-safe representation independent of the map cache.

## ENGINE_FLYPOINT_VERMILION's Crystal index (constants/engine_flags.asm). Named
## here rather than on Gen2WorldState because nothing in game/ reads a flypoint;
## the story walk does, and it holds Crystal indices.
const FLYPOINT_VERMILION: int = 58


func test_world_state_round_trips_persistent_overworld_fields() -> void:
	var state := Gen2WorldState.new(
		{7: true}, {"1:2": 4}, {3: 8}, {0: 120}, 17, {9: true},
		6, Vector2i(1, 2), 0xDF,
		[{"species": 0xF3, "level": 40, "map_group": 1, "map_number": 2}], true,
		0, Gen2WorldState.PHONE_RECEIVE_DELAYS[0], 0, {16: true}
	)
	var restored := Gen2WorldState.from_dict(state.to_dict())
	assert_true(restored.is_event_flag_active(7))
	assert_eq(restored.map_scene(1, 2), 4)
	assert_eq(restored.item_quantity(3), 8)
	assert_eq(restored.money(), 120)
	assert_eq(restored.coins(), 17)
	assert_true(restored.has_phone_contact(9))
	assert_eq(restored.repel_steps(), 6)
	assert_eq(restored.swarm_map(), Vector2i(1, 2))
	assert_eq(restored.fishing_swarm_species(), 0xDF)
	assert_true(restored.just_battled())
	assert_true(restored.has_seen_species(16))
	assert_eq(restored.roaming_mons().size(), 1)


## `wPCItems` is its own array, so it round-trips beside the bag rather than
## inside it. A state written before the item PC existed has no key at all,
## which restores as an empty PC.
func test_pc_items_round_trip_beside_the_bag() -> void:
	var state := Gen2WorldState.new({}, {}, {3: 8})
	assert_true(bool(state.apply_changes({}, {}, {"pc_items": {3: 2, 9: 1}})["ok"]))
	var restored := Gen2WorldState.from_dict(state.to_dict())
	assert_eq(restored.item_quantity(3), 8)
	assert_eq(restored.pc_item_quantity(3), 2)
	assert_eq(restored.pc_item_quantity(9), 1)
	var without: Dictionary = state.to_dict()
	without.erase("pc_items")
	assert_eq(Gen2WorldState.from_dict(without).pc_items().size(), 0)
	assert_eq(
		state.apply_changes({}, {}, {"pc_items": {0: 1}})["reason"],
		&"invalid_pc_item_quantity"
	)


func test_maptile_decorations_round_trip_and_validate_categories() -> void:
	var state := Gen2WorldState.new()
	assert_true(state.set_maptile_decoration(&"bed", 0x02))
	assert_true(state.set_maptile_decoration(&"poster", 0x10))
	assert_false(state.set_maptile_decoration(&"unknown", 1))
	assert_false(state.set_maptile_decoration(&"bed", 0x100))
	var restored := Gen2WorldState.from_dict(state.to_dict())
	assert_eq(restored.maptile_decoration(&"bed"), 0x02)
	assert_eq(restored.maptile_decoration(&"poster"), 0x10)
	assert_eq(restored.maptile_decoration(&"plant"), 0)


func test_engine_flags_round_trip_and_daily_reset_preserves_hall_of_fame() -> void:
	var state := Gen2WorldState.new()
	state.set_hall_of_fame()
	var changed: Dictionary = state.apply_changes({}, {}, {
		"engine_flags": {
			Gen2WorldState.ENGINE_GOLDENROD_UNDERGROUND_MERCHANT_CLOSED: true,
		},
	})
	assert_true(changed["ok"])
	var restored := Gen2WorldState.from_dict(state.to_dict())
	assert_true(restored.hall_of_fame())
	assert_true(restored.bargain_merchant_closed())
	assert_true(restored.reset_daily_flags())
	assert_true(restored.hall_of_fame())
	assert_false(restored.bargain_merchant_closed())
	assert_false(restored.reset_daily_flags())


func test_badge_count_matches_active_flags_across_both_bytes() -> void:
	var state := Gen2WorldState.new()
	assert_eq(state.badge_count(), 0)
	state.set_engine_flag(Gen2WorldState.ENGINE_ZEPHYRBADGE)
	assert_eq(state.badge_count(), 1)
	for flag: int in Gen2WorldState.BADGE_ENGINE_FLAGS:
		state.set_engine_flag(flag)
	assert_eq(state.badge_count(), 16)
	## wBadges is one contiguous flag_array spanning both wJohtoBadges and
	## wKantoBadges, so a Kanto badge must count toward the same total.
	var kanto_only := Gen2WorldState.new()
	kanto_only.set_engine_flag(Gen2WorldState.ENGINE_EARTHBADGE)
	assert_eq(kanto_only.badge_count(), 1)


func test_badge_mask_follows_source_order_on_both_profiles() -> void:
	var crystal := Gen2WorldState.new()
	crystal.set_engine_flag(Gen2WorldState.ENGINE_ZEPHYRBADGE)
	crystal.set_engine_flag(Gen2WorldState.ENGINE_EARTHBADGE)
	assert_eq(crystal.badge_mask(), (1 << 0) | (1 << 15))

	var gold := Gen2WorldState.new()
	gold.set_engine_flag(Gen2WorldState.ENGINE_ZEPHYRBADGE - 1)
	gold.set_engine_flag(Gen2WorldState.ENGINE_EARTHBADGE - 1)
	assert_eq(gold.badge_mask(false), (1 << 0) | (1 << 15))


## `wUnlockedUnowns` sits directly after `wKantoBadges` in the engine-flag
## table, so it carries the badges' own one-index profile shift, and it is what
## `CheckUnownLetter` refuses a rolled wild Unown's letter against.
func test_the_unlocked_unown_sets_follow_the_badges_onto_both_profiles() -> void:
	var crystal := Gen2WorldState.new()
	assert_eq(crystal.unlocked_unowns(), 0)
	crystal.set_engine_flag(Gen2WorldState.ENGINE_UNLOCKED_UNOWNS_FIRST)
	crystal.set_engine_flag(Gen2WorldState.ENGINE_UNLOCKED_UNOWNS_FIRST + 3)
	assert_eq(crystal.unlocked_unowns(), (1 << 0) | (1 << 3))

	var gold := Gen2WorldState.new()
	gold.set_engine_flag(Gen2WorldState.ENGINE_UNLOCKED_UNOWNS_FIRST - 1)
	assert_eq(gold.unlocked_unowns(false), 1 << 0)
	## The Crystal index on a Gold table would land one row late, on L-R.
	assert_eq(gold.unlocked_unowns(), 0)


## `CheckUnownLetter` walks only the sets whose bit is set, so a letter is
## unlocked when ANY unlocked set holds it. A save with nothing solved holds no
## letter at all, and a negative mask is the no-gate a caller with no save passes.
func test_an_unown_letter_is_unlocked_by_any_set_that_holds_it() -> void:
	assert_true(Gen2WorldState.unown_letter_unlocked(1, 0b0001), "A in A-K")
	assert_false(Gen2WorldState.unown_letter_unlocked(12, 0b0001), "L is not")
	assert_true(Gen2WorldState.unown_letter_unlocked(12, 0b0011), "L once L-R is up")
	assert_true(Gen2WorldState.unown_letter_unlocked(26, 0b1000), "Z in X-Z")
	for letter: int in range(1, 27):
		assert_false(Gen2WorldState.unown_letter_unlocked(letter, 0), "nothing solved")
		assert_true(Gen2WorldState.unown_letter_unlocked(letter, -1), "no gate")
	## The four sets are the whole alphabet with no letter in two of them.
	var seen: Dictionary = {}
	for one_set: Array in Gen2WorldState.UNOWN_LETTER_SETS:
		for letter: int in one_set:
			assert_false(seen.has(letter), "letter %d is in two sets" % letter)
			seen[letter] = true
	assert_eq(seen.size(), RomLayout.UNOWN_FORMS)


## BIKEFLAGS_STRENGTH_ACTIVE_F sits three flags ahead of ENGINE_ZEPHYRBADGE, so
## it carries the same one-index profile shift the badges do, and it must not be
## confused with a badge in either direction.
func test_strength_active_flag_is_profile_split_and_is_not_a_badge() -> void:
	assert_eq(Gen2WorldState.strength_active_flag(true), 24)
	assert_eq(Gen2WorldState.strength_active_flag(false), 23)
	assert_eq(
		Gen2WorldState.strength_active_flag(true),
		Gen2WorldState.badge_flag(0, true) - 3
	)
	assert_eq(
		Gen2WorldState.strength_active_flag(false),
		Gen2WorldState.badge_flag(0, false) - 3
	)

	var state := Gen2WorldState.new()
	state.set_engine_flag(Gen2WorldState.strength_active_flag(true))
	assert_true(state.is_engine_flag_active(Gen2WorldState.strength_active_flag(true)))
	assert_false(state.is_engine_flag_active(Gen2WorldState.strength_active_flag(false)))
	assert_eq(state.badge_count(true), 0)
	assert_eq(state.badge_count(false), 0)


## Nothing in the pinned engine/ or home/ ever clears BIKEFLAGS_STRENGTH_ACTIVE_F,
## and engine flags serialize with the world snapshot, so the flag has to outlive
## a round trip and the map-reload reset that clears temporary event flags.
func test_strength_active_flag_survives_round_trip_and_map_reload() -> void:
	var state := Gen2WorldState.new()
	state.set_engine_flag(Gen2WorldState.strength_active_flag(true))
	state.set_event_flag(0, true)

	var restored: Gen2WorldState = Gen2WorldState.from_dict(state.to_dict())
	assert_true(restored.is_engine_flag_active(Gen2WorldState.strength_active_flag(true)))
	restored.reset_map_reload_flags()
	assert_true(restored.is_engine_flag_active(Gen2WorldState.strength_active_flag(true)))
	assert_false(restored.is_event_flag_active(0))


## pokegold's engine flag table has no ENGINE_MOBILE_SYSTEM entry ahead of the
## badge section, so every pokegold badge sits one index lower than the same
## symbol in pokecrystal's constants/engine_flags.asm. A Crystal-numbered
## ENGINE_ZEPHYRBADGE write must not count as a Gold/Silver badge, and a
## Gold/Silver-numbered write (one lower) must not count as a Crystal badge.
func test_badge_count_uses_the_gold_silver_table_when_requested() -> void:
	## Index 42 (ENGINE_EARTHBADGE) is the Crystal table's Kanto endpoint and
	## falls outside the Gold/Silver table (26-41), so it isolates the
	## Crystal-only end of the one-index shift.
	var state := Gen2WorldState.new()
	state.set_engine_flag(Gen2WorldState.ENGINE_EARTHBADGE)
	assert_eq(state.badge_count(true), 1)
	assert_eq(state.badge_count(false), 0)

	## Index 26 (ENGINE_ZEPHYRBADGE - 1) is the Gold/Silver table's Johto
	## endpoint and falls outside the Crystal table (27-42), isolating the
	## Gold/Silver-only end.
	var gold_state := Gen2WorldState.new()
	gold_state.set_engine_flag(Gen2WorldState.ENGINE_ZEPHYRBADGE - 1)
	assert_eq(gold_state.badge_count(false), 1)
	assert_eq(gold_state.badge_count(true), 0)

	for flag: int in Gen2WorldState.BADGE_ENGINE_FLAGS_GOLD_SILVER:
		gold_state.set_engine_flag(flag)
	assert_eq(gold_state.badge_count(false), 16)


## Same one-index shift for the Goldenrod Underground merchant flag: pinned
## pokecrystal has it at 86, pinned pokegold at 85.
func test_bargain_merchant_closed_uses_the_gold_silver_flag_when_requested() -> void:
	var state := Gen2WorldState.new()
	state.set_engine_flag(Gen2WorldState.ENGINE_GOLDENROD_UNDERGROUND_MERCHANT_CLOSED)
	assert_true(state.bargain_merchant_closed(true))
	assert_false(state.bargain_merchant_closed(false))

	var gold_state := Gen2WorldState.new()
	gold_state.set_engine_flag(
		Gen2WorldState.ENGINE_GOLDENROD_UNDERGROUND_MERCHANT_CLOSED_GOLD_SILVER
	)
	assert_true(gold_state.bargain_merchant_closed(false))
	assert_false(gold_state.bargain_merchant_closed(true))


func test_reset_daily_flags_clears_the_matching_profiles_merchant_flag_only() -> void:
	var gold_state := Gen2WorldState.new()
	gold_state.set_engine_flag(
		Gen2WorldState.ENGINE_GOLDENROD_UNDERGROUND_MERCHANT_CLOSED_GOLD_SILVER
	)
	assert_false(gold_state.reset_daily_flags(true))
	assert_true(gold_state.bargain_merchant_closed(false))
	assert_true(gold_state.reset_daily_flags(false))
	assert_false(gold_state.bargain_merchant_closed(false))


## CheckDailyResetTimer zeroes the whole wDailyFlags1 byte, so Kurt's flag goes
## with the merchant's. Without it he never finishes a ball.
func test_reset_daily_flags_clears_kurts_flag_on_both_profiles() -> void:
	for crystal: bool in [true, false]:
		var state := Gen2WorldState.new()
		var flag: int = Gen2WorldState.engine_flag(
			Gen2WorldState.ENGINE_KURT_MAKING_BALLS, crystal
		)
		state.set_engine_flag(flag)
		assert_false(state.reset_daily_flags(not crystal))
		assert_true(state.is_engine_flag_active(flag))
		assert_true(state.reset_daily_flags(crystal))
		assert_false(state.is_engine_flag_active(flag))


func test_the_saved_kurt_quantity_survives_a_snapshot_round_trip() -> void:
	var state := Gen2WorldState.new()
	state.set_kurt_apricorn_quantity(7)
	var restored: Gen2WorldState = Gen2WorldState.from_dict(state.to_dict())
	assert_eq(restored.kurt_apricorn_quantity(), 7)
	## Absent in a state written before the errand existed, and zero is what a
	## fresh SelectApricornForKurt writes anyway.
	assert_eq(Gen2WorldState.from_dict({}).kurt_apricorn_quantity(), 0)


## Gen2WorldState.is_crystal_profile mirrors
## Gen2WorldScriptRunner._crystal_commands(): only a verified Gold or Silver
## cache is treated as the shorter engine flag table.
func test_is_crystal_profile_matches_the_game_id_and_defaults_true_for_no_data() -> void:
	assert_true(Gen2WorldState.is_crystal_profile(null))
	var crystal_data := GameData.new()
	crystal_data.id = &"crystal"
	assert_true(Gen2WorldState.is_crystal_profile(crystal_data))
	var gold_data := GameData.new()
	gold_data.id = &"gold"
	assert_false(Gen2WorldState.is_crystal_profile(gold_data))
	var silver_data := GameData.new()
	silver_data.id = &"silver"
	assert_false(Gen2WorldState.is_crystal_profile(silver_data))


## engine_flag() is the same one-index shift the named *_GOLD_SILVER constants
## spell out, for a caller holding a Crystal index and no pair. The three named
## pairs are what pin the shift's direction here: a derived answer that
## disagreed with any of them would be wrong in the same way twice.
func test_engine_flag_maps_a_crystal_index_onto_the_gold_silver_table() -> void:
	for index: int in [0, 3, 4, 15, Gen2WorldState.ENGINE_MOBILE_SYSTEM - 1]:
		assert_eq(Gen2WorldState.engine_flag(index, true), index)
		assert_eq(Gen2WorldState.engine_flag(index, false), index)

	## ENGINE_MOBILE_SYSTEM is the entry pokegold does not ship, so it maps onto
	## nothing there; -1 is what is_engine_flag_active() reads as inactive.
	assert_eq(
		Gen2WorldState.engine_flag(Gen2WorldState.ENGINE_MOBILE_SYSTEM, true),
		Gen2WorldState.ENGINE_MOBILE_SYSTEM
	)
	assert_eq(
		Gen2WorldState.engine_flag(Gen2WorldState.ENGINE_MOBILE_SYSTEM, false), -1
	)

	for pair: Array in [
		[Gen2WorldState.ENGINE_ROCKETS_IN_RADIO_TOWER,
			Gen2WorldState.ENGINE_ROCKETS_IN_RADIO_TOWER_GOLD_SILVER],
		[Gen2WorldState.ENGINE_STRENGTH_ACTIVE,
			Gen2WorldState.ENGINE_STRENGTH_ACTIVE_GOLD_SILVER],
		[Gen2WorldState.ENGINE_GOLDENROD_UNDERGROUND_MERCHANT_CLOSED,
			Gen2WorldState.ENGINE_GOLDENROD_UNDERGROUND_MERCHANT_CLOSED_GOLD_SILVER],
	]:
		assert_eq(Gen2WorldState.engine_flag(pair[0], true), pair[0])
		assert_eq(Gen2WorldState.engine_flag(pair[0], false), pair[1])

	for badge: int in Gen2WorldState.BADGE_ENGINE_FLAGS.size():
		assert_eq(
			Gen2WorldState.engine_flag(Gen2WorldState.badge_flag(badge, true), false),
			Gen2WorldState.badge_flag(badge, false)
		)

	## The read a caller actually makes: a Crystal index resolved on the Gold
	## table must find a Gold write and miss a Crystal one.
	var state := Gen2WorldState.new()
	state.set_engine_flag(Gen2WorldState.engine_flag(FLYPOINT_VERMILION, false))
	assert_true(state.is_engine_flag_active(
		Gen2WorldState.engine_flag(FLYPOINT_VERMILION, false)
	))
	assert_false(state.is_engine_flag_active(
		Gen2WorldState.engine_flag(FLYPOINT_VERMILION, true)
	))


func test_badge_flags_survive_round_trip_and_daily_or_map_reload_resets() -> void:
	var state := Gen2WorldState.new()
	state.set_engine_flag(Gen2WorldState.ENGINE_ZEPHYRBADGE)
	state.set_engine_flag(Gen2WorldState.ENGINE_HIVEBADGE)
	var restored := Gen2WorldState.from_dict(state.to_dict())
	assert_eq(restored.badge_count(), 2)
	restored.reset_daily_flags()
	assert_eq(restored.badge_count(), 2)
	restored.reset_map_reload_flags()
	assert_eq(restored.badge_count(), 2)


func test_source_temporary_event_flags_include_zero_and_reset_on_map_reload() -> void:
	var state := Gen2WorldState.new()
	state.set_event_flag(0)
	state.set_event_flag(7)
	state.set_event_flag(8)
	assert_true(state.is_event_flag_active(0))
	assert_true(state.is_event_flag_active(7))
	assert_true(state.is_event_flag_active(8))
	assert_true(state.reset_map_reload_flags())
	assert_false(state.is_event_flag_active(0))
	assert_false(state.is_event_flag_active(7))
	assert_true(state.is_event_flag_active(8))
	assert_false(state.reset_map_reload_flags())


func test_invalid_engine_flag_transaction_does_not_mutate_state() -> void:
	var state := Gen2WorldState.new()
	var failed: Dictionary = state.apply_changes({}, {}, {
		"engine_flags": {-1: true},
	})
	assert_false(failed["ok"])
	assert_false(state.hall_of_fame())
	assert_false(state.bargain_merchant_closed())


func test_world_state_rejects_invalid_swarm_transaction_without_mutation() -> void:
	var state := Gen2WorldState.new()
	var failed: Dictionary = state.apply_changes({}, {}, {
		"swarm": {"active": true, "map_group": 1, "map_number": 1, "fishing_species": 99},
	})
	assert_false(failed["ok"])
	assert_eq(state.swarm_map(), Vector2i(-1, -1))
	assert_eq(state.fishing_swarm_species(), 0)


func test_phone_timer_and_pending_special_call_round_trip() -> void:
	var state := Gen2WorldState.new()
	assert_eq(state.phone_receive_cycle(), 0)
	assert_eq(state.phone_receive_minutes(), 20)
	assert_false(state.advance_phone_receive_timer(19))
	assert_eq(state.phone_receive_minutes(), 1)
	assert_true(state.advance_phone_receive_timer(1))
	assert_true(state.phone_receive_ready())
	assert_true(state.consume_phone_receive_timer())
	assert_eq(state.phone_receive_cycle(), 1)
	assert_eq(state.phone_receive_minutes(), 10)
	var changed: Dictionary = state.apply_changes({}, {}, {
		"pending_special_phone_call": 6,
	})
	assert_true(changed["ok"])
	var restored := Gen2WorldState.from_dict(state.to_dict())
	assert_eq(restored.pending_special_phone_call(), 6)
	assert_eq(restored.phone_receive_cycle(), 1)
	assert_eq(restored.phone_receive_minutes(), 10)


func test_phone_contact_transaction_enforces_the_cartridge_capacity() -> void:
	var state := Gen2WorldState.new()
	var contacts: Dictionary = {}
	for contact: int in Gen2WorldState.PHONE_CONTACT_CAPACITY:
		contacts[contact] = true
	var accepted: Dictionary = state.apply_changes({}, {}, {"phone_contacts": contacts})
	assert_true(accepted["ok"])
	var rejected: Dictionary = state.apply_changes({}, {}, {"phone_contacts": {10: true}})
	assert_false(rejected["ok"])
	assert_eq(state.phone_contact_count(), Gen2WorldState.PHONE_CONTACT_CAPACITY)


func test_seen_species_changes_round_trip_and_commit_atomically() -> void:
	var state := Gen2WorldState.new()
	var changed: Dictionary = state.apply_changes({}, {}, {"seen_species": {25: true}})
	assert_true(changed["ok"])
	assert_true(state.has_seen_species(25))
	var restored := Gen2WorldState.from_dict(state.to_dict())
	assert_true(restored.has_seen_species(25))


## readmem/writemem/loadmem address plain WRAM bytes; only a bounded handful
## carry script state, so the state keeps them as an address-keyed byte map.
func test_script_memory_round_trips_and_rejects_out_of_range_bytes() -> void:
	var state := Gen2WorldState.new()
	assert_eq(state.script_memory(0xD1D6), 0, "an address never written reads zero")
	var changed: Dictionary = state.apply_changes({}, {}, {"script_memory": {0xD1D6: 7}})
	assert_true(changed["ok"])
	assert_eq(state.script_memory(0xD1D6), 7)
	var restored := Gen2WorldState.from_dict(state.to_dict())
	assert_eq(restored.script_memory(0xD1D6), 7)

	var cleared: Dictionary = state.apply_changes({}, {}, {"script_memory": {0xD1D6: 0}})
	assert_true(cleared["ok"])
	assert_eq(state.script_memory(0xD1D6), 0)
	assert_false(state.script_memory_values().has(0xD1D6))

	for rejected: Dictionary in [{0xD1D6: 256}, {0xD1D6: -1}, {0: 3}]:
		var result: Dictionary = state.apply_changes({}, {}, {"script_memory": rejected})
		assert_false(result["ok"], JSON.stringify(rejected))
		assert_eq(result["reason"], &"invalid_script_memory")
	assert_eq(state.script_memory(0xD1D6), 0, "a refused transaction mutates nothing")


## InitRoamMons seeds the roam structs, and Gen2WorldAPI.open() seeds the same
## imported records, so re-seeding must not teleport a beast already loose.
func test_seeding_roaming_mons_keeps_a_record_that_already_moved() -> void:
	var initial: Array = [{"species": 243, "level": 40, "map_group": 1, "map_number": 1}]
	var state := Gen2WorldState.new()
	state.ensure_roaming_mons(initial)
	assert_eq(state.roaming_mons(), initial)

	var moved: Array = [{"species": 243, "level": 40, "map_group": 5, "map_number": 9}]
	var loose: Gen2WorldState = Gen2WorldState.from_dict({"roaming_mons": moved})
	loose.ensure_roaming_mons(initial)
	assert_eq(loose.roaming_mons(), moved)


## A missing schedule stream must be a no-op, because creating and randomizing
## a generator here makes save-state movement depend on an invisible source.
func test_roaming_does_not_roll_without_an_injected_generator() -> void:
	var state := Gen2WorldState.new()
	var initial: Array = [{"species": 243, "level": 40, "map_group": 1, "map_number": 1}]
	state.ensure_roaming_mons(initial)
	var rows: Array = [{
		"map_group": 1,
		"map_number": 1,
		"connections": [{"map_group": 1, "map_number": 2}],
	}]

	assert_eq(state.advance_roaming(rows), [])
	assert_eq(state.roaming_mons(), initial)


## `wLastDexMode` sits in the saved player data, so it survives a snapshot the
## way the radio knob beside it does.
func test_the_last_dex_mode_round_trips() -> void:
	var state := Gen2WorldState.new()
	assert_eq(state.last_dex_mode(), RomLayout.DEXMODE_NEW, "a fresh state opens on NEW")
	state.set_last_dex_mode(RomLayout.DEXMODE_ABC)
	var restored := Gen2WorldState.from_dict(state.to_dict())
	assert_eq(restored.last_dex_mode(), RomLayout.DEXMODE_ABC)


## DEXMODE_UNOWN is the Unown dex rather than a listing order, and never becomes
## wCurDexMode, so it is refused rather than stored.
func test_the_unown_dex_is_not_a_listing_mode() -> void:
	var state := Gen2WorldState.new()
	state.set_last_dex_mode(RomLayout.DEXMODE_UNOWN)
	assert_eq(state.last_dex_mode(), RomLayout.DEXMODE_NEW)


## `UpdateUnownDex` walks to the first empty slot: a form already listed keeps
## its place, and the list only ever grows at the end.
func test_the_unown_dex_appends_in_catching_order_and_never_twice() -> void:
	var state := Gen2WorldState.new()
	for form: int in [12, 3, 12, 26, 3]:
		state.update_unown_dex(form)
	assert_eq(state.unown_dex(), [12, 3, 26] as Array[int])
	assert_eq(state.unown_caught_count(), 3)

	# A form outside the twenty-six is not a slot the loop can reach.
	state.update_unown_dex(0)
	state.update_unown_dex(RomLayout.UNOWN_FORMS + 1)
	assert_eq(state.unown_caught_count(), 3)

	var restored := Gen2WorldState.from_dict(state.to_dict())
	assert_eq(restored.unown_dex(), [12, 3, 26] as Array[int])


## A snapshot written before the Unown dex existed restores as an empty one
## rather than refusing, which is why no save format bump went with it.
func test_a_state_without_an_unown_dex_restores_empty() -> void:
	var state := Gen2WorldState.new()
	state.update_unown_dex(4)
	var raw: Dictionary = state.to_dict()
	raw.erase("unown_dex")
	assert_true(Gen2WorldState.from_dict(raw).unown_dex().is_empty())


## `CountStep` and `StepHappiness`: the party gains a point every 512 steps,
## because `wStepCount` has to wrap for `StepHappiness` to be reached at all and
## its own `and 1` acts on every second visit. `wPoisonStepCount` counts on the
## same step and wraps on its own byte.
func test_count_step_owes_step_happiness_every_five_hundred_and_twelve_steps() -> void:
	var state := Gen2WorldState.new()
	for _step: int in 511:
		state.count_step()
	assert_eq(state.step_count(), 511 & 0xFF)
	assert_eq(state.take_pending_step_happiness(), 0, "the first wrap is the odd visit")
	state.count_step()
	assert_eq(state.step_count(), 0)
	assert_eq(state.poison_step_count(), 0)
	assert_eq(state.take_pending_step_happiness(), 1)
	assert_eq(state.take_pending_step_happiness(), 0, "draining forgets what it took")
	for _step: int in 512:
		state.count_step()
	assert_eq(state.take_pending_step_happiness(), 1)


## `CountStep`'s `cp $80`: `DoEggStep` is owed every 256 steps, half a wrap away
## from the `StepHappiness` pass at zero.
func test_count_step_owes_an_egg_step_every_two_hundred_and_fifty_six_steps() -> void:
	var state := Gen2WorldState.new()
	for _step: int in Gen2WorldState.EGG_STEP_PHASE - 1:
		state.count_step()
	assert_eq(state.take_pending_egg_steps(), 0)
	state.count_step()
	assert_eq(state.step_count(), Gen2WorldState.EGG_STEP_PHASE)
	assert_eq(state.take_pending_egg_steps(), 1)
	assert_eq(state.take_pending_egg_steps(), 0, "draining forgets what it took")
	assert_eq(state.take_pending_step_happiness(), 0, "the two passes never share a step")
	for _step: int in 256:
		state.count_step()
	assert_eq(state.take_pending_egg_steps(), 1)


## The Repel countdown was the whole of this call before the counters joined it,
## and it still spends one step at a time and stops at zero.
func test_count_step_spends_a_repel_step_and_stops_at_zero() -> void:
	var state := Gen2WorldState.new({}, {}, {}, {}, 0, {}, 2)
	state.count_step()
	assert_eq(state.repel_steps(), 1)
	state.count_step()
	state.count_step()
	assert_eq(state.repel_steps(), 0)


## The one step a Repel runs out on, which is where a renewal offer belongs.
## Held rather than cleared by the read, so an offer landing on a step a warp or
## a script already owns waits for one that can spend it.
func test_the_step_that_runs_a_repel_out_is_an_edge_the_reader_holds() -> void:
	var state := Gen2WorldState.new({}, {}, {}, {}, 0, {}, 2)
	state.count_step()
	assert_false(state.repel_expired(), "one step left is not an edge")
	state.count_step()
	assert_true(state.repel_expired())
	assert_true(state.repel_expired(), "reading it does not spend it")
	state.count_step()
	assert_true(state.repel_expired(), "a step with no Repel does not clear it either")
	state.clear_repel_expired()
	assert_false(state.repel_expired())
	## A walk with no Repel on at all never raises it.
	var walking := Gen2WorldState.new()
	walking.count_step()
	assert_false(walking.repel_expired())


## `DoRepelStep` stands in front of the counters and its wear-off answers with
## carry, so `CountStep` reaches `.doscript` and charges the step to nothing:
## not the poison phase, not the step count, not the Day-Care.
func test_the_step_a_repel_runs_out_on_is_counted_for_nothing() -> void:
	var state := Gen2WorldState.new({}, {}, {}, {}, 0, {}, 2)
	assert_true(state.count_step(), "a step with the Repel still on is counted")
	assert_eq(state.poison_step_count(), 1)
	assert_false(state.count_step(), "the step it wears off on is not")
	assert_eq(state.poison_step_count(), 1)
	assert_eq(state.step_count(), 1)
	assert_eq(state.take_pending_day_care_steps(), 1)
	assert_true(state.count_step(), "the step after it is counted again")
	assert_eq(state.poison_step_count(), 2)


## The three counters are saved beside the Repel countdown. A state written
## before they existed carries none of the keys and restores as a fresh walk.
func test_step_counters_round_trip_and_default_to_a_fresh_walk() -> void:
	var state := Gen2WorldState.new()
	for _step: int in 300:
		state.count_step()
	var restored := Gen2WorldState.from_dict(state.to_dict())
	assert_eq(restored.step_count(), 300 & 0xFF)
	assert_eq(restored.poison_step_count(), 300 & 0xFF)
	var legacy := Gen2WorldState.from_dict({"items": {}})
	assert_eq(legacy.step_count(), 0)
	assert_eq(legacy.poison_step_count(), 0)


## `CheckDailyResetTimer` does more than clear the flag bytes: `wKenjiBreakTimer`
## is stepped on every day that passes and resampled when it runs out, and the
## lucky number's own countdown is stepped beside it. A weekday alone cannot say
## how many days have gone by, so the rollover is where both are moved.
func test_a_day_passing_steps_the_two_day_counted_timers() -> void:
	var state := Gen2WorldState.new()
	var random := RandomNumberGenerator.new()
	random.seed = 7
	state.restart_lucky_number_countdown(Gen2WorldClock.FRIDAY)
	assert_false(state.lucky_number_show_ready(), "a Friday restarts a whole week")
	for _day: int in Gen2WorldClock.DAYS_PER_WEEK - 1:
		state.reset_daily_flags(true, random)
		assert_false(state.lucky_number_show_ready())
	state.reset_daily_flags(true, random)
	assert_true(state.lucky_number_show_ready(), "seven days later it comes round")
	## `SampleKenjiBreakCountdown` is three to six, and a zero timer resamples
	## rather than going negative.
	assert_between(state.kenji_break_timer(), 3, 6)


## `RestartLuckyNumberCountdown.GetDaysUntilNextFriday`, which answers the days
## to the coming Friday and seven on a Friday or a Saturday.
func test_the_lucky_number_countdown_runs_to_the_next_friday() -> void:
	for row: Array in [[0, 5], [4, 1], [5, 7], [6, 6]]:
		var state := Gen2WorldState.new()
		state.restart_lucky_number_countdown(int(row[0]))
		for _day: int in int(row[1]) - 1:
			state.reset_daily_flags()
			assert_false(state.lucky_number_show_ready(), "day %d" % int(row[0]))
		state.reset_daily_flags()
		assert_true(state.lucky_number_show_ready(), "day %d" % int(row[0]))


## `LoadOrRegenerateLuckyIDNumber`: `sLuckyNumberDay` holds the day plus one, so
## a stored zero is "never drawn" and a day whose stamp already matches keeps
## the number it had rather than spending two rolls on a new one.
func test_todays_lucky_number_is_drawn_once_a_day() -> void:
	var state := Gen2WorldState.new()
	var random := RandomNumberGenerator.new()
	random.seed = 11
	assert_true(state.refresh_lucky_id_number(3, random))
	var drawn: int = state.lucky_id_number()
	assert_false(state.refresh_lucky_id_number(3, random), "the same day draws nothing")
	assert_eq(state.lucky_id_number(), drawn)
	assert_true(state.refresh_lucky_id_number(4, random))
	assert_between(state.lucky_id_number(), 0, 0xFFFF)


## Every byte the deferred routines added survives a save and a reload, since
## each of them is read a session later: the record on the Magikarp house sign,
## Mom's own flags, the Blue Card and the password the radio drew this morning.
func test_the_deferred_routines_state_survives_a_round_trip() -> void:
	var state := Gen2WorldState.new()
	state.set_best_magikarp(4, 7, "MANIA")
	state.set_mom_savings_flags(0x81)
	state.set_blue_card_balance(12)
	state.set_buenas_password(0x32)
	state.set_kenji_break_timer(5)
	state.set_battle_caught_celebi(true)
	var restored: Gen2WorldState = Gen2WorldState.from_dict(state.to_dict())
	assert_eq(restored.best_magikarp(), {"feet": 4, "inches": 7, "ot": "MANIA"})
	assert_eq(restored.mom_savings_flags(), 0x81)
	assert_eq(restored.blue_card_balance(), 12)
	assert_eq(restored.buenas_password(), 0x32)
	assert_eq(restored.kenji_break_timer(), 5)
	assert_true(restored.battle_caught_celebi())


## `SECTION "SRAM Battle Tower"`: a challenge saved between two battles has to
## come back with the room it chose, the trainers it has already met and the
## reward it drew, or the streak restarts against the same opponents.
func test_a_battle_tower_challenge_survives_a_round_trip() -> void:
	var state := Gen2WorldState.new()
	var tower: Gen2BattleTower = state.battle_tower()
	tower.challenge_state = Gen2BattleTower.CHALLENGE_IN_PROGRESS
	tower.beaten = 3
	tower.chosen_group = 7
	tower.level_group = 7
	tower.trainers = [12, 40, 3, 0xFF, 0xFF, 0xFF, 0xFF]
	tower.save_file_flags = Gen2BattleTower.FLAG_EXPLANATION_READ
	tower.reward = Gen2BattleTower.MIN_REWARD
	tower.previous_mons = [135, 197, 6]
	var restored: Gen2WorldState = Gen2WorldState.from_dict(state.to_dict())
	var back: Gen2BattleTower = restored.battle_tower()
	assert_eq(back.challenge_state, Gen2BattleTower.CHALLENGE_IN_PROGRESS)
	assert_eq(back.beaten, 3)
	assert_eq(back.chosen_group, 7)
	assert_eq(back.level_group, 7)
	assert_eq(back.trainers, [12, 40, 3, 0xFF, 0xFF, 0xFF, 0xFF])
	assert_eq(back.save_file_flags, Gen2BattleTower.FLAG_EXPLANATION_READ)
	assert_eq(back.reward, Gen2BattleTower.MIN_REWARD)
	assert_eq(back.previous_mons, [135, 197, 6])


## A slot written before the tower existed reads as one with no challenge in it,
## which is the truth about it: nothing versions for this, the way `box_names`
## and the Hall of Fame do not.
func test_a_slot_with_no_battle_tower_record_reads_as_no_challenge() -> void:
	var raw: Dictionary = Gen2WorldState.new().to_dict()
	raw.erase("battle_tower")
	var tower: Gen2BattleTower = Gen2WorldState.from_dict(raw).battle_tower()
	assert_eq(tower.challenge_state, Gen2BattleTower.NO_CHALLENGE)
	assert_eq(tower.beaten, 0)
	assert_eq(tower.trainers.size(), Gen2BattleTower.STREAK_LENGTH)
	assert_eq(tower.trainers[0], Gen2BattleTower.NO_TRAINER)


## `ResetBattleTowerTrainersSRAM` clears the streak and its count and nothing
## else: `Script_ChooseChallenge` runs it every time the counter is approached,
## and a cleared explanation flag would make the receptionist explain the tower
## again on every visit.
func test_resetting_the_streak_keeps_the_explanation_and_the_room() -> void:
	var tower := Gen2BattleTower.new()
	tower.beaten = 4
	tower.trainers[0] = 12
	tower.level_group = 5
	tower.save_file_flags = Gen2BattleTower.FLAG_EXPLANATION_READ
	tower.reset_trainers()
	assert_eq(tower.beaten, 0)
	assert_eq(tower.trainers[0], Gen2BattleTower.NO_TRAINER)
	assert_eq(tower.level_group, 5)
	assert_eq(tower.save_file_flags, Gen2BattleTower.FLAG_EXPLANATION_READ)


## `BattleTower_GiveReward`'s own shape, which is not "is there room": a pack
## under `MAX_ITEMS` always has room for a new row, and a full one only when it
## already carries the reward with fewer than 95 of it.
func test_a_full_pack_turns_the_reward_into_a_potion() -> void:
	var tower := Gen2BattleTower.new()
	tower.reward = Gen2BattleTower.MIN_REWARD
	assert_eq(tower.reward_for({1: 1}), Gen2BattleTower.MIN_REWARD)
	var full: Dictionary = {}
	for item: int in Gen2WorldPack.MAX_ITEMS:
		full[item + 1] = 1
	assert_eq(tower.reward_for(full), Gen2BattleTower.REWARD_FULL_PACK)
	full.erase(1)
	full[Gen2BattleTower.MIN_REWARD] = 94
	assert_eq(tower.reward_for(full), Gen2BattleTower.MIN_REWARD)
	full[Gen2BattleTower.MIN_REWARD] = 95
	assert_eq(tower.reward_for(full), Gen2BattleTower.REWARD_FULL_PACK)


## LUCKY_PUNCH sits inside `BATTLETOWER_MIN_REWARD`..`BATTLETOWER_MAX_REWARD`
## without being a reward, so the roll that lands on it is drawn again.
func test_the_reward_is_a_stat_booster_and_never_the_lucky_punch() -> void:
	var tower := Gen2BattleTower.new()
	var seen: Dictionary = {}
	for seed_value: int in 200:
		var random := RandomNumberGenerator.new()
		random.seed = seed_value
		var item: int = tower.choose_reward(random)
		assert_between(item, Gen2BattleTower.MIN_REWARD, Gen2BattleTower.MAX_REWARD)
		assert_ne(item, Gen2BattleTower.LUCKY_PUNCH)
		seen[item] = true
	assert_eq(seen.size(), Gen2BattleTower.MAX_REWARD - Gen2BattleTower.MIN_REWARD)


## `BattleEnd_HandleRoamMons`: a roamer that was run from keeps the HP and the
## DVs the fight left it on, and one that was caught or defeated is emptied so
## `CheckEncounterRoamMon` can never select the slot again.
func test_a_roamer_keeps_its_hp_and_dvs_between_encounters() -> void:
	var state := Gen2WorldState.new()
	state.ensure_roaming_mons(
		[{"species": 243, "level": 40, "map_group": 1, "map_number": 1}]
	)
	assert_true(state.note_roam_battle_end(243, false, 37, 0xABCD))
	var restored: Gen2WorldState = Gen2WorldState.from_dict(state.to_dict())
	var kept: Dictionary = restored.roaming_mons()[0]
	assert_eq(int(kept["hp"]), 37)
	assert_eq(int(kept["dvs"]), 0xABCD)

	assert_true(restored.note_roam_battle_end(243, true, 0, 0xABCD))
	var emptied: Dictionary = restored.roaming_mons()[0]
	assert_eq(int(emptied["species"]), 0)
	assert_eq(int(emptied["hp"]), 0)
	assert_eq(int(emptied["map_group"]), Gen2WorldState.ROAM_MAP_N_A)
	assert_eq(
		restored.roaming_mons_on(1, 1).size(), 0,
		"an emptied slot is on no map"
	)


## `UpdateRoamMons` skips a struct whose map group is GROUP_N_A, so a beaten
## roamer is never walked back onto the map.
func test_a_beaten_roamer_is_not_walked() -> void:
	var state := Gen2WorldState.new()
	state.ensure_roaming_mons(
		[{"species": 243, "level": 40, "map_group": 1, "map_number": 1}]
	)
	state.note_roam_battle_end(243, true, 0, 0)
	var rows: Array = [{
		"map_group": 1, "map_number": 1,
		"connections": [{"map_group": 1, "map_number": 2}],
	}]
	var generator := RandomNumberGenerator.new()
	generator.seed = 7
	assert_eq(state.advance_roaming(rows, generator), [])
	assert_eq(int(state.roaming_mons()[0]["map_group"]), Gen2WorldState.ROAM_MAP_N_A)


## `wStatusFlags`' flash bit is saved player data, so a cave lit before a save is
## still lit when the slot is opened again.
func test_flash_survives_a_snapshot() -> void:
	var state := Gen2WorldState.new()
	state.set_used_flash(true)
	assert_true(Gen2WorldState.from_dict(state.to_dict()).used_flash())
	var without: Dictionary = state.to_dict()
	without.erase("used_flash")
	assert_false(Gen2WorldState.from_dict(without).used_flash())


## `DoBikeStep`: the counter is saved, the call is queued the first counted step
## past 1024, and the counter saturates rather than wrapping.
func test_the_bike_shop_call_is_queued_after_1024_saved_steps() -> void:
	var state := Gen2WorldState.new()
	for _step: int in Gen2WorldState.BIKE_SHOP_CALL_STEPS - 1:
		assert_false(state.do_bike_step(true, true))
	assert_eq(state.bike_step(), Gen2WorldState.BIKE_SHOP_CALL_STEPS - 1)

	var reopened: Gen2WorldState = Gen2WorldState.from_dict(state.to_dict())
	assert_eq(reopened.bike_step(), Gen2WorldState.BIKE_SHOP_CALL_STEPS - 1)
	assert_false(
		reopened.do_bike_step(false, true), "a step off the bike counts nothing"
	)
	assert_false(
		reopened.do_bike_step(true, false), "a map with no service counts nothing"
	)
	assert_true(reopened.do_bike_step(true, true))
	assert_eq(reopened.pending_special_phone_call(), Gen2WorldState.SPECIALCALL_BIKESHOP)
	assert_false(
		reopened.do_bike_step(true, true), "a queued call is not overwritten"
	)


## The first Unown a save meets is what every Pokedex entry for UNOWN is drawn
## as, whether it was caught or only seen, and it is written once.
func test_the_first_unown_seen_is_kept_and_written_once() -> void:
	var state := Gen2WorldState.new()
	state.note_first_unown_seen(9)
	state.update_unown_dex(3)
	assert_eq(state.first_unown_seen(), 9)
	assert_eq(state.unown_dex(), [3] as Array[int])
	assert_eq(Gen2WorldState.from_dict(state.to_dict()).first_unown_seen(), 9)

	## A state written before the byte was kept falls back to the first form
	## caught rather than to form A.
	var without: Dictionary = state.to_dict()
	without.erase("first_unown_seen")
	assert_eq(Gen2WorldState.from_dict(without).first_unown_seen(), 3)
