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

## `PlayerCalcMoveDamage`'s four routines, against what the cartridges
## themselves answered: the oracle's `battle/gen1_damage.py` runs them on a
## real dump and prints `wDamage` and `wMoveMissed` per case, and
## [method _damage_oracle_sweep] prints the same 5,972 lines. `rand` is what
## `Random` answers, which `RandomizeDamage` rotates right before it compares.
const DAMAGE_ORACLE_HEAD: String = "power type effect level attack defense " \
	+ "party_attack party_defense screens critical atk_types def_types rand -> damage missed"
const DAMAGE_ORACLE_DIGEST: String = "b7a2ca24ee9c82d4c6e4f0a6948d9f4704d34189"
const DAMAGE_ATTACKS: Array[int] = [1, 50, 130, 255, 256, 300, 600, 999]
const DAMAGE_DEFENSES: Array[int] = [1, 30, 100, 255, 256, 400, 999]
const DAMAGE_POWERS: Array[int] = [40, 90, 250]
const DAMAGE_LEVELS: Array[int] = [5, 50, 100]
const DAMAGE_RANDS: Array[int] = [217, 255]
const DAMAGE_LIGHT_SCREEN: int = 1 << 1
const DAMAGE_REFLECT: int = 1 << 2
const DAMAGE_EXPLODE_EFFECT: int = 0x07
const DAMAGE_TYPES: Array[int] = [
	0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x07, 0x08,
	0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1A,
]
const DAMAGE_PAIRS: Array = [
	[0x00, 0x02], [0x01, 0x03], [0x03, 0x04], [0x05, 0x04], [0x07, 0x16],
	[0x07, 0x03], [0x08, 0x03], [0x15, 0x19], [0x15, 0x02], [0x16, 0x03],
	[0x17, 0x02], [0x05, 0x15], [0x19, 0x18], [0x1A, 0x02], [0x14, 0x02],
	[0x04, 0x05], [0x18, 0x15],
]
const DAMAGE_TYPE_STATS: Array = [[10, 250, 10], [120, 60, 120]]
const DAMAGE_PSYCHIC: int = 0x18
const DAMAGE_DRAGON: int = 0x1A

## `CalculateModifiedStats`, `ApplyBurnAndParalysisPenaltiesToPlayer` and
## `ApplyBadgeStatBoosts` in a row, then the boosts once more, against the
## oracle's `battle/gen1_stats.py` and its 612 lines from the cartridges.
const STATS_ORACLE_HEAD: String = "atk def spd spc mods status badges -> atk def spd spc | boosted again"
const STATS_ORACLE_DIGEST: String = "f59fbb99feef06220731c1818ba62369dc81b589"
const STATS_ORACLE_ROWS: Array = [
	[1, 1, 1, 1], [7, 9, 11, 13], [100, 100, 100, 100], [255, 256, 511, 512],
	[700, 800, 900, 999], [888, 889, 890, 891],
]
const STATS_ORACLE_STAGED_ROWS: Array = [
	[100, 100, 100, 100], [255, 256, 511, 512], [700, 800, 900, 999],
]
const STATS_ORACLE_STATUSES: Array[int] = [0, Gen2Status.PARALYSIS, Gen2Status.BURN]
const STATS_ORACLE_BADGES: Array[int] = [0x00, 0x01, 0x04, 0x10, 0x40, 0x55, 0xAA, 0xFF]
const STATS_ORACLE_KEYS: Array[String] = ["attack", "defense", "speed", "sp_attack"]
const STATS_NEUTRAL_MOD: int = 7

var _r: RefCounted = null


func run(r: RefCounted) -> void:
	_r = r
	r.each_game_of(RomRegistry.GEN1, _one_game)


