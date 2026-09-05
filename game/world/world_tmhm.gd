class_name Gen2WorldTMHM
extends RefCounted

## Scene-free tables and gates for teaching a TM or HM (engine/items/tmhm.asm).
## The TM/HM pocket does not reach `UseItem`'s jumptable at all: its own USE entry
## runs AskTeachTMHM, then ChooseMonToLearnTMHM, then TeachTMHM. This class owns
## the first and the checks the third makes;
## [method Gen2WorldPartyHost.teach_tm_hm] owns the transaction. Everything here is
## byte identical between the pins, pokegold's TeachTMHM differing by one line, a
## stubbed trainer-ranking call that does nothing.

## constants/item_constants.asm. The run from TM01 to HM07 is not contiguous:
## ITEM_C3 and ITEM_DC sit inside it as dummies, which is why the number a TM
## carries comes from Gen2Layout.tmhm_number_for_item() rather than subtraction.
const ITEM_TM01: int = Gen2Layout.ITEM_TM01
const ITEM_HM01: int = Gen2Layout.ITEM_HM01
## `cp TM01` needs no ceiling on hardware because an item number is a byte. A
## defined item is not one: Gen2ContentOverlay.FIRST_MOD_NUMBER is 256, so
## without this every mod item read as a TM, and as an HM.
const ITEM_BYTE_MAX: int = Gen2Layout.ITEM_BYTE_MAX

## Eight bytes of learnable flags on each species, one bit per TMNUM, indexed by
## the entry's own zero-based place in TMHMMoves.
const TMHM_FLAG_BYTES: int = Gen2Layout.TMHM_BYTES


## AskTeachTMHM's first test, `cp TM01` before anything else: an item below TM01
## is not a TM or HM and the prompt never appears. Generation 1 numbers the two
## runs the other way up, five HMs at $C4 with the fifty TMs above them, so the
## comparison is its own.
static func is_tm_hm(item: int, generation: int = RomRegistry.GEN2) -> bool:
	if generation == RomRegistry.GEN1:
		return Gen1Layout.machine_number(item) > 0
	return item >= ITEM_TM01 and item <= ITEM_BYTE_MAX


## IsHM, which TeachTMHM asks before ConsumeTM: an HM is never used up.
static func is_hm(item: int, generation: int = RomRegistry.GEN2) -> bool:
	if generation == RomRegistry.GEN1:
		return Gen1Layout.is_hm_item(item)
	return item >= ITEM_HM01 and item <= ITEM_BYTE_MAX


## GetTMHMNumber: the one-based `TMHMMoves` row [param item] names, or 0. The one
## place either generation's numbering is turned into a row.
static func number_for_item(data: GameData, item: int) -> int:
	if data == null:
		return 0
	if data.generation == RomRegistry.GEN1:
		return Gen1Layout.machine_number(item)
	return Gen2Layout.tmhm_number_for_item(item, data.tmhm_moves().size())


## GetTMHMItemMove: the move [param item] teaches, or 0 when it is not a TM/HM
## this cartridge carries.
static func move_for_item(data: GameData, item: int) -> int:
	return data.tmhm_move(number_for_item(data, item)) if data != null else 0


## CanLearnTMHMMove: the species' own flag bit for the TM/HM that teaches
## [param move]. A move no TM/HM teaches answers false, matching the source's
## `.end` branch, which returns c = 0 after walking off the end of TMHMMoves.
static func can_learn(data: GameData, species: int, move: int) -> bool:
	if data == null:
		return false
	var number: int = data.tmhm_number_for_move(move)
	if number < 1:
		return false
	var flags: Array = data.species(species).get("tmhm", [])
	if flags.size() < TMHM_FLAG_BYTES:
		return false
	# SmallFarFlagAction with d = 0: byte index >> 3, then bit index & 7 counted
	# from the *low* bit, since it shifts 1 left that many times.
	var index: int = number - 1
	var byte: int = int(flags[index >> 3])
	return (byte & (1 << (index & 7))) != 0


## KnowsMove (engine/pokemon/knows_move.asm), which TeachTMHM asks after
## compatibility and before LearnMove: all four slots, zeros included, though a
## zero can never match a real move.
static func knows_move(moves: Array, move: int) -> bool:
	return moves.has(move)


## LearnMove's own first step: the first empty move slot, or -1 when all four are
## taken and the source would open ForgetMove instead.
static func first_empty_slot(moves: Array) -> int:
	for slot: int in moves.size():
		if int(moves[slot]) == 0:
			return slot
	return -1


## AskTeachTMHM's two texts, BootedTMText/BootedHMText then ContainedMoveText,
## as the one prompt this project shows before its yes/no. The source prints them
## as two boxes; the wording is verbatim.
static func teach_prompt(data: GameData, item: int) -> Dictionary:
	var move: int = move_for_item(data, item)
	if move <= 0:
		return {"ok": false, "reason": &"not_a_tm_hm", "item": item}
	var move_name: String = String(data.move(move).get("name", "MOVE"))
	var hm: bool = is_hm(item, data.generation)
	var booted: String = "Booted up an HM." if hm else "Booted up a TM."
	return {
		"ok": true,
		"item": item,
		"move": move,
		"move_name": move_name,
		"hm": hm,
		"text": "%s It contained %s. Teach %s to a #MON?" % [booted, move_name, move_name],
	}


## `_TMHMNotCompatibleText` (data/text/common_2.asm), which `TeachTMHM` and
## `CheckCanLearnMoveTutorMove` both print when `CanLearnTMHMMove` says no.
static func not_compatible_text(mon_name: String, move_name: String) -> String:
	return "%s is not compatible with %s. It can't learn %s." % [
		move_name, mon_name, move_name,
	]


## `_KnowsMoveText` (data/text/common_3.asm), printed by `KnowsMove` itself, so
## every caller that reaches it shows this line and no other.
static func knows_move_text(mon_name: String, move_name: String) -> String:
	return "%s knows %s." % [mon_name, move_name]
