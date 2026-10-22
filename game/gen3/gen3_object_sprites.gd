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
const SPRITE_COUNT: int = 64
const SHADOW_SIZES: Array[Vector2i] = [Vector2i(8, 8), Vector2i(16, 8), Vector2i(32, 8), Vector2i(64, 32)]
## `sAffineAnim_ReflectionDistortion_0`: relative X deltas, four/eight frames each.
const REFLECTION_DELTAS: Array[int] = [1, 0, -1, 0, -1, 0, 1, 0]
const SHADOW_Y_OFFSETS: Array[int] = [4, 4, 4, 16]

var data: GameData
var palettes := PackedByteArray()
var reflection_type: int = 0
var special_tag: int = PALETTE_TAG_NONE
var reflections: Array[Dictionary] = []
var _reflection_frame: int = 0
var _reflection_scale: int = -256
var _ruby: bool = false
var _order: Array[int] = []


func _init(game: GameData) -> void:
	data = game
	palettes.resize(16 * 32)
	_ruby = game.id in [RomRegistry.RUBY, RomRegistry.SAPPHIRE]
	for slot: int in SPRITE_COUNT:
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


## Objects, reflections and shadows sorted together, front first; `tiles` is 4bpp in 1D order.
func oam(objects: Gen3ObjectEvents, origin: Vector2i) -> Array:
	var entries: Dictionary = {}
	for slot: int in Gen3ObjectEvents.COUNT:
		var object: Gen3ObjectEvents.ObjectEvent = objects.objects[slot]
		if object.active and objects.graphics_info(object.graphics_id).has("oam"):
			entries[slot] = _entry(objects, object, origin)
	for shadow: Dictionary in objects.shadow_sprites():
		var entry: Dictionary = _shadow_entry(objects, shadow, origin)
		if not entry.is_empty():
			entries[int(shadow["sprite_slot"])] = entry
	for reflection: Dictionary in reflections:
		var entry: Dictionary = _reflection_entry(objects, reflection, origin)
		entries[int(reflection["sprite_slot"])] = entry
	_sort(entries)
	var out: Array = []
	for slot: int in _order:
		if not entries.has(slot):
			continue
		if slot >= Gen3ObjectEvents.COUNT:
			if not entries[slot].get("invisible", false):
				out.append(entries[slot]["part"])
		elif not objects.objects[slot].sprite_invisible:
			out.append_array(_parts(objects.objects[slot], entries[slot]))
	return out


static func effect_slot(effects: Array[Dictionary], reverse: bool = true) -> int:
	# `CreateReflectionEffectSprites` reserves the final two sprites for the shared distortion matrices.
	var slots: Array = range(SPRITE_COUNT - 3, Gen3ObjectEvents.COUNT - 1, -1) if reverse \
		else range(Gen3ObjectEvents.COUNT, SPRITE_COUNT - 2)
	for slot: int in slots:
		if not effects.any(func(effect: Dictionary) -> bool: return effect.get("sprite_slot", -1) == slot):
			return slot
	return -1


## `SetUpReflection` keeps the object slot/local ID and the initial bridge offset, not its map identity.
func start_reflection(objects: Gen3ObjectEvents, object: Gen3ObjectEvents.ObjectEvent, slot: int,
		still: bool, effects: Array[Dictionary]) -> void:
	var sprite_slot: int = effect_slot(effects + reflections, false)
	if sprite_slot < 0:
		return
	var info: Dictionary = objects.graphics_info(object.graphics_id)
	var bridge: int = 0
	if not info.get("disable_reflection_palette_load", false):
		bridge = _bridge_type(object.previous_behavior)
		if bridge == 0:
			bridge = _bridge_type(object.current_behavior)
	reflections.append({"object_slot": slot, "local_id": object.local_id, "sprite_slot": sprite_slot,
		"still": still, "offset": 0 if bridge == 0 else 12 + (bridge - 1) * 16})
	_load_reflection_palette(info, REFLECTION_SLOTS[object.palette_num], bridge != 0)


func _bridge_type(behavior: int) -> int:
	if data.id in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN]:
		return 0
	if behavior >= 0x70 and behavior <= 0x73:
		return behavior - 0x70
	if not _ruby:
		if behavior in [0x7A, 0x7B]:
			return 2
		if behavior in [0x7C, 0x7D]:
			return 3
	return 0


