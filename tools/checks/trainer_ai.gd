extends RefCounted

var _r: RefCounted = null

## Sweeps the trainer AI over every trainer in all three cartridges: what
## `AI_Basic`, `AI_Types`, `AI_Status` and `AI_Aggressive` do to a real moveset,
## and what `FindEnemyMonsWithAtLeastQuarterMaxHP` makes of a real HP bar. Those
## four layers roll no dice, so every claim below is an equality rather than a
## distribution.
##   Godot --headless --path . -s res://tools/validate.gd -- trainer_ai

## The three opponents every party member is scored against, by species. Each
## one is here for a typing: Gastly is what a Normal or Fighting move cannot
## touch and what `.poisonimmunity` reads, Magnemite is what a Poison move
## cannot touch through the chart, and Diglett is what an Electric move cannot.
const OPPONENTS: Array[int] = [92, 81, 50]
const OPPONENT_LEVEL: int = 50

## `AIDiscourageMove`'s ten on top of the starting twenty.
const DISMISSED: int = Gen2BattleAI.DEFAULT_SCORE + Gen2BattleAI.DISCOURAGE_MOVE


func run(r: RefCounted) -> void:
	_r = r
	for game_id: StringName in _r.GAME_IDS:
		var data: GameData = GameData.open(game_id)
		if data == null:
			_r.fail("%s cache is unavailable. Import roms/%s.gbc first." % [game_id, game_id])
			continue
		_r.game_id = game_id
		_sweep(game_id, data)
	_r.game_id = &""


func _sweep(game_id: StringName, data: GameData) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var opponents: Array = []
	for species: int in OPPONENTS:
		var mon: Gen2BattleMon = Gen2BattleMon.create(
			data, species, OPPONENT_LEVEL, data.moves_at_level(species, OPPONENT_LEVEL),
			Gen2BattleMon.PERFECT_DVS, {}, 0
		)
		if mon == null:
			_r.fail("%s: species %d could not be built." % [game_id, species])
			return
		opponents.append(mon)

	var scored: int = 0
	var bars: int = 0
	for trainer_class: int in range(1, data.trainer_count() + 1):
		for index: int in data.trainer_party_count(trainer_class):
			var party: Gen2Party = Gen2TrainerParty.build(data, trainer_class, index)
			if party == null:
				continue
			for slot: int in party.size():
				var member: Gen2BattleMon = party.at(slot)
				if member == null:
					continue
				bars += _check_quarter_rule(game_id, member)
				for opponent: Gen2BattleMon in opponents:
					_check_layers(game_id, data, member, opponent, rng)
					scored += 1
	print("  %s: %d scorings, %d HP bars." % [game_id, scored, bars])


func _check_layers(
	game_id: StringName, data: GameData, attacker: Gen2BattleMon,
	defender: Gen2BattleMon, rng: RandomNumberGenerator
) -> void:
	var types: Array = _layer(data, attacker, defender, rng, RomLayout.AI_TYPES)
	var status: Array = _layer(data, attacker, defender, rng, RomLayout.AI_STATUS)
	var safeguarded: Array = Gen2BattleAI.score_slots(
		attacker, defender, data, RomLayout.AI_BASIC, rng, 0, 0, Gen2Weather.NONE,
		Gen2Screens.NONE, Gen2Screens.SAFEGUARD
	)
	_check_aggressive(game_id, data, attacker, defender, rng)

	for slot: int in Gen2BattleMon.MAX_MOVES:
		if slot >= attacker.moves.size() or int(attacker.moves[slot]) == 0:
			break
		var move: Dictionary = data.move(int(attacker.moves[slot]))
		var effect: int = int(move.get("effect", 0))
		var power: int = int(move.get("power", 0))
		var immune: bool = data.type_effectiveness(
			int(move.get("type", RomLayout.TYPE_NORMAL)), defender.types()
		) == RomLayout.MATCHUP_NO_EFFECT

		if immune:
			_r.check(
				int(types[slot]) >= DISMISSED,
				"%s: AI_Types did not dismiss an immune %s." % [game_id, move.get("name", "?")]
			)

		var poisoning: bool = effect == Gen2MoveEffect.TOXIC or effect == Gen2MoveEffect.POISON
		var poison_shortcut: bool = poisoning and defender.types().has(RomLayout.TYPE_POISON)
		# `.poisonimmunity` falls into `.typeimmunity`, so a Poison move against
		# anything else is still read by the chart.
		var read_by_status: bool = poisoning or power > 0 \
			or effect == Gen2MoveEffect.SLEEP or effect == Gen2MoveEffect.PARALYZE
		var wanted: int = Gen2BattleAI.DEFAULT_SCORE
		if poison_shortcut or (read_by_status and immune):
			wanted = DISMISSED
		_r.check(
			int(status[slot]) == wanted,
			"%s: AI_Status put %s at %d, expected %d." % [
				game_id, move.get("name", "?"), status[slot], wanted
			]
		)

		if Gen2BattleAI.STATUS_ONLY_EFFECTS.has(effect):
			_r.check(
				int(safeguarded[slot]) >= DISMISSED,
				"%s: AI_Basic ignored Safeguard for %s." % [game_id, move.get("name", "?")]
			)


## `AI_Aggressive` picks one winner and punishes the rest, and it does so even
## when every one of them lands for nothing: `c` is already set by the first
## damaging move, whatever the damage came to. So a moveset with any damaging
## move at all leaves exactly one ordinary slot alone.
func _check_aggressive(
	game_id: StringName, data: GameData, attacker: Gen2BattleMon,
	defender: Gen2BattleMon, rng: RandomNumberGenerator
) -> void:
	var scores: Array = _layer(data, attacker, defender, rng, RomLayout.AI_AGGRESSIVE)
	var ordinary: int = 0
	var untouched: int = 0
	var damaging: bool = false
	for slot: int in Gen2BattleMon.MAX_MOVES:
		if slot >= attacker.moves.size() or int(attacker.moves[slot]) == 0:
			break
		var move: Dictionary = data.move(int(attacker.moves[slot]))
		damaging = damaging or int(move.get("power", 0)) > 0
		if int(move.get("power", 0)) < 2:
			continue
		if Gen2BattleAI.RECKLESS_EFFECTS.has(int(move.get("effect", 0))):
			continue
		ordinary += 1
		if int(scores[slot]) == Gen2BattleAI.DEFAULT_SCORE:
			untouched += 1

	if not damaging or ordinary == 0:
		return
	_r.check(
		untouched <= 1,
		"%s: AI_Aggressive left %d of %d ordinary moves alone." % [
			game_id, untouched, ordinary
		]
	)


func _layer(
	data: GameData, attacker: Gen2BattleMon, defender: Gen2BattleMon,
	rng: RandomNumberGenerator, layer: int
) -> Array:
	return Gen2BattleAI.score_slots(attacker, defender, data, layer, rng)


## `FindEnemyMonsWithAtLeastQuarterMaxHP` over one real HP bar: below a maximum
## of 256 its shifted word clears the maximum exactly when the current HP is not
## a multiple of four, which is the whole of what the scan comes to. Answers 1 so
## the caller can count the bars it walked.
func _check_quarter_rule(game_id: StringName, member: Gen2BattleMon) -> int:
	var maximum: int = member.max_hp()
	if maximum >= 256:
		return 0
	for hp: int in range(1, maximum + 1):
		var wanted: bool = (hp % 4) != 0
		if (Gen2AISwitch._shifted_hp(hp) > maximum) != wanted:
			_r.fail("%s: %d of %d HP disagrees with the shift." % [game_id, hp, maximum])
			return 1
	return 1
