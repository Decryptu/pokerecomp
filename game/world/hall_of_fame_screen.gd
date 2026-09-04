class_name Gen2HallOfFameScreen
extends Control

## The screen behind `halloffame`, embedded in the overworld the way the PC and
## the mart overlays are: the record box, then `AnimateHallOfFame`'s walk over
## the party and the player's own panel. The two pic slides and the palette
## rotations are not here. An induction reads no joypad over its panels and holds
## each for [method Gen2HallOfFame.panel_frames]; `_HallOfFamePC` walks the same
## panels over a stored record and answers A, B and START.

signal closed()

## `PokeAnim_CryNoWait` inside Crystal's ANIM_MON_HOF, pokegold's `PlayMonCry`.
signal cry_requested(species: int)

## `ProfOaksPCRating`'s `PlayMusic MUSIC_NONE` and `PlaySFX`.
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
## How long the page on screen holds before moving on by itself, and its clock.
var _hold_frames: int = 0
var _hold_clock := Gen2WorldAnimation.FrameClock.new()


## [param pages] is [method Gen2HallOfFame.pages]; an empty list closes at once.
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


## How many pages are left, including the one on screen.
func remaining() -> int:
	return maxi(_pages.size() - _index, 0)


func current_page() -> Dictionary:
	if _index < 0 or _index >= _pages.size():
		return {}
	return _pages[_index]


## `_HallOfFamePC.DisplayTeam`'s three: A moves on, B leaves the viewer, which
## is what [member cancelled] says afterwards, and START skips the rest of this
## team. `AnimateHallOfFame` reads none of them.
func handle_button(button: int) -> bool:
	if _hold_frames > 0:
		## Both holds end on `DelayFrames`, which reads no joypad.
		return true
	if button == PokeButton.A:
		advance()
		return true
	if not viewer:
		return false
	if button == PokeButton.B:
		cancelled = true
		closed.emit()
		return true
	if button == PokeButton.START:
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

	## Under the page, so the box borders stay drawn over it.
	_pic = TextureRect.new()
	_pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pic)

	_background = TextureRect.new()
	_background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)


## Hardware frames of whichever page is holding. Public so a test owns its own.
func advance_hold_frames(count: int) -> void:
	for _step: int in count:
		if _hold_frames <= 0:
			return
		_hold_frames -= 1
		if _hold_frames <= 0:
			set_process(false)
			advance()


func _process(delta: float) -> void:
	advance_hold_frames(_hold_clock.tick(delta))


func _refresh() -> void:
	var page: Dictionary = current_page()
	if page.is_empty() or _background == null:
		return
	_hold_frames = _hold_for(page)
	if _hold_frames > 0:
		_hold_clock.reset()
	set_process(_hold_frames > 0)
	if StringName(page.get("kind", &"")) == Gen2HallOfFame.PAGE_MON:
		cry_requested.emit(int(page.get("species", 0)))
	if page.has("sfx"):
		rating_reached.emit(int(page["sfx"]))
	var indices: PackedByteArray = _page_renderer.draw(page)
	var image: Image = Gen2PicImage.from_indices(
		indices, Gen2Screen.WIDTH, Gen2Screen.HEIGHT,
		PokePalette.pic_palette(PackedColorArray([Color.WHITE, Color.BLACK])),
		true
	)
	Gen2PicImage.show(_background, image)
	_background.size = Vector2(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)
	_refresh_pic(page)


## `.SavingRecordText`'s hundred frames, and an induction's own panel count.
## The viewer's panels answer the joypad, so they hold for nothing.
func _hold_for(page: Dictionary) -> int:
	match StringName(page.get("kind", &"")):
		Gen2HallOfFame.PAGE_SAVING:
			return Gen2SavePrompt.SAVING_RECORD_FRAMES
		Gen2HallOfFame.PAGE_MON:
			return 0 if viewer else Gen2HallOfFame.panel_frames(_data)
	return 0


func _refresh_pic(page: Dictionary) -> void:
	if _pic == null:
		return
	_pic.texture = null
	if _data == null:
		return
	var kind: StringName = StringName(page.get("kind", &""))
	if kind == Gen2HallOfFame.PAGE_PLAYER:
		_show_player_pic(bool(page.get("female", false)))
		return
	if kind != Gen2HallOfFame.PAGE_MON:
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


## `HOF_LoadTrainerFrontpic` and `PlaceGraphic` at (12,5), the intro's picture.
func _show_player_pic(female: bool) -> void:
	var cell: Dictionary = Gen2OakSpeech.player_cell(_data, female)
	if cell.is_empty():
		return
	var image: Image = Gen2PicImage.from_indices(
		cell["indices"], int(cell["width"]), int(cell["height"]),
		Gen2OakSpeech.player_palette(_data, female)
	)
	Gen2PicImage.show(_pic, image)
	_pic.size = Vector2(image.get_size())
	var at: Vector2i = Gen2HallOfFamePage.player_pic_position()
	_pic.position = Vector2(
		at.x + Gen2PicImage.frontpic_pad_columns(int(cell["width"]) / Gen2Font.TILE) \
			* Gen2Font.TILE,
		at.y + Gen2HallOfFamePage.pic_size() - image.get_height()
	)
