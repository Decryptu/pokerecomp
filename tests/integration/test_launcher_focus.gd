extends GutTest

## Whether a controller has anywhere to start in the launcher.
##
## Godot moves focus between controls on `ui_up` and the rest of that family, but
## only once something already has it, and nothing did. Traversal itself is the
## engine's; what is checked here is that a screen hands over a first control and
## that a modal takes it and gives it back.

var _launcher: Control = null


func before_each() -> void:
	Gen2InputRuntime.instance().apply_options(Gen2Options.new())
	_launcher = load("res://game/main/main.tscn").instantiate() as Control
	add_child_autofree(_launcher)
	await get_tree().process_frame


func after_each() -> void:
	Gen2OptionsStore.use_test_path()


func _use(event: InputEvent) -> void:
	Gen2InputRuntime.instance()._input(event)


func _focus_owner() -> Control:
	return _launcher.get_viewport().gui_get_focus_owner()


func test_a_pad_lands_on_something_it_can_press() -> void:
	_use(InputEventJoypadButton.new())
	await get_tree().process_frame
	await get_tree().process_frame

	var focused: Control = _focus_owner()
	assert_not_null(focused, "a controller needs a first control")
	assert_true(_launcher.is_ancestor_of(focused))
	assert_eq(focused.focus_mode, Control.FOCUS_ALL)


func test_switching_pages_hands_the_ring_to_the_new_one() -> void:
	_use(InputEventJoypadButton.new())
	await get_tree().process_frame
	await get_tree().process_frame

	_launcher.select_page(&"settings")
	await get_tree().process_frame
	await get_tree().process_frame

	var focused: Control = _focus_owner()
	assert_not_null(focused)
	assert_true(focused.is_visible_in_tree(), "focus never lands on a hidden page")


func test_down_from_the_cartridge_reaches_the_floating_dock() -> void:
	_use(InputEventJoypadButton.new())
	await get_tree().process_frame
	await get_tree().process_frame
	var stage: Gen2CartridgeStage = _focus_owner() as Gen2CartridgeStage
	assert_not_null(stage)
	var guard: Gen2FocusGuard = _launcher.find_child("FocusGuard", true, false)
	assert_true(guard.move_focus(Vector2.DOWN))
	var focused: Control = _focus_owner()
	assert_not_null(focused)
	assert_true(focused is Gen2LauncherButton)
	assert_ne(focused, stage)


func test_left_and_right_stay_inside_the_floating_dock() -> void:
	_use(InputEventJoypadButton.new())
	await get_tree().process_frame
	await get_tree().process_frame
	var shell: Gen2LauncherShell = _launcher.get("_shell")
	var buttons: Dictionary = shell.get("_buttons")
	var mods: Gen2LauncherButton = buttons[&"mods"]
	mods.grab_focus()
	var right := InputEventAction.new()
	right.action = &"ui_right"
	right.pressed = true
	shell._on_dock_input(right, &"mods")
	assert_same(_focus_owner(), buttons[&"settings"], "right stays on the dock")
	var left := InputEventAction.new()
	left.action = &"ui_left"
	left.pressed = true
	shell._on_dock_input(left, &"settings")
	assert_same(_focus_owner(), mods, "left stays on the dock")


func test_up_from_the_dock_returns_to_the_current_page() -> void:
	_use(InputEventJoypadButton.new())
	await get_tree().process_frame
	await get_tree().process_frame
	var shell: Gen2LauncherShell = _launcher.get("_shell")
	var buttons: Dictionary = shell.get("_buttons")
	(buttons[&"mods"] as Control).grab_focus()
	var up := InputEventAction.new()
	up.action = &"ui_up"
	up.pressed = true
	shell._on_dock_input(up, &"mods")
	assert_true(_focus_owner() is Gen2CartridgeStage)


func test_mod_page_builds_a_visible_logical_focus_route() -> void:
	_use(InputEventJoypadButton.new())
	_launcher.select_page(&"mods")
	await get_tree().process_frame
	await get_tree().process_frame
	var install: Control = _focus_owner()
	assert_not_null(install)
	assert_eq(install.tooltip_text, "Install a mod .zip")
	var right: NodePath = install.focus_neighbor_right
	assert_false(right.is_empty(), "the page explicitly names the next control")
	var next: Control = install.get_node(right) as Control
	assert_eq(next.text, "Sources", "right follows the visible action row")
	var down: NodePath = install.focus_neighbor_bottom
	assert_false(down.is_empty(), "down enters the page rather than losing focus")
	var below: Control = install.get_node(down) as Control
	assert_true(below.is_visible_in_tree())
	assert_ne(below, install)


