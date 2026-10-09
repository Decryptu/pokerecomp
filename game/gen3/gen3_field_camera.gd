class_name Gen3FieldCamera
extends RefCounted

## `fieldmap.c`'s camera: the player's map and grid, `gSaveBlock1Ptr->pos` (the
## focus in layout coordinates, which is the view's top-left in backup ones),
## `CameraMove`'s walk across a connection and the saved map view it carries
## over. The focus is [member pos] plus [constant Gen3MapGrid.MAP_OFFSET].

const VIEW_WIDTH: int = Gen3MapGrid.OFFSET_W
const VIEW_HEIGHT: int = Gen3MapGrid.OFFSET_H
## `gDirectionToVectors`, by `DIR_*`.
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1),
]

var data: GameData
var group: int = -1
var number: int = -1
var header: Dictionary = {}
var grid: Gen3MapGrid
var pos := Vector2i.ZERO
## `gCamera`: whether the last [method move] crossed into another map, and the
## old [member pos] less the one the new map gave before the step was added.
var crossed: bool = false
var shift := Vector2i.ZERO
## `mapView`: the 15x14 words [method save_view] copied, empty once cleared.
var view := PackedInt32Array()


static func open(game: GameData, map_group: int, map_number: int, at: Vector2i) -> Gen3FieldCamera:
	var camera := Gen3FieldCamera.new()
	camera.data = game
	camera.pos = at
	return camera if camera.load_map(map_group, map_number) else null


## `InitMap`'s grid. The grid before it stays the previous one, which Emerald
## reads connection flags from.
func load_map(map_group: int, map_number: int) -> bool:
	var next: Gen3MapGrid = Gen3MapGrid.open(data, map_group, map_number, grid)
	if next == null:
		return false
	grid = next
	group = map_group
	number = map_number
	header = data.world_map_header(map_group, map_number)
	return true


## `CameraMove`. Stepping onto a connected map's cells loads that map, puts
## [member pos] where the step lands in it and lays the saved view over the new
## grid. False when the step stays on this map, or is refused.
func move(step: Vector2i) -> bool:
	crossed = false
	var direction: int = grid.border_id_at(pos.x + Gen3MapGrid.MAP_OFFSET + step.x,
		pos.y + Gen3MapGrid.MAP_OFFSET + step.y)
	if direction <= Gen3MapGrid.Connection.NONE:
		pos += step
		return false
	var connection: Dictionary = _incoming(direction)
	if connection.is_empty():
		return false
	save_view()
	var old: Vector2i = pos
	_position_from(connection, direction, step)
	load_map(int(connection["group"]), int(connection["number"]))
	crossed = true
	shift = old - pos
	pos += step
	_view_to_backup(direction)
	return true


## `GetIncomingConnection`. Every straight step off the layout finds one; a
## diagonal step off a corner can name a side whose connection does not span
## the old position, and the cartridge then reads a connection from address 0,
## the BIOS. [method move] refuses that step, keeping [member pos].
func _incoming(direction: int) -> Dictionary:
	var vertical: bool = direction == Gen3MapGrid.Connection.SOUTH or direction == Gen3MapGrid.Connection.NORTH
	var coord: int = pos.x if vertical else pos.y
	var size: int = int(header["width" if vertical else "height"])
	for connection: Dictionary in header.get("connections", []):
		if int(connection["direction"]) != direction:
			continue
		var other: Dictionary = data.world_map_header(int(connection["group"]), int(connection["number"]))
		var offset: int = int(connection["offset"])
		# IsCoordInIncomingConnectingMap: the far end is inclusive.
		if coord >= maxi(offset, 0) and coord <= mini(int(other["width" if vertical else "height"]) + offset, size):
			return connection
	return {}


