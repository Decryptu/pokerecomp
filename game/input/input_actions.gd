class_name PokeInputActions
extends RefCounted

## What a device has to do to produce a [PokeButton], as data: a plain dictionary,
## so the whole control scheme survives a trip through the options file and the
## remap UI can describe one without holding an [InputEvent]. Three kinds cover
## every device the engine reports, `key`, `pad_button` and `pad_axis`, each with
## a `code` and the axis one a `sign`. Keys bind by physical keycode, so the d-pad
## keeps the WASD positions on a layout that does not spell WASD there, and
## [method describe] asks the platform what that key is labelled. Nothing here
## reads or writes the options file.

const KIND_KEY: StringName = &"key"
const KIND_PAD_BUTTON: StringName = &"pad_button"
const KIND_PAD_AXIS: StringName = &"pad_axis"
const KINDS: Array[StringName] = [KIND_KEY, KIND_PAD_BUTTON, KIND_PAD_AXIS]

const DEVICE_KEYBOARD: StringName = &"keyboard"
const DEVICE_GAMEPAD: StringName = &"gamepad"

## Past this much of its travel a stick counts as pressed. Godot applies it per
## action, so it is set here rather than left at the 0.2 default, which walks
## the player on a worn stick sitting still.
const DEADZONE: float = 0.5

## An [InputMap] event with this device matches every device, which is what a
## pad binding wants: the player should not have to rebind because they plugged
## the controller into the other port.
const ALL_DEVICES: int = -1

## The pad button Godot's own UI actions are missing.
##
## `ui_accept` ships as Enter, Keypad Enter and Space, and `ui_cancel` as Escape
## alone, so on a machine with no keyboard every focus ring in the launcher can
## be moved and nothing under it can be chosen. The page pair and the menu key
## are missing the same way, and these five are added rather than replaced.
const UI_PAD_BUTTONS: Dictionary = {
	&"ui_accept": JOY_BUTTON_A,
	&"ui_cancel": JOY_BUTTON_B,
	&"ui_menu": JOY_BUTTON_Y,
	&"ui_page_up": JOY_BUTTON_LEFT_SHOULDER,
	&"ui_page_down": JOY_BUTTON_RIGHT_SHOULDER,
}

## `ui_menu` ships as the Menu key, which most keyboards do not have and no
## legend should print. Replaced with the third key of the Z, X, C row: Tab is
## Godot's own focus step, and A and B are already Z and X.
const UI_KEYS: Dictionary = {
	&"ui_menu": KEY_C,
}

## How many bindings one button may carry. The remap UI shows a fixed number of
## slots, and an options file claiming hundreds is a file to clamp, not to obey.
const MAX_BINDINGS: int = 6

const DEFAULTS: Dictionary = {
	PokeButton.UP: [
		{"kind": KIND_KEY, "code": KEY_UP},
		{"kind": KIND_KEY, "code": KEY_W},
		{"kind": KIND_PAD_BUTTON, "code": JOY_BUTTON_DPAD_UP},
		{"kind": KIND_PAD_AXIS, "code": JOY_AXIS_LEFT_Y, "sign": -1},
	],
	PokeButton.DOWN: [
		{"kind": KIND_KEY, "code": KEY_DOWN},
		{"kind": KIND_KEY, "code": KEY_S},
		{"kind": KIND_PAD_BUTTON, "code": JOY_BUTTON_DPAD_DOWN},
		{"kind": KIND_PAD_AXIS, "code": JOY_AXIS_LEFT_Y, "sign": 1},
	],
	PokeButton.LEFT: [
		{"kind": KIND_KEY, "code": KEY_LEFT},
		{"kind": KIND_KEY, "code": KEY_A},
		{"kind": KIND_PAD_BUTTON, "code": JOY_BUTTON_DPAD_LEFT},
		{"kind": KIND_PAD_AXIS, "code": JOY_AXIS_LEFT_X, "sign": -1},
	],
	PokeButton.RIGHT: [
		{"kind": KIND_KEY, "code": KEY_RIGHT},
		{"kind": KIND_KEY, "code": KEY_D},
		{"kind": KIND_PAD_BUTTON, "code": JOY_BUTTON_DPAD_RIGHT},
		{"kind": KIND_PAD_AXIS, "code": JOY_AXIS_LEFT_X, "sign": 1},
	],
	PokeButton.A: [
		{"kind": KIND_KEY, "code": KEY_Z},
		{"kind": KIND_KEY, "code": KEY_SPACE},
		{"kind": KIND_PAD_BUTTON, "code": JOY_BUTTON_A},
	],
	PokeButton.B: [
		{"kind": KIND_KEY, "code": KEY_X},
		{"kind": KIND_KEY, "code": KEY_ESCAPE},
		{"kind": KIND_PAD_BUTTON, "code": JOY_BUTTON_B},
	],
	PokeButton.START: [
		{"kind": KIND_KEY, "code": KEY_ENTER},
		{"kind": KIND_KEY, "code": KEY_KP_ENTER},
		{"kind": KIND_PAD_BUTTON, "code": JOY_BUTTON_START},
	],
	PokeButton.SELECT: [
		{"kind": KIND_KEY, "code": KEY_BACKSPACE},
		{"kind": KIND_KEY, "code": KEY_TAB},
		{"kind": KIND_PAD_BUTTON, "code": JOY_BUTTON_BACK},
	],
}

