extends RefCounted

## Every script `Gen1WorldImporter.decode_script` reads, with the importer's log
## on: a path reaching an unread instruction is dropped whole, and only the log says so.

## Rows that read to no node on purpose; none are left.
const EMPTY_ROWS: Dictionary = {&"red": [], &"blue": [], &"yellow": []}

## `RST $38` at the cartridge's first byte, which no script reads.
const UNREADABLE_AT: int = 0
const UNREADABLE_OP: int = 0xFF

var _r: RefCounted


func run(r: RefCounted) -> void:
	_r = r
	r.each_game_of(RomRegistry.GEN1, _one_game)


func _one_game() -> void:
	var rom: RomFile = RomFile.open_verified("res://roms/%s.gb" % _r.game_id)
	if rom == null:
		_r.fail("no verified dump to decode.")
		return
	var layout: Dictionary = Gen1Layout.for_id(rom.id)
	_control(rom, layout)
	Gen1WorldImporter.refusals = []
	var world: Dictionary = Gen1WorldImporter.read_world(rom, layout)
	var entries: Array = Gen1WorldImporter.refusals
	Gen1WorldImporter.refusals = null
	if not _r.check(bool(world.get("ok", false)), "the world does not decode."):
		return
	var refused: PackedStringArray = []
	var empty: PackedStringArray = []
	for entry: Dictionary in entries:
		var site: String = "%d/%s" % [entry["map"], entry["row"]]
		if int(entry["op"]) == Gen1WorldImporter.SCRIPT_EMPTY:
			empty.append(site)
		else:
			refused.append("%s at %X, opcode %02X" % [site, entry["at"], entry["op"]])
	empty.sort()
	_r.check(refused.is_empty(), "scripts dropped at an unread instruction: %s." % [
		"; ".join(refused),
	])
	_r.check(Array(empty) == EMPTY_ROWS[_r.game_id], "rows that read to nothing: %s." % [
		", ".join(empty),
	])
	if _r.game_id == &"yellow":
		_jessie_and_james(world)
	_r.note("gen1 scripts read whole: %d empty, %d refused" % [empty.size(), refused.size()])


## The log has to be able to say something, or an empty one proves nothing.
func _control(rom: RomFile, layout: Dictionary) -> void:
	Gen1WorldImporter.refusals = []
	Gen1WorldImporter.decode_script(rom, layout, 0, UNREADABLE_AT)
	var entries: Array = Gen1WorldImporter.refusals
	Gen1WorldImporter.refusals = null
	_r.check(entries.size() == 1 and int(entries[0]["op"]) == UNREADABLE_OP,
		"an unreadable opcode logs %s." % [entries])


func _jessie_and_james(world: Dictionary) -> void:
	for map: Dictionary in world["maps"]:
		if int(map["number"]) == 61:
			var script: Array = map["texts"][13]["script"]
			_r.check(script.size() == 2 and script[0]["op"] == "text"
				and script[1] == {"op": "delay", "frames": 64},
				"Mt Moon B2F's last Jessie and James line reads %s." % [script])
