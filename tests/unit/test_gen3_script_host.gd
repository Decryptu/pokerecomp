extends GutTest

func _host(bytes: PackedByteArray, id: StringName = RomRegistry.EMERALD, start_at: int = 1) -> Gen3ScriptHost:
	var data := GameData.new()
	data.id = id
	data.generation = RomRegistry.GEN3
	data._sections = {"headers": true, "scripts": true}
	data._world_headers = {"0:0": {"events": {"objects": []}}}
	var instructions: Dictionary = {}
	var rom := RomFile.from_bytes(bytes, id)
	var at: int = 1
	while at < bytes.size():
		var row: Dictionary = Gen3Script.instruction(rom, at)
		instructions[str(at)] = row
		at = int(row["next_offset"])
	data._world_scripts = {"instructions": instructions,
		"texts": {"64": {"bytes": [0xBB, 0xBC, 0xFF]}},
		"movements": {"64": {"bytes": [0x08, 0x08, 0xFE]}}}
	var movement_types: Array = []
	for type: int in 12:
		movement_types.append({"ranged": false, "facing": 1})
	data._world_scripts["movement_types"] = movement_types
	var camera := Gen3FieldCamera.new()
	camera.data = data
	camera.group = 0
	camera.number = 0
	camera.grid = Gen3MapGrid.new()
	camera.grid.width = 32
	camera.grid.height = 32
	camera.grid.layout_width = 17
	camera.grid.layout_height = 18
	camera.grid.blocks.resize(1024)
	camera.grid.blocks.fill(0x3000)
	camera.grid._behaviors.resize(1024)
	var objects := Gen3ObjectEvents.new(camera, Gen3EventData.new(id))
	var avatar := Gen3PlayerAvatar.open(objects, Vector2i(10, 10), 1, 0)
	var template: Dictionary = Gen3ObjectEvents.EMPTY_TEMPLATE.duplicate()
	template.merge({"local_id": 1, "x": 5, "y": 5}, true)
	objects.spawn(template, 0, 0)
	var host := Gen3ScriptHost.new(avatar)
	if start_at > 0:
		host.start(start_at, 1)
	return host


func test_dialogue_locks_finish_steps_and_release_models_after_button_input() -> void:
	var host: Gen3ScriptHost = _host(PackedByteArray([0,
		0x6A, 0x67, 0x40, 0, 0, 8, 0x66, 0x6D, 0x6C, 2]))
	var npc: Gen3ObjectEvents.ObjectEvent = host.objects.objects[1]
	npc.single_movement_active = true
	host.avatar.tile_state = Gen3PlayerAvatar.Tile.TRANSITION
	assert_eq(host.tick(), [])
	assert_false(npc.frozen)
	host.tick()
	assert_eq(host.context.state, Gen3ScriptContext.State.NATIVE_WAIT)
	npc.single_movement_active = false
	host.avatar.tile_state = Gen3PlayerAvatar.Tile.CENTER
	host.tick()
	assert_true(npc.frozen)
	host.tick()
	var events: Array[Dictionary] = host.tick()
	assert_eq(events[0]["text"], "AB")
	assert_true(host.message_visible)
	assert_true(host.objects.events.controls_locked)
	host.tick(PokeButton.A)
	assert_eq(host.context.state, Gen3ScriptContext.State.NATIVE_WAIT)
	host.finish_message()
	host.tick()
	host.tick(PokeButton.A)
	assert_eq(host.context.state, Gen3ScriptContext.State.NATIVE_WAIT)
	host.tick(PokeButton.UP)
	assert_eq(host.context.state, Gen3ScriptContext.State.NATIVE_WAIT)
	host.tick(PokeButton.B)
	assert_eq(host.tick(), [{"kind": "close_message"}])
	assert_false(npc.frozen)
	assert_false(npc.anim.paused)
	assert_false(host.message_visible)
	assert_false(host.objects.events.controls_locked)


func test_movement_lists_drive_held_actions_and_wait_for_the_last_applied_object() -> void:
	var host: Gen3ScriptHost = _host(PackedByteArray([0,
		0x16, 0, 0x40, 1, 0, 0x4F, 0, 0x40, 0x40, 0, 0, 8,
		0x4F, 1, 0, 0x41, 0, 0, 8, 0x51, 0, 0, 0x29, 1, 0, 0x6C, 2]))
	var npc: Gen3ObjectEvents.ObjectEvent = host.objects.objects[1]
	var initial: Vector2i = npc.current
	host.tick()
	assert_true(npc.held_movement_active)
	assert_false(host.objects.events.flag_get(1))
	var completed_frame: int = 0
	for frame: int in range(1, 41):
		host.step()
		if host.objects.events.flag_get(1) and completed_frame == 0:
			completed_frame = frame
	assert_eq(completed_frame, 35)
	assert_eq(npc.current, initial + Vector2i(0, 2))
	assert_true(host.objects.events.flag_get(1))
	assert_false(npc.frozen)
	assert_eq(host.context.state, Gen3ScriptContext.State.STOPPED)


