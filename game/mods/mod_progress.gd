class_name Gen2ModProgress
extends RefCounted

## What a run has achieved, as one flat read-only dictionary.
##
## A mod is deliberately given no world and no save: [method Gen2ModHost.progress]
## and [method Gen2ModHost.progress_for] hand it this instead, the way
## [method Gen2ModHost.inventory] hands it the bag. Every field is a state the
## run has REACHED rather than a moment it passed, so a mod installed onto a save
## already played reads what that save has and a mod watching
## [signal Gen2ModHost.progress_changed] sees the same field move.
##
## Cartridge differences are resolved here. `badges` is a Crystal-ordered mask
## whichever profile is open, so a mod never touches
## [method Gen2WorldState.badge_flag] or the Gold and Silver flag table.
##
## A field this cannot answer is LEFT OUT rather than zeroed, so a mod written
## against a later build reads a missing answer as nothing achieved rather than
## as an achievement lost.

## The live run: [param world] for everything the world owns and [param save] for
## the party, the boxes and the play timer, which are the save's.
##
## Either may be null and the fields that one answers are then absent rather than
## zero. A reading with neither is `{}`.
static func of(world: Gen2WorldAPI, save: Gen2SaveData) -> Dictionary:
	var out: Dictionary = {}
	if world != null and world.state != null:
		_read_state(out, world.state, Gen2WorldState.is_crystal_profile(world.data))
		out[&"beat_red"] = world.spawn_after_champion == Gen2WorldSnapshot.SPAWN_AFTER_RED
	_read_save(out, save)
	return out


## The same off a save with no world open, which is what a `save_activated`
## callback has: the slot has been chosen and the world has not been built yet.
static func of_save(save: Gen2SaveData, data: GameData = null) -> Dictionary:
	var out: Dictionary = {}
	if save != null and save.world != null and save.world.world_state != null:
		_read_state(out, save.world.world_state, Gen2WorldState.is_crystal_profile(data))
		out[&"beat_red"] = \
			save.world.spawn_after_champion == Gen2WorldSnapshot.SPAWN_AFTER_RED
	_read_save(out, save)
	return out


## Whether two readings differ in any field either of them carries. What decides
## whether [signal Gen2ModHost.progress_changed] is emitted, so a field appearing
## or disappearing counts as a move exactly as a field changing value does.
static func differs(left: Dictionary, right: Dictionary) -> bool:
	if left.size() != right.size():
		return true
	for key: Variant in left:
		if not right.has(key) or right[key] != left[key]:
			return true
	return false


static func _read_state(out: Dictionary, state: Gen2WorldState, crystal: bool) -> void:
	out[&"badges"] = state.badge_mask(crystal)
	out[&"badge_count"] = state.badge_count(crystal)
	out[&"hall_of_fame"] = state.hall_of_fame()
	out[&"seen_count"] = state.seen_count()
	out[&"caught_count"] = state.caught_count()
	out[&"unown_caught"] = state.unown_caught_count()
	out[&"money"] = state.money()
	out[&"coins"] = state.coins()
	out[&"step_count"] = state.step_count()
	out[&"phone_contacts"] = state.phone_contact_count()


## The party, the boxes and the play timer, which are the save's on both paths:
## the world screen plays the slot's own party rather than a copy, so the live
## run and a slot the launcher has only opened are read the same way.
static func _read_save(out: Dictionary, save: Gen2SaveData) -> void:
	if save == null:
		return
	if save.game_time != null:
		out[&"play_hours"] = save.game_time.hours
		out[&"play_minutes"] = save.game_time.minutes
	var party: Array = []
	party.append_array(save.party)
	## `ContestDropOffMons` moves the masked members off the party rather than
	## leaving them behind `wPartyCount`, so a contest must not read as a run
	## that released five Pokemon.
	party.append_array(save.contest_stashed_party)
	var highest: int = 0
	var shiny: int = 0
	var kept: int = 0
	for row: Variant in party:
		var mon: Gen2SaveMon = row as Gen2SaveMon
		if mon == null or mon.species <= 0:
			continue
		kept += 1
		highest = maxi(highest, mon.level)
		if Gen2Stats.is_shiny(mon.dvs):
			shiny += 1
	out[&"party_count"] = kept
	for raw: Variant in save.boxes:
		var box: Gen2SaveBox = raw as Gen2SaveBox
		if box == null:
			continue
		for slot: Variant in box.slots:
			var mon: Gen2SaveMon = slot as Gen2SaveMon
			if mon == null or mon.species <= 0:
				continue
			kept += 1
			highest = maxi(highest, mon.level)
			if Gen2Stats.is_shiny(mon.dvs):
				shiny += 1
	out[&"kept_count"] = kept
	out[&"highest_level"] = highest
	out[&"shiny_count"] = shiny
