class_name Gen3World
extends RefCounted

const HEADER_SIZE: int = 28
const WILD_HEADER_SIZE: int = 20
const WILD_METHODS: Array[String] = ["land", "water", "rock_smash", "fishing"]
## pret's ChooseWildMonIndex_*; fishing weights sum to 100 within each rod.
const SLOT_CHANCES: Array = [
	[20, 20, 10, 10, 10, 10, 5, 5, 4, 4, 1, 1],
	[60, 30, 5, 4, 1], [60, 30, 5, 4, 1],
	[70, 30, 60, 20, 20, 40, 40, 15, 4, 1],
]
const RODS: Dictionary = {"old_rod": [0, 2], "good_rod": [2, 5], "super_rod": [5, 10]}
const RUBY_STEP_POSITIONS: Array = [1, 3, 0, 2]
const STEP_ANIMS_LIMIT: int = 16


static func verify(rom: RomFile, layout: Dictionary) -> Dictionary:
	if read(rom, layout).is_empty():
		return {"ok": false, "message": "Map layouts, tilesets, events, script bytecode, script data, movement types, berries, object graphics or wild encounters did not decode."}
	return {"ok": true, "message": ""}


static func read(rom: RomFile, layout: Dictionary) -> Dictionary:
	var headers: Dictionary = _headers(rom, layout)
	if headers.is_empty():
		return {}
	var encounters: Dictionary = _encounters(rom, layout, headers)
	if encounters.is_empty():
		return {}
	var graphics: Dictionary = _graphics(rom, headers)
	if graphics.is_empty():
		return {}
	var scripts: Dictionary = Gen3Script.read(rom, layout, headers)
	var movement_types: Array = _movement_types(rom, layout)
	var object_graphics: Dictionary = _object_graphics(rom, layout, graphics)
	var berries: Array = [] if object_graphics.is_empty() else _berries(rom, layout, object_graphics, graphics)
	var palettes: Dictionary = _object_palettes(rom, layout, object_graphics, graphics)
	if scripts.is_empty() or movement_types.is_empty() or berries.is_empty() or palettes.is_empty():
		return {}
	if layout.has("shadow_templates") and not _shadow_templates(rom, layout, object_graphics, graphics):
		return {}
	scripts["movement_types"] = movement_types
	scripts["berries"] = berries
	scripts.merge(object_graphics)
	scripts["object_palettes"] = palettes
	return {"headers": headers, "encounters": encounters, "graphics": graphics, "scripts": scripts}


## Per `MOVEMENT_TYPE_*`, whether `InitObjectEventStateFromTemplate` gives it a range of at least one, and the
## direction an object of that type starts facing.
static func _movement_types(rom: RomFile, layout: Dictionary) -> Array:
	var at: int = int(layout["movement_types"])
	var count: int = int(layout["movement_type_count"])
	if not rom.in_bounds(at, count * 2):
		return []
	var out: Array = []
	for type: int in count:
		var ranged: int = rom.u8(at + type)
		var facing: int = rom.u8(at + count + type)
		if ranged > 1 or facing > 4:
			return []
		out.append({"ranged": ranged == 1, "facing": facing})
	return out


## `gBerries` has 43 padded 28-byte records. Hoenn's graphics lookup also accepts ID 44: its pic and palette
## pointers run into the following tables.
static func _berries(rom: RomFile, layout: Dictionary, object_graphics: Dictionary, graphics: Dictionary) -> Array:
	var at: int = int(layout["berries"])
	if not rom.in_bounds(at, 43 * 28):
		return []
	var out: Array = []
	for index: int in (44 if layout.has("berry_graphics") else 43):
		var row: Dictionary = {}
		if index < 43:
			row = {"stage_minutes": rom.u8(at + index * 28 + 20) * 60,
				"min_yield": rom.u8(at + index * 28 + 11), "max_yield": rom.u8(at + index * 28 + 10)}
			if int(row["stage_minutes"]) == 0 or int(row["min_yield"]) > int(row["max_yield"]):
				return []
		for table: String in ["berry_graphics", "berry_palettes"]:
			if not layout.has(table):
				continue
			var source: int = Gen3Layout.read_pointer(rom, int(layout[table]) + index * 4, 5, 1)
			if source < 0:
				return []
			row[table] = Array(rom.slice(source, 5))
		if layout.has("berry_pics"):
			var pics: int = Gen3Layout.read_pointer(rom, int(layout["berry_pics"]) + index * 4, 8)
			if pics < 0:
				return []
			var last: int = 0
			for graphics_id: int in row["berry_graphics"]:
				if graphics_id >= object_graphics["object_graphics"].size():
					return []
				var anims: String = str(int(object_graphics["object_graphics"][graphics_id]["anims"]))
				last = maxi(last, _last_image(object_graphics["sprite_anims"][anims]))
			_read_images(rom, pics, last, object_graphics, graphics)
			row["berry_images"] = pics
		out.append(row)
	return out


