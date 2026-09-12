class_name Gen1TrainerAI
extends RefCounted

## `engine/battle/trainer_ai.asm` and `SelectEnemyMove`: how a Generation 1
## opponent picks its move and what a class does in front of it. [Gen2BattleAI]
## is Crystal's, and no [Gen2Rules] flag reshapes this one.

## `wBuffer`'s starting score, the disabled slot's, and layer 1's nudge.
const BASE_SCORE: int = 10
const DISABLED_SCORE: int = 0x50
const STATUS_PENALTY: int = 5

## `.chooseRandomMove`'s three `cp`s over one byte: 64, 64, 63 and 65 of 256.
const SLOT_ROLL_BOUNDS: Array[int] = [64, 128, 191]
## A refused slot is rolled again; the cap only bounds a party with no slot.
const ROLL_CAP: int = 64

## `StatusAilmentMoveEffects`, the cartridge's own bytes (`gen1_effect`).
const STATUS_AILMENT_EFFECTS: Array[int] = [0x01, 0x20, 0x42, 0x43]
## `AIMoveChoiceModification2`'s two `cp` ranges: ATTACK_UP1 to BIDE and
## ATTACK_UP2 to POISON, each end exclusive.
const SETUP_RANGES: Array = [[0x0A, 0x1A], [0x32, 0x42]]
## `.loopMoves`' three effects, and `AIGetTypeEffectiveness`' initial `$10`
## where EFFECTIVE is 10: a chart row of 10 would read as resisted.
const SUPER_FANG_EFFECT: int = 0x28
const SPECIAL_DAMAGE_EFFECT: int = 0x29
const FLY_EFFECT: int = 0x2B
const EFFECTIVENESS_INITIAL: int = 0x10

## Items in Generation 1's numbering.
const FULL_RESTORE: int = 0x10
const HYPER_POTION: int = 0x12
const SUPER_POTION: int = 0x13
const POTION: int = 0x14
const FULL_HEAL: int = 0x34
const GUARD_SPEC: int = 0x37
const X_ATTACK: int = 0x41
const X_DEFEND: int = 0x42
const X_SPEED: int = 0x43
## `AIRecoverHP`'s three `ld b`s.
const POTION_AMOUNTS: Dictionary = {POTION: 20, SUPER_POTION: 50, HYPER_POTION: 200}

## `TrainerAIPointers`' routines as steps over one `Random` byte: `unless_*`
## are the `ret`s, `if_*` Agatha's `jp c`, `do` the `AIUse*` or the switch.
## `cooltrainer_f`'s `ret nc` is commented out, so its roll never applies.
const ROUTINES: Dictionary = {
	"generic": [],
	"juggler": [{"unless_roll": 65}, {"do": "switch"}],
	"blackbelt": [{"unless_roll": 32}, {"do": X_ATTACK}],
	"giovanni": [{"unless_roll": 65}, {"do": GUARD_SPEC}],
	"cooltrainer_m": [{"unless_roll": 65}, {"do": X_ATTACK}],
	"cooltrainer_f": [{"if_hp": 10, "do": HYPER_POTION}, {"unless_hp": 5}, {"do": "switch"}],
	"brock": [{"unless_status": true}, {"do": FULL_HEAL}],
	"misty": [{"unless_roll": 65}, {"do": X_DEFEND}],
	"lt_surge": [{"unless_roll": 65}, {"do": X_SPEED}],
	"erika": [{"unless_roll": 129}, {"unless_hp": 10}, {"do": SUPER_POTION}],
	"koga": [{"unless_roll": 65}, {"do": X_ATTACK}],
	"koga_yellow": [{"unless_roll": 32}, {"do": X_ATTACK}],
	"blaine": [{"unless_roll": 65}, {"do": SUPER_POTION}],
	"blaine_yellow": [{"unless_roll": 65}, {"unless_hp": 10}, {"do": SUPER_POTION}],
	"sabrina": [{"unless_roll": 65}, {"unless_hp": 10}, {"do": HYPER_POTION}],
	"sabrina_yellow": [{"unless_roll": 65}, {"do": X_DEFEND}],
	"rival2": [{"unless_roll": 32}, {"unless_hp": 5}, {"do": POTION}],
	"rival3": [{"unless_roll": 32}, {"unless_hp": 5}, {"do": FULL_RESTORE}],
	"lorelei": [{"unless_roll": 129}, {"unless_hp": 5}, {"do": SUPER_POTION}],
	"bruno": [{"unless_roll": 65}, {"do": X_DEFEND}],
	"agatha": [
		{"if_roll": 20, "do": "switch"}, {"unless_roll": 129}, {"unless_hp": 4},
		{"do": SUPER_POTION},
	],
	"lance": [{"unless_roll": 129}, {"unless_hp": 5}, {"do": HYPER_POTION}],
}

