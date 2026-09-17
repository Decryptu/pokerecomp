extends RefCounted

var _r: RefCounted = null

## Yellow's `SurfingPikachuMinigame` run whole with nothing pressed and with
## RIGHT held, its tables counted, and the three printer pages drawn.
##   Godot --headless --path . -s res://tools/validate.gd -- gen1_surfing

const SEED: int = 0x5AFE
const FRAME_CAP: int = 12000
## The frame each routine is first on with nothing pressed on this seed; the
## first `RunGame` frame is the cartridge's own.
const IDLE_ROUTINES: Dictionary = {
	Gen1SurfingMinigame.Routine.START: 1, Gen1SurfingMinigame.Routine.RUN: 237,
	Gen1SurfingMinigame.Routine.WAIT_RESULTS: 4982,
	Gen1SurfingMinigame.Routine.SCROLL_RESULTS: 5175,
	Gen1SurfingMinigame.Routine.DRAW_RESULTS: 5212, Gen1SurfingMinigame.Routine.HP_LEFT: 5213,
	Gen1SurfingMinigame.Routine.RADNESS: 5246, Gen1SurfingMinigame.Routine.TOTAL: 5311,
	Gen1SurfingMinigame.Routine.ADD_HP: 5376, Gen1SurfingMinigame.Routine.ADD_RADNESS: 5465,
	Gen1SurfingMinigame.Routine.WAIT_LAST: 5531, Gen1SurfingMinigame.Routine.EXIT: 5774,
	Gen1SurfingMinigame.Routine.EXIT | Gen1SurfingMinigame.ROUTINE_DONE: 5775,
}
const IDLE_TOTAL: int = 0x1256
const IDLE_END: int = 5777
const HELD_TOTAL: int = 0x1107
const HELD_END: int = 6938
const HOLD_FROM: int = 400
const WAVE_KINDS: Dictionary = {"choose": 1, "advance": 113, "reset": 9, "hold": 1}
## `UnknownPacket_72751`'s one box.
const TITLE_PALETTE_CELLS: int = 72
const PAGES: Array[String] = ["diploma", "high_score", "portrait"]


func run(r: RefCounted) -> void:
	_r = r
	_r.each_game_of(RomRegistry.GEN1, _run_one)


func _run_one() -> void:
	var data: GameData = _r.data
	if _r.game_id != RomRegistry.YELLOW:
		_r.check(data.surfing().is_empty(), "the cache carries a beach it has no map for.")
		_r.check(Gen1SurfingMinigame.create(data, null, 0, false, false) == null,
			"the minigame opens off Yellow.")
		return
	_check_tables(data)
	_check_idle_run(data)
	_check_held_run(data)
	_check_printer_pages(data)


func _check_tables(data: GameData) -> void:
	var surfing: Dictionary = data.surfing()
	_r.check((surfing.get("spawn_states", []) as Array).size() == Gen1Layout.SURFING_SPAWN_STATES,
		"SurfingPikachuObjectSpawnData is not thirteen rows.")
	_r.check((surfing.get("frames", []) as Array).size() == Gen1Layout.SURFING_FRAMESETS,
		"SurfingPikachuFrames is not 28 framesets.")
	_r.check((surfing.get("oam_sets", []) as Array).size() == Gen1Layout.SURFING_OAM_SETS,
		"SurfingPikachuOAMData is not 36 sets.")
	var kinds: Dictionary = {}
	for row: Dictionary in surfing.get("wave_functions", []) as Array:
		kinds[String(row["kind"])] = int(kinds.get(String(row["kind"]), 0)) + 1
	_r.check(kinds == WAVE_KINDS, "the wave functions read %s." % [kinds])
	_r.check((surfing.get("wave_patterns", []) as Array).size() == Gen1Layout.SURFING_WAVE_PATTERNS,
		"the wave slices are not thirty.")
	var starts: Array = surfing.get("wave_starts", [])
	var functions: Array = surfing.get("wave_functions", [])
	for start: Variant in starts:
		_r.check(int(start) < functions.size() and String(functions[int(start)]["kind"]) == "advance",
			"wave start $%02X is not the first slice of a sequence." % int(start))
	var opening: Dictionary = data.opening()
	_r.check((opening["palettes"] as Dictionary).has("surfing")
		and (opening["palettes"] as Dictionary).has("surfing_title"),
		"the two SetPal_PikachusBeach packets are not in the opening.")
	var title: PackedByteArray = Gen1OpeningPage.attribute_map(opening["blocks"]["surfing_title"])
	var lit: int = 0
	for cell: int in title:
		lit += 1 if cell == 1 else 0
	_r.check(lit == TITLE_PALETTE_CELLS, "the title's box paints %d cells in palette 1." % lit)
	_r.note("gen1 surfing waves %s" % [kinds])