## A mouse needs no ring, and putting one up would move it away from whatever
## the player is pointing at.
func test_a_mouse_is_left_alone() -> void:
	_use(InputEventMouseButton.new())
	var guard: Gen2FocusGuard = _launcher.find_child("FocusGuard", true, false)
	assert_not_null(guard, "the shell carries a guard")

	_launcher.get_viewport().gui_release_focus()
	guard.refresh()
	await get_tree().process_frame
	assert_null(_focus_owner())


## A scroll pane takes focus so prose can be read without a pointer, and answers
## every up and down by scrolling. Landing the ring on one that holds controls
## left a pad with no visible focus and no way past the page.
func test_the_ring_never_lands_on_a_pane_that_holds_controls() -> void:
	for page: StringName in [&"settings", &"about"]:
		_use(InputEventJoypadButton.new())
		_launcher.select_page(page)
		await get_tree().process_frame
		await get_tree().process_frame
		var focused: Control = _focus_owner()
		assert_not_null(focused, String(page))
		assert_false(focused is ScrollContainer, "%s stranded the ring on its pane" % page)
		assert_true(focused is BaseButton, String(page))


## Every control on a scrolling page has to be reachable, and the page has to be
## leavable: the walk ends on the dock rather than on a control with nothing
## under it.
func test_a_pad_walks_the_whole_settings_page_and_leaves_it() -> void:
	_use(InputEventJoypadButton.new())
	_launcher.select_page(&"settings")
	await get_tree().process_frame
	await get_tree().process_frame
	var guard: Gen2FocusGuard = _launcher.find_child("FocusGuard", true, false)
	var seen: Array[Control] = []
	var on_dock: bool = false
	for _step: int in 200:
		var focused: Control = _focus_owner()
		if focused == null:
			break
		if not seen.has(focused):
			seen.append(focused)
		if focused is Gen2LauncherButton and (focused as Gen2LauncherButton).tooltip_text == "Settings":
			on_dock = true
			break
		if not guard.move_focus(Vector2.DOWN):
			break
		# The pane brings the newly focused control into view, and the next
		# neighbour is chosen from where things are once it has.
		await get_tree().process_frame
	assert_true(on_dock, "down never reached the dock")
	assert_gt(seen.size(), 5, "the walk skipped the page")


## `JoyTextDelay`'s repeat arrives as one action press ([Gen2InputRuntime]), and
## a screen that answered it twice would cross a page before the player let go.
func test_one_repeat_of_a_held_direction_moves_the_ring_one_control() -> void:
	_use(InputEventJoypadButton.new())
	_launcher.select_page(&"settings")
	await get_tree().process_frame
	await get_tree().process_frame
	var from: Control = _focus_owner()
	assert_not_null(from)
	var next: Control = from.get_node_or_null(from.focus_neighbor_bottom) as Control
	assert_not_null(next, "the guard names what is below")

	var runtime: Gen2InputRuntime = Gen2InputRuntime.instance()
	runtime.send_action(Gen2Button.action(Gen2Button.DOWN), true)
	await get_tree().process_frame
	assert_same(_focus_owner(), next, "one repeat is one control, not two")
	runtime.send_action(Gen2Button.action(Gen2Button.DOWN), false)
	await get_tree().process_frame


## A pane that answered a direction at the end of its travel was a trap: down
## scrolled nothing forever and the dock was never reached.
func test_a_pane_hands_a_direction_on_once_it_has_nowhere_left_to_scroll() -> void:
	var pane: Gen2LauncherScroll = Gen2LauncherScroll.create()
	pane.size = Vector2(200, 100)
	add_child_autofree(pane)
	var tall := Control.new()
	tall.custom_minimum_size = Vector2(200, 2000)
	pane.add_child(tall)
	await get_tree().process_frame
	await get_tree().process_frame

	var down := InputEventAction.new()
	down.action = Gen2Button.action(Gen2Button.DOWN)
	down.pressed = true
	assert_true(pane._scroll_by(down), "there is room below")
	for _step: int in 400:
		if not pane._scroll_by(down):
			break
	assert_false(pane._scroll_by(down), "the bottom hands the press on")

	var up := InputEventAction.new()
	up.action = Gen2Button.action(Gen2Button.UP)
	up.pressed = true
	assert_true(pane._scroll_by(up), "and up still moves from there")


