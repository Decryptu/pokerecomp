extends RefCounted

var _r: RefCounted = null

## Sweeps Mystery Gift against freshly imported real caches on all three
## cartridges: both gift tables end to end, every box `DoMysteryGift` can end on,
## the screen each cartridge draws, and the whole decision chain between the
## exchange and the gift. The class this stops is a chain answering the wrong box:
## every refusal in `DoMysteryGift` is one `jp` from the next and a happy-path test
## never sees the other seven, so the chain is driven once per outcome.

## `MysteryGiftItems` and `MysteryGiftDecos`. The first and last row of each is
## what tells a table read forwards from one read backwards, and the pair of
## fourth rows is `MysteryGiftFallbackItem`'s own shared byte.
const FIRST_ITEM: int = 0xAD
const LAST_ITEM: int = 0xBD
const FIRST_DECO: int = 0x16
const LAST_DECO: int = 0x27

## Crystal's `_CGB_MysteryGift` copies two palettes and Gold and Silver's copies
## one, which is the one thing about the screen that is not the same on all
## three.
const PALETTES: Dictionary = {&"crystal": 2, &"gold": 1, &"silver": 1}

## `.String_PressAToLink_BToCancel`'s own four lines.
const PROMPT_LINES: int = 4

## A partner block that reaches the gift, which every outcome case then breaks
## in exactly one way.
const PARTNER: Dictionary = {
	"game_version": 1, "id": 0x1234, "name": "KRIS", "dex_caught": 30,
	"sent_deco": 0, "which_item": 0, "which_deco": 0, "backup_item": 0,
	"daily_partners": 0,
}


func run(r: RefCounted) -> void:
	_r = r
	var screens: Dictionary = {}
	for game_id: StringName in _r.GAME_IDS:
		var data: GameData = GameData.open(game_id)
		if data == null:
			_r.fail("%s cache is unavailable. Import roms/%s.gbc first." % [game_id, game_id])
			continue
		_r.game_id = game_id
		if not _r.check(
			data.has_mystery_gift(), "%s: no Mystery Gift block in the cache." % game_id
		):
			continue
		_verify_tables(game_id, data)
		_verify_boxes(game_id, data)
		screens[game_id] = _verify_screen(game_id, data)
		_verify_chain(game_id, data)
		_verify_live_screen(game_id, data)
	_r.game_id = &""
	_verify_screens_agree(screens)


## Both tables are their own length, open and close on their own rows, and
## every row of `MysteryGiftDecos` names a decoration that is not a trophy: the
## two trophy dolls sit past `NUM_NON_TROPHY_DECOS` and the received-decoration
## flag array has no room for one.
func _verify_tables(game_id: StringName, data: GameData) -> void:
	for decorations: bool in [false, true]:
		var table: Array = data.mystery_gift_table(decorations)
		var label: String = "MysteryGiftDecos" if decorations else "MysteryGiftItems"
		if not _r.check(
			table.size() == RomLayout.MYSTERY_GIFT_TABLE_ROWS,
			"%s: %s is %d rows, not %d." % [
				game_id, label, table.size(), RomLayout.MYSTERY_GIFT_TABLE_ROWS,
			]
		):
			continue
		var first: int = FIRST_DECO if decorations else FIRST_ITEM
		var last: int = LAST_DECO if decorations else LAST_ITEM
		_r.check(
			int(table[0]) == first and int(table[-1]) == last,
			"%s: %s runs $%02X..$%02X, not $%02X..$%02X." % [
				game_id, label, int(table[0]), int(table[-1]), first, last,
			]
		)
		if not decorations:
			continue
		var highest: int = 0
		for row: Variant in table:
			highest = maxi(highest, int(row))
		_r.check(
			highest < Gen2MysteryGift.NUM_NON_TROPHY_DECOS,
			"%s: %s offers decoration %d, which is a trophy." % [
				game_id, label, highest,
			]
		)
	## `MysteryGiftFallbackItem` is one byte read two ways, so an index past
	## either end has to answer it and nothing else.
	for decorations: bool in [false, true]:
		_r.check(
			Gen2MysteryGift.gift_at(
				data.mystery_gift_table(decorations),
				RomLayout.MYSTERY_GIFT_TABLE_ROWS
			) == Gen2MysteryGift.FALLBACK_GIFT,
			"%s: an index past the table's end is not the fallback." % game_id
		)


