class_name Gen2PartyScreen
extends Control

## The party menu, in the two places it is opened from. Embedded in the overworld
## it is `PartyMenu` itself: `StartMenu_Pokemon` runs `InitPartyMenuWithCancel`
## and `PokemonActionSubmenu` opens `MonSubmenu`'s box over the bottom of it, so
## the embedded view is [Gen2PartyMenuPage] and [Gen2MenuPage] at hardware
## resolution and the model below is what `PartyMenuSelect` answers. The
## launcher's own party view, which is not a cartridge screen, keeps the
## window-resolution panel and carries the PC storage and development battle
## buttons that no cartridge has.

## Emitted only when embedded, mirroring Gen2BoxScreen.closed: the overworld
## start menu resumes on this rather than the screen navigating away with
## change_scene_to_file, which would tear down the running world.
signal closed(result: Dictionary)
## A chosen submenu entry this screen does not own, mirroring
## Gen2StartMenuScreen.action_chosen. Field moves need the live world, which
## belongs to the world screen, so the choice is reported rather than run here.
signal action_chosen(action: Dictionary)
## A sound this screen owes, by `constants/sfx_constants.asm` index. Emitted
## rather than played: the audio player belongs to whoever embedded this.
signal sfx_requested(index: int, waited: bool)
## `PlayMonCry2`, which the stats screen this menu opens plays on every mon it
## loads. Emitted for the same reason [signal sfx_requested] is.
signal cry_requested(species: int)
## `PartyMenuSelect`'s own answer, when the list was opened as
## `SelectMonFromParty` rather than as `StartMenu_Pokemon`: the chosen party
## index, or -1 for the carry a CANCEL row or a B press returns. Every caller of
## `SelectMonFromParty` (the Name Rater, the move deleter, the seer, the haircut
## brothers) is one of these, so the selection is the list's answer rather than a
## per-caller mode.
signal selection_made(party_index: int)


## The two `MonMenuOptions` rows that open a second party list rather than
## leaving the menu: `MonMenu_Softboiled_MilkDrink` serves both.
const HEAL_TRANSFER_MOVES: Array[int] = [
	Gen2WorldFieldMove.MOVE_SOFTBOILED, Gen2WorldFieldMove.MOVE_MILK_DRINK,
]

## data/mon_menu.asm's MONMENUVALUE_* option strings, in that file's order.
const OPTION_STATS: StringName = &"stats"
const OPTION_SWITCH: StringName = &"switch"
const OPTION_ITEM: StringName = &"item"
const OPTION_CANCEL: StringName = &"cancel"
const OPTION_MOVE: StringName = &"move"
## `GiveTakeItemMenuData`'s own two rows, which ITEM opens rather than answers.
const OPTION_GIVE: StringName = &"give"
const OPTION_TAKE: StringName = &"take"
## `MONMENUITEM_MAIL`, which `GetMonSubmenuItems` puts where ITEM would be when
## `ItemIsMail` answers for the held item, and `MonMailAction`'s own three rows.
const OPTION_MAIL: StringName = &"mail"
const OPTION_MAIL_READ: StringName = &"mail_read"
const OPTION_MAIL_TAKE: StringName = &"mail_take"
const OPTION_MAIL_QUIT: StringName = &"mail_quit"
## engine/pokemon/mon_submenu.asm's NUM_MONMENU_ITEMS: a list already this long
## drops CANCEL rather than growing.
const MAX_SUBMENU_ITEMS: int = 8

## `PartyMenuStrings`' two rows this screen reaches: `ChooseAMonString` for
## `PARTYMENUACTION_CHOOSE_POKEMON`, which `StartMenu_Pokemon` writes, and
## `UseOnWhichPKMNString` for the `PARTYMENUACTION_HEALING_ITEM` that
## `.SelectMilkDrinkRecipient` sets. Engine text no importer reads, like the rest
## of `data/text/common_*.asm`.
## `constants/menu_constants.asm`'s PARTYMENUACTION_*. Two reach this screen:
## `SelectMonFromParty`'s own zero, which every service writes, and the GIVE_MON
## both `SelectTradeOrDayCareMon` callers write.
const ACTION_CHOOSE_POKEMON: int = 0
const ACTION_GIVE_MON: int = 6

const PROMPT_CHOOSE: String = "Choose a #MON."
const PROMPT_USE_ON_WHICH: String = "Use on which PKMN?"

## The two more of `PartyMenuStrings` the pack's own lists reach:
## `ToWhichPKMNString` for `PARTYMENUACTION_GIVE_ITEM`, which `GiveItem` writes,
## and `TeachWhichPKMNString` for the `PARTYMENUACTION_TEACH_TMHM` that
## `TeachTMHM` writes. Kept beside the two above rather than in the screen that
## reads them, so all four strings are in one place.
const PROMPT_TO_WHICH: String = "To which PKMN?"
const PROMPT_TEACH_WHICH: String = "Teach which PKMN?"

## `SwitchPartyMons`' own `PARTYMENUACTION_MOVE` string, `MoveToWhereString`.
const PROMPT_MOVE_TO_WHERE: String = "Move to where?"

## `constants/sfx_constants.asm`'s SFX_SWITCH_POKEMON.
const SFX_SWITCH_POKEMON: int = 0x20

## `_PokemonNotEnoughHPText` and `_ItemCantUseOnMonText`, the two refusals the
## heal transfer prints. Both are a `MenuTextbox` over the menu on the cartridge
## and stand in the menu's own bottom box here. The A or B they wait for is the
## same.
const MESSAGE_NOT_ENOUGH_HP: String = "Not enough HP…"
const MESSAGE_NO_EFFECT: String = "It won't have any effect."

