extends RefCounted

## Sweeps `_SlotMachine` and `PromptUserToPlaySlots` on real caches. Every
## expectation is transcribed from the sources rather than read back out of the
## implementation, and whole spins on pinned seeds assert what stopped where.

## `Reel1Tilemap`, `Reel2Tilemap` and `Reel3Tilemap`, byte for byte, including
## the first three symbols each repeats behind itself.
const REELS: Array[Array] = [
	[
		0x00, 0x08, 0x14, 0x0C, 0x10, 0x00, 0x08, 0x14, 0x0C, 0x10,
		0x04, 0x08, 0x14, 0x0C, 0x10, 0x00, 0x08, 0x14,
	],
	[
		0x00, 0x0C, 0x08, 0x10, 0x14, 0x04, 0x0C, 0x08, 0x10, 0x14,
		0x04, 0x0C, 0x08, 0x10, 0x14, 0x00, 0x0C, 0x08,
	],
	[
		0x00, 0x0C, 0x08, 0x10, 0x14, 0x0C, 0x08, 0x10, 0x14, 0x0C,
		0x04, 0x08, 0x10, 0x14, 0x0C, 0x00, 0x0C, 0x08,
	],
]

## `Slots_GetPayout.PayoutTable`, in `SLOTS_*` order.
const PAYOUTS: Array[int] = [300, 50, 6, 8, 10, 15]

## `.InitGFX`'s own loads: which tile each run is decompressed to and how many
## tiles it is. `Slots2LZ` is loaded twice, which is why the section carries it
## once and two banks index it.
const SECTION: Dictionary = {"slots_1": 37, "slots_2": 64, "slots_3": 64}

## `Slots_StopReel3`'s two blocks, as (threshold, action) walked in order. The
## first is the one `and a / jr nz, .biased` falls through on, a bias of
## SLOTS_SEVEN, and Chansey is in it alone. The thresholds are `71 percent - 1`,
## `47 percent + 1`, `24 percent - 1`, `63 percent` and `31 percent + 1`.
const REEL3_SEVEN_BIAS: Array[Array] = [[180, 9], [120, 16], [60, 18], [0, 21]]
const REEL3_OTHER_BIAS: Array[Array] = [[160, 9], [80, 16], [0, 18]]

## `Slots_InitBias.Normal` and `.Lucky`, as (threshold, symbol).
const BIAS_NORMAL: Array[Array] = [
	[1, 0x00], [3, 0x04], [10, 0x14], [20, 0x10], [40, 0x0C], [48, 0x08], [255, -1],
]
const BIAS_LUCKY: Array[Array] = [
	[2, 0x00], [3, 0x04], [8, 0x14], [16, 0x10], [30, 0x0C], [80, 0x08], [255, -1],
]

## `MAX_COINS`, and `Slots_AskBet`'s own three items.
const MAX_COINS: int = 9999
const BETS: Array[int] = [1, 2, 3]

