extends GutTest

## Service hosts use the imported cache and the production world transaction
## boundaries. The fixture remains synthetic so no cartridge data enters tests.

const Fixture := preload("res://tests/integration/world_trainer_fixture.gd")

const APRICORN_RED: int = 0x55
const APRICORN_PNK: int = 0x65
const BALL_LEVEL: int = 0x9F

var _data: GameData = null
var _world: Gen2WorldAPI = null
var _save: Gen2SaveData = null


func before_each() -> void:
	_data = Fixture.build()
	_write_services()
	_data = GameData.open_directory(Fixture.directory())
	var state := Gen2WorldState.new({}, {}, {7: 1}, {0: 500})
	_world = Gen2WorldAPI.open(
		_data, Fixture.MAP_GROUP, Fixture.MAP_NUMBER, Vector2i(7, 6), state
	)
	_save = Gen2SaveStore.create_development_save(_data, 0)
	_save.world = _world.snapshot()


func after_each() -> void:
	RomCache.clear(Fixture.directory())


## Every runtime request the runner can stage has to reach something that draws
## it, and the four tables below are the whole set of answers there are. Without
## this, `special NameRival` staged a request nothing opened, so the policeman
## asked the question and [Gen2WorldHost]'s default answered SILVER for the
## player. A kind that genuinely has nothing to draw belongs in
## [constant Gen2WorldHost.UNATTENDED_REQUESTS] with the reason beside it.
func test_every_runtime_request_kind_reaches_a_screen_or_is_named_unattended() -> void:
	var answered: Dictionary = {}
	for kind: StringName in Gen2WorldScreen.REQUEST_HANDLERS:
		answered[kind] = true
	for kind: StringName in Gen2WorldScreen.REQUEST_OPENERS:
		answered[kind] = true
	for kind: StringName in Gen2WorldScreen.SERVICE_HOST_REQUESTS:
		answered[kind] = true
	for kind: StringName in Gen2WorldHost.UNATTENDED_REQUESTS:
		answered[kind] = true
	var unanswered: Array[StringName] = []
	for kind: StringName in Gen2WorldScriptRunner.COMPLETION_HANDLERS:
		if not answered.has(kind):
			unanswered.append(kind)
	assert_eq(unanswered, [] as Array[StringName],
		"these staged requests reach no screen and are not named unattended")


func test_mart_entries_use_imported_items_and_prices() -> void:
	var mart: Dictionary = _data.world_mart(0)
	var entries: Array = Gen2WorldMartHost.entries(_data, mart)
	assert_eq(entries.size(), 2)
	assert_eq(entries[0]["item"], 7)
	assert_eq(entries[0]["name"], "ITEM7")
	assert_eq(entries[0]["price"], 120)


func test_mart_purchase_updates_money_items_and_save_atomically() -> void:
	_set_mart_script()
	var waiting: Array = _world.dispatch_script_events(Vector2i(7, 6))
	assert_eq(waiting[0]["status"], &"waiting")
	assert_eq(_world.pending_runtime_request()["kind"], &"mart_requested")

	var resolved: Dictionary = Gen2WorldHost.resolve_runtime_request(_world)
	assert_true(resolved["ok"])
	var purchase: Dictionary = Gen2WorldMartHost.purchase(
		_world, _save, resolved["data"]["mart"], 7, 2, false
	)
	assert_true(purchase["ok"])
	assert_eq(_world.state.item_quantity(7), 3)
	assert_eq(_world.state.money(), 260)
	assert_eq(_save.world.world_state.item_quantity(7), 3)
	assert_eq(_save.world.world_state.money(), 260)

	var complete: Dictionary = Gen2WorldHost.complete_runtime_request(
		_world, {"ok": true, "script_value": 1}, _save, false
	)
	assert_true(complete["ok"])
	assert_eq(complete["results"][0]["status"], &"complete")


func test_mart_purchase_refuses_insufficient_money_without_mutation() -> void:
	var mart: Dictionary = _data.world_mart(0)
	var before: Dictionary = _world.snapshot().to_dict()
	var result: Dictionary = Gen2WorldMartHost.purchase(
		_world, _save, mart, 7, 5, false
	)
	assert_false(result["ok"])
	assert_eq(result["reason"], &"insufficient_money")
	assert_eq(_world.snapshot().to_dict(), before)
	assert_eq(_save.world.world_state.money(), 500)


## `SellMenu.okay_to_sell`: the stack leaves the pack and `GiveMoney` puts
## `Sell_HalvePrice`'s answer in, which halves the multiplied total rather than
## each unit's price.
func test_mart_sale_pays_half_the_multiplied_price_and_empties_the_stack() -> void:
	_world.state.apply_changes({}, {}, {"items": {7: 3}})
	assert_eq(Gen2WorldMartHost.sell_price(_data, 7, 1), 60)
	assert_eq(Gen2WorldMartHost.sell_price(_data, 7, 3), 180)

	var sold: Dictionary = Gen2WorldMartHost.sell(_world, _save, 7, 3, false)
	assert_true(bool(sold["ok"]), str(sold))
	assert_eq(int(sold["total"]), 180)
	assert_eq(_world.state.item_quantity(7), 0)
	assert_eq(_world.state.money(), 680)
	assert_eq(_save.world.world_state.money(), 680)


