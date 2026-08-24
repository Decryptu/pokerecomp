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

	match kind:
		&"wild":
			var species: int = int(values.get("pokemon", 0))
			var level: int = int(values.get("level", 0))
			if not _valid_species(data, species):
				return _failure(&"invalid_wild_species", {"species": species})
			if level < 1 or level > Gen2Experience.MAX_LEVEL:
				return _failure(&"invalid_wild_level", {"level": level})
			# `LoadEnemyMon` rolls `wEnemyMonDVs` unless the caller already has
			# them; a visible encounter chose its own before the player met it,
			# and shininess is a fact about those four numbers alone.
			var wild_mon: Gen2BattleMon = Gen2BattleMon.create(
				data, species, level, data.moves_at_level(species, level),
				int(values.get("dvs", Gen2BattleMon.PERFECT_DVS))
			)
			# LoadEnemyMon's .TreeMon branch: a headbutt encounter whose species
			# is in CheckSleepingTreeMon's list for the current time of day
			# enters asleep for TREEMON_SLEEP_TURNS. The caller answers the list
			# question, since only it knows the time of day and the profile;
			# Gold and Silver never say true, having neither routine nor data.
			if wild_mon != null and bool(values.get("asleep", false)):
				wild_mon.status = Gen2WorldTreemon.SLEEP_TURNS
			enemy_party = Gen2Party.of(wild_mon)
		&"trainer":
			trainer_class = int(values.get("trainer_group", 0))
			trainer_index = int(values.get("trainer_id", 0))
			enemy_party = Gen2TrainerParty.build(data, trainer_class, trainer_index)
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
	var generator := random if random != null else RandomNumberGenerator.new()
	var battle: Gen2Battle = Gen2Battle.create_parties(
		data, player_party, enemy_party, generator,
		kind in [&"trainer", &"battle_tower", &"link_battle"], player_badges, battle_rules
	)
	if battle == null:
		return _failure(&"battle_setup_failed")
	# wBattleType, which a `loadvar VAR_BATTLETYPE` before `startbattle` sets.
	# Running is the only thing that reads it so far, and four of its values are
	# what make Celebi, Suicune and the Rocket trap battles inescapable.
	battle.battle_type = int(values.get("battle_type", Gen2Battle.BATTLETYPE_NORMAL))

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
