class_name Gen2LinkSession
extends RefCounted

## `SECTION "Link Battle Data"` and every routine the cable club reaches through
## it: `wLinkMode`, `wPlayerLinkAction`, `wChosenCableClubRoom` and
## `wOtherPlayerLinkMode`, plus the answers `WaitForLinkedFriend`,
## `CheckLinkTimeout_Receptionist`, `CheckBothSelectedSameRoom`,
## `CheckTimeCapsuleCompatibility`, `ValidateOTTrademon` and
## `CheckAnyOtherAliveMonsForTrade` give from them.
##
## Scene free, and WRAM rather than save data: the cartridge keeps none of this
## across a reset, and neither does [Gen2WorldState], which holds one live and
## leaves it out of its snapshot. The cable itself is [Gen2LinkTransport], which
## is injected; nothing here knows what it is made of.

const CONNECTION_NOT_ESTABLISHED: int = Gen2LinkTransport.CONNECTION_NOT_ESTABLISHED
const USING_EXTERNAL_CLOCK: int = Gen2LinkTransport.USING_EXTERNAL_CLOCK
const USING_INTERNAL_CLOCK: int = Gen2LinkTransport.USING_INTERNAL_CLOCK

const LINK_NULL: int = Gen2LinkTransport.LINK_NULL
const LINK_TIMECAPSULE: int = Gen2LinkTransport.LINK_TIMECAPSULE
const LINK_TRADECENTER: int = Gen2LinkTransport.LINK_TRADECENTER
const LINK_COLOSSEUM: int = Gen2LinkTransport.LINK_COLOSSEUM

const CABLECLUBROOM_NULL: int = Gen2LinkTransport.CABLECLUBROOM_NULL
const CABLECLUBROOM_TRADECENTER: int = Gen2LinkTransport.CABLECLUBROOM_TRADECENTER
const CABLECLUBROOM_COLOSSEUM: int = Gen2LinkTransport.CABLECLUBROOM_COLOSSEUM

## `CheckTimeCapsuleCompatibility`'s own four answers in wScriptVar.
const TIME_CAPSULE_OK: int = 0
const TIME_CAPSULE_MON_TOO_NEW: int = 1
const TIME_CAPSULE_MOVE_TOO_NEW: int = 2
const TIME_CAPSULE_MON_HAS_MAIL: int = 3

## `JOHTO_POKEMON`, the first species a Gen 1 game has no room for, and
## `STRUGGLE + 1`, the first move index past its own list.
const JOHTO_POKEMON: int = 152
const FIRST_GEN2_MOVE: int = 166

## `MAX_LEVEL + 1`, which is what `ValidateOTTrademon` calls abnormal.
const MAX_LEVEL: int = 100

## MAGNEMITE and MAGNETON, the two species `ValidateOTTrademon` names rather
## than type-checks: Electric became Electric/Steel between the generations.
const TIME_CAPSULE_RETYPED_SPECIES: Array[int] = [81, 82]

## `NUM_LINK_BATTLE_RECORDS` and `MAX_LINK_RECORD`.
const NUM_LINK_BATTLE_RECORDS: int = 5
const MAX_LINK_RECORD: int = 9999

## The frames each routine spends, from its own `ld c` in front of `DelayFrames`.
## None of them is free, and a receptionist that answers instantly is the same
## class of defect the missing fades were.
const WAIT_FOR_FRIEND_CONNECTED_FRAMES: int = 50
const ENTER_TIME_CAPSULE_FRAMES: int = 50
const WAIT_FOR_OTHER_PLAYER_FRAMES: int = 12
const CLOSE_LINK_FRAMES: int = 6
const FAILED_LINK_TO_PAST_FRAMES: int = 40
const CHECK_LINK_TIMEOUT_FRAMES: int = 2

