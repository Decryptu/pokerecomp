class_name Gen2StartMenuScreen
extends Control

## The overworld pause menu (engine/menus/start_menu.asm). The list, `_Option`,
## `SaveMenu` and every box the pack opens are the cartridge's own screens through
## [Gen2StartMenuPage] and [Gen2PackPage], drawn into whichever [Gen2Screen] the
## host hands over; a caller handing over none keeps the panel below. Pokedex,
## Pokemon and Pokegear are the world's, so this only reports the choice.

## An available entry this screen does not own (Pokedex, Pokemon, Pokegear,
## Player); the caller opens it. [param id] is the registering mod's where the
## row is a mod's, and empty for every cartridge row.
signal action_chosen(kind: StringName, id: StringName)
## Emitted on Exit or cancel from the top-level list.
signal closed
## `.Field`'s PACKSTATE_QUITRUNSCRIPT: an ITEMMENU_CLOSE item whose effect
## succeeded, so the pack quits and the overworld runs what it queued. The
## payload is the resolved effect: only the world's host can cast a rod.
signal field_item_used(request: Dictionary)

## `EvoStoneEffect`'s own `EvolvePokemon`: the pack has already written the party
## row, and the animation belongs to the screen the overworld hosts. [param after]
## is this menu's own continuation, run when that screen closes.
signal evolution_animation_requested(plan: Dictionary, after: Callable)
## `PlaySFX`, which this screen has no driver of its own for: the world that
## hosts it owns the player. `SFX_SAVE` is the only one it asks for.
signal sfx_requested(sfx: int, waited: bool)
## A field move chosen off the MOVES row, in the same shape a party member's own
## submenu emits: the world runs the one and the other through one path.
signal field_move_chosen(action: Dictionary)
## The reset chord's question was answered YES. Only the screen hosting this one
## can restart the game, the same way it is the one that opens the launcher.
signal soft_reset_confirmed

enum Mode {
	LIST, PACK, PACK_ITEM, PACK_TEACH, PACK_TARGET,
	PACK_FORGET_ASK, PACK_FORGET, PACK_STOP_LEARNING, PACK_PP_MOVE,
	PACK_TOSS_QUANTITY, PACK_TOSS_CONFIRM, PACK_GIVE_SWAP,
	PACK_RESULT, SAVE_ASK, SAVE_OVERWRITE, SAVE_SAVING, SAVE_SAVED,
	SAVE_FAILED, QUIT_ASK, LAUNCHER_ASK, RESET_ASK, OPTIONS, MODS, MOD_OPTIONS,
	FIELD_MOVES,
}

## The prompt's step as one of this screen's modes, so its box is drawn the way
## every other question here is.
const SAVE_PROMPT_MODES: Dictionary = {
	Gen2SavePrompt.Step.ASK: Mode.SAVE_ASK,
	Gen2SavePrompt.Step.OVERWRITE: Mode.SAVE_OVERWRITE,
	Gen2SavePrompt.Step.SAVING: Mode.SAVE_SAVING,
	Gen2SavePrompt.Step.SAVED: Mode.SAVE_SAVED,
	Gen2SavePrompt.Step.FAILED: Mode.SAVE_FAILED,
}


## The two-row boxes, by the cursor each toggles and the method that repaints it.
const TOGGLE_MODES: Dictionary = {
	Mode.PACK_TEACH: [&"_teach_cursor", &"_render_teach"],
	Mode.PACK_FORGET_ASK: [&"_forget_confirm_cursor", &"_render_forget_ask"],
	Mode.PACK_STOP_LEARNING: [&"_forget_confirm_cursor", &"_render_stop_learning"],
	Mode.PACK_TOSS_CONFIRM: [&"_toss_confirm_cursor", &"_render_toss_confirm"],
	Mode.PACK_GIVE_SWAP: [&"_swap_cursor", &"_render_give_swap"],
	Mode.SAVE_ASK: [&"_save_cursor", &"_render_save"],
	Mode.SAVE_OVERWRITE: [&"_save_cursor", &"_render_save"],
	Mode.QUIT_ASK: [&"_save_cursor", &"_render_save"],
	Mode.LAUNCHER_ASK: [&"_save_cursor", &"_render_save"],
	Mode.RESET_ASK: [&"_save_cursor", &"_render_save"],
}

## Every mode whose A press is one call. A ladder row is read with left and right,
## so A does nothing on one, the way it does on the cartridge's own value rows; a
## mod's button row is the exception, where pressing it is the whole setting.
const CONFIRM_HANDLERS: Dictionary = {
	Mode.LIST: &"_confirm_list",
	Mode.PACK_ITEM: &"_confirm_item_action",
	Mode.PACK_TEACH: &"_confirm_teach",
	Mode.PACK_FORGET_ASK: &"_confirm_forget_ask",
	Mode.PACK_FORGET: &"_confirm_forget",
	Mode.PACK_PP_MOVE: &"_confirm_pp_move",
	Mode.PACK_STOP_LEARNING: &"_confirm_stop_learning",
	Mode.PACK_TOSS_CONFIRM: &"_confirm_toss",
	Mode.PACK_GIVE_SWAP: &"_confirm_give_swap",
	Mode.SAVE_ASK: &"_confirm_save",
	Mode.SAVE_OVERWRITE: &"_confirm_save",
	Mode.SAVE_SAVING: &"_confirm_save",
	Mode.SAVE_SAVED: &"_confirm_save",
	Mode.SAVE_FAILED: &"_confirm_save",
	Mode.QUIT_ASK: &"_confirm_save",
	Mode.LAUNCHER_ASK: &"_confirm_save",
	Mode.RESET_ASK: &"_confirm_save",
	Mode.MOD_OPTIONS: &"_press_mod_option",
	Mode.FIELD_MOVES: &"_confirm_field_move",
}

## `SaveMenu`'s question. The words and the frames are [Gen2SavePrompt]'s: every
## save runs one routine, and only the question in front of it differs.
const SAVE_ASK_LINES: Array[String] = Gen2SavePrompt.ASK_LINES
## `_StartMenuContestEndText`, which `StartMenu_Quit` asks over the same
## `YesNoMenuHeader` box the save question uses. Authored here beside the save
## texts for the same reason: no importer reads either.
const QUIT_ASK_LINES: Array[String] = [
	"Would you like to", "end the Contest?",
]
## This port's own words, over the same `YesNoBox` the two above use. The
## launcher is where a cartridge goes back to here, and leaving takes whatever
## has not been saved with it, which is the only reason the row asks at all.
const LAUNCHER_ASK_LINES: Array[String] = [
	"Would you like to", "quit this game?",
]
## The reset chord's own question, asked once ever: see
## [signal Gen2InputRuntime.reset_chord_pressed]. Three lines, so the first two
## are prompted past before the box appears, the way the overwrite question is.
const RESET_ASK_LINES: Array[String] = [
	"You pressed the", "RESET buttons.", "Reset the game?",
]
## `RestoreThePPOfWhichMoveText` and `PPRestoredText`, `text_far` stubs no script
## reaches, so they are this screen's the way the questions above are. The third
## is this port's own words: the save model carries no PP UP ceiling.
const RESTORE_PP_WHICH_MOVE: String = "Restore the PP of\nwhich move?"
const PP_RESTORED: String = "PP was restored."
const PP_UP_UNSUPPORTED: String = "PP UP has no effect\nin this port yet."

const SAVE_SAVING_FRAMES: int = Gen2SavePrompt.SAVING_FRAMES
const SAVE_WRITE_FRAMES: int = Gen2SavePrompt.WRITE_FRAMES
const SAVE_DONE_FRAMES: int = Gen2SavePrompt.DONE_FRAMES

## `SwitchItemsInBag`' own two, both hexadecimal the way the constants file
## counts: `.place_insert` asks for SFX_SWITCH_POKEMON twice through
## `WaitPlaySFX`, and a pocket cycle asks for SFX_SWITCH_POCKETS.
const SFX_SWITCH_POKEMON: int = 0x20
const SFX_SWITCH_POCKETS: int = 0x62

## The pack's five imported texts, by the key `GameData.menu_text` holds each
## under. `UseItem`'s two refusals and `TossMenu`'s three; "(S)" is three literal
## characters in the charmap rather than a plural rule, so the cartridge really
## does say "POTION(S)".
const TEXT_OAK: String = "oak_no_time"
const TEXT_NO_MON: String = "no_mon"
const TEXT_TOSS_ASK: String = "toss_ask"
const TEXT_TOSS_ASK_QUANTITY: String = "toss_ask_quantity"
const TEXT_TOSS_THREW: String = "toss_threw"

## What each reads on a cache imported before the texts were, which is the only
## way any of these is ever seen. Verbatim from data/text/common_2.asm.
const TEXT_FALLBACKS: Dictionary = {
	TEXT_OAK: "OAK: <PLAYER>!\nThis isn't the\ntime to use that!",
	TEXT_NO_MON: "You don't have a\nPOKéMON!",
	TEXT_TOSS_ASK: "Throw away how\nmany?",
	TEXT_TOSS_ASK_QUANTITY: "Throw away <NUM_>\n<RAM_>(S)?",
	TEXT_TOSS_THREW: "Threw away\n<RAM_>(S).",
}


## The pack's submenus, `MENU_BACKUP_TILES` boxes over the pack's own screen.
## `MenuHeader_UsableKeyItem` and its five siblings differ only in where the box
## starts: `menu_coords 13, y, SCREEN_WIDTH - 1, TEXTBOX_Y - 1`, y being
## `TEXTBOX_Y - 1 - 2 * items` so the rows end on the text box.
const ITEM_MENU_LEFT: int = 13
const ITEM_MENU_RIGHT: int = 19
const ITEM_MENU_BOTTOM: int = 11
## [method Gen2MenuBox.yes_no]'s box: left 14, right 19, top 7, bottom 11.
const YES_NO_AT: Vector2i = Vector2i(14, 7)
const YES_NO_SPAN: Vector2i = Vector2i(5, 4)
## `TossItem_MenuHeader`: `menu_coords 15, 9, SCREEN_WIDTH - 1, TEXTBOX_Y - 1`.
const TOSS_QUANTITY_AT: Vector2i = Vector2i(15, 9)
const TOSS_QUANTITY_TO: Vector2i = Vector2i(19, 11)
## `STATICMENU_CURSOR | STATICMENU_NO_TOP_SPACING`, which every one of them sets.
const SUBMENU_FLAGS: int = (
	Gen2MenuBox.STATICMENU_CURSOR | Gen2MenuBox.STATICMENU_NO_TOP_SPACING
)
## `YesNoMenuHeader.MenuData`'s own two strings.
const YES_NO_OPTIONS: Array[String] = ["YES", "NO"]

var _world: Gen2WorldAPI = null
var _data: GameData = null
var _save_action: Callable = Callable()
var _mode: Mode = Mode.LIST
var _menu: Gen2WorldStartMenu = null

var _pack_pockets: Array = []
var _pack_pocket_index: int = 0
var _pack_cursor: int = 0
var _pack_save: Gen2SaveData = null
var _pack_persist: bool = true
var _item_actions: Array = []
var _item_cursor: int = 0
var _target_cursor: int = 0
var _pack_result: String = ""
## `wItemsPocketScrollPosition` and its three siblings: which entry the visible
## five start at. Held per pocket, the way the source holds one variable each.
var _pack_scroll: Array[int] = [0, 0, 0, 0]
## Which row of the start menu's own list is at the top of the box. See
## [method _scroll_list_to_cursor].
var _list_scroll: int = 0
var _pack_cursors: Array[int] = [0, 0, 0, 0]
## `wSwitchItem` less one: the row SELECT marked in the pocket the pack is on,
## or -1 for `SwitchItemsInBag`' own zero.
var _pack_switch: int = -1
var _pack_page: Gen2PackPage = null
var _pack_result_ok: bool = false
## `PrintText` waits per page, so a result longer than the box's two rows is
## pressed through rather than cut off at the frame.
var _pack_result_pages: Array = []
var _pack_result_page: int = 0
## What runs when the last page of the box is pressed past, instead of the pack
## coming back: the next move an evolution has to offer.
var _pack_result_next: Callable = Callable()
## AskTeachTMHM's resolved prompt, held while its yes/no is on screen, and
## whether the party list that follows is ChooseMonToLearnTMHM's rather than
## `.Party`'s.
var _teach_prompt: Dictionary = {}
var _teach_cursor: int = 0
var _teaching: bool = false
## `SelectQuantityToToss`'s dial and `YesNoBox`'s cursor, held while TOSS runs.
var _toss_prompt: Gen2WorldQuantityPrompt = null
var _toss_confirm_cursor: int = 0

