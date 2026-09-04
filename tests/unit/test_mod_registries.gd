extends GutTest

## The three registries a mod reaches that are not a renderer: move effects,
## effect commands and the read-only event channel. Each is checked for what it
## lets a mod add and for what it refuses to let one take over.

const Fixture := preload("res://tests/unit/battle_fixture.gd")
const MOD: StringName = &"testmod"
## An effect byte no cartridge move carries, so registering it cannot change a
## move already in the table.
const NEW_EFFECT: int = 0xF0

var _directory: String = ""
var _data: GameData = null
var _ran: Array = []
var _seen: Array = []


func before_each() -> void:
	Gen2ModHost.reset()
	_directory = RomCache.directory_for(&"registrytest", "0123456789abcdef")
	_data = Fixture.build(_directory)
	_ran = []
	_seen = []


func after_each() -> void:
	RomCache.clear(_directory)
	Gen2ModHost.reset()


func _note(turn: Gen2Turn) -> void:
	_ran.append(turn.move_number)


func _watch(queued_event: Dictionary) -> void:
	_seen.append(queued_event)


func test_a_registered_command_runs_inside_a_real_move_sequence() -> void:
	var host: Gen2ModHost = Gen2ModHost.instance()
	assert_true(bool(host.register_effect_command(MOD, &"marker", _note).get("ok", false)))
	assert_true(bool(host.register_move_effect(MOD, NEW_EFFECT, [
		Gen2EffectCommands.USED_MOVE_TEXT,
		Gen2EffectCommands.DO_TURN,
		&"marker",
		Gen2EffectCommands.END_MOVE,
	]).get("ok", false)))

	assert_eq(Gen2MoveEffect.sequence_for(NEW_EFFECT).size(), 4)
	assert_true(Gen2MoveEffect.is_written(NEW_EFFECT))

	var battle: Gen2Battle = Gen2Battle.create(
		_data,
		Gen2BattleMon.create(_data, Fixture.PIKACHU, 50, [Fixture.TACKLE]),
		Gen2BattleMon.create(_data, Fixture.GEODUDE, 50, [Fixture.TACKLE]),
		RandomNumberGenerator.new()
	)
	var turn: Gen2Turn = Gen2Turn.create(
		battle, Gen2Battle.PLAYER, 0, Fixture.TACKLE, _data.move(Fixture.TACKLE), []
	)
	for command: StringName in Gen2MoveEffect.sequence_for(NEW_EFFECT):
		Gen2EffectCommands.run(command, turn)
	assert_eq(_ran, [Fixture.TACKLE], "the registered step ran with the turn")


func test_a_registration_cannot_shadow_a_step_every_move_depends_on() -> void:
	var host: Gen2ModHost = Gen2ModHost.instance()
	assert_eq(
		StringName(host.register_effect_command(
			MOD, Gen2EffectCommands.APPLY_DAMAGE, _note
		)["reason"]),
		&"reserved_effect_command"
	)
	# And the stat commands are engine steps too, not just the shared ones.
	assert_eq(
		StringName(host.register_effect_command(
			MOD, Gen2EffectCommands.ATTACK_UP, _note
		)["reason"]),
		&"reserved_effect_command"
	)


func test_an_effect_naming_a_step_nobody_wrote_is_refused_at_registration() -> void:
	# Refused here, where the mod's id is in hand, rather than pushing an error
	# in the middle of a turn.
	var result: Dictionary = Gen2ModHost.instance().register_move_effect(MOD, NEW_EFFECT, [
		Gen2EffectCommands.USED_MOVE_TEXT, &"nosuchstep",
	])
	assert_eq(StringName(result["reason"]), &"unknown_effect_command")
	assert_false(Gen2MoveEffect.is_written(NEW_EFFECT))


func test_effects_whose_command_reads_the_byte_back_are_not_replaceable() -> void:
	for effect: int in Gen2MoveEffect.RESERVED_EFFECTS:
		assert_eq(
			StringName(Gen2ModHost.instance().register_move_effect(
				MOD, effect, [Gen2EffectCommands.END_MOVE]
			)["reason"]),
			&"reserved_effect", "effect %d" % effect
		)


func test_a_registered_effect_replaces_the_cartridge_list_and_reset_restores_it() -> void:
	var before: Array = Gen2MoveEffect.sequence_for(Gen2MoveEffect.SLEEP)
	assert_true(bool(Gen2ModHost.instance().register_move_effect(
		MOD, Gen2MoveEffect.SLEEP, [Gen2EffectCommands.END_MOVE]
	).get("ok", false)))
	assert_eq(Gen2MoveEffect.sequence_for(Gen2MoveEffect.SLEEP).size(), 1)
	Gen2ModHost.reset()
	assert_eq(Gen2MoveEffect.sequence_for(Gen2MoveEffect.SLEEP), before)


func test_two_mods_claiming_one_effect_is_refused() -> void:
	var host: Gen2ModHost = Gen2ModHost.instance()
	host.register_move_effect(MOD, NEW_EFFECT, [Gen2EffectCommands.END_MOVE])
	assert_eq(
		StringName(host.register_move_effect(
			&"othermod", NEW_EFFECT, [Gen2EffectCommands.END_MOVE]
		)["reason"]),
		&"duplicate_move_effect"
	)


