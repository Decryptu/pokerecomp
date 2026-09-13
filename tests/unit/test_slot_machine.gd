extends GutTest

## `_SlotMachine`'s rules (engine/games/slot_machine.asm), driven headless. The
## reel strips here are the cartridge's own, so a window is a real one; the art is
## `tools/checks/slots.gd` and the screen around it
## `tests/integration/test_world_slot_machine.gd`. What is asserted is what a
## reading gets wrong rather than what a spin looks like: that a bet is taken once
## and paid once, that an unbiased spin can only stop where nothing is lined up,
## that a seven keeps its own bias, and that the payout animation walks the coins
## over rather than adding them at once.

const REELS: Array = [
	[
		0x00, 0x08, 0x14, 0x0C, 0x10, 0x00, 0x08, 0x14, 0x0C, 0x10,
		0x04, 0x08, 0x14, 0x0C, 0x10, 0x00, 0x08, 0x14,
	],
	[
		0x00, 0x0C, 0x08, 0x10, 0x14, 0x04, 0x0C, 0x08, 0x10, 0x14,
		0x04, 0x0C, 0x08, 0x10, 0x14, 0x00, 0x0C, 0x08,
	],
	[
		0x00, 0x0C, 0x08, 0x10, 0x14, 0x0C, 0x08, 0x10, 0x14, 0x0C,
		0x04, 0x08, 0x10, 0x14, 0x0C, 0x00, 0x0C, 0x08,
	],
]

const FRAME_CAP: int = 2400


func _strips() -> Array[PackedByteArray]:
	var out: Array[PackedByteArray] = []
	for reel: Array in REELS:
		var strip := PackedByteArray()
		for symbol: int in reel:
			strip.append(symbol)
		out.append(strip)
	return out


func _machine(coins: int = 200, lucky: bool = false, seed_value: int = 1) -> Gen2SlotMachine:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return Gen2SlotMachine.create(_strips(), coins, lucky, rng)


## Drives to the next prompt, answering `WaitSFX` the way a screen with no audio
## player does. [param stop_at] is the prompt to stop on.
func _drive(machine: Gen2SlotMachine, stop_at: int, frames: int = FRAME_CAP) -> bool:
	for _frame: int in frames:
		if machine.prompt() == stop_at:
			return true
		if machine.waiting_for_sfx():
			machine.sfx_finished()
			continue
		if machine.prompt() == Gen2SlotMachine.Prompt.TEXT:
			machine.dismiss_text()
			continue
		if machine.jumptable_index() in [
			Gen2SlotMachine.SLOTS_WAIT_REEL1, Gen2SlotMachine.SLOTS_WAIT_REEL2,
			Gen2SlotMachine.SLOTS_WAIT_REEL3,
		]:
			machine.press_a()
		if not machine.advance():
			return machine.prompt() == stop_at
	return false


## One whole spin, from the bet menu to `SlotsAction_RestartOrQuit`'s own wait.
func _spin(machine: Gen2SlotMachine, bet: int) -> bool:
	if not _drive(machine, Gen2SlotMachine.Prompt.BET):
		return false
	machine.answer_bet(4 - bet)
	return _drive(machine, Gen2SlotMachine.Prompt.PRESS)


## `Slots_AskBet`: the menu's own row is `4 - wMenuCursorY` coins, and the
## sixteen-bit subtraction happens once.
func test_the_bet_is_taken_once() -> void:
	var machine: Gen2SlotMachine = _machine()
	assert_true(_drive(machine, Gen2SlotMachine.Prompt.BET))
	machine.answer_bet(1)
	assert_eq(machine.bet(), 3)
	assert_eq(machine.coins(), 197)


## `.DeductCoins`' own refusal: a balance under the bet reprints the box and
## goes back to the menu rather than spinning.
func test_a_bet_over_the_balance_is_refused() -> void:
	var machine: Gen2SlotMachine = _machine(2)
	assert_true(_drive(machine, Gen2SlotMachine.Prompt.BET))
	machine.answer_bet(1)
	assert_eq(machine.prompt(), Gen2SlotMachine.Prompt.TEXT)
	assert_eq(machine.prompt_name(), &"not_enough_coins")
	assert_eq(machine.coins(), 2)
	machine.dismiss_text()
	assert_eq(machine.prompt(), Gen2SlotMachine.Prompt.BET)


