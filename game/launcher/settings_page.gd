class_name Gen2SettingsPage
extends BoxContainer

## Edits [Gen2Options] in five sections: how the launcher looks, how the app
## behaves, the controls, the rules a run is created with, and the cartridge's
## own OPTION menu. Every change writes immediately, because a half-applied file
## is worse than none. One section shows at a time, from a rail beside the rows
## on a wide window and a strip above them on a narrow one: five cards in one
## pane was forty focus stops from the first row to the last.

signal appearance_changed

## Label, then the values in the order the source cycles them.
const TEXT_SPEEDS: Array[String] = ["Fast", "Mid", "Slow"]
const PRINTER_LABELS: Array[String] = ["Lightest", "Lighter", "Normal", "Darker", "Darkest"]
## [constant Gen2Rules.MODES], in its order. Written out rather than capitalized
## from the names, which would say "Qol".
const RULE_MODES: Array[String] = ["Current", "Vanilla", "QoL"]
## What each mode answers, said once. [constant Gen2Rules.MODE_CURRENT]'s row
## counts the table rather than describing it, so a flag added later cannot leave
## this sentence wrong.
const RULE_MODE_TEXT: Dictionary = {
	Gen2Rules.MODE_CURRENT: "what this port ships",
	Gen2Rules.MODE_VANILLA: "every one of them reproduced, cartridge for cartridge",
	Gen2Rules.MODE_QOL: "every one of them corrected",
	Gen2Rules.MODE_CUSTOM: "your own picks",
}

const SECTIONS: Array[Dictionary] = [
	{"id": &"look", "label": "Appearance", "glyph": &"palette"},
	{"id": &"app", "label": "Application", "glyph": &"display"},
	{"id": &"controls", "label": "Controls", "glyph": &"pad"},
	{"id": &"rules", "label": "Gameplay", "glyph": &"sparkle"},
	{"id": &"game", "label": "In game", "glyph": &"text"},
]
const RAIL_WIDTH: float = 210.0
const ROWS_WIDTH: float = 760.0

var _theme: Gen2LauncherTheme = null
var _options: Gen2Options = null
var _saved: Label = null
## Where a modal opens. The launcher root rather than this page, so a sheet
## covers the bars as well and is not clipped by the settings scroll.
var _host: Control = null
## The line under the Bugs row, which names the mode the flags actually describe.
## Rewritten rather than rebuilt, because a mode press must not rebuild the row
## the press came from.
var _rules_summary: Label = null
var _rail: BoxContainer = null
var _panes: Dictionary = {}
var _tabs: Dictionary = {}
var _current: StringName = &"look"
var _compact: bool = false


static func create(palette: Gen2LauncherTheme, host: Control = null) -> Gen2SettingsPage:
	var page := Gen2SettingsPage.new()
	page._theme = palette
	page._options = Gen2OptionsStore.current()
	page._host = host
	page._build()
	return page


func _build() -> void:
	add_theme_constant_override("separation", Gen2LauncherUI.GAP_LG)
	_rail = BoxContainer.new()
	_rail.add_theme_constant_override("separation", Gen2LauncherUI.GAP_XS)
	_rail.custom_minimum_size.x = RAIL_WIDTH
	add_child(_rail)

	var body: VBoxContainer = Gen2LauncherUI.column(Gen2LauncherUI.GAP_MD)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)
	_saved = Gen2LauncherUI.muted(_theme, "Changes are written as you make them.")
	body.add_child(_saved)
	var scroll: Gen2LauncherScroll = Gen2LauncherScroll.create()
	body.add_child(scroll)
	var stack: MarginContainer = MarginContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.resized.connect(func() -> void: stack.add_theme_constant_override(
		"margin_right", int(maxf(stack.size.x - ROWS_WIDTH, 0.0))
	))
	scroll.add_child(stack)

	for section: Dictionary in SECTIONS:
		var id := StringName(section["id"])
		var pane: VBoxContainer = Gen2LauncherUI.column(Gen2LauncherUI.GAP_SM)
		pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pane.visible = false
		stack.add_child(pane)
		_panes[id] = pane
		var tab: Gen2LauncherButton = Gen2LauncherButton.create(
			_theme, String(section["label"]), Gen2LauncherButton.Variant.SEGMENT,
			StringName(section["glyph"])
		)
		tab.custom_minimum_size.y = Gen2LauncherUI.TOUCH_TARGET
		tab.pressed.connect(select_section.bind(id))
		_rail.add_child(tab)
		_tabs[id] = tab

	_build_look(_panes[&"look"])
	_build_app(_panes[&"app"])
	_build_controls(_panes[&"controls"])
	_build_rules(_panes[&"rules"])
	_build_game(_panes[&"game"])
	for pane: StringName in _panes:
		(_panes[pane] as VBoxContainer).add_child(Gen2LauncherUI.bottom_safe_space())
	_apply_rail()
	select_section(_current)


