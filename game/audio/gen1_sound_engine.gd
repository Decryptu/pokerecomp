class_name Gen1SoundEngine
extends RefCounted

## The Generation 1 sound driver, ported from `audio/engine_1.asm`.
##
## [method update_music] is one `Audio1_UpdateMusic`, run once per LCD frame: it
## walks each of the eight channel streams and writes the hardware registers, and
## [PokeApu] turns those writes into samples. The three near-identical copies of
## the driver differ only in what [member audio_rom_bank] selects, so one port
## carries all of them and reads that bank's own header table, effects, wave
## instruments and music.

const NUM_CHANNELS: int = 8
const NUM_MUSIC_CHANS: int = 4
const CHAN3: int = 2
const CHAN4: int = 3
const CHAN5: int = 4
const CHAN7: int = 6
const CHAN8: int = 7

## The two sixteen-bit tables, as bases into [member _pointers].
const CMD_POINTERS: int = 0
const RETURN_ADDRESSES: int = 8

## `wram.asm`'s per-channel arrays after those two tables, in address order, as
## bases into [member _wram]. `.stopAllAudio`'s flat fill walks exactly this.
const SOUND_IDS: int = 0
const FLAGS1: int = 8
const FLAGS2: int = 16
const DUTY_CYCLES: int = 24
const DUTY_CYCLE_PATTERNS: int = 32
const VIBRATO_DELAY: int = 40
const VIBRATO_EXTENTS: int = 48
const VIBRATO_RATES: int = 56
const FREQUENCY_LOW: int = 64
const VIBRATO_RELOAD: int = 72
const SLIDE_LENGTH_MOD: int = 80
const SLIDE_STEPS: int = 88
const SLIDE_STEPS_FRACTION: int = 96
const SLIDE_CURRENT_FRACTION: int = 104
const SLIDE_CURRENT_HIGH: int = 112
const SLIDE_CURRENT_LOW: int = 120
const SLIDE_TARGET_HIGH: int = 128
const SLIDE_TARGET_LOW: int = 136
const NOTE_DELAY: int = 144
const LOOP_COUNTERS: int = 152
const NOTE_SPEEDS: int = 160
const NOTE_DELAY_FRACTION: int = 168
const OCTAVES: int = 176
const VOLUMES: int = 184
const WRAM_SLOTS: int = 192
## Where the pointer tables end, so the two flat fills below count in bytes.
const POINTER_BYTES: int = 32

const BIT_PERFECT_PITCH: int = 1 << 0
const BIT_SOUND_CALL: int = 1 << 1
const BIT_NOISE_OR_SFX: int = 1 << 2
const BIT_VIBRATO_DIRECTION: int = 1 << 3
const BIT_PITCH_SLIDE_ON: int = 1 << 4
const BIT_PITCH_SLIDE_DECREASING: int = 1 << 5
const BIT_ROTATE_DUTY_CYCLE: int = 1 << 6
const BIT_EXECUTE_MUSIC: int = 1 << 0
const BIT_MUTE_AUDIO: int = 1 << 7
const BIT_LOW_HEALTH_ALARM: int = 1 << 7
const LOW_HEALTH_TIMER_MASK: int = 0x7F
const DISABLE_LOW_HEALTH_ALARM: int = 0xFF

const SOUND_RET_CMD: int = 0xFF
const SOUND_CALL_CMD: int = 0xFD
const SOUND_LOOP_CMD: int = 0xFE
const NOTE_TYPE_CMD: int = 0xD0
const OCTAVE_CMD: int = 0xE0
const SFX_NOTE_CMD: int = 0x20
const PITCH_SWEEP_CMD: int = 0x10
const PITCH_SLIDE_CMD: int = 0xEB
const DRUM_NOTE_CMD: int = 0xB0
const REST_CMD: int = 0xC0

## The commands that take no time, keyed by the whole byte. `Audio1_octave` takes
## what is left of $e0 to $ef and `Audio1_note` everything else.
const COMMANDS: Dictionary = {
	0xE8: &"_toggle_perfect_pitch",
	0xEA: &"_vibrato",
	0xEC: &"_duty_cycle",
	0xED: &"_tempo",
	0xEE: &"_stereo_panning",
	0xEF: &"_unknown_ef",
	0xF0: &"_volume",
	0xF8: &"_execute_music",
	0xFC: &"_duty_cycle_pattern",
}

const SFX_STOP_ALL_MUSIC: int = 0xFF
## `music_const` numbering, the same on all three cartridges: ids below
## [constant NOISE_INSTRUMENTS_END] are the nineteen drum instruments, and a cry
## runs from [constant CRY_SFX_START] to one below [constant CRY_SFX_END].
const NOISE_INSTRUMENTS_END: int = 20
const CRY_SFX_START: int = 20
const CRY_SFX_END: int = 134
const BATTLE_SFX_START: int = 157
const BATTLE_SFX_END: int = 234
## Each audio bank opens with its own header table, three bytes per id, whose
## first entry is $ff $ff $ff padding.
const HEADER_TABLE_ADDRESS: int = 0x4000
const HEADER_ENTRY_SIZE: int = 3

const REG_DUTY_SOUND_LEN: int = 1
const REG_VOLUME_ENVELOPE: int = 2
const REG_FREQUENCY_LO: int = 3
## `Audio1_HWChannelBaseAddresses`: channels 2 and 4 are pinned one below their
## length register, so [constant REG_DUTY_SOUND_LEN] lands on it.
const HW_CHANNEL_BASE: Array[int] = [0x10, 0x15, 0x1A, 0x1F, 0x10, 0x15, 0x1A, 0x1F]
const HW_ENABLE_MASK: Array[int] = [0x11, 0x22, 0x44, 0x88, 0x11, 0x22, 0x44, 0x88]

const RAUDVOL: int = 0xFF24
const RAUDTERM: int = 0xFF25
const RAUDENA: int = 0xFF26
const RAUD1SWEEP: int = 0xFF10
const RAUD3ENA: int = 0xFF1A
const RAUD3LEVEL: int = 0xFF1C
const AUD3ENA_ON: int = 0x80
const AUD1SWEEP_DOWN: int = 0x08
const AUD1HIGH_LENGTH_ON: int = 0x40
const WAVE_RAM: int = 0xFF30
const WAVE_RAM_SIZE: int = 16
const MAX_VOLUME: int = 0x77
const DEFAULT_TEMPO: int = 0x100

