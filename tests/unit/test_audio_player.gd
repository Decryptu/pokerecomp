extends GutTest

## The player's own decisions, separate from the driver: which requests restart
## music, which stop it, and that the generator keeps being fed.

const Player := preload("res://game/audio/gen2_audio_player.gd")

var _player: Gen2AudioPlayer = null


func before_each() -> void:
	_player = Player.new()
	add_child_autofree(_player)
	# Every case here services the timeline by hand and counts what it cost, so
	# the node's own pump must not have spent a frame first.
	_player.set_process(false)


## One looping channel stream, so a started track stays started. [param channel]
## is the hardware channel it loads, which is `LoadChannel`'s own low three bits.
func _record(bank: int, index: int = 1, channel: int = 0) -> Dictionary:
	return {
		"index": index,
		"bank": bank,
		"address": 0x4000,
		"data_address": 0x4000,
		"bytes": [
			channel, 0x03, 0x40,
			0xD8, 0x10, 0xB1, 0xD4, 0x1F, 0xFC, 0x03, 0x40,
		],
	}


## The same stream under a `channel_count 2` header, on channels 1 and 2.
func _two_channel_record(bank: int) -> Dictionary:
	var record: Dictionary = _record(bank)
	record["bytes"] = [
		0x40, 0x06, 0x40,
		0x01, 0x06, 0x40,
		0xD8, 0x10, 0xB1, 0xD4, 0x1F, 0xFC, 0x06, 0x40,
	]
	return record


## `Music_Mom` names channels 2, 3 and 4 and `Music_NewBarkTown` 1, 2 and 3, and
## `_PlayMusic` only loads the ones its own header names. Every source caller
## spends `PlayMusic MUSIC_NONE` in front of it for this reason: without one the
## town's first channel plays on under Mom's theme, at the town's own tempo.
func test_a_new_piece_stops_the_channels_it_does_not_name() -> void:
	assert_true(_player.play_record(_two_channel_record(2), &"map_music")["played"])
	assert_eq(_player.audio_status()["active_channels"], [1, 2] as Array[int])

	assert_true(_player.play_record(_record(3, 1, 1), &"music")["played"])
	assert_eq(_player.audio_status()["active_channels"], [2] as Array[int])


## The app block's two volumes are the game's, not only the launcher's: they are
## pushed to the driver's mix, where music and effects can still be told apart,
## and a host's own scale multiplies them.
func test_the_app_volumes_and_a_host_scale_reach_the_drivers_mix() -> void:
	var options: Gen2Options = Gen2OptionsStore.current()
	var music: int = options.music_volume
	var sfx: int = options.sfx_volume
	options.music_volume = Gen2Options.MAX_VOLUME
	options.sfx_volume = 0
	# Edited in place while the player runs, which is what the settings slider
	# does, so the level has to be read rather than taken once at startup.
	_player._apply_settings()
	var status: Dictionary = _player.audio_status()
	assert_almost_eq(float(status["music_gain"]), 1.0, 0.001)
	assert_almost_eq(float(status["sfx_gain"]), 0.0, 0.001)

	_player.volume_scale = 0.5
	assert_almost_eq(float(_player.audio_status()["music_gain"]), 0.5, 0.001)

	options.music_volume = music
	options.sfx_volume = sfx


## A host that stops its own stream and then asks for music again gets sound,
## not a live driver over a dead output.
func test_a_stopped_output_under_live_channels_starts_itself_again() -> void:
	assert_true(_player.play_record(_record(2), &"map_music")["played"])
	_player._player.stop()
	_player._service_timeline()
	assert_true(_player._player.playing, "the output followed the driver")

	# Stopping the driver as well leaves it stopped, which is what a screen
	# closing means.
	_player.stop_all()
	_player._service_timeline()
	assert_false(_player._player.playing)


func test_music_already_playing_is_continued_rather_than_started_again() -> void:
	var first: Dictionary = _player.play_record(_record(2), &"map_music")
	assert_true(first["ok"])
	assert_true(first["played"])

	# Two connected maps with the same header music are one continuous track on
	# the cartridge. Restarting it at each map edge is audible.
	var again: Dictionary = _player.play_record(_record(2), &"map_music")
	assert_true(again["ok"])
	assert_false(again["played"])
	assert_true(again["continued"])

	# A different track still replaces it.
	assert_true(_player.play_record(_record(3), &"map_music")["played"])


