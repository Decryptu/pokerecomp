extends GutTest

## Where the on-screen controller's clusters land, and what a point presses.

const PORTRAIT := Rect2(Vector2.ZERO, Vector2(480, 700))
const LANDSCAPE := Rect2(Vector2.ZERO, Vector2(960, 480))
## What the game leaves the controller on a phone held upright: the map takes the
## top, so the strip is wider than it is tall while the arrangement in it is still
## the upright one.
const PORTRAIT_STRIP := Rect2(Vector2(0, 477), Vector2(393, 375))


func _layout() -> PokeTouchLayout:
	return PokeTouchLayout.new()


func test_orientation_follows_the_area() -> void:
	assert_eq(
		PokeTouchLayout.orientation_of(Vector2(480, 700)),
		PokeTouchLayout.ORIENTATION_PORTRAIT,
	)
	assert_eq(
		PokeTouchLayout.orientation_of(Vector2(960, 480)),
		PokeTouchLayout.ORIENTATION_LANDSCAPE,
	)
	assert_eq(
		PokeTouchLayout.orientation_of(Vector2(500, 500)),
		PokeTouchLayout.ORIENTATION_LANDSCAPE,
		"a square area is not portrait",
	)


## Including the arrangement the rectangle would not have named itself: a default
## anchor was measured against the whole screen and meets a strip for the first
## time here, which is where half a face button used to end up off the glass.
func test_every_group_is_inside_the_area_in_both_orientations() -> void:
	var layout: PokeTouchLayout = _layout()
	var cases: Array = [
		[PORTRAIT, &""],
		[LANDSCAPE, &""],
		[PORTRAIT_STRIP, PokeTouchLayout.ORIENTATION_PORTRAIT],
	]
	for factor: float in [PokeTouchLayout.MIN_SCALE, 1.0, PokeTouchLayout.MAX_SCALE]:
		layout.scale = factor
		for case: Array in cases:
			var area: Rect2 = case[0]
			for group: StringName in PokeTouchLayout.GROUPS:
				var rect: Rect2 = layout.group_rect(group, area, case[1])
				assert_true(
					area.encloses(rect),
					"%s fits %s at %s" % [group, area.size, factor],
				)


## Landscape centres the hardware screen and leaves the margins, so nothing may
## sit across the middle where the game is.
func test_landscape_keeps_the_clusters_off_the_centre() -> void:
	var layout: PokeTouchLayout = _layout()
	var middle: float = LANDSCAPE.size.x * 0.5
	for group: StringName in PokeTouchLayout.GROUPS:
		var rect: Rect2 = layout.group_rect(group, LANDSCAPE)
		assert_false(
			rect.position.x < middle and rect.end.x > middle,
			"%s clears the screen" % group,
		)


func test_the_dpad_reads_by_dominant_axis() -> void:
	var layout: PokeTouchLayout = _layout()
	var rect: Rect2 = layout.group_rect(PokeTouchLayout.GROUP_PAD, PORTRAIT)
	var centre: Vector2 = rect.get_center()
	var reach: float = rect.size.x * 0.45

	assert_eq(layout.direction_at(centre + Vector2(0, -reach), PORTRAIT), PokeButton.UP)
	assert_eq(layout.direction_at(centre + Vector2(0, reach), PORTRAIT), PokeButton.DOWN)
	assert_eq(layout.direction_at(centre + Vector2(-reach, 0), PORTRAIT), PokeButton.LEFT)
	assert_eq(layout.direction_at(centre + Vector2(reach, 0), PORTRAIT), PokeButton.RIGHT)


## A corner gives one direction, not two: nothing in either game moves
## diagonally, and a press that walked twice would be wrong in a menu as well.
func test_a_corner_of_the_dpad_gives_one_direction() -> void:
	var layout: PokeTouchLayout = _layout()
	for area: Rect2 in [PORTRAIT, LANDSCAPE]:
		for factor: float in [0.6, 1.0, 1.8]:
			layout.scale = factor
			var rect: Rect2 = layout.group_rect(PokeTouchLayout.GROUP_PAD, area)
			for diagonal: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
				var corner: Vector2 = rect.get_center() + rect.size * diagonal * 0.35
				var expected: int = PokeButton.RIGHT if diagonal.x > 0 else PokeButton.LEFT
				assert_eq(layout.direction_at(corner, area), expected)


