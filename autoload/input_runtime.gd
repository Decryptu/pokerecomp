class_name Gen2InputRuntime
extends Node

## The live control scheme, and which device the player is actually using.
##
## Bindings need an owner because the [InputMap] has no memory of where it came
## from; the active device needs one because what decides whether an on-screen
## d-pad is drawn is whether the player is touching the screen right now. Screens
## read this through [method instance] rather than the `InputRuntime` global: a
## `-s` script compiles before the tree that owns the autoloads exists.

signal device_changed(kind: StringName)
## The effective answer, after both the setting and the active device. Also
## emitted when the frontmost controller changes, since that changes which pad
## should be drawing even though the setting has not moved.
signal touch_controls_changed(shown: bool)
## A rebind landed. What is bound has already been installed in the [InputMap]
## by the time this arrives; a screen only needs it to redraw a legend.
signal scheme_changed()
## A + B + START + SELECT, the console's own reset, reported once per press of
## the chord. The machine's rather than the game's, so it is detected here and
## whichever screen is up decides what a reset costs.
signal reset_chord_pressed()

var _scheme: Dictionary = {}
## What the player bound each mod's own actions to, keyed by action name. See
## [method Gen2ModHost.register_action].
var _mod_controls: Dictionary = {}
var _touch_mode: StringName = Gen2Options.TOUCH_AUTO
var _layout: Gen2TouchLayout = Gen2TouchLayout.new()
var _device: StringName = Gen2InputDevice.KEYBOARD
var _touch_shown: bool = false
## Held directions in the order they were pressed, so the newest wins. Two
## directions at once is normal play, not an error: a player turning a corner
## presses the next one before releasing the last.
var _direction_order: Array[int] = []
## Seconds until the next repeat, per held direction. A direction with no entry
## is not held, so the next press on it is a fresh one.
var _repeat_clock: Dictionary = {}
## The direction a repeat has just been sent for, cleared by the event arriving.
## Without it the gate would swallow the very press it emitted.
var _repeat_open: Dictionary = {}
## Whether all four reset buttons were down last frame, so the chord fires once
## per press rather than once per frame it is held.
var _reset_chord_down: bool = false
## Every on-screen controller in the tree, innermost last. A battle opened over
## the map puts a second one on screen, and only the top of this stack may draw
## or read a finger.
## Typed as Control rather than as the pad, which keeps this script off the one
## that draws it: the pad has to name this class, and two class names that name
## each other do not compile.
var _pads: Array[Control] = []

## `JoyTextDelay`, which is the whole of the hardware's menu auto-repeat
## (`home/joypad.asm`): a fresh press reloads `wTextDelayFrames` with 15, and
## every later frame the counter reaches zero the held button is reported
## pressed again and the counter is reloaded with 5.
const REPEAT_DELAY_FRAMES: int = 15
const REPEAT_INTERVAL_FRAMES: int = 5
## Counted in seconds so the repeat keeps the source's rate on a host drawing at
## something other than 60 Hz.
const FRAME_SECONDS: float = 1.0 / 60.0

## The four buttons a Game Boy resets on. `home/init.asm` wires them to the
## hardware rather than to any routine, so the chord works from anywhere the
## console is running and is not something the game can decline.
const RESET_CHORD: Array[int] = [
	Gen2Button.A, Gen2Button.B, Gen2Button.START, Gen2Button.SELECT,
]

## The autoload, cached after the first lookup.
static var _instance: Gen2InputRuntime = null


## Named relative to the root rather than as `/root/InputRuntime`: a script
## handed to `-s` runs outside the active scene tree, where an absolute path
## makes even `get_node_or_null` push an error before returning null. The
## no-runtime answer is the intended one for every headless run, so it has to be
## silent.
static func instance() -> Gen2InputRuntime:
	if _instance == null:
		var loop: SceneTree = Engine.get_main_loop() as SceneTree
		if loop != null:
			_instance = loop.root.get_node_or_null(^"InputRuntime") as Gen2InputRuntime
	return _instance


