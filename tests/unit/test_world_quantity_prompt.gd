extends GutTest


## `BuySellToss_InterpretJoypad`: one on up and down, ten on left and right,
## with UP past the ceiling back to one and DOWN past one to the ceiling.
func test_the_generation_2_dial_steps_by_one_and_by_ten() -> void:
	assert_eq(Gen2WorldQuantityPrompt.stepped(5, PokeButton.UP, 20), 6)
	assert_eq(Gen2WorldQuantityPrompt.stepped(5, PokeButton.RIGHT, 20), 15)
	assert_eq(Gen2WorldQuantityPrompt.stepped(15, PokeButton.RIGHT, 20), 20)
	assert_eq(Gen2WorldQuantityPrompt.stepped(5, PokeButton.LEFT, 20), 1)
	assert_eq(Gen2WorldQuantityPrompt.stepped(20, PokeButton.UP, 20), 1)
	assert_eq(Gen2WorldQuantityPrompt.stepped(1, PokeButton.DOWN, 20), 20)


## `DisplayChooseQuantityMenu` reads A, B, UP and DOWN and nothing else, which
## is the dial every Generation 1 mart counter asks through.
func test_the_generation_1_dial_ignores_left_and_right() -> void:
	assert_eq(Gen2WorldQuantityPrompt.stepped(5, PokeButton.RIGHT, 99, RomRegistry.GEN1), 5)
	assert_eq(Gen2WorldQuantityPrompt.stepped(5, PokeButton.LEFT, 99, RomRegistry.GEN1), 5)
	assert_eq(Gen2WorldQuantityPrompt.stepped(5, PokeButton.UP, 99, RomRegistry.GEN1), 6)


func test_the_dial_reports_its_two_terminals() -> void:
	var prompt: Gen2WorldQuantityPrompt = Gen2WorldQuantityPrompt.open(9)
	assert_eq(prompt.press(PokeButton.UP), Gen2WorldQuantityPrompt.PENDING)
	assert_eq(prompt.press(PokeButton.A), Gen2WorldQuantityPrompt.CONFIRMED)
	assert_eq(prompt.press(PokeButton.B), Gen2WorldQuantityPrompt.CANCELLED)
