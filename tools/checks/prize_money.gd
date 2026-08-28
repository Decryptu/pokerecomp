extends RefCounted

var _r: RefCounted = null

## Verifies what a beaten trainer pays, against freshly imported real caches, on
## all three cartridges. Two halves. `TrainerClassAttributes`' base rewards are
## transcribed below from the pinned `data/trainers/attributes.asm` rather than read
## back out of the cache, so an importer that shifted a row by a byte goes red. Then
## every individual trainer in the corpus is walked through the seam a battle uses,
## and what comes out is checked against the arithmetic the source spells: four
## quarters of base times the last member's level, doubled by the Amulet Coin,
## split with Mom whole.

## `data/trainers/attributes.asm`, in class order from FALKNER. Gold and Silver
## are the first 66 of these; Crystal adds MYSTICALMAN, the 67th, and the rows
## in front of it are identical between the two pins.
const BASE_REWARDS: Array[int] = [
	25, 25, 25, 25, 25, 25, 25, 25, 15, 25, 25, 25, 25, 25, 25, 25, 25,
	25, 25, 25, 25, 4, 8, 6, 6, 25, 12, 12, 22, 15, 10, 18, 18, 18, 25,
	4, 10, 2, 5, 10, 8, 25, 8, 8, 8, 25, 22, 12, 10, 6, 18, 8, 5, 5, 18,
	8, 10, 18, 20, 18, 5, 20, 25, 25, 10, 10, 25,
]
const CRYSTAL_CLASSES: int = 67
const GOLD_CLASSES: int = 66

## `MAX_MONEY`, which `AddBattleMoneyToAccount` caps every account at.
const MAX_MONEY: int = 999999


func run(r: RefCounted) -> void:
	_r = r
	for game_id: StringName in _r.GAME_IDS:
		var data: GameData = GameData.open(game_id)
		if data == null:
			_r.fail("%s cache is unavailable. Import roms/%s.gbc first." % [game_id, game_id])
			continue
		_r.game_id = game_id
		if not _verify_base_rewards(game_id, data):
			continue
		_verify_prizes(game_id, data)
	_r.game_id = &""


## The transcribed table against the imported one, row for row.
func _verify_base_rewards(game_id: StringName, data: GameData) -> bool:
	var expected: int = CRYSTAL_CLASSES if game_id == &"crystal" else GOLD_CLASSES
	if not _r.check(
		data.trainer_count() == expected,
		"%s: %d trainer classes, expected %d." % [game_id, data.trainer_count(), expected]
	):
		return false
	for trainer_class: int in range(1, expected + 1):
		var reward: int = int(
			data.trainer_attributes(trainer_class).get("base_reward", -1)
		)
		if not _r.check(
			reward == BASE_REWARDS[trainer_class - 1],
			"%s: class %d pays a base of %d, expected %d." % [
				game_id, trainer_class, reward, BASE_REWARDS[trainer_class - 1]
			]
		):
			return false
	return true


## Every individual trainer on the cartridge through the whole seam.
func _verify_prizes(game_id: StringName, data: GameData) -> void:
	var walked: int = 0
	var biggest: int = 0
	for trainer_class: int in range(1, data.trainer_count() + 1):
		var base: int = int(data.trainer_attributes(trainer_class).get("base_reward", 0))
		for index: int in data.trainer_party_count(trainer_class):
			var party: Gen2Party = Gen2TrainerParty.build(data, trainer_class, index)
			if not _r.check(
				party != null and not party.mons.is_empty(),
				"%s: class %d trainer %d builds no party." % [game_id, trainer_class, index]
			):
				return
			var last: Gen2BattleMon = party.mons[party.mons.size() - 1]
			var quarter: int = base * last.level
			## `Multiply`'s product is read two bytes wide, so a reward that
			## needed three would truncate. The corpus must never reach it.
			if not _r.check(
				quarter <= 0xFFFF,
				"%s: class %d trainer %d is worth %d, past two bytes." % [
					game_id, trainer_class, index, quarter
				]
			):
				return
			var plain: Dictionary = Gen2Battle.prize_money_split(
				quarter, false, 0, 0, MAX_MONEY
			)
			if not _r.check(
				int(plain["wallet"]) == quarter * 4 and int(plain["mom"]) == 0
					and int(plain["shown"]) == quarter * 4
					and StringName(plain["line"]) == Gen2Battle.PRIZE_KEPT_IT_ALL,
				"%s: class %d trainer %d pays %s, expected %d whole." % [
					game_id, trainer_class, index, plain, quarter * 4
				]
			):
				return
			## The Amulet Coin doubles the quarter before it is handed out, so
			## the whole prize and the printed figure both double.
			var doubled: Dictionary = Gen2Battle.prize_money_split(
				quarter, true, 0, 0, MAX_MONEY
			)
			if not _r.check(
				int(doubled["wallet"]) == quarter * 8
					and int(doubled["shown"]) == quarter * 8,
				"%s: class %d trainer %d doubles to %s." % [
					game_id, trainer_class, index, doubled
				]
			):
				return
			## `.loop`/`.loop2` hand out four quarters between them however the
			## savings bits fall, so nothing is ever lost or minted.
			for saving: int in [0, 1, 2, 3]:
				var split: Dictionary = Gen2Battle.prize_money_split(
					quarter, false,
					Gen2WorldScriptRunner.MOM_ACTIVE | saving, 0, MAX_MONEY
				)
				if not _r.check(
					int(split["wallet"]) + int(split["mom"]) == quarter * 4,
					"%s: class %d trainer %d loses money at tier %d: %s." % [
						game_id, trainer_class, index, saving, split
					]
				):
					return
			walked += 1
			biggest = maxi(biggest, quarter * 8)
	_r.note("%s: %d trainers, the richest worth ¥%d." % [game_id, walked, biggest])
