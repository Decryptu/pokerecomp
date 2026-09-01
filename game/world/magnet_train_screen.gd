class_name Gen2MagnetTrainScreen
extends Control

## [Gen2MagnetTrain] with [Gen2MagnetTrainPage] in front of it, the way
## [Gen2TradeAnimationScreen] stands over a trade: `MagnetTrain` runs its own
## loop, so this owns the screen until the train has arrived.

signal closed()
signal sfx_requested(index: int)
signal music_requested(index: int)

const FRAME_CAP: int = 2000

var _movie: Gen2MagnetTrain = null
var _page: Gen2MagnetTrainPage = null
var _background: TextureRect = null


func open(
	data: GameData, tileset: Gen2WorldTileset, to_goldenrod: bool,
	time_of_day: int, female: bool
) -> bool:
	_page = Gen2MagnetTrainPage.create(data, tileset, time_of_day, female)
	if _page == null:
		return false
	_movie = Gen2MagnetTrain.create(to_goldenrod)
	return true


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


func handle_button(_button: int) -> bool:
	return true


func movie() -> Gen2MagnetTrain:
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


func _refresh() -> void:
	if _background == null:
		return
	Gen2PicImage.show(_background, _page.draw(_movie))
	_background.size = Vector2(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)