## Godot names no joypad button, and the numbers are meaningless to a player.
## `core/input/input_enums.h` order, under the SDL layout every mapped pad is
## translated into, so these are the positions rather than the printed letters.
const PAD_BUTTON_NAMES: Dictionary = {
	JOY_BUTTON_A: "A (bottom)",
	JOY_BUTTON_B: "B (right)",
	JOY_BUTTON_X: "X (left)",
	JOY_BUTTON_Y: "Y (top)",
	JOY_BUTTON_BACK: "Back",
	JOY_BUTTON_GUIDE: "Guide",
	JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "Left stick press",
	JOY_BUTTON_RIGHT_STICK: "Right stick press",
	JOY_BUTTON_LEFT_SHOULDER: "L",
	JOY_BUTTON_RIGHT_SHOULDER: "R",
	JOY_BUTTON_DPAD_UP: "D-pad up",
	JOY_BUTTON_DPAD_DOWN: "D-pad down",
	JOY_BUTTON_DPAD_LEFT: "D-pad left",
	JOY_BUTTON_DPAD_RIGHT: "D-pad right",
	JOY_BUTTON_MISC1: "Share",
	JOY_BUTTON_PADDLE1: "Paddle 1",
	JOY_BUTTON_PADDLE2: "Paddle 2",
	JOY_BUTTON_PADDLE3: "Paddle 3",
	JOY_BUTTON_PADDLE4: "Paddle 4",
	JOY_BUTTON_TOUCHPAD: "Touchpad",
}

## What a pad prints on its face buttons, per layout. Godot reports SDL
## positions, so `JOY_BUTTON_A` is the bottom button whatever is printed on it:
## Xbox prints A there and Nintendo prints B.
const PAD_LAYOUT_AUTO: StringName = &"auto"
const PAD_LAYOUT_XBOX: StringName = &"xbox"
const PAD_LAYOUT_NINTENDO: StringName = &"nintendo"
const PAD_LAYOUTS: Array[StringName] = [
	PAD_LAYOUT_AUTO, PAD_LAYOUT_XBOX, PAD_LAYOUT_NINTENDO,
]

const PAD_FACE_LABELS: Dictionary = {
	PAD_LAYOUT_XBOX: {
		JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
		JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	},
	PAD_LAYOUT_NINTENDO: {
		JOY_BUTTON_A: "B", JOY_BUTTON_B: "A", JOY_BUTTON_X: "Y", JOY_BUTTON_Y: "X",
		JOY_BUTTON_LEFT_SHOULDER: "L", JOY_BUTTON_RIGHT_SHOULDER: "R",
	},
}