## Each `ObjectEventGraphicsInfo` but its tile tag and affine anims, tables keyed by dump offset. An anims
## table runs over every following sequence pointer, as the cartridge reads it, and images as far as it
## indexes.
static func _object_graphics(rom: RomFile, layout: Dictionary, graphics: Dictionary) -> Dictionary:
	var tables: Dictionary = {}
	var out: Dictionary = {"sprite_anims": tables, "sprite_images": {}, "subsprite_tables": {}}
	graphics["sprite_images"] = {}
	for key: String in ["object_graphics", "mauville_graphics"]:
		if not layout.has(key):
			continue
		var rows: Array = []
		for index: int in int(layout[key + "_count"]):
			var info: int = Gen3Layout.read_pointer(rom, int(layout[key]) + index * 4, 0x24)
			var anims: int = -1 if info < 0 else Gen3Layout.read_pointer(rom, info + 0x18, 4)
			if anims < 0:
				return {}
			if not tables.has(str(anims)):
				tables[str(anims)] = _anim_table(rom, anims)
			var row: Dictionary = _graphics_info(rom, info, tables[str(anims)], out, graphics)
			if tables[str(anims)].is_empty() or row.is_empty():
				return {}
			row["anims"] = anims
			rows.append(row)
		out[key] = rows
	var steps: Dictionary = {}
	out["step_anims"] = steps
	return out if _step_anims(rom, layout, tables, steps) else {}


## The first four `gFieldEffectObjectTemplatePointers` entries; TAG_NONE leaves palette slot zero.
static func _shadow_templates(rom: RomFile, layout: Dictionary, out: Dictionary, graphics: Dictionary) -> bool:
	var surfable: int = int(layout["surfable_behaviors"])
	if not rom.in_bounds(surfable, 256):
		return false
	out["surfable_behaviors"] = []
	var mask: int = 1 if rom.id in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN] else 2
	for tile_behavior: int in 256:
		if rom.u8(surfable + tile_behavior) & mask:
			out["surfable_behaviors"].append(tile_behavior)
	var rows: Array = []
	for index: int in 4:
		var at: int = Gen3Layout.read_pointer(rom, int(layout["shadow_templates"]) + index * 4, 24)
		var oam: int = -1 if at < 0 else Gen3Layout.read_pointer(rom, at + 4, 8)
		var images: int = -1 if at < 0 else Gen3Layout.read_pointer(rom, at + 12, 8)
		if oam < 0 or images < 0 or rom.u32le(at) != 0xFFFFFFFF:
			return false
		_read_images(rom, images, 0, out, graphics)
		var size: Vector2i = Gen3ObjectSprites.OAM_SIZES[rom.u16le(oam) >> 14][rom.u16le(oam + 2) >> 14]
		if out["sprite_images"][str(images)].size() != 1 or size != Gen3ObjectSprites.SHADOW_SIZES[index]:
			return false
		rows.append({"images": images, "width": size.x, "height": size.y})
	out["shadow_templates"] = rows
	return true


