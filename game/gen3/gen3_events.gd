class_name Gen3Events
extends RefCounted

const KINDS: Array[String] = ["objects", "warps", "coords", "backgrounds"]
const STRIDES: Array[int] = [24, 8, 16, 12]


static func read(rom: RomFile, layout: Dictionary, at: int) -> Dictionary:
	if not rom.in_bounds(at, 20):
		return {}
	var out: Dictionary = {}
	for kind: int in KINDS.size():
		var count: int = rom.u8(at + kind)
		var rows: Array = []
		var offset: int = Gen3Layout.read_pointer(rom, at + 4 + kind * 4, count * STRIDES[kind]) if count > 0 else 0
		if offset < 0:
			return {}
		for slot: int in count:
			var row: Dictionary = _event(rom, layout, offset + slot * STRIDES[kind], kind)
			if row.is_empty():
				return {}
			rows.append(row)
		out[KINDS[kind]] = rows
	return out


static func _event(rom: RomFile, layout: Dictionary, at: int, kind: int) -> Dictionary:
	match kind:
		0: return _object(rom, layout, at)
		1: return _warp(rom, layout, at)
		2: return _coord(rom, at)
		3: return _background(rom, at)
	return {}


static func _script(rom: RomFile, at: int) -> int:
	return 0 if rom.u32le(at) == 0 else Gen3Layout.read_pointer(rom, at, 1, 1)


static func _object(rom: RomFile, layout: Dictionary, at: int) -> Dictionary:
	var kind: int = rom.u8(at + 2)
	var out: Dictionary = {"local_id": rom.u8(at), "graphics_id": rom.u8(at + 1),
		"kind": kind, "x": rom.s16le(at + 4), "y": rom.s16le(at + 6)}
	if kind == 255 and rom.id in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN]:
		var number: int = rom.u16le(at + 12)
		var group: int = rom.u16le(at + 14)
		if not Gen3Layout.valid_map(layout, group, number):
			return {}
		out.merge({"target_local_id": rom.u8(at + 8), "target_group": group, "target_number": number})
		return out
	if kind != 0:
		return {}
	var script: int = _script(rom, at + 16)
	if script < 0:
		return {}
	out.merge({"elevation": rom.u8(at + 8), "movement_type": rom.u8(at + 9),
		"movement_range_x": rom.u8(at + 10) & 15, "movement_range_y": rom.u8(at + 10) >> 4,
		"trainer_type": rom.u16le(at + 12), "trainer_sight_or_berry_tree_id": rom.u16le(at + 14),
		"script_offset": script, "flag": rom.u16le(at + 20)})
	return out


static func _warp(rom: RomFile, layout: Dictionary, at: int) -> Dictionary:
	var group: int = rom.u8(at + 7)
	var number: int = rom.u8(at + 6)
	if not Gen3Layout.valid_map(layout, group, number) and not (group == number and group in [0x7F, 0xFF]):
		return {}
	return {"x": rom.s16le(at), "y": rom.s16le(at + 2), "elevation": rom.u8(at + 4),
		"warp_id": rom.u8(at + 5), "group": group, "number": number}


static func _coord(rom: RomFile, at: int) -> Dictionary:
	var script: int = _script(rom, at + 12)
	if script < 0:
		return {}
	var frlg: bool = rom.id in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN]
	return {"x": rom.u16le(at) if frlg else rom.s16le(at),
		"y": rom.u16le(at + 2) if frlg else rom.s16le(at + 2),
		"elevation": rom.u8(at + 4), "variable": rom.u16le(at + 6),
		"value": rom.u16le(at + 8), "script_offset": script}


static func _background(rom: RomFile, at: int) -> Dictionary:
	var kind: int = rom.u8(at + 5)
	var out: Dictionary = {"x": rom.u16le(at), "y": rom.u16le(at + 2),
		"elevation": rom.u8(at + 4), "kind": kind}
	if kind in [5, 6, 7]:
		var frlg: bool = rom.id in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN]
		out.merge({"item": rom.u16le(at + 8),
			"hidden_item_id": rom.u8(at + 10) if frlg else rom.u16le(at + 10)})
		if frlg:
			out.merge({"quantity": rom.u8(at + 11) & 0x7F, "underfoot": (rom.u8(at + 11) & 0x80) != 0})
	elif kind == 8 and rom.id not in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN]:
		out["secret_base_id"] = rom.u32le(at + 8)
	else:
		var script: int = _script(rom, at + 8)
		if script < 0:
			return {}
		out["script_offset"] = script
	return out


## src/script.c: five-byte dispatch rows; types 2/4 point at eight-byte comparisons.
## Table terminators are one byte and two bytes respectively, with no pointer.
static func map_scripts(rom: RomFile, at: int) -> Array:
	if at == 0:
		return []
	var out: Array = []
	while rom.in_bounds(at, 1):
		var type: int = rom.u8(at)
		if type == 0:
			return out
		if type > (6 if rom.id in [RomRegistry.RUBY, RomRegistry.SAPPHIRE] else 7):
			return [{}]
		var offset: int = Gen3Layout.read_pointer(rom, at + 1, 2 if type in [2, 4] else 1, 1)
		if offset < 0:
			return [{}]
		var row: Dictionary = {"type": type, "script_offset": offset}
		if type in [2, 4]:
			var conditions: Array = _conditions(rom, offset)
			if conditions == [{}]:
				return [{}]
			row = {"type": type, "table_offset": offset, "conditions": conditions}
		out.append(row)
		at += 5
	return [{}]


static func _conditions(rom: RomFile, at: int) -> Array:
	var out: Array = []
	while rom.in_bounds(at, 2):
		var variable: int = rom.u16le(at)
		if variable == 0:
			return out
		if not rom.in_bounds(at, 8):
			return [{}]
		var script: int = Gen3Layout.read_pointer(rom, at + 4, 1, 1)
		if script < 0:
			return [{}]
		out.append({"variable": variable, "value": rom.u16le(at + 2), "script_offset": script})
		at += 8
	return [{}]