const PAD_BADGES: Dictionary = {
	JOY_BUTTON_BACK: "Back",
	JOY_BUTTON_START: "Start",
	JOY_BUTTON_GUIDE: "Home",
	JOY_BUTTON_LEFT_STICK: "LS",
	JOY_BUTTON_RIGHT_STICK: "RS",
	JOY_BUTTON_DPAD_UP: "Up",
	JOY_BUTTON_DPAD_DOWN: "Down",
	JOY_BUTTON_DPAD_LEFT: "Left",
	JOY_BUTTON_DPAD_RIGHT: "Right",
}

const KEY_BADGES: Dictionary = {
	KEY_ESCAPE: "Esc",
	KEY_ENTER: "Enter",
	KEY_KP_ENTER: "Enter",
	KEY_BACKSPACE: "Bksp",
	KEY_SPACE: "Space",
	KEY_PAGEUP: "PgUp",
	KEY_PAGEDOWN: "PgDn",
	KEY_UP: "Up",
	KEY_DOWN: "Down",
	KEY_LEFT: "Left",
	KEY_RIGHT: "Right",
}

const NINTENDO_PAD_WORDS: Array[String] = ["nintendo", "switch", "joy-con", "joycon", "wii"]


## Axis name by sign, negative first.
const PAD_AXIS_NAMES: Dictionary = {
	JOY_AXIS_LEFT_X: ["Left stick left", "Left stick right"],
	JOY_AXIS_LEFT_Y: ["Left stick up", "Left stick down"],
	JOY_AXIS_RIGHT_X: ["Right stick left", "Right stick right"],
	JOY_AXIS_RIGHT_Y: ["Right stick up", "Right stick down"],
	JOY_AXIS_TRIGGER_LEFT: ["L2", "L2"],
	JOY_AXIS_TRIGGER_RIGHT: ["R2", "R2"],
}


## The stock scheme, as a fresh copy the caller may edit.
static func defaults() -> Dictionary:
	var scheme: Dictionary = {}
	for button: int in PokeButton.ALL:
		var bindings: Array = []
		for binding: Dictionary in DEFAULTS[button]:
			bindings.append(binding.duplicate())
		scheme[button] = bindings
	return scheme


## Replaces every `gen2_*` action in the [InputMap] with these bindings.
##
## Rebuilt rather than merged: a rebind that only added would leave the previous
## key working, and the player would have two keys where the screen says one.
static func install(scheme: Dictionary) -> void:
	for button: int in PokeButton.ALL:
		var name: StringName = PokeButton.action(button)
		if not InputMap.has_action(name):
			InputMap.add_action(name, DEADZONE)
		else:
			InputMap.action_set_deadzone(name, DEADZONE)
			InputMap.action_erase_events(name)
		for binding: Dictionary in scheme.get(button, []):
			var event: InputEvent = to_event(binding)
			if event != null:
				InputMap.action_add_event(name, event)
	install_ui_pad_buttons()


## Gives [constant UI_PAD_BUTTONS] and [constant UI_KEYS] to the engine's own UI
## actions. Idempotent.
static func install_ui_pad_buttons() -> void:
	for action: StringName in UI_PAD_BUTTONS:
		_add_ui_binding(action, {"kind": KIND_PAD_BUTTON, "code": int(UI_PAD_BUTTONS[action])})
	for action: StringName in UI_KEYS:
		_replace_ui_key(action, int(UI_KEYS[action]))


## Takes the engine's keys off [param action] so a legend prints a real one.
static func _replace_ui_key(action: StringName, code: int) -> void:
	if not InputMap.has_action(action):
		return
	for existing: InputEvent in InputMap.action_get_events(action):
		if existing is InputEventKey:
			InputMap.action_erase_event(action, existing)
	_add_ui_binding(action, {"kind": KIND_KEY, "code": code})


static func _add_ui_binding(action: StringName, binding: Dictionary) -> void:
	if not InputMap.has_action(action):
		return
	for existing: InputEvent in InputMap.action_get_events(action):
		if from_event(existing) == binding:
			return
	var event: InputEvent = to_event(binding)
	if event != null:
		InputMap.action_add_event(action, event)


