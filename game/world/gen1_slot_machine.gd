class_name Gen1SlotMachine
extends Gen2SlotMachine

## `PromptUserToPlaySlots` (engine/slots/slot_machine.asm), one VBlank an
## [method advance], drawn into a [Gen1Lcd]. A wheel's offset is one byte past
## the row it has drawn, so it stops on an odd offset and shows three whole
## symbols; the odds only decide whether wheel 3 rolls on past a match.

## `dw SLOTS7` and its neighbours: the low byte is the bottom row's first tile,
## the high byte the top row's, and `wSlotMachineWinningSymbol` is the high less two.
const SLOTS7: int = 0x0200
const SLOTSBAR: int = 0x0604
const SLOTSCHERRY: int = 0x0A08
const SLOTSFISH: int = 0x0E0C
const SLOTSBIRD: int = 0x1210
const SLOTSMOUSE: int = 0x1614
const SYMBOL_STEP: int = 4
const SYMBOL_ID_OFFSET: int = 2
## `SlotRewardPointers` in symbol order: the payout and the flash count `b`.
const REWARDS: Array[int] = [300, 100, 8, 15, 15, 15]
const FLASHES: Array[int] = [0x14, 0x08, 0x02, 0x04, 0x04, 0x04]
const REWARD_300: int = 0
const REWARD_100: int = 1
## `HIGH(SLOTSBAR) + 1`: a symbol below it is a seven or a bar.
const SEVEN_OR_BAR_LIMIT: int = (SLOTSBAR >> 8) + 1

const FLAG_CAN_WIN: int = 1 << 6
const FLAG_CAN_WIN_7_OR_BAR: int = 1 << 7
## `SlotMachine_SetFlags`' rolls and `StartSlotMachine`'s two chances.
const CHANCE_LUCKY: int = 250
const CHANCE_NORMAL: int = 253
const CHANCE_MATCHES: int = 210
const ALLOW_MATCHES_COUNTER: int = 60
const REWARD_300_KEEP_FLAGS_BELOW: int = 0x80

## `LoadSlotMachineTiles`' `ld a, $1c` and `SlotMachine_AnimWheel`'s wrap at 30.
const WHEEL_START_OFFSET: int = 0x1C
const WHEEL_WRAP: int = 30
const WHEEL_ROWS: int = 6
const WHEEL_OAM_SLOTS: int = WHEEL_ROWS * 2
const WHEEL_BASE_Y: int = 0x58
const WHEEL_X: Array[int] = [0x30, 0x50, 0x70]
const WHEEL_ATTRIBUTES: int = Gen1Lcd.OAM_PRIO
## `SlotMachine_SpinWheels`' twenty free passes at two frames, then `.loop2`'s
## `DelayFrame` and one more on a Super Game Boy.
const FREE_SPIN_PASSES: int = 20
const FREE_SPIN_FRAMES: int = 2
const SPIN_FRAMES: int = 2
const SLIP_COUNTER: int = 4
const REROLL_COUNTER: int = 4

## `.flashScreenLoop`'s five frames a step and its `xor $40`, which is the same
## bit `SlotMachine_PayCoinsToPlayer` flips on `rOBP0` every fifth coin.
const SCREEN_FLASH_FRAMES: int = 5
const PALETTE_FLASH: int = 0x40
const PAYOUT_FRAMES: int = 8
const PAYOUT_FRAMES_7_OR_BAR: int = 4
const PAYOUT_FLASH_EVERY: int = 5
const OUT_OF_COINS_FRAMES: int = 60
const YES_FRAMES: int = 15
## `GBPalWhiteOutWithDelay3` on the way in and out, and `Delay3` at the end.
const WHITE_OUT_FRAMES: int = 3
const PALETTE_NORMAL: int = 0xE4
const CURSOR_BLINK_FRAMES: int = Gen2TextBox.CURSOR_BLINK_FRAMES

const SFX_SLOTS_STOP_WHEEL: int = 190
const SFX_SLOTS_REWARD: int = 191
const SFX_SLOTS_NEW_SPIN: int = 192
const SFX_GET_KEY_ITEM: int = 148
const SFX_GET_ITEM_2: int = 137
const SFX_PRESS_AB: int = 144

