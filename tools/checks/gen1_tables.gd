extends RefCounted

## The Generation 1 species, move, type, item and trainer tables, swept whole on
## Red, Blue and Yellow. Pinned values come from pret's `pokered` and
## `pokeyellow` data files; everything else is an invariant the table has to hold
## across all 151 species, all 165 moves and all 83 items, so a wrong offset that
## still reads plausible bytes is caught by the rows either side of it.

const SPECIES_COUNT: int = 151
const MOVE_COUNT: int = 165
## `NUM_ITEMS`, and the last row the table carries: `GetMachineName` and
## `GetMachinePrice` put HM01 at $C4 and TM50 at $FA, so the cache runs that far
## with the unnamed ids between them empty.
const ITEM_COUNT: int = 83
const ITEM_TABLE_COUNT: int = 250
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
## `MoveEffectPointerTable` translated ([constant Gen1Layout.MOVE_EFFECTS]),
## as effect id to how many of the 165 moves land on it. The whole table stands
## behind this: a row that moves shows up as two counts that disagree.
const EFFECT_CENSUS: Dictionary = {
	0: 31, 1: 5, 2: 3, 3: 3, 4: 4, 5: 3, 6: 6, 7: 2, 8: 1, 9: 1, 10: 2, 11: 3,
	13: 1, 16: 2, 17: 1, 18: 1, 19: 2, 20: 1, 23: 4, 25: 1, 26: 1, 27: 2, 28: 3,
	29: 7, 30: 1, 31: 7, 32: 3, 33: 1, 34: 1, 35: 1, 38: 3, 39: 4, 40: 1, 41: 2,
	42: 4, 44: 2, 45: 2, 46: 1, 47: 1, 48: 4, 49: 2, 50: 1, 51: 2, 52: 1, 53: 1,
	57: 1, 59: 1, 65: 1, 66: 2, 67: 3, 68: 1, 69: 1, 70: 3, 71: 1, 76: 2, 77: 1,
	79: 1, 80: 1, 81: 1, 82: 1, 83: 1, 84: 1, 85: 1, 86: 1, 87: 2, 88: 1, 155: 2,
}

## The seven rows `SpecialDamageEffect`, `PoisonEffect` and `ChargeEffect` split
## by move, and the two the first of them carries its damage in.
const PINNED_EFFECTS: Dictionary = {
	49: [41, 20], 69: [87, 1], 82: [41, 40], 91: [155, 100],
	92: [33, 0], 101: [87, 0], 149: [88, 1],
}

