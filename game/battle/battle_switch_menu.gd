class_name Gen2BattleSwitchMenu
extends RefCounted

## `PickSwitchMonInBattle` and `ForcePickSwitchMonInBattle`
## (`engine/battle/core.asm`): `OfferSwitch`'s YES can be backed out of; Baton
## Pass reaches `ForcePickPartyMonInBattle`, which answers a refusal with
## `SFX_WRONG`; `ForcePlayerMonChoice` makes no `SwitchMonAlreadyOut` check.
## CANCEL is a row in both because `SetUpBattlePartyMenu` goes through
## `InitPartyMenuWithCancel`.

const WRAPS: bool = true  ## `PartyMenu2DMenuData`'s `_2DMENU_WRAP_UP_DOWN`, its only movement flag.

const DEFAULT_CURSOR: int = 0  ## `InitPartyMenuWithCancel`'s `wMenuCursorY` 1: the first member.

## What [method confirm] and [method cancel] answer with.
const CHOSEN: StringName = &"chosen"
const CANCELLED: StringName = &"cancelled"
const ALREADY_OUT: StringName = &"already_out"
const NO_ENERGY: StringName = &"no_energy"
const EGG: StringName = &"egg"
const CANNOT_CANCEL: StringName = &"cannot_cancel"

## [Gen2PartyMenuPage]'s rows in party order. An egg keeps its slot with index -1.
var rows: Array = []

var forced: bool = false  ## `ForcePickSwitchMonInBattle` rather than `PickSwitchMonInBattle`.

var active: int = -1  ## What `SwitchMonAlreadyOut` compares against.

var cursor: int = DEFAULT_CURSOR  ## Zero-based over [method item_count], the CANCEL row last.

var gen1: bool = false  ## Whose refusal texts [method confirm] prints.


## [param save] holds the eggs the battle party left out.
static func for_party(
	party: Gen2Party, is_forced: bool = false, save: Gen2SaveData = null
) -> Gen2BattleSwitchMenu:
	var menu := Gen2BattleSwitchMenu.new()
	menu.forced = is_forced
	if party == null:
		return menu
	menu.active = party.active
	var lead: Gen2BattleMon = party.at(0)
	menu.gen1 = lead != null and lead.data != null and lead.data.generation == RomRegistry.GEN1
	if save != null and Gen2SaveBattleAdapter.egg_slots(party, save) <= 0:
		save = null
	var next: int = 0
	var slots: int = save.party.size() if save != null else party.size()
	for slot: int in slots:
		var saved: Gen2SaveMon = save.party[slot] if save != null else null
		if saved != null and saved.is_egg:
			menu.rows.append({"index": -1, "species": saved.species, "name": saved.nickname,
				"egg": true, "level": saved.level, "status": 0, "fainted": false})
			continue
		var mon: Gen2BattleMon = party.at(next)
		next += 1
		if mon == null:
			continue
		menu.rows.append({
			"index": next - 1,
			"species": mon.species,
			"item": mon.item,
			"name": mon.display_name(),
			"level": mon.level,
			"hp": mon.hp,
			"max_hp": mon.max_hp(),
			"status": mon.status,
			"fainted": mon.is_fainted(),
		})
	return menu


## `w2DMenuNumRows`: the party plus CANCEL.
func item_count() -> int:
	return rows.size() + 1


func is_cancel(index: int) -> bool:
	return index == rows.size()


## `_2DMENU_WRAP_UP_DOWN` over one column.
func move(delta: int) -> bool:
	if delta == 0 or item_count() <= 1:
		return false
	cursor = wrapi(cursor + delta, 0, item_count())
	return true


## `PartyMenuSelect` returning the row, then the two checks over it; a refusal
## leaves the list standing (`jr z, .loop`, `jr c, .pick`).
func confirm() -> Dictionary:
	if is_cancel(cursor):
		return cancel()
	if cursor < 0 or cursor >= rows.size():
		return {"result": CANNOT_CANCEL, "sfx": Gen2Sfx.SFX_WRONG}
	var row: Dictionary = rows[cursor]
	if bool(row.get("egg", false)):
		return {"result": EGG, "text": egg_text()}
	if bool(row.get("fainted", false)):
		return {"result": NO_ENERGY, "text": no_energy_text(gen1)}
	if int(row.get("index", -1)) == active:
		return {"result": ALREADY_OUT, "text": already_out_text(String(row.get("name", "")), gen1)}
	return {"result": CHOSEN, "index": int(row.get("index", -1))}


## B and the CANCEL row both set carry, which `ForcePickPartyMonInBattle`
## swallows.
func cancel() -> Dictionary:
	if forced:
		return {"result": CANNOT_CANCEL, "sfx": Gen2Sfx.SFX_WRONG}
	return {"result": CANCELLED}


## The list's line by why it is open: `BattleMenu_PKMN`'s CHOOSE_POKEMON, an item
## target's healing action, every other pick's SWITCH, and Generation 1's three.
static func prompt_text(data: GameData = null, reason: StringName = &"") -> String:
	match reason:
		&"player":
			return Gen2PartyScreen.prompt_text(data, &"normal", Gen2PartyScreen.PROMPT_CHOOSE)
		&"item":
			return Gen2PartyScreen.prompt_text(data, &"item_use", Gen2PartyScreen.PROMPT_USE_ON_WHICH)
	return Gen2PartyScreen.prompt_text(data, &"battle", "Which PKMN?")


## `BattleMonMenu.MenuData` and Generation 1's `SwitchStatsCancelText`.
const ACTIONS: Array[String] = ["SWITCH", "STATS", "CANCEL"]
const ACTION_BOX: Rect2i = Rect2i(11, 11, 8, 6)


static func action_menu() -> Gen2WorldMenu:
	var menu := Gen2WorldMenu.new()
	menu.options = ACTIONS.duplicate()
	menu.flags = Gen2WorldMenu.YES_NO_FLAGS
	menu.rows = ACTIONS.size()
	return menu


## `PlacePartyNicknames`' `.CancelString`, two columns left of the nicknames.
static func cancel_label() -> String:
	return "CANCEL"


## `BattleText_TheresNoWillToBattle` and Generation 1's `_NoWillText`.
static func no_energy_text(generation_1: bool = false) -> String:
	return "There's no will\nto fight!" if generation_1 else "There's no will to\nbattle!"


## `BattleText_AnEGGCantBattle`.
static func egg_text() -> String:
	return "An EGG can't\nbattle!"


## `BattleText_MonIsAlreadyOut` and Generation 1's `_AlreadyOutText`.
static func already_out_text(name: String, generation_1: bool = false) -> String:
	return ("%s is\nalready out!" if generation_1 else "%s\nis already out.") % name


## `AskUseNextPokemon`'s question, wild battles only: `_UseNextMonText` on both.
static func use_next_text() -> String:
	return "Use next #MON?"


## `BattleText_EnemyIsAboutToUseWillPlayerChangeMon` and `_TrainerAboutToUseText`.
static func offer_text(
	trainer: String, mon: String, player: String, generation_1: bool = false
) -> String:
	var opening: String = "%s is\nabout to use" if generation_1 else "%s\nis about to use"
	return (opening + Gen2TextStream.SCROLL_BREAK + "%s" + ("!" if generation_1 else ".")
		+ Gen2TextStream.PAGE_BREAK + "Will %s\nchange #MON?") % [trainer, mon, player]
