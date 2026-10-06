extends RefCounted

## Generation 3's species, move, type, item, ability and Pokedex tables. Pins
## come from pret's data files; the sweeps catch a stride that reads plausibly.

const SPECIES_COUNT: int = 386
const MOVE_COUNT: int = 354
const MATCHUP_COUNT: int = 110
const FORESIGHT_MATCHUPS: int = 2
const HOENN_DEX_COUNT: int = 202
const EVOLUTION_COUNT: int = 184
const NO_FLIP_COUNT: int = 18
## FireRed and LeafGreen each carry their own `sDeoxysLevelUpLearnset`.
const LEARNSET_MOVES: Dictionary = {
	&"ruby": 3947, &"sapphire": 3947, &"firered": 4011, &"leafgreen": 4013, &"emerald": 3947,
}

const PINNED_SPECIES: Dictionary = {
	1: ["BULBASAUR", 1, 203, [45, 49, 49, 45, 65, 65], [12, 3], 45, 64, [0, 0], 31, 20, 3,
		[1, 7], [65, 0]],
	113: ["CHANSEY", 113, 277, [250, 5, 5, 50, 35, 105], [0, 0], 30, 255, [0, 197], 254, 40, 4,
		[6, 6], [30, 32]],
	252: ["TREECKO", 277, 1, [40, 45, 35, 70, 65, 55], [12, 12], 45, 65, [0, 0], 31, 20, 3,
		[1, 14], [65, 0]],
	292: ["SHEDINJA", 303, 44, [1, 90, 45, 40, 30, 30], [6, 7], 45, 95, [0, 0], 255, 15, 1,
		[10, 10], [25, 0]],
}
const WURMPLE: int = 265
const WURMPLE_EVOLUTIONS: Array = [[11, 7, 266], [12, 7, 268]]
const PINNED_MOVES: Dictionary = {
	98: ["QUICK ATTACK", 40, 0, 100, 30, 1],
	182: ["PROTECT", 0, 0, 0, 10, 3],
	264: ["FOCUS PUNCH", 150, 1, 100, 20, -3],
	354: ["PSYCHO BOOST", 140, 14, 90, 5, 0],
}
## Rows whose `itemId` is set: `ITEMS_COUNT` less the 68 `ITEM_NONE` rows.
const NAMED_ITEMS: Dictionary = {
	&"ruby": 281, &"sapphire": 281, &"firered": 307, &"leafgreen": 307, &"emerald": 309,
}
const LEFTOVERS: int = 200
const LEFTOVERS_PIN: Array = ["LEFTOVERS", 200, 43, 10, 1]
## FireRed and LeafGreen's POCKET_KEY_ITEMS is 2; the other three's is 5.
const MACH_BIKE: int = 259
const KEY_ITEMS_POCKET: Dictionary = {
	&"ruby": 5, &"sapphire": 5, &"firered": 2, &"leafgreen": 2, &"emerald": 5,
}
const LEVITATE: Array = [26, "LEVITATE", "Not hit by GROUND attacks."]
const PIKACHU_DEX: Array = ["MOUSE", 4, 60]
const BULBASAUR_SCALES: Dictionary = {
	&"ruby": [356, 17, 256, 0], &"sapphire": [356, 17, 256, 0],
	&"firered": [356, 16, 256, -2], &"leafgreen": [356, 16, 256, -2],
	&"emerald": [356, 17, 256, 0],
}
const DEX_PAGES: Dictionary = {
	&"ruby": 2, &"sapphire": 2, &"firered": 1, &"leafgreen": 1, &"emerald": 1,
}
const TYPE_NAMES: Array = [
	"NORMAL", "FIGHT", "FLYING", "POISON", "GROUND", "ROCK", "BUG", "GHOST", "STEEL",
	"???", "FIRE", "WATER", "GRASS", "ELECTR", "PSYCHC", "ICE", "DRAGON", "DARK",
]

var _r: RefCounted


