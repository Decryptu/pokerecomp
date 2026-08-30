class_name Gen2LauncherShell
extends Control

## The frame every launcher screen sits in: a backdrop, a top bar carrying the
## clock, the tabs and the charge, the page, and the bar of button hints along
## the bottom. Neither bar changes edge with the window; what changes is whether
## the tabs are named. The strip above the page is what makes a pad predictable:
## up leaves the page, down returns, and the shoulders step the strip from
## anywhere without moving the ring.

signal page_selected(id: StringName)

## Width below which the launcher writes smaller and pads tighter. Measured in
## launcher units, which are points rather than pixels, so a phone held upright
## is below it whatever its screen is made of.
const COMPACT_WIDTH: float = 820.0
## Room kept for a message and its detail line above the page.
const TOAST_HEIGHT: float = 84.0
const BAR_FADE_TOP: float = 22.0
const PHONE_LANDSCAPE_HEIGHT: float = 600.0
const NAMED_TABS_WIDTH: float = 620.0

var theme_palette: Gen2LauncherTheme = null
var compact: bool = false

var _backdrop: TextureRect = null
## The two layers a cartridge's artwork crossfades between, and the sheet of
## page colour over them that keeps the launcher readable on top of a picture.
var _art_holder: Control = null
var _art_back: TextureRect = null
var _art_front: TextureRect = null
var _art_veil: ColorRect = null
var _art_texture: Texture2D = null
var _art_tween: Tween = null
var _host: MarginContainer = null
var _clock: Label = null
var _battery: Gen2LauncherBattery = null
var _top_right: HBoxContainer = null
var _pages: MarginContainer = null
var _top_bar: Control = null
var _tabs: HBoxContainer = null
var _tab_strip: HBoxContainer = null
var _shoulders: Array[Gen2LauncherHint] = []
var _bar_host: Control = null
var _hints: Gen2LauncherHintBar = null
var _toast: Gen2LauncherToast = null
var _flash: ColorRect = null
var _entries: Array[Dictionary] = []
var _buttons: Dictionary = {}
var _page_nodes: Dictionary = {}
var _current: StringName = &""
var _focus: Gen2FocusGuard = null

## Set by [method flash] and consumed by the next shell built, which is what
## carries one transition across a scene change. Static because the shell that
## faded out is gone by the time the next one exists.
static var _transition_pending: bool = false


static func create(palette: Gen2LauncherTheme) -> Gen2LauncherShell:
	var shell := Gen2LauncherShell.new()
	shell.theme_palette = palette
	shell._build()
	return shell


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = theme_palette.control_theme()

	_backdrop = TextureRect.new()
	_backdrop.texture = theme_palette.backdrop_texture()
	_backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	# The artwork and the sheet of page colour over it fade together, so a page
	# with no cartridge behind it is the plain gradient rather than a veil over
	# nothing. Inside, the two texture layers crossfade one picture into the next.
	_art_holder = Control.new()
	_art_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art_holder.modulate.a = 0.0
	add_child(_art_holder)
	_art_back = _art_layer()
	_art_front = _art_layer()
	# One sheet of page colour over the artwork rather than a translucent image:
	# the picture is a backdrop, and the text above it has to stay readable
	# whatever the picture happens to be doing underneath.
	_art_veil = ColorRect.new()
	_art_veil.color = theme_palette.with_alpha(
		theme_palette.backdrop_bottom, 0.76 if theme_palette.is_dark() else 0.72
	)
	_art_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art_holder.add_child(_art_veil)

	_host = MarginContainer.new()
	_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_host)
	var root: VBoxContainer = Gen2LauncherUI.column(Gen2LauncherUI.GAP_MD)
	_host.add_child(root)

	root.add_child(_build_top_bar())
	## Hidden until its own probe answers, so a machine that reports no charge
	## shows a clock and nothing beside it.
	_battery = Gen2LauncherBattery.create(theme_palette)
	_battery.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_top_right.add_child(_battery)

	# The clock is only ever read to the minute, but ticking every second keeps
	# it from sitting a whole minute behind the one on the wall.
	var tick := Timer.new()
	tick.wait_time = 1.0
	tick.autostart = true
	tick.timeout.connect(func() -> void: _clock.text = _now())
	add_child(tick)

	_pages = MarginContainer.new()
	_pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_pages)

	add_child(_build_hint_bar())

	_toast = Gen2LauncherToast.create(theme_palette)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	add_child(_toast)
	_pages.resized.connect(_place_toast)

	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_flash)
	# The screen this one replaced left through `flash()`, so this one arrives
	# under the same sheet and walks it back rather than cutting in under it.
	if _transition_pending:
		_transition_pending = false
		_flash.color = Color(_flash_color(), 1.0)
		ready.connect(fade_in, CONNECT_ONE_SHOT)

	## Every launcher screen is drawn in points, and only a launcher screen is:
	## the world upscales a 160x144 screen by a whole number of real pixels, and
	## a window drawn in points would make that number wrong.
	Gen2LauncherUI.attach_density(self)
	resized.connect(_apply_layout)
	_apply_layout()
	_place_toast()
	_focus = Gen2FocusGuard.attach(self)
	_focus.edge_targets = {Gen2Button.UP: _tab_landing}