func test_ruby_explicit_map_movement_alias_and_absent_object_wait() -> void:
	var host: Gen3ScriptHost = _host(PackedByteArray([0,
		0x50, 1, 0, 0x40, 0, 0, 8, 2, 3, 0x52, 1, 0, 2, 3, 2]), RomRegistry.RUBY)
	host.tick()
	host.tick()
	host.tick()
	assert_eq(host.context.state, Gen3ScriptContext.State.STOPPED)
	assert_false(host.objects.objects[1].held_movement_active)


func test_host_faults_synchronously_before_later_bytecode_changes_state() -> void:
	var host: Gen3ScriptHost = _host(PackedByteArray([0, 0x67, 0x41, 0, 0, 8, 0x29, 1, 0, 2]))
	var events: Array[Dictionary] = host.tick()
	assert_eq(events.size(), 1)
	assert_eq(events[0]["reason"], "missing_text")
	assert_false(host.objects.events.flag_get(1))
	assert_false(host.objects.events.controls_locked)


func test_a_busy_message_refuses_replacement_without_reading_the_second_pointer() -> void:
	var host: Gen3ScriptHost = _host(PackedByteArray([0,
		0x67, 0x40, 0, 0, 8, 0x67, 0x41, 0, 0, 8, 0x66, 2]))
	assert_eq(host.tick().size(), 1)
	assert_eq(host.context.state, Gen3ScriptContext.State.NATIVE_WAIT)
	host.finish_message()
	host.tick()
	host.tick()
	assert_eq(host.context.state, Gen3ScriptContext.State.STOPPED)


func test_immediate_map_scripts_keep_the_foreground_context_and_frame_tables_use_shared_vars() -> void:
	var host: Gen3ScriptHost = _host(PackedByteArray([0, 0x28, 3, 0, 2,
		0x16, 0, 0x40, 7, 0, 2, 0x16, 0, 0x40, 8, 0, 2]))
	host.objects.camera.data._world_headers["0:0"]["map_scripts"] = [
		{"type": 1, "script_offset": 5},
		{"type": 2, "conditions": [{"variable": 0x4000, "value": 7, "script_offset": 11}]}]
	host.tick()
	var offset: int = host.context.offset
	assert_eq(host.run_map_script(1), [])
	assert_eq(host.context.offset, offset)
	assert_eq(host.context.state, Gen3ScriptContext.State.DELAY)
	assert_false(host.try_frame_script())
	for frame: int in 4:
		host.tick()
	assert_true(host.try_frame_script())
	host.tick()
	assert_eq(host.objects.events.var_get(0x4000), 8)
	assert_false(host.try_frame_script())


func test_field_steps_preserve_external_control_locks_and_schedule_map_scripts_before_movement() -> void:
	var host: Gen3ScriptHost = _host(PackedByteArray([0, 2, 0x16, 0, 0x40, 1, 0, 2]))
	host.tick()
	host.objects.events.controls_locked = true
	host.step([PokeButton.RIGHT], [PokeButton.RIGHT])
	assert_true(host.objects.events.controls_locked)
	assert_eq(host.avatar.running_state, Gen3PlayerAvatar.Running.NOT_MOVING)
	host.objects.camera.data._world_headers["0:0"]["map_scripts"] = [
		{"type": 2, "conditions": [{"variable": 0x4000, "value": 0, "script_offset": 2}]}]
	host.objects.events.controls_locked = false
	host.step([PokeButton.RIGHT], [PokeButton.RIGHT])
	assert_eq(host.objects.events.var_get(0x4000), 1)
	assert_eq(host.avatar.running_state, Gen3PlayerAvatar.Running.NOT_MOVING)
	host.step([PokeButton.RIGHT], [PokeButton.RIGHT])
	assert_eq(host.avatar.object().facing, Gen3ObjectEvents.Direction.EAST)


func test_a_button_starts_the_npc_script_across_a_counter_and_faces_the_player() -> void:
	var host: Gen3ScriptHost = _host(PackedByteArray([0,
		0x6A, 0x5A, 0x67, 0x40, 0, 0, 8, 0x66, 0x6D, 0x6C, 2]), RomRegistry.EMERALD, 0)
	var npc: Gen3ObjectEvents.ObjectEvent = host.objects.objects[1]
	Gen3ObjectEvents.move_to_map_coords(npc, host.avatar.object().current + Vector2i(0, 2))
	var template: Dictionary = Gen3ObjectEvents.EMPTY_TEMPLATE.duplicate()
	template.merge({"local_id": 1, "script_offset": 1}, true)
	host.objects.templates.append(template)
	var front: Vector2i = host.avatar.object().current + Vector2i(0, 1)
	host.objects.camera.grid.blocks[front.y * 32 + front.x] = 0x3001
	host.objects.camera.grid._behaviors[1] = 0x80
	host.step([], [PokeButton.A])
	assert_eq(host.selected_slot, 1)
	assert_eq(host.objects.events.var_get(0x800F), 1)
	assert_eq(host.objects.events.var_get(0x800C), Gen3ObjectEvents.Direction.SOUTH)
	var messages: Array = []
	for frame: int in 3:
		messages.append_array(host.step())
	assert_true(messages.any(func(event: Dictionary) -> bool: return event["kind"] == "message"))
	assert_eq(npc.facing, Gen3ObjectEvents.Direction.NORTH)
	host.finish_message()
	host.step()
	host.step()
	host.step([], [PokeButton.A])
	host.step()
	assert_eq(host.context.state, Gen3ScriptContext.State.STOPPED)
	assert_false(host.objects.events.controls_locked)