## `audio/notes.asm`, read rather than derived: `Audio1_CalculateFrequency`
## shifts these arithmetically, so every entry keeps its top bit.
const PITCHES: Array[int] = [
	0xF82C, 0xF89D, 0xF907, 0xF96B, 0xF9CA, 0xFA23,
	0xFA77, 0xFAC7, 0xFB12, 0xFB58, 0xFB9B, 0xFBDA,
]

## A stream that jumps without reaching a note hangs the cartridge; bounding the
## walk leaves a silent channel instead of a frozen game.
const MAX_PARSE_STEPS: int = 4096

var apu: PokeApu = null

## Listening levels, 1.0 being the cartridge's own output. They weigh the mix
## only, so a register trace reads the same whatever these are set to.
var music_gain: float = 1.0
var sfx_gain: float = 1.0

## `wAudioROMBank`: which copy of the driver is running, and so which header
## table, effect data and wave instruments an id names.
var audio_rom_bank: int = 0

var music_wave_instrument: int = 0
var sfx_wave_instrument: int = 0
var music_tempo: int = DEFAULT_TEMPO
var sfx_tempo: int = DEFAULT_TEMPO
var stereo_panning: int = 0xFF
var sound_id: int = 0
var saved_volume: int = 0
var disable_channel_output_when_sfx_ends: int = 0
var mute_audio_and_pause_music: int = 0
var unused_music_byte: int = 0
var frequency_modifier: int = 0
var tempo_modifier: int = 0x80
var low_health_alarm: int = 0

## `wAudioFadeOutControl` and the two counters `FadeOutAudio` runs off.
var fade_out_control: int = 0
var fade_out_counter: int = 0
var fade_out_reload: int = 0
var saved_rom_bank: int = 0
## `wStatusFlags2`'s BIT_NO_AUDIO_FADE_OUT, the one thing that stops
## `FadeOutAudio` writing full volume on a frame nothing is fading.
var no_audio_fade_out: bool = false

## `wOptions & SOUND_MASK` shifted right once, which is what only Yellow reads:
## it offsets straight into `Audio1_ApplyMonoStereo`'s four enable-mask rows, and
## zero is MONO, the setting a cartridge starts on.
var mono_stereo_offset: int = 0
var yellow: bool = false

var _pointers := PackedInt32Array()
var _wram := PackedInt32Array()
var _banks: Dictionary = {}


func _init(shared_apu: PokeApu = null) -> void:
	apu = shared_apu if shared_apu != null else PokeApu.new()
	_pointers.resize(NUM_CHANNELS * 2)
	_wram.resize(WRAM_SLOTS)


## `wChannelSoundIDs`, which is what says a channel is playing anything.
func channel_sound_id(channel: int) -> int:
	return _wram[SOUND_IDS + channel]


func channel_command_pointer(channel: int) -> int:
	return _pointers[CMD_POINTERS + channel]


## The audio banks as [Gen1Importer] wrote them: a whole ROM bank each, with its
## own header table, effects, wave instruments and music.
func set_assets(assets: Dictionary) -> void:
	var banks: Variant = assets.get("audio_banks", [])
	if not banks is Array:
		return
	for entry: Variant in banks as Array:
		if entry is Dictionary:
			register_bank(entry as Dictionary)


func register_bank(entry: Dictionary) -> bool:
	var bank: int = int(entry.get("bank", -1))
	if bank < 0:
		return false
	if _banks.has(bank):
		return true
	var bytes: PackedByteArray = _to_bytes(entry.get("bytes", []))
	if bytes.is_empty():
		return false
	_banks[bank] = {
		"bytes": bytes,
		"origin": int(entry.get("data_address", HEADER_TABLE_ADDRESS)),
		"wave_pointers": int(entry.get("wave_pointers", 0)),
		"max_sfx_id": int(entry.get("max_sfx_id", 0xFD)),
	}
	if audio_rom_bank == 0:
		audio_rom_bank = bank
	return true


func registered_bank_count() -> int:
	return _banks.size()


func bank_is_registered(bank: int) -> bool:
	return _banks.has(bank)



## `PlayMusic`: the bank is chosen first, then the id runs through `PlaySound`.
func play_music(bank: int, id: int) -> bool:
	if not _banks.has(bank):
		return false
	fade_out_control = 0
	audio_rom_bank = bank
	saved_rom_bank = bank
	play_sound(id)
	return true


## `Audio<N>_PlaySound` for whichever copy of the driver [member audio_rom_bank]
## names. An id above that bank's own `MAX_SFX_ID` is a piece of music and clears
## the four music channels first; anything at or below it is an effect.
func play_sound(id: int) -> void:
	if not _banks.has(audio_rom_bank):
		return
	sound_id = id & 0xFF
	if sound_id == SFX_STOP_ALL_MUSIC:
		_stop_all_audio()
		return
	if sound_id > _max_sfx_id():
		_init_music_variables()
	elif not _claim_sfx_channels():
		return
	_play_sound_common()


## `.playSfx`'s channel loop, which walks the header's channels from the last to
## the first and is also the gate that refuses a request while a higher-priority
## effect holds one. False is its own `ret`, which drops the whole request with
## the channels it has already cleared left cleared.
func _claim_sfx_channels() -> bool:
	var header: int = _header_address(sound_id)
	var index: int = (_bank_byte(audio_rom_bank, header) >> 6) & 0x03
	while true:
		var entry: int = header + index * HEADER_ENTRY_SIZE
		var channel: int = _bank_byte(audio_rom_bank, entry) & 0x0F
		var existing: int = _wram[SOUND_IDS + channel]
		if existing != 0 and not _sfx_may_take_channel(channel, existing):
			return false
		_init_sfx_variables(channel)
		if index == 0:
			return true
		index -= 1
	return true


## A noise instrument never interrupts a busy noise channel, and nothing else
## interrupts a lower-numbered effect.
func _sfx_may_take_channel(channel: int, existing: int) -> bool:
	if channel != CHAN8:
		return sound_id <= existing
	if sound_id < NOISE_INSTRUMENTS_END:
		return false
	return existing <= NOISE_INSTRUMENTS_END or sound_id <= existing


