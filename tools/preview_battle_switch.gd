extends SceneTree

## Captures the menus a battle is answered through, against a real imported cache:
## `BattleMenu`'s own four rows and the `MoveSelectionScreen` behind FIGHT,
## `OfferSwitch`'s yes/no box over the field, `AskUseNextPokemon`'s box in the same
## place, and the party list they open. The stages are [constant MENU_STAGES] and [constant WORLD_STAGES].
##   Godot --path . -s res://tools/preview_battle_switch.gd -- \
##       crystal /tmp/s.png [stage] [presses] [passes]

const WINDOW_SIZE := Vector2i(1152, 648)
## Enough frames for the scene to lay out and for the hardware viewport to hold
## what the menus were driven to; the intro and the turn are settled by hand
## below rather than by waiting. A shorter run photographs the composite as it
## was a few frames before the presses.
const SETTLE_FRAMES: int = 30

## The Pokemon `wContestMon` is holding for the `contest_replace` stage. A
## CATERPIE in the low levels, which is what a contest is full of.
## The wild the contest catch is made on, and the one already held.
const CONTEST_WILD_SPECIES: int = 13
const CONTEST_WILD_LEVEL: int = 12
const CONTEST_STOCK_SPECIES: int = 10
const CONTEST_STOCK_LEVEL: int = 9
const CONTEST_STOCK_MAX_HP: int = 27

## `BattlePack`'s rows for the `pack` stage: a potion, a Full Heal and an X
## Attack, which are one of each of `UseItem`'s three battle branches
## (constants/item_constants.asm).
const PACK_ITEMS: Array[int] = [0x12, 0x26, 0x31]
const PACK_QUANTITIES: Dictionary = {0x12: 3, 0x26: 1, 0x31: 2}

## The `balls` stage's rows: every ball `PokeBallEffect` has an effect for, which
## is the four ordinary ones plus the seven Kurt makes out of apricorns.
const BALL_QUANTITIES: Dictionary = {
	0x05: 12, 0x04: 5, 0x02: 3, 0x01: 1, 0x9D: 2, 0x9F: 2, 0xA0: 2,
	0xA1: 2, 0xA4: 2, 0xA5: 2, 0xA6: 2,
}

## Falkner, and three of the player's own, all at a level where nothing faints
## before the question is asked.
const TRAINER_CLASS: int = 1
const PLAYER_SPECIES: Array[int] = [155, 152, 158]
const PLAYER_LEVEL: int = 30
## Four moves on the lead, so `MoveSelectionScreen`'s list is a full one:
## TACKLE, GROWL, TAIL_WHIP and BITE (constants/move_constants.asm).
const LEAD_MOVES: Array[int] = [33, 45, 39, 44]
## The `info` stages' own four, one per effectiveness the annotation can mark
## against Pidgey's NORMAL/FLYING: THUNDERSHOCK is super effective, TACKLE
## neutral, VINE WHIP resisted and EARTHQUAKE has no effect at all.
const INFO_MOVES: Array[int] = [84, 33, 22, 89]

## The `shiny` and `normal` stages' wild: GYARADOS, whose ordinary blue and whose
## shiny red are the furthest apart of any pair the cartridge draws, and the one
## the game itself forces (`BATTLETYPE_FORCESHINY` at the Lake of Rage).
const SHINY_SPECIES: int = 130
const SHINY_LEVEL: int = 30
## The two stages that go through `start_world_battle` rather than a staged
## `_battle`, because the palette is chosen in `_init_battle_display` and only
## the world path runs it.
const WORLD_STAGES: Array[String] = ["shiny", "normal", "prize", "contest_replace"]

## The `prize` stage's held item, AMULET_COIN (constants/item_constants.asm).
## `CheckAmuletCoin` doubles the reward off it, so the figure in the picture is
## `.DoubleReward`'s rather than the plain one.
const AMULET_COIN: int = 0x5B

