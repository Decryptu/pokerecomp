class_name Gen2WorldServiceScreen
extends Control

## Presentation host for imported overworld services. It owns only selection,
## labels and input. Script state and transactions stay in the scene-free world
## hosts and API.

signal completed(results: Array)
## The sound this screen asks for, played by whoever owns the driver.
##
## Nothing here reaches [Gen2AudioPlayer]: the world screen owns the one player
## a map's music and its effects share, so a second surface asking for a sound
## goes through it the way the start menu, the party screen and the move screen
## already do. [Gen2WorldAudioHost] is an inspection probe that renders no
## samples and must never stand in for it.
##
## [param waited] is `WaitPlaySFX`, or a `WaitSFX` spent in front of the sound
## by hand: the cartridge holds there until the four effect channels are free,
## so the request can never be the one `PlaySFX`'s own priority gate refuses.
## The wait itself is not spent; what it carries is that the sound is heard.
signal sfx_requested(index: int, waited: bool)
## `PlayMonCry2` from a screen this one opens, the box screen's stats page today.
## Passed on for the same reason [signal sfx_requested] is: the world screen owns
## the one player.
signal cry_requested(species: int)

enum MODE {
	MENU, MART, PHONE, TOWN_MAP, CARD,
	APRICORN, PC, PC_ITEMS, PC_ITEM_LIST, PC_TEXT, MOM_BANK,
	PC_BOXES, PC_BOX_LIST,
	PC_DECO, PC_DECO_LIST, PC_DECO_SIDE,
	PC_BOX_SUBMENU,
	PC_MAILBOX, PC_MAIL_SUBMENU, PC_MAIL_CONFIRM,
	ELEVATOR,
}

## `ElevatorFloorNames`, in `FLOOR_*` order (constants/script_constants.asm).
const FLOOR_NAMES: Array[String] = [
	"B4F", "B3F", "B2F", "B1F", "1F", "2F", "3F", "4F", "5F", "6F",
	"7F", "8F", "9F", "10F", "11F", "ROOF",
]
## `Elevator_MenuData`'s `db 4, 0`: four rows of floors are shown at a time.
const ELEVATOR_ROWS: int = 4

## `PokemonCenterPC`'s own box storage, which is the one row that opens a screen
## rather than a list. It is added as a child the way the MAP card adds the
## region map, so the top menu is still there when the box screen closes.
const BOX_SCENE := preload("res://game/save/box_screen.tscn")
## `.AttachMail`'s own `PartyMenuSelect`, which is the same list the day care
## and the move tutor open.
const PARTY_SCENE: PackedScene = preload("res://game/save/party_screen.tscn")

## `wPokegearRadioMusicPlaying`, which is what `ExitPokegearRadio_HandleMusic`
## branches on: zero while nothing in this overlay has touched the music, and
## one of the source's own two values once the radio card has.
const RADIO_MUSIC_SILENT: int = 0
const RADIO_MUSIC_RESTART_MAP: int = 0xFE
const RADIO_MUSIC_ENTER_MAP: int = 0xFF

const WorldMenu := preload("res://game/world/world_menu.gd")

## `BuyMenuLoop`'s four states: the list `ScrollingMenu` runs, the quantity
## `SelectQuantityToBuy` asks for, `MartConfirmPurchase`'s yes/no, and a box
## waiting on `JoyWaitAorB`.
const MART_LIST: StringName = &"list"
const MART_QUANTITY: StringName = &"quantity"
const MART_CONFIRM: StringName = &"confirm"
const MART_MESSAGE: StringName = &"message"
## `StandardMart`'s own jumptable, which only `MartDialog` runs: the BUY/SELL/QUIT
## menu and the three states `SellMenu` adds behind its SELL row. The other four
## shop types open `BuyMenu` and nothing else.
const MART_TOP: StringName = &"top"
const MART_SELL: StringName = &"sell"
const MART_SELL_QUANTITY: StringName = &"sell_quantity"
const MART_SELL_CONFIRM: StringName = &"sell_confirm"
const MART_SELL_STAGES: Array[StringName] = [
	MART_SELL, MART_SELL_QUANTITY, MART_SELL_CONFIRM,
]
## `MenuHeader_BuySell`'s three rows, inline in `engine/items/mart.asm` and
## reached by no script, so they are this screen's the way [Gen2WorldPC]'s
## BILL'S PC rows are.
const MART_TOP_ROWS: Array[String] = ["BUY", "SELL", "QUIT"]
const MART_TOP_BUY: int = 0
const MART_TOP_SELL: int = 1
const MART_TOP_QUIT: int = 2
## Which of `GetMartDialogGroup.MartTextFunctionPointers`' groups a variant
## reads. The rooftop sale takes the standard group, which is why it has no
## prefix of its own; the bargain shop's `MARTTEXT_HOW_MANY` slot is
## `BuyMenuLoop` rather than a text, so it asks no quantity.
const MART_TEXT_PREFIX: Dictionary = {
	&"standard": "", &"bitter": "bitter_", &"bargain": "bargain_",
	&"pharmacy": "pharmacy_", &"rooftop_mart_1": "", &"rooftop_mart_2": "",
}
## `PlayTransactionSound`, once the money has been taken.
const SFX_TRANSACTION: int = 0x22

## `PC_PlaySwapItemsSound`, which asks for the same effect twice through
## `WaitPlaySFX`. Hexadecimal, the way `constants/sfx_constants.asm` counts.
const SFX_SWITCH_POKEMON: int = 0x20
## `BillsPC_PlaceEmptyBoxString_SFX`'s own `SFX_WRONG`.
const SFX_WRONG: int = 0x19
## `PokegearPhone_MakePhoneCall`'s own `SFX_CALL`, and the `SFX_NO_SIGNAL`
## `Phone_NoSignal` answers a map with no service with.
const SFX_CALL: int = 0x6A
const SFX_NO_SIGNAL: int = 0x6C

## `BillsPC_ChangeBoxSubmenu.MenuData`'s four rows, inline in `bills_pc.asm` and
## reached by no script, so they are this screen's the way the machine's own top
## menu is.
const BOX_SUBMENU_SWITCH: int = 0
const BOX_SUBMENU_NAME: int = 1
const BOX_SUBMENU_PRINT: int = 2
const BOX_SUBMENU_QUIT: int = 3
const BOX_SUBMENU_ROWS: Array[String] = ["SWITCH", "NAME", "PRINT", "QUIT"]
## `.NoMonString`, and `PrintPCBox` behind PRINT: with nothing on the link
## `CheckPrinterStatus` leaves `wPrinterHandshake` at -1, which is the same
## PRINTER_ERROR_2 the diploma and the Unown printer answer with.
const BOX_EMPTY_TEXT: String = "There's no #MON."
## `Textbox`'s interior, which is what a mart box's words are wrapped to.
const MART_TEXT_COLUMNS: int = 18
const MART_TEXT_ROWS: int = 2
## `hMoneyTemp` is HRAM and `wItemQuantityChange` is not, which is how a
## `text_decimal` marker says which of the two numbers it wants.
const HRAM_FIRST: int = 0xFF00

var _world: Gen2WorldAPI = null
var _data: GameData = null
var _save: Gen2SaveData = null
var _persist: bool = false
var _request: Dictionary = {}
var _resolved: Dictionary = {}
var _mode: int = -1
var _choices: Array = []
var _menu_input: Dictionary = {}
var _menu: Gen2WorldMenu = null
var _cursor: int = 0
var _mart: Dictionary = {}
var _mart_entries: Array = []
var _mart_quantity: int = 1
var _mart_purchased: bool = false
## `BuyMenu`'s own layer, which owns all 160x144 the way the region map does: the
## scrolling list's own scroll and cursor, which of `BuyMenuLoop`'s four states
## it is in, and the boxes waiting on a press.
var _mart_view: TextureRect = null
var _mart_page: Gen2MartPage = null
var _mart_menu_page: Gen2MenuPage = null
var _mart_stage: StringName = MART_LIST
var _mart_scroll: int = 0
var _mart_pages: Array = []
var _mart_after: StringName = MART_LIST
var _mart_confirm: int = 0
## `SellMenu`'s own list, which is the pack rather than the shop's stock.
var _mart_sell_entries: Array = []
var _mart_top: int = MART_TOP_BUY
## `wCurElevatorFloors` and `wElevatorOriginFloor`: the list the host resolved
## and the row `.FindCurrentFloor` matched, plus this screen's own scroll.
var _elevator: Dictionary = {}
var _elevator_scroll: int = 0
var _apricorns: Gen2WorldApricorn = null
var _mom_dial: Gen2WorldMoneyDial = null
## The same counted blink [Gen2TextBox]'s arrow is, since it is the same
## `hVBlankCounter` bit: sixteen frames with the digit and sixteen without.
var _mom_blink: float = 0.0
var _pokegear_cards: Array = []
var _town_map: Gen2TownMapScreen = null
## The clock, phone or radio card while one is open, which is a hardware-
## resolution screen over this panel the way the region map is.
var _pokegear: Gen2PokegearScreen = null
## `wPokegearRadioMusicPlaying`. Only the radio card writes it, so an overlay
## that never opened one leaves the map's own music where it stands.
var _radio_music: int = RADIO_MUSIC_SILENT
## Whether the region map on screen is the fly map, which answers a spawn rather
## than closing the overlay.
var _fly_map: bool = false
var _town_map_from_request: bool = false
## `PokemonCenterPC` and the item PC behind it: which rows are on offer, which
## of the three item lists is open, and the box screen when BILL'S PC is.
var _pc_rows: Array = []
var _pc_house: bool = false
var _pc_action: int = -1
var _pc_entries: Array = []
## `wSwitchItem` less one: the PC row an earlier SELECT marked, or -1 for none.
var _pc_switch: int = -1
var _pc_quantity: int = 1
## The PC's own text boxes and what happens once the last is acknowledged:
## `PROF.OAK'S PC` returns to the top menu and `TURN OFF` shuts the machine down.
var _pc_pages: Array = []
var _pc_sfx: int = -1
var _pc_after: StringName = &"top"
var _pc_label: String = ""
## `_PlayerDecorationMenu`: which category is open, the row waiting on
## `DecoAction_AskWhichSide`, and `wChangedDecorations`, which is what makes the
## machine close so the room can redraw.
var _deco_slot: StringName = &""
var _deco_pending: int = -1
var _deco_changed: bool = false
## Events this screen produced outside the request it is answering, which the
## map's own callbacks are: they belong at the end of the same result list.
var _extra_results: Array = []
var _boxes: Gen2BoxScreen = null
## `_HallOfFamePC`: the records the machine is walking and which one is up.
## `LoadHOFTeam`'s carry is what a record with nothing in it answers, so an
## empty team ends the walk rather than drawing a blank panel.
var _hof: Gen2HallOfFameScreen = null
## `BillsPC_ChangeBoxSubmenu`'s `wMenuSelection`, which is the box the list's
## cursor was on rather than `wCurBox`, and the keyboard its NAME row opens.
var _box_submenu_index: int = 0
var _naming: Gen2NamingScreenScreen = null
var _hof_index: int = 0
## `MailboxPC`: `wCurMessageIndex`, the message a submenu is acting on, the
## reader `.ReadMail` opens and the party list `.AttachMail` opens.
var _mail_index: int = 0
var _mail_reader: Gen2MailScreen = null
var _mail_party: Gen2PartyScreen = null
## `_ChangeBox_MenuHeader`'s `db 4, 0`: four rows of a scrolling list, and where
## the window into the fourteen boxes stands.
const BOX_LIST_ROWS: int = 4
## The `db rows` byte of every scrolling menu this screen hosts, which is how
## many of its list a window shows at once. `wMenuScrollPosition` is one value
## here, the way it is one address on the cartridge: only one of these lists is
## ever open.
const SCROLLING_ROWS: Dictionary = {
	MODE.PC_BOX_LIST: BOX_LIST_ROWS,
	## `MailboxPC.TopMenuData`, `.PCItemsMenuData` and
	## `_PlayerDecorationMenu.ScrollingMenuData`.
	MODE.PC_MAILBOX: 4,
	MODE.PC_ITEM_LIST: 4,
	MODE.PC_DECO_LIST: 8,
}
var _pc_scroll: int = 0
## `wCurBox`, which CHANGE BOX writes and both lists read. It is the save's, so
## the box a deposit lands in outlives the machine being switched off.
var _box_index: int = 0
## Whether storage was opened without the Pokemon Center machine around it, so
## its B leaves the host rather than stepping back to a menu. See
## [method open_bills_pc].
var _bills_pc_only: bool = false
## Whether the menu on screen is the host's own question rather than a script's.
## See [method open_prompt].
var _host_prompt: bool = false

## The screen every layer here is drawn in: the one the opener handed over, so
## the menu box stands on the map's own 160x144 rather than beside it.
var _service_hardware: Gen2Screen = null
## Whether the hardware layer holds an image for the mode this host is in, and
## whether a screen of its own is standing over both layers. [method
## _apply_layer_visibility] is what these two decide.
var _service_drawn: bool = false
var _overlay_open: bool = false
var _service_view: TextureRect = null
var _service_page: Gen2WorldServicePage = null
## `SetDayOfWeek`'s own dial, shared with the new game's `InitClock` screen.
var _clock_page: Gen2ClockSetPage = null

var _title: String = ""
var _summary: String = ""
var _status: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()


## The screen this panel's layers are drawn in, handed over before it is added
## to the tree: the world's own, so a `MenuTextbox` over the map is composited
## with the map instead of standing in a screen of its own beside it.
func set_screen(screen: Gen2Screen) -> void:
	_service_hardware = screen