## Where `LoadSlotMachineTiles` puts each sheet, as [Gen1Lcd] tiles.
const OBJECT_TILES: int = 0
const BACKGROUND_TILES_1: int = Gen1Lcd.SIGNED_BASE
const BACKGROUND_TILES_2: int = Gen1Lcd.SIGNED_BASE + 0x25
const FONT_TILES: int = Gen1Lcd.BLOCK_TILES
const TEXT_BOX_TILES: int = Gen1Lcd.SIGNED_BASE + Gen1Layout.FONT_EXTRA_FIRST_CODE
const WINNING_SYMBOL_TILE: int = 0x25
const WINNING_SYMBOL_AT: Vector2i = Vector2i(2, 13)

const COLUMNS: int = Gen1Layout.SCREEN_WIDTH_TILES
const ROWS: int = 18
## `SlotMachine_UpdateBallTiles`: two cells down at columns 3 and 16.
const BALL_LIT: int = 0x14
const BALL_UNLIT: int = 0x23
const BALL_COLUMNS: Array[int] = [3, 16]
const BALL_ROWS: Array[Array] = [[6], [4, 8], [2, 10]]
const CREDIT_AT: Vector2i = Vector2i(5, 1)
const PAYOUT_AT: Vector2i = Vector2i(11, 1)
const DIGITS: int = 4
## `PrintText`'s box and where `text` and `line` land.
const BOX_AT: Vector2i = Vector2i(0, 12)
const BOX_INNER: Vector2i = Vector2i(18, 4)
const TEXT_AT: Vector2i = Vector2i(1, 14)
const LINE_STEP: int = 2
const ARROW_AT: Vector2i = Vector2i(18, 16)
## `MainSlotMachineLoop`'s bet box and `CoinMultiplierSlotMachineText`.
const BET_BOX_AT: Vector2i = Vector2i(14, 11)
const BET_BOX_INNER: Vector2i = Vector2i(4, 5)
const BET_TEXT_AT: Vector2i = Vector2i(16, 12)
const BET_CURSOR_X: int = 15
const BET_ROWS: Array[String] = ["×3", "×2", "×1"]
## `TwoOptionMenuStrings`' YES/NO row at `hlcoord 14, 12`.
const YES_NO_BOX_AT: Vector2i = Vector2i(14, 12)
const YES_NO_BOX_INNER: Vector2i = Vector2i(4, 3)
const YES_NO_TEXT_AT: Vector2i = Vector2i(16, 13)
const YES_NO_CURSOR_X: int = 15
const YES_NO_ROWS: Array[String] = ["YES", "NO"]
const CURSOR: int = Gen1Text.ARROW_UP
const DOWN_ARROW: int = Gen1Text.ARROW_DOWN

enum State {
	WHITE_OUT,
	BET,
	NOT_ENOUGH,
	START,
	FREE_SPIN,
	SPIN,
	REROLL,
	YEAH,
	FLASH,
	LINED_UP,
	PAY,
	NOT_THIS_TIME,
	OUT_OF_COINS,
	ONE_MORE_GO,
	YES,
	CLOSING,
	DONE,
}

## One `SlotMachineWheel*` table with its own `wSlotMachineWheel*Offset`.
class Wheel extends RefCounted:
	var table: PackedByteArray = PackedByteArray()
	var offset: int = Gen1SlotMachine.WHEEL_START_OFFSET
	var slip: int = 0

	## `SlotMachine_GetWheelTiles`: bottom, middle and top, every other byte.
	func tiles() -> PackedInt32Array:
		var out := PackedInt32Array()
		for row: int in 3:
			out.append(table[offset + row * 2])
		return out

	## `rra / jr nc`: the wheel may stop only on an odd offset.
	func centred() -> bool:
		return offset & 1 == 1


var lcd: Gen1Lcd = Gen1Lcd.new()
var _data: GameData = null
var _state: int = State.WHITE_OUT
var _wait: int = 0
var _wheels: Array[Wheel] = []
var _flags: int = 0
var _allow_matches: int = 0
var _chance: int = CHANCE_NORMAL
var _stopping: int = 0
var _reroll: int = 0
var _winning: int = -1
var _flashes_left: int = 0
var _anim_counter: int = 0
var _passes: int = 0
var _lines: PackedStringArray = PackedStringArray()
var _arrow: bool = false
var _arrow_clock: int = 0
var _bet_cursor: int = 0
var _yes_no_cursor: int = 0
var _music_paused: bool = false


