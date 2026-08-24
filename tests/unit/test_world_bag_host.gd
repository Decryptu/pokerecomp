extends GutTest

## The item transactions no party, mart or script is behind: `TossItem`
## (`home/item.asm`) for the bag, and `engine/events/pokecenter_pc.asm`'s own
## deposit, withdraw and toss for `wPCItems`. Both commit through the same
## [Gen2WorldTransaction] boundary, and the PC's menus are checked here for the
## same reason: it is the file that owns the fixture they read.

const Fixture := preload("res://tests/integration/world_trainer_fixture.gd")

const POTION: int = 7
const KEY_ITEM: int = 8
## `MailItems`' first entry, at its real number: `ItemIsMail` checks the number,
## so a stand-in would not be mail at all.
const FLOWER_MAIL: int = 158

var _data: GameData = null
var _world: Gen2WorldAPI = null
var _save: Gen2SaveData = null


func before_each() -> void:
	_data = Fixture.build()
	_write_items()
	_data = GameData.open_directory(Fixture.directory())
	var state := Gen2WorldState.new({}, {}, {POTION: 5, KEY_ITEM: 1, FLOWER_MAIL: 1}, {0: 500})
	_world = Gen2WorldAPI.open(
		_data, Fixture.MAP_GROUP, Fixture.MAP_NUMBER, Vector2i(7, 6), state
	)
	_save = Gen2SaveStore.create_development_save(_data, 0)
	_save.world = _world.snapshot()


func after_each() -> void:
	RomCache.clear(Fixture.directory())


## A tossable stack and one `_CheckTossableItem` refuses, which is what the
## source's `ITEMATTR_PERMISSIONS` bit means: set is "cannot".
func _write_items() -> void:
	var items: Array = RomCache.read_json(RomCache.items_path(Fixture.directory()))
	for raw: Dictionary in items:
		match int(raw.get("number", 0)):
			POTION:
				raw["name"] = "POTION"
				raw["pocket"] = Gen2WorldPack.TYPE_ITEM
				raw["permissions"] = Gen2WorldPack.CANT_SELECT
				raw["field_menu"] = Gen2WorldPack.ITEMMENU_PARTY
			FLOWER_MAIL:
				raw["name"] = "FLOWER MAIL"
				raw["pocket"] = Gen2WorldPack.TYPE_ITEM
				raw["permissions"] = Gen2WorldPack.CANT_SELECT
				raw["field_menu"] = Gen2WorldPack.ITEMMENU_NOUSE
			KEY_ITEM:
				raw["name"] = "BICYCLE"
				raw["pocket"] = Gen2WorldPack.TYPE_KEY_ITEM
				raw["permissions"] = Gen2WorldPack.CANT_TOSS
				raw["field_menu"] = Gen2WorldPack.ITEMMENU_CURRENT
	RomCache.write_json(RomCache.items_path(Fixture.directory()), items)


## On the flat item model `_TossItem`'s whole pocket walk is one subtraction, and
## the stack it leaves behind is what the pack lists next.
func test_tossing_part_of_a_stack_leaves_the_rest() -> void:
	var result: Dictionary = Gen2WorldBagHost.toss(_world, _save, POTION, 2, false)
	assert_true(bool(result["ok"]), str(result))
	assert_eq(result["quantity"], 2)
	assert_eq(result["remaining"], 3)
	assert_eq(result["name"], "POTION")
	assert_eq(_world.state.item_quantity(POTION), 3)


func test_tossing_the_whole_stack_empties_it() -> void:
	assert_true(bool(Gen2WorldBagHost.toss(_world, _save, POTION, 5, false)["ok"]))
	assert_eq(_world.state.item_quantity(POTION), 0)
	for pocket: Dictionary in Gen2WorldPack.build(_data, _world.state):
		for entry: Dictionary in pocket.get("items", []):
			assert_ne(int(entry.get("item", 0)), POTION, "it is off the list")


## The quantity is `wCurItemQuantity`, which the dial has already clamped to the
## stack; a caller that is not that dial is refused rather than trusted.
func test_a_quantity_outside_the_stack_is_refused_and_changes_nothing() -> void:
	for quantity: int in [0, -1, 6, 99]:
		var result: Dictionary = Gen2WorldBagHost.toss(_world, _save, POTION, quantity, false)
		assert_false(bool(result["ok"]), "quantity %d" % quantity)
		assert_eq(result["reason"], &"invalid_toss_quantity")
	assert_eq(_world.state.item_quantity(POTION), 5)