func _now() -> String:
	var clock: Dictionary = Time.get_time_dict_from_system()
	return "%02d:%02d" % [int(clock["hour"]), int(clock["minute"])]


## The strip is laid over the row rather than placed in it: a centre cell between
## two of different widths is not the middle of the screen.
func _build_top_bar() -> Control:
	_top_bar = Control.new()
	_top_bar.custom_minimum_size.y = Gen2LauncherButton.TAB_HEIGHT
	_top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var row: HBoxContainer = Gen2LauncherUI.row(Gen2LauncherUI.GAP_MD)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_bar.add_child(row)
	_clock = Gen2LauncherUI.title(theme_palette, _now(), Gen2LauncherTheme.FONT_TITLE)
	_clock.add_theme_color_override("font_color", theme_palette.text)
	_clock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_clock)
	row.add_child(Gen2LauncherUI.spacer())
	_top_right = Gen2LauncherUI.row(Gen2LauncherUI.GAP_MD)
	_top_right.alignment = BoxContainer.ALIGNMENT_END
	_top_right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_top_right)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_bar.add_child(centre)
	# The shoulders step the strip, so the ring must never land on one.
	_tabs = Gen2LauncherUI.row(Gen2LauncherUI.GAP_SM)
	centre.add_child(_tabs)
	_shoulders = []
	_tabs.add_child(_shoulder(&"ui_page_up"))
	_tab_strip = Gen2LauncherUI.row(Gen2LauncherUI.GAP_XS)
	_tabs.add_child(_tab_strip)
	_tabs.add_child(_shoulder(&"ui_page_down"))
	return _top_bar


func _shoulder(action: StringName) -> Gen2LauncherHint:
	var badge: Gen2LauncherHint = Gen2LauncherHint.create(theme_palette, action, "")
	badge.pressed.connect(step_page.bind(-1 if action == &"ui_page_up" else 1))
	_shoulders.append(badge)
	return badge


func _build_hint_bar() -> Control:
	_bar_host = Control.new()
	_bar_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_host.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)

	var fade := TextureRect.new()
	fade.texture = _bar_gradient()
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bar_host.add_child(fade)

	_hints = Gen2LauncherHintBar.create(theme_palette)
	_hints.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hints.offset_top = -Gen2LauncherUI.TOUCH_TARGET
	_bar_host.add_child(_hints)
	return _bar_host


## Adds a top-bar action, right aligned, in the order added.
func add_action(button: Control) -> void:
	_top_right.add_child(button)


func add_page(id: StringName, label: String, glyph: StringName, page: Control) -> void:
	_entries.append({"id": id, "label": label, "glyph": glyph})
	page.visible = false
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_nodes[id] = page
	_pages.add_child(page)
	# The layout is settled before the first page exists, so a page is told the
	# shape it is being added into rather than waiting for the next change of it.
	if page.has_method("set_compact"):
		page.call("set_compact", compact)
	if page.has_signal(&"hints_changed"):
		page.connect(&"hints_changed", _refresh_hints)
	_rebuild_tabs()
	if _current.is_empty():
		select(id)