## Both views live in a screen this node may not own, so they go by hand.
func _exit_tree() -> void:
	if _hof != null:
		Gen2Screen.drop_on_exit(_hof)
		_hof = null
	if _mail_reader != null:
		Gen2Screen.drop_on_exit(_mail_reader)
		_mail_reader = null
	if _naming != null:
		Gen2Screen.drop_on_exit(_naming)
		_naming = null
	for view: TextureRect in [_service_view, _mart_view]:
		if view != null:
			Gen2Screen.drop_on_exit(view)
	_service_view = null
	_mart_view = null


## Opens the host for whatever pending input the world currently exposes.
func open_pending(
	world: Gen2WorldAPI,
	data: GameData,
	save: Gen2SaveData = null,
	persist: bool = false
) -> bool:
	_world = world
	_data = data
	_save = save
	_persist = persist
	if _world == null or _data == null:
		_show_error("Service host has no world or cartridge cache.")
		return false
	var input: Dictionary = _world.pending_script_input()
	var input_type: StringName = StringName(input.get("type", &""))
	if input_type in [&"choice", &"menu"]:
		_open_menu(input)
		return true
	var request: Dictionary = _world.pending_runtime_request()
	if request.is_empty():
		_show_error("No pending service request.")
		return false
	_request = request
	if StringName(request.get("kind", &"")) == &"town_map_requested":
		_open_town_map(true)
		return true
	if StringName(request.get("kind", &"")) == &"mom_bank_dial_requested":
		_open_mom_bank(request.get("values", {}))
		return true
	var resolved: Dictionary = Gen2WorldHost.resolve_runtime_request(_world, request)
	if not bool(resolved.get("ok", false)):
		_show_error("Service unavailable: %s" % String(resolved.get("reason", "unknown")))
		return false
	_resolved = resolved
	match StringName(request.get("kind", &"")):
		&"mart_requested":
			_open_mart(resolved.get("data", {}).get("mart", {}))
			return true
		&"phone_call_requested", &"special_phone_call_requested":
			_open_phone(request, resolved.get("data", {}))
			return true
		&"apricorn_selection_requested":
			_open_apricorns()
			return true
		&"elevator_requested":
			_open_elevator(resolved.get("data", {}).get("elevator", {}))
			return true
		&"pc_requested":
			_open_pc(StringName(resolved.get("data", {}).get("pc", {}).get("mode", &"")))
			return true
	_show_error("No scene host for %s." % String(request.get("kind", "request")))
	return false


func is_active() -> bool:
	return _mode >= 0


## Opens the Pokegear straight onto its PHONE card, which is what the overworld's
## own phone shortcut reaches.
func open_phone_list(
	world: Gen2WorldAPI,
	data: GameData,
	save: Gen2SaveData = null,
	persist: bool = false
) -> bool:
	if not _open_pokegear(world, data, save, persist, "Phone"):
		return false
	_open_card(Gen2PokegearScreen.CARD_PHONE)
	return true


## `PokeGear`'s own entrance. `.InitTilemap` writes POKEGEARCARD_CLOCK and
## opens on it: there is no card list on the cartridge, and B on any card is
## that card's own `.quit`, which leaves the Pokegear rather than a list.
func open_pokegear(
	world: Gen2WorldAPI,
	data: GameData,
	save: Gen2SaveData = null,
	persist: bool = false
) -> bool:
	if not _open_pokegear(world, data, save, persist, "Pokegear"):
		return false
	_open_card(Gen2PokegearScreen.CARD_CLOCK)
	return true


## `wPokegearFlags`: which cards the player owns, in the jumptable's own order.
func _open_pokegear(
	world: Gen2WorldAPI, data: GameData, save: Gen2SaveData, persist: bool, label: String
) -> bool:
	_world = world
	_data = data
	_save = save
	_persist = persist
	if _world == null or _data == null:
		_show_error("%s has no world or cartridge cache." % label)
		return false
	_pokegear_cards = Gen2PokegearScreen.owned_cards(_world.state)
	return true


## Parent screens route buttons here so the service overlay owns input while open.
func handle_button(button: int) -> bool:
	if not is_active():
		return false
	if _mode == MODE.APRICORN:
		_press_apricorns(button)
		return true
	if _mode == MODE.ELEVATOR:
		_press_elevator(button)
		return true
	if _mode == MODE.MART:
		_press_mart(button)
		return true
	if _mode == MODE.MOM_BANK:
		_press_mom_bank(button)
		return true
	if _mode == MODE.CARD and _pokegear != null:
		return _pokegear.handle_button(button)
	## The box screen owns all 160x144 while BILL'S PC is open, the way the
	## region map does, so the buttons are its own.
	if _naming != null:
		return _naming.handle_button(button)
	if _hof != null:
		return _hof.handle_button(button)
	if _boxes != null:
		return _boxes.handle_button(button)
	if _mail_reader != null:
		return _mail_reader.handle_button(button)
	if _mail_party != null:
		return _mail_party.handle_button(button)
	if Gen2Button.is_direction(button):
		_move_direction(Gen2Button.vector(button))
		return true
	match button:
		Gen2Button.A:
			_confirm()
			return true
		Gen2Button.B:
			_cancel()
			return true
		Gen2Button.SELECT:
			return _press_pc_item_select()
	return false


## `PCItemsJoypad`'s `.select_1` and `.a_select_2`, which are one press of
## `SwitchItemsInBag` over `wPCItems`. Only the two lists that show the PC's own
## items reach it: a deposit is `DepositSellPack`, whose joypad handler has no
## SELECT in it.
func _press_pc_item_select() -> bool:
	if _mode != MODE.PC_ITEM_LIST \
		or _pc_action == Gen2WorldPC.PLAYERSPCITEM_DEPOSIT_ITEM:
		return false
	_apply_pc_switch_press()
	return true


## One press, the same shape [Gen2StartMenuScreen] gives the pack's own SELECT.
func _apply_pc_switch_press() -> void:
	var order: Array = []
	for entry: Dictionary in _pc_entries:
		order.append(int(entry.get("item", 0)))
	var answer: Dictionary = Gen2WorldPack.switch_items(order, _pc_switch, _cursor)
	var next_order: Array = answer["order"]
	if next_order != order and _world != null:
		Gen2WorldBagHost.reorder(_world, _save, next_order, true)
		_refresh_pc_entries()
		## `PC_PlaySwapItemsSound`, which is the pack's own pair of effects.
		sfx_requested.emit(SFX_SWITCH_POKEMON, true)
		sfx_requested.emit(SFX_SWITCH_POKEMON, true)
	_pc_switch = int(answer["held"])
	_render_rows()


func selected_index() -> int:
	return _cursor


func _build_ui() -> void:
	_service_hardware = Gen2Screen.host_for(self, _service_hardware)
	if _service_hardware == null:
		return
	_service_view = TextureRect.new()
	_service_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_service_view.size = Vector2(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)
	_service_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_service_hardware.display(_service_view)
	_apply_layer_visibility()


## A YES/NO the HOST asks rather than one a script staged: the same
## `Script_yesorno` box in the same place, answered back to whoever opened this
## instead of into the script runner. [method completed] carries one
## `{kind: &"host_choice", choice}` row, choice 0 for YES and 1 for NO, and -1
## when it was cancelled.
func open_prompt(
	world: Gen2WorldAPI,
	data: GameData,
	save: Gen2SaveData,
	persist: bool,
	text: String
) -> bool:
	_world = world
	_data = data
	_save = save
	_persist = persist
	if _world == null or _data == null:
		_show_error("Prompt has no world or cartridge cache.")
		return false
	_host_prompt = true
	_open_menu({"text": text, "choices": Gen2WorldMenu.YES_NO_KEYS})
	return true


## `Elevator_AskWhichFloor`: the floor list in `Elevator_MenuHeader`'s box with
## `Elevator_GetCurrentFloorText`'s own small box beside it. `.LoadPointer` and
## `.FindCurrentFloor` already ran on the host side, so this is the menu alone.
func _open_elevator(elevator: Dictionary) -> void:
	_mode = MODE.ELEVATOR
	_elevator = elevator.duplicate(true)
	_elevator_scroll = 0
	## `ld a, 1` is the header's default option, and `xor a / ld
	## [wMenuScrollPosition], a` puts the window at the top whatever floor the
	## car is on.
	_cursor = 0
	_title = ""
	_status = ""
	_summary = _elevator_prompt()
	_render_elevator()


## `_AskFloorElevatorText`, or this host's own wording on a cache imported
## before the stub was read.
func _elevator_prompt() -> String:
	var line: String = String(_data.special_text("elevator", "which_floor")) \
		if _data != null else ""
	return line if not line.is_empty() else "Which floor?"


func _elevator_floors() -> Array:
	return _elevator.get("floors", [])


static func _floor_name(index: int) -> String:
	return FLOOR_NAMES[index] if index >= 0 and index < FLOOR_NAMES.size() else "?"


func _render_elevator() -> void:
	var rows: Array = []
	var floors: Array = _elevator_floors()
	for row: int in ELEVATOR_ROWS:
		var index: int = _elevator_scroll + row
		if index >= floors.size():
			break
		rows.append(_floor_name(int((floors[index] as Dictionary)["floor"])))
	_render_service_page(rows, _cursor - _elevator_scroll)


func _press_elevator(button: int) -> void:
	var floors: Array = _elevator_floors()
	if button == Gen2Button.B:
		## `.cancel`'s `scf`, which `Script_elevator`'s `ret c` leaves as FALSE.
		_finish_runtime({"ok": true})
		return
	if button == Gen2Button.A:
		if _cursor < 0 or _cursor >= floors.size():
			return
		## `Elevator`'s own `cp [hl] / jr z, .quit`: choosing the floor the car
		## is already on is a cancel, not a ride.
		if _cursor == int(_elevator.get("current", -1)):
			_finish_runtime({"ok": true})
			return
		_finish_runtime({"ok": true, "floor": (floors[_cursor] as Dictionary).duplicate()})
		return
	if button == Gen2Button.UP:
		_cursor = maxi(0, _cursor - 1)
	elif button == Gen2Button.DOWN:
		_cursor = mini(floors.size() - 1, _cursor + 1)
	else:
		return
	_elevator_scroll = clampi(
		_elevator_scroll, maxi(0, _cursor - ELEVATOR_ROWS + 1), _cursor
	)
	_render_elevator()


func _open_menu(input: Dictionary) -> void:
	_mode = MODE.MENU
	_menu_input = input.duplicate(true)
	_menu = WorldMenu.from_input(_menu_input)
	_choices = _menu.options.duplicate(true)
	_cursor = _menu.selected_index()
	_title = "MENU"
	## The question the box behind this menu is still showing. A command name is
	## an internal key, never something the cartridge prints, so it is not a
	## fallback: an unattached menu says nothing rather than saying "yesorno".
	_summary = String(input.get("text", ""))
	_status = ""
	_render_rows()


## `BuyMenu`, which is a screen of its own rather than a box over the map: the
## panel steps aside for it the way it does for the region map, and the shop's
## own intro box is the first thing it prints.
func _open_mart(mart: Dictionary) -> void:
	_mode = MODE.MART
	_mart = mart.duplicate(true)
	for row: Dictionary in Gen2ModHost.instance().mart_entries(_mart):
		(_mart["items"] as Array).append(row)
	_refresh_mart_entries()
	_mart_quantity = 1
	_mart_purchased = false
	_mart_scroll = 0
	_cursor = 0
	_set_overlay_open(true)
	if _mart_view == null and _service_hardware != null:
		_mart_view = TextureRect.new()
		_mart_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_mart_view.size = Vector2(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)
		_mart_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		## Displayed after the panel's own view, which is [method
		## Gen2Screen.display]'s z-order: the shop owns all 160x144 while it is
		## up and the menu behind it is hidden anyway.
		_service_hardware.display(_mart_view)
	_mart_top = MART_TOP_BUY
	_refresh_mart_sell_entries()
	## `.HowMayIHelpYou` prints `MartWelcomeText` and hands the loop to
	## `.TopMenu`; every other shop type prints its own intro over `BuyMenu`.
	_show_mart_text(_mart_text("intro"), MART_TOP if _mart_standard() else MART_LIST)


## Whether this shop is `MartDialog`'s, which is the one that runs
## `StandardMart`'s BUY/SELL/QUIT loop rather than opening `BuyMenu` alone.
func _mart_standard() -> bool:
	return StringName(_mart_source().get("variant", &"")) == &"standard"


## One of the shop's own boxes, by the slot name its group gives it.
func _mart_text(slot: String, filled: Dictionary = {}) -> String:
	var prefix: String = String(MART_TEXT_PREFIX.get(
		StringName(_mart_source().get("variant", &"standard")), ""
	))
	var slot_name: String = prefix + slot
	if slot == "intro" and prefix.is_empty():
		slot_name = "welcome"
	var text: String = _data.mart_text(slot_name)
	if text.is_empty():
		return ""
	return _fill_mart_markers(text, filled)


## `PartyMonItemName` and the two `text_decimal`s a mart box carries. The number
## markers are told apart by their address rather than by their order, since the
## bargain shop names the item first and the price second.
func _fill_mart_markers(text: String, filled: Dictionary) -> String:
	var out: String = Gen2TextStream.fill_marker(
		text, Gen2TextStream.RAM_MARKER, String(filled.get("name", ""))
	)
	while true:
		var at: int = out.find(Gen2TextStream.NUMBER_MARKER)
		if at < 0:
			break
		var end: int = out.find(">", at)
		if end < 0:
			break
		var address: int = out.substr(
			at + Gen2TextStream.NUMBER_MARKER.length(),
			end - at - Gen2TextStream.NUMBER_MARKER.length()
		).hex_to_int()
		out = out.substr(0, at) + String.num_int64(int(filled.get(
			"total" if address >= HRAM_FIRST else "quantity", 0
		))) + out.substr(end + 1)
	return out


