class_name Gen2SaveScreen
extends Control

## Player-facing save selection for one imported cartridge revision.
##
## The screen only coordinates validated save data. Original SRAM bytes enter
## through [Gen2SramAdapter], and project slots are written through
## [Gen2SaveStore], so no control here needs to know a cartridge offset.
##
## It is the launcher's second screen and shares its frame: same shell, same
## soft surfaces, same palette.

var _palette: Gen2LauncherTheme = null
var _data: GameData = null
var _data_override: GameData = null
var _selected_slot: int = 0
var _new_game_visible: bool = false
var _slots: Array = []
## Which challenge the new-game form has selected. It is fixed for the life of
## the save the form creates, which is why it is asked here and not in Settings.
var _new_game_challenge: StringName = Gen2Rules.CHALLENGE_VANILLA
var _pending_replace_action: StringName = &""
var _pending_import_path: String = ""

var _shell: Gen2LauncherShell = null
var _page: VBoxContainer = null
var _slots_container: HFlowContainer = null
var _details_box: VBoxContainer = null
var _status_title: String = ""
var _status_detail: String = ""
var _name_input: LineEdit = null
var _export_dialog: Gen2LauncherFilePicker = null
var _slot_import_dialog: Gen2LauncherFilePicker = null
var _file_dialog: Gen2LauncherFilePicker = null
## `MysteryGift`'s own screen, which is a main-menu row on the cartridge and
## belongs here for the same reason its SRAM block sits outside the checksummed
## save: the exchange happens with no file loaded, and the two slots this
## screen already lists are the only two Mystery Gift blocks on one machine.
var _mystery_gift: Gen2MysteryGiftScreen = null
var _mystery_gift_hardware: Gen2Screen = null
var _mystery_gift_clock := Gen2WorldAnimation.FrameClock.new()


func _ready() -> void:
	_palette = Gen2LauncherTheme.active()
	_data = _data_override if _data_override != null else _resolve_data()
	_build_ui()
	_refresh()
	var input: Gen2InputRuntime = Gen2InputRuntime.instance()
	if input != null and not input.back_requested.is_connected(_on_back_requested):
		input.back_requested.connect(_on_back_requested)


## Test and tooling seam for synthetic caches. Production callers use the
## selected registry game through [GameRuntime].
func set_data(data: GameData) -> void:
	_data_override = data
	_data = data
	if is_inside_tree() and _slots_container != null:
		_refresh()


## Selects a project slot by number.
func select_slot(slot: int) -> bool:
	if slot < 0 or slot >= Gen2SaveStore.MAX_SLOTS:
		return false
	_selected_slot = slot
	_new_game_visible = false
	_refresh()
	return true


## Opens the new-game form for a slot. Existing slots require confirmation
## through the button-driven path, while tests and tools may call this directly.
## Without a slot, an unselected screen falls back to a fresh one, which is the
## only thing a game with no saves at all can mean.
func open_new_game(slot: int = -1) -> bool:
	if slot >= 0 and not select_slot(slot):
		return false
	if slot < 0 and _selected_slot < 0 and not open_new_slot():
		return false
	_new_game_visible = true
	_refresh_details()
	return true


## Targets the next unused slot, the "new save slot" action. Fails only when
## every slot number is taken.
func open_new_slot() -> bool:
	if _data == null:
		return false
	var slot: int = Gen2SaveStore.next_free_slot(_data.id, _data.sha1)
	if slot < 0:
		_set_status(&"error", "No new slot is available.", "Delete a save to free one.")
		return false
	_selected_slot = slot
	_new_game_visible = true
	_refresh_details()
	return true


## Starts a new game in the selected slot by running the cartridge's own intro.
## Nothing is written here: `NewGame` reaches `InitializeWorld` only after
## `PlayerProfileSetup` and `OakSpeech` have returned, so the slot is staged on
## [GameRuntime] and [Gen2IntroScreen] writes it once the trainer has a name and a
## gender, and abandoning the intro leaves no file behind. [param label] is the
## save file's decorative name, optional; [param challenge] overrides the form's
## own pick, which is what a test and a driver use.
func create_new_game(label: String = "", challenge: StringName = &"") -> bool:
	if _data == null:
		_set_status(&"error", "New game unavailable.", "No imported cartridge cache is selected.")
		return false
	# Nothing is selected when the game has no saves at all, and a new game is
	# then unambiguously a new slot.
	if _selected_slot < 0:
		_selected_slot = Gen2SaveStore.next_free_slot(_data.id, _data.sha1)
	if _selected_slot < 0:
		_set_status(&"error", "New game was not created.", "Every save slot is in use.")
		return false
	var trimmed: String = label.strip_edges()
	if trimmed.length() > Gen2SaveData.MAX_LABEL:
		_set_status(
			&"error", "New game was not started.",
			"A save name is at most %d characters." % Gen2SaveData.MAX_LABEL,
		)
		return false
	var chosen: StringName = challenge if Gen2Rules.CHALLENGES.has(challenge) \
		else _new_game_challenge
	GameRuntime.begin_new_game(_data.id, _selected_slot, trimmed, chosen)
	_new_game_visible = false
	get_tree().change_scene_to_file.call_deferred("res://game/world/intro_screen.tscn")
	return true


