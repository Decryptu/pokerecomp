class_name Gen2LauncherHintBar
extends Control

## The row of [Gen2LauncherHint] chips along the bottom of a launcher screen and
## the keyboard and pad routes that answer them. A screen declares what it does
## once, as data, and that declaration is the chips, the presses on them and the
## shortcut: a legend written apart from what it names goes stale.

## Actions the bar answers. Accept is not one: it belongs to the focus ring.
const ACTIONS: Array[StringName] = [&"ui_cancel", &"ui_menu"]

var _theme: Gen2LauncherTheme = null
var _row: HBoxContainer = null
var _handlers: Dictionary = {}
var _hints: Dictionary = {}


static func create(palette: Gen2LauncherTheme) -> Gen2LauncherHintBar:
	var bar := Gen2LauncherHintBar.new()
	bar._theme = palette
	bar._build()
	return bar


func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row = Gen2LauncherUI.row(Gen2LauncherUI.GAP_SM)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)


## Replaces what the bar offers: dictionaries of `action`, `label` and `run`. An
## action outside [constant ACTIONS] is drawn but not listened for.
func set_hints(entries: Array) -> void:
	Gen2LauncherUI.clear(_row)
	_handlers.clear()
	_hints.clear()
	for entry: Dictionary in entries:
		var action := StringName(entry.get("action", &""))
		var hint: Gen2LauncherHint = Gen2LauncherHint.create(
			_theme, action, String(entry.get("label", ""))
		)
		var run: Variant = entry.get("run")
		if run is Callable:
			hint.pressed.connect(run as Callable)
			_handlers[action] = run
		_row.add_child(hint)
		_hints[action] = hint
	visible = not entries.is_empty()


func hint_for(action: StringName) -> Gen2LauncherHint:
	return _hints.get(action)


func actions() -> Array:
	return _hints.keys()


func band_height() -> float:
	return Gen2LauncherUI.TOUCH_TARGET


func _behind_a_modal() -> bool:
	for node: Node in get_tree().get_nodes_in_group(Gen2FocusGuard.MODAL_GROUP):
		var modal := node as Control
		if modal != null and modal.is_visible_in_tree() and not modal.is_ancestor_of(self):
			return true
	return false


## Unhandled rather than [method Control._gui_input]: the bar never holds focus,
## and a control that wanted the key has already had it.
func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _behind_a_modal():
		return
	for action: StringName in ACTIONS:
		if not _handlers.has(action) or not event.is_action_pressed(action):
			continue
		accept_event()
		get_viewport().set_input_as_handled()
		Gen2LauncherAudio.play(&"click")
		(_handlers[action] as Callable).call()
		return
