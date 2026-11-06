class_name Gen3Bag
extends RefCounted

## `item.c`'s bag and PC, with `money.c`'s and `coins.c`'s totals. FireRed and LeafGreen keep one 999 stack per item;
## Ruby, Sapphire and Emerald split stacks at 99 (berries 999) and refuse a second TM or berry slot once one exists.

const POCKET_SLOTS: Dictionary = {
	RomRegistry.RUBY: [20, 20, 16, 64, 46], RomRegistry.SAPPHIRE: [20, 20, 16, 64, 46],
	RomRegistry.FIRERED: [42, 30, 13, 58, 43], RomRegistry.LEAFGREEN: [42, 30, 13, 58, 43],
	RomRegistry.EMERALD: [30, 30, 16, 64, 46],
}
const PC_SLOTS: Dictionary = {
	RomRegistry.RUBY: 50, RomRegistry.SAPPHIRE: 50,
	RomRegistry.FIRERED: 30, RomRegistry.LEAFGREEN: 30, RomRegistry.EMERALD: 50,
}
const KEY_POCKET: int = 1
const TM_POCKET: int = 3
const BERRY_POCKET: int = 4
const STACK: int = 99
const LARGE_STACK: int = 999
const MAX_MONEY: int = 999999
const MAX_COINS: int = 9999
const POKE_BALL: int = 4
const FIRST_BERRY: int = 133
const LAST_BERRY: int = 175
const TM_CASE: int = 364
const BERRY_POUCH: int = 365
const GOT_BERRY_POUCH_FLAG: int = 0x847

var money: int = 0
var coins: int = 0
var _data: GameData
var _events: Gen3EventData
var _frlg: bool = false
var _pockets: Array = []
var _pc: Array = []


func _init(data: GameData, events: Gen3EventData) -> void:
	_data = data
	_events = events
	_frlg = events.game in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN]
	for size: int in POCKET_SLOTS[events.game]:
		_pockets.append(_empty(size))
	_pc = _empty(PC_SLOTS[events.game])


static func _empty(size: int) -> Array:
	var slots: Array = []
	slots.resize(size)
	slots.fill(Vector2i.ZERO)
	return slots


func pocket_of(item: int) -> int: # `GetPocketByItemId`: 0 for an item outside every pocket, else `POCKET_*`.
	return int(_data.item(item).get("pocket", 0))


func has(item: int, count: int) -> bool:
	var pocket: int = pocket_of(item)
	if pocket == 0:
		return false
	for slot: Vector2i in _pockets[pocket - 1]:
		if slot.x != item:
			continue
		if slot.y >= count:
			return true
		if _frlg:
			return false
		count -= slot.y
		if count == 0:
			return true
	return false


func has_space(item: int, count: int) -> bool:
	var pocket: int = pocket_of(item)
	if pocket == 0:
		return false
	return not (_one_stack_plan(pocket - 1, item, count) if _frlg else _split_plan(pocket - 1, item, count)).is_empty()


func add(item: int, count: int) -> bool:
	var pocket: int = pocket_of(item)
	if pocket == 0:
		return false
	if _frlg and not has(item, 1) and not _take_container(pocket - 1, item):
		return false
	var slots: Array = _one_stack_plan(pocket - 1, item, count) if _frlg else _split_plan(pocket - 1, item, count)
	if slots.is_empty():
		return false
	_pockets[pocket - 1] = slots
	return true


func _split_plan(pocket: int, item: int, count: int) -> Array: # `AddBagItem` on a copy of the pocket, so a refused overflow changes nothing.
	var slots: Array = _pockets[pocket].duplicate()
	var capacity: int = LARGE_STACK if pocket == BERRY_POCKET else STACK
	var single: bool = pocket in [TM_POCKET, BERRY_POCKET]
	for index: int in slots.size():
		var slot: Vector2i = slots[index]
		if slot.x != item:
			continue
		if slot.y + count <= capacity:
			slots[index] = Vector2i(item, slot.y + count)
			return slots
		if single:
			return []
		count -= capacity - slot.y
		slots[index] = Vector2i(item, capacity)
		if count == 0:
			return slots
	if count == 0:
		return slots
	for index: int in slots.size():
		if slots[index] != Vector2i.ZERO:
			continue
		if count > capacity and single and _events.game == RomRegistry.EMERALD:
			return []
		slots[index] = Vector2i(item, mini(count, capacity))
		count -= mini(count, capacity)
		if count == 0:
			return slots
	return []


func _one_stack_plan(pocket: int, item: int, count: int) -> Array:
	var slots: Array = _pockets[pocket].duplicate()
	for index: int in slots.size():
		var slot: Vector2i = slots[index]
		if slot.x == item:
			if slot.y + count > LARGE_STACK:
				return []
			slots[index] = Vector2i(item, slot.y + count)
			return slots
	var free: int = slots.find(Vector2i.ZERO)
	if free < 0:
		return []
	slots[free] = Vector2i(item, count)
	return slots


func _take_container(pocket: int, item: int) -> bool: # FireRed's first TM or berry brings its case or pouch, even when the item itself then finds no slot.
	if pocket == TM_POCKET and not _grant_key_item(TM_CASE):
		return false
	if pocket == BERRY_POCKET:
		if not _grant_key_item(BERRY_POUCH):
			return false
		_events.flag_set(GOT_BERRY_POUCH_FLAG)
	if item == BERRY_POUCH:
		_events.flag_set(GOT_BERRY_POUCH_FLAG)
	return true


func _grant_key_item(item: int) -> bool:
	if has(item, 1):
		return true
	var free: int = _pockets[KEY_POCKET].find(Vector2i.ZERO)
	if free < 0:
		return false
	_pockets[KEY_POCKET][free] = Vector2i(item, 1)
	return true


func remove(item: int, count: int) -> bool:
	var pocket: int = pocket_of(item)
	if pocket == 0 or item == 0:
		return false
	var slots: Array = _pockets[pocket - 1]
	var total: int = 0
	for slot: Vector2i in slots:
		if slot.x == item:
			if _frlg:
				total = slot.y
				break
			total += slot.y
	if total < count or total == 0:
		return false
	for index: int in slots.size():
		var slot: Vector2i = slots[index]
		if slot.x != item:
			continue
		var taken: int = mini(slot.y, count)
		count -= taken
		slots[index] = Vector2i.ZERO if taken == slot.y else Vector2i(item, slot.y - taken)
		if count == 0:
			return true
	return true


func pc_has(item: int, count: int) -> bool:
	for slot: Vector2i in _pc:
		if slot.x == item and slot.y >= count:
			return true
	return false


func pc_add(item: int, count: int) -> bool:
	var slots: Array = _pc.duplicate()
	for index: int in slots.size():
		var slot: Vector2i = slots[index]
		if slot.x != item:
			continue
		if _frlg and slot.y + count > LARGE_STACK:
			return false
		var moved: int = mini(count, LARGE_STACK - slot.y)
		slots[index] = Vector2i(item, slot.y + moved)
		count -= moved
		if count == 0:
			_pc = slots
			return true
	var free: int = slots.find(Vector2i.ZERO)
	if free < 0:
		return false
	slots[free] = Vector2i(item, count)
	_pc = slots
	return true


func add_money(amount: int) -> void:
	money = mini(money + amount, MAX_MONEY)


func remove_money(amount: int) -> void:
	money = maxi(money - amount, 0)


func add_coins(amount: int) -> bool: # Refuses only when already at the cap, as `AddCoins` does; a partial top-up saturates.
	if coins >= MAX_COINS:
		return false
	coins = mini(coins + amount, MAX_COINS)
	return true


func remove_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	return true