## B on the menu is `ret c`, which is the quit entry and not another bet.
func test_cancelling_the_menu_leaves_the_game() -> void:
	var machine: Gen2SlotMachine = _machine()
	assert_true(_drive(machine, Gen2SlotMachine.Prompt.BET))
	machine.answer_bet(-1)
	assert_eq(machine.jumptable_index(), Gen2SlotMachine.SLOTS_QUIT)
	for _frame: int in 8:
		if machine.waiting_for_sfx():
			machine.sfx_finished()
		machine.advance()
	assert_true(machine.finished())


## `ReelAction_StopReel3` has no way to stop on a match the bias did not ask
## for, and `SLOTS_NO_BIAS` matches nothing: an unbiased spin cannot pay.
func test_an_unbiased_spin_never_lines_anything_up() -> void:
	var unbiased: int = 0
	for seed_value: int in 24:
		var machine: Gen2SlotMachine = _machine(200, false, seed_value)
		assert_true(_spin(machine, 3), "spin %d must reach its payout" % seed_value)
		if machine.bias() != Gen2SlotMachine.SLOTS_NO_BIAS:
			continue
		unbiased += 1
		assert_eq(
			machine.matched(), Gen2SlotMachine.SLOTS_NO_MATCH,
			"an unbiased spin lined up %d" % machine.matched()
		)
	assert_gt(unbiased, 0, "the sweep must reach an unbiased spin at all")


## `Slots_GetPayout.PayoutTable` against `wCoins`, over whichever seeds pay.
func test_a_match_pays_its_own_table_row() -> void:
	var paid: int = 0
	for seed_value: int in 64:
		var machine: Gen2SlotMachine = _machine(200, true, seed_value)
		assert_true(_spin(machine, 3))
		var matched: int = machine.matched()
		if matched == Gen2SlotMachine.SLOTS_NO_MATCH:
			assert_eq(machine.coins(), 197, "a losing spin must pay nothing")
			continue
		paid += 1
		assert_eq(
			machine.coins(), 197 + Gen2SlotMachine.PAYOUTS[matched / 4],
			"a %d match must pay its own row" % matched
		)
	assert_gt(paid, 0, "the lucky machine must pay at least once in 64 spins")


## `SlotsAction_PayoutAnim` moves one coin every other frame, so a three hundred
## coin win is six hundred frames of animation rather than one addition.
func test_the_payout_is_walked_over_one_coin_at_a_time() -> void:
	var machine: Gen2SlotMachine = _machine(200, true, 3)
	assert_true(_drive(machine, Gen2SlotMachine.Prompt.BET))
	machine.answer_bet(1)
	## Drive to the payout and watch the balance climb rather than jump.
	var seen: Array[int] = []
	for _frame: int in FRAME_CAP:
		if machine.prompt() == Gen2SlotMachine.Prompt.PRESS:
			break
		if machine.waiting_for_sfx():
			machine.sfx_finished()
			continue
		if machine.prompt() == Gen2SlotMachine.Prompt.TEXT:
			machine.dismiss_text()
			continue
		if machine.jumptable_index() in [
			Gen2SlotMachine.SLOTS_WAIT_REEL1, Gen2SlotMachine.SLOTS_WAIT_REEL2,
			Gen2SlotMachine.SLOTS_WAIT_REEL3,
		]:
			machine.press_a()
		machine.advance()
		if not seen.has(machine.coins()):
			seen.append(machine.coins())
	## The bet was taken before the loop, so the balance it starts on is the one
	## already paid for.
	if machine.matched() == Gen2SlotMachine.SLOTS_NO_MATCH:
		assert_eq(seen.size(), 1, "a losing spin moves the balance nowhere")
		return
	assert_eq(
		seen.size(), 1 + Gen2SlotMachine.PAYOUTS[machine.matched() / 4],
		"every coin of the payout must be its own step"
	)


