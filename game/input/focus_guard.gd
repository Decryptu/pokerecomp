class_name Gen2FocusGuard
extends Node

## Gives a controller somewhere to start, and somewhere to go. Godot moves focus
## on `ui_up` and the rest of that family, but only once something already has
## it, and nothing does when a screen opens. The ring goes up only for a keyboard
## or a pad, and is never taken away, since a click that dropped focus would
## empty the field it had just filled. A modal takes the whole guard with it, or
## the geometric search joins a control in it to one on the page behind.

## Nodes in this group are modal: while one is in the tree it is the only part of
## the screen the guard looks at. Named rather than typed, so the guard owes
## nothing to the launcher; [Gen2LauncherSheet] is what joins it today.
const MODAL_GROUP: StringName = &"gen2_focus_modal"

const SIDES: Dictionary = {
	&"left": Vector2.LEFT, &"right": Vector2.RIGHT,
	&"up": Vector2.UP, &"down": Vector2.DOWN,
}

## Where focus should land when tree order is not the best answer: a screen whose
## first control is a corner toggle would start a pad there rather than on it.
var preferred: Control = null
## Direction to a [Callable] taking the control being left and answering where to
## go when nothing on the screen lies that way. A floating dock is over the page
## rather than under it, so a long page's last control has nothing below it.
var edge_targets: Dictionary = {}

var _root: Control = null


func _process(_delta: float) -> void:
	# Lists and detail panes are rebuilt after button presses. If the focused
	# button was part of that rebuild, restore a visible target on the next frame.
	refresh()
	_refresh_focus_neighbors()


func _unhandled_input(event: InputEvent) -> void:
	var button: int = Gen2Button.direction_in(event)
	if button == Gen2Button.NONE:
		return
	var direction := Vector2(Gen2Button.vector(button))
	if move_focus(direction):
		_root.get_viewport().set_input_as_handled()


## Attaches a guard to [param root] and returns it, or returns the one already
## there: two guards answer the same arrow twice and the ring moves two controls
## a press. A guard is a child of the screen it watches and goes away with it.
static func attach(root: Control) -> Gen2FocusGuard:
	var existing := root.get_node_or_null(^"FocusGuard") as Gen2FocusGuard
	if existing != null:
		return existing
	var guard := Gen2FocusGuard.new()
	guard.name = "FocusGuard"
	guard._root = root
	root.add_child(guard)
	return guard


func _ready() -> void:
	Gen2InputRuntime.instance().device_changed.connect(_on_device_changed)
	# One frame late: a screen built in code has nothing to focus yet.
	refresh.call_deferred()


## Puts the ring on the first control that can take it, if the device wants one.
func refresh() -> void:
	if _root == null or not _root.is_inside_tree():
		return
	if Gen2InputDevice.is_pointer(Gen2InputRuntime.instance().device()):
		return
	var viewport: Viewport = _root.get_viewport()
	if viewport == null:
		return
	var focused: Control = viewport.gui_get_focus_owner()
	var top: Control = _effective_root()
	# Focus left behind on the page when a modal opened is focus outside the
	# modal, so it is moved in rather than left where the arrows cannot see it.
	if focused != null and (top == _root or top.is_ancestor_of(focused)):
		return
	var target: Control = _wanted()
	if target != null:
		target.grab_focus()


## What the guard may look at: the last modal under [member _root], so a sheet
## opened over a sheet owns the arrows, or the whole screen when there is none.
func _effective_root() -> Control:
	var top: Control = _root
	for node: Node in _root.get_tree().get_nodes_in_group(MODAL_GROUP):
		var control := node as Control
		if control == null or not control.is_visible_in_tree():
			continue
		if control == _root or _root.is_ancestor_of(control):
			top = control
	return top


func _wanted() -> Control:
	if (
		preferred != null
		and is_instance_valid(preferred)
		and preferred.is_visible_in_tree()
		and _focusable(preferred)
	):
		return preferred
	return first_focusable(_effective_root())


func _on_device_changed(_kind: StringName) -> void:
	refresh()


