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
	"toggleable_index": 0xCC4D,
	"cur_party_species": 0xCF91,
	"cur_map_script": 0xDA39,
	"map_scripts": 0xD5F0,
	"map_script_flags": 0xD126,
	"new_tile_block": 0xD09F,
	"replace_tile_block": 0x02C0,
	"predef": 0x01A0,
	"predef_pointers": 0x0300,
	"hide_object": 0x0210,
	"show_object": 0x0220,
	"pick_up_item": 0x0230,
	"in_game_trade": 0x0240,
	"which_trade": 0xCD3D,
	"saved_coord_index": 0xCF0D,
	"cur_opponent": 0xD059,
	"cur_enemy_level": 0xD127,
	"is_in_battle": 0xD057,
	"battle_result": 0xCF0B,
	"status_flags_4": 0xD72E,
	"wait_for_button": 0x01B0,
	"auto_textbox_on": 0x01C0,
	"auto_textbox_off": 0x01D0,
	"has_enough_money": 0x01E0,
	"display_text_box": 0x01F0,
	"text_box_id": 0xD125,
	"money_hram": 0xFF9F,
	"player_money": 0xD347,
	"sub_bcd": 0x0250,
	"has_enough_coins": 0x0260,
	"player_coins": 0xD5A4,
	"add_bcd": 0x0270,
	"coin_box": 0x0280,
	"print_predef_text": 0x0290,
	"display_text_id": 0x02A0,
	"count_set_bits": 0x02B0,
	"text_predefs": 0x0400,
	"text_id_hram": 0xFF8C,
	"joy_held": 0xFFB4,
	"auto_text_box_control": 0xCF0C,
	"facing_direction": 0xC109,
	"num_set_bits": 0xD11E,
	"cur_map_tileset": 0xD367,
	"tile_map": 0xC3A0,
	"player_y": 0xD361,
	"player_x": 0xD362,
	"update_sprites": 0x02D0,
	"play_sound": 0x02E0,
	"play_sound_wait": 0x02F0,
	"start_simulating_joypad": 0x0320,
	"simulated_joypad_index": 0xCD38,
	"simulated_joypad_end": 0xCCD3,
	"call_function_in_table": 0x0330,
	"execute_map_script": 0x0340,
	"player_coords_in_array": 0x0350,
	"delay_3": 0x0360,
	"delay_frames": 0x0370,
	"play_default_music": 0x0380,
	"check_map_trainers": 0x0390,
	"start_trainer_battle": 0x03A0,
	"end_trainer_battle": 0x03B0,
	"load_gym_names": 0x03C0,
	"joy_ignore": 0xCD6B,
	"update_sprites_enabled": 0xCFCB,
	"obtained_badges": 0xD356,
	"sprite_state_data": 0xC100,
	"status_flags_6": 0xD732,
	"status_flags_5": 0xD730,
	"sprite_facing_hram": 0xFF8D,
	"player_moving_direction": 0xD528,
	"joy_pressed": 0xFFB3,
	"new_sound_id": 0xC0EE,
	"set_sprite_facing": 0x03D0,
	"set_sprite_facing_delay": 0x03E0,
	"sprite_stay": 0x03F0,
	"move_sprite": 0x0410,
	"decode_rle": 0x0420,
	"play_music": 0x0430,
	"last_map": 0xD365,
	"check_boulder_coords": 0x0440,
	"trainer_no": 0xD05D,
	"rival_starter": 0xD715,
}
## `PredefPointers`' rows, by the id `predef` leaves in a.
const PREDEFS: Dictionary = {
	1: 0x0210, 2: 0x0220, 3: 0x0230, 4: 0x0240, 5: 0x0250, 6: 0x0270,
	7: 0x02C0,
}
const AT: int = 0x1000
const HELLO: int = 0x1800
const BYE: int = 0x1810
const UNREAD_CALL: int = 0x0200
## Where a `MoveSprite` list and a `DecodeRLEList` one are laid down.
const MOVEMENT_LIST: int = 0x1900
## `call z, nn`, one of [constant Gen1Layout.SCRIPT_CONDITIONAL_CALLS]' four.
const CALL_Z: int = 0xCC
## A `<Map>_ScriptPointers` table, the `w<Map>CurScript` byte it dispatches on
## and one state body behind it.
const TABLE: int = 0x1900
const STATE: int = 0x1910
const MAP_SCRIPT_BYTE: int = 4
## `PewterCityPlayerLeavingEastCoords`' shape: `db y, x` rows under a $FF.
const COORDS: int = 0x1930
## `ret nc`, which a coordinate list is refused with, and `call nz`, which a map
## load gate calls its own body through.
const RET_NC: int = 0xD0
const RET_NZ: int = 0xC0
const CALL_NZ: int = 0xC4


func _rom(program: Array, strings: Dictionary = {}, raw: Dictionary = {}) -> RomFile:
	var data: PackedByteArray = PackedByteArray()
	data.resize(RomFile.BANK_SIZE)
	for offset: int in program.size():
		data[AT + offset] = int(program[offset])
	for address: int in raw:
		data[address] = int(raw[address])
	for address: int in strings:
		## `TX_START`, the literal, and `<DONE>`: what a `text_far` target holds.
		var text: PackedByteArray = Gen1Text.encode(String(strings[address]))
		data[int(address)] = Gen1Text.TEXT_START
		for offset: int in text.size():
			data[int(address) + 1 + offset] = text[offset]
		data[int(address) + 1 + text.size()] = Gen2TextStream.CHAR_DONE
	for id: int in PREDEFS:
		var row: int = int(LAYOUT["predef_pointers"]) + id * Gen1Layout.PREDEF_SIZE
		data[row + 1] = int(PREDEFS[id]) & 0xFF
		data[row + 2] = int(PREDEFS[id]) >> 8
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


