class_name Gen2BattleAI
extends RefCounted

## Scores an enemy trainer's move choice the way the cartridge's own AI does.
##
## Every slot starts at 20, or 80 with no PP. Each bit set in the trainer class's
## [constant RomLayout.ATTR_AI_MOVE_WEIGHTS] word runs one scoring layer over the
## four slots in the cartridge's bit order ([constant RomLayout.AI_BASIC] through
## [constant RomLayout.AI_RISKY]), nudging scores up (discourage) or down
## (encourage). Lowest score wins, ties broken at random.
##
## [RefCounted], scene-free, randomness injected, so a whole decision can be
## asserted on in a test.
##
## `engine/battle/ai/scoring.asm` finds that minimum by decrementing every slot's
## counter per pass until one reaches zero, then walking backward to give tied
## slots the same outcome. That is an argmin without a MIN instruction, not a
## rule of its own, so [method choose_slot] takes the minimum directly.
##
## Percent chances use the cartridge's `X * 255 / 100` macro rather than the odd
## byte a few call sites adjust by one; the difference is one part in 256.
##
## Every row of `AI_Redundant` and of `AI_Smart`'s own jumptable has a handler;
## `tests/unit/test_ai.gd` pins the latter against the source table.

## Everything one scoring layer is allowed to read, gathered once so a handler
## takes the fact it needs rather than a thirteenth positional argument.
## The cartridge reads all of this straight out of WRAM; this is that page.
class Context extends RefCounted:
	var attacker: Gen2BattleMon = null
	var defender: Gen2BattleMon = null
	var data: GameData = null
	var rng: RandomNumberGenerator = null
	var atk_turns: int = 0
	var def_turns: int = 0
	var weather: int = Gen2Weather.NONE
	var attacker_screens: int = Gen2Screens.NONE
	var defender_screens: int = Gen2Screens.NONE
	var has_bench: bool = false
	var matchup_score: int = Gen2AISwitch.BASE_SCORE
	## `AICheckLastPlayerMon`: whether the player still has somebody behind the
	## one that is out.
	var defender_has_bench: bool = false
	## `wPlayerUsedMoves`, oldest first, which is what Counter, Mirror Coat and
	## `AI_Smart_Unused2B` walk.
	var defender_used_moves: Array[int] = []
	## `AI_Smart_HealBell` ors every living party member's status byte together,
	## including the one that is out.
	var bench_status_mask: int = Gen2Status.NONE

	## The same argument list [method Gen2BattleAI.score_slots] takes, so one
	## layer can be run on its own without restating the whole page.
	static func of(
		attacker: Gen2BattleMon,
		defender: Gen2BattleMon,
		data: GameData,
		rng: RandomNumberGenerator,
		atk_turns: int = 0,
		def_turns: int = 0,
		weather: int = Gen2Weather.NONE,
		attacker_screens: int = Gen2Screens.NONE,
		defender_screens: int = Gen2Screens.NONE,
		has_bench: bool = false,
		matchup_score: int = Gen2AISwitch.BASE_SCORE,
		defender_has_bench: bool = false,
		defender_used_moves: Array = [],
		bench_status_mask: int = Gen2Status.NONE
	) -> Context:
		var out := Context.new()
		out.attacker = attacker
		out.defender = defender
		out.data = data
		out.rng = rng
		out.atk_turns = atk_turns
		out.def_turns = def_turns
		out.weather = weather
		out.attacker_screens = attacker_screens
		out.defender_screens = defender_screens
		out.has_bench = has_bench
		out.matchup_score = matchup_score
		out.defender_has_bench = defender_has_bench
		out.defender_used_moves.assign(defender_used_moves)
		out.bench_status_mask = bench_status_mask
		return out


## A move nobody can use, whatever the layers think of it.
const DEFAULT_SCORE: int = 20
const UNUSABLE_SCORE: int = 80

## What [code]AIDiscourageMove[/code] adds: a move that is actively a bad idea
## right now, short of being unusable outright.
const DISCOURAGE_MOVE: int = 10

## The status conditions [constant RomLayout.AI_BASIC] will not stack a second
## of onto a target that already carries one, because the cartridge's own
## status byte refuses a second status the same way [Gen2Status] does.
const STATUS_ONLY_EFFECTS: Array = [
	Gen2MoveEffect.SLEEP, Gen2MoveEffect.TOXIC, Gen2MoveEffect.POISON, Gen2MoveEffect.PARALYZE,
]

## [constant RomLayout.AI_AGGRESSIVE] does not punish a move for dealing less
## damage than the hardest hitter if losing the mon over it is the point.
## Effect bytes, not moves: Selfdestruct and Explosion share one, and so do
## every double and multi-hit move.
const RECKLESS_EFFECTS: Array = [7, 27, 29, 44] # SELFDESTRUCT, RAMPAGE, MULTI_HIT, DOUBLE_HIT

## [constant RomLayout.AI_RISKY] treats these two as a special case: a move
## that faints the user (Selfdestruct, Explosion) or skips the damage formula
## for a guaranteed kill (Horn Drill, Fissure, Guillotine, Sheer Cold) is worth
## holding back on unless already hurt.
const RISKY_EFFECTS: Array = [7, 38] # SELFDESTRUCT, OHKO

## [constant RomLayout.AI_OPPORTUNIST] discourages these particular moves, by
## number, once its own HP is low: `data/battle/ai/stall_moves.asm` in
## pokecrystal. Every one of them either does nothing to the opponent's HP or
## buys time, which is a poor trade when the trade might not come.
const STALL_MOVE_NUMBERS: Array = [
	14, 39, 43, 45, 50, 54, 68, 73, 74, 81, 96, 97, 99, 102, 103, 106, 110, 111, 112, 113, 114,
	115, 116, 117, 133, 144, 150, 151, 159, 160, 164, 172,
]

## The screen each of the three screen moves would raise, which is the whole of
## `AI_Redundant`'s `.LightScreen`, `.Reflect` and `.Safeguard`.
const SCREEN_FOR_EFFECT: Dictionary = {
	Gen2MoveEffect.LIGHT_SCREEN: Gen2Screens.LIGHT_SCREEN,
	Gen2MoveEffect.REFLECT: Gen2Screens.REFLECT,
	Gen2MoveEffect.SAFEGUARD: Gen2Screens.SAFEGUARD,
}

## The weather each of the three weather moves would set, which is the whole of
## `AI_Redundant`'s `.RainDance`, `.SunnyDay` and `.Sandstorm`: a move that would
## set the weather already up is a wasted turn.
const WEATHER_FOR_EFFECT: Dictionary = {
	Gen2MoveEffect.RAIN_DANCE: Gen2Weather.RAIN,
	Gen2MoveEffect.SUNNY_DAY: Gen2Weather.SUN,
	Gen2MoveEffect.SANDSTORM: Gen2Weather.SANDSTORM,
}

## `RainDanceMoves` and `SunnyDayMoves`: what makes each of the two worth
## setting, by move number. Neither list is what a player would write, and the
## Sunny Day one is missing Solarbeam, Flame Wheel and Moonlight outright, which
## `docs/bugs_and_glitches.md` records as a bug rather than a choice.
const RAIN_DANCE_MOVE_NUMBERS: Array = [55, 56, 57, 61, 87, 127, 128, 145, 152, 190, 250]
const SUNNY_DAY_MOVE_NUMBERS: Array = [7, 52, 53, 83, 126, 221, 234, 235]

## `UsefulMoves`, the source table Mirror Move consults before its two
## encouragement rolls.
const USEFUL_MOVE_NUMBERS: Array[int] = [
	38, 47, 53, 56, 57, 58, 59, 63, 79, 85, 87, 89, 92, 94, 95, 105, 126, 135, 162,
]

## `.SandstormImmuneTypes`, which is the same three types the damage itself
## exempts.
const SANDSTORM_IMMUNE_TYPES: Array = Gen2Weather.SANDSTORM_EXEMPT_TYPES

## [constant RomLayout.AI_CAUTIOUS] discourages these once it is no longer the
## first turn, because a move whose value is a residual effect (Leech Seed,
## Toxic-family status, a screen) has usually already paid for itself or not
## at all by then: `data/battle/ai/residual_moves.asm` in pokecrystal.
const RESIDUAL_MOVE_NUMBERS: Array = [54, 73, 77, 78, 86, 116, 117, 139, 144, 160, 164, 191]


## What the enemy does with its turn: pull its Pokémon out, reach for an item, or
## use a move.
##
## `AI_SwitchOrTryItem`, which runs before the turn and settles ahead of it.
## Switching is considered first and an item only when it is refused, which is
## the cartridge's `DontSwitch` fallthrough rather than a separate decision.
##
## Answers a [Gen2Battle] action dictionary. [param item_switch_flags] is the
## class's own [constant RomLayout.ATTR_AI_ITEM_SWITCH] word, and
## [param move_slot] is what [method choose_slot] already picked, used when
## nothing else is worth doing.
static func choose_action(
	battle: Gen2Battle, item_switch_flags: int, move_slot: int, rng: RandomNumberGenerator
) -> Dictionary:
	if not battle.is_trainer_battle:
		return Gen2Battle.use_move(move_slot)

	# `CheckEnemyLockedIn`, which returns out of the whole routine: a Pokémon
	# mid-charge, mid-rampage or recharging neither switches nor is handed an
	# item.
	if _locked_in(battle.mon(Gen2Battle.ENEMY)):
		return Gen2Battle.use_move(move_slot)

	if _can_leave(battle):
		var switch: Dictionary = Gen2AISwitch.decide(battle, item_switch_flags, rng)
		if bool(switch["switch"]):
			return Gen2Battle.switch_to(int(switch["index"]))

	if not battle.enemy_items.is_empty() \
			and Gen2AIItems.is_highest_level(battle.party(Gen2Battle.ENEMY)):
		var item: int = Gen2AIItems.choose(
			battle.mon(Gen2Battle.ENEMY), battle.enemy_items, item_switch_flags,
			battle.mon(Gen2Battle.ENEMY).turns_taken, rng
		)
		if item != 0:
			return Gen2Battle.use_item(item)

	return Gen2Battle.use_move(move_slot)


## The two things that jump straight to `DontSwitch` without stopping the item
## half: a Mean Look the player landed, and a wrap the enemy is caught in.
static func _can_leave(battle: Gen2Battle) -> bool:
	if Gen2Substatus.has(battle.mon(Gen2Battle.PLAYER).substatus, Gen2Substatus.CANT_RUN):
		return false
	return battle.mon(Gen2Battle.ENEMY).trapped_turns <= 0


## `CheckEnemyLockedIn`: the four substatus bits its three tests read, BIDE
## among them (`wEnemySubStatus3`'s `1 << SUBSTATUS_BIDE`). A trainer storing
## Bide picks no move and does not switch.
static func _locked_in(mon: Gen2BattleMon) -> bool:
	for flag: int in [
		Gen2Substatus.RECHARGING, Gen2Substatus.CHARGING,
		Gen2Substatus.RAMPAGING, Gen2Substatus.ROLLOUT, Gen2Substatus.BIDE,
	]:
		if Gen2Substatus.has(mon.substatus, flag):
			return true
	return false