## All eight `text_far` stubs decode, and each says what only it says. A run
## pinned one stub out would still decode eight boxes, so the content is what
## the check is on.
func _verify_boxes(game_id: StringName, data: GameData) -> void:
	var contains: Dictionary = {
		Gen2MysteryGift.OUTCOME_CANCELED: "cancelled",
		Gen2MysteryGift.OUTCOME_COMM_ERROR: "Communication",
		Gen2MysteryGift.OUTCOME_RETRIEVE: "retrieve",
		Gen2MysteryGift.OUTCOME_FRIEND_NOT_READY: "friend",
		Gen2MysteryGift.OUTCOME_FIVE_A_DAY: "five",
		Gen2MysteryGift.OUTCOME_ONE_A_DAY: "per person",
		Gen2MysteryGift.OUTCOME_SENT: "sent",
		Gen2MysteryGift.OUTCOME_SENT_HOME: "home",
	}
	for outcome: Variant in contains:
		var text: String = Gen2MysteryGiftScreen.box_text(
			data, StringName(outcome), "KRIS", "GOLD", "BERRY"
		)
		_r.check(
			text.contains(String(contains[outcome])),
			"%s: the %s box reads \"%s\"." % [game_id, outcome, text]
		)
	## The two boxes the gift arrives in are the only two that name anybody, and
	## both have to spell the partner rather than leaving a marker behind.
	for outcome: StringName in [
		Gen2MysteryGift.OUTCOME_SENT, Gen2MysteryGift.OUTCOME_SENT_HOME,
	]:
		var text: String = Gen2MysteryGiftScreen.box_text(
			data, outcome, "KRIS", "GOLD", "BERRY"
		)
		_r.check(
			text.contains("KRIS") and text.contains("BERRY") \
				and not text.contains(Gen2TextStream.RAM_MARKER),
			"%s: the %s box did not fill its buffers: \"%s\"." % [
				game_id, outcome, text,
			]
		)


## The screen each cartridge draws: the tilemap indexes its own art, the prompt
## is the routine's own four lines, and the picture comes out at screen size.
func _verify_screen(game_id: StringName, data: GameData) -> PackedByteArray:
	var page: Gen2MysteryGiftPage = Gen2MysteryGiftPage.from_data(data)
	if not _r.check(page != null, "%s: the Mystery Gift page did not build." % game_id):
		return PackedByteArray()
	_r.check(
		page.palette.size() == int(PALETTES[game_id]) * RomLayout.PREDEF_PALETTE_COLORS,
		"%s: the screen carries %d colours, not %d palettes' worth." % [
			game_id, page.palette.size(), int(PALETTES[game_id]),
		]
	)
	_r.check(
		page.prompt.split("\n").size() == PROMPT_LINES,
		"%s: the prompt is %d lines, not %d." % [
			game_id, page.prompt.split("\n").size(), PROMPT_LINES,
		]
	)
	var tiles: int = data.mystery_gift_indices().size() / (
		Gen2Tiles.TILE_WIDTH * Gen2Tiles.TILE_HEIGHT
	)
	var highest: int = 0
	for code: int in page.tilemap():
		## `ClearBox`'s own blank is a font glyph rather than a tile of the
		## screen's art, which is what the cartridge blanks a box with too.
		if code < RomLayout.FONT_FIRST_CODE \
				and code != Gen2MysteryGiftPage.BLANK_CODE:
			highest = maxi(highest, code)
	_r.check(
		highest < tiles,
		"%s: the screen indexes tile %d of %d." % [game_id, highest, tiles]
	)
	## Every cell of the attrmap names a palette the layout copied, which is
	## what says Crystal's second one is reached and Gold's single one is not
	## overrun.
	var banks: int = int(PALETTES[game_id])
	var worst: int = 0
	for attribute: int in page.attributes():
		worst = maxi(worst, attribute)
	_r.check(
		worst < banks,
		"%s: the attrmap names palette %d of %d." % [game_id, worst, banks]
	)
	var image: Image = page.render("")
	if not _r.check(
		image != null and image.get_width() == Gen2MysteryGiftPage.WIDTH \
			and image.get_height() == Gen2MysteryGiftPage.HEIGHT,
		"%s: the Mystery Gift screen did not render at screen size." % game_id
	):
		return PackedByteArray()
	return image.get_data()


