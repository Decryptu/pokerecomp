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
	_the_bag_in_a_fight()
	_a_safari_battle()
	_the_tutor_throws()


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
## The Pidgey's own Whirlwind outspeeds a Bulbasaur and ends a wild battle, so
## a routine drill hands [param enemy_moves] SPLASH.
func _fight(
	player_level: int, enemy_level: int, moves: Array, seed_value: int,
	enemy_moves: Array = []
) -> Gen2Battle:
	var generator := RandomNumberGenerator.new()
	generator.seed = seed_value
	var player_moves: Array = moves if not moves.is_empty() \
		else _r.data.moves_at_level(SWEEP_PLAYER, player_level)
	return Gen2Battle.create(
		_r.data,
		Gen2BattleMon.create(_r.data, SWEEP_PLAYER, player_level, player_moves),
		Gen2BattleMon.create(
			_r.data, SWEEP_ENEMY, enemy_level,
			enemy_moves if not enemy_moves.is_empty()
			else _r.data.moves_at_level(SWEEP_ENEMY, enemy_level)
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
const SPLASH_MOVE: int = 150
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
	var battle: Gen2Battle = _fight(SWEEP_LEVEL, SWEEP_LEVEL, [HAZE_MOVE], SWEEP_SEED, [SPLASH_MOVE])
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
	var battle: Gen2Battle = _fight(SWEEP_LEVEL, SWEEP_LEVEL, [WRAP_MOVE], SWEEP_SEED, [SPLASH_MOVE])
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
		SWEEP_LEVEL, SWEEP_LEVEL, [CONVERSION_MOVE], SWEEP_SEED, [SPLASH_MOVE]
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
		var battle: Gen2Battle = _fight(SWEEP_LEVEL, SWEEP_LEVEL, [move], SWEEP_SEED, [SPLASH_MOVE])
		if not _r.check(battle != null, "no battle could be built for move %d" % move):
			return
		battle.take_turn(0, 0)
		_r.check(battle.is_over(), "move %d did not end the wild battle" % move)

		var trainer: Gen2Battle = _fight(SWEEP_LEVEL, SWEEP_LEVEL, [move], SWEEP_SEED, [SPLASH_MOVE])
		trainer.is_trainer_battle = true
		var events: Array = trainer.take_turn(0, 0)
		_r.check(not trainer.is_over(), "move %d ended a trainer battle" % move)
		var failed: bool = false
		for event: Dictionary in events:
			failed = failed or StringName(event.get("type", &"")) == Gen2Battle.MOVE_FAILED
		_r.check(failed, "move %d said nothing against a trainer" % move)


## `UseItem` from `DisplayPlayerBag`'s own list, at the cartridge's item numbers:
## a heal, a status cure, a revive, the two kinds of X item, the doll, the flute,
## and a row `ItemUsePtrTable` refuses inside a battle.
const BAG_POTION: int = 0x14
const BAG_ANTIDOTE: int = 0x0B
const BAG_REVIVE: int = 0x35
const BAG_X_ATTACK: int = 0x41
const BAG_X_SPECIAL: int = 0x44
const BAG_DIRE_HIT: int = 0x3A
const BAG_POKE_DOLL: int = 0x33
const BAG_POKE_FLUTE: int = 0x49
const BAG_TOWN_MAP: int = 0x05


func _the_bag_in_a_fight() -> void:
	var battle: Gen2Battle = _bag_battle()
	var member: Gen2BattleMon = battle.party(Gen2Battle.PLAYER).at(1)
	member.hp = 1
	member.status = Gen2Status.POISON
	_bag_check(battle.use_bag_item(BAG_POTION, 1), "POTION")
	_r.check(member.hp == 21, "a POTION left %d HP, not 21" % member.hp)
	_bag_check(battle.use_bag_item(BAG_ANTIDOTE, 1), "ANTIDOTE")
	_r.check(member.status == Gen2Status.NONE, "an ANTIDOTE left status %d" % member.status)
	member.hp = 0
	_bag_check(battle.use_bag_item(BAG_REVIVE, 1), "REVIVE")
	_r.check(member.hp > 0, "a REVIVE left the member fainted")

	var out: Gen2BattleMon = battle.mon(Gen2Battle.PLAYER)
	_bag_check(battle.use_bag_item(BAG_X_ATTACK), "X ATTACK")
	_r.check(out.stage("attack") == 1, "X ATTACK left attack at %d" % out.stage("attack"))
	## One stage byte for the one Special stat, which is what the twin carries.
	_bag_check(battle.use_bag_item(BAG_X_SPECIAL), "X SPECIAL")
	_r.check(
		out.stage("sp_attack") == 1 and out.stage("sp_defense") == 1,
		"X SPECIAL left %d and %d" % [out.stage("sp_attack"), out.stage("sp_defense")]
	)
	_bag_check(battle.use_bag_item(BAG_DIRE_HIT), "DIRE HIT")
	_r.check(
		Gen2Substatus.has(out.substatus, Gen2Substatus.FOCUS_ENERGY),
		"DIRE HIT set no focus energy"
	)
	_r.check(
		StringName(battle.use_bag_item(BAG_TOWN_MAP).get("reason", &"")) \
			== &"item_not_usable_here",
		"a TOWN MAP is not refused with ItemUseNotTime"
	)

	out.status = Gen2Status.SLEEP_MASK
	battle.party(Gen2Battle.PLAYER).at(1).status = Gen2Status.SLEEP_MASK
	var flute: Dictionary = battle.use_bag_item(BAG_POKE_FLUTE)
	_bag_check(flute, "POKE FLUTE")
	_r.check(int(flute.get("woken", 0)) == 2, "the flute woke %d" % int(flute.get("woken", 0)))
	_r.check(not bool(flute.get("spent", true)), "the flute was spent")
	_the_wild_sleeps_alone()

	_r.check(
		StringName(_bag_battle(true).use_bag_item(BAG_POKE_DOLL).get("reason", &"")) \
			== &"item_has_no_effect",
		"a POKE DOLL is not refused in a trainer battle"
	)
	var wild: Gen2Battle = _bag_battle()
	_bag_check(wild.use_bag_item(BAG_POKE_DOLL), "POKE DOLL")
	_r.check(wild.is_over(), "a POKE DOLL did not end the wild battle")
	_r.note("gen1 battle bag: 10 rows used, refused or spent as the table says")


## `wWereAnyMonsAsleep` against a wild that is the only sleeper, which is what
## [method Gen1Layout.flute_counts_wild] parts.
func _the_wild_sleeps_alone() -> void:
	var battle: Gen2Battle = _bag_battle()
	battle.mon(Gen2Battle.ENEMY).status = Gen2Status.SLEEP_MASK
	var flute: Dictionary = battle.use_bag_item(BAG_POKE_FLUTE)
	_bag_check(flute, "POKE FLUTE")
	var counted: int = 1 if _r.game_id == RomRegistry.YELLOW else 0
	_r.check(int(flute.get("woken", 0)) == counted,
		"a sleeping wild counted %d, wanted %d" % [int(flute.get("woken", 0)), counted])
	_r.check(
		not Gen2Status.is_asleep(battle.mon(Gen2Battle.ENEMY).status),
		"the flute left the wild asleep"
	)


func _bag_check(result: Dictionary, name: String) -> void:
	_r.check(bool(result.get("ok", false)), "%s was refused: %s" % [
		name, String(result.get("reason", &""))
	])


## Two party members so a benched row can be healed, revived and woken.
func _bag_battle(trainer: bool = false) -> Gen2Battle:
	var generator := RandomNumberGenerator.new()
	generator.seed = SWEEP_SEED
	return Gen2Battle.create_parties(
		_r.data,
		Gen2Party.create([
			Gen2BattleMon.create(
				_r.data, SWEEP_PLAYER, SWEEP_LEVEL,
				_r.data.moves_at_level(SWEEP_PLAYER, SWEEP_LEVEL)
			),
			Gen2BattleMon.create(
				_r.data, SWEEP_ENEMY, SWEEP_LEVEL,
				_r.data.moves_at_level(SWEEP_ENEMY, SWEEP_LEVEL)
			),
		]),
		Gen2Party.of(Gen2BattleMon.create(
			_r.data, SWEEP_ENEMY, SWEEP_LEVEL,
			_r.data.moves_at_level(SWEEP_ENEMY, SWEEP_LEVEL)
		)),
		generator, trainer
	)


## `BaitRockCommon`'s `.randomLoop`: a factor grows by 1 to 5, in even shares.
const SAFARI_ROLLS: int = 4000
const SAFARI_FACTOR_SHARE: float = 0.2
const SAFARI_TOLERANCE: float = 0.03
## `.compareWithRandomValue`: a low Speed byte at or above 128 carries out of the
## doubling and takes the enemy away with no roll.
const SAFARI_SLOW_SPEED: int = 20
const SAFARI_FAST_SPEED: int = 200


## A Safari battle's whole turn: `ItemUseBait` halves the catch rate where
## `ItemUseRock` doubles it, `PrintSafariZoneBattleText` counts the factor the
## last action raised, and `.notOutOfSafariBalls` may roll the enemy away.
func _a_safari_battle() -> void:
	var battle: Gen2Battle = _fight(SWEEP_LEVEL, SWEEP_LEVEL, [], SWEEP_SEED)
	if not _r.check(battle != null, "no battle could be built for the Safari game"):
		return
	var rate: int = int(_r.data.species(SWEEP_ENEMY).get("catch_rate", 0))
	battle.battle_type = Gen2Battle.BATTLETYPE_SAFARI
	battle.safari_catch_rate = rate
	var rolls: Callable = Callable(battle.rng, "randi_range").bind(0, 0xFF)
	battle.throw_bait_or_rock(true, rolls)
	@warning_ignore("integer_division")
	var halved: int = rate / 2
	_r.check(battle.safari_catch_rate == halved and battle.safari_escape_factor == 0,
		"bait left the catch rate at %d, wanted %d." % [battle.safari_catch_rate, halved])
	battle.throw_bait_or_rock(false, rolls)
	_r.check(battle.safari_catch_rate == mini(halved * 2, 0xFF)
		and battle.safari_bait_factor == 0,
		"a rock left the catch rate at %d." % battle.safari_catch_rate)

	## `.no_bait` reads the escape counter only once the bait one is spent.
	battle.safari_bait_factor = 1
	battle.safari_escape_factor = 1
	_r.check(battle.safari_battle_text(rate) == Gen2Battle.SAFARI_EATING_TEXT
		and battle.safari_bait_factor == 0, "the bait counter said the wrong box.")
	_r.check(battle.safari_battle_text(rate) == Gen2Battle.SAFARI_ANGRY_TEXT
		and battle.safari_catch_rate == rate,
		"the escape counter left the catch rate at %d." % battle.safari_catch_rate)
	_r.check(battle.safari_battle_text(rate).is_empty(),
		"a spent pair of counters still said something.")
	_safari_factor_distribution()
	_safari_run_roll()
	_r.note("gen1 battle the Safari game's bait, rock and %d run rolls" % SAFARI_ROLLS)


func _safari_factor_distribution() -> void:
	var battle: Gen2Battle = _fight(SWEEP_LEVEL, SWEEP_LEVEL, [], SWEEP_SEED)
	if battle == null:
		return
	var rolls: Callable = Callable(battle.rng, "randi_range").bind(0, 0xFF)
	var counts: Array[int] = [0, 0, 0, 0, 0]
	for _roll: int in SAFARI_ROLLS:
		battle.safari_bait_factor = 0
		battle.throw_bait_or_rock(true, rolls)
		var grown: int = battle.safari_bait_factor
		if not _r.check(grown >= 1 and grown <= Gen1Layout.SAFARI_FACTOR_LIMIT,
			"a bait raised the factor by %d." % grown):
			return
		counts[grown - 1] += 1
	for grown: int in counts.size():
		var share: float = float(counts[grown]) / SAFARI_ROLLS
		_r.check(absf(share - SAFARI_FACTOR_SHARE) <= SAFARI_TOLERANCE,
			"a factor of %d came up %.3f of the time." % [grown + 1, share])


func _safari_run_roll() -> void:
	var battle: Gen2Battle = _fight(SWEEP_LEVEL, SWEEP_LEVEL, [], SWEEP_SEED)
	if battle == null:
		return
	var enemy: Gen2BattleMon = battle.mon(Gen2Battle.ENEMY)
	var rolls: Callable = Callable(battle.rng, "randi_range").bind(0, 0xFF)
	enemy.stats["speed"] = SAFARI_FAST_SPEED
	_r.check(battle.safari_enemy_runs(rolls), "a fast wild stayed with no roll.")
	enemy.stats["speed"] = SAFARI_SLOW_SPEED
	var ran: Array[int] = [0, 0, 0]
	for index: int in ran.size():
		battle.safari_bait_factor = 1 if index == 1 else 0
		battle.safari_escape_factor = 1 if index == 2 else 0
		for _roll: int in SAFARI_ROLLS:
			if battle.safari_enemy_runs(rolls):
				ran[index] += 1
	_r.check(ran[1] < ran[0] and ran[0] < ran[2],
		"the run rolls came out %s eating, plain and angry." % [ran])


## The tutor on the real overlay, frame by frame, from the map script that
## starts him: Viridian City's catch training, Yellow's initial one that
## `ItemUseBall` refuses, and Prof. Oak's PIKACHU with no party at all. A row is
## the state to start on, the one left behind, the wild, and whether the ball lands.
const TUTOR_ROWS: Dictionary = {
	&"red": [[1, 2, 13, true]], &"blue": [[1, 2, 13, true]],
	&"yellow": [[3, 4, 19, true], [7, 8, 19, false]],
}
const TUTOR_GUARD_FRAMES: int = 6000
const VIRIDIAN_CITY: int = 1
const VIRIDIAN_BYTE: int = 4
const PALLET_TOWN: int = 0
const TUTOR_CELL := Vector2i(23, 10)
const PIKACHU_DEX: int = 25
## `_ItemUseText001`, `text_low`, `_ItemUseText002`; `_ItemUseBallText05`'s
## `line` and `cont`; and `_ItemUseBallText04`.
const TUTOR_USED: String = "%s used\nPOKé BALL!"
const TUTOR_CAUGHT: String = "All right!\n%s was" + Gen2TextStream.SCROLL_BREAK + "caught!"
const TUTOR_BROKE_FREE: String = "Shoot! It was so\nclose too!"


func _the_tutor_throws() -> void:
	for row: Array in TUTOR_ROWS[_r.game_id] as Array:
		var screen: Gen2WorldScreen = _open_screen(VIRIDIAN_CITY, TUTOR_CELL, true)
		var world: Gen2WorldAPI = screen.world()
		var party_before: int = screen.active_save().party.size()
		var balls_before: int = world.state.item_quantity(Gen1Layout.ITEM_POKE_BALL)
		world.state.set_gen1_map_script(VIRIDIAN_BYTE, int(row[0]))
		screen._show_script_results(world.dispatch_sight_events())
		var training: Dictionary = _drive_tutor(screen)
		var name: String = String(_r.data.species(int(row[2])).get("name", ""))
		_r.check(training["frames"] < TUTOR_GUARD_FRAMES, "the old man's battle never ended: %s" % [training])
		_r.check((training["messages"] as Array).has(TUTOR_USED % "OLD MAN"), "the old man threw nothing: %s" % [training])
		var landed: String = TUTOR_CAUGHT % name if bool(row[3]) else TUTOR_BROKE_FREE
		_r.check((training["messages"] as Array).has(landed), "the old man's %s ball said %s" % [name, training])
		_r.check(world.state.gen1_map_script(VIRIDIAN_BYTE) == int(row[1]),
			"the training left Viridian City on state %d." % world.state.gen1_map_script(VIRIDIAN_BYTE))
		_r.check(screen.active_save().party.size() == party_before
			and world.state.item_quantity(Gen1Layout.ITEM_POKE_BALL) == balls_before,
			"the old man's catch was kept.")
		_r.note("gen1 tutor: the old man's %s in %d frames, %s" % [
			name, training["frames"], "caught" if bool(row[3]) else "broke free"])
		_close_screen(screen)
	if not Gen1Layout.TUTOR_WILDS[_r.game_id].has(Gen1Layout.BATTLE_TYPE_PIKACHU):
		return
	var lab: Gen2WorldScreen = _open_screen(PALLET_TOWN, TUTOR_CELL, false)
	lab.preview_catch_tutorial(true)
	var oak: Dictionary = _drive_tutor(lab)
	var pikachu: String = String(_r.data.species(PIKACHU_DEX).get("name", ""))
	_r.check(oak["frames"] < TUTOR_GUARD_FRAMES, "Prof. Oak's battle never ended: %s" % [oak])
	_r.check((oak["messages"] as Array).has(TUTOR_USED % "PROF.OAK")
		and (oak["messages"] as Array).has(TUTOR_CAUGHT % pikachu), "Prof. Oak's throw said %s" % [oak])
	_r.check(lab.active_save().party.is_empty(), "Prof. Oak's PIKACHU joined the party.")
	_r.note("gen1 tutor: Prof. Oak's %s in %d frames" % [pikachu, oak["frames"]])
	_close_screen(lab)


func _open_screen(map: int, cell: Vector2i, party: bool) -> Gen2WorldScreen:
	var screen: Gen2WorldScreen = (load("res://game/world/world_screen.tscn") as PackedScene).instantiate()
	screen.map_group = 0
	screen.map_number = map
	screen.start_cell = cell
	screen.encounter_seed = 1
	screen.set_data(_r.data)
	var save: Gen2SaveData = Gen2SaveStore.create_development_save(_r.data, 0)
	if not party:
		save.party = []
	screen.set_save(save)
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.set_process(false)
	return screen


func _close_screen(screen: Gen2WorldScreen) -> void:
	(Engine.get_main_loop() as SceneTree).root.remove_child(screen)
	screen.free()


func _drive_tutor(screen: Gen2WorldScreen) -> Dictionary:
	var messages: Array[String] = []
	var frames: int = 0
	var host: Gen2BattleScreen = null
	while frames < TUTOR_GUARD_FRAMES:
		frames += 1
		screen.advance_frame()
		var current: Gen2BattleScreen = screen.get("_battle_host")
		if host == null:
			host = current
			continue
		if current == null:
			break
		var snapshot: Dictionary = host.battle_snapshot()
		var line: String = String(snapshot.get("message", ""))
		if messages.is_empty() or messages.back() != line:
			messages.append(line)
		if bool(snapshot.get("awaits_press", false)):
			screen.press_button(PokeButton.A)
	return {"frames": frames, "messages": messages}
