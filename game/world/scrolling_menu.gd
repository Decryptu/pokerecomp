class_name Gen2ScrollingMenu
extends RefCounted

## What a press that moves a list costs in frames, for every host of one.

## The position of a screen that is not a list, or is not one at the moment.
const NOT_A_LIST: Vector2i = Vector2i(-1, -1)

## `_ScrollingMenu.zero` (`engine/menus/scrolling_menu.asm`, the same in pokegold)
## runs on every move, inside the window or past it: PyBoy on Crystal measures
## five frames to the next `ScrollingMenuJoyAction` for the pack, the item PC's
## list and the mart's. `WaitBGMap`'s four follow before the pad is read again.
const ZERO_FRAMES: int = 5
const POLL_FRAMES: int = 4

## `DisplayListMenuID` (`home/list_menu.asm`) moves the cursor in the window with
## no wait; a scroll reprints through two `Delay3`, which PyBoy on Red measures
## at six frames, seven where the redraw overruns.
const GEN1_SCROLL_FRAMES: int = 6


## Spends a move between positions of (cursor row, first row shown); Generation 1
## waits on a scroll only.
static func after_press(gen1: bool, before: Vector2i, now: Vector2i) -> void:
	if before == NOT_A_LIST or now == NOT_A_LIST or before == now:
		return
	if gen1 and before.y == now.y:
		return
	var input: Gen2InputRuntime = Gen2InputRuntime.instance()
	if input == null:
		return
	if gen1:
		input.stall(GEN1_SCROLL_FRAMES)
	else:
		input.stall(ZERO_FRAMES + POLL_FRAMES, POLL_FRAMES)
