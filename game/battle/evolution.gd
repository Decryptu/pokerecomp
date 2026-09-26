class_name Gen2Evolution
extends RefCounted

## `EvolveAfterBattle`'s branches in engine/pokemon/evolve.asm, one predicate
## per caller: the battle's level pass, the pack's stone and the link's trade.

const HAPPINESS_TO_EVOLVE: int = 220
const EVERSTONE: int = 70
## Item effects.asm dispatches every one of these through EvoStoneEffect.
const STONE_ITEMS: Array[int] = [8, 0x16, 0x17, 0x18, 0x22, 0xA9]


## The same rows on either cartridge. Generation 1 numbers its items the other
## way up and shares only $22 with the run above, where it is a Water Stone and
## a Sun Stone respectively.
static func stone_items(data: GameData) -> Array[int]:
	if data != null and data.generation == RomRegistry.GEN1:
		return Gen1Layout.STONE_ITEMS
	return STONE_ITEMS
## A trade evolution's parameter when it asks for no held item: `inc a / jr z`.
const TRADE_NO_ITEM: int = 0xFF

static func level_evolution(data: GameData, mon: Gen2BattleMon, time_of_day: int) -> Dictionary:
	if data == null or mon == null:
		return {}
	if mon.item == EVERSTONE:
		return {}
	for row: Dictionary in data.evolutions(mon.species):
		if _eligible(row, mon, time_of_day):
			return row.duplicate(true)
	return {}


## `.item`, which is the one branch of `EvolveAfterBattle` that never calls
## `IsMonHoldingEverstone`. The refusal is one level up, in `EvoStoneEffect`'s
## own `cp EVERSTONE`, so it belongs to whoever uses the item rather than here.
static func item_evolution(data: GameData, mon: Gen2BattleMon, item: int) -> Dictionary:
	if data == null or mon == null:
		return {}
	for row: Dictionary in data.evolutions(mon.species):
		if int(row.get("method", 0)) == Gen2Layout.EVOLVE_ITEM \
			and int(row.get("parameter", 0)) == item:
			return row.duplicate(true)
	return {}


## `.trade`: EVERSTONE refuses, a `$FF` parameter asks for nothing, and any other
## value is an item the Pokemon must be HOLDING, which the Time Capsule's
## `cp LINK_TIMECAPSULE` refuses outright. The cartridge zeroes `wTempMonItem`
## on the way through, so a held requirement is CONSUMED; that is the caller's
## to write, and [code]consumes_held_item[/code] says when.
static func trade_evolution(
	data: GameData, mon: Gen2BattleMon, link_mode: int = Gen2LinkTransport.LINK_TRADECENTER
) -> Dictionary:
	if data == null or mon == null or mon.item == EVERSTONE:
		return {}
	for row: Dictionary in data.evolutions(mon.species):
		if int(row.get("method", 0)) != Gen2Layout.EVOLVE_TRADE:
			continue
		var parameter: int = int(row.get("parameter", TRADE_NO_ITEM))
		if parameter == TRADE_NO_ITEM:
			return row.duplicate(true)
		if mon.item != parameter or link_mode == Gen2LinkTransport.LINK_TIMECAPSULE:
			continue
		var out: Dictionary = row.duplicate(true)
		out["consumes_held_item"] = parameter
		return out
	return {}


## `EvolvingText` then `CongratulationsYourPokemonText` and `_EvolvedIntoText`,
## as the one line each. Verbatim from data/text/common_3.asm; the source shows
## them as two boxes with the animation between them.
static func evolving_text(mon_name: String) -> String:
	return "What? %s is evolving!" % mon_name


static func evolved_text(mon_name: String, new_species_name: String) -> String:
	return "Congratulations! Your %s evolved into %s!" % [mon_name, new_species_name]


## `UpdateSpeciesNameIfNotNicknamed`, which runs before `GetBaseData` reloads
## the new species: the comparison is against the OLD species' name, since
## `wBaseDexNo` still holds it. A Pokemon carrying its own species name is not
## nicknamed, so it takes the new one; anything else keeps what it was called.
static func nickname_after_evolution(
	data: GameData, nickname: String, old_species: int, new_species: int
) -> String:
	if data == null or old_species == new_species:
		return nickname
	# A cartridge party row always holds a name, so an empty one here is this
	# project's own way of saying un-nicknamed rather than a third case.
	if not nickname.is_empty() \
		and nickname != String(data.species(old_species).get("name", "")):
		return nickname
	return String(data.species(new_species).get("name", nickname))


static func _eligible(row: Dictionary, mon: Gen2BattleMon, time_of_day: int) -> bool:
	var method: int = int(row.get("method", 0))
	var parameter: int = int(row.get("parameter", 0))
	if method == Gen2Layout.EVOLVE_LEVEL:
		return mon.level >= parameter
	if method == Gen2Layout.EVOLVE_HAPPINESS:
		if mon.happiness < HAPPINESS_TO_EVOLVE:
			return false
		if parameter == Gen2Layout.TRIGGER_ANYTIME:
			return true
		if parameter == Gen2Layout.TRIGGER_MORNDAY:
			return time_of_day != Gen2WorldPalette.TIME_NIGHT
		return parameter == Gen2Layout.TRIGGER_NITE \
			and time_of_day == Gen2WorldPalette.TIME_NIGHT
	if method == Gen2Layout.EVOLVE_STAT:
		if mon.level < parameter:
			return false
		var attack: int = int(mon.stats.get("attack", 0))
		var defense: int = int(mon.stats.get("defense", 0))
		var condition: int = int(row.get("condition", 0))
		if condition == Gen2Layout.ATTACK_OVER_DEFENSE:
			return attack > defense
		if condition == Gen2Layout.ATTACK_UNDER_DEFENSE:
			return attack < defense
		return condition == Gen2Layout.ATTACK_EQUALS_DEFENSE \
			and attack == defense
	return false