## `SlotMachineWheel1` to `3` (data/events/slot_machine_wheels.asm), as bytes.
const GEN1_WHEELS: Array[Array] = [
	[0x00, 0x02, 0x14, 0x16, 0x0C, 0x0E, 0x04, 0x06, 0x08, 0x0A, 0x00, 0x02,
		0x0C, 0x0E, 0x10, 0x12, 0x04, 0x06, 0x08, 0x0A, 0x00, 0x02, 0x14, 0x16,
		0x10, 0x12, 0x04, 0x06, 0x08, 0x0A, 0x00, 0x02, 0x14, 0x16, 0x0C, 0x0E],
	[0x00, 0x02, 0x0C, 0x0E, 0x08, 0x0A, 0x10, 0x12, 0x14, 0x16, 0x04, 0x06,
		0x08, 0x0A, 0x0C, 0x0E, 0x10, 0x12, 0x08, 0x0A, 0x04, 0x06, 0x0C, 0x0E,
		0x10, 0x12, 0x08, 0x0A, 0x14, 0x16, 0x00, 0x02, 0x0C, 0x0E, 0x08, 0x0A],
	[0x00, 0x02, 0x10, 0x12, 0x0C, 0x0E, 0x08, 0x0A, 0x14, 0x16, 0x10, 0x12,
		0x0C, 0x0E, 0x08, 0x0A, 0x14, 0x16, 0x10, 0x12, 0x0C, 0x0E, 0x08, 0x0A,
		0x14, 0x16, 0x10, 0x12, 0x04, 0x06, 0x00, 0x02, 0x10, 0x12, 0x0C, 0x0E],
]
## `SlotRewardPointers`' six routines: the coins and the flash count each returns.
const GEN1_REWARDS: Array[int] = [300, 100, 8, 15, 15, 15]
const GEN1_FLASHES: Array[int] = [0x14, 0x08, 0x02, 0x04, 0x04, 0x04]
## `BlkPacket_Slots`' five `ATTR_BLK_DATA` rows.
const GEN1_BLOCKS: Array[Array] = [
	[3, 0x05, 0, 0, 19, 11], [3, 0x0A, 0, 4, 19, 9], [2, 0x0F, 0, 6, 19, 7],
	[3, 0x00, 4, 4, 15, 9], [3, 0x00, 0, 12, 19, 17],
]
## `SlotMachineTiles1`, `SlotMachineTiles2` and `SlotMachineMap` by size.
const GEN1_SHEETS: Dictionary = {"slots_1": 37, "slots_2": 24}
const GEN1_TILEMAP_CELLS: int = 12 * 20
const GEN1_TEXTS: Dictionary = {
	"play": "A slot machine!", "out_of_coins": "Darn!", "bet": "Bet how many",
	"start": "Start!", "not_enough_coins": "Not enough", "one_more_go": "One more ",
	"lined_up": " lined up!", "not_this_time": "Not this time!", "yeah": "Yeah!",
}
## Twenty free passes, a slip of four a wheel, four rerolls and a 300-coin
## payout at eight frames a coin; the presses are spaced so one lands on a
## wheel still slipping as often as on one that has stopped.
const GEN1_SPIN_FRAME_CAP: int = 3200
const GEN1_PRESS_GAP: int = 7

## How many spins a sweep drives per cartridge, and how long one is given to
## reach its own end. A spin is three A presses and a payout animation of up to
## three hundred coins, which is `PAYOUTS[0]` times the two frames each takes.
const SPINS: int = 64
const SPIN_FRAME_CAP: int = 2400

var _r: RefCounted = null


func run(r: RefCounted) -> void:
	_r = r
	_verify_tables()
	for game_id: StringName in _r.GAME_IDS:
		var data: GameData = GameData.open(game_id)
		if data == null:
			_r.fail("%s cache is unavailable. Import roms/%s.gbc first." % [game_id, game_id])
			continue
		_r.game_id = game_id
		if not _r.check(data.has_slots(), "%s: no slot machine art in the cache." % game_id):
			continue
		_verify_section(game_id, data)
		_verify_strips(game_id, data)
		_verify_text(game_id, data)
		_verify_spins(game_id, data)
	_r.game_id = &""
	_verify_gen1_tables()
	_r.each_game_of(RomRegistry.GEN1, _gen1_game)


func _verify_tables() -> void:
	_r.check(
		Array(Gen2SlotMachine.PAYOUTS) == PAYOUTS,
		"the payout table is not `Slots_GetPayout.PayoutTable`."
	)
	_r.check(
		Gen2SlotMachine.BIAS_NORMAL == BIAS_NORMAL,
		"the normal bias table is not `Slots_InitBias.Normal`."
	)
	_r.check(
		Gen2SlotMachine.BIAS_LUCKY == BIAS_LUCKY,
		"the lucky bias table is not `Slots_InitBias.Lucky`."
	)
	_verify_reel3_rolls()


## Every byte `Random` can answer, against a second reading of the two blocks.
func _verify_reel3_rolls() -> void:
	for symbol: int in [0x00, 0x04, 0x08, 0x0C, 0x10, 0x14, -1]:
		var rows: Array[Array] = REEL3_SEVEN_BIAS if symbol == 0 else REEL3_OTHER_BIAS
		for roll: int in 256:
			var want: int = 0
			for row: Array in rows:
				if roll >= int(row[0]):
					want = int(row[1])
					break
			var got: int = Gen2SlotMachine.reel3_action(symbol, roll)
			if got == want:
				continue
			_r.fail(
				"`Slots_StopReel3` on bias %d roll %d answers %d, not %d."
				% [symbol, roll, got, want]
			)
			return


