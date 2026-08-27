class_name Gen2ShelfPage
extends VBoxContainer

## The launcher's home: the cartridge carousel and the one or two things you can
## do with whatever is in the middle of it.
##
## The page reports what was clicked and displays what it is told. Every import,
## refusal and launch belongs to the launcher.

signal insert_requested(game_id: StringName)
signal play_requested(game_id: StringName)
signal manage_requested(game_id: StringName)
## The shell paints its backdrop for the selected cartridge.
signal selection_changed(game_id: StringName)

## How much of the stage's height the band above the carousel may cost. The band
## is reserved rather than found, so a short window pays for it out of the
## cartridge. Past this share the cartridge has given up more than the button is
## worth and the button goes to the corner instead. A flat height cannot answer
## this: 600 px cornered the button on a 1920x600 window where the cartridge
## still had 130 px to spare below it.
const MANAGE_BAND_SHARE: float = 0.22

var _theme: Gen2LauncherTheme = null
var _stage: Gen2CartridgeStage = null
var _manage: Gen2LauncherButton = null
var _details: Dictionary = {}
var _compact: bool = false


static func create(palette: Gen2LauncherTheme, compact: bool) -> Gen2ShelfPage:
	var page := Gen2ShelfPage.new()
	page._theme = palette
	page._compact = compact
	page._build()
	return page


func _build() -> void:
	add_theme_constant_override("separation", Gen2LauncherUI.GAP_LG)

	_stage = Gen2CartridgeStage.create(_theme, RomRegistry.ORDER)
	_stage.selection_changed.connect(_on_selection_changed)
	_stage.insert_requested.connect(func(id: StringName) -> void: insert_requested.emit(id))
	_stage.play_requested.connect(func(id: StringName) -> void: play_requested.emit(id))

	_manage = Gen2LauncherButton.icon_only(
		_theme, &"dots", Gen2LauncherButton.Variant.DOCK, _action_side()
	)
	_manage.tooltip_text = "Cartridge options"
	_manage.pressed.connect(func() -> void: manage_requested.emit(_stage.selected_id()))
	add_child(_stage)
	_stage.add_child(_manage)
	_stage.resized.connect(_place_manage)
	_stage.layout_changed.connect(_place_manage)

	_refresh_action()
	_place_manage.call_deferred()


func stage() -> Gen2CartridgeStage:
	return _stage


## Where a keyboard or a pad starts on this page: the carousel, which is what the
## page is about and what ui_left and ui_right then turn.
func focus_target() -> Control:
	return _stage


func cartridge(game_id: StringName) -> Gen2Cartridge:
	return _stage.cartridge(game_id)


func selected_id() -> StringName:
	return _stage.selected_id()


func set_slot_state(game_id: StringName, imported: bool, detail: String) -> void:
	_details[game_id] = detail
	_stage.set_imported(game_id, imported)
	_refresh_action()


func set_busy(busy: bool) -> void:
	_manage.set_disabled_state(busy)


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
	_manage.set_side(_action_side())
	_sync_stage_inset()
	_place_manage.call_deferred()


func _on_selection_changed(game_id: StringName) -> void:
	_refresh_action()
	_place_manage.call_deferred()
	selection_changed.emit(game_id)


func _action_side() -> float:
	return Gen2LauncherUI.TOUCH_TARGET if _compact else Gen2LauncherButton.DOCK_SIDE


## Whether a stage of [param stage_size] sends the button to its corner rather
## than reserving [param band] above the carousel for it. Separate from the
## placement because the placement needs a real window behind it and this rule
## is the whole of what went wrong.
static func corners_manage(stage_size: Vector2, band: float) -> bool:
	return stage_size.x > stage_size.y and band > stage_size.y * MANAGE_BAND_SHARE


func _place_manage() -> void:
	if _stage == null or _manage == null:
		return
	var card: Gen2Cartridge = _stage.selected_cartridge()
	if card == null:
		return
	var band: float = _action_side() + Gen2LauncherUI.GAP_LG
	var cornered: bool = corners_manage(_stage.size, band)
	var side: float = Gen2LauncherUI.TOUCH_TARGET if cornered else _action_side()
	if not is_equal_approx(_manage.size.x, side):
		_manage.set_side(side)
	var inset: float = 0.0 if cornered or not _manage.visible else side + Gen2LauncherUI.GAP_LG
	if not is_equal_approx(_stage.top_inset, inset):
		_stage.set_top_inset(inset)
		return
	if cornered:
		# Clear of the edge, because a disc flush into the corner reads as
		# something that slipped rather than something placed there.
		_manage.position = Vector2(
			_stage.size.x - side - Gen2LauncherUI.GAP_MD, float(Gen2LauncherUI.GAP_MD)
		)
		_stage.move_child(_manage, _stage.get_child_count() - 1)
		return
	var gap: float = Gen2LauncherUI.GAP_MD + card.size.x * 0.05
	_manage.position = Vector2(
		(_stage.size.x - _manage.size.x) * 0.5,
		maxf(0.0, card.position.y - _manage.size.y - gap),
	)
	_stage.move_child(_manage, _stage.get_child_count() - 1)


func _refresh_action() -> void:
	var id: StringName = _stage.selected_id()
	var card: Gen2Cartridge = _stage.selected_cartridge()
	if card == null:
		return
	var title: String = RomRegistry.title_for(id)
	if card.imported:
		_manage.tooltip_text = "%s options. %s" % [title, _details.get(id, "Ready")]
	_manage.visible = card.imported
	_sync_stage_inset()


func _sync_stage_inset() -> void:
	if _stage == null or _manage == null:
		return
	_place_manage()