static func _graphics_info(rom: RomFile, info: int, anims: Array, out: Dictionary, graphics: Dictionary) -> Dictionary:
	var oam: int = Gen3Layout.read_pointer(rom, info + 0x10, 8)
	var images: int = Gen3Layout.read_pointer(rom, info + 0x1C, 8)
	var subsprites: int = 0 if rom.u32le(info + 0x14) == 0 else Gen3Layout.read_pointer(rom, info + 0x14, 48)
	if oam < 0 or images < 0 or subsprites < 0:
		return {}
	var bits: int = rom.u8(info + 0x0C)
	var row: Dictionary = {
		"palette_tag": rom.u16le(info + 2), "reflection_palette_tag": rom.u16le(info + 4),
		"size": rom.u16le(info + 6), "width": rom.s16le(info + 8), "height": rom.s16le(info + 10),
		"palette_slot": bits & 0xF, "shadow_size": (bits >> 4) & 3, "inanimate": bool(bits & 0x40),
		"disable_reflection_palette_load": bool(bits & 0x80), "tracks": rom.u8(info + 0x0D),
		"oam": {"affine_mode": (rom.u16le(oam) >> 8) & 3, "obj_mode": (rom.u16le(oam) >> 10) & 3,
			"shape": rom.u16le(oam) >> 14, "size": rom.u16le(oam + 2) >> 14,
			"priority": (rom.u16le(oam + 4) >> 10) & 3},
		"images": images, "subsprite_tables": subsprites,
	}
	_read_images(rom, images, _last_image(anims), out, graphics)
	if subsprites != 0 and not out["subsprite_tables"].has(str(subsprites)):
		out["subsprite_tables"][str(subsprites)] = _subsprite_tables(rom, subsprites)
	if out["sprite_images"][str(images)].is_empty() \
			or (subsprites != 0 and out["subsprite_tables"][str(subsprites)].is_empty()):
		return {}
	return row


static func _read_images(rom: RomFile, at: int, last: int, out: Dictionary, graphics: Dictionary) -> void:
	var images: Array = out["sprite_images"].get(str(at), [])
	if images.size() <= last:
		out["sprite_images"][str(at)] = _image_table(rom, at, last, graphics["sprite_images"])


static func _last_image(anims: Array) -> int:
	var last: int = 0
	for sequence: Array in anims:
		for word: int in sequence:
			if word & 0xFFFF < 0x8000:
				last = maxi(last, word & 0xFFFF)
	return last


## `SpriteFrameImage` rows 0 to [param last] as [data offset, size], up to the first that points at no data.
static func _image_table(rom: RomFile, at: int, last: int, bytes: Dictionary) -> Array:
	var out: Array = []
	for index: int in last + 1:
		var size: int = rom.u16le(at + index * 8 + 4) if rom.in_bounds(at + index * 8, 8) else 0
		var data: int = Gen3Layout.read_pointer(rom, at + index * 8, maxi(size, 1), 1)
		if data < 0 or size == 0 or size % GbaTiles.TILE_BYTES != 0:
			break
		out.append([data, size])
		if bytes.get(str(data), {}).get("bytes", []).size() < size:
			bytes[str(data)] = {"bytes": Array(rom.slice(data, size))}
	return out


## The six `SubspriteTable`s, a null list empty. Ruby and Sapphire's halfword `x` and `y` pad `Subsprite` to 8 bytes.
static func _subsprite_tables(rom: RomFile, at: int) -> Array:
	var wide: bool = rom.id in [RomRegistry.RUBY, RomRegistry.SAPPHIRE]
	var size: int = 8 if wide else 4
	var out: Array = []
	for index: int in Gen3ObjectSprites.SUBSPRITE_TABLES:
		var count: int = rom.u8(at + index * 8)
		var list: int = 0 if rom.u32le(at + index * 8 + 4) == 0 \
			else Gen3Layout.read_pointer(rom, at + index * 8 + 4, count * size, 2)
		if list < 0 or count > Gen3ObjectSprites.SUBSPRITE_LIMIT or (list == 0) != (count == 0):
			return []
		var table: Array = []
		for part: int in count:
			var p: int = list + part * size
			var bits: int = rom.u16le(p + (4 if wide else 2))
			table.append({"x": rom.s16le(p) if wide else rom.s8(p),
				"y": rom.s16le(p + 2) if wide else rom.s8(p + 1),
				"shape": bits & 3, "size": (bits >> 2) & 3, "tile_offset": (bits >> 4) & 0x3FF,
				"priority": bits >> 14})
		out.append(table)
	return out


