class_name Gen2BoxScreen
extends Control

## Bill's PC's three lists, on the hardware's own grid. [Gen2PCBoxPage] is the
## picture and `engine/pokemon/bills_pc.asm` is the model. `_DepositPKMN`,
## `_WithdrawPKMN` and `_MovePKMNWithoutMail` are this one screen with a
## different list loaded, opened from the panel's own top menu. A on a row opens
## the submenu each jumptable reaches; left and right belong to
## `MoveMonWithoutMail_DPad` alone.

signal closed(result: Dictionary)
## `PlayMonCry2` from the stats screen this one can open, played by whoever owns
## the audio player: nothing here reaches [Gen2AudioPlayer].
signal cry_requested(species: int)
## `MoveMonWOMail_InsertMon_SaveGame`'s `SFX_SAVE`, played by the driver's owner.
signal sfx_requested(index: int, waited: bool)

## The PC is drawn in hardware pixels and the panel it opens from is ordinary UI,
## so the screen carries a [Gen2Screen] of its own the way the region map does.

## `PCString_*` and `.PartyPKMN`, engine strings inside `bills_pc.asm` that no
## script points at, so they are the host's the way the contest lines are. "PKMN"
## is the two tiles `<PK>` and `<MN>` and "#" is the POKé ligature.
const PROMPT_CHOOSE: String = "Choose a PKMN."
const PROMPT_WHATS_UP: String = "What's up?"
const PROMPT_RELEASE: String = "Release PKMN?"
const PROMPT_LAST_MON: String = "It's your last PKMN!"
const PROMPT_NO_USABLE: String = "No more usable PKMN!"
## `PCString_RemoveMail`, the third thing `BillsPC_CheckMail_PreventBlackout`
## refuses on.
const PROMPT_REMOVE_MAIL: String = "Remove MAIL."
const PROMPT_BOX_FULL: String = "The BOX is full."
const PROMPT_PARTY_FULL: String = "The party's full!"
const PROMPT_NO_EGGS: String = "No releasing EGGS!"
const PROMPT_STORED: String = "Stored %s!"
const PROMPT_GOT: String = "Got %s!"
## `ReleasePKMN_ByePKMN` prints `PCString_ReleasedPKMN` for eighty frames and
## then this one for fifty. Nothing here spends frames, so the line left on the
## page is the one the source leaves on it.
const PROMPT_BYE: String = "Bye, %s!"
const PARTY_NAME: String = "PARTY PKMN"

## `wBillsPC_LoadedBox`: zero is the party and the boxes follow it.
const LOADED_PARTY: int = 0

## Which of `_BillsPC.Jumptable`'s three list rows opened this screen.
const MODE_DEPOSIT: int = 0
const MODE_WITHDRAW: int = 1
## `_MovePKMNWithoutMail`, which is neither list: left and right load any of the
## party and the fourteen boxes, and A twice moves a Pokemon from one place in
## one of them to another place in another.
const MODE_MOVE: int = 2
## Its two `.Joypad` passes: choosing the Pokemon and choosing where it goes.
const MOVE_PHASE_CHOOSE: int = 0
const MOVE_PHASE_INSERT: int = 1
## `PCString_MoveToWhere` and `PCString_TheresNoRoom`.
const PROMPT_MOVE_WHERE: String = "Move to where?"
const PROMPT_NO_ROOM: String = "There's no room."
## `.MenuData`'s own three rows, which drop the RELEASE the other two lists have.
const SUBMENU_ROWS_MOVE: Array[String] = ["MOVE", "STATS", "CANCEL"]
const SUBMENU_MOVE_STATS: int = 1
const SUBMENU_MOVE_CANCEL: int = 2

## `BillsPCDepositMenuHeader` and `BillsPC_Withdraw.MenuHeader`, the same
## `menu_coords 9, 4, SCREEN_WIDTH - 1, 13` over the listing, and the yes/no
## `lb bc, 14, 11` puts under it. `_YesNoBox` adds five and four to the corner it
## is handed.
const SUBMENU_FLAGS: int = Gen2MenuBox.STATICMENU_CURSOR
const SUBMENU_AT: Rect2i = Rect2i(9, 4, 10, 9)
const RELEASE_AT: Vector2i = Vector2i(14, 11)
const RELEASE_SPAN: Vector2i = Vector2i(5, 4)
const RELEASE_OPTIONS: Array[String] = ["YES", "NO"]

## `BillsPCDepositJumptable` and `BillsPC_Withdraw.dw`: the same four rows, whose
## first is the transfer the loaded list implies.
const SUBMENU_TRANSFER: int = 0
const SUBMENU_STATS: int = 1
const SUBMENU_RELEASE: int = 2
const SUBMENU_CANCEL: int = 3
const SUBMENU_ROWS: Array[String] = ["DEPOSIT", "STATS", "RELEASE", "CANCEL"]
const SUBMENU_ROWS_WITHDRAW: Array[String] = ["WITHDRAW", "STATS", "RELEASE", "CANCEL"]

