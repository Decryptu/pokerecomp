class_name Gen2Diagnostics
extends Node

## What a player hands over when something goes wrong: this build, this machine,
## the settings and mods in force, and the engine's own log of the session.
##
## A sink rather than a set of call sites: [Logger] goes in through
## [method OS.add_logger], so every print, warning and runtime error in the game,
## a tool or a mod reaches the report without being routed twice. The file at
## [constant DIRECTORY] is the engine's own, so it catches the crash handler's
## backtrace too; this class adds the header, the pruning and the bundle.

## Where the engine's file logger writes, mirrored from `project.godot` so the
## prune and the bundle read the directory the logs are actually in.
const DIRECTORY: String = "user://logs"
## Raised at boot and lowered on a clean exit, so the next launch can tell a
## quit from a crash without parsing anything.
const MARKER: String = "user://logs/session.json"

## What the prune keeps. The engine's own rotation counts files and nothing
## else, so a run that logged for a week is bounded here instead.
const KEEP_FILES: int = 10
const KEEP_DAYS: int = 30
const KEEP_BYTES: int = 8 << 20

## How much of the session the report itself quotes. The whole log is in the
## bundle beside it; this is the part a reader sees without unzipping.
const RECENT_LINES: int = 200
## The longest single message kept in that tail, so one enormous dump cannot
## push the rest of the session out of the report.
const LINE_LIMIT: int = 1000

const BUNDLE_PREFIX: String = "pokerecomp-report-"

## The autoload, cached after the first lookup. Reached through this rather than
## through the `Diagnostics` global for the reason
## [method Gen2GameRuntime.instance] gives: a script handed to `-s` compiles
## before the autoloads exist.
static var _instance: Gen2Diagnostics = null

var _sink: Gen2DiagnosticsSink = null
## Guards the tail and the counters. A logger is called from whichever thread
## raised the message, including the resource loader's.
var _lock: Mutex = Mutex.new()
var _tail: PackedStringArray = PackedStringArray()
var _errors: int = 0
var _warnings: int = 0
var _started_unix: int = 0
var _previous_unclean: bool = false
## The scene last written to the log, so the breadcrumb is a change rather than
## a line a frame.
var _scene_path: String = ""


static func instance() -> Gen2Diagnostics:
	if _instance == null:
		var loop: SceneTree = Engine.get_main_loop() as SceneTree
		if loop != null:
			_instance = loop.root.get_node_or_null(^"Diagnostics") as Gen2Diagnostics
	return _instance


## Records one line of context. Safe before the autoload exists and in a tool
## run, so a caller never guards the call itself.
##
## Goes through `print`, which is what puts it in the engine's log file next to
## the errors it explains; the sink below picks it up on the way past.
static func note(topic: String, message: String) -> void:
	print("[%s] %s" % [topic, message])


## A breadcrumb rather than an event: the same line, kept out of a run that is
## not a player's own. A corpus check or a story walk loads thousands of maps
## and its output is read by a diff, so a trail written for a bug report would
## drown it and would slow it down for no one's benefit.
static func trace(topic: String, message: String) -> void:
	if Gen2GameRuntime.is_player_launch():
		note(topic, message)


func _ready() -> void:
	_started_unix = int(Time.get_unix_time_from_system())
	prune()
	_read_marker()
	_install_sink()
	# Deferred so the header names the mods that are running: this autoload is
	# listed first, ahead of the one that loads them, because the sink has to be
	# installed before anything else can raise a message it would miss.
	_print_header.call_deferred()


## Printed rather than written, so it is near the top of the engine's own log
## file: a crash log is then self-describing whether or not the player ever
## reaches the launcher again.
##
## A player's launch only, for the reason [method trace] gives: a check or a
## tool is read for the answer it prints, and a header no one asked for is in
## the way of it.
func _print_header() -> void:
	if Gen2GameRuntime.is_player_launch():
		print(summary())


func _exit_tree() -> void:
	_clear_marker()
	if _sink != null:
		OS.remove_logger(_sink)
		_sink = null