## `.playSoundCommon`: the header's channel pointers into `wChannelCommandPointers`,
## then the four sound ids and the wave-channel rewrite a cry gets.
func _play_sound_common() -> void:
	var header: int = _header_address(sound_id)
	var count: int = ((_bank_byte(audio_rom_bank, header) >> 6) & 0x03) + 1
	for index: int in count:
		var entry: int = header + index * HEADER_ENTRY_SIZE
		var channel: int = _bank_byte(audio_rom_bank, entry) & 0x0F
		_pointers[CMD_POINTERS + channel] = _bank_byte(audio_rom_bank, entry + 1) \
			| (_bank_byte(audio_rom_bank, entry + 2) << 8)
		_wram[SOUND_IDS + channel] = sound_id
		if channel >= CHAN4:
			_wram[FLAGS1 + channel] |= BIT_NOISE_OR_SFX
	if not _is_cry_id(sound_id):
		return
	for channel: int in range(CHAN5, NUM_CHANNELS):
		_wram[SOUND_IDS + channel] = sound_id
	_pointers[CMD_POINTERS + CHAN7] = _cry_ret_address()
	if saved_volume != 0:
		return
	saved_volume = apu.read(RAUDVOL)
	apu.write(RAUDVOL, MAX_VOLUME)


## `Audio<N>_CryRet` is one `sound_ret` byte, and the pointer at it is only ever
## read and rewound onto itself, so the header table's own $ff padding answers
## for it without a fourth symbol to pin per bank.
func _cry_ret_address() -> int:
	return HEADER_TABLE_ADDRESS + 1


func _is_cry_id(id: int) -> bool:
	return id >= CRY_SFX_START and id < CRY_SFX_END


## `Audio2_IsBattleSFX`, which only the battle copy of the driver has: the two
## effect sound ids are read as one OR. Yellow's copy takes the closing id in as
## well, where Red and Blue's stops one below it.
func _battle_sfx_applies() -> bool:
	if audio_rom_bank != Gen1Layout.AUDIO_BANK_ROM[1]:
		return false
	var combined: int = _wram[SOUND_IDS + CHAN5] | _wram[SOUND_IDS + CHAN8]
	if combined < BATTLE_SFX_START:
		return false
	return combined <= BATTLE_SFX_END if yellow else combined < BATTLE_SFX_END


## A cry, or a battle effect in the copy of the driver that knows about them.
func _cry_or_battle_sfx() -> bool:
	return _is_cry_id(_wram[SOUND_IDS + CHAN5]) or _battle_sfx_applies()


func _max_sfx_id() -> int:
	return int((_banks[audio_rom_bank] as Dictionary)["max_sfx_id"])


func _header_address(id: int) -> int:
	return HEADER_TABLE_ADDRESS + id * HEADER_ENTRY_SIZE


## `.playMusic`'s own clear, which reaches the four music channels alone so an
## effect on the other four keeps playing over the new piece. The note-delay
## fractions, the octaves and the volumes are not in it.
func _init_music_variables() -> void:
	unused_music_byte = 0
	disable_channel_output_when_sfx_ends = 0
	music_wave_instrument = 0
	sfx_wave_instrument = 0
	music_tempo = DEFAULT_TEMPO
	for index: int in NUM_MUSIC_CHANS:
		_pointers[CMD_POINTERS + index] = 0
		_pointers[RETURN_ADDRESSES + index] = 0
		_clear_channel(index)
	stereo_panning = 0xFF
	apu.write(RAUDVOL, 0)
	apu.write(RAUD1SWEEP, AUD1SWEEP_DOWN)
	apu.write(RAUDTERM, 0)
	apu.write(RAUD3ENA, 0)
	apu.write(RAUD3ENA, AUD3ENA_ON)
	apu.write(RAUDVOL, MAX_VOLUME)


## Every array the two clears zero, plus the three they set to one. The delay
## fraction, the octave and the volume are deliberately outside it.
func _clear_channel(channel: int) -> void:
	for base: int in [
		SOUND_IDS, FLAGS1, FLAGS2, DUTY_CYCLES, DUTY_CYCLE_PATTERNS, VIBRATO_DELAY,
		VIBRATO_EXTENTS, VIBRATO_RATES, FREQUENCY_LOW, VIBRATO_RELOAD,
		SLIDE_LENGTH_MOD, SLIDE_STEPS, SLIDE_STEPS_FRACTION, SLIDE_CURRENT_FRACTION,
		SLIDE_CURRENT_HIGH, SLIDE_CURRENT_LOW, SLIDE_TARGET_HIGH, SLIDE_TARGET_LOW,
	]:
		_wram[base + channel] = 0
	_wram[LOOP_COUNTERS + channel] = 1
	_wram[NOTE_DELAY + channel] = 1
	_wram[NOTE_SPEEDS + channel] = 1


## `.playChannel`, the same clear over one channel with the sweep switched off
## when that channel is the first effect channel.
func _init_sfx_variables(channel: int) -> void:
	_pointers[CMD_POINTERS + channel] = 0
	_pointers[RETURN_ADDRESSES + channel] = 0
	_clear_channel(channel)
	if channel == CHAN5:
		apu.write(RAUD1SWEEP, AUD1SWEEP_DOWN)


## `.stopAllAudio`. Its flat fill stops after 160 bytes, short of the two
## pitch-slide target arrays and of the octaves and volumes; Yellow fills 176 and
## takes the targets with it.
func _stop_all_audio() -> void:
	apu.write(RAUDENA, AUD3ENA_ON)
	apu.write(RAUD3ENA, AUD3ENA_ON)
	apu.write(RAUDTERM, 0)
	apu.write(RAUD3LEVEL, 0)
	apu.write(RAUD1SWEEP, AUD1SWEEP_DOWN)
	apu.write(0xFF12, AUD1SWEEP_DOWN)
	apu.write(0xFF17, AUD1SWEEP_DOWN)
	apu.write(0xFF21, AUD1SWEEP_DOWN)
	apu.write(0xFF14, AUD1HIGH_LENGTH_ON)
	apu.write(0xFF19, AUD1HIGH_LENGTH_ON)
	apu.write(0xFF23, AUD1HIGH_LENGTH_ON)
	apu.write(RAUDVOL, MAX_VOLUME)
	unused_music_byte = 0
	disable_channel_output_when_sfx_ends = 0
	mute_audio_and_pause_music = 0
	music_wave_instrument = 0
	sfx_wave_instrument = 0
	music_tempo = DEFAULT_TEMPO
	sfx_tempo = DEFAULT_TEMPO
	_fill_channel_block(176 if yellow else 160)
	for index: int in NUM_CHANNELS:
		_wram[NOTE_DELAY + index] = 1
		_wram[LOOP_COUNTERS + index] = 1
		_wram[NOTE_SPEEDS + index] = 1
	stereo_panning = 0xFF


func _fill_channel_block(bytes: int) -> void:
	for index: int in mini(bytes, POINTER_BYTES) / 2:
		_pointers[index] = 0
	for index: int in mini(maxi(bytes - POINTER_BYTES, 0), WRAM_SLOTS):
		_wram[index] = 0


