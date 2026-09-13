extends RefCounted

var _r: RefCounted = null

## `PlayIntro` and `DisplayTitleScreen` on the three Generation 1 caches, run
## whole with nothing pressed and then with each press the cartridge reads. The
## pins are what a real dump under an emulator agreed with frame by frame: the
## frame each phase opens on, and digests of the OAM and LCD registers through
## the opening and the first title mons, on the cartridge's own picks.
##   Godot --headless --path . -s res://tools/validate.gd -- gen1_opening

const FRAMES: int = 3000
## Dex numbers the cartridge's `Random` chose in the traced runs.
const PICKS: Dictionary = {
	&"red": [92, 95, 112, 132, 7, 1],
	&"blue": [142, 26, 56, 137, 37, 60],
	&"yellow": [],
}
## Phase frames from `LoadCopyrightAndTextBoxTiles`' `hWY` write, and the digests.
const EXPECTED: Dictionary = {
	&"red": {"presents": 200, "intro_movie": 524, "title": 1092,
		"oam": "395fbd78f3fe072a8ab88ff48db59641", "regs": "4c5788d0b327110d11f1d9dad28909e4"},
	&"blue": {"presents": 200, "intro_movie": 524, "title": 1092,
		"oam": "a38b8dbd6d86f6c78d7fa71ed1b640b8", "regs": "9538d00dd0387be20f8489c115962716"},
	&"yellow": {"presents": 198, "intro_movie": 522, "title": 1764,
		"oam": "9aeb98e42bad0c9d6874fef2b1ad4811", "regs": "47aaa30e49c79497ab1985e7eb5f5c70"},
}
## A frame inside `.bigStarLoop`, one inside `PlayIntroScene`, one on the title.
const PRESS_IN_STAR: int = 300
const PRESS_IN_INTRO: int = 700
const PRESS_ON_TITLE: Dictionary = {&"red": 1600, &"blue": 1600, &"yellow": 2100}
const HOLD_FRAMES: int = 30
## `IncrementResetCounter`'s $C00 frames of Yellow's title.
const YELLOW_RESET: int = 0xC00


func run(r: RefCounted) -> void:
	_r = r
	_r.each_game_of(RomRegistry.GEN1, _run_one)


func _run_one() -> void:
	var data: GameData = _r.data
	var game_id: StringName = _r.game_id
	var page: Gen1OpeningPage = Gen1OpeningPage.from_data(data)
	if not _r.check(page != null, "the cache carries no opening."):
		return
	_check_tables(data, game_id)
	_check_untouched(data, game_id, page)
	_check_presses(data, game_id)
	if game_id == RomRegistry.YELLOW:
		_check_yellow_reset(data)


## Every `TitleMons` species has a load and a pic; every packet paints two palettes.
func _check_tables(data: GameData, game_id: StringName) -> void:
	var opening: Dictionary = data.opening()
	for name: String in ["splash", "intro", "title"]:
		var attributes: PackedByteArray = Gen1OpeningPage.attribute_map(opening["blocks"][name])
		var used: Dictionary = {}
		for slot: int in attributes:
			used[slot] = true
		_r.check(used.size() >= 2, "%s's ATTR_BLK paints one palette." % name)
	if game_id == RomRegistry.YELLOW:
		var yellow: Dictionary = opening.get("yellow", {})
		_r.check(
			(yellow.get("frames", []) as Array).size() == Gen1Layout.YELLOW_INTRO_FRAMESETS
				and (yellow.get("oam_sets", []) as Array).size() == Gen1Layout.YELLOW_INTRO_OAM_SETS,
			"Yellow's animated object tables are short."
		)
		return
	var loads: Dictionary = Gen1Opening.TITLE_MON_LOAD_FRAMES[game_id]
	for mon: Variant in opening.get("title_mons", []):
		_r.check(loads.has(int(mon)), "TitleMons species %d has no measured load." % int(mon))
		_r.check(not data.species_pic(int(mon)).is_empty(), "species %d has no front pic." % int(mon))