## The breadcrumb every screen gets for free. `current_scene` has no signal of
## its own, and one pointer comparison a frame is cheaper than a notification in
## each of the screens that would otherwise have to report themselves.
func _process(_delta: float) -> void:
	var scene: Node = get_tree().current_scene
	var path: String = scene.scene_file_path if scene != null else ""
	if path == _scene_path:
		return
	_scene_path = path
	if not path.is_empty():
		trace("screen", path)


## Whether the previous session ended without reaching [method _exit_tree]: a
## crash, a kill, or a phone taking the process away. The launcher offers the
## report on the strength of this.
func previous_session_crashed() -> bool:
	return _previous_unclean


## Takes [param stored] as the previous session's marker. Public because the
## notice it raises is otherwise reachable only by crashing the game, which no
## test can do to itself.
func adopt_marker(stored: String) -> void:
	_previous_unclean = unclean_marker(stored)


## Said once. The launcher is rebuilt whole on a palette change and replays what
## it was saying, so a notice left standing would come back every time the
## player switched appearance.
func forget_previous_crash() -> void:
	_previous_unclean = false


func error_count() -> int:
	return _errors


func warning_count() -> int:
	return _warnings


## The last [constant RECENT_LINES] messages, oldest first.
func tail() -> PackedStringArray:
	_lock.lock()
	var out: PackedStringArray = _tail.duplicate()
	_lock.unlock()
	return out


## Everything but the log tail: the block a player can paste into a chat message
## without it being a wall of text. [method report] is this plus the tail.
func summary() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("pokerecomp diagnostics")
	lines.append("Generated  %s" % _stamp())
	lines.append("Build      %s, Godot %s, %s" % [
		Gen2AppVersion.display(),
		Engine.get_version_info().get("string", "?"),
		"debug" if OS.is_debug_build() else "release",
	])
	lines.append("Machine    %s %s, %s, %s" % [
		OS.get_distribution_name(), OS.get_version(),
		Engine.get_architecture_name(), OS.get_locale(),
	])
	lines.append("Video      %s, %s" % [
		_setting("rendering/renderer/rendering_method", "?"),
		_video_adapter(),
	])
	# Which of the three ways to ask for a file this build has. A player who
	# cannot get a cartridge in is the report this line is here for.
	lines.append("Files      %s" % _file_picker_kind())
	lines.append("Session    %s, %d error%s, %d warning%s%s" % [
		_uptime(),
		_errors, "" if _errors == 1 else "s",
		_warnings, "" if _warnings == 1 else "s",
		", the previous session ended unexpectedly" if _previous_unclean else "",
	])
	lines.append("")
	lines.append_array(_cartridge_lines())
	lines.append("")
	lines.append_array(_mod_lines())
	lines.append("")
	lines.append_array(_settings_lines())
	return "\n".join(lines)


## The whole thing, header and log tail. What `report.txt` inside the bundle
## holds, and what a player with no way to attach a file can still copy.
func report() -> String:
	var lines: PackedStringArray = PackedStringArray([summary(), "", "Recent log"])
	var recent: PackedStringArray = tail()
	if recent.is_empty():
		lines.append("  nothing was logged this session")
	for line: String in recent:
		lines.append("  %s" % line)
	return "\n".join(lines)


## Writes the report and every kept log file into one `.zip` under
## [param folder], and answers the path it wrote.
##
## A zip rather than the log itself because the useful thing is the whole set:
## the session that crashed is usually the file *before* the one this launch is
## writing. An empty [param folder] takes the platform's downloads directory,
## and `user://` when there is none, which is what a phone answers.
func write_bundle(folder: String = "") -> Dictionary:
	var wanted: String = folder if not folder.is_empty() else _bundle_directory()
	var fallback: String = ProjectSettings.globalize_path("user://")
	# A downloads directory that exists is not a directory this process may
	# write to: Android hands one back that needs a permission the game never
	# asks for. The app's own directory always answers, so a refusal there is a
	# real failure and a refusal above it is not.
	var written: Dictionary = _pack_bundle(wanted)
	if not bool(written["ok"]) and wanted != fallback:
		written = _pack_bundle(fallback)
	return written