## `FadeOutAudio`, which VBlank runs in front of the driver. Nothing fading is
## still a write: full volume every frame unless the no-fade flag is up.
func fade_out_audio() -> void:
	if fade_out_control == 0:
		if not no_audio_fade_out:
			apu.write(RAUDVOL, MAX_VOLUME)
		return
	if fade_out_counter != 0:
		fade_out_counter -= 1
		return
	fade_out_counter = fade_out_reload
	var volume: int = apu.read(RAUDVOL)
	if volume == 0:
		_finish_fade_out()
		return
	var low: int = (volume & 0x0F) - 1
	var high: int = ((volume >> 4) & 0x0F) - 1
	apu.write(RAUDVOL, ((high & 0x0F) << 4) | (low & 0x0F))


func _finish_fade_out() -> void:
	var queued: int = fade_out_control
	fade_out_control = 0
	play_sound(SFX_STOP_ALL_MUSIC)
	audio_rom_bank = saved_rom_bank
	play_sound(queued)


## `PlaySound`'s `.fadeOut`: a frame count per volume step and the id to start
## once the volume reaches zero.
func start_fade(frames: int, queued_id: int, queued_bank: int) -> void:
	fade_out_control = queued_id & 0xFF
	fade_out_counter = frames & 0xFF
	fade_out_reload = frames & 0xFF
	saved_rom_bank = queued_bank if queued_bank > 0 else audio_rom_bank


## `Music_DoLowHealthAlarm`, which the battle loop runs beside the driver rather
## than inside it. The tone it writes stays on channel 1 until it is changed.
func do_low_health_alarm() -> void:
	if low_health_alarm == DISABLE_LOW_HEALTH_ALARM:
		low_health_alarm = 0
		_wram[SOUND_IDS + CHAN5] = 0
		_write_alarm_tone(0x00, 0x00, 0x8000)
		return
	if (low_health_alarm & BIT_LOW_HEALTH_ALARM) == 0:
		return
	var timer: int = low_health_alarm & LOW_HEALTH_TIMER_MASK
	if timer == 0:
		_write_alarm_tone(0xA0, 0xE2, 0x8750)
		low_health_alarm = 30 | BIT_LOW_HEALTH_ALARM
		return
	if timer == 20:
		_write_alarm_tone(0xB0, 0xE2, 0x86EE)
	_wram[SOUND_IDS + CHAN5] = CRY_SFX_END
	low_health_alarm = ((timer - 1) & LOW_HEALTH_TIMER_MASK) | BIT_LOW_HEALTH_ALARM


## `.playTone` clears the sweep and then copies four bytes, so the five registers
## land as zero, length, envelope, frequency low and frequency high.
func _write_alarm_tone(length: int, envelope: int, frequency: int) -> void:
	apu.write(RAUD1SWEEP, 0)
	apu.write(0xFF11, length)
	apu.write(0xFF12, envelope)
	apu.write(0xFF13, frequency & 0xFF)
	apu.write(0xFF14, (frequency >> 8) & 0xFF)


## `Music_PokeFluteInBattle`: the caught-mon effect is started and its three
## channel pointers are overwritten at once with the flute's own.
func play_poke_flute_in_battle(pointers: Array) -> void:
	play_sound(Gen1Layout.SFX_CAUGHT_MON)
	for index: int in mini(pointers.size(), 3):
		_pointers[CMD_POINTERS + CHAN5 + index] = int(pointers[index]) & 0xFFFF


## Overwrites the channel pointers a piece has just loaded, which is what the two
## alternate `MeetRival` starts and `Music_Cities1AlternateTempo` do.
func overwrite_channel_pointers(pointers: Array) -> void:
	for index: int in mini(pointers.size(), NUM_MUSIC_CHANS):
		_pointers[CMD_POINTERS + index] = int(pointers[index]) & 0xFFFF


func music_channels_active() -> bool:
	for index: int in NUM_MUSIC_CHANS:
		if _wram[SOUND_IDS + index] != 0:
			return true
	return false


## `WaitForSoundToFinish` waits on the four effect channels alone.
func sfx_active() -> bool:
	for index: int in range(NUM_MUSIC_CHANS, NUM_CHANNELS):
		if _wram[SOUND_IDS + index] != 0:
			return true
	return false


func any_channel_active() -> bool:
	return music_channels_active() or sfx_active()



## `Audio<N>_UpdateMusic`, one LCD frame of the driver.
func update_music() -> void:
	for channel: int in NUM_CHANNELS:
		if _wram[SOUND_IDS + channel] == 0:
			continue
		if channel >= CHAN5 or mute_audio_and_pause_music == 0:
			_apply_music_affects(channel)
			continue
		if (mute_audio_and_pause_music & BIT_MUTE_AUDIO) != 0:
			continue
		mute_audio_and_pause_music |= BIT_MUTE_AUDIO
		apu.write(RAUDTERM, 0)
		apu.write(RAUD3ENA, 0)
		apu.write(RAUD3ENA, AUD3ENA_ON)
	_apply_output_gain()


## The two listening levels, pushed to the hardware channels by which stream owns
## each one. A hardware channel an effect has taken carries the effect level for
## as long as its sound id stands.
func _apply_output_gain() -> void:
	for hardware: int in NUM_MUSIC_CHANS:
		apu.channel_gain[hardware] = (
			sfx_gain if _wram[SOUND_IDS + hardware + NUM_MUSIC_CHANS] != 0 else music_gain
		)


## `Audio1_ApplyMusicAffects`: the delay counter first, then the duty pattern,
## the pitch slide and the vibrato, none of which run on a frame a note starts.
func _apply_music_affects(c: int) -> void:
	if _wram[NOTE_DELAY + c] == 1:
		_play_next_note(c)
		return
	_wram[NOTE_DELAY + c] = (_wram[NOTE_DELAY + c] - 1) & 0xFF
	if c < CHAN5 and _wram[SOUND_IDS + c + NUM_MUSIC_CHANS] != 0:
		return
	if (_wram[FLAGS1 + c] & BIT_ROTATE_DUTY_CYCLE) != 0:
		_apply_duty_cycle_pattern(c)
	if (_wram[FLAGS2 + c] & BIT_EXECUTE_MUSIC) == 0 \
		and (_wram[FLAGS1 + c] & BIT_NOISE_OR_SFX) != 0:
		return
	if (_wram[FLAGS1 + c] & BIT_PITCH_SLIDE_ON) != 0:
		_apply_pitch_slide(c)
		return
	if _wram[VIBRATO_DELAY + c] != 0:
		_wram[VIBRATO_DELAY + c] -= 1
		return
	_apply_vibrato(c)


