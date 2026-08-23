extends GutTest

## The log sink, the report and the prune. Nothing here writes into the real
## log directory: the prune is driven over a scratch directory of its own, and
## the bundle is written where the test can delete it.

const SCRATCH: String = "user://diagnostics-test-bundle"


func _diagnostics() -> Gen2Diagnostics:
	var log_node: Gen2Diagnostics = Gen2Diagnostics.instance()
	assert_not_null(log_node, "the Diagnostics autoload is registered")
	return log_node


func after_each() -> void:
	if DirAccess.dir_exists_absolute(SCRATCH):
		for name: String in DirAccess.get_files_at(SCRATCH):
			DirAccess.remove_absolute("%s/%s" % [SCRATCH, name])
		DirAccess.remove_absolute(SCRATCH)


func test_the_engine_writes_a_log_file_this_can_read() -> void:
	# The sink is a mirror; the file the bundle carries is the engine's own, so
	# a build that turned file logging off would ship a report with no logs in
	# it and nothing else would say so.
	assert_true(
		bool(ProjectSettings.get_setting("debug/file_logging/enable_file_logging", false)),
		"file logging is on",
	)
	assert_eq(
		String(ProjectSettings.get_setting("debug/file_logging/log_path", "")).get_base_dir(),
		Gen2Diagnostics.DIRECTORY,
	)


func test_a_print_reaches_the_tail() -> void:
	var log_node: Gen2Diagnostics = _diagnostics()
	Gen2Diagnostics.note("test", "a line nothing else writes")
	var tail: PackedStringArray = log_node.tail()
	assert_gt(tail.size(), 0)
	assert_string_contains(tail[tail.size() - 1], "[test] a line nothing else writes")


func test_a_pushed_warning_is_counted_and_kept() -> void:
	var log_node: Gen2Diagnostics = _diagnostics()
	var warnings: int = log_node.warning_count()
	var errors: int = log_node.error_count()
	push_warning("diagnostics test warning")
	assert_eq(log_node.warning_count(), warnings + 1)
	assert_eq(log_node.error_count(), errors, "and a warning is not counted as one")
	var tail: PackedStringArray = log_node.tail()
	assert_string_contains(tail[tail.size() - 1], "diagnostics test warning")
	assert_string_contains(tail[tail.size() - 1], "warning")


func test_the_tail_is_bounded() -> void:
	var log_node: Gen2Diagnostics = _diagnostics()
	for index: int in Gen2Diagnostics.RECENT_LINES + 20:
		Gen2Diagnostics.note("test", "line %d" % index)
	assert_eq(log_node.tail().size(), Gen2Diagnostics.RECENT_LINES)


func test_one_enormous_message_cannot_fill_the_report() -> void:
	var log_node: Gen2Diagnostics = _diagnostics()
	Gen2Diagnostics.note("test", "x".repeat(Gen2Diagnostics.LINE_LIMIT * 4))
	var tail: PackedStringArray = log_node.tail()
	assert_lt(tail[tail.size() - 1].length(), Gen2Diagnostics.LINE_LIMIT + 64)


func test_the_summary_names_the_build_the_machine_and_every_mod() -> void:
	var summary: String = _diagnostics().summary()
	assert_string_contains(summary, Gen2AppVersion.VERSION)
	assert_string_contains(summary, OS.get_distribution_name())
	assert_string_contains(summary, "Cartridges")
	assert_string_contains(summary, "Settings")
	for game_id: StringName in RomRegistry.ORDER:
		assert_string_contains(summary, RomRegistry.title_for(game_id))
	for manifest: Gen2ModManifest in Gen2ModHost.instance().manifests():
		assert_string_contains(summary, String(manifest.id))


## What the player pastes into a chat is the summary, so it must not carry the
## home directory their account is named after.
func test_the_summary_carries_no_absolute_path() -> void:
	var home: String = ProjectSettings.globalize_path("user://")
	assert_false(_diagnostics().summary().contains(home))


func test_the_report_quotes_the_log_tail() -> void:
	Gen2Diagnostics.note("test", "a line the report should quote")
	var report: String = _diagnostics().report()
	assert_string_contains(report, "Recent log")
	assert_string_contains(report, "a line the report should quote")