## A box the shop is holding on, laid out into the pages `JoyWaitAorB` steps
## through. An empty text goes straight on, which is what a cache imported
## before the mart's own words leaves.
func _show_mart_text(text: String, after: StringName) -> void:
	_mart_after = after
	_mart_pages = [] if text.strip_edges().is_empty() \
		else Gen2TextLayout.lay_out(text, MART_TEXT_COLUMNS, MART_TEXT_ROWS)
	if _mart_pages.is_empty():
		_advance_mart_text()
		return
	_mart_stage = MART_MESSAGE
	_render_mart()


func _advance_mart_text() -> void:
	if not _mart_pages.is_empty():
		_mart_pages.remove_at(0)
	if not _mart_pages.is_empty():
		_render_mart()
		return
	if _mart_after == MART_LIST or _mart_after == MART_TOP or _mart_after == MART_SELL:
		_mart_stage = _mart_after
		_cursor = 0
		if _mart_after == MART_TOP:
			_cursor = _mart_top
		_render_mart()
		return
	_close_mart()
	_finish_runtime({"ok": true, "script_value": 1 if _mart_purchased else 0})


## `w2DMenuNumRows`: the CANCEL row is only on offer when the whole list fits,
## because `ScrollingMenu_InitFlags` adds it to the row count and `.d_down`
## stops scrolling at `size - height`.
func _mart_row_count() -> int:
	var rows: int = _mart_list().size()
	return rows + 1 if rows < Gen2MartPage.LIST_HEIGHT else Gen2MartPage.LIST_HEIGHT


## Whichever of the shop's stock and the player's pack the stage is showing.
func _mart_list() -> Array:
	return _mart_sell_entries if _mart_stage in MART_SELL_STAGES else _mart_entries


func _mart_rows() -> Array:
	var entries: Array = _mart_list()
	var out: Array = []
	for row: int in _mart_row_count():
		var index: int = _mart_scroll + row
		out.append({"cancel": true} if index >= entries.size() else entries[index])
	return out


func _mart_selection() -> Dictionary:
	var entries: Array = _mart_list()
	var index: int = _mart_scroll + _cursor
	return {} if index >= entries.size() else entries[index]


func _press_mart(button: int) -> void:
	match _mart_stage:
		MART_MESSAGE:
			if button in [Gen2Button.A, Gen2Button.B]:
				_advance_mart_text()
		MART_TOP:
			_press_mart_top(button)
		MART_LIST:
			_press_mart_list(button)
		MART_QUANTITY:
			_press_mart_quantity(button)
		MART_CONFIRM:
			_press_mart_confirm(button)
		MART_SELL:
			_press_mart_sell_list(button)
		MART_SELL_QUANTITY:
			_press_mart_sell_quantity(button)
		MART_SELL_CONFIRM:
			_press_mart_sell_confirm(button)


func _press_mart_list(button: int) -> void:
	match button:
		Gen2Button.UP:
			_move_mart_cursor(-1)
		Gen2Button.DOWN:
			_move_mart_cursor(1)
		Gen2Button.B:
			_leave_mart()
		Gen2Button.A:
			var entry: Dictionary = _mart_selection()
			if entry.is_empty():
				_leave_mart()
				return
			if bool(entry.get("sold_out", false)):
				## `BargainShopAskPurchaseQuantity.SoldOut`, the one refusal that
				## comes before a price is ever named.
				_show_mart_text(_mart_text("sold_out", {"name": entry.get("name", "")}), MART_LIST)
				return
			_mart_quantity = 1
			if StringName(_mart_source().get("variant", &"")) == &"bargain":
				_ask_mart_confirm()
				return
			## `MARTTEXT_HOW_MANY` is printed before `SelectQuantityToBuy`, and
			## the box stays up under the dial rather than waiting on a press.
			_mart_pages = Gen2TextLayout.lay_out(
				_mart_text("how_many"), MART_TEXT_COLUMNS, MART_TEXT_ROWS
			)
			_mart_stage = MART_QUANTITY
			_render_mart()


func _move_mart_cursor(delta: int) -> void:
	var rows: int = _mart_row_count()
	var next: int = _cursor + delta
	if next < 0:
		if _mart_scroll > 0:
			_mart_scroll -= 1
	elif next >= rows:
		if _mart_list().size() >= _mart_scroll + Gen2MartPage.LIST_HEIGHT:
			_mart_scroll += 1
	else:
		_cursor = next
	_render_mart()


## `BuySellToss_InterpretJoypad`: one on up and down, ten on left and right,
## against `wItemQuantity`, which `StandardMartAskPurchaseQuantity` sets to the
## whole stack rather than to what the money or the pack allows.
func _press_mart_quantity(button: int) -> void:
	var maximum: int = Gen2WorldMartHost.MAX_ITEM_STACK
	match button:
		Gen2Button.UP:
			_mart_quantity = 1 if _mart_quantity >= maximum else _mart_quantity + 1
		Gen2Button.DOWN:
			_mart_quantity = maximum if _mart_quantity <= 1 else _mart_quantity - 1
		Gen2Button.RIGHT:
			_mart_quantity = mini(_mart_quantity + 10, maximum)
		Gen2Button.LEFT:
			_mart_quantity = maxi(_mart_quantity - 10, 1)
		Gen2Button.B:
			_mart_stage = MART_LIST
		Gen2Button.A:
			_ask_mart_confirm()
			return
	_render_mart()


## `MartConfirmPurchase`: the price box and the yes/no over it.
func _ask_mart_confirm() -> void:
	var entry: Dictionary = _mart_selection()
	_mart_confirm = 0
	_mart_stage = MART_CONFIRM
	_mart_pages = Gen2TextLayout.lay_out(
		_mart_text("final_price", {
			"name": entry.get("name", ""),
			"quantity": _mart_quantity,
			"total": int(entry.get("price", 0)) * _mart_quantity,
		}),
		MART_TEXT_COLUMNS, MART_TEXT_ROWS
	)
	_render_mart()


func _press_mart_confirm(button: int) -> void:
	match button:
		Gen2Button.UP, Gen2Button.DOWN:
			_mart_confirm = 1 - _mart_confirm
		Gen2Button.B:
			_mart_stage = MART_LIST
		Gen2Button.A:
			if _mart_confirm == 0:
				_buy_mart_selection()
				return
			_mart_stage = MART_LIST
	_render_mart()


## The transaction itself, and whichever of `BuyMenuLoop`'s three answers it
## earns: too little money, no room in the pack, or the shop's own thanks.
func _buy_mart_selection() -> void:
	var entry: Dictionary = _mart_selection()
	var purchase: Dictionary = Gen2WorldMartHost.purchase(
		_world, _save, _mart_source(), int(entry.get("item", 0)), _mart_quantity, _persist
	)
	if not bool(purchase.get("ok", false)):
		var reason: StringName = StringName(purchase.get("reason", &""))
		var slot: String = {
			&"insufficient_money": "no_money", &"item_stack_full": "pack_full",
			&"bargain_item_sold_out": "sold_out",
		}.get(reason, "")
		if slot.is_empty():
			_status = "Purchase failed: %s" % String(reason)
			_mart_stage = MART_LIST
			_render_mart()
			return
		_show_mart_text(_mart_text(slot, {"name": entry.get("name", "")}), MART_LIST)
		return
	_mart_purchased = true
	## `PlayTransactionSound` is a `WaitSFX` and then the sound.
	sfx_requested.emit(SFX_TRANSACTION, true)
	_refresh_mart_entries()
	_show_mart_text(_mart_text("thanks", {
		"name": purchase.get("name", ""), "quantity": _mart_quantity,
		"total": int(purchase.get("total", 0)),
	}), MART_LIST)


## B off the buy or sell list. `.Buy` and `.Sell` both fall into
## `.AnythingElse`, so a standard shop asks again rather than saying goodbye;
## only `.Quit` and the four single-list shop types print the come-again box.
func _leave_mart() -> void:
	if _mart_standard():
		_show_mart_text(_mart_text("ask_more"), MART_TOP)
		return
	_quit_mart()


func _quit_mart() -> void:
	_show_mart_text(_mart_text("come_again"), &"exit")


## `.TopMenu`'s three rows. `VerticalMenu` answers carry on B, which `.quit`
## takes, so B is QUIT rather than a way back out of the shop.
func _press_mart_top(button: int) -> void:
	match button:
		Gen2Button.UP:
			_cursor = wrapi(_cursor - 1, 0, MART_TOP_ROWS.size())
		Gen2Button.DOWN:
			_cursor = wrapi(_cursor + 1, 0, MART_TOP_ROWS.size())
		Gen2Button.B:
			_quit_mart()
			return
		Gen2Button.A:
			_mart_top = _cursor
			match _cursor:
				MART_TOP_BUY:
					_mart_stage = MART_LIST
					_cursor = 0
					_mart_scroll = 0
				MART_TOP_SELL:
					_open_mart_sell()
					return
				_:
					_quit_mart()
					return
	_render_mart()


## `.Sell`: `DepositSellPack` over the whole pack. A pack with nothing sellable
## in it answers `wPackUsedItem` zero at once, which is `SellMenu.quit`, so the
## shop asks again rather than opening an empty list.
func _open_mart_sell() -> void:
	_refresh_mart_sell_entries()
	if _mart_sell_entries.is_empty():
		_show_mart_text(_mart_text("ask_more"), MART_TOP)
		return
	_mart_stage = MART_SELL
	_cursor = 0
	_mart_scroll = 0
	_mart_quantity = 1
	_render_mart()


## The pack as rows this list can draw, at `GetMartPrice`'s halved price per
## unit. `SellMenu.TryToSellItem` refuses a key item after it is chosen, so the
## row is on offer and the refusal is `MartCantBuyText`.
func _refresh_mart_sell_entries() -> void:
	_mart_sell_entries = []
	for pocket: Dictionary in Gen2WorldPack.build(_data, _world.state):
		for row: Dictionary in pocket.get("items", []):
			var item: int = int(row.get("item", 0))
			_mart_sell_entries.append({
				"item": item,
				"name": String(row.get("name", "")),
				"price": Gen2WorldMartHost.sell_price(_data, item),
				"quantity": int(row.get("quantity", 0)),
			})


func _press_mart_sell_list(button: int) -> void:
	match button:
		Gen2Button.UP:
			_move_mart_cursor(-1)
		Gen2Button.DOWN:
			_move_mart_cursor(1)
		Gen2Button.B:
			_leave_mart()
		Gen2Button.A:
			var entry: Dictionary = _mart_selection()
			if entry.is_empty():
				_leave_mart()
				return
			if not Gen2WorldMartHost.can_sell(_data, int(entry.get("item", 0))):
				## `.try_sell`'s `_CheckTossableItem` refusal, which leaves the
				## list up rather than ending the sale.
				_show_mart_text(_mart_text("cant_buy"), MART_SELL)
				return
			_mart_quantity = 1
			_mart_pages = Gen2TextLayout.lay_out(
				_mart_text("sell_how_many"), MART_TEXT_COLUMNS, MART_TEXT_ROWS
			)
			_mart_stage = MART_SELL_QUANTITY
			_render_mart()


## `Toss_Sell_Loop` is the same dial the purchase uses, bounded by the stack the
## player owns rather than by ninety-nine.
func _press_mart_sell_quantity(button: int) -> void:
	var maximum: int = maxi(1, int(_mart_selection().get("quantity", 1)))
	match button:
		Gen2Button.UP:
			_mart_quantity = 1 if _mart_quantity >= maximum else _mart_quantity + 1
		Gen2Button.DOWN:
			_mart_quantity = maximum if _mart_quantity <= 1 else _mart_quantity - 1
		Gen2Button.RIGHT:
			_mart_quantity = mini(_mart_quantity + 10, maximum)
		Gen2Button.LEFT:
			_mart_quantity = maxi(_mart_quantity - 10, 1)
		Gen2Button.B:
			_mart_stage = MART_SELL
		Gen2Button.A:
			_mart_confirm = 0
			_mart_stage = MART_SELL_CONFIRM
			_mart_pages = Gen2TextLayout.lay_out(
				_mart_text("sell_price", {
					"total": Gen2WorldMartHost.sell_price(
						_data, int(_mart_selection().get("item", 0)), _mart_quantity
					),
					"quantity": _mart_quantity,
				}),
				MART_TEXT_COLUMNS, MART_TEXT_ROWS
			)
	_render_mart()


func _press_mart_sell_confirm(button: int) -> void:
	match button:
		Gen2Button.UP, Gen2Button.DOWN:
			_mart_confirm = 1 - _mart_confirm
		Gen2Button.B:
			_mart_stage = MART_SELL
		Gen2Button.A:
			if _mart_confirm == 0:
				_sell_mart_selection()
				return
			_mart_stage = MART_SELL
	_render_mart()


## The sale itself, and `MartBoughtText` behind it.
func _sell_mart_selection() -> void:
	var entry: Dictionary = _mart_selection()
	var sold: Dictionary = Gen2WorldMartHost.sell(
		_world, _save, int(entry.get("item", 0)), _mart_quantity, _persist
	)
	if not bool(sold.get("ok", false)):
		var reason: StringName = StringName(sold.get("reason", &""))
		if reason == &"item_cannot_be_sold":
			_show_mart_text(_mart_text("cant_buy"), MART_SELL)
			return
		_status = "Sale failed: %s" % String(reason)
		_mart_stage = MART_SELL
		_render_mart()
		return
	sfx_requested.emit(SFX_TRANSACTION, true)
	_refresh_mart_sell_entries()
	_mart_scroll = mini(_mart_scroll, maxi(0, _mart_sell_entries.size() - 1))
	_cursor = mini(_cursor, maxi(0, _mart_sell_entries.size() - _mart_scroll - 1))
	_show_mart_text(
		_mart_text("bought", {
			"name": sold.get("name", ""), "quantity": _mart_quantity,
			"total": int(sold.get("total", 0)),
		}),
		MART_SELL if not _mart_sell_entries.is_empty() else MART_TOP
	)


