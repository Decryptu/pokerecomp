class_name Gen2HallOfFameScreen
extends Control

## The screen behind `halloffame`, embedded in the overworld the way the PC and
## the mart overlays are: the record box, then `AnimateHallOfFame`'s walk over
## the party and the player's own panel, advanced by A. The two pic slides and
## the palette rotations are not here, and the source's 60 frames a panel are a
## key press instead, there being no animation to watch. `_HallOfFamePC` reuses
## the same walk over a stored record.

signal closed()

## `ProfOaksPCRating`'s `PlayMusic MUSIC_NONE` and `PlaySFX`, which reach the
## overworld's own player the way the Pokedex's cry does.
signal rating_reached(sfx: int)

const BACKDROP: Color = Color.WHITE

## Whether this is `_HallOfFamePC`'s viewer rather than `AnimateHallOfFame`'s
## induction: only the viewer answers B and START.
var viewer: bool = false
## Whether B closed it, which is `.b_button`'s carry and the way out of the
## machine's own loop.
var cancelled: bool = false

var _data: GameData = null
var _pages: Array = []
var _index: int = 0
var _page_renderer: Gen2HallOfFamePage = null
var _background: TextureRect = null
var _pic: TextureRect = null
## `HallOfFame_FadeOutMusic`'s `ld c, 100` behind the record box, and its clock.
var _saving_frames: int = 0
var _saving_clock := Gen2WorldAnimation.FrameClock.new()


## [param pages] is [method Gen2HallOfFame.pages]. An empty list closes at once
## rather than showing a blank screen.
func set_context(data: GameData, pages: Array) -> void:
	_data = data
	_pages = pages
	_page_renderer = Gen2HallOfFamePage.from_data(data)
	_index = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)
	if _page_renderer == null or _pages.is_empty():
		closed.emit()
		return
	_build()
	_refresh()


## How many pages are left, including the one on screen. Drives the scene tests
## and the screenshot tool without reaching into the array.
func remaining() -> int:
	return maxi(_pages.size() - _index, 0)


func current_page() -> Dictionary:
	if _index < 0 or _index >= _pages.size():
		return {}
	return _pages[_index]


## A moves on, matching every other text pause in the overworld. There is no way
## back: the cartridge's panels do not rewind either.
##
## `_HallOfFamePC.DisplayTeam` adds two: B leaves the viewer, which is what
## [member cancelled] says afterwards, and START skips the rest of this team.
## `AnimateHallOfFame` reads neither, so an induction ignores them.
func handle_button(button: int) -> bool:
	if _saving_frames > 0:
		## `HallOfFame_FadeOutMusic` ends on `DelayFrames`, which reads nothing.
		return true
	if button == Gen2Button.A:
		advance()
		return true
	if not viewer:
		return false
	if button == Gen2Button.B:
		cancelled = true
		closed.emit()
		return true
	if button == Gen2Button.START:
		_index = _pages.size()
		closed.emit()
		return true
	return false


func advance() -> void:
	_index += 1
	if _index >= _pages.size():
		closed.emit()
		return
	_refresh()


func _build() -> void:
	add_child(Gen2Screen.Field.create(BACKDROP))

	## The pic sits under the page so the bottom box's border stays drawn over
	## it, the way the hardware's window does.
	_pic = TextureRect.new()
	_pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pic)

	_background = TextureRect.new()
	_background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)


## Hardware frames of the record box. Public so a test owns its own.
func advance_saving_frames(count: int) -> void:
	for _step: int in count:
		if _saving_frames <= 0:
			return
		_saving_frames -= 1
		if _saving_frames <= 0:
			set_process(false)
			advance()


func _process(delta: float) -> void:
	advance_saving_frames(_saving_clock.tick(delta))


func _refresh() -> void:
	var page: Dictionary = current_page()
	if page.is_empty() or _background == null:
		return
	if StringName(page.get("kind", &"")) == Gen2HallOfFame.PAGE_SAVING:
		_saving_frames = Gen2SavePrompt.SAVING_RECORD_FRAMES
		_saving_clock.reset()
		set_process(true)
	if page.has("sfx"):
		rating_reached.emit(int(page["sfx"]))
	var indices: PackedByteArray = _page_renderer.draw(page)
	var image: Image = Gen2PicImage.from_indices(
		indices, Gen2Screen.WIDTH, Gen2Screen.HEIGHT,
		Gen2Palette.pic_palette(PackedColorArray([Color.WHITE, Color.BLACK])),
		true
	)
	Gen2PicImage.show(_background, image)
	_background.size = Vector2(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)
	_refresh_pic(page)


func _refresh_pic(page: Dictionary) -> void:
	if _pic == null:
		return
	_pic.texture = null
	if _data == null or StringName(page.get("kind", &"")) != Gen2HallOfFame.PAGE_MON:
		return
	var species: int = int(page.get("species", 0))
	var unown_form: int = int(page.get("unown_form", 0))
	var pic: Dictionary = _data.unown_pic(unown_form - 1) if unown_form > 0 \
		else _data.species_pic(species)
	if pic.is_empty():
		return
	var image: Image = Gen2PicImage.from_atlas(
		_data.atlas_indices(pic["atlas"]), _data.atlas(pic["atlas"]), pic,
		_data.palette(species, bool(page.get("shiny", false)))
	)
	Gen2PicImage.show(_pic, image)
	_pic.size = Vector2(image.get_size())
	## The source centres a seven-tile cell on (6,5); a pic smaller than that
	## cell is drawn at its bottom, the way _PrepMonFrontpic places it.
	var cell: int = Gen2HallOfFamePage.pic_size()
	var at: Vector2i = Gen2HallOfFamePage.pic_position()
	_pic.position = Vector2(
		at.x + (cell - image.get_width()) / 2.0,
		at.y + cell - image.get_height()
	)
