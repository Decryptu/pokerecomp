extends RefCounted

## `ItemUseBall` on Red, Blue and Yellow, against what the cartridges themselves
## answered. The throw is a pure function of five WRAM bytes and the two numbers
## `call Random` gives it, so the oracle's `battle/gen1_catch.py` drives the
## routine on a real dump and prints the `wPokeBallAnimData` it wrote;
## [method _oracle_sweep] prints the same 2,312 lines. All three cartridges
## answer identically. The corpus sweep beside it runs every species' imported
## catch rate through every ball.

## `ItemUsePtrTable`'s ball rows and what `ItemNames` calls them.
const BALL_NAMES: Dictionary = {
	0x01: "MASTER BALL", 0x02: "ULTRA BALL", 0x03: "GREAT BALL",
	0x04: "POKé BALL", 0x08: "SAFARI BALL",
}

## What Crystal's numbering reads as on a Generation 1 cache.
const GEN2_NUMBERING_READS: Dictionary = {
	Gen2WorldPartyHost.ITEM_POKE_BALL: "TOWN MAP",
	Gen2WorldPartyHost.ITEM_GREAT_BALL: "POKé BALL",
}

## `wPokeBallAnimData`: the high nybble is how many of `.PokeBallAnimations`
## play, the low nybble the rocks. $43 is `.canUseBall`'s preset, which the
## captured path never writes over.
const ANIM_CAUGHT: int = 0x43
const ANIM_MISSED: int = 0x20
const ANIM_SHOOK_BASE: int = 0x60

## The oracle's case list in its own order, so the two files diff line for line.
## A Rand1 over the ball's ceiling would spend a third `Random`.
const ORACLE_BALLS: Array[int] = [0x04, 0x03, 0x02, 0x08]
const ORACLE_CEILINGS: Dictionary = {0x04: 255, 0x03: 200, 0x02: 150, 0x08: 150}
const ORACLE_ROLLS: Array[int] = [
	0, 1, 11, 12, 24, 25, 60, 100, 149, 150, 199, 200, 254, 255,
]
const ORACLE_RATES: Array[int] = [1, 3, 25, 45, 90, 120, 190, 255]
const ORACLE_SECOND: Array[int] = [0, 63, 128, 255]
const ORACLE_HEALTH: Array = [
	[1, 1], [3, 1], [4, 4], [4, 1], [20, 20], [20, 10], [20, 1],
	[85, 85], [85, 43], [85, 1], [86, 86], [86, 1], [100, 100], [100, 50],
	[255, 255], [255, 128], [255, 1], [341, 341], [341, 1],
	[342, 342], [342, 1], [400, 400], [400, 1], [703, 703], [703, 1],
	[999, 999], [999, 500], [999, 1],
]
const ORACLE_STATUSES: Array[int] = [0, 1, 3, 7, 8, 16, 32, 64]
const ORACLE_HEAD: String = "ball rate maxhp curhp status rand1 rand2 -> animdata"

## SHA-1 of the file the oracle writes, which all three cartridges produce byte
## for byte. Re-earn it with `venv/bin/python battle/gen1_catch.py red <out>`
## rather than by copying whatever this prints.
const ORACLE_DIGEST: String = "f339a8a5578a88520ad742ad69a43d04bb855daf"