## `BillsPC_CheckMail_PreventBlackout`'s own `cp $3` against
## `wBillsPC_NumMonsInBox`, which `CopyBoxmonSpecies` leaves one over the party
## count because the CANCEL row is in it.
const BLACKOUT_ROWS: int = 3

var _data: GameData = null
var _data_override: GameData = null
var _save: Gen2SaveData = null
var _save_override: Gen2SaveData = null
var _persist: bool = true
var _embedded: bool = false
var _box_index: int = 0
var _selected_box_slot: int = -1
var _selected_party_index: int = -1
## `wBillsPC_LoadedBox`, `wBillsPC_CursorPosition` and `wBillsPC_ScrollPosition`.
var _loaded: int = LOADED_PARTY
var _cursor: int = 0
var _scroll: int = 0
## The line the bottom box carries, which is `PCString_ChooseaPKMN` until a
## transfer answers.
var _prompt: String = PROMPT_CHOOSE
## `MovePKMNWithoutMail_InsertMon`'s two waits, and the clock that spends them.
var _saving_frames: int = 0
var _saving_saved: bool = false
var _saving_clock := Gen2WorldAnimation.FrameClock.new()
## `_DepositPKMN` or `_WithdrawPKMN`, and the submenu, the release yes/no and
## the stats screen either of them can put over the listing.
var _mode: int = MODE_DEPOSIT
## `wJumptableIndex`'s two joypad passes and the backup `.Move` takes of where
## the Pokemon came from, which `.b_button_2` puts back.
var _move_phase: int = MOVE_PHASE_CHOOSE
var _move_from_loaded: int = LOADED_PARTY
var _move_from_index: int = -1
var _move_backup: Array = []
var _submenu_open: bool = false
var _submenu_cursor: int = 0
var _release_open: bool = false
var _release_cursor: int = 0
var _stats: Gen2MonStatsScreen = null
var _stats_page: Gen2StatsScreenPage = null
var _menu_page: Gen2MenuPage = null
var _page: Gen2PCBoxPage = null
## The screen this is drawn in, and the 160x144 layer inside it.
var _screen: Gen2Screen = null
var _field: Control = null
var _backdrop: Gen2Screen.Field = null
var _background: TextureRect = null
var _pic: TextureRect = null
var _cursor_sprites: Array[TextureRect] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_data = _data_override if _data_override != null else _resolve_data()
	_save = _save_override if _save_override != null else _resolve_save()
	_page = Gen2PCBoxPage.from_data(_data)
	_build()
	_refresh()
	# Not while embedded in the overworld: the world screen routes buttons here
	# itself, and a focus ring appearing over the map would be the map's.
	if not _embedded:
		Gen2FocusGuard.attach(self)


## Supplies the cache/save context. Embedded overworld use can keep the same
## atomic storage operations in memory while a selected runtime save persists.
func set_context(
	data: GameData, save: Gen2SaveData, persist: bool = true, embedded: bool = false,
	mode: int = MODE_DEPOSIT, box_index: int = 0
) -> void:
	_data_override = data
	_save_override = save
	_persist = persist
	_embedded = embedded
	_data = data
	_save = save
	_mode = mode if mode in [MODE_DEPOSIT, MODE_WITHDRAW, MODE_MOVE] else MODE_DEPOSIT
	_box_index = clampi(box_index, 0, Gen2SaveData.BOX_COUNT - 1)
	## `.Init` writes `wBillsPC_LoadedBox` itself, so which list is up is the
	## mode's rather than anything the last screen left behind. MOVE PKMN W/O
	## MAIL opens on `wCurBox`, which is the box the machine is already on.
	_loaded = LOADED_PARTY if _mode == MODE_DEPOSIT else _box_index + 1
	_move_phase = MOVE_PHASE_CHOOSE
	_move_from_index = -1
	_move_backup = []
	_cursor = 0
	_scroll = 0
	_prompt = PROMPT_CHOOSE
	if is_inside_tree():
		if _page == null:
			_page = Gen2PCBoxPage.from_data(_data)
		_refresh()


func box_snapshot() -> Dictionary:
	var boxes: Array = []
	if _save != null:
		for box_index: int in Gen2SaveData.BOX_COUNT:
			var slots: Array = []
			var box: Gen2SaveBox = _save.boxes[box_index] if box_index < _save.boxes.size() else null
			for slot: int in Gen2SaveBox.CAPACITY:
				var mon: Gen2SaveMon = box.slots[slot] if box != null and slot < box.slots.size() else null
				slots.append(_mon_snapshot(box_index, slot, mon))
			boxes.append({"index": box_index, "slots": slots})
	return {
		"box": _box_index,
		"selected_box_slot": _selected_box_slot,
		"selected_party_index": _selected_party_index,
		"loaded": _loaded,
		"cursor": _cursor,
		"scroll": _scroll,
		"prompt": _prompt,
		"mode": _mode,
		"submenu": _submenu_labels() if _submenu_open else [],
		"submenu_cursor": _submenu_cursor if _submenu_open else -1,
		"release": _release_cursor if _release_open else -1,
		"stats": _stats != null,
		"boxes": boxes,
	}


