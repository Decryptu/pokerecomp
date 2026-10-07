class_name Gen3Trainers
extends RefCounted

## `gTrainers` holds individuals, not classes. `CreateNPCTrainerParty` selects
## one of four padded structs; species convert to national numbers at import.
static func verify(rom: RomFile, layout: Dictionary) -> Dictionary:
	if not rom.in_bounds(int(layout["trainers"]), int(layout["trainer_count"]) * Gen3Layout.TRAINER_SIZE):
		return _fail("gTrainers leaves the dump.")
	for number: int in int(layout["trainer_class_count"]):
		var at: int = int(layout["trainer_class_names"]) + number * Gen3Layout.TRAINER_CLASS_NAME_SIZE
		if not Gen3Text.ends_within(rom.bytes(), at, Gen3Layout.TRAINER_CLASS_NAME_SIZE):
			return _fail("Trainer class %d has no name end." % number)
	for number: int in range(1, int(layout["trainer_count"])):
		if _trainer(rom, layout, number).is_empty():
			return _fail("Trainer %d has an invalid header or party." % number)
	var money: Dictionary = _verify_money(rom, layout)
	return _verify_pics(rom, layout) if bool(money["ok"]) else money


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "message": message}


static func read(rom: RomFile, layout: Dictionary) -> Array:
	var out: Array = []
	for number: int in range(1, int(layout["trainer_count"])):
		var entry: Dictionary = _trainer(rom, layout, number)
		if entry.is_empty():
			return []
		out.append(entry)
	return out


static func _trainer(rom: RomFile, layout: Dictionary, number: int) -> Dictionary:
	var at: int = int(layout["trainers"]) + number * Gen3Layout.TRAINER_SIZE
	if not rom.in_bounds(at, Gen3Layout.TRAINER_SIZE):
		return {}
	var flags: int = rom.u8(at)
	var trainer_class: int = rom.u8(at + 1)
	var picture: int = rom.u8(at + 3)
	var count: int = rom.u8(at + 32)
	if flags >= Gen3Layout.PARTY_STRIDES.size() or trainer_class >= int(layout["trainer_class_count"]) \
		or picture >= int(layout["trainer_pic_count"]) or count < 1 or count > Gen3Layout.TRAINER_PARTY_LIMIT \
		or rom.u8(at + 24) > 1 or not Gen3Text.ends_within(rom.bytes(), at + 4, Gen3Layout.TRAINER_NAME_SIZE):
		return {}
	var party: Array = _party(rom, layout, Gen3Layout.rom_offset(rom.u32le(at + 36)), count, flags)
	var items: Array[int] = []
	for slot: int in 4:
		var item: int = rom.u16le(at + 16 + slot * 2)
		if item >= int(layout["item_count"]):
			return {}
		items.append(item)
	if party.is_empty():
		return {}
	return {
		"number": number,
		"name": Gen3Text.decode_fixed(rom.bytes(), at + 4, Gen3Layout.TRAINER_NAME_SIZE),
		"class": trainer_class,
		"class_name": Gen3Text.decode_fixed(rom.bytes(), int(layout["trainer_class_names"])
			+ trainer_class * Gen3Layout.TRAINER_CLASS_NAME_SIZE, Gen3Layout.TRAINER_CLASS_NAME_SIZE),
		"type": flags,
		"female": (rom.u8(at + 2) & 0x80) != 0,
		"encounter_music": rom.u8(at + 2) & 0x7F,
		"picture": picture,
		"palette": _palette(rom, layout, picture),
		"pic_size": rom.u16le(int(layout["trainer_pics"]) + picture * Gen3Layout.PIC_ENTRY_SIZE + 4),
		"pic_coordinates": _coordinates(rom, layout, picture),
		"items": items,
		"double_battle": rom.u8(at + 24) != 0,
		"ai_flags": rom.u32le(at + 28),
		"base_money": _base_money(rom, layout, trainer_class),
		"party": party,
	}


static func _party(rom: RomFile, layout: Dictionary, at: int, count: int, flags: int) -> Array:
	var stride: int = Gen3Layout.PARTY_STRIDES[flags]
	if at % 4 != 0 or not rom.in_bounds(at, count * stride):
		return []
	var out: Array = []
	for slot: int in count:
		var mon: Dictionary = _mon(rom, layout, at + slot * stride, flags)
		if mon.is_empty():
			return []
		out.append(mon)
	return out


