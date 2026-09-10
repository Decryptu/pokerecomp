extends GutTest

## `Credits` and `ParseCredits` (`engine/movie/credits.asm`) over a fixture
## cache, and [Gen2CreditsPage] over the same one.
##
## The model is scene-free but data-driven: the script, the strings, the palettes
## and `.Frames` all come out of a cache, so the fixture is what makes a case
## here say anything.

const Fixture := preload("res://tests/integration/world_trainer_fixture.gd")

## The fixture script's waits, as ticks: STAFF then 2, the music beat 1 and 1,
## the two names 2, the copyright 1, The End 1.
const FIRST_WAIT: int = 2

var _data: GameData = null


func before_each() -> void:
	Fixture.build()
	_data = GameData.open_directory(Fixture.directory())


func after_each() -> void:
	RomCache.clear(Fixture.directory())


func _gold() -> GameData:
	Fixture.build(RomRegistry.GOLD)
	return GameData.open_directory(Fixture.directory(RomRegistry.GOLD))


func _spend(credits: Gen2Credits, frames: int, held: Array = []) -> Array:
	var events: Array = []
	for _frame: int in frames:
		events.append_array(credits.advance_frame(held))
	return events


func _cell(map: PackedInt32Array, column: int, row: int) -> int:
	return map[row * Gen2Credits.COLUMNS + column]


## `ConstructCreditsTilemap`: the banner is five copies of one 4x4 cell, so the
## tile at a column is its position within that cell.
func test_the_banner_is_five_copies_of_one_four_by_four_cell() -> void:
	var credits: Gen2Credits = Gen2Credits.create(_data)
	var map: PackedInt32Array = credits.bg_map()
	for row: int in Gen2Credits.BANNER_ROWS:
		for column: int in Gen2Credits.COLUMNS:
			assert_eq(
				_cell(map, column, row),
				row * Gen2Credits.BANNER_COLUMNS + column % Gen2Credits.BANNER_COLUMNS
			)


## `DrawCreditsBorder`'s two bases, and the row each band sits on, which is where
## the two profiles part: Crystal gives the text four more rows and Gold and
## Silver a second banner.
func test_the_two_border_bands_sit_where_the_profile_puts_them() -> void:
	var crystal: PackedInt32Array = Gen2Credits.create(_data).bg_map()
	assert_eq(
		_cell(crystal, 5, Gen2Credits.BORDER_TOP_ROW),
		Gen2Credits.BORDER_TOP_TILE + 1
	)
	assert_eq(
		_cell(crystal, 0, Gen2Credits.BORDER_BOTTOM_ROW), Gen2Credits.BORDER_BOTTOM_TILE
	)

	var gold: PackedInt32Array = Gen2Credits.create(_gold()).bg_map()
	assert_eq(
		_cell(gold, 0, Gen2Credits.BORDER_BOTTOM_ROW_GOLD_SILVER),
		Gen2Credits.BORDER_BOTTOM_TILE
	)
	assert_eq(
		_cell(gold, 0, Gen2Credits.BORDER_BOTTOM_ROW_GOLD_SILVER + 1), 0,
		"and the second banner starts under it"
	)


## `wAttrmap`: the banner, the two bands and the text region. Gold and Silver
## give the bands and the text one slot and both banners the other.
func test_the_attribute_map_is_the_three_slots_the_profile_uses() -> void:
	var crystal: PackedInt32Array = Gen2Credits.create(_data).attributes()
	assert_eq(_cell(crystal, 0, 0), Gen2Credits.PALETTE_BANNER)
	assert_eq(_cell(crystal, 0, Gen2Credits.BORDER_TOP_ROW), Gen2Credits.PALETTE_BORDER)
	assert_eq(_cell(crystal, 0, Gen2Credits.TEXT_TOP_ROW), Gen2Credits.PALETTE_TEXT)
	assert_eq(_cell(crystal, 0, Gen2Credits.BORDER_BOTTOM_ROW), Gen2Credits.PALETTE_BORDER)

	var gold: PackedInt32Array = Gen2Credits.create(_gold()).attributes()
	assert_eq(_cell(gold, 0, 0), Gen2Credits.PALETTE_BANNER)
	assert_eq(_cell(gold, 0, Gen2Credits.TEXT_TOP_ROW), Gen2Credits.PALETTE_BORDER)
	assert_eq(
		_cell(gold, 0, Gen2Credits.BORDER_BOTTOM_ROW_GOLD_SILVER + 1),
		Gen2Credits.PALETTE_BANNER
	)


