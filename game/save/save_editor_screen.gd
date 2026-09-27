extends Control

## The save editor. Presentation only: every rule lives in [Gen2SaveEditor].
## Stock controls in [method Gen2LauncherTheme.control_theme], each row wrapping,
## since the screen opens at whatever size the window is.

## In drawing order, so a snapshot names a tab rather than an index.
const TABS: Array[StringName] = [&"party", &"boxes", &"items", &"events", &"map", &"dex"]
## `ItemNames`' filler for the item numbers no constant names.
const UNUSED_ITEM_NAME: String = "TERU-SAMA"

var _editor: Gen2SaveEditor = null
var _tabs: TabContainer = null
var _status: Label = null
var _validity: Label = null
var _party_list: ItemList = null
var _party_form: VBoxContainer = null
var _box_picker: OptionButton = null
var _box_list: ItemList = null
var _box_form: VBoxContainer = null
var _item_list: ItemList = null
var _item_rows: Array[int] = []
var _picked_item: int = 1
var _item_button: Button = null
var _item_set: Button = null
var _quantity_field: SpinBox = null
var _money_field: SpinBox = null
var _coins_field: SpinBox = null
var _flag_field: SpinBox = null
var _badge_boxes: Array[CheckBox] = []
var _map_fields: Dictionary = {}
var _dex_species: int = 1
## Pickers built before the save opened, named once it has.
var _relabel: Array[Callable] = []
var _dex_list: ItemList = null
var _selected_party: int = -1
var _selected_box: int = 0
var _selected_box_slot: int = -1
var _palette: Gen2LauncherTheme = null
var _margin: MarginContainer = null


func _ready() -> void:
	_build_ui()
	if _editor == null:
		_open_selected_slot()
	_refresh()
	Gen2FocusGuard.attach(self)


## Opens an explicit save. Tests and tools use this instead of relying on
## whatever the runtime happens to have selected.
func set_editor(editor: Gen2SaveEditor) -> void:
	_editor = editor
	if is_inside_tree():
		_refresh()


func _open_selected_slot() -> void:
	var data: GameData = GameData.open(GameRuntime.selected_game_id)
	if data == null or GameRuntime.selected_save_slot < 0:
		return
	var result: Dictionary = Gen2SaveStore.load_result(
		data.id, data.sha1, GameRuntime.selected_save_slot, data
	)
	if bool(result.get("ok", false)):
		_editor = Gen2SaveEditor.open(result["save"], data)


## A read-only view for tests, in the shape the other screens expose.
func editor_snapshot() -> Dictionary:
	if _editor == null:
		return {"open": false, "tab": &"", "valid": false}
	var validation: Dictionary = _editor.validate()
	var party: Array = []
	for mon: Gen2SaveMon in _editor.save.party:
		party.append({"species": mon.species, "level": mon.level, "hp": mon.hp})
	return {
		"open": true,
		"tab": TABS[_tabs.current_tab] if _tabs != null else &"",
		"valid": bool(validation["ok"]),
		"message": String(validation["message"]),
		"dirty": _editor.is_dirty(),
		"player_name": _editor.save.player_name,
		"label": _editor.save.label,
		"party": party,
		"selected_party": _selected_party,
		"selected_box": _selected_box,
		"selected_box_slot": _selected_box_slot,
		"has_world": _editor.has_world(),
	}


func select_party_member(index: int) -> bool:
	if _editor == null or index < 0 or index >= _editor.save.party.size():
		return false
	_selected_party = index
	_refresh_party_form()
	return true


func select_box_member(slot: int) -> bool:
	var box: Gen2SaveBox = _editor.box(_selected_box) if _editor != null else null
	if box == null or slot < 0 or slot >= box.slots.size() or box.slots[slot] == null:
		return false
	_selected_box_slot = slot
	_refresh_box_form()
	return true


func select_tab(tab: StringName) -> bool:
	var index: int = TABS.find(tab)
	if index < 0 or _tabs == null:
		return false
	_tabs.current_tab = index
	return true


func save_now() -> bool:
	if _editor == null:
		return false
	_commit_typing()
	if not _apply_pending_map():
		return false
	var result: Dictionary = _editor.commit()
	_set_status(String(result["message"]) if not result["ok"] else "Saved.")
	if result["ok"]:
		# The slot on disk changed under whatever the runtime is holding.
		GameRuntime.reload_selected_save()
	_refresh()
	return bool(result["ok"])