static func _mon(rom: RomFile, layout: Dictionary, at: int, flags: int) -> Dictionary:
	var species: int = Gen3Layout.national_number(rom, layout, rom.u16le(at + 4))
	var level: int = rom.u8(at + 2)
	var iv: int = rom.u16le(at)
	var held: bool = (flags & Gen3Layout.PARTY_HELD_ITEM) != 0
	var item: int = rom.u16le(at + 6) if held else 0
	if species < 1 or species > Gen3Layout.NATIONAL_DEX_COUNT or level < 1 or level > 100 \
		or iv > 255 or item >= int(layout["item_count"]):
		return {}
	var moves: Array[int] = []
	if (flags & Gen3Layout.PARTY_CUSTOM_MOVES) != 0:
		for slot: int in 4:
			var move: int = rom.u16le(at + (8 if held else 6) + slot * 2)
			if move >= Gen3Layout.MOVES_COUNT:
				return {}
			moves.append(move)
	return {"species": species, "level": level, "iv": iv, "item": item, "moves": moves}


## Money tables end on class 0xff, whose value is the cartridge's fallback.
static func _base_money(rom: RomFile, layout: Dictionary, trainer_class: int) -> int:
	var at: int = int(layout["trainer_money"])
	for row: int in 256:
		if not rom.in_bounds(at + row * 2, 2):
			return -1
		var key: int = rom.u8(at + row * 2)
		if key == trainer_class or key == 0xFF:
			return rom.u8(at + row * 2 + 1)
	return -1


static func _verify_money(rom: RomFile, layout: Dictionary) -> Dictionary:
	var at: int = int(layout["trainer_money"])
	for row: int in 256:
		if not rom.in_bounds(at + row * 2, 2):
			return _fail("Trainer money table leaves the dump.")
		var key: int = rom.u8(at + row * 2)
		if key == 0xFF:
			return {"ok": true}
		if key >= int(layout["trainer_class_count"]):
			return _fail("Trainer money row %d names an invalid class." % row)
	return _fail("Trainer money table has no end.")


static func _coordinates(rom: RomFile, layout: Dictionary, picture: int) -> Dictionary:
	var at: int = int(layout["trainer_coords"]) + picture * 4
	return {"size": rom.u8(at), "y_offset": rom.u8(at + 1)}


static func _raw(rom: RomFile, layout: Dictionary, key: String, picture: int) -> PackedByteArray:
	var at: int = int(layout[key]) + picture * Gen3Layout.PIC_ENTRY_SIZE
	return GbaLz.decompress(rom.bytes(), Gen3Layout.rom_offset(rom.u32le(at)))


static func _palette(rom: RomFile, layout: Dictionary, picture: int) -> Array[int]:
	var raw: PackedByteArray = _raw(rom, layout, "trainer_palettes", picture)
	var out: Array[int] = []
	if raw.size() != Gen3Layout.PALETTE_BYTES:
		return out
	for at: int in range(0, raw.size(), 2):
		out.append(raw[at] | raw[at + 1] << 8)
	return out


static func palettes(rom: RomFile, layout: Dictionary) -> Array:
	var out: Array = []
	for picture: int in int(layout["trainer_pic_count"]):
		out.append(_palette(rom, layout, picture))
	return out


## Some sheets reserve two canvases but decompress to one (front_pic_tables).
static func _verify_pics(rom: RomFile, layout: Dictionary) -> Dictionary:
	var count: int = int(layout["trainer_pic_count"])
	if not rom.in_bounds(int(layout["trainer_coords"]), count * 4):
		return _fail("Trainer coordinates leave the dump.")
	for key: String in ["trainer_pics", "trainer_palettes"]:
		for picture: int in count:
			var at: int = int(layout[key]) + picture * Gen3Layout.PIC_ENTRY_SIZE
			var palette: bool = key == "trainer_palettes"
			var size: int = Gen3Layout.PALETTE_BYTES if palette else Gen3Layout.PIC_BYTES
			if not rom.in_bounds(at, Gen3Layout.PIC_ENTRY_SIZE) or rom.u16le(at + (4 if palette else 6)) != picture:
				return _fail("%s row %d has an invalid tag." % [key, picture])
			if _raw(rom, layout, key, picture).size() != size or not palette and not [size, size * 2].has(rom.u16le(at + 4)):
				return _fail("%s row %d has an invalid size." % [key, picture])
	return {"ok": true, "message": "Trainers verified."}


static func import_pics(rom: RomFile, layout: Dictionary, directory: String) -> Dictionary:
	var count: int = int(layout["trainer_pic_count"])
	var atlas: Dictionary = PokeTiles.new_atlas(Gen3Layout.PIC_TILES, count)
	for picture: int in count:
		var pixels: PackedByteArray = GbaTiles.decode(_raw(rom, layout, "trainer_pics", picture), 8, 8)
		PokeTiles.blit_pic(pixels, 8, atlas, picture)
	if not RomCache.write_indices(RomCache.pic_path(directory, "trainers"), atlas["pixels"]):
		return {}
	return PokeTiles.atlas_record(atlas)