func focus_target() -> Control:
	return _tabs[_current]


func select_section(id: StringName) -> void:
	if not _panes.has(id):
		return
	_current = id
	for key: StringName in _panes:
		(_panes[key] as Control).visible = key == id
		(_tabs[key] as Gen2LauncherButton).set_active(key == id)


func current_section() -> StringName:
	return _current


func set_compact(compact: bool) -> void:
	if compact == _compact:
		return
	_compact = compact
	_apply_rail()


func _apply_rail() -> void:
	vertical = _compact
	_rail.vertical = not _compact
	_rail.custom_minimum_size.x = 0.0 if _compact else RAIL_WIDTH
	# Stacked, the strip is worth its own height; beside the rows, the column.
	_rail.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if _compact \
		else Control.SIZE_EXPAND_FILL
	for id: StringName in _tabs:
		var tab := _tabs[id] as Gen2LauncherButton
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _compact \
			else Control.SIZE_FILL
		tab.text = "" if _compact else String(_label_of(id))


func _label_of(id: StringName) -> String:
	for section: Dictionary in SECTIONS:
		if StringName(section["id"]) == id:
			return String(section["label"])
	return ""


func _build_look(pane: VBoxContainer) -> void:
	pane.add_child(Gen2LauncherUI.choice(
		_theme, &"palette", "Theme", ["Light", "Dark"],
		Gen2Options.UI_THEMES.find(_options.ui_theme),
		func(index: int) -> void:
			_options.ui_theme = Gen2Options.UI_THEMES[index]
			_persist()
			appearance_changed.emit(),
		_host
	))
	pane.add_child(Gen2LauncherUI.choice(
		_theme, &"pad", "Controller letters", _titles(Gen2InputActions.PAD_LAYOUTS),
		maxi(Gen2InputActions.PAD_LAYOUTS.find(_options.pad_layout), 0),
		func(index: int) -> void:
			_options.pad_layout = Gen2InputActions.PAD_LAYOUTS[index]
			_persist()
			Gen2InputRuntime.instance().apply_options(_options),
		_host
	))
	pane.add_child(Gen2LauncherUI.muted(
		_theme,
		"Every button this launcher names is drawn with the letter your own pad "
		+ "prints. Auto reads the pad that is plugged in; Nintendo puts A to the "
		+ "right, and Xbox puts it at the bottom."
	))


