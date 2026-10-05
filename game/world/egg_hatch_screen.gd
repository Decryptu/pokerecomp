class_name Gen2EggHatchScreen
extends Control

## `HatchEggs` and its `EggHatch_AnimationSequence`, one party egg at a time,
## over rows [method Gen2WorldPartyHost.hatch_egg] has already written; this owns
## the nickname. Counts no `DelayFrames` states were measured on a Crystal dump.

signal named(party_index: int, nickname: String)
signal closed()
signal cry_requested(species: int)
signal sfx_requested(index: int)
signal music_requested(index: int)

## constants/music_constants.asm.
const MUSIC_NONE: int = 0
const MUSIC_EVOLUTION: int = 0x22
const TILE: int = Gen2Font.TILE
const BOX: int = Gen2PicImage.FRONTPIC_TILES
## The egg's and the hatchling's 7x7 blocks, which `PadFrontpic` pads into.
const EGG_AT: Vector2i = Vector2i(7, 4)
const HATCHLING_AT: Vector2i = Vector2i(6, 3)

## `BlankScreen` and the LCD-off loads before `MUSIC_EVOLUTION`, then the egg's
## `Hatch_UpdateFrontpicBGMapCenter`.
const MUSIC_FRAME: int = 18
const EGG_FRAME: int = 27
const OPENING_FRAMES: int = 80 + 1  ## `ld c, 80`, and `hSCX` shows a VBlank later.
const WOBBLE_PASSES: int = 8
## `EggHatch_DoAnimFrame`'s own `DelayFrame` plus `ld c, 2`.
const WOBBLE_HALF_FRAMES: int = 3
const PASS_TAIL_FRAMES: int = 16  ## `ld c, 16` at the end of every pass.
## `hSCX` 2 and `wGlobalAnimXOffset` -2 first: egg and cracks move left, then right.
const WOBBLE_SHIFT: int = 2

## Struct coordinates, x first as `InitSpriteAnimStruct` takes them. Gold and
## Silver's `EggHatch_CrackShell` leaves out the `+ 4`.
const CRACK_X: int = 88
const CRACK_Y: int = 76
const GOLD_SILVER_CRACK_LIFT: int = 4
## `.SpriteData` as [x, y, flips, angle]; `shell_fragment` calls its x y.
const FRAGMENTS: Array = [
	[84, 72, 0x00, 0x3C], [92, 72, 0x20, 0x04], [84, 80, 0x00, 0x30], [92, 80, 0x20, 0x10],
	[84, 88, 0x40, 0x24], [92, 88, 0x60, 0x1C], [80, 76, 0x00, 0x36], [96, 76, 0x20, 0x0A],
	[80, 84, 0x40, 0x2A], [96, 84, 0x60, 0x16],
]
const OAM_X_FLIP: int = 0x20
const OAM_Y_FLIP: int = 0x40
## `SpriteAnimFunc_RevealNewMon`: the dead piece is still drawn the pass it dies.
const FRAGMENT_STEP: int = 8
const FRAGMENT_LAST_RADIUS: int = 0x80
const FRAGMENT_ANGLE_FLIP: int = 0x20
## Frames after `.done` shows: the hatchling's block, the loop, `AnimateFrontpic`.
const HATCHLING_FRAME: int = 7
const FRAGMENT_LOOP_FRAME: int = 11
const ANIMATE_FRAME: int = FRAGMENT_LOOP_FRAME + 129 + 1

enum Phase {
	HUH,
	BLANK,
	OPENING,
	WOBBLE,
	FRAGMENTS,
	ANIMATE,
	CRY,
	HATCHED,
	ASK_NICKNAME,
	CLEARING,
	NAMING,
	DONE,
}

var _data: GameData = null
var _audio: Gen2AudioPlayer = null
var _sine: Gen2BattleAnimData = null
var _hatches: Array = []
var _index: int = 0
var _phase: int = Phase.DONE
var _frames: int = 0
var _counter: int = 0
var _halves_left: int = 0
var _half_frames: int = 0
var _shift: int = 0
var _cracks: int = 0
## `wOBPals1`'s first palette, which `_CGB_Evolution` leaves as the overworld's.
var _object_colors: PackedColorArray = PackedColorArray()
var _pic_origin: Vector2i = EGG_AT
var _pic_pad: Vector2i = Vector2i.ZERO
var _nickname_forced: bool = false
var menu_transition: Gen2MenuTransition = null
var _animation: Gen2PicAnimation = null
var _animation_pixels: PackedByteArray = PackedByteArray()
var _sfx_watch: Dictionary = {}

