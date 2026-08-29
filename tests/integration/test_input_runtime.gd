extends GutTest

## The live scheme and the active device, driven the way the game drives them.

var _runtime: Gen2InputRuntime = null


func before_each() -> void:
	_runtime = Gen2InputRuntime.instance()
	_runtime.apply_options(Gen2Options.new())


func after_each() -> void:
	for button: int in Gen2Button.ALL:
		_runtime.release(button)
	await get_tree().process_frame
	_runtime.apply_options(Gen2Options.new())
	Gen2OptionsStore.use_test_path()


## Two frames: one for the synthesised event to reach the input state, one for
## the runtime's own poll to see it.
func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func test_the_autoload_is_reachable_without_the_global_name() -> void:
	assert_not_null(_runtime, "a preview tool has to be able to find it")
	assert_same(_runtime, get_tree().root.get_node("/root/InputRuntime"))


## A synthesised press has to arrive both at the event handlers and at the polled
## state, or a screen would see the button and the walk would not.
func test_a_pressed_button_reaches_the_polled_input_state() -> void:
	_runtime.press(Gen2Button.A)
	await _settle()
	assert_true(Input.is_action_pressed(&"gen2_a"))

	_runtime.release(Gen2Button.A)
	await _settle()
	assert_false(Input.is_action_pressed(&"gen2_a"))


func test_pressing_nothing_is_harmless() -> void:
	_runtime.press(Gen2Button.NONE)
	await _settle()
	assert_eq(_runtime.held_direction(), Gen2Button.NONE)


## Turning a corner means pressing the next direction before releasing the last,
## so the newest held one wins and the walk turns rather than stalling.
func test_the_newest_held_direction_wins_and_the_older_one_survives_it() -> void:
	_runtime.press(Gen2Button.UP)
	await _settle()
	assert_eq(_runtime.held_direction(), Gen2Button.UP)

	_runtime.press(Gen2Button.LEFT)
	await _settle()
	assert_eq(_runtime.held_direction(), Gen2Button.LEFT)

	_runtime.release(Gen2Button.LEFT)
	await _settle()
	assert_eq(_runtime.held_direction(), Gen2Button.UP)

	_runtime.release(Gen2Button.UP)
	await _settle()
	assert_eq(_runtime.held_direction(), Gen2Button.NONE)


func test_the_active_device_follows_the_events() -> void:
	_runtime._input(InputEventKey.new())
	assert_eq(_runtime.device(), Gen2InputDevice.KEYBOARD)

	_runtime._input(InputEventJoypadButton.new())
	assert_eq(_runtime.device(), Gen2InputDevice.GAMEPAD)

	_runtime._input(InputEventScreenTouch.new())
	assert_eq(_runtime.device(), Gen2InputDevice.TOUCH)


## A knocked desk should not hide the interface a pad player is looking at.
func test_mouse_motion_alone_does_not_change_the_device() -> void:
	_runtime._input(InputEventJoypadButton.new())
	_runtime._input(InputEventMouseMotion.new())
	assert_eq(_runtime.device(), Gen2InputDevice.GAMEPAD)

	_runtime._input(InputEventMouseButton.new())
	assert_eq(_runtime.device(), Gen2InputDevice.MOUSE)


func test_automatic_shows_the_controller_only_while_a_finger_is_on_the_screen() -> void:
	var options := Gen2Options.new()
	options.touch_mode = Gen2Options.TOUCH_AUTO
	_runtime.apply_options(options)

	_runtime._input(InputEventKey.new())
	assert_false(_runtime.touch_controls_shown())

	_runtime._input(InputEventScreenTouch.new())
	assert_true(_runtime.touch_controls_shown())

	_runtime._input(InputEventJoypadButton.new())
	assert_false(_runtime.touch_controls_shown(), "a pad puts them away")


## Reported from a released Android build: Android's Back put the on-screen
## controller away and grew the game screen into the room it left, on `auto`
## only, since `always` never asks which device is in use. A phone's own
## furniture arrives as key events and a phone has no keyboard to pick up.
func test_a_phone_key_does_not_put_the_on_screen_controller_away() -> void:
	_runtime._handheld = true
	_runtime._input(InputEventScreenTouch.new())
	assert_true(_runtime.touch_controls_shown(), "a finger shows them")

	var back := InputEventKey.new()
	back.physical_keycode = KEY_BACK
	back.pressed = true
	_runtime._input(back)
	assert_eq(_runtime.device(), Gen2InputDevice.TOUCH, "Back is the phone, not a keyboard")
	assert_true(_runtime.touch_controls_shown(), "and the controller stays up")

	_runtime._input(InputEventJoypadButton.new())
	assert_false(_runtime.touch_controls_shown(), "a pad plugged into it still does")
	_runtime._handheld = Gen2InputDevice.is_handheld()


func test_the_pinned_modes_ignore_the_device() -> void:
	for pair: Array in [[Gen2Options.TOUCH_ALWAYS, true], [Gen2Options.TOUCH_NEVER, false]]:
		var options := Gen2Options.new()
		options.touch_mode = pair[0]
		_runtime.apply_options(options)
		for event: InputEvent in [
			InputEventKey.new(), InputEventScreenTouch.new(), InputEventJoypadButton.new(),
		]:
			_runtime._input(event)
			assert_eq(_runtime.touch_controls_shown(), pair[1], String(pair[0]))


