class_name Gen2LauncherUI
extends RefCounted

## Small shared pieces every launcher page builds from: text, rows, and the
## setting row every option in this project is drawn as.

const GAP_XS: int = 4
const GAP_SM: int = 8
const GAP_MD: int = 14
const GAP_LG: int = 22
## A whole multiple of a mod icon's native 32, so its pixels stay square.
const MOD_ICON_SIDE: float = 64.0
## Room around the hint bar before the page may put its final control underneath.
const BAR_VERTICAL_PADDING: float = 24.0

## The smallest square a finger can be asked to hit, in launcher units. Apple
## and Google both name 44 and 48 device-independent points; the larger is used
## because a chip on the bottom bar is aimed at while walking.
const TOUCH_TARGET: float = 48.0


## Whether this display server hands out the screen's own pixels rather than
## points. A platform that cannot open a second window is one whose window is the
## whole screen, and every one of them measures in physical pixels. Asked of the
## display server rather than of a list of platform names, so a console this
## project has not met yet is covered on the day it arrives. A headless run
## answers no to every feature there is, so it is asked first whether it draws at
## all; without that a test tier would measure itself as a handheld.
static func draws_in_screen_pixels() -> bool:
	return (
		DisplayServer.window_can_draw()
		and not DisplayServer.has_feature(DisplayServer.FEATURE_SUBWINDOWS)
	)


## How many window pixels one launcher unit is drawn at, so a unit is a
## device-independent point rather than a pixel. Every size the launcher is
## written in is a desktop pixel, comfortable only because a desktop screen is
## about 100 pixels to the inch; a phone is three to four times that, so the same
## numbers arrive at a third of the size and the window measures wide enough to be
## taken for a desktop. iOS and Android both report the backing scale. A Switch
## reports neither: 237 dots per inch in the hands and 96 in the dock, which the
## same formula turns into 1.5 and 1.
static func display_density() -> float:
	if preview_density > 0.0:
		return preview_density
	if not draws_in_screen_pixels():
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
	if is_equal_approx(density, 1.0) or window.size.x <= 0:
		window.content_scale_factor = 1.0
		return
	# The project already stretches the window onto its base viewport, and the
	# factor multiplies that rather than replacing it, so the stretch has to be
	# divided back out for a unit to land on a point.
	window.content_scale_factor = clampf(
		density / maxf(base_stretch(window), 0.01), 0.25, 8.0
	)


## Keeps [param root]'s window drawn in launcher units for as long as [param root]
## is in the tree, and puts it back when it leaves.
##
## Every screen written in launcher units needs this and only those do, so it is
## a guard a screen attaches rather than something a shell happens to own: the
## save editor is drawn in the same units and has no shell, and without the
## factor it arrived on a phone at a third of its size. The factor is worked out
## against the window, so turning the device redoes it.
static func attach_density(root: Control) -> DensityGuard:
	var guard := DensityGuard.new()
	guard.name = "DensityGuard"
	root.add_child(guard)
	return guard


## See [method attach_density]. A node rather than a call so entering and leaving
## the tree, and the window changing size, are all one thing to get right.
class DensityGuard extends Node:
	func _enter_tree() -> void:
		var window: Window = get_window()
		Gen2LauncherUI.apply_display_density(window, true)
		if window != null and not window.size_changed.is_connected(_update):
			window.size_changed.connect(_update)

	func _exit_tree() -> void:
		var window: Window = get_window()
		if window != null and window.size_changed.is_connected(_update):
			window.size_changed.disconnect(_update)
		Gen2LauncherUI.apply_display_density(window, false)

	func _update() -> void:
		Gen2LauncherUI.apply_display_density(get_window(), true)


## How many window pixels one unit of the base viewport is drawn at before the
## density factor above. The game leaves the factor off and is drawn at exactly
## this, which is what puts a 160x144 screen on whole pixels.
static func base_stretch(window: Window) -> float:
	if window == null:
		return 1.0
	var base: Vector2 = Vector2(window.content_scale_size)
	var pixels: Vector2 = Vector2(window.size)
	if base.x <= 0.0 or base.y <= 0.0 or pixels.x <= 0.0 or pixels.y <= 0.0:
		return 1.0
	return minf(pixels.x / base.x, pixels.y / base.y)


