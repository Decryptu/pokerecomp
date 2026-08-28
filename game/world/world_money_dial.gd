class_name Gen2WorldMoneyDial
extends RefCounted

## `Mom_WithdrawDepositMenuJoypad`, the six-digit money dial her bank is the only
## caller of. It owns `wStringBuffer2`, the amount being typed, and
## `wMomBankDigitCursorPosition`, which digit the cursor stands on; the caller owns
## the box the three balances are drawn in. Not [Gen2WorldQuantityPrompt], which is
## `BuySellToss_InterpretJoypad`: that dial steps one value against a ceiling and
## this one adds and subtracts a power of ten per digit, so up on the hundreds
## column moves the amount by a hundred rather than moving a digit.

## `.DigitQuantities`, `10**x` for x from five down to nought. The table is
## written out three times in the source and only the first sixth is indexed:
## `.getdigitquantity` adds the cursor position three times, which is one
## `bigdt` row.
const DIGITS: int = 6
## `MAX_MONEY`, which `GiveMoney` clamps the typed amount to.
const MAXIMUM: int = Gen2WorldInventory.MAX_MONEY

## `Mom_DepositString` and `Mon_WithdrawString`, the word over the amount and
## the whole difference between the two headers.
const MODE_DEPOSIT: StringName = &"deposit"
const MODE_WITHDRAW: StringName = &"withdraw"
const WORD_OF: Dictionary = {MODE_DEPOSIT: "DEPOSIT", MODE_WITHDRAW: "WITHDRAW"}

const PENDING: StringName = &"pending"
const CONFIRMED: StringName = &"confirmed"
const CANCELLED: StringName = &"cancelled"

## `Mom_SetUpDepositMenu` and `Mom_SetUpWithdrawMenu`, which differ only in the
## word over the amount.
var mode: StringName = MODE_DEPOSIT
## `wMomsMoney` and `wMoney` as the box drew them, which is a picture rather
## than a balance: the transaction is settled by the runner once A is pressed.
var saved: int = 0
var held: int = 0
## `wStringBuffer2`, zeroed by `.StoreMoney` before the box opens.
var value: int = 0
## `wMomBankDigitCursorPosition`, `ld a, 5` on entry: the ones column.
var cursor: int = DIGITS - 1


static func open(mode_name: StringName, saved_balance: int, held_balance: int) -> Gen2WorldMoneyDial:
	var dial := Gen2WorldMoneyDial.new()
	dial.mode = mode_name
	dial.saved = maxi(saved_balance, 0)
	dial.held = maxi(held_balance, 0)
	return dial


func press(button: int) -> StringName:
	match button:
		Gen2Button.A:
			return CONFIRMED
		Gen2Button.B:
			return CANCELLED
		Gen2Button.UP:
			## `.incrementdigit` is `GiveMoney`, so the whole amount is clamped
			## at the ceiling rather than the digit wrapping.
			value = mini(value + _step(), MAXIMUM)
		Gen2Button.DOWN:
			## `.decrementdigit` is `TakeMoney`, which leaves zero rather than
			## borrowing past it.
			value = maxi(value - _step(), 0)
		Gen2Button.LEFT:
			## `.movecursorleft` and `.movecursorright` both `ret` at the edge:
			## the cursor stops rather than wrapping.
			cursor = maxi(cursor - 1, 0)
		Gen2Button.RIGHT:
			cursor = mini(cursor + 1, DIGITS - 1)
	return PENDING


## What `PrintNum` draws with PRINTNUM_MONEY and PRINTNUM_LEADINGZEROS: six
## digits behind the currency mark, with no blanks in front of them.
func amount_string() -> String:
	return "¥%s" % String.num_int64(value).lpad(DIGITS, "0")


func _step() -> int:
	return int(pow(10, DIGITS - 1 - cursor))