## Builds the [InputEvent] an [InputMap] entry needs, or null for a binding this
## build does not recognise.
static func to_event(binding: Dictionary) -> InputEvent:
	var code: int = int(binding.get("code", 0))
	match StringName(binding.get("kind", &"")):
		KIND_KEY:
			var key := InputEventKey.new()
			# Physical only. A binding that also carried a keycode would match
			# twice on a US layout and disagree with itself on any other.
			key.physical_keycode = code as Key
			return key
		KIND_PAD_BUTTON:
			var pad := InputEventJoypadButton.new()
			pad.button_index = code as JoyButton
			pad.device = ALL_DEVICES
			return pad
		KIND_PAD_AXIS:
			var axis := InputEventJoypadMotion.new()
			axis.axis = code as JoyAxis
			axis.axis_value = signf(float(binding.get("sign", 1)))
			axis.device = ALL_DEVICES
			return axis
	return null


## The binding an event stands for, or an empty dictionary if it is not one a
## player could have meant. This is what the remap UI captures with: it listens
## for anything and keeps whatever answers here.
static func from_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key: InputEventKey = event
		var code: int = key.physical_keycode if key.physical_keycode != 0 else key.keycode
		if code == 0:
			return {}
		return {"kind": KIND_KEY, "code": code}
	if event is InputEventJoypadButton:
		return {"kind": KIND_PAD_BUTTON, "code": int((event as InputEventJoypadButton).button_index)}
	if event is InputEventJoypadMotion:
		var motion: InputEventJoypadMotion = event
		# A stick resting near zero reports motion constantly. Only a real push
		# past the same deadzone the action uses is a binding.
		if absf(motion.axis_value) < DEADZONE:
			return {}
		return {
			"kind": KIND_PAD_AXIS,
			"code": int(motion.axis),
			"sign": -1 if motion.axis_value < 0.0 else 1,
		}
	return {}


## The key actually printed where this physical one sits, as a keycode.
## `keyboard_get_label_from_physical` returns a key rather than a string, and
## refuses with an error on a display server that reads no keyboard layout: a
## headless run, every handheld, and the console. Asking how many layouts it has
## is the same question without the error, and it is answered by every display
## server rather than by a list of platform names, so a settings page no longer
## puts fourteen refusals into every bug report a phone or a Switch sends.
static func _labelled_key(code: int) -> int:
	if DisplayServer.keyboard_get_layout_count() <= 0:
		return code
	var labelled: int = DisplayServer.keyboard_get_label_from_physical(code)
	return labelled if labelled != 0 else code


static func device_of(binding: Dictionary) -> StringName:
	return DEVICE_KEYBOARD if StringName(binding.get("kind", &"")) == KIND_KEY \
		else DEVICE_GAMEPAD


## What to print for a binding. Keys ask the platform for the label actually
## printed on the key in that physical position, so a French player rebinding
## the d-pad reads ZQSD rather than the WASD the binding is stored as.
static func describe(binding: Dictionary) -> String:
	var code: int = int(binding.get("code", 0))
	match StringName(binding.get("kind", &"")):
		KIND_KEY:
			return OS.get_keycode_string(_labelled_key(code))
		KIND_PAD_BUTTON:
			return PAD_BUTTON_NAMES.get(code, "Pad button %d" % code)
		KIND_PAD_AXIS:
			var names: Array = PAD_AXIS_NAMES.get(code, [])
			if names.is_empty():
				return "Pad axis %d%s" % [code, "-" if int(binding.get("sign", 1)) < 0 else "+"]
			return String(names[0 if int(binding.get("sign", 1)) < 0 else 1])
	return "Unbound"


## Resolves [constant PAD_LAYOUT_AUTO] against the pad plugged in.
static func resolve_pad_layout(chosen: StringName) -> StringName:
	if PAD_FACE_LABELS.has(chosen):
		return chosen
	if OS.has_feature("switch"):
		return PAD_LAYOUT_NINTENDO
	for device: int in Input.get_connected_joypads():
		var name: String = Input.get_joy_name(device).to_lower()
		for word: String in NINTENDO_PAD_WORDS:
			if name.contains(word):
				return PAD_LAYOUT_NINTENDO
	return PAD_LAYOUT_XBOX


