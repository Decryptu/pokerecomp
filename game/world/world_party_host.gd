class_name Gen2WorldPartyHost
extends RefCounted

## Scene-free transactions for party-owned overworld operations.
##
## A script can stage world changes and then pause for a gift, egg or NPC trade.
## The host builds a candidate save first, resumes the script, and only writes
## the candidate after both sides have succeeded. The six-party limit is
## deliberate until the save model has a real PC-box owner.

## `CAUGHT_EGG_LEVEL`: a hatchling's caught level is 1 whatever level it hatches
## at, so the stats page shows the egg rather than the hatch.
const CAUGHT_EGG_LEVEL: int = 1
## `HatchEggs`' own `ld [hl], $78`, the happiness a hatchling starts on.
const HATCHED_HAPPINESS: int = 0x78
## `LANDMARK_GIFT`, the landmark `SetGiftMonCaughtData` writes instead of a map.
const LANDMARK_GIFT: int = 0x7E
## `LANDMARK_NATIONAL_PARK`, which `CheckPartyFullAfterContest` writes over
## whatever `SetCaughtData` read off the map the results are collected on.
const LANDMARK_NATIONAL_PARK: int = 13

## `CheckPartyFullAfterContest`'s own three answers.
const BUGCONTEST_CAUGHT_MON: int = 0
const BUGCONTEST_BOXED_MON: int = 1
const BUGCONTEST_NO_CATCH: int = 2
## `HatchEggs`' own `cp TOGEPI`, the one species whose hatch sets an event flag.
const SPECIES_TOGEPI: int = 0xAF
const EVENT_TOGEPI_HATCHED: int = 84

const ITEM_POTION: int = 0x12
const ITEM_REVIVE: int = 0x27
const ITEM_MAX_REVIVE: int = 0x28
const ITEM_REVIVAL_HERB: int = 0x7C
const ITEM_REPEL: int = 0x14
const ITEM_SUPER_REPEL: int = 0x2A
const ITEM_MAX_REPEL: int = 0x2B
const ITEM_MASTER_BALL: int = 0x01
const ITEM_ULTRA_BALL: int = 0x02
const ITEM_GREAT_BALL: int = 0x04
const ITEM_POKE_BALL: int = 0x05
## The Bug Contest's own ball. It is never in the bag: `wParkBallsRemaining` is
## what holds it and `BattleMenu_Pack`'s contest branch loads it by name.
const ITEM_PARK_BALL: int = 0xB1
## `ConvertBerriesToBerryJuice`'s own three constants.
## `StatExpItemPointerOffsets`: the five vitamins and the stat experience each
## one raises. `MON_HP_EXP` and its four neighbours are words and the offsets
## name the high byte, so `VitaminEffect` reads and writes that byte alone: it
## refuses at 100 and adds 10 there, which is 25,600 and 2,560 of the flat value
## kept here.
const VITAMINS: Dictionary = {
	0x1A: "hp", 0x1B: "attack", 0x1C: "defense", 0x1D: "speed", 0x1F: "special",
}
const VITAMIN_CAP: int = 100 << 8
const VITAMIN_STEP: int = 10 << 8

## The four items whose own routine is an ordinary effect plus a happiness
## penalty and `LooksBitterMessage`. `EnergypowderEffect` and `EnergyRootEffect`
## share one body and differ only in the row they charge.
const BITTER_ITEMS: Dictionary = {
	0x79: Gen2Battle.HAPPINESS_BITTERPOWDER,
	0x7A: Gen2Battle.HAPPINESS_ENERGYROOT,
	0x7B: Gen2Battle.HAPPINESS_BITTERPOWDER,
	ITEM_REVIVAL_HERB: Gen2Battle.HAPPINESS_REVIVALHERB,
}

## `data/events/happiness_probabilities.asm`, one row per outcome as
## `[threshold, wScriptVar, HappinessChanges row]`. `percent` is `* $ff / 100`
## with integer division, so `30 percent` is 76 and `50 percent + 1` is 128.
const HAPPINESS_PROBABILITIES: Dictionary = {
	&"older_haircut": [
		[76, 2, Gen2Battle.HAPPINESS_OLDERCUT1],
		[128, 3, Gen2Battle.HAPPINESS_OLDERCUT2],
		[255, 4, Gen2Battle.HAPPINESS_OLDERCUT3],
	],
	&"younger_haircut": [
		[154, 2, Gen2Battle.HAPPINESS_YOUNGCUT1],
		[76, 3, Gen2Battle.HAPPINESS_YOUNGCUT2],
		[255, 4, Gen2Battle.HAPPINESS_YOUNGCUT3],
	],
	&"grooming": [[255, 2, Gen2Battle.HAPPINESS_GROOMING]],
}

## The bytes `HaircutOrGrooming`'s `.loop` reads when it walks off the end of
## `HappinessData_DaisysGrooming`, which is `docs/bugs_and_glitches.md`'s
## "Daisy's grooming doesn't always increase happiness". `sub $ff` from `$ff`
## sets no carry, so a roll of exactly 255 steps three bytes on into
## `CopyPokemonName_Buffer1_Buffer3`'s own `ld hl, wStringBuffer1`: `$21`
## borrows against the remaining zero, and the address's two bytes are then read
## as the row. The address is the one part that is not shared, so the low byte
## reaching wScriptVar and the high byte reaching `ChangeHappiness` are pinned
## per profile out of rgblink's symbol table.
const STRING_BUFFER_1: Dictionary = {true: 0xD073, false: 0xCF6B}
const HAPPINESS_TABLE_OVERRUN_OPCODE: int = 0x21

const ITEM_BERRY: int = 0xAD
const ITEM_BERRY_JUICE: int = 0x8B
const SHUCKLE: int = 0xD5
const SPECIES_MAGIKARP: int = 0x81
const SPECIES_DRATINI: int = 0x93

## HAPPINESS_THRESHOLD_1 and HAPPINESS_THRESHOLD_2
## (constants/pokemon_data_constants.asm), which pick a HappinessChanges column.
const HAPPINESS_THRESHOLD_1: int = 100
const HAPPINESS_THRESHOLD_2: int = 200

## `engine/events/shuckle.asm`. MANIA's own OT and ID are the routine's
## literals, and `ReturnShuckie` tests all three before it takes the Pokemon
## back, so a SHUCKLE the player caught themselves is refused.
const MANIA_OT_ID: int = 518
const MANIA_OT_NAME: String = "MANIA"
const SHUCKIE_NICKNAME: String = "SHUCKIE"
const SHUCKIE_LEVEL: int = 15
const SHUCKIE_HAPPY_THRESHOLD: int = 150
## `constants/script_constants.asm`'s own five.
const SHUCKIE_WRONG_MON: int = 0
const SHUCKIE_REFUSED: int = 1
const SHUCKIE_RETURNED: int = 2
const SHUCKIE_HAPPY: int = 3
const SHUCKIE_FAINTED: int = 4

## `CheckMagikarpLength`'s own four answers.
const MAGIKARPLENGTH_NOT_MAGIKARP: int = 0
const MAGIKARPLENGTH_REFUSED: int = 1
const MAGIKARPLENGTH_TOO_SHORT: int = 2
const MAGIKARPLENGTH_BEAT_RECORD: int = 3

## `MagikarpLengths`: the threshold that is also x, and the divisor y. z is the
## row's index plus two, which is `wTempByteValue` starting at 2.
const MAGIKARP_LENGTHS: Array = [
	[110, 1], [310, 2], [710, 4], [2710, 20], [7710, 50], [17710, 100],
	[32710, 150], [47710, 150], [57710, 100], [62710, 50], [64710, 20],
	[65210, 5], [65410, 2], [65510, 1],
]

const CAPTURE_BALLS: Array[int] = [
	ITEM_POKE_BALL, ITEM_GREAT_BALL, ITEM_ULTRA_BALL, ITEM_MASTER_BALL,
]

const WOBBLE_PROBABILITIES: Array = [
	[1, 63], [2, 75], [3, 84], [4, 90], [5, 95], [7, 103], [10, 113],
	[15, 126], [20, 134], [30, 149], [40, 160], [50, 169], [60, 177],
	[80, 191], [100, 201], [120, 211], [140, 220], [160, 227], [180, 234],
	[200, 240], [220, 246], [240, 251], [254, 253], [255, 255],
]


## Returns the ball items whose capture effects are implemented by this host.
## The order follows the ordinary ball pocket order used by the source menu.
static func capture_ball_items() -> Array[int]:
	return CAPTURE_BALLS.duplicate()


## Returns owned supported balls without making the battle scene aware of world
## state. Item definitions still validate the pocket when a throw is resolved.
static func owned_capture_balls(world: Gen2WorldAPI) -> Array[int]:
	var out: Array[int] = []
	if world == null or world.state == null:
		return out
	for ball: int in CAPTURE_BALLS:
		if world.state.item_quantity(ball) > 0:
			out.append(ball)
	return out


static func complete_runtime_request(
	world: Gen2WorldAPI,
	result: Dictionary,
	save: Gen2SaveData = null,
	persist: bool = true,
	random: RandomNumberGenerator = null
) -> Dictionary:
	if world == null:
		return _failure(&"missing_world", {})
	var request: Dictionary = world.pending_runtime_request()
	if request.is_empty():
		return _failure(&"runtime_request_not_pending", {})
	var kind: StringName = StringName(request.get("kind", &""))
	if kind not in [
		&"pokemon_requested", &"trade_requested", &"contest_mon_requested",
		&"dratini_moveset_requested",
	]:
		return _failure(&"party_request_not_pending", request)
	if save == null or world.data == null:
		return _failure(&"missing_save", request)
	var opened: Dictionary = Gen2WorldTransaction.begin(world, save)
	if not bool(opened.get("ok", false)):
		return _failure(StringName(opened["reason"]), {
			"details": opened.get("details", {}), "request": request,
		})

	var candidate: Gen2SaveData = opened["candidate"]
	var generator: RandomNumberGenerator = random if random != null else RandomNumberGenerator.new()
	if random == null:
		generator.randomize()
	var transaction: Dictionary = _apply_party_request(
		world, candidate, request, result, generator
	)
	if not bool(transaction.get("ok", false)):
		return _failure(
			StringName(transaction.get("reason", &"party_request_failed")),
			{"request": request, "details": transaction}
		)

	var before: Gen2WorldSnapshot = world.snapshot()
	## After the snapshot, so a refused transaction rolls the dex flag back with
	## everything else the request wrote.
	_register_caught(world, int(transaction.get("register_caught", 0)))
	_register_unown(world, int(transaction.get("register_unown", 0)))
	var completion_result: Dictionary = {
		"ok": true,
		"script_value": int(transaction.get("script_value", 0)),
		"accepted": bool(transaction.get("accepted", false)),
		"reason": transaction.get("reason", &""),
		"transaction": transaction.get("summary", {}).duplicate(true),
	}
	var resumed: Array = world.complete_runtime_request(completion_result)
	if resumed.is_empty() or not bool(resumed[0].get("ok", false)):
		return _failure(&"runtime_request_failed", {
			"request": request, "results": resumed,
		})

	var committed: Dictionary = Gen2WorldTransaction.commit(
		world, save, candidate, before, persist
	)
	if not bool(committed.get("ok", false)):
		return _failure(StringName(committed["reason"]), {
			"details": committed.get("details", {}), "results": resumed,
		})
	return {
		"ok": true,
		"handled": true,
		"request": request,
		## What the script read out of wScriptVar, which for
		## `CheckPartyFullAfterContest` is the branch its caller takes.
		"script_value": int(transaction.get("script_value", 0)),
		"transaction": transaction.get("summary", {}).duplicate(true),
		"results": resumed,
	}


## Restores HP, status and PP for every non-egg party member, matching the
## source HealParty routine. The candidate save is validated before writeback,
## and the live world only resumes after the candidate is ready.
static func heal_party(
	world: Gen2WorldAPI,
	save: Gen2SaveData,
	persist: bool = true,
) -> Dictionary:
	if world == null or save == null or world.data == null:
		return _failure(&"missing_save", {})
	var opened: Dictionary = Gen2WorldTransaction.begin(world, save)
	if not bool(opened.get("ok", false)):
		return _failure(StringName(opened["reason"]), opened.get("details", {}))
	var candidate: Gen2SaveData = opened["candidate"]
	var healed: int = heal_party_rows(world.data, candidate)
	if healed < 0:
		return _failure(&"invalid_party_member", {})

	var before: Gen2WorldSnapshot = world.snapshot()
	var resumed: Array = world.complete_runtime_request({
		"ok": true,
		"script_value": 1,
		"healed_members": healed,
	})
	if resumed.is_empty() or not bool(resumed[0].get("ok", false)):
		return _failure(&"runtime_request_failed", {"results": resumed})
	var committed: Dictionary = Gen2WorldTransaction.commit(
		world, save, candidate, before, persist
	)
	if not bool(committed.get("ok", false)):
		return _failure(StringName(committed["reason"]), committed.get("details", {}))
	return {
		"ok": true,
		"handled": true,
		"healed_members": healed,
		"results": resumed,
	}



