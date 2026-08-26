class_name Gen2LauncherUI
extends RefCounted

## Small shared pieces every launcher page builds from: text, rows, and the
## composite controls (segmented choice, number and slider) that replace Godot's
## own.

const GAP_XS: int = 4
const GAP_SM: int = 8
const GAP_MD: int = 14
const GAP_LG: int = 22
## The side a mod's icon is drawn at: a whole multiple of its native 32, so the
## cartridge's own pixels stay square.
const MOD_ICON_SIDE: float = 64.0
## Room around a dock disc before the page may put its final control underneath.
const DOCK_VERTICAL_PADDING: float = 28.0

## The smallest square a finger can be asked to hit, in launcher units. Apple
## and Google both name 44 and 48 device-independent points; the larger is used
## because a dock disc is aimed at while walking.
const TOUCH_TARGET: float = 48.0


## How many window pixels one launcher unit is drawn at, so that a unit is a
## device-independent point rather than a pixel.
##
## Every size the launcher is written in is a desktop pixel, which is a comfortable
## reading size only because a desktop screen is about 100 pixels to the inch. A
## phone is three to four times that, so the same numbers arrive at a third of the
## size and the window measures wide enough to be taken for a desktop. The screen's
## own backing scale is exactly that ratio, and iOS and Android both report it.
static func display_density() -> float:
	if preview_density > 0.0:
		return preview_density
	if not OS.has_feature("mobile"):
		return 1.0
	var scale: float = DisplayServer.screen_get_scale()
	if scale > 1.0:
		return scale
	# Android reports 1.0 here and puts the ratio in the dots per inch instead,
	# against the 160 that defines the density-independent pixel.
	var dpi: int = DisplayServer.screen_get_dpi()
	return clampf(float(dpi) / 160.0, 1.0, 4.0)


## Draws [param window] in launcher units. Set while a launcher screen is on and
## unset when it leaves, because the game is drawn in cartridge pixels and an
## integer upscale of a 160x144 screen must be computed against the real ones.
static func apply_display_density(window: Window, on: bool) -> void:
	if window == null:
		return
	var density: float = display_density() if on else 1.0
	# A desktop draws in points already, and so does a headless run, whose window
	# has no size to divide by.
	var base: Vector2 = Vector2(window.content_scale_size)
	var pixels: Vector2 = Vector2(window.size)
	if is_equal_approx(density, 1.0) or base.x <= 0.0 or base.y <= 0.0 or pixels.x <= 0.0:
		window.content_scale_factor = 1.0
		return
	# The project already stretches the window onto its base viewport, and the
	# factor multiplies that rather than replacing it, so the stretch has to be
	# divided back out for a unit to land on a point.
	var stretch: float = minf(pixels.x / base.x, pixels.y / base.y)
	window.content_scale_factor = clampf(density / maxf(stretch, 0.01), 0.25, 8.0)


## What the screen's own furniture takes out of [param window], in launcher
## units: the notch and the clock above, the home indicator below, and the
## rounded corners the display server counts into both. Zero everywhere the
## platform has nothing to say.
static func safe_area_insets(window: Window) -> Dictionary:
	var none: Dictionary = {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}
	if not preview_insets.is_empty():
		return preview_insets
	if window == null or not OS.has_feature("mobile"):
		return none
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var screen: Vector2i = DisplayServer.screen_get_size()
	if safe.size.x <= 0 or safe.size.y <= 0 or screen.x <= 0 or screen.y <= 0:
		return none
	# The safe area is given in screen pixels; a launcher unit is what the window
	# draws one at.
	var unit: float = maxf(float(window.size.x) / maxf(window.get_visible_rect().size.x, 1.0), 0.01)
	return {
		"left": maxf(float(safe.position.x), 0.0) / unit,
		"top": maxf(float(safe.position.y), 0.0) / unit,
		"right": maxf(float(screen.x - safe.end.x), 0.0) / unit,
		"bottom": maxf(float(screen.y - safe.end.y), 0.0) / unit,
	}


