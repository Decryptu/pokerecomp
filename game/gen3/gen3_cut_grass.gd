class_name Gen3CutGrass
extends RefCounted

## fldeff_cut.c: `SetUpFieldMove_Cut` ([method set_up]), `FldEff_CutGrass` ([method start]) and its blades.

const FLDEFF_USE_CUT_ON_GRASS: int = 1
const FLDEFF_USE_CUT_ON_TREE: int = 2
const FLDEFF_CUT_GRASS: int = 58
const ABILITY_HYPER_CUTTER: int = 52
const VAR_LAST_TALKED: int = 0x800F
const BLADES: int = 8
const SPIN_FRAMES: int = 28
const BLADE_SIZE: Vector2i = Vector2i(8, 8)
## `OBJ_EVENT_GFX_CUTTABLE_TREE`, FRLG's `OBJ_EVENT_GFX_CUT_TREE`.
const HOENN_TREE: int = 82
const FRLG_TREE: int = 95
const MB_TALL_GRASS: int = 2
const MB_LONG_GRASS: int = 3
const MB_LONG_GRASS_SOUTH_EDGE: int = 9
const MB_ASHGRASS: int = 0x24
const TERRAIN_GRASS: int = 1
const GENERAL_GRASS: int = 0x001
const GENERAL_LONG_GRASS: int = 0x015
## `SetCutGrassMetatile`'s switch, which ignores the tileset; FRLG's is `sCutGrassMetatileMapping`.
const HOENN_MOWED: Dictionary = {0x208: 0x001, 0x015: 0x001, 0x00D: 0x001, 0x1C6: 0x1CE, 0x1C7: 0x1CF,
	0x281: 0x279, 0x282: 0x27A, 0x283: 0x27B, 0x206: 0x271, 0x207: 0x271, 0x212: 0x218, 0x20A: 0x218, 0x025: 0x00E}
const FRLG_MOWED: Dictionary = {0x00D: 0x001, 0x00A: 0x013, 0x00B: 0x00E, 0x00C: 0x00F, 0x352: 0x33E,
	0x300: 0x310, 0x301: 0x311, 0x302: 0x312, 0x284: 0x281}
## `GetLongGrassCaseAt`'s tops (the field, then the Fortree secret base's left, middle and right) and their roots.
const LONG_GRASS_ROOTS: Dictionary = {0x001: 0x208, 0x279: 0x281, 0x27A: 0x282, 0x27B: 0x283}
## `sHyperCutStruct`: the offset and the 1-based normal-square cell that must be passable.
const HYPER_CUT: Array = [[-2, -2, 1], [-1, -2, 1], [0, -2, 2], [1, -2, 3], [2, -2, 3], [-2, -1, 1], [2, -1, 3],
	[-2, 0, 4], [2, 0, 6], [-2, 1, 7], [2, 1, 9], [-2, 2, 7], [-1, 2, 7], [0, 2, 8], [1, 2, 9], [2, 2, 9]]
## `CutMoveRuinValleyCheck` and `CutMoveOpenDottedHoleDoor`, in backup-map cells.
const RUIN_VALLEY: Vector2i = Vector2i(3, 61)
const RUIN_VALLEY_CELL: Vector2i = Vector2i(31, 32)
const DOTTED_HOLE_CELL: Vector2i = Vector2i(31, 31)
const DOTTED_HOLE_OPEN: int = 0x358
const FLAG_USED_CUT_ON_RUIN_VALLEY_BRAILLE: int = 0x2E3
const FARAWAY_ISLAND_INTERIOR: Vector2i = Vector2i(26, 57)
const FLAG_CAUGHT_MEW: int = 0x1CA
const FLAG_HIDE_MEW: int = 0x2CE

var blades: Array[Dictionary] = []
var active: bool = false