## `HealParty`'s own walk, without the transaction around it: full HP, no status
## and full PP for every party member that is not an egg. Answers how many rows
## it moved, or -1 for a row the battle adapter cannot read.
##
## Shared, because the whiteout heals the same party [method heal_party] does and
## reaches it from a screen rather than from a `special`.
static func heal_party_rows(data: GameData, save: Gen2SaveData) -> int:
	if data == null or save == null:
		return -1
	var healed: int = 0
	for mon: Gen2SaveMon in save.party:
		if mon == null or mon.is_egg:
			continue
		var battle_mon: Gen2BattleMon = Gen2SaveBattleAdapter.to_battle_mon(data, mon)
		if battle_mon == null:
			return -1
		var max_hp: int = battle_mon.max_hp()
		if mon.hp != max_hp or mon.status != Gen2Status.NONE:
			healed += 1
		mon.hp = max_hp
		mon.status = Gen2Status.NONE
		for slot: int in Gen2SaveMon.MAX_MOVES:
			var move_number: int = int(mon.moves[slot])
			mon.pp[slot] = int(data.move(move_number).get("pp", 0)) if move_number > 0 else 0
	return healed


## `Softboiled_MilkDrinkFunction`: a fifth of the user's own maximum health moved
## from the user to another party member, as one candidate transaction.
##
## Both halves are the *user's* fifth. `GetOneFifthMaxHP` is called twice with
## `wCurPartyMon` still holding the user, and only then is the recipient written
## into it, so a big Pokemon heals a small one by a big number.
##
## The refusals are `.SelectMilkDrinkRecipient`'s own, in its order: the user
## itself, a fainted recipient and one already at full health. The caller checks
## the user's own health first, which is the `.CheckMonHasEnoughHP` this shares
## with the party menu's line.
static func transfer_health(
	world: Gen2WorldAPI,
	save: Gen2SaveData,
	from_index: int,
	to_index: int,
	persist: bool = true,
) -> Dictionary:
	if world == null or save == null or world.data == null:
		return _failure(&"missing_save", {})
	if from_index == to_index:
		return _failure(&"same_member", {"party_index": to_index})
	var opened: Dictionary = Gen2WorldTransaction.begin(world, save)
	if not bool(opened.get("ok", false)):
		return _failure(StringName(opened["reason"]), opened.get("details", {}))
	var candidate: Gen2SaveData = opened["candidate"]
	var user: Gen2SaveMon = _party_member(candidate, from_index)
	var target: Gen2SaveMon = _party_member(candidate, to_index)
	if user == null or target == null:
		return _failure(&"unknown_party_member", {"party_index": to_index})
	var amount: int = one_fifth_max_hp(world.data, user)
	if amount <= 0 or user.hp <= amount:
		return _failure(&"not_enough_health", {"party_index": from_index})
	if target.is_egg or target.hp <= 0:
		return _failure(&"fainted_member", {"party_index": to_index})
	var target_max: int = _max_hp(world.data, target)
	if target.hp >= target_max:
		return _failure(&"already_full", {"party_index": to_index})

	user.hp -= amount
	var restored: int = mini(amount, target_max - target.hp)
	target.hp += restored
	var before: Gen2WorldSnapshot = world.snapshot()
	var committed: Dictionary = Gen2WorldTransaction.commit(
		world, save, candidate, before, persist
	)
	if not bool(committed.get("ok", false)):
		return _failure(StringName(committed["reason"]), committed.get("details", {}))
	return {
		"ok": true,
		"amount": amount,
		"restored": restored,
		"from": from_index,
		"to": to_index,
	}


## `GetOneFifthMaxHP`, and so also `.CheckMonHasEnoughHP`'s own divisor: a
## Pokemon may use Softboiled or Milk Drink only while it has more than this.
static func one_fifth_max_hp(data: GameData, mon: Gen2SaveMon) -> int:
	if data == null or mon == null or mon.is_egg:
		return 0
	@warning_ignore("integer_division")
	return _max_hp(data, mon) / 5


## A party member by index, or null when the slot is empty.
static func _party_member(save: Gen2SaveData, index: int) -> Gen2SaveMon:
	if save == null or index < 0 or index >= save.party.size():
		return null
	return save.party[index]


## Applies a field item to a save and the live world as one candidate transaction.
## The current slice covers source party item effects, including EvoStoneEffect's
## candidate evolution and the HP delta applied by EvolvePokemon.
static func use_item(
	world: Gen2WorldAPI,
	save: Gen2SaveData,
	item: int,
	party_index: int = -1,
	persist: bool = true
) -> Dictionary:
	if world == null or save == null or world.data == null:
		return _failure(&"missing_save", {})
	if world.state == null or world.state.item_quantity(item) <= 0:
		return _failure(&"insufficient_item_quantity", {"item": item})
	var opened: Dictionary = Gen2WorldTransaction.begin(world, save)
	if not bool(opened.get("ok", false)):
		return _failure(StringName(opened["reason"]), opened.get("details", {}))
	var candidate: Gen2SaveData = opened["candidate"]
	var effect: Dictionary = _apply_item_effect(world.data, candidate, item, party_index)
	if not bool(effect.get("ok", false)):
		return _failure(StringName(effect.get("reason", &"item_has_no_effect")), effect)
	var before: Gen2WorldSnapshot = world.snapshot()
	var next_quantity: int = world.state.item_quantity(item) - 1
	var changes: Dictionary = {"items": {item: next_quantity}}
	if effect.has("repel_steps"):
		changes["repel_steps"] = int(effect["repel_steps"])
	var applied: Dictionary = world.state.apply_changes({}, {}, changes)
	if not bool(applied.get("ok", false)):
		return _failure(&"item_state_failed", applied)
	var committed: Dictionary = Gen2WorldTransaction.commit(
		world, save, candidate, before, persist
	)
	if not bool(committed.get("ok", false)):
		return _failure(StringName(committed["reason"]), committed.get("details", {}))
	# `.proceed`'s dex writes, on the live state beside every other one: the
	# caller has the snapshot a refused save rolls back to.
	_register_caught(world, int(effect.get("register_caught", 0)))
	_register_unown(world, int(effect.get("register_unown", 0)))
	return {
		"ok": true,
		"item": item,
		"party_index": party_index,
		"effect": effect.get("effect", &""),
		"healed": int(effect.get("healed", 0)),
		"status_cleared": int(effect.get("status_cleared", 0)),
		"repel_steps": int(effect.get("repel_steps", -1)),
		"old_species": int(effect.get("old_species", 0)),
		"new_species": int(effect.get("new_species", 0)),
		"evolving_name": String(effect.get("evolving_name", "")),
		"move_offers": effect.get("move_offers", []).duplicate(),
		"bitter": bool(effect.get("bitter", false)),
		"stat": String(effect.get("stat", "")),
	}


## engine/items/tmhm.asm's TeachTMHM, as one candidate transaction beside
## use_item(). The pack's own USE reaches this, not `UseItem`'s jumptable: the
## TM/HM pocket runs AskTeachTMHM, ChooseMonToLearnTMHM and TeachTMHM instead
## (engine/items/pack.asm's .UseItem).
##
## The refusal order is the source's. CanLearnTMHMMove comes first, then
## KnowsMove, then LearnMove's own search for an empty slot; each answers before
## anything is written.
##
## A full moveset is where LearnMove reaches ForgetMove, which is a menu, so this
## is called twice: once with [param forget_slot] left at -1, which is what runs
## the two compatibility checks and answers `moveset_full` having written
## nothing, and again with the slot the player gave up. An empty slot always
## wins over a passed [param forget_slot], because LearnMove.loop only reaches
## ForgetMove when its own scan finds no zero.
##
## An HM is not consumed: TeachTMHM returns straight after IsHM, so it skips both
## ConsumeTM and the happiness change.
static func teach_tm_hm(
	world: Gen2WorldAPI,
	save: Gen2SaveData,
	item: int,
	party_index: int,
	forget_slot: int = -1,
	persist: bool = true
) -> Dictionary:
	if world == null or save == null or world.data == null:
		return _failure(&"missing_save", {})
	if world.state == null or world.state.item_quantity(item) <= 0:
		return _failure(&"insufficient_item_quantity", {"item": item})
	var move: int = Gen2WorldTMHM.move_for_item(world.data, item)
	if move <= 0:
		return _failure(&"not_a_tm_hm", {"item": item})
	if party_index < 0 or party_index >= save.party.size():
		return _failure(&"invalid_party_index", {"party_index": party_index})
	var mon: Gen2SaveMon = save.party[party_index] as Gen2SaveMon
	if mon == null:
		return _failure(&"invalid_party_index", {"party_index": party_index})
	# ChooseMonToLearnTMHM refuses an egg with SFX_WRONG and reopens the list, so
	# an egg never reaches TeachTMHM at all.
	if mon.is_egg:
		return _failure(&"cannot_teach_egg", {"party_index": party_index})
	if not Gen2WorldTMHM.can_learn(world.data, mon.species, move):
		return _failure(&"not_compatible", {"species": mon.species, "move": move})
	if Gen2WorldTMHM.knows_move(mon.moves, move):
		return _failure(&"already_knows_move", {"move": move})
	var slot: int = Gen2WorldTMHM.first_empty_slot(mon.moves)
	var forgot: int = 0
	if slot < 0:
		# ForgetMove's own refusals, answering before the candidate save is built
		# the way every refusal above them does.
		if forget_slot < 0:
			return _failure(&"moveset_full", {
				"party_index": party_index, "move": move, "moves": mon.moves.duplicate(),
			})
		if forget_slot >= mon.moves.size():
			return _failure(&"invalid_forget_slot", {"forget_slot": forget_slot})
		forgot = int(mon.moves[forget_slot])
		if Gen2MoveForget.is_hm_move(forgot):
			return _failure(&"cannot_forget_hm", {"forget_slot": forget_slot, "forgot": forgot})
		slot = forget_slot

	var opened: Dictionary = Gen2WorldTransaction.begin(world, save)
	if not bool(opened.get("ok", false)):
		return _failure(StringName(opened["reason"]), opened.get("details", {}))
	var candidate: Gen2SaveData = opened["candidate"]
	var learner: Gen2SaveMon = candidate.party[party_index] as Gen2SaveMon
	learner.moves[slot] = move
	# LearnMove writes the move, then its PP from Moves + MOVE_PP: a freshly
	# learned move always arrives at full PP.
	learner.pp[slot] = int(world.data.move(move).get("pp", 0))

	var before: Gen2WorldSnapshot = world.snapshot()
	## `IsHM` returns before both the happiness change and `ConsumeTM`, so an HM
	## costs nothing and moves nothing; a TM does both, in that order.
	var consumed: bool = not Gen2WorldTMHM.is_hm(item)
	var happiness: int = learner.happiness
	if consumed:
		learner.happiness = change_happiness(
			world.data, learner.happiness, RomLayout.HAPPINESS_LEARNMOVE
		)
	var applied: Dictionary = {"ok": true}
	if consumed:
		applied = world.state.apply_changes({}, {}, {
			"items": {item: world.state.item_quantity(item) - 1},
		})
	if not bool(applied.get("ok", false)):
		return _failure(&"item_state_failed", applied)
	var committed: Dictionary = Gen2WorldTransaction.commit(
		world, save, candidate, before, persist
	)
	if not bool(committed.get("ok", false)):
		return _failure(StringName(committed["reason"]), committed.get("details", {}))
	return {
		"ok": true,
		"item": item,
		"party_index": party_index,
		"move": move,
		"slot": slot,
		"forgot": forgot,
		"pp": learner.pp[slot],
		"consumed": consumed,
		"happiness": learner.happiness,
		"happiness_change": learner.happiness - happiness,
	}


