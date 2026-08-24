class_name Gen2HallOfFame
extends RefCounted

## The induction sequence `halloffame` asks for, as pages a screen can draw.
##
## `engine/events/halloffame.asm`'s AnimateHallOfFame walks the party built by
## GetHallOfFameParty, showing one panel per Pokémon and then the player's own,
## so the order and the contents here are that routine's, not a choice.
## `HOF_AnimatePlayerPic` ends on `farcall ProfOaksPCRating`, whose two texts
## print into the empty box that panel opens under itself, so the player's panel
## is answered once per box rather than once.
##
## What this does not carry is what the project has no source for. The panel's
## `<ID>№/` line needs the mon's OT ID, which the save does keep; the player's
## panel additionally wants the trainer ID and PLAY TIME, which the save model
## has neither of, so those lines are absent rather than drawn as zeros.

## GetHallOfFameParty's own cap: it copies at most a full party and stops on the
## -1 terminator.
const MAX_MONS: int = 6

const PAGE_MON: StringName = &"mon"
const PAGE_PLAYER: StringName = &"player"

## `sHallOfFame`'s own thirty records and `HOF_MASTER_COUNT`, which is where
## `wHallOfFameCount` stops rather than wrapping.
const MAX_RECORDS: int = 30
const MASTER_COUNT: int = 200
## `hof_mon`'s nickname field, which is `MON_NAME_LENGTH - 1`.
const MAX_NICKNAME: int = 10


## The pages, in AnimateHallOfFame's order: every non-egg party member, then the
## player. An empty or egg-only party still answers the player's page, matching
## LoadHOFTeam's carry falling straight through to HOF_AnimatePlayerPic.
##
## [param state] is what `Rate` counts; without it, or without the rating table,
## the player's page is the bare panel the source never stops on.
static func pages(
	data: GameData, save: Gen2SaveData, state: Gen2WorldState = null
) -> Array:
	var out: Array = []
	if data == null or save == null:
		return out
	for mon: Gen2SaveMon in save.party:
		if out.size() >= MAX_MONS:
			break
		## GetHallOfFameParty skips EGG without consuming a slot, so an egg is
		## not inducted and does not shorten the list either.
		if mon.is_egg:
			continue
		out.append(_mon_page(data, mon))
	out.append_array(_player_pages(data, save, state))
	return out


## `HOF_AnimatePlayerPic`'s panel, once per box `ProfOaksPCRating` prints into
## it: both its texts run past two lines, and `PrintText` waits at each break the
## way it does anywhere else. The last box carries the sound the rating picked,
## which is where `PlayMusic MUSIC_NONE` and `PlaySFX` both sit.
static func _player_pages(
	data: GameData, save: Gen2SaveData, state: Gen2WorldState
) -> Array:
	var panel: Dictionary = {"kind": PAGE_PLAYER, "player_name": save.player_name}
	var rating: Dictionary = Gen2ProfOaksPC.rate(data, state)
	if rating.is_empty():
		return [panel]
	var boxes: Array = []
	for text: Variant in rating["pages"] as Array:
		boxes.append_array(Gen2TextLayout.lay_out(
			String(text), Gen2HallOfFamePage.TEXT_COLUMNS, Gen2HallOfFamePage.TEXT_ROWS
		))
	var out: Array = []
	for index: int in boxes.size():
		var page: Dictionary = panel.duplicate()
		page["lines"] = Array(boxes[index] as PackedStringArray)
		if index == boxes.size() - 1:
			page["sfx"] = int(rating["sfx"])
		out.append(page)
	return out


static func _mon_page(data: GameData, mon: Gen2SaveMon) -> Dictionary:
	var species_name: String = String(data.species(mon.species).get("name", ""))
	## DisplayHOFMon prints the species name from GetBasePokemonName and the
	## nickname separately, so a mon that was never renamed shows the same word
	## twice. That is the cartridge's own panel, not a bug to collapse.
	var nickname: String = mon.nickname if not mon.nickname.is_empty() else species_name
	return {
		"kind": PAGE_MON,
		"species": mon.species,
		## Gen 2 species numbers are dex numbers, which is why DisplayHOFMon
		## prints wCurPartySpecies straight into the №. field.
		"dex_number": mon.species,
		"species_name": species_name,
		"nickname": nickname,
		"level": mon.level,
		"ot_id": mon.ot_id,
		"gender": Gen2BattleMon.gender_for(data, mon.species, mon.dvs),
		## `DisplayHOFMon` draws the pic through `GetMonFrontpic`, which reads
		## `wUnownLetter`: an Unown in the Hall of Fame is its own letter, not A.
		"unown_form": Gen2Stats.unown_letter(mon.dvs) \
			if mon.species == RomLayout.UNOWN_SPECIES else 0,
	}