## What each pinned row proves, and the byte the cartridge wrote.
## [ball, rate, max HP, current HP, status, Rand1, Rand2] -> `wPokeBallAnimData`.
const PINNED: Array = [
	# `.loop`'s ceilings: 255, 200 and the 150 an Ultra or a Safari Ball takes.
	[[0x04, 255, 100, 50, 0, 255, 0], ANIM_CAUGHT],
	[[0x03, 255, 100, 50, 0, 200, 0], ANIM_CAUGHT],
	[[0x02, 255, 100, 50, 0, 150, 0], ANIM_CAUGHT],
	[[0x08, 255, 100, 50, 0, 150, 0], ANIM_CAUGHT],
	# A roll under the status term is caught outright: 25 asleep, 12 poisoned.
	[[0x04, 45, 100, 100, 3, 24, 255], ANIM_CAUGHT],
	[[0x04, 45, 100, 100, 3, 25, 255], ANIM_SHOOK_BASE + 1],
	[[0x04, 45, 100, 100, 8, 11, 255], ANIM_CAUGHT],
	[[0x04, 45, 100, 100, 8, 12, 255], ANIM_SHOOK_BASE + 1],
	[[0x04, 190, 100, 100, 32, 0, 255], ANIM_CAUGHT],
	# `.addAilmentValue` moves the same throw off the bottom of the ladder.
	[[0x04, 45, 100, 100, 0, 12, 255], ANIM_MISSED],
	[[0x04, 190, 100, 100, 0, 0, 255], ANIM_SHOOK_BASE + 1],
	# W over 255 is caught with no second roll: one HP floors to `ld c, $1`.
	[[0x04, 255, 999, 1, 0, 60, 0], ANIM_CAUGHT],
	[[0x03, 255, 100, 50, 0, 60, 255], ANIM_CAUGHT],
	# BallFactor2 is 255 and 200, one more rock out of a Great Ball at every rung.
	[[0x04, 25, 100, 50, 0, 60, 255], ANIM_MISSED],
	[[0x03, 25, 100, 50, 0, 60, 255], ANIM_SHOOK_BASE + 1],
	[[0x04, 190, 100, 50, 0, 199, 255], ANIM_SHOOK_BASE + 2],
	[[0x03, 190, 100, 50, 0, 199, 255], ANIM_SHOOK_BASE + 3],
	# 342 max HP locks Crystal up; nothing here truncates the divisor.
	[[0x04, 255, 342, 342, 0, 60, 255], ANIM_SHOOK_BASE + 2],
	[[0x04, 255, 999, 999, 0, 60, 255], ANIM_SHOOK_BASE + 2],
]

## The only two catch rates Yellow rewrote, by dex number.
const CATCH_RATES: Dictionary = {
	&"yellow": {148: 27, 149: 9},
	&"red": {148: 45, 149: 45},
	&"blue": {148: 45, 149: 45},
}

## One roll pair per outcome the ladder can reach.
const CORPUS_ROLLS: Array = [[0, 255], [60, 255], [100, 128], [150, 0]]

## SHA-1 of every species against every ball, one digest per cartridge.
const CORPUS_DIGESTS: Dictionary = {
	&"red": "7dabad4cd44540ae2b3b80a2c08e097141db9dc8",
	&"blue": "7dabad4cd44540ae2b3b80a2c08e097141db9dc8",
	&"yellow": "4259edebdc2384733103eaaf123b570f16af3b16",
}

const SPECIES_COUNT: int = 151

var _r: RefCounted = null


func run(r: RefCounted) -> void:
	_r = r
	r.each_game_of(RomRegistry.GEN1, _one_game)


func _one_game() -> void:
	_the_balls_are_the_cartridge_s()
	for row: Array in PINNED:
		_verify(row[0] as Array, int(row[1]))
	_oracle_sweep()
	_corpus_sweep()


## The five numbers `ItemUsePtrTable` gives an `ItemUseBall` row.
func _the_balls_are_the_cartridge_s() -> void:
	var offered: Array[int] = Gen2WorldPartyHost.capture_ball_items(RomRegistry.GEN1)
	_r.check(
		offered.size() == BALL_NAMES.size(),
		"%d balls are offered, %d have an ItemUseBall row." % [
			offered.size(), BALL_NAMES.size(),
		]
	)
	for ball: int in BALL_NAMES:
		_r.check(ball in offered, "ball %d is not offered." % ball)
		var name: String = String(_r.data.item(ball).get("name", ""))
		_r.check(
			name == String(BALL_NAMES[ball]),
			"item %d is %s, the cartridge calls it %s." % [ball, name, BALL_NAMES[ball]]
		)
	for ball: int in GEN2_NUMBERING_READS:
		var name: String = String(_r.data.item(ball).get("name", ""))
		_r.check(
			name == String(GEN2_NUMBERING_READS[ball]),
			"Crystal's %d reads as %s here, not %s." % [
				ball, name, GEN2_NUMBERING_READS[ball],
			]
		)


