extends GutTest

## The induction sequence and the panel it draws, against a synthetic cache.

const Fixture := preload("res://tests/integration/world_trainer_fixture.gd")

const TILE: int = Gen2Font.TILE

## `Rate`'s two texts, one box each at the fixture's short lengths.
const RATING_PAGES: int = 2
## `InitDisplayForHallOfFame`'s record box, which `HallOfFame_FadeOutMusic` puts
## up in front of the whole induction.
const SAVING_PAGES: int = 1

var _data: GameData = null


func before_each() -> void:
	Fixture.build()
	_data = GameData.open_directory(Fixture.directory())


func after_each() -> void:
	RomCache.clear(Fixture.directory())


func _save(species_list: Array, eggs: Array = []) -> Gen2SaveData:
	var save := Gen2SaveData.new()
	save.player_name = "ASH"
	for index: int in species_list.size():
		var mon := Gen2SaveMon.new()
		mon.species = int(species_list[index])
		mon.level = 10 + index
		mon.ot_id = 1234
		mon.is_egg = index in eggs
		save.party.append(mon)
	return save


func test_pages_follow_the_party_and_end_with_the_player() -> void:
	var pages: Array = Gen2HallOfFame.pages(_data, _save([1, 4]))
	assert_eq(pages.size(), SAVING_PAGES + 2 + RATING_PAGES)
	assert_eq(StringName(pages[0]["kind"]), Gen2HallOfFame.PAGE_SAVING)
	assert_eq(StringName(pages[1]["kind"]), Gen2HallOfFame.PAGE_MON)
	## `SCGB_PLAYER_OR_MON_FRONTPIC_PALS`, which the Hall of Fame asks for and
	## which reaches `GetMonNormalOrShinyPalettePointer`: a shiny is inducted in
	## its own colours, the same DV word the letter beside it comes from.
	assert_false(bool(pages[1]["shiny"]), "the fixture's party is not shiny")

	var shiny_save: Gen2SaveData = _save([1, 4])
	shiny_save.party[0].dvs = Gen2Stats.SHINY_DVS
	var shiny_pages: Array = Gen2HallOfFame.pages(_data, shiny_save)
	assert_true(bool(shiny_pages[1]["shiny"]))
	assert_false(bool(shiny_pages[2]["shiny"]), "and only the one that is")
	## The stored records take the same road: an induction is written and read
	## back, so a shiny in the viewer is drawn shiny however long ago it won.
	var stored: Array = Gen2HallOfFame.inducted([], shiny_save)
	var replayed: Array = Gen2HallOfFame.record_pages(_data, stored[0])
	assert_true(bool(replayed[0]["shiny"]), "the stored record kept it")
	assert_eq(int(pages[1]["species"]), 1)
	assert_eq(int(pages[1]["dex_number"]), 1)
	assert_eq(int(pages[2]["species"]), 4)
	assert_eq(StringName(pages[3]["kind"]), Gen2HallOfFame.PAGE_PLAYER)
	assert_eq(String(pages[3]["player_name"]), "ASH")


## `HOF_AnimatePlayerPic` ends on `farcall ProfOaksPCRating`, so the player's
## panel is answered once per box its two texts fill, and the sound the rating
## picked plays on the last of them.
func test_the_player_panel_carries_the_oak_rating() -> void:
	var pages: Array = Gen2HallOfFame.pages(_data, _save([1]))
	var counts: Dictionary = pages[2]
	var rating: Dictionary = pages[3]
	assert_eq(StringName(counts["kind"]), Gen2HallOfFame.PAGE_PLAYER)
	assert_eq(StringName(rating["kind"]), Gen2HallOfFame.PAGE_PLAYER)
	assert_string_contains(String((counts["lines"] as Array)[0]), "SEEN")
	assert_eq(String((rating["lines"] as Array)[0]), "RATING01", "nothing caught")
	assert_false(counts.has("sfx"), "the sound is on the rating, not the counts")
	assert_eq(int(rating["sfx"]), Fixture.OAK_FIRST_SFX)


## A cache with no rating table leaves the panel the source never stops on.
func test_a_cache_without_the_ratings_shows_the_bare_panel() -> void:
	var manifest: Dictionary = RomCache.read_manifest(Fixture.directory())
	manifest.erase("oak_ratings")
	RomCache.write_json(RomCache.manifest_path(Fixture.directory()), manifest)
	var data: GameData = GameData.open_directory(Fixture.directory())
	var pages: Array = Gen2HallOfFame.pages(data, _save([1]))
	assert_eq(pages.size(), SAVING_PAGES + 2)
	assert_false(pages[2].has("lines"))