static func create_gen1(
	data: GameData, start_coins: int, lucky: bool, rng: RandomNumberGenerator
) -> Gen1SlotMachine:
	var machine := Gen1SlotMachine.new()
	machine._data = data
	machine._rng = rng
	machine._coins = clampi(start_coins, 0, MAX_COINS)
	machine._lucky = lucky
	machine._chance = CHANCE_LUCKY if lucky else CHANCE_NORMAL
	for wheel: int in Gen1Layout.SLOTS_WHEELS:
		var reel := Wheel.new()
		reel.table = data.slots_reel(wheel)
		machine._wheels.append(reel)
	machine._load_screen()
	machine._white_out()
	machine._wait = WHITE_OUT_FRAMES
	return machine


func gen1() -> bool:
	return true


func state() -> int:
	return _state


func flags() -> int:
	return _flags


func allow_matches_counter() -> int:
	return _allow_matches


func winning_symbol() -> int:
	return _winning


func wheel_offsets() -> PackedInt32Array:
	var out := PackedInt32Array()
	for wheel: Wheel in _wheels:
		out.append(wheel.offset)
	return out


func stopping() -> int:
	return _stopping


func music_paused() -> bool:
	return _music_paused


func palettes() -> Array:
	var out: Array = []
	for index: int in Gen1Layout.PAL_SET_PALETTES:
		out.append(_data.slots_palette(index) if _data != null else PackedColorArray())
	return out


func blocks() -> Array:
	return _data.slots_blocks() if _data != null else []


func finished() -> bool:
	return _state == State.DONE


func set_menu_cursor(bet_row: int, yes_no_row: int) -> void:
	if _prompt == Prompt.BET and bet_row != _bet_cursor:
		_bet_cursor = bet_row
		_draw_bet_menu()
	if _prompt == Prompt.PLAY_AGAIN and yes_no_row != _yes_no_cursor:
		_yes_no_cursor = yes_no_row
		_draw_yes_no()


func advance() -> bool:
	if _state == State.DONE:
		return false
	if _waiting_sfx:
		return true
	if _arrow:
		_blink_arrow()
	if _prompt != Prompt.NONE:
		return true
	if _wait > 0:
		_wait -= 1
		if _wait > 0:
			return true
	_step()
	return _state != State.DONE


## `HandleMenuInput` over the bet box: [param option] is the row, 1 for ×3, and
## -1 the B that leaves `MainSlotMachineLoop`.
func answer_bet(option: int) -> void:
	if _prompt != Prompt.BET:
		return
	_prompt = Prompt.NONE
	_prompt_name = &""
	_play(SFX_PRESS_AB)
	_restore_bet_line()
	if option < 1 or option > BET_ROWS.size():
		_close()
		return
	_bet = SYMBOL_STEP - option
	if _coins < _bet:
		_print(&"not_enough_coins", Prompt.TEXT)
		_state = State.NOT_ENOUGH
		return
	_take_bet()


## `WaitForTextScrollButtonPress` answered, with `ManualTextScroll`'s own sound.
func dismiss_text() -> void:
	if _prompt != Prompt.TEXT:
		return
	_prompt = Prompt.NONE
	_prompt_name = &""
	_hide_arrow()
	_play(SFX_PRESS_AB)
	match _state:
		State.NOT_ENOUGH:
			_open_bet_menu()
		State.YEAH:
			_reward_300()
		State.LINED_UP:
			_start_payout()
		State.NOT_THIS_TIME:
			_after_spin()
		_:
			pass


## `DisplayTwoOptionMenu` answered: YES spends fifteen frames and plays again.
func answer_play_again(yes: bool) -> void:
	if _prompt != Prompt.PLAY_AGAIN:
		return
	_prompt = Prompt.NONE
	_prompt_name = &""
	_play(SFX_PRESS_AB)
	if not yes:
		_close()
		return
	_state = State.YES
	_wait = YES_FRAMES