## `wLinkMode`, which the room's own console special reads back and
## `WaitForOtherPlayerToExit` clears.
var link_mode: int = LINK_NULL
## `wPlayerLinkAction`, the room at the receptionist and the menu choice inside
## the trade screen.
var player_link_action: int = CABLECLUBROOM_NULL
## `wChosenCableClubRoom`, the door this player walked up to.
var chosen_room: int = CABLECLUBROOM_NULL
## `wOtherPlayerLinkMode`, which the receptionist scripts `readmem`: zero is a
## Game Boy running a Gen 1 game and the only thing the Time Capsule accepts.
var other_player_link_mode: int = 0
## `hSerialConnectionStatus` as this side last saw it.
var connection_status: int = CONNECTION_NOT_ESTABLISHED
## The peer's own block from the last exchange: its name, id and party. Empty
## until a room has been agreed.
var peer: Dictionary = {}


## `SetBitsForLinkTradeRequest` and `SetBitsForBattleRequest`, which are one
## routine each: the room goes into both `wPlayerLinkAction` and
## `wChosenCableClubRoom`.
func request_room(room: int) -> void:
	player_link_action = room
	chosen_room = room


## `SetBitsForTimeCapsuleRequest`, which asks for no room at all: it opens the
## serial port and leaves both bytes at `CABLECLUBROOM_NULL`.
func request_time_capsule() -> void:
	request_room(CABLECLUBROOM_NULL)


## `WaitForLinkedFriend`. TRUE once the other Game Boy has answered, FALSE when
## its $2ff passes went by without one, which is what a single console always
## gets. The frames the TRUE branch then spends are
## [constant WAIT_FOR_FRIEND_CONNECTED_FRAMES].
func wait_for_linked_friend(transport: Gen2LinkTransport) -> int:
	connection_status = transport.status() if transport != null else CONNECTION_NOT_ESTABLISHED
	if connection_status not in [USING_INTERNAL_CLOCK, USING_EXTERNAL_CLOCK]:
		connection_status = CONNECTION_NOT_ESTABLISHED
		return 0
	return 1


## `CheckLinkTimeout_Receptionist`, which sets `wPlayerLinkAction` to 1 and runs
## `Link_CheckCommunicationError`: FALSE is a link that dropped while the two
## players were saving, and the peer's own action lands in
## `wOtherPlayerLinkMode` for the `readmem` that follows.
##
## A Gen 1 game has no `wPlayerLinkAction` to raise, so what comes back from one
## is zero, which is the whole of the "can't link to the past" branch and the
## whole of what makes the Time Capsule legal.
func check_link_timeout(transport: Gen2LinkTransport) -> int:
	player_link_action = 1
	if transport == null or not transport.connected():
		other_player_link_mode = 0
		reset_serial_registers(transport)
		return 0
	other_player_link_mode = 0 if int(transport.peer.get(
		"generation", Gen2LinkTransport.GENERATION_2
	)) == Gen2LinkTransport.GENERATION_1 else 1
	return 1


## `CheckBothSelectedSameRoom`, which exchanges `wChosenCableClubRoom` and only
## then commits `wLinkMode`. The mode is the room plus one, which is why
## `CABLECLUBROOM_TRADECENTER` becomes `LINK_TRADECENTER`.
func check_both_selected_same_room(transport: Gen2LinkTransport) -> int:
	if transport == null:
		return 0
	if transport.peer_room(chosen_room) != chosen_room:
		return 0
	link_mode = chosen_room + 1
	peer = transport.exchange({"room": chosen_room})
	return 1


## `EnterTimeCapsule`, which agrees a `$4` sync nybble and then sets
## `LINK_TIMECAPSULE` by hand rather than off the chosen room, because the
## Time Capsule's own room byte is `CABLECLUBROOM_NULL`.
func enter_time_capsule(transport: Gen2LinkTransport) -> void:
	if transport != null:
		transport.exchange_nybble(4)
		peer = transport.exchange({"room": CABLECLUBROOM_NULL})
	link_mode = LINK_TIMECAPSULE


## `TimeCapsule`, `TradeCenter` and `Colosseum`: each sets `wLinkMode` again on
## the way into `LinkCommunications`, so the console the player used is what
## decides what is exchanged rather than the receptionist that sent them there.
func open_room(mode: int) -> void:
	link_mode = mode


## `CloseLink`, and `Link_ResetSerialRegistersAfterLinkClosure` behind it.
func close_link(transport: Gen2LinkTransport) -> void:
	link_mode = LINK_NULL
	reset_serial_registers(transport)


