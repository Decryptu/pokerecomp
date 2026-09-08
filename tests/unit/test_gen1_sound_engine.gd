extends GutTest

## The Generation 1 driver's own decisions, watched through the registers it
## writes. Every fixture is a real channel stream: a header at `id * 3` from the
## table start, then commands from `macros/scripts/audio.asm`.

const ORIGIN: int = Gen1SoundEngine.HEADER_TABLE_ADDRESS
const BANK: int = 0x02
const MAX_SFX_ID: int = 100
const NR11: int = 0xFF11
const NR12: int = 0xFF12
const NR13: int = 0xFF13
const NR14: int = 0xFF14
const NR50: int = 0xFF24
const NR51: int = 0xFF25
## Where a fixture's streams are laid, clear of every header the tests define.
const STREAMS_AT: int = 0x200


## One bank, `{id: [[channel, [bytes]], ...]}`. $ff pads it, which is
## `sound_ret`, so an id no fixture defines stops on its first byte.
func _bank(sounds: Dictionary, max_sfx_id: int = MAX_SFX_ID) -> Dictionary:
	var bytes := PackedByteArray()
	bytes.resize(0x1000)
	bytes.fill(Gen1SoundEngine.SOUND_RET_CMD)
	var at: int = STREAMS_AT
	for id: int in sounds:
		var streams: Array = sounds[id]
		var header: int = id * Gen1SoundEngine.HEADER_ENTRY_SIZE
		for index: int in streams.size():
			var stream: Array = streams[index]
			var first: int = ((streams.size() - 1) << 6) | int(stream[0])
			bytes[header + index * 3] = first if index == 0 else int(stream[0])
			bytes[header + index * 3 + 1] = (ORIGIN + at) & 0xFF
			bytes[header + index * 3 + 2] = ((ORIGIN + at) >> 8) & 0xFF
			for value: int in stream[1] as Array:
				bytes[at] = value
				at += 1
	return {
		"bank": BANK, "bytes": bytes, "data_address": ORIGIN,
		"wave_pointers": ORIGIN + 0xF00, "max_sfx_id": max_sfx_id,
	}


func _engine(sounds: Dictionary, max_sfx_id: int = MAX_SFX_ID) -> Gen1SoundEngine:
	var engine := Gen1SoundEngine.new()
	engine.register_bank(_bank(sounds, max_sfx_id))
	engine.audio_rom_bank = BANK
	engine.apu.tracing = true
	return engine


## Register writes as `[frame, address, value]`, the traffic the request itself
## produced and not the power-on before it.
func _writes(engine: Gen1SoundEngine, frames: int) -> Array:
	engine.apu.trace_lines = PackedStringArray()
	var out: Array = []
	for frame: int in frames:
		engine.apu.trace_frame = frame
		engine.update_music()
	for line: String in engine.apu.trace_lines:
		var parts: PackedStringArray = line.split(" ")
		out.append([int(parts[0]), parts[1].hex_to_int(), parts[2].hex_to_int()])
	return out


func _values(writes: Array, address: int) -> Array:
	var out: Array = []
	for write: Array in writes:
		if int(write[1]) == address:
			out.append(int(write[2]))
	return out


func _stream_address(index: int) -> int:
	return ORIGIN + STREAMS_AT + index


func _frames_of(writes: Array, address: int) -> Array:
	var out: Array = []
	for write: Array in writes:
		if int(write[1]) == address:
			out.append(int(write[0]))
	return out


func test_a_header_hands_each_channel_its_own_stream() -> void:
	var engine: Gen1SoundEngine = _engine({200: [[0, [0xFF]], [1, [0xFF]]]})
	assert_true(engine.play_music(BANK, 200))
	assert_eq(engine.channel_sound_id(0), 200)
	assert_eq(engine.channel_sound_id(1), 200)
	assert_eq(engine.channel_sound_id(2), 0, "a channel the header misses is untouched")
	assert_eq(engine.channel_command_pointer(0), _stream_address(0))
	assert_eq(engine.channel_command_pointer(1), _stream_address(1))


