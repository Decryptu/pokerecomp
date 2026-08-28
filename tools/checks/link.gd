extends RefCounted

## Sweeps link play against freshly imported real caches, all three cartridges. The
## class this exists to catch is a cable club that answers a question the cartridge
## does not ask: every one of the three receptionist scripts is the same shape and
## none can be reached without a peer, so the two paths that matter are the one a
## single console gets and the one a peer gets, and both are driven on the real map.
## `LinkCommsBorderGFX` is checked as the two different things it is, seventy tiles
## and a screen tilemap on Crystal against nine tiles and no tilemap on Gold and
## Silver, which is the whole difference between the two trade screens.

## `newgroup CABLE_CLUB`, the same group and numbers in both pins.
const CABLE_CLUB_GROUP: int = 20
const POKECENTER_2F: int = 1
const TRADE_CENTER: int = 2
const COLOSSEUM: int = 3
const TIME_CAPSULE: int = 4

## `Pokecenter2F_MapEvents`' own object rows: the three receptionists stand one
## cell above where the player talks to them.
const TRADE_RECEPTIONIST_CELL: Vector2i = Vector2i(5, 3)
const BATTLE_RECEPTIONIST_CELL: Vector2i = Vector2i(9, 3)
const TIME_CAPSULE_RECEPTIONIST_CELL: Vector2i = Vector2i(13, 4)
## `bg_event 7, 3, BGEVENT_READ, Pokecenter2FLinkRecordSign`.
const LINK_RECORD_SIGN_CELL: Vector2i = Vector2i(7, 4)
## `bg_event 4, 4, BGEVENT_RIGHT` in each room, which is read by facing right
## from the cell to its left.
const CONSOLE_CELL: Vector2i = Vector2i(3, 4)

## `EVENT_GAVE_MYSTERY_EGG_TO_ELM`, which is what opens the trade and battle
## rooms; the Time Capsule is gated on `EVENT_MET_BILL` being clear instead.
const EVENT_GAVE_MYSTERY_EGG_TO_ELM: int = 31

## How many script steps a receptionist path is given before it is called stuck.
const STEP_CAP: int = 400

## A party that passes every Time Capsule test: two Kanto species, no mail and
## no move past `STRUGGLE`.
const LEGAL_PARTY: Dictionary = {
	"species": [1, 4], "held_items": [0, 0], "moves": [[1, 2], [3, 4]],
	"names": ["ONE", "TWO"],
}

var _r: RefCounted = null


func run(r: RefCounted) -> void:
	_r = r
	_r.each_game(func() -> void:
		_verify_border()
		_verify_texts()
		_verify_no_cable()
		_verify_with_peer()
		_verify_time_capsule_receptionist()
		_verify_rooms()
		_verify_record_sign()
	)
	_verify_compatibility()
	_verify_record()


## `LinkCommsBorderGFX` and the tilemaps behind it, which are the one part of
## the trade screen the two cartridges do not share.
func _verify_border() -> void:
	var data: GameData = _r.data
	if not _r.check(data.has_link_border(), "no trade screen border in the cache"):
		return
	var tiles: int = RomLayout.LINK_BORDER_TILES_CRYSTAL if _r.crystal \
		else RomLayout.LINK_BORDER_TILES_GOLD_SILVER
	_r.check(
		data.link_border_indices().size() == tiles * Gen2Tiles.TILE_WIDTH \
			* Gen2Tiles.TILE_HEIGHT,
		"the border strip is not %d tiles" % tiles
	)
	var screen: PackedByteArray = data.link_border_tilemap("screen")
	_r.check(
		screen.is_empty() != _r.crystal,
		"the cartridge %s a trade screen tilemap" % [
			"carries" if not screen.is_empty() else "carries no",
		]
	)
	if not _r.crystal:
		return
	_r.check(
		screen.size() == RomLayout.LINK_TRADE_TILEMAP_BYTES,
		"the screen tilemap is %d bytes" % screen.size()
	)
	for name: String in ["cable_top", "cable_bottom"]:
		_r.check(
			data.link_border_tilemap(name).size() == RomLayout.LINK_TRADE_CABLE_ROWS_BYTES,
			"%s is %d bytes" % [name, data.link_border_tilemap(name).size()]
		)
	var page: Gen2LinkPage = Gen2LinkPage.from_data(data)
	if not _r.check(page != null, "the trade page will not build"):
		return
	## The screen the player actually sees, drawn once: a page that draws nothing
	## is a blank buffer, and the border alone fills more than a tenth of it.
	var drawn: PackedByteArray = page.draw_trade({
		"player": {"name": "RED", "species": ["ONE", "TWO"]},
		"partner": {"name": "BLUE", "species": ["THREE"]},
		"list": 0, "index": 0, "footer": -1, "confirm": -1,
	})
	var ink: int = 0
	for value: int in drawn:
		if value != 0:
			ink += 1
	_r.check(
		ink > drawn.size() / 10,
		"the trade screen drew %d of %d pixels" % [ink, drawn.size()]
	)