func test_a_thumb_resting_dead_centre_presses_nothing() -> void:
	var layout: PokeTouchLayout = _layout()
	var rect: Rect2 = layout.group_rect(PokeTouchLayout.GROUP_PAD, PORTRAIT)
	assert_eq(layout.direction_at(rect.get_center(), PORTRAIT), PokeButton.NONE)
	assert_eq(layout.button_at(rect.get_center(), PORTRAIT), PokeButton.NONE)


func test_a_point_outside_the_dpad_is_not_a_direction() -> void:
	var layout: PokeTouchLayout = _layout()
	assert_eq(layout.direction_at(Vector2(-40, -40), PORTRAIT), PokeButton.NONE)


func test_each_face_and_menu_button_is_pressable_at_its_own_centre() -> void:
	var layout: PokeTouchLayout = _layout()
	var rects: Dictionary = layout.button_rects(PORTRAIT)
	for button: int in [PokeButton.A, PokeButton.B, PokeButton.START, PokeButton.SELECT]:
		assert_true(rects.has(button), PokeButton.label(button))
		assert_eq(
			layout.button_at((rects[button] as Rect2).get_center(), PORTRAIT),
			button,
			PokeButton.label(button),
		)


func test_a_is_below_and_left_of_b() -> void:
	var rects: Dictionary = _layout().button_rects(PORTRAIT)
	var a: Rect2 = rects[PokeButton.A]
	var b: Rect2 = rects[PokeButton.B]
	assert_lt(a.get_center().x, b.get_center().x)
	assert_gt(a.get_center().y, b.get_center().y)


func test_scale_grows_every_group() -> void:
	var layout: PokeTouchLayout = _layout()
	var before: Vector2 = layout.group_size(PokeTouchLayout.GROUP_PAD)
	layout.scale = PokeTouchLayout.MAX_SCALE
	assert_gt(layout.group_size(PokeTouchLayout.GROUP_PAD).x, before.x)


## The one way an options screen could hand back a layout nobody can press.
func test_a_group_cannot_be_dragged_off_the_area() -> void:
	var layout: PokeTouchLayout = _layout()
	layout.set_anchor(
		PokeTouchLayout.ORIENTATION_PORTRAIT,
		PokeTouchLayout.GROUP_PAD,
		Vector2(-3.0, 5.0),
		PORTRAIT.size,
	)
	assert_true(PORTRAIT.encloses(layout.group_rect(PokeTouchLayout.GROUP_PAD, PORTRAIT)))


func test_an_unknown_group_or_orientation_moves_nothing() -> void:
	var layout: PokeTouchLayout = _layout()
	var before: Vector2 = layout.anchor(
		PokeTouchLayout.ORIENTATION_PORTRAIT, PokeTouchLayout.GROUP_PAD
	)
	layout.set_anchor(&"sideways", PokeTouchLayout.GROUP_PAD, Vector2(0.9, 0.9), PORTRAIT.size)
	layout.set_anchor(
		PokeTouchLayout.ORIENTATION_PORTRAIT, &"shoulder", Vector2(0.9, 0.9), PORTRAIT.size
	)
	layout.set_anchor(
		PokeTouchLayout.ORIENTATION_PORTRAIT, PokeTouchLayout.GROUP_PAD, Vector2(0.9, 0.9),
		Vector2.ZERO,
	)
	assert_eq(layout.anchor(PokeTouchLayout.ORIENTATION_PORTRAIT, PokeTouchLayout.GROUP_PAD), before)