func _build_app(pane: VBoxContainer) -> void:
	pane.add_child(Gen2LauncherUI.level(
		_theme, &"volume", "Music volume", _options.music_volume, 0, Gen2Options.MAX_VOLUME,
		func(value: int) -> void:
			_options.music_volume = value
			_persist()
	))
	pane.add_child(Gen2LauncherUI.level(
		_theme, &"volume", "Sound volume", _options.sfx_volume, 0, Gen2Options.MAX_VOLUME,
		func(value: int) -> void:
			_options.sfx_volume = value
			_persist()
	))
	pane.add_child(Gen2LauncherUI.choice(
		_theme, &"display", "Window", _titles(Gen2Options.VIDEO_MODES),
		maxi(Gen2Options.VIDEO_MODES.find(_options.video_mode), 0),
		func(index: int) -> void:
			_options.video_mode = Gen2Options.VIDEO_MODES[index]
			_persist(),
		_host
	))
	pane.add_child(Gen2LauncherUI.choice(
		_theme, &"display", "Screen", ["Framed", "Fill"], 1 if _options.screen_fill else 0,
		func(index: int) -> void:
			_options.screen_fill = index == 1
			_persist(),
		_host
	))
	pane.add_child(Gen2LauncherUI.muted(
		_theme,
		"Fill gives every screen the whole window instead of black bars. The "
		+ "overworld draws the connected maps around this one; every other screen "
		+ "carries its own background out to the edge. Menus and boxes stay where "
		+ "the hardware put them. Zoom with + and - while walking."
	))
	pane.add_child(Gen2LauncherUI.choice(
		_theme, &"display", "Scrolling", ["Hardware", "Smooth"],
		1 if _options.smooth_scroll else 0,
		func(index: int) -> void:
			_options.smooth_scroll = index == 1
			_persist(),
		_host
	))
	pane.add_child(Gen2LauncherUI.muted(
		_theme,
		"The overworld moves two pixels at a time, once every two frames, which "
		+ "is what a Game Boy did and what its screen smeared over. Smooth draws "
		+ "the frame in between, so the map moves a pixel a frame and lands on "
		+ "the same pixel the hardware did. Nothing in the game is timed "
		+ "differently either way."
	))
	pane.add_child(Gen2LauncherUI.choice(
		_theme, &"display", "Second screen", _titles(Gen2Options.SECOND_SCREENS),
		maxi(Gen2Options.SECOND_SCREENS.find(_options.second_screen), 0),
		func(index: int) -> void:
			_options.second_screen = Gen2Options.SECOND_SCREENS[index]
			_persist(),
		_host
	))
	pane.add_child(Gen2LauncherUI.muted(
		_theme,
		"A handheld with a lower panel gets the map, the team, the pack, the "
		+ "Pokedex and the trainer card on it, with a row of tabs to pick between "
		+ "them. It is a view: nothing on it takes a button, and a page appears "
		+ "only once the START menu would have offered it. Window opens the same "
		+ "panel in a desktop window instead."
	))
	pane.add_child(Gen2LauncherUI.choice(
		_theme, &"speed", "Game speed", _titles(Gen2Options.GAME_SPEEDS),
		maxi(Gen2Options.GAME_SPEEDS.find(_options.game_speed), 0),
		func(index: int) -> void:
			_options.game_speed = Gen2Options.GAME_SPEEDS[index]
			_persist(),
		_host
	))
	var fps_labels: Array[String] = []
	for fps: int in Gen2Options.FPS_CHOICES:
		fps_labels.append("Display" if fps == 0 else str(fps))
	pane.add_child(Gen2LauncherUI.choice(
		_theme, &"speed", "Frame rate", fps_labels,
		maxi(Gen2Options.FPS_CHOICES.find(_options.max_fps), 0),
		func(index: int) -> void:
			_options.max_fps = Gen2Options.FPS_CHOICES[index]
			_persist(),
		_host
	))
	pane.add_child(Gen2LauncherUI.muted(
		_theme,
		"Display draws one frame per refresh, which is the only setting whose "
		+ "frames each reach the panel once. A number below the panel's own rate "
		+ "is a sleep and not a refresh, so the same picture is shown for one "
		+ "refresh, then three, then two, and walking stutters however even the "
		+ "game is underneath. Pick one only to save battery."
	))


func _build_controls(pane: VBoxContainer) -> void:
	var section: Gen2ControlsSection = Gen2ControlsSection.create(
		_theme, _options, _host if _host != null else self
	)
	section.changed.connect(func() -> void:
		_persist()
		Gen2InputRuntime.instance().apply_options(_options)
	)
	section.arrange_requested.connect(_open_touch_layout)
	pane.add_child(section)


