extends GutTest

## Battle requests use a small synthetic cache so their validation and party
## construction stay independent of a real cartridge or a scene tree.

const SPECIES_ONE: int = 1
const SPECIES_TWO: int = 2
const TACKLE: int = 1

var _directory: String = ""
var _data: GameData = null


func before_each() -> void:
	_directory = RomCache.directory_for(&"worldbattletest", "0123456789abcdef")
	RomCache.clear(_directory)
	RomCache.prepare(_directory)
	_write_cache()
	_data = GameData.open_directory(_directory)


func after_each() -> void:
	RomCache.clear(_directory)


func _write_cache() -> void:
	RomCache.write_json(RomCache.species_path(_directory), [
		{
			"number": SPECIES_ONE, "name": "ONE",
			"stats": {"hp": 50, "attack": 50, "defense": 50, "speed": 50,
				"sp_attack": 50, "sp_defense": 50},
			"types": [0, 0], "growth_rate": Gen2Experience.GROWTH_MEDIUM_FAST,
			"base_exp": 50, "gender_ratio": 0, "held_items": [0, 0],
			"learnset": [{"level": 1, "move": TACKLE}],
		},
		{
			"number": SPECIES_TWO, "name": "TWO",
			"stats": {"hp": 60, "attack": 60, "defense": 60, "speed": 60,
				"sp_attack": 60, "sp_defense": 60},
			"types": [0, 0], "growth_rate": Gen2Experience.GROWTH_MEDIUM_FAST,
			"base_exp": 60, "gender_ratio": 0, "held_items": [17, 18],
			"learnset": [{"level": 1, "move": TACKLE}],
		},
	])
	RomCache.write_json(RomCache.moves_path(_directory), [{
		"number": TACKLE, "name": "TACKLE", "power": 40, "type": 0,
		"accuracy": 255, "pp": 35, "effect": 0, "chance": 0,
	}])
	RomCache.write_json(RomCache.items_path(_directory), [])
	RomCache.write_json(RomCache.types_path(_directory), [{"number": 0, "name": "NORMAL"}])
	RomCache.write_json(RomCache.matchups_path(_directory), [])
	RomCache.write_json(RomCache.trainers_path(_directory), [{
		"number": 1, "name": "ACE", "palette": [0x1234, 0x5678], "dvs": 0xFFFF,
		## `TrainerClassAttributes`' base reward, which `ComputeTrainerReward`
		## multiplies by the last party member's level. 25 is Falkner's row.
		"attributes": {
			"item1": 0, "item2": 0, "base_reward": 25,
			"ai_move_weights": 0, "ai_item_switch": 0,
		},
		"trainers": [{
			"name": "ACE", "type": Gen2Layout.TRAINER_MON_NORMAL,
			"party": [{"level": 5, "species": SPECIES_TWO, "item": 0, "moves": []}],
		}],
	}])
	RomCache.write_json(RomCache.manifest_path(_directory), {
		"format_version": RomCache.FORMAT_VERSION,
		"game_id": "worldbattletest",
		"sha1": "0123456789abcdef",
		"complete": true,
	})


func _player_party() -> Gen2Party:
	return Gen2WorldBattleAdapter.fallback_party(_data, SPECIES_ONE, 5, 1)


func test_wild_request_builds_a_one_mon_enemy_party() -> void:
	var prepared: Dictionary = Gen2WorldBattleAdapter.prepare(
		_data,
		{"kind": &"battle_requested", "values": {
			"kind": &"wild", "pokemon": SPECIES_TWO, "level": 5,
		}},
		_player_party(), RandomNumberGenerator.new()
	)
	assert_true(prepared["ok"])
	assert_false(prepared["trainer_battle"])
	assert_eq((prepared["enemy_party"] as Gen2Party).size(), 1)
	assert_eq((prepared["battle"] as Gen2Battle).enemy.species, SPECIES_TWO)


