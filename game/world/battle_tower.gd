class_name Gen2BattleTower
extends RefCounted

## `SECTION "SRAM Battle Tower"` and the routines that read it: the challenge's
## own state, the seven trainers it has already sampled, and the levels, rules
## and rewards `engine/events/battle_tower/` decides from them.
##
## Scene free. The world screen owns the two menus and the battle; this record
## owns the SRAM section and every answer `BattleTowerAction`, `LoadOpponentTrainerAndPokemon`
## and `_CheckForBattleTowerRules` give from it.

## constants/battle_tower_constants.asm's `sBattleTowerChallengeState` values.
const NO_CHALLENGE: int = 0
const SAVED_AND_LEFT: int = 1
const CHALLENGE_IN_PROGRESS: int = 2
const WON_CHALLENGE: int = 3
const RECEIVED_REWARD: int = 4

const PARTY_LENGTH: int = Gen2Layout.BATTLETOWER_PARTY_LENGTH
const STREAK_LENGTH: int = Gen2Layout.BATTLETOWER_STREAK_LENGTH
const NUM_UNIQUE_MON: int = Gen2Layout.BATTLETOWER_NUM_UNIQUE_MON
const NUM_UNIQUE_TRAINERS: int = Gen2Layout.BATTLETOWER_NUM_UNIQUE_TRAINERS
const LEVEL_GROUPS: int = Gen2Layout.BATTLETOWER_LEVEL_GROUPS
## `sBTTrainers` is filled with `$ff` by `ResetBattleTowerTrainersSRAM`, which is
## also what makes "no trainer sampled yet" a value no trainer index can be.
const NO_TRAINER: int = 0xFF

## `BattleTowerAction`'s own jumptable indices, in the order
## constants/battle_tower_constants.asm declares them. Only the rows a script
## the player can reach uses are named; the rest are the mobile adapter's and
## answer [method action]'s default.
const ACTION_CHECK_EXPLANATION_READ: int = 0
const ACTION_SET_EXPLANATION_READ: int = 1
const ACTION_GET_CHALLENGE_STATE: int = 2
const ACTION_SAVE_AND_QUIT: int = 3
const ACTION_CHALLENGE_CANCELED: int = 4
const ACTION_MOBILE_RECORD_CLEAR: int = 6
const ACTION_SAVE_LEVEL_GROUP: int = 7
const ACTION_LOAD_LEVEL_GROUP: int = 8
const ACTION_CHECK_SAVE_FILE_IS_YOURS: int = 9
const ACTION_MAX_VOLUME: int = 10
const ACTION_MOBILE_CLEAR_ROOM_FLAG: int = 17
const ACTION_LEVEL_CHECK: int = 24
const ACTION_UBERS_CHECK: int = 25
const ACTION_RESET_DATA: int = 26
const ACTION_GIVE_REWARD: int = 27
const ACTION_SET_WON_CHALLENGE: int = 28
const ACTION_SET_RECEIVED_REWARD: int = 29
const ACTION_CHOOSE_REWARD: int = 30
const ACTION_SAVE_OPTIONS: int = 31

## `sBattleTowerSaveFileFlags`. Bit 1 is the explanation the receptionist only
## offers once; bit 0 is the mobile half's own and nothing local reads it.
const FLAG_MOBILE_READ: int = 1
const FLAG_EXPLANATION_READ: int = 2

## `BATTLETOWER_MIN_REWARD` and `BATTLETOWER_MAX_REWARD`, the stat boosters
## `BattleTower_RandomlyChooseReward` rolls between, and the LUCKY_PUNCH sitting
## inside the run that it rerolls. `BattleTower_GiveReward` answers POTION when
## the pack cannot hold five more of the roll, which the script prints its
## "stuffed full" line from.
const MIN_REWARD: int = 26
const MAX_REWARD: int = 31
const LUCKY_PUNCH: int = 30
const REWARD_QUANTITY: int = 5
const REWARD_FULL_PACK: int = 18

## `BattleTower_UbersCheck`: MEWTWO, MEW and everything from LUGIA up may only
## enter a room of Lv.70 or higher, and the check is skipped outright once the
## chosen group is that high.
const UBER_MEWTWO: int = 150
const UBER_MEW: int = 151
const UBER_FIRST_LEGENDARY: int = 249
const UBER_MIN_LEVEL: int = 70

## `BattleTowerRoomMenu_PlacePickLevelMenu`: four rows before the Hall of Fame
## and all ten after it, CANCEL behind either.
const PRE_HALL_OF_FAME_GROUPS: int = 4