func _build_rules(pane: VBoxContainer) -> void:
	pane.add_child(Gen2LauncherUI.muted(
		_theme,
		"Generation II shipped with bugs, and this port can play them either way. "
		+ "A run keeps the rules it was created with, so changing these affects "
		+ "the next new game rather than a save already in progress."
	))
	pane.add_child(Gen2LauncherUI.choice(
		_theme, &"bug", "Bugs", RULE_MODES, maxi(Gen2Rules.MODES.find(_options.rules.mode), 0),
		func(index: int) -> void:
			_options.rules.set_mode(Gen2Rules.MODES[index])
			_refresh_rules()
			_persist(),
		_host
	))
	_rules_summary = Gen2LauncherUI.muted(_theme, "")
	pane.add_child(_rules_summary)
	var listing: Gen2LauncherButton = Gen2LauncherButton.create(
		_theme, "Which bugs...", Gen2LauncherButton.Variant.QUIET
	)
	# Wide as its own words, not as the pane: a secondary action stretched from
	# edge to edge reads as a field to type in rather than something to press.
	listing.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	listing.pressed.connect(_open_rules_sheet)
	pane.add_child(listing)
	_refresh_rules()
	## Vanilla, Hard and Nuzlocke are NOT here. A challenge decides what a run
	## did rather than how this machine plays it, and one that could be switched
	## off after a death would not be a challenge: it is chosen once, on the
	## save screen, when the game is created.
	pane.add_child(Gen2LauncherUI.muted(
		_theme,
		"Vanilla, Hard and Nuzlocke are picked when you start a new game, on the "
		+ "save screen. A run keeps the one it was created with for good."
	))


func _build_game(pane: VBoxContainer) -> void:
	pane.add_child(Gen2LauncherUI.muted(
		_theme, "These are the cartridge's own OPTION menu, kept as the same bytes."
	))
	pane.add_child(Gen2LauncherUI.choice(
		_theme, &"text", "Text speed", TEXT_SPEEDS, _options.text_speed,
		func(index: int) -> void:
			_options.text_speed = index
			_persist(),
		_host
	))
	pane.add_child(Gen2LauncherUI.switch(
		_theme, &"sparkle", "Battle scene", _options.battle_scene,
		func(on: bool) -> void:
			_options.battle_scene = on
			_persist()
	))
	pane.add_child(Gen2LauncherUI.choice(
		_theme, &"pad", "Battle style", ["Shift", "Set"], 1 if _options.battle_style_set else 0,
		func(index: int) -> void:
			_options.battle_style_set = index == 1
			_persist(),
		_host
	))
	pane.add_child(Gen2LauncherUI.choice(
		_theme, &"volume", "Sound", ["Mono", "Stereo"], 1 if _options.stereo else 0,
		func(index: int) -> void:
			_options.stereo = index == 1
			_persist(),
		_host
	))
	pane.add_child(Gen2LauncherUI.level(
		_theme, &"text", "Text frame", _options.textbox_frame, 0, Gen2Options.FRAME_COUNT - 1,
		func(value: int) -> void:
			_options.textbox_frame = value
			_persist(),
		func(value: int) -> String: return "Type %d" % (value + 1)
	))
	pane.add_child(Gen2LauncherUI.switch(
		_theme, &"text", "Menu account", _options.menu_account,
		func(on: bool) -> void:
			_options.menu_account = on
			_persist()
	))
	pane.add_child(Gen2LauncherUI.choice(
		_theme, &"display", "Print", PRINTER_LABELS, _options.printer_brightness,
		func(index: int) -> void:
			_options.printer_brightness = index
			_persist(),
		_host
	))
	## The one row here that changes nothing you can see. It is the cartridge's
	## own PRINT byte and is kept because the block is kept whole; the Game Boy
	## Printer is a real peripheral with no path to a modern device, so the
	## Pokedex's own PRINT does nothing, exactly as `.Print` does without one.
	pane.add_child(Gen2LauncherUI.muted(
		_theme,
		"Print sets the Game Boy Printer's darkness. Nothing here can print, so "
		+ "this only keeps the byte the cartridge stored."
	))