func _pack_bundle(directory: String) -> Dictionary:
	# The parent is tested before the directory is created rather than letting
	# the create fail: [method DirAccess.make_dir_absolute] raises an engine
	# error on its way to returning one, and this refusal is an ordinary answer
	# that the fallback above deals with. It would otherwise be the loudest line
	# in the log of a player who reported nothing.
	if not DirAccess.dir_exists_absolute(directory):
		if not DirAccess.dir_exists_absolute(directory.get_base_dir()):
			return {"ok": false, "message": "That folder could not be opened.", "path": ""}
		if DirAccess.make_dir_absolute(directory) != OK:
			return {"ok": false, "message": "That folder could not be opened.", "path": ""}
	# path_join rather than a format string: a globalized user:// already ends in
	# a separator, and the result is read off a phone screen and typed by hand.
	var path: String = directory.path_join("%s%s.zip" % [BUNDLE_PREFIX, _file_stamp()])
	var packer := ZIPPacker.new()
	if packer.open(path) != OK:
		return {"ok": false, "message": "The report file could not be created.", "path": ""}
	var written: int = 0
	if _pack(packer, "report.txt", report().to_utf8_buffer()):
		written += 1
	for file: String in log_files():
		# Empty is a length, not a failure: a session that logged nothing still
		# rotated a file, and dropping it here left `files` disagreeing with
		# what [method log_files] named.
		var full: String = "%s/%s" % [DIRECTORY, file]
		if FileAccess.file_exists(full) \
			and _pack(packer, "logs/%s" % file, FileAccess.get_file_as_bytes(full)):
			written += 1
	packer.close()
	return {"ok": true, "message": "", "path": path, "files": written}


## The kept log files, newest first, named relative to [param directory]: an
## absolute path carries the player's account name into a file they are about to
## publish. Sorted by name rather than mtime, which has one-second resolution
## while a rotation writes several files inside one second; a rotated name is the
## live one with an ISO stamp inserted, so name-descending is newest-first and the
## prune below cannot take the session it was run to preserve.
func log_files(directory: String = DIRECTORY) -> PackedStringArray:
	var live: String = String(
		ProjectSettings.get_setting("debug/file_logging/log_path", "")
	).get_file()
	var found: Array[String] = []
	for file: String in DirAccess.get_files_at(directory):
		if file.get_extension().to_lower() == "log":
			found.append(file)
	found.sort_custom(func(a: String, b: String) -> bool:
		if (a == live) != (b == live):
			return a == live
		var left: int = FileAccess.get_modified_time("%s/%s" % [directory, a])
		var right: int = FileAccess.get_modified_time("%s/%s" % [directory, b])
		return a > b if left == right else left > right
	)
	return PackedStringArray(found)


## Drops log files in [param directory] past the count, the age or the total
## size this keeps, whichever bites first, oldest first.
##
## The engine's own rotation counts files at startup and nothing else, so a
## single session that logged for a week, or a build that once wrote under
## another name, would otherwise sit in the player's data directory for good.
## Returns how many files it removed.
func prune(directory: String = DIRECTORY) -> int:
	if not DirAccess.dir_exists_absolute(directory):
		return 0
	var names: PackedStringArray = log_files(directory)
	var oldest_kept: int = int(Time.get_unix_time_from_system()) - KEEP_DAYS * 86400
	var budget: int = KEEP_BYTES
	var removed: int = 0
	for index: int in names.size():
		var path: String = "%s/%s" % [directory, names[index]]
		var size: int = _file_size(path)
		budget -= size
		var stale: bool = (
			index >= KEEP_FILES
			or budget < 0
			or FileAccess.get_modified_time(path) < oldest_kept
		)
		# The newest file is the one being written right now, so it is kept
		# whatever it costs: removing it would silently take the session the
		# player is about to report with it.
		if stale and index > 0 and DirAccess.remove_absolute(path) == OK:
			removed += 1
	return removed


