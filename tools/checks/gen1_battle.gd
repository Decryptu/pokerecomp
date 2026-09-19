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

## `battle/gen1_turn.py`: `ExecutePlayerMove` whole, one move per effect byte.
const TURN_ORACLE_HEAD: String = "move variant -> missed rage beyond hits damage"
const TURN_ORACLE_DIGEST: String = "bf2342f7ecfd64e93ffcdabd95ffb1c6b06e020b"
const TRANSFORM_ORACLE_HEAD: String = "side sub target_transformed invulnerable -> user after"
const TRANSFORM_ORACLE_DIGEST: String = "f22be46ca73e7087e0946d31f57babee082833bc"
const ORACLE_STALE_DAMAGE: int = 1234
const ORACLE_LEVEL: int = 50
const ORACLE_STAT: int = 100
const ORACLE_HP: int = 300
const ORACLE_SUB_HP: int = 255
const ORACLE_USER: int = 1
const ORACLE_TARGET: int = 19
const ORACLE_DRAGON: int = 0x1A
const ORACLE_NORMAL: int = 0x00
const ORACLE_USER_TYPES: Array[int] = [ORACLE_DRAGON, ORACLE_DRAGON]
const ORACLE_FILLER: Array[int] = [33, 33, 33, 33]
const ORACLE_SKIPPED_MOVES: Array[int] = [118, 119, 102]
const ORACLE_TURN_VARIANTS: Array[String] = ["hit", "miss", "sub"]
const ORACLE_BIDE_VARIANTS: Dictionary = {
	"store": [2, 100, ORACLE_STALE_DAMAGE], "release": [1, 100, ORACLE_STALE_DAMAGE],
	"release_small": [1, 10, 0], "release_zero": [1, 0, 0],
	"store_wrap": [2, 0xFFF0, ORACLE_STALE_DAMAGE], "release_wrap": [1, 0x9000, 0],
}
const ORACLE_HIT_EVENTS: Array[StringName] = [
	Gen2Battle.HIT, Gen2Battle.OHKO, Gen2Battle.SUBSTITUTE_TOOK_DAMAGE,
]
const ORACLE_MISS_EVENTS: Array[StringName] = [Gen2Battle.MISSED, Gen2Battle.NO_EFFECT]
const ORACLE_PRINTED_EVENTS: Array[StringName] = [
	Gen2Battle.USED_MOVE, Gen2Battle.BIDE_STORING, Gen2Battle.BIDE_UNLEASHED,
	Gen2Battle.MOVE_FAILED, Gen2Battle.RAGE_BUILDING, Gen2Battle.STAT_CHANGED,
]
const ORACLE_TRANSFORM_STATS: Array[int] = [200, 201, 202, 203]
const ORACLE_TRANSFORM_UNMODIFIED: Array[int] = [150, 151, 152, 153]
const ORACLE_TRANSFORM_STAGE_KEYS: Array[String] = [
	"attack", "defense", "speed", "sp_attack", "accuracy", "evasion",
]
const ORACLE_TRANSFORM_MOVES: Array[int] = [33, 6, 7, 0]
const ORACLE_DISABLED_SLOT: int = 1
const ORACLE_DISABLED_TURNS: int = 2
const ORACLE_TWO_TO_FIVE_EFFECT: int = 0x1D
const ORACLE_SIDE_DROP_EFFECTS: Array[int] = [0x44, 0x45, 0x46, 0x47]

var _r: RefCounted = null


func run(r: RefCounted) -> void:
	_r = r
	r.each_game_of(RomRegistry.GEN1, _one_game)


func _one_game() -> void:
	_created_knowing()
	_critical_chances()
	_damage_oracle_sweep()
	_stats_oracle_sweep()
	_turn_oracle_sweep()
	_transform_oracle_sweep()
	_every_move()
	_a_wild_fight()
	_haze_clears_more_than_stages()
	_the_turn_bleeds_behind_each_move()
	_the_stored_stats_compound()
	_a_sleeper_loses_the_turn_it_wakes_on()
	_a_freeze_and_a_screen_outlive_the_turn()
	_counter_doubles_the_last_damage()
	_rage_raises_a_stage()
	_mimic_asks_the_player_and_rolls_for_the_enemy()
	_a_traded_pokemon_disobeys()
	_a_multi_hit_repeats_its_first_figure()
	_bide_stores_the_last_damage_at_each_turn()
	_fissure_reads_speed_and_swift_reaches_the_air()
	_sleep_lands_on_a_recharging_target()
	_a_trapping_move_holds_its_target()
	_the_trap_counter_distribution()
	_conversion_copies_the_target()
	_teleport_ends_the_battle()
	_the_bag_in_a_fight()
	_a_safari_battle()
	_the_tutor_throws()
	_a_wild_fight_on_the_screen()
	_mimic_on_the_screen()
	_a_lost_fight_on_the_screen()
	_a_ghost_on_the_screen()


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


