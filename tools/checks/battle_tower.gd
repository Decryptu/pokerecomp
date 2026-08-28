extends RefCounted

var _r: RefCounted = null

## Verifies the Battle Tower against freshly imported real caches, on all three
## games. Expected values come from the pinned pokecrystal source: the 70 class
## rows, the ten level groups, the two per-class tables and the menu strings. The
## pins are counted off the asm rather than read from [Gen2BattleTower]'s own
## tables, so a mistranscribed row is a failure instead of an agreement. Gold and
## Silver ship no tower at all, which is checked as an absence rather than as an
## empty table: a cache that claims otherwise is a wrong pin.

## `BattleTowerTrainers`' four corners: the run's own ends and the two rows
## either side of `assert_table_length BATTLETOWER_NUM_UNIQUE_MON`, which is
## where Crystal 1.0's sampler stops.
## The `; nn` comments in constants/trainer_constants.asm are hexadecimal:
## FISHER is $25, CAMPER $36, GENTLEMAN $20 and FIREBREATHER $30.
const EXPECTED_TRAINERS: Dictionary = {
	0: ["HANSON", 0x25], 20: ["McMAHILL", 0x36], 21: ["OBRIEN", 0x20], 69: ["WONG", 0x30],
}

## `BattleTowerMons`' first row of each level group: species, held item and the
## four moves, counted off data/battle_tower/parties.asm.
const EXPECTED_FIRST_MONS: Array = [
	# JOLTEON/MIRACLEBERRY: THUNDERBOLT, HYPER_BEAM, SHADOW_BALL, ROAR
	[135, 109, [85, 63, 247, 46]],
	# UMBREON/LEFTOVERS: PROTECT, TOXIC, MUD_SLAP, ATTRACT
	[197, 146, [182, 92, 189, 213]],
	# JOLTEON/MIRACLEBERRY: THUNDERBOLT, THUNDER_WAVE, ROAR, MUD_SLAP
	[135, 109, [85, 86, 46, 189]],
	# TAUROS/GOLD_BERRY: RETURN, HYPER_BEAM, EARTHQUAKE, IRON_TAIL
	[128, 174, [216, 63, 89, 231]],
	# KINGDRA/GOLD_BERRY: SURF, HYPER_BEAM, BLIZZARD, DRAGONBREATH
	[230, 174, [57, 63, 59, 225]],
	# KINGDRA/LEFTOVERS: DRAGONBREATH, SURF, HYPER_BEAM, BLIZZARD
	[230, 146, [225, 57, 63, 59]],
	# JOLTEON/MIRACLEBERRY: THUNDERBOLT, HYPER_BEAM, SHADOW_BALL, ROAR
	[135, 109, [85, 63, 247, 46]],
	# JOLTEON/MIRACLEBERRY: THUNDER_WAVE, THUNDERBOLT, IRON_TAIL, ROAR
	[135, 109, [86, 85, 231, 46]],
	# UMBREON/KINGS_ROCK: FAINT_ATTACK, MUD_SLAP, MOONLIGHT, CONFUSE_RAY
	[197, 82, [185, 189, 236, 109]],
	# HOUNDOOM/MINT_BERRY: CRUNCH, FLAMETHROWER, ROAR, REST
	[229, 84, [242, 53, 46, 156]],
]

## `Strings_L10ToL100` and `MenuData_ChallengeExplanationCancel`, decoded.
## `Strings_L10ToL100`, with the padding each eight-byte row carries: the level
## rows open with a space and CANCEL does not, which is the column each stands
## in when `BattleTowerRoomMenu_UpdatePickLevelMenu` places it at `hlcoord 13,
## 9`.
const EXPECTED_LEVEL_ROWS: Array[String] = [
	" L:10 ", " L:20 ", " L:30 ", " L:40 ", " L:50 ", " L:60 ", " L:70 ",
	" L:80 ", " L:90 ", " L:100", "CANCEL",
]
const EXPECTED_MENU_ROWS: Array[String] = ["Challenge", "Explanation", "Cancel"]