func test_a_subscriber_sees_published_events_and_cannot_write_through_them() -> void:
	var host: Gen2ModHost = Gen2ModHost.instance()
	assert_true(bool(host.subscribe(Gen2ModHost.CHANNEL_BATTLE, MOD, _watch).get("ok", false)))
	var queued_event: Dictionary = {"type": Gen2Battle.HIT, "damage": 12}
	Gen2ModHost.publish(Gen2ModHost.CHANNEL_BATTLE, queued_event)
	assert_eq(_seen.size(), 1)
	assert_eq(int(_seen[0]["damage"]), 12)
	# The subscriber holds a copy, so writing to it reaches nothing.
	(_seen[0] as Dictionary)["damage"] = 999
	assert_eq(int(queued_event["damage"]), 12)
	# And the other channel is a different conversation.
	Gen2ModHost.publish(Gen2ModHost.CHANNEL_WORLD, {"status": &"waiting"})
	assert_eq(_seen.size(), 1)


## Mutation is the other half of the event channel: the turn or the script has
## already committed, so what reaches the screen is presentation and may be
## rewritten, while the key the screen dispatches on may not.
func test_an_event_mutator_rewrites_presentation_and_not_the_routing_key() -> void:
	var host: Gen2ModHost = Gen2ModHost.instance()
	assert_true(bool(host.register_event_mutator(
		Gen2ModHost.CHANNEL_BATTLE, MOD,
		func(queued_event: Dictionary) -> Dictionary:
			queued_event["damage"] = 1
			return queued_event
	).get("ok", false)))
	assert_true(bool(host.subscribe(Gen2ModHost.CHANNEL_BATTLE, MOD, _watch).get("ok", false)))

	var effective: Dictionary = Gen2ModHost.publish(
		Gen2ModHost.CHANNEL_BATTLE, {"type": Gen2Battle.HIT, "damage": 12}
	)
	assert_eq(int(effective["damage"]), 1, "the screen shows what the mutator returned")
	assert_eq(int(_seen[0]["damage"]), 1, "and a watcher sees the same event")

	host.unregister_event_mutator(Gen2ModHost.CHANNEL_BATTLE, MOD)
	assert_eq(
		int(Gen2ModHost.publish(
			Gen2ModHost.CHANNEL_BATTLE, {"type": Gen2Battle.HIT, "damage": 12}
		)["damage"]),
		12
	)


func test_a_mutator_that_changes_the_key_or_answers_with_nothing_is_ignored() -> void:
	var host: Gen2ModHost = Gen2ModHost.instance()
	host.register_event_mutator(
		Gen2ModHost.CHANNEL_BATTLE, MOD,
		func(mutated: Dictionary) -> Dictionary:
			mutated["type"] = Gen2Battle.ANIMATION
			return mutated
	)
	var queued_event: Dictionary = {"type": Gen2Battle.HIT, "damage": 12}
	assert_eq(
		StringName(Gen2ModHost.publish(Gen2ModHost.CHANNEL_BATTLE, queued_event)["type"]),
		StringName(Gen2Battle.HIT),
		"a rewrite cannot turn one screen operation into another"
	)

	host.unregister_event_mutator(Gen2ModHost.CHANNEL_BATTLE, MOD)
	host.register_event_mutator(
		Gen2ModHost.CHANNEL_WORLD, MOD, func(_event: Dictionary) -> Variant: return null
	)
	assert_eq(
		Gen2ModHost.publish(Gen2ModHost.CHANNEL_WORLD, {"status": &"waiting"}),
		{"status": &"waiting"},
		"and a mutator answering with nothing leaves the queued_event alone"
	)


## Exclusive, because composing two rewrites in load order would make the picture
## depend on which mod happened to load first.
func test_only_one_mod_may_mutate_a_channel() -> void:
	var host: Gen2ModHost = Gen2ModHost.instance()
	assert_true(bool(host.register_event_mutator(
		Gen2ModHost.CHANNEL_WORLD, MOD, _watch
	).get("ok", false)))
	var second: Dictionary = host.register_event_mutator(
		Gen2ModHost.CHANNEL_WORLD, &"othermod", _watch
	)
	assert_eq(StringName(second["reason"]), &"duplicate_event_mutator")
	assert_string_contains(String(second["detail"]), "othermod")
	assert_eq(
		StringName(host.register_event_mutator(&"nowhere", MOD, _watch)["reason"]),
		&"unknown_channel"
	)
	assert_eq(
		StringName(host.register_event_mutator(
			Gen2ModHost.CHANNEL_BATTLE, MOD, Callable()
		)["reason"]),
		&"invalid_event_mutator_handler"
	)
	# Another mod's id cannot release it either.
	host.unregister_event_mutator(Gen2ModHost.CHANNEL_WORLD, &"othermod")
	assert_eq(
		StringName(host.register_event_mutator(
			Gen2ModHost.CHANNEL_WORLD, &"othermod", _watch
		)["reason"]),
		&"duplicate_event_mutator"
	)


func test_unsubscribing_and_unknown_channels() -> void:
	var host: Gen2ModHost = Gen2ModHost.instance()
	assert_eq(
		StringName(host.subscribe(&"nowhere", MOD, _watch)["reason"]), &"unknown_channel"
	)
	assert_eq(
		StringName(host.subscribe(
			Gen2ModHost.CHANNEL_WORLD, MOD, Callable()
		)["reason"]),
		&"invalid_subscriber_handler"
	)
	host.subscribe(Gen2ModHost.CHANNEL_WORLD, MOD, _watch)
	assert_eq(
		StringName(host.subscribe(Gen2ModHost.CHANNEL_WORLD, MOD, _watch)["reason"]),
		&"duplicate_subscriber"
	)
	host.unsubscribe(Gen2ModHost.CHANNEL_WORLD, MOD)
	Gen2ModHost.publish(Gen2ModHost.CHANNEL_WORLD, {"status": &"waiting"})
	assert_eq(_seen.size(), 0)