## Preview seams for `tools/preview_launcher.gd`, which runs on a desktop and so
## is told about a phone rather than asking one. Zero and empty mean ask the
## display server, which is every real run.
static var preview_density: float = 0.0
static var preview_insets: Dictionary = {}


## How much a scrolling page keeps clear along its bottom edge: the dock's own
## room plus whatever the screen takes under it for a home indicator.
static func dock_reserve(window: Window) -> float:
	var viewport_size: Vector2 = window.get_visible_rect().size if window != null else Vector2.ZERO
	return Gen2LauncherShell.dock_side_for(viewport_size, 4, safe_area_insets(window)) \
		+ DOCK_VERTICAL_PADDING + float(safe_area_insets(window)["bottom"])



static func title(theme: Gen2LauncherTheme, text: String, size: int = Gen2LauncherTheme.FONT_TITLE) -> Label:
	return _label(text, size, theme.text)


static func body(theme: Gen2LauncherTheme, text: String) -> Label:
	return _label(text, Gen2LauncherTheme.FONT_BODY, theme.text)


static func muted(theme: Gen2LauncherTheme, text: String) -> Label:
	var label: Label = _label(text, Gen2LauncherTheme.FONT_SMALL, theme.muted)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## A section marker: small, spaced capitals in the faint colour.
static func caption(theme: Gen2LauncherTheme, text: String) -> Label:
	var label: Label = _label(text.to_upper(), Gen2LauncherTheme.FONT_TINY, theme.faint)
	label.add_theme_constant_override("outline_size", 0)
	return label


static func column(separation: int = GAP_MD) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	return box


## A row of buttons that wraps onto a second line rather than widening its page.
## A narrow window is the ordinary case on a phone held upright, and the launcher
## pages scroll vertically only.
static func actions(separation: int = GAP_SM) -> HFlowContainer:
	var box := HFlowContainer.new()
	box.add_theme_constant_override("h_separation", separation)
	box.add_theme_constant_override("v_separation", separation)
	return box


static func row(separation: int = GAP_MD) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	return box


## Empties a container that is about to be rebuilt.
##
## Every launcher pane is rebuilt from a button inside it, so the node emitting
## `pressed` is one of the children being removed and `free()` there destroys an
## object the signal is still walking. Detaching first takes the child out of the
## rebuilt list at once and leaves the deletion to the end of the frame.
static func clear(container: Node) -> void:
	if container == null:
		return
	Gen2Screen.drop_children(container)


static func spacer() -> Control:
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


static func dock_safe_space() -> Control:
	var gap := Control.new()
	gap.custom_minimum_size.y = Gen2LauncherButton.DOCK_SIDE + DOCK_VERTICAL_PADDING
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The home indicator's height is only knowable once there is a window to ask.
	gap.tree_entered.connect(
		func() -> void: gap.custom_minimum_size.y = dock_reserve(gap.get_window())
	)
	return gap


## How wide a control wants to be, which is its minimum unless it holds a row
## that wraps: such a row measures as one column, so a [FieldRow] would squeeze a
## whole track into a column even where it fits unwrapped. A control that wraps
## points at the row with `wrapping_row`, and this adds back what wrapping hid.
## Measured on the call rather than stored, because a minimum is not settled
## until the control is in a tree with a font.
static func preferred_width(control: Control) -> float:
	var minimum: float = control.get_combined_minimum_size().x
	if not control.has_meta(&"wrapping_row"):
		return minimum
	var flow := control.get_meta(&"wrapping_row") as HFlowContainer
	if flow == null:
		return minimum
	var wanted: float = 0.0
	var widest: float = 0.0
	var counted: int = 0
	for child: Node in flow.get_children():
		var item := child as Control
		if item == null or not item.visible:
			continue
		var item_wide: float = item.get_combined_minimum_size().x
		wanted += item_wide
		widest = maxf(widest, item_wide)
		counted += 1
	if counted == 0:
		return minimum
	wanted += float((counted - 1) * flow.get_theme_constant(&"h_separation", &"HFlowContainer"))
	return minimum - widest + wanted


