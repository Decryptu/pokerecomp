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
const LEARNABLE_PAIRS: Dictionary = {&"red": 3037, &"blue": 3037, &"yellow": 3043}
const CHARMANDER_DEX: int = 4
const CUT_MOVE: int = 15
const TMHM_COUNT: int = 55
const EVOLUTION_COUNT: int = 72
## `page` in every `PokedexEntry` description, which `PageChar` waits on.
const DEX_PAGES: int = 2
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

const INTRO_BEAT_KEYS: Array = [
	"oak_speech_1", "oak_speech_2", "introduce_player", "your_name_is",
	"introduce_rival", "his_name_is", "oak_speech_3",
]
const OAK_SPEECH_1_OPENS: String = "Hello there!"
const INTRO_MARKERS: Array = [
	["oak_speech_3", "<PLAYER>"], ["your_name_is", "<PLAYER>"],
	["his_name_is", "<RIVAL>"],
]

const INTRO_NAMES: Dictionary = {
	&"red": {
		"player": ["NEW NAME", "RED", "ASH", "JACK"],
		"rival": ["NEW NAME", "BLUE", "GARY", "JOHN"],
	},
	&"blue": {
		"player": ["NEW NAME", "BLUE", "GARY", "JOHN"],
		"rival": ["NEW NAME", "RED", "ASH", "JACK"],
	},
	&"yellow": {
		"player": ["NEW NAME", "YELLOW", "ASH", "JACK"],
		"rival": ["NEW NAME", "BLUE", "GARY", "JOHN"],
	},
}
const INTRO_SPECIES: Dictionary = {
	&"red": [33, 30], &"blue": [33, 30], &"yellow": [25, 25],
}
const NEW_GAME_WARP: Dictionary = {"map": 38, "x": 3, "y": 6, "tileset": 4}
## `_DexSeenOwnedText` with 12 and 3 in its slots, `_DexRatingText` whose
## `<COLON>` is one tile, and `AnimateHallOfFame`'s six pages per member.
const HOF_SEEN_OWNED: String = "POKéDEX   Seen: 12\n         Owned:  3"
const HOF_RATING: String = "POKéDEX Rating<COLON>"
const HOF_RATING_TILES: int = 15
const HOF_PAGES_PER_MON: int = 6
const HOF_FADE_PAGES: int = 3
const HOF_TEAM_CAPACITY: int = 50

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

## `TradeMons` whole, as dex numbers: the give and get species, the
## `TRADE_DIALOGSET_*` and the nickname of every `npctrade` row, unused rows
## included. Transcribed from `data/events/trades.asm`.
const TRADES: Dictionary = {
	&"red": [
		[33, 30, 0, "TERRY"], [63, 122, 0, "MARCEL"], [12, 15, 2, "CHIKUCHIKU"],
		[77, 86, 0, "SAILOR"], [21, 83, 2, "DUX"], [80, 108, 0, "MARC"],
		[61, 124, 1, "LOLA"], [26, 101, 1, "DORIS"], [48, 114, 2, "CRINKLES"],
		[32, 29, 2, "SPOT"],
	],
	&"yellow": [
		[108, 51, 0, "GURIO"], [35, 122, 0, "MILES"], [12, 15, 2, "STINGER"],
		[115, 89, 0, "STICKY"], [151, 151, 2, "BART"], [114, 47, 0, "SPIKE"],
		[18, 18, 1, "MARTY"], [55, 112, 1, "BUFFY"], [58, 87, 2, "CEZANNE"],
		[104, 67, 2, "RICKY"],
	],
}
## `InGameTrade_TrainerString`, the one OT name every row shares, and the two
## values `DoInGameTradeDialogue` rolls rather than storing.
const TRADE_OT_NAME: String = "TRAINER"
const TRADE_ROLLED: int = -1

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
	_trades()
	_intro()
	_hall_of_fame()