func _close_mart() -> void:
	if _mart_view != null:
		Gen2Screen.drop(_mart_view)
		_mart_view = null
	_set_overlay_open(false)


func _render_mart() -> void:
	if _mart_view == null or _data == null:
		return
	if _mart_page == null:
		_mart_page = Gen2MartPage.from_data(_data)
	if _mart_page == null:
		return
	var page: PackedStringArray = _mart_pages[0] if not _mart_pages.is_empty() \
		else PackedStringArray()
	var selling: bool = _mart_stage in MART_SELL_STAGES
	var listing: bool = _mart_stage == MART_LIST or _mart_stage == MART_SELL
	var image: Image = _mart_page.render({
		"money": _world.state.money(Gen2WorldMartHost.MONEY_ACCOUNT),
		"rows": _mart_rows(),
		"cursor": _cursor if listing else -1,
		"scrolled": _mart_scroll > 0,
		"text": "\n".join(page) if not listing else _mart_description(),
		## `StandardMartAskPurchaseQuantity` closes the dial with `ExitMenu`
		## before `MartConfirmPurchase` prints, so the box is the quantity
		## stage's alone.
		"quantity": _mart_quantity \
			if _mart_stage == MART_QUANTITY or _mart_stage == MART_SELL_QUANTITY else -1,
		## `DisplaySellingPrice` halves the multiplied total, not each unit's
		## price, so the two subtotals are not the same arithmetic.
		"subtotal": Gen2WorldMartHost.sell_price(
			_data, int(_mart_selection().get("item", 0)), _mart_quantity
		) if selling else int(_mart_selection().get("price", 0)) * _mart_quantity,
	})
	if image == null:
		return
	if _mart_stage == MART_CONFIRM or _mart_stage == MART_SELL_CONFIRM:
		_blend_mart_menu(image, Gen2MenuBox.yes_no(), ["YES", "NO"], _mart_confirm)
	elif _mart_stage == MART_TOP:
		## `MenuHeader_BuySell`'s `menu_coords 0, 0, 7, 8`.
		_blend_mart_menu(
			image,
			Gen2MenuBox.from_coords(0, 0, 7, 8, Gen2MenuBox.STATICMENU_CURSOR),
			MART_TOP_ROWS, _cursor
		)
	Gen2PicImage.show(_mart_view, image)


func _blend_mart_menu(
	image: Image, box: Gen2MenuBox, rows: Array, cursor: int
) -> void:
	if _mart_menu_page == null:
		_mart_menu_page = Gen2MenuPage.from_data(_data)
	if _mart_menu_page == null:
		return
	var menu: Image = _mart_menu_page.render(box, rows, cursor)
	image.blend_rect(
		menu, Rect2i(Vector2i.ZERO, menu.get_size()),
		box.border_position() * Gen2Font.TILE
	)


## `UpdateItemDescription`, which prints nothing for the CANCEL row.
func _mart_description() -> String:
	var entry: Dictionary = _mart_selection()
	if entry.is_empty():
		return ""
	return String(_data.item(int(entry.get("item", 0))).get("description", ""))


## `SelectApricornForKurt`'s two boxes. The model owns both cursors and the loop
## between them, so this only draws whichever one it is on.
func _open_apricorns() -> void:
	_mode = MODE.APRICORN
	_apricorns = Gen2WorldApricorn.open(_world.data, _world.state)
	_title = "APRICORNS"
	if _apricorns.is_done():
		## FindApricornsInBag's own refusal. Kurt only asks with one in the bag,
		## so this is the guard rather than a branch a player reaches.
		_finish_apricorns()
		return
	_render_apricorns()


func _render_apricorns() -> void:
	if _apricorns.phase == Gen2WorldApricorn.SELECT_QUANTITY:
		_cursor = 0
		var chosen: Dictionary = _apricorns.selected_entry()
		_summary = "How many should I make?"
		## `PlaceApricornQuantity` draws the name and `×NN` under it; the
		## ceiling is this host's own, since nothing here draws a bag page.
		_status = "x%d    of %d" % [
			_apricorns.prompt.value, _apricorns.prompt.maximum,
		]
		_render_rows([String(chosen.get("name", ""))])
		return
	_summary = "Which APRICORN should I use?"
	_status = ""
	_render_rows(_apricorn_rows())


## The four-row window the scrolling menu shows, CANCEL included when the list
## is short enough for it. `_cursor` is the row inside that window.
func _apricorn_rows() -> Array:
	var rows: Array = []
	for row: int in _apricorns.rows():
		var index: int = _apricorns.scroll + row
		if index >= _apricorns.entries.size():
			rows.append("CANCEL")
			break
		var entry: Dictionary = _apricorns.entries[index]
		rows.append("%-12s x%2d" % [String(entry.get("name", "")), int(entry.get("quantity", 0))])
	_cursor = _apricorns.cursor_y - 1
	return rows


func _press_apricorns(button: int) -> void:
	_apricorns.press(button)
	if _apricorns.is_done():
		_finish_apricorns()
		return
	_render_apricorns()


func _finish_apricorns() -> void:
	var answer: Dictionary = _apricorns.result()
	_apricorns = null
	_finish_runtime({"ok": true, "item": answer["item"], "quantity": answer["quantity"]})


## `Mom_SetUpDepositMenu` and `Mom_SetUpWithdrawMenu` over
## `Mom_WithdrawDepositMenuJoypad`. The model owns the amount and the cursor;
## this owns the box and the blink.
##
## `Mom_Wait10Frames` stands between the box and the joypad so a press that
## opened it cannot be read as a press on it. The world screen spends the press
## that reaches here, so those ten frames are not held: what they are for is
## already true.
func _open_mom_bank(values: Dictionary) -> void:
	_mode = MODE.MOM_BANK
	_mom_dial = Gen2WorldMoneyDial.open(
		StringName(values.get("mode", Gen2WorldMoneyDial.MODE_DEPOSIT)),
		int(values.get("saved", 0)), int(values.get("held", 0))
	)
	_mom_blink = 0.0
	_title = "MOM"
	_summary = ""
	_status = ""
	set_process(true)
	_render_rows()


func _press_mom_bank(button: int) -> void:
	if _mom_dial == null:
		_finish_mom_bank(-1)
		return
	match _mom_dial.press(button):
		Gen2WorldMoneyDial.CONFIRMED:
			_finish_mom_bank(_mom_dial.value)
		Gen2WorldMoneyDial.CANCELLED:
			_finish_mom_bank(-1)
		_:
			_render_rows()


func _finish_mom_bank(amount: int) -> void:
	_mom_dial = null
	set_process(false)
	_finish_runtime({"ok": true, "amount": amount})


## The digit under the cursor is drawn for sixteen frames in every thirty-two,
## so only a crossing of the half period is redrawn.
func _process(_delta: float) -> void:
	if _mode != MODE.MOM_BANK or _mom_dial == null:
		return
	var was_up: bool = _mom_cursor_up()
	_mom_blink = fmod(
		_mom_blink + Gen2TextBox.FRAME_SECONDS,
		Gen2TextBox.FRAME_SECONDS * float(Gen2TextBox.CURSOR_BLINK_FRAMES) * 2.0
	)
	if _mom_cursor_up() != was_up:
		_render_rows()


func _mom_cursor_up() -> bool:
	return _mom_blink < Gen2TextBox.FRAME_SECONDS * float(Gen2TextBox.CURSOR_BLINK_FRAMES)


func _mom_bank_image() -> Image:
	if _mom_dial == null:
		return null
	var drawn: Dictionary = Gen2MartPage.bank_window(
		_data, Gen2WorldMoneyDial.WORD_OF[_mom_dial.mode],
		_mom_dial.saved, _mom_dial.held, _mom_dial.amount_string(),
		_mom_dial.cursor, _mom_cursor_up()
	)
	if drawn.is_empty():
		return null
	var image := Image.create_empty(
		Gen2Screen.WIDTH, Gen2Screen.HEIGHT, false, Image.FORMAT_RGBA8
	)
	var part: Image = drawn["image"]
	image.blit_rect(
		part, Rect2i(Vector2i.ZERO, part.get_size()),
		(drawn["at"] as Vector2i) * Gen2Font.TILE
	)
	return image


## The dial with no script behind it, for the screenshot driver: the routine's
## boxes are the runner's and reach it through `open_pending`, and this is the
## one picture that has to be looked at.
func open_mom_bank(
	world: Gen2WorldAPI, data: GameData, mode: StringName, saved: int, held: int
) -> bool:
	_world = world
	_data = data
	if _world == null or _data == null:
		_show_error("Mom's bank has no world or cartridge cache.")
		return false
	_open_mom_bank({"mode": mode, "saved": saved, "held": held})
	return true


## BILL'S PC on its own, without the machine's top menu in front of it: the
## opening a registered start-menu action asks for. `PC_CheckPartyForPokemon` is
## the same refusal the machine has, applied here rather than trusted.
func open_bills_pc(
	world: Gen2WorldAPI,
	data: GameData,
	save: Gen2SaveData = null,
	persist: bool = false
) -> bool:
	_world = world
	_data = data
	_save = save
	_persist = persist
	if _world == null or _data == null:
		_show_error("Storage has no world or cartridge cache.")
		return false
	if not Gen2WorldPC.can_open(_save):
		_show_error("Storage needs a party.")
		return false
	_bills_pc_only = true
	_open_bills_pc_menu()
	return true


## `special PokemonCenterPC` and `special PlayersHousePC` without a script in
## front of them, for the screenshot drivers: no preview map carries either cell.
func open_pc_machine(
	world: Gen2WorldAPI,
	data: GameData,
	save: Gen2SaveData,
	persist: bool,
	mode: StringName
) -> bool:
	_world = world
	_data = data
	_save = save
	_persist = persist
	if _world == null or _data == null:
		_show_error("The PC has no world or cartridge cache.")
		return false
	if not Gen2WorldPC.can_open(_save):
		_show_error("The PC needs a party.")
		return false
	_open_pc(mode)
	return true


## `BillsPC_SeeYa`, and the `.LogOut` behind it: back to the machine's own top
## menu, or out of the host when nothing opened this but a start-menu action.
func _leave_bills_pc() -> void:
	if _bills_pc_only:
		_finish([])
		return
	_open_pc(&"pokemon_center")


## `PokemonCenterPC`'s top menu, or `_PlayersHousePC`'s item PC when the script
## asked for the bedroom's. `PC_CheckPartyForPokemon` is the one refusal either
## has before it opens.
func _open_pc(mode: StringName) -> void:
	_pc_house = mode == &"players_house"
	if not _pc_house and not Gen2WorldPC.can_open(_save):
		## `.PokecenterPCCantUseText`: the machine answers and shuts down again.
		_finish_runtime({"ok": true, "script_value": 0, "cancelled": true})
		return
	if _pc_house:
		_open_pc_items()
		return
	_mode = MODE.PC
	_cursor = 0
	_pc_rows = Gen2WorldPC.top_menu(
		_data, _world.state, _save.player_name if _save != null else ""
	)
	_title = "PC"
	_summary = _data.pokecenter_pc_text("whose")
	_status = ""
	_render_rows()


## The item PC's own menu. The Pokemon Center's list ends in LOG OFF because the
## top menu is still open behind it; the bedroom's ends in TURN OFF.
func _open_pc_items() -> void:
	_mode = MODE.PC_ITEMS
	_cursor = 0
	_pc_action = -1
	_deco_changed = false
	_pc_rows = Gen2WorldPC.players_pc_menu(_data, _pc_house)
	_title = _data.pokecenter_pc_row("players_pc").replace(
		Gen2WorldPC.PLAYER_MARKER,
		_save.player_name if _save != null and not _save.player_name.is_empty()
		else "PLAYER"
	)
	_summary = _data.pokecenter_pc_text("ask_what_do")
	_refresh_pc_counts()
	_render_rows()


## Whichever of the bag and the PC the chosen action reads.
func _open_pc_item_list(action: int) -> void:
	_pc_action = action
	## `PCItemsJoypad` clears `wSwitchItem` before its loop.
	_pc_switch = -1
	_cursor = 0
	_pc_quantity = 1
	_refresh_pc_entries()
	if _pc_entries.is_empty():
		## `.CheckItemsInBag`'s `.PlayersPCNoItemsText`, which the source prints
		## for a deposit. The other two open an empty scrolling menu there, which
		## can only be cancelled, so they are refused with the same box rather
		## than drawn empty.
		_status = _data.pokecenter_pc_text("no_items")
		_render_rows()
		return
	_mode = MODE.PC_ITEM_LIST
	## `SelectQuantityToToss` is asked before the move, so the box that names it
	## is the list's own prompt here.
	_summary = {
		Gen2WorldPC.PLAYERSPCITEM_WITHDRAW_ITEM: "how_many_withdraw",
		Gen2WorldPC.PLAYERSPCITEM_DEPOSIT_ITEM: "how_many_deposit",
	}.get(action, "")
	_summary = _data.pokecenter_pc_text(_summary) if not _summary.is_empty() \
		else _data.menu_text("toss_ask")
	_render_rows()


func _refresh_pc_entries() -> void:
	_pc_entries = Gen2WorldPC.bag_entries(_data, _world.state) \
		if _pc_action == Gen2WorldPC.PLAYERSPCITEM_DEPOSIT_ITEM \
		else Gen2WorldPC.pc_entries(_data, _world.state)
	_cursor = mini(_cursor, maxi(0, _pc_entries.size() - 1))
	_refresh_pc_counts()


