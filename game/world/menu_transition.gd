class_name Gen2MenuTransition
extends RefCounted

## `FadeToMenu`, `CloseSubmenu` and `ExitAllMenus` (`home/map.asm`), spent a frame
## at a time by the owner of the screen. Generation 1 fades nothing: `GBPalWhiteOut`
## is white at once and each screen holds it while it loads.

signal changed

## `ConvertTimePalsIncHL` and `ConvertTimePalsDecHL` walk four rows this far apart.
const FADE_STEP_FRAMES: int = Gen2WorldPalette.FADE_STEP_FRAMES

## `CloseSubmenu` up to its fade, measured: three frames of `ClearBGPalettes`,
## `ReloadTilesetAndPalettes` with the LCD off (fifteen frames on Crystal, twelve
## in its player's room, nine on Gold and Silver) and `WaitBGMap2`'s eight or nine.
const CLOSE_WHITE_FRAMES: Dictionary = {&"crystal": 26, &"gold": 21, &"silver": 21}

## Per screen, the frames white from the press to the screen's first draw and
## from its B to the map back under the menu. Measured with one party member:
## six take three frames longer to draw. Red and Blue agree; Yellow loads Pikachu.
const GEN1_RED_FRAMES: Dictionary = {
	&"pokedex": Vector2i(15, 10), &"party": Vector2i(19, 34),
	&"trainer_card": Vector2i(47, 21),
}
const GEN1_YELLOW_FRAMES: Dictionary = {
	&"pokedex": Vector2i(22, 15), &"party": Vector2i(26, 40),
	&"trainer_card": Vector2i(54, 26),
}

var gen1: bool = false
## The cartridge, which picks the measured frames.
var game: StringName = &"crystal"

## `{frames, order, white_fill, covered}` per step, and the step in flight.
var _steps: Array[Dictionary] = []
var _index: int = 0
var _left: int = 0
var _then: Callable = Callable()


func active() -> bool:
	return not _steps.is_empty()


func order() -> int:
	return int(_steps[_index]["order"]) if active() else Gen2WorldPalette.FADE_IDENTITY


## `FillWhiteBGColor`, which only the way out runs.
func white_fill() -> bool:
	return active() and bool(_steps[_index]["white_fill"])


## All of the screen white rather than the map in one of the fade's rows:
## `ClearBGPalettes` writes every colour `$ffff`, which no row is.
func covered() -> bool:
	return active() and bool(_steps[_index]["covered"])


## `FadeToMenu`, then [param open] once the map is white. [param screen] names
## the Generation 1 screen, and one it has no frames for opens at once.
func fade_to_menu(open: Callable, screen: StringName = &"") -> void:
	if active():
		_finish()
	if gen1:
		_begin(_hold(_gen1_frames(screen).x), open)
		return
	_begin(_fade(Gen2WorldPalette.FADE_OUT_ORDERS, true), open)


## `CloseSubmenu` and `ExitAllMenus`, then [param done] once the map is back. The
## caller has put the menu away and what stood behind it back: the white is over both.
func close_submenu(done: Callable = Callable(), screen: StringName = &"") -> void:
	if active():
		_finish()
	if gen1:
		_begin(_hold(_gen1_frames(screen).y), done)
		return
	var steps: Array[Dictionary] = _hold(int(CLOSE_WHITE_FRAMES.get(game, 26)))
	steps.append_array(_fade(Gen2WorldPalette.FADE_IN_ORDERS, false))
	_begin(steps, done)


func advance_frame() -> void:
	if not active():
		return
	_left -= 1
	if _left > 0:
		return
	_index += 1
	if _index >= _steps.size():
		_finish()
		return
	_left = int(_steps[_index]["frames"])
	changed.emit()


func _gen1_frames(screen: StringName) -> Vector2i:
	return (GEN1_YELLOW_FRAMES if game == &"yellow" else GEN1_RED_FRAMES).get(
		screen, Vector2i.ZERO
	)


func _begin(steps: Array[Dictionary], then: Callable) -> void:
	if steps.is_empty():
		if then.is_valid():
			then.call()
		return
	_steps = steps
	_index = 0
	_left = int(steps[0]["frames"])
	_then = then
	changed.emit()


func _finish() -> void:
	var then: Callable = _then
	_steps = []
	_then = Callable()
	changed.emit()
	if then.is_valid():
		then.call()


static func _hold(frames: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if frames > 0:
		out.append({
			"frames": frames, "order": Gen2WorldPalette.FADE_IDENTITY,
			"white_fill": false, "covered": true,
		})
	return out


static func _fade(orders: Array[int], filled: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row: int in orders:
		out.append({
			"frames": FADE_STEP_FRAMES, "order": row, "white_fill": filled,
			"covered": false,
		})
	return out
