extends RefCounted

## The Generation 1 species, move, type, item and trainer tables, swept whole on
## Red, Blue and Yellow. Pinned values come from pret's `pokered` and
## `pokeyellow` data files; everything else is an invariant the table has to hold
## across all 151 species, all 165 moves and all 83 items, so a wrong offset that
## still reads plausible bytes is caught by the rows either side of it.

const SPECIES_COUNT: int = 151
const MOVE_COUNT: int = 165
const ITEM_COUNT: int = 83
const TYPE_COUNT: int = 16
const TRAINER_COUNT: int = 47
const MATCHUP_COUNT: int = 82
const TMHM_COUNT: int = 55
const EVOLUTION_COUNT: int = 72
## `data/pokemon/evos_moves.asm`: Yellow gave Pikachu and its line more to learn.
const LEARNSET_MOVES: Dictionary = {&"red": 728, &"blue": 728, &"yellow": 755}

## The only two `BaseStats` fields Yellow changed: `data/pokemon/base_stats/`
## drops Dragonair's catch rate from 45 to 27 and Dragonite's from 45 to 9.
## Everything else in that table is the same on all three cartridges.
const YELLOW_CATCH_RATES: Dictionary = {148: 27, 149: 9}

## Whole rows of `BaseStats`, by dex number: name, hp, attack, defense, speed,
## special, both types, catch rate and base experience.
const PINNED_SPECIES: Dictionary = {
	1: ["BULBASAUR", 45, 49, 49, 45, 65, 0x16, 0x03, 45, 64],
	6: ["CHARIZARD", 78, 84, 78, 100, 85, 0x14, 0x02, 45, 209],
	25: ["PIKACHU", 35, 55, 30, 90, 50, 0x17, 0x17, 190, 82],
	151: ["MEW", 100, 100, 100, 100, 100, 0x18, 0x18, 45, 64],
}

## `data/moves/moves.asm`, first and last: effect, power, type, accuracy, pp.
const PINNED_MOVES: Dictionary = {
	1: ["POUND", 0, 40, 0x00, 255, 35],
	165: ["STRUGGLE", 48, 50, 0x00, 255, 10],
}

## `TechnicalMachines`: TM01 through TM05, then the five HMs.
const PINNED_TMS: Array[int] = [5, 13, 14, 18, 25]
const PINNED_HMS: Array[int] = [15, 19, 57, 70, 148]

## `constants/type_constants.asm`: the physical run, the hole nothing uses, and
## the special run that starts at FIRE.
const TYPE_UNUSED_FIRST: int = 0x09
const TYPE_UNUSED_LAST: int = 0x13
const TYPE_SPECIAL_FIRST: int = 0x14
const TYPE_DRAGON: int = 0x1A

## `SUPER_EFFECTIVE`, `NOT_VERY_EFFECTIVE` and `NO_EFFECT`. A neutral row would
## say nothing, so 10 must never appear.
const MULTIPLIERS: Array[int] = [0, 5, 20]

const MAX_LEVEL: int = 100

var _r: RefCounted = null


func run(r: RefCounted) -> void:
	_r = r
	r.each_game_of(RomRegistry.GEN1, _one_game)
	_compare_cartridges()


func _one_game() -> void:
	_species()
	_moves()
	_types()
	_items()
	_tmhm()
	_trainers()


func _species() -> void:
	var data: GameData = _r.data
	if not _r.check(data.species_count() == SPECIES_COUNT, "%d species, expected %d" % [
		data.species_count(), SPECIES_COUNT
	]):
		return
	var evolutions: int = 0
	var learnset_moves: int = 0
	for dex: int in range(1, SPECIES_COUNT + 1):
		var entry: Dictionary = data.species(dex)
		evolutions += (entry["evolutions"] as Array).size()
		learnset_moves += (entry["learnset"] as Array).size()
		_one_species(dex, entry)
	_r.check(evolutions == EVOLUTION_COUNT, "%d evolutions, expected %d" % [
		evolutions, EVOLUTION_COUNT
	])
	var expected: int = int(LEARNSET_MOVES[_r.game_id])
	_r.check(learnset_moves == expected, "%d level-up moves, expected %d" % [
		learnset_moves, expected
	])
	_r.note("%d species, %d evolutions, %d level-up moves" % [
		SPECIES_COUNT, evolutions, learnset_moves
	])