func _decode(
	program: Array, strings: Dictionary = {}, raw: Dictionary = {}
) -> Array:
	return Gen1WorldImporter.decode_script(_rom(program, strings, raw), LAYOUT, 0, AT)


func _load_a(address: int) -> Array:
	return [Gen1Layout.SCRIPT_LD_A_MEM, address & 0xFF, address >> 8]


func _store_a(address: int) -> Array:
	return [Gen1Layout.SCRIPT_LD_MEM_A, address & 0xFF, address >> 8]


## `ld a, n` / `ldh [n], a`, which is how a row names a sprite and its facing.
func _store_hram(address: int, value: int) -> Array:
	return [
		Gen1Layout.SCRIPT_LD_A, value, Gen1Layout.SCRIPT_LDH_MEM_A, address & 0xFF,
	]


## `ld hl, <table>` / `ld a, [w<Map>CurScript]` / `jp CallFunctionInTable`.
func _dispatch() -> Array:
	return _load_hl(TABLE) \
		+ _load_a(int(LAYOUT["map_scripts"]) + MAP_SCRIPT_BYTE) \
		+ [Gen1Layout.SCRIPT_JP, LAYOUT["call_function_in_table"] & 0xFF,
			int(LAYOUT["call_function_in_table"]) >> 8]


func test_the_dispatch_names_the_table_and_the_byte_it_reads() -> void:
	assert_eq(_decode(_dispatch()), [
		{"op": "map_script_table", "table": TABLE, "byte": MAP_SCRIPT_BYTE},
	])


func test_a_store_to_a_map_script_byte_names_the_state_it_leaves() -> void:
	var script: Array = _decode(
		[Gen1Layout.SCRIPT_LD_A, 3] + _store_a(int(LAYOUT["map_scripts"]) + MAP_SCRIPT_BYTE)
			+ [Gen1Layout.SCRIPT_RET]
	)
	assert_eq(script, [{"op": "set_map_script", "byte": MAP_SCRIPT_BYTE, "value": 3}])


func test_a_map_script_store_the_walk_cannot_value_answers_nothing() -> void:
	assert_eq(
		_decode(_store_a(int(LAYOUT["map_scripts"])) + [Gen1Layout.SCRIPT_RET]), []
	)


## `wCurrentMapScriptFlags` is clear on every frame but the map's own load, so
## the gate in front of a per-frame script tests false and the body it would
## have called is not read at all.
func test_the_map_load_gate_is_walked_past() -> void:
	var gate: Array = _load_hl(int(LAYOUT["map_script_flags"])) \
		+ [Gen1Layout.SCRIPT_PREFIX, Gen1Layout.SCRIPT_BIT_BASE + Gen1Layout.SCRIPT_OPERAND_HL,
			Gen1Layout.SCRIPT_PREFIX,
			Gen1Layout.SCRIPT_RES_BASE + Gen1Layout.SCRIPT_OPERAND_HL,
			CALL_NZ, UNREAD_CALL & 0xFF, UNREAD_CALL >> 8]
	var script: Array = _decode(
		gate + _print(HELLO) + _call(int(LAYOUT["text_script_end"])), _boxes()
	)
	assert_eq(script, [{"op": "text", "text": "HI"}])


func test_a_coordinate_list_becomes_the_cells_it_holds() -> void:
	var program: Array = _load_hl(COORDS) + _call(int(LAYOUT["player_coords_in_array"])) \
		+ [RET_NC] + _print(HELLO) + _call(int(LAYOUT["text_script_end"]))
	var script: Array = Gen1WorldImporter.decode_script(
		_rom(program, _boxes(), {
			COORDS: 7, COORDS + 1: 9, COORDS + 2: 8, COORDS + 3: 10,
			COORDS + 4: Gen1Layout.MAP_COORD_END,
		}),
		LAYOUT, 0, AT
	)
	assert_eq(script, [{
		"op": "player_in_array",
		"cells": [{"y": 7, "x": 9}, {"y": 8, "x": 10}],
		"then": [{"op": "text", "text": "HI"}], "else": [],
	}])


func test_a_store_to_a_sprite_facing_byte_turns_that_object() -> void:
	var facing_byte: int = int(LAYOUT["sprite_state_data"]) \
		+ 2 * Gen1Layout.SPRITE_SLOT_SIZE + Gen1Layout.SPRITE_FACING_AT
	var script: Array = _decode(
		[Gen1Layout.SCRIPT_LD_A, Gen1Layout.FACING_LEFT] + _store_a(facing_byte)
			+ [Gen1Layout.SCRIPT_RET]
	)
	assert_eq(script, [
		{"op": "object_facing", "object": 1, "facing": Gen1Layout.FACING_LEFT},
	])