## `Slots_CheckCoinCaseFull`: a case at MAX_COINS takes no more, and the payout
## still counts down.
func test_a_full_coin_case_takes_no_more() -> void:
	var machine: Gen2SlotMachine = _machine(Gen2SlotMachine.MAX_COINS, true, 3)
	assert_true(_spin(machine, 3))
	assert_true(machine.coins() <= Gen2SlotMachine.MAX_COINS)
	assert_eq(machine.payout(), 0, "the payout must drain whether it lands or not")


## `Slots_AskPlayAgain`'s own exit: no coins left prints its line, spends sixty
## frames and quits without asking anything.
func test_running_out_of_coins_ends_the_game_without_asking() -> void:
	var machine: Gen2SlotMachine = _machine(0)
	machine._ask_play_again()
	assert_eq(machine.prompt(), Gen2SlotMachine.Prompt.NONE)
	assert_eq(machine.jumptable_index(), Gen2SlotMachine.SLOTS_QUIT)
	var printed: Array = []
	for event: Variant in machine.take_events():
		printed.append((event as Dictionary).get("name", &""))
	assert_true(printed.has(&"ran_out_of_coins"))


## The same routine with coins left asks, and YES goes back to `SLOTS_INIT`.
func test_playing_again_starts_the_machine_over() -> void:
	var machine: Gen2SlotMachine = _machine(10)
	machine._ask_play_again()
	assert_eq(machine.prompt(), Gen2SlotMachine.Prompt.PLAY_AGAIN)
	machine.answer_play_again(true)
	assert_eq(machine.jumptable_index(), Gen2SlotMachine.SLOTS_INIT)


## `Slots_InitBias`' own `ret z`: SLOTS_SEVEN is zero, so a spin that left the
## bias there rolls nothing and keeps it.
func test_a_seven_bias_is_kept_rather_than_rerolled() -> void:
	var machine: Gen2SlotMachine = _machine()
	machine._bias = Gen2SlotMachine.SLOTS_SEVEN
	machine._init_bias()
	assert_eq(machine.bias(), Gen2SlotMachine.SLOTS_SEVEN)


## `.SpinReel`: a reel's action runs on every sixteenth unit of distance and the
## rate is what walks the objects between two symbols.
func test_a_reel_steps_a_symbol_every_sixteen_units() -> void:
	var machine: Gen2SlotMachine = _machine()
	var reel: Gen2SlotMachine.Reel = machine.reels()[0]
	var before: int = reel.position
	reel.spin_rate = Gen2SlotMachine.RATE_NORMAL
	for _step: int in 4:
		machine._spin_reel(0)
	assert_eq(reel.spin_distance, 16)
	assert_eq(reel.position, (before + 1) % Gen2SlotMachine.REEL_SIZE)


## The strips repeat their own first three symbols, so a window at the end of a
## reel reads three real ones rather than wrapping.
func test_every_window_is_three_symbols_of_the_strip() -> void:
	var machine: Gen2SlotMachine = _machine()
	var reel: Gen2SlotMachine.Reel = machine.reels()[0]
	for position: int in Gen2SlotMachine.REEL_SIZE:
		reel.position = position
		var window: PackedByteArray = reel.window()
		assert_eq(window.size(), 3)
		for symbol: int in window:
			assert_true(symbol in [0x00, 0x04, 0x08, 0x0C, 0x10, 0x14])


## `Slots_StopReel3`'s `and a / jr nz, .biased`: SLOTS_SEVEN is the zero that
## falls through, so Chansey belongs to the seven bias and to nothing else.
func test_only_a_seven_bias_can_throw_chansey() -> void:
	var chansey: int = Gen2SlotMachine.REEL_ACTION_INIT_CHANSEY
	var seen: Array[int] = []
	for roll: int in 256:
		var action: int = Gen2SlotMachine.reel3_action(Gen2SlotMachine.SLOTS_SEVEN, roll)
		if not seen.has(action):
			seen.append(action)
		for other: int in [0x04, 0x08, 0x0C, 0x10, 0x14, Gen2SlotMachine.SLOTS_NO_BIAS]:
			assert_ne(
				Gen2SlotMachine.reel3_action(other, roll), chansey,
				"bias %d roll %d must not reach Chansey" % [other, roll]
			)
	assert_true(seen.has(chansey), "a seven bias reaches Chansey below `24 percent - 1`")
	assert_eq(seen.size(), 4, "the seven block has all four modes in it")


