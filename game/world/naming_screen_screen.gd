class_name Gen2NamingScreenScreen
extends Control

## The naming screen (`engine/menus/naming_screen.asm`), embedded the way the
## trainer card and the Hall of Fame are.
##
## [Gen2NamingScreen] owns the walk and [Gen2NamingScreenPage] the tiles; this
## is the node between them. Input is the eight hardware buttons and nothing
## else, so a test presses a button rather than a key.

## Carries the stored entry. `NamingScreen_StoreEntry` runs on END and on
## nothing else, so a caller that never sees this signal has no name to take.
signal closed(name: String)

## `wNamingScreenType`'s three that a screen here opens, all the player's
## keyboard; NAME_MON and NAME_BOX differ only in the length cap.
const KIND_PLAYER: StringName = &"player"
const KIND_MON: StringName = &"mon"
const KIND_BOX: StringName = &"box"
## `_ComposeMailMessage`, which is not a `wNamingScreenType` at all: its own
## routine with its own keyboard. A caller reads the raw buffer off
## [method model] rather than the `closed` argument, a mail message being two
## fixed-width lines and a break rather than a name.
const KIND_MAIL: StringName = &"mail"

## `data/sprites/sprites.asm`'s rows for the labels `.Rival`, `.Mom` and `.Box`
## name. The three indices are the same in both pins.
const SPRITE_RIVAL: int = 0x04
const SPRITE_MOM: int = 0x0C
const SPRITE_POKE_BALL: int = 0x54

## `'♂'` and `'♀'` at `.Pokemon`'s `hlcoord 1, 2`; `GetGender`'s carry writes
## nothing, which is zero here.
const MALE_SIGN: int = 0xEF
const FEMALE_SIGN: int = 0xF5


## `farcall GetGender` for a Pokemon whose DVs are known.
static func gender_sign(data: GameData, species: int, dvs: int) -> int:
	if data == null or dvs < 0:
		return 0
	match Gen2BattleMon.gender_for(data, species, dvs):
		Gen2BattleMon.GENDER_MALE:
			return MALE_SIGN
		Gen2BattleMon.GENDER_FEMALE:
			return FEMALE_SIGN
	return 0

var _screen: Gen2NamingScreen = null
var _page: Gen2NamingScreenPage = null
var _prompt: String = ""
var _background: TextureRect = null
## The strip `NamingScreenJumptable`'s row loads into `vTiles0 tile $00`, and
## `.Pokemon`'s `♂`/`♀`/nothing. See [method set_icon].
var _icon: PackedByteArray = PackedByteArray()
var _gender: int = 0

## The four colours the screen is drawn through, index 0 the field and 3 the
## ink. Empty is black-on-white; the intro sets it because
## `RotateThreePalettesRight` fades this screen out before `ClearTilemap`.
var palette: PackedColorArray = PackedColorArray():
	set(value):
		palette = value
		_refresh()



## `NamingScreenJumptable`'s own strings. One keyboard names a Pokemon, the
## player and the rival; only the line over it differs, so it is the caller's.
const PROMPT_PLAYER: String = "YOUR NAME?"
const PROMPT_RIVAL: String = "RIVAL'S NAME?"


func open(data: GameData, prompt: String, kind: StringName = KIND_PLAYER) -> bool:
	_prompt = prompt
	_page = Gen2NamingScreenPage.from_data(data)
	if _page == null or not _page.ready():
		return false
	_screen = _model(data, kind)
	if _screen.rows().is_empty():
		return false
	if is_inside_tree():
		_refresh()
	return true


static func _model(data: GameData, kind: StringName) -> Gen2NamingScreen:
	if kind == KIND_MON:
		return Gen2NamingScreen.for_mon(data)
	if kind == KIND_BOX:
		return Gen2NamingScreen.for_box(data)
	if kind == KIND_MAIL:
		return Gen2NamingScreen.for_mail(data)
	return Gen2NamingScreen.for_player(data)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)
	_background = TextureRect.new()
	_background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)
	if _screen != null:
		_refresh()


func model() -> Gen2NamingScreen:
	return _screen


## `NamingScreenJumptable`'s icon, which every row but `.Friend` spawns and is
## what those rows differ in. [param gender] is `.Pokemon`'s sign, or zero.
func set_icon(strip: PackedByteArray, gender: int = 0) -> void:
	_icon = strip
	_gender = gender
	_refresh()


## `.Pokemon`'s icon and sign by species, and the other rows' by sprite number.
func set_species_icon(data: GameData, species: int, gender: int = 0) -> void:
	if data == null:
		return
	set_icon(data.species_icon_indices(species), gender)


func set_sprite_icon(data: GameData, sprite_number: int) -> void:
	if data == null:
		return
	set_icon(data.overworld_sprite_indices(sprite_number))


## `NamingScreenJoypadLoop`'s `.ReadButtons`, in its own order: A, then B, then
## START, then SELECT. The d-pad is `NamingScreen_AnimateCursor`'s own read and
## is not in that list, so it never ends the screen.
func handle_button(button: int) -> bool:
	if _screen == null:
		return false
	match button:
		PokeButton.A:
			if _screen.press_a() == Gen2NamingScreen.RESULT_END:
				closed.emit(_screen.stored_name())
				return true
		PokeButton.B:
			_screen.press_b()
		PokeButton.START:
			_screen.press_start()
		PokeButton.SELECT:
			_screen.press_select()
		_:
			if not PokeButton.is_direction(button):
				return false
			_screen.move(PokeButton.vector(button))
	_refresh()
	return true


func _refresh() -> void:
	if _background == null or _page == null or _screen == null:
		return
	var indices: PackedByteArray = _page.draw(_screen, _prompt, _icon, _gender)
	Gen2PicImage.show(_background, Gen2PicImage.from_indices(
		indices, Gen2Screen.WIDTH, Gen2Screen.HEIGHT, _colors()
	))
	_background.size = Vector2(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)

## `SCGB_DIPLOMA`, which is two colours here the way every other 1bpp screen in
## this project is, unless a caller has handed one in.
func _colors() -> PackedColorArray:
	return palette if palette.size() == 4 else PokePalette.pic_palette(
		PackedColorArray([Color.WHITE, Color.BLACK])
	)