## The trade screen's three imported boxes, each by the words that identify it
## and by the `text_ram` it names.
func _verify_texts() -> void:
	var data: GameData = _r.data
	if not _r.check(data.has_special_text("link"), "no link text run in the cache"):
		return
	_r.check(
		data.special_text("link", "cant_battle").contains("be able to battle"),
		"cant_battle reads %s" % data.special_text("link", "cant_battle")
	)
	_r.check(
		data.special_text("link", "abnormal_mon").contains("abnormal"),
		"abnormal_mon reads %s" % data.special_text("link", "abnormal_mon")
	)
	var ask: String = data.special_text("link", "ask_trade")
	_r.check(ask.begins_with("Trade "), "ask_trade reads %s" % ask)
	var address: int = data.special_text_ram("trademon_nickname")
	_r.check(
		address > 0 and ask.contains("%s%04X>" % [Gen2TextStream.RAM_MARKER, address]),
		"ask_trade does not name wBufferTrademonNickname (%04X)" % address
	)


## The path a single console gets, which is the only one a player without a
## second save file can reach: `WaitForLinkedFriend` times out, the receptionist
## says the friend is not ready, and the script ends where it stands.
func _verify_no_cable() -> void:
	var world: Gen2WorldAPI = _open_center(null)
	if world == null:
		return
	var results: Array = _talk(world, TRADE_RECEPTIONIST_CELL)
	## `yesorno` after `Text_TradeReceptionistIntro`.
	if not _r.check(_offers_choice(results), "the trade receptionist asked nothing"):
		return
	results = world.choose_script_input(0)
	results.append_array(_settle(world))
	_r.check(
		not world.script_busy(),
		"the receptionist's script did not finish without a cable"
	)
	var session: Gen2LinkSession = world.state.link_session()
	_r.check(
		session.link_mode == Gen2LinkSession.LINK_NULL,
		"a timed-out link left wLinkMode at %d" % session.link_mode
	)
	_r.check(
		session.connection_status == Gen2LinkSession.CONNECTION_NOT_ESTABLISHED,
		"a timed-out link left the serial port open"
	)
	## `Text_PleaseWait` is the box the timeout stands behind, and the one that
	## follows it is `.FriendNotReady`'s, which the script prints and closes
	## without a `waitbutton` of its own.
	_r.check(
		not _said(results, "Please wait").is_empty(),
		"the receptionist did not print the waiting box"
	)
	_r.check(
		world.pending_runtime_request().is_empty(),
		"a timed-out link still opened %s" % [
			world.pending_runtime_request().get("kind", &"none"),
		]
	)