## `.try_sell`'s `_CheckTossableItem` refusal, and the quantity guard in front
## of it, neither of which touches the world.
func test_mart_sale_refuses_an_untossable_item_and_an_impossible_quantity() -> void:
	var before: Dictionary = _world.snapshot().to_dict()
	var too_many: Dictionary = Gen2WorldMartHost.sell(_world, _save, 7, 9, false)
	assert_eq(StringName(too_many["reason"]), &"invalid_sell_quantity")

	_world.state.apply_changes({}, {}, {"items": {8: 1}})
	assert_false(Gen2WorldMartHost.can_sell(_data, 8))
	var refused: Dictionary = Gen2WorldMartHost.sell(_world, _save, 8, 1, false)
	assert_eq(StringName(refused["reason"]), &"item_cannot_be_sold")
	_world.state.apply_changes({}, {}, {"items": {8: 0}})
	assert_eq(_world.snapshot().to_dict(), before)


func test_mart_dialog_resolves_all_imported_shop_variants() -> void:
	var standard: Dictionary = Gen2WorldMartHost.resolve_mart(
		_data, Gen2WorldMartHost.MARTTYPE_STANDARD, 0
	)
	assert_true(standard["ok"])
	assert_eq(standard["mart"]["variant"], &"standard")
	var bitter: Dictionary = Gen2WorldMartHost.resolve_mart(
		_data, Gen2WorldMartHost.MARTTYPE_BITTER, 0
	)
	assert_true(bitter["ok"])
	assert_eq(bitter["mart"]["variant"], &"bitter")
	var pharmacy: Dictionary = Gen2WorldMartHost.resolve_mart(
		_data, Gen2WorldMartHost.MARTTYPE_PHARMACY, 0
	)
	assert_true(pharmacy["ok"])
	assert_eq(pharmacy["mart"]["variant"], &"pharmacy")
	var bargain: Dictionary = Gen2WorldMartHost.resolve_mart(
		_data, Gen2WorldMartHost.MARTTYPE_BARGAIN, 0
	)
	assert_true(bargain["ok"])
	assert_eq(bargain["mart"]["variant"], &"bargain")
	assert_eq(bargain["mart"]["items"][0]["price"], 50)
	var rooftop: Dictionary = Gen2WorldMartHost.resolve_mart(
		_data, Gen2WorldMartHost.MARTTYPE_ROOFTOP, 0
	)
	assert_true(rooftop["ok"])
	assert_eq(rooftop["mart"]["variant"], &"rooftop_mart_1")
	assert_eq(rooftop["mart"]["items"][0]["price"], 10)
	var invalid: Dictionary = Gen2WorldMartHost.resolve_mart(_data, 9, 0)
	assert_false(invalid["ok"])
	assert_eq(invalid["reason"], &"unsupported_mart_dialog")


func test_mart_host_uses_hall_of_fame_for_rooftop_stock() -> void:
	_set_mart_script(Gen2WorldMartHost.MARTTYPE_ROOFTOP)
	_world.state.set_hall_of_fame()
	var waiting: Array = _world.dispatch_script_events(Vector2i(7, 6))
	assert_eq(waiting[0]["status"], &"waiting")
	var resolved: Dictionary = Gen2WorldHost.resolve_runtime_request(_world)
	assert_true(resolved["ok"])
	assert_eq(resolved["data"]["mart"]["variant"], &"rooftop_mart_2")
	assert_eq(resolved["data"]["mart"]["items"][0]["price"], 20)


func test_bargain_purchase_closes_merchant_and_sells_each_item_once() -> void:
	var bargain: Dictionary = Gen2WorldMartHost.resolve_mart(
		_data, Gen2WorldMartHost.MARTTYPE_BARGAIN, 0, false, _world.state
	)
	assert_true(bargain["ok"])
	var quantity: Dictionary = Gen2WorldMartHost.purchase(
		_world, _save, bargain["mart"], 7, 2, false
	)
	assert_false(quantity["ok"])
	assert_eq(quantity["reason"], &"bargain_quantity_must_be_one")
	var purchase: Dictionary = Gen2WorldMartHost.purchase(
		_world, _save, bargain["mart"], 7, 1, false
	)
	assert_true(purchase["ok"])
	assert_true(_world.state.bargain_merchant_closed())
	assert_true(_save.world.world_state.bargain_merchant_closed())
	assert_true(Gen2WorldMartHost.entries(_data, bargain["mart"])[0]["sold_out"])
	var sold_out: Dictionary = Gen2WorldMartHost.purchase(
		_world, _save, bargain["mart"], 7, 1, false
	)
	assert_false(sold_out["ok"])
	assert_eq(sold_out["reason"], &"bargain_item_sold_out")
	var closed: Dictionary = Gen2WorldMartHost.resolve_mart(
		_data, Gen2WorldMartHost.MARTTYPE_BARGAIN, 0, false, _world.state
	)
	assert_false(closed["ok"])
	assert_eq(closed["reason"], &"bargain_mart_closed")
	_world.set_world_clock(1, 6, 0)
	var next_day: Dictionary = Gen2WorldMartHost.resolve_mart(
		_data, Gen2WorldMartHost.MARTTYPE_BARGAIN, 0, false, _world.state
	)
	assert_true(next_day["ok"])


