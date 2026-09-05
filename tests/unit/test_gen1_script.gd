extends GutTest

## [method Gen1WorldImporter.decode_script], the machine code behind a
## `text_asm` row read as the boxes it prints. Real rows are swept on all three
## cartridges by `tools/checks/gen1_maps.gd`; what is built here is the shapes
## that corpus does not hold, above all the ones that have to answer nothing.

const LAYOUT: Dictionary = {
	"print_text": 0x0100,
	"text_script_end": 0x0110,
	"yes_no_choice": 0x0120,
	"disable_waiting": 0x0130,
	"play_cry": 0x0140,
	"wait_for_sound": 0x0150,
	"do_not_wait": 0xCC3C,
	"current_menu_item": 0xCC26,
	"event_flags": 0xD747,
	"talk_to_trainer": 0x0160,
	"give_item": 0x0170,
	"is_item_in_bag": 0x0180,
	"bankswitch": 0x0190,
	"remove_item": 0x7F37,
	"remove_item_bank": 0x05,
	"item_to_remove": 0xFFDB,
}
const AT: int = 0x1000
const HELLO: int = 0x1800
const BYE: int = 0x1810
const UNREAD_CALL: int = 0x0200


func _rom(program: Array, strings: Dictionary = {}) -> RomFile:
	var data: PackedByteArray = PackedByteArray()
	data.resize(RomFile.BANK_SIZE)
	for offset: int in program.size():
		data[AT + offset] = int(program[offset])
	for address: int in strings:
		## `TX_START`, the literal, and `<DONE>`: what a `text_far` target holds.
		var text: PackedByteArray = Gen1Text.encode(String(strings[address]))
		data[int(address)] = Gen1Text.TEXT_START
		for offset: int in text.size():
			data[int(address) + 1 + offset] = text[offset]
		data[int(address) + 1 + text.size()] = Gen2TextStream.CHAR_DONE
	return RomFile.from_bytes(data)


func _boxes(text: String = "HI", second: String = "BYE") -> Dictionary:
	return {HELLO: text, BYE: second}


## `ld hl, nn`, low byte first.
func _load_hl(address: int) -> Array:
	return [Gen1Layout.SCRIPT_LD_HL, address & 0xFF, address >> 8]


func _call(address: int) -> Array:
	return [Gen1Layout.SCRIPT_CALL, address & 0xFF, address >> 8]


func _print(address: int) -> Array:
	return _load_hl(address) + _call(int(LAYOUT["print_text"]))


func _decode(program: Array, strings: Dictionary = {}) -> Array:
	return Gen1WorldImporter.decode_script(_rom(program, strings), LAYOUT, 0, AT)


func test_a_row_that_prints_one_box_decodes_to_it() -> void:
	var script: Array = _decode(
		_print(HELLO) + _call(int(LAYOUT["text_script_end"])), _boxes()
	)
	assert_eq(script, [{"op": "text", "text": "HI"}])


func test_a_jump_to_the_end_ends_the_row() -> void:
	var script: Array = _decode(
		_print(HELLO)
			+ [Gen1Layout.SCRIPT_JP, LAYOUT["text_script_end"] & 0xFF,
				int(LAYOUT["text_script_end"]) >> 8],
		_boxes()
	)
	assert_eq(script.size(), 1)


func test_a_call_this_decoder_does_not_read_answers_nothing() -> void:
	# Not a prefix: a row that would go on to give an item has to say nothing at
	# all rather than open with its first line and stop.
	assert_eq(_decode(_print(HELLO) + _call(UNREAD_CALL), _boxes()), [])


func test_a_cry_and_its_wait_are_walked_past() -> void:
	var script: Array = _decode(
		_call(int(LAYOUT["play_cry"])) + _call(int(LAYOUT["wait_for_sound"]))
			+ _print(HELLO) + _call(int(LAYOUT["text_script_end"])),
		_boxes()
	)
	assert_eq(script, [{"op": "text", "text": "HI"}])


## `CheckEvent`: `ld a, [wEventFlags + n]` then `bit b, a`.
func _check_event(flag: int) -> Array:
	var address: int = int(LAYOUT["event_flags"]) + flag / 8
	return [
		Gen1Layout.SCRIPT_LD_A_MEM, address & 0xFF, address >> 8,
		Gen1Layout.SCRIPT_PREFIX,
		Gen1Layout.SCRIPT_BIT_BASE + (flag % 8) * 8 + Gen1Layout.SCRIPT_OPERAND_A,
	]


