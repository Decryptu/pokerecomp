extends RefCounted

var _r: RefCounted = null

## [Gen2WorldCatalog] on all six cartridges. The catalog is derived from the
## decoded scripts and events, so what is pinned is the meaning as well as the
## count: the starters by name, every badge granted once, the legendaries at
## their levels and the Game Corner's prices, against a decode that drifts.

## constants/pokemon_constants.asm.
const CHIKORITA: int = 152
const CYNDAQUIL: int = 155
const TOTODILE: int = 158
const LUGIA: int = 249
const HO_OH: int = 250
const CELEBI: int = 251
const SUICUNE: int = 245
const SUDOWOODO: int = 185
const SNORLAX: int = 143
const RED_GYARADOS: int = 130

## constants/pokemon_constants.asm on Red, Blue and Yellow.
const BULBASAUR: int = 1
const CHARMANDER: int = 4
const SQUIRTLE: int = 7
const PIKACHU: int = 25
const MAROWAK: int = 105
const ARTICUNO: int = 144
const ZAPDOS: int = 145
const MOLTRES: int = 146
const MEWTWO: int = 150
const GOLD_TEETH: int = 0x40
const HM04: int = 199
## `[item, map]`: a key item behind the gate it opens. The parcel and the flute
## into the Safari Zone, past the old man and Snorlax.
const GEN1_SELF_LOCKS: Array = [[0x46, Vector2i(0, 0xDB)], [0x49, Vector2i(0, 0xDB)]]
## The egg past the Route 30 battle, the Squirtbottle past Sudowoodo, the
## SecretPotion and the S.S. Ticket into Kanto past the Mineral Badge.
const GEN2_SELF_LOCKS: Array = [
	[0x45, Vector2i(10, 5)], [0xAF, Vector2i(4, 9)], [0x43, Vector2i(12, 2)], [0x44, Vector2i(12, 3)],
]

## Per game: total rows, and the count under each kind in
## [constant Gen2WorldCatalog.KINDS]' own order.
const EXPECTED_CENSUS: Dictionary = {
	&"gold": [449, 3, 9, 15, 8, 9, 352, 16, 37],
	&"silver": [449, 3, 9, 15, 8, 9, 352, 16, 37],
	&"crystal": [516, 3, 11, 14, 9, 6, 419, 16, 38],
	&"red": [270, 3, 4, 16, 9, 10, 206, 8, 14],
	&"blue": [270, 3, 4, 16, 9, 10, 206, 8, 14],
	&"yellow": [276, 1, 7, 18, 7, 10, 211, 8, 14],
}

## Oak's three balls, and Yellow's one Pikachu.
const EXPECTED_STARTERS: Dictionary = {
	&"gold": [CHIKORITA, CYNDAQUIL, TOTODILE],
	&"silver": [CHIKORITA, CYNDAQUIL, TOTODILE],
	&"crystal": [CHIKORITA, CYNDAQUIL, TOTODILE],
	&"red": [BULBASAUR, CHARMANDER, SQUIRTLE],
	&"blue": [BULBASAUR, CHARMANDER, SQUIRTLE],
	&"yellow": [PIKACHU],
}

## The birds, Mewtwo, the two Snorlax and the ghost Marowak, from the map
## scripts and the standing objects alike.
const GEN1_STATICS: Dictionary = {
	ARTICUNO: [50], ZAPDOS: [50], MOLTRES: [50], MEWTWO: [70], SNORLAX: [30, 30],
	MAROWAK: [30],
}

## The legendaries and set pieces every profile has to place, and at what level.
## `maps/*.asm`'s own `loadwildmon` operands.
const EXPECTED_STATICS: Dictionary = {
	&"gold": {LUGIA: [70, 40], HO_OH: [40, 70], SNORLAX: [50], SUDOWOODO: [20]},
	&"silver": {LUGIA: [70, 40], HO_OH: [40, 70], SNORLAX: [50], SUDOWOODO: [20]},
	&"crystal": {
		LUGIA: [60], HO_OH: [60], CELEBI: [30], SUICUNE: [40],
		SNORLAX: [50], SUDOWOODO: [20], RED_GYARADOS: [30],
	},
	&"red": GEN1_STATICS, &"blue": GEN1_STATICS, &"yellow": GEN1_STATICS,
}