## Picks a move slot for [param attacker] to use against [param defender], the
## way [param ai_move_weights] (a trainer class's own
## [constant RomLayout.ATTR_AI_MOVE_WEIGHTS]) says to score it.
##
## [param attacker_turns_taken] and [param defender_turns_taken] are
## `wEnemyTurnsTaken` and `wPlayerTurnsTaken`, each side's own
## [member Gen2BattleMon.turns_taken] read before the turn is spent, which is
## when the cartridge's AI reads them too. Every handler that wants them wants
## the same thing: whether this is the Pokémon's first turn out.
##
## [param weather] is [member Gen2Battle.weather], and the two screen words are
## [member Gen2Battle.screens] for each side. [param attacker_screens] is the
## AI's own, which is the `wEnemyScreens` every `AI_Redundant` screen row reads;
## [param defender_screens] is the player's, which is what its Confuse row and
## its damage estimate read.
##
## [param has_bench] and [param matchup_score] are the two routines the smart
## layer farcalls out of a handler rather than reads off a battler:
## `FindAliveEnemyMons`, which is whether the AI has anybody left to send, and
## `CheckPlayerMoveTypeMatchups`, which is `wEnemyAISwitchScore` and is
## [method Gen2AISwitch.matchup_score] here. Both are supplied the way
## [param weather] is, since this routine scores a pairing rather than a battle;
## the defaults are the neutral states, a lone Pokémon and an unnudged score.
##
## Always returns a slot in range: [method Gen2Battle.move_for] turns an
## unusable slot into Struggle, so no empty-moveset case is needed here.
static func choose_slot(
	attacker: Gen2BattleMon,
	defender: Gen2BattleMon,
	data: GameData,
	ai_move_weights: int,
	rng: RandomNumberGenerator,
	attacker_turns_taken: int = 0,
	defender_turns_taken: int = 0,
	weather: int = Gen2Weather.NONE,
	attacker_screens: int = Gen2Screens.NONE,
	defender_screens: int = Gen2Screens.NONE,
	has_bench: bool = false,
	matchup_score: int = Gen2AISwitch.BASE_SCORE,
	defender_has_bench: bool = false,
	defender_used_moves: Array = [],
	bench_status_mask: int = Gen2Status.NONE
) -> int:
	return _pick_lowest(
		score_slots(
			attacker, defender, data, ai_move_weights, rng,
			attacker_turns_taken, defender_turns_taken, weather,
			attacker_screens, defender_screens, has_bench, matchup_score,
			defender_has_bench, defender_used_moves, bench_status_mask
		),
		attacker, rng
	)


## What every layer named in [param ai_move_weights] leaves each of the four slots
## at, before the argmin. The same arguments [method choose_slot] takes, and the
## half of it a single handler can be read off.
static func score_slots(
	attacker: Gen2BattleMon,
	defender: Gen2BattleMon,
	data: GameData,
	ai_move_weights: int,
	rng: RandomNumberGenerator,
	attacker_turns_taken: int = 0,
	defender_turns_taken: int = 0,
	weather: int = Gen2Weather.NONE,
	attacker_screens: int = Gen2Screens.NONE,
	defender_screens: int = Gen2Screens.NONE,
	has_bench: bool = false,
	matchup_score: int = Gen2AISwitch.BASE_SCORE,
	defender_has_bench: bool = false,
	defender_used_moves: Array = [],
	bench_status_mask: int = Gen2Status.NONE
) -> Array:
	var scores: Array = []
	for slot: int in Gen2BattleMon.MAX_MOVES:
		scores.append(DEFAULT_SCORE if attacker.can_use(slot) else UNUSABLE_SCORE)

	var context := Context.of(
		attacker, defender, data, rng, attacker_turns_taken, defender_turns_taken,
		weather, attacker_screens, defender_screens, has_bench, matchup_score,
		defender_has_bench, defender_used_moves, bench_status_mask
	)

	if ai_move_weights & RomLayout.AI_BASIC:
		_apply_basic(scores, context)
	if ai_move_weights & RomLayout.AI_SETUP:
		_apply_setup(scores, context)
	if ai_move_weights & RomLayout.AI_TYPES:
		_apply_types(scores, context)
	if ai_move_weights & RomLayout.AI_OFFENSIVE:
		_apply_offensive(scores, context)
	if ai_move_weights & RomLayout.AI_SMART:
		_apply_smart(scores, context)
	if ai_move_weights & RomLayout.AI_OPPORTUNIST:
		_apply_opportunist(scores, context)
	if ai_move_weights & RomLayout.AI_AGGRESSIVE:
		_apply_aggressive(scores, context)
	if ai_move_weights & RomLayout.AI_CAUTIOUS:
		_apply_cautious(scores, context)
	if ai_move_weights & RomLayout.AI_STATUS:
		_apply_status(scores, context)
	if ai_move_weights & RomLayout.AI_RISKY:
		_apply_risky(scores, context)

	return scores


static func _pick_lowest(scores: Array, attacker: Gen2BattleMon, rng: RandomNumberGenerator) -> int:
	var best: int = UNUSABLE_SCORE + 1
	for slot: int in scores.size():
		if attacker.can_use(slot) and int(scores[slot]) < best:
			best = int(scores[slot])

	var candidates: Array = []
	for slot: int in scores.size():
		if attacker.can_use(slot) and int(scores[slot]) == best:
			candidates.append(slot)

	if candidates.is_empty():
		return 0
	return candidates[rng.randi_range(0, candidates.size() - 1)]


## The move a slot names, or an empty Dictionary for a slot with nothing in it.
static func _move_at(mon: Gen2BattleMon, data: GameData, slot: int) -> Dictionary:
	if slot < 0 or slot >= mon.moves.size():
		return {}
	return data.move(int(mon.moves[slot]))


static func _effect(move: Dictionary) -> int:
	return int(move.get("effect", 0))


static func _power(move: Dictionary) -> int:
	return int(move.get("power", 0))


static func _discourage(scores: Array, slot: int, by: int = DISCOURAGE_MOVE) -> void:
	scores[slot] = int(scores[slot]) + by


static func _encourage(scores: Array, slot: int, by: int = 1) -> void:
	scores[slot] = int(scores[slot]) - by


static func _above_half(mon: Gen2BattleMon) -> bool:
	return mon.hp * 2 > mon.max_hp()


static func _above_quarter(mon: Gen2BattleMon) -> bool:
	return mon.hp * 4 > mon.max_hp()


static func _at_max_hp(mon: Gen2BattleMon) -> bool:
	return mon.hp >= mon.max_hp()


## Whether [param a] is faster than [param b] with stages and status applied,
## the same stat a turn's own speed order reads.
static func _faster(a: Gen2BattleMon, b: Gen2BattleMon) -> bool:
	return a.stat("speed") > b.stat("speed")


## True with roughly [param percent] chance, the cartridge's own "X percent"
## macro: a threshold out of 255, truncated.
static func _roll(rng: RandomNumberGenerator, percent: int) -> bool:
	return _rolls_under(rng, percent * 255 / 100)


## The same roll against a threshold written out rather than as a percentage.
## `39 percent + 1` is a macro result with a byte added to it, which no percentage
## reproduces, so the sites that use it name the number.
static func _rolls_under(rng: RandomNumberGenerator, threshold: int) -> bool:
	return rng.randi_range(0, 255) < threshold


## `39 percent + 1`, which is 100. Five `AI_Smart` branches roll against it.
const AI_39_PERCENT_PLUS_ONE: int = 100

## `79 percent - 1`, which is 200: `AI_Smart_Rollout`, `AI_Smart_Attract` and
## `AI_Smart_Unused2B` roll against it.
const AI_79_PERCENT_MINUS_ONE: int = 200

## `28 percent - 1`, which is 70, and `AI_Smart_Encore` alone.
const AI_28_PERCENT_MINUS_ONE: int = 70

## `EncoreMoves`: what the AI thinks is worth locking the player into, by move
## number. `AI_Smart_Encore` reads it only for a move it has already decided is
## weak against the enemy in front of it.
const ENCORE_MOVE_NUMBERS: Array[int] = [
	14, 18, 43, 46, 50, 54, 73, 74, 77, 81, 96, 97, 100, 103, 114, 116, 138, 139,
	150, 159, 160, 162, 164, 167, 169, 170, 172, 177, 178, 181,
]


## [code]AI_50_50[/code] and [code]AI_80_20[/code]: named for the "do nothing"
## half of the roll, because every call site in pret's own source is a skip.
static func _skip_50_50(rng: RandomNumberGenerator) -> bool:
	return rng.randi_range(0, 255) < 128


static func _skip_80_20(rng: RandomNumberGenerator) -> bool:
	return rng.randi_range(0, 255) < 50


## [constant RomLayout.AI_BASIC]: nothing redundant. A status move against an
## already-statused target, confusion against a confused one, Disable or Encore
## against a locked one, Attract against a target already in love or of the same
## or unknown gender, and a second Mist or Focus Energy, which is why those two
## read the attacker rather than the defender, and a screen the attacker's own
## side already holds. A standing Substitute reads the attacker for the same
## reason; Leech Seed, Nightmare and Spikes read the target.
##
## `AI_Redundant`'s own thirty rows are the rest of it, each reading whichever
## side the effect would land on.
static func _apply_basic(scores: Array, c: Context) -> void:
	var attacker: Gen2BattleMon = c.attacker
	var defender: Gen2BattleMon = c.defender
	var data: GameData = c.data
	var weather: int = c.weather
	var attacker_screens: int = c.attacker_screens
	var defender_screens: int = c.defender_screens
	for slot: int in Gen2BattleMon.MAX_MOVES:
		if not attacker.can_use(slot):
			continue
		var effect: int = _effect(_move_at(attacker, data, slot))
		var redundant: bool = false
		if effect == Gen2MoveEffect.CONFUSE:
			# `.Confuse` is the one row with two clauses: already confused, or
			# behind the player's own Safeguard.
			redundant = Gen2Substatus.has(defender.substatus, Gen2Substatus.CONFUSED) \
				or Gen2Screens.has(defender_screens, Gen2Screens.SAFEGUARD)
		elif STATUS_ONLY_EFFECTS.has(effect):
			redundant = Gen2Status.is_afflicted(defender.status)
		elif effect == Gen2MoveEffect.DISABLE:
			redundant = defender.disabled_slot >= 0
		elif effect == Gen2MoveEffect.ENCORE:
			redundant = defender.encored_slot >= 0
		elif effect == Gen2MoveEffect.ATTRACT:
			var same_gender: bool = attacker.gender() == defender.gender()
			var unknown_gender: bool = attacker.gender() == Gen2BattleMon.GENDER_NONE \
				or defender.gender() == Gen2BattleMon.GENDER_NONE
			redundant = same_gender or unknown_gender \
				or Gen2Substatus.has(defender.substatus, Gen2Substatus.ATTRACTED)
		elif effect == Gen2MoveEffect.MIST:
			redundant = Gen2Substatus.has(attacker.substatus, Gen2Substatus.MIST)
		elif effect == Gen2MoveEffect.FOCUS_ENERGY:
			redundant = Gen2Substatus.has(attacker.substatus, Gen2Substatus.FOCUS_ENERGY)
		elif effect == Gen2MoveEffect.PERISH_SONG:
			# `.PerishSong` reads `wPlayerSubStatus1`, the target's: a second song
			# over one already counting down would reset nothing.
			redundant = Gen2Substatus.has(defender.substatus, Gen2Substatus.PERISH)
		elif effect == Gen2MoveEffect.MEAN_LOOK:
			# `.MeanLook` reads the user's own flag, the side the trap sits on.
			redundant = Gen2Substatus.has(attacker.substatus, Gen2Substatus.CANT_RUN)
		elif SCREEN_FOR_EFFECT.has(effect):
			# `.LightScreen`, `.Reflect` and `.Safeguard` all read
			# `wEnemyScreens`, the AI's own side: a screen it already holds is
			# the wasted turn, not one the player holds.
			redundant = Gen2Screens.has(attacker_screens, int(SCREEN_FOR_EFFECT[effect]))
		elif effect == Gen2MoveEffect.SUBSTITUTE:
			# `.Substitute` reads `wEnemySubStatus4`, the AI's own.
			redundant = Gen2Substatus.has(attacker.substatus, Gen2Substatus.SUBSTITUTE)
		elif effect == Gen2MoveEffect.LEECH_SEED:
			redundant = Gen2Substatus.has(defender.substatus, Gen2Substatus.LEECH_SEED)
		elif effect == Gen2MoveEffect.NIGHTMARE:
			# `.Nightmare` treats *no* status as the redundant case, so a target
			# carrying any status stays encouraged even when it is awake and cannot
			# have one. The source marks that as a bug; reproduced, not fixed.
			redundant = not Gen2Status.is_afflicted(defender.status) \
				or Gen2Substatus.has(defender.substatus, Gen2Substatus.NIGHTMARE)
		elif effect == Gen2MoveEffect.SPIKES:
			# `.Spikes` reads `wPlayerScreens`, the side they would land on.
			redundant = Gen2Screens.has(defender_screens, Gen2Screens.SPIKES)
		elif effect == Gen2MoveEffect.FORESIGHT:
			redundant = Gen2Substatus.has(defender.substatus, Gen2Substatus.IDENTIFIED)
		elif effect == Gen2MoveEffect.TELEPORT:
			# `.Teleport` is a label on `.Redundant` itself, so it is redundant
			# unconditionally: a trainer's Pokémon is refused by the move anyway.
			redundant = true
		elif effect == Gen2MoveEffect.SLEEP_TALK or effect == Gen2MoveEffect.SNORE:
			# `.SleepTalk` shares Snore's row: awake means the move is wasted.
			redundant = not Gen2Status.is_asleep(attacker.status)
		elif effect == Gen2MoveEffect.DREAM_EATER:
			# `.DreamEater` is the same shape read the other way round, off the
			# target's status rather than the user's.
			redundant = not Gen2Status.is_asleep(defender.status)
		elif effect == Gen2MoveEffect.SWAGGER:
			redundant = Gen2Substatus.has(defender.substatus, Gen2Substatus.CONFUSED)
		elif effect == Gen2MoveEffect.TRANSFORM:
			redundant = Gen2Substatus.has(attacker.substatus, Gen2Substatus.TRANSFORMED)
		elif effect == Gen2MoveEffect.FUTURE_SIGHT:
			# `.FutureSight` reads `SCREENS_UNUSED`, a bit nothing ever writes, so
			# a second Future Sight is never discouraged. `docs/bugs_and_glitches.md`
			# records it as a bug; reproduced, not fixed.
			redundant = false
		elif effect == Gen2MoveEffect.HEAL or effect == Gen2MoveEffect.MORNING_SUN \
				or effect == Gen2MoveEffect.SYNTHESIS or effect == Gen2MoveEffect.MOONLIGHT:
			# Four labels on one body: healing a full bar does nothing, whatever
			# the weather would have made of it.
			redundant = _at_max_hp(attacker)
		elif WEATHER_FOR_EFFECT.has(effect):
			redundant = weather == int(WEATHER_FOR_EFFECT[effect])
		if redundant:
			_discourage(scores, slot)


