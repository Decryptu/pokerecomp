class_name Gen2Nuzlocke
extends RefCounted

## The Nuzlocke challenge's own state and rules, for a run whose
## [member Gen2Rules.challenge] is [constant Gen2Rules.CHALLENGE_NUZLOCKE].
##
## Its own file rather than [Gen2Rules] because a rule there names what the
## engine DOES and never changes, while this is what the run has SPENT: which
## areas have given up their one encounter, which Pokemon are gone, and whether
## the run is over. It lives on the save for the same reason the party does.
##
## Not [Gen2WorldPartyHost] either: the launcher's save screen reads a slot's
## graveyard and its verdict without a world, and the save model has to
## serialize the block whether or not one is loaded.
##
## The ruleset is the one Bulbapedia records: two mandatory rules (one catch per
## area, a faint is permanent) and the near-universal three beside them (every
## Pokemon nicknamed, no undoing a death by reloading, a full wipe ends the run).
## The optional clauses are not implemented: a dupes or shiny clause makes the
## challenge easier, and a run that wants one can play it by hand.

## How many losses a run's memorial keeps. A full party six times over, which is
## more than a finished Nuzlocke has ever needed, and a bound so a save cannot
## grow without one.
const MAX_GRAVEYARD: int = 36

## Why a run ended. Only one today; a second would be a rule that ends it.
const ENDED_WIPED: StringName = &"wiped"

## Why a Pokemon is in the graveyard. The two ways HP reaches zero where the
## player can see it.
const CAUSE_BATTLE: StringName = &"battle"
const CAUSE_POISON: StringName = &"poison"


## The stored shape, normalized. Every reader goes through this rather than
## trusting a file: a hand-edited save must cost a refused area, never a crash.
static func normalize(raw: Variant) -> Dictionary:
	if raw is not Dictionary or (raw as Dictionary).is_empty():
		return {}
	var row: Dictionary = raw
	var out: Dictionary = {"areas": {}, "graveyard": [], "ended": {}}
	var raw_areas: Variant = row.get("areas", {})
	if raw_areas is Dictionary:
		for key: Variant in raw_areas as Dictionary:
			var landmark: int = int(String(key))
			var entry: Variant = (raw_areas as Dictionary)[key]
			if landmark < 0 or entry is not Dictionary:
				continue
			(out["areas"] as Dictionary)[str(landmark)] = {
				"species": maxi(int((entry as Dictionary).get("species", 0)), 0),
				"caught": bool((entry as Dictionary).get("caught", false)),
			}
	var raw_graveyard: Variant = row.get("graveyard", [])
	if raw_graveyard is Array:
		for entry: Variant in (raw_graveyard as Array).slice(0, MAX_GRAVEYARD):
			if entry is Dictionary:
				(out["graveyard"] as Array).append(_normalize_grave(entry))
	var raw_ended: Variant = row.get("ended", {})
	if raw_ended is Dictionary and not (raw_ended as Dictionary).is_empty():
		out["ended"] = {
			"reason": String((raw_ended as Dictionary).get("reason", String(ENDED_WIPED))),
			"landmark": maxi(int((raw_ended as Dictionary).get("landmark", 0)), 0),
			"day": maxi(int((raw_ended as Dictionary).get("day", 0)), 0),
		}
	return out


static func _normalize_grave(entry: Dictionary) -> Dictionary:
	return {
		"species": maxi(int(entry.get("species", 0)), 0),
		"nickname": String(entry.get("nickname", "")).substr(0, Gen2NameRater.NICKNAME_LENGTH),
		"level": clampi(int(entry.get("level", 1)), 1, Gen2Experience.MAX_LEVEL),
		"cause": String(entry.get("cause", String(CAUSE_BATTLE))),
		"landmark": maxi(int(entry.get("landmark", 0)), 0),
	}


## Whether [param section] describes a run that can still be played. An empty
## block is a run that has lost nothing, which is a new one.
static func run_over(section: Dictionary) -> bool:
	var ended: Variant = section.get("ended", {})
	return ended is Dictionary and not (ended as Dictionary).is_empty()


