extends SceneTree

## Renders one imported audio record through the sound engine and the APU, and
## writes a WAV plus the per-frame register trace beside it. The trace is the
## parity artefact: a faithful implementation of the driver writes the same
## registers in the same order on the same frames. Kinds are `music`, `sfx`,
## `stereo_sfx`, `cry` and `mon_cry`; the id is the record index, the species for
## `mon_cry`, `<bank>:<id>` on a Generation 1 cache, or `all`. Last is the panning.
##   ... -s res://tools/render_audio.gd -- crystal music 1 600 /tmp/out
##   ... -s res://tools/render_audio.gd -- red music 2:186 600 /tmp/out


func _initialize() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() < 5:
		printerr("usage: render_audio.gd -- <game> <music|sfx|stereo_sfx|cry> <id|bank:id|all> <frames> <out-prefix> [stereo] [panning]")
		quit(1)
		return
	var game: StringName = StringName(arguments[0])
	var kind: StringName = StringName(arguments[1])
	var frames: int = int(arguments[3])
	var prefix: String = arguments[4]
	if PokeToolPath.refuses(prefix):
		quit(2)
		return
	var stereo: bool = arguments.size() > 5 and arguments[5] == "1"
	var panning: int = int(arguments[6]) if arguments.size() > 6 else 0

	var data: GameData = GameData.open(game)
	if data == null:
		printerr("No imported cache for %s. Run tools/import_rom.gd first." % game)
		quit(1)
		return

	var assets: Dictionary = data.audio_assets()
	if arguments[2] == "all":
		quit(_sweep(data, kind, assets, frames, stereo, panning, prefix))
		return

	var entry: Dictionary = _record(data, kind, arguments[2])
	if entry.is_empty():
		printerr("No %s entry %s in the %s cache." % [kind, arguments[2], game])
		quit(1)
		return
	_report(kind, arguments[2], entry)
	if not _render(entry, kind, assets, frames, stereo, panning, prefix):
		quit(1)
		return
	print("%s.wav: %d frames" % [prefix, frames])
	quit(0)


## Every record the cache holds of that kind. A Generation 1 sweep is named by
## bank and id, so a file per record keeps the two spaces apart.
func _sweep(
	data: GameData, kind: StringName, assets: Dictionary, frames: int,
	stereo: bool, panning: int, prefix: String
) -> int:
	if data.generation == RomRegistry.GEN1:
		return _sweep_gen1(data, kind, assets, frames, prefix)
	var index: int = 1 if kind == &"mon_cry" else 0
	while true:
		var swept: Dictionary = _record(data, kind, str(index))
		if swept.is_empty():
			break
		_report(kind, str(index), swept)
		if not _render(swept, kind, assets, frames, stereo, panning, "%s_%d" % [prefix, index]):
			return 1
		index += 1
	print("Rendered %s records up to %d into %s_*" % [kind, index - 1, prefix])
	return 0


func _sweep_gen1(
	data: GameData, kind: StringName, assets: Dictionary, frames: int, prefix: String
) -> int:
	var rows: Array = data.gen1_audio_rows(&"sfx" if kind != &"music" else &"music")
	for row: Dictionary in rows:
		var record: Dictionary = data.gen1_sound(int(row["bank"]), int(row["index"]))
		var name: String = "%s_%02X_%d" % [prefix, int(row["bank"]), int(row["index"])]
		if not _render(record, kind, assets, frames, false, 0, name):
			return 1
	print("Rendered %d %s records into %s_*" % [rows.size(), kind, prefix])
	return 0


func _record(data: GameData, kind: StringName, id: String) -> Dictionary:
	if kind == &"mon_cry":
		return data.species_cry(int(id))
	if data.generation == RomRegistry.GEN1:
		var parts: PackedStringArray = id.split(":")
		if parts.size() != 2:
			return {}
		return data.gen1_sound(int(parts[0]), int(parts[1]))
	return data.world_audio(_table(kind), int(id))


## `mon_cry` resolves through the cry table, so the parameters it picked are
## worth printing: a parity run has to hand the same two to the other side.
func _report(kind: StringName, id: String, entry: Dictionary) -> void:
	if kind != &"mon_cry":
		return
	print("species %s: cry index %d pitch %d length %d" % [
		id, int(entry.get("sound_id", entry.get("index", -1))),
		int(entry.get("cry_pitch", 0)), int(entry.get("cry_length", 0)),
	])


func _render(
	entry: Dictionary, kind: StringName, assets: Dictionary, frames: int,
	stereo: bool, panning: int, prefix: String
) -> bool:
	var result: Dictionary = PokeAudioRender.render(
		entry, kind, assets, frames, stereo, true, panning
	)
	if not bool(result.get("ok", false)):
		printerr("Render failed: %s" % result.get("reason", "unknown"))
		return false
	if not PokeAudioRender.write_wav(prefix + ".wav", result["pcm"]):
		printerr("Cannot write %s.wav" % prefix)
		return false
	var trace := FileAccess.open(prefix + ".trace", FileAccess.WRITE)
	if trace == null:
		printerr("Cannot write %s.trace" % prefix)
		return false
	trace.store_string(result["trace"])
	trace.close()
	return true


func _table(kind: StringName) -> StringName:
	if kind == &"cry" or kind == &"cries" or kind == &"mon_cry":
		return &"cries"
	if kind == &"sfx" or kind == &"sound" or kind == &"stereo_sfx":
		return &"sfx"
	return &"music"