## `LearnMove` on its own, without the TM/HM that usually reaches it: what an
## evolution offers a Pokemon whose four slots are full. The refusal order is
## `LearnMove`'s own, an empty slot always winning over a passed
## [param forget_slot] the way `.loop` does, and by default nothing is consumed
## and no happiness moves because no item was used.
##
## [param compatibility_checked] is `CheckCanLearnMoveTutorMove`'s own
## `predef CanLearnTMHMMove`, which stands in front of `KnowsMove` there and
## nowhere else, and [param happiness_kind] its `ld c, HAPPINESS_LEARNMOVE`,
## charged inside the same transaction the move is written in. A level-up offer
## passes neither, which is what makes it the plain `LearnMove` it is.
static func learn_move(
	world: Gen2WorldAPI,
	save: Gen2SaveData,
	party_index: int,
	move: int,
	forget_slot: int = -1,
	persist: bool = true,
	compatibility_checked: bool = false,
	happiness_kind: int = 0
) -> Dictionary:
	if world == null or save == null or world.data == null:
		return _failure(&"missing_save", {})
	if move <= 0 or world.data.move(move).is_empty():
		return _failure(&"unknown_move", {"move": move})
	var mon: Gen2SaveMon = _party_member(save, party_index)
	if mon == null or mon.is_egg:
		return _failure(&"invalid_party_index", {"party_index": party_index})
	if compatibility_checked \
		and not Gen2WorldTMHM.can_learn(world.data, mon.species, move):
		return _failure(&"not_compatible", {"species": mon.species, "move": move})
	if Gen2WorldTMHM.knows_move(mon.moves, move):
		return _failure(&"already_knows_move", {"move": move})
	var slot: int = Gen2WorldTMHM.first_empty_slot(mon.moves)
	var forgot: int = 0
	if slot < 0:
		if forget_slot < 0:
			return _failure(&"moveset_full", {
				"party_index": party_index, "move": move, "moves": mon.moves.duplicate(),
			})
		if forget_slot >= mon.moves.size():
			return _failure(&"invalid_forget_slot", {"forget_slot": forget_slot})
		forgot = int(mon.moves[forget_slot])
		if Gen2MoveForget.is_hm_move(forgot):
			return _failure(&"cannot_forget_hm", {"forget_slot": forget_slot, "forgot": forgot})
		slot = forget_slot
	var opened: Dictionary = Gen2WorldTransaction.begin(world, save)
	if not bool(opened.get("ok", false)):
		return _failure(StringName(opened["reason"]), opened.get("details", {}))
	var candidate: Gen2SaveData = opened["candidate"]
	var learner: Gen2SaveMon = candidate.party[party_index] as Gen2SaveMon
	learner.moves[slot] = move
	learner.pp[slot] = int(world.data.move(move).get("pp", 0))
	## `.learned` is what `CheckCanLearnMoveTutorMove` tests before its
	## `ChangeHappiness`, so a cancelled forget charges nothing: the refusals
	## above have already answered by here.
	var happiness_before: int = learner.happiness
	if happiness_kind > 0:
		learner.happiness = change_happiness(
			world.data, learner.happiness, happiness_kind
		)
	var before: Gen2WorldSnapshot = world.snapshot()
	var committed: Dictionary = Gen2WorldTransaction.commit(
		world, save, candidate, before, persist
	)
	if not bool(committed.get("ok", false)):
		return _failure(StringName(committed["reason"]), committed.get("details", {}))
	return {
		"ok": true,
		"party_index": party_index,
		"move": move,
		"slot": slot,
		"forgot": forgot,
		"pp": learner.pp[slot],
		"happiness": learner.happiness,
		"happiness_change": learner.happiness - happiness_before,
	}


## `CheckCanLearnMoveTutorMove` (`engine/events/move_tutor.asm`): the same
## `LearnMove` a TM reaches, with `CanLearnTMHMMove` in front of it and
## `HAPPINESS_LEARNMOVE` behind it, and no item either way. The tutor charges
## coins in its map script rather than here.
static func teach_tutor_move(
	world: Gen2WorldAPI,
	save: Gen2SaveData,
	party_index: int,
	move: int,
	forget_slot: int = -1,
	persist: bool = true
) -> Dictionary:
	return learn_move(
		world, save, party_index, move, forget_slot, persist,
		true, RomLayout.HAPPINESS_LEARNMOVE
	)


## `ChangeHappiness` over the imported table, taking the byte rather than the
## Pokemon: `wCurPartyMon`'s egg guard and the `wBattleMonHappiness` mirror
## behind it are the caller's, because a caller here holds either a
## [Gen2SaveMon] or a [Gen2BattleMon] and never both.
##
## The three rows are picked by HAPPINESS_THRESHOLD_1 and _2, and the sign of a
## change is `cp $64`: a byte from 100 up is the subtracting branch, which is why
## the table is read signed. Each branch answers the carry rather than clamping,
## so a rise saturates at 255 and a fall at 0.
static func change_happiness(data: GameData, happiness: int, kind: int) -> int:
	var changes: Array[int] = []
	if data != null:
		changes = data.happiness_changes(kind)
	if changes.size() < RomLayout.HAPPINESS_CHANGE_WIDTH:
		return happiness
	var row: int = 0 if happiness < HAPPINESS_THRESHOLD_1 \
		else (1 if happiness < HAPPINESS_THRESHOLD_2 else 2)
	return clampi(happiness + changes[row], 0, 255)


## `HaircutOrGrooming`'s `Random` walk over one of the three tables: subtract
## each threshold in turn and take the row that borrows. [param roll] is the
## byte `Random` answered and [param crystal] picks the overrun's own address.
##
## Answers `{"script_value": int, "happiness_kind": int}`. A kind no
## `HappinessChanges` row exists for leaves [method change_happiness]'s byte
## alone, which is exactly what the cartridge's overrun does with it.
static func groom_outcome(routine: StringName, roll: int, crystal: bool) -> Dictionary:
	var rows: Array = HAPPINESS_PROBABILITIES.get(routine, [])
	var buffer: int = int(STRING_BUFFER_1[crystal])
	rows = rows + [[
		HAPPINESS_TABLE_OVERRUN_OPCODE, buffer & 0xFF, (buffer >> 8) & 0xFF,
	]]
	var left: int = roll & 0xFF
	for row: Array in rows:
		if left < int(row[0]):
			return {"script_value": int(row[1]), "happiness_kind": int(row[2])}
		left -= int(row[0])
	return {"script_value": 0, "happiness_kind": 0}


## `StepHappiness`, spent [param times] over: one flat point to every party
## member that is not an egg, saturating at 255 rather than wrapping, and
## reaching no `HappinessChanges` row at all. The step counter that decides how
## often is [method Gen2WorldState.count_step]'s.
##
## Answers the slots that moved, so a caller can persist only when the walk
## actually changed something.
static func apply_step_happiness(save: Gen2SaveData, times: int = 1) -> Array[int]:
	var moved: Array[int] = []
	if save == null or times <= 0:
		return moved
	for index: int in save.party.size():
		var mon: Gen2SaveMon = save.party[index] as Gen2SaveMon
		if mon == null or mon.is_egg:
			continue
		var raised: int = mini(255, mon.happiness + times)
		if raised == mon.happiness:
			continue
		mon.happiness = raised
		moved.append(index)
	return moved



## `Text_BreedHuh`: "Huh?" and then a `para` whose page is empty, because the
## `text_asm` behind it is the animation rather than a line. The empty page is
## what the sequence opens on, so the box waits for a press like any other
## paragraph break.
const HUH_TEXT: String = "Huh?" + Gen2TextStream.PAGE_BREAK


## `_BreedEggHatchText`, whose `wStringBuffer1` is the name the row now carries.
static func hatch_text(nickname: String) -> String:
	return "%s came\nout of its EGG!" % nickname


## `_BreedAskNicknameText`, the `YesNoBox` after the hatch.
static func nickname_question(nickname: String) -> String:
	return "Give a nickname to\n%s?" % nickname


## `NamingScreenJumptable`'s `.Pokemon`: the name, `'S` beside it and
## `NICKNAME?` on the row two below.
static func nickname_prompt(nickname: String) -> String:
	return "%s'S\nNICKNAME?" % nickname


## `_CaughtAskNicknameText`, the question `GiveANickname_YesNo` asks for anything
## received rather than hatched. Distinct from [method nickname_question], which
## is `_BreedAskNicknameText` and names the row on its own line.
static func caught_nickname_question(species_name: String) -> String:
	return "Give a nickname to\nthe %s you%sreceived?" % [
		species_name, Gen2TextStream.SCROLL_BREAK,
	]


## `_AskGiveNicknameText`, which is `PokeBallEffect`'s own question and not
## `GiveANickname_YesNo`'s: a caught Pokemon is asked about by name alone, where
## a received one is [method caught_nickname_question]'s longer line.
static func capture_nickname_question(species_name: String) -> String:
	return "Give a nickname to\n%s?" % species_name


## `_WasSentToBillsPCText` and `_BallSentToPCText`, which are the same words in
## the same shape: the gift path reads `wStringBuffer1` and the capture path
## `wMonOrItemNameBuffer`, and both hold the name the row ended up with rather
## than the species. Kept as a format so the screen that owns the naming can
## fill it in with its own answer.
const SENT_TO_BOX_FORMAT: String = "%s was\nsent to BILL's PC."


static func sent_to_box_text(species_name: String) -> String:
	return SENT_TO_BOX_FORMAT % species_name


## Where `GivePoke` would put one more Pokemon: `TryAddMonToParty` first, then
## `SendMonIntoBox`, and `.FailedToGiveMon` when neither has room. Answered
## without writing anything, because `GiveANickname_YesNo` stands between the
## two on the cartridge and the prompt it opens is drawn before this port's own
## transaction runs.
static func gift_destination(save: Gen2SaveData) -> StringName:
	if save == null:
		return &"full"
	if save.party.size() < Gen2SaveData.MAX_PARTY:
		return &"party"
	return &"box" if bool(save.first_empty_box_slot().get("ok", false)) else &"full"


## `DoEggStep`, spent [param times] over. Each pass walks the party from the
## front taking one hatch cycle off every egg, and stops on the first egg whose
## counter reaches zero, so an egg behind that one keeps its cycle for that
## step. Answers the party index of the egg that is ready to hatch, or -1.
##
## The counter lives in the happiness byte, which is what `GiveEgg` wrote and
## what `HatchEggs` reads; [method apply_step_happiness] skips eggs for the same
## reason.
static func apply_egg_steps(save: Gen2SaveData, times: int = 1) -> int:
	if save == null or times <= 0:
		return -1
	for _pass: int in times:
		for index: int in save.party.size():
			var mon: Gen2SaveMon = save.party[index] as Gen2SaveMon
			if mon == null or not mon.is_egg:
				continue
			mon.happiness = (mon.happiness - 1) & 0xFF
			if mon.happiness == 0:
				return index
	return -1


## `CheckPlayerPartyForFitMon`: the OR of every party slot's HP word, which is
## why it needs no egg test of its own. `GiveEgg` zeroes an egg's HP after the
## stats are generated, so an egg contributes nothing here and a party of
## nothing but eggs is out of useable Pokemon.
static func party_has_fit_mon(save: Gen2SaveData) -> bool:
	if save == null:
		return false
	for mon: Gen2SaveMon in save.party:
		if mon != null and mon.hp > 0:
			return true
	return false


## `DoPoisonStep`, the pass `CountStep` owes every fourth step. One HP off every
## poisoned member that is still standing, and a member the point finishes has
## its status cleared, which is what stops it being damaged again.
##
## The two flags `wPoisonStepFlagSum` collects decide what the pass costs:
## `%10`, somebody fainted, is the only one that reaches a script, and `%01`
## alone is the sound and nothing else. `.CheckWhitedOut` runs inside that
## script, so the happiness penalty and the lines are charged on the faint
## branch alone.
##
## Answers `{"damaged", "fainted", "sfx", "texts", "whiteout"}`; the caller owns
## the sound, the box and the blackout behind it.
static func apply_poison_step(data: GameData, save: Gen2SaveData) -> Dictionary:
	var out: Dictionary = {
		"damaged": PackedInt32Array(), "fainted": PackedInt32Array(),
		"sfx": false, "texts": PackedStringArray(), "whiteout": false,
	}
	if data == null or save == null or save.party.is_empty():
		return out
	var damaged: PackedInt32Array = PackedInt32Array()
	var fainted: PackedInt32Array = PackedInt32Array()
	for index: int in save.party.size():
		var mon: Gen2SaveMon = save.party[index] as Gen2SaveMon
		if mon == null or not Gen2Status.has(mon.status, Gen2Status.POISON) or mon.hp <= 0:
			continue
		mon.hp -= 1
		if mon.hp > 0:
			damaged.append(index)
			continue
		mon.status = Gen2Status.NONE
		fainted.append(index)
	out["damaged"] = damaged
	out["fainted"] = fainted
	if fainted.is_empty():
		out["sfx"] = not damaged.is_empty()
		return out
	## `.Script_MonFaintedToPoison` opens with `.PlayPoisonSFX` whatever the
	## flags were, so a faint plays the same sound a survivor does.
	out["sfx"] = true
	var texts: PackedStringArray = PackedStringArray()
	for index: int in fainted:
		var mon: Gen2SaveMon = save.party[index] as Gen2SaveMon
		mon.happiness = change_happiness(
			data, mon.happiness, Gen2Battle.HAPPINESS_POISONFAINT
		)
		## `GetPartyNickname` reads the row's own name, which `AddPartyMon` always
		## writes; an empty one is this port's development party and falls back
		## the way every other screen's name does.
		texts.append(poison_faint_text(
			mon.nickname if not mon.nickname.is_empty()
			else String(data.species(mon.species).get("name", ""))
		))
	out["texts"] = texts
	out["whiteout"] = not party_has_fit_mon(save)
	return out


