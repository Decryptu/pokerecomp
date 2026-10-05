extends RefCounted

## Every script `Gen1WorldImporter.decode_script` reads, with the importer's log
## on: a path reaching an unread instruction is dropped whole, and only the log says so.

## Rows that read to no node on purpose; none are left.
const EMPTY_ROWS: Dictionary = {&"red": [], &"blue": [], &"yellow": []}

## Instructions a walk passed over as free, by routine; `Gen1Layout.SCRIPT_SILENT_CALLS`
## says why each is. The one `DelayFrames` behind `HallOfFamePC` is `Gen1Credits`'.
const SILENT_RED_BLUE: Dictionary = {
	"auto_textbox_off": 5, "auto_textbox_on": 233, "celadon_elevator_warps": 1,
	"check_map_trainers": 3, "copy_data": 7, "count_set_bits": 3, "delay_frames": 1,
	"end_trainer_battle": 7, "get_sprite_position": 1, "init_battle_enemy": 15,
	"load_gym_names": 8, "load_screen_1": 1, "load_spinner_arrow_tiles": 2, "random": 2,
	"reload_map_data": 2, "rocket_elevator_warps": 1, "save_screen_1": 1, "save_screen_2": 1,
	"serial_connect": 12, "set_sprite_image": 2, "silph_elevator_warps": 1,
	"start_trainer_battle": 1, "update_sprites": 22, "wait_for_button": 2,
}
const SILENT_YELLOW: Dictionary = {
	"auto_textbox_off": 6, "auto_textbox_on": 236, "celadon_elevator_warps": 1,
	"check_map_trainers": 5, "copy_data": 6, "count_set_bits": 4, "delay_frames": 1,
	"end_trainer_battle": 6, "get_sprite_position": 1, "init_battle_enemy": 15,
	"load_current_map_view": 1, "load_gym_names": 8, "load_screen_1": 1, "load_screen_2": 4,
	"load_spinner_arrow_tiles": 2, "random": 3, "reload_map_data": 1,
	"reload_tileset_patterns": 4, "rocket_elevator_warps": 1, "save_screen_1": 1,
	"save_screen_2": 5, "serial_connect": 12, "set_sprite_image_2": 2, "silph_elevator_warps": 1,
	"start_trainer_battle": 1, "update_sprites": 34, "wait_for_button": 6,
}
const SILENT_SITES: Dictionary = {
	&"red": SILENT_RED_BLUE, &"blue": SILENT_RED_BLUE, &"yellow": SILENT_YELLOW,
}
## The instructions that became a wait or a fade, by routine.
const WAIT_RED_BLUE: Dictionary = {
	"delay_3": 43, "delay_frame": 3, "delay_frames": 13, "fade_in_black": 4, "fade_in_white": 3,
	"fade_out_black": 4, "fade_out_white": 3, "gb_pal_white_out_delay": 1, "load_gb_pal": 1,
	"restore_screen_tiles": 1, "set_sprite_facing_delay": 32,
}
const WAIT_YELLOW: Dictionary = {
	"delay_3": 65, "delay_frame": 3, "delay_frames": 27, "fade_in_black": 8, "fade_in_white": 3,
	"fade_out_black": 8, "fade_out_white": 3, "gb_pal_normal": 4, "gb_pal_white_out_delay": 7,
	"load_gb_pal": 2, "restore_screen_tiles": 6, "set_sprite_facing_delay": 30,
}
const WAIT_SITES: Dictionary = {
	&"red": WAIT_RED_BLUE, &"blue": WAIT_RED_BLUE, &"yellow": WAIT_YELLOW,
}

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
	Gen1WorldImporter.skipped = []
	Gen1WorldImporter.waited = []
	var world: Dictionary = Gen1WorldImporter.read_world(rom, layout)
	var entries: Array = Gen1WorldImporter.refusals
	var silent: Dictionary = _sites(Gen1WorldImporter.skipped)
	var waits: Dictionary = _sites(Gen1WorldImporter.waited)
	Gen1WorldImporter.refusals = null
	Gen1WorldImporter.skipped = null
	Gen1WorldImporter.waited = null
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
	_r.check(silent == SILENT_SITES[_r.game_id], "routines passed over as free: %s." % [silent])
	_r.check(waits == WAIT_SITES[_r.game_id], "routines that became waits: %s." % [waits])
	if _r.game_id == &"yellow":
		_jessie_and_james(world)
	_r.note("gen1 scripts read whole: %d empty, %d refused" % [empty.size(), refused.size()])


func _sites(entries: Array) -> Dictionary:
	var seen: Dictionary = {}
	for entry: Dictionary in entries:
		seen[[entry["routine"], entry["at"]]] = true
	var counts: Dictionary = {}
	for key: Array in seen:
		counts[key[0]] = int(counts.get(key[0], 0)) + 1
	return counts


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