## The Goldenrod Underground merchant flag is one index lower in pinned
## pokegold than in pinned pokecrystal (constants/engine_flags.asm). A
## purchase against a Gold-profile GameData must close the merchant at that
## lower index, not the Crystal one, or a real pokegold bargain script's
## checkflag would never see the closure this project just wrote.
func test_bargain_purchase_on_a_gold_profile_cache_closes_the_gold_silver_flag() -> void:
	var gold_directory: String = Fixture.directory(&"gold")
	var gold_data: GameData = Fixture.build(&"gold")
	_write_services_at(gold_directory)
	gold_data = GameData.open_directory(gold_directory)
	var gold_world: Gen2WorldAPI = Gen2WorldAPI.open(
		gold_data, Fixture.MAP_GROUP, Fixture.MAP_NUMBER, Vector2i(7, 6),
		Gen2WorldState.new({}, {}, {7: 1}, {0: 500})
	)
	var gold_save: Gen2SaveData = Gen2SaveStore.create_development_save(gold_data, 0)
	gold_save.world = gold_world.snapshot()

	var bargain: Dictionary = Gen2WorldMartHost.resolve_mart(
		gold_data, Gen2WorldMartHost.MARTTYPE_BARGAIN, 0, false, gold_world.state
	)
	assert_true(bargain["ok"])
	var purchase: Dictionary = Gen2WorldMartHost.purchase(
		gold_world, gold_save, bargain["mart"], 7, 1, false
	)
	assert_true(purchase["ok"])
	assert_true(gold_world.state.bargain_merchant_closed(false))
	assert_false(gold_world.state.bargain_merchant_closed(true))
	var closed: Dictionary = Gen2WorldMartHost.resolve_mart(
		gold_data, Gen2WorldMartHost.MARTTYPE_BARGAIN, 0, false, gold_world.state
	)
	assert_false(closed["ok"])
	assert_eq(closed["reason"], &"bargain_mart_closed")

	RomCache.clear(gold_directory)


func test_bargain_host_refuses_a_closed_merchant_before_opening_ui() -> void:
	_set_mart_script(Gen2WorldMartHost.MARTTYPE_BARGAIN)
	_world.state.set_engine_flag(Gen2WorldState.ENGINE_GOLDENROD_UNDERGROUND_MERCHANT_CLOSED)
	var waiting: Array = _world.dispatch_script_events(Vector2i(7, 6))
	assert_eq(waiting[0]["status"], &"waiting")
	var resolved: Dictionary = Gen2WorldHost.resolve_runtime_request(_world)
	assert_false(resolved["ok"])
	assert_eq(resolved["reason"], &"bargain_mart_closed")


func test_bargain_script_keeps_the_source_monday_morning_gate() -> void:
	_write_bargain_schedule_script()
	var monday_morning := Gen2WorldScriptRunner.begin(_data, _world.state, {
		"kind": &"test", "bank": Fixture.BANK, "script": 0x6300,
		"clock": {"day": 1, "hour": 6, "minute": 0},
	})
	var morning_result: Dictionary = monday_morning.advance()
	assert_eq(morning_result["status"], &"waiting")
	assert_eq(morning_result["event"]["request"]["kind"], &"mart_requested")
	assert_eq(morning_result["event"]["request"]["values"]["dialog"], Gen2WorldMartHost.MARTTYPE_BARGAIN)
	var sunday := Gen2WorldScriptRunner.begin(_data, _world.state, {
		"kind": &"test", "bank": Fixture.BANK, "script": 0x6300,
		"clock": {"day": 0, "hour": 6, "minute": 0},
	})
	assert_eq(sunday.advance()["status"], &"complete")
	var monday_night := Gen2WorldScriptRunner.begin(_data, _world.state, {
		"kind": &"test", "bank": Fixture.BANK, "script": 0x6300,
		"clock": {"day": 1, "hour": 18, "minute": 0},
	})
	assert_eq(monday_night.advance()["status"], &"complete")


func test_mart_purchase_refuses_crossing_the_source_item_stack_limit() -> void:
	var mart: Dictionary = _data.world_mart(0)
	## `BuyMenuLoop` asks `CompareMoney` first, so the stack is only what refuses
	## once the whole order is affordable.
	_world.state.apply_changes({}, {}, {"money": {0: 999999}})
	var before: Dictionary = _world.snapshot().to_dict()
	var result: Dictionary = Gen2WorldMartHost.purchase(
		_world, _save, mart, 7, Gen2WorldPack.MAX_ITEM_STACK, false
	)
	assert_false(result["ok"])
	assert_eq(result["reason"], &"item_stack_full")
	assert_eq(_world.snapshot().to_dict(), before)


## `BuyMenuLoop`'s own order: `CompareMoney` runs before `ReceiveItem`, so an
## order that fails both is refused on the price.
func test_mart_purchase_refuses_on_money_before_the_stack_limit() -> void:
	var mart: Dictionary = _data.world_mart(0)
	var result: Dictionary = Gen2WorldMartHost.purchase(
		_world, _save, mart, 7, Gen2WorldPack.MAX_ITEM_STACK, false
	)
	assert_false(result["ok"])
	assert_eq(result["reason"], &"insufficient_money")


func test_phone_summary_uses_imported_contact_and_trainer_class() -> void:
	var contact: Dictionary = _data.world_phone_contact(0)
	var summary: Dictionary = Gen2WorldPhoneHost.contact_summary(_data, contact)
	assert_eq(summary["index"], 0)
	assert_eq(summary["trainer_name"], "LEADER")
	assert_eq(summary["trainer_number"], 2)
	assert_eq(summary["map_group"], Fixture.MAP_GROUP)


