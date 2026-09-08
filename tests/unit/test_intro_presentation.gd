extends GutTest

## `home/fade.asm` and `engine/menus/intro_menu.asm`'s frame counts and palette
## bytes, which are the whole of the intro's timing, with
## `engine/movie/oak_speech/oak_speech.asm`'s own runs and beat order beside
## them.

var _row := PackedColorArray([Color.RED, Color.GREEN, Color.BLUE, Color.WHITE])
var _motion: Gen2IntroPresentation = null


func before_each() -> void:
	_motion = Gen2IntroPresentation.new()


## Runs the queue out and returns the palette byte in force on each frame.
func _bgp_trace() -> Array[int]:
	var out: Array[int] = []
	while _motion.advance_frame():
		out.append(_motion.bgp())
	return out


func _column_trace() -> Array[int]:
	var out: Array[int] = []
	while _motion.advance_frame():
		out.append(_motion.column())
	return out


## `CopyPals` reads the byte two bits at a time, low pair first, and writes the
## loaded colour each pair names. %11100100 is the identity.
func test_a_palette_byte_indexes_the_loaded_row() -> void:
	assert_eq(Gen2IntroPresentation.apply_bgp(_row, 0xE4), _row, "the identity")
	assert_eq(
		Gen2IntroPresentation.apply_bgp(_row, 0x00),
		PackedColorArray([Color.RED, Color.RED, Color.RED, Color.RED]),
		"IncGradGBPalTable_07 is every colour the first one"
	)
	assert_eq(
		Gen2IntroPresentation.apply_bgp(_row, 0xFF),
		PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]),
		"IncGradGBPalTable_00 is every colour the last one"
	)
	# `dc 2,1,0,0`: a right rotation that fills from the left rather than wrapping.
	assert_eq(
		Gen2IntroPresentation.apply_bgp(_row, 0x90),
		PackedColorArray([Color.RED, Color.RED, Color.GREEN, Color.BLUE])
	)


## Anything that is not a four-colour row has no byte to index it.
func test_a_row_that_is_not_four_colours_is_handed_back() -> void:
	var pair := PackedColorArray([Color.RED, Color.BLUE])
	assert_eq(Gen2IntroPresentation.apply_bgp(pair, 0x00), pair)


## Three steps of eight frames, ending on white: tables 05, 06, 07.
func test_rotate_three_right_is_three_eights_ending_on_white() -> void:
	_motion.push_rotate_three_right()
	var trace: Array[int] = _bgp_trace()
	assert_eq(trace.size(), 24)
	assert_eq(trace[0], 0x90)
	assert_eq(trace[8], 0x40)
	assert_eq(trace[16], 0x00)
	assert_eq(_motion.bgp(), 0x00, "and the byte stays after the routine returns")


## Tables 06, 05, 04, read backwards, so it ends on the identity.
func test_rotate_three_left_ends_on_the_identity() -> void:
	_motion.push_rotate_three_left()
	var trace: Array[int] = _bgp_trace()
	assert_eq(trace.size(), 24)
	assert_eq(trace[0], 0x40)
	assert_eq(trace[16], Gen2IntroPresentation.BGP_NORMAL)


## Four steps of eight. Right runs the table forward from all-dark to the
## identity; Left runs it back the other way.
func test_the_four_palette_fades_are_thirty_two_frames_each() -> void:
	_motion.push_rotate_four_right()
	var right: Array[int] = _bgp_trace()
	assert_eq(right.size(), 32)
	assert_eq(right[0], 0xFF)
	assert_eq(right[24], Gen2IntroPresentation.BGP_NORMAL)

	_motion = Gen2IntroPresentation.new()
	_motion.push_rotate_four_left()
	var left: Array[int] = _bgp_trace()
	assert_eq(left.size(), 32)
	assert_eq(left[0], Gen2IntroPresentation.BGP_NORMAL)
	assert_eq(left[24], 0xFF, "ending on black")


