extends GutTest

func _context(bytes: PackedByteArray, id: StringName = RomRegistry.EMERALD) -> Gen3ScriptContext:
	var rom := RomFile.from_bytes(bytes, id)
	var rows: Dictionary = {}
	var at: int = 1
	while at < bytes.size():
		var row: Dictionary = Gen3Script.instruction(rom, at)
		if row.is_empty():
			break
		rows[str(at)] = row
		at = int(row["next_offset"])
	var data := GameData.new()
	data.id = id
	data.generation = RomRegistry.GEN3
	data._sections = {"scripts": true}
	data._world_scripts = {"instructions": rows, "standard": [0x30]}
	var context := Gen3ScriptContext.new(data, Gen3EventData.new(id))
	context.start(1)
	return context


func test_calls_and_standard_dispatch_return_to_the_next_instruction() -> void:
	var bytes := PackedByteArray([0, 0x16, 0, 0x40, 5, 0, 4, 0x30, 0, 0, 8,
		0x21, 0, 0x40, 6, 0, 6, 1, 0x1B, 0, 0, 8, 0x16, 0, 0x40, 99, 0, 2])
	bytes.resize(0x30)
	bytes.append_array([0x17, 0, 0x40, 1, 0, 3])
	for id: StringName in Gen3Script.FORMAT_COUNTS:
		var context: Gen3ScriptContext = _context(bytes, id)
		assert_eq(context.tick(), [])
		assert_eq(context._events.var_get(0x4000), 6)
		assert_eq(context.state, Gen3ScriptContext.State.STOPPED)
	bytes[6] = 9
	bytes[7] = 0
	bytes[8] = 0
	bytes[9] = 0
	bytes[10] = 0
	var standard: Gen3ScriptContext = _context(bytes)
	standard.tick()
	assert_eq(standard._events.var_get(0x4000), 6)


func test_arithmetic_uses_literals_for_add_and_varget_for_subtract() -> void:
	var context: Gen3ScriptContext = _context(PackedByteArray([0,
		0x16, 1, 0x40, 2, 0, 0x16, 0, 0x40, 0xFF, 0xFF,
		0x17, 0, 0x40, 1, 0, 0x18, 0, 0x40, 1, 0x40,
		0x19, 2, 0x40, 0, 0x40, 0x1A, 3, 0x40, 7, 0,
		0x17, 3, 0x40, 1, 0x40, 2]))
	context.tick()
	assert_eq(context._events.var_get(0x4002), 0xFFFE)
	assert_eq(context._events.var_get(0x4003), 0x4008)


func test_flag_comparison_and_local_byte_comparison_drive_conditions() -> void:
	var bytes := PackedByteArray([0,
		0x29, 1, 0, 0x2B, 1, 0, 7, 1, 0x20, 0, 0, 8,
		0x2A, 1, 0, 0x2B, 1, 0, 0x27, 2])
	bytes.resize(32)
	bytes.append_array([0x0F, 0, 1, 1, 0, 0, 0x1C, 0, 1, 3])
	var context: Gen3ScriptContext = _context(bytes)
	assert_eq(context.tick(), [{"type": "waitstate", "offset": 19}])
	assert_eq(context.comparison, 0)
	assert_false(context._events.flag_get(1))
	context.resume()
	context.tick()
	assert_eq(context.state, Gen3ScriptContext.State.STOPPED)


func test_delay_finishes_on_its_native_tick_and_resumes_on_the_following_tick() -> void:
	var context: Gen3ScriptContext = _context(PackedByteArray([0, 0x28, 2, 0, 0x29, 1, 0, 2]))
	context.tick()
	context.tick()
	assert_eq(context.state, Gen3ScriptContext.State.DELAY)
	context.tick()
	assert_eq(context.state, Gen3ScriptContext.State.RUNNING)
	assert_false(context._events.flag_get(1))
	context.tick()
	assert_true(context._events.flag_get(1))
	assert_eq(context.state, Gen3ScriptContext.State.STOPPED)


func test_zero_delay_wraps_the_halfword_timer() -> void:
	var context: Gen3ScriptContext = _context(PackedByteArray([0, 0x28, 0, 0, 2]))
	context.tick()
	context.tick()
	assert_eq(context._events.script_delay, 0xFFFF)


func test_unimplemented_commands_and_non_yielding_loops_stop_with_evidence() -> void:
	var context: Gen3ScriptContext = _context(PackedByteArray([0, 0x2C, 1, 0, 2, 0, 2]))
	var events: Array[Dictionary] = context.tick()
	assert_eq(events[0]["reason"], "unsupported_command")
	assert_eq(events[0]["offset"], 1)
	assert_eq(events[0]["instruction"]["command"], "initclock")
	assert_eq(context.tick(), [])
	var loop: Gen3ScriptContext = _context(PackedByteArray([0, 5, 1, 0, 0, 8]))
	assert_eq(loop.tick(3)[0]["reason"], "instruction_budget")


func test_return_without_a_caller_ends_and_restart_clears_context_state() -> void:
	var context: Gen3ScriptContext = _context(PackedByteArray([0, 3]))
	context.tick()
	assert_eq(context.state, Gen3ScriptContext.State.STOPPED)
	context.locals[0] = 10
	context.comparison = 2
	context.start(1)
	assert_eq(context.locals, [0, 0, 0, 0])
	assert_eq(context.comparison, 0)