func _verify_section(game_id: StringName, data: GameData) -> void:
	var rom: RomFile = RomFile.open_verified("res://roms/%s.gbc" % game_id)
	if not _r.check(rom != null, "%s: roms/%s.gbc is unreadable." % [game_id, game_id]):
		return
	var section: Dictionary = RomImporter.read_slots_section(rom, Gen2Layout.for_id(rom.id))
	if not _r.check(
		section.size() == Gen2Layout.SLOTS_SECTION.size(),
		"%s: the slots section walked %d records, not %d." % [
			game_id, section.size(), Gen2Layout.SLOTS_SECTION.size()
		]
	):
		return
	for name: String in SECTION:
		var tiles: int = int(SECTION[name])
		_r.check(
			int(section[name].size()) == tiles * PokeTiles.TILE_BYTES,
			"%s: %s is %d bytes, not %d tiles." % [
				game_id, name, section[name].size(), tiles
			]
		)
		_r.check(
			data.slots_indices(name) == PokeTiles.decode_2bpp_strip(
				section[name], 0, tiles
			),
			"%s: the cached %s strip is not the dump's." % [game_id, name]
		)
	_r.check(
		Array(data.slots_tilemap()) == Array(section["tilemap"]),
		"%s: the cached tilemap is not `SlotsTilemap`." % game_id
	)
	_r.note("%s: %d slots records, %d tiles, %d tilemap cells." % [
		game_id, SECTION.size(), 37 + 64 + 64, data.slots_tilemap().size()
	])


func _verify_strips(game_id: StringName, data: GameData) -> void:
	for reel: int in REELS.size():
		_r.check(
			Array(data.slots_reel(reel)) == REELS[reel],
			"%s: reel %d is not `Reel%dTilemap`." % [game_id, reel + 1, reel + 1]
		)
	for index: int in Gen2Layout.SLOTS_PALETTES:
		_r.check(
			data.slots_palette(index).size() == Gen2Layout.PREDEF_PALETTE_COLORS,
			"%s: palette %d is not four colours." % [game_id, index]
		)
	var page: Gen2SlotMachinePage = Gen2SlotMachinePage.from_data(data)
	if not _r.check(page != null and page.ready(), "%s: the page will not build." % game_id):
		return
	## `_CGB_SlotMachine`'s own attrmap: the text region is the whole of the six
	## rows under the machine and nothing above them is palette 7.
	var slots: PackedInt32Array = page.attributes()
	var text_cells: int = 0
	for cell: int in slots.size():
		if slots[cell] == Gen2SlotMachinePage.TEXT_PALETTE:
			text_cells += 1
	_r.check(
		text_cells == 6 * Gen2SlotMachinePage.SCREEN_COLUMNS,
		"%s: %d cells are on the text palette, not 120." % [game_id, text_cells]
	)


## The seven boxes, each of which has to have decoded out of a `text_far` stub.
func _verify_text(game_id: StringName, data: GameData) -> void:
	for name: String in Gen2Layout.slots_text_names():
		_r.check(
			not data.slots_text(name).is_empty(),
			"%s: the %s box is empty." % [game_id, name]
		)
	_r.check(
		data.slots_text("bet_how_many").begins_with("Bet how many"),
		"%s: the bet box is not `_SlotsBetHowManyCoinsText`." % game_id
	)


## Whole spins on a pinned seed, every bet and both machines, against the
## source's own arithmetic rather than a pinned outcome: the coins the bet took,
## the payout the match is worth, and a match really lined up on a paid row.
func _verify_spins(game_id: StringName, data: GameData) -> void:
	var spins: int = 0
	var wins: int = 0
	var biased: int = 0
	for spin: int in SPINS:
		var rng := RandomNumberGenerator.new()
		rng.seed = spin
		var strips: Array[PackedByteArray] = []
		for reel: int in Gen2SlotMachine.REELS:
			strips.append(data.slots_reel(reel))
		var machine: Gen2SlotMachine = Gen2SlotMachine.create(
			strips, 200, spin % 2 == 1, rng
		)
		var bet: int = BETS[spin % BETS.size()]
		var before: int = machine.coins()
		if not _drive_spin(machine, bet):
			_r.fail("%s: spin %d never reached its payout." % [game_id, spin])
			return
		spins += 1
		if machine.bias() != Gen2SlotMachine.SLOTS_NO_BIAS:
			biased += 1
		var matched: int = machine.matched()
		var payout: int = 0 if matched == Gen2SlotMachine.SLOTS_NO_MATCH \
			else PAYOUTS[matched / 4]
		if payout > 0:
			wins += 1
		if not _r.check(
			machine.coins() == mini(before - bet + payout, MAX_COINS),
			"%s: spin %d paid %d coins for a %s match." % [
				game_id, spin, machine.coins() - before + bet, matched
			]
		):
			return
		if not _verify_window(game_id, spin, machine, bet, matched):
			return
	_r.note("%s: %d spins, %d biased, %d matched." % [game_id, spins, biased, wins])


