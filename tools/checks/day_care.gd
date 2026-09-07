extends RefCounted

## Sweeps the Day-Care and the breeding rules behind it on freshly imported real
## caches, all three cartridges, whole corpus. What this exists to catch is a rule
## that is right for the pair a test was written for and wrong for the corpus:
## `GetPreEvolution` is a search over every species, `CheckBreedmonCompatibility`
## reads two records at once, and `FillMoves` is the same routine the retrieval and
## the egg both go through, and a sampled pair answers none of those. The
## real-cartridge counterpart to tests/unit/test_world_day_care.gd.

## `PrintDayCareText.TextTable`'s twenty, `.NotYetText`, `DayCareManOutside`'s
## five and `engine/pokemon/breeding.asm`'s two plus five.
const EXPECTED_TEXTS: int = 33
## One stub per run, by the words that identify the run rather than the address.
const TEXT_ANCHORS: Dictionary = {
	"man_intro": "I'm the DAY-CARE",
	"not_yet": "Not yet",
	"found_an_egg": "it's you!",
	"left_with_man": "DAY-CARE MAN",
	"brimming_with_energy": "brimming with",
}

## `DITTO`, the one species compatible with everything that breeds at all.
const SPECIES_DITTO: int = 132

## The Generation 1 stubs whose own `text_ram` names `wNameBuffer` or
## `wDayCareMonName`, and the two carrying a `text_decimal` or a `text_bcd`.
const GEN1_RAM_BOXES: Array[String] = [
	"will_look_after", "has_grown", "got_mon_back", "needs_more_time",
]
const GEN1_NUMBER_BOXES: Array[String] = ["has_grown", "owe_money"]

var _r: RefCounted = null


func run(r: RefCounted) -> void:
	_r = r
	for game_id: StringName in _r.GAME_IDS:
		var data: GameData = GameData.open(game_id)
		if data == null:
			_r.fail("%s cache is unavailable. Import roms/%s.gbc first." % [game_id, game_id])
			continue
		_r.game_id = game_id
		_verify_texts(game_id, data)
		_verify_pre_evolutions(game_id, data)
		_verify_compatibility(game_id, data)
		_verify_egg_moves(game_id, data)
		_verify_fill_moves(game_id, data)
		_verify_odd_eggs(game_id, data)
	_r.each_game_of(RomRegistry.GEN1, _one_gen1_game)
	_r.game_id = &""


## Generation 1's own Day-Care: one slot, `IncrementDayCareMonExp` a point a
## step, and `DaycareGentlemanText` reading the level back off the experience.
func _one_gen1_game() -> void:
	_verify_gen1_texts()
	_verify_gen1_hm_moves()
	_verify_gen1_growth()
	_verify_gen1_learning()


## The fifteen stubs, each distinct and each carrying the print-time markers its
## own `text_ram`, `text_decimal` or `text_bcd` writes.
func _verify_gen1_texts() -> void:
	var seen: Dictionary = {}
	for name: String in Gen1Layout.DAY_CARE_TEXT_AT:
		var text: String = _r.data.day_care_text(name)
		if not _r.check(not text.is_empty(), "the %s box is empty." % name):
			continue
		_r.check(not seen.has(text), "the %s box repeats another." % name)
		seen[text] = true
		_r.check(
			text.contains(Gen2TextStream.RAM_MARKER) == GEN1_RAM_BOXES.has(name),
			"the %s box reads %s." % [name, text]
		)
		_r.check(
			text.contains(Gen2TextStream.NUMBER_MARKER) == GEN1_NUMBER_BOXES.has(name),
			"the %s box reads %s." % [name, text]
		)
	_r.check(
		_r.data.day_care_text("all_right_then").to_lower().contains("come again"),
		"`all_right_then` did not run on into `come_again`."
	)


## `HMMoveArray`: `KnowsHMMove` answers for the five HM machines' moves and for
## nothing else on the cartridge.
func _verify_gen1_hm_moves() -> void:
	var refused: Array[int] = []
	for move: int in range(1, _r.data.move_count() + 1):
		if Gen2WorldTMHM.knows_hm_move(_r.data, [move]):
			refused.append(move)
	var wanted: Array[int] = []
	for number: int in range(Gen1Layout.TM_COUNT + 1, Gen1Layout.TM_COUNT + Gen1Layout.HM_COUNT + 1):
		wanted.append(_r.data.tmhm_move(number))
	wanted.sort()
	_r.check(refused == wanted, "the Day-Care refuses moves %s." % [refused])
	_r.note("gen1 day-care refuses %d HM moves" % refused.size())


