class_name Gen2LauncherButton
extends Button

## Every button the launcher draws, in the weights it uses. Godot lays out a
## button's own icon and label, so the glyph is handed over as a texture rather
## than parked by hand; what this adds is the palette, the press sound and a
## hover that lifts the tabs.

enum Variant {
	## The one action a screen is about: a filled accent pill.
	PRIMARY,
	## A chip that fills with the accent when it is reached.
	NEUTRAL,
	## A hairline and nothing else until it is reached. The outline is what says
	## a control rather than a caption: without one "Which bugs..." was read as
	## the line of text above it.
	QUIET,
	## Quiet, but standing on the toast's chip rather than on the page. The
	## page's own muted ink is all but invisible against a surface that is the
	## opposite side of the page from it.
	ON_CHIP,
	## Destructive, tinted with the error colour.
	DANGER,
	## One choice inside a segmented track.
	SEGMENT,
	## One page in the top tab strip: a pill carrying a glyph, and its name too
	## where the row is wide enough.
	TAB,
}

const ICON_SIDE: float = 23.0
## The pill a tab is drawn in, and the square it shrinks to with no room for its
## name. [constant Gen2LauncherUI.TOUCH_TARGET]: it is pressed while walking.
const TAB_HEIGHT: float = 48.0

var variant: Variant = Variant.NEUTRAL
## Played on press. A cartridge action overrides it with its own clip.
var sound: StringName = &"click"

var _theme: Gen2LauncherTheme = null
var _glyph: StringName = &""
## Whether this is the current choice in its group. Kept here rather than on
## [member BaseButton.button_pressed], which only means anything to a toggle.
var _active: bool = false
## Whether a pointer is over the button or a pad is on it. The icon is a raster
## rather than a themed colour, so reaching a button has to repaint rather than
## swap a stylebox.
var _lit: bool = false
var _side: float = TAB_HEIGHT


static func create(
	palette: Gen2LauncherTheme,
	label: String,
	kind: Variant = Variant.NEUTRAL,
	glyph: StringName = &"",
) -> Gen2LauncherButton:
	var button := Gen2LauncherButton.new()
	button._theme = palette
	button.variant = kind
	button.text = label
	button._glyph = glyph
	button.custom_minimum_size = Vector2(0, 42)
	button.repaint()
	return button


static func icon_only(
	palette: Gen2LauncherTheme,
	glyph: StringName,
	kind: Variant = Variant.QUIET,
	side: float = 42.0,
) -> Gen2LauncherButton:
	var button: Gen2LauncherButton = create(palette, "", kind, glyph)
	button.set_side(side)
	return button


## Resizes a round or square icon button, keeping it circular. A [BoxContainer]
## stretches its children across the row, so without the shrink a disc beside a
## taller button is drawn as an ellipse.
func set_side(side: float) -> void:
	_side = side
	custom_minimum_size = Vector2(side, side)
	size = Vector2(side, side)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	repaint()


static func tab(
	palette: Gen2LauncherTheme, glyph: StringName, label: String
) -> Gen2LauncherButton:
	var button: Gen2LauncherButton = create(palette, label, Variant.TAB, glyph)
	button.custom_minimum_size = Vector2(0, TAB_HEIGHT)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return button


## Drops or restores a tab's words. The glyph stays either way.
func set_labelled(labelled: bool, label: String) -> void:
	text = label if labelled else ""
	custom_minimum_size = Vector2(0.0 if labelled else TAB_HEIGHT, TAB_HEIGHT)
	repaint()


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	add_theme_font_size_override("font_size", Gen2LauncherTheme.FONT_BODY)
	add_theme_constant_override("h_separation", 9)
	add_theme_constant_override("icon_max_width", int(ICON_SIDE))
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	focus_entered.connect(_on_hover.bind(true))
	focus_exited.connect(_on_hover.bind(false))
	pressed.connect(func() -> void: Gen2LauncherAudio.play(sound))
	resized.connect(_centre_pivot)


func set_glyph(glyph: StringName) -> void:
	_glyph = glyph
	repaint()


func is_active() -> bool:
	return _active


## Marks the button as the current choice in its group.
func set_active(active: bool) -> void:
	_active = active
	repaint()


func _paint() -> Dictionary:
	# Reached means hovered, focused or the current choice. The three look the
	# same on purpose: a pad moving onto a control has to read exactly as a
	# pointer resting on it.
	var reached: bool = _lit or _active
	var fill: Color = _theme.surface
	var border: Color = Color(0, 0, 0, 0)
	var ink: Color = _theme.on_surface
	# Only enough room either side of the glyph to keep it off the edge: a button
	# is mostly icon, which is what makes one readable at a glance and at a
	# distance.
	var pad_x: int = 0 if text.is_empty() else 20
	var pad_y: int = 8
	if variant == Variant.TAB:
		return _tab_paint()
	match variant:
		Variant.PRIMARY:
			fill = _theme.accent
			ink = _theme.on_accent
		Variant.QUIET:
			fill = _theme.accent_wash(0.13) if _active else Color(0, 0, 0, 0)
			border = _theme.accent_wash(0.45) if _active else _theme.line
			ink = _theme.accent if _active else _theme.muted
		Variant.ON_CHIP:
			fill = _theme.with_alpha(_theme.on_surface, 0.16) if reached else Color(0, 0, 0, 0)
			ink = _theme.with_alpha(_theme.on_surface, 1.0 if reached else 0.7)
		Variant.DANGER:
			fill = _theme.with_alpha(_theme.error, 0.12)
			border = _theme.with_alpha(_theme.error, 0.40)
			ink = _theme.error
		# The chosen segment is a chip in its track, so which one is chosen reads
		# from the fill rather than from a hairline around it.
		Variant.SEGMENT:
			fill = _theme.surface if _active else Color(0, 0, 0, 0)
			ink = _theme.on_surface if _active else _theme.muted
			pad_x = 14
			pad_y = 7
		# A plain chip: reaching it fills it with the accent.
		Variant.NEUTRAL:
			fill = _theme.accent if reached else _theme.surface
			ink = _theme.on_accent if reached else _theme.on_surface
	return {"fill": fill, "border": border, "ink": ink, "pad_x": pad_x, "pad_y": pad_y}