## One spin: the bet menu, the three A presses and the payout, with no host and
## so no `WaitSFX` to wait on.
func _drive_spin(machine: Gen2SlotMachine, bet: int) -> bool:
	var frames: int = 0
	while frames < SPIN_FRAME_CAP:
		frames += 1
		if machine.waiting_for_sfx():
			machine.sfx_finished()
			continue
		match machine.prompt():
			Gen2SlotMachine.Prompt.BET:
				machine.answer_bet(4 - bet)
				continue
			Gen2SlotMachine.Prompt.TEXT:
				machine.dismiss_text()
				continue
			Gen2SlotMachine.Prompt.PRESS:
				## `SlotsAction_RestartOrQuit`, which is as far as a spin goes.
				return true
			Gen2SlotMachine.Prompt.PLAY_AGAIN:
				machine.answer_play_again(false)
				continue
			_:
				pass
		if machine.jumptable_index() in [
			Gen2SlotMachine.SLOTS_WAIT_REEL1, Gen2SlotMachine.SLOTS_WAIT_REEL2,
			Gen2SlotMachine.SLOTS_WAIT_REEL3,
		]:
			machine.press_a()
		if not machine.advance():
			return true
	return false


## Every reel standing on a symbol of its own strip, and the match the machine
## reported really lined up on a row this bet paid for.
func _verify_window(
	game_id: StringName, spin: int, machine: Gen2SlotMachine, bet: int, matched: int
) -> bool:
	var windows: Array[PackedByteArray] = []
	for reel: Gen2SlotMachine.Reel in machine.reels():
		var window: PackedByteArray = reel.window()
		if not _r.check(
			window.size() == 3,
			"%s: spin %d left a reel with no window." % [game_id, spin]
		):
			return false
		for symbol: int in window:
			if not _r.check(
				symbol in [0x00, 0x04, 0x08, 0x0C, 0x10, 0x14],
				"%s: spin %d stopped on symbol %d." % [game_id, spin, symbol]
			):
				return false
		windows.append(window)
	if matched == Gen2SlotMachine.SLOTS_NO_MATCH:
		return true
	## `Slots_CheckMatchedAllThreeReels`' own five rows, in the order the bet
	## reaches them: the middle row for one coin, the outer two for two, and the
	## diagonals for three.
	var lines: Array[Array] = [[1, 1, 1]]
	if bet >= 2:
		lines.append([0, 0, 0])
		lines.append([2, 2, 2])
	if bet >= 3:
		lines.append([0, 1, 2])
		lines.append([2, 1, 0])
	for line: Array in lines:
		if windows[0][int(line[0])] == matched and windows[1][int(line[1])] == matched \
			and windows[2][int(line[2])] == matched:
			return true
	return _r.check(
		false,
		"%s: spin %d reported a %d match no row of a %d-coin bet carries." % [
			game_id, spin, matched, bet
		]
	)


func _verify_gen1_tables() -> void:
	_r.check(Array(Gen1SlotMachine.REWARDS) == GEN1_REWARDS,
		"the Generation 1 reward table is not `SlotRewardPointers`.")
	_r.check(Array(Gen1SlotMachine.FLASHES) == GEN1_FLASHES,
		"the Generation 1 flash counts are not `SlotReward*Func`'s.")


func _gen1_game() -> void:
	var data: GameData = _r.data
	if not _r.check(data.has_slots(), "no slot machine art in the cache."):
		return
	for wheel: int in GEN1_WHEELS.size():
		_r.check(Array(data.slots_reel(wheel)) == GEN1_WHEELS[wheel],
			"wheel %d is not `SlotMachineWheel%d`." % [wheel + 1, wheel + 1])
	_r.check(data.slots_tilemap().size() == GEN1_TILEMAP_CELLS,
		"`SlotMachineMap` is %d cells." % data.slots_tilemap().size())
	var blocks: Array = []
	for row: Variant in data.slots_blocks():
		blocks.append(Array(row).map(func(byte: Variant) -> int: return int(byte)))
	_r.check(blocks == GEN1_BLOCKS, "`BlkPacket_Slots` read %s." % [blocks])
	for index: int in Gen1Layout.PAL_SET_PALETTES:
		_r.check(data.slots_palette(index).size() == Gen1Layout.SUPER_PALETTE_COLORS,
			"palette %d is not four colours." % index)
	for sheet: String in GEN1_SHEETS:
		_r.check(int(data.tile_sheet(sheet).get("tiles", 0)) == int(GEN1_SHEETS[sheet]),
			"%s is not %d tiles." % [sheet, int(GEN1_SHEETS[sheet])])
	for name: String in GEN1_TEXTS:
		_r.check(data.slots_text(name).begins_with(String(GEN1_TEXTS[name])),
			"the %s box reads %s." % [name, data.slots_text(name)])
	_verify_gen1_screen(data)
	_verify_gen1_spins(data)


