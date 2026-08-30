extends GutTest

## Launcher tests use the real scene and synthetic rejected files. They never
## import a cartridge or create cartridge-derived data.

var _launcher: Control = null
var _scratch_path: String = "user://launcher-test-small.gbc"
var _mod_archive: String = "user://launcher-test-mod.zip"
var _view_archive: String = "user://launcher-test-view-mod.zip"

## The launcher installs into the real user://mods, so a mod test cleans up
## after itself whether or not it got that far.
const PROBE_MOD_ID: StringName = &"launcher_probe"
## The renderer-registering probe has an id of its own because Godot caches a
## loaded script by path: two mods sharing a directory would have the first
## one's entry script run for the second.
const VIEW_MOD_ID: StringName = &"launcher_view_probe"
## The sources these tests follow. Unfollowed after each one, or a test that
## fails part way leaves the next one reading a feed it never added.
const PROBE_FEEDS: Array[String] = [
	"https://mods.example.com/update-all.json",
	"https://mods.example.com/update-queue.json",
]


func after_each() -> void:
	if is_instance_valid(_launcher):
		_launcher.free()
	_launcher = null
	# A palette change rebuilds the launcher by detaching the old shell and
	# queueing it, so freeing the root leaves that one pending until a frame
	# runs the deletion queue.
	await get_tree().process_frame
	DirAccess.remove_absolute(_scratch_path)
	DirAccess.remove_absolute(_mod_archive)
	DirAccess.remove_absolute(_view_archive)
	Gen2ModInstaller.uninstall(PROBE_MOD_ID)
	Gen2ModInstaller.uninstall(VIEW_MOD_ID)
	for feed: String in PROBE_FEEDS:
		Gen2ModIndex.unfollow(feed)
	for game_id: StringName in RomRegistry.ORDER:
		Gen2CartridgeArt.revert(game_id)
	_clear_art_scratch()


## The mods page on its own, which is what every mod workflow but the file
## picker lives on. Built outside the launcher because none of it needs one.
func _mods_page() -> Gen2ModsPage:
	var page: Gen2ModsPage = Gen2ModsPage.create(Gen2LauncherTheme.active())
	add_child_autofree(page)
	return page


## Every page built here would otherwise read the project's own index the moment
## it entered the tree, and then an icon per row: a runner's user:// is empty, so
## a warm cache never hides it and the suite makes a live request per page. Seven
## are built. What a player pressed still reaches the network in any run.
func test_a_page_fetches_on_its_own_only_for_a_player() -> void:
	var loose: Gen2ModsPage = autofree(Gen2ModsPage.create(Gen2LauncherTheme.active()))
	assert_false(loose._may_fetch_unprompted(), "a page off the tree asks for nothing")

	var page: Gen2ModsPage = _mods_page()
	assert_eq(
		page._may_fetch_unprompted(),
		Gen2GameRuntime.is_player_launch(),
		"in the tree, the launch kind is the whole gate"
	)


func _open_launcher() -> void:
	# The machine running the tests may itself have crashed last, and the notice
	# that raises is a toast every other launcher test would then have to
	# tolerate. Each test says for itself what the previous session did.
	var diagnostics: Gen2Diagnostics = Gen2Diagnostics.instance()
	if diagnostics != null:
		diagnostics.adopt_marker("")
	var packed: PackedScene = load("res://game/main/main.tscn")
	_launcher = packed.instantiate()
	add_child(_launcher)
	await get_tree().process_frame


func test_launcher_lists_every_supported_game() -> void:
	await _open_launcher()
	var snapshot: Dictionary = _launcher.launcher_snapshot()
	var games: Dictionary = snapshot["games"]

	assert_eq(games.size(), RomRegistry.ORDER.size())
	for game_id: StringName in RomRegistry.ORDER:
		var row: Dictionary = games[String(game_id)]
		assert_eq(row["title"], RomRegistry.title_for(game_id))
		assert_true(row["imported"] is bool)
		assert_false(row["selected"])


func test_launcher_opens_on_the_shelf_and_moves_between_its_pages() -> void:
	await _open_launcher()
	assert_eq(_launcher.launcher_snapshot()["page"], "shelf")
	for page: String in ["mods", "settings", "about", "shelf"]:
		_launcher.select_page(StringName(page))
		assert_eq(_launcher.launcher_snapshot()["page"], page)
	# An unknown id leaves the current page alone rather than blanking it.
	_launcher.select_page(&"nowhere")
	assert_eq(_launcher.launcher_snapshot()["page"], "shelf")


func test_switching_appearance_rebuilds_the_launcher_and_keeps_its_status() -> void:
	await _open_launcher()
	var before: Dictionary = _launcher.launcher_snapshot()
	# Whichever appearance this machine's options file holds. Naming one would
	# assert the tester's own preference rather than the switch.
	var opened := StringName(before["theme"])
	assert_true(Gen2LauncherTheme.MODES.has(opened), String(opened))

	var wanted: StringName = Gen2LauncherTheme.for_mode(opened).other_mode()
	_launcher.preview_theme(wanted)
	var after: Dictionary = _launcher.launcher_snapshot()
	assert_eq(after["theme"], String(wanted))
	# The shelf is rebuilt whole, so the message on it has to be carried over.
	assert_eq(after["status"], before["status"])
	assert_eq(after["detail"], before["detail"])
	assert_eq(after["page"], before["page"])