## `IntroFadePalettes`: six entries, ten frames each.
func test_the_frontpic_fade_is_six_tens_ending_on_the_identity() -> void:
	_motion.push_rotate_left_frontpic()
	var trace: Array[int] = _bgp_trace()
	assert_eq(trace.size(), 60)
	assert_eq(trace[0], 0x54)
	assert_eq(trace[10], 0xA8)
	assert_eq(trace[50], Gen2IntroPresentation.BGP_NORMAL)


## `Intro_WipeInFrontpic` holds whatever palette it inherited for one frame,
## then writes the identity for the rest of hWX's walk.
func test_the_wipe_is_sixteen_frames_and_pops_the_pic_on_the_second() -> void:
	_motion.push_rotate_three_right()
	while _motion.advance_frame():
		pass
	_motion.push_wipe_in_frontpic()
	var trace: Array[int] = _bgp_trace()
	assert_eq(trace.size(), 16)
	assert_eq(trace[0], 0x00, "still white on the frame before the palette write")
	assert_eq(trace[1], Gen2IntroPresentation.BGP_NORMAL)


func test_wipe_window_counts_down_from_the_source_hwx_value_in_eights() -> void:
	assert_eq(Gen2IntroPresentation.wipe_window_x(0), 0x77)
	assert_eq(Gen2IntroPresentation.wipe_window_x(1), 0x6F)
	assert_eq(Gen2IntroPresentation.wipe_window_x(14), 7)
	assert_eq(Gen2IntroPresentation.wipe_window_x(15), 0)
	assert_eq(Gen2IntroPresentation.wipe_window_x(99), 0)


## `MovePlayerPic`'s eight iterations, each `WaitBGMap`'s four frames plus its
## own `DelayFrame`, walking one tile at a time from (6,4) to (13,4).
func test_the_player_pic_walks_a_tile_every_five_frames() -> void:
	_motion.push_move_player_pic(true)
	var trace: Array[int] = _column_trace()
	assert_eq(trace.size(), 40)
	assert_eq(trace[0], 6)
	assert_eq(trace[4], 6, "a column is held for all five of its frames")
	assert_eq(trace[5], 7)
	assert_eq(trace[39], 13)
	assert_eq(_motion.column(), 13, "and the last column is never cleared")


func test_the_pic_walks_back_the_same_way() -> void:
	_motion.push_move_player_pic(false)
	var trace: Array[int] = _column_trace()
	assert_eq(trace.size(), 40)
	assert_eq(trace[0], 13)
	assert_eq(trace[39], 6)


## The queue is what a routine returning empties; the palette byte and the
## column are hardware state and survive it.
func test_clearing_the_queue_keeps_the_screen_as_it_was_drawn() -> void:
	_motion.push_move_player_pic(true)
	_motion.push_rotate_three_right()
	while _motion.advance_frame():
		pass
	_motion.clear()
	assert_eq(_motion.column(), 13)
	assert_eq(_motion.bgp(), 0x00)
	assert_true(_motion.finished())


func test_remaining_frames_counts_what_the_queue_still_owes() -> void:
	_motion.push_rotate_three_right()
	assert_eq(_motion.remaining_frames(), 24)
	for _frame: int in 10:
		_motion.advance_frame()
	assert_eq(_motion.remaining_frames(), 14)


# --- Generation 1's own runs --------------------------------------------------

## `GBFadeOutToWhite`: `FadePal6`, `FadePal7` and `FadePal8`'s rBGP bytes, eight
## frames each, ending on a screen with every index white.
func test_the_generation_one_fade_out_is_three_eights_ending_on_white() -> void:
	_motion.push_gen1_fade_out_white()
	var trace: Array[int] = _bgp_trace()
	assert_eq(trace.size(), 24)
	assert_eq([trace[0], trace[8], trace[16], trace[23]], [0x90, 0x40, 0x00, 0x00])