## `_CheckTossableItem` is the first thing `.ItemBallsKey_LoadSubmenu` branches
## on, so an item that refuses it never has TOSS in its submenu at all.
func test_an_item_that_cannot_be_tossed_is_refused_at_both_ends() -> void:
	assert_false(Gen2WorldPack.can_toss(_data, KEY_ITEM))
	for entry: Dictionary in Gen2WorldPack.item_submenu(_data, KEY_ITEM):
		assert_ne(StringName(entry.get("action", &"")), Gen2WorldPack.ACTION_TOSS)
	var result: Dictionary = Gen2WorldBagHost.toss(_world, _save, KEY_ITEM, 1, false)
	assert_false(bool(result["ok"]))
	assert_eq(result["reason"], &"item_cannot_be_tossed")
	assert_eq(_world.state.item_quantity(KEY_ITEM), 1)


func test_an_unknown_item_is_refused() -> void:
	var result: Dictionary = Gen2WorldBagHost.toss(_world, _save, 250, 1, false)
	assert_false(bool(result["ok"]))
	assert_eq(result["reason"], &"unknown_item")


## The commit boundary is optional: a toss with no save behind it still changes
## the live world, which is what a screen without one does.
func test_a_toss_without_a_save_still_changes_the_world() -> void:
	assert_true(bool(Gen2WorldBagHost.toss(_world, null, POTION, 1, false)["ok"]))
	assert_eq(_world.state.item_quantity(POTION), 4)


## `Gen2WorldTransaction.run` puts the live world back when the candidate save
## refuses, so a refused toss leaves the stack where it was.
func test_a_refused_candidate_save_rolls_the_world_back() -> void:
	_save.party.clear()
	_save.player_name = ""
	var result: Dictionary = Gen2WorldBagHost.toss(_world, _save, POTION, 2, false)
	assert_false(bool(result["ok"]), str(result))
	assert_eq(_world.state.item_quantity(POTION), 5, "the stack is back")


## `PlayerDepositItemMenu` and `PlayerWithdrawItemMenu` are the same move in
## opposite directions, and the flat model keeps one stack per item on each side.
func test_a_stack_moves_between_the_bag_and_the_pc_and_back() -> void:
	var deposited: Dictionary = Gen2WorldPC.deposit(_world, _save, POTION, 2, false)
	assert_true(bool(deposited["ok"]), str(deposited))
	assert_eq(deposited["bag"], 3)
	assert_eq(deposited["pc"], 2)
	assert_eq(_world.state.item_quantity(POTION), 3)
	assert_eq(_world.state.pc_item_quantity(POTION), 2)

	var withdrawn: Dictionary = Gen2WorldPC.withdraw(_world, _save, POTION, 2, false)
	assert_true(bool(withdrawn["ok"]), str(withdrawn))
	assert_eq(_world.state.item_quantity(POTION), 5)
	assert_eq(_world.state.pc_item_quantity(POTION), 0, "an emptied stack is gone")


## `.no_toss` keeps a key item out of the PC, which is the same permission bit
## TOSS reads.
func test_a_key_item_cannot_be_deposited() -> void:
	var result: Dictionary = Gen2WorldPC.deposit(_world, _save, KEY_ITEM, 1, false)
	assert_false(bool(result["ok"]))
	assert_eq(result["reason"], &"item_cannot_be_deposited")
	assert_eq(_world.state.pc_item_quantity(KEY_ITEM), 0)


## `.NoRoomInPC`: `ReceiveItem` fails before anything leaves the bag, so a full
## PC leaves the stack where it was.
func test_a_full_pc_refuses_a_new_stack_without_taking_it() -> void:
	var full: Dictionary = {}
	for slot: int in Gen2WorldPack.MAX_PC_ITEMS:
		full[slot + 20] = 1
	assert_true(bool(_world.state.apply_changes({}, {}, {"pc_items": full})["ok"]))
	var result: Dictionary = Gen2WorldPC.deposit(_world, _save, POTION, 1, false)
	assert_false(bool(result["ok"]))
	assert_eq(result["reason"], &"pc_full")
	assert_eq(_world.state.item_quantity(POTION), 5)