func _one_game() -> void:
	_created_knowing()
	_critical_chances()
	_damage_oracle_sweep()
	_stats_oracle_sweep()
	_every_move()
	_a_wild_fight()
	_haze_clears_more_than_stages()
	_the_turn_bleeds_behind_each_move()
	_the_stored_stats_compound()
	_a_sleeper_loses_the_turn_it_wakes_on()
	_a_freeze_and_a_screen_outlive_the_turn()
	_counter_doubles_the_last_damage()
	_rage_raises_a_stage()
	_a_trapping_move_holds_its_target()
	_the_trap_counter_distribution()
	_conversion_copies_the_target()
	_teleport_ends_the_battle()
	_the_bag_in_a_fight()
	_a_safari_battle()
	_the_tutor_throws()
	_a_wild_fight_on_the_screen()


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


func _damage_oracle_sweep() -> void:
	var lines: PackedStringArray = PackedStringArray([DAMAGE_ORACLE_HEAD])
	for attack: int in DAMAGE_ATTACKS:
		for defense: int in DAMAGE_DEFENSES:
			for power: int in DAMAGE_POWERS:
				for level: int in DAMAGE_LEVELS:
					for critical: int in [0, 1]:
						for screens: int in [0, DAMAGE_REFLECT]:
							for rand: int in DAMAGE_RANDS:
								lines.append(_damage_line([
									power, 0, 0, level, attack, defense, attack + 7,
									defense + 3, screens, critical, [0, 0], [0, 0], rand,
								]))
	for attack: int in [90, 400]:
		for defense: int in [70, 300]:
			for screens: int in [0, DAMAGE_LIGHT_SCREEN, DAMAGE_REFLECT]:
				lines.append(_damage_line([
					95, DAMAGE_PSYCHIC, 0, 60, attack, defense, attack, defense, screens,
					0, [DAMAGE_PSYCHIC, DAMAGE_PSYCHIC], [0x01, 0x03], 255,
				]))
	var pairs: Array = []
	for kind: int in DAMAGE_TYPES:
		pairs.append([kind, kind])
	pairs.append_array(DAMAGE_PAIRS)
	for move_type: int in DAMAGE_TYPES:
		for pair: Array in pairs:
			for stab: int in [0, 1]:
				for row: Array in DAMAGE_TYPE_STATS:
					lines.append(_damage_line([
						int(row[2]), move_type, 0, 30, int(row[0]), int(row[1]),
						int(row[0]), int(row[1]), 0, 0,
						[move_type if stab == 1 else DAMAGE_DRAGON, DAMAGE_DRAGON], pair, 255,
					]))
	for defense: int in [30, 255, 256, 1000]:
		for attack: int in [100, 300]:
			lines.append(_damage_line([
				170, 0, DAMAGE_EXPLODE_EFFECT, 50, attack, defense, attack, defense,
				0, 0, [0, 0], [0, 0], 255,
			]))
	if _r.digest_matches("damage oracle", lines, DAMAGE_ORACLE_DIGEST):
		_r.note("gen1 battle %d damage cases answered as the cartridge does" % (lines.size() - 1))


func _stats_oracle_sweep() -> void:
	var lines: PackedStringArray = PackedStringArray([STATS_ORACLE_HEAD])
	var neutral: Array[int] = [STATS_NEUTRAL_MOD, STATS_NEUTRAL_MOD, STATS_NEUTRAL_MOD, STATS_NEUTRAL_MOD]
	for row: Array in STATS_ORACLE_ROWS:
		for status: int in STATS_ORACLE_STATUSES:
			for badges: int in STATS_ORACLE_BADGES:
				lines.append(_stats_line(row, neutral, status, badges))
	for stage: int in range(1, 14):
		for index: int in 4:
			var mods: Array[int] = neutral.duplicate()
			mods[index] = stage
			for row: Array in STATS_ORACLE_STAGED_ROWS:
				for status: int in STATS_ORACLE_STATUSES:
					lines.append(_stats_line(row, mods, status, 0x55))
	if _r.digest_matches("stat oracle", lines, STATS_ORACLE_DIGEST):
		_r.note("gen1 battle %d stored-stat cases answered as the cartridge does" % (lines.size() - 1))


