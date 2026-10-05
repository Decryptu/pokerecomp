class_name Gen1SramContext
extends RefCounted

## The image, the cache and the first refusal of one Generation 1 import or
## export. A reader never aborts: the adapter looks once at the end.

var game_id: StringName = &""
var raw: PackedByteArray = PackedByteArray()
var data: GameData = null
var refusal: String = ""
var _dex_of_index: Dictionary = {}


func refuse(message: String) -> void:
	if refusal.is_empty():
		refusal = message


func ok() -> bool:
	return refusal.is_empty()


func u8(at: int) -> int:
	return int(raw[at])


func u16(at: int) -> int:
	return (int(raw[at]) << 8) | int(raw[at + 1])


func u24(at: int) -> int:
	return (int(raw[at]) << 16) | (int(raw[at + 1]) << 8) | int(raw[at + 2])


func put16(at: int, value: int) -> void:
	raw[at] = (value >> 8) & 0xFF
	raw[at + 1] = value & 0xFF


func put24(at: int, value: int) -> void:
	raw[at] = (value >> 16) & 0xFF
	raw[at + 1] = (value >> 8) & 0xFF
	raw[at + 2] = value & 0xFF


func fill(at: int, length: int, value: int) -> void:
	for index: int in length:
		raw[at + index] = value


## A `.sav` names a species by internal index, the cache by Pokedex number.
func dex_of(index: int) -> int:
	if _dex_of_index.is_empty() and data != null:
		for number: int in range(1, data.species_count() + 1):
			var row: int = int(data.species(number).get("index", 0))
			if row > 0:
				_dex_of_index[row] = number
	return int(_dex_of_index.get(index, 0))


func index_of(dex: int) -> int:
	return int(data.species(dex).get("index", 0)) if data != null else 0
