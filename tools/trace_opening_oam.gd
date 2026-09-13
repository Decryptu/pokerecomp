extends SceneTree

## Dumps the opening's shadow OAM against a real cache, one `frame slot y x
## tile` line per sprite per frame, the OAM bytes as a cartridge's buffer holds
## them: two faithful implementations of `PlaySpriteAnimations` put the same
## sprites in the same slots on the same frames. `<game> <phase> [out.txt]
## [frames] [picks]`, with `phase` one of PHASES. `gen1` runs the whole opening,
## writes the LCD registers beside the trace as `<out>.regs`, shoots in the Game
## Boy's greys, and `picks` are the dex numbers a cartridge's title chose.

const PHASES: Array[String] = ["presents", "intro", "gs_intro", "title", "trade", "gen1"]
## The whole opening and the first title mons; Red's title never ends alone.
const GEN1_FRAME_CAP: int = 3000

## The title screen runs until its own timeout, which is longer than anything
## worth diffing; this is well past `TitleScreenEnd`'s own count.
const TITLE_FRAME_CAP: int = 4000
## Either movie ends itself; this only stops a run that never does.
const MOVIE_FRAME_CAP: int = 4000

## Frames to write a PNG for, beside the trace's own output path.
var _shots: Dictionary = {}
var _shot_prefix: String = "res://presents"
## `frame scene counter` per frame, for whichever phase keeps those.
var _state := PackedStringArray()


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2 or not PHASES.has(args[1]):
		push_error(
			"Usage: trace_opening_oam.gd -- <game> <%s> [out.txt]"
			% "|".join(PHASES)
		)
		quit(1)
		return
	var data: GameData = _open(StringName(args[0]))
	if data == null:
		quit(1)
		return
	if args.size() > 2:
		if PokeToolPath.refuses(args[2]):
			quit(2)
			return
		_shot_prefix = args[2].get_basename()
	if args.size() > 3:
		_parse_shots(args[3])
	var lines: PackedStringArray = _trace(args, data)
	if args.size() > 2:
		var file := FileAccess.open(args[2], FileAccess.WRITE)
		if file == null:
			push_error("Could not write %s." % args[2])
			quit(1)
			return
		file.store_string("\n".join(lines) + "\n")
		print("%d lines to %s" % [lines.size(), args[2]])
		if not _state.is_empty():
			var states := FileAccess.open(args[2] + ".state", FileAccess.WRITE)
			if states != null:
				states.store_string("\n".join(_state) + "\n")
	else:
		print("\n".join(lines))
	quit(0)


## `3,10-12` marks frames 3, 10, 11 and 12 for a PNG each.
func _parse_shots(spec: String) -> void:
	for value: String in spec.split(","):
		var dash: int = value.find("-", 1)
		if dash < 0:
			_shots[int(value)] = true
			continue
		for frame: int in range(int(value.left(dash)), int(value.substr(dash + 1)) + 1):
			_shots[frame] = true


func _trace(args: PackedStringArray, data: GameData) -> PackedStringArray:
	match args[1]:
		"presents":
			return _trace_presents(data)
		"intro":
			return _trace_intro(data)
		"gs_intro":
			return _trace_gs_intro(data)
		"trade":
			return _trace_trade(data)
		"gen1":
			var out_path: String = args[2] if args.size() > 2 else ""
			return _trace_gen1(data, out_path, args[4] if args.size() > 4 else "")
	return _trace_title(data)


## `GameFreakPresentsScene` from its first frame to the one it sets its own exit
## bit on, which is what the phase's pinned budget counts.
func _trace_presents(data: GameData) -> PackedStringArray:
	var page: Gen2GameFreakPresentsPage = Gen2GameFreakPresentsPage.from_data(data)
	if page == null:
		push_error("%s has no GameFreak Presents art." % data.id)
		return PackedStringArray()
	var phase := Gen2GameFreakPresents.new()
	phase.start(data.id, Gen2BattleAnimData.from_game_data(data))
	var out := PackedStringArray()
	var frame: int = 0
	var words: int = -1
	while not phase.finished():
		_append_frame(out, frame, page.shadow_oam(phase))
		if _shots.has(frame):
			var image: Image = page.draw(phase)
			if image != null:
				image.save_png("%s_f%d.png" % [_shot_prefix, frame])
		# The words are background, so they are not in the trace; printing the
		# frame each is placed on is what aligns it, since a cartridge's own
		# tilemap says the same thing.
		if phase.words() != words:
			words = phase.words()
			print("frame %d: words %d" % [frame, words])
		phase.advance_frame()
		frame += 1
	_append_frame(out, frame, page.shadow_oam(phase))
	print("frame %d: finished" % frame)
	return out


