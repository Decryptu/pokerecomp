class_name Gen2WorldBattleAdapter
extends RefCounted

## Scene-free preparation of the battle requests emitted by the overworld
## script runner. The battle screen owns presentation and input; this boundary
## only validates source identifiers and builds the existing battle model.

const OUTCOME_WON: StringName = &"won"
const OUTCOME_LOST: StringName = &"lost"
const OUTCOME_CAUGHT: StringName = &"caught"
const OUTCOME_RAN: StringName = &"ran"
const OUTCOME_CANCELLED: StringName = &"cancelled"

## `CheckMagikarpArea`'s two `cp`s, the same numbers in both pins.
const GROUP_LAKE_OF_RAGE: int = 9
const MAP_LAKE_OF_RAGE: int = 6
## `HIGH(1536)`, `LOW(1616)`, `LOW(1600)` and `HIGH(1024)`, all read against a
## length in feet and inches: the unit-conversion entry in the bug docs.
const MAGIKARP_HUGE_FEET: int = 6
const MAGIKARP_HUGE_INCHES: int = 80
const MAGIKARP_LARGE_INCHES: int = 64
const MAGIKARP_FLOOR_FEET: int = 4
const MAGIKARP_HUGE_SKIP: int = 12
const MAGIKARP_LARGE_SKIP: int = 50
const MAGIKARP_FLOOR_SKIP: int = 100


static func prepare(
	data: GameData,
	request: Dictionary,
	player_party: Gen2Party,
	random: RandomNumberGenerator = null,
	player_badges: int = 0,
	battle_rules: Gen2Rules = null,
) -> Dictionary:
	if data == null or player_party == null or player_party.is_wiped():
		return _failure(&"missing_player_party")

	var raw_values: Variant = request.get("values", request)
	if not raw_values is Dictionary:
		return _failure(&"invalid_battle_request")
	var values: Dictionary = (raw_values as Dictionary).duplicate(true)
	var kind: StringName = StringName(values.get("kind", &""))
	var enemy_party: Gen2Party = null
	var trainer_class: int = 0
	var trainer_index: int = 0
	# wBattleType, which a `loadvar VAR_BATTLETYPE` before `startbattle` sets.
	# Read before the party is built, since `LoadEnemyMon` branches a wild's DVs
	# on it. Running is the only other thing that reads it so far, and four of
	# its values are what make Celebi, Suicune and the Rocket trap battles
	# inescapable.
	var battle_type: int = int(values.get("battle_type", Gen2Battle.BATTLETYPE_NORMAL))
	# `BattleRandom`, so a wild's DVs come out of the run's own sequence and a
	# replay of the same seed meets the same Pokemon.
	var generator := random if random != null else RandomNumberGenerator.new()

	match kind:
		&"wild":
			var wild: Dictionary = _wild_party(data, values, battle_type, generator)
			if not wild["ok"]:
				return wild
			enemy_party = wild["party"]
		&"trainer":
			trainer_class = int(values.get("trainer_group", 0))
			trainer_index = int(values.get("trainer_id", 0))
			enemy_party = Gen2TrainerParty.build(
				data, trainer_class, trainer_index, battle_rules
			)
			if enemy_party == null:
				return _failure(&"invalid_trainer", {
					"trainer_class": trainer_class, "trainer_index": trainer_index,
				})
		&"battle_tower", &"link_battle":
			## `ReadBTTrainerParty` copies a whole `wOTPartyMon` block out of the
			## sampled record rather than building one from a trainer table, so
			## the party arrives with the request and nothing is rolled here.
			## A link battle is the same shape one caller further out:
			## `Link_PrepPartyData_Gen2` sends whole party structs and the other
			## Game Boy's arrive the same way, with no trainer class behind them.
			trainer_class = int(values.get("trainer_class", 0))
			var members: Array = []
			for raw_mon: Variant in values.get("enemy_party", []) as Array:
				var saved: Gen2SaveMon = Gen2SaveMon.from_dict(raw_mon)
				var member: Gen2BattleMon = Gen2SaveBattleAdapter.to_battle_mon(data, saved)
				if member == null:
					return _failure(&"invalid_battle_tower_mon", {"mon": raw_mon})
				members.append(member)
			enemy_party = Gen2Party.create(members)
		_:
			return _failure(&"unsupported_battle_kind", {"kind": kind})

	if enemy_party == null or enemy_party.is_wiped():
		return _failure(&"missing_enemy_party")
	## `BadgeStatBoosts` and `DoBadgeTypeBoosts` both `ret nz` on `wLinkMode` and
	## on `wInBattleTowerBattle`: no badge bonus outside a single-player fight.
	var badges: int = 0 if kind in [&"battle_tower", &"link_battle"] else player_badges
	var battle: Gen2Battle = Gen2Battle.create_parties(
		data, player_party, enemy_party, generator,
		kind in [&"trainer", &"battle_tower", &"link_battle"], badges, battle_rules
	)
	if battle == null:
		return _failure(&"battle_setup_failed")
	battle.battle_type = battle_type
	## `InitEnemyTrainer` belongs to setting the opponent up rather than to
	## whoever draws the fight, so every host gets the class's two items, its
	## gym-leader happiness and `ComputeTrainerReward` from one place. Only a
	## `kind` of `trainer` reaches `ComputeTrainerReward`: `ReadTrainerParty`
	## returns in front of it for the Battle Tower and for a link partner.
	if trainer_class > 0:
		battle.init_enemy_trainer(trainer_class, kind == &"trainer")

	return {
		"ok": true,
		"request": values,
		"battle": battle,
		"player_party": player_party,
		"enemy_party": enemy_party,
		"trainer_class": trainer_class,
		"trainer_index": trainer_index,
		"trainer_battle": kind == &"trainer",
	}