## Directional fallback for layouts Godot cannot join geometrically. It sees only
## an unhandled action, so native traversal inside rows, sliders, text fields and
## scroll panes keeps precedence.
func move_focus(direction: Vector2) -> bool:
	if _root == null or not _root.is_inside_tree() or direction == Vector2.ZERO:
		return false
	var viewport: Viewport = _root.get_viewport()
	var top: Control = _effective_root()
	var current: Control = viewport.gui_get_focus_owner()
	if current == null or not top.is_ancestor_of(current):
		refresh()
		return viewport.gui_get_focus_owner() != null
	var best: Control = _toward(current, direction, focusable_controls(top), top == _root)
	if best == null or best == current:
		return false
	best.grab_focus()
	return true


## Godot's automatic search is unreliable across nested cards and scroll panes.
## Explicit neighbours give arrows, WASD and a d-pad the one visible route.
func _refresh_focus_neighbors() -> void:
	if _root == null or not _root.is_inside_tree():
		return
	var top: Control = _effective_root()
	var controls: Array[Control] = focusable_controls(top)
	var edges: bool = top == _root
	for control: Control in controls:
		for side: StringName in SIDES:
			var direction: Vector2 = SIDES[side]
			_set_neighbor(control, side, _toward(control, direction, controls, edges))


## The neighbour that way, or the screen's edge target. [param edges] is false
## inside a modal, whose own edges are its own.
func _toward(
	current: Control, direction: Vector2, controls: Array[Control], edges: bool
) -> Control:
	var best: Control = _neighbor(current, direction, controls)
	if best != null or not edges:
		return best
	var make: Variant = edge_targets.get(Gen2Button.from_vector(Vector2i(direction)))
	if make is not Callable:
		return null
	var target := (make as Callable).call(current) as Control
	return target if target != null and target != current and target.is_visible_in_tree() \
		else null


static func _neighbor(
	current: Control, direction: Vector2, controls: Array[Control]
) -> Control:
	var origin: Vector2 = current.get_global_rect().get_center()
	var best: Control = null
	var best_score: float = INF
	for candidate: Control in controls:
		if candidate == current:
			continue
		var delta: Vector2 = candidate.get_global_rect().get_center() - origin
		var forward: float = delta.dot(direction)
		if forward <= 1.0:
			continue
		var sideways: float = absf(delta.cross(direction))
		var score: float = forward + sideways * 2.5
		if score < best_score:
			best_score = score
			best = candidate
	return best


static func _set_neighbor(control: Control, side: StringName, target: Control) -> void:
	var path := NodePath()
	if target != null:
		path = control.get_path_to(target)
	match side:
		&"left": control.focus_neighbor_left = path
		&"right": control.focus_neighbor_right = path
		&"up": control.focus_neighbor_top = path
		&"down": control.focus_neighbor_bottom = path


## The first control under [param root] that would accept focus, depth first.
static func first_focusable(root: Node) -> Control:
	return _first_focusable(root, true)


static func focusable_controls(root: Node) -> Array[Control]:
	var out: Array[Control] = []
	_collect_focusable(root, out)
	return out


static func _collect_focusable(root: Node, out: Array[Control]) -> void:
	for child: Node in root.get_children():
		var control := child as Control
		if control != null:
			if not control.is_visible_in_tree():
				continue
			if _takes_focus(control):
				out.append(control)
		_collect_focusable(child, out)


## Whether the ring may rest here. One rule, so where it lands and where it may
## travel are the same set; a landing spot it cannot leave strands a controller.
static func _takes_focus(control: Control) -> bool:
	return _focusable(control) and not _scroll_with_controls(control)


static func _focusable(control: Control) -> bool:
	return control.focus_mode == Control.FOCUS_ALL and not _is_disabled(control)


static func _first_focusable(root: Node, skip_panes: bool) -> Control:
	for child: Node in root.get_children():
		var control := child as Control
		if control != null:
			if not control.visible:
				continue
			if _focusable(control) and not (skip_panes and _scroll_with_controls(control)):
				return control
		var found: Control = _first_focusable(child, skip_panes)
		if found != null:
			return found
	return null


## A pane takes focus so prose can be read without a pointer, and answers an up
## or a down by scrolling ([Gen2LauncherScroll]). One holding controls is a dead
## end: it eats every direction and the controls are never reached.
static func _scroll_with_controls(control: Control) -> bool:
	return control is ScrollContainer and _first_focusable(control, false) != null


static func _is_disabled(control: Control) -> bool:
	var button := control as BaseButton
	return button != null and button.disabled
