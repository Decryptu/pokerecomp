class_name Gen1FacilityScripts
extends RefCounted


## The [method GameData.special_text] run `DisplayPokemonCenterDialogue_`'s own
## boxes are imported under.
const GEN1_POKECENTER_RUN: String = "pokecenter"
const GEN1_CABLE_CLUB_RUN: String = "cable_club"
const GEN1_CABLE_CLUB_STRINGS: String = "cable_club_strings"
const GEN1_LINK_RUN: String = "link"
const GEN1_COLOSSEUM2_RUN: String = "colosseum2"

## `InGameTradeTextPointers`' fifteen and the two boxes the swap prints, which
## both generations' trades read under one run name.
const GEN1_TRADE_RUN: String = "npc_trade"

## `TextScript_PokemonCenterPC`, `TextScript_ItemStoragePC` and
## `TextScript_BillsPC`, each a machine, the run its own boxes were imported
## under and the boot line it opens with. `BIT_USING_GENERIC_PC` is clear on all
## three, which is what makes every one of them print that line.
const GEN1_PC_MACHINES: Dictionary = {
	Gen1Layout.TEXT_SCRIPT_POKECENTER_PC: [&"gen1_pokemon_center", "pc", "turned_on"],
	Gen1Layout.TEXT_SCRIPT_PLAYERS_PC: [&"gen1_players_pc", "players_pc", "turned_on"],
	Gen1Layout.TEXT_SCRIPT_BILLS_PC: [&"gen1_bills_pc", "bills_pc", "switch_on"],
}

const GEN1_WAITING_STEPS: Array[StringName] = [&"request", &"choice", &"wait"]


## `.IntroText` under a `YesNoChoice`, with `wPartyCount` tested before the list.
static func _gen1_day_care_offer(world: Gen2WorldAPI) -> Dictionary:
	var taken: Array = [_gen1_day_care_box(world, "only_one_mon")]
	if int(world._party_summary.get("count", 0)) > 1:
		taken = [
			_gen1_day_care_box(world, "which_mon"),
			{
				"type": &"request",
				"values": {"kind": &"party_selection_requested", "values": {
					"routine": &"day_care",
				}},
				"day_care": &"deposit",
			},
		]
	return {
		"type": &"choice",
		"text": String(_gen1_day_care_box(world, "intro")["text"]),
		"yes": taken,
		"no": [_gen1_day_care_box(world, "come_again")],
	}


## `DisplayPartyMenu`'s carry is CANCEL, and `callfar KnowsHMMove` is the whole
## of what is asked about the row it came back with.
static func _gen1_day_care_after_selection(world: Gen2WorldAPI, result: Dictionary) -> Array:
	var party_index: int = int(result.get("party_index", -1))
	if party_index < 0:
		return [_gen1_day_care_box(world, "all_right_then")]
	if Gen2WorldTMHM.knows_hm_move(world.data, _gen1_party_moves(world, party_index)):
		return [_gen1_day_care_box(world, "knows_hm_move")]
	return [
		_gen1_day_care_box(world, "will_look_after", String(result.get("nickname", ""))),
		_gen1_day_care_request(&"deposit", party_index, PIKACHU_CLIP_DAY_CARE_IN),
		_gen1_day_care_box(world, "come_see_me"),
	]


## `PlayCry` on `wCurPartySpecies`, or Yellow's `PikachuCry28` going in and
## `PikachuCry35` coming out; both ride the request's completion.
const PIKACHU_CLIP_DAY_CARE_IN: int = 27
const PIKACHU_CLIP_DAY_CARE_OUT: int = 34


static func _gen1_cry_after(world: Gen2WorldAPI, step: Dictionary, result: Dictionary) -> Array:
	if bool(result.get("starter_pikachu", false)):
		return [Gen1ScriptNodes._gen1_sound_step(world, "pikachu_clip", {"index": int(step["cry_after"])})]
	var species: int = int(result.get("species", 0))
	return [Gen1ScriptNodes._gen1_sound_step(world, "cry", {"index": species})] if species > 0 else []


## `.daycareInUse`: the level the slot reached and the price behind it.
static func _gen1_day_care_visit(world: Gen2WorldAPI, steps: Array) -> bool:
	var visit: Dictionary = Gen2WorldDayCare.gen1_visit(world.state, world.data)
	if visit.is_empty():
		return false
	var nickname: String = String(visit["nickname"])
	var growth: int = int(visit["growth"])
	steps.append(_gen1_day_care_box(world, "has_grown" if growth > 0 else "needs_more_time", nickname, "%3d" % growth
	))
	if int(world._party_summary.get("count", 0)) >= Gen2SaveData.MAX_PARTY:
		steps.append(_gen1_day_care_box(world, "no_room"))
		return true
	var price: int = int(visit["price"])
	steps.append({"type": &"money_box", "kind": &"money_top_right"})
	steps.append({
		"type": &"choice",
		"text": String(_gen1_day_care_box(world, "owe_money", "", str(price))["text"]),
		"yes": _gen1_day_care_payment(world, price, nickname),
		"no": [_gen1_day_care_box(world, "all_right_then")],
	})
	return true


## `.enoughMoney` pays before it draws the box again, so the receipt stands over
## the new balance.
static func _gen1_day_care_payment(world: Gen2WorldAPI, price: int, nickname: String) -> Array:
	var purse: int = world.state.money(Gen2WorldMartHost.MONEY_ACCOUNT)
	if purse < price:
		return [_gen1_day_care_box(world, "not_enough_money")]
	return [
		{"type": &"money", "amount": purse - price},
		{"type": &"money_box", "kind": &"money_top_right"},
		_gen1_day_care_box(world, "heres_your_mon"),
		_gen1_day_care_request(&"withdraw", -1, PIKACHU_CLIP_DAY_CARE_OUT),
		_gen1_day_care_box(world, "got_mon_back", nickname),
	]


static func _gen1_day_care_request(action: StringName, party_index: int, clip: int) -> Dictionary:
	return {"type": &"request", "cry_after": clip, "values": {
		"kind": &"day_care_mon_requested",
		"values": {"action": action, "party_index": party_index},
	}}


## One stub with its `text_ram` and its `text_decimal` or `text_bcd` filled,
## [param number] already spelled the way that command prints it.
static func _gen1_day_care_box(world: Gen2WorldAPI, name: String, ram: String = "", number: String = "") -> Dictionary:
	var text: String = Gen1ScriptNodes.gen1_filled_text(world, world.data.day_care_text(name))
	if not ram.is_empty():
		text = Gen2TextStream.fill_all_markers(text, Gen2TextStream.RAM_MARKER, ram)
	if not number.is_empty():
		text = Gen2TextStream.fill_all_markers(
			text, Gen2TextStream.NUMBER_MARKER, number
		)
	return {"type": &"text", "text": text}


