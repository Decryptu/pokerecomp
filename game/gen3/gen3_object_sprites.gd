class_name Gen3ObjectSprites
extends RefCounted

## OBJ palettes and field-effect culling from `event_object_movement.c`; `BuildOamBuffer`'s OAM.

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
const REFLECTION_ANIM: Array = [
	[-256, 256, -128, 0], [1, 0, 0, 4], [0, 0, 0, 8], [-1, 0, 0, 4],
	[0, 0, 0, 8], [-1, 0, 0, 4], [0, 0, 0, 8], [1, 0, 0, 4],
	[0, 0, 0, 8], [Gen3AffineAnim.JUMP, 1],
]
const SHADOW_Y_OFFSETS: Array[int] = [4, 4, 4, 16]

var data: GameData
var palette: Gen3Palette
## `UpdateSpritePaletteWithWeather` applies after reflection loads; weather sprites share the effect pool.
var weather: Gen3FieldWeather:
	set(value):
		weather = value
		if value != null:
			value.sprites.taken_slots = taken_slots
var effects: Array[Dictionary] = []
var reflection_type: int = 0
var special_tag: int = PALETTE_TAG_NONE
var reflections: Array[Dictionary] = []
var _reflection_anim := Gen3AffineAnim.new()
var _ruby: bool = false
var _order: Array[int] = []


func _init(game: GameData, palettes: Gen3Palette = null) -> void:
	data = game
	_reflection_anim.anims = [REFLECTION_ANIM]
	palette = palettes if palettes != null else Gen3Palette.new()
	_ruby = game.id in [RomRegistry.RUBY, RomRegistry.SAPPHIRE]
	for slot: int in SPRITE_COUNT:
		_order.append(slot)


## `InitObjectEventPalettes`; a link on FireRed, LeafGreen and Emerald loads six slots.
func init_palettes(type: int) -> void:
	palette.sprite_tags.clear()
	palette.reserved_sprite_count = 8 if type == 1 and not _ruby else 12
	reflection_type = type
	special_tag = PALETTE_TAG_NONE
	var sets: Array = data.world_object_palette_sets().get("tag_sets", [])
	var tags: Array = sets[type] if type < sets.size() else []
	for slot: int in mini(tags.size(), LINK_PALETTE_SLOTS if type == 1 and not _ruby else PALETTE_SLOTS):
		patch(int(tags[slot]), slot)


func patch(tag: int, slot: int) -> void:
	palette.load(data.world_object_palette(tag), Gen3Palette.OBJ_OFFSET + slot * 16)


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
	return subpriority_at(object.pixel_position.y + 16 - origin.y, elevation, add)


static func subpriority_at(bottom: int, elevation: int, add: int) -> int:
	var row: int = ((bottom + 8) & 0xFF) >> 4
	return (ELEVATION_SUBPRIORITY[elevation] + ((16 - row) << 1) + add) & 0xFF


## Objects, reflections and field effects sorted together, front first; `tiles` is 4bpp in 1D order.
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
	for effect: Dictionary in effects:
		var entry: Dictionary = {}
		if effect.get("grass", false) or effect.get("map_effect", false):
			entry = _map_effect_entry(objects, effect)
		elif int(effect["request"]["effect_id"]) in objects.icon_effects():
			entry = _icon_entry(objects, effect, origin)
		if not entry.is_empty():
			entries[int(effect["sprite_slot"])] = entry
	for reflection: Dictionary in reflections:
		var entry: Dictionary = _reflection_entry(objects, reflection, origin)
		entries[int(reflection["sprite_slot"])] = entry
	if weather != null:
		entries.merge(weather.sprites.oam_entries(weather.contrast_slot, weather.picture_slot))
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


## The first free sprite slot past the objects', from the end as `CreateSpriteAtEnd` looks or from the start.
func effect_slot(reverse: bool = true) -> int:
	# `CreateReflectionEffectSprites` reserves the final two sprites for the shared distortion matrices.
	var slots: Array = range(SPRITE_COUNT - 3, Gen3ObjectEvents.COUNT - 1, -1) if reverse \
		else range(Gen3ObjectEvents.COUNT, SPRITE_COUNT - 2)
	var taken: Array = taken_slots()
	if weather != null:
		taken.append_array(weather.sprites.slots())
	for slot: int in slots:
		if not slot in taken:
			return slot
	return -1


func taken_slots() -> Array:
	var out: Array = range(Gen3ObjectEvents.COUNT)
	for row: Dictionary in effects + reflections:
		out.append(int(row.get("sprite_slot", -1)))
	return out


