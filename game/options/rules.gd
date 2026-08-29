class_name Gen2Rules
extends RefCounted

## Which behaviour a run is played under: the places this project and the
## cartridge disagree on purpose, and which challenge the run was created under.
## Separate from [Gen2Options], because a rule changes what the engine DOES and so
## belongs to the run that produced a save. A flag is edited in Settings and the
## next new game takes a copy; [member challenge] is chosen when the game is made
## and never moves again. Every flag is named for the cartridge's behaviour, so a
## flag that is off is this project's corrected answer and a flag added later
## defaults to whatever [constant MODE_CURRENT] says.

## Every named flag, mapped to what [constant MODE_CURRENT] does today. The
## descriptions belong beside the branch, not here; each key names the
## `docs/bugs_and_glitches.md` entry it switches.
const FLAGS: Dictionary = {
	## `BattleCommand_BellyDrum` calls `BattleCommand_AttackUp2` BEFORE the HP
	## check, so a failed Belly Drum has already raised Attack by two stages.
	&"belly_drum_boosts_below_half_hp": false,
	## `CalcExpAtLevel` runs its formula at level 1, where the medium slow curve's
	## `- 140` underflows three bytes.
	&"medium_slow_level_one_underflow": false,
	## `AI_Cautious`'s `ret nc` abandons the remaining move slots on a failed
	## roll rather than moving on to the next one.
	&"cautious_ai_abandons_remaining_moves": false,
	## `ShortHPBar_CalcPixelFrame`'s off-by-one, which changes the HP NUMBER
	## printed mid-drain under a 48-pixel maximum and never the bar.
	&"short_hp_bar_number_off_by_one": false,
	## `DittoMetalPowder` runs past `TruncateHL_BC`, so a defence byte over 170
	## carries, halves the attack and folds back below where it started.
	&"metal_powder_overflow": true,
}

## What each flag is, for a player choosing one. Keyed like [constant FLAGS] and
## in its order: `title` names the bug and `detail` says what the CARTRIDGE does,
## which is what the flag reproduces when it is on. Said without a source symbol,
## because the symbols are beside the branches; this is the only wording a
## settings screen has, so a second copy in the launcher would go stale.
const FLAG_TEXT: Dictionary = {
	&"belly_drum_boosts_below_half_hp": {
		"title": "Belly Drum below half HP",
		"detail": "Attack is raised by two stages before the HP is checked, so a"
			+ " Belly Drum that fails for want of HP has already paid the boost.",
	},
	&"medium_slow_level_one_underflow": {
		"title": "Medium Slow at level 1",
		"detail": "The experience formula is run at level 1, where the medium slow"
			+ " curve underflows and asks for about 16 million points.",
	},
	&"cautious_ai_abandons_remaining_moves": {
		"title": "Cautious trainer AI",
		"detail": "A trainer weighing its moves stops at the first one a roll"
			+ " passes over, leaving the rest of them unscored.",
	},
	&"short_hp_bar_number_off_by_one": {
		"title": "Short HP bar's number",
		"detail": "The HP number printed while a short bar drains is rounded down"
			+ " where the rest of the routine rounds up, so it reads one low."
			+ " Never the bar itself.",
	},
	&"metal_powder_overflow": {
		"title": "Metal Powder on Ditto",
		"detail": "Boosting a Defense above 170 overflows, halves the attacker's"
			+ " Attack instead and folds the defence back below where it started.",
	},
}

## The mutual recoil faint is deliberately NOT a flag: the award pass
## already refuses a fainted recipient, so clearing the participant as
## `UpdateFaintedPlayerMon` does changes no outcome that can be observed. It
## becomes a flag when turn-event ordering makes the difference visible, and a
## flag with both sides identical would be scaffolding.

## What each mode answers for a flag. `current` is what shipped and is the
## default; `vanilla` reproduces every listed bug; `qol` corrects every one.
const MODE_CURRENT: StringName = &"current"
const MODE_VANILLA: StringName = &"vanilla"
const MODE_QOL: StringName = &"qol"
## Not a mode a player picks: what [method mode_of] answers once a flag has been
## moved away from every preset.
const MODE_CUSTOM: StringName = &"custom"
const MODES: Array[StringName] = [MODE_CURRENT, MODE_VANILLA, MODE_QOL]

## Which challenge a run is played under, chosen once when the save is created
## and never again: a run that met a trainer under one of these did not produce
## the state another would have. [constant CHALLENGE_VANILLA] is the cartridge's
## own game and is what a slot written before this existed reads as.
const CHALLENGE_VANILLA: StringName = &"vanilla"
const CHALLENGE_HARD: StringName = &"hard"
const CHALLENGE_NUZLOCKE: StringName = &"nuzlocke"
const CHALLENGES: Array[StringName] = [
	CHALLENGE_VANILLA, CHALLENGE_HARD, CHALLENGE_NUZLOCKE,
]