## `BATTLE_TOWER_BATTLE_ROOM`, its warp-in cell, and how many script steps the
## room's scene is driven for before the first fight has to be up.
const BATTLE_ROOM_GROUP: int = 22
const BATTLE_ROOM_MAP: int = 12
const BATTLE_ROOM_CELL: Vector2i = Vector2i(3, 7)
const BATTLE_ROOM_FRAME_CAP: int = 512

## `BTTrainerClassGenders`' own ends: FALKNER is MALE and GRUNTF is FEMALE.
const EXPECTED_GENDERS: Dictionary = {0: 0, 65: 1}
## `BTTrainerClassSprites`' own ends: SPRITE_FALKNER ($12) and SPRITE_ROCKET_GIRL
## ($36), the constants file's comments being hexadecimal here as well.
const EXPECTED_SPRITES: Dictionary = {0: 0x12, 65: 0x36}


func run(r: RefCounted) -> void:
	_r = r
	_r.each_game(func() -> void:
		if _r.data.id != &"crystal":
			_r.check(
				not _r.data.has_battle_tower(),
				"%s has a Battle Tower block, which its cartridge ships nothing for" % _r.data.id
			)
			return
		_verify_trainers()
		_verify_mons()
		_verify_strings()
		_verify_class_tables()
		_verify_sampler()
		_verify_rules()
		_verify_battle_room()
	)


func _verify_trainers() -> void:
	var rows: Array = _r.data.battle_tower().get("trainers", []) as Array
	if not _r.check(
		rows.size() == Gen2BattleTower.NUM_UNIQUE_TRAINERS,
		"BattleTowerTrainers has %d rows, not %d." % [
			rows.size(), Gen2BattleTower.NUM_UNIQUE_TRAINERS,
		]
	):
		return
	for index: Variant in EXPECTED_TRAINERS:
		var row: Dictionary = rows[int(index)] as Dictionary
		var expected: Array = EXPECTED_TRAINERS[index] as Array
		_r.check(
			String(row.get("name", "")) == String(expected[0]),
			"BattleTowerTrainers row %d is \"%s\", not \"%s\"." % [
				index, row.get("name", ""), expected[0],
			]
		)
		_r.check(
			int(row.get("class", 0)) == int(expected[1]),
			"BattleTowerTrainers row %d is class %d, not %d." % [
				index, int(row.get("class", 0)), int(expected[1]),
			]
		)


## Every one of the 210 rows, on its own group's level, with a species and four
## move slots the cache can name: a group read at the wrong stride lands on the
## previous group's levels long before it lands outside the table.
func _verify_mons() -> void:
	for group: int in Gen2BattleTower.LEVEL_GROUPS:
		var level: int = (group + 1) * 10
		for index: int in Gen2BattleTower.NUM_UNIQUE_MON:
			var bytes: PackedByteArray = _r.data.battle_tower_mon(group, index)
			if not _r.check(
				bytes.size() == RomLayout.BATTLETOWER_MON_BYTES,
				"BattleTowerMons %d/%d is %d bytes." % [group, index, bytes.size()]
			):
				return
			var mon: Gen2SaveMon = Gen2SramAdapter.read_party_mon(bytes, 0)
			_r.check(
				mon != null and mon.level == level,
				"BattleTowerMons %d/%d is level %d, not %d." % [
					group, index, mon.level if mon != null else -1, level,
				]
			)
			_r.check(
				mon != null and not _r.data.species(mon.species).is_empty(),
				"BattleTowerMons %d/%d names species %d." % [
					group, index, mon.species if mon != null else -1,
				]
			)
			for move: int in mon.moves:
				_r.check(
					move == 0 or not _r.data.move(move).is_empty(),
					"BattleTowerMons %d/%d knows move %d." % [group, index, move]
				)
		var first: Array = EXPECTED_FIRST_MONS[group] as Array
		var head: Gen2SaveMon = Gen2SramAdapter.read_party_mon(
			_r.data.battle_tower_mon(group, 0), 0
		)
		_r.check(
			head != null and head.species == int(first[0]) and head.item == int(first[1])
			and head.moves == (first[2] as Array),
			"BattleTowerMons group %d opens on %s, not %s." % [
				group,
				[head.species, head.item, head.moves] if head != null else [],
				first,
			]
		)