func test_special_battle_requests_keep_their_context() -> void:
	var opponent := Gen2SaveMon.new()
	opponent.species = SPECIES_TWO
	opponent.level = 5
	opponent.moves = [TACKLE]
	opponent.pp = [35]
	opponent.hp = 10
	for kind: StringName in [&"battle_tower", &"link_battle"]:
		var prepared: Dictionary = Gen2WorldBattleAdapter.prepare(
			_data, {"values": {
				"kind": kind, "trainer_class": 1,
				"enemy_party": [opponent.to_dict()],
			}}, _player_party(), RandomNumberGenerator.new(), 0, null, 123
		)
		assert_true(bool(prepared["ok"]), String(prepared.get("reason", "")))
		var battle: Gen2Battle = prepared["battle"]
		assert_eq(battle.in_battle_tower, kind == &"battle_tower")
		assert_eq(battle.is_link_battle, kind == &"link_battle")
		assert_eq(battle.player_id, 123)



## `LoadEnemyMon.WildItem` spends its item roll before the two DV bytes. Sweep
## enough seeds to reach all three exits and compare the whole draw order.
func test_a_wild_rolls_its_species_held_items_before_its_dvs() -> void:
	var seen: Dictionary = {}
	for seed_value: int in 2048:
		var expected_rng := RandomNumberGenerator.new()
		expected_rng.seed = seed_value
		var first: int = expected_rng.randi_range(0, 255)
		var expected_item: int = 0
		if first >= Gen2WorldBattleAdapter.WILD_ITEM_NONE_ROLL:
			expected_item = 18 \
				if expected_rng.randi_range(0, 255) < Gen2WorldBattleAdapter.WILD_ITEM_RARE_ROLL \
				else 17
		var expected_dvs: int = (
			expected_rng.randi_range(0, 255) << 8
		) | expected_rng.randi_range(0, 255)

		var actual_rng := RandomNumberGenerator.new()
		actual_rng.seed = seed_value
		var prepared: Dictionary = Gen2WorldBattleAdapter.prepare(
			_data, {"values": {"kind": &"wild", "pokemon": SPECIES_TWO, "level": 5}},
			_player_party(), actual_rng
		)
		assert_true(prepared["ok"])
		var wild: Gen2BattleMon = (prepared["battle"] as Gen2Battle).enemy
		assert_eq(wild.item, expected_item)
		assert_eq(wild.dvs, expected_dvs)
		seen[expected_item] = true
		if seen.size() == 3:
			break
	assert_eq(seen.size(), 3, "none, common and rare all occur")


func test_a_force_item_wild_takes_item_one_without_spending_a_roll() -> void:
	var expected_rng := RandomNumberGenerator.new()
	expected_rng.seed = 91
	var expected_dvs: int = (
		expected_rng.randi_range(0, 255) << 8
	) | expected_rng.randi_range(0, 255)
	var actual_rng := RandomNumberGenerator.new()
	actual_rng.seed = 91
	var prepared: Dictionary = Gen2WorldBattleAdapter.prepare(
		_data, {"values": {
			"kind": &"wild", "pokemon": SPECIES_TWO, "level": 5,
			"battle_type": Gen2Battle.BATTLETYPE_FORCEITEM,
		}}, _player_party(), actual_rng
	)
	assert_true(prepared["ok"])
	var wild: Gen2BattleMon = (prepared["battle"] as Gen2Battle).enemy
	assert_eq(wild.item, 17)
	assert_eq(wild.dvs, expected_dvs)


func test_battle_request_carries_the_players_badge_mask() -> void:
	var prepared: Dictionary = Gen2WorldBattleAdapter.prepare(
		_data,
		{"kind": &"battle_requested", "values": {
			"kind": &"wild", "pokemon": SPECIES_TWO, "level": 5,
		}},
		_player_party(), RandomNumberGenerator.new(), 1 << 0
	)
	assert_true(prepared["ok"])
	var battle: Gen2Battle = prepared["battle"]
	assert_eq(battle.player_badge_mask, 1)
	assert_gt(battle.player.stat("attack"), battle.player.stats["attack"])


