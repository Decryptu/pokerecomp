class_name Gen3FieldMenu
extends RefCounted # `script_menu.c`'s `yesnobox` and `multichoice` windows and input tasks, on [Gen3FieldMessage]'s BG0.

const NOTHING: int = -1
const B_RESULT: int = 127
const MAX_WIDTH: Dictionary = {&"ruby": 28, &"firered": 28, &"emerald": 28}
const ROW_HEIGHT: Dictionary = {&"ruby": 16, &"firered": 14, &"emerald": 16}
const ROW_TOP: Dictionary = {&"ruby": 1, &"firered": 2, &"emerald": 1}
const FRLG_HEIGHTS: Array[int] = [1, 2, 4, 6, 7, 9, 11, 13, 14] # GetMCWindowHeight.
const YES_NO: Dictionary = {&"ruby": Rect2i(21, 9, 5, 4), &"firered": Rect2i(21, 9, 6, 4), &"emerald": Rect2i(21, 9, 5, 4)}
const YES_NO_DELAY: int = 5
const CHOICE_DELAY: Dictionary = {&"ruby": 2, &"firered": 0, &"emerald": 2}
const CURSOR: int = 0xEF # ▶.

var active: bool = false
var _message: Gen3FieldMessage
var _engine: StringName
var _area := Rect2i()
var _cursor: int = 0
var _count: int = 0
var _columns: int = 1
var _column_width: int = 0
var _yes_no: bool = false
var _ignore_b: bool = false
var _wrap: bool = false
var _delay: int = 0


func _init(message: Gen3FieldMessage, engine: StringName) -> void:
	_message = message
	_engine = engine


func open(request: Dictionary) -> void: # ScriptMenu_YesNo, ScriptMenu_Multichoice and ScriptMenu_MultichoiceGrid.
	var choices: Array = request["choices"]
	_yes_no = request.get("yes_no", false)
	_ignore_b = request.get("ignore_b", false)
	_columns = maxi(int(request.get("columns", 1)), 1)
	_count = choices.size()
	_cursor = int(request.get("default", 0))
	_wrap = _count > 3
	_delay = YES_NO_DELAY if _yes_no else CHOICE_DELAY[_engine]
	var width: int = 0
	var lines: Array[PackedByteArray] = []
	for choice: String in choices:
		lines.append(Gen3Text.encode(choice))
		width = maxi(width, _message.text_width(lines.back()))
	var cells: int = mini((width + 9) / 8 + 1, MAX_WIDTH[_engine])
	_column_width = cells * 8
	_area = _window(request, cells)
	_message.draw_window(_area, Gen3FieldMessage.MENU_TILE)
	for index: int in _count:
		var at: Vector2i = _cell(index) + Vector2i(8, 0)
		_message.print_on(Gen3FieldMessage.MENU_TILE, _area.size, at, lines[index])
	_draw_cursor()
	active = true


func step(pressed: Array[int], requests: Array) -> int: # The result the script reads, or [constant NOTHING].
	if not active:
		return NOTHING
	if _delay > 0:
		_delay -= 1
		return NOTHING
	if PokeButton.A in pressed:
		requests.append({"kind": "sound", "name": "select"})
		return _close(int(_cursor == 0) if _yes_no else _cursor)
	if PokeButton.B in pressed and not _ignore_b:
		requests.append({"kind": "sound", "name": "select"})
		return _close(0 if _yes_no else B_RESULT)
	for button: int in pressed:
		_move(button, requests)
	return NOTHING


func _close(result: int) -> int:
	active = false
	_message.erase_window(_area)
	return result


func _window(request: Dictionary, cells: int) -> Rect2i:
	if _yes_no:
		return YES_NO[_engine]
	var rows: int = ceili(float(_count) / _columns)
	var height: int = (FRLG_HEIGHTS[rows] if rows < FRLG_HEIGHTS.size() else 1) if _engine == &"firered" else rows * 2
	var width: int = _columns * cells
	var left: int = int(request["left"])
	if left + width > MAX_WIDTH[_engine]:
		left = maxi(MAX_WIDTH[_engine] - width, 0)
	return Rect2i(left, int(request["top"]), width, height)


func _cell(index: int) -> Vector2i:
	var row: int = index / _columns
	return Vector2i(index % _columns * _column_width, row * int(ROW_HEIGHT[_engine]) + int(ROW_TOP[_engine]))


func _move(button: int, requests: Array) -> void:
	var delta: int = 0
	match button:
		PokeButton.UP: delta = -_columns
		PokeButton.DOWN: delta = _columns
		PokeButton.LEFT: delta = -1 if _columns > 1 else 0
		PokeButton.RIGHT: delta = 1 if _columns > 1 else 0
	if delta == 0:
		return
	var next: int = _cursor + delta
	if _wrap and _columns == 1:
		next = posmod(next, _count)
	next = clampi(next, 0, _count - 1)
	if next == _cursor:
		return
	requests.append({"kind": "sound", "name": "select"})
	var old: Vector2i = _cell(_cursor)
	_message.clear_rect_on(Gen3FieldMessage.MENU_TILE, _area.size, Rect2i(old, Vector2i(8, 14)))
	_cursor = next
	_draw_cursor()


func _draw_cursor() -> void:
	_message.print_on(Gen3FieldMessage.MENU_TILE, _area.size, _cell(_cursor), PackedByteArray([CURSOR]))
