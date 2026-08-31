extends RefCounted

var _r: RefCounted = null

## Verifies `DecorationAttributes` and the `DecorationNames` run behind it against
## freshly imported real caches in all three games, and the name
## [Gen2WorldDecoration] spells from each row. One pinned address per cartridge
## finds the lot, so what says the address is right is the content: fifty-three
## rows whose types, actions, event flags and block or sprite bytes are the
## source's. The pins are byte identical bar one name, Gold and Silver spelling the
## third console "NINTENDO64" where Crystal spells it "NINTENDO 64".

## Every row, as [name, type, action, event flag, block or sprite]. The name is
## what `GetDecoName` assembles, not the `DecorationNames` entry the row points
## at: a poster, doll and big doll each name a species instead.
const EXPECTED: Array[Array] = [
	["CANCEL", 1, 0, 0, 0x00],
	["PUT IT AWAY", 1, 2, 0, 0x00],
	["FEATHERY BED", 2, 1, 676, 0x1B],
	["PINK BED", 2, 1, 677, 0x1C],
	["POLKADOT BED", 2, 1, 678, 0x1D],
	["PIKACHU BED", 2, 1, 679, 0x1E],
	["PUT IT AWAY", 1, 4, 0, 0x00],
	["RED CARPET", 3, 3, 680, 0x08],
	["BLUE CARPET", 3, 3, 681, 0x0B],
	["YELLOW CARPET", 3, 3, 682, 0x0E],
	["GREEN CARPET", 3, 3, 683, 0x11],
	["PUT IT AWAY", 1, 6, 0, 0x00],
	["MAGNAPLANT", 1, 5, 684, 0x20],
	["TROPICPLANT", 1, 5, 685, 0x21],
	["JUMBOPLANT", 1, 5, 686, 0x22],
	["PUT IT AWAY", 1, 8, 0, 0x00],
	["TOWN MAP", 1, 7, 687, 0x1F],
	["PIKACHU POSTER", 4, 7, 688, 0x23],
	["CLEFAIRY POSTER", 4, 7, 689, 0x24],
	["JIGGLYPUFF POSTER", 4, 7, 690, 0x25],
	["PUT IT AWAY", 1, 10, 0, 0x00],
	["NES", 1, 9, 691, 0x5C],
	["SUPER NES", 1, 9, 692, 0x5B],
	["NINTENDO 64", 1, 9, 693, 0x51],
	["VIRTUAL BOY", 1, 9, 694, 0x57],
	["PUT IT AWAY", 1, 12, 0, 0x00],
	["BIG SNORLAX", 6, 11, 719, 0x33],
	["BIG ONIX", 6, 11, 720, 0x50],
	["BIG LAPRAS", 6, 11, 721, 0x47],
	["PUT IT AWAY", 1, 14, 0, 0x00],
	["PIKACHU DOLL", 5, 13, 695, 0x8E],
	["SURF PIKACHU DOLL", 1, 13, 696, 0x34],
	["CLEFAIRY DOLL", 5, 13, 697, 0x8F],
	["JIGGLYPUFF DOLL", 5, 13, 698, 0x94],
	["BULBASAUR DOLL", 5, 13, 699, 0x93],
	["CHARMANDER DOLL", 5, 13, 700, 0x90],
	["SQUIRTLE DOLL", 5, 13, 701, 0x89],
	["POLIWAG DOLL", 5, 13, 702, 0x8D],
	["DIGLETT DOLL", 5, 13, 703, 0x8C],
	["STARYU DOLL", 5, 13, 704, 0x92],
	["MAGIKARP DOLL", 5, 13, 705, 0x88],
	["ODDISH DOLL", 5, 13, 706, 0x85],
	["GENGAR DOLL", 5, 13, 707, 0x86],
	["SHELLDER DOLL", 5, 13, 708, 0x84],
	["GRIMER DOLL", 5, 13, 709, 0x95],
	["VOLTORB DOLL", 5, 13, 710, 0x9B],
	["WEEDLE DOLL", 5, 13, 711, 0x83],
	["UNOWN DOLL", 5, 13, 712, 0x80],
	["GEODUDE DOLL", 5, 13, 713, 0x81],
	["MACHOP DOLL", 5, 13, 714, 0x9A],
	["TENTACOOL DOLL", 5, 13, 715, 0x98],
	["GOLD TROPHY", 1, 13, 717, 0x5E],
	["SILVER TROPHY", 1, 13, 718, 0x5F],
]
## `data/decorations/names.asm`'s one difference between the pins.
const NINTENDO_64: int = 23
const NINTENDO_64_GOLD_SILVER: String = "NINTENDO64"
const FIELDS: Array[String] = ["type", "action", "flag", "sprite"]

## `_PlayerDecorationMenu.category_pointers`' seven categories and the ids each
## `FindOwned*` list holds, which is what a category menu offers once the flags
## are set. Pinned from the source's own lists rather than read off the table,
## so the two have to agree.
const EXPECTED_CATEGORIES: Dictionary = {
	&"bed": [2, 3, 4, 5],
	&"carpet": [7, 8, 9, 10],
	&"plant": [12, 13, 14],
	&"poster": [16, 17, 18, 19],
	&"console": [21, 22, 23, 24],
	&"big_doll": [26, 27, 28],
	&"left_ornament": [
		30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47,
		48, 49, 50, 51, 52,
	],
}