## `.Jumptable` is thirteen entries and `ParseCredits` is the first, so one
## `CREDITS_WAIT` tick costs thirteen frames.
func test_a_wait_tick_is_a_whole_jumptable_cycle() -> void:
	var credits: Gen2Credits = Gen2Credits.create(_data)
	_spend(credits, 1)
	assert_eq(credits.timer(), FIRST_WAIT)

	_spend(credits, Gen2Credits.CYCLE_FRAMES - 1)
	assert_eq(credits.timer(), FIRST_WAIT, "and nothing else in the cycle spends one")

	_spend(credits, 1)
	assert_eq(credits.timer(), FIRST_WAIT - 1)


## The cycle a caller can read: `wJumptableIndex` walks the thirteen entries in
## order and wraps back onto `ParseCredits`, which is the one step that spends a
## tick. Only that step and the one in front of it are ever followed by a parse,
## which is what lets a test tell `Credits_HandleBButton` apart from the wait.
func test_the_step_walks_the_cycle_and_wraps_onto_parse() -> void:
	var credits: Gen2Credits = Gen2Credits.create(_data)
	assert_eq(credits.step(), Gen2Credits.STEP_PARSE, "the loop opens on a parse")
	for entry: int in range(1, Gen2Credits.CYCLE_FRAMES):
		_spend(credits, 1)
		assert_eq(credits.step(), entry)
	_spend(credits, 1)
	assert_eq(credits.step(), Gen2Credits.STEP_PARSE, "and the last entry wraps")


## `.print`: the string's line operand is two rows per step from row 6, and
## `NextLineChar` drops two more at the string's own starting column.
func test_a_string_prints_two_rows_a_line_and_wraps_at_its_own_column() -> void:
	var credits: Gen2Credits = Gen2Credits.create(_data)
	_spend(credits, Gen2Credits.CYCLE_FRAMES * (FIRST_WAIT + 1))
	var map: PackedInt32Array = credits.bg_map()
	## `db CREDITS_STAFF, 1`, whose string is "#", a letter, `<NEXT>`, a letter.
	var row: int = Gen2Credits.TEXT_TOP_ROW + Gen2Credits.TEXT_LINE_SPACING
	var poke: PackedByteArray = Gen2Text.encode(Gen2Credits.POKE_TEXT)
	for index: int in poke.size():
		assert_eq(_cell(map, index, row), poke[index], "# is a string, not a tile")
	assert_eq(_cell(map, poke.size(), row), 0x85)
	assert_eq(_cell(map, 0, row + Gen2Credits.TEXT_LINE_SPACING), 0x86)


## `.copyright`'s own `hlcoord 2, 6`, the one string that does not start at
## column 0.
func test_the_copyright_string_starts_two_columns_in() -> void:
	var credits: Gen2Credits = Gen2Credits.create(_data)
	## Past the staff wait, the music beat's two waits and the two names' wait.
	_spend(credits, Gen2Credits.CYCLE_FRAMES * 11)
	var map: PackedInt32Array = credits.bg_map()
	var row: int = Gen2Credits.TEXT_TOP_ROW + Gen2Credits.TEXT_LINE_SPACING
	assert_eq(
		_cell(map, Gen2Credits.COPYRIGHT_COLUMN, row), Gen2Layout.COPYRIGHT_FIRST_CODE
	)
	assert_eq(
		_cell(map, Gen2Credits.COPYRIGHT_COLUMN, row + Gen2Credits.TEXT_LINE_SPACING),
		Gen2Layout.COPYRIGHT_FIRST_CODE + 2,
		"and its <NEXT> keeps that column"
	)