func test_the_two_orientations_are_kept_apart() -> void:
	var layout: PokeTouchLayout = _layout()
	var landscape_before: Vector2 = layout.anchor(
		PokeTouchLayout.ORIENTATION_LANDSCAPE, PokeTouchLayout.GROUP_PAD
	)
	layout.set_anchor(
		PokeTouchLayout.ORIENTATION_PORTRAIT, PokeTouchLayout.GROUP_PAD,
		Vector2(0.5, 0.5), PORTRAIT.size,
	)
	assert_eq(
		layout.anchor(PokeTouchLayout.ORIENTATION_LANDSCAPE, PokeTouchLayout.GROUP_PAD),
		landscape_before,
	)


func test_a_layout_survives_the_options_file() -> void:
	var layout: PokeTouchLayout = _layout()
	layout.scale = 1.4
	layout.opacity = 0.5
	layout.set_anchor(
		PokeTouchLayout.ORIENTATION_LANDSCAPE, PokeTouchLayout.GROUP_A,
		Vector2(0.7, 0.3), LANDSCAPE.size,
	)
	var restored: PokeTouchLayout = PokeTouchLayout.parse(
		JSON.parse_string(JSON.stringify(layout.to_dict()))
	)
	assert_eq(restored.to_dict(), layout.to_dict())
	assert_false(restored.is_default())


func test_an_unreadable_layout_clamps_to_the_defaults() -> void:
	for raw: Variant in [null, "layout", 3]:
		assert_true(PokeTouchLayout.parse(raw).is_default())
	var partial: PokeTouchLayout = PokeTouchLayout.parse({
		"scale": 99.0,
		"opacity": -4.0,
		"portrait": {"pad": "over there", "a": [2.0, -1.0]},
	})
	assert_eq(partial.scale, PokeTouchLayout.MAX_SCALE)
	assert_eq(partial.opacity, PokeTouchLayout.MIN_OPACITY)
	assert_eq(
		partial.anchor(PokeTouchLayout.ORIENTATION_PORTRAIT, PokeTouchLayout.GROUP_PAD),
		PokeTouchLayout.DEFAULT_ANCHORS[PokeTouchLayout.ORIENTATION_PORTRAIT][PokeTouchLayout.GROUP_PAD],
	)
	assert_eq(
		partial.anchor(PokeTouchLayout.ORIENTATION_PORTRAIT, PokeTouchLayout.GROUP_A),
		Vector2(1.0, 0.0),
	)


## A layout written while A and B were one cluster carries a `face` centre and
## neither of the two the pad places now. `_split_face` puts them on the diagonal
## that cluster held them on, B up and right of the old centre and A down and
## left, so a player who arranged one finds it where they left it.
func test_a_layout_from_before_a_and_b_came_apart_is_split() -> void:
	var migrated: PokeTouchLayout = PokeTouchLayout.parse({
		"portrait": {"face": [0.76, 0.50]},
	})
	var a: Vector2 = migrated.anchor(
		PokeTouchLayout.ORIENTATION_PORTRAIT, PokeTouchLayout.GROUP_A
	)
	var b: Vector2 = migrated.anchor(
		PokeTouchLayout.ORIENTATION_PORTRAIT, PokeTouchLayout.GROUP_B
	)
	assert_lt(a.x, b.x, "A stays left of B")
	assert_gt(a.y, b.y, "and below it")
	assert_almost_eq((a.x + b.x) * 0.5, 0.76, 0.001, "around the cluster's own centre")
	assert_almost_eq((a.y + b.y) * 0.5, 0.50, 0.001)
	assert_false(
		migrated.to_dict()["portrait"].has("face"), "and the old name is not written back"
	)


## A layout that already names the two is left alone, so a migration cannot run
## twice and walk the pair apart.
func test_a_layout_that_already_names_a_and_b_is_not_split_again() -> void:
	var stored: Dictionary = {
		"portrait": {"face": [0.10, 0.10], "a": [0.30, 0.60], "b": [0.50, 0.40]},
	}
	var parsed: PokeTouchLayout = PokeTouchLayout.parse(stored)
	assert_eq(
		parsed.anchor(PokeTouchLayout.ORIENTATION_PORTRAIT, PokeTouchLayout.GROUP_A),
		Vector2(0.30, 0.60),
	)
	assert_eq(
		parsed.anchor(PokeTouchLayout.ORIENTATION_PORTRAIT, PokeTouchLayout.GROUP_B),
		Vector2(0.50, 0.40),
	)


