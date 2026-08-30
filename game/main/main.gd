extends Control

## The launcher: a shelf of cartridges, plus the mods, settings and about pages
## reachable from the dock under it.
##
## It owns presentation and workflow, while the ROM and cache layers remain
## responsible for verification and decoding. Everything it draws is built in
## code from [Gen2LauncherShell] and the cards under it, so changing the
## appearance is a rebuild rather than a repaint.

## How often the cartridge import hands the loop a frame back. Long enough that
## the frames cost the import very little, short enough to read as motion.
const IMPORT_YIELD_MS: int = 80

## Shelf label and sheet sentence per cache state, in the player's words: a cache
## is never migrated ([constant RomCache.FORMAT_VERSION]) and is asked for again.
const CACHE_STATE_COPY: Dictionary = {
	RomCache.STATE_USABLE: ["", "This cartridge is imported and verified."],
	RomCache.STATE_STALE: [
		"Update needed",
		"This version reads cartridges differently. Import your file again to play.",
	],
	RomCache.STATE_INCOMPLETE: [
		"Import unfinished",
		"The last import stopped early. Import your file again to play.",
	],
	RomCache.STATE_MISSING: ["", "No cartridge file has been imported yet."],
}

## Said beside both lines that ask for a file again, which read as "start again".
const SAVES_ARE_SAFE: String = "Your saved games are not affected."

var _palette: Gen2LauncherTheme = null
var _shell: Gen2LauncherShell = null
var _shelf: Gen2ShelfPage = null
var _mods: Gen2ModsPage = null
var _settings: Gen2SettingsPage = null
var _about: Gen2AboutPage = null
var _title_backdrop: Gen2LauncherTitleBackdrop = null

var _file_dialog: Gen2LauncherFilePicker = null
var _mod_dialog: Gen2LauncherFilePicker = null
var _art_dialog: Gen2LauncherFilePicker = null
var _preview_browse_dir: String = ""
var _update_http: HTTPRequest = null

var _importing: bool = false
var _selected_game_id: StringName = &""
## The game a re-import is replacing, so a cache is only overwritten by a dump
## of the cartridge it already holds.
var _reimport_game_id: StringName = &""
## The cartridge whose picture the open art dialog will replace.
var _art_game_id: StringName = &""
var _status: Dictionary = {"kind": &"info", "title": "", "detail": ""}


func _ready() -> void:
	_palette = Gen2LauncherTheme.active()
	_build()
	_print_allowlist()
	_refresh_games()
	_report_previous_crash()
	var input: Gen2InputRuntime = Gen2InputRuntime.instance()
	if input != null and not input.back_requested.is_connected(_on_back_requested):
		input.back_requested.connect(_on_back_requested)


## Rebuilt whole when the appearance changes, which is the only way a launcher
## drawn entirely in code can switch palette without every widget growing a
## repaint path of its own.
func _build() -> void:
	Gen2Screen.drop_children(self)
	theme = _palette.control_theme()

	_shell = Gen2LauncherShell.create(_palette)
	add_child(_shell)
	_title_backdrop = Gen2LauncherTitleBackdrop.new()
	add_child(_title_backdrop)

	_shelf = Gen2ShelfPage.create(_palette, _shell.compact)
	_shelf.insert_requested.connect(_open_import_dialog)
	_shelf.play_requested.connect(_launch_game)
	_shelf.manage_requested.connect(_open_manage_sheet)
	_shelf.selection_changed.connect(_on_cartridge_selected)
	# The backdrop follows the shelf being on screen rather than the dock being
	# pressed, so a sheet, a restored page or anything else that reveals the
	# shelf without a page signal brings the picture and its music back too.
	_shelf.visibility_changed.connect(_refresh_backdrop)
	_shell.add_page(&"shelf", "Play", &"shelf", _shelf)

	_mods = Gen2ModsPage.create(_palette, self)
	_mods.install_requested.connect(_open_mod_dialog)
	_shell.add_page(&"mods", "Mods", &"mods", _mods)

	_settings = Gen2SettingsPage.create(_palette, self)
	_settings.appearance_changed.connect(_reload_appearance)
	_shell.add_page(&"settings", "Settings", &"settings", _settings)

	_about = Gen2AboutPage.create(_palette, self)
	_about.update_check_requested.connect(check_for_updates)
	_shell.add_page(&"about", "About", &"about", _about)

	_shell.page_selected.connect(_on_page_selected)
	_build_dialogs()
	_on_page_selected(_shell.current_page())
	# A message survives a palette rebuild, in the kind it was raised as: an
	# error replayed as information takes the warning glyph off it and gives it
	# a dismissal timer the toast deliberately withholds from a failure.
	if not String(_status["title"]).is_empty():
		_set_status(
			StringName(_status["kind"]), String(_status["title"]), String(_status["detail"])
		)


