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