func test_coordinate_events_run_on_arrival_in_order_before_the_next_step() -> void:
	var host: Gen3ScriptHost = _host(PackedByteArray([0,
		0x16, 0, 0x40, 7, 0, 2, 0x29, 1, 0, 2]), RomRegistry.EMERALD, 0)
	host.objects.camera.data._world_headers["0:0"]["events"]["coords"] = [
		{"x": 3, "y": 4, "elevation": 4, "variable": 0x4000, "value": 0, "script_offset": 7},
		{"x": 3, "y": 4, "elevation": 0, "variable": 7, "value": 0, "script_offset": 0},
		{"x": 3, "y": 4, "elevation": 0, "variable": 0, "value": 0, "script_offset": 1},
		{"x": 3, "y": 4, "elevation": 0, "variable": 0x4000, "value": 0x107, "script_offset": 7}]
	var output: Array = []
	for frame: int in 40:
		output.append_array(host.step([PokeButton.DOWN]))
		if host.objects.events.flag_get(1):
			break
	assert_true(host.objects.events.flag_get(1))
	assert_eq(host.objects.events.var_get(0x4000), 7)
	assert_eq(host.avatar.object().current, Vector2i(10, 11))
	assert_true(output.has({"kind": "weather", "weather": 9}))


func test_background_events_use_original_front_cell_and_first_matching_elevation() -> void:
	var host: Gen3ScriptHost = _host(PackedByteArray([0, 0x29, 2, 0, 2]), RomRegistry.FIRERED, 0)
	host.objects.camera.data._world_headers["0:0"]["events"]["backgrounds"] = [
		{"x": 3, "y": 4, "elevation": 4, "kind": 0, "script_offset": 1},
		{"x": 3, "y": 4, "elevation": 0, "kind": 1, "script_offset": 1},
		{"x": 3, "y": 4, "elevation": 0, "kind": 0, "script_offset": 1}]
	assert_false(host.interact())
	host.objects.camera.data._world_headers["0:0"]["events"]["backgrounds"][1]["kind"] = 2
	var front: Vector2i = host.avatar.object().current + Vector2i.DOWN
	host.objects.camera.grid.blocks[front.y * 32 + front.x] = 0x3001
	host.objects.camera.grid._behaviors[1] = 0x80
	host.step([], [PokeButton.A])
	assert_true(host.objects.events.flag_get(2))
	assert_eq(host.selected_slot, -1)
	assert_eq(host.objects.events.var_get(0x800F), 0)
	assert_eq(host.objects.events.var_get(0x800C), Gen3ObjectEvents.Direction.SOUTH)
	host.objects.events.controls_locked = false
	host.objects.camera.data._world_scripts["native"] = {"test_signpost": 1}
	host.objects.camera.data._world_headers["0:0"]["events"]["backgrounds"] = [
		{"x": 3, "y": 4, "elevation": 0, "kind": 0, "script_offset": 0}]
	assert_true(host.interact(), "a null script runs EventScript_TestSignpostMsg")


func _field_host(id: StringName, natives: Dictionary = {}) -> Gen3ScriptHost:
	var host: Gen3ScriptHost = _host(PackedByteArray([0, 0x27, 2]), id, 0)
	host.objects.camera.data._world_scripts["native"] = natives
	host.objects.camera.header = host.objects.camera.data._world_headers["0:0"]
	return host


func _set_cell(host: Gen3ScriptHost, at: Vector2i, behavior: int) -> void:
	host.objects.camera.grid.blocks[at.y * 32 + at.x] = 0x3001
	host.objects.camera.grid._behaviors[1] = behavior


func _walk_onto(host: Gen3ScriptHost, behavior: int) -> Array:
	_set_cell(host, host.avatar.object().current + Vector2i.DOWN, behavior)
	var output: Array = []
	for frame: int in 24:
		output.append_array(host.step([PokeButton.DOWN]))
		if host.warp_pending or host.context.state != Gen3ScriptContext.State.STOPPED:
			break
	return output


func test_hidden_items_read_each_engines_packing_and_a_taken_item_is_not_a_script() -> void:
	var host: Gen3ScriptHost = _field_host(RomRegistry.EMERALD, {"hidden_item": 1})
	var row: Dictionary = {"x": 3, "y": 4, "elevation": 0, "kind": 7, "item": 13, "hidden_item_id": 2}
	host.objects.camera.data._world_headers["0:0"]["events"]["backgrounds"] = [row]
	assert_true(host.interact())
	assert_eq(host.objects.events.var_get(0x8004), 0x1F6)
	assert_eq(host.objects.events.var_get(0x8005), 13)
	host.objects.events.controls_locked = false
	host._field_special("SetHiddenItemFlag")
	assert_false(host.interact())
	var frlg: Gen3ScriptHost = _field_host(RomRegistry.FIRERED, {"hidden_item": 1})
	row.merge({"quantity": 3, "underfoot": false}, true)
	frlg.objects.camera.data._world_headers["0:0"]["events"]["backgrounds"] = [row]
	assert_true(frlg.interact())
	assert_eq(frlg.objects.events.var_get(0x8004), 0x3EA)
	assert_eq(frlg.objects.events.var_get(0x8006), 3)