## The first frame the machine shows: `SlotMachineMap`, the bet line, the objects.
func _verify_gen1_screen(data: GameData) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var machine: Gen1SlotMachine = Gen1SlotMachine.create_gen1(data, 50, false, rng)
	for _frame: int in Gen1SlotMachine.WHITE_OUT_FRAMES + 1:
		machine.advance()
	_r.check(machine.prompt() == Gen2SlotMachine.Prompt.BET,
		"the machine did not open on the bet menu.")
	var map: PackedByteArray = machine.lcd.maps[0]
	var tilemap: PackedByteArray = data.slots_tilemap()
	var drawn: bool = true
	for row: int in Gen1Layout.SLOTS_TILEMAP_ROWS:
		for column: int in Gen1Layout.SCREEN_WIDTH_TILES:
			var cell: Vector2i = Vector2i(column, row)
			## The two counts are printed over the map's own row 1, and the bet
			## box's top edge over its row 11.
			if row == 1 and column >= Gen1SlotMachine.CREDIT_AT.x \
				and column < Gen1SlotMachine.PAYOUT_AT.x + Gen1SlotMachine.DIGITS:
				continue
			if row == Gen1SlotMachine.BET_BOX_AT.y and column >= Gen1SlotMachine.BET_BOX_AT.x:
				continue
			drawn = drawn and map[row * Gen1Lcd.MAP_SIDE + column] \
				== tilemap[row * Gen1Layout.SCREEN_WIDTH_TILES + column]
			if not drawn:
				_r.fail("cell %s is not `SlotMachineMap`'s." % cell)
				return
	_r.check(_gen1_cells(machine, Gen1SlotMachine.CREDIT_AT, 4) == Gen1Text.encode("0050"),
		"the credit reads %s." % [_gen1_cells(machine, Gen1SlotMachine.CREDIT_AT, 4)])
	_r.check(_gen1_cells(machine, Gen1SlotMachine.TEXT_AT, 12) == Gen1Text.encode("Bet how many"),
		"the bet line is not up.")
	_r.check(_gen1_cells(machine, Vector2i(15, 12), 3) == Gen1Text.encode("▶×3"),
		"the bet cursor is not on ×3.")
	var page: Gen2SlotMachinePage = Gen2SlotMachinePage.from_data(data)
	var image: Image = page.render(machine) if page != null else null
	_r.check(image != null and image.get_width() == Gen1Lcd.WIDTH
		and image.get_height() == Gen1Lcd.HEIGHT, "the page will not render.")
	_verify_gen1_objects(machine)


## `SlotMachine_AnimWheel`'s objects, each row the next byte behind the offset.
func _verify_gen1_objects(machine: Gen1SlotMachine) -> void:
	var offsets: PackedInt32Array = machine.wheel_offsets()
	for wheel: int in Gen1Layout.SLOTS_WHEELS:
		var drawn: int = (int(offsets[wheel]) + Gen1SlotMachine.WHEEL_WRAP - 1) \
			% Gen1SlotMachine.WHEEL_WRAP
		for row: int in Gen1SlotMachine.WHEEL_ROWS:
			var left: Dictionary = machine.lcd.sprite(wheel * Gen1SlotMachine.WHEEL_OAM_SLOTS + row * 2)
			var right: Dictionary = machine.lcd.sprite(wheel * Gen1SlotMachine.WHEEL_OAM_SLOTS + row * 2 + 1)
			var tile: int = int(GEN1_WHEELS[wheel][drawn + row])
			var y: int = Gen1SlotMachine.WHEEL_BASE_Y - row * Gen1Lcd.TILE
			if not _r.check(
				int(left["y"]) == y and int(right["y"]) == y
				and int(left["x"]) == Gen1SlotMachine.WHEEL_X[wheel]
				and int(right["x"]) == Gen1SlotMachine.WHEEL_X[wheel] + Gen1Lcd.TILE
				and int(left["tile"]) == tile and int(right["tile"]) == tile + 1
				and int(left["attributes"]) == Gen1Lcd.OAM_PRIO,
				"wheel %d row %d draws %s %s at offset %d." % [wheel + 1, row, left, right, drawn]
			):
				return