## `LoadEnemyMon` for a wild, on the run's own generator.
static func _wild_party(
	data: GameData, values: Dictionary, battle_type: int,
	generator: RandomNumberGenerator
) -> Dictionary:
	var species: int = int(values.get("pokemon", 0))
	var level: int = int(values.get("level", 0))
	if not _valid_species(data, species):
		return _failure(&"invalid_wild_species", {"species": species})
	if level < 1 or level > Gen2Experience.MAX_LEVEL:
		return _failure(&"invalid_wild_level", {"level": level})
	var wild_mon: Gen2BattleMon = Gen2BattleMon.create(
		data, species, level, data.moves_at_level(species, level),
		wild_dvs(values, battle_type, species, generator)
	)
	# LoadEnemyMon's .TreeMon branch: a headbutt encounter whose species is in
	# CheckSleepingTreeMon's list for the current time of day enters asleep for
	# TREEMON_SLEEP_TURNS. The caller answers the list question, since only it
	# knows the time of day and the profile; Gold and Silver never say true,
	# having neither routine nor data.
	if wild_mon != null and bool(values.get("asleep", false)):
		wild_mon.status = Gen2WorldTreemon.SLEEP_TURNS
	## `LoadEnemyMon`'s second `BATTLETYPE_ROAMING` branch: a roamer whose struct
	## has been initialised comes back on the stored HP rather than on a full bar,
	## which is what makes chipping one down between encounters worth doing. The
	## uninitialised case carries no `hp` and keeps the stats it was just built
	## with.
	if wild_mon != null and int(values.get("hp", 0)) > 0:
		wild_mon.hp = clampi(int(values["hp"]), 1, wild_mon.max_hp())
	return {"ok": true, "party": Gen2Party.of(wild_mon)}