## [constant RomLayout.AI_SETUP]: use a stat move on the first turn. Raising is
## encouraged only on the attacker's first turn and lowering only on the
## defender's; past that both are heavily discouraged.
static func _apply_setup(scores: Array, c: Context) -> void:
	var attacker: Gen2BattleMon = c.attacker
	var data: GameData = c.data
	var rng: RandomNumberGenerator = c.rng
	var atk_turns: int = c.atk_turns
	var def_turns: int = c.def_turns
	for slot: int in Gen2BattleMon.MAX_MOVES:
		if not attacker.can_use(slot):
			continue
		var effect: int = _effect(_move_at(attacker, data, slot))
		var is_up: bool = _in_run(effect, Gen2MoveEffect.STAT_UP_BASE) \
			or _in_run(effect, Gen2MoveEffect.STAT_UP_2_BASE)
		var is_down: bool = _in_run(effect, Gen2MoveEffect.STAT_DOWN_BASE) \
			or _in_run(effect, Gen2MoveEffect.STAT_DOWN_2_BASE)

		if is_up:
			if atk_turns == 0:
				if not _skip_50_50(rng):
					_encourage(scores, slot, 2)
			elif not _roll(rng, 12):
				_discourage(scores, slot, 2)
		elif is_down:
			if def_turns == 0:
				if not _skip_50_50(rng):
					_encourage(scores, slot, 2)
			elif not _roll(rng, 12):
				_discourage(scores, slot, 2)


static func _in_run(effect: int, base: int) -> bool:
	return effect >= base and effect < base + Gen2MoveEffect.STAT_RUN_LENGTH


## [constant RomLayout.AI_TYPES]: dismiss a move the defender is immune to,
## encourage a super-effective one, and discourage a not-very-effective one
## unless it is the only type of damage on offer.
static func _apply_types(scores: Array, c: Context) -> void:
	var attacker: Gen2BattleMon = c.attacker
	var defender: Gen2BattleMon = c.defender
	var data: GameData = c.data
	for slot: int in Gen2BattleMon.MAX_MOVES:
		if not attacker.can_use(slot):
			continue
		var move: Dictionary = _move_at(attacker, data, slot)
		var move_type: int = int(move.get("type", RomLayout.TYPE_NORMAL))
		# `AI_Types` sets `hBattleTurn` to the enemy before every
		# `BattleCheckTypeMatchup`, so the Foresight flag it reads is the player's:
		# the defender's from the side doing the scoring.
		var effectiveness: int = data.type_effectiveness(
			move_type, defender.types(),
			Gen2Substatus.has(defender.substatus, Gen2Substatus.IDENTIFIED)
		)

		if effectiveness == RomLayout.MATCHUP_NO_EFFECT:
			_discourage(scores, slot)
		elif effectiveness == RomLayout.MATCHUP_EFFECTIVE:
			continue
		elif effectiveness > RomLayout.MATCHUP_EFFECTIVE:
			if _power(move) > 0:
				_encourage(scores, slot)
		else:
			# Not very effective. Discourage it only if some other move in the
			# same four deals damage of a different type: a mon that only knows
			# one type of attack should still use it.
			for other: int in Gen2BattleMon.MAX_MOVES:
				var other_move: Dictionary = _move_at(attacker, data, other)
				if other_move.is_empty():
					continue
				if int(other_move.get("type", -1)) == move_type:
					continue
				if _power(other_move) > 0:
					_discourage(scores, slot, 1)
					break


## [constant RomLayout.AI_OFFENSIVE]: heavily discourage a move with no power,
## for a class whose whole strategy is to attack.
static func _apply_offensive(scores: Array, c: Context) -> void:
	var attacker: Gen2BattleMon = c.attacker
	var data: GameData = c.data
	for slot: int in Gen2BattleMon.MAX_MOVES:
		if not attacker.can_use(slot):
			continue
		if _power(_move_at(attacker, data, slot)) <= 0:
			_discourage(scores, slot, 2)