## `TossItemFromPC` is `TossItem` on the other array, and reads `CanToss` the
## same way.
func test_the_pc_tosses_its_own_stack() -> void:
	assert_true(bool(Gen2WorldPC.deposit(_world, _save, POTION, 3, false)["ok"]))
	var result: Dictionary = Gen2WorldPC.toss(_world, _save, POTION, 1, false)
	assert_true(bool(result["ok"]), str(result))
	assert_eq(_world.state.pc_item_quantity(POTION), 2)
	assert_eq(_world.state.item_quantity(POTION), 2, "the bag is not touched")


## `.ChooseWhichPCListToUse`: the Pokedex adds PROF.OAK'S PC and the induction
## adds HALL OF FAME.
func test_the_top_menu_grows_with_the_dex_and_the_hall_of_fame() -> void:
	var rows: Callable = func() -> Array:
		var out: Array = []
		for row: Dictionary in Gen2WorldPC.top_menu(_data, _world.state, "GOLD"):
			out.append(int(row["row"]))
		return out
	assert_eq(Gen2WorldPC.top_menu_list(_world.state), Gen2WorldPC.PCPC_BEFORE_POKEDEX)
	assert_eq(rows.call(), [
		Gen2WorldPC.PCPCITEM_BILLS_PC, Gen2WorldPC.PCPCITEM_PLAYERS_PC,
		Gen2WorldPC.PCPCITEM_TURN_OFF,
	])
	assert_eq(
		String(Gen2WorldPC.top_menu(_data, _world.state, "GOLD")[1]["name"]), "GOLD's PC"
	)

	_world.state.set_engine_flag(Gen2WorldState.ENGINE_POKEDEX, true)
	assert_eq(Gen2WorldPC.top_menu_list(_world.state), Gen2WorldPC.PCPC_BEFORE_HOF)
	assert_true(Gen2WorldPC.PCPCITEM_OAKS_PC in rows.call())

	_world.state.set_hall_of_fame(true)
	assert_eq(Gen2WorldPC.top_menu_list(_world.state), Gen2WorldPC.PCPC_POSTGAME)
	assert_true(Gen2WorldPC.PCPCITEM_HALL_OF_FAME in rows.call())


## `GetHallOfFameParty` and `AddHallOfFameEntry`: eggs are skipped, the newest
## team is at the front, and `wHallOfFameCount` counts the inductions rather
## than the records.
func test_an_induction_records_the_party_newest_first() -> void:
	(_save.party[0] as Gen2SaveMon).nickname = "FIRST"
	var records: Array = Gen2HallOfFame.inducted([], _save)
	assert_eq(records.size(), 1)
	assert_eq(int(records[0]["win_count"]), 1)
	assert_eq(int(records[0]["mons"].size()), _save.party.size())
	assert_eq(String(records[0]["mons"][0]["nickname"]), "FIRST")

	(_save.party[0] as Gen2SaveMon).nickname = "SECOND"
	records = Gen2HallOfFame.inducted(records, _save)
	assert_eq(records.size(), 2)
	assert_eq(int(records[0]["win_count"]), 2)
	assert_eq(String(records[0]["mons"][0]["nickname"]), "SECOND")
	assert_eq(String(records[1]["mons"][0]["nickname"]), "FIRST")
	assert_eq(Gen2HallOfFame.win_count(records), 2)

	## `sHallOfFame` holds thirty and the oldest falls off the end.
	for _step: int in Gen2HallOfFame.MAX_RECORDS:
		records = Gen2HallOfFame.inducted(records, _save)
	assert_eq(records.size(), Gen2HallOfFame.MAX_RECORDS)
	assert_eq(Gen2HallOfFame.win_count(records), 2 + Gen2HallOfFame.MAX_RECORDS)

	## `_HallOfFamePC.DisplayMonAndStrings` draws the count on every panel of the
	## record it belongs to, which is the one line an induction has no room for.
	var pages: Array = Gen2HallOfFame.record_pages(_data, records[0])
	assert_eq(pages.size(), records[0]["mons"].size())
	assert_eq(int(pages[0]["win_count"]), Gen2HallOfFame.win_count(records))
	assert_eq(
		Gen2SaveData.from_dict(_save.to_dict()).hall_of_fame.size(), 0,
		"nothing is stored until an induction writes it"
	)
	_save.hall_of_fame = records
	var reopened: Gen2SaveData = Gen2SaveData.from_dict(_save.to_dict())
	assert_eq(reopened.hall_of_fame.size(), Gen2HallOfFame.MAX_RECORDS)
	assert_eq(String(reopened.hall_of_fame[0]["mons"][0]["nickname"]), "SECOND")