func test_metatiles_answer_by_engine_and_only_the_pcs_are_silent() -> void:
	var host: Gen3ScriptHost = _field_host(RomRegistry.EMERALD, {"pc": 1, "tv": 1, "region_map": 1})
	var front: Vector2i = host.avatar.object().current + Vector2i.DOWN
	_set_cell(host, front, 0x86)
	assert_false(host.interact(), "a television only answers from the south")
	var requests: Array = []
	_set_cell(host, front, 0x83)
	assert_true(host.interact(requests))
	assert_eq(requests, [])
	host.objects.events.controls_locked = false
	_set_cell(host, front, 0x85)
	assert_true(host.interact(requests))
	assert_eq(requests, [{"kind": "sound", "name": "select"}])
	var frlg: Gen3ScriptHost = _field_host(RomRegistry.FIRERED, {"book_shelf": 1})
	_set_cell(frlg, frlg.avatar.object().current + Vector2i.DOWN, 0x81)
	assert_true(frlg.interact(), "0x81 is an unused row in Hoenn and FireRed's bookshelf")


func test_surf_and_waterfall_prompts_need_the_move_and_their_engines_badge() -> void:
	var host: Gen3ScriptHost = _field_host(RomRegistry.FIRERED, {"cannot_use_waterfall": 1, "current_too_fast": 1})
	var front: Vector2i = host.avatar.object().current + Vector2i.DOWN
	_set_cell(host, front, 0x13)
	assert_true(host.interact())
	assert_eq(host.context.offset, 1)
	host.objects.events.controls_locked = false
	_set_cell(host, front, 0x11)
	assert_false(host.interact())
	host.objects.events.party = [{"species": 1, "nickname": "A", "moves": [57], "egg": false, "hp": 1}]
	assert_true(host.interact())


func test_step_warp_tiles_take_each_engines_presentation() -> void:
	for row: Array in [[RomRegistry.EMERALD, 0x67, "teleport"], [RomRegistry.EMERALD, 0x0E, "mossdeep_gym"],
			[RomRegistry.RUBY, 0x29, "lavaridge_b1f"], [RomRegistry.FIRERED, 0x67, "teleport"]]:
		var host: Gen3ScriptHost = _field_host(row[0])
		_warp_map(host)
		var cell: Vector2i = host.avatar.object().current + Vector2i.DOWN - Vector2i.ONE * 7
		host.objects.camera.data._world_headers["0:0"]["events"]["warps"] = [
			{"x": cell.x, "y": cell.y, "elevation": 0, "group": 0, "number": 1, "warp_id": 0}]
		var output: Array = _walk_onto(host, row[1])
		assert_true(host.warp_pending, "%s %x" % [row[0], row[1]])
		assert_true(output.any(func(event: Dictionary) -> bool: return event["kind"] == "warp" and event["mode"] == row[2]))


func test_a_hole_starts_its_script_after_setup_and_an_ordinary_floor_hole_needs_no_warp_row() -> void:
	var host: Gen3ScriptHost = _field_host(RomRegistry.FIRERED, {"fall_warp": 1})
	_warp_map(host)
	var cell: Vector2i = host.avatar.object().current + Vector2i.DOWN - Vector2i.ONE * 7
	host.objects.camera.data._world_headers["0:0"]["events"]["warps"] = [
		{"x": cell.x, "y": cell.y, "elevation": 0, "group": 0, "number": 1, "warp_id": 0}]
	_walk_onto(host, 0x66)
	assert_false(host.warp_pending)
	assert_eq(host.warps.destination["number"], 1)
	assert_eq(host.objects.events.stats[Gen3FieldInput.GAME_STAT_STEPS], 1)
	var hoenn: Gen3ScriptHost = _field_host(RomRegistry.RUBY, {"fall_down_hole": 1})
	_walk_onto(hoenn, 0x66)
	assert_true(hoenn.objects.events.controls_locked)


func test_directional_stairs_warp_on_foot_with_the_bike_delay() -> void:
	var host: Gen3ScriptHost = _field_host(RomRegistry.FIRERED)
	_warp_map(host)
	var player: Gen3ObjectEvents.ObjectEvent = host.avatar.object()
	Gen3ObjectEvents.set_direction(player, Gen3ObjectEvents.Direction.EAST)
	var cell: Vector2i = player.current - Vector2i.ONE * 7
	host.objects.camera.data._world_headers["0:0"]["events"]["warps"] = [
		{"x": cell.x, "y": cell.y, "elevation": 0, "group": 0, "number": 1, "warp_id": 0}]
	_set_cell(host, player.current, 0x6C)
	host.avatar.flags = Gen3PlayerAvatar.Flag.MACH_BIKE
	var requests: Array = host.step([PokeButton.RIGHT])
	var warp: Array = requests.filter(func(event: Dictionary) -> bool: return event["kind"] == "warp")
	assert_eq(warp[0]["mode"], "stairs")
	assert_eq(warp[0]["delay"], 12)
	assert_true(host.avatar.flags & Gen3PlayerAvatar.Flag.ON_FOOT != 0)