func _stats_line(row: Array, mods: Array[int], status: int, badges: int) -> String:
	var mon: Gen2BattleMon = Gen2BattleMon.create(_r.data, SWEEP_PLAYER, SWEEP_LEVEL)
	for index: int in 4:
		mon.stats[STATS_ORACLE_KEYS[index]] = int(row[index])
		mon.stages[STATS_ORACLE_KEYS[index]] = mods[index] - STATS_NEUTRAL_MOD
	mon.stats["sp_defense"] = int(row[3])
	mon.stages["sp_defense"] = mods[3] - STATS_NEUTRAL_MOD
	mon.status = status
	mon.gen1_badges = badges
	mon.gen1_stats = {}
	mon.gen1_recalculate_stats()
	mon.gen1_apply_penalties()
	mon.gen1_apply_badge_boosts()
	var first: String = _stats_text(mon)
	mon.gen1_apply_badge_boosts()
	return "%d %d %d %d %x%x%x%x %d %d -> %s | %s" % [
		row[0], row[1], row[2], row[3], mods[0], mods[1], mods[2], mods[3], status,
		badges, first, _stats_text(mon),
	]


func _stats_text(mon: Gen2BattleMon) -> String:
	return "%d %d %d %d" % [
		mon.gen1_stats["attack"], mon.gen1_stats["defense"], mon.gen1_stats["speed"],
		mon.gen1_stats["special"],
	]


## A defense the shift leaves at zero hangs the cartridge, which prints HUNG.
func _damage_line(case: Array) -> String:
	var special: bool = int(case[1]) >= Gen2Layout.SPECIAL_TYPES_START
	var attacker: Gen2BattleMon = _stat_mon(
		int(case[3]), int(case[4]), int(case[6]), case[10] as Array, special, true
	)
	var defender: Gen2BattleMon = _stat_mon(
		int(case[3]), int(case[5]), int(case[7]), case[11] as Array, special, false
	)
	var screens: int = int(case[8])
	var critical: bool = int(case[9]) == 1
	var move: Dictionary = {
		"number": 1, "type": int(case[1]), "power": int(case[0]),
		"effect": Gen2MoveEffect.SELFDESTRUCT if int(case[2]) == DAMAGE_EXPLODE_EFFECT else 0,
	}
	var head: String = "%d %d %d %d %d %d %d %d %d %d %d,%d %d,%d %d" % [
		case[0], case[1], case[2], case[3], case[4], case[5], case[6], case[7],
		case[8], case[9], case[10][0], case[10][1], case[11][0], case[11][1], case[12],
	]
	var flags: int = (DAMAGE_REFLECT if screens & DAMAGE_REFLECT else 0) \
		| (DAMAGE_LIGHT_SCREEN if screens & DAMAGE_LIGHT_SCREEN else 0)
	var port_screens: int = (Gen2Screens.REFLECT if flags & DAMAGE_REFLECT else 0) \
		| (Gen2Screens.LIGHT_SCREEN if flags & DAMAGE_LIGHT_SCREEN else 0)
	var stats: Array = Gen2Damage.damage_stats(
		attacker, defender, int(case[1]), critical, port_screens
	)
	if int(stats[1]) == 0:
		return "%s -> HUNG HUNG" % head
	var rand: int = int(case[12])
	var result: Dictionary = Gen2Damage.calculate_with(
		attacker, defender, move, critical, ((rand >> 1) | ((rand & 1) << 7)) & 0xFF,
		Gen2Weather.NONE, port_screens
	)
	var missed: int = 1 if bool(result["missed"]) or bool(result["immune"]) else 0
	return "%s -> %d %d" % [head, int(result["damage"]), missed]