static func point_scale(control: Control) -> float:
	var window: Window = control.get_window()
	if window == null or (not draws_in_screen_pixels() and preview_density <= 0.0):
		return 1.0
	var pixels_per_unit: float = float(window.size.x) / maxf(window.get_visible_rect().size.x, 1.0)
	pixels_per_unit *= control.get_global_transform_with_canvas().x.length()
	return display_density() / maxf(pixels_per_unit, 0.01)


## One launcher unit in the units the game is drawn in. The two differ by the
## density factor alone, and a rectangle the game works out from a whole multiple
## of 160x144 is not the same fraction of the screen in both.
static func game_unit_scale(window: Window) -> float:
	if window == null:
		return 1.0
	var here: float = float(window.size.x) / maxf(window.get_visible_rect().size.x, 1.0)
	return here / maxf(base_stretch(window), 0.01)


## What the screen's own furniture takes out of [param window], in launcher
## units: the notch and the clock above, the home indicator below, and the
## rounded corners the display server counts into both. Zero everywhere the
## platform has nothing to say.
static func safe_area_insets(window: Window) -> Dictionary:
	var none: Dictionary = {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}
	if not preview_insets.is_empty():
		return preview_insets
	if window == null or not draws_in_screen_pixels():
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


## How much a scrolling page keeps clear along its bottom edge: the hint bar's
## own room plus whatever the screen takes under it for a home indicator.
static func bottom_reserve(window: Window) -> float:
	var viewport_size: Vector2 = window.get_visible_rect().size if window != null else Vector2.ZERO
	return Gen2LauncherShell.bottom_band(viewport_size) \
		+ float(safe_area_insets(window)["bottom"])


static func bar_padding(viewport_size: Vector2) -> float:
	return 12.0 if viewport_size.x > viewport_size.y and viewport_size.y < 600.0 \
		else BAR_VERTICAL_PADDING


static func title(theme: Gen2LauncherTheme, text: String, size: int = Gen2LauncherTheme.FONT_TITLE) -> Label:
	return _label(text, size, theme.text)


static func body(theme: Gen2LauncherTheme, text: String) -> Label:
	return _label(text, Gen2LauncherTheme.FONT_BODY, theme.text)


static func muted(theme: Gen2LauncherTheme, text: String) -> Label:
	var label: Label = _label(text, Gen2LauncherTheme.FONT_SMALL, theme.muted)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## A muted word that does not wrap, for a line of short facts.
##
## [method muted] wraps, and a wrapping label reports almost no minimum width, so
## one dropped into a flow row or an expanding box is squeezed to a character a
## line. A fact is short enough to keep whole and long enough to be worth the
## helper.
static func tag(theme: Gen2LauncherTheme, text: String) -> Label:
	var label: Label = muted(theme, text)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
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


static func bottom_safe_space() -> Control:
	var gap := Control.new()
	gap.custom_minimum_size.y = TOUCH_TARGET + BAR_VERTICAL_PADDING
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The home indicator's height is only knowable once there is a window to ask.
	gap.tree_entered.connect(
		func() -> void: gap.custom_minimum_size.y = bottom_reserve(gap.get_window())
	)
	return gap


static func stacked(theme: Gen2LauncherTheme, text: String, control: Control) -> Control:
	var line: VBoxContainer = column(GAP_XS)
	line.add_child(tag(theme, text))
	line.add_child(control)
	return line


## One setting as a full-width row: a glyph, the name over its value, and the
## chevron that opens the choices. It replaced a label beside a segmented track,
## which was a focus stop per choice and wider than a phone held upright.
static func choice(
	theme: Gen2LauncherTheme, glyph: StringName, label: String, choices: Array,
	selected: int, handler: Callable, host: Control = null
) -> SettingRow:
	return SettingRow.make(theme, glyph, label, choices, selected, handler, host)


static func switch(
	theme: Gen2LauncherTheme, glyph: StringName, label: String, on: bool, handler: Callable
) -> SettingRow:
	var made: SettingRow = SettingRow.make(
		theme, glyph, label, ["Off", "On"], 1 if on else 0,
		func(index: int) -> void: handler.call(index == 1)
	)
	made.cycles = true
	made.show_switch()
	return made