## `TrainerAI`'s `.done` tests on Yellow: the two status words' lock bits.
const LOCKED_SUBSTATUSES: Array[int] = [
	Gen2Substatus.CHARGING, Gen2Substatus.RAMPAGING, Gen2Substatus.BIDE, Gen2Substatus.RAGE,
]

## `wAICount`'s fresh value, replaced by the class's count on the first pass.
const COUNT_UNLOADED: int = -1


## `SelectEnemyMove` from `.canSelectMove` on. The locks in front of it keep
## the old choice on the cartridge; here [method Gen2Battle.move_for] answers
## for a locked Pokémon whatever slot it is asked for.
static func select_slot(battle: Gen2Battle, rng: RandomNumberGenerator) -> int:
	var enemy: Gen2BattleMon = battle.mon(Gen2Battle.ENEMY)
	if enemy.moves.size() < 2 or int(enemy.moves[1]) == 0:
		return 0
	var enabled: Array = enabled_slots(battle) if battle.is_trainer_battle \
		else _existing_slots(enemy)
	for _attempt: int in ROLL_CAP:
		var slot: int = roll_slot(rng)
		if slot == enemy.disabled_slot or slot >= enemy.moves.size():
			continue
		if int(enemy.moves[slot]) == 0 or not bool(enabled[slot]):
			continue
		return slot
	return 0


## `.chooseRandomMove`'s one byte against its three bounds.
static func roll_slot(rng: RandomNumberGenerator) -> int:
	var roll: int = rng.randi_range(0, 255)
	for slot: int in SLOT_ROLL_BOUNDS.size():
		if roll < SLOT_ROLL_BOUNDS[slot]:
			return slot
	return SLOT_ROLL_BOUNDS.size()


static func _existing_slots(enemy: Gen2BattleMon) -> Array:
	var out: Array = []
	for slot: int in Gen2BattleMon.MAX_MOVES:
		out.append(slot < enemy.moves.size() and int(enemy.moves[slot]) != 0)
	return out


## `AIEnemyTrainerChooseMoves`: the slots the layers leave at the lowest score.
static func enabled_slots(battle: Gen2Battle) -> Array:
	var enemy: Gen2BattleMon = battle.mon(Gen2Battle.ENEMY)
	var layers: Array = _attributes(battle).get("ai_layers", [])
	if layers.is_empty():
		return _existing_slots(enemy)
	var scores: Array = score_slots(battle, layers)
	var lowest: int = DISABLED_SCORE + 1
	for slot: int in _move_count(enemy):
		lowest = mini(lowest, int(scores[slot]))
	var out: Array = []
	for slot: int in Gen2BattleMon.MAX_MOVES:
		out.append(slot < _move_count(enemy) and int(scores[slot]) == lowest)
	return out


## The four scores after every layer in [param layers] has run.
static func score_slots(battle: Gen2Battle, layers: Array) -> Array:
	var enemy: Gen2BattleMon = battle.mon(Gen2Battle.ENEMY)
	var scores: Array = [BASE_SCORE, BASE_SCORE, BASE_SCORE, BASE_SCORE]
	if enemy.disabled_slot >= 0 and enemy.disabled_slot < scores.size():
		scores[enemy.disabled_slot] = DISABLED_SCORE
	for layer: int in layers:
		match layer:
			1:
				_discourage_status_moves(battle, scores)
			2:
				_encourage_setup_moves(battle, scores)
			3:
				_weigh_type_matchups(battle, scores)
	return scores