## [constant RomLayout.AI_SMART]: context-specific scoring, per move effect.
## See the constant above this function for which effects have a handler.
static func _apply_smart(scores: Array, c: Context) -> void:
	var attacker: Gen2BattleMon = c.attacker
	var defender: Gen2BattleMon = c.defender
	var data: GameData = c.data
	var rng: RandomNumberGenerator = c.rng
	var atk_turns: int = c.atk_turns
	var def_turns: int = c.def_turns
	var weather: int = c.weather
	var has_bench: bool = c.has_bench
	var matchup_score: int = c.matchup_score
	for slot: int in Gen2BattleMon.MAX_MOVES:
		if not attacker.can_use(slot):
			continue
		match _effect(_move_at(attacker, data, slot)):
			Gen2MoveEffect.MIRROR_MOVE:
				_smart_mirror_move(scores, slot, attacker, defender, rng)
			Gen2MoveEffect.MIMIC:
				_smart_mimic(scores, slot, attacker, defender, data, rng)
			Gen2MoveEffect.CONVERSION_2:
				_smart_conversion_2(scores, slot, defender, rng)
			Gen2MoveEffect.SLEEP:
				if not _skip_50_50(rng):
					_encourage(scores, slot, 2)
			Gen2MoveEffect.HAZE: # AI_Smart_ResetStats
				_smart_reset_stats(scores, slot, attacker, defender, rng)
			Gen2MoveEffect.TOXIC:
				if not _above_half(defender):
					_discourage(scores, slot, 1)
			Gen2MoveEffect.CONFUSE:
				_smart_confuse(scores, slot, defender, rng)
			Gen2MoveEffect.PARALYZE:
				_smart_paralyze(scores, slot, attacker, defender, rng)
			Gen2MoveEffect.RECHARGE_HIT: # Hyper Beam
				_smart_hyper_beam(scores, slot, attacker, rng)
			# `AI_Smart_DestinyBond`, `AI_Smart_Reversal` and `AI_Smart_SkullBash`
			# are one label and one body in the source, so they are one arm here.
			Gen2MoveEffect.SKULL_BASH, Gen2MoveEffect.REVERSAL, \
			Gen2MoveEffect.DESTINY_BOND:
				if _above_quarter(attacker):
					_discourage(scores, slot, 1)
			# `AI_Smart_ForceSwitch`: discourage blowing the player away unless
			# `CheckPlayerMoveTypeMatchups` says the pairing is going badly, which
			# is the same score `AI_Smart_PerishSong` reads.
			# `AI_Smart_BatonPass` is the same body under a second label, so the
			# two share an arm the way Destiny Bond shares Skull Bash's.
			Gen2MoveEffect.FORCE_SWITCH, Gen2MoveEffect.BATON_PASS:
				if matchup_score >= Gen2AISwitch.BASE_SCORE:
					_discourage(scores, slot, 1)
			Gen2MoveEffect.PROTECT:
				_smart_protect(scores, slot, attacker, defender, rng)
			Gen2MoveEffect.ENDURE:
				_smart_endure(scores, slot, attacker, data, rng)
			Gen2MoveEffect.BELLY_DRUM:
				_smart_belly_drum(scores, slot, attacker)
			Gen2MoveEffect.PSYCH_UP:
				_smart_psych_up(scores, slot, attacker, defender, rng)
			Gen2MoveEffect.SOLARBEAM:
				_smart_solarbeam(scores, slot, weather, rng)
			Gen2MoveEffect.THUNDER:
				_smart_thunder(scores, slot, weather, rng)
			Gen2MoveEffect.SANDSTORM:
				_smart_sandstorm(scores, slot, defender, rng)
			Gen2MoveEffect.RAIN_DANCE:
				_smart_weather_move(
					scores, slot, attacker, defender, rng, atk_turns, def_turns,
					RomLayout.TYPE_WATER, RomLayout.TYPE_FIRE, RAIN_DANCE_MOVE_NUMBERS
				)
			Gen2MoveEffect.SUNNY_DAY:
				_smart_weather_move(
					scores, slot, attacker, defender, rng, atk_turns, def_turns,
					RomLayout.TYPE_FIRE, RomLayout.TYPE_WATER, SUNNY_DAY_MOVE_NUMBERS
				)
			Gen2MoveEffect.TRAP_TARGET:
				_smart_trap_target(scores, slot, attacker, defender, def_turns, rng)
			Gen2MoveEffect.HEAL, Gen2MoveEffect.MORNING_SUN, Gen2MoveEffect.SYNTHESIS, \
			Gen2MoveEffect.MOONLIGHT:
				_smart_heal(scores, slot, attacker, rng)
			Gen2MoveEffect.PERISH_SONG:
				_smart_perish_song(scores, slot, defender, rng, has_bench, matchup_score)
			Gen2MoveEffect.PAIN_SPLIT:
				_smart_pain_split(scores, slot, attacker, defender)
			Gen2MoveEffect.LOCK_ON:
				_smart_lock_on(scores, slot, attacker, defender, data, rng)
			Gen2MoveEffect.SPITE:
				_smart_spite(scores, slot, attacker, defender, rng)
			Gen2MoveEffect.THIEF:
				_discourage(scores, slot, THIEF_PENALTY)
			Gen2MoveEffect.FORESIGHT:
				_smart_foresight(scores, slot, attacker, defender, rng)
			Gen2MoveEffect.MEAN_LOOK:
				_smart_mean_look(scores, slot, attacker, defender, rng, has_bench, matchup_score)
			Gen2MoveEffect.PURSUIT:
				_smart_pursuit(scores, slot, defender, rng)
			# `AI_Smart_Snore` is an empty label in front of
			# `AI_Smart_SleepTalk`.
			Gen2MoveEffect.SLEEP_TALK, Gen2MoveEffect.SNORE:
				_smart_sleep_talk(scores, slot, attacker)
			Gen2MoveEffect.LEECH_HIT:
				_smart_leech_hit(scores, slot, c)
			Gen2MoveEffect.SELFDESTRUCT:
				_smart_selfdestruct(scores, slot, c)
			Gen2MoveEffect.DREAM_EATER:
				if not _roll(rng, 10):
					_encourage(scores, slot, 3)
			Gen2MoveEffect.EVASION_UP:
				_smart_evasion_up(scores, slot, c)
			Gen2MoveEffect.ACCURACY_DOWN:
				_smart_accuracy_down(scores, slot, c)
			Gen2MoveEffect.ALWAYS_HIT:
				_smart_always_hit(scores, slot, c)
			Gen2MoveEffect.BIDE:
				# `AICheckEnemyMaxHP` and a 10% pass, which is the whole routine.
				if not _at_max_hp(attacker) and not _roll(rng, 10):
					_discourage(scores, slot, 1)
			# `AI_Smart_LightScreen` is an empty label in front of
			# `AI_Smart_Reflect`, so the two are one body.
			Gen2MoveEffect.LIGHT_SCREEN, Gen2MoveEffect.REFLECT:
				if not _at_max_hp(attacker) and not _roll(rng, 8):
					_discourage(scores, slot, 1)
			Gen2MoveEffect.OHKO:
				_smart_ohko(scores, slot, attacker, defender)
			# `AI_Smart_Toxic` falls into `AI_Smart_LeechSeed`.
			Gen2MoveEffect.LEECH_SEED:
				if not _above_half(defender):
					_discourage(scores, slot, 1)
			Gen2MoveEffect.SUPER_FANG:
				if not _above_quarter(defender):
					_discourage(scores, slot, 1)
			# `AI_Smart_RazorWind` is an empty label in front of
			# `AI_Smart_Unused2B`.
			Gen2MoveEffect.RAZOR_WIND, Gen2MoveEffect.UNUSED_2B:
				_smart_unused_2b(scores, slot, c)
			Gen2MoveEffect.SP_DEF_UP_2:
				_smart_sp_defense_up_2(scores, slot, c)
			Gen2MoveEffect.SPEED_DOWN_HIT:
				_smart_speed_down_hit(scores, slot, c)
			Gen2MoveEffect.SUBSTITUTE:
				if not _above_half(attacker):
					_discourage(scores, slot)
			Gen2MoveEffect.RAGE:
				_smart_rage(scores, slot, attacker, rng)
			Gen2MoveEffect.DISABLE:
				_smart_disable(scores, slot, c)
			Gen2MoveEffect.COUNTER:
				_smart_counter(scores, slot, c, true)
			Gen2MoveEffect.MIRROR_COAT:
				_smart_counter(scores, slot, c, false)
			Gen2MoveEffect.ENCORE:
				_smart_encore(scores, slot, c)
			Gen2MoveEffect.DEFROST_OPPONENT:
				if Gen2Status.has(attacker.status, Gen2Status.FREEZE):
					_encourage(scores, slot, 3)
			Gen2MoveEffect.HEAL_BELL:
				_smart_heal_bell(scores, slot, c)
			Gen2MoveEffect.PRIORITY_HIT:
				_smart_priority_hit(scores, slot, c)
			Gen2MoveEffect.NIGHTMARE:
				if not _skip_50_50(rng):
					_encourage(scores, slot, 1)
			Gen2MoveEffect.FLAME_WHEEL:
				if Gen2Status.has(attacker.status, Gen2Status.FREEZE):
					_encourage(scores, slot, 5)
			Gen2MoveEffect.CURSE:
				_smart_curse(scores, slot, c)
			Gen2MoveEffect.ROLLOUT:
				_smart_rollout(scores, slot, c)
			Gen2MoveEffect.FURY_CUTTER:
				_smart_fury_cutter(scores, slot, c)
			# `AI_Smart_Swagger` is an empty label in front of
			# `AI_Smart_Attract`.
			Gen2MoveEffect.SWAGGER, Gen2MoveEffect.ATTRACT:
				_smart_attract(scores, slot, c)
			Gen2MoveEffect.SAFEGUARD:
				if not _above_half(defender) and not _skip_80_20(rng):
					_discourage(scores, slot, 1)
			# `AI_Smart_Magnitude` is an empty label in front of
			# `AI_Smart_Earthquake`, and `AI_Smart_Twister` in front of
			# `AI_Smart_Gust`: each pair guesses at the move the other half of
			# it punishes.
			Gen2MoveEffect.MAGNITUDE, Gen2MoveEffect.EARTHQUAKE:
				_smart_ground_or_air(
					scores, slot, c, Gen2MoveEffect.DIG_MOVE, Gen2Substatus.UNDERGROUND
				)
			Gen2MoveEffect.TWISTER, Gen2MoveEffect.GUST:
				_smart_ground_or_air(
					scores, slot, c, Gen2MoveEffect.FLY_MOVE, Gen2Substatus.FLYING
				)
			Gen2MoveEffect.RAPID_SPIN:
				_smart_rapid_spin(scores, slot, c)
			Gen2MoveEffect.HIDDEN_POWER:
				_smart_hidden_power(scores, slot, c)
			Gen2MoveEffect.FUTURE_SIGHT:
				if _faster(attacker, defender) and _is_semi_invulnerable(defender):
					_encourage(scores, slot, 2)
			Gen2MoveEffect.STOMP:
				if defender.minimized and not _skip_80_20(rng):
					_encourage(scores, slot, 1)
			Gen2MoveEffect.FLY_OR_DIG:
				if _is_semi_invulnerable(defender) and _faster(attacker, defender):
					_encourage(scores, slot, 3)


## `AI_Smart_MirrorMove`: without a remembered player move, a faster AI
## dismisses Mirror Move because it will act before seeing one. A useful
## remembered move gets one 50% encouragement and, when the AI is faster, a
## second 90% encouragement.
static func _smart_mirror_move(
	scores: Array, slot: int, attacker: Gen2BattleMon, defender: Gen2BattleMon,
	rng: RandomNumberGenerator
) -> void:
	var copied: int = defender.last_counter_move
	if copied == 0:
		if _faster(attacker, defender):
			_discourage(scores, slot)
		return
	if not USEFUL_MOVE_NUMBERS.has(copied):
		return
	if not _skip_50_50(rng):
		_encourage(scores, slot, 1)
	if _faster(attacker, defender) and not _rolls_under(rng, 25):
		_encourage(scores, slot, 1)


## `AI_Smart_Mimic`: wait for a move when slower, dismiss the blind attempt
## when faster, and only copy above half health. A resisted last move is
## discouraged; a super-effective or source-listed useful one gets its own 50%
## encouragement.
static func _smart_mimic(
	scores: Array, slot: int, attacker: Gen2BattleMon, defender: Gen2BattleMon,
	data: GameData, rng: RandomNumberGenerator
) -> void:
	var copied: int = defender.last_counter_move
	if copied == 0:
		if _faster(attacker, defender):
			_discourage(scores, slot)
		else:
			_discourage(scores, slot, 1)
		return
	if not _above_half(attacker):
		_discourage(scores, slot, 1)
		return
	var move: Dictionary = data.move(copied)
	if move.is_empty():
		return
	var effectiveness: int = data.type_effectiveness(
		int(move.get("type", RomLayout.TYPE_NORMAL)), defender.types(),
		Gen2Substatus.has(defender.substatus, Gen2Substatus.IDENTIFIED)
	)
	if effectiveness < RomLayout.MATCHUP_EFFECTIVE:
		_discourage(scores, slot, 1)
		return
	if effectiveness > RomLayout.MATCHUP_EFFECTIVE and not _skip_50_50(rng):
		_encourage(scores, slot, 1)
	if USEFUL_MOVE_NUMBERS.has(copied) and not _skip_50_50(rng):
		_encourage(scores, slot, 1)


## `AI_Smart_Snore` and `AI_Smart_SleepTalk` are one source body. A sleep count
## of one wakes before the move and is discouraged; every other value gets the
## smart layer's encouragement. The basic layer independently discourages the
## awake case, leaving it a bad choice overall as on the cartridge.
static func _smart_sleep_talk(scores: Array, slot: int, attacker: Gen2BattleMon) -> void:
	if (attacker.status & Gen2Status.SLEEP_MASK) == 1:
		_discourage(scores, slot, 3)
	else:
		_encourage(scores, slot, 3)


## `AI_Smart_Conversion2`'s documented bug: once the player has a remembered
## move, the smart layer almost always discourages the very response designed
## for it. The no-last-move branch reads past move zero in the cartridge; this
## model leaves that undefined lookup neutral rather than inventing ROM bytes.
static func _smart_conversion_2(
	scores: Array, slot: int, defender: Gen2BattleMon, rng: RandomNumberGenerator
) -> void:
	if defender.last_counter_move != 0 and not _rolls_under(rng, 25):
		_discourage(scores, slot, 1)


## `AI_Smart_Solarbeam`: 80% to encourage it greatly in sun, where it needs no
## charge turn, and 90% to discourage it greatly in rain, where it also loses
## half its damage.
static func _smart_solarbeam(
	scores: Array, slot: int, weather: int, rng: RandomNumberGenerator
) -> void:
	if weather == Gen2Weather.SUN:
		if not _skip_80_20(rng):
			_encourage(scores, slot, 2)
		return
	if weather == Gen2Weather.RAIN and not _roll(rng, 10):
		_discourage(scores, slot, 2)


## `AI_Smart_Thunder`: 90% to discourage it in sun, where its accuracy halves.
## Rain is not mentioned, because the accuracy step and `CheckHit` have already
## made it certain.
static func _smart_thunder(
	scores: Array, slot: int, weather: int, rng: RandomNumberGenerator
) -> void:
	if weather == Gen2Weather.SUN and not _roll(rng, 10):
		_discourage(scores, slot, 1)


## `AI_Smart_Sandstorm`: worthless against a target the sand cannot touch, poor
## against one already low, and a 50% encouragement otherwise.
static func _smart_sandstorm(
	scores: Array, slot: int, defender: Gen2BattleMon, rng: RandomNumberGenerator
) -> void:
	for defending_type: int in defender.types():
		if SANDSTORM_IMMUNE_TYPES.has(int(defending_type)):
			_discourage(scores, slot, 2)
			return

	if not _above_half(defender):
		_discourage(scores, slot, 1)
		return
	if not _skip_50_50(rng):
		_encourage(scores, slot, 1)