## `CrystalIntro` from its first frame to the one it sets its own exit bit on,
## driven with no buttons held so nothing skips it.
func _trace_intro(data: GameData) -> PackedStringArray:
	var page: Gen2IntroMoviePage = Gen2IntroMoviePage.from_data(data)
	if page == null:
		push_error("%s has no intro movie art." % data.id)
		return PackedStringArray()
	var movie: Gen2IntroMovie = Gen2IntroMovie.create(
		data, Gen2BattleAnimData.from_game_data(data)
	)
	var out := PackedStringArray()
	var frame: int = 0
	var scene: int = -1
	while not movie.finished() and frame < MOVIE_FRAME_CAP:
		_append_frame(out, frame, page.shadow_oam(movie))
		_append_state(frame, movie.scene(), movie.counter(), movie.waiting())
		if _shots.has(frame):
			page.draw(movie).save_png("%s_f%d.png" % [_shot_prefix, frame])
		if movie.scene() != scene:
			scene = movie.scene()
			print("frame %d: scene %d" % [frame, scene])
		movie.advance_frame()
		frame += 1
	print("frame %d: finished" % frame)
	return out


## `GoldSilverIntro`, the same way.
func _trace_gs_intro(data: GameData) -> PackedStringArray:
	var page: Gen2GoldSilverIntroPage = Gen2GoldSilverIntroPage.from_data(data)
	if page == null:
		push_error("%s has no intro movie art." % data.id)
		return PackedStringArray()
	var movie: Gen2GoldSilverIntro = Gen2GoldSilverIntro.create(
		data, Gen2BattleAnimData.from_game_data(data)
	)
	var out := PackedStringArray()
	var frame: int = 0
	var scene: int = -1
	while not movie.finished() and frame < MOVIE_FRAME_CAP:
		_append_frame(out, frame, page.shadow_oam(movie))
		_append_state(
			frame, movie.scene(), movie.counter(), movie.waiting(),
			movie.secondary_counter()
		)
		if _shots.has(frame):
			page.draw(movie).save_png("%s_f%d.png" % [_shot_prefix, frame])
		if movie.scene() != scene:
			scene = movie.scene()
			print("frame %d: scene %d" % [frame, scene])
		movie.advance_frame()
		frame += 1
	print("frame %d: finished" % frame)
	return out


## `TradeAnimation`'s first half, on the pair the oracle puts a cartridge into.
func _trace_trade(data: GameData) -> PackedStringArray:
	var page: Gen2TradeAnimationPage = Gen2TradeAnimationPage.from_data(data)
	if page == null:
		push_error("%s has no trade animation art." % data.id)
		return PackedStringArray()
	var movie: Gen2TradeAnimation = Gen2TradeAnimation.create(
		data, Gen2BattleAnimData.from_game_data(data), {
			"player": {
				"species": 152, "species_name": "CHIKORITA", "sender_name": "RED",
				"ot_name": "RED", "ot_id": 12345, "caught_gender": 1,
			},
			"ot": {
				"species": 25, "species_name": "PIKACHU", "sender_name": "BLUE",
				"ot_name": "BLUE", "ot_id": 54321, "caught_gender": 2,
			},
			"link_mode": Gen2LinkSession.LINK_TRADECENTER,
		}
	)
	var out := PackedStringArray()
	var frame: int = 0
	while not movie.finished() and frame < MOVIE_FRAME_CAP:
		_append_frame(out, frame, page.shadow_oam(movie))
		if _shots.has(frame):
			page.draw(movie).save_png("%s_f%d.png" % [_shot_prefix, frame])
		movie.advance_frame()
		frame += 1
	print("frame %d: finished" % frame)
	return out