## `.loopDecrementEntries` stops at the first empty slot.
static func _move_count(enemy: Gen2BattleMon) -> int:
	for slot: int in enemy.moves.size():
		if int(enemy.moves[slot]) == 0:
			return slot
	return enemy.moves.size()


static func _attributes(battle: Gen2Battle) -> Dictionary:
	if battle.data == null or battle.enemy_trainer_class <= 0:
		return {}
	return battle.data.trainer_attributes(battle.enemy_trainer_class)


static func _move(battle: Gen2Battle, number: int) -> Dictionary:
	return battle.data.move(number) if battle.data != null else {}


## `AIMoveChoiceModification1`.
static func _discourage_status_moves(battle: Gen2Battle, scores: Array) -> void:
	if battle.mon(Gen2Battle.PLAYER).status == Gen2Status.NONE:
		return
	var enemy: Gen2BattleMon = battle.mon(Gen2Battle.ENEMY)
	for slot: int in _move_count(enemy):
		var move: Dictionary = _move(battle, int(enemy.moves[slot]))
		if int(move.get("power", 0)) != 0:
			continue
		if STATUS_AILMENT_EFFECTS.has(int(move.get("gen1_effect", -1))):
			scores[slot] = int(scores[slot]) + STATUS_PENALTY


## `AIMoveChoiceModification2`, the opponent's second move alone.
static func _encourage_setup_moves(battle: Gen2Battle, scores: Array) -> void:
	if battle.gen1_enemy_moves != 1:
		return
	var enemy: Gen2BattleMon = battle.mon(Gen2Battle.ENEMY)
	for slot: int in _move_count(enemy):
		var effect: int = int(_move(battle, int(enemy.moves[slot])).get("gen1_effect", -1))
		for range_pair: Array in SETUP_RANGES:
			if effect >= int(range_pair[0]) and effect < int(range_pair[1]):
				scores[slot] = int(scores[slot]) - 1
				break


## `AIMoveChoiceModification3`.
static func _weigh_type_matchups(battle: Gen2Battle, scores: Array) -> void:
	var enemy: Gen2BattleMon = battle.mon(Gen2Battle.ENEMY)
	var player_types: Array = battle.mon(Gen2Battle.PLAYER).types()
	for slot: int in _move_count(enemy):
		var move: Dictionary = _move(battle, int(enemy.moves[slot]))
		var effectiveness: int = battle.data.first_matchup(int(move.get("type", 0)), player_types)
		if effectiveness < 0:
			effectiveness = EFFECTIVENESS_INITIAL
		if effectiveness == EFFECTIVENESS_INITIAL:
			continue
		if effectiveness > EFFECTIVENESS_INITIAL:
			scores[slot] = int(scores[slot]) - 1
		elif _has_better_move(battle, enemy, int(move.get("type", 0))):
			scores[slot] = int(scores[slot]) + 1


## `.loopMoves`, which walks the weighed move too and counts it by effect.
static func _has_better_move(battle: Gen2Battle, enemy: Gen2BattleMon, type: int) -> bool:
	for slot: int in _move_count(enemy):
		var move: Dictionary = _move(battle, int(enemy.moves[slot]))
		var effect: int = int(move.get("gen1_effect", -1))
		if effect in [SUPER_FANG_EFFECT, SPECIAL_DAMAGE_EFFECT, FLY_EFFECT]:
			return true
		if int(move.get("type", 0)) != type and int(move.get("power", 0)) != 0:
			return true
	return false