## The same path with a peer on the other end, which reaches the room: the save
## prompt, the timeout check, the room agreement and the walk in.
func _verify_with_peer() -> void:
	var world: Gen2WorldAPI = _open_center(_peer(Gen2LinkSession.CABLECLUBROOM_TRADECENTER))
	if world == null:
		return
	var results: Array = _talk(world, TRADE_RECEPTIONIST_CELL)
	if not _r.check(_offers_choice(results), "the trade receptionist asked nothing"):
		return
	results = world.choose_script_input(0)
	results.append_array(_settle(world))
	## `Text_MustSaveGame`'s own yesorno.
	if not _r.check(_offers_choice(results), "the receptionist did not offer to save"):
		return
	results = world.choose_script_input(0)
	results.append_array(_settle(world))
	var session: Gen2LinkSession = world.state.link_session()
	_r.check(
		session.chosen_room == Gen2LinkSession.CABLECLUBROOM_TRADECENTER,
		"the trade receptionist chose room %d" % session.chosen_room
	)
	_r.check(
		session.other_player_link_mode != 0,
		"a Gen 2 peer was read as a Gen 1 game"
	)
	_r.check(
		session.link_mode == Gen2LinkSession.LINK_TRADECENTER,
		"the agreed room left wLinkMode at %d" % session.link_mode
	)
	_r.check(
		not session.peer.is_empty(),
		"the peer's own party never came back over the cable"
	)
	## The Colosseum's receptionist is the same script with the other room.
	var battle_world: Gen2WorldAPI = _open_center(
		_peer(Gen2LinkSession.CABLECLUBROOM_COLOSSEUM)
	)
	if battle_world == null:
		return
	var battle_results: Array = _talk(battle_world, BATTLE_RECEPTIONIST_CELL)
	if not _r.check(
		_offers_choice(battle_results), "the battle receptionist asked nothing"
	):
		return
	battle_results = battle_world.choose_script_input(0)
	battle_results.append_array(_settle(battle_world))
	if _offers_choice(battle_results):
		battle_results = battle_world.choose_script_input(0)
		battle_results.append_array(_settle(battle_world))
	_r.check(
		battle_world.state.link_session().link_mode == Gen2LinkSession.LINK_COLOSSEUM,
		"the battle receptionist agreed room %d" % \
			battle_world.state.link_session().link_mode
	)


## The Time Capsule with a Gen 2 peer, which is the one room two of these
## cartridges can never open: `SetBitsForTimeCapsuleRequest` asks for
## `CABLECLUBROOM_NULL` and `readmem wOtherPlayerLinkMode` is non-zero for a
## Gen 2 game, so the script takes `CheckBothSelectedSameRoom` and the
## incompatible-rooms box.
func _verify_time_capsule_receptionist() -> void:
	var world: Gen2WorldAPI = _open_center(
		_peer(Gen2LinkSession.CABLECLUBROOM_NULL)
	)
	if world == null:
		return
	var results: Array = _talk(world, TIME_CAPSULE_RECEPTIONIST_CELL)
	if not _r.check(_offers_choice(results), "the Time Capsule receptionist asked nothing"):
		return
	results = world.choose_script_input(0)
	results.append_array(_settle(world))
	if _offers_choice(results):
		results = world.choose_script_input(0)
		results.append_array(_settle(world))
	_r.check(
		world.state.link_session().link_mode != Gen2LinkSession.LINK_TIMECAPSULE,
		"a Gen 2 peer was let into the Time Capsule"
	)


## The three rooms: `CableClubCheckWhichChris` decides which friend is standing
## there and the console runs the exchange the room is for.
func _verify_rooms() -> void:
	for room: Array in [
		[TRADE_CENTER, Gen2LinkSession.LINK_TRADECENTER],
		[COLOSSEUM, Gen2LinkSession.LINK_COLOSSEUM],
		[TIME_CAPSULE, Gen2LinkSession.LINK_TIMECAPSULE],
	]:
		var state := Gen2WorldState.new()
		state.set_link_transport(_peer(Gen2LinkSession.CABLECLUBROOM_TRADECENTER))
		var world: Gen2WorldAPI = _r.open_world(
			CABLE_CLUB_GROUP, int(room[0]), CONSOLE_CELL, state
		)
		if world == null:
			continue
		_settle_results(world, world.dispatch_map_entry())
		## `MAPCALLBACK_OBJECTS` runs `CableClubCheckWhichChris`, which is the
		## internal clock's side here: the player who opened the receptionist
		## holds it, so the friend on the left is the one shown.
		_r.check(
			state.link_session().which_chris(state.link_transport()) == 0,
			"room %d put the wrong friend on screen" % int(room[0])
		)
		world.player_facing = Gen2WorldSprite.FACING_RIGHT
		var results: Array = world.interact()
		results.append_array(_settle(world))
		var request: Dictionary = world.pending_runtime_request()
		if not _r.check(
			StringName(request.get("kind", &"")) == &"link_room_requested",
			"room %d's console staged %s" % [
				int(room[0]), request.get("kind", &"none"),
			]
		):
			continue
		_r.check(
			int((request.get("values", {}) as Dictionary).get("link_mode", 0)) == int(room[1]),
			"room %d opened link mode %d" % [
				int(room[0]),
				int((request.get("values", {}) as Dictionary).get("link_mode", 0)),
			]
		)


