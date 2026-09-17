class_name Gen2WorldOptionsMenu
extends RefCounted

## The in-game OPTION menu (engine/menus/options_menu.asm): seven value rows
## plus CANCEL, each a left/right cycle over one field of [Gen2Options], edited
## in place and never written to the file. Byte identical between the pins
## except pokegold's `.ExitOptions` lacking the `SFX_TRANSACTION` play.
## `DisplayOptionMenu` (pokered engine/menus/main_menu.asm) is three sections
## over the same three fields and CANCEL; Yellow's `DisplayOptionMenu_`
## (pokeyellow engine/menus/options.asm) adds SOUND and PRINT on one page.

## GetOptionPointer.Pointers indexes.
const OPT_TEXT_SPEED: int = 0
const OPT_BATTLE_SCENE: int = 1
const OPT_BATTLE_STYLE: int = 2
const OPT_SOUND: int = 3
const OPT_PRINT: int = 4
const OPT_MENU_ACCOUNT: int = 5
const OPT_FRAME: int = 6
const OPT_CANCEL: int = 7
const NUM_OPTIONS: int = 8

## `StringOptions` and each handler's own value strings.
const TEXT_SPEED_VALUES: Array[String] = ["FAST", "MID", "SLOW"]
const PRINT_VALUES: Array[String] = ["LIGHTEST", "LIGHTER", "NORMAL", "DARKER", "DARKEST"]

const ROWS: Array[Dictionary] = [
	{"index": OPT_TEXT_SPEED, "label": "TEXT SPEED"},
	{"index": OPT_BATTLE_SCENE, "label": "BATTLE SCENE"},
	{"index": OPT_BATTLE_STYLE, "label": "BATTLE STYLE"},
	{"index": OPT_SOUND, "label": "SOUND"},
	{"index": OPT_PRINT, "label": "PRINT"},
	{"index": OPT_MENU_ACCOUNT, "label": "MENU ACCOUNT"},
	{"index": OPT_FRAME, "label": "FRAME"},
	{"index": OPT_CANCEL, "label": "CANCEL"},
]

## `TextSpeedOptionText` and its three siblings, each label with its `next`
## line, and each value's cursor column: `TextSpeedOptionData`'s 14, 7 and 1
## and the toggles' `xor 1 ^ 10`.
const GEN1_TEXT_SPEED: int = 0
const GEN1_BATTLE_ANIMATION: int = 1
const GEN1_BATTLE_STYLE: int = 2
const GEN1_CANCEL: int = 3
const GEN1_ROWS: Array[Dictionary] = [
	{
		"index": GEN1_TEXT_SPEED, "label": "TEXT SPEED",
		"values": " FAST  MEDIUM SLOW", "columns": [1, 7, 14],
	},
	{
		"index": GEN1_BATTLE_ANIMATION, "label": "BATTLE ANIMATION",
		"values": " ON       OFF", "columns": [1, 10],
	},
	{
		"index": GEN1_BATTLE_STYLE, "label": "BATTLE STYLE",
		"values": " SHIFT    SET", "columns": [1, 10],
	},
	{"index": GEN1_CANCEL, "label": "CANCEL", "values": "", "columns": [1]},
]

