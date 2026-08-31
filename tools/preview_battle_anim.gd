extends SceneTree

## Captures a battle animation mid-flight against a real imported cache, which
## `tools/screenshot.gd` cannot drive: an animation needs a turn taken, an event
## queue walked to the animation it wants, and a counted number of frames spent
## inside it. The flags and the `catch`, `0`, `miss` and frame-range forms are
## documented below.
##   Godot --path . -s res://tools/preview_battle_anim.gd -- \
##       <game> <output.png> <move> <side> <frames> [scene_off] [matchup=<enemy>,<player>]

const WINDOW_SIZE := Vector2i(1152, 648)
## Enough frames for the scene to lay out before anything is driven, and enough
## after it for the viewport to draw what was driven.
const SETTLE_FRAMES: int = 4
const DRAW_FRAMES: int = 3
## A runaway guard on the event pump: no turn produces anywhere near this many
## steps, and a driver that never reaches its animation should say so.
const MAX_STEPS: int = 4096
## How long a line that owes a press is left on screen before this driver presses
## it. A person is what the cartridge waits for; a fixed count is what makes two
## runs of this tool the same run.
const PRESS_AFTER: int = 40
## `<move> catch` throws a ball instead of taking a turn. It is not a move
## number, so it cannot collide with one.
const CATCH_MOVE: int = -1

## `matchup=` is what a picture reported against one pair is shot as.
const DEFAULT_MATCHUP: Vector2i = Vector2i(16, 155)
const MATCHUP_LEVEL: int = 20

var _screen: Gen2BattleScreen = null
var _output_path: String = ""
var _move: int = 1
var _side_is_enemy: bool = false
var _frames_in: int = 0
var _range_lo: int = -1
var _range_hi: int = -1
var _cursor: int = 0
var _settle: int = 0
var _held: int = 0
var _last_trace: String = ""
var _scene_off: bool = false
var _with_intro: bool = false
var _miss: bool = false
var _frames: int = 0
var _matchup: Vector2i = DEFAULT_MATCHUP


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 5:
		push_error(
			"Usage: preview_battle_anim.gd -- <game> <output.png> <move> <side> <frames> [scene_off]"
		)
		quit(1)
		return
	_output_path = args[1]
	if Gen2ToolPath.refuses(_output_path):
		quit(2)
		return
	_move = CATCH_MOVE if args[2] == "catch" else int(args[2])
	_side_is_enemy = int(args[3]) != 0
	if args[4].contains("-"):
		var span: PackedStringArray = args[4].split("-", false)
		_range_lo = int(span[0])
		_range_hi = int(span[1]) if span.size() > 1 else int(span[0])
		_frames_in = _range_hi
	else:
		_frames_in = int(args[4])
	for flag: String in args.slice(5):
		if flag.begins_with("matchup="):
			var pair: PackedStringArray = flag.trim_prefix("matchup=").split(",", false)
			if pair.size() != 2:
				push_error("matchup= wants <enemy>,<player>")
				quit(1)
				return
			_matchup = Vector2i(int(pair[0]), int(pair[1]))
			continue
		match flag:
			"scene_off":
				_scene_off = true
			"with_intro":
				_with_intro = true
			"miss":
				_miss = true
			_:
				push_error("Unknown flag %s" % flag)
				quit(1)
				return

	var data: GameData = GameData.open(StringName(args[0]))
	if data == null:
		push_error("No cache for %s. Import roms/%s.gbc first." % [args[0], args[0]])
		quit(1)
		return

	## The shared object rather than the file: `CheckBattleScene` reads what
	## `current()` answers, and a capture has no business rewriting the option
	## the owner of this machine chose.
	Gen2OptionsStore.current().battle_scene = not _scene_off

	root.set_content_scale_size(WINDOW_SIZE)
	root.size = WINDOW_SIZE
	var packed: PackedScene = load("res://game/battle/battle_screen.tscn")
	_screen = packed.instantiate() as Gen2BattleScreen
	_screen.set_data(data)
	root.add_child(_screen)
	current_scene = _screen
	# The screen counts hardware frames off `_process` deltas. The frames spent
	# here are counted rather than timed, so nothing drifts while the viewport
	# catches up with what was driven.
	_screen.set_process(false)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < SETTLE_FRAMES:
		return false
	if _frames == SETTLE_FRAMES:
		if not _drive():
			quit(1)
			return true
		return false
	if _range_lo >= 0:
		return _shoot_range()
	if _frames < SETTLE_FRAMES + DRAW_FRAMES:
		return false

	var image: Image = Gen2ToolPath.capture(root)
	if image == null:
		quit(1)
		return true
	var error: Error = image.save_png(_output_path)
	if error != OK:
		push_error("Could not write %s (error %d)" % [_output_path, error])
		quit(1)
		return true
	print("Wrote %s (%dx%d) %s" % [
		_output_path, image.get_width(), image.get_height(),
		JSON.stringify(_screen.animation_snapshot()),
	])
	quit(0)
	return true