## `maps/GoldenrodGameCorner.asm` and `maps/CeladonGameCorner.asm`'s own
## `EQU` prices, in the order the corpus walk reaches them. Generation 1's are
## the Magikarp salesman's ¥500 and then `PrizeMenus`' three lists of coins.
const EXPECTED_PRIZE_PRICES: Dictionary = {
	&"gold": [200, 700, 2100, 200, 700, 2100, 3333, 6666, 9999],
	&"silver": [200, 700, 2100, 200, 700, 2100, 3333, 6666, 9999],
	&"crystal": [100, 800, 1500, 2222, 5555, 8888],
	&"red": [500, 180, 500, 1200, 2800, 5500, 9999, 3300, 5500, 7700],
	&"blue": [500, 120, 750, 1200, 2500, 4600, 6500, 3300, 5500, 7700],
	&"yellow": [500, 230, 1000, 2680, 6500, 6500, 9999, 3300, 5500, 7700],
}


func run(r: RefCounted) -> void:
	_r = r
	_r.each_game(_one_game)
	_r.each_game_of(RomRegistry.GEN1, _one_game)


func _one_game() -> void:
	var _catalog: Gen2WorldCatalog = _r.data.catalog()
	_verify_census(_catalog)
	_verify_starters(_catalog)
	_verify_statics(_catalog)
	_verify_prizes(_catalog)
	_verify_badges(_catalog)
	_verify_ids(_catalog)
	_verify_patching(_catalog)
	if _r.data.generation == RomRegistry.GEN1:
		_verify_gen1_links(_catalog)
		_verify_gen1_progression(_catalog)
	else:
		_verify_links(_catalog)
		_verify_progression(_catalog)
	_verify_sidecar(_catalog)


## The sidecar is what a player actually reads: the scan costs thirteen seconds
## and runs at import, and every check above this one ran against whatever
## [method GameData.catalog] handed back. So this asks the other question, that
## a restored catalog and a freshly scanned one are the same catalog, every row,
## every link and every kind's order.
func _verify_sidecar(_catalog: Gen2WorldCatalog) -> void:
	var written: Variant = RomCache.read_json(
		RomCache.world_catalog_path(_r.data.directory)
	)
	if not _r.check(written is Dictionary, "the import wrote no _catalog sidecar."):
		return
	var restored: Gen2WorldCatalog = Gen2WorldCatalog.from_dict(_r.data, written)
	if not _r.check(restored != null, "the _catalog sidecar does not restore."):
		return
	var scanned: Gen2WorldCatalog = Gen2WorldCatalog.build(_r.data)
	_r.check(
		restored.to_dict() == scanned.to_dict(),
		"the sidecar and a fresh scan disagree."
	)
	## And the one thing `to_dict` cannot say: that what the runtime asks for
	## comes back the same, patches folded in and all.
	for kind: StringName in Gen2WorldCatalog.KINDS:
		_r.check(
			restored.ids(kind) == scanned.ids(kind),
			"%s ids differ between the sidecar and a fresh scan." % kind
		)
		for id: int in scanned.ids(kind):
			if restored.check(id) != scanned.check(id):
				_r.check(false, "row %d differs between the sidecar and a scan." % id)
				return


func _verify_census(_catalog: Gen2WorldCatalog) -> void:
	var found: Array = [_catalog.size()]
	for kind: StringName in Gen2WorldCatalog.KINDS:
		found.append(_catalog.ids(kind).size())
	var expected: Array = EXPECTED_CENSUS[_r.game_id]
	_r.note("catalog %d rows: %s." % [_catalog.size(), str(found.slice(1))])
	_r.check(
		found == expected,
		"census is %s, not the pinned %s." % [str(found), str(expected)]
	)