func test_publishing_with_no_host_built_does_nothing() -> void:
	# The publish call sits on the path every battle event takes, so a game with
	# no mods must not build a host to publish to nobody.
	Gen2ModHost.reset()
	Gen2ModHost.publish(Gen2ModHost.CHANNEL_BATTLE, {"type": Gen2Battle.HIT})
	assert_eq(_seen.size(), 0)


func test_two_mods_claiming_one_renderer_id_is_named_rather_than_silently_won() -> void:
	var host: Gen2ModHost = Gen2ModHost.instance()
	assert_eq(
		StringName(host.register_world_renderer(
			Gen2ModHost.BUILT_IN_RENDERER, Gen2WorldRenderer
		)["reason"]),
		&"duplicate_renderer"
	)
	assert_eq(
		StringName(host.register_battle_renderer(
			Gen2ModHost.BUILT_IN_RENDERER, Gen2BattleRenderer
		)["reason"]),
		&"duplicate_renderer"
	)


func test_the_shipped_example_mod_registers_everything_it_documents() -> void:
	# mods/examples/new_content/ is the reference a mod author copies, so it is
	# run here rather than only read: a registration it gets wrong would be
	# refused silently and the example would teach the refusal.
	var manifest: Dictionary = PokeModManifest.read("res://mods/examples/new_content")
	assert_true(bool(manifest.get("ok", false)), "example manifest reads")
	var host: Gen2ModHost = Gen2ModHost.instance()
	## Discovered rather than only read: a save-bound registration takes the
	## manifest object THIS host discovered as the capability, so a copy with the
	## same id grants nothing.
	host.discover("res://mods/examples")
	var discovered: PokeModManifest = null
	for candidate: PokeModManifest in host.manifests():
		if candidate.id == &"new_content":
			discovered = candidate
	assert_not_null(discovered)
	assert_true(bool(host.load_mod(discovered).get("ok", false)))

	var overlay: Gen2ContentOverlay = host.content_overlay()
	assert_false(overlay.is_empty())
	assert_eq(
		overlay.defined_numbers(Gen2ContentOverlay.KIND_SPECIES),
		[Gen2ContentOverlay.FIRST_MOD_NUMBER] as Array[int]
	)
	# Its move names an effect it registered itself, so the effect resolves to
	# the list rather than falling back to an ordinary attack.
	var move: Dictionary = overlay.resolve(
		Gen2ContentOverlay.KIND_MOVE, Gen2ContentOverlay.FIRST_MOD_NUMBER, {}
	)
	assert_true(Gen2MoveEffect.is_written(int(move["effect"])))
	assert_true(Gen2MoveEffect.sequence_for(int(move["effect"])).has(
		Gen2EffectCommands.RECOIL
	))
	# 8: its stats page is registered and builds off the snapshot's own DV word.
	var pages: Array = host.stats_pages()
	assert_eq(pages.size(), 1)
	var placements: Array = (pages[0]["build"] as Callable).call(
		{"dvs": Gen2Stats.pack_dvs(15, 9, 7, 12), "stat_exp": {"attack": 25600}}
	)
	assert_true(placements.has({"text": "15", "at": Vector2i(8, 11)}), "the ATTACK DV")
	assert_true(placements.has({"text": "25600", "at": Vector2i(14, 11)}), "its stat exp")

	# And its patch reaches a cartridge row without replacing the rest of it.
	var pikachu: Dictionary = overlay.resolve(
		Gen2ContentOverlay.KIND_SPECIES, 25,
		{"name": "PIKACHU", "stats": {"hp": 35, "speed": 90}}
	)
	assert_eq(int(pikachu["stats"]["speed"]), 110)
	assert_eq(int(pikachu["stats"]["hp"]), 35)
	assert_eq(String(pikachu["name"]), "PIKACHU")

	# The example is the documentation for the whole contract, so it declares the
	# current one and demonstrates each surface a version added. A host bump with
	# the example left behind fails here rather than in a mod author's reading.
	for id: String in ["new_content", "voxel_preview"]:
		var declared: Dictionary = PokeModManifest.read("res://mods/examples/%s" % id)
		assert_true(bool(declared.get("ok", false)), id)
		assert_eq(
			(declared["manifest"] as PokeModManifest).api_version,
			PokeModManifest.API_VERSION,
			id
		)
	# 9: its item names the evolution using it causes, as a field rather than a
	# callback, so the host owns the transaction the evolution runs inside.
	assert_eq(
		int(overlay.resolve(
			Gen2ContentOverlay.KIND_ITEM, Gen2ContentOverlay.FIRST_MOD_NUMBER, {}
		)["evolution"]["method"]),
		Gen2Layout.EVOLVE_TRADE
	)
	# 4: a type of its own, and a chart exception naming it.
	assert_eq(
		overlay.defined_numbers(Gen2ContentOverlay.KIND_TYPE),
		[Gen2ContentOverlay.FIRST_MOD_NUMBER] as Array[int]
	)
	assert_eq(int(overlay.resolve(
		Gen2ContentOverlay.KIND_MATCHUP,
		Gen2ContentOverlay.matchup_number(
			Gen2ContentOverlay.FIRST_MOD_NUMBER, Gen2Layout.TYPE_STEEL
		),
		{"multiplier": Gen2Layout.MATCHUP_EFFECTIVE}
	).get("multiplier", 0)), Gen2Layout.MATCHUP_SUPER_EFFECTIVE)
	# 4: decoded art, which is exactly tiles * tiles * 64 indices or it is dropped.
	var voltling: Dictionary = overlay.resolve(
		Gen2ContentOverlay.KIND_SPECIES, Gen2ContentOverlay.FIRST_MOD_NUMBER, {}
	)
	var front: Dictionary = (voltling["pics"] as Dictionary)["front"]
	assert_eq((front["indices"] as PackedByteArray).size(), 7 * 7 * 64)
	# 3: an item in a mod pocket, and the mart shelf it is sold from.
	assert_eq(
		int(overlay.resolve(
			Gen2ContentOverlay.KIND_ITEM, Gen2ContentOverlay.FIRST_MOD_NUMBER, {}
		)["pocket"]),
		Gen2ModHost.FIRST_MOD_POCKET
	)
	var shelf: Array = host.mart_entries({"mart_id": 0, "variant": 0, "items": []})
	assert_eq(shelf.size(), 1)
	assert_eq(int((shelf[0] as Dictionary)["item"]), Gen2ContentOverlay.FIRST_MOD_NUMBER)
	assert_eq(int((shelf[0] as Dictionary)["price"]), 400)
	# 3: a named axis, whose two halves both registered rather than colliding
	# with the cartridge's eight.
	assert_eq(host.actions().size(), 2)
	# 2: a visible-encounter population, and 15: its own glow, which is a field
	# on the entry rather than anything the mod draws.
	assert_eq(host.visible_encounter_ids().size(), 1)
	var population: Object = host.visible_encounter_providers()[0]
	population.call("set_context", {
		"generation": 1, "run_seed": 1,
		"eligible": {"grass": PackedVector2Array([Vector2(4, 4)])},
		"tables": {"grass": {"slots": [
			{"species": 25, "min_level": 3, "max_level": 3},
		]}},
	})
	population.call("advance_frame")
	var wanderers: Array = population.call("encounters")
	assert_eq(wanderers.size(), 1)
	assert_gt(float((wanderers[0] as Dictionary)["glow"]["amount"]), 0.0)
	# 13: the five read-only policies that change how the game is played.
	assert_eq(host.field_move_source_ids().size(), 1)
	assert_eq(host.repel_renewal_ids().size(), 1)
	assert_eq(host.catch_experience_ids().size(), 1)
	assert_eq(host.battle_info_ids().size(), 1)
	assert_true(Gen2ModHost.allows_item_field_move(Gen2WorldFieldMove.MOVE_FLY))
	assert_true(Gen2ModHost.awards_catch_experience())
	assert_eq(host.repel_renewal_item({0x2B: 1}), 0x2B, "the only one owned")
	## 16: how many DV words one wild is drawn with, and the bag the provider
	## reads the charm out of. No world is open here, so the bag is empty and the
	## example answers the cartridge's own single roll.
	assert_eq(host.shiny_rolls_ids().size(), 1)
	assert_eq(host.inventory(), {}, "no world open")
	assert_eq(Gen2ModHost.shiny_roll_count({"species": 25}), 1, "the charm is not held")
	host.set_inventory_source(Callable(self, "_charmed_bag"))
	assert_eq(host.inventory(), {0x19: 1})
	assert_eq(Gen2ModHost.shiny_roll_count({"species": 25}), 3, "held")
	host.set_inventory_source(Callable())
	## 16: an item gift, queued rather than answered the way a hidden item's ask
	## is, and drained in order.
	host.request_item_gift(0x19, 2)
	host.request_item_gift(0x14)
	host.request_item_gift(0, 1)
	var gifts: Array[Dictionary] = host.take_item_gift_requests()
	assert_eq(gifts, [{"item": 0x19, "quantity": 2}, {"item": 0x14, "quantity": 1}])
	assert_eq(host.take_item_gift_requests(), [], "the drain empties the queue")
	host.request_item_gift(0x2B)
	host.requeue_item_gifts(gifts)
	var order: Array = []
	for gift: Dictionary in host.take_item_gift_requests():
		order.append(int(gift["item"]))
	assert_eq(order, [0x19, 0x14, 0x2B], "what could not be spent goes back in front")
	## A start-menu row naming a host action, gated on the host's own party test
	## after the mod's predicate. The BADGES row has no party gate, so an empty
	## party leaves the PC row alone.
	var empty: Array = host.start_menu_entries({"party_count": 0})
	assert_eq(empty.size(), 1)
	assert_eq(
		StringName((empty[0] as Dictionary)["action"]),
		Gen2ModHost.START_ACTION_OPEN_MOD_PAGE
	)
	var rows: Array = host.start_menu_entries({"party_count": 1})
	assert_eq(rows.size(), 2)
	assert_eq(
		StringName((rows[0] as Dictionary)["action"]),
		Gen2ModHost.START_ACTION_OPEN_BILLS_PC
	)
	## The example's own page, and the eight rows it lists with no badges won.
	assert_eq(host.page_ids(), [&"new_content"])
	var listed: Array = host.page_rows(&"new_content")
	assert_eq(listed.size(), 8)
	assert_true(bool((listed[0] as Dictionary)["locked"]))
	## An annotation placed where the grid can hold it, said in the interface's
	## own coordinates.
	var drawn: Array = host.battle_info_placements({
		"menu_stage": "move", "enemy_seen_before": true, "neutral": 10,
		"weather": Gen2Weather.SUN, "player_stages": {"attack": 2}, "enemy_stages": {},
		"move_rows": [{"effectiveness": 20}, {"effectiveness": 10}],
		## Where the host says the rows are, which is what a provider annotating
		## them reads instead of writing the menu's coordinates down.
		"move_rows_at": Vector2i(5, 13), "move_rows_step": Vector2i(0, 1),
		"move_rows_right": 18,
	})
	assert_eq(drawn.size(), 3, "one mark, one stage line and the weather tile")
	assert_eq((drawn[0] as Dictionary)["at"], Vector2i(18, 13))
	assert_true((drawn[0] as Dictionary).has("tile"), "the mark is a tile of the mod's own")
	assert_eq(String((drawn[1] as Dictionary)["text"]), "ATK2")
	assert_true((drawn.back() as Dictionary).has("tile"))

	# 4: one presentation mutator, which may not change the routing key.
	var dressed: Dictionary = Gen2ModHost.publish(Gen2ModHost.CHANNEL_WORLD, {
		"status": &"waiting", "event": {"type": &"text", "text": "PIKACHU!"},
	})
	assert_eq(StringName(dressed["status"]), &"waiting")
	assert_eq(String((dressed["event"] as Dictionary)["text"]), "VOLTLING!")