## Imports an original SRAM file into the selected project slot. A failed
## import never reaches [Gen2SaveStore.save], so the previous slot remains.
func import_sav_path(path: String, slot: int = -1) -> bool:
	if _data == null:
		_set_status(&"error", "Save import unavailable.", "No imported cartridge cache is selected.")
		return false
	if slot >= 0 and not select_slot(slot):
		return false
	if not FileAccess.file_exists(path):
		_set_status(&"error", "Save import failed.", "The selected file could not be opened.")
		return false
	var raw: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if raw.is_empty():
		_set_status(&"error", "Save import failed.", "The selected file is empty.")
		return false
	var imported: Dictionary = Gen2SramAdapter.import_bytes(
		_data.id, _data.sha1, _selected_slot, raw, _data
	)
	if not imported["ok"]:
		_set_status(&"error", "Save import rejected.", String(imported["message"]))
		return false
	var save: Gen2SaveData = imported["save"]
	var result: Dictionary = Gen2SaveStore.save(save, _data)
	if not result["ok"]:
		_set_status(&"error", "Save import failed.", String(result["message"]))
		return false
	GameRuntime.reload_selected_save()
	_new_game_visible = false
	_refresh()
	_set_status(
		&"success",
		"Save imported into slot %d." % (_selected_slot + 1),
		"The cartridge copy was %s and passed validation." % String(imported["copy"]),
	)
	return true


## Read-only state used by scene tests and screenshot drivers.
func save_screen_snapshot() -> Dictionary:
	return {
		"game_id": String(_data.id) if _data != null else "",
		"selected_slot": _selected_slot,
		"new_game": _new_game_visible,
		# Whether the name form is actually on screen, which is not the same
		# question as whether it was asked for: a details pane that refused to
		# draw leaves the flag up and the form absent.
		"new_game_form": is_instance_valid(_name_input),
		"status": _status_title,
		"detail": _status_detail,
		"slots": _slots.duplicate(true),
	}


func _resolve_data() -> GameData:
	if GameRuntime.has_selected_game():
		return GameRuntime.selected_data()
	return GameData.open_any()


func _build_ui() -> void:
	theme = _palette.control_theme()
	_shell = Gen2LauncherShell.create(_palette)
	add_child(_shell)

	var back: Gen2LauncherButton = Gen2LauncherButton.create(
		_palette, "Shelf", Gen2LauncherButton.Variant.QUIET, &"back"
	)
	back.pressed.connect(_back_to_launcher)
	_shell.add_action(back)

	_page = Gen2LauncherUI.column(Gen2LauncherUI.GAP_LG)
	var head: HBoxContainer = Gen2LauncherUI.row(Gen2LauncherUI.GAP_MD)
	_page.add_child(head)
	var save_title: Label = Gen2LauncherUI.title(
		_palette, "Save data", Gen2LauncherTheme.FONT_DISPLAY
	)
	save_title.name = "SaveScreenTitle"
	head.add_child(save_title)
	head.add_child(Gen2LauncherUI.spacer())
	var game_title: Label = Gen2LauncherUI.muted(
		_palette, _data.title() if _data != null else "No cartridge selected"
	)
	game_title.name = "SaveScreenGameTitle"
	# The expanding spacer otherwise squeezes a wrapping label to one character per line.
	game_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	game_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	game_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(game_title)

	_slots_container = HFlowContainer.new()
	_slots_container.add_theme_constant_override("h_separation", Gen2LauncherUI.GAP_MD)
	_slots_container.add_theme_constant_override("v_separation", Gen2LauncherUI.GAP_MD)
	_slots_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_child(_slots_container)

	var details: Gen2LauncherScroll = Gen2LauncherScroll.create()
	_page.add_child(details)
	_details_box = Gen2LauncherUI.column(Gen2LauncherUI.GAP_MD)
	_details_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_child(_details_box)

	_shell.add_page(&"saves", "Saves", &"save", _page)

	_file_dialog = _picker(
		"Choose an original cartridge save",
		FileDialog.FILE_MODE_OPEN_FILE,
		PackedStringArray(["*.sav; Cartridge save", "*; All files"]),
	)
	_file_dialog.file_selected.connect(_on_file_selected)
	_export_dialog = _picker(
		"Export this save slot",
		FileDialog.FILE_MODE_SAVE_FILE,
		PackedStringArray(["*.json; pokerecomp save"]),
	)
	_export_dialog.file_selected.connect(_export_selected_slot)
	_slot_import_dialog = _picker(
		"Import a pokerecomp save",
		FileDialog.FILE_MODE_OPEN_FILE,
		PackedStringArray(["*.json; pokerecomp save"]),
	)
	_slot_import_dialog.file_selected.connect(_import_slot_file)