func reload_now() -> bool:
	if _editor == null:
		return false
	var result: Dictionary = Gen2SaveStore.load_result(
		_editor.save.game_id, _editor.save.rom_sha1, _editor.save.slot, _editor.data
	)
	if not bool(result.get("ok", false)):
		_set_status(String(result.get("message", "the slot could not be reloaded")))
		return false
	_editor = Gen2SaveEditor.open(result["save"], _editor.data)
	_selected_party = -1
	_selected_box_slot = -1
	_set_status("Reloaded from disk.")
	_refresh()
	return true


func _build_ui() -> void:
	_palette = Gen2LauncherTheme.active()
	theme = _palette.control_theme()
	var backdrop := ColorRect.new()
	backdrop.color = _palette.backdrop_bottom
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	## Drawn in launcher units like the pages it borrows its controls from, so it
	## needs the same factor: without it every word here arrived on a phone at a
	## third of its size. See [method Gen2LauncherUI.attach_density].
	Gen2LauncherUI.attach_density(self)

	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	_apply_margins()
	resized.connect(_apply_margins)
	var margin: MarginContainer = _margin

	var root: VBoxContainer = Gen2LauncherUI.column(Gen2LauncherUI.GAP_MD)
	margin.add_child(root)

	var header: HFlowContainer = Gen2LauncherUI.actions()
	root.add_child(header)
	header.add_child(Gen2LauncherUI.title(
		_palette, "Save editor", Gen2LauncherTheme.FONT_TITLE
	))
	_validity = Gen2LauncherUI.tag(_palette, "")
	_validity.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_validity)
	header.add_child(_action("Reload", reload_now))
	header.add_child(_action("Save", save_now))
	header.add_child(_action("Close", _close))

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_tabs)
	for page: Control in [
		_build_party_tab(), _build_boxes_tab(), _build_items_tab(),
		_build_events_tab(), _build_map_tab(), _build_dex_tab(),
	]:
		_tabs.add_child(_scrolled(page))
	for index: int in TABS.size():
		_tabs.set_tab_title(index, String(TABS[index]).capitalize())

	_status = Gen2LauncherUI.muted(_palette, "")
	root.add_child(_status)


## Standing off the notch and the home indicator as [Gen2LauncherShell] does.
func _apply_margins() -> void:
	if _margin == null:
		return
	var insets: Dictionary = Gen2LauncherUI.safe_area_insets(get_window())
	var narrow: bool = size.x < Gen2LauncherShell.COMPACT_WIDTH
	var pad: int = Gen2LauncherUI.GAP_SM if narrow else Gen2LauncherUI.GAP_LG
	_margin.add_theme_constant_override("margin_left", pad + int(insets["left"]))
	_margin.add_theme_constant_override("margin_right", pad + int(insets["right"]))
	_margin.add_theme_constant_override("margin_top", pad + int(insets["top"]))
	_margin.add_theme_constant_override("margin_bottom", pad + int(insets["bottom"]))


func _scrolled(page: Control) -> Control:
	var scroll: Gen2LauncherScroll = Gen2LauncherScroll.create()
	scroll.name = page.name
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.content().add_child(page)
	return scroll


func _build_party_tab() -> Control:
	var page: HFlowContainer = Gen2LauncherUI.actions(Gen2LauncherUI.GAP_MD)
	page.name = "Party"

	var left: VBoxContainer = Gen2LauncherUI.column(Gen2LauncherUI.GAP_SM)
	left.custom_minimum_size = Vector2(260, 320)
	page.add_child(left)
	_party_list = ItemList.new()
	_party_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_party_list.item_selected.connect(func(index: int) -> void: select_party_member(index))
	left.add_child(_party_list)

	left.add_child(_add_row(
		func(species: int, level: int) -> Dictionary:
			return _editor.add_party_member(species, level),
		func() -> void:
			_apply(_editor.remove_party_member(_selected_party))
			_selected_party = -1
	))

	_party_form = _form_column()
	page.add_child(_party_form)
	return page