## `hSpriteIndex` shares `hTextID`'s byte, so the routine behind the store is
## what says an object was meant rather than a text row.
func test_the_facing_routine_turns_the_sprite_its_hram_byte_names() -> void:
	var script: Array = _decode(
		_store_hram(int(LAYOUT["text_id_hram"]), 2)
			+ _store_hram(int(LAYOUT["sprite_facing_hram"]), Gen1Layout.FACING_LEFT)
			+ [Gen1Layout.SCRIPT_CALL, 0xE0, 0x03, Gen1Layout.SCRIPT_RET]
	)
	assert_eq(script, [
		{"op": "object_facing", "object": 1, "facing": Gen1Layout.FACING_LEFT},
	])


func test_a_sprite_walk_carries_its_own_movement_list() -> void:
	var script: Array = _decode(
		_store_hram(int(LAYOUT["text_id_hram"]), 3)
			+ [Gen1Layout.SCRIPT_LD_DE, MOVEMENT_LIST & 0xFF, MOVEMENT_LIST >> 8]
			+ [Gen1Layout.SCRIPT_CALL, 0x10, 0x04, Gen1Layout.SCRIPT_RET],
		{}, {
			MOVEMENT_LIST: 0xC0, MOVEMENT_LIST + 1: 0x40,
			MOVEMENT_LIST + 2: Gen1Layout.NPC_MOVEMENT_END,
		}
	)
	assert_eq(script, [{"op": "object_move", "object": 2, "moves": [3, 1]}])


## `FindPathToPlayer` writes its answer into WRAM, which no list in the bank
## stands at, so Oak's own walk says nothing here.
func test_a_sprite_walk_out_of_wram_answers_nothing() -> void:
	assert_eq(_decode(
		_store_hram(int(LAYOUT["text_id_hram"]), 3)
			+ [Gen1Layout.SCRIPT_LD_DE, 0x97, 0xCC]
			+ [Gen1Layout.SCRIPT_CALL, 0x10, 0x04, Gen1Layout.SCRIPT_RET]
	), [])


## `DecodeRLEList` unrolls its pairs into the buffer, and `GetSimulatedInput`
## spends them back to front.
func test_a_decoded_walk_spends_its_buffer_back_to_front() -> void:
	var script: Array = _decode(
		_load_hl(int(LAYOUT["simulated_joypad_end"]))
			+ [Gen1Layout.SCRIPT_LD_DE, MOVEMENT_LIST & 0xFF, MOVEMENT_LIST >> 8]
			+ [Gen1Layout.SCRIPT_CALL, 0x20, 0x04, Gen1Layout.SCRIPT_DEC_A]
			+ _store_a(int(LAYOUT["simulated_joypad_index"]))
			+ [Gen1Layout.SCRIPT_CALL, 0x20, 0x03, Gen1Layout.SCRIPT_RET],
		{}, {
			MOVEMENT_LIST: 0x20, MOVEMENT_LIST + 1: 1, MOVEMENT_LIST + 2: 0x40,
			MOVEMENT_LIST + 3: 2, MOVEMENT_LIST + 4: Gen1Layout.RLE_END,
		}
	)
	assert_eq(script, [{"op": "walk", "moves": [
		{"direction": 1, "steps": 2}, {"direction": 2, "steps": 1},
	]}])


## A row spending more entries than it wrote reads whatever the buffer held, so
## the walk is refused rather than invented.
func test_a_walk_longer_than_its_buffer_answers_nothing() -> void:
	assert_eq(_decode(
		[Gen1Layout.SCRIPT_LD_A, 0x40] + _store_a(int(LAYOUT["simulated_joypad_end"]))
			+ [Gen1Layout.SCRIPT_LD_A, 3]
			+ _store_a(int(LAYOUT["simulated_joypad_index"]))
			+ [Gen1Layout.SCRIPT_CALL, 0x20, 0x03, Gen1Layout.SCRIPT_RET]
	), [])


## `bit BIT_SCRIPTED_NPC_MOVEMENT, a` / `ret nz`, which is how a state holds
## still while the walk the state before it started is drawn.
func test_a_scripted_movement_bit_becomes_a_movement_branch() -> void:
	var script: Array = _decode(
		_load_a(int(LAYOUT["status_flags_5"]))
			+ [Gen1Layout.SCRIPT_PREFIX, Gen1Layout.SCRIPT_BIT_BASE | 0x07]
			+ [RET_NZ] + _print(HELLO) + [Gen1Layout.SCRIPT_RET],
		{HELLO: "HI"}
	)
	assert_eq(script, [{
		"op": "movement_running", "who": Gen1Layout.MOVEMENT_TEST_OBJECT,
		"then": [], "else": [{"op": "text", "text": "HI"}],
	}], "the box opens on the side that is no longer walking")


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


## `CheckEitherEventSet`: one `ld a, [wEventFlags + n]` and an `and` whose mask
## names both flags, so the byte answers for the pair at once.
func test_either_of_two_flags_in_one_byte_is_one_branch() -> void:
	var address: int = int(LAYOUT["event_flags"]) + 4
	var clear: Array = _print(BYE) + _call(int(LAYOUT["text_script_end"]))
	var script: Array = _decode(
		[Gen1Layout.SCRIPT_LD_A_MEM, address & 0xFF, address >> 8,
			Gen1Layout.SCRIPT_AND_N, 0b01000010]
			+ [0x20, clear.size()] + clear
			+ _print(HELLO) + _call(int(LAYOUT["text_script_end"])),
		_boxes()
	)
	assert_eq(script, [{
		"op": "branch", "flag": 33, "either": [38],
		"then": [{"op": "text", "text": "HI"}],
		"else": [{"op": "text", "text": "BYE"}],
	}])


