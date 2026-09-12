extends GutTest

## `SelectEnemyMove`, `AIEnemyTrainerChooseMoves`' three layers, `TrainerAI`'s
## routines and the moves `ReadTrainer` writes over a party, on the fixture's
## two Generation 1 classes.

const Fixture := preload("res://tests/unit/battle_fixture.gd")

## Seeds enough for a share of 64 in 256 to settle inside a fortieth.
const SEEDS: int = 1024
const SHARE_TOLERANCE: float = 0.025
const DRAIN_MOVE: int = Fixture.DRAIN_MOVE

var _directory: String = ""
var _data: GameData = null
var _rng: RandomNumberGenerator = null


func before_each() -> void:
	_directory = RomCache.directory_for(&"gen1aitest", "0123456789abcdef")
	_data = Fixture.build(_directory, "testgame", RomRegistry.GEN1)
	_rng = RandomNumberGenerator.new()
	_rng.seed = 7


func after_each() -> void:
	RomCache.clear(_directory)


func _mon(species: int, moves: Array, level: int = 50) -> Gen2BattleMon:
	return Gen2BattleMon.create(_data, species, level, moves)


## A trainer battle against [param enemy_party], the player's Pikachu with
## Tackle. [param trainer_class] 0 is a wild.
func _battle(enemy_party: Array, trainer_class: int, player: Gen2BattleMon = null) -> Gen2Battle:
	var lead: Gen2BattleMon = player if player != null else _mon(Fixture.PIKACHU, [Fixture.TACKLE])
	var battle: Gen2Battle = Gen2Battle.create_parties(
		_data, Gen2Party.of(lead), Gen2Party.create(enemy_party), _rng, trainer_class > 0
	)
	if trainer_class > 0:
		battle.init_enemy_trainer(trainer_class)
	return battle


func _shares(battle: Gen2Battle) -> Array:
	var counts: Array = [0, 0, 0, 0]
	for seed_value: int in SEEDS:
		_rng.seed = seed_value
		counts[Gen1TrainerAI.select_slot(battle, _rng)] += 1
	return counts


func test_a_wild_rolls_its_four_slots_at_the_cartridges_shares() -> void:
	var battle: Gen2Battle = _battle([_mon(Fixture.GEODUDE, [
		Fixture.TACKLE, Fixture.GROWL, Fixture.SLASH, Fixture.EMBER,
	])], 0)
	var counts: Array = _shares(battle)
	for slot: int in 4:
		var expected: float = [64.0, 64.0, 63.0, 65.0][slot] / 256.0
		assert_almost_eq(
			float(counts[slot]) / float(SEEDS), expected, SHARE_TOLERANCE,
			".chooseRandomMove's slot %d share" % slot
		)


func test_a_disabled_or_empty_slot_is_rolled_again() -> void:
	var battle: Gen2Battle = _battle([_mon(Fixture.GEODUDE, [
		Fixture.TACKLE, Fixture.GROWL, Fixture.SLASH,
	])], 0)
	battle.mon(Gen2Battle.ENEMY).disabled_slot = 1
	var counts: Array = _shares(battle)
	assert_eq(counts[1], 0, "the disabled slot")
	assert_eq(counts[3], 0, "the empty slot")
	assert_eq(counts[0] + counts[2], SEEDS, "every roll landed on the two left")


func test_a_single_move_is_slot_zero_without_a_roll() -> void:
	var battle: Gen2Battle = _battle([_mon(Fixture.GEODUDE, [Fixture.TACKLE])], 0)
	assert_eq(_shares(battle)[0], SEEDS, ".canSelectMove's one-move answer")


func test_layer_one_discourages_status_moves_once_the_player_has_a_status() -> void:
	var battle: Gen2Battle = _battle([_mon(Fixture.GEODUDE, [
		Fixture.TACKLE, Fixture.THUNDER_WAVE, Fixture.SLEEP_POWDER,
	])], Fixture.GEN1_LEADER)
	assert_eq(Gen1TrainerAI.score_slots(battle, [1]), [10, 10, 10, 10], "a healthy player")
	battle.mon(Gen2Battle.PLAYER).status = Gen2Status.PARALYSIS
	assert_eq(Gen1TrainerAI.score_slots(battle, [1]), [10, 15, 15, 10], "a paralysed one")
	assert_eq(Gen1TrainerAI.enabled_slots(battle), [true, false, false, false])


func test_layer_two_encourages_setup_on_the_second_move_alone() -> void:
	var battle: Gen2Battle = _battle([_mon(Fixture.GEODUDE, [
		Fixture.TACKLE, Fixture.GROWL, Fixture.SWORDS_DANCE,
	])], Fixture.GEN1_LEADER)
	assert_eq(Gen1TrainerAI.score_slots(battle, [2]), [10, 10, 10, 10], "the first move")
	battle.gen1_enemy_moves = 1
	assert_eq(Gen1TrainerAI.score_slots(battle, [2]), [10, 9, 9, 10], "the second")
	battle.gen1_enemy_moves = 2
	assert_eq(Gen1TrainerAI.score_slots(battle, [2]), [10, 10, 10, 10], "the third")