## Test and screen seam: what the Bugs row says and what the sheet lists, from
## one place so the two cannot disagree. `mode` is what the flags describe rather
## than what was last pressed, which is `custom` once one has been moved.
func rules_snapshot() -> Dictionary:
	var rules: Gen2Rules = _options.rules
	var mode: StringName = rules.mode_of()
	var flags: Array = []
	var reproduced: int = 0
	for flag: StringName in Gen2Rules.FLAGS:
		var on: bool = rules.reproduces(flag)
		reproduced += 1 if on else 0
		var text: Dictionary = Gen2Rules.FLAG_TEXT.get(flag, {})
		flags.append({
			"flag": flag, "on": on,
			"title": String(text.get("title", "")),
			"detail": String(text.get("detail", "")),
		})
	return {
		"mode": mode,
		"summary": "%s: %s. %d of %d bugs reproduced." % [
			String(mode).capitalize(), String(RULE_MODE_TEXT.get(mode, "")),
			reproduced, flags.size(),
		],
		"flags": flags,
	}


func _refresh_rules() -> void:
	if _rules_summary == null:
		return
	_rules_summary.text = String(rules_snapshot()["summary"])


func _set_rule_flag(flag: StringName, reproduce_hardware: bool) -> void:
	_options.rules.set_flag(flag, reproduce_hardware)
	_refresh_rules()
	_persist()


## The five bugs themselves, each with what the cartridge does and a switch. The
## model has carried per-flag overrides and a `custom` mode since it was written
## and nothing reached them, so a player could pick an end of the table and not
## see what was in it.
func _open_rules_sheet() -> void:
	var rules: Gen2Rules = _options.rules
	var sheet: Gen2LauncherSheet = Gen2LauncherSheet.create(_theme, "Bugs and glitches")
	sheet.body().add_child(Gen2LauncherUI.muted(
		_theme, "On reproduces the cartridge. Off is this port's corrected answer."
	))
	for row: Dictionary in rules_snapshot()["flags"] as Array:
		var flag := StringName(row["flag"])
		var entry: VBoxContainer = Gen2LauncherUI.column(2)
		sheet.body().add_child(entry)
		entry.add_child(Gen2LauncherUI.switch(
			_theme, &"bug", String(row["title"]), bool(row["on"]),
			func(on: bool) -> void: _set_rule_flag(flag, on)
		))
		entry.add_child(Gen2LauncherUI.muted(_theme, String(row["detail"])))
	var reset: Gen2LauncherButton = Gen2LauncherButton.create(
		_theme, "Back to %s" % String(rules.mode).capitalize(),
		Gen2LauncherButton.Variant.QUIET
	)
	reset.pressed.connect(func() -> void:
		rules.clear_flags()
		_refresh_rules()
		_persist()
		sheet.close()
	)
	sheet.add_action(reset)
	sheet.open(_host if _host != null else self)


func _open_touch_layout() -> void:
	var sheet: Gen2TouchLayoutSheet = Gen2TouchLayoutSheet.create(_theme, _options)
	sheet.closed.connect(_persist)
	sheet.open(_host if _host != null else self)


func _titles(values: Array) -> Array[String]:
	var out: Array[String] = []
	for value: Variant in values:
		out.append(String(value).capitalize())
	return out


func _persist() -> void:
	Gen2GameRuntime.apply_display_options(_options)
	var ok: bool = Gen2OptionsStore.save(_options)
	_saved.text = (
		"Saved." if ok else "The options file could not be written."
	)
	_saved.add_theme_color_override("font_color", _theme.muted if ok else _theme.error)
