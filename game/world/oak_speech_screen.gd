class_name Gen2OakSpeechScreen
extends Control

## `OakSpeech` drawn: a pic above the standard text box, advanced with A, with
## `NamePlayer`'s menu and keyboard where the source puts them. The routine is a
## run of `PrintText` calls separated by palette fades and `ClearTilemap`, so this
## screen is a run of beats separated by [Gen2IntroPresentation] queues. Nothing
## here waits a number of frames it chose: every count is a `DelayFrames` operand.
## Oak and the speech species use the ordinary imported pic tables; Gold and Silver
## use CAL's trainer pic for the player and Crystal the imported raw ChrisPic.

## Carries the name the intro settled on, already through `InitName`'s default.
signal finished(player_name: String)

## `Intro_PrepTrainerPic` and `PrepMonFrontpic` both place at `hlcoord 6, 4`.
const PIC_AT: Vector2i = Vector2i(6, 4)
const PIC_TILES: int = 7
const TILE: int = Gen2Font.TILE
const GEN1_NAME_BOX_FRAMES: int = 10

## Where the screen is standing, which is the routine it is inside.
enum Phase {
	## Inside a queued run of `DelayFrames`: no button does anything.
	ANIMATING,
	## At a `PrintText`, which is the only place A advances.
	TEXT,
	## `ShowPlayerNamingChoices`, then `NamingScreen` on its NEW NAME row.
	NAME_MENU,
	NAMING,
	DONE,
}

var _data: GameData = null
var _beats: Array = []
var _index: int = 0
var _gender: int = Gen2SaveData.GENDER_MALE
var _player_name: String = ""
var _rival_name: String = ""
var _naming_role: String = Gen2OakSpeech.NAME_NONE
var _gen1: bool = false
var _phase: int = Phase.ANIMATING

var _background: Gen2Screen.Field = null
var _pic: TextureRect = null
var _pic_palette: PackedColorArray = PackedColorArray()
## `Palette_TextBG7`, the palette a `TextboxPalette` region is drawn through, so
## a fade over a text box passes through its two middle colours. Gold and Silver
## ship none and fall back to the black-on-white every 1bpp page here uses.
var _text_palette: PackedColorArray = PackedColorArray()
## The picture as indices and size, kept so a fade recolours rather than redraws.
var _pic_cell: Dictionary = {}
var _pic_pad_columns: int = 0
var _text_box: Gen2TextBox = null
## `Intro_PlacePlayerSprite`'s four OAM tiles, which is the one thing the intro
## draws as an object rather than in the tilemap.
var _sprite: TextureRect = null
var _sprite_palette: PackedColorArray = PackedColorArray()
var _sprite_source: Gen2WorldSprite = null
var _naming: Gen2NamingScreenScreen = null
var _name_menu: Gen2PlayerNameMenuScreen = null
var _audio: Gen2AudioPlayer = null
var _audio_started: bool = false
var _cry_played: bool = false
var _presentation := Gen2IntroPresentation.new()
var _frame_clock := Gen2WorldAnimation.FrameClock.new()
## What to run when the queue empties, which is where the routine resumes.
var _after: Callable = Callable()