func _ready() -> void:
	# Before any event has arrived the only evidence is the hardware. A phone
	# should show its controller on the first frame rather than after the first
	# tap, and a desktop should not show one at all.
	_device = Gen2InputDevice.kind_for_hardware(
		not Input.get_connected_joypads().is_empty(),
		DisplayServer.is_touchscreen_available(),
	)
	apply_options(Gen2OptionsStore.current())


## Installs an options object's control scheme and touch settings. The settings
## page calls this after every change; nothing else needs to.
func apply_options(options: Gen2Options) -> void:
	if options == null:
		return
	_scheme = options.controls
	_mod_controls = options.mod_controls
	_touch_mode = options.touch_mode
	_layout = options.touch_layout
	Gen2InputActions.install(_scheme)
	install_mod_actions()
	scheme_changed.emit()
	_refresh_touch_controls()


## Puts every registered mod action in the [InputMap] with whatever the player
## bound it to. Called again after a mod loads, since a mod registers its
## actions during its own entry script and the options were applied before that.
func install_mod_actions() -> void:
	var actions: Array = Gen2ModHost.instance().actions()
	Gen2InputActions.install_mod_actions(actions, _mod_controls)
	# The on-screen controller places one button per action, so it needs the
	# labels; where each one sits, and whether they are drawn at all, is the
	# player's and stays in the layout.
	var buttons: Array = []
	for action: Dictionary in actions:
		buttons.append({"action": action["name"], "label": action["label"]})
	_layout.mod_buttons = buttons
	touch_controls_changed.emit(_touch_shown)


func scheme() -> Dictionary:
	return _scheme


func mod_controls() -> Dictionary:
	return _mod_controls


func touch_layout() -> Gen2TouchLayout:
	return _layout


func touch_mode() -> StringName:
	return _touch_mode


func device() -> StringName:
	return _device


## Whether the on-screen controller should be drawn right now.
func touch_controls_shown() -> bool:
	return _touch_shown


## Turns the on-screen controller back on and writes it to the options file.
##
## The escape from [constant Gen2Options.TOUCH_NEVER], which is the one setting
## that can leave a touch-only player with nothing to press. It restores `auto`
## rather than `always`, so a pad the player picks up again still hides it.
func reveal_touch_controls() -> bool:
	if _touch_mode != Gen2Options.TOUCH_NEVER:
		return false
	var options: Gen2Options = Gen2OptionsStore.current()
	options.touch_mode = Gen2Options.TOUCH_AUTO
	Gen2OptionsStore.save(options)
	_touch_mode = Gen2Options.TOUCH_AUTO
	# The gesture is a touch, so the device is a touchscreen whatever was last
	# used. Saying so is what makes `auto` resolve to shown on this same frame.
	_set_device(Gen2InputDevice.TOUCH)
	_refresh_touch_controls()
	return true


## Registers an on-screen controller as the frontmost one. The last to enter
## the tree is the one in front, which is what an overlay opened over a screen
## already is.
func claim_touch_pad(pad: Control) -> void:
	if pad == null or _pads.has(pad):
		return
	_pads.append(pad)
	touch_controls_changed.emit(_touch_shown)


func release_touch_pad(pad: Control) -> void:
	if not _pads.has(pad):
		return
	_pads.erase(pad)
	touch_controls_changed.emit(_touch_shown)


func active_touch_pad() -> Control:
	return _pads.back() if not _pads.is_empty() else null


## Presses a button from something that is not a device: the on-screen
## controller, a preview, or a test.
##
## Sent as an [InputEventAction] through [method Input.parse_input_event] rather
## than delivered to a screen directly, so it takes the same path a key does and
## arrives at both the event handlers and [method Input.is_action_pressed].
func press(button: int) -> void:
	_send(button, true)


func release(button: int) -> void:
	_send(button, false)


func _send(button: int, pressed: bool) -> void:
	send_action(Gen2Button.action(button), pressed)


## The same for an action named directly, which is what the on-screen controller
## presses a mod's own button with.
func send_action(action: StringName, pressed: bool) -> void:
	if String(action).is_empty():
		return
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


