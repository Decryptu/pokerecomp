class_name Gen2TrainerParty
extends RefCounted

## One of a trainer class's individual trainers as a battle-ready party. A
## NORMAL or ITEM trainer's Pokemon knows what its level teaches; MOVES and
## ITEM_MOVES know the stored moves. DVs are the per-class word. This is also
## where [constant Gen2Rules.CHALLENGE_HARD]'s rules land, one rule not 800 teams.


## The party a trainer class's [param index]th trainer brings, or null if
## [param data] has no such trainer or none of its Pokémon could be built.
##
## [param rules] defaults to the installed set, which is the run's; a caller
## holding a battle's own passes it rather than installing it.
## [param context] is `ReadTrainer`'s `lone_attack` and `rival_starter`.
static func build(
	data: GameData, trainer_class: int, index: int, rules: Gen2Rules = null,
	context: Dictionary = {}
) -> Gen2Party:
	if data == null:
		return null

	var trainer: Dictionary = data.trainer_party(trainer_class, index)
	if trainer.is_empty():
		return null

	var played: Gen2Rules = rules if rules != null else Gen2Rules.active()
	var mon_type: int = int(trainer["type"])
	var dvs: int = played.trainer_dvs(data.trainer_dvs(trainer_class))
	var trained: Dictionary = played.trainer_stat_exp()
	var members: Array = []
	for mon: Dictionary in (trainer["party"] as Array):
		var species: int = int(mon["species"])
		## The stored moves are the trainer's own whatever the level becomes; a
		## NORMAL or ITEM trainer fills its slots from the level it arrives at,
		## so a raised one knows what that level teaches.
		var level: int = played.trainer_level(int(mon["level"]))
		var moves: Array = _moves_for(data, mon_type, species, level, mon["moves"])
		members.append(
			Gen2BattleMon.create(data, species, level, moves, dvs, trained, int(mon["item"]))
		)
	apply_special_moves(data, members, trainer.get("special_moves", []), context)

	return Gen2Party.create(members)


## `ReadTrainer`'s tail: each row a move written over one member's slot after
## `AddPartyMon` filled it, gated on `wLoneAttackNo` or picked by
## `wRivalStarter`. No PP is written beside it and the enemy's is never spent,
## so an empty slot takes the move's own.
static func apply_special_moves(
	data: GameData, members: Array, rows: Array, context: Dictionary
) -> void:
	var lone: int = int(context.get("lone_attack", 0))
	for row: Dictionary in rows:
		if row.has("lone") and int(row["lone"]) != lone:
			continue
		var member: Gen2BattleMon = members[int(row["member"]) - 1] \
			if int(row["member"]) <= members.size() else null
		if member == null:
			continue
		var move: int = int(row.get("move", 0))
		if row.has("starter"):
			move = _starter_move(row["starter"], int(context.get("rival_starter", 0)))
		var slot: int = int(row["slot"]) - 1
		while member.moves.size() <= slot:
			member.moves.append(0)
			member.pp.append(0)
		member.moves[slot] = move
		if int(member.pp[slot]) == 0:
			member.pp[slot] = int(data.move(move).get("pp", 0))


## `.GiveStarterMove`: species 0 is the line every other value takes.
static func _starter_move(rows: Array, starter: int) -> int:
	var fallback: int = 0
	for row: Dictionary in rows:
		if int(row["species"]) == starter:
			return int(row["move"])
		if int(row["species"]) == 0:
			fallback = int(row["move"])
	return fallback


## What one of this trainer's Pokémon knows: its own stored moves if the
## trainer's type says it carries them, or the ordinary learnset fill
## otherwise. Zero is not a move; it is an empty slot in the stored list, and
## is dropped rather than passed to [Gen2BattleMon] as one.
static func _moves_for(
	data: GameData, mon_type: int, species: int, level: int, stored: Array
) -> Array:
	if mon_type == Gen2Layout.TRAINER_MON_MOVES or mon_type == Gen2Layout.TRAINER_MON_ITEM_MOVES:
		var out: Array = []
		for move: Variant in stored:
			if int(move) != 0:
				out.append(int(move))
		return out

	return data.moves_at_level(species, level)