func _oracle_moves() -> Array[int]:
	var by_effect: Dictionary = {}
	for number: int in range(1, MOVE_COUNT + 1):
		var byte: int = int(_r.data.move(number).get("gen1_effect", -1))
		if not by_effect.has(byte):
			by_effect[byte] = number
	var out: Array[int] = []
	out.assign(by_effect.values())
	if not out.has(COUNTER_MOVE):
		out.append(COUNTER_MOVE)
	out.sort()
	return out.filter(func(number: int) -> bool: return not ORACLE_SKIPPED_MOVES.has(number))


func _turn_oracle_sweep() -> void:
	var lines: PackedStringArray = PackedStringArray([TURN_ORACLE_HEAD])
	for move: int in _oracle_moves():
		for variant: String in ORACLE_TURN_VARIANTS:
			lines.append(_turn_line(move, variant))
	for variant: String in ORACLE_BIDE_VARIANTS:
		lines.append(_bide_line(variant))
	if _r.digest_matches("turn oracle", lines, TURN_ORACLE_DIGEST):
		_r.note("gen1 battle %d turn cases answered as the cartridge does" % (lines.size() - 1))


func _oracle_fight(move: int, target_moves: Array, user_types: Array) -> Gen2Battle:
	var generator := RandomNumberGenerator.new()
	generator.seed = SWEEP_SEED
	var battle: Gen2Battle = Gen2Battle.create(
		_r.data,
		Gen2BattleMon.create(_r.data, ORACLE_USER, ORACLE_LEVEL, [move] + ORACLE_FILLER.slice(1), 0),
		Gen2BattleMon.create(_r.data, ORACLE_TARGET, ORACLE_LEVEL, target_moves, 0),
		generator
	)
	if battle == null:
		return null
	_flatten(battle.player, user_types)
	_flatten(battle.enemy, [ORACLE_NORMAL, ORACLE_NORMAL])
	battle.enemy.substatus |= Gen2Substatus.RAGE
	battle.last_damage_dealt = ORACLE_STALE_DAMAGE
	battle.gen1_selected_moves[Gen2Battle.ENEMY] = TACKLE_MOVE
	return battle


func _flatten(mon: Gen2BattleMon, types: Array) -> void:
	for key: String in ["attack", "defense", "speed", "sp_attack", "sp_defense"]:
		mon.stats[key] = ORACLE_STAT
	mon.stats["hp"] = ORACLE_HP
	mon.hp = ORACLE_HP
	mon.battle_types = [int(types[0]), int(types[1])]
	mon.gen1_load_stats(0)


func _turn_line(move: int, variant: String) -> String:
	var battle: Gen2Battle = _oracle_fight(move, ORACLE_FILLER, ORACLE_USER_TYPES)
	if battle == null:
		return "%d %s -> no battle" % [move, variant]
	if variant == "miss":
		battle.enemy.substatus |= Gen2Substatus.FLYING
	else:
		battle.player.substatus |= Gen2Substatus.X_ACCURACY
	if variant == "sub":
		battle.enemy.substatus |= Gen2Substatus.SUBSTITUTE
		battle.enemy.substitute_hp = ORACLE_SUB_HP
	var events: Array = []
	battle._act(Gen2Battle.PLAYER, 0, move, events)
	var hits: int = _count_events(events, ORACLE_HIT_EVENTS, Gen2Battle.ENEMY)
	var lost: int = ORACLE_HP - battle.enemy.hp
	if variant == "sub":
		lost = ORACLE_SUB_HP - battle.enemy.substitute_hp \
			if Gen2Substatus.has(battle.enemy.substatus, Gen2Substatus.SUBSTITUTE) else ORACLE_SUB_HP
	var rage: int = _count_events(events, [Gen2Battle.RAGE_BUILDING])
	return "%d %s -> missed %d rage %s beyond %+d hits %s damage %s" % [
		move, variant, mini(_count_events(events, ORACLE_MISS_EVENTS), 1), _rage_text(rage, hits),
		battle.enemy.stage("attack") - _side_drops(events, move) - rage,
		_hits_text(hits, move), _damage_class(battle.last_damage_dealt, lost, hits),
	]


## The two figures a roll decides, folded the way the harness folds them.
func _hits_text(hits: int, move: int) -> String:
	if hits >= 2 and int(_r.data.move(move).get("gen1_effect", -1)) == ORACLE_TWO_TO_FIVE_EFFECT:
		return "2+"
	return str(hits)


func _rage_text(rage: int, hits: int) -> String:
	return "each" if rage > 0 and rage == hits else str(rage)


## The harness's roll never lands a `*_DOWN_SIDE_EFFECT`.
func _side_drops(events: Array, move: int) -> int:
	if not ORACLE_SIDE_DROP_EFFECTS.has(int(_r.data.move(move).get("gen1_effect", -1))):
		return 0
	var dropped: int = 0
	for event: Dictionary in events:
		if StringName(event.get("type", &"")) == Gen2Battle.STAT_CHANGED \
			and int(event.get("target", -1)) == Gen2Battle.ENEMY \
			and String(event.get("stat", "")) == "attack" and int(event.get("by", 0)) < 0:
			dropped += int(event.get("by", 0))
	return dropped


