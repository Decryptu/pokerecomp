class_name Gen3ObjectSprites
extends RefCounted

## The object events' OBJ palettes (`event_object_movement.c`) and the OAM `BuildOamBuffer` makes of them.

const PALETTE_SLOTS: int = 10
const LINK_PALETTE_SLOTS: int = 6
const PALSLOT_PLAYER: int = 0
const PALSLOT_NPC_SPECIAL: int = 10
const PALETTE_TAG_NONE: int = 0x11FF
const REFLECTION_TYPES: int = 4
## The reflection types `InitObjectEventPalettes` is called with, 1 in a link.
const USED_REFLECTION_TYPES: Array[int] = [0, 1]
## `gReflectionEffectPaletteMap`.
const REFLECTION_SLOTS: Array[int] = [1, 1, 6, 7, 8, 9, 6, 7, 8, 9, 11, 11, 0, 0, 0, 0]
const SUBSPRITE_TABLES: int = 6
const SUBSPRITE_LIMIT: int = 32
## `sOamDimensions` by shape, then size.
const OAM_SIZES: Array = [
	[Vector2i(8, 8), Vector2i(16, 16), Vector2i(32, 32), Vector2i(64, 64)],
	[Vector2i(16, 8), Vector2i(32, 8), Vector2i(32, 16), Vector2i(64, 32)],
	[Vector2i(8, 16), Vector2i(8, 32), Vector2i(16, 32), Vector2i(32, 64)],
	[Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0)],
]
enum Subsprites { OFF, ON, IGNORE_PRIORITY }
## `sElevationToPriority`, `sElevationToSubpriority` and `sElevationToSubspriteTableNum`.
const ELEVATION_PRIORITY: Array[int] = [2, 2, 2, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 0, 0, 2]
const ELEVATION_SUBPRIORITY: Array[int] = [115, 115, 83, 115, 83, 115, 83, 115, 83, 115, 83, 115, 83, 0, 0, 115]
const ELEVATION_SUBSPRITE_TABLE: Array[int] = [1, 1, 1, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 0, 0, 1]
const LONG_GRASS_TABLE: int = 4
const LONG_GRASS_TABLE_HIGH: int = 5
const DISPLAY_HEIGHT: int = 160

var data: GameData
var palettes := PackedByteArray()
var reflection_type: int = 0
var special_tag: int = PALETTE_TAG_NONE
var _ruby: bool = false
## `sSpriteOrder` over object slots, kept between frames.
var _order: Array[int] = []


func _init(game: GameData) -> void:
	data = game
	palettes.resize(16 * 32)
	_ruby = game.id in [RomRegistry.RUBY, RomRegistry.SAPPHIRE]
	for slot: int in Gen3ObjectEvents.COUNT:
		_order.append(slot)


## `InitObjectEventPalettes`; a link on FireRed, LeafGreen and Emerald loads six slots.
func init_palettes(type: int) -> void:
	reflection_type = type
	special_tag = PALETTE_TAG_NONE
	var sets: Array = data.world_object_palette_sets().get("tag_sets", [])
	var tags: Array = sets[type] if type < sets.size() else []
	for slot: int in mini(tags.size(), LINK_PALETTE_SLOTS if type == 1 and not _ruby else PALETTE_SLOTS):
		patch(int(tags[slot]), slot)


func patch(tag: int, slot: int) -> void:
	var colors: PackedByteArray = data.world_object_palette(tag)
	for index: int in colors.size():
		palettes[slot * 32 + index] = colors[index]


## `TrySetupObjectEventSprite` ([param spawn]) and `ObjectEventSetGraphicsId`'s palette loads.
func load_palette(info: Dictionary, spawn: bool) -> void:
	var slot: int = int(info.get("palette_slot", -1))
	var tag: int = int(info.get("palette_tag", PALETTE_TAG_NONE))
	if slot == PALSLOT_PLAYER:
		patch(tag, slot)
		if spawn:
			_patch_reflection("player_reflections", tag, slot)
	elif slot == PALSLOT_NPC_SPECIAL:
		special_tag = tag
		patch(tag, slot)
		_patch_reflection("special_reflections", tag, slot)


func _patch_reflection(sets: String, tag: int, slot: int) -> void:
	var tags: Array = data.world_object_palette_sets().get(sets, {}).get(str(tag), [])
	if not tags.is_empty():
		patch(int(tags[reflection_type]), REFLECTION_SLOTS[slot])


## `UpdateOamCoords` against the screen at backup pixel [param origin].
static func corner(object: Gen3ObjectEvents.ObjectEvent, info: Dictionary, origin: Vector2i) -> Vector2i:
	var center := Vector2i(-(int(info.get("width", 0)) >> 1), -(int(info.get("height", 0)) >> 1))
	return object.pixel_position + Vector2i(8, 16 + center.y) + Vector2i(object.x2, object.jump_y) + center - origin