func _step() -> void:
	match _state:
		State.WHITE_OUT:
			_show_machine()
		State.START:
			_start_spin()
		State.FREE_SPIN:
			_free_spin_pass()
		State.SPIN:
			_spin_pass()
		State.REROLL:
			_reroll_pass()
		State.FLASH:
			_flash_pass()
		State.PAY:
			_pay_pass()
		State.OUT_OF_COINS, State.CLOSING:
			_close()
		State.YES:
			_light_balls(BALL_UNLIT, BET_ROWS.size())
			_open_round()
		_:
			pass


## `LoadSlotMachineTiles` and `LoadFontTilePatterns`, with the text box tiles
## the overworld left at $60.
func _load_screen() -> void:
	lcd.lcdc = Gen1Lcd.LCDC_DEFAULT
	## The overworld parks the window off the screen, and nothing here moves it.
	lcd.wy = Gen1Opening.WINDOW_OFF
	_load_sheet("slots_2", OBJECT_TILES)
	_load_sheet("slots_1", BACKGROUND_TILES_1)
	_load_sheet("slots_2", BACKGROUND_TILES_2)
	_load_sheet("font", FONT_TILES)
	_load_sheet("font_extra", TEXT_BOX_TILES)
	lcd.fill_map(0, Gen1Text.SPACE)
	lcd.write_map(0, Vector2i.ZERO, COLUMNS, Gen1Layout.SLOTS_TILEMAP_ROWS, _data.slots_tilemap())
	for wheel: Wheel in _wheels:
		wheel.offset = WHEEL_START_OFFSET
	_anim_wheels()


func _load_sheet(sheet: String, at: int) -> void:
	var tiles: int = int(_data.tile_sheet(sheet).get("tiles", 0))
	lcd.load_tiles(at, _data.tile_indices(sheet), tiles, 0, tiles)


func _white_out() -> void:
	lcd.bgp = 0
	lcd.obp0 = 0
	lcd.obp1 = 0


func _show_machine() -> void:
	lcd.bgp = PALETTE_NORMAL
	lcd.obp0 = PALETTE_NORMAL
	_open_round()


## `MainSlotMachineLoop`'s head: the two counts, the bet line, then `.loop`.
func _open_round() -> void:
	_payout = 0
	_print_credit()
	_print_payout()
	_print(&"bet")
	_open_bet_menu()


func _open_bet_menu() -> void:
	_state = State.BET
	_bet_cursor = 1
	_draw_bet_menu()
	_prompt = Prompt.BET
	_prompt_name = &"bet"


func _restore_bet_line() -> void:
	_print(&"bet")


## `.skip1` to `SlotMachine_SpinWheels`, the spin sound behind `WaitForSoundToFinish`.
func _take_bet() -> void:
	_coins -= _bet
	_print_credit()
	_light_balls(BALL_LIT, _bet)
	_set_flags()
	for wheel: Wheel in _wheels:
		wheel.slip = SLIP_COUNTER
	_reroll = REROLL_COUNTER
	_state = State.START
	_waiting_sfx = true


func _start_spin() -> void:
	_play(SFX_SLOTS_NEW_SPIN)
	_print(&"start")
	_passes = 0
	_state = State.FREE_SPIN
	_free_spin_pass()


## `SlotMachine_SetFlags`. A seven-and-bar mode already set is kept.
func _set_flags() -> void:
	if _flags & FLAG_CAN_WIN_7_OR_BAR:
		return
	if _allow_matches != 0:
		_flags |= FLAG_CAN_WIN
		return
	var roll: int = _random()
	if roll == 0:
		_allow_matches = ALLOW_MATCHES_COUNTER
		return
	if _chance < roll:
		_flags |= FLAG_CAN_WIN_7_OR_BAR
		return
	if CHANCE_MATCHES < roll:
		_flags |= FLAG_CAN_WIN
		return
	_flags = 0


func _free_spin_pass() -> void:
	if _passes >= FREE_SPIN_PASSES:
		_stopping = 0
		_state = State.SPIN
		_spin_pass()
		return
	_passes += 1
	_anim_wheels()
	_wait = FREE_SPIN_FRAMES


func _spin_pass() -> void:
	if _pressed_a:
		_pressed_a = false
		_handle_stop_press()
	_stop_or_anim(0)
	_stop_or_anim(1)
	if _stop_or_anim(2):
		_check_for_matches()
		return
	_wait = SPIN_FRAMES