func _verify_strings() -> void:
	_r.check(
		Array(_r.data.battle_tower().get("level_rows", [])) == Array(EXPECTED_LEVEL_ROWS),
		"Strings_L10ToL100 reads %s." % [_r.data.battle_tower().get("level_rows", [])]
	)
	_r.check(
		Array(_r.data.battle_tower().get("menu_rows", [])) == Array(EXPECTED_MENU_ROWS),
		"The challenge menu reads %s." % [_r.data.battle_tower().get("menu_rows", [])]
	)
	for name: String in RomLayout.BATTLETOWER_MENU_TEXT_ORDER:
		_r.check(
			not String((_r.data.battle_tower().get("menu_text", {}) as Dictionary).get(
				name, ""
			)).is_empty(),
			"The room menu's %s box decoded to nothing." % name
		)
	## All 120 trainer lines, both arrays and all three kinds. A pin one stub out
	## reads the neighbouring line rather than nothing, so the count is what says
	## the run is the run and the emptiness is what says every entry is a text.
	var texts: Dictionary = _r.data.battle_tower().get("texts", {}) as Dictionary
	for kind: String in RomLayout.BATTLETOWER_TEXT_KINDS:
		var arrays: Dictionary = texts.get(kind, {}) as Dictionary
		for array: String in ["male", "female"]:
			var lines: Array = arrays.get(array, []) as Array
			var expected: int = RomLayout.BATTLETOWER_MALE_TEXTS if array == "male" \
				else RomLayout.BATTLETOWER_FEMALE_TEXTS
			if not _r.check(
				lines.size() == expected,
				"The %s %s lines number %d, not %d." % [array, kind, lines.size(), expected]
			):
				continue
			for index: int in lines.size():
				_r.check(
					not String(lines[index]).is_empty(),
					"The %s %s line %d decoded to nothing." % [array, kind, index]
				)


func _verify_class_tables() -> void:
	var genders: Array = _r.data.battle_tower().get("class_genders", []) as Array
	var sprites: Array = _r.data.battle_tower().get("class_sprites", []) as Array
	var expected: int = _r.data.trainer_count() - 1
	_r.check(
		genders.size() == expected and sprites.size() == expected,
		"The per-class tables are %d and %d rows, not %d." % [
			genders.size(), sprites.size(), expected,
		]
	)
	for index: Variant in EXPECTED_GENDERS:
		_r.check(
			int(genders[int(index)]) == int(EXPECTED_GENDERS[index]),
			"BTTrainerClassGenders %d is %d." % [index, int(genders[int(index)])]
		)
	for index: Variant in EXPECTED_SPRITES:
		_r.check(
			int(sprites[int(index)]) == int(EXPECTED_SPRITES[index]),
			"BTTrainerClassSprites %d is %d." % [index, int(sprites[int(index)])]
		)
	## Every class the 70 trainers actually name has to reach both tables, which
	## is what a class byte read one row out fails on.
	for row: Dictionary in _r.data.battle_tower().get("trainers", []) as Array:
		var trainer_class: int = int(row.get("class", 0))
		_r.check(
			trainer_class >= 1 and trainer_class <= expected,
			"%s is class %d, outside the two per-class tables." % [
				row.get("name", ""), trainer_class,
			]
		)
		_r.check(
			Gen2BattleTower.class_sprite(_r.data, trainer_class) > 0,
			"%s's class has no overworld sprite." % row.get("name", "")
		)