## `_PoisonFaintText`, whose `wStringBuffer3` is the nickname `GetPartyNickname`
## put there.
static func poison_faint_text(nickname: String) -> String:
	return "%s\nfainted!" % nickname


## `_WhitedOutText`. `<PLAYER>` is the name on the save, and the `para` is the
## page the box turns to.
static func whited_out_text(player_name: String) -> String:
	return "%s is out of\nuseable #MON!%s%s whited\nout!" % [
		player_name, Gen2TextStream.PAGE_BREAK, player_name,
	]


## `Script_Whiteout` past its own text: `HealParty`, `HalveMoney`,
## `GetWhiteoutSpawn` and the `WarpToSpawnPoint` behind them, in that order.
##
## One routine, because every way of blacking out reaches this one script: a
## battle lost anywhere goes through `Script_reloadmapafterbattle`, and the last
## party member fainting to poison goes through `.Script_MonFaintedToPoison`.
##
## The spawn is `wLastSpawnMapGroup`/`wLastSpawnMapNumber` read back through
## `IsSpawnPoint`, so a map `blackoutmod` named is honoured here and SPAWN_HOME
## is what a player who has entered no Pokemon Center gets.
static func whiteout(
	world: Gen2WorldAPI, save: Gen2SaveData, persist: bool = true
) -> Dictionary:
	if world == null or world.data == null or world.state == null:
		return _failure(&"missing_world", {})
	var healed: int = heal_party_rows(world.data, save)
	if healed < 0:
		return _failure(&"invalid_party_member", {})
	## `HalveMoney`'s `srl`/`rra` chain over the three bytes, which is a floor.
	var before_money: int = world.state.money(0)
	world.state.apply_changes({}, {}, {"money": {0: before_money >> 1}})
	var spawn: int = world.whiteout_spawn()
	var warped: Dictionary = world.warp_to_spawn(spawn)
	if not bool(warped.get("ok", false)):
		return _failure(StringName(warped.get("reason", &"missing_spawn")), warped)
	if persist and save != null:
		var written: Dictionary = Gen2SaveStore.save(save, world.data)
		if not bool(written.get("ok", false)):
			return _failure(&"whiteout_save_failed", {
				"message": written.get("message", ""),
			})
	return {
		"ok": true,
		"handled": true,
		"healed_members": healed,
		"money_before": before_money,
		"money_after": world.state.money(0),
		"spawn": spawn,
		"warp": warped,
	}


## Attempts to catch one wild battle mon and consumes the ball on either result.
## The battle screen owns the animation; this host owns the cartridge outcome and
## the save/world writeback. A caught mon enters the party when there is room and
## otherwise uses the first free PC-box slot.
static func capture_wild(
	world: Gen2WorldAPI,
	save: Gen2SaveData,
	wild: Gen2BattleMon,
	ball: int,
	random: RandomNumberGenerator = null,
	caught_location: int = 0,
	persist: bool = true,
	battle_type: int = Gen2Battle.BATTLETYPE_NORMAL
) -> Dictionary:
	if world == null or save == null or world.data == null or wild == null:
		return _failure(&"missing_capture_context", {})
	var opened: Dictionary = Gen2WorldTransaction.begin(world, save)
	if not bool(opened.get("ok", false)):
		return _failure(StringName(opened["reason"]), opened.get("details", {}))
	if save.party.size() >= Gen2SaveData.MAX_PARTY:
		var storage: Dictionary = save.first_empty_box_slot()
		if not bool(storage.get("ok", false)):
			return _failure(&"storage_full", {"ball": ball})
	var definition: Dictionary = world.data.item(ball)
	if definition.is_empty():
		return _failure(&"unknown_ball", {"ball": ball})
	if int(definition.get("pocket", 0)) != RomLayout.ITEM_POCKET_BALL:
		return _failure(&"item_is_not_a_ball", {"ball": ball})
	if ball not in [ITEM_MASTER_BALL, ITEM_ULTRA_BALL, ITEM_GREAT_BALL, ITEM_POKE_BALL]:
		return _failure(&"unsupported_ball_effect", {"ball": ball})
	if world.state == null or world.state.item_quantity(ball) <= 0:
		return _failure(&"insufficient_ball_quantity", {"ball": ball})
	var generator: RandomNumberGenerator = random if random != null else RandomNumberGenerator.new()
	if random == null:
		generator.randomize()
	var outcome: Dictionary = _capture_outcome(world.data, wild, ball, generator)
	var candidate: Gen2SaveData = opened["candidate"]
	var destination: Dictionary = {}
	var box_full: bool = false
	if bool(outcome.get("caught", false)):
		var captured: Gen2SaveMon = _captured_mon(world.data, save, wild, generator)
		if captured == null:
			return _failure(&"could_not_create_captured_pokemon", outcome)
		## `SetCaughtData` runs on the caught Pokemon itself. [param
		## caught_location] is the caller's override, for a catch whose landmark
		## is not the map the player is standing on; every one that has none
		## passes 0 and takes the map's.
		set_caught_data(
			captured, wild.level, world.object_time_of_day, world.player_female(),
			caught_location if caught_location > 0 else world.landmark()
		)
		destination = candidate.add_party_or_box(captured)
		if not bool(destination.get("ok", false)):
			return _failure(StringName(destination.get("reason", &"storage_full")), {
				"ball": ball, "outcome": outcome,
			})
		box_full = _fills_its_box(candidate, destination)
	var before: Gen2WorldSnapshot = world.snapshot()
	## After the snapshot the rollback below restores, so a refused candidate
	## save takes the dex flag back with the ball.
	if bool(outcome.get("caught", false)):
		_register_caught(world, wild.species)
		_register_unown(world, _unown_form(
			wild.species, wild.persistent_dvs(), destination
		))
	var next_quantity: int = world.state.item_quantity(ball) - 1
	var item_result: Dictionary = world.state.apply_changes({}, {}, {"items": {ball: next_quantity}})
	if not bool(item_result.get("ok", false)):
		return _failure(&"ball_state_failed", item_result)
	var committed: Dictionary = Gen2WorldTransaction.commit(
		world, save, candidate, before, persist
	)
	if not bool(committed.get("ok", false)):
		return _failure(StringName(committed["reason"]), committed.get("details", {}))
	## `.SendToPC`'s own `cp MONS_PER_BOX`: the catch that fills a box raises
	## BATTLERESULT_BOX_FULL, which `Script_reloadmapafterbattle` answers with
	## `Script_SpecialBillCall` once the battle is over. Behind the commit, so a
	## catch that was rolled back owes no phone call.
	world.state.set_battle_box_full(box_full)
	## `PokeBallEffect`'s own `cp BATTLETYPE_CELEBI` behind the dex entry: the
	## bit is raised by the catch rather than by the shrine, and
	## `CheckCaughtCelebi` reads it once the fight is over.
	if bool(outcome.get("caught", false)) and battle_type == Gen2Battle.BATTLETYPE_CELEBI:
		world.state.set_battle_caught_celebi(true)
	return {
		"ok": true,
		"handled": true,
		"caught": bool(outcome.get("caught", false)),
		"ball": ball,
		"quantity": next_quantity,
		"catch_rate": int(outcome.get("catch_rate", 0)),
		"wobbles": int(outcome.get("wobbles", 0)),
		"species": wild.species,
		"destination": destination.duplicate(true),
		"box_full": box_full,
	}


## `.SendToPC`'s `ld a, [sBoxCount] / cp MONS_PER_BOX`, read after the deposit:
## the box the catch landed in has no room left. The save model keeps no
## current-box pointer, so the box asked about is the one the deposit picked,
## which is what [method Gen2SaveData.box_free_space] already answers scripts
## with.
static func _fills_its_box(save: Gen2SaveData, destination: Dictionary) -> bool:
	if save == null or StringName(destination.get("destination", &"")) != &"box":
		return false
	var box: Gen2SaveBox = save.boxes[int(destination.get("box", -1))] as Gen2SaveBox
	return box != null and box.occupied_count() >= Gen2SaveBox.CAPACITY


## `CheckPartyFullAfterContest`, which is what takes home whatever the Bug
## Catching Contest caught. `wContestMon` is a party struct already, so the party
## branch is a copy and the box branch an `InsertPokemonIntoBox`; each stands
## behind its own `GiveANickname_YesNo`, and `SetCaughtData` is then overwritten
## with LANDMARK_NATIONAL_PARK, the gender bit kept.
##
## Three things a reading gets wrong. `.BoxFull` writes nothing and still answers
## BUGCONTEST_BOXED_MON, so a full party over a full box loses the catch; the box
## branch prints no "sent to BILL's PC" line, because the script's own
## `ContestResults_PartyFullText` is what BUGCONTEST_BOXED_MON reaches; and
## `wContestMon` is cleared on every branch but that last one.
static func _apply_contest_mon(
	world: Gen2WorldAPI,
	candidate: Gen2SaveData,
	result: Dictionary,
	random: RandomNumberGenerator
) -> Dictionary:
	var caught: Dictionary = world.state.contest_mon() if world.state != null else {}
	var species: int = int(caught.get("species", 0))
	if species <= 0 or world.data.species(species).is_empty():
		return {
			"ok": true, "accepted": false, "script_value": BUGCONTEST_NO_CATCH,
			"reason": &"no_contest_catch",
			"summary": {"kind": &"contest_mon", "accepted": false},
		}
	var boxed: bool = candidate.party.size() >= Gen2SaveData.MAX_PARTY
	if boxed and not bool(candidate.first_empty_box_slot().get("ok", false)):
		## `.BoxFull`: nothing is written and the catch is gone, which is the
		## cartridge's own answer rather than a refusal of this port's.
		world.state.set_contest_mon({})
		return {
			"ok": true, "accepted": false, "script_value": BUGCONTEST_BOXED_MON,
			"reason": &"storage_full",
			"summary": {"kind": &"contest_mon", "accepted": false, "species": species},
		}
	var mon: Gen2SaveMon = _new_mon(
		world.data, candidate, species, int(caught.get("level", 1)),
		int(caught.get("item", 0)), random, false, int(caught.get("dvs", -1))
	)
	if mon == null:
		return {"ok": false, "reason": &"could_not_create_pokemon"}
	## The health it was standing there with, which is what `ContestScore` read
	## and what the struct kept.
	mon.hp = clampi(int(caught.get("hp", mon.hp)), 0, mon.hp)
	if result.has("nickname"):
		var chosen: String = String(result["nickname"]).strip_edges()
		if not chosen.is_empty():
			mon.nickname = chosen
	set_caught_data(
		mon, int(caught.get("level", 1)), world.object_time_of_day,
		world.player_female(), LANDMARK_NATIONAL_PARK
	)
	var placed: Dictionary = candidate.add_party_or_box(mon)
	if not bool(placed.get("ok", false)):
		return {"ok": false, "reason": StringName(placed.get("reason", &"storage_full"))}
	world.state.set_contest_mon({})
	return {
		"ok": true,
		"accepted": true,
		"script_value": BUGCONTEST_BOXED_MON if boxed else BUGCONTEST_CAUGHT_MON,
		"register_caught": species,
		"register_unown": _unown_form(species, mon.dvs, placed),
		"summary": {
			"kind": &"contest_mon", "accepted": true, "species": species,
			"level": int(caught.get("level", 1)),
			"destination": placed.get("destination", &"party"),
			"nickname": mon.nickname,
		},
	}