var _backdrop: Gen2Screen.Field = null
var _pic: TextureRect = null
var _sprites: TextureRect = null
var _text_box: Gen2TextBox = null
var _yes_no: Gen2YesNoBox = null
var _naming: Gen2NamingScreenScreen = null


## [param hatches] is one [method Gen2WorldPartyHost.hatch_egg] summary per egg in
## party order. [param forced] is the Nuzlocke's keyboard without the YES/NO.
func set_context(
	data: GameData, hatches: Array, forced: bool = false,
	object_colors: PackedColorArray = PackedColorArray()
) -> void:
	_data = data
	_hatches = hatches.duplicate(true)
	_index = 0
	_nickname_forced = forced
	_object_colors = object_colors


func set_audio_player(player: Gen2AudioPlayer) -> void:
	_audio = player


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)
	if _data == null or _hatches.is_empty():
		closed.emit()
		return
	_sine = Gen2BattleAnimData.from_game_data(_data)
	_build()
	_begin_hatch()


func remaining() -> int:
	return maxi(_hatches.size() - _index, 0)


## `SCGB_EVOLUTION`: what hatched is drawn in its own colours.
func _hatch_shiny() -> bool:
	return bool(current_hatch().get("shiny", false))


func current_hatch() -> Dictionary:
	if _index < 0 or _index >= _hatches.size():
		return {}
	return _hatches[_index]


func phase() -> int:
	return _phase


## Whether the sequence stands on a press rather than on a count.
func awaiting_press() -> bool:
	if _phase in [Phase.ASK_NICKNAME, Phase.NAMING]:
		return true
	if _text_box == null or not _text_box.visible or _text_box.is_revealing():
		return false
	return _phase == Phase.HATCHED or _text_box.has_pages_left()


func text_lines() -> PackedStringArray:
	if _text_box == null or not _text_box.visible:
		return PackedStringArray()
	return _text_box.text_lines()


func nickname_cursor() -> int:
	return _yes_no.cursor() if _yes_no != null else -1


func naming_screen() -> Gen2NamingScreenScreen:
	return _naming


## `PromptButton` takes A or B and clicks; `YesNoBox` answers B as NO, which is
## `.nonickname`.
func handle_button(button: int) -> bool:
	if _phase == Phase.NAMING and _naming != null:
		return _naming.handle_button(button)
	if _yes_no != null and _yes_no.is_open():
		return _yes_no.handle_button(button)
	if button != PokeButton.A and button != PokeButton.B:
		return false
	if _text_box == null or not _text_box.visible:
		return false
	if _text_box.is_revealing() or _text_box.has_pages_left():
		_text_box.advance()
		return true
	if _phase == Phase.HATCHED:
		_text_box.advance()
		_open_nickname_question()
		return true
	return false


func _build() -> void:
	_backdrop = Gen2Screen.Field.create(Color.WHITE)
	_backdrop.visible = false
	add_child(_backdrop)

	_pic = TextureRect.new()
	_pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pic.visible = false
	add_child(_pic)

	_sprites = TextureRect.new()
	_sprites.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprites.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sprites)

	_yes_no = Gen2YesNoBox.new(Gen2MenuPage.from_data(_data))
	_yes_no.answered.connect(_answer_nickname)
	add_child(_yes_no)

	_text_box = Gen2TextBox.for_screen(_data)
	_text_box.prompt_answered.connect(sfx_requested.emit)
	add_child(_text_box)


## `Text_BreedHuh`, over the map or the last hatchling's screen.
func _begin_hatch() -> void:
	if current_hatch().is_empty():
		_phase = Phase.DONE
		closed.emit()
		return
	if _index == 0:
		_backdrop.visible = false
		_pic.visible = false
	_yes_no.close()
	_phase = Phase.HUH
	_show_text(Gen2WorldPartyHost.HUH_TEXT)


func _show_text(text: String, prompt: bool = false) -> void:
	if _text_box == null:
		return
	_text_box.visible = true
	_text_box.show_text(text, prompt)


