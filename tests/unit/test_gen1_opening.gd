extends GutTest

## [Gen1Opening]'s frame budget and joypad on a cache holding only the tables
## `PlayIntro` reads, no art: the phases open on the source's own frame counts,
## `CheckForUserInterruption` reads what it reads, the title loop picks and
## answers, and Yellow's title resets. What the screen looks like is
## tools/checks/gen1_opening.gd's, against the cartridge.

const RED_ID: StringName = &"testgen1open"
const YELLOW_ID: StringName = &"testgen1openy"
const SHA1: String = "0123456789abcdef"
## `PlayShootingStar` from `hWY` to `rBGP`: `ClearScreen`'s three frames, the
## text box sheet's five `CopyVideoData` frames and the copyright's four.
const COPYRIGHT_SHOWN: int = 12
## The intro's own `Delay3` behind the stars and the fade's three steps.
const NIDORINO_ANIMS: Array = [
	[[0, 0], [-2, 2], [-1, 2], [1, 2], [2, 2]],
	[[0, 0], [-2, -2], [-1, -2], [1, -2], [2, -2]],
	[[0, 0], [-12, 6], [-8, 6], [8, 6], [12, 6]],
	[[0, 0], [-8, -4], [-4, -4], [4, -4], [8, -4]],
	[[0, 0], [-8, 4], [-4, 4], [4, 4], [8, 4]],
	[[0, 0], [2, 0], [2, 0], [0, 0]],
	[[-8, -16], [-7, -14], [-6, -12], [-4, -10]],
]

var _directories: Array[String] = []


func after_each() -> void:
	for directory: String in _directories:
		RomCache.clear(directory)
	_directories.clear()


func _opening_section(yellow: bool) -> Dictionary:
	var section: Dictionary = {
		"shooting_star_oam": [[0, 160, 160, 16], [0, 168, 160, 48], [8, 160, 161, 16], [8, 168, 161, 48]],
		"logo_oam": [],
		"small_star_oam": [0, 0, 162, 144],
		"small_star_waves": [
			[[104, 48], [104, 64], [104, 88], [104, 120]],
			[[104, 56], [104, 72], [104, 96], [104, 112]],
			[[104, 52], [104, 76], [104, 84], [104, 100]],
			[[104, 60], [104, 92], [104, 108], [104, 116]],
		],
		"palettes": {},
		"blocks": {},
		"gengar_tilemaps": [[], [], []],
	}
	for slot: int in Gen1Layout.SPLASH_LOGO_OAM_SPRITES:
		section["logo_oam"].append([72 + (slot % 2) * 8, 80 + slot * 4, 0x80 + slot, 0])
	if yellow:
		section["yellow"] = {
			"tilemaps": [], "speed_bars": [], "pal_flash": [0xE4, 0xC0, 0xC0, 0xE4],
			"pal_fade": [0xE4, 0x90, 0x40, 0x00], "spawn_states": [[0, 0, 0], [1, 1, 0]],
			"frames": [[[0, 32], [-1, 0]], [[1, 4], [-2, 0]]],
			"oam_sets": [{"tile": 0, "sprites": [[0, 0, 0, 0]]}, {"tile": 2, "sprites": [[0, 0, 1, 0]]}],
			"title_logo_tilemap": [], "title_bubble_tilemap": [], "title_pikachu_tilemap": [],
			"title_eyes_oam": [[96, 64, 0xF1, 0x22], [96, 72, 0xF0, 0x22]],
			"sine": [], "sine_words": [],
		}
	else:
		section["nidorino_anims"] = NIDORINO_ANIMS
		section["title_mons"] = [4, 7, 1, 13, 32, 123, 25, 35, 112, 63, 92, 132, 17, 95, 77, 129]
		section["version_text"] = [0x60, 0x61]
	return section


func _data(yellow: bool) -> GameData:
	var id: StringName = YELLOW_ID if yellow else RED_ID
	var directory: String = RomCache.directory_for(id, SHA1)
	RomCache.clear(directory)
	RomCache.prepare(directory)
	_directories.append(directory)
	RomCache.write_json(RomCache.manifest_path(directory), {
		"format_version": RomCache.FORMAT_VERSION, "complete": true,
		"game_id": String(id), "generation": RomRegistry.GEN1,
		"opening": _opening_section(yellow), "tiles": {},
	})
	var data: GameData = GameData.open_directory(directory)
	# A profile the layout knows, so the per-cartridge frame tables answer.
	data.id = RomRegistry.YELLOW if yellow else RomRegistry.RED
	return data