## `FailedLinkToPast`, which spends forty frames and agrees an `$e` nybble so
## the Gen 1 game on the other end stops waiting too.
func failed_link_to_past(transport: Gen2LinkTransport) -> void:
	if transport != null:
		transport.exchange_nybble(0xE)


## `WaitForOtherPlayerToExit`, which walks the serial port through both clocks
## and then puts everything back: the timeout counter, `hVBlank` and `wLinkMode`
## all reach zero, which is what makes a cancelled visit leave no link behind.
func wait_for_other_player_to_exit(transport: Gen2LinkTransport) -> void:
	link_mode = LINK_NULL
	peer = {}
	reset_serial_registers(transport)


## `Link_ResetSerialRegistersAfterLinkClosure`.
func reset_serial_registers(transport: Gen2LinkTransport) -> void:
	connection_status = CONNECTION_NOT_ESTABLISHED
	if transport != null:
		transport.close()


## `CableClubCheckWhichChris`, which the three rooms' `MAPCALLBACK_OBJECTS` runs
## to decide which of the two identical friends is standing there: TRUE for the
## player holding the external clock, who is the one on the right.
func which_chris(transport: Gen2LinkTransport) -> int:
	var side: int = transport.status() if transport != null else connection_status
	return 1 if side == USING_EXTERNAL_CLOCK else 0


## `CheckTimeCapsuleCompatibility`, in the order the routine runs its three
## tests: every species slot first, then mail, then moves. The answer is the
## wScriptVar value and the party slot the box names, which is the slot the test
## stopped on rather than the first slot of the party.
##
## [param party] is the world's own party mirror: the parallel `species`,
## `held_items` and `moves` arrays [method Gen2WorldAPI.set_party_summary]
## carries, which is where every other party-reading special gets its answer.
static func time_capsule_compatibility(party: Dictionary) -> Dictionary:
	var species: Array = party.get("species", [])
	var held_items: Array = party.get("held_items", [])
	var moves: Array = party.get("moves", [])
	for slot: int in species.size():
		if int(species[slot]) >= JOHTO_POKEMON:
			return _incompatible(TIME_CAPSULE_MON_TOO_NEW, slot, int(species[slot]), 0)
	for slot: int in held_items.size():
		if Gen2HeldItem.is_mail(int(held_items[slot])):
			return _incompatible(
				TIME_CAPSULE_MON_HAS_MAIL, slot, _species_at(species, slot), 0
			)
	for slot: int in moves.size():
		for move: Variant in moves[slot] as Array:
			if int(move) >= FIRST_GEN2_MOVE:
				return _incompatible(
					TIME_CAPSULE_MOVE_TOO_NEW, slot, _species_at(species, slot),
					int(move)
				)
	return _incompatible(TIME_CAPSULE_OK, -1, 0, 0)


static func _species_at(species: Array, slot: int) -> int:
	return int(species[slot]) if slot < species.size() else 0


static func _incompatible(value: int, slot: int, species: int, move: int) -> Dictionary:
	return {"value": value, "slot": slot, "species": species, "move": move}


## `ValidateOTTrademon`: the offered Pokemon's own species must match the row the
## party list names it by, unless that row says EGG, and its level must be one a
## level can be. The Time Capsule adds a third test, and it is the only one that
## needs the peer to say anything about itself: a Gen 1 game reports the typing
## it holds for the species, and one whose typing this generation changed is
## refused. Magnemite and Magneton are excused by name because theirs is that
## change.
##
## [param mon] carries `types` only when the peer is a Gen 1 game, which is the
## only sender `Link_ConvertPartyStruct1to2` fills `wLinkOTPartyMonTypes` from,
## so a Gen 2 peer skips the test rather than failing an empty one.
static func validate_ot_trademon(
	mon: Dictionary, listed_species: int, listed_is_egg: bool, mode: int,
	base_types: Array = []
) -> bool:
	if not listed_is_egg and listed_species != int(mon.get("species", 0)):
		return false
	if int(mon.get("level", 0)) > MAX_LEVEL:
		return false
	if mode != LINK_TIMECAPSULE:
		return true
	if int(mon.get("species", 0)) in TIME_CAPSULE_RETYPED_SPECIES:
		return true
	var reported: Array = mon.get("types", [])
	if reported.size() < 2 or base_types.size() < 2:
		return true
	return int(reported[0]) == int(base_types[0]) \
		and int(reported[1]) == int(base_types[1])


