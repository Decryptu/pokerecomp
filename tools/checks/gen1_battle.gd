extends RefCounted

## A Generation 1 fight, swept on Red, Blue and Yellow: the four moves every one
## of the 151 species is created knowing, all 165 moves used once each through
## the shared engine, `CriticalHitTest`'s chance over the whole base speed
## column, one wild battle fought to a faint, and the four routines Generation 1
## keeps where Crystal's command list does something else. The move sweep is what
## the effect translation is worth: an effect byte that lands on the wrong list
## either throws or stops producing events.

const SPECIES_COUNT: int = 151
const MOVE_COUNT: int = 165
const MOVE_SLOTS: int = 4

## The levels the created-knowing sweep asks at: the first, the one a starter is
## met at, and the three a learnset has usually run out by.
const SWEEP_LEVELS: Array[int] = [1, 5, 25, 50, 100]

## How many species know one, two, three and four moves at level 1: the base
## stats column with whatever `WriteMonMoves` finds at level 1 over it. Yellow
## rewrote 23 learnsets and moves three species along by one.
const STARTING_MOVE_CENSUS: Dictionary = {
	&"red": [32, 53, 40, 26], &"blue": [32, 53, 40, 26], &"yellow": [35, 54, 38, 24],
}

## Bulbasaur against Pidgey, both at a level where every move has something to
## work with, and the seed the fight is reproducible from.
const SWEEP_PLAYER: int = 1
const SWEEP_ENEMY: int = 16
const SWEEP_LEVEL: int = 50
const SWEEP_SEED: int = 20260930

## The wild fight: a level five starter against the level three Pidgey Route 1
## really offers, run to a faint. Pinned so a change to a damage rule shows up
## as a different number of turns.
const FIGHT_LEVELS: Array[int] = [5, 3]
const FIGHT_TURN_CAP: int = 64
const FIGHT_TURNS: int = 4

## `CriticalHitTest`, spot-checked where the shifts are interesting: no speed at
## all, a slow one, Persian's 115 already saturating a high-critical move, and
## the byte's own end. Each row is base speed, then the ordinary chance, the one
## under Focus Energy, and the one a high-critical move gets.
const CRITICAL_CHANCES: Array = [
	[0, 0, 0, 0],
	[40, 20, 5, 160],
	[115, 57, 14, 255],
	[255, 127, 31, 255],
]

var _r: RefCounted = null


func run(r: RefCounted) -> void:
	_r = r
	r.each_game_of(RomRegistry.GEN1, _one_game)


func _one_game() -> void:
	_created_knowing()
	_critical_chances()
	_every_move()
	_a_wild_fight()
	_haze_clears_more_than_stages()
	_a_trapping_move_holds_its_target()
	_the_trap_counter_distribution()
	_conversion_copies_the_target()
	_teleport_ends_the_battle()


## `AddPartyMon`'s four base moves and `WriteMonMoves` over them, for every
## species at five levels: never empty, never more than four, never a repeat and
## never a move the cartridge does not carry.
func _created_knowing() -> void:
	var census: Array[int] = [0, 0, 0, 0]
	for species: int in range(1, SPECIES_COUNT + 1):
		for level: int in SWEEP_LEVELS:
			var moves: Array = _r.data.moves_at_level(species, level)
			var name: String = String(_r.data.species(species).get("name", "?"))
			if not _r.check(
				not moves.is_empty() and moves.size() <= MOVE_SLOTS,
				"%s at level %d knows %d moves" % [name, level, moves.size()]
			):
				continue
			for move: int in moves:
				_r.check(move >= 1 and move <= MOVE_COUNT, "%s knows move %d" % [name, move])
			_r.check(_distinct(moves), "%s at level %d knows %s" % [name, level, str(moves)])
			if level == SWEEP_LEVELS[0]:
				census[moves.size() - 1] += 1
	_r.check(Array(census) == (STARTING_MOVE_CENSUS[_r.game_id] as Array),
		"the level one move census reads %s" % str(census))
	_r.note("gen1 battle %d species created knowing at %d levels" % [
		SPECIES_COUNT, SWEEP_LEVELS.size(),
	])