func test_every_refusal_reason_the_mod_layer_produces_has_player_wording() -> void:
	# The launcher and the index dialog share one table now; a reason worded in
	# neither used to show as a raw StringName through whichever screen met it.
	for reason: StringName in [
		&"not_a_zip", &"unsafe_archive_entry", &"unsupported_api_version",
		&"unsupported_index_schema", &"already_installed", &"duplicate_renderer",
		&"duplicate_content", &"reserved_effect_command", &"missing_entry_script",
		&"duplicate_party_menu_entry", &"party_menu_entry_missing_callable",
		&"invalid_party_menu_entry", &"duplicate_stats_page",
		&"stats_page_missing_callable", &"stats_pages_full",
		&"battle_info_cells_taken", &"battle_info_placement_refused",
		&"invalid_mod_page", &"mod_page_missing_callable", &"duplicate_mod_page",
		&"empty_notice", &"notice_line_too_long", &"unknown_notice_sound",
		&"invalid_notice_icon", &"notice_queue_full",
	]:
		var text: String = PokeModRefusal.text({"reason": reason, "detail": "x/y.zip"})
		assert_false(text.begins_with(String(reason)), "worded: %s" % reason)
		assert_false(text.is_empty())
	# An unworded reason still names something a search finds.
	assert_string_contains(PokeModRefusal.text({"reason": &"brand_new"}), "brand_new")


