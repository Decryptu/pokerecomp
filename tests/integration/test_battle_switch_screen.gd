extends GutTest


const Fixture := preload("res://tests/integration/world_trainer_fixture.gd")
const BattleFixture := preload("res://tests/unit/battle_fixture.gd")

var _data: GameData = null
var _screen: Gen2BattleScreen = null
var _rng := RandomNumberGenerator.new()


func before_each() -> void:
	Gen2ModHost.reset()
	Fixture.build()
	_data = GameData.open_directory(Fixture.directory())
	_rng.seed = 5


func after_each() -> void:
	if is_instance_valid(_screen):
		_screen.free()
		_screen = null
	RomCache.clear(Fixture.directory())
	Gen2ModHost.reset()


func _mon(species: int, moves: Array) -> Gen2BattleMon:
	return Gen2BattleMon.create(_data, species, 20, moves)


func _open(battle: Gen2Battle, actions: Array) -> void:
	var packed: PackedScene = load("res://game/battle/battle_screen.tscn")
	_screen = packed.instantiate() as Gen2BattleScreen
	_screen.set_data(_data)
	## The way the world hosts a fight: every frame is spent through
	## `advance_hardware_frame`, and nothing runs off real time between them.
	_screen.set_driven(true)
	add_child(_screen)
	await get_tree().process_frame
	_screen.show_matchup(BattleFixture.GEODUDE, BattleFixture.PIKACHU, 20, 20)
	_screen.set("_battle", battle)
	_screen.set("_pending", battle.take_actions(actions[0], actions[1]))
	await get_tree().process_frame


## A trainer battle with a bench on both sides, whose lead falls to the first
## SWIFT: `HandleEnemyMonFaint`'s `EnemySwitch` is the one caller that reaches
## `CheckWhetherToAskSwitch` with `wBattleHasJustStarted` clear.
func _trainer_battle(shift: bool) -> Gen2Battle:
	var battle: Gen2Battle = _faint_battle(true, false)
	battle.battle_style_set = not shift
	return battle


func _settle_bars() -> void:
	var guard: int = 4000
	while _screen.frames_running() and guard > 0:
		_screen.advance_frame()
		guard -= 1


func _stage() -> String:
	return String(_screen.battle_snapshot()["switch_stage"])


func _cursor() -> int:
	return int(_screen.battle_snapshot()["switch_cursor"])


func _layer() -> TextureRect:
	return _screen.get("_menu_layer")


func _advance_to(stage: String, limit: int = 40) -> void:
	for _press: int in limit:
		## Settled first: the frames a turn owes can reach the state by
		## themselves, and a press spent after it has arrived is a press into
		## whatever the state opened.
		_settle_bars()
		if _stage() == stage:
			return
		_screen.finish()
		_screen.advance()
		await get_tree().process_frame


func _read_question() -> void:
	var box: Gen2TextBox = _screen.get("_box")
	while box != null and (box.is_revealing() or box.has_pages_left()):
		if box.is_revealing():
			_screen.advance_hardware_frame()
		else:
			_screen._handle_button(PokeButton.A)
	_screen.advance_hardware_frame()
	await get_tree().process_frame


func _step(button: int) -> void:
	_settle_bars()
	# A press cannot finish a printing page, so the page is read first, which is
	# what a player waits through.
	_screen.finish()
	_screen._handle_button(button)
	_spend_yes_no_hold()
	await get_tree().process_frame


## `InterpretTwoOptionMenu`'s hold behind an answered question, and a
## medicine's bar and `ItemActionTextWaitButton` hold before its press is read.
func _spend_yes_no_hold() -> void:
	var offer: Gen2WorldMenu = _screen.get("_switch_offer")
	while offer != null and offer.holding():
		_screen.advance_hardware_frame()
	var result: Dictionary = _screen.get("_item_result")
	while result.has("anim") or int(result.get("hold", 0)) > 0:
		_screen.advance_hardware_frame()
		result = _screen.get("_item_result")


## `OfferSwitch` prints the question and only then places the box, so the two
## paragraphs cannot be answered before they have been read.
func test_shift_puts_the_question_up_before_its_yes_no_box() -> void:
	var battle: Gen2Battle = _trainer_battle(true)
	await _open(battle, [Gen2Battle.use_move(0), Gen2Battle.use_move(0)])
	await _advance_to("offer")

	assert_eq(_stage(), "offer")
	assert_true(
		String(_screen.battle_snapshot()["message"]).contains("change #MON?"),
		String(_screen.battle_snapshot()["message"])
	)
	assert_false(_layer().visible, "the box is not up while the question is printing")

	await _read_question()
	assert_true(_layer().visible, "and is once it has been read")
	assert_eq(_cursor(), 0, "YesNoMenuHeader opens on YES")


## NO is `.said_no`: the trainer's Pokémon comes in and the player's stays,
## which is what SET would have done without asking.
func test_no_sends_the_trainer_out_and_leaves_the_player_standing() -> void:
	var battle: Gen2Battle = _trainer_battle(true)
	await _open(battle, [Gen2Battle.use_move(0), Gen2Battle.use_move(0)])
	await _advance_to("offer")
	await _read_question()

	await _step(PokeButton.DOWN)
	assert_eq(_cursor(), 1)
	await _step(PokeButton.A)

	assert_eq(_stage(), "", "the question is answered")
	assert_eq(battle.awaiting_switch_offer(), -1)
	assert_eq(battle.party(Gen2Battle.ENEMY).active, 1)
	assert_eq(battle.party(Gen2Battle.PLAYER).active, 0)
	assert_false(_layer().visible)


## `InterpretTwoOptionMenu` returns carry on B, which `OfferSwitch` reads as no.
func test_b_is_the_same_answer_as_no() -> void:
	var battle: Gen2Battle = _trainer_battle(true)
	await _open(battle, [Gen2Battle.use_move(0), Gen2Battle.use_move(0)])
	await _advance_to("offer")
	await _read_question()

	await _step(PokeButton.B)
	assert_eq(_stage(), "")
	assert_eq(battle.party(Gen2Battle.PLAYER).active, 0)