func select_box(box_index: int) -> bool:
	if _save == null or box_index < 0 or box_index >= _save.boxes.size():
		return false
	_box_index = box_index
	_selected_box_slot = -1
	if _mode == MODE_WITHDRAW:
		_loaded = box_index + 1
	_cursor = 0
	_scroll = 0
	_refresh()
	return true


func select_box_slot(slot: int) -> bool:
	if slot < 0 or slot >= Gen2SaveBox.CAPACITY:
		return false
	_selected_box_slot = slot
	_selected_party_index = -1
	_refresh()
	return true


func select_party_member(index: int) -> bool:
	if _save == null or index < 0 or index >= _save.party.size():
		return false
	_selected_party_index = index
	_selected_box_slot = -1
	_refresh()
	return true


## `DepositPokemon`. A transaction reason never reaches the page: the source
## prints one of its own strings for each refusal it has, and one it has none for
## is one the joypad cannot ask for.
func deposit_selected_party() -> bool:
	if _save == null or _selected_party_index < 0:
		_prompt = PROMPT_CHOOSE
		_refresh()
		return false
	var mon_name: String = _display_name(_save.party[_selected_party_index] as Gen2SaveMon)
	var result: Dictionary = Gen2SaveStorage.deposit_party_to_box(
		_save, _data, _selected_party_index, _box_index, -1, _persist
	)
	if not bool(result.get("ok", false)):
		_prompt = _refusal(result, PROMPT_BOX_FULL)
		_refresh()
		return false
	_prompt = PROMPT_STORED % mon_name
	_selected_party_index = -1
	_clamp_cursor()
	_refresh()
	return true


## `TryWithdrawPokemon`, whose one refusal is `PCString_PartyFull`.
func withdraw_selected_box() -> bool:
	if _save == null or _selected_box_slot < 0:
		_prompt = PROMPT_CHOOSE
		_refresh()
		return false
	var box: Gen2SaveBox = _save.boxes[_box_index] if _box_index < _save.boxes.size() else null
	var mon_name: String = _display_name(
		box.slots[_selected_box_slot] as Gen2SaveMon if box != null else null
	)
	var result: Dictionary = Gen2SaveStorage.withdraw_box_to_party(
		_save, _data, _box_index, _selected_box_slot, _persist
	)
	if not bool(result.get("ok", false)):
		_prompt = _refusal(result, PROMPT_PARTY_FULL)
		_refresh()
		return false
	_prompt = PROMPT_GOT % mon_name
	_selected_box_slot = -1
	_clamp_cursor()
	_refresh()
	return true


## `.release`, behind the yes/no both submenus put up. The party's own blackout
## check has already run: the source asks it before the question, not after.
func release_selected() -> bool:
	if _save == null:
		return false
	var mon: Gen2SaveMon = _selected_mon()
	var mon_name: String = _display_name(mon)
	var result: Dictionary = Gen2SaveStorage.release_party_member(
		_save, _data, _selected_party_index, _persist
	) if _loaded == LOADED_PARTY else Gen2SaveStorage.release_box_slot(
		_save, _data, _box_index, _selected_box_slot, _persist
	)
	if not bool(result.get("ok", false)):
		_prompt = _refusal(result, PROMPT_LAST_MON)
		_refresh()
		return false
	_prompt = PROMPT_BYE % mon_name
	_selected_party_index = -1
	_selected_box_slot = -1
	_clamp_cursor()
	_refresh()
	return true


## The line a refused transaction prints. Every reason the joypad can produce has
## a string of its own; anything else is a damaged save reaching a screen that
## cannot say so, and takes the caller's own line rather than a symbol name.
func _refusal(result: Dictionary, fallback: String) -> String:
	match StringName(result.get("reason", &"")):
		&"box_full", &"box_slot_occupied":
			return PROMPT_BOX_FULL
		&"party_full":
			return PROMPT_PARTY_FULL
		&"last_party_member":
			return PROMPT_LAST_MON
	return fallback


## `Withdraw_UpDown` and the two jumptables around it: up and down walk the list,
## A takes the row the cursor stands on and B leaves. Left and right belong to
## MOVE PKMN W/O MAIL alone and do nothing here.
func handle_button(button: int) -> bool:
	if _saving_frames > 0:
		## Two `DelayFrames`, which read no joypad.
		return true
	if _stats != null:
		return _stats.handle_button(button)
	if _release_open:
		return _handle_release_button(button)
	if _submenu_open:
		return _handle_submenu_button(button)
	match button:
		Gen2Button.UP:
			_press_up()
		Gen2Button.DOWN:
			_press_down()
		Gen2Button.LEFT, Gen2Button.RIGHT:
			## `MoveMonWithoutMail_DPad`'s carry: left and right load the list
			## before or after this one, and the cursor starts again at its top.
			## They belong to MOVE PKMN W/O MAIL alone and do nothing elsewhere.
			if _mode != MODE_MOVE:
				return false
			_load_neighbour(-1 if button == Gen2Button.LEFT else 1)
		Gen2Button.A:
			_confirm()
		Gen2Button.B:
			_back()
		_:
			return false
	return true