func select(id: StringName) -> void:
	if not _page_nodes.has(id):
		return
	_current = id
	for key: StringName in _page_nodes:
		(_page_nodes[key] as Control).visible = key == id
	for key: StringName in _buttons:
		(_buttons[key] as Gen2LauncherButton).set_active(key == id)
	# A page that has just been hidden takes its focus with it, so the new one
	# needs somewhere for a pad to land. The ring follows the page rather than
	# staying on the tab that opened it, which would answer the next arrow press
	# with another page change; a pointer moves no ring at all.
	if _focus != null:
		_focus.preferred = _page_landing()
		if _focus.preferred != null and not Gen2InputDevice.is_pointer(
			Gen2InputRuntime.instance().device()
		):
			_focus.preferred.grab_focus.call_deferred()
		_focus.refresh.call_deferred()
	_refresh_hints()
	page_selected.emit(id)


## The page's own hints, plus the way back every page but the first carries.
func _refresh_hints() -> void:
	if _hints == null or _current.is_empty():
		return
	var page: Control = _page_nodes[_current]
	var own: Array = page.call("hints") as Array if page.has_method("hints") else []
	var entries: Array = []
	var home := StringName(_entries[0]["id"]) if not _entries.is_empty() else &""
	if _entries.size() > 1 and _current != home and not _answers_cancel(own):
		entries.append({
			"action": &"ui_cancel", "label": "Back",
			"run": func() -> void: select(home),
		})
	entries.append_array(own)
	set_hints(entries)


static func _answers_cancel(entries: Array) -> bool:
	for entry: Dictionary in entries:
		if StringName(entry.get("action", &"")) == &"ui_cancel":
			return true
	return false


func current_page() -> StringName:
	return _current


func toast() -> Gen2LauncherToast:
	return _toast


## What the Switch build's washed-out page and missing toast need answered, twice
## over since the veil and the toast both arrive on a tween.
func log_layers(where: String) -> void:
	print(layer_report(where))
	if is_inside_tree():
		get_tree().create_timer(1.0).timeout.connect(
			func() -> void: print(layer_report(where + " +1s"))
		)


func layer_report(where: String) -> String:
	if _art_holder == null or _art_veil == null or _host == null or _toast == null:
		return "launcher layers %s: not built" % where
	return "launcher layers %s: art=%.2f at %d, veil %s, page at %d, toast %s %.2f %s" % [
		where, _art_holder.modulate.a, _art_holder.get_index(), _art_veil.color,
		_host.get_index(), _toast.visible, _toast.modulate.a, _toast.get_global_rect(),
	]


## Puts [param texture] behind the launcher, crossfading from whatever was there.
## Pass null for the plain gradient, which is what a page with no cartridge
## behind it wants.
func set_backdrop_art(texture: Texture2D, game_screen: bool = false) -> void:
	if texture == _art_texture:
		return
	_art_texture = texture
	if _art_tween != null and _art_tween.is_valid():
		_art_tween.kill()
	# The layer on show drops to the back so the new picture can come up over it
	# rather than under it.
	var outgoing: TextureRect = _art_front
	_art_front = _art_back
	_art_back = outgoing
	_art_front.texture = texture
	_art_front.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art_front.texture_filter = (
		CanvasItem.TEXTURE_FILTER_NEAREST
		if game_screen
		else CanvasItem.TEXTURE_FILTER_LINEAR
	)
	_art_front.modulate.a = 0.0
	_art_holder.move_child(_art_back, 0)
	_art_holder.move_child(_art_front, 1)
	if not is_inside_tree():
		_art_front.modulate.a = 1.0
		_art_back.modulate.a = 0.0
		_art_holder.modulate.a = 1.0 if texture != null else 0.0
		return
	_art_tween = create_tween()
	_art_tween.set_parallel(true)
	_art_tween.tween_property(_art_front, "modulate:a", 1.0, 0.45)
	_art_tween.tween_property(_art_back, "modulate:a", 0.0, 0.45)
	_art_tween.tween_property(_art_holder, "modulate:a", 1.0 if texture != null else 0.0, 0.45)


func _art_layer() -> TextureRect:
	var layer := TextureRect.new()
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# Covers the window at any shape: a backdrop is allowed to lose its edges,
	# and letterboxing one would show the gradient in two stripes.
	layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.modulate.a = 0.0
	_art_holder.add_child(layer)
	return layer