## `Pokecenter2FLinkRecordSign`, which is one `special DisplayLinkRecord` and
## nothing else: it writes no state and the script runs on behind it.
func _verify_record_sign() -> void:
	var world: Gen2WorldAPI = _open_center(null)
	if world == null:
		return
	world.player_cell = LINK_RECORD_SIGN_CELL
	world.player_facing = Gen2WorldSprite.FACING_UP
	## Not settled: `DisplayLinkRecord` is the request itself, and answering it
	## is what would take it off the pending slot before it could be read.
	world.interact()
	var request: Dictionary = world.pending_runtime_request()
	_r.check(
		StringName(request.get("kind", &"")) == &"link_record_requested",
		"the link record sign staged %s" % request.get("kind", &"none")
	)


## `CheckTimeCapsuleCompatibility`'s four answers, each on a party that fails
## exactly one of its three tests and in the order the routine runs them.
func _verify_compatibility() -> void:
	var cases: Array = [
		[LEGAL_PARTY, Gen2LinkSession.TIME_CAPSULE_OK, -1],
		[{
			"species": [1, 152], "held_items": [0, 0], "moves": [[1], [1]],
		}, Gen2LinkSession.TIME_CAPSULE_MON_TOO_NEW, 1],
		[{
			"species": [1, 4], "held_items": [0, Gen2HeldItem.MAIL_ITEMS[0]],
			"moves": [[1], [1]],
		}, Gen2LinkSession.TIME_CAPSULE_MON_HAS_MAIL, 1],
		[{
			"species": [1, 4], "held_items": [0, 0], "moves": [[1], [166]],
		}, Gen2LinkSession.TIME_CAPSULE_MOVE_TOO_NEW, 1],
	]
	for row: Array in cases:
		var verdict: Dictionary = Gen2LinkSession.time_capsule_compatibility(row[0])
		_r.check(
			int(verdict["value"]) == int(row[1]),
			"a party expecting answer %d got %d" % [int(row[1]), int(verdict["value"])]
		)
		_r.check(
			int(verdict["slot"]) == int(row[2]),
			"answer %d named slot %d rather than %d" % [
				int(row[1]), int(verdict["slot"]), int(row[2]),
			]
		)
	## The species test runs before the mail test, so a party that fails both is
	## refused for the species.
	var both: Dictionary = Gen2LinkSession.time_capsule_compatibility({
		"species": [152], "held_items": [Gen2HeldItem.MAIL_ITEMS[0]], "moves": [[1]],
	})
	_r.check(
		int(both["value"]) == Gen2LinkSession.TIME_CAPSULE_MON_TOO_NEW,
		"the three tests do not run in the routine's order"
	)