## Every species at every deposit level: `CalcLevelFromExperience` answers the
## level the experience bought, the price is a hundred a level plus a hundred,
## and a slot past MAX_LEVEL has its experience written back down.
func _verify_gen1_growth() -> void:
	var state: Gen2WorldState = Gen2WorldState.new()
	for species: int in range(1, _r.data.species_count() + 1):
		var rate: int = int(_r.data.species(species).get("growth_rate", 0))
		for level: int in range(1, Gen2WorldDayCare.MAX_LEVEL):
			var visit: Dictionary = _gen1_visit(
				state, species, level, Gen2Experience.total_exp_at(rate, level + 1)
			)
			if not _r.check(
				int(visit.get("growth", -1)) == 1 and int(visit.get("price", 0)) == 200,
				"%s at level %d grew by %s." % [species, level, visit.get("growth", -1)]
			):
				return
		var top: int = Gen2Experience.total_exp_at(rate, Gen2WorldDayCare.MAX_LEVEL)
		var clamped: Dictionary = _gen1_visit(state, species, 1, Gen2Experience.MAX_EXP)
		if not _r.check(
			int(clamped.get("level", 0)) == Gen2WorldDayCare.MAX_LEVEL
				and state.day_care_mon(Gen2WorldDayCare.SLOT_MAN).exp == top,
			"species %d ran past MAX_LEVEL and kept %s." % [species, clamped]
		):
			return
	_r.note("gen1 day-care growth over %d species" % _r.data.species_count())


## `WriteMonMoves` under `wLearningMovesFromDayCare`, for every species and every
## deposit level: four slots, no move twice, and PP behind every one of them.
func _verify_gen1_learning() -> void:
	for species: int in range(1, _r.data.species_count() + 1):
		var learnset: Array = _r.data.learnset(species)
		for level: int in range(1, Gen2WorldDayCare.MAX_LEVEL):
			var mon: Gen2SaveMon = _gen1_slot(species, level)
			mon.moves = Gen2Learnset.moves_at_level(learnset, level)
			while mon.moves.size() < Gen2SaveMon.MAX_MOVES:
				mon.moves.append(0)
			mon.pp = [1, 1, 1, 1]
			mon.level = Gen2WorldDayCare.MAX_LEVEL
			Gen2WorldDayCare.gen1_fill_moves(_r.data, mon, level)
			if not _r.check(_gen1_moves_sane(mon), "species %d from level %d learned %s with %s." % [
				species, level, mon.moves, mon.pp,
			]):
				return
	_r.note("gen1 day-care learning over %d species" % _r.data.species_count())


func _gen1_moves_sane(mon: Gen2SaveMon) -> bool:
	var seen: Dictionary = {}
	for slot: int in Gen2SaveMon.MAX_MOVES:
		var move: int = int(mon.moves[slot])
		if move == 0:
			continue
		if seen.has(move) or int(mon.pp[slot]) < 1:
			return false
		seen[move] = true
	return mon.moves.size() == Gen2SaveMon.MAX_MOVES


func _gen1_visit(
	state: Gen2WorldState, species: int, level: int, experience: int
) -> Dictionary:
	var mon: Gen2SaveMon = _gen1_slot(species, level)
	mon.exp = experience
	state.set_day_care_mon(Gen2WorldDayCare.SLOT_MAN, mon)
	state.set_day_care_has_mon(Gen2WorldDayCare.SLOT_MAN, true)
	return Gen2WorldDayCare.gen1_visit(state, _r.data)


func _gen1_slot(species: int, level: int) -> Gen2SaveMon:
	var mon: Gen2SaveMon = Gen2SaveMon.new()
	mon.species = species
	mon.level = level
	mon.moves = [0, 0, 0, 0]
	mon.pp = [0, 0, 0, 0]
	return mon