## `PlayersPCMenuData.WhichPC`: the bedroom's list ends in TURN OFF, a Pokemon
## Center's in LOG OFF, because the top menu is still open behind it.
func test_the_item_pc_ends_in_log_off_only_inside_the_pokemon_center() -> void:
	var last: Callable = func(house: bool) -> int:
		var menu: Array = Gen2WorldPC.players_pc_menu(_data, house)
		return int(menu[menu.size() - 1]["row"])
	assert_eq(last.call(false), Gen2WorldPC.PLAYERSPCITEM_LOG_OFF)
	assert_eq(last.call(true), Gen2WorldPC.PLAYERSPCITEM_TURN_OFF)


## `PC_CheckPartyForPokemon`, which is the one refusal the top menu owns.
func test_an_empty_party_cannot_open_the_pokemon_centers_pc() -> void:
	assert_true(Gen2WorldPC.can_open(_save))
	_save.party.clear()
	assert_false(Gen2WorldPC.can_open(_save))


## `TryGiveItemToPartymon`'s `.give_item_to_mon`: one out of the bag, one into
## the hand.
func test_giving_an_item_takes_it_out_of_the_bag() -> void:
	var result: Dictionary = Gen2WorldBagHost.give_to_party(_world, _save, POTION, 0, false, false)
	assert_true(bool(result["ok"]), str(result))
	assert_eq(result["held"], 0)
	assert_eq(_world.state.item_quantity(POTION), 4)
	assert_eq((_save.party[0] as Gen2SaveMon).item, POTION)


## The refusal `PokemonAskSwapItemText` is asked over: the source stops to ask
## before it writes anything, so an unanswered swap leaves both items alone.
func test_a_full_hand_is_refused_until_the_swap_is_answered() -> void:
	(_save.party[0] as Gen2SaveMon).item = KEY_ITEM
	var asked: Dictionary = Gen2WorldBagHost.give_to_party(_world, _save, POTION, 0, false, false)
	assert_false(bool(asked["ok"]))
	assert_eq(asked["reason"], &"already_holding")
	assert_eq(int((asked["details"] as Dictionary)["held"]), KEY_ITEM)
	assert_eq(_world.state.item_quantity(POTION), 5)
	assert_eq((_save.party[0] as Gen2SaveMon).item, KEY_ITEM)

	var swapped: Dictionary = Gen2WorldBagHost.give_to_party(_world, _save, POTION, 0, true, false)
	assert_true(bool(swapped["ok"]), str(swapped))
	assert_eq(swapped["held"], KEY_ITEM)
	assert_eq(_world.state.item_quantity(POTION), 4)
	assert_eq(_world.state.item_quantity(KEY_ITEM), 2)
	assert_eq((_save.party[0] as Gen2SaveMon).item, POTION)


## `.GiveItem` refuses the key item pocket before `TryGiveItemToPartymon` ever
## runs, and an egg is refused by `GiveItem`'s own `cp EGG`.
func test_a_key_item_and_an_egg_are_both_refused() -> void:
	var key: Dictionary = Gen2WorldBagHost.give_to_party(_world, _save, KEY_ITEM, 0, false, false)
	assert_false(bool(key["ok"]))
	assert_eq(key["reason"], &"item_cannot_be_held")

	(_save.party[0] as Gen2SaveMon).is_egg = true
	var egg: Dictionary = Gen2WorldBagHost.give_to_party(_world, _save, POTION, 0, false, false)
	assert_false(bool(egg["ok"]))
	assert_eq(egg["reason"], &"cannot_hold_egg")
	assert_eq(_world.state.item_quantity(POTION), 5)


## `TakePartyItem`, and `PokemonNotHoldingText` for an empty hand.
func test_taking_an_item_puts_it_back_in_the_bag() -> void:
	assert_eq(
		StringName(Gen2WorldBagHost.take_from_party(_world, _save, 0, false)["reason"]),
		&"not_holding"
	)
	(_save.party[0] as Gen2SaveMon).item = POTION
	var result: Dictionary = Gen2WorldBagHost.take_from_party(_world, _save, 0, false)
	assert_true(bool(result["ok"]), str(result))
	assert_eq(result["name"], "POTION")
	assert_eq(_world.state.item_quantity(POTION), 6)
	assert_eq((_save.party[0] as Gen2SaveMon).item, 0)