func test_launcher_reports_a_rejected_rom_without_importing() -> void:
	await _open_launcher()
	var file: FileAccess = FileAccess.open(_scratch_path, FileAccess.WRITE)
	var bytes := PackedByteArray()
	bytes.resize(1024)
	file.store_buffer(bytes)
	file.close()

	await _launcher.import_rom_path(_scratch_path)
	var snapshot: Dictionary = _launcher.launcher_snapshot()

	assert_eq(snapshot["status"], "Import stopped.")
	assert_string_contains(snapshot["detail"], "bytes")
	assert_false(snapshot["importing"])


func test_runtime_selection_accepts_registry_games_and_rejects_unknown_ids() -> void:
	var previous: StringName = GameRuntime.selected_game_id
	var previous_slot: int = GameRuntime.selected_save_slot

	assert_true(GameRuntime.select_game(RomRegistry.CRYSTAL))
	assert_eq(GameRuntime.selected_game_id, RomRegistry.CRYSTAL)
	assert_true(GameRuntime.select_save_slot(RomRegistry.CRYSTAL, 1))
	assert_true(GameRuntime.has_selected_save_slot())
	assert_eq(GameRuntime.selected_save_slot, 1)
	assert_false(GameRuntime.select_game(&"not_a_game"))
	assert_eq(GameRuntime.selected_game_id, RomRegistry.CRYSTAL)
	assert_false(GameRuntime.select_save_slot(RomRegistry.CRYSTAL, Gen2SaveStore.MAX_SLOTS))
	assert_eq(GameRuntime.selected_save_slot, 1)

	GameRuntime.selected_game_id = previous
	GameRuntime.selected_save_slot = previous_slot
	GameRuntime.reload_selected_save()


func test_the_selected_save_is_one_shared_instance_until_the_selection_changes() -> void:
	var previous: StringName = GameRuntime.selected_game_id
	var previous_slot: int = GameRuntime.selected_save_slot
	var data: GameData = GameData.open_any()
	if data == null:
		pass_test("No imported cache on this machine.")
		return

	assert_true(GameRuntime.select_save_slot(data.id, 0))
	var save: Gen2SaveData = GameRuntime.selected_save()
	if save == null:
		pass_test("Slot 0 of the imported cache is empty.")
	else:
		# Two readers must see one save, or a party change made by a battle is
		# invisible to whoever writes the world snapshot.
		assert_same(save, GameRuntime.selected_save())
		GameRuntime.reload_selected_save()
		assert_not_same(save, GameRuntime.selected_save())

	GameRuntime.selected_game_id = previous
	GameRuntime.selected_save_slot = previous_slot
	GameRuntime.reload_selected_save()


## The backdrop is heard as well as seen, at half the app block's music volume,
## and it stops with the picture rather than playing on behind another page.
func test_the_title_backdrop_plays_the_title_music_and_stops_with_the_picture() -> void:
	var data: GameData = GameData.open_any()
	if data == null:
		pass_test("No imported cache on this machine.")
		return
	var backdrop := Gen2LauncherTitleBackdrop.new()
	add_child_autofree(backdrop)
	if backdrop.show_game(data) == null:
		pass_test("This cache carries no title-screen art.")
		return

	var audio: Gen2AudioPlayer = null
	for child: Node in backdrop.get_children():
		if child is Gen2AudioPlayer:
			audio = child
	assert_not_null(audio, "the backdrop built a driver")
	if audio == null:
		return
	assert_almost_eq(audio.volume_scale, Gen2LauncherTitleBackdrop.VOLUME_SCALE, 0.001)
	assert_true(bool(audio.audio_status()["music_active"]), "the title piece started")

	backdrop.hide_backdrop()
	assert_false(bool(audio.audio_status()["music_active"]), "and it stops with it")


## Leaving the shelf and coming back is the whole cycle: the picture and the
## music both come back with the page, without the player touching the list.
func test_the_backdrop_music_comes_back_with_the_shelf() -> void:
	if GameData.open_any() == null:
		pass_test("No imported cache on this machine.")
		return
	await _open_launcher()
	var shell: Gen2LauncherShell = _launcher.get("_shell")
	var backdrop: Gen2LauncherTitleBackdrop = _launcher.get("_title_backdrop")
	if backdrop.get_child_count() == 0:
		pass_test("No cartridge is seated on this machine.")
		return
	assert_true(_music_active(backdrop), "the shelf started it")

	shell.select(&"settings")
	await get_tree().process_frame
	assert_false(_music_active(backdrop), "another page stops it")

	shell.select(&"shelf")
	await get_tree().process_frame
	assert_true(_music_active(backdrop), "and coming back starts it again")

	# The picture being up is the whole condition: a piece stopped underneath is
	# started again on the next frame the backdrop draws, whatever stopped it.
	for child: Node in backdrop.get_children():
		if child is Gen2AudioPlayer:
			(child as Gen2AudioPlayer).stop_all()
	assert_false(_music_active(backdrop))
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(_music_active(backdrop), "the backdrop holds its own music")