func _add_row(add: Callable, remove: Callable) -> HFlowContainer:
	var row: HFlowContainer = Gen2LauncherUI.actions()
	var species: Array[int] = [1]
	var species_button: Button = _action("", func() -> void: pass)
	_relabel.append(func() -> void: species_button.text = _named(&"species", species[0]))
	species_button.pressed.connect(func() -> void:
		_pick("Species", &"species", species[0], func(picked: int) -> void:
			species[0] = picked
			species_button.text = _named(&"species", picked)
		)
	)
	row.add_child(species_button)
	var level_field := SpinBox.new()
	level_field.min_value = 1
	level_field.max_value = Gen2Experience.MAX_LEVEL
	level_field.value = 5
	row.add_child(level_field)
	row.add_child(_action("Add", func() -> void:
		_apply(add.call(species[0], int(level_field.value)))
	))
	row.add_child(_action("Remove", remove))
	return row


func _form_column() -> VBoxContainer:
	var form: VBoxContainer = Gen2LauncherUI.column(Gen2LauncherUI.GAP_SM)
	form.custom_minimum_size = Vector2(260, 0)
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return form


func _build_boxes_tab() -> Control:
	var page: VBoxContainer = Gen2LauncherUI.column(Gen2LauncherUI.GAP_SM)
	page.name = "Boxes"
	_box_picker = OptionButton.new()
	for index: int in Gen2SaveData.BOX_COUNT:
		_box_picker.add_item("Box %d" % (index + 1), index)
	_box_picker.item_selected.connect(func(index: int) -> void:
		_selected_box = index
		_selected_box_slot = -1
		_refresh_boxes()
	)
	page.add_child(_box_picker)
	page.add_child(_add_row(
		func(species: int, level: int) -> Dictionary:
			return _editor.add_box_member(_selected_box, species, level),
		func() -> void:
			_apply(_editor.remove_box_member(_selected_box, _selected_box_slot))
			_selected_box_slot = -1
	))

	var split: HFlowContainer = Gen2LauncherUI.actions(Gen2LauncherUI.GAP_MD)
	page.add_child(split)
	_box_list = _page_list()
	_box_list.custom_minimum_size = Vector2(260, 0)
	_box_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box_list.item_selected.connect(func(slot: int) -> void:
		if not select_box_member(slot):
			_selected_box_slot = -1
			_refresh_box_form()
	)
	split.add_child(_box_list)
	_box_form = _form_column()
	split.add_child(_box_form)
	return page


func _build_items_tab() -> Control:
	var page: VBoxContainer = Gen2LauncherUI.column(Gen2LauncherUI.GAP_SM)
	page.name = "Items"

	var money_row: HFlowContainer = Gen2LauncherUI.actions()
	page.add_child(money_row)
	money_row.add_child(_label("Money"))
	_money_field = SpinBox.new()
	_money_field.max_value = Gen2WorldInventory.MAX_MONEY
	_money_field.value_changed.connect(func(value: float) -> void:
		_apply(_editor.set_money(0, int(value)), false)
	)
	money_row.add_child(_money_field)
	money_row.add_child(_label("Coins"))
	_coins_field = SpinBox.new()
	_coins_field.max_value = Gen2WorldInventory.MAX_COINS
	_coins_field.value_changed.connect(func(value: float) -> void:
		_apply(_editor.set_coins(int(value)), false)
	)
	money_row.add_child(_coins_field)

	var item_row: HFlowContainer = Gen2LauncherUI.actions()
	page.add_child(item_row)
	_item_button = _action("", func() -> void:
		_pick("Item", &"item", _picked_item, _pick_item)
	)
	item_row.add_child(_item_button)
	_quantity_field = SpinBox.new()
	_quantity_field.max_value = Gen2WorldPack.MAX_ITEM_STACK
	_quantity_field.value = 1
	item_row.add_child(_quantity_field)
	_item_set = _action("Add", func() -> void:
		_apply(_editor.set_item_quantity(_picked_item, int(_quantity_field.value)))
	)
	item_row.add_child(_item_set)
	item_row.add_child(_action("Remove", func() -> void:
		var picked: PackedInt32Array = _item_list.get_selected_items()
		if not picked.is_empty() and picked[0] < _item_rows.size():
			_apply(_editor.remove_item(_item_rows[picked[0]]))
	))

	_item_list = _page_list()
	_item_list.item_selected.connect(_pick_bag_row)
	page.add_child(_item_list)
	return page