func test_phone_time_masks_and_map_rules_match_the_cartridge() -> void:
	assert_eq(Gen2WorldPhoneHost.time_mask_for_hour(3), Gen2WorldPhoneHost.TIME_NIGHT)
	assert_eq(Gen2WorldPhoneHost.time_mask_for_hour(4), Gen2WorldPhoneHost.TIME_MORNING)
	assert_eq(Gen2WorldPhoneHost.time_mask_for_hour(10), Gen2WorldPhoneHost.TIME_DAY)
	assert_eq(Gen2WorldPhoneHost.time_mask_for_hour(18), Gen2WorldPhoneHost.TIME_NIGHT)
	assert_true(Gen2WorldPhoneHost.time_mask_matches(7, 23))
	assert_false(Gen2WorldPhoneHost.time_mask_matches(2, 6))

	var map := Gen2WorldMap.new()
	map.group = Fixture.MAP_GROUP + 1
	map.number = Fixture.MAP_NUMBER
	map.environment = 0
	map.phone_flag = 0
	var state := Gen2WorldState.new({}, {}, {}, {}, 0, {0: true})
	var incoming: Dictionary = Gen2WorldPhoneHost.resolve_incoming(
		_data, state, map, 6, true, true, 0
	)
	assert_true(incoming["ok"])
	assert_eq(incoming["contact_id"], 0)

	map.group = Fixture.MAP_GROUP
	var same_map: Dictionary = Gen2WorldPhoneHost.resolve_incoming(
		_data, state, map, 6, true, true, 0
	)
	assert_false(same_map["ok"])
	assert_eq(same_map["reason"], &"no_available_caller")
	map.phone_flag = 1
	var no_service: Dictionary = Gen2WorldPhoneHost.resolve_incoming(
		_data, state, map, 6, true, true, 0
	)
	assert_false(no_service["ok"])
	assert_eq(no_service["reason"], &"phone_service_unavailable")


func test_outgoing_phone_uses_imported_same_map_and_out_of_area_scripts() -> void:
	var metadata: Dictionary = {
		"out_of_area_script": {"bank": Fixture.BANK, "address": 0x6600},
		"just_talk_script": {"bank": Fixture.BANK, "address": 0x6610},
	}
	var phone: Dictionary = RomCache.read_json(RomCache.world_phone_path(Fixture.directory()))
	phone["metadata"] = metadata
	RomCache.write_json(RomCache.world_phone_path(Fixture.directory()), phone)
	_data = GameData.open_directory(Fixture.directory())
	var state := Gen2WorldState.new({}, {}, {}, {}, 0, {0: true})
	var same_map: Dictionary = Gen2WorldPhoneHost.resolve_outgoing(
		_data, state, _world.current_map, 0, 12
	)
	assert_true(same_map["ok"])
	assert_true(same_map["phone"]["same_map"])
	assert_eq(same_map["script"]["address"], 0x6610)
	_world.current_map.phone_flag = 1
	var out_of_area: Dictionary = Gen2WorldPhoneHost.resolve_outgoing(
		_data, state, _world.current_map, 0, 12
	)
	assert_true(out_of_area["ok"])
	assert_true(out_of_area["out_of_area"])
	assert_eq(out_of_area["script"]["address"], 0x6600)


func test_audio_host_runs_the_real_record_without_a_second_renderer() -> void:
	var record: Dictionary = _data.world_audio(&"music", 0)
	var result: Dictionary = Gen2WorldAudioHost.play(record, &"music")
	assert_true(result["ok"])
	assert_false(result["played"])
	assert_eq(result["backend"], Gen2WorldAudioHost.BACKEND_PROBE)
	assert_true(result["ready"])
	assert_eq(result["byte_count"], 6)
	assert_false(result.has("stream"))


func test_menu_input_can_be_cancelled_without_selecting_an_option() -> void:
	_write_menu_script()
	var runner := Gen2WorldScriptRunner.begin(_data, _world.state, {
		"kind": &"test", "bank": Fixture.BANK, "script": 0x6310,
	})
	var waiting: Dictionary = runner.advance()
	assert_eq(waiting["status"], &"waiting")
	assert_eq(waiting["event"]["type"], &"menu")
	var complete: Dictionary = runner.cancel_input()
	assert_eq(complete["status"], &"complete")
	assert_true(complete["events"].any(func(event: Dictionary) -> bool:
		return event.get("type", &"") == &"state_changed"
	) == false)


## `special NameRater`, the same shape Kurt's own special is staged with.
func _set_name_rater_script() -> void:
	_set_special_script(Gen2WorldScriptRunner.SPECIAL_NAME_RATER)


## One `special` on the cell the world opens standing on, and a world rebuilt
## around it.
func _set_special_script(special: int) -> void:
	var scripts: Dictionary = RomCache.read_json(RomCache.world_scripts_path(Fixture.directory()))
	scripts[Gen2WorldScript.pointer_key(Fixture.BANK, 0x6300)] = [
		Gen2WorldScript.SPECIAL,
		special, 0x00,
		Gen2WorldScript.END,
	]
	RomCache.write_json(RomCache.world_scripts_path(Fixture.directory()), scripts)
	var maps: Array = RomCache.read_json(RomCache.world_maps_path(Fixture.directory()))
	for raw: Dictionary in maps:
		if int(raw.get("group", -1)) != Fixture.MAP_GROUP \
		or int(raw.get("number", -1)) != Fixture.MAP_NUMBER:
			continue
		var events: Dictionary = raw.get("events", {})
		events["coord_events"] = [{"x": 7, "y": 6, "script": 0x6300}]
		raw["events"] = events
	RomCache.write_json(RomCache.world_maps_path(Fixture.directory()), maps)
	_data = GameData.open_directory(Fixture.directory())
	_world = Gen2WorldAPI.open(
		_data, Fixture.MAP_GROUP, Fixture.MAP_NUMBER, Vector2i(7, 6),
		Gen2WorldState.new({}, {}, {})
	)
	_save = Gen2SaveStore.create_development_save(_data, 0)
	_save.world = _world.snapshot()