## How many times a `.resample` loop is drawn before the guard below answers.
## The cartridge's own loops are unbounded and cannot hang; see
## [method _first_unsampled_trainer].
const RESAMPLE_LIMIT: int = 256

## `BattleTowerText`'s two arrays and the three lines each trainer owns.
const TEXT_GREETING: int = 0
const TEXT_LOSS: int = 1
const TEXT_WIN: int = 2

## `sBattleTowerChallengeState`
var challenge_state: int = NO_CHALLENGE
## `sNrOfBeatenBattleTowerTrainers`, which is also where in `sBTTrainers` the
## next sampled trainer is written.
var beaten: int = 0
## `sBTChoiceOfLevelGroup`, 1 to 10. Zero until a challenge has chosen one.
var level_group: int = 0
## `wBTChoiceOfLvlGroup`, the WRAM byte the room menu writes and the hallway,
## the sampler and `SaveBattleTowerLevelGroup` read. Its own field because the
## two are written at different moments: the menu picks a room, and only the
## save at the end of a session copies that pick into SRAM.
var chosen_group: int = 0
## `sBTTrainers`, seven trainer indices or [constant NO_TRAINER].
var trainers: Array = []
var save_file_flags: int = 0
## `sBattleTowerReward`, chosen once per challenge by
## `BattleTower_RandomlyChooseReward` and handed over only at the end of it.
var reward: int = 0
## `sBTMonPrevTrainer1`-`3` and `sBTMonPrevPrevTrainer1`-`3`, the species of the
## last two teams: the sampler refuses a species either of them used.
var previous_mons: Array = []
var earlier_mons: Array = []


func _init() -> void:
	trainers = _filled(STREAK_LENGTH, NO_TRAINER)
	previous_mons = _filled(PARTY_LENGTH, 0)
	earlier_mons = _filled(PARTY_LENGTH, 0)


static func _filled(size: int, value: int) -> Array:
	var out: Array = []
	for _index: int in size:
		out.append(value)
	return out


func to_dict() -> Dictionary:
	return {
		"challenge_state": challenge_state,
		"beaten": beaten,
		"level_group": level_group,
		"chosen_group": chosen_group,
		"trainers": trainers.duplicate(),
		"save_file_flags": save_file_flags,
		"reward": reward,
		"previous_mons": previous_mons.duplicate(),
		"earlier_mons": earlier_mons.duplicate(),
	}


## The stored shape, defaulting rather than versioning: a slot written before the
## tower existed reads as a save with no challenge in it, which is the truth
## about it.
static func from_dict(raw: Variant) -> Gen2BattleTower:
	var out := Gen2BattleTower.new()
	if not raw is Dictionary:
		return out
	var source: Dictionary = raw as Dictionary
	out.challenge_state = clampi(int(source.get("challenge_state", NO_CHALLENGE)), 0, RECEIVED_REWARD)
	out.beaten = clampi(int(source.get("beaten", 0)), 0, STREAK_LENGTH)
	out.level_group = clampi(int(source.get("level_group", 0)), 0, LEVEL_GROUPS)
	out.chosen_group = clampi(int(source.get("chosen_group", 0)), 0, LEVEL_GROUPS)
	out.save_file_flags = int(source.get("save_file_flags", 0)) & 0xFF
	out.reward = int(source.get("reward", 0)) & 0xFF
	out.trainers = _bytes_field(source.get("trainers", []), STREAK_LENGTH, NO_TRAINER)
	out.previous_mons = _bytes_field(source.get("previous_mons", []), PARTY_LENGTH, 0)
	out.earlier_mons = _bytes_field(source.get("earlier_mons", []), PARTY_LENGTH, 0)
	return out


static func _bytes_field(raw: Variant, size: int, fill: int) -> Array:
	var out: Array = _filled(size, fill)
	if not raw is Array:
		return out
	var source: Array = raw as Array
	for index: int in mini(size, source.size()):
		out[index] = int(source[index]) & 0xFF
	return out


func duplicate_tower() -> Gen2BattleTower:
	return from_dict(to_dict())


## `ResetBattleTowerTrainersSRAM`: every sampled trainer forgotten and the count
## back to zero. The level group, the reward and the save-file flags are not
## touched, which is why a cancelled challenge still remembers the explanation.
func reset_trainers() -> void:
	trainers = _filled(STREAK_LENGTH, NO_TRAINER)
	beaten = 0


## The highest level a party member may be for [param group], `wcd4f * 10` in
## `BattleTower_LevelCheck`.
static func group_level(group: int) -> int:
	return group * 10