## A `call` to a routine the layout does not name is the map's own:
## `MtMoonB2FReceivedFossilText` is an `ld hl` and a tail `jp PrintText`.
func test_a_call_to_the_maps_own_routine_is_walked_and_returned_from() -> void:
	var routine: int = AT + 0x40
	var program: Array = _call(routine) + _print(BYE) \
		+ _call(int(LAYOUT["text_script_end"]))
	while program.size() < 0x40:
		program.append(0)
	program.append_array(
		_load_hl(HELLO) + [Gen1Layout.SCRIPT_JP,
			LAYOUT["print_text"] & 0xFF, int(LAYOUT["print_text"]) >> 8]
	)
	assert_eq(_decode(program, _boxes()), [
		{"op": "text", "text": "HI"}, {"op": "text", "text": "BYE"},
	])


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


## `callfar` is the same three the other way about, and the routine it names is
## walked in the bank `b` carries. Yellow keeps 22 rows behind one.
func test_a_far_call_to_a_routine_is_walked_and_returned_from() -> void:
	var routine: int = AT + 0x40
	var program: Array = _load_hl(routine) + [Gen1Layout.SCRIPT_LD_B, 0]
	program += _call(int(LAYOUT["bankswitch"])) + _print(BYE) \
		+ _call(int(LAYOUT["text_script_end"]))
	while program.size() < 0x40:
		program.append(0)
	program.append_array(_print(HELLO) + [Gen1Layout.SCRIPT_RET])
	assert_eq(_decode(program, _boxes()), [
		{"op": "text", "text": "HI"}, {"op": "text", "text": "BYE"},
	])


func test_a_far_call_to_machine_code_this_decoder_cannot_read_answers_nothing() -> void:
	assert_eq(_decode(
		[Gen1Layout.SCRIPT_LD_A, 0x40, Gen1Layout.SCRIPT_LDH_MEM_A, 0xDB,
			Gen1Layout.SCRIPT_LD_B, 0x05]
			+ _load_hl(UNREAD_CALL) + _call(int(LAYOUT["bankswitch"]))
			+ _call(int(LAYOUT["text_script_end"]))
	), [])


## `ld a, id` and `call Predef`, the whole of the macro.
func _predef(id: int) -> Array:
	return [Gen1Layout.SCRIPT_LD_A, id] + _call(int(LAYOUT["predef"]))


## `ld a, TOGGLE_X` and `ld [wToggleableObjectIndex], a` in front of one.
func _toggle(index: int, id: int) -> Array:
	return [Gen1Layout.SCRIPT_LD_A, index, Gen1Layout.SCRIPT_LD_MEM_A,
		int(LAYOUT["toggleable_index"]) & 0xFF,
		int(LAYOUT["toggleable_index"]) >> 8] + _predef(id)


func test_a_predef_hiding_an_object_keeps_its_global_index() -> void:
	assert_eq(_decode(_toggle(7, 1) + _call(int(LAYOUT["text_script_end"]))),
		[{"op": "toggle_object", "index": 7, "hidden": true}])


func test_a_predef_showing_an_object_reads_the_other_way() -> void:
	assert_eq(_decode(_toggle(7, 2) + _call(int(LAYOUT["text_script_end"]))),
		[{"op": "toggle_object", "index": 7, "hidden": false}])


## `wToggleableObjectIndex` is what the routine reads, so a row that wrote no
## index is one this decoder cannot say which object goes off the map.
func test_a_predef_with_no_index_written_answers_nothing() -> void:
	assert_eq(_decode(_predef(1) + _call(int(LAYOUT["text_script_end"]))), [])


## `ld a, block`, `ld [wNewTileBlockID], a` and `lb bc, y, x` in front of a
## `predef ReplaceTileBlock`, which is a map's own load callback whole.
func _replace_block(block: int, y: int, x: int) -> Array:
	return [
		Gen1Layout.SCRIPT_LD_A, block, Gen1Layout.SCRIPT_LD_MEM_A,
		int(LAYOUT["new_tile_block"]) & 0xFF, int(LAYOUT["new_tile_block"]) >> 8,
		Gen1Layout.SCRIPT_LD_BC, x, y,
	] + _predef(7)


func test_a_replace_tile_block_predef_becomes_a_block_node() -> void:
	assert_eq(_decode(_replace_block(0x54, 2, 3) + [Gen1Layout.SCRIPT_RET]),
		[{"op": "replace_block", "block": 0x54, "y": 2, "x": 3}])


## `wNewTileBlockID` is the whole of what the routine writes, so a callback that
## named no block says nothing rather than writing whatever stood in `a`.
func test_a_block_predef_with_no_block_written_answers_nothing() -> void:
	assert_eq(_decode(
		[Gen1Layout.SCRIPT_LD_BC, 3, 2] + _predef(7) + [Gen1Layout.SCRIPT_RET]
	), [])