func _opening(yellow: bool = false) -> Gen1Opening:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	return Gen1Opening.create(_data(yellow), rng)


func _advance(opening: Gen1Opening, frames: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for _frame: int in frames:
		events.append_array(opening.advance_frame())
	return events


## The frame [param phase] opens on, counted the way tools/trace_opening_oam.gd
## counts, from 0.
func _phase_at(opening: Gen1Opening, phase: StringName, cap: int = 4000) -> int:
	for _frame: int in cap:
		if opening.phase() == phase:
			return opening.frame() - 1
		opening.advance_frame()
	return -1


func _advance_to(opening: Gen1Opening, index: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	while opening.frame() < index + 1:
		events.append_array(opening.advance_frame())
	return events


func test_a_generation_2_cache_has_no_opening() -> void:
	assert_null(Gen1Opening.create(null))


func test_the_first_vblank_hides_every_sprite() -> void:
	var opening: Gen1Opening = _opening()
	opening.advance_frame()
	for entry: Dictionary in opening.shadow_oam():
		assert_eq(int(entry["y"]), Gen1Opening.OFF_SCREEN_Y)


func test_the_copyright_holds_180_frames_behind_its_loads() -> void:
	var opening: Gen1Opening = _opening()
	_advance_to(opening, COPYRIGHT_SHOWN - 1)
	assert_eq(opening.lcd.bgp, 0)
	_advance_to(opening, COPYRIGHT_SHOWN)
	assert_eq(opening.lcd.bgp, Gen1Opening.INTRO_PALETTE, "rBGP lands with PlaceString")
	assert_eq(opening.lcd.wy, 0, "the copyright is the window over vBGMap1")
	assert_eq(_phase_at(opening, Gen1Opening.PHASE_PRESENTS), 200)
	assert_eq(opening.lcd.lcdc & Gen1Lcd.LCDC_WINDOW, 0, "res B_LCDC_WINDOW")
	assert_true(opening.lcd.lcdc & Gen1Lcd.LCDC_BG_MAP != 0, "set B_LCDC_BG_MAP")


func test_the_star_falls_forty_frames_and_the_logo_flashes_three_times() -> void:
	var opening: Gen1Opening = _opening()
	var presents: int = _phase_at(opening, Gen1Opening.PHASE_PRESENTS)
	# `DelayFrames 64`, the three `CopyVideoData` frames, and the first move.
	var star: Array[Dictionary] = _advance_to(opening, presents + Gen1Opening.SHOOTING_STAR_DELAY + 3)
	assert_true(star.any(func(event: Dictionary) -> bool:
		return event["type"] == &"play_sfx" and int(event["sfx"]) == Gen1Opening.SFX_SHOOTING_STAR))
	assert_eq(int(opening.shadow_oam()[0]["y"]), 4, "four pixels down on its first frame")
	assert_eq(int(opening.shadow_oam()[0]["x"]), 156)
	_advance(opening, 40)
	assert_eq(int(opening.shadow_oam()[0]["y"]), Gen1Opening.OFF_SCREEN_Y, "cleared at $a0")
	assert_eq(opening.lcd.obp0, Gen1Opening._rotate_right_twice(Gen1Opening.SHOOTING_STAR_OBP0))
	_advance(opening, Gen1Opening.LOGO_FLASH_FRAMES * 2)
	assert_eq(opening.lcd.obp0, Gen1Opening._rotate_right_twice(
		Gen1Opening._rotate_right_twice(Gen1Opening._rotate_right_twice(Gen1Opening.SHOOTING_STAR_OBP0))
	))


func test_the_fight_opens_on_frame_524_and_the_title_on_1092() -> void:
	var opening: Gen1Opening = _opening()
	var events: Array[Dictionary] = _advance_to(opening, 523)
	assert_true(events.any(func(event: Dictionary) -> bool:
		return event["type"] == &"play_music" and int(event["music"]) == Gen1Opening.MUSIC_INTRO_BATTLE),
		"MUSIC_INTRO_BATTLE starts in front of the Delay3")
	assert_eq(_phase_at(opening, Gen1Opening.PHASE_INTRO_MOVIE), 524)
	_advance(opening, 1)
	assert_eq(int(opening.shadow_oam()[0]["y"]), 88, "InitIntroNidorinoOAM's first row")
	assert_eq(opening.lcd.scx, 2, "IntroMoveMon's first step")
	assert_eq(_phase_at(opening, Gen1Opening.PHASE_TITLE), 1092)
	_advance(opening, 20)
	assert_eq(opening.title_species(), 4, "STARTER1 first on Red")


func test_a_press_in_the_star_lands_on_the_fight_after_delay3() -> void:
	var opening: Gen1Opening = _opening()
	_advance(opening, 300)
	opening.press(Gen1Opening.PAD_A)
	opening.advance_frame()
	opening.release(Gen1Opening.PAD_A)
	assert_eq(_phase_at(opening, Gen1Opening.PHASE_INTRO_MOVIE), 304, "the read, .next, Delay3")


func test_the_chord_interrupts_where_a_tap_between_reads_does_not() -> void:
	var opening: Gen1Opening = _opening()
	_advance(opening, 700)
	opening.press(Gen1Opening.PAD_B)
	opening.advance_frame()
	opening.release(Gen1Opening.PAD_B)
	assert_eq(_phase_at(opening, Gen1Opening.PHASE_TITLE), 1092, "B is no button of the intro's")
	opening = _opening()
	_advance(opening, 700)
	opening.press(Gen1Opening.CHORD_CLEAR_SAVE)
	assert_lt(_phase_at(opening, Gen1Opening.PHASE_TITLE), 800)


func test_the_title_picks_a_different_mon_each_time_and_answers_a_press() -> void:
	var opening: Gen1Opening = _opening()
	_phase_at(opening, Gen1Opening.PHASE_TITLE)
	var seen: Array[int] = [opening.title_species()]
	_advance(opening, 1500)
	assert_true(opening.title_species() != seen[0], "TitleScreenPickNewMon rolled")
	var frame: int = opening.frame()
	opening.press(Gen1Opening.PAD_START)
	var answered: bool = false
	var cried: bool = false
	for _step: int in 400:
		for event: Dictionary in opening.advance_frame():
			answered = answered or event["type"] == &"title_menu"
			cried = cried or event["type"] == &"play_cry"
		if opening.finished():
			break
	assert_true(cried, "PlayCry before the white-out")
	assert_true(answered and opening.finished())
	assert_lt(opening.frame() - frame, 300)


func test_title_picks_can_be_handed_in() -> void:
	var opening: Gen1Opening = _opening()
	opening.set_title_picks([92, 95] as Array[int])
	_phase_at(opening, Gen1Opening.PHASE_TITLE)
	_advance(opening, 600)
	assert_eq(opening.title_species(), 92)


func test_yellow_runs_its_own_intro_and_resets_its_title() -> void:
	var opening: Gen1Opening = _opening(true)
	assert_eq(_phase_at(opening, Gen1Opening.PHASE_INTRO_MOVIE), 522)
	var title: int = _phase_at(opening, Gen1Opening.PHASE_TITLE)
	assert_gt(title, 522)
	var restarted: bool = false
	for _frame: int in Gen1Opening.YELLOW_RESET_FRAMES + 400:
		for event: Dictionary in opening.advance_frame():
			restarted = restarted or event["type"] == &"restart_opening"
		if opening.finished():
			break
	assert_true(restarted and opening.finished(), "IncrementResetCounter's $C00 frames")


func test_yellows_eyes_blink_on_the_timer() -> void:
	var opening: Gen1Opening = _opening(true)
	_phase_at(opening, Gen1Opening.PHASE_TITLE)
	var tiles: Dictionary = {}
	for _frame: int in 300:
		opening.advance_frame()
		tiles[int(opening.shadow_oam()[0]["tile"]) & ~Gen1Opening.YELLOW_BLINK_MASK] = true
	assert_eq(tiles.size(), 3, "open, half and closed")