## `sObjectEventSpritePalettes`, the four `sObjectPaletteTagSets` and the reflection sets by main tag.
static func _object_palettes(rom: RomFile, layout: Dictionary, object_graphics: Dictionary,
		graphics: Dictionary) -> Dictionary:
	if object_graphics.is_empty():
		return {}
	var rows: Array = []
	graphics["object_palettes"] = {}
	if not layout.has("object_palettes"):
		return {"rows": rows, "tag_sets": [], "player_reflections": {}, "special_reflections": {}}
	var at: int = int(layout["object_palettes"])
	while rom.in_bounds(at, 8) and rom.u32le(at) != 0:
		var colors: int = Gen3Layout.read_pointer(rom, at, Gen3Layout.PALETTE_BYTES, 2)
		if colors < 0:
			return {}
		rows.append([rom.u16le(at + 4), colors])
		graphics["object_palettes"][str(colors)] = {"bytes": Array(rom.slice(colors, Gen3Layout.PALETTE_BYTES))}
		at += 8
	var out: Dictionary = {"rows": rows, "tag_sets": [],
		"player_reflections": _reflection_sets(rom, int(layout["player_reflection_palettes"])),
		"special_reflections": _reflection_sets(rom, int(layout["special_reflection_palettes"]))}
	if out["player_reflections"].is_empty() or out["special_reflections"].is_empty():
		return {}
	for index: int in Gen3ObjectSprites.REFLECTION_TYPES:
		var tag_set: int = Gen3Layout.read_pointer(rom, int(layout["object_palette_tags"]) + index * 4,
			Gen3ObjectSprites.PALETTE_SLOTS * 2, 2)
		if tag_set < 0:
			return {}
		out["tag_sets"].append(range(Gen3ObjectSprites.PALETTE_SLOTS).map(
			func(slot: int) -> int: return rom.u16le(tag_set + slot * 2)))
	return out if _palette_tags_found(out, object_graphics) else {}


## Every tag the palette code can look up has a row; `FindObjectEventPaletteIndexByTag` would miss and copy
## from past the table. FRLG's reflection sets name Hoenn tags no graphics reach.
static func _palette_tags_found(palettes: Dictionary, object_graphics: Dictionary) -> bool:
	var tags: Array = palettes["rows"].map(func(row: Array) -> int: return int(row[0]))
	var needed: Array = []
	for type: int in Gen3ObjectSprites.USED_REFLECTION_TYPES:
		needed.append_array(palettes["tag_sets"][type])
	var sets: Dictionary = {Gen3ObjectSprites.PALSLOT_PLAYER: "player_reflections",
		Gen3ObjectSprites.PALSLOT_NPC_SPECIAL: "special_reflections"}
	for row: Dictionary in object_graphics.get("object_graphics", []) + object_graphics.get("mauville_graphics", []):
		var slot: int = int(row["palette_slot"])
		if sets.has(slot):
			needed.append(int(row["palette_tag"]))
			var reflections: Array = palettes[sets[slot]].get(str(int(row["palette_tag"])), [])
			for type: int in Gen3ObjectSprites.USED_REFLECTION_TYPES:
				needed.append_array(reflections.slice(type, type + 1))
	for tag: int in needed:
		if not tags.has(tag):
			return false
	return true


static func _reflection_sets(rom: RomFile, at: int) -> Dictionary:
	var out: Dictionary = {}
	while rom.in_bounds(at, 8) and rom.u16le(at) != Gen3ObjectSprites.PALETTE_TAG_NONE:
		var data: int = Gen3Layout.read_pointer(rom, at + 4, Gen3ObjectSprites.REFLECTION_TYPES * 2, 2)
		if data < 0:
			return {}
		if not out.has(str(rom.u16le(at))):
			out[str(rom.u16le(at))] = range(Gen3ObjectSprites.REFLECTION_TYPES).map(
				func(type: int) -> int: return rom.u16le(data + type * 2))
		at += 8
	return out


## `GetStepAnimTable`'s `animPos` by anims table; Ruby's `sub_805FE28` steps every table.
static func _step_anims(rom: RomFile, layout: Dictionary, tables: Dictionary, out: Dictionary) -> bool:
	if not layout.has("step_anims"):
		for anims: String in tables:
			out[anims] = RUBY_STEP_POSITIONS
		return true
	var at: int = int(layout["step_anims"])
	while rom.in_bounds(at, 8) and rom.u32le(at) != 0:
		var anims: int = Gen3Layout.read_pointer(rom, at, 4)
		if anims < 0 or _anim_table(rom, anims).is_empty() or out.size() == STEP_ANIMS_LIMIT:
			return false
		out[str(anims)] = Array(rom.slice(at + 4, 4))
		at += 8
	return rom.in_bounds(at, 8)


static func _anim_table(rom: RomFile, at: int) -> Array:
	var out: Array = []
	while true:
		var sequence: int = Gen3Layout.read_pointer(rom, at + out.size() * 4, 4)
		var words: Array = [] if sequence < 0 else _anim_sequence(rom, sequence)
		if words.is_empty():
			return out
		out.append(words)
	return out