## `GetHallOfFameParty` and `AddHallOfFameEntry`: the party as a stored record,
## eggs skipped, in front of whatever was already kept, with the thirtieth
## falling off the end. The win count is `wHallOfFameCount` after its own
## increment, which stops at `HOF_MASTER_COUNT` rather than wrapping.
static func inducted(records: Array, save: Gen2SaveData) -> Array:
	if save == null:
		return records.duplicate(true)
	var mons: Array = []
	for mon: Gen2SaveMon in save.party:
		if mons.size() >= MAX_MONS:
			break
		if mon == null or mon.is_egg:
			continue
		mons.append({
			"species": mon.species,
			"ot_id": mon.ot_id,
			"dvs": mon.dvs,
			"level": mon.level,
			"nickname": mon.nickname.substr(0, MAX_NICKNAME),
		})
	var out: Array = records.duplicate(true)
	out.push_front({"win_count": mini(win_count(records) + 1, MASTER_COUNT), "mons": mons})
	out.resize(mini(out.size(), MAX_RECORDS))
	return out


## `wHallOfFameCount`, which the newest record carries: every induction stores
## the count it was made at.
static func win_count(records: Array) -> int:
	if records.is_empty() or not records[0] is Dictionary:
		return 0
	return int((records[0] as Dictionary).get("win_count", 0))


## One stored record as the panels `_HallOfFamePC.DisplayTeam` walks. Unlike an
## induction there is no player panel behind them: the viewer's `.b_button` is
## the only way out.
static func record_pages(data: GameData, record: Dictionary) -> Array:
	var out: Array = []
	if data == null:
		return out
	var raw_mons: Variant = record.get("mons", [])
	if not raw_mons is Array:
		return out
	for raw: Variant in raw_mons as Array:
		if not raw is Dictionary:
			continue
		var mon: Dictionary = raw
		var species: int = int(mon.get("species", 0))
		var species_name: String = String(data.species(species).get("name", ""))
		var nickname: String = String(mon.get("nickname", ""))
		var dvs: int = int(mon.get("dvs", 0))
		out.append({
			"kind": PAGE_MON,
			"species": species,
			"dex_number": species,
			"species_name": species_name,
			"nickname": nickname if not nickname.is_empty() else species_name,
			"level": int(mon.get("level", 0)),
			"ot_id": int(mon.get("ot_id", 0)),
			"gender": Gen2BattleMon.gender_for(data, species, dvs),
			"unown_form": Gen2Stats.unown_letter(dvs) \
				if species == RomLayout.UNOWN_SPECIES else 0,
			## `.print_num_hof`'s "-Time Famer", which is the one line the viewer
			## draws that an induction does not.
			"win_count": int(record.get("win_count", 0)),
		})
	return out


## The stored shape, checked rather than trusted: JSON numbers come back as
## floats and a hand-edited save can carry anything.
static func parse_records(raw: Variant) -> Array:
	var out: Array = []
	if not raw is Array:
		return out
	for raw_record: Variant in raw as Array:
		if not raw_record is Dictionary or out.size() >= MAX_RECORDS:
			continue
		var record: Dictionary = raw_record
		var mons: Array = []
		var raw_mons: Variant = record.get("mons", [])
		if raw_mons is Array:
			for raw_mon: Variant in raw_mons as Array:
				if not raw_mon is Dictionary or mons.size() >= MAX_MONS:
					continue
				var mon: Dictionary = raw_mon
				mons.append({
					"species": int(mon.get("species", 0)) & 0xFF,
					"ot_id": int(mon.get("ot_id", 0)) & 0xFFFF,
					"dvs": int(mon.get("dvs", 0)) & 0xFFFF,
					"level": clampi(int(mon.get("level", 0)), 0, Gen2Experience.MAX_LEVEL),
					"nickname": String(mon.get("nickname", "")).substr(0, MAX_NICKNAME),
				})
		out.append({
			"win_count": clampi(int(record.get("win_count", 0)), 0, MASTER_COUNT),
			"mons": mons,
		})
	return out
