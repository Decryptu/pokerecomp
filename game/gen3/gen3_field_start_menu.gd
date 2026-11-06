class_name Gen3FieldStartMenu
extends RefCounted # `start_menu.c`'s action lists, window and input on [Gen3FieldMessage]'s BG0. Link, Union Room and frontier lists wait on those modes.

const FADE: String = "fade" # What [method step] returns besides "", an action of [constant LABELS] and these two.
const CLOSE: String = "close"
const RETIRE: String = "retire"
const SAVE: String = "save"
const EXIT: String = "exit"
const HELP_ROWS: int = 9 # `sStartMenuDescPointers`.
const NO_FADE: Array[String] = [SAVE, EXIT, RETIRE] # The callbacks HandleStartMenuInput sends to at once.
const LABELS: Dictionary = { # `MENU_ACTION_*`: rows of `sStartMenuItems`.
	&"ruby": {"pokedex": 0, "pokemon": 1, "bag": 2, "pokenav": 3, "player": 4, "save": 5, "option": 6, "exit": 7, "retire": 8},
	&"emerald": {"pokedex": 0, "pokemon": 1, "bag": 2, "pokenav": 3, "player": 4, "save": 5, "option": 6, "exit": 7, "retire": 8},
	&"firered": {"pokedex": 0, "pokemon": 1, "bag": 2, "player": 3, "save": 4, "option": 5, "exit": 6, "retire": 7},
}
const SAFARI_ACTIONS: Array[String] = ["retire", "pokedex", "pokemon", "bag", "player", "option", "exit"]
const FIRST_ROW: Dictionary = {&"ruby": 8, &"emerald": 9, &"firered": 0}
const ROW_HEIGHT: Dictionary = {&"ruby": 16, &"emerald": 16, &"firered": 15}
const TEXT_LEFT: Dictionary = {&"ruby": 0, &"emerald": 8, &"firered": 8}
const CURSOR: int = 0xEF # gText_SelectorArrow3.
const CURSOR_SIZE := Vector2i(8, 14)
const RUBY_CURSOR_SIZE := Vector2i(48, 16) # `menu_cursor.c`'s sprite is six tiles wide; its OBJ-window box is outlined here.
const BUILD_STEPS: int = 4 # InitStartMenuStep's cases before it prints two rows a frame, each a frame of StartMenuTask.
const INPUT_DELAY: int = 2 # SwitchTaskToFollowupFunc, then Task_ShowStartMenu's first case.

var active: bool = false
var _message: Gen3FieldMessage
var _engine: StringName
var _labels: Array = []
var _help: Array = []
var _placeholders: Callable
var _actions: Array[String] = []
var _area := Rect2i()
var _cursor: int = 0 # `sStartMenuCursorPos`, kept between openings.
var _show_help: bool = false
var _building: int = 0
var _delay: int = 0
var _leaving: String = ""


func _init(message: Gen3FieldMessage, engine: StringName, table: Dictionary, placeholders: Callable) -> void:
	_message = message
	_engine = engine
	_labels = table.get("labels", [])
	_help = table.get("help", [])
	_placeholders = placeholders


func open(events: Gen3EventData) -> void: # CreateStartMenuTask; the window appears when its build ends.
	_actions = _build_actions(events)
	_cursor = _cursor if _cursor < _actions.size() else 0
	_leaving = ""
	_show_help = not _help.is_empty()
	_building = BUILD_STEPS + ceili(_actions.size() / 2.0)
	_delay = INPUT_DELAY
	active = true


func step(pressed: Array[int], requests: Array, fading: bool) -> String:
	if not active:
		return ""
	if _building > 0:
		_building -= 1
		if _building == 0:
			_draw()
		return ""
	if _delay > 0:
		_delay -= 1
		return ""
	if _leaving != "":
		return _leave(fading)
	if PokeButton.UP in pressed:
		_move(-1, requests)
	if PokeButton.DOWN in pressed:
		_move(1, requests)
	if PokeButton.A in pressed:
		requests.append({"kind": "sound", "name": "select"})
		_leaving = _actions[_cursor]
		return "" if _leaving in NO_FADE else FADE
	if PokeButton.START in pressed or PokeButton.B in pressed:
		_erase()
		return CLOSE
	return ""