## `MonSubmenu.MenuHeader`'s `menu_coords 6, 0, SCREEN_WIDTH - 1,
## SCREEN_HEIGHT - 1` with `.GetTopCoord`'s own top:
## `1 + bottom - 2 * (count + 1)`, so the box grows upward from the bottom row.
const SUBMENU_LEFT: int = 6
const SUBMENU_RIGHT: int = 19
const SUBMENU_BOTTOM: int = 17

## `GiveTakeItemMenuData`'s `menu_coords 12, 12, SCREEN_WIDTH - 1,
## SCREEN_HEIGHT - 1`, which is a fixed box rather than a grown one.
const ITEM_MENU_BOX: Rect2i = Rect2i(12, 12, 7, 5)
## `MonMailAction.MenuHeader`'s `menu_coords 12, 10, SCREEN_WIDTH - 1,
## SCREEN_HEIGHT - 1`, one row taller than GIVE/TAKE's.
const MAIL_MENU_BOX: Rect2i = Rect2i(12, 10, 7, 7)

var _data: GameData = null
var _data_override: GameData = null
var _save: Gen2SaveData = null
var _save_override: Gen2SaveData = null
var _embedded: bool = false
var _cards: VBoxContainer = null
var _player_label: Label = null
var _status: Label = null
var _storage_button: Gen2LauncherButton = null
var _battle_button: Gen2LauncherButton = null
## The launcher's own appearance, the one [Gen2SaveScreen] is drawn in. The
## window-resolution view is a launcher page and is built out of its parts, so a
## theme change and a narrow window both reach it.
var _palette: Gen2LauncherTheme = null
var _shell: Gen2LauncherShell = null
## The cursor and per-mon submenu. Reachable only through handle_button(),
## which only the world screen calls, so the standalone save-screen view keeps
## its mouse-driven behavior unchanged.
var _member_cursor: int = 0
var _submenu: VBoxContainer = null
var _submenu_items: Array = []
var _submenu_cursor: int = 0
var _submenu_open: bool = false
## Whether the rows on screen are ITEM's GIVE/TAKE box rather than the mon's own
## submenu, which is what B goes back to.
var _item_menu_open: bool = false
## Which fixed box that submenu is drawn in: GIVE/TAKE's or `MonMailAction`'s,
## which is one row taller and two rows higher.
var _fixed_menu_box: Rect2i = ITEM_MENU_BOX
## `.SelectMilkDrinkRecipient`: which party member is giving its health away, and
## which of the two moves asked. -1 and 0 when no recipient list is open.
var _heal_user: int = -1
var _heal_move: int = 0
## `wSwitchMon` less one: which member SWITCH is holding, or -1 when the list is
## not `InitPartyMenuNoCancel`'s.
var _switch_from: int = -1
## `SelectMonFromParty`'s own list: A answers the caller rather than opening
## `PokemonActionSubmenu`, and the prompt is whichever `PartyMenuStrings` row
## the caller wrote into `wPartyMenuActionText`.
var _selecting: bool = false
var _select_prompt: String = PROMPT_CHOOSE
## `wPartyMenuActionText`, which decides the column beside the nicknames.
var _select_action: int = ACTION_CHOOSE_POKEMON

## The hardware screen the embedded view is drawn in, and the two pages drawn
## into it. Handed over by the opener or found around this node; never a second
## one over a window that already has one.
var _hardware: Gen2Screen = null
var _view: TextureRect = null
var _page: Gen2PartyMenuPage = null
var _menu_page: Gen2MenuPage = null
## A refusal standing in the menu's own bottom box, which the next A or B
## clears. See [constant MESSAGE_NOT_ENOUGH_HP].
var _message: String = ""
## Whether this is being read rather than driven. See [method set_read_only].
var _read_only: bool = false
var _frame_clock := Gen2WorldAnimation.FrameClock.new()
## `OpenPartyStats`' own screen, standing over the whole party menu while it is
## up, and the page that draws it.
var _stats: Gen2MonStatsScreen = null
var _stats_page: Gen2StatsScreenPage = null
## `ManagePokemonMoves`' own screen, opened the same way over the same menu.
var _moves: Gen2MoveScreen = null
var _moves_page: Gen2MoveScreenPage = null


func _ready() -> void:
	_data = _data_override if _data_override != null else _resolve_data()
	_save = _save_override if _save_override != null else _resolve_save()
	_build_ui()
	_refresh()
	## Only the hardware view has anything to spend a frame on.
	set_process(_embedded)
	# Not while embedded in the overworld: the world screen routes buttons here
	# itself, and a focus ring appearing over the map would be the map's.
	if not _embedded:
		Gen2FocusGuard.attach(self)


## Test seam for a synthetic cache and validated save. `embedded` is the
## overworld start menu's Pokemon entry: the save-screen navigation actions
## (development battle, PC storage by scene change) do not apply while a
## world is running, so they are hidden rather than left to tear it down.
func set_context(data: GameData, save: Gen2SaveData, embedded: bool = false) -> void:
	_data_override = data
	_save_override = save
	_embedded = embedded
	_data = data
	_save = save
	_member_cursor = 0
	_submenu_open = false
	_item_menu_open = false
	_submenu_items = []
	_submenu_cursor = 0
	_switch_from = -1
	_stats = null
	_moves = null
	if is_inside_tree() and _cards != null:
		_refresh()


## `SelectMonFromParty`: the same `InitPartyMenuWithCancel` list with
## `wPartyMenuActionText` set by the caller, whose A opens no submenu and
## answers [signal selection_made] instead. [param prompt] is the
## `PartyMenuStrings` row that caller writes; the default is the
## PARTYMENUACTION_CHOOSE_POKEMON `SelectMonFromParty` writes with its own
## `xor a`.
func open_selection(
	prompt: String = PROMPT_CHOOSE, action: int = ACTION_CHOOSE_POKEMON
) -> void:
	_selecting = true
	_select_action = action
	_select_prompt = prompt
	_member_cursor = 0
	_submenu_open = false
	_item_menu_open = false
	_submenu_items = []
	_switch_from = -1
	_heal_user = -1
	_heal_move = 0
	_message = ""
	if is_inside_tree():
		_refresh()