## Answers false when the cache carries no intro text, which the caller reports
## rather than running a speech with nothing in it.
func open(data: GameData, gender: int) -> bool:
	_data = data
	_gender = gender
	_gen1 = Gen2OakSpeech.is_gen1(data)
	_beats = Gen2OakSpeech.beats(data)
	_index = 0
	if _beats.is_empty():
		return false
	## `OakSpeech` runs no `RunPaletteCommand` at all, so a Generation 1 speech
	## is drawn in the four shades the hardware shows with no packet sent.
	_text_palette = PokePalette.monochrome() if _gen1 else data.text_bg_palette()
	if _text_palette.size() != 4:
		_text_palette = PokePalette.pic_palette(
			PackedColorArray([Color.WHITE, Color.BLACK])
		)
	if is_inside_tree():
		_begin()
	return true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)
	# `ClearTilemap` leaves the whole screen blank, which is white here the way
	# every other 1bpp page in this project is.
	_background = Gen2Screen.Field.create(Color.WHITE)
	add_child(_background)

	_audio = Gen2AudioPlayer.new()
	add_child(_audio)

	_pic = TextureRect.new()
	_pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pic)

	_text_box = Gen2TextBox.new()
	_text_box.driven = true
	_text_box.font = Gen2Font.from_data(_data)
	_text_box.frame_style = Gen2OptionsStore.current().textbox_frame
	_text_box.position = Vector2(0, Gen2TextBox.STANDARD_TOP * TILE)
	# `ClearTilemap` runs before the first pic is even loaded, so the speech
	# opens on a blank screen and not on an empty box.
	_text_box.visible = false
	add_child(_text_box)

	if not _beats.is_empty():
		_begin()


func _process(delta: float) -> void:
	if _text_box != null:
		_text_box.accelerated = PokeButton.text_accelerating()
	advance_frames(_frame_clock.tick(delta))


func advance_frames(count: int) -> void:
	for _frame: int in count:
		if _text_box != null:
			_text_box.advance_frame()
		if _phase != Phase.ANIMATING:
			# The cry sits inside `OakText2`'s own `text_asm`, so it fires when
			# the words have finished appearing rather than when A is pressed.
			# Every frame asked for is spent: returning here left a caller that
			# had asked for a whole printing text with one frame of it.
			_play_cry_if_due()
			continue
		_presentation.advance_frame()
		_apply_frame()
		# `DelayFrames` returns on its last VBlank; no frame goes at a boundary.
		if _presentation.finished():
			_finish_queue()


func beat_index() -> int:
	return _index


func beat_count() -> int:
	return _beats.size()


## True while the naming screen is up, which is the one point in the speech that
## does not answer A by advancing.
func naming() -> bool:
	return _naming != null


func choosing_name() -> bool:
	return _name_menu != null


func name_choice_image() -> Image:
	return _name_menu.image() if _name_menu != null else null


## How many source frames the screen still owes before it is waiting on a press:
## the queued animation, or the rest of a text that is still printing. A press
## cannot shorten either, so a caller settling the screen spends these.
func animation_frames_left() -> int:
	if _phase == Phase.ANIMATING:
		return _presentation.remaining_frames()
	return _text_box.frames_left() if _text_box != null else 0


## The name the intro has settled on so far, empty until the naming screen
## closes.
func player_name() -> String:
	return _player_name


func rival_name() -> String:
	return _rival_name


## A advances, the way every `PrintText` in the routine waits for one. A button
## pressed inside a `DelayFrames` run is swallowed, which is what the hardware
## does with a joypad nobody is reading.
func handle_button(button: int) -> bool:
	if _phase == Phase.ANIMATING:
		return true
	if _name_menu != null:
		return _name_menu.handle_button(button)
	if _naming != null:
		return _naming.handle_button(button)
	if button != PokeButton.A:
		return false
	advance()
	return true


## One page forward, then one beat forward once the text has run out. A plain
## method as well as a key handler, so the speech can be photographed partway.
func advance() -> void:
	if _phase != Phase.TEXT or _index >= _beats.size():
		return
	# Every beat here is one `PrintText`, which waits at each page and again at
	# the end, so the beat only moves on once the box has nothing left.
	if _text_box != null and _text_box.advance():
		return
	var role: String = String(_beats[_index].get("name", Gen2OakSpeech.NAME_NONE))
	if role != Gen2OakSpeech.NAME_NONE:
		_naming_role = role
		_open_name_menu()
		return
	# `RotateThreePalettesRight` then `ClearTilemap` after the beats that load a
	if bool(_beats[_index].get("clears_after", false)):
		_push_fade_out()
		_queue(_enter_next_beat)
		return
	_enter_next_beat()