var _objects: Gen3ObjectEvents
var _game: StringName
## `sCutSquareSide`, the `sTileCountFromPlayer` reach and Emerald's `sHyperCutTiles`.
var _side: int = 3
var _tiles := PackedByteArray()
## `gPlayerFacingPosition.elevation`, which `CheckObjectGraphicsInFrontOfPlayer` sets.
var _elevation: int = 0
var _open_dotted_hole: bool = false
var _player: Gen3ObjectEvents.ObjectEvent


func _init(objects: Gen3ObjectEvents) -> void:
	_objects = objects
	_game = objects.camera.data.id
	_tiles.resize(25)


func _frlg() -> bool:
	return _game in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN]


## The effect to start, or -1; Emerald records the cells to mow, two deep with [param ability] Hyper Cutter.
func set_up(player: Gen3ObjectEvents.ObjectEvent, ability: int = 0) -> int:
	_open_dotted_hole = false
	if _frlg() and _ruin_valley_braille(player):
		_open_dotted_hole = true
		return FLDEFF_USE_CUT_ON_GRASS
	if _tree_in_front(player):
		return FLDEFF_USE_CUT_ON_TREE
	if _frlg():
		for cell: Vector2i in _square(player.current, 1):
			if _at_level(cell) and _terrain_grass(cell):
				return FLDEFF_USE_CUT_ON_GRASS
		return -1
	if _game != RomRegistry.EMERALD:
		for cell: Vector2i in _square(player.current, 1):
			if _at_level(cell) and _poke_or_ash_grass(cell):
				return FLDEFF_USE_CUT_ON_GRASS
		return -1
	return FLDEFF_USE_CUT_ON_GRASS if _set_up_emerald(player.current, ability == ABILITY_HYPER_CUTTER) else -1


## `CheckObjectGraphicsInFrontOfPlayer`; with no object there the cartridge reads past `gObjectEvents`.
func _tree_in_front(player: Gen3ObjectEvents.ObjectEvent) -> bool:
	var at: Vector2i = player.current + Gen3FieldCamera.DIRECTIONS[player.facing]
	_elevation = player.previous_elevation
	var slot: int = _objects.at_position(at, _elevation)
	if slot < 0 or _objects.objects[slot].graphics_id != (FRLG_TREE if _frlg() else HOENN_TREE):
		return false
	_objects.events.var_set(VAR_LAST_TALKED, _objects.objects[slot].local_id)
	return true


func _ruin_valley_braille(player: Gen3ObjectEvents.ObjectEvent) -> bool:
	return not _objects.events.flag_get(FLAG_USED_CUT_ON_RUIN_VALLEY_BRAILLE) \
		and Vector2i(_objects.camera.group, _objects.camera.number) == RUIN_VALLEY \
		and player.current == RUIN_VALLEY_CELL and player.facing == 2


## The hyper ring reaches past `cutTiles`' passable cells; collision 1 alone blocks (pret's BUGFIX: 1 to 3).
func _set_up_emerald(center: Vector2i, hyper: bool) -> bool:
	_side = 5 if hyper else 3
	_tiles.fill(0)
	var passable := PackedByteArray()
	var found: bool = false
	for cell: int in 9:
		var at: Vector2i = center + Vector2i(cell % 3 - 1, cell / 3 - 1)
		var tile: int = 6 + (cell / 3) * 5 + cell % 3
		passable.append(0)
		if not _at_level(at):
			continue
		if _poke_or_ash_grass(at):
			_tiles[tile] = 1
			found = true
		if _grid().collision_at(at.x, at.y) != 1:
			passable[cell] = 1
			if _cuttable_grass(at):
				_tiles[tile] = 1
	if not hyper:
		return found
	for row: Array in HYPER_CUT:
		var at: Vector2i = center + Vector2i(int(row[0]), int(row[1]))
		if passable[int(row[2]) - 1] == 0 or not _at_level(at):
			continue
		if _poke_or_ash_grass(at):
			found = true
			_tiles[int(row[1]) * 5 + 12 + int(row[0])] = 1
		elif _cuttable_grass(at):
			_tiles[int(row[1]) * 5 + 12 + int(row[0])] = 1
	return found