## A whole streak sampled on every level group: seven opponents, none of them
## the same trainer, each of three Pokemon that share no species or held item,
## and none repeating a species either of the two teams before it used.
func _verify_sampler() -> void:
	for group: int in Gen2BattleTower.LEVEL_GROUPS:
		var tower := Gen2BattleTower.new()
		tower.chosen_group = group + 1
		var random := RandomNumberGenerator.new()
		random.seed = group + 1
		var teams: Array = []
		var drawn: Array = []
		for battle: int in Gen2BattleTower.STREAK_LENGTH:
			var opponent: Dictionary = tower.load_opponent(_r.data, random)
			if not _r.check(
				not opponent.is_empty(),
				"group %d battle %d sampled no opponent" % [group, battle]
			):
				return
			_r.check(
				not drawn.has(int(opponent["trainer"])),
				"group %d met trainer %d twice in one streak" % [group, opponent["trainer"]]
			)
			drawn.append(int(opponent["trainer"]))
			## `CopyBTTrainer_FromBT_OT_TowBT_OTTemp` counts the trainer before
			## the fight, and `sBTTrainers[sNrOfBeaten]` is where the next sample
			## is written: without the count the streak keeps one slot.
			tower.beaten += 1
			var species: Array = []
			var items: Array = []
			for mon: Gen2SaveMon in opponent["mons"] as Array:
				_r.check(
					mon.level == (group + 1) * 10,
					"group %d drew a level %d opponent" % [group, mon.level]
				)
				species.append(mon.species)
				items.append(mon.item)
			_r.check(
				species.size() == Gen2BattleTower.PARTY_LENGTH,
				"group %d battle %d has %d Pokemon" % [group, battle, species.size()]
			)
			for index: int in species.size():
				_r.check(
					species.count(species[index]) == 1,
					"group %d battle %d doubled species %d" % [group, battle, species[index]]
				)
				_r.check(
					items.count(items[index]) == 1,
					"group %d battle %d doubled item %d" % [group, battle, items[index]]
				)
			for earlier: Array in teams.slice(maxi(0, teams.size() - 2)):
				for number: int in species:
					_r.check(
						not earlier.has(number),
						"group %d battle %d reused species %d" % [group, battle, number]
					)
			teams.append(species)


## `BattleTowerBattleRoom`'s own scene, driven on the real map: the opponent is
## sampled, its class gives the room's object a sprite, `battletowertext` prints
## that trainer's greeting, and the fight staged is the sampled team rather than
## a trainer-table party.
func _verify_battle_room() -> void:
	var state := Gen2WorldState.new()
	state.battle_tower().chosen_group = 3
	var world: Gen2WorldAPI = _r.open_world(
		BATTLE_ROOM_GROUP, BATTLE_ROOM_MAP, BATTLE_ROOM_CELL, state
	)
	if world == null:
		return
	world.set_party_summary(3, false, [1, 4, 7] as Array[int], [[], [], []],
		["A", "B", "C"], [false, false, false], {"levels": [30, 30, 30]})
	## `MapSetupScript_Warp` reaches `MAPCALLBACK_NEWMAP` and then the scene, so
	## the room's own `SCENE_BATTLETOWERBATTLEROOM_ENTER` runs on map entry
	## rather than off a coordinate the player steps on.
	var results: Array = world.dispatch_map_entry()
	for _frame: int in BATTLE_ROOM_FRAME_CAP:
		var staged: Dictionary = world.pending_runtime_request()
		if StringName(staged.get("kind", &"")) == &"battle_requested":
			break
		if not staged.is_empty():
			## Everything the room asks for on the way in: the warp sound, the
			## opponent's own music and the movements between them. Each is
			## answered the way the screen answers it, so the walk to the fight
			## is the real one.
			results.append_array(world.complete_runtime_request({"ok": true}))
			continue
		if not world.pending_script_wait().is_empty():
			results.append_array(world.advance_script_presentation_frame())
			continue
		if not world.script_busy():
			break
		results.append_array(world.run_event_queue(true, 0))
	var request: Dictionary = world.pending_runtime_request()
	if not _r.check(
		StringName(request.get("kind", &"")) == &"battle_requested",
		"the battle room staged %s rather than a fight" % [request.get("kind", &"none")]
	):
		return
	var values: Dictionary = request.get("values", {}) as Dictionary
	_r.check(
		StringName(values.get("kind", &"")) == &"battle_tower",
		"the fight is a %s battle" % [values.get("kind", &"")]
	)
	_r.check(
		(values.get("enemy_party", []) as Array).size() == Gen2BattleTower.PARTY_LENGTH,
		"the opponent brought %d Pokemon" % (values.get("enemy_party", []) as Array).size()
	)
	_r.check(
		int(values.get("trainer_class", 0)) >= 1,
		"the opponent has no trainer class"
	)
	_r.check(
		not String(values.get("trainer_name", "")).is_empty(),
		"the opponent has no name"
	)
	## `CopyBTTrainer_FromBT_OT_TowBT_OTTemp` runs in front of the fight.
	_r.check(
		state.battle_tower().challenge_state == Gen2BattleTower.CHALLENGE_IN_PROGRESS,
		"the challenge is not in progress by the time the first fight starts"
	)
	_r.check(state.battle_tower().beaten == 1, "the first trainer was not counted")
	var greeted: bool = false
	var sprited: bool = false
	for result: Dictionary in results:
		for event: Dictionary in result.get("events", []) as Array:
			if event.get("type", &"") == &"battle_tower_opponent_loaded":
				sprited = int(event.get("sprite", 0)) > 0
		var text: Dictionary = result.get("event", {}) as Dictionary
		if StringName(text.get("type", &"")) == &"text" \
			and not String(text.get("text", "")).is_empty():
			greeted = true
	_r.check(sprited, "the sampled opponent was given no overworld sprite")
	_r.check(greeted, "the opponent said nothing before the fight")