## `CheckEventAfterBranchReuseA` reads the event byte the block write left in
## `a`, which only the `push af` and `pop af` around the write keep.
func test_push_and_pop_af_carry_the_event_byte_across_a_block_write() -> void:
	var locked: Array = [Gen1Layout.SCRIPT_PUSH_AF] \
		+ _replace_block(0x54, 2, 2) + [Gen1Layout.SCRIPT_POP_AF]
	var script: Array = _decode(
		_check_event(0) + [0x20, locked.size()] + locked
			+ [
				Gen1Layout.SCRIPT_PREFIX,
				Gen1Layout.SCRIPT_BIT_BASE + 8 + Gen1Layout.SCRIPT_OPERAND_A,
				0xC0,
			] + _replace_block(0x54, 5, 2) + [Gen1Layout.SCRIPT_RET]
	)
	assert_eq(script, [{
		"op": "branch", "flag": 0,
		"then": [{
			"op": "branch", "flag": 1,
			"then": [],
			"else": [{"op": "replace_block", "block": 0x54, "y": 5, "x": 2}],
		}],
		"else": [
			{"op": "replace_block", "block": 0x54, "y": 2, "x": 2},
			{
				"op": "branch", "flag": 1,
				"then": [],
				"else": [{"op": "replace_block", "block": 0x54, "y": 5, "x": 2}],
			},
		],
	}])


## `PickUpItemText` whole: the object's own item is the world's to supply.
func test_the_pick_up_predef_becomes_its_own_node() -> void:
	assert_eq(_decode(_predef(3) + _call(int(LAYOUT["text_script_end"]))),
		[{"op": "pick_up_item"}])


func test_any_other_predef_answers_nothing() -> void:
	assert_eq(_decode(_predef(0) + _call(int(LAYOUT["text_script_end"]))), [])


## `ld a, TRADE_FOR_x`, `ld [wWhichTrade], a` and `predef DoInGameTradeDialogue`.
func _trade(row: int) -> Array:
	return [Gen1Layout.SCRIPT_LD_A, row, Gen1Layout.SCRIPT_LD_MEM_A,
		int(LAYOUT["which_trade"]) & 0xFF,
		int(LAYOUT["which_trade"]) >> 8] + _predef(4)


func test_a_trade_predef_keeps_the_row_it_was_handed() -> void:
	assert_eq(_decode(_trade(6) + _call(int(LAYOUT["text_script_end"]))),
		[{"op": "scratch", "address": 0xCD3D, "value": 6}, {"op": "trade", "trade_id": 6}])


func test_a_trade_predef_with_no_row_written_answers_nothing() -> void:
	assert_eq(_decode(_predef(4) + _call(int(LAYOUT["text_script_end"]))), [])


## `Route11Gate2FYoungsterText` opens `xor a ; TRADE_FOR_TERRY`.
func test_xor_a_writes_the_row_a_load_of_zero_would() -> void:
	assert_eq(_decode(
		[Gen1Layout.SCRIPT_XOR_A, Gen1Layout.SCRIPT_LD_MEM_A,
			int(LAYOUT["which_trade"]) & 0xFF, int(LAYOUT["which_trade"]) >> 8]
			+ _predef(4) + _call(int(LAYOUT["text_script_end"]))
	), [{"op": "scratch", "address": 0xCD3D, "value": 0}, {"op": "trade", "trade_id": 0}])


## `CheckEvent flag, 1`: one `rrca` per bit up to the one asked about, which a
## `jr c` behind it reads out of carry rather than out of Z.
func _check_event_carry(flag: int) -> Array:
	@warning_ignore("integer_division")
	var byte: int = int(LAYOUT["event_flags"]) + flag / 8
	var out: Array = [Gen1Layout.SCRIPT_LD_A_MEM, byte & 0xFF, byte >> 8]
	for _rotation: int in (flag % 8) + 1:
		out.append(Gen1Layout.SCRIPT_RRCA)
	return out


func test_a_rotated_event_check_reads_the_flag_out_of_carry() -> void:
	## `jr c` hops over what runs when the flag is clear, the way `jr nz` does.
	var clear: Array = _print(BYE) + _call(int(LAYOUT["text_script_end"]))
	var script: Array = _decode(
		_check_event_carry(11) + [0x38, clear.size()] + clear
			+ _print(HELLO) + _call(int(LAYOUT["text_script_end"])),
		_boxes()
	)
	assert_eq(script, [{"op": "branch", "flag": 11,
		"then": [{"op": "text", "text": "HI"}],
		"else": [{"op": "text", "text": "BYE"}]}])


## Nothing but the rotation raised carry, so a `jr nz` behind the run is reading
## a Z the rotation did not write.
func test_a_zero_branch_behind_a_rotation_answers_nothing() -> void:
	var clear: Array = _print(BYE) + _call(int(LAYOUT["text_script_end"]))
	assert_eq(_decode(
		_check_event_carry(3) + [0x20, clear.size()] + clear
			+ _print(HELLO) + _call(int(LAYOUT["text_script_end"])), _boxes()
	), [])


