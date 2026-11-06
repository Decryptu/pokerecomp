extends GutTest


class Encounters:
	extends GameData
	var rate: int = 100

	func world_encounter(_method: StringName, _group: int, _number: int, _variant: int = 0) -> Dictionary:
		return {"rate": rate, "slots": [{"species": 25, "min_level": 3, "max_level": 3, "chance": 100}]}

	func world_encounter_variant_count(_method: StringName, _group: int, _number: int) -> int:
		return 1

	func world_encounter_tile(behavior: int) -> bool:
		return behavior == GRASS

	func world_surfable(_behavior: int) -> bool:
		return false

	func species(_number: int) -> Dictionary:
		return {"abilities": [0, 0], "types": [0, 0]}


const GRASS: int = 2
const MAP := Vector2i(0, 16)
const ON_FOOT: int = Gen3PlayerAvatar.Flag.ON_FOOT
const FRLG_LAND: int = 1 << Gen3WildEncounter.ENCOUNTER_TYPE_SHIFT


func _model(id: StringName, engine: StringName, rate: int = 100) -> Gen3WildEncounter:
	var data := Encounters.new()
	data.rate = rate
	return Gen3WildEncounter.new(data, Gen3EventData.new(id), engine)


func test_immunity_steps_come_first_and_return_after_an_encounter() -> void:
	var wild: Gen3WildEncounter = _model(RomRegistry.EMERALD, &"emerald")
	for step: int in Gen3WildEncounter.IMMUNITY_STEPS:
		assert_eq(wild.check(MAP, GRASS, 0, ON_FOOT), {})
	assert_eq(wild.check(MAP, GRASS, 0, ON_FOOT), {"species": 25, "level": 3, "area": "land"}, "A rate of 100 always fights.")
	assert_eq(wild.check(MAP, GRASS, 0, ON_FOOT), {})
	assert_eq(wild._previous, GRASS)
	assert_eq(wild.check(MAP, 0, 0, ON_FOOT), {}, "Plain ground has no encounters.")


func test_repel_turns_away_levels_under_the_first_healthy_mon_and_passes_its_equals() -> void:
	var wild: Gen3WildEncounter = _model(RomRegistry.EMERALD, &"emerald")
	wild._events.var_set(int(Gen3FieldInput.FLAGS[&"emerald"]["repel"]), 10)
	wild._events.party.assign([{"species": 1, "egg": true, "hp": 0, "level": 50}, {"species": 1, "hp": 9, "level": 4}])
	assert_false(wild._allowed_by_repel(3))
	assert_true(wild._allowed_by_repel(4))
	wild._events.party.assign([])
	assert_false(wild._allowed_by_repel(100), "No usable party finds no level to compare.")


func test_frlg_counts_cooldown_steps_and_builds_a_rate_buff_on_misses() -> void:
	var wild: Gen3WildEncounter = _model(RomRegistry.FIRERED, &"firered", 1)
	wild._frlg_rng = 3 # A stream with no roll low enough to fight.
	var fights: int = 0
	for step: int in 16:
		fights += int(not wild.check(MAP, GRASS, FRLG_LAND, ON_FOOT).is_empty())
	assert_eq(fights, 0)
	assert_eq(wild._steps, 8, "A rate under 10 waits eight steps, then every step rolls.")
	assert_true(wild._rate_buff > 0, "Misses add the map's rate to the buff.")
	wild.restart_immunity()
	assert_eq([wild._steps, wild._rate_buff], [0, 0])
