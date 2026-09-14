class_name Gen2TradeAnimationScreen
extends Control

## [Gen2TradeAnimation] with [Gen2TradeAnimationPage] in front of it, or
## [Gen1TradeAnimation] drawing its own LCD, for a host that has a screen. The
## trade itself is already committed when this opens, the way `NPCTrade` calls
## `DoNPCTrade` before its animation and `InGameTrade_DoTrade` runs
## `InternalClockTradeAnim` before `AddPartyMon`.

signal closed()
signal cry_requested(species: int)
signal sfx_requested(index: int)
signal music_requested(index: int)

const FRAME_CAP: int = 20000

var _movie: Gen2TradeAnimation = null
var _page: Gen2TradeAnimationPage = null
var _gen1: Gen1TradeAnimation = null
var _background: TextureRect = null


## [param context] is what [method Gen2TradeAnimation.create] takes.
func set_context(
	data: GameData, context: Dictionary, half: int = Gen2TradeAnimation.PLAYER_1
) -> void:
	if data != null and data.generation == RomRegistry.GEN1:
		_gen1 = Gen1TradeAnimation.create(data, context, half)
		return
	_page = Gen2TradeAnimationPage.from_data(data)
	_movie = Gen2TradeAnimation.create(
		data, Gen2BattleAnimData.from_game_data(data), context, half
	)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)
	if _gen1 == null and (_movie == null or _page == null):
		closed.emit()
		return
	_background = TextureRect.new()
	_background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)
	if _movie != null:
		_forward(_movie.drain_events())
	_refresh()


## Neither `TradeAnimation` nor `TradeAnimCommon` reads the joypad, so a press
## is spent rather than passed on.
func handle_button(_button: int) -> bool:
	return true


func movie() -> Gen2TradeAnimation:
	return _movie


func gen1_movie() -> Gen1TradeAnimation:
	return _gen1


func _finished() -> bool:
	return _gen1.finished() if _gen1 != null else _movie == null or _movie.finished()


func _frame() -> int:
	return _gen1.frame() if _gen1 != null else _movie.frame()


func _advance() -> void:
	_forward(_gen1.advance_frame() if _gen1 != null else _movie.advance_frame())


func advance_frame() -> void:
	if _finished():
		return
	_advance()
	_refresh()
	if _finished():
		closed.emit()


func settle() -> void:
	if _movie == null and _gen1 == null:
		return
	while not _finished() and _frame() < FRAME_CAP:
		_advance()
	closed.emit()


func _forward(events: Array) -> void:
	for event: Dictionary in events:
		match StringName(event["type"]):
			&"play_music":
				music_requested.emit(int(event["music"]))
			&"play_sfx":
				sfx_requested.emit(int(event["sfx"]))
			&"play_cry":
				cry_requested.emit(int(event["species"]))


func _refresh() -> void:
	if _background == null:
		return
	var image: Image = Gen1OpeningPage.colour(_gen1.lcd.render(), [], _gen1.palettes()) \
		if _gen1 != null else _page.draw(_movie)
	Gen2PicImage.show(_background, image)
	_background.size = Vector2(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)