## What is printed on the control a binding names, in the width of a key cap.
static func badge(binding: Dictionary, layout: StringName = PAD_LAYOUT_AUTO) -> String:
	var code: int = int(binding.get("code", 0))
	match StringName(binding.get("kind", &"")):
		KIND_KEY:
			var labelled: int = _labelled_key(code)
			return KEY_BADGES.get(labelled, OS.get_keycode_string(labelled))
		KIND_PAD_BUTTON:
			var faces: Dictionary = PAD_FACE_LABELS[resolve_pad_layout(layout)]
			return faces.get(code, PAD_BADGES.get(code, "?"))
		KIND_PAD_AXIS:
			# The last word of the sentence [method describe] would have said.
			var words: PackedStringArray = describe(binding).split(" ", false)
			return "" if words.is_empty() else String(words[-1]).capitalize()
	return ""


## The badge for [param action] on [param device], read out of the [InputMap] so
## a rebind and the engine's own `ui_*` family need no second copy of either.
static func action_badge(
	action: StringName, device: StringName, layout: StringName = PAD_LAYOUT_AUTO
) -> String:
	if not InputMap.has_action(action):
		return ""
	var wanted: StringName = DEVICE_GAMEPAD if device == PokeInputDevice.GAMEPAD \
		else DEVICE_KEYBOARD
	for event: InputEvent in InputMap.action_get_events(action):
		var binding: Dictionary = from_event(event)
		if binding.is_empty() or device_of(binding) != wanted:
			continue
		var text: String = badge(binding, layout)
		if not text.is_empty():
			return text
	return ""


## Reads a scheme back out of the options file.
##
## Clamped rather than refused, the way the rest of [Gen2Options] is: one
## unreadable binding should cost that binding, and a button left with none at
## all falls back to its default rather than becoming unpressable.
static func sanitize(raw: Variant) -> Dictionary:
	var scheme: Dictionary = defaults()
	if raw is not Dictionary:
		return scheme
	var stored: Dictionary = raw
	for button: int in PokeButton.ALL:
		# JSON has no integer keys, so a scheme that has been through the
		# options file is keyed by the action name rather than the button.
		var entry: Variant = stored.get(String(PokeButton.action(button)))
		if entry is not Array:
			continue
		var bindings: Array = []
		for row: Variant in entry:
			if row is not Dictionary:
				continue
			var binding: Dictionary = _sanitize_binding(row)
			if not binding.is_empty() and not bindings.has(binding):
				bindings.append(binding)
			if bindings.size() >= MAX_BINDINGS:
				break
		# An empty list is a button the player can no longer press. Every other
		# option clamps to something usable, and so does this.
		if not bindings.is_empty():
			scheme[button] = bindings
	return scheme


## One binding, clamped to the three kinds and their ranges, or empty. Public
## because a mod declares its own defaults as plain dictionaries and they have to
## become the same shape the options file stores before anything compares them.
static func sanitize_binding(row: Dictionary) -> Dictionary:
	return _sanitize_binding(row)


static func _sanitize_binding(row: Dictionary) -> Dictionary:
	var kind := StringName(String(row.get("kind", "")))
	if not KINDS.has(kind):
		return {}
	var code: int = int(row.get("code", 0))
	match kind:
		KIND_KEY:
			if code <= 0:
				return {}
			return {"kind": kind, "code": code}
		KIND_PAD_BUTTON:
			if code < 0 or code >= JOY_BUTTON_MAX:
				return {}
			return {"kind": kind, "code": code}
		KIND_PAD_AXIS:
			if code < 0 or code >= JOY_AXIS_MAX:
				return {}
			return {"kind": kind, "code": code, "sign": -1 if int(row.get("sign", 1)) < 0 else 1}
	return {}


## The scheme as the options file stores it: keyed by action name, because JSON
## has no integer keys and a round trip would otherwise turn one into a string.
static func to_dict(scheme: Dictionary) -> Dictionary:
	var row: Dictionary = {}
	for button: int in PokeButton.ALL:
		var bindings: Array = []
		for binding: Dictionary in scheme.get(button, []):
			bindings.append(binding.duplicate())
		row[String(PokeButton.action(button))] = bindings
	return row