## GIVE's two directions. `_giving` is the pack's own: the item is chosen and the
## party list picks who holds it. `_give_target` is `GiveTakePartyMonItem`'s,
## where the Pokemon is already chosen and the pack list is `DepositSellPack`,
## which acts on the item rather than opening a submenu over it.
var _giving: bool = false
var _give_target: int = -1
## `PokemonAskSwapItemText`'s yes/no, who it is about and the question itself,
## which stands in the pack's own text box while the box is up.
var _swap_cursor: int = 0
var _swap_target: int = -1
var _swap_question: String = ""
## Whether the USE running is `UseRegisteredItem`'s rather than the pack's own,
## which is the one thing the two jumptables disagree about: their refusals.
var _using_registered: bool = false
## An entry point asked for before the panel was built, run once it is.
var _pending_entry: Callable = Callable()

## ForgetMove's list and the two yes/no boxes around it. The party index is held
## because the second teach_tm_hm() call has to name the same Pokémon the first
## one refused.
var _forget_moves: Array = []
## `RestorePPEffect`'s own `MoveSelectionScreen`: which item asked and which
## party member it is being used on, held while the move list is up.
var _pp_item: int = 0
var _pp_party_index: int = -1
## `MoveCantForgetHMText` while the list it was refused on is still open.
var _forget_refusal: String = ""
var _forget_cursor: int = 0
var _forget_party_index: int = -1
var _forget_confirm_cursor: int = 0
## What is being learned, whichever opened the flow: a TM/HM's move or one an
## evolution offered. `_learning_move` is 0 while a TM owns the flow, so the
## confirm knows which of the two host calls to make.
var _forget_move_name: String = ""
var _learning_move: int = 0
## The moves a field evolution offered that would not fit, offered one at a time
## the way `EvolveAfterBattle` calls `LearnMove` over the new learnset.
var _evolution_offers: Array[int] = []

## `SaveMenu`'s own state: the text standing in the speech box, which of its
## lines is on the top row, `wMenuCursorY` for the yes/no, and the frames the
## two timed modes have spent.
var _save_lines: Array = []
var _save_line: int = 0
var _save_cursor: int = -1
var _save_frames: int = 0
var _save_clock := Gen2WorldAnimation.FrameClock.new()
## `SaveMenu`'s own sequence while one is up, and null the rest of the time.
var _save_prompt: Gen2SavePrompt = null

var _options_menu: Gen2WorldOptionsMenu = null

## The two kinds of row the MODS entry holds: see [method _mod_rows].
const MOD_ROW_VIEW: StringName = &"view"
const MOD_ROW_MOD: StringName = &"mod"

## The MODS entry: which mod is being configured and where each cursor sits.
## The rows themselves are the host's registrations, read fresh on every render
## so a value changed from the launcher is never shown stale. The VIEW row in
## front of them is the host's own and belongs to no mod: see [method _mod_rows].
var _mod_ids: Array[StringName] = []
var _mod_cursor: int = 0
var _mod_id: StringName = &""
var _mod_option_cursor: int = 0

## The cartridge's own screens, drawn into whichever [Gen2Screen] the host
## handed over. `StartMenu`'s box sits over the map, so it goes into the world's
## own screen rather than one of this node's; without one, nothing is drawn at
## all, which is what a test or the launcher gets.
var _screen: Gen2Screen = null
## `ComposeMailMessage`: the keyboard GIVE opens for a mail item, and what it
## wrote, held until [method _give_selected_item] runs the transaction with it.
var _naming: Gen2NamingScreenScreen = null
var _pending_mail: Gen2SaveMail = null
var _mail_item: int = 0
var _mail_target: int = -1
var _mail_swap: bool = false
var _view: TextureRect = null
var _page: Gen2StartMenuPage = null
## `LoadPartyMenuGFX`: the target list is the party menu, so it is drawn by the
## page that draws the party menu everywhere else.
var _target_page: Gen2PartyMenuPage = null
## The target list's icon clock.
var _target_clock := Gen2WorldAnimation.FrameClock.new()


## The MOVES row's own list: `{move, item, badge}` as
## [method Gen2WorldAPI.item_field_move_offers] answered when it was opened.
var _field_move_rows: Array = []
var _field_move_cursor: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _menu != null:
		_open_list_mode()
	if _pending_entry.is_valid():
		var entry: Callable = _pending_entry
		_pending_entry = Callable()
		entry.call()


## `save_action` takes no arguments and answers an "ok" key, with a "reason"
## behind a false one: a Callable, so this screen does not know where saves live.
## Called before or after the node enters the tree, the way the box screen is.
func open(world: Gen2WorldAPI, data: GameData, save_action: Callable, previous_cursor: int = 0) -> bool:
	_world = world
	_data = data
	_save_action = save_action
	if _world == null or _data == null:
		return false
	_menu = Gen2WorldStartMenu.from_world(_world, previous_cursor)
	if is_inside_tree():
		_open_list_mode()
	return true


## The save the pack's USE applies to, and whether that write reaches disk.
## Without it the pack lists items and refuses to use one, which is what a
## screenshot tool driving an injected world gets. Passed rather than wrapped the
## way `save_action` is: USE is a [Gen2WorldPartyHost] transaction over this same
## save, not a snapshot write only the world screen can do.
func set_party_context(save: Gen2SaveData, persist: bool = true) -> void:
	_pack_save = save
	_pack_persist = persist


## The list model's cursor, so a caller can carry it into the next open() the
## way the source's wBattleMenuCursorPosition survives a reopen.
func cursor() -> int:
	return _menu.cursor if _menu != null else 0


## `GiveTakePartyMonItem`'s GIVE, which opens the pack over a Pokemon the player
## has already chosen. [method open] and [method set_party_context] come first,
## the same way the start menu's own pack does.
func open_give(party_index: int) -> void:
	_give_target = party_index
	if _defer_entry(open_give.bind(party_index)):
		return
	_open_pack_mode()


## `SelectMenu`. `CheckRegisteredItem` answers first, and its `.NotRegistered`
## carry is `MayRegisterItemText` rather than a pack at all; otherwise
## `UseRegisteredItem` runs `CheckItemMenu`'s jumptable over the registered item,
## which is the same one the pack's own USE reads.
func open_registered_item() -> void:
	if _defer_entry(open_registered_item):
		return
	var item: int = Gen2WorldBagHost.registered_item(_world)
	_open_pack_mode()
	_using_registered = true
	if item <= 0:
		_show_pack_result(Gen2WorldPack.may_register_text(), false)
		return
	if not _select_pack_item(item):
		_show_pack_result(Gen2WorldPack.may_register_text(), false)
		return
	_confirm_use()


## Holds an entry point until this screen is in the tree, the way [method open]
## holds the list. A caller that opens this screen before adding it to the tree
## is a preview or a test; the overworld adds it first.
func _defer_entry(entry: Callable) -> bool:
	if is_inside_tree():
		return false
	_pending_entry = entry
	return true


## Puts the pack cursor on one item, which is what `CheckRegisteredItem` finding
## the entry in its pocket amounts to here.
func _select_pack_item(item: int) -> bool:
	for pocket_index: int in _pack_pockets.size():
		var items: Array = (_pack_pockets[pocket_index] as Dictionary).get("items", [])
		for index: int in items.size():
			if int((items[index] as Dictionary).get("item", 0)) != item:
				continue
			_pack_pocket_index = pocket_index
			_pack_cursor = index
			_render_pack()
			return true
	return false


func handle_button(button: int) -> bool:
	## The mail keyboard owns all 160x144 while it is up, the way BILL'S PC's
	## own does over the box screen.
	if _naming != null:
		return _naming.handle_button(button)
	## `BuySellToss_InterpretJoypad` reads the joypad itself and answers with a
	## carry, so the dial takes the whole button rather than a direction and an
	## A/B split, the way [Gen2WorldApricorn] feeds it.
	if _mode == Mode.PACK_TOSS_QUANTITY:
		var pressed: bool = _press_toss_quantity(button)
		_render_hardware()
		return pressed
	if Gen2Button.is_direction(button):
		_move(Gen2Button.vector(button))
		_render_hardware()
		return true
	match button:
		Gen2Button.A:
			_confirm()
			_render_hardware()
			return true
		Gen2Button.B:
			_cancel()
			_render_hardware()
			return true
		Gen2Button.SELECT:
			if _mode != Mode.PACK:
				return false
			_press_pack_select()
			_render_hardware()
			return true
	return false


## `Pack_InterpretJoypad`'s `.select` and `.switching_item`'s own SELECT, which
## are the same press: the first marks a row and the second places the held item
## on the row the cursor is on.
func _press_pack_select() -> void:
	if _give_target >= 0:
		## `DepositSellPack` runs its own joypad handler with no `.select` in it,
		## so a pack opened to pick one item does not reorder anything.
		return
	_apply_switch_press()


## One press of `SwitchItemsInBag`: the pocket's own rows, the row an earlier
## SELECT marked and the row the cursor is on. A press that moved something is
## written through [Gen2WorldBagHost], so the order the player arranged is in the
## save rather than in this screen.
func _apply_switch_press() -> void:
	var order: Array = []
	for row: Dictionary in _current_pocket_items():
		order.append(int(row.get("item", 0)))
	var answer: Dictionary = Gen2WorldPack.switch_items(order, _pack_switch, _pack_cursor)
	var next_order: Array = answer["order"]
	if next_order != order and _world != null:
		Gen2WorldBagHost.reorder(_world, _pack_save, next_order, false, _pack_persist)
		_open_pack_mode(false)
		## `.place_insert` asks for the same effect twice through `WaitPlaySFX`.
		sfx_requested.emit(SFX_SWITCH_POKEMON, true)
		sfx_requested.emit(SFX_SWITCH_POKEMON, true)
	_pack_switch = int(answer["held"])


func _move(direction: Vector2i) -> void:
	match _mode:
		Mode.LIST:
			## The source's .MenuData omits STATICMENU_ENABLE_LEFT_RIGHT, so
			## only vertical input moves the top-level list.
			if direction.x == 0 and _menu != null and _menu.move(direction.y):
				_scroll_list_to_cursor()
				_render_list()
		Mode.PACK:
			if direction.x != 0:
				_cycle_pocket(direction.x)
			elif direction.y != 0:
				_move_pack_cursor(direction.y)
		Mode.PACK_ITEM:
			_move_wrapped(
				direction.y, &"_item_cursor", _item_actions.size(), &"_render_item_menu"
			)
		Mode.PACK_FORGET, Mode.PACK_PP_MOVE:
			_move_forget_list(direction.y)
		Mode.PACK_TARGET:
			_move_wrapped(
				direction.y, &"_target_cursor", _target_rows(), &"_render_targets"
			)
		Mode.FIELD_MOVES:
			_move_wrapped(
				direction.y, &"_field_move_cursor", _field_move_rows.size(), &""
			)
		Mode.PACK_TEACH, Mode.PACK_FORGET_ASK, Mode.PACK_STOP_LEARNING, \
		Mode.PACK_TOSS_CONFIRM, Mode.PACK_GIVE_SWAP, Mode.SAVE_ASK, \
		Mode.SAVE_OVERWRITE, Mode.QUIT_ASK, Mode.LAUNCHER_ASK, Mode.RESET_ASK:
			_toggle_two_row(direction)
		Mode.OPTIONS:
			_move_options(direction)
		Mode.MODS:
			_move_mods(direction)
		Mode.MOD_OPTIONS:
			_move_mod_options(direction)


func _move_wrapped(step: int, at: StringName, rows: int, render: StringName) -> void:
	if step == 0 or rows <= 0:
		return
	set(at, wrapi(int(get(at)) + signi(step), 0, rows))
	if render != &"":
		call(render)


## `InitPartyMenuWithCancel`: CANCEL is the row after the last member and the
## cursor wraps around it, which is `w2DMenuNumRows` being the party count plus
## one.
func _target_rows() -> int:
	var targets: Array = _party_targets()
	return 0 if targets.is_empty() else targets.size() + 1


## w2DMenuNumCols is 1, so only vertical input moves the move list.
func _move_forget_list(step: int) -> void:
	if step == 0 or _forget_moves.is_empty():
		return
	_forget_cursor = wrapi(_forget_cursor + signi(step), 0, _forget_moves.size())
	_forget_refusal = ""
	_render_forget_list()