## `AllOptionsText`'s five rows at `hlcoord 2, 2` and `OptionMenuCancelText`
## at `hlcoord 2, 16`, each handler's own value strings and the `hlcoord` it
## places them at. `OptionsControl` skips the two dummy rows, so CANCEL is the
## sixth row here.
const YELLOW_TEXT_SPEED: int = 0
const YELLOW_ANIMATION: int = 1
const YELLOW_BATTLE_STYLE: int = 2
const YELLOW_SOUND: int = 3
const YELLOW_PRINT: int = 4
const YELLOW_CANCEL: int = 5
const YELLOW_ROWS: Array[Dictionary] = [
	{"index": YELLOW_TEXT_SPEED, "label": "TEXT SPEED :", "row": 2, "column": 14,
		"values": ["FAST", "MID ", "SLOW"]},
	{"index": YELLOW_ANIMATION, "label": "ANIMATION  :", "row": 4, "column": 14,
		"values": ["ON ", "OFF"]},
	{"index": YELLOW_BATTLE_STYLE, "label": "BATTLESTYLE:", "row": 6, "column": 14,
		"values": ["SHIFT", "SET  "]},
	{"index": YELLOW_SOUND, "label": "SOUND:", "row": 8, "column": 8,
		"values": ["MONO     ", "EARPHONE1", "EARPHONE2", "EARPHONE3"]},
	{"index": YELLOW_PRINT, "label": "PRINT:", "row": 10, "column": 8,
		"values": ["LIGHTEST", "LIGHTER ", "NORMAL  ", "DARKER  ", "DARKEST "]},
	{"index": YELLOW_CANCEL, "label": "CANCEL", "row": 16, "column": 0, "values": []},
]

enum Layout { CRYSTAL, GEN1, YELLOW }

var cursor: int = 0
var layout: Layout = Layout.CRYSTAL
var _options: Gen2Options = null


static func build(source_options: Gen2Options, menu_layout: Layout = Layout.CRYSTAL) -> Gen2WorldOptionsMenu:
	var menu := Gen2WorldOptionsMenu.new()
	menu._options = source_options if source_options != null else Gen2Options.new()
	menu.layout = menu_layout
	return menu


## Which `DisplayOptionMenu` a cache runs.
static func layout_for(data: GameData) -> Layout:
	if data == null or data.generation != RomRegistry.GEN1:
		return Layout.CRYSTAL
	return Layout.YELLOW if data.id == RomRegistry.YELLOW else Layout.GEN1


func options() -> Gen2Options:
	return _options


func _rows() -> Array[Dictionary]:
	match layout:
		Layout.GEN1:
			return GEN1_ROWS
		Layout.YELLOW:
			return YELLOW_ROWS
	return ROWS


func size() -> int:
	return _rows().size()


## `OptionsControl`, whose two branches the source's own comments call
## unexplained each land on the value a plain wrap would.
func move(delta: int) -> bool:
	if delta == 0:
		return false
	cursor = wrapi(cursor + signi(delta), 0, size())
	return true


## CANCEL is the only row A answers: every other handler reads left and right
## alone, so A on them does nothing.
func is_cancel() -> bool:
	return cursor == size() - 1


## Left or right on the selected row. The four bit rows toggle on either
## direction, each handler's `.LeftPressed` jumping to the opposite branch from
## `.NonePressed`. Returns whether a value changed.
func adjust(delta: int) -> bool:
	if delta == 0:
		return false
	var step: int = signi(delta)
	match layout:
		Layout.GEN1:
			return _adjust_gen1(step)
		Layout.YELLOW:
			return _adjust_yellow(step)
	match cursor:
		OPT_TEXT_SPEED:
			_options.text_speed = wrapi(
				_options.text_speed + step, 0, TEXT_SPEED_VALUES.size()
			)
		OPT_BATTLE_SCENE:
			_options.battle_scene = not _options.battle_scene
		OPT_BATTLE_STYLE:
			_options.battle_style_set = not _options.battle_style_set
		OPT_SOUND:
			_options.stereo = not _options.stereo
		OPT_PRINT:
			_options.printer_brightness = wrapi(
				_options.printer_brightness + step, 0, PRINT_VALUES.size()
			)
		OPT_MENU_ACCOUNT:
			_options.menu_account = not _options.menu_account
		## `maskbits NUM_FRAMES`, so it wraps rather than clamping.
		OPT_FRAME:
			_options.textbox_frame = wrapi(
				_options.textbox_frame + step, 0, Gen2Options.FRAME_COUNT
			)
		_:
			return false
	return true


