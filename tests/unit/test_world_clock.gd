extends GutTest

## The host clock uses the same one-second units as the cartridge RTC, but it
## is deterministic so a test can cross a boundary without waiting in real time.


func test_clock_publishes_one_schedule_tick_per_completed_minute() -> void:
	var clock := Gen2WorldClock.new(9, 59, 2)
	assert_eq(clock.advance(59.9).size(), 0)
	var ticks: Array = clock.advance(0.1)
	assert_eq(ticks.size(), 1)
	assert_eq(ticks[0]["day"], 2)
	assert_eq(ticks[0]["hour"], 10)
	assert_eq(ticks[0]["minute"], 0)
	assert_eq(ticks[0]["time_of_day"], Gen2WorldPalette.TIME_DAY)


func test_clock_uses_source_time_of_day_boundaries_and_wraps_the_week() -> void:
	var clock := Gen2WorldClock.new(17, 59, 6)
	assert_eq(clock.time_of_day(), Gen2WorldPalette.TIME_DAY)
	clock.advance(60.0)
	assert_eq(clock.time_of_day(), Gen2WorldPalette.TIME_NIGHT)
	assert_eq(clock.day, 6)
	clock.advance(6.0 * 60.0 * 60.0)
	assert_eq(clock.hour, 0)
	assert_eq(clock.day, 0)


## `--clock=HH:MM`, which is how an hour is photographed through the production
## path: a renderer reads world state and must not write it, so nothing inside
## the game can move the clock to look at what it draws at another hour.
func test_the_clock_pin_is_parsed_off_the_command_line_and_holds_the_run() -> void:
	assert_eq(Gen2WorldClock.parse_pin(PackedStringArray(["--headless"])), {})
	assert_eq(
		Gen2WorldClock.parse_pin(PackedStringArray(["--clock=06:30"])),
		{"hour": 6, "minute": 30, "day": 0},
	)
	assert_eq(
		Gen2WorldClock.parse_pin(PackedStringArray(["-s", "x.gd", "--clock=22:05:3"])),
		{"hour": 22, "minute": 5, "day": 3},
	)
	# Out of range wraps rather than refusing, the way the constructor's does.
	assert_eq(
		Gen2WorldClock.parse_pin(PackedStringArray(["--clock=25:61:9"])),
		{"hour": 1, "minute": 1, "day": 2},
	)

	var clock := Gen2WorldClock.new(6, 30)
	clock.pinned = true
	assert_eq(clock.advance(60.0 * 60.0 * 12.0), [])
	assert_eq(clock.hour, 6)
	assert_eq(clock.minute, 30)
	assert_eq(clock.time_of_day(), Gen2WorldPalette.TIME_MORNING)