func _music_active(backdrop: Gen2LauncherTitleBackdrop) -> bool:
	for child: Node in backdrop.get_children():
		if child is Gen2AudioPlayer:
			return bool((child as Gen2AudioPlayer).audio_status()["music_active"])
	return false


func _write_probe_mod_zip() -> void:
	var packer := ZIPPacker.new()
	assert_eq(packer.open(_mod_archive), OK)
	var files: Dictionary = {
		"%s/mod.json" % PROBE_MOD_ID: JSON.stringify({
			"id": String(PROBE_MOD_ID), "name": "Launcher Probe", "version": "1.0.0",
			"api_version": Gen2ModManifest.API_VERSION, "entry": "mod.gd",
		}),
		"%s/mod.gd" % PROBE_MOD_ID:
			"extends RefCounted\n\nfunc register(_h, _m) -> void:\n\tpass\n",
	}
	for entry: String in files:
		packer.start_file(entry)
		packer.write_file(String(files[entry]).to_utf8_buffer())
		packer.close_file()
	packer.close()


func test_launcher_installs_a_mod_zip_and_lists_it_without_a_restart() -> void:
	await _open_launcher()
	_write_probe_mod_zip()

	var result: Dictionary = _launcher.import_mod_path(_mod_archive)
	assert_true(result["ok"], JSON.stringify(result))
	assert_eq(result["id"], PROBE_MOD_ID)
	# Loaded into the live host, not merely written to disk.
	assert_true(Gen2ModHost.instance().manifests().any(
		func(manifest: Gen2ModManifest) -> bool: return manifest.id == PROBE_MOD_ID
	))
	assert_string_contains(_launcher.launcher_snapshot()["status"], "Launcher Probe")


func test_launcher_reports_a_file_that_is_not_a_mod_archive() -> void:
	await _open_launcher()
	var file: FileAccess = FileAccess.open(_mod_archive, FileAccess.WRITE)
	file.store_string("not an archive")
	file.close()

	var result: Dictionary = _launcher.import_mod_path(_mod_archive)
	assert_false(result["ok"])
	assert_eq(result["reason"], &"not_a_zip")
	var snapshot: Dictionary = _launcher.launcher_snapshot()
	assert_eq(snapshot["status"], "That mod was not installed.")
	assert_string_contains(snapshot["detail"], "not a .zip archive")


func test_index_install_requires_the_download_to_be_the_listed_mod() -> void:
	_write_probe_mod_zip()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(_mod_archive)
	var page: Gen2ModsPage = _mods_page()

	# A source offering one mod cannot deliver another.
	var wrong: Dictionary = page.install_entry_bytes(
		{"id": &"something_else", "name": "Something Else"}, bytes
	)
	assert_false(wrong["ok"])
	assert_eq(wrong["reason"], &"unexpected_mod_id")
	assert_string_contains(page.status_text(), "different mod")

	var right: Dictionary = page.install_entry_bytes(
		{"id": PROBE_MOD_ID, "name": "Launcher Probe"}, bytes
	)
	assert_true(right["ok"], JSON.stringify(right))
	assert_eq(right["id"], PROBE_MOD_ID)
	assert_string_contains(page.status_text(), "Installed")


## A server that is down costs the freshness of a listing rather than the
## listing: the last feed that parsed is kept and shown, with the player told
## which copy they are looking at.
func test_a_source_that_cannot_be_read_falls_back_to_the_copy_on_disk() -> void:
	var feed: String = "https://mods.example.com/index.json"
	var page: Gen2ModsPage = _mods_page()

	var text: String = JSON.stringify({
		"schema_version": Gen2ModIndex.SCHEMA_VERSION,
		"name": "Example",
		"mods": [{"id": "voxel", "name": "Voxel", "version": "1.2.0",
			"download": "https://example.com/voxel.zip"}],
	})
	assert_true(bool(page.receive_feed_response(feed, true, text).get("ok", false)))
	assert_string_contains(page.status_text(), "lists 1 mod")

	page.receive_feed_response(feed, false, "", "That source could not be read (HTTP 503).")
	assert_string_contains(page.status_text(), "Showing the copy saved")

	# A fetch that arrives as something other than a feed is the same answer.
	page.receive_feed_response(feed, true, "not json")
	assert_string_contains(page.status_text(), "Showing the copy saved")

	Gen2ModIndex.forget_cache(feed)
	page.receive_feed_response(feed, false, "", "That source could not be read (HTTP 503).")
	assert_string_contains(page.status_text(), "HTTP 503")
	assert_false(page.status_text().contains("Showing the copy"))