## `CheckAnyOtherAliveMonsForTrade`. A trade that would leave this side with
## nothing that can fight is refused, so the offered slot is skipped here and
## the incoming Pokemon is what answers for it.
##
## Carry set is the refusal in the source, so this answers the opposite: TRUE
## means the trade may go ahead.
static func any_other_alive_mons_for_trade(
	party: Array, offered_slot: int, incoming: Dictionary
) -> bool:
	for slot: int in party.size():
		if slot == offered_slot:
			continue
		if int((party[slot] as Dictionary).get("hp", 0)) > 0:
			return true
	return int(incoming.get("hp", 0)) > 0


## `AddLastLinkBattleToLinkRecord`. The totals rise first, then the opponent's
## own row: an existing row for that ID and name is raised, and a new opponent
## takes the last of the five, which `.FindOpponentAndAppendRecord`'s sort has
## kept for the least successful one. Both counters stop at
## [constant MAX_LINK_RECORD] rather than wrapping.
##
## [param result] is `wins`, `losses` or `draws`, which is `wBattleResult`'s own
## WIN/LOSE/DRAW one name further on.
static func add_battle_to_record(
	record: Dictionary, opponent: Dictionary, result: StringName
) -> Dictionary:
	var updated: Dictionary = normalize_record(record)
	var key: String = String(result)
	updated[key] = _raise_count(int(updated.get(key, 0)))
	var rows: Array = updated["records"]
	var opponent_name: String = String(opponent.get("name", ""))
	var id: int = int(opponent.get("id", 0)) & 0xFFFF
	var found: int = -1
	for index: int in rows.size():
		var row: Dictionary = rows[index]
		if String(row.get("name", "")) == opponent_name and int(row.get("id", 0)) == id:
			found = index
			break
	if found < 0:
		found = rows.size() - 1
		rows[found] = {
			"name": opponent_name, "id": id, "wins": 0, "losses": 0, "draws": 0,
		}
	rows[found][key] = _raise_count(int((rows[found] as Dictionary).get(key, 0)))
	rows.sort_custom(_more_successful)
	updated["records"] = rows
	return updated


## `.loop4`, which is a bubble sort of the five rows on the three counters in
## the order they are stored.
static func _more_successful(a: Dictionary, b: Dictionary) -> bool:
	for key: String in ["wins", "losses", "draws"]:
		if int(a.get(key, 0)) != int(b.get(key, 0)):
			return int(a.get(key, 0)) > int(b.get(key, 0))
	return false


## `.CheckOverflow`, which stops a counter at the cap instead of carrying past
## it.
static func _raise_count(value: int) -> int:
	return mini(value + 1, MAX_LINK_RECORD)


## `sLinkBattleStats` as this project keeps it, with the five rows always
## present: an empty row is one `_DisplayLinkRecord` prints its dashes for.
static func normalize_record(raw: Variant) -> Dictionary:
	var source: Dictionary = raw if raw is Dictionary else {}
	var rows: Array = []
	for entry: Variant in source.get("records", []):
		if not entry is Dictionary or rows.size() >= NUM_LINK_BATTLE_RECORDS:
			continue
		var row: Dictionary = entry
		rows.append({
			"name": String(row.get("name", "")),
			"id": int(row.get("id", 0)) & 0xFFFF,
			"wins": clampi(int(row.get("wins", 0)), 0, MAX_LINK_RECORD),
			"losses": clampi(int(row.get("losses", 0)), 0, MAX_LINK_RECORD),
			"draws": clampi(int(row.get("draws", 0)), 0, MAX_LINK_RECORD),
		})
	while rows.size() < NUM_LINK_BATTLE_RECORDS:
		rows.append({"name": "", "id": 0, "wins": 0, "losses": 0, "draws": 0})
	return {
		"wins": clampi(int(source.get("wins", 0)), 0, MAX_LINK_RECORD),
		"losses": clampi(int(source.get("losses", 0)), 0, MAX_LINK_RECORD),
		"draws": clampi(int(source.get("draws", 0)), 0, MAX_LINK_RECORD),
		"records": rows,
	}