func party_snapshot() -> Dictionary:
	var members: Array = []
	if _data != null and _save != null:
		for index: int in Gen2SaveData.MAX_PARTY:
			if index >= _save.party.size():
				members.append({"empty": true, "index": index})
				continue
			members.append(_member_snapshot(index, _save.party[index]))
	return {
		"player_name": _save.player_name if _save != null else "",
		"slot": _save.slot if _save != null else -1,
		"members": members,
	}


## engine/pokemon/mon_submenu.asm's GetMonSubmenuItems for one party member. An
## egg gets three entries and no moves; otherwise the four move slots are walked
## in the mon's own slot order, appending every move that appears in
## MonMenuOptions' field-move rows, and the fixed options follow. Every row is
## acted on, since the screens STATS and MOVE open are built. [param slot] is
## one-based and [param in_battle] is whether the list belongs to a turn: both
## only decide which mod rows are offered.
static func submenu_items_for(
	data: GameData, mon: Gen2SaveMon, slot: int = 0, in_battle: bool = false
) -> Array:
	var items: Array = []
	if mon == null:
		return items
	# The source compares wCurPartySpecies against EGG ($fd); this save model
	# carries the same fact as Gen2SaveMon.is_egg beside a real species.
	## An egg is three rows and no moves, and a mod gets none of them: there is
	## nothing to follow, teach or send out, and the source itself offers less.
	if mon.is_egg:
		items.append(_option_entry(OPTION_STATS, "STATS"))
		items.append(_option_entry(OPTION_SWITCH, "SWITCH"))
		items.append(_option_entry(OPTION_CANCEL, "CANCEL"))
		return items
	for move: int in mon.moves:
		if move == 0 or not Gen2WorldFieldMove.is_field_move(move):
			continue
		items.append({
			"kind": &"field_move",
			"move": move,
			"label": String(data.move(move).get("name", "MOVE")) if data != null else "MOVE",
		})
	items.append(_option_entry(OPTION_STATS, "STATS"))
	## `SwitchPartyMons` makes its own `cp 2` refusal rather than being greyed
	## out, so the row is offered whatever the party holds.
	items.append(_option_entry(OPTION_SWITCH, "SWITCH"))
	items.append(_option_entry(OPTION_MOVE, "MOVE"))
	## `GetMonSubmenuItems`: `ItemIsMail` decides between the two rows, so a
	## member holding mail has no ITEM row at all.
	if Gen2HeldItem.is_mail(mon.item):
		items.append(_option_entry(OPTION_MAIL, "MAIL"))
	else:
		items.append(_option_entry(OPTION_ITEM, "ITEM"))
	## After every cartridge action and before CANCEL, which is the source's own
	## last row and the way out of the box. A mod cannot displace one: the list
	## still stops at `NUM_MONMENU_ITEMS`, so rows past it are simply not offered.
	for entry: Dictionary in Gen2ModHost.instance().party_member_entries(slot, in_battle):
		if items.size() >= MAX_SUBMENU_ITEMS:
			break
		items.append({
			"kind": &"mod_party_action", "mod": entry["kind"],
			"label": entry["label"], "handler": entry["handler"],
		})
	if items.size() < MAX_SUBMENU_ITEMS:
		items.append(_option_entry(OPTION_CANCEL, "CANCEL"))
	return items


static func _option_entry(option: StringName, label: String) -> Dictionary:
	return {"kind": &"option", "option": option, "label": label}


## `GiveTakeItemMenuData`, the two-row box ITEM opens. Both answers need the live
## world the overworld owns, so each is reported rather than run here, the way a
## field move is.
static func item_menu_items() -> Array:
	return [
		{"kind": &"mon_item", "option": OPTION_GIVE, "label": "GIVE"},
		{"kind": &"mon_item", "option": OPTION_TAKE, "label": "TAKE"},
	]


## `MonMailAction.MenuData`'s three rows. READ opens `ReadPartyMonMail` and
## TAKE is `SendMailToPC` or the bag, both of which need the live world.
static func mail_menu_items() -> Array:
	return [
		{"kind": &"mon_mail", "option": OPTION_MAIL_READ, "label": "READ"},
		{"kind": &"mon_mail", "option": OPTION_MAIL_TAKE, "label": "TAKE"},
		{"kind": &"mon_mail", "option": OPTION_MAIL_QUIT, "label": "QUIT"},
	]


func _party_size() -> int:
	return _save.party.size() if _save != null else 0


## Button driver for the embedded overworld view, mirroring
## Gen2StartMenuScreen.handle_button. Returns whether the button was used.
func handle_button(button: int) -> bool:
	## `StatsScreenInit` runs its own joypad loop over the whole screen, so
	## nothing below it is reachable while it is up.
	if _stats != null:
		var used: bool = _stats.handle_button(button)
		if _stats != null:
			_refresh()
		return used
	if _moves != null:
		var used_move: bool = _moves.handle_button(button)
		if _moves != null:
			_refresh()
		return used_move
	## `JoyWaitAorB` behind a refusal: the press that clears the box does nothing
	## else, and a direction is not one of the two it waits for.
	if not _message.is_empty():
		if button == PokeButton.A or button == PokeButton.B:
			_message = ""
			_refresh()
			return true
		return false
	if _party_size() == 0:
		if button == PokeButton.B:
			_cancel()
			return true
		return false
	match button:
		PokeButton.UP:
			_move_cursor(-1)
			return true
		PokeButton.DOWN:
			_move_cursor(1)
			return true
		PokeButton.A:
			_confirm()
			return true
		PokeButton.B:
			_cancel()
			return true
	return false


