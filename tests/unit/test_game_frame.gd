extends GutTest

## How a game screen splits between the hardware screen and the controller, and
## what [Gen2Screen] puts in the room SCREEN FILL gives it.

const SCREEN_SCENE: PackedScene = preload("res://game/render/gen2_screen.tscn")
const WINDOW := Vector2(1152, 648)


## A screen in the tree at [param area], with SCREEN FILL as [param fill].
func _built(fill: bool = true, area: Vector2 = WINDOW) -> Gen2Screen:
	Gen2OptionsStore.use_test_path()
	Gen2OptionsStore.current().screen_fill = fill
	var screen: Gen2Screen = SCREEN_SCENE.instantiate() as Gen2Screen
	add_child_autofree(screen)
	# The scene anchors to its frame, which would take the size back off it.
	screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	screen.size = area
	return screen


## A [param width] x [param height] picture of [param field] with a stripe of
## [param ink] across it, which is the shape of every screen here: a lot of one
## colour with writing on it.
func _picture(field: Color, ink: Color, rows: int = 4) -> Image:
	var image := Image.create_empty(
		Gen2Screen.WIDTH, Gen2Screen.HEIGHT, false, Image.FORMAT_RGBA8
	)
	image.fill(field)
	image.fill_rect(Rect2i(0, 0, Gen2Screen.WIDTH, rows), ink)
	return image


func _screen(area: Vector2, controls: bool) -> Rect2:
	return Gen2GameFrame.split(area, controls)["screen"]


func _controls(area: Vector2, controls: bool) -> Rect2:
	return Gen2GameFrame.split(area, controls)["controls"]


## With nothing to place, both cases are the same and a desktop window is
## exactly what it was.
func test_without_a_controller_the_screen_takes_the_whole_frame() -> void:
	for area: Vector2 in [Vector2(1152, 648), Vector2(480, 960)]:
		assert_eq(_screen(area, false), Rect2(Vector2.ZERO, area))


## Landscape centres the screen and overlays the controller on the margins,
## which is where the thumbs already are.
func test_landscape_centres_the_screen_and_shares_the_frame() -> void:
	var area := Vector2(1152, 648)
	assert_eq(_screen(area, true), Rect2(Vector2.ZERO, area))
	assert_eq(_controls(area, true), Rect2(Vector2.ZERO, area))


func test_portrait_puts_the_screen_at_the_top_and_the_controller_under_it() -> void:
	var area := Vector2(480, 960)
	var screen: Rect2 = _screen(area, true)
	var controls: Rect2 = _controls(area, true)

	assert_eq(screen.position.y, 0.0, "top aligned")
	assert_eq(screen.get_center().x, area.x * 0.5, "centred across the width")
	assert_eq(controls.position.y, screen.end.y, "the controller starts where the screen ends")
	assert_eq(controls.end.y, area.y)
	assert_gt(controls.size.y, 0.0)


## A hardware pixel has to stay square, so the screen is always a whole number of
## them and never the height the split asked for.
func test_the_portrait_screen_is_a_whole_number_of_hardware_pixels() -> void:
	for height: int in [700, 800, 960, 1280]:
		var area := Vector2(480, height)
		var screen: Rect2 = _screen(area, true)
		var factor: float = screen.size.y / Gen2Screen.HEIGHT
		assert_eq(factor, floorf(factor), "%dpx tall" % height)
		assert_eq(screen.size.x, Gen2Screen.WIDTH * factor)


func test_the_portrait_screen_leaves_the_controller_its_share() -> void:
	var area := Vector2(480, 960)
	assert_lt(
		_screen(area, true).size.y,
		area.y * (1.0 - Gen2GameFrame.PORTRAIT_CONTROL_SHARE) + 1.0,
	)


## A window too small for one whole hardware pixel still draws one, rather than
## collapsing to nothing.
func test_a_tiny_frame_keeps_the_screen_at_one_to_one() -> void:
	var screen: Rect2 = _screen(Vector2(120, 300), true)
	assert_eq(screen.size, Vector2(Gen2Screen.WIDTH, Gen2Screen.HEIGHT))


## The split above is only reachable if the device is allowed to turn: Godot's
## default locks every handheld to landscape, and nothing else here sets it.
func test_a_handheld_may_turn_into_the_portrait_layout() -> void:
	assert_eq(
		int(ProjectSettings.get_setting("display/window/handheld/orientation")),
		DisplayServer.SCREEN_SENSOR,
	)


## SCREEN FILL: an expanded screen is given the whole portrait share instead of
## the 10:9 rectangle inside it, since the leftover is void it can draw map into.
func test_an_expanded_portrait_screen_takes_the_whole_share() -> void:
	var area := Vector2(480, 960)
	var framed: Rect2 = Gen2GameFrame.split(area, true)["screen"]
	var filled: Rect2 = Gen2GameFrame.split(area, true, true)["screen"]
	assert_eq(filled.position, Vector2.ZERO)
	assert_eq(filled.size.x, area.x)
	assert_gt(filled.size.y, framed.size.y)
	assert_eq(
		Gen2GameFrame.split(area, true, true)["controls"].position.y,
		filled.end.y,
		"the controller still starts where the screen ends",
	)


## Landscape and a screen with no controller are unchanged either way: the
## screen already had the whole frame and fills it itself.
func test_expanding_changes_nothing_where_the_screen_had_the_frame() -> void:
	for area: Vector2 in [Vector2(1152, 648), Vector2(480, 960)]:
		assert_eq(
			Gen2GameFrame.split(area, false, true)["screen"],
			Gen2GameFrame.split(area, false)["screen"],
		)


