class_name Gen2YesNoBox
extends TextureRect

## `YesNoBox` over a screen that owns the question, closed when its hold ends.

signal answered(yes: bool)
## `MenuClickSound`'s `SFX_READ_TEXT_2`, on the press that answers.
signal clicked(sfx: int)

var _page: Gen2MenuPage = null
var _menu: Gen2WorldMenu = null


func _init(page: Gen2MenuPage = null) -> void:
	_page = page
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func set_page(page: Gen2MenuPage) -> void:
	_page = page


func open() -> void:
	_menu = Gen2WorldMenu.yes_no()
	_render()


func close() -> void:
	_menu = null
	visible = false


func is_open() -> bool:
	return _menu != null


func holding() -> bool:
	return _menu != null and _menu.holding()


## The row under the cursor, or -1 when no box is up.
func cursor() -> int:
	return _menu.cursor if _menu != null else -1


func handle_button(button: int) -> bool:
	if _menu == null:
		return false
	if _menu.press_yes_no(button):
		if _menu.just_answered():
			clicked.emit(Gen2Sfx.SFX_READ_TEXT_2)
		if not _menu.holding():
			_render()
	return true


func advance_frame() -> void:
	if _menu == null or not _menu.advance_hold():
		return
	var yes: bool = _menu.answered_yes()
	close()
	answered.emit(yes)


func _render() -> void:
	if _page == null or _menu == null:
		return
	var box: Gen2MenuBox = Gen2MenuBox.yes_no()
	Gen2PicImage.show(self, _page.render(box, _menu.options, _menu.cursor))
	position = Vector2(box.border_position() * Gen2Font.TILE)
	visible = true