static func evolve(mon: Gen2BattleMon, target: int) -> Dictionary:
	if mon == null or mon.data == null or target <= 0 \
		or target == mon.species or mon.data.species(target).is_empty():
		return {}
	var old_species: int = mon.species
	var old_hp: int = mon.hp
	var before_max_hp: int = mon.max_hp()
	mon.species = target
	mon.battle_types.clear()
	mon.hp = 0
	mon.recalculate()
	# `evolve.asm` adds the max-HP delta, preserving damage through evolution.
	mon.hp = clampi(old_hp + mon.max_hp() - before_max_hp, 0, mon.max_hp())
	return {"old_species": old_species, "new_species": target}


## `StoppedEvolvingText`, printed by `CancelEvolution` before the master loop
## moves on to the next party member.
static func stopped_evolving_text(mon_name: String) -> String:
	return "Huh? %s stopped evolving!" % mon_name


## `EvolveAfterBattle`'s master loop as a list of plans: nothing here writes a
## party row, so a caller can apply only the ones not cancelled. [param evolvable]
## is `wEvolvableFlags`; `.trade` and `.item` never pass after a battle.
## [param active_species] is what Generation 1's loop reads ([method red_blue_stone_row]).
static func after_battle(
	data: GameData, save: Gen2SaveData, evolvable: Array, time_of_day: int,
	active_species: int = 0
) -> Array:
	var plans: Array = []
	if data == null or save == null:
		return plans
	var flagged: Array[int] = []
	for battle_index: int in evolvable:
		var mapped: int = Gen2SaveBattleAdapter.save_party_index(save, int(battle_index))
		if mapped >= 0:
			flagged.append(mapped)
	for index: int in save.party.size():
		if not flagged.has(index):
			continue
		var mon: Gen2SaveMon = save.party[index]
		if mon == null or mon.is_egg:
			continue
		var battle_mon: Gen2BattleMon = Gen2SaveBattleAdapter.to_battle_mon(data, mon)
		if battle_mon == null:
			continue
		var row: Dictionary = level_evolution(data, battle_mon, time_of_day)
		if row.is_empty():
			row = red_blue_stone_row(data, battle_mon, active_species)
		if row.is_empty():
			continue
		var target: int = int(row.get("target", 0))
		if target <= 0 or target == mon.species or data.species(target).is_empty():
			continue
		plans.append(plan(data, mon, index, row, true))
	return plans


## One pass of the master loop as the evolution screen plays it.
## [param can_cancel] is `.pressed_b`'s `wForceEvolution` test.
static func plan(
	data: GameData, mon: Gen2SaveMon, index: int, row: Dictionary, can_cancel: bool
) -> Dictionary:
	return {
		"index": index,
		"old_species": mon.species,
		"new_species": int(row.get("target", 0)),
		"level": mon.level,
		# `GetNickname` / `CopyName1` fill wStringBuffer2 before the species is
		# replaced, and every box of the sequence reads it.
		"evolving_name": Gen2SaveMon.display_name(mon, data),
		# `.check_statused`'s `CheckFaintedFrzSlp`, which costs the cry and the
		# closing `AnimateFrontpic` both.
		"statused": is_statused(mon),
		# `SCGB_EVOLUTION` reaches `GetMonNormalOrShinyPalettePointer`, and an
		# evolution changes the species rather than the DV word.
		"shiny": Gen2Stats.is_shiny(mon.dvs),
		"can_cancel": can_cancel,
		"row": row.duplicate(true),
	}


## Red and Blue's `.checkItemEvo` compares a stone row against `wCurItem`, which
## is `wCurPartySpecies`: the last thing `DrawPlayerHUDAndHPBar` wrote there is
## the player's own battler, so a party member that gained a level evolves off a
## stone whose item id is that battler's index. Measured on both cartridges: a
## GROWLITHE ($21, THUNDER_STONE) winning evolves a PIKACHU behind it, and
## Yellow's `wIsInBattle` test refuses the row.
static func red_blue_stone_row(data: GameData, mon: Gen2BattleMon, active_species: int) -> Dictionary:
	if data == null or mon == null or data.generation != RomRegistry.GEN1 \
		or data.id == RomRegistry.YELLOW or active_species <= 0:
		return {}
	var index: int = int(data.species(active_species).get("index", 0))
	for row: Dictionary in data.evolutions(mon.species):
		if int(row.get("method", 0)) == Gen2Layout.EVOLVE_ITEM \
			and int(row.get("parameter", 0)) == index:
			return row.duplicate(true)
	return {}


## `CheckFaintedFrzSlp`, which `EvolutionAnimation.check_statused` asks about the
## party row rather than about a battler: fainted, frozen or asleep.
static func is_statused(mon: Gen2SaveMon) -> bool:
	if mon == null:
		return true
	return mon.hp <= 0 or (mon.status & Gen2Status.FREEZE) != 0 \
		or Gen2Status.is_asleep(mon.status)