## `InitNickname`, which `PokeBallEffect` runs once the row is already in the
## party or the box: `NamingScreen` writes into `wPartyMonNicknames` or
## `sBoxMonNicknames` rather than into the struct the catch built, so the rename
## is its own write and not part of [method capture_wild]'s transaction.
##
## [param destination] is that method's own answer. Nothing is written when the
## player kept the species name, which is what NO and an empty entry both leave
## in `wStringBuffer1`.
static func name_captured_mon(
	world: Gen2WorldAPI,
	save: Gen2SaveData,
	destination: Dictionary,
	nickname: String,
	persist: bool = true
) -> Dictionary:
	if world == null or save == null or nickname.strip_edges().is_empty():
		return _failure(&"missing_nickname_context", {})
	var opened: Dictionary = Gen2WorldTransaction.begin(world, save)
	if not bool(opened.get("ok", false)):
		return _failure(StringName(opened["reason"]), opened.get("details", {}))
	var candidate: Gen2SaveData = opened["candidate"]
	var mon: Gen2SaveMon = _captured_row(candidate, destination)
	if mon == null:
		return _failure(&"captured_row_not_found", destination.duplicate(true))
	if mon.nickname == nickname:
		return {"ok": true, "handled": true, "renamed": false}
	mon.nickname = nickname
	var before: Gen2WorldSnapshot = world.snapshot()
	var committed: Dictionary = Gen2WorldTransaction.commit(
		world, save, candidate, before, persist
	)
	if not bool(committed.get("ok", false)):
		return _failure(StringName(committed["reason"]), committed.get("details", {}))
	return {"ok": true, "handled": true, "renamed": true, "nickname": nickname}


## The row [method capture_wild] just wrote, on either side of
## `TryAddMonToParty`/`SendMonIntoBox`.
static func _captured_row(save: Gen2SaveData, destination: Dictionary) -> Gen2SaveMon:
	if save == null or destination.is_empty():
		return null
	match StringName(destination.get("destination", &"")):
		&"party":
			var index: int = int(destination.get("party_index", -1))
			return save.party[index] as Gen2SaveMon \
				if index >= 0 and index < save.party.size() else null
		&"box":
			var box_index: int = int(destination.get("box", -1))
			if box_index < 0 or box_index >= save.boxes.size():
				return null
			var box: Gen2SaveBox = save.boxes[box_index] as Gen2SaveBox
			var slot: int = int(destination.get("slot", -1))
			if box == null or slot < 0 or slot >= box.slots.size():
				return null
			return box.slots[slot] as Gen2SaveMon
	return null


static func _apply_party_request(
	world: Gen2WorldAPI,
	candidate: Gen2SaveData,
	request: Dictionary,
	result: Dictionary,
	random: RandomNumberGenerator
) -> Dictionary:
	var kind: StringName = StringName(request.get("kind", &""))
	if kind == &"contest_mon_requested":
		return _apply_contest_mon(world, candidate, result, random)
	if kind == &"pokemon_requested" \
		and StringName((request.get("values", {}) as Dictionary).get("kind", &"")) == &"give_shuckle":
		return _apply_give_shuckle(world, candidate, request, random)
	if kind == &"dratini_moveset_requested":
		return _apply_dratini_moveset(world, candidate, request)
	if kind == &"pokemon_requested":
		var values: Dictionary = request.get("values", {})
		var is_egg: bool = not values.has("pokemon")
		var species: int = int(values.get("pokemon", values.get("value", 0)))
		var level: int = int(values.get("level", values.get("value_2", 0)))
		var held_item: int = int(values.get("item", 0))
		if species <= 0 or world.data.species(species).is_empty():
			return {"ok": false, "reason": &"unknown_species", "species": species}
		if level < 1 or level > Gen2Experience.MAX_LEVEL:
			return {"ok": false, "reason": &"invalid_level", "level": level}
		if held_item < 0 or (held_item > 0 and world.data.item(held_item).is_empty()):
			return {"ok": false, "reason": &"unknown_item", "item": held_item}
		var mon: Gen2SaveMon = _new_mon(
			world.data, candidate, species, level, held_item, random, is_egg
		)
		if mon == null:
			return {"ok": false, "reason": &"could_not_create_pokemon"}
		## `AddPartyMon`'s three caught-data branches. An egg's is overwritten by
		## `SetEggMonCaughtData` when it hatches; a plain `givepoke` takes
		## `SetCaughtData`, the map the player is standing on.
		set_caught_data(
			mon, level, world.object_time_of_day, world.player_female(), world.landmark()
		)
		if is_egg:
			## `GiveEgg` is `TryAddMonToParty` and nothing else, so a full party
			## boxes no egg and leaves `Script_giveegg`'s own `xor a` in
			## wScriptVar; only the `ret nc` past it writes 2.
			if candidate.party.size() >= Gen2SaveData.MAX_PARTY:
				return {
					"ok": true, "accepted": false, "script_value": 0,
					"reason": &"party_full",
					"summary": {
						"kind": &"egg", "accepted": false,
						"species": species, "level": level,
					},
				}
			return _append_mon(candidate, mon, 2, {
				"kind": &"egg", "species": species, "level": level, "item": held_item,
			})
		var source: Dictionary = request.get("source", {})
		var bank: int = int(source.get("bank", -1))
		var nickname: String = _world_name(
			world.data, bank, int(values.get("nickname_address", -1))
		)
		var ot_name: String = _world_name(
			world.data, bank, int(values.get("ot_name_address", -1))
		)
		if not nickname.is_empty():
			mon.nickname = nickname
		if not ot_name.is_empty():
			mon.original_trainer = ot_name
			## `SetGiftPartyMonCaughtData`: a `givepoke` that names an OT is
			## somebody's present, so its level byte is zero and its
			## landmark is LANDMARK_GIFT rather than this map.
			set_caught_data(mon, 0, -1, world.player_female(), LANDMARK_GIFT)
		elif result.has("nickname"):
			## `GiveANickname_YesNo` and `InitNickname`: the `.wildmon` branch,
			## which is the thirteen `givepoke` sites that name no OT. The screen
			## drew the question and the naming keyboard, and NO answers with the
			## species name `.done` already left in the row.
			var chosen: String = String(result["nickname"]).strip_edges()
			if not chosen.is_empty():
				mon.nickname = chosen
		var appended: Dictionary = _append_mon(candidate, mon, 0, {
			"kind": &"gift", "species": species, "level": level, "item": held_item,
		})
		if not bool(appended.get("ok", false)):
			## `.FailedToGiveMon`'s `ld b, $2`: neither the party nor the box had
			## room, so nothing is written and the script reads 2 and runs on.
			if StringName(appended.get("reason", &"")) == &"storage_full":
				return {
					"ok": true, "accepted": false, "script_value": 2,
					"reason": &"storage_full",
					"summary": {
						"kind": &"gift", "accepted": false,
						"species": species, "level": level,
					},
				}
			return appended
		var destination: StringName = StringName(
			(appended["summary"]["destination"] as Dictionary).get("destination", &"party")
		)
		if destination == &"box":
			## `.skip_nickname`'s tail copies `wMonOrItemNameBuffer` over
			## `sBoxMonNicknames` after `InitNickname` has written the player's
			## entry, so a boxed gift always ends up with the species name.
			mon.nickname = String(world.data.species(species).get("name", ""))
			appended["script_value"] = 1
		return appended

	if kind == &"trade_requested":
		var values: Dictionary = request.get("values", {})
		var trade_id: int = int(values.get("trade_id", -1))
		var trade: Dictionary = world.data.world_trade(trade_id)
		if trade.is_empty():
			return {"ok": false, "reason": &"unknown_trade", "trade_id": trade_id}
		## A visible-catalog site may name its own two halves. Applied to this
		## call's COPY of the record: one cartridge trade row is named by more
		## than one site, and writing the row would move the other one too. The
		## nickname, OT, item and DVs stay the record's, since they belong to the
		## Pokemon the cartridge wrote rather than to the species.
		for half: Array in [
			["offered_species", "offered_species"], ["requested_species", "requested_species"],
		]:
			if values.has(half[0]) and int(values[half[0]]) > 0:
				trade[half[1]] = int(values[half[0]])
		var requested_index: int = int(result.get("party_index", -1))
		if requested_index < 0 or requested_index >= candidate.party.size():
			requested_index = _find_trade_candidate(world.data, candidate, trade)
		if requested_index < 0:
			return {
				"ok": true, "accepted": false, "script_value": 0,
				"reason": &"requested_pokemon_missing",
				"summary": {"kind": &"trade", "accepted": false, "trade_id": trade_id},
			}
		var requested: Gen2SaveMon = candidate.party[requested_index]
		if requested.species != int(trade["requested_species"]):
			return {"ok": false, "reason": &"trade_candidate_mismatch"}
		if not _trade_gender_matches(
			world.data, requested, int(trade.get("gender", RomLayout.TRADE_GENDER_EITHER))
		):
			return {"ok": false, "reason": &"trade_candidate_gender_mismatch"}
		var received: Gen2SaveMon = _new_mon(
			world.data, candidate, int(trade["offered_species"]), requested.level,
			int(trade["item"]), random, false, int(trade["dvs"])
		)
		if received == null:
			return {"ok": false, "reason": &"could_not_create_trade_pokemon"}
		received.nickname = String(trade.get("nickname", ""))
		received.original_trainer = String(trade.get("ot_name", ""))
		received.ot_id = int(trade.get("ot_id", 0))
		candidate.party[requested_index] = received
		return {
			"ok": true, "accepted": true, "script_value": 1,
			"register_caught": received.species,
			## A trade lands in the party slot the given Pokemon left, which is
			## the PARTYMON `GeneratePartyMonStats` registers.
			"register_unown": _unown_form(
				received.species, received.dvs, {"destination": &"party"}
			),
			"summary": {
				"kind": &"trade", "accepted": true, "trade_id": trade_id,
				"given_species": requested.species,
				"received_species": received.species,
			},
		}
	return {"ok": false, "reason": &"unsupported_party_request"}


## `AddPartyMon`'s `.registerpokedex`, which an egg never reaches: the source
## checks `cp EGG` first and jumps past `SetSeenAndCaughtMon`, so a Pokemon is
## unknown to the dex until it hatches.
static func _append_mon(
	candidate: Gen2SaveData, mon: Gen2SaveMon,
	script_value: int, summary: Dictionary
) -> Dictionary:
	var destination: Dictionary = candidate.add_party_or_box(mon)
	if not bool(destination.get("ok", false)):
		return {
			"ok": false,
			"reason": destination.get("reason", &"storage_full"),
			"destination": destination,
		}
	return {
		"ok": true, "accepted": true, "script_value": script_value,
		"register_caught": 0 if StringName(summary.get("kind", &"")) == &"egg" else mon.species,
		"register_unown": 0 if mon.is_egg else _unown_form(mon.species, mon.dvs, destination),
		"summary": summary.merged({
			"accepted": true, "destination": destination.duplicate(true),
		}),
	}


## `SetSeenAndCaughtMon`. Written straight onto the live state rather than
## staged, the way the ball count is, and always after the caller has taken its
## rollback snapshot so a refused save takes the flag back too.
static func _register_caught(world: Gen2WorldAPI, species: int) -> void:
	if world == null or world.state == null or species <= 0:
		return
	world.state.set_species_caught(species)


## `GeneratePartyMonStats`' `.registerunowndex`. The form is read off the DVs
## rather than stored, and only a Pokemon that reached the party registers: the
## routine runs under `wMonType` PARTYMON alone, so an Unown caught with a full
## party is caught without entering the Unown dex.
static func _unown_form(species: int, dvs: int, destination: Dictionary) -> int:
	if species != RomLayout.UNOWN_SPECIES:
		return 0
	if StringName(destination.get("destination", &"")) != &"party":
		return 0
	return Gen2Stats.unown_letter(dvs)


## Written straight onto the live state beside [method _register_caught], and
## for the same reason: the caller has already taken the snapshot a refused save
## rolls back to.
static func _register_unown(world: Gen2WorldAPI, form: int) -> void:
	if world == null or world.state == null or form <= 0:
		return
	world.state.update_unown_dex(form)