## `DecorationIDs`, transcribed from the source's own list rather than read off
## the table this check reads: the flag order is not the id order, since the
## dolls come in front of the big dolls here and behind them there.
const EXPECTED_IDS: Array[int] = [
	2, 3, 4, 5,
	7, 8, 9, 10,
	12, 13, 14,
	16, 17, 18, 19,
	21, 22, 23, 24,
	30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47,
	48, 49, 50,
	26, 27, 28,
	51, 52,
]


func run(r: RefCounted) -> void:
	_r = r
	_r.each_game(_verify_game)


func _verify_game() -> void:
	var data: GameData = _r.data
	if not _r.check(
		data.decoration_count() == EXPECTED.size(),
		"the table holds %d rows, not %d" % [data.decoration_count(), EXPECTED.size()]
	):
		return
	for deco: int in EXPECTED.size():
		_verify_row(data, deco)
	_verify_categories(data)
	_verify_ids(data)
	_r.note("%d decoration rows in %d categories, %d flag indices" % [
		EXPECTED.size(), EXPECTED_CATEGORIES.size(), EXPECTED_IDS.size(),
	])


## `GetDecorationID`, which is the whole of what `SetSpecificDecorationFlag` and
## Mystery Gift's copy walk do before they touch a flag. The two trophy dolls sit
## past `NUM_NON_TROPHY_DECOS`, which is the reason the walk stops short of them.
func _verify_ids(data: GameData) -> void:
	for index: int in EXPECTED_IDS.size():
		var deco: int = Gen2WorldDecoration.decoration_for_flag(data, index)
		_r.check(
			deco == EXPECTED_IDS[index],
			"flag %d names decoration %d, not %d" % [index, deco, EXPECTED_IDS[index]]
		)
	_r.check(
		Gen2WorldDecoration.decoration_for_flag(data, EXPECTED_IDS.size()) == 0,
		"the run past the table's end answers a decoration"
	)
	_r.check(
		Gen2WorldDecoration.decoration_for_flag(
			data, Gen2WorldDecoration.DECOFLAG_GOLD_TROPHY_DOLL
		) == 51
		and Gen2WorldDecoration.decoration_for_flag(
			data, Gen2WorldDecoration.DECOFLAG_SILVER_TROPHY_DOLL
		) == 52,
		"the two trophy boxes do not reach their own dolls"
	)


func _verify_row(data: GameData, deco: int) -> void:
	var expected: Array = EXPECTED[deco]
	var name: String = String(expected[0])
	if deco == NINTENDO_64 and not _r.crystal:
		name = NINTENDO_64_GOLD_SILVER
	var spelled: String = Gen2WorldDecoration.decoration_name(data, deco)
	_r.check(
		spelled == name,
		"row %d is named \"%s\", not \"%s\"" % [deco, spelled, name]
	)
	var row: Dictionary = data.decoration(deco)
	for index: int in FIELDS.size():
		var field: String = FIELDS[index]
		_r.check(
			int(row.get(field, -1)) == int(expected[index + 1]),
			"row %d's %s is %d, not %d" % [
				deco, field, int(row.get(field, -1)), int(expected[index + 1]),
			]
		)


## The category a row's action puts it in, and the PUT IT AWAY header each
## category has exactly one of.
func _verify_categories(data: GameData) -> void:
	var found: Dictionary = {}
	var headers: Dictionary = {}
	for deco: int in EXPECTED.size():
		var slot: StringName = Gen2WorldDecoration.slot_of(data, deco)
		if slot.is_empty():
			_r.check(deco == 0, "row %d belongs to no category" % deco)
			continue
		if Gen2WorldDecoration.is_put_away(data, deco):
			headers[slot] = int(headers.get(slot, 0)) + 1
			continue
		var members: Array = found.get(slot, [])
		members.append(deco)
		found[slot] = members
	for slot: StringName in EXPECTED_CATEGORIES:
		_r.check(
			found.get(slot, []) == EXPECTED_CATEGORIES[slot],
			"category %s holds %s, not %s" % [
				slot, JSON.stringify(found.get(slot, [])),
				JSON.stringify(EXPECTED_CATEGORIES[slot]),
			]
		)
		_r.check(
			int(headers.get(slot, 0)) == 1,
			"category %s has %d PUT IT AWAY rows, not one" % [
				slot, int(headers.get(slot, 0)),
			]
		)
	_verify_menu_trim(data)


## `PopulateDecoCategoryMenu`'s `cp 8`, counted on the list with PUT IT AWAY and
## CANCEL already on it: six owned rows make eight and lose the last.
func _verify_menu_trim(data: GameData) -> void:
	var ornaments: Array = EXPECTED_CATEGORIES[Gen2WorldDecoration.SLOT_LEFT_ORNAMENT]
	for owned: int in range(1, ornaments.size() + 1):
		var state := Gen2WorldState.new()
		for index: int in owned:
			Gen2WorldDecoration.set_owned(data, state, int(ornaments[index]))
		var rows: Array = Gen2WorldDecoration.category_rows(
			data, state, Gen2WorldDecoration.SLOT_LEFT_ORNAMENT
		)
		var cancels: bool = owned + 2 < Gen2WorldDecoration.CATEGORY_MENU_HEIGHT
		_r.check(
			rows.size() == owned + (2 if cancels else 1),
			"%d owned ornaments gave %d rows" % [owned, rows.size()]
		)
		_r.check(
			(int(rows[rows.size() - 1]["deco"]) == 0) == cancels,
			"%d owned ornaments got CANCEL wrong" % owned
		)