## `CREDITS_WAIT2` leaves `hBGMapMode` off, so the batch it closes is written to
## the tilemap and never copied to the BG map.
func test_a_wait2_batch_is_written_and_never_shown() -> void:
	var credits: Gen2Credits = Gen2Credits.create(_data)
	## The staff batch, then the one holding `CREDITS_MUSIC` and `CREDITS_WAIT2`.
	_spend(credits, Gen2Credits.CYCLE_FRAMES * (FIRST_WAIT + 1) + 1)
	var row: int = Gen2Credits.TEXT_TOP_ROW + Gen2Credits.TEXT_LINE_SPACING
	assert_eq(
		_cell(credits.tilemap(), 0, row), Gen2Credits.BLANK_TILE,
		"the tilemap has been cleared"
	)
	assert_ne(
		_cell(credits.bg_map(), 0, row), Gen2Credits.BLANK_TILE,
		"and the staff batch is still on screen"
	)


## `.end` clears the text region and returns without turning the copy back on,
## which is the whole reason "The End" stays up.
func test_the_end_survives_the_clear_in_front_of_credits_end() -> void:
	var credits: Gen2Credits = Gen2Credits.create(_data)
	_spend(credits, Gen2Credits.CYCLE_FRAMES * 40)
	assert_true(credits.finished())
	assert_eq(
		_cell(credits.bg_map(), Gen2Credits.THE_END_AT.x, Gen2Credits.THE_END_AT.y),
		Gen2Credits.THE_END_TILE
	)
	assert_eq(
		_cell(credits.tilemap(), Gen2Credits.THE_END_AT.x, Gen2Credits.THE_END_AT.y),
		Gen2Credits.BLANK_TILE,
		"and the tilemap under it was cleared"
	)


## `Credits_LoadBorderGFX` draws the frame the counter holds and steps it
## afterwards, and `.init` neither draws nor steps while the banner is cleared.
func test_the_banner_steps_once_per_graphics_request() -> void:
	var credits: Gen2Credits = Gen2Credits.create(_data)
	_spend(credits, Gen2Credits.CYCLE_FRAMES)
	assert_eq(credits.banner_block(), -1, "CREDITS_CLEAR holds it blank")

	## Past the two names' `CREDITS_SCENE, 1`, which is the fixture's own scene.
	_spend(credits, Gen2Credits.CYCLE_FRAMES * 7)
	var blocks: Array = []
	for _cycle: int in 3:
		_spend(credits, Gen2Credits.CYCLE_FRAMES)
		blocks.append(credits.banner_block())
	assert_eq(blocks.size(), 3)
	assert_ne(blocks[0], blocks[1], "and it is a different frame each cycle")


## Crystal requests graphics twice a cycle and Gold and Silver once, so the same
## number of cycles walks the banner twice as far on Crystal.
func test_crystal_steps_the_banner_twice_a_cycle() -> void:
	assert_eq(Gen2Credits.GFX_STEPS.size(), 2)
	assert_eq(Gen2Credits.GFX_STEPS_GOLD_SILVER.size(), 1)


## `Credits_LYOverride`'s `dec a / dec a`, which Gold and Silver replace with
## `inc a / inc a`. It is a byte, so Crystal's first step wraps.
func test_the_border_scroll_walks_two_pixels_a_cycle_each_way() -> void:
	var crystal: Gen2Credits = Gen2Credits.create(_data)
	_spend(crystal, Gen2Credits.CYCLE_FRAMES)
	assert_eq(crystal.scroll(), 0xFE)

	var gold: Gen2Credits = Gen2Credits.create(_gold())
	_spend(gold, Gen2Credits.CYCLE_FRAMES)
	assert_eq(gold.scroll(), 2)


## `.music`'s two `PlayMusic` calls, which the screen hands to the overworld's
## own player, and `.end`'s fade into MUSIC_POST_CREDITS.
func test_the_script_asks_for_its_music_and_fades_into_the_next() -> void:
	var credits: Gen2Credits = Gen2Credits.create(_data)
	var events: Array = _spend(credits, Gen2Credits.CYCLE_FRAMES * 40)
	var kinds: Array = []
	for event: Dictionary in events:
		kinds.append([StringName(event["type"]), int(event["music"])])
	assert_eq(kinds, [
		[&"music_requested", Gen2Credits.MUSIC_CREDITS],
		[&"music_fade_requested", Gen2Credits.MUSIC_POST_CREDITS],
	])


