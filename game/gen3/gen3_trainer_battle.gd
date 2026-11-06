class_name Gen3TrainerBattle
extends RefCounted

## `battle_setup.c`'s trainer battle state; a second trainer's arguments fill the B fields. Hosts run the battle itself.

enum Mode { SINGLE, CONTINUE_NO_MUSIC, CONTINUE, NO_INTRO, DOUBLE, REMATCH, CONTINUE_DOUBLE, REMATCH_DOUBLE,
	CONTINUE_DOUBLE_NO_MUSIC, FACILITY_OR_EARLY_RIVAL, SET_TRAINER_A, SET_TRAINER_B, HILL }
enum Outcome { NONE, WON, LOST, DREW, RAN, TELEPORTED, MON_FLED, CAUGHT, NO_SAFARI_BALLS, FORFEITED }
const TRAINER_FLAGS_START: int = 0x500
const TRAINER_SECRET_BASE: int = 1024
const RIVAL_HEAL_AFTER: int = 1
const ORDINARY_WORDS: Array[String] = ["intro", "defeat"] # Each `s*BattleParams` table's loaded words, after the mode, trainer id and local id.
const WORDS: Dictionary = {
	Mode.CONTINUE_NO_MUSIC: ["intro", "defeat", "return"], Mode.CONTINUE: ["intro", "defeat", "return"],
	Mode.NO_INTRO: ["defeat"], Mode.DOUBLE: ["intro", "defeat", "cannot"],
	Mode.REMATCH_DOUBLE: ["intro", "defeat", "cannot"],
	Mode.CONTINUE_DOUBLE: ["intro", "defeat", "cannot", "return"],
	Mode.CONTINUE_DOUBLE_NO_MUSIC: ["intro", "defeat", "cannot", "return"],
}
const NO_MUSIC_MODES: Array[int] = [Mode.CONTINUE_NO_MUSIC, Mode.CONTINUE_DOUBLE_NO_MUSIC]

var mode: int = 0
var opponent_a: int = 0
var opponent_b: int = 0
var local_id: int = 0
var rival_flags: int = 0
var victory_speech: int = 0
var cannot_speech: int = 0
var end_script: int = -1
var _speech: Array[Dictionary] = [{"intro": 0, "defeat": 0, "return": 0}, {"intro": 0, "defeat": 0, "return": 0}]
var _possible_scripts: int = 0
var _check_b: bool = false
var face_index: int = 0 # `gWhichTrainerToFaceAfterBattle`.
var _frlg: bool = false
var _emerald: bool = false


func _init(game: StringName) -> void:
	_frlg = game in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN]
	_emerald = game == RomRegistry.EMERALD


func reset_opponents() -> void:
	opponent_a = 0
	opponent_b = 0


func configure(operands: Array, next_offset: int, approaching_id: int) -> bool: # `BattleSetup_ConfigureTrainerBattle`, false for Emerald's facility modes, whose trainers need their world state.
	var side: int = 1 if approaching_id != 0 else 0
	_speech[side] = {"intro": 0, "defeat": 0, "return": 0}
	local_id = 0
	victory_speech = 0
	cannot_speech = 0
	end_script = next_offset
	mode = int(operands[0])
	if _emerald and mode in [Mode.FACILITY_OR_EARLY_RIVAL, Mode.HILL]:
		return false
	if _frlg and mode == Mode.FACILITY_OR_EARLY_RIVAL:
		opponent_a = int(operands[1])
		rival_flags = int(operands[2])
		_speech[0]["defeat"] = int(operands[3])
		victory_speech = int(operands[4])
		return true
	var second: bool = mode == Mode.SET_TRAINER_B or side == 1 and mode in [Mode.SINGLE, Mode.CONTINUE]
	side = 1 if second else 0
	if second:
		opponent_b = int(operands[1])
	else:
		opponent_a = int(operands[1])
	local_id = int(operands[2])
	var words: Array = WORDS.get(mode, ORDINARY_WORDS)
	for index: int in words.size():
		var value: int = int(operands[3 + index])
		if words[index] == "cannot":
			cannot_speech = value
		else:
			_speech[side][words[index]] = value
	return true


func sets_map_vars(approaching_id: int) -> bool: # `SetMapVarsToTrainer` runs for every mode but these, and for the first trainer only.
	if mode in [Mode.NO_INTRO, Mode.SET_TRAINER_A, Mode.SET_TRAINER_B, Mode.FACILITY_OR_EARLY_RIVAL]:
		return false
	return approaching_id == 0 or mode not in [Mode.SINGLE, Mode.CONTINUE]


func intro_speech(approaching_id: int) -> int:
	return int(_speech[1 if approaching_id != 0 else 0]["intro"])


func flag_set(events: Gen3EventData) -> bool:
	return events.flag_get(TRAINER_FLAGS_START + opponent_a)


func begin(approaching_count: int) -> Dictionary: # `BattleSetup_StartTrainerBattle`.
	_possible_scripts = approaching_count
	_check_b = false
	face_index = 0
	return {"kind": "trainer_battle", "mode": mode, "opponent_a": opponent_a, "opponent_b": opponent_b,
		"defeat_a": _speech[0]["defeat"], "defeat_b": _speech[1]["defeat"], "victory": victory_speech}


func finish(outcome: int, events: Gen3EventData) -> bool: # `CB2_EndTrainerBattle`: false when the player whites out instead of returning to the script.
	var defeated: bool = outcome in [Outcome.LOST, Outcome.DREW]
	if _frlg and mode == Mode.FACILITY_OR_EARLY_RIVAL:
		events.var_set(Gen3ScriptServices.VAR_RESULT, int(defeated))
		if defeated and rival_flags & RIVAL_HEAL_AFTER == 0:
			return false
		_set_flags(events)
		return true
	if opponent_a == TRAINER_SECRET_BASE:
		return true
	if defeated:
		return false
	_set_flags(events)
	return true


func _set_flags(events: Gen3EventData) -> void:
	if opponent_b != 0:
		events.flag_set(TRAINER_FLAGS_START + opponent_b)
	events.flag_set(TRAINER_FLAGS_START + opponent_a)


func beaten_script() -> int: # `BattleSetup_GetTrainerPostBattleScript`; -1 stands for `EventScript_TryGetTrainerScript`'s `releaseall`, `end`.
	var check_b: bool = _check_b
	_check_b = false
	var script: int = int(_speech[1 if check_b else 0]["return"])
	if script != 0:
		face_index = 1 if check_b else 0
		return Gen3Layout.rom_offset(script)
	if not check_b and _possible_scripts > 1: # ShouldTryGetTrainerScript sends a second pass to trainer B.
		_possible_scripts = 0
		_check_b = true
		return beaten_script()
	return -1