## `.playSfx` against `.playMusic`: only an id above the bank's own MAX_SFX_ID
## clears the four music channels, which is why an effect plays over a piece.
func test_an_id_above_the_banks_max_sfx_id_is_the_only_one_that_clears_music() -> void:
	var engine: Gen1SoundEngine = _engine({
		200: [[0, [0xFF]]], 50: [[4, [0xFF]]], 201: [[0, [0xFF]]],
	})
	assert_true(engine.play_music(BANK, 200))
	engine.play_sound(50)
	assert_eq(engine.channel_sound_id(0), 200, "an effect leaves the music channel")
	assert_eq(engine.channel_sound_id(4), 50)
	engine.play_sound(201)
	assert_eq(engine.channel_sound_id(0), 201, "a second piece takes the music channel")


## `.playSfx` walks the header's channels and refuses the whole request while a
## lower-numbered effect still holds one of them.
func test_a_lower_numbered_effect_keeps_the_channel_it_holds() -> void:
	var engine: Gen1SoundEngine = _engine({40: [[4, [0xFF]]], 60: [[4, [0xFF]]]})
	engine.play_sound(40)
	engine.play_sound(60)
	assert_eq(engine.channel_sound_id(4), 40, "60 cannot take 40's channel")
	engine.play_sound(40)
	assert_eq(engine.channel_sound_id(4), 40)


## `Audio1_note_pitch` through `Audio1_CalculateFrequency`: octave 7 is the
## pitch table unshifted, so C_ is $F82C with 8 added to its high byte.
func test_a_note_writes_the_frequency_the_pitch_table_gives() -> void:
	var engine: Gen1SoundEngine = _engine({200: [[0, [
		0xD8, 0x00, 0xE7, 0x01, 0xFF,
	]]]})
	assert_true(engine.play_music(BANK, 200))
	var writes: Array = _writes(engine, 1)
	var value: int = Gen1SoundEngine.PITCHES[0] - 0x10000
	var low: int = value & 0xFF
	var high: int = ((((value >> 8) & 0xFF) + 8) & 0xFF)
	assert_eq(_values(writes, NR13), [low], "the low frequency byte")
	assert_eq(_values(writes, NR14), [(high | 0x80) & 0xC7], "the high byte with the restart")


## `Audio1_note_length`: the delay is note speed times length times tempo, and
## the note that follows is not read until it runs out.
func test_note_delay_is_speed_times_length_times_tempo() -> void:
	# note_type 8, octave 7, note C_ length 4 -> 8 * 4 * $100 >> 8 = 32 frames.
	var engine: Gen1SoundEngine = _engine({200: [[0, [
		0xD8, 0x00, 0xE7, 0x03, 0x03, 0xFF,
	]]]})
	assert_true(engine.play_music(BANK, 200))
	var writes: Array = _writes(engine, 40)
	assert_eq(_frames_of(writes, NR13), [0, 32], "the second note starts 32 frames on")


## `sound_loop` counts up to its operand and then steps past the address. The
## jump goes back onto the note itself, which is the stream's fourth byte.
func test_a_loop_runs_its_count_and_then_falls_through() -> void:
	var note: int = _stream_address(3)
	var engine: Gen1SoundEngine = _engine({200: [[0, [
		0xD8, 0x00, 0xE7,
		0x00,
		0xFE, 0x02, note & 0xFF, (note >> 8) & 0xFF,
		0xFF,
	]]]})
	assert_true(engine.play_music(BANK, 200))
	## Two notes of eight frames each, and the `sound_ret` behind them.
	var writes: Array = _writes(engine, 24)
	assert_eq(_values(writes, NR13).size(), 2, "the note plays twice and the loop ends")
	assert_eq(engine.channel_sound_id(0), 0, "the stream reaches its sound_ret")


## `sound_call` remembers the byte after its operand and `sound_ret` goes back to
## it rather than stopping the channel.
func test_sound_call_returns_to_the_byte_after_it() -> void:
	var call_target: int = _stream_address(8)
	var engine: Gen1SoundEngine = _engine({200: [[0, [
		0xD8, 0x00, 0xE7,
		0xFD, call_target & 0xFF, (call_target >> 8) & 0xFF,
		0x00,
		0xFF,
		0x00,
		0xFF,
	]]]})
	assert_true(engine.play_music(BANK, 200))
	var writes: Array = _writes(engine, 16)
	assert_eq(_values(writes, NR13).size(), 2, "the called note and the one after the return")