func _move_cursor(delta: int) -> void:
	if _submenu_open:
		if _submenu_items.is_empty():
			return
		_submenu_cursor = wrapi(_submenu_cursor + delta, 0, _submenu_items.size())
	else:
		_member_cursor = wrapi(_member_cursor + delta, 0, _row_count())
	_refresh()


## `InitPartyMenuWithCancel`, which every way into this menu goes through: the
## party plus the CANCEL row `PlacePartyNicknames.end` prints after it.
func _row_count() -> int:
	## `SwitchPartyMons` reopens through `InitPartyMenuNoCancel`, so the row
	## after the last member is not there to land on.
	return _party_size() if _switch_from >= 0 else _party_size() + 1


## Where the arrow is, which [Gen2PartyMenuPage] counts the same way.
func _cursor_row() -> int:
	return _member_cursor


func _on_cancel_row() -> bool:
	return _switch_from < 0 and _member_cursor >= _party_size()


func _confirm() -> void:
	## `PartyMenuSelect` answers CANCEL with the same carry a B press sets, so
	## the row and the button are one path.
	if _on_cancel_row() and not _submenu_open:
		_cancel()
		return
	## `SelectMonFromParty` returns the moment `PartyMenuSelect` does: there is
	## no submenu behind this list.
	if _selecting:
		selection_made.emit(_member_cursor)
		return
	if _switch_from >= 0:
		_finish_switch()
		return
	if _heal_user >= 0:
		_choose_heal_target()
		return
	if not _submenu_open:
		_open_submenu()
		return
	if _submenu_cursor < 0 or _submenu_cursor >= _submenu_items.size():
		return
	var entry: Dictionary = _submenu_items[_submenu_cursor]
	if StringName(entry.get("option", &"")) == OPTION_CANCEL:
		_close_submenu()
		return
	_confirm_submenu(entry)


func _confirm_submenu(entry: Dictionary) -> void:
	match StringName(entry.get("kind", &"")):
		&"field_move":
			var move: int = int(entry.get("move", 0))
			if move in HEAL_TRANSFER_MOVES:
				_open_heal_target(move)
				return
			action_chosen.emit({
				"kind": &"field_move",
				"move": move,
				"slot": _member_cursor,
				"name": _display_name(_save.party[_member_cursor]),
			})
		&"mon_item":
			action_chosen.emit({
				"kind": &"mon_item",
				"option": StringName(entry.get("option", &"")),
				"slot": _member_cursor,
				"name": _display_name(_save.party[_member_cursor]),
			})
		&"mon_mail":
			## `.done` answers 3, which `.choosemenu` takes back to the list.
			if StringName(entry.get("option", &"")) == OPTION_MAIL_QUIT:
				_open_submenu()
				return
			action_chosen.emit({
				"kind": &"mon_mail",
				"option": StringName(entry.get("option", &"")),
				"slot": _member_cursor,
				"name": _display_name(_save.party[_member_cursor]),
			})
		&"mod_party_action":
			## The handler is the mod's, and the slot is the only thing it is
			## told: the menu closes behind it the way a field move's does.
			(entry["handler"] as Callable).call(_member_cursor + 1)
			_close_submenu()
			action_chosen.emit({
				"kind": &"mod_party_action",
				"mod": StringName(entry.get("mod", &"")),
				"slot": _member_cursor,
				"name": _display_name(_save.party[_member_cursor]),
			})
		&"option":
			_confirm_option(StringName(entry.get("option", &"")))


func _confirm_option(option: StringName) -> void:
	match option:
		OPTION_ITEM:
			_open_item_menu()
		OPTION_MAIL:
			_open_mail_menu()
		OPTION_SWITCH:
			_begin_switch()
		OPTION_STATS:
			_open_stats()
		OPTION_MOVE:
			_open_moves()


## `MonMenu_Stats` reaches `OpenPartyStats`, which is `StatsScreenInit` over the
## whole party menu. It answers 0, which is `.choosemenu`: the list comes back
## with the submenu shut and the prompt reset, on whichever row the stats screen
## was left on.
func _open_stats() -> void:
	if _data == null or _save == null or _member_cursor >= _party_size():
		return
	_stats = Gen2MonStatsScreen.create(_data, _save.party, _member_cursor)
	_stats.closed.connect(_close_stats)
	_stats.cry_requested.connect(cry_requested.emit)
	## `StatsScreenInit` clears the tilemap before it draws, so the submenu is
	## gone rather than standing behind the screen.
	_submenu_open = false
	_item_menu_open = false
	_stats.announce()
	_refresh()


## `MonMenu_Move` reaches `ManagePokemonMoves`, which answers 0 for the same
## `.choosemenu` STATS answers with, and refuses an egg outright.
func _open_moves() -> void:
	if _data == null or _save == null or _member_cursor >= _party_size():
		return
	var mon: Gen2SaveMon = _save.party[_member_cursor]
	if mon == null or mon.is_egg:
		_close_submenu()
		return
	_moves = Gen2MoveScreen.create(_data, _save.party, _member_cursor)
	_moves.closed.connect(_close_moves)
	_moves.sfx_requested.connect(sfx_requested.emit)
	## `SetUpMoveScreenBG`'s own `ClearTilemap`, as above.
	_submenu_open = false
	_item_menu_open = false
	_refresh()


func _close_moves() -> void:
	if _moves == null:
		return
	_member_cursor = clampi(_moves.cursor(), 0, _row_count() - 1)
	_moves = null
	_close_submenu()