## The five Day-Care specials, staged the same way and answered from the same
## run of stubs. The role is what tells the one screen which routine it is.
func test_the_five_day_care_specials_each_stage_their_own_role() -> void:
	var roles: Dictionary = {
		Gen2WorldScriptRunner.SPECIAL_DAY_CARE_MAN: &"man",
		Gen2WorldScriptRunner.SPECIAL_DAY_CARE_LADY: &"lady",
		Gen2WorldScriptRunner.SPECIAL_DAY_CARE_MAN_OUTSIDE: &"outside",
		Gen2WorldScriptRunner.SPECIAL_DAY_CARE_MON_1: &"mon1",
		Gen2WorldScriptRunner.SPECIAL_DAY_CARE_MON_2: &"mon2",
	}
	for special: int in roles:
		_set_special_script(special)
		var waiting: Array = _world.dispatch_script_events(Vector2i(7, 6))
		assert_eq(waiting[0]["status"], &"waiting", JSON.stringify(waiting))
		var request: Dictionary = _world.pending_runtime_request()
		assert_eq(request["kind"], &"day_care_requested")
		assert_eq(StringName(request["values"]["role"]), StringName(roles[special]))

		var resolved: Dictionary = Gen2WorldHost.resolve_runtime_request(_world)
		assert_true(resolved["ok"], JSON.stringify(resolved))
		assert_eq(
			(resolved["data"]["day_care_text"] as Dictionary).size(),
			Gen2WorldHost.day_care_texts(_data).size()
		)


## Four of the five write no wScriptVar at all, so a completion with no value in
## it must leave whatever the script had put there.
func test_a_day_care_completion_without_a_value_leaves_the_script_variable() -> void:
	_set_special_script(Gen2WorldScriptRunner.SPECIAL_DAY_CARE_MON_1)
	_world.dispatch_script_events(Vector2i(7, 6))
	var results: Array = _world.complete_runtime_request({"ok": true})
	assert_false(results.is_empty())
	assert_true(bool(results[0].get("ok", false)), JSON.stringify(results))


func test_name_rater_special_stages_a_request_carrying_all_ten_boxes() -> void:
	_set_name_rater_script()
	var waiting: Array = _world.dispatch_script_events(Vector2i(7, 6))
	assert_eq(waiting[0]["status"], &"waiting", JSON.stringify(waiting))
	assert_eq(_world.pending_runtime_request()["kind"], &"name_rater_requested")

	var resolved: Dictionary = Gen2WorldHost.resolve_runtime_request(_world)
	assert_true(resolved["ok"], JSON.stringify(resolved))
	var lines: Dictionary = resolved["data"]["name_rater_text"]
	assert_eq(lines.size(), Gen2Layout.NAME_RATER_TEXT_ORDER.size())
	for row_name: String in Gen2Layout.NAME_RATER_TEXT_ORDER:
		assert_false(String(lines[row_name]).is_empty(), row_name)


## A cache imported before format 76 carries none of the boxes, and inventing
## his lines would be worse than saying the host cannot run.
func test_name_rater_refuses_a_cache_without_his_boxes() -> void:
	var manifest: Dictionary = RomCache.read_manifest(Fixture.directory())
	manifest.erase("name_rater_text")
	RomCache.write_json(RomCache.manifest_path(Fixture.directory()), manifest)
	_set_name_rater_script()
	assert_eq(_world.dispatch_script_events(Vector2i(7, 6))[0]["status"], &"waiting")
	var resolved: Dictionary = Gen2WorldHost.resolve_runtime_request(_world)
	assert_false(resolved["ok"])
	assert_eq(resolved["reason"], &"name_rater_text_unavailable")


## `_NameRaterPerfectNameText` names `wStringBuffer1` twice, so filling the
## first marker alone leaves the second on screen.
func test_every_nickname_marker_in_a_box_is_filled() -> void:
	var filled: String = Gen2TextStream.fill_all_markers(
		_data.name_rater_text("perfect_name"), Gen2TextStream.RAM_MARKER, "SPARKY"
	)
	assert_false(filled.contains(Gen2TextStream.RAM_MARKER))
	assert_eq(filled.count("SPARKY"), 2)


## `special MoveDeletion`, staged the same way.
func _set_move_deleter_script() -> void:
	var scripts: Dictionary = RomCache.read_json(RomCache.world_scripts_path(Fixture.directory()))
	scripts[Gen2WorldScript.pointer_key(Fixture.BANK, 0x6300)] = [
		Gen2WorldScript.SPECIAL,
		Gen2WorldScriptRunner.SPECIAL_MOVE_DELETION, 0x00,
		Gen2WorldScript.END,
	]
	RomCache.write_json(RomCache.world_scripts_path(Fixture.directory()), scripts)
	var maps: Array = RomCache.read_json(RomCache.world_maps_path(Fixture.directory()))
	for raw: Dictionary in maps:
		if int(raw.get("group", -1)) != Fixture.MAP_GROUP \
		or int(raw.get("number", -1)) != Fixture.MAP_NUMBER:
			continue
		var events: Dictionary = raw.get("events", {})
		events["coord_events"] = [{"x": 7, "y": 6, "script": 0x6300}]
		raw["events"] = events
	RomCache.write_json(RomCache.world_maps_path(Fixture.directory()), maps)
	_data = GameData.open_directory(Fixture.directory())
	_world = Gen2WorldAPI.open(
		_data, Fixture.MAP_GROUP, Fixture.MAP_NUMBER, Vector2i(7, 6),
		Gen2WorldState.new({}, {}, {})
	)
	_save = Gen2SaveStore.create_development_save(_data, 0)
	_save.world = _world.snapshot()


func test_move_deleter_special_stages_a_request_carrying_all_eight_boxes() -> void:
	_set_move_deleter_script()
	var waiting: Array = _world.dispatch_script_events(Vector2i(7, 6))
	assert_eq(waiting[0]["status"], &"waiting", JSON.stringify(waiting))
	assert_eq(_world.pending_runtime_request()["kind"], &"move_deleter_requested")

	var resolved: Dictionary = Gen2WorldHost.resolve_runtime_request(_world)
	assert_true(resolved["ok"], JSON.stringify(resolved))
	var lines: Dictionary = resolved["data"]["move_deleter_text"]
	assert_eq(lines.size(), Gen2Layout.MOVE_DELETER_TEXT_ORDER.size())
	for row_name: String in Gen2Layout.MOVE_DELETER_TEXT_ORDER:
		assert_false(String(lines[row_name]).is_empty(), row_name)