func _picker(
	title: String, mode: FileDialog.FileMode, filters: PackedStringArray
) -> Gen2LauncherFilePicker:
	var dialog: Gen2LauncherFilePicker = Gen2LauncherUI.file_picker(_palette, title, mode, filters)
	add_child(dialog)
	return dialog


func _refresh() -> void:
	if _data == null:
		_set_status(
			&"error",
			"No cartridge cache is ready.",
			"Return to the shelf and import a supported dump.",
		)
		return
	_slots = Gen2SaveStore.slots_for(_data.id, _data.sha1, _data)
	# Slots are created on demand, so a slot number is no longer its own index
	# in this list and a game with no saves has no selectable slot at all.
	if _row_for(_selected_slot).is_empty():
		_selected_slot = int(_slots[0]["slot"]) if not _slots.is_empty() else -1
	_refresh_slot_cards()
	_refresh_details()


func _refresh_slot_cards() -> void:
	Gen2LauncherUI.clear(_slots_container)
	_slots_container.visible = not _new_game_visible

	for row: Dictionary in _slots:
		_slots_container.add_child(_slot_card(row))

	var add: Gen2LauncherButton = Gen2LauncherButton.create(
		_palette, "New slot", Gen2LauncherButton.Variant.NEUTRAL, &"plus"
	)
	add.custom_minimum_size = Vector2(160, 92)
	add.pressed.connect(func() -> void: open_new_slot())
	_slots_container.add_child(add)


func _slot_card(row: Dictionary) -> Control:
	var slot: int = int(row["slot"])
	var selected: bool = slot == _selected_slot
	var card: Gen2LauncherCard = (
		Gen2LauncherCard.selected(_palette, Gen2LauncherTheme.RADIUS_MD, 16) if selected
		else Gen2LauncherCard.create(_palette, Gen2LauncherTheme.RADIUS_MD, 16)
	)
	card.custom_minimum_size = Vector2(216, 92)
	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_ALL
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.pressed.connect(select_slot.bind(slot))
	card.add_child(button)

	var column: VBoxContainer = Gen2LauncherUI.column(2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	var top: HBoxContainer = Gen2LauncherUI.row(Gen2LauncherUI.GAP_SM)
	column.add_child(top)
	var heading: Label = Gen2LauncherUI.body(_palette, "Slot %d" % (slot + 1))
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heading)
	var state: Label = Gen2LauncherUI.caption(_palette, _slot_state(row))
	state.add_theme_color_override("font_color", _slot_state_color(row))
	top.add_child(state)
	var label: String = String(row.get("label", ""))
	column.add_child(Gen2LauncherUI.muted(
		_palette, label if not label.is_empty() else _slot_message(row)
	))
	return card


