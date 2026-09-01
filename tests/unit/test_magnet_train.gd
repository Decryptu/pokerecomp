extends GutTest

## `MagnetTrain`'s jumptable and its override buffer, driven without a cache: the
## whole scene is byte counters, so every number here is the cartridge's own.
## `tools/checks/magnet_train.gd` is what checks the two tilemaps it draws with.

const FRAME_CAP: int = 2000

## One frame in `.InitPlayerSpriteAnim`, 129 in the wait behind it, 33 moving the
## train to `wMagnetTrainHoldPosition`, 129 waiting again, 81 moving it to
## `wMagnetTrainFinalPosition`, and one each for the wait that is already spent
## and `.TrainArrived`.
const RIDE_FRAMES: int = 375
## `.MoveTrain1`'s 32 single pixels and `.MoveTrain2`'s 80 doubles.
const TRAVEL: int = 32 + 160


func _run(movie: Gen2MagnetTrain) -> Array:
	var events: Array = []
	while not movie.finished() and movie.frame() < FRAME_CAP:
		events.append_array(movie.advance_frame())
	return events


## Both directions reach `JUMPTABLE_EXIT` on the same frame: the two rides are
## the same distance in opposite directions.
func test_both_directions_run_the_same_number_of_frames() -> void:
	for to_goldenrod: bool in [false, true]:
		var movie: Gen2MagnetTrain = Gen2MagnetTrain.create(to_goldenrod)
		_run(movie)
		assert_true(movie.finished(), "direction %s never finished" % to_goldenrod)
		assert_eq(movie.frame(), RIDE_FRAMES, "direction %s" % to_goldenrod)


## `MagnetTrain_LoadGFX_PlayMusic`'s `PlayMusic2` and `.TrainArrived`'s
## `PlaySFX`, which are the only two sounds the ride asks for.
func test_the_ride_plays_its_music_and_its_arrival() -> void:
	var movie: Gen2MagnetTrain = Gen2MagnetTrain.create(false)
	var events: Array = movie.drain_events()
	assert_eq(events.size(), 1)
	assert_eq(events[0]["type"], &"play_music")
	assert_eq(int(events[0]["music"]), Gen2MagnetTrain.MUSIC)
	var rest: Array = _run(movie)
	assert_eq(rest.size(), 1)
	assert_eq(rest[0]["type"], &"play_sfx")
	assert_eq(int(rest[0]["sfx"]), Gen2MagnetTrain.SFX_ARRIVED)


## `MagnetTrain_UpdateLYOverrides`' three runs, read a scanline late: 48 lines
## carry `wMagnetTrainPosition` and the 96 around them carry twice
## `wMagnetTrainOffset`.
func test_the_override_buffer_is_three_bands_read_a_line_late() -> void:
	var movie: Gen2MagnetTrain = Gen2MagnetTrain.create(false)
	var lines: PackedInt32Array = movie.line_offsets()
	assert_eq(lines.size(), Gen2MagnetTrain.HEIGHT)
	assert_eq(lines[0], lines[1], "line 0 shares the first entry")
	var bands: Array[int] = []
	for line: int in lines.size():
		if bands.is_empty() or bands[bands.size() - 1] != lines[line]:
			bands.append(lines[line])
	assert_eq(bands.size(), 3, "the buffer is not three bands")
	assert_eq(bands[0], bands[2], "the bushes do not share an offset")
	assert_eq(bands[1], 12 * Gen2MagnetTrain.TILE, "the train's own band")
	assert_eq(bands[0], (12 * Gen2MagnetTrain.TILE * 2) & 0xFF, "the bushes' band")


## The player rides the train rather than the screen: `wGlobalAnimXOffset` grows
## by exactly what `wMagnetTrainPosition` loses, so the sprite stands in the same
## train window from the first frame to the last.
func test_the_player_holds_one_place_in_the_train() -> void:
	for to_goldenrod: bool in [false, true]:
		var movie: Gen2MagnetTrain = Gen2MagnetTrain.create(to_goldenrod)
		var window: int = -1
		var frames: int = 0
		while not movie.finished() and movie.frame() < FRAME_CAP:
			movie.advance_frame()
			var local: int = (movie.player_at().x + movie.line_offsets()[70]) & 0xFF
			if window < 0:
				window = local
			assert_eq(local, window, "the player left the train window")
			frames += 1
		assert_eq(frames, RIDE_FRAMES)


## `.MoveTrain1` steps one pixel a frame and `.MoveTrain2` two, which is 192 of
## the map's 256 either way.
func test_the_train_travels_the_same_distance_in_both_directions() -> void:
	for to_goldenrod: bool in [false, true]:
		var movie: Gen2MagnetTrain = Gen2MagnetTrain.create(to_goldenrod)
		var first: int = movie.line_offsets()[70]
		_run(movie)
		var moved: int = (first - movie.line_offsets()[70]) * (-1 if to_goldenrod else 1)
		assert_eq(posmod(moved, 0x100), TRAVEL, "direction %s" % to_goldenrod)


## `oamframe ..., 8` four times: two drawings, the second of them mirrored on its
## second pass, which is `Facings`' own down row.
func test_the_player_walks_through_the_four_oam_frames() -> void:
	var movie: Gen2MagnetTrain = Gen2MagnetTrain.create(false)
	var seen: Array[int] = []
	for _frame: int in 4 * Gen2MagnetTrain.SPRITE_FRAME_LENGTH:
		movie.advance_frame()
		if seen.is_empty() or seen[seen.size() - 1] != movie.player_frame():
			seen.append(movie.player_frame())
	assert_eq(seen, [0, 1, 0, 3] as Array[int])
