class_name Gen2LinkScreen
extends Control

## `LinkCommunications` from the console the player used to the moment the room
## lets them go: the trade screen's own two-list menu and `_DisplayLinkRecord`'s
## one page. Embedded in the overworld the way the Hall of Fame viewer and BILL'S
## PC are. The cable is [Gen2LinkTransport] and the commit is
## [method Gen2WorldPartyHost.commit_link_trade]; this screen owns the cursor, the
## boxes and the order they are shown in, and nothing else. The Colosseum is not
## here: `Colosseum` runs the same opening and then a battle, which the world
## screen already opens through its own battle host.

signal closed()
## `LinkMonStatsScreen`, which the overworld opens over this the way the party
## menu opens one. [param side] is 0 for the player's list and 1 for the
## partner's.
signal stats_requested(side: int, index: int)
## One completed trade, as [method Gen2WorldPartyHost.commit_link_trade]
## reported it.
signal traded(result: Dictionary)

const MODE_TRADE: int = 0
const MODE_RECORD: int = 1

## `LinkCommunications`' own `ld c, 80 / call DelayFrames` twice, spent behind
## the "Please wait!" box while the two parties are exchanged.
const PLEASE_WAIT_FRAMES: int = 160
## `ld c, 100 / call DelayFrames` after both players have offered, and the fifty
## `PlaceWaitingTextAndSyncAndExchangeNybble` ends on.
const OFFER_FRAMES: int = 100
const WAITING_FRAMES: int = 50

## `LinkTradePartiesMenuMasterLoop`'s two lists.
const LIST_PLAYER: int = 0
const LIST_PARTNER: int = 1

## `LinkTrade_TradeStatsMenu`'s two words.
const FOOTER_STATS: int = 0
const FOOTER_TRADE: int = 1

## What the screen is showing, in the order `LinkTrade` reaches them.
enum STEP {
	PLEASE_WAIT, SELECT, FOOTER, OFFERING, CONFIRM, RESULT, LEAVING, DONE,
}

var mode: int = MODE_TRADE
## Whether the trade is written to disk. A driver that only wants the screen
## passes false, the way the box screen's own `persist` does.
var persist: bool = true

var _data: GameData = null
var _world: Gen2WorldAPI = null
var _save: Gen2SaveData = null
var _transport: Gen2LinkTransport = null
var _page: Gen2LinkPage = null
var _background: TextureRect = null

var _step: int = STEP.PLEASE_WAIT
var _frames: int = 0
var _list: int = LIST_PLAYER
var _index: int = 0
var _partner_index: int = 0
var _on_cancel: bool = false
var _cancel_sent: bool = false
var _footer: int = FOOTER_TRADE
var _confirm: int = 0
var _message: Array = []
var _message_spacing: int = Gen2LinkPage.MESSAGE_PRINTED_SPACING
var _partner_choice: int = -1
var _partner: Dictionary = {}


func set_context(
	data: GameData,
	world: Gen2WorldAPI,
	save: Gen2SaveData,
	transport: Gen2LinkTransport,
	screen_mode: int = MODE_TRADE,
	persist_writes: bool = true
) -> void:
	_data = data
	_world = world
	_save = save
	_transport = transport if transport != null else Gen2LinkTransport.new()
	mode = screen_mode if screen_mode in [MODE_TRADE, MODE_RECORD] else MODE_TRADE
	persist = persist_writes
	_page = Gen2LinkPage.from_data(data)
	_partner = _transport.peer.duplicate(true)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)
	if _page == null:
		closed.emit()
		return
	_background = TextureRect.new()
	_background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)
	if mode == MODE_RECORD:
		_step = STEP.DONE
	elif not _transport.connected():
		## A room whose cable has nothing on the other end never gets past
		## `LinkCommunications`' own opening box; `Link_CheckCommunicationError`
		## is what ends it, and the player walks back out.
		_step = STEP.PLEASE_WAIT
		_frames = PLEASE_WAIT_FRAMES
	else:
		_step = STEP.PLEASE_WAIT
		_frames = PLEASE_WAIT_FRAMES
	_refresh()