## A listing offering a newer version than the one installed says so, and the
## count of them is on the status line.
func test_a_source_names_the_mods_a_newer_version_is_listed_for() -> void:
	_write_probe_mod_zip()
	var installed: Dictionary = Gen2ModInstaller.install_zip(_mod_archive)
	assert_true(bool(installed.get("ok", false)), JSON.stringify(installed))
	Gen2ModHost.reset()
	Gen2ModHost.instance().discover()

	var feed: String = "https://mods.example.com/updates.json"
	var page: Gen2ModsPage = _mods_page()
	page.receive_feed_response(feed, true, JSON.stringify({
		"schema_version": Gen2ModIndex.SCHEMA_VERSION,
		"name": "Example",
		"mods": [{"id": String(PROBE_MOD_ID), "name": "Launcher Probe", "version": "9.9.9",
			"download": "https://example.com/probe.zip"}],
	}))
	assert_string_contains(page.status_text(), "1 can be updated")

	# The same listing at the installed version offers a reinstall and no update.
	page.receive_feed_response(feed, true, JSON.stringify({
		"schema_version": Gen2ModIndex.SCHEMA_VERSION,
		"name": "Example",
		"mods": [{"id": String(PROBE_MOD_ID), "name": "Launcher Probe",
			"version": String(installed["version"]),
			"download": "https://example.com/probe.zip"}],
	}))
	assert_false(page.status_text().contains("can be updated"))
	Gen2ModIndex.forget_cache(feed)


## The header carries one button and it offers whichever of its two actions is
## worth pressing: read the sources while nothing is known to be out of date, and
## download every update once something is.
func test_the_header_button_offers_update_all_once_a_source_lists_one() -> void:
	_write_probe_mod_zip()
	assert_true(bool(Gen2ModInstaller.install_zip(_mod_archive).get("ok", false)))
	Gen2ModHost.reset()
	Gen2ModHost.instance().discover()

	var feed: String = PROBE_FEEDS[0]
	assert_true(bool(Gen2ModIndex.follow(feed).get("ok", false)))
	var page: Gen2ModsPage = _mods_page()
	var button: Gen2LauncherButton = page._check_updates_button
	assert_eq(button.get("_glyph"), &"refresh_square", "nothing to update yet")

	page.receive_feed_response(feed, true, JSON.stringify({
		"schema_version": Gen2ModIndex.SCHEMA_VERSION,
		"name": "Example",
		"mods": [{"id": String(PROBE_MOD_ID), "name": "Launcher Probe", "version": "9.9.9",
			"download": "https://example.com/probe.zip"}],
	}))
	assert_eq(page.available_update_count(), 1)
	assert_eq(button.get("_glyph"), &"download", "the same button is now Update all")
	assert_eq(button.text, "", "and it is still icon sized for a phone")
	assert_string_contains(button.tooltip_text, "1 mod update")
	assert_eq(
		StringName((page.update_rows()[0] as Dictionary)["id"]), PROBE_MOD_ID,
		"one press is the installed mods a source has something newer for"
	)


## Update all walks its queue whatever each row answers, and a row whose download
## never starts is the refusal a single press of that row would give.
func test_update_all_walks_its_queue_and_reports_what_it_installed() -> void:
	_write_probe_mod_zip()
	assert_true(bool(Gen2ModInstaller.install_zip(_mod_archive).get("ok", false)))
	Gen2ModHost.reset()
	Gen2ModHost.instance().discover()

	var feed: String = PROBE_FEEDS[1]
	assert_true(bool(Gen2ModIndex.follow(feed).get("ok", false)))
	var page: Gen2ModsPage = _mods_page()
	page.receive_feed_response(feed, true, JSON.stringify({
		"schema_version": Gen2ModIndex.SCHEMA_VERSION,
		"name": "Example",
		"mods": [{"id": String(PROBE_MOD_ID), "name": "Launcher Probe", "version": "9.9.9",
			"download": "https://example.com/probe.zip"}],
	}))
	assert_eq(page.available_update_count(), 1)

	# No test reaches a server, so the transport is taken away: every row then
	# answers the way one whose download could not be started does.
	page._http = null
	page.download_all()
	for _frame: int in 4:
		await get_tree().process_frame
	assert_eq(page._update_queue.size(), 0, "the queue is drained rather than stuck")
	assert_string_contains(page.status_text(), "No mod update could be installed")
	assert_false(page._check_updates_button.disabled, "and the button is pressable again")


## A toast with nothing to say occupies nothing: not drawn, and not in the hit
## test either.
func test_a_silent_toast_is_not_on_screen_at_all() -> void:
	await _open_launcher()
	var toast: Gen2LauncherToast = _find_toast(_launcher)
	assert_not_null(toast)

	assert_false(toast.visible, "an empty toast is gone rather than transparent")
	toast.show_message(&"error", "Something", "happened")
	assert_true(toast.visible)


