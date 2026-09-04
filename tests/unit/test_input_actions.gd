extends GutTest

## The button vocabulary and the bindings behind it.
##
## The [InputMap] is global engine state, so every test that installs a scheme
## puts the defaults back afterwards rather than leaving the next one to guess.


func after_each() -> void:
	PokeInputActions.install(PokeInputActions.defaults())


func _key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code as Key
	event.pressed = true
	return event


func test_every_button_has_an_action_and_maps_back() -> void:
	assert_eq(PokeButton.ALL.size(), 8)
	for button: int in PokeButton.ALL:
		var action: StringName = PokeButton.action(button)
		assert_false(action.is_empty(), "button %d has an action" % button)
		assert_eq(PokeButton.from_action(action), button)
	assert_eq(PokeButton.from_action(&"not_a_button"), PokeButton.NONE)


func test_directions_carry_vectors_both_ways() -> void:
	assert_eq(PokeButton.DIRECTIONS.size(), 4)
	for button: int in PokeButton.DIRECTIONS:
		assert_true(PokeButton.is_direction(button))
		assert_eq(PokeButton.from_vector(PokeButton.vector(button)), button)
	assert_false(PokeButton.is_direction(PokeButton.A))
	assert_eq(PokeButton.vector(PokeButton.A), Vector2i.ZERO)
	assert_eq(PokeButton.from_vector(Vector2i(1, 1)), PokeButton.NONE)


func test_defaults_bind_every_button_on_both_devices() -> void:
	var scheme: Dictionary = PokeInputActions.defaults()
	for button: int in PokeButton.ALL:
		var devices: Array[StringName] = []
		for binding: Dictionary in scheme[button]:
			var device: StringName = PokeInputActions.device_of(binding)
			if not devices.has(device):
				devices.append(device)
		assert_true(
			devices.has(PokeInputActions.DEVICE_KEYBOARD),
			"%s has a key" % PokeButton.label(button),
		)
		assert_true(
			devices.has(PokeInputActions.DEVICE_GAMEPAD),
			"%s has a pad binding" % PokeButton.label(button),
		)


func test_defaults_are_a_copy_the_caller_may_edit() -> void:
	var scheme: Dictionary = PokeInputActions.defaults()
	(scheme[PokeButton.A] as Array).clear()
	assert_false((PokeInputActions.defaults()[PokeButton.A] as Array).is_empty())


## Rebuilt, not merged: a rebind that only added would leave the old key working
## and the settings page would be lying about what is bound.
func test_install_replaces_the_previous_scheme() -> void:
	PokeInputActions.install(PokeInputActions.defaults())
	assert_true(_key(KEY_Z).is_action_pressed(&"gen2_a"))

	var scheme: Dictionary = PokeInputActions.defaults()
	scheme[PokeButton.A] = [{"kind": PokeInputActions.KIND_KEY, "code": KEY_M}]
	PokeInputActions.install(scheme)

	assert_true(_key(KEY_M).is_action_pressed(&"gen2_a"))
	assert_false(_key(KEY_Z).is_action_pressed(&"gen2_a"))
	assert_eq(InputMap.action_get_events(&"gen2_a").size(), 1)


func test_install_sets_the_deadzone_a_stick_needs() -> void:
	PokeInputActions.install(PokeInputActions.defaults())
	assert_eq(InputMap.action_get_deadzone(&"gen2_up"), PokeInputActions.DEADZONE)


func test_events_round_trip_through_bindings() -> void:
	var cases: Array[Dictionary] = [
		{"kind": PokeInputActions.KIND_KEY, "code": KEY_Q},
		{"kind": PokeInputActions.KIND_PAD_BUTTON, "code": JOY_BUTTON_X},
		{"kind": PokeInputActions.KIND_PAD_AXIS, "code": JOY_AXIS_LEFT_Y, "sign": -1},
	]
	for binding: Dictionary in cases:
		var event: InputEvent = PokeInputActions.to_event(binding)
		assert_not_null(event, String(binding["kind"]))
		assert_eq(PokeInputActions.from_event(event), binding)