## `GBFadeInFromWhite` reads the same table backwards from `FadePal7`.
func test_the_generation_one_fade_in_ends_on_the_identity() -> void:
	_motion.push_gen1_fade_in_white()
	var trace: Array[int] = _bgp_trace()
	assert_eq(trace.size(), 24)
	assert_eq([trace[0], trace[8], trace[16]], [0x40, 0x90, 0xE4])


## `MovePicLeft`: rWX 119 for two frames, the second writing the identity
## palette, then one frame per eight until the subtraction would pass zero.
func test_the_picture_walks_in_from_fourteen_columns_of_window() -> void:
	_motion.push_gen1_move_pic_left()
	var columns: Array[int] = _column_trace()
	assert_eq(columns.size(), 16)
	assert_eq(columns[0], Gen2IntroPresentation.PIC_LEFT_COLUMN + 14)
	assert_eq(columns[1], columns[0], "the second frame writes the palette, not rWX")
	assert_eq(columns[columns.size() - 1], Gen2IntroPresentation.PIC_LEFT_COLUMN)

	_motion.clear()
	_motion.push_gen1_move_pic_left()
	var palettes: Array[int] = _bgp_trace()
	assert_eq(palettes[1], Gen2IntroPresentation.BGP_NORMAL)


## `OakSpeechSlidePicRight` and its left half: six columns, one `Delay3` each,
## between the picture's own place and where the name box leaves it.
func test_the_name_box_slide_is_six_columns_of_three_frames() -> void:
	_motion.push_gen1_slide_pic(true)
	var columns: Array[int] = _column_trace()
	assert_eq(columns.size(), 18)
	assert_eq(columns[0], Gen2IntroPresentation.PIC_LEFT_COLUMN + 1)
	assert_eq(columns[columns.size() - 1], Gen2IntroPresentation.GEN1_SLIDE_RIGHT_COLUMN)

	_motion.clear()
	_motion.push_gen1_slide_pic(false)
	columns = _column_trace()
	assert_eq(columns.size(), 18)
	assert_eq(columns[columns.size() - 1], Gen2IntroPresentation.PIC_LEFT_COLUMN)


## `OakSpeech`'s own run: two pictures and two naming branches where Generation
## 2 has one, and the two answers printed over the pictures that asked for them.
func test_the_generation_one_beats_are_the_source_routines_order() -> void:
	var keys: Array = []
	var names: Array = []
	for row: Array in Gen2OakSpeech.GEN1_ORDER:
		keys.append(String(row[1]))
		if String(row[4]) != Gen2OakSpeech.NAME_NONE:
			names.append(String(row[4]))
	assert_eq(keys, [
		"oak_speech_1", "oak_speech_2", "introduce_player", "your_name_is",
		"introduce_rival", "his_name_is", "oak_speech_3",
	])
	assert_eq(names, [Gen2OakSpeech.NAME_PLAYER, Gen2OakSpeech.NAME_RIVAL])
	assert_eq(int(Gen2OakSpeech.GEN1_ORDER[3][0]), Gen2OakSpeech.Pic.PLAYER)
	assert_eq(int(Gen2OakSpeech.GEN1_ORDER[5][0]), Gen2OakSpeech.Pic.RIVAL)
	assert_eq(int(Gen2OakSpeech.GEN1_ORDER[1][2]), Gen2OakSpeech.Enter.MOVE_LEFT)
	assert_eq(int(Gen2OakSpeech.GEN1_ORDER[6][2]), Gen2OakSpeech.Enter.FADE_IN_WHITE)


## `_OakSpeechText3` opens on `<PLAYER>` and `_HisNameIsText` carries `<RIVAL>`,
## which are the only two print-time names the speech has to fill.
func test_both_intro_names_are_filled_where_the_codec_left_them() -> void:
	assert_eq(
		Gen2OakSpeech.with_names("<PLAYER>! <RIVAL> waits.", "RED", "BLUE"),
		"RED! BLUE waits."
	)