func test_step_counters_end_repel_and_poison_each_engines_period() -> void:
	var host: Gen3ScriptHost = _field_host(RomRegistry.FIRERED, {"repel_wore_off": 1, "field_poison": 1})
	var events: Gen3EventData = host.objects.events
	events.party = [{"species": 1, "nickname": "A", "moves": [], "egg": false, "hp": 1, "status": 8}]
	events.var_set(0x4020, 1)
	var requests: Array = []
	host._on_step(requests)
	assert_eq(events.var_get(0x4020), 0)
	assert_eq(host.context.offset, 1, "the repel script")
	assert_eq(requests, [])
	for step: int in 3:
		host._on_step(requests)
	assert_eq(int(events.party[0]["hp"]), 1, "FireRed's poison ticks every fifth step")
	host.context.offset = -1
	host._on_step(requests)
	assert_eq(int(events.party[0]["hp"]), 0)
	assert_eq(requests, [{"kind": "poison_flash"}])
	assert_eq(host.context.offset, 1, "the poison script")
	host._executing = host.context
	host._field_poison_white_out()
	assert_eq(events.var_get(Gen3ScriptServices.VAR_RESULT), 1)
	assert_eq(int(events.party[0]["status"]), 0)


func test_diving_needs_its_badge_and_prefers_a_connection_to_the_map_script() -> void:
	var host: Gen3ScriptHost = _field_host(RomRegistry.EMERALD, {"use_dive": 1})
	_warp_map(host)
	var player: Gen3ObjectEvents.ObjectEvent = host.avatar.object()
	_set_cell(host, player.current, 0x12)
	host.objects.camera.header["connections"] = [{"direction": Gen3FieldInput.CONNECTION_DIVE, "group": 0, "number": 1, "offset": 0}]
	host.step([], [PokeButton.A])
	assert_eq(host.context.state, Gen3ScriptContext.State.STOPPED)
	host.objects.events.controls_locked = false
	host.objects.events.flag_set(host.input.flags["dive"])
	host.step([], [PokeButton.A])
	assert_true(host.objects.events.controls_locked)
	assert_eq(host.warps.destination["number"], 1)
	var requests: Array[Dictionary] = host.finish_dive()
	assert_eq(requests[0]["mode"], "dive")


func test_a_transition_script_swaps_the_layout_the_grid_is_built_from() -> void:
	var host: Gen3ScriptHost = _host(PackedByteArray([0, 0xA7, 2, 0, 2]), RomRegistry.EMERALD, 0)
	_warp_map(host)
	var data: GameData = host.objects.camera.data
	var blocks := PackedByteArray()
	blocks.resize(32)
	data._world_tilesets["layouts"]["7"] = {"blocks": {"bytes": blocks}, "border": {"bytes": blocks.slice(0, 8)}}
	data._world_tilesets["layout_table"] = [{}, {"width": 2, "height": 8, "border_width": 2, "border_height": 2,
		"layout_offset": 7, "primary_tileset_offset": 1, "secondary_tileset_offset": 2}]
	data._world_headers["0:1"]["map_scripts"] = [{"type": 3, "script_offset": 1}]
	host.warps.destination = Gen3Warp.record(0, 1, -1, 1, 1)
	host._begin_warp("warp", true)
	host.complete_warp()
	assert_eq(host.objects.camera.grid.layout_width, 2)
	assert_eq(int(host.objects.camera.header["layout_id"]), 2)


func test_firered_signs_read_on_walking_in_and_walking_away_cancels_them() -> void:
	var host: Gen3ScriptHost = _field_host(RomRegistry.FIRERED, {"pokecenter_sign": 1, "cancel_message_box": 1})
	var player: Gen3ObjectEvents.ObjectEvent = host.avatar.object()
	Gen3ObjectEvents.set_direction(player, Gen3ObjectEvents.Direction.NORTH)
	_set_cell(host, player.current + Vector2i.UP, 0x87)
	var requests: Array = host.step([PokeButton.UP])
	assert_true(host.signpost)
	assert_true(host.objects.events.controls_locked)
	host.context.state = Gen3ScriptContext.State.NATIVE_WAIT
	host._sign_inhibit = 0
	host.objects.camera.data._world_scripts["native"]["cancel_message_box"] = 1
	var cancel: int = host.context.offset
	host.step([PokeButton.LEFT])
	assert_eq(host.context.offset, cancel, "the cancel script restarts the context")
	assert_false(host._sign_cancelable)


