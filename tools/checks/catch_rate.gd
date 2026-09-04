extends RefCounted

var _r: RefCounted = null

## `wFinalCatchRate` on all three cartridges, against what the cartridges
## themselves answered. `PokeBallEffect` settles the whole catch rate before it
## rolls, so the answer is a pure function of eleven bytes and can be asked of a
## real dump directly; running the same rolls on hardware prints one line per
## case and this topic builds the same 4,779 here. The sweep is the whole corpus:
## every species against every ball, every byte boundary of the health term against
## every status bit, and Level Ball's whole ladder. What is pinned is the digest
## plus the rows below, which name the branch each one proves.

## `data/items/apricorn_balls.asm` and the four ordinary ones. MASTER_BALL is not
## here: it never reaches the multiplier table.
const BALLS: Array[int] = [0x05, 0x04, 0x02, 0x9D, 0x9F, 0xA0, 0xA1, 0xA4, 0xA5, 0xA6]

## The health pairs the sweep uses. 85 is the last max HP whose `3 * max` fits in
## a byte, 341 is the documented cliff, and 342 is where the shifted divisor's
## low byte reaches zero.
const HEALTH: Array = [
	[20, 20], [20, 10], [20, 1], [85, 85], [85, 43], [85, 1],
	[86, 86], [86, 43], [86, 1], [100, 100], [100, 50], [100, 1],
	[200, 200], [200, 100], [200, 1], [255, 255], [255, 128], [255, 1],
	[341, 341], [341, 171], [341, 1], [342, 342], [342, 171], [342, 1],
	[400, 400], [400, 200], [400, 1], [703, 703], [703, 352], [703, 1],
]
## A sleep count of 1, 3 and 7, then PSN, BRN, FRZ and PAR one bit at a time.
const STATUSES: Array[int] = [0, 1, 3, 7, 8, 16, 32, 64]
const RATES: Array[int] = [1, 3, 25, 45, 90, 120, 190, 255]
const LEVELS: Array[int] = [1, 3, 5, 10, 20, 50, 100]
const PLAYER_LEVELS: Array[int] = [1, 5, 10, 20, 40, 80, 100]

## SHA-1 of the whole sweep, one digest per cartridge, taken from a run that
## agreed with the dump case for case. Re-earn it with
## `venv/bin/python battle/catch_rate.py <game> /tmp/cart_catch_<game>.txt`
## rather than by copying whatever this prints.
const DIGESTS: Dictionary = {
	&"crystal": "b4baef4d9894675f3620862c7591b3c16d8b9377",
	&"gold": "32d91f998347f09f67f15c65098cc112907b699d",
	&"silver": "32d91f998347f09f67f15c65098cc112907b699d",
}

## What each pinned row proves, and the rate the cartridge answered.
## [ball, species, base rate, max HP, current HP, status, wild level,
##  player level, fishing] -> final rate.
const PINNED: Array = [
	# The health term with nothing else on it, on both sides of the byte
	# boundary at 85 max HP: `3 * 86` no longer fits and both operands shift.
	[[0x05, 25, 255, 85, 85, 0, 10, 50, 0], 85],
	[[0x05, 25, 255, 85, 1, 0, 10, 50, 0], 253],
	[[0x05, 25, 255, 86, 86, 0, 10, 50, 0], 83],
	[[0x05, 25, 255, 86, 1, 0, 10, 50, 0], 251],
	# Sleep and freeze add ten; the +5 the other three were meant to add never
	# runs, which is the whole of "BRN/PSN/PAR do not affect catch rate".
	[[0x05, 25, 45, 100, 50, 0, 10, 50, 0], 30],
	[[0x05, 25, 45, 100, 50, 3, 10, 50, 0], 40],
	[[0x05, 25, 45, 100, 50, 32, 10, 50, 0], 40],
	[[0x05, 25, 45, 100, 50, 8, 10, 50, 0], 30],
	[[0x05, 25, 45, 100, 50, 16, 10, 50, 0], 30],
	[[0x05, 25, 45, 100, 50, 64, 10, 50, 0], 30],
	# Past 341 max HP the shifted divisor stops fitting too, and a wild at full
	# health then reads as easier to catch than one at half.
	[[0x05, 25, 255, 341, 341, 0, 10, 50, 0], 85],
	[[0x05, 25, 255, 400, 400, 0, 10, 50, 0], 67],
	[[0x05, 25, 255, 400, 200, 0, 10, 50, 0], 135],
	[[0x04, 25, 100, 100, 100, 0, 10, 50, 0], 50],  # Great and Ultra.
	[[0x02, 25, 100, 100, 100, 0, 10, 50, 0], 66],
	[[0xA0, 25, 100, 100, 100, 0, 10, 50, 0], 33],  # Lure Ball, which is three times the rate and only on a rod battle.
	[[0xA0, 25, 100, 100, 100, 0, 10, 50, 1], 85],
	[[0xA1, 81, 100, 100, 100, 0, 10, 50, 0], 85],  # Fast Ball, whose list is three species long: MAGNEMITE against MR. MIME.
	[[0xA1, 122, 100, 100, 100, 0, 10, 50, 0], 33],
	[[0xA5, 30, 100, 100, 100, 0, 10, 50, 0], 33],  # Moon Ball never boosts anything, NIDORINA included.
	# Love Ball boosts a matching gender rather than a differing one, and
	# answers nothing for a genderless species. Both DVs are $FFFF here, so
	# both sides are male wherever the ratio allows one.
	[[0xA6, 25, 100, 100, 100, 0, 10, 50, 0], 85],
	[[0xA6, 201, 100, 100, 100, 0, 10, 50, 0], 33],
	[[0xA4, 25, 100, 100, 100, 0, 10, 50, 0], 33],  # Friend Ball has no multiplier row at all: its effect is the happiness.
	# Level Ball skips the health term outright, so its answer is the multiplied
	# rate: eight times under a quarter of the player's level, then four, then
	# two, then nothing once the wild has caught up.
	[[0x9F, 25, 45, 100, 100, 0, 5, 40, 0], 255],
	[[0x9F, 25, 45, 100, 100, 0, 10, 40, 0], 180],
	[[0x9F, 25, 45, 100, 100, 0, 20, 40, 0], 90],
	[[0x9F, 25, 45, 100, 100, 0, 50, 40, 0], 45],
	[[0x9D, 25, 100, 100, 100, 0, 10, 50, 0], 26],  # Heavy Ball: twenty off a light species, forty onto SNORLAX.
	[[0x9D, 143, 100, 100, 100, 0, 10, 50, 0], 46],
]