static func earnings(battle: Gen2Battle, state: Gen2WorldState, won: bool) -> Dictionary:
	var result: Dictionary = {
		"money": {}, "prize_shown": 0, "prize_line": &"", "pay_day": 0,
	}
	if battle == null or not won:
		return result
	var wallet: int = 0
	var to_mom: int = 0
	if battle.battle_reward > 0:
		var split: Dictionary = Gen2Battle.prize_money_split(
			battle.battle_reward,
			battle.amulet_coin,
			state.mom_savings_flags() if state != null else 0,
			state.money(Gen2WorldScriptRunner.ACCOUNT_MOMS_MONEY) if state != null else 0,
			Gen2WorldInventory.MAX_MONEY,
		)
		wallet += int(split["wallet"])
		to_mom += int(split["mom"])
		result["prize_shown"] = int(split["shown"])
		result["prize_line"] = split["line"]
	## `CheckPayDay` doubles the coins with the same Amulet Coin the prize used,
	## and does it whether or not there was a trainer to pay a prize.
	if battle.pay_day_money > 0:
		var coins: int = battle.pay_day_money
		if battle.amulet_coin:
			coins = Gen2Battle.double_reward(coins)
		result["pay_day"] = coins
		wallet += coins
	if wallet > 0:
		(result["money"] as Dictionary)[Gen2WorldScriptRunner.ACCOUNT_YOUR_MONEY] = wallet
	if to_mom > 0:
		(result["money"] as Dictionary)[Gen2WorldScriptRunner.ACCOUNT_MOMS_MONEY] = to_mom
	return result


## `AddBattleMoneyToAccount`, which caps each account at `MAX_MONEY` on its own.
## [param money] is [method earnings]' own dictionary.
static func credit_earnings(state: Gen2WorldState, money: Dictionary) -> void:
	if state == null or money.is_empty():
		return
	var balances: Dictionary = {}
	for account: int in money:
		balances[account] = mini(
			state.money(account) + int(money[account]), Gen2WorldInventory.MAX_MONEY
		)
	state.apply_changes({}, {}, {"money": balances})


## `LoadEnemyMon`'s `.InitDVs` for a wild, which decides whether the Pokemon in
## the grass is shiny, has a bad stat or answers a different Hidden Power. Rolled
## here rather than in each of the nine callers, on the battle's own generator.
## Two cases keep an answer of their own, in the source's order: a request
## carrying `dvs` keeps it, and BATTLETYPE_FORCESHINY writes the shiny word.
static func wild_dvs(
	values: Dictionary, battle_type: int, species: int, generator: RandomNumberGenerator
) -> int:
	if values.has("dvs"):
		return int(values["dvs"])
	if battle_type == Gen2Battle.BATTLETYPE_FORCESHINY:
		return Gen2Stats.SHINY_DVS
	var rolls: int = Gen2ModHost.shiny_roll_count({
		"species": species,
		"level": int(values.get("level", 0)),
		"method": StringName(values.get("method", &"")),
		"map_group": int(values.get("map_group", -1)),
		"map_number": int(values.get("map_number", -1)),
	})
	## -1 is an unstamped request: no gate, so a preview tool or a test keeps the
	## letter it rolled.
	var unlocked: int = int(values.get("unlocked_unowns", -1))
	var word: int = _roll_dvs(generator, species, unlocked, values)
	## The charm's extra rolls sit past the source, which takes one: the first
	## shiny is kept and otherwise the last stands, so 0 and 1 are both vanilla.
	for _extra: int in maxi(0, rolls - 1):
		if Gen2Stats.is_shiny(word):
			break
		word = _roll_dvs(generator, species, unlocked, values)
	return word