## The screen-to-screen transition, in the family of the cartridge's own:
## `FadeOutToWhite` walks `Gen2WorldPalette.FADE_OUT_ORDERS` one row at a time,
## holding each for `FADE_STEP_FRAMES`, so the screen leaves in four discrete steps
## rather than on a ramp. The colour it flattens onto is the palette's own and the
## steps are alpha rather than palette rows. [param hand_over] is false when the
## screen after this one is not a shell screen: the world arrives on its own map
## fade, so it must not be walked back out of the launcher's sheet as well.
func flash(hand_over: bool = true) -> void:
	if not is_inside_tree():
		return
	_transition_pending = hand_over
	await _step_flash(_flash_color(), 0.0, 1.0)


## `FadeInFromWhite`: the same four rows walked back. Run by `_build` when the
## screen before this one left through [method flash], and by nothing else, so
## a cold boot opens on the launcher rather than on a wipe.
func fade_in() -> void:
	if not is_inside_tree():
		return
	await _step_flash(_flash_color(), 1.0, 0.0)
	_flash.color = _flash_color()


## Preview seam for `tools/preview_launcher.gd`: the sheet as [method flash]
## leaves it after [param step] of its four, which a moving fade cannot be
## photographed at.
func preview_fade_step(step: int) -> void:
	if _flash == null:
		return
	var steps: int = Gen2WorldPalette.FADE_OUT_ORDERS.size()
	var color: Color = _flash_color()
	color.a = float(clampi(step, 0, steps)) / float(steps)
	_flash.color = color


func _flash_color() -> Color:
	return Color(0, 0, 0, 0) if theme_palette.is_dark() else Color(1, 1, 1, 0)


func _step_flash(color: Color, from: float, to: float) -> void:
	var steps: int = Gen2WorldPalette.FADE_OUT_ORDERS.size()
	color.a = from
	_flash.color = color
	for step: int in steps:
		for _frame: int in Gen2WorldPalette.FADE_STEP_FRAMES:
			await get_tree().process_frame
			if not is_inside_tree():
				return
		color.a = lerpf(from, to, float(step + 1) / float(steps))
		_flash.color = color


func _rebuild_tabs() -> void:
	Gen2LauncherUI.clear(_tab_strip)
	_buttons.clear()
	_tabs.visible = _entries.size() > 1
	for entry: Dictionary in _entries:
		var id: StringName = entry["id"]
		var button: Gen2LauncherButton = Gen2LauncherButton.tab(
			theme_palette, entry["glyph"], String(entry["label"])
		)
		button.tooltip_text = String(entry["label"])
		button.add_to_group(Gen2FocusGuard.ASIDE_GROUP)
		button.pressed.connect(select.bind(id))
		button.gui_input.connect(_on_tab_input.bind(id))
		_tab_strip.add_child(button)
		_buttons[id] = button
	_apply_layout()
	if not _current.is_empty():
		select(_current)


## Moves [param delta] tabs along, wrapping. What the shoulders do.
func step_page(delta: int) -> void:
	if _entries.size() < 2:
		return
	var at: int = _index_of(_current)
	select(StringName(_entries[posmod(at + delta, _entries.size())]["id"]))


func _index_of(id: StringName) -> int:
	for index: int in _entries.size():
		if StringName(_entries[index]["id"]) == id:
			return index
	return 0


## A page switched behind a modal leaves the sheet over a page it never opened
## from, so the shoulders stop while one is up.
func _unhandled_input(event: InputEvent) -> void:
	if _entries.size() < 2 or not get_tree().get_nodes_in_group(
		Gen2FocusGuard.MODAL_GROUP
	).is_empty():
		return
	var delta: int = 0
	if event.is_action_pressed(&"ui_page_up"):
		delta = -1
	elif event.is_action_pressed(&"ui_page_down"):
		delta = 1
	if delta == 0:
		return
	get_viewport().set_input_as_handled()
	step_page(delta)


func _tab_landing(from: Control) -> Control:
	if _tabs == null or not _tabs.visible or _tabs.is_ancestor_of(from):
		return null
	return _buttons.get(_current) as Control


## Godot's search prefers a page control below a tab over the tab beside it, so
## the strip owns its axes: left and right wrap, down leaves.
func _on_tab_input(event: InputEvent, id: StringName) -> void:
	var at: int = _index_of(id)
	var target: Control = null
	match Gen2Button.direction_in(event):
		Gen2Button.LEFT:
			target = _buttons.get(StringName(_entries[posmod(at - 1, _entries.size())]["id"]))
		Gen2Button.RIGHT:
			target = _buttons.get(StringName(_entries[posmod(at + 1, _entries.size())]["id"]))
		Gen2Button.DOWN:
			target = _page_landing()
		_:
			return
	if target == null or not target.is_visible_in_tree():
		return
	(_buttons[id] as Control).accept_event()
	target.grab_focus()