## The one shape only Elm's three balls take: a `pokepic` of the species a
## `givepoke` in the same script hands over; on Red and Blue, a `wPlayerStarter`
## store on the way to the give. If either stops being unique, this is where it
## shows.
func _verify_starters(_catalog: Gen2WorldCatalog) -> void:
	var found: Array[int] = _catalog.possible_starters()
	found.sort()
	var wanted: Array = EXPECTED_STARTERS[_r.game_id]
	_r.check(
		Array(found) == wanted, "starters are %s, not the pinned %s." % [str(found), str(wanted)]
	)
	for row: Dictionary in _catalog.rows(Gen2WorldCatalog.KIND_STARTER):
		_r.check(
			int(row["level"]) == 5,
			"a starter is offered at level %d rather than 5." % int(row["level"])
		)


func _verify_statics(_catalog: Gen2WorldCatalog) -> void:
	var levels: Dictionary = {}
	for row: Dictionary in _catalog.rows(Gen2WorldCatalog.KIND_STATIC):
		var species: int = int(row["species"])
		var list: Array = levels.get(species, [])
		list.append(int(row["level"]))
		levels[species] = list
	for species: int in EXPECTED_STATICS[_r.game_id]:
		var wanted: Array = EXPECTED_STATICS[_r.game_id][species]
		var found: Array = levels.get(species, [])
		found.sort()
		var sorted_wanted: Array = wanted.duplicate()
		sorted_wanted.sort()
		_r.check(
			found == sorted_wanted,
			"species %d stands at %s, not the pinned %s." % [
				species, str(found), str(sorted_wanted),
			]
		)


## A prize is a give site with a `takecoins` behind it, and the price has to be
## the one for THAT branch rather than the first one in the vendor's script.
func _verify_prizes(_catalog: Gen2WorldCatalog) -> void:
	var prices: Array = []
	for row: Dictionary in _catalog.rows(Gen2WorldCatalog.KIND_PRIZE):
		prices.append(int(row["price"]))
	_r.check(
		prices == EXPECTED_PRIZE_PRICES[_r.game_id],
		"prize prices are %s, not the pinned %s." % [
			str(prices), str(EXPECTED_PRIZE_PRICES[_r.game_id]),
		]
	)


## Sixteen badges exist and each is granted somewhere; Kanto's eight sit from
## `KANTO_BADGE_FIRST` on a Generation 1 cartridge. Gold and Silver set two of
## them from a second script as well, which is why the row count is not the badge
## count and why the test is over the SET rather than the list.
func _verify_badges(_catalog: Gen2WorldCatalog) -> void:
	var seen: Dictionary = {}
	for row: Dictionary in _catalog.rows(Gen2WorldCatalog.KIND_BADGE):
		seen[int(row["badge"])] = true
		_r.check(
			_catalog.is_progression(row), "badge %d is not progression." % int(row["badge"])
		)
	var badges: Array = seen.keys()
	badges.sort()
	var wanted: Array = range(Gen2WorldState.BADGE_ENGINE_FLAGS.size())
	if _r.data.generation == RomRegistry.GEN1:
		wanted = range(Gen2WorldState.KANTO_BADGE_FIRST, Gen2WorldState.BADGE_ENGINE_FLAGS.size())
	_r.check(
		badges == wanted,
		"badges %s are granted, not %s." % [str(badges), str(wanted)]
	)


## An id has to name one site and be recomputable from the site's own address,
## since that is what a runtime reader does. Both directions, over every row.
func _verify_ids(_catalog: Gen2WorldCatalog) -> void:
	var seen: Dictionary = {}
	for row: Dictionary in _catalog.rows():
		var id: int = int(row["id"])
		if seen.has(id):
			_r.check(false, "id %d names two sites." % id)
			return
		seen[id] = true
		if not row.has("address"):
			continue
		var recomputed: int = Gen2WorldCatalog.pack_id(
			StringName(row["kind"]), int(row["bank"]), int(row["address"])
		)
		if recomputed != id & ~Gen2WorldCatalog.ID_VARIANT_MASK:
			_r.check(false, "id %d does not recompute from its own address." % id)
			return
	_r.note("%d ids, each naming one site." % seen.size())