## `SlotMachine_HandleInputWhileWheelsSpin`: the next wheel is asked to stop once
## the one before it has, and a press before then is spent on nothing.
func _handle_stop_press() -> void:
	if _stopping >= 1 and _stopping <= 2 and _wheels[_stopping - 1].slip != 0:
		return
	_stopping += 1
	_play(SFX_SLOTS_STOP_WHEEL)


## `SlotMachine_StopOrAnimWheel1` to `3`. Answers whether wheel 3 has stopped.
func _stop_or_anim(index: int) -> bool:
	var wheel: Wheel = _wheels[index]
	if _stopping < index + 1 or not wheel.centred():
		_anim_wheel(index)
		return false
	if index == 2:
		return true
	if wheel.slip == 0:
		return false
	wheel.slip -= 1
	var stopped: bool = _stop_wheel_1_early() if index == 0 else _stop_wheel_2_early()
	if not stopped:
		_anim_wheel(index)
	return false


## `SlotMachine_StopWheel1Early`: stop unless the middle symbol is a cherry, and
## in seven-and-bar mode never, its `jr c` comparing a tile against its own id.
func _stop_wheel_1_early() -> bool:
	if _flags & FLAG_CAN_WIN_7_OR_BAR or _wheels[0].tiles()[1] == SLOTSCHERRY >> 8:
		return false
	_wheels[0].slip = 0
	return true


## `SlotMachine_StopWheel2Early`: stop once a symbol lines up with wheel 1. In
## seven-and-bar mode the tile read is the one the search ended on, the bottom
## when nothing lined up, and the wheel stops when that is a seven or a bar.
func _stop_wheel_2_early() -> bool:
	var row: int = _first_two_match_row()
	if _flags & FLAG_CAN_WIN_7_OR_BAR:
		if _wheels[1].tiles()[maxi(row, 0)] >= SEVEN_OR_BAR_LIMIT:
			return false
	elif row < 0:
		return false
	_wheels[1].slip = 0
	return true


## `SlotMachine_FindWheel1Wheel2Matches`: the five pairs wheel 3 could complete,
## answered as the wheel 2 row `de` stands on, or -1 for none.
func _first_two_match_row() -> int:
	var one: PackedInt32Array = _wheels[0].tiles()
	var two: PackedInt32Array = _wheels[1].tiles()
	for pair: Array in [[0, 0], [0, 1], [1, 1], [2, 1], [2, 2]]:
		if two[int(pair[1])] == one[int(pair[0])]:
			return int(pair[1])
	return -1


## `SlotMachine_CheckForMatches`: the lines a bet pays, then whether the odds let
## the match stand or roll wheel 3 on.
func _check_for_matches() -> void:
	var symbol: int = _matched_symbol()
	var may_win: bool = _flags & (FLAG_CAN_WIN | FLAG_CAN_WIN_7_OR_BAR) != 0
	if symbol < 0:
		if may_win:
			_reroll -= 1
			if _reroll != 0:
				_start_reroll()
				return
		_print(&"not_this_time", Prompt.TEXT)
		_state = State.NOT_THIS_TIME
		return
	if not may_win or (_flags & FLAG_CAN_WIN_7_OR_BAR == 0 and symbol < SEVEN_OR_BAR_LIMIT):
		_start_reroll()
		return
	_accept_match(symbol - SYMBOL_ID_OFFSET)


func _matched_symbol() -> int:
	var one: PackedInt32Array = _wheels[0].tiles()
	var two: PackedInt32Array = _wheels[1].tiles()
	var three: PackedInt32Array = _wheels[2].tiles()
	var lines: Array = [[1, 1, 1]]
	if _bet >= 2:
		lines = [[2, 2, 2], [0, 0, 0]] + lines
	if _bet == 3:
		lines = [[0, 1, 2], [2, 1, 0]] + lines
	for line: Array in lines:
		var symbol: int = one[int(line[0])]
		if two[int(line[1])] == symbol and three[int(line[2])] == symbol:
			return symbol
	return -1


## `.rollWheel3DownByOneSymbol`: two steps a frame apart, then the check again.
func _start_reroll() -> void:
	_state = State.REROLL
	_passes = 0
	_reroll_pass()


