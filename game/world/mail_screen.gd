class_name Gen2MailScreen
extends Control

## `ReadAnyMail` (`engine/pokemon/mail_2.asm`), embedded the way the Hall of
## Fame viewer is.
##
## The routine loads the type's own graphics, prints the message and the author
## over them, and then does nothing but wait: `.loop` reads A, B and START and
## returns on any of the first two. [Gen2MailPage] owns the picture; this is the
## node between it and the buttons.
##
## START is `PrintMailAndExit`, the Game Boy Printer, which this project has no
## transport for. It is answered as a press that does nothing rather than left
## to fall through to whatever is behind the screen.

signal closed()

## The screen has no field of its own: `ClearBGPalettes` and `DisableLCD` run
## before the type's graphics are loaded, so the surround is the mail's own
## background colour once `LoadMailPalettes` has run.
var _data: GameData = null
var _mail: Gen2SaveMail = null
var _page: Gen2MailPage = null
var _background: TextureRect = null


func set_context(data: GameData, mail: Gen2SaveMail) -> void:
	_data = data
	_mail = mail
	_page = Gen2MailPage.from_data(data)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)
	if _page == null or not _page.ready() or _mail == null:
		closed.emit()
		return
	_build()
	_refresh()


## `.loop`: A and B leave, START reaches the printer and comes back. Nothing
## else is read, so the d-pad does not close the screen.
func handle_button(button: int) -> bool:
	if button == Gen2Button.A or button == Gen2Button.B:
		closed.emit()
		return true
	return button == Gen2Button.START


func _build() -> void:
	var colours: PackedColorArray = _colours()
	add_child(Gen2Screen.Field.create(
		colours[0] if colours.size() > 0 else Color.WHITE
	))

	_background = TextureRect.new()
	_background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)


func _refresh() -> void:
	var indices: PackedByteArray = _page.draw(_mail)
	Gen2PicImage.show(_background, Gen2PicImage.from_indices(
		indices, Gen2Screen.WIDTH, Gen2Screen.HEIGHT, _colours()
	))
	_background.size = Vector2(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)


## `LoadMailPalettes`, whole: this is the one screen in the project drawn
## through four cartridge colours rather than a white-to-black pair.
func _colours() -> PackedColorArray:
	if _data == null or _mail == null:
		return Gen2Palette.pic_palette(PackedColorArray([Color.WHITE, Color.BLACK]))
	return _data.mail_palette(Gen2MailPage.palette_index(_mail))