func _refresh_details() -> void:
	if _details_box == null:
		return
	_slots_container.visible = not _new_game_visible
	Gen2LauncherUI.clear(_details_box)
	# The pane's own controls go with it. A detached child is deleted at the end
	# of the frame rather than here, so a reference kept past the rebuild would
	# still answer `is_instance_valid` and report a form that is off screen.
	_name_input = null
	if _data == null or _selected_slot < 0:
		return
	# A slot targeted for a new game has no row yet, since slots_for answers only
	# what is on disk. Describing it as empty is what lets the form open on it;
	# bailing here is what kept the "New slot" button from doing anything.
	var row: Dictionary = _row_for(_selected_slot)
	if row.is_empty():
		row = Gen2SaveStore.empty_slot_row(_selected_slot)

	var panel: Gen2LauncherCard = Gen2LauncherCard.create(_palette, Gen2LauncherTheme.RADIUS_MD, 22)
	_details_box.add_child(panel)
	var body: VBoxContainer = Gen2LauncherUI.column(Gen2LauncherUI.GAP_MD)
	panel.add_child(body)

	var head: HBoxContainer = Gen2LauncherUI.row(Gen2LauncherUI.GAP_MD)
	body.add_child(head)
	var heading: Label = Gen2LauncherUI.title(_palette, "Slot %d" % (_selected_slot + 1))
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(heading)
	var state: Label = Gen2LauncherUI.caption(_palette, _slot_state(row))
	state.add_theme_color_override("font_color", _slot_state_color(row))
	state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(state)

	if _new_game_visible:
		_build_new_game_form(body)
		return

	var save: Gen2SaveData = _load_selected_save()
	if save != null:
		body.add_child(Gen2LauncherUI.muted(_palette, "Player: %s" % save.player_name))
		body.add_child(Gen2LauncherUI.muted(_palette, "Mode: %s" % _challenge_title(save)))
		var over: bool = Gen2Nuzlocke.run_over(save.nuzlocke)
		var save_actions: HFlowContainer = Gen2LauncherUI.actions()
		body.add_child(save_actions)
		## A Nuzlocke that lost its last Pokemon is finished. The slot is still a
		## file to look at, export or delete; it is not a game to walk back into.
		if not over:
			save_actions.add_child(_action(
				"Continue", Gen2LauncherButton.Variant.PRIMARY, &"play", _continue_selected
			))
		save_actions.add_child(_action("Party", Gen2LauncherButton.Variant.NEUTRAL, &"", _open_party))
		## `MainMenu_GetWhichMenu`: the row is on the menu once
		## `sNumDailyMysteryGiftPartnerIDs` is no longer -1, which is the byte a
		## save wrote rather than the one Carrie cleared, so it appears on the
		## session after the explanation rather than during it.
		if Gen2MysteryGift.menu_row_unlocked(save.mystery_gift):
			save_actions.add_child(_action(
				"Mystery Gift", Gen2LauncherButton.Variant.NEUTRAL, &"",
				_open_mystery_gift
			))
		save_actions.add_child(_action("Import .sav", Gen2LauncherButton.Variant.NEUTRAL, &"", _request_import))
		save_actions.add_child(_action("Replace", Gen2LauncherButton.Variant.NEUTRAL, &"", _request_new_game))
		_add_party_summary(body, save)
		_add_nuzlocke_summary(body, save)
		_add_slot_management(body)
		return

	body.add_child(Gen2LauncherUI.muted(_palette, _slot_message(row)))
	var actions: HFlowContainer = Gen2LauncherUI.actions()
	body.add_child(actions)
	actions.add_child(_action("New game", Gen2LauncherButton.Variant.PRIMARY, &"plus", _request_new_game))
	actions.add_child(_action("Import .sav", Gen2LauncherButton.Variant.NEUTRAL, &"", _request_import))
	# Renaming, exporting or deleting a slot with no file behind it can only
	# report failure, so a free slot is offered none of it.
	if bool(row["exists"]):
		_add_slot_management(body)


## Naming, export, deletion and the editor. Kept below the play actions,
## because these are about the slot as a file rather than the game in it, and
## only the last of them is reversible.
func _add_slot_management(body: VBoxContainer) -> void:
	body.add_child(Gen2LauncherUI.caption(_palette, "This slot as a file"))
	var name_row: HFlowContainer = Gen2LauncherUI.actions()
	body.add_child(name_row)
	var name_input := LineEdit.new()
	name_input.placeholder_text = "Slot name"
	name_input.max_length = Gen2SaveData.MAX_LABEL
	name_input.text = String(_row_for(_selected_slot).get("label", ""))
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	## A wrapping row gives a child its minimum width rather than the line, so
	## the field says how wide it wants to be and drops the button under it when
	## the page cannot hold both.
	name_input.custom_minimum_size = Vector2(220, 0)
	name_row.add_child(name_input)
	name_row.add_child(_action("Rename", Gen2LauncherButton.Variant.NEUTRAL, &"", func() -> void:
		_rename_slot(name_input.text)
	))

	var file_row: HFlowContainer = Gen2LauncherUI.actions()
	body.add_child(file_row)
	file_row.add_child(_action("Edit save", Gen2LauncherButton.Variant.NEUTRAL, &"settings", _open_editor))
	file_row.add_child(_action("Export", Gen2LauncherButton.Variant.NEUTRAL, &"", func() -> void:
		# A suggested name, which the system dialogs offer for editing and which
		# is the whole name on a machine that browses without a keyboard.
		_export_dialog.current_file = export_file_name()
		_export_dialog.show_picker(Vector2i(900, 600))
	))
	file_row.add_child(_action("Import", Gen2LauncherButton.Variant.NEUTRAL, &"", func() -> void:
		_slot_import_dialog.show_picker(Vector2i(900, 600))
	))
	file_row.add_child(_action("Delete", Gen2LauncherButton.Variant.DANGER, &"trash", _request_delete))