func _stat_mon(
	level: int, stored: int, party: int, types: Array, special: bool, attacking: bool
) -> Gen2BattleMon:
	var mon: Gen2BattleMon = Gen2BattleMon.create(_r.data, SWEEP_PLAYER, level)
	var key: String = "special" if special else ("attack" if attacking else "defense")
	mon.gen1_stats = {"attack": 1, "defense": 1, "speed": 1, "special": 1}
	mon.gen1_stats[key] = stored
	for party_key: String in (["sp_attack", "sp_defense"] if special else [key]):
		mon.stats[party_key] = party
	mon.battle_types = [int(types[0]), int(types[1])]
	return mon


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
const SWORDS_DANCE_MOVE: int = 14
const COUNTER_MOVE: int = 68
const RAGE_MOVE: int = 99
const TACKLE_MOVE: int = 33
const GASTLY: int = 92
const TOXIC_MOVE: int = 92
const LEECH_SEED_MOVE: int = 73
const REFLECT_MOVE: int = 115
const BADGES_ATTACK_SPEED: int = 0x11
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


## `HandlePoisonBurnLeechSeed` behind each side's move: a sixteenth, and a
## seed on a badly poisoned Pokemon stepping the toxic counter twice a turn.
func _the_turn_bleeds_behind_each_move() -> void:
	var battle: Gen2Battle = _fight(
		SWEEP_LEVEL, SWEEP_LEVEL, [TOXIC_MOVE, LEECH_SEED_MOVE], SWEEP_SEED, [SPLASH_MOVE]
	)
	if not _r.check(battle != null, "no battle could be built for TOXIC"):
		return
	battle.player.status = Gen2Status.POISON
	var before: int = battle.player.hp
	var events: Array = battle.take_turn(0, 0)
	var order: Array = []
	for event: Dictionary in events:
		var type: StringName = StringName(event.get("type", &""))
		if type == Gen2Battle.HURT_BY_STATUS or type == Gen2Battle.USED_MOVE:
			order.append("%s:%d" % [type, int(event.get("side", -1))])
	_r.check(
		before - battle.player.hp == maxi(battle.player.max_hp() >> Gen1Layout.RESIDUAL_SHIFT, 1),
		"a poisoned mover bled %d of %d" % [before - battle.player.hp, battle.player.max_hp()]
	)
	var player_moves: int = order.find("used_move:0")
	var hurt: int = order.find("hurt_by_status:0")
	_r.check(
		player_moves >= 0 and hurt > player_moves
		and (order.find("used_move:1") < 0 or order.find("used_move:1") > hurt
			or order.find("used_move:1") < player_moves),
		"the poison landed at %s" % str(order)
	)
	if not Gen2Status.has(battle.enemy.status, Gen2Status.POISON):
		return
	while not Gen2Substatus.has(battle.enemy.substatus, Gen2Substatus.LEECH_SEED):
		if battle.enemy.is_fainted() or battle.player.is_fainted():
			return
		battle.take_turn(1, 0)
	var counter: int = battle.enemy.toxic_counter
	battle.take_turn(1, 0)
	_r.check(battle.enemy.toxic_counter == counter + 2,
		"a seeded TOXIC counter went from %d to %d" % [counter, battle.enemy.toxic_counter])


## `ApplyBadgeStatBoosts` at the send-out and again behind a stat-up.
func _the_stored_stats_compound() -> void:
	var battle: Gen2Battle = _fight(
		SWEEP_LEVEL, SWEEP_LEVEL, [SWORDS_DANCE_MOVE], SWEEP_SEED, [SPLASH_MOVE]
	)
	if not _r.check(battle != null, "no battle could be built for SWORDS DANCE"):
		return
	battle.set_player_badges(BADGES_ATTACK_SPEED << Gen2WorldState.KANTO_BADGE_FIRST)
	var attack: int = battle.player.unmodified_stat("attack")
	var speed: int = battle.player.unmodified_stat("speed")
	_r.check(
		battle.player.stat("attack") == mini(attack + (attack >> 3), 999)
		and battle.player.stat("speed") == mini(speed + (speed >> 3), 999)
		and battle.player.stat("defense") == battle.player.unmodified_stat("defense"),
		"the badges read %d %d %d off %d %d" % [
			battle.player.stat("attack"), battle.player.stat("speed"),
			battle.player.stat("defense"), attack, speed,
		]
	)
	battle.player.status = Gen2Status.PARALYSIS
	battle.player.gen1_apply_penalties()
	var quartered: int = battle.player.stat("speed")
	battle.take_turn(0, 0)
	var doubled: int = mini(attack * 2, 999)
	_r.check(battle.player.stat("attack") == mini(doubled + (doubled >> 3), 999),
		"SWORDS DANCE left the attack at %d off %d" % [battle.player.stat("attack"), attack])
	_r.check(battle.player.stat("speed") == mini(quartered + (quartered >> 3), 999),
		"the speed was boosted again to %d from %d" % [battle.player.stat("speed"), quartered])
	battle.take_turn(0, 0)
	var tripled: int = mini(attack * 3, 999)
	_r.check(battle.player.stat("attack") == mini(tripled + (tripled >> 3), 999),
		"a second SWORDS DANCE left %d off %d" % [battle.player.stat("attack"), attack])


