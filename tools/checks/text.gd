extends RefCounted

var _r: RefCounted = null

## Every box a mod can rewrite, against freshly imported real caches, on all
## three cartridges. ADDRESSABILITY is the point: a translation is possible only
## if every box has a name a mod reaches it by, so the sweep names each one,
## rewrites it through an overlay of its own and reads it back.

## Per game: named boxes, map dialogues, and the empty `text`/`done` ones.
const EXPECTED_CENSUS: Dictionary = {
	&"gold": [166, 3004, 0],
	&"silver": [166, 3004, 0],
	&"crystal": [198, 3946, 1],
}

## A world line names the player, so a replacement has to be able to.
const REPLACEMENT: String = "<PLAYER> DIT BONJOUR."


func run(r: RefCounted) -> void:
	_r = r
	_r.each_game(func() -> void:
		var named: int = _verify_every_named_box_reads_back()
		var world: Array = _verify_every_map_dialogue_reads_back()
		_r.note("%d named boxes over %d runs, %d map dialogues, %d of them empty." % [
			named, _r.data.text_runs().size(), world[0], world[1],
		])
		var found: Array = [named, world[0], world[1]]
		_r.check(
			found == EXPECTED_CENSUS[_r.game_id],
			"census is %s, not the pinned %s." % [
				str(found), str(EXPECTED_CENSUS[_r.game_id]),
			]
		)
	)


func _verify_every_named_box_reads_back() -> int:
	var seen: int = 0
	var overlay := Gen2TextOverlay.new()
	_r.data.set_text_overlay(overlay)
	for text_run: StringName in _r.data.text_runs():
		for name: String in _r.data.text_names(text_run):
			seen += 1
			if not _r.check(
				not _r.data.text(text_run, name).is_empty(),
				"%s/%s is named but says nothing." % [text_run, name],
			):
				continue
			overlay.patch(text_run, name, &"check", REPLACEMENT)
			_r.check(
				_r.data.text(text_run, name) == REPLACEMENT,
				"%s/%s does not read back what a mod wrote." % [text_run, name],
			)
	_r.data.set_text_overlay(null)
	return seen


## The same over the map dialogue, whose replacement comes back with the
## print-time codes filled.
func _verify_every_map_dialogue_reads_back() -> Array:
	var seen: int = 0
	var empty: int = 0
	var overlay := Gen2TextOverlay.new()
	_r.data.set_text_overlay(overlay)
	for name: String in _r.data.world_text_names():
		var parts: PackedStringArray = name.split(":")
		if parts.size() != 2:
			_r.check(false, "%s is not a pointer key." % name)
			continue
		seen += 1
		var bank: int = parts[0].to_int()
		var address: int = parts[1].hex_to_int()
		overlay.patch(Gen2TextOverlay.RUN_WORLD, name, &"check", REPLACEMENT)
		var shown: Dictionary = _r.data.world_text_string(bank, address, {"player": "GOLD"})
		if not bool(shown.get("ok", false)):
			continue
		if Gen2WorldScript.decode_text(_r.data.world_text(bank, address)).get("text", "") == "":
			empty += 1
			continue
		_r.check(
			String(shown.get("text", "")) == "GOLD DIT BONJOUR.",
			"%s does not read back what a mod wrote, with its name filled." % name,
		)
	_r.data.set_text_overlay(null)
	return [seen, empty]