## As tall as its rows, since the tab itself scrolls.
func _page_list() -> ItemList:
	var list := ItemList.new()
	list.auto_height = true
	return list


func _pick_bag_row(index: int) -> void:
	if index >= _item_rows.size():
		return
	_pick_item(_item_rows[index])


func _pick_item(item: int) -> void:
	_picked_item = item
	_item_button.text = _named(&"item", item)
	var held: int = _editor.save.world.world_state.item_quantity(item) if _editor.has_world() else 0
	_quantity_field.set_value_no_signal(held if held > 0 else 1)
	_item_set.text = "Set" if held > 0 else "Add"


func _build_events_tab() -> Control:
	var page: VBoxContainer = Gen2LauncherUI.column(Gen2LauncherUI.GAP_SM)
	page.name = "Events"

	var badges: HFlowContainer = Gen2LauncherUI.actions()
	page.add_child(badges)
	_badge_boxes = []
	for index: int in Gen2WorldState.BADGE_ENGINE_FLAGS.size():
		var box := CheckBox.new()
		box.text = "Badge %d" % (index + 1)
		box.toggled.connect(func(pressed: bool) -> void: _set_badge(index, pressed))
		badges.add_child(box)
		_badge_boxes.append(box)

	var flag_row: HFlowContainer = Gen2LauncherUI.actions()
	page.add_child(flag_row)
	flag_row.add_child(_label("Event flag"))
	_flag_field = SpinBox.new()
	_flag_field.max_value = 4095
	flag_row.add_child(_flag_field)
	flag_row.add_child(_action("Set", func() -> void:
		_apply(_editor.set_event_flag(int(_flag_field.value), true))
	))
	flag_row.add_child(_action("Clear", func() -> void:
		_apply(_editor.set_event_flag(int(_flag_field.value), false))
	))
	return page


func _build_map_tab() -> Control:
	var page: VBoxContainer = Gen2LauncherUI.column(Gen2LauncherUI.GAP_SM)
	page.name = "Map"
	for field: String in ["group", "number", "x", "y"]:
		var row: HFlowContainer = Gen2LauncherUI.actions()
		page.add_child(row)
		row.add_child(_label(field.capitalize()))
		var spin := SpinBox.new()
		spin.max_value = 999
		row.add_child(spin)
		_map_fields[field] = spin
	page.add_child(_action("Move player", _apply_position))

	for field: String in ["day", "hour", "minute"]:
		var row: HFlowContainer = Gen2LauncherUI.actions()
		page.add_child(row)
		row.add_child(_label(field.capitalize()))
		var spin := SpinBox.new()
		spin.max_value = 59
		row.add_child(spin)
		_map_fields[field] = spin
	page.add_child(_action("Set clock", func() -> void:
		_apply(_editor.set_clock(
			int(_map_fields["day"].value),
			int(_map_fields["hour"].value),
			int(_map_fields["minute"].value),
		))
	))
	return page


func _build_dex_tab() -> Control:
	var page: VBoxContainer = Gen2LauncherUI.column(Gen2LauncherUI.GAP_SM)
	page.name = "Dex"
	var row: HFlowContainer = Gen2LauncherUI.actions()
	page.add_child(row)
	var species_button: Button = _action("", func() -> void: pass)
	_relabel.append(func() -> void: species_button.text = _named(&"species", _dex_species))
	species_button.pressed.connect(func() -> void:
		_pick("Species", &"species", _dex_species, func(picked: int) -> void:
			_dex_species = picked
			species_button.text = _named(&"species", picked)
		)
	)
	row.add_child(species_button)
	row.add_child(_action("Seen", func() -> void:
		_apply(_editor.set_seen_species(_dex_species, true))
	))
	row.add_child(_action("Caught", func() -> void:
		_apply(_editor.set_caught_species(_dex_species))
	))
	row.add_child(_action("Clear", func() -> void:
		_apply(_editor.set_seen_species(_dex_species, false))
	))
	row.add_child(_action("Register party and boxes", func() -> void:
		_apply(_editor.register_owned())
	))
	_dex_list = _page_list()
	page.add_child(_dex_list)
	return page