func _action(
	label: String, variant: Gen2LauncherButton.Variant, glyph: StringName, handler: Callable
) -> Gen2LauncherButton:
	var button: Gen2LauncherButton = Gen2LauncherButton.create(_palette, label, variant, glyph)
	button.pressed.connect(handler)
	return button


func _rename_slot(label: String) -> void:
	if _data == null:
		return
	var result: Dictionary = Gen2SaveStore.rename_slot(
		_data.id, _data.sha1, _selected_slot, label, _data
	)
	if not result["ok"]:
		_set_status(&"error", "The slot was not renamed.", String(result["message"]))
		return
	_set_status(&"success", "Renamed slot %d." % (_selected_slot + 1), label)
	_refresh()


func _request_delete() -> void:
	if not _slot_exists():
		return
	_confirm(
		"Delete slot %d?" % (_selected_slot + 1),
		"This cannot be undone.",
		"Delete",
		_delete_selected_slot,
	)


## A modal card rather than an OS dialog, so a confirmation looks the same on
## every platform the launcher runs on.
func _confirm(title: String, message: String, action: String, handler: Callable) -> void:
	var sheet: Gen2LauncherSheet = Gen2LauncherSheet.create(_palette, title)
	sheet.body().add_child(Gen2LauncherUI.muted(_palette, message))
	var confirm: Gen2LauncherButton = Gen2LauncherButton.create(
		_palette, action, Gen2LauncherButton.Variant.PRIMARY
	)
	confirm.pressed.connect(func() -> void:
		sheet.close()
		handler.call()
	)
	sheet.add_action(confirm)
	sheet.open(self)


func _delete_selected_slot() -> void:
	if _data == null or not Gen2SaveStore.delete_slot(_data.id, _data.sha1, _selected_slot):
		_set_status(&"error", "The slot was not deleted.", "Nothing was removed.")
		return
	_set_status(&"info", "Deleted slot %d." % (_selected_slot + 1), "")
	_selected_slot = -1
	GameRuntime.reload_selected_save()
	_refresh()


## What an exported slot is called: the cartridge, the slot and the label the
## player gave it, with anything a file system might refuse taken out.
func export_file_name() -> String:
	var parts := PackedStringArray()
	if _data != null:
		parts.append(String(_data.id))
	parts.append("slot-%d" % (_selected_slot + 1))
	var label: String = String(_row_for(_selected_slot).get("label", "")).strip_edges()
	if not label.is_empty():
		parts.append(label)
	return "%s.json" % "-".join(parts).to_lower().replace(" ", "-").validate_filename()


func _export_selected_slot(path: String) -> void:
	var result: Dictionary = Gen2SaveStore.export_slot(
		_data.id, _data.sha1, _selected_slot, path
	)
	if not result["ok"]:
		_set_status(&"error", "The save was not exported.", String(result["message"]))
		return
	_set_status(&"success", "Exported slot %d." % (_selected_slot + 1), path)


func _import_slot_file(path: String) -> void:
	var result: Dictionary = Gen2SaveStore.import_slot(path, _data)
	if not result["ok"]:
		_set_status(&"error", "That save was not imported.", String(result["message"]))
		return
	_selected_slot = int(result["slot"])
	_set_status(&"success", "Imported into slot %d." % (_selected_slot + 1), path)
	_refresh()


func _open_editor() -> void:
	if _data == null or not GameRuntime.select_save_slot(_data.id, _selected_slot):
		_set_status(&"error", "The editor could not open.", "Select a readable slot first.")
		return
	get_tree().change_scene_to_file.call_deferred("res://game/save/save_editor_screen.tscn")


## The launcher names the save file and nothing else. The trainer is named in
## the game, on the cartridge's own naming screen, which the intro reaches after
## Oak's speech.
func _build_new_game_form(body: VBoxContainer) -> void:
	body.add_child(Gen2LauncherUI.muted(
		_palette, "Name this save file. Your trainer name is chosen in the game."
	))
	_name_input = LineEdit.new()
	_name_input.placeholder_text = "Slot name (optional)"
	_name_input.max_length = Gen2SaveData.MAX_LABEL
	_name_input.custom_minimum_size = Vector2(0, 42)
	body.add_child(Gen2LauncherUI.caption(_palette, "Save name"))
	body.add_child(_name_input)
	_build_challenge_field(body)
	var actions: HFlowContainer = Gen2LauncherUI.actions()
	body.add_child(actions)
	actions.add_child(_action("Start game", Gen2LauncherButton.Variant.PRIMARY, &"check", _create_from_form))
	actions.add_child(_action("Cancel", Gen2LauncherButton.Variant.NEUTRAL, &"", cancel_new_game))