## LoadEnemyMon's .TreeMon branch: a headbutt encounter whose species is in
## CheckSleepingTreeMon's list for the current time of day enters asleep for
## TREEMON_SLEEP_TURNS. The list question is answered before this boundary,
## since only the caller knows the time of day and the profile.
func test_a_tree_battle_starts_the_wild_asleep_only_when_it_is_told_to() -> void:
	var asleep: Dictionary = Gen2WorldBattleAdapter.prepare(
		_data,
		{"kind": &"battle_requested", "values": {
			"kind": &"wild", "pokemon": SPECIES_TWO, "level": 5,
			"battle_type": Gen2Battle.BATTLETYPE_TREE, "asleep": true,
		}},
		_player_party(), RandomNumberGenerator.new()
	)
	assert_true(asleep["ok"])
	var sleeping: Gen2Battle = asleep["battle"]
	assert_eq(sleeping.battle_type, Gen2Battle.BATTLETYPE_TREE)
	assert_eq(sleeping.enemy.status, Gen2WorldTreemon.SLEEP_TURNS)
	assert_true(Gen2Status.is_asleep(sleeping.enemy.status))

	# A tree battle against an unlisted species, and Gold and Silver's every
	# tree battle, say false and start awake.
	var awake: Dictionary = Gen2WorldBattleAdapter.prepare(
		_data,
		{"kind": &"battle_requested", "values": {
			"kind": &"wild", "pokemon": SPECIES_TWO, "level": 5,
			"battle_type": Gen2Battle.BATTLETYPE_TREE, "asleep": false,
		}},
		_player_party(), RandomNumberGenerator.new()
	)
	assert_true(awake["ok"])
	assert_eq((awake["battle"] as Gen2Battle).enemy.status, Gen2Status.NONE)


func test_trainer_request_uses_the_source_party_and_trainer_battle_rules() -> void:
	var prepared: Dictionary = Gen2WorldBattleAdapter.prepare(
		_data,
		{"kind": &"battle_requested", "values": {
			"kind": &"trainer", "trainer_group": 1, "trainer_id": 0,
		}},
		_player_party(), RandomNumberGenerator.new()
	)
	assert_true(prepared["ok"])
	assert_true(prepared["trainer_battle"])
	assert_eq((prepared["battle"] as Gen2Battle).is_trainer_battle, true)
	assert_eq((prepared["enemy_party"] as Gen2Party).active_mon().species, SPECIES_TWO)


func test_invalid_battle_identifiers_are_structured_failures() -> void:
	var invalid_species: Dictionary = Gen2WorldBattleAdapter.prepare(
		_data,
		{"kind": &"battle_requested", "values": {
			"kind": &"wild", "pokemon": 99, "level": 5,
		}},
		_player_party()
	)
	assert_false(invalid_species["ok"])
	assert_eq(invalid_species["reason"], &"invalid_wild_species")

	var invalid_trainer: Dictionary = Gen2WorldBattleAdapter.prepare(
		_data,
		{"kind": &"battle_requested", "values": {
			"kind": &"trainer", "trainer_group": 1, "trainer_id": 9,
		}},
		_player_party()
	)
	assert_false(invalid_trainer["ok"])
	assert_eq(invalid_trainer["reason"], &"invalid_trainer")


## A visible encounter chose its DVs before the player met it, so the battle is
## built with those four numbers rather than a fresh roll. This is also
## `.Roaming`'s stored word: the caller that has one puts it in the request.
func test_a_wild_request_carries_its_own_dvs_into_the_battle() -> void:
	var shiny: int = Gen2Stats.pack_dvs(2, 10, 10, 10)
	var prepared: Dictionary = Gen2WorldBattleAdapter.prepare(
		_data, {"values": {"kind": &"wild", "pokemon": SPECIES_TWO, "level": 5, "dvs": shiny}},
		_player_party()
	)
	assert_true(bool(prepared["ok"]), String(prepared.get("reason", "")))
	assert_eq((prepared["battle"] as Gen2Battle).enemy.dvs, shiny)
	assert_true(Gen2Stats.is_shiny((prepared["battle"] as Gen2Battle).enemy.dvs))