## Installs the sink. Kept as a field because [Logger] is a [RefCounted] and the
## engine's list does not own it.
func _install_sink() -> void:
	_sink = Gen2DiagnosticsSink.new()
	_sink.host = self
	OS.add_logger(_sink)


## Appends to the tail, from whichever thread raised the message.
func record(level: String, message: String) -> void:
	_lock.lock()
	match level:
		"error":
			_errors += 1
		"warning":
			_warnings += 1
	_tail.append("%s %-7s %s" % [
		Time.get_time_string_from_system(), level, message.left(LINE_LIMIT)
	])
	while _tail.size() > RECENT_LINES:
		_tail.remove_at(0)
	_lock.unlock()


## Reads the previous session's marker and raises this one's.
##
## Only a player's own launch writes it. A headless check or a `-s` tool that
## the wall-clock cap kills never reaches [method _exit_tree], so letting those
## write the marker would report a crash to the player at the next launch, and
## letting them clear it would hide a real one.
func _read_marker() -> void:
	adopt_marker(FileAccess.get_file_as_string(MARKER))
	if not Gen2GameRuntime.is_player_launch():
		return
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	_write_marker(false)


## Whether [param stored] is a marker left raised. A missing or unreadable one
## answers false: an absent file is a first launch, and a half-written one is
## not evidence of a crash worth telling the player about.
static func unclean_marker(stored: String) -> bool:
	if stored.is_empty():
		return false
	# Parsed through an instance rather than [method JSON.parse_string], which
	# raises an engine error of its own: a torn marker is an ordinary answer
	# here, not something to report in the log this class keeps.
	var reader := JSON.new()
	if reader.parse(stored) != OK:
		return false
	var raw: Variant = reader.data
	return raw is Dictionary and not bool((raw as Dictionary).get("clean", true))


func _clear_marker() -> void:
	if Gen2GameRuntime.is_player_launch():
		_write_marker(true)


func _write_marker(clean: bool) -> void:
	var file: FileAccess = FileAccess.open(MARKER, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"clean": clean, "version": Gen2AppVersion.VERSION, "started": _started_unix,
	}))


## Cache state per cartridge, and no save counts: a slot count would load every
## save file to answer, which is real work at boot for a line a bug report
## almost never turns on.
func _cartridge_lines() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray(["Cartridges"])
	var runtime: Gen2GameRuntime = Gen2GameRuntime.instance()
	var selected: StringName = runtime.selected_game_id if runtime != null else &""
	for game_id: StringName in RomRegistry.ORDER:
		var sha1: String = RomRegistry.sha1_for(game_id)
		lines.append("  %-8s %-11s%s" % [
			RomRegistry.title_for(game_id),
			RomCache.state(RomCache.directory_for(game_id, sha1)),
			"  (selected)" if game_id == selected else "",
		])
	return lines


func _mod_lines() -> PackedStringArray:
	var host: Gen2ModHost = Gen2ModHost.instance()
	var running: Array = host.loaded_mods()
	var manifests: Array = host.manifests()
	var lines: PackedStringArray = PackedStringArray(["Mods  %d installed, %d running" % [
		manifests.size(), running.size(),
	]])
	for manifest: Gen2ModManifest in manifests:
		lines.append("  %-24s %-10s api %-3d %s" % [
			manifest.id, manifest.version, manifest.api_version,
			"running" if running.has(manifest.id)
			else ("on" if Gen2ModState.is_enabled(manifest.id) else "off"),
		])
	for failure: Dictionary in host.failures():
		lines.append("  refused %s: %s (%s)" % [
			failure.get("directory", failure.get("id", "?")),
			failure.get("reason", "unknown"), failure.get("detail", ""),
		])
	return lines


