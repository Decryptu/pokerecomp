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


## The cartridge's RTC keeps running while the machine is off, so a save opens at
## the time it was written at plus the real seconds since. Without this a session
## resumed at the hour the last one stopped at, and a player who set the clock to
## the morning saw no other time of day, whatever the hour they played at.
func test_a_saved_clock_catches_up_to_the_time_that_passed_while_it_was_closed() -> void:
	var stamp: float = 1_000_000.0
	assert_eq(
		Gen2WorldClock.catch_up(0, 10, 15, stamp, stamp + 60.0 * 90.0),
		{"day": 0, "hour": 11, "minute": 45},
	)
	# Two and a half days on, which carries the weekday with it.
	assert_eq(
		Gen2WorldClock.catch_up(5, 23, 30, stamp, stamp + 60.0 * 60.0 * 60.0),
		{"day": 1, "hour": 11, "minute": 30},
	)
	# A snapshot written before the stamp was kept, and a host clock put back:
	# neither runs the world's own clock backwards.
	assert_eq(
		Gen2WorldClock.catch_up(3, 8, 5, 0.0, stamp), {"day": 3, "hour": 8, "minute": 5}
	)
	assert_eq(
		Gen2WorldClock.catch_up(3, 8, 5, stamp, stamp - 3600.0),
		{"day": 3, "hour": 8, "minute": 5},
	)


## The stamp is the snapshot's, so what a save carries is the host second its own
## clock was written at.
func test_a_snapshot_stamps_the_host_second_its_clock_was_written_at() -> void:
	Gen2WorldClock.host_seconds_override = 1_234_567.0
	var snapshot := Gen2WorldSnapshot.new()
	snapshot.world_day = 2
	snapshot.world_hour = 9
	snapshot.world_minute = 40
	snapshot.world_clock_stamp = Gen2WorldClock.host_seconds()
	var restored: Gen2WorldSnapshot = Gen2WorldSnapshot.from_dict(snapshot.to_dict())
	assert_eq(restored.world_clock_stamp, 1_234_567.0)
	Gen2WorldClock.host_seconds_override = 2_234_567.0
	assert_eq(
		Gen2WorldClock.catch_up(
			restored.world_day, restored.world_hour, restored.world_minute,
			restored.world_clock_stamp
		),
		{"day": 6, "hour": 23, "minute": 26},
	)
	Gen2WorldClock.host_seconds_override = -1.0