## The zoom ladder: whole pixels per hardware pixel on the way in, halves on the
## way out once one pixel each is reached, and never past the survey floor.
func test_the_zoom_ladder_steps_whole_pixels_then_halves() -> void:
	assert_eq(Gen2Screen.scale_at(4, 0), 4.0, "no step is the fitting scale")
	assert_eq(Gen2Screen.scale_at(4, 2), 6.0)
	assert_eq(Gen2Screen.scale_at(4, -3), 1.0, "one pixel each is the last whole step")
	assert_eq(Gen2Screen.scale_at(4, -4), 0.5)
	assert_eq(Gen2Screen.scale_at(4, -5), 0.25)
	assert_eq(Gen2Screen.scale_at(4, -9), Gen2Screen.MIN_SCALE, "the survey floor")


## The expanded buffer covers the window and grows by whole map blocks, so half
## the difference from the hardware screen is a whole tile and the interface
## rectangle inside it lands on the grid every screen is laid out against.
func test_the_expanded_buffer_covers_the_window_on_a_block_grid() -> void:
	for area: Vector2 in [Vector2(1152, 648), Vector2(1920, 1080), Vector2(430, 932)]:
		for scale: float in [1.0, 2.0, 4.0, 0.5]:
			var view: Vector2i = Gen2Screen.buffer_for(area, scale)
			assert_gte(float(view.x) * scale, area.x, "%s at %sx covers the width" % [area, scale])
			assert_gte(float(view.y) * scale, area.y, "%s at %sx covers the height" % [area, scale])
			assert_eq((view.x - Gen2Screen.WIDTH) % Gen2Screen.BUFFER_STEP, 0)
			assert_eq((view.y - Gen2Screen.HEIGHT) % Gen2Screen.BUFFER_STEP, 0)


## A window smaller than the hardware screen still gets the hardware screen:
## there is nothing to fill and a smaller buffer would crop the game.
func test_the_expanded_buffer_never_shrinks_below_the_hardware_screen() -> void:
	assert_eq(
		Gen2Screen.buffer_for(Vector2(100, 100), 4.0),
		Vector2i(Gen2Screen.WIDTH, Gen2Screen.HEIGHT),
	)


## SCREEN FILL is read by the screen itself. Every screen in the game gets one of
## these and none of them asks; a screen written next year does not have to know
## the setting exists to be responsive in a window that is not 10:9.
func test_a_screen_takes_the_window_without_being_told() -> void:
	assert_true(_built(true).expanded, "filled")
	assert_false(_built(false).expanded, "framed")


## And it fills the room it took. A screen laid out in 160x144 has nothing of its
## own out there, so the default is that the screen paints it rather than leaving
## a bar; only a view that draws the whole buffer turns this off.
func test_the_surround_is_filled_unless_a_view_owns_the_buffer() -> void:
	assert_true(_built(true).interface_masked)


## With the screen's own field, taken from the picture that screen drew. The
## field is what a screen is mostly made of, not what its border happens to be:
## a cartridge screen puts a box frame or a header strip along its own edge often
## enough that the edge says black where the screen reads white.
func test_the_surround_follows_the_picture_a_screen_drew() -> void:
	var screen: Gen2Screen = _built()
	var view := TextureRect.new()
	screen.display(view)
	Gen2PicImage.show(view, _picture(Color.WHITE, Color.BLACK))
	assert_eq(screen.surround_color, Color.WHITE)

	Gen2PicImage.show(view, _picture(Color.RED, Color.BLACK))
	assert_eq(screen.surround_color, Color.RED, "and follows it when it is redrawn")


## A layer drawn over another screen is not that screen's field, so it does not
## answer for it: the pack's cursor sprite would otherwise paint the window.
func test_a_layer_over_a_screen_does_not_answer_for_it() -> void:
	var screen: Gen2Screen = _built()
	var view := TextureRect.new()
	screen.display(view)
	Gen2PicImage.show(view, _picture(Color.WHITE, Color.BLACK))
	var overlay := TextureRect.new()
	screen.display(overlay)
	Gen2PicImage.show(overlay, _picture(Color(0, 0, 0, 0), Color.BLACK))
	assert_eq(screen.surround_color, Color.WHITE, "the screen under it still owns it")


## Half the screens here are drawn as a colour rather than as a picture, so the
## field they stand on is the same seam.
func test_a_screen_drawn_as_a_colour_says_so_too() -> void:
	var screen: Gen2Screen = _built()
	screen.display(Gen2Screen.Field.create(Color.AQUA))
	await wait_process_frames(2)
	assert_eq(screen.surround_color, Color.AQUA)


## Content laid out in the hardware's own 160x144 goes where that rectangle is.
## In the buffer's corner it would sit off to one side of the boxes above it,
## which is what the built-in battle arena did the first time this expanded.
func test_hardware_sized_content_lands_on_the_interface_rectangle() -> void:
	var screen: Gen2Screen = _built()
	var arena := ColorRect.new()
	screen.display_content(arena)
	assert_eq(
		arena.get_parent().position, screen.interface_layer().position,
		"the layer it went on covers the hardware rectangle",
	)
	assert_gt(screen.interface_layer().position.x, 0.0, "which is not the corner")


## A view that fills the buffer keeps the buffer's own origin, or the map would
## be drawn one interface rectangle in from the corner.
func test_a_buffer_filling_view_keeps_the_buffer_origin() -> void:
	var screen: Gen2Screen = _built()
	var map := ColorRect.new()
	screen.display_content(map, true)
	assert_eq(map.get_parent(), screen.viewport())
	assert_eq(screen.viewport().get_children().find(map), 0, "and stays the floor")