## `register_stats_page` refuses what it cannot draw, and refuses a sixth page:
## the indicator run is centred against the right arrow and one more block than
## [constant Gen2StatsScreenPage.MAX_PAGES] stands on the front pic.
func test_the_stats_screen_refuses_a_page_it_cannot_draw_or_indicate() -> void:
	var host: Gen2ModHost = Gen2ModHost.instance()
	var build := func(_page: Dictionary) -> Array: return []
	assert_eq(
		StringName(host.register_stats_page(&"", {"build": build})["reason"]),
		&"invalid_stats_page"
	)
	assert_eq(
		StringName(host.register_stats_page(MOD, {})["reason"]),
		&"stats_page_missing_callable"
	)
	assert_true(bool(host.register_stats_page(MOD, {"build": build})["ok"]))
	assert_eq(
		StringName(host.register_stats_page(MOD, {"build": build})["reason"]),
		&"duplicate_stats_page"
	)
	var room: int = Gen2StatsScreenPage.MAX_PAGES - Gen2StatsScreenPage.NUM_PAGES - 1
	for index: int in room:
		assert_true(bool(host.register_stats_page(
			StringName("filler%d" % index), {"build": build}
		)["ok"]))
	assert_eq(
		StringName(host.register_stats_page(&"toomany", {"build": build})["reason"]),
		&"stats_pages_full"
	)
	assert_eq(Gen2StatsScreenPage.page_count(), Gen2StatsScreenPage.MAX_PAGES)


## The eight steps the last row of the effects table added are engine steps like
## every other: a mod can name them in a list of its own and cannot take them over.
func test_the_last_rows_steps_are_engine_steps_a_mod_can_name() -> void:
	var host: Gen2ModHost = Gen2ModHost.instance()
	var steps: Array = [
		Gen2EffectCommands.TELEPORT, Gen2EffectCommands.FORESIGHT,
		Gen2EffectCommands.LOCK_ON, Gen2EffectCommands.SPITE,
		Gen2EffectCommands.PAIN_SPLIT, Gen2EffectCommands.THIEF,
		Gen2EffectCommands.PURSUIT, Gen2EffectCommands.BEAT_UP,
	]
	for step: StringName in steps:
		assert_true(Gen2EffectCommands.is_engine_command(step), String(step))
		assert_eq(
			StringName(host.register_effect_command(MOD, step, _note)["reason"]),
			&"reserved_effect_command", String(step)
		)

	var result: Dictionary = host.register_move_effect(MOD, NEW_EFFECT, [
		Gen2EffectCommands.USED_MOVE_TEXT, Gen2EffectCommands.DO_TURN,
		Gen2EffectCommands.CHECK_HIT, Gen2EffectCommands.LOCK_ON,
		Gen2EffectCommands.END_MOVE,
	])
	assert_true(bool(result["ok"]), JSON.stringify(result))
	assert_true(Gen2MoveEffect.is_written(NEW_EFFECT))


