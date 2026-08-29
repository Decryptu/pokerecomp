extends GutTest

## Which device an event says the player is using.


func test_each_event_kind_names_its_device() -> void:
	assert_eq(Gen2InputDevice.kind_of(InputEventKey.new()), Gen2InputDevice.KEYBOARD)
	assert_eq(Gen2InputDevice.kind_of(InputEventJoypadButton.new()), Gen2InputDevice.GAMEPAD)
	assert_eq(Gen2InputDevice.kind_of(InputEventJoypadMotion.new()), Gen2InputDevice.GAMEPAD)
	assert_eq(Gen2InputDevice.kind_of(InputEventScreenTouch.new()), Gen2InputDevice.TOUCH)
	assert_eq(Gen2InputDevice.kind_of(InputEventScreenDrag.new()), Gen2InputDevice.TOUCH)
	assert_eq(Gen2InputDevice.kind_of(InputEventMouseButton.new()), Gen2InputDevice.MOUSE)


func test_an_event_that_names_no_device_answers_nothing() -> void:
	assert_eq(Gen2InputDevice.kind_of(InputEventAction.new()), &"")


## `emulate_mouse_from_touch` is on by default, which is what makes the launcher
## work under a finger. Without this the answer would flip back to mouse on every
## tap and the on-screen controller would vanish mid-press.
func test_a_mouse_event_emulated_from_a_touch_reads_as_touch() -> void:
	var click := InputEventMouseButton.new()
	click.device = InputEvent.DEVICE_ID_EMULATION
	assert_eq(Gen2InputDevice.kind_of(click), Gen2InputDevice.TOUCH)


## Android sends Back, its navigation bar and its volume rocker as key events,
## and a phone has no keyboard of its own. Read as one they put the on-screen
## controller away mid-game and the screen grew into the room it left, which is
## what a player reported.
func test_a_phone_has_no_keyboard_and_no_mouse_to_pick_up() -> void:
	var back := InputEventKey.new()
	back.physical_keycode = KEY_BACK
	assert_eq(Gen2InputDevice.evidence_of(back, true), &"")
	assert_eq(Gen2InputDevice.evidence_of(InputEventMouseButton.new(), true), &"")
	assert_eq(
		Gen2InputDevice.evidence_of(InputEventScreenTouch.new(), true), Gen2InputDevice.TOUCH
	)
	assert_eq(
		Gen2InputDevice.evidence_of(InputEventJoypadButton.new(), true),
		Gen2InputDevice.GAMEPAD,
		"a pad plugged into a phone is still a pad",
	)


func test_evidence_is_the_kind_for_everything_a_player_holds() -> void:
	var typed := InputEventKey.new()
	typed.physical_keycode = KEY_Z
	assert_eq(Gen2InputDevice.evidence_of(typed, false), Gen2InputDevice.KEYBOARD)
	assert_eq(
		Gen2InputDevice.evidence_of(InputEventScreenTouch.new(), false), Gen2InputDevice.TOUCH
	)
	assert_eq(
		Gen2InputDevice.evidence_of(InputEventJoypadButton.new(), false),
		Gen2InputDevice.GAMEPAD,
	)
	assert_eq(
		Gen2InputDevice.evidence_of(InputEventMouseButton.new(), false), Gen2InputDevice.MOUSE
	)


## A desk knocked while the player holds a pad would otherwise hide the
## interface they are looking at, and a drifting stick would do it with nobody
## in the room. A click and a push past the deadzone are evidence; neither of
## these is.
func test_a_pointer_that_moved_and_a_stick_that_did_not_are_not_evidence() -> void:
	assert_eq(Gen2InputDevice.kind_of(InputEventMouseMotion.new()), Gen2InputDevice.MOUSE)
	assert_eq(Gen2InputDevice.evidence_of(InputEventMouseMotion.new(), false), &"")

	var drift := InputEventJoypadMotion.new()
	drift.axis_value = Gen2InputActions.DEADZONE - 0.01
	assert_eq(Gen2InputDevice.evidence_of(drift, false), &"")
	drift.axis_value = Gen2InputActions.DEADZONE
	assert_eq(Gen2InputDevice.evidence_of(drift, false), Gen2InputDevice.GAMEPAD)


func test_pointers_are_the_kinds_that_need_no_focus_ring() -> void:
	assert_true(Gen2InputDevice.is_pointer(Gen2InputDevice.MOUSE))
	assert_true(Gen2InputDevice.is_pointer(Gen2InputDevice.TOUCH))
	assert_false(Gen2InputDevice.is_pointer(Gen2InputDevice.KEYBOARD))
	assert_false(Gen2InputDevice.is_pointer(Gen2InputDevice.GAMEPAD))


func test_every_kind_is_named() -> void:
	for kind: StringName in Gen2InputDevice.KINDS:
		assert_false(Gen2InputDevice.label(kind).is_empty(), String(kind))
	assert_eq(Gen2InputDevice.label(&"nothing"), "")


func test_the_first_frame_prefers_a_pad_over_a_touchscreen() -> void:
	# A Switch in the hands and a phone with a controller both report both, and
	# on both the player is holding buttons rather than touching glass.
	assert_eq(Gen2InputDevice.kind_for_hardware(true, true), Gen2InputDevice.GAMEPAD)
	assert_eq(Gen2InputDevice.kind_for_hardware(true, false), Gen2InputDevice.GAMEPAD)
	assert_eq(Gen2InputDevice.kind_for_hardware(false, true), Gen2InputDevice.TOUCH)
	assert_eq(Gen2InputDevice.kind_for_hardware(false, false), Gen2InputDevice.KEYBOARD)