## `RegisterItem` checks `CheckSelectableItem`, and `CheckRegisteredItem` clears
## a registration the pack can no longer answer.
func test_a_registration_lasts_while_the_item_is_owned() -> void:
	var refused: Dictionary = Gen2WorldBagHost.register(_world, _save, POTION, false)
	assert_false(bool(refused["ok"]))
	assert_eq(refused["reason"], &"item_cannot_be_registered")

	assert_true(bool(Gen2WorldBagHost.register(_world, _save, KEY_ITEM, false)["ok"]))
	assert_eq(_world.state.registered_item(), KEY_ITEM)
	assert_eq(Gen2WorldBagHost.registered_item(_world), KEY_ITEM)

	_world.state.apply_changes({}, {}, {"items": {KEY_ITEM: 0}})
	assert_eq(Gen2WorldBagHost.registered_item(_world), 0)
	assert_eq(_world.state.registered_item(), 0, "the check clears it where it looks")


## `.FindCategoriesWithOwnedDecos`: only a category with an owned decoration is
## on the top menu, and EXIT is its last row whether or not anything is.
func test_the_decoration_menu_offers_only_categories_with_something_in_them() -> void:
	var categories: Array = Gen2WorldDecoration.categories(_data, _world.state)
	assert_eq(categories.size(), 1, JSON.stringify(categories))
	assert_eq(String(categories[0]["name"]), Gen2WorldDecoration.CATEGORY_EXIT)

	Gen2WorldDecoration.set_owned(_data, _world.state, Fixture.DECO_FEATHERY_BED)
	categories = Gen2WorldDecoration.categories(_data, _world.state)
	assert_eq(categories.size(), 2, JSON.stringify(categories))
	assert_eq(StringName(categories[0]["slot"]), Gen2WorldDecoration.SLOT_BED)


## `FindOwnedDecosInCategory` appends the category's PUT IT AWAY and then
## CANCEL, so an owned row is never the whole list.
func test_a_category_list_ends_in_put_it_away_and_cancel() -> void:
	Gen2WorldDecoration.set_owned(_data, _world.state, Fixture.DECO_FEATHERY_BED)
	var rows: Array = Gen2WorldDecoration.category_rows(
		_data, _world.state, Gen2WorldDecoration.SLOT_BED
	)
	assert_eq(rows.size(), 3, JSON.stringify(rows))
	assert_eq(int(rows[0]["deco"]), Fixture.DECO_FEATHERY_BED)
	assert_true(Gen2WorldDecoration.is_put_away(_data, int(rows[1]["deco"])))
	assert_eq(int(rows[2]["deco"]), 0)


## `DecoAction_TrySetItUp` and `DecoAction_TryPutItAway` over one slot, and the
## `.alreadythere` refusal that leaves it where it is.
func test_setting_a_decoration_up_and_putting_it_away_move_one_slot() -> void:
	Gen2WorldDecoration.set_owned(_data, _world.state, Fixture.DECO_FEATHERY_BED)
	var refused: Dictionary = Gen2WorldDecoration.apply(
		_world, _save, Fixture.DECO_SURF_PIKACHU_DOLL,
		Gen2WorldDecoration.SLOT_LEFT_ORNAMENT, false
	)
	assert_eq(
		StringName(refused.get("reason", &"")), &"decoration_not_owned",
		"an unowned row cannot be set up"
	)

	var set_up: Dictionary = Gen2WorldDecoration.apply(
		_world, _save, Fixture.DECO_FEATHERY_BED, &"", false
	)
	assert_true(bool(set_up["ok"]), str(set_up))
	assert_true(bool(set_up["changed"]))
	assert_eq(
		_world.state.maptile_decoration(Gen2WorldDecoration.SLOT_BED),
		Fixture.DECO_FEATHERY_BED
	)

	var again: Dictionary = Gen2WorldDecoration.apply(
		_world, _save, Fixture.DECO_FEATHERY_BED, &"", false
	)
	assert_false(bool(again["changed"]))
	assert_eq(String(again["text"]), Gen2WorldDecoration.TEXT_ALREADY_SET_UP)

	var put_away: Dictionary = Gen2WorldDecoration.apply(
		_world, _save, _put_away_row(Gen2WorldDecoration.SLOT_BED), &"", false
	)
	assert_true(bool(put_away["changed"]))
	assert_eq(_world.state.maptile_decoration(Gen2WorldDecoration.SLOT_BED), 0)
	assert_eq(
		String(
			Gen2WorldDecoration.apply(
				_world, _save, _put_away_row(Gen2WorldDecoration.SLOT_BED), &"", false
			)["text"]
		),
		Gen2WorldDecoration.TEXT_NOTHING_TO_PUT_AWAY
	)