func test_move_deleter_refuses_a_cache_without_his_boxes() -> void:
	var manifest: Dictionary = RomCache.read_manifest(Fixture.directory())
	manifest.erase("move_deleter_text")
	RomCache.write_json(RomCache.manifest_path(Fixture.directory()), manifest)
	_set_move_deleter_script()
	assert_eq(_world.dispatch_script_events(Vector2i(7, 6))[0]["status"], &"waiting")
	var resolved: Dictionary = Gen2WorldHost.resolve_runtime_request(_world)
	assert_false(resolved["ok"])
	assert_eq(resolved["reason"], &"move_deleter_text_unavailable")


func _write_services() -> void:
	_write_services_at(Fixture.directory())


func _write_services_at(directory: String) -> void:
	var items: Array = RomCache.read_json(RomCache.items_path(directory))
	for raw: Dictionary in items:
		if int(raw.get("number", 0)) == 7:
			raw["name"] = "ITEM7"
			raw["price"] = 120
		## `ITEMATTR_PERMISSIONS`' can't-toss bit, which is what `SellMenu`'s
		## `_CheckTossableItem` refuses a key item with.
		if int(raw.get("number", 0)) == 8:
			raw["permissions"] = Gen2Layout.ITEM_ATTRIBUTE_CANT_TOSS
	RomCache.write_json(RomCache.items_path(directory), items)
	RomCache.write_json(RomCache.world_marts_path(directory), {
		"marts": [{"index": 0, "bank": Fixture.BANK, "address": 0x4000, "items": [7, 8]}],
		"default": {"items": [7]}, "special": {
			"bargain": [{"item": 7, "price": 50}],
			"rooftop_mart_1": [{"item": 8, "price": 10}],
			"rooftop_mart_2": [{"item": 8, "price": 20}],
		},
	})
	RomCache.write_json(RomCache.world_phone_path(directory), {
		"contacts": [{
			"index": 0, "trainer_class": 1, "trainer_number": 2,
			"map_group": Fixture.MAP_GROUP, "map_number": Fixture.MAP_NUMBER,
			"callee_time": 1, "caller_time": 2,
		}],
		"special_calls": [],
	})
	RomCache.write_json(RomCache.world_audio_path(directory), {
		"music": [{"index": 0, "bank": Fixture.BANK, "address": 0x4000,
			"bytes": [0x00, 0x03, 0x40, 0xD4, 0x10, 0xFF], "byte_count": 6}],
		"sfx": [],
	})


## `Elevator`'s `.FindCurrentFloor` fails with `scf` when the backup map is on no
## floor row, and `Script_elevator`'s `ret c` swallows it: the car draws no menu,
## wScriptVar stays FALSE and the script runs on. It is not a refused request.
func test_an_elevator_that_cannot_place_itself_leaves_the_script_running() -> void:
	_set_elevator_script()
	assert_eq(_world.backup_warp, {})
	var waiting: Array = _world.dispatch_script_events(Vector2i(7, 6))
	assert_eq(waiting[0]["status"], &"waiting")
	assert_eq(_world.pending_runtime_request()["kind"], &"elevator_requested")
	var resolved: Dictionary = Gen2WorldHost.resolve_runtime_request(_world)
	assert_true(bool(resolved["ok"]), JSON.stringify(resolved))
	assert_eq(int(resolved["data"]["elevator"]["current"]), -1)
	var complete: Dictionary = Gen2WorldHost.complete_runtime_request(
		_world, {"ok": true}, _save, false
	)
	assert_eq(complete["results"][0]["status"], &"complete", JSON.stringify(complete))


## The same list with the backup warp standing on one of its rows, which is every
## ordinary ride.
func test_an_elevator_places_itself_on_the_backup_warps_floor() -> void:
	_set_elevator_script()
	_world.backup_warp = {
		"map_group": Fixture.MAP_GROUP, "map_number": Fixture.MAP_NUMBER, "warp": 1,
	}
	_world.dispatch_script_events(Vector2i(7, 6))
	var resolved: Dictionary = Gen2WorldHost.resolve_runtime_request(_world)
	assert_eq(int(resolved["data"]["elevator"]["current"]), 1)


## `elevfloor`'s two rows behind a `Script_elevator` on the fixture's coord event.
## The first row names a map nothing here stands on; the second is this map.
func _set_elevator_script() -> void:
	var scripts: Dictionary = RomCache.read_json(RomCache.world_scripts_path(Fixture.directory()))
	scripts[Gen2WorldScript.pointer_key(Fixture.BANK, 0x6300)] = [
		0x95, 0x10, 0x40, 0x91,
	]
	scripts[Gen2WorldScript.pointer_key(Fixture.BANK, 0x4010)] = [
		2, 4, 4, 21, 5, 5, 3, Fixture.MAP_GROUP, Fixture.MAP_NUMBER, 0xFF,
	]
	RomCache.write_json(RomCache.world_scripts_path(Fixture.directory()), scripts)
	var maps: Array = RomCache.read_json(RomCache.world_maps_path(Fixture.directory()))
	for raw: Dictionary in maps:
		if int(raw.get("group", -1)) != Fixture.MAP_GROUP \
		or int(raw.get("number", -1)) != Fixture.MAP_NUMBER:
			continue
		var events: Dictionary = raw.get("events", {})
		events["coord_events"] = [{"x": 7, "y": 6, "script": 0x6300}]
		raw["events"] = events
	RomCache.write_json(RomCache.world_maps_path(Fixture.directory()), maps)
	_data = GameData.open_directory(Fixture.directory())
	_world = Gen2WorldAPI.open(
		_data, Fixture.MAP_GROUP, Fixture.MAP_NUMBER, Vector2i(7, 6), _world.state
	)