## `TitleScreenScene` from its first frame, which is the entrance scrolling the
## screen in, to the one that answers. Driven with no buttons held, the way a
## cartridge left alone runs it, so the timeout is what ends it.
func _trace_title(data: GameData) -> PackedStringArray:
	var page: Gen2TitlePage = Gen2TitlePage.from_data(data)
	if page == null:
		push_error("%s has no title screen art." % data.id)
		return PackedStringArray()
	var scene: Gen2TitleScene = Gen2TitleScene.create(
		data.id, Gen2BattleAnimData.from_game_data(data)
	)
	var out := PackedStringArray()
	var frame: int = 0
	var where: StringName = &""
	while not scene.finished() and frame < TITLE_FRAME_CAP:
		_append_frame(out, frame, page.shadow_oam(scene))
		if _shots.has(frame):
			var image: Image = page.draw(scene)
			if image != null:
				image.save_png("%s_f%d.png" % [_shot_prefix, frame])
		if scene.scene() != where:
			where = scene.scene()
			print("frame %d: %s" % [frame, where])
		scene.advance_frame()
		frame += 1
	print("frame %d: finished" % frame)
	return out


## The opening with nothing pressed; the register file is
## `frame LCDC SCY SCX WY BGP OBP0 OBP1 phase`.
func _trace_gen1(data: GameData, out_path: String, picks: String) -> PackedStringArray:
	var page: Gen1OpeningPage = Gen1OpeningPage.from_data(data)
	if page == null:
		push_error("%s has no opening." % data.id)
		return PackedStringArray()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var opening: Gen1Opening = Gen1Opening.create(data, rng)
	if not picks.is_empty():
		var chosen: Array[int] = []
		for value: String in picks.split(","):
			chosen.append(int(value))
		opening.set_title_picks(chosen)
	var out := PackedStringArray()
	var regs := PackedStringArray()
	var frame: int = 0
	var phase: StringName = &""
	var species: int = 0
	while not opening.finished() and frame < GEN1_FRAME_CAP:
		opening.advance_frame()
		var live: Array[Dictionary] = []
		for entry: Dictionary in opening.shadow_oam():
			if int(entry["y"]) != 0 or int(entry["x"]) != 0 or int(entry["tile"]) != 0:
				live.append(entry)
		_append_frame(out, frame, live)
		var lcd: Gen1Lcd = opening.lcd
		regs.append("%d %02x %02x %02x %02x %02x %02x %02x %s" % [
			frame, lcd.lcdc, lcd.scy, lcd.scx, lcd.wy, lcd.bgp, lcd.obp0, lcd.obp1,
			opening.phase(),
		])
		if _shots.has(frame):
			page.draw_shades(opening).save_png("%s_f%d.png" % [_shot_prefix, frame])
		if opening.phase() != phase:
			phase = opening.phase()
			print("frame %d: %s" % [frame, phase])
		if opening.title_species() != species:
			species = opening.title_species()
			print("frame %d: title mon %d" % [frame, species])
		frame += 1
	print("frame %d: finished" % frame)
	if not out_path.is_empty():
		var file := FileAccess.open(out_path + ".regs", FileAccess.WRITE)
		if file != null:
			file.store_string("\n".join(regs) + "\n")
	return out


## A frame paying a setup scene's delay is written under the setup scene's own
## index, which is the one the cartridge is still in while it spends it.
func _append_state(
	frame: int, scene: int, counter: int, waiting: bool, secondary: int = -1
) -> void:
	# A setup scene's counter is the previous scene's last value until the
	# routine's own tail zeroes it, and the routine is spread over every
	# `DelayFrame` its decompressions spend, so a waiting frame carries no
	# counter to line up on and is written as -1.
	var values: Array = [frame, scene - 1, -1] if waiting \
		else [frame, scene, counter]
	if secondary >= 0:
		values.append(secondary)
	var words := PackedStringArray()
	for value: int in values:
		words.append(str(value))
	_state.append(" ".join(words))


func _append_frame(out: PackedStringArray, frame: int, entries: Array[Dictionary]) -> void:
	var slot: int = 0
	for entry: Dictionary in entries:
		out.append("%d %d %d %d %d" % [
			frame, slot, int(entry["y"]), int(entry["x"]), int(entry["tile"]),
		])
		slot += 1


func _open(game: StringName) -> GameData:
	var sha1: String = RomRegistry.sha1_for(game)
	var directory: String = RomCache.directory_for(game, sha1) if not sha1.is_empty() else ""
	if directory.is_empty() or not RomCache.is_usable(directory):
		push_error("No cache for %s. Run tools/import_rom.gd first." % game)
		return null
	var data: GameData = GameData.open_directory(directory)
	if data == null:
		push_error("Could not open the cache for %s." % game)
	return data