## The Day-Care Man's own gift, Crystal's alone. Every row decodes as the
## nicknamed-mon struct it is, the probabilities rise to $ffff, and every share
## of the roll lands on a row: rolling each entry's own word and the one below
## it walks both edges of `.loop`'s comparison rather than sampling the middle.
func _verify_odd_eggs(game_id: StringName, data: GameData) -> void:
	var rows: Array = data.odd_eggs()
	if game_id != &"crystal":
		_r.check(rows.is_empty(), "%s: ships %d Odd Eggs." % [game_id, rows.size()])
		return
	if not _r.check(
		rows.size() == Gen2Layout.ODD_EGG_COUNT,
		"%s: %d Odd Eggs, not %d." % [game_id, rows.size(), Gen2Layout.ODD_EGG_COUNT]
	):
		return
	var probabilities: Array = []
	for row: Variant in rows:
		probabilities.append(int((row as Dictionary).get("probability", 0)))
	for index: int in rows.size():
		var mon: Gen2SaveMon = data.odd_egg_mon(index)
		if not _r.check(mon != null, "%s: Odd Egg %d does not decode." % [game_id, index]):
			continue
		_r.check(
			not data.species(mon.species).is_empty(),
			"%s: Odd Egg %d names species %d." % [game_id, index, mon.species]
		)
		_r.check(
			mon.level == Gen2Layout.ODD_EGG_LEVEL,
			"%s: Odd Egg %d is level %d." % [game_id, index, mon.level]
		)
		_r.check(
			mon.nickname == Gen2Layout.ODD_EGG_NICKNAME,
			"%s: Odd Egg %d is nicknamed \"%s\"." % [game_id, index, mon.nickname]
		)
		_r.check(
			Gen2WorldPartyHost.odd_egg_row(probabilities[index], probabilities) == index,
			"%s: the word %d does not land on Odd Egg %d." % [
				game_id, probabilities[index], index,
			]
		)
		var below: int = probabilities[index - 1] + 1 if index > 0 else 0
		_r.check(
			Gen2WorldPartyHost.odd_egg_row(below, probabilities) == index,
			"%s: the word %d does not land on Odd Egg %d." % [game_id, below, index]
		)
	_r.check(
		probabilities[-1] == Gen2Layout.ODD_EGG_PROBABILITY_TOTAL,
		"%s: the Odd Egg probabilities close on %d." % [game_id, probabilities[-1]]
	)


## Every stub of the four runs decodes, and one per run carries the words that
## say the pin is that run and not its neighbour.
func _verify_texts(game_id: StringName, data: GameData) -> void:
	var found: int = 0
	for subject: Array in Gen2Layout.DAY_CARE_TEXT_RUNS:
		for raw_name: Variant in subject[1] as Array:
			var name: String = String(raw_name)
			var text: String = data.day_care_text(name)
			if _r.check(
				not text.is_empty(), "%s: the Day-Care's %s text is empty." % [game_id, name]
			):
				found += 1
	_r.check(
		found == EXPECTED_TEXTS,
		"%s: %d of %d Day-Care texts decoded." % [game_id, found, EXPECTED_TEXTS]
	)
	for name: String in TEXT_ANCHORS:
		_r.check(
			data.day_care_text(name).contains(String(TEXT_ANCHORS[name])),
			"%s: the Day-Care's %s text is \"%s\"." % [
				game_id, name, data.day_care_text(name)
			]
		)


## `DayCare_InitBreeding` calls `GetPreEvolution` exactly twice, so two passes
## have to reach a base form for every species on the cartridge: a third pass
## finding anything would mean a three-deep line whose egg is the middle stage.
func _verify_pre_evolutions(game_id: StringName, data: GameData) -> void:
	var deepest: int = 0
	for species: int in range(1, data.species_count() + 1):
		var once: int = Gen2WorldDayCare.pre_evolution(data, species)
		var twice: int = Gen2WorldDayCare.pre_evolution(data, once)
		var thrice: int = Gen2WorldDayCare.pre_evolution(data, twice)
		if once != species:
			deepest = maxi(deepest, 2 if twice != once else 1)
		if not _r.check(
			thrice == twice,
			"%s: species %d is still evolving from %d after two passes." % [
				game_id, species, thrice
			]
		):
			continue
		## Every species an egg can be has a hatch counter, since the counter is
		## what `DoEggStep` drains and a zero one hatches on the first step.
		_r.check(
			int(data.species(twice).get("hatch_cycles", 0)) > 0,
			"%s: base species %d has no hatch cycles." % [game_id, twice]
		)
	_r.check(deepest == 2, "%s: no species is two evolutions deep." % game_id)