## Ends the run. Writing it into the section is what makes it survive a reload,
## which is the whole of the no-resets rule this project can enforce.
static func end_run(section: Dictionary, landmark: int, day: int) -> void:
	if run_over(section):
		return
	section["ended"] = {
		"reason": String(ENDED_WIPED),
		"landmark": maxi(landmark, 0),
		"day": maxi(day, 0),
	}


## Whether this area has already given up its one encounter.
static func area_spent(section: Dictionary, landmark: int) -> bool:
	var areas: Variant = section.get("areas", {})
	return areas is Dictionary and (areas as Dictionary).has(str(maxi(landmark, 0)))


## Records this area's one encounter and answers whether it was still free. A
## claimed area answers false and the caller refuses the ball; the encounter is
## spent whether the Pokemon is caught, beaten or run from, which is the rule's
## "no second chances".
static func claim_area(section: Dictionary, landmark: int, species: int) -> bool:
	if landmark < 0:
		return false
	if area_spent(section, landmark):
		return false
	if section.get("areas", null) is not Dictionary:
		section["areas"] = {}
	(section["areas"] as Dictionary)[str(landmark)] = {
		"species": maxi(species, 0), "caught": false,
	}
	return true


## Marks this area's encounter as one that was actually caught, for the record
## the save screen shows. The area is already spent by the time this runs.
static func note_caught(section: Dictionary, landmark: int) -> void:
	var areas: Variant = section.get("areas", {})
	if areas is not Dictionary:
		return
	var entry: Variant = (areas as Dictionary).get(str(maxi(landmark, 0)), null)
	if entry is Dictionary:
		(entry as Dictionary)["caught"] = true


## Removes every fainted party member and records it, answering the rows it
## took in party order. The Pokemon is released rather than boxed: that is the
## rule as written, and a grave box would be six party slots a player could
## still reach.
##
## Eggs are skipped. An egg has no HP to lose and the cartridge never lets one
## take damage, so a zero there is a row shape rather than a death.
static func reap(save: Gen2SaveData, cause: StringName, landmark: int) -> Array:
	if save == null:
		return []
	var lost: Array = []
	var survivors: Array = []
	for member: Variant in save.party:
		var mon: Gen2SaveMon = member as Gen2SaveMon
		if mon == null:
			continue
		if mon.is_egg or mon.hp > 0:
			survivors.append(mon)
			continue
		lost.append(_normalize_grave({
			"species": mon.species,
			"nickname": mon.nickname,
			"level": mon.level,
			"cause": String(cause),
			"landmark": landmark,
		}))
	if lost.is_empty():
		return []
	save.party = survivors
	if save.nuzlocke.get("graveyard", null) is not Array:
		save.nuzlocke["graveyard"] = []
	var graveyard: Array = save.nuzlocke["graveyard"]
	graveyard.append_array(lost)
	if graveyard.size() > MAX_GRAVEYARD:
		save.nuzlocke["graveyard"] = graveyard.slice(
			graveyard.size() - MAX_GRAVEYARD, graveyard.size()
		)
	return lost


## The name a lost Pokemon is mourned by: its nickname, or the species when a
## row carries none.
static func grave_name(data: GameData, entry: Dictionary) -> String:
	var nickname: String = String(entry.get("nickname", ""))
	if not nickname.is_empty():
		return nickname
	if data == null:
		return "?"
	return String(data.species(int(entry.get("species", 0))).get("name", "?"))


## What the battle says after `%s fainted!` for the player's own Pokemon: the
## faint is the death, and the line says so where the player is looking.
static func death_text(nickname: String) -> String:
	return "%s is gone\nfor good..." % nickname


## `_WhitedOutText`'s place when the run cannot come back from it.
static func run_over_text(player_name: String) -> String:
	return "%s is out of\nuseable #MON!%s%s's\nNUZLOCKE is over." % [
		player_name, Gen2TextStream.PAGE_BREAK, player_name,
	]


## What the ball selector says instead of opening in an area that has already
## given up its encounter.
static func area_spent_text(area_name: String) -> String:
	if area_name.is_empty():
		return "You already met this area's #MON!"
	return "%s has already\ngiven its #MON!" % area_name