func _refresh() -> void:
	if _editor == null:
		_set_status("No save is open.")
		return
	_refresh_validity()
	for relabel: Callable in _relabel:
		relabel.call()
	_refresh_party()
	_refresh_party_form()
	_refresh_boxes()
	_refresh_items()
	_refresh_events()
	_refresh_map()
	_refresh_dex()


func _refresh_validity() -> void:
	var validation: Dictionary = _editor.validate()
	_validity.text = "Validates clean" if validation["ok"] else String(validation["message"])


func _refresh_party() -> void:
	_party_list.clear()
	for mon: Gen2SaveMon in _editor.save.party:
		_party_list.add_item("%s  Lv%d  %d/%d HP" % [
			_species_name(mon.species), mon.level, mon.hp, _editor.max_hp_for(mon),
		])
	if _selected_party >= 0 and _selected_party < _party_list.item_count:
		_party_list.select(_selected_party)


func _refresh_party_form() -> void:
	if _party_form == null:
		return
	var in_range: bool = _selected_party >= 0 and _selected_party < _editor.save.party.size()
	_fill_mon_form(_party_form, _editor.save.party[_selected_party] if in_range else null)


## Rebuilt per selection. A Generation II box row stores no HP, so a boxed
## Pokemon's form has none.
func _fill_mon_form(form: VBoxContainer, mon: Gen2SaveMon) -> void:
	Gen2LauncherUI.clear(form)
	if mon == null:
		return
	form.add_child(_named_field("Species", &"species", mon.species, func(value: int) -> void:
		_apply(_editor.set_species(mon, value))
	))
	form.add_child(_field("Level", mon.level, 1, Gen2Experience.MAX_LEVEL,
		func(value: int) -> void: _apply(_editor.set_level(mon, value))
	))
	if _editor.save.party.has(mon) or _editor.data.generation == RomRegistry.GEN1:
		form.add_child(_field("HP", mon.hp, 0, _editor.max_hp_for(mon),
			func(value: int) -> void: _apply(_editor.set_hp(mon, value))
		))
	var gender: StringName = _editor.gender_of(mon)
	if gender != Gen2BattleMon.GENDER_NONE:
		var gender_row: HFlowContainer = Gen2LauncherUI.actions()
		gender_row.add_child(_label("Gender %s" % Gen2BattleMon.gender_glyph(gender)))
		var other: StringName = Gen2BattleMon.GENDER_FEMALE if gender == Gen2BattleMon.GENDER_MALE \
			else Gen2BattleMon.GENDER_MALE
		gender_row.add_child(_action("Make %s" % Gen2BattleMon.gender_glyph(other), func() -> void:
			_apply(_editor.set_gender(mon, other))
		))
		form.add_child(gender_row)
	form.add_child(_field("Happiness", mon.happiness, 0, 255,
		func(value: int) -> void: _apply(_editor.set_happiness(mon, value))
	))
	form.add_child(_named_field("Held item", &"held", mon.item, func(value: int) -> void:
		_apply(_editor.set_held_item(mon, value))
	))
	for slot: int in Gen2SaveMon.MAX_MOVES:
		form.add_child(_named_field(
			"Move %d" % (slot + 1), &"move", int(mon.moves[slot]),
			func(value: int) -> void: _apply(_editor.set_move(mon, slot, value))
		))
	form.add_child(_dv_row(mon))


func _dv_row(mon: Gen2SaveMon) -> HFlowContainer:
	var dv_row: HFlowContainer = Gen2LauncherUI.actions()
	dv_row.add_child(_label("DVs"))
	var dv_fields: Array[SpinBox] = []
	for dv: int in [
		Gen2Stats.attack_dv(mon.dvs), Gen2Stats.defense_dv(mon.dvs),
		Gen2Stats.speed_dv(mon.dvs), Gen2Stats.special_dv(mon.dvs),
	]:
		var spin := SpinBox.new()
		spin.max_value = Gen2Stats.MAX_DV
		spin.value = dv
		dv_row.add_child(spin)
		dv_fields.append(spin)
	dv_row.add_child(_action("Apply", func() -> void:
		_apply(_editor.set_dvs(
			mon, int(dv_fields[0].value), int(dv_fields[1].value),
			int(dv_fields[2].value), int(dv_fields[3].value),
		))
	))
	return dv_row


