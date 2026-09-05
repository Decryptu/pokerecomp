class_name Gen2ModsPage
extends VBoxContainer

## The mod manager: a list grouped by where each mod came from, a page per mod,
## and a page for the sources the player follows. The model is a package
## manager's, so removing a mod a source lists uninstalls it and leaves it listed
## while removing one from a file deletes the only copy; [Gen2ModCatalogue]
## decides both. A change is applied where it is made: the host is reset and every
## entry script runs again, nothing here withdrawing one registration on its own.

## Asks the launcher for its file picker: the page owns no OS dialog.
signal install_requested
## What [method hints] would answer has changed; the shell owns the bar.
signal hints_changed

## A feed and a mod archive are both small. This stops a hostile or broken server
## streaming forever into memory.
const MAX_DOWNLOAD_BYTES: int = 96 * 1024 * 1024

var _theme: Gen2LauncherTheme = null
var _host: Control = null
## Whether the page is drawn for a narrow screen, where a row's controls go under
## its name instead of beside it.
var _compact: bool = false
var _views: Control = null
var _list_view: VBoxContainer = null
var _list: VBoxContainer = null
var _note: Label = null
var _detail: Gen2ModDetailPage = null
var _sources: Gen2ModSourcesPage = null
var _http: HTTPRequest = null
## Feed to the entries its last good copy listed. Read from the cache on every
## refresh, so a listing survives a restart and the network is only ever asked
## when the player asks for it.
var _listings: Dictionary = {}
var _pending: Dictionary = {}
var _busy: bool = false
var _check_queue: Array[String] = []
## Feeds this page has already tried to read on its own, so a source whose
## server is down is attempted once rather than on every rebuild of the list.
var _read_once: Dictionary = {}
## Whether the queue being drained is the page reading a source nobody asked it
## to. It says nothing when it finishes; a player who pressed the button gets a
## count either way.
var _reading_quietly: bool = false
var _check_updates_button: Gen2LauncherButton = null
## Update all is a queue: the page's one request is serialised behind `_busy`.
var _update_queue: Array = []
var _updated: int = 0
var _install_button: Gen2LauncherButton = null
## Its own request, because the page's other one is serialised behind `_busy`
## and an icon must never make a player wait for a download or a feed.
var _icons: HTTPRequest = null
## Icon URLs still to fetch, and the squares waiting for them. A square is a
## node in the list, so a rebuild drops both rather than filling a freed one.
var _icon_queue: Array[String] = []
var _icon_targets: Dictionary = {}
var _icon_busy: bool = false
var _icon_pending: String = ""


static func create(palette: Gen2LauncherTheme, host: Control = null) -> Gen2ModsPage:
	var page := Gen2ModsPage.new()
	page._theme = palette
	page._host = host
	page._build()
	page.refresh()
	return page