## `VerticalMenu` over a two-row box, where every direction toggles the cursor.
## The save family parks its own at -1 while a box is timed rather than asked,
## and reads no joypad then.
func _toggle_two_row(direction: Vector2i) -> void:
	var row: Array = TOGGLE_MODES[_mode]
	var at: int = int(get(row[0]))
	if at < 0 or direction == Vector2i.ZERO:
		return
	set(row[0], 1 - at)
	call(row[1])


func _move_options(direction: Vector2i) -> void:
	if direction.y != 0:
		_options_menu.move(direction.y)
		_render_options_menu()
	elif direction.x != 0 and _options_menu.adjust(direction.x):
		_persist_options()
		_render_options_menu()


func _move_mods(direction: Vector2i) -> void:
	var mod_rows: Array = _mod_rows()
	if mod_rows.is_empty():
		return
	if direction.y != 0:
		_mod_cursor = wrapi(_mod_cursor + signi(direction.y), 0, mod_rows.size())
		_render_mods()
	elif direction.x != 0 and _mod_view_row(mod_rows):
		_cycle_view(signi(direction.x))


func _move_mod_options(direction: Vector2i) -> void:
	var rows: Array = _mod_options()
	if rows.is_empty():
		return
	if direction.y != 0:
		_mod_option_cursor = wrapi(_mod_option_cursor + signi(direction.y), 0, rows.size())
		_render_mod_options()
	elif direction.x != 0:
		_adjust_mod_option(rows, direction.x)

func _confirm() -> void:
	var handler: StringName = CONFIRM_HANDLERS.get(_mode, &"")
	if handler != &"":
		call(handler)
		return
	match _mode:
		Mode.PACK:
			## `.switching_item` reads A before anything else, so the A that
			## would open an item's submenu places the held item instead.
			if _pack_switch >= 0:
				_apply_switch_press()
				return
			## `ScrollingMenuJoyAction`'s `.a_button` answers `-1` on the CANCEL
			## row and falls into `.b_button`, so choosing it leaves the pack.
			if _pack_cursor_on_cancel():
				_cancel()
				return
			## `DepositSellPack` acts on the item it is given rather than
			## opening a submenu over it, which is the pack `.GiveItem` opens.
			if _give_target >= 0:
				_give_selected_item(_give_target)
			else:
				_open_item_mode()
		Mode.PACK_TARGET:
			## `PartyMenuSelect` returns carry on CANCEL, which the caller answers
			## the same way it answers B.
			if _target_cursor >= _party_targets().size():
				_open_item_mode()
			elif _teaching:
				_teach_selected_item(_target_cursor)
			elif _giving:
				_give_selected_item(_target_cursor)
			else:
				_use_selected_item(_target_cursor)
		Mode.PACK_RESULT:
			_leave_pack_result()
		## Options_Cancel is the only handler that reads A.
		Mode.OPTIONS:
			if _options_menu.is_cancel():
				_open_list_mode()
		## The VIEW row is read with left and right, the way a value row is, so
		## A does nothing on it.
		Mode.MODS:
			var chosen: Dictionary = _mod_row()
			if StringName(chosen.get("kind", &"")) == MOD_ROW_MOD:
				_open_mod_options_mode(StringName(chosen["id"]))


## A pack opened over one Pokemon has no menu to go back to; A and B agree.
func _leave_pack_result() -> void:
	if _pack_result_advanced():
		return
	if _pack_result_continued():
		return
	if _give_target >= 0:
		closed.emit()
	else:
		_open_pack_mode(false)

func _cancel() -> void:
	match _mode:
		Mode.LIST:
			closed.emit()
		Mode.PACK:
			## `.end_switch`, which drops the mark and leaves the pack open.
			if _pack_switch >= 0:
				_pack_switch = -1
				return
			if _give_target >= 0:
				closed.emit()
			else:
				_open_list_mode()
		Mode.PACK_ITEM, Mode.PACK_TEACH:
			_open_pack_mode(false)
		Mode.PACK_RESULT:
			_leave_pack_result()
		## B at ForgetMove's ask is YesNoBox's no, and B in the move list is its
		## own .cancel's scf. Both are the carry LearnMove.cancel tests.
		Mode.PACK_FORGET_ASK, Mode.PACK_FORGET:
			_open_stop_learning()
		## No to "Stop learning?" is `jp .loop`, back to ForgetMove's ask.
		Mode.PACK_STOP_LEARNING:
			_open_forget_ask()
		## B in `MoveSelectionScreen` is `jr nz, .loop`, back to the party list.
		Mode.PACK_PP_MOVE:
			_open_target_mode()
		Mode.PACK_TARGET:
			_open_item_mode()
		## B at the yes/no is `YesNoBox`'s no, which is the carry `TossMenu`
		## returns on. The submenu is already closed by then, so it lands back on
		## the pocket list rather than on the item's own menu.
		Mode.PACK_TOSS_CONFIRM, Mode.PACK_GIVE_SWAP:
			_open_pack_mode(false)
		Mode.SAVE_ASK, Mode.SAVE_OVERWRITE, Mode.SAVE_SAVING, Mode.SAVE_SAVED, \
		Mode.SAVE_FAILED, Mode.QUIT_ASK, Mode.LAUNCHER_ASK, Mode.RESET_ASK:
			_cancel_save()
		## `_Option.joypad_loop` exits on PAD_START | PAD_B from any row.
		Mode.OPTIONS, Mode.MODS, Mode.FIELD_MOVES:
			_open_list_mode()
		Mode.MOD_OPTIONS:
			_open_mods_mode()


func _confirm_list() -> void:
	if _menu == null or _menu.size() == 0:
		return
	if not _menu.selected_available():
		return
	match _menu.selected_kind():
		Gen2WorldStartMenu.ITEM_PACK:
			_open_pack_mode()
		Gen2WorldStartMenu.ITEM_SAVE:
			_open_save_confirm_mode()
		Gen2WorldStartMenu.ITEM_QUIT:
			_enter_save_mode(Mode.QUIT_ASK, QUIT_ASK_LINES, 0)
		Gen2WorldStartMenu.ITEM_OPTION:
			_open_options_mode()
		Gen2WorldStartMenu.ITEM_MODS:
			_open_mods_mode()
		Gen2WorldStartMenu.ITEM_FIELD_MOVES:
			_open_field_moves_mode()
		Gen2WorldStartMenu.ITEM_EXIT:
			closed.emit()
		Gen2WorldStartMenu.ITEM_LAUNCHER:
			_enter_save_mode(Mode.LAUNCHER_ASK, LAUNCHER_ASK_LINES, 0)
		Gen2WorldStartMenu.ITEM_POKEDEX, Gen2WorldStartMenu.ITEM_POKEMON, \
		Gen2WorldStartMenu.ITEM_POKEGEAR, Gen2WorldStartMenu.ITEM_PLAYER:
			action_chosen.emit(_menu.selected_kind(), &"")
		_:
			# A Gen2ModHost-registered entry. Either it names a host action, which
			# only the world screen can perform, or it carries the handler that
			# made it available at all; this cannot reach one with neither.
			var entry: Dictionary = _menu.selected_item()
			var action: StringName = StringName(entry.get("action", &""))
			if action != &"":
				## A page row names the page it opens; every other action needs
				## only its own name.
				action_chosen.emit(
					action, StringName(entry.get("page", entry.get("kind", &"")))
				)
				return
			var handler: Variant = entry.get("handler", null)
			if handler is Callable:
				(handler as Callable).call()


## `StartMenu_PrintBugContestStatus`' three values: `wContestMon` and its level,
## and `wParkBallsRemaining`. An unset `wContestMon` is the empty name the page
## prints `.NoneString` for.
func _contest_status() -> Dictionary:
	if _world == null:
		return {}
	var caught: Dictionary = _world.state.contest_mon()
	var species: int = int(caught.get("species", 0))
	return {
		"name": String(_world.data.species(species).get("name", "")) \
			if species > 0 and _world.data != null else "",
		"level": int(caught.get("level", 0)),
		"balls": _world.state.park_balls(),
	}


func _open_list_mode() -> void:
	_save_prompt = null
	_mode = Mode.LIST
	## The row the menu reopens on is the one it was left on, which may be past
	## the window a previous open left behind.
	_scroll_list_to_cursor()
	_render_list()


## The window the list is drawn through. The box is the height of the screen and
## the cartridge's own eight rows fill it exactly, so a `MENU_START` entry a mod
## registers is a row past the bottom; `_move_pack_cursor` solves the same thing
## for a pocket, and this is its twin. `STATICMENU_WRAP` still wraps the cursor,
## and the window follows it round, so EXIT is one press up from the top row.
func _scroll_list_to_cursor() -> void:
	if _menu == null:
		_list_scroll = 0
		return
	var shown: int = Gen2StartMenuPage.visible_rows(
		_world != null and _world.bug_contest_active()
	)
	_list_scroll = clampi(
		clampi(_list_scroll, _menu.cursor - shown + 1, _menu.cursor),
		0, maxi(_menu.size() - shown, 0)
	)


func _render_list() -> void:
	if _menu == null:
		return
	_render_hardware()


## `StartMenu_Option`'s `farcall Option`. The model edits the shared
## [Gen2OptionsStore] object, so the launcher's settings card and this menu can
## never disagree about a value, which is the same reason the cartridge block
## exists at all.
func _open_options_mode() -> void:
	_mode = Mode.OPTIONS
	_options_menu = Gen2WorldOptionsMenu.build(Gen2OptionsStore.current())
	_render_options_menu()


## Written on every change, matching the launcher card and the cartridge, which
## commits each press to `wOptions` rather than on the way out.
func _persist_options() -> void:
	if Gen2OptionsStore.save(_options_menu.options()):
		return


func _render_options_menu() -> void:
	_render_hardware()


## The MODS entry: the mods that registered a setting, one row each. Only
## reachable when there is at least one, which is what puts the entry in the list
## at all.
func _open_mods_mode() -> void:
	_mode = Mode.MODS
	_mod_ids = Gen2ModHost.instance().option_mod_ids()
	_mod_cursor = clampi(_mod_cursor, 0, maxi(_mod_rows().size() - 1, 0))
	_render_mods()


## The rows MODS shows: the host's own VIEW row where there is more than one view
## to choose from, then one row per mod that registered a setting. The view is
## the host's rather than any mod's, since `Gen2ModHost` holds one selection for
## both surfaces; `V` is behind [method Gen2DebugKeys.enabled], so this is the
## only place a shipped build can change it.
func _mod_rows() -> Array:
	var rows: Array = []
	if Gen2ModHost.instance().view_ids().size() > 1:
		rows.append({"kind": MOD_ROW_VIEW, "id": &""})
	for id: StringName in _mod_ids:
		rows.append({"kind": MOD_ROW_MOD, "id": id})
	return rows


## The row the cursor is on, empty where there is none.
func _mod_row() -> Dictionary:
	var rows: Array = _mod_rows()
	if _mod_cursor < 0 or _mod_cursor >= rows.size():
		return {}
	return rows[_mod_cursor]


func _mod_view_row(rows: Array) -> bool:
	return _mod_cursor >= 0 and _mod_cursor < rows.size() \
		and StringName(rows[_mod_cursor].get("kind", &"")) == MOD_ROW_VIEW


## One step along the host's view list, wrapping. The switch is the host's, so
## the live screens rebuild on [signal Gen2ModHost.view_changed] and this row
## neither knows nor cares which of them is up.
func _cycle_view(step: int) -> void:
	var host: Gen2ModHost = Gen2ModHost.instance()
	var ids: Array[StringName] = host.view_ids()
	if ids.size() < 2:
		return
	var at: int = maxi(ids.find(host.selected_view()), 0)
	host.select_view(ids[posmod(at + step, ids.size())])
	_render_mods()


func _render_mods() -> void:
	_render_hardware()


## The MOVES entry: one row per HM field move the bag can supply and no party
## member knows. Only reachable while there is at least one, which is what puts
## the entry in the list at all.
func _open_field_moves_mode() -> void:
	_mode = Mode.FIELD_MOVES
	_field_move_rows = _world.item_field_move_offers() if _world != null else []
	_field_move_cursor = clampi(_field_move_cursor, 0, maxi(_field_move_rows.size() - 1, 0))