## `FieldMoveCallback_CutGrass` and `FldEff_CutGrass` after `loadfadedpal`; Ruby re-reads the behaviors.
func start(player: Gen3ObjectEvents.ObjectEvent) -> Array:
	_player = player
	if _open_dotted_hole:
		_grid().set_metatile_id(DOTTED_HOLE_CELL.x, DOTTED_HOLE_CELL.y, DOTTED_HOLE_OPEN)
		_objects.events.flag_set(FLAG_USED_CUT_ON_RUIN_VALLEY_BRAILLE)
		_objects.events.controls_locked = false
		return [{"kind": "sound", "name": "bang"}]
	var info: Dictionary = _objects.camera.data.world_cut_grass_graphics()
	var palette: int = _objects.sprites.load_effect_palette(info)
	if _frlg():
		for cell: Vector2i in _square(player.current, 1):
			if _at_level(cell) and _terrain_grass(cell):
				_mow(cell, FRLG_MOWED)
	elif _game == RomRegistry.EMERALD:
		for tile: int in 25:
			if _tiles[tile] == 1:
				_mow(player.current + Vector2i(tile % 5 - 2, tile / 5 - 2), HOENN_MOWED)
	else:
		_side = 3
		for cell: Vector2i in _square(player.current, 1):
			if _at_level(cell) and _cuttable_grass(cell):
				_mow(cell, HOENN_MOWED)
	if not _frlg():
		var reach: int = _side / 2
		_fix_long_grass(player.current - Vector2i(reach, reach + 1))
	_start_blades(info, palette)
	return [{"kind": "sound", "name": "m_cut"}]


func _mow(at: Vector2i, mowed: Dictionary) -> void:
	var id: int = _grid().metatile_id_at(at.x, at.y)
	if mowed.has(id):
		_grid().set_metatile_id(at.x, at.y, mowed[id])
	var slot: int = _objects.at_position(at)
	if slot >= 0:
		_objects.objects[slot].trigger_ground_effects = true


## `SetCutGrassMetatiles` and `HandleLongGrassOnHyper`, from the square's top-left minus a row.
func _fix_long_grass(corner: Vector2i) -> void:
	for column: int in _side:
		var x: int = corner.x + column
		if _id(x, corner.y) == GENERAL_LONG_GRASS:
			_root(x, corner.y + 1)
		if _id(x, corner.y + _side) == GENERAL_GRASS:
			_unroot(x, corner.y + _side + 1)
	if _side == 5:
		for edge: int in 2:
			_fix_hyper_edge(corner, edge)


func _fix_hyper_edge(corner: Vector2i, edge: int) -> void:
	var x: int = corner.x + edge * 4
	var first: int = 5 + edge * 4
	if _tiles[first] == 1:
		_unroot(x, corner.y + 3)
	if _tiles[first + 5] == 1:
		if _id(x, corner.y + 2) == GENERAL_LONG_GRASS:
			_root(x, corner.y + 3)
		_unroot(x, corner.y + 4)
	if _tiles[first + 10] == 1 and _id(x, corner.y + 3) == GENERAL_LONG_GRASS:
		_root(x, corner.y + 4)


func _root(x: int, y: int) -> void:
	var id: int = _id(x, y)
	if LONG_GRASS_ROOTS.has(id):
		_grid().set_metatile_id(x, y, LONG_GRASS_ROOTS[id])


func _unroot(x: int, y: int) -> void:
	var id: int = _id(x, y)
	for top: int in LONG_GRASS_ROOTS:
		if LONG_GRASS_ROOTS[top] == id:
			_grid().set_metatile_id(x, y, top)