## A tab says two things where the rest of the set says one, so being current and
## being reached are drawn apart.
func _tab_paint() -> Dictionary:
	var fill: Color = Color(0, 0, 0, 0)
	var ink: Color = _theme.muted
	if _lit:
		fill = _theme.accent
		ink = _theme.on_accent
	elif _active:
		fill = _theme.surface
		ink = _theme.on_surface
	return {
		"fill": fill, "border": Color(0, 0, 0, 0), "ink": ink,
		"pad_x": 10 if text.is_empty() else 18, "pad_y": 8,
	}


func repaint() -> void:
	if _theme == null:
		return
	var radius: float = _radius()
	var paint: Dictionary = _paint()
	var fill: Color = paint["fill"]
	var border: Color = paint["border"]
	var ink: Color = paint["ink"]
	var pad_x: int = paint["pad_x"]
	var pad_y: int = paint["pad_y"]
	var icon_side: float = ICON_SIDE

	_style("normal", fill, border, radius, pad_x, pad_y)
	_style("hover", _hovered(fill), _hovered(border), radius, pad_x, pad_y)
	_style("pressed", _pressed_fill(fill), _hovered(border), radius, pad_x, pad_y)
	_style("disabled", _theme.with_alpha(fill, 0.4), _theme.with_alpha(border, 0.4),
		radius, pad_x, pad_y)
	# Focus is not hover or the active value. A heavy accent ring standing clear
	# of the button is always present, so keyboard and controller users can locate
	# the cursor even on a filled primary button or the already-selected tab,
	# where a flush ring would only read as a slightly larger button.
	add_theme_stylebox_override(
		"focus", _theme.padded(_theme.focus_ring(radius, 3), pad_x, pad_y)
	)

	for state: String in ["font_color", "font_hover_color", "font_pressed_color",
			"font_focus_color"]:
		add_theme_color_override(state, ink)
	add_theme_color_override("font_disabled_color", _theme.faint)
	add_theme_constant_override("icon_max_width", int(icon_side))
	if not _glyph.is_empty():
		icon = Gen2LauncherIcon.raster(
			_glyph, icon_side, _theme.faint if disabled else ink
		)
	# Godot gives the icon the left slot and the label the rest of the width, so
	# a button with no label leaves its icon hard against the left edge. Centring
	# the icon and dropping the separation is what puts it in the middle.
	icon_alignment = (
		HORIZONTAL_ALIGNMENT_LEFT if not text.is_empty() else HORIZONTAL_ALIGNMENT_CENTER
	)
	add_theme_constant_override("h_separation", 9 if not text.is_empty() else 0)


func set_disabled_state(off: bool) -> void:
	disabled = off
	repaint()


func _radius() -> float:
	match variant:
		Variant.PRIMARY, Variant.DANGER:
			return Gen2LauncherTheme.RADIUS_PILL
		Variant.TAB:
			return Gen2LauncherTheme.RADIUS_PILL
		Variant.SEGMENT:
			return Gen2LauncherTheme.RADIUS_SM - 2.0
	return Gen2LauncherTheme.RADIUS_SM


func _style(
	state: String, fill: Color, border: Color, radius: float, pad_x: int, pad_y: int,
	border_width: int = 1,
) -> void:
	add_theme_stylebox_override(
		state, _theme.padded(_theme.box(fill, radius, border, border_width), pad_x, pad_y)
	)


func _hovered(colour: Color) -> Color:
	if colour.a <= 0.0:
		return _theme.accent_wash(0.10) if variant != Variant.PRIMARY else colour
	return colour.lerp(_theme.text if variant == Variant.PRIMARY else _theme.accent, 0.14)


func _pressed_fill(colour: Color) -> Color:
	if colour.a <= 0.0:
		return _theme.accent_wash(0.18)
	return colour.darkened(0.10) if not _theme.is_dark() else colour.lightened(0.08)


func _centre_pivot() -> void:
	pivot_offset = size * 0.5


## Only the tabs move: the strip is the launcher's one place where a pointer
## wants to feel the target under it.
func _on_hover(entered: bool) -> void:
	if disabled:
		return
	# Focus and the pointer both count as reached, so a button the mouse has left
	# stays lit while a pad is still on it.
	var reached: bool = entered or has_focus() or is_hovered()
	if reached != _lit:
		_lit = reached
		repaint()
	if entered:
		Gen2LauncherAudio.play(&"hover")
	if variant != Variant.TAB or not is_inside_tree():
		return
	_centre_pivot()
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale", Vector2.ONE * (1.07 if entered else 1.0), 0.18)