## The direction bit is set and reset nowhere else, so the swing alternates by
## itself; the counter reloads out of its own high nibble.
func _apply_vibrato(c: int) -> void:
	var extent: int = _wram[VIBRATO_EXTENTS + c]
	if extent == 0:
		return
	if (_wram[VIBRATO_RATES + c] & 0x0F) != 0:
		_wram[VIBRATO_RATES + c] -= 1
		return
	var rate: int = _wram[VIBRATO_RATES + c]
	_wram[VIBRATO_RATES + c] = (rate | (((rate << 4) | (rate >> 4)) & 0xFF)) & 0xFF
	var pitch: int = _wram[FREQUENCY_LOW + c]
	var value: int = 0
	if (_wram[FLAGS1 + c] & BIT_VIBRATO_DIRECTION) != 0:
		_wram[FLAGS1 + c] &= ~BIT_VIBRATO_DIRECTION
		var below: int = extent & 0x0F
		value = 0 if below > pitch else pitch - below
	else:
		_wram[FLAGS1 + c] |= BIT_VIBRATO_DIRECTION
		var above: int = (extent & 0xF0) >> 4
		value = 0xFF if pitch + above > 0xFF else pitch + above
	apu.write(_register(REG_FREQUENCY_LO, c), value)


## `Audio1_PlayNextNote`: the vibrato delay is reloaded, the slide is cleared and
## the stream is walked until something takes time.
func _play_next_note(c: int) -> void:
	_wram[VIBRATO_DELAY + c] = _wram[VIBRATO_RELOAD + c]
	_wram[FLAGS1 + c] &= ~(BIT_PITCH_SLIDE_ON | BIT_PITCH_SLIDE_DECREASING)
	## Yellow holds the first effect channel still while the alarm owns it,
	## re-enabling its output rather than reading another command.
	if yellow and c == CHAN5 and (low_health_alarm & BIT_LOW_HEALTH_ALARM) != 0:
		_enable_channel_output(c)
		return
	var steps: int = 0
	while _run_command(c, _get_next_music_byte(c)):
		steps += 1
		if steps > MAX_PARSE_STEPS:
			_wram[SOUND_IDS + c] = 0
			push_warning("Gen1SoundEngine: channel %d read %d commands without a note."
				% [c, MAX_PARSE_STEPS])
			return


## `Audio1_sound_ret` down to `Audio1_note_pitch`, in the source's own order.
## True carries on to the next command; false is one of its `ret`s.
func _run_command(c: int, d: int) -> bool:
	if d == SOUND_RET_CMD:
		return _sound_ret(c)
	if d == SOUND_CALL_CMD:
		return _sound_call(c)
	if d == SOUND_LOOP_CMD:
		return _sound_loop(c)
	if (d & 0xF0) == NOTE_TYPE_CMD:
		_note_type(c, d)
		return true
	if d == PITCH_SLIDE_CMD:
		_pitch_slide(c)
		return false
	if COMMANDS.has(d):
		return call(StringName(COMMANDS[d]), c)
	if (d & 0xF0) == OCTAVE_CMD:
		_wram[OCTAVES + c] = d & 0x0F
		return true
	var free_of_music: bool = (_wram[FLAGS2 + c] & BIT_EXECUTE_MUSIC) == 0
	if (d & 0xF0) == SFX_NOTE_CMD and c >= CHAN4 and free_of_music:
		_sfx_note(c, d)
		return false
	if c >= CHAN5 and d == PITCH_SWEEP_CMD and free_of_music:
		apu.write(RAUD1SWEEP, _get_next_music_byte(c))
		return true
	_note(c, d)
	return false


## `sound_ret` outside a `sound_call`: the channel stops, its output is disabled
## and a cry hands the saved volume back on the way out.
func _sound_ret(c: int) -> bool:
	if (_wram[FLAGS1 + c] & BIT_SOUND_CALL) != 0:
		_wram[FLAGS1 + c] &= ~BIT_SOUND_CALL
		_pointers[CMD_POINTERS + c] = _pointers[RETURN_ADDRESSES + c]
		return true
	if _disable_on_sound_ret(c):
		apu.write(RAUDTERM, apu.read(RAUDTERM) & (~HW_ENABLE_MASK[c] & 0xFF))
	if _is_cry_id(_wram[SOUND_IDS + CHAN5]):
		## Every cry channel but the first rewinds onto its own `sound_ret` and
		## keeps its id, so it idles there until the first one ends.
		if c != CHAN5:
			_pointers[CMD_POINTERS + c] = (_pointers[CMD_POINTERS + c] - 1) & 0xFFFF
			return false
		apu.write(RAUDVOL, saved_volume)
		saved_volume = 0
	_wram[SOUND_IDS + c] = 0
	return false


func _disable_on_sound_ret(c: int) -> bool:
	if c < CHAN4:
		return true
	_wram[FLAGS1 + c] &= ~BIT_NOISE_OR_SFX
	_wram[FLAGS2 + c] &= ~BIT_EXECUTE_MUSIC
	if c != CHAN7:
		return false
	apu.write(RAUD3ENA, 0)
	apu.write(RAUD3ENA, AUD3ENA_ON)
	if disable_channel_output_when_sfx_ends == 0:
		return false
	disable_channel_output_when_sfx_ends = 0
	return true


func _sound_call(c: int) -> bool:
	var target: int = _get_next_music_byte(c)
	target |= _get_next_music_byte(c) << 8
	_pointers[RETURN_ADDRESSES + c] = _pointers[CMD_POINTERS + c]
	_pointers[CMD_POINTERS + c] = target
	_wram[FLAGS1 + c] |= BIT_SOUND_CALL
	return true


## `sound_loop`: the counter counts up to the operand, and a zero operand is the
## infinite loop nearly every piece ends on.
func _sound_loop(c: int) -> bool:
	var wanted: int = _get_next_music_byte(c)
	if wanted != 0:
		if _wram[LOOP_COUNTERS + c] == wanted:
			_wram[LOOP_COUNTERS + c] = 1
			_get_next_music_byte(c)
			_get_next_music_byte(c)
			return true
		_wram[LOOP_COUNTERS + c] = (_wram[LOOP_COUNTERS + c] + 1) & 0xFF
	var target: int = _get_next_music_byte(c)
	_pointers[CMD_POINTERS + c] = target | (_get_next_music_byte(c) << 8)
	return true