func _settings_lines() -> PackedStringArray:
	var options: Gen2Options = Gen2OptionsStore.current()
	var lines: PackedStringArray = PackedStringArray(["Settings"])
	lines.append("  display    %s, %d fps, zoom %d, %s, %s" % [
		options.video_mode, options.max_fps, options.zoom_step,
		"screen fill" if options.screen_fill else "framed", options.ui_theme,
	])
	lines.append("  play       speed %s, text %d, %s, touch %s" % [
		options.game_speed, options.text_speed,
		"stereo" if options.stereo else "mono", options.touch_mode,
	])
	lines.append("  volume     music %d, effects %d" % [
		options.music_volume, options.sfx_volume,
	])
	var rules: Gen2Rules = Gen2Rules.active()
	var changed: PackedStringArray = PackedStringArray()
	for flag: StringName in Gen2Rules.FLAGS:
		if rules.reproduces(flag) != bool(Gen2Rules.FLAGS[flag]):
			changed.append(String(flag))
	lines.append("  rules      %s%s" % [
		rules.mode_of(),
		"" if changed.is_empty() else ", changed: %s" % ", ".join(changed),
	])
	return lines


## The platform's downloads directory when it has one the player can reach, and
## the app's own data directory otherwise, which is what a phone answers.
func _bundle_directory() -> String:
	var downloads: String = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if not downloads.is_empty() and DirAccess.dir_exists_absolute(downloads):
		return downloads
	return ProjectSettings.globalize_path("user://")


func _pack(packer: ZIPPacker, entry: String, bytes: PackedByteArray) -> bool:
	if packer.start_file(entry) != OK:
		return false
	var ok: bool = packer.write_file(bytes) == OK
	packer.close_file()
	return ok


func _uptime() -> String:
	var seconds: int = maxi(int(Time.get_unix_time_from_system()) - _started_unix, 0)
	return "up %dh %02dm" % [seconds / 3600, (seconds / 60) % 60]


## Local time with the offset spelled out, because a report is read by someone
## in another one and a bare local stamp cannot be lined up with anything.
func _stamp() -> String:
	var offset: int = int(Time.get_time_zone_from_system().get("bias", 0))
	return "%s UTC%s%02d:%02d" % [
		Time.get_datetime_string_from_system(false, true),
		"-" if offset < 0 else "+", absi(offset) / 60, absi(offset) % 60,
	]


static func _file_stamp() -> String:
	return Time.get_datetime_string_from_system().replace(":", "-")


static func _file_size(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	return 0 if file == null else int(file.get_length())


static func _setting(key: String, fallback: String) -> String:
	return String(ProjectSettings.get_setting(key, fallback))


## Which picker [Gen2LauncherFilePicker] would present here.
static func _file_picker_kind() -> String:
	if Engine.has_singleton(Gen2LauncherFilePicker.NATIVE_SINGLETON):
		return "the system picker, through the platform plugin"
	if Gen2LauncherFilePicker.use_native_dialog_here():
		return "the system picker, through the engine"
	if DisplayServer.has_feature(DisplayServer.FEATURE_MOUSE):
		return "the engine's own browser"
	return "the launcher's own browser, opening at %s" % Gen2BrowseSheet.start_dir()


## Empty on a headless run, and on a machine whose driver never answered.
static func _video_adapter() -> String:
	var adapter: String = RenderingServer.get_video_adapter_name()
	return adapter if not adapter.is_empty() else "no adapter"


## The sink itself, kept beside the autoload rather than in a file of its own:
## it is four lines and it has no other caller.
##
## Nothing here prints. A logger that raised a message of its own would be
## handed it straight back.
class Gen2DiagnosticsSink extends Logger:
	var host: Gen2Diagnostics = null

	func _log_message(message: String, error: bool) -> void:
		if host != null and not error:
			host.record("print", message.strip_edges())

	func _log_error(
		function: String,
		file: String,
		line: int,
		code: String,
		rationale: String,
		_editor_notify: bool,
		error_type: int,
		script_backtraces: Array[ScriptBacktrace],
	) -> void:
		if host == null:
			return
		var level: String = "warning" if error_type == Logger.ERROR_TYPE_WARNING else "error"
		var said: String = rationale if not rationale.is_empty() else code
		var text: String = "%s  at %s (%s:%d)" % [said, function, file, line]
		for backtrace: ScriptBacktrace in script_backtraces:
			if not backtrace.is_empty():
				text += "\n    %s" % backtrace.format(4).strip_edges()
		host.record(level, text)