func _one_species(dex: int, entry: Dictionary) -> void:
	var stats: Dictionary = entry["stats"]
	var name: String = String(entry["name"])
	_r.check(not name.is_empty(), "species %d has no name" % dex)
	_r.check(int(entry["index"]) >= 1 and int(entry["index"]) <= 190,
		"species %d sits in slot %d" % [dex, entry["index"]])
	for key: String in ["hp", "attack", "defense", "speed", "special"]:
		_r.check(int(stats[key]) > 0, "%s has no %s" % [name, key])
	for type: int in entry["types"] as Array:
		_r.check(_is_real_type(int(type)), "%s carries type $%02X" % [name, type])
	_r.check(int(entry["catch_rate"]) > 0, "%s has no catch rate" % name)
	_r.check(int(entry["base_exp"]) > 0, "%s has no base experience" % name)
	_r.check(int(entry["pic_offsets"]["front"]) > 0 and int(entry["pic_offsets"]["back"]) > 0,
		"%s has an unreachable pic" % name)
	_dex_entry(name, entry["dex"])
	_learnset(name, entry["learnset"])
	_evolutions(name, entry["evolutions"])
	if PINNED_SPECIES.has(dex):
		_pinned_species(dex, entry, stats)


func _pinned_species(dex: int, entry: Dictionary, stats: Dictionary) -> void:
	var want: Array = PINNED_SPECIES[dex]
	var read: Array = [
		String(entry["name"]),
		int(stats["hp"]), int(stats["attack"]), int(stats["defense"]),
		int(stats["speed"]), int(stats["special"]),
		int((entry["types"] as Array)[0]), int((entry["types"] as Array)[1]),
		int(entry["catch_rate"]), int(entry["base_exp"]),
	]
	_r.check(read == want, "species %d reads %s, expected %s" % [dex, str(read), str(want)])


func _dex_entry(name: String, dex: Dictionary) -> void:
	_r.check(not String(dex["category"]).is_empty(), "%s has no Pokedex category" % name)
	_r.check(int(dex["height"]) > 0, "%s has no height" % name)
	_r.check(int(dex["weight"]) > 0, "%s has no weight" % name)
	var pages: Array = dex["pages"]
	_r.check(pages.size() == 1 and not String(pages[0]).is_empty(),
		"%s has no Pokedex description" % name)
	# `text_far` is the only way out of an entry, so an undecoded byte left in
	# the text is a pointer that landed somewhere it should not have.
	_r.check(not String(pages[0]).contains("<"), "%s's description holds a raw byte" % name)


func _learnset(name: String, learnset: Array) -> void:
	for row: Dictionary in learnset:
		var level: int = int(row["level"])
		var move: int = int(row["move"])
		_r.check(level >= 1 and level <= MAX_LEVEL, "%s learns at level %d" % [name, level])
		_r.check(move >= 1 and move <= MOVE_COUNT, "%s learns move %d" % [name, move])


func _evolutions(name: String, evolutions: Array) -> void:
	for row: Dictionary in evolutions:
		var method: int = int(row["method"])
		_r.check(Gen1Layout.EVOLVE_SIZES.has(method), "%s evolves by method %d" % [name, method])
		var species: int = int(row["species"])
		_r.check(species >= 1 and species <= SPECIES_COUNT,
			"%s evolves into species %d" % [name, species])
		if method == Gen1Layout.EVOLVE_ITEM:
			var item: int = int(row["item"])
			_r.check(item >= 1 and item <= ITEM_COUNT, "%s evolves with item %d" % [name, item])


func _moves() -> void:
	var data: GameData = _r.data
	if not _r.check(data.move_count() == MOVE_COUNT, "%d moves, expected %d" % [
		data.move_count(), MOVE_COUNT
	]):
		return
	for number: int in range(1, MOVE_COUNT + 1):
		var move: Dictionary = data.move(number)
		var name: String = String(move["name"])
		_r.check(not name.is_empty(), "move %d has no name" % number)
		_r.check(_is_real_type(int(move["type"])), "%s is type $%02X" % [name, move["type"]])
		_r.check(int(move["pp"]) >= 1 and int(move["pp"]) <= 40, "%s has %d PP" % [
			name, move["pp"]
		])
		if PINNED_MOVES.has(number):
			var want: Array = PINNED_MOVES[number]
			var read: Array = [
				name, int(move["effect"]), int(move["power"]), int(move["type"]),
				int(move["accuracy"]), int(move["pp"]),
			]
			_r.check(read == want, "move %d reads %s, expected %s" % [
				number, str(read), str(want)
			])
	_r.note("%d moves" % MOVE_COUNT)


func _types() -> void:
	var data: GameData = _r.data
	_r.check(data.type_count() == TYPE_COUNT, "%d types, expected %d" % [
		data.type_count(), TYPE_COUNT
	])
	var matchups: int = 0
	for attacker: int in Gen1Layout.TYPE_COUNT:
		for defender: int in Gen1Layout.TYPE_COUNT:
			var multiplier: int = data.type_matchup(attacker, defender)
			if multiplier == Gen1Layout.TYPE_EFFECT_NEUTRAL:
				continue
			matchups += 1
			_r.check(MULTIPLIERS.has(multiplier), "$%02X on $%02X is x%d" % [
				attacker, defender, multiplier
			])
			_r.check(_is_real_type(attacker) and _is_real_type(defender),
				"a matchup names the unused type run")
	_r.check(matchups == MATCHUP_COUNT, "%d matchups, expected %d" % [matchups, MATCHUP_COUNT])
	_r.note("%d types, %d matchups" % [TYPE_COUNT, matchups])