func _set_mart_script(dialog_id: int = Gen2WorldMartHost.MARTTYPE_STANDARD) -> void:
	var scripts: Dictionary = RomCache.read_json(RomCache.world_scripts_path(Fixture.directory()))
	scripts[Gen2WorldScript.pointer_key(Fixture.BANK, 0x6300)] = [0x94, dialog_id, 0x00, 0x40, 0x91]
	RomCache.write_json(RomCache.world_scripts_path(Fixture.directory()), scripts)
	var maps: Array = RomCache.read_json(RomCache.world_maps_path(Fixture.directory()))
	for raw: Dictionary in maps:
		if int(raw.get("group", -1)) != Fixture.MAP_GROUP \
		or int(raw.get("number", -1)) != Fixture.MAP_NUMBER:
			continue
		var events: Dictionary = raw.get("events", {})
		events["coord_events"] = [{"x": 7, "y": 6, "script": 0x6300}]
		raw["events"] = events
	RomCache.write_json(RomCache.world_maps_path(Fixture.directory()), maps)
	_data = GameData.open_directory(Fixture.directory())
	_world = Gen2WorldAPI.open(
		_data, Fixture.MAP_GROUP, Fixture.MAP_NUMBER, Vector2i(7, 6),
		Gen2WorldState.new({}, {}, {7: 1}, {0: 500})
	)
	_save = Gen2SaveStore.create_development_save(_data, 0)
	_save.world = _world.snapshot()


func _write_bargain_schedule_script() -> void:
	var scripts: Dictionary = RomCache.read_json(RomCache.world_scripts_path(Fixture.directory()))
	scripts[Gen2WorldScript.pointer_key(Fixture.BANK, 0x6300)] = [
		0x1C, 0x0B, 0x06, 1, 0x10, 0x63, 0x91,
	]
	scripts[Gen2WorldScript.pointer_key(Fixture.BANK, 0x6310)] = [
		0x2B, Gen2WorldPhoneHost.TIME_MORNING, 0x09, 0x20, 0x63, 0x91,
	]
	scripts[Gen2WorldScript.pointer_key(Fixture.BANK, 0x6320)] = [
		0x94, Gen2WorldMartHost.MARTTYPE_BARGAIN, 0x00, 0x40, 0x91,
	]
	RomCache.write_json(RomCache.world_scripts_path(Fixture.directory()), scripts)
	_data = GameData.open_directory(Fixture.directory())


## `special SelectApricornForKurt` behind a coord event, over a bag holding
## whichever apricorns the case needs.
func _set_apricorn_script(items: Dictionary) -> void:
	var scripts: Dictionary = RomCache.read_json(RomCache.world_scripts_path(Fixture.directory()))
	scripts[Gen2WorldScript.pointer_key(Fixture.BANK, 0x6300)] = [
		Gen2WorldScript.SPECIAL,
		Gen2WorldScriptRunner.SPECIAL_SELECT_APRICORN_FOR_KURT, 0x00,
		Gen2WorldScript.END,
	]
	RomCache.write_json(RomCache.world_scripts_path(Fixture.directory()), scripts)
	var maps: Array = RomCache.read_json(RomCache.world_maps_path(Fixture.directory()))
	for raw: Dictionary in maps:
		if int(raw.get("group", -1)) != Fixture.MAP_GROUP \
		or int(raw.get("number", -1)) != Fixture.MAP_NUMBER:
			continue
		var events: Dictionary = raw.get("events", {})
		events["coord_events"] = [{"x": 7, "y": 6, "script": 0x6300}]
		raw["events"] = events
	RomCache.write_json(RomCache.world_maps_path(Fixture.directory()), maps)
	_data = GameData.open_directory(Fixture.directory())
	_world = Gen2WorldAPI.open(
		_data, Fixture.MAP_GROUP, Fixture.MAP_NUMBER, Vector2i(7, 6),
		Gen2WorldState.new({}, {}, items)
	)
	_save = Gen2SaveStore.create_development_save(_data, 0)
	_save.world = _world.snapshot()


func _open_apricorn_request() -> Dictionary:
	var waiting: Array = _world.dispatch_script_events(Vector2i(7, 6))
	assert_eq(waiting[0]["status"], &"waiting", JSON.stringify(waiting))
	return _world.pending_runtime_request()


func test_kurts_special_stages_a_request_carrying_the_bag_list() -> void:
	_set_apricorn_script({APRICORN_RED: 4, APRICORN_PNK: 2, 7: 1})
	var request: Dictionary = _open_apricorn_request()
	assert_eq(request["kind"], &"apricorn_selection_requested")

	var resolved: Dictionary = Gen2WorldHost.resolve_runtime_request(_world)
	assert_true(resolved["ok"], JSON.stringify(resolved))
	var apricorns: Array = resolved["data"]["apricorns"]
	assert_eq(apricorns.size(), 2)
	assert_eq(apricorns[0]["item"], APRICORN_RED)
	assert_eq(apricorns[0]["quantity"], 4)
	assert_eq(apricorns[1]["item"], APRICORN_PNK)


