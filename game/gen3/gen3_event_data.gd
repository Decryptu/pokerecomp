class_name Gen3EventData
extends RefCounted

## `event_data.c`: the event flags and vars. Flag 0 has no storage, so it reads
## clear and ignores writes; a var below `VARS_START` has none either, and
## `VarGet` answers it with the id itself.

const VARS_START: int = 0x4000
const TEMP_FLAGS_COUNT: int = 0x20
const TEMP_VARS_COUNT: int = 0x10
## The system flags `ClearTempFieldEventData` clears after the temporary ones.
const CLEARED_SYSTEM_FLAGS: Dictionary = {
	&"ruby": [0x84D, 0x84E, 0x829, 0x861],
	&"sapphire": [0x84D, 0x84E, 0x829, 0x861],
	&"firered": [0x803, 0x804, 0x805, 0x807, 0x842],
	&"leafgreen": [0x803, 0x804, 0x805, 0x807, 0x842],
	&"emerald": [0x8AD, 0x8AE, 0x889, 0x8C1, 0x880],
}

var game: StringName
var _flags: Dictionary = {}
var _vars: Dictionary = {}


func _init(game_id: StringName) -> void:
	game = game_id


func flag_get(id: int) -> bool:
	return _flags.has(id & 0xFFFF)


func flag_set(id: int) -> void:
	if id & 0xFFFF != 0:
		_flags[id & 0xFFFF] = true


func flag_clear(id: int) -> void:
	_flags.erase(id & 0xFFFF)


func var_get(id: int) -> int:
	id &= 0xFFFF
	return int(_vars.get(id, 0)) if id >= VARS_START else id


func var_set(id: int, value: int) -> void:
	if id & 0xFFFF >= VARS_START:
		_vars[id & 0xFFFF] = value & 0xFFFF


## `ClearTempFieldEventData`, run on every map load.
func clear_temp() -> void:
	for id: int in TEMP_FLAGS_COUNT:
		_flags.erase(id)
	for id: int in TEMP_VARS_COUNT:
		_vars.erase(VARS_START + id)
	for id: int in CLEARED_SYSTEM_FLAGS[game]:
		_flags.erase(id)