## What a screen calls each challenge. What each one DOES is
## [method challenge_detail], which builds its line rather than storing it so
## [constant HARD_LEVEL_BONUS_PERCENT] is stated once.
const CHALLENGE_TITLES: Dictionary = {
	CHALLENGE_VANILLA: "Vanilla",
	CHALLENGE_HARD: "Hard",
	CHALLENGE_NUZLOCKE: "Nuzlocke",
}

## How much higher a trainer's Pokemon is under [constant CHALLENGE_HARD], as a
## percentage of its own level and never less than one level. A global rule
## rather than a rewritten team per trainer: the cartridge's own parties stay
## recognisable and every one of the 800-odd trainers is covered by the one
## number.
const HARD_LEVEL_BONUS_PERCENT: int = 15

## Every stat's experience filled under [constant CHALLENGE_HARD], which is what
## a fully trained Pokemon carries. The cartridge gives a trainer's Pokemon none.
const HARD_STAT_EXP: int = Gen2Stats.MAX_STAT_EXP

## The rules the engine is playing under right now.
##
## Statics reach the run through here: [Gen2Experience], [Gen2Damage] and
## [Gen2BattleAI] take no engine object, and threading a rules argument through
## every one of them would put the same value in two places to disagree. So there
## is exactly one installed set at a time, and the two objects that own a run
## ([Gen2WorldAPI] and [Gen2Battle]) install what they were built with.
static var _active: Gen2Rules = null

var mode: StringName = MODE_CURRENT
## See [constant CHALLENGES]. Fixed for the life of the save that carries it.
var challenge: StringName = CHALLENGE_VANILLA
## Only the flags moved away from [member mode], so a mode change carries every
## flag the player never touched.
var overrides: Dictionary = {}


## The installed rules, which are [constant MODE_CURRENT]'s until something
## installs otherwise. Never null, so a caller never branches on having a run.
static func active() -> Gen2Rules:
	if _active == null:
		_active = Gen2Rules.new()
	return _active


## Plays under [param rules]. A null one restores the shipped behaviour, which is
## what a tool, a check or a test with no run of its own wants.
static func install(rules: Gen2Rules) -> void:
	_active = rules


## Whether the cartridge's behaviour is reproduced for [param flag]. An unknown
## flag answers false rather than crashing: a mod or a save may name one this
## build does not have.
func reproduces(flag: StringName) -> bool:
	if not FLAGS.has(flag):
		return false
	if overrides.has(flag):
		return bool(overrides[flag])
	return _mode_value(mode, flag)


## Reads the installed rules, for a static that has no run object in hand.
static func hardware(flag: StringName) -> bool:
	return active().reproduces(flag)


## Moves one flag off its mode. Refuses a flag this build does not name, so a
## typo in a mod is a refusal rather than a setting that silently does nothing.
func set_flag(flag: StringName, reproduce_hardware: bool) -> bool:
	if not FLAGS.has(flag):
		return false
	if _mode_value(mode, flag) == reproduce_hardware:
		overrides.erase(flag)
	else:
		overrides[flag] = reproduce_hardware
	return true


## The mode the flags actually describe, which is [constant MODE_CUSTOM] once one
## of them is not any preset's answer. What a settings row shows.
func mode_of() -> StringName:
	for candidate: StringName in MODES:
		var all_match: bool = true
		for flag: StringName in FLAGS:
			if reproduces(flag) != _mode_value(candidate, flag):
				all_match = false
				break
		if all_match:
			return candidate
	return MODE_CUSTOM


## Switches every flag the player has not moved. The overrides are kept, which is
## what makes a mode a starting point rather than a reset; [method clear_flags]
## is the reset.
func set_mode(new_mode: StringName) -> void:
	mode = new_mode if MODES.has(new_mode) else MODE_CURRENT
	for flag: StringName in overrides.keys():
		if _mode_value(mode, flag) == bool(overrides[flag]):
			overrides.erase(flag)


func clear_flags() -> void:
	overrides = {}


## The AI layers a trainer class scores with, its imported mask everywhere but
## [constant CHALLENGE_HARD], which adds every layer the class does not already
## have. Masked to the layers the scorer knows either way, so a patched trainer
## cannot ask for a bit nothing reads. Hard rewrites the imported mask rather
## than inventing numbers, since a score this project made up would not be this
## cartridge's game any more.
func ai_move_weights(imported: int) -> int:
	if challenge == CHALLENGE_HARD:
		return RomLayout.AI_MOVE_WEIGHTS_MASK
	return imported & RomLayout.AI_MOVE_WEIGHTS_MASK