## YES is `SetUpBattlePartyMenu` and `PickSwitchMonInBattle`: the party list, and
## the row chosen there is the switch.
func test_yes_opens_the_party_list_and_the_chosen_row_switches() -> void:
	var battle: Gen2Battle = _trainer_battle(true)
	await _open(battle, [Gen2Battle.use_move(0), Gen2Battle.use_move(0)])
	await _advance_to("offer")
	await _read_question()

	await _step(PokeButton.A)
	assert_eq(_stage(), "pick")
	assert_true(_layer().visible)
	assert_eq(_layer().position, Vector2.ZERO, "the list is the whole screen")
	assert_false((_screen.get("_box") as Gen2TextBox).visible, "and the battle's box is not")

	await _step(PokeButton.DOWN)
	assert_eq(_cursor(), 1)
	await _step(PokeButton.A)

	assert_eq(_stage(), "")
	assert_eq(battle.party(Gen2Battle.PLAYER).active, 1, "the player switched too")
	assert_eq(battle.party(Gen2Battle.ENEMY).active, 1)
	assert_true((_screen.get("_box") as Gen2TextBox).visible)


## `SwitchMonAlreadyOut` is `jr c, .pick`: the line is printed over the list and
## the list comes back rather than the question being answered.
func test_the_one_already_out_is_refused_and_the_list_comes_back() -> void:
	var battle: Gen2Battle = _trainer_battle(true)
	await _open(battle, [Gen2Battle.use_move(0), Gen2Battle.use_move(0)])
	await _advance_to("offer")
	await _read_question()
	await _step(PokeButton.A)

	await _step(PokeButton.A)
	assert_eq(_stage(), "refused")
	assert_true(
		String(_screen.battle_snapshot()["message"]).contains("is already out"),
		String(_screen.battle_snapshot()["message"])
	)
	assert_eq(battle.awaiting_switch_offer(), 1, "and nothing was answered")

	## One press, which is the one `StdBattleTextbox` was waiting for: the line is
	## read first and a press cannot shorten the reading.
	await _step(PokeButton.A)
	assert_eq(_stage(), "pick", "the list is redrawn")
	assert_true(_layer().visible)


## CANCEL is `OfferSwitch.canceled_switch`, which falls into `.said_no`.
func test_cancelling_the_list_is_the_same_answer_as_no() -> void:
	var battle: Gen2Battle = _trainer_battle(true)
	await _open(battle, [Gen2Battle.use_move(0), Gen2Battle.use_move(0)])
	await _advance_to("offer")
	await _read_question()
	await _step(PokeButton.A)

	await _step(PokeButton.B)
	assert_eq(_stage(), "")
	assert_eq(battle.party(Gen2Battle.PLAYER).active, 0)
	assert_eq(battle.party(Gen2Battle.ENEMY).active, 1)


## SET is the whole of `CheckWhetherToAskSwitch`'s third refusal, so no menu is
## ever opened and the turn runs on.
func test_set_never_opens_a_menu() -> void:
	var battle: Gen2Battle = _trainer_battle(false)
	await _open(battle, [Gen2Battle.use_move(0), Gen2Battle.use_move(0)])
	await _advance_to("offer", 20)
	assert_eq(_stage(), "")
	assert_eq(battle.party(Gen2Battle.ENEMY).active, 1)


func _baton_pass_battle() -> Gen2Battle:
	return Gen2Battle.create_parties(
		_data,
		Gen2Party.create([
			_mon(BattleFixture.PIKACHU, [BattleFixture.BATON_PASS]),
			_mon(BattleFixture.BULBASAUR, [BattleFixture.TACKLE]),
		]),
		Gen2Party.of(_mon(BattleFixture.GEODUDE, [BattleFixture.TACKLE])),
		_rng, false
	)


## `ForcePickSwitchMonInBattle` cannot be backed out of: neither B nor the CANCEL
## row leaves the list, and the turn stays standing behind it.
func test_baton_pass_opens_a_list_that_cannot_be_backed_out_of() -> void:
	var battle: Gen2Battle = _baton_pass_battle()
	await _open(battle, [Gen2Battle.use_move(0), Gen2Battle.use_move(0)])
	await _advance_to("pick")

	assert_eq(_stage(), "pick")
	assert_true(bool(_screen.battle_snapshot()["switch_forced"]))
	assert_eq(battle.awaiting_baton_pass(), Gen2Battle.PLAYER)

	await _step(PokeButton.B)
	assert_eq(_stage(), "pick", "B is swallowed")
	assert_eq(battle.awaiting_baton_pass(), Gen2Battle.PLAYER)

	## Two rows and CANCEL, so two presses down reach it.
	await _step(PokeButton.DOWN)
	await _step(PokeButton.DOWN)
	assert_eq(_cursor(), 2)
	await _step(PokeButton.A)
	assert_eq(_stage(), "pick", "and so is the CANCEL row")

	await _step(PokeButton.UP)
	await _step(PokeButton.A)
	assert_eq(_stage(), "")
	assert_eq(battle.awaiting_baton_pass(), -1)
	assert_eq(battle.party(Gen2Battle.PLAYER).active, 1, "the pass landed on the row chosen")


## The enemy's own Baton Pass is `FindMonInOTPartyToSwitchIntoBattle`, the AI's
## pick, and opens no menu at all.
func test_the_enemys_baton_pass_is_answered_by_its_own_ai() -> void:
	var battle: Gen2Battle = Gen2Battle.create_parties(
		_data,
		Gen2Party.of(_mon(BattleFixture.PIKACHU, [BattleFixture.TACKLE])),
		Gen2Party.create([
			_mon(BattleFixture.GEODUDE, [BattleFixture.BATON_PASS]),
			_mon(BattleFixture.CHARMANDER, [BattleFixture.TACKLE]),
		]),
		_rng, true
	)
	await _open(battle, [Gen2Battle.use_move(0), Gen2Battle.use_move(0)])
	await _advance_to("pick", 20)

	assert_eq(_stage(), "", "no menu was opened for the other side")
	assert_eq(battle.awaiting_baton_pass(), -1)
	assert_eq(battle.party(Gen2Battle.ENEMY).active, 1)


## A faint with somebody behind it, arranged so the turn cannot go the other way:
## Swift never rolls accuracy and one hit point cannot survive it.
func _faint_battle(trainer: bool, faint_player: bool) -> Gen2Battle:
	var battle: Gen2Battle = Gen2Battle.create_parties(
		_data,
		Gen2Party.create([
			_mon(BattleFixture.PIKACHU, [BattleFixture.SWIFT]),
			_mon(BattleFixture.BULBASAUR, [BattleFixture.TACKLE]),
		]),
		Gen2Party.create([
			_mon(BattleFixture.GEODUDE, [BattleFixture.SWIFT]),
			_mon(BattleFixture.CHARMANDER, [BattleFixture.TACKLE]),
		]),
		_rng, trainer
	)
	battle.battle_style_set = false
	if faint_player:
		battle.player.hp = 1
	else:
		battle.enemy.hp = 1
	return battle


