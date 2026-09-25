extends GutTest

## `GoldSilverIntro` (pokegold/engine/movie/intro.asm) where it can be checked
## without a cartridge: the scene walk, the button, the framesets and OAM sets
## the sprites index, and the wave row.
##
## The movie itself needs the art, so its frames, scene starts and sounds are
## pinned in `tools/checks/gs_intro.gd` against a real cache instead.


## A movie with no cache behind it still spends its frames, which is what lets a
## caller run the budget without an animation layer.
func test_a_movie_without_art_still_walks_its_scenes() -> void:
	var movie: Gen2GoldSilverIntro = Gen2GoldSilverIntro.create(null)
	for _frame: int in 4000:
		if movie.finished():
			break
		movie.advance_frame()
	assert_true(movie.finished(), "the exit bit is reached without a cache")
	assert_eq(movie.scene(), Gen2Layout.GS_INTRO_SCENES - 1)


## `.PlayFrame` reads `hJoyLast and PAD_BUTTONS` before anything else, so a
## press ends the movie wherever it lands and a second one changes nothing.
func test_a_button_ends_the_movie_once() -> void:
	var movie: Gen2GoldSilverIntro = Gen2GoldSilverIntro.create(null)
	movie.advance_frame()
	assert_true(movie.cancel())
	assert_true(movie.finished())
	assert_false(movie.cancel(), "and the second press has nothing to end")


## Every `SpriteAnimObjects` row names a frameset this movie carries and a
## callback `PlaySpriteAnimations` answers, and every frameset entry names an
## OAM set the page holds.
func test_every_object_resolves_to_a_frameset_and_an_oam_set() -> void:
	for row_name: StringName in Gen2GoldSilverIntro.OBJECTS:
		var row: Dictionary = Gen2GoldSilverIntro.OBJECTS[row_name]
		assert_true(
			Gen2GoldSilverIntro.FRAMESETS.has(StringName(row["frameset"])), String(row_name)
		)
	for row_name: StringName in Gen2GoldSilverIntro.FRAMESETS:
		var frameset: Dictionary = Gen2GoldSilverIntro.FRAMESETS[row_name]
		assert_false((frameset["frames"] as Array).is_empty(), String(row_name))
		for entry: Array in frameset["frames"]:
			assert_between(
				int(entry[0]), 0, Gen2GoldSilverIntroPage.OAM_SETS.size() - 1, String(row_name)
			)
			assert_gt(int(entry[1]), 0, "%s lasts n + 1 frames" % row_name)


## `.OAMData_GSIntroStarter` is a five-by-five pic, so the three runs are
## twenty-five tiles apart and none of them overlaps the next.
func test_the_starter_pics_do_not_overlap_each_other() -> void:
	var tiles: int = Gen2GoldSilverIntroPage.STARTER_TILES
	var pics: Array = Gen2GoldSilverIntroPage.STARTER_PICS
	for index: int in pics.size() - 1:
		assert_gte(
			int((pics[index + 1] as Dictionary)["vtile"])
				- int((pics[index] as Dictionary)["vtile"]),
			tiles * tiles
		)


## `Intro_CheckSCYEvent`'s jumptable is keyed by `hSCY` itself, and the scene
## walks it upward from $80, so every entry has to sit in that run.
func test_every_scy_event_is_reachable_from_the_scenes_own_start() -> void:
	for scy: int in Gen2GoldSilverIntro.SCY_EVENTS:
		assert_between(int(scy), 0x80, 0xFF)


## `Intro_AnimateOceanWaves` copies to `vBGMap0 tile $1e`, which is the map's
## byte 480 and so the whole of row 15, never the byte $1e that reading the
## operand as an offset gives. Its four tiles repeat across all thirty-two
## columns and the set steps with `wIntroFrameCounter2`.
func test_the_ocean_waves_fill_one_whole_map_row() -> void:
	var movie: Gen2GoldSilverIntro = Gen2GoldSilverIntro.create(null)
	for _frame: int in 700:
		movie.advance_frame()
	var map: PackedByteArray = movie.bg_map()
	var first: int = Gen2GoldSilverIntro.WAVE_ROW * Gen2GoldSilverIntro.MAP_COLUMNS
	for column: int in Gen2GoldSilverIntro.MAP_COLUMNS:
		assert_between(map[first + column], 0x70, 0x7F)
		assert_eq(map[first + column] & 0x03, column & 0x03, "four tiles repeated")
	assert_eq(map[0x1E], 0, "and not the byte $1e the operand reads as an offset")