## `PokemonActionSubmenu`'s own exit: the menu closes and the move runs. The
## action is the party submenu's shape with no slot in it, so the world's one
## dispatch decides what the move does and the source's own text names the
## player rather than a Pokemon.
func _confirm_field_move() -> void:
	if _field_move_cursor < 0 or _field_move_cursor >= _field_move_rows.size():
		return
	var row: Dictionary = _field_move_rows[_field_move_cursor]
	field_move_chosen.emit({
		"kind": &"field_move", "move": int(row["move"]), "slot": -1,
		"item": int(row.get("item", 0)),
	})


## The name of each offered move, which is the cartridge's own.
func _field_move_labels() -> Array:
	var out: Array = []
	for row: Dictionary in _field_move_rows:
		out.append(String(_data.move(int(row["move"])).get("name", "")) if _data != null else "")
	return out


## The name the player installed, falling back to the id for a mod registered
## without a manifest, which is what a test or the built-in host does.
func _mod_name(id: StringName) -> String:
	for manifest: Gen2ModManifest in Gen2ModHost.instance().manifests():
		if manifest.id == id:
			return manifest.name
	return String(id)


func _open_mod_options_mode(id: StringName) -> void:
	_mode = Mode.MOD_OPTIONS
	_mod_id = id
	_mod_option_cursor = 0
	_render_mod_options()


## Read from the host on every render rather than held, so a value the launcher
## changed is never shown stale.
func _mod_options() -> Array:
	return Gen2ModHost.instance().options(_mod_id)


func _render_mod_options() -> void:
	_render_hardware()


## A button row acts on the press and stores nothing. A ladder row ignores A.
func _press_mod_option() -> void:
	var rows: Array = _mod_options()
	if rows.is_empty():
		return
	var row: Dictionary = rows[_mod_option_cursor]
	if StringName(row.get("kind", Gen2ModHost.OPTION_LADDER)) != Gen2ModHost.OPTION_BUTTON:
		return
	## Both of `press_option`'s refusals are ruled out by the two checks above,
	## and this screen has no cartridge box to print one in either way.
	Gen2ModHost.instance().press_option(_mod_id, StringName(row.get("key", &"")))


## One step either way: a rung, wrapping the way the cartridge's own value rows
## do, or one of a number's own steps. Written through the host, so the file is
## committed on the press and whatever registered the setting hears about it at
## once.
func _adjust_mod_option(rows: Array, delta: int) -> void:
	var row: Dictionary = rows[_mod_option_cursor]
	if StringName(row.get("kind", Gen2ModHost.OPTION_LADDER)) == Gen2ModHost.OPTION_BUTTON:
		return
	var result: Dictionary = Gen2ModHost.instance().adjust_option(
		_mod_id, StringName(row.get("key", &"")), delta
	)
	if not bool(result.get("ok", false)):
		return
	_render_mod_options()


## [param reset] false keeps the pocket and cursor, which is what returning from
## an item submenu does; the source restores each pocket's own saved cursor the
## same way. The item list is always rebuilt, since a USE changed a quantity.
func _open_pack_mode(reset: bool = true) -> void:
	_mode = Mode.PACK
	_giving = false
	_teaching = false
	_using_registered = false
	_evolution_offers.clear()
	_learning_move = 0
	_forget_move_name = ""
	_pack_pockets = Gen2WorldPack.build(_data, _world.state) if _world != null else []
	if reset:
		_pack_pocket_index = 0
		_pack_cursor = 0
		_pack_cursors.fill(0)
		_pack_scroll.fill(0)
	## `Pack_Jumptable`'s entry clears `wSwitchItem`, so a pack reopened after a
	## submenu holds nothing.
	_pack_switch = -1
	_pack_pocket_index = clampi(_pack_pocket_index, 0, maxi(_pack_pockets.size() - 1, 0))
	## The CANCEL row is always there, so an emptied pocket puts the cursor on it
	## rather than on an item that is gone.
	_pack_cursor = clampi(_pack_cursor, 0, _current_pocket_items().size())
	_render_pack()


func _current_pocket() -> Dictionary:
	if _pack_pockets.is_empty():
		return {}
	return _pack_pockets[_pack_pocket_index]


func _current_pocket_items() -> Array:
	return _current_pocket().get("items", [])


## `.ItemsPocketMenu` and its three siblings, each of which stores its own
## `w*PocketCursor` and `w*PocketScrollPosition` on the way out and loads them
## again on the way in, so a pocket is where the player left it.
func _cycle_pocket(delta: int) -> void:
	if _pack_pockets.is_empty():
		return
	## `.switching_item` answers left and right with a plain carry, so the pocket
	## cannot be changed while a row is held.
	if _pack_switch >= 0:
		return
	_pack_cursors[_pack_pocket_index] = _pack_cursor
	_pack_pocket_index = wrapi(_pack_pocket_index + signi(delta), 0, _pack_pockets.size())
	## `.d_left` and `.d_right` each play it before they leave.
	sfx_requested.emit(SFX_SWITCH_POCKETS, false)
	_pack_cursor = clampi(
		_pack_cursors[_pack_pocket_index], 0, _current_pocket_items().size()
	)
	_render_pack()


## `ScrollingMenuJoyAction`'s `.d_up` and `.d_down`, which move the cursor
## inside the visible five and scroll only at their edges. The CANCEL row is one
## past the last item, which is what makes the walk wrap over `size + 1`.
func _move_pack_cursor(delta: int) -> void:
	var rows: int = _current_pocket_items().size() + 1
	_pack_cursor = wrapi(_pack_cursor + signi(delta), 0, rows)
	_pack_scroll[_pack_pocket_index] = clampi(
		clampi(
			_pack_scroll[_pack_pocket_index],
			_pack_cursor - (Gen2PackPage.LIST_HEIGHT - 1), _pack_cursor
		),
		0, maxi(rows - Gen2PackPage.LIST_HEIGHT, 0)
	)
	_render_pack()


## Whether the cursor is on `ScrollingMenu_UpdateDisplay`'s CANCEL row, which is
## what a pocket with nothing in it is entirely made of.
func _pack_cursor_on_cancel() -> bool:
	return _pack_cursor >= _current_pocket_items().size()


func _render_pack() -> void:
	_render_hardware()


func _pack_rows() -> Array:
	return Gen2WorldPack.list_rows(
		_data,
		int(_current_pocket().get("pocket", 0)),
		_current_pocket_items(),
		_pack_scroll[_pack_pocket_index],
	)


## The pack as the cartridge draws it. `UpdateItemDescription` prints the item's
## own description, and the TM/HM pocket the move's; a cursor on CANCEL leaves
## the box empty, which is what `TMHM_CheckHoveringOverCancel` does.
func _pack_image() -> Image:
	if _pack_page == null:
		_pack_page = Gen2PackPage.from_data(_data)
	if _pack_page == null:
		return null
	return _pack_page.image(
		_data, _pack_map(_pack_description()), _pack_pocket_index, _player_is_female()
	)


## The pocket listing's own tilemap with [param text] in its description box,
## which is where every one of the pack's prints lands: `Pack_PrintTextNoScroll`
## and `MenuTextbox` both write the same six rows at the foot of the screen.
func _pack_map(text: String) -> PackedInt32Array:
	var pocket: int = _pack_pocket_index
	return _pack_page.pocket_map(
		pocket, _pack_rows(), _pack_cursor - _pack_scroll[pocket], text,
		_data.pack_pocket_name(pocket) if _data != null else PackedByteArray()
	)


## The pack's screen with one of its `MENU_BACKUP_TILES` boxes over it.
## [param draw_page] writes tiles into the map the pack just built, so the box wears
## the attrmap `_CGB_PackPals` left rather than being a layer of its own.
func _pack_overlay(text: String, draw_page: Callable) -> Image:
	if _pack_page == null:
		_pack_page = Gen2PackPage.from_data(_data)
	if _pack_page == null:
		return null
	var map: PackedInt32Array = _pack_map(text)
	if draw_page.is_valid():
		draw_page.call(map)
	return _pack_page.image(_data, map, _pack_pocket_index, _player_is_female())


## `YesNoBox` over one of the pack's printed questions, which is what every one
## of its confirmations is.
func _pack_yes_no(text: String, cursor_index: int) -> Image:
	return _pack_overlay(_last_page(text), func(map: PackedInt32Array) -> void:
		_pack_page.draw_menu(
			map,
			Gen2MenuBox.from_coords(
				YES_NO_AT.x, YES_NO_AT.y,
				YES_NO_AT.x + YES_NO_SPAN.x, YES_NO_AT.y + YES_NO_SPAN.y,
				SUBMENU_FLAGS
			),
			YES_NO_OPTIONS, cursor_index
		)
	)


## `MenuHeader_UsableKeyItem` and its five siblings, which are one box whose top
## is chosen so [param count] rows end on the text box.
func _item_menu_box(count: int) -> Gen2MenuBox:
	return Gen2MenuBox.from_coords(
		ITEM_MENU_LEFT, ITEM_MENU_BOTTOM - 2 * maxi(count, 0),
		ITEM_MENU_RIGHT, ITEM_MENU_BOTTOM, SUBMENU_FLAGS
	)


## What a box is left holding after the prints in front of a question: `YesNoBox`
## opens over the last page of the last `PrintText`, so a question preceded by
## more words than two rows hold shows its tail rather than its head.
## `AskTeachTMHM`'s pair of texts is the one that reaches past a page.
func _last_page(text: String) -> String:
	var pages: Array = Gen2TextLayout.lay_out(
		text, Gen2PackPage.TEXTBOX_COLUMNS - 2, Gen2PackPage.TEXTBOX_ROWS_OF_TEXT
	)
	if pages.is_empty():
		return ""
	return "\n".join(pages[pages.size() - 1] as PackedStringArray)


## Which page of the result text the box is holding.
func _pack_result_text() -> String:
	if _pack_result_pages.is_empty():
		return ""
	var page: PackedStringArray = _pack_result_pages[
		clampi(_pack_result_page, 0, _pack_result_pages.size() - 1)
	]
	return "\n".join(page)


func _pack_description() -> String:
	## `.select` prints `AskItemMoveText` over the description and nothing
	## reprints one until the item is placed.
	if _pack_switch >= 0:
		return Gen2WorldPack.ask_item_move_text()
	if _pack_cursor_on_cancel() or _data == null:
		return ""
	return Gen2WorldPack.row_description(_data, int(_selected_item().get("item", 0)))


## `wPlayerGender`, which picks Kris's pack and her own palettes.
func _player_is_female() -> bool:
	return _world != null and _world.player_female()


func _selected_item() -> Dictionary:
	var items: Array = _current_pocket_items()
	if _pack_cursor < 0 or _pack_cursor >= items.size():
		return {}
	return items[_pack_cursor]


## `.ItemBallsKey_LoadSubmenu` and `.TMHMPocketMenu` both open a submenu on the
## selected item rather than acting on it directly.
func _open_item_mode() -> void:
	var item: Dictionary = _selected_item()
	if item.is_empty():
		return
	_mode = Mode.PACK_ITEM
	## Both are answers the party list ahead is still waiting to give. Leaving
	## either set here is what let a TM's cancelled ChooseMonToLearnTMHM teach
	## itself from the next item's own `.Party` list.
	_teaching = false
	_giving = false
	_item_actions = Gen2WorldPack.item_submenu(_data, int(item.get("item", 0)))
	_item_cursor = 0
	_render_item_menu()


func _render_item_menu() -> void:
	_render_hardware()


func _confirm_item_action() -> void:
	if _item_cursor < 0 or _item_cursor >= _item_actions.size():
		return
	var action: StringName = StringName(
		(_item_actions[_item_cursor] as Dictionary).get("action", &"")
	)
	match action:
		Gen2WorldPack.ACTION_QUIT:
			_open_pack_mode(false)
		Gen2WorldPack.ACTION_TOSS:
			_open_toss_quantity()
		Gen2WorldPack.ACTION_GIVE:
			_open_give_target()
		Gen2WorldPack.ACTION_SELECT:
			_register_selected_item()
		_:
			_confirm_use()


## `GiveItem`'s own party list, which `.NoPokemon` answers when there is none.
func _open_give_target() -> void:
	if _party_targets().is_empty():
		_show_pack_result(_pack_text(TEXT_NO_MON), false)
		return
	_giving = true
	_open_target_mode()