## `note_type`, which is `drum_speed` on the noise channel: the low nibble is the
## note speed, and the two wave channels split their parameter into an instrument
## index and an output level.
func _note_type(c: int, d: int) -> void:
	_wram[NOTE_SPEEDS + c] = d & 0x0F
	if c == CHAN4:
		return
	var parameter: int = _get_next_music_byte(c)
	if c == CHAN3 or c == CHAN7:
		if c == CHAN3:
			music_wave_instrument = parameter & 0x0F
		else:
			sfx_wave_instrument = parameter & 0x0F
		parameter = ((parameter & 0x30) << 1) & 0xFF
	_wram[VOLUMES + c] = parameter


func _toggle_perfect_pitch(c: int) -> bool:
	_wram[FLAGS1 + c] ^= BIT_PERFECT_PITCH
	return true


## `vibrato`: the extent is split so the swing above the note rounds away from
## zero and the swing below it rounds toward it.
func _vibrato(c: int) -> bool:
	var delay: int = _get_next_music_byte(c)
	_wram[VIBRATO_DELAY + c] = delay
	_wram[VIBRATO_RELOAD + c] = delay
	var shape: int = _get_next_music_byte(c)
	var extent: int = (shape & 0xF0) >> 4
	_wram[VIBRATO_EXTENTS + c] = (((extent >> 1) + (extent & 1)) << 4) | (extent >> 1)
	var rate: int = shape & 0x0F
	_wram[VIBRATO_RATES + c] = (rate << 4) | rate
	return true


## `pitch_slide` reads its own length and target and then falls into the note
## length, so the note byte behind it is what times the slide.
func _pitch_slide(c: int) -> void:
	_wram[SLIDE_LENGTH_MOD + c] = _get_next_music_byte(c)
	var target: int = _get_next_music_byte(c)
	var frequency: int = _calculate_frequency(target & 0x0F, (target & 0xF0) >> 4)
	_wram[SLIDE_TARGET_HIGH + c] = (frequency >> 8) & 0xFF
	_wram[SLIDE_TARGET_LOW + c] = frequency & 0xFF
	_wram[FLAGS1 + c] |= BIT_PITCH_SLIDE_ON
	var note: int = _get_next_music_byte(c)
	_note_length(c, note)
	if not _note_length_returns(c):
		_note_pitch(c, note)


func _duty_cycle(c: int) -> bool:
	var value: int = _get_next_music_byte(c)
	_wram[DUTY_CYCLES + c] = ((value >> 2) | (value << 6)) & 0xC0
	return true


## `tempo`, which the four effect channels keep apart from the four music ones.
## Each half clears its own note-delay fractions.
func _tempo(c: int) -> bool:
	var value: int = _get_next_music_byte(c) << 8
	value |= _get_next_music_byte(c)
	var base: int = NUM_MUSIC_CHANS if c >= CHAN5 else 0
	if c >= CHAN5:
		sfx_tempo = value
	else:
		music_tempo = value
	for index: int in NUM_MUSIC_CHANS:
		_wram[NOTE_DELAY_FRACTION + base + index] = 0
	return true


func _stereo_panning(c: int) -> bool:
	stereo_panning = _get_next_music_byte(c)
	return true


## `unknownmusic0xef`, which no shipped stream reaches: it plays the id it reads
## and moves the noise channel's own id into the disable flag.
func _unknown_ef(c: int) -> bool:
	play_sound(_get_next_music_byte(c))
	if disable_channel_output_when_sfx_ends == 0:
		disable_channel_output_when_sfx_ends = _wram[SOUND_IDS + CHAN8]
		_wram[SOUND_IDS + CHAN8] = 0
	return true


func _duty_cycle_pattern(c: int) -> bool:
	var pattern: int = _get_next_music_byte(c)
	_wram[DUTY_CYCLE_PATTERNS + c] = pattern
	_wram[DUTY_CYCLES + c] = pattern & 0xC0
	_wram[FLAGS1 + c] |= BIT_ROTATE_DUTY_CYCLE
	return true


func _volume(c: int) -> bool:
	apu.write(RAUDVOL, _get_next_music_byte(c))
	return true


func _execute_music(c: int) -> bool:
	_wram[FLAGS2 + c] |= BIT_EXECUTE_MUSIC
	return true


## `square_note` and `noise_note`, the effect channels' own note: a length, a
## volume envelope and either a two-byte frequency or the noise channel's one.
func _sfx_note(c: int, d: int) -> void:
	var length: int = _note_length(c, d)
	apu.write(_register(REG_DUTY_SOUND_LEN, c), length | _wram[DUTY_CYCLES + c])
	apu.write(_register(REG_VOLUME_ENVELOPE, c), _get_next_music_byte(c))
	var low: int = _get_next_music_byte(c)
	var high: int = 0
	if c != CHAN8:
		high = _get_next_music_byte(c)
	_apply_duty_cycle_and_sound_length(c)
	_enable_channel_output(c)
	_apply_wave_pattern_and_frequency(c, low, high)


## `Audio1_note`: on the music noise channel a `drum_note` plays its instrument
## as a sound of its own before the length is counted.
func _note(c: int, d: int) -> void:
	var length_byte: int = d
	if c == CHAN4 and (d & 0xF0) <= DRUM_NOTE_CMD:
		var instrument: int = d >> 4
		length_byte = d & 0x0F
		if (d & 0xF0) == DRUM_NOTE_CMD:
			instrument = _get_next_music_byte(c)
		if disable_channel_output_when_sfx_ends == 0:
			play_sound(instrument)
	_note_length(c, length_byte)
	if _note_length_returns(c):
		return
	_note_pitch(c, length_byte)


## The one place `Audio1_note_length` returns to its caller rather than falling
## into `Audio1_note_pitch`, which is every effect channel and the music noise
## channel outside `execute_music`.
func _note_length_returns(c: int) -> bool:
	return (_wram[FLAGS2 + c] & BIT_EXECUTE_MUSIC) == 0 \
		and (_wram[FLAGS1 + c] & BIT_NOISE_OR_SFX) != 0


## `Audio1_note_length`: the delay is the note length times the note speed times
## the tempo, carried in a byte of fraction.
func _note_length(c: int, d: int) -> int:
	var product: int = _multiply_add(_wram[NOTE_SPEEDS + c], (d & 0x0F) + 1, 0)
	var tempo: int = music_tempo
	if c >= CHAN5:
		tempo = DEFAULT_TEMPO
		if c != CHAN8:
			_set_sfx_tempo()
			tempo = sfx_tempo
	var total: int = _multiply_add(product & 0xFF, tempo, _wram[NOTE_DELAY_FRACTION + c])
	_wram[NOTE_DELAY_FRACTION + c] = total & 0xFF
	_wram[NOTE_DELAY + c] = (total >> 8) & 0xFF
	return _wram[NOTE_DELAY + c]


