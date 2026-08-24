extends SceneTree

## Captures the menus a battle is answered through, against a real imported
## cache: `BattleMenu`'s own FIGHT/PKMN/PACK/RUN and the `MoveSelectionScreen`
## behind FIGHT, `OfferSwitch`'s yes/no box over the field,
## `AskUseNextPokemon`'s box in the same place, and the party list they open.
##
##   Godot --path . -s res://tools/preview_battle_switch.gd -- crystal /tmp/s.png [stage] [presses] [passes]
##
## [stage] is one of `offer` (the default), `menu`, `move`, `info` (the move
## list with a registered battle-information provider's annotations over it:
## a mark per row for the effectiveness against the defender, the non-zero stat
## stages, and a tile of the provider's own for the weather), `info_pack` and
## `info_pkmn` (the same battle state, with the modal that covers the
## annotations open and no provider of this tool's own registered, so a mod
## under test is the only thing answering), `contest`, `pack`,
## `pick`, `use_next`, `replace` and `level_up`, which is the stats box
## `.skip_exp_bar_animation` draws beside its grew-to-level line;
## [presses] is a `u,d,l,r,a,b` list driven into the menu before the shot, so a
## cursor row or a refusal can be photographed; [passes] is how many sprite
## passes the party page's icons are given, which is what moves the chosen row's
## icon off its resting offset. The screen's own processing is taken away before
## those are spent, so the same arguments photograph the same frame. The battle is a real trainer's
## party out of the cache with the player on a bench of three, since both a
## switch and a replacement need somebody to send.
##
## The two faint stages take the player's Pokémon down rather than fighting it
## down: what is being photographed is the question a faint leads to, and a real
## turn would have to be repeated until a move happened to land.

const WINDOW_SIZE := Vector2i(1152, 648)
## Enough frames for the scene to lay out and for the hardware viewport to hold
## what the menus were driven to; the intro and the turn are settled by hand
## below rather than by waiting. A shorter run photographs the composite as it
## was a few frames before the presses.
const SETTLE_FRAMES: int = 30

## `BattlePack`'s rows for the `pack` stage: a potion, a Full Heal and an X
## Attack, which are one of each of `UseItem`'s three battle branches
## (constants/item_constants.asm).
const PACK_ITEMS: Array[int] = [0x12, 0x26, 0x31]
const PACK_QUANTITIES: Dictionary = {0x12: 3, 0x26: 1, 0x31: 2}

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

## The stages `BattleMenu`'s own first opening leads into with nothing staged
## behind it, rather than a question a turn has to reach.
const MENU_STAGES: Array[String] = [
	"menu", "move", "info", "info_pack", "info_pkmn", "contest", "pack",
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

	RenderingServer.force_draw()
	var image: Image = root.get_texture().get_image()
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
		## `BattleMenu_PKMN`'s party page, the other modal that covers the same
		## cells: RIGHT from FIGHT is PKMN.
		if _stage == "info_pkmn":
			_screen._handle_button(Gen2Button.RIGHT)
			_screen._handle_button(Gen2Button.A)
		for press: String in _presses:
			_screen._handle_button(_button(press))
		_screen.finish()
		_settle_icons()
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