## The chance itself, and the whole base speed column read through it: nothing
## in the corpus reaches the cap on an ordinary move, and a high-critical move,
## worth eight times the shift, saturates from base speed 64 up.
func _critical_chances() -> void:
	for row: Array in CRITICAL_CHANCES:
		var speed: int = int(row[0])
		var read: Array = [
			speed,
			Gen2Damage.gen1_critical_chance(speed, false, false),
			Gen2Damage.gen1_critical_chance(speed, true, false),
			Gen2Damage.gen1_critical_chance(speed, false, true),
		]
		_r.check(read == row, "base speed %d reads %s, expected %s" % [
			speed, str(read), str(row)
		])

	var saturated: int = 0
	for species: int in range(1, SPECIES_COUNT + 1):
		var speed: int = int(
			(_r.data.species(species).get("stats", {}) as Dictionary).get("speed", 0)
		)
		var ordinary: int = Gen2Damage.gen1_critical_chance(speed, false, false)
		@warning_ignore("integer_division")
		_r.check(ordinary == speed / 2, "%d base speed gives %d in 256" % [speed, ordinary])
		if Gen2Damage.gen1_critical_chance(speed, false, true) == 0xFF:
			saturated += 1
	_r.note("gen1 battle %d species saturate a high-critical move" % saturated)


## Every move used once through the engine, which is what an effect byte read
## into the wrong list breaks: the turn either produces nothing or the command
## list asks for state the move never set.
func _every_move() -> void:
	var used: int = 0
	var damaged: int = 0
	for move: int in range(1, MOVE_COUNT + 1):
		var battle: Gen2Battle = _fight(SWEEP_LEVEL, SWEEP_LEVEL, [move], SWEEP_SEED + move)
		if not _r.check(battle != null, "no battle could be built for move %d" % move):
			return
		var before: int = battle.enemy.hp
		var events: Array = battle.take_turn(0, 0)
		var name: String = String(_r.data.move(move).get("name", "?"))
		if not _r.check(not events.is_empty(), "%s produced no events" % name):
			continue
		used += 1
		if battle.enemy.hp < before:
			damaged += 1
	_r.check(used == MOVE_COUNT, "%d of %d moves ran" % [used, MOVE_COUNT])
	_r.note("gen1 battle %d moves run, %d took HP off the target" % [used, damaged])


## One wild battle to a faint, both sides picking their first move every turn.
func _a_wild_fight() -> void:
	var battle: Gen2Battle = _fight(FIGHT_LEVELS[0], FIGHT_LEVELS[1], [], SWEEP_SEED)
	if not _r.check(battle != null, "no wild fight could be built"):
		return
	var turns: int = 0
	while turns < FIGHT_TURN_CAP:
		if battle.player.is_fainted() or battle.enemy.is_fainted():
			break
		battle.take_turn(0, 0)
		turns += 1
	_r.check(turns < FIGHT_TURN_CAP, "the wild fight did not end in %d turns" % FIGHT_TURN_CAP)
	_r.check(turns == FIGHT_TURNS, "the wild fight took %d turns, pinned %d" % [
		turns, FIGHT_TURNS,
	])
	_r.note("gen1 battle a wild %s went down in %d turns" % [
		_r.data.species(SWEEP_ENEMY).get("name", "?"), turns,
	])