## `VerticalMenu` over the listing. Its B is the CANCEL row, which is
## `BillsPCDepositFuncCancel`: back to the list, nothing done.
func _handle_submenu_button(button: int) -> bool:
	match button:
		Gen2Button.UP:
			_submenu_cursor = wrapi(_submenu_cursor - 1, 0, _submenu_labels().size())
		Gen2Button.DOWN:
			_submenu_cursor = wrapi(_submenu_cursor + 1, 0, _submenu_labels().size())
		Gen2Button.A:
			_confirm_submenu()
			return true
		Gen2Button.B:
			_close_submenu()
			return true
		_:
			return false
	_refresh()
	return true


## `PlaceYesNoBox`, whose B is its NO.
func _handle_release_button(button: int) -> bool:
	match button:
		Gen2Button.UP:
			_release_cursor = wrapi(_release_cursor - 1, 0, RELEASE_OPTIONS.size())
		Gen2Button.DOWN:
			_release_cursor = wrapi(_release_cursor + 1, 0, RELEASE_OPTIONS.size())
		Gen2Button.A:
			_release_open = false
			if _release_cursor == 0:
				_close_submenu(false)
				release_selected()
			else:
				_prompt = PROMPT_WHATS_UP
				_refresh()
			return true
		Gen2Button.B:
			_release_open = false
			_prompt = PROMPT_WHATS_UP
			_refresh()
			return true
		_:
			return false
	_refresh()
	return true


## The submenu's own four rows, whose first is named for the list that is loaded.
func _submenu_labels() -> Array:
	if _mode == MODE_MOVE:
		return SUBMENU_ROWS_MOVE
	return SUBMENU_ROWS_WITHDRAW if _loaded != LOADED_PARTY else SUBMENU_ROWS


## `.WhatsUp`/`.PrepSubmenu`: the string changes and the cursor opens on the
## transfer row, which is `ld a, $1 / ld [wMenuCursorY], a`.
func _open_submenu() -> void:
	_submenu_open = true
	_submenu_cursor = 0
	_prompt = PROMPT_WHATS_UP
	_refresh()


func _close_submenu(redraw: bool = true) -> void:
	_submenu_open = false
	_release_open = false
	_prompt = PROMPT_CHOOSE
	if redraw:
		_refresh()


func _confirm_submenu() -> void:
	if _mode == MODE_MOVE:
		match _submenu_cursor:
			SUBMENU_TRANSFER:
				## `.Move`: `BillsPC_CheckMail_PreventBlackout` first, and then
				## the second joypad pass over whichever list is loaded then.
				var refusal: String = _blackout_refusal()
				if not refusal.is_empty():
					_close_submenu(false)
					_prompt = refusal
					_refresh()
					return
				_close_submenu(false)
				_begin_move()
			SUBMENU_MOVE_STATS:
				_open_stats()
			_:
				_close_submenu()
		return
	match _submenu_cursor:
		SUBMENU_TRANSFER:
			var refusal: String = _blackout_refusal()
			if not refusal.is_empty():
				_close_submenu(false)
				_prompt = refusal
				_refresh()
				return
			_close_submenu(false)
			if _loaded == LOADED_PARTY:
				deposit_selected_party()
			else:
				withdraw_selected_box()
		SUBMENU_STATS:
			_open_stats()
		SUBMENU_RELEASE:
			var blocked: String = _blackout_refusal()
			if blocked.is_empty() and _selected_mon() != null \
					and (_selected_mon() as Gen2SaveMon).is_egg:
				## `BillsPC_IsMonAnEgg`, which the box side checks on its own and
				## the party side reaches behind the blackout check.
				blocked = PROMPT_NO_EGGS
			if not blocked.is_empty():
				_close_submenu(false)
				_prompt = blocked
				_refresh()
				return
			_release_open = true
			_release_cursor = 0
			_prompt = PROMPT_RELEASE
			_refresh()
		_:
			_close_submenu()


## `BillsPC_CheckMail_PreventBlackout`, which guards the party list's transfer
## and its release alike, in its own order: the last Pokemon, then a party with
## nothing else standing, then mail.
func _blackout_refusal() -> String:
	if _loaded != LOADED_PARTY or _save == null:
		return ""
	if rows().size() < BLACKOUT_ROWS:
		return PROMPT_LAST_MON
	if _all_others_fainted():
		return PROMPT_NO_USABLE
	# `wBillsPC_MonHasMail`, which `BillsPC_PrintMonInfo` writes for the row the
	# cursor stands on rather than for a stored selection.
	var mon: Gen2SaveMon = _selected_mon()
	if mon != null and not mon.is_egg and Gen2HeldItem.is_mail(mon.item):
		return PROMPT_REMOVE_MAIL
	return ""