## `.WakeUp` falls into `ExecutePlayerMoveDone`, and `SleepEffect` rolls 1..7.
func _a_sleeper_loses_the_turn_it_wakes_on() -> void:
	var battle: Gen2Battle = _fight(SWEEP_LEVEL, SWEEP_LEVEL, [SPLASH_MOVE], SWEEP_SEED, [SPLASH_MOVE])
	if not _r.check(battle != null, "no battle could be built for a sleeper"):
		return
	battle.enemy.status = 1
	battle.player.status = 2
	_r.check(battle.player_move_menu_skipped() and not battle.player_menu_skipped(),
		"a sleeper was offered the move list")
	battle.player.status = Gen2Status.NONE
	var events: Array = battle.take_turn(0, 0)
	var woke: bool = false
	var moved: bool = false
	for event: Dictionary in events:
		var type: StringName = StringName(event.get("type", &""))
		woke = woke or type == Gen2Battle.WOKE_UP
		moved = moved or (type == Gen2Battle.USED_MOVE and int(event.get("side", -1)) == Gen2Battle.ENEMY)
	_r.check(woke and not moved, "the sleeper woke %s and moved %s" % [woke, moved])
	var rng := RandomNumberGenerator.new()
	rng.seed = SWEEP_SEED
	var seen: Dictionary = {}
	for _roll: int in 400:
		seen[Gen2Status.roll_sleep(rng, false, false, true)] = true
	_r.check(seen.size() == 7 and seen.has(1) and seen.has(7), "SleepEffect rolled %s" % str(seen.keys()))


## No `HandleDefrost` and no `HandleScreens`.
func _a_freeze_and_a_screen_outlive_the_turn() -> void:
	var battle: Gen2Battle = _fight(SWEEP_LEVEL, SWEEP_LEVEL, [REFLECT_MOVE, SPLASH_MOVE], SWEEP_SEED, [SPLASH_MOVE])
	if not _r.check(battle != null, "no battle could be built for REFLECT"):
		return
	battle.enemy.status = Gen2Status.FREEZE
	battle.take_turn(0, 0)
	for _turn: int in 8:
		battle.take_turn(1, 0)
	_r.check(Gen2Status.has(battle.enemy.status, Gen2Status.FREEZE), "the freeze thawed")
	_r.check(Gen2Screens.has(battle.screens[Gen2Battle.PLAYER], Gen2Screens.REFLECT),
		"REFLECT faded")
	_r.check(not battle.mon(Gen2Battle.ENEMY).is_fainted(), "the frozen target went down")


## `HandleCounterMove` reads the target's selected move and doubles `wDamage`
## with no type chart in the way, so a Gastly's TACKLE is paid back twice.
func _counter_doubles_the_last_damage() -> void:
	var generator := RandomNumberGenerator.new()
	generator.seed = SWEEP_SEED
	var battle: Gen2Battle = Gen2Battle.create(
		_r.data,
		Gen2BattleMon.create(_r.data, SWEEP_PLAYER, SWEEP_LEVEL, [COUNTER_MOVE]),
		Gen2BattleMon.create(_r.data, GASTLY, SWEEP_LEVEL, [TACKLE_MOVE]),
		generator
	)
	if not _r.check(battle != null, "no battle could be built for COUNTER"):
		return
	for _turn: int in 8:
		var player_before: int = battle.player.hp
		var enemy_before: int = battle.enemy.hp
		battle.take_turn(0, 0)
		var taken: int = player_before - battle.player.hp
		if taken <= 0 or battle.enemy.is_fainted():
			continue
		_r.check(enemy_before - battle.enemy.hp == taken * 2,
			"COUNTER paid %d back for %d" % [enemy_before - battle.enemy.hp, taken])
		return
	_r.fail("no turn saw TACKLE land and COUNTER answer")