func test_applying_a_scheme_installs_it_in_the_input_map() -> void:
	var options := Gen2Options.new()
	options.controls[Gen2Button.START] = [
		{"kind": Gen2InputActions.KIND_KEY, "code": KEY_F9},
	]
	_runtime.apply_options(options)

	var key := InputEventKey.new()
	key.physical_keycode = KEY_F9
	key.pressed = true
	assert_true(key.is_action_pressed(&"gen2_start"))
	assert_eq(_runtime.scheme(), options.controls)


func test_reveal_does_nothing_unless_the_controller_is_switched_off() -> void:
	var options := Gen2Options.new()
	options.touch_mode = Gen2Options.TOUCH_AUTO
	_runtime.apply_options(options)
	assert_false(_runtime.reveal_touch_controls(), "there is nothing to reveal")


## `JoyTextDelay`: the second press of a direction the player never let go of is
## the hardware's own repeat, and it does not arrive for fifteen frames. Without
## the gate an analog stick reported one on every event it sent, which walked a
## menu cursor the length of its list on one push.
func test_a_held_direction_repeats_at_the_source_rate_and_not_faster() -> void:
	var down := InputEventJoypadMotion.new()
	down.axis = JOY_AXIS_LEFT_Y
	down.axis_value = 1.0
	assert_false(_runtime._gate_direction_repeat(down), "the first press is the player's")
	down.axis_value = 0.98
	assert_true(_runtime._gate_direction_repeat(down), "the stick has not been let go")
	assert_true(_runtime._gate_direction_repeat(down))

	## The repeat the gate owes, spent as frames rather than as presses.
	_runtime.press(Gen2Button.DOWN)
	await _settle()
	assert_eq(_spend(Gen2InputRuntime.REPEAT_DELAY_FRAMES + 1), 1,
		"one repeat in the first fifteen frames, not fifteen")
	_runtime.release(Gen2Button.DOWN)
	await _settle()


func _key(pressed: bool) -> InputEventKey:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_DOWN
	key.pressed = pressed
	return key


## Spends [param frames] of repeat and answers how many reached the tree.
func _spend(frames: int) -> int:
	var counter := RepeatCounter.new()
	add_child_autoqfree(counter)
	for _frame: int in frames:
		_runtime._advance_direction_repeat(Gen2InputRuntime.FRAME_SECONDS)
	var seen: int = counter.seen
	counter.queue_free()
	return seen


## A repeat is an edge, not a state. `Input` keeps an action's API state apart
## from its device state and reports either as pressed, and only an action
## release clears the API half, so a repeat sent through
## [method Input.parse_input_event] latched the direction: the key came up, the
## action stayed pressed, and the walk, the menu and the repeat itself all ran on
## with nothing able to stop them.
func test_a_held_direction_lets_go_the_moment_the_key_does() -> void:
	Input.parse_input_event(_key(true))
	_runtime._input(_key(true))
	await _settle()
	assert_eq(_runtime.held_direction(), Gen2Button.DOWN)
	assert_gt(_spend(120), 15, "two seconds of a held key is repeating")

	Input.parse_input_event(_key(false))
	await _settle()
	assert_false(Input.is_action_pressed(&"gen2_down"), "a repeat must not latch it")
	assert_eq(_runtime.held_direction(), Gen2Button.NONE, "the walk stops with the key")
	assert_eq(_spend(120), 0, "and so does the menu")


## Four buttons at once is a state no single press says, so the chord is polled
## and reported once per press of it.
func test_the_reset_chord_is_reported_once_while_it_is_held() -> void:
	var fired: Array = []
	_runtime.reset_chord_pressed.connect(func() -> void: fired.append(true))
	for button: int in Gen2InputRuntime.RESET_CHORD:
		_runtime.press(button)
	await _settle()
	await _settle()
	assert_eq(fired.size(), 1, "held for four frames, reported once")
	_runtime.release(Gen2Button.SELECT)
	await _settle()
	_runtime.press(Gen2Button.SELECT)
	await _settle()
	assert_eq(fired.size(), 2, "let go and pressed again is a second reset")
	for button: int in Gen2InputRuntime.RESET_CHORD:
		_runtime.release(button)
	await _settle()


## Counts the repeats the runtime pushes into the tree, which is what a screen
## sees. [member Gen2InputRuntime._repeat_open] cannot be read for this: the gate
## clears it as the event arrives, and the event arrives inside the same call.
class RepeatCounter extends Node:
	var seen: int = 0

	func _input(event: InputEvent) -> void:
		if event is InputEventAction and event.is_action_pressed(&"gen2_down"):
			seen += 1


## Android's Back reaches every node as a notification. The runtime turns it into
## one signal so the screen that is up decides what it costs, and
## `quit_on_go_back` is off so nothing leaves the app on its own.
func test_the_back_notification_is_reported_as_a_signal() -> void:
	var fired: Array = []
	_runtime.back_requested.connect(func() -> void: fired.append(true))
	_runtime.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_eq(fired.size(), 1, "one press, one report")
	assert_false(
		ProjectSettings.get_setting("application/config/quit_on_go_back", true),
		"the engine must not quit before a screen has answered",
	)