func _new_game(data: GameData) -> Gen1SurfingMinigame:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	return Gen1SurfingMinigame.create(data, rng, 0, true, false)


func _check_idle_run(data: GameData) -> void:
	var game: Gen1SurfingMinigame = _new_game(data)
	if not _r.check(game != null, "the minigame did not open."):
		return
	var firsts: Dictionary = _drive(game, -1, 0)
	var expected: Dictionary = {}
	for routine: int in IDLE_ROUTINES:
		expected[routine] = int(IDLE_ROUTINES[routine])
	_r.check(firsts == expected, "an idle run's routines opened on %s." % [firsts])
	_r.check(game.finished() and game.frame() == IDLE_END,
		"an idle run ended on frame %d." % game.frame())
	_r.check(game.total_score() == IDLE_TOTAL, "an idle run scored $%04X." % game.total_score())
	_r.check(game.hi_score_beaten() and game.hi_score() == IDLE_TOTAL,
		"an idle run's score did not stand as the hi score.")
	_r.note("gen1 surfing idle run %d frames, total $%04X, hi $%04X beaten %s, routines %s" % [
		game.frame(), game.total_score(), game.hi_score(), game.hi_score_beaten(), firsts,
	])


func _check_held_run(data: GameData) -> void:
	var game: Gen1SurfingMinigame = _new_game(data)
	if game == null:
		return
	var firsts: Dictionary = _drive(game, HOLD_FROM, FRAME_CAP)
	_r.check(game.finished() and game.frame() == HELD_END,
		"a held run ended on frame %d." % game.frame())
	_r.check(game.total_score() == HELD_TOTAL, "a held run scored $%04X." % game.total_score())
	_r.note("gen1 surfing held run %d frames, total $%04X, run from %d" % [
		game.frame(), game.total_score(), int(firsts.get(Gen1SurfingMinigame.Routine.RUN, -1)),
	])


## A pressed while a state waits on it, RIGHT held from [param hold_from].
func _drive(game: Gen1SurfingMinigame, hold_from: int, hold_frames: int) -> Dictionary:
	var firsts: Dictionary = {}
	var pressing: bool = false
	while not game.finished() and game.frame() < FRAME_CAP:
		var frame: int = game.frame()
		if frame == hold_from:
			game.press(Gen1SurfingMinigame.PAD_RIGHT)
		if hold_from >= 0 and frame == hold_from + hold_frames:
			game.release(Gen1SurfingMinigame.PAD_RIGHT)
		var waiting: bool = game.routine() in [
			Gen1SurfingMinigame.Routine.EXIT, Gen1SurfingMinigame.Routine.GAME_OVER,
		]
		if waiting and not pressing:
			game.press(Gen1SurfingMinigame.PAD_A)
			pressing = true
		game.advance_frame()
		if not firsts.has(game.routine()):
			firsts[game.routine()] = game.frame()
	return firsts


func _check_printer_pages(data: GameData) -> void:
	var page: Gen2DiplomaPage = Gen2DiplomaPage.from_data(data)
	if not _r.check(page != null, "the diploma page did not build."):
		return
	var status: String = data.printer_status_string("error_2")
	var cancel: String = data.printer_status_string("press_b")
	_r.check(status.begins_with(" Printer Error 2") and cancel == "Press B to Cancel",
		"the printer strings read %s and %s." % [status, cancel])
	var mon: Dictionary = {
		"species": 25, "dex_number": 25, "species_name": "PIKACHU", "nickname": "PIKA",
		"level": 12, "max_hp": 34, "stats": {"attack": 20, "defense": 15, "speed": 30, "sp_attack": 18},
		"moves": [84, 45, 39, 86], "ot_name": "ASH", "ot_id": 12345,
	}
	for kind: String in PAGES:
		var printed: Image = page.render_gen1_printer(
			kind, {"player": "ASH", "hi_score": 0x1234, "mon": mon}, status, cancel
		)
		_r.check(printed != null and _colours(printed) >= 3,
			"the %s page draws %d colours under the status box." % [kind, _colours(printed)])
	var preview: Image = page.render_gen1_printer("high_score", {"player": "ASH", "hi_score": 0x1234}, "", "")
	_r.check(preview != null and _colours(preview) >= 3, "the high-score page draws blank.")


static func _colours(image: Image) -> int:
	var seen: Dictionary = {}
	for y: int in range(0, image.get_height(), 4):
		for x: int in range(0, image.get_width(), 4):
			seen[image.get_pixel(x, y).to_rgba32()] = true
	return seen.size()
