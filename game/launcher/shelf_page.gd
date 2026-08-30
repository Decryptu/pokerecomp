class_name Gen2ShelfPage
extends VBoxContainer

## The launcher's home: the cartridge carousel and the plate under it naming
## whatever is in the middle. The page reports what was clicked and displays what
## it is told; every import, refusal and launch belongs to the launcher, and what
## can be done to a cartridge is said on the hint bar.

signal insert_requested(game_id: StringName)
signal play_requested(game_id: StringName)
signal manage_requested(game_id: StringName)
## The shell paints its backdrop for the selected cartridge.
signal selection_changed(game_id: StringName)
## What [method hints] would answer has changed; the shell owns the bar.
signal hints_changed

var _theme: Gen2LauncherTheme = null
var _stage: Gen2CartridgeStage = null
var _plate: Gen2LauncherCard = null
var _name: Label = null
var _state: Label = null
var _details: Dictionary = {}
var _compact: bool = false
var _busy: bool = false


static func create(palette: Gen2LauncherTheme, compact: bool) -> Gen2ShelfPage:
	var page := Gen2ShelfPage.new()
	page._theme = palette
	page._compact = compact
	page._build()
	return page


func _build() -> void:
	add_theme_constant_override("separation", Gen2LauncherUI.GAP_MD)

	_stage = Gen2CartridgeStage.create(_theme, RomRegistry.ORDER)
	_stage.selection_changed.connect(_on_selection_changed)
	_stage.insert_requested.connect(func(id: StringName) -> void: insert_requested.emit(id))
	_stage.play_requested.connect(func(id: StringName) -> void: play_requested.emit(id))
	add_child(_stage)
	add_child(_build_plate())
	add_child(Gen2LauncherUI.bottom_safe_space())
	_refresh_plate()


## The name of whatever is in the middle, and a line for its state. A chip
## because it stands on the artwork behind the shelf, not on a page colour.
func _build_plate() -> Control:
	var centre := CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate = Gen2LauncherCard.chip(_theme, Gen2LauncherTheme.RADIUS_PILL, 14, 16)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(_plate)
	var column: VBoxContainer = Gen2LauncherUI.column(0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_child(column)
	_name = Gen2LauncherUI.title(_theme, "", Gen2LauncherTheme.FONT_TITLE)
	_name.add_theme_color_override("font_color", _theme.on_surface)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_name)
	_state = Gen2LauncherUI.tag(_theme, "")
	_state.add_theme_color_override("font_color", _theme.with_alpha(_theme.on_surface, 0.7))
	_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_state)
	return centre


func stage() -> Gen2CartridgeStage:
	return _stage


## Where a keyboard or a pad starts on this page: the carousel, which is what the
## page is about and what ui_left and ui_right then turn.
func focus_target() -> Control:
	return _stage


func hints() -> Array:
	if _busy:
		return []
	var id: StringName = _stage.selected_id()
	var card: Gen2Cartridge = _stage.selected_cartridge()
	var playable: bool = card != null and card.imported
	var entries: Array = [{
		"action": &"ui_accept",
		"label": "Play" if playable else "Add cartridge",
		"run": func() -> void:
			if playable:
				play_requested.emit(id)
			else:
				insert_requested.emit(id),
	}]
	if card != null and card.cache_state != RomCache.STATE_MISSING:
		entries.append({
			"action": &"ui_menu",
			"label": "Options",
			"run": func() -> void: manage_requested.emit(id),
		})
	return entries


func cartridge(game_id: StringName) -> Gen2Cartridge:
	return _stage.cartridge(game_id)


func selected_id() -> StringName:
	return _stage.selected_id()


func set_slot_state(game_id: StringName, state: StringName, detail: String) -> void:
	_details[game_id] = detail
	_stage.set_cache_state(game_id, state, detail)
	_refresh_plate()
	hints_changed.emit()


## An import leaves nothing worth pressing, so the bar empties.
func set_busy(busy: bool) -> void:
	if busy == _busy:
		return
	_busy = busy
	hints_changed.emit()


## Moves the selection onto [param game_id], used after an import so the freshly
## seated cartridge is the one on show.
func focus_game(game_id: StringName) -> void:
	var index: int = RomRegistry.ORDER.find(game_id)
	if index >= 0:
		_stage.select(index)


func set_compact(compact: bool) -> void:
	if compact == _compact:
		return
	_compact = compact
	_refresh_plate()


func _on_selection_changed(game_id: StringName) -> void:
	_refresh_plate()
	selection_changed.emit(game_id)
	hints_changed.emit()


func _refresh_plate() -> void:
	var id: StringName = _stage.selected_id()
	if _name == null or id.is_empty():
		return
	_name.text = RomRegistry.title_for(id)
	_name.add_theme_font_size_override(
		"font_size", Gen2LauncherTheme.FONT_TITLE if _compact else Gen2LauncherTheme.FONT_DISPLAY
	)
	var detail: String = String(_details.get(id, ""))
	_state.text = detail if not detail.is_empty() else "Ready to play"