## Whether this event is a directional press nothing should act on. An analog
## stick reports a fresh [InputEventJoypadMotion] on every value change and each
## is an action press, so one push walked a menu the length of the list; a held
## key repeats at the OS rate for the same reason. The extras are swallowed in
## front of the engine's own focus navigation, and
## [method _advance_direction_repeat] puts back the repeat the hardware had.
func _gate_direction_repeat(event: InputEvent) -> bool:
	var button: int = Gen2Button.direction_in(event)
	if button == Gen2Button.NONE:
		return false
	if bool(_repeat_open.get(button, false)):
		_repeat_open[button] = false
		return false
	if _repeat_clock.has(button):
		return true
	_repeat_clock[button] = FRAME_SECONDS * float(REPEAT_DELAY_FRAMES)
	return false


## The direction currently held, most recently pressed first, or [constant
## Gen2Button.NONE]. Polled rather than read off events, because walking
## continues while a direction is held and the operating system's key repeat is
## not the rate the hardware walked at.
func held_direction() -> int:
	return _direction_order.back() if not _direction_order.is_empty() else Gen2Button.NONE


func _process(delta: float) -> void:
	for button: int in Gen2Button.DIRECTIONS:
		var held: bool = Gen2Button.held(button)
		var at: int = _direction_order.find(button)
		if held and at < 0:
			_direction_order.append(button)
		elif not held and at >= 0:
			_direction_order.remove_at(at)
	_advance_direction_repeat(delta)
	_poll_reset_chord()


## The reset chord, polled rather than read off events: four buttons at once is
## a state, and no single press says it.
func _poll_reset_chord() -> void:
	var down: bool = true
	for button: int in RESET_CHORD:
		if not Gen2Button.held(button):
			down = false
			break
	if down and not _reset_chord_down:
		reset_chord_pressed.emit()
	_reset_chord_down = down


## `JoyTextDelay`'s counter, one direction at a time. A direction the gate has
## seen pressed carries a clock; when it runs out the direction is pressed again
## on the player's behalf, which is what lets a held d-pad walk a list at all.
func _advance_direction_repeat(delta: float) -> void:
	for button: int in Gen2Button.DIRECTIONS:
		if not _direction_pressed(button):
			_repeat_clock.erase(button)
			_repeat_open.erase(button)
			continue
		if not _repeat_clock.has(button):
			continue
		var left: float = float(_repeat_clock[button]) - delta
		if left > 0.0:
			_repeat_clock[button] = left
			continue
		_repeat_clock[button] = FRAME_SECONDS * float(REPEAT_INTERVAL_FRAMES)
		_repeat_open[button] = true
		## Only a press. A release would take the action away from
		## [method Gen2Button.held] while the player is still holding the button,
		## and the map walks on that answer.
		send_action(Gen2Button.action(button), true)


## Whether a direction is down on either vocabulary; see
## [constant Gen2Button.UI_ACTIONS].
static func _direction_pressed(button: int) -> bool:
	return Gen2Button.held(button) \
		or Input.is_action_pressed(Gen2Button.UI_ACTIONS[button])


## Watches every event and consumes none, except a directional press the
## hardware would not have reported: see [method _gate_direction_repeat]. Device
## recon has to see input the screens never get, including the mouse motion that
## says the player has put the pad down.
func _input(event: InputEvent) -> void:
	if _gate_direction_repeat(event):
		var viewport: Viewport = get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		return
	var kind: StringName = Gen2InputDevice.kind_of(event)
	if kind.is_empty():
		return
	# Mouse motion alone is not evidence: a desk knocked while the player holds
	# a pad would hide the interface they are looking at. A click is.
	if kind == Gen2InputDevice.MOUSE and event is InputEventMouseMotion:
		return
	_set_device(kind)


func _set_device(kind: StringName) -> void:
	if kind == _device:
		return
	_device = kind
	device_changed.emit(kind)
	_refresh_touch_controls()


func _refresh_touch_controls() -> void:
	var shown: bool = false
	match _touch_mode:
		Gen2Options.TOUCH_ALWAYS:
			shown = true
		Gen2Options.TOUCH_NEVER:
			shown = false
		_:
			shown = _device == Gen2InputDevice.TOUCH
	if shown == _touch_shown:
		return
	_touch_shown = shown
	touch_controls_changed.emit(shown)