## `RegisterItem`. `CheckSelectableItem` has already decided whether SEL is in
## the submenu at all, so the refusal here is only reachable from a caller that
## is not that submenu.
func _register_selected_item() -> void:
	var item: Dictionary = _selected_item()
	if item.is_empty():
		return
	if _world == null:
		_show_pack_result("No world is loaded.", false)
		return
	var result: Dictionary = Gen2WorldBagHost.register(
		_world, _pack_save, int(item.get("item", 0)), _pack_persist
	)
	if not bool(result.get("ok", false)):
		if StringName(result.get("reason", &"")) == &"item_cannot_be_registered":
			_show_pack_result(Gen2WorldPack.cant_register_text(), false)
			return
		_show_pack_result(
			"Could not register that (%s)." % String(result.get("reason", "")), false
		)
		return
	_show_pack_result(Gen2WorldPack.registered_text(String(result.get("name", ""))), true)


## `TryGiveItemToPartymon`, from either direction: the pack's GIVE names the
## Pokemon last and `GiveTakePartyMonItem`'s GIVE names the item last. A hand
## that is already full stops at `PokemonAskSwapItemText` with nothing written.
func _give_selected_item(party_index: int, swap: bool = false) -> void:
	var item: Dictionary = _selected_item()
	if item.is_empty():
		return
	if _pack_save == null or _world == null:
		_show_pack_result("No save is loaded.", false)
		return
	var number: int = int(item.get("item", 0))
	if not Gen2WorldPack.can_hold(_data, number):
		_show_pack_result(Gen2WorldPack.cant_hold_text(), false)
		return
	## `GivePartyItem` writes the item and then runs `ComposeMailMessage`; here
	## the message is written first, because the transaction is what commits and
	## a cancelled entry has to leave the bag alone.
	if Gen2HeldItem.is_mail(number) and _pending_mail == null:
		_open_mail_composer(number, party_index, swap)
		return
	var result: Dictionary = Gen2WorldBagHost.give_to_party(
		_world, _pack_save, number, party_index, swap, _pack_persist, _pending_mail
	)
	_pending_mail = null
	if bool(result.get("ok", false)):
		var target_name: String = _target_name(party_index)
		var held_name: String = String(result.get("held_name", ""))
		_show_pack_result(
			Gen2WorldPack.swap_text(target_name, held_name, String(result.get("name", ""))) \
				if int(result.get("held", 0)) > 0 \
				else Gen2WorldPack.hold_text(target_name, String(result.get("name", ""))),
			true
		)
		return
	var reason: StringName = StringName(result.get("reason", &""))
	if reason == &"already_holding":
		_open_give_swap(party_index, String(
			(result.get("details", {}) as Dictionary).get("held_name", "")
		))
		return
	_show_pack_result(_give_refusal(reason, party_index), false)


## `_ComposeMailMessage` over the party menu's own screen. The entry is the
## caller's, so it is written here and handed to the transaction; B on the
## keyboard is not a way out of the screen, so an empty message is a message.
func _open_mail_composer(item: int, party_index: int, swap: bool) -> void:
	if _naming != null or _screen == null:
		return
	var host := Gen2NamingScreenScreen.new()
	if not host.open(_data, "", Gen2NamingScreenScreen.KIND_MAIL):
		host.free()
		_show_pack_result("The mail keyboard is not in this cache.", false)
		return
	_naming = host
	_mail_item = item
	_mail_target = party_index
	_mail_swap = swap
	host.z_index = 5
	host.closed.connect(_on_mail_composed)
	_screen.display(host)


## `ComposeMailMessage`'s tail: the stored entry, the player's own name and ID,
## the species that is about to hold it and the item itself.
func _on_mail_composed(_name: String) -> void:
	var entry: PackedByteArray = _naming.model().stored_entry() if _naming != null 		else Gen2SaveMail.blank_message()
	if _naming != null:
		Gen2Screen.drop(_naming)
		_naming = null
	var species: int = 0
	if _pack_save != null and _mail_target >= 0 and _mail_target < _pack_save.party.size():
		species = (_pack_save.party[_mail_target] as Gen2SaveMon).species
	_pending_mail = Gen2SaveMail.compose(
		entry,
		_pack_save.player_name if _pack_save != null else "",
		_pack_save.player_id if _pack_save != null else 0,
		species, _mail_item
	)
	_give_selected_item(_mail_target, _mail_swap)


func _give_refusal(reason: StringName, party_index: int) -> String:
	match reason:
		&"holding_mail":
			## `.please_remove_mail`, the one refusal a swap is not offered for.
			return "Please remove the\nMAIL first."
		&"cannot_hold_egg":
			return Gen2WorldPack.egg_cant_hold_text()
		&"item_cannot_be_held":
			return Gen2WorldPack.cant_hold_text()
		&"bag_full":
			return Gen2WorldPack.storage_full_text()
		&"insufficient_item_quantity":
			return "You have none of those."
	return "%s could not be given that (%s)." % [_target_name(party_index), String(reason)]


func _open_give_swap(party_index: int, held_name: String) -> void:
	_mode = Mode.PACK_GIVE_SWAP
	_swap_cursor = 0
	_swap_target = party_index
	_swap_question = Gen2WorldPack.ask_swap_text(_target_name(party_index), held_name)
	_render_give_swap()


func _render_give_swap() -> void:
	_render_hardware()


## The answer to `PokemonAskSwapItemText`. Its no is `.abort`, which leaves both
## items where they were.
func _confirm_give_swap() -> void:
	if _swap_cursor != 0:
		_open_pack_mode(false)
		return
	_give_selected_item(_swap_target, true)


## `UseItem`'s jumptable: `.Oak` refuses, `.Current` and `.Field` apply straight
## away, and `.Party` asks which Pokemon first. `.Field` runs the effect here and
## quits the pack only when it succeeded, which is `wItemEffectSucceeded`; a CLOSE
## item this project has no effect for leaves the byte clear and lands on `.Oak`
## with every other refusal.
func _confirm_use() -> void:
	var item: Dictionary = _selected_item()
	if item.is_empty():
		return
	var number: int = int(item.get("item", 0))
	## The TM/HM pocket never reaches `UseItem`'s jumptable: engine/items/pack.asm
	## gives it its own USE, which runs AskTeachTMHM first.
	if Gen2WorldPack.pocket_for(_data, number) == Gen2WorldPack.TYPE_TM_HM:
		_open_teach_mode(number)
		return
	match Gen2WorldPack.field_use_kind(_data, number):
		Gen2WorldPack.ITEMMENU_PARTY:
			if _party_targets().is_empty():
				_show_pack_result(_pack_text(TEXT_NO_MON), false)
				return
			_open_target_mode()
		Gen2WorldPack.ITEMMENU_CURRENT:
			## `CoinCaseEffect` is `MenuTextboxWaitButton` over
			## `_CoinCaseCountText` and nothing else: the count is shown where the
			## pack already prints, and the pack stays open behind it.
			if number == Gen2WorldPack.ITEM_COIN_CASE:
				_show_pack_result(_coin_case_text(), true)
				return
			## `BlueCardEffect` is the same routine over a different text and a
			## different counter, and it closes nothing either.
			if number == Gen2WorldPack.ITEM_BLUE_CARD:
				_show_pack_result(_blue_card_text(), true)
				return
			if Gen2WorldPack.TROPHY_BOXES.has(number):
				_open_trophy_box(number)
				return
			_use_selected_item(-1)
		Gen2WorldPack.ITEMMENU_CLOSE:
			_use_field_item(number)
		_:
			_show_pack_result(_pack_text(TEXT_OAK), false)


## `.Field`: `DoItemEffect` and then `wItemEffectSucceeded`. The effects that run
## in the overworld are resolved here and reported to the host, which is what
## `QueueScript` is on the cartridge; the pack itself only decides whether to
## quit.
func _use_field_item(item: int) -> void:
	var request: Dictionary = _resolve_field_item(item) if _world != null else {}
	if not bool(request.get("ok", false)):
		## `.Field` says `.Oak` and `UseRegisteredItem`'s `.Overworld`
		## `CantUseItem`, which is the one thing the two jumptables disagree on.
		_show_pack_result(_use_refusal(&"item_effect_failed", item), false)
		return
	## `.CheckIfRegistered`: the Bicycle's two scripts each have a silent copy.
	request["registered"] = _using_registered
	field_item_used.emit(request)


## One `ItemEffects` entry each, in the order `Gen2WorldPack.FIELD_EFFECTS` names
## them. A failure is `.Oak`, whatever the effect's own reason was: the source
## reads one byte and cannot tell them apart either.
func _resolve_field_item(item: int) -> Dictionary:
	var effect: StringName = Gen2WorldPack.field_effect(_data, item)
	var request: Dictionary = {"ok": true, "effect": effect, "item": item}
	match effect:
		Gen2WorldPack.FIELD_EFFECT_BICYCLE:
			var ridden: Dictionary = _world.bike_request()
			if not bool(ridden.get("ok", false)):
				return {"ok": false}
			request["bike"] = ridden
		Gen2WorldPack.FIELD_EFFECT_ESCAPE_ROPE:
			var escaped: Dictionary = _world.escape_rope_request()
			if not bool(escaped.get("ok", false)):
				return {"ok": false}
			## `UseDisposableItem`, which only the succeeding half reaches. The
			## row was chosen out of the pack, so the pocket holds at least one.
			if _world.inventory != null:
				_world.inventory.change_item_quantity(item, -1)
			request["warp"] = escaped
		Gen2WorldPack.FIELD_EFFECT_ROD:
			var rod: StringName = Gen2WorldInventory.rod_for_item(item)
			if not bool(_world.fishing_check(rod).get("ok", false)):
				return {"ok": false}
			request["rod"] = rod
		Gen2WorldPack.FIELD_EFFECT_ITEMFINDER:
			request["found"] = _world.hidden_item_nearby()
		Gen2WorldPack.FIELD_EFFECT_CARD_KEY:
			var slot: Dictionary = _world.card_key_request()
			if not bool(slot.get("ok", false)):
				return {"ok": false}
			request.merge(slot, true)
		Gen2WorldPack.FIELD_EFFECT_BASEMENT_KEY:
			var door: Dictionary = _world.basement_key_request()
			if not bool(door.get("ok", false)):
				return {"ok": false}
			request.merge(door, true)
		## The one effect that cannot fail: `_Squirtbottle` writes
		## `wItemEffectSucceeded` before the script it queues decides anything,
		## so the pack closes whether or not a Sudowoodo is in front.
		Gen2WorldPack.FIELD_EFFECT_SQUIRTBOTTLE:
			request.merge(_world.squirtbottle_request(), true)
		Gen2WorldPack.FIELD_EFFECT_SACRED_ASH:
			if _pack_save == null:
				return {"ok": false}
			var used: Dictionary = Gen2WorldPartyHost.use_item(
				_world, _pack_save, item, -1, _pack_persist
			)
			if not bool(used.get("ok", false)):
				return {"ok": false}
			request["healed"] = int(used.get("healed", 0))
		_:
			return {"ok": false}
	return request


## `.Party`'s party list. Reads the same save the USE will be applied to, so a
## screen without one offers no targets and answers `.NoPokemon`. The rows are
## `WritePartyMenuTilemap`'s, in the shape [Gen2PartyMenuPage] draws and
## [Gen2PartyScreen] builds, since the list this opens is that same menu.
func _party_targets() -> Array:
	if _pack_save == null:
		return []
	var targets: Array = []
	for member: Variant in _pack_save.party:
		var mon: Gen2SaveMon = member as Gen2SaveMon
		if mon == null:
			continue
		# Max HP is derived, not stored, the same way Gen2PartyScreen derives it.
		var battle_mon: Gen2BattleMon = Gen2SaveBattleAdapter.to_battle_mon(_data, mon)
		var max_hp: int = 0 if battle_mon == null else battle_mon.max_hp()
		targets.append({
			"index": targets.size(),
			"species": mon.species,
			"item": mon.item,
			"name": mon.nickname if not mon.nickname.is_empty() \
				else String(_data.species(mon.species).get("name", "UNKNOWN")),
			"level": mon.level,
			"hp": mon.hp,
			"max_hp": 0 if mon.is_egg else max_hp,
			"status": mon.status,
			"fainted": not mon.is_egg and mon.hp <= 0,
			"egg": mon.is_egg,
		})
	return targets


## `PartyMenuStrings`, picked by the `wPartyMenuActionText` each of the three
## entrances writes: `TeachTMHM`'s PARTYMENUACTION_TEACH_TMHM, `GiveItem`'s
## PARTYMENUACTION_GIVE_ITEM, and the PARTYMENUACTION_HEALING_ITEM every
## `.Party` item effect writes.
func _target_prompt() -> String:
	if _teaching:
		return Gen2PartyScreen.PROMPT_TEACH_WHICH
	return Gen2PartyScreen.PROMPT_TO_WHICH if _giving \
		else Gen2PartyScreen.PROMPT_USE_ON_WHICH