## The four party rules and the two room-menu refusals, each on a party that
## fails exactly it.
func _verify_rules() -> void:
	var legal: Dictionary = {
		"species": [1, 4, 7], "levels": [10, 10, 10],
		"held_items": [0, 0, 0], "eggs": [false, false, false],
	}
	_r.check(
		Gen2BattleTower.rule_failures(legal).is_empty(),
		"a legal party was refused: %s" % [Gen2BattleTower.rule_failures(legal)]
	)
	var cases: Array = [
		[{"species": [1, 4], "levels": [10, 10], "held_items": [0, 0],
			"eggs": [false, false]}, "only_three_may_be_entered"],
		[{"species": [1, 1, 7], "levels": [10, 10, 10], "held_items": [0, 0, 0],
			"eggs": [false, false, false]}, "must_all_be_different_kinds"],
		[{"species": [1, 4, 7], "levels": [10, 10, 10], "held_items": [1, 1, 0],
			"eggs": [false, false, false]}, "must_not_hold_the_same_items"],
		[{"species": [1, 4, 7], "levels": [10, 10, 10], "held_items": [0, 0, 0],
			"eggs": [false, false, true]}, "you_cant_take_an_egg"],
	]
	for case: Array in cases:
		_r.check(
			Gen2BattleTower.rule_failures(case[0] as Dictionary) == [String(case[1])],
			"%s was not the only failure of %s" % [case[1], case[0]]
		)
	## `BattleTower_LevelCheck` and `BattleTower_UbersCheck`: a member over the
	## room's own level, and a legendary under Lv.70 in a room below it.
	_r.check(
		Gen2BattleTower.level_check({"levels": [10, 11, 10]}, 1) == 1,
		"the level check missed a member over the room's level"
	)
	_r.check(
		Gen2BattleTower.level_check({"levels": [10, 10, 10]}, 1) == -1,
		"the level check refused a legal party"
	)
	_r.check(
		Gen2BattleTower.ubers_check(
			{"species": [1, 150, 7], "levels": [60, 60, 60]}, 6
		) == 1,
		"the ubers check let MEWTWO into a Lv.60 room"
	)
	_r.check(
		Gen2BattleTower.ubers_check(
			{"species": [1, 150, 7], "levels": [70, 70, 70]}, 7
		) == -1,
		"the ubers check refused a Lv.70 room, which it never reads"
	)