## `SetPositionFromConnection`.
func _position_from(connection: Dictionary, direction: int, step: Vector2i) -> void:
	var other: Dictionary = data.world_map_header(int(connection["group"]), int(connection["number"]))
	var offset: int = int(connection["offset"])
	match direction:
		Gen3MapGrid.Connection.EAST:
			pos = Vector2i(-step.x, pos.y - offset)
		Gen3MapGrid.Connection.WEST:
			pos = Vector2i(int(other["width"]), pos.y - offset)
		Gen3MapGrid.Connection.SOUTH:
			pos = Vector2i(pos.x - offset, -step.y)
		Gen3MapGrid.Connection.NORTH:
			pos = Vector2i(pos.x - offset, int(other["height"]))


## `SaveMapView`: the view's rows, read straight through the backup words.
func save_view() -> void:
	view.resize(VIEW_WIDTH * VIEW_HEIGHT)
	for y: int in VIEW_HEIGHT:
		for x: int in VIEW_WIDTH:
			view[x + y * VIEW_WIDTH] = grid.blocks[grid.width * (pos.y + y) + pos.x + x]


## `MoveMapViewToBackup`: the saved view less the row or column the step
## left behind, written over the new grid where it now lies, then cleared.
## Rows run on through the flat buffer. A diagonal step can carry them past
## its end, into `sBackupMapData`'s unused tail, or one word before its
## start; neither word is part of the map, so neither is kept.
func _view_to_backup(direction: int) -> void:
	var to: Vector2i = pos
	var from := Vector2i.ZERO
	var size := Vector2i(VIEW_WIDTH, VIEW_HEIGHT)
	match direction:
		Gen3MapGrid.Connection.NORTH:
			to.y += 1
			size.y -= 1
		Gen3MapGrid.Connection.SOUTH:
			from.y = 1
			size.y -= 1
		Gen3MapGrid.Connection.WEST:
			to.x += 1
			size.x -= 1
		Gen3MapGrid.Connection.EAST:
			from.x = 1
			size.x -= 1
	for y: int in size.y:
		for x: int in size.x:
			var at: int = x + to.x + grid.width * (y + to.y)
			if at >= 0 and at < grid.blocks.size():
				grid.blocks[at] = view[from.x + x + VIEW_WIDTH * (from.y + y)]
	view.clear()


## `CanCameraMoveInDirection`.
func can_move(direction: int) -> bool:
	var at: Vector2i = pos + Vector2i.ONE * Gen3MapGrid.MAP_OFFSET + DIRECTIONS[direction]
	return grid.border_id_at(at.x, at.y) != Gen3MapGrid.Connection.INVALID


## `GetMapConnectionAtPos` for a backup-map cell: the connection whose map
## holds it, empty for one inside the layout, a dive or emerge connection or
## no map.
func connection_at(x: int, y: int) -> Dictionary:
	var layout_width: int = int(header["width"])
	var layout_height: int = int(header["height"])
	for connection: Dictionary in header.get("connections", []):
		var direction: int = int(connection["direction"])
		var past: bool = false
		match direction:
			Gen3MapGrid.Connection.NORTH:
				past = y < Gen3MapGrid.MAP_OFFSET
			Gen3MapGrid.Connection.SOUTH:
				past = y >= layout_height + Gen3MapGrid.MAP_OFFSET
			Gen3MapGrid.Connection.WEST:
				past = x < Gen3MapGrid.MAP_OFFSET
			Gen3MapGrid.Connection.EAST:
				past = x >= layout_width + Gen3MapGrid.MAP_OFFSET
		if past and _holds(connection, x - Gen3MapGrid.MAP_OFFSET, y - Gen3MapGrid.MAP_OFFSET):
			return connection
	return {}


## `IsPosInConnectingMap`.
func _holds(connection: Dictionary, x: int, y: int) -> bool:
	var other: Dictionary = data.world_map_header(int(connection["group"]), int(connection["number"]))
	var offset: int = int(connection["offset"])
	if int(connection["direction"]) <= Gen3MapGrid.Connection.NORTH:
		return x - offset >= 0 and x - offset < int(other["width"])
	return y - offset >= 0 and y - offset < int(other["height"])