## `AddLastLinkBattleToLinkRecord`: the totals, an opponent's own row, and the
## cap neither carries past.
func _verify_record() -> void:
	var record: Dictionary = Gen2LinkSession.normalize_record({})
	_r.check(
		(record["records"] as Array).size() == Gen2LinkSession.NUM_LINK_BATTLE_RECORDS,
		"an empty record does not carry its five rows"
	)
	var opponent: Dictionary = {"name": "BLUE", "id": 1234}
	for _win: int in 3:
		record = Gen2LinkSession.add_battle_to_record(record, opponent, &"wins")
	record = Gen2LinkSession.add_battle_to_record(record, opponent, &"losses")
	_r.check(int(record["wins"]) == 3, "three wins counted as %d" % int(record["wins"]))
	_r.check(int(record["losses"]) == 1, "one loss counted as %d" % int(record["losses"]))
	var row: Dictionary = (record["records"] as Array)[0]
	_r.check(
		String(row.get("name", "")) == "BLUE" and int(row.get("wins", 0)) == 3,
		"the opponent's own row reads %s" % [row]
	)
	## A second opponent takes a row of its own rather than the first one's.
	record = Gen2LinkSession.add_battle_to_record(
		record, {"name": "GREEN", "id": 9}, &"wins"
	)
	var names: Array = []
	for entry: Dictionary in record["records"] as Array:
		names.append(String(entry.get("name", "")))
	_r.check(
		names.has("BLUE") and names.has("GREEN"),
		"two opponents did not both keep a row: %s" % [names]
	)
	## `.CheckOverflow`, which stops rather than wrapping.
	var capped: Dictionary = Gen2LinkSession.normalize_record({
		"wins": Gen2LinkSession.MAX_LINK_RECORD,
	})
	capped = Gen2LinkSession.add_battle_to_record(capped, opponent, &"wins")
	_r.check(
		int(capped["wins"]) == Gen2LinkSession.MAX_LINK_RECORD,
		"the win counter passed its cap"
	)


func _peer(room: int) -> Gen2LinkTransport:
	var transport := Gen2LinkTransport.new()
	transport.peer = {
		"name": "BLUE", "id": 4242, "gender": 0,
		"generation": Gen2LinkTransport.GENERATION_2,
		"room": room,
		"party": [{"species": 1, "level": 5, "hp": 20, "moves": [1, 0, 0, 0]}],
	}
	return transport


func _open_center(transport: Gen2LinkTransport) -> Gen2WorldAPI:
	var state := Gen2WorldState.new()
	state.apply_changes({EVENT_GAVE_MYSTERY_EGG_TO_ELM: true}, {}, {})
	state.set_link_transport(transport)
	var world: Gen2WorldAPI = _r.open_world(
		CABLE_CLUB_GROUP, POKECENTER_2F, TRADE_RECEPTIONIST_CELL, state
	)
	if world == null:
		return null
	world.set_party_summary(
		2, false, [1, 4] as Array[int], LEGAL_PARTY["moves"], LEGAL_PARTY["names"],
		[false, false], {"held_items": [0, 0], "levels": [5, 5]}
	)
	return world


func _talk(world: Gen2WorldAPI, cell: Vector2i) -> Array:
	world.player_cell = cell
	world.player_facing = Gen2WorldSprite.FACING_UP
	var results: Array = world.interact()
	results.append_array(_settle(world))
	return results


## Answers everything the script asks for that is not a choice, the way the
## screen answers it: the frames a link routine spends, the quick save it asks
## to write, and the movements between the receptionist and the door.
func _settle(world: Gen2WorldAPI) -> Array:
	var out: Array = []
	for _step: int in STEP_CAP:
		if _offers_choice_pending(world):
			return out
		var request: Dictionary = world.pending_runtime_request()
		if not request.is_empty():
			if StringName(request.get("kind", &"")) == &"link_room_requested":
				return out
			out.append_array(world.complete_runtime_request({"ok": true}))
			continue
		if not world.pending_script_wait().is_empty():
			out.append_array(world.advance_script_presentation_frame())
			continue
		if not world.script_busy():
			return out
		out.append_array(world.run_event_queue(true, -1))
	_r.fail("a link script ran past %d steps" % STEP_CAP)
	return out


func _settle_results(world: Gen2WorldAPI, results: Array) -> Array:
	results.append_array(_settle(world))
	return results


func _offers_choice_pending(world: Gen2WorldAPI) -> bool:
	var pending: Dictionary = world.pending_script_input()
	return StringName(pending.get("type", &"")) in [&"choice", &"menu"]


func _offers_choice(results: Array) -> bool:
	for result: Dictionary in results:
		var event: Dictionary = result.get("event", {})
		if StringName(event.get("type", &"")) in [&"choice", &"menu"]:
			return true
	return false


## The first box in [param results] carrying [param words], or the empty string.
func _said(results: Array, words: String) -> String:
	for result: Dictionary in results:
		var event: Dictionary = result.get("event", {})
		var text: String = String(event.get("text", ""))
		if text.contains(words):
			return text
	return ""