## `DoMysteryGift` from the exchange down, once per box it can end on. Each case
## is the same partner with exactly one thing changed, so a chain that tests in
## the wrong order answers the wrong box and fails here.
func _verify_chain(game_id: StringName, data: GameData) -> void:
	var tables: Dictionary = {
		"items": data.mystery_gift_table(false),
		"decos": data.mystery_gift_table(true),
	}
	for case: Array in [
		[Gen2MysteryGift.OUTCOME_SENT, {}, {}],
		## Five partners already today, which is tested before anything else.
		[Gen2MysteryGift.OUTCOME_FIVE_A_DAY,
			{"daily_partners": Gen2MysteryGift.MAX_PARTNERS}, {}],
		## The same person twice, which is the second test.
		[Gen2MysteryGift.OUTCOME_ONE_A_DAY,
			{"partner_ids": [0x1234], "daily_partners": 1}, {}],
		## A gift already waiting at the counter, and then the partner's own.
		[Gen2MysteryGift.OUTCOME_RETRIEVE, {"backup_item": 1}, {}],
		[Gen2MysteryGift.OUTCOME_FRIEND_NOT_READY, {}, {"backup_item": 1}],
		## A decoration nobody has received yet goes home; the same decoration a
		## second time falls through to the item, which is the one branch in the
		## chain that does not end where it started.
		[Gen2MysteryGift.OUTCOME_SENT_HOME, {}, {"sent_deco": 1}],
		[Gen2MysteryGift.OUTCOME_SENT,
			{"decorations_received": [int(tables["decos"][0])]}, {"sent_deco": 1}],
	]:
		var section: Dictionary = Gen2MysteryGift.default_section()
		section["unlocked"] = 0
		section["daily_partners"] = 0
		for key: Variant in case[1] as Dictionary:
			section[key] = (case[1] as Dictionary)[key]
		var partner: Dictionary = PARTNER.duplicate()
		for key: Variant in case[2] as Dictionary:
			partner[key] = (case[2] as Dictionary)[key]
		var transport := Gen2MysteryGiftTransport.new()
		transport.peer = partner
		var result: Dictionary = Gen2MysteryGift.exchange(
			section, transport, PARTNER.duplicate(), tables, data
		)
		_r.check(
			StringName(result.get("outcome", &"")) == StringName(case[0]),
			"%s: the chain answered %s where %s was due." % [
				game_id, result.get("outcome", &""), case[0],
			]
		)
	## A window with nobody in it is a real path: `ExchangeMysteryGiftData`
	## times out and the routine loops back to its own prompt.
	var empty: Dictionary = Gen2MysteryGift.default_section()
	var timed_out: Dictionary = Gen2MysteryGift.exchange(
		empty, Gen2MysteryGiftTransport.new(), PARTNER.duplicate(), tables, data
	)
	_r.check(
		StringName(timed_out.get("outcome", &"")) == Gen2MysteryGift.OUTCOME_COMM_ERROR \
			and bool(timed_out.get("retry", false)),
		"%s: an empty window did not time out into the retry box." % game_id
	)


## The art differs between Crystal and the other two on purpose, and Gold and
## Silver's is the same run at the same address, so their two screens are one
## picture. A difference there would be a wrong pin on one of them.
func _verify_screens_agree(screens: Dictionary) -> void:
	if screens.size() < 3:
		return
	_r.check(
		screens[&"gold"] == screens[&"silver"] \
			and not (screens[&"gold"] as PackedByteArray).is_empty(),
		"Gold and Silver drew different Mystery Gift screens."
	)
	_r.check(
		screens[&"crystal"] != screens[&"gold"],
		"Crystal drew Gold's Mystery Gift screen, which is a wrong pin."
	)


## The live path, which an offline chain cannot reach: the screen is built,
## displayed, and driven with the two buttons the routine has. What it settles
## is that the section the screen edits is the save's, so a gift received here
## is in the file the counter reads and not in a copy of it.
func _verify_live_screen(game_id: StringName, data: GameData) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		_r.fail("%s: no scene tree for the Mystery Gift screen." % game_id)
		return
	var save := Gen2SaveData.new()
	save.player_name = "GOLD"
	Gen2MysteryGift.unlock(save.mystery_gift)
	Gen2MysteryGift.backup(save.mystery_gift)
	var transport := Gen2MysteryGiftTransport.new()
	transport.peer = PARTNER.duplicate()
	var random := RandomNumberGenerator.new()
	random.seed = 11
	var host := Gen2MysteryGiftScreen.new()
	host.set_context(data, save, transport, 30, 0, random)
	tree.root.add_child(host)
	## The screen counts its own frames off the clock in `_process`; this check
	## spends them by hand, the way `tools/preview_*.gd` do.
	host.set_process(false)
	_r.check(
		host.step() == Gen2MysteryGiftScreen.STEP.PROMPT \
			and host.visible_text().is_empty(),
		"%s: the screen did not open on its prompt." % game_id
	)
	host.handle_button(Gen2Button.A)
	host.settle()
	_r.check(
		host.step() == Gen2MysteryGiftScreen.STEP.MESSAGE,
		"%s: the exchange did not finish inside its own timeout." % game_id
	)
	_r.check(
		StringName(host.result().get("outcome", &"")) == Gen2MysteryGift.OUTCOME_SENT,
		"%s: the live exchange answered %s." % [
			game_id, host.result().get("outcome", &""),
		]
	)
	_r.check(
		int(save.mystery_gift["backup_item"]) != 0,
		"%s: the gift did not reach the save the screen was handed." % game_id
	)
	_r.check(
		host.visible_text().contains("KRIS"),
		"%s: the box on screen does not name the partner." % game_id
	)
	host.queue_free()