## `AI_Smart_RainDance` and `AI_Smart_SunnyDay`, which are one routine with two
## type pairs: the weather is a bad idea if it would suit the target and a good
## one if it would hurt it, and otherwise worth setting only with a move that
## wants it.
##
## [param favours_target] is the type the weather helps and
## [param disfavours_target] the one it hurts, in the order the cartridge tests
## them: the target's first type answers before its second, so a Water/Fire
## target under Rain Dance is a Water target.
static func _smart_weather_move(
	scores: Array, slot: int, attacker: Gen2BattleMon, defender: Gen2BattleMon,
	rng: RandomNumberGenerator, atk_turns: int, def_turns: int,
	favours_target: int, disfavours_target: int, wanted_moves: Array
) -> void:
	for defending_type: int in defender.types():
		if int(defending_type) == favours_target:
			_discourage(scores, slot, 3)
			return
		if int(defending_type) == disfavours_target:
			_good_weather_type(scores, slot, defender, atk_turns, def_turns)
			return

	# `AIHasMoveInArray` walks the four slots by move number alone: no PP check
	# and no usability check, so a wanted move with nothing left in it still
	# counts as a reason to set the weather.
	var has_wanted: bool = false
	for known: Variant in attacker.moves:
		if wanted_moves.has(int(known)):
			has_wanted = true
			break

	if not has_wanted or not _above_half(defender):
		_discourage(scores, slot, 3)
		return
	if not _skip_50_50(rng):
		_encourage(scores, slot, 1)


## `AIGoodWeatherType`: worth two only while the target is still healthy and one
## of the two Pokémon has just come out.
static func _good_weather_type(
	scores: Array, slot: int, defender: Gen2BattleMon, atk_turns: int, def_turns: int
) -> void:
	if not _above_half(defender):
		return
	if def_turns == 0 or atk_turns == 0:
		_encourage(scores, slot, 2)


## `AI_Smart_TrapTarget`: pointless against a target already bound, and worth two
## against one that is losing health anyway or has only just come out, provided
## the user has enough left to hold it there.
##
## The five states it encourages on are Toxic and the four bits
## `and 1 << SUBSTATUS_IN_LOVE | 1 << SUBSTATUS_ROLLOUT | 1 << SUBSTATUS_IDENTIFIED
## | 1 << SUBSTATUS_NIGHTMARE` tests in one instruction.
static func _smart_trap_target(
	scores: Array, slot: int, attacker: Gen2BattleMon, defender: Gen2BattleMon,
	def_turns: int, rng: RandomNumberGenerator
) -> void:
	var worth_it: bool = defender.trapped_turns <= 0 and (
		defender.toxic_counter > 0
		or Gen2Substatus.has(
			defender.substatus,
			Gen2Substatus.ATTRACTED | Gen2Substatus.ROLLOUT
			| Gen2Substatus.IDENTIFIED | Gen2Substatus.NIGHTMARE
		)
		or def_turns == 0
	)

	if not worth_it:
		if not _skip_50_50(rng):
			_discourage(scores, slot, 1)
		return

	if not _above_quarter(attacker):
		return
	if not _skip_50_50(rng):
		_encourage(scores, slot, 2)


static func _smart_reset_stats(
	scores: Array, slot: int, attacker: Gen2BattleMon, defender: Gen2BattleMon,
	rng: RandomNumberGenerator
) -> void:
	var encourage: bool = false
	for key: String in Gen2BattleMon.STAGED_STATS + Gen2BattleMon.STAGED_ODDS:
		if attacker.stage(key) < -2:
			encourage = true
			break
	if not encourage:
		for key: String in Gen2BattleMon.STAGED_STATS + Gen2BattleMon.STAGED_ODDS:
			if defender.stage(key) > 2:
				encourage = true
				break

	if not encourage:
		_discourage(scores, slot, 1)
		return
	if not _roll(rng, 16):
		_encourage(scores, slot, 1)


static func _smart_confuse(
	scores: Array, slot: int, defender: Gen2BattleMon, rng: RandomNumberGenerator
) -> void:
	if _above_half(defender):
		return
	if _roll(rng, 90):
		_discourage(scores, slot, 1)
	if not _above_quarter(defender):
		_discourage(scores, slot, 1)


static func _smart_paralyze(
	scores: Array, slot: int, attacker: Gen2BattleMon, defender: Gen2BattleMon,
	rng: RandomNumberGenerator
) -> void:
	if not _above_quarter(defender):
		if not _skip_50_50(rng):
			_discourage(scores, slot, 1)
		return
	if _faster(attacker, defender):
		return
	if not _above_quarter(attacker):
		return
	if not _skip_80_20(rng):
		_encourage(scores, slot, 2)


static func _smart_hyper_beam(
	scores: Array, slot: int, attacker: Gen2BattleMon, rng: RandomNumberGenerator
) -> void:
	if _above_half(attacker):
		if not _roll(rng, 16):
			return
		_discourage(scores, slot, 1)
		if _skip_50_50(rng):
			return
		_discourage(scores, slot, 1)
		return

	if _above_quarter(attacker):
		return
	if _skip_50_50(rng):
		return
	_encourage(scores, slot, 1)


## `AI_Smart_Heal`, which `AI_Smart_MorningSun`, `AI_Smart_Synthesis` and
## `AI_Smart_Moonlight` are all labels on: 90% to encourage it greatly below a
## quarter health, discourage it above half, and nothing in between. The AI reads
## its own health here, never the player's.
static func _smart_heal(
	scores: Array, slot: int, attacker: Gen2BattleMon, rng: RandomNumberGenerator
) -> void:
	if not _above_quarter(attacker):
		if not _roll(rng, 10):
			_encourage(scores, slot, 2)
		return
	if _above_half(attacker):
		_discourage(scores, slot, 1)


## `AI_Smart_PerishSong`: worth singing when the player cannot leave, not worth
## singing when the AI has nobody to leave for.
##
## Three branches in the source's own order. `.no`, with nobody on the bench, is
## the only one that moves a score without a roll: five points against, since a
## song the AI cannot walk away from kills it too. A player held by Mean Look or
## Spider Web is `.yes`, 50% to encourage. Otherwise the AI only bothers when the
## matchup is one it is not losing: `CheckPlayerMoveTypeMatchups` below
## [constant Gen2AISwitch.BASE_SCORE] returns with nothing said, and at or above
## it is 50% to discourage. Reading that as "sing when things are going badly"
## has it backwards; the branch that says yes is the trapped one.
static func _smart_perish_song(
	scores: Array, slot: int, defender: Gen2BattleMon, rng: RandomNumberGenerator,
	has_bench: bool, matchup_score: int
) -> void:
	if not has_bench:
		_discourage(scores, slot, 5)
		return

	if Gen2Substatus.has(defender.substatus, Gen2Substatus.CANT_RUN):
		if not _skip_50_50(rng):
			_encourage(scores, slot, 1)
		return

	if matchup_score < Gen2AISwitch.BASE_SCORE:
		return
	if _skip_50_50(rng):
		return
	_discourage(scores, slot, 1)


## `AI_Smart_PainSplit`: pointless while the enemy is the healthier of the two,
## which is `enemy hp * 2 > player hp` rather than a comparison of fractions.
static func _smart_pain_split(
	scores: Array, slot: int, attacker: Gen2BattleMon, defender: Gen2BattleMon
) -> void:
	if attacker.hp * 2 > defender.hp:
		_discourage(scores, slot, 1)


## `AI_Smart_LockOn`, whose two halves ask opposite questions.
##
## With the player already locked on, aiming again is wasted: every inaccurate
## move the enemy knows is encouraged instead, and Lock On itself is dismissed.
## The walk stops at the first empty slot, which is `.dismiss`.
##
## Without it, the ladder is health, then speed, then whether the accuracy is
## actually a problem: a sharply raised evasion or a sharply lowered accuracy is
## worth aiming for, a mild one is not worth a turn, and past both it comes down
## to whether any move in the list is inaccurate enough to want the help and at
## least neutral against the target.
static func _smart_lock_on(
	scores: Array, slot: int, attacker: Gen2BattleMon, defender: Gen2BattleMon,
	data: GameData, rng: RandomNumberGenerator
) -> void:
	if Gen2Substatus.has(defender.substatus, Gen2Substatus.LOCK_ON):
		for other: int in Gen2BattleMon.MAX_MOVES:
			if other >= attacker.moves.size() or int(attacker.moves[other]) == 0:
				break
			var known: Dictionary = _move_at(attacker, data, other)
			if int(known.get("accuracy", Gen2Accuracy.ALWAYS_HITS)) < LOCK_ON_WANTED_ACCURACY:
				_encourage(scores, other, 2)
		_discourage(scores, slot)
		return

	if not _above_quarter(attacker):
		_discourage(scores, slot, 1)
		return
	if not _above_half(attacker) and not _faster(attacker, defender):
		_discourage(scores, slot, 1)
		return

	# `.skip_speed_check`'s ladder, in its order: the first test that matches wins.
	var evasion: int = defender.stage("evasion")
	var accuracy: int = attacker.stage("accuracy")
	var wanted: bool = evasion >= 3
	if not wanted:
		if evasion >= 1:
			return
		wanted = accuracy < -2
	if not wanted:
		if accuracy < 0:
			return
		if _lock_on_has_wanting_move(attacker, defender, data):
			return
		_discourage(scores, slot, 1)
		return

	if _skip_50_50(rng):
		return
	_encourage(scores, slot, 2)


## `.checkmove`: whether any move in the list is inaccurate enough to want the
## help and at least neutral against the target. Everything accurate is passed
## over, and running out of slots, or reaching an empty one, answers no.
static func _lock_on_has_wanting_move(
	attacker: Gen2BattleMon, defender: Gen2BattleMon, data: GameData
) -> bool:
	for slot: int in Gen2BattleMon.MAX_MOVES:
		if slot >= attacker.moves.size() or int(attacker.moves[slot]) == 0:
			return false
		var move: Dictionary = _move_at(attacker, data, slot)
		if int(move.get("accuracy", Gen2Accuracy.ALWAYS_HITS)) >= LOCK_ON_WANTED_ACCURACY:
			continue
		if data.type_effectiveness(
			int(move.get("type", RomLayout.TYPE_NORMAL)), defender.types(),
			Gen2Substatus.has(defender.substatus, Gen2Substatus.IDENTIFIED)
		) >= RomLayout.MATCHUP_EFFECTIVE:
			return true
	return false


## `cp 71 percent - 1`, which is 180: the accuracy byte at or above which a move
## does not need the help.
const LOCK_ON_WANTED_ACCURACY: int = 180


## `AI_Smart_Spite`: worth it against a move the target is nearly out of, wasted
## against one it has plenty of.
##
## The target has not moved yet in the first branch, so there is nothing to drain
## and the question is only whether the enemy would get to see a move first.
static func _smart_spite(
	scores: Array, slot: int, attacker: Gen2BattleMon, defender: Gen2BattleMon,
	rng: RandomNumberGenerator
) -> void:
	var last_move: int = defender.last_counter_move
	if last_move == 0:
		if _faster(attacker, defender):
			_discourage(scores, slot)
			return
		if _skip_50_50(rng):
			return
		_discourage(scores, slot, 1)
		return

	# `.moveloop`, which walks the target's own list and returns without scoring
	# when the move is not in it.
	var drained: int = defender.moves.find(last_move)
	if drained < 0:
		return

	var left: int = defender.pp_left(drained)
	if left < SPITE_WANTED_PP:
		if _rolls_under(rng, AI_39_PERCENT_PLUS_ONE):
			return
		_encourage(scores, slot, 2)
		return
	if left < SPITE_PLENTY_PP and not _rolls_under(rng, AI_39_PERCENT_PLUS_ONE):
		return
	_discourage(scores, slot, 1)


