class_name Gen3World
extends RefCounted

## GBA map headers and normal wild tables, before event/scripts and metatile decoding.
## Gen3Importer owns content tables; Gen2WorldMap encodes the GB map format.
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


static func verify(rom: RomFile, layout: Dictionary) -> Dictionary:
	if read(rom, layout).is_empty():
		return {"ok": false, "message": "Map headers or wild encounters did not decode."}
	return {"ok": true, "message": ""}


static func read(rom: RomFile, layout: Dictionary) -> Dictionary:
	var headers: Dictionary = _headers(rom, layout)
	if headers.is_empty():
		return {}
	var encounters: Dictionary = _encounters(rom, layout, headers)
	if encounters.is_empty():
		return {}
	return {"headers": headers, "encounters": encounters}


static func _pointer(rom: RomFile, at: int, length: int, alignment: int = 4) -> int:
	if not rom.in_bounds(at, 4):
		return -1
	var offset: int = Gen3Layout.rom_offset(rom.u32le(at))
	return offset if offset % alignment == 0 and rom.in_bounds(offset, length) else -1


static func _valid_map(layout: Dictionary, group: int, number: int) -> bool:
	var sizes: Array = layout["map_group_sizes"]
	return group >= 0 and group < sizes.size() and number >= 0 and number < int(sizes[group])


static func _headers(rom: RomFile, layout: Dictionary) -> Dictionary:
	var sizes: Array = layout["map_group_sizes"]
	var table: int = int(layout["map_groups"])
	if not rom.in_bounds(table, sizes.size() * 4):
		return {}
	var out: Dictionary = {}
	for group: int in sizes.size():
		var pointers: int = _pointer(rom, table + group * 4, int(sizes[group]) * 4)
		if pointers < 0:
			return {}
		for number: int in int(sizes[group]):
			var at: int = _pointer(rom, pointers + number * 4, HEADER_SIZE)
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
	var map_layout: int = _pointer(rom, at, 28 if frlg else 24)
	var events: int = _pointer(rom, at + 4, 20)
	var scripts: int = _pointer(rom, at + 8, 1, 1)
	if map_layout < 0 or events < 0 or scripts < 0:
		return {}
	var dimensions: Dictionary = _layout(rom, map_layout, frlg)
	var connections: Array = _connections(rom, layout, at + 12)
	if dimensions.is_empty() or connections == [{}]:
		return {}
	var out: Dictionary = {
		"header_offset": at, "layout_offset": map_layout,
		"events_offset": events, "scripts_offset": scripts,
		"music": rom.u16le(at + 16), "layout_id": rom.u16le(at + 18),
		"region_map_section": rom.u8(at + 20), "requires_flash": rom.u8(at + 21) != 0,
		"weather": rom.u8(at + 22), "map_type": rom.u8(at + 23),
		"battle_scene": rom.u8(at + 27), "connections": connections,
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
	var border: int = _pointer(rom, at + 8, border_width * border_height * 2, 2)
	var blocks: int = _pointer(rom, at + 12, width * height * 2, 2)
	var primary: int = _pointer(rom, at + 16, 24)
	var secondary: int = _pointer(rom, at + 20, 24)
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
	var at: int = _pointer(rom, pointer_at, 8)
	if at < 0:
		return [{}]
	var count: int = rom.u32le(at)
	if count < 1 or count > 255:
		return [{}]
	var list: int = _pointer(rom, at + 4, count * 12)
	if list < 0:
		return [{}]
	var out: Array = []
	for slot: int in count:
		var row: int = list + slot * 12
		var direction: int = rom.u8(row)
		var group: int = rom.u8(row + 8)
		var number: int = rom.u8(row + 9)
		if direction < 1 or direction > 6 or not _valid_map(layout, group, number):
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


## GetCurrentMapWildMonHeaderId adds the Altering Cave set to its first row.
## Every occurrence keeps its ordinal even when a method is absent in that set.
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
	var at: int = _pointer(rom, pointer_at, 8)
	if at < 0:
		return {}
	var rate: int = rom.u8(at)
	var chances: Array = SLOT_CHANCES[method]
	var mons: int = _pointer(rom, at + 4, chances.size() * 4)
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