## The toast is drawn over the bottom centre of every launcher page, which is
## where the shelf puts Play and the cache button, so a card that stopped the
## mouse left both of them dead. Its dismiss button is the one exception, and it
## is only there on a message that would otherwise stay up forever.
func test_only_a_toasts_dismiss_button_takes_a_click_from_what_is_under_it() -> void:
	await _open_launcher()
	var toast: Gen2LauncherToast = _find_toast(_launcher)

	toast.show_message(&"error", "Something", "happened")
	await get_tree().process_frame
	var stopping: Array[String] = []
	_mouse_stoppers(toast, stopping)
	assert_eq(stopping.size(), 1, "a refusal offers a way out and nothing else")

	# An import ends itself, so offering to hide it would be offering to cancel
	# something this cannot; information goes on its own.
	for kind: StringName in [&"busy", &"info", &"success"]:
		toast.show_message(kind, "Something", "happened")
		await get_tree().process_frame
		var others: Array[String] = []
		_mouse_stoppers(toast, others)
		assert_eq(others, [] as Array[String], "nothing is clickable on a %s toast" % kind)

	toast.hide_message()
	await get_tree().process_frame
	var hidden: Array[String] = []
	_mouse_stoppers(toast, hidden)
	assert_eq(hidden, [] as Array[String], "and a toast that has gone takes nothing at all")


## Every control in [param node]'s subtree that would actually take a press,
## which is one that stops the mouse and is on screen to be pressed.
func _mouse_stoppers(node: Node, out: Array[String]) -> void:
	if (
		node is Control
		and (node as Control).mouse_filter == Control.MOUSE_FILTER_STOP
		and (node as Control).is_visible_in_tree()
	):
		out.append("%s %s" % [node.get_class(), node.name])
	for child: Node in node.get_children():
		_mouse_stoppers(child, out)


func _find_toast(node: Node) -> Gen2LauncherToast:
	if node is Gen2LauncherToast:
		return node
	for child: Node in node.get_children():
		var found: Gen2LauncherToast = _find_toast(child)
		if found != null:
			return found
	return null


## There is no cache migration by design, so the one thing the launcher owes a
## player whose cache a build has outgrown is a sentence saying which of the
## four states it is in and that the dump is wanted again.
func test_every_cache_state_says_something_different() -> void:
	var main := preload("res://game/main/main.gd")
	var said: Dictionary = {}
	for state: StringName in [
		RomCache.STATE_USABLE, RomCache.STATE_STALE,
		RomCache.STATE_INCOMPLETE, RomCache.STATE_MISSING,
	]:
		var text: String = main.cache_state_text(state)
		assert_false(text.is_empty(), "%s says nothing" % state)
		assert_false(said.has(text), "%s repeats another state's line" % state)
		said[text] = true
	for state: StringName in [RomCache.STATE_STALE, RomCache.STATE_INCOMPLETE]:
		assert_true(
			main.cache_state_text(state).contains("Import the cartridge again"),
			"%s asks for the dump" % state
		)


## A mod archive whose entry registers a renderer of each kind, for the view
## switch below: the same id on both is what says the two are one view.
func _write_view_mod_zip() -> void:
	var packer := ZIPPacker.new()
	assert_eq(packer.open(_view_archive), OK)
	var files: Dictionary = {
		"%s/mod.json" % VIEW_MOD_ID: JSON.stringify({
			"id": String(VIEW_MOD_ID), "name": "Launcher View Probe", "version": "1.0.0",
			"api_version": Gen2ModManifest.API_VERSION, "entry": "mod.gd",
		}),
		"%s/world.gd" % VIEW_MOD_ID: """extends Node2D
func set_world(_world, _animation = null) -> void:
	pass
func set_time_of_day(_time_of_day: int) -> void:
	pass
func refresh() -> void:
	pass
func refresh_animation() -> void:
	pass
""",
		"%s/battle.gd" % VIEW_MOD_ID: """extends Node2D
func set_battle_data(_data) -> bool:
	return true
func set_view(_view: Dictionary) -> void:
	pass
func refresh() -> void:
	pass
""",
		"%s/mod.gd" % VIEW_MOD_ID: """extends RefCounted

func register(host, manifest) -> void:
	host.register_world_renderer(
		manifest.id, load("%s/world.gd" % manifest.directory), "Probe"
	)
	host.register_battle_renderer(
		manifest.id, load("%s/battle.gd" % manifest.directory), "Probe"
	)
""",
	}
	for entry: String in files:
		packer.start_file(entry)
		packer.write_file(String(files[entry]).to_utf8_buffer())
		packer.close_file()
	packer.close()