## `Credits_HandleBButton`, which refuses until the script has passed its header
## and refuses entirely without STATUSFLAGS_HALL_OF_FAME_F.
func test_b_only_skips_on_a_replay_and_only_past_the_header() -> void:
	var first: Gen2Credits = Gen2Credits.create(_data, false)
	_spend(first, Gen2Credits.CYCLE_FRAMES * 2, [PokeButton.B])
	assert_eq(first.timer(), FIRST_WAIT - 1, "an unskippable run spends one tick a cycle")

	var replay: Gen2Credits = Gen2Credits.create(_data, true)
	_spend(replay, 1, [PokeButton.B])
	assert_lt(
		replay.position(), Gen2Credits.SKIP_FROM_POSITION,
		"the header is still under the skip's own position"
	)
	assert_eq(replay.timer(), FIRST_WAIT, "so nothing was burned yet")

	_spend(replay, Gen2Credits.CYCLE_FRAMES * 7, [PokeButton.B])
	assert_gt(replay.position(), Gen2Credits.SKIP_FROM_POSITION)
	var standing: int = replay.timer()
	_spend(replay, 2, [PokeButton.B])
	assert_eq(replay.timer(), standing - 2, "and past it a held B burns a tick a frame")


## `Credits_HandleAButton` tests JUMPTABLE_EXIT_F, so A does nothing until the
## script has run out.
func test_a_only_leaves_once_the_script_has_run_out() -> void:
	var credits: Gen2Credits = Gen2Credits.create(_data)
	assert_false(credits.may_finish([PokeButton.A]))
	_spend(credits, Gen2Credits.CYCLE_FRAMES * 40)
	assert_true(credits.finished())
	assert_false(credits.may_finish([]), "and it is a held button, not a state")
	assert_true(credits.may_finish([PokeButton.A]))


## The page resolves a banner tile through `.Frames`' block rather than through
## the strip's own position, which is what makes one sheet four animations.
func test_the_page_draws_the_banner_out_of_the_block_the_frame_names() -> void:
	var page: Gen2CreditsPage = Gen2CreditsPage.from_data(_data)
	assert_true(page.ready())
	var credits: Gen2Credits = Gen2Credits.create(_data)
	var map: PackedInt32Array = credits.bg_map()
	for block: int in [0, 1, 2]:
		var indices: PackedByteArray = page.compose(map, block)
		assert_eq(
			indices[0], block % Fixture.CREDITS_BLOCK_INDEXES,
			"block %d draws its own tiles" % block
		)
	assert_eq(
		page.compose(map, -1)[0], Gen2Credits.BLANK_FRAME_INDEX,
		"and a cleared banner is the solid frame, not an empty cell"
	)


## `GetCreditsPalette`'s Gold and Silver branch blacks out the last colour of the
## slot the border and the text share, which is the one the font's ink lands on.
func test_gold_blacks_out_the_text_slots_last_colour() -> void:
	var gold: GameData = _gold()
	var page: Gen2CreditsPage = Gen2CreditsPage.from_data(gold)
	var border: PackedColorArray = page.palette(gold, 0, Gen2Credits.PALETTE_BORDER)
	assert_eq(border[Gen2Layout.CREDITS_PALETTE_COLORS - 1], Color.BLACK)
	assert_ne(
		page.palette(gold, 0, Gen2Credits.PALETTE_BANNER)[
			Gen2Layout.CREDITS_PALETTE_COLORS - 1
		],
		Color.BLACK,
		"and the banner keeps its own"
	)

	var crystal_page: Gen2CreditsPage = Gen2CreditsPage.from_data(_data)
	assert_ne(
		crystal_page.palette(_data, 0, Gen2Credits.PALETTE_BORDER)[
			Gen2Layout.CREDITS_PALETTE_COLORS - 1
		],
		Color.BLACK,
		"and Crystal's three palettes are left alone"
	)