static func _new_mon(
	data: GameData,
	save: Gen2SaveData,
	species: int,
	level: int,
	held_item: int,
	random: RandomNumberGenerator,
	is_egg: bool,
	dvs: int = -1
) -> Gen2SaveMon:
	var known_moves: Array = data.moves_at_level(species, level)
	var dv_word: int = Gen2BattleMon.random_dvs(random) if dvs < 0 else dvs
	var battle_mon: Gen2BattleMon = Gen2BattleMon.create(
		data, species, level, known_moves, dv_word, {}, held_item
	)
	if battle_mon == null:
		return null
	var out: Gen2SaveMon = Gen2SaveBattleAdapter.from_battle_mon(battle_mon)
	out.nickname = String(data.species(species).get("name", ""))
	out.original_trainer = save.player_name
	out.is_egg = is_egg
	if is_egg:
		out.nickname = "EGG"
		out.hp = 0
		# `GiveEgg`'s `ld a, [wBaseEggSteps] / ld [hl], a`: an egg's happiness
		# byte is its hatch counter, and `DoEggStep` spends one of it per 256
		# steps. The debug branch above it writes 1 and is not reachable here.
		out.happiness = int(data.species(species).get("hatch_cycles", 0))
	return out


static func _find_trade_candidate(data: GameData, save: Gen2SaveData, trade: Dictionary) -> int:
	var requested_species: int = int(trade.get("requested_species", 0))
	var required_gender: int = int(trade.get("gender", RomLayout.TRADE_GENDER_EITHER))
	for index: int in save.party.size():
		var mon: Gen2SaveMon = save.party[index]
		if mon == null or mon.is_egg or mon.species != requested_species:
			continue
		if _trade_gender_matches(data, mon, required_gender):
			return index
	return -1


static func _trade_gender_matches(
	data: GameData, mon: Gen2SaveMon, required_gender: int
) -> bool:
	if required_gender == RomLayout.TRADE_GENDER_EITHER:
		return true
	var battle_mon: Gen2BattleMon = Gen2SaveBattleAdapter.to_battle_mon(data, mon)
	if battle_mon == null:
		return false
	if required_gender == RomLayout.TRADE_GENDER_MALE:
		return battle_mon.gender() == Gen2BattleMon.GENDER_MALE
	if required_gender == RomLayout.TRADE_GENDER_FEMALE:
		return battle_mon.gender() == Gen2BattleMon.GENDER_FEMALE
	return false


static func _apply_item_effect(
	data: GameData, save: Gen2SaveData, item: int, party_index: int
) -> Dictionary:
	var definition: Dictionary = data.item(item)
	if definition.is_empty():
		return {"ok": false, "reason": &"unknown_item", "item": item}
	if item in [ITEM_REPEL, ITEM_SUPER_REPEL, ITEM_MAX_REPEL]:
		return {
			"ok": true, "effect": &"repel",
			"repel_steps": 100 if item == ITEM_REPEL else (200 if item == ITEM_SUPER_REPEL else 250),
		}
	if item == Gen2WorldPack.ITEM_SACRED_ASH:
		return _apply_sacred_ash(data, save)
	if party_index < 0 or party_index >= save.party.size():
		return {"ok": false, "reason": &"party_member_required"}
	var mon: Gen2SaveMon = save.party[party_index]
	if mon == null or mon.is_egg:
		return {"ok": false, "reason": &"invalid_party_member"}
	var evolution: Dictionary = _apply_item_evolution(data, mon, item)
	if not evolution.is_empty():
		return evolution
	var vitamin: Dictionary = _apply_vitamin(data, mon, item)
	if not vitamin.is_empty():
		return vitamin
	var max_hp: int = _max_hp(data, mon)
	# `RevivePokemon`'s own `cp REVIVE / jr z, .revive_half_hp`: REVIVE is the
	# only half, so MAX_REVIVE and REVIVAL_HERB both reach `ReviveFullHP`.
	if item in [ITEM_REVIVE, ITEM_MAX_REVIVE, ITEM_REVIVAL_HERB]:
		if mon.hp > 0:
			return {"ok": false, "reason": &"item_has_no_effect"}
		mon.hp = maxi(max_hp / 2, 1) if item == ITEM_REVIVE else max_hp
		return _with_bitterness(
			data, mon, item, {"ok": true, "effect": &"revive", "healed": mon.hp}
		)

	var status_mask: int = int(definition.get("status_mask", 0))
	var heal_amount: int = int(definition.get("heal_amount", 0))
	var cleared: int = mon.status & status_mask
	var healed: int = 0
	if heal_amount > 0 and mon.hp > 0:
		var target_hp: int = max_hp if heal_amount >= Gen2Stats.MAX_STAT_VALUE else mini(
			max_hp, mon.hp + heal_amount
		)
		healed = target_hp - mon.hp
		mon.hp = target_hp
	if cleared != 0:
		mon.status &= ~status_mask
	if healed <= 0 and cleared == 0:
		return {"ok": false, "reason": &"item_has_no_effect"}
	return _with_bitterness(data, mon, item, {
		"ok": true, "effect": &"party_item", "healed": healed,
		"status_cleared": cleared,
	})


## `VitaminEffect`. The cap is a refusal rather than a clamp.
## `UpdateStatsAfterItem` is `CalcMonStats` writing `MON_MAXHP` and the five
## stats below it and nothing else, so an HP UP raises the maximum and heals
## nothing; here every one of those is derived from the stat experience, which
## leaves the raise and the happiness row as the whole effect.
static func _apply_vitamin(data: GameData, mon: Gen2SaveMon, item: int) -> Dictionary:
	if not VITAMINS.has(item):
		return {}
	var stat: String = VITAMINS[item]
	var raised: int = int(mon.stat_exp.get(stat, 0))
	if raised >= VITAMIN_CAP:
		return {"ok": false, "reason": &"item_has_no_effect"}
	mon.stat_exp[stat] = raised + VITAMIN_STEP
	mon.happiness = change_happiness(data, mon.happiness, Gen2Battle.HAPPINESS_USEDITEM)
	return {
		"ok": true, "effect": &"vitamin", "stat": stat,
		"stat_exp": int(mon.stat_exp[stat]), "happiness": mon.happiness,
	}


## The happiness half of `HealPowderEffect`, `EnergypowderEnergyRootCommon` and
## `RevivalHerbEffect`, which each run it only once their shared effect reports
## the item was used. Every other field item charges nothing.
static func _with_bitterness(
	data: GameData, mon: Gen2SaveMon, item: int, effect: Dictionary
) -> Dictionary:
	if not BITTER_ITEMS.has(item):
		return effect
	mon.happiness = change_happiness(data, mon.happiness, int(BITTER_ITEMS[item]))
	effect["bitter"] = true
	effect["happiness"] = mon.happiness
	return effect


## `_SacredAsh`: `CheckAnyFaintedMon` first, which skips eggs and stops at the
## first zero, and then `SacredAshScript`'s `special HealParty` over the whole
## party rather than over the fainted members alone.
static func _apply_sacred_ash(data: GameData, save: Gen2SaveData) -> Dictionary:
	var fainted: bool = false
	for mon: Gen2SaveMon in save.party:
		if mon != null and not mon.is_egg and mon.hp <= 0:
			fainted = true
			break
	if not fainted:
		return {"ok": false, "reason": &"item_has_no_effect"}
	var healed: int = 0
	for mon: Gen2SaveMon in save.party:
		if mon == null or mon.is_egg:
			continue
		var max_hp: int = _max_hp(data, mon)
		if max_hp <= 0:
			return {"ok": false, "reason": &"invalid_party_member"}
		healed += max_hp - mon.hp
		mon.hp = max_hp
		mon.status = Gen2Status.NONE
		for slot: int in Gen2SaveMon.MAX_MOVES:
			var move_number: int = int(mon.moves[slot])
			mon.pp[slot] = int(data.move(move_number).get("pp", 0)) if move_number > 0 else 0
	return {"ok": true, "effect": &"sacred_ash", "healed": healed}


## The one evolution a field item can cause. The method it runs is a fact on the
## item row rather than a callback: a defined item that names an
## [code]evolution[/code] method runs that method's predicate, and an item that
## names none is a cartridge stone, dispatched through `EvoStoneEffect` the way
## `.item` is. Everything past the predicate is shared, which is what keeps the
## adapter, the HP delta and the move offers in one place.
static func _apply_item_evolution(data: GameData, mon: Gen2SaveMon, item: int) -> Dictionary:
	var declared: Dictionary = data.item(item).get("evolution", {}) as Dictionary
	var method: int = int(declared.get("method", 0))
	if method == 0 and item not in Gen2Evolution.STONE_ITEMS:
		return {}
	var battle_mon: Gen2BattleMon = Gen2SaveBattleAdapter.to_battle_mon(data, mon)
	if battle_mon == null:
		return {}
	var row: Dictionary = {}
	match method:
		0, RomLayout.EVOLVE_ITEM:
			# `EvoStoneEffect`'s own `cp EVERSTONE / jr z, .NoEffect`, which is
			# where the stone path refuses one and `.item` does not: the check is
			# the item effect's rather than the predicate's, so a link or field
			# caller reaching `item_evolution` another way is not bound by it.
			if battle_mon.item == Gen2Evolution.EVERSTONE:
				return {}
			row = Gen2Evolution.item_evolution(
				data, battle_mon, int(declared.get("parameter", item))
			)
		RomLayout.EVOLVE_TRADE:
			row = Gen2Evolution.trade_evolution(data, battle_mon)
		_:
			return {}
	if row.is_empty():
		return {}
	return apply_evolution(data, mon, row)


## `.proceed` and everything past it: the species is replaced, `CalcMonStats`
## adds the max-HP delta, `UpdateSpeciesNameIfNotNicknamed` renames an
## un-nicknamed row and `LearnLevelMoves` offers what the new species knows at
## the level that triggered it. Shared, because the master loop reaches it from a
## level evolution and `EvoStoneEffect` from an item, and only the predicate in
## front of it differs.
static func apply_evolution(data: GameData, mon: Gen2SaveMon, row: Dictionary) -> Dictionary:
	if data == null or mon == null or row.is_empty():
		return {}
	var battle_mon: Gen2BattleMon = Gen2SaveBattleAdapter.to_battle_mon(data, mon)
	if battle_mon == null:
		return {}
	var result: Dictionary = Gen2Evolution.evolve(battle_mon, int(row.get("target", 0)))
	if result.is_empty():
		return {}
	var move_offers: Array[int] = []
	for move: int in data.moves_learned_at(battle_mon.species, battle_mon.level):
		if battle_mon.moves.has(move):
			continue
		if not battle_mon.learn_move(move):
			move_offers.append(move)
	var evolved_from: int = mon.species
	# `GetNickname` / `CopyName1` fill wStringBuffer2 BEFORE the species is
	# replaced, and both `EvolvingText` and `CongratulationsYourPokemonText` read
	# it, so the two boxes name what the Pokemon was called on the way in. Held
	# because the rename below is what the name would otherwise be read through.
	var evolving_name: String = mon.nickname if not mon.nickname.is_empty() \
		else String(data.species(evolved_from).get("name", ""))
	mon.species = battle_mon.species
	mon.nickname = Gen2Evolution.nickname_after_evolution(
		data, mon.nickname, evolved_from, mon.species
	)
	# `.trade`'s `xor a / ld [wTempMonItem], a`: a held requirement is spent by
	# the evolution it caused.
	if row.has("consumes_held_item"):
		mon.item = 0
		battle_mon.item = 0
	mon.moves = [0, 0, 0, 0]
	mon.pp = [0, 0, 0, 0]
	for slot: int in mini(battle_mon.moves.size(), Gen2SaveMon.MAX_MOVES):
		mon.moves[slot] = int(battle_mon.moves[slot])
		mon.pp[slot] = int(battle_mon.pp[slot])
	mon.exp = battle_mon.exp
	mon.hp = battle_mon.hp
	mon.status = battle_mon.status
	mon.happiness = battle_mon.happiness
	return {
		"ok": true,
		"effect": &"evolution",
		"old_species": int(result["old_species"]),
		"new_species": int(result["new_species"]),
		"evolving_name": evolving_name,
		# `.proceed`'s `SetSeenAndCaughtMon`, and `UpdateUnownDex` behind it: the
		# species a Pokemon became is caught, not only seen.
		"register_caught": mon.species,
		"register_unown": _unown_form(
			mon.species, mon.dvs, {"destination": &"party"}
		),
		"move_offers": move_offers,
	}