## The stages `BattleMenu`'s own first opening leads into with nothing staged
## behind it, rather than a question a turn has to reach.
const MENU_STAGES: Array[String] = [
	"menu", "move", "info", "info_pack", "info_pkmn", "contest", "pack", "balls",
]

var _screen: Gen2BattleScreen = null
var _output_path: String = ""
var _stage: String = "offer"
var _presses: PackedStringArray = PackedStringArray()
var _icon_passes: int = 0
var _frames: int = 0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("Usage: preview_battle_switch.gd -- <game> <output.png> [stage] [presses]")
		quit(1)
		return
	_output_path = args[1]
	if Gen2ToolPath.refuses(_output_path):
		quit(2)
		return
	_stage = args[2] if args.size() > 2 else "offer"
	if args.size() > 3:
		_presses = args[3].split(",", false)
	if args.size() > 4:
		_icon_passes = int(args[4])

	var data: GameData = GameData.open(StringName(args[0]))
	if data == null:
		push_error("No cache for %s. Import roms/%s.gbc first." % [args[0], args[0]])
		quit(1)
		return

	root.set_content_scale_size(WINDOW_SIZE)
	root.size = WINDOW_SIZE
	var packed: PackedScene = load("res://game/battle/battle_screen.tscn")
	_screen = packed.instantiate() as Gen2BattleScreen
	_screen.set_data(data)
	root.add_child(_screen)
	current_scene = _screen


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 3:
		_open()
	if _frames < SETTLE_FRAMES:
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
	var snapshot: Dictionary = _screen.battle_snapshot()
	print("Wrote %s, switch stage %s answering %s, menu stage %s at %d/%d" % [
		_output_path, snapshot["switch_stage"], snapshot["switch_reason"],
		snapshot["menu_stage"], snapshot["menu_position"], snapshot["move_cursor"],
	])
	quit(0)
	return true


## What a registered battle-information provider is, in the fewest lines that
## draw all three things one can put on the interface: a mark per move row, the
## stages that moved, and a tile the cartridge has no glyph for.
class Annotations extends RefCounted:
	## The two corners a battle leaves empty: above the enemy's picture, and the
	## cell in front of its panel. Where an annotation goes is the mod's own
	## business; these two are chosen so the capture reads.
	const STAGES_AT := Vector2i(13, 0)
	const WEATHER_AT := Vector2i(0, 5)
	## Eight bytes of 1bpp, one a row, bit 7 leftmost.
	const SUN_ROWS: Array[int] = [0x18, 0x3C, 0x7E, 0xFF, 0xFF, 0x7E, 0x3C, 0x18]
	## The three marks, as tiles rather than text: the interface font has no `+`
	## and its `▲` is a code the main font does not carry, so a symbol the
	## cartridge never printed is supplied here. Eight bytes of 1bpp, one a row,
	## bit 7 leftmost. A circle with a centre dot for super effective, a triangle
	## for resisted and an X for no effect at all.
	const MARK_SUPER: Array[int] = [0x3C, 0x42, 0x81, 0x99, 0x99, 0x81, 0x42, 0x3C]
	const MARK_RESISTED: Array[int] = [0x00, 0x10, 0x38, 0x38, 0x7C, 0x7C, 0xFE, 0x00]
	const MARK_IMMUNE: Array[int] = [0x00, 0x42, 0x24, 0x18, 0x18, 0x24, 0x42, 0x00]

	## The seven keys `Gen2BattleMon.stages` carries, said the way a player reads
	## them. The interface font has no `+`: the charmap's own arrows are what a
	## direction is written with, and a mod wanting a `+` supplies it as a tile.
	const STAGE_LABELS: Dictionary = {
		"attack": "ATK", "defense": "DEF", "speed": "SPD",
		"sp_attack": "SP.A", "sp_defense": "SP.D",
		"accuracy": "ACC", "evasion": "EVA",
	}

	func annotate_battle(snapshot: Dictionary) -> Array:
		var out: Array = []
		var neutral: int = int(snapshot.get("neutral", 10))
		if String(snapshot.get("menu_stage", "")) == "move" \
			and bool(snapshot.get("enemy_seen_before", false)):
			for index: int in (snapshot.get("move_rows", []) as Array).size():
				var row: Dictionary = (snapshot["move_rows"] as Array)[index]
				var against: int = int(row.get("effectiveness", neutral))
				if against == neutral:
					continue
				var mark: Array[int] = MARK_IMMUNE if against == 0 else (
					MARK_SUPER if against > neutral else MARK_RESISTED
				)
				## Where the host says the rows are, rather than where
				## `MoveSelectionScreen` happens to put them today.
				var at: Vector2i = (snapshot["move_rows_at"] as Vector2i) \
					+ (snapshot["move_rows_step"] as Vector2i) * index
				out.append({
					"tile": mark, "at": Vector2i(int(snapshot["move_rows_right"]), at.y),
				})
		var line: Vector2i = STAGES_AT
		for key: String in (snapshot.get("player_stages", {}) as Dictionary):
			var stage: int = int((snapshot["player_stages"] as Dictionary)[key])
			if stage == 0:
				continue
			out.append({
				"text": "%s%d" % [STAGE_LABELS.get(key, key.to_upper()), stage],
				"at": line,
			})
			line += Vector2i(0, 1)
		if Gen2Weather.is_active(int(snapshot.get("weather", 0))):
			out.append({"tile": SUN_ROWS, "at": WEATHER_AT})
		return out