## Label on the left, control on the right, which is every settings line.
static func field(theme: Gen2LauncherTheme, text: String, control: Control) -> Container:
	var line := FieldRow.new()
	var label: Label = body(theme, text)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(label)
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(control)
	return line


## The two halves of a [method field], side by side while they both fit and
## stacked when they do not.
##
## Every launcher page scrolls vertically only, so a row wider than the window is
## cut off rather than reachable, and a settings row is exactly the shape that
## outgrows a portrait phone: the label wants its whole text and the control
## carries its own minimum width. Stacking is what keeps the control on screen.
class FieldRow extends Container:
	func _init() -> void:
		resized.connect(update_minimum_size)

	func _halves() -> Array[Control]:
		var found: Array[Control] = []
		for child: Node in get_children():
			var control := child as Control
			if control != null and control.visible:
				found.append(control)
		return found

	## Measured against the width actually given, which is why the row asks to be
	## re-measured whenever it is resized.
	func _stacks(halves: Array[Control]) -> bool:
		var wanted: float = halves[0].get_combined_minimum_size().x \
			+ float(GAP_MD) + Gen2LauncherUI.preferred_width(halves[1])
		return size.x > 0.0 and size.x < wanted

	func _get_minimum_size() -> Vector2:
		var halves: Array[Control] = _halves()
		if halves.size() < 2:
			return Vector2.ZERO
		var label: Vector2 = halves[0].get_combined_minimum_size()
		var control: Vector2 = halves[1].get_combined_minimum_size()
		# The width asked for is the control's alone, never the whole row's: a row
		# that asked for both halves would be granted them, and would then always
		# measure as fitting and never stack. The label is what gives instead.
		if _stacks(halves):
			return Vector2(control.x, label.y + float(GAP_XS) + control.y)
		return Vector2(control.x, maxf(label.y, control.y))

	func _notification(what: int) -> void:
		if what != NOTIFICATION_SORT_CHILDREN:
			return
		var halves: Array[Control] = _halves()
		if halves.size() < 2:
			return
		var label: Vector2 = halves[0].get_combined_minimum_size()
		if _stacks(halves):
			fit_child_in_rect(halves[0], Rect2(0.0, 0.0, size.x, label.y))
			fit_child_in_rect(halves[1], Rect2(
				0.0, label.y + float(GAP_XS), size.x, size.y - label.y - float(GAP_XS)
			))
			return
		var control_width: float = Gen2LauncherUI.preferred_width(halves[1])
		var label_width: float = maxf(size.x - control_width - float(GAP_MD), 0.0)
		fit_child_in_rect(halves[0], Rect2(0.0, 0.0, label_width, size.y))
		fit_child_in_rect(halves[1], Rect2(
			label_width + float(GAP_MD), 0.0, control_width, size.y
		))


## A row of choices in one track, the chosen one filled.
static func segmented(
	theme: Gen2LauncherTheme, choices: Array, selected: int, handler: Callable
) -> Control:
	var track: Gen2LauncherCard = Gen2LauncherCard.well(theme, Gen2LauncherTheme.RADIUS_SM, 3)
	# Wraps for the same reason [FieldRow] stacks: a five-choice track is wider
	# than a phone held upright, and the page it sits in has no second axis.
	var line: HFlowContainer = actions(2)
	track.add_child(line)
	var buttons: Array[Gen2LauncherButton] = []
	for index: int in choices.size():
		var button: Gen2LauncherButton = Gen2LauncherButton.create(
			theme, String(choices[index]), Gen2LauncherButton.Variant.SEGMENT
		)
		button.custom_minimum_size = Vector2(0, 30)
		button.add_theme_font_size_override("font_size", Gen2LauncherTheme.FONT_SMALL)
		buttons.append(button)
		line.add_child(button)
		button.pressed.connect(func() -> void:
			for other: Gen2LauncherButton in buttons:
				other.set_active(false)
			button.set_active(true)
			handler.call(index)
		)
	if selected >= 0 and selected < buttons.size():
		buttons[selected].set_active(true)
	track.set_meta(&"wrapping_row", line)
	return track