## A Park Ball thrown inside the Bug Catching Contest, which is a different
## transaction from [method capture_wild]: the ball comes out of
## `wParkBallsRemaining` rather than the bag, and what is caught goes to
## `wContestMon` rather than to the party or a box, so no save is touched and
## nothing can be refused for a full party.
##
## `BugContest_SetCaughtContestMon` asks before replacing a Pokemon already
## caught, so a hit while one is held answers `replace_offer` and leaves the
## state alone until the caller comes back with [method set_contest_mon].
static func capture_contest(
	world: Gen2WorldAPI, wild: Gen2BattleMon, random: RandomNumberGenerator = null
) -> Dictionary:
	if world == null or world.data == null or world.state == null or wild == null:
		return _failure(&"missing_capture_context", {})
	if world.state.park_balls() <= 0:
		return _failure(&"no_park_balls", {"ball": ITEM_PARK_BALL})
	var generator: RandomNumberGenerator = random if random != null else RandomNumberGenerator.new()
	if random == null:
		generator.randomize()
	world.state.set_park_balls(world.state.park_balls() - 1)
	var outcome: Dictionary = _capture_outcome(world.data, wild, ITEM_PARK_BALL, generator)
	var result: Dictionary = {
		"ok": true,
		"ball": ITEM_PARK_BALL,
		"quantity": world.state.park_balls(),
		"caught": bool(outcome["caught"]),
		"catch_rate": int(outcome["catch_rate"]),
		"wobbles": int(outcome["wobbles"]),
		"contest": true,
	}
	if not bool(outcome["caught"]):
		return result
	result["mon"] = contest_mon_from(wild)
	result["replace_offer"] = not world.state.contest_mon().is_empty()
	if not bool(result["replace_offer"]):
		world.state.set_contest_mon(result["mon"])
	return result


## `.generatestats`: the caught Pokemon as `ContestScore` reads it. The stats
## and DVs are the ones the wild was standing there with, which is what
## `GeneratePartyMonStats` builds for a `WILDMON`.
static func contest_mon_from(wild: Gen2BattleMon) -> Dictionary:
	return {
		"species": wild.species,
		"level": wild.level,
		"hp": wild.hp,
		"max_hp": wild.max_hp(),
		"attack": int(wild.stats.get("attack", 0)),
		"defense": int(wild.stats.get("defense", 0)),
		"speed": int(wild.stats.get("speed", 0)),
		"special_attack": int(wild.stats.get("sp_attack", 0)),
		"special_defense": int(wild.stats.get("sp_defense", 0)),
		"dvs": wild.dvs,
		"item": wild.item,
	}


static func _capture_outcome(
	data: GameData, wild: Gen2BattleMon, ball: int, random: RandomNumberGenerator
) -> Dictionary:
	if ball == ITEM_MASTER_BALL:
		return {"caught": true, "catch_rate": 255, "wobbles": 3}
	var species: Dictionary = data.species(wild.species)
	var catch_rate: int = clampi(int(species.get("catch_rate", 0)), 1, 255)
	match ball:
		ITEM_ULTRA_BALL:
			catch_rate = mini(catch_rate * 2, 255)
		## `GreatBallMultiplier` and `ParkBallMultiplier` are the same routine
		## written twice: catch rate times one and a half.
		ITEM_GREAT_BALL, ITEM_PARK_BALL:
			catch_rate = mini(catch_rate + int(catch_rate / 2.0), 255)
		ITEM_POKE_BALL:
			pass
	var max_hp: int = maxi(wild.max_hp(), 1)
	var current_hp: int = clampi(wild.hp, 1, max_hp)
	var final_rate: int = _source_hp_catch_rate(max_hp, current_hp, catch_rate)
	# This is the actual Gen 2 behavior: sleep and freeze add 10, while the
	# intended +5 for burn, poison and paralysis is skipped by the source bug.
	if Gen2Status.has(wild.status, Gen2Status.FREEZE) or Gen2Status.is_asleep(wild.status):
		final_rate = mini(final_rate + 10, 255)
	var caught: bool = random.randi_range(0, 255) <= final_rate
	return {
		"caught": caught,
		"catch_rate": final_rate,
		"wobbles": 3 if caught else _failed_wobbles(final_rate, random),
	}


static func _source_hp_catch_rate(max_hp: int, current_hp: int, catch_rate: int) -> int:
	# The cartridge shifts both operands by two only when 3 * max HP does not
	# fit in one byte. It then keeps the low byte, including the documented
	# high-HP overflow behavior, instead of using a wider modern formula.
	var three_max: int = 3 * max_hp
	var two_current: int = 2 * current_hp
	if (three_max >> 8) != 0:
		three_max >>= 2
		two_current >>= 2
	var divisor: int = maxi(three_max & 0xFF, 1)
	var current_part: int = maxi(two_current & 0xFF, 1)
	var remaining: int = maxi((three_max & 0xFF) - current_part, 0)
	return clampi(maxi(1, int(remaining * catch_rate / float(divisor))), 1, 255)


static func _failed_wobbles(catch_rate: int, random: RandomNumberGenerator) -> int:
	var chance: int = 63
	for row: Array in WOBBLE_PROBABILITIES:
		if catch_rate <= int(row[0]):
			chance = int(row[1])
			break
	for wobble: int in 3:
		if random.randi_range(0, 255) >= chance:
			return wobble + 1
	return 3


static func _captured_mon(
	data: GameData,
	save: Gen2SaveData,
	wild: Gen2BattleMon,
	random: RandomNumberGenerator
) -> Gen2SaveMon:
	var out: Gen2SaveMon = Gen2SaveBattleAdapter.from_battle_mon(wild)
	if out == null:
		return null
	out.hp = wild.max_hp()
	out.status = Gen2Status.NONE
	out.nickname = String(data.species(wild.species).get("name", ""))
	out.original_trainer = save.player_name
	out.ot_id = random.randi_range(0, 0xFFFF)
	out.happiness = 70
	out.is_egg = false
	return out


## `SetBoxmonOrEggmonCaughtData`, the three bytes every caught or hatched
## Pokemon carries. All three are the trainer's rather than the Pokemon's: the
## gender bit is `wPlayerGender` and not the caught mon's, which is what the
## "caught by" line reads back, and the level is CAUGHT_EGG_LEVEL for a hatch.
static func set_caught_data(
	mon: Gen2SaveMon, level: int, time_of_day: int, player_female: bool, landmark: int
) -> void:
	if mon == null:
		return
	mon.caught_level = clampi(level, 0, 63)
	# `ld a, [wTimeOfDay] / inc a`: the field holds MORN as 1, so the -1 a gift
	# passes is the cartridge's own `xor a` over both halves of the byte.
	mon.caught_time = clampi(time_of_day + 1, 0, 3)
	mon.caught_gender = 1 if player_female else 0
	mon.caught_location = clampi(landmark, 0, 127)


## `_NameRater`'s own `CopyBytes` into `wPartyMonNicknames`, which is the one
## write the routine makes. Kept here rather than in the screen that asks for it:
## every caller of `_NamingScreen` over a party row lands on this same copy.
static func rename_party_mon(
	save: Gen2SaveData, party_index: int, nickname: String
) -> Dictionary:
	if save == null:
		return {"ok": false, "reason": &"missing_save"}
	if party_index < 0 or party_index >= save.party.size():
		return {"ok": false, "reason": &"invalid_party_index"}
	var mon: Gen2SaveMon = save.party[party_index] as Gen2SaveMon
	if mon == null:
		return {"ok": false, "reason": &"invalid_party_index"}
	var settled: String = nickname.substr(0, Gen2NameRater.NICKNAME_LENGTH)
	if settled.is_empty():
		return {"ok": false, "reason": &"empty_nickname"}
	mon.nickname = settled
	return {"ok": true, "party_index": party_index, "nickname": settled}


## `HatchEggs` for one party slot: the egg becomes the Pokemon it was carrying.
## Everything here is the source's own order, and every one of the seven writes
## has a reader in this project, which is why none is left out.
##
## Answers the summary the screen shows, or an empty dictionary when the slot is
## not an egg that is ready.
static func hatch_egg(
	world: Gen2WorldAPI, save: Gen2SaveData, index: int
) -> Dictionary:
	if world == null or world.data == null or save == null:
		return {}
	if index < 0 or index >= save.party.size():
		return {}
	var mon: Gen2SaveMon = save.party[index] as Gen2SaveMon
	if mon == null or not mon.is_egg or mon.happiness != 0:
		return {}
	set_caught_data(
		mon, CAUGHT_EGG_LEVEL, world.object_time_of_day,
		world.player_female(), world.landmark()
	)
	mon.is_egg = false
	# `ld [hl], $78`: the counter the walk drained becomes the hatchling's own
	# base happiness, which is why the write happens before anything reads it.
	mon.happiness = HATCHED_HAPPINESS
	mon.status = Gen2Status.NONE
	mon.hp = _max_hp(world.data, mon)
	mon.ot_id = save.player_id
	mon.original_trainer = save.player_name
	mon.nickname = String(world.data.species(mon.species).get("name", ""))
	## `SetSeenAndCaughtMon`, which `GiveEgg` was careful to undo when the egg
	## arrived: the dex learns the species here and nowhere earlier.
	if world.state != null:
		world.state.set_species_caught(mon.species)
		if mon.species == SPECIES_TOGEPI:
			world.state.set_event_flag(EVENT_TOGEPI_HATCHED)
	return {
		"kind": &"hatch", "party_index": index, "species": mon.species,
		"level": mon.level, "nickname": mon.nickname,
	}


static func _max_hp(data: GameData, mon: Gen2SaveMon) -> int:
	var species: Dictionary = data.species(mon.species)
	var base: Dictionary = species.get("stats", {})
	return Gen2Stats.calculate(
		int(base.get("hp", 0)), Gen2Stats.hp_dv(mon.dvs), int(mon.stat_exp.get("hp", 0)),
		mon.level, true
	)


static func _world_name(data: GameData, bank: int, address: int) -> String:
	if bank < 0 or address < 0:
		return ""
	var bytes: PackedByteArray = data.world_text(bank, address)
	return Gen2Text.decode_fixed(bytes, 0, RomLayout.TRADE_NAME_LENGTH) if not bytes.is_empty() else ""


static func _failure(reason: StringName, details: Dictionary) -> Dictionary:
	return {"ok": false, "handled": false, "reason": reason, "details": details.duplicate(true)}


## `GivePokerusAndConvertBerries`, the line `ExitBattle` runs one after
## `EvolveAfterBattle`. Both halves are gated on
## `STATUSFLAGS2_REACHED_GOLDENROD_F`, and both are pure party writes, so the
## whole routine is one call the world boundary makes on a battle it won.
##
## Returns what changed, for a caller that wants to say so: an empty dictionary
## when neither half did anything.
static func give_pokerus_and_convert_berries(
	data: GameData, save: Gen2SaveData, world: Gen2WorldAPI,
	random: RandomNumberGenerator
) -> Dictionary:
	if save == null or random == null:
		return {}
	var reached: bool = world != null and world.state != null \
		and world.state.reached_goldenrod(Gen2WorldState.is_crystal_profile(data))
	var out: Dictionary = {}
	var juice: int = _convert_berries_to_berry_juice(save, reached, random)
	if juice >= 0:
		out["berry_juice_index"] = juice
	var infected: Dictionary = _give_pokerus(save, reached, random)
	if not infected.is_empty():
		out.merge(infected)
	return out


## `ConvertBerriesToBerryJuice`: a 1-in-16 roll, then the first SHUCKLE in the
## party holding a BERRY. The party index it converted, or -1.
static func _convert_berries_to_berry_juice(
	save: Gen2SaveData, reached_goldenrod: bool, random: RandomNumberGenerator
) -> int:
	if not reached_goldenrod or _random_byte(random) >= 16:
		return -1
	for index: int in save.party.size():
		var mon: Gen2SaveMon = save.party[index]
		if mon == null or mon.species != SHUCKLE or mon.item != ITEM_BERRY:
			continue
		mon.item = ITEM_BERRY_JUICE
		return index
	return -1


## The rest of `GivePokerusAndConvertBerries`: an active infection anywhere in
## the party is sampled for a spread and nothing else can happen, which is why
## no second Pokemon catches it de novo while one is still carrying it.
static func _give_pokerus(
	save: Gen2SaveData, reached_goldenrod: bool, random: RandomNumberGenerator
) -> Dictionary:
	var count: int = save.party.size()
	for index: int in count:
		var carrier: Gen2SaveMon = save.party[index]
		if carrier != null and (carrier.pokerus & 0x0F) != 0:
			return _try_spread_pokerus(save, index, random)
	if not reached_goldenrod:
		return {}
	## `Random` fills two bytes and both are read: 3 of 65,536.
	if _random_byte(random) != 0 or _random_byte(random) >= 3:
		return {}
	var target: int = _random_byte(random) & 0x7
	while target >= count:
		target = _random_byte(random) & 0x7
	var mon: Gen2SaveMon = save.party[target]
	if mon == null or (mon.pokerus & 0xF0) != 0:
		return {}
	## `.randomPokerusLoop` samples the strain and the duration out of one byte,
	## and rerolls a zero because that byte is the whole of both.
	var roll: int = _random_byte(random)
	while roll == 0:
		roll = _random_byte(random)
	mon.pokerus = pokerus_from_roll(roll)
	return {"pokerus_index": target, "pokerus": mon.pokerus}