func _refresh_boxes() -> void:
	if _box_list == null:
		return
	_box_list.clear()
	var box: Gen2SaveBox = _editor.box(_selected_box)
	if box == null:
		return
	for slot: int in box.slots.size():
		var mon: Gen2SaveMon = box.slots[slot]
		_box_list.add_item("%d. %s" % [
			slot + 1,
			"empty" if mon == null else "%s Lv%d" % [_species_name(mon.species), mon.level],
		])
	if _selected_box_slot >= 0 and _selected_box_slot < _box_list.item_count:
		_box_list.select(_selected_box_slot)
	_refresh_box_form()


func _refresh_box_form() -> void:
	if _box_form == null:
		return
	var box: Gen2SaveBox = _editor.box(_selected_box)
	var in_range: bool = box != null and _selected_box_slot >= 0 \
		and _selected_box_slot < box.slots.size()
	_fill_mon_form(_box_form, box.slots[_selected_box_slot] if in_range else null)


func _refresh_items() -> void:
	if _item_list == null:
		return
	_item_list.clear()
	var state: Gen2WorldState = _editor.save.world.world_state if _editor.has_world() else null
	if state == null:
		_item_list.add_item("This save has no world state.")
		_money_field.editable = false
		_coins_field.editable = false
		return
	_money_field.set_value_no_signal(state.money(0))
	_coins_field.set_value_no_signal(state.coins())
	_item_button.text = _named(&"item", _picked_item)
	_item_set.text = "Set" if state.item_quantity(_picked_item) > 0 else "Add"
	_item_rows = []
	for item: Variant in state.items():
		_item_rows.append(int(item))
		_item_list.add_item("%s x%d" % [
			_item_name(int(item)), state.item_quantity(int(item)),
		])


func _refresh_events() -> void:
	var flags: Array[int] = _editor.badge_flags()
	var state: Gen2WorldState = _editor.save.world.world_state if _editor.has_world() else null
	for index: int in _badge_boxes.size():
		var box: CheckBox = _badge_boxes[index]
		box.disabled = state == null or index >= flags.size()
		box.set_pressed_no_signal(
			state != null and index < flags.size() and state.is_engine_flag_active(flags[index])
		)


func _refresh_map() -> void:
	if not _editor.has_world():
		return
	var world: Gen2WorldSnapshot = _editor.save.world
	_map_fields["group"].set_value_no_signal(world.map_id.x)
	_map_fields["number"].set_value_no_signal(world.map_id.y)
	_map_fields["x"].set_value_no_signal(world.player_cell.x)
	_map_fields["y"].set_value_no_signal(world.player_cell.y)
	_map_fields["day"].set_value_no_signal(world.world_day)
	_map_fields["hour"].set_value_no_signal(world.world_hour)
	_map_fields["minute"].set_value_no_signal(world.world_minute)


func _refresh_dex() -> void:
	if _dex_list == null:
		return
	_dex_list.clear()
	if not _editor.has_world():
		_dex_list.add_item("This save has no world state.")
		return
	var state: Gen2WorldState = _editor.save.world.world_state
	var numbers: Array = state.seen_species().keys()
	numbers.sort()
	for species: Variant in numbers:
		_dex_list.add_item("%d %s  %s" % [
			int(species), _species_name(int(species)),
			"caught" if state.has_caught_species(int(species)) else "seen",
		])


func _set_badge(index: int, pressed: bool) -> void:
	var flags: Array[int] = _editor.badge_flags()
	if index >= flags.size():
		return
	_apply(_editor.set_engine_flag(flags[index], pressed))


func _apply_position() -> void:
	_apply(_editor.set_player_position(_typed_map(), _typed_cell()))


func _typed_map() -> Vector2i:
	return Vector2i(int(_map_fields["group"].value), int(_map_fields["number"].value))


func _typed_cell() -> Vector2i:
	return Vector2i(int(_map_fields["x"].value), int(_map_fields["y"].value))


