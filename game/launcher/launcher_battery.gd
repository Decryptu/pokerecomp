class_name Gen2LauncherBattery
extends HBoxContainer

## The charge indicator in the top right. Godot reports no power state on any
## platform, so every reading here is this project's own. There is one probe per
## platform and no fallback: a machine whose charge cannot be read draws no
## indicator rather than a full cell that is not true, which is what
## [method reading_available] answers. macOS reads `pmset -g batt` and Windows
## `Get-CimInstance Win32_Battery`, both on a worker thread; Linux and BSD read
## `/sys/class/power_supply`; Android and iOS come through the platform plugin.
## Anything else, the Switch build included, has no probe and no indicator.

const FULL: int = 100
## The cell, without the terminal on its right end.
const BODY: Vector2 = Vector2(26.0, 13.0)
const TERMINAL: Vector2 = Vector2(2.5, 5.0)
## Below this the cell is drawn in the warning colour.
const LOW: int = 20

## How often the charge is read again. A percentage moves a few times an hour on
## any real machine, and two of the probes are a process launch.
const POLL_SECONDS: float = 60.0

## The Android and iOS singletons, each registered by the platform plugin of the
## same name. Absent everywhere else, which is what [method _probe_plugin] tests.
const ANDROID_SINGLETON: StringName = &"Gen2PlatformPower"
const IOS_SINGLETON: StringName = &"NativePower"

## `/sys/class/power_supply` names a laptop battery `BAT0` through `BAT2` and a
## handheld's `battery`. Read in order; the first that answers is the one.
const SYSFS_ROOT: String = "/sys/class/power_supply"
const SYSFS_NAMES: Array[String] = ["BAT0", "BAT1", "BAT2", "battery"]

## The last reading and the moment it was taken, shared by every widget rather
## than held per instance: the charge belongs to the machine, and a page rebuilt
## on a theme change must not launch a process to learn what is already known.
static var _shared: Dictionary = {}
static var _shared_at: float = -1.0
## The running worker task, or -1. Static for the same reason: two shells opening
## at once would run two `pmset`s.
static var _task: int = -1
static var _lock: Mutex = Mutex.new()

var level: int = 0
var charging: bool = false

var _theme: Gen2LauncherTheme = null
var _cell: Control = null
var _readout: Label = null
var _since_poll: float = POLL_SECONDS


static func create(palette: Gen2LauncherTheme) -> Gen2LauncherBattery:
	var battery := Gen2LauncherBattery.new()
	battery._theme = palette
	battery._build()
	return battery


func _build() -> void:
	add_theme_constant_override("separation", Gen2LauncherUI.GAP_SM)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_readout = Gen2LauncherUI.title(_theme, "", Gen2LauncherTheme.FONT_BODY)
	_readout.add_theme_color_override("font_color", _theme.surface)
	_readout.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_readout)
	_cell = Control.new()
	_cell.custom_minimum_size = Vector2(BODY.x + TERMINAL.x + 1.0, BODY.y)
	_cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cell.draw.connect(_draw_cell)
	add_child(_cell)
	## Nothing is drawn until a probe has answered, so a machine with no battery
	## never flashes a full cell on its way to showing none.
	visible = false
	_apply(_cached_reading())


func _process(delta: float) -> void:
	_since_poll += delta
	_collect_finished_task()
	if _since_poll < POLL_SECONDS:
		return
	_since_poll = 0.0
	_start_poll()


## Whether this machine answered with a charge at all. False on a desktop with
## no battery, on the Switch build, and on any platform with no probe.
func reading_available() -> bool:
	return visible


## Sets the charge by hand, clamped to a percentage. The seam a test and
## `tools/preview_launcher.gd` use to photograph a level the machine running
## them is not on.
func set_level(percent: int, is_charging: bool = false) -> void:
	_apply({"percent": clampi(percent, 0, FULL), "charging": is_charging})