func test_two_attaches_on_one_screen_are_one_guard() -> void:
	var root := Control.new()
	add_child_autofree(root)
	var first: Gen2FocusGuard = Gen2FocusGuard.attach(root)
	assert_same(Gen2FocusGuard.attach(root), first, "two rings move two controls a press")


func test_the_first_focusable_skips_what_cannot_take_focus() -> void:
	var root := Control.new()
	add_child_autofree(root)
	root.add_child(Label.new())
	var hidden := Button.new()
	hidden.visible = false
	root.add_child(hidden)
	var off := Button.new()
	off.disabled = true
	root.add_child(off)
	var wanted := Button.new()
	root.add_child(wanted)

	assert_same(Gen2FocusGuard.first_focusable(root), wanted)


func test_the_first_focusable_enters_a_pane_rather_than_stopping_on_it() -> void:
	var root := Control.new()
	add_child_autofree(root)
	var pane := ScrollContainer.new()
	pane.focus_mode = Control.FOCUS_ALL
	root.add_child(pane)
	var inside := Button.new()
	pane.add_child(inside)

	assert_same(Gen2FocusGuard.first_focusable(root), inside)
	assert_false(Gen2FocusGuard.focusable_controls(root).has(pane))


## A pane with nothing focusable in it is the one that keeps the ring: scrolling
## it is the only way past a wall of prose without a pointer.
func test_a_pane_of_prose_still_takes_the_ring() -> void:
	var root := Control.new()
	add_child_autofree(root)
	var pane := ScrollContainer.new()
	pane.focus_mode = Control.FOCUS_ALL
	root.add_child(pane)
	pane.add_child(Label.new())

	assert_same(Gen2FocusGuard.first_focusable(root), pane)


func test_nothing_focusable_is_not_an_error() -> void:
	var root := Control.new()
	add_child_autofree(root)
	root.add_child(Label.new())
	assert_null(Gen2FocusGuard.first_focusable(root))


## A guard with nothing to focus has to let the arrow past. Reporting the ring
## someone else was holding as its own left every direction press claimed, and
## the screen routing its own buttons behind the guard never saw one.
func test_a_guard_with_nothing_to_focus_does_not_claim_a_direction() -> void:
	var elsewhere := Button.new()
	add_child_autofree(elsewhere)
	var root := Control.new()
	add_child_autofree(root)
	root.add_child(Label.new())
	var guard: Gen2FocusGuard = Gen2FocusGuard.attach(root)
	elsewhere.grab_focus()
	await get_tree().process_frame

	assert_same(_focus_owner(), elsewhere)
	assert_false(guard.move_focus(Vector2.DOWN))
	assert_same(_focus_owner(), elsewhere, "and it is left where it was")


## A modal is where a pad has to be, and where it was has to come back, or
## closing a sheet would strand the player with nothing selected.
func test_a_sheet_takes_the_ring_and_gives_it_back() -> void:
	_use(InputEventJoypadButton.new())
	await get_tree().process_frame
	await get_tree().process_frame
	var before: Control = _focus_owner()
	assert_not_null(before)

	var sheet: Gen2LauncherSheet = Gen2LauncherSheet.create(
		Gen2LauncherTheme.active(), "Replace mod"
	)
	sheet.add_action(Gen2LauncherButton.create(
		Gen2LauncherTheme.active(), "Replace", Gen2LauncherButton.Variant.PRIMARY
	))
	sheet.open(_launcher)
	await get_tree().process_frame
	await get_tree().process_frame

	var inside: Control = _focus_owner()
	assert_not_null(inside)
	assert_true(sheet.is_ancestor_of(inside), "the ring moved into the sheet")

	sheet.close()
	await get_tree().process_frame
	assert_same(_focus_owner(), before)


## The cancel used to be read in _gui_input, which only ever reaches the focused
## control, and the sheet itself never holds focus.
func test_cancel_closes_a_sheet_from_a_button_inside_it() -> void:
	var sheet: Gen2LauncherSheet = Gen2LauncherSheet.create(Gen2LauncherTheme.active(), "Sheet")
	sheet.open(_launcher)
	await get_tree().process_frame
	await get_tree().process_frame

	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	sheet._unhandled_input(cancel)
	await get_tree().process_frame

	assert_false(is_instance_valid(sheet) and sheet.is_inside_tree())