func _close_stats() -> void:
	if _stats == null:
		return
	_member_cursor = clampi(_stats.cursor(), 0, _row_count() - 1)
	_stats = null
	_close_submenu()


func _cancel() -> void:
	## `PartyMenuSelect`'s carry, which is the same answer the CANCEL row gives.
	if _selecting:
		selection_made.emit(-1)
		return
	## `SwitchPartyMons`' `bit B_PAD_B` reaches `.DontSwitch`, which is
	## `CancelPokemonAction`: the move is given up and the plain list comes back.
	if _switch_from >= 0:
		_switch_from = -1
		_close_submenu()
		return
	## `.SelectMilkDrinkRecipient`'s own `.set_carry`: a B press over the
	## recipient list gives up on the move and leaves the party menu standing.
	if _heal_user >= 0:
		_heal_user = -1
		_heal_move = 0
		_open_submenu()
		return
	## `GiveTakePartyMonItem`'s own `VerticalMenu` carry is `.cancel`, which
	## returns to the submenu it opened over rather than closing the party menu.
	if _item_menu_open:
		_open_submenu()
		return
	if _submenu_open:
		_close_submenu()
		return
	close_embedded()


## `MonMenu_Softboiled_MilkDrink`'s own gate and then
## `.SelectMilkDrinkRecipient`: a user with a fifth of its health or less says so
## and stays on the submenu, and anything else opens the recipient list, which is
## the party list again with the submenu closed.
func _open_heal_target(move: int) -> void:
	var user: Gen2SaveMon = _save.party[_member_cursor]
	var fifth: int = Gen2WorldPartyHost.one_fifth_max_hp(_data, user)
	if fifth <= 0 or user.hp <= fifth:
		## `.NotEnoughHP` prints and then returns 3, which is `.menu`: the
		## submenu does not survive the refusal.
		_say(MESSAGE_NOT_ENOUGH_HP)
		_close_submenu()
		return
	_heal_user = _member_cursor
	_heal_move = move
	_submenu_open = false
	_item_menu_open = false
	_submenu_items = []
	_refresh()


## One press over the recipient list. The three refusals stay on the list the way
## `.cant_use` loops back to it; anything else is the caller's to apply, since
## the health it moves belongs to a save the world owns.
func _choose_heal_target() -> void:
	if _member_cursor == _heal_user:
		_say(MESSAGE_NO_EFFECT)
		return
	var target: Gen2SaveMon = _save.party[_member_cursor]
	var target_max: int = Gen2SaveBattleAdapter.to_battle_mon(_data, target).max_hp() \
		if not target.is_egg else 0
	if target.is_egg or target.hp <= 0 or target.hp >= target_max:
		_say(MESSAGE_NO_EFFECT)
		return
	var action: Dictionary = {
		"kind": &"heal_transfer",
		"move": _heal_move,
		"slot": _heal_user,
		"target_slot": _member_cursor,
		"name": _display_name(_save.party[_heal_user]),
		"target_name": _display_name(target),
	}
	_heal_user = -1
	_heal_move = 0
	action_chosen.emit(action)


## `SwitchPartyMons`: a party of one has nothing to trade with and falls straight
## into `.DontSwitch`, and anything else holds this member and reopens the list
## without its CANCEL row.
func _begin_switch() -> void:
	if _party_size() < 2:
		_close_submenu()
		return
	_switch_from = _member_cursor
	_submenu_open = false
	_item_menu_open = false
	_submenu_items = []
	_refresh()


## `_SwitchPartyMons`: the two members trade places whole, and the same row twice
## is its own `jr z, .skip`. The list comes back with CANCEL either way.
func _finish_switch() -> void:
	var from: int = _switch_from
	_switch_from = -1
	if from != _member_cursor and from >= 0 and from < _party_size() \
		and _member_cursor < _party_size():
		var held: Gen2SaveMon = _save.party[from]
		_save.party[from] = _save.party[_member_cursor]
		_save.party[_member_cursor] = held
		## `.ClearSprite` runs once per row and ends on `WaitPlaySFX`, so the
		## effect is asked for twice and the second waits the first out.
		sfx_requested.emit(SFX_SWITCH_POKEMON, true)
		sfx_requested.emit(SFX_SWITCH_POKEMON, true)
	_member_cursor = clampi(_member_cursor, 0, _row_count() - 1)
	## The icons are respawned rather than stepped: `LoadPartyMenuGFX` and
	## `InitPartyMenuGFX` run again behind the reopened list.
	if _page != null:
		_page.reset(_rows())
	_refresh()


func _open_item_menu() -> void:
	_submenu_items = item_menu_items()
	_submenu_cursor = 0
	_item_menu_open = true
	_fixed_menu_box = ITEM_MENU_BOX
	_refresh()


func _open_mail_menu() -> void:
	_submenu_items = mail_menu_items()
	_submenu_cursor = 0
	_item_menu_open = true
	_fixed_menu_box = MAIL_MENU_BOX
	_refresh()


func _open_submenu() -> void:
	if _member_cursor < 0 or _member_cursor >= _party_size():
		return
	_submenu_items = submenu_items_for(_data, _save.party[_member_cursor], _member_cursor + 1)
	_submenu_cursor = 0
	_submenu_open = not _submenu_items.is_empty()
	_item_menu_open = false
	_refresh()


func _close_submenu() -> void:
	_submenu_open = false
	_item_menu_open = false
	_submenu_items = []
	_submenu_cursor = 0
	_refresh()


func submenu_snapshot() -> Dictionary:
	return {
		"open": _submenu_open,
		"item_menu": _item_menu_open,
		"cursor": _submenu_cursor,
		"member": _member_cursor,
		"on_cancel": _on_cancel_row(),
		"switch_from": _switch_from,
		"message": _message,
		"items": _submenu_items.duplicate(true),
	}