func _apply(reading: Dictionary) -> void:
	var percent: int = int(reading.get("percent", -1))
	if percent < 0:
		visible = false
		return
	var wanted_charging: bool = bool(reading.get("charging", false))
	visible = true
	if percent == level and wanted_charging == charging:
		return
	level = percent
	charging = wanted_charging
	_readout.text = "%d%%" % level
	_cell.queue_redraw()


## The colour the cell is filled with: the accent while something is charging it,
## the warning colour while it is nearly empty, and the surface otherwise.
func _ink() -> Color:
	if charging:
		return _theme.success
	return _theme.warning if level <= LOW else _theme.surface


func _draw_cell() -> void:
	var ink: Color = _ink()
	var shell := Rect2(Vector2(0.0, (_cell.size.y - BODY.y) * 0.5), BODY)
	_cell.draw_style_box(
		_theme.box(Color(0, 0, 0, 0), 4.0, _theme.with_alpha(ink, 0.55), 2), shell
	)
	_cell.draw_style_box(
		_theme.box(_theme.with_alpha(ink, 0.55), 2.0),
		Rect2(
			Vector2(shell.end.x + 1.0, shell.get_center().y - TERMINAL.y * 0.5),
			TERMINAL,
		),
	)
	# Inset by the outline plus a hair, so a full cell still reads as a cell with
	# something in it rather than as a solid block.
	var inner: Rect2 = shell.grow(-3.5)
	if inner.size.x <= 0.0 or level <= 0:
		return
	inner.size.x *= float(level) / float(FULL)
	_cell.draw_style_box(_theme.box(ink, 2.0), inner)


static func _cached_reading() -> Dictionary:
	_lock.lock()
	var out: Dictionary = _shared.duplicate()
	_lock.unlock()
	return out


## Reads the charge again unless a read is already in flight or the last one is
## still fresh, which is what keeps every open shell to one probe between them.
func _start_poll() -> void:
	if _task >= 0:
		return
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	if _shared_at >= 0.0 and now - _shared_at < POLL_SECONDS:
		_apply(_cached_reading())
		return
	## The two singleton platforms are a field read and are answered here: a JNI
	## call from a worker thread is not something this project can promise, and
	## there is nothing to gain by it.
	var native: Dictionary = _probe_plugin()
	if not native.is_empty():
		_store(native)
		_apply(native)
		return
	## Only the two that launch a process go to a worker. A sysfs read is a file
	## and costs less than the thread would.
	if _shells_out():
		_task = WorkerThreadPool.add_task(_run_probe)
		return
	var reading: Dictionary = _probe_shell()
	_store(reading)
	_apply(reading)


## Hands a finished worker's answer to the cell. The task writes the shared
## reading rather than touching this node, so a shell freed mid-probe leaves
## nothing dangling.
func _collect_finished_task() -> void:
	if _task < 0 or not WorkerThreadPool.is_task_completed(_task):
		return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	_apply(_cached_reading())


func _exit_tree() -> void:
	if _task < 0:
		return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1


static func _run_probe() -> void:
	_store(_probe_shell())


static func _store(reading: Dictionary) -> void:
	_lock.lock()
	_shared = reading.duplicate()
	_shared_at = float(Time.get_ticks_msec()) / 1000.0
	_lock.unlock()


## Whether this platform's probe launches a process, which is the only reason a
## reading is taken off the main thread at all.
static func _shells_out() -> bool:
	return OS.get_name() in ["macOS", "Windows"]


## The two platforms whose reading is a plugin singleton. Empty everywhere else,
## and empty on a build that lost its plugin: `has_method` answers false on a
## [JNISingleton] whose calls all work, so the call is made and the answer is
## what decides.
static func _probe_plugin() -> Dictionary:
	var singleton: StringName = &""
	match OS.get_name():
		"Android":
			singleton = ANDROID_SINGLETON
		"iOS":
			singleton = IOS_SINGLETON
		_:
			return {}
	if not Engine.has_singleton(singleton):
		return {}
	var plugin: Object = Engine.get_singleton(singleton)
	var percent: int = int(plugin.call("battery_percent"))
	if percent < 0:
		return {}
	return {
		"percent": clampi(percent, 0, FULL),
		"charging": bool(plugin.call("battery_charging")),
	}