## `cp 6` and `cp 15`: below the first is worth draining, at or above the second
## is not, and between them a roll decides.
const SPITE_WANTED_PP: int = 6
const SPITE_PLENTY_PP: int = 15


## `AI_Smart_Thief`: `add $1e`, and nothing else. Thirty points is past every
## other move on the list, so Thief is thrown only when there is nothing else.
const THIEF_PENALTY: int = 30


## `AI_Smart_Foresight`: worth it against a sharply raised evasion, a sharply
## lowered accuracy of its own, or a Ghost, which is the only target the flag
## opens a type matchup against. Otherwise almost always discouraged.
static func _smart_foresight(
	scores: Array, slot: int, attacker: Gen2BattleMon, defender: Gen2BattleMon,
	rng: RandomNumberGenerator
) -> void:
	var wanted: bool = attacker.stage("accuracy") < -2 \
		or defender.stage("evasion") >= 3 \
		or defender.types().has(RomLayout.TYPE_GHOST)
	if not wanted:
		if _roll(rng, FORESIGHT_DISCOURAGE_SKIP_PERCENT):
			return
		_discourage(scores, slot, 1)
		return

	if _rolls_under(rng, AI_39_PERCENT_PLUS_ONE):
		return
	_encourage(scores, slot, 2)


## `AI_Smart_MeanLook`: the source only wants the trap from above half health,
## with a live bench, or against a player who is already trapped in a costly
## state. The Toxic branch is intentionally the cartridge's bug: it encourages
## Mean Look because the AI's own Pokémon is badly poisoned.
static func _smart_mean_look(
	scores: Array, slot: int, attacker: Gen2BattleMon, defender: Gen2BattleMon,
	rng: RandomNumberGenerator, has_bench: bool, matchup_score: int
) -> void:
	if attacker.hp * 2 < attacker.max_hp():
		_discourage(scores, slot)
		return
	if not has_bench:
		_discourage(scores, slot)
		return

	var strongly_wanted: bool = attacker.toxic_counter > 0 or Gen2Substatus.has(
		defender.substatus,
		Gen2Substatus.ATTRACTED | Gen2Substatus.ROLLOUT
		| Gen2Substatus.IDENTIFIED | Gen2Substatus.NIGHTMARE
	)
	if strongly_wanted:
		if not _skip_80_20(rng):
			_encourage(scores, slot, 3)
		return

	# CheckPlayerMoveTypeMatchups returns 11 when the player has only resisted
	# attacks. That is the one ordinary case where Mean Look is not discouraged.
	if matchup_score < Gen2AISwitch.COMFORTABLE_SCORE:
		_discourage(scores, slot, 1)


## `cp 8 percent; ret c`: the one-in-twelve chance the penalty is not applied, the
## same roll [constant PROTECT_DISCOURAGE_SKIP_PERCENT] names.
const FORESIGHT_DISCOURAGE_SKIP_PERCENT: int = 8


## `AI_Smart_Pursuit`: worth two points against a target nearly down, discouraged
## against one that is not, since a Pokémon with health left is unlikely to run.
static func _smart_pursuit(
	scores: Array, slot: int, defender: Gen2BattleMon, rng: RandomNumberGenerator
) -> void:
	if not _above_quarter(defender):
		if _skip_50_50(rng):
			return
		_encourage(scores, slot, 2)
		return
	if _skip_80_20(rng):
		return
	_discourage(scores, slot, 1)


## `AI_Smart_Protect`: one ladder of tests, first match winning, and the two exits
## are asymmetric. `.encourage` is an 80% roll and one point off; `.discourage` is
## a two-point penalty that an 8% roll skips outright, and `.greatly_discourage`
## adds a point and falls into it, so the worst case is three.
##
static func _smart_protect(
	scores: Array, slot: int, attacker: Gen2BattleMon, defender: Gen2BattleMon,
	rng: RandomNumberGenerator
) -> void:
	if attacker.protect_count != 0:
		_smart_protect_discourage(scores, slot, rng, true)
		return

	# The second test reads `wPlayerSubStatus5`, the flag a Lock On the enemy used
	# left on the player: with a guaranteed hit already lined up, sitting the turn
	# out wastes it.
	if Gen2Substatus.has(defender.substatus, Gen2Substatus.LOCK_ON):
		_smart_protect_discourage(scores, slot, rng, false)
		return

	var encourage: bool = defender.fury_cutter_count >= PROTECT_FURY_CUTTER_COUNT \
		or Gen2Substatus.has(defender.substatus, Gen2Substatus.CHARGING) \
		or defender.toxic_counter > 0 \
		or Gen2Substatus.has(defender.substatus, Gen2Substatus.LEECH_SEED) \
		or Gen2Substatus.has(defender.substatus, Gen2Substatus.CURSE)

	if not encourage:
		# The Rollout test is the fall-through, and it is two refusals in one: a
		# player not rolling at all discourages, and one rolling under three
		# discourages as well. Only a boosted Rollout reaches `.encourage`.
		if not Gen2Substatus.has(defender.substatus, Gen2Substatus.ROLLOUT) \
			or defender.rollout_count < PROTECT_ROLLOUT_COUNT:
			_smart_protect_discourage(scores, slot, rng, false)
			return

	if _skip_80_20(rng):
		return
	_encourage(scores, slot, 1)


## `cp 3` on both counts: what makes a Fury Cutter or a Rollout worth sitting out.
const PROTECT_FURY_CUTTER_COUNT: int = 3
const PROTECT_ROLLOUT_COUNT: int = 3


## `.greatly_discourage` falls into `.discourage`, so the extra point is added in
## front of the roll that can skip the other two.
static func _smart_protect_discourage(
	scores: Array, slot: int, rng: RandomNumberGenerator, greatly: bool
) -> void:
	if greatly:
		_discourage(scores, slot, 1)
	if _roll(rng, PROTECT_DISCOURAGE_SKIP_PERCENT):
		return
	_discourage(scores, slot, 2)


## `cp 8 percent; ret c`: the one-in-twelve chance the penalty is not applied.
const PROTECT_DISCOURAGE_SKIP_PERCENT: int = 8


## `AI_Smart_Endure`: the same opening test as Protect, then health, then the one
## reason to want to survive on a single point.
##
## Reversal is looked for by effect rather than by move number, which is
## `AIHasMoveEffect`, and Flail carries the same byte, so either move answers.
##
## `.no_reversal` is the other reason: `wEnemySubStatus5`, the flag a Lock On the
## *player* used left on the enemy. A guaranteed incoming hit is exactly what
## surviving on one point is for.
static func _smart_endure(
	scores: Array, slot: int, attacker: Gen2BattleMon, data: GameData,
	rng: RandomNumberGenerator
) -> void:
	if attacker.protect_count != 0 or _at_max_hp(attacker):
		_discourage(scores, slot, 2)
		return
	if _above_quarter(attacker):
		_discourage(scores, slot, 1)
		return
	if not _has_move_effect(attacker, data, Gen2MoveEffect.REVERSAL):
		if not Gen2Substatus.has(attacker.substatus, Gen2Substatus.LOCK_ON):
			return
		if _skip_50_50(rng):
			return
		_encourage(scores, slot, 2)
		return
	if _skip_80_20(rng):
		return
	_encourage(scores, slot, 3)


## `AIHasMoveEffect`: whether this Pokémon knows any move carrying [param effect].
##
## An empty slot ends the search rather than being skipped, which is the source's
## own `and a / jr z, .no`, and PP and Disable are not asked about at all. The
## first costs nothing on a packed move list and is kept because the list is only
## packed by convention.
static func _has_move_effect(mon: Gen2BattleMon, data: GameData, effect: int) -> bool:
	for slot: int in Gen2BattleMon.MAX_MOVES:
		if slot >= mon.moves.size() or int(mon.moves[slot]) == 0:
			return false
		if _effect(_move_at(mon, data, slot)) == effect:
			return true
	return false


static func _smart_belly_drum(scores: Array, slot: int, attacker: Gen2BattleMon) -> void:
	if attacker.stage("attack") >= 3:
		_discourage(scores, slot, 5)
		return
	if _at_max_hp(attacker):
		return
	_discourage(scores, slot, 1)
	if not _above_half(attacker):
		_discourage(scores, slot, 5)


static func _smart_psych_up(
	scores: Array, slot: int, attacker: Gen2BattleMon, defender: Gen2BattleMon,
	rng: RandomNumberGenerator
) -> void:
	var enemy_sum: int = 0
	var player_sum: int = 0
	for key: String in Gen2BattleMon.STAGED_STATS + Gen2BattleMon.STAGED_ODDS:
		enemy_sum += attacker.stage(key)
		player_sum += defender.stage(key)

	if enemy_sum >= player_sum:
		_discourage(scores, slot, 2)
		return
	if defender.stage("accuracy") < -1:
		return
	if attacker.stage("evasion") > 0:
		return
	if _skip_80_20(rng):
		return
	_encourage(scores, slot, 1)


## [constant RomLayout.AI_OPPORTUNIST]: discourage [constant STALL_MOVE_NUMBERS]
## once its own HP is low, more insistently the lower it is.
static func _apply_opportunist(scores: Array, c: Context) -> void:
	var attacker: Gen2BattleMon = c.attacker
	var data: GameData = c.data
	var rng: RandomNumberGenerator = c.rng
	if _above_half(attacker):
		return
	if _above_quarter(attacker) and _skip_50_50(rng):
		return

	for slot: int in Gen2BattleMon.MAX_MOVES:
		if not attacker.can_use(slot):
			continue
		var move: Dictionary = _move_at(attacker, data, slot)
		if STALL_MOVE_NUMBERS.has(int(move.get("number", 0))):
			_discourage(scores, slot, 1)


## [constant RomLayout.AI_AGGRESSIVE]: discourage every damaging move but
## whichever deals the most, unless it would cost the mon itself
## ([constant RECKLESS_EFFECTS]) or does one point of damage that is really a
## fixed-damage move ([code]power < 2[/code]).
##
## The estimate is [constant Gen2Damage.MAX_VARIATION] with no critical, the top
## of a hit's real range. `AIDamageCalc` special-cases fixed-damage effects this
## engine does not implement, so those use the ordinary formula: that shifts how
## hard they rank, not which move is strongest.
static func _apply_aggressive(scores: Array, c: Context) -> void:
	var attacker: Gen2BattleMon = c.attacker
	var defender: Gen2BattleMon = c.defender
	var data: GameData = c.data
	var defender_screens: int = c.defender_screens
	var best_slot: int = -1
	var best_damage: int = -1
	for slot: int in Gen2BattleMon.MAX_MOVES:
		if not attacker.can_use(slot):
			continue
		var move: Dictionary = _move_at(attacker, data, slot)
		if _power(move) <= 0:
			continue
		var damage: int = _estimate_damage(attacker, defender, move, defender_screens)
		if damage >= best_damage:
			best_damage = damage
			best_slot = slot

	if best_slot == -1 or best_damage <= 0:
		return

	for slot: int in Gen2BattleMon.MAX_MOVES:
		if slot == best_slot or not attacker.can_use(slot):
			continue
		var move: Dictionary = _move_at(attacker, data, slot)
		if _power(move) < 2:
			continue
		if RECKLESS_EFFECTS.has(_effect(move)):
			continue
		_discourage(scores, slot, 1)