func _push_fade_out() -> void:
	if _gen1:
		_presentation.push_gen1_fade_out_white()
		return
	_presentation.push_rotate_three_right()


## The whole opening of `OakSpeech`: out to black, the music, back in, and out
## to white before the first picture is loaded.
func _begin() -> void:
	_presentation.clear()
	if _gen1:
		_start_audio()
		_show_beat()
		return
	_presentation.push_rotate_four_left()
	_queue(_after_first_fade)


func _after_first_fade() -> void:
	_start_audio()
	_presentation.push_rotate_four_right()
	_presentation.push_rotate_three_right()
	_queue(_show_beat)


func _queue(after: Callable) -> void:
	_after = after
	_phase = Phase.ANIMATING
	_frame_clock.reset()
	_apply_frame()


func _finish_queue() -> void:
	_presentation.clear()
	_phase = Phase.TEXT
	var next: Callable = _after
	_after = Callable()
	if next.is_valid():
		next.call()


## Writes the frame's palette byte and pic column onto what is drawn. Every BG
## palette on screen goes through the same byte, which is what a hardware fade
## does to a screen carrying more than one palette.
func _apply_frame() -> void:
	var bgp: int = _presentation.bgp()
	var text_colors: PackedColorArray = Gen2IntroPresentation.apply_bgp(_text_palette, bgp)
	if _background != null:
		_background.color = text_colors[0]
	if _text_box != null:
		_text_box.palette = text_colors
	if _name_menu != null:
		_name_menu.palette = text_colors
	if _naming != null:
		_naming.palette = text_colors
	if _pic != null and _pic.texture != null and _pic_palette.size() == 4:
		_redraw_pic(Gen2IntroPresentation.apply_bgp(_pic_palette, bgp))
	# `RotatePalettesRight` writes the object palettes from the same table row,
	# so the sprite `Intro_PlacePlayerSprite` leaves standing fades with the rest.
	if _sprite != null and _sprite.visible:
		_redraw_sprite(Gen2IntroPresentation.apply_bgp(_sprite_palette, bgp))
	if _pic != null:
		_pic.position.x = float(
			(_presentation.column() + _pic_pad_columns) * TILE
		)


func _enter_next_beat() -> void:
	_index += 1
	if _index >= _beats.size():
		_begin_shrink()
		return
	_show_beat()


## `InitializeWorld`'s `call ShrinkPlayer`, which runs the moment `OakSpeech`
## returns, on the screen the speech left standing: the player pic is still at
## (6,4) and `_OakText7`'s box is still drawn, because nothing between the two
## routines clears either.
func _begin_shrink() -> void:
	_play_shrink_sfx()
	if not _gen1:
		_fade_music()
	_presentation.push_delay(_shrink_waits()[0])
	_queue(_shrink_to_first)


func _shrink_waits() -> Array[int]:
	return Gen2OakSpeech.GEN1_SHRINK_WAITS if _gen1 else Gen2OakSpeech.SHRINK_WAITS


func _shrink_to_first() -> void:
	_show_shrink_pic(0)
	_presentation.push_delay(_shrink_waits()[1])
	_queue(_shrink_to_second)


func _shrink_to_second() -> void:
	_show_shrink_pic(1)
	if _gen1:
		_fade_music()
	_presentation.push_delay(_shrink_waits()[2])
	_queue(_shrink_clear)


func _shrink_clear() -> void:
	_pic.texture = null
	_pic_cell = {}
	if _gen1:
		_place_player_sprite()
		_presentation.push_delay(_shrink_waits()[3])
		_presentation.push_gen1_fade_out_white()
		_queue(_shrink_done)
		return
	_presentation.push_delay(Gen2OakSpeech.SHRINK_WAITS[3])
	_queue(_shrink_place_sprite)


