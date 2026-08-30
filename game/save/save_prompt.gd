class_name Gen2SavePrompt
extends RefCounted

## Every save `engine/menus/save.asm` performs, as the one sequence they share:
## an optional question, `AskOverwriteSaveFile`, `SavingDontTurnOffThePower` and
## `SavedTheGame`. Node free, with the write injected. [enum Kind] is only the
## question in front, `Link_SaveGame` (whose caller is `TryQuickSave`) asking
## none of its own.
enum Kind { MENU, CHANGE_BOX, MOVE_MON, LINK }

## `ASK` and `OVERWRITE` read a yes/no, `SAVING` and `SAVED` read no joypad at
## all, and `FAILED` is this port's own step.
enum Step { ASK, OVERWRITE, SAVING, SAVED, FAILED, REFUSED, DONE }

## The texts, out of `data/text/common_3.asm` on Crystal and `common_2.asm` on
## Gold and Silver, which no importer reads and which this project authors beside
## its other engine text. Verbatim, one entry a line, so a box scrolls where
## `_ContText` scrolls. `AnotherSaveFileText` is `AlreadyASaveFileText`'s sibling
## for another player's file, and `CompareLoadedAndSavedPlayerID` cannot reach it
## here: a world is always played from the slot it was started in.
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
const QUESTIONS: Array[Array] = [ASK_LINES, CHANGE_BOX_LINES, MOVE_MON_LINES, []]

## `SavingDontTurnOffThePower`'s own `ld c, 16`, then `SavedTheGame`'s 32 before
## the words and 30 after them; `MovePKMNWithoutMail_InsertMon`'s 20 and
## `MoveMonWOMail_InsertMon_SaveGame`'s 24; and `SFX_SAVE`, hexadecimal the way
## constants/sfx_constants.asm counts.
const SAVING_FRAMES: int = 16
const WRITE_FRAMES: int = 32
const DONE_FRAMES: int = 30
const LEAVE_ON_FRAMES: int = 20
const INSERT_SAVED_FRAMES: int = 24
const SFX_SAVE: int = 0x25

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
	return step in [Step.ASK, Step.OVERWRITE, Step.FAILED]


func finished() -> bool:
	return step in [Step.REFUSED, Step.DONE]


## Stopped on a NO, which is the carry both `.refused` branches set.
func refused() -> bool:
	return step == Step.REFUSED


## A on the box. A three-line text is prompted past once before its last line,
## which is `_ContText`'s own `PromptButton`, and [param yes] is ignored there.
func confirm(yes: bool) -> void:
	if cursor < 0 and step in [Step.ASK, Step.OVERWRITE]:
		line = 1
		cursor = 0
		return
	match step:
		Step.ASK:
			_enter(Step.OVERWRITE if yes else Step.REFUSED)
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


## One hardware frame of the two timed steps.
func frame() -> void:
	if reads_joypad() or finished():
		return
	frames += 1
	match step:
		Step.SAVING:
			if frames == SAVING_FRAMES:
				_run_write()
			elif frames == SAVING_FRAMES + WRITE_FRAMES:
				_show_result()
		## Exactly, not past: a host freed a frame later would otherwise be told
		## the sequence ended again on every frame in between.
		Step.SAVED:
			if frames == DONE_FRAMES:
				_enter(Step.DONE)


func frames_elapsed(count: int) -> void:
	for _step: int in count:
		frame()


## The frame the write lands on, where `ChangeBoxSaveGame` switches its box.
func writing_now() -> bool:
	return step == Step.SAVING and frames == SAVING_FRAMES


## The frame `SavedTheGame` asks for `SFX_SAVE` through `WaitPlaySFX`.
func sfx_owed() -> bool:
	return step == Step.SAVED and frames == 0


func _open_question(text: Array) -> void:
	lines.assign(text)
	cursor = -1 if text.size() > 2 else 0


func _enter(next: Step) -> void:
	step = next
	frames = 0
	line = 0
	match next:
		Step.ASK:
			_open_question(QUESTIONS[int(_kind)])
		Step.OVERWRITE:
			_open_question(OVERWRITE_LINES)
		Step.SAVING:
			lines.assign(SAVING_LINES)
			cursor = -1
		Step.SAVED:
			lines.assign([SAVED_LINES[0] % _player_name, SAVED_LINES[1]])
			cursor = -1
		Step.FAILED:
			lines.assign([
				"Save failed:", String(result.get("reason", "unknown")),
			])
			cursor = 0
		_:
			lines.clear()
			cursor = -1


func _run_write() -> void:
	result = _write.call() if _write.is_valid() \
		else {"ok": false, "reason": &"no_save_action"}


## `SavedTheGame`'s words. The failure line is this project's own: the cartridge
## has no such path, its write being to SRAM it has already checked.
func _show_result() -> void:
	_enter(Step.SAVED if bool(result.get("ok", false)) else Step.FAILED)