func _page_landing() -> Control:
	var page: Control = _page_nodes.get(_current)
	if page == null:
		return null
	return page.call("focus_target") if page.has_method("focus_target") \
		else Gen2FocusGuard.first_focusable(page)


func _apply_layout() -> void:
	var insets: Dictionary = Gen2LauncherUI.safe_area_insets(get_window())
	var phone_landscape: bool = size.x > size.y and size.y < PHONE_LANDSCAPE_HEIGHT
	var wide: bool = size.x >= COMPACT_WIDTH and not phone_landscape
	var margin: int = 30 if wide else 16
	# The clock and the charge sit on the top row, which a notch or a rounded
	# corner would otherwise take a bite out of.
	_host.add_theme_constant_override("margin_left", margin + int(insets["left"]))
	_host.add_theme_constant_override("margin_right", margin + int(insets["right"]))
	_host.add_theme_constant_override("margin_top", (14 if wide else 8) + int(insets["top"]))
	# Pages reach the bezel; each scrolling page owns a safe tail that can move
	# its final control above the floating hint bar.
	_host.add_theme_constant_override("margin_bottom", 0)
	_layout_bars(insets)
	if compact == not wide and not _entries.is_empty():
		return
	compact = not wide
	for key: StringName in _page_nodes:
		var page: Control = _page_nodes[key]
		if page.has_method("set_compact"):
			page.call("set_compact", compact)


## The tabs keep their words while the row has any to spare, and drop to glyphs
## in squares when it has not.
func _layout_bars(insets: Dictionary) -> void:
	var named: bool = names_tabs(size, _entries.size())
	for entry: Dictionary in _entries:
		var button := _buttons.get(StringName(entry["id"])) as Gen2LauncherButton
		if button != null:
			button.set_labelled(named, String(entry["label"]))
	# A row too narrow to name its tabs would draw these over the clock.
	for badge: Gen2LauncherHint in _shoulders:
		badge.visible = named
	# Both stand off the home indicator, or the chips sit half under it.
	var bottom: float = float(insets["bottom"])
	_bar_host.offset_top = -(bottom_band(size) + BAR_FADE_TOP + bottom)
	_hints.offset_bottom = -bottom


## Whether [param count] tabs are named as well as drawn. A phone in landscape
## has the width and not the height, hence both axes.
static func names_tabs(viewport_size: Vector2, count: int) -> bool:
	if count <= 1:
		return false
	if viewport_size.x > viewport_size.y and viewport_size.y < PHONE_LANDSCAPE_HEIGHT:
		return false
	return viewport_size.x >= NAMED_TABS_WIDTH


## What the hint bar takes out of the bottom, before the home indicator. A page
## keeps this much clear so its last control is not left under the chips.
static func bottom_band(viewport_size: Vector2) -> float:
	return Gen2LauncherUI.TOUCH_TARGET + Gen2LauncherUI.bar_padding(viewport_size)


func set_hints(entries: Array) -> void:
	_hints.set_hints(entries)


func hint_bar() -> Gen2LauncherHintBar:
	return _hints


func tabs() -> Array[Gen2LauncherButton]:
	var found: Array[Gen2LauncherButton] = []
	for entry: Dictionary in _entries:
		found.append(_buttons[StringName(entry["id"])])
	return found


func _place_toast() -> void:
	if _toast == null or _pages == null:
		return
	_toast.offset_bottom = -(Gen2LauncherUI.bottom_reserve(get_window()) + 10.0)
	_toast.offset_top = _toast.offset_bottom - TOAST_HEIGHT


func _bar_gradient() -> GradientTexture2D:
	var ramp := Gradient.new()
	ramp.set_color(0, theme_palette.with_alpha(theme_palette.backdrop_bottom, 0.0))
	ramp.set_color(1, theme_palette.backdrop_bottom)
	var texture := GradientTexture2D.new()
	texture.gradient = ramp
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.width = 8
	texture.height = 128
	return texture
