class_name Gen2Diagnostics
extends Node


## Must match the engine log path in `project.godot`.
const DIRECTORY: String = "user://logs"
const MARKER: String = "user://logs/session.json"

## Engine rotation bounds file count, not age or total size.
const KEEP_FILES: int = 10
const KEEP_DAYS: int = 30
const KEEP_BYTES: int = 8 << 20

const RECENT_LINES: int = 200
const LINE_LIMIT: int = 1000

const BUNDLE_PREFIX: String = "pokerecomp-report-"

## `-s` scripts compile before autoload globals exist.
static var _instance: Gen2Diagnostics = null

var _sink: Gen2DiagnosticsSink = null
## Logger callbacks also run on resource-loader threads.
var _lock: Mutex = Mutex.new()
var _tail: PackedStringArray = PackedStringArray()
var _errors: int = 0
var _warnings: int = 0
var _started_unix: int = 0
var _previous_unclean: bool = false
var _scene_path: String = ""


static func instance() -> Gen2Diagnostics:
	if _instance == null:
		var loop: SceneTree = Engine.get_main_loop() as SceneTree
		if loop != null:
			_instance = loop.root.get_node_or_null(^"Diagnostics") as Gen2Diagnostics
	return _instance


## Safe before the autoload exists; `print` reaches the engine log.
static func note(topic: String, message: String) -> void:
	print("[%s] %s" % [topic, message])


## Skip trace output in tools that load thousands of maps.
static func trace(topic: String, message: String) -> void:
	if Gen2GameRuntime.is_player_launch():
		note(topic, message)


func _ready() -> void:
	_started_unix = int(Time.get_unix_time_from_system())
	prune()
	_read_marker()
	_install_sink()
	# Install the sink first; print the header after mods load.
	_print_header.call_deferred()


## Printing puts the header into the engine crash log.
func _print_header() -> void:
	if Gen2GameRuntime.is_player_launch():
		print(summary())


func _exit_tree() -> void:
	_clear_marker()
	if _sink != null:
		OS.remove_logger(_sink)
		_sink = null


## `current_scene` has no change signal.
func _process(_delta: float) -> void:
	var scene: Node = get_tree().current_scene
	var path: String = scene.scene_file_path if scene != null else ""
	if path == _scene_path:
		return
	_scene_path = path
	if not path.is_empty():
		trace("screen", path)


func previous_session_crashed() -> bool:
	return _previous_unclean


func adopt_marker(stored: String) -> void:
	_previous_unclean = unclean_marker(stored)


## Launcher rebuilds must not replay the crash notice.
func forget_previous_crash() -> void:
	_previous_unclean = false


func error_count() -> int:
	return _errors


func warning_count() -> int:
	return _warnings


func tail() -> PackedStringArray:
	_lock.lock()
	var out: PackedStringArray = _tail.duplicate()
	_lock.unlock()
	return out


func summary() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("pokerecomp diagnostics")
	lines.append("Generated  %s" % _stamp())
	lines.append("Build      %s, Godot %s, %s" % [
		PokeAppVersion.display(),
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


func report() -> String:
	var lines: PackedStringArray = PackedStringArray([summary(), "", "Recent log"])
	var recent: PackedStringArray = tail()
	if recent.is_empty():
		lines.append("  nothing was logged this session")
	for line: String in recent:
		lines.append("  %s" % line)
	return "\n".join(lines)


## A crash log may be the rotated file before the current one.
func write_bundle(folder: String = "") -> Dictionary:
	var wanted: String = folder if not folder.is_empty() else _bundle_directory()
	var fallback: String = ProjectSettings.globalize_path("user://")
	# Android can report an unwritable Downloads directory.
	var written: Dictionary = _pack_bundle(wanted)
	if not bool(written["ok"]) and wanted != fallback:
		written = _pack_bundle(fallback)
	return written


func _pack_bundle(directory: String) -> Dictionary:
	# A failed `make_dir_absolute` logs an engine error before returning.
	if not DirAccess.dir_exists_absolute(directory):
		if not DirAccess.dir_exists_absolute(directory.get_base_dir()):
			return {"ok": false, "message": "That folder could not be opened.", "path": ""}
		if DirAccess.make_dir_absolute(directory) != OK:
			return {"ok": false, "message": "That folder could not be opened.", "path": ""}
	var path: String = directory.path_join("%s%s.zip" % [BUNDLE_PREFIX, _file_stamp()])
	var packer := ZIPPacker.new()
	if packer.open(path) != OK:
		return {"ok": false, "message": "The report file could not be created.", "path": ""}
	var written: int = 0
	if _pack(packer, "report.txt", report().to_utf8_buffer()):
		written += 1
	for file: String in log_files():
		# Empty rotated logs still belong in the bundle.
		var full: String = "%s/%s" % [DIRECTORY, file]
		if FileAccess.file_exists(full) \
			and _pack(packer, "logs/%s" % file, FileAccess.get_file_as_bytes(full)):
			written += 1
	packer.close()
	return {"ok": true, "message": "", "path": path, "files": written}


## Name sorting distinguishes rotations within one second; relative names omit account paths.
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


## Engine rotation does not limit log age or total size.
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
		# The newest file may still be open for writing.
		if stale and index > 0 and DirAccess.remove_absolute(path) == OK:
			removed += 1
	return removed


## The engine does not own the RefCounted logger.
func _install_sink() -> void:
	_sink = Gen2DiagnosticsSink.new()
	_sink.host = self
	OS.add_logger(_sink)


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


## Headless tools must not raise or clear a player crash marker when their process is killed.
func _read_marker() -> void:
	adopt_marker(FileAccess.get_file_as_string(MARKER))
	if not Gen2GameRuntime.is_player_launch():
		return
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	_write_marker(false)


## Missing or unreadable markers are not evidence of a crash.
static func unclean_marker(stored: String) -> bool:
	if stored.is_empty():
		return false
	# `JSON.parse_string` logs an engine error for a torn marker.
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
		"clean": clean, "version": PokeAppVersion.VERSION, "started": _started_unix,
	}))


## Counting saves would load every slot at boot.
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
	for manifest: PokeModManifest in manifests:
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


## Include the offset so reports from different time zones can be aligned.
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


static func _file_picker_kind() -> String:
	if Engine.has_singleton(Gen2LauncherFilePicker.NATIVE_SINGLETON):
		return "the system picker, through the platform plugin"
	if Gen2LauncherFilePicker.use_native_dialog_here():
		return "the system picker, through the engine"
	if DisplayServer.has_feature(DisplayServer.FEATURE_MOUSE):
		return "the engine's own browser"
	return "the launcher's own browser, opening at %s" % Gen2BrowseSheet.start_dir()


static func _video_adapter() -> String:
	var adapter: String = RenderingServer.get_video_adapter_name()
	return adapter if not adapter.is_empty() else "no adapter"


## The sink must not print: it would receive its own message.
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