## `Audio1_note_pitch`: a rest silences the channel, anything else is a
## frequency, an envelope and a restart.
func _note_pitch(c: int, d: int) -> void:
	if (d & 0xF0) == REST_CMD:
		_rest(c)
		return
	var frequency: int = _calculate_frequency(d >> 4, _wram[OCTAVES + c])
	if (_wram[FLAGS1 + c] & BIT_PITCH_SLIDE_ON) != 0:
		_init_pitch_slide_vars(c, frequency)
	if c < CHAN5 and _wram[SOUND_IDS + CHAN5 + c] != 0:
		return
	apu.write(_register(REG_VOLUME_ENVELOPE, c), _wram[VOLUMES + c])
	_apply_duty_cycle_and_sound_length(c)
	_enable_channel_output(c)
	var low: int = frequency & 0xFF
	if (_wram[FLAGS1 + c] & BIT_PERFECT_PITCH) != 0:
		low = (low + 1) & 0xFF
	_wram[FREQUENCY_LOW + c] = low
	_apply_wave_pattern_and_frequency(c, low, (frequency >> 8) & 0xFF)


## A rest on either wave channel drops its output bit; on the others it sets the
## envelope to a fade-in and restarts the channel.
func _rest(c: int) -> void:
	if c < CHAN5 and _wram[SOUND_IDS + CHAN5 + c] != 0:
		return
	if c == CHAN3 or c == CHAN7:
		apu.write(RAUDTERM, apu.read(RAUDTERM) & (~HW_ENABLE_MASK[c] & 0xFF))
		return
	apu.write(_register(REG_VOLUME_ENVELOPE, c), 0x08)
	apu.write(_register(REG_FREQUENCY_LO, c) + 1, 0x80)


## `Audio1_EnableChannelOutput`: this channel's two bits go up, and the panning
## byte narrows them for the noise channel and for a music channel no effect has
## taken. One write, however the value was reached.
func _enable_channel_output(c: int) -> void:
	var enable: int = _enable_mask(c)
	var value: int = apu.read(RAUDTERM) | enable
	if c == CHAN8 or (c < CHAN5 and _wram[SOUND_IDS + CHAN5 + c] == 0):
		value = (apu.read(RAUDTERM) & (~HW_ENABLE_MASK[c] & 0xFF)) | (stereo_panning & enable)
	apu.write(RAUDTERM, value)


## Yellow reads the SOUND option here, which picks one of four enable-mask rows;
## the other two cartridges have the mono row alone.
func _enable_mask(c: int) -> int:
	if not yellow:
		return HW_ENABLE_MASK[c]
	return int(Gen1Layout.YELLOW_ENABLE_MASKS[mono_stereo_offset + c])


## `Audio1_ApplyDutyCycleAndSoundLength`: the note delay doubles as the sound
## length, with the duty cycle in the top two bits everywhere but channel 3.
func _apply_duty_cycle_and_sound_length(c: int) -> void:
	var value: int = _wram[NOTE_DELAY + c]
	if c != CHAN3 and c != CHAN7:
		value = (value & 0x3F) | _wram[DUTY_CYCLES + c]
	apu.write(_register(REG_DUTY_SOUND_LEN, c), value)


## `Audio1_ApplyWavePatternAndFrequency`: the wave channels reload all sixteen
## bytes of wave RAM first, and every channel ends on the two frequency bytes.
func _apply_wave_pattern_and_frequency(c: int, low: int, high: int) -> void:
	if c == CHAN3 or c == CHAN7:
		_load_wave_pattern(music_wave_instrument if c == CHAN3 else sfx_wave_instrument)
	var value: int = (high | 0x80) & 0xC7
	apu.write(_register(REG_FREQUENCY_LO, c), low)
	apu.write(_register(REG_FREQUENCY_LO, c) + 1, value)
	## The battle copy of the driver and Yellow's single copy leave the music
	## channels alone here; Red and Blue's first and third copies do not.
	if c < CHAN5 and (yellow or audio_rom_bank == Gen1Layout.AUDIO_BANK_ROM[1]):
		return
	_apply_frequency_modifier(c, low, value)


## `.loop` copies the instrument over wave RAM with the channel stopped, then
## starts it again.
func _load_wave_pattern(instrument: int) -> void:
	var bank: int = _wave_bank()
	if not _banks.has(bank):
		return
	var entry: int = int((_banks[bank] as Dictionary)["wave_pointers"]) + instrument * 2
	var source: int = _bank_byte(bank, entry) | (_bank_byte(bank, entry + 1) << 8)
	apu.write(RAUD3ENA, 0)
	for index: int in WAVE_RAM_SIZE:
		apu.write(WAVE_RAM + index, _bank_byte(bank, source + index))
	apu.write(RAUD3ENA, AUD3ENA_ON)


## Yellow keeps one `Audio1_WavePointers`, in the first audio bank, so every copy
## of the driver reads the same instruments and the same garbage sixth one.
func _wave_bank() -> int:
	return Gen1Layout.AUDIO_BANK_ROM[0] if yellow else audio_rom_bank


## `Audio1_ApplyFrequencyModifier`: a cry, and a battle effect in the copy of the
## driver that knows them, adds `wFrequencyModifier` to what was just written.
func _apply_frequency_modifier(c: int, low: int, high: int) -> void:
	if not _cry_or_battle_sfx():
		return
	var value: int = low + frequency_modifier
	apu.write(_register(REG_FREQUENCY_LO, c), value & 0xFF)
	apu.write(_register(REG_FREQUENCY_LO, c) + 1, (high + (1 if value > 0xFF else 0)) & 0xFF)


## `Audio1_SetSfxTempo`: a cry runs at `wTempoModifier` biased by $80, and
## everything else at one.
func _set_sfx_tempo() -> void:
	sfx_tempo = (tempo_modifier + 0x80) & 0xFFFF if _cry_or_battle_sfx() else DEFAULT_TEMPO


## `Audio1_ApplyDutyCyclePattern`: the stored pattern rotates two bits a frame,
## so the duty cycle changes at the driver's rate rather than the note's.
func _apply_duty_cycle_pattern(c: int) -> void:
	var pattern: int = _wram[DUTY_CYCLE_PATTERNS + c]
	pattern = ((pattern << 2) | (pattern >> 6)) & 0xFF
	_wram[DUTY_CYCLE_PATTERNS + c] = pattern
	var register: int = _register(REG_DUTY_SOUND_LEN, c)
	apu.write(register, (apu.read(register) & 0x3F) | (pattern & 0xC0))