## [param moves] empty takes whatever the level gives, which is what a wild
## encounter and a party member both carry.
func _fight(player_level: int, enemy_level: int, moves: Array, seed_value: int) -> Gen2Battle:
	var generator := RandomNumberGenerator.new()
	generator.seed = seed_value
	var player_moves: Array = moves if not moves.is_empty() \
		else _r.data.moves_at_level(SWEEP_PLAYER, player_level)
	return Gen2Battle.create(
		_r.data,
		Gen2BattleMon.create(_r.data, SWEEP_PLAYER, player_level, player_moves),
		Gen2BattleMon.create(
			_r.data, SWEEP_ENEMY, enemy_level,
			_r.data.moves_at_level(SWEEP_ENEMY, enemy_level)
		),
		generator
	)


static func _distinct(moves: Array) -> bool:
	var seen: Dictionary = {}
	for move: int in moves:
		if seen.has(move):
			return false
		seen[move] = true
	return true


## The moves that carry the four split effects, and the two types Pidgey has.
const HAZE_MOVE: int = 114
const WRAP_MOVE: int = 35
const CONVERSION_MOVE: int = 160
const TELEPORT_MOVE: int = 100
const ROAR_MOVE: int = 46
## `TYPE_NORMAL` and `TYPE_FLYING` as `type_constants.asm` numbers them.
const PIDGEY_TYPES: Array[int] = [0, 2]

## How many Wraps to roll for the counter census, and what `TrappingEffect`'s
## two-bit draw with its reroll is worth over them: one and two continuations
## 3/8 each, three and four 1/8 each. Compared as shares rather than counts.
const TRAP_TURN_CAP: int = 8
const TRAP_ROLLS: int = 4000
const TRAP_SHARES: Array[float] = [0.375, 0.375, 0.125, 0.125]
const TRAP_TOLERANCE: float = 0.025


## `HazeEffect_`: both sides' stages, both sides' volatile statuses and both
## screens, and the target's own status byte with them. Crystal's
## `EFFECT_RESET_STATS` clears the stages and nothing else.
func _haze_clears_more_than_stages() -> void:
	var battle: Gen2Battle = _fight(SWEEP_LEVEL, SWEEP_LEVEL, [HAZE_MOVE], SWEEP_SEED)
	if not _r.check(battle != null, "no battle could be built for HAZE"):
		return
	battle.player.change_stage("attack", 2)
	battle.enemy.change_stage("defense", -2)
	battle.enemy.status = Gen2Status.PARALYSIS
	battle.enemy.substatus |= Gen2Substatus.LEECH_SEED | Gen2Substatus.FOCUS_ENERGY
	battle.player.substatus |= Gen2Substatus.MIST
	battle.screens[Gen2Battle.PLAYER] = Gen2Screens.LIGHT_SCREEN
	battle.take_turn(0, 0)
	_r.check(battle.player.stage("attack") == 0, "HAZE left the user a stage")
	_r.check(battle.enemy.stage("defense") == 0, "HAZE left the target a stage")
	_r.check(battle.enemy.status == Gen2Status.NONE, "HAZE left the target paralysed")
	_r.check(
		battle.enemy.substatus & (Gen2Substatus.LEECH_SEED | Gen2Substatus.FOCUS_ENERGY) == 0,
		"HAZE left the target seeded or pumped"
	)
	_r.check(
		battle.player.substatus & Gen2Substatus.MIST == 0, "HAZE left the user misted"
	)
	_r.check(
		battle.screens[Gen2Battle.PLAYER] == Gen2Screens.NONE, "HAZE left a screen up"
	)