## `BattleTower_LevelCheck`, which fails on the first party member above the
## chosen group's level. -1 when the party is inside it.
##
## [param party] is the read-only party mirror the script runner carries:
## `species`, `levels`, `held_items` and `eggs`, one entry per slot.
static func level_check(party: Dictionary, group: int) -> int:
	var levels: Array = party.get("levels", []) as Array
	var cap: int = group_level(group)
	for index: int in levels.size():
		if int(levels[index]) > cap:
			return index
	return -1


## `BattleTower_UbersCheck`. Answers the offending party index, or -1. The whole
## check is skipped once the chosen group is Lv.70 or higher, which is what its
## own `cp 70 / 10` in front of the loop does.
static func ubers_check(party: Dictionary, group: int) -> int:
	if group_level(group) >= UBER_MIN_LEVEL:
		return -1
	var species: Array = party.get("species", []) as Array
	var levels: Array = party.get("levels", []) as Array
	for index: int in species.size():
		var number: int = int(species[index])
		var uber: bool = number == UBER_MEWTWO or number == UBER_MEW \
			or (number >= UBER_FIRST_LEGENDARY and number <= Gen2Layout.SPECIES_COUNT)
		if uber and index < levels.size() and int(levels[index]) < UBER_MIN_LEVEL:
			return index
	return -1


## `_CheckForBattleTowerRules`' four checks in its own order, each named by the
## box it prints. An empty Array is a party that may enter.
##
## `BattleTower_ExecuteJumptable` runs every check rather than stopping at the
## first, so a party can fail more than one and the receptionist says so once
## per failure.
static func rule_failures(party: Dictionary) -> Array:
	var species: Array = party.get("species", []) as Array
	var eggs: Array = party.get("eggs", []) as Array
	var out: Array = []
	if species.size() != PARTY_LENGTH:
		out.append("only_three_may_be_entered")
	if not _values_are_unique(species, eggs):
		out.append("must_all_be_different_kinds")
	if not _values_are_unique(party.get("held_items", []) as Array, eggs):
		out.append("must_not_hold_the_same_items")
	for index: int in eggs.size():
		if bool(eggs[index]):
			out.append("you_cant_take_an_egg")
			break
	return out


## `CheckPartyValueIsUnique`, which skips an egg on either side of the
## comparison and a zero on the left: three members holding nothing are not
## three members holding the same item.
static func _values_are_unique(values: Array, eggs: Array) -> bool:
	for first: int in values.size():
		if first < eggs.size() and bool(eggs[first]):
			continue
		var value: int = int(values[first])
		if value == 0:
			continue
		for second: int in range(first + 1, values.size()):
			if second < eggs.size() and bool(eggs[second]):
				continue
			if int(values[second]) == value:
				return false
	return true


## `LoadOpponentTrainerAndPokemon`: a trainer this streak has not sampled, and
## three Pokemon sharing no species or item within the team. Species from the
## last two teams are excluded too. Each mon carries its stored battle stats.
func load_opponent(data: GameData, random: RandomNumberGenerator) -> Dictionary:
	if data == null or not data.has_battle_tower():
		return {}
	var rows: Array = data.battle_tower().get("trainers", []) as Array
	if rows.is_empty():
		return {}
	var trainer: int = _sample_trainer(random)
	if beaten >= 0 and beaten < trainers.size():
		trainers[beaten] = trainer
	var record: Dictionary = rows[trainer % rows.size()] as Dictionary
	var mons: Array = _sample_mons(data, random)
	var sampled: Array = []
	for mon: Dictionary in mons:
		sampled.append(int(mon["species"]))
	earlier_mons = previous_mons.duplicate()
	previous_mons = sampled
	return {
		"trainer": trainer,
		"name": String(record.get("name", "")),
		"class": int(record.get("class", 0)),
		"mons": mons,
	}


## The `.resample` loop: `maskbits BATTLETOWER_NUM_UNIQUE_TRAINERS` is seven
## bits, so the roll is 0 to 127 and anything past the table is drawn again, as
## is any index already in `sBTTrainers`.
##
## Crystal 1.0 masks with `BATTLETOWER_NUM_UNIQUE_MON` instead and can only ever
## reach the first 21; the pinned dumps are 1.1, so this is the 1.1 branch.
func _sample_trainer(random: RandomNumberGenerator) -> int:
	for _attempt: int in RESAMPLE_LIMIT:
		var roll: int = random.randi() & 0x7F
		if roll >= NUM_UNIQUE_TRAINERS or trainers.has(roll):
			continue
		return roll
	return _first_unsampled_trainer()