## `LoadEnemyMon`'s second BATTLETYPE_ROAMING branch: a roamer whose struct has
## been initialised comes back on the HP the last fight left it on rather than on
## a full bar, and a full-bar request is left alone.
func test_a_roamer_returns_on_the_hp_its_struct_carries() -> void:
	var chipped: Dictionary = Gen2WorldBattleAdapter.prepare(
		_data, {"values": {
			"kind": &"wild", "pokemon": SPECIES_TWO, "level": 40,
			"battle_type": Gen2Battle.BATTLETYPE_ROAMING, "hp": 7, "dvs": 0xABCD,
		}},
		_player_party()
	)
	assert_true(bool(chipped["ok"]), String(chipped.get("reason", "")))
	var enemy: Gen2BattleMon = (chipped["battle"] as Gen2Battle).enemy
	assert_eq(enemy.hp, 7)
	assert_eq(enemy.dvs, 0xABCD)
	assert_gt(enemy.max_hp(), 7, "only the current HP is stored")

	var fresh: Dictionary = Gen2WorldBattleAdapter.prepare(
		_data, {"values": {
			"kind": &"wild", "pokemon": SPECIES_TWO, "level": 40,
			"battle_type": Gen2Battle.BATTLETYPE_ROAMING,
		}},
		_player_party()
	)
	assert_true(bool(fresh["ok"]), String(fresh.get("reason", "")))
	var full: Gen2BattleMon = (fresh["battle"] as Gen2Battle).enemy
	assert_eq(full.hp, full.max_hp())


## `LoadEnemyMon`'s `.GenerateDVs`: a wild that carries none is rolled two bytes
## off the BATTLE's own generator rather than handed 15/15/15/15, which is what
## every encounter source but the visible-encounter provider used to get. Off
## that generator and no other, so the same seed meets the same Pokemon.
func test_a_wild_with_no_dvs_is_rolled_off_the_battles_own_generator() -> void:
	var words: Array[int] = []
	for _attempt: int in 2:
		var generator := RandomNumberGenerator.new()
		generator.seed = 20260825
		var run: Array[int] = []
		for _wild: int in 8:
			var prepared: Dictionary = Gen2WorldBattleAdapter.prepare(
				_data, {"values": {"kind": &"wild", "pokemon": SPECIES_TWO, "level": 5}},
				_player_party(), generator
			)
			assert_true(bool(prepared["ok"]), String(prepared.get("reason", "")))
			run.append((prepared["battle"] as Gen2Battle).enemy.dvs)
		if words.is_empty():
			words = run
		else:
			assert_eq(run, words, "the same seed draws the same eight words")
	## Not the perfect word, and not one word eight times: the point of the roll.
	assert_false(words.all(func(word: int) -> bool:
		return word == Gen2BattleMon.PERFECT_DVS
	), "no wild is perfect any more")
	assert_gt(words.reduce(func(seen: Dictionary, word: int) -> Dictionary:
		seen[word] = true
		return seen
	, {}).size(), 1, "eight rolls are not one number")


## `.NotRoaming`'s forced-shiny branch, which writes `ATKDEFDV_SHINY` and
## `SPDSPCDV_SHINY` rather than rolling. This is the red Gyarados, and nothing
## read the battle type for its DVs before.
func test_a_forced_shiny_wild_is_shiny() -> void:
	var generator := RandomNumberGenerator.new()
	generator.seed = 7
	var prepared: Dictionary = Gen2WorldBattleAdapter.prepare(
		_data, {"values": {
			"kind": &"wild", "pokemon": SPECIES_TWO, "level": 30,
			"battle_type": Gen2Battle.BATTLETYPE_FORCESHINY,
		}}, _player_party(), generator
	)
	assert_true(bool(prepared["ok"]), String(prepared.get("reason", "")))
	assert_eq((prepared["battle"] as Gen2Battle).enemy.dvs, Gen2Stats.SHINY_DVS)
	assert_true(Gen2Stats.is_shiny((prepared["battle"] as Gen2Battle).enemy.dvs))