## `LoadPartyMenuGFX`, built the first time the list is opened and kept, the way
## [member _page] is.
func _party_menu_page() -> Gen2PartyMenuPage:
	if _target_page == null and _data != null:
		_target_page = Gen2PartyMenuPage.from_data(_data)
	return _target_page


## One pass of the target list's icons, which animate on the hardware clock the
## rest of the party menu's do. Public the way [method advance_save_frame] is, so
## a test or a screenshot driver can step them without waiting on real time.
func advance_target_icons() -> void:
	if _target_page == null or _mode != Mode.PACK_TARGET:
		return
	_target_page.advance(_party_targets(), _target_cursor)
	_render_hardware()


## AskTeachTMHM: the booted-up text and its yes/no. A TM/HM the cartridge does
## not carry has no move, which is the source's `.NotTMHM` fall-through, so no
## prompt appears and USE reports nothing happened.
func _open_teach_mode(item: int) -> void:
	_teach_prompt = Gen2WorldTMHM.teach_prompt(_data, item)
	if not bool(_teach_prompt.get("ok", false)):
		_show_pack_result(_pack_text(TEXT_OAK), false)
		return
	_teaching = false
	_teach_cursor = 0
	_mode = Mode.PACK_TEACH
	_render_teach()


func _render_teach() -> void:
	_render_hardware()


## The yes/no answer. Yes reaches ChooseMonToLearnTMHM, which is the same party
## list `.Party` uses; no closes the way the source's carry return does.
func _confirm_teach() -> void:
	if _teach_cursor != 0:
		_open_pack_mode(false)
		return
	if _party_targets().is_empty():
		_show_pack_result(_pack_text(TEXT_NO_MON), false)
		return
	_teaching = true
	_open_target_mode()


func _teach_selected_item(party_index: int) -> void:
	if _pack_save == null or _world == null:
		_show_pack_result("No save is loaded.", false)
		return
	var item: int = int(_teach_prompt.get("item", 0))
	_learning_move = 0
	_forget_move_name = String(_teach_prompt.get("move_name", ""))
	var result: Dictionary = Gen2WorldPartyHost.teach_tm_hm(
		_world, _pack_save, item, party_index, -1, _pack_persist
	)
	_teaching = false
	if not bool(result.get("ok", false)):
		var reason: StringName = StringName(result.get("reason", &""))
		# LearnMove runs after CanLearnTMHMMove and KnowsMove, so this is the one
		# refusal that opens a menu instead of ending the USE.
		if reason == &"moveset_full":
			var details: Dictionary = result.get("details", {})
			_forget_party_index = party_index
			_forget_moves = Gen2MoveForget.options(_data, details.get("moves", []))
			if not _forget_moves.is_empty():
				_open_forget_ask()
				return
		_show_pack_result(_teach_refusal(reason, party_index), false)
		return
	_show_pack_result(Gen2MoveForget.learned_text(
		_target_name(party_index), String(_teach_prompt.get("move_name", ""))
	), true)


## ForgetMove's own AskForgetMoveText yes/no, which it prints before the list.
func _open_forget_ask() -> void:
	_mode = Mode.PACK_FORGET_ASK
	_forget_confirm_cursor = 0
	_render_forget_ask()


func _render_forget_ask() -> void:
	_render_hardware()


func _confirm_forget_ask() -> void:
	if _forget_confirm_cursor != 0:
		_open_stop_learning()
		return
	_open_forget_list()


## ForgetMove's .loop: MoveAskForgetText over the moves ListMoves drew. The
## cartridge's list is plain move names, so an HM is not marked here; it answers
## on confirm, the way .hmmove does.
func _open_forget_list() -> void:
	_mode = Mode.PACK_FORGET
	_forget_refusal = ""
	_forget_cursor = 0
	_render_forget_list()


## The list's own box carries `MoveCantForgetHMText` while it stands, since
## `.hmmove` prints it and is `jr .loop` rather than a cancel. Any move of the
## cursor puts `ListMoves`' own question back.
func _render_forget_list() -> void:
	_render_hardware()


## The answer TeachTMHM is called a second time with. An HM keeps the list open
## behind MoveCantForgetHMText, since .hmmove is `jr .loop` and not a cancel.
func _confirm_forget() -> void:
	if _forget_cursor < 0 or _forget_cursor >= _forget_moves.size():
		return
	var entry: Dictionary = _forget_moves[_forget_cursor]
	if not bool(entry.get("forgettable", false)):
		_forget_refusal = Gen2MoveForget.cant_forget_hm_text()
		_render_forget_list()
		return
	var slot: int = int(entry.get("slot", -1))
	var result: Dictionary = Gen2WorldPartyHost.learn_move(
		_world, _pack_save, _forget_party_index, _learning_move, slot, _pack_persist
	) if _learning_move > 0 else Gen2WorldPartyHost.teach_tm_hm(
		_world, _pack_save, int(_teach_prompt.get("item", 0)), _forget_party_index,
		slot, _pack_persist
	)
	if not bool(result.get("ok", false)):
		_show_pack_result(
			_teach_refusal(StringName(result.get("reason", &"")), _forget_party_index), false,
			_offer_next_evolution_move if _learning_move > 0 else Callable()
		)
		return
	var target_name: String = _target_name(_forget_party_index)
	_show_pack_result("%s %s" % [
		Gen2MoveForget.forgot_text(target_name, String(entry.get("name", ""))),
		Gen2MoveForget.learned_text(target_name, _forget_move_name),
	], true, _offer_next_evolution_move if _learning_move > 0 else Callable())


## LearnMove.cancel, reached from the ask's no and from B in the list alike.
func _open_stop_learning() -> void:
	_mode = Mode.PACK_STOP_LEARNING
	_forget_confirm_cursor = 0
	_render_stop_learning()


func _render_stop_learning() -> void:
	_render_hardware()


## Yes ends the offer with DidNotLearnMoveText; no is `jp .loop`, which reaches
## ForgetMove's ask again.
func _confirm_stop_learning() -> void:
	if _forget_confirm_cursor != 0:
		_open_forget_ask()
		return
	_show_pack_result(Gen2MoveForget.did_not_learn_text(
		_target_name(_forget_party_index), _forget_move_name
	), false, _offer_next_evolution_move if _learning_move > 0 else Callable())


func _target_name(party_index: int) -> String:
	var targets: Array = _party_targets()
	if party_index < 0 or party_index >= targets.size():
		return "#MON"
	return String((targets[party_index] as Dictionary).get("name", "#MON"))


## TeachTMHM's own refusals, verbatim from data/text/common_2.asm and
## common_3.asm. A full moveset is not among them: it opens ForgetMove's menu
## instead, so the only way to reach the two forget-slot reasons here is a
## revalidation failing between the two teach_tm_hm() calls.
func _teach_refusal(reason: StringName, party_index: int) -> String:
	var move_name: String = _forget_move_name if not _forget_move_name.is_empty() \
		else String(_teach_prompt.get("move_name", "that move"))
	var target_name: String = _target_name(party_index)
	match reason:
		&"not_compatible":
			return Gen2WorldTMHM.not_compatible_text(target_name, move_name)
		&"already_knows_move":
			return Gen2WorldTMHM.knows_move_text(target_name, move_name)
		&"cannot_forget_hm":
			return Gen2MoveForget.cant_forget_hm_text()
		&"invalid_forget_slot":
			return "%s can't forget that move." % target_name
		&"cannot_teach_egg":
			return "An EGG can't learn anything."
	return "Can't teach that: %s" % String(reason)


func _open_target_mode() -> void:
	_mode = Mode.PACK_TARGET
	_target_cursor = clampi(_target_cursor, 0, _party_targets().size())
	## `InitPartyMenuGFX` respawns one icon struct per member every time the list
	## is opened, which is what puts the icons on the page at all.
	if _party_menu_page() != null:
		_target_page.reset(_party_targets())
	_target_clock.reset()
	_render_targets()
	## `InitPartyMenuGFX` opens every struct on frame -1, so the icons are blank
	## until `DoNextFrameForAllSprites` has run once; the list is drawn after
	## that first pass rather than before it.
	advance_target_icons()


func _render_targets() -> void:
	## The panel fallback carries the same CANCEL row the hardware page draws, so
	## the cursor means one thing whichever of the two is up.
	var rows: Array = _party_targets()
	rows.append({"cancel": true})
	_render_hardware()


func _use_selected_item(party_index: int, move_slot: int = -1) -> void:
	var item: Dictionary = _selected_item()
	if item.is_empty():
		return
	if _pack_save == null or _world == null:
		_show_pack_result("No save is loaded.", false)
		return
	var number: int = int(item.get("item", 0))
	var result: Dictionary = Gen2WorldPartyHost.use_item(
		_world, _pack_save, number, party_index, _pack_persist, move_slot
	)
	if not bool(result.get("ok", false)):
		if StringName(result.get("reason", &"")) == &"move_slot_required":
			_open_pp_move_list(number, party_index)
			return
		_show_pack_result(_use_refusal(StringName(result.get("reason", &"")), number), false)
		return
	if StringName(result.get("effect", &"")) == &"rare_candy":
		## `RareCandyEffect` prints its level-up box and then runs
		## `LearnLevelMoves`, whose full-moveset case is the same `ForgetMove` the
		## TM path opens.
		_forget_party_index = party_index
		_evolution_offers.assign(result.get("move_offers", []))
		_show_pack_result(_use_summary(item, result), true, _offer_next_evolution_move)
		return
	if StringName(result.get("effect", &"")) == &"evolution":
		_forget_party_index = party_index
		_evolution_offers.assign(result.get("move_offers", []))
		## `EvoStoneEffect` reaches `EvolvePokemon` with `wForceEvolution` set, so
		## the same `EvolutionAnimation` runs and its B does nothing: the whole
		## presentation is the screen the after-battle pass uses, and this path
		## prints no box of its own.
		evolution_animation_requested.emit({
			"index": party_index,
			"old_species": int(result.get("old_species", 0)),
			"new_species": int(result.get("new_species", 0)),
			"evolving_name": String(result.get("evolving_name", "")),
			"statused": Gen2Evolution.is_statused(_pack_save.party[party_index]),
			## The stone does not touch the DV word either, so the plan carries
			## the same answer the level path's does. See `Gen2Evolution.plans`.
			"shiny": Gen2Stats.is_shiny(_pack_save.party[party_index].dvs),
			"can_cancel": false,
		}, _offer_next_evolution_move)
		return
	_show_pack_result(_use_summary(item, result), true)


## `EvolveAfterBattle`'s tail: `LearnMove` over what the new species knows at its
## own level, one move at a time, each able to open `ForgetMove` in turn.
func _offer_next_evolution_move() -> void:
	if _evolution_offers.is_empty():
		_learning_move = 0
		_forget_move_name = ""
		_open_pack_mode(false)
		return
	var move: int = _evolution_offers.pop_front()
	_learning_move = move
	_forget_move_name = String(_data.move(move).get("name", "")) if _data != null else ""
	var result: Dictionary = Gen2WorldPartyHost.learn_move(
		_world, _pack_save, _forget_party_index, move, -1, _pack_persist
	)
	if bool(result.get("ok", false)):
		_show_pack_result(Gen2MoveForget.learned_text(
			_target_name(_forget_party_index), _forget_move_name
		), true, _offer_next_evolution_move)
		return
	if StringName(result.get("reason", &"")) == &"moveset_full":
		var details: Dictionary = result.get("details", {})
		_forget_moves = Gen2MoveForget.options(_data, details.get("moves", []))
		if not _forget_moves.is_empty():
			_open_forget_ask()
			return
	_offer_next_evolution_move()


## The source has no single "it worked" line: the effect routine prints its own.
## These name what changed, from the values Gen2WorldPartyHost already returns.
func _use_summary(item: Dictionary, result: Dictionary) -> String:
	var item_name: String = String(item.get("name", "ITEM"))
	if int(result.get("repel_steps", -1)) >= 0:
		return "%s will repel weak Pokemon for %d steps." % [
			item_name, int(result.get("repel_steps", 0)),
		]
	if int(result.get("level", 0)) > 0:
		return "%s grew to level %d!" % [
			_target_name(_forget_party_index), int(result.get("level", 0)),
		]
	if int(result.get("restored", 0)) > 0:
		return PP_RESTORED
	var healed: int = int(result.get("healed", 0))
	if healed > 0:
		return "%s restored %d HP." % [item_name, healed]
	if int(result.get("status_cleared", 0)) != 0:
		return "%s cured the status." % item_name
	return "%s was used." % item_name