func _reroll_pass() -> void:
	if _passes == 2:
		_check_for_matches()
		return
	_passes += 1
	_anim_wheel(2)
	_wait = 1


func _accept_match(symbol: int) -> void:
	_winning = symbol
	var reward: int = symbol / SYMBOL_STEP
	_payout = REWARDS[reward]
	_flashes_left = FLASHES[reward]
	_matched = symbol
	match reward:
		REWARD_300:
			_print(&"yeah", Prompt.TEXT)
			_state = State.YEAH
			return
		REWARD_100:
			_play(SFX_GET_KEY_ITEM)
			_flags = 0
		_:
			if _allow_matches != 0:
				_allow_matches -= 1
	_state = State.FLASH
	_flash_pass()


## `SlotReward300Func` behind `YeahText`'s press: half the time the flags are
## cleared, and the allow-matches counter always is.
func _reward_300() -> void:
	_play(SFX_GET_ITEM_2)
	if _random() >= REWARD_300_KEEP_FLAGS_BELOW:
		_flags = 0
	_allow_matches = 0
	_state = State.FLASH
	_flash_pass()


func _flash_pass() -> void:
	if _flashes_left == 0:
		_print_payout()
		_print(&"lined_up", Prompt.TEXT)
		_print_winning_symbol()
		_state = State.LINED_UP
		return
	_flashes_left -= 1
	lcd.bgp ^= PALETTE_FLASH
	_wait = SCREEN_FLASH_FRAMES


## `SlotMachine_PayCoinsToPlayer`: the music held, then a coin a step.
func _start_payout() -> void:
	_music_paused = true
	_events.append({"kind": &"music_paused", "paused": true})
	_anim_counter = PAYOUT_FLASH_EVERY
	_state = State.PAY
	_waiting_sfx = true


func _pay_pass() -> void:
	if _payout == 0:
		_print_payout()
		lcd.obp0 = PALETTE_NORMAL
		_music_paused = false
		_events.append({"kind": &"music_paused", "paused": false})
		_after_spin()
		return
	_payout -= 1
	_coins = mini(_coins + 1, MAX_COINS)
	_print_credit()
	_print_payout()
	_play(SFX_SLOTS_REWARD)
	_anim_counter -= 1
	if _anim_counter == 0:
		lcd.obp0 ^= PALETTE_FLASH
		_anim_counter = PAYOUT_FLASH_EVERY
	_wait = PAYOUT_FRAMES_7_OR_BAR if _winning < SEVEN_OR_BAR_LIMIT else PAYOUT_FRAMES


## `.skip2` and the branch before it: out of coins ends the loop, otherwise
## `OneMoreGoSlotMachineText` under the YES/NO box.
func _after_spin() -> void:
	if _coins == 0:
		_print(&"out_of_coins")
		_state = State.OUT_OF_COINS
		_wait = OUT_OF_COINS_FRAMES
		return
	_print(&"one_more_go")
	_yes_no_cursor = 1
	_draw_yes_no()
	_state = State.ONE_MORE_GO
	_prompt = Prompt.PLAY_AGAIN
	_prompt_name = &"one_more_go"


func _close() -> void:
	if _state == State.CLOSING:
		_state = State.DONE
		return
	_white_out()
	_state = State.CLOSING
	_wait = WHITE_OUT_FRAMES


## `SlotMachine_AnimWheel`: twelve objects from the offset up, then the offset moves on.
func _anim_wheel(index: int) -> void:
	var wheel: Wheel = _wheels[index]
	var slot: int = index * WHEEL_OAM_SLOTS
	var y: int = WHEEL_BASE_Y
	for row: int in WHEEL_ROWS:
		var tile: int = wheel.table[wheel.offset + row]
		lcd.set_sprite(slot, y, WHEEL_X[index], tile, WHEEL_ATTRIBUTES)
		lcd.set_sprite(slot + 1, y, WHEEL_X[index] + Gen1Lcd.TILE, tile + 1, WHEEL_ATTRIBUTES)
		slot += 2
		y -= Gen1Lcd.TILE
	wheel.offset = (wheel.offset + 1) % WHEEL_WRAP


func _anim_wheels() -> void:
	for index: int in _wheels.size():
		_anim_wheel(index)


