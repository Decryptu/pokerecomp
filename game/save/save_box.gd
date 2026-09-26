class_name Gen2SaveBox
extends RefCounted

## One PC box: a packed list, `sBoxCount` rows from the top with the unused tail
## of [member slots] null. Its name and whether it is current are [Gen2SaveData]'s.

const CAPACITY: int = 20

var slots: Array = []
var shape_valid: bool = true


func _init() -> void:
	slots.resize(CAPACITY)
	slots.fill(null)


static func from_dict(raw: Variant) -> Gen2SaveBox:
	if not raw is Array:
		return null
	var source: Array = raw as Array
	var out := Gen2SaveBox.new()
	out.shape_valid = source.size() == CAPACITY
	var count: int = 0
	for index: int in mini(source.size(), CAPACITY):
		var raw_mon: Variant = source[index]
		if raw_mon == null:
			continue
		if not raw_mon is Dictionary:
			out.shape_valid = false
			continue
		out.slots[count] = Gen2SaveMon.from_dict(raw_mon)
		count += 1
	return out


func to_dict() -> Array:
	var out: Array = []
	for index: int in CAPACITY:
		var mon: Gen2SaveMon = slots[index] if index < slots.size() else null
		if mon == null:
			out.append(null)
			continue
		out.append(mon.to_dict())
	return out


## `sBoxCount`, or -1 when the box is full.
func first_empty_slot() -> int:
	var count: int = occupied_count()
	return count if count < CAPACITY else -1


## `InsertPokemonIntoBox` at [param slot]; -1 or past the last row appends.
func put(mon: Gen2SaveMon, slot: int = -1) -> Dictionary:
	if mon == null:
		return {"ok": false, "reason": &"missing_pokemon"}
	if slots.size() != CAPACITY:
		return {"ok": false, "reason": &"invalid_box_shape"}
	var count: int = occupied_count()
	if count >= CAPACITY:
		return {"ok": false, "reason": &"box_full"}
	var target: int = count if slot < 0 else mini(slot, count)
	slots.insert(target, mon)
	slots.resize(CAPACITY)
	return {"ok": true, "slot": target}


## `RemoveMonFromPartyOrBox`'s REMOVE_BOX: the rows behind move up one.
func take(slot: int) -> Gen2SaveMon:
	if slot < 0 or slot >= slots.size() or slots[slot] == null:
		return null
	var mon: Gen2SaveMon = slots[slot]
	slots.remove_at(slot)
	slots.append(null)
	return mon


func occupied_count() -> int:
	var count: int = 0
	for slot: Variant in slots:
		if slot != null:
			count += 1
	return count