## The view is chosen from the mod's own page, which is the whole point of the
## row: a release build has no debug keys, so `V` cannot be the only way in.
## One switch covers both surfaces and turning it off returns to the built-in
## view.
func test_a_mod_registering_renderers_is_switched_on_from_its_own_page() -> void:
	_write_view_mod_zip()
	assert_true(bool(Gen2ModInstaller.install_zip(_view_archive).get("ok", false)))
	Gen2ModHost.reset()
	var host: Gen2ModHost = Gen2ModHost.instance()
	host.discover()
	assert_true(host.load_discovered().has(VIEW_MOD_ID))

	var page: Gen2ModsPage = _mods_page()
	var row: Dictionary = page._row_for(VIEW_MOD_ID)
	assert_false(row.is_empty(), "the installed mod is in the catalogue")
	var detail: Gen2ModDetailPage = Gen2ModDetailPage.create(Gen2LauncherTheme.active())
	add_child_autofree(detail)
	detail.set_row(row)

	var switch: Gen2LauncherToggle = detail.find_child(
		String(Gen2ModDetailPage.VIEW_SWITCH_NAME), true, false
	)
	assert_not_null(switch, "a mod that registered a renderer gets a view switch")
	assert_false(switch.button_pressed, "and starts on the built-in view")

	switch.button_pressed = true
	assert_eq(host.selected_view(), VIEW_MOD_ID)
	assert_eq(host.selected_world_renderer(), VIEW_MOD_ID)
	assert_eq(host.selected_battle_renderer(), VIEW_MOD_ID)
	assert_eq(
		Gen2ModState.selected_view(), VIEW_MOD_ID, "and the choice is on disk"
	)

	## set_row rebuilt the card, so the switch that is up now is a new node.
	var again: Gen2LauncherToggle = detail.find_child(
		String(Gen2ModDetailPage.VIEW_SWITCH_NAME), true, false
	)
	assert_true(again.button_pressed, "the rebuilt row shows the view as on")
	again.button_pressed = false
	assert_eq(host.selected_view(), Gen2ModHost.BUILT_IN_RENDERER)

	Gen2ModHost.reset()
	DirAccess.remove_absolute(Gen2ModState.PATH)
	Gen2ModState.reload()


## A 390pt window leaves a mod's name about eleven characters wide beside its
## toggle, bin and chevron, which trimmed every name on the page.
func test_a_narrow_mods_page_gives_a_row_its_controls_a_line_of_their_own() -> void:
	_write_probe_mod_zip()
	assert_true(bool(Gen2ModInstaller.install_zip(_mod_archive).get("ok", false)))
	Gen2ModHost.reset()
	Gen2ModHost.instance().discover()
	Gen2ModHost.instance().load_discovered()

	var page: Gen2ModsPage = _mods_page()
	assert_eq(_card_lines(page), 1, "a wide window keeps the row on one line")
	page.set_compact(true)
	assert_eq(_card_lines(page), 2, "a narrow one gives the controls their own")
	page.set_compact(false)
	assert_eq(_card_lines(page), 1, "and takes it back when there is room")
	Gen2ModHost.reset()


## How many lines the first mod card is stacked into.
func _card_lines(page: Gen2ModsPage) -> int:
	for card: Node in page.find_children("", "Gen2LauncherCard", true, false):
		for child: Node in card.get_children():
			if child is VBoxContainer:
				return (child as VBoxContainer).get_child_count()
	return 0


## Only a run on the device can say why the Switch build dims its page and draws
## no toast, so the launcher can say what it built (`HANDOFF.md`).
func test_the_shell_can_report_what_it_layered() -> void:
	await _open_launcher()
	var shell: Gen2LauncherShell = _launcher.get("_shell")
	assert_not_null(shell)
	var line: String = shell.layer_report("test")
	assert_string_contains(line, "veil", "the report names the sheet over the artwork")
	assert_string_contains(line, "toast", "and whether the toast is on screen")
	assert_false(line.contains("not built"), "a launcher that is up has both")


## A mod that replaces nothing about how the game is drawn gets no row at all,
## rather than a switch that would do nothing.
func test_a_mod_with_no_renderer_has_no_view_switch() -> void:
	_write_probe_mod_zip()
	assert_true(bool(Gen2ModInstaller.install_zip(_mod_archive).get("ok", false)))
	Gen2ModHost.reset()
	Gen2ModHost.instance().discover()
	Gen2ModHost.instance().load_discovered()

	var page: Gen2ModsPage = _mods_page()
	var detail: Gen2ModDetailPage = Gen2ModDetailPage.create(Gen2LauncherTheme.active())
	add_child_autofree(detail)
	detail.set_row(page._row_for(PROBE_MOD_ID))
	assert_null(detail.find_child(String(Gen2ModDetailPage.VIEW_SWITCH_NAME), true, false))
	Gen2ModHost.reset()


## A palette change rebuilds the launcher whole and replays whatever it was
## saying. Replayed as information, a failure lost its warning glyph and picked
## up the dismissal timer the toast withholds from an error on purpose.
func test_a_failure_survives_a_rebuild_as_a_failure() -> void:
	await _open_launcher()
	_launcher.import_mod_path("user://no-such-mod.zip")
	assert_eq(_launcher.launcher_snapshot()["kind"], "error")

	_launcher.preview_theme(&"dark")
	await get_tree().process_frame
	var snapshot: Dictionary = _launcher.launcher_snapshot()
	assert_eq(snapshot["kind"], "error")
	assert_eq(snapshot["status"], "That mod was not installed.")


## A crash the player never saw a message about is a crash they cannot report.
func test_a_crashed_session_is_reported_at_the_next_launch() -> void:
	await _open_launcher()
	Gen2Diagnostics.instance().adopt_marker('{"clean": false}')
	await _open_launcher_keeping_the_marker()
	var snapshot: Dictionary = _launcher.launcher_snapshot()
	assert_eq(snapshot["kind"], "error")
	assert_string_contains(String(snapshot["status"]), "ended unexpectedly")
	assert_false(
		Gen2Diagnostics.instance().previous_session_crashed(),
		"and it is said once, not again on every rebuild",
	)