## `PromptUserToPlaySlots` (engine/slots/slot_machine.asm) on a cache holding
## the three `SlotMachineWheel*` tables and nothing drawn, driven the same way.

const GEN1_WHEELS: Array = [
	[0x00, 0x02, 0x14, 0x16, 0x0C, 0x0E, 0x04, 0x06, 0x08, 0x0A, 0x00, 0x02,
		0x0C, 0x0E, 0x10, 0x12, 0x04, 0x06, 0x08, 0x0A, 0x00, 0x02, 0x14, 0x16,
		0x10, 0x12, 0x04, 0x06, 0x08, 0x0A, 0x00, 0x02, 0x14, 0x16, 0x0C, 0x0E],
	[0x00, 0x02, 0x0C, 0x0E, 0x08, 0x0A, 0x10, 0x12, 0x14, 0x16, 0x04, 0x06,
		0x08, 0x0A, 0x0C, 0x0E, 0x10, 0x12, 0x08, 0x0A, 0x04, 0x06, 0x0C, 0x0E,
		0x10, 0x12, 0x08, 0x0A, 0x14, 0x16, 0x00, 0x02, 0x0C, 0x0E, 0x08, 0x0A],
	[0x00, 0x02, 0x10, 0x12, 0x0C, 0x0E, 0x08, 0x0A, 0x14, 0x16, 0x10, 0x12,
		0x0C, 0x0E, 0x08, 0x0A, 0x14, 0x16, 0x10, 0x12, 0x0C, 0x0E, 0x08, 0x0A,
		0x14, 0x16, 0x10, 0x12, 0x04, 0x06, 0x00, 0x02, 0x10, 0x12, 0x0C, 0x0E],
]
const GEN1_SHA1: String = "0000000000000000000000000000000000000002"
var _gen1_directories: Array[String] = []


func after_each() -> void:
	for directory: String in _gen1_directories:
		RomCache.clear(directory)
	_gen1_directories.clear()


func _gen1_data() -> GameData:
	var directory: String = RomCache.directory_for(RomRegistry.RED, GEN1_SHA1)
	RomCache.clear(directory)
	RomCache.prepare(directory)
	_gen1_directories.append(directory)
	var tilemap: Array = []
	tilemap.resize(240)
	tilemap.fill(0)
	var palettes: Array = []
	palettes.resize(16)
	palettes.fill(0x7FFF)
	RomCache.write_json(RomCache.manifest_path(directory), {
		"format_version": RomCache.FORMAT_VERSION, "complete": true,
		"game_id": String(RomRegistry.RED), "generation": RomRegistry.GEN1,
		"slots": {"tilemap": tilemap, "reels": GEN1_WHEELS, "palettes": palettes, "blocks": []},
		"slots_text": {
			"play": "A slot machine!\nWant to play?", "out_of_coins": "Darn!\nRan out of coins!",
			"bet": "Bet how many\ncoins?", "start": "Start!",
			"not_enough_coins": "Not enough\ncoins!", "one_more_go": "One more \ngo?",
			"lined_up": " lined up!\nScored <RAM_CF4B> coins!", "not_this_time": "Not this time!",
			"yeah": "Yeah!",
		},
		"tiles": {},
	})
	var data: GameData = GameData.open_directory(directory)
	data.id = RomRegistry.RED
	return data


func _gen1_machine(coins: int = 200, lucky: bool = false, seed_value: int = 1) -> Gen1SlotMachine:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return Gen1SlotMachine.create_gen1(_gen1_data(), coins, lucky, rng)


## Drives to [param stop_at], pressing A once a spin is in `.loop2` and every
## box past, the way the check topic does.
func _gen1_drive(machine: Gen1SlotMachine, stop_at: int, frames: int = FRAME_CAP) -> bool:
	for _frame: int in frames:
		if machine.prompt() == stop_at:
			return true
		if machine.waiting_for_sfx():
			machine.sfx_finished()
			continue
		if machine.prompt() == Gen2SlotMachine.Prompt.TEXT:
			machine.dismiss_text()
			continue
		if machine.state() == Gen1SlotMachine.State.SPIN:
			machine.press_a()
		if not machine.advance():
			return machine.prompt() == stop_at
	return false


