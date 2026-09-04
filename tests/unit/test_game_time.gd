extends GutTest

## home/game_time.asm's GameTimer.


func test_sixty_frames_make_a_second_even_though_a_frame_is_not_a_sixtieth() -> void:
	var time := PokeGameTime.new()
	for _frame: int in PokeGameTime.FRAMES_PER_SECOND - 1:
		assert_false(time.advance_frame())
	assert_eq(time.seconds, 0)
	time.advance_frame()
	assert_eq(time.seconds, 1)
	assert_eq(time.frames, 0)


## The counter only reports a change when something the card prints moved, which
## is the minute and above.
func test_only_a_minute_or_more_reports_a_change() -> void:
	var time := PokeGameTime.create(0, 0, 59, 59)
	assert_true(time.advance_frame())
	assert_eq(time.minutes, 1)
	assert_eq(time.seconds, 0)


func test_sixty_minutes_make_an_hour() -> void:
	var time := PokeGameTime.create(4, 59, 59, 59)
	assert_true(time.advance_frame())
	assert_eq(time.hours, 5)
	assert_eq(time.minutes, 0)
	assert_eq(time.seconds, 0)
	assert_eq(time.frames, 0)


## "Cap the timer after 1000 hours", which leaves 999:59:59 on the card and
## stops counting for good.
func test_the_timer_caps_at_999_59_59_and_stays_there() -> void:
	var time := PokeGameTime.create(999, 59, 59, 59)
	assert_true(time.advance_frame())
	assert_true(time.capped)
	assert_eq(time.hours, PokeGameTime.CAPPED_HOURS)
	assert_eq(time.minutes, PokeGameTime.CAPPED_MINUTES)
	assert_eq(time.seconds, PokeGameTime.CAPPED_SECONDS)

	assert_false(time.advance_frame())
	assert_eq(time.hours, PokeGameTime.CAPPED_HOURS)


func test_many_frames_at_once_match_the_same_frames_one_at_a_time() -> void:
	var stepped := PokeGameTime.new()
	for _frame: int in 3 * PokeGameTime.FRAMES_PER_SECOND + 7:
		stepped.advance_frame()
	var jumped := PokeGameTime.new()
	jumped.advance_frames(3 * PokeGameTime.FRAMES_PER_SECOND + 7)
	assert_eq(jumped.to_dict(), stepped.to_dict())


func test_a_negative_or_zero_jump_changes_nothing() -> void:
	var time := PokeGameTime.new()
	assert_false(time.advance_frames(0))
	assert_false(time.advance_frames(-5))
	assert_eq(time.frames, 0)


func test_it_round_trips_and_clamps_a_damaged_value() -> void:
	var time := PokeGameTime.create(12, 34, 56, 7)
	assert_eq(PokeGameTime.parse(time.to_dict()).to_dict(), time.to_dict())

	var damaged: PokeGameTime = PokeGameTime.parse({
		"hours": 5000, "minutes": -3, "seconds": 900, "frames": 61,
	})
	assert_eq(damaged.hours, PokeGameTime.CAPPED_HOURS)
	assert_eq(damaged.minutes, 0)
	assert_eq(damaged.seconds, PokeGameTime.CAPPED_SECONDS)
	assert_eq(damaged.frames, PokeGameTime.FRAMES_PER_SECOND - 1)
	assert_eq(PokeGameTime.parse("not a timer").to_dict(), PokeGameTime.new().to_dict())


## `TrainerCard_Page1_PrintGameTime`: four columns for the hours and two digits
## with leading zeros for the minutes.
func test_the_printed_columns_are_the_source_field_widths() -> void:
	var time := PokeGameTime.create(7, 5, 0, 0)
	assert_eq(time.hours_text(), "   7")
	assert_eq(time.minutes_text(), "05")
	assert_eq(PokeGameTime.create(999, 59, 0, 0).hours_text(), " 999")
