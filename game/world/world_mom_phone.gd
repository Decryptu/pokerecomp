class_name Gen2WorldMomPhone
extends RefCounted

## `engine/events/mom_phone.asm`: what Mom's savings buy while the player is out,
## and the call she makes about it. `MomTriesToBuySomething` runs after a trainer
## battle, on the same `Script_reloadmapafterbattle` branch `Script_SpecialBillCall`
## sits opposite. It reads her balance, decides whether a purchase is due, hands
## the item over and puts her on the line. Scene-free like the other world hosts,
## and split the way the source is: this file is the decision, applying it is
## [method Gen2WorldAPI.mom_purchase] and the call is
## [method Gen2WorldAPI.request_caller_phone_call].

## `PhoneContacts` index. Mom is the second row on all three cartridges.
const CONTACT_MOM: int = 1

## `MOMITEM_KIND`. An item goes to the PC, a doll to the player's room.
const KIND_ITEM: int = 1
const KIND_DOLL: int = 2


## `MomTriesToBuySomething` down to its `scf`: whether a purchase is due, and
## which row it is. [param random_row] is `RandomRange`'s answer over
## `MomItems_1`, drawn by the caller so nothing here reaches a global generator.
##
## Answers `{ ok, reason }` when nothing is bought, and otherwise the row, the
## set and index to store, and the trigger balance the walk left behind.
static func resolve(
	data: GameData,
	state: Gen2WorldState,
	map: Gen2WorldMap,
	random_row: int = 0
) -> Dictionary:
	if data == null or state == null:
		return {"ok": false, "reason": &"mom_data_unavailable"}
	## `GetMapPhoneService`: she cannot ring where a phone cannot.
	if not Gen2WorldPhoneHost.map_has_phone_service(map):
		return {"ok": false, "reason": &"phone_service_unavailable"}
	var savings: int = state.money(Gen2WorldScriptRunner.ACCOUNT_MOMS_MONEY)
	## `CheckBalance_MomItem2`'s first half: the ladder, in order, and only while
	## a row is left. `wWhichMomItem` never goes back.
	var index: int = state.mom_item_index()
	if index < data.mom_item_count(0):
		var row: Dictionary = data.mom_item(0, index)
		if not row.is_empty() and savings >= int(row.get("trigger", 0)):
			return _purchase(row, index, 0, state.mom_item_trigger_balance())
	## `.check_have_2300`: the trigger balance climbs by `MOM_MONEY` until it
	## reaches her savings, and she buys only when it lands on them exactly.
	var trigger: int = state.mom_item_trigger_balance()
	while trigger < savings:
		trigger += Gen2Layout.MOM_MONEY
	if trigger != savings:
		return {
			"ok": false, "reason": &"mom_balance_not_on_a_boundary",
			"trigger_balance": trigger,
		}
	trigger += Gen2Layout.MOM_MONEY
	var count: int = data.mom_item_count(1)
	if count <= 0:
		return {"ok": false, "reason": &"mom_items_unavailable"}
	var chosen: int = posmod(random_row, count)
	return _purchase(data.mom_item(1, chosen), index, chosen + 1, trigger)


static func _purchase(
	row: Dictionary, index: int, set_number: int, trigger_balance: int
) -> Dictionary:
	if row.is_empty():
		return {"ok": false, "reason": &"mom_items_unavailable"}
	var doll: bool = int(row.get("kind", KIND_ITEM)) == KIND_DOLL
	return {
		"ok": true,
		"row": row.duplicate(),
		"doll": doll,
		"item": int(row.get("item", 0)),
		"cost": int(row.get("cost", 0)),
		## `.ASMFunction`'s `inc [hl]`, which only the ladder reaches: a random
		## pick out of `MomItems_1` leaves `wWhichMomItem` where it was.
		"next_index": index + 1 if set_number == 0 else index,
		"set": set_number,
		"trigger_balance": trigger_balance,
	}