## `ld hl, wStatusFlags4` and `set BIT_GOT_LAPRAS, [hl]`, the one saved byte
## outside `wEventFlags` a row writes.
func test_an_engine_flag_is_written_as_its_own_kind() -> void:
	assert_eq(_decode(
		_load_hl(int(LAYOUT["status_flags_4"]))
			+ [Gen1Layout.SCRIPT_PREFIX, Gen1Layout.SCRIPT_SET_BASE + 0x06]
			+ _call(int(LAYOUT["text_script_end"]))
	), [{"op": "flag", "flag": Gen1Layout.ENGINE_FLAG_FIRST, "set": true,
		"engine": true}])


## `call z, WaitForTextScrollButtonPress`: the routine spends nothing here, so
## both sides of it print the same boxes.
func test_a_conditional_call_to_a_silent_routine_is_walked_past() -> void:
	assert_eq(_decode(
		[CALL_Z, int(LAYOUT["wait_for_button"]) & 0xFF,
			int(LAYOUT["wait_for_button"]) >> 8]
			+ _print(HELLO) + _call(int(LAYOUT["text_script_end"])), _boxes()
	), [{"op": "text", "text": "HI"}])


func test_a_conditional_call_to_anything_else_answers_nothing() -> void:
	assert_eq(_decode(
		[CALL_Z, int(LAYOUT["print_text"]) & 0xFF,
			int(LAYOUT["print_text"]) >> 8]
			+ _call(int(LAYOUT["text_script_end"]))
	), [])


## `ldh [hMoney + n], a`, most significant byte first.
func _money(price: Array) -> Array:
	var out: Array = []
	for index: int in price.size():
		out += [Gen1Layout.SCRIPT_LD_A, int(price[index]),
			Gen1Layout.SCRIPT_LDH_MEM_A, (int(LAYOUT["money_hram"]) + index) & 0xFF]
	return out


## `HasEnoughMoney` sets carry when the player is short, so the `jr nc` behind it
## hops to the sale and the price is the one the row wrote into `hMoney`.
func test_a_money_test_keeps_the_price_and_both_sides() -> void:
	var short: Array = _print(BYE) + _call(int(LAYOUT["text_script_end"]))
	var script: Array = _decode(
		_money([0x00, 0x05, 0x00]) + _call(int(LAYOUT["has_enough_money"]))
			+ [0x30, short.size()] + short
			+ _print(HELLO) + _call(int(LAYOUT["text_script_end"])),
		_boxes()
	)
	assert_eq(script, [{
		"op": "has_money", "price": 500,
		"then": [{"op": "text", "text": "HI"}],
		"else": [{"op": "text", "text": "BYE"}],
	}])


func test_a_money_test_with_no_price_written_answers_nothing() -> void:
	assert_eq(_decode(
		_money([0x00, 0x05]) + _call(int(LAYOUT["has_enough_money"]))
			+ _call(int(LAYOUT["text_script_end"]))
	), [])


## `wPriceTemp` stands at `wWhichTrade`'s own address, so the predef behind the
## three stores is what says a price was meant.
func _spend(price: Array) -> Array:
	var at: int = int(LAYOUT["which_trade"])
	var out: Array = []
	for index: int in price.size():
		out += [Gen1Layout.SCRIPT_LD_A, int(price[index]), Gen1Layout.SCRIPT_LD_MEM_A,
			(at + index) & 0xFF, (at + index) >> 8]
	var money: int = int(LAYOUT["player_money"]) + Gen1Layout.MONEY_BYTES - 1
	return out + _load_hl(at + Gen1Layout.MONEY_BYTES - 1) \
		+ [Gen1Layout.SCRIPT_LD_DE, money & 0xFF, money >> 8,
			Gen1Layout.SCRIPT_LD_C, Gen1Layout.MONEY_BYTES] \
		+ _predef(5)


func test_the_subtraction_predef_becomes_the_price_it_takes() -> void:
	assert_eq(
		_decode(_spend([0x00, 0x05, 0x00]) + _call(int(LAYOUT["text_script_end"]))),
		[{"op": "scratch", "address": 0xCD3D, "value": 0}, {"op": "spend_money", "amount": 500}]
	)


## `ldh [hCoins + n], a`, which is `hMoney`'s last two bytes.
func _coins(count: Array) -> Array:
	var out: Array = []
	var at: int = int(LAYOUT["money_hram"]) + Gen1Layout.COIN_BUFFER_AT
	for index: int in count.size():
		out += [Gen1Layout.SCRIPT_LD_A, int(count[index]),
			Gen1Layout.SCRIPT_LDH_MEM_A, (at + index) & 0xFF]
	return out


## The two flags `HasEnoughCoins` leaves: carry when the player is short, which
## `jr nc` at $30 reads, and zero when the counts are equal, which `jr z` at $28
## reads. `GameCornerGentlemanText` is the one row of the corpus that takes the
## second, so both readings are built here.
func test_a_coin_test_reads_either_flag() -> void:
	for row: Array in [[0x30, "at_least"], [0x28, "exactly"]]:
		var refused: Array = _print(BYE) + _call(int(LAYOUT["text_script_end"]))
		var script: Array = _decode(
			_coins([0x99, 0x90]) + _call(int(LAYOUT["has_enough_coins"]))
				+ [int(row[0]), refused.size()] + refused
				+ _print(HELLO) + _call(int(LAYOUT["text_script_end"])),
			_boxes()
		)
		assert_eq(script, [{
			"op": "has_coins", "coins": 9990, "test": String(row[1]),
			"then": [{"op": "text", "text": "HI"}],
			"else": [{"op": "text", "text": "BYE"}],
		}])