## `register_shiny_rolls`: the host draws up to the count the provider asks for
## and keeps the first shiny word, so a charmed run meets one far sooner than
## 1 in 8192. Measured rather than asserted on one wild, since a single roll
## proves nothing about a count.
func test_a_shiny_rolls_provider_draws_more_words_per_wild() -> void:
	var vanilla: int = _shiny_wilds(64)
	Gen2ModHost.instance().register_shiny_rolls(&"test_charm", ShinyRollsStub.new())
	var charmed: int = _shiny_wilds(64)
	Gen2ModHost.reset()
	## The stub asks for more than MAX_SHINY_ROLLS, so the host draws its own
	## ceiling of 1024: one wild in eight, and about eight shinies over 64. One
	## roll a wild is one in 8192, so vanilla's 64 find none in almost every run.
	assert_eq(vanilla, 0, "one roll a wild finds no shiny in 64")
	assert_gt(charmed, 0, "1024 rolls a wild does")


## A wild UNOWN rerolls while its letter is locked, which is `CheckUnownLetter`'s
## `jr c, .GenerateDVs`. The mask is the save's `wUnlockedUnowns` and reaches
## here on the request, since the adapter has no save.
func test_a_wild_unown_only_takes_an_unlocked_letter() -> void:
	## The roll rather than a whole battle: this cartridge-free suite has no
	## UNOWN to build a party member out of, and the gate is in the word.
	var generator := RandomNumberGenerator.new()
	generator.seed = 99
	for _wild: int in 32:
		## X-Z alone, the last set and the smallest.
		var word: int = Gen2WorldBattleAdapter.wild_dvs(
			{"unlocked_unowns": 0b1000}, Gen2Battle.BATTLETYPE_NORMAL,
			Gen2Layout.UNOWN_SPECIES, generator
		)
		var letter: int = Gen2Stats.unown_letter(word)
		assert_true(letter in [24, 25, 26], "letter %d is not in X-Z" % letter)
	## No mask stamped is no gate, which is every caller that is not the world
	## screen: the letters it draws are not all in one set.
	var ungated: Dictionary = {}
	for _wild: int in 32:
		ungated[Gen2Stats.unown_letter(Gen2WorldBattleAdapter.wild_dvs(
			{}, Gen2Battle.BATTLETYPE_NORMAL, Gen2Layout.UNOWN_SPECIES, generator
		))] = true
	assert_gt(ungated.size(), 3, "an ungated roll reaches past one set")


## `LoadEnemyMon.CheckMagikarpArea` floors a wild Magikarp's length outside Lake
## of Rage: three rolls in five reroll anything under four feet. Inside the group
## the filter is skipped, so the same seed keeps its short ones.
func test_a_wild_magikarp_is_floored_outside_lake_of_rage() -> void:
	assert_lt(
		_short_magikarp({"map_group": 5, "map_number": 3}),
		_short_magikarp({
			"map_group": Gen2WorldBattleAdapter.GROUP_LAKE_OF_RAGE, "map_number": 6,
		}),
		"the floor drops short Magikarp only outside the lake"
	)
	## The pair of `cp`s is an OR, so a map numbered 6 in any group skips it too.
	assert_eq(
		_short_magikarp({"map_group": 5, "map_number": Gen2WorldBattleAdapter.MAP_LAKE_OF_RAGE}),
		_short_magikarp({
			"map_group": Gen2WorldBattleAdapter.GROUP_LAKE_OF_RAGE, "map_number": 6,
		}),
		"map number 6 skips the floor in every group"
	)