## One frame of the entrance per captured picture, the viewport given
## [constant DRAW_FRAMES] to catch up with each. The frame numbers are counted
## from the one the pics stop sliding on, which is what the cartridge trace is
## aligned to as well.
func _shoot_range() -> bool:
	## Godot turns processing back on for a node whose script has a `_process`,
	## and the screen counts hardware frames in its own. Taken away again here
	## rather than once in `_initialize`, or three of its frames are spent
	## between every two of this driver's.
	_screen.set_process(false)
	if _settle > 0:
		_settle -= 1
		return false
	# `DoBattle`'s first `BattleMenu` is the end of the opening, so a range that
	# runs past it stops there rather than writing the menu over and over.
	var done: bool = _cursor > _range_lo and not _screen.entrance_running() \
		and not _screen.intro_running() and not _screen.frames_running() \
		and not bool(_screen.battle_snapshot()["awaits_press"])
	if _cursor > _range_hi or done:
		print("Wrote %d frames to %s_f*.png" % [
			mini(_cursor, _range_hi + 1) - _range_lo, _prefix()
		])
		quit(0)
		return true
	if _cursor >= _range_lo:
		# The window is not guaranteed to have been composited between two of
		# this driver's frames, and an uncomposited one hands back the last
		# picture that was: a whole capture can come out as one frame repeated.
		# Drawing on demand is what makes a run of this tool reproducible.
		var image: Image = Gen2ToolPath.capture(root)
		if image == null:
			quit(1)
			return true
		var error: Error = image.save_png("%s_f%d.png" % [_prefix(), _cursor])
		if error != OK:
			push_error("Could not write frame %d (error %d)" % [_cursor, error])
			quit(1)
			return true
	_trace()
	_cursor += 1
	_entrance_frame()
	_settle = DRAW_FRAMES
	return false


## The frame the opening changed on, and what it changed to. The cartridge's own
## trace is a list of the frames its routines ran on, so this is the artefact the
## two are diffed as.
func _trace() -> void:
	var now: Dictionary = _screen.entrance_snapshot()
	var line: String = JSON.stringify(now)
	if line == _last_trace:
		return
	_last_trace = line
	print("%d %s" % [_cursor, line])


func _prefix() -> String:
	return _output_path.trim_suffix(".png")


## One hardware frame of the opening, with the press a person would make.
## `WildPokemonAppearedText`, `WantsToBattleText` and the `cont` inside
## `BattleText_EnemySentOut` all wait on a button; this counts
## [constant PRESS_AFTER] frames of the line standing finished and then presses,
## so a run of this tool is reproducible where a person is not.
func _entrance_frame() -> void:
	_screen.advance_frame()
	if _screen.frames_running():
		_held = 0
		return
	var box: Gen2TextBox = _screen.get("_box")
	if box != null and box.is_revealing():
		_held = 0
		return
	if not _screen.entrance_running() and not bool(_screen.battle_snapshot()["awaits_press"]):
		_held = 0
		return
	_held += 1
	if _held < PRESS_AFTER:
		return
	_held = 0
	_screen.finish()
	_screen.advance()


## The entrance, stopped [member _frames_in] frames after the slide. `<side>` 1
## opens a real trainer's fight instead of a wild one, which is the branch with
## `SFX_SHINE`, a line of its own and two balls thrown rather than one.
func _drive_entrance() -> bool:
	if _side_is_enemy:
		_screen.show_trainer(1, 0)
	else:
		_show_matchup()
	if _range_lo >= 0:
		# `InitBattleDisplay` and `BattleIntroSlidingPics` are frames of the
		# opening like any other; a diff against the cartridge trace wants them
		# spent first, and a recording wants them in the picture.
		if not _with_intro:
			while _screen.intro_running():
				_screen.advance_frame()
		return true
	while _screen.intro_running():
		_screen.advance_frame()
	for _frame: int in _frames_in:
		if not _screen.frames_running() and _screen.entrance_running():
			_screen.finish()
			_screen.advance()
			continue
		_screen.advance_frame()
	return true