func _render_submenu() -> void:
	if _submenu == null:
		return
	Gen2LauncherUI.clear(_submenu)
	_submenu.visible = _submenu_open
	if not _submenu_open:
		return
	for index: int in _submenu_items.size():
		var entry: Dictionary = _submenu_items[index]
		var label := Label.new()
		label.text = ("> " if index == _submenu_cursor else "  ") \
			+ String(entry.get("label", ""))
		label.add_theme_color_override(
			"font_color",
			_palette.accent if index == _submenu_cursor else _palette.text
		)
		label.add_theme_font_size_override("font_size", Gen2LauncherTheme.FONT_BODY)
		_submenu.add_child(label)


func _resolve_data() -> GameData:
	return Gen2GameRuntime.data_or_any()


func _resolve_save() -> Gen2SaveData:
	return Gen2GameRuntime.selected_save_or_null() if _data != null else null


## `StartMenu_Pokemon`'s screen: the party menu owns all 160x144 of it, so the
## view is laid out in hardware pixels rather than in the window ones of
## whatever parent added this one. The screen it goes in is the one already at
## the window ([method Gen2Screen.host_for]), so the list lands exactly on the
## rectangle the map behind it is drawn in.
func _build_hardware_ui() -> void:
	_hardware = Gen2Screen.host_for(self, _hardware)
	if _hardware == null:
		return
	_view = TextureRect.new()
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_view.size = Vector2(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hardware.display(_view)


## Draws the party as a readout rather than as a menu: no cursor, no CANCEL row
## and an empty bottom box.
##
## For a display that shows the party without being able to choose from it. The
## three are one switch rather than three because they are one fact: an arrow, a
## way out and a question are all furniture for a press that cannot happen here.
func set_read_only(on: bool) -> void:
	if _read_only == on:
		return
	_read_only = on
	if is_inside_tree():
		_render_hardware()


## The screen the opener wants this drawn in, handed over before it is added to
## the tree. Without one the view goes in whichever screen this ends up inside.
func set_screen(screen: Gen2Screen) -> void:
	_hardware = screen


## The view lives in a screen this node may not own, so it goes by hand.
func _exit_tree() -> void:
	if _view != null:
		Gen2Screen.drop_on_exit(_view)
		_view = null


## One hardware frame of `PlaySpriteAnimations` over the icons. `FreezeMonIcons`
## is what `MonSubmenu` calls before it draws its box, so a menu that is up
## stops them where they stand.
func _process(delta: float) -> void:
	if _view == null or _page == null:
		return
	var frames: int = _frame_clock.tick(delta)
	if frames == 0 or _submenu_open or _item_menu_open:
		return
	## `StatsScreen_WaitAnim` is the stats screen's own loop, and the party
	## icons behind it are not being stepped while it is up.
	if _stats != null:
		for _pic_frame: int in frames:
			_stats.advance_animation()
		_render_hardware()
		return
	if _moves != null:
		for _icon_frame: int in frames:
			_moves_page_advance()
		_render_hardware()
		return
	var rows: Array = _rows()
	for _frame: int in frames:
		_page.advance(rows, _cursor_row())
	_render_hardware()


func _moves_page_advance() -> void:
	if _moves_page != null:
		_moves_page.advance()


## `WritePartyMenuTilemap`'s rows, in [Gen2BattleSwitchMenu]'s own shape plus the
## `egg` [Gen2PartyMenuPage] needs, which a battle party never carries.
## `PartyMenuQualityPointers`' `.Gender`, both `SelectTradeOrDayCareMon` callers.
func _gender_column() -> bool:
	return _selecting and _select_action == ACTION_GIVE_MON


func _rows() -> Array:
	var out: Array = []
	if _save == null:
		return out
	for index: int in _save.party.size():
		var mon: Gen2SaveMon = _save.party[index]
		if mon == null:
			continue
		out.append({
			"index": index,
			"species": mon.species,
			"item": mon.item,
			"name": _display_name(mon),
			"level": mon.level,
			"hp": mon.hp,
			"max_hp": 0 if mon.is_egg else _max_hp(mon),
			"status": mon.status,
			"fainted": not mon.is_egg and mon.hp <= 0,
			"egg": mon.is_egg,
			"quality": Gen2PartyMenuPage.gender_quality(
				Gen2BattleMon.gender_for(_data, mon.species, mon.dvs)
			),
		})
	return out


## `PlacePartyMenuText`'s string: a refusal that is still standing, then the
## recipient list's own action text, then `StartMenu_Pokemon`'s.
func _prompt() -> String:
	if not _message.is_empty():
		return _message
	if _selecting:
		return _select_prompt
	if _switch_from >= 0:
		return PROMPT_MOVE_TO_WHERE
	return PROMPT_USE_ON_WHICH if _heal_user >= 0 else PROMPT_CHOOSE


func _render_hardware() -> void:
	if _view == null or _data == null:
		return
	if _stats != null:
		_render_stats()
		return
	if _moves != null:
		_render_moves()
		return
	if _page == null:
		_page = Gen2PartyMenuPage.from_data(_data)
	if _menu_page == null:
		_menu_page = Gen2MenuPage.from_data(_data)
	if _page == null:
		return
	var rows: Array = _rows()
	var image: Image = _page.render(
		rows,
		-1 if _read_only else _cursor_row(),
		"" if _read_only else _prompt(),
		_switch_from < 0 and not _read_only,
		_switch_from,
		_gender_column(),
	)
	if image == null:
		return
	if _menu_page != null and (_submenu_open or _item_menu_open):
		var box: Gen2MenuBox = _submenu_box()
		var menu: Image = _menu_page.render(box, _submenu_labels(), _submenu_cursor)
		image.blend_rect(
			menu, Rect2i(Vector2i.ZERO, menu.get_size()),
			box.border_position() * Gen2Font.TILE
		)
	Gen2PicImage.show(_view, image)


## `StatsScreenInit`'s own screen, over the party menu rather than beside it. The
## front pic has a palette of its own, so it is composed on top the way a party
## icon is rather than written into the page's index buffer.
func _render_stats() -> void:
	if _stats_page == null:
		_stats_page = Gen2StatsScreenPage.from_data(_data)
	if _stats_page == null:
		return
	var snapshot: Dictionary = _stats.snapshot()
	var image: Image = _stats_page.render(snapshot, _data)
	_blend_stats_pic(image, snapshot)
	Gen2PicImage.show(_view, image)


## `MoveScreenLoop`'s own screen, which steps its one mon icon per frame the way
## the party list steps six.
func _render_moves() -> void:
	if _moves_page == null:
		_moves_page = Gen2MoveScreenPage.from_data(_data)
	if _moves_page == null:
		return
	Gen2PicImage.show(_view, _moves_page.render(_moves.snapshot(), _data))


## `PrepMonFrontpic`'s own seven-tile cell on `hlcoord 0, 0`, which mirrors the
## picture and bottom-aligns a smaller one against the far column.
func _blend_stats_pic(image: Image, snapshot: Dictionary) -> void:
	var species: int = int(snapshot.get("species", 0))
	if species <= 0:
		return
	var art: Image = Gen2StatsScreenPage.pic_image(_data, snapshot, _stats)
	if art == null:
		return
	image.blit_rect(art, Rect2i(Vector2i.ZERO, art.get_size()), Vector2i(
		Gen2StatsScreenPage.pic_position()
	) + Gen2StatsScreenPage.pic_origin(art.get_size(), snapshot))


## `.GetTopCoord` for the mon's own submenu, and the fixed box whichever of
## `GiveTakeItemMenuData` and `MonMailAction.MenuHeader` is open over it.
func _submenu_box() -> Gen2MenuBox:
	if _item_menu_open:
		return Gen2MenuBox.from_coords(
			_fixed_menu_box.position.x, _fixed_menu_box.position.y,
			_fixed_menu_box.end.x, _fixed_menu_box.end.y, Gen2MenuBox.STATICMENU_CURSOR
		)
	return mon_menu_box(_submenu_items.size())


## `.GetTopCoord`'s own box for [param count] rows, which is where the cartridge
## prints the field-move names `MonMenuOptions` carries. Static because the start
## menu's MOVES row draws the same names and must not print them in a narrower
## box: WATERFALL is nine characters and the source list's words are eight.
static func mon_menu_box(count: int) -> Gen2MenuBox:
	return Gen2MenuBox.from_coords(
		SUBMENU_LEFT, SUBMENU_BOTTOM + 1 - 2 * (maxi(count, 0) + 1),
		SUBMENU_RIGHT, SUBMENU_BOTTOM, Gen2MenuBox.STATICMENU_CURSOR
	)


## `PopulateMonMenu` places the option strings themselves.
func _submenu_labels() -> Array:
	var out: Array = []
	for entry: Variant in _submenu_items:
		out.append(String((entry as Dictionary).get("label", "")))
	return out


func _build_ui() -> void:
	if _embedded:
		_build_hardware_ui()
		return
	_palette = Gen2LauncherTheme.active()
	theme = _palette.control_theme()
	_shell = Gen2LauncherShell.create(_palette)
	add_child(_shell)

	var back: Gen2LauncherButton = Gen2LauncherButton.create(
		_palette, "Save data", Gen2LauncherButton.Variant.QUIET, &"back"
	)
	back.pressed.connect(_back)
	_shell.add_action(back)

	var page: VBoxContainer = Gen2LauncherUI.column(Gen2LauncherUI.GAP_LG)
	var head: HBoxContainer = Gen2LauncherUI.row(Gen2LauncherUI.GAP_MD)
	page.add_child(head)
	var heading: VBoxContainer = Gen2LauncherUI.column(Gen2LauncherUI.GAP_XS)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(heading)
	heading.add_child(Gen2LauncherUI.title(
		_palette, "Party", Gen2LauncherTheme.FONT_DISPLAY
	))
	heading.add_child(Gen2LauncherUI.muted(
		_palette, "Player party and persistent condition"
	))
	_player_label = Gen2LauncherUI.caption(_palette, "")
	_player_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_player_label)

	var scroll: Gen2LauncherScroll = Gen2LauncherScroll.create()
	page.add_child(scroll)
	var body: VBoxContainer = Gen2LauncherUI.column(Gen2LauncherUI.GAP_MD)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.content().add_child(body)
	_cards = Gen2LauncherUI.column(Gen2LauncherUI.GAP_SM)
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_cards)
	_submenu = Gen2LauncherUI.column(Gen2LauncherUI.GAP_XS)
	_submenu.visible = false
	body.add_child(_submenu)

	## The three things this view offers that no cartridge screen does. A
	## wrapping row, so a phone held upright drops them onto their own lines
	## rather than pushing the page off its own width.
	var actions: HFlowContainer = Gen2LauncherUI.actions()
	body.add_child(actions)
	_storage_button = Gen2LauncherButton.create(
		_palette, "PC storage", Gen2LauncherButton.Variant.NEUTRAL, &"folder"
	)
	_storage_button.pressed.connect(_open_storage)
	actions.add_child(_storage_button)
	_battle_button = Gen2LauncherButton.create(
		_palette, "Development battle", Gen2LauncherButton.Variant.PRIMARY, &"play"
	)
	_battle_button.pressed.connect(_start_battle)
	actions.add_child(_battle_button)

	_status = Gen2LauncherUI.muted(_palette, "")
	body.add_child(_status)
	_shell.add_page(&"party", "Party", &"save", page)