## `union AnimCmd` words through `ANIMCMD_END` or `ANIMCMD_JUMP`; a frame keeps its top byte clear, so a run
## of other data is not taken for one.
static func _anim_sequence(rom: RomFile, at: int) -> Array:
	var out: Array = []
	while out.size() < Gen3SpriteAnim.SEQUENCE_LIMIT and rom.in_bounds(at + out.size() * 4, 4):
		var word: int = rom.u32le(at + out.size() * 4)
		if word >> 24 != 0:
			return []
		out.append(word)
		if word & 0xFFFF == Gen3SpriteAnim.JUMP:
			return out if (word >> 16) & 0x3F < out.size() else []
		if word & 0xFFFF == Gen3SpriteAnim.END:
			return out
	return []


static func _headers(rom: RomFile, layout: Dictionary) -> Dictionary:
	var sizes: Array = layout["map_group_sizes"]
	var table: int = int(layout["map_groups"])
	if not rom.in_bounds(table, sizes.size() * 4):
		return {}
	var out: Dictionary = {}
	for group: int in sizes.size():
		var pointers: int = Gen3Layout.read_pointer(rom, table + group * 4, int(sizes[group]) * 4)
		if pointers < 0:
			return {}
		for number: int in int(sizes[group]):
			var at: int = Gen3Layout.read_pointer(rom, pointers + number * 4, HEADER_SIZE)
			var row: Dictionary = _header(rom, layout, at)
			if row.is_empty():
				return {}
			row.merge({"group": group, "number": number})
			out["%d:%d" % [group, number]] = row
	return out


static func _header(rom: RomFile, layout: Dictionary, at: int) -> Dictionary:
	if at < 0:
		return {}
	var frlg: bool = rom.id in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN]
	var map_layout: int = Gen3Layout.read_pointer(rom, at, 28 if frlg else 24)
	var events: int = Gen3Layout.read_pointer(rom, at + 4, 20)
	var scripts: int = 0 if rom.u32le(at + 8) == 0 else Gen3Layout.read_pointer(rom, at + 8, 1, 1)
	if map_layout < 0 or events < 0 or scripts < 0:
		return {}
	var dimensions: Dictionary = _layout(rom, map_layout, frlg)
	var connections: Array = _connections(rom, layout, at + 12)
	var event_rows: Dictionary = Gen3Events.read(rom, layout, events)
	var script_rows: Array = Gen3Events.map_scripts(rom, scripts)
	if dimensions.is_empty() or connections == [{}] or event_rows.is_empty() or script_rows == [{}]:
		return {}
	var out: Dictionary = {
		"header_offset": at, "layout_offset": map_layout,
		"events_offset": events, "scripts_offset": scripts,
		"music": rom.u16le(at + 16), "layout_id": rom.u16le(at + 18),
		"region_map_section": rom.u8(at + 20), "requires_flash": rom.u8(at + 21) != 0,
		"weather": rom.u8(at + 22), "map_type": rom.u8(at + 23),
		"battle_scene": rom.u8(at + 27), "connections": connections,
		"events": event_rows, "map_scripts": script_rows,
	}
	out.merge(dimensions)
	out.merge(_flags(rom, at, frlg))
	return out


static func _layout(rom: RomFile, at: int, frlg: bool) -> Dictionary:
	var width: int = rom.u32le(at)
	var height: int = rom.u32le(at + 4)
	var border_width: int = rom.u8(at + 24) if frlg else 2
	var border_height: int = rom.u8(at + 25) if frlg else 2
	if width < 1 or height < 1 or width > 0x7FFF or height > 0x7FFF \
		or border_width < 1 or border_height < 1:
		return {}
	var border: int = Gen3Layout.read_pointer(rom, at + 8, border_width * border_height * 2, 2)
	var blocks: int = Gen3Layout.read_pointer(rom, at + 12, width * height * 2, 2)
	var primary: int = Gen3Layout.read_pointer(rom, at + 16, 24)
	var secondary: int = Gen3Layout.read_pointer(rom, at + 20, 24)
	if border < 0 or blocks < 0 or primary < 0 or secondary < 0:
		return {}
	return {"width": width, "height": height, "border_width": border_width,
		"border_height": border_height, "border_offset": border, "blocks_offset": blocks,
		"primary_tileset_offset": primary, "secondary_tileset_offset": secondary}


