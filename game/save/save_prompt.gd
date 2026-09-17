class_name Gen2SavePrompt
extends RefCounted

## Every save `engine/menus/save.asm` performs, as the one sequence they share:
## an optional question, `AskOverwriteSaveFile`, `SavingDontTurnOffThePower` and
## `SavedTheGame`. Node free, with the write injected. [enum Kind] is only the
## question in front, `Link_SaveGame` asking none of its own. `GEN1_MENU` is
## pokered's `SaveMenu` and `YELLOW_MENU` pokeyellow's.
enum Kind { MENU, CHANGE_BOX, MOVE_MON, LINK, GEN1_MENU, YELLOW_MENU }

## `ASK` and `OVERWRITE` read a yes/no, `SAVING` and `SAVED` read no joypad at
## all, and `FAILED` is this port's own step.
enum Step { ASK, OVERWRITE, SAVING, SAVED, FAILED, REFUSED, DONE }

## The texts, out of `data/text/common_3.asm` on Crystal and `common_2.asm` on
## Gold and Silver, authored here verbatim, one entry a line, so a box scrolls
## where `_ContText` scrolls. `AnotherSaveFileText` is unreachable: a world is
## always played from the slot it was started in.
const ASK_LINES: Array[String] = [
	"Would you like to", "save the game?",
]
const CHANGE_BOX_LINES: Array[String] = [
	"When you change a", "#MON BOX, data", "will be saved. OK?",
]
const MOVE_MON_LINES: Array[String] = [
	"Each time you move", "a #MON, data", "will be saved. OK?",
]
const OVERWRITE_LINES: Array[String] = [
	"There is already a", "save file. Is it", "OK to overwrite?",
]
const SAVING_LINES: Array[String] = [
	"SAVING… DON'T TURN", "OFF THE POWER.",
]
## `_SavedTheGameText`, whose `<PLAYER>` is filled from the save.
const SAVED_LINES: Array[String] = [
	"%s saved", "the game.",
]
## `MovePKMNWithoutMail_InsertMon`'s own one-row box, a `PlaceString` rather than
## a text, and the `_PCMonHoldingMailText` `BillsPC_MovePKMNMenu` refuses the
## whole row with.
const SAVING_LEAVE_ON: String = "Saving… Leave ON!"
const MON_HOLDING_MAIL_LINES: Array[String] = [
	"There is a #MON", "holding MAIL.", "Please remove the", "MAIL.",
]
## pokered's `data/text/text_3.asm` and `NowSavingString`, pokeyellow's
## `_SavingText`.
const GEN1_ASK_LINES: Array[String] = [
	"Would you like to", "SAVE the game?",
]
const GEN1_SAVING_LINES: Array[String] = ["Now saving..."]
const YELLOW_SAVING_LINES: Array[String] = ["Saving..."]
const GEN1_SAVED_LINES: Array[String] = [
	"%s saved", "the game!",
]
const QUESTIONS: Array[Array] = [
	ASK_LINES, CHANGE_BOX_LINES, MOVE_MON_LINES, [], GEN1_ASK_LINES, GEN1_ASK_LINES,
]

## `SavingDontTurnOffThePower`'s `ld c, 16`, `SavedTheGame`'s 32 before the
## words and 30 after, `MovePKMNWithoutMail_InsertMon`'s 20,
## `MoveMonWOMail_InsertMon_SaveGame`'s 24, and `SFX_SAVE`.
const SAVING_FRAMES: int = 16
const WRITE_FRAMES: int = 32
const DONE_FRAMES: int = 30
const LEAVE_ON_FRAMES: int = 20
const INSERT_SAVED_FRAMES: int = 24
const SFX_SAVE: int = 0x25
## Per kind: the frames the info box stands with no question, the frame
## `SaveGameData` lands on, the frame the saved line goes up, the frame
## `SFX_SAVE` plays and when SAVED ends. `PrintSaveScreenText`'s `ld c, 30` and
## `SaveMenu.save`'s `ld c, 120`; Yellow adds `ld c, 10` three times.
const TIMINGS: Dictionary = {
	Kind.GEN1_MENU: {"hold": 30, "write": 0, "result": 120, "sfx": 0, "done": 30},
	Kind.YELLOW_MENU: {"hold": 40, "write": 0, "result": 128, "sfx": 10, "done": 40},
}
const GEN2_TIMING: Dictionary = {
	"hold": 0, "write": SAVING_FRAMES, "result": SAVING_FRAMES + WRITE_FRAMES,
	"sfx": 0, "done": DONE_FRAMES,
}

## `InitDisplayForHallOfFame`'s `_SavingRecordText` and the `ld c, 100`
## `HallOfFame_FadeOutMusic` spends behind it. Not this sequence: `HallOfFame`
## saves further down and says nothing there.
const SAVING_RECORD_LINES: Array[String] = [
	"SAVING RECORD…", "DON'T TURN OFF!",
]
const SAVING_RECORD_FRAMES: int = 100

