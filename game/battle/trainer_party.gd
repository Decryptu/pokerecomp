class_name Gen2TrainerParty
extends RefCounted

## Turns one of a trainer class's individual trainers into a battle-ready party.
## Lives here rather than beside [Gen2Learnset] because it produces
## [Gen2BattleMon]s and the data layer holds no battle types.
##
## A NORMAL or ITEM trainer's Pokemon knows what its level teaches; a MOVES or
## ITEM_MOVES trainer's knows exactly the moves stored with it. DVs are the
## per-class word rather than [constant Gen2BattleMon.PERFECT_DVS]. This is also
## where [constant Gen2Rules.CHALLENGE_HARD]'s rules land, one rule not 800 teams.


## The party a trainer class's [param index]th trainer brings, or null if
## [param data] has no such trainer or none of its Pokémon could be built.
##
## [param rules] defaults to the installed set, which is the run's; a caller
## holding a battle's own passes it rather than installing it.
static func build(
	data: GameData, trainer_class: int, index: int, rules: Gen2Rules = null
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

	return Gen2Party.create(members)


## What one of this trainer's Pokémon knows: its own stored moves if the
## trainer's type says it carries them, or the ordinary learnset fill
## otherwise. Zero is not a move; it is an empty slot in the stored list, and
## is dropped rather than passed to [Gen2BattleMon] as one.
static func _moves_for(
	data: GameData, mon_type: int, species: int, level: int, stored: Array
) -> Array:
	if mon_type == RomLayout.TRAINER_MON_MOVES or mon_type == RomLayout.TRAINER_MON_ITEM_MOVES:
		var out: Array = []
		for move: Variant in stored:
			if int(move) != 0:
				out.append(int(move))
		return out

	return data.moves_at_level(species, level)