## The whole point of the split: each is dragged on its own.
func test_a_and_b_are_placed_separately() -> void:
	var layout: PokeTouchLayout = _layout()
	var before: Vector2 = layout.anchor(
		PokeTouchLayout.ORIENTATION_PORTRAIT, PokeTouchLayout.GROUP_B
	)
	layout.set_anchor(
		PokeTouchLayout.ORIENTATION_PORTRAIT, PokeTouchLayout.GROUP_A,
		Vector2(0.5, 0.2), PORTRAIT.size,
	)
	assert_eq(
		layout.anchor(PokeTouchLayout.ORIENTATION_PORTRAIT, PokeTouchLayout.GROUP_B), before
	)
	var rects: Dictionary = layout.button_rects(PORTRAIT)
	assert_false(
		(rects[PokeButton.A] as Rect2).intersects(rects[PokeButton.B] as Rect2),
		"and each has a rectangle of its own"
	)


func test_a_duplicate_is_independent_of_the_original() -> void:
	var layout: PokeTouchLayout = _layout()
	var copy: PokeTouchLayout = layout.duplicate_layout()
	copy.scale = 1.5
	copy.set_anchor(
		PokeTouchLayout.ORIENTATION_PORTRAIT, PokeTouchLayout.GROUP_PAD,
		Vector2(0.6, 0.6), PORTRAIT.size,
	)
	assert_true(layout.is_default())


## A mod's own controls have to reach a phone player, and must not cover the
## screen of one who never asked for them.
func test_mod_buttons_are_off_until_the_player_switches_them_on() -> void:
	var layout: PokeTouchLayout = _layout()
	layout.mod_buttons = [
		{"action": &"mod_voxel_pitch_up", "label": "Camera up"},
		{"action": &"mod_voxel_pitch_down", "label": "Camera down"},
	]
	assert_true(layout.mod_groups().is_empty(), "off by default")
	assert_true(layout.mod_button_rects(PORTRAIT).is_empty())

	layout.mod_buttons_shown = true
	assert_eq(layout.mod_groups().size(), 2)
	assert_eq(layout.mod_label(&"mod_voxel_pitch_up"), "Camera up")
	var rects: Dictionary = layout.mod_button_rects(PORTRAIT)
	assert_eq(rects.size(), 2)
	# Each is pressable at its own centre and stacked clear of the one above.
	for action: StringName in rects:
		assert_eq(layout.mod_action_at((rects[action] as Rect2).get_center(), PORTRAIT), action)
	assert_false(
		(rects[&"mod_voxel_pitch_up"] as Rect2).intersects(rects[&"mod_voxel_pitch_down"])
	)


func test_a_mod_button_is_placed_and_survives_the_options_file() -> void:
	var layout: PokeTouchLayout = _layout()
	layout.mod_buttons = [{"action": &"mod_voxel_pitch_up", "label": "Camera up"}]
	layout.mod_buttons_shown = true
	layout.set_anchor(
		PokeTouchLayout.ORIENTATION_PORTRAIT, &"mod_voxel_pitch_up",
		Vector2(0.3, 0.7), PORTRAIT.size,
	)
	var stored: PokeTouchLayout = PokeTouchLayout.parse(layout.to_dict())
	assert_true(stored.mod_buttons_shown)
	# The placement is read back without knowing which mods are installed, so an
	# uninstalled mod's position waits rather than being thrown away.
	assert_eq(
		stored.anchor(PokeTouchLayout.ORIENTATION_PORTRAIT, &"mod_voxel_pitch_up"),
		Vector2(0.3, 0.7),
	)
	assert_false(layout.is_default())