## Ruby's flags only carry show_map_name; running/cycling are code rules there.
static func _flags(rom: RomFile, at: int, frlg: bool) -> Dictionary:
	if rom.id in [RomRegistry.RUBY, RomRegistry.SAPPHIRE]:
		return {"flags": rom.u8(at + 26), "escape_rope": rom.u8(at + 25),
			"show_map_name": rom.u8(at + 26) != 0}
	var flags: int = rom.u8(at + (25 if frlg else 26))
	var out: Dictionary = {
		"allow_cycling": rom.u8(at + 24) != 0 if frlg else (flags & 1) != 0,
		"allow_escaping": (flags & (1 if frlg else 2)) != 0,
		"allow_running": (flags & (2 if frlg else 4)) != 0,
		"show_map_name": (flags & (4 if frlg else 8)) != 0,
	}
	if frlg:
		out["floor_number"] = rom.s8(at + 26)
	return out


static func _connections(rom: RomFile, layout: Dictionary, pointer_at: int) -> Array:
	if rom.u32le(pointer_at) == 0:
		return []
	var at: int = Gen3Layout.read_pointer(rom, pointer_at, 8)
	if at < 0:
		return [{}]
	var count: int = rom.u32le(at)
	if count < 1 or count > 255:
		return [{}]
	var list: int = Gen3Layout.read_pointer(rom, at + 4, count * 12)
	if list < 0:
		return [{}]
	var out: Array = []
	for slot: int in count:
		var row: int = list + slot * 12
		var direction: int = rom.u8(row)
		var group: int = rom.u8(row + 8)
		var number: int = rom.u8(row + 9)
		if direction < 1 or direction > 6 or not Gen3Layout.valid_map(layout, group, number):
			return [{}]
		var offset: int = rom.u32le(row + 4)
		out.append({"direction": direction, "offset": offset if offset < 0x80000000 else offset - 0x100000000,
			"group": group, "number": number})
	return out


static func _encounters(rom: RomFile, layout: Dictionary, headers: Dictionary) -> Dictionary:
	var at: int = int(layout["wild_headers"])
	var count: int = int(layout["wild_header_count"])
	if not rom.in_bounds(at, (count + 1) * WILD_HEADER_SIZE):
		return {}
	var end: int = at + count * WILD_HEADER_SIZE
	if rom.u8(end) != 0xFF or rom.u8(end + 1) != 0xFF:
		return {}
	var out: Dictionary = {"land": {}, "water": {}, "rock_smash": {},
		"old_rod": {}, "good_rod": {}, "super_rod": {}}
	var seen: Dictionary = {}
	for index: int in count:
		var row: int = at + index * WILD_HEADER_SIZE
		var key: String = "%d:%d" % [rom.u8(row), rom.u8(row + 1)]
		if not headers.has(key):
			return {}
		var variant: int = int(seen.get(key, 0))
		seen[key] = variant + 1
		if not _encounter_methods(rom, layout, row, key, variant, out):
			return {}
	return out


## GetCurrentMapWildMonHeaderId adds the Altering Cave set to its first row. Every occurrence keeps its
## ordinal even when a method is absent in that set.
static func _encounter_methods(rom: RomFile, layout: Dictionary, at: int, key: String, variant: int, out: Dictionary) -> bool:
	var records: Dictionary = {}
	for method: int in WILD_METHODS.size():
		var pointer_at: int = at + 4 + method * 4
		if rom.u32le(pointer_at) == 0:
			continue
		var record: Dictionary = _wild_info(rom, layout, pointer_at, method)
		if record.is_empty():
			return false
		if method < 3:
			records[WILD_METHODS[method]] = record
			continue
		for rod: String in RODS:
			var rod_record: Dictionary = record.duplicate(true)
			rod_record["slots"] = record["slots"].slice(int(RODS[rod][0]), int(RODS[rod][1]))
			records[rod] = rod_record
	for method: String in out:
		var table: Dictionary = out[method]
		if not records.has(method) and not table.has(key):
			continue
		var variants: Array = table.get(key, [])
		while variants.size() < variant:
			variants.append({})
		variants.append(records.get(method, {}))
		table[key] = variants
	return true


