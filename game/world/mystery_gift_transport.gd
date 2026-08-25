class_name Gen2MysteryGiftTransport
extends RefCounted

## The infrared window, as the only thing above it needs it to be.
##
## `ExchangeMysteryGiftData` reaches the other Game Boy through rRP rather than
## through the cable, and what it does with it comes down to three things:
## whether a partner is in the window at all, which of the two ends is the
## sender, and one twenty-byte block swapped both ways. There is no infrared
## port on a modern platform, so this project chooses the transport, and this
## class is that choice.
##
## Scene free and injected, the way [Gen2LinkTransport] is. A window with
## nobody in it is the honest default and a real game path rather than a stub:
## the exchange times out, `hMGStatusFlags` comes back `MG_TIMED_OUT` and
## `DoMysteryGift` prints its own communication-error box.
##
## The one partner that exists today is another of this player's own save
## slots, which [method peer_from_save] builds. A network transport subclasses
## this and overrides [method peer_block]; nothing above changes.

## `hMGRole`. The side that holds the window open first is the receiver, which
## is what `InitializeIRCommunicationRoles` settles between two real Game Boys.
const IR_RECEIVER: int = 1
const IR_SENDER: int = 2

## The partner's own side of the window, or empty for nobody in it. The keys
## are `StageDataForMysteryGift`'s own twenty bytes plus the slot it came from.
var peer: Dictionary = {}

## `hMGRole`. Whoever opened this screen is the one waiting, so they receive
## first and send back, which is `ReceiverExchangeMysteryGiftDataPayloads`.
var role: int = IR_RECEIVER


## Whether anybody is in the window at all. Everything else asks this first.
func connected() -> bool:
	return not peer.is_empty()


## `ExchangeMysteryGiftData`'s own return in `hMGStatusFlags`. A window with
## nobody in it spends its four seconds and comes back timed out, which
## `DoMysteryGift` reads as its communication error and loops back to the
## prompt.
func status() -> int:
	return Gen2MysteryGift.MG_OKAY if connected() else Gen2MysteryGift.MG_TIMED_OUT


## `SendMysteryGiftDataPayload` and `ReceiveMysteryGiftDataPayload` as the one
## operation they are together: this side's staged block goes out and the
## partner's comes back. Empty means the window closed, which every caller
## treats the same way as nobody being in it.
func exchange(payload: Dictionary) -> Dictionary:
	if not connected():
		return {}
	return peer_block(payload)


## The partner's own block. The base transport answers out of [member peer],
## which is a save slot that is not being played, so its roll was made when the
## window opened and it does not change while this side thinks about it.
func peer_block(_payload: Dictionary) -> Dictionary:
	return peer.duplicate(true)


## A partner built from a save slot: the player's other file, which is the only
## second Mystery Gift block that exists on one machine.
##
## [param dex_caught] and [param random] are what `StageDataForMysteryGift`
## reads and rolls on that side, so the roll is the slot's rather than this
## one's.
static func peer_from_save(
	save: Gen2SaveData, dex_caught: int, random: RandomNumberGenerator
) -> Dictionary:
	if save == null:
		return {}
	var section: Dictionary = Gen2MysteryGift.normalize(save.mystery_gift)
	var block: Dictionary = Gen2MysteryGift.stage_player_data(
		save, section, dex_caught, random
	)
	block["slot"] = save.slot
	return block


## The transport a save slot makes, or one with nobody in the window when there
## is no other slot to hold one open.
static func to_save(
	save: Gen2SaveData, dex_caught: int, random: RandomNumberGenerator
) -> Gen2MysteryGiftTransport:
	var transport := Gen2MysteryGiftTransport.new()
	transport.peer = peer_from_save(save, dex_caught, random)
	return transport