## The one choice this screen makes that the game itself cannot take back. It is
## here rather than in Settings because it belongs to the run: a Nuzlocke that
## could be switched off after a death would not be one.
func _build_challenge_field(body: VBoxContainer) -> void:
	body.add_child(Gen2LauncherUI.caption(_palette, "Mode"))
	var titles: Array = []
	for challenge: StringName in Gen2Rules.CHALLENGES:
		titles.append(Gen2Rules.challenge_title(challenge))
	var detail: Label = Gen2LauncherUI.muted(_palette, "")
	body.add_child(Gen2LauncherUI.segmented(
		_palette, titles, maxi(Gen2Rules.CHALLENGES.find(_new_game_challenge), 0),
		func(index: int) -> void:
			_new_game_challenge = Gen2Rules.CHALLENGES[index]
			detail.text = Gen2Rules.challenge_detail(_new_game_challenge)
	))
	detail.text = Gen2Rules.challenge_detail(_new_game_challenge)
	body.add_child(detail)
	body.add_child(Gen2LauncherUI.muted(
		_palette, "This is fixed once the game starts and cannot be changed later."
	))


## What the run is played under, as the launcher spells it. A slot written
## before the challenge existed has no rules block and reads as the cartridge's
## own game, which is what it was.
func _challenge_title(save: Gen2SaveData) -> String:
	return Gen2Rules.challenge_title(
		save.run_rules.challenge if save.run_rules != null else Gen2Rules.CHALLENGE_VANILLA
	)


## The Nuzlocke's own record: how many areas have given up their encounter, what
## the run has lost, and its verdict. Drawn for a Nuzlocke and nothing else, so
## an ordinary slot's pane is exactly what it was.
func _add_nuzlocke_summary(body: VBoxContainer, save: Gen2SaveData) -> void:
	if save.run_rules == null or not save.run_rules.is_nuzlocke():
		return
	var areas: Variant = save.nuzlocke.get("areas", {})
	var graveyard: Variant = save.nuzlocke.get("graveyard", [])
	var area_count: int = (areas as Dictionary).size() if areas is Dictionary else 0
	var lost: Array = graveyard as Array if graveyard is Array else []
	body.add_child(Gen2LauncherUI.caption(_palette, "Nuzlocke"))
	if Gen2Nuzlocke.run_over(save.nuzlocke):
		var verdict: Label = Gen2LauncherUI.body(
			_palette, "This run is over. %d area%s met, %d lost." % [
				area_count, "" if area_count == 1 else "s", lost.size(),
			]
		)
		verdict.add_theme_color_override("font_color", _palette.error)
		body.add_child(verdict)
	else:
		body.add_child(Gen2LauncherUI.muted(
			_palette, "%d area%s met, %d lost." % [
				area_count, "" if area_count == 1 else "s", lost.size(),
			]
		))
	if lost.is_empty():
		return
	var names: PackedStringArray = PackedStringArray()
	for entry: Variant in lost:
		if entry is Dictionary:
			names.append("%s Lv.%d" % [
				Gen2Nuzlocke.grave_name(_data, entry as Dictionary),
				int((entry as Dictionary).get("level", 1)),
			])
	body.add_child(Gen2LauncherUI.muted(_palette, ", ".join(names)))


func _add_party_summary(body: VBoxContainer, save: Gen2SaveData) -> void:
	body.add_child(Gen2LauncherUI.caption(_palette, "Party"))
	var grid := HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", Gen2LauncherUI.GAP_SM)
	grid.add_theme_constant_override("v_separation", Gen2LauncherUI.GAP_SM)
	body.add_child(grid)
	for index: int in Gen2SaveData.MAX_PARTY:
		var cell: Gen2LauncherCard = Gen2LauncherCard.well(_palette, Gen2LauncherTheme.RADIUS_SM, 12)
		cell.custom_minimum_size = Vector2(196, 0)
		grid.add_child(cell)
		var column: VBoxContainer = Gen2LauncherUI.column(1)
		cell.add_child(column)
		if index >= save.party.size():
			column.add_child(Gen2LauncherUI.muted(_palette, "%d. Empty" % (index + 1)))
			continue
		var mon: Gen2SaveMon = save.party[index]
		var battle_mon: Gen2BattleMon = Gen2SaveBattleAdapter.to_battle_mon(_data, mon)
		column.add_child(Gen2LauncherUI.body(
			_palette, "%d. %s" % [index + 1, _display_name(mon)]
		))
		column.add_child(Gen2LauncherUI.muted(_palette, "Lv.%d   HP %d/%d   %s" % [
			mon.level, mon.hp, battle_mon.max_hp(), _status_name(mon.status)
		]))