func _refresh_pc_counts() -> void:
	_status = "PC %d/%d stacks" % [
		_world.state.pc_items().size(), Gen2WorldPack.MAX_PC_ITEMS,
	]


func _confirm_pc_row() -> void:
	if _cursor < 0 or _cursor >= _pc_rows.size():
		return
	var row: int = int(_pc_rows[_cursor].get("row", -1))
	if _mode == MODE.PC_BOX_LIST:
		_open_box_submenu(clampi(row, 0, Gen2SaveData.BOX_COUNT - 1))
		return
	if _mode == MODE.PC_BOX_SUBMENU:
		_confirm_box_submenu(row)
		return
	if _mode == MODE.PC_BOXES:
		match row:
			Gen2WorldPC.BILLSPCITEM_WITHDRAW:
				_open_boxes(Gen2BoxScreen.MODE_WITHDRAW)
			Gen2WorldPC.BILLSPCITEM_DEPOSIT:
				_open_boxes(Gen2BoxScreen.MODE_DEPOSIT)
			Gen2WorldPC.BILLSPCITEM_CHANGE_BOX:
				_open_box_list()
			Gen2WorldPC.BILLSPCITEM_MOVE_WITHOUT_MAIL:
				_open_boxes(Gen2BoxScreen.MODE_MOVE)
			Gen2WorldPC.BILLSPCITEM_SEE_YA:
				_leave_bills_pc()
		return
	if _mode == MODE.PC_DECO:
		var slot: StringName = StringName(_pc_rows[_cursor].get("slot", &""))
		if slot.is_empty():
			_leave_decorations()
		else:
			_open_decoration_category(slot)
		return
	if _mode == MODE.PC_DECO_LIST:
		_choose_decoration(int(_pc_rows[_cursor].get("deco", 0)))
		return
	if _mode == MODE.PC_DECO_SIDE:
		var side: StringName = StringName(_pc_rows[_cursor].get("side", &""))
		if side.is_empty():
			_open_decoration_category(_deco_slot)
		else:
			_apply_decoration(_deco_pending, side)
		return
	if _mode == MODE.PC_MAILBOX:
		_open_mail_submenu(row)
		return
	if _mode == MODE.PC_MAIL_SUBMENU:
		_confirm_mail_submenu(row)
		return
	if _mode == MODE.PC_MAIL_CONFIRM:
		_confirm_mail_to_pack(row == 0)
		return
	if _mode == MODE.PC:
		match row:
			Gen2WorldPC.PCPCITEM_BILLS_PC:
				_open_bills_pc_menu()
			Gen2WorldPC.PCPCITEM_PLAYERS_PC:
				_open_pc_items()
			Gen2WorldPC.PCPCITEM_OAKS_PC:
				_open_pc_oak()
			Gen2WorldPC.PCPCITEM_HALL_OF_FAME:
				_open_hall_of_fame(0)
			Gen2WorldPC.PCPCITEM_TURN_OFF:
				## `TurnOffPC` prints before `.shutdown` runs.
				_open_pc_text(
					[_data.pokecenter_pc_text("closed")], &"close", "TURN OFF"
				)
		return
	match row:
		Gen2WorldPC.PLAYERSPCITEM_WITHDRAW_ITEM, \
		Gen2WorldPC.PLAYERSPCITEM_DEPOSIT_ITEM, \
		Gen2WorldPC.PLAYERSPCITEM_TOSS_ITEM:
			_open_pc_item_list(row)
		Gen2WorldPC.PLAYERSPCITEM_MAIL_BOX:
			_open_mailbox()
		Gen2WorldPC.PLAYERSPCITEM_DECORATION:
			_open_decorations()
		Gen2WorldPC.PLAYERSPCITEM_LOG_OFF:
			_open_pc(&"pokemon_center")
		Gen2WorldPC.PLAYERSPCITEM_TURN_OFF:
			_finish_runtime({"ok": true, "script_value": 0})


func _confirm_pc_item() -> void:
	if _cursor < 0 or _cursor >= _pc_entries.size():
		_open_pc_items()
		return
	var entry: Dictionary = _pc_entries[_cursor]
	var item: int = int(entry.get("item", 0))
	var applied: Dictionary = {}
	match _pc_action:
		Gen2WorldPC.PLAYERSPCITEM_WITHDRAW_ITEM:
			applied = Gen2WorldPC.withdraw(_world, _save, item, _pc_quantity, _persist)
		Gen2WorldPC.PLAYERSPCITEM_DEPOSIT_ITEM:
			applied = Gen2WorldPC.deposit(_world, _save, item, _pc_quantity, _persist)
		_:
			applied = Gen2WorldPC.toss(_world, _save, item, _pc_quantity, _persist)
	if not bool(applied.get("ok", false)):
		## `.PackFull` and `.NoRoomInPC` are the two the source has a box for;
		## everything else is a refusal it never reaches.
		var reason: StringName = StringName(applied.get("reason", &""))
		_status = {
			&"pc_full": "no_room_deposit", &"pack_full": "no_room_withdraw",
			&"item_stack_full": "no_room_withdraw",
		}.get(reason, "")
		_status = _data.pokecenter_pc_text(_status) if not _status.is_empty() \
			else "Refused: %s" % String(reason)
		return
	_pc_quantity = 1
	_refresh_pc_entries()
	## `.PlayersPCWithdrewItemsText` and `.PlayersPCDepositItemsText`, whose two
	## markers `PartyMonItemName` and the quantity fill.
	_status = _filled(
		_data.pokecenter_pc_text(
			"withdrew" if _pc_action == Gen2WorldPC.PLAYERSPCITEM_WITHDRAW_ITEM
			else "deposited"
		),
		applied
	) if _pc_action != Gen2WorldPC.PLAYERSPCITEM_TOSS_ITEM else _filled(
		_data.menu_text("toss_threw"), applied
	)
	_render_rows()


## The item name and the quantity into whichever markers the box left for them.
func _filled(text: String, applied: Dictionary) -> String:
	var out: String = Gen2TextStream.fill_marker(
		text, Gen2TextStream.NUMBER_MARKER, String.num_int64(int(applied.get("quantity", 0)))
	)
	return Gen2TextStream.fill_marker(
		out, Gen2TextStream.RAM_MARKER, String(applied.get("name", ""))
	)


func _change_pc_quantity(step: int) -> void:
	if _cursor < 0 or _cursor >= _pc_entries.size():
		return
	var owned: int = int(_pc_entries[_cursor].get("quantity", 1))
	_pc_quantity = clampi(_pc_quantity + step, 1, maxi(1, owned))
	_render_rows()


## `OaksPC`, which prints `ProfOaksPC`'s rating into the PC's own box and
## returns to the loop. A cache with no rating table has nothing to print, which
## is what an empty boot says.
func _open_pc_oak() -> void:
	var boot: Dictionary = Gen2ProfOaksPC.boot(_data, _world.state)
	if boot.is_empty():
		_status = "PROF.OAK'S PC needs a cache that carries its ratings."
		return
	_pc_sfx = int(boot["sfx"])
	_open_pc_text(boot["pages"], &"top", "PROF.OAK'S PC")


## `_PlayerDecorationMenu`'s top menu: only a category the player owns something
## in, and EXIT.
func _open_decorations() -> void:
	_mode = MODE.PC_DECO
	_cursor = 0
	_deco_slot = &""
	_deco_pending = -1
	_pc_rows = Gen2WorldDecoration.categories(_data, _world.state)
	_title = _data.pokecenter_pc_row("decoration", true)
	_summary = ""
	_status = ""
	_render_rows()


## `PopulateDecoCategoryMenu`: the owned rows, the category's own PUT IT AWAY and
## CANCEL, which the ornament list is too long to keep.
func _open_decoration_category(slot: StringName) -> void:
	var rows: Array = Gen2WorldDecoration.category_rows(_data, _world.state, slot)
	if rows.is_empty():
		## `.empty`'s own box. `categories()` drops a category with nothing in
		## it, so this is only reached by a mod's list emptying under the menu.
		_open_pc_text(
			[Gen2WorldDecoration.TEXT_NOTHING_TO_CHOOSE], &"decoration", _title
		)
		return
	_mode = MODE.PC_DECO_LIST
	_cursor = 0
	_deco_slot = slot
	_pc_rows = rows
	_summary = ""
	_status = ""
	_render_rows()


## `DecoAction_AskWhichSide` stands between the ornament category and its action;
## every other category runs straight into `DoDecorationAction2`.
func _choose_decoration(deco: int) -> void:
	if deco <= 0:
		_open_decorations()
		return
	if not Gen2WorldDecoration.asks_side(_data, deco):
		_apply_decoration(deco, &"")
		return
	_mode = MODE.PC_DECO_SIDE
	_cursor = 0
	_deco_pending = deco
	_pc_rows = Gen2WorldDecoration.SIDE_ROWS.duplicate()
	_summary = Gen2WorldDecoration.TEXT_WHICH_SIDE_PUT_AWAY \
		if Gen2WorldDecoration.is_put_away(_data, deco) \
		else Gen2WorldDecoration.TEXT_WHICH_SIDE_PUT_ON
	_status = ""
	_render_rows()


func _apply_decoration(deco: int, side: StringName) -> void:
	var applied: Dictionary = Gen2WorldDecoration.apply(
		_world, _save, deco, side, _persist
	)
	if not bool(applied.get("ok", false)):
		_status = "Refused: %s" % String(applied.get("reason", &""))
		_render_rows()
		return
	_deco_changed = _deco_changed or bool(applied.get("changed", false))
	## `PopulateDecoCategoryMenu` returns to `.top_loop` after one action, so a
	## category list is opened once per visit rather than looped in.
	var text: String = String(applied.get("text", ""))
	if text.is_empty():
		_open_decorations()
		return
	var pages: Array = []
	for page: PackedStringArray in Gen2TextLayout.lay_out(
		text, MART_TEXT_COLUMNS, MART_TEXT_ROWS
	):
		pages.append("\n".join(page))
	_open_pc_text(pages, &"decoration", _title)


## The way out of the decoration menu, which is the way out of the machine once
## anything moved: `ToggleMaptileDecorations` and `ToggleDecorationsVisibility`
## are map callbacks, so the room is only right after they have run again.
func _leave_decorations() -> void:
	if not _deco_changed:
		_open_pc_items()
		return
	_deco_changed = false
	_extra_results = _world.dispatch_callbacks(-1)
	_world.load_object_masks()
	_finish_runtime({"ok": true, "script_value": 0})


## A run of the PC's own boxes, acknowledged one at a time.
func _open_pc_text(pages: Array, after: StringName, label: String) -> void:
	_mode = MODE.PC_TEXT
	_pc_pages = pages.duplicate()
	_pc_after = after
	_cursor = 0
	_pc_label = label
	_show_pc_page()


func _show_pc_page() -> void:
	_summary = String(_pc_pages[0]) if not _pc_pages.is_empty() else ""
	_status = ""
	_render_rows([_pc_label])


## `ProfOaksPCBoot` plays the sound `Rate` chose once the rating is printed, so
## the last page is where it lands.
func _advance_pc_text() -> void:
	if not _pc_pages.is_empty():
		_pc_pages.remove_at(0)
	if not _pc_pages.is_empty():
		_show_pc_page()
		return
	if _pc_sfx >= 0:
		## `ProfOaksPCBoot` waits *behind* its sound, not in front of it.
		sfx_requested.emit(_pc_sfx, false)
	_pc_sfx = -1
	if _pc_after == &"close":
		_finish_runtime({"ok": true, "script_value": 0})
		return
	if _pc_after == &"decoration":
		_open_decorations()
		return
	_open_pc(&"pokemon_center")


## `_BillsPC`, the top menu the two lists and the box picker sit behind.
## `.CheckCanUsePC` is the one refusal it has, and it is the machine's own.
func _open_bills_pc_menu() -> void:
	if not Gen2WorldPC.can_open(_save):
		## `.CheckCanUsePC` prints and returns to `PokemonCenterPC`'s own loop.
		## The start-menu action never reaches this: [method open_bills_pc]
		## refuses the same test before the host is opened at all.
		_open_pc_text([Gen2WorldPC.BILLS_PC_NEEDS_POKEMON], &"top", "BILL's PC")
		return
	_mode = MODE.PC_BOXES
	_cursor = 0
	_box_index = clampi(
		_save.current_box if _save != null else 0, 0, Gen2SaveData.BOX_COUNT - 1
	)
	_pc_rows = Gen2WorldPC.bills_pc_menu()
	_title = _data.pokecenter_pc_row("bills_pc")
	_summary = Gen2WorldPC.BILLS_PC_WHAT
	_status = ""
	_render_rows()


## `_ChangeBox`'s scrolling list: every box by name, with what
## `BillsPC_PrintBoxCountAndCapacity` prints beside the one the cursor is on.
## Choosing one opens `BillsPC_ChangeBoxSubmenu`.
func _open_box_list() -> void:
	_mode = MODE.PC_BOX_LIST
	_cursor = _box_index
	_pc_scroll = clampi(_box_index - BOX_LIST_ROWS + 1, 0, Gen2SaveData.BOX_COUNT - BOX_LIST_ROWS)
	_pc_rows = []
	for index: int in Gen2SaveData.BOX_COUNT:
		_pc_rows.append({
			"row": index,
			"name": _save.box_name(index) if _save != null else "BOX%d" % (index + 1),
		})
	_title = "CHANGE BOX"
	_summary = "Choose a BOX."
	_refresh_box_counts()
	_render_rows()