## `AskUseNextPokemon`: the question, then the same `lb bc, 1, 7` box
## `OfferSwitch` uses, and a YES that falls straight into the party list.
func test_a_wild_faint_asks_whether_to_use_the_next_pokemon() -> void:
	var battle: Gen2Battle = _faint_battle(false, true)
	await _open(battle, [Gen2Battle.use_move(0), Gen2Battle.use_move(0)])
	await _advance_to("use_next")

	assert_eq(_stage(), "use_next")
	assert_true(
		String(_screen.battle_snapshot()["message"]).contains("Use next"),
		String(_screen.battle_snapshot()["message"])
	)
	await _read_question()
	assert_true(_layer().visible)
	assert_eq(_cursor(), 0, "YesNoMenuHeader opens on YES")

	await _step(PokeButton.A)
	assert_eq(_stage(), "pick", "ForcePlayerMonChoice, with no press in between")
	assert_eq(String(_screen.battle_snapshot()["switch_reason"]), "replace")
	assert_true(bool(_screen.battle_snapshot()["switch_forced"]))


## NO is the run, and Pikachu in the first party slot is faster than the Geodude
## chasing it, so it gets away on speed alone.
func test_no_runs_from_the_wild_battle_instead_of_replacing() -> void:
	var battle: Gen2Battle = _faint_battle(false, true)
	await _open(battle, [Gen2Battle.use_move(0), Gen2Battle.use_move(0)])
	await _advance_to("use_next")
	await _read_question()

	await _step(PokeButton.B)
	assert_eq(_stage(), "")
	assert_true(battle.has_fled())
	assert_true(bool(_screen.battle_snapshot()["battle_over"]))


## `ForcePickPartyMonInBattle` cannot be backed out of, and the row chosen is
## what comes in. A trainer battle never asks the question above it.
func test_a_trainer_faint_opens_a_replacement_list_with_no_way_out() -> void:
	var battle: Gen2Battle = _faint_battle(true, true)
	await _open(battle, [Gen2Battle.use_move(0), Gen2Battle.use_move(0)])
	await _advance_to("pick")

	assert_eq(String(_screen.battle_snapshot()["switch_reason"]), "replace")
	await _step(PokeButton.B)
	assert_eq(_stage(), "pick", "B is swallowed")

	## Two rows and CANCEL, so two presses down reach a row that refuses too.
	await _step(PokeButton.DOWN)
	await _step(PokeButton.DOWN)
	assert_eq(_cursor(), 2)
	await _step(PokeButton.A)
	assert_eq(_stage(), "pick")

	await _step(PokeButton.UP)
	await _step(PokeButton.A)
	assert_eq(_stage(), "")
	assert_eq(battle.party(Gen2Battle.PLAYER).active, 1)
	assert_false(battle.awaiting_replacement())


## The one that just fainted is refused by `CheckIfCurPartyMonIsFitToFight`, and
## the list comes back rather than the question being answered.
func test_the_fainted_row_is_refused_and_the_list_comes_back() -> void:
	var battle: Gen2Battle = _faint_battle(true, true)
	await _open(battle, [Gen2Battle.use_move(0), Gen2Battle.use_move(0)])
	await _advance_to("pick")

	await _step(PokeButton.A)
	assert_eq(_stage(), "refused")
	assert_true(
		String(_screen.battle_snapshot()["message"]).contains("no will to\nbattle!"),
		String(_screen.battle_snapshot()["message"])
	)
	assert_true(battle.must_replace(Gen2Battle.PLAYER), "and nothing was answered")

	await _step(PokeButton.A)
	assert_eq(_stage(), "pick", "the list is redrawn")
	assert_true(bool(_screen.battle_snapshot()["switch_forced"]), "still with no way out")


func _menu_stage() -> String:
	return String(_screen.battle_snapshot()["menu_stage"])


func _menu_layer() -> TextureRect:
	return _screen.get("_battle_menu_layer")


func _advance_to_menu(limit: int = 40) -> void:
	for _press: int in limit:
		_settle_bars()
		if _menu_stage() != "":
			return
		_screen.finish()
		_screen.advance()
		await get_tree().process_frame


## A wild battle whose player has two moves, so the list has two rows and a
## second one to move the cursor onto.
func _menu_battle() -> Gen2Battle:
	return Gen2Battle.create_parties(
		_data,
		Gen2Party.create([
			_mon(BattleFixture.PIKACHU, [BattleFixture.TACKLE, BattleFixture.GROWL]),
			_mon(BattleFixture.BULBASAUR, [BattleFixture.TACKLE]),
		]),
		Gen2Party.of(_mon(BattleFixture.GEODUDE, [BattleFixture.TACKLE])),
		_rng, false
	)


## The turn ends on the menu rather than on another turn, and `BattleMenuHeader`
## opens on FIGHT.
func test_the_end_of_a_turn_opens_the_battle_menu() -> void:
	var battle: Gen2Battle = _menu_battle()
	await _open(battle, [Gen2Battle.use_move(0), Gen2Battle.use_move(0)])
	await _advance_to_menu()

	assert_eq(_menu_stage(), "main")
	assert_eq(int(_screen.battle_snapshot()["menu_position"]), Gen2BattleMenu.FIGHT)
	assert_true(_menu_layer().visible)
	assert_false(_screen._renderer_input_free(), "the menu owns the joypad")