## A caller's own refusal in this list's box, for a selection the list itself
## cannot judge. `_PlayerMailBoxMenu`'s `.AttachMail` is the shape: it prints
## `.MailEggText` or `.MailAlreadyHoldingItemText` and jumps back to
## `.try_again`, which is this list still open behind the box.
func say(message: String) -> void:
	_say(message)


## A refusal, in whichever box this view has: the menu's own bottom one when it
## is the cartridge's screen, and the panel's status line when it is not.
func _say(message: String) -> void:
	if _embedded:
		_message = message
		_render_hardware()
		return
	if _status == null:
		return
	_status.text = message
	_status.add_theme_color_override("font_color", _palette.muted)


func _refresh() -> void:
	if _embedded:
		_render_hardware()
		return
	if _cards == null:
		return
	Gen2LauncherUI.clear(_cards)
	if _player_label != null:
		_player_label.text = "Player: %s" % (_save.player_name if _save != null else "Unavailable")
	if _data == null or _save == null:
		_status.text = "No validated save selected."
		_status.add_theme_color_override("font_color", _palette.error)
		return
	for index: int in Gen2SaveData.MAX_PARTY:
		_cards.add_child(_member_card(index))
	_render_submenu()
	_status.text = "Slot %d" % (_save.slot + 1)
	_status.add_theme_color_override("font_color", _palette.success)