## A stream that jumps without ever reaching a note hangs the cartridge. Bounding
## the walk leaves a silent channel instead of a frozen frame.
func test_a_stream_that_never_reaches_a_note_stops_instead_of_hanging() -> void:
	var here: int = _stream_address(0)
	var engine: Gen1SoundEngine = _engine({200: [[0, [
		0xFE, 0x00, here & 0xFF, (here >> 8) & 0xFF,
	]]]})
	assert_true(engine.play_music(BANK, 200))
	engine.update_music()
	assert_eq(engine.channel_sound_id(0), 0, "the channel gives up rather than spinning")


## `FadeOutAudio` writes full volume on every frame nothing is fading, which is
## what BIT_NO_AUDIO_FADE_OUT exists to stop.
func test_the_fade_writes_full_volume_until_the_flag_stops_it() -> void:
	var engine: Gen1SoundEngine = _engine({200: [[0, [0xFF]]]})
	engine.apu.trace_lines = PackedStringArray()
	engine.fade_out_audio()
	assert_eq(_trace(engine, NR50), [Gen1SoundEngine.MAX_VOLUME])
	engine.no_audio_fade_out = true
	engine.apu.trace_lines = PackedStringArray()
	engine.fade_out_audio()
	assert_eq(_trace(engine, NR50), [], "the flag leaves the register alone")


func _trace(engine: Gen1SoundEngine, address: int) -> Array:
	var out: Array = []
	for line: String in engine.apu.trace_lines:
		var parts: PackedStringArray = line.split(" ")
		if parts[1].hex_to_int() == address:
			out.append(parts[2].hex_to_int())
	return out


## `PlaySound`'s `.fadeOut`: a frame count per volume step, and the queued id
## starts out of the bank it was queued with once the volume reaches zero.
func test_a_fade_that_reaches_zero_starts_the_queued_id() -> void:
	var engine: Gen1SoundEngine = _engine({200: [[0, [0xFF]]], 201: [[1, [0xFF]]]})
	assert_true(engine.play_music(BANK, 200))
	engine.start_fade(1, 201, BANK)
	for _frame: int in 64:
		engine.fade_out_audio()
	assert_eq(engine.fade_out_control, 0, "the fade finished")
	assert_eq(engine.channel_sound_id(1), 201, "the queued piece took over")


## `Audio1_ApplyMonoStereo`, which Yellow alone reads: the SOUND option offsets
## into four enable-mask rows and zero is the mono row every cartridge starts on.
func test_only_yellow_narrows_the_enable_mask_by_the_sound_option() -> void:
	var engine: Gen1SoundEngine = _engine({200: [[0, [
		0xD8, 0x00, 0xE7, 0x01, 0xFF,
	]]]})
	assert_true(engine.play_music(BANK, 200))
	assert_eq(_values(_writes(engine, 1), NR51), [Gen1SoundEngine.HW_ENABLE_MASK[0]])
	var yellow: Gen1SoundEngine = _engine({200: [[0, [
		0xD8, 0x00, 0xE7, 0x01, 0xFF,
	]]]})
	yellow.yellow = true
	yellow.mono_stereo_offset = 16
	assert_true(yellow.play_music(BANK, 200))
	assert_eq(
		_values(_writes(yellow, 1), NR51),
		[int(Gen1Layout.YELLOW_ENABLE_MASKS[16])], "the third row"
	)


## `PlaySound $ff` is `_InitSound`: every channel drops its id, so nothing the
## driver was playing survives it.
func test_the_stop_id_clears_every_channel() -> void:
	var engine: Gen1SoundEngine = _engine({200: [[0, [0xFF]]], 50: [[4, [0xFF]]]})
	assert_true(engine.play_music(BANK, 200))
	engine.play_sound(50)
	engine.play_sound(Gen1SoundEngine.SFX_STOP_ALL_MUSIC)
	for channel: int in Gen1SoundEngine.NUM_CHANNELS:
		assert_eq(engine.channel_sound_id(channel), 0, "channel %d" % channel)
	assert_false(engine.any_channel_active())