func _intro() -> void:
	var data: GameData = _r.data
	var beats: Array = Gen2OakSpeech.beats(data)
	var keys: Array = []
	for beat: Dictionary in beats:
		keys.append(String(beat["key"]))
		_r.check(not String(beat["text"]).is_empty(), "%s is empty." % beat["key"])
	_r.check(keys == INTRO_BEAT_KEYS, "the intro beats read %s." % [keys])
	_r.check(data.intro_text("oak_speech_1").begins_with(OAK_SPEECH_1_OPENS),
		"OakSpeechText1 opens %s." % data.intro_text("oak_speech_1").left(20))
	for pair: Array in INTRO_MARKERS:
		_r.check(data.intro_text(String(pair[0])).contains(String(pair[1])),
			"%s carries no %s." % pair)

	var names: Dictionary = INTRO_NAMES[_r.game_id]
	for role: String in names:
		_r.check(data.gen1_default_names(role == "rival") == names[role],
			"the %s names read %s." % [role, data.gen1_default_names(role == "rival")])
	_intro_keyboards()
	_r.check(data.player_frontpic(Gen2OakSpeech.GEN1_SHRINK_SLOTS[1]).size() > 0
		and data.tile_indices("intro_ed").size() == PokeTiles.TILE_WIDTH * PokeTiles.TILE_HEIGHT,
		"the shrink pics or the ED tile are missing.")
	_r.check(Gen2OakSpeech.intro_species(data) == int(INTRO_SPECIES[_r.game_id][0])
		and Gen2OakSpeech.intro_cry(data) == int(INTRO_SPECIES[_r.game_id][1]),
		"the speech draws %d and cries %d." % [
			Gen2OakSpeech.intro_species(data), Gen2OakSpeech.intro_cry(data)
		])
	_new_game_warp()


## `HoFDisplayPlayerStats`' two stubs and the pages over the development save.
func _hall_of_fame() -> void:
	var data: GameData = _r.data
	var seen_owned: String = Gen2ProfOaksPC.fill_counts(
		data.special_text("hall_of_fame", "seen_owned"), 12, 3
	)
	_r.check(seen_owned == HOF_SEEN_OWNED, "DexSeenOwnedText fills to %s." % [seen_owned])
	var rating: String = data.special_text("hall_of_fame", "rating")
	_r.check(rating == HOF_RATING and Gen1Text.encode(rating).size() == HOF_RATING_TILES,
		"DexRatingText reads %s in %d tiles." % [rating, Gen1Text.encode(rating).size()])
	var save: Gen2SaveData = Gen2SaveStore.create_development_save(data, 0)
	var pages: Array = Gen2HallOfFame.pages(data, save, null)
	var mons: int = 0
	var text_pages: int = 0
	for page: Dictionary in pages:
		if bool(page.get("slide", false)) and StringName(page["kind"]) == Gen2HallOfFame.PAGE_MON:
			mons += 1
		if page.has("lines") and not page.has("bgp"):
			text_pages += 1
	_r.check(mons == save.party.size(), "%d of %d party members slide in." % [mons, save.party.size()])
	_r.check(
		pages.size() == 1 + mons * HOF_PAGES_PER_MON + 1 + text_pages + HOF_FADE_PAGES,
		"the induction is %d pages for %d members and %d boxes." % [pages.size(), mons, text_pages]
	)
	_r.check(bool(pages[0].get("music", false))
		and bool(pages[pages.size() - HOF_FADE_PAGES].get("fade_music", false)),
		"the music starts on the first page and fades with the last panel.")
	_r.check(Gen2HallOfFame.max_records(data) == HOF_TEAM_CAPACITY,
		"sHallOfFame keeps %d teams." % Gen2HallOfFame.max_records(data))


func _intro_keyboards() -> void:
	var model: Gen2NamingScreen = Gen2NamingScreen.for_gen1_player(_r.data)
	var rows: Array = model.rows()
	_r.check(rows.size() == Gen1Layout.ALPHABET_ROWS + 1,
		"the upper keyboard holds %d rows." % rows.size())
	for row: int in Gen1Layout.ALPHABET_ROWS:
		_r.check((rows[row] as Array).size() == Gen1Layout.ALPHABET_COLUMNS,
			"keyboard row %d holds %d cells." % [row, (rows[row] as Array).size()])
	model.row = Gen2NamingScreen.GEN1_END_ROW
	model.column = Gen2NamingScreen.GEN1_LAST_COLUMN
	_r.check(model.last_character() == Gen1Layout.CHAR_ED
		and model.cursor_command() == Gen2NamingScreen.COMMAND_END,
		"the last letter cell is not <ED>.")
	model.upper_case = false
	_r.check(model.rows()[0] != rows[0], "both keyboards hold the same letters.")
	_r.check(model.max_length == Gen2NamingScreen.GEN1_MAX_LENGTH,
		"a name may be %d characters." % model.max_length)


