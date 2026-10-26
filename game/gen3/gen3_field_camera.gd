class_name Gen3FieldCamera
extends RefCounted

## `fieldmap.c`'s camera: the player's map and grid, `gSaveBlock1Ptr->pos` (the focus in layout coordinates,
## which is the view's top-left in backup ones), `CameraMove`'s walk across a connection and the saved map
## view it carries over. The focus is [member pos] plus [constant Gen3MapGrid.MAP_OFFSET].

const VIEW_WIDTH: int = Gen3MapGrid.OFFSET_W
const VIEW_HEIGHT: int = Gen3MapGrid.OFFSET_H
const PAN_Y: int = 32
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
## `gCamera`: whether the last [method move] crossed into another map, and the old [member pos] less the one
## the new map gave before the step was added.
var crossed: bool = false
var shift := Vector2i.ZERO
## `mapView`: the 15x14 words [method save_view] copied, empty once cleared.
var view := PackedInt32Array()
var scroll := Vector2i.ZERO
## `gFieldCamera.x`/`y`: signed remainders, distinct from the screen offset.
var movement_offset := Vector2i.ZERO
## `gTotalCameraPixelOffsetX`/`Y` (u16): `InitObjectEventsLocal` zeroes it at a warp and each `CameraUpdate`
## takes its pixel step off it, so it runs on across connections.
var pixel_offset := Vector2i.ZERO


## The backup-map pixel at the screen's top-left: the BG and sprite offsets add 8 to [constant PAN_Y], `InstallCameraPanAheadCallback`'s pan.
func screen_origin() -> Vector2i:
	return pos * 16 + scroll + Vector2i(0, PAN_Y + 8)


## `UpdateCameraPanning`'s `gSpriteCoordOffsetX`/`Y`, which every sprite with `coordOffsetEnabled` adds.
func sprite_coord_offset() -> Vector2i:
	return Vector2i(_s16(pixel_offset.x), _s16(pixel_offset.y - PAN_Y - 8))


## `SetSpritePosToMapCoords`: backup-map [param cell]'s screen corner, less [method sprite_coord_offset].
func sprite_position(cell: Vector2i) -> Vector2i:
	var delta: Vector2i = -pixel_offset - movement_offset + Vector2i(signi(movement_offset.x), signi(movement_offset.y)) * 16
	return Vector2i(_s16(((cell.x - pos.x) << 4) + _s16(delta.x)), _s16(((cell.y - pos.y) << 4) + _s16(delta.y)))


static func _s16(value: int) -> int:
	return ((value & 0xFFFF) ^ 0x8000) - 0x8000


static func open(game: GameData, map_group: int, map_number: int, at: Vector2i) -> Gen3FieldCamera:
	var camera := Gen3FieldCamera.new()
	camera.data = game
	camera.pos = at
	return camera if camera.load_map(map_group, map_number) else null


## `InitMap`'s grid. The grid before it stays the previous one, which Emerald reads connection flags from.
func load_map(map_group: int, map_number: int) -> bool:
	var next: Gen3MapGrid = Gen3MapGrid.open(data, map_group, map_number, grid)
	if next == null:
		return false
	grid = next
	group = map_group
	number = map_number
	header = data.world_map_header(map_group, map_number)
	return true


## `CameraMove`. Stepping onto a connected map's cells loads that map, puts [member pos] where the step lands
## in it and lays the saved view over the new grid. False when the step stays on this map, or is refused.
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


## `CameraUpdate`, after its callback supplies the tracked sprite's pixel displacement. The vertical
## reversal writes deltaX in all three engines. Return the cell step for the host's object update.
func update(speed: Vector2i) -> Vector2i:
	var step := Vector2i.ZERO
	if speed.x != 0 and (movement_offset.x == 0 or movement_offset.x == -speed.x):
		step.x = signi(speed.x)
	if speed.y != 0 and movement_offset.y == 0:
		step.y = signi(speed.y)
	if movement_offset.y != 0 and movement_offset.y == -speed.y:
		step.x = signi(speed.y)
	movement_offset = Vector2i((movement_offset.x + speed.x) % 16, (movement_offset.y + speed.y) % 16)
	if step != Vector2i.ZERO:
		move(step)
	scroll += speed - step * 16
	pixel_offset = Vector2i((pixel_offset.x - speed.x) & 0xFFFF, (pixel_offset.y - speed.y) & 0xFFFF)
	return step


## `GetIncomingConnection`. Every straight step off the layout finds one; a diagonal step off a corner can
## name a side whose connection does not span the old position, and the cartridge then reads a connection from
## address 0, the BIOS. [method move] refuses that step, keeping [member pos].
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


## `MoveMapViewToBackup`: the saved view less the row or column the step left behind, written over the new
## grid where it now lies, then cleared. Rows run on through the flat buffer. A diagonal step can carry them
## past its end, into `sBackupMapData`'s unused tail, or one word before its start; neither word is part of
## the map, so neither is kept.
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


func can_move(direction: int) -> bool:
	var at: Vector2i = pos + Vector2i.ONE * Gen3MapGrid.MAP_OFFSET + DIRECTIONS[direction]
	return grid.border_id_at(at.x, at.y) != Gen3MapGrid.Connection.INVALID


## `GetMapConnectionAtPos` for a backup-map cell: the connection whose map holds it, empty for one inside the
## layout, a dive or emerge connection or no map.
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