## How many of 200 rolled wild Magikarp came out under four feet, off one seeded
## generator so each map answers the same sequence.
func _short_magikarp(values: Dictionary) -> int:
	var generator := RandomNumberGenerator.new()
	generator.seed = 1234
	var request: Dictionary = values.duplicate()
	request["player_id"] = 0x1234
	var short: int = 0
	for _wild: int in 200:
		var word: int = Gen2WorldBattleAdapter.wild_dvs(
			request, Gen2Battle.BATTLETYPE_NORMAL,
			Gen2WorldPartyHost.SPECIES_MAGIKARP, generator
		)
		var length: Vector2i = Gen2WorldPartyHost.magikarp_length(
			PackedByteArray([(word >> 8) & 0xFF, word & 0xFF]), 0x1234
		)
		if length.x < Gen2WorldBattleAdapter.MAGIKARP_FLOOR_FEET:
			short += 1
	return short


## How many of [param count] rolled wilds came out shiny, off one seeded
## generator so the two halves of the test above draw the same sequence.
func _shiny_wilds(count: int) -> int:
	var generator := RandomNumberGenerator.new()
	generator.seed = 4242
	var shinies: int = 0
	for _wild: int in count:
		var prepared: Dictionary = Gen2WorldBattleAdapter.prepare(
			_data, {"values": {"kind": &"wild", "pokemon": SPECIES_TWO, "level": 5}},
			_player_party(), generator
		)
		if Gen2Stats.is_shiny((prepared["battle"] as Gen2Battle).enemy.dvs):
			shinies += 1
	return shinies


class ShinyRollsStub:
	extends RefCounted

	func shiny_rolls(_context: Dictionary) -> int:
		return 4096


## `PlayBattleMusic` runs in front of `DoBattleTransition`, so the track has to
## be answerable from the request alone, before a battle exists to read. It is
## the same answer `Gen2Battle.battle_music` gives the prepared fight, which is
## what lets the driver continue the piece rather than restart it behind the
## transition.
func test_the_battle_track_is_answerable_from_the_request_alone() -> void:
	var wild: Dictionary = {"values": {"kind": &"wild", "pokemon": SPECIES_TWO, "level": 5}}
	assert_eq(
		Gen2WorldBattleAdapter.music_for(wild, Gen2Battle.LANDMARK_NONE, Gen2WorldPalette.TIME_DAY),
		Gen2Battle.battle_music(
			Gen2Battle.BATTLETYPE_NORMAL, 0, 0,
			Gen2Battle.LANDMARK_NONE, Gen2WorldPalette.TIME_DAY
		)
	)
	## A trainer's own two numbers are the request's, and a wild request holding
	## neither must not be read as trainer class 0's row by accident.
	var leader: Dictionary = {"values": {
		"kind": &"trainer",
		"trainer_group": Gen2Battle.TRAINER_CLASS_CHAMPION,
		"trainer_id": 1,
	}}
	assert_eq(
		Gen2WorldBattleAdapter.music_for(
			leader, Gen2Battle.LANDMARK_NONE, Gen2WorldPalette.TIME_DAY
		),
		Gen2Battle.MUSIC_CHAMPION_BATTLE
	)
	## `BATTLETYPE_SUICUNE` sits in front of both compares, so it wins over the
	## class the request also carries.
	var roaming: Dictionary = {"values": {
		"kind": &"wild", "pokemon": SPECIES_TWO, "level": 5,
		"battle_type": Gen2Battle.BATTLETYPE_ROAMING,
	}}
	assert_eq(
		Gen2WorldBattleAdapter.music_for(
			roaming, Gen2Battle.LANDMARK_NONE, Gen2WorldPalette.TIME_NIGHT
		),
		Gen2Battle.MUSIC_SUICUNE_BATTLE
	)
	assert_eq(
		Gen2WorldBattleAdapter.music_for(
			{"values": 5}, Gen2Battle.LANDMARK_NONE, Gen2WorldPalette.TIME_DAY
		),
		Gen2Battle.MUSIC_NONE
	)