## `docs/bugs_and_glitches.md`'s three wrong-bank species, whose Heavy Ball
## answer differs between the profiles. SUNFLORA is not here: the cartridge does
## not answer at all.
const PINNED_CRYSTAL: Array = [
	[[0x9D, 64, 100, 100, 100, 0, 10, 50, 0], 40],
	[[0x9D, 128, 100, 100, 100, 0, 10, 50, 0], 46],
]
const PINNED_GOLD: Array = [
	[[0x9D, 64, 100, 100, 100, 0, 10, 50, 0], 26],
	[[0x9D, 128, 100, 100, 100, 0, 10, 50, 0], 26],
]

## The two max HP values whose shifted divisor is a whole multiple of 256, where
## `_Divide` never leaves its loop: the cartridge locks up rather than answering,
## so nothing here can be pinned against a dump. What is checked instead is that
## the guard is live and the divisor it falls back on is the untruncated one.
## [max HP, current HP] -> the rate a base of 255 answers with.
const DIVIDE_BY_ZERO: Array = [
	[[342, 342], 84], [[342, 171], 170], [[683, 683], 85], [[683, 342], 169],
]


func run(r: RefCounted) -> void:
	_r = r
	for game_id: StringName in _r.GAME_IDS:
		var data: GameData = GameData.open(game_id)
		if data == null:
			_r.fail("%s cache is unavailable. Import roms/%s.gbc first." % [game_id, game_id])
			continue
		var crystal: bool = Gen2WorldState.is_crystal_profile(data)
		for row: Array in PINNED:
			_verify(game_id, data, row[0] as Array, int(row[1]))
		for row: Array in (PINNED_CRYSTAL if crystal else PINNED_GOLD):
			_verify(game_id, data, row[0] as Array, int(row[1]))
		for row: Array in DIVIDE_BY_ZERO:
			var pair: Array = row[0]
			_verify(game_id, data, [
				0x05, 25, 255, int(pair[0]), int(pair[1]), 0, 10, 50, 0,
			], int(row[1]))
		_verify_sweep(game_id, data)


## Every case the oracle runs, hashed. The digest is what makes this the whole
## corpus rather than the rows above.
func _verify_sweep(game_id: StringName, data: GameData) -> void:
	var lines: PackedStringArray = PackedStringArray()
	for species: int in range(1, Gen2Layout.SPECIES_COUNT + 1):
		for ball: int in BALLS:
			lines.append(_line(data, [ball, species, 100, 100, 100, 0, 10, 50, 0]))
			if ball == 0xA0:
				lines.append(_line(data, [ball, species, 100, 100, 100, 0, 10, 50, 1]))
	for rate: int in RATES:
		for pair: Array in HEALTH:
			for status: int in STATUSES:
				lines.append(_line(
					data, [0x05, 25, rate, int(pair[0]), int(pair[1]), status, 10, 50, 0]
				))
	for player: int in PLAYER_LEVELS:
		for wild: int in LEVELS:
			for rate: int in [45, 190]:
				lines.append(_line(data, [0x9F, 25, rate, 100, 100, 0, wild, player, 0]))
	var digest: String = ("\n".join(lines) + "\n").sha1_text()
	var expected: String = String(DIGESTS.get(game_id, ""))
	if expected.is_empty():
		_r.fail("%s: no pinned digest for the sweep. It answered %s." % [game_id, digest])
		return
	if digest != expected:
		_r.fail("%s: the %d-case sweep is %s, pinned %s." % [
			game_id, lines.size(), digest, expected,
		])


func _verify(game_id: StringName, data: GameData, case: Array, expected: int) -> void:
	var answered: int = _rate(data, case)
	if answered != expected:
		_r.fail("%s: %s answered %d, the cartridge %d." % [
			game_id, str(case), answered, expected,
		])


func _line(data: GameData, case: Array) -> String:
	return "%s -> %d" % [" ".join(case.map(func(v: int) -> String: return str(v))), _rate(data, case)]


func _rate(data: GameData, case: Array) -> int:
	return Gen2WorldPartyHost.final_catch_rate(data, int(case[0]), {
		"base_rate": int(case[2]),
		"max_hp": int(case[3]),
		"current_hp": int(case[4]),
		"status": int(case[5]),
		"species": int(case[1]),
		"dvs": 0xFFFF,
		"level": int(case[6]),
		"thrower_species": int(case[1]),
		"thrower_dvs": 0xFFFF,
		"thrower_level": int(case[7]),
		"battle_type": Gen2Battle.BATTLETYPE_FISH if int(case[8]) == 1 \
			else Gen2Battle.BATTLETYPE_NORMAL,
	})
