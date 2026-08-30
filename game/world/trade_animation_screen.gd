class_name Gen2TradeAnimationScreen
extends Control

## [Gen2TradeAnimation] with [Gen2TradeAnimationPage] in front of it, for a host
## that has a screen. The trade itself is already committed when this opens, the
## way `NPCTrade` calls `DoNPCTrade` before its animation.

signal closed()
signal cry_requested(species: int)
signal sfx_requested(index: int)
signal music_requested(index: int)

const FRAME_CAP: int = 20000

var _movie: Gen2TradeAnimation = null
var _page: Gen2TradeAnimationPage = null
var _background: TextureRect = null


## [param context] is what [method Gen2TradeAnimation.create] takes.
func set_context(
	data: GameData, context: Dictionary, half: int = Gen2TradeAnimation.PLAYER_1
) -> void:
	_page = Gen2TradeAnimationPage.from_data(data)
	_movie = Gen2TradeAnimation.create(
		data, Gen2BattleAnimData.from_game_data(data), context, half
	)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)
	if _movie == null or _page == null:
		closed.emit()
		return
	_background = TextureRect.new()
	_background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)
	_forward(_movie.drain_events())
	_refresh()


## `TradeAnimation` reads no joypad, so a press is spent rather than passed on.
func handle_button(_button: int) -> bool:
	return true


func movie() -> Gen2TradeAnimation:
	return _movie


func advance_frame() -> void:
	if _movie == null or _movie.finished():
		return
	_forward(_movie.advance_frame())
	_refresh()
	if _movie.finished():
		closed.emit()


func settle() -> void:
	if _movie == null:
		return
	while not _movie.finished() and _movie.frame() < FRAME_CAP:
		_forward(_movie.advance_frame())
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
	Gen2PicImage.show(_background, _page.draw(_movie))
	_background.size = Vector2(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)
