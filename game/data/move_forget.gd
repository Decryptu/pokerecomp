class_name Gen2MoveForget
extends RefCounted

## engine/pokemon/learn.asm's `LearnMove` and `ForgetMove`, reached from
## `TeachTMHM` and from a level-up alike: `AskForgetMoveText`'s yes/no, then
## `MoveAskForgetText` and the list, where an HM row prints
## `MoveCantForgetHMText` and loops. B or a no reaches `LearnMove.cancel`.

## How many moves a Pokémon can know at once, NUM_MOVES.
const MOVE_SLOTS: int = 4

## `Text_1_2_and_Poof`'s own `PlaySFX`; `OneTwoAndText` plays SFX_SWAP by `PlaySound` id.
const SFX_SWITCH_POKEMON: int = 0x20
const GEN1_SFX_SWAP: int = 174

## home/hm_moves.asm's `IsHMMove.HMMoves`, in source order: forgetting is gated
## on every HM, not on the four the overworld acts on. `data/moves/hm_moves.asm`
## is the first five, Generation 1's WATERFALL being an ordinary move.
const HM_MOVES: Array[int] = [
	0x0F,  # CUT
	0x13,  # FLY
	0x39,  # SURF
	0x46,  # STRENGTH
	0x94,  # FLASH
	0x7F,  # WATERFALL
	0xFA,  # WHIRLPOOL
]
const GEN1_HM_MOVE_COUNT: int = 5

## `data/text/common_3.asm` and `data/text/text_4.asm` with their own breaks:
## a digit, a question and every full stop differ.
const TEXTS: Dictionary = {
	&"ask": "%s is\ntrying to learn\ue001%s.\ue000But %s\ncan't learn more\ue001than four moves.\ue000Delete an older\nmove to make room\ue001for %s?",
	&"which": "Which move should\nbe forgotten?",
	&"stop": "Stop learning\n%s?",
	&"did_not_learn": "%s\ndid not learn\ue001%s.",
	&"forgot": "1, 2 and… Poof!\ue000%s forgot\n%s.\ue000And…",
	&"learned": "%s learned\n%s!",
	&"cant_forget_hm": "HM moves can't be\nforgotten now.",
}
const GEN1_TEXTS: Dictionary = {
	&"ask": "%s is\ntrying to learn\ue001%s!\ue000But, %s\ncan't learn more\ue001than 4 moves!\ue000Delete an older\nmove to make room\ue001for %s?",
	&"which": "Which move should\nbe forgotten?",
	&"stop": "Abandon learning\n%s?",
	&"did_not_learn": "%s\ndid not learn\ue001%s!",
	&"forgot": "1, 2 and... Poof!\ue000%s forgot\n%s!\ue000And...",
	&"learned": "%s learned\n%s!",
	&"cant_forget_hm": "HM techniques\ncan't be deleted!",
}


## `IsHMMove`: an HM's move, which `ForgetMove` refuses to give up.
static func is_hm_move(move: int, generation: int = RomRegistry.GEN2) -> bool:
	var index: int = HM_MOVES.find(move)
	return index >= 0 and (generation != RomRegistry.GEN1 or index < GEN1_HM_MOVE_COUNT)


## `ListMoves`' rows: it stops at the first zero, so a padded slot is not listed.
## `forgettable` is the `IsHMMove` test the menu makes on confirm, resolved up
## front so a screen can mark the row rather than only refuse it.
static func options(data: GameData, moves: Array) -> Array:
	var out: Array = []
	if data == null:
		return out
	for slot: int in mini(moves.size(), MOVE_SLOTS):
		var move: int = int(moves[slot])
		if move == 0:
			break
		out.append({
			"slot": slot,
			"move": move,
			"name": String(data.move(move).get("name", "MOVE")),
			"forgettable": not is_hm_move(move, data.generation),
		})
	return out


static func _text(key: StringName, generation: int) -> String:
	return String((GEN1_TEXTS if generation == RomRegistry.GEN1 else TEXTS)[key])


## `AskForgetMoveText` and `TryingToLearnText`.
static func ask_text(mon_name: String, move_name: String, generation: int = RomRegistry.GEN2) -> String:
	return _text(&"ask", generation) % [mon_name, move_name, mon_name, move_name]


## `MoveAskForgetText`, the heading over the move list.
static func which_text(generation: int = RomRegistry.GEN2) -> String:
	return _text(&"which", generation)


## `StopLearningMoveText` and `AbandonLearningText`, `LearnMove.cancel`'s own yes/no.
static func stop_text(move_name: String, generation: int = RomRegistry.GEN2) -> String:
	return _text(&"stop", generation) % move_name


## `DidNotLearnMoveText`, the end of a cancelled offer.
static func did_not_learn_text(
	mon_name: String, move_name: String, generation: int = RomRegistry.GEN2
) -> String:
	return _text(&"did_not_learn", generation) % [mon_name, move_name]


## `Text_1_2_and_Poof` then `_MoveForgotText`; `OneTwoAndText` through `ForgotAndText`.
static func forgot_text(
	mon_name: String, old_move_name: String, generation: int = RomRegistry.GEN2
) -> String:
	return _text(&"forgot", generation) % [mon_name, old_move_name]


## `LearnedMoveText` and `LearnedMove1Text`.
static func learned_text(
	mon_name: String, move_name: String, generation: int = RomRegistry.GEN2
) -> String:
	return _text(&"learned", generation) % [mon_name, move_name]


## `MoveCantForgetHMText` and `HMCantDeleteText`; `.hmmove` is `jr .loop`.
static func cant_forget_hm_text(generation: int = RomRegistry.GEN2) -> String:
	return _text(&"cant_forget_hm", generation)