func _gen1_spin(machine: Gen1SlotMachine, bet: int) -> bool:
	if not _gen1_drive(machine, Gen2SlotMachine.Prompt.BET):
		return false
	machine.answer_bet(4 - bet)
	return _gen1_drive(machine, Gen2SlotMachine.Prompt.PLAY_AGAIN)


func _gen1_events(machine: Gen1SlotMachine) -> Array:
	var out: Array = []
	for event: Variant in machine.take_events():
		out.append(event)
	return out


## `GBPalWhiteOutWithDelay3`, then `MainSlotMachineLoop`'s bet menu on `×3`.
func test_gen1_opens_white_and_lands_on_the_bet_menu() -> void:
	var machine: Gen1SlotMachine = _gen1_machine()
	assert_eq(machine.lcd.bgp, 0)
	for _frame: int in Gen1SlotMachine.WHITE_OUT_FRAMES:
		machine.advance()
	assert_eq(machine.prompt(), Gen2SlotMachine.Prompt.BET)
	assert_eq(machine.lcd.bgp, Gen1SlotMachine.PALETTE_NORMAL)
	assert_eq(Array(machine.wheel_offsets()), [29, 29, 29], "LoadSlotMachineTiles draws $1c and moves on")


## `.loop`'s `jp nz, LoadScreenTilesFromBuffer1`: B leaves the loop with the
## purse untouched, and the white-out spends its three frames.
func test_gen1_b_on_the_bet_menu_leaves() -> void:
	var machine: Gen1SlotMachine = _gen1_machine(50)
	assert_true(_gen1_drive(machine, Gen2SlotMachine.Prompt.BET))
	machine.answer_bet(-1)
	assert_eq(machine.state(), Gen1SlotMachine.State.CLOSING)
	var frames: int = 0
	while frames < FRAME_CAP:
		frames += 1
		if not machine.advance():
			break
	assert_eq(frames, Gen1SlotMachine.WHITE_OUT_FRAMES, "the loop returns on the third VBlank")
	assert_eq(machine.coins(), 50)


## `.skip1`'s compare against `wPlayerCoins`: a bet the purse cannot cover
## prints `NotEnoughCoinsSlotMachineText` and the menu comes back.
func test_gen1_a_bet_over_the_balance_is_refused() -> void:
	var machine: Gen1SlotMachine = _gen1_machine(2)
	assert_true(_gen1_drive(machine, Gen2SlotMachine.Prompt.BET))
	machine.answer_bet(1)
	assert_eq(machine.prompt(), Gen2SlotMachine.Prompt.TEXT)
	assert_eq(machine.prompt_name(), &"not_enough_coins")
	machine.dismiss_text()
	assert_eq(machine.prompt(), Gen2SlotMachine.Prompt.BET)
	assert_eq(machine.coins(), 2)


## Every wheel stops on an odd offset, which is three whole symbols, and the
## bet left the purse once whatever the spin paid.
func test_gen1_every_wheel_stops_centred() -> void:
	for seed_value: int in 6:
		var machine: Gen1SlotMachine = _gen1_machine(200, seed_value % 2 == 1, seed_value)
		assert_true(_gen1_spin(machine, 3), "seed %d never ended its spin" % seed_value)
		for offset: int in machine.wheel_offsets():
			assert_eq(offset & 1, 1, "seed %d stopped on offset %d" % [seed_value, offset])
		var payout: int = 0 if machine.winning_symbol() < 0 \
			else Gen1SlotMachine.REWARDS[machine.winning_symbol() / 4]
		assert_eq(machine.coins(), 197 + payout)


## `.foundMatch` with neither flag set rolls wheel 3 on rather than paying, so
## a spin the flags forbid ends on `NotThisTimeText` whatever lined up.
func test_gen1_nothing_pays_while_the_flags_forbid_it() -> void:
	for seed_value: int in 8:
		var machine: Gen1SlotMachine = _gen1_machine(200, false, 20 + seed_value)
		assert_true(_gen1_drive(machine, Gen2SlotMachine.Prompt.BET))
		machine.answer_bet(1)
		machine._flags = 0
		machine._allow_matches = 0
		assert_true(_gen1_drive(machine, Gen2SlotMachine.Prompt.PLAY_AGAIN))
		assert_eq(machine.winning_symbol(), -1)
		assert_eq(machine.coins(), 197)