## The four fields whose effect is not at the command the site is: a starter's
## picture, and a prize's two coin commands. A patch that reached the `givepoke`
## alone would show one Pokemon and hand over another.
func _verify_links(_catalog: Gen2WorldCatalog) -> void:
	for row: Dictionary in _catalog.rows(Gen2WorldCatalog.KIND_STARTER):
		_r.check(
			row.has("picture_address"),
			"a starter has no linked pokepic, so its ball would show the old one."
		)
		if not row.has("picture_address"):
			return
		var linked: Dictionary = _catalog.link_at(
			int(row["bank"]), int(row["picture_address"])
		)
		_r.check(
			int(linked.get("id", -1)) == int(row["id"])
				and StringName(linked.get("role", &"")) == &"picture",
			"a starter's pokepic does not link back to it."
		)
	for row: Dictionary in _catalog.rows(Gen2WorldCatalog.KIND_PRIZE):
		for key: String in ["check_address", "take_address"]:
			_r.check(row.has(key), "a prize has no linked %s." % key)
			if not row.has(key):
				return
			var linked: Dictionary = _catalog.link_at(int(row["bank"]), int(row[key]))
			_r.check(
				int(linked.get("id", -1)) == int(row["id"])
					and StringName(linked.get("role", &"")) == &"price",
				"a prize's %s does not link back to it." % key
			)
	var shops: Array = _catalog.rows(Gen2WorldCatalog.KIND_SHOP)
	var stocked: int = 0
	for row: Dictionary in shops:
		if not (row.get("items", []) as Array).is_empty():
			stocked += 1
	_r.check(stocked > 0, "no shop site carries an inventory.")
	_r.note("%d of %d shop sites carry their own shelf." % [stocked, shops.size()])


## The cartridge's own placement finishes, and one that hides Surf behind Surf
## does not. The second is the whole reason the validator exists.
func _verify_progression(_catalog: Gen2WorldCatalog) -> void:
	var data: GameData = GameData.open(_r.game_id)
	if data == null:
		return
	var vanilla: Dictionary = Gen2WorldProgression.validate(data, {})
	_r.check(
		bool(vanilla["ok"]),
		"the cartridge's own placement does not validate: %s." % str(vanilla.get("missing", {}))
	)
	_r.note("progression: %d checks reached, %d of them critical." % [
		int(vanilla["reached"]), int(vanilla["critical"]),
	])

	var surf_item: int = 0
	for item: int in _catalog.field_hm_items():
		if _catalog.move_for_hm_item(item) == Gen2WorldFieldMove.MOVE_SURF:
			surf_item = item
	## Every other move and every gate open, so only Surf stands in the way.
	var walk: Gen2WorldReachability = Gen2WorldReachability.build(data, _catalog.story())
	var moves: Dictionary = {}
	for move: int in Gen2WorldReachability.GATE_MOVES:
		if move != Gen2WorldFieldMove.MOVE_SURF:
			moves[move] = true
	var dry: Dictionary = walk.reachable(Gen2WorldProgression.start_map(data), moves)
	var behind: int = -1
	for row: Dictionary in _catalog.rows(Gen2WorldCatalog.KIND_ITEM):
		if not row.has("map"):
			continue
		var key: int = Gen2WorldReachability.map_key(
			int((row["map"] as Vector2i).x), int((row["map"] as Vector2i).y)
		)
		if not dry.has(key):
			behind = int(row["id"])
			break
	if behind < 0 or surf_item <= 0:
		_r.check(false, "no site behind Surf to build a self-locking placement from.")
		return
	## Surf on a shore only Surf reaches, and nowhere else.
	var patches: Dictionary = {behind: {"item": surf_item}}
	for row: Dictionary in _catalog.rows(Gen2WorldCatalog.KIND_ITEM):
		if int(row["item"]) == surf_item and int(row["id"]) != behind:
			patches[int(row["id"])] = {"item": Gen2Layout.ITEM_TM01}
	var locked: Dictionary = Gen2WorldProgression.validate(data, patches)
	_r.check(not bool(locked["ok"]), "a placement hiding Surf behind Surf validated.")
	_r.check(
		not (locked.get("missing", {}) as Dictionary).is_empty(),
		"a rejected placement named no unreachable requirement."
	)
	## And it is the same answer twice, which is what lets a generator retry.
	_r.check(
		Gen2WorldProgression.validate(data, patches) == locked,
		"two validations of one placement disagreed."
	)
	_r.check(
		bool(Gen2WorldProgression.validate(data, {})["ok"]),
		"a rejected placement was left installed."
	)
	_verify_self_locks(data, _catalog, GEN2_SELF_LOCKS)