func test_an_event_branch_keeps_the_flag_and_both_sides() -> void:
	## `jr nz` hops over what runs when the flag is clear, so that side is laid
	## out first and the one the branch is taken to follows it.
	var clear: Array = _print(BYE) + _call(int(LAYOUT["text_script_end"]))
	var script: Array = _decode(
		_check_event(37) + [0x20, clear.size()] + clear
			+ _print(HELLO) + _call(int(LAYOUT["text_script_end"])),
		_boxes()
	)
	assert_eq(script, [{
		"op": "branch", "flag": 37,
		"then": [{"op": "text", "text": "HI"}],
		"else": [{"op": "text", "text": "BYE"}],
	}])


func test_a_branch_side_this_decoder_cannot_read_is_marked_rather_than_dropped() -> void:
	var clear: Array = _print(BYE) + _call(int(LAYOUT["text_script_end"]))
	var script: Array = _decode(
		_check_event(37) + [0x20, clear.size()] + clear + _call(UNREAD_CALL),
		_boxes()
	)
	if not assert_eq(script.size(), 1, "the branch is the whole row"):
		return
	assert_eq((script[0] as Dictionary)["then"], [{"op": "unknown"}])
	assert_eq((script[0] as Dictionary)["else"], [{"op": "text", "text": "BYE"}])


func test_a_branch_with_neither_side_readable_answers_nothing() -> void:
	var clear: Array = _call(UNREAD_CALL)
	assert_eq(_decode(
		_check_event(37) + [0x20, clear.size()] + clear + _call(UNREAD_CALL), _boxes()
	), [])


## `YesNoChoice` writes `wCurrentMenuItem`, which is zero for YES.
func test_the_zero_side_of_a_yes_no_is_yes() -> void:
	var menu: int = int(LAYOUT["current_menu_item"])
	var yes: Array = _print(HELLO) + _call(int(LAYOUT["text_script_end"]))
	var script: Array = _decode(
		_call(int(LAYOUT["yes_no_choice"]))
			+ [Gen1Layout.SCRIPT_LD_A_MEM, menu & 0xFF, menu >> 8, Gen1Layout.SCRIPT_AND_A]
			+ [0x20, yes.size()] + yes
			+ _print(BYE) + _call(int(LAYOUT["text_script_end"])),
		_boxes()
	)
	assert_eq(script, [{
		"op": "choice",
		"no": [{"op": "text", "text": "BYE"}],
		"yes": [{"op": "text", "text": "HI"}],
	}])


func test_a_flag_write_becomes_its_own_node() -> void:
	var address: int = int(LAYOUT["event_flags"]) + 5
	var script: Array = _decode(
		_load_hl(address)
			+ [Gen1Layout.SCRIPT_PREFIX,
				Gen1Layout.SCRIPT_SET_BASE + 3 * 8 + Gen1Layout.SCRIPT_OPERAND_HL]
			+ _call(int(LAYOUT["text_script_end"]))
	)
	assert_eq(script, [{"op": "flag", "flag": 43, "set": true}])


func test_a_flag_write_outside_the_event_array_answers_nothing() -> void:
	assert_eq(_decode(
		_load_hl(0xC000)
			+ [Gen1Layout.SCRIPT_PREFIX,
				Gen1Layout.SCRIPT_SET_BASE + Gen1Layout.SCRIPT_OPERAND_HL]
			+ _call(int(LAYOUT["text_script_end"]))
	), [])


## `AfterDisplayingTextID` reads the flag once, after the row is done, so it
## belongs to the last box rather than to every box printed behind it.
func test_the_no_press_flag_lands_on_the_last_box_only() -> void:
	var script: Array = _decode(
		_call(int(LAYOUT["disable_waiting"])) + _print(HELLO) + _print(BYE)
			+ _call(int(LAYOUT["text_script_end"])),
		_boxes()
	)
	assert_eq(script, [
		{"op": "text", "text": "HI"},
		{"op": "text", "text": "BYE", "press": false},
	])