## `TrappingEffect` and `.HeldInPlaceCheck`: the user repeats the move for the
## rolled number of turns, the target never acts, and every continuation deals
## the first hit's damage over again. `MoveHitTest.moveMissed` clears the flag,
## so the run walks until a Wrap actually binds.
func _a_trapping_move_holds_its_target() -> void:
	var battle: Gen2Battle = _fight(SWEEP_LEVEL, SWEEP_LEVEL, [WRAP_MOVE], SWEEP_SEED)
	if not _r.check(battle != null, "no battle could be built for WRAP"):
		return
	var bound: int = 0
	var first: int = 0
	for _turn: int in TRAP_TURN_CAP:
		if battle.enemy.is_fainted() or battle.player.is_fainted():
			break
		var before: int = battle.enemy.hp
		battle.take_turn(0, 0)
		if battle.enemy.trapping_move == 0:
			continue
		bound = battle.enemy.trapped_turns
		first = before - battle.enemy.hp
		break
	if not _r.check(bound > 0 and first > 0, "no WRAP bound its target"):
		return

	var held: int = 0
	for _turn: int in bound:
		var before: int = battle.enemy.hp
		var events: Array = battle.take_turn(0, 0)
		_r.check(before - battle.enemy.hp == first, "a continuation dealt %d, not %d" % [
			before - battle.enemy.hp, first,
		])
		for event: Dictionary in events:
			if StringName(event.get("type", &"")) == Gen2Battle.CANNOT_MOVE \
				and StringName(event.get("reason", &"")) == &"held_in_place":
				held += 1
	_r.check(held == bound, "%d turns held over %d continuations" % [held, bound])
	_r.check(battle.enemy.trapping_move == 0, "CheckNumAttacksLeft never let go")
	_r.note("gen1 battle WRAP held its target for %d turns at %d HP" % [bound, first])


## The two-bit roll with its reroll, over enough Wraps for the shares to settle.
func _the_trap_counter_distribution() -> void:
	var census: Array[int] = [0, 0, 0, 0]
	var generator := RandomNumberGenerator.new()
	generator.seed = SWEEP_SEED
	for _roll: int in TRAP_ROLLS:
		var turns: int = Gen2Substatus.roll_gen1_trap_turns(generator)
		if not _r.check(turns >= 1 and turns <= 4, "a trap rolled %d turns" % turns):
			return
		census[turns - 1] += 1
	for index: int in census.size():
		var share: float = float(census[index]) / float(TRAP_ROLLS)
		_r.check(
			absf(share - TRAP_SHARES[index]) < TRAP_TOLERANCE,
			"%d continuations came up %.3f, expected %.3f" % [
				index + 1, share, TRAP_SHARES[index],
			]
		)
	_r.note("gen1 battle %d trap rolls read %s" % [TRAP_ROLLS, str(census)])


## `ConversionEffect_`: both of the target's types onto the user, where Crystal's
## own Conversion samples the user's own moves for one.
func _conversion_copies_the_target() -> void:
	var battle: Gen2Battle = _fight(
		SWEEP_LEVEL, SWEEP_LEVEL, [CONVERSION_MOVE], SWEEP_SEED
	)
	if not _r.check(battle != null, "no battle could be built for CONVERSION"):
		return
	battle.take_turn(0, 0)
	_r.check(
		battle.player.types() == Array(PIDGEY_TYPES),
		"CONVERSION left the user on %s" % str(battle.player.types())
	)


## `SwitchAndTeleportEffect`: one routine for three moves. A wild battle ends
## whenever the user is at least the target's level, and a trainer battle refuses
## all three outright.
func _teleport_ends_the_battle() -> void:
	for move: int in [TELEPORT_MOVE, ROAR_MOVE]:
		var battle: Gen2Battle = _fight(SWEEP_LEVEL, SWEEP_LEVEL, [move], SWEEP_SEED)
		if not _r.check(battle != null, "no battle could be built for move %d" % move):
			return
		battle.take_turn(0, 0)
		_r.check(battle.is_over(), "move %d did not end the wild battle" % move)

		var trainer: Gen2Battle = _fight(SWEEP_LEVEL, SWEEP_LEVEL, [move], SWEEP_SEED)
		trainer.is_trainer_battle = true
		var events: Array = trainer.take_turn(0, 0)
		_r.check(not trainer.is_over(), "move %d ended a trainer battle" % move)
		var failed: bool = false
		for event: Dictionary in events:
			failed = failed or StringName(event.get("type", &"")) == Gen2Battle.MOVE_FAILED
		_r.check(failed, "move %d said nothing against a trainer" % move)