## `CheckBreedmonCompatibility` over the whole species square. Two things are
## swept: the answer does not depend on which slot a species is in, and every
## answer is one of the values `DayCareMonCompatibilityText` and
## `DayCare_InitBreeding` between them account for.
func _verify_compatibility(game_id: StringName, data: GameData) -> void:
	var count: int = data.species_count()
	var breeders: int = 0
	var asymmetric: int = 0
	var out_of_range: int = 0
	for first: int in range(1, count + 1):
		var mon1: Gen2SaveMon = _mon(first, 0x1234, 111)
		for second: int in range(first, count + 1):
			var mon2: Gen2SaveMon = _mon(second, 0x5678, 222)
			var forward: int = Gen2WorldDayCare.compatibility(data, mon1, mon2)
			var backward: int = Gen2WorldDayCare.compatibility(data, mon2, mon1)
			if forward != backward:
				asymmetric += 1
			if forward not in [0, 51, 128, 177, 254, 255]:
				out_of_range += 1
			if forward != 0 and forward != 255:
				breeders += 1
	_r.check(
		asymmetric == 0,
		"%s: %d species pairs answer differently by slot." % [game_id, asymmetric]
	)
	_r.check(
		out_of_range == 0,
		"%s: %d species pairs answer a value no branch reads." % [game_id, out_of_range]
	)
	_r.check(breeders > 0, "%s: no species pair breeds at all." % game_id)
	## Ditto's own row, which is the one species the group test lets through
	## whatever it is paired with.
	var ditto: Gen2SaveMon = _mon(SPECIES_DITTO, 0x1234, 111)
	for species: int in range(1, count + 1):
		var partner: Gen2SaveMon = _mon(species, 0x5678, 222)
		var breeds: bool = Gen2WorldDayCare.compatibility(data, ditto, partner) != 0
		_r.check(
			breeds == (species != SPECIES_DITTO
				and Gen2WorldDayCare.groups_compatible(data, ditto, partner)),
			"%s: DITTO and species %d disagree with their egg groups." % [game_id, species]
		)


## Every egg move names a move this cache has, and every one of them is one the
## egg species can actually receive: `GetEggMove`'s first test is the list
## itself, so a list entry that fails [method Gen2WorldDayCare.inherits_move]
## would mean the two readings of the same table disagree.
func _verify_egg_moves(game_id: StringName, data: GameData) -> void:
	var rows: int = 0
	for species: int in range(1, data.species_count() + 1):
		for move: int in data.egg_moves(species):
			rows += 1
			if not _r.check(
				move > 0 and move <= data.move_count(),
				"%s: species %d inherits move %d." % [game_id, species, move]
			):
				continue
			_r.check(
				Gen2WorldDayCare.inherits_move(data, species, move, null),
				"%s: species %d's own egg move %d is refused." % [game_id, species, move]
			)
	_r.check(rows > 0, "%s: no egg moves imported." % game_id)


## `FillMoves` over every species at every level, both branches. Four slots, no
## repeats and nothing above the level asked for is the whole of the routine's
## contract, and the skip branch may only ever be a subset of the plain one.
func _verify_fill_moves(game_id: StringName, data: GameData) -> void:
	for species: int in range(1, data.species_count() + 1):
		var learnset: Array = data.learnset(species)
		for level: int in range(1, Gen2Experience.MAX_LEVEL + 1):
			var known: Array = Gen2Learnset.moves_at_level(learnset, level)
			if not _r.check(
				known.size() <= Gen2Learnset.MOVE_SLOTS,
				"%s: species %d knows %d moves at level %d." % [
					game_id, species, known.size(), level
				]
			):
				return
			var seen: Dictionary = {}
			for move: Variant in known:
				if not _r.check(
					not seen.has(move),
					"%s: species %d knows move %d twice at level %d." % [
						game_id, species, int(move), level
					]
				):
					return
				seen[move] = true
			## The retrieval branch: filling from the level below teaches at most
			## what the whole walk would, and never a move it would not.
			var grown: Array = Gen2Learnset.moves_at_level(learnset, maxi(1, level - 1))
			Gen2Learnset.fill_moves(learnset, grown, level, maxi(1, level - 1))
			if not _r.check(
				grown.size() <= Gen2Learnset.MOVE_SLOTS,
				"%s: species %d grows into %d moves at level %d." % [
					game_id, species, grown.size(), level
				]
			):
				return


## A Day-Care slot with the DVs and trainer ID a sweep needs to be able to vary,
## since both of them are read by `CheckBreedmonCompatibility`.
func _mon(species: int, dvs: int, ot_id: int) -> Gen2SaveMon:
	var mon: Gen2SaveMon = Gen2SaveMon.new()
	mon.species = species
	mon.dvs = dvs
	mon.ot_id = ot_id
	mon.level = 20
	return mon
