class_name Gen2LauncherTitleBackdrop
extends Node

## A non-interactive title-screen loop for the launcher backdrop: never the boot
## cinema, plus the cartridge sound driver playing its title music at
## [constant VOLUME_SCALE] of the player's settings. [Gen2TitleScene] over
## [Gen2TitlePage], or a `DisplayTitleScreen`-only [Gen1Opening] over
## [Gen1OpeningPage].

const FRAME_TIME: float = 1.0 / 60.0
const MAX_STEPS_PER_TICK: int = 4
## The backdrop plays under an interface rather than as the game, so it takes
## half of whatever the app block's music volume is.
const VOLUME_SCALE: float = 0.5

## How much of a frame the title lettering fills, which the launcher erases to
## draw its own type over: Crystal's logo ends on row ten, Gold and Silver's on
## row seven, and Generation 1's on `TITLE_LOGO_AT`'s seven plus a version line.
const LETTERING_BOTTOM: Dictionary = {
	RomRegistry.RED: 72, RomRegistry.BLUE: 72, RomRegistry.YELLOW: 72,
	RomRegistry.GOLD: 60, RomRegistry.SILVER: 60, RomRegistry.CRYSTAL: 80,
}
## The copyright is the final tile row on every one of them.
const COPYRIGHT_TOP: int = 136

## `DisplayTitleScreen`'s entrance ends on `PlayMusic MUSIC_TITLE_SCREEN`, the
## frame the title has settled on, and the backdrop opens there. A bound.
const MAX_SETTLE_FRAMES: int = 600

var _data: GameData = null
var _page: Gen2TitlePage = null
var _scene: Gen2TitleScene = null
var _gen1_page: Gen1OpeningPage = null
var _gen1: Gen1Opening = null
var _sine: Gen2BattleAnimData = null
var _texture: ImageTexture = null
var _elapsed: float = 0.0
var _audio: Gen2AudioPlayer = null


func _ready() -> void:
	set_process(false)


## Starts or resumes [param data]'s title. Answers the live texture the shell
## should display, or null when this cache does not carry title-screen art.
func show_game(data: GameData) -> Texture2D:
	if data == null:
		hide_backdrop()
		return null
	if _data != data:
		_data = data
		_page = Gen2TitlePage.from_data(data)
		_gen1_page = Gen1OpeningPage.from_data(data)
		_sine = Gen2BattleAnimData.from_game_data(data)
		# A game change gets a new resource so the shell can crossfade to it. A
		# loop restart keeps the existing resource because the shell holds it.
		_texture = null
		_restart()
	if not _playing():
		set_process(false)
		_stop_music()
		return null
	set_process(true)
	_start_music()
	return _texture


func hide_backdrop() -> void:
	set_process(false)
	_elapsed = 0.0
	_stop_music()


func _process(delta: float) -> void:
	if not _playing() or _texture == null:
		return
	_elapsed += delta
	var steps: int = mini(int(_elapsed / FRAME_TIME), MAX_STEPS_PER_TICK)
	if steps <= 0:
		return
	_elapsed -= float(steps) * FRAME_TIME
	for _step: int in steps:
		_advance()
	var frame: Image = _frame()
	if frame != null:
		_texture.update(frame)
	_hold_music()


func _playing() -> bool:
	return (_page != null and _scene != null) or (_gen1_page != null and _gen1 != null)


func _advance() -> void:
	if _gen1 != null:
		# The events are dropped: the piece playing is this node's own.
		_gen1.advance_frame()
		if _gen1.finished():
			_restart()
		return
	_scene.advance_frame()
	if _scene.finished():
		_restart()


func _frame() -> Image:
	if _gen1 != null:
		return _clean_frame(_gen1_page.draw(_gen1))
	return _clean_frame(_page.draw(_scene)) if _scene != null else null


func _restart() -> void:
	_elapsed = 0.0
	_scene = null
	_gen1 = null
	if _data != null and _gen1_page != null:
		_gen1 = Gen1Opening.create(_data, null, true)
		_settle_gen1()
	elif _data != null and _page != null:
		_scene = Gen2TitleScene.create(_data.id, _sine)
	var frame: Image = _frame()
	if frame == null:
		_texture = null
	elif _texture == null:
		_texture = ImageTexture.create_from_image(frame)
	else:
		_texture.update(frame)


func _settle_gen1() -> void:
	for _step: int in MAX_SETTLE_FRAMES:
		for event: Dictionary in _gen1.advance_frame():
			if StringName(event.get("type", &"")) == &"play_music":
				return
		if _gen1.finished():
			return


## The player is built on the first backdrop rather than in `_ready`, so a
## headless run, a test or a screenshot tool never wakes the driver.
func _start_music() -> void:
	if _data == null:
		return
	var record: Dictionary = _title_music()
	if record.is_empty():
		return
	if _audio == null:
		_audio = Gen2AudioPlayer.new()
		_audio.volume_scale = VOLUME_SCALE
		add_child(_audio)
	# A second request for the piece already playing is continued rather than
	# restarted, so returning to the shelf does not start the tune over.
	_audio.play_record(record, &"music", _audio_assets())


## `MUSIC_TITLE` on Crystal, `MUSIC_TITLE_SCREEN` in `Init`'s own bank below.
func _title_music() -> Dictionary:
	if _data.generation == RomRegistry.GEN1:
		return _data.gen1_sound(Gen1Movie.AUDIO_BANK, Gen1Opening.MUSIC_TITLE_SCREEN)
	return _data.world_audio(&"music", Gen2BootCinema.MUSIC_TITLE)


func _stop_music() -> void:
	if _audio == null:
		return
	_audio.stop_all()


## The music is a property of the backdrop being up, checked on the frames it
## draws rather than started by whichever event brought it back: while there is
## a picture there is a piece playing, and one that ends starts again.
func _hold_music() -> void:
	if _audio != null and _audio.music_playing():
		return
	_start_music()


## The two blobs [Gen2SoundEngine] reads outside a record.
func _audio_assets() -> Dictionary:
	return _data.audio_assets()


## Removes the title lettering from the launcher copy alone; every gameplay
## caller still receives the cartridge-accurate frame.
func _clean_frame(frame: Image) -> Image:
	if frame == null:
		return null
	frame.fill_rect(
		Rect2i(0, 0, frame.get_width(), int(LETTERING_BOTTOM.get(_data.id, 60))),
		frame.get_pixel(0, 0),
	)
	# Preserve each profile's lower-band colour instead of imposing a colour of
	# the launcher's own.
	for y: int in range(COPYRIGHT_TOP, frame.get_height()):
		frame.fill_rect(Rect2i(0, y, frame.get_width(), 1), frame.get_pixel(0, y))
	return frame