## Whether a scheme is the stock one, which is what lets the settings page offer
## a reset only when there is something to reset.
static func is_default(scheme: Dictionary) -> bool:
	return to_dict(scheme) == to_dict(defaults())


## Every button already bound to this, other than [param excluding]. A rebind
## uses it to say what it would take away; nothing here refuses a duplicate,
## since one key doing two things is the player's call to make.
static func conflicts(scheme: Dictionary, binding: Dictionary, excluding: int) -> Array[int]:
	var found: Array[int] = []
	for button: int in PokeButton.ALL:
		if button == excluding:
			continue
		for existing: Dictionary in scheme.get(button, []):
			if existing == binding:
				found.append(button)
				break
	return found


## The first of the eight already bound to [param binding], or
## [constant PokeButton.NONE]. What a mod's declared default is checked against:
## a mod cannot see the eight, so a default on W would never fire and nothing
## would say why.
static func button_bound_to(scheme: Dictionary, binding: Dictionary) -> int:
	var found: Array[int] = conflicts(scheme, binding, PokeButton.NONE)
	return found[0] if not found.is_empty() else PokeButton.NONE


## A mod's own actions, installed beside the eight. Same three binding kinds, same
## deadzone, same physical keycodes: an action a mod declares is bound, rebound
## and described by the code that does it for the cartridge's own buttons, and
## reaches the mod as an id rather than as an [InputEvent]. [param actions] is
## `[{name, default}]` and [param stored] the player's overrides; actions
## installed by an earlier call and absent from this one are erased, so a mod
## switched off does not leave a live action behind.
static func install_mod_actions(actions: Array, stored: Dictionary) -> void:
	var wanted: Dictionary = {}
	for action: Dictionary in actions:
		var name: StringName = StringName(action.get("name", &""))
		if String(name).is_empty():
			continue
		wanted[name] = true
		if not InputMap.has_action(name):
			InputMap.add_action(name, DEADZONE)
		else:
			InputMap.action_set_deadzone(name, DEADZONE)
			InputMap.action_erase_events(name)
		var raw: Variant = stored.get(String(name), action.get("default", []))
		for binding: Dictionary in _sanitize_bindings(raw):
			var event: InputEvent = to_event(binding)
			if event != null:
				InputMap.action_add_event(name, event)
	for name: StringName in _installed_mod_actions:
		if not wanted.has(name) and InputMap.has_action(name):
			InputMap.erase_action(name)
	_installed_mod_actions = wanted.keys()


## The mod action names currently in the [InputMap], so a later install can take
## back what an earlier one added.
static var _installed_mod_actions: Array = []


## A stored binding list, clamped the way [method sanitize] clamps the eight.
## Returns an empty list rather than a default: an action with nothing bound is
## a mod's action the player has not chosen a key for, which is a legal state and
## reads as "Unbound".
static func _sanitize_bindings(raw: Variant) -> Array:
	var bindings: Array = []
	if raw is not Array:
		return bindings
	for row: Variant in raw as Array:
		if row is not Dictionary:
			continue
		var binding: Dictionary = _sanitize_binding(row)
		if not binding.is_empty() and not bindings.has(binding):
			bindings.append(binding)
		if bindings.size() >= MAX_BINDINGS:
			break
	return bindings


## The player's mod-action overrides as the options file stores them, keyed by
## action name. Kept apart from the eight so an uninstalled mod's leftover row is
## visibly not one of the cartridge's buttons.
static func sanitize_mod_controls(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if raw is not Dictionary:
		return out
	for key: Variant in raw as Dictionary:
		var name: String = String(key)
		if not name.begins_with(MOD_ACTION_PREFIX):
			continue
		out[name] = _sanitize_bindings((raw as Dictionary)[key])
	return out


const MOD_ACTION_PREFIX: String = "mod_"


## The [InputMap] action name a mod's key is installed under. The prefix keeps a
## mod's actions out of the `gen2_*` namespace, which a mod cannot reach.
static func mod_action_name(id: StringName, key: StringName) -> StringName:
	return StringName("%s%s_%s" % [MOD_ACTION_PREFIX, id, key])