## The AI's own damage prediction, which is `EnemyAttackDamage` and
## `BattleCommand_DamageCalc` themselves rather than an approximation of them, so
## it reads the player's screens exactly as a real hit would.
static func _estimate_damage(
	attacker: Gen2BattleMon, defender: Gen2BattleMon, move: Dictionary,
	defender_screens: int = Gen2Screens.NONE
) -> int:
	return int(Gen2Damage.calculate_with(
		attacker, defender, move, false, Gen2Damage.MAX_VARIATION,
		false, Gen2Weather.NONE, defender_screens
	)["damage"])


## [constant RomLayout.AI_CAUTIOUS]: discourage [constant RESIDUAL_MOVE_NUMBERS]
## once it is no longer the attacker's first turn.
##
## Diverges from a documented source bug (`docs/bugs_and_glitches.md`,
## "'Cautious' AI may fail to discourage residual moves") unless
## `cautious_ai_abandons_remaining_moves` is on: `ret nc` abandons the remaining
## slots on a missed roll, where pret's own fix moves on to the next one.
static func _apply_cautious(scores: Array, c: Context) -> void:
	var attacker: Gen2BattleMon = c.attacker
	var data: GameData = c.data
	var rng: RandomNumberGenerator = c.rng
	var atk_turns: int = c.atk_turns
	if atk_turns == 0:
		return
	for slot: int in Gen2BattleMon.MAX_MOVES:
		if not attacker.can_use(slot):
			continue
		var move: Dictionary = _move_at(attacker, data, slot)
		if not RESIDUAL_MOVE_NUMBERS.has(int(move.get("number", 0))):
			continue
		if _roll(rng, 90):
			_discourage(scores, slot, 1)
		elif Gen2Rules.hardware(&"cautious_ai_abandons_remaining_moves"):
			return


## [constant RomLayout.AI_STATUS]: dismiss a status move the defender's typing
## shrugs off. Toxic and Poison need no poison-type shortcut, since a Poison-type
## defender against a Poison-type move already reads
## [constant RomLayout.MATCHUP_NO_EFFECT] out of the real chart.
static func _apply_status(scores: Array, c: Context) -> void:
	var attacker: Gen2BattleMon = c.attacker
	var defender: Gen2BattleMon = c.defender
	var data: GameData = c.data
	for slot: int in Gen2BattleMon.MAX_MOVES:
		if not attacker.can_use(slot):
			continue
		var move: Dictionary = _move_at(attacker, data, slot)
		var effect: int = _effect(move)
		if not STATUS_ONLY_EFFECTS.has(effect) and _power(move) > 0:
			continue

		var move_type: int = int(move.get("type", RomLayout.TYPE_NORMAL))
		if data.type_effectiveness(move_type, defender.types()) == RomLayout.MATCHUP_NO_EFFECT:
			_discourage(scores, slot)


## [constant RomLayout.AI_RISKY]: greatly encourage anything that would
## faint the defender outright. [constant RISKY_EFFECTS] (a move that costs
## the user its own faint, or skips the formula for a guaranteed hit) is held
## back on unless the attacker is already hurt.
static func _apply_risky(scores: Array, c: Context) -> void:
	var attacker: Gen2BattleMon = c.attacker
	var defender: Gen2BattleMon = c.defender
	var data: GameData = c.data
	var rng: RandomNumberGenerator = c.rng
	var defender_screens: int = c.defender_screens
	for slot: int in Gen2BattleMon.MAX_MOVES:
		if not attacker.can_use(slot):
			continue
		var move: Dictionary = _move_at(attacker, data, slot)
		if _power(move) <= 0:
			continue

		if RISKY_EFFECTS.has(_effect(move)):
			if _at_max_hp(attacker):
				continue
			if _roll(rng, 79):
				continue

		if _estimate_damage(attacker, defender, move, defender_screens) >= defender.hp:
			_encourage(scores, slot, 5)


## `BattleCheckTypeMatchup` run for the enemy's turn: what [param move] would do
## to whoever is standing opposite, Foresight included.
static func _matchup(c: Context, move: Dictionary) -> int:
	return c.data.type_effectiveness(
		int(move.get("type", RomLayout.TYPE_NORMAL)), c.defender.types(),
		Gen2Substatus.has(c.defender.substatus, Gen2Substatus.IDENTIFIED)
	)


## `SUBSTATUS_TOXIC`, which this engine keeps as the ramp counter itself: the
## counter only ever runs while the badly-poisoned flag is set.
static func _badly_poisoned(mon: Gen2BattleMon) -> bool:
	return mon.toxic_counter > 0


## `and 1 << SUBSTATUS_FLYING | 1 << SUBSTATUS_UNDERGROUND`, which five handlers
## test as one thing: a target no ordinary move can reach this turn.
static func _is_semi_invulnerable(mon: Gen2BattleMon) -> bool:
	return Gen2Substatus.has(mon.substatus, Gen2Substatus.FLYING | Gen2Substatus.UNDERGROUND)


## `AI_Smart_LeechHit`: a draining move is worth it when it is super effective
## and there is room to put the drain, and mostly not worth it when it is not.
static func _smart_leech_hit(scores: Array, slot: int, c: Context) -> void:
	var matchup: int = _matchup(c, _move_at(c.attacker, c.data, slot))
	if matchup < RomLayout.MATCHUP_EFFECTIVE:
		if not _rolls_under(c.rng, AI_39_PERCENT_PLUS_ONE):
			_discourage(scores, slot, 1)
		return
	if matchup == RomLayout.MATCHUP_EFFECTIVE:
		return
	if _at_max_hp(c.attacker):
		return
	if not _skip_80_20(c.rng):
		_encourage(scores, slot, 1)


## `AI_Smart_Selfdestruct`: fainting on purpose is only a trade when there is
## nothing left to trade away, or when the mon is nearly gone anyway.
static func _smart_selfdestruct(scores: Array, slot: int, c: Context) -> void:
	# `FindAliveEnemyMons` returning carry is a bench to fall back on, and
	# `AICheckLastPlayerMon`'s `nz` is a player who still has one too.
	if not c.has_bench and c.defender_has_bench:
		_discourage(scores, slot, 3)
		return
	if _above_half(c.attacker):
		_discourage(scores, slot, 3)
		return
	if not _above_quarter(c.attacker):
		return
	if _roll(c.rng, 8):
		return
	_discourage(scores, slot, 3)


## The half of `AI_Smart_EvasionUp` and `AI_Smart_AccuracyDown` that is one body
## under two labels: what an accuracy gap is worth once neither routine has
## already made up its mind.
static func _evasion_tail(scores: Array, slot: int, c: Context) -> void:
	if _badly_poisoned(c.defender):
		if not _rolls_under(c.rng, AI_39_PERCENT_PLUS_ONE):
			_encourage(scores, slot, 2)
		return
	if Gen2Substatus.has(c.defender.substatus, Gen2Substatus.LEECH_SEED):
		if not _skip_50_50(c.rng):
			_encourage(scores, slot, 1)
		return
	if c.defender.stage("accuracy") < c.attacker.stage("evasion"):
		_discourage(scores, slot, 1)
		return
	if c.defender.fury_cutter_count > 0 \
			or Gen2Substatus.has(c.defender.substatus, Gen2Substatus.ROLLOUT):
		_encourage(scores, slot, 2)
		return
	_discourage(scores, slot, 1)


## `AI_Smart_EvasionUp`. The whole routine is a ladder on the enemy's own HP:
## the healthier it is, the more a turn spent on evasion is worth.
static func _smart_evasion_up(scores: Array, slot: int, c: Context) -> void:
	if c.attacker.stage("evasion") >= Gen2Stats.MAX_STAGE:
		_discourage(scores, slot)
		return
	if _at_max_hp(c.attacker):
		if _badly_poisoned(c.defender) or _roll(c.rng, 70):
			_encourage(scores, slot, 2)
			return
		_evasion_tail(scores, slot, c)
		return
	if not _above_quarter(c.attacker):
		_discourage(scores, slot, 2)
		_evasion_tail(scores, slot, c)
		return
	if _roll(c.rng, 4):
		_encourage(scores, slot, 2)
		return
	if not _above_half(c.attacker):
		if _skip_50_50(c.rng):
			_evasion_tail(scores, slot, c)
			return
		_discourage(scores, slot, 2)
		_evasion_tail(scores, slot, c)
		return
	if _skip_80_20(c.rng):
		_encourage(scores, slot, 2)
		return
	_evasion_tail(scores, slot, c)


## `AI_Smart_AccuracyDown`: the same ladder read off the player's HP instead,
## with the enemy's own half-HP check standing in front of the full-HP arm.
static func _smart_accuracy_down(scores: Array, slot: int, c: Context) -> void:
	if _at_max_hp(c.defender) and _above_half(c.attacker):
		if _badly_poisoned(c.defender) or _roll(c.rng, 70):
			_encourage(scores, slot, 2)
			return
		_evasion_tail(scores, slot, c)
		return
	if not _above_quarter(c.defender):
		_discourage(scores, slot, 2)
		_evasion_tail(scores, slot, c)
		return
	if _roll(c.rng, 4):
		_encourage(scores, slot, 2)
		return
	if not _above_half(c.defender):
		if _skip_50_50(c.rng):
			_evasion_tail(scores, slot, c)
			return
		_discourage(scores, slot, 2)
		_evasion_tail(scores, slot, c)
		return
	if _skip_80_20(c.rng):
		_encourage(scores, slot, 2)
		return
	_evasion_tail(scores, slot, c)


## `AI_Smart_AlwaysHit`: Swift and its kin are worth reaching for exactly when
## the accuracy chain has gone against the enemy by three stages either way.
static func _smart_always_hit(scores: Array, slot: int, c: Context) -> void:
	if c.attacker.stage("accuracy") >= -2 and c.defender.stage("evasion") < 3:
		return
	if not _skip_80_20(c.rng):
		_encourage(scores, slot, 2)


## `AI_Smart_Ohko`: dismissed outright against a higher level, since the move
## itself refuses, and discouraged against a target still above half.
static func _smart_ohko(
	scores: Array, slot: int, attacker: Gen2BattleMon, defender: Gen2BattleMon
) -> void:
	if attacker.level < defender.level:
		_discourage(scores, slot)
		return
	if not _above_half(defender):
		_discourage(scores, slot, 1)


## `AI_Smart_Unused2B`, which no move in either pin reaches: it belongs to
## `EFFECT_UNUSED_2B` and is here because a mod naming that effect would.
static func _smart_unused_2b(scores: Array, slot: int, c: Context) -> void:
	if Gen2Substatus.has(c.attacker.substatus, Gen2Substatus.PERISH) \
			and c.attacker.perish_count < 3:
		_discourage(scores, slot, 1)
		return
	for number: int in c.defender_used_moves:
		if _effect(c.data.move(number)) == Gen2MoveEffect.PROTECT:
			_discourage(scores, slot, 6)
			return
	if not Gen2Substatus.has(c.attacker.substatus, Gen2Substatus.CONFUSED) \
			and _above_half(c.attacker):
		return
	if _rolls_under(c.rng, AI_79_PERCENT_MINUS_ONE):
		return
	_discourage(scores, slot, 1)


## `AI_Smart_SpDefenseUp2`: Amnesia is for a healthy mon facing special damage,
## and for nothing else.
static func _smart_sp_defense_up_2(scores: Array, slot: int, c: Context) -> void:
	if not _above_half(c.attacker) or c.attacker.stage("sp_defense") >= 4:
		_discourage(scores, slot, 1)
		return
	if c.attacker.stage("sp_defense") >= 2:
		return
	var special: bool = false
	for move_type: int in c.defender.types():
		if not Gen2Damage.is_physical(move_type):
			special = true
			break
	if not special or _skip_80_20(c.rng):
		return
	_encourage(scores, slot, 2)