func _new_game_warp() -> void:
	var warp: Dictionary = _r.data.gen1_new_game_warp()
	_r.check(warp == NEW_GAME_WARP, "NewGameWarp reads %s." % [warp])
	var snapshot: Gen2WorldSnapshot = Gen2WorldSpawn.new_game_snapshot(_r.data)
	if not _r.check(snapshot != null, "the new game builds no world."):
		return
	_r.check(
		snapshot.map_id == Vector2i(0, int(NEW_GAME_WARP["map"]))
		and snapshot.player_cell == Vector2i(
			int(NEW_GAME_WARP["x"]), int(NEW_GAME_WARP["y"])
		)
		and snapshot.world_state.money(0) == Gen2WorldSpawn.START_MONEY
		and snapshot.world_state.pc_items() == {Gen2WorldSpawn.GEN1_POTION: 1}
		and snapshot.world_state.items().is_empty(),
		"the new game opens at %s %s with %s." % [
			snapshot.map_id, snapshot.player_cell, snapshot.world_state.pc_items()
		]
	)
	var map: Gen2WorldMap = _r.data.world_map(snapshot.map_id.x, snapshot.map_id.y)
	var tileset: Gen2WorldTileset = _r.data.world_tileset(map.tileset)
	_r.check(tileset.tile_passable(int(map.collision[
		snapshot.player_cell.y * map.collision_width + snapshot.player_cell.x
	])), "the new game's own cell cannot be stood on.")
	_r.note("the intro reads %d boxes and opens on map %d at %s" % [
		Gen1Layout.INTRO_TEXT_AT.size() + Gen1Layout.INTRO_NAME_TEXT_AT.size(),
		snapshot.map_id.y, snapshot.player_cell,
	])


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
	## `page` parts every description in two, which is what
	## `ShowPokedexDataInternal` waits between.
	var pages: Array = dex["pages"]
	_r.check(pages.size() == DEX_PAGES, "%s has %d description pages" % [name, pages.size()])
	for page: Variant in pages:
		_r.check(not String(page).is_empty(), "%s has an empty description page" % name)
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
	## The numbering skips $09 to $13, so a cache holding only the types that
	## exist cannot be read by position: every real number answers with a name.
	for type: int in Gen1Layout.TYPE_COUNT:
		if not _is_real_type(type):
			continue
		_r.check(
			not data.type_name(type).is_empty(), "type $%02X has no name." % type
		)
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
	_r.check(String(data.item(Gen1Layout.ITEM_COUNT + 1)["name"]) == "B2F",
		"$54 is not B2F")
	_r.check(String(data.item(Gen1Layout.ITEM_NAME_COUNT)["name"]) == "B4F",
		"$61 is not B4F")
	_r.check(String(data.item(Gen1Layout.ITEM_NAME_COUNT + 1)["name"]).is_empty(),
		"$62 has a name")
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
	## `CanLearnTMHMMove` over `BaseStats`' seven flag bytes, every species and
	## every machine; Yellow retuned six rows and MEW's padding byte is $FF.
	var pairs: int = 0
	for species: int in range(1, _r.data.species_count() + 1):
		for number: int in range(1, TMHM_COUNT + 1):
			if Gen2WorldTMHM.can_learn(_r.data, species, _r.data.tmhm_move(number)):
				pairs += 1
	_r.check(pairs == int(LEARNABLE_PAIRS[_r.game_id]),
		"%d species/machine pairs are learnable" % pairs)
	_r.check(Gen2WorldTMHM.can_learn(_r.data, CHARMANDER_DEX, CUT_MOVE),
		"CHARMANDER cannot learn CUT")


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


## `TradeMons` and the `special_text` run behind `InGameTradeTextPointers`: ten
## rows on all three cartridges, three dialog sets of five boxes each, and the
## two boxes `InGameTrade_DoTrade` prints around the swap.
func _trades() -> void:
	var wanted: Array = TRADES[&"yellow" if _r.game_id == RomRegistry.YELLOW else &"red"]
	var read: Array = []
	for index: int in _r.data.world_trade_count():
		var row: Dictionary = _r.data.world_trade(index)
		read.append([
			int(row["requested_species"]), int(row["offered_species"]),
			int(row["dialog"]), String(row["nickname"]),
		])
		_r.check(
			String(row["ot_name"]) == TRADE_OT_NAME
			and int(row["dvs"]) == TRADE_ROLLED and int(row["ot_id"]) == TRADE_ROLLED,
			"trade %d carries %s." % [index, row]
		)
	_r.check(read == wanted, "the trade table reads %s." % [read])
	for name: String in Gen2Layout.TRADE_TEXT_ORDER + Gen1Layout.NPC_TRADE_TEXT_AT.keys():
		_r.check(
			not _r.data.special_text("npc_trade", name).is_empty(),
			"the trade run has no %s box." % name
		)