## `UseItem` and `UseRegisteredItem` refuse the same item in two words: the
## pack's `.Field` falls through to `.Oak` when the effect did nothing, and
## SELECT's `.Overworld` reaches `CantUseItem` instead.
func _use_refusal(reason: StringName, item: int) -> String:
	if _using_registered:
		return Gen2WorldPack.cant_use_text()
	## `.Field` reads one byte and says `.Oak` for every way an effect can fail,
	## so a CLOSE item is answered before the reasons `.Party`'s own effects give.
	if Gen2WorldPack.field_use_kind(_data, item) == Gen2WorldPack.ITEMMENU_CLOSE:
		return _pack_text(TEXT_OAK)
	match reason:
		&"item_has_no_effect":
			return "It won't have any effect."
		&"insufficient_item_quantity":
			return "You have none of those."
		&"pp_up_unsupported":
			return PP_UP_UNSUPPORTED
	return "Can't use that here: %s" % String(reason)


## `RestoreThePPOfWhichMoveText` and `MoveSelectionScreen` behind it. The list is
## the target's own moves; the item is spent when one is chosen.
func _open_pp_move_list(item: int, party_index: int) -> void:
	var mon: Gen2SaveMon = _pack_save.party[party_index] \
		if _pack_save != null and party_index >= 0 \
		and party_index < _pack_save.party.size() else null
	_forget_moves = Gen2MoveForget.options(_data, mon.moves) if mon != null else []
	if _forget_moves.is_empty():
		_show_pack_result(_use_refusal(&"item_has_no_effect", item), false)
		return
	_mode = Mode.PACK_PP_MOVE
	_pp_item = item
	_pp_party_index = party_index
	_forget_cursor = 0
	_forget_refusal = ""
	_render_hardware()


func _confirm_pp_move() -> void:
	if _forget_cursor < 0 or _forget_cursor >= _forget_moves.size():
		return
	_use_selected_item(
		_pp_party_index, int(_forget_moves[_forget_cursor].get("slot", -1))
	)


## `TossMenu`: the ask, then `SelectQuantityToToss`, which is the same dial the
## mart and Kurt read their joypad through. The ceiling is the stack itself.
func _open_toss_quantity() -> void:
	var item: Dictionary = _selected_item()
	if item.is_empty():
		return
	_mode = Mode.PACK_TOSS_QUANTITY
	_toss_prompt = Gen2WorldQuantityPrompt.open(int(item.get("quantity", 1)))
	_render_toss_quantity()


func _render_toss_quantity() -> void:
	_render_hardware()


## `AskQuantityThrowAwayText` and the `YesNoBox` behind it.
func _open_toss_confirm() -> void:
	if _toss_prompt == null or _selected_item().is_empty():
		return
	_mode = Mode.PACK_TOSS_CONFIRM
	_toss_confirm_cursor = 0
	_render_toss_confirm()


func _render_toss_confirm() -> void:
	_render_hardware()


## `TossItem` and `ThrewAwayText`. The bag host owns the transaction; a refusal
## is reported rather than swallowed, since nothing else here can explain it.
func _confirm_toss() -> void:
	if _toss_confirm_cursor != 0:
		_open_pack_mode(false)
		return
	var item: Dictionary = _selected_item()
	if _world == null or item.is_empty() or _toss_prompt == null:
		_show_pack_result("No world is loaded.", false)
		return
	var result: Dictionary = Gen2WorldBagHost.toss(
		_world, _pack_save, int(item.get("item", 0)), _toss_prompt.value, _pack_persist
	)
	if not bool(result.get("ok", false)):
		_show_pack_result(
			"Could not throw that away (%s)." % String(result.get("reason", "")), false
		)
		return
	## The result box keeps whatever summary the mode before it left, and the
	## question is not it: `ThrewAwayText` is printed under the item's own name.
	_show_pack_result(
		_fill_item_text(_pack_text(TEXT_TOSS_THREW), String(result.get("name", ""))), true
	)


## The dial's own joypad read. Its cancel is `cp -1 / scf`, the same carry
## `TossMenu` treats as "finish", so B goes back to the pocket list.
func _press_toss_quantity(button: int) -> bool:
	if _toss_prompt == null:
		_open_pack_mode(false)
		return true
	match _toss_prompt.press(button):
		Gen2WorldQuantityPrompt.CONFIRMED:
			_open_toss_confirm()
		Gen2WorldQuantityPrompt.CANCELLED:
			_toss_prompt = null
			_open_pack_mode(false)
		_:
			_render_toss_quantity()
	return true


## `_CoinCaseCountText`, whose `text_decimal wCoins, 2, 4` comes back as a
## number marker the count fills. Gold and Silver carry no usable text: theirs
## ends with `done` rather than `text_end`, so `DoTextUntilTerminator` runs off
## `TextCommands` and the cartridge executes whatever follows, which is
## `docs/bugs_and_glitches.md`'s own Coin Case entry. Those two keep the wording.
func _coin_case_text() -> String:
	var text: String = _data.menu_text("coin_case") if _data != null else ""
	if text.is_empty():
		return "Coins:\n%4d" % _coins()
	return Gen2TextStream.fill_marker(
		text, Gen2TextStream.NUMBER_MARKER, "%4d" % _coins()
	)


## `_BlueCardBalanceText`, whose `text_decimal wBlueCardBalance, 1, 2` is the one
## byte [Gen2WorldState] keeps for Buena's points.
func _blue_card_text() -> String:
	var text: String = _data.menu_text("blue_card") if _data != null else ""
	var balance: int = _world.state.blue_card_balance() \
		if _world != null and _world.state != null else 0
	if text.is_empty():
		return "You now have\n%2d points." % balance
	return Gen2TextStream.fill_marker(
		text, Gen2TextStream.NUMBER_MARKER, "%2d" % balance
	)


## `OpenBox`: `SetSpecificDecorationFlag` on the box's own `DECOFLAG_*`, the one
## text, and `UseDisposableItem`. Nothing can refuse it, so the flag is set and
## the box is spent whether or not the trophy was already owned.
func _open_trophy_box(item: int) -> void:
	if _world == null or _world.state == null or _data == null:
		_show_pack_result("No world is loaded.", false)
		return
	Gen2WorldDecoration.set_owned_by_flag(
		_data, _world.state, int(Gen2WorldPack.TROPHY_BOXES[item])
	)
	if _world.inventory != null:
		_world.inventory.change_item_quantity(item, -1)
	_show_pack_result(_trophy_text(), true)


## `_SentTrophyHomeText`, whose second paragraph names `wPlayerName`.
func _trophy_text() -> String:
	var text: String = _data.menu_text("sent_trophy_home") if _data != null else ""
	if text.is_empty():
		return "There was a trophy\ninside!"
	return Gen2TextStream.fill_all_markers(
		text, Gen2TextStream.RAM_MARKER,
		_pack_save.player_name if _pack_save != null else ""
	)


## `wCoins`, which only the Coin Case reads here.
func _coins() -> int:
	return _world.state.coins() if _world != null and _world.state != null else 0


## One of the pack's own texts, imported when the cache carries it. The source's
## own line breaks are kept: these boxes are the hardware's now, and a break is
## where the cartridge ended the row.
func _pack_text(key: String) -> String:
	var text: String = _data.menu_text(key) if _data != null else ""
	if text.is_empty():
		text = String(TEXT_FALLBACKS.get(key, ""))
	return text


## `Pack_GetItemName` fills wStringBuffer2 and the dial owns wItemQuantityChange,
## so a text's one name slot and one number slot are these two. Filled by
## position: the address inside a marker is the profile's own WRAM.
func _fill_item_text(text: String, item_name: String, quantity: int = -1) -> String:
	var out: String = text
	if quantity >= 0:
		out = Gen2TextStream.fill_marker(
			out, Gen2TextStream.NUMBER_MARKER, str(quantity)
		)
	return Gen2TextStream.fill_marker(out, Gen2TextStream.RAM_MARKER, item_name)


func _show_pack_result(message: String, ok: bool, next: Callable = Callable()) -> void:
	_mode = Mode.PACK_RESULT
	_pack_result_next = next
	_pack_result = message
	_pack_result_ok = ok
	_pack_result_pages = Gen2TextLayout.lay_out(
		message, Gen2PackPage.TEXTBOX_COLUMNS - 2, Gen2PackPage.TEXTBOX_ROWS_OF_TEXT
	)
	_pack_result_page = 0
	_render_pack_result()


## The box's last page handing back to whatever queued work is left, which is
## how an evolution's move offers follow its own two lines.
func _pack_result_continued() -> bool:
	if not _pack_result_next.is_valid():
		return false
	var next: Callable = _pack_result_next
	_pack_result_next = Callable()
	next.call()
	return true


## `PrintText`'s own wait: a result that runs past the box's two rows is pressed
## through page by page before the pack comes back.
func _pack_result_advanced() -> bool:
	if _pack_result_page + 1 >= _pack_result_pages.size():
		return false
	_pack_result_page += 1
	_render_pack_result()
	return true


func _render_pack_result() -> void:
	_render_hardware()


## `SaveMenu`'s first question. `LoadStandardMenuHeader` and
## `DisplaySaveInfoOnSave` put the info box up before it, and both stay up for
## every mode below. [Gen2SavePrompt] is the sequence; this draws its box.
func _open_save_confirm_mode() -> void:
	_save_prompt = Gen2SavePrompt.open(
		Gen2SavePrompt.Kind.MENU,
		_pack_save.player_name if _pack_save != null else "",
		_save_action
	)
	_sync_save_prompt()


func _sync_save_prompt() -> void:
	if _save_prompt == null:
		return
	if _save_prompt.refused():
		## `.refused`'s carry, which `StartMenu_Save` answers with 0.
		_save_prompt = null
		_open_list_mode()
		return
	if _save_prompt.finished():
		## `StartMenu_Save`'s `ld a, 1`, `StartMenu`'s exit and not `.Reopen`.
		_save_prompt = null
		closed.emit()
		return
	if _save_prompt.sfx_owed():
		## `SavedTheGame` reaches it through `WaitPlaySFX`; the wait behind it is
		## not spent, for the reason the intro cry's is not.
		sfx_requested.emit(Gen2SavePrompt.SFX_SAVE, true)
	_mode = SAVE_PROMPT_MODES[_save_prompt.step]
	_save_lines = _save_prompt.lines.duplicate()
	_save_line = _save_prompt.line
	_save_cursor = _save_prompt.cursor
	_save_frames = _save_prompt.frames
	_render_save()


## The yes/no's own cursor, `YesNoMenuHeader`'s `db 1` default, and the words
## the box holds. [param cursor_index] below zero is a mode with no box at all.
func _enter_save_mode(mode: Mode, lines: Array, cursor_index: int) -> void:
	_save_prompt = null
	_mode = mode
	_save_lines = lines.duplicate()
	_save_line = 0
	_save_cursor = cursor_index
	_save_frames = 0
	_render_save()


func _confirm_save() -> void:
	match _mode:
		## `.refused` on NO, which is the carry `StartMenu_Save` answers with 0:
		## back to the list rather than out of the menu.
		## `StartMenu_Quit`'s `jr c, .DontEndContest`, which is the same 0 the
		## save question answers NO with: back to the list. YES queues
		## `BugCatchingContestReturnToGateScript`, which is the world's.
		Mode.QUIT_ASK:
			if _save_cursor == 1:
				_open_list_mode()
			else:
				action_chosen.emit(Gen2WorldStartMenu.ITEM_QUIT, &"")
		## NO goes back to the list the row was chosen from, the same as every
		## other question here. YES is the world's: only the screen hosting this
		## one can put the launcher back.
		Mode.LAUNCHER_ASK:
			if _save_cursor == 1:
				_open_list_mode()
			else:
				action_chosen.emit(Gen2WorldStartMenu.ITEM_LAUNCHER, &"")
		## The chord opened this menu with nothing else to do, so both answers
		## close it. Either one is also the acknowledgement: the player now knows
		## the shortcut is there, and it is never asked again.
		Mode.RESET_ASK:
			## `_ContText`'s own `PromptButton` before the third line, the way
			## the overwrite question reads its own.
			if _save_cursor < 0:
				_save_line = 1
				_save_cursor = 0
				_render_save()
				return
			_acknowledge_reset()
			if _save_cursor == 1:
				closed.emit()
			else:
				soft_reset_confirmed.emit()
		## `SavingDontTurnOffThePower` zeroes the joypad bytes before it prints,
		## and the prompt refuses a button on both timed steps.
		Mode.SAVE_ASK, Mode.SAVE_OVERWRITE, Mode.SAVE_SAVING, Mode.SAVE_SAVED, \
		Mode.SAVE_FAILED:
			if _save_prompt != null:
				_save_prompt.confirm(_save_cursor == 0)
				_sync_save_prompt()