## `hLCDCPointer` is LOW(rSCX) and `Credits_LYOverride` fills only the two border
## bands, so nothing else on the screen moves with it.
func test_only_the_border_rows_are_scrolled() -> void:
	var credits: Gen2Credits = Gen2Credits.create(_data)
	assert_eq(credits.scroll_rows(), [
		Gen2Credits.BORDER_TOP_ROW, Gen2Credits.BORDER_BOTTOM_ROW,
	])
	assert_eq(
		Gen2Credits.create(_gold()).scroll_rows(),
		[Gen2Credits.BORDER_TOP_ROW, Gen2Credits.BORDER_BOTTOM_ROW_GOLD_SILVER]
	)


const PokedexFixture := preload("res://tests/unit/pokedex_fixture.gd")


func _gen1() -> Gen1Credits:
	return Gen1Credits.create_gen1(PokedexFixture.build_gen1())


## `HallOfFamePC`: `ClearScreen` and `ld c, 100` of white, then the two black
## bands and `PlayMusic MUSIC_CREDITS`, then `ld c, 128` before the first
## screen.
func test_generation_1_opens_white_then_raises_the_bands_with_the_music() -> void:
	var credits: Gen1Credits = _gen1()
	assert_eq(credits.bgp(), Gen1Credits.BGP_WHITE)
	assert_eq(_spend(credits, Gen1Credits.OPEN_FRAMES - 1).size(), 0)
	assert_eq(_cell(credits.bg_map(), 0, 0), Gen2Credits.BLANK_TILE, "no bands yet")
	var events: Array = credits.advance_frame()
	assert_eq(events.size(), 1)
	assert_eq(int(events[0]["music"]), Gen2Credits.MUSIC_CREDITS)
	var map: PackedInt32Array = credits.bg_map()
	for row: int in Gen1Credits.BAND_ROWS:
		assert_eq(_cell(map, 5, row), Gen1Credits.BLACK_TILE)
		assert_eq(_cell(map, 5, Gen1Credits.BAND_BOTTOM_ROW + row), Gen1Credits.BLACK_TILE)
	assert_eq(_cell(map, 5, Gen1Credits.MIDDLE_FIRST_ROW), Gen2Credits.BLANK_TILE)
	assert_eq(credits.bgp(), Gen1Credits.BGP_HIDDEN)
	assert_eq(credits.position(), 0, "nothing parsed until the lead is spent")
	_spend(credits, Gen1Credits.LEAD_FRAMES)
	assert_eq(credits.position(), 2, "the first string and its command")
	RomCache.clear(PokedexFixture.gen1_directory())


## `.fadeInTextAndShowMon`: `FadeInCredits` walks `HoFGBPalettes` five frames a
## step, the wait follows, and `DisplayCreditsMon` slides the next mon across
## with everything black, then leaves colour 2 white for the next screen.
func test_generation_1_fades_waits_and_slides_the_mon() -> void:
	var credits: Gen1Credits = _gen1()
	_spend(credits, Gen1Credits.OPEN_FRAMES + Gen1Credits.LEAD_FRAMES)
	var map: PackedInt32Array = credits.bg_map()
	assert_eq(_cell(map, 7, Gen2Credits.TEXT_TOP_ROW), 0x92, "STAFF at its own column")
	for step: int in Gen1Credits.FADE_PALETTES.size():
		_spend(credits, 1)
		assert_eq(credits.bgp(), Gen1Credits.FADE_PALETTES[step], "step %d" % step)
		_spend(credits, Gen1Credits.FADE_STEP_FRAMES - 1)
	_spend(credits, int(Gen1Credits.WAITS[Gen1Layout.CREDITS_TEXT_FADE_MON]))
	assert_eq(credits.sliding_mon(), 0, "the copies to VRAM come first")
	_spend(credits, Gen1Credits.SLIDE_SETUP_FRAMES)
	assert_eq(credits.sliding_mon(), 1)
	assert_eq(credits.bgp(), Gen1Credits.BGP_SILHOUETTE)
	assert_eq(credits.slide_scroll(), 0, "the first scroll frame shows SCX 0")
	_spend(credits, 1)
	assert_eq(credits.slide_scroll(), Gen1Credits.SLIDE_STEP)
	_spend(credits, Gen1Credits.SLIDE_FRAMES - 2)
	assert_eq(credits.slide_scroll(), (Gen1Credits.SLIDE_FRAMES - 1) * Gen1Credits.SLIDE_STEP)
	_spend(credits, 1)
	assert_eq(credits.sliding_mon(), 0)
	assert_eq(credits.bgp(), Gen1Credits.BGP_HIDDEN)
	assert_eq(_cell(credits.bg_map(), 7, Gen2Credits.TEXT_TOP_ROW), 0x8D, "NAME is up")
	RomCache.clear(PokedexFixture.gen1_directory())