## `BillsPC_ChangeBoxSubmenu`: the four rows over whichever box the list's own
## cursor was standing on, which is `wMenuSelection`.
func _open_box_submenu(index: int) -> void:
	_mode = MODE.PC_BOX_SUBMENU
	_box_submenu_index = index
	_cursor = BOX_SUBMENU_SWITCH
	_pc_rows = []
	for row: int in BOX_SUBMENU_ROWS.size():
		_pc_rows.append({"row": row, "name": BOX_SUBMENU_ROWS[row]})
	_summary = Gen2WorldPC.BILLS_PC_WHAT
	_status = ""
	_render_rows()


func _confirm_box_submenu(row: int) -> void:
	match row:
		BOX_SUBMENU_SWITCH:
			## `.Switch`: `wCurBox` and nothing else, and the box it is already
			## on is a `ret z` rather than a second save.
			if _box_submenu_index != _box_index:
				_box_index = _box_submenu_index
				if _save != null:
					_save.current_box = _box_index
			_open_box_list()
		BOX_SUBMENU_NAME:
			_open_box_naming()
		BOX_SUBMENU_PRINT:
			_print_box()
		_:
			_open_box_list()


## `.Name`: `NamingScreen` with `NAME_BOX`, whose answer is written back over the
## box's own name. The keyboard is the one the player's name and a nickname use.
func _open_box_naming() -> void:
	if _naming != null or _data == null or _save == null:
		return
	var host := Gen2NamingScreenScreen.new()
	if not host.open(
		_data, _save.box_name(_box_submenu_index),
		Gen2NamingScreenScreen.KIND_BOX
	):
		host.free()
		_status = "The naming keyboard is not in this cache."
		_render_rows()
		return
	_naming = host
	_set_overlay_open(true)
	host.z_index = 5
	host.closed.connect(_on_box_named)
	_service_hardware.display(host)


## `.Name`'s tail: whatever `NamingScreen_StoreEntry` left is written straight
## back over the box's name, and an empty entry is the default name again rather
## than a blank label.
func _on_box_named(entered: String) -> void:
	if _naming != null:
		Gen2Screen.drop(_naming)
		_naming = null
	_set_overlay_open(false)
	if _save != null:
		_save.set_box_name(_box_submenu_index, entered)
	_open_box_list()


## `.Print`: `GetBoxCount` first, and then `PrintPCBox` over the box's own mons.
## There is no printer on the link, so the send answers the same PRINTER_ERROR_2
## the diploma and the Unown printer do.
func _print_box() -> void:
	var box: Gen2SaveBox = _save.boxes[_box_submenu_index] if _save != null \
		and _box_submenu_index < _save.boxes.size() else null
	if box == null or box.occupied_count() <= 0:
		sfx_requested.emit(SFX_WRONG, true)
		_status = BOX_EMPTY_TEXT
		_render_rows()
		return
	_status = _data.printer_status_string(Gen2DiplomaScreen.STATUS_CONNECTION_ERROR)
	_render_rows()


## `GetBoxCount` for the row the cursor stands on, over MONS_PER_BOX.
func _refresh_box_counts() -> void:
	var index: int = clampi(_cursor, 0, Gen2SaveData.BOX_COUNT - 1)
	var box: Gen2SaveBox = _save.boxes[index] if _save != null \
		and index < _save.boxes.size() else null
	var count: int = 0
	if box != null:
		for slot: int in Gen2SaveBox.CAPACITY:
			if slot < box.slots.size() and box.slots[slot] != null:
				count += 1
	_status = "%d/%d PKMN, CURRENT BOX %d" % [
		count, Gen2SaveBox.CAPACITY, _box_index + 1,
	]


## BILL'S PC's own two lists. The panel steps aside for the box screen the way it
## does for the region map, so the menu is still there when the boxes close.
## `_PlayerMailBoxMenu`: `InitMail` answers zero when `sMailboxCount` is, and
## the routine prints `.EmptyMailboxText` instead of opening the list.
func _open_mailbox() -> void:
	_pc_rows = Gen2WorldPC.mailbox_entries(_save)
	if _pc_rows.is_empty():
		_status = Gen2WorldPC.MAILBOX_EMPTY
		_mode = MODE.PC_ITEMS
		_pc_rows = Gen2WorldPC.players_pc_menu(_data, _pc_house)
		_render_rows()
		return
	_mode = MODE.PC_MAILBOX
	## `MailboxPC` keeps `wCurMessageIndex` across the submenu, so the list
	## reopens on the message that was just acted on rather than at the top.
	_cursor = clampi(_mail_index, 0, _pc_rows.size() - 1)
	_title = _data.pokecenter_pc_row("mail_box", true)
	_summary = ""
	_status = ""
	_render_rows()


func _open_mail_submenu(index: int) -> void:
	_mail_index = clampi(index, 0, maxi(0, _save.mailbox.size() - 1))
	_mode = MODE.PC_MAIL_SUBMENU
	_cursor = 0
	_pc_rows = []
	for row: int in Gen2WorldPC.MAILBOX_ROWS.size():
		_pc_rows.append({"row": row, "name": Gen2WorldPC.MAILBOX_ROWS[row]})
	_status = ""
	_render_rows()


func _confirm_mail_submenu(row: int) -> void:
	match row:
		Gen2WorldPC.MAILBOXITEM_READ:
			_open_mail_reader()
		Gen2WorldPC.MAILBOXITEM_PUT_IN_PACK:
			_open_mail_confirm()
		Gen2WorldPC.MAILBOXITEM_ATTACH:
			_open_mail_attach()
		_:
			_open_mailbox()


## `.PutInPack`'s `.MailMessageLostText` and the `YesNoBox` under it.
func _open_mail_confirm() -> void:
	_mode = MODE.PC_MAIL_CONFIRM
	_cursor = 0
	_pc_rows = [{"row": 0, "name": "YES"}, {"row": 1, "name": "NO"}]
	_summary = Gen2WorldPC.MAILBOX_MESSAGE_LOST
	_status = ""
	_render_rows()


func _confirm_mail_to_pack(accepted: bool) -> void:
	_summary = ""
	if not accepted:
		_open_mailbox()
		return
	var applied: Dictionary = Gen2WorldPC.mailbox_to_pack(
		_world, _save, _mail_index, _persist
	)
	_open_mailbox()
	if not bool(applied.get("ok", false)):
		## `ReceiveItem`'s own failure, which is `.MailPackFullText`.
		_status = Gen2WorldPC.MAILBOX_PACK_FULL
		return
	_status = Gen2WorldPC.MAILBOX_CLEARED


func _open_mail_reader() -> void:
	var mail: Gen2SaveMail = _save.mailbox[_mail_index] 		if _mail_index >= 0 and _mail_index < _save.mailbox.size() else null
	var host := Gen2MailScreen.new()
	host.set_context(_data, mail)
	_mail_reader = host
	_set_overlay_open(true)
	host.z_index = 5
	host.closed.connect(_on_mail_reader_closed)
	_service_hardware.display(host)


func _on_mail_reader_closed() -> void:
	if _mail_reader != null:
		Gen2Screen.drop(_mail_reader)
		_mail_reader = null
	_set_overlay_open(false)
	## `.ReadMail` ends in `CloseSubmenu`, which is back into `MailboxPC.loop`.
	_open_mailbox()


func _open_mail_attach() -> void:
	var host: Gen2PartyScreen = PARTY_SCENE.instantiate() as Gen2PartyScreen
	if host == null or _save == null:
		_status = "Attaching mail needs a validated save."
		return
	_mail_party = host
	_set_overlay_open(true)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_STOP
	host.z_index = 5
	host.set_screen(_service_hardware)
	add_child(host)
	host.set_context(_data, _save, true)
	host.selection_made.connect(_on_mail_attach_selected)
	host.open_selection()


## `.try_again`: the egg and held-item refusals print and reopen the same list,
## so only a member that can take the mail leaves it.
func _on_mail_attach_selected(party_index: int) -> void:
	if party_index >= 0:
		var refusal: StringName = Gen2WorldPC.attach_refusal(_save, party_index)
		if refusal != &"":
			_mail_party.say(
				Gen2WorldPC.MAILBOX_EGG if refusal == &"egg"
				else Gen2WorldPC.MAILBOX_ALREADY_HOLDING
			)
			return
	_close_mail_attach()
	if party_index < 0:
		_open_mailbox()
		return
	var applied: Dictionary = Gen2WorldPC.mailbox_attach(
		_world, _save, _mail_index, party_index, _persist
	)
	_open_mailbox()
	_status = Gen2WorldPC.MAILBOX_MOVED if bool(applied.get("ok", false)) 		else "Refused: %s" % String(applied.get("reason", ""))


func _close_mail_attach() -> void:
	if _mail_party != null:
		Gen2Screen.drop(_mail_party)
		_mail_party = null
	_set_overlay_open(false)


func _open_boxes(mode: int) -> void:
	var host: Gen2BoxScreen = BOX_SCENE.instantiate() as Gen2BoxScreen
	if host == null or _save == null:
		_status = "Box storage needs a validated save."
		return
	_boxes = host
	_set_overlay_open(true)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.z_index = 5
	host.set_screen(_service_hardware)
	add_child(host)
	host.set_context(_data, _save, _persist, true, mode, _box_index)
	host.cry_requested.connect(_on_boxes_cry)
	host.closed.connect(_on_boxes_closed)


## The box screen's stats page plays a cry, and this screen owns no player: the
## world screen is what turns [signal sfx_requested] into sound, and a cry is not
## one, so it is passed on rather than dropped silently.
func _on_boxes_cry(species: int) -> void:
	cry_requested.emit(species)


## `Gen2BoxScreen.closed` carries the result its own host would have resumed a
## script with; nothing is waiting here, because the PC's request is still open.
## `_HallOfFamePC.MasterLoop`: one stored team at a time, newest first, until
## `LoadHOFTeam` runs out of records or B leaves. The panels are the induction's
## own, which is why this opens the same screen the sequence does.
func _open_hall_of_fame(index: int) -> void:
	var records: Array = _save.hall_of_fame if _save != null else []
	var pages: Array = Gen2HallOfFame.record_pages(
		_data, records[index]
	) if index >= 0 and index < records.size() else []
	if pages.is_empty():
		## `.absent` and `.invalid` both answer carry, which `.MasterLoop` takes
		## straight back to the machine's own menu.
		_open_pc(&"pokemon_center")
		return
	var host := Gen2HallOfFameScreen.new()
	host.viewer = true
	host.set_context(_data, pages)
	_hof = host
	_hof_index = index
	_set_overlay_open(true)
	host.z_index = 5
	host.closed.connect(_on_hall_of_fame_closed)
	_service_hardware.display(host)


func _on_hall_of_fame_closed() -> void:
	var cancelled: bool = _hof != null and _hof.cancelled
	if _hof != null:
		Gen2Screen.drop(_hof)
		_hof = null
	_set_overlay_open(false)
	if cancelled:
		_open_pc(&"pokemon_center")
		return
	_open_hall_of_fame(_hof_index + 1)


func _on_boxes_closed(_result: Dictionary) -> void:
	if _boxes != null:
		Gen2Screen.drop(_boxes)
		_boxes = null
	_set_overlay_open(false)
	## `BillsPC_DepositMenu` and `BillsPC_WithdrawMenu` both `CloseWindow` back
	## into `.UseBillsPC`'s own loop, which is the top menu.
	_open_bills_pc_menu()


func _open_phone(request: Dictionary, data: Dictionary) -> void:
	_mode = MODE.PHONE
	_cursor = 0
	_title = "PHONE"
	var summary: Dictionary = {}
	if StringName(request.get("kind", &"")) == &"phone_call_requested":
		summary = Gen2WorldPhoneHost.contact_summary(
			_data, data.get("contact", {})
		)
		_summary = _phone_text(summary)
	else:
		summary = Gen2WorldPhoneHost.special_call_summary(
			_data, data.get("special_call", {})
		)
		_summary = "Special call %d for contact %d." % [
			int(summary.get("index", -1)), int(summary.get("contact", -1)),
		]
	_status = "The imported call record is ready."
	if bool(data.get("out_of_area", false)):
		_status = "This call will use the cartridge out-of-area script."
	elif bool(data.get("phone", {}).get("same_map", false)):
		_status = "This call will use the cartridge same-map script."
	_render_rows(["Continue"])


## One of `PokegearJumptable`'s cards, each on the hardware's own tile grid the
## way the MAP card is. It owns all 160x144 while it is up.
func _open_card(card: StringName) -> void:
	_mode = MODE.CARD
	_cursor = 0
	_set_overlay_open(true)
	_pokegear = Gen2PokegearScreen.new()
	_pokegear.z_index = 5
	_pokegear.set_screen(_service_hardware)
	add_child(_pokegear)
	_pokegear.closed.connect(_on_card_closed)
	_pokegear.switched.connect(_on_card_switched)
	_pokegear.tuned.connect(_on_card_tuned)
	_pokegear.called.connect(_on_card_called)
	_pokegear.deleted.connect(_on_card_deleted)
	var owned: Array = []
	for entry: Dictionary in _pokegear_cards:
		owned.append(StringName(entry.get("card", &"")))
	var text: String = ""
	if card == Gen2PokegearScreen.CARD_CLOCK:
		text = _data.pokegear_text("press_button")
	elif card == Gen2PokegearScreen.CARD_PHONE:
		text = _data.pokegear_text("ask_who")
	if not _pokegear.open(
		_data, card, owned, text, _data.pokegear_text("ask_delete"),
		_world.map_time_of_day()
	):
		_on_card_closed()
		return
	_refresh_card()


