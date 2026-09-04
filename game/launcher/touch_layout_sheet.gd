class_name Gen2TouchLayoutSheet
extends Control

## Arranging the on-screen controller: drag each cluster where a thumb wants it,
## and set how large and how solid it is. Full screen rather than a card, because
## what is being arranged is measured against the rectangle the game hands the
## controller and a preview in a box of its own would place it against the wrong
## one. The layout is per orientation and this edits the one the window is in;
## turning the device sideways is both how the other is reached and the only way
## to see what it will look like.

signal closed()

const SCALE_STEPS: int = 100
const OPACITY_STEPS: int = 100

var _theme: Gen2LauncherTheme = null
var _options: Gen2Options = null
var _pad: Gen2TouchPad = null
var _orientation: Label = null
var _toolbar_host: MarginContainer = null
var _fields: GridContainer = null


static func create(palette: Gen2LauncherTheme, options: Gen2Options) -> Gen2TouchLayoutSheet:
	var sheet := Gen2TouchLayoutSheet.new()
	sheet._theme = palette
	sheet._options = options
	sheet._build()
	return sheet


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	## A modal, so the arrows belong to it rather than to the page under it.
	add_to_group(Gen2FocusGuard.MODAL_GROUP)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = _theme.control_theme()

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_pad = Gen2TouchPad.new()
	# The live layout, not a copy: a drag edits the options object directly, so
	# there is nothing to write back when the editor closes.
	_pad.set_layout(_options.touch_layout)
	_pad.set_edit_mode(true)
	add_child(_pad)

	add_child(_toolbar())
	resized.connect(_refresh_orientation)
	ready.connect(_refresh_orientation, CONNECT_ONE_SHOT)
	_refresh_orientation()


func _toolbar() -> Control:
	var host := MarginContainer.new()
	_toolbar_host = host
	host.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	# The sheet opens against the top edge, which is where a phone keeps its
	# notch and its clock.
	var insets: Dictionary = Gen2LauncherUI.safe_area_insets(get_window())
	host.add_theme_constant_override("margin_left", 24 + int(insets["left"]))
	host.add_theme_constant_override("margin_right", 24 + int(insets["right"]))
	host.add_theme_constant_override("margin_top", 20 + int(insets["top"]))
	var card: Gen2LauncherCard = Gen2LauncherCard.floating(
		_theme, Gen2LauncherTheme.RADIUS_LG, 12, 30
	)
	host.add_child(card)
	var column: VBoxContainer = Gen2LauncherUI.column(Gen2LauncherUI.GAP_SM)
	card.add_child(column)

	var head: HBoxContainer = Gen2LauncherUI.row(Gen2LauncherUI.GAP_MD)
	column.add_child(head)
	var heading: Label = Gen2LauncherUI.title(_theme, "Arrange the buttons")
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(heading)
	var done: Gen2LauncherButton = Gen2LauncherButton.create(
		_theme, "Done", Gen2LauncherButton.Variant.PRIMARY, &"check"
	)
	done.pressed.connect(close)
	head.add_child(done)

	_orientation = Gen2LauncherUI.muted(_theme, "")
	column.add_child(_orientation)

	_fields = GridContainer.new()
	_fields.add_theme_constant_override("h_separation", 24)
	column.add_child(_fields)
	_fields.add_child(Gen2LauncherUI.level(
		_theme, &"touch", "Size",
		int(roundf(_options.touch_layout.scale * SCALE_STEPS)),
		int(PokeTouchLayout.MIN_SCALE * SCALE_STEPS),
		int(PokeTouchLayout.MAX_SCALE * SCALE_STEPS),
		func(value: int) -> void:
			_options.touch_layout.scale = float(value) / SCALE_STEPS
			_pad.queue_redraw()
	))
	_fields.add_child(Gen2LauncherUI.level(
		_theme, &"touch", "Opacity",
		int(roundf(_options.touch_layout.opacity * OPACITY_STEPS)),
		int(PokeTouchLayout.MIN_OPACITY * OPACITY_STEPS),
		int(PokeTouchLayout.MAX_OPACITY * OPACITY_STEPS),
		func(value: int) -> void:
			_options.touch_layout.opacity = float(value) / OPACITY_STEPS
			_pad.queue_redraw()
	))
	return host


## The rectangle the game will hand the controller, in the sheet's own units.
## Portrait keeps the map above it, so a cluster dragged to the middle of the
## whole screen would sit two thirds of the way down in play. The screen is a
## whole multiple of 160x144, so the split has to be worked out in the units the
## game measures it in and brought back.
func _place_pad() -> void:
	if _pad == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var unit: float = Gen2LauncherUI.game_unit_scale(get_window())
	var controls: Rect2 = Gen2GameFrame.split(
		size * unit, true, _options.screen_fill
	)["controls"]
	_pad.position = controls.position / unit
	_pad.size = controls.size / unit


func _refresh_orientation() -> void:
	if _orientation == null:
		return
	_place_pad()
	var landscape: bool = PokeTouchLayout.orientation_of(size) \
		== PokeTouchLayout.ORIENTATION_LANDSCAPE
	_orientation.visible = not landscape
	_fields.columns = 2 if landscape else 1
	var insets: Dictionary = Gen2LauncherUI.safe_area_insets(get_window())
	_toolbar_host.add_theme_constant_override("margin_left", 24 + int(insets["left"]))
	_toolbar_host.add_theme_constant_override("margin_right", 24 + int(insets["right"]))
	_toolbar_host.add_theme_constant_override("margin_top", (8 if landscape else 20) + int(insets["top"]))
	var arranging: StringName = _pad.orientation()
	_orientation.text = (
		"Drag each group. This is the %s arrangement; turn the device to set the other."
		% ("sideways" if arranging == PokeTouchLayout.ORIENTATION_LANDSCAPE else "upright")
	)


func open(host: Control) -> void:
	host.add_child(self)


## The layout being edited is the live one, so nothing has to be copied back.
## Writing it is the caller's, on [signal closed]: a slider dragged across its
## track would otherwise be one disk write per pixel.
func close() -> void:
	_pad.set_edit_mode(false)
	Gen2InputRuntime.instance().apply_options(_options)
	closed.emit()
	Gen2Screen.drop(self)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		accept_event()
		close()