func _bide_line(variant: String) -> String:
	var battle: Gen2Battle = _oracle_fight(BIDE_MOVE, ORACLE_FILLER, ORACLE_USER_TYPES)
	if battle == null:
		return "%d %s -> no battle" % [BIDE_MOVE, variant]
	var preset: Array = ORACLE_BIDE_VARIANTS[variant]
	battle.player.substatus |= Gen2Substatus.X_ACCURACY | Gen2Substatus.BIDE
	battle.player.bide_turns = int(preset[0])
	battle.player.bide_damage = int(preset[1])
	battle.player.bide_move = BIDE_MOVE
	battle.last_damage_dealt = int(preset[2])
	var events: Array = []
	battle._act(Gen2Battle.PLAYER, 0, BIDE_MOVE, events)
	var missed: int = _count_events(events, ORACLE_MISS_EVENTS) \
		+ _count_events(events, [Gen2Battle.MOVE_FAILED])
	return "%d %s -> missed %d rage %d storing %d left %d acc %d damage %d printed %d" % [
		BIDE_MOVE, variant, mini(missed, 1), _count_events(events, [Gen2Battle.RAGE_BUILDING]),
		1 if Gen2Substatus.has(battle.player.substatus, Gen2Substatus.BIDE) else 0,
		battle.player.bide_turns, battle.player.bide_damage, battle.last_damage_dealt,
		_count_events(events, ORACLE_PRINTED_EVENTS),
	]


func _count_events(events: Array, kinds: Array, target: int = -1) -> int:
	var count: int = 0
	for event: Dictionary in events:
		if kinds.has(StringName(event.get("type", &""))) \
			and (target < 0 or int(event.get("target", -1)) == target):
			count += 1
	return count


func _damage_class(damage: int, lost: int, hits: int) -> String:
	if damage == 0:
		return "zero"
	if damage == ORACLE_STALE_DAMAGE:
		return "stale"
	if hits > 0 and lost == damage * hits:
		return "dealt"
	@warning_ignore("integer_division")
	if hits > 0 and lost / hits > 0 and damage == maxi(lost / hits / 2, 1):
		return "half"
	return str(damage)


func _transform_oracle_sweep() -> void:
	var lines: PackedStringArray = PackedStringArray([TRANSFORM_ORACLE_HEAD])
	for side: int in [Gen2Battle.PLAYER, Gen2Battle.ENEMY]:
		for sub: int in [0, 1]:
			for transformed: int in [0, 1]:
				for invulnerable: int in [0, 1]:
					lines.append(_transform_line(side, sub, transformed, invulnerable))
	if _r.digest_matches("transform oracle", lines, TRANSFORM_ORACLE_DIGEST):
		_r.note("gen1 battle %d transform cases answered as the cartridge does" % (lines.size() - 1))


