extends GutTest

## Everything a release is published from. Two things go wrong here silently:
## a development tree reaching a distributable pack, and metadata drifting apart
## between the places a store reads it. Both are audited across every preset, so
## adding a platform cannot quietly restore example mods or skip a version.

const PRESETS: String = "res://export_presets.cfg"
const ALTSTORE_SOURCE: String = "res://.github/altstore/source.json"
const RELEASE_NOTES: String = "res://.github/release-notes.md"

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


## Four files name the engine, and a release mixes two engines the moment they
## disagree: the templates come from one commit and the iOS plugin linked into
## them from another. The 4.8.dev4 bump left `release.yml` behind by itself.
func test_every_file_that_names_the_engine_names_the_same_one() -> void:
	var templates: String = FileAccess.get_file_as_string(
		"res://.github/workflows/export-templates.yml"
	)
	var release: String = FileAccess.get_file_as_string("res://.github/workflows/release.yml")
	var ci: String = FileAccess.get_file_as_string("res://.github/workflows/ci.yml")
	var android: String = FileAccess.get_file_as_string("res://tools/build_android_plugin.sh")
	var readme: String = FileAccess.get_file_as_string("res://README.md")
	var tag: String = _engine_pin(templates, "GODOT_VERSION")
	var commit: String = _engine_pin(templates, "GODOT_COMMIT")
	# The tag and the directory the templates unpack into differ by one
	# character, which is what `release.yml` says and DEVICES.md repeats.
	var directory: String = tag.replace("-", ".")
	assert_ne(tag, "", "export-templates.yml names a Godot release")
	assert_ne(commit, "", "export-templates.yml names a Godot commit")
	assert_eq(_engine_pin(release, "GODOT_VERSION"), tag)
	assert_eq(_engine_pin(release, "GODOT_COMMIT"), commit)
	assert_eq(_engine_pin(release, "GODOT_TEMPLATE_DIR"), directory)
	assert_eq(_engine_pin(ci, "GODOT_VERSION"), tag)
	assert_string_contains(android, 'GODOT_TAG="${GODOT_TAG:-%s}"' % tag)
	assert_string_contains(
		android, 'GODOT_LIB_VERSION="${GODOT_LIB_VERSION:-%s}"' % directory
	)
	assert_string_contains(readme, "Godot-%s-" % directory)


## One `key: value` from a workflow's own `env:` block, which is two spaces in.
static func _engine_pin(workflow: String, key: String) -> String:
	for line: String in workflow.split("\n"):
		if line.begins_with("  %s: " % key):
			return line.split(": ", true, 1)[1].strip_edges()
	return ""


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


## The AltStore feed is generated by `tools/altstore_source.sh` and read by a
## store rather than by anything here, so nothing else notices when the preset
## it describes moves under it.
func test_the_altstore_source_describes_the_ios_preset() -> void:
	var text: String = FileAccess.get_file_as_string(ALTSTORE_SOURCE)
	assert_ne(text, "", "%s is readable" % ALTSTORE_SOURCE)
	var source: Dictionary = JSON.parse_string(text)
	assert_not_null(source, "%s parses" % ALTSTORE_SOURCE)
	var file: ConfigFile = _presets()
	var bundle: String = String(file.get_value("preset.4.options", "application/bundle_identifier", ""))
	var minimum: String = String(file.get_value("preset.4.options", "application/min_ios_version", ""))
	var app: Dictionary = source["apps"][0]
	assert_eq(String(app["bundleIdentifier"]), bundle, "the listed bundle is the one exported")
	var versions: Array = app["versions"]
	assert_gt(versions.size(), 0, "the source lists a version")
	assert_eq(String(app["version"]), String(versions[0]["version"]),
		"the app-level copy an older client reads is the newest version")
	for version: Dictionary in versions:
		assert_eq(String(version["minOSVersion"]), minimum,
			"%s asks for the iOS the preset builds for" % version["version"])
		assert_string_contains(String(version["downloadURL"]),
			"/releases/download/v%s/" % version["version"], "the download is that release's own")
		assert_gt(int(version["size"]), 0, "%s carries its byte count" % version["version"])


## `.github/workflows/release.yml`'s own `sed '/^<!--/,/-->$/d'`, which is what
## the published body is. The editing note names `## Added` in its own prose, so
## a rewrite that starts from the first one in the file lands inside the note and
## takes its closing marker with it; the range then runs to the end and the whole
## file renders as nothing. 0.1.17 published an empty body that way and 0.1.18
## spent a seven-target build finding out, so the contract is a test now.
static func _rendered_notes() -> PackedStringArray:
	var out := PackedStringArray()
	var dropping: bool = false
	for line: String in FileAccess.get_file_as_string(RELEASE_NOTES).split("\n"):
		if dropping:
			dropping = not line.strip_edges().ends_with("-->")
			continue
		if line.begins_with("<!--"):
			dropping = not line.strip_edges().ends_with("-->")
			continue
		out.append(line)
	while out.size() > 0 and out[0].strip_edges().is_empty():
		out.remove_at(0)
	return out


func test_the_release_notes_render_to_a_body_that_opens_on_a_section() -> void:
	var body: PackedStringArray = _rendered_notes()
	assert_gt(body.size(), 0, "the release notes render to nothing")
	if body.size() > 0:
		assert_true(body[0].begins_with("## "), "the body opens on %s" % body[0])
	var sections: int = 0
	for line: String in body:
		if line.begins_with("## "):
			sections += 1
	assert_gt(sections, 0, "the body carries no section")


func test_the_release_notes_editing_note_is_opened_once_and_closed() -> void:
	var opens: int = 0
	var closes: int = 0
	for line: String in FileAccess.get_file_as_string(RELEASE_NOTES).split("\n"):
		if line.begins_with("<!--"):
			opens += 1
		if line.strip_edges().ends_with("-->"):
			closes += 1
	assert_eq(opens, 1, "one editing note")
	assert_eq(closes, opens, "every editing note is closed")


## The one punctuation `CLAUDE.md` forbids outright, checked where a body is
## written rather than left to a reader.
func test_the_release_notes_carry_no_em_dash() -> void:
	assert_false(
		FileAccess.get_file_as_string(RELEASE_NOTES).contains(char(0x2014)),
		"the release notes carry an em dash"
	)
