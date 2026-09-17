class_name Gen2DiplomaScreen
extends Control

## `_Diploma` and `_PrintDiploma`, which are the same page under two loops.
## `_Diploma` is `PlaceDiplomaOnScreen` and `WaitPressAorB_BlinkCursor`, so either
## button closes it. `_PrintDiploma` draws the same page and holds in
## `SendScreenToPrinter`; with nothing on the link both printer variables stay -1,
## which is PRINTER_ERROR_2, and B is the way out. That is the branch a Game Boy
## with no printer takes rather than a refusal invented here. Page 2 is therefore
## never drawn by the printing loop, because `.cancel` skips it, and
## [method preview_page] is what photographs it.

signal closed()
signal music_requested(index: int)

## `MUSIC_PRINTER`, which `Printer_PlayMusic` starts before the send.
const MUSIC_PRINTER: int = 0x5B

## `CheckPrinterStatus`'s `.error_2`, the connection error a link with nothing
## on it reaches.
const STATUS_CONNECTION_ERROR: String = "error_2"

## Yellow's three `Print*` pages hold in `PrintDiplomaPage`'s loop the same way.
const GEN1_MUSIC_PRINTER: Array[int] = [0x20, 163]
const GEN1_PAGES: Array[String] = ["diploma", "high_score", "portrait"]

var _page: Gen2DiplomaPage = null
var _view: TextureRect = null
var _player: String = ""
var _play_time: Dictionary = {}
var _status: String = ""
var _cancel: String = ""
var _printing: bool = false
var _shown_page: int = 1
var _open: bool = false
var _gen1_kind: String = ""
var _gen1_values: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)


## [param printing] is `_PrintDiploma` rather than `_Diploma`. Answers false on
## a cache with no diploma art, which is what the caller refuses the special on
## rather than opening an empty page.
func open(
	data: GameData, player: String, play_time: Dictionary, sends: bool = false
) -> bool:
	_page = Gen2DiplomaPage.from_data(data)
	if _page == null:
		visible = false
		return false
	_player = player
	_play_time = play_time.duplicate()
	_printing = sends
	_status = data.printer_status_string(STATUS_CONNECTION_ERROR) if sends else ""
	_open = true
	visible = true
	if sends:
		music_requested.emit(MUSIC_PRINTER)
	_refresh()
	return true


## [param preview] is the high-score page held for a press rather than printed.
func open_gen1_printer(data: GameData, kind: String, values: Dictionary, preview: bool) -> bool:
	_page = Gen2DiplomaPage.from_data(data)
	if _page == null or kind not in GEN1_PAGES \
			or (not preview and data.printer_status_string(STATUS_CONNECTION_ERROR).is_empty()):
		visible = false
		return false
	_gen1_kind = kind
	_gen1_values = values.duplicate()
	_printing = not preview
	_status = data.printer_status_string(STATUS_CONNECTION_ERROR) if _printing else ""
	_cancel = data.printer_status_string("press_b")
	_open = true
	visible = true
	if _printing:
		music_requested.emit(MUSIC_PRINTER)
	_refresh()
	return true


func page() -> Gen2DiplomaPage:
	return _page


func gen1_kind() -> String:
	return _gen1_kind


func printing() -> bool:
	return _printing


## Which of the two pages is on screen, for a check that would otherwise read
## pixels back.
func shown_page() -> int:
	return _shown_page


func handle_button(button: int) -> bool:
	if not _open:
		return false
	## `CheckCancelPrint` reads B alone; `WaitPressAorB_BlinkCursor` reads both.
	if button == PokeButton.B or (not _printing and button == PokeButton.A):
		close()
	return true


## The screenshot driver's own second page, which no loop here reaches: with a
## printer on the link `SendScreenToPrinter` would return without carry and
## `PrintDiplomaPage2` would draw it.
func preview_page(page_number: int) -> void:
	_shown_page = clampi(page_number, 1, 2)
	_refresh()


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
	if not _gen1_kind.is_empty():
		Gen2PicImage.show(_view, _page.render_gen1_printer(_gen1_kind, _gen1_values, _status, _cancel))
		return
	Gen2PicImage.show(_view, _page.render(
		_shown_page, _player, _play_time,
		_status if _shown_page == 1 else ""
	))