## What a resample loop that will not terminate answers. The cartridge's own
## loop cannot hang: seven sampled trainers out of seventy always leave one, and
## the roll is uniform. A generator that is not costs a frozen game rather than
## a rare opponent, so the guard picks the lowest index the streak has not used.
func _first_unsampled_trainer() -> int:
	for index: int in NUM_UNIQUE_TRAINERS:
		if not trainers.has(index):
			return index
	return 0


## `LoadRandomBattleTowerMon`'s `.FindARandomBattleTowerMon`: three rows of the
## chosen level group, refusing a species or an item already on this team and a
## species either of the last two teams used.
func _sample_mons(data: GameData, random: RandomNumberGenerator) -> Array:
	var out: Array = []
	var group: int = clampi(chosen_group, 1, LEVEL_GROUPS) - 1
	for _slot: int in PARTY_LENGTH:
		var chosen: Dictionary = {}
		for _attempt: int in RESAMPLE_LIMIT:
			var roll: int = random.randi() & 0x1F
			if roll >= NUM_UNIQUE_MON:
				continue
			var candidate: Dictionary = mon_record(data, group, roll)
			if candidate.is_empty() or not _mon_is_free(candidate, out):
				continue
			chosen = candidate
			break
		if chosen.is_empty():
			chosen = _first_free_mon(data, group, out)
		if not chosen.is_empty():
			out.append(chosen)
	return out


func _mon_is_free(candidate: Dictionary, team: Array) -> bool:
	for mon: Dictionary in team:
		if mon.species == candidate.species or mon.item == candidate.item:
			return false
	return not previous_mons.has(candidate.species) \
		and not earlier_mons.has(candidate.species)


func _first_free_mon(data: GameData, group: int, team: Array) -> Dictionary:
	for index: int in NUM_UNIQUE_MON:
		var candidate: Dictionary = mon_record(data, group, index)
		if not candidate.is_empty() and _mon_is_free(candidate, team):
			return candidate
	return {}


## `InitEnemyMon` copies the six stored stats; `ValidateBTParty` is unreferenced.
static func mon_record(data: GameData, group: int, index: int) -> Dictionary:
	var raw: PackedByteArray = data.battle_tower_mon(group, index)
	var saved: Gen2SaveMon = Gen2SramAdapter.read_nicknamed_mon(raw, 0)
	if saved == null:
		return {}
	saved.nickname = String(data.species(saved.species).get("name", ""))
	var record: Dictionary = saved.to_dict()
	record["battle_stats"] = Gen2SramAdapter.read_party_stats(raw, 0)
	return record


## `BattleTowerText`: a male class draws from 25 lines and a female from 15, and
## the greeting's roll is remembered so the same trainer's win and loss lines
## come from the same personality. Answers { index, text }.
func trainer_line(
	data: GameData, trainer_class: int, kind: int, random: RandomNumberGenerator,
	remembered: int = -1
) -> Dictionary:
	var texts: Dictionary = data.battle_tower().get("texts", {}) as Dictionary
	var female: bool = is_class_female(data, trainer_class)
	var lines: Array = ((texts.get(
		Gen2Layout.BATTLETOWER_TEXT_KINDS[kind], {}
	) as Dictionary).get("female" if female else "male", []) as Array)
	if lines.is_empty():
		return {"index": 0, "text": ""}
	var index: int = remembered
	if kind == TEXT_GREETING or index < 0 or index >= lines.size():
		# The `dec c / jr nz, .restore` in the source: only the greeting rolls,
		# and the two lines behind it read `wBT_TrainerTextIndex` back.
		index = _roll_line(random, lines.size())
	return {"index": index, "text": String(lines[index])}


## `and $1f / cp 25 / sub 25` for a male and `and $f / cp 15 / sub 15` for a
## female: one mask and one subtraction rather than a resample, so the low
## indices are twice as likely as the high ones and that is the distribution.
static func _roll_line(random: RandomNumberGenerator, count: int) -> int:
	var mask: int = 0x1F if count > 16 else 0x0F
	var roll: int = random.randi() & mask
	return roll if roll < count else roll - count


## `BTTrainerClassGenders`, which the table indexes with the class minus one.
static func is_class_female(data: GameData, trainer_class: int) -> bool:
	var genders: Array = data.battle_tower().get("class_genders", []) as Array
	var index: int = trainer_class - 1
	if index < 0 or index >= genders.size():
		return false
	return int(genders[index]) != 0


