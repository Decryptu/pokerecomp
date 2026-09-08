extends RefCounted

var _r: RefCounted = null

## Verifies the Generation 1 sound driver against freshly imported real caches on
## all three cartridges. Every record every header table names is played, so a
## stream that never reaches a note is a failure rather than silence, and every
## number the rest of the tree spells a sound with is resolved: each map's own
## track and bank, every species cry, and both role tables.

## Enough frames for the slowest header to reach its first note and write a
## register. A stream writing nothing in this many never started.
const FRAMES: int = 24

var _engine: Gen1SoundEngine = null


func run(r: RefCounted) -> void:
	_r = r
	_r.each_game_of(RomRegistry.GEN1, func() -> void:
		_engine = Gen1SoundEngine.new()
		_engine.yellow = _r.game_id == RomRegistry.YELLOW
		_engine.apu.tracing = true
		_verify_the_banks()
		_verify_every_record_plays()
		_verify_every_map_track()
		_verify_every_cry()
		_verify_the_role_tables()
	)


## `SFX_Headers_1` to `_3`, and `_4` on Yellow: the cache carries a whole ROM
## bank each, and an unregistered one is every id in it gone.
func _verify_the_banks() -> void:
	var assets: Dictionary = _r.data.audio_assets()
	_engine.set_assets(assets)
	var wanted: int = Gen1Layout.audio_bank_count(_r.game_id)
	_r.check(_engine.registered_bank_count() == wanted,
		"the cache registers %d audio banks, not %d." % [
			_engine.registered_bank_count(), wanted,
		])
	for index: int in wanted:
		var bank: int = Gen1Layout.AUDIO_BANK_ROM[index]
		_r.check(_engine.bank_is_registered(bank), "audio bank $%02X is missing." % bank)


## Every id both header tables name, played through the driver. The counts are
## `Gen1Layout`'s own pins, so a table that walks short is caught before the
## records are.
func _verify_every_record_plays() -> void:
	var counts: Array[int] = Gen1Layout.audio_record_counts(_r.game_id)
	var wanted: int = 0
	for count: int in counts:
		wanted += count
	var music: Array = _r.data.gen1_audio_rows(&"music")
	var sfx: Array = _r.data.gen1_audio_rows(&"sfx")
	_r.check(music.size() + sfx.size() == wanted,
		"the cache holds %d records, not the %d the tables walk." % [
			music.size() + sfx.size(), wanted,
		])
	var silent: Array[String] = []
	for row: Dictionary in music:
		if not _plays(int(row["bank"]), int(row["index"]), true):
			silent.append("music $%02X:%d" % [int(row["bank"]), int(row["index"])])
	for row: Dictionary in sfx:
		if not _plays(int(row["bank"]), int(row["index"]), false):
			silent.append("sfx $%02X:%d" % [int(row["bank"]), int(row["index"])])
	_r.note("audio: %d music and %d effects over %d banks." % [
		music.size(), sfx.size(), counts.size(),
	])
	_r.check(silent.is_empty(), "%d records write no register: %s." % [
		silent.size(), ", ".join(silent.slice(0, 8)),
	])


## One record, from `PlaySound` to the registers it reaches. The stop in front is
## the sweep's own: `.playSfx` refuses a request while a lower-numbered effect
## still holds one of its channels, so a run in id order would report the
## cartridge's own priority as silence.
func _plays(bank: int, id: int, is_music: bool) -> bool:
	_engine.audio_rom_bank = bank
	_engine.play_sound(Gen1SoundEngine.SFX_STOP_ALL_MUSIC)
	_engine.apu.trace_lines = PackedStringArray()
	if is_music:
		if not _engine.play_music(bank, id):
			return false
	else:
		_engine.play_sound(id)
	if not _engine.any_channel_active():
		return false
	for _frame: int in FRAMES:
		_engine.update_music()
	return not _engine.apu.trace_lines.is_empty()


## `MapSongBanks` over the whole map list: two bytes a map, and a wrong second
## one is a piece playing out of the wrong copy of the driver.
func _verify_every_map_track() -> void:
	var missing: Array[String] = []
	var banks: Dictionary = {}
	for map: Gen2WorldMap in _r.data.world_maps():
		banks[map.music_bank] = int(banks.get(map.music_bank, 0)) + 1
		if _r.data.gen1_sound(map.music_bank, map.music).is_empty():
			missing.append("map %d wants $%02X:%d" % [map.number, map.music_bank, map.music])
	var rows: Array = banks.keys()
	rows.sort()
	_r.note("map music: %d maps over banks %s." % [_r.data.world_maps().size(), str(rows)])
	_r.check(missing.is_empty(), "%d maps name no record: %s." % [
		missing.size(), ", ".join(missing.slice(0, 8)),
	])
	for bank: int in rows:
		_r.check(Gen1Layout.AUDIO_BANK_ROM.has(bank),
			"a map names audio bank $%02X, which is not one of the driver's." % bank)


## `GetCryData`: every species reaches a cry, and the id it reaches is the one
## the three-channel stride puts it at.
func _verify_every_cry() -> void:
	var missing: Array[String] = []
	for number: int in range(1, Gen1Layout.SPECIES_COUNT + 1):
		var row: Dictionary = _r.data.mon_cry(number)
		if row.is_empty():
			missing.append("species %d has no cry row" % number)
			continue
		var record: Dictionary = _r.data.species_cry(number)
		var wanted: int = Gen1Layout.AUDIO_CRY_FIRST_ID + int(row["index"]) * 3
		if record.is_empty() or int(record.get("sound_id", -1)) != wanted:
			missing.append("species %d wants id %d" % [number, wanted])
	_r.note("cries: %d species over %d headers." % [
		Gen1Layout.SPECIES_COUNT, Gen1Layout.AUDIO_CRY_COUNT,
	])
	_r.check(missing.is_empty(), "%d cries do not resolve: %s." % [
		missing.size(), ", ".join(missing.slice(0, 8)),
	])


## The two tables that answer a Crystal number with a Generation 1 sound. Every
## row has to reach a record, since an unlisted number is what stands for "no
## screen here" and a listed one that resolves to nothing is silence in play.
func _verify_the_role_tables() -> void:
	for number: Variant in Gen1Layout.SFX_ROLES:
		var record: Dictionary = _r.data.world_audio(&"sfx", int(number))
		_r.check(not record.is_empty(),
			"SFX role $%02X resolves to nothing." % int(number))
	for track: Variant in Gen1Layout.MUSIC_ROLES:
		var role: Array = Gen1Layout.music_role(int(track))
		var record: Dictionary = _r.data.gen1_sound(int(role[0]), int(role[1]))
		_r.check(not record.is_empty(),
			"music role $%02X wants $%02X:%d, which is not in the cache." % [
				int(track), int(role[0]), int(role[1]),
			])
	_r.note("roles: %d effects and %d tracks." % [
		Gen1Layout.SFX_ROLES.size(), Gen1Layout.MUSIC_ROLES.size(),
	])