func test_a_coin_test_with_one_byte_written_answers_nothing() -> void:
	assert_eq(_decode(
		_coins([0x99]) + _call(int(LAYOUT["has_enough_coins"]))
			+ _call(int(LAYOUT["text_script_end"]))
	), [])


## `AddBCDPredef` with `wPlayerCoins + 1` in de and two in c. The Day-Care sums
## its own price with the same predef over another buffer, which reads as
## nothing rather than as coins.
func _add_coins(count: Array, at: int) -> Array:
	var coins: int = int(LAYOUT["money_hram"]) + Gen1Layout.COIN_BUFFER_AT
	return _coins(count) + _load_hl(coins + Gen1Layout.COIN_BYTES - 1) \
		+ [Gen1Layout.SCRIPT_LD_DE, at & 0xFF, at >> 8,
			Gen1Layout.SCRIPT_LD_C, Gen1Layout.COIN_BYTES] \
		+ _predef(6)


func test_the_addition_predef_becomes_the_coins_it_gives() -> void:
	var at: int = int(LAYOUT["player_coins"]) + Gen1Layout.COIN_BYTES - 1
	assert_eq(
		_decode(_add_coins([0x00, 0x50], at) + _call(int(LAYOUT["text_script_end"]))),
		[{"op": "add_coins", "amount": 50}]
	)


func test_an_addition_onto_another_buffer_answers_nothing() -> void:
	assert_eq(_decode(
		_add_coins([0x00, 0x50], int(LAYOUT["player_money"]))
			+ _call(int(LAYOUT["text_script_end"]))
	), [])


## `GameCornerDrawCoinBox`, which the layout names by its full ROM offset
## because the same address in another bank is another routine.
func test_the_coin_box_call_becomes_its_own_node() -> void:
	assert_eq(
		_decode(_call(int(LAYOUT["coin_box"])) + _call(int(LAYOUT["text_script_end"]))),
		[{"op": "coin_box"}]
	)


## `ld a, MONEY_BOX`, `ld [wTextBoxID], a` and `call DisplayTextBoxID`.
func _text_box(id: int) -> Array:
	return [Gen1Layout.SCRIPT_LD_A, id, Gen1Layout.SCRIPT_LD_MEM_A,
		int(LAYOUT["text_box_id"]) & 0xFF, int(LAYOUT["text_box_id"]) >> 8] \
		+ _call(int(LAYOUT["display_text_box"]))


func test_the_money_box_becomes_its_own_node() -> void:
	assert_eq(
		_decode(_text_box(Gen1Layout.MONEY_BOX_ID)
			+ _call(int(LAYOUT["text_script_end"]))),
		[{"op": "money_box"}]
	)


## Every other id names a menu this port hands nothing to.
func test_any_other_text_box_answers_nothing() -> void:
	assert_eq(
		_decode(_text_box(Gen1Layout.MONEY_BOX_ID + 1)
			+ _call(int(LAYOUT["text_script_end"]))),
		[]
	)


## `jp nz` is three bytes where the conditional `jr`s are two. Read as two, its
## fall-through lands inside its own operand and the row says nothing.
func test_a_long_conditional_jump_is_three_bytes() -> void:
	var clear: Array = _print(BYE) + _call(int(LAYOUT["text_script_end"]))
	var set_side: Array = _print(HELLO) + _call(int(LAYOUT["text_script_end"]))
	var head: Array = _check_event(37)
	var target: int = AT + head.size() + Gen1Layout.SCRIPT_LONG_SIZE + clear.size()
	assert_eq(_decode(
		head + [0xC2, target & 0xFF, target >> 8] + clear + set_side, _boxes()
	), [{
		"op": "branch", "flag": 37,
		"then": [{"op": "text", "text": "HI"}],
		"else": [{"op": "text", "text": "BYE"}],
	}])


## `and a` raises Z only when `a` is zero, so the side a `jp nz` does not take
## knows the register: the salesman writes `hMoney` out of it.
func test_the_zero_side_of_and_a_knows_the_register() -> void:
	var no: Array = _print(BYE) + _call(int(LAYOUT["text_script_end"]))
	var yes: Array = [Gen1Layout.SCRIPT_LDH_MEM_A, int(LAYOUT["money_hram"]) & 0xFF,
		Gen1Layout.SCRIPT_LDH_MEM_A, (int(LAYOUT["money_hram"]) + 2) & 0xFF,
		Gen1Layout.SCRIPT_LD_A, 0x05,
		Gen1Layout.SCRIPT_LDH_MEM_A, (int(LAYOUT["money_hram"]) + 1) & 0xFF]
	yes += _call(int(LAYOUT["has_enough_money"])) + [0x30, no.size()] + no \
		+ _print(HELLO) + _call(int(LAYOUT["text_script_end"]))
	var script: Array = _decode(
		_call(int(LAYOUT["yes_no_choice"]))
			+ [Gen1Layout.SCRIPT_LD_A_MEM, int(LAYOUT["current_menu_item"]) & 0xFF,
				int(LAYOUT["current_menu_item"]) >> 8, Gen1Layout.SCRIPT_AND_A]
			+ [0x20, yes.size()] + yes + no,
		_boxes()
	)
	assert_eq(script, [{
		"op": "choice",
		"yes": [{
			"op": "has_money", "price": 500,
			"then": [{"op": "text", "text": "HI"}],
			"else": [{"op": "text", "text": "BYE"}],
		}],
		"no": [{"op": "text", "text": "BYE"}],
	}])