## `BattlePack` is the pack's own screen over the fight: the pockets, the rows
## and `UpdateItemDescription`'s box, with `ItemSubmenu` behind A.
func test_the_pack_is_the_pack_screen_with_the_row_description_under_it() -> void:
	var battle: Gen2Battle = _menu_battle()
	await _open(battle, [Gen2Battle.use_move(0), Gen2Battle.use_move(0)])
	await _advance_to_menu()
	var items: Array[int] = [BattleFixture.POTION, BattleFixture.FULL_HEAL]
	_screen.set_battle_pack(
		items, {BattleFixture.POTION: 3, BattleFixture.FULL_HEAL: 1}
	)

	await _step(PokeButton.DOWN)
	assert_eq(int(_screen.battle_snapshot()["menu_position"]), Gen2BattleMenu.PACK)
	await _step(PokeButton.A)
	var pack: Gen2StartMenuScreen = _screen.get("_pack_host")
	assert_not_null(pack, "the pack's own screen")
	assert_eq(pack._mode, Gen2StartMenuScreen.Mode.PACK)
	assert_eq(int(pack._selected_item()["item"]), BattleFixture.POTION)
	assert_eq(pack._pack_description(), Gen2WorldPack.row_description(_data, BattleFixture.POTION))

	await _step(PokeButton.DOWN)
	assert_eq(int(pack._selected_item()["item"]), BattleFixture.FULL_HEAL, "a list walks downwards")
	await _step(PokeButton.A)
	assert_eq(pack._mode, Gen2StartMenuScreen.Mode.PACK_ITEM, "ItemSubmenu is up")
	assert_eq(pack._item_actions.size(), 2, "USE and QUIT")
	await _step(PokeButton.B)
	await _step(PokeButton.B)
	assert_null(_screen.get("_pack_host"))
	assert_eq(_menu_stage(), "main", "`.didnt_use_item` is `jp BattleMenu`")


## The throw is a message and no message redraws a menu, so the ball list stood
## over the whole of the fight it had just started.
func test_throwing_a_ball_takes_the_list_off_the_screen() -> void:
	var battle: Gen2Battle = _menu_battle()
	await _open(battle, [Gen2Battle.use_move(0), Gen2Battle.use_move(0)])
	await _advance_to_menu()
	_screen.set_battle_pack(
		[BattleFixture.POTION, BattleFixture.POKE_BALL],
		{BattleFixture.POTION: 1, BattleFixture.POKE_BALL: 4}
	)
	_screen.set_capture_balls([BattleFixture.POKE_BALL], {BattleFixture.POKE_BALL: 4})
	## A ball is only thrown in a wild battle, which is what the world tells the
	## screen when it hands one over.
	_screen.set("_world_battle_active", true)
	_screen.set("_world_battle_request", {"values": {"kind": &"wild"}})

	await _step(PokeButton.DOWN)
	await _step(PokeButton.A)
	await _step(PokeButton.RIGHT)
	await _step(PokeButton.A)
	var pack: Gen2StartMenuScreen = _screen.get("_pack_host")
	assert_eq(int(pack._selected_item()["item"]), BattleFixture.POKE_BALL, "the BALL pocket")
	assert_eq(pack._mode, Gen2StartMenuScreen.Mode.PACK_ITEM, "ItemSubmenu is up")

	## `.BattleOnly` runs the effect on USE; the row was already chosen in the
	## pack, so nothing asks which ball a second time.
	await _step(PokeButton.A)
	assert_true(bool(_screen.get("_capture_waiting")), "the ball is in the air")
	assert_null(_screen.get("_pack_host"), "and nothing is drawn over the fight")
	assert_false(_menu_layer().visible)


## `_2DMenuInterpretJoypad` with neither wrap flag: a press off the grid is
## ignored, and the four positions are the source's own order.
func test_the_battle_menu_walks_its_two_by_two_and_does_not_wrap() -> void:
	var battle: Gen2Battle = _menu_battle()
	await _open(battle, [Gen2Battle.use_move(0), Gen2Battle.use_move(0)])
	await _advance_to_menu()

	await _step(PokeButton.LEFT)
	assert_eq(int(_screen.battle_snapshot()["menu_position"]), Gen2BattleMenu.FIGHT)
	await _step(PokeButton.RIGHT)
	assert_eq(int(_screen.battle_snapshot()["menu_position"]), Gen2BattleMenu.PKMN)
	await _step(PokeButton.DOWN)
	assert_eq(int(_screen.battle_snapshot()["menu_position"]), Gen2BattleMenu.RUN)
	await _step(PokeButton.DOWN)
	assert_eq(int(_screen.battle_snapshot()["menu_position"]), Gen2BattleMenu.RUN)
	await _step(PokeButton.LEFT)
	assert_eq(int(_screen.battle_snapshot()["menu_position"]), Gen2BattleMenu.PACK)


## FIGHT is `MoveSelectionScreen`: the Pokemon's own moves, and the row chosen
## there is the move the turn is spent on.
func test_fight_opens_the_move_list_and_the_chosen_row_is_the_move_used() -> void:
	var battle: Gen2Battle = _menu_battle()
	await _open(battle, [Gen2Battle.use_move(0), Gen2Battle.use_move(0)])
	await _advance_to_menu()

	await _step(PokeButton.A)
	assert_eq(_menu_stage(), "move")
	var rows: Array = _screen.battle_snapshot()["move_rows"]
	assert_eq(rows.size(), 2, "two moves, two rows")
	assert_eq(int((rows[0] as Dictionary)["move"]), BattleFixture.TACKLE)

	await _step(PokeButton.DOWN)
	assert_eq(int(_screen.battle_snapshot()["move_cursor"]), 1)
	var before: int = battle.mon(Gen2Battle.PLAYER).pp_left(1)
	await _step(PokeButton.A)

	assert_eq(_menu_stage(), "", "the list is gone once the turn is taken")
	assert_eq(battle.mon(Gen2Battle.PLAYER).pp_left(1), before - 1, "GROWL was used")


## `.pressed_up` and `.pressed_down` under the WRAP flag the screen writes.
func test_the_move_cursor_wraps_and_b_goes_back_to_the_menu() -> void:
	var battle: Gen2Battle = _menu_battle()
	await _open(battle, [Gen2Battle.use_move(0), Gen2Battle.use_move(0)])
	await _advance_to_menu()
	await _step(PokeButton.A)

	await _step(PokeButton.UP)
	assert_eq(int(_screen.battle_snapshot()["move_cursor"]), 1, "wrapped to the last row")
	await _step(PokeButton.DOWN)
	assert_eq(int(_screen.battle_snapshot()["move_cursor"]), 0)

	await _step(PokeButton.B)
	assert_eq(_menu_stage(), "main", "B leaves the list for the menu behind it")


## `.no_pp_left`: the line is printed over the list and the list comes back on
## the press that reads it, with the turn still unspent.
func test_a_move_with_no_pp_is_refused_and_the_list_comes_back() -> void:
	var battle: Gen2Battle = _menu_battle()
	await _open(battle, [Gen2Battle.use_move(0), Gen2Battle.use_move(0)])
	await _advance_to_menu()
	battle.mon(Gen2Battle.PLAYER).pp[0] = 0

	await _step(PokeButton.A)
	await _step(PokeButton.A)
	assert_eq(_menu_stage(), "refused")
	assert_true(
		String(_screen.battle_snapshot()["message"]).contains("no PP left"),
		String(_screen.battle_snapshot()["message"])
	)

	var box: Gen2TextBox = _screen.get("_box")
	while box.is_revealing() or box.has_pages_left():
		box.finish()
		if box.has_pages_left():
			box.advance()
	await _step(PokeButton.A)
	assert_eq(_menu_stage(), "move", "and the list is back")