## A row whose value is a number with a bar under it.
static func level(
	theme: Gen2LauncherTheme, glyph: StringName, label: String, value: int,
	minimum: int, maximum: int, handler: Callable, format: Callable = Callable()
) -> SettingRow:
	var choices: Array = []
	var spell: Callable = format if format.is_valid() \
		else func(amount: int) -> String: return str(amount)
	for step: int in range(minimum, maximum + 1):
		choices.append(spell.call(step))
	var made: SettingRow = SettingRow.make(
		theme, glyph, label, choices, value - minimum,
		func(index: int) -> void: handler.call(index + minimum)
	)
	made.show_bar()
	return made


## See [method choice]. A [Button] so the ring, the sound and the keyboard come
## for nothing; its contents are a row anchored over it, since a [Button] lays
## out one icon and one label and this has four things.
class SettingRow extends Button:
	## Whether a press cycles the value rather than opening the list.
	var cycles: bool = false

	var _theme: Gen2LauncherTheme = null
	var _choices: Array = []
	var _at: int = 0
	var _handler: Callable = Callable()
	var _host: Control = null
	var _row: HBoxContainer = null
	var _name: Label = null
	var _value: Label = null
	var _bar: ProgressBar = null
	var _chevron: Gen2LauncherIcon = null
	var _switch: Gen2LauncherToggle = null

	static func make(
		palette: Gen2LauncherTheme, glyph: StringName, label: String, choices: Array,
		selected: int, handler: Callable, host: Control = null
	) -> SettingRow:
		var made := SettingRow.new()
		made._theme = palette
		made._choices = choices
		made._at = clampi(selected, 0, maxi(choices.size() - 1, 0))
		made._handler = handler
		made._host = host
		made._build(glyph, label)
		return made

	func _build(glyph: StringName, label: String) -> void:
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_row = Gen2LauncherUI.row(GAP_MD)
		_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_row)
		if not glyph.is_empty():
			var mark: Gen2LauncherIcon = Gen2LauncherIcon.create(glyph, 22.0, _theme.muted)
			mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_row.add_child(mark)
		var column: VBoxContainer = Gen2LauncherUI.column(1)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_row.add_child(column)
		_name = Gen2LauncherUI.tag(_theme, label)
		column.add_child(_name)
		_value = Gen2LauncherUI.title(_theme, "", Gen2LauncherTheme.FONT_TITLE)
		column.add_child(_value)
		_bar = ProgressBar.new()
		_bar.show_percentage = false
		_bar.custom_minimum_size.y = 4.0
		_bar.max_value = maxf(float(_choices.size() - 1), 1.0)
		_bar.visible = false
		column.add_child(_bar)
		_chevron = Gen2LauncherIcon.create(&"chevron", 20.0, _theme.muted)
		_chevron.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_row.add_child(_chevron)
		pressed.connect(_on_pressed)
		focus_entered.connect(_repaint)
		focus_exited.connect(_repaint)
		mouse_entered.connect(_repaint)
		mouse_exited.connect(_repaint)
		tree_entered.connect(_measure)
		_row.minimum_size_changed.connect(_measure)
		_repaint()

	## Draws the value as a bar as well as a number, and takes the chevron away:
	## the row is adjusted in place and opens nothing.
	func show_bar() -> void:
		_bar.visible = true
		_chevron.visible = false
		_repaint()

	## Puts a switch where the chevron was. It is drawn rather than pressed: a
	## stop inside a row is one a pad cannot leave.
	func show_switch() -> void:
		_chevron.visible = false
		_value.visible = false
		_switch = Gen2LauncherToggle.create(_theme, _at == 1)
		_switch.focus_mode = Control.FOCUS_NONE
		_switch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_switch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_row.add_child(_switch)
		_repaint()

	func value_text() -> String:
		return _value.text

	func index() -> int:
		return _at

	func switch_node() -> Gen2LauncherToggle:
		return _switch

	## Moves the value [param delta] along, clamped rather than wrapped.
	func step(delta: int) -> void:
		var wanted: int = clampi(_at + delta, 0, _choices.size() - 1)
		if wanted == _at:
			return
		set_index(wanted)
		Gen2LauncherAudio.play(&"hover")

	func set_index(wanted: int) -> void:
		_at = clampi(wanted, 0, maxi(_choices.size() - 1, 0))
		_repaint()
		if _handler.is_valid():
			_handler.call(_at)

	## Left and right change the value; the guard sees what is left over.
	func _gui_input(event: InputEvent) -> void:
		match Gen2Button.direction_in(event):
			Gen2Button.LEFT:
				accept_event()
				step(-1)
			Gen2Button.RIGHT:
				accept_event()
				step(1)

	func _on_pressed() -> void:
		Gen2LauncherAudio.play(&"click")
		if _choices.size() <= 1:
			return
		if cycles or _bar.visible or _host == null:
			set_index(posmod(_at + 1, _choices.size()))
			return
		_open_list()

	## The choices as a sheet of rows, the current one ticked.
	func _open_list() -> void:
		var sheet: Gen2LauncherSheet = Gen2LauncherSheet.create(_theme, _name.text)
		for slot: int in _choices.size():
			var pick: Gen2LauncherButton = Gen2LauncherButton.create(
				_theme, String(_choices[slot]), Gen2LauncherButton.Variant.NEUTRAL,
				&"check" if slot == _at else &""
			)
			pick.set_active(slot == _at)
			pick.pressed.connect(func() -> void:
				set_index(slot)
				sheet.close()
			)
			sheet.body().add_child(pick)
		sheet.open(_host)

	func _repaint() -> void:
		if _theme == null:
			return
		_value.text = "" if _choices.is_empty() else String(_choices[_at])
		_bar.value = float(_at)
		if _switch != null:
			_switch.set_pressed_no_signal(_at == 1)
			_switch.queue_redraw()
		var reached: bool = has_focus() or is_hovered()
		_name.add_theme_color_override("font_color", _theme.muted)
		_value.add_theme_color_override(
			"font_color", _theme.accent if reached else _theme.text
		)
		for state: String in ["normal", "hover", "pressed", "disabled"]:
			add_theme_stylebox_override(state, _theme.padded(_theme.box(
				_theme.accent_wash(0.08) if reached else _theme.panel,
				Gen2LauncherTheme.RADIUS_MD, _theme.accent_wash(0.5) if reached else _theme.line
			), 18, 12))
		add_theme_stylebox_override("focus", _theme.padded(
			_theme.focus_ring(Gen2LauncherTheme.RADIUS_MD, 3), 18, 12
		))
		_measure()

	## A [Button] answers its own minimum size in C++ and never calls a script's
	## [method Control._get_minimum_size].
	func _measure() -> void:
		var chrome: StyleBox = get_theme_stylebox(&"normal")
		var wanted: Vector2 = _row.get_combined_minimum_size()
		if chrome == null:
			return
		wanted += chrome.get_minimum_size()
		custom_minimum_size.y = maxf(wanted.y, TOUCH_TARGET + 12.0)
		# The anchored row ignores the stylebox padding, so it is put back as
		# offsets or the bar runs out past the card's own edge.
		_row.offset_left = chrome.get_margin(SIDE_LEFT)
		_row.offset_top = chrome.get_margin(SIDE_TOP)
		_row.offset_right = -chrome.get_margin(SIDE_RIGHT)
		_row.offset_bottom = -chrome.get_margin(SIDE_BOTTOM)


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


## The one file picker every launcher dialog is built from. The platform
## reasoning, and what shows it, are in [Gen2LauncherFilePicker].
static func file_picker(
	theme: Gen2LauncherTheme,
	title_text: String,
	mode: FileDialog.FileMode,
	filters: PackedStringArray
) -> Gen2LauncherFilePicker:
	return Gen2LauncherFilePicker.create(theme, title_text, mode, filters)


## The square a mod's icon is drawn in, on a list row and on its own page. Always
## the same node whether or not there is a picture, because the alternative is a
## list whose names start at two different places depending on whose mod it is; a
## mod with no icon gets the generic glyph, greyed, in the same square. Nearest
## filtering and never stretched: an icon is 32x32 pixel art drawn at about 40, so
## smoothing it would blur exactly the edges it is made of.
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