func _build_dialogs() -> void:
	_file_dialog = _picker(
		"Choose a cartridge dump",
		PackedStringArray(["*.gbc; Cartridge dump", "*.gb; Cartridge dump"]),
	)
	_file_dialog.file_selected.connect(_on_file_selected)

	_mod_dialog = _picker("Choose a mod .zip", PackedStringArray(["*.zip; Mod archive"]))
	_mod_dialog.file_selected.connect(func(path: String) -> void: import_mod_path(path))

	_art_dialog = _picker(
		"Choose cartridge art",
		PackedStringArray(["*.png, *.webp, *.jpg, *.jpeg; Image"]),
	)
	_art_dialog.file_selected.connect(func(path: String) -> void: adopt_cartridge_art(path))

	# Created once and reused. The check only ever runs from the button.
	_update_http = HTTPRequest.new()
	_update_http.request_completed.connect(_on_update_response)
	add_child(_update_http)

	# A window drop is the same import, so the OS file manager works wherever it
	# offers one. Routing is by extension because the two imports validate very
	# differently and neither should be handed the other's file.
	var window: Window = get_window()
	if not window.files_dropped.is_connected(_on_files_dropped):
		window.files_dropped.connect(_on_files_dropped)


func _picker(title: String, filters: PackedStringArray) -> Gen2LauncherFilePicker:
	var dialog: Gen2LauncherFilePicker = Gen2LauncherUI.file_picker(
		_palette, title, FileDialog.FILE_MODE_OPEN_FILE, filters
	)
	add_child(dialog)
	return dialog


func _reload_appearance() -> void:
	_palette = Gen2LauncherTheme.active()
	_build()
	_refresh_games()


func _on_cartridge_selected(_game_id: StringName) -> void:
	_refresh_backdrop()


## Only the shelf is dressed in a cartridge's artwork. Behind a page of cards the
## same picture reads as a stain rather than as a backdrop.
func _on_page_selected(_id: StringName) -> void:
	_refresh_backdrop()


## The selected cartridge's artwork, and only once that cartridge is imported: an
## empty bay would otherwise advertise a game the player cannot start.
func _refresh_backdrop() -> void:
	if not is_instance_valid(_shelf) or not is_instance_valid(_shell):
		return
	var game_id: StringName = _shelf.selected_id()
	var seated: Gen2Cartridge = _shelf.cartridge(game_id)
	var showing: bool = (
		_shell.current_page() == &"shelf" and seated != null and seated.imported
	)
	if not showing:
		_title_backdrop.hide_backdrop()
		_shell.set_backdrop_art(null)
		return
	var data: GameData = GameData.open(game_id)
	var title_texture: Texture2D = _title_backdrop.show_game(data)
	if title_texture != null:
		_shell.set_backdrop_art(title_texture, true)
	else:
		# A legacy cache without imported title art gets the neutral page rather
		# than carrying a second set of authored background images in the build.
		_shell.set_backdrop_art(null)


func _refresh_games() -> void:
	for game_id: StringName in RomRegistry.ORDER:
		var data: GameData = GameData.open(game_id)
		var state: StringName = cache_state_for(game_id) if data == null \
			else RomCache.STATE_USABLE
		_shelf.set_slot_state(game_id, state, _cartridge_detail(game_id, data, state))
	_shelf.set_busy(_importing)
	_refresh_backdrop()


func cache_state_for(game_id: StringName) -> StringName:
	return RomCache.state(RomCache.directory_for(game_id, RomRegistry.sha1_for(game_id)))


func _cartridge_detail(game_id: StringName, data: GameData, state: StringName) -> String:
	if data == null:
		return cache_state_note(state)
	var slots: Array = Gen2SaveStore.slots_for(game_id, data.sha1, data)
	var ready_slots: int = 0
	for row: Dictionary in slots:
		if row["valid"]:
			ready_slots += 1
	if slots.is_empty():
		return "Ready. No saves yet"
	return "Ready. %d save%s" % [ready_slots, "" if ready_slots == 1 else "s"]