func _build() -> void:
	add_theme_constant_override("separation", Gen2LauncherUI.GAP_LG)
	_http = HTTPRequest.new()
	_http.use_threads = true
	_http.body_size_limit = MAX_DOWNLOAD_BYTES
	add_child(_http)
	_icons = HTTPRequest.new()
	_icons.use_threads = true
	_icons.body_size_limit = PokeModArt.MAX_ICON_BYTES
	_icons.request_completed.connect(_on_icon_arrived)
	add_child(_icons)

	_views = Control.new()
	_views.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_views.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_views)

	_list_view = Gen2LauncherUI.column(Gen2LauncherUI.GAP_LG)
	_list_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_views.add_child(_list_view)

	# Actions get their own row: three controls beside the title exceed a phone's
	# width, while this stays compact on desktop and wraps nothing unpredictably.
	var head: VBoxContainer = Gen2LauncherUI.column(Gen2LauncherUI.GAP_SM)
	_list_view.add_child(head)
	var text: VBoxContainer = Gen2LauncherUI.column(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(text)
	text.add_child(Gen2LauncherUI.title(_theme, "Mods", Gen2LauncherTheme.FONT_DISPLAY))
	_note = Gen2LauncherUI.muted(_theme, "")
	text.add_child(_note)

	var actions: HBoxContainer = Gen2LauncherUI.row(Gen2LauncherUI.GAP_SM)
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(actions)
	_check_updates_button = Gen2LauncherButton.icon_only(
		_theme, &"refresh_all", Gen2LauncherButton.Variant.NEUTRAL, 42.0
	)
	_check_updates_button.pressed.connect(_on_update_button)
	actions.add_child(_check_updates_button)
	_sync_update_button()
	_install_button = Gen2LauncherButton.create(
		_theme, "Install", Gen2LauncherButton.Variant.PRIMARY, &"plus"
	)
	_install_button.tooltip_text = "Install a mod .zip"
	_install_button.pressed.connect(func() -> void: install_requested.emit())
	actions.add_child(_install_button)
	var sources: Gen2LauncherButton = Gen2LauncherButton.create(
		_theme, "Sources", Gen2LauncherButton.Variant.NEUTRAL, &"download"
	)
	sources.pressed.connect(open_sources)
	actions.add_child(sources)

	var scroll: Gen2LauncherScroll = Gen2LauncherScroll.create()
	_list_view.add_child(scroll)
	_list = Gen2LauncherUI.column(Gen2LauncherUI.GAP_MD)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.content().add_child(_list)


## The page's primary action is stable while the source check starts and stops
## in the background, so entering with a pad never depends on network timing.
func focus_target() -> Control:
	return _install_button


## Rebuilds the list from what is installed and what the followed sources last
## listed. The network is not touched: a listing is read from its cache, which
## is what makes opening this page instant and offline.
func refresh() -> void:
	_listings = {}
	for source: Dictionary in PokeModIndex.followed():
		var cached: Dictionary = PokeModIndex.cached_feed(String(source["feed"]))
		if bool(cached.get("ok", false)):
			_listings[String(source["feed"])] = cached["entries"]
	_relist()
	if _detail != null:
		_detail.set_row(_row_for(_detail.mod_id()))
	if _sources != null:
		_sources.refresh()
	_read_unread_sources()


## Whether the page may reach the network without a player having asked it to.
## [method HTTPRequest.request] refuses, loudly, from a node that is not in the
## tree, and [method create] builds the whole page before the launcher adds it.
## The rest is [method Gen2GameRuntime.is_player_launch]: a check, a test tier or
## a replay has nobody to show a listing to, so every page it builds would fetch
## the feed and an icon per row. What a player pressed is not gated here.
func _may_fetch_unprompted() -> bool:
	return is_inside_tree() and Gen2GameRuntime.is_player_launch()


## Reads a source that has never been read, once. Every build follows this
## project's own index, and without this it would list nothing until the player
## thought to press Check for updates.
func _read_unread_sources() -> void:
	if _busy or not _check_queue.is_empty() or not _update_queue.is_empty():
		return
	if not _may_fetch_unprompted():
		return
	for source: Dictionary in PokeModIndex.followed():
		var feed: String = String(source["feed"])
		if not _listings.has(feed) and not _read_once.has(feed):
			_read_once[feed] = true
			_check_queue.append(feed)
	if _check_queue.is_empty():
		return
	_reading_quietly = true
	_sync_update_button()
	_check_next_source()


func _relist() -> void:
	_icon_queue.clear()
	_icon_targets.clear()
	Gen2LauncherUI.clear(_list)
	var host: Gen2ModHost = Gen2ModHost.instance()
	var groups: Array = Gen2ModCatalogue.groups(
		host.manifests(), PokeModIndex.followed(), _listings, host.present_ids()
	)
	var failures: Array = host.failures()
	_note.text = "Loaded from %s" % Gen2ModHost.ROOT
	_sync_update_button()

	if groups.is_empty() and failures.is_empty():
		_list.add_child(_empty_state())
		_list.add_child(Gen2LauncherUI.bottom_safe_space())
		return
	for group: Dictionary in groups:
		_list.add_child(Gen2LauncherUI.caption(_theme, String(group["label"])))
		for row: Dictionary in group["rows"] as Array:
			_list.add_child(_card(row))
	if not failures.is_empty():
		_list.add_child(Gen2LauncherUI.caption(_theme, "Not loaded"))
		for failure: Dictionary in failures:
			_list.add_child(_refusal(failure))
	_list.add_child(Gen2LauncherUI.bottom_safe_space())
	_fetch_next_icon()


func _empty_state() -> Control:
	var panel: Gen2LauncherCard = Gen2LauncherCard.well(_theme, Gen2LauncherTheme.RADIUS_MD, 28)
	var box: VBoxContainer = Gen2LauncherUI.column(Gen2LauncherUI.GAP_SM)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	var icon: PokeLauncherIcon = PokeLauncherIcon.create(&"mods", 28.0, _theme.faint)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	var line: Label = Gen2LauncherUI.muted(
		_theme, "No mods yet. Install a .zip, or read a source to browse what it lists."
	)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(line)
	return panel


## One row: what it is, whether it is on, and its one action. Everything else is
## on the mod's own page, which the row itself opens.
func _card(row: Dictionary) -> Control:
	var panel: Gen2LauncherCard = Gen2LauncherCard.create(_theme, Gen2LauncherTheme.RADIUS_MD, 18)
	# A portrait phone leaves a name eleven characters wide beside the controls,
	# so the controls take a row of their own and the name takes the width.
	var stack: VBoxContainer = Gen2LauncherUI.column(Gen2LauncherUI.GAP_SM)
	panel.add_child(stack)
	var line: HBoxContainer = Gen2LauncherUI.row(Gen2LauncherUI.GAP_MD)
	stack.add_child(line)
	line.add_child(_icon_square(row))

	var text: VBoxContainer = Gen2LauncherUI.column(1)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_child(text)
	# An id is one long word and will not wrap, so it is trimmed rather than
	# allowed to set the width of every row on the page.
	text.add_child(_clipped(Gen2LauncherUI.body(_theme, String(row["name"]))))
	text.add_child(_clipped(Gen2LauncherUI.muted(_theme, _version_line(row))))

	var controls: HBoxContainer = line
	if _compact:
		controls = Gen2LauncherUI.row(Gen2LauncherUI.GAP_MD)
		controls.alignment = BoxContainer.ALIGNMENT_END
		stack.add_child(controls)

	if bool(row["installed"]):
		var switch: Gen2LauncherToggle = Gen2LauncherToggle.create(_theme, bool(row["enabled"]))
		switch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		switch.toggled.connect(func(on: bool) -> void: set_enabled(row, on))
		controls.add_child(switch)

	for button: Control in _action_buttons(row):
		controls.add_child(button)

	var open: Gen2LauncherButton = Gen2LauncherButton.icon_only(
		_theme, &"chevron", Gen2LauncherButton.Variant.QUIET, 40.0
	)
	open.tooltip_text = "Open %s" % row["name"]
	open.pressed.connect(func() -> void: open_mod(StringName(row["id"])))
	controls.add_child(open)
	# Pressing the row is the same as pressing its chevron. The toggle and the
	# action are buttons of their own and take their own press first.
	panel.activated.connect(func() -> void: open_mod(StringName(row["id"])))
	return panel


## Redrawn for the width the page is being given. Rebuilding is how every
## launcher pane changes shape, since each is built in code from its state.
func set_compact(on: bool) -> void:
	if on == _compact:
		return
	_compact = on
	refresh()


## A label that gives up its width rather than pushing the row wider than the
## card. Its own minimum is what makes a [HBoxContainer] overflow.
static func _clipped(label: Label) -> Label:
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size.x = 0.0
	return label


## What a row can do: download a mod that is not installed, update one a source
## offers a newer version of, replace a copy this host would not load, and remove
## whatever is on disk. Download, update and replace are the same press, since a
## source hands over an archive and the installer replaces what was there.
##
## The remove button follows `present` rather than `installed`, or a copy whose
## manifest was refused has no button that does anything: the download over it is
## refused by the directory and there is nothing else to press.
func _action_buttons(row: Dictionary) -> Array[Control]:
	var out: Array[Control] = []
	var action: StringName = Gen2ModCatalogue.action_for(row)
	if action != &"remove" and bool(row["listed"]):
		var get_it: Gen2LauncherButton = Gen2LauncherButton.icon_only(
			_theme, &"download", Gen2LauncherButton.Variant.PRIMARY, 40.0
		)
		get_it.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		get_it.tooltip_text = ACTION_TOOLTIPS[action] % row["name"]
		get_it.pressed.connect(func() -> void: download(row))
		out.append(get_it)
	if not bool(row["present"]):
		return out
	var remove: Gen2LauncherButton = Gen2LauncherButton.icon_only(
		_theme, &"trash", Gen2LauncherButton.Variant.DANGER, 40.0
	)
	remove.tooltip_text = "Remove %s" % row["name"]
	remove.pressed.connect(func() -> void: remove_mod(row))
	out.append(remove)
	return out


const ACTION_TOOLTIPS: Dictionary = {
	&"download": "Download %s",
	&"update": "Download and install the available update for %s",
	&"replace": "Replace the copy of %s this version cannot load",
}


## The line under a name: the version in hand, and what a source is offering
## when that is something else.
static func _version_line(row: Dictionary) -> String:
	var line: String = String(row["id"])
	var version: String = String(row["version"])
	if not version.is_empty():
		line += "  %s" % version
	if not bool(row["installed"]):
		# A copy on disk the host refused is not the same as nothing installed,
		# and the refusal card below the list says which one it was.
		return "%s  %s" % [
			line, "Installed, not loaded" if bool(row["present"]) else "Not installed"
		]
	match StringName(row["update"]):
		PokeModIndex.UPDATE_AVAILABLE:
			return "%s  %s available" % [line, row["listed_version"]]
		PokeModIndex.INSTALLED_IS_NEWER:
			return "%s  newer than this source" % line
	return line


func _refusal(failure: Dictionary) -> Control:
	var panel: Gen2LauncherCard = Gen2LauncherCard.well(_theme, Gen2LauncherTheme.RADIUS_MD, 18)
	var line: HBoxContainer = Gen2LauncherUI.row(Gen2LauncherUI.GAP_MD)
	panel.add_child(line)
	line.add_child(PokeLauncherIcon.create(&"warning", 20.0, _theme.warning))
	var text: VBoxContainer = Gen2LauncherUI.column(1)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(text)
	text.add_child(Gen2LauncherUI.body(
		_theme, String(failure.get("directory", failure.get("id", "?")))
	))
	text.add_child(Gen2LauncherUI.muted(_theme, PokeModRefusal.text(failure)))
	return panel


## The row for one id as the catalogue sees it now, or an empty dictionary for a
## mod that has since been removed and is listed nowhere.
func _row_for(id: StringName) -> Dictionary:
	var host: Gen2ModHost = Gen2ModHost.instance()
	for group: Dictionary in Gen2ModCatalogue.groups(
		host.manifests(), PokeModIndex.followed(), _listings, host.present_ids()
	):
		for row: Dictionary in group["rows"] as Array:
			if StringName(row["id"]) == id:
				return row
	return {}


func open_mod(id: StringName) -> void:
	var row: Dictionary = _row_for(id)
	if row.is_empty():
		return
	if _detail == null:
		_detail = Gen2ModDetailPage.create(_theme, _host)
		_detail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_detail.closed.connect(show_list)
		_detail.enabled_changed.connect(set_enabled)
		_detail.download_requested.connect(download)
		_detail.remove_requested.connect(remove_mod)
		_views.add_child(_detail)
	_detail.set_row(row)
	_show(_detail)


func open_sources() -> void:
	if _sources == null:
		_sources = Gen2ModSourcesPage.create(_theme)
		_sources.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_sources.closed.connect(show_list)
		_sources.followed.connect(_on_followed)
		_sources.unfollowed.connect(func(_feed: String) -> void: refresh())
		_sources.refresh_requested.connect(fetch_feed)
		_views.add_child(_sources)
	_sources.refresh()
	_show(_sources)


## A sub-view answers cancel itself, so the shell's way back is not offered.
func hints() -> Array:
	if current_view() != &"list":
		return [{"action": &"ui_cancel", "label": "Mods", "run": show_list}]
	return [{
		"action": &"ui_menu", "label": "Install from file",
		"run": func() -> void: install_requested.emit(),
	}]


func show_list() -> void:
	refresh()
	_show(_list_view)


func _show(view: Control) -> void:
	for child: Node in _views.get_children():
		(child as Control).visible = child == view
	hints_changed.emit()


func current_view() -> StringName:
	if _detail != null and _detail.visible:
		return &"mod"
	return &"sources" if _sources != null and _sources.visible else &"list"


func _on_followed(feed: String) -> void:
	refresh()
	fetch_feed(feed)


## Asks a source for its listing. Everything it can answer is
## [method PokeModIndex.receive_feed]'s, so a failure falls back to the copy on
## disk rather than emptying the list.
func fetch_feed(feed: String) -> void:
	_fetch_feed(feed)


func check_for_updates() -> void:
	if _busy or not _check_queue.is_empty() or not _update_queue.is_empty():
		return
	# Never empty: every build follows this project's own index.
	for source: Dictionary in PokeModIndex.followed():
		_read_once[String(source["feed"])] = true
		_check_queue.append(String(source["feed"]))
	_reading_quietly = false
	_sync_update_button()
	_status("Checking mod sources for updates...", _theme.muted)
	_check_next_source()


func _check_next_source() -> void:
	if _check_queue.is_empty():
		var quietly: bool = _reading_quietly
		_reading_quietly = false
		refresh()
		if quietly:
			return
		var count: int = available_update_count()
		_status(
			"%d mod update%s available. Choose its download button to install." % [
				count, " is" if count == 1 else "s are",
			] if count > 0 else "All installed mods are up to date.",
			_theme.accent if count > 0 else _theme.muted,
		)
		return
	var feed: String = _check_queue.pop_front()
	_fetch_feed(feed, _check_next_source)


func available_update_count() -> int:
	return update_rows().size()


## What the update button offers: a newer version, and a copy this host would
## not load that a source can hand over again, which is the one press out of a
## contract bump.
const UPDATE_ACTIONS: Array[StringName] = [&"update", &"replace"]


func update_rows() -> Array:
	var out: Array = []
	var host: Gen2ModHost = Gen2ModHost.instance()
	for group: Dictionary in Gen2ModCatalogue.groups(
		host.manifests(), PokeModIndex.followed(), _listings, host.present_ids()
	):
		for row: Dictionary in group["rows"] as Array:
			if UPDATE_ACTIONS.has(Gen2ModCatalogue.action_for(row)) and bool(row["listed"]):
				out.append(row)
	return out


func _on_update_button() -> void:
	if available_update_count() > 0:
		download_all()
		return
	check_for_updates()


func download_all() -> void:
	if _busy or not _check_queue.is_empty() or not _update_queue.is_empty():
		return
	_update_queue = update_rows()
	if _update_queue.is_empty():
		return
	_updated = 0
	_sync_update_button()
	_download_next_update()


func _download_next_update() -> void:
	if _update_queue.is_empty():
		var count: int = _updated
		_updated = 0
		_sync_update_button()
		_status(
			"Updated %d mod%s." % [count, "" if count == 1 else "s"] if count > 0
				else "No mod update could be installed.",
			_theme.accent if count > 0 else _theme.error,
		)
		return
	download(_update_queue.pop_front() as Dictionary, func(ok: bool) -> void:
		if ok:
			_updated += 1
		_download_next_update()
	)


func _sync_update_button() -> void:
	if _check_updates_button == null:
		return
	var updates: int = available_update_count()
	var draining: bool = not _update_queue.is_empty()
	_check_updates_button.set_disabled_state(
		_busy or draining or not _check_queue.is_empty()
	)
	_check_updates_button.variant = Gen2LauncherButton.Variant.PRIMARY if updates > 0 \
		else Gen2LauncherButton.Variant.NEUTRAL
	_check_updates_button.set_glyph(&"download" if updates > 0 else &"refresh_all")
	_check_updates_button.tooltip_text = "Download and install %d mod update%s" % [
		updates, "" if updates == 1 else "s",
	] if updates > 0 else "Check all followed sources for mod updates"


func _fetch_feed(feed: String, finished: Callable = Callable()) -> void:
	_status("Reading %s..." % feed, _theme.muted)
	var started: bool = _request(feed, func(
		result: int, code: int, _headers: PackedStringArray, body: PackedByteArray
	) -> void:
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			receive_feed_response(feed, false, "", "That source could not be read (HTTP %d)." % code)
		else:
			receive_feed_response(feed, true, body.get_string_from_utf8())
		if finished.is_valid():
			finished.call()
	)
	if not started and finished.is_valid():
		finished.call_deferred()


## Takes whatever the request came back with. Public and separate from the
## handler so both answers a server can give are testable without one.
func receive_feed_response(
	feed: String, ok: bool, text: String = "", problem: String = ""
) -> Dictionary:
	var received: Dictionary = PokeModIndex.receive_feed(feed, ok, text, problem)
	if not bool(received.get("ok", false)):
		_status(String(received.get("detail", "That source could not be read.")), _theme.error)
		return received
	_listings[feed] = received["entries"]
	_relist()
	if bool(received.get("stale", false)):
		_status("%s Showing the copy saved %s ago." % [
			received.get("problem", ""), PokeModIndex.age_text(int(received.get("age", 0)))
		], _theme.warning)
	else:
		_status(_listing_text(received), _theme.muted)
	return received


func _listing_text(received: Dictionary) -> String:
	var entries: Array = received["entries"]
	var source_name: String = String(received.get("name", ""))
	var line: String = "%s lists %d mod%s." % [
		source_name if not source_name.is_empty() else "That source",
		entries.size(), "" if entries.size() == 1 else "s",
	]
	var updates: int = PokeModIndex.update_count(entries, _installed_versions())
	if updates > 0:
		line += "  %d can be updated." % updates
	return line


func _installed_versions() -> Dictionary:
	var installed: Dictionary = {}
	for manifest: PokeModManifest in Gen2ModHost.instance().manifests():
		installed[manifest.id] = manifest.version
	return installed


## Downloads and installs one listed row, which is the same press for a mod that
## is absent, out of date, or reinstalled. [param finished] takes whether it landed.
func download(row: Dictionary, finished: Callable = Callable()) -> void:
	if not PokeModIndex.is_downloadable(String(row.get("download", ""))):
		_status("%s has no download in its source." % row.get("name", "That mod"), _theme.error)
		_settled(finished, false)
		return
	_pending = row.duplicate(true)
	_status("Downloading %s..." % row["name"], _theme.muted)
	var started: bool = _request(String(row["download"]), func(
		result: int, code: int, _headers: PackedStringArray, body: PackedByteArray
	) -> void:
		var pending: Dictionary = _pending
		_pending = {}
		if pending.is_empty():
			_settled(finished, false)
			return
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			_status("%s could not be downloaded (HTTP %d)." % [pending["name"], code], _theme.error)
			_settled(finished, false)
			return
		_settled(finished, bool(install_entry_bytes(pending, body).get("ok", false)))
	)
	if not started:
		_pending = {}
		_settled(finished, false)


func _settled(finished: Callable, ok: bool) -> void:
	if finished.is_valid():
		finished.call_deferred(ok)


## Installs a downloaded archive for [param row]. Separate from the request
## handler so the decision this makes can be tested without a server: the listed
## id must match, because a source names what it is offering and a download that
## turns out to be another mod is exactly what this refuses.
func install_entry_bytes(row: Dictionary, body: PackedByteArray) -> Dictionary:
	var installed: Dictionary = Gen2ModInstaller.install_bytes(
		body, bool(row.get("present", row.get("installed", false))), StringName(row["id"])
	)
	if not bool(installed.get("ok", false)):
		_status("%s was not installed: %s" % [
			row.get("name", row["id"]), PokeModRefusal.text(installed)
		], _theme.error)
		return installed
	_reload()
	refresh()
	_status("Installed %s." % installed.get("name", row.get("name", "")), _theme.accent)
	return installed


## Switches one mod on or off. The whole host is reloaded, because a
## registration cannot be withdrawn on its own.
func set_enabled(row: Dictionary, on: bool) -> void:
	var id := StringName(row["id"])
	if not Gen2ModState.set_enabled(id, on):
		_status("That switch could not be written to %s." % Gen2ModState.PATH, _theme.error)
		return
	_reload()
	refresh()
	_status("%s is %s." % [row["name"], "on" if on else "off"], _theme.muted)


## Removes one mod. A mod a source lists stays in the list and can be downloaded
## again; a mod that came from a file is gone, so that one is confirmed first.
func remove_mod(row: Dictionary) -> void:
	if not Gen2ModCatalogue.removal_is_permanent(row):
		_remove_now(row)
		return
	var sheet: Gen2LauncherSheet = Gen2LauncherSheet.create(_theme, "Delete mod")
	sheet.body().add_child(Gen2LauncherUI.muted(
		_theme,
		"%s came from a file rather than a source, so deleting it cannot be undone."
			% row["name"],
	))
	var confirm: Gen2LauncherButton = Gen2LauncherButton.create(
		_theme, "Delete", Gen2LauncherButton.Variant.DANGER, &"trash"
	)
	confirm.pressed.connect(func() -> void:
		sheet.close()
		_remove_now(row)
	)
	sheet.add_action(confirm)
	sheet.open(_host if _host != null else self)


func _remove_now(row: Dictionary) -> void:
	if not bool(Gen2ModInstaller.uninstall(StringName(row["id"])).get("ok", false)):
		_status("%s could not be removed." % row["name"], _theme.error)
		return
	_reload()
	# A listed mod keeps its row and offers a download again, which is what the
	# list rebuild produces on its own; one from a file has no row left, so the
	# page it was opened from is gone with it.
	if _detail != null and _detail.visible and _row_for(StringName(row["id"])).is_empty():
		show_list()
	else:
		refresh()
	_status("%s was removed." % row["name"], _theme.muted)


## The host reload behind any change. Without a runtime there is no host to
## reload and rediscovering is all the list needs, which is what a page built by
## a test or a preview gets.
func _reload() -> void:
	var runtime: Gen2GameRuntime = Gen2GameRuntime.instance()
	if runtime == null:
		Gen2ModHost.instance().discover()
		return
	runtime.reload_mods()


func _request(url: String, handler: Callable) -> bool:
	if not PokeModIndex.is_downloadable(url):
		_status("That address is not an https URL.", _theme.error)
		return false
	if _http == null or _busy:
		return false
	for connection: Dictionary in _http.request_completed.get_connections():
		_http.request_completed.disconnect(connection["callable"])
	_http.request_completed.connect(func(
		result: int, code: int, headers: PackedStringArray, body: PackedByteArray
	) -> void:
		_busy = false
		handler.call(result, code, headers, body)
	, CONNECT_ONE_SHOT)
	_busy = true
	if _http.request(url) != OK:
		_busy = false
		_status("Could not reach %s." % url, _theme.error)
		return false
	return true


## The square for one row, and the one place that decides where its picture
## comes from: the installed copy's own file first, then whatever the source
## already handed over, and the network only for a listing whose icon is not on
## disk yet.
func _icon_square(row: Dictionary) -> Control:
	var texture: Texture2D = PokeModArt.icon_texture(String(row.get("icon", "")))
	var url: String = String(row.get("icon_url", ""))
	if texture == null and not url.is_empty():
		texture = PokeModArt.cached_icon(url)
	var square: Control = Gen2LauncherUI.mod_icon(_theme, texture)
	if texture == null and PokeModArt.wants_fetch(url) and not _icon_targets.has(url):
		# Only a TextureRect can be filled in later, and a square with no picture
		# is the fallback glyph. It is replaced through its parent instead.
		_icon_targets[url] = square
		_icon_queue.append(url)
	return square


## The icon queue is left standing until the page is on screen, and every icon
## it holds is asked for here. Nothing else starts a request on its own; see
## [method _may_fetch_unprompted] for which runs are allowed to.
func _ready() -> void:
	_fetch_next_icon()
	# The page is built before it is in the tree, so the first `refresh` cannot
	# make a request. This is the one that reads the built-in source.
	_read_unread_sources()


func _fetch_next_icon() -> void:
	if _icon_busy or _icon_queue.is_empty() or _icons == null:
		return
	if not _may_fetch_unprompted():
		return
	var url: String = _icon_queue.pop_front()
	_icon_busy = true
	if _icons.request(url) != OK:
		_icon_busy = false
		_icon_targets.erase(url)
		_fetch_next_icon()
		return
	_icon_pending = url


func _on_icon_arrived(
	result: int, code: int, _headers: PackedStringArray, body: PackedByteArray
) -> void:
	var url: String = _icon_pending
	_icon_pending = ""
	_icon_busy = false
	# A missing icon is not a failure worth telling anyone about: the row keeps
	# its glyph and nothing is retried until the list is built again.
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var texture: Texture2D = PokeModArt.icon_texture_from_bytes(body)
		if texture != null:
			PokeModArt.cache_icon(url, body)
			_place_icon(url, texture)
	_icon_targets.erase(url)
	_fetch_next_icon()


## Puts an arrived picture in the square that was drawn for it, replacing the
## fallback glyph in place so the row does not move.
func _place_icon(url: String, texture: Texture2D) -> void:
	var square: Variant = _icon_targets.get(url, null)
	if square is not Control or not (square as Control).is_inside_tree():
		return
	var control: Control = square as Control
	if Gen2LauncherUI.set_mod_icon(control, texture):
		return
	var parent: Node = control.get_parent()
	var art: Control = Gen2LauncherUI.mod_icon(_theme, texture)
	parent.add_child(art)
	parent.move_child(art, control.get_index())
	parent.remove_child(control)
	control.queue_free()
	_icon_targets[url] = art


func _status(message: String, colour: Color) -> void:
	_note.text = message
	_note.add_theme_color_override("font_color", colour)
	if colour == _theme.error:
		Gen2LauncherAudio.play(&"error")
	if _sources != null:
		_sources.set_status(message, colour)
	if _detail != null:
		_detail.set_status(message, colour)


## What the page is telling the player, for a test that wants to read what they
## would see.
func status_text() -> String:
	return _note.text
