class_name Gen3Warp
extends RefCounted

var destination: Dictionary = {}
var location: Dictionary = {}
var last: Dictionary = {}
var dynamic: Dictionary = {}
var dive: Dictionary = {}
var hole: Dictionary = {}
var escape: Dictionary = {}


static func record(group: int, number: int, id: int, x: int = -1, y: int = -1) -> Dictionary:
	return {"group": _s8(group), "number": _s8(number), "warp_id": _s8(id), "x": _s8(x), "y": _s8(y)}


static func _s8(value: int) -> int: # overworld.c::SetWarpData takes signed bytes, including script coordinates.
	return ((value & 0xFF) ^ 0x80) - 0x80


func from_event(data: GameData, group: int, number: int, id: int, at: Vector2i) -> bool: # field_control_avatar.c::SetupWarp and overworld.c::UpdateEscapeWarp.
	var rows: Array = data.world_map_events(group, number).get("warps", [])
	if id < 0 or id >= rows.size():
		return false
	var row: Dictionary = rows[id]
	if int(row["number"]) == 0x7F:
		destination = dynamic.duplicate()
		return not destination.is_empty()
	destination = record(int(row["group"]), int(row["number"]), int(row["warp_id"]))
	var target: Dictionary = data.world_map_header(int(row["group"]), int(row["number"]))
	var source: Dictionary = data.world_map_header(group, number)
	if int(source.get("map_type", 0)) in [1, 2, 3, 5, 6] and int(target.get("map_type", 0)) not in [1, 2, 3, 5, 6]:
		escape = record(group, number, -1, at.x, at.y + 1)
	var exits: Array = target.get("events", {}).get("warps", [])
	var target_id: int = int(row["warp_id"])
	if target_id >= 0 and target_id < exits.size() and int(exits[target_id]["number"]) == 0x7F:
		dynamic = record(group, number, id, at.x, at.y)
	return not target.is_empty()


func position(data: GameData) -> Vector2i: # overworld.c::SetPlayerCoordsFromWarp prefers a valid warp id to coordinates.
	var group: int = int(destination["group"])
	var number: int = int(destination["number"])
	var rows: Array = data.world_map_events(group, number).get("warps", [])
	var id: int = int(destination["warp_id"])
	if id >= 0 and id < rows.size():
		return Vector2i(int(rows[id]["x"]), int(rows[id]["y"]))
	if int(destination["x"]) >= 0 and int(destination["y"]) >= 0:
		return Vector2i(int(destination["x"]), int(destination["y"]))
	var header: Dictionary = data.world_map_header(group, number)
	return Vector2i(int(header["width"]) / 2, int(header["height"]) / 2)


func fall_destination(at: Vector2i) -> Dictionary: # overworld.c::SetWarpDestinationToFixedHoleWarp.
	if hole.is_empty() or hole == record(-1, -1, -1):
		return last.duplicate()
	return record(int(hole["group"]), int(hole["number"]), -1, at.x, at.y)


func commit() -> void:
	last = location.duplicate()
	location = destination.duplicate()