func _show_matchup() -> void:
	_screen.show_matchup(_matchup.x, _matchup.y, MATCHUP_LEVEL, MATCHUP_LEVEL)


## Everything `DoBattle` spends before its first menu, so a turn driven after
## this is a turn rather than the ball still being thrown.
func _settle_entrance() -> void:
	for _step: int in MAX_STEPS:
		if not _screen.frames_running() and not _screen.entrance_running():
			return
		if _screen._audio_player != null:
			_screen._audio_player.stop_all()
		if _screen.frames_running():
			_screen.advance_frame()
			continue
		_screen.finish()
		_screen.advance()


## `PokeBallEffect`'s own throw, which is not a turn: `ANIM_THROW_POKE_BALL` is
## played by the item rather than by a move, and `<side>` decides whether the
## Pokemon is caught or gets out, since only `anim_checkpokeball` tells the two
## endings apart.
func _drive_capture() -> bool:
	_show_matchup()
	while _screen.intro_running():
		_screen.advance_frame()
	_settle_entrance()
	## The ball selector belongs to a wild battle a world screen opened, and this
	## driver has no world. What is being photographed is the animation the
	## resolved throw plays, so it is asked for the way `complete_capture` asks
	## for it: a POKE BALL, three wobbles, and the ending `<side>` names.
	_screen._begin_capture_animation(
		Gen2WorldPartyHost.ITEM_POKE_BALL, 3, not _side_is_enemy
	)
	for _frame: int in _frames_in:
		_screen.advance_frame()
	return true


## Settles the intro, teaches both Pokemon the move, takes the turn and walks the
## event queue to the first animation on the requested side.
## A turn that cannot land, drawn to its end. The stages are the whole of the
## forcing: `.StatModifiers` multiplies the two together, so six down against six
## up leaves nothing on the dice.
func _drive_miss(battle: Gen2Battle) -> bool:
	battle.mon(Gen2Battle.ENEMY if not _side_is_enemy else Gen2Battle.PLAYER) \
		.change_stage("evasion", 6)
	battle.mon(Gen2Battle.PLAYER if not _side_is_enemy else Gen2Battle.ENEMY) \
		.change_stage("accuracy", -6)
	## A charge move spends its first turn going up, so the miss wanted is the
	## second one. Nothing else takes two.
	for _turn: int in 2:
		_screen.take_turn_with(0, 0)
		for _step: int in MAX_STEPS:
			if _screen.frames_running():
				# The same emptying `_drive` does: nothing is listening, and
				# `WaitSFX` would otherwise wait on real time.
				if _screen._audio_player != null:
					_screen._audio_player.stop_all()
				_screen.advance_frame()
				continue
			if _screen._pending.is_empty():
				break
			_screen.finish()
			_screen.advance()
		if not Gen2Substatus.has(
			battle.mon(Gen2Battle.ENEMY if _side_is_enemy else Gen2Battle.PLAYER).substatus,
			Gen2Substatus.FLYING | Gen2Substatus.UNDERGROUND
		):
			break
	for _frame: int in _frames_in:
		_screen.advance_frame()
	return true


func _drive() -> bool:
	if _move == 0:
		return _drive_entrance()
	if _move == CATCH_MOVE:
		return _drive_capture()
	_show_matchup()
	while _screen.intro_running():
		_screen.advance_frame()
	_settle_entrance()

	var battle: Gen2Battle = _screen._battle
	for side: int in [Gen2Battle.PLAYER, Gen2Battle.ENEMY]:
		var mon: Gen2BattleMon = battle.mon(side)
		mon.moves[0] = _move
		mon.pp[0] = 40
	if _miss:
		return _drive_miss(battle)
	_screen.take_turn_with(0, 0)

	for _step: int in MAX_STEPS:
		var snapshot: Dictionary = _screen.animation_snapshot()
		if bool(snapshot["running"]) \
				and bool(snapshot["enemy_turn"]) == _side_is_enemy:
			for _frame: int in _frames_in:
				_screen.advance_frame()
			_screen.finish()
			return true
		# `_PlayBattleAnim` ends on `WaitSFX`, which waits on real time while this
		# driver counts frames as fast as it can. Nothing is being listened to, so
		# the effect player is emptied rather than waited for.
		if _screen._audio_player != null:
			_screen._audio_player.stop_all()
		if _screen.frames_running():
			_screen.advance_frame()
			continue
		_screen.finish()
		_screen.advance()
	push_error("No animation on that side in %d steps. %s" % [MAX_STEPS, JSON.stringify(_screen.battle_snapshot())])
	return false
