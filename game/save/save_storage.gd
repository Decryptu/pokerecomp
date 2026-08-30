class_name Gen2SaveStorage
extends RefCounted

## Atomic party and PC-box transactions for a validated project save. Each edits
## a deep candidate, validates it, writes it through the save store and only then
## updates the shared save, so a failed write leaves both copies untouched.


static func deposit_party_to_box(
	save: Gen2SaveData,
	data: GameData,
	party_index: int,
	box_index: int = -1,
	box_slot: int = -1,
	persist: bool = true,
) -> Dictionary:
	var candidate_result: Dictionary = _candidate(save, data)
	if not bool(candidate_result.get("ok", false)):
		return candidate_result
	var candidate: Gen2SaveData = candidate_result["save"]
	if party_index < 0 or party_index >= candidate.party.size():
		return _failure(&"invalid_party_index")
	if candidate.party.size() <= 1:
		return _failure(&"last_party_member")
	var mon: Gen2SaveMon = candidate.party[party_index]
	if mon == null:
		return _failure(&"missing_pokemon")
	var destination: Dictionary = _box_destination(candidate, box_index, box_slot)
	if not bool(destination.get("ok", false)):
		return destination
	var box: Gen2SaveBox = candidate.boxes[int(destination["box"])]
	var placed: Dictionary = box.put(mon, int(destination["slot"]))
	if not bool(placed.get("ok", false)):
		return _failure(StringName(placed.get("reason", &"box_insert_failed")))
	candidate.party.remove_at(party_index)
	return _commit(save, data, candidate, {
		"kind": &"party_to_box",
		"party_index": party_index,
		"box": int(destination["box"]),
		"slot": int(destination["slot"]),
	}, persist)


static func withdraw_box_to_party(
	save: Gen2SaveData,
	data: GameData,
	box_index: int,
	box_slot: int,
	persist: bool = true,
) -> Dictionary:
	var candidate_result: Dictionary = _candidate(save, data)
	if not bool(candidate_result.get("ok", false)):
		return candidate_result
	var candidate: Gen2SaveData = candidate_result["save"]
	if box_index < 0 or box_index >= candidate.boxes.size():
		return _failure(&"invalid_box_index")
	if box_slot < 0 or box_slot >= Gen2SaveBox.CAPACITY:
		return _failure(&"invalid_box_slot")
	if candidate.party.size() >= Gen2SaveData.MAX_PARTY:
		return _failure(&"party_full")
	var box: Gen2SaveBox = candidate.boxes[box_index]
	if box == null or box_slot >= box.slots.size():
		return _failure(&"invalid_box_shape")
	var mon: Gen2SaveMon = box.slots[box_slot]
	if mon == null:
		return _failure(&"empty_box_slot")
	box.slots[box_slot] = null
	candidate.party.append(mon)
	return _commit(save, data, candidate, {
		"kind": &"box_to_party",
		"party_index": candidate.party.size() - 1,
		"box": box_index,
		"slot": box_slot,
	}, persist)


## `RemoveMonFromPartyOrBox` behind both `.release`s: the same atomic write the
## transfers make, with nothing on the other end. `BillsPC_IsMonAnEgg` and
## `BillsPC_CheckMail_PreventBlackout` are the caller's, printed before the
## yes/no.
static func release_party_member(
	save: Gen2SaveData, data: GameData, party_index: int, persist: bool = true
) -> Dictionary:
	var candidate_result: Dictionary = _candidate(save, data)
	if not bool(candidate_result.get("ok", false)):
		return candidate_result
	var candidate: Gen2SaveData = candidate_result["save"]
	if party_index < 0 or party_index >= candidate.party.size():
		return _failure(&"invalid_party_index")
	if candidate.party.size() <= 1:
		return _failure(&"last_party_member")
	candidate.party.remove_at(party_index)
	return _commit(save, data, candidate, {
		"kind": &"release_party", "party_index": party_index,
	}, persist)


static func release_box_slot(
	save: Gen2SaveData, data: GameData, box_index: int, box_slot: int,
	persist: bool = true
) -> Dictionary:
	var candidate_result: Dictionary = _candidate(save, data)
	if not bool(candidate_result.get("ok", false)):
		return candidate_result
	var candidate: Gen2SaveData = candidate_result["save"]
	if box_index < 0 or box_index >= candidate.boxes.size():
		return _failure(&"invalid_box_index")
	if box_slot < 0 or box_slot >= Gen2SaveBox.CAPACITY:
		return _failure(&"invalid_box_slot")
	var box: Gen2SaveBox = candidate.boxes[box_index]
	if box == null or box_slot >= box.slots.size():
		return _failure(&"invalid_box_shape")
	if box.slots[box_slot] == null:
		return _failure(&"empty_box_slot")
	box.slots[box_slot] = null
	return _commit(save, data, candidate, {
		"kind": &"release_box", "box": box_index, "slot": box_slot,
	}, persist)