static func _wild_info(rom: RomFile, layout: Dictionary, pointer_at: int, method: int) -> Dictionary:
	var at: int = Gen3Layout.read_pointer(rom, pointer_at, 8)
	if at < 0:
		return {}
	var rate: int = rom.u8(at)
	var chances: Array = SLOT_CHANCES[method]
	var mons: int = Gen3Layout.read_pointer(rom, at + 4, chances.size() * 4)
	if rate > 100 or mons < 0:
		return {}
	var slots: Array = []
	for slot: int in chances.size():
		var row: int = mons + slot * 4
		var low: int = rom.u8(row)
		var high: int = rom.u8(row + 1)
		var species: int = Gen3Layout.national_number(rom, layout, rom.u16le(row + 2))
		if low < 1 or low > 100 or high < 1 or high > 100 or species < 1 or species > Gen3Layout.NATIONAL_DEX_COUNT:
			return {}
		slots.append({"slot": slot, "min_level": low, "max_level": high,
			"species": species, "chance": int(chances[slot])})
	return {"rate": rate, "slots": slots}


## pret's metatiles.h/metatiles.inc places each attribute array immediately after its eight-word metatile
## array. FRLG swaps callback/attributes in Tileset.
static func _graphics(rom: RomFile, headers: Dictionary) -> Dictionary:
	var layouts: Dictionary = {}
	var tilesets: Dictionary = {}
	for header: Dictionary in headers.values():
		var key: String = str(header["layout_offset"])
		if not layouts.has(key):
			layouts[key] = {
				"blocks": {"bytes": Array(rom.slice(header["blocks_offset"], header["width"] * header["height"] * 2))},
				"border": {"bytes": Array(rom.slice(header["border_offset"], header["border_width"] * header["border_height"] * 2))},
			}
		for field: String in ["primary_tileset_offset", "secondary_tileset_offset"]:
			key = str(header[field])
			if not tilesets.has(key):
				tilesets[key] = _tileset(rom, int(header[field]))
			var record: Dictionary = tilesets[key]
			if record.is_empty() or bool(record["secondary"]) != (field == "secondary_tileset_offset"):
				return {}
	return {"layouts": layouts, "tilesets": tilesets}


static func _tileset(rom: RomFile, at: int) -> Dictionary:
	var frlg: bool = rom.id in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN]
	var attribute_size: int = 4 if frlg else 2
	var secondary: int = rom.u8(at + 1)
	if rom.u8(at) > 1 or secondary > 1:
		return {}
	var split: int = primary_tile_count(rom.id)
	var capacity: int = 1024 - split if secondary == 1 else split
	var tiles: int = Gen3Layout.read_pointer(rom, at + 4, 4)
	var metatiles: int = Gen3Layout.read_pointer(rom, at + 12, 16, 2)
	var attributes: int = Gen3Layout.read_pointer(rom, at + (20 if frlg else 16), attribute_size, attribute_size)
	var count: int = (attributes - metatiles) / 16
	if tiles < 0 or metatiles < 0 or attributes < 0 or count < 1 or count > capacity \
		or (attributes - metatiles) % 16 != 0 \
		or not rom.in_bounds(attributes, count * attribute_size):
		return {}
	var tile_bytes: PackedByteArray = _tile_bytes(rom, tiles, capacity, rom.u8(at) == 1)
	if tile_bytes.is_empty():
		return {}
	var palette: Dictionary = _tileset_palette(rom, at, frlg, secondary)
	var callback: int = int(palette.get("callback_offset", 0))
	var animation: Dictionary = Gen3TilesetAnims.read(rom, callback) if callback != 0 else {}
	if palette.is_empty() or (callback != 0 and animation.is_empty()):
		return {}
	var out: Dictionary = {"compressed": rom.u8(at) == 1, "secondary": secondary == 1,
		"tile_offset": split if secondary == 1 else 0, "tile_count": tile_bytes.size() / 32,
		"metatile_offset": split if secondary == 1 else 0, "metatile_count": count,
		"attribute_size": attribute_size,
		"tiles": {"bytes": Array(tile_bytes)},
		"metatiles": {"bytes": Array(rom.slice(metatiles, count * 16))},
		"attributes": {"bytes": Array(rom.slice(attributes, count * attribute_size))},
		"metatile_tail": {"bytes": Array(_tail(rom, metatiles + count * 16, (capacity - count) * 16))},
		"attribute_tail": {"bytes": Array(_tail(rom, attributes + count * attribute_size,
			(capacity - count) * attribute_size))},
		"animation": animation}
	out.merge(palette)
	return out


## The ROM after a metatile or attribute array, up to the bank's id space: `DrawMetatileAt` and
## `GetMetatileAttributesById` index past the array for an id the tileset lacks, which a connection strip from
## a map on another secondary tileset brings into the backup map.
static func _tail(rom: RomFile, at: int, length: int) -> PackedByteArray:
	return rom.slice(at, clampi(rom.size() - at, 0, length))