## Hashed whole, header included, so the digest is the cartridge file's own.
func _oracle_sweep() -> void:
	var lines: PackedStringArray = PackedStringArray([ORACLE_HEAD])
	for ball: int in ORACLE_BALLS:
		for rate: int in ORACLE_RATES:
			for first: int in ORACLE_ROLLS:
				if first > int(ORACLE_CEILINGS[ball]):
					continue
				for second: int in ORACLE_SECOND:
					lines.append(_line([ball, rate, 100, 50, 0, first, second]))
	for ball: int in [0x04, 0x03]:
		for pair: Array in ORACLE_HEALTH:
			for rate: int in [3, 45, 255]:
				for second: int in [0, 128, 255]:
					lines.append(_line([
						ball, rate, int(pair[0]), int(pair[1]), 0, 60, second,
					]))
	for status: int in ORACLE_STATUSES:
		for rate: int in [3, 45, 190]:
			for first: int in [0, 11, 12, 24, 25, 100, 255]:
				for second: int in [0, 255]:
					lines.append(_line([0x04, rate, 100, 100, status, first, second]))
	var digest: String = ("\n".join(lines) + "\n").sha1_text()
	if digest != ORACLE_DIGEST:
		_r.fail("the %d-case oracle sweep is %s, the cartridge %s." % [
			lines.size() - 1, digest, ORACLE_DIGEST,
		])


## Every species' own catch rate through every ball: the oracle above names its
## rate directly and reads no base stats column.
func _corpus_sweep() -> void:
	var lines: PackedStringArray = PackedStringArray()
	var rewritten: Dictionary = CATCH_RATES.get(_r.game_id, {})
	for species: int in range(1, SPECIES_COUNT + 1):
		var rate: int = int(_r.data.species(species).get("catch_rate", -1))
		if rate < 0:
			_r.fail("species %d carries no catch rate." % species)
			return
		if rewritten.has(species):
			_r.check(rate == int(rewritten[species]), "species %d catches at %d, not %d." % [
				species, rate, rewritten[species],
			])
		for ball: int in Gen2WorldPartyHost.capture_ball_items(RomRegistry.GEN1):
			for pair: Array in CORPUS_ROLLS:
				lines.append("%d %s" % [species, _line([
					ball, rate, 100, 50, 0, int(pair[0]), int(pair[1]),
				])])
	var digest: String = ("\n".join(lines) + "\n").sha1_text()
	var expected: String = String(CORPUS_DIGESTS.get(_r.game_id, ""))
	if expected.is_empty():
		_r.fail("no pinned corpus digest. It answered %s." % digest)
		return
	if digest != expected:
		_r.fail("the %d-case corpus sweep is %s, pinned %s." % [
			lines.size(), digest, expected,
		])


func _verify(case: Array, expected: int) -> void:
	var answered: int = _anim_data(case)
	if answered != expected:
		_r.check(false, "%s answered $%02X, the cartridge $%02X." % [
			str(case), answered, expected,
		])


func _line(case: Array) -> String:
	return "%s -> %d" % [
		" ".join(case.map(func(v: int) -> String: return str(v))), _anim_data(case),
	]


## The byte the cartridge writes, out of what this port answers instead.
func _anim_data(case: Array) -> int:
	var queue: Array = [int(case[5]), int(case[6])]
	var outcome: Dictionary = Gen2WorldPartyHost.gen1_ball_outcome(int(case[0]), {
		"catch_rate": int(case[1]),
		"max_hp": int(case[2]),
		"current_hp": int(case[3]),
		"status": int(case[4]),
	}, func() -> int: return int(queue.pop_front()) if not queue.is_empty() else 0)
	if bool(outcome["caught"]):
		return ANIM_CAUGHT
	var rocks: int = int(outcome["wobbles"])
	return ANIM_SHOOK_BASE + rocks if rocks > 0 else ANIM_MISSED
