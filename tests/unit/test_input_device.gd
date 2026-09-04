extends GutTest

## Which device an event says the player is using.


func test_each_event_kind_names_its_device() -> void:
	assert_eq(PokeInputDevice.kind_of(InputEventKey.new()), PokeInputDevice.KEYBOARD)
	assert_eq(PokeInputDevice.kind_of(InputEventJoypadButton.new()), PokeInputDevice.GAMEPAD)
	assert_eq(PokeInputDevice.kind_of(InputEventJoypadMotion.new()), PokeInputDevice.GAMEPAD)
	assert_eq(PokeInputDevice.kind_of(InputEventScreenTouch.new()), PokeInputDevice.TOUCH)
	assert_eq(PokeInputDevice.kind_of(InputEventScreenDrag.new()), PokeInputDevice.TOUCH)
	assert_eq(PokeInputDevice.kind_of(InputEventMouseButton.new()), PokeInputDevice.MOUSE)


func test_an_event_that_names_no_device_answers_nothing() -> void:
	assert_eq(PokeInputDevice.kind_of(InputEventAction.new()), &"")


## `emulate_mouse_from_touch` is on by default, which is what makes the launcher
## work under a finger. Without this the answer would flip back to mouse on every
## tap and the on-screen controller would vanish mid-press.
func test_a_mouse_event_emulated_from_a_touch_reads_as_touch() -> void:
	var click := InputEventMouseButton.new()
	click.device = InputEvent.DEVICE_ID_EMULATION
	assert_eq(PokeInputDevice.kind_of(click), PokeInputDevice.TOUCH)


## Android sends Back, its navigation bar and its volume rocker as key events,
## and a phone has no keyboard of its own. Read as one they put the on-screen
## controller away mid-game and the screen grew into the room it left, which is
## what a player reported.
func test_a_phone_has_no_keyboard_and_no_mouse_to_pick_up() -> void:
	var back := InputEventKey.new()
	back.physical_keycode = KEY_BACK
	assert_eq(PokeInputDevice.evidence_of(back, true), &"")
	assert_eq(PokeInputDevice.evidence_of(InputEventMouseButton.new(), true), &"")
	assert_eq(
		PokeInputDevice.evidence_of(InputEventScreenTouch.new(), true), PokeInputDevice.TOUCH
	)
	assert_eq(
		PokeInputDevice.evidence_of(InputEventJoypadButton.new(), true),
		PokeInputDevice.GAMEPAD,
		"a pad plugged into a phone is still a pad",
	)


func test_evidence_is_the_kind_for_everything_a_player_holds() -> void:
	var typed := InputEventKey.new()
	typed.physical_keycode = KEY_Z
	assert_eq(PokeInputDevice.evidence_of(typed, false), PokeInputDevice.KEYBOARD)
	assert_eq(
		PokeInputDevice.evidence_of(InputEventScreenTouch.new(), false), PokeInputDevice.TOUCH
	)
	assert_eq(
		PokeInputDevice.evidence_of(InputEventJoypadButton.new(), false),
		PokeInputDevice.GAMEPAD,
	)
	assert_eq(
		PokeInputDevice.evidence_of(InputEventMouseButton.new(), false), PokeInputDevice.MOUSE
	)


## A desk knocked while the player holds a pad would otherwise hide the
## interface they are looking at, and a drifting stick would do it with nobody
## in the room. A click and a push past the deadzone are evidence; neither of
## these is.
func test_a_pointer_that_moved_and_a_stick_that_did_not_are_not_evidence() -> void:
	assert_eq(PokeInputDevice.kind_of(InputEventMouseMotion.new()), PokeInputDevice.MOUSE)
	assert_eq(PokeInputDevice.evidence_of(InputEventMouseMotion.new(), false), &"")

	var drift := InputEventJoypadMotion.new()
	drift.axis_value = PokeInputActions.DEADZONE - 0.01
	assert_eq(PokeInputDevice.evidence_of(drift, false), &"")
	drift.axis_value = PokeInputActions.DEADZONE
	assert_eq(PokeInputDevice.evidence_of(drift, false), PokeInputDevice.GAMEPAD)


func test_pointers_are_the_kinds_that_need_no_focus_ring() -> void:
	assert_true(PokeInputDevice.is_pointer(PokeInputDevice.MOUSE))
	assert_true(PokeInputDevice.is_pointer(PokeInputDevice.TOUCH))
	assert_false(PokeInputDevice.is_pointer(PokeInputDevice.KEYBOARD))
	assert_false(PokeInputDevice.is_pointer(PokeInputDevice.GAMEPAD))


func test_every_kind_is_named() -> void:
	for kind: StringName in PokeInputDevice.KINDS:
		assert_false(PokeInputDevice.label(kind).is_empty(), String(kind))
	assert_eq(PokeInputDevice.label(&"nothing"), "")


func test_the_first_frame_prefers_a_pad_over_a_touchscreen() -> void:
	# A Switch in the hands and a phone with a controller both report both, and
	# on both the player is holding buttons rather than touching glass.
	assert_eq(PokeInputDevice.kind_for_hardware(true, true), PokeInputDevice.GAMEPAD)
	assert_eq(PokeInputDevice.kind_for_hardware(true, false), PokeInputDevice.GAMEPAD)
	assert_eq(PokeInputDevice.kind_for_hardware(false, true), PokeInputDevice.TOUCH)
	assert_eq(PokeInputDevice.kind_for_hardware(false, false), PokeInputDevice.KEYBOARD)