static func _tile_bytes(rom: RomFile, at: int, capacity: int, compressed: bool) -> PackedByteArray:
	if compressed and (rom.u32le(at) >> 8) % GbaTiles.TILE_BYTES != 0:
		return PackedByteArray()
	var bytes: PackedByteArray = GbaLz.decompress(rom.bytes(), at) if compressed \
		else rom.slice(at, capacity * GbaTiles.TILE_BYTES)
	if bytes.size() < GbaTiles.TILE_BYTES or bytes.size() > capacity * GbaTiles.TILE_BYTES:
		return PackedByteArray()
	return bytes


static func _tileset_palette(rom: RomFile, at: int, frlg: bool, secondary: int) -> Dictionary:
	var primary_pals: int = 7 if frlg else 6
	var total_pals: int = 12 if rom.id in [RomRegistry.RUBY, RomRegistry.SAPPHIRE] else 13
	var first_pal: int = primary_pals if secondary == 1 else 0
	var pal_count: int = total_pals - primary_pals if secondary == 1 else primary_pals
	var palettes: int = Gen3Layout.read_pointer(rom, at + 8, total_pals * 32 if secondary == 1 else primary_pals * 32)
	var callback: int = rom.u32le(at + (16 if frlg else 20))
	var callback_offset: int = Gen3Layout.rom_offset(callback & ~1)
	if palettes < 0 or (callback != 0 and ((callback & 1) == 0 or not rom.in_bounds(callback_offset, 2))):
		return {}
	return {"palette_offset": first_pal, "palette_count": pal_count,
		"callback_offset": callback_offset if callback != 0 else 0,
		"palettes": {"bytes": Array(rom.slice(palettes + first_pal * 32, pal_count * 32))}}


static func primary_tile_count(id: StringName) -> int:
	return 640 if id in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN] else 512


## One metatile id's tiles and attributes. An id past the tileset's rows reads the ROM after the arrays, as
## the cartridge does; one past that is empty.
static func metatile(tileset: Dictionary, number: int) -> Dictionary:
	var row: Array = _metatile_row(tileset, number)
	if row.is_empty():
		return {}
	var tiles: PackedByteArray = row[0]
	var index: int = row[2]
	var raw: int = metatile_attributes(tileset, number)
	var entries: Array = []
	for slot: int in 8:
		var word: int = tiles.decode_u16(index * 16 + slot * 2)
		entries.append({"tile": word & 0x3FF, "flip_x": (word & 0x400) != 0,
			"flip_y": (word & 0x800) != 0, "palette": word >> 12})
	return {"tiles": entries, "attributes": raw, "behavior": behavior(tileset, raw),
		"layer_type": layer_type(tileset, raw)}


## The raw attribute word of the id [method metatile] reads, or -1 where it is empty.
static func metatile_attributes(tileset: Dictionary, number: int) -> int:
	var row: Array = _metatile_row(tileset, number)
	if row.is_empty():
		return -1
	var words: PackedByteArray = row[1]
	return words.decode_u32(row[2] * 4) if _wide(tileset) else words.decode_u16(row[2] * 2)


static func behavior(tileset: Dictionary, raw: int) -> int:
	return raw & (0x1FF if _wide(tileset) else 0xFF)


static func layer_type(tileset: Dictionary, raw: int) -> int:
	return (raw >> 29) & 3 if _wide(tileset) else (raw >> 12) & 15


static func _wide(tileset: Dictionary) -> bool:
	return int(tileset["attribute_size"]) == 4


## The metatile and attribute arrays an id reads and its index in them.
static func _metatile_row(tileset: Dictionary, number: int) -> Array:
	var index: int = number - int(tileset.get("metatile_offset", 0))
	var count: int = int(tileset.get("metatile_count", 0))
	if index < 0:
		return []
	if index < count:
		return [tileset["metatiles"]["bytes"], tileset["attributes"]["bytes"], index]
	index -= count
	var tiles: PackedByteArray = tileset["metatile_tail"]["bytes"]
	var words: PackedByteArray = tileset["attribute_tail"]["bytes"]
	if (index + 1) * 16 > tiles.size() or (index + 1) * int(tileset["attribute_size"]) > words.size():
		return []
	return [tiles, words, index]