## Public driver used by tests and by non-interactive tooling. Awaitable because
## the import gives the screen one frame to put its progress up before taking
## the main thread for the rest of the job.
func import_rom_path(path: String) -> void:
	await _on_file_selected(path)


## Installs a mod archive and loads it without a restart, which is safe here
## because the launcher is the one screen that exists before any world or
## battle has been built. Public for the same reason [method import_rom_path]
## is: a test drives the import without going through a native dialog.
func import_mod_path(path: String, replace: bool = false) -> Dictionary:
	var result: Dictionary = Gen2ModInstaller.install_zip(path, replace)
	if bool(result.get("ok", false)):
		GameRuntime.load_mods()
		_mods.refresh()
		_set_status(
			&"success",
			"Installed %s." % result.get("name", result.get("id", "the mod")),
			"%d files in %s." % [int(result.get("files", 0)), result.get("directory", "")],
		)
		return result
	if StringName(result.get("reason", &"")) == &"already_installed":
		_confirm_mod_replace(path, String(result.get("detail", "That mod")))
		return result
	_set_status(&"error", "That mod was not installed.", Gen2ModRefusal.text(result))
	return result


func _confirm_mod_replace(path: String, mod_name: String) -> void:
	var sheet: Gen2LauncherSheet = Gen2LauncherSheet.create(_palette, "Replace mod")
	sheet.body().add_child(Gen2LauncherUI.muted(
		_palette, "%s is already installed. Replace it with this archive?" % mod_name
	))
	var replace: Gen2LauncherButton = Gen2LauncherButton.create(
		_palette, "Replace", Gen2LauncherButton.Variant.PRIMARY
	)
	replace.pressed.connect(func() -> void:
		sheet.close()
		import_mod_path(path, true)
	)
	sheet.add_action(replace)
	sheet.open(self)


func _on_back_requested() -> void:
	if _importing:
		return
	if _close_top_layer():
		return
	if _shell != null and _shell.current_page() != &"shelf":
		_shell.select(&"shelf")
		return
	_confirm_quit()


func _close_top_layer() -> bool:
	var pickers: Array[Gen2LauncherFilePicker] = [_file_dialog, _mod_dialog]
	for picker: Gen2LauncherFilePicker in pickers:
		if picker != null and picker.visible:
			picker.hide()
			return true
	var sheets: Array[Node] = find_children("", "Gen2LauncherSheet", true, false)
	if sheets.is_empty():
		return false
	var top: Gen2LauncherSheet = sheets[sheets.size() - 1] as Gen2LauncherSheet
	top.close()
	return true


func _confirm_quit() -> void:
	var sheet: Gen2LauncherSheet = Gen2LauncherSheet.create(_palette, "Quit pokerecomp")
	sheet.body().add_child(Gen2LauncherUI.muted(
		_palette, "Close the app? Nothing is running, so there is nothing to lose."
	))
	var quit: Gen2LauncherButton = Gen2LauncherButton.create(
		_palette, "Quit", Gen2LauncherButton.Variant.DANGER, &"power"
	)
	quit.pressed.connect(func() -> void: get_tree().quit())
	sheet.add_action(quit)
	sheet.open(self)


func _open_mod_dialog() -> void:
	if _importing:
		return
	_mod_dialog.show_picker(Vector2i(920, 620))


## Asks the release API what the latest version is. Public so a test can drive
## the request path without a button press.
func check_for_updates() -> void:
	if _importing or _update_http == null:
		return
	_about.set_update_result("Checking...", _palette.muted)
	_set_status(&"busy", "Checking for updates...", Gen2UpdateCheck.RELEASES_API)
	var headers: PackedStringArray = PackedStringArray([
		"Accept: application/vnd.github+json",
	])
	if _update_http.request(Gen2UpdateCheck.RELEASES_API, headers) != OK:
		_set_status(&"error", "The update check could not start.", "No request was made.")


