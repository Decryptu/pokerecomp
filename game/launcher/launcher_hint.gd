class_name Gen2LauncherHint
extends Button

## One action, drawn as the control that performs it and the words for what it
## does: the "B Close" chip a console puts along the bottom of every screen. The
## badge comes out of the [InputMap] for the device in hand, so a rebind, a pad
## arriving and a hand leaving the keys each change it; a pointer has no button
## to print, so the chip is pressed rather than read.

const BADGE_MIN: float = 26.0
const BADGE_PAD_X: float = 8.0

var _theme: Gen2LauncherTheme = null
var _action: StringName = &""
var _row: HBoxContainer = null
var _badge: Gen2HintBadge = null
var _label: Label = null
var _lit: bool = false


## [param bound] is an [InputMap] name; [param words] say what pressing it does.
static func create(
	palette: Gen2LauncherTheme, bound: StringName, words: String
) -> Gen2LauncherHint:
	var hint := Gen2LauncherHint.new()
	hint._theme = palette
	hint._action = bound
	hint._build(words)
	return hint


func _build(words: String) -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	size_flags_vertical = Control.SIZE_SHRINK_CENTER

	_row = Gen2LauncherUI.row(Gen2LauncherUI.GAP_SM)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_row)
	var row: HBoxContainer = _row
	_badge = Gen2HintBadge.new()
	_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_badge)
	_label = Gen2LauncherUI.body(_theme, words)
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_label)

	mouse_entered.connect(_on_reached.bind(true))
	mouse_exited.connect(_on_reached.bind(false))
	focus_entered.connect(_on_reached.bind(true))
	focus_exited.connect(_on_reached.bind(false))
	pressed.connect(func() -> void: Gen2LauncherAudio.play(&"click"))
	var input: Gen2InputRuntime = Gen2InputRuntime.instance()
	if input != null:
		input.device_changed.connect(func(_kind: StringName) -> void: refresh())
		input.scheme_changed.connect(refresh)
	# A label reports no width until it has a font, so it is measured again.
	tree_entered.connect(_measure)
	_row.minimum_size_changed.connect(_measure)
	refresh()


func set_label(words: String) -> void:
	_label.text = words
	_measure()


## A [Button] answers its own minimum size in C++ and calls no script's.
func _measure() -> void:
	if _row == null:
		return
	var chrome: StyleBox = get_theme_stylebox(&"normal")
	if chrome == null:
		return
	var wanted: Vector2 = _row.get_combined_minimum_size() + chrome.get_minimum_size()
	custom_minimum_size = Vector2(wanted.x, maxf(wanted.y, Gen2LauncherUI.TOUCH_TARGET))
	_row.offset_left = chrome.get_margin(SIDE_LEFT)
	_row.offset_right = -chrome.get_margin(SIDE_RIGHT)


## Lets a pad rest on this chip: off for a legend, on for a sheet's way out.
func set_focusable(on: bool) -> void:
	focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE
	refresh()


func action() -> StringName:
	return _action


func badge_text() -> String:
	return _badge.text


func refresh() -> void:
	if _theme == null:
		return
	var input: Gen2InputRuntime = Gen2InputRuntime.instance()
	var device: StringName = input.device() if input != null else PokeInputDevice.KEYBOARD
	var layout: StringName = input.pad_layout() if input != null \
		else PokeInputActions.PAD_LAYOUT_AUTO
	var printed: String = "" if PokeInputDevice.is_pointer(device) \
		else PokeInputActions.action_badge(_action, device, layout)
	_badge.set_badge(_theme, printed, _lit)
	# A wordless chip with nothing printed on it is no legend at all.
	visible = not printed.is_empty() or not _label.text.is_empty()
	_label.add_theme_color_override(
		"font_color", _theme.on_surface if _lit else _theme.text
	)
	_label.add_theme_font_size_override("font_size", Gen2LauncherTheme.FONT_SMALL)
	var pad: int = int(BADGE_PAD_X) if printed.is_empty() else 10
	add_theme_stylebox_override("normal", _chip(pad, false))
	add_theme_stylebox_override("hover", _chip(pad, true))
	add_theme_stylebox_override("pressed", _chip(pad, true))
	add_theme_stylebox_override("disabled", _chip(pad, false))
	# A chip a pad can rest on gets the ring every other control gets.
	add_theme_stylebox_override("focus", _focus_chip(pad))
	_measure()


## The ring goes over the filled chip, never instead of it: the ink is the
## fill's, and a ring alone left light words on a light page.
func _focus_chip(pad: int) -> StyleBoxFlat:
	if focus_mode != Control.FOCUS_ALL:
		return _chip(pad, _lit)
	var style: StyleBoxFlat = _chip(pad, true)
	style.border_color = _theme.accent
	style.set_border_width_all(3)
	style.set_expand_margin_all(float(Gen2LauncherTheme.FOCUS_GAP))
	return style


func _chip(pad: int, filled: bool) -> StyleBoxFlat:
	var fill: Color = _theme.surface if filled else _theme.with_alpha(_theme.surface, 0.0)
	return _theme.padded(
		_theme.box(fill, Gen2LauncherTheme.RADIUS_PILL), pad + 4, 6
	)


func _on_reached(entered: bool) -> void:
	if entered == _lit:
		return
	_lit = entered
	if entered:
		Gen2LauncherAudio.play(&"hover")
	refresh()


## A rounded cap with the printed control in it.
class Gen2HintBadge extends Label:
	func _init() -> void:
		horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_badge(palette: Gen2LauncherTheme, printed: String, lit: bool) -> void:
		text = printed
		visible = not printed.is_empty()
		if not visible:
			custom_minimum_size = Vector2.ZERO
			return
		add_theme_font_size_override("font_size", Gen2LauncherTheme.FONT_SMALL)
		add_theme_color_override(
			"font_color", palette.surface if lit else palette.on_surface
		)
		var fill: Color = palette.on_surface if lit else palette.surface
		add_theme_stylebox_override("normal", palette.padded(
			palette.box(fill, Gen2LauncherHint.BADGE_MIN * 0.5),
			int(Gen2LauncherHint.BADGE_PAD_X), 0
		))
		# Never shorter than the square: two heights read as two kinds of thing.
		var wide: float = maxf(
			get_theme_font(&"font").get_string_size(
				printed, HORIZONTAL_ALIGNMENT_LEFT, -1.0, Gen2LauncherTheme.FONT_SMALL
			).x + Gen2LauncherHint.BADGE_PAD_X * 2.0,
			Gen2LauncherHint.BADGE_MIN,
		)
		custom_minimum_size = Vector2(wide, Gen2LauncherHint.BADGE_MIN)
