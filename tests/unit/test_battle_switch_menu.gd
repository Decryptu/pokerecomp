extends GutTest

## `PickSwitchMonInBattle` and `ForcePickSwitchMonInBattle`
## (`engine/battle/core.asm`): the rows, the wrapping cursor and the two
## refusals both variants share.

const Fixture := preload("res://tests/unit/battle_fixture.gd")

var _directory: String = ""
var _data: GameData = null


func before_each() -> void:
	_directory = RomCache.directory_for(&"switchmenutest", "0123456789abcdef")
	_data = Fixture.build(_directory)


func after_each() -> void:
	RomCache.clear(_directory)


func _mon(species: int, level: int = 20) -> Gen2BattleMon:
	return Gen2BattleMon.create(_data, species, level, [Fixture.TACKLE])


## Three standing, the first one out, which is what a battle party looks like
## when `OfferSwitch` asks.
func _party() -> Gen2Party:
	return Gen2Party.create([
		_mon(Fixture.PIKACHU), _mon(Fixture.BULBASAUR), _mon(Fixture.GEODUDE),
	])


func _menu(forced: bool = false) -> Gen2BattleSwitchMenu:
	return Gen2BattleSwitchMenu.for_party(_party(), forced)


func test_the_list_is_the_party_and_one_cancel_row() -> void:
	var menu: Gen2BattleSwitchMenu = _menu()
	assert_eq(menu.rows.size(), 3)
	assert_eq(menu.item_count(), 4, "w2DMenuNumRows is wPartyCount + 1")
	assert_true(menu.is_cancel(3))
	assert_false(menu.is_cancel(2))
	assert_eq(menu.cursor, Gen2BattleSwitchMenu.DEFAULT_CURSOR)


## Every field [Gen2PartyMenuPage] draws comes off the row rather than out of the
## battle, so the page never reaches back into one.
func test_a_row_carries_everything_the_page_draws() -> void:
	var party: Gen2Party = _party()
	party.at(1).take_damage(3)
	party.at(1).status = Gen2Status.POISON
	party.at(1).nickname = "BUDDY"
	var row: Dictionary = Gen2BattleSwitchMenu.for_party(party).rows[1]
	assert_eq(int(row["index"]), 1)
	assert_eq(String(row["name"]), "BUDDY", "PlacePartyNicknames prints the nickname")
	assert_eq(int(row["level"]), 20)
	assert_eq(int(row["hp"]), party.at(1).hp)
	assert_eq(int(row["max_hp"]), party.at(1).max_hp())
	assert_eq(int(row["status"]), Gen2Status.POISON)
	assert_false(bool(row["fainted"]))


## An egg keeps its party slot in the list and is refused with
## `BattleText_AnEGGCantBattle`; the members either side keep their battle index.
func test_an_egg_keeps_its_row_and_cannot_battle() -> void:
	var save := Gen2SaveData.new()
	for species: int in [Fixture.PIKACHU, Fixture.BULBASAUR, Fixture.GEODUDE]:
		var saved := Gen2SaveMon.new()
		saved.species = species
		save.party.append(saved)
	(save.party[1] as Gen2SaveMon).is_egg = true
	(save.party[1] as Gen2SaveMon).nickname = "EGG"
	var party: Gen2Party = Gen2Party.create([_mon(Fixture.PIKACHU), _mon(Fixture.GEODUDE)])
	var menu: Gen2BattleSwitchMenu = Gen2BattleSwitchMenu.for_party(party, false, save)
	assert_eq(menu.rows.size(), 3)
	assert_true(bool(menu.rows[1]["egg"]))
	assert_eq(String(menu.rows[1]["name"]), "EGG")
	assert_eq(int(menu.rows[2]["index"]), 1)
	menu.cursor = 1
	assert_eq(menu.confirm(), {
		"result": Gen2BattleSwitchMenu.EGG, "text": Gen2BattleSwitchMenu.egg_text(),
	})


## `PartyMenu2DMenuData`'s `_2DMENU_WRAP_UP_DOWN`, over the CANCEL row as well.
func test_the_cursor_wraps_through_cancel() -> void:
	var menu: Gen2BattleSwitchMenu = _menu()
	assert_true(menu.move(-1))
	assert_eq(menu.cursor, 3, "up from the first row reaches CANCEL")
	assert_true(menu.move(1))
	assert_eq(menu.cursor, 0)
	for _step: int in 3:
		menu.move(1)
	assert_eq(menu.cursor, 3)
	menu.move(1)
	assert_eq(menu.cursor, 0)


func test_a_standing_bench_member_is_the_answer() -> void:
	var menu: Gen2BattleSwitchMenu = _menu()
	menu.cursor = 1
	var answer: Dictionary = menu.confirm()
	assert_eq(answer["result"], Gen2BattleSwitchMenu.CHOSEN)
	assert_eq(int(answer["index"]), 1)


## `SwitchMonAlreadyOut` prints `BattleText_MonIsAlreadyOut` and jumps back to
## `.pick`, so the row is refused with a line rather than accepted.
func test_the_one_already_out_is_refused_by_name() -> void:
	var menu: Gen2BattleSwitchMenu = _menu()
	menu.cursor = 0
	var answer: Dictionary = menu.confirm()
	assert_eq(answer["result"], Gen2BattleSwitchMenu.ALREADY_OUT)
	assert_true(String(answer["text"]).contains("is already out"), String(answer["text"]))
	assert_true(String(answer["text"]).begins_with(menu.rows[0]["name"]))


