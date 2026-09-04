class_name Gen2UnownPrinterScreen
extends Control

## `_UnownPrinter`'s `.joy_loop`: left and right walk the twenty-six letters and
## the vacant slot behind them, wrapping either way, B leaves and A sends the stamp
## to the printer. A therefore reaches `SendScreenToPrinter`, which prints whatever
## `CheckPrinterStatus` last found; with nothing on the link both printer variables
## stay -1, which is PRINTER_ERROR_2, and B is the way back. There is no printer to
## plug in, so that is the whole of what A can do here rather than a refusal
## invented for it.

signal closed()
signal music_requested(index: int)
signal map_music_requested()

const MUSIC_PRINTER: int = Gen2DiplomaScreen.MUSIC_PRINTER
const STATUS_CONNECTION_ERROR: String = Gen2DiplomaScreen.STATUS_CONNECTION_ERROR

var _page: Gen2UnownPrinterPage = null
var _view: TextureRect = null
## `wJumptableIndex`, which this routine uses as the browser's own cursor.
var _slot: int = 0
var _status: String = ""
var _printing: bool = false
var _open: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)


## Answers false on a cache with no printer glyphs, and on `ld a, [wUnownDex] /
## and a / ret z`: with no Unown caught the routine returns before it draws
## anything.
func open(data: GameData, caught: int) -> bool:
	_page = Gen2UnownPrinterPage.from_data(data)
	if _page == null or caught <= 0:
		visible = false
		return false
	_status = data.printer_status_string(STATUS_CONNECTION_ERROR)
	_slot = 0
	_printing = false
	_open = true
	visible = true
	_refresh()
	return true


func slot() -> int:
	return _slot


func printing() -> bool:
	return _printing


func page() -> Gen2UnownPrinterPage:
	return _page


func handle_button(button: int) -> bool:
	if not _open:
		return false
	if _printing:
		## `CheckCancelPrint` reads B alone, and the send never ends on its own.
		if button == PokeButton.B:
			_printing = false
			map_music_requested.emit()
			_refresh()
		return true
	match button:
		PokeButton.B:
			close()
		PokeButton.A:
			_printing = true
			music_requested.emit(MUSIC_PRINTER)
			_refresh()
		PokeButton.LEFT:
			## `.press_left`: zero becomes `NUM_UNOWN + 1` before the decrement,
			## so the vacant slot is what the first letter wraps back to.
			_slot = Gen2UnownPrinterPage.SLOTS - 1 if _slot == 0 else _slot - 1
			_refresh()
		PokeButton.RIGHT:
			_slot = 0 if _slot >= Gen2UnownPrinterPage.SLOTS - 1 else _slot + 1
			_refresh()
	return true


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	closed.emit()


func _refresh() -> void:
	if _page == null:
		return
	if _view == null:
		_view = TextureRect.new()
		_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_view)
	var image: Image = _page.render_stamp(_slot) if _printing else _page.render(_slot)
	if _printing:
		_page.draw_status(image, _status)
	Gen2PicImage.show(_view, image)