## `TrainerAI`: the item or switch taken instead of the move as a [Gen2Battle]
## action, or empty for a turn the class lets the move through.
static func trainer_action(battle: Gen2Battle, rng: RandomNumberGenerator) -> Dictionary:
	if not battle.is_trainer_battle or battle.is_link_battle or battle.gen1_ai_count == 0:
		return {}
	if battle.data != null and Gen1Layout.trainer_ai_respects_lock(battle.data.id) \
		and _locked(battle.mon(Gen2Battle.ENEMY)):
		return {}
	var attributes: Dictionary = _attributes(battle)
	if attributes.is_empty():
		return {}
	if battle.gen1_ai_count == COUNT_UNLOADED:
		battle.gen1_ai_count = int(attributes.get("ai_count", 0))
	var roll: int = rng.randi_range(0, 255)
	var enemy: Gen2BattleMon = battle.mon(Gen2Battle.ENEMY)
	for step: Dictionary in ROUTINES.get(String(attributes.get("ai_routine", "")), []):
		if _step_returns(step, enemy, roll):
			return {}
		if _step_taken(step, enemy, roll) and step.has("do"):
			return _do(battle, step["do"])
	return {}


## The `ret`s.
static func _step_returns(step: Dictionary, enemy: Gen2BattleMon, roll: int) -> bool:
	if step.has("unless_roll") and roll >= int(step["unless_roll"]):
		return true
	if step.has("unless_hp") and not _hp_below(enemy, int(step["unless_hp"])):
		return true
	return step.has("unless_status") and enemy.status == Gen2Status.NONE


## The conditional jumps, passed over when their test fails.
static func _step_taken(step: Dictionary, enemy: Gen2BattleMon, roll: int) -> bool:
	if step.has("if_roll") and roll >= int(step["if_roll"]):
		return false
	return not (step.has("if_hp") and not _hp_below(enemy, int(step["if_hp"])))


static func _locked(enemy: Gen2BattleMon) -> bool:
	for flag: int in LOCKED_SUBSTATUSES:
		if Gen2Substatus.has(enemy.substatus, flag):
			return true
	return false


## `AICheckIfHPBelowFraction`, the quotient truncated.
static func _hp_below(enemy: Gen2BattleMon, fraction: int) -> bool:
	@warning_ignore("integer_division")
	return enemy.hp < enemy.max_hp() / fraction


## A switch spends no count: `SwitchEnemyMon` skips `DecrementAICount`.
static func _do(battle: Gen2Battle, what: Variant) -> Dictionary:
	if what is String:
		var index: int = switch_target(battle.party(Gen2Battle.ENEMY))
		return Gen2Battle.switch_to(index) if index >= 0 else {}
	battle.gen1_ai_count -= 1
	return Gen2Battle.use_item(int(what))


## `AISwitchIfEnoughMons`, then `EnemySendOutFirstMon`'s `.next2`: the first
## standing member that is not out, or -1.
static func switch_target(party: Gen2Party) -> int:
	if party.healthy_count() < 2:
		return -1
	for index: int in party.size():
		var member: Gen2BattleMon = party.at(index)
		if index != party.active and member != null and not member.is_fainted():
			return index
	return -1


## The `AIUse*` half, in the shape [method Gen2AIItems.apply] answers. Guard
## Spec raises Mist whether or not it stands; an X item is
## `StatModifierUpEffect` over the enemy.
static func apply_item(battle: Gen2Battle, user: Gen2BattleMon, item: int) -> Dictionary:
	if POTION_AMOUNTS.has(item):
		return {"healed": user.heal(int(POTION_AMOUNTS[item]))}
	if item == FULL_RESTORE:
		var cured: bool = _cure_status(user)
		return {"healed": user.heal(user.max_hp()), "cured": cured}
	if item == FULL_HEAL:
		return {"cured": _cure_status(user)}
	if item == GUARD_SPEC:
		user.substatus |= Gen2Substatus.MIST
		return {"substatus": Gen2Substatus.MIST}
	var raised: Dictionary = battle.apply_x_item(user, item)
	return {"stat": String(raised.get("stat", "")), "raised": bool(raised.get("ok", false))}


## `AICureStatus`: the status byte and `BADLY_POISONED`.
static func _cure_status(user: Gen2BattleMon) -> bool:
	var had: bool = user.status != Gen2Status.NONE
	user.status = Gen2Status.NONE
	user.toxic_counter = 0
	return had