func _request_new_game() -> void:
	if _slot_exists():
		_pending_replace_action = &"new_game"
		_pending_import_path = ""
		_confirm(
			"Replace slot %d?" % (_selected_slot + 1),
			"The save in it is overwritten by a new game.",
			"Replace",
			_on_replace_confirmed,
		)
		return
	open_new_game()


func _request_import() -> void:
	_file_dialog.show_picker(Vector2i(900, 600))


func _on_file_selected(path: String) -> void:
	if _slot_exists():
		_pending_replace_action = &"import"
		_pending_import_path = path
		_confirm(
			"Replace slot %d?" % (_selected_slot + 1),
			"The save in it is overwritten by this cartridge save.",
			"Replace",
			_on_replace_confirmed,
		)
		return
	import_sav_path(path)


func _on_replace_confirmed() -> void:
	var action: StringName = _pending_replace_action
	var path: String = _pending_import_path
	_pending_replace_action = &""
	_pending_import_path = ""
	if action == &"new_game":
		open_new_game()
	elif action == &"import":
		import_sav_path(path)


func _create_from_form() -> void:
	# The field belongs to a details pane that is rebuilt whole, so the reference
	# outlives the node it points at.
	if is_instance_valid(_name_input):
		create_new_game(_name_input.text, _new_game_challenge)


## Closes the new-game form, leaving the slot it was opened on selected.
func cancel_new_game() -> void:
	_new_game_visible = false
	_refresh_details()


func _continue_selected() -> void:
	var save: Gen2SaveData = _load_selected_save()
	if _data == null or save == null:
		return
	## The same refusal the missing button expresses, at the seam a test or a
	## driver reaches: a finished Nuzlocke is never opened again.
	if Gen2Nuzlocke.run_over(save.nuzlocke):
		_set_status(&"error", "This run is over.", "A Nuzlocke that wiped cannot be continued.")
		return
	if not GameRuntime.select_save_slot(_data.id, _selected_slot):
		_set_status(
			&"error",
			"Could not select save slot.",
			"The selected cartridge is not in the registry.",
		)
		return
	Gen2LauncherAudio.play(&"power")
	await _shell.flash(false)
	get_tree().change_scene_to_file.call_deferred("res://game/world/world_screen.tscn")


## `MainMenu_MysteryGift`: `UpdateTime`, the day countdown, and then the
## screen. The partner is the first other occupied slot of the same cartridge,
## which is `IR_SENDER`'s Game Boy here; no other slot is nobody in the window,
## and the exchange times out the way the routine does with one console.
func _open_mystery_gift() -> void:
	var save: Gen2SaveData = _load_selected_save()
	if _data == null or save == null or _mystery_gift != null:
		return
	var random := RandomNumberGenerator.new()
	var host := Gen2MysteryGiftScreen.new()
	host.set_context(
		_data, save, _mystery_gift_transport(save, random),
		_mystery_gift_dex_caught(save), _mystery_gift_day(save), random
	)
	host.closed.connect(_close_mystery_gift.bind(save))
	_mystery_gift = host
	_mystery_gift_hardware = Gen2Screen.host_for(self, _mystery_gift_hardware)
	_mystery_gift_hardware.display(host)
	set_process(true)


## The other slot's own block, staged the moment the window opens: the roll is
## that save's rather than this one's, which is what makes the item it offers
## its own.
func _mystery_gift_transport(
	save: Gen2SaveData, random: RandomNumberGenerator
) -> Gen2MysteryGiftTransport:
	for slot: int in Gen2SaveStore.occupied_slots(_data.id, _data.sha1):
		if slot == save.slot:
			continue
		var loaded: Dictionary = Gen2SaveStore.load_result(
			_data.id, _data.sha1, slot, _data
		)
		if not bool(loaded.get("ok", false)):
			continue
		var peer: Gen2SaveData = loaded["save"] as Gen2SaveData
		return Gen2MysteryGiftTransport.to_save(
			peer, _mystery_gift_dex_caught(peer), random
		)
	return Gen2MysteryGiftTransport.new()


