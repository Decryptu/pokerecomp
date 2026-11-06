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