func test_start_and_a_registered_item_lock_the_field_until_the_menu_returns_it() -> void:
	var host: Gen3ScriptHost = _field_host(RomRegistry.EMERALD, {"select_without_item": 1})
	assert_true(host.step([], [PokeButton.START]).has({"kind": "start_menu"}))
	assert_true(host.objects.events.controls_locked)
	host.end_field_menu()
	host.objects.events.registered_item = 13
	host.step([], [PokeButton.SELECT])
	assert_eq(host.objects.events.registered_item, 0, "an item no longer in the bag unregisters")
	assert_true(host.objects.events.controls_locked)


func _warp_map(host: Gen3ScriptHost) -> void:
	var data: GameData = host.objects.camera.data
	data._sections["gba_graphics"] = true
	data._world_headers["0:1"] = {"width": 8, "height": 8, "border_width": 2, "border_height": 2,
		"layout_id": 1, "layout_offset": 1, "primary_tileset_offset": 1, "secondary_tileset_offset": 2,
		"events": {"objects": [], "warps": [{"x": 2, "y": 3, "elevation": 0, "group": 0, "number": 0x7F, "warp_id": 0}]}}
	var blocks := PackedByteArray()
	blocks.resize(128)
	for index: int in 64:
		blocks.encode_u16(index * 2, 0x3000)
	var empty_tileset: Dictionary = {"metatile_tail": {"bytes": PackedByteArray()},
		"attribute_tail": {"bytes": PackedByteArray()}, "attribute_size": 2}
	data._world_tilesets = {"layouts": {"1": {"blocks": {"bytes": blocks}, "border": {"bytes": blocks.slice(0, 8)}}},
		"tilesets": {"1": empty_tileset, "2": empty_tileset}}


func test_script_warp_yields_then_loads_the_destination_and_replaces_the_old_context() -> void:
	var host: Gen3ScriptHost = _host(PackedByteArray([0,
		0x39, 0, 1, 0, 0, 0x40, 0, 0x40, 0x29, 9, 0, 2,
		0x16, 0, 0x40, 2, 0, 0x63, 1, 0, 4, 0, 5, 0, 0x65, 1, 0, 5, 2,
		0xA2, 1, 0, 2, 0, 5, 0, 1, 0, 0x17, 0, 0x40, 1, 0, 2]))
	_warp_map(host)
	var template: Dictionary = Gen3ObjectEvents.EMPTY_TEMPLATE.duplicate()
	template["local_id"] = 1
	host.objects.camera.data._world_headers["0:1"]["events"]["objects"] = [template]
	host.objects.events.var_set(0x4000, 99)
	host.objects.camera.data._world_headers["0:1"]["map_scripts"] = [
		{"type": 3, "script_offset": 13}, {"type": 1, "script_offset": 30}]
	var requests: Array[Dictionary] = host.tick()
	assert_eq(requests[0]["kind"], "warp")
	assert_eq(requests[0]["destination"]["x"], 99)
	assert_false(host.objects.events.flag_get(9))
	assert_true(host.warp_pending)
	assert_true(host.objects.events.controls_locked)
	assert_eq(host.tick(), [])
	assert_false(host.objects.events.flag_get(9))
	var old_objects: WeakRef = weakref(host.objects)
	var old_avatar: WeakRef = weakref(host.avatar)
	host.objects.fly.fly_out(host.avatar, 1, 0, 0, 0)
	var loaded: Array[Dictionary] = host.complete_warp()
	assert_null(old_objects.get_ref())
	assert_null(old_avatar.get_ref())
	assert_eq(loaded.back(), {"kind": "map_loaded", "group": 0, "number": 1, "position": Vector2i(2, 3)})
	assert_eq(host.avatar.object().current, Vector2i(9, 10))
	assert_eq(host.objects.events.var_get(0x4000), 3)
	var npc: Gen3ObjectEvents.ObjectEvent = host.objects.by_identity(1, 1, 0)
	assert_eq(npc.current, Vector2i(11, 12))
	assert_eq(npc.movement_type, 5)
	assert_eq(host.objects.camera.grid.block_at(8, 9), 0x3C05)
	assert_eq(host.context.state, Gen3ScriptContext.State.STOPPED)
	assert_false(host.objects.events.flag_get(9))
	assert_false(host.objects.events.controls_locked)
	assert_false(host.warp_pending)


func test_door_input_uses_dynamic_return_and_ignores_a_warp_on_ordinary_ground() -> void:
	var host: Gen3ScriptHost = _host(PackedByteArray([0, 2]), RomRegistry.EMERALD, 0)
	_warp_map(host)
	host.objects.camera.data._world_headers["0:0"]["events"]["warps"] = [
		{"x": 3, "y": 2, "elevation": 0, "group": 0, "number": 1, "warp_id": 0}]
	Gen3ObjectEvents.set_direction(host.avatar.object(), Gen3ObjectEvents.Direction.NORTH)
	var door: Vector2i = host.avatar.object().current + Vector2i.UP
	host.objects.camera.grid.blocks[door.y * 32 + door.x] = 0x3001
	host.objects.camera.grid._behaviors[1] = 0x69
	var requests: Array = host.step([PokeButton.UP])
	assert_true(requests.any(func(event: Dictionary) -> bool: return event["kind"] == "warp" and event["mode"] == "door"))
	assert_eq(host.warps.dynamic["warp_id"], 0)
	host.complete_warp()
	assert_eq(host.avatar.object().facing, Gen3ObjectEvents.Direction.SOUTH)
	assert_false(host.warps.from_event(host.objects.camera.data, 0, 1, 1, Vector2i(2, 3)))
	assert_true(host.warps.from_event(host.objects.camera.data, 0, 1, 0, Vector2i(2, 3)))
	assert_eq(host.warps.destination["number"], 0)
	assert_eq(host.warps.position(host.objects.camera.data), Vector2i(3, 2))
	assert_false(host.warp_pending)
	host.step([PokeButton.UP])
	assert_false(host.warp_pending)