func test_the_bundle_holds_the_report_and_the_log_files() -> void:
	var expected: int = _diagnostics().log_files().size()
	var written: Dictionary = _diagnostics().write_bundle(
		ProjectSettings.globalize_path(SCRATCH)
	)
	assert_true(bool(written["ok"]), String(written["message"]))
	var path: String = String(written["path"])
	assert_true(FileAccess.file_exists(path))

	var reader := ZIPReader.new()
	assert_eq(reader.open(path), OK)
	var names: PackedStringArray = reader.get_files()
	assert_true(names.has("report.txt"))
	assert_string_contains(reader.read_file("report.txt").get_string_from_utf8(), "pokerecomp")
	var logs: int = 0
	for name: String in names:
		# The reader lists the folder itself as an entry too.
		if name.begins_with("logs/") and not name.ends_with("/"):
			logs += 1
	assert_eq(logs, expected, "every kept log file is packed")
	reader.close()


## A downloads directory a phone hands back is not always one the game may
## write to. Refusing there is not a failure the player should be shown.
func test_a_folder_that_refuses_falls_back_to_the_app_directory() -> void:
	# A directory under a file, which no platform will create.
	var refused: String = "%s/inside-a-file" % ProjectSettings.globalize_path(
		Gen2OptionsStore.path()
	)
	var written: Dictionary = _diagnostics().write_bundle(refused)
	assert_true(bool(written["ok"]), String(written["message"]))
	var path: String = String(written["path"])
	assert_true(path.begins_with(ProjectSettings.globalize_path("user://")))
	assert_true(FileAccess.file_exists(path))
	DirAccess.remove_absolute(path)


func test_the_prune_keeps_the_newest_files_and_drops_the_rest() -> void:
	DirAccess.make_dir_recursive_absolute(SCRATCH)
	var wanted: int = Gen2Diagnostics.KEEP_FILES + 6
	for index: int in wanted:
		var file: FileAccess = FileAccess.open(
			"%s/godot%03d.log" % [SCRATCH, index], FileAccess.WRITE
		)
		file.store_string("line %d" % index)
		file = null
	# A file the prune must not touch, because a bundle only carries `.log`.
	var marker: FileAccess = FileAccess.open("%s/keep.json" % SCRATCH, FileAccess.WRITE)
	marker.store_string("{}")
	marker = null

	var removed: int = _diagnostics().prune(SCRATCH)
	assert_eq(removed, wanted - Gen2Diagnostics.KEEP_FILES)
	assert_eq(_diagnostics().log_files(SCRATCH).size(), Gen2Diagnostics.KEEP_FILES)
	assert_true(FileAccess.file_exists("%s/keep.json" % SCRATCH))


func test_the_prune_never_takes_the_file_being_written() -> void:
	DirAccess.make_dir_recursive_absolute(SCRATCH)
	var live: String = String(
		ProjectSettings.get_setting("debug/file_logging/log_path", "")
	).get_file()
	var file: FileAccess = FileAccess.open("%s/%s" % [SCRATCH, live], FileAccess.WRITE)
	# One file over every budget at once. It is still the newest, so it stays:
	# taking it would drop the very session the player is about to report.
	file.store_string("x".repeat(Gen2Diagnostics.KEEP_BYTES + 1))
	file = null
	assert_eq(_diagnostics().prune(SCRATCH), 0)
	assert_eq(_diagnostics().log_files(SCRATCH).size(), 1)


## The rotation writes several files inside one second, so the order has to
## come from somewhere other than the modification time. A run that got this
## wrong deleted whichever file the sort happened to put last, the live one
## included.
func test_files_written_in_the_same_second_still_order_newest_first() -> void:
	DirAccess.make_dir_recursive_absolute(SCRATCH)
	var live: String = String(
		ProjectSettings.get_setting("debug/file_logging/log_path", "")
	).get_file()
	var stem: String = live.get_basename()
	for name: String in [
		"%s2026-08-01T00.00.03.log" % stem,
		"%s2026-08-01T00.00.01.log" % stem,
		live,
		"%s2026-08-01T00.00.02.log" % stem,
	]:
		var file: FileAccess = FileAccess.open("%s/%s" % [SCRATCH, name], FileAccess.WRITE)
		file.store_string("x")
		file = null
	var order: PackedStringArray = _diagnostics().log_files(SCRATCH)
	assert_eq(order[0], live)
	assert_string_contains(order[1], "00.00.03")
	assert_string_contains(order[3], "00.00.01")


## The marker is what tells a crash from a quit. A player never sees it, so it
## is checked here rather than through the launcher's notice.
func test_the_marker_reads_a_crash_and_nothing_else() -> void:
	assert_true(Gen2Diagnostics.unclean_marker('{"clean": false}'))
	assert_false(Gen2Diagnostics.unclean_marker('{"clean": true}'))
	assert_false(Gen2Diagnostics.unclean_marker(""), "a first launch is not a crash")
	assert_false(Gen2Diagnostics.unclean_marker("{ half writ"), "nor is a torn file")