## `CheckCurPartyMonFainted`: whether every party member but the chosen one has
## no HP left. `wCurPartyMon` is `wBillsPC_CursorPosition` plus the scroll, so
## the one left out is the row under the cursor.
func _all_others_fainted() -> bool:
	var chosen: int = _cursor + _scroll
	for index: int in _save.party.size():
		if index == chosen:
			continue
		var mon: Gen2SaveMon = _save.party[index]
		if mon != null and mon.hp > 0:
			return false
	return true


## `BillsPC_StatsScreen`, which is `StatsScreenInit` over this screen and hands
## control back on the way out.
func _open_stats() -> void:
	var mon: Gen2SaveMon = _selected_mon()
	if mon == null or _data == null:
		return
	_stats = Gen2MonStatsScreen.create(_data, [mon])
	_stats.closed.connect(_close_stats)
	_stats.cry_requested.connect(func(species: int) -> void: cry_requested.emit(species))
	_stats.announce()
	_refresh()


## The submenu is still up behind it, which is where `.stats` returns.
func _close_stats() -> void:
	_stats = null
	_prompt = PROMPT_WHATS_UP
	_refresh()


## The list `CopyBoxmonSpecies` builds: every occupied slot of the loaded list,
## then the CANCEL row its `ld a, -1` terminator becomes.
func rows() -> Array:
	var out: Array = []
	for entry: Array in _entries():
		var mon: Gen2SaveMon = entry[1]
		out.append({
			"name": _display_name(mon), "index": int(entry[0]), "cancel": false,
		})
	out.append({"name": Gen2PCBoxPage.CANCEL, "index": -1, "cancel": true})
	return out


func _entries() -> Array:
	var out: Array = []
	if _save == null:
		return out
	if _loaded == LOADED_PARTY:
		for index: int in _save.party.size():
			out.append([index, _save.party[index]])
		return out
	var box: Gen2SaveBox = _save.boxes[_box_index] if _box_index < _save.boxes.size() else null
	if box == null:
		return out
	for slot: int in Gen2SaveBox.CAPACITY:
		if slot < box.slots.size() and box.slots[slot] != null:
			out.append([slot, box.slots[slot]])
	return out


func _resolve_data() -> GameData:
	return Gen2GameRuntime.data_or_any()


func _resolve_save() -> Gen2SaveData:
	return Gen2GameRuntime.selected_save_or_null() if _data != null else null


