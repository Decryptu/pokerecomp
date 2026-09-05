class_name Gen2WorldQuantityPrompt
extends RefCounted

## `BuySellToss_InterpretJoypad` (`engine/items/buy_sell_toss.asm`), the dial
## every source quantity prompt reads its joypad through. It owns
## `wItemQuantity` (the ceiling) and `wItemQuantityChange` (the shown value) and
## nothing else; the caller owns the box the number is drawn in.
##
## `Kurt_SelectQuantity` is the first caller here. `SelectQuantityToToss` and the
## mart's own prompt are the same routine over their own headers, so the pack's
## TOSS needs this model and a box rather than a second dial.

const PAGE_STEP: int = 10

const PENDING: StringName = &"pending"
const CONFIRMED: StringName = &"confirmed"
const CANCELLED: StringName = &"cancelled"

## `wItemQuantity`, the ceiling the caller loaded before opening the box.
var maximum: int = 1
## `wItemQuantityChange`, which every caller opens on 1.
var value: int = 1
## `DisplayChooseQuantityMenu`'s `.waitForKeyPressLoop` reads A, B, UP and DOWN
## and nothing else, so Generation 1's dial has no ten-step on left and right.
var page_steps: bool = true


static func open(
	available: int, generation: int = RomRegistry.GEN2
) -> Gen2WorldQuantityPrompt:
	var prompt := Gen2WorldQuantityPrompt.new()
	prompt.maximum = maxi(1, available)
	prompt.value = 1
	prompt.page_steps = generation != RomRegistry.GEN1
	return prompt


## The same dial for a caller that keeps the number itself: the mart's box and
## the item PC's row are `Toss_Sell_Loop` over their own headers.
static func stepped(shown: int, button: int, available: int) -> int:
	var prompt: Gen2WorldQuantityPrompt = open(available)
	prompt.value = clampi(shown, 1, prompt.maximum)
	prompt.press(button)
	return prompt.value


func press(button: int) -> StringName:
	match button:
		PokeButton.A:
			return CONFIRMED
		PokeButton.B:
			return CANCELLED
		PokeButton.UP:
			_step_up()
		PokeButton.DOWN:
			_step_down()
		PokeButton.LEFT:
			if page_steps:
				_page_down()
		PokeButton.RIGHT:
			if page_steps:
				_page_up()
	return PENDING


## `.down` decrements, and the byte reaching zero is what wraps it to the
## ceiling rather than a comparison against 1.
func _step_down() -> void:
	value -= 1
	if value == 0:
		value = maximum


func _step_up() -> void:
	value += 1
	if value > maximum:
		value = 1


func _page_down() -> void:
	value = 1 if value - PAGE_STEP <= 0 else value - PAGE_STEP


func _page_up() -> void:
	value = mini(value + PAGE_STEP, maximum)