## Each key item swapped with a ball behind the gate it opens is refused.
func _verify_self_locks(data: GameData, _catalog: Gen2WorldCatalog, locks: Array) -> void:
	for lock: Array in locks:
		var source: Dictionary = {}
		var behind: Dictionary = {}
		for row: Dictionary in _catalog.rows(Gen2WorldCatalog.KIND_ITEM):
			if int(row["item"]) == int(lock[0]) and source.is_empty():
				source = row
			elif row.get("map", Vector2i(-1, -1)) == lock[1] and behind.is_empty():
				behind = row
		if not _r.check(not source.is_empty() and not behind.is_empty(), "no site for self-lock %s." % str(lock)):
			continue
		var result: Dictionary = Gen2WorldProgression.validate(data, {
			int(source["id"]): {"item": int(behind["item"])}, int(behind["id"]): {"item": int(lock[0])},
		})
		_r.check(not bool(result["ok"]), "item %X behind its own gate on %s validated." % [lock[0], lock[1]])
		_r.note("item %X on %s refused: %s" % [lock[0], lock[1], str(result.get("missing", {}))])


## The whole point of the catalog: a patch has to reach the row a runtime reader
## gets. Done on an overlay of this check's own, so the shared one is untouched.
func _verify_patching(_catalog: Gen2WorldCatalog) -> void:
	var overlay := Gen2ContentOverlay.new()
	var data: GameData = GameData.open(_r.game_id)
	if data == null:
		return
	data.set_content_overlay(overlay)
	var patched: Gen2WorldCatalog = data.catalog()
	var moved: int = 0
	for kind: StringName in [
		Gen2WorldCatalog.KIND_STARTER, Gen2WorldCatalog.KIND_GIFT,
		Gen2WorldCatalog.KIND_STATIC, Gen2WorldCatalog.KIND_PRIZE,
	]:
		for row: Dictionary in patched.rows(kind):
			overlay.patch(Gen2ContentOverlay.KIND_CHECK, &"check", int(row["id"]), {
				"species": CELEBI, "level": 7,
			})
			var after: Dictionary = patched.check(int(row["id"]))
			if int(after["species"]) != CELEBI or int(after["level"]) != 7:
				_r.check(false, "row %d did not read its patch back." % int(row["id"]))
				return
			moved += 1
	for row: Dictionary in patched.rows(Gen2WorldCatalog.KIND_ITEM):
		overlay.patch(Gen2ContentOverlay.KIND_CHECK, &"check", int(row["id"]), {
			"item": 1, "quantity": 3,
		})
		var after: Dictionary = patched.check(int(row["id"]))
		if int(after["item"]) != 1 or int(after["quantity"]) != 3:
			_r.check(false, "item row %d did not read its patch back." % int(row["id"]))
			return
		moved += 1
	_r.note("%d rows patched and read back." % moved)
	_r.check(
		Gen2ContentOverlay.shared().is_empty(),
		"the check leaked into the shared overlay."
	)