func _items() -> void:
	var data: GameData = _r.data
	if not _r.check(data.item_count() == ITEM_COUNT, "%d items, expected %d" % [
		data.item_count(), ITEM_COUNT
	]):
		return
	for number: int in range(1, ITEM_COUNT + 1):
		var item: Dictionary = data.item(number)
		_r.check(not String(item["name"]).is_empty(), "item %d has no name" % number)
		_r.check(int(item["price"]) >= 0, "item %d is priced %d" % [number, item["price"]])
	_r.check(String(data.item(1)["name"]) == "MASTER BALL", "item 1 is not the Master Ball")
	_r.check(int(data.item(4)["price"]) == 200, "a Poke Ball is not 200")
	_r.note("%d items" % ITEM_COUNT)


func _tmhm() -> void:
	var moves: Array[int] = _r.data.tmhm_moves()
	if not _r.check(moves.size() == TMHM_COUNT, "%d TM/HM rows, expected %d" % [
		moves.size(), TMHM_COUNT
	]):
		return
	var seen: Dictionary = {}
	for move: int in moves:
		_r.check(move >= 1 and move <= MOVE_COUNT, "a TM teaches move %d" % move)
		_r.check(not seen.has(move), "move %d is on two machines" % move)
		seen[move] = true
	_r.check(moves.slice(0, PINNED_TMS.size()) == PINNED_TMS, "TM01 to TM05 read %s" % str(
		moves.slice(0, PINNED_TMS.size())
	))
	_r.check(moves.slice(Gen1Layout.TM_COUNT) == PINNED_HMS, "the HMs read %s" % str(
		moves.slice(Gen1Layout.TM_COUNT)
	))


func _trainers() -> void:
	var data: GameData = _r.data
	_r.check(data.trainer_count() == TRAINER_COUNT, "%d trainer classes, expected %d" % [
		data.trainer_count(), TRAINER_COUNT
	])
	for number: int in range(1, TRAINER_COUNT + 1):
		_r.check(not String(data.trainer(number)["name"]).is_empty(),
			"trainer class %d has no name" % number)


## Red and Blue are one source built twice, so every table swept here is
## identical between them and a difference means a layout has drifted. Yellow
## shares the whole table but the two catch rates and what the mons learn, which
## is what makes it worth diffing rather than only spot-checking.
func _compare_cartridges() -> void:
	var red: GameData = GameData.open(RomRegistry.RED)
	var blue: GameData = GameData.open(RomRegistry.BLUE)
	var yellow: GameData = GameData.open(RomRegistry.YELLOW)
	if red == null or blue == null or yellow == null:
		return
	var differences: int = 0
	var learnsets: int = 0
	for dex: int in range(1, SPECIES_COUNT + 1):
		if _stats_of(red, dex) != _stats_of(blue, dex):
			differences += 1
			_r.fail("species %d differs between Red and Blue" % dex)
		# The override goes on Red's side: it is Red's row rewritten to what
		# Yellow is known to have changed, so an unrecorded change still fails.
		if _stats_of(red, dex, YELLOW_CATCH_RATES) != _stats_of(yellow, dex):
			differences += 1
			_r.fail("species %d differs between Red and Yellow" % dex)
		if red.species(dex)["learnset"] != yellow.species(dex)["learnset"]:
			learnsets += 1
	for dex: int in YELLOW_CATCH_RATES:
		_r.check(int(yellow.species(dex)["catch_rate"]) == int(YELLOW_CATCH_RATES[dex]),
			"Yellow's species %d has catch rate %d" % [dex, yellow.species(dex)["catch_rate"]])
	_r.check(learnsets > 0, "Yellow's learnsets are identical to Red's")
	_r.note("%d species rows differ across the three cartridges; %d learnsets differ in Yellow"
		% [differences, learnsets])


## One species row in the shape the three cartridges are compared in.
## [param catch_rates] carries the rows a cartridge is known to have changed, so
## a real difference still fails and a recorded one does not.
static func _stats_of(data: GameData, dex: int, catch_rates: Dictionary = {}) -> Array:
	var entry: Dictionary = data.species(dex)
	var catch_rate: int = int(catch_rates.get(dex, entry["catch_rate"]))
	return [entry["name"], entry["stats"], entry["types"], catch_rate,
		entry["base_exp"], entry["growth_rate"]]


static func _is_real_type(type: int) -> bool:
	if type > TYPE_DRAGON:
		return false
	return type < TYPE_UNUSED_FIRST or type > TYPE_UNUSED_LAST