## Nothing pressed: the phases open on their frames and the traces digest.
func _check_untouched(data: GameData, game_id: StringName, page: Gen1OpeningPage) -> void:
	var expected: Dictionary = EXPECTED[game_id]
	var opening: Gen1Opening = _opening(data, game_id)
	var oam := HashingContext.new()
	oam.start(HashingContext.HASH_MD5)
	var regs := HashingContext.new()
	regs.start(HashingContext.HASH_MD5)
	var phases: Dictionary = {}
	var frame: int = 0
	while frame < FRAMES and not opening.finished():
		var before: StringName = opening.phase()
		opening.advance_frame()
		if opening.phase() != before:
			phases[String(opening.phase())] = frame
		for entry: Dictionary in opening.shadow_oam():
			if int(entry["y"]) != 0 or int(entry["x"]) != 0 or int(entry["tile"]) != 0:
				oam.update(("%d %d %d %d\n" % [frame, entry["y"], entry["x"], entry["tile"]]).to_utf8_buffer())
		var lcd: Gen1Lcd = opening.lcd
		regs.update(("%d %02x %02x %02x %02x %02x %02x %02x\n" % [
			frame, lcd.lcdc, lcd.scy, lcd.scx, lcd.wy, lcd.bgp, lcd.obp0, lcd.obp1,
		]).to_utf8_buffer())
		if frame == PRESS_IN_INTRO:
			_r.check(page.draw(opening).get_size() == Vector2i(Gen1Lcd.WIDTH, Gen1Lcd.HEIGHT),
				"the page draws no screen.")
		frame += 1
	_r.check(not opening.finished(), "the title ended with nothing pressed.")
	for name: String in ["presents", "intro_movie", "title"]:
		_r.check(
			int(phases.get(name, -1)) == int(expected[name]),
			"%s opens on frame %d, not %d." % [name, int(phases.get(name, -1)), int(expected[name])]
		)
	var oam_digest: String = oam.finish().hex_encode()
	var regs_digest: String = regs.finish().hex_encode()
	print("%s: phases %s oam %s regs %s" % [game_id, JSON.stringify(phases), oam_digest, regs_digest])
	_r.check(oam_digest == String(expected["oam"]), "the OAM trace digests to %s." % oam_digest)
	_r.check(regs_digest == String(expected["regs"]), "the register trace digests to %s." % regs_digest)


## A press in the star, one in the fight, one on the title.
func _check_presses(data: GameData, game_id: StringName) -> void:
	var expected: Dictionary = EXPECTED[game_id]
	var opening: Gen1Opening = _opening(data, game_id)
	_advance(opening, PRESS_IN_STAR)
	opening.press(Gen1Opening.PAD_A)
	opening.advance_frame()
	opening.release(Gen1Opening.PAD_A)
	var landed: int = _advance_until(opening, Gen1Opening.PHASE_INTRO_MOVIE, FRAMES)
	_r.check(
		landed > 0 and landed < int(expected["intro_movie"]),
		"a press in the star reached the fight on frame %d." % landed
	)
	# `.next` skips the forty frames behind the stars and nothing else.
	_r.check(
		landed == PRESS_IN_STAR + 2 + Gen1Opening.DELAY3,
		"the star skip reached the fight on frame %d." % landed
	)
	# `Joypad` runs only inside `CheckForUserInterruption`, so a tap between
	# two reads is lost on the cartridge too; the button is held.
	opening = _opening(data, game_id)
	_advance(opening, PRESS_IN_INTRO)
	opening.press(Gen1Opening.PAD_START)
	_advance(opening, HOLD_FRAMES)
	opening.release(Gen1Opening.PAD_START)
	landed = _advance_until(opening, Gen1Opening.PHASE_TITLE, FRAMES)
	_r.check(
		landed > 0 and landed < int(expected["title"]),
		"a press in the fight reached the title on frame %d." % landed
	)
	opening = _opening(data, game_id)
	_advance(opening, int(PRESS_ON_TITLE[game_id]))
	opening.press(Gen1Opening.PAD_A)
	var cried: bool = false
	var answered: bool = false
	for _frame: int in 600:
		for event: Dictionary in opening.advance_frame():
			cried = cried or event["type"] == &"play_cry"
			answered = answered or event["type"] == &"title_menu"
		if opening.finished():
			break
	_r.check(opening.finished() and answered, "a press on the title did not answer MainMenu.")
	_r.check(cried == (game_id != RomRegistry.YELLOW), "the title's cry is Red and Blue's alone.")


## `.doTitlescreenReset` after $C00 frames of Yellow's title.
func _check_yellow_reset(data: GameData) -> void:
	var opening: Gen1Opening = _opening(data, RomRegistry.YELLOW)
	_advance_until(opening, Gen1Opening.PHASE_TITLE, FRAMES)
	var restarted: int = -1
	for frame: int in YELLOW_RESET + 600:
		for event: Dictionary in opening.advance_frame():
			if event["type"] == &"restart_opening":
				restarted = frame
		if opening.finished():
			break
	_r.check(restarted > YELLOW_RESET, "Yellow's title reset on frame %d of it." % restarted)


func _opening(data: GameData, game_id: StringName) -> Gen1Opening:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var opening: Gen1Opening = Gen1Opening.create(data, rng)
	var picks: Array[int] = []
	for pick: Variant in PICKS[game_id]:
		picks.append(int(pick))
	opening.set_title_picks(picks)
	return opening


func _advance(opening: Gen1Opening, frames: int) -> void:
	for _frame: int in frames:
		opening.advance_frame()


func _advance_until(opening: Gen1Opening, phase: StringName, cap: int) -> int:
	for _frame: int in cap:
		if opening.phase() == phase:
			return opening.frame()
		opening.advance_frame()
	return -1