## Which day the countdown behind the daily limit is measured in. A slot carries
## the world day it was saved on; one with no world yet is day zero, which is
## where a new game starts.
func _mystery_gift_day(save: Gen2SaveData) -> int:
	return save.world.world_day if save.world != null else 0


## `CountSetBits` over `wPokedexCaught`, which is what a partner's block carries
## and nothing here reads back. A slot with no world has caught nothing.
func _mystery_gift_dex_caught(save: Gen2SaveData) -> int:
	if save.world == null or save.world.world_state == null:
		return 0
	return save.world.world_state.caught_count()


func _close_mystery_gift(save: Gen2SaveData) -> void:
	var host: Gen2MysteryGiftScreen = _mystery_gift
	_mystery_gift = null
	if host != null:
		Gen2Screen.drop(host)
	set_process(false)
	## The section is the file's, so a gift that arrived is written back before
	## the screen is forgotten.
	Gen2SaveStore.save(save, _data)
	_refresh()


func _process(delta: float) -> void:
	if _mystery_gift == null:
		return
	for _frame: int in _mystery_gift_clock.tick(delta):
		_mystery_gift.advance_frame()


func _unhandled_input(event: InputEvent) -> void:
	if _mystery_gift == null:
		return
	var button: int = Gen2Button.pressed_in(event)
	if button == Gen2Button.NONE:
		return
	get_viewport().set_input_as_handled()
	_mystery_gift.handle_button(button)


func _open_party() -> void:
	if _data == null or _load_selected_save() == null:
		return
	if not GameRuntime.select_save_slot(_data.id, _selected_slot):
		_set_status(
			&"error",
			"Could not select save slot.",
			"The selected cartridge is not in the registry.",
		)
		return
	get_tree().change_scene_to_file.call_deferred("res://game/save/party_screen.tscn")


func _on_back_requested() -> void:
	var sheets: Array[Node] = find_children("", "Gen2LauncherSheet", true, false)
	if not sheets.is_empty():
		(sheets[sheets.size() - 1] as Gen2LauncherSheet).close()
		return
	_back_to_launcher()


## The same transition the launcher opened this screen with, walked the other
## way: both ends carry a shell, so the sheet is handed over the scene change.
func _back_to_launcher() -> void:
	await _shell.flash()
	get_tree().change_scene_to_file.call_deferred("res://game/main/main.tscn")


## The listed row for a slot number, or an empty dictionary when that slot has
## no save. [member _slots] holds only occupied slots, so this is a search
## rather than an index.
func _row_for(slot: int) -> Dictionary:
	if slot < 0:
		return {}
	for row: Dictionary in _slots:
		if int(row["slot"]) == slot:
			return row
	return {}


func _load_selected_save() -> Gen2SaveData:
	var row: Dictionary = _row_for(_selected_slot)
	if _data == null or row.is_empty() or not row["valid"]:
		return null
	var result: Dictionary = Gen2SaveStore.load_result(_data.id, _data.sha1, _selected_slot, _data)
	return result["save"] if result["ok"] else null


func _slot_exists() -> bool:
	var row: Dictionary = _row_for(_selected_slot)
	return not row.is_empty() and bool(row["exists"])


func _slot_state(row: Dictionary) -> String:
	if not row["exists"]:
		return "Empty"
	if not row["valid"]:
		return "Unreadable"
	return "Run over" if bool(row.get("run_over", false)) else "Ready"


func _slot_message(row: Dictionary) -> String:
	if not row["exists"]:
		return "No player data in this slot."
	if not row["valid"]:
		return String(row["message"])
	if bool(row.get("run_over", false)):
		return "This Nuzlocke ended."
	return "Ready to continue."


func _slot_state_color(row: Dictionary) -> Color:
	if not row["exists"]:
		return _palette.muted
	if not row["valid"] or bool(row.get("run_over", false)):
		return _palette.error
	return _palette.success


func _display_name(mon: Gen2SaveMon) -> String:
	if mon.nickname.is_empty():
		return _species_name(mon.species)
	return mon.nickname


func _species_name(species: int) -> String:
	if _data == null:
		return "UNKNOWN"
	return String(_data.species(species).get("name", "UNKNOWN"))


func _status_name(status: int) -> String:
	var status_name: StringName = Gen2Status.name_of(status)
	return "OK" if status_name.is_empty() else String(status_name).to_upper()


func _set_status(kind: StringName, title: String, detail: String) -> void:
	_status_title = title
	_status_detail = detail
	if kind == &"error":
		Gen2LauncherAudio.play(&"error")
	if _shell != null:
		_shell.toast().show_message(kind, title, detail)