var step: Step = Step.ASK
## The box's lines and the one it has scrolled to, and the yes/no's cursor: 0 is
## YES, 1 is NO, and below zero is a box with no question on it yet.
var lines: Array[String] = []
var line: int = 0
var cursor: int = -1
var frames: int = 0
var result: Dictionary = {}

var _kind: Kind = Kind.MENU
var _player_name: String = ""
var _write: Callable = Callable()


## [param write] takes no arguments and answers an "ok" key, with a "reason"
## behind a false one.
static func open(kind: Kind, player_name: String, write: Callable) -> Gen2SavePrompt:
	var prompt := Gen2SavePrompt.new()
	prompt._kind = kind
	prompt._player_name = player_name
	prompt._write = write
	if QUESTIONS[int(kind)].is_empty():
		prompt._enter(Step.OVERWRITE)
	else:
		prompt._enter(Step.ASK)
	return prompt


func reads_joypad() -> bool:
	return step in [Step.ASK, Step.OVERWRITE, Step.FAILED] and not holding_info()


func holding_info() -> bool:
	return step == Step.ASK and frames < _timing("hold")


func _timing(name: String) -> int:
	return int(TIMINGS.get(_kind, GEN2_TIMING)[name])


func _gen1() -> bool:
	return TIMINGS.has(_kind)


func finished() -> bool:
	return step in [Step.REFUSED, Step.DONE]


## Stopped on a NO, which is the carry both `.refused` branches set.
func refused() -> bool:
	return step == Step.REFUSED


## A on the box. A three-line text is prompted past once before its last line,
## which is `_ContText`'s own `PromptButton`, and [param yes] is ignored there.
func confirm(yes: bool) -> void:
	if holding_info():
		return
	if cursor < 0 and step in [Step.ASK, Step.OVERWRITE]:
		line = 1
		cursor = 0
		return
	match step:
		## `CheckPreviousSaveFile` asks `OlderFileWillBeErasedText` of another
		## player's file alone, which a slot never holds here.
		Step.ASK:
			if not yes:
				_enter(Step.REFUSED)
			else:
				_enter(Step.SAVING if _gen1() else Step.OVERWRITE)
		Step.OVERWRITE:
			_enter(Step.SAVING if yes else Step.REFUSED)
		## A write that failed did not happen, so it ends the way a NO does.
		Step.FAILED:
			_enter(Step.REFUSED)
		_:
			pass


## B, which is `YesNoBox`'s NO and `PromptButton`'s other button.
func cancel() -> void:
	confirm(false)


func frame() -> void:
	if reads_joypad() or finished():
		return
	frames += 1
	match step:
		Step.ASK:
			if frames == _timing("hold"):
				_open_question(QUESTIONS[int(_kind)])
		Step.SAVING:
			if frames == _timing("write"):
				_run_write()
			elif frames == _timing("result"):
				_show_result()
		## Exactly, not past: a host freed a frame later would otherwise be told
		## the sequence ended again on every frame in between.
		Step.SAVED:
			if frames == _timing("done"):
				_enter(Step.DONE)


func frames_elapsed(count: int) -> void:
	for _step: int in count:
		frame()


## The frame the write lands on, where `ChangeBoxSaveGame` switches its box.
func writing_now() -> bool:
	return step == Step.SAVING and frames == _timing("write")


## The frame `SavedTheGame` asks for `SFX_SAVE` through `WaitPlaySFX`.
func sfx_owed() -> bool:
	return step == Step.SAVED and frames == _timing("sfx")


func _open_question(text: Array) -> void:
	lines.assign(text)
	cursor = -1 if text.size() > 2 else 0


func _enter(next: Step) -> void:
	step = next
	frames = 0
	line = 0
	match next:
		Step.ASK:
			if _timing("hold") > 0:
				lines.clear()
				cursor = -1
			else:
				_open_question(QUESTIONS[int(_kind)])
		Step.OVERWRITE:
			_open_question(OVERWRITE_LINES)
		Step.SAVING:
			lines.assign(_saving_lines())
			cursor = -1
			if _timing("write") == 0:
				_run_write()
		Step.SAVED:
			var saved: Array[String] = GEN1_SAVED_LINES if _gen1() else SAVED_LINES
			lines.assign([saved[0] % _player_name, saved[1]])
			cursor = -1
		Step.FAILED:
			lines.assign([
				"Save failed:", String(result.get("reason", "unknown")),
			])
			cursor = 0
		_:
			lines.clear()
			cursor = -1


func _saving_lines() -> Array[String]:
	match _kind:
		Kind.GEN1_MENU:
			return GEN1_SAVING_LINES
		Kind.YELLOW_MENU:
			return YELLOW_SAVING_LINES
	return SAVING_LINES


func _run_write() -> void:
	result = _write.call() if _write.is_valid() \
		else {"ok": false, "reason": &"no_save_action"}


## `SavedTheGame`'s words. The failure line is this project's own: the cartridge
## has no such path, its write being to SRAM it has already checked.
func _show_result() -> void:
	_enter(Step.SAVED if bool(result.get("ok", false)) else Step.FAILED)