## Created at the player's last OAM corner plus (8, 20), screen-fixed, `data[2]` 32 apart.
func _start_blades(info: Dictionary, palette: int) -> void:
	var images: Array = info.get("images", [])
	var tiles: PackedByteArray = PackedByteArray() if images.is_empty() \
		else _objects.camera.data.world_sprite_image(int(images[0][0]), int(images[0][1]))
	var corner: Vector2i = Gen3ObjectSprites.corner(_player, _objects.graphics_info(_player.graphics_id),
		_objects.camera.screen_origin())
	var origin := Vector2i((corner.x & 0x1FF) + 8, (corner.y & 0xFF) + 20)
	for blade: int in BLADES:
		var sprite: Dictionary = {"sprite_slot": _objects.sprites.effect_slot(false), "position": origin,
			"origin": origin, "size": BLADE_SIZE, "priority": 1, "subpriority": 0, "palette": palette & 0xF,
			"tiles": tiles, "radius": 0, "frame": 0, "angle": blade * 32, "speed": 0, "started": false}
		blades.append(sprite)
		_objects.sprites.pics.append(sprite)
	active = true


## `CutGrassSpriteCallback1`, then `CutGrassSpriteCallback2` until `data[1]` reaches 28, then the end callback.
func animate() -> Array:
	if not active:
		return []
	var first: Dictionary = blades[0]
	if first["started"] and int(first["frame"]) > SPIN_FRAMES:
		return _end()
	for blade: Dictionary in blades:
		if not blade["started"]:
			blade.merge({"radius": 8, "frame": 0, "speed": 0, "started": true}, true)
			continue
		var angle: int = int(blade["angle"])
		var radius: int = int(blade["radius"])
		var offset := Vector2i(radius * Gen3ObjectEvents.SINE[angle] >> 8, radius * Gen3ObjectEvents.SINE[angle + 64] >> 8)
		blade["position"] = blade["origin"] + offset
		blade["angle"] = (angle + 8) & 0xFF
		blade["radius"] = radius + 1 + (int(blade["speed"]) >> 2)
		blade["speed"] = int(blade["speed"]) + 1
		blade["frame"] = int(blade["frame"]) + 1
	return []


## `CutGrassSpriteCallbackEnd`, then Emerald's `IsMewPlayingHideAndSeek` script.
func _end() -> Array:
	for blade: Dictionary in blades:
		_objects.sprites.pics.erase(blade)
	_objects.sprites.free_effect_palette({"palette": blades[0]["palette"]})
	blades.clear()
	active = false
	Gen3ObjectEvents.clear_held_movement_if_finished(_player)
	_objects.unfreeze_all()
	_objects.events.controls_locked = false
	var events: Gen3EventData = _objects.events
	var map := Vector2i(_objects.camera.group, _objects.camera.number)
	if _game != RomRegistry.EMERALD or map != FARAWAY_ISLAND_INTERIOR or events.flag_get(FLAG_CAUGHT_MEW) \
			or events.flag_get(FLAG_HIDE_MEW):
		return []
	return [{"kind": "script", "offset": _objects.camera.data.world_native_script_offset("hide_mew_when_grass_cut")}]


func _grid() -> Gen3MapGrid:
	return _objects.camera.grid


func _id(x: int, y: int) -> int:
	return _grid().metatile_id_at(x, y)


func _at_level(at: Vector2i) -> bool:
	return _grid().elevation_at(at.x, at.y) == _elevation


func _terrain_grass(at: Vector2i) -> bool:
	return _grid().terrain_at(at.x, at.y) == TERRAIN_GRASS


func _poke_or_ash_grass(at: Vector2i) -> bool:
	return _grid().behavior_at(at.x, at.y) & 0xFF in [MB_TALL_GRASS, MB_LONG_GRASS, MB_ASHGRASS]


func _cuttable_grass(at: Vector2i) -> bool:
	return _grid().behavior_at(at.x, at.y) & 0xFF in [MB_TALL_GRASS, MB_LONG_GRASS, MB_ASHGRASS, MB_LONG_GRASS_SOUTH_EDGE]


static func _square(center: Vector2i, reach: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y: int in range(-reach, reach + 1):
		for x: int in range(-reach, reach + 1):
			out.append(center + Vector2i(x, y))
	return out