func test_the_source_restart_special_starts_the_same_track_again() -> void:
	assert_true(_player.play_record(_record(2), &"map_music")["played"])
	# RestartMapMusic exists to override the rule above, so it has to.
	assert_true(_player.play_record(_record(2), &"map_music", {}, true)["played"])


func test_music_none_stops_everything_the_way_init_sound_does() -> void:
	assert_true(_player.play_record(_record(2), &"map_music")["played"])
	assert_true(_player.audio_status()["music_active"])
	# `PlayMusic MUSIC_NONE` is `_InitSound`, not a stream.
	var stopped: Dictionary = _player.play_record(_record(2, 0), &"map_music")
	assert_true(stopped["stopped"])
	assert_false(_player.audio_status()["music_active"])


func test_an_effect_is_playing_until_its_stream_ends() -> void:
	var effect: Dictionary = {
		"index": 3,
		"bank": 9,
		"address": 0x4000,
		"data_address": 0x4000,
		"bytes": [0x40, 0x03, 0x40, 0xDF, 0xD8, 0x01, 0xB1, 0xD4, 0x10, 0xFF],
	}
	assert_true(_player.play_record(effect, &"sound")["played"])
	assert_true(_player.effect_playing())
	for _frame: int in 8:
		_player._engine.update_sound()
	assert_false(_player.effect_playing())


## The queue is kept a fixed few frames ahead of the output rather than full, so
## the rest of the generator's depth is headroom instead of press-to-sound delay.
func test_the_queue_is_kept_to_its_latency_target_not_to_the_brim() -> void:
	assert_true(_player.play_record(_record(99), &"map_music")["ok"])
	_player._service_timeline()
	var capacity: int = _player._capacity
	var waiting: int = capacity - _player._playback.get_frames_available()
	assert_gt(capacity, 0, "the depth was learned from the stream")
	assert_gt(_player._timeline_updates, 0, "the service filled the queue at all")
	assert_almost_eq(
		float(waiting),
		float(Gen2AudioPlayer.TARGET_FRAMES_MIN * Gen2Apu.SAMPLES_PER_FRAME),
		float(Gen2Apu.SAMPLES_PER_FRAME),
	)
	assert_lt(waiting, capacity, "the rest of the depth is left as headroom")

	# A second service does not fill to the brim: the target is a level, not a
	# rate, so the queue comes back to the same depth rather than growing. The
	# level is what is asserted rather than the number of pushes, because the
	# output is a live driver here and whatever it drained between two pushes is
	# pushed again by the same rule.
	_player._service_timeline()
	assert_almost_eq(
		float(capacity - _player._playback.get_frames_available()),
		float(Gen2AudioPlayer.TARGET_FRAMES_MIN * Gen2Apu.SAMPLES_PER_FRAME),
		float(Gen2Apu.SAMPLES_PER_FRAME),
	)


## A device that cannot hold the target says so by running the queue dry, and the
## target rises for it rather than being chosen per platform by ear.
func test_an_underrun_raises_the_target_instead_of_needing_a_build_per_target() -> void:
	assert_true(_player.play_record(_record(99), &"map_music")["ok"])
	_player._service_timeline()
	var target: int = _player._target_frames
	# An empty queue under a depth that is already known, which is what the audio
	# server leaves behind when it consumed everything and asked for more.
	_player._player.stop()
	_player._player.play()
	_player._playback = _player._player.get_stream_playback() as AudioStreamGeneratorPlayback
	_player._service_timeline()
	assert_eq(_player._target_frames, target + 1)
	assert_eq(int(_player.audio_status()["underruns"]), 1)


## An output that takes nothing while the driver has sound for it is a session
## that went away, whatever `AudioStreamPlayer.playing` says. Every platform can
## reach some version of it and only some announce one.
func test_a_dead_output_is_rebuilt_rather_than_pushed_into_forever() -> void:
	assert_true(_player.play_record(_record(99), &"map_music")["ok"])
	_player._service_timeline()
	var first: AudioStreamPlayer = _player._player
	# The queue is at its target and nothing is consuming it, which is what a
	# torn-down session looks like from here.
	for _tick: int in 8:
		_player._service_timeline(Gen2AudioPlayer.STALL_SECONDS * 0.25)
	assert_eq(int(_player.audio_status()["output_restarts"]), 1)
	assert_ne(_player._player, first, "the stream player is a new one")
	assert_true(_player._player.playing)
	assert_true(_player.audio_status()["music_active"], "the driver kept the piece")


