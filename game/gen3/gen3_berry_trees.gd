class_name Gen3BerryTrees
extends RefCounted

## `berry.c`: six-byte save records; Ruby's growthSparkle bit is Emerald's stopGrowth bit. The field host
## supplies elapsed minutes and a shared RNG.
const COUNT: int = 128
const RECORD_SIZE: int = 6
enum Stage { EMPTY, PLANTED, SPROUTED, TALLER, FLOWERING, BERRIES }

var data: GameData
var random_seed: int = 0
var random_word: Callable = _random
var _records := PackedByteArray()


func _init(game_data: GameData) -> void:
	data = game_data
	_records.resize(COUNT * RECORD_SIZE)


func record(id: int) -> Dictionary:
	if id < 0 or id >= COUNT:
		return {}
	var at: int = id * RECORD_SIZE
	return {"berry": int(_records[at]), "stage": int(_records[at + 1] & 0x7F),
		"stop_growth": bool(_records[at + 1] & 0x80), "minutes": _records.decode_u16(at + 2),
		"yield": int(_records[at + 4]), "regrowth": int(_records[at + 5] & 15),
		"watered": int(_records[at + 5] >> 4)}


func plant(id: int, berry: int, stage: int, growth_enabled: bool = true) -> void:
	if id < 0 or id >= COUNT or stage < Stage.EMPTY or stage > Stage.BERRIES:
		return
	remove(id)
	var at: int = id * RECORD_SIZE
	_records[at] = berry & 0xFF
	_records[at + 1] = stage | (0 if growth_enabled else 0x80)
	var minutes: int = int(_info(berry & 0xFF).get("stage_minutes", 0))
	if stage == Stage.BERRIES:
		_records[at + 4] = _yield(id)
		minutes *= 4
	_records.encode_u16(at + 2, minutes)


func remove(id: int) -> void:
	if id >= 0 and id < COUNT:
		for index: int in RECORD_SIZE:
			_records[id * RECORD_SIZE + index] = 0


func allow_growth(id: int) -> void:
	if id >= 0 and id < COUNT:
		_records[id * RECORD_SIZE + 1] &= 0x7F


func water(id: int) -> bool:
	var tree: Dictionary = record(id)
	var stage: int = int(tree.get("stage", 0))
	if stage < Stage.PLANTED or stage > Stage.FLOWERING:
		return false
	_records[id * RECORD_SIZE + 5] |= 1 << (stage + 3)
	return true


func advance_minutes(minutes: int) -> void:
	if data.id in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN]:
		return
	for id: int in COUNT:
		var tree: Dictionary = record(id)
		if int(tree["berry"]) == 0 or int(tree["stage"]) == 0 or bool(tree["stop_growth"]):
			continue
		var duration: int = int(_info(int(tree["berry"])).get("stage_minutes", 0))
		if duration == 0 or minutes >= duration * 71:
			remove(id)
		else:
			_advance(id, minutes)


func _advance(id: int, minutes: int) -> void:
	var at: int = id * RECORD_SIZE
	while minutes != 0:
		var remaining: int = _records.decode_u16(at + 2)
		if remaining > minutes:
			_records.encode_u16(at + 2, (remaining - minutes) & 0xFFFF)
			return
		minutes -= remaining
		var duration: int = int(_info(int(_records[at])).get("stage_minutes", 0))
		_records.encode_u16(at + 2, duration)
		if not _grow(id):
			return
		if int(_records[at + 1]) == Stage.BERRIES:
			_records.encode_u16(at + 2, duration * 4)


func _grow(id: int) -> bool:
	var at: int = id * RECORD_SIZE
	match int(_records[at + 1]):
		Stage.EMPTY:
			return false
		Stage.FLOWERING:
			_records[at + 4] = _yield(id)
			_records[at + 1] += 1
		Stage.PLANTED, Stage.SPROUTED, Stage.TALLER:
			_records[at + 1] += 1
		Stage.BERRIES:
			_records[at + 4] = 0
			_records[at + 5] = (_records[at + 5] + 1) & 15
			_records[at + 1] = Stage.SPROUTED
			if _records[at + 5] == 10:
				remove(id)
	return true


func _info(berry: int) -> Dictionary:
	return data.world_berry(berry if berry >= 1 and berry <= 43 else 1)


func _yield(id: int) -> int:
	var tree: Dictionary = record(id)
	var info: Dictionary = _info(int(tree["berry"]))
	var minimum: int = int(info.get("min_yield", 0))
	var water_count: int = 0
	for stage: int in 4:
		water_count += (int(tree["watered"]) >> stage) & 1
	if water_count == 0:
		return minimum
	var difference: int = int(info.get("max_yield", 0)) - minimum
	var roll: int = difference * (water_count - 1) + int(random_word.call()) % (difference + 1)
	return minimum + roll / 4 + int(roll % 4 >= 2)


func _random() -> int:
	random_seed = (random_seed * 0x41C64E6D + 0x6073) & 0xFFFFFFFF
	return random_seed >> 16