## `.TrySpreadPokerus`: a 1-in-3 roll, then a walk away from the carrier in one
## direction. A party member that has already recovered (`and $3` zero with a
## strain still on it) stops the walk rather than being skipped.
static func _try_spread_pokerus(
	save: Gen2SaveData, carrier: int, random: RandomNumberGenerator
) -> Dictionary:
	if _random_byte(random) >= 85:
		return {}
	var count: int = save.party.size()
	if count <= 1:
		return {}
	var strain_source: int = save.party[carrier].pokerus
	## `ld a, b / cp 2 / jr c`: b is how many party members are left including
	## the carrier, so a carrier in the last slot can only walk backwards.
	var forwards: bool = carrier < count - 1 and _random_byte(random) >= 129
	var step: int = 1 if forwards else -1
	var index: int = carrier
	while true:
		index += step
		if index < 0 or index >= count:
			return {}
		var mon: Gen2SaveMon = save.party[index]
		if mon == null:
			return {}
		if mon.pokerus == 0:
			mon.pokerus = pokerus_spread_from(strain_source)
			return {"pokerus_index": index, "pokerus": mon.pokerus}
		if (mon.pokerus & 0x3) == 0:
			return {}
		strain_source = mon.pokerus
	return {}


## `.load_pkrs`: one byte is the whole of both halves. A high nibble of zero is
## strain zero, and the duration is read off the strain rather than off the byte,
## which is what the shared `and $3 / inc a` after the `swap b` does.
static func pokerus_from_roll(roll: int) -> int:
	var strain: int = 0 if (roll & 0xF0) == 0 else (roll & 0x7) + 1
	return ((strain << 4) & 0xF0) + (strain & 0x3) + 1


## `.infectMon`: the carrier's strain is kept and the duration is derived from
## that strain, so a spread never carries the carrier's remaining days.
static func pokerus_spread_from(carrier: int) -> int:
	return (carrier & 0xF0) + ((carrier >> 4) & 0x3) + 1


## One `Random` byte. The cartridge's own generator is not modelled; what
## matters at every call site above is the distribution and the number of draws.
static func _random_byte(random: RandomNumberGenerator) -> int:
	return random.randi_range(0, 0xFF)


## `ApplyPokerusTick`, which `CheckPokerusTick` runs with the days elapsed since
## the timer's start day: the low nibble is days remaining and floors at zero,
## and the strain nibble is kept, which is what stops a recovered Pokemon from
## catching it again. True when a byte moved.
static func apply_pokerus_tick(save: Gen2SaveData, days: int) -> bool:
	if save == null or days <= 0:
		return false
	var changed: bool = false
	for mon: Gen2SaveMon in save.party:
		if mon == null:
			continue
		var remaining: int = mon.pokerus & 0x0F
		if remaining == 0:
			continue
		mon.pokerus = (mon.pokerus & 0xF0) + maxi(remaining - days, 0)
		changed = true
	return changed


## `CalcMagikarpLength`, in feet and inches. [param dvs] is MON_DVS' two bytes
## and [param player_id] is wPlayerID, read high byte first the way the routine
## reads it.
##
## `.BCLessThanDE`'s `ret c / ret nc` is reproduced rather than fixed: the low
## byte is never reached, so the row is chosen on the threshold's high byte
## alone, which is what `MagikarpLengths`' own comment says the table really
## means. Fixing it would move every length in the game by up to a foot.
static func magikarp_length(dvs: PackedByteArray, player_id: int) -> Vector2i:
	var id_high: int = _rotate_right((player_id >> 8) & 0xFF)
	var id_low: int = _rotate_right(player_id & 0xFF)
	var b: int = (_rotate_right(_rotate_right(int(dvs[0]) if dvs.size() > 0 else 0))) ^ id_high
	var c: int = (_rotate_right(_rotate_right(int(dvs[1]) if dvs.size() > 1 else 0))) ^ id_low
	var bc: int = (b << 8) | c
	var millimetres: int = 0
	if b == 0 and c < 10:
		millimetres = bc + 190
	else:
		var matched: bool = false
		for row: int in MAGIKARP_LENGTHS.size():
			var threshold: int = int(MAGIKARP_LENGTHS[row][0])
			if b >= (threshold >> 8) & 0xFF:
				continue
			@warning_ignore("integer_division")
			var quotient: int = ((bc - threshold) & 0xFFFF) / int(MAGIKARP_LENGTHS[row][1])
			millimetres = (quotient & 0xFF) + 100 * (row + 2)
			matched = true
			break
		if not matched:
			## The walk fell off the end with the last row's threshold still in
			## de, which is the subtraction `.next` leaves standing.
			millimetres = ((bc - int(MAGIKARP_LENGTHS[MAGIKARP_LENGTHS.size() - 1][0])) & 0xFFFF) + 1600
	## mm to inches is `hl * 10 / 254`, and feet is that over twelve.
	@warning_ignore("integer_division")
	var inches: int = ((millimetres * 10) & 0xFFFF) / 254
	@warning_ignore("integer_division")
	return Vector2i(inches / 12, inches % 12)


## One `rrca`: an 8-bit rotate right through no carry.
static func _rotate_right(value: int) -> int:
	return ((value >> 1) | (value << 7)) & 0xFF


## `PrintMagikarpLength`'s own string: two `PrintNum`s with
## PRINTNUM_LEFTALIGN, so neither number is padded, between the feet and inch
## marks `gfx/font/feet_inches.2bpp` supplies.
static func magikarp_length_string(feet: int, inches: int) -> String:
	return "%d′%d″" % [feet, inches]


## `CompareBytes` over the two length bytes, which is a strict lexicographic
## test: an equal length is not a new record.
static func magikarp_beats_record(length: Vector2i, record: Dictionary) -> bool:
	var best_feet: int = int(record.get("feet", 0))
	if length.x != best_feet:
		return length.x > best_feet
	return length.y > int(record.get("inches", 0))


## `CheckForLuckyNumberWinners`, as one walk over the ID numbers the party
## mirror carries.
##
## [param stored_ids] and [param stored_species] are every box slot in one list,
## which is what the source's open-box pass plus its `.BoxesLoop` skipping
## `wCurBox` add up to. Answers `{script_value, species, in_storage}`, where a
## zero script value is the routine's own "found nothing" and leaves both boxes
## unprinted.
static func lucky_number_match(
	lucky_id: int, party_ids: Array, party_species: Array, party_eggs: Array,
	stored_ids: Array, stored_species: Array
) -> Dictionary:
	var best: int = 0
	var best_species: int = 0
	var in_storage: bool = false
	var wanted: String = "%05d" % (lucky_id & 0xFFFF)
	for slot: int in party_ids.size():
		if slot < party_species.size() and int(party_species[slot]) == Gen2WorldScriptRunner.SPECIES_EGG:
			continue
		if slot < party_eggs.size() and bool(party_eggs[slot]):
			continue
		var scored: int = _lucky_number_score(wanted, int(party_ids[slot]))
		if scored == 0 or (best != 0 and best < scored):
			continue
		best = scored
		best_species = int(party_species[slot]) if slot < party_species.size() else 0
		in_storage = false
	for slot: int in stored_ids.size():
		if slot < stored_species.size() and int(stored_species[slot]) == Gen2WorldScriptRunner.SPECIES_EGG:
			continue
		var boxed: int = _lucky_number_score(wanted, int(stored_ids[slot]))
		if boxed == 0 or (best != 0 and best < boxed):
			continue
		best = boxed
		best_species = int(stored_species[slot]) if slot < stored_species.size() else 0
		in_storage = true
	return {"script_value": best, "species": best_species, "in_storage": in_storage}


## `.CompareLuckyNumberToMonID`: both numbers printed with
## PRINTNUM_LEADINGZEROS over five digits and compared from the last digit
## backwards, stopping at the first that differs. Five digits is a first prize,
## three or four a second, two a third, and anything less is no match at all.
static func _lucky_number_score(wanted: String, mon_id: int) -> int:
	var theirs: String = "%05d" % (mon_id & 0xFFFF)
	var matched: int = 0
	for digit: int in range(4, -1, -1):
		if wanted[digit] != theirs[digit]:
			break
		matched += 1
	if matched == 5:
		return 1
	if matched >= 3:
		return 2
	if matched == 2:
		return 3
	return 0


## `GiveShuckle`. A level 15 SHUCKLE holding a BERRY, named SHUCKIE under
## MANIA's name and ID, with `SetGiftPartyMonCaughtData`'s CAUGHT_BY_UNKNOWN.
##
## `TryAddMonToParty` and nothing else: a full party is `.NotGiven`, which
## answers zero and never reaches a box. The daily flag behind it is the
## script's own `setflag`, which has already run by here.
static func _apply_give_shuckle(
	world: Gen2WorldAPI,
	candidate: Gen2SaveData,
	request: Dictionary,
	random: RandomNumberGenerator
) -> Dictionary:
	if candidate.party.size() >= Gen2SaveData.MAX_PARTY:
		return {
			"ok": true, "accepted": false, "script_value": 0, "reason": &"party_full",
			"summary": {"kind": &"shuckie", "accepted": false, "species": SHUCKLE},
		}
	var mon: Gen2SaveMon = _new_mon(
		world.data, candidate, SHUCKLE, SHUCKIE_LEVEL, ITEM_BERRY, random, false
	)
	if mon == null:
		return {"ok": false, "reason": &"could_not_create_pokemon"}
	set_caught_data(mon, 0, -1, world.player_female(), LANDMARK_GIFT)
	mon.ot_id = MANIA_OT_ID
	mon.original_trainer = MANIA_OT_NAME
	mon.nickname = SHUCKIE_NICKNAME
	var appended: Dictionary = _append_mon(candidate, mon, 1, {
		"kind": &"shuckie", "species": SHUCKLE, "level": SHUCKIE_LEVEL,
		"item": ITEM_BERRY,
	})
	if not bool(appended.get("ok", false)):
		return {
			"ok": true, "accepted": false, "script_value": 0, "reason": &"party_full",
			"summary": {"kind": &"shuckie", "accepted": false, "species": SHUCKLE},
		}
	return appended


## `GiveDratini`, which gives nothing: it walks the party backwards for the last
## DRATINI and overwrites its four move slots, each with that move's own full
## PP. Wrap, Thunder Wave, Twister and Extremespeed for the elder's answer, and
## a level 15 Dratini's own list for the other. Nothing is written when the
## party holds no Dratini, and the routine answers nothing either way.
const DRATINI_MOVESETS: Array = [
	[35, 86, 239, 245],
	[35, 43, 86, 239],
]


static func _apply_dratini_moveset(
	world: Gen2WorldAPI, candidate: Gen2SaveData, request: Dictionary
) -> Dictionary:
	var values: Dictionary = request.get("values", {})
	var moveset: int = clampi(int(values.get("moveset", 0)), 0, DRATINI_MOVESETS.size() - 1)
	var slot: int = -1
	for index: int in range(candidate.party.size() - 1, -1, -1):
		var member: Variant = candidate.party[index]
		if member is Gen2SaveMon and int((member as Gen2SaveMon).species) == SPECIES_DRATINI:
			slot = index
			break
	if slot < 0:
		return {
			"ok": true, "accepted": false, "script_value": 0, "reason": &"no_dratini",
			"summary": {"kind": &"dratini_moveset", "accepted": false},
		}
	var mon: Gen2SaveMon = candidate.party[slot]
	var taught: Array = []
	for move_slot: int in DRATINI_MOVESETS[moveset].size():
		var move: int = int(DRATINI_MOVESETS[moveset][move_slot])
		mon.moves[move_slot] = move
		mon.pp[move_slot] = int(world.data.move(move).get("pp", 0))
		taught.append(move)
	return {
		"ok": true, "accepted": true, "script_value": 0,
		"summary": {
			"kind": &"dratini_moveset", "accepted": true, "slot": slot, "moves": taught,
		},
	}