func test_stack_overflow_jumps_without_pushing_an_extra_return_address() -> void:
	var context: Gen3ScriptContext = _context(PackedByteArray([0,
		0x17, 0, 0x40, 1, 0, 0x21, 0, 0x40, 21, 0,
		6, 1, 27, 0, 0, 8, 4, 1, 0, 0, 8,
		0x17, 1, 0x40, 1, 0, 3]))
	assert_eq(context.tick(), [])
	assert_eq(context.state, Gen3ScriptContext.State.STOPPED)
	assert_eq(context._events.var_get(0x4000), 21)
	assert_eq(context._events.var_get(0x4001), 19)


func test_random_and_stats_share_the_field_event_state() -> void:
	var context: Gen3ScriptContext = _context(PackedByteArray([0,
		0x16, 0, 0x40, 7, 0, 0x8F, 0, 0x40, 0xc3, 1, 0xc3, 1, 2]))
	context._events.random.next()
	context._events.stats[1] = 0xFFFFFE
	context.tick()
	assert_eq(context._events.var_get(0x800D), 59774 % 7)
	assert_eq(context._events.stats[1], 0xFFFFFF)


func test_dialogue_events_preserve_order_and_native_wait_completion_ticks() -> void:
	var context: Gen3ScriptContext = _context(PackedByteArray([0,
		0x6A, 0x0F, 0, 0x20, 0, 0, 8, 0x67, 0, 0, 0, 0, 0x66,
		0x6D, 0x68, 0x6C, 2]))
	assert_eq(context.tick(), [{"type": "script_command", "command": "lock",
		"operands": [], "offset": 1}])
	context.resume()
	assert_eq(context.tick(), [])
	assert_eq(context.state, Gen3ScriptContext.State.NATIVE_WAIT)
	assert_eq(context.tick(10000, true), [])
	assert_eq(context.tick(), [
		{"type": "script_command", "command": "message", "operands": [0x08000020], "offset": 8},
		{"type": "script_command", "command": "waitmessage", "operands": [], "offset": 13}])
	context.tick(10000, true)
	assert_eq(context.tick(), [{"type": "script_command", "command": "waitbuttonpress",
		"operands": [], "offset": 14}])
	context.tick(10000, true)
	assert_eq(context.tick(), [
		{"type": "script_command", "command": "closemessage", "operands": [], "offset": 15},
		{"type": "script_command", "command": "release", "operands": [], "offset": 16}])
	assert_eq(context.state, Gen3ScriptContext.State.STOPPED)


func test_host_events_survive_a_later_fault_and_restart_clears_native_wait() -> void:
	var context: Gen3ScriptContext = _context(PackedByteArray([0, 0x68, 0x2E, 0x69, 2]))
	var events: Array[Dictionary] = context.tick()
	assert_eq(events.size(), 2)
	assert_eq(events[0]["command"], "closemessage")
	assert_eq(events[1]["reason"], "unsupported_command")
	context.start(3)
	assert_eq(context.tick()[0]["command"], "lockall")
	context.start(4)
	assert_eq(context.tick(), [])
	assert_eq(context.state, Gen3ScriptContext.State.STOPPED)


func test_map_script_dispatch_uses_first_matching_type_and_varget_on_both_sides() -> void:
	var context: Gen3ScriptContext = _context(PackedByteArray([0, 0x29, 1, 0, 2, 0x29, 2, 0, 2]))
	context._data._sections["headers"] = true
	context._data._world_headers = {"1:2": {"map_scripts": [
		{"type": 1, "script_offset": 1}, {"type": 1, "script_offset": 5},
		{"type": 2, "conditions": [
			{"variable": 0x4000, "value": 7, "script_offset": 1},
			{"variable": 0x4000, "value": 0x4001, "script_offset": 5}]},
		{"type": 4, "conditions": []}]}}
	context._events.var_set(0x4000, 9)
	context._events.var_set(0x4001, 9)
	assert_true(context.start_map_script(1, 2, 1))
	context.tick()
	assert_true(context._events.flag_get(1))
	assert_false(context._events.flag_get(2))
	assert_true(context.start_map_script(1, 2, 2))
	context.tick()
	assert_true(context._events.flag_get(2))
	assert_false(context.start_map_script(1, 2, 4))
	assert_false(context.start_map_script(1, 2, 7))
	assert_false(context.start_map_script(9, 9, 1))
	assert_eq(context.state, Gen3ScriptContext.State.STOPPED)


func test_pause_counter_is_shared_and_context_start_does_not_reset_it() -> void:
	var foreground: Gen3ScriptContext = _context(PackedByteArray([0, 0x28, 2, 0, 2, 0x28, 1, 0, 2]))
	foreground.tick()
	var immediate := Gen3ScriptContext.new(foreground._data, foreground._events)
	immediate.start(5)
	assert_eq(foreground._events.script_delay, 2)
	immediate.tick()
	immediate.tick()
	foreground.tick()
	assert_eq(foreground._events.script_delay, 0xFFFF)
	assert_eq(foreground.state, Gen3ScriptContext.State.DELAY)