## `.pressedLeftInTextSpeed` stops at FAST and `.pressedRightInTextSpeed` at
## SLOW, where the two toggles answer either direction with the other value.
func _adjust_gen1(step: int) -> bool:
	match cursor:
		GEN1_TEXT_SPEED:
			var speed: int = clampi(_options.text_speed + step, 0, TEXT_SPEED_VALUES.size() - 1)
			if speed == _options.text_speed:
				return false
			_options.text_speed = speed
		GEN1_BATTLE_ANIMATION:
			_options.battle_scene = not _options.battle_scene
		GEN1_BATTLE_STYLE:
			_options.battle_style_set = not _options.battle_style_set
		_:
			return false
	return true


## Yellow's handlers wrap every cycle, `OptionsMenu_TextSpeed`'s `ld c, -1`
## included, and the two toggles answer either direction.
func _adjust_yellow(step: int) -> bool:
	match cursor:
		YELLOW_TEXT_SPEED:
			_options.text_speed = wrapi(_options.text_speed + step, 0, TEXT_SPEED_VALUES.size())
		YELLOW_ANIMATION:
			_options.battle_scene = not _options.battle_scene
		YELLOW_BATTLE_STYLE:
			_options.battle_style_set = not _options.battle_style_set
		YELLOW_SOUND:
			_options.earphone = wrapi(_options.earphone + step, 0, Gen2Options.EARPHONE_COUNT)
		YELLOW_PRINT:
			_options.printer_brightness = wrapi(
				_options.printer_brightness + step, 0, PRINT_VALUES.size()
			)
		_:
			return false
	return true


## Which of a Generation 1 row's values is chosen; the first three rows are the
## same fields on both layouts.
func gen1_choice(index: int) -> int:
	match index:
		GEN1_TEXT_SPEED:
			return clampi(_options.text_speed, 0, TEXT_SPEED_VALUES.size() - 1)
		GEN1_BATTLE_ANIMATION:
			return 0 if _options.battle_scene else 1
		GEN1_BATTLE_STYLE:
			return 1 if _options.battle_style_set else 0
		YELLOW_SOUND:
			return clampi(_options.earphone, 0, Gen2Options.EARPHONE_COUNT - 1)
		YELLOW_PRINT:
			return clampi(_options.printer_brightness, 0, PRINT_VALUES.size() - 1)
	return 0


## One `{index, label, value}` per row for a renderer. CANCEL carries an empty
## value, since the source prints no setting beside it. A Generation 1 row
## carries its own table row and the `choice` among its values instead.
func rows() -> Array:
	var built: Array = []
	if layout != Layout.CRYSTAL:
		for row: Dictionary in _rows():
			var gen1_row: Dictionary = row.duplicate()
			gen1_row["choice"] = gen1_choice(int(row["index"]))
			built.append(gen1_row)
		return built
	for row: Dictionary in ROWS:
		built.append({
			"index": int(row["index"]),
			"label": String(row["label"]),
			"value": _value_label(int(row["index"])),
		})
	return built


func _value_label(index: int) -> String:
	match index:
		OPT_TEXT_SPEED:
			return TEXT_SPEED_VALUES[
				clampi(_options.text_speed, 0, TEXT_SPEED_VALUES.size() - 1)
			]
		OPT_BATTLE_SCENE:
			return "ON" if _options.battle_scene else "OFF"
		OPT_BATTLE_STYLE:
			return "SET" if _options.battle_style_set else "SHIFT"
		OPT_SOUND:
			return "STEREO" if _options.stereo else "MONO"
		OPT_PRINT:
			return PRINT_VALUES[
				clampi(_options.printer_brightness, 0, PRINT_VALUES.size() - 1)
			]
		OPT_MENU_ACCOUNT:
			return "ON" if _options.menu_account else "OFF"
		## `UpdateFrame` draws the stored 0-7 with `add '1'`.
		OPT_FRAME:
			return "TYPE %d" % (clampi(_options.textbox_frame, 0, Gen2Options.FRAME_COUNT - 1) + 1)
		_:
			return ""