## The trainer's second Pokémon coming in, which is what `OfferSwitch` asks
## about, or the player's own going down, which is what `AskUseNextPokemon` and
## `ForcePlayerMonChoice` follow. SHIFT is forced on rather than read out of the
## options file, since the question is the thing being photographed.
## Whether this stage stands the battle up in the state an information provider
## has something to say about. Registering a provider is a separate question:
## see [constant MENU_STAGES].
func _informing() -> bool:
	return _stage.begins_with("info")


func _open() -> void:
	if _stage == "prize":
		_open_prize()
		return
	if _stage == "contest_replace":
		_open_contest_replace()
		return
	if _stage in WORLD_STAGES:
		_open_world_stage()
		return
	_open_battle_stage()


## `GotMoneyForWinningText`, reached by winning the fight rather than staging it.
func _open_prize() -> void:
	## `.give_money` prints it behind `PrintWinLossText`, and the reward is
	## `ComputeTrainerReward`'s off the party the request built.
	_screen.start_world_battle({"values": {
		"kind": &"trainer", "trainer_group": TRAINER_CLASS, "trainer_id": 0,
	}})
	var fight: Gen2Battle = _screen.get("_battle")
	fight.player.item = AMULET_COIN
	_screen.set("_pending", fight.entrance_events(Gen2Battle.PLAYER))
	_drain_to_menu()
	## Each of Falkner's two is put on one hit point and knocked out by the
	## lead's first move. The switch offer his bench opens is declined, since
	## what is being photographed is the line behind the last faint.
	for _step: int in 400:
		_settle()
		var snapshot: Dictionary = _screen.battle_snapshot()
		if "for winning" in String(snapshot["message"]):
			## The box is still revealing on the frame it is spotted, and
			## the figure is the whole point of the picture.
			_read_question()
			_settle()
			return
		if String(snapshot["switch_stage"]) != "":
			_read_question()
			_screen._handle_button(Gen2Button.B)
			continue
		if String(snapshot["menu_stage"]) == "main" and not fight.is_over():
			fight.enemy.hp = 1
			_screen.set("_pending", fight.take_actions(
				Gen2Battle.use_move(0), Gen2Battle.use_move(0)
			))
		_screen.finish()
		_screen.advance()
	push_error("the prize line was never reached")