## Which step is on screen, for the checks and the screenshot tool.
func step() -> int:
	return _step


func advance_frame() -> void:
	if _frames <= 0:
		return
	_frames -= 1
	if _frames > 0:
		return
	match _step:
		STEP.PLEASE_WAIT:
			if not _transport.connected():
				_step = STEP.LEAVING
				closed.emit()
				return
			_step = STEP.SELECT
		STEP.OFFERING:
			_step = STEP.CONFIRM
		STEP.RESULT:
			_step = STEP.SELECT
			_message = []
		STEP.LEAVING:
			closed.emit()
			return
	_refresh()


## Spends [param limit] frames of whatever wait is standing, for a driver that
## wants the screen rather than the animation in front of it.
func settle(limit: int = 600) -> void:
	var guard: int = limit
	while _frames > 0 and guard > 0:
		advance_frame()
		guard -= 1


func handle_button(button: int) -> bool:
	if _page == null:
		return false
	if mode == MODE_RECORD:
		if button in [Gen2Button.A, Gen2Button.B]:
			closed.emit()
		return true
	if _frames > 0:
		return true
	match _step:
		STEP.SELECT:
			return _press_select(button)
		STEP.FOOTER:
			return _press_footer(button)
		STEP.CONFIRM:
			return _press_confirm(button)
	return true


## `LinkTradePartymonMenuLoop` and `LinkTradeOTPartymonMenuLoop`, which are one
## list each with the other one below it: DOWN off the bottom of the player's
## list moves into the partner's, UP off the top of the partner's moves back,
## and UP off the top of the player's reaches CANCEL.
func _press_select(button: int) -> bool:
	var rows: int = _rows(_list)
	if _on_cancel:
		match button:
			Gen2Button.A:
				_leave()
			Gen2Button.UP:
				_on_cancel = false
				_list = LIST_PARTNER
				_index = maxi(_rows(LIST_PARTNER) - 1, 0)
			Gen2Button.DOWN:
				_on_cancel = false
				_list = LIST_PLAYER
				_index = 0
		_refresh()
		return true
	match button:
		Gen2Button.A:
			if _list == LIST_PARTNER:
				## `.not_a_button`'s A branch opens `LinkMonStatsScreen` on the
				## partner's row; the row the cursor is left on is the offer the
				## transport answers with.
				_partner_index = _index
				stats_requested.emit(LIST_PARTNER, _index)
			else:
				_step = STEP.FOOTER
				_footer = FOOTER_TRADE
		Gen2Button.UP:
			if _index > 0:
				_index -= 1
			elif _list == LIST_PARTNER:
				_list = LIST_PLAYER
				_index = maxi(_rows(LIST_PLAYER) - 1, 0)
			else:
				_on_cancel = true
		Gen2Button.DOWN:
			if _index + 1 < rows:
				_index += 1
			elif _list == LIST_PLAYER:
				_list = LIST_PARTNER
				_index = 0
			else:
				_on_cancel = true
	_refresh()
	return true


## `LinkTrade_TradeStatsMenu`: RIGHT and LEFT move between the two words, B goes
## back to the list, A on STATS opens the player's own stats page and A on TRADE
## offers the row.
func _press_footer(button: int) -> bool:
	match button:
		Gen2Button.RIGHT:
			_footer = FOOTER_TRADE
		Gen2Button.LEFT:
			_footer = FOOTER_STATS
		Gen2Button.B:
			_step = STEP.SELECT
		Gen2Button.A:
			if _footer == FOOTER_STATS:
				_step = STEP.SELECT
				stats_requested.emit(LIST_PLAYER, _index)
			else:
				_offer()
	_refresh()
	return true