func _build() -> void:
	var screen: Gen2Screen = Gen2Screen.host_for(self, _screen)
	if screen == null:
		return
	_screen = screen
	_field = Control.new()
	_field.size = Vector2(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.display(_field)
	## The page is drawn with colour 0 transparent so the pic shows through the
	## cell it is composed into, which leaves the backdrop to fill it.
	_backdrop = Gen2Screen.Field.create(Color.WHITE)
	_field.add_child(_backdrop)
	## The pic sits under the page so the listing's border stays drawn over it,
	## the way the hardware's own window does.
	_pic = _sprite()
	_background = _sprite()
	for _index: int in Gen2PCBoxPage.max_cursor_sprites():
		_cursor_sprites.append(_sprite())


func _sprite() -> TextureRect:
	var node := TextureRect.new()
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field.add_child(node)
	return node


## Drawing only. The selection is [method _sync_selection]'s, so a caller that
## picked a slot by hand keeps it and a cache carrying no font still draws
## nothing without losing one.
func _refresh() -> void:
	var mon: Gen2SaveMon = _selected_mon()
	if _page == null or _background == null:
		return
	if _stats != null:
		_refresh_stats()
		return
	var visible_rows: Array = []
	var all_rows: Array = rows()
	for index: int in Gen2PCBoxPage.LIST_HEIGHT:
		var at: int = _scroll + index
		if at < all_rows.size():
			visible_rows.append(all_rows[at])
	var indices: PackedByteArray = _page.draw({
		"box_name": _box_name(),
		"rows": visible_rows,
		"prompt": _prompt,
		"mon": _mon_state(mon),
	})
	_draw_menus(indices)
	var palette: PackedColorArray = _interface_palette()
	if _backdrop != null:
		_backdrop.color = palette[0]
	Gen2PicImage.show(_background, Gen2PicImage.from_indices(
		indices, Gen2Screen.WIDTH, Gen2Screen.HEIGHT, palette, true
	))
	_background.size = Vector2(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)
	_refresh_pic(mon)
	## `.WhatsUp` and `.PrepSubmenu` both open with `ClearSprites`, and the
	## picture is tilemap rather than OAM, so only the ring goes.
	_refresh_cursor(0 if _submenu_open else all_rows.size())


## The submenu, and the release yes/no under it, into the page's own buffer:
## `VerticalMenu` and `PlaceYesNoBox` draw over the tilemap that is already up.
func _draw_menus(indices: PackedByteArray) -> void:
	if not _submenu_open:
		return
	if _menu_page == null:
		_menu_page = Gen2MenuPage.from_data(_data)
	if _menu_page == null:
		return
	var width: int = Gen2Screen.WIDTH
	_menu_page.draw(
		Gen2MenuBox.from_coords(
			SUBMENU_AT.position.x, SUBMENU_AT.position.y,
			SUBMENU_AT.position.x + SUBMENU_AT.size.x,
			SUBMENU_AT.position.y + SUBMENU_AT.size.y, SUBMENU_FLAGS
		),
		_submenu_labels(), _submenu_cursor, indices, width
	)
	if not _release_open:
		return
	_menu_page.draw(
		Gen2MenuBox.from_coords(
			RELEASE_AT.x, RELEASE_AT.y,
			RELEASE_AT.x + RELEASE_SPAN.x, RELEASE_AT.y + RELEASE_SPAN.y,
			SUBMENU_FLAGS | Gen2MenuBox.STATICMENU_NO_TOP_SPACING
		),
		RELEASE_OPTIONS, _release_cursor, indices, width
	)


## `StatsScreenInit` over this screen, drawn the way the party menu draws it: the
## front pic has a palette of its own and is composed on top of the page.
func _refresh_stats() -> void:
	if _stats_page == null:
		_stats_page = Gen2StatsScreenPage.from_data(_data)
	if _stats_page == null:
		return
	var snapshot: Dictionary = _stats.snapshot()
	var image: Image = _stats_page.render(snapshot, _data)
	if image == null:
		return
	Gen2PicImage.show(_background, image)
	_background.size = Vector2(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)
	if _backdrop != null:
		_backdrop.color = Color.WHITE
	_refresh_stats_pic(snapshot)
	_refresh_cursor(0)


## `PrepMonFrontpic`'s cell, the same one [method _refresh_pic] places a listing
## picture in, at the stats screen's own corner.
func _refresh_stats_pic(snapshot: Dictionary) -> void:
	if _pic == null:
		return
	_pic.texture = null
	var species: int = int(snapshot.get("species", 0))
	if species <= 0 or _data == null:
		return
	var egg: bool = bool(snapshot.get("egg", false))
	var pic: Dictionary = _data.egg_pic() if egg else _data.species_pic(species)
	if pic.is_empty():
		return
	var art: Image = Gen2PicImage.from_atlas(
		_data.atlas_indices(pic["atlas"]), _data.atlas(pic["atlas"]), pic,
		_data.egg_palette() if egg \
			else _data.palette(species, bool(snapshot.get("shiny", false)))
	)
	if art == null:
		return
	Gen2PicImage.show(_pic, art)
	_pic.size = Vector2(art.get_size())
	var cell: int = Gen2StatsScreenPage.pic_size()
	_pic.position = Vector2(Gen2StatsScreenPage.pic_position()) + Vector2(
		float(cell - art.get_width()) * 0.5, float(cell - art.get_height())
	)


## `_CGB_BillsPC`'s background palette, PREDEFPAL_POKEDEX, which the Pokedex
## already imports as its own interface palette.
func _interface_palette() -> PackedColorArray:
	var colors: PackedColorArray = _data.pokedex_palette("interface") if _data != null \
		else PackedColorArray()
	if colors.is_empty():
		return Gen2Palette.pic_palette(PackedColorArray([Color.WHITE, Color.BLACK]))
	return colors


## Which slot the cursor stands on, kept in the two fields the transfers read so
## that walking the list and picking a slot by hand are the same selection.
func _sync_selection() -> void:
	if _selected_mon() == null:
		return
	var entries: Array = _entries()
	var at: int = _cursor + _scroll
	if at < 0 or at >= entries.size():
		return
	if _loaded == LOADED_PARTY:
		_selected_party_index = int(entries[at][0])
		_selected_box_slot = -1
		return
	_selected_box_slot = int(entries[at][0])
	_selected_party_index = -1


func _selected_mon() -> Gen2SaveMon:
	var entries: Array = _entries()
	var at: int = _cursor + _scroll
	if at < 0 or at >= entries.size():
		return null
	return entries[at][1]


## `PCMonInfo`'s own fields. An egg is drawn as its pic and nothing else, which
## is where the source returns.
func _mon_state(mon: Gen2SaveMon) -> Dictionary:
	if mon == null or _data == null:
		return {}
	if mon.is_egg:
		return {}
	return {
		"level": mon.level,
		"gender": _gender_glyph(Gen2BattleMon.gender_for(_data, mon.species, mon.dvs)),
		"species_name": String(_data.species(mon.species).get("name", "")),
		"item": mon.item,
		## `ItemIsMail`, which picks the mail icon `$5c` over the item icon `$5d`
		## and is what `wBillsPC_MonHasMail` records for the blackout guard.
		"mail": Gen2HeldItem.is_mail(mon.item),
	}


func _gender_glyph(gender: StringName) -> String:
	if gender == Gen2BattleMon.GENDER_MALE:
		return "♂"
	if gender == Gen2BattleMon.GENDER_FEMALE:
		return "♀"
	return " "


func _refresh_pic(mon: Gen2SaveMon) -> void:
	if _pic == null:
		return
	_pic.texture = null
	if mon == null or _data == null:
		return
	var pic: Dictionary = _data.species_pic(mon.species)
	if pic.is_empty():
		return
	var image: Image = Gen2PicImage.from_atlas(
		_data.atlas_indices(pic["atlas"]), _data.atlas(pic["atlas"]), pic,
		## `_CGB_BillsPC` reaches `GetMonNormalOrShinyPalettePointer`, so the
		## selection is drawn shiny here the way it is on its own stats page.
		_data.palette(mon.species, Gen2Stats.is_shiny(mon.dvs))
	)
	Gen2PicImage.show(_pic, image)
	_pic.size = Vector2(image.get_size())
	## `_PrepMonFrontpic` places a pic smaller than the seven-tile cell at its
	## bottom, which is what keeps every species standing on the same line.
	var cell: int = Gen2PCBoxPage.pic_size()
	_pic.position = Vector2(Gen2PCBoxPage.pic_position()) + Vector2(
		float(cell - image.get_width()) * 0.5, float(cell - image.get_height())
	)


func _refresh_cursor(row_count: int) -> void:
	var sprites: Array = _page.cursor_sprites(_cursor, row_count)
	var sheet: PackedByteArray = _data.tile_indices("pc_select") if _data != null \
		else PackedByteArray()
	var palette: PackedColorArray = _data.party_menu_icon_palette(0) if _data != null \
		else PackedColorArray()
	for index: int in _cursor_sprites.size():
		var node: TextureRect = _cursor_sprites[index]
		node.visible = index < sprites.size() and not sheet.is_empty() \
			and not palette.is_empty()
		if not node.visible:
			continue
		var sprite: Dictionary = sprites[index]
		node.position = Vector2(sprite["position"])
		Gen2PicImage.show(node, _cursor_image(
			sheet, palette, int(sprite["tile"]),
			bool(sprite["flip_x"]), bool(sprite["flip_y"])
		))


## One tile of `PCSelectLZ`, flipped the way its OAM attribute asks. `B_OAM_XFLIP`
## flips the tile where it stands rather than mirroring a square, which is why
## each object is drawn on its own.
func _cursor_image(
	sheet: PackedByteArray, palette: PackedColorArray, tile: int,
	flip_x: bool, flip_y: bool
) -> Image:
	var side: int = Gen2Font.TILE
	var cell := PackedByteArray()
	cell.resize(side * side)
	Gen2Font.blit_slot(
		sheet, RomLayout.PC_SELECT_TILES * side, tile, cell, side, 0, 0
	)
	var image: Image = Gen2PicImage.from_indices(cell, side, side, palette, true)
	if flip_x:
		image.flip_x()
	if flip_y:
		image.flip_y()
	return image


## `BillsPC_BoxName`, which names the party or the loaded box.
func _box_name() -> String:
	if _loaded == LOADED_PARTY:
		return PARTY_NAME
	return _save.box_name(_box_index) if _save != null else ""


func _mon_snapshot(box: int, slot: int, mon: Gen2SaveMon) -> Dictionary:
	if mon == null:
		return {"empty": true, "box": box, "slot": slot}
	return {
		"empty": false, "box": box, "slot": slot,
		"name": _display_name(mon), "species": mon.species, "level": mon.level,
	}


func _display_name(mon: Gen2SaveMon) -> String:
	if mon == null:
		return ""
	if not mon.nickname.is_empty():
		return mon.nickname
	return String(_data.species(mon.species).get("name", "UNKNOWN")) if _data != null \
		else "UNKNOWN"


func _press_up() -> void:
	if _cursor > 0:
		_cursor -= 1
	elif _scroll > 0:
		_scroll -= 1
	else:
		return
	_sync_selection()
	_refresh()


## `BillsPC_PressDown`: the cursor stops one row short of the list's length and
## the scroll takes over at the bottom of the five rows on screen.
func _press_down() -> void:
	var count: int = rows().size()
	if _cursor + _scroll + 1 >= count:
		return
	if _cursor + 1 < Gen2PCBoxPage.LIST_HEIGHT:
		_cursor += 1
	else:
		_scroll += 1
	_sync_selection()
	_refresh()


## A on the CANCEL row leaves, the way `.a_button`'s `cp -1` does; on any other
## row it opens the submenu.
func _confirm() -> void:
	if _mode == MODE_MOVE and _move_phase == MOVE_PHASE_INSERT:
		_insert_moved_mon()
		return
	var all_rows: Array = rows()
	var at: int = _cursor + _scroll
	if at < 0 or at >= all_rows.size() or bool((all_rows[at] as Dictionary)["cancel"]):
		_back()
		return
	_sync_selection()
	_open_submenu()


## `MoveMonWithoutMail_DPad`: the party is `wBillsPC_LoadedBox` zero and the
## fourteen boxes follow it, wrapping either way.
func _load_neighbour(step: int) -> void:
	_loaded = wrapi(_loaded + step, 0, Gen2SaveData.BOX_COUNT + 1)
	if _loaded != LOADED_PARTY:
		_box_index = _loaded - 1
	_cursor = 0
	_scroll = 0
	_selected_box_slot = -1
	_selected_party_index = -1
	_refresh()


## `.Move`: the list and the row the Pokemon came from are backed up, and the
## second pass begins wherever the first one left off.
func _begin_move() -> void:
	_move_from_loaded = _loaded
	_move_from_index = _cursor + _scroll
	_move_backup = [_loaded, _cursor, _scroll]
	_move_phase = MOVE_PHASE_INSERT
	_prompt = PROMPT_MOVE_WHERE
	_refresh()


## `.a_button_2`: `BillsPC_CheckSpaceInDestination` and then
## `MovePKMNWithoutMail_InsertMon`, which puts up a box for twenty frames, moves
## the Pokemon and saves behind it. The move lands in front of the box here
## rather than behind it, which the box itself covers.
func _insert_moved_mon() -> void:
	var result: Dictionary = Gen2SaveStorage.move_mon(
		_save, _data, _move_from_loaded, _move_from_index, _loaded,
		_cursor + _scroll, _persist
	)
	if not bool(result.get("ok", false)):
		## `.no_space` steps the jumptable back one, which leaves the insert
		## cursor where it was with the box's own refusal printed under it.
		_prompt = PROMPT_NO_ROOM if StringName(
			result.get("reason", &"")
		) == &"no_room_in_destination" else _refusal(result, PROMPT_NO_ROOM)
		_refresh()
		return
	_prompt = Gen2SavePrompt.SAVING_LEAVE_ON
	_saving_frames = Gen2SavePrompt.LEAVE_ON_FRAMES
	_saving_saved = false
	set_process(true)
	_refresh()


## `MoveMonWOMail_InsertMon_SaveGame`'s `SFX_SAVE` and twenty-four frames, with
## the box still up: the save runs behind it.
func _saved_moved_mon() -> void:
	sfx_requested.emit(Gen2SavePrompt.SFX_SAVE, true)
	_saving_frames = Gen2SavePrompt.INSERT_SAVED_FRAMES
	_saving_saved = true


## The two waits, one hardware frame at a time. Public so a test owns its own.
func advance_saving_frames(count: int) -> void:
	for _step: int in count:
		if _saving_frames <= 0:
			return
		_saving_frames -= 1
		if _saving_frames > 0:
			continue
		if _saving_saved:
			set_process(false)
			_saving_saved = false
			_end_move()
		else:
			_saved_moved_mon()


func _process(delta: float) -> void:
	if _saving_frames <= 0:
		set_process(false)
		return
	advance_saving_frames(_saving_clock.tick(delta))


## `.Cancel` and `.b_button_2` alike: the first pass again, on the list the
## Pokemon was chosen from.
func _end_move() -> void:
	if _move_backup.size() == 3:
		_loaded = int(_move_backup[0])
		_cursor = int(_move_backup[1])
		_scroll = int(_move_backup[2])
		if _loaded != LOADED_PARTY:
			_box_index = _loaded - 1
	_move_phase = MOVE_PHASE_CHOOSE
	_move_from_index = -1
	_move_backup = []
	_prompt = PROMPT_CHOOSE
	_clamp_cursor()
	_refresh()


## After a transfer the list is one row shorter, so the cursor comes back inside
## it the way `CopyBoxmonSpecies` and the joypad bounds do together.
func _clamp_cursor() -> void:
	var count: int = rows().size()
	while _cursor + _scroll >= count and (_cursor > 0 or _scroll > 0):
		if _scroll > 0:
			_scroll -= 1
		else:
			_cursor -= 1
	_selected_box_slot = -1
	_selected_party_index = -1


func _back() -> void:
	if _mode == MODE_MOVE and _move_phase == MOVE_PHASE_INSERT:
		_end_move()
		return
	if _embedded:
		close_embedded()
		return
	get_tree().change_scene_to_file.call_deferred("res://game/save/party_screen.tscn")


func close_embedded() -> void:
	if not _embedded:
		return
	closed.emit({"ok": true, "script_value": 0, "changed": false})


## The screen the opener wants this drawn in, as [Gen2PokegearScreen] takes it.
func set_screen(screen: Gen2Screen) -> void:
	_screen = screen


## The field lives in a screen this node may not own, so it goes by hand.
func _exit_tree() -> void:
	if _field != null:
		Gen2Screen.drop_on_exit(_field)
		_field = null