## Save takes the Map tab as typed; false when that is refused.
func _apply_pending_map() -> bool:
	if not _editor.has_world() or _map_fields.is_empty():
		return true
	var world: Gen2WorldSnapshot = _editor.save.world
	var results: Array[Dictionary] = []
	if _typed_map() != world.map_id or _typed_cell() != world.player_cell:
		results.append(_editor.set_player_position(_typed_map(), _typed_cell()))
	var clock := Vector3i(
		int(_map_fields["day"].value), int(_map_fields["hour"].value),
		int(_map_fields["minute"].value),
	)
	if clock != Vector3i(world.world_day, world.world_hour, world.world_minute):
		results.append(_editor.set_clock(clock.x, clock.y, clock.z))
	for result: Dictionary in results:
		if not bool(result["ok"]):
			_apply(result)
			return false
	return true


## A touch on a button leaves a SpinBox's typed text uncommitted until focus goes.
func _commit_typing() -> void:
	if is_inside_tree():
		get_viewport().gui_release_focus()


## A refused edit reports why and leaves the controls showing what is actually
## stored, which is why this refreshes on failure as well as success.
func _apply(result: Dictionary, refresh: bool = true) -> void:
	if _editor == null:
		return
	_set_status("" if bool(result["ok"]) else String(result["message"]))
	if refresh:
		_refresh()
	else:
		_refresh_validity()


func _close() -> void:
	get_tree().change_scene_to_file.call_deferred("res://game/save/save_screen.tscn")


## A sheet the finger scrolls: an [OptionButton]'s popup ran off a phone's
## screen with no way to scroll it.
func _pick(title: String, kind: StringName, current: int, handler: Callable) -> void:
	if _editor == null:
		return
	var sheet: Gen2LauncherSheet = Gen2LauncherSheet.create(_palette, title)
	var here: Button = null
	for number: int in _named_numbers(kind):
		var row: Gen2LauncherButton = Gen2LauncherButton.create(
			_palette, _named(kind, number), Gen2LauncherButton.Variant.QUIET
		)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.pressed.connect(func() -> void:
			sheet.close()
			handler.call(number)
		)
		sheet.body().add_child(row)
		if number == current:
			here = row
	await sheet.open(self)
	if here != null and is_instance_valid(here):
		here.grab_focus()


func _named_numbers(kind: StringName) -> Array[int]:
	var out: Array[int] = []
	var data: GameData = _editor.data
	match kind:
		&"species":
			for species: int in range(1, data.species_count() + 1):
				out.append(species)
		&"move":
			out.append(Gen2SaveEditor.NO_MOVE)
			for move: int in range(1, data.move_count() + 1):
				out.append(move)
		&"item", &"held":
			if kind == &"held":
				out.append(0)
			for item: int in range(1, data.item_count() + 1):
				var item_name: String = data.item_name(item)
				if not item_name.is_empty() and item_name != UNUSED_ITEM_NAME:
					out.append(item)
	return out


func _named(kind: StringName, number: int) -> String:
	if _editor == null:
		return str(number)
	if number == 0 and kind != &"species":
		return "none"
	match kind:
		&"species":
			return "%d %s" % [number, _species_name(number)]
		&"move":
			var row: Dictionary = _editor.data.move(number)
			return "%d %s" % [number, String(row.get("name", "unknown %d" % number))]
	return "%d %s" % [number, _item_name(number)]


func _named_field(text: String, kind: StringName, value: int, handler: Callable) -> Container:
	var row: HFlowContainer = Gen2LauncherUI.actions()
	row.add_child(_label(text))
	row.add_child(_action(_named(kind, value), func() -> void:
		_pick(text, kind, value, handler)
	))
	return row


func _species_name(species: int) -> String:
	var row: Dictionary = _editor.data.species(species)
	return String(row.get("name", "?")) if not row.is_empty() else "unknown %d" % species


func _item_name(item: int) -> String:
	var row: Dictionary = _editor.data.item(item)
	return String(row.get("name", "?")) if not row.is_empty() else "unknown %d" % item


func _set_status(message: String) -> void:
	if _status != null:
		_status.text = message


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _action(text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(func() -> void:
		_commit_typing()
		handler.call()
	)
	return button


func _field(text: String, value: int, minimum: int, maximum: int, handler: Callable) -> Container:
	var row: HFlowContainer = Gen2LauncherUI.actions()
	row.add_child(_label(text))
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.value = value
	spin.value_changed.connect(func(changed: float) -> void: handler.call(int(changed)))
	row.add_child(spin)
	return row
