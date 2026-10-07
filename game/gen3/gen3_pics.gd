class_name Gen3Pics
extends RefCounted

## pret's pokemon_graphics tables: CompressedSpriteSheet/Palette are eight bytes,
## MonCoords four. Every picture frame is an 8x8 tile canvas, regardless of coords.
const TABLES: Array[String] = ["front_pics", "back_pics", "normal_palettes", "shiny_palettes"]


static func verify(rom: RomFile, layout: Dictionary) -> Dictionary:
	for key: String in ["front_coords", "back_coords"]:
		if not rom.in_bounds(int(layout[key]), Gen3Layout.PIC_TABLE_COUNT * 4):
			return {"ok": false, "message": "%s is outside the dump." % key}
	for key: String in TABLES:
		for species: int in Gen3Layout.PIC_TABLE_COUNT:
			var at: int = int(layout[key]) + species * Gen3Layout.PIC_ENTRY_SIZE
			var is_palette: bool = key.ends_with("palettes")
			var tag: int = species + (Gen3Layout.SHINY_TAG_BASE if key == "shiny_palettes" else 0)
			if not rom.in_bounds(at, Gen3Layout.PIC_ENTRY_SIZE) \
				or rom.u16le(at + (4 if is_palette else 6)) != tag:
				return {"ok": false, "message": "%s row %d has the wrong tag." % [key, species]}
			var raw: PackedByteArray = read(rom, layout, key, species)
			var unit: int = Gen3Layout.PALETTE_BYTES if is_palette else Gen3Layout.PIC_BYTES
			var frames: int = 4 if species == Gen3Layout.CASTFORM else 1
			if not is_palette and (rom.id == RomRegistry.EMERALD and key == "front_pics" \
				or species == Gen3Layout.DEOXYS and rom.id in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN, RomRegistry.EMERALD]):
				frames = maxi(frames, 2)
			if raw.size() != unit * frames or not is_palette and rom.u16le(at + 4) != Gen3Layout.PIC_BYTES:
				return {"ok": false, "message": "%s row %d decodes to %d bytes." % [key, species, raw.size()]}
	return {"ok": true, "message": "Pictures verified."}


static func read(rom: RomFile, layout: Dictionary, key: String, species: int) -> PackedByteArray:
	var at: int = int(layout[key]) + species * Gen3Layout.PIC_ENTRY_SIZE
	return GbaLz.decompress(rom.bytes(), Gen3Layout.rom_offset(rom.u32le(at)))


static func palette(rom: RomFile, layout: Dictionary, species: int) -> Dictionary:
	var out: Dictionary = {}
	for kind: String in ["normal", "shiny"]:
		var raw: PackedByteArray = read(rom, layout, kind + "_palettes", species)
		var colors: Array[int] = []
		for at: int in range(0, raw.size(), 2):
			colors.append(raw[at] | raw[at + 1] << 8)
		out[kind] = colors
	return out


static func coordinates(rom: RomFile, layout: Dictionary, species: int) -> Dictionary:
	var out: Dictionary = {}
	for kind: String in ["front", "back"]:
		var at: int = int(layout[kind + "_coords"]) + species * 4
		var size: int = rom.u8(at)
		out[kind] = {"width": (size >> 4) * 8, "height": (size & 15) * 8, "y_offset": rom.u8(at + 1)}
	return out


static func import_pics(
	rom: RomFile, layout: Dictionary, directory: String, species: Array, progress: Callable
) -> Dictionary:
	var atlases: Dictionary = {}
	for kind: String in ["front", "back"]:
		for entry: Dictionary in species:
			var index: int = int(entry["index"])
			var count: int = _add_frames(rom, layout, atlases, kind, index, int(entry["number"]) - 1, species.size())
			entry.get_or_add("pic_frames", {})[kind] = count
			entry.get_or_add("pic_default_frames", {})[kind] = 1 if index == Gen3Layout.DEOXYS and count == 2 else 0
		for form: int in Gen3Layout.UNOWN_FORMS:
			var index: int = Gen3Layout.UNOWN_SPECIES if form == 0 else Gen3Layout.UNOWN_B + form - 1
			_add_frames(rom, layout, atlases, "unown_" + kind, index, form, Gen3Layout.UNOWN_FORMS)
		if progress.is_valid():
			progress.call(kind + " pictures", species.size(), species.size())
	var records: Dictionary = {}
	for name: String in atlases:
		if not RomCache.write_indices(RomCache.pic_path(directory, name), atlases[name]["pixels"]):
			return {}
		records[name] = PokeTiles.atlas_record(atlases[name])
	return records


static func _add_frames(
	rom: RomFile, layout: Dictionary, atlases: Dictionary, name: String, species: int, slot: int, cells: int
) -> int:
	var key: String = ("back" if name.ends_with("back") else "front") + "_pics"
	var raw: PackedByteArray = read(rom, layout, key, species)
	@warning_ignore("integer_division")
	var frames: int = raw.size() / Gen3Layout.PIC_BYTES
	for frame: int in frames:
		var atlas_name: String = name if frame == 0 else "%s_%d" % [name, frame]
		if not atlases.has(atlas_name):
			atlases[atlas_name] = PokeTiles.new_atlas(Gen3Layout.PIC_TILES, cells)
		var pixels: PackedByteArray = GbaTiles.decode(raw, 8, 8, frame * Gen3Layout.PIC_BYTES)
		PokeTiles.blit_pic(pixels, 8, atlases[atlas_name], slot)
	return frames