## `CheckPlayerHasUsableMoves`' `.force_struggle`: no list, a line that asks
## no press, sixty frames, and the turn goes to Struggle.
func test_a_pokemon_with_no_usable_move_says_so_and_struggles() -> void:
	var battle: Gen2Battle = _menu_battle()
	await _open(battle, [Gen2Battle.use_move(0), Gen2Battle.use_move(0)])
	await _advance_to_menu()
	battle.mon(Gen2Battle.PLAYER).pp[0] = 0
	battle.mon(Gen2Battle.PLAYER).pp[1] = 0

	await _step(PokeButton.A)
	assert_eq(_menu_stage(), "")
	assert_eq(
		String(_screen.battle_snapshot()["message"]), "PIKACHU\nhas no moves left!"
	)
	assert_false(bool(_screen.battle_snapshot()["awaits_press"]))
	var guard: int = 400
	while _screen.battle_snapshot()["message"] == "PIKACHU\nhas no moves left!" and guard > 0:
		_screen.advance_hardware_frame()
		guard -= 1
	assert_gt(guard, 0, "the turn ran on without a press")
	assert_string_contains(String(_screen.battle_snapshot()["message"]), "STRUGGLE")


## RUN is `BattleMenu_Run`, which settles before the turn does.
func test_run_leaves_the_wild_battle() -> void:
	var battle: Gen2Battle = _menu_battle()
	await _open(battle, [Gen2Battle.use_move(0), Gen2Battle.use_move(0)])
	await _advance_to_menu()

	await _step(PokeButton.DOWN)
	await _step(PokeButton.RIGHT)
	assert_eq(int(_screen.battle_snapshot()["menu_position"]), Gen2BattleMenu.RUN)
	await _step(PokeButton.A)
	assert_eq(_menu_stage(), "")
	assert_false(_screen.get("_pending").is_empty(), "the run is a turn's worth of events")


## PKMN is `BattleMenu_PKMN`: the same party list a switch offer opens, backed
## out of into the menu it came from, and the row chosen there spends the turn.
func test_pkmn_opens_a_party_list_that_can_be_cancelled_back_to_the_menu() -> void:
	var battle: Gen2Battle = _menu_battle()
	await _open(battle, [Gen2Battle.use_move(0), Gen2Battle.use_move(0)])
	await _advance_to_menu()

	await _step(PokeButton.RIGHT)
	await _step(PokeButton.A)
	assert_eq(_stage(), "pick")
	assert_eq(String(_screen.battle_snapshot()["switch_reason"]), "player")
	assert_false(bool(_screen.battle_snapshot()["switch_forced"]), "and it can be left")

	await _step(PokeButton.B)
	assert_eq(_stage(), "")
	assert_eq(_menu_stage(), "main", "cancelling is a jp BattleMenu")

	await _step(PokeButton.A)
	await _step(PokeButton.DOWN)
	await _step(PokeButton.A)
	assert_eq(_stage(), "action", "SWITCH/STATS/CANCEL is asked of the member first")
	await _step(PokeButton.A)
	assert_eq(battle.party(Gen2Battle.PLAYER).active, 1, "the bench member came in")


## A mod's renderer is offered the leftovers only while the screen is not asking
## a question of its own, the way it is for the forget prompt and ball selection.
func test_a_renderer_is_not_offered_input_while_a_menu_is_up() -> void:
	var battle: Gen2Battle = _trainer_battle(true)
	await _open(battle, [Gen2Battle.use_move(0), Gen2Battle.use_move(0)])
	assert_true(_screen._renderer_input_free())
	await _advance_to("offer")
	assert_false(_screen._renderer_input_free())
	await _read_question()
	await _step(PokeButton.B)
	assert_true(_screen._renderer_input_free())


## `BattleMenu_Pack`: PACK opens `BattlePack`'s own list, an ITEMMENU_PARTY row
## asks `UseItem_SelectMon` for a target, and the item is spent before the turn
## the enemy still gets.
func test_the_pack_uses_an_item_on_the_chosen_member_and_spends_the_turn() -> void:
	var battle: Gen2Battle = _menu_battle()
	await _open(battle, [Gen2Battle.use_move(0), Gen2Battle.use_move(0)])
	await _advance_to_menu()
	_screen.set_battle_pack(
		[BattleFixture.POTION], {BattleFixture.POTION: 2}
	)
	var spent: Array = []
	_screen.item_used.connect(func(item: int, target: int) -> void:
		spent.append([item, target])
	)
	var bench: Gen2BattleMon = battle.party(Gen2Battle.PLAYER).at(1)
	bench.hp = 1

	await _step(PokeButton.DOWN)
	assert_eq(int(_screen.battle_snapshot()["menu_position"]), Gen2BattleMenu.PACK)
	await _step(PokeButton.A)
	var pack: Gen2StartMenuScreen = _screen.get("_pack_host")
	assert_not_null(pack, "the pack is up")
	assert_eq(int(pack._selected_item()["item"]), BattleFixture.POTION)

	# `ItemSubmenu`'s USE, and then the party list `UseItem_SelectMon` opens
	# with the bench member on it.
	await _step(PokeButton.A)
	await _step(PokeButton.A)
	assert_eq(_stage(), "pick")
	await _step(PokeButton.DOWN)
	await _step(PokeButton.A)

	assert_eq(bench.hp, 21, "the potion landed on the bench member")
	assert_eq(spent, [[BattleFixture.POTION, 1]], "and the world was told to spend it")
	assert_null(_screen.get("_pack_host"))