func advance_frame() -> void:
	if _phase in [Phase.DONE, Phase.CLEARING, Phase.NAMING] or _data == null:
		return
	if _yes_no.is_open():
		_yes_no.advance_frame()
		return
	if _text_box != null and _text_box.visible:
		_text_box.advance_frame()
		if _text_box.is_revealing() or _text_box.has_pages_left():
			return
	match _phase:
		Phase.HUH:
			_open_sequence()
		Phase.BLANK:
			_advance_blank()
		Phase.OPENING:
			if _spend():
				_begin_wobble()
		Phase.WOBBLE:
			_advance_wobble()
		Phase.FRAGMENTS:
			_advance_fragments()
		Phase.ANIMATE:
			_advance_frontpic_animation()
		Phase.CRY:
			if not _sfx_playing():
				_open_hatched_text()
		Phase.ASK_NICKNAME:
			## `YesNoBox` opens once `PrintText` returns.
			_yes_no.open()


func _spend() -> bool:
	_frames -= 1
	return _frames <= 0


func _sfx_playing() -> bool:
	return _audio != null and _audio.still_waiting(_sfx_watch)


## `EggHatch_AnimationSequence` up to its `ld c, 80`.
func _open_sequence() -> void:
	_text_box.visible = false
	_backdrop.visible = true
	_pic.visible = false
	_shift = 0
	_cracks = 0
	_draw_sprites([])
	music_requested.emit(MUSIC_NONE)
	_phase = Phase.BLANK
	_frames = 0


func _advance_blank() -> void:
	_frames += 1
	if _frames == MUSIC_FRAME:
		music_requested.emit(MUSIC_EVOLUTION)
	if _frames < EGG_FRAME:
		return
	_pic.visible = true
	_draw_egg()
	_phase = Phase.OPENING
	_frames = OPENING_FRAMES


func _begin_wobble() -> void:
	_counter = 0
	_phase = Phase.WOBBLE
	_start_pass()


## `.outerloop`: pass e wobbles e times.
func _start_pass() -> void:
	if _counter >= WOBBLE_PASSES:
		_finish_wobble()
		return
	_counter += 1
	_halves_left = _counter * 2
	_half_frames = WOBBLE_HALF_FRAMES
	_set_shift(WOBBLE_SHIFT)


func _advance_wobble() -> void:
	if _halves_left > 0:
		_half_frames -= 1
		if _half_frames > 0:
			return
		_halves_left -= 1
		_half_frames = WOBBLE_HALF_FRAMES
		if _halves_left > 0:
			_set_shift(-_shift)
			return
		_frames = PASS_TAIL_FRAMES
		return
	if _spend():
		_crack_shell()
		_start_pass()


func _set_shift(shift: int) -> void:
	_shift = shift
	_place_pic()
	_draw_cracks()


## `EggHatch_CrackShell`: `dec a / and $7` cracks after passes 2, 4 and 6.
func _crack_shell() -> void:
	var step: int = (_counter - 1) & 0x7
	if step == 0x7 or (step & 1) == 0:
		return
	_cracks += 1
	sfx_requested.emit(Gen2Sfx.SFX_EGG_CRACK)


## `.done`: the scroll put back, `ClearSprites` and the shell thrown.
func _finish_wobble() -> void:
	_shift = 0
	_cracks = 0
	_place_pic()
	sfx_requested.emit(Gen2Sfx.SFX_EGG_HATCH)
	_sfx_watch = {}
	_phase = Phase.FRAGMENTS
	_frames = 0
	_draw_fragments(0)


func _advance_fragments() -> void:
	_frames += 1
	if _frames == HATCHLING_FRAME:
		_draw_species(int(current_hatch().get("species", 0)))
	_draw_fragments(maxi(_frames - FRAGMENT_LOOP_FRAME + 1, 0))
	if _frames >= ANIMATE_FRAME and not _sfx_playing():
		_draw_sprites([])
		_open_frontpic_animation()


## `SpriteAnimFunc_RevealNewMon`'s [param update]th pass: the radius from before
## the `add 8`, the angle flipped by $20 first.
func _draw_fragments(update: int) -> void:
	var drawn: int = mini(update, FRAGMENT_LAST_RADIUS / FRAGMENT_STEP - 1)
	if update > FRAGMENT_LAST_RADIUS / FRAGMENT_STEP:
		_draw_sprites([])
		return
	var radius: int = drawn * FRAGMENT_STEP
	var flip: int = FRAGMENT_ANGLE_FLIP if drawn % 2 == 0 else 0
	var sprites: Array = []
	for piece: Array in FRAGMENTS:
		var angle: int = int(piece[3]) ^ flip
		sprites.append([
			int(piece[0]) + _wave(angle + 0x10, radius), int(piece[1]) + _wave(angle, radius),
			1, int(piece[2]),
		])
	_draw_sprites(sprites)