## When a trainer class reaches into its bag and how readily it switches out.
## [constant CHALLENGE_HARD] moves every class onto
## [constant RomLayout.SWITCH_OFTEN] and leaves the item bits alone: a class with
## no held items has none to use, and giving it some would be a rewritten team.
func ai_item_switch(imported: int) -> int:
	var flags: int = imported & RomLayout.AI_ITEM_SWITCH_MASK
	if challenge != CHALLENGE_HARD:
		return flags
	flags &= ~(RomLayout.SWITCH_RARELY | RomLayout.SWITCH_SOMETIMES)
	return flags | RomLayout.SWITCH_OFTEN


## The level a trainer's Pokemon actually arrives at. One level is the floor, so
## the rule bites on the level 2 rival as well as on the level 50 champion.
func trainer_level(level: int) -> int:
	if challenge != CHALLENGE_HARD or level <= 0:
		return level
	@warning_ignore("integer_division")
	var bonus: int = (level * HARD_LEVEL_BONUS_PERCENT) / 100
	return mini(level + maxi(bonus, 1), Gen2Experience.MAX_LEVEL)


## The DV word a trainer's Pokemon carries: its class's own, or a perfect one
## under [constant CHALLENGE_HARD].
func trainer_dvs(imported: int) -> int:
	return Gen2BattleMon.PERFECT_DVS if challenge == CHALLENGE_HARD else imported


## The stat experience a trainer's Pokemon carries. The cartridge gives one
## none; [constant CHALLENGE_HARD] gives it a full set.
func trainer_stat_exp() -> Dictionary:
	if challenge != CHALLENGE_HARD:
		return {}
	var out: Dictionary = {}
	for key: String in Gen2Experience.STAT_EXP_KEYS:
		out[key] = HARD_STAT_EXP
	return out


func is_nuzlocke() -> bool:
	return challenge == CHALLENGE_NUZLOCKE


## The name a screen shows for [param challenge_name]. Unknown reads as the
## cartridge's own game, which is what an unreadable save is played as.
static func challenge_title(challenge_name: StringName) -> String:
	return String(CHALLENGE_TITLES.get(challenge_name, CHALLENGE_TITLES[CHALLENGE_VANILLA]))


## What [param challenge_name] actually does, said once here because the launcher is
## the only thing that says it and a second copy there would go stale.
static func challenge_detail(challenge_name: StringName) -> String:
	match challenge_name:
		CHALLENGE_HARD:
			return ("Every trainer scores with all ten of the game's own AI layers,"
				+ " switches out often, and brings a party %d%% higher with perfect"
				+ " DVs and full stat experience.") % HARD_LEVEL_BONUS_PERCENT
		CHALLENGE_NUZLOCKE:
			return ("One catch per area, a faint is permanent, every Pokemon is"
				+ " nicknamed, and losing the party ends the run for good.")
	return ("The cartridge's own game. Trainers bring the parties they were"
		+ " written with and a faint costs nothing but the walk back.")


func duplicate_rules() -> Gen2Rules:
	var out := Gen2Rules.new()
	out.mode = mode
	out.challenge = challenge
	out.overrides = overrides.duplicate()
	return out


func matches(other: Gen2Rules) -> bool:
	if other == null:
		return false
	if challenge != other.challenge:
		return false
	for flag: StringName in FLAGS:
		if reproduces(flag) != other.reproduces(flag):
			return false
	return true


## Only what differs from the mode, so a saved run stays readable and a flag
## added later is not written into a file that never chose it.
func to_dict() -> Dictionary:
	var flags: Dictionary = {}
	for flag: StringName in overrides:
		flags[String(flag)] = bool(overrides[flag])
	return {
		"mode": String(mode),
		"challenge": String(challenge),
		"flags": flags,
	}


## Clamped rather than refused, the way [method Gen2Options.parse] is: one
## unreadable value must not cost the player the rest of the block.
static func parse(raw: Variant) -> Gen2Rules:
	var out := Gen2Rules.new()
	if raw is not Dictionary:
		return out
	var row: Dictionary = raw
	var raw_mode := StringName(String(row.get("mode", "")))
	out.mode = raw_mode if MODES.has(raw_mode) else MODE_CURRENT
	## A slot written before the challenge existed named a trainer-AI difficulty
	## here instead, and reads as the cartridge's own game whatever it said.
	var raw_challenge := StringName(String(row.get("challenge", "")))
	out.challenge = raw_challenge if CHALLENGES.has(raw_challenge) else CHALLENGE_VANILLA
	var flags: Variant = row.get("flags", {})
	if flags is Dictionary:
		for key: Variant in flags as Dictionary:
			out.set_flag(StringName(String(key)), bool((flags as Dictionary)[key]))
	return out


## `current` is the table itself; `vanilla` and `qol` are its two ends.
static func _mode_value(for_mode: StringName, flag: StringName) -> bool:
	match for_mode:
		MODE_VANILLA:
			return true
		MODE_QOL:
			return false
	return bool(FLAGS.get(flag, false))