## `Audio1_ApplyPitchSlide`, the frame-by-frame walk toward the target.
func _apply_pitch_slide(c: int) -> void:
	var current: int = (_wram[SLIDE_CURRENT_HIGH + c] << 8) | _wram[SLIDE_CURRENT_LOW + c]
	var target: int = (_wram[SLIDE_TARGET_HIGH + c] << 8) | _wram[SLIDE_TARGET_LOW + c]
	var next: int = 0
	if (_wram[FLAGS1 + c] & BIT_PITCH_SLIDE_DECREASING) != 0:
		var doubled: int = _wram[SLIDE_STEPS_FRACTION + c] * 2
		_wram[SLIDE_STEPS_FRACTION + c] = doubled & 0xFF
		next = (current - _wram[SLIDE_STEPS + c] - (1 if doubled > 0xFF else 0)) & 0xFFFF
		if next < target:
			_stop_pitch_slide(c)
			return
	else:
		var fraction: int = _wram[SLIDE_CURRENT_FRACTION + c] + _wram[SLIDE_STEPS_FRACTION + c]
		_wram[SLIDE_CURRENT_FRACTION + c] = fraction & 0xFF
		next = (current + _wram[SLIDE_STEPS + c] + (1 if fraction > 0xFF else 0)) & 0xFFFF
		if target < next:
			_stop_pitch_slide(c)
			return
	_wram[SLIDE_CURRENT_LOW + c] = next & 0xFF
	_wram[SLIDE_CURRENT_HIGH + c] = (next >> 8) & 0xFF
	apu.write(_register(REG_FREQUENCY_LO, c), next & 0xFF)
	apu.write(_register(REG_FREQUENCY_LO, c) + 1, (next >> 8) & 0xFF)


func _stop_pitch_slide(c: int) -> void:
	_wram[FLAGS1 + c] &= ~(BIT_PITCH_SLIDE_ON | BIT_PITCH_SLIDE_DECREASING)


## `Audio1_InitPitchSlideVars`. The length modifier becomes the divisor, and the
## borrow the source takes from the current frequency rather than from the target
## is the cartridge's own bug: an upward slide whose low byte has wrapped starts
## $200 further away than it should.
func _init_pitch_slide_vars(c: int, frequency: int) -> void:
	_wram[SLIDE_CURRENT_HIGH + c] = (frequency >> 8) & 0xFF
	_wram[SLIDE_CURRENT_LOW + c] = frequency & 0xFF
	var divisor: int = _wram[NOTE_DELAY + c] - _wram[SLIDE_LENGTH_MOD + c]
	divisor = 1 if divisor < 0 else divisor
	_wram[SLIDE_LENGTH_MOD + c] = divisor
	var low: int = (frequency & 0xFF) - _wram[SLIDE_TARGET_LOW + c]
	var high: int = ((frequency >> 8) & 0xFF) - (1 if low < 0 else 0) \
		- _wram[SLIDE_TARGET_HIGH + c]
	if high >= 0:
		_wram[FLAGS1 + c] |= BIT_PITCH_SLIDE_DECREASING
	else:
		low = _wram[SLIDE_TARGET_LOW + c] - (frequency & 0xFF)
		var wrapped: int = (((frequency >> 8) & 0xFF) - (1 if low < 0 else 0)) & 0xFF
		high = _wram[SLIDE_TARGET_HIGH + c] - wrapped
		_wram[FLAGS1 + c] &= ~BIT_PITCH_SLIDE_DECREASING
	_divide_pitch_slide(c, high & 0xFF, low & 0xFF, divisor)


## `.divideLoop`, whose count includes the borrowing pass: the stored step is the
## quotient plus one and the stored fraction the remainder less the divisor.
func _divide_pitch_slide(c: int, high: int, low: int, divisor: int) -> void:
	if divisor == 0:
		## The cartridge subtracts zero forever here and locks the console up, so
		## no shipped stream reaches it.
		_wram[SLIDE_STEPS + c] = 0
		_wram[SLIDE_STEPS_FRACTION + c] = 0
		_wram[SLIDE_CURRENT_FRACTION + c] = 0
		return
	var quotient: int = 0
	while true:
		quotient += 1
		low -= divisor
		if low >= 0:
			continue
		if high == 0:
			break
		high -= 1
		low &= 0xFF
	_wram[SLIDE_STEPS + c] = quotient & 0xFF
	_wram[SLIDE_STEPS_FRACTION + c] = (low + divisor) & 0xFF
	_wram[SLIDE_CURRENT_FRACTION + c] = (low + divisor) & 0xFF


## `Audio1_MultiplyAdd`: hl = l + a * de, sixteen bits wide.
func _multiply_add(multiplier: int, value: int, addend: int) -> int:
	return (addend + multiplier * value) & 0xFFFF


## `Audio1_CalculateFrequency`: the table entry shifted right arithmetically once
## per octave above the lowest, with eight added to the high byte.
func _calculate_frequency(note: int, octave: int) -> int:
	if note < 0 or note >= PITCHES.size():
		return 0
	var value: int = PITCHES[note] - 0x10000
	var shifts: int = (7 - octave) & 0xFF
	while shifts > 0:
		value >>= 1
		shifts -= 1
	return (((((value >> 8) & 0xFF) + 8) & 0xFF) << 8) | (value & 0xFF)


func _register(register: int, c: int) -> int:
	return 0xFF00 | ((HW_CHANNEL_BASE[c] + register) & 0xFF)


func _get_next_music_byte(c: int) -> int:
	var address: int = _pointers[CMD_POINTERS + c]
	_pointers[CMD_POINTERS + c] = (address + 1) & 0xFFFF
	return _bank_byte(audio_rom_bank, address)


func _bank_byte(bank: int, address: int) -> int:
	var entry: Variant = _banks.get(bank, null)
	if entry == null:
		return 0xFF
	var bytes: PackedByteArray = (entry as Dictionary)["bytes"]
	var at: int = address - int((entry as Dictionary)["origin"])
	if at < 0 or at >= bytes.size():
		return 0xFF
	return bytes[at]


static func _to_bytes(value: Variant) -> PackedByteArray:
	if value is PackedByteArray:
		return value
	if not value is Array:
		return PackedByteArray()
	var raw: Array = value as Array
	var out := PackedByteArray()
	out.resize(raw.size())
	for index: int in out.size():
		out[index] = int(raw[index]) & 0xFF
	return out
