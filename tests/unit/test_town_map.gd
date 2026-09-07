extends GutTest

## `_TownMap`'s region choice and cursor walk, and `DisplayTownMap`'s own walk
## over `TownMapOrder` beside it, which is all of the region map that is not
## pixels. The page and the imported art are covered by
## `tools/preview_town_map.gd` against a real cache.

## `TownMapOrder`'s own head: PALLET_TOWN, ROUTE_1, VIRIDIAN_CITY, ROUTE_2.
const GEN1_ORDER: Array[int] = [0, 12, 1, 13]
## OAKS_LAB, which is an indoor map standing on Pallet Town's own point.
const GEN1_OAKS_LAB: int = 40


func test_johto_window_is_the_whole_region_and_the_cursor_wraps() -> void:
	var map := Gen2TownMap.create(Gen2TownMap.JOHTO_LANDMARK, true)
	assert_eq(map.region(), Gen2TownMap.REGION_JOHTO)
	assert_eq(map.first_landmark(), 1)
	assert_eq(map.last_landmark(), 46)
	assert_eq(map.cursor, 1)

	map.press(PokeButton.UP)
	assert_eq(map.cursor, 2)
	map.press(PokeButton.DOWN)
	assert_eq(map.cursor, 1)
	## `.pressed_down` rewinds to one past the window's end and steps back.
	map.press(PokeButton.DOWN)
	assert_eq(map.cursor, 46)
	map.press(PokeButton.UP)
	assert_eq(map.cursor, 1)


func test_gold_and_silver_windows_sit_one_landmark_lower() -> void:
	var map := Gen2TownMap.create(Gen2TownMap.JOHTO_LANDMARK, false)
	assert_eq(map.last_landmark(), 45)
	map.press(PokeButton.DOWN)
	assert_eq(map.cursor, 45)


func test_kanto_opens_on_the_victory_road_window_until_the_hall_of_fame() -> void:
	var sealed := Gen2TownMap.create(71, true)
	assert_eq(sealed.region(), Gen2TownMap.REGION_KANTO)
	assert_eq(sealed.first_landmark(), Gen2TownMap.LANDMARK_VICTORY_ROAD)
	assert_eq(sealed.last_landmark(), Gen2TownMap.LANDMARK_ROUTE_28)

	var opened := Gen2TownMap.create(71, true, true)
	assert_eq(opened.first_landmark(), 47)
	assert_eq(opened.last_landmark(), Gen2TownMap.LANDMARK_ROUTE_28)


func test_a_cursor_outside_the_window_walks_into_it_rather_than_being_clamped() -> void:
	## `_TownMap` writes the cursor from the player's own landmark and never
	## clamps it, so a Kanto map opened before the Hall of Fame starts below the
	## window and the first press lands inside it.
	var map := Gen2TownMap.create(47, true)
	assert_eq(map.cursor, 47)
	map.press(PokeButton.UP)
	assert_eq(map.cursor, 48)
	map.press(PokeButton.DOWN)
	assert_eq(map.cursor, 47)


func test_the_fast_ship_is_kanto_on_the_poster_and_johto_on_the_card() -> void:
	## `_TownMap.InitTilemap` picks by number alone; `InitPokegearTilemap.Map`
	## tests `LANDMARK_FAST_SHIP` first.
	var fast_ship: int = Gen2WorldRadio.fast_ship_landmark(true)
	var poster := Gen2TownMap.create(fast_ship, true)
	assert_eq(poster.region(), Gen2TownMap.REGION_KANTO)

	var card := Gen2TownMap.create(
		fast_ship, true, false, Gen2TownMap.SCREEN_POKEGEAR_CARD
	)
	assert_eq(card.region(), Gen2TownMap.REGION_JOHTO)


func test_only_the_d_pad_moves_the_cursor() -> void:
	var map := Gen2TownMap.create(10, true)
	assert_false(map.press(PokeButton.A))
	assert_false(map.press(PokeButton.LEFT))
	assert_eq(map.cursor, 10)


## `Pokedex_GetArea` opens on Johto whatever landmark it is given, holds the
## region in the cursor byte, and reaches Kanto only once the Hall of Fame flag
## is set.
func test_the_dex_area_walks_regions_rather_than_landmarks() -> void:
	var map := Gen2TownMap.create(71, true, false, Gen2TownMap.SCREEN_DEX_AREA)
	assert_eq(map.region(), Gen2TownMap.REGION_JOHTO)
	assert_false(map.press(PokeButton.LEFT))
	assert_false(map.press(PokeButton.UP))
	assert_false(map.press(PokeButton.RIGHT))
	assert_eq(map.region(), Gen2TownMap.REGION_JOHTO)

	var opened := Gen2TownMap.create(71, true, true, Gen2TownMap.SCREEN_DEX_AREA)
	assert_true(opened.press(PokeButton.RIGHT))
	assert_eq(opened.region(), Gen2TownMap.REGION_KANTO)
	assert_false(opened.press(PokeButton.RIGHT))
	assert_true(opened.press(PokeButton.LEFT))
	assert_eq(opened.region(), Gen2TownMap.REGION_JOHTO)


## `.CheckPlayerLocation`, which counts the Fast Ship as Johto rather than by
## number the way the poster does.
func test_the_dex_area_draws_the_player_only_in_their_own_region() -> void:
	var johto := Gen2TownMap.create(1, true, true, Gen2TownMap.SCREEN_DEX_AREA)
	assert_true(johto.player_in_region())
	johto.press(PokeButton.RIGHT)
	assert_false(johto.player_in_region())

	var ship := Gen2TownMap.create(
		Gen2WorldRadio.fast_ship_landmark(true), true, true, Gen2TownMap.SCREEN_DEX_AREA
	)
	assert_true(ship.player_in_region())

	var kanto := Gen2TownMap.create(47, true, true, Gen2TownMap.SCREEN_DEX_AREA)
	assert_false(kanto.player_in_region())
	kanto.press(PokeButton.RIGHT)
	assert_true(kanto.player_in_region())