## GetHallOfFameParty skips EGG without consuming a slot, so the egg is neither
## inducted nor counted against the six.
func test_an_egg_is_skipped_and_the_player_page_still_follows() -> void:
	var pages: Array = Gen2HallOfFame.pages(_data, _save([1, 4, 7], [1]))
	assert_eq(pages.size(), SAVING_PAGES + 2 + RATING_PAGES)
	assert_eq(int(pages[1]["species"]), 1)
	assert_eq(int(pages[2]["species"]), 7)
	assert_eq(StringName(pages[3]["kind"]), Gen2HallOfFame.PAGE_PLAYER)


## LoadHOFTeam's carry falls straight through to HOF_AnimatePlayerPic, so a
## party with nothing to induct still reaches the player's own panel.
func test_a_party_of_only_eggs_answers_the_player_page_alone() -> void:
	var pages: Array = Gen2HallOfFame.pages(_data, _save([1, 4], [0, 1]))
	assert_eq(pages.size(), SAVING_PAGES + RATING_PAGES)
	assert_eq(StringName(pages[1]["kind"]), Gen2HallOfFame.PAGE_PLAYER)


## DisplayHOFMon prints the species name and the nickname in two places, so a
## mon that was never renamed shows the same word twice rather than a blank.
func test_an_unnamed_mon_takes_its_species_name_as_its_nickname() -> void:
	var pages: Array = Gen2HallOfFame.pages(_data, _save([1]))
	assert_eq(String(pages[1]["nickname"]), String(pages[1]["species_name"]))
	assert_false(String(pages[1]["species_name"]).is_empty())


func test_a_nickname_is_kept() -> void:
	var save: Gen2SaveData = _save([1])
	(save.party[0] as Gen2SaveMon).nickname = "SPARKY"
	var pages: Array = Gen2HallOfFame.pages(_data, save)
	assert_eq(String(pages[1]["nickname"]), "SPARKY")


func test_pages_stop_at_a_full_party() -> void:
	var pages: Array = Gen2HallOfFame.pages(_data, _save([1, 2, 3, 4, 5, 6, 7]))
	assert_eq(pages.size(), SAVING_PAGES + Gen2HallOfFame.MAX_MONS + RATING_PAGES)


func test_a_missing_cache_or_save_answers_nothing() -> void:
	assert_eq(Gen2HallOfFame.pages(null, _save([1])).size(), 0)
	assert_eq(Gen2HallOfFame.pages(_data, null).size(), 0)


## The panel is drawn as indices on the hardware's own grid, so the whole page
## is one 160x144 buffer and the two text boxes are really in it.
func test_a_mon_panel_draws_both_boxes_on_a_full_screen_buffer() -> void:
	var page_renderer: Gen2HallOfFamePage = Gen2HallOfFamePage.from_data(_data)
	assert_not_null(page_renderer)
	var pages: Array = Gen2HallOfFame.pages(_data, _save([1]))
	var indices: PackedByteArray = page_renderer.draw(pages[1])
	assert_eq(indices.size(), Gen2Screen.WIDTH * Gen2Screen.HEIGHT)
	assert_true(_has_ink(indices, Gen2HallOfFamePage.MON_TOP_BOX))
	assert_true(_has_ink(indices, Gen2HallOfFamePage.MON_BOTTOM_BOX))


## `HOF_AnimatePlayerPic` opens the bottom box empty for the rating to print
## into, so the player's panel draws both.
func test_the_player_panel_draws_its_name_box_and_the_rating_box() -> void:
	var page_renderer: Gen2HallOfFamePage = Gen2HallOfFamePage.from_data(_data)
	var pages: Array = Gen2HallOfFame.pages(_data, _save([1]))
	var indices: PackedByteArray = page_renderer.draw(pages[2])
	assert_eq(indices.size(), Gen2Screen.WIDTH * Gen2Screen.HEIGHT)
	assert_true(_has_ink(indices, Gen2HallOfFamePage.PLAYER_BOX))
	assert_true(_has_ink(indices, Gen2HallOfFamePage.MON_BOTTOM_BOX))