## `HandleBuildingRage` is `StatModifierUpEffect` on the raging side: a stage,
## not a multiplier, and one per move that lands.
func _rage_raises_a_stage() -> void:
	var battle: Gen2Battle = _fight(SWEEP_LEVEL, SWEEP_LEVEL, [RAGE_MOVE], SWEEP_SEED, [TACKLE_MOVE])
	if not _r.check(battle != null, "no battle could be built for RAGE"):
		return
	var built: int = 0
	for _turn: int in 4:
		for event: Dictionary in battle.take_turn(0, 0):
			if StringName(event.get("type", &"")) == Gen2Battle.RAGE_BUILDING:
				built += 1
		if battle.enemy.is_fainted() or battle.player.is_fainted():
			break
	_r.check(built >= 2 and battle.player.stage("attack") == built,
		"%d hits left RAGE at stage %d" % [built, battle.player.stage("attack")])
	_r.check(battle.player.rage_count == 0, "a Generation 1 RAGE counted %d" % battle.player.rage_count)
	_r.check(battle.player.is_fainted() or battle.player_menu_skipped(),
		"a raging player was offered the menu")


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


## The same wild fight on the real screen, pressed through to its end:
## `PlayBattleVictoryMusic`'s MUSIC_DEFEATED_WILD_MON out of bank $08 once the
## wild has gone down, which the engine alone cannot hear.
var _watched: Gen2BattleScreen = null


func _a_wild_fight_on_the_screen() -> void:
	var screen: Gen2WorldScreen = _open_screen(PALLET_TOWN, TUTOR_CELL, true)
	## Yellow's starter leads: a PIKACHU carrying the save's own ID and name.
	var save: Gen2SaveData = screen.active_save()
	var lead: Gen2SaveMon = save.party[0]
	lead.species = PIKACHU_DEX
	lead.ot_id = save.player_id
	lead.original_trainer = save.player_name
	screen.preview_battle_request(SWEEP_ENEMY, FIGHT_LEVELS[1])
	var frames: int = 0
	var result: Dictionary = {}
	var over: bool = false
	var starter: bool = false
	while frames < TUTOR_GUARD_FRAMES:
		frames += 1
		screen.advance_frame()
		var host: Gen2BattleScreen = screen.get("_battle_host")
		if host == null:
			if over:
				break
			continue
		if host != _watched:
			_watched = host
			host.battle_finished.connect(func(finished: Dictionary) -> void: result.merge(finished))
			starter = host._battle.mon(Gen2Battle.PLAYER).starter_pikachu
		var snapshot: Dictionary = host.battle_snapshot()
		over = bool(snapshot.get("battle_over", false))
		if bool(snapshot.get("awaits_press", false)) or StringName(snapshot.get("menu_stage", &"")) != &"":
			screen.press_button(PokeButton.A)
	var victory: int = int(result.get("victory_music", -1))
	_r.check(over and not result.is_empty(), "the wild fight on the screen never ended.")
	_r.check(victory == Gen1Layout.MUSIC_DEFEATED_WILD_MON,
		"the win played music %d rather than MUSIC_DEFEATED_WILD_MON." % victory)
	_r.check(starter == (_r.game_id == RomRegistry.YELLOW),
		"the lead PIKACHU is %s the starter." % ["not" if not starter else "read as"])
	_r.note("gen1 battle the screen's wild fight ended in %d frames on piece %d" % [frames, victory])
	_close_screen(screen)