## `.try_trade`: the row goes out as `wPlayerLinkAction`, the partner's comes
## back as `wOtherPlayerLinkMode`, `LinkTradePlaceArrow` marks it and the two
## validity tests run before the question is asked.
func _offer() -> void:
	_partner_choice = _transport_choice()
	var incoming: Dictionary = _partner_mon(_partner_choice)
	if incoming.is_empty() or not Gen2LinkSession.validate_ot_trademon(
		incoming, int(incoming.get("species", 0)), bool(incoming.get("is_egg", false)),
		_link_mode()
	):
		_refuse(_abnormal_message(incoming))
		return
	if not Gen2LinkSession.any_other_alive_mons_for_trade(
		_player_rows(), _index, incoming
	):
		_refuse(_cant_battle_message())
		return
	_step = STEP.OFFERING
	_frames = OFFER_FRAMES
	_message = _ask_message(incoming)


## `.abnormal` and the `CheckAnyOtherAliveMonsForTrade` branch beside it: both
## print their box, then `String_TooBadTheTradeWasCanceled`, and go back to the
## listing.
func _refuse(lines: Array) -> void:
	_partner_choice = -1
	_step = STEP.RESULT
	_frames = OFFER_FRAMES
	_message = lines
	_refresh()


func _press_confirm(button: int) -> bool:
	match button:
		Gen2Button.UP:
			_confirm = 0
		Gen2Button.DOWN:
			_confirm = 1
		Gen2Button.B:
			_cancel_trade()
			return true
		Gen2Button.A:
			if _confirm == 0:
				_commit()
			else:
				_cancel_trade()
			return true
	_refresh()
	return true


func _cancel_trade() -> void:
	_confirm = 0
	_partner_choice = -1
	_step = STEP.RESULT
	_frames = WAITING_FRAMES
	_place_message(Gen2LinkPage.TRADE_CANCELED)
	_refresh()


## `.do_trade`, whose whole save-side effect is
## [method Gen2WorldPartyHost.commit_link_trade]. `SaveAfterLinkTrade` is the
## write that transaction already is.
func _commit() -> void:
	_confirm = 0
	var result: Dictionary = Gen2WorldPartyHost.commit_link_trade(
		_world, _save, _index, _partner_mon(_partner_choice),
		{"name": String(_partner.get("name", "")), "link_mode": _link_mode()},
		persist
	)
	_step = STEP.RESULT
	_frames = WAITING_FRAMES
	if not bool(result.get("ok", false)):
		_place_message(Gen2LinkPage.TRADE_CANCELED)
	else:
		_place_message(Gen2LinkPage.TRADE_COMPLETED)
		## The row the partner gave up is gone from its party for the rest of
		## this visit, the way the cartridge's own copy of it is.
		_take_partner_mon(_partner_choice)
		_index = mini(_index, maxi(_rows(LIST_PLAYER) - 1, 0))
		traded.emit(result)
	_partner_choice = -1
	_refresh()


## `LinkTradePartymonMenuCheckCancel.a_button`, which sends `$f` and waits for
## the same byte back before `ExitLinkCommunications` runs.
func _leave() -> void:
	_cancel_sent = true
	_step = STEP.LEAVING
	_frames = WAITING_FRAMES
	_refresh()


## One of the two inline `db` strings, which `PlaceString` puts on consecutive
## rows rather than two apart.
func _place_message(text: String) -> void:
	_message = Array(text.split("\n"))
	_message_spacing = Gen2LinkPage.MESSAGE_PLACED_SPACING


func _link_mode() -> int:
	if _world == null or _world.state == null:
		return Gen2LinkSession.LINK_TRADECENTER
	return _world.state.link_session().link_mode


## `wOtherPlayerLinkMode` after `.try_trade`'s own exchange, which is the row the
## partner offered. The transport is what answers it; see
## [method Gen2LinkTransport.choose_trade_slot].
func _transport_choice() -> int:
	return _transport.choose_trade_slot({
		"ot_cursor": _partner_index, "ot_count": _rows(LIST_PARTNER),
	})


func _rows(list: int) -> int:
	if list == LIST_PARTNER:
		return (_partner.get("party", []) as Array).size()
	return _save.party.size() if _save != null else 0


func _player_rows() -> Array:
	var out: Array = []
	if _save == null:
		return out
	for mon: Gen2SaveMon in _save.party:
		out.append(mon.to_dict())
	return out