func _shrink_place_sprite() -> void:
	_place_player_sprite()
	_presentation.push_delay(Gen2OakSpeech.SHRINK_WAITS[4])
	_presentation.push_rotate_three_right()
	_queue(_shrink_done)


## `RotateThreePalettesRight` then `ClearTilemap`, which is where `ShrinkPlayer`
## returns and `SpawnPlayer` takes over.
func _shrink_done() -> void:
	if _sprite != null:
		_sprite.visible = false
	_hide_speech(true)
	_phase = Phase.DONE
	finished.emit(_player_name)


## Loads the beat's picture, then runs whichever transition brings it in before
## the text is printed over it.
func _show_beat() -> void:
	if _text_box == null or _index >= _beats.size():
		return
	var beat: Dictionary = _beats[_index]
	_cry_played = false
	_show_pic(int(beat["pic"]))
	match int(beat.get("enter", Gen2OakSpeech.Enter.NONE)):
		Gen2OakSpeech.Enter.FRONTPIC:
			_presentation.push_rotate_left_frontpic()
		Gen2OakSpeech.Enter.WIPE:
			_presentation.push_wipe_in_frontpic()
		Gen2OakSpeech.Enter.MOVE_LEFT:
			_presentation.push_gen1_move_pic_left()
		Gen2OakSpeech.Enter.FADE_IN_WHITE:
			_presentation.push_gen1_fade_in_white()
	if _presentation.finished():
		_print_text()
		return
	# `ClearTilemap` left the screen blank, so there is no box until `PrintText`
	# draws one after the transition.
	_text_box.visible = false
	_queue(_print_text)


func _print_text() -> void:
	if _text_box == null or _index >= _beats.size():
		return
	_text_box.visible = true
	_text_box.show_text(Gen2OakSpeech.with_names(
		String(_beats[_index]["text"]), _player_name, _rival_name
	))
	_phase = Phase.TEXT
	_apply_frame()


## `OakText2`'s `text_asm` plays the cry once the words are up. The source's
## `WaitSFX` after it is not modelled: nothing here holds the script until the
## four effect channels are free.
func _play_cry_if_due() -> void:
	if _cry_played or _index >= _beats.size() or _text_box == null:
		return
	if String(_beats[_index].get("key", "")) != _cry_beat_key() or _text_box.is_revealing():
		return
	_cry_played = true
	_play_intro_cry()


func _cry_beat_key() -> String:
	return "oak_speech_2" if _gen1 else "oak_2"


## `NamePlayer`: the pic slides to the right, then the preset menu opens over
## where it was.
func _open_name_menu() -> void:
	if _gen1:
		_presentation.push_gen1_slide_pic(true)
	else:
		_presentation.push_move_player_pic(true)
	_queue(_show_name_choices)


func _show_name_choices() -> void:
	_name_menu = Gen2PlayerNameMenuScreen.new()
	if not _name_menu.open(_data, _gender, _naming_role == Gen2OakSpeech.NAME_RIVAL):
		_name_menu.free()
		_name_menu = null
		_open_naming()
		return
	_name_menu.closed.connect(_on_name_choice)
	add_child(_name_menu)
	# `DisplayIntroNameTextBox` draws over the top eleven rows alone, so the box
	# the introduction printed is still standing under it.
	if _text_box != null and not _gen1:
		_text_box.visible = false
	_phase = Phase.NAME_MENU


func _on_name_choice(chosen: String) -> void:
	Gen2Screen.drop(_name_menu)
	_name_menu = null
	if chosen == "":
		_open_naming()
		return
	_store_name(chosen)
	if _text_box != null:
		_text_box.visible = true
	# `StorePlayerName`, `ApplyMonOrTrainerPals`, then the pic walks back.
	if _gen1:
		_presentation.push_delay(GEN1_NAME_BOX_FRAMES + Gen2IntroPresentation.DELAY_3_FRAMES)
		_presentation.push_gen1_slide_pic(false)
	else:
		_presentation.push_move_player_pic(false)
	_queue(_enter_next_beat)