func _leave(fading: bool) -> String: # The chosen callback, which waits out the fade; FLAG_SYS_POKEDEX_GET comes with a seen Pokémon, so `GetNationalPokedexCount` cannot refuse.
	if fading:
		return ""
	var action: String = _leaving
	if action == SAVE:
		active = false # The window stays under the save prompt; [method Gen3FieldScreen.return_to_start_menu] redraws it.
		return action
	_erase()
	return CLOSE if action == EXIT else action


func _erase() -> void:
	active = false
	_message.erase_window(_area)
	if _show_help:
		_message.erase_help()


func _build_actions(events: Gen3EventData) -> Array[String]:
	var flags: Dictionary = Gen3FieldInput.FLAGS[_engine]
	if events.flag_get(int(flags["safari"])):
		return SAFARI_ACTIONS.duplicate()
	var out: Array[String] = []
	if events.flag_get(int(flags["pokedex"])):
		out.append("pokedex")
	if events.flag_get(int(flags["pokemon"])):
		out.append("pokemon")
	out.append("bag")
	if flags.has("pokenav") and events.flag_get(int(flags["pokenav"])):
		out.append("pokenav")
	out.append_array(["player", "save", "option", "exit"])
	return out


func _draw() -> void:
	var count: int = _actions.size()
	match _engine:
		&"ruby": _area = Rect2i(23, 1, 6, count * 2 + 2) # Menu_DrawStdWindowFrame(22, 0, 29, count * 2 + 3), frame included.
		&"emerald": _area = Rect2i(22, 1, 7, count * 2 + 2) # AddStartMenuWindow.
		&"firered": _area = Rect2i(22, 1, 7, count * 2 - 1) # CreateStartMenuWindow.
	_message.draw_window(_area, Gen3FieldMessage.MENU_TILE)
	var values: Dictionary = _placeholders.call()
	for index: int in count:
		var label: String = _labels[LABELS[_engine][_actions[index]]]
		_message.print_on(Gen3FieldMessage.MENU_TILE, _area.size, Vector2i(TEXT_LEFT[_engine], _row(index)),
			Gen3Text.encode(Gen3Text.expand_placeholders(label, values)))
	_draw_cursor()
	_draw_help()


func _row(index: int) -> int:
	return int(FIRST_ROW[_engine]) + index * int(ROW_HEIGHT[_engine])


func _draw_cursor() -> void:
	if _engine == &"ruby":
		_message.outline_on(Gen3FieldMessage.MENU_TILE, _area.size, Rect2i(0, _row(_cursor), RUBY_CURSOR_SIZE.x, RUBY_CURSOR_SIZE.y))
	else:
		_message.print_on(Gen3FieldMessage.MENU_TILE, _area.size, Vector2i(0, _row(_cursor)), PackedByteArray([CURSOR]))


func _clear_cursor() -> void:
	var size: Vector2i = RUBY_CURSOR_SIZE if _engine == &"ruby" else CURSOR_SIZE
	var rect := Rect2i(0, _row(_cursor), size.x, size.y)
	_message.clear_rect_on(Gen3FieldMessage.MENU_TILE, _area.size, rect)
	if _engine == &"ruby": # The box is drawn over the row, so the label comes back with it.
		var label: String = _labels[LABELS[_engine][_actions[_cursor]]]
		_message.print_on(Gen3FieldMessage.MENU_TILE, _area.size, Vector2i(0, _row(_cursor)),
			Gen3Text.encode(Gen3Text.expand_placeholders(label, _placeholders.call())))


func _move(delta: int, requests: Array) -> void: # Menu_MoveCursor wraps.
	requests.append({"kind": "sound", "name": "select"})
	_clear_cursor()
	_cursor = posmod(_cursor + delta, _actions.size())
	_draw_cursor()
	_draw_help()


func _draw_help() -> void: # `optionsButtonMode` starts on HELP and no OPTION screen can change it yet.
	if _show_help:
		var row: int = LABELS[_engine][_actions[_cursor]]
		_message.draw_help(Gen3Text.encode(String(_help[row])))