## A Park Ball thrown and caught while `wContestMon` already holds one, which is
## the only way to `DisplayAlreadyCaughtText` and the comparison behind it. A wild
## through the world's own path, since a capture needs one; the result is written
## rather than rolled, because what is photographed is the page and a real throw
## would have to be repeated until it stuck.
func _open_contest_replace() -> void:
	_screen.start_world_battle({"values": {
		"kind": &"wild", "pokemon": CONTEST_WILD_SPECIES,
		"level": CONTEST_WILD_LEVEL,
		"battle_type": Gen2Battle.BATTLETYPE_CONTEST,
	}})
	_screen.set_capture_balls(
		[Gen2WorldPartyHost.ITEM_PARK_BALL],
		{Gen2WorldPartyHost.ITEM_PARK_BALL: Gen2WorldBugContest.BALLS}
	)
	_drain_to_menu()
	_screen.begin_capture()
	_screen.select_capture_ball(0)
	_screen.throw_capture_ball()
	_screen.complete_capture({
		"ok": true, "contest": true, "caught": true, "wobbles": 3,
		"ball": Gen2WorldPartyHost.ITEM_PARK_BALL,
		"quantity": Gen2WorldBugContest.BALLS - 1,
		"replace_offer": true,
		"mon": Gen2WorldPartyHost.contest_mon_from(_screen.capture_target()),
		"stock_species": CONTEST_STOCK_SPECIES,
		"stock_level": CONTEST_STOCK_LEVEL,
		"stock_max_hp": CONTEST_STOCK_MAX_HP,
	})
	## The throw's animation, then the shake lines and
	## `DisplayAlreadyCaughtText`, each prompted past the way a player would.
	for _press: int in 20:
		_settle()
		if String(_screen.battle_snapshot()["switch_stage"]) == "contest_replace":
			break
		_screen.finish()
		_screen.advance()
	_read_question()
	_settle_icons()


## The wild the world starts, entered the way a step into the grass does:
## `BATTLETYPE_FORCESHINY` is what writes the shiny word, so the picture is the
## cartridge's own forced shiny rather than a number typed in here.
func _open_world_stage() -> void:
	var values: Dictionary = {
		"kind": &"wild", "pokemon": SHINY_SPECIES, "level": SHINY_LEVEL,
	}
	if _stage == "shiny":
		values["battle_type"] = Gen2Battle.BATTLETYPE_FORCESHINY
	else:
		## Named rather than rolled, so the two pictures differ in the four
		## numbers alone: an unnamed wild would roll and could be anything.
		values["dvs"] = Gen2BattleMon.PERFECT_DVS
	_screen.start_world_battle({"values": values})
	## Both sides in one picture: `CGB_BattleColors` reads `CheckShininess`
	## for the back pic as well, and the player's own party is the only place
	## a shiny back pic can come from. Written after the battle is built and
	## the display re-read, since the palette is chosen there.
	var started: Gen2Battle = _screen.get("_battle")
	if started != null:
		started.player.dvs = Gen2Stats.SHINY_DVS if _stage == "shiny" \
			else Gen2BattleMon.PERFECT_DVS
		_screen._init_battle_display()
	_drain_to_menu()
	## The second `_init_battle_display` leaves a shorter event queue behind
	## it, so the drain can land a press further in than it does without one.
	## Backed out rather than counted, so both stages photograph the same
	## screen and the two pictures differ in the palettes alone.
	for _press: int in 4:
		if String(_screen.battle_snapshot()["menu_stage"]) == "main":
			break
		_screen._handle_button(Gen2Button.B)
		_settle()