## `Sprites_Sine`; `Sprites_Cosine` is a quarter turn on.
func _wave(angle: int, radius: int) -> int:
	return Gen2BattleAnimFunctions.sine_of(_sine, angle, radius) if _sine != null else 0


func _draw_cracks() -> void:
	var lift: int = 0 if Gen2WorldState.is_crystal_profile(_data) else GOLD_SILVER_CRACK_LIFT
	var sprites: Array = []
	for crack: int in _cracks:
		sprites.append([CRACK_X - _shift, CRACK_Y - lift + crack * TILE, 0, 0])
	_draw_sprites(sprites)


## `AnimateFrontpic ANIM_MON_HATCH` on Crystal, `PlayMonCry` on Gold and Silver.
func _open_frontpic_animation() -> void:
	var species: int = int(current_hatch().get("species", 0))
	var record: Dictionary = _data.pic_animation(species)
	if record.is_empty():
		if Gen2WorldState.is_crystal_profile(_data):
			_open_hatched_text()
			return
		cry_requested.emit(species)
		_sfx_watch = {}
		_phase = Phase.CRY
		return
	_animation = Gen2PicAnimation.new(record, Gen2PicAnimation.ANIM_MON_HATCH)
	_animation_pixels = Gen2BattleRenderer.padded_pic(
		_data, _data.species_pic(species), BOX, true,
		_data.species_pic_animation(species)
	)
	_phase = Phase.ANIMATE
	_advance_frontpic_animation()


func _advance_frontpic_animation() -> void:
	if _animation == null:
		_open_hatched_text()
		return
	var cry: StringName = _animation.advance()
	if cry != &"":
		cry_requested.emit(int(current_hatch().get("species", 0)))
	_draw_animation_box()
	if _animation.finished():
		_animation = null
		_animation_pixels = PackedByteArray()
		_open_hatched_text()


## `.BreedClearboxText`, then `_BreedEggHatchText`.
func _open_hatched_text() -> void:
	_draw_species(int(current_hatch().get("species", 0)))
	_phase = Phase.HATCHED
	_show_text(
		Gen2WorldPartyHost.hatch_text(String(current_hatch().get("nickname", ""))), true
	)


func _open_nickname_question() -> void:
	_phase = Phase.ASK_NICKNAME
	if _nickname_forced:
		_answer_nickname(true)
		return
	_show_text(
		Gen2WorldPartyHost.nickname_question(String(current_hatch().get("nickname", "")))
	)


## NO is `.nonickname`, which keeps the species name; YES is `NamingScreen`.
func _answer_nickname(yes: bool) -> void:
	if not yes:
		_finish_hatch(String(current_hatch().get("nickname", "")))
		return
	_phase = Phase.CLEARING
	if menu_transition == null:
		_open_naming()
		return
	menu_transition.clear_screen(_open_naming, &"naming_screen")


func _open_naming() -> void:
	_naming = Gen2NamingScreenScreen.new()
	if not _naming.open(
		_data, Gen2WorldPartyHost.nickname_prompt(
			String(current_hatch().get("nickname", ""))
		),
		Gen2NamingScreenScreen.KIND_MON
	):
		_naming = null
		_finish_hatch(String(current_hatch().get("nickname", "")))
		return
	## `NamingScreen`'s `.Pokemon` draws the icon and `GetGender`'s sign.
	var species: int = int(current_hatch().get("species", 0))
	_naming.set_species_icon(_data, species, Gen2NamingScreenScreen.gender_sign(
		_data, species, int(current_hatch().get("dvs", -1))
	))
	_text_box.visible = false
	_backdrop.visible = false
	_pic.visible = false
	_naming.closed.connect(_on_named)
	add_child(_naming)
	_phase = Phase.NAMING


## `InitName`, which keeps the species name when the entry came back blank.
func _on_named(entered: String) -> void:
	Gen2Screen.drop(_naming)
	_naming = null
	_finish_hatch(
		Gen2NamingScreen.init_name(entered, String(current_hatch().get("nickname", "")))
	)