func test_object_commands_keep_live_movement_and_saved_templates_separate() -> void:
	var host: Gen3ScriptHost = _host(PackedByteArray([0,
		0x57, 1, 0, 6, 0, 7, 0, 0x64, 1, 0, 0x53, 1, 0,
		0x55, 1, 0, 0x59, 1, 0, 0, 0, 2]))
	var template: Dictionary = Gen3ObjectEvents.EMPTY_TEMPLATE.duplicate()
	template.merge({"local_id": 1, "x": 5, "y": 5, "flag": 100}, true)
	host.objects.templates.append(template)
	var old_object: Gen3ObjectEvents.ObjectEvent = host.objects.by_identity(1, 0, 0)
	assert_eq(host.tick(), [])
	var npc: Gen3ObjectEvents.ObjectEvent = host.objects.by_identity(1, 0, 0)
	assert_false(old_object.active)
	assert_eq(npc.current, Vector2i(13, 14))
	assert_true(npc.invisible)
	assert_true(host.objects.events.flag_get(100))
	assert_eq(host.objects.template_by_id(1, 0, 0)["x"], 6)


func _op(name: String) -> int:
	for opcode: int in Gen3Script.COMMANDS.size():
		if Gen3Script.COMMANDS[opcode].begins_with(name + ":"):
			return opcode
	return -1


func _services_host(bytes: PackedByteArray, data_rows: Dictionary = {}) -> Gen3ScriptHost:
	var host: Gen3ScriptHost = _host(bytes, RomRegistry.EMERALD, 0)
	var data: GameData = host.objects.camera.data
	data._items = [{"number": 1, "name": "POTION", "pocket": 1}]
	data._world_scripts.merge({"std_strings": ["ITEMS"], "multichoice": [["ONE", "TWO"]]})
	data._world_scripts.merge(data_rows, true)
	host.start(1, 1)
	return host


func test_item_and_string_commands_fill_the_results_a_message_expands() -> void:
	var host: Gen3ScriptHost = _services_host(PackedByteArray([0,
		_op("additem"), 1, 0, 2, 0, _op("bufferitemname"), 1, 1, 0, _op("bufferstdstring"), 2, 0, 0,
		_op("message"), 0x40, 0, 0, 8, 2]), {"texts": {"64": {"bytes": [0xFD, 3, 0, 0xFD, 4, 0xFF]}}})
	var events: Array[Dictionary] = host.tick()
	assert_eq(host.objects.events.var_get(Gen3ScriptServices.VAR_RESULT), 1)
	assert_true(host.objects.events.bag.has(1, 2))
	assert_eq(events[0]["text"], "POTION ITEMS")


func test_bag_rules_follow_each_engine_and_refuse_an_overflow_whole() -> void:
	var data := GameData.new()
	data.generation = RomRegistry.GEN3
	data._items = [{"number": 1, "pocket": 1}, {"number": 2, "pocket": 4}, {"number": 3, "pocket": 5}]
	var split := Gen3Bag.new(data, Gen3EventData.new(RomRegistry.EMERALD))
	assert_true(split.add(1, 90))
	assert_true(split.add(1, 20))
	assert_true(split.has(1, 110))
	assert_true(split.add(2, 99))
	assert_false(split.add(2, 1))
	assert_false(split.has_space(2, 1))
	assert_true(split.remove(1, 100))
	assert_false(split.has(1, 11))
	var events := Gen3EventData.new(RomRegistry.FIRERED)
	var one_stack := Gen3Bag.new(data, events)
	assert_true(one_stack.add(1, 500))
	assert_false(one_stack.add(1, 500))
	assert_true(one_stack.has(1, 500))
	assert_true(one_stack.add(3, 1))
	assert_true(events.flag_get(Gen3Bag.GOT_BERRY_POUCH_FLAG))


func test_a_menu_stops_the_script_until_the_answer_lands_in_var_result() -> void:
	var host: Gen3ScriptHost = _services_host(PackedByteArray([0, _op("multichoice"), 1, 2, 0, 0,
		_op("compare_var_to_value"), 0x0D, 0x80, 1, 0, 2]))
	assert_eq(host.tick(), [{"kind": "menu", "left": 1, "top": 2, "choices": ["ONE", "TWO"], "default": 0,
		"columns": 1, "ignore_b": false}])
	assert_eq(host.objects.events.var_get(Gen3ScriptServices.VAR_RESULT), 0xFF)
	host.tick()
	assert_eq(host.context.state, Gen3ScriptContext.State.WAITING)
	host.choose(1)
	host.tick()
	assert_eq(host.context.state, Gen3ScriptContext.State.STOPPED)
	assert_eq(host.context.comparison, 1)