## One whole number, typed or stepped. A slider is the wrong shape for a value
## whose range is wide and whose exact digits matter, which is what a mod's
## number setting usually is.
static func number(
	theme: Gen2LauncherTheme, value: int, minimum: int, maximum: int, step: int,
	handler: Callable,
) -> Control:
	var box := SpinBox.new()
	box.min_value = minimum
	box.max_value = maximum
	box.step = maxi(step, 1)
	box.value = value
	box.select_all_on_focus = true
	box.custom_minimum_size = Vector2(120, 0)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var field_edit: LineEdit = box.get_line_edit()
	field_edit.add_theme_font_size_override("font_size", Gen2LauncherTheme.FONT_SMALL)
	field_edit.add_theme_color_override("font_color", theme.text)
	box.value_changed.connect(func(changed: float) -> void: handler.call(int(changed)))
	return box


## [param format] spells the readout, for a row the cartridge shows as something
## other than the byte it stores: OPTION's own frame row is `UpdateFrame`'s
## `add '1'`, so a stored 0 reads TYPE 1. Omitted, the readout is the number.
static func slider(
	theme: Gen2LauncherTheme, value: int, minimum: int, maximum: int, handler: Callable,
	format: Callable = Callable()
) -> Control:
	var spell: Callable = format if format.is_valid() \
		else func(amount: int) -> String: return str(amount)
	var line: HBoxContainer = row(GAP_MD)
	var bar := HSlider.new()
	bar.min_value = minimum
	bar.max_value = maximum
	bar.step = 1
	bar.value = value
	bar.custom_minimum_size = Vector2(170, 22)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var readout: Label = muted(theme, spell.call(value))
	readout.custom_minimum_size = Vector2(52, 0)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.value_changed.connect(func(changed: float) -> void:
		readout.text = spell.call(int(changed))
		handler.call(int(changed))
	)
	line.add_child(bar)
	line.add_child(readout)
	return line


## The one file picker every launcher dialog is built from. The platform
## reasoning, and what shows it, are in [Gen2LauncherFilePicker].
static func file_picker(
	theme: Gen2LauncherTheme,
	title_text: String,
	mode: FileDialog.FileMode,
	filters: PackedStringArray
) -> Gen2LauncherFilePicker:
	return Gen2LauncherFilePicker.create(theme, title_text, mode, filters)


## The square a mod's icon is drawn in, on a list row and on its own page.
##
## Always the same node whether or not there is a picture, because the alternative
## is a list whose names start at two different places depending on whose mod it
## is. A mod with no icon gets the generic glyph, greyed, in the same square.
##
## Nearest filtering, and never stretched: an icon is 32x32 pixel art drawn at
## about 40, so smoothing it would blur exactly the edges it is made of, and
## letting it fill a square it is not square for would distort it.
static func mod_icon(
	theme: Gen2LauncherTheme, texture: Texture2D, side: float = MOD_ICON_SIDE
) -> Control:
	if texture == null:
		var glyph: Gen2LauncherIcon = Gen2LauncherIcon.create(&"mods", side * 0.62, theme.faint)
		glyph.custom_minimum_size = Vector2(side, side)
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return glyph
	var art := TextureRect.new()
	art.texture = texture
	art.custom_minimum_size = Vector2(side, side)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return art


## Swaps the picture into a square [method mod_icon] already drew, for an icon
## that arrived from the network after its row was built. A square holding the
## fallback glyph answers false and is replaced by its owner instead:
## [Gen2LauncherIcon] is a [TextureRect] too, so filling one would leave a node
## that draws a mod's art while still believing it is a tinted glyph.
static func set_mod_icon(square: Control, texture: Texture2D) -> bool:
	if square is Gen2LauncherIcon or square is not TextureRect or texture == null:
		return false
	(square as TextureRect).texture = texture
	return true


static func _label(text: String, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	return label