## Oak's three balls are one `AddPartyMon` at one address, so they are three
## rows at it, and the `wPlayerStarter` store beside it answers for each by the
## species that reaches it. The Magikarp salesman's two money commands link the
## same way a prize's coin commands do.
func _verify_gen1_links(_catalog: Gen2WorldCatalog) -> void:
	for row: Dictionary in _catalog.rows(Gen2WorldCatalog.KIND_STARTER):
		if not _r.check(row.has("starter_address"), "a starter has no linked wPlayerStarter store."):
			return
		var linked: Dictionary = _catalog.gen1_linked(
			Gen2WorldCatalog.KIND_STARTER, "starter_address",
			RomFile.linear(int(row["bank"]), int(row["starter_address"])),
			{"species": int(row["species"])}
		)
		_r.check(
			int(linked.get("id", -1)) == int(row["id"]),
			"the store beside starter %d does not answer for it." % int(row["species"])
		)
	var linked_prizes: int = 0
	for row: Dictionary in _catalog.rows(Gen2WorldCatalog.KIND_PRIZE):
		if not row.has("address"):
			continue
		linked_prizes += 1
		for key: String in ["ask_address", "spend_address"]:
			if not _r.check(row.has(key), "the money prize has no linked %s." % key):
				return
			var linked: Dictionary = _catalog.link_at(int(row["bank"]), int(row[key]))
			_r.check(
				int(linked.get("id", -1)) == int(row["id"])
					and StringName(linked.get("role", &"")) == &"price",
				"the money prize's %s does not link back to it." % key
			)
	_r.check(linked_prizes == 1, "%d prizes are script sites, not the salesman alone." % linked_prizes)
	var stocked: int = 0
	for row: Dictionary in _catalog.rows(Gen2WorldCatalog.KIND_SHOP):
		if not (row.get("items", []) as Array).is_empty():
			stocked += 1
	_r.check(
		stocked == _catalog.ids(Gen2WorldCatalog.KIND_SHOP).size(),
		"%d shop sites carry no shelf." % (_catalog.ids(Gen2WorldCatalog.KIND_SHOP).size() - stocked)
	)


## The cartridge's own placement finishes; one that takes the Gold Teeth away
## leaves the Warden's HM04 behind the item he asks for, and says so.
func _verify_gen1_progression(_catalog: Gen2WorldCatalog) -> void:
	var data: GameData = GameData.open(_r.game_id)
	if data == null:
		return
	var vanilla: Dictionary = Gen2WorldProgression.validate(data, {})
	_r.check(
		bool(vanilla["ok"]),
		"the cartridge's own placement does not validate: %s." % str(vanilla.get("missing", {}))
	)
	_r.note("progression: %d checks reached, %d of them critical." % [
		int(vanilla["reached"]), int(vanilla["critical"]),
	])
	var teeth: int = -1
	var warden: int = -1
	for row: Dictionary in _catalog.rows(Gen2WorldCatalog.KIND_ITEM):
		if int(row["item"]) == GOLD_TEETH:
			teeth = int(row["id"])
		if int(row["item"]) == HM04 and row["requires"].has({"item": GOLD_TEETH}):
			warden = int(row["id"])
	if not _r.check(teeth >= 0 and warden >= 0, "no Gold Teeth ball or no Warden asking for them."):
		return
	var gone: Dictionary = {teeth: {"item": Gen2Layout.ITEM_TM01}}
	var locked: Dictionary = Gen2WorldProgression.validate(data, gone)
	_r.check(not bool(locked["ok"]), "a placement with no Gold Teeth validated.")
	var missing: Dictionary = locked.get("missing", {})
	_r.check(
		int(missing.get("check", -1)) == warden and missing.get("requirement", {}) == {"item": GOLD_TEETH},
		"the refusal named %s rather than the Warden's Gold Teeth." % str(missing)
	)
	_r.check(
		Gen2WorldProgression.validate(data, gone) == locked,
		"two validations of one placement disagreed."
	)
	_r.check(
		bool(Gen2WorldProgression.validate(data, {})["ok"]),
		"a rejected placement was left installed."
	)
	_verify_self_locks(data, _catalog, GEN1_SELF_LOCKS)