func test_a_row_that_never_ends_answers_nothing() -> void:
	# `jr -2` is its own address, which is what the budget is for.
	assert_eq(_decode([Gen1Layout.SCRIPT_JR, 0xFE]), [])


func test_a_box_that_does_not_decode_answers_nothing() -> void:
	assert_eq(_decode(_print(HELLO) + _call(int(LAYOUT["text_script_end"]))), [])


## `lb bc, ITEM, COUNT` then `call GiveItem`, with `jr nc` onto the refusal.
func _give(item: int, count: int) -> Array:
	return [Gen1Layout.SCRIPT_LD_BC, count, item] + _call(int(LAYOUT["give_item"]))


func test_a_gift_folds_both_sides_of_its_carry_onto_one_node() -> void:
	## `jr nc` hops over the receipt onto the refusal, so the taken side is the
	## bag that had no room and the one laid out first is the gift that landed.
	var received: Array = _print(HELLO) + _call(int(LAYOUT["text_script_end"]))
	var script: Array = _decode(
		_give(0xF1, 1) + [0x30, received.size()] + received
			+ _print(BYE) + _call(int(LAYOUT["text_script_end"])),
		_boxes()
	)
	assert_eq(script, [{
		"op": "give_item", "item": 0xF1, "count": 1,
		"ok": [{"op": "text", "text": "HI"}],
		"full": [{"op": "text", "text": "BYE"}],
	}])


func test_a_gift_with_no_item_loaded_answers_nothing() -> void:
	assert_eq(_decode(
		_call(int(LAYOUT["give_item"])) + _call(int(LAYOUT["text_script_end"]))
	), [])


func test_a_carry_branch_behind_a_flag_test_answers_nothing() -> void:
	# `jr nc` reads the flag a routine returned in, which `bit b, a` never wrote.
	var clear: Array = _print(BYE) + _call(int(LAYOUT["text_script_end"]))
	assert_eq(_decode(
		_check_event(37) + [0x30, clear.size()] + clear
			+ _print(HELLO) + _call(int(LAYOUT["text_script_end"])),
		_boxes()
	), [])


func test_a_zero_branch_behind_a_gift_answers_nothing() -> void:
	var full: Array = _print(BYE) + _call(int(LAYOUT["text_script_end"]))
	assert_eq(_decode(
		_give(0xF1, 1) + [0x20, full.size()] + full
			+ _print(HELLO) + _call(int(LAYOUT["text_script_end"])),
		_boxes()
	), [])


## `ld b, ITEM` then `call IsItemInBag`, which sets zero when the bag has none.
func test_an_item_test_keeps_the_item_and_both_sides() -> void:
	var missing: Array = _print(BYE) + _call(int(LAYOUT["text_script_end"]))
	var script: Array = _decode(
		[Gen1Layout.SCRIPT_LD_B, 0x45] + _call(int(LAYOUT["is_item_in_bag"]))
			+ [0x20, missing.size()] + missing
			+ _print(HELLO) + _call(int(LAYOUT["text_script_end"])),
		_boxes()
	)
	assert_eq(script, [{
		"op": "has_item", "item": 0x45,
		"then": [{"op": "text", "text": "HI"}],
		"else": [{"op": "text", "text": "BYE"}],
	}])


## `ldh [hItemToRemoveID], a` then `farcall RemoveItemByID`.
func test_a_far_call_to_remove_an_item_becomes_its_own_node() -> void:
	var script: Array = _decode(
		[Gen1Layout.SCRIPT_LD_A, 0x40, Gen1Layout.SCRIPT_LDH_MEM_A, 0xDB,
			Gen1Layout.SCRIPT_LD_B, 0x05]
			+ _load_hl(0x7F37) + _call(int(LAYOUT["bankswitch"]))
			+ _call(int(LAYOUT["text_script_end"]))
	)
	assert_eq(script, [{"op": "take_item", "item": 0x40}])


func test_a_far_call_to_anything_else_answers_nothing() -> void:
	assert_eq(_decode(
		[Gen1Layout.SCRIPT_LD_A, 0x40, Gen1Layout.SCRIPT_LDH_MEM_A, 0xDB,
			Gen1Layout.SCRIPT_LD_B, 0x05]
			+ _load_hl(0x4000) + _call(int(LAYOUT["bankswitch"]))
			+ _call(int(LAYOUT["text_script_end"]))
	), [])