## A wide window is not a short one. The band above the carousel used to be
## given up on a flat 600 px of stage height, which sent the button to the top
## right corner of a 1920x600 window where the cartridge still had 130 px to
## spare underneath it.
func test_the_cartridge_options_button_only_leaves_the_carousel_when_the_stage_is_short() -> void:
	var desktop: float = Gen2LauncherButton.DOCK_SIDE + Gen2LauncherUI.GAP_LG
	var touch: float = Gen2LauncherUI.TOUCH_TARGET + Gen2LauncherUI.GAP_LG
	for stage: Vector2 in [Vector2(1860, 539), Vector2(2340, 559), Vector2(1220, 739)]:
		assert_false(
			Gen2ShelfPage.corners_manage(stage, desktop),
			"a %s stage has the room" % stage,
		)
	assert_false(Gen2ShelfPage.corners_manage(Vector2(812, 335), touch), "a phone held over")
	# Tall is never cornered, whatever the band costs: the button is above the
	# carousel on every portrait window and that is where a thumb expects it.
	assert_false(Gen2ShelfPage.corners_manage(Vector2(390, 700), touch))
	# Short enough that the band would come out of the cartridge rather than out
	# of the space around it.
	assert_true(Gen2ShelfPage.corners_manage(Vector2(1240, 240), touch))
	assert_true(Gen2ShelfPage.corners_manage(Vector2(1240, 300), desktop))


func _open_launcher_keeping_the_marker() -> void:
	if is_instance_valid(_launcher):
		_launcher.free()
	_launcher = (load("res://game/main/main.tscn") as PackedScene).instantiate()
	add_child(_launcher)
	await get_tree().process_frame


## Godot reports no power state on any platform, so the indicator is only ever
## drawn once a probe of this project's own has answered. A machine with no
## battery must show nothing rather than a full cell that is not true.
func test_the_charge_indicator_is_hidden_until_a_probe_answers() -> void:
	var battery: Gen2LauncherBattery = Gen2LauncherBattery.create(Gen2LauncherTheme.active())
	add_child_autofree(battery)
	battery._apply({})
	assert_false(battery.reading_available(), "no reading, no indicator")

	battery.set_level(64)
	assert_true(battery.reading_available())
	assert_eq(battery.level, 64)
	assert_false(battery.charging)

	battery.set_level(200, true)
	assert_eq(battery.level, Gen2LauncherBattery.FULL, "a percentage is clamped")
	assert_true(battery.charging)
	battery._apply({})
	assert_false(battery.reading_available(), "and it goes away again")


## The one line every macOS reading is parsed out of. `pmset` prints a header
## with no percentage in it when the machine has no battery at all.
func test_the_macos_reading_is_the_number_in_front_of_the_percent_sign() -> void:
	assert_eq(
		Gen2LauncherBattery._percent_before_sign(
			" -InternalBattery-0 (id=22151267)\t89%; discharging; 9:51 remaining"
		),
		89,
	)
	assert_eq(Gen2LauncherBattery._percent_before_sign("Now drawing from 'AC Power'"), -1)
	assert_eq(Gen2LauncherBattery._percent_before_sign("%"), -1, "and never a bare sign")
	assert_eq(Gen2LauncherBattery._percent_before_sign("120%"), Gen2LauncherBattery.FULL)


## Every platform this project ships to either has a probe or draws nothing.
## The two singleton platforms answer nothing on a desktop, which is what keeps
## a missing plugin from being read as a flat battery.
func test_only_the_platforms_with_a_probe_shell_out() -> void:
	assert_true(Gen2LauncherBattery._probe_plugin().is_empty(), "no singleton here")
	assert_eq(
		Gen2LauncherBattery._shells_out(), OS.get_name() in ["macOS", "Windows"],
		"a process is launched for those two and nothing else",
	)


## Android's Back on the launcher. It quit the app outright before, from any page
## and over any sheet; it now closes what is open, walks back to the shelf, and
## only asks about quitting on a bare shelf.
func test_back_closes_what_is_open_before_it_asks_about_quitting() -> void:
	await _open_launcher()
	var shell: Gen2LauncherShell = _launcher.get("_shell")

	_launcher.select_page(&"about")
	_launcher.call("_on_back_requested")
	assert_eq(shell.current_page(), &"shelf", "a page other than the shelf is the way back")

	_launcher.call("_confirm_quit")
	await get_tree().process_frame
	assert_eq(_sheet_count(), 1, "a bare shelf asks first")
	_launcher.call("_on_back_requested")
	await get_tree().process_frame
	assert_eq(_sheet_count(), 0, "and a second Back is the cancel on that question")


## The sheets open over the launcher, innermost last.
func _sheet_count() -> int:
	return _launcher.find_children("", "Gen2LauncherSheet", true, false).size()