## `AI_Smart_SpeedDownHit`, which reads the move's own animation byte and so is
## Icy Wind alone. The importer drops that byte because it is the move number.
static func _smart_speed_down_hit(scores: Array, slot: int, c: Context) -> void:
	if int(_move_at(c.attacker, c.data, slot).get("number", 0)) != Gen2MoveEffect.ICY_WIND_MOVE:
		return
	if not _above_quarter(c.attacker) or c.def_turns != 0:
		return
	if _faster(c.attacker, c.defender) or _roll(c.rng, 12):
		return
	_encourage(scores, slot, 2)


## `AI_Smart_Rage`: worth more the longer the counter has been running, and
## worth starting only from a healthy mon.
static func _smart_rage(
	scores: Array, slot: int, attacker: Gen2BattleMon, rng: RandomNumberGenerator
) -> void:
	if not Gen2Substatus.has(attacker.substatus, Gen2Substatus.RAGE):
		if not _above_half(attacker):
			_discourage(scores, slot, 1)
		elif _skip_80_20(rng):
			_encourage(scores, slot, 1)
		return
	if not _skip_50_50(rng):
		_encourage(scores, slot, 1)
	if attacker.rage_count < 2:
		return
	_encourage(scores, slot, 1)
	if attacker.rage_count < 3:
		return
	_encourage(scores, slot, 1)


## `AI_Smart_Disable`: only from in front, and only against a move worth taking
## away. `.notencourage` reads the scored move's own power, so a damaging
## Disable-effect move is left alone rather than discouraged.
static func _smart_disable(scores: Array, slot: int, c: Context) -> void:
	if _faster(c.attacker, c.defender):
		if USEFUL_MOVE_NUMBERS.has(c.defender.last_counter_move):
			if not _rolls_under(c.rng, AI_39_PERCENT_PLUS_ONE):
				_encourage(scores, slot, 1)
			return
		if _power(_move_at(c.attacker, c.data, slot)) > 0:
			return
	if _roll(c.rng, 8):
		return
	_discourage(scores, slot, 1)


## `AI_Smart_Counter` and `AI_Smart_MirrorCoat`, which are one routine reading
## the other half of the physical/special split: three remembered hits of the
## right half make it worth the guess, and the last one seen decides a tie.
static func _smart_counter(scores: Array, slot: int, c: Context, physical: bool) -> void:
	var seen: int = 0
	for number: int in c.defender_used_moves:
		var move: Dictionary = c.data.move(number)
		if _power(move) <= 0:
			continue
		if Gen2Damage.is_physical(int(move.get("type", RomLayout.TYPE_NORMAL))) != physical:
			continue
		seen += 1

	if seen == 0:
		_discourage(scores, slot, 1)
		return
	if seen < 3:
		if c.defender.last_counter_move == 0:
			return
		var last: Dictionary = c.data.move(c.defender.last_counter_move)
		if _power(last) <= 0:
			return
		if Gen2Damage.is_physical(int(last.get("type", RomLayout.TYPE_NORMAL))) != physical:
			return
	if _rolls_under(c.rng, AI_39_PERCENT_PLUS_ONE):
		return
	_encourage(scores, slot, 1)


## `AI_Smart_Encore`: locking the player into what it just did, which is worth
## most when that move cannot hurt the enemy at all.
static func _smart_encore(scores: Array, slot: int, c: Context) -> void:
	if not _faster(c.attacker, c.defender):
		_discourage(scores, slot, 3)
		return
	if c.defender.last_move_used == 0:
		_discourage(scores, slot)
		return

	var last: Dictionary = c.data.move(c.defender.last_move_used)
	var weak: bool = _power(last) <= 0
	if not weak:
		# `CheckTypeMatchup` against `wEnemyMonType1`: the enemy scoring how the
		# player's last move lands on itself, which is the other direction from
		# every other matchup in this file.
		var matchup: int = c.data.type_effectiveness(
			int(last.get("type", RomLayout.TYPE_NORMAL)), c.attacker.types(),
			Gen2Substatus.has(c.attacker.substatus, Gen2Substatus.IDENTIFIED)
		)
		if matchup >= RomLayout.MATCHUP_EFFECTIVE:
			weak = true
		elif matchup != RomLayout.MATCHUP_NO_EFFECT:
			return
	if weak and not ENCORE_MOVE_NUMBERS.has(c.defender.last_counter_move):
		_discourage(scores, slot, 3)
		return
	if _rolls_under(c.rng, AI_28_PERCENT_MINUS_ONE):
		return
	_encourage(scores, slot, 2)


## `AI_Smart_HealBell`: dismissed when nobody on the enemy's side is statused,
## and worth most when the one that is out is asleep or frozen.
static func _smart_heal_bell(scores: Array, slot: int, c: Context) -> void:
	if c.bench_status_mask == Gen2Status.NONE:
		if c.attacker.status == Gen2Status.NONE:
			_discourage(scores, slot)
		return
	if c.attacker.status != Gen2Status.NONE:
		_encourage(scores, slot, 1)
	if not Gen2Status.has(
		c.attacker.status, Gen2Status.FREEZE | Gen2Status.SLEEP_MASK
	):
		return
	if _skip_50_50(c.rng):
		return
	_encourage(scores, slot, 2)


## `AI_Smart_PriorityHit`: Quick Attack is for going second, and it is only
## worth encouraging when it would finish the player off.
static func _smart_priority_hit(scores: Array, slot: int, c: Context) -> void:
	if _faster(c.attacker, c.defender):
		return
	if _is_semi_invulnerable(c.defender):
		_discourage(scores, slot)
		return
	var move: Dictionary = _move_at(c.attacker, c.data, slot)
	if _estimate_damage(c.attacker, c.defender, move, c.defender_screens) > c.defender.hp:
		_encourage(scores, slot, 3)


## `AI_Smart_Curse`, two routines under one label: a Ghost pays half its own HP
## and wants the trade to be the last one, and everything else is reading
## whether an attack raise will be spent.
static func _smart_curse(scores: Array, slot: int, c: Context) -> void:
	if c.attacker.types().has(RomLayout.TYPE_GHOST):
		_smart_ghost_curse(scores, slot, c)
		return
	if not _above_half(c.attacker) or c.attacker.stage("attack") >= 4:
		_discourage(scores, slot, 1)
		return
	if c.attacker.stage("attack") >= 2:
		return
	var types: Array = c.defender.types()
	var first: int = int(types[0]) if not types.is_empty() else RomLayout.TYPE_NORMAL
	if first == RomLayout.TYPE_GHOST:
		_discourage(scores, slot, 2)
		return
	# A player made of special types will not feel the defence, so the attack
	# raise has to be worth it on its own.
	for move_type: int in types:
		if not Gen2Damage.is_physical(move_type):
			return
	if _skip_80_20(c.rng):
		return
	_encourage(scores, slot, 2)


## `.ghost_curse`: never twice, never as the last mon against a player who still
## has a bench, and best from full HP on the player's first turn.
static func _smart_ghost_curse(scores: Array, slot: int, c: Context) -> void:
	if Gen2Substatus.has(c.defender.substatus, Gen2Substatus.CURSE):
		_discourage(scores, slot)
		return
	if not c.has_bench and c.defender_has_bench:
		_discourage(scores, slot, 4)
		return
	if c.has_bench and not c.defender_has_bench:
		if not _skip_50_50(c.rng):
			_encourage(scores, slot, 2)
		return
	if not _above_quarter(c.attacker):
		_discourage(scores, slot, 4)
		return
	if not _above_half(c.attacker):
		_discourage(scores, slot, 2)
		return
	if not _at_max_hp(c.attacker) or c.def_turns != 0:
		return
	if not _skip_50_50(c.rng):
		_encourage(scores, slot, 2)


## `AI_Smart_Rollout`: a run that has to survive several turns, so anything that
## might interrupt it, or any accuracy gap, is a reason to stop.
static func _smart_rollout(scores: Array, slot: int, c: Context) -> void:
	var risky: bool = Gen2Substatus.has(
		c.attacker.substatus, Gen2Substatus.ATTRACTED | Gen2Substatus.CONFUSED
	)
	risky = risky or Gen2Status.has(c.attacker.status, Gen2Status.PARALYSIS)
	risky = risky or not _above_quarter(c.attacker)
	risky = risky or c.attacker.stage("accuracy") < 0
	risky = risky or c.defender.stage("evasion") >= 1
	if risky:
		if not _skip_80_20(c.rng):
			_discourage(scores, slot, 1)
		return
	if not _rolls_under(c.rng, AI_79_PERCENT_MINUS_ONE):
		return
	_encourage(scores, slot, 2)


## `AI_Smart_FuryCutter`, which pays out on the counter and then falls straight
## into `AI_Smart_Rollout` for the rest of the reading.
static func _smart_fury_cutter(scores: Array, slot: int, c: Context) -> void:
	var count: int = c.attacker.fury_cutter_count
	if count >= 1:
		_encourage(scores, slot, 1)
	if count >= 2:
		_encourage(scores, slot, 2)
	if count >= 3:
		_encourage(scores, slot, 3)
	_smart_rollout(scores, slot, c)


## `AI_Smart_Attract`: worth a turn against a Pokémon that has only just come
## out, and a wasted one against anything else.
static func _smart_attract(scores: Array, slot: int, c: Context) -> void:
	if c.def_turns != 0:
		if not _skip_80_20(c.rng):
			_discourage(scores, slot, 1)
		return
	if not _rolls_under(c.rng, AI_79_PERCENT_MINUS_ONE):
		return
	_encourage(scores, slot, 1)


## `AI_Smart_Earthquake` and `AI_Smart_Gust`: the same routine reading Dig or
## Fly. A player already underground or airborne is punished from in front, and
## one that has only used the move before is a guess taken from behind.
static func _smart_ground_or_air(
	scores: Array, slot: int, c: Context, move_number: int, flag: int
) -> void:
	if c.defender.last_counter_move != move_number:
		return
	if Gen2Substatus.has(c.defender.substatus, flag):
		if _faster(c.attacker, c.defender):
			_encourage(scores, slot, 2)
		return
	if _faster(c.attacker, c.defender) or _skip_50_50(c.rng):
		return
	_encourage(scores, slot, 1)


## `AI_Smart_RapidSpin`: the only reason to spin is something stuck to the
## enemy's own side of the field.
static func _smart_rapid_spin(scores: Array, slot: int, c: Context) -> void:
	var stuck: bool = c.attacker.trapped_turns > 0
	stuck = stuck or Gen2Substatus.has(c.attacker.substatus, Gen2Substatus.LEECH_SEED)
	stuck = stuck or Gen2Screens.has(c.attacker_screens, Gen2Screens.SPIKES)
	if not stuck or _skip_80_20(c.rng):
		return
	_encourage(scores, slot, 2)


## `AI_Smart_HiddenPower`: the type and power the enemy's own DVs give it,
## scored the way any other attack would be.
static func _smart_hidden_power(scores: Array, slot: int, c: Context) -> void:
	var resolved: Dictionary = Gen2Damage.hidden_power(c.attacker.dvs)
	var matchup: int = c.data.type_effectiveness(
		int(resolved["type"]), c.defender.types(),
		Gen2Substatus.has(c.defender.substatus, Gen2Substatus.IDENTIFIED)
	)
	var power: int = int(resolved["power"])
	if matchup < RomLayout.MATCHUP_EFFECTIVE or power < 50:
		_discourage(scores, slot, 1)
		return
	if matchup > RomLayout.MATCHUP_EFFECTIVE or power >= 70:
		_encourage(scores, slot, 1)