## What the open card reads off the world, which is all of its display state.
func _refresh_card() -> void:
	if _pokegear == null:
		return
	match _pokegear.card():
		Gen2PokegearScreen.CARD_CLOCK:
			var clock: Dictionary = _world.world_clock()
			_pokegear.set_clock(
				int(clock.get("day", 0)), int(clock.get("hour", 0)),
				int(clock.get("minute", 0))
			)
		Gen2PokegearScreen.CARD_RADIO:
			var tuned: Dictionary = _world.radio_station()
			# `RadioMusicRestartDE` on a station and `NoRadioMusic` on dead air:
			# either way the card has taken the music off the map, which is what
			# makes the exit restart it.
			_radio_music = RADIO_MUSIC_RESTART_MAP if bool(tuned.get("ok", false)) \
				else RADIO_MUSIC_ENTER_MAP
			var radio_show: Gen2RadioShow = _world.radio_show()
			_pokegear.set_radio(
				_world.state.radio_knob(),
				String(tuned.get("name", "")) if bool(tuned.get("ok", false)) else "",
				radio_show.lines() if radio_show != null else PackedStringArray()
			)
		Gen2PokegearScreen.CARD_PHONE:
			_pokegear.set_contacts(
				_world.registered_phone_contacts(),
				Gen2WorldPhoneHost.map_has_phone_service(_world.current_map)
			)


## `Pokegear_SwitchPage`: the next or previous card the player owns, with no wrap
## at either end. The clock is always there and is where the Pokegear opens.
func _on_card_switched(direction: int) -> void:
	var order: Array = []
	for entry: Dictionary in _pokegear_cards:
		order.append(StringName(entry.get("card", &"")))
	var at: int = order.find(_pokegear.card()) + direction
	if at < 0 or at >= order.size():
		return
	var card: StringName = order[at]
	if card == &"map":
		# The MAP card is the region map's own screen, and B on it is the same
		# `.cancel` every other card has: it leaves the Pokegear.
		_close_card()
		_open_town_map(false)
		return
	_close_card()
	_open_card(card)


## `wPokegearRadioMusicPlaying`, for the host that owns the driver:
## `ExitPokegearRadio_HandleMusic` restarts the map's music only when the radio
## card has played something over it, and every other service leaves it alone.
## The restart lands when this overlay closes rather than when the card does,
## since the overlay is what the world is waiting on rather than the card.
func radio_music_playing() -> int:
	return _radio_music


## One hardware frame of whichever card is open. Only the radio card spends any:
## `PlayRadioShow` is the one thing the Pokegear runs per frame.
func advance_frame() -> void:
	if _pokegear == null or _pokegear.card() != Gen2PokegearScreen.CARD_RADIO:
		return
	if _world.advance_radio_frame():
		_refresh_card()


func _on_card_tuned(knob: int) -> void:
	_world.tune_radio(knob)
	_refresh_card()


func _on_card_called(contact: int) -> void:
	# `.no_service` refuses in front of `MakePhoneCallFromPokegear`, so a map
	# without service says so on the card and never reaches a phone script.
	if not Gen2WorldPhoneHost.map_has_phone_service(_world.current_map):
		sfx_requested.emit(SFX_NO_SIGNAL, false)
		_pokegear.say(_data.pokegear_text("out_of_service"))
		return
	sfx_requested.emit(SFX_CALL, false)
	_pokegear.say(_data.pokegear_text("ellipse"))
	var results: Array = _world.request_outgoing_phone_call(contact)
	_close_card()
	_mode = -1
	_set_overlay_open(false)
	completed.emit(results)


## `PokegearPhone_DeletePhoneNumber`, which clears the slot and closes the gap
## behind it. The list here is a set, so dropping the contact is the whole of it.
func _on_card_deleted(contact: int) -> void:
	var changed: Dictionary = _world.state.apply_changes({}, {}, {
		"phone_contacts": {contact: false},
	})
	if bool(changed.get("ok", false)):
		_refresh_card()


func _on_card_closed() -> void:
	if _pokegear != null and _pokegear.card() == Gen2PokegearScreen.CARD_RADIO:
		_world.close_radio()
	_close_card()
	_mode = -1
	_set_overlay_open(false)
	completed.emit([])


func _close_card() -> void:
	if _pokegear == null:
		return
	Gen2Screen.drop(_pokegear)
	_pokegear = null


## `_FlyMap` opened as an overlay of its own: the region map with the flypoint
## cursor, and nothing of the Pokegear around it.
##
## The chosen spawn is reported through [signal completed] as
## `{ "kind": &"fly_chosen", "spawn": index }`, and a cancel reports -1, which is
## the `ld a, -1` `.pressedB` leaves.
func open_fly_map(
	world: Gen2WorldAPI, data: GameData, save: Gen2SaveData, request: Dictionary
) -> bool:
	_world = world
	_data = data
	_save = save
	_persist = false
	if _world == null or _data == null:
		_show_error("The region map has no world or cartridge cache.")
		return false
	_mode = MODE.TOWN_MAP
	_town_map_from_request = false
	_fly_map = true
	_set_overlay_open(true)
	_town_map = Gen2TownMapScreen.new()
	_town_map.z_index = 5
	_town_map.set_screen(_service_hardware)
	add_child(_town_map)
	_town_map.closed.connect(_on_town_map_closed)
	var visited: Array[int] = []
	for index: Variant in request.get("visited", []):
		visited.append(int(index))
	var opened: bool = _town_map.open_fly(
		_data,
		_world.landmark_backup(),
		bool(request.get("in_kanto", false)),
		visited,
		_save != null and _save.gender == Gen2SaveData.GENDER_FEMALE,
		_world.map_time_of_day(),
	)
	if not opened:
		_on_town_map_closed()
		return false
	return true


func _open_town_map(from_request: bool) -> void:
	_mode = MODE.TOWN_MAP
	_town_map_from_request = from_request
	# The region map is the whole screen, so neither of this host's own layers
	# is drawn under it.
	_set_overlay_open(true)
	_town_map = Gen2TownMapScreen.new()
	_town_map.z_index = 5
	_town_map.set_screen(_service_hardware)
	add_child(_town_map)
	_town_map.closed.connect(_on_town_map_closed)
	# The Pokegear's own MAP card when the Pokegear opened it, `_TownMap`'s
	# corner box when `OverworldTownMap` did.
	var owned: Array = Gen2PokegearScreen.owned_card_ids(_world.state)
	var screen: StringName = Gen2TownMap.SCREEN_TOWN_MAP if from_request \
		else Gen2TownMap.SCREEN_POKEGEAR_CARD
	var opened: bool = _town_map.open(
		_data,
		_world.landmark_backup(),
		_world.state.hall_of_fame(),
		screen,
		owned,
		_save != null and _save.gender == Gen2SaveData.GENDER_FEMALE,
		_world.map_time_of_day(),
	)
	if not opened:
		_on_town_map_closed()


func _on_town_map_closed() -> void:
	var chosen: int = _town_map.chosen_spawn() if _town_map != null else -1
	if _town_map != null:
		Gen2Screen.drop(_town_map)
		_town_map = null
	_set_overlay_open(false)
	if _fly_map:
		_fly_map = false
		_mode = -1
		completed.emit([{"kind": &"fly_chosen", "spawn": chosen}])
		return
	if _town_map_from_request:
		_town_map_from_request = false
		_finish_runtime({"ok": true, "script_value": 1})
		return
	_mode = -1
	completed.emit([])


func _move_cursor(delta: int) -> void:
	var count: int = _option_count()
	if count <= 0:
		return
	_cursor = wrapi(_cursor + delta, 0, count)
	if _mode == MODE.PC_ITEM_LIST:
		_pc_quantity = 1
	## `ScrollingMenu` keeps the cursor inside its own window and moves the
	## window under it.
	var rows: int = _scrolling_rows()
	if rows > 0:
		_pc_scroll = clampi(_pc_scroll, _cursor - rows + 1, _cursor)
		_pc_scroll = clampi(_pc_scroll, 0, maxi(0, count - rows))
	if _mode == MODE.PC_BOX_LIST:
		## `BillsPC_PrintBoxCountAndCapacity` runs per row rather than per
		## choice.
		_refresh_box_counts()
	_render_rows()


## How many rows this mode's list shows at once, or zero for a menu that is not
## a `ScrollingMenu` and draws all of its options.
func _scrolling_rows() -> int:
	if _mode == MODE.MENU:
		## A scripted `verticalmenu` declares as many rows as it has options, so
		## only a list longer than its own window is one.
		if _menu == null or _menu.rows >= _menu.options.size():
			return 0
		return _menu.rows
	return int(SCROLLING_ROWS.get(_mode, 0))


func _move_direction(direction: Vector2i) -> void:
	if _mode == MODE.TOWN_MAP and _town_map != null:
		_town_map.handle_button(Gen2Button.from_vector(direction))
		return
	if _mode == MODE.MENU and _menu != null:
		if _menu.move(direction):
			_cursor = _menu.selected_index()
			_render_rows()
		return
	if _mode == MODE.PC_ITEM_LIST and direction.x != 0:
		_change_pc_quantity(direction.x)
		return
	if direction.x != 0:
		_move_cursor(direction.x)
	else:
		_move_cursor(direction.y)


func _confirm() -> void:
	if _mode in [
		MODE.PC, MODE.PC_ITEMS, MODE.PC_BOXES, MODE.PC_BOX_LIST,
		MODE.PC_DECO, MODE.PC_DECO_LIST, MODE.PC_DECO_SIDE, MODE.PC_BOX_SUBMENU,
		MODE.PC_MAILBOX, MODE.PC_MAIL_SUBMENU, MODE.PC_MAIL_CONFIRM,
	]:
		_confirm_pc_row()
		return
	if _mode == MODE.PC_ITEM_LIST:
		## `.moving_stuff_around` reads A before anything else, so the A that
		## would pick a quantity places the held row instead.
		if _pc_switch >= 0:
			_apply_pc_switch_press()
			return
		_confirm_pc_item()
		return
	if _mode == MODE.PC_TEXT:
		_advance_pc_text()
		return
	if _mode == MODE.MENU:
		if _choices.is_empty():
			_status = "The imported menu has no selectable options."
			return
		_finish_input(_cursor)
		return
	if _mode == MODE.PHONE:
		_finish_runtime({"ok": true, "script_value": 1})


func _cancel() -> void:
	if _mode == MODE.PC_BOXES:
		## `.cancel`: B off the top menu is the same way out SEE YA! is.
		_leave_bills_pc()
	elif _mode == MODE.PC_BOX_LIST:
		_open_bills_pc_menu()
	elif _mode == MODE.PC_BOX_SUBMENU:
		## `VerticalMenu`'s carry, which `.ret c` takes back to `.loop`.
		_open_box_list()
	elif _mode == MODE.PC:
		## `.shutdown`: B off the top menu is the same shut-down TURN OFF is.
		_finish_runtime({"ok": true, "script_value": 0})
	elif _mode == MODE.PC_ITEMS:
		if _pc_house:
			_finish_runtime({"ok": true, "script_value": 0})
		else:
			_open_pc(&"pokemon_center")
	elif _mode == MODE.PC_ITEM_LIST:
		## `.b_2`: the mark is dropped and the list stays up.
		if _pc_switch >= 0:
			_pc_switch = -1
			_render_rows()
			return
		_open_pc_items()
	elif _mode == MODE.PC_MAILBOX:
		## `ScrollingMenu`'s PAD_B, which is `.exit` and the way back to the
		## menu `_PlayerMailBoxMenu` was called from.
		_open_pc_items()
	elif _mode == MODE.PC_MAIL_SUBMENU:
		## `VerticalMenu`'s carry, which `.subexit` takes back to `.loop`.
		_open_mailbox()
	elif _mode == MODE.PC_MAIL_CONFIRM:
		_confirm_mail_to_pack(false)
	elif _mode == MODE.PC_DECO:
		_leave_decorations()
	elif _mode == MODE.PC_DECO_LIST:
		_open_decorations()
	elif _mode == MODE.PC_DECO_SIDE:
		_open_decoration_category(_deco_slot)
	elif _mode == MODE.PC_TEXT:
		## Both `PromptButton` answers advance the box; neither leaves early.
		_advance_pc_text()
	elif _mode == MODE.MENU:
		_finish_input_cancelled()
	elif _mode == MODE.PHONE:
		_finish_runtime({"ok": true, "script_value": 0, "cancelled": true})
	elif _mode == MODE.TOWN_MAP and _town_map != null:
		_town_map.close()


func _finish_input(choice: int) -> void:
	if _host_prompt:
		_finish([{"kind": &"host_choice", "choice": choice}])
		return
	var results: Array = _world.choose_script_input(choice)
	_finish(results)


func _finish_input_cancelled() -> void:
	if _host_prompt:
		## `YesNoBox`'s B is its NO, not a third answer: the caller is told the
		## same thing the second row would have told it.
		_finish([{"kind": &"host_choice", "choice": 1}])
		return
	var results: Array = _world.cancel_script_input()
	_finish(results)


func _finish_runtime(result: Dictionary) -> void:
	var host_result: Dictionary = Gen2WorldHost.complete_runtime_request(
		_world, result, _save, _persist
	)
	if not bool(host_result.get("ok", false)):
		_status = "Request failed: %s" % String(host_result.get("reason", "unknown"))
		_render_rows()
		return
	_finish(host_result.get("results", []))


func _finish(results: Array) -> void:
	if not _extra_results.is_empty():
		results.append_array(_extra_results)
		_extra_results = []
	_mode = -1
	_close_mart()
	completed.emit(results)