## `ItemRestoreHP` on a full member is `StatusHealer_NoEffect`: the line prints
## over the party list the member was chosen on, and `.BattleField` then
## redraws the pack with the potion still in it and the turn still the player's.
func test_a_potion_that_would_do_nothing_says_so_over_the_list_then_the_pack() -> void:
	var battle: Gen2Battle = _menu_battle()
	await _open(battle, [Gen2Battle.use_move(0), Gen2Battle.use_move(0)])
	await _advance_to_menu()
	_screen.set_battle_pack([BattleFixture.POTION], {BattleFixture.POTION: 1})
	var user: Gen2BattleMon = battle.mon(Gen2Battle.PLAYER)
	user.hp = user.max_hp()
	var spent: Array = []
	_screen.item_used.connect(func(item: int, target: int) -> void: spent.append([item, target]))

	await _step(PokeButton.DOWN)
	await _step(PokeButton.A)
	await _step(PokeButton.A)
	await _step(PokeButton.A)
	assert_eq(_stage(), "pick")
	await _step(PokeButton.A)
	assert_eq(_stage(), "refused", "the line stands over the party list")
	assert_true(
		String(_screen.battle_snapshot()["message"]).contains("won't have any effect"),
		String(_screen.battle_snapshot()["message"])
	)
	assert_null(_screen.get("_pack_host"))
	await _step(PokeButton.A)
	assert_eq(_stage(), "")
	assert_not_null(_screen.get("_pack_host"), "and the pack is back")
	assert_eq(spent, [], "nothing was spent")


## `UseItem_SelectMon` makes none of the switch list's own checks: the Pokemon
## already out is exactly what a potion is usually used on, and backing out of
## the list reopens the pack rather than the menu.
func test_the_item_target_list_takes_the_one_out_and_backs_out_to_the_pack() -> void:
	var battle: Gen2Battle = _menu_battle()
	await _open(battle, [Gen2Battle.use_move(0), Gen2Battle.use_move(0)])
	await _advance_to_menu()
	_screen.set_battle_pack([BattleFixture.POTION], {BattleFixture.POTION: 1})
	battle.mon(Gen2Battle.PLAYER).hp = 1

	await _step(PokeButton.DOWN)
	await _step(PokeButton.A)
	await _step(PokeButton.A)
	await _step(PokeButton.A)
	assert_eq(_stage(), "pick")
	await _step(PokeButton.B)
	assert_eq(_stage(), "", "the list is gone")
	assert_not_null(_screen.get("_pack_host"), "and the pack is back")

	await _step(PokeButton.A)
	await _step(PokeButton.A)
	await _step(PokeButton.A)
	assert_eq(_stage(), "item_result", "the bar fills on the list it was chosen from")
	await _step(PokeButton.A)
	## Healed to 21 and then hit, because the item spends the turn and the enemy
	## still moves in it.
	assert_gt(battle.mon(Gen2Battle.PLAYER).hp, 1, "used on the one that is out")
	assert_lt(battle.mon(Gen2Battle.PLAYER).hp, 21, "and the enemy answered it")


## An ITEMMENU_CLOSE row is applied to whoever is out with no list in front of
## it, and B leaves the pack for the menu it was opened from.
func test_an_x_item_needs_no_target_and_b_closes_the_pack() -> void:
	var battle: Gen2Battle = _menu_battle()
	await _open(battle, [Gen2Battle.use_move(0), Gen2Battle.use_move(0)])
	await _advance_to_menu()
	_screen.set_battle_pack([BattleFixture.X_ATTACK], {BattleFixture.X_ATTACK: 1})

	await _step(PokeButton.DOWN)
	await _step(PokeButton.A)
	await _step(PokeButton.B)
	assert_eq(_menu_stage(), "main", "B is a jp BattleMenu")

	await _step(PokeButton.A)
	await _step(PokeButton.A)
	await _step(PokeButton.A)
	assert_eq(battle.mon(Gen2Battle.PLAYER).stage("attack"), 1)
	assert_eq(_stage(), "", "no target list for an item used on the one that is out")


## `RestorePPEffect`'s `.loop`: an Ether asks which move after it has asked which
## Pokemon, and the slot chosen there is the one that fills.
func test_an_ether_asks_which_move_and_fills_that_slot() -> void:
	var battle: Gen2Battle = _menu_battle()
	await _open(battle, [Gen2Battle.use_move(0), Gen2Battle.use_move(0)])
	await _advance_to_menu()
	_screen.set_battle_pack([BattleFixture.ETHER], {BattleFixture.ETHER: 1})
	var user: Gen2BattleMon = battle.mon(Gen2Battle.PLAYER)
	user.pp[0] = 0
	user.pp[1] = 0

	await _step(PokeButton.DOWN)
	await _step(PokeButton.A)
	await _step(PokeButton.A)
	await _step(PokeButton.A)
	assert_eq(_stage(), "pick")
	await _step(PokeButton.A)
	assert_true(bool(_screen.get("_pack_move_selecting")), "the move list is up")

	## `PAD_DOWN | PAD_UP | PAD_A | PAD_B`: the sides do not move the cursor.
	await _step(PokeButton.RIGHT)
	await _step(PokeButton.DOWN)
	await _step(PokeButton.A)
	assert_eq(user.pp_left(0), 0, "the slot it was not used on")
	assert_gt(user.pp_left(1), 0, "and the one it was")


## `BugContest_SetCaughtContestMon`: a catch made while `wContestMon` already
## holds one says `DisplayAlreadyCaughtText`, draws
## `DisplayCaughtContestMonStats` and asks over it. The comparison is what the
## question is answered from, so a screen that draws nothing is a question asked
## blind.
func test_a_second_contest_catch_is_asked_over_the_comparison() -> void:
	var battle: Gen2Battle = Gen2Battle.create_parties(
		_data,
		Gen2Party.create([_mon(BattleFixture.PIKACHU, [BattleFixture.TACKLE])]),
		Gen2Party.create([_mon(BattleFixture.GEODUDE, [BattleFixture.TACKLE])]),
		_rng, false
	)
	battle.battle_type = Gen2Battle.BATTLETYPE_CONTEST
	await _open(battle, [Gen2Battle.use_move(0), Gen2Battle.use_move(0)])
	_screen.set("_pending", [])
	## `_is_wild_battle` is what a capture is gated on, and it reads the world's
	## own request rather than the battle: a contest catch is a wild one.
	_screen.set("_world_battle_active", true)
	_screen.set("_world_battle_request", {"values": {"kind": &"wild"}})
	_screen.set_capture_balls(
		[Gen2WorldPartyHost.ITEM_PARK_BALL],
		{Gen2WorldPartyHost.ITEM_PARK_BALL: Gen2WorldBugContest.BALLS}
	)
	assert_true(bool(_screen.begin_capture().get("ok", false)))
	assert_true(bool(_screen.throw_capture_ball().get("ok", false)))
	_screen.complete_capture({
		"ok": true, "contest": true, "caught": true, "wobbles": 3,
		"ball": Gen2WorldPartyHost.ITEM_PARK_BALL,
		"quantity": Gen2WorldBugContest.BALLS - 1,
		"replace_offer": true,
		"mon": Gen2WorldPartyHost.contest_mon_from(_screen.capture_target()),
		"stock_species": BattleFixture.BULBASAUR,
		"stock_level": 9,
		"stock_max_hp": 27,
	})

	## The throw's own frames, then the shake lines and the already-caught line,
	## each prompted past the way a player would.
	for _press: int in 20:
		_settle_bars()
		if _stage() == "contest_replace":
			break
		_screen.finish()
		_screen.advance()
	assert_eq(_stage(), "contest_replace")

	## The page is one image on the menu layer, the way the party page is: the
	## two boxes and `PlaceYesNoBox`' own go into one tilemap on the cartridge.
	await _read_question()
	var layer: TextureRect = _screen.get("_menu_layer")
	assert_true(layer.visible, "the comparison is drawn")
	assert_eq(layer.position, Vector2.ZERO, "over the field rather than beside it")
	## `hlcoord 0, 6` plus five border rows, which is where the lower box ends.
	assert_eq(
		int(layer.size.y),
		(Gen2BattleScreen.CONTEST_THIS_TOP + Gen2BattleScreen.CONTEST_STATS_HEIGHT + 1)
			* Gen2Font.TILE,
		"and stops above the text box, which this screen draws itself"
	)