## `SlotMachine_PayCoinsToPlayer`: a coin a step with `SFX_SLOTS_REWARD` each,
## eight frames apart, `rOBP0` flipped every fifth, and the music held.
func test_gen1_the_payout_is_walked_over_one_coin_at_a_time() -> void:
	var machine: Gen1SlotMachine = _gen1_machine(100)
	assert_true(_gen1_drive(machine, Gen2SlotMachine.Prompt.BET))
	machine.answer_bet(3)
	machine._coins = 99
	machine._winning = 8
	machine._payout = 8
	machine._state = Gen1SlotMachine.State.LINED_UP
	machine._prompt = Gen2SlotMachine.Prompt.TEXT
	machine.take_events()
	machine.dismiss_text()
	assert_true(machine.music_paused())
	var rewards: int = 0
	var frames: int = 0
	while machine.state() == Gen1SlotMachine.State.PAY and frames < FRAME_CAP:
		if machine.waiting_for_sfx():
			machine.sfx_finished()
		machine.advance()
		frames += 1
		for event: Variant in _gen1_events(machine):
			if int((event as Dictionary).get("index", -1)) == Gen1SlotMachine.SFX_SLOTS_REWARD:
				rewards += 1
	assert_eq(rewards, 8)
	assert_eq(machine.coins(), 107)
	assert_eq(machine.payout(), 0)
	assert_eq(frames, 8 * Gen1SlotMachine.PAYOUT_FRAMES + 1)
	assert_false(machine.music_paused())
	assert_eq(machine.lcd.obp0, Gen1SlotMachine.PALETTE_NORMAL)


## `OutOfCoinsSlotMachineText` and `ld c, 60`: no coins left ends the loop
## without the YES/NO box.
func test_gen1_running_out_of_coins_ends_the_game_without_asking() -> void:
	var machine: Gen1SlotMachine = _gen1_machine(1, false, 3)
	assert_true(_gen1_drive(machine, Gen2SlotMachine.Prompt.BET))
	machine.answer_bet(3)
	machine._flags = 0
	machine._allow_matches = 0
	assert_true(_gen1_drive(machine, Gen2SlotMachine.Prompt.PLAY_AGAIN, 600)
		or machine.state() == Gen1SlotMachine.State.OUT_OF_COINS
		or machine.state() == Gen1SlotMachine.State.CLOSING
		or machine.finished())
	assert_ne(machine.prompt(), Gen2SlotMachine.Prompt.PLAY_AGAIN)
	assert_eq(machine.coins(), 0)


## `SlotMachine_StopWheel2Early` stops the wheel once a symbol lines up with
## wheel 1, and in seven-and-bar mode only on a seven or a bar.
func test_gen1_wheel_two_stops_on_a_line_up() -> void:
	var machine: Gen1SlotMachine = _gen1_machine()
	var one: Gen1SlotMachine.Wheel = machine._wheels[0]
	var two: Gen1SlotMachine.Wheel = machine._wheels[1]
	one.offset = 1
	two.offset = 1
	two.slip = 4
	machine._flags = 0
	assert_true(machine._stop_wheel_2_early(), "wheel 2's bottom seven lines up with wheel 1's")
	assert_eq(two.slip, 0)
	two.offset = 3
	two.slip = 4
	assert_false(machine._stop_wheel_2_early(), "nothing of $0C, $08, $10 stands on wheel 1's $02, $14, $0C at 1")
	machine._flags = Gen1SlotMachine.FLAG_CAN_WIN_7_OR_BAR
	two.offset = 1
	two.slip = 4
	assert_true(machine._stop_wheel_2_early(), "a lined-up seven stops it")
	two.offset = 5
	two.slip = 4
	assert_false(machine._stop_wheel_2_early(), "a cherry at the bottom keeps it spinning")