func _load_reflection_palette(info: Dictionary, slot: int, bridge: bool) -> void:
	var tag: int = int(info.get("reflection_palette_tag", PALETTE_TAG_NONE))
	if tag == PALETTE_TAG_NONE:
		return
	var main_slot: int = int(info.get("palette_slot", -1))
	if bridge:
		patch(tag, slot)
	elif main_slot in [PALSLOT_PLAYER, PALSLOT_NPC_SPECIAL]:
		patch(int(info["palette_tag"]), slot)
		if main_slot == PALSLOT_NPC_SPECIAL:
			special_tag = int(info["palette_tag"])
		_patch_reflection("player_reflections" if main_slot == PALSLOT_PLAYER else "special_reflections",
			int(info["palette_tag"]), slot)
	else:
		patch(palette_tag(slot), slot)


## `GetObjectPaletteTag` uses the last special object's tag for every slot above the regular bank.
func palette_tag(slot: int) -> int:
	var sets: Dictionary = data.world_object_palette_sets()
	if slot < PALETTE_SLOTS:
		return int(sets["tag_sets"][reflection_type][slot])
	var tags: Array = sets.get("special_reflections", {}).get(str(special_tag), [])
	return int(tags[reflection_type]) if not tags.is_empty() else PALETTE_TAG_NONE


## `UpdateObjectReflectionSprite` and the two invisible distortion sprites' affine clocks.
func step_reflections(objects: Gen3ObjectEvents) -> void:
	for index: int in range(reflections.size() - 1, -1, -1):
		var reflection: Dictionary = reflections[index]
		var object: Gen3ObjectEvents.ObjectEvent = objects.objects[int(reflection["object_slot"])]
		if not object.active or not object.has_reflection or object.local_id != int(reflection["local_id"]):
			reflections.remove_at(index)
	if _reflection_frame > 0:
		var phase: int = (_reflection_frame - 1) % 48
		var command: int = phase / 12 * 2 + int(phase % 12 >= 4)
		_reflection_scale += REFLECTION_DELTAS[command]
	_reflection_frame += 1


func _reflection_entry(objects: Gen3ObjectEvents, reflection: Dictionary, origin: Vector2i) -> Dictionary:
	var object: Gen3ObjectEvents.ObjectEvent = objects.objects[int(reflection["object_slot"])]
	var entry: Dictionary = _entry(objects, object, origin)
	var info: Dictionary = entry["info"]
	var y: int = (int(entry["y"]) + int(info["height"]) - 2 + int(reflection["offset"]) - 2 * object.jump_y) & 0xFF
	var part: Dictionary = {"x": entry["x"], "y": y, "priority": 3,
		"palette": REFLECTION_SLOTS[object.palette_num], "tiles": entry["tiles"],
		"size": OAM_SIZES[int(info["oam"]["shape"])][int(info["oam"]["size"])],
		"flip": Vector2i(int(object.anim.h_flip), 1)}
	if not reflection["still"]:
		var a: int = -(65536 / _reflection_scale)
		part["matrix"] = Vector4i(-a if object.anim.h_flip else a, 0, 0, -256)
	return {"y": y, "key": (3 << 8) | 152, "part": part,
		"invisible": object.sprite_invisible or object.hide_reflection}


func _shadow_entry(objects: Gen3ObjectEvents, shadow: Dictionary, origin: Vector2i) -> Dictionary:
	var request: Dictionary = shadow["request"]
	var object: Gen3ObjectEvents.ObjectEvent = objects.by_identity(int(request["local_id"]),
		int(request["map_number"]), int(request["map_group"]))
	var info: Dictionary = data.world_shadow_graphics(int(shadow["shadow_size"]))
	if object == null or info.is_empty():
		return {}
	var size := Vector2i(int(info["width"]), int(info["height"]))
	var height: int = int(objects.graphics_info(object.graphics_id).get("height", 0))
	var center: Vector2i = object.pixel_position + Vector2i(8, 16 - (height >> 1) + int(shadow["y_offset"])) - origin
	var at: Vector2i = center - size / 2
	var frame: Array = info["images"][0]
	return {"y": at.y & 0xFF, "key": (object.priority << 8) | 148,
		"part": {"x": at.x & 0x1FF, "y": at.y & 0xFF, "flip": Vector2i.ZERO, "priority": object.priority,
			"palette": 0, "size": size, "tiles": data.world_sprite_image(int(frame[0]), int(frame[1]))}}


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