## Two `BattleRandom` bytes, high byte first, rerolled while `CheckUnownLetter`
## or the Magikarp filters refuse them. Unbounded the way the source's is, and
## safe for the same reason: the mask is narrowed to the four real sets, every
## one holds letters, and a wild Unown is refused outright on an empty mask.
static func _roll_dvs(
	generator: RandomNumberGenerator, species: int, unlocked_unowns: int,
	values: Dictionary = {}
) -> int:
	var gated: bool = species == RomLayout.UNOWN_SPECIES and unlocked_unowns > 0
	var mask: int = unlocked_unowns & ((1 << Gen2WorldState.UNOWN_LETTER_SETS.size()) - 1)
	while true:
		var word: int = (generator.randi_range(0, 255) << 8) | generator.randi_range(0, 255)
		if gated and mask != 0 \
			and not Gen2WorldState.unown_letter_unlocked(Gen2Stats.unown_letter(word), mask):
			continue
		if _magikarp_accepted(word, species, generator, values):
			return word
	return 0


## `LoadEnemyMon.Magikarp` and `.CheckMagikarpArea`, which make a very long wild
## Magikarp rarer and a short one rarer still. False is `jr .GenerateDVs`.
static func _magikarp_accepted(
	dvs: int, species: int, generator: RandomNumberGenerator, values: Dictionary
) -> bool:
	if species != Gen2WorldPartyHost.SPECIES_MAGIKARP:
		return true
	var length: Vector2i = Gen2WorldPartyHost.magikarp_length(
		PackedByteArray([(dvs >> 8) & 0xFF, dvs & 0xFF]),
		int(values.get("player_id", 0))
	)
	if length.x == MAGIKARP_HUGE_FEET \
		and generator.randi_range(0, 255) >= MAGIKARP_HUGE_SKIP:
		if length.y >= MAGIKARP_HUGE_INCHES:
			return false
		if generator.randi_range(0, 255) >= MAGIKARP_LARGE_SKIP \
			and length.y >= MAGIKARP_LARGE_INCHES:
			return false
	if int(values.get("map_group", -1)) == GROUP_LAKE_OF_RAGE \
		or int(values.get("map_number", -1)) == MAP_LAKE_OF_RAGE:
		return true
	if generator.randi_range(0, 255) < MAGIKARP_FLOOR_SKIP:
		return true
	return length.x >= MAGIKARP_FLOOR_FEET


## `PlayBattleMusic`'s track, off the request alone.
##
## `FindFirstAliveMonAndStartBattle` runs `PlayBattleMusic` in front of
## `DoBattleTransition`, so the piece starts before the fight is built: the
## world screen asks here when the transition opens and the battle screen asks
## again for the same track, which the driver continues rather than restarts.
## Both read the one request, so neither can pick a different piece.
static func music_for(
	request: Dictionary, landmark_id: int, day_period: int, crystal: bool = true
) -> int:
	var raw: Variant = request.get("values", request)
	if not raw is Dictionary:
		return Gen2Battle.MUSIC_NONE
	var values: Dictionary = raw as Dictionary
	var trainer: bool = StringName(values.get("kind", &"")) == &"trainer"
	return Gen2Battle.battle_music(
		int(values.get("battle_type", Gen2Battle.BATTLETYPE_NORMAL)),
		int(values.get("trainer_group", 0)) if trainer else 0,
		int(values.get("trainer_id", 0)) if trainer else 0,
		landmark_id, day_period, crystal,
	)


static func fallback_party(
	data: GameData, first_species: int = 155, level: int = 5, size: int = 2
) -> Gen2Party:
	if data == null or data.species_count() <= 0 or size < 1 or size > Gen2Party.MAX_SIZE:
		return null
	var members: Array = []
	for offset: int in size:
		var species: int = wrapi(first_species + offset, 1, data.species_count() + 1)
		members.append(
			Gen2BattleMon.create(data, species, level, data.moves_at_level(species, level))
		)
	return Gen2Party.create(members)


static func _valid_species(data: GameData, species: int) -> bool:
	return species > 0 and not data.species(species).is_empty()


static func _failure(reason: StringName, details: Dictionary = {}) -> Dictionary:
	return {"ok": false, "reason": reason, "details": details.duplicate(true)}