func _on_update_response(
	result: int, code: int, _headers: PackedStringArray, body: PackedByteArray
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		var offline: String = "This build is %s." % Gen2UpdateCheck.current_version()
		_about.set_update_result("The check did not reach the network.", _palette.error)
		_set_status(&"error", "The update check did not reach the network.", offline)
		return
	var status: Dictionary = Gen2UpdateCheck.status_for(code, body.get_string_from_utf8())
	var kind: StringName = &"info"
	var colour: Color = _palette.muted
	match int(status["status"]):
		Gen2UpdateCheck.Status.UPDATE_AVAILABLE:
			kind = &"info"
			colour = _palette.accent
		Gen2UpdateCheck.Status.UP_TO_DATE:
			kind = &"success"
			colour = _palette.success
		Gen2UpdateCheck.Status.UNREADABLE:
			kind = &"error"
			colour = _palette.error
	var message: String = Gen2UpdateCheck.describe(status)
	_about.set_update_result(message, colour)
	_set_status(kind, message, String(status.get("url", Gen2UpdateCheck.RELEASES_PAGE)))


func _open_manage_sheet(game_id: StringName) -> void:
	if _importing:
		return
	var path: String = RomCache.directory_for(game_id, RomRegistry.sha1_for(game_id))
	var state: StringName = RomCache.state(path)
	var sheet: Gen2LauncherSheet = Gen2LauncherSheet.create(
		_palette, RomRegistry.title_for(game_id)
	)
	var body: VBoxContainer = sheet.body()
	body.add_child(Gen2LauncherUI.muted(_palette, cache_state_text(state)))
	if needs_reimport(state):
		body.add_child(Gen2LauncherUI.muted(_palette, SAVES_ARE_SAFE))
	var directory: Label = Gen2LauncherUI.muted(_palette, path)
	directory.add_theme_color_override("font_color", _palette.faint)
	body.add_child(directory)

	# Off the state rather than off the data: a stale or half-written cache is
	# exactly the one worth opening or deleting, and neither can be read.
	if state != RomCache.STATE_MISSING:
		var open_folder: Gen2LauncherButton = Gen2LauncherButton.create(
			_palette, "Open cache folder", Gen2LauncherButton.Variant.NEUTRAL, &"folder"
		)
		open_folder.pressed.connect(func() -> void: _open_cache_folder(game_id))
		body.add_child(open_folder)
		var delete: Gen2LauncherButton = Gen2LauncherButton.create(
			_palette, "Delete cache", Gen2LauncherButton.Variant.DANGER, &"trash"
		)
		delete.pressed.connect(func() -> void:
			sheet.close()
			_delete_cache(game_id)
		)
		body.add_child(delete)

	var art: Gen2LauncherButton = Gen2LauncherButton.create(
		_palette, "Use your own art", Gen2LauncherButton.Variant.NEUTRAL, &"folder"
	)
	art.tooltip_text = "Replace this cartridge's picture with an image of your own"
	art.pressed.connect(func() -> void:
		_art_game_id = game_id
		sheet.close()
		_art_dialog.show_picker(Vector2i(920, 620))
	)
	body.add_child(art)
	if Gen2CartridgeArt.has_custom_art(game_id):
		var default_art: Gen2LauncherButton = Gen2LauncherButton.create(
			_palette, "Use the default art", Gen2LauncherButton.Variant.NEUTRAL, &"refresh"
		)
		default_art.pressed.connect(func() -> void:
			sheet.close()
			revert_cartridge_art(game_id)
		)
		body.add_child(default_art)

	sheet.add_action(_reimport_action(
		sheet, game_id, "Re-import" if state != RomCache.STATE_MISSING else "Import"
	))
	sheet.open(self)


## The manage sheet answers the same states, but it is a workbench.
func _open_update_sheet(game_id: StringName, state: StringName) -> void:
	var sheet: Gen2LauncherSheet = Gen2LauncherSheet.create(
		_palette, RomRegistry.title_for(game_id)
	)
	var body: VBoxContainer = sheet.body()
	var sentence: Label = Gen2LauncherUI.body(_palette, cache_state_text(state))
	sentence.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(sentence)
	body.add_child(Gen2LauncherUI.muted(_palette, SAVES_ARE_SAFE))
	sheet.add_action(_reimport_action(sheet, game_id, "Import again"))
	sheet.open(self)


func _reimport_action(
	sheet: Gen2LauncherSheet, game_id: StringName, label: String
) -> Gen2LauncherButton:
	var button: Gen2LauncherButton = Gen2LauncherButton.create(
		_palette, label, Gen2LauncherButton.Variant.PRIMARY, &"download"
	)
	button.pressed.connect(func() -> void:
		_reimport_game_id = game_id
		sheet.close()
		_show_import_picker()
	)
	return button


static func cache_state_note(state: StringName) -> String:
	return _cache_state_copy(state, 0)


## Takes a state rather than a cartridge, so the four sentences can be asserted
## without a cache on disk to put a build's own cartridges at risk.
static func cache_state_text(state: StringName) -> String:
	return _cache_state_copy(state, 1)


static func needs_reimport(state: StringName) -> bool:
	return state == RomCache.STATE_STALE or state == RomCache.STATE_INCOMPLETE


static func _cache_state_copy(state: StringName, column: int) -> String:
	var row: Array = CACHE_STATE_COPY.get(state, ["", ""])
	return String(row[column])


## Public and separate from the dialog for the reason
## [method Gen2ModsPage.install_entry_bytes] is: a test needs no OS file dialog.
func adopt_cartridge_art(path: String) -> Dictionary:
	var game_id: StringName = _art_game_id
	_art_game_id = &""
	var taken: Dictionary = Gen2CartridgeArt.adopt(game_id, path)
	if not bool(taken.get("ok", false)):
		_set_status(
			&"error",
			"That art was not used.",
			Gen2CartridgeArt.refusal_text(StringName(taken.get("reason", &""))),
		)
		return taken
	_refresh_cartridge_art(game_id)
	_set_status(
		&"success",
		"%s is wearing your own art." % RomRegistry.title_for(game_id),
		"Cartridge options has a way back to the default.",
	)
	return taken


func revert_cartridge_art(game_id: StringName) -> void:
	if not Gen2CartridgeArt.revert(game_id):
		return
	_refresh_cartridge_art(game_id)
	_set_status(
		&"info",
		"%s is wearing its own art again." % RomRegistry.title_for(game_id),
		"The picture you chose was removed.",
	)


func _refresh_cartridge_art(game_id: StringName) -> void:
	var seated: Gen2Cartridge = _shelf.cartridge(game_id)
	if seated != null:
		seated.refresh_art()


func _open_cache_folder(game_id: StringName) -> void:
	var directory: String = RomCache.directory_for(game_id, RomRegistry.sha1_for(game_id))
	OS.shell_open(ProjectSettings.globalize_path(directory))


## Removes the decoded cartridge data and nothing else. Saves live under their
## own root, so deleting a cache costs an import and no player progress.
func _delete_cache(game_id: StringName) -> void:
	RomCache.clear(RomCache.directory_for(game_id, RomRegistry.sha1_for(game_id)))
	if _selected_game_id == game_id:
		_selected_game_id = &""
	var seated: Gen2Cartridge = _shelf.cartridge(game_id)
	if seated != null and seated.imported:
		await seated.play_eject()
	_set_status(
		&"info",
		"Removed the %s cache." % RomRegistry.title_for(game_id),
		"Your saves were not touched. Import the cartridge again to play.",
	)
	_refresh_games()


func _on_files_dropped(files: PackedStringArray) -> void:
	if _importing:
		return
	for path: String in files:
		match path.get_extension().to_lower():
			"zip":
				import_mod_path(path)
				return
			"gb", "gbc":
				_on_file_selected(path)
				return
	_set_status(
		&"error",
		"Nothing to import there.",
		"Drop a .gb or .gbc cartridge dump, or a mod .zip.",
	)


## A small read-only view of the launcher state, useful for UI checks without
## reaching into the controls the launcher creates dynamically.
func launcher_snapshot() -> Dictionary:
	var games: Dictionary = {}
	for game_id: StringName in RomRegistry.ORDER:
		var data: GameData = GameData.open(game_id)
		games[String(game_id)] = {
			"title": RomRegistry.title_for(game_id),
			"imported": data != null,
			"cache_state": String(
				RomCache.STATE_USABLE if data != null else cache_state_for(game_id)
			),
			"selected": game_id == _selected_game_id,
			"save_slots": Gen2SaveStore.slots_for(game_id, data.sha1, data) if data != null else [],
		}
	return {
		"status": String(_status["title"]),
		"kind": String(_status["kind"]),
		"detail": String(_status["detail"]),
		"importing": _importing,
		"page": String(_shell.current_page()) if _shell != null else "",
		"theme": String(_palette.mode),
		"games": games,
	}


## Opens one of the launcher's pages by id. Public so a preview or a test can
## photograph a page without clicking its navigation entry.
func select_page(id: StringName) -> void:
	if _shell != null:
		_shell.select(id)


## Preview seam: holds the transition sheet at one of `FadeOutToWhite`'s four
## rows so a still can show that the fade is stepped. Photography only; the
## launcher itself only ever runs the whole walk.
func preview_fade_step(step: int) -> void:
	_shell.preview_fade_step(step)


## Preview seam: every bay photographed on one machine. Nothing on disk moves.
func preview_slot_states(states: Dictionary) -> void:
	for game_id: StringName in RomRegistry.ORDER:
		var state := StringName(states.get(String(game_id), RomCache.STATE_MISSING))
		var detail: String = "Ready. 2 saves" if state == RomCache.STATE_USABLE \
			else cache_state_note(state)
		_shelf.set_slot_state(game_id, state, detail)
	_refresh_backdrop()


## Preview seam: opens one of the mods page's own views, so a mod's page and
## the sources page can be photographed without a press.
func preview_mods_view(view: StringName, id: StringName = &"") -> void:
	select_page(&"mods")
	match view:
		&"mod":
			_mods.open_mod(id)
		&"sources":
			_mods.open_sources()
		_:
			_mods.show_list()


## Preview seam: opens a real launcher sheet without synthesising a pointer
## press, so visual checks can photograph every menu consistently.
func preview_sheet(view: StringName) -> void:
	match view:
		&"manage":
			select_page(&"shelf")
			_open_manage_sheet(_shelf.selected_id())
		&"update":
			select_page(&"shelf")
			_open_update_sheet(_shelf.selected_id(), RomCache.STATE_STALE)
		&"touch":
			select_page(&"settings")
			_settings._open_touch_layout()
		&"bugs":
			select_page(&"settings")
			_settings._open_rules_sheet()
		&"report":
			select_page(&"about")
			_about.open_report_sheet()
		&"quit":
			select_page(&"shelf")
			_confirm_quit()
		&"toast":
			# The one message that stays until it is dismissed, over the shelf's
			# own action row, which is what its dismiss button has to clear.
			_set_status(
				&"error",
				"The last session ended unexpectedly.",
				"About > Report a bug will save a file with the logs in it.",
			)
		&"browse":
			select_page(&"shelf")
			_file_dialog.show_browse_sheet(_preview_browse_dir)
		&"binding":
			select_page(&"settings")
			var sheet: Gen2BindingSheet = Gen2BindingSheet.for_button(
				_palette, Gen2OptionsStore.current(), Gen2Button.A
			)
			sheet.open(self)
		&"delete_mod":
			select_page(&"mods")
			var row: Dictionary = _mods._row_for(&"voxel_preview")
			if not row.is_empty():
				_mods.remove_mod(row)


## Preview seam: switches appearance without writing the options file.
func preview_theme(wanted: StringName) -> void:
	_palette = Gen2LauncherTheme.for_mode(wanted)
	_build()
	_refresh_games()


## Seats the cartridge, then opens its save slots. The animation runs before the
## scene change so the sound and the movement both finish on this screen.
func _launch_game(game_id: StringName) -> void:
	if _importing:
		return
	var data: GameData = GameData.open(game_id)
	if data == null:
		_open_import_dialog(game_id)
		return
	if not GameRuntime.select_game(game_id):
		_set_status(
			&"error",
			"Could not select %s." % RomRegistry.title_for(game_id),
			"The registry did not recognise that cartridge.",
		)
		return
	_selected_game_id = game_id
	# The launch says itself with the transition; a toast announcing it would be
	# a second, slower answer to the same press.
	_shelf.set_busy(true)
	var seated: Gen2Cartridge = _shelf.cartridge(game_id)
	if seated != null:
		await seated.play_start()
	await _shell.flash()
	get_tree().change_scene_to_file.call_deferred("res://game/save/save_screen.tscn")


## A cartridge this build cannot read was imported once; an empty bay was not.
func _open_import_dialog(game_id: StringName = &"") -> void:
	if _importing:
		return
	var state: StringName = cache_state_for(game_id) if not game_id.is_empty() \
		else RomCache.STATE_MISSING
	if needs_reimport(state):
		_open_update_sheet(game_id, state)
		return
	_show_import_picker()


func _show_import_picker() -> void:
	if _importing:
		return
	_set_status(
		&"info",
		"Choose a cartridge dump.",
		"The importer identifies the cartridge by SHA-1, never by filename.",
	)
	_file_dialog.show_picker(Vector2i(920, 620))


func _on_file_selected(path: String) -> void:
	if _importing:
		return
	_importing = true
	_shelf.set_busy(true)
	_shell.toast().set_progress(true, 0.0)
	_set_status(&"busy", "Verifying cartridge...", path.get_file())
	# A frame before the first of the work, so the toast is laid out rather than
	# merely built. The tree's own signal rather than the rendering server's:
	# `frame_post_draw` is never emitted on a headless run, where this would
	# then wait for a frame that is never drawn.
	await get_tree().process_frame

	var identity: Dictionary = RomVerifier.identify(path)
	if identity["status"] != RomVerifier.Status.OK:
		_finish_import(false, String(identity["message"]))
		return

	# A re-import replaces one cartridge's cache, so it only accepts that
	# cartridge's own dump. Without this, choosing the wrong file from the
	# manage sheet would quietly import a different one instead of saying so.
	if not _reimport_game_id.is_empty() and StringName(identity["id"]) != _reimport_game_id:
		var wanted: StringName = _reimport_game_id
		_reimport_game_id = &""
		_finish_import(false, "That dump is %s, not %s." % [
			RomRegistry.title_for(StringName(identity["id"])), RomRegistry.title_for(wanted),
		])
		return
	_reimport_game_id = &""

	var rom: RomFile = RomFile.open_verified(path)
	if rom == null:
		_finish_import(false, "The verified cartridge could not be read.")
		return

	_set_status(&"busy", "Checking table layout...", path.get_file())
	# The layout check reads the whole overworld once, which is most of a second
	# on a phone, and it is the last thing before the import proper.
	await get_tree().process_frame
	var layout_check: Dictionary = RomImporter.verify_layout(rom)
	if not layout_check["ok"]:
		_finish_import(false, String(layout_check["message"]))
		return

	var importer := RomImporter.new()
	var result: Dictionary = await importer.import_rom(
		rom, _on_import_progress, IMPORT_YIELD_MS
	)
	if not result["ok"]:
		_finish_import(false, String(result["message"]))
		return

	var game_id: StringName = identity["id"]
	GameRuntime.select_game(game_id)
	_selected_game_id = game_id
	_finish_import(true, "%d species and %d trainer classes are ready." % [
		int(result["species"]), int(result["trainers"]),
	])
	_refresh_games()
	_shelf.focus_game(game_id)
	var seated: Gen2Cartridge = _shelf.cartridge(game_id)
	if seated != null:
		seated.play_insert()


func _on_import_progress(stage: String, done: int, total: int) -> void:
	if total > 0:
		_shell.toast().set_progress(true, float(done) / float(total) * 100.0)
	_set_status(&"busy", "%s, %d/%d" % [stage.capitalize(), done, total], "")


func _finish_import(success: bool, message: String) -> void:
	_importing = false
	_shelf.set_busy(false)
	_shell.toast().set_progress(false)
	if not success:
		Gen2LauncherAudio.play(&"error")
	_set_status(
		&"success" if success else &"error",
		"Import complete." if success else "Import stopped.",
		message,
	)
	if _shell != null:
		_shell.log_layers("import")


func _set_status(kind: StringName, title: String, detail: String) -> void:
	_status = {"kind": kind, "title": title, "detail": detail}
	if _shell != null:
		_shell.toast().show_message(kind, title, detail)


## Says so when the last session did not shut down, and says where the report
## file is. The launcher is the one screen a player is certain to see after a
## crash, so this is where the offer belongs; nothing is written or sent here.
func _report_previous_crash() -> void:
	var diagnostics: Gen2Diagnostics = Gen2Diagnostics.instance()
	if diagnostics == null or not diagnostics.previous_session_crashed():
		return
	diagnostics.forget_previous_crash()
	_set_status(
		&"error",
		"The last session ended unexpectedly.",
		"About > Report a bug will save a file with the logs in it.",
	)


func _print_allowlist() -> void:
	var lines: PackedStringArray = []
	for id: StringName in RomRegistry.ORDER:
		lines.append("  %-8s %s" % [RomRegistry.title_for(id), RomRegistry.sha1_for(id)])
	print("pokerecomp supported cartridges:")
	print("\n".join(lines))


## A reset lands here: nothing is behind the chord left to reset.
func claim_soft_reset() -> bool:
	return true
