extends GutTest

## The Nuzlocke's own rules, on the block that records them. The challenge
## itself is a [Gen2Rules] flag and is covered in `test_rules.gd`; what a run
## has SPENT lives here.

const ROUTE_29: int = 12
const ROUTE_30: int = 13


func _mon(species: int, level: int, hp: int, nickname: String = "") -> Gen2SaveMon:
	var mon := Gen2SaveMon.new()
	mon.species = species
	mon.level = level
	mon.hp = hp
	mon.nickname = nickname
	return mon


func _save(party: Array) -> Gen2SaveData:
	var save := Gen2SaveData.new()
	save.party = party
	return save


## An area gives up one encounter and no more, whatever became of it. The claim
## is what a ball is later checked against, so a second claim on the same area
## has to answer false rather than overwrite the first.
func test_an_area_gives_up_exactly_one_encounter() -> void:
	var section: Dictionary = {}
	assert_false(Gen2Nuzlocke.area_spent(section, ROUTE_29))
	assert_true(Gen2Nuzlocke.claim_area(section, ROUTE_29, 16))
	assert_true(Gen2Nuzlocke.area_spent(section, ROUTE_29))
	assert_false(
		Gen2Nuzlocke.claim_area(section, ROUTE_29, 19),
		"the second Pokemon on the same route is not catchable",
	)
	assert_eq(
		int((section["areas"] as Dictionary)[str(ROUTE_29)]["species"]), 16,
		"and the first one is still the one on the record",
	)
	assert_true(Gen2Nuzlocke.claim_area(section, ROUTE_30, 10), "the next route is its own")
	assert_false(Gen2Nuzlocke.claim_area(section, -1, 10), "a map with no landmark claims none")


## A catch is recorded on the area it was already spent on, so the memorial can
## tell a route whose Pokemon was taken from one whose Pokemon got away.
func test_a_catch_is_noted_on_the_area_it_was_already_spent_on() -> void:
	var section: Dictionary = {}
	Gen2Nuzlocke.claim_area(section, ROUTE_29, 16)
	assert_false(bool((section["areas"] as Dictionary)[str(ROUTE_29)]["caught"]))
	Gen2Nuzlocke.note_caught(section, ROUTE_29)
	assert_true(bool((section["areas"] as Dictionary)[str(ROUTE_29)]["caught"]))
	Gen2Nuzlocke.note_caught(section, ROUTE_30)
	assert_false(
		(section["areas"] as Dictionary).has(str(ROUTE_30)),
		"an area nothing claimed is not created by the note",
	)


## A faint is a death: the row leaves the party and joins the memorial. An egg
## has no HP to lose, and a zero on one is a row shape rather than a loss.
func test_a_faint_takes_the_row_off_the_party_and_records_it() -> void:
	var egg: Gen2SaveMon = _mon(1, 5, 0)
	egg.is_egg = true
	var save: Gen2SaveData = _save([
		_mon(155, 12, 0, "CYNDER"), _mon(16, 8, 14), egg, _mon(19, 4, 0),
	])

	var lost: Array = Gen2Nuzlocke.reap(save, Gen2Nuzlocke.CAUSE_BATTLE, ROUTE_29)

	assert_eq(lost.size(), 2)
	assert_eq(String(lost[0]["nickname"]), "CYNDER")
	assert_eq(int(lost[0]["level"]), 12)
	assert_eq(String(lost[0]["cause"]), String(Gen2Nuzlocke.CAUSE_BATTLE))
	assert_eq(int(lost[0]["landmark"]), ROUTE_29)
	assert_eq(save.party.size(), 2, "the survivor and the egg are what is left")
	assert_eq((save.party[0] as Gen2SaveMon).species, 16)
	assert_true((save.party[1] as Gen2SaveMon).is_egg)
	assert_eq((save.nuzlocke["graveyard"] as Array).size(), 2)

	assert_true(
		Gen2Nuzlocke.reap(save, Gen2Nuzlocke.CAUSE_BATTLE, ROUTE_29).is_empty(),
		"a second pass over the same party takes nothing",
	)