## `HOF_AnimatePlayerPic` prints the trainer ID at `hlcoord 1, 6` and the play
## timer under `.PlayTime`, both of which the save carries.
func test_the_player_panel_prints_the_trainer_id_and_the_play_timer() -> void:
	var save: Gen2SaveData = _save([1])
	save.player_id = 456
	save.game_time = PokeGameTime.create(7, 5, 0, 0)
	var page: Dictionary = Gen2HallOfFame.pages(_data, save)[2]
	assert_eq(int(page["player_id"]), 456)
	assert_eq(int(page["hours"]), 7)
	assert_eq(String(page["minutes"]), "05")
	var indices: PackedByteArray = Gen2HallOfFamePage.from_data(_data).draw(page)
	# The fixture fills each sheet with an index of its own: 1 is battle_font,
	# 3 the main font, and the colon is the one glyph read from the main strip.
	assert_eq(_index_at(indices, Gen2HallOfFamePage.PLAYER_ID_LABEL), 1, "<ID>")
	assert_eq(_index_at(indices, Gen2HallOfFamePage.PLAYER_ID_NUMBER), 3, "the digits")
	assert_eq(_index_at(indices, Gen2HallOfFamePage.PLAY_TIME_LABEL), 3, "PLAY TIME")
	assert_eq(
		_index_at(indices, Gen2HallOfFamePage.PLAY_TIME_COLON), 2,
		"the colon comes off FontExtra rather than the battle strip"
	)
	assert_eq(Gen2Text.character(Gen2HallOfFamePage.CODE_COLON), ":")


## `.DisplayNewHallOfFamer`'s `ld c, 60` and pokegold's `ld c, 180`: an induction
## panel holds for frames rather than for a press.
func test_the_panel_hold_is_profile_split() -> void:
	assert_eq(
		Gen2HallOfFame.panel_frames(_data),
		Gen2HallOfFame.PANEL_FRAMES_CRYSTAL if Gen2WorldState.is_crystal_profile(_data)
		else Gen2HallOfFame.PANEL_FRAMES_GOLD_SILVER
	)


## Any non-zero palette index inside a tile rectangle. Index 0 is the page's
## own background, so ink means something was drawn there.
func _has_ink(indices: PackedByteArray, box: Rect2i) -> bool:
	for row: int in box.size.y * TILE:
		var y: int = box.position.y * TILE + row
		for column: int in box.size.x * TILE:
			var at: int = y * Gen2Screen.WIDTH + box.position.x * TILE + column
			if at < indices.size() and indices[at] != 0:
				return true
	return false


## The panel's columns are DisplayHOFMon's own. They were one tile right of it
## while plain words stood in for the glyphs the battle-extra strip carries, so
## the positions are pinned rather than left to the next reader to notice.
func test_the_panel_sits_on_the_source_columns() -> void:
	assert_eq(Gen2HallOfFamePage.DEX_LABEL, Vector2i(1, 13), "hlcoord 1, 13")
	assert_eq(Gen2HallOfFamePage.DEX_NUMBER, Vector2i(3, 13), "hlcoord 3, 13")
	assert_eq(Gen2HallOfFamePage.SPECIES_NAME, Vector2i(7, 13), "hlcoord 7, 13")
	assert_eq(Gen2HallOfFamePage.GENDER, Vector2i(18, 13), "hlcoord 18, 13")
	assert_eq(Gen2HallOfFamePage.NICKNAME_SLASH, Vector2i(8, 14), "hlcoord 8, 14")
	assert_eq(Gen2HallOfFamePage.LEVEL, Vector2i(1, 16), "hlcoord 1, 16")
	assert_eq(Gen2HallOfFamePage.OT_LABEL, Vector2i(7, 16), "hlcoord 7, 16")
	assert_eq(Gen2HallOfFamePage.OT_NUMBER, Vector2i(10, 16), "hlcoord 10, 16")
	# And the glyphs it places are the charmap's, read under the strip
	# halloffame.asm loads before printing any of this.
	assert_eq(Gen2HallOfFamePage.FONT, Gen2Text.FONT_BATTLE_EXTRA)
	assert_eq(
		Gen2Text.character(Gen2HallOfFamePage.CODE_NUMERO, Gen2HallOfFamePage.FONT), "№"
	)
	assert_eq(Gen2Text.character(Gen2HallOfFamePage.CODE_ID, Gen2HallOfFamePage.FONT), "<ID>")
	assert_eq(Gen2Text.character(Gen2HallOfFamePage.CODE_LEVEL, Gen2HallOfFamePage.FONT), "<LV>")
	assert_eq(Gen2Text.character(Gen2HallOfFamePage.CODE_DOT), ".")
	assert_eq(Gen2Text.character(Gen2HallOfFamePage.CODE_SLASH), "/")