static func _gen1_party_moves(world: Gen2WorldAPI, party_index: int) -> Array:
	var moves: Array = world._party_summary.get("moves", [])
	return moves[party_index] as Array if party_index < moves.size() else []


## `DoInGameTradeDialogue` over the row's own `wWhichTrade`:
## `wCompletedInGameTradeFlags` answers TRADETEXT_AFTER_TRADE alone once the swap
## has happened, and the offer is a `YesNoChoice` under TRADETEXT_WANNA_TRADE.
static func _gen1_trade(world: Gen2WorldAPI, node: Dictionary, steps: Array) -> bool:
	var trade_id: int = int(node["trade_id"])
	var values: Dictionary = {"trade_id": trade_id}
	var site: Dictionary = Gen1ScriptNodes._gen1_site(world, [Gen2WorldCatalog.KIND_TRADE], node, {"trade": trade_id})
	if site.has("species"):
		values["offered_species"] = int(site["species"])
		values["requested_species"] = int(site["requested_species"])
	var record: Dictionary = Gen2WorldPartyHost.trade_record(world.data, values)
	if record.is_empty():
		return false
	if world.state != null and world.state.npc_trade_done(trade_id):
		steps.append(_gen1_trade_box(world, record, Gen2WorldScriptRunner.TRADE_DIALOG_AFTER))
		return true
	steps.append({
		"type": &"choice",
		"text": _gen1_trade_text(world, record, Gen2Layout.trade_text_name(
			false, Gen2WorldScriptRunner.TRADE_DIALOG_INTRO, int(record["dialog"])
		)),
		"yes": [{
			"type": &"request",
			"values": {"kind": &"party_selection_requested", "values": {
				"routine": &"npc_trade", "trade": values,
			}},
			"trade": trade_id,
		}],
		"no": [_gen1_trade_box(world, record, Gen2WorldScriptRunner.TRADE_DIALOG_CANCEL)],
	})
	return true


## `InGameTrade_DoTrade` behind `DisplayPartyMenu`: a cancelled list is
## TRADETEXT_NO_TRADE and a wrong species TRADETEXT_WRONG_MON. The swap sets the
## flag before `ConnectCableText`, and `TradedForText` follows the movie.
static func _gen1_trade_after_selection(world: Gen2WorldAPI, step: Dictionary, result: Dictionary) -> Array:
	var trade_id: int = int(step["trade"])
	var record: Dictionary = Gen2WorldPartyHost.trade_record(world.data, {"trade_id": trade_id})
	var party_index: int = int(result.get("party_index", -1))
	if record.is_empty():
		return []
	if party_index < 0:
		return [_gen1_trade_box(world, record, Gen2WorldScriptRunner.TRADE_DIALOG_CANCEL)]
	if int(result.get("species", 0)) != int(record["requested_species"]):
		return [_gen1_trade_box(world, record, Gen2WorldScriptRunner.TRADE_DIALOG_WRONG)]
	return [
		{"type": &"npc_trade", "trade_id": trade_id},
		_gen1_trade_run_box(world, record, "cable"),
		{"type": &"request", "values": {"kind": &"trade_requested", "values": {
			"trade_id": trade_id, "party_index": party_index,
		}}},
		_gen1_trade_run_box(world, record, "traded_for"),
		_gen1_trade_box(world, record, Gen2WorldScriptRunner.TRADE_DIALOG_COMPLETE),
	]


static func _gen1_trade_box(world: Gen2WorldAPI, record: Dictionary, dialog: int) -> Dictionary:
	return _gen1_trade_run_box(world, record, Gen2Layout.trade_text_name(
		false, dialog, int(record.get("dialog", 0))
	))


static func _gen1_trade_run_box(world: Gen2WorldAPI, record: Dictionary, name: String) -> Dictionary:
	return {"type": &"text", "text": _gen1_trade_text(world, record, name)}


## `InGameTrade_GetMonName` twice: the species the row asks for into
## `wInGameTradeGiveMonName` and the one it offers into its neighbour.
static func _gen1_trade_text(world: Gen2WorldAPI, record: Dictionary, name: String) -> String:
	if world.data == null or name.is_empty():
		return ""
	var text: String = Gen1ScriptNodes.gen1_filled_text(world, world.data.special_text(GEN1_TRADE_RUN, name))
	for row: Array in [
		[Gen1Layout.TRADE_GIVE_NAME, int(record.get("requested_species", 0))],
		[Gen1Layout.TRADE_RECEIVE_NAME, int(record.get("offered_species", 0))],
	]:
		text = Gen2TextStream.fill_all_markers(
			text, "%s%04X>" % [Gen2TextStream.RAM_MARKER, int(row[0])],
			String(world.data.species(int(row[1])).get("name", ""))
		)
	return text