## A save cannot grow without a bound, so the memorial keeps the last losses and
## drops the oldest rather than every one of a very long run.
func test_the_memorial_is_bounded() -> void:
	var save: Gen2SaveData = _save([])
	for index: int in Gen2Nuzlocke.MAX_GRAVEYARD + 4:
		save.party = [_mon(16, index + 1, 0, "N%d" % index)]
		Gen2Nuzlocke.reap(save, Gen2Nuzlocke.CAUSE_POISON, ROUTE_29)
	var graveyard: Array = save.nuzlocke["graveyard"]
	assert_eq(graveyard.size(), Gen2Nuzlocke.MAX_GRAVEYARD)
	assert_eq(
		String(graveyard[graveyard.size() - 1]["nickname"]),
		"N%d" % (Gen2Nuzlocke.MAX_GRAVEYARD + 3),
		"the newest loss is the one kept",
	)


## The run's own ending. Writing it into the block is what survives a reload,
## and it is written once: a second wipe cannot rewrite where the run died.
func test_a_run_ends_once_and_stays_ended() -> void:
	var section: Dictionary = {}
	assert_false(Gen2Nuzlocke.run_over(section))
	Gen2Nuzlocke.end_run(section, ROUTE_29, 3)
	assert_true(Gen2Nuzlocke.run_over(section))
	Gen2Nuzlocke.end_run(section, ROUTE_30, 5)
	assert_eq(int((section["ended"] as Dictionary)["landmark"]), ROUTE_29)
	assert_eq(String((section["ended"] as Dictionary)["reason"]), String(Gen2Nuzlocke.ENDED_WIPED))


## A hand-edited save must cost a refused area, never a crash, so every reader
## goes through the normalizer.
func test_an_unreadable_block_is_normalized_rather_than_trusted() -> void:
	assert_true(Gen2Nuzlocke.normalize("not a block").is_empty())
	assert_true(Gen2Nuzlocke.normalize({}).is_empty())

	var section: Dictionary = Gen2Nuzlocke.normalize({
		"areas": {"12": {"species": -4, "caught": true}, "-1": {}, "13": "nonsense"},
		"graveyard": [{"level": 900, "species": 16}, "nonsense"],
		"ended": {"reason": "wiped"},
	})
	assert_eq((section["areas"] as Dictionary).size(), 1)
	assert_eq(int((section["areas"] as Dictionary)["12"]["species"]), 0)
	assert_eq((section["graveyard"] as Array).size(), 1)
	assert_eq(int((section["graveyard"] as Array)[0]["level"]), Gen2Experience.MAX_LEVEL)
	assert_true(Gen2Nuzlocke.run_over(section))


## The block travels with the save it describes, which is what makes a death
## survive a reload.
func test_the_block_round_trips_through_the_save() -> void:
	var save: Gen2SaveData = _save([_mon(155, 12, 0, "CYNDER")])
	save.game_id = &"crystal"
	Gen2Nuzlocke.claim_area(save.nuzlocke, ROUTE_29, 16)
	Gen2Nuzlocke.reap(save, Gen2Nuzlocke.CAUSE_BATTLE, ROUTE_29)
	Gen2Nuzlocke.end_run(save.nuzlocke, ROUTE_29, 1)

	var restored: Gen2SaveData = Gen2SaveData.from_dict(save.to_dict())
	assert_true(Gen2Nuzlocke.area_spent(restored.nuzlocke, ROUTE_29))
	assert_true(Gen2Nuzlocke.run_over(restored.nuzlocke))
	assert_eq((restored.nuzlocke["graveyard"] as Array).size(), 1)
	assert_eq(
		String((restored.nuzlocke["graveyard"] as Array)[0]["nickname"]), "CYNDER"
	)
	assert_true(
		Gen2SaveData.from_dict(Gen2SaveData.new().to_dict()).nuzlocke.is_empty(),
		"and a run that is not a Nuzlocke carries no block at all",
	)


## The name a loss is mourned by, which is the one a screen prints.
func test_a_loss_without_a_nickname_falls_back_to_its_species() -> void:
	assert_eq(Gen2Nuzlocke.grave_name(null, {"nickname": "CYNDER"}), "CYNDER")
	assert_eq(Gen2Nuzlocke.grave_name(null, {"species": 155}), "?", "with no cache to ask")