func _open_naming() -> void:
	_naming = Gen2NamingScreenScreen.new()
	if not _naming.open(_data, _naming_prompt()):
		_naming.free()
		_naming = null
		_enter_next_beat()
		return
	## `.Player`'s `GetPlayerIcon`, which is the sprite the gender screen picked.
	## `PrintNamingText` draws no icon at all outside NAME_MON_SCREEN.
	if not _gen1:
		_naming.set_sprite_icon(
			_data, Gen2WorldSprite.player_normal_sprite(_gender == Gen2SaveData.GENDER_FEMALE)
		)
	_naming.closed.connect(_on_named)
	add_child(_naming)
	_hide_speech(true)
	_phase = Phase.NAMING


func _naming_prompt() -> String:
	if _naming_role != Gen2OakSpeech.NAME_RIVAL:
		return Gen2NamingScreenScreen.GEN1_PROMPT_PLAYER if _gen1 \
			else Gen2NamingScreenScreen.PROMPT_PLAYER
	return Gen2NamingScreenScreen.GEN1_PROMPT_RIVAL if _gen1 \
		else Gen2NamingScreenScreen.PROMPT_RIVAL


## `.NewName`'s tail: out to white, the screen cleared, the player pic drawn
## again at (6,4), `WaitBGMap`'s four frames, and back in from white.
## `ChoosePlayerName`'s own `cp '@'` sends an empty entry straight back to the
## keyboard rather than filling in a default.
func _on_named(entered: String) -> void:
	if _gen1:
		Gen2Screen.drop(_naming)
		_naming = null
		if entered.strip_edges() == "":
			_open_naming()
			return
		_store_name(entered)
		_presentation.push(
			Gen2IntroPresentation.KEEP, Gen2IntroPresentation.PIC_LEFT_COLUMN,
			Gen2IntroPresentation.DELAY_3_FRAMES
		)
		_queue(_after_naming_fade)
		return
	_store_name(Gen2OakSpeech.resolve_name(entered, _gender))
	_presentation.push_rotate_three_right()
	_queue(_after_naming_fade)


func _store_name(chosen: String) -> void:
	if _naming_role == Gen2OakSpeech.NAME_RIVAL:
		_rival_name = chosen
		return
	_player_name = chosen


func _after_naming_fade() -> void:
	if _naming != null:
		Gen2Screen.drop(_naming)
		_naming = null
	_hide_speech(false)
	if _text_box != null:
		_text_box.visible = false
	_show_pic(int(_beats[_index]["pic"]) if _gen1 else Gen2OakSpeech.Pic.PLAYER)
	if _gen1:
		_resume_after_name()
		return
	_presentation.push_delay(Gen2IntroPresentation.WAIT_BG_MAP_FRAMES)
	_presentation.push_rotate_three_left()
	_queue(_resume_after_name)


func _resume_after_name() -> void:
	if _text_box != null:
		_text_box.visible = true
	_enter_next_beat()


func _hide_speech(was_hidden: bool) -> void:
	for node: CanvasItem in [_background, _pic, _text_box]:
		if node != null:
			node.visible = not was_hidden