func test_layer_three_reads_the_first_chart_row_and_a_better_move() -> void:
	var player: Gen2BattleMon = _mon(Fixture.GEODUDE, [Fixture.TACKLE])
	var battle: Gen2Battle = _battle(
		[_mon(Fixture.PIKACHU, [Fixture.TACKLE, DRAIN_MOVE, Fixture.THUNDER_WAVE])],
		Fixture.GEN1_LEADER, player
	)
	## Normal on Rock is resisted and Absorb is a damaging move of another type;
	## Grass on Rock is favoured; Electric's first row against Ground is 0, and
	## Thunder Wave's better move is either damaging one.
	assert_eq(Gen1TrainerAI.score_slots(battle, [3]), [11, 9, 11, 10])
	assert_eq(Gen1TrainerAI.enabled_slots(battle), [false, true, false, false])
	assert_eq(_data.first_matchup(Fixture.ELECTRIC, [Fixture.GROUND, Fixture.ROCK]), 0)
	assert_eq(_data.first_matchup(Fixture.DARK, [Fixture.NORMAL, Fixture.NORMAL]), -1)


func test_a_resisted_move_with_nothing_better_is_left_alone() -> void:
	var battle: Gen2Battle = _battle(
		[_mon(Fixture.PIKACHU, [Fixture.TACKLE, Fixture.GROWL])],
		Fixture.GEN1_LEADER, _mon(Fixture.GEODUDE, [Fixture.TACKLE])
	)
	assert_eq(Gen1TrainerAI.score_slots(battle, [3]), [10, 10, 10, 10])


func test_the_lowest_scores_are_what_the_roll_chooses_between() -> void:
	var battle: Gen2Battle = _battle([_mon(Fixture.GEODUDE, [
		Fixture.TACKLE, Fixture.THUNDER_WAVE, Fixture.SLASH,
	])], Fixture.GEN1_LEADER)
	battle.mon(Gen2Battle.PLAYER).status = Gen2Status.PARALYSIS
	var counts: Array = _shares(battle)
	assert_eq(counts[1], 0, "the discouraged status move")
	assert_gt(counts[0], 0)
	assert_gt(counts[2], 0)


func test_brock_spends_a_full_heal_on_a_status_and_nothing_otherwise() -> void:
	var battle: Gen2Battle = _battle([_mon(Fixture.GEODUDE, [Fixture.TACKLE])], Fixture.GEN1_LEADER)
	assert_eq(Gen1TrainerAI.trainer_action(battle, _rng), {}, "no status")
	assert_eq(battle.gen1_ai_count, Fixture.GEN1_LEADER_COUNT, "the count loads on the first pass")
	battle.mon(Gen2Battle.ENEMY).status = Gen2Status.BURN
	assert_eq(
		Gen1TrainerAI.trainer_action(battle, _rng), Gen2Battle.use_item(Gen1TrainerAI.FULL_HEAL)
	)
	assert_eq(battle.gen1_ai_count, Fixture.GEN1_LEADER_COUNT - 1, "DecrementAICount")
	battle.gen1_ai_count = 0
	assert_eq(Gen1TrainerAI.trainer_action(battle, _rng), {}, "no uses left")


func test_a_juggler_switches_a_quarter_of_the_time_to_the_first_other_member() -> void:
	var battle: Gen2Battle = _battle([
		_mon(Fixture.PIKACHU, [Fixture.TACKLE]), _mon(Fixture.GEODUDE, [Fixture.TACKLE]),
		_mon(Fixture.CHARMANDER, [Fixture.TACKLE]),
	], Fixture.GEN1_JUGGLER)
	var switched: int = 0
	for seed_value: int in SEEDS:
		_rng.seed = seed_value
		var action: Dictionary = Gen1TrainerAI.trainer_action(battle, _rng)
		if action.is_empty():
			continue
		assert_eq(action, Gen2Battle.switch_to(1))
		switched += 1
	assert_almost_eq(float(switched) / float(SEEDS), 65.0 / 256.0, SHARE_TOLERANCE)
	assert_eq(battle.gen1_ai_count, 3, "a switch spends no count")
	battle.party(Gen2Battle.ENEMY).at(1).hp = 0
	battle.party(Gen2Battle.ENEMY).at(2).hp = 0
	_rng.seed = 1
	assert_eq(Gen1TrainerAI.trainer_action(battle, _rng), {}, "nobody left to send")


