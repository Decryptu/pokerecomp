extends GutTest

## The read-only snapshot a battle renderer is handed when the battle was
## entered from the world. It is built from a real Gen2WorldAPI over the same
## synthetic cache the rest of the world unit tests use.

const Fixture := preload("res://tests/integration/world_trainer_fixture.gd")

var _data: GameData = null


func before_all() -> void:
	Fixture.build()
	_data = GameData.open_directory(Fixture.directory())


func after_all() -> void:
	RomCache.clear(Fixture.directory())


func _world() -> Gen2WorldAPI:
	return Gen2WorldAPI.open(_data, 1, 1, Vector2i(4, 4))


func test_capture_copies_the_map_tileset_cell_and_facing() -> void:
	var world: Gen2WorldAPI = _world()
	world.player_facing = Gen2WorldSprite.FACING_LEFT
	var context: Gen2BattleWorldContext = Gen2BattleWorldContext.capture(
		world, Gen2WorldPalette.TIME_NIGHT
	)
	assert_eq(context.map_id, Vector2i(1, 1))
	assert_eq(context.map_group(), 1)
	assert_eq(context.map_number(), 1)
	assert_eq(context.tileset, world.current_map.tileset)
	assert_eq(context.player_cell, Vector2i(4, 4))
	assert_eq(context.player_facing, Gen2WorldSprite.FACING_LEFT)
	assert_eq(context.time_of_day, Gen2WorldPalette.TIME_NIGHT)


## A copy, not a handle: the whole point is that a renderer cannot reach world
## state through it once the fight has started.
func test_the_snapshot_does_not_follow_the_world_it_was_taken_from() -> void:
	var world: Gen2WorldAPI = _world()
	var context: Gen2BattleWorldContext = Gen2BattleWorldContext.capture(world, 0)
	world.player_cell = Vector2i(6, 6)
	world.player_facing = Gen2WorldSprite.FACING_UP
	assert_eq(context.player_cell, Vector2i(4, 4))
	assert_eq(context.player_facing, Gen2WorldSprite.FACING_DOWN)


## The world's own row when the caller does not name one, which is the map's
## rather than the clock's: a dark cave is night until Flash is used.
func test_an_unnamed_time_of_day_falls_back_to_the_maps_own_row() -> void:
	var world: Gen2WorldAPI = _world()
	world.set_object_time(22, Gen2WorldPalette.TIME_NIGHT)
	var context: Gen2BattleWorldContext = Gen2BattleWorldContext.capture(world)
	assert_eq(context.time_of_day, world.map_time_of_day())


func test_a_world_without_a_map_answers_nothing() -> void:
	assert_null(Gen2BattleWorldContext.capture(null))


## `RegionCheck` reads `GetWorldMapLocation`, which is what `PlayBattleMusic`
## picks a wild track off, so the snapshot has to carry it.
func test_capture_copies_the_maps_landmark() -> void:
	var world: Gen2WorldAPI = _world()
	var context: Gen2BattleWorldContext = Gen2BattleWorldContext.capture(world)
	assert_eq(context.landmark, world.landmark())
	assert_eq(int(context.to_dictionary()["landmark"]), world.landmark())


## The map as it stood, so a renderer staging the fight on it draws the cut tree
## gone and the dock after the ship: a copy, like the rest.
func test_capture_carries_the_changed_blocks_and_written_tiles() -> void:
	var world: Gen2WorldAPI = _world()
	## The fixture's tileset has one block, so the override is seeded as
	## `change_block` stores it.
	var block: int = 5
	world._block_overrides["1:1:1:1"] = block
	world._block_overrides["1:2:1:1"] = block
	world.erase_screen_rows(0, 1, 7)
	var context: Gen2BattleWorldContext = Gen2BattleWorldContext.capture(world)
	assert_eq(context.changed_blocks, {Vector2i(1, 1): block})
	assert_eq(context.written_tiles.size(), Gen1Lcd.MAP_SIDE)
	assert_eq(int(context.written_tiles[world.screen_origin_tile()]), 7)
	world.erase_screen_rows(1, 1, 8)
	assert_eq(context.written_tiles.size(), Gen1Lcd.MAP_SIDE, "a copy")


## `Gen2WorldDrawList.drawn_tile_at`: a written tile over the block, the band's
## repeated columns past the screen's twentieth while it scrolls, and a revision
## that moves with each edit and not with the band's offset or a hidden tree.
func test_the_draw_list_answers_the_tile_the_background_shows() -> void:
	var world: Gen2WorldAPI = _world()
	var effects := Gen2WorldEffects.new()
	var list := Gen2WorldDrawList.new(world, effects)
	var origin: Vector2i = world.screen_origin_tile()
	var plain: int = list.drawn_tile_at(origin)
	var revision: int = list.drawn_revision()
	world.erase_screen_rows(0, 1, plain + 1)
	assert_eq(list.drawn_tile_at(origin), plain + 1)
	assert_gt(list.drawn_revision(), revision)

	effects.start_gen1_ss_anne()
	while effects.ss_anne_band_offset() == 0:
		effects.advance_frame()
	var band: Dictionary = list.band()
	var row: int = (band["rows"] as Vector2i).x
	assert_eq(int(band["first_column"]), origin.x)
	assert_eq(int(band["reach"]), 127)
	var columns: int = Gen2WorldAPI.VIEW_PIXELS.x / PokeTiles.TILE_WIDTH
	for past: int in 4:
		assert_eq(
			list.drawn_tile_at(Vector2i(origin.x + columns + past, row)),
			list.drawn_tile_at(Vector2i(origin.x + columns - 2 + (past & 1), row)),
			"ScheduleEastColumnRedraw's copy"
		)
	revision = list.drawn_revision()
	effects.advance_frame()
	effects.advance_frame()
	assert_eq(list.drawn_revision(), revision, "the offset alone moves nothing")

	## A hidden Headbutt tree is a 32-frame overlay beside the background.
	var below: Vector2i = origin + Vector2i(0, 2)
	var standing: int = list.drawn_tile_at(below)
	effects.start_headbutt_tree(Vector2i(floori(below.x / 2.0), floori(below.y / 2.0)))
	assert_eq(list.hidden_tree_cells().size(), 1)
	assert_eq(list.drawn_tile_at(below), standing, "the tree is not the background")
	assert_eq(list.drawn_revision(), revision, "and moves nothing")