## `CRED_COPYRIGHT` loads its tiles at $60 and prints the three rows at
## `hlcoord 2, 7` on the same screen; `CRED_THE_END` clears the middle, swaps
## the sheet, fades in and returns, which is the credits' end. The script's own
## delay then holds The End until A or B.
func test_generation_1_copyright_then_the_end_holds_for_a_press() -> void:
	var credits: Gen1Credits = _gen1()
	var frames: int = 0
	while not credits.finished() and frames < 5000:
		credits.advance_frame()
		frames += 1
		if credits.sheet() == Gen1Credits.SHEET_COPYRIGHT and credits.bgp() == Gen1Credits.BGP_HIDDEN \
			and credits.sliding_mon() == 0:
			break
	assert_eq(_cell(credits.bg_map(), 2, 7), 0x60)
	assert_eq(_cell(credits.bg_map(), 2, 11), 0x63, "a next drops two rows")
	while not credits.finished() and frames < 5000:
		credits.advance_frame()
		frames += 1
	assert_true(credits.finished())
	assert_eq(credits.sheet(), Gen1Credits.SHEET_THE_END)
	assert_eq(_cell(credits.bg_map(), Gen1Credits.THE_END_AT_GEN1.x, Gen1Credits.THE_END_AT_GEN1.y), 0x60)
	assert_eq(credits.bgp(), Gen1Credits.FADE_PALETTES[Gen1Credits.FADE_PALETTES.size() - 1])
	assert_false(credits.may_finish([PokeButton.A]), "the delay reads no joypad")
	_spend(credits, Gen1Credits.END_HOLD_FRAMES)
	assert_false(credits.may_finish([]))
	assert_true(credits.may_finish([PokeButton.A]))
	assert_true(credits.music_outlasts(), "nothing before jp Init stops it")
	RomCache.clear(PokedexFixture.gen1_directory())


## `ShiftFontColorIndex` zeroes the low plane, so the page's ink is colour 2,
## the black tile stays colour 3 and the sheet at $60 is drawn as it is.
func test_generation_1_page_composes_ink_on_colour_two() -> void:
	var data: GameData = PokedexFixture.build_gen1()
	var page: Gen2CreditsPage = Gen2CreditsPage.from_data(data)
	assert_true(page.ready())
	var credits: Gen1Credits = Gen1Credits.create_gen1(data)
	_spend(credits, Gen1Credits.OPEN_FRAMES + Gen1Credits.LEAD_FRAMES)
	var indices: PackedByteArray = page.compose_gen1(credits.bg_map(), Gen1Credits.SHEET_NONE)
	var width: int = Gen2Screen.WIDTH
	assert_eq(indices[0], PokeTiles.INK, "the band")
	assert_eq(indices[Gen2Credits.TEXT_TOP_ROW * Gen2Font.TILE * width + 7 * Gen2Font.TILE], 2, "the font, shifted")
	var image: Image = page.image(data, credits.frame_state())
	assert_eq(image.get_size(), Vector2i(Gen2Screen.WIDTH, Gen2Screen.HEIGHT))
	RomCache.clear(PokedexFixture.gen1_directory())