func test_presentation_reads_vars_and_a_host_wait_lasts_until_the_screen_finishes() -> void:
	var host: Gen3ScriptHost = _services_host(PackedByteArray([0, 0x16, 0, 0x40, 9, 0,
		_op("playmoncry"), 0, 0x40, 2, 0, _op("waitse"), _op("setflag"), 1, 0, 2]))
	assert_eq(host.tick(), [{"kind": "playmoncry", "operands": [9, 2]}, {"kind": "waitse", "operands": []}])
	host.tick()
	assert_false(host.objects.events.flag_get(1))
	host.finish_wait()
	host.tick()
	host.tick()
	assert_true(host.objects.events.flag_get(1))


## A talked-to trainer: the mode's words after `trainerbattle`, then `dotrainerbattle` and `gotobeatenscript` as its
## battle script, and `setflag 2`, `end` as what either return path reaches.
func _trainer_host(mode: int, words: Array) -> Gen3ScriptHost:
	var bytes := PackedByteArray([0, 0x5C, mode, 7, 0, 1, 0])
	for word: int in words:
		bytes.resize(bytes.size() + 4)
		bytes.encode_u32(bytes.size() - 4, word)
	var battle_at: int = bytes.size()
	bytes.append_array([_op("dotrainerbattle"), _op("gotobeatenscript"), _op("setflag"), 2, 0, 2])
	return _services_host(bytes, {"trainer_battle": [battle_at, 0, 0, 0, 0]})


func test_a_won_battle_marks_the_trainer_and_runs_the_beaten_path() -> void:
	var host: Gen3ScriptHost = _trainer_host(0, [0x08000040, 0x08000040])
	var events: Array[Dictionary] = host.tick()
	assert_eq(events[0]["kind"], "trainer_battle")
	assert_eq(events[0]["opponent_a"], 7)
	assert_eq(host.selected_slot, 1)
	assert_eq(host.finish_battle(Gen3TrainerBattle.Outcome.WON), [])
	host.tick()
	assert_true(host.objects.events.flag_get(Gen3TrainerBattle.TRAINER_FLAGS_START + 7))
	assert_eq(host.context.state, Gen3ScriptContext.State.STOPPED)
	assert_false(host.objects.events.flag_get(2))


func test_a_lost_battle_whites_out_and_a_continuation_returns_to_its_script() -> void:
	var lost: Gen3ScriptHost = _trainer_host(0, [0x08000040, 0x08000040])
	lost.tick()
	assert_eq(lost.finish_battle(Gen3TrainerBattle.Outcome.LOST), [{"kind": "white_out"}])
	assert_false(lost.objects.events.flag_get(Gen3TrainerBattle.TRAINER_FLAGS_START + 7))
	var won: Gen3ScriptHost = _trainer_host(2, [0x08000040, 0x08000040, 0x08000000 + 21])
	won.tick()
	won.finish_battle(Gen3TrainerBattle.Outcome.WON)
	won.tick()
	assert_true(won.objects.events.flag_get(2))


func test_a_trainer_that_sees_the_player_starts_its_approach_with_the_battle_configured() -> void:
	var bytes := PackedByteArray([0, 0x5C, 0, 7, 0, 0, 0, 0x40, 0, 0, 8, 0x40, 0, 0, 8, 2,
		_op("selectapproachingtrainer"), 2])
	var host: Gen3ScriptHost = _host(bytes, RomRegistry.EMERALD, 0)
	host.objects.camera.data._world_scripts["native"] = {"trainer_approach": 16}
	var template: Dictionary = Gen3ObjectEvents.EMPTY_TEMPLATE.duplicate()
	template.merge({"local_id": 2, "x": 3, "y": 1, "trainer_type": 1, "trainer_sight_or_berry_tree_id": 5,
		"script_offset": 1}, true)
	host.objects.templates.append(template)
	host.objects.spawn(template, 0, 0)
	var trainer: Gen3ObjectEvents.ObjectEvent = host.objects.by_identity(2, 0, 0)
	Gen3ObjectEvents.turn(trainer, Gen3ObjectEvents.Direction.SOUTH)
	host.step()
	assert_eq(host.battle.opponent_a, 7)
	assert_eq(host.objects.events.var_get(0x800F), 2)
	assert_eq(host.selected_slot, host.objects.objects.find(trainer))


func test_frlg_quest_log_specials_are_no_screens_and_its_menu_flag_is_not_ignore_b() -> void:
	var host: Gen3ScriptHost = _field_host(RomRegistry.FIRERED)
	host._executing = host.context
	assert_eq(host._special("QuestLogNoOp"), 0)
	assert_eq(host.context.state, Gen3ScriptContext.State.STOPPED, "A quest log special must not stop the script for a screen.")
	host.objects.camera.data._world_scripts["multichoice"] = []
	host._menu_command({"command": "multichoice", "operands": [19, 8, 20, 2]})
	assert_false(host._output.back()["ignore_b"], "FALSE | TRUE << 1 still lets B cancel.")
