extends GutTest

## Everything a release is published from. Two things go wrong here silently:
## a development tree reaching a distributable pack, and metadata drifting apart
## between the places a store reads it. Both are audited across every preset, so
## adding a platform cannot quietly restore example mods or skip a version.

const PRESETS: String = "res://export_presets.cfg"

## Preset names `.github/workflows/release.yml` exports by. Renaming one in the
## editor would leave the workflow asking for a preset that is not there, and
## the failure would arrive on a tag rather than on a pull request.
const PUBLISHED: Array[String] = [
	"Windows Desktop", "macOS", "Linux", "Android", "iOS",
	"Linux ARM64", "Windows Desktop ARM64",
]

## Preset section to the option keys under it that must equal the app version.
const VERSION_KEYS: Dictionary = {
	"preset.1.options": ["application/short_version", "application/version"],
	"preset.3.options": ["version/name"],
	"preset.4.options": ["application/short_version", "application/version"],
}


func _presets() -> ConfigFile:
	var file := ConfigFile.new()
	assert_eq(file.load(PRESETS), OK, "export_presets.cfg must parse")
	return file


func test_every_export_preset_excludes_tests_tools_and_repository_mods() -> void:
	var text: String = FileAccess.get_file_as_string(PRESETS)
	var current: String = ""
	for line: String in text.split("\n"):
		if line.begins_with("[preset.") and not line.contains(".options]"):
			current = line
			continue
		if not line.begins_with("exclude_filter="):
			continue
		assert_ne(current, "", "an exclusion belongs to a preset")
		for excluded: String in ["tests/*", "tools/*", "addons/gut/*", "mods/*"]:
			assert_string_contains(line, excluded, "preset %s excludes %s" % [current, excluded])


func test_the_published_presets_are_all_present_and_named_as_the_release_asks() -> void:
	var file: ConfigFile = _presets()
	var found: Array[String] = []
	for section: String in file.get_sections():
		if section.ends_with(".options"):
			continue
		found.append(String(file.get_value(section, "name", "")))
	found.sort()
	var expected: Array[String] = PUBLISHED.duplicate()
	expected.sort()
	assert_eq(found, expected)


## A desktop download is one file. An executable published beside a separate
## `.pck` is a download a player can take half of and then report as broken.
func test_every_desktop_preset_embeds_its_pack() -> void:
	var file: ConfigFile = _presets()
	for section: String in file.get_sections():
		if not file.has_section_key(section, "binary_format/embed_pck"):
			continue
		assert_true(bool(file.get_value(section, "binary_format/embed_pck")), section)


func test_every_export_preset_states_the_app_version() -> void:
	var file: ConfigFile = _presets()
	for section: String in VERSION_KEYS:
		for key: String in VERSION_KEYS[section]:
			assert_eq(
				String(file.get_value(section, key, "")),
				Gen2AppVersion.VERSION,
				"%s/%s" % [section, key]
			)


func test_the_project_settings_state_the_app_version() -> void:
	assert_eq(String(ProjectSettings.get_setting("application/config/version", "")),
		Gen2AppVersion.VERSION)


func test_a_published_release_is_announced_without_committing_the_webhook() -> void:
	var workflow: String = FileAccess.get_file_as_string("res://.github/workflows/release.yml")
	assert_string_contains(workflow, "secrets.DISCORD_RELEASE_WEBHOOK")
	assert_string_contains(workflow, "github.repository }}/releases/tag/")
	assert_false(workflow.contains("discord.com/api/webhooks/"), "the credential stays in secrets")


## Android refuses an in-place update whose version code did not rise, so the
## code is a function of the version rather than a number bumped by hand.
func test_the_android_version_code_derives_from_the_app_version() -> void:
	var parts: Array[int] = Gen2UpdateCheck.parse_version(Gen2AppVersion.VERSION)
	assert_eq(parts.size(), 3, "the app version is major.minor.patch")
	var expected: int = parts[0] * 10000 + parts[1] * 100 + parts[2]
	assert_eq(int(_presets().get_value("preset.3.options", "version/code", 0)), expected)


## The one Android permission this app asks for, and the only one it may.
## Nothing here reaches a player's files: a cartridge and a mod archive both
## arrive through the system picker, which grants the one file chosen. The
## engine adds INTERNET on its own only for a remote-debug build, so a release
## without this key has no network at all: no update check, no mod source, no
## icon. 0.1.0 shipped that way.
func test_the_android_preset_asks_for_the_network_and_nothing_else() -> void:
	var file: ConfigFile = _presets()
	assert_true(bool(file.get_value("preset.3.options", "permissions/internet", false)))
	assert_eq(
		Array(file.get_value("preset.3.options", "permissions/custom_permissions",
			PackedStringArray())),
		[],
	)
	for key: String in file.get_section_keys("preset.3.options"):
		if not key.begins_with("permissions/") or key.ends_with("custom_permissions"):
			continue
		assert_eq(key, "permissions/internet", "%s is asked for and must not be" % key)


## An Apple team id names a personal developer account and this repository is
## public. The release IPA is unsigned and needs none; a device build pastes one
## in and does not commit it.
func test_the_ios_preset_carries_no_signing_identity() -> void:
	assert_eq(String(_presets().get_value("preset.4.options",
		"application/app_store_team_id", "")), "")


## Directories no preset ships, so a heavy import under one costs a player
## nothing. `addons/gut/` is the only third-party tree with imported art in it.
const NOT_SHIPPED: Array[String] = [
	"res://tests/", "res://tools/", "res://addons/gut/", "res://artifacts/",
	"res://mods/", "res://roms/",
]

## Below this an import's fixed overhead dominates and a ratio means nothing.
const AUDITED_FROM_BYTES: int = 32 * 1024

## What an import may cost over its own source. Godot's default texture mode is
## lossless, and re-encoding an already-lossy source losslessly is what this
## catches: three cartridge photographs of 140 KiB each once reached the pack as
## 1.2 MiB apiece, which was two thirds of everything the player downloaded.
const MOST_TIMES_ITS_SOURCE: float = 4.0


func _shipped_imports(from: String, into: Array[String]) -> void:
	for entry: String in DirAccess.get_directories_at(from):
		var sub: String = from.path_join(entry) + "/"
		if entry.begins_with(".") or NOT_SHIPPED.has(sub):
			continue
		_shipped_imports(sub.trim_suffix("/"), into)
	for entry: String in DirAccess.get_files_at(from):
		if entry.ends_with(".import"):
			into.append(from.path_join(entry))


## Swept over every source the presets ship rather than over the four files that
## went wrong, because the next one will be a different four.
func test_no_imported_asset_costs_much_more_than_its_own_source() -> void:
	var imports: Array[String] = []
	_shipped_imports("res://", imports)
	assert_gt(imports.size(), 0, "the sweep found something to audit")
	var audited: int = 0
	for import_path: String in imports:
		var source: String = import_path.trim_suffix(".import")
		var config := ConfigFile.new()
		if config.load(import_path) != OK:
			continue
		var imported: String = String(config.get_value("remap", "path", ""))
		if imported.is_empty() or not FileAccess.file_exists(imported):
			continue
		var source_bytes: int = _bytes(source)
		if source_bytes < AUDITED_FROM_BYTES:
			continue
		audited += 1
		var ratio: float = float(_bytes(imported)) / float(source_bytes)
		assert_lt(ratio, MOST_TIMES_ITS_SOURCE,
			"%s imports to %.2f times its %d bytes" % [source, ratio, source_bytes])
	assert_gt(audited, 0, "the sweep audited something over the floor")


func _bytes(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	return 0 if file == null else int(file.get_length())
