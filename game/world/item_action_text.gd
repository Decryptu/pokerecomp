class_name Gen2ItemActionText
extends RefCounted

## `.MenuActionTexts` and `PartyMenuItemUseMessagePointers`: a medicine's line
## over the party menu, in the field and in battle.

const HEAL: StringName = &"heal"
const REVIVE: StringName = &"revive"
const LEVEL: StringName = &"level"
const CONFUSION: StringName = &"confusion"
const STATUS_ACTIONS: Dictionary = {
	Gen2Status.POISON: &"poison", Gen2Status.BURN: &"burn", Gen2Status.FREEZE: &"freeze",
	Gen2Status.SLEEP_MASK: &"sleep", Gen2Status.PARALYSIS: &"paralysis",
	Gen2Status.ANY: &"all",
}
const TEXTS: Dictionary = {
	HEAL: "%s\nrecovered %dHP!",
	REVIVE: "%s\nis revitalized.",
	LEVEL: "%s grew to\nlevel %d!",
	CONFUSION: "%s came\nto its senses.",
	&"poison": "%s's\ncured of poison.",
	&"burn": "%s's\nburn was healed.",
	&"freeze": "%s\nwas defrosted.",
	&"sleep": "%s\nwoke up.",
	&"paralysis": "%s's\nrid of paralysis.",
	&"all": "%s's\nhealth returned.",
}
const GEN1_TEXTS: Dictionary = {
	HEAL: "%s\nrecovered by %d!",
	REVIVE: "%s\nis revitalized!",
	LEVEL: "%s grew\nto level %d!",
	&"poison": "%s was\ncured of poison!",
	&"burn": "%s's\nburn was healed!",
	&"freeze": "%s was\ndefrosted!",
	&"sleep": "%s\nwoke up!",
	&"paralysis": "%s's\nrid of paralysis!",
	&"all": "%s's\nhealth returned!",
}
## `ItemActionTextWaitButton`'s `DelayFrames 50`, and `.showHealingItemMessage`'s.
const HOLD_FRAMES: int = 50
const LOOKS_BITTER: String = "It looks bitter…"
const CANT_USE_ON_EGG: String = "That can't be used\non an EGG."


## The row [param result] earned, or none for a use with a plain line.
static func kind(data: GameData, item: int, result: Dictionary) -> StringName:
	if int(result.get("level", 0)) > 0:
		return LEVEL
	if StringName(result.get("effect", &"")) == &"revive" or bool(result.get("revived", false)):
		return REVIVE
	if int(result.get("healed", 0)) > 0:
		return HEAL
	if int(result.get("status_cleared", 0)) == 0:
		return CONFUSION if bool(result.get("unconfused", false)) else &""
	return STATUS_ACTIONS.get(int(data.item(item).get("status_mask", 0)), &"all")


static func text(row: StringName, target: String, result: Dictionary, gen1: bool) -> String:
	var line: String = String((GEN1_TEXTS if gen1 else TEXTS)[row])
	if row == LEVEL:
		return line % [target, int(result.get("level", 0))]
	if row == HEAL:
		return line % [target, int(result.get("healed", 0))]
	return line % target