func test_a_key_binding_is_physical_only() -> void:
	var event: InputEventKey = PokeInputActions.to_event(
		{"kind": PokeInputActions.KIND_KEY, "code": KEY_W}
	)
	assert_eq(event.physical_keycode, KEY_W)
	assert_eq(event.keycode, KEY_NONE, "a second code would match twice on one layout")


func test_pad_bindings_match_every_device() -> void:
	for binding: Dictionary in [
		{"kind": PokeInputActions.KIND_PAD_BUTTON, "code": JOY_BUTTON_A},
		{"kind": PokeInputActions.KIND_PAD_AXIS, "code": JOY_AXIS_LEFT_X, "sign": 1},
	]:
		assert_eq(
			PokeInputActions.to_event(binding).device,
			PokeInputActions.ALL_DEVICES,
			"the other port is not a rebind",
		)


## A stick resting near centre reports motion constantly, and none of it is a
## binding the player meant to make.
func test_a_resting_stick_is_not_a_binding() -> void:
	var motion := InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = 0.1
	assert_eq(PokeInputActions.from_event(motion), {})

	motion.axis_value = -0.9
	assert_eq(int(PokeInputActions.from_event(motion)["sign"]), -1)


func test_unusable_events_are_not_bindings() -> void:
	assert_eq(PokeInputActions.from_event(InputEventMouseMotion.new()), {})
	assert_eq(PokeInputActions.from_event(InputEventKey.new()), {})


func test_sanitize_returns_the_defaults_for_anything_unreadable() -> void:
	for raw: Variant in [null, 7, "controls", []]:
		assert_true(
			PokeInputActions.is_default(PokeInputActions.sanitize(raw)),
			"unreadable input falls back",
		)


func test_sanitize_reads_a_stored_scheme_back() -> void:
	var scheme: Dictionary = PokeInputActions.defaults()
	scheme[PokeButton.START] = [{"kind": PokeInputActions.KIND_KEY, "code": KEY_F8}]
	var restored: Dictionary = PokeInputActions.sanitize(PokeInputActions.to_dict(scheme))
	assert_eq(restored[PokeButton.START], scheme[PokeButton.START])


## Clamped, not refused: one unreadable binding costs that binding, and a button
## left with none at all keeps its default rather than becoming unpressable.
func test_sanitize_drops_bad_rows_and_keeps_a_button_pressable() -> void:
	var stored: Dictionary = PokeInputActions.to_dict(PokeInputActions.defaults())
	stored["gen2_b"] = [
		{"kind": "sorcery", "code": 4},
		{"kind": PokeInputActions.KIND_KEY, "code": 0},
		{"kind": PokeInputActions.KIND_PAD_BUTTON, "code": -3},
		"not a row",
		{"kind": PokeInputActions.KIND_KEY, "code": KEY_N},
	]
	stored["gen2_a"] = []
	var scheme: Dictionary = PokeInputActions.sanitize(stored)

	assert_eq(scheme[PokeButton.B], [{"kind": PokeInputActions.KIND_KEY, "code": KEY_N}])
	assert_eq(scheme[PokeButton.A], PokeInputActions.defaults()[PokeButton.A])


func test_sanitize_drops_duplicates_and_bounds_the_count() -> void:
	var stored: Dictionary = PokeInputActions.to_dict(PokeInputActions.defaults())
	var rows: Array = []
	for index: int in PokeInputActions.MAX_BINDINGS + 4:
		rows.append({"kind": PokeInputActions.KIND_KEY, "code": KEY_A + index})
	rows.append({"kind": PokeInputActions.KIND_KEY, "code": KEY_A})
	stored["gen2_select"] = rows
	var bindings: Array = PokeInputActions.sanitize(stored)[PokeButton.SELECT]

	assert_eq(bindings.size(), PokeInputActions.MAX_BINDINGS)
	assert_eq(bindings[0], {"kind": PokeInputActions.KIND_KEY, "code": KEY_A})