## `MovePKMNWithoutMail_InsertMon`'s four branches in one: the mon leaves
## [param from_index] of one list and is inserted at [param to_index] of the
## other. A list is the party at `Gen2BoxScreen.LOADED_PARTY` and the box before
## it otherwise, `wBillsPC_LoadedBox`'s own numbering.
## `BillsPC_CheckSpaceInDestination` is the one refusal, and only across lists.
static func move_mon(
	save: Gen2SaveData,
	data: GameData,
	from_loaded: int,
	from_index: int,
	to_loaded: int,
	to_index: int,
	persist: bool = true,
) -> Dictionary:
	var candidate_result: Dictionary = _candidate(save, data)
	if not bool(candidate_result.get("ok", false)):
		return candidate_result
	var candidate: Gen2SaveData = candidate_result["save"]
	var source: Array = _loaded_list(candidate, from_loaded)
	if source.is_empty() and from_index != 0:
		return _failure(&"invalid_loaded_list")
	if from_index < 0 or from_index >= source.size():
		return _failure(&"invalid_source_slot")
	var mon: Gen2SaveMon = source[from_index]
	if mon == null:
		return _failure(&"missing_pokemon")
	if from_loaded == to_loaded:
		var reordered: Array = source.duplicate()
		reordered.remove_at(from_index)
		## `.CheckTrivialMove`: the row pointed at has already shifted up by the
		## one that left, so the insert row loses one when it came from above.
		var at: int = to_index - 1 if to_index > from_index else to_index
		reordered.insert(clampi(at, 0, reordered.size()), mon)
		_write_loaded_list(candidate, from_loaded, reordered)
	else:
		var destination: Array = _loaded_list(candidate, to_loaded)
		var capacity: int = Gen2SaveData.MAX_PARTY 			if to_loaded == Gen2BoxScreen.LOADED_PARTY else Gen2SaveBox.CAPACITY
		if destination.size() >= capacity:
			return _failure(&"no_room_in_destination")
		if from_loaded == Gen2BoxScreen.LOADED_PARTY and source.size() <= 1:
			return _failure(&"last_party_member")
		var without: Array = source.duplicate()
		without.remove_at(from_index)
		destination = destination.duplicate()
		destination.insert(clampi(to_index, 0, destination.size()), mon)
		_write_loaded_list(candidate, from_loaded, without)
		_write_loaded_list(candidate, to_loaded, destination)
	return _commit(save, data, candidate, {
		"kind": &"move_mon",
		"from_loaded": from_loaded, "from_index": from_index,
		"to_loaded": to_loaded, "to_index": to_index,
	}, persist)


## One `wBillsPC_LoadedBox` list as the packed array the source treats it as:
## the party is already one and a box's own occupied slots are read in order.
static func _loaded_list(save: Gen2SaveData, loaded: int) -> Array:
	if loaded == Gen2BoxScreen.LOADED_PARTY:
		return save.party
	var box: Gen2SaveBox = save.boxes[loaded - 1] 		if loaded - 1 >= 0 and loaded - 1 < save.boxes.size() else null
	if box == null:
		return []
	var out: Array = []
	for slot: int in Gen2SaveBox.CAPACITY:
		if slot < box.slots.size() and box.slots[slot] != null:
			out.append(box.slots[slot])
	return out


static func _write_loaded_list(save: Gen2SaveData, loaded: int, members: Array) -> void:
	if loaded == Gen2BoxScreen.LOADED_PARTY:
		save.party = members.duplicate()
		return
	var box: Gen2SaveBox = save.boxes[loaded - 1] 		if loaded - 1 >= 0 and loaded - 1 < save.boxes.size() else null
	if box == null:
		return
	box.slots.fill(null)
	for slot: int in mini(members.size(), Gen2SaveBox.CAPACITY):
		box.slots[slot] = members[slot]


static func _candidate(save: Gen2SaveData, data: GameData) -> Dictionary:
	if save == null or data == null:
		return _failure(&"missing_save_context")
	var candidate: Gen2SaveData = Gen2SaveData.from_dict(save.to_dict())
	if candidate == null:
		return _failure(&"invalid_save_shape")
	var validation: Dictionary = Gen2SaveValidator.validate(save, data)
	if not bool(validation.get("ok", false)):
		return {
			"ok": false,
			"reason": &"invalid_save",
			"message": validation.get("message", "save validation failed"),
		}
	return {"ok": true, "save": candidate}


static func _box_destination(
	save: Gen2SaveData, box_index: int, box_slot: int
) -> Dictionary:
	if box_index < 0:
		return save.deposit_box_slot()
	if box_index >= save.boxes.size():
		return _failure(&"invalid_box_index")
	var box: Gen2SaveBox = save.boxes[box_index]
	if box == null:
		return _failure(&"invalid_box_shape")
	var target_slot: int = box_slot if box_slot >= 0 else box.first_empty_slot()
	if target_slot < 0:
		return _failure(&"box_full")
	if target_slot >= Gen2SaveBox.CAPACITY:
		return _failure(&"invalid_box_slot")
	if target_slot >= box.slots.size():
		return _failure(&"invalid_box_shape")
	if box.slots[target_slot] != null:
		return _failure(&"box_slot_occupied")
	return {"ok": true, "box": box_index, "slot": target_slot}


static func _commit(
	source: Gen2SaveData,
	data: GameData,
	candidate: Gen2SaveData,
	transaction: Dictionary,
	persist: bool = true,
) -> Dictionary:
	if persist:
		var write: Dictionary = Gen2SaveStore.save(candidate, data)
		if not bool(write.get("ok", false)):
			return {
				"ok": false,
				"reason": &"save_failed",
				"message": write.get("message", "save failed"),
			}
	source.copy_from(candidate)
	var result: Dictionary = {"ok": true, "message": ""}
	result["persisted"] = persist
	for key: Variant in transaction:
		result[key] = transaction[key]
	return result


static func _failure(reason: StringName) -> Dictionary:
	return {"ok": false, "reason": reason, "message": String(reason)}
