extends GutTest


func _config() -> Dictionary:
	var glyphs := PackedByteArray()
	glyphs.resize(0x8000)
	glyphs[0xBB * 64 + 3] = 0x40 # The second row's first pixel of `A`, in the high byte's slot, is text.
	var widths := PackedByteArray()
	widths.resize(0x200)
	widths[0xBB] = 6
	var frame := PackedByteArray()
	frame.resize(0x280)
	var palette := PackedByteArray()
	palette.resize(32)
	return {"fonts": [{"glyphs": glyphs, "widths": widths}], "frame": frame, "frame_palette": palette, "arrow": frame}


func _pixel(message: Gen3FieldMessage, x: int, y: int) -> int:
	return message._pixel(x, y)


func _run(message: Gen3FieldMessage, frames: int, pressed: bool = false, requests: Array = []) -> bool:
	var finished: bool = false
	for frame: int in frames:
		finished = message.step(false, pressed, requests) or finished
	return finished


func test_text_prints_at_the_option_speed_a_press_hurries_it_and_a_prompt_waits_for_one() -> void:
	var message := Gen3FieldMessage.new(_config(), &"emerald", Gen3Palette.new())
	message.show(PackedByteArray([0xBB, 0xBB, 0xFB, 0xBB, 0xFF]), "message", 3)
	_run(message, 2)
	assert_true(message.visible, "The frame is up after the load and draw frames.")
	_run(message, 1)
	assert_eq(_pixel(message, 0, 2), 2, "The first letter lands on the first frame the printer runs.")
	assert_eq(message._x, 6)
	_run(message, 3)
	assert_eq(message._x, 6, "Mid speed holds three frames.")
	_run(message, 1)
	assert_eq(message._x, 12)
	_run(message, 10)
	assert_eq(message._state, Gen3FieldMessage.State.CLEAR)
	var requests: Array = []
	_run(message, 1, true, requests)
	assert_eq(requests, [{"kind": "sound", "name": "select"}])
	assert_eq(message._x, 0, "The press clears the box.")
	assert_true(_run(message, 10), "The text ends and reports it once.")
	assert_false(message.printing)


func test_frlg_prints_male_and_female_speakers_in_their_colours() -> void:
	var config: Dictionary = _config()
	config["fonts"] = [config["fonts"][0], config["fonts"][0], config["fonts"][0]]
	var message := Gen3FieldMessage.new(config, &"firered", Gen3Palette.new())
	message.show(PackedByteArray([0xBB, 0xFF]), "message", 1)
	assert_eq(message._colors[0], Gen3FieldMessage.TEXT_RED)
	assert_eq(message._font, Gen3FieldMessage.FONT_FEMALE)
	message.show(PackedByteArray([0xBB, 0xFF]), "message", 3)
	assert_eq(message._font, Gen3FieldMessage.FONT_NORMAL)


func test_decoded_text_encodes_back_to_its_cartridge_bytes() -> void:
	var bytes := PackedByteArray([0xBB, 0xD5, 0xA1, 0x00, 0xFE, 0xFB, 0x53, 0x54, 0xFC, 0x01, 0x04, 0xAB, 0xFF])
	var text: String = Gen3Text.decode_fixed(RomRegistry.EMERALD, bytes, 0, bytes.size())
	assert_eq(Gen3Text.encode(text), bytes)
	assert_eq(Gen3Text.encode("A<B"), PackedByteArray([0xBB, 0x85, 0xBC, 0xFF]), "A lone < is the character.")


func test_a_menu_wraps_only_past_three_rows_and_b_answers_as_the_script_expects() -> void:
	var message := Gen3FieldMessage.new(_config(), &"emerald", Gen3Palette.new())
	var menu := Gen3FieldMenu.new(message, &"emerald")
	var requests: Array = []
	var up: Array[int] = [PokeButton.UP]
	var a: Array[int] = [PokeButton.A]
	var b: Array[int] = [PokeButton.B]
	menu.open({"left": 0, "top": 0, "choices": ["A", "A", "A"], "ignore_b": false})
	assert_eq(menu.step(a, requests), Gen3FieldMenu.NOTHING, "Input waits out the delay.")
	menu.step([], requests)
	menu.step(up, requests)
	assert_eq(menu.step(a, requests), 0, "Three rows stop at the top.")
	menu.open({"left": 0, "top": 0, "choices": ["A", "A", "A", "A"], "ignore_b": true})
	menu.step([], requests)
	menu.step([], requests)
	menu.step(up, requests)
	assert_eq(menu.step(b, requests), Gen3FieldMenu.NOTHING, "ignore_b keeps the menu open.")
	assert_eq(menu.step(a, requests), 3, "Four rows wrap.")
	menu.open({"left": 21, "top": 9, "choices": ["YES", "NO"], "yes_no": true})
	for frame: int in Gen3FieldMenu.YES_NO_DELAY:
		menu.step([], requests)
	assert_eq(menu.step(a, requests), 1, "The first row is YES, which reads 1.")


func _start_menu(engine: StringName, events: Gen3EventData) -> Gen3FieldStartMenu:
	var labels: Array = ["A", "A", "A", "A", "A", "A", "A", "A", "A"]
	var message := Gen3FieldMessage.new(_config(), engine, Gen3Palette.new())
	var menu := Gen3FieldStartMenu.new(message, engine, {"labels": labels, "help": []}, func() -> Dictionary: return {})
	menu.open(events)
	return menu


func _idle(menu: Gen3FieldStartMenu, frames: int) -> void:
	for frame: int in frames:
		menu.step([], [], false)


## The list follows the flags, a hidden row keeps the cursor honest, and the callbacks leave as the cartridge's do.
func test_start_menu_rows_cursor_wrap_and_the_three_ways_out() -> void:
	var events := Gen3EventData.new(RomRegistry.EMERALD)
	var menu: Gen3FieldStartMenu = _start_menu(&"emerald", events)
	assert_eq(menu._actions, ["bag", "player", "save", "option", "exit"] as Array[String])
	var early: Array = []
	menu.step([PokeButton.DOWN], early, false)
	assert_eq(early, [], "The window builds over frames before the task reads input.")
	_idle(menu, 8)
	var requests: Array = []
	menu.step([PokeButton.UP], requests, false)
	assert_eq(requests, [{"kind": "sound", "name": "select"}])
	assert_eq(menu._actions[menu._cursor], "exit", "Menu_MoveCursor wraps.")
	assert_eq(menu.step([PokeButton.A], [], false), "", "EXIT does not fade.")
	assert_eq(menu.step([], [], false), Gen3FieldStartMenu.CLOSE)
	assert_false(menu.active)
	menu.open(events)
	_idle(menu, 9)
	assert_eq(menu.step([PokeButton.DOWN], [], false), "")
	assert_eq(menu._cursor, 0, "The closed menu remembers EXIT, and DOWN from it wraps to the top.")
	assert_eq(menu.step([PokeButton.A], [], false), Gen3FieldStartMenu.FADE)
	assert_eq(menu.step([], [], true), "", "The callback waits out the fade.")
	assert_eq(menu.step([], [], false), "bag")
	events.flag_set(int(Gen3FieldInput.FLAGS[&"emerald"]["safari"]))
	menu.open(events)
	assert_eq(menu._actions[0], Gen3FieldStartMenu.RETIRE)
