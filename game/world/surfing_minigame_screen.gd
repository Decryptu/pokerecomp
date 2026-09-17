class_name Gen1SurfingMinigameScreen
extends Control

## [Gen1SurfingMinigame] over the map, on the overworld's pump; the pad is read
## held, so a direction rides [method release_button] too.

signal closed(hi_score: int)
signal sfx_requested(index: int)
signal music_requested(song: Array[int])
signal pikachu_clip_requested(index: int)
signal tempo_requested(tempo: int)

const FRAME_CAP: int = 60000
const BUTTONS: Dictionary = {
	PokeButton.A: Gen1SurfingMinigame.PAD_A,
	PokeButton.SELECT: Gen1SurfingMinigame.PAD_SELECT,
	PokeButton.LEFT: Gen1SurfingMinigame.PAD_LEFT,
	PokeButton.RIGHT: Gen1SurfingMinigame.PAD_RIGHT,
}

var _game: Gen1SurfingMinigame = null
var _view: TextureRect = null
var _open: bool = false


func open(
	data: GameData, rng: RandomNumberGenerator, hi_score: int, surfing_pikachu: bool,
	select_quits: bool
) -> bool:
	_game = Gen1SurfingMinigame.create(data, rng, hi_score, surfing_pikachu, select_quits)
	if _game == null:
		visible = false
		return false
	_open = true
	visible = true
	_refresh()
	return true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)
	_refresh()


func game() -> Gen1SurfingMinigame:
	return _game


func handle_button(button: int) -> bool:
	if _open and BUTTONS.has(button):
		_game.press(int(BUTTONS[button]))
	return true


func release_button(button: int) -> void:
	if _open and BUTTONS.has(button):
		_game.release(int(BUTTONS[button]))


func advance_frame() -> void:
	if not _open or _game.finished():
		return
	_forward(_game.advance_frame())
	tempo_requested.emit(_game.tempo_request)
	_refresh()
	if _game.finished():
		_close()


func settle() -> void:
	while _open and not _game.finished() and _game.frame() < FRAME_CAP:
		_forward(_game.advance_frame())
	if _open:
		_close()


func _close() -> void:
	_open = false
	visible = false
	closed.emit(_game.hi_score())


func _forward(events: Array) -> void:
	for event: Dictionary in events:
		match StringName(event["type"]):
			&"play_music":
				music_requested.emit([int(event["bank"]), int(event["music"])] as Array[int])
			&"play_sfx":
				sfx_requested.emit(int(event["sfx"]))
			&"play_pikachu_clip":
				pikachu_clip_requested.emit(int(event["index"]))


func render() -> Image:
	return Gen1OpeningPage.colour(_game.lcd.render(), _game.blocks(), _game.palettes(), _game.lcd.slots)


func _refresh() -> void:
	if _game == null or not is_inside_tree():
		return
	if _view == null:
		_view = TextureRect.new()
		_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_view)
	Gen2PicImage.show(_view, render())
	_view.size = Vector2(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)