## `lb bc, 14, 7` rather than `OfferSwitch`'s `lb bc, 1, 7`: the question stands
## beside the THIS box, not over the STOCK one.
func test_the_contest_question_uses_its_own_corner() -> void:
	assert_eq(Gen2BattleScreen.CONTEST_YES_NO_LEFT, 14)
	assert_eq(Gen2BattleScreen.CONTEST_YES_NO_TOP, 7)
	assert_ne(Gen2BattleScreen.CONTEST_YES_NO_LEFT, Gen2BattleScreen.YES_NO_LEFT)


## PKMN, then a bench member, which is where `BattleMonMenu` is asked.
func _open_member_menu(battle: Gen2Battle, row: int = 1) -> void:
	await _open(battle, [Gen2Battle.use_move(0), Gen2Battle.use_move(0)])
	await _advance_to_menu()
	await _step(PokeButton.RIGHT)
	await _step(PokeButton.A)
	for _row: int in row:
		await _step(PokeButton.DOWN)
	await _step(PokeButton.A)


## `BattleMenuPKMN_Loop`'s `.Stats` is `Battle_StatsScreen` and then
## `BattleMenuPKMN_ReturnFromStats`, which is the list again with no turn spent.
func test_stats_opens_the_stats_screen_and_b_returns_to_the_list() -> void:
	var battle: Gen2Battle = _menu_battle()
	await _open_member_menu(battle)
	assert_eq(_stage(), "action")

	await _step(PokeButton.DOWN)
	await _step(PokeButton.A)
	assert_eq(_stage(), "stats")
	var stats: Gen2MonStatsScreen = _screen.get("_battle_stats")
	assert_not_null(stats, "the stats screen is up")
	assert_eq(stats.cursor(), 1, "on the member the row was chosen for")

	await _step(PokeButton.B)
	assert_eq(_stage(), "pick", "back on the party list")
	assert_null(_screen.get("_battle_stats"))
	assert_eq(_cursor(), 1, "on the same row")
	assert_eq(battle.party(Gen2Battle.PLAYER).active, 0, "and nobody switched")
	assert_true(_screen.get("_pending").is_empty(), "no turn was spent")


## `BattleMonMenu` sets carry on B, which is `.PressedB` and `BattleMenuPKMN_Loop`:
## the list. The CANCEL row is `.Cancel`, whose `jp BattleMenu` leaves the list.
func test_b_in_the_member_menu_is_the_list_and_cancel_is_the_battle_menu() -> void:
	var battle: Gen2Battle = _menu_battle()
	await _open_member_menu(battle)

	await _step(PokeButton.B)
	assert_eq(_stage(), "pick", "B goes back to the list")
	assert_eq(_cursor(), 1)

	await _step(PokeButton.A)
	assert_eq(_stage(), "action")
	## `_InitVerticalMenuCursor` sets `_2DMENU_WRAP_UP_DOWN` only for
	## `STATICMENU_WRAP`, which `BattleMonMenu.MenuData` does not carry.
	await _step(PokeButton.UP)
	assert_eq(int((_screen.get("_switch_action") as Gen2WorldMenu).cursor), 0, "UP stops at SWITCH")
	for _press: int in 3:
		await _step(PokeButton.DOWN)
	assert_eq(int((_screen.get("_switch_action") as Gen2WorldMenu).cursor), 2, "DOWN stops at CANCEL")
	await _step(PokeButton.A)
	assert_eq(_stage(), "")
	assert_eq(_menu_stage(), "main", "CANCEL is a jp BattleMenu")
	assert_eq(battle.party(Gen2Battle.PLAYER).active, 0)


## `TryPlayerSwitch` on the one already out prints `BattleText_MonIsAlreadyOut`
## and is `jp BattleMenuPKMN_Loop`, so SWITCH is refused rather than spent.
func test_switch_on_the_one_already_out_is_refused_over_the_list() -> void:
	var battle: Gen2Battle = _menu_battle()
	await _open_member_menu(battle, 0)
	assert_eq(_stage(), "action")

	await _step(PokeButton.A)
	assert_eq(_stage(), "refused")
	assert_true(
		String(_screen.battle_snapshot()["message"]).contains("is already out."),
		String(_screen.battle_snapshot()["message"])
	)
	await _step(PokeButton.A)
	assert_eq(_stage(), "pick")
	assert_true(_screen.get("_pending").is_empty(), "the turn is still the player's")