func run(r: RefCounted) -> void:
	_r = r
	r.each_game_of(RomRegistry.GEN3, _one_game)


func _one_game() -> void:
	_species()
	_moves()
	_types()
	_items()
	_abilities()
	_dex_entries()
	_undecoded_text()


func _species() -> void:
	var data: GameData = _r.data
	if not _r.check(data.species_count() == SPECIES_COUNT,
		"%d species, not %d." % [data.species_count(), SPECIES_COUNT]):
		return
	var hoenn: Dictionary = {}
	var evolutions: int = 0
	var learnset_moves: int = 0
	var no_flip: int = 0
	for number: int in range(1, SPECIES_COUNT + 1):
		var entry: Dictionary = data.species(number)
		_r.check(int(entry["number"]) == number, "record %d is numbered %s." % [
			number, entry["number"],
		])
		var index: int = int(entry["index"])
		_r.check(index < 252 or index > 276, "%s is an unused Unown slot." % entry["name"])
		if int(entry["hoenn_number"]) <= HOENN_DEX_COUNT:
			hoenn[int(entry["hoenn_number"])] = true
		evolutions += data.evolutions(number).size()
		learnset_moves += data.learnset(number).size()
		no_flip += 1 if bool(entry["no_flip"]) else 0
	_r.check(hoenn.size() == HOENN_DEX_COUNT, "the Hoenn dex numbers %d species." % hoenn.size())
	_r.check(evolutions == EVOLUTION_COUNT, "%d evolutions." % evolutions)
	_r.check(learnset_moves == int(LEARNSET_MOVES[data.id]),
		"%d level-up moves." % learnset_moves)
	_r.check(no_flip == NO_FLIP_COUNT, "%d species are never flipped." % no_flip)
	for number: int in PINNED_SPECIES:
		_pinned_species(data, number, PINNED_SPECIES[number])
	var wurmple: Array = data.evolutions(WURMPLE).map(func(row: Dictionary) -> Array:
		return _ints([row["method"], row["parameter"], row["target"]]))
	_r.check(wurmple == WURMPLE_EVOLUTIONS, "Wurmple evolves by %s." % str(wurmple))


func _pinned_species(data: GameData, number: int, pin: Array) -> void:
	var entry: Dictionary = data.species(number)
	var stats: Dictionary = entry["stats"]
	var read: Array = [
		entry["name"], entry["index"], entry["hoenn_number"],
		[stats["hp"], stats["attack"], stats["defense"], stats["speed"],
			stats["sp_attack"], stats["sp_defense"]],
		entry["types"], entry["catch_rate"], entry["base_exp"], entry["items"],
		entry["gender_ratio"], entry["egg_cycles"], entry["growth_rate"],
		entry["egg_groups"], entry["abilities"],
	]
	_r.check(_ints(read) == pin, "species %d reads %s." % [number, str(read)])


static func _ints(value: Variant) -> Variant:
	if value is float:
		return int(value)
	if value is Array:
		return (value as Array).map(_ints)
	return value


func _moves() -> void:
	var data: GameData = _r.data
	if not _r.check(data.move_count() == MOVE_COUNT,
		"%d moves, not %d." % [data.move_count(), MOVE_COUNT]):
		return
	for number: int in PINNED_MOVES:
		var move: Dictionary = data.move(number)
		var read: Array = [
			move["name"], move["power"], move["type"], move["accuracy"], move["pp"],
			move["priority"],
		]
		_r.check(_ints(read) == PINNED_MOVES[number], "move %d reads %s." % [
			number, str(read),
		])