func _gen1_cells(machine: Gen1SlotMachine, at: Vector2i, count: int) -> PackedByteArray:
	var out := PackedByteArray()
	for index: int in count:
		out.append(machine.lcd.maps[0][at.y * Gen1Lcd.MAP_SIDE + at.x + index])
	return out


## Whole spins on pinned seeds: the bet leaves the purse, every wheel stops on
## an odd offset, and a payout is for a symbol really on a line the bet paid for.
func _verify_gen1_spins(data: GameData) -> void:
	var wins: int = 0
	var paid: int = 0
	var seven_bar: int = 0
	for spin: int in SPINS:
		var rng := RandomNumberGenerator.new()
		rng.seed = spin
		var machine: Gen1SlotMachine = Gen1SlotMachine.create_gen1(data, 200, spin % 2 == 1, rng)
		var bet: int = BETS[spin % BETS.size()]
		if not _drive_gen1_spin(machine, bet, spin):
			_r.fail("spin %d never reached its end." % spin)
			return
		var offsets: PackedInt32Array = machine.wheel_offsets()
		for wheel: int in offsets.size():
			if not _r.check(int(offsets[wheel]) & 1 == 1,
				"spin %d stopped wheel %d on offset %d." % [spin, wheel + 1, int(offsets[wheel])]):
				return
		var symbol: int = _gen1_lined_up(offsets, bet)
		var winning: int = machine.winning_symbol()
		var payout: int = 0 if winning < 0 else GEN1_REWARDS[winning / 4]
		if winning >= 0:
			wins += 1
			paid += payout
			if winning < Gen1SlotMachine.SEVEN_OR_BAR_LIMIT:
				seven_bar += 1
			if not _r.check(symbol - Gen1SlotMachine.SYMBOL_ID_OFFSET == winning,
				"spin %d paid symbol %d with %d lined up." % [spin, winning, symbol]):
				return
		elif not _r.check(symbol < 0 or machine.flags() == 0,
			"spin %d lined up %d under flags %d and paid nothing." % [spin, symbol, machine.flags()]):
			return
		if not _r.check(machine.coins() == 200 - bet + payout,
			"spin %d left %d coins on a bet of %d paying %d." % [spin, machine.coins(), bet, payout]):
			return
	_r.note("%d spins, %d matched, %d sevens or bars, %d coins paid." % [SPINS, wins, seven_bar, paid])


func _drive_gen1_spin(machine: Gen1SlotMachine, bet: int, spin: int) -> bool:
	var frames: int = 0
	var presses: int = 0
	var since_press: int = 0
	while frames < GEN1_SPIN_FRAME_CAP:
		frames += 1
		if machine.waiting_for_sfx():
			machine.sfx_finished()
			continue
		match machine.prompt():
			Gen2SlotMachine.Prompt.BET:
				machine.answer_bet(4 - bet)
				continue
			Gen2SlotMachine.Prompt.TEXT:
				machine.dismiss_text()
				continue
			Gen2SlotMachine.Prompt.PLAY_AGAIN:
				return true
			_:
				pass
		if machine.state() == Gen1SlotMachine.State.OUT_OF_COINS:
			return true
		if machine.state() == Gen1SlotMachine.State.SPIN and presses < 3:
			since_press += 1
			if since_press >= GEN1_PRESS_GAP + spin % 3:
				machine.press_a()
				presses += 1
				since_press = 0
		if not machine.advance():
			return true
	return false


## `SlotMachine_CheckForMatches`' lines, read off the tables here: the symbol, or -1.
func _gen1_lined_up(offsets: PackedInt32Array, bet: int) -> int:
	var windows: Array = []
	for wheel: int in GEN1_WHEELS.size():
		var rows: Array = []
		for row: int in 3:
			rows.append(int(GEN1_WHEELS[wheel][int(offsets[wheel]) + row * 2]))
		windows.append(rows)
	var lines: Array = [[1, 1, 1]]
	if bet >= 2:
		lines = [[2, 2, 2], [0, 0, 0]] + lines
	if bet == 3:
		lines = [[0, 1, 2], [2, 1, 0]] + lines
	for line: Array in lines:
		var symbol: int = int(windows[0][int(line[0])])
		if int(windows[1][int(line[1])]) == symbol and int(windows[2][int(line[2])]) == symbol:
			return symbol
	return -1