func test_conflicts_names_the_other_buttons_holding_a_binding() -> void:
	var scheme: Dictionary = PokeInputActions.defaults()
	var space: Dictionary = {"kind": PokeInputActions.KIND_KEY, "code": KEY_SPACE}

	assert_eq(PokeInputActions.conflicts(scheme, space, PokeButton.A), [] as Array[int])
	assert_eq(PokeInputActions.conflicts(scheme, space, PokeButton.B), [PokeButton.A] as Array[int])


func test_describe_names_each_kind() -> void:
	assert_eq(
		PokeInputActions.describe({"kind": PokeInputActions.KIND_PAD_BUTTON, "code": JOY_BUTTON_START}),
		"Start",
	)
	assert_eq(
		PokeInputActions.describe({
			"kind": PokeInputActions.KIND_PAD_AXIS, "code": JOY_AXIS_LEFT_Y, "sign": 1,
		}),
		"Left stick down",
	)
	assert_eq(PokeInputActions.describe({}), "Unbound")
	assert_false(
		PokeInputActions.describe({"kind": PokeInputActions.KIND_KEY, "code": KEY_SPACE}).is_empty()
	)


func test_a_key_beyond_the_named_pad_buttons_still_reads() -> void:
	assert_string_contains(
		PokeInputActions.describe({"kind": PokeInputActions.KIND_PAD_BUTTON, "code": 99}), "99"
	)


func test_the_engines_ui_actions_answer_to_a_pad() -> void:
	# Godot binds ui_accept to three keys and nothing else, so a machine with no
	# keyboard could move every focus ring and choose nothing under it. The
	# engine's own events are put back afterwards, the way the scheme is.
	var stock: Dictionary = {}
	for action: StringName in PokeInputActions.UI_PAD_BUTTONS:
		stock[action] = InputMap.action_get_events(action)
		InputMap.action_erase_events(action)
	PokeInputActions.install(PokeInputActions.defaults())

	for action: StringName in PokeInputActions.UI_PAD_BUTTONS:
		var pad := InputEventJoypadButton.new()
		pad.device = PokeInputActions.ALL_DEVICES
		pad.button_index = int(PokeInputActions.UI_PAD_BUTTONS[action]) as JoyButton
		pad.pressed = true
		assert_true(InputMap.event_is_action(pad, action), "%s answers to its pad button" % action)

	for action: StringName in stock:
		for event: InputEvent in stock[action]:
			if not InputMap.action_has_event(action, event):
				InputMap.action_add_event(action, event)


func test_installing_twice_adds_one_ui_pad_binding() -> void:
	PokeInputActions.install(PokeInputActions.defaults())
	var once: int = InputMap.action_get_events(&"ui_accept").size()
	PokeInputActions.install(PokeInputActions.defaults())
	assert_eq(InputMap.action_get_events(&"ui_accept").size(), once)


## Godot moves a focus ring on `ui_up` and a menu moves on `gen2_up`, and one key
## or pad button produces both. Anything reading a direction off an event has to
## answer for either, or the launcher and the game disagree about the same press.
func test_a_direction_is_read_off_either_vocabulary() -> void:
	PokeInputActions.install(PokeInputActions.defaults())
	var key := InputEventKey.new()
	key.physical_keycode = KEY_DOWN
	key.pressed = true
	assert_eq(PokeButton.direction_in(key), PokeButton.DOWN)

	## W is bound to the cartridge's UP and to nothing of Godot's.
	var wasd := InputEventKey.new()
	wasd.physical_keycode = KEY_W
	wasd.pressed = true
	assert_eq(PokeButton.direction_in(wasd), PokeButton.UP)

	var accept := InputEventKey.new()
	accept.physical_keycode = KEY_Z
	accept.pressed = true
	assert_eq(PokeButton.direction_in(accept), PokeButton.NONE, "A is not a direction")