## `DecoAction_setupornament` asks which side, and
## `DecoAction_SetItUp_Ornament.getwhichside` takes the same doll off the other
## one rather than standing two of it.
func test_an_ornament_takes_a_side_and_leaves_the_other() -> void:
	Gen2WorldDecoration.set_owned(_data, _world.state, Fixture.DECO_PIKACHU_DOLL)
	assert_true(Gen2WorldDecoration.asks_side(_data, Fixture.DECO_PIKACHU_DOLL))
	assert_eq(
		StringName(
			Gen2WorldDecoration.apply(
				_world, _save, Fixture.DECO_PIKACHU_DOLL, &"", false
			)["reason"]
		),
		&"decoration_side_required"
	)

	assert_true(bool(Gen2WorldDecoration.apply(
		_world, _save, Fixture.DECO_PIKACHU_DOLL,
		Gen2WorldDecoration.SLOT_LEFT_ORNAMENT, false
	)["ok"]))
	assert_true(bool(Gen2WorldDecoration.apply(
		_world, _save, Fixture.DECO_PIKACHU_DOLL,
		Gen2WorldDecoration.SLOT_RIGHT_ORNAMENT, false
	)["ok"]))
	assert_eq(
		_world.state.maptile_decoration(Gen2WorldDecoration.SLOT_LEFT_ORNAMENT), 0,
		"the doll left the side it was on"
	)
	assert_eq(
		_world.state.maptile_decoration(Gen2WorldDecoration.SLOT_RIGHT_ORNAMENT),
		Fixture.DECO_PIKACHU_DOLL
	)


func _put_away_row(slot: StringName) -> int:
	for deco: int in _data.decoration_count():
		if Gen2WorldDecoration.slot_of(_data, deco) == slot \
			and Gen2WorldDecoration.is_put_away(_data, deco):
			return deco
	return -1


## `GivePartyItem`'s tail: a mail item is only handed over with the message
## `ComposeMailMessage` wrote, and the message travels on the record.
func test_mail_is_only_given_with_a_message_behind_it() -> void:
	var refused: Dictionary = Gen2WorldBagHost.give_to_party(
		_world, _save, FLOWER_MAIL, 0, false, false
	)
	assert_false(bool(refused["ok"]))
	assert_eq(refused["reason"], &"mail_not_written")
	assert_eq(_world.state.item_quantity(FLOWER_MAIL), 1)

	var mail: Gen2SaveMail = Gen2SaveMail.compose(
		Gen2SaveMail.blank_message(), "GOLD", 0x1234, 1, FLOWER_MAIL
	)
	var given: Dictionary = Gen2WorldBagHost.give_to_party(
		_world, _save, FLOWER_MAIL, 0, false, false, mail
	)
	assert_true(bool(given["ok"]), str(given))
	assert_eq(_world.state.item_quantity(FLOWER_MAIL), 0)
	assert_eq((_save.party[0] as Gen2SaveMon).item, FLOWER_MAIL)
	assert_eq((_save.party[0] as Gen2SaveMon).mail.author, "GOLD")


## `.please_remove_mail`, which is asked in front of `PokemonAskSwapItemText`:
## a held mail is not offered as a swap at all.
func test_a_member_holding_mail_is_refused_rather_than_asked_to_swap() -> void:
	var mon: Gen2SaveMon = _save.party[0]
	mon.item = FLOWER_MAIL
	mon.mail = Gen2SaveMail.compose(
		Gen2SaveMail.blank_message(), "GOLD", 0x1234, mon.species, FLOWER_MAIL
	)
	for swap: bool in [false, true]:
		var result: Dictionary = Gen2WorldBagHost.give_to_party(
			_world, _save, POTION, 0, swap, false
		)
		assert_false(bool(result["ok"]))
		assert_eq(result["reason"], &"holding_mail")
	assert_eq(_world.state.item_quantity(POTION), 5)