## None of the eight reads its own effect byte back, so none of them joins the
## list a mod cannot rewrite.
func test_the_last_rows_effects_stay_replaceable() -> void:
	for effect: int in [
		Gen2MoveEffect.PAIN_SPLIT, Gen2MoveEffect.LOCK_ON, Gen2MoveEffect.SPITE,
		Gen2MoveEffect.THIEF, Gen2MoveEffect.FORESIGHT, Gen2MoveEffect.PURSUIT,
		Gen2MoveEffect.TELEPORT, Gen2MoveEffect.BEAT_UP,
	]:
		assert_true(bool(Gen2ModHost.instance().register_move_effect(
			MOD, effect, [Gen2EffectCommands.END_MOVE]
		)["ok"]), "effect %d" % effect)


## The bag [method Gen2ModHost.inventory] reads while the test stands in for an
## open world: the example mod's charm, and nothing else.
func _charmed_bag() -> Dictionary:
	return {0x19: 1}


## `battle_info_placements` refuses a placement the 20x18 grid cannot hold, and
## says so: a provider whose column grows by a row per active stat stage runs off
## the bottom only when several are up at once, and a row quietly missing is what
## a player sees. Once per distinct refusal, because this runs every frame off a
## snapshot a provider is a pure function of.
class _OffGrid:
	extends RefCounted

	var placements: Array = []

	func annotate_battle(_snapshot: Dictionary) -> Array:
		return placements


func test_a_battle_annotation_the_grid_refuses_is_reported_once() -> void:
	var host: Gen2ModHost = Gen2ModHost.instance()
	var provider := _OffGrid.new()
	provider.placements = [
		{"at": Vector2i(0, Gen2BattleAnnotations.ROWS), "text": "ATK2"},
		{"at": Vector2i(0, 0), "text": "OK"},
	]
	assert_true(bool(host.register_battle_info(MOD, provider)["ok"]))
	var before: int = host.failures().size()
	var drawn: Array = host.battle_info_placements({})
	assert_eq(drawn.size(), 1, "the placement that fits is still drawn")
	var failures: Array = host.failures()
	assert_eq(failures.size(), before + 1)
	var refusal: Dictionary = failures.back()
	assert_eq(StringName(refusal["reason"]), &"battle_info_placement_refused")
	assert_eq(StringName(refusal["id"]), MOD)
	assert_string_contains(String(refusal["detail"]), "off_grid")
	## The next frame is the same snapshot and the same answer, and says nothing.
	host.battle_info_placements({})
	host.battle_info_placements({})
	assert_eq(host.failures().size(), before + 1, "one entry, not one a frame")


## `request_hidden_item` collapses an ask for a cell already queued and one whose
## own event flag is already set, so a provider may ask from its own read of
## `hidden_items()` every frame without keeping a private set of what it has
## named. A cell left clear by the pack-full branch stays askable.
func test_a_hidden_item_ask_collapses_on_the_queue_and_on_the_flag() -> void:
	var host: Gen2ModHost = Gen2ModHost.instance()
	host.set_hidden_items_source(Callable(self, "_hidden_item_rows"))
	for _frame: int in 60:
		host.request_hidden_item(Vector2i(3, 4))
		host.request_hidden_item(Vector2i(9, 9))
	assert_eq(
		host.take_hidden_item_requests(), [Vector2i(3, 4)] as Array[Vector2i],
		"the taken cell is dropped and the other queued once"
	)
	## What a drain could not spend goes back without doubling a cell the mod
	## asked for again on the frame the queue was empty.
	host.request_hidden_item(Vector2i(3, 4))
	host.requeue_hidden_items([Vector2i(3, 4)] as Array[Vector2i])
	assert_eq(host.take_hidden_item_requests(), [Vector2i(3, 4)] as Array[Vector2i])


## Two charms are worth what each adds past the cartridge's own roll, not the
## larger of the two: the Let's Go number for a Shiny Charm carried at a full
## Catch Combo is 14 and not 12.
func test_shiny_roll_providers_compose_additively() -> void:
	var host: Gen2ModHost = Gen2ModHost.instance()
	assert_true(bool(host.register_shiny_rolls(&"charm", _Rolls.new(3))["ok"]))
	assert_eq(Gen2ModHost.shiny_roll_count({"species": 25}), 3, "one alone is unchanged")
	assert_true(bool(host.register_shiny_rolls(&"combo", _Rolls.new(12))["ok"]))
	assert_eq(Gen2ModHost.shiny_roll_count({"species": 25}), 14)
	## 0 and 1 both mean the cartridge's own roll, so neither adds anything.
	assert_true(bool(host.register_shiny_rolls(&"quiet", _Rolls.new(0))["ok"]))
	assert_eq(Gen2ModHost.shiny_roll_count({"species": 25}), 14, "0 adds nothing")


