class_name Gen2WorldClock
extends RefCounted

## Deterministic host clock for the real-time Generation 2 day cycle.
## One elapsed host second is one cartridge clock second. A tick is published at
## each completed game minute, while time-of-day changes use the cartridge's
## 04:00, 10:00 and 18:00 boundaries.
##
## Seconds, not hardware frames, on purpose. Everything else in the overworld is
## a countdown spent by [method Gen2WorldScreen.advance_frame]; the cartridge
## reads a real-time clock for the day cycle, so this one takes wall time and
## [method Gen2WorldScreen._advance_day_cycle] is the only caller that hands it
## `delta`. A test or a replay reaches any boundary by asking for the seconds
## rather than by waiting for them
## ([method Gen2WorldScreen.advance_world_time]).
##
## The clock does not move roaming Pokémon: the cartridge advances those during
## map setup, so [method Gen2WorldAPI.advance_schedule] is driven by a map change
## rather than elapsed time.

const SECONDS_PER_MINUTE: float = 60.0
const MINUTES_PER_HOUR: int = 60
const HOURS_PER_DAY: int = 24
const DAYS_PER_WEEK: int = 7
## `constants/wram_constants.asm`'s weekday numbering, SUNDAY first.
## `RestartLuckyNumberCountdown` is the one routine that names a day.
const FRIDAY: int = 5
const MORN_START: int = 4
const DAY_START: int = 10
const NITE_START: int = 18

## `--clock=HH:MM`, and `--clock=HH:MM:D` to name the day of the week as well.
## The prefix, so the switch is written once.
const PIN_ARGUMENT: String = "--clock="

var day: int = 0
var hour: int = 0
var minute: int = 0
## Whether this clock is held where it was opened. See [method pin].
var pinned: bool = false
var _elapsed_seconds: float = 0.0

static var _pin: Dictionary = {}
static var _pin_read: bool = false


func _init(start_hour: int = 0, start_minute: int = 0, start_day: int = 0) -> void:
	day = posmod(start_day, DAYS_PER_WEEK)
	hour = posmod(start_hour, HOURS_PER_DAY)
	minute = posmod(start_minute, MINUTES_PER_HOUR)


func time_of_day() -> int:
	if hour < MORN_START:
		return Gen2WorldPalette.TIME_NIGHT
	if hour < DAY_START:
		return Gen2WorldPalette.TIME_MORNING
	if hour < NITE_START:
		return Gen2WorldPalette.TIME_DAY
	return Gen2WorldPalette.TIME_NIGHT


## `--clock=HH:MM` on the command line: the time every world opened this run
## starts at and is held at, over the export defaults and over a save's own.
##
## An hour reaches the screen through the palettes and the light, and a renderer
## reads world state and must not write it, so a shot tool or a mod's own
## instrument cannot otherwise photograph what it draws at any hour but the one
## the run happens to be in. Empty unless the switch was passed, and read once:
## a run's clock cannot change under it.
static func pin() -> Dictionary:
	if not _pin_read:
		_pin_read = true
		_pin = parse_pin(OS.get_cmdline_args() + OS.get_cmdline_user_args())
	return _pin


## The pin [param args] names, empty if none of them is one. Public so a test
## reaches the parsing without a command line.
static func parse_pin(args: PackedStringArray) -> Dictionary:
	for argument: String in args:
		if not argument.begins_with(PIN_ARGUMENT):
			continue
		var parts: PackedStringArray = argument.trim_prefix(PIN_ARGUMENT).split(":")
		if parts.size() < 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
			push_warning("%s wants HH:MM, or HH:MM:D for the day: %s" % [
				PIN_ARGUMENT, argument
			])
			continue
		var named_day: int = 0
		if parts.size() > 2 and parts[2].is_valid_int():
			named_day = int(parts[2])
		return {
			"hour": posmod(int(parts[0]), HOURS_PER_DAY),
			"minute": posmod(int(parts[1]), MINUTES_PER_HOUR),
			"day": posmod(named_day, DAYS_PER_WEEK),
		}
	return {}


func advance(seconds: float, world: Gen2WorldAPI = null) -> Array:
	if seconds <= 0.0 or pinned:
		return []
	_elapsed_seconds += seconds
	var ticks: Array = []
	while _elapsed_seconds >= SECONDS_PER_MINUTE:
		_elapsed_seconds -= SECONDS_PER_MINUTE
		_advance_minute()
		if world != null:
			world.set_world_clock(day, hour, minute)
		ticks.append({
			"kind": &"world_clock_minute",
			"day": day,
			"hour": hour,
			"minute": minute,
			"time_of_day": time_of_day(),
		})
	return ticks


func snapshot() -> Dictionary:
	return {
		"day": day,
		"hour": hour,
		"minute": minute,
		"elapsed_seconds": _elapsed_seconds,
		"time_of_day": time_of_day(),
	}


func _advance_minute() -> void:
	minute += 1
	if minute < MINUTES_PER_HOUR:
		return
	minute = 0
	hour += 1
	if hour < HOURS_PER_DAY:
		return
	hour = 0
	day = (day + 1) % DAYS_PER_WEEK