## `_FlyMap`, whose cursor is a `FLY_*` index rather than a landmark and whose
## walk skips every flypoint the player has not visited.

func test_the_fly_map_opens_on_the_region_the_player_is_in() -> void:
	var johto := Gen2TownMap.fly(Gen2TownMap.JOHTO_LANDMARK, false, [] as Array[int], true)
	assert_eq(johto.region(), Gen2TownMap.REGION_JOHTO)
	assert_eq(johto.cursor, 0, "New Bark is Johto's default")
	assert_eq(johto.first_landmark(), 0)
	assert_eq(johto.last_landmark(), Gen2Layout.KANTO_FLYPOINT - 1)

	var kanto := Gen2TownMap.fly(
		60, true, [Gen2TownMap.FLY_INDIGO] as Array[int], true
	)
	assert_eq(kanto.region(), Gen2TownMap.REGION_KANTO)
	assert_eq(kanto.cursor, Gen2TownMap.FLY_INDIGO, "Indigo is Kanto's default")
	assert_eq(kanto.first_landmark(), Gen2Layout.KANTO_FLYPOINT)
	assert_eq(kanto.last_landmark(), Gen2Layout.FLYPOINT_COUNT - 1)
	# The player icon still says where the player is standing.
	assert_eq(kanto.player_landmark, 60)


func test_kanto_falls_back_to_johtos_map_until_indigo_plateau() -> void:
	# `.NoKanto`, which is what stops the source's own crash on a region with no
	# flypoint enabled.
	var map := Gen2TownMap.fly(60, true, [] as Array[int], true)
	assert_eq(map.region(), Gen2TownMap.REGION_JOHTO)
	assert_eq(map.cursor, 0)


func test_the_fly_cursor_skips_every_flypoint_that_has_not_been_visited() -> void:
	# Violet is flypoint 2 and Goldenrod 4; nothing between them is visited.
	var map := Gen2TownMap.fly(
		Gen2TownMap.JOHTO_LANDMARK, false, [2, 4] as Array[int], true
	)
	map.press(PokeButton.UP)
	assert_eq(map.cursor, 2)
	map.press(PokeButton.UP)
	assert_eq(map.cursor, 4)
	# Wrapping past the end lands back on the default, which is on the map
	# whether or not it has been visited.
	map.press(PokeButton.UP)
	assert_eq(map.cursor, 0)
	map.press(PokeButton.DOWN)
	assert_eq(map.cursor, 4)


func test_a_fly_map_with_nothing_visited_holds_its_default() -> void:
	var map := Gen2TownMap.fly(Gen2TownMap.JOHTO_LANDMARK, false, [] as Array[int], true)
	for press: int in [PokeButton.UP, PokeButton.DOWN, PokeButton.UP]:
		map.press(press)
		assert_eq(map.cursor, 0)


func test_the_generation_1_map_opens_on_wcurmap_with_the_order_still_at_zero() -> void:
	## `.enterLoop` draws the cursor on `wCurMap` while `wWhichTownMapLocation`
	## is zero, so the first UP press walks to the order's second row.
	var map := Gen2TownMap.create_gen1(GEN1_OAKS_LAB, PackedInt32Array(GEN1_ORDER))
	assert_eq(map.region(), Gen2TownMap.REGION_KANTO)
	assert_eq(map.cursor, GEN1_OAKS_LAB)
	assert_eq(map.player_landmark, GEN1_OAKS_LAB)
	assert_false(map.row_cleared)

	map.press(PokeButton.UP)
	assert_eq(map.cursor, GEN1_ORDER[1])
	assert_true(map.row_cleared)
	assert_eq(map.arrow_hidden, 0)


func test_the_generation_1_cursor_wraps_both_ways_round_the_order() -> void:
	var map := Gen2TownMap.create_gen1(0, PackedInt32Array(GEN1_ORDER))
	map.press(PokeButton.DOWN)
	assert_eq(map.cursor, GEN1_ORDER[GEN1_ORDER.size() - 1])
	assert_eq(map.arrow_hidden, 1)
	map.press(PokeButton.UP)
	assert_eq(map.cursor, GEN1_ORDER[0])
	## Neither LEFT nor A moves it: `.inputLoop` watches four buttons and the
	## d-pad's other axis is not among them.
	assert_false(map.press(PokeButton.LEFT))
	assert_eq(map.cursor, GEN1_ORDER[0])


func test_the_generation_1_fly_walk_skips_a_town_that_was_not_visited() -> void:
	## `BuildFlyLocationsList` with Pallet, Pewter and Cerulean visited.
	var towns := PackedInt32Array([
		0, Gen1Layout.TOWN_MAP_NOT_VISITED, 2, 3,
		Gen1Layout.TOWN_MAP_NOT_VISITED, Gen1Layout.TOWN_MAP_NOT_VISITED,
	])
	var map := Gen2TownMap.fly_gen1(0, towns)
	assert_eq(map.cursor, 0)
	map.press(PokeButton.UP)
	assert_eq(map.cursor, 2)
	map.press(PokeButton.UP)
	assert_eq(map.cursor, 3)
	## `.wrapToStartOfList` skips the unvisited test, and the first town is the
	## one the source leaves reachable regardless.
	map.press(PokeButton.UP)
	assert_eq(map.cursor, 0)
	## `.pressedDown` keeps skipping through the wrap, where UP does not.
	map.press(PokeButton.DOWN)
	assert_eq(map.cursor, 3)
