extends GutTest

## [Gen2LinkScreen]'s trade list, read back through [method Gen2LinkScreen.trade_state]
## without a texture.

const Fixture := preload("res://tests/unit/battle_fixture.gd")

var _directory: String = ""
var _data: GameData = null


func before_each() -> void:
	_directory = RomCache.directory_for(&"linktest", "0123456789abcdef")
	_data = Fixture.build(_directory)


func after_each() -> void:
	RomCache.clear(_directory)
	Gen2ModHost.reset()


## `PlaceTradePartnerNamesAndParty` runs `GetPokemonName` over the party species
## list, whose entry for an egg is EGG, so both columns name an egg as EGG
## rather than the species it carries.
func test_both_trade_columns_name_an_egg_egg() -> void:
	var save: Gen2SaveData = Gen2SaveBattleAdapter.from_battle_party(
		_data.id, _data.sha1, 1,
		Gen2Party.of(Gen2BattleMon.create(_data, Fixture.PIKACHU, 20, [Fixture.TACKLE])),
		"RED"
	)
	var egg: Gen2SaveMon = Gen2SaveMon.from_dict(save.party[0].to_dict())
	egg.is_egg = true
	save.party.append(egg)
	var screen := Gen2LinkScreen.new()
	screen.set("_data", _data)
	screen.set("_save", save)
	screen.set("_partner", {"name": "BLUE", "party": [egg.to_dict(), save.party[0].to_dict()]})
	var state: Dictionary = screen.trade_state()
	screen.free()
	var species_name: String = String(_data.species(Fixture.PIKACHU).get("name", ""))
	assert_eq(state["player"]["species"], [species_name, Gen2StatsScreenPage.EGG_STRING])
	assert_eq(state["partner"]["species"], [Gen2StatsScreenPage.EGG_STRING, species_name])


## `ShowLinkBattleParticipantsAfterEnd` stands with no verdict for 150 frames,
## `DisplayLinkBattleResult` shows it for 200, and the record page that follows
## waits for A or B.
func test_a_colosseum_battle_ends_on_its_verdict_and_then_the_record() -> void:
	var screen := Gen2LinkScreen.new()
	screen.mode = Gen2LinkScreen.MODE_VERSUS_RESULT
	screen.set("_page", Gen2LinkPage.new())
	screen.set("_step", Gen2LinkScreen.STEP.VERSUS)
	screen.set("_frames", Gen2LinkScreen.VERSUS_FRAMES)
	screen.set_versus([], [], "YOU WIN")
	assert_eq(String(screen.get("_versus")["result"]), "")
	for _frame: int in Gen2LinkScreen.VERSUS_FRAMES:
		screen.advance_frame()
	assert_eq(String(screen.get("_versus")["result"]), "YOU WIN")
	for _frame: int in Gen2LinkScreen.VERDICT_FRAMES:
		screen.advance_frame()
	var closed: Array = [false]
	screen.closed.connect(func() -> void: closed[0] = true)
	screen.handle_button(PokeButton.A)
	assert_true(bool(closed[0]))
	screen.free()