## The scratch directory the art store is exercised in, so a run never writes a
## picture onto one of this machine's own cartridges. The one test that has to
## use the real root reverts it in `after_each`.
const ART_SCRATCH: String = "user://cartridge_art_tests"


func _clear_art_scratch() -> void:
	var listing: PackedStringArray = DirAccess.get_files_at(ART_SCRATCH)
	for entry: String in listing:
		DirAccess.remove_absolute("%s/%s" % [ART_SCRATCH, entry])
	DirAccess.remove_absolute(ART_SCRATCH)


func _write_image(path: String, width: int, height: int) -> String:
	var image: Image = Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color.REBECCA_PURPLE)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	return path


## What is stored is a picture this project encoded, not the file that was
## chosen, and it is never larger than the shell it stands in for.
func test_chosen_cartridge_art_is_re_encoded_and_fitted_to_the_shell() -> void:
	var source: String = _write_image("%s/source.png" % ART_SCRATCH, 3000, 1500)
	assert_false(Gen2CartridgeArt.has_custom_art(&"gold", ART_SCRATCH))

	var taken: Dictionary = Gen2CartridgeArt.adopt(&"gold", source, ART_SCRATCH)
	assert_true(bool(taken.get("ok", false)), JSON.stringify(taken))
	assert_true(Gen2CartridgeArt.has_custom_art(&"gold", ART_SCRATCH))

	var texture: Texture2D = Gen2CartridgeArt.texture_for(&"gold", ART_SCRATCH)
	assert_not_null(texture)
	assert_eq(texture.get_size().x, float(Gen2CartridgeArt.STORED_SIDE), "the long side")
	assert_eq(texture.get_size().y, float(Gen2CartridgeArt.STORED_SIDE / 2), "aspect kept")

	## Smaller than the shell is left where it is: a 32x32 sprite is drawn small
	## rather than smeared over a cartridge.
	assert_true(bool(Gen2CartridgeArt.adopt(
		&"gold", _write_image("%s/small.png" % ART_SCRATCH, 32, 48), ART_SCRATCH
	).get("ok", false)))
	assert_eq(
		Gen2CartridgeArt.texture_for(&"gold", ART_SCRATCH).get_size(), Vector2(32, 48),
		"and the texture is the new picture rather than the cached first one"
	)

	assert_true(Gen2CartridgeArt.revert(&"gold", ART_SCRATCH))
	assert_false(Gen2CartridgeArt.has_custom_art(&"gold", ART_SCRATCH))
	assert_null(Gen2CartridgeArt.texture_for(&"gold", ART_SCRATCH))
	assert_false(Gen2CartridgeArt.revert(&"gold", ART_SCRATCH), "nothing left to remove")


## Every way a chosen file can be refused, each with a sentence rather than an
## error: the file is the player's own and the launcher has to say why.
func test_a_file_that_is_not_cartridge_art_is_refused_with_a_reason() -> void:
	DirAccess.make_dir_recursive_absolute(ART_SCRATCH)
	var text: String = "%s/notes.txt" % ART_SCRATCH
	var file: FileAccess = FileAccess.open(text, FileAccess.WRITE)
	file.store_string("PNG? no.")
	file.close()

	var rows: Array = [
		[&"unknown_cartridge", Gen2CartridgeArt.adopt(&"", text, ART_SCRATCH)],
		[&"missing_file", Gen2CartridgeArt.adopt(&"gold", "%s/nope.png" % ART_SCRATCH, ART_SCRATCH)],
		[&"not_an_image", Gen2CartridgeArt.adopt(&"gold", text, ART_SCRATCH)],
	]
	for row: Array in rows:
		var answer: Dictionary = row[1]
		assert_false(bool(answer.get("ok", false)), String(row[0]))
		assert_eq(StringName(answer["reason"]), StringName(row[0]))
		assert_false(Gen2CartridgeArt.refusal_text(row[0]).is_empty(), String(row[0]))
	assert_false(Gen2CartridgeArt.has_custom_art(&"gold", ART_SCRATCH), "and nothing was stored")


## The cartridge draws the player's picture where it has one and the shipped
## shell where it has not, contained inside the shell's own box whatever shape
## the picture is.
func test_a_cartridge_wears_the_players_own_art_and_goes_back_to_the_default() -> void:
	var card: Gen2Cartridge = autofree(
		Gen2Cartridge.create(Gen2LauncherTheme.active(), &"gold")
	)
	var art: TextureRect = card.get("_art")
	assert_eq(art.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "contained, not stretched")
	assert_eq(art.texture, Gen2Cartridge.ART[&"gold"], "the shipped shell")

	assert_true(bool(Gen2CartridgeArt.adopt(
		&"gold", _write_image("%s/mine.png" % ART_SCRATCH, 700, 300)
	).get("ok", false)))
	card.refresh_art()
	assert_ne(art.texture, Gen2Cartridge.ART[&"gold"], "the player\'s own")

	Gen2CartridgeArt.revert(&"gold")
	card.refresh_art()
	assert_eq(art.texture, Gen2Cartridge.ART[&"gold"])
