class_name Gen2LinkTransport
extends RefCounted

## The cable, as the only thing above it needs it to be. `home/serial.asm` reaches
## the other Game Boy through exactly three operations and every routine the cable
## club runs is built from them: read `hSerialConnectionStatus`, exchange one byte,
## and exchange a block. There is no cable on a modern platform, so this class is
## the three operations and nothing about wires, timing or bit order. Scene free
## and injected: a transport with no peer is the honest default and a real game
## path, since `WaitForLinkedFriend` times out. The one peer today is another of
## this player's slots; a network transport overrides the three operations.

## constants/serial_constants.asm. `CONNECTION_NOT_ESTABLISHED` is what
## `Link_ResetSerialRegistersAfterLinkClosure` writes back.
const CONNECTION_NOT_ESTABLISHED: int = 0xFF
const USING_EXTERNAL_CLOCK: int = 0x01
const USING_INTERNAL_CLOCK: int = 0x02

## `wLinkMode`.
const LINK_NULL: int = 0
const LINK_TIMECAPSULE: int = 1
const LINK_TRADECENTER: int = 2
const LINK_COLOSSEUM: int = 3
const LINK_MOBILE: int = 4

## `wChosenCableClubRoom` and `wPlayerLinkAction` at the receptionist.
const CABLECLUBROOM_NULL: int = 0
const CABLECLUBROOM_TRADECENTER: int = 1
const CABLECLUBROOM_COLOSSEUM: int = 2

## The peer's own side of the link, or empty for no cable. Keys:
## `name`, `id`, `gender`, `party` (an array of [Gen2SaveMon] dictionaries),
## `room` (its `wChosenCableClubRoom`) and `generation`.
var peer: Dictionary = {}

## Which side of the cable this player is. `CableClubCheckWhichChris` and the
## trade animation both branch on it, and `WaitForLinkedFriend` only reports a
## connection once it is one of the two clocks.
var clock: int = CONNECTION_NOT_ESTABLISHED


## Which generation the peer's game is. `readmem wOtherPlayerLinkMode` after
## `CheckLinkTimeout_Receptionist` is zero for a Game Boy running a Gen 1 game
## and non-zero for a Gen 2 one, which is the whole of the "can't link to the
## past" test and the whole of what makes the Time Capsule legal.
const GENERATION_1: int = 1
const GENERATION_2: int = 2


## Whether a peer is on the other end at all. Everything else asks this first.
func connected() -> bool:
	return not peer.is_empty()


## `hSerialConnectionStatus`. The peer this project can build is another save
## slot on this machine, and the player who opened the receptionist is the one
## holding the cable's internal clock, so they are player 1.
func status() -> int:
	if not connected():
		return CONNECTION_NOT_ESTABLISHED
	if clock == CONNECTION_NOT_ESTABLISHED:
		clock = USING_INTERNAL_CLOCK
	return clock


## `Link_EnsureSync`, which sends one nybble and returns the peer's. The source
## spins until a byte with the `$d0` marker comes back; a transport with a peer
## already has the answer, and one without has none.
func exchange_nybble(value: int) -> int:
	if not connected():
		return -1
	return peer_nybble(value & 0xF)


## What the peer answers a sync nybble with. The base transport's peer is a save
## file rather than a player, so it agrees with whatever this side proposed:
## it entered the same room and it is ready. A network transport overrides this
## with the byte that actually came back.
func peer_nybble(value: int) -> int:
	return value


## `Serial_ExchangeBytes` at the block level: this side's payload goes out and
## the peer's comes back. Empty means the cable dropped, which every caller
## treats as a link that closed.
func exchange(payload: Dictionary) -> Dictionary:
	if not connected():
		return {}
	return peer_block(payload)


## The peer's own block. The base transport answers out of [member peer], which
## is a save slot that is not being played, so its party is whatever it was
## saved with.
func peer_block(_payload: Dictionary) -> Dictionary:
	return {
		"name": String(peer.get("name", "")),
		"id": int(peer.get("id", 0)),
		"gender": int(peer.get("gender", 0)),
		"generation": int(peer.get("generation", GENERATION_2)),
		"room": int(peer.get("room", CABLECLUBROOM_NULL)),
		"party": (peer.get("party", []) as Array).duplicate(true),
	}


## `Link_ResetSerialRegistersAfterLinkClosure`. A closed link forgets which side
## it was; the peer stays, because the player can walk back to the receptionist.
func close() -> void:
	clock = CONNECTION_NOT_ESTABLISHED


## Which room the peer walked up to. A save slot cannot choose, so it agrees:
## the two players who sat down together picked the same door, and the one case
## that must still fail is a Gen 2 peer at the Time Capsule, which
## [Gen2LinkSession] settles from `generation` rather than from here.
func peer_room(chosen_room: int) -> int:
	return int(peer.get("room", chosen_room))


## Which row of its own party the peer offers in a trade. A save file has nobody
## behind it to choose, so the base transport answers with the row the player
## left the partner's list on, which is the list `LinkTrade_OTPartyMenu` already
## lets them move a cursor through; a network transport answers with the row
## that actually came back in `wOtherPlayerLinkMode`.
##
## [param context] carries `ot_cursor` and `ot_count`.
func choose_trade_slot(context: Dictionary) -> int:
	var rows: int = int(context.get("ot_count", 0))
	if rows <= 0:
		return -1
	return clampi(int(context.get("ot_cursor", 0)), 0, rows - 1)


## A peer built from a save slot: the player's other file, which is the only
## second party that exists on one machine. [param room] is the door it is
## treated as having walked up to.
static func peer_from_save(save: Gen2SaveData, room: int = CABLECLUBROOM_NULL) -> Dictionary:
	if save == null:
		return {}
	var party: Array = []
	for mon: Gen2SaveMon in save.party:
		party.append(mon.to_dict())
	return {
		"name": save.player_name,
		"id": save.player_id,
		"gender": save.gender,
		"generation": GENERATION_2,
		"room": room,
		"party": party,
		"slot": save.slot,
	}


## The transport a save slot makes, or one with no cable when there is no other
## slot to link to.
static func to_save(save: Gen2SaveData, room: int = CABLECLUBROOM_NULL) -> Gen2LinkTransport:
	var transport := Gen2LinkTransport.new()
	transport.peer = peer_from_save(save, room)
	return transport