func _open_battle_stage() -> void:
	var data: GameData = _screen.get("_data")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var members: Array = []
	for species: int in PLAYER_SPECIES:
		var lead: Array[int] = INFO_MOVES if _informing() else LEAD_MOVES
		members.append(Gen2BattleMon.create(
			data, species, PLAYER_LEVEL,
			lead.duplicate() if members.is_empty() else [33]
		))
	var enemy: Gen2Party = Gen2TrainerParty.build(data, TRAINER_CLASS, 0)
	if enemy == null or enemy.size() < 2:
		push_error("Trainer class %d has no bench to switch from" % TRAINER_CLASS)
		quit(1)
		return

	## `AskUseNextPokemon` prints in a wild battle and returns at once in a
	## trainer one, which is the only thing separating the two faint stages.
	_screen.show_trainer(TRAINER_CLASS, 0, PLAYER_SPECIES[0], PLAYER_LEVEL)
	var battle: Gen2Battle = Gen2Battle.create_parties(
		data, Gen2Party.create(members), enemy, rng, _stage != "use_next"
	)
	battle.battle_style_set = false
	_screen.set("_battle", battle)
	if _stage in ["use_next", "replace"]:
		## Through the screen's own quarter, so the HUD in the picture is the HUD
		## the faint left rather than the one the intro drew, and then the
		## engine's own FAINTED event, which is what runs `MonFaintedAnimation`.
		for _quarter: int in 8:
			if battle.player.is_fainted():
				break
			_screen.hurt_player()
		_screen.set("_pending", [
			{"type": Gen2Battle.FAINTED, "side": Gen2Battle.PLAYER},
		])
	elif _stage == "level_up":
		## A real knockout, not a staged event: the lead is parked one point
		## under its next threshold so the award is certain to cross it, and the
		## turn it takes is the one that runs `GiveExperiencePoints`.
		battle.player.exp = Gen2Experience.total_exp_at(
			battle.player.growth_rate(), battle.player.level + 1
		) - 1
		battle.enemy.hp = 1
		_screen.set("_pending", battle.take_actions(
			Gen2Battle.use_move(0), Gen2Battle.use_move(0)
		))
	elif _stage not in MENU_STAGES:
		_screen.set("_pending", battle.take_actions(
			Gen2Battle.use_move(0), Gen2Battle.switch_to(1)
		))

	## `ContestBattleMenuHeader` in place of the ordinary one, which is
	## wBattleType alone. The balls are the contest's own count rather than the
	## bag's, exactly as the world screen hands them over.
	if _stage == "contest":
		battle.battle_type = Gen2Battle.BATTLETYPE_CONTEST
		_screen.set_capture_balls(
			[Gen2WorldPartyHost.ITEM_PARK_BALL],
			{Gen2WorldPartyHost.ITEM_PARK_BALL: Gen2WorldBugContest.BALLS}
		)

	if _stage == "level_up":
		_drain_to_level_up()
		_read_question()
		_screen.finish()
		_settle_icons()
		return

	## Both menu stages are what the intro leads into with nothing else staged,
	## which is `BattleMenu`'s own first opening.
	if _stage in MENU_STAGES:
		_open_menu_stage(battle)
		return

	_drain()
	if _stage == "pick":
		_read_question()
		_screen._handle_button(Gen2Button.A)
	for press: String in _presses:
		_screen._handle_button(_button(press))
	if _stage in ["offer", "use_next"]:
		_read_question()
	## A refusal is a line the box is still revealing, and the capture does not
	## wait on real time.
	_screen.finish()
	_settle_icons()


