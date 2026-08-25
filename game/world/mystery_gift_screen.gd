class_name Gen2MysteryGiftScreen
extends Control

## `DoMysteryGift` (`engine/link/mystery_gift.asm`), from the prompt the screen
## opens on to the box it ends on.
##
## The routine is three steps and no menu: the layout with
## `.String_PressAToLink_BToCancel` under it, A to hold the infrared window open
## and B to leave it, and then one box. Everything the box could say is
## [method Gen2MysteryGift.exchange]'s answer, so this screen owns the wait, the
## two buttons and the picture; the decision is not here and neither is the
## section.
##
## It is the main menu's row rather than an overworld one, so its host is the
## save screen: the section lives outside the checksummed save on the cartridge
## precisely so the exchange can happen with no file loaded, and the two slots
## the save screen already has in front of it are the only two Mystery Gift
## blocks that exist on one machine.

signal closed()

## What is on screen, in the order the routine reaches them.
enum STEP { PROMPT, EXCHANGING, MESSAGE }

## `ExchangeMysteryGiftData`'s own four-second timeout, in hardware frames. The
## screen spends it whether or not a partner is in the window, because that is
## what the routine spends looking.
const EXCHANGE_FRAMES: int = 60 * 4

var _page: Gen2MysteryGiftPage = null
var _data: GameData = null
var _save: Gen2SaveData = null
var _transport: Gen2MysteryGiftTransport = null
var _random: RandomNumberGenerator = null
var _dex_caught: int = 0
var _day: int = 0

var _step: STEP = STEP.PROMPT
var _frames: int = 0
var _result: Dictionary = {}
var _pages: Array = []
var _page_index: int = 0
var _background: TextureRect = null


## [param transport] is the infrared window; one with nobody in it is a real
## path rather than a stub. [param day] is the world day the countdown behind
## the daily limit is measured in.
func set_context(
	data: GameData, save: Gen2SaveData, transport: Gen2MysteryGiftTransport,
	dex_caught: int, day: int, random: RandomNumberGenerator
) -> void:
	_data = data
	_save = save
	_transport = transport if transport != null else Gen2MysteryGiftTransport.new()
	_dex_caught = dex_caught
	_day = day
	_random = random if random != null else RandomNumberGenerator.new()
	_page = Gen2MysteryGiftPage.from_data(data)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)
	if _page == null or _save == null:
		closed.emit()
		return
	_background = TextureRect.new()
	_background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)
	## `MysteryGift`'s own two calls in front of the screen: `UpdateTime` and
	## `DoMysteryGiftIfDayHasPassed`, which is what lifts yesterday's limit.
	Gen2MysteryGift.begin_session(_section(), _day)
	_refresh()


func step() -> STEP:
	return _step


## What the last exchange answered, empty before one has run.
func result() -> Dictionary:
	return _result.duplicate()


func handle_button(button: int) -> bool:
	if _page == null:
		return false
	match _step:
		STEP.PROMPT:
			if button == Gen2Button.A:
				_step = STEP.EXCHANGING
				_frames = EXCHANGE_FRAMES
				_refresh()
			elif button == Gen2Button.B:
				closed.emit()
		STEP.MESSAGE:
			if button in [Gen2Button.A, Gen2Button.B]:
				if _page_index + 1 < _pages.size():
					_page_index += 1
					_refresh()
				elif bool(_result.get("retry", false)):
					## `.CommunicationError` is the one box that does not leave:
					## `jp DoMysteryGift` puts the prompt back up.
					_step = STEP.PROMPT
					_refresh()
				else:
					closed.emit()
	return true


func advance_frame() -> void:
	if _frames <= 0:
		return
	_frames -= 1
	if _frames == 0 and _step == STEP.EXCHANGING:
		_exchange()


func settle(limit: int = EXCHANGE_FRAMES + 8) -> void:
	var guard: int = limit
	while _frames > 0 and guard > 0:
		advance_frame()
		guard -= 1


## The whole of the routine past `ExchangeMysteryGiftData`, and the write-back
## behind it: the section this screen edited is the save's, so a gift lands in
## the slot that was chosen rather than in the one being played.
func _exchange() -> void:
	var section: Dictionary = _section()
	var player: Dictionary = Gen2MysteryGift.stage_player_data(
		_save, section, _dex_caught, _random
	)
	_result = Gen2MysteryGift.exchange(section, _transport, player, {
		"items": _data.mystery_gift_table(false),
		"decos": _data.mystery_gift_table(true),
	}, _data)
	_save.mystery_gift = section
	_pages = Gen2TextLayout.lay_out(box_text(
		_data, StringName(_result.get("outcome", &"")),
		String(_transport.peer.get("name", "")),
		_save.player_name, String(_result.get("name", ""))
	), Gen2MysteryGiftPage.MESSAGE_COLUMNS, Gen2MysteryGiftPage.MESSAGE_ROWS)
	_page_index = 0
	_step = STEP.MESSAGE
	_refresh()


func _section() -> Dictionary:
	if _save.mystery_gift.is_empty():
		_save.mystery_gift = Gen2MysteryGift.default_section()
	return _save.mystery_gift


## One of `DoMysteryGift`'s eight boxes with its `text_ram` markers filled in.
## The two the gift arrives in name the partner, the player and the gift; the
## other six name nobody, and filling a marker they do not carry costs nothing.
static func box_text(
	data: GameData, outcome: StringName, partner: String, player: String,
	gift: String
) -> String:
	if data == null or outcome.is_empty():
		return ""
	var text: String = data.special_text("mystery_gift", String(outcome))
	if text.is_empty():
		return ""
	var buffers: Dictionary = {
		"mystery_gift_partner_name": partner,
		"mystery_gift_player_name": player,
	}
	for name: String in buffers:
		var address: int = data.special_text_ram(name)
		if address >= 0:
			text = Gen2TextStream.fill_all_markers(
				text, "%s%04X>" % [Gen2TextStream.RAM_MARKER, address],
				String(buffers[name])
			)
	var buffer_1: Array[int] = data.string_buffer_addresses()
	if buffer_1.size() > RomLayout.STRING_BUFFER_1:
		text = Gen2TextStream.fill_all_markers(
			text,
			"%s%04X>" % [
				Gen2TextStream.RAM_MARKER, buffer_1[RomLayout.STRING_BUFFER_1],
			],
			gift
		)
	return text


## What is in the box right now: empty while the prompt is up, and one page of
## the outcome once it has been printed.
func visible_text() -> String:
	if _step != STEP.MESSAGE or _page_index >= _pages.size():
		return ""
	return "\n".join(_pages[_page_index] as PackedStringArray)


func _refresh() -> void:
	if _background == null or _page == null:
		return
	Gen2PicImage.show(_background, _page.render(visible_text()))
	_background.size = Vector2(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)