func _finish_hatch(nickname: String) -> void:
	var hatch: Dictionary = current_hatch()
	if not hatch.is_empty():
		named.emit(int(hatch.get("party_index", -1)), nickname)
	_index += 1
	if _text_box != null:
		_text_box.visible = false
	if _index >= _hatches.size():
		_phase = Phase.DONE
		closed.emit()
		return
	_begin_hatch()


## `GetEggFrontpic`: the egg's own picture and palette.
func _draw_egg() -> void:
	var pic: Dictionary = _data.egg_pic()
	if pic.is_empty():
		_pic.texture = null
		return
	_blit(pic, _data.egg_palette(), EGG_AT)


func _draw_species(species: int) -> void:
	var pic: Dictionary = _data.species_pic(species)
	if pic.is_empty():
		_pic.texture = null
		return
	_blit(pic, _data.palette(species, _hatch_shiny()), HATCHLING_AT)


func _blit(pic: Dictionary, colours: PackedColorArray, at: Vector2i) -> void:
	var image: Image = Gen2PicImage.from_atlas(
		_data.atlas_indices(pic["atlas"]), _data.atlas(pic["atlas"]), pic, colours
	)
	Gen2PicImage.show(_pic, image)
	_pic.size = Vector2(image.get_size())
	_pic_origin = at
	_pic_pad = Gen2PicImage.frontpic_origin(image.get_size(), false, _data.generation)
	_place_pic()


## `hSCX` scrolls the whole background, so the picture moves the other way.
func _place_pic() -> void:
	if _pic == null:
		return
	var at: Vector2i = _pic_origin * TILE + _pic_pad
	_pic.position = Vector2(at.x - _shift, at.y)


func _draw_animation_box() -> void:
	if _pic == null or _animation == null:
		return
	var indices: PackedByteArray = Gen2PicImage.animation_box_indices(
		_animation.box, _animation_pixels, BOX
	)
	if indices.is_empty():
		return
	var side: int = BOX * TILE
	var image: Image = Gen2PicImage.from_indices(
		indices, side, side,
		_data.palette(int(current_hatch().get("species", 0)), _hatch_shiny())
	)
	Gen2PicImage.show(_pic, image)
	_pic.size = Vector2(image.get_size())
	_pic_origin = HATCHLING_AT
	_pic_pad = Vector2i.ZERO
	_place_pic()


## Shadow OAM for [param sprites], each [x, y, tile, flips]. Every sum is a
## byte, and a lower slot wins a pixel, so the list is painted last to first.
func _draw_sprites(sprites: Array) -> void:
	if _sprites == null:
		return
	if sprites.is_empty() or _object_colors.size() < 4:
		_sprites.texture = null
		return
	var tiles: PackedByteArray = _data.tile_indices("egg_hatch")
	var image: Image = Image.create_empty(Gen2Screen.WIDTH, Gen2Screen.HEIGHT, false, Image.FORMAT_RGBA8)
	for slot: int in range(sprites.size() - 1, -1, -1):
		_paint_sprite(image, tiles, sprites[slot])
	Gen2PicImage.show(_sprites, image)
	_sprites.size = Vector2(image.get_size())


func _paint_sprite(image: Image, tiles: PackedByteArray, sprite: Array) -> void:
	var oam_x: int = (int(sprite[0]) - TILE / 2) & 0xFF
	var oam_y: int = (int(sprite[1]) - TILE / 2) & 0xFF
	var strip: int = Gen2Layout.EGG_HATCH_TILES * TILE
	var flips: int = int(sprite[3])
	for row: int in TILE:
		for column: int in TILE:
			var x: int = oam_x - TILE + column
			var y: int = oam_y - 2 * TILE + row
			if x < 0 or y < 0 or x >= Gen2Screen.WIDTH or y >= Gen2Screen.HEIGHT:
				continue
			var from_row: int = TILE - 1 - row if flips & OAM_Y_FLIP else row
			var from_column: int = TILE - 1 - column if flips & OAM_X_FLIP else column
			var at: int = from_row * strip + int(sprite[2]) * TILE + from_column
			var index: int = int(tiles[at]) if at < tiles.size() else 0
			if index != 0:
				image.set_pixel(x, y, _object_colors[index])
