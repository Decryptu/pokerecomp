class_name Gen2LauncherScroll
extends ScrollContainer

## A vertical scroll pane that can be read without a pointer, which Godot does
## not give. A pad walking the controls inside brings the pane with it; a pane of
## prose has nothing focusable, so it takes focus itself and reads an up or a down
## as scrolling. A finger is the third way: [constant Control.MOUSE_FILTER_STOP]
## ends a pointer event at the button it reaches, so the pane reads the touch in
## [method Node._input] and leaves the engine's own drag off.

## How far one press moves the pane, as a fraction of what it shows.
const PAGE: float = 0.42
## How far one repeat of a held direction moves it: a repeat every five frames
## ([Gen2InputRuntime]) carrying a page each would be five screens a second.
const LINE: float = 0.10
## How far a finger travels before the touch is a scroll rather than a tap.
const TOUCH_DEADZONE: float = 12.0
## Room kept either side of the content: a ring is drawn outside the control it
## rings and a pane clips what leaves it.
const RING_INSET: int = 8
const WAYS: Dictionary = {Gen2Button.DOWN: 1, Gen2Button.UP: -1}

var _content: MarginContainer = null
## The finger this pane is following, or -1.
var _touch_index: int = -1
## Where it landed, in window units, so the button under it can be let go of.
var _touch_from: Vector2 = Vector2.ZERO
var _touch_travel: float = 0.0
var _touch_dragging: bool = false


func content() -> MarginContainer:
	return _content


static func create() -> Gen2LauncherScroll:
	var scroll := Gen2LauncherScroll.new()
	# Never `SCROLL_MODE_DISABLED`: that adds the child's whole minimum width, so
	# one row wider than the window widens the launcher rather than being held
	# inside. Hidden instead, and the rows wrap so nothing needs the axis.
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	scroll._content = MarginContainer.new()
	scroll._content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right"]:
		scroll._content.add_theme_constant_override("margin_" + side, RING_INSET)
	scroll.add_child(scroll._content)
	return scroll


func _ready() -> void:
	# A [Control] is not handed raw input unless it asks.
	set_process_input(true)
	get_v_scroll_bar().changed.connect(_refresh_focus_mode)
	resized.connect(_refresh_focus_mode)
	_refresh_focus_mode()


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
	if _scroll_by(event):
		accept_event()


## A held direction repeats as an [InputEventAction], and the engine routes no
## action to `_gui_input`, so a pane holding focus reads its repeats here.
func _unhandled_input(event: InputEvent) -> void:
	if has_focus() and _scroll_by(event):
		get_viewport().set_input_as_handled()


## Whether the pane took the direction. One already at that end of its travel
## does not, or the player is stranded on a page they have finished reading.
func _scroll_by(event: InputEvent) -> bool:
	if not _scrollable():
		return false
	var way: int = int(WAYS.get(Gen2Button.direction_in(event), 0))
	if way == 0:
		return false
	var at: int = scroll_vertical
	# A repeat is an InputEventAction; a press the player made is not.
	var fraction: float = LINE if event is InputEventAction else PAGE
	scroll_vertical = int(float(at) + float(way) * maxf(size.y * fraction, 40.0))
	return scroll_vertical != at


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


## Takes the press off the button the finger landed on, now that it has turned
## out to be scrolling. [BaseButton] tracks a touch itself and nothing public
## cancels one; disabling clears the attempt and re-enabling in the same call
## leaves it live for the release that clears its own record of the finger.
func _release_pressed_button() -> void:
	_cancel_card_presses(self)
	var button: BaseButton = _button_at(self, _touch_from)
	if button == null or button.disabled:
		return
	button.set_disabled(true)
	button.set_disabled(false)


static func _cancel_card_presses(node: Node) -> void:
	if node is Gen2LauncherCard:
		node.cancel_press()
	for child: Node in node.get_children():
		_cancel_card_presses(child)


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


## Whether there is more here than fits, the only case worth stopping on.
func _scrollable() -> bool:
	var bar: VScrollBar = get_v_scroll_bar()
	return bar != null and bar.max_value > bar.page


func _refresh_focus_mode() -> void:
	focus_mode = Control.FOCUS_ALL if _scrollable() else Control.FOCUS_NONE