## `SetUpReflection` keeps the object slot/local ID and the initial bridge offset, not its map identity.
func start_reflection(objects: Gen3ObjectEvents, object: Gen3ObjectEvents.ObjectEvent, slot: int,
		still: bool) -> void:
	var sprite_slot: int = effect_slot(false)
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
	if weather != null:
		weather.update_sprite_palette(slot)


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
	_reflection_anim.animate()


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
		var matrix: Vector4i = _reflection_anim.matrix()
		if object.anim.h_flip:
			matrix.x = -matrix.x
		part["matrix"] = matrix
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


func load_effect_palette(info: Dictionary) -> int:
	var tag: int = int(info.get("palette_tag", 0xFFFF))
	if tag == 0xFFFF:
		return int(info.get("palette", 0))
	var slot: int = palette.sprite_index(tag)
	if slot == 0xFF:
		slot = palette.alloc_sprite(tag)
		if slot != 0xFF:
			palette.load(info.get("palette_bytes", PackedByteArray()), Gen3Palette.OBJ_OFFSET + slot * 16)
	if slot != 0xFF and weather != null:
		weather.update_sprite_palette(slot)
	return int(info["palette"]) if data.id == RomRegistry.EMERALD and info.has("palette") else slot & 0xF


func free_effect_palette(effect: Dictionary) -> void:
	var slot: int = int(effect.get("palette", 0))
	if effects.any(func(other: Dictionary) -> bool: return int(other.get("palette", 0)) == slot):
		return
	if weather != null:
		for sprite: Gen3WeatherSprites.WeatherSprite in weather.sprites.all_sprites():
			if slot == (weather.picture_slot if sprite.second_palette else weather.contrast_slot):
				return
	palette.sprite_tags.erase(slot)


func _map_effect_entry(objects: Gen3ObjectEvents, effect: Dictionary) -> Dictionary:
	var anim: Gen3SpriteAnim = effect["anim"]
	if anim.tiles.is_empty():
		return {}
	var info: Dictionary = effect["info"]
	var size := Vector2i(int(info["width"]), int(info["height"]))
	var center: Vector2i = effect["position"] + objects.camera.sprite_coord_offset()
	var at: Vector2i = center - size / 2
	var sub: int = int(effect.get("subpriority", 0))
	var priority: int = int(effect["priority"])
	return {"y": at.y & 0xFF, "key": (priority << 8) | sub,
		"invisible": effect.get("invisible", false),
		"part": {"x": at.x & 0x1FF, "y": at.y & 0xFF, "flip": Vector2i(int(anim.h_flip), int(anim.v_flip)),
			"priority": priority, "palette": int(effect["palette"]), "size": size,
			"tiles": data.world_sprite_image(int(anim.tiles[0]), int(anim.tiles[1]))}}


static func _field_effect_off_screen(top_left: Vector2i, size: Vector2i) -> bool:
	var x: int = wrapi(top_left.x, -32768, 32768)
	var y: int = wrapi(top_left.y, -32768, 32768)
	var x2: int = wrapi(x + size.x / 4, -32768, 32768)
	var y2: int = wrapi(y + size.y / 4, -32768, 32768)
	return x >= 256 or x2 < -16 or y >= 176 or y2 < -16


func update_field_effect(objects: Gen3ObjectEvents, effect: Dictionary) -> void:
	if int(effect["request"]["effect_id"]) in [15, Gen3ObjectEvents.FLDEFF_FEET_IN_FLOWING_WATER, Gen3ObjectEvents.FLDEFF_SAND_PILE, Gen3ObjectEvents.FLDEFF_HOT_SPRINGS_WATER]:
		_update_linked_effect(objects, effect)
	var anim: Gen3SpriteAnim = effect["anim"]
	var info: Dictionary = effect["info"]
	var size := Vector2i(int(info["width"]), int(info["height"]))
	var center: Vector2i = effect["position"] + objects.camera.sprite_coord_offset()
	var linked_hidden: bool = int(effect["request"]["effect_id"]) == 41 and effect.get("invisible", false)
	effect["invisible"] = linked_hidden or _field_effect_off_screen(center - size / 2, size)
	if not effect.has("elevation") or int(effect["request"]["effect_id"]) == 41:
		return
	var add: int = 4 if int(effect["request"]["effect_id"]) == 4 and anim.cmd_index == 0 else 0
	var sub: int = subpriority_at(center.y + size.y / 2, int(effect["elevation"]), add)
	if int(effect["request"]["effect_id"]) in [4, 17]:
		sub = _grass_subpriority(objects, effect["position"], size, sub)
	effect["subpriority"] = sub


