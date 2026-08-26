extends GutTest

## Version rules and release parsing only. Nothing here touches the network:
## the launcher owns the request and hands the result to `status_for`.


func test_the_project_declares_a_version() -> void:
	assert_false(Gen2UpdateCheck.current_version().is_empty())
	assert_false(Gen2UpdateCheck.parse_version(Gen2UpdateCheck.current_version()).is_empty())
	assert_eq(Gen2UpdateCheck.current_version(), Gen2AppVersion.VERSION)
	assert_string_contains(Gen2AppVersion.display(), Gen2AppVersion.CHANNEL)


func test_a_tag_may_carry_a_leading_v() -> void:
	assert_eq(Gen2UpdateCheck.parse_version("v1.2.3"), [1, 2, 3] as Array[int])
	assert_eq(Gen2UpdateCheck.parse_version("1.2.3"), [1, 2, 3] as Array[int])


func test_a_prerelease_or_build_suffix_is_cut() -> void:
	assert_eq(Gen2UpdateCheck.parse_version("1.2.3-beta.1"), [1, 2, 3] as Array[int])
	assert_eq(Gen2UpdateCheck.parse_version("1.2.3+build7"), [1, 2, 3] as Array[int])


func test_a_version_without_numbers_parses_empty() -> void:
	assert_eq(Gen2UpdateCheck.parse_version("nightly"), [] as Array[int])


func test_missing_components_count_as_zero() -> void:
	assert_eq(Gen2UpdateCheck.compare_versions("1.2", "1.2.0"), 0)
	assert_eq(Gen2UpdateCheck.compare_versions("1.2", "1.2.1"), -1)


func test_versions_order_by_component_not_by_text() -> void:
	assert_eq(Gen2UpdateCheck.compare_versions("0.9.0", "0.10.0"), -1)
	assert_eq(Gen2UpdateCheck.compare_versions("1.0.0", "0.99.99"), 1)
	assert_eq(Gen2UpdateCheck.compare_versions("2.0.0", "2.0.0"), 0)


func test_a_release_document_reads_into_display_fields() -> void:
	var release: Dictionary = Gen2UpdateCheck.parse_release(JSON.stringify({
		"tag_name": "v0.2.0",
		"name": "Second release",
		"html_url": "https://github.com/Decryptu/pokerecomp/releases/tag/v0.2.0",
		"published_at": "2026-08-08T10:00:00Z",
	}))

	assert_true(release["ok"])
	assert_eq(release["version"], "v0.2.0")
	assert_eq(release["name"], "Second release")
	assert_string_contains(release["url"], "releases/tag/v0.2.0")


func test_a_release_url_that_is_not_https_falls_back_to_the_releases_page() -> void:
	var release: Dictionary = Gen2UpdateCheck.parse_release(JSON.stringify({
		"tag_name": "0.2.0", "html_url": "http://example.invalid/tricked",
	}))

	assert_true(release["ok"])
	assert_eq(release["url"], Gen2UpdateCheck.RELEASES_PAGE)


func test_a_release_without_a_usable_tag_is_refused() -> void:
	assert_false(Gen2UpdateCheck.parse_release(JSON.stringify({"name": "no tag"}))["ok"])
	assert_false(Gen2UpdateCheck.parse_release(JSON.stringify({"tag_name": "nightly"}))["ok"])


func test_unreadable_json_is_refused() -> void:
	assert_false(Gen2UpdateCheck.parse_release("{ not json")["ok"])


func test_a_newer_release_reports_an_update() -> void:
	var body: String = JSON.stringify({"tag_name": "v0.2.0"})
	var result: Dictionary = Gen2UpdateCheck.status_for(200, body, "0.1.0")

	assert_eq(result["status"], Gen2UpdateCheck.Status.UPDATE_AVAILABLE)
	assert_string_contains(Gen2UpdateCheck.describe(result), "0.2.0")


func test_the_same_release_reports_up_to_date() -> void:
	var body: String = JSON.stringify({"tag_name": "v0.1.0"})
	var result: Dictionary = Gen2UpdateCheck.status_for(200, body, "0.1.0")

	assert_eq(result["status"], Gen2UpdateCheck.Status.UP_TO_DATE)


func test_a_local_build_ahead_of_the_release_says_so() -> void:
	var body: String = JSON.stringify({"tag_name": "v0.1.0"})
	var result: Dictionary = Gen2UpdateCheck.status_for(200, body, "0.2.0")

	assert_eq(result["status"], Gen2UpdateCheck.Status.AHEAD)


## GitHub answers 404 for a repository that has published nothing. The check
## worked; there is simply nothing to compare against.
func test_a_repository_with_no_releases_is_an_answer_not_a_failure() -> void:
	var result: Dictionary = Gen2UpdateCheck.status_for(404, "", "0.1.0")

	assert_eq(result["status"], Gen2UpdateCheck.Status.NO_RELEASES)
	assert_string_contains(Gen2UpdateCheck.describe(result), "0.1.0")


func test_any_other_http_code_is_unreadable() -> void:
	assert_eq(
		Gen2UpdateCheck.status_for(503, "", "0.1.0")["status"],
		Gen2UpdateCheck.Status.UNREADABLE,
	)


func test_a_two_hundred_with_a_damaged_body_is_unreadable() -> void:
	assert_eq(
		Gen2UpdateCheck.status_for(200, "{ not json", "0.1.0")["status"],
		Gen2UpdateCheck.Status.UNREADABLE,
	)


func test_an_oversized_response_is_refused_before_parsing() -> void:
	var huge: String = "x".repeat(Gen2UpdateCheck.MAX_RESPONSE_BYTES + 1)
	assert_false(Gen2UpdateCheck.parse_release(huge)["ok"])


## The release metadata below is stated once per export target and read by
## stores, not by this code, so nothing else can notice it drifting. A release
## whose presets disagree with [Gen2AppVersion] ships builds the update check
## then calls newer or older than themselves.

const PRESETS: String = "res://export_presets.cfg"

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


## Android refuses an in-place update whose version code did not rise, so the
## code is a function of the version rather than a number bumped by hand.
func test_the_android_version_code_derives_from_the_app_version() -> void:
	var parts: Array[int] = Gen2UpdateCheck.parse_version(Gen2AppVersion.VERSION)
	assert_eq(parts.size(), 3, "the app version is major.minor.patch")
	var expected: int = parts[0] * 10000 + parts[1] * 100 + parts[2]
	assert_eq(int(_presets().get_value("preset.3.options", "version/code", 0)), expected)


## An Apple team id names a personal developer account. The release IPA is
## unsigned and needs none; a device build pastes one in and never commits it.
func test_the_ios_preset_carries_no_signing_identity() -> void:
	assert_eq(String(_presets().get_value("preset.4.options",
		"application/app_store_team_id", "")), "")