## The desktop probes. [method _shells_out] names the two that are run on a
## worker thread; the sysfs read is a file and is answered where it is asked.
static func _probe_shell() -> Dictionary:
	match OS.get_name():
		"macOS":
			return _probe_pmset()
		"Windows":
			return _probe_windows()
		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			return _probe_sysfs()
	return {}


## `pmset -g batt`, whose second line is
## ` -InternalBattery-0 (id=...)\t89%; discharging; 9:51 remaining present: true`.
## A Mac with no battery prints the first line and nothing else.
static func _probe_pmset() -> Dictionary:
	var output: Array = []
	if OS.execute("/usr/bin/pmset", ["-g", "batt"], output, false) != 0 or output.is_empty():
		return {}
	var text: String = String(output[0])
	var percent: int = _percent_before_sign(text)
	if percent < 0:
		return {}
	## The header says which source the machine is on, and the row says what the
	## battery itself is doing. "charged" is a full battery on the mains, which
	## reads as charging here rather than as a cell that is quietly draining.
	return {
		"percent": percent,
		"charging": text.containsn("; charging") or text.containsn("; charged")
			or text.containsn("; finishing charge"),
	}


## `Win32_Battery`, whose `EstimatedChargeRemaining` is the percentage and whose
## `BatteryStatus` is 2 while the machine is on the mains. PowerShell rather than
## `wmic`, which Windows 11 no longer ships.
static func _probe_windows() -> Dictionary:
	var output: Array = []
	var script: String = (
		"$b = Get-CimInstance -ClassName Win32_Battery | Select-Object -First 1;"
		+ " if ($b) { \"$($b.EstimatedChargeRemaining) $($b.BatteryStatus)\" }"
	)
	var code: int = OS.execute(
		"powershell", ["-NoProfile", "-NonInteractive", "-Command", script], output, false
	)
	if code != 0 or output.is_empty():
		return {}
	var fields: PackedStringArray = String(output[0]).strip_edges().split(" ", false)
	if fields.size() < 2 or not fields[0].is_valid_int():
		return {}
	return {
		"percent": clampi(int(fields[0]), 0, FULL),
		## `BatteryStatus` 2 is "on AC"; 6, 7, 8 and 9 are the charging states.
		"charging": int(fields[1]) in [2, 6, 7, 8, 9],
	}


## `/sys/class/power_supply/<name>/capacity`, which every Linux and BSD power
## driver exposes as a bare percentage, with `status` beside it.
static func _probe_sysfs() -> Dictionary:
	for supply: String in SYSFS_NAMES:
		var directory: String = "%s/%s" % [SYSFS_ROOT, supply]
		var capacity: String = _read_sysfs_line("%s/capacity" % directory)
		if not capacity.is_valid_int():
			continue
		var status: String = _read_sysfs_line("%s/status" % directory)
		return {
			"percent": clampi(int(capacity), 0, FULL),
			"charging": status == "Charging" or status == "Full",
		}
	return {}


## One line of a sysfs file. `get_as_text` asks the file how long it is, and a
## sysfs file answers with its page size rather than its content, so the line is
## read instead.
static func _read_sysfs_line(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var line: String = file.get_line().strip_edges()
	file.close()
	return line


## The number in front of the first `%` in [param text], or -1 when there is
## none. What `pmset`'s row is read with.
static func _percent_before_sign(text: String) -> int:
	var sign_at: int = text.find("%")
	if sign_at <= 0:
		return -1
	var digits: String = ""
	var at: int = sign_at - 1
	while at >= 0 and text[at] >= "0" and text[at] <= "9":
		digits = text[at] + digits
		at -= 1
	return clampi(int(digits), 0, FULL) if digits.is_valid_int() else -1