## `TakePartyItem` puts the item in the bag and says nothing about the message,
## so the message goes with it: a record left holding mail with no item is one
## the MAIL row could still read.
func test_taking_a_mail_item_takes_its_message_with_it() -> void:
	var mon: Gen2SaveMon = _save.party[0]
	mon.item = FLOWER_MAIL
	mon.mail = Gen2SaveMail.compose(
		Gen2SaveMail.blank_message(), "GOLD", 0x1234, mon.species, FLOWER_MAIL
	)
	var result: Dictionary = Gen2WorldBagHost.take_from_party(_world, _save, 0, false)
	assert_true(bool(result["ok"]), str(result))
	assert_eq((_save.party[0] as Gen2SaveMon).item, 0)
	assert_null((_save.party[0] as Gen2SaveMon).mail)
	assert_eq(_world.state.item_quantity(FLOWER_MAIL), 2)


## `SendMailToPC`, `DeleteMailFromPC` and `MoveMailFromPCToParty`, which is the
## whole of what MAIL BOX moves.
func test_mail_moves_between_a_member_and_the_mailbox() -> void:
	var mon: Gen2SaveMon = _save.party[0]
	mon.item = FLOWER_MAIL
	mon.mail = Gen2SaveMail.compose(
		Gen2SaveMail.blank_message(), "GOLD", 0x1234, mon.species, FLOWER_MAIL
	)
	assert_true(Gen2SaveMail.any_mon_holding_mail(_save))
	var sent: Dictionary = Gen2WorldPC.mailbox_send(_world, _save, 0, false)
	assert_true(bool(sent["ok"]), str(sent))
	assert_eq(_save.mailbox.size(), 1)
	assert_eq((_save.party[0] as Gen2SaveMon).item, 0)
	assert_null((_save.party[0] as Gen2SaveMon).mail)
	assert_false(Gen2SaveMail.any_mon_holding_mail(_save))

	## `.AttachMail` refuses a member already holding an item without moving
	## anything, which is `.MailAlreadyHoldingItemText`.
	(_save.party[0] as Gen2SaveMon).item = POTION
	var refused: Dictionary = Gen2WorldPC.mailbox_attach(_world, _save, 0, 0, false)
	assert_false(bool(refused["ok"]))
	assert_eq(refused["reason"], &"already_holding")
	assert_eq(_save.mailbox.size(), 1)

	(_save.party[0] as Gen2SaveMon).item = 0
	var attached: Dictionary = Gen2WorldPC.mailbox_attach(_world, _save, 0, 0, false)
	assert_true(bool(attached["ok"]), str(attached))
	assert_eq(_save.mailbox.size(), 0)
	assert_eq((_save.party[0] as Gen2SaveMon).item, FLOWER_MAIL)
	assert_eq((_save.party[0] as Gen2SaveMon).mail.author, "GOLD")


## `.PutInPack`: `ReceiveItem` first, so a full pack leaves the message where it
## is, and the mailbox entry is only deleted once the item has arrived.
func test_putting_mail_in_the_pack_deletes_it_and_keeps_the_item() -> void:
	_save.mailbox.append(Gen2SaveMail.compose(
		Gen2SaveMail.blank_message(), "GOLD", 0x1234, 1, FLOWER_MAIL
	))
	var result: Dictionary = Gen2WorldPC.mailbox_to_pack(_world, _save, 0, false)
	assert_true(bool(result["ok"]), str(result))
	assert_eq(result["item"], FLOWER_MAIL)
	assert_eq(_save.mailbox.size(), 0)
	assert_eq(_world.state.item_quantity(FLOWER_MAIL), 2)


## `GetMailboxCount` against `MAILBOX_CAPACITY`, which is `SendMailToPC`'s only
## refusal.
func test_a_full_mailbox_refuses_the_next_message() -> void:
	for _index: int in Gen2SaveMail.CAPACITY:
		_save.mailbox.append(Gen2SaveMail.compose(
			Gen2SaveMail.blank_message(), "GOLD", 0x1234, 1, FLOWER_MAIL
		))
	var mon: Gen2SaveMon = _save.party[0]
	mon.item = FLOWER_MAIL
	mon.mail = Gen2SaveMail.compose(
		Gen2SaveMail.blank_message(), "GOLD", 0x1234, mon.species, FLOWER_MAIL
	)
	var sent: Dictionary = Gen2WorldPC.mailbox_send(_world, _save, 0, false)
	assert_false(bool(sent["ok"]))
	assert_eq(sent["reason"], &"mailbox_full")
	assert_eq((_save.party[0] as Gen2SaveMon).item, FLOWER_MAIL)