func test_giving_kurt_apricorns_takes_them_and_commits_the_quantity() -> void:
	_set_apricorn_script({APRICORN_RED: 4})
	assert_eq(_open_apricorn_request()["kind"], &"apricorn_selection_requested")

	var completed: Dictionary = Gen2WorldHost.complete_runtime_request(
		_world, {"ok": true, "item": APRICORN_RED, "quantity": 3}, _save, false
	)
	assert_true(completed["ok"], JSON.stringify(completed))
	assert_eq(completed["results"][0]["status"], &"complete")
	assert_eq(_world.state.item_quantity(APRICORN_RED), 1)
	assert_eq(_world.state.kurt_apricorn_quantity(), 3)
	assert_eq(_save.world.world_state.item_quantity(APRICORN_RED), 1)
	assert_eq(_save.world.world_state.kurt_apricorn_quantity(), 3)


func test_backing_out_of_kurts_selection_answers_zero_and_takes_nothing() -> void:
	_set_apricorn_script({APRICORN_RED: 4})
	assert_eq(_open_apricorn_request()["kind"], &"apricorn_selection_requested")

	var completed: Dictionary = Gen2WorldHost.complete_runtime_request(
		_world, {"ok": true, "item": 0, "quantity": 0}, _save, false
	)
	assert_true(completed["ok"], JSON.stringify(completed))
	assert_eq(_world.state.item_quantity(APRICORN_RED), 4)
	assert_eq(_world.state.kurt_apricorn_quantity(), 0)


func test_kurts_host_refuses_more_apricorns_than_the_bag_holds() -> void:
	_set_apricorn_script({APRICORN_RED: 2})
	assert_eq(_open_apricorn_request()["kind"], &"apricorn_selection_requested")

	var completed: Dictionary = Gen2WorldHost.complete_runtime_request(
		_world, {"ok": true, "item": APRICORN_RED, "quantity": 3}, _save, false
	)
	assert_false(completed["ok"], JSON.stringify(completed))
	assert_eq(completed["reason"], &"invalid_apricorn_quantity")
	assert_eq(_world.state.item_quantity(APRICORN_RED), 2)
	assert_eq(_world.pending_runtime_request()["kind"], &"apricorn_selection_requested")


## The committed byte is what a later day's `verbosegiveitemvar BALL,
## VAR_KURT_APRICORNS` sizes the ball stack from, in its own invocation.
func test_the_saved_quantity_sizes_a_later_verbosegiveitemvar() -> void:
	_set_apricorn_script({APRICORN_RED: 4})
	assert_eq(_open_apricorn_request()["kind"], &"apricorn_selection_requested")
	var completed: Dictionary = Gen2WorldHost.complete_runtime_request(
		_world, {"ok": true, "item": APRICORN_RED, "quantity": 3}, _save, false
	)
	assert_true(completed["ok"], JSON.stringify(completed))

	var scripts: Dictionary = RomCache.read_json(RomCache.world_scripts_path(Fixture.directory()))
	scripts[Gen2WorldScript.pointer_key(Fixture.BANK, 0x6400)] = [
		0x9F, BALL_LEVEL, 0x16, Gen2WorldScript.END,
	]
	RomCache.write_json(RomCache.world_scripts_path(Fixture.directory()), scripts)
	var later := Gen2WorldScriptRunner.begin(
		GameData.open_directory(Fixture.directory()), _world.state,
		{"kind": &"test", "bank": Fixture.BANK, "script": 0x6400}
	)
	## GiveItemScript's received line, its sound and its `itemnotify` box, which
	## every verbose give ends on.
	var result: Dictionary = later.advance()
	assert_eq(result["status"], &"waiting", JSON.stringify(result))
	var sounded: Dictionary = later.advance(true)
	assert_eq(
		StringName(sounded["event"]["request"]["kind"]), &"audio_requested",
		JSON.stringify(sounded)
	)
	assert_eq(
		later.complete_runtime_request({"ok": true})["status"], &"waiting"
	)
	assert_eq(later.advance(true)["status"], &"complete")
	assert_eq(_world.state.item_quantity(BALL_LEVEL), 3)


func _write_menu_script() -> void:
	var scripts: Dictionary = RomCache.read_json(RomCache.world_scripts_path(Fixture.directory()))
	scripts[Gen2WorldScript.pointer_key(Fixture.BANK, 0x6310)] = [0x4F, 0x34, 0x12, 0x59, 0x91]
	RomCache.write_json(RomCache.world_scripts_path(Fixture.directory()), scripts)
	RomCache.write_json(RomCache.world_menus_path(Fixture.directory()), {
		Gen2WorldScript.pointer_key(Fixture.BANK, 0x1234): {
			"bank": Fixture.BANK, "address": 0x1234, "options": ["YES", "NO"],
		},
	})
	_data = GameData.open_directory(Fixture.directory())


## `CheckOwnMon`'s OT test walks `NAME_LENGTH_JAPANESE - 2` bytes and compares
## one more, so a longer name is decided on its first five letters. The
## terminator is one of the five, so a shorter name still has to match whole.
func test_an_ot_name_is_own_on_its_first_five_letters() -> void:
	var player := Gen2SaveData.new()
	player.player_id = 0x1234
	player.player_name = "MICHAEL"
	for row: Array in [
		["MICHAEL", true], ["MICHASHA", true], ["MICHA", true],
		["MICH", false], ["MICKEY", false], ["michael", false],
	]:
		var mon := Gen2SaveMon.new()
		mon.ot_id = player.player_id
		mon.original_trainer = String(row[0])
		assert_eq(
			Gen2WorldScreen._is_own_mon(player, mon), bool(row[1]),
			"OT \"%s\" against MICHAEL" % row[0]
		)
	var stranger := Gen2SaveMon.new()
	stranger.ot_id = 0x1235
	stranger.original_trainer = player.player_name
	assert_false(Gen2WorldScreen._is_own_mon(player, stranger), "the ID is tested too")
