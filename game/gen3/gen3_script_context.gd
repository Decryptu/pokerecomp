class_name Gen3ScriptContext
extends RefCounted

enum State { STOPPED, RUNNING, DELAY, WAITING, FAULT }

const STACK_LIMIT: int = 19 # script.c::ScriptPush reserves stack[20]'s last slot.
const CONDITIONS: Array = [[0], [1], [2], [0, 1], [1, 2], [0, 2]]

var state: int = State.STOPPED
var offset: int = -1
var comparison: int = 0
var locals: Array[int] = [0, 0, 0, 0]
var error: Dictionary = {}
var _data: GameData
var _events: Gen3EventData
var _stack: Array[int] = []
var _delay: int = 0


func _init(data: GameData, events: Gen3EventData) -> void:
	_data = data
	_events = events


func start(at: int) -> void:
	offset = at
	comparison = 0
	locals = [0, 0, 0, 0]
	_stack.clear()
	error = {}
	_delay = 0
	state = State.RUNNING


func resume() -> void:
	if state == State.WAITING:
		state = State.RUNNING


func tick(budget: int = 10000) -> Array[Dictionary]:
	if state == State.DELAY:
		_delay = (_delay - 1) & 0xFFFF
		if _delay == 0:
			state = State.RUNNING
		return [] # script.c::RunScriptCommand returns even on the tick a native wait completes.
	if state != State.RUNNING:
		return []
	for count: int in budget:
		if offset < 0:
			state = State.STOPPED
			return []
		var at: int = offset
		var row: Dictionary = _data.world_script_instruction(at)
		if row.is_empty():
			return _fault(at, "missing_instruction")
		offset = int(row["next_offset"])
		if not _execute(row):
			return _fault(at, "unsupported_command", row)
		if state == State.WAITING:
			return [{"type": "waitstate", "offset": at}]
		if state != State.RUNNING:
			return []
	return _fault(offset, "instruction_budget")


func _fault(at: int, reason: String, row: Dictionary = {}) -> Array[Dictionary]:
	state = State.FAULT
	error = {"type": "script_error", "offset": at, "reason": reason, "instruction": row.duplicate(true)}
	return [error.duplicate(true)]


func _execute(row: Dictionary) -> bool:
	var command: String = row["command"]
	var args: Array = row["operands"]
	if command in ["nop", "nop1"]:
		return true
	if command == "end":
		state = State.STOPPED
		return true
	if command == "return":
		offset = -1 if _stack.is_empty() else _stack.pop_back()
		return true
	if command in ["goto", "call", "goto_if", "call_if", "gotostd", "callstd", "gotostd_if", "callstd_if"]:
		return _branch(command, args)
	if command == "delay":
		_delay = int(args[0])
		state = State.DELAY
		return true
	if command == "waitstate":
		state = State.WAITING
		return true
	if command in ["setflag", "clearflag", "checkflag", "incrementgamestat", "random"]:
		return _event_command(command, args)
	return _value_command(command, args)


func _branch(command: String, args: Array) -> bool:
	if command.ends_with("_if"):
		var condition: int = int(args[0])
		if condition < 0 or condition >= CONDITIONS.size():
			return false
		if comparison not in CONDITIONS[condition]:
			return true
	var target: int = int(args.back())
	if command.contains("std"):
		target = _data.world_standard_script_offset(target)
		if target < 0:
			return true
	else:
		target = Gen3Layout.rom_offset(target)
	if command.begins_with("call") and _stack.size() < STACK_LIMIT:
		_stack.append(offset)
	offset = target
	return true


func _event_command(command: String, args: Array) -> bool:
	var id: int = int(args[0])
	match command:
		"setflag": _events.flag_set(id)
		"clearflag": _events.flag_clear(id)
		"checkflag": comparison = int(_events.flag_get(id))
		"incrementgamestat": _events.increment_stat(id)
		"random":
			var limit: int = _events.var_get(id)
			if limit == 0:
				return false
			_events.var_set(0x800D, _events.random.next() % limit)
	return true


func _value_command(command: String, args: Array) -> bool:
	if args.size() != 2:
		return false
	var dest: int = int(args[0])
	var value: int = int(args[1])
	match command:
		"setvar": _events.var_set(dest, value)
		"addvar": _events.var_set(dest, _events.var_get(dest) + value)
		"subvar": _events.var_set(dest, _events.var_get(dest) - _events.var_get(value))
		"copyvar", "setorcopyvar": _events.var_set(dest, _events.var_get(value))
		"compare_var_to_value": comparison = _compare(_events.var_get(dest), value)
		"compare_var_to_var": comparison = _compare(_events.var_get(dest), _events.var_get(value))
		"loadword", "loadbyte", "copylocal", "compare_local_to_local", "compare_local_to_value":
			return _local_command(command, dest, value)
		_: return false
	return true


func _local_command(command: String, dest: int, value: int) -> bool:
	if dest < 0 or dest >= locals.size():
		return false
	if command in ["copylocal", "compare_local_to_local"]:
		if value < 0 or value >= locals.size():
			return false
		value = locals[value]
	match command:
		"loadword", "loadbyte", "copylocal": locals[dest] = value
		"compare_local_to_local", "compare_local_to_value": comparison = _compare(locals[dest] & 0xFF, value & 0xFF)
	return true


static func _compare(left: int, right: int) -> int:
	return 0 if left < right else (1 if left == right else 2)
