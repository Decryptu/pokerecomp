class_name RomImport
extends RefCounted

## Which importer reads a cartridge. Every caller goes through here, so a
## generation is a row in this file and nothing in the launcher.

static func _generation(rom: RomFile) -> int:
	return RomRegistry.generation_for(rom.id)


## Checks the offset table against the cartridge before anything is decoded.
static func verify_layout(rom: RomFile) -> Dictionary:
	match _generation(rom):
		RomRegistry.GEN1:
			return Gen1Importer.verify_layout(rom)
		RomRegistry.GEN2:
			return RomImporter.verify_layout(rom)
		RomRegistry.GEN3:
			return Gen3Importer.verify_layout(rom)
	return {"ok": false, "message": "No importer for %s." % rom.id}


## The importer's own { ok, message, ... }; only `ok` and `message` are common.
static func import_rom(
	rom: RomFile, on_progress: Callable = Callable(), yield_ms: int = 0
) -> Dictionary:
	match _generation(rom):
		RomRegistry.GEN1:
			return await Gen1Importer.new().import_rom(rom, on_progress, yield_ms)
		RomRegistry.GEN2:
			return await RomImporter.new().import_rom(rom, on_progress, yield_ms)
		RomRegistry.GEN3:
			return Gen3Importer.import_rom(rom, on_progress)
	return {"ok": false, "message": "No importer for %s." % rom.id}


## Counts are each importer's own keys; a missing one is left out.
static func ready_message(result: Dictionary) -> String:
	var trainers: int = int(result.get("trainers", 0))
	if trainers == 0:
		return "%d species are ready." % int(result.get("species", 0))
	return "%d species and %d trainer classes are ready." % [
		int(result.get("species", 0)), trainers,
	]


static func describe_header(rom: RomFile) -> PackedStringArray:
	if _generation(rom) == RomRegistry.GEN3:
		var gba: GbaHeader = GbaHeader.parse(rom)
		return PackedStringArray([gba.describe(), "header complement %s" % (
			"ok" if gba.complement == GbaHeader.compute_complement(rom) else "MISMATCH"
		)])
	var header: RomHeader = RomHeader.parse(rom)
	return PackedStringArray([header.describe(), "header checksum %s" % (
		"ok" if header.header_checksum == RomHeader.compute_header_checksum(rom) else "MISMATCH"
	)])