## The line a mod asks the battle to print: queued in order, one line wide, and
## dropped rather than held where no battle is up.
func test_a_battle_message_is_queued_measured_and_dropped() -> void:
	var host: Gen2ModHost = Gen2ModHost.instance()
	var refused: Dictionary = host.request_battle_message(MOD, "Catch Combo 2!")
	assert_eq(StringName(refused["reason"]), &"no_battle_showing_messages")
	assert_eq(host.take_battle_message(), {}, "nothing was queued")

	host.set_battle_messages_open(true)
	assert_true(bool(host.request_battle_message(MOD, "Catch Combo 2!")["ok"]))
	assert_true(bool(host.request_battle_message(MOD, "Catch Combo 3!")["ok"]))
	assert_eq(host.request_battle_message(MOD, "   ")["reason"], &"empty_battle_message")

	## 18 tiles is one line of a standard box, and a nineteenth is refused by
	## name rather than clipped.
	var before: int = host.failures().size()
	var wide: Dictionary = host.request_battle_message(MOD, "1234567890123456789")
	assert_eq(StringName(wide["reason"]), &"battle_message_too_long")
	assert_true(bool(host.request_battle_message(MOD, "123456789012345678")["ok"]), "18 fits")
	var two_lines: Dictionary = host.request_battle_message(MOD, "one\ntwo")
	assert_eq(StringName(two_lines["reason"]), &"battle_message_too_long")
	assert_eq(host.failures().size(), before + 2, "both refusals reach the launcher")
	assert_eq(StringName((host.failures().back() as Dictionary)["id"]), MOD)

	assert_eq(String(host.take_battle_message()["text"]), "Catch Combo 2!")
	assert_eq(String(host.take_battle_message()["text"]), "Catch Combo 3!")
	## The battle went away with a line still queued, and it goes with it.
	host.set_battle_messages_open(false)
	assert_eq(host.take_battle_message(), {})


## Answers one total whatever it is asked, the way a charm does.
class _Rolls:
	var _rolls: int = 1

	func _init(rolls: int) -> void:
		_rolls = rolls

	func shiny_rolls(_context: Dictionary) -> int:
		return _rolls


## `(9, 9)` has been picked up; `(3, 4)` has not, which is also what the
## pack-full branch leaves behind.
func _hidden_item_rows() -> Array:
	return [
		{"cell": Vector2i(3, 4), "item": 1, "flag": 10, "taken": false},
		{"cell": Vector2i(9, 9), "item": 2, "flag": 11, "taken": true},
	]


## `request_notice`: queued in order, one banner line wide, refused rather than
## clipped, and capped so a mod cannot own the map for a minute.
func test_a_notice_is_measured_queued_and_capped() -> void:
	var host: Gen2ModHost = Gen2ModHost.instance()
	assert_true(bool(host.request_notice(MOD, {
		"title": "ACHIEVEMENT", "line": "Eight badges", "icon": {"badge": 0},
	})["ok"]))
	assert_eq(
		StringName(host.request_notice(&"", {"title": "x"})["reason"]),
		&"invalid_provider"
	)
	assert_eq(
		StringName(host.request_notice(MOD, {"title": "  ", "line": ""})["reason"]),
		&"empty_notice"
	)
	## Fifteen tiles is one line of the banner past the frame and the icon, and a
	## sixteenth is refused by name rather than clipped.
	var width: int = Gen2MapNameSignPage.NOTICE_COLUMNS
	assert_true(bool(host.request_notice(MOD, {"title": "A".repeat(width)})["ok"]))
	var wide: Dictionary = host.request_notice(MOD, {"title": "A".repeat(width + 1)})
	assert_eq(StringName(wide["reason"]), &"notice_line_too_long")
	assert_eq(
		StringName(host.request_notice(MOD, {"title": "one\ntwo"})["reason"]),
		&"notice_line_too_long"
	)
	assert_eq(
		StringName(host.request_notice(MOD, {"title": "x", "sound": &"shine"})["reason"]),
		&"unknown_notice_sound",
		"the sparkle is not one of the sounds a notice may borrow"
	)
	assert_eq(Gen2ModHost.notice_sound_index(&"item"), 0x01)
	assert_eq(Gen2ModHost.notice_sound_index(&"none"), -1)

	var first: Dictionary = host.take_notice_request()
	assert_eq(String(first["title"]), "ACHIEVEMENT")
	assert_eq(String(first["line"]), "Eight badges")
	assert_eq(StringName(first["sound"]), Gen2ModHost.NOTICE_SOUND_DEFAULT)
	assert_eq(String(host.take_notice_request()["title"]), "A".repeat(width))
	assert_eq(host.take_notice_request(), {})

	for _index: int in Gen2ModHost.MAX_NOTICES:
		assert_true(bool(host.request_notice(MOD, {"title": "x"})["ok"]))
	assert_eq(
		StringName(host.request_notice(MOD, {"title": "x"})["reason"]),
		&"notice_queue_full"
	)