func _partner_mon(index: int) -> Dictionary:
	var party: Array = _partner.get("party", [])
	if index < 0 or index >= party.size():
		return {}
	return (party[index] as Dictionary).duplicate(true)


func _take_partner_mon(index: int) -> void:
	var party: Array = _partner.get("party", [])
	if index >= 0 and index < party.size():
		party.remove_at(index)
	_partner["party"] = party
	_partner_index = mini(_partner_index, maxi(party.size() - 1, 0))


func _species_name(species: int) -> String:
	return String(_data.species(species).get("name", "")) if _data != null else ""


## `_LinkAskTradeForText`, whose two `text_ram` buffers are the two nicknames.
func _ask_message(incoming: Dictionary) -> Array:
	var mine: String = ""
	if _save != null and _index < _save.party.size():
		var mon: Gen2SaveMon = _save.party[_index]
		mine = mon.nickname if not mon.nickname.is_empty() \
			else _species_name(mon.species)
	var theirs: String = String(incoming.get("nickname", ""))
	if theirs.is_empty():
		theirs = _species_name(int(incoming.get("species", 0)))
	return _special_text("ask_trade", {"trademon_nickname": mine, 1: theirs})


func _abnormal_message(incoming: Dictionary) -> Array:
	return _special_text("abnormal_mon", {
		1: _species_name(int(incoming.get("species", 0))),
	})


func _cant_battle_message() -> Array:
	return _special_text("cant_battle", {})


## One of the trade screen's three imported boxes, with its buffers filled and
## its lines split the way the box would page them.
func _special_text(box: String, buffers: Dictionary) -> Array:
	if _data == null:
		return []
	var text: String = _data.special_text("link", box)
	for name_or_address: Variant in buffers:
		var address: int = _data.special_text_ram(String(name_or_address)) \
			if name_or_address is String else int(name_or_address)
		if address < 0:
			continue
		text = text.replace(
			"%s%04X>" % [Gen2TextStream.RAM_MARKER, address],
			String(buffers[name_or_address])
		)
	_message_spacing = Gen2LinkPage.MESSAGE_PRINTED_SPACING
	var pages: Array = Gen2TextLayout.lay_out(
		text, Gen2LinkPage.MESSAGE_BOX.size.x, 2
	)
	return Array(pages[0]) if not pages.is_empty() else []


func _refresh() -> void:
	if _background == null or _page == null:
		return
	var indices: PackedByteArray
	if mode == MODE_RECORD:
		indices = _page.draw_record(
			_save.link_record if _save != null else {},
			_save.player_name if _save != null else "",
			_save != null
		)
	elif _step == STEP.PLEASE_WAIT:
		indices = _page.draw_please_wait()
	else:
		indices = _page.draw_trade(trade_state())
	Gen2PicImage.show(_background, _page.image(indices))
	_background.size = Vector2(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)


## What the page is asked to draw, exposed so a check can read a screen back
## without a texture.
func trade_state() -> Dictionary:
	return {
		"player": {
			"name": _save.player_name if _save != null else "",
			"species": _party_names(_player_rows()),
		},
		"partner": {
			"name": String(_partner.get("name", "")),
			"species": _party_names(_partner.get("party", [])),
		},
		"list": _list,
		"index": _index,
		"cancel": _on_cancel,
		"cancel_sent": _cancel_sent,
		"partner_choice": _partner_choice,
		"footer": _footer if _step == STEP.FOOTER else -1,
		"confirm": _confirm if _step == STEP.CONFIRM else -1,
		"message": _message.duplicate(),
		"message_spacing": _message_spacing,
		"waiting": _step in [STEP.OFFERING, STEP.LEAVING],
	}


## `PlaceTradePartnerNamesAndParty` prints the species name and not the
## nickname, which is the one place either list does.
func _party_names(rows: Array) -> Array:
	var out: Array = []
	for row: Dictionary in rows:
		out.append(_species_name(int(row.get("species", 0))))
	return out
