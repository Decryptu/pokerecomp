class_name Gen3ScriptContext
extends RefCounted

enum State { STOPPED, RUNNING, DELAY, WAITING, NATIVE_WAIT, FAULT }

const STACK_LIMIT: int = 19 # script.c::ScriptPush reserves stack[20]'s last slot.
const WARP_COMMANDS: Array[String] = ["warp", "warpsilent", "warpdoor", "warphole", "warpteleport",
	"warpmossdeepgym", "warpspinenter", "warpwhitefade"]
const OBJECT_COMMANDS: Array[String] = ["removeobject", "removeobjectat", "removeobject_at",
	"addobject", "addobjectat", "addobject_at", "setobjectxy", "setobjectxyperm", "copyobjectxytoperm",
	"showobjectat", "hideobjectat", "setobjectmovementtype", "setmetatile", "getplayerxy"]
const HOST_COMMANDS: Array[String] = [
	"message", "messageautoscroll", "messageinstant", "pokenavcall",
	"waitmessage", "closemessage", "waitbuttonpress",
	"lock", "lockall", "release", "releaseall", "faceplayer", "turnobject",
	"applymovement", "applymovementat", "applymovement_at",
	"waitmovement", "waitmovementat", "waitmovement_at",
	"setwarp", "setdynamicwarp", "setdivewarp", "setholewarp", "setescapewarp",
]
const NATIVE_COMMANDS: Array[String] = ["waitmessage", "waitbuttonpress", "lock", "lockall",
	"waitmovement", "waitmovementat", "waitmovement_at"] # scrcmd.c::SetupNativeScript callers.
const CONDITIONS: Array = [[0], [1], [2], [0, 1], [1, 2], [0, 2]]

var state: int = State.STOPPED
var offset: int = -1
var comparison: int = 0
var locals: Array[int] = [0, 0, 0, 0]
var error: Dictionary = {}
var _data: GameData
var _events: Gen3EventData
var _stack: Array[int] = []
var _output: Array[Dictionary] = []


func _init(data: GameData, events: Gen3EventData) -> void:
	_data = data
	_events = events


func start(at: int) -> void:
	offset = at
	comparison = 0
	locals = [0, 0, 0, 0]
	_stack.clear()
	error = {}
	state = State.RUNNING


func start_map_script(group: int, number: int, type: int) -> bool:
	for row: Dictionary in _data.world_map_script_entries(group, number):
		if int(row.get("type", 0)) != type:
			continue
		if type in [2, 4]:
			for condition: Dictionary in row.get("conditions", []):
				var left: int = _events.var_get(int(condition["variable"]))
				var right: int = _events.var_get(int(condition["value"])) # script.c::MapHeaderCheckScriptTable resolves both.
				if left == right:
					start(int(condition["script_offset"]))
					return true
			return false
		start(int(row["script_offset"]))
		return true
	return false


func resume() -> void:
	if state == State.WAITING:
		state = State.RUNNING


func tick(budget: int = 10000, native_complete: bool = false, command_handler: Callable = Callable()) -> Array[Dictionary]:
	_output = []
	if state == State.NATIVE_WAIT:
		if native_complete:
			state = State.RUNNING
		return []
	if state == State.DELAY:
		_events.script_delay = (_events.script_delay - 1) & 0xFFFF
		if _events.script_delay == 0:
			state = State.RUNNING
		return [] # script.c::RunScriptCommand returns even on the tick a native wait completes.
	if state != State.RUNNING:
		return []
	for count: int in budget:
		if offset < 0:
			state = State.STOPPED
			return _output
		var at: int = offset
		var row: Dictionary = _data.world_script_instruction(at)
		if row.is_empty():
			return fail(at, "missing_instruction")
		offset = int(row["next_offset"])
		if not _execute(row, at, command_handler):
			return fail(at, "unsupported_command", row)
		if state == State.WAITING:
			_output.append({"type": "waitstate", "offset": at})
			return _output
		if state != State.RUNNING or String(row["command"]) in WARP_COMMANDS:
			return _output
	return fail(offset, "instruction_budget")


func fail(at: int, reason: String, row: Dictionary = {}) -> Array[Dictionary]:
	state = State.FAULT
	error = {"type": "script_error", "offset": at, "reason": reason, "instruction": row.duplicate(true)}
	_output.append(error.duplicate(true))
	return _output


func _execute(row: Dictionary, at: int, command_handler: Callable) -> bool:
	var command: String = row["command"]
	var args: Array = row["operands"]
	if command in HOST_COMMANDS or command in WARP_COMMANDS or command in OBJECT_COMMANDS:
		return _host_command(row, at, command_handler)
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
		_events.script_delay = int(args[0])
		state = State.DELAY
		return true
	if command == "waitstate":
		state = State.WAITING
		return true
	if command in ["setflag", "clearflag", "checkflag", "incrementgamestat", "random"]:
		return _event_command(command, args)
	return _value_command(command, args)


func _host_command(row: Dictionary, at: int, command_handler: Callable) -> bool:
	var command: String = row["command"]
	var operands: Array = row["operands"].duplicate()
	if command in ["message", "messageautoscroll", "messageinstant", "pokenavcall"] and int(operands[0]) == 0:
		operands[0] = locals[0] # scrcmd.c::ScrCmd_message and its printing variants accept NULL for data[0].
	var event: Dictionary = {"type": "script_command", "command": command,
		"operands": operands, "offset": at}
	_output.append(event)
	if command in NATIVE_COMMANDS:
		state = State.NATIVE_WAIT
	if command_handler.is_valid():
		command_handler.call(event)
	return true


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