## `UpdateSandPileFieldEffect` restarts on pos1 changes; `UpdateHotSpringsWaterFieldEffect` draws one subpriority ahead.
func _update_linked_effect(objects: Gen3ObjectEvents, effect: Dictionary) -> void:
	var request: Dictionary = effect["request"]
	var object: Gen3ObjectEvents.ObjectEvent = objects.by_identity(int(request["local_id"]),
		int(request["map_number"]), int(request["map_group"]))
	var height: int = int(objects.graphics_info(object.graphics_id).get("height", 0))
	var offset: int = (height >> 1) - 8 if int(request["effect_id"]) == Gen3ObjectEvents.FLDEFF_HOT_SPRINGS_WATER else int(effect["y_offset"])
	var position: Vector2i = object.pixel_position + Vector2i(8, 16 - (height >> 1) + offset) \
		- objects.camera.screen_origin() - objects.camera.sprite_coord_offset()
	effect["position"] = Vector2i(wrapi(position.x, -32768, 32768), wrapi(position.y, -32768, 32768))
	if int(request["effect_id"]) == Gen3ObjectEvents.FLDEFF_SAND_PILE and effect["last_position"] != effect["position"]:
		effect["last_position"] = effect["position"]
		if (effect["anim"] as Gen3SpriteAnim).ended:
			(effect["anim"] as Gen3SpriteAnim).start(0)
	if int(request["effect_id"]) != 15:
		effect["subpriority"] = (object.subpriority - int(int(request["effect_id"]) == Gen3ObjectEvents.FLDEFF_HOT_SPRINGS_WATER)) & 0xFF


## `UpdateGrassFieldEffectSubpriority` raises grass behind the first overlapping object's feet.
func _grass_subpriority(objects: Gen3ObjectEvents, center: Vector2i, size: Vector2i, sub: int) -> int:
	for object: Gen3ObjectEvents.ObjectEvent in objects.objects:
		if not object.active:
			continue
		var height: int = int(objects.graphics_info(object.graphics_id).get("height", 0))
		var linked: Vector2i = object.pixel_position + Vector2i(8, 16 - height / 2) \
			- objects.camera.screen_origin() - objects.camera.sprite_coord_offset()
		linked = Vector2i(wrapi(linked.x, -32768, 32768), wrapi(linked.y, -32768, 32768))
		var ylo: int = wrapi(center.y + size.y / 2, -32768, 32768)
		var yhi: int = wrapi(ylo - height / 2, -32768, 32768)
		var top: int = wrapi(linked.y - height / 2, -32768, 32768)
		if wrapi(center.x - size.x / 2, -32768, 32768) < linked.x \
				and wrapi(center.x + size.x / 2, -32768, 32768) > linked.x \
				and (top < yhi or top < ylo) \
				and linked.y > yhi and sub <= object.subpriority:
			return (object.subpriority + 2) & 0xFF
	return sub


func _icon_entry(objects: Gen3ObjectEvents, effect: Dictionary, origin: Vector2i) -> Dictionary:
	var request: Dictionary = effect["request"]
	var object: Gen3ObjectEvents.ObjectEvent = objects.by_identity(int(request["local_id"]),
		int(request["map_number"]), int(request["map_group"]))
	var info: Dictionary = data.world_icon_graphics(int(request["effect_id"]))
	var anim: Gen3SpriteAnim = effect["anim"]
	if object == null or info.is_empty() or anim.tiles.is_empty():
		return {}
	var height: int = int(objects.graphics_info(object.graphics_id).get("height", 0))
	var center: Vector2i = object.pixel_position + Vector2i(8, -(height >> 1)) + Vector2i(object.x2,
		object.jump_y + int(effect["y_offset"])) - origin
	var at: Vector2i = center - Vector2i(8, 8)
	return {"y": at.y & 0xFF, "key": (1 << 8) | (0x53 if request["effect_id"] == 0 else 0x52),
		"part": {"x": at.x & 0x1FF, "y": at.y & 0xFF, "flip": Vector2i(int(anim.h_flip), int(anim.v_flip)),
			"priority": 1, "palette": int(effect["palette"]), "size": Vector2i(16, 16),
			"tiles": data.world_sprite_image(int(anim.tiles[0]), int(anim.tiles[1]))}}


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
	if object.anim.affine:
		whole["matrix"] = object.affine.matrix()
		whole["double_size"] = true
		var dims: Vector2i = whole["size"]
		whole["x"] = (int(whole["x"]) - dims.x / 2) & 0x1FF
		whole["y"] = (int(whole["y"]) - dims.y / 2) & 0xFF
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