## B is `YesNoBox`'s no wherever a question is up, and `PromptButton`'s other
## button while the text still has a line to come. The two timed modes read no
## joypad at all.
func _cancel_save() -> void:
	if _save_prompt != null:
		_save_prompt.cancel()
		_sync_save_prompt()
	elif _save_cursor < 0 and _mode == Mode.RESET_ASK:
		_confirm_save()
	elif _mode == Mode.RESET_ASK:
		## B is `YesNoBox`'s NO, and the menu was opened for the question alone.
		_acknowledge_reset()
		closed.emit()
	elif _save_cursor >= 0:
		_open_list_mode()


## The reset chord has now been used once, so the question is never asked again.
## Written whichever way it was answered: what the box is for is telling the
## player the shortcut exists, and it has done that either way.
func _acknowledge_reset() -> void:
	var options: Gen2Options = Gen2OptionsStore.current()
	if options.soft_reset_acknowledged:
		return
	options.soft_reset_acknowledged = true
	Gen2OptionsStore.save(options)


## Opens the reset chord's own question over whatever this menu was showing. The
## world calls it instead of a row being chosen, so the list behind it is never
## the thing the player is answering about.
func ask_soft_reset() -> void:
	_enter_save_mode(Mode.RESET_ASK, RESET_ASK_LINES, -1)


## One hardware frame of the two timed modes. Public so a test or a preview owns
## its own frames rather than sampling a screen mid-flight.
func advance_save_frame() -> void:
	if _save_prompt == null:
		return
	_save_prompt.frame()
	_sync_save_prompt()


func advance_save_frames(count: int) -> void:
	for _step: int in count:
		advance_save_frame()


func _process(delta: float) -> void:
	if _mode == Mode.PACK_TARGET:
		for _frame: int in _target_clock.tick(delta):
			advance_target_icons()
		return
	_target_clock.reset()
	if _mode != Mode.SAVE_SAVING and _mode != Mode.SAVE_SAVED:
		_save_clock.reset()
		return
	for _frame: int in _save_clock.tick(delta):
		advance_save_frame()


## `DisplaySaveInfoOnSave`'s four rows: the same fields [Gen2TrainerCard]'s
## first page reads, with `Continue_DisplayBadgeCount`'s popcount over both
## badge bytes beside them.
func _save_state() -> Dictionary:
	var state: Gen2WorldState = _world.state if _world != null else null
	var time: Gen2GameTime = _pack_save.game_time \
		if _pack_save != null and _pack_save.game_time != null else Gen2GameTime.new()
	var crystal: bool = Gen2WorldState.is_crystal_profile(_data)
	return {
		"player_name": _pack_save.player_name if _pack_save != null else "",
		"badges": state.badge_count(crystal) if state != null else 0,
		"pokedex": state != null and state.is_engine_flag_active(
			Gen2WorldStartMenu.ENGINE_POKEDEX
		),
		"caught": state.caught_count() if state != null else 0,
		"hours": time.hours,
		"minutes": time.minutes,
		"lines": _save_lines,
		"line": _save_line,
		"cursor": _save_cursor,
	}


func _render_save() -> void:
	_render_hardware()


## The screen `StartMenu`'s own box is drawn into. The world hands over the one
## the map is already in, so the box stands over it the way the map name sign
## does.
func set_screen(screen: Gen2Screen) -> void:
	_screen = screen
	if _screen == null or _view != null:
		return
	_view = TextureRect.new()
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_view.size = Vector2(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.display(_view)
	_render_hardware()


## Frees the overlay, since it lives in a screen this node does not own.
func _exit_tree() -> void:
	if _view != null:
		Gen2Screen.drop_on_exit(_view)
		_view = null
	if _naming != null:
		Gen2Screen.drop_on_exit(_naming)
		_naming = null


## `StartMenu`'s own list, which is the picture behind every question asked off
## a row of it.
func _list_image() -> Image:
	if _menu == null or _page == null:
		return null
	var contest: bool = _world != null and _world.bug_contest_active()
	var shown: int = Gen2StartMenuPage.visible_rows(contest)
	var labels: Array = []
	for entry: Variant in _menu.items():
		labels.append(String((entry as Dictionary).get("label", "")))
	## `.PrintMenuAccount` reads the option on every cursor move, so turning MENU
	## ACCOUNT off takes the block away at once.
	var description: String = _menu.selected_description() \
		if Gen2OptionsStore.current().menu_account else ""
	return _page.render_list(
		labels.slice(_list_scroll, _list_scroll + shown),
		_menu.cursor - _list_scroll, description, contest, null,
		_contest_status() if contest else {}
	)


## Whichever of the cartridge's screens this mode is. `_hardware_image()` answers
## every one of them, so there is no window-resolution fallback behind it.
func _render_hardware() -> void:
	if _view == null:
		return
	var image: Image = _hardware_image()
	_view.visible = image != null
	if image == null:
		return
	Gen2PicImage.show(_view, image)


## The words this mode's own box prints, which is what [method _hardware_image]
## hands the page. One reading, so a caller can have the box without the pixels.
func box_text() -> String:
	match _mode:
		Mode.PACK_ITEM:
			return _pack_description()
		Mode.PACK_TEACH:
			return String(_teach_prompt.get("text", ""))
		Mode.PACK_FORGET_ASK:
			return Gen2MoveForget.ask_text(
				_target_name(_forget_party_index), _forget_move_name
			)
		Mode.PACK_STOP_LEARNING:
			return Gen2MoveForget.stop_text(_forget_move_name)
		Mode.PACK_TOSS_CONFIRM:
			return _fill_item_text(
				_pack_text(TEXT_TOSS_ASK_QUANTITY),
				String(_selected_item().get("name", "")),
				_toss_prompt.value if _toss_prompt != null else 1
			)
		Mode.PACK_GIVE_SWAP:
			return _swap_question
		Mode.PACK_TOSS_QUANTITY:
			return _pack_text(TEXT_TOSS_ASK)
		Mode.PACK_FORGET:
			return _forget_refusal if not _forget_refusal.is_empty() \
				else Gen2MoveForget.which_text()
		Mode.PACK_PP_MOVE:
			return RESTORE_PP_WHICH_MOVE
		Mode.PACK_RESULT:
			return _pack_result_text()
	return ""


func _hardware_image() -> Image:
	if _data == null:
		return null
	if _page == null:
		_page = Gen2StartMenuPage.from_data(_data)
	if _page == null:
		return null
	match _mode:
		Mode.LIST:
			return _list_image()
		Mode.SAVE_ASK, Mode.SAVE_OVERWRITE, Mode.SAVE_SAVING, Mode.SAVE_SAVED, \
		Mode.SAVE_FAILED:
			return _page.render_save(_save_state())
		## `StartMenu_Quit` and the two rows this port added below it ask over the
		## list they were chosen from. Only `SaveMenu` puts up
		## `Continue_LoadMenuHeader`'s panel of badges, Pokedex and play time,
		## because only the save question is about the file.
		Mode.QUIT_ASK, Mode.LAUNCHER_ASK, Mode.RESET_ASK:
			return _page.render_save(_save_state(), _list_image())
		Mode.OPTIONS:
			return _options_image()
		Mode.PACK:
			return _pack_image()
		Mode.PACK_ITEM:
			return _item_menu_image()
		Mode.PACK_TEACH, Mode.PACK_FORGET_ASK, Mode.PACK_STOP_LEARNING, \
		Mode.PACK_TOSS_CONFIRM, Mode.PACK_GIVE_SWAP:
			return _pack_yes_no(box_text(), int(get(TOGGLE_MODES[_mode][0])))
		Mode.PACK_TOSS_QUANTITY:
			return _toss_quantity_image()
		Mode.PACK_FORGET, Mode.PACK_PP_MOVE:
			return _move_list_image()
		Mode.PACK_RESULT:
			return _pack_overlay(box_text(), Callable())
		Mode.PACK_TARGET:
			return _target_image()
		Mode.FIELD_MOVES:
			var moves: Array = _field_move_labels()
			return _page.render_list(
				moves, _field_move_cursor, "", false,
				Gen2PartyScreen.mon_menu_box(moves.size())
			)
		Mode.MODS:
			return _mod_rows_image()
		Mode.MOD_OPTIONS:
			return _mod_options_image()
	return null


func _options_image() -> Image:
	if _options_menu == null:
		return null
	return _page.render_options(_options_menu.rows(), _options_menu.cursor)


func _item_menu_image() -> Image:
	var labels: Array = []
	for entry: Dictionary in _item_actions:
		labels.append(String(entry.get("label", "")))
	return _pack_overlay(box_text(), func(map: PackedInt32Array) -> void:
		_pack_page.draw_menu(map, _item_menu_box(labels.size()), labels, _item_cursor)
	)


func _toss_quantity_image() -> Image:
	return _pack_overlay(box_text(), func(map: PackedInt32Array) -> void:
		_pack_page.draw_quantity(
			map,
			Gen2MenuBox.from_coords(
				TOSS_QUANTITY_AT.x, TOSS_QUANTITY_AT.y,
				TOSS_QUANTITY_TO.x, TOSS_QUANTITY_TO.y, 0
			),
			_toss_prompt.value if _toss_prompt != null else 1
		)
	)


func _move_list_image() -> Image:
	var moves: Array = []
	for entry: Dictionary in _forget_moves:
		moves.append(String(entry.get("name", "")))
	return _pack_overlay(
		box_text(), func(map: PackedInt32Array) -> void:
			_pack_page.draw_move_list(map, moves, _forget_cursor)
	)


func _target_image() -> Image:
	if _party_menu_page() == null:
		return null
	return _target_page.render(_party_targets(), _target_cursor, _target_prompt())


func _mod_rows_image() -> Image:
	var rows: Array = []
	for row: Dictionary in _mod_rows():
		if StringName(row["kind"]) == MOD_ROW_VIEW:
			var host: Gen2ModHost = Gen2ModHost.instance()
			rows.append({"label": "VIEW", "value": host.view_label(host.selected_view())})
			continue
		rows.append({"label": _mod_name(StringName(row["id"])), "value": ""})
	var window: Dictionary = _option_window(rows, _mod_cursor)
	return _page.render_options(window["rows"], window["cursor"])


func _mod_options_image() -> Image:
	var rows: Array = []
	for raw: Dictionary in _mod_options():
		rows.append({
			"label": String(raw.get("label", "")), "value": _mod_option_value(raw),
		})
	var window: Dictionary = _option_window(
		rows, _mod_option_cursor, Gen2StartMenuPage.OPTIONS_VISIBLE_VALUE_ROWS
	)
	return _page.render_options(window["rows"], window["cursor"])


func _mod_option_value(raw: Dictionary) -> String:
	match StringName(raw.get("kind", Gen2ModHost.OPTION_LADDER)):
		Gen2ModHost.OPTION_BUTTON:
			return String(raw.get("press_label", "Go"))
		Gen2ModHost.OPTION_NUMBER:
			return str(int(raw.get("value", 0)))
	var labels: Array = raw.get("labels", []) as Array
	var index: int = int(raw.get("index", 0))
	return String(labels[index]) if index >= 0 and index < labels.size() else ''

## Keeps the active global row on the hardware page. Input and mutations retain
## the global cursor; only the rows handed to the page move.
func _option_window(
	rows: Array, cursor_index: int,
	visible_rows: int = Gen2StartMenuPage.OPTIONS_VISIBLE_ROWS
) -> Dictionary:
	var first: int = clampi(
		cursor_index - visible_rows + 1,
		0, maxi(rows.size() - visible_rows, 0)
	)
	var last: int = mini(first + visible_rows, rows.size())
	return {
		"rows": rows.slice(first, last),
		"cursor": cursor_index - first if cursor_index >= 0 else -1,
	}