## A resume does not cut a live output: an alt-tab is a FOCUS_IN too. It shortens
## the watchdog's window, so an output that is still there proves it at once.
func test_a_resume_shortens_the_watchdog_rather_than_rebuilding_outright() -> void:
	assert_true(_player.play_record(_record(99), &"map_music")["ok"])
	_player._service_timeline()
	_player._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	assert_eq(int(_player.audio_status()["output_restarts"]), 0, "nothing was cut")
	assert_almost_eq(
		_player._starved_seconds,
		Gen2AudioPlayer.STALL_SECONDS - Gen2AudioPlayer.RESUME_GRACE_SECONDS,
		0.001,
	)

	# An output that is really gone is replaced a tenth of a second later.
	_player._service_timeline(Gen2AudioPlayer.RESUME_GRACE_SECONDS)
	assert_eq(int(_player.audio_status()["output_restarts"]), 1)


func test_a_fade_walks_the_master_volume_down_and_then_stops() -> void:
	assert_true(_player.play_record(_record(2), &"map_music")["played"])
	assert_true(_player.fade_out(1))
	for _frame: int in 32:
		_player._engine.update_sound()
	assert_eq(_player.audio_status()["volume"], Gen2SoundEngine.MAX_VOLUME,
		"the fade ends in `_InitSound`, which restores full volume")
	assert_false(_player.audio_status()["music_active"])


## `PlayStereoCry` writes wCryTracks and puts 1 in wStereoPanningMask;
## `PlayMonCry2` zeroes both. Written per request, so one battler's side does not
## leak into the next cry.
func test_a_cry_takes_its_tracks_for_that_request_only() -> void:
	var cry: Dictionary = _record(2)
	cry["cry_pitch"] = 0
	cry["cry_length"] = 0
	_player.play_record(cry, &"cry", {}, false, 0xF0)
	assert_eq(_player._engine.cry_tracks, 0xF0)
	assert_eq(_player._engine.stereo_panning_mask, 1)

	_player.play_record(cry, &"cry")
	assert_eq(_player._engine.cry_tracks, 0, "the next cry is PlayMonCry2's")
	assert_eq(_player._engine.stereo_panning_mask, 0)


## `wLowHealthAlarm`'s DANGER_ON bit is what `PlayDanger` runs off; clearing it
## zeroes the byte whole, the way `StopDangerSound` does.
func test_the_low_health_alarm_is_the_danger_bit_and_its_timer() -> void:
	assert_false(_player.low_health_alarm())
	_player.set_low_health_alarm(true)
	assert_true(_player.low_health_alarm())
	assert_eq(_player._engine.low_health_alarm, 1 << Gen2SoundEngine.DANGER_ON_BIT)

	_player._engine.low_health_alarm |= 12
	_player.set_low_health_alarm(false)
	assert_eq(_player._engine.low_health_alarm, 0, "the timer went with it")


## `Options_Sound` toggles the STEREO bit and spends `RestartMapMusic` on the
## change, because `Music_StereoPanning` has already narrowed `channel.tracks`
## and only a restart widens them again. The option is shared and edited in
## place, so the player follows it rather than being told.
func test_the_sound_option_reaches_the_driver_and_restarts_the_piece() -> void:
	var options: Gen2Options = Gen2OptionsStore.current()
	var was: bool = options.stereo
	options.stereo = false
	_player._apply_settings()
	assert_false(_player._engine.stereo)

	assert_true(_player.play_record(_record(2), &"map_music")["played"])
	var key: String = _player.audio_status()["music_key"]

	options.stereo = true
	_player._apply_settings()
	assert_true(_player._engine.stereo, "the driver follows the SOUND option live")
	assert_eq(_player.audio_status()["music_key"], key,
		"RestartMapMusic starts the same piece again")
	assert_true(_player.audio_status()["music_active"])

	_player.stop_all()
	options.stereo = not options.stereo
	_player._apply_settings()
	assert_eq(_player.audio_status()["music_key"], "",
		"a map with no music is `PlayMusic MUSIC_NONE` twice")
	options.stereo = was


## A `stereo_sfx` request is `PlayStereoSFX`, so the mask it carries is
## `wStereoPanningMask` rather than a cry's tracks.
func test_a_stereo_sfx_request_carries_its_panning_mask() -> void:
	_player._engine.stereo = true
	assert_true(_player.play_record(_record(2), &"stereo_sfx", {}, false, 0x0F)["played"])
	assert_eq(_player._engine.stereo_panning_mask, 0x0F)