## A conditional `call` to a routine that prints is a branch: the side that
## calls prints the routine's box and then its own, the other only its own.
func test_a_conditional_call_is_a_branch() -> void:
	var routine: int = 0x1400
	var script: Array = _decode(
		_load_a(int(LAYOUT["event_flags"])) + [Gen1Layout.SCRIPT_PREFIX, 0x5F]
			+ [0xC4, routine & 0xFF, routine >> 8] + _print(HELLO) + [Gen1Layout.SCRIPT_RET],
		_boxes(), _raw_at(routine, _print(BYE) + [Gen1Layout.SCRIPT_RET])
	)
	assert_eq(script, [{"op": "branch", "flag": 3,
		"then": [{"op": "text", "text": "BYE"}, {"op": "text", "text": "HI"}],
		"else": [{"op": "text", "text": "HI"}]}])


## The Elite Four rooms end their buffer with `ld [hl], a`.
func test_a_store_through_hl_ends_the_joypad_buffer() -> void:
	var script: Array = _decode(
		_load_hl(int(LAYOUT["simulated_joypad_end"])) + [Gen1Layout.SCRIPT_LD_A, 0x40]
			+ [Gen1Layout.SCRIPT_LD_HLI_A, Gen1Layout.SCRIPT_LD_HL_A, Gen1Layout.SCRIPT_LD_A, 2]
			+ _store_a(int(LAYOUT["simulated_joypad_index"]))
			+ _call(int(LAYOUT["start_simulating_joypad"])) + [Gen1Layout.SCRIPT_RET]
	)
	assert_eq(script, [{"op": "walk", "moves": [{"direction": 1, "steps": 2}]}])


## `ld a, [hli]` over a table in the bank, `cp $ff` folding on the byte read
## and the loop behind it unrolling: Silph Co.'s rockets leaving.
func test_a_table_loop_unrolls_on_the_bytes_read() -> void:
	var table: int = 0x1900
	var script: Array = _decode(
		_load_hl(table) + [Gen1Layout.SCRIPT_LD_A_HLI, Gen1Layout.SCRIPT_CP_N, 0xFF, 0x28, 0x0C]
			+ [Gen1Layout.SCRIPT_PUSH_HL] + _store_a(int(LAYOUT["toggleable_index"]))
			+ [Gen1Layout.SCRIPT_LD_A, 1] + _call(int(LAYOUT["predef"]))
			+ [Gen1Layout.SCRIPT_POP_HL, Gen1Layout.SCRIPT_JR, 0xEF, Gen1Layout.SCRIPT_RET],
		{}, {table: 5, table + 1: 9, table + 2: 0xFF}
	)
	assert_eq(script, [
		{"op": "toggle_object", "index": 5, "hidden": true},
		{"op": "toggle_object", "index": 9, "hidden": true},
	])


func test_a_last_map_store_is_a_node() -> void:
	assert_eq(_decode(
		[Gen1Layout.SCRIPT_LD_A, 7] + _store_a(int(LAYOUT["last_map"])) + [Gen1Layout.SCRIPT_RET]
	), [{"op": "set_last_map", "map": 7}])


## `CheckBoulderCoords` answers in carry, so `jr nc` is the side off the list.
func test_a_boulder_check_branches_in_carry() -> void:
	var cells: int = 0x1900
	var script: Array = _decode(
		_load_hl(cells) + _call(int(LAYOUT["check_boulder_coords"])) + [0x30, 0x06]
			+ _print(HELLO) + [Gen1Layout.SCRIPT_RET],
		_boxes(), {cells: 4, cells + 1: 6, cells + 2: Gen1Layout.MAP_COORD_END}
	)
	assert_eq(script, [{"op": "boulder_on", "cells": [{"y": 4, "x": 6}],
		"then": [{"op": "text", "text": "HI"}], "else": []}])


## `wCurOpponent` above OPP_ID_OFFSET, then `wRivalStarter` picking `wTrainerNo`.
func test_the_rivals_starter_picks_the_party() -> void:
	var script: Array = _decode(
		[Gen1Layout.SCRIPT_LD_A, 0xF2] + _store_a(int(LAYOUT["cur_opponent"]))
			+ _load_a(int(LAYOUT["rival_starter"])) + [Gen1Layout.SCRIPT_CP_N, 0xB1, 0x20, 0x04]
			+ [Gen1Layout.SCRIPT_LD_A, 7, Gen1Layout.SCRIPT_JR, 0x02, Gen1Layout.SCRIPT_LD_A, 9]
			+ _store_a(int(LAYOUT["trainer_no"])) + [Gen1Layout.SCRIPT_RET]
	)
	assert_eq(script, [{"op": "starter", "who": "rival", "value": 0xB1,
		"then": [{"op": "trainer_battle", "class": 0x2A, "number": 7}],
		"else": [{"op": "trainer_battle", "class": 0x2A, "number": 9}]}])


func _raw_at(address: int, bytes: Array) -> Dictionary:
	var out: Dictionary = {}
	for index: int in bytes.size():
		out[address + index] = int(bytes[index])
	return out