## `BTTrainerClassSprites`, the overworld sprite
## `LoadOpponentTrainerAndPokemonWithOTSprite` gives the battle room's opponent
## object. Zero when the class is outside the table.
static func class_sprite(data: GameData, trainer_class: int) -> int:
	var sprites: Array = data.battle_tower().get("class_sprites", []) as Array
	var index: int = trainer_class - 1
	if index < 0 or index >= sprites.size():
		return 0
	return int(sprites[index])


## `BattleTower_RandomlyChooseReward`: one of the five stat boosters, LUCKY_PUNCH
## rerolled because it sits inside the run without being a reward. Stored rather
## than handed over, so the item the player gets after seven wins was decided
## before the first.
func choose_reward(random: RandomNumberGenerator) -> int:
	var span: int = MAX_REWARD - MIN_REWARD + 1
	for _attempt: int in RESAMPLE_LIMIT:
		var roll: int = random.randi() & 0x07
		if roll >= span:
			roll -= span
		var item: int = MIN_REWARD + roll
		if item == LUCKY_PUNCH:
			continue
		reward = item
		return item
	reward = MIN_REWARD
	return reward


## `BattleTower_GiveReward`: the stored item, or POTION when the pack has no room
## for five more of it. [param pack] is the item pocket as
## [code]{ item: quantity }[/code].
##
## The source's own shape, which is not "is there room": a pack under `MAX_ITEMS`
## always has room for a new row, and a full one only does when it already
## carries the reward with fewer than `MAX_ITEM_STACK - 5 + 1` of it.
func reward_for(pack: Dictionary) -> int:
	if pack.size() < Gen2WorldPack.MAX_ITEMS:
		return reward
	if pack.has(reward) \
		and int(pack[reward]) < Gen2WorldPack.MAX_ITEM_STACK - REWARD_QUANTITY + 1:
		return reward
	return REWARD_FULL_PACK


## `BattleTowerAction`'s jumptable, as the value it leaves in `wScriptVar`.
## An action that writes nothing there answers -1, which the runner leaves the
## variable alone for.
##
## The mobile rows are no-ops with a reason: each writes a byte in SRAM bank 5
## that only the mobile adapter's own routines read, and none of them reaches a
## script the player can talk to.
## The four actions whose whole body is the challenge state they write.
const CHALLENGE_STATE_ACTIONS: Dictionary = {
	ACTION_SAVE_AND_QUIT: SAVED_AND_LEFT,
	ACTION_CHALLENGE_CANCELED: NO_CHALLENGE,
	ACTION_SET_WON_CHALLENGE: WON_CHALLENGE,
	ACTION_SET_RECEIVED_REWARD: RECEIVED_REWARD,
}
const PARTY_CHECK_ACTIONS: Array[int] = [ACTION_LEVEL_CHECK, ACTION_UBERS_CHECK]


func action(index: int, context: Dictionary = {}) -> int:
	if CHALLENGE_STATE_ACTIONS.has(index):
		challenge_state = int(CHALLENGE_STATE_ACTIONS[index])
		return -1
	if PARTY_CHECK_ACTIONS.has(index):
		return _party_check(index, context.get("party", {}) as Dictionary)
	match index:
		ACTION_CHECK_EXPLANATION_READ:
			if not bool(context.get("save_is_yours", true)):
				return 0
			return save_file_flags & FLAG_EXPLANATION_READ
		ACTION_SET_EXPLANATION_READ:
			save_file_flags |= FLAG_EXPLANATION_READ
		ACTION_GET_CHALLENGE_STATE:
			return challenge_state
		ACTION_SAVE_LEVEL_GROUP:
			level_group = chosen_group
		ACTION_LOAD_LEVEL_GROUP:
			chosen_group = level_group
			return chosen_group
		ACTION_CHECK_SAVE_FILE_IS_YOURS:
			return 1 if bool(context.get("save_is_yours", true)) else 0
		ACTION_RESET_DATA:
			reset_trainers()
		ACTION_CHOOSE_REWARD:
			var random: Variant = context.get("random", null)
			if random is RandomNumberGenerator:
				choose_reward(random as RandomNumberGenerator)
		ACTION_GIVE_REWARD:
			return reward_for(context.get("pack", {}) as Dictionary)
	return -1


func _party_check(index: int, party: Dictionary) -> int:
	var refused: int = level_check(party, chosen_group) if index == ACTION_LEVEL_CHECK \
		else ubers_check(party, chosen_group)
	return 0 if refused < 0 else group_level(chosen_group)