## `SlotMachine_LightBalls` and `..._PutOutLitBalls`: the rows a bet reaches.
func _light_balls(tile: int, wager: int) -> void:
	for level: int in mini(wager, BALL_ROWS.size()):
		for row: int in BALL_ROWS[level]:
			for column: int in BALL_COLUMNS:
				_write(Vector2i(column, row), tile)
				_write(Vector2i(column, row + 1), tile + 1)


func _print_credit() -> void:
	_place_string(CREDIT_AT, ("%d" % _coins).lpad(DIGITS, "0"))


func _print_payout() -> void:
	_place_string(PAYOUT_AT, ("%d" % _payout).lpad(DIGITS, "0"))


## `SlotMachine_PrintWinningSymbol`: the symbol as background tiles, top row above.
func _print_winning_symbol() -> void:
	var first: int = WINNING_SYMBOL_TILE + _winning
	_write(WINNING_SYMBOL_AT + Vector2i(0, 1), first)
	_write(WINNING_SYMBOL_AT + Vector2i(1, 1), first + 1)
	_write(WINNING_SYMBOL_AT, first + 2)
	_write(WINNING_SYMBOL_AT + Vector2i(1, 0), first + 3)


## `PrintText`: the box, the lines, and `▼` when the box ends on `prompt`.
func _print(name: StringName, kind: int = Prompt.NONE) -> void:
	var text: String = _data.slots_text(String(name)) if _data != null else ""
	if name == &"lined_up":
		text = Gen2TextStream.fill_marker(text, Gen2TextStream.RAM_MARKER, str(_payout))
	_events.append({"kind": &"text", "name": name})
	_draw_box(BOX_AT, BOX_INNER)
	_lines = text.split("\n")
	for line: int in _lines.size():
		_place_string(TEXT_AT + Vector2i(0, line * LINE_STEP), _lines[line])
	if kind != Prompt.NONE:
		_prompt = kind
		_prompt_name = name
		_show_arrow()


func _show_arrow() -> void:
	_arrow = true
	_arrow_clock = 0
	_write(ARROW_AT, DOWN_ARROW)


func _hide_arrow() -> void:
	_arrow = false
	_write(ARROW_AT, Gen1Text.SPACE)


func _blink_arrow() -> void:
	_arrow_clock += 1
	var shown: bool = (_arrow_clock / CURSOR_BLINK_FRAMES) % 2 == 0
	_write(ARROW_AT, DOWN_ARROW if shown else Gen1Text.SPACE)


func _draw_bet_menu() -> void:
	_draw_box(BET_BOX_AT, BET_BOX_INNER)
	for row: int in BET_ROWS.size():
		var at: Vector2i = BET_TEXT_AT + Vector2i(0, row * LINE_STEP)
		_place_string(at, BET_ROWS[row])
		_write(Vector2i(BET_CURSOR_X, at.y), CURSOR if row == _bet_cursor - 1 else Gen1Text.SPACE)


func _draw_yes_no() -> void:
	_draw_box(YES_NO_BOX_AT, YES_NO_BOX_INNER)
	for row: int in YES_NO_ROWS.size():
		var at: Vector2i = YES_NO_TEXT_AT + Vector2i(0, row * LINE_STEP)
		_place_string(at, YES_NO_ROWS[row])
		_write(Vector2i(YES_NO_CURSOR_X, at.y), CURSOR if row == _yes_no_cursor - 1 else Gen1Text.SPACE)


func _draw_box(at: Vector2i, inner: Vector2i) -> void:
	var rows: Array = Gen1Text.text_box_rows(inner)
	for row: int in rows.size():
		var codes: Array = rows[row]
		for column: int in codes.size():
			_write(at + Vector2i(column, row), int(codes[column]))


func _place_string(at: Vector2i, text: String) -> void:
	var codes: PackedByteArray = Gen1Text.encode(text)
	for index: int in codes.size():
		_write(at + Vector2i(index, 0), codes[index])


func _write(at: Vector2i, tile: int) -> void:
	if at.x < 0 or at.x >= COLUMNS or at.y < 0 or at.y >= ROWS:
		return
	lcd.maps[0][at.y * Gen1Lcd.MAP_SIDE + at.x] = tile