## The three glyphs stood in as words before, so the columns they occupy are
## what proves they are drawn now: the dex label is two tiles, not three, and
## column 6 is the blank the source leaves before the name.
func test_the_dex_row_draws_two_label_tiles_and_leaves_column_six_blank() -> void:
	var page_renderer: Gen2HallOfFamePage = Gen2HallOfFamePage.from_data(_data)
	assert_not_null(page_renderer)
	var pages: Array = Gen2HallOfFame.pages(_data, _save([1]))
	var indices: PackedByteArray = page_renderer.draw(pages[1])
	# The fixture fills each sheet with an index of its own, so a drawn pixel
	# says which strip it came from: 1 is battle_font, 3 is the main font.
	assert_eq(_index_at(indices, Vector2i(1, 13)), 1, "№ comes off the battle strip")
	assert_eq(_index_at(indices, Vector2i(2, 13)), 3, "the dot is a main-font code")
	assert_eq(_index_at(indices, Vector2i(6, 13)), 0, "the blank before the name")
	assert_eq(_index_at(indices, Vector2i(7, 13)), 3, "the name starts at 7")
	assert_eq(_index_at(indices, Vector2i(1, 16)), 1, "the level symbol")
	assert_eq(_index_at(indices, Vector2i(7, 16)), 1, "<ID>")
	assert_eq(_index_at(indices, Vector2i(8, 16)), 1, "№")


## The palette index of a tile's top-left pixel.
func _index_at(indices: PackedByteArray, tile: Vector2i) -> int:
	var at: int = tile.y * TILE * Gen2Screen.WIDTH + tile.x * TILE
	return indices[at] if at < indices.size() else -1


const PokedexFixture := preload("res://tests/unit/pokedex_fixture.gd")

## `AnimateHallOfFame`'s own pages on a Generation 1 cache: `ld c, 100` of
## white, then per member the slide, the info box with its cry, HallOfFameText's
## box and `GBFadeOutToWhite`'s three palettes, then the player's slide and the
## three `HoFPrintTextAndDelay` boxes, a `cont` inside the rating waiting for
## its press.
func test_generation_1_pages_follow_animate_hall_of_fame() -> void:
	var data: GameData = PokedexFixture.build_gen1()
	var pages: Array = Gen2HallOfFame.pages(data, _save([1, 4]))
	assert_eq(pages.size(), 1 + 2 * 6 + 1 + 2 + 3 + 3)
	assert_eq(StringName(pages[0]["kind"]), Gen2HallOfFame.PAGE_BLANK)
	assert_eq(int(pages[0]["hold"]), Gen2HallOfFame.GEN1_OPEN_FRAMES)
	assert_true(bool(pages[0]["music"]), "PlayMusic MUSIC_HALL_OF_FAME after the white")
	assert_true(bool(pages[1]["slide"]))
	assert_eq(int(pages[1]["hold"]), Gen2HallOfFame.GEN1_SLIDE_FRAMES)
	assert_false(bool(pages[1]["cry"]), "the slide is silent")
	assert_eq(int(pages[2]["hold"]), Gen2HallOfFame.GEN1_INFO_FRAMES)
	assert_true(bool(pages[2].get("cry", true)), "HoFDisplayMonInfo ends on PlayCry")
	assert_eq(pages[2]["types"], [String(data.type_name(1)), String(data.type_name(2))] \
		if data.type_name(1) != data.type_name(2) else [String(data.type_name(1))])
	assert_true(bool(pages[3]["famed"]))
	assert_eq(int(pages[3]["hold"]), Gen2HallOfFame.GEN1_FAMED_FRAMES)
	for step: int in 3:
		assert_eq(int(pages[4 + step]["bgp"]), Gen2HallOfFame.GEN1_FADE_PALETTES[step])
		assert_eq(int(pages[4 + step]["hold"]), Gen2HallOfFame.GEN1_FADE_STEP_FRAMES)
	var player: int = 1 + 2 * 6
	assert_eq(StringName(pages[player]["kind"]), Gen2HallOfFame.PAGE_PLAYER)
	assert_true(bool(pages[player]["slide"]))
	assert_eq(pages[player + 1]["lines"], ["POKéDEX   Seen:  0", "         Owned:  0"])
	assert_eq(int(pages[player + 1]["hold"]), Gen2HallOfFame.GEN1_TEXT_FRAMES)
	assert_eq(pages[player + 2]["lines"], ["POKéDEX Rating<COLON>"], "one tile, one line")
	assert_eq(int(pages[player + 3]["hold"]), 0, "cont waits for the press")
	assert_eq(int(pages[player + 4]["hold"]), 0, "and the carried line's page does too")
	assert_eq(int(pages[player + 5]["hold"]), Gen2HallOfFame.GEN1_TEXT_FRAMES)
	assert_true(bool(pages[player + 6]["fade_music"]), "HoFFadeOutScreenAndMusic")
	RomCache.clear(PokedexFixture.gen1_directory())