## `InitEnemyTrainer` and `ComputeTrainerReward` belong to preparing the
## opponent, so a host that answers a fight without drawing it gets the same
## reward the battle screen would. 25 times the last member's level of 5.
func test_a_prepared_trainer_carries_its_reward() -> void:
	var prepared: Dictionary = Gen2WorldBattleAdapter.prepare(
		_data,
		{"kind": &"battle_requested", "values": {
			"kind": &"trainer", "trainer_group": 1, "trainer_id": 0,
		}},
		_player_party(), RandomNumberGenerator.new()
	)
	assert_true(prepared["ok"])
	assert_eq((prepared["battle"] as Gen2Battle).battle_reward, 125)


## `.give_money`'s four quarters and `CheckPayDay`'s coins as one credit per
## account, which is the whole of what a won battle pays.
func test_earnings_credit_the_wallet_with_the_prize_and_the_coins() -> void:
	var prepared: Dictionary = Gen2WorldBattleAdapter.prepare(
		_data,
		{"kind": &"battle_requested", "values": {
			"kind": &"trainer", "trainer_group": 1, "trainer_id": 0,
		}},
		_player_party(), RandomNumberGenerator.new()
	)
	var battle: Gen2Battle = prepared["battle"]
	battle.pay_day_money = 40
	var earned: Dictionary = Gen2WorldBattleAdapter.earnings(battle, null, true)
	assert_eq(
		int((earned["money"] as Dictionary)[Gen2WorldScriptRunner.ACCOUNT_YOUR_MONEY]), 540
	)
	assert_eq(int(earned["prize_shown"]), 500)
	assert_eq(int(earned["pay_day"]), 40)
	assert_eq(StringName(earned["prize_line"]), Gen2Battle.PRIZE_KEPT_IT_ALL)

	## `CheckAmuletCoin`'s one flag doubles both.
	battle.amulet_coin = true
	var doubled: Dictionary = Gen2WorldBattleAdapter.earnings(battle, null, true)
	assert_eq(
		int((doubled["money"] as Dictionary)[Gen2WorldScriptRunner.ACCOUNT_YOUR_MONEY]), 1080
	)
	assert_eq(int(doubled["pay_day"]), 80)


## A loss, a draw and a run all reach `and $f / ret nz` and pay nothing.
func test_a_battle_that_was_not_won_pays_nothing() -> void:
	var prepared: Dictionary = Gen2WorldBattleAdapter.prepare(
		_data,
		{"kind": &"battle_requested", "values": {
			"kind": &"trainer", "trainer_group": 1, "trainer_id": 0,
		}},
		_player_party(), RandomNumberGenerator.new()
	)
	var battle: Gen2Battle = prepared["battle"]
	battle.pay_day_money = 40
	assert_true(
		(Gen2WorldBattleAdapter.earnings(battle, null, false)["money"] as Dictionary).is_empty()
	)


func test_tower_preparation_heals_even_a_wiped_party_before_choosing_the_lead() -> void:
	var party: Gen2Party = _player_party()
	var lead: Gen2BattleMon = party.at(0)
	lead.hp = 0
	lead.status = Gen2Status.POISON
	lead.pp[0] = 0
	var enemy: Dictionary = Gen2SaveBattleAdapter.from_battle_mon(_player_party().at(0)).to_dict()
	enemy["battle_stats"] = {
		"hp": 40, "attack": 23, "defense": 22, "speed": 21, "sp_attack": 20, "sp_defense": 19,
	}
	enemy["hp"] = 40
	var prepared: Dictionary = Gen2WorldBattleAdapter.prepare(_data, {"values": {
		"kind": &"battle_tower", "enemy_party": [enemy],
	}}, party)
	assert_true(prepared["ok"])
	assert_eq(lead.hp, lead.max_hp())
	assert_eq(lead.status, Gen2Status.NONE)
	assert_eq(lead.pp_left(0), 35)
	assert_eq((prepared["battle"] as Gen2Battle).enemy.stats, enemy["battle_stats"])
	assert_eq((prepared["battle"] as Gen2Battle).enemy.hp, 40)
	assert_true(prepared["trainer_battle"])