func _transform_line(side: int, sub: int, transformed: int, invulnerable: int) -> String:
	var battle: Gen2Battle = _oracle_fight(TRANSFORM_MOVE, ORACLE_TRANSFORM_MOVES, ORACLE_USER_TYPES)
	if battle == null:
		return "%d %d %d %d -> no battle" % [side, sub, transformed, invulnerable]
	var user: Gen2BattleMon = battle.mon(side)
	var target: Gen2BattleMon = battle.mon(1 - side)
	battle.enemy.substatus &= ~Gen2Substatus.RAGE
	user.species = ORACLE_USER
	target.species = ORACLE_TARGET
	user.moves = [TRANSFORM_MOVE, 0, 0, 0]
	user.pp = [10, 0, 0, 0]
	user.dvs = 0x1234
	user.battle_types = ORACLE_USER_TYPES.duplicate()
	user.disabled_slot = ORACLE_DISABLED_SLOT
	user.disable_turns = ORACLE_DISABLED_TURNS
	target.moves = ORACLE_TRANSFORM_MOVES.duplicate()
	target.pp = [10, 10, 10, 0]
	target.dvs = 0xABCD
	target.battle_types = [ORACLE_NORMAL, 0x03]
	for index: int in 4:
		target.gen1_stats[Gen2BattleMon.GEN1_STAT_KEYS[index]] = ORACLE_TRANSFORM_STATS[index]
		target.stats[STATS_ORACLE_KEYS[index]] = ORACLE_TRANSFORM_UNMODIFIED[index]
	target.stats["sp_defense"] = ORACLE_TRANSFORM_UNMODIFIED[3]
	for index: int in ORACLE_TRANSFORM_STAGE_KEYS.size():
		target.stages[ORACLE_TRANSFORM_STAGE_KEYS[index]] = index + 1
	target.stages["sp_defense"] = 4
	if sub == 1:
		target.substatus |= Gen2Substatus.SUBSTITUTE
	if transformed == 1:
		target.substatus |= Gen2Substatus.TRANSFORMED
	if invulnerable == 1:
		target.substatus |= Gen2Substatus.FLYING
	var events: Array = []
	battle._act(side, 0, TRANSFORM_MOVE, events)
	var stages: String = ""
	for key: String in ORACLE_TRANSFORM_STAGE_KEYS:
		stages += "%x" % (user.stage(key) + STATS_NEUTRAL_MOD)
	return (
		"%d %d %d %d -> failed %d now %d species %d hp %d level %d types %d %d moves %s "
		+ "dvs %04x maxhp %d stats %s pp %s unmodified %s mods %s original %s disable %d"
	) % [
		side, sub, transformed, invulnerable, _count_events(events, [Gen2Battle.MOVE_FAILED]),
		1 if Gen2Substatus.has(user.substatus, Gen2Substatus.TRANSFORMED) else 0,
		user.species, user.hp, user.level, user.battle_types[0], user.battle_types[1],
		" ".join(user.moves.map(func(number: int) -> String: return str(number))),
		user.dvs, user.max_hp(), _stats_text(user),
		" ".join(user.pp.map(func(left: int) -> String: return str(left))),
		" ".join(STATS_ORACLE_KEYS.map(func(key: String) -> String: return str(user.stats[key]))),
		stages, "%04x" % user.persistent_dvs() if side == Gen2Battle.ENEMY else "-",
		1 if user.disabled_slot >= 0 else 0,
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
const MIMIC_MOVE: int = 102
const DOUBLESLAP_MOVE: int = 3
const BIDE_MOVE: int = 117
const TRANSFORM_MOVE: int = 144
const FISSURE_MOVE: int = 90
const SWIFT_MOVE: int = 129
const FLY_MOVE: int = 19
const SING_MOVE: int = 47
const X_ATTACK_ITEM: int = 0x41
const GUST_MOVE: int = 16
const TACKLE_MOVE: int = 33
const GROWL_MOVE: int = 45
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
	# `ItemUseXStat` is the same routine: X ATTACK moves the stage to +5 and
	# boosts every badge stat again.
	var speed_before: int = battle.player.stat("speed")
	battle.apply_x_item(battle.player, X_ATTACK_ITEM)
	var raised: int = mini(attack * 7 / 2, 999)
	_r.check(battle.player.stat("attack") == mini(raised + (raised >> 3), 999)
		and battle.player.stat("speed") == mini(speed_before + (speed_before >> 3), 999),
		"X ATTACK left %d and %d" % [battle.player.stat("attack"), battle.player.stat("speed")])


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


## `MimicEffect`: the player picks off the target's list, the enemy rolls, and
## the copy sits in MIMIC's own slot with MIMIC's own PP.
func _mimic_asks_the_player_and_rolls_for_the_enemy() -> void:
	var battle: Gen2Battle = _fight(SWEEP_LEVEL, SWEEP_LEVEL, [MIMIC_MOVE], SWEEP_SEED, [GUST_MOVE])
	if not _r.check(battle != null, "no battle could be built for MIMIC"):
		return
	battle.take_turn(0, 0)
	if not _r.check(battle.awaiting_mimic() == Gen2Battle.PLAYER, "MIMIC asked nobody"):
		return
	_r.check(battle.mimic_choices() == [GUST_MOVE], "the list read %s" % str(battle.mimic_choices()))
	_r.check(battle.answer_mimic(1).is_empty(), "an empty row was taken")
	battle.answer_mimic(0)
	_r.check(battle.awaiting_mimic() < 0 and int(battle.player.moves[0]) == GUST_MOVE
		and battle.player.pp_left(0) == int(_r.data.move(MIMIC_MOVE).get("pp", 0)) - 1,
		"the copy left slot 0 as %d with %d PP" % [battle.player.moves[0], battle.player.pp_left(0)])
	battle.player.reset_volatile()
	_r.check(int(battle.player.moves[0]) == MIMIC_MOVE
		and battle.player.pp_left(0) == int(_r.data.move(MIMIC_MOVE).get("pp", 0)) - 1,
		"the switch gave back %d with %d PP" % [battle.player.moves[0], battle.player.pp_left(0)])

	var rolled: Gen2Battle = _fight(SWEEP_LEVEL, SWEEP_LEVEL, [SPLASH_MOVE], SWEEP_SEED, [MIMIC_MOVE])
	rolled.take_turn(0, 0)
	_r.check(rolled.awaiting_mimic() < 0 and int(rolled.enemy.moves[0]) == SPLASH_MOVE,
		"the enemy's MIMIC left %s" % str(rolled.enemy.moves))


## `jp nz, GetPlayerAnimationType`: every hit of a multi-hit move is the first
## one's damage, the calculation and the roll happening once.
func _a_multi_hit_repeats_its_first_figure() -> void:
	var battle: Gen2Battle = _fight(SWEEP_LEVEL, SWEEP_LEVEL, [DOUBLESLAP_MOVE], SWEEP_SEED, [SPLASH_MOVE])
	if not _r.check(battle != null, "no battle could be built for DOUBLESLAP"):
		return
	var seen: Dictionary = {}
	for _turn: int in 12:
		var amounts: Array = []
		for event: Dictionary in battle.take_turn(0, 0):
			if StringName(event.get("type", &"")) == Gen2Battle.HIT and int(event.get("target", -1)) == Gen2Battle.ENEMY:
				amounts.append(int(event.get("amount", 0)))
		if amounts.size() > 1:
			seen[amounts.size()] = true
			_r.check(amounts.count(amounts[0]) == amounts.size() or battle.enemy.is_fainted(),
				"DOUBLESLAP dealt %s" % str(amounts))
		if battle.enemy.is_fainted() or battle.player.is_fainted():
			break
	_r.check(not seen.is_empty(), "DOUBLESLAP never hit twice")


## `.BideCheck` adds `wDamage` at each of the user's turns and unleashes twice
## the total with no `MoveHitTest`: a faster TACKLE every turn is summed from
## the turn after BIDE was chosen.
func _bide_stores_the_last_damage_at_each_turn() -> void:
	var battle: Gen2Battle = _fight(SWEEP_LEVEL, SWEEP_LEVEL, [BIDE_MOVE], SWEEP_SEED, [TACKLE_MOVE])
	if not _r.check(battle != null, "no battle could be built for BIDE"):
		return
	var stored: int = 0
	for turn: int in 6:
		var player_before: int = battle.player.hp
		var enemy_before: int = battle.enemy.hp
		var events: Array = battle.take_turn(0, 0)
		var released: bool = events.any(func(event: Dictionary) -> bool:
			return StringName(event.get("type", &"")) == Gen2Battle.BIDE_UNLEASHED)
		if turn > 0:
			stored += player_before - battle.player.hp
		if released:
			var paid: int = enemy_before - battle.enemy.hp
			_r.check(paid == stored * 2 or battle.enemy.is_fainted(),
				"BIDE paid %d back for %d stored" % [paid, stored])
			return
		if battle.player.is_fainted():
			break
	_r.fail("BIDE never unleashed")


## `OneHitKOEffect_` misses a faster target whatever the levels, and Swift
## returns from `MoveHitTest` in front of the Fly and Dig check.
func _fissure_reads_speed_and_swift_reaches_the_air() -> void:
	var battle: Gen2Battle = _fight(SWEEP_LEVEL, SWEEP_LEVEL, [FISSURE_MOVE], SWEEP_SEED, [SPLASH_MOVE])
	if not _r.check(battle != null, "no battle could be built for FISSURE"):
		return
	_r.check(battle.player.stat("speed") < battle.enemy.stat("speed"), "the user is not slower")
	for _turn: int in 4:
		for event: Dictionary in battle.take_turn(0, 0):
			_r.check(StringName(event.get("type", &"")) != Gen2Battle.OHKO, "FISSURE landed from below")
	var swift: Gen2Battle = _fight(SWEEP_LEVEL, SWEEP_LEVEL, [SWIFT_MOVE], SWEEP_SEED, [FLY_MOVE])
	var hits: int = 0
	var flying: int = 0
	for _turn: int in 6:
		var events: Array = swift.take_turn(0, 0)
		if not Gen2Substatus.has(swift.enemy.substatus, Gen2Substatus.FLYING):
			continue
		flying += 1
		for event: Dictionary in events:
			if StringName(event.get("type", &"")) == Gen2Battle.HIT and int(event.get("target", -1)) == Gen2Battle.ENEMY:
				hits += 1
		if swift.enemy.is_fainted() or swift.player.is_fainted():
			break
	_r.check(flying > 0 and hits == flying, "SWIFT hit %d times over %d turns in the air" % [hits, flying])


## `SleepEffect` skips every test for a target that needs to recharge, the
## status it already carries included.
func _sleep_lands_on_a_recharging_target() -> void:
	var battle: Gen2Battle = _fight(SWEEP_LEVEL, FIGHT_LEVELS[1], [SING_MOVE], SWEEP_SEED, [SPLASH_MOVE])
	if not _r.check(battle != null, "no battle could be built for SING"):
		return
	battle.enemy.status = Gen2Status.PARALYSIS
	battle.enemy.substatus |= Gen2Substatus.RECHARGING
	battle.take_turn(0, 0)
	_r.check(Gen2Status.is_asleep(battle.enemy.status)
		and not Gen2Substatus.has(battle.enemy.substatus, Gen2Substatus.RECHARGING),
		"SING left the recharging target at status %d" % battle.enemy.status)


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


## The same fight with MIMIC alone: the screen puts the enemy's list up under
## `wMoveMenuType` 1, and A takes the row and the fight goes on.
func _mimic_on_the_screen() -> void:
	var screen: Gen2WorldScreen = _open_screen(PALLET_TOWN, TUTOR_CELL, true)
	var lead: Gen2SaveMon = screen.active_save().party[0]
	lead.moves = [MIMIC_MOVE, 0, 0, 0]
	lead.pp = [int(_r.data.move(MIMIC_MOVE).get("pp", 0)), 0, 0, 0]
	screen.preview_battle_request(SWEEP_ENEMY, FIGHT_LEVELS[1])
	var frames: int = 0
	var asked: bool = false
	var copied: int = 0
	while frames < TUTOR_GUARD_FRAMES:
		frames += 1
		screen.advance_frame()
		var host: Gen2BattleScreen = screen.get("_battle_host")
		if host == null:
			continue
		var snapshot: Dictionary = host.battle_snapshot()
		if bool(snapshot.get("battle_over", false)):
			break
		var stage: StringName = StringName(snapshot.get("menu_stage", &""))
		if stage == &"mimic":
			asked = true
		if asked and copied == 0 and host._battle.awaiting_mimic() < 0:
			copied = int(host._battle.mon(Gen2Battle.PLAYER).moves[0])
			break
		if bool(snapshot.get("awaits_press", false)) or stage != &"":
			screen.press_button(PokeButton.A)
	_r.check(asked, "the screen never put MIMIC's list up.")
	_r.check(copied != 0 and copied != MIMIC_MOVE, "the screen's MIMIC copied %d." % copied)
	_close_screen(screen)


## `HandlePlayerBlackOut` on the real screen and `.battleOccurred` behind it. A
## row is the map, the opponent (-1 the map's first trainer, 0 a wild, else a
## class), the lines the fight says, whether each wore PAL_BLACK, and whether
## the map's blackout follows.
const ROUTE_3: int = 14
const ROUTE_22: int = 33
const LOSS_MONEY: int = 3001
const LOSS_ROWS: Array = [
	[ROUTE_3, 0, ["blacked_out"], [true], true],
	[ROUTE_3, -1, ["blacked_out"], [true], true],
	[ROUTE_22, Gen1Layout.RIVAL1_CLASS, ["rival1_win", "blacked_out"], [false, true], true],
	[Gen1Layout.OAKS_LAB, Gen1Layout.RIVAL1_CLASS, ["rival1_win"], [false], false],
]


func _a_lost_fight_on_the_screen() -> void:
	for row: Array in LOSS_ROWS:
		var screen: Gen2WorldScreen = _open_screen(int(row[0]), TUTOR_CELL, true)
		var world: Gen2WorldAPI = screen.world()
		world.state.apply_changes({}, {}, {"money": {0: LOSS_MONEY}})
		var from: Vector2i = world.player_cell
		if int(row[1]) < 0:
			_talk_to_first_trainer(screen)
		elif int(row[1]) == 0:
			screen.preview_battle_request(SWEEP_ENEMY, FIGHT_LEVELS[0])
		else:
			screen._start_battle_request(world._gen1_trainer_request(int(row[1]), 1, {}, -1)["values"])
		var fought: Dictionary = _drive_loss(screen)
		var messages: Array = fought["messages"]
		var black: Array = fought["black"]
		for index: int in range(messages.size() - 1, -1, -1):
			if String(messages[index]).ends_with("fainted!"):
				messages = messages.slice(index + 1)
				black = black.slice(index + 1)
				break
		var said: Array = []
		for name: String in row[2]:
			said.append(world.gen1_filled_text(_r.data.special_text("link_battle", name)))
		_r.check(messages == said, "the lost fight on map %d said %s, expected %s" % [
			row[0], messages, said])
		_r.check(black == row[3], "the lost fight on map %d wore PAL_BLACK %s, expected %s" % [
			row[0], black, row[3]])
		var save: Gen2SaveData = screen.active_save()
		var landing: Dictionary = _r.data.gen1_fly_warp(PALLET_TOWN)
		if bool(row[4]):
			_r.check(world.current_map.number == PALLET_TOWN
				and world.player_cell == Vector2i(int(landing["x"]), int(landing["y"])),
				"the blackout from map %d landed on map %d at %s." % [row[0], world.current_map.number, world.player_cell])
			_r.check(world.state.money(0) == LOSS_MONEY / 2, "the blackout left ¥%d." % world.state.money(0))
			_r.check(save.party[0].hp == Gen2SaveBattleAdapter.to_battle_mon(_r.data, save.party[0]).max_hp(),
				"the blackout left the lead on %d HP." % save.party[0].hp)
		else:
			_r.check(world.current_map.number == int(row[0]) and world.player_cell == from,
				"a loss in OAKS_LAB moved the player to map %d %s." % [world.current_map.number, world.player_cell])
			_r.check(world.state.money(0) == LOSS_MONEY and save.party[0].hp == 0,
				"a loss in OAKS_LAB cost ¥%d and healed to %d." % [LOSS_MONEY - world.state.money(0), save.party[0].hp])
		_r.check(not screen._field_move_text and not screen._script_prompt.begins_with("Blackout"),
			"the loss on map %d left the map on %s." % [row[0], screen._script_prompt])
		_r.note("gen1 battle a loss on map %d to %d said %d lines in %d frames" % [
			row[0], row[1], said.size(), fought["frames"]])
		_close_screen(screen)


## `TalkToTrainer` on the map's first trainer, pressed past the before line.
func _talk_to_first_trainer(screen: Gen2WorldScreen) -> void:
	var world: Gen2WorldAPI = screen.world()
	for object: Gen2WorldObject in world.objects:
		if object.object_type == Gen2WorldObject.OBJECTTYPE_TRAINER:
			world.player_cell = object.cell + Vector2i.DOWN
			break
	screen.press_button(PokeButton.UP)
	screen.advance_frames(TUTOR_SETTLE_FRAMES)
	screen.interact()
	screen.advance_frames(TUTOR_SETTLE_FRAMES)
	screen.press_button(PokeButton.A)


const TUTOR_SETTLE_FRAMES: int = 120


## The fight lost by the enemy's own move: the lead on one HP knowing SPLASH
## alone and the rest down. Every line printed and its palette, to the map.
func _drive_loss(screen: Gen2WorldScreen) -> Dictionary:
	var messages: Array[String] = []
	var black: Array[bool] = []
	var frames: int = 0
	var host: Gen2BattleScreen = null
	var felled: bool = false
	while frames < TUTOR_GUARD_FRAMES:
		frames += 1
		screen.advance_frame()
		var current: Gen2BattleScreen = screen.get("_battle_host")
		if current == null:
			if host != null:
				break
			continue
		host = current
		var snapshot: Dictionary = host.battle_snapshot()
		if not felled and StringName(snapshot.get("menu_stage", &"")) != &"":
			felled = true
			var party: Array = host._battle.party(Gen2Battle.PLAYER).mons
			for member: Gen2BattleMon in party:
				member.hp = 0
			(party[0] as Gen2BattleMon).hp = 1
			(party[0] as Gen2BattleMon).moves = [SPLASH_MOVE, 0, 0, 0]
			(party[0] as Gen2BattleMon).pp = [1, 0, 0, 0]
		var line: String = String(snapshot.get("message", ""))
		if felled and not line.is_empty() and (messages.is_empty() or messages.back() != line):
			messages.append(line)
			black.append(bool(host.get("_gen1_black")))
		if bool(snapshot.get("awaits_press", false)) or StringName(snapshot.get("menu_stage", &"")) != &"":
			screen.press_button(PokeButton.A)
	return {"frames": frames, "messages": messages, "black": black}


## `CheckForDisobedience` on a traded lead of 40 with no badge: every outcome
## over 400 seeds, `.useRandomMove`'s pick never the slot above the one chosen,
## and no `ignored orders...sleeping` since the routine has no sleep test.
## MARSHBADGE alone, bit 6, lifts the ceiling to 70.
const DISOBEY_LEVEL: int = 40
const DISOBEY_SEEDS: int = 400
const DISOBEY_BADGES: int = 0
const MARSH_BADGE: int = 1 << 6


func _a_traded_pokemon_disobeys() -> void:
	var outcomes: Dictionary = {}
	var picked: Dictionary = {}
	for seed_value: int in DISOBEY_SEEDS:
		var battle: Gen2Battle = _disobedience_fight(seed_value, DISOBEY_BADGES)
		for event: Dictionary in battle.take_turn(0, 0):
			if event.get("type", &"") == Gen2Battle.CANNOT_MOVE:
				outcomes[event["reason"]] = true
			elif event.get("type", &"") == Gen2Battle.USED_MOVE \
				and int(event.get("side", -1)) == Gen2Battle.PLAYER:
				picked[int(event["move"])] = true
	for outcome: StringName in [&"began_to_nap", &"wont_obey", &"loafing", &"turned_away", &"ignored_orders"]:
		_r.check(outcomes.has(outcome), "no seed reached %s" % outcome)
	_r.check(not outcomes.has(&"ignored_sleeping"), "a Generation 1 lead ignored orders sleeping")
	_r.check(picked.has(GROWL_MOVE) and picked.has(TACKLE_MOVE) and not picked.has(SPLASH_MOVE),
		"the disobedient picks were %s" % [picked.keys()])
	var obedient: int = 0
	for seed_value: int in DISOBEY_SEEDS:
		var battle: Gen2Battle = _disobedience_fight(seed_value, MARSH_BADGE)
		var disobeyed: bool = false
		for event: Dictionary in battle.take_turn(0, 0):
			disobeyed = disobeyed or event.get("type", &"") == Gen2Battle.CANNOT_MOVE
		obedient += 0 if disobeyed else 1
	_r.check(obedient == DISOBEY_SEEDS, "MARSHBADGE left %d of %d seeds disobeying" % [
		DISOBEY_SEEDS - obedient, DISOBEY_SEEDS])
	_r.note("gen1 battle disobedience reached %d outcomes, picking %s" % [outcomes.size(), picked.keys()])


## GROWL, SPLASH and TACKLE, GROWL chosen: the roll compared with the one-based
## cursor skips SPLASH and the zero-based slot reaches GROWL again.
func _disobedience_fight(seed_value: int, badges: int) -> Gen2Battle:
	var battle: Gen2Battle = _fight(
		DISOBEY_LEVEL, SWEEP_LEVEL, [GROWL_MOVE, SPLASH_MOVE, TACKLE_MOVE], seed_value, [SPLASH_MOVE]
	)
	battle.player_id = 1
	battle.player.ot_id = 2
	battle.set_player_badges(badges << Gen2WorldState.KANTO_BADGE_FIRST)
	return battle


## `IsGhostBattle` on the real screen: a GASTLY on Pokemon Tower 3F with no
## SILPH SCOPE is a GHOST nobody can move against and everybody runs from, and
## the RESTLESS_SOUL with the scope is unveiled as a MAROWAK over
## `MarowakAnim`'s 153 frames.
const POKEMON_TOWER_3F: int = 0x90
const GHOST_LINES: Array[String] = [
	"GHOST\nappeared!", "Darn! The GHOST\ncan't be ID'd!", "Go! BULBASAUR!",
	"GHOST: Get out...\nGet out...", "BULBASAUR is too\nscared to move!", "Got away safely!",
]
const UNVEIL_LINES: Array[String] = [
	"GHOST\nappeared!", "SILPH SCOPE\nunveiled the" + Gen2TextStream.SCROLL_BREAK + "GHOST's identity!",
	"Wild MAROWAK\nappeared!", "Go! BULBASAUR!",
]


func _a_ghost_on_the_screen() -> void:
	var screen: Gen2WorldScreen = _open_screen(POKEMON_TOWER_3F, TUTOR_CELL, true)
	var world: Gen2WorldAPI = screen.world()
	_r.check(world.gen1_ghost_kind(GASTLY) == Gen1Layout.GHOST_UNIDENTIFIED
		and world.gen1_ghost_kind(Gen1Layout.RESTLESS_SOUL) == Gen1Layout.GHOST_UNIDENTIFIED,
		"a tower wild without the scope is not a ghost")
	screen.preview_battle_request(GASTLY, SWEEP_LEVEL)
	var fought: Dictionary = _drive_ghost(screen, true)
	_r.check(fought["messages"] == GHOST_LINES, "the ghost fight said %s" % [fought["messages"]])
	_r.check(fought["name"] == "Enemy GHOST" and fought["pic"] == "true",
		"the ghost stood as %s, ghosted %s" % [fought["name"], fought["pic"]])
	_r.check(bool(fought["ran"]), "the ghost fight did not end on the run")
	_close_screen(screen)
	screen = _open_screen(POKEMON_TOWER_3F, TUTOR_CELL, true)
	world = screen.world()
	world.state.apply_changes({}, {}, {"items": {Gen1Layout.ITEM_SILPH_SCOPE: 1}})
	_r.check(world.gen1_ghost_kind(GASTLY) == &""
		and world.gen1_ghost_kind(Gen1Layout.RESTLESS_SOUL) == Gen1Layout.GHOST_UNVEILED,
		"the scope does not unveil the MAROWAK alone")
	screen.preview_battle_request(Gen1Layout.RESTLESS_SOUL, SWEEP_LEVEL)
	var unveiled: Dictionary = _drive_ghost(screen, false)
	_r.check(unveiled["messages"] == UNVEIL_LINES, "the unveiling said %s" % [unveiled["messages"]])
	_r.check(unveiled["name"] == "Enemy MAROWAK" and unveiled["pic"] == "false",
		"the unveiled ghost stood as %s, ghosted %s" % [unveiled["name"], unveiled["pic"]])
	## Sampled before each frame, so the one that clears it is not counted.
	_r.check(int(unveiled["unveil_frames"]) == Gen2BattleScreen.UNVEIL_FRAMES - 1,
		"MarowakAnim ran %d frames" % int(unveiled["unveil_frames"]))
	_r.note("gen1 battle the ghost said %d lines and the unveiling %d over %d frames" % [
		GHOST_LINES.size(), UNVEIL_LINES.size(), int(unveiled["unveil_frames"])])
	_close_screen(screen)


## Every line to the first menu, then FIGHT's first move and RUN when
## [param runs], with what the enemy stood as at the menu.
func _drive_ghost(screen: Gen2WorldScreen, runs: bool) -> Dictionary:
	var messages: Array[String] = []
	var frames: int = 0
	var unveil_frames: int = 0
	var host: Gen2BattleScreen = null
	var menus: int = 0
	var out: Dictionary = {"name": "", "pic": "", "ran": false}
	while frames < TUTOR_GUARD_FRAMES:
		frames += 1
		screen.advance_frame()
		var current: Gen2BattleScreen = screen.get("_battle_host")
		if current == null:
			if host != null:
				break
			continue
		host = current
		if not (host.get("_unveil") as Dictionary).is_empty():
			unveil_frames += 1
		var snapshot: Dictionary = host.battle_snapshot()
		var line: String = String(snapshot.get("message", ""))
		if not line.is_empty() and (messages.is_empty() or messages.back() != line):
			messages.append(line)
		if StringName(snapshot.get("menu_stage", &"")) == &"main":
			if menus == 0:
				out["name"] = String(host._battler_name(Gen2Battle.ENEMY))
				out["pic"] = str(host._enemy_ghosted)
			menus += 1
			if not runs or menus > 2:
				break
			if menus == 2:
				screen.press_button(PokeButton.DOWN)
				screen.advance_frame()
				screen.press_button(PokeButton.RIGHT)
				screen.advance_frame()
			screen.press_button(PokeButton.A)
		elif bool(snapshot.get("awaits_press", false)) or StringName(snapshot.get("menu_stage", &"")) != &"":
			screen.press_button(PokeButton.A)
	out["ran"] = host == null or not is_instance_valid(host) or host.get_parent() == null
	out["messages"] = messages
	out["unveil_frames"] = unveil_frames
	return out