## `sHallOfFame` keeps fifty teams and `wNumHoFTeams` stops at 255, and
## `PKMNLeaguePC` walks them oldest first with `wHoFTeamNo` on each panel.
func test_generation_1_records_keep_fifty_and_walk_oldest_first() -> void:
	var data: GameData = PokedexFixture.build_gen1()
	var records: Array = []
	for _win: int in Gen2HallOfFame.MAX_RECORDS_GEN1 + 1:
		records = Gen2HallOfFame.inducted(records, _save([1]), data)
	assert_eq(records.size(), Gen2HallOfFame.MAX_RECORDS_GEN1)
	assert_eq(Gen2HallOfFame.win_count(records), Gen2HallOfFame.MAX_RECORDS_GEN1 + 1)
	assert_eq(int(Gen2HallOfFame.record_at(data, records, 0)["win_count"]), 2, "the oldest kept")
	assert_eq(int(Gen2HallOfFame.record_at(_data, records, 0)["win_count"]), 51, "Crystal's newest")
	var page: Dictionary = Gen2HallOfFame.record_pages(
		data, Gen2HallOfFame.record_at(data, records, 0)
	)[0]
	assert_eq(int(page["team_number"]), 2)
	var indices: PackedByteArray = Gen2HallOfFamePage.from_data(data).draw(page)
	assert_true(_has_ink(indices, Gen2HallOfFamePage.GEN1_TEAM_BOX))
	assert_true(_has_ink(indices, Gen2HallOfFamePage.GEN1_INFO_BOX))
	RomCache.clear(PokedexFixture.gen1_directory())


## The Generation 1 panels: the slide draws nothing, the info box stands alone
## until HallOfFameText's box joins it, and the player's panel is its two boxes
## with `PrintText`'s under them.
func test_generation_1_panels_draw_their_own_boxes() -> void:
	var data: GameData = PokedexFixture.build_gen1()
	var renderer: Gen2HallOfFamePage = Gen2HallOfFamePage.from_data(data)
	var pages: Array = Gen2HallOfFame.pages(data, _save([1]))
	assert_eq(renderer.draw(pages[1]).count(0), Gen2Screen.WIDTH * Gen2Screen.HEIGHT)
	var info: PackedByteArray = renderer.draw(pages[2])
	assert_true(_has_ink(info, Gen2HallOfFamePage.GEN1_INFO_BOX))
	assert_false(_has_ink(info, Gen2HallOfFamePage.GEN1_FAMED_BOX))
	assert_true(_has_ink(renderer.draw(pages[3]), Gen2HallOfFamePage.GEN1_FAMED_BOX))
	var player: PackedByteArray = renderer.draw(pages[9])
	assert_true(_has_ink(player, Gen2HallOfFamePage.GEN1_NAME_BOX))
	assert_true(_has_ink(player, Gen2HallOfFamePage.GEN1_STATS_BOX))
	assert_true(_has_ink(player, Gen2HallOfFamePage.MON_BOTTOM_BOX))
	assert_eq(renderer.pic_at(), Gen2HallOfFamePage.player_pic_position(), "hlcoord 12, 5")
	## `SET_PAL_POKEMON_WHOLE_SCREEN`, then `FadePal6`: colour 3 falls to the
	## row's colour 2 on the first step.
	var colors: PackedColorArray = Gen2HallOfFame.page_palette(data, pages[4])
	assert_eq(colors[3], data.palette(1)[2])
	RomCache.clear(PokedexFixture.gen1_directory())