func _types() -> void:
	var data: GameData = _r.data
	var names: Array = []
	for type: int in TYPE_NAMES.size():
		names.append(data.type_name(type))
	_r.check(names == TYPE_NAMES, "gTypeNames reads %s." % str(names))
	var rows: Array = RomCache.read_json(RomCache.matchups_path(data.directory))
	_r.check(rows.size() == MATCHUP_COUNT, "%d matchups." % rows.size())
	var foresight: Array = rows.filter(func(row: Dictionary) -> bool:
		return bool(row["negated_by_foresight"]))
	_r.check(foresight.size() == FORESIGHT_MATCHUPS
		and foresight.all(func(row: Dictionary) -> bool: return int(row["defender"]) == 7),
		"Foresight lifts %s." % str(foresight))
	_r.check(data.type_matchup(10, 12) == 20 and data.type_matchup(0, 7) == 0
		and data.type_matchup(0, 7, true) == 10,
		"FIRE on GRASS is %d, NORMAL on GHOST %d and %d under Foresight." % [
			data.type_matchup(10, 12), data.type_matchup(0, 7), data.type_matchup(0, 7, true),
		])


func _items() -> void:
	var data: GameData = _r.data
	var named: int = 0
	for number: int in range(1, data.item_count() + 1):
		named += 0 if bool(data.item(number)["unused"]) else 1
	_r.check(named == int(NAMED_ITEMS[data.id]), "%d named items." % named)
	var leftovers: Dictionary = data.item(LEFTOVERS)
	var read: Array = _ints([
		leftovers["name"], leftovers["price"], leftovers["hold_effect"],
		leftovers["hold_effect_parameter"], leftovers["pocket"],
	])
	_r.check(read == LEFTOVERS_PIN, "item %d reads %s." % [LEFTOVERS, str(read)])
	var pocket: int = int(data.item(MACH_BIKE)["pocket"])
	_r.check(pocket == int(KEY_ITEMS_POCKET[data.id]), "MACH BIKE is in pocket %d." % pocket)


func _abilities() -> void:
	var data: GameData = _r.data
	var levitate: Dictionary = data.ability(int(LEVITATE[0]))
	var read: Array = [int(levitate["number"]), levitate["name"], levitate["description"]]
	_r.check(read == LEVITATE, "ability %d reads %s." % [LEVITATE[0], str(read)])
	_r.check(data.ability_count() == Gen3Layout.ABILITY_COUNT,
		"%d abilities." % data.ability_count())


func _dex_entries() -> void:
	var data: GameData = _r.data
	var pikachu: Dictionary = data.dex_entry(25)
	var read: Array = [pikachu["category"], pikachu["height"], pikachu["weight"]]
	_r.check(read == PIKACHU_DEX, "Pikachu's dex entry reads %s." % str(read))
	var dex: Dictionary = data.species(1)["dex"]
	var scales: Array = _ints([
		dex["pokemon_scale"], dex["pokemon_offset"], dex["trainer_scale"], dex["trainer_offset"],
	])
	_r.check(scales == BULBASAUR_SCALES[data.id], "Bulbasaur's scales read %s." % str(scales))
	for number: int in range(1, SPECIES_COUNT + 1):
		var pages: int = data.dex_entry(number)["pages"].size()
		if not _r.check(pages == int(DEX_PAGES[data.id]), "species %d has %d pages." % [
			number, pages,
		]):
			return


## A code [Gen3Text] has no glyph for decodes as `<$nn>`.
func _undecoded_text() -> void:
	var data: GameData = _r.data
	var texts: Array = []
	for number: int in range(1, data.item_count() + 1):
		texts.append_array([data.item(number)["name"], data.item(number)["description"]])
	for ability: int in data.ability_count():
		texts.append_array([data.ability(ability)["name"], data.ability(ability)["description"]])
	for number: int in range(1, SPECIES_COUNT + 1):
		texts.append(data.species(number)["name"])
		texts.append(data.dex_entry(number)["category"])
		texts.append_array(data.dex_entry(number)["pages"])
	for move: int in range(1, MOVE_COUNT + 1):
		texts.append(data.move(move)["name"])
	var undecoded: Array = texts.filter(func(text: String) -> bool: return text.contains("<$"))
	_r.check(undecoded.is_empty(), "%d texts hold codes with no glyph, first %s." % [
		undecoded.size(), str(undecoded.slice(0, 1)),
	])
