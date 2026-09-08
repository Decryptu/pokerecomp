class_name PokeAudioRender
extends RefCounted

## Offline render of one audio record: run the driver for a fixed number of
## frames and keep the samples. Used by the parity tool and by tests; live
## playback drives [Gen2SoundEngine] and [PokeApu] directly.


## Returns `pcm` as interleaved 16-bit stereo, and `trace` as the driver's
## hardware-register writes when `trace` is asked for.
static func render(
	record: Dictionary,
	kind: StringName,
	assets: Dictionary,
	frames: int,
	stereo: bool = false,
	trace: bool = false,
	panning: int = 0,
) -> Dictionary:
	if record.is_empty():
		return {"ok": false, "reason": &"audio_data_unavailable"}
	if int(assets.get("generation", RomRegistry.GEN2)) == RomRegistry.GEN1:
		return render_gen1(record, assets, frames, trace)
	var apu := PokeApu.new()
	var engine := Gen2SoundEngine.new(apu)
	engine.stereo = stereo
	engine.set_assets(assets)
	apu.tracing = trace
	engine.init_sound()
	var started: bool = false
	match kind:
		&"cry", &"cries", &"mon_cry":
			started = engine.play_cry(record)
		&"sfx", &"sound":
			started = engine.play_sfx(record)
		&"stereo_sfx":
			engine.stereo_panning_mask = panning
			started = engine.play_stereo_sfx(record)
		_:
			started = engine.play_music(record)
	if not started:
		return {"ok": false, "reason": &"audio_record_unplayable"}

	var pcm := PackedInt32Array()
	pcm.resize(maxi(frames, 1) * PokeApu.SAMPLES_PER_FRAME * 2)
	var cursor: int = 0
	for frame: int in maxi(frames, 1):
		apu.trace_frame = frame
		engine.update_sound()
		var block: PackedInt32Array = apu.render_frame_pcm()
		for index: int in block.size():
			pcm[cursor + index] = block[index]
		cursor += block.size()
	return {
		"ok": true,
		"pcm": pcm,
		"trace": "\n".join(apu.trace_lines) + "\n" if trace else "",
		"frames": maxi(frames, 1),
	}


## The same render for a Generation 1 record. `PlaySound $ff` runs first so both
## sides of a parity diff start from the same registers and the same channel
## block, and the trace is the engine bank's writes alone: `FadeOutAudio` is
## VBlank's, one bank away, and belongs to the live path rather than to this one.
static func render_gen1(
	record: Dictionary, assets: Dictionary, frames: int, trace: bool = false
) -> Dictionary:
	var apu := PokeApu.new()
	var engine := Gen1SoundEngine.new(apu)
	engine.yellow = bool(assets.get("yellow", false))
	engine.set_assets(assets)
	var bank: int = int(record.get("bank", -1))
	var id: int = int(record.get("sound_id", -1))
	if bank <= 0:
		bank = Gen1Layout.AUDIO_BANK_ROM[0]
	if not engine.bank_is_registered(bank) or id <= 0:
		return {"ok": false, "reason": &"audio_record_unplayable"}
	engine.audio_rom_bank = bank
	engine.play_sound(Gen1SoundEngine.SFX_STOP_ALL_MUSIC)
	engine.frequency_modifier = int(record.get("cry_pitch", 0)) & 0xFF
	engine.tempo_modifier = int(record.get("cry_length", 0x80)) & 0xFF
	apu.tracing = trace
	engine.play_sound(id)
	var pcm := PackedInt32Array()
	pcm.resize(maxi(frames, 1) * PokeApu.SAMPLES_PER_FRAME * 2)
	var cursor: int = 0
	for frame: int in maxi(frames, 1):
		apu.trace_frame = frame
		engine.update_music()
		var block: PackedInt32Array = apu.render_frame_pcm()
		for index: int in block.size():
			pcm[cursor + index] = block[index]
		cursor += block.size()
	return {
		"ok": true,
		"pcm": pcm,
		"trace": "\n".join(apu.trace_lines) + "\n" if trace else "",
		"frames": maxi(frames, 1),
	}


## Writes interleaved 16-bit stereo as a RIFF/WAVE file.
static func write_wav(path: String, pcm: PackedInt32Array) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	var data_bytes: int = pcm.size() * 2
	file.store_buffer("RIFF".to_ascii_buffer())
	file.store_32(36 + data_bytes)
	file.store_buffer("WAVE".to_ascii_buffer())
	file.store_buffer("fmt ".to_ascii_buffer())
	file.store_32(16)
	file.store_16(1)
	file.store_16(2)
	file.store_32(PokeApu.SAMPLE_RATE)
	file.store_32(PokeApu.SAMPLE_RATE * 4)
	file.store_16(4)
	file.store_16(16)
	file.store_buffer("data".to_ascii_buffer())
	file.store_32(data_bytes)
	var samples := PackedByteArray()
	samples.resize(data_bytes)
	for index: int in pcm.size():
		var value: int = clampi(pcm[index], -32768, 32767) & 0xFFFF
		samples[index * 2] = value & 0xFF
		samples[index * 2 + 1] = (value >> 8) & 0xFF
	file.store_buffer(samples)
	file.close()
	return true