## `YesNoChoice` stands behind the box that asked, so the question is the last
## box printed.
static func _gen1_script_choice(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	var asked: int = _gen1_last_box(steps)
	if asked < 0:
		return false
	var question: Dictionary = steps[asked]
	steps.remove_at(asked)
	var yes: Array = []
	var no: Array = []
	if not Gen1ScriptNodes._gen1_resolve_script(world, node["yes"] as Array, yes, _gen1_run_copy(run)) \
		or not Gen1ScriptNodes._gen1_resolve_script(world, node["no"] as Array, no, _gen1_run_copy(run)):
		return false
	steps.append({
		"type": &"choice", "text": String(question["text"]), "yes": yes, "no": no,
	})
	return true


## `HandleMenuInput` over a box a script drew itself: the node owns the tail,
## walked once per row and once for the B press.
static func _gen1_script_menu(
	world: Gen2WorldAPI,
	node: Dictionary, tail: Array, steps: Array, run: Dictionary
) -> bool:
	var rows: Array = _gen1_menu_rows(world, node, run)
	if rows.is_empty():
		return false
	var answers: Array = []
	for index: int in rows.size():
		var row: Dictionary = rows[index]
		if not _gen1_menu_walk(world, tail, answers, run, {
			"row": index, "item": int(row.get("item", -1)),
		}):
			return false
	if not _gen1_menu_walk(world, tail, answers, run, {"row": -1, "item": -1, "cancelled": true}):
		return false
	## The question stays up under the menu, so its box owes no press.
	var asked: int = _gen1_last_box(steps)
	var text: String = String((steps[asked] as Dictionary)["text"]) if asked >= 0 else ""
	if asked >= 0:
		steps.remove_at(asked)
	steps.append({
		"type": &"request", "menu": true, "answers": answers,
		"values": {"kind": &"gen1_menu_requested", "values": {
			"box": node["box"], "entries_at": node.get("entries_at", {}),
			"labels": node.get("labels", []), "rows": rows, "text": text,
		}},
	})
	return true


static func _gen1_menu_walk(
	world: Gen2WorldAPI,
	tail: Array, answers: Array, run: Dictionary, menu: Dictionary
) -> bool:
	var arm: Array = []
	var copy: Dictionary = _gen1_run_copy(run)
	copy["menu"] = menu
	if not Gen1ScriptNodes._gen1_resolve_script(world, tail, arm, copy):
		return false
	answers.append(arm)
	return true


static func _gen1_menu_rows(world: Gen2WorldAPI, node: Dictionary, run: Dictionary) -> Array:
	var rows: Array = []
	if not node.has("filter"):
		for text: String in node.get("entries", []) as Array:
			rows.append({"text": text})
		return rows
	var bag: Dictionary = run["bag"]
	for value: Variant in node["filter"] as Array:
		var item: int = int(value)
		if int(bag.get(item, 0)) > 0:
			rows.append({"item": item, "text": world.data.item_name(item) if world.data != null else ""})
	return rows


## The box a YES/NO opens under, which nothing written between the two takes
## the place of.
static func _gen1_last_box(steps: Array) -> int:
	for index: int in range(steps.size() - 1, -1, -1):
		var type: StringName = StringName((steps[index] as Dictionary)["type"])
		if type == &"text":
			return index
		if GEN1_WAITING_STEPS.has(type):
			return -1
	return -1


static func _gen1_run_copy(run: Dictionary) -> Dictionary:
	return run.duplicate(true)


static func _gen1_script_box(
	world: Gen2WorldAPI,
	node: Dictionary, named: String, buffers: Dictionary = {}
) -> Dictionary:
	var text: String = Gen1ScriptNodes.gen1_filled_text(world, String(node.get("text", "")))
	for address: Variant in buffers:
		text = Gen2TextStream.fill_all_markers(
			text, "%s%04X>" % [Gen2TextStream.RAM_MARKER, int(address)],
			String(buffers[address])
		)
	if not named.is_empty():
		text = Gen2TextStream.fill_all_markers(
			text, Gen2TextStream.RAM_MARKER, named
		)
	var step: Dictionary = {"type": &"text", "text": text}
	if not bool(node.get("press", true)):
		step["press"] = false
	return step


## `DisplayTextID`'s own dispatch, which reads the first byte of the text a
## pointer stands at: a `TX_SCRIPT_*` id runs a routine and prints nothing.
static func _gen1_facility_steps(world: Gen2WorldAPI, row: Dictionary, text_id: int = 0) -> Array:
	var command: int = int(row.get("command", 0))
	if GEN1_PC_MACHINES.has(command):
		return _gen1_pc_steps(world, GEN1_PC_MACHINES[command] as Array)
	match command:
		Gen1Layout.TEXT_SCRIPT_MART:
			return _gen1_mart_steps(world, row, text_id)
		Gen1Layout.TEXT_SCRIPT_POKECENTER_NURSE:
			return _gen1_nurse_steps(world)
		Gen1Layout.TEXT_SCRIPT_CABLE_CLUB:
			return _gen1_cable_club_steps(world)
		Gen1Layout.TEXT_SCRIPT_VENDING_MACHINE:
			return _gen1_vending_steps(world)
		Gen1Layout.TEXT_SCRIPT_PRIZE_VENDOR:
			return _gen1_prize_steps(world, text_id)
	return []


## `SFX_TURN_ON_PC` starts with the boot line; only `ActivatePC` waits it out.
static func _gen1_pc_steps(world: Gen2WorldAPI, machine: Array) -> Array:
	var steps: Array = [
		Gen1ScriptNodes._gen1_sound_step(world, "sound", {"index": Gen1Sfx.SFX_TURN_ON_PC}),
		_gen1_facility_box(world, String(machine[1]), String(machine[2])),
	]
	if machine[0] == &"gen1_pokemon_center":
		steps.append(Gen1ScriptNodes._gen1_sound_step(world, "wait"))
	steps.append({"type": &"request", "values": {
		"kind": &"pc_requested", "values": {"mode": StringName(machine[0])},
	}})
	return steps


## `GetPrizeMenuId` subtracts `TEXT_GAMECORNERPRIZEROOM_PRIZE_VENDOR_1` from the id
## that opened it, so a vendor's list is their place among the map's own prize rows.
static func _gen1_prize_steps(world: Gen2WorldAPI, text_id: int) -> Array:
	var menus: Array = world.data.prize_menus() if world.data != null else []
	var first: int = _gen1_first_prize_text(world)
	var menu: int = text_id - first
	if first <= 0 or menu < 0 or menu >= menus.size():
		return []
	var chosen: Dictionary = menus[menu]
	var tms: bool = bool(chosen.get("tms", false))
	var rows: Array = []
	for index: int in (chosen.get("rows", []) as Array).size():
		var row: Dictionary = chosen["rows"][index]
		var site: Dictionary = Gen1ScriptNodes._gen1_event_site(world,
			Gen2WorldCatalog.KIND_PRIZE, Gen2WorldCatalog.GEN1_SOURCE_PRIZE,
			menu << Gen2WorldCatalog.GEN1_PRIZE_MENU_SHIFT | index,
			{"item" if tms else "species": int(row.get("item", 0)), "price": int(row.get("cost", 0)),
				"level": int(row.get("level", 0))}
		)
		rows.append({
			"item": int(site["item" if tms else "species"]), "cost": int(site["price"]),
			"level": int(site.get("level", 0)),
		})
	return [{"type": &"request", "values": {
		"kind": &"prize_requested",
		"values": {"menu": menu, "tms": tms, "rows": rows},
	}}]


static func _gen1_first_prize_text(world: Gen2WorldAPI) -> int:
	if world.current_map == null:
		return 0
	for index: int in world.current_map.texts.size():
		if int((world.current_map.texts[index] as Dictionary).get("command", 0)) \
			== Gen1Layout.TEXT_SCRIPT_PRIZE_VENDOR:
			return index + 1
	return 0


## `VendingMachineMenu`, whose list is `VendingPrices` rather than a shelf and
## whose greeting is the box the menu stands over.
static func _gen1_vending_steps(world: Gen2WorldAPI) -> Array:
	var rows: Array = world.data.vending_rows() if world.data != null else []
	if rows.is_empty():
		return []
	return [{"type": &"request", "values": {
		"kind": &"vending_requested", "values": {"rows": rows},
	}}]


## `CableClubNPC`: no Pokedex, or Yellow's follower not walking, is
## `MakingPreparationsText`; nobody on the cable is `wLinkTimeoutCounter` and
## `.failedToEstablishConnection`; a partner is `.establishedConnection`.
static func _gen1_cable_club_steps(world: Gen2WorldAPI) -> Array:
	var ready: bool = world.state != null \
		and world.state.is_engine_flag_active(Gen2WorldState.ENGINE_POKEDEX) \
		and (world.pikachu == null or world.pikachu.following())
	var welcome: Dictionary = _gen1_facility_box(world, GEN1_CABLE_CLUB_RUN, "welcome")
	if not ready:
		return [
			welcome,
			_gen1_wait_step(&"cable_club_wait", Gen1Layout.CABLE_CLUB_PREPARING_FRAMES),
			_gen1_facility_box(world, GEN1_CABLE_CLUB_RUN, "making_preparations"),
		]
	if world.state.link_transport().status() == Gen2LinkTransport.CONNECTION_NOT_ESTABLISHED:
		return [
			welcome,
			_gen1_wait_step(&"cable_club_wait", Gen1Layout.CABLE_CLUB_TIMEOUT_FRAMES),
			_gen1_facility_box(world, GEN1_CABLE_CLUB_RUN, "area_reserved"),
		]
	welcome["press"] = false
	return [
		welcome,
		_gen1_wait_step(&"cable_club_wait", Gen1Layout.CABLE_CLUB_CONNECTED_FRAMES),
		{
			"type": &"choice",
			"text": Gen1ScriptNodes.gen1_filled_text(world, world.data.special_text(GEN1_CABLE_CLUB_RUN, "please_apply")),
			"yes": _gen1_cable_club_save_steps(world),
			"no": [
				_gen1_wait_step(&"cable_club_wait", Gen1Layout.CABLE_CLUB_CLOSE_FRAMES),
				_gen1_facility_box(world, GEN1_CABLE_CLUB_RUN, "come_again"),
			],
		},
	]


## YES: `SaveGameData` writes silently, `SFX_SAVE`, `PleaseWaitText` with its own
## `text_pause`, and `Serial_SyncAndExchangeNybble`, which a save-file peer answers.
static func _gen1_cable_club_save_steps(world: Gen2WorldAPI) -> Array:
	var please_wait: Dictionary = _gen1_facility_box(world, GEN1_CABLE_CLUB_RUN, "please_wait")
	please_wait["press"] = false
	return [
		{"type": &"request", "values": {"kind": &"quick_save_requested", "values": {}}},
		_gen1_wait_step(&"cable_club_wait", Gen1Layout.CABLE_CLUB_SAVE_FRAMES, {
			"sounds": [{"frame": 0, "gen1": true, "index": Gen1Sfx.SFX_SAVE}],
		}),
		please_wait,
	] + _gen1_link_menu_steps(world)


## `LinkMenu`: BIT_LINK_CONNECTED, `WhereWouldYouLikeText` under
## `CableClubOptionsText`'s rows; B and CANCEL are `.choseCancel`.
static func _gen1_link_menu_steps(world: Gen2WorldAPI) -> Array:
	var rows: Array = []
	for label: String in world.data.special_text(GEN1_CABLE_CLUB_STRINGS, "options").split("\n"):
		rows.append({"text": label})
	var box: Rect2i = Gen1Layout.LINK_MENU_BOX_YELLOW if rows.size() > 3 \
		else Gen1Layout.LINK_MENU_BOX
	var answers: Array = []
	for row: int in rows.size():
		answers.append(_gen1_link_menu_answer(world, row, rows.size()))
	answers.append(_gen1_link_menu_cancel_steps(world))
	var question: Dictionary = _gen1_facility_box(world, GEN1_LINK_RUN, "where_to")
	return [
		{"type": &"link_connected", "set": true},
		{"type": &"request", "menu": true, "answers": answers, "values": {
			"kind": &"gen1_menu_requested", "values": {
				"box": {"x": box.position.x, "y": box.position.y,
					"width": box.size.x, "height": box.size.y},
				"entries_at": {"x": box.position.x + 2, "y": box.position.y + 2},
				"labels": [], "rows": rows, "text": String(question["text"]),
				"hold_frames": Gen1Layout.LINK_MENU_HOLD_FRAMES, "fast_text": true,
			},
		}},
	]


## One row's own walk; Yellow's COLOSSEUM2 is `.asm_f5963`'s handshake first.
static func _gen1_link_menu_answer(world: Gen2WorldAPI, row: int, rows: int) -> Array:
	if row == rows - 1:
		return _gen1_link_menu_cancel_steps(world)
	if row == Gen1Layout.LINK_MENU_COLOSSEUM2:
		return [
			_gen1_wait_step(&"cable_club_wait",
				Gen1Layout.CUP_HANDSHAKE_FRAMES + Gen1Layout.CUP_MENU_OPEN_FRAMES),
			{"type": &"cup_menu"},
		]
	return _gen1_link_room_steps(world, row)


## `.next`: `PleaseWaitText`, `PrepareForSpecialWarp` and the room's own row.
static func _gen1_link_room_steps(world: Gen2WorldAPI, row: int) -> Array:
	var please_wait: Dictionary = _gen1_facility_box(world, GEN1_LINK_RUN, "please_wait")
	please_wait["press"] = false
	return [
		please_wait,
		_gen1_wait_step(&"cable_club_wait",
			Gen1Layout.LINK_MENU_WAIT_FRAMES + Gen1Layout.LINK_MENU_WARP_FRAMES),
		{"type": &"link_state", "value": Gen1Layout.LINK_STATE_IN_CABLE_CLUB},
		{"type": &"special_warp", "name": Gen1Layout.CABLE_CLUB_WARP_ROWS[
			row * 2 if row == Gen1Layout.LINK_MENU_TRADE else 2
		]},
	]


## `Func_f531b`: a row walked to its cup's verdict on both parties, a refusal
## reopening the menu; CANCEL and B are `asm_f547f`'s carry.
static func _gen1_cup_menu_steps(world: Gen2WorldAPI) -> Array:
	world.state.link_session().gen1_stadium_cup = 0
	var rows: Array = []
	for label: String in world.data.special_text(GEN1_CABLE_CLUB_STRINGS, "rows").split("\n"):
		rows.append({"text": label})
	var cup_rules: Dictionary = {}
	for cup: int in Gen1Layout.CUP_COUNT:
		cup_rules[cup] = Array(world.data.special_text(GEN1_CABLE_CLUB_STRINGS, "rules_%d" % cup).split("\n"))
	var answers: Array = []
	for cup: int in Gen1Layout.CUP_COUNT:
		answers.append(_gen1_cup_answer(world, cup))
	answers.append(_gen1_link_menu_cancel_steps(world))
	answers.append(_gen1_link_menu_cancel_steps(world))
	return [{"type": &"request", "menu": true, "answers": answers, "values": {
		"kind": &"gen1_menu_requested", "values": {
			"box": _gen1_box(Gen1Layout.CUP_MENU_BOX),
			"entries_at": {"x": Gen1Layout.CUP_MENU_ROWS_AT.x, "y": Gen1Layout.CUP_MENU_ROWS_AT.y},
			"labels": [{
				"x": Gen1Layout.CUP_VIEW_AT.x, "y": Gen1Layout.CUP_VIEW_AT.y, "step": 1,
				"rows": Array(world.data.special_text(GEN1_CABLE_CLUB_STRINGS, "view_rules").split("\n")),
			}],
			"boxes": [_gen1_box(Gen1Layout.CUP_VIEW_BOX), _gen1_box(Gen1Layout.CUP_RULES_BOX)],
			"cursor_labels": {
				"x": Gen1Layout.CUP_RULES_AT.x, "y": Gen1Layout.CUP_RULES_AT.y, "step": 1,
				"rows": cup_rules,
			},
			"rows": rows, "text": "", "hold_frames": Gen1Layout.CUP_MENU_HOLD_FRAMES,
		},
	}}]


static func _gen1_box(box: Rect2i) -> Dictionary:
	return {"x": box.position.x, "y": box.position.y, "width": box.size.x, "height": box.size.y}


static func _gen1_cup_answer(world: Gen2WorldAPI, cup: int) -> Array:
	var refusal: String = _gen1_cup_refusal(world,
		cup, world._party_summary.get("species", []), world._party_summary.get("levels", [])
	)
	if not refusal.is_empty():
		return [{"type": &"text", "text": refusal}, {"type": &"cup_menu"}]
	var species: Array = []
	var levels: Array = []
	for row: Dictionary in world.state.link_transport().peer.get("party", []) as Array:
		species.append(int(row.get("species", 0)))
		levels.append(int(row.get("level", 0)))
	if not _gen1_cup_refusal(world, cup, species, levels).is_empty():
		return [_gen1_facility_box(world, GEN1_COLOSSEUM2_RUN, "ineligible"), {"type": &"cup_menu"}]
	return [{"type": &"stadium_cup", "cup": cup + 1}] \
		+ _gen1_link_room_steps(world, Gen1Layout.LINK_MENU_COLOSSEUM)


## `PokeCup`, `PikaCup` and `PetitCup` in their own order; empty lets the party in.
static func _gen1_cup_refusal(world: Gen2WorldAPI, cup: int, species: Array, levels: Array) -> String:
	if species.size() != Gen1Layout.CUP_PARTY_SIZE:
		return _gen1_cup_text(world, "three_mons")
	if species.has(Gen1Layout.CUP_MEW):
		return _gen1_cup_text(world, "mew")
	if species[0] == species[1] or species[0] == species[2] or species[1] == species[2]:
		return _gen1_cup_text(world, "different_mons")
	if cup == Gen1Layout.CUP_PETIT:
		var sized: String = _gen1_petit_refusal(world, species)
		if not sized.is_empty():
			return sized
	var bounds: Array = Gen1Layout.CUP_LEVELS[cup]
	var names: Array = Gen1Layout.CUP_REFUSALS[cup]
	var total: int = 0
	for level: Variant in levels:
		if int(level) > int(bounds[1]):
			return _gen1_cup_text(world, String(names[1]))
		if int(level) < int(bounds[0]):
			return _gen1_cup_text(world, String(names[0]))
		total += int(level)
	if total > int(bounds[2]):
		return _gen1_cup_text(world, String(names[2]))
	return ""


## `Func_3b10f` over every member, then the Pokedex's inches and pounds.
static func _gen1_petit_refusal(world: Gen2WorldAPI, species: Array) -> String:
	for member: Variant in species:
		if _gen1_is_evolved(world, int(member)):
			return _gen1_cup_text(world, "evolved", int(member))
	for member: Variant in species:
		var dex: Dictionary = world.data.dex_entry(int(member))
		var height: int = int(dex.get("height", 0))
		@warning_ignore("integer_division")
		if (height / 100) * 12 + height % 100 > Gen1Layout.CUP_PETIT_MAX_INCHES:
			return _gen1_cup_text(world, "height", int(member))
		if int(dex.get("weight", 0)) > Gen1Layout.CUP_PETIT_MAX_WEIGHT:
			return _gen1_cup_text(world, "weight", int(member))
	return ""


static func _gen1_is_evolved(world: Gen2WorldAPI, species: int) -> bool:
	for number: int in range(1, world.data.species_count() + 1):
		for row: Dictionary in world.data.evolutions(number):
			if int(row.get("target", 0)) == species:
				return true
	return false


static func _gen1_cup_text(world: Gen2WorldAPI, name: String, species: int = 0) -> String:
	var text: String = world.data.special_text(GEN1_COLOSSEUM2_RUN, name)
	if species > 0:
		text = text.replace(
			"%s%04X>" % [Gen2TextStream.RAM_MARKER, int(Gen1Layout.for_id(world.data.id)["name_buffer"])],
			String(world.data.species(species).get("name", ""))
		)
	return text


static func _gen1_link_menu_cancel_steps(world: Gen2WorldAPI) -> Array:
	return [
		_gen1_wait_step(&"cable_club_wait", Gen1Layout.LINK_MENU_CANCEL_FRAMES),
		_gen1_facility_box(world, GEN1_LINK_RUN, "canceled"),
		{"type": &"link_connected", "set": false},
	]


## `CableClub_Run`: `ld c, 80` behind "Just a moment.",
## `CableClub_DoBattleOrTrade`, `HealParty` after a fight, `ReturnToCableClubRoom`.
static func _gen1_cable_club_run_steps(link_state: int) -> Array:
	var battle: bool = link_state == Gen1Layout.LINK_STATE_START_BATTLE
	var out: Array = [
		_gen1_wait_step(&"cable_club_wait", Gen1Layout.CABLE_CLUB_RUN_FRAMES),
		{"type": &"request", "values": {"kind": &"link_room_requested", "values": {
			"link_mode": Gen2LinkTransport.LINK_COLOSSEUM if battle \
				else Gen2LinkTransport.LINK_TRADECENTER,
			"gen1": true,
		}}},
	]
	if battle:
		out.append({"type": &"request", "values": {
			"kind": &"party_heal_requested", "values": {},
		}})
	out.append({"type": &"cable_club_return"})
	return out


## `LoadSpecialWarpData` and `SpecialEnterMap`: on foot, facing down, `wLastMap`
## left at PALLET_TOWN, and the cell left from kept for the snapshot.
static func _gen1_special_warp(world: Gen2WorldAPI, name: String) -> Dictionary:
	var warp: Dictionary = world.data.gen1_cable_club_warp(name) if world.data != null else {}
	var target: Gen2WorldMap = world.data.world_map(0, int(warp.get("map", -1))) if not warp.is_empty() else null
	if target == null:
		return {}
	if world._gen1_cable_club_origin.is_empty():
		world._gen1_cable_club_origin = {
			"map": world.map_id(), "cell": world.player_cell, "facing": world.player_facing,
			"movement_mode": world.movement_mode, "sprite": world.player_sprite_number,
			"last_map": world._gen1_last_map,
		}
	var from_map: Vector2i = world.map_id()
	world.movement_mode = Gen2WorldAPI.MOVEMENT_WALK
	world.player_sprite_number = world._walking_sprite()
	world.player_facing = Gen2WorldSprite.FACING_DOWN
	world._apply_map(
		target, world.data.world_tileset(target.tileset),
		Vector2i(int(warp["x"]), int(warp["y"])), true, 0, Gen2WorldAPI.MAP_ENTRY_WARP
	)
	world._gen1_last_map = Gen1Layout.PALLET_TOWN
	return {"type": &"warp", "from_map": from_map, "to_map": world.map_id(), "to_cell": world.player_cell}


## `ReturnToCableClubRoom` and `CableClub_Run`'s tail: `wStatusFlags3` zeroed,
## the room loaded again, LINK_STATE_IN_CABLE_CLUB.
static func gen1_return_to_cable_club_room(world: Gen2WorldAPI) -> Array:
	if world.current_map == null:
		return []
	var rest: Array = world._gen1_steps
	world._apply_map(world.current_map, world.current_tileset, world.player_cell, true, 0, Gen2WorldAPI.MAP_ENTRY_WARP)
	world._gen1_steps = rest
	world.state.link_session().gen1_link_state = Gen1Layout.LINK_STATE_IN_CABLE_CLUB
	return [{"type": &"map_reloaded", "map": world.map_id(), "cell": world.player_cell}]


## `wLinkState`.
static func gen1_link_state(world: Gen2WorldAPI) -> int:
	return world.state.link_session().gen1_link_state if world.state != null else Gen1Layout.LINK_STATE_NONE


static func gen1_link_connected(world: Gen2WorldAPI) -> bool:
	return world.state != null and world.state.link_session().gen1_link_connected


## The cell SRAM holds: the receptionist's while the player is in a link room.
static func gen1_saved_position(world: Gen2WorldAPI) -> Dictionary:
	return world._gen1_cable_club_origin


## `MartDialog`'s counter is the whole of a Generation 1 shop, so the request
## carries the inventory `script_mart` wrote behind the id.
## `script_mart` writes the shelf into the text pointer, so a counter is named by its map and text row.
static func _gen1_mart_steps(world: Gen2WorldAPI, row: Dictionary, text_id: int) -> Array:
	var items: Variant = Gen1ScriptNodes._gen1_event_site(world,
		Gen2WorldCatalog.KIND_SHOP, Gen2WorldCatalog.GEN1_SOURCE_TEXT, text_id - 1,
		{"items": row.get("items", [])}
	)["items"]
	if not items is Array or (items as Array).is_empty():
		return []
	var place: Vector2i = world.map_id()
	return [{"type": &"request", "values": {
		"kind": &"mart_requested",
		"values": {
			"dialog": Gen2WorldMartHost.MARTTYPE_STANDARD,
			"address": 0,
			"items": (items as Array).duplicate(),
			"map_group": place.x,
			"map_number": place.y,
			"text_id": text_id,
		},
	}}]


## `DisplayPokemonCenterDialogue_`: `ShallWeHealYourPokemonText` is the first
## visit's alone, `BIT_USED_POKECENTER` set behind it, and `YesNoChoicePokeCenter`
## opens over whichever box was last. `SetLastBlackoutMap` is YES's, ahead of the heal.
## Yellow's starter, asleep at Pewter's, answers with `LooksContentText` alone.
static func _gen1_nurse_steps(world: Gen2WorldAPI) -> Array:
	if world.pikachu != null and world.current_map.number == Gen1Layout.PEWTER_POKECENTER \
		and not world.pikachu.following():
		return [_gen1_facility_box(world, "pokecenter_pikachu", "looks_content")]
	var used: int = Gen1Layout.status_flag_4(Gen1Layout.USED_POKECENTER_BIT)
	var asked: bool = world.state.is_engine_flag_active(used)
	world.state.set_engine_flag(used, true)
	var farewell: Array = [_gen1_pokecenter_box(world, "farewell")]
	var steps: Array = [] if asked else [_gen1_pokecenter_box(world, "welcome")]
	var heal: Array = _gen1_yellow_heal_steps(world) if world.pikachu != null else _gen1_red_heal_steps(world)
	return steps + [
		{
			"type": &"choice",
			"text": String(_gen1_pokecenter_box(world, "welcome")["text"]) if asked \
				else _gen1_pokecenter_text(world, "shall_we_heal"),
			"yes": [{"type": &"blackout_map"}] + heal + farewell,
			"no": farewell,
		},
	]


## Red and Blue's YES: image $18 turns the nurse to the machine until
## `AnimateHealingMachine`'s `UpdateSprites`, and $14 bows after the second line.
static func _gen1_red_heal_steps(world: Gen2WorldAPI) -> Array:
	var steps: Array = [_gen1_pokecenter_box(world, "need_your_pokemon")]
	steps.append_array(_gen1_nurse_pose(world, Vector2i.LEFT, Gen1Layout.NURSE_RED_TURN_FRAMES))
	steps.append({"type": &"request", "values": {"kind": &"party_heal_requested", "values": {}}})
	steps.append(_gen1_heal_machine_step(world))
	steps.append_array(_gen1_nurse_pose(world, Vector2i.DOWN, 0))
	steps.append(_gen1_pokecenter_box(world, "fighting_fit"))
	steps.append_array(_gen1_nurse_bow(world, Gen1Layout.NURSE_RED_BOW_FRAMES))
	steps.append_array(_gen1_nurse_pose(world, Vector2i.DOWN, 0))
	return steps


## Yellow's YES. `IsStarterPikachuAliveInOurParty` is read before the heal and
## after it, and `HealParty` follows the animation.
static func _gen1_yellow_heal_steps(world: Gen2WorldAPI) -> Array:
	var following: bool = world.pikachu.following()
	var alive: bool = world.pikachu.starter_alive()
	var kept: bool = world.gen1_starter_slot() >= 0
	var steps: Array = []
	if alive and following:
		steps.append(_gen1_nurse_delay(Gen1Layout.PIKACHU_REDRAW_FRAMES))
		steps.append_array(_gen1_nurse_joy_walk(world))
	steps.append(_gen1_pokecenter_box(world, "need_your_pokemon"))
	steps.append(_gen1_nurse_delay(Gen1Layout.NURSE_BOW_FRAMES))
	if following:
		steps.append({"type": &"pikachu", "what": "drawing", "value": false})
		if alive:
			steps.append_array(_gen1_nurse_bow(world))
	steps.append_array(_gen1_nurse_pose(world, Vector2i.LEFT))
	steps.append(_gen1_nurse_delay(Gen1Layout.NURSE_MACHINE_LEAD_FRAMES))
	steps.append(_gen1_heal_machine_step(world))
	steps.append({"type": &"request", "values": {"kind": &"party_heal_requested", "values": {}}})
	if following:
		if kept:
			steps.append_array(_gen1_nurse_bow(world))
		steps.append({"type": &"pikachu", "what": "spawn_state", "value": Gen1Pikachu.SPAWN_ABOVE})
		steps.append({"type": &"pikachu", "what": "drawing", "value": true})
	steps.append_array(_gen1_nurse_pose(world, Vector2i.DOWN))
	steps.append(_gen1_pokecenter_box(world, "fighting_fit"))
	if kept:
		steps.append({"type": &"pikachu", "what": "face", "value": Gen1Pikachu.FACING_DOWN})
		steps.append(_gen1_nurse_delay(Gen1Layout.NURSE_TURN_FRAMES))
	steps.append(_gen1_nurse_delay(Gen1Layout.PIKACHU_REDRAW_FRAMES))
	steps.append(_gen1_nurse_delay(Gen1Layout.NURSE_FIT_FRAMES))
	return steps


## `Func_6ebb` on the nurse.
static func _gen1_nurse_pose(
	world: Gen2WorldAPI,
	direction: Vector2i, frames: int = Gen1Layout.NURSE_TURN_FRAMES
) -> Array:
	var steps: Array = [
		{"type": &"object_facing", "index": 0, "facing": world.facing_for_direction(direction)},
	]
	if frames > 0:
		steps.append(_gen1_nurse_delay(frames))
	return steps


## `Func_6eaa`: her UP image, which bows.
static func _gen1_nurse_bow(world: Gen2WorldAPI, frames: int = Gen1Layout.NURSE_BOW_FRAMES) -> Array:
	return _gen1_nurse_pose(world, Vector2i.UP, frames)


static func _gen1_nurse_delay(frames: int) -> Dictionary:
	return _gen1_wait_step(&"nurse_delay", frames)


## `PikachuWalksToNurseJoy.GetMovementData`.
static func _gen1_nurse_joy_walk(world: Gen2WorldAPI) -> Array:
	var scripts: Array = world.data.gen1_pikachu().get("nurse_movements", []) if world.data != null else []
	var at: Vector2i = world.pikachu.cell
	var which: int = -1
	if at.y > world.player_cell.y:
		which = 0
	elif at.y == world.player_cell.y:
		which = 2 if at.x > world.player_cell.x else 1
	var steps: Array = []
	if which >= 0 and which < scripts.size():
		Gen1ScriptNodes._gen1_node_pikachu_movement(world, {"bytes": scripts[which]}, steps, {})
	return steps


## `farcall AnimateHealingMachine`, the step behind `predef HealParty`, which the
## dialogue waits out before its last two lines. `.partyLoop` sounds one ball
## every `ld c, 30`, and the flashes open on `MUSIC_PKMN_HEALED`.
static func _gen1_heal_machine_step(world: Gen2WorldAPI) -> Dictionary:
	var balls: int = int(world._party_summary.get("count", 0))
	var flashes_at: int = balls * Gen2WorldEffects.HEAL_MACHINE_BALL_FRAMES
	var frames: int = flashes_at + Gen2WorldEffects.HEAL_MACHINE_FLASHES \
		* Gen2WorldEffects.HEAL_MACHINE_FLASH_INTERVAL
	var sounds: Array = [{
		"frame": 0, "gen1": true, "index": Gen1SoundEngine.SFX_STOP_ALL_MUSIC,
	}]
	for ball: int in balls:
		sounds.append({
			"frame": ball * Gen2WorldEffects.HEAL_MACHINE_BALL_FRAMES,
			"gen1": true, "index": Gen1Sfx.SFX_HEALING_MACHINE,
		})
	sounds.append({
		"frame": flashes_at, "gen1": true, "index": Gen1Layout.MUSIC_PKMN_HEALED,
	})
	return _gen1_wait_step(&"heal_machine_anim", frames, {
		"machine_type": 0, "balls": balls, "sounds": sounds,
	})


## A counted wait, with the `presentation_special_applied` event a screen would
## start it from when [param presentation] names one.
static func _gen1_wait_step(kind: StringName, frames: int, presentation: Dictionary = {}
) -> Dictionary:
	var step: Dictionary = {"type": &"wait", "values": {
		"type": &"wait",
		"wait": Gen2WorldScriptRunner.WAIT_FRAMES,
		"kind": kind,
		"frames": frames,
	}}
	if not presentation.is_empty():
		var event: Dictionary = presentation.duplicate(true)
		event["type"] = &"presentation_special_applied"
		event["kind"] = kind
		step["events"] = [event]
	return step


static func _gen1_pokecenter_box(world: Gen2WorldAPI, name: String) -> Dictionary:
	return _gen1_facility_box(world, GEN1_POKECENTER_RUN, name)


static func _gen1_pokecenter_text(world: Gen2WorldAPI, name: String) -> String:
	return world.data.special_text(GEN1_POKECENTER_RUN, name) if world.data != null else ""


static func _gen1_facility_box(world: Gen2WorldAPI, run: String, name: String) -> Dictionary:
	return {
		"type": &"text",
		"text": Gen1ScriptNodes.gen1_filled_text(world,
			world.data.special_text(run, name)
		) if world.data != null else "",
	}


static func _gen1_event_at(world: Gen2WorldAPI, cell: Vector2i, kind: StringName) -> Dictionary:
	for event: Dictionary in world._active_events_at(cell):
		if event.get("kind", &"") == kind and int(event.get("text", 0)) > 0:
			return event
	return {}


## `TalkToTrainer`: the flag, the after or before line, `EngageMapTrainer` unless
## [param seen], and `StartTrainerBattle`. Standing wild Pokemon share the header.
static func _gen1_trainer_steps(world: Gen2WorldAPI, row: Dictionary, event: Dictionary, seen: bool = false) -> Array:
	var raw: Variant = row.get("trainer", {})
	if not raw is Dictionary or (raw as Dictionary).is_empty():
		return []
	var header: Dictionary = raw as Dictionary
	var flag: int = int(header["event_flag"])
	world._gen1_scratch[int(Gen1Layout.for_id(world.data.id)["trainer_header_flag_bit"])] = flag % 8
	if world.event_flag_active(flag):
		if header.has("after_script"):
			var steps: Array = []
			return steps if Gen1ScriptNodes._gen1_resolve_script(world, header["after_script"], steps, Gen1ScriptNodes._gen1_run(world, event)) else []
		return [{"type": &"text", "text": Gen1ScriptNodes.gen1_filled_text(world, String(header["after"]))}]
	var fight: Array = [{"type": &"text", "text": Gen1ScriptNodes.gen1_filled_text(world, String(header["before"]))}]
	if not seen:
		_gen1_engage_music(world, event, fight)
	fight.append({
		"type": &"request",
		"values": {
			"kind": &"battle_requested",
			"values": _gen1_battle_values(world, header, event),
		},
		"trainer_flag": flag,
		"object_index": int(event.get("object_index", -1)),
		"standing_wild": not event.has("trainer_class"),
		"end_script": header.get("end_script", []),
	})
	return fight


## `EngageMapTrainer`'s `PlayTrainerMusic`, under a printed box's wait for the press.
static func _gen1_engage_music(world: Gen2WorldAPI, event: Dictionary, steps: Array) -> void:
	if int(world._gen1_volatile.get("gym_leader", 0)) != 0:
		return
	## A standing Pokemon's species byte is in no list, so it plays Youngster's.
	var record: Dictionary = world.data.trainer_encounter_music(
		int(event.get("trainer_class", Gen1Layout.YOUNGSTER_CLASS))
	)
	if record.is_empty():
		return
	var music: Dictionary = Gen1ScriptNodes._gen1_sound_step(world, "music", {
		"index": int(record["sound_id"]), "bank": int(record["bank"]),
	})
	var last: Dictionary = steps.back() if not steps.is_empty() else {}
	if StringName(last.get("type", &"")) == &"text" and bool(last.get("press", true)):
		last["press"] = false
		steps.append({"type": &"button", "arrow": true, "events": [music["event"]]})
		return
	steps.append(music)


## `InitBattleEnemyParameters` splits the object's two bytes on `OPP_ID_OFFSET`:
## above it a trainer class and party, below a species and a level.
static func _gen1_battle_values(world: Gen2WorldAPI, header: Dictionary, event: Dictionary) -> Dictionary:
	if not event.has("trainer_class"):
		var site: Dictionary = Gen1ScriptNodes._gen1_event_site(world,
			Gen2WorldCatalog.KIND_STATIC, Gen2WorldCatalog.GEN1_SOURCE_OBJECT,
			int(event.get("object_index", -1)),
			{"species": int(event.get("species", 0)), "level": int(event.get("level", 0))}
		)
		return {"kind": &"wild", "pokemon": int(site["species"]), "level": int(site["level"])}
	var trainer_class: int = int(event["trainer_class"])
	var spoken: Dictionary = {"text": "%s: %s" % [
		_gen1_trainer_name(world, trainer_class), String(header["end"]),
	]}
	return {
		"kind": &"trainer",
		"trainer_group": trainer_class,
		"trainer_class": trainer_class,
		"trainer_id": maxi(int(event.get("trainer_number", 1)) - 1, 0),
		"object_index": int(event.get("object_index", -1)),
		"trainer_name": _gen1_trainer_name(world, trainer_class),
		"win_text": spoken,
		"loss_text": _gen1_loss_text(world, trainer_class),
		"defeated_text": _gen1_defeated_text(world, trainer_class),
	}


## `GetTrainerName_`: the rival's own name for his three classes.
static func _gen1_trainer_name(world: Gen2WorldAPI, trainer_class: int) -> String:
	if trainer_class in Gen1Layout.RIVAL_CLASSES:
		return world.rival_name
	return world.data.trainer_name(trainer_class) if world.data != null else ""


## `TrainerDefeatedText`, the first line `TrainerBattleVictory` prints.
static func _gen1_defeated_text(world: Gen2WorldAPI, trainer_class: int) -> String:
	return gen1_trainer_text(world, "defeated", _gen1_trainer_name(world, trainer_class))


## A `link_battle` row with `wTrainerName`'s marker filled with [param name].
static func gen1_trainer_text(world: Gen2WorldAPI, text: String, name: String) -> String:
	if world.data == null:
		return ""
	var layout: Dictionary = Gen1Layout.for_id(world.data.id)
	return Gen1ScriptNodes.gen1_filled_text(world, world.data.special_text("link_battle", text).replace(
		"%s%04X>" % [Gen2TextStream.RAM_MARKER, int(layout["trainer_name_wram"])], name
	))


## `HandlePlayerBlackOut`: OPP_RIVAL1 alone says a line on a loss. The lose row
## `SaveEndBattleTextPointers` keeps is printed by nothing.
static func _gen1_loss_text(world: Gen2WorldAPI, trainer_class: int) -> Dictionary:
	if trainer_class != Gen1Layout.RIVAL1_CLASS or world.data == null:
		return {}
	return {"text": Gen1ScriptNodes.gen1_filled_text(world, world.data.special_text("link_battle", "rival1_win"))}


## `IsGhostBattle` and `PrintBeginningBattleText`'s `.pokemonTower`: a wild on
## the tower's floors is a GHOST without a SILPH SCOPE in the bag, and
## RESTLESS_SOUL, the MAROWAK, appears as one and is unveiled with it.
static func gen1_ghost_kind(world: Gen2WorldAPI, species: int) -> StringName:
	if not world._gen1 or world.current_map == null or world.state == null \
		or world.current_map.number < Gen1Layout.POKEMON_TOWER_1F \
		or world.current_map.number > Gen1Layout.POKEMON_TOWER_7F:
		return &""
	if world.state.item_quantity(Gen1Layout.ITEM_SILPH_SCOPE) <= 0:
		return Gen1Layout.GHOST_UNIDENTIFIED
	return Gen1Layout.GHOST_UNVEILED if species == Gen1Layout.RESTLESS_SOUL else &""


## `PlayerBlackedOutText2`, printed over the fight the party was lost in.
static func gen1_blackout_text(world: Gen2WorldAPI) -> String:
	return Gen1ScriptNodes.gen1_filled_text(world, world.data.special_text("link_battle", "blacked_out")) \
		if world._gen1 and world.data != null else ""


## `.battleOccurred`'s `AnyPartyAlive` behind every Generation 1 fight but one on
## OAKS_LAB, whatever the fight came to. With no save to read, the outcome stands
## in. A `wPartyCount` of zero, which is Yellow's Pikachu demo, runs its loop 256
## times over the WRAM past the party and ORs a nonzero byte: alive.
static func gen1_blackout_due(world: Gen2WorldAPI, save: Gen2SaveData, outcome: StringName) -> bool:
	if not world._gen1 or world.current_map == null or world.current_map.number == Gen1Layout.OAKS_LAB:
		return false
	if save == null:
		return outcome == Gen2WorldBattleAdapter.OUTCOME_LOST
	return not save.party.is_empty() and not Gen2WorldPartyHost.party_has_fit_mon(save)