## `Intro_PrepTrainerPic` and `PrepMonFrontpic` both fill a seven-tile box at
## (6,4). A pic smaller than the box is padded by `PadFrontpic`
## (`engine/gfx/load_pics.asm`), not centred: it lays one blank tile column
## before the pic, blank rows above it, and for a 5x5 one blank column after, so
## the pic ends up bottom-aligned one column in.
func _show_pic(kind: int) -> void:
	if _pic == null:
		return
	_pic.texture = null
	_pic_palette = PackedColorArray()
	_pic_cell = {}
	if _data == null:
		return
	var cell: Dictionary = {}
	var palette: PackedColorArray = _text_palette if _gen1 else PackedColorArray()
	var mirrored: bool = false
	match kind:
		Gen2OakSpeech.Pic.OAK:
			if not _gen1:
				palette = _data.trainer_palette(Gen2OakSpeech.POKEMON_PROF)
			cell = Gen2OakSpeech.trainer_cell(_data, _oak_class())
		Gen2OakSpeech.Pic.RIVAL:
			cell = Gen2OakSpeech.trainer_cell(_data, Gen2OakSpeech.GEN1_RIVAL1)
		Gen2OakSpeech.Pic.MON:
			# `PrepMonFrontpic` sets wBoxAlignment before `PlaceGraphic`, and
			# `Intro_PrepTrainerPic` does not, so only this beat is mirrored.
			mirrored = true
			var species: int = Gen2OakSpeech.intro_species(_data)
			if not _gen1:
				palette = _data.palette(species)
			cell = _species_cell(species)
			if not cell.is_empty():
				cell["indices"] = Gen2PicImage.x_flipped_indices(
					cell["indices"], int(cell["width"])
				)
		Gen2OakSpeech.Pic.PLAYER:
			var female: bool = _gender == Gen2SaveData.GENDER_FEMALE
			if _gen1:
				cell = _player_front_cell(0)
			else:
				palette = Gen2OakSpeech.player_palette(_data, female)
				cell = Gen2OakSpeech.player_cell(_data, female)
	if cell.is_empty():
		return
	_pic_cell = cell
	_pic_palette = palette
	_pic_pad_columns = Gen2PicImage.frontpic_pad_columns(
		int(cell["width"]) / TILE, mirrored, _data.generation
	)
	_pic.size = Vector2(float(cell["width"]), float(cell["height"]))
	_pic.position = Vector2(
		float((PIC_AT.x + _pic_pad_columns) * TILE),
		float(PIC_AT.y * TILE + PIC_TILES * TILE - int(cell["height"]))
	)
	_redraw_pic(Gen2IntroPresentation.apply_bgp(palette, _presentation.bgp()))


## Redraws the picture through [param colors]. The indices are kept, so a fade
## step costs a palette swap rather than another crop of the atlas.
func _redraw_pic(colors: PackedColorArray) -> void:
	if _pic_cell.is_empty():
		return
	Gen2PicImage.show(_pic, Gen2PicImage.from_indices(
		_pic_cell["indices"], int(_pic_cell["width"]), int(_pic_cell["height"]), colors
	))


func _oak_class() -> int:
	return Gen2OakSpeech.GEN1_PROF_OAK if _gen1 else Gen2OakSpeech.POKEMON_PROF


func _player_front_cell(slot: int) -> Dictionary:
	var pic: Dictionary = _data.player_frontpic(slot)
	if pic.is_empty():
		return {}
	return Gen2PicImage.atlas_cell(
		_data.atlas_indices(pic["atlas"]), _data.atlas(pic["atlas"]), pic
	)


func _species_cell(species: int) -> Dictionary:
	var pic: Dictionary = _data.species_pic(species)
	if pic.is_empty():
		return {}
	return Gen2PicImage.atlas_cell(
		_data.atlas_indices(pic["atlas"]), _data.atlas(pic["atlas"]), pic
	)


func _start_audio() -> void:
	if _audio_started or _audio == null or _data == null:
		return
	_audio_started = true
	_audio.play_record(
		_data.world_audio(&"music", Gen1Layout.MUSIC_ROUTES2 if _gen1 \
			else Gen2OakSpeech.MUSIC_ROUTE_30), &"music", _audio_assets()
	)