func _member_card(index: int) -> Control:
	var selected: bool = index == _member_cursor and index < _party_size()
	var card: Gen2LauncherCard = (
		Gen2LauncherCard.selected(_palette, Gen2LauncherTheme.RADIUS_MD, 16) if selected
		else Gen2LauncherCard.create(_palette, Gen2LauncherTheme.RADIUS_MD, 16)
	)
	var content: HBoxContainer = Gen2LauncherUI.row(Gen2LauncherUI.GAP_MD)
	card.add_child(content)
	var number: Label = Gen2LauncherUI.title(_palette, "%d" % (index + 1))
	number.add_theme_color_override("font_color", _palette.accent)
	number.custom_minimum_size = Vector2(24, 0)
	number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_child(number)
	if _save == null or index >= _save.party.size():
		content.add_child(Gen2LauncherUI.tag(_palette, "Empty"))
		return card
	var mon: Gen2SaveMon = _save.party[index]
	var summary: VBoxContainer = Gen2LauncherUI.column(Gen2LauncherUI.GAP_XS)
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(summary)
	summary.add_child(Gen2LauncherUI.title(_palette, _display_name(mon)))
	## Level and HP wrap onto their own line on a narrow page rather than
	## widening the card past the window.
	var facts: HFlowContainer = Gen2LauncherUI.actions(Gen2LauncherUI.GAP_MD)
	summary.add_child(facts)
	facts.add_child(Gen2LauncherUI.tag(_palette, _species_name(mon.species)))
	facts.add_child(Gen2LauncherUI.tag(_palette, "Lv.%d" % mon.level))
	facts.add_child(Gen2LauncherUI.tag(_palette, "HP %d/%d" % [mon.hp, _max_hp(mon)]))
	var condition: Label = Gen2LauncherUI.caption(_palette, _status_name(mon.status))
	condition.add_theme_color_override("font_color", _status_color(mon.status))
	facts.add_child(condition)
	return card


func _member_snapshot(index: int, mon: Gen2SaveMon) -> Dictionary:
	return {
		"empty": false,
		"index": index,
		"name": _display_name(mon),
		"species": mon.species,
		"level": mon.level,
		"hp": mon.hp,
		"max_hp": _max_hp(mon),
		"status": _status_name(mon.status),
	}


func _max_hp(mon: Gen2SaveMon) -> int:
	var battle_mon: Gen2BattleMon = Gen2SaveBattleAdapter.to_battle_mon(_data, mon)
	return battle_mon.max_hp() if battle_mon != null else 0


func _display_name(mon: Gen2SaveMon) -> String:
	return mon.nickname if not mon.nickname.is_empty() else _species_name(mon.species)


func _species_name(species: int) -> String:
	return String(_data.species(species).get("name", "UNKNOWN")) if _data != null else "UNKNOWN"


func _status_name(status: int) -> String:
	var status_name: StringName = Gen2Status.name_of(status)
	return "OK" if status_name.is_empty() else String(status_name).to_upper()


func _status_color(status: int) -> Color:
	return _palette.success if Gen2Status.name_of(status).is_empty() else _palette.warning


func _start_battle() -> void:
	if _data == null or _save == null:
		return
	if not _select_slot():
		return
	get_tree().change_scene_to_file.call_deferred("res://game/battle/battle_screen.tscn")


func _back() -> void:
	if _embedded:
		close_embedded()
		return
	get_tree().change_scene_to_file.call_deferred("res://game/save/save_screen.tscn")


func close_embedded() -> void:
	if not _embedded:
		return
	closed.emit({"ok": true})


func _open_storage() -> void:
	if _data == null or _save == null:
		_status.text = "No validated save selected."
		_status.add_theme_color_override("font_color", _palette.error)
		return
	if not _select_slot():
		return
	get_tree().change_scene_to_file.call_deferred("res://game/save/box_screen.tscn")


## Hands the slot to the runtime before changing scene, so the screen that opens
## next reads the same save this one is showing. False with the refusal already
## on screen when there is no runtime or the cartridge is not in the registry.
func _select_slot() -> bool:
	var runtime: Gen2GameRuntime = Gen2GameRuntime.instance()
	if runtime != null and runtime.select_save_slot(_data.id, _save.slot):
		return true
	_status.text = "The selected cartridge is not in the registry."
	_status.add_theme_color_override("font_color", _palette.error)
	return false