## The rows this mode is offering, which is all [method _render_service_page]
## needs: there is no second list to keep in step with it any more.
func _render_rows(override: Array = []) -> void:
	if _is_single_row() and override.is_empty():
		## One value at a time, the way the dial and the room menu each show it.
		override = [_choices[clampi(_cursor, 0, _choices.size() - 1)]] if not _choices.is_empty() \
			else []
	var values: Array = override if not override.is_empty() else (
		_choices if _mode == MODE.MENU \
		else _pc_rows if _mode in [
			MODE.PC, MODE.PC_ITEMS, MODE.PC_BOXES,
			MODE.PC_DECO, MODE.PC_DECO_LIST, MODE.PC_DECO_SIDE,
			MODE.PC_BOX_SUBMENU,
			MODE.PC_MAILBOX, MODE.PC_MAIL_SUBMENU, MODE.PC_MAIL_CONFIRM,
		] \
		else _pc_entries if _mode == MODE.PC_ITEM_LIST \
		else ["Continue"]
	)
	var rows: int = _scrolling_rows()
	if rows > 0 and override.is_empty():
		## The window `ScrollingMenu` draws, and the cursor's place inside it.
		## Clamped here rather than at each way in: a list reopened on a row it
		## was left on (`wCurMessageIndex`, `wCurBox`) starts scrolled to it.
		_pc_scroll = clampi(_pc_scroll, _cursor - rows + 1, _cursor)
		_pc_scroll = clampi(_pc_scroll, 0, maxi(0, values.size() - rows))
		_render_service_page(values.slice(_pc_scroll, _pc_scroll + rows), _cursor - _pc_scroll)
		return
	_render_service_page(values)


## `PhoneCall`'s ringing box and `PC_DisplayText`'s plain `MenuTextbox` print
## neither one, so those two draw no rows at all here.
func _render_service_page(values: Array, cursor: int = -1) -> void:
	if _service_view == null or _data == null:
		_service_drawn = false
		_apply_layer_visibility()
		return
	if _service_page == null:
		_service_page = Gen2WorldServicePage.from_data(_data)
	if _service_page == null:
		_service_drawn = false
		_apply_layer_visibility()
		return
	var page_rows: Array = [] if _mode in [MODE.PHONE, MODE.PC_TEXT] else values
	var labels: Array = []
	for value: Variant in page_rows:
		if value is Dictionary:
			var row: Dictionary = value
			var label: String = String(row.get("name", row.get("caller_label", "")))
			if _mode == MODE.PC_ITEM_LIST:
				label += " x%d" % int(row.get("quantity", 0))
			labels.append(label)
		else:
			labels.append(String(value))
	## `_PlayerDecorationMenu`'s list reaches row 16 and the routine prints no
	## box under it, so the category's name is the list's own title row on the
	## cartridge rather than a speech box the list would be drawn over.
	var quiet: bool = _mode == MODE.PC_DECO_LIST
	var image: Image = _mom_bank_image() if _mode == MODE.MOM_BANK \
		else _dial_image() if _is_dial() else _service_page.render(
		"" if quiet else _title, "" if quiet else _summary, labels,
		_cursor if cursor < 0 else cursor, "" if quiet else _status,
		_service_box(), _service_note()
	)
	if image != null:
		Gen2PicImage.show(_service_view, image)
	_service_drawn = image != null
	_apply_layer_visibility()


## `Elevator_GetCurrentFloorText`'s own box, which no other mode draws.
func _service_note() -> PackedStringArray:
	if _mode != MODE.ELEVATOR:
		return PackedStringArray()
	var floors: Array = _elevator_floors()
	var current: int = int(_elevator.get("current", -1))
	if current < 0 or current >= floors.size():
		return PackedStringArray()
	return PackedStringArray([
		"Now on:", _floor_name(int((floors[current] as Dictionary)["floor"])),
	])


## An overlay owns all 160x144 while it is up: the mart, box storage, a Pokegear
## card and the region map are each a screen rather than a box over this one.
func _set_overlay_open(open: bool) -> void:
	_overlay_open = open
	_apply_layer_visibility()


## The one place the hardware layer is shown: never while an overlay is up, and
## never before a service has opened. Setting it by hand at each entrance is what
## left it standing behind whatever the mode drew.
func _apply_layer_visibility() -> void:
	if _service_view != null:
		_service_view.visible = _mode >= 0 and not _overlay_open and _service_drawn


func _is_dial() -> bool:
	return _mode == MODE.MENU and _menu != null and _menu.kind == &"spinner"


## The two menus that show one row rather than a list: `SetDayOfWeek`'s dial and
## `BattleTowerRoomMenu_UpdatePickLevelMenu`'s room, which prints the chosen
## level at `hlcoord 13, 9` between the two arrows and nothing else.
func _is_single_row() -> bool:
	return _is_dial() \
		or (_mode == MODE.MENU and _menu != null and _menu.kind == &"room")


## `SetDayOfWeek`'s `.loop`: the box, the two arrows, the one weekday string at
## `hlcoord 10, 5` and `.OakTimeWhatDayIsItText` in the speech box below it.
func _dial_image() -> Image:
	if _clock_page == null:
		_clock_page = Gen2ClockSetPage.from_data(_data)
	if _clock_page == null:
		return null
	var day: int = clampi(_cursor, 0, Gen2ClockSetScreen.DAYS.size() - 1)
	var prompt: String = _summary if not _summary.is_empty() \
		else "What day is it?"
	return _clock_page.render(Gen2ClockSetScreen.DAYS[day], prompt, -1, &"day")


## The `menu_coords` box this mode's own list sits in. `null` draws no box,
## which is what MODE.MENU falls back to before a menu is loaded.
func _service_box() -> Gen2MenuBox:
	match _mode:
		MODE.MENU:
			if _menu == null or _menu.kind == &"spinner":
				return null
			var menu_box: Gen2MenuBox = _menu.box()
			menu_box.scroll = _pc_scroll
			return menu_box
		MODE.PC, MODE.PC_ITEMS, MODE.PC_BOXES:
			return _pc_top_box()
		MODE.PC_DECO_LIST:
			return _deco_list_box()
		MODE.ELEVATOR:
			## `Elevator_MenuHeader`'s `menu_coords 12, 1, 18, 9`.
			##
			## `ScrollingMenu_UpdateDisplay` reaches its first row with
			## `MenuBoxCoord2Tile / ld bc, SCREEN_WIDTH + 1`, which is one row
			## down and one column right, where `_InitVerticalMenuCursor` spends
			## a second row before the first item. A scrolling menu therefore has
			## no top spacing, and this box's fourth floor sits on its own border
			## without it.
			var elevator_box: Gen2MenuBox = Gen2MenuBox.from_coords(
				12, 1, 18, 9,
				Gen2MenuBox.STATICMENU_CURSOR | Gen2MenuBox.STATICMENU_NO_TOP_SPACING
			)
			elevator_box.scrolling_arrows = true
			elevator_box.scroll = _elevator_scroll
			return elevator_box
		MODE.PC_MAILBOX:
			## `.TopMenuHeader`'s `menu_coords 8, 1, SCREEN_WIDTH - 2, 10`.
			return _scrolling_box(
				Gen2MenuBox.from_coords(8, 1, 18, 10, Gen2MenuBox.STATICMENU_CURSOR)
			)
		MODE.PC_MAIL_SUBMENU:
			## `.SubMenuHeader`'s `menu_coords 0, 0, 13, 9`.
			return Gen2MenuBox.from_coords(0, 0, 13, 9, Gen2MenuBox.STATICMENU_CURSOR)
		MODE.PC_MAIL_CONFIRM:
			## `YesNoBox`'s own box, which `.PutInPack` opens over its question.
			return Gen2MenuBox.yes_no()
		MODE.PC_DECO:
			return _deco_category_box()
		MODE.PC_DECO_SIDE:
			return _deco_side_box()
		MODE.PC_BOX_LIST:
			return _pc_box_list_box()
		MODE.PC_BOX_SUBMENU:
			## `.MenuHeader`'s `menu_coords 11, 4, SCREEN_WIDTH - 1, 13`, raised
			## two rows: the change-box screen it is drawn over on the cartridge
			## has its own words at rows 14 to 17, and this panel's box is at 11,
			## which the source's corner would put QUIT behind.
			return Gen2MenuBox.from_coords(11, 2, 19, 11, Gen2MenuBox.STATICMENU_CURSOR)
		MODE.PC_ITEM_LIST:
			return _pc_item_list_box()
		MODE.APRICORN:
			return _apricorn_quantity_box() if _apricorns != null \
				and _apricorns.phase == Gen2WorldApricorn.SELECT_QUANTITY \
				else _apricorn_select_box()
	return null


## `PokemonCenterPC.TopMenu` and `PlayersPCMenuData` share this `menu_coords`.
func _pc_top_box() -> Gen2MenuBox:
	return Gen2MenuBox.from_coords(
		0, 0, 15, 12, Gen2MenuBox.STATICMENU_CURSOR | Gen2MenuBox.STATICMENU_WRAP
	)


## `_ChangeBox_MenuHeader`'s `menu_coords 1, 5, 9, 12`, which is four rows of a
## scrolling list rather than all fourteen at once.
func _pc_box_list_box() -> Gen2MenuBox:
	var box: Gen2MenuBox = Gen2MenuBox.from_coords(
		1, 5, 9, 5 + BOX_LIST_ROWS + 2, Gen2MenuBox.STATICMENU_CURSOR
	)
	## `ScrollingMenu` writes its rows one apart, where `VerticalMenu` writes
	## them two.
	box.row_step = 1
	return box


## `_PlayerDecorationMenu.MenuHeader`'s `menu_coords 5, 0, SCREEN_WIDTH - 1,
## SCREEN_HEIGHT - 1`.
func _deco_category_box() -> Gen2MenuBox:
	return Gen2MenuBox.from_coords(
		5, 0, 19, 17, Gen2MenuBox.STATICMENU_CURSOR | Gen2MenuBox.STATICMENU_WRAP
	)


## `DecoSideMenuHeader`'s `menu_coords 0, 0, 13, 7`.
func _deco_side_box() -> Gen2MenuBox:
	return Gen2MenuBox.from_coords(0, 0, 13, 7, Gen2MenuBox.STATICMENU_CURSOR)


## `PCItemsMenuData`'s `menu_coords 4, 1, 18, 10`.
func _pc_item_list_box() -> Gen2MenuBox:
	return _scrolling_box(
		Gen2MenuBox.from_coords(4, 1, 18, 10, Gen2MenuBox.STATICMENU_CURSOR)
	)


## `_PlayerDecorationMenu.ScrollingMenuHeader`'s `menu_coords 1, 1, SCREEN_WIDTH
## - 2, SCREEN_HEIGHT - 2`. The category list above it is a `VerticalMenu` with
## its own coords, and this list used to be drawn in the PC's top-menu box.
func _deco_list_box() -> Gen2MenuBox:
	return _scrolling_box(
		Gen2MenuBox.from_coords(1, 1, 18, 16, Gen2MenuBox.STATICMENU_CURSOR)
	)


## `SCROLLINGMENU_DISPLAY_ARROWS` and the window this screen's one
## `wMenuScrollPosition` stands at.
func _scrolling_box(box: Gen2MenuBox) -> Gen2MenuBox:
	box.scrolling_arrows = true
	box.scroll = _pc_scroll
	return box


## `Kurt_SelectApricorn.MenuHeader`'s `menu_coords 1, 1, 13, 10`.
func _apricorn_select_box() -> Gen2MenuBox:
	var box: Gen2MenuBox = Gen2MenuBox.from_coords(
		1, 1, 13, 10, Gen2MenuBox.STATICMENU_CURSOR
	)
	box.scrolling_arrows = true
	box.scroll = _apricorns.scroll if _apricorns != null else 0
	return box


## `Kurt_SelectQuantity.MenuHeader`'s `menu_coords 6, 9, SCREEN_WIDTH - 1, 12`.
## `PlaceApricornQuantity` writes the name and quantity by hand rather than
## through a `STATICMENU_CURSOR` list, so this box draws no cursor.
func _apricorn_quantity_box() -> Gen2MenuBox:
	return Gen2MenuBox.from_coords(6, 9, 19, 12, 0)


func _option_count() -> int:
	if _mode == MODE.MENU:
		return _menu.options.size() if _menu != null else _choices.size()
	if _mode in [
		MODE.PC, MODE.PC_ITEMS, MODE.PC_BOXES, MODE.PC_BOX_LIST,
		MODE.PC_DECO, MODE.PC_DECO_LIST, MODE.PC_DECO_SIDE, MODE.PC_BOX_SUBMENU,
		MODE.PC_MAILBOX, MODE.PC_MAIL_SUBMENU, MODE.PC_MAIL_CONFIRM,
	]:
		return _pc_rows.size()
	if _mode == MODE.PC_ITEM_LIST:
		return maxi(1, _pc_entries.size())
	return 1


func _mart_source() -> Dictionary:
	return _mart


## `FarReadMart`'s own list. CANCEL is not one of its rows: `ScrollingMenu`
## draws it past the terminator, which is what [method _mart_rows] does.
func _refresh_mart_entries() -> void:
	_mart_entries = Gen2WorldMartHost.entries(_data, _mart_source())


func _phone_text(summary: Dictionary) -> String:
	return "%s %d\nMap %d/%d\nCaller time %d, callee time %d" % [
		String(summary.get("trainer_name", "UNKNOWN")),
		int(summary.get("trainer_number", 0)),
		int(summary.get("map_group", -1)), int(summary.get("map_number", -1)),
		int(summary.get("caller_time", 0)), int(summary.get("callee_time", 0)),
	]


## Nothing is drawn for it: a host with no world or cartridge cache never opens,
## and the caller's own `false` is what says so.
func _show_error(message: String) -> void:
	_mode = -1
	_menu = null
	_title = "SERVICE ERROR"
	_summary = message
	_status = ""
	_apply_layer_visibility()
