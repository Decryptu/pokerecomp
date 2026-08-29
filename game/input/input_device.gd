class_name Gen2InputDevice
extends RefCounted

## Which kind of device an event came from.
##
## The engine reports what happened, never what the player is holding, and the
## two questions have different answers: a phone with a pad plugged in has a
## touchscreen it is not using, and a laptop with a touchscreen has one the
## player touches once an hour. Only the device actually in use should decide
## whether on-screen controls are drawn or a focus ring is shown, so
## [Gen2InputRuntime] keeps the last answer this gives and publishes it.

const KEYBOARD: StringName = &"keyboard"
const MOUSE: StringName = &"mouse"
const TOUCH: StringName = &"touch"
const GAMEPAD: StringName = &"gamepad"
const KINDS: Array[StringName] = [KEYBOARD, MOUSE, TOUCH, GAMEPAD]

const LABELS: Dictionary = {
	KEYBOARD: "Keyboard",
	MOUSE: "Mouse",
	TOUCH: "Touchscreen",
	GAMEPAD: "Controller",
}


## The kind to assume before any event has arrived, from what the machine has.
##
## A pad comes first where there is both, because a machine with both is being
## held by its buttons: a Switch in the hands has a touchscreen nobody is
## touching, and so does a phone with a controller paired to it. The first real
## event replaces this answer anyway; what it decides is the first frame.
static func kind_for_hardware(has_pad: bool, has_touch: bool) -> StringName:
	if has_pad:
		return GAMEPAD
	if has_touch:
		return TOUCH
	return KEYBOARD


## The device kind an event came from, or an empty name for an event that says
## nothing about one. A mouse event emulated from a touch carries [constant
## InputEvent.DEVICE_ID_EMULATION]: without that, `emulate_mouse_from_touch`
## would flip the answer to mouse on every tap of the launcher.
static func kind_of(event: InputEvent) -> StringName:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return TOUCH
	if event is InputEventKey:
		return KEYBOARD
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return GAMEPAD
	if event is InputEventMouse:
		return TOUCH if event.device == InputEvent.DEVICE_ID_EMULATION else MOUSE
	return &""


## The kind an event is evidence the player has picked up, or an empty name.
## Android sends its Back button, its navigation bar and its volume rocker as
## key events, and a [param handheld] has no keyboard or mouse of its own:
## reading Back as one put the on-screen controller away mid-game.
static func evidence_of(event: InputEvent, handheld: bool) -> StringName:
	var kind: StringName = kind_of(event)
	if handheld and (kind == KEYBOARD or kind == MOUSE):
		return &""
	# A knocked desk and a drifting stick are nobody's hands; a click is.
	if event is InputEventMouseMotion:
		return &""
	var motion := event as InputEventJoypadMotion
	if motion != null and absf(motion.axis_value) < Gen2InputActions.DEADZONE:
		return &""
	return kind


static func is_handheld() -> bool:
	return OS.has_feature("mobile")


static func label(kind: StringName) -> String:
	return LABELS.get(kind, "")


## Whether a kind drives the interface by pointing at it. These are the two that
## need no focus ring in the launcher, and the two an on-screen d-pad would be
## in the way of everywhere else.
static func is_pointer(kind: StringName) -> bool:
	return kind == MOUSE or kind == TOUCH
