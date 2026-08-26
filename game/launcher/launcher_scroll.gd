class_name Gen2LauncherScroll
extends ScrollContainer

## A vertical scroll pane that can be read without a pointer.
##
## Two things are needed and Godot gives neither by default. A pad walking the
## controls inside a pane has to bring the pane with it, which is
## [member ScrollContainer.follow_focus]. And a pane whose content is mostly text
## has stretches with nothing focusable in them, so the pane itself takes focus
## and reads `ui_up` and `ui_down` as scrolling, which is the only way past a
## wall of prose on a keyboard.
##
## The pane only takes focus when it actually has somewhere to go, so a short
## page does not put a stop on the way down to the dock.
##
## A finger is the third way, and the engine gives none of it. [ScrollContainer]
## drags off mouse events emulated from the touch, and
## [constant Control.MOUSE_FILTER_STOP] ends a pointer event at the control it
## reaches: [method Viewport._gui_call_input] stops there for every mouse, touch
## and drag event, and only a wheel is passed on by `force_pass_scroll_events`.
## Every launcher page is a column of buttons, each of them STOP, so a wheel
## scrolls the pane and a finger on the same page moves nothing. The pane
## therefore reads the touch in [method Node._input], ahead of the GUI, and
## leaves the engine's own drag switched off.

## How far one press moves the pane, as a fraction of what it shows.
const PAGE: float = 0.42
## How far a finger travels before the touch is a scroll rather than a tap.
const TOUCH_DEADZONE: float = 12.0

## The finger this pane is following, or -1.
var _touch_index: int = -1
## Where it landed, in window units, so the button under it can be let go of.
var _touch_from: Vector2 = Vector2.ZERO
var _touch_travel: float = 0.0
var _touch_dragging: bool = false


static func create() -> Gen2LauncherScroll:
	var scroll := Gen2LauncherScroll.new()
	# Never `SCROLL_MODE_DISABLED`: that adds the child's whole minimum width to
	# the pane, so one row wider than the window widens the launcher itself
	# rather than being held inside the pane. Hidden instead, and the rows stack
	# or wrap ([FieldRow], `controls_section.gd`) so nothing needs the axis.
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	return scroll


func _ready() -> void:
	# A [Control] is not handed raw input unless it asks.
	set_process_input(true)
	get_v_scroll_bar().changed.connect(_refresh_focus_mode)
	resized.connect(_refresh_focus_mode)
	_refresh_focus_mode()


## The finger, read before the GUI has a chance to stop it at a button.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_screen_touch(event)
	elif event is InputEventScreenDrag:
		_on_screen_drag(event)


func _gui_input(event: InputEvent) -> void:
	# The engine drags this pane off the mouse events `emulate_mouse_from_touch`
	# makes from the same finger [method _input] is already following, so both
	# left on scroll the page twice as far as the finger moved.
	if event.device == InputEvent.DEVICE_ID_EMULATION \
		and (event is InputEventMouseButton or event is InputEventMouseMotion):
		accept_event()
		return
	if not _scrollable():
		return
	var step: float = maxf(size.y * PAGE, 40.0)
	if event.is_action_pressed("ui_down", true):
		accept_event()
		scroll_vertical = int(float(scroll_vertical) + step)
	elif event.is_action_pressed("ui_up", true):
		accept_event()
		scroll_vertical = int(float(scroll_vertical) - step)


func _on_screen_touch(touch: InputEventScreenTouch) -> void:
	if not touch.pressed:
		if touch.index == _touch_index:
			# The release is left for the GUI whether or not the finger scrolled:
			# a button that saw the press keeps waiting for its own release, and
			# _release_pressed_button has already taken the press away from it.
			_touch_index = -1
			_touch_dragging = false
		return
	if _touch_index != -1 or not _scrollable() or not _takes_touches(touch.position):
		return
	_touch_index = touch.index
	_touch_from = touch.position
	_touch_travel = 0.0
	_touch_dragging = false


func _on_screen_drag(drag: InputEventScreenDrag) -> void:
	if drag.index != _touch_index:
		return
	_touch_travel += drag.relative.y
	if not _touch_dragging:
		if absf(_touch_travel) < TOUCH_DEADZONE:
			return
		_touch_dragging = true
		_release_pressed_button()
	scroll_vertical = int(float(scroll_vertical) - drag.relative.y)
	get_viewport().set_input_as_handled()


## Whether a touch at [param point] is this pane's. A page's pane is still in
## the tree and still under the point while a sheet covers it, so the modal
## convention [Gen2FocusGuard] already keeps is what decides between the two.
func _takes_touches(point: Vector2) -> bool:
	if not is_visible_in_tree() or not get_global_rect().has_point(point):
		return false
	for modal: Node in get_tree().get_nodes_in_group(Gen2FocusGuard.MODAL_GROUP):
		if modal != self and not modal.is_ancestor_of(self):
			return false
	return true


## Takes the press off the button the finger landed on, now that the finger has
## turned out to be scrolling. [BaseButton] tracks a touch itself, and nothing
## public cancels one; disabling clears the attempt and re-enabling in the same
## call leaves the button live for the release that is still to come, which is
## what clears its own record of the finger.
func _release_pressed_button() -> void:
	var button: BaseButton = _button_at(self, _touch_from)
	if button == null or button.disabled:
		return
	button.set_disabled(true)
	button.set_disabled(false)


static func _button_at(node: Node, point: Vector2) -> BaseButton:
	for child: Node in node.get_children():
		var control := child as Control
		if control == null or not control.is_visible_in_tree():
			continue
		var found: BaseButton = _button_at(control, point)
		if found != null:
			return found
		if control is BaseButton and control.get_global_rect().has_point(point):
			return control
	return null


## Whether there is more here than fits, which is the only case where the pane is
## worth stopping on.
func _scrollable() -> bool:
	var bar: VScrollBar = get_v_scroll_bar()
	return bar != null and bar.max_value > bar.page


func _refresh_focus_mode() -> void:
	focus_mode = Control.FOCUS_ALL if _scrollable() else Control.FOCUS_NONE
