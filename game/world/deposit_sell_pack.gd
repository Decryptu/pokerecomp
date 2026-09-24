class_name Gen2DepositSellPack
extends RefCounted

## `SellMenu` and `PlayerDepositItemMenu` over `DepositSellPack`: each chosen
## stack's words, dial and transaction. [Gen2StartMenuScreen] draws the pack.

const SELL: StringName = &"sell"
const DEPOSIT: StringName = &"deposit"
## `SellItem_MenuHeader`, `TossItem_MenuHeader` and the money box.
const SELL_DIAL: Rect2i = Rect2i(7, 15, 12, 2)
const DEPOSIT_DIAL: Rect2i = Rect2i(15, 9, 4, 2)
const MONEY_BOX: Rect2i = Rect2i(0, 11, 8, 2)

var kind: StringName = SELL
var _world: Gen2WorldAPI = null
var _save: Gen2SaveData = null
var _persist: bool = true
var _item: int = 0
var _name: String = ""


static func open(
	action: StringName, world: Gen2WorldAPI, save: Gen2SaveData, persist: bool
) -> Gen2DepositSellPack:
	var out := Gen2DepositSellPack.new()
	out.kind = action
	out._world = world
	out._save = save
	out._persist = persist
	return out


## A refusal, an untossable deposit applied at one, or nothing for the dial.
func choose(item: int, item_name: String) -> Dictionary:
	_item = item
	_name = item_name
	var tossable: bool = Gen2WorldPack.can_toss(_data(), item)
	if kind == SELL and not Gen2WorldMartHost.can_sell(_data(), item):
		return {"refusal": _data().mart_text("cant_buy")}
	if kind == DEPOSIT and not tossable:
		return {"applied": apply(1)}
	return {}


func how_many_text() -> String:
	return _data().mart_text("sell_how_many") if kind == SELL \
		else _data().pokecenter_pc_text("how_many_deposit")


func dial_box() -> Rect2i:
	return SELL_DIAL if kind == SELL else DEPOSIT_DIAL


## `DisplaySellingPrice` beside the count; `NoPriceToDisplay` is -1.
func subtotal(quantity: int) -> int:
	return Gen2WorldMartHost.sell_price(_data(), _item, quantity) if kind == SELL else -1


func shows_money() -> bool:
	return kind == SELL


func money() -> int:
	return _world.state.money(Gen2WorldMartHost.MONEY_ACCOUNT)


func asks_price() -> bool:
	return kind == SELL


func price_text(quantity: int) -> String:
	return Gen2WorldMartHost.fill_text(
		_data().mart_text("sell_price"), {"total": subtotal(quantity), "quantity": quantity}
	)


## The transaction's `text`, and `sfx` for `PlayTransactionSound`.
func apply(quantity: int) -> Dictionary:
	var result: Dictionary = Gen2WorldMartHost.sell(_world, _save, _item, quantity, _persist) \
		if kind == SELL else Gen2WorldPC.deposit(_world, _save, _item, quantity, _persist)
	if not bool(result.get("ok", false)):
		var reason: StringName = StringName(result.get("reason", &""))
		if kind == DEPOSIT and reason in [&"pc_full", &"item_stack_full"]:
			return {"text": _data().pokecenter_pc_text("no_room_deposit")}
		return {"text": "Refused: %s" % String(reason)}
	if kind == DEPOSIT:
		return {"text": Gen2WorldMartHost.fill_text(
			_data().pokecenter_pc_text("deposited"), {"name": _name, "quantity": quantity}
		)}
	return {"sfx": Gen2Sfx.SFX_TRANSACTION, "text": Gen2WorldMartHost.fill_text(
		_data().mart_text("bought"),
		{"name": _name, "quantity": quantity, "total": int(result.get("total", 0))}
	)}


func _data() -> GameData:
	return _world.data
