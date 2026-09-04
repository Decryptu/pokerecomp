class_name RomImport
extends RefCounted

## Which importer reads a cartridge. The generations share the ROM layer, the
## cache and [GameData]; nothing else, because a Generation 1 table has neither
## the record sizes nor the banking of a Generation 2 one. Every caller goes
## through here rather than naming an importer, so a third generation is a row
## in this file and nothing in the launcher.

static func _generation(rom: RomFile) -> int:
	return RomRegistry.generation_for(rom.id)


## Sanity-checks the offset table against the cartridge before anything is
## decoded. Returns { ok, message }.
static func verify_layout(rom: RomFile) -> Dictionary:
	match _generation(rom):
		RomRegistry.GEN1:
			return Gen1Importer.verify_layout(rom)
		RomRegistry.GEN2:
			return RomImporter.verify_layout(rom)
	return {"ok": false, "message": "No importer for %s." % rom.id}


## Decodes the cartridge into its cache directory. Returns the importer's own
## { ok, message, ... }; only `ok` and `message` are common to both.
static func import_rom(
	rom: RomFile, on_progress: Callable = Callable(), yield_ms: int = 0
) -> Dictionary:
	match _generation(rom):
		RomRegistry.GEN1:
			return await Gen1Importer.new().import_rom(rom, on_progress, yield_ms)
		RomRegistry.GEN2:
			return await RomImporter.new().import_rom(rom, on_progress, yield_ms)
	return {"ok": false, "message": "No importer for %s." % rom.id}
