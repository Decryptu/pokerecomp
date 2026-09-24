class_name Gen2WorldQuantityPrompt
extends RefCounted

## `BuySellToss_InterpretJoypad` (`engine/items/buy_sell_toss.asm`), the dial
## every quantity prompt reads its joypad through: `wItemQuantity` (the ceiling)
## and `wItemQuantityChange` (the shown value), while the caller owns the box.
## Kurt, `SelectQuantityToToss` and the mart are the one routine over their own
## headers.

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


## The same dial for a caller that keeps the number itself: the mart's box.
static func stepped(
	shown: int, button: int, available: int, generation: int = RomRegistry.GEN2
) -> int:
	var prompt: Gen2WorldQuantityPrompt = open(available, generation)
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