## One of `ShrinkPlayer`'s two intermediate pictures, in the same 7x7 box and the
## same palette the player pic was drawn through: `ShrinkFrame` reloads the tiles
## and re-places the graphic without touching the palettes.
func _show_shrink_pic(which: int) -> void:
	if _pic == null or _data == null:
		return
	if _gen1:
		var cell: Dictionary = _player_front_cell(Gen2OakSpeech.GEN1_SHRINK_SLOTS[which])
		if cell.is_empty():
			return
		_pic_cell = cell
		_pic_pad_columns = 0
		_pic.size = Vector2(float(cell["width"]), float(cell["height"]))
		_pic.position = Vector2(PIC_AT * TILE)
		_redraw_pic(Gen2IntroPresentation.apply_bgp(_pic_palette, _presentation.bgp()))
		return
	var pic_name: String = Gen2Layout.SHRINK_PIC_NAMES[which]
	var indices: PackedByteArray = _data.tile_indices(pic_name)
	var side: int = Gen2Layout.SHRINK_PIC_COLUMNS * TILE
	if indices.size() < side * side:
		return
	_pic_cell = {"indices": indices, "width": side, "height": side}
	_pic_pad_columns = 0
	_pic.size = Vector2(float(side), float(side))
	_pic.position = Vector2(PIC_AT * TILE)
	_redraw_pic(Gen2IntroPresentation.apply_bgp(_pic_palette, _presentation.bgp()))


## `Intro_PlacePlayerSprite`: `GetPlayerIcon`'s first frame as four OAM tiles,
## in PAL_OW_RED or PAL_OW_BLUE. Objects, so it survives the `ClearBox` that
## emptied the picture and fades with the palette like everything else.
func _place_player_sprite() -> void:
	if _data == null:
		return
	var female: bool = _gender == Gen2SaveData.GENDER_FEMALE
	var sprite: Gen2WorldSprite = _data.overworld_sprite(
		Gen2WorldSprite.player_normal_sprite(female)
	)
	if sprite == null:
		return
	# The routine names PAL_OW_RED and PAL_OW_BLUE where `InitPlayerObject` names
	# PAL_NPC_RED and PAL_NPC_BLUE; both pairs index the same two rows, since the
	var colors: PackedColorArray = _text_palette if _gen1 \
		else _data.overworld_sprite_palette(
			Gen2WorldSprite.player_palette(female), Gen2WorldPalette.TIME_DAY
		)
	if _sprite == null:
		_sprite = TextureRect.new()
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_sprite)
	_sprite_source = sprite
	_sprite_palette = colors
	_sprite.position = Vector2(Gen2OakSpeech.SHRINK_SPRITE_AT)
	_sprite.visible = true
	_redraw_sprite(Gen2IntroPresentation.apply_bgp(colors, _presentation.bgp()))


func _redraw_sprite(colors: PackedColorArray) -> void:
	if _sprite == null or _sprite_source == null or _data == null:
		return
	var image: Image = Gen2WorldSprite.image_for(
		_sprite_source, _data.overworld_sprite_indices(_sprite_source.number), colors
	)
	Gen2PicImage.show(_sprite, image)
	_sprite.size = Vector2(image.get_size())


func _fade_music() -> void:
	if _audio != null:
		_audio.fade_out(Gen2OakSpeech.GEN1_SHRINK_FADE_FRAMES if _gen1 \
			else Gen2OakSpeech.SHRINK_FADE_FRAMES)


func _play_shrink_sfx() -> void:
	if _audio == null or _data == null:
		return
	_audio.play_record(
		_data.world_audio(&"sfx", Gen1Layout.SFX_SHRINK if _gen1 \
			else Gen2OakSpeech.SHRINK_SFX), &"sfx", _audio_assets()
	)


func _play_intro_cry() -> void:
	if _audio == null or _data == null:
		return
	_audio.play_record(
		_data.species_cry(Gen2OakSpeech.intro_cry(_data)), &"cry", _audio_assets()
	)


func _audio_assets() -> Dictionary:
	return {
		"wave_samples": _data.world_audio_asset(&"wave_samples"),
		"drumkits": _data.world_audio_asset(&"drumkits"),
	}
