class_name Gen3Importer
extends RefCounted

## Generation 3's importer: it checks the header against the registry row and
## decodes nothing yet, so a Generation 3 cartridge is recognised, never seated.

## The `GAME_CODE` and `GAME_REVISION` each pret Makefile hands `gbafix`.
const HEADERS: Dictionary = {
	RomRegistry.RUBY: ["AXVE", 2],
	RomRegistry.SAPPHIRE: ["AXPE", 2],
	RomRegistry.FIRERED: ["BPRE", 1],
	RomRegistry.LEAFGREEN: ["BPGE", 1],
	RomRegistry.EMERALD: ["BPEE", 0],
}


static func verify_layout(rom: RomFile) -> Dictionary:
	if not HEADERS.has(rom.id):
		return {"ok": false, "message": "No Generation 3 header for %s." % rom.id}
	var header: GbaHeader = GbaHeader.parse(rom)
	var wanted: Array = HEADERS[rom.id]
	if header.game_code != String(wanted[0]) or header.version != int(wanted[1]):
		return {"ok": false, "message": "%s claims to be %s revision %d, not %s revision %d." % [
			RomRegistry.title_for(rom.id), header.game_code, header.version,
			wanted[0], wanted[1],
		]}
	return {"ok": true, "message": "header %s revision %d" % [header.game_code, header.version]}


static func import_rom(rom: RomFile) -> Dictionary:
	return {
		"ok": false,
		"message": "%s is recognised; nothing past its header is decoded yet."
			% RomRegistry.title_for(rom.id),
	}