## `CheckIfCurPartyMonIsFitToFight` prints `BattleText_TheresNoWillToBattle` and
## is `jr z, .loop` inside `PickPartyMonInBattle`, in front of the already-out
## check, so a fainted Pokémon is refused whichever variant asked.
func test_a_fainted_row_is_refused() -> void:
	var party: Gen2Party = _party()
	party.at(2).take_damage(party.at(2).max_hp())
	for forced: bool in [false, true]:
		var menu: Gen2BattleSwitchMenu = Gen2BattleSwitchMenu.for_party(party, forced)
		menu.cursor = 2
		var answer: Dictionary = menu.confirm()
		assert_eq(answer["result"], Gen2BattleSwitchMenu.NO_ENERGY)
		assert_eq(String(answer["text"]), Gen2BattleSwitchMenu.no_energy_text())


func test_cancel_backs_out_of_the_offer_list() -> void:
	var menu: Gen2BattleSwitchMenu = _menu()
	assert_eq(menu.cancel()["result"], Gen2BattleSwitchMenu.CANCELLED)
	menu.cursor = 3
	assert_eq(menu.confirm()["result"], Gen2BattleSwitchMenu.CANCELLED, "the CANCEL row")


## `ForcePickPartyMonInBattle` swallows the carry, plays `SFX_WRONG` and picks
## again, so neither B nor CANCEL leaves the Baton Pass list.
func test_the_forced_list_cannot_be_backed_out_of() -> void:
	var menu: Gen2BattleSwitchMenu = _menu(true)
	for answer: Dictionary in [menu.cancel(), _at(menu, 3).confirm()]:
		assert_eq(answer["result"], Gen2BattleSwitchMenu.CANNOT_CANCEL)
		assert_eq(int(answer["sfx"]), Gen2Sfx.SFX_WRONG)


func _at(menu: Gen2BattleSwitchMenu, cursor: int) -> Gen2BattleSwitchMenu:
	menu.cursor = cursor
	return menu


func test_a_party_of_one_is_a_list_of_one_and_cancel() -> void:
	var menu: Gen2BattleSwitchMenu = Gen2BattleSwitchMenu.for_party(
		Gen2Party.of(_mon(Fixture.PIKACHU))
	)
	assert_eq(menu.item_count(), 2)
	assert_eq(menu.confirm()["result"], Gen2BattleSwitchMenu.ALREADY_OUT)


## `data/text/battle.asm`'s `BattleText_TheresNoWillToBattle`,
## `BattleText_MonIsAlreadyOut`, `BattleText_UseNextMon` and
## `BattleText_EnemyIsAboutToUseWillPlayerChangeMon`, breaks and all.
func test_generation_two_refusals_are_the_battle_text_lines() -> void:
	var cont: String = Gen2TextStream.SCROLL_BREAK
	var para: String = Gen2TextStream.PAGE_BREAK
	assert_eq(Gen2BattleSwitchMenu.no_energy_text(), "There's no will to\nbattle!")
	assert_eq(Gen2BattleSwitchMenu.already_out_text("BUDDY"), "BUDDY\nis already out.")
	assert_eq(Gen2BattleSwitchMenu.use_next_text(), "Use next #MON?")
	assert_eq(
		Gen2BattleSwitchMenu.offer_text("FALKNER", "PIDGEY", "GOLD"),
		"FALKNER\nis about to use%sPIDGEY.%sWill GOLD\nchange #MON?" % [cont, para]
	)


## pokered's `data/text/text_2.asm`: `_NoWillText`, `_AlreadyOutText`,
## `_UseNextMonText` and `_TrainerAboutToUseText`, whose name shares the first
## line and whose Pokémon ends on `!`.
func test_generation_one_refusals_are_its_own_lines() -> void:
	var cont: String = Gen2TextStream.SCROLL_BREAK
	var para: String = Gen2TextStream.PAGE_BREAK
	assert_eq(Gen2BattleSwitchMenu.no_energy_text(true), "There's no will\nto fight!")
	assert_eq(Gen2BattleSwitchMenu.already_out_text("BUDDY", true), "BUDDY is\nalready out!")
	assert_eq(
		Gen2BattleSwitchMenu.offer_text("BROCK", "ONIX", "RED", true),
		"BROCK is\nabout to use%sONIX!%sWill RED\nchange #MON?" % [cont, para]
	)


## A Generation 1 party is refused in Generation 1's words, which the list reads
## off its lead rather than being told.
func test_a_generation_one_party_confirms_with_its_own_refusals() -> void:
	_data.generation = RomRegistry.GEN1
	var party: Gen2Party = _party()
	party.at(2).take_damage(party.at(2).max_hp())
	var menu: Gen2BattleSwitchMenu = Gen2BattleSwitchMenu.for_party(party)
	assert_true(menu.gen1)
	assert_eq(String(_at(menu, 2).confirm()["text"]), Gen2BattleSwitchMenu.no_energy_text(true))
	assert_eq(
		String(_at(menu, 0).confirm()["text"]),
		Gen2BattleSwitchMenu.already_out_text(String(menu.rows[0]["name"]), true)
	)


## `BattleMonMenu.MenuData`: three rows in the box `menu_coords 11, 11, 19, 17`
## places, opening on SWITCH.
func test_the_member_submenu_is_switch_stats_cancel() -> void:
	var menu: Gen2WorldMenu = Gen2BattleSwitchMenu.action_menu()
	assert_eq(menu.options, ["SWITCH", "STATS", "CANCEL"])
	assert_eq(menu.rows, 3)
	assert_eq(menu.cursor, 0)
	assert_eq(Gen2BattleSwitchMenu.ACTION_BOX, Rect2i(11, 11, 8, 6))