## What `StartMenu_Item`'s three tables come to over the whole 250-row table:
## `KeyItemFlags`' own 31 rows with the five HMs behind `IsItemHM`, the Bicycle
## and `UsableItems_CloseMenu` quitting the menu, and `UsableItems_PartyMenu`
## with all 55 machines opening the party list. The 15 rows `UseItem` refuses
## outside a battle answer in front of all three, four of them X stats that are
## on the party list and never open it. Identical on all three cartridges.
const KEY_ITEM_COUNT: int = 36
const FIELD_MENU_CENSUS: Dictionary = {
	Gen2Layout.ITEMMENU_NOUSE: 15,
	Gen2Layout.ITEMMENU_CLOSE: 7,
	Gen2Layout.ITEMMENU_PARTY: 87,
	Gen2Layout.ITEMMENU_CURRENT: 141,
}
## One row of each shape: the item, its field menu and whether `IsKeyItem` says
## yes. The Town Map and the Poke Ball are both `call UseItem` rows, one of them
## a key item and one not, and `ItemUseBall`'s own `ld a, [wIsInBattle]` is why
## only one of the two does anything on a map.
const PINNED_ITEM_ATTRIBUTES: Dictionary = {
	0x04: [Gen2Layout.ITEMMENU_NOUSE, false],
	0x41: [Gen2Layout.ITEMMENU_NOUSE, false],
	0x05: [Gen2Layout.ITEMMENU_CURRENT, true],
	0x06: [Gen2Layout.ITEMMENU_CLOSE, true],
	0x14: [Gen2Layout.ITEMMENU_PARTY, false],
	0x4E: [Gen2Layout.ITEMMENU_CLOSE, true],
	0xC4: [Gen2Layout.ITEMMENU_PARTY, true],
	0xC9: [Gen2Layout.ITEMMENU_PARTY, false],
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
		var species: int = int(row["target"])
		_r.check(species >= 1 and species <= SPECIES_COUNT,
			"%s evolves into species %d" % [name, species])
		var parameter: int = int(row["parameter"])
		if method == Gen1Layout.EVOLVE_ITEM:
			_r.check(parameter >= 1 and parameter <= ITEM_COUNT,
				"%s evolves with item %d" % [name, parameter])
			_r.check(Gen1Layout.STONE_ITEMS.has(parameter),
				"%s evolves with item %d, which is no stone" % [name, parameter])
		elif method == Gen1Layout.EVOLVE_TRADE:
			_r.check(parameter == Gen2Evolution.TRADE_NO_ITEM,
				"%s trades holding item %d" % [name, parameter])


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
	_move_effects()
	_r.note("%d moves" % MOVE_COUNT)


## Every move's effect byte in the shared numbering: one the battle engine has a
## command list for, and the same census on all three cartridges.
func _move_effects() -> void:
	var census: Dictionary = {}
	for number: int in range(1, MOVE_COUNT + 1):
		var move: Dictionary = _r.data.move(number)
		var effect: int = int(move["effect"])
		census[effect] = int(census.get(effect, 0)) + 1
		var known: bool = effect == Gen2MoveEffect.NORMAL_HIT_EFFECT \
			or Gen2MoveEffect.is_written(effect)
		_r.check(known, "%s reads effect %d, which is unwritten" % [move["name"], effect])
		if PINNED_EFFECTS.has(number):
			var read: Array = [effect, int(move["power"])]
			_r.check(read == PINNED_EFFECTS[number], "move %d reads %s, expected %s" % [
				number, str(read), str(PINNED_EFFECTS[number])
			])
	_r.check(census == EFFECT_CENSUS, "the effect census reads %s" % str(census))


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
	if not _r.check(data.item_count() == ITEM_TABLE_COUNT, "%d items, expected %d" % [
		data.item_count(), ITEM_TABLE_COUNT
	]):
		return
	for number: int in range(1, ITEM_COUNT + 1):
		var item: Dictionary = data.item(number)
		_r.check(not String(item["name"]).is_empty(), "item %d has no name" % number)
		_r.check(int(item["price"]) >= 0, "item %d is priced %d" % [number, item["price"]])
	_r.check(String(data.item(1)["name"]) == "MASTER BALL", "item 1 is not the Master Ball")
	_r.check(int(data.item(4)["price"]) == 200, "a Poke Ball is not 200")
	## `HiddenPrefix` and `TechnicalPrefix` either side of the gap, and
	## `TechnicalMachinePrices`' first and last nybbles.
	_r.check(String(data.item(Gen1Layout.HM_FIRST_ITEM)["name"]) == "HM01",
		"$C4 is not HM01")
	_r.check(int(data.item(Gen1Layout.HM_FIRST_ITEM)["price"]) == 0, "an HM has a price")
	_r.check(String(data.item(Gen1Layout.TM_FIRST_ITEM)["name"]) == "TM01",
		"$C9 is not TM01")
	_r.check(int(data.item(Gen1Layout.TM_FIRST_ITEM)["price"]) == 3000, "TM01 is not 3000")
	_r.check(int(data.item(ITEM_TABLE_COUNT)["price"]) == 2000, "TM50 is not 2000")
	_r.check(String(data.item(Gen1Layout.ITEM_COUNT + 1)["name"]).is_empty(),
		"$54 has a name")
	_item_attributes(data)
	_r.note("%d named items in a table of %d" % [ITEM_COUNT, ITEM_TABLE_COUNT])


## The three tables `StartMenu_Item` reads a row's own behaviour out of, swept
## over the whole table: one bag pocket, nothing registered on SELECT, and a
## field menu that is one of the three the ladder can answer.
func _item_attributes(data: GameData) -> void:
	var keys: int = 0
	var census: Dictionary = {}
	for number: int in range(1, ITEM_TABLE_COUNT + 1):
		var item: Dictionary = data.item(number)
		var menu: int = int(item["field_menu"])
		census[menu] = int(census.get(menu, 0)) + 1
		if not Gen2WorldPack.can_toss(data, number):
			keys += 1
		_r.check(int(item["pocket"]) == Gen1Layout.BAG_POCKET,
			"item %d is in pocket %d" % [number, item["pocket"]])
		_r.check(not Gen2WorldPack.can_select(data, number),
			"item %d can be registered" % number)
	_r.check(keys == KEY_ITEM_COUNT, "%d key items, expected %d" % [keys, KEY_ITEM_COUNT])
	_r.check(census == FIELD_MENU_CENSUS, "field menus read %s" % str(census))
	for number: int in PINNED_ITEM_ATTRIBUTES:
		var pinned: Array = PINNED_ITEM_ATTRIBUTES[number]
		_r.check(int(data.item(number)["field_menu"]) == int(pinned[0]),
			"item %d has field menu %d" % [number, data.item(number)["field_menu"]])
		_r.check(Gen2WorldPack.can_toss(data, number) != bool(pinned[1]),
			"item %d is tossable %s" % [number, not bool(pinned[1])])
	_r.check(Gen2WorldPack.pocket_order(data).size() == 1,
		"the Generation 1 bag cycles through %d pockets" % Gen2WorldPack.pocket_order(data).size())


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
	## `GetMachineName` counts the HMs above the TMs and the item run puts them
	## below, so every machine must reach its own row through the seam and
	## nothing else may reach one at all.
	var reached: Dictionary = {}
	for number: int in range(1, ITEM_TABLE_COUNT + 1):
		var row: int = Gen2WorldTMHM.number_for_item(_r.data, number)
		var machine: bool = number >= Gen1Layout.HM_FIRST_ITEM
		_r.check(machine == (row > 0), "item %d answers machine row %d" % [number, row])
		if row > 0:
			_r.check(not reached.has(row), "two items answer machine row %d" % row)
			reached[row] = true
	_r.check(reached.size() == TMHM_COUNT,
		"%d of %d machines are reached" % [reached.size(), TMHM_COUNT])
	_r.check(Gen2WorldTMHM.is_hm(Gen1Layout.HM_FIRST_ITEM, RomRegistry.GEN1)
		and not Gen2WorldTMHM.is_hm(Gen1Layout.TM_FIRST_ITEM, RomRegistry.GEN1),
		"the HM run does not end at TM01")


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
