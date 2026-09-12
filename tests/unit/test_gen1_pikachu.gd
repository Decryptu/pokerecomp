extends GutTest

## [Gen1Pikachu] on its own: the follow buffer and cadence are measured against
## the cartridge by `tools/trace_world_walk.gd ... pikachu`; what is pinned here
## is the arithmetic a trace does not reach.


func _view(cell: Vector2i, facing: int = Gen1Pikachu.FACING_DOWN) -> Gen1Pikachu.View:
	var view := Gen1Pikachu.View.new()
	view.cell = cell
	view.facing = facing
	return view


func _standing(cell: Vector2i, facing: int = Gen1Pikachu.FACING_DOWN) -> Gen1Pikachu:
	var pikachu := Gen1Pikachu.new()
	pikachu.set_party(true, false)
	pikachu.cell = cell
	pikachu.pixel = cell * Gen1Pikachu.CELL_PIXELS
	pikachu.facing = facing
	pikachu.image = facing
	return pikachu


func _run_movement(pikachu: Gen1Pikachu, bytes: Array, view: Gen1Pikachu.View) -> int:
	pikachu.start_movement(PackedByteArray(bytes))
	var passes: int = 0
	while pikachu.movement_running() and passes < 512:
		pikachu.advance_movement_pass(view)
		passes += 1
	return passes


## `$00` spends a pass, `$1d` eight of two pixels with the cell following on the
## last, and the `$3f` load one more plus its `DelayFrame`.
func test_a_scripted_step_moves_a_cell_in_eight_passes() -> void:
	var pikachu: Gen1Pikachu = _standing(Vector2i(4, 4))
	var passes: int = _run_movement(pikachu, [0x00, 0x1D, 0x3F], _view(Vector2i(4, 5)))
	assert_eq(passes, 10)
	assert_eq(pikachu.cell, Vector2i(4, 5))
	assert_eq(pikachu.pixel, Vector2i(64, 80))
	assert_eq(pikachu.facing, Gen1Pikachu.FACING_DOWN)
	assert_eq(pikachu.movement_overrun, 1)


## `$36` looks up and moves nothing; `$26` slides up one cell at a pixel a pass.
func test_a_look_turns_and_a_slide_walks_slowly() -> void:
	var pikachu: Gen1Pikachu = _standing(Vector2i(4, 4))
	_run_movement(pikachu, [0x00, 0x36, 0x3F], _view(Vector2i(4, 5)))
	assert_eq(pikachu.facing, Gen1Pikachu.FACING_UP)
	assert_eq(pikachu.cell, Vector2i(4, 4))
	pikachu.start_movement(PackedByteArray([0x00, 0x26, 0x3F]))
	var view: Gen1Pikachu.View = _view(Vector2i(4, 5))
	pikachu.advance_movement_pass(view)
	pikachu.advance_movement_pass(view)
	assert_eq(pikachu.pixel, Vector2i(64, 63))
	assert_eq(pikachu.image, Gen1Pikachu.FACING_UP)
	while pikachu.movement_running():
		pikachu.advance_movement_pass(view)
	assert_eq(pikachu.cell, Vector2i(4, 3))
	assert_eq(pikachu.pixel, Vector2i(64, 48))


## `$2d`: the sine lifts the sprite over sixteen passes with a shadow under it,
## and the ground pixel is a cell down when the arc lands.
func test_a_hop_arcs_with_a_shadow_and_lands() -> void:
	var pikachu: Gen1Pikachu = _standing(Vector2i(4, 4))
	pikachu.start_movement(PackedByteArray([0x00, 0x2D, 0x3F]))
	var view: Gen1Pikachu.View = _view(Vector2i(4, 5))
	pikachu.advance_movement_pass(view)
	var heights: Array[int] = []
	var shadows: int = 0
	for _pass: int in 16:
		pikachu.advance_movement_pass(view)
		heights.append(pikachu.movement_height())
		shadows += 1 if pikachu.movement_shadow() else 0
	assert_eq(heights.max(), 8)
	assert_eq(heights[-1], 0)
	assert_eq(shadows, 15)
	assert_eq(pikachu.cell, Vector2i(4, 5))
	assert_eq(pikachu.pixel, Vector2i(64, 80))


## `Data_fd731` is walked one way by `$39` and the other by `$3a`, each taking
## its pass count off the script; the turn is the drawn image's, not the facing.
func test_the_turn_commands_walk_the_ring_both_ways() -> void:
	var pikachu: Gen1Pikachu = _standing(Vector2i(4, 4))
	_run_movement(pikachu, [0x00, 0x39, 0x00, 0x3F], _view(Vector2i(4, 5)))
	assert_eq(pikachu.drawn_facing(), Gen1Pikachu.FACING_LEFT >> 2)
	assert_eq(pikachu.facing, Gen1Pikachu.FACING_DOWN)
	_run_movement(pikachu, [0x00, 0x3A, 0x00, 0x3A, 0x00, 0x3F], _view(Vector2i(4, 5)))
	assert_eq(pikachu.drawn_facing(), Gen1Pikachu.FACING_UP >> 2)


## `GetPikaPicAnimationScriptIndex`: the mood picks the column, the happiness
## the row, each the first threshold not below it.
func test_the_mood_and_happiness_tables_pick_an_emotion() -> void:
	var tables: Dictionary = {
		"moods": [[40, 1], [127, 2], [128, 3], [210, 4], [255, 5]],
		"happiness": [[50, 14, 14, 6, 13, 13], [100, 9, 9, 5, 12, 12], [255, 17, 17, 19, 20, 20]],
	}
	var pikachu := Gen1Pikachu.new()
	assert_eq(pikachu.mood_emotion(tables), 5)
	pikachu.mood = 20
	pikachu.happiness = 50
	assert_eq(pikachu.mood_emotion(tables), 14)
	pikachu.mood = 255
	pikachu.happiness = 255
	assert_eq(pikachu.mood_emotion(tables), 20)


## `ModifyPikachuHappiness` reads the row's column off the happiness hundred and
## moves the mood toward the row's target; the walking row asks the party alone.
func test_happiness_moves_by_the_table_and_the_mood_follows() -> void:
	var pikachu := Gen1Pikachu.new()
	pikachu.set_party(true, false)
	pikachu.modify_happiness(Gen1Pikachu.HAPPY_LEVELUP)
	assert_eq(pikachu.happiness, 95)
	assert_eq(pikachu.mood, 0x8A)
	pikachu.modify_happiness(Gen1Pikachu.HAPPY_DEPOSITED)
	assert_eq(pikachu.happiness, 92)
	assert_eq(pikachu.mood, 0x62)
	pikachu.set_party(false, false)
	pikachu.modify_happiness(Gen1Pikachu.HAPPY_LEVELUP)
	assert_eq(pikachu.happiness, 92)