## Explosion from the faster side downs both: `HandleEnemyMonFaint` sets
## `wBattleEnded` in a wild battle, so nothing asks "Use next" and no party list
## opens for the fallen player, however many presses follow.
func test_a_wild_double_faint_ends_the_battle_without_a_party_list() -> void:
	var battle: Gen2Battle = Gen2Battle.create_parties(
		_data,
		Gen2Party.create([
			_mon(BattleFixture.PIKACHU, [BattleFixture.EXPLOSION]),
			_mon(BattleFixture.BULBASAUR, [BattleFixture.TACKLE]),
		]),
		Gen2Party.of(_mon(BattleFixture.GEODUDE, [BattleFixture.TACKLE])),
		_rng, false
	)
	battle.enemy.hp = 1
	await _open(battle, [Gen2Battle.use_move(0), Gen2Battle.use_move(0)])
	assert_true(battle.player.is_fainted(), "the user fell to its own Explosion")
	assert_true(battle.is_over())

	var stages: Array = []
	for _press: int in 40:
		_settle_bars()
		if _stage() != "" and not stages.has(_stage()):
			stages.append(_stage())
		_screen.finish()
		_screen.advance()
		await get_tree().process_frame
	assert_eq(stages, [], "no question and no list was opened")
	assert_false(battle.must_replace(Gen2Battle.PLAYER))
	assert_true(bool(_screen.battle_snapshot()["battle_over"]))


## `HealHP_SFX_GFX` fills the bar on the party menu the member was chosen from,
## then `ItemActionTextWaitButton` prints `.MenuActionTexts`' line and spends
## `DelayFrames 50` before a press is read; only then does the enemy move.
func test_a_potion_fills_the_bar_then_holds_its_line_before_the_turn() -> void:
	var battle: Gen2Battle = _menu_battle()
	await _open(battle, [Gen2Battle.use_move(0), Gen2Battle.use_move(0)])
	await _advance_to_menu()
	_screen.set_battle_pack([BattleFixture.POTION], {BattleFixture.POTION: 1})
	var bench: Gen2BattleMon = battle.party(Gen2Battle.PLAYER).at(1)
	bench.hp = 1
	for button: int in [PokeButton.DOWN, PokeButton.A, PokeButton.A, PokeButton.A, PokeButton.DOWN]:
		await _step(button)
	_settle_bars()
	_screen._handle_button(PokeButton.A)

	assert_eq(_stage(), "item_result")
	assert_eq(bench.hp, 21)
	var result: Dictionary = _screen.get("_item_result")
	assert_true(result.has("anim"), "the bar is still filling")
	assert_eq(String(result["text"]), "BULBASAUR\nrecovered 20HP!")
	_screen._handle_button(PokeButton.A)
	assert_eq(_stage(), "item_result", "a press does not cut the bar short")

	var guard: int = 400
	while (_screen.get("_item_result") as Dictionary).has("anim") and guard > 0:
		_screen.advance_hardware_frame()
		guard -= 1
	assert_eq(int((_screen.get("_item_result") as Dictionary)["hold"]), Gen2ItemActionText.HOLD_FRAMES)
	for _frame: int in Gen2ItemActionText.HOLD_FRAMES - 1:
		_screen.advance_hardware_frame()
	_screen._handle_button(PokeButton.A)
	assert_eq(_stage(), "item_result", "one frame of the hold is still owed")
	assert_true(_screen.get("_pending").is_empty(), "and the turn is not taken")

	_screen.advance_hardware_frame()
	_screen._handle_button(PokeButton.A)
	assert_eq(_stage(), "", "the press is read once the hold is spent")
	assert_false(_screen.get("_pending").is_empty(), "and the enemy's turn follows")


## A status healer has no bar to fill: `GetItemHealingAction` names its line by
## the item's mask, which for FULL HEAL is `ANY` and "health returned".
func test_a_status_healer_prints_its_status_line() -> void:
	var battle: Gen2Battle = _menu_battle()
	await _open(battle, [Gen2Battle.use_move(0), Gen2Battle.use_move(0)])
	await _advance_to_menu()
	_screen.set_battle_pack([BattleFixture.FULL_HEAL], {BattleFixture.FULL_HEAL: 1})
	var bench: Gen2BattleMon = battle.party(Gen2Battle.PLAYER).at(1)
	bench.status = Gen2Status.POISON
	for button: int in [PokeButton.DOWN, PokeButton.A, PokeButton.A, PokeButton.A, PokeButton.DOWN]:
		await _step(button)
	_settle_bars()
	_screen._handle_button(PokeButton.A)

	assert_eq(_stage(), "item_result")
	var result: Dictionary = _screen.get("_item_result")
	assert_false(result.has("anim"), "nothing to fill")
	assert_eq(String(result["text"]), "BULBASAUR's\nhealth returned.")
	assert_eq(bench.status, 0)


## Generation 1's `DisplayBagMenu`: the bag's rows and CANCEL, a cursor that stops
## at both ends, and A that is `UseBagItem` with no USE box in front of it: a
## POTION goes straight to `ItemUseMedicine`'s party menu.
func test_the_generation_one_bag_stops_at_both_ends_and_uses_on_a() -> void:
	var battle: Gen2Battle = _menu_battle()
	await _open(battle, [Gen2Battle.use_move(0), Gen2Battle.use_move(0)])
	await _advance_to_menu()
	_data.generation = RomRegistry.GEN1
	_screen.set_battle_pack(
		[BattleFixture.POTION, BattleFixture.FULL_HEAL],
		{BattleFixture.POTION: 1, BattleFixture.FULL_HEAL: 1}
	)
	await _step(PokeButton.DOWN)
	await _step(PokeButton.A)
	assert_true(bool(_screen.get("_pack_selecting")), "the bag list is up")
	assert_null(_screen.get("_pack_host"), "and not Generation 2's pack screen")

	await _step(PokeButton.UP)
	assert_eq(_screen.selected_pack_item(), BattleFixture.POTION, "the top stops")
	for _press: int in 3:
		await _step(PokeButton.DOWN)
	assert_eq(int(_screen.get("_pack_index")), 2, "the bottom is CANCEL and stops there")
	assert_eq(_screen.selected_pack_item(), 0)

	await _step(PokeButton.A)
	assert_false(bool(_screen.get("_pack_selecting")), "CANCEL closes the bag")
	assert_eq(_menu_stage(), "main")

	battle.mon(Gen2Battle.PLAYER).hp = 1
	await _step(PokeButton.A)
	while _screen.selected_pack_item() != BattleFixture.POTION:
		await _step(PokeButton.UP)
	await _step(PokeButton.A)
	assert_eq(String(_screen.get("_pack_action_stage")), "", "no USE box")
	assert_eq(_stage(), "pick", "the party menu the potion asks for")
	_settle_bars()
	_screen._handle_button(PokeButton.A)
	assert_eq(_stage(), "item_result")
	assert_eq(
		String((_screen.get("_item_result") as Dictionary)["text"]), "PIKACHU\nrecovered by 20!",
		"`_PotionText`'s own wording"
	)