## `register_page` and `START_ACTION_OPEN_MOD_PAGE`: one page per mod, the rows
## asked fresh and normalised, and a row naming the action absent until the page
## behind it exists.
func test_a_mod_page_is_registered_once_and_gates_its_own_start_row() -> void:
	var host: Gen2ModHost = Gen2ModHost.instance()
	var context: Dictionary = {"party_count": 1}
	assert_true(bool(host.register_menu_entry(Gen2ModHost.MENU_START, MOD, {
		"label": "AWARDS", "action": Gen2ModHost.START_ACTION_OPEN_MOD_PAGE,
	})["ok"]))
	assert_eq(
		host.start_menu_entries(context).size(), 0,
		"a row that would open nothing is absent rather than dead"
	)

	var rows := func() -> Array:
		return [
			{"label": "ZEPHYRBADGE", "detail": "Won", "icon": {"badge": 0}},
			{"label": "  ", "detail": "dropped"},
			{"label": "CHAMPION", "locked": true, "icon": "not a set of fields"},
		]
	assert_eq(
		StringName(host.register_page(&"", {"rows": rows})["reason"]), &"invalid_mod_page"
	)
	assert_eq(
		StringName(host.register_page(MOD, {"title": "AWARDS"})["reason"]),
		&"mod_page_missing_callable"
	)
	assert_true(bool(host.register_page(MOD, {"title": "AWARDS", "rows": rows})["ok"]))
	assert_eq(
		StringName(host.register_page(MOD, {"title": "AGAIN", "rows": rows})["reason"]),
		&"duplicate_mod_page"
	)
	assert_eq(host.page_ids(), [MOD])
	assert_eq(String(host.page(MOD)["title"]), "AWARDS")
	assert_false(host.page(MOD).has("rows"), "the mod's own function is not handed out")
	assert_eq(host.page(&"absent"), {})

	var listed: Array = host.page_rows(MOD)
	assert_eq(listed.size(), 2, "a row with no label is dropped")
	assert_eq(String(listed[0]["label"]), "ZEPHYRBADGE")
	assert_eq(listed[0]["icon"], {"badge": 0})
	assert_true(bool(listed[1]["locked"]))
	assert_eq(listed[1]["icon"], {}, "an icon that is not a set of fields is none")
	assert_eq(host.page_rows(&"absent"), [])

	assert_eq(host.start_menu_entries(context).size(), 1, "the page exists now")


## The badge tables are one engine flag apart between the two profiles, so a save
## read through the wrong one answers every badge wrongly. A mod calling
## `progress_for` from `save_activated` has no [GameData], and the save carries
## the cartridge it belongs to.
func test_a_progress_reading_uses_the_cartridge_the_save_names() -> void:
	var save := Gen2SaveData.new()
	save.game_id = &"gold"
	save.world = Gen2WorldSnapshot.new()
	## Gold and Silver's first badge, which on Crystal's table is not a badge the
	## mask counts at all.
	save.world.world_state.set_engine_flag(
		Gen2WorldState.badge_flag(0, false), true
	)

	var told: Dictionary = Gen2ModProgress.of_save(save)
	assert_eq(int(told[&"badges"]), 0b1, "the save's own game_id picked the table")
	assert_eq(int(told[&"badge_count"]), 1)

	save.game_id = &"crystal"
	assert_eq(
		int(Gen2ModProgress.of_save(save)[&"badges"]), 0,
		"and Crystal's table reads the same flag as no badge",
	)
	assert_true(
		Gen2WorldState.is_crystal_game_id(&"crystal"),
		"an id nobody recognises is Crystal, as a null cache has always been",
	)
	assert_false(Gen2WorldState.is_crystal_game_id(&"silver"))


## `progress`, `progress_for` and `progress_changed`: the same fields off a live
## run and off a save nobody has opened yet, a field that moved emitted once, and
## nothing read at all while no mod is watching.
func test_the_progress_reading_answers_a_save_and_reports_what_moved() -> void:
	var host: Gen2ModHost = Gen2ModHost.instance()
	assert_eq(host.progress(), {}, "no world open")

	var save := Gen2SaveData.new()
	save.world = Gen2WorldSnapshot.new()
	var state: Gen2WorldState = save.world.world_state
	state.set_engine_flag(
		Gen2WorldState.badge_flag(0), true
	)
	state.set_engine_flag(Gen2WorldState.badge_flag(1), true)
	var mon := Gen2SaveMon.new()
	mon.species = 25
	mon.level = 42
	mon.dvs = Gen2Stats.SHINY_DVS
	save.party = [mon]

	var reading: Dictionary = host.progress_for(save)
	assert_eq(int(reading[&"badges"]), 0b11)
	assert_eq(int(reading[&"badge_count"]), 2)
	assert_eq(int(reading[&"party_count"]), 1)
	assert_eq(int(reading[&"kept_count"]), 1, "the boxes are empty")
	assert_eq(int(reading[&"highest_level"]), 42)
	assert_eq(int(reading[&"shiny_count"]), 1)
	assert_false(bool(reading[&"beat_red"]))
	## A save with no world at all answers what the save itself holds and leaves
	## every world field out rather than zeroing it.
	var bare: Dictionary = Gen2ModProgress.of_save(Gen2SaveData.new())
	assert_false(bare.has(&"badges"))
	assert_true(bare.has(&"party_count"))

	## Nothing is read while nobody is watching: the party and every box are the
	## expensive half of a reading.
	var reads: Array = []
	var source := func() -> Dictionary:
		reads.append(true)
		return Gen2ModProgress.of_save(save)
	host.set_progress_source(source)
	host.refresh_progress()
	assert_eq(reads.size(), 0, "no connection, no reading")

	var seen: Array = []
	host.progress_changed.connect(func(moved: Dictionary) -> void: seen.append(moved))
	host.refresh_progress()
	assert_eq(seen.size(), 1, "the first reading is a move from nothing")
	host.refresh_progress()
	assert_eq(seen.size(), 1, "a reading that did not move is not emitted")

	state.set_engine_flag(Gen2WorldState.badge_flag(2), true)
	host.refresh_progress()
	assert_eq(seen.size(), 2)
	assert_eq(int((seen.back() as Dictionary)[&"badge_count"]), 3)

	host.set_progress_source(Callable())
	assert_eq(host.progress(), {}, "the world closed")