## `SetObjectSubpriorityByElevation` against the screen at backup pixel [param origin].
static func subpriority(object: Gen3ObjectEvents.ObjectEvent, elevation: int, origin: Vector2i, add: int) -> int:
	var row: int = ((object.pixel_position.y + 16 - origin.y + 8) & 0xFF) >> 4
	return (ELEVATION_SUBPRIORITY[elevation] + ((16 - row) << 1) + add) & 0xFF


## The objects' OAM front first, `tiles` 4bpp in 1D order; sprites other than objects are not sorted in.
func oam(objects: Gen3ObjectEvents, origin: Vector2i) -> Array:
	var entries: Dictionary = {}
	for slot: int in Gen3ObjectEvents.COUNT:
		var object: Gen3ObjectEvents.ObjectEvent = objects.objects[slot]
		if object.active and objects.graphics_info(object.graphics_id).has("oam"):
			entries[slot] = _entry(objects, object, origin)
	_sort(entries)
	var out: Array = []
	for slot: int in _order:
		if entries.has(slot) and not objects.objects[slot].sprite_invisible:
			out.append_array(_parts(objects.objects[slot], entries[slot]))
	return out


func _entry(objects: Gen3ObjectEvents, object: Gen3ObjectEvents.ObjectEvent, origin: Vector2i) -> Dictionary:
	var info: Dictionary = objects.graphics_info(object.graphics_id)
	var at: Vector2i = corner(object, info, origin)
	var tiles: PackedByteArray = PackedByteArray() if object.anim.tiles.is_empty() \
		else data.world_sprite_image(int(object.anim.tiles[0]), int(object.anim.tiles[1]))
	return {"x": at.x & 0x1FF, "y": at.y & 0xFF, "info": info, "tiles": tiles,
		"center": Vector2i(-(int(info["width"]) >> 1), -(int(info["height"]) >> 1)),
		"key": (object.priority << 8) | object.subpriority}


## `SortSprites`: lower key first, then the greater y (past the screen negative); ties keep last frame's order.
func _sort(entries: Dictionary) -> void:
	var places: Array[int] = []
	var slots: Array[int] = []
	for index: int in _order.size():
		if entries.has(_order[index]):
			places.append(index)
			slots.append(_order[index])
	for index: int in range(1, slots.size()):
		var at: int = index
		while at > 0 and _ahead(entries[slots[at]], entries[slots[at - 1]]):
			var swap: int = slots[at]
			slots[at] = slots[at - 1]
			slots[at - 1] = swap
			at -= 1
	for index: int in places.size():
		_order[places[index]] = slots[index]


static func _ahead(entry: Dictionary, before: Dictionary) -> bool:
	var y: int = int(entry["y"]) - (256 if int(entry["y"]) >= DISPLAY_HEIGHT else 0)
	var y_before: int = int(before["y"]) - (256 if int(before["y"]) >= DISPLAY_HEIGHT else 0)
	return int(before["key"]) > int(entry["key"]) or (int(before["key"]) == int(entry["key"]) and y_before < y)


## `AddSpriteToOamBuffer` and `AddSubspritesToOamBuffer`.
func _parts(object: Gen3ObjectEvents.ObjectEvent, entry: Dictionary) -> Array:
	var info: Dictionary = entry["info"]
	var flip := Vector2i(int(object.anim.h_flip), int(object.anim.v_flip))
	var whole: Dictionary = {"x": entry["x"], "y": entry["y"], "flip": flip, "priority": object.priority,
		"palette": object.palette_num, "tiles": entry["tiles"],
		"size": OAM_SIZES[int(info["oam"]["shape"])][int(info["oam"]["size"])]}
	var tables: Array = info["subsprite_tables"]
	if object.subsprite_mode == Subsprites.OFF or tables.is_empty() or tables[object.subsprite_table].is_empty():
		return [whole]
	var base := Vector2i(int(entry["x"]) - int(entry["center"].x), int(entry["y"]) - int(entry["center"].y))
	var out: Array = []
	for part: Dictionary in tables[object.subsprite_table]:
		var size: Vector2i = OAM_SIZES[int(part["shape"])][int(part["size"])]
		var offset := Vector2i(int(part["x"]), int(part["y"]))
		if flip.x:
			offset.x = -(offset.x + size.x)
		if flip.y:
			offset.y = -(offset.y + size.y)
		var piece: Dictionary = whole.duplicate()
		piece["x"] = (base.x + offset.x) & 0x1FF
		piece["y"] = (base.y + offset.y) & 0xFF
		piece["size"] = size
		piece["tiles"] = (entry["tiles"] as PackedByteArray).slice(int(part["tile_offset"]) * GbaTiles.TILE_BYTES)
		if object.subsprite_mode != Subsprites.IGNORE_PRIORITY:
			piece["priority"] = int(part["priority"])
		out.append(piece)
	return out