## `BattleMenu`'s own first opening, with nothing else staged.
func _open_menu_stage(battle: Gen2Battle) -> void:
	## The state an information provider reads, which is the stage rather
	## than the provider: a seen opponent, weather on, and two stages moved.
	## Only `info` registers this tool's own, so a capture of a mod's
	## annotations has exactly one provider answering and cannot attribute
	## one mod's placements to the other.
	if _informing():
		## What `SetSeenMon` would have left behind, since a first sighting is
		## not something the Pokedex could have told the player about.
		_screen.set("_enemy_seen_before", true)
		battle.weather = Gen2Weather.SUN
		battle.weather_turns = 3
		battle.player.stages["attack"] = 2
		battle.player.stages["speed"] = -1
	## The annotations are a mod's, over the move list they describe: the
	## provider is synthetic and everything it is handed, and everything drawn
	## from what it answers, is the host's.
	if _stage == "info":
		Gen2ModHost.instance().register_battle_info(&"preview", Annotations.new())
	_drain_to_menu()
	if _stage in ["move", "info"]:
		_screen._handle_button(Gen2Button.A)
	## `BattlePack`'s own list, over the bag the world hands the battle. The
	## rows are a real cache's items, so the picture reads as the pack.
	if _stage in ["pack", "info_pack"]:
		_screen.set_battle_pack(PACK_ITEMS, PACK_QUANTITIES)
		_screen._handle_button(Gen2Button.DOWN)
		_screen._handle_button(Gen2Button.A)
	## The BALL pocket of the same list. Every row of
	## `BallMultiplierFunctionTable` is reachable, so the picture is the
	## whole of what a player can throw.
	if _stage == "balls":
		_screen.set_battle_pack(
			Gen2WorldPartyHost.capture_ball_items(), BALL_QUANTITIES
		)
		_screen._handle_button(Gen2Button.DOWN)
		_screen._handle_button(Gen2Button.A)
	## `BattleMenu_PKMN`'s party page, the other modal that covers the same
	## cells: RIGHT from FIGHT is PKMN.
	if _stage == "info_pkmn":
		_screen._handle_button(Gen2Button.RIGHT)
		_screen._handle_button(Gen2Button.A)
	for press: String in _presses:
		_screen._handle_button(_button(press))
	_screen.finish()
	_settle_icons()

## The icons animate on their own clock, so the screen keeps stepping them
## across the frames this tool spends laying the scene out. Taking its
## processing away first is what makes the shot the pass that was asked for.
func _settle_icons() -> void:
	_screen.set_process(false)
	for _pass: int in _icon_passes:
		_screen.advance_party_icons()
	_screen._refresh_menu_layer()


## The same drain, stopping on the frame the level-up stats box is up.
func _drain_to_level_up() -> void:
	for _press: int in 60:
		## The box is popped by the bar pump inside `_settle`, not by the press
		## after it, so the check goes between the two: pressing on would scroll
		## the line being photographed away.
		_settle()
		if not Dictionary(_screen.battle_snapshot()["level_up_stats"]).is_empty():
			return
		_screen.finish()
		_screen.advance()


## The same drain, stopping at `BattleMenu` rather than at a switch question.
## `BattleMenu`'s own first opening. The menu is looked for after the frames the
## entrance owes have been spent and before the next press, not before both: the
## check used to stand in front of the whole iteration, so the press that opened
## the menu was followed by one more that chose FIGHT, and every stage below
## photographed a turn instead of the list it asked for.
func _drain_to_menu() -> void:
	for _press: int in 60:
		_settle()
		if String(_screen.battle_snapshot()["menu_stage"]) != "":
			return
		_screen.finish()
		_screen.advance()


## Every queued event shown and pressed past, which is what reaches the question.
func _drain() -> void:
	for _press: int in 60:
		if String(_screen.battle_snapshot()["switch_stage"]) != "":
			return
		_settle()
		_screen.finish()
		_screen.advance()


func _settle() -> void:
	var guard: int = 4000
	while _screen.frames_running() and guard > 0:
		_screen.advance_frame()
		guard -= 1


## Reads the question to its last page, which is where the yes/no box appears.
func _read_question() -> void:
	var box: Gen2TextBox = _screen.get("_box")
	while box != null and (box.is_revealing() or box.has_pages_left()):
		box.finish()
		if box.has_pages_left():
			box.advance()
	_screen._refresh_menu_layer()


func _button(name: String) -> int:
	match name.strip_edges().to_lower():
		"u": return Gen2Button.UP
		"d": return Gen2Button.DOWN
		"l": return Gen2Button.LEFT
		"r": return Gen2Button.RIGHT
		"b": return Gen2Button.B
		_: return Gen2Button.A