func test_items_do_what_the_ai_use_routines_do() -> void:
	var battle: Gen2Battle = _battle([_mon(Fixture.GEODUDE, [Fixture.TACKLE])], Fixture.GEN1_LEADER)
	var enemy: Gen2BattleMon = battle.mon(Gen2Battle.ENEMY)
	enemy.hp = 1
	enemy.status = Gen2Status.POISON
	assert_eq(Gen1TrainerAI.apply_item(battle, enemy, Gen1TrainerAI.POTION), {"healed": 20})
	assert_eq(enemy.status, Gen2Status.POISON, "a potion cures nothing")
	assert_eq(Gen1TrainerAI.apply_item(battle, enemy, Gen1TrainerAI.FULL_HEAL), {"cured": true})
	enemy.status = Gen2Status.BURN
	var restored: Dictionary = Gen1TrainerAI.apply_item(battle, enemy, Gen1TrainerAI.FULL_RESTORE)
	assert_eq(restored, {"healed": enemy.max_hp() - 21, "cured": true})
	assert_eq(enemy.hp, enemy.max_hp())
	Gen1TrainerAI.apply_item(battle, enemy, Gen1TrainerAI.GUARD_SPEC)
	assert_true(Gen2Substatus.has(enemy.substatus, Gen2Substatus.MIST))
	var raised: Dictionary = Gen1TrainerAI.apply_item(battle, enemy, Gen1TrainerAI.X_ATTACK)
	assert_eq(raised, {"stat": "attack", "raised": true})
	assert_eq(enemy.stage("attack"), 1)


func test_the_class_acts_where_its_move_would_have_been() -> void:
	var battle: Gen2Battle = _battle(
		[_mon(Fixture.GEODUDE, [Fixture.TACKLE])], Fixture.GEN1_LEADER,
		_mon(Fixture.PIKACHU, [Fixture.GROWL])
	)
	battle.mon(Gen2Battle.ENEMY).status = Gen2Status.BURN
	var events: Array = battle.take_turn(0, 0)
	var kinds: Array = []
	for event: Dictionary in events:
		kinds.append(event["type"])
	var used: int = kinds.find(Gen2Battle.TRAINER_USED_ITEM)
	assert_gt(used, kinds.find(Gen2Battle.USED_MOVE), "after the faster player's move")
	assert_eq(battle.mon(Gen2Battle.ENEMY).status, Gen2Status.NONE)
	assert_eq(battle.gen1_enemy_moves, 0, "ExecuteEnemyMove was skipped")
	events = battle.take_turn(0, 0)
	assert_eq(battle.gen1_enemy_moves, 1, "and runs on the next turn")


func test_an_opponents_pp_is_never_spent() -> void:
	var battle: Gen2Battle = _battle([_mon(Fixture.GEODUDE, [Fixture.TACKLE])], 0)
	battle.take_turn(0, 0)
	assert_eq(battle.mon(Gen2Battle.ENEMY).pp_left(0), 35, "DecrementPP has no enemy half")
	assert_eq(battle.mon(Gen2Battle.PLAYER).pp_left(0), 34)


func test_quick_attack_goes_first_and_counter_last_by_move_number() -> void:
	var battle: Gen2Battle = _battle([_mon(Fixture.GEODUDE, [Fixture.TACKLE])], 0)
	var quick_attack: int = 98
	assert_eq(battle.order({Gen2Battle.PLAYER: Fixture.TACKLE, Gen2Battle.ENEMY: Fixture.TACKLE}),
		[Gen2Battle.PLAYER, Gen2Battle.ENEMY], "Pikachu outspeeds Geodude")
	assert_eq(battle.order({Gen2Battle.PLAYER: Fixture.TACKLE, Gen2Battle.ENEMY: quick_attack}),
		[Gen2Battle.ENEMY, Gen2Battle.PLAYER])
	assert_eq(battle.order({Gen2Battle.PLAYER: Fixture.COUNTER, Gen2Battle.ENEMY: Fixture.TACKLE}),
		[Gen2Battle.ENEMY, Gen2Battle.PLAYER])
	assert_eq(battle.order({Gen2Battle.PLAYER: Fixture.COUNTER, Gen2Battle.ENEMY: Fixture.COUNTER}),
		[Gen2Battle.PLAYER, Gen2Battle.ENEMY], "both used it, so speed")


func test_special_moves_land_by_the_lone_attack_and_the_starter() -> void:
	var lone: Gen2Party = Gen2TrainerParty.build(_data, Fixture.GEN1_LEADER, 0, null, {"lone_attack": 1})
	assert_eq(lone.at(1).moves, [Fixture.EMBER, 0, Fixture.GEN1_LONE_MOVE], "LoneMoves' row")
	assert_eq(lone.at(1).pp_left(2), 10, "the slot takes the move's own PP")
	assert_eq(lone.at(0).moves, [Fixture.GROWL, Fixture.SLASH], "and nothing else")
	var champion: Gen2Party = Gen2TrainerParty.build(
		_data, Fixture.GEN1_LEADER, 0, null, {"rival_starter": Fixture.GEN1_STARTER}
	)
	assert_eq(champion.at(0).moves, [Fixture.GROWL, Fixture.SLASH, Fixture.GEN1_TEAM_MOVE])
	assert_eq(champion.at(1).moves, [Fixture.EMBER, 0, 0, Fixture.GEN1_STARTER_MOVE])
	var other: Gen2Party = Gen2TrainerParty.build(_data, Fixture.GEN1_LEADER, 0, null, {})
	assert_eq(other.at(1).moves, [Fixture.EMBER, 0, 0, Fixture.GEN1_OTHER_STARTER_MOVE])
