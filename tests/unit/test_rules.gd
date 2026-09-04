extends GutTest

## The rules object itself: what a mode answers, what an override does to it, and
## what survives the options file. Each flag's own BEHAVIOUR is tested where the
## branch is, at the layer that owns it, not here.

const FIRST_FLAG: StringName = &"belly_drum_boosts_below_half_hp"
const REPRODUCED_TODAY: StringName = &"metal_powder_overflow"


func after_each() -> void:
	Gen2Rules.install(null)


## The default is what shipped, which is a mix: some cartridge bugs are
## reproduced and some are corrected, and a mode is what makes that uniform.
func test_the_default_is_todays_behaviour_and_the_two_modes_are_its_ends() -> void:
	var rules := Gen2Rules.new()
	assert_eq(rules.mode, Gen2Rules.MODE_CURRENT)
	assert_eq(rules.mode_of(), Gen2Rules.MODE_CURRENT)
	assert_false(rules.reproduces(FIRST_FLAG))
	assert_true(rules.reproduces(REPRODUCED_TODAY), "reproduced before any flag existed")

	rules.set_mode(Gen2Rules.MODE_VANILLA)
	for flag: StringName in Gen2Rules.FLAGS:
		assert_true(rules.reproduces(flag), String(flag))
	rules.set_mode(Gen2Rules.MODE_QOL)
	for flag: StringName in Gen2Rules.FLAGS:
		assert_false(rules.reproduces(flag), String(flag))


func test_an_override_moves_one_flag_and_names_the_set_custom() -> void:
	var rules := Gen2Rules.new()
	assert_true(rules.set_flag(FIRST_FLAG, true))
	assert_true(rules.reproduces(FIRST_FLAG))
	assert_eq(rules.mode_of(), Gen2Rules.MODE_CUSTOM)
	# Set back to what the mode already says and the override is gone rather than
	# kept as a value that agrees with it.
	assert_true(rules.set_flag(FIRST_FLAG, false))
	assert_true(rules.overrides.is_empty())
	assert_eq(rules.mode_of(), Gen2Rules.MODE_CURRENT)

	assert_false(rules.set_flag(&"no_such_bug", true), "a flag this build lacks is refused")
	assert_true(rules.overrides.is_empty())


## A mode is a starting point, not a reset: what the player moved by hand stays
## moved. `clear_flags` is the reset.
func test_a_mode_change_keeps_a_hand_moved_flag() -> void:
	var rules := Gen2Rules.new()
	rules.set_flag(FIRST_FLAG, true)
	rules.set_mode(Gen2Rules.MODE_QOL)
	assert_true(rules.reproduces(FIRST_FLAG))
	assert_false(rules.reproduces(REPRODUCED_TODAY))
	assert_eq(rules.mode_of(), Gen2Rules.MODE_CUSTOM)

	# Under vanilla that same override agrees with the mode, so it stops being one.
	rules.set_mode(Gen2Rules.MODE_VANILLA)
	assert_true(rules.overrides.is_empty())
	assert_eq(rules.mode_of(), Gen2Rules.MODE_VANILLA)

	rules.set_flag(REPRODUCED_TODAY, false)
	rules.clear_flags()
	assert_eq(rules.mode_of(), Gen2Rules.MODE_VANILLA)


## Only the overrides are written, so a flag added by a later build is not
## recorded in a file that never chose it and keeps its own default.
func test_only_what_differs_is_written_and_read_back() -> void:
	var rules := Gen2Rules.new()
	rules.set_mode(Gen2Rules.MODE_VANILLA)
	rules.challenge = Gen2Rules.CHALLENGE_HARD
	rules.set_flag(REPRODUCED_TODAY, false)

	var written: Dictionary = rules.to_dict()
	assert_eq(written["mode"], String(Gen2Rules.MODE_VANILLA))
	assert_eq(written["flags"], {String(REPRODUCED_TODAY): false})

	var restored: Gen2Rules = Gen2Rules.parse(written)
	assert_true(restored.matches(rules))
	assert_eq(restored.challenge, Gen2Rules.CHALLENGE_HARD)
	assert_false(restored.reproduces(REPRODUCED_TODAY))
	assert_true(restored.reproduces(FIRST_FLAG))


func test_an_unreadable_block_falls_back_rather_than_refusing_the_rest() -> void:
	var rules: Gen2Rules = Gen2Rules.parse({
		"mode": "sideways", "challenge": "impossible", "flags": {"no_such_bug": true},
	})
	assert_eq(rules.mode, Gen2Rules.MODE_CURRENT)
	assert_eq(rules.challenge, Gen2Rules.CHALLENGE_VANILLA)
	assert_true(rules.overrides.is_empty())
	assert_true(Gen2Rules.parse("not a block").matches(Gen2Rules.new()))


## Hard rewrites which AI layers score rather than inventing a score of its own,
## so it can only ever ask for bits the scorer already reads.
func test_hard_rewrites_a_trainer_classes_own_ai_layers() -> void:
	var rules := Gen2Rules.new()
	var imported: int = Gen2Layout.AI_BASIC | Gen2Layout.AI_SMART
	assert_eq(rules.ai_move_weights(imported), imported, "vanilla is the cartridge's own")

	rules.challenge = Gen2Rules.CHALLENGE_HARD
	assert_eq(rules.ai_move_weights(imported), Gen2Layout.AI_MOVE_WEIGHTS_MASK)
	assert_eq(
		rules.ai_move_weights(0) & ~Gen2Layout.AI_MOVE_WEIGHTS_MASK, 0,
		"and never a bit the scorer does not read"
	)

	rules.challenge = Gen2Rules.CHALLENGE_NUZLOCKE
	assert_eq(
		rules.ai_move_weights(Gen2Layout.AI_BASIC | (1 << 15)), Gen2Layout.AI_BASIC,
		"a patched trainer cannot smuggle one in either"
	)


## The same rewrite on the word that decides when a class switches out and
## reaches into its bag. Hard moves every class onto SWITCH_OFTEN and leaves the
## item bits where the cartridge put them.
func test_hard_moves_every_trainer_class_onto_switch_often() -> void:
	var rules := Gen2Rules.new()
	var imported: int = Gen2Layout.SWITCH_RARELY | Gen2Layout.CONTEXT_USE
	assert_eq(rules.ai_item_switch(imported), imported, "vanilla is the cartridge's own")

	rules.challenge = Gen2Rules.CHALLENGE_HARD
	assert_eq(
		rules.ai_item_switch(imported), Gen2Layout.SWITCH_OFTEN | Gen2Layout.CONTEXT_USE
	)
	assert_eq(
		rules.ai_item_switch(Gen2Layout.SWITCH_SOMETIMES), Gen2Layout.SWITCH_OFTEN,
		"and never two switch answers at once"
	)
	assert_eq(
		rules.ai_item_switch(1 << 15) & ~Gen2Layout.AI_ITEM_SWITCH_MASK, 0,
		"a patched class cannot smuggle a bit in"
	)


## The party rules are one global number each rather than 800 rewritten teams:
## a percentage on the level, a perfect DV word, a full set of stat experience.
func test_hard_raises_a_trainers_party_by_one_global_rule_each() -> void:
	var rules := Gen2Rules.new()
	assert_eq(rules.trainer_level(20), 20, "vanilla leaves the table alone")
	assert_eq(rules.trainer_dvs(0x1234), 0x1234)
	assert_true(rules.trainer_stat_exp().is_empty())

	rules.challenge = Gen2Rules.CHALLENGE_HARD
	assert_eq(rules.trainer_level(20), 23, "20 plus 15 percent, floored")
	assert_eq(rules.trainer_level(2), 3, "and never less than one level")
	assert_eq(
		rules.trainer_level(Gen2Experience.MAX_LEVEL), Gen2Experience.MAX_LEVEL,
		"the cap is the cartridge's own"
	)
	assert_eq(rules.trainer_level(0), 0, "an absent level is not raised")
	assert_eq(rules.trainer_dvs(0x1234), Gen2BattleMon.PERFECT_DVS)
	var trained: Dictionary = rules.trainer_stat_exp()
	assert_eq(trained.size(), Gen2Experience.STAT_EXP_KEYS.size())
	for key: String in Gen2Experience.STAT_EXP_KEYS:
		assert_eq(int(trained[key]), Gen2Stats.MAX_STAT_EXP)


## The challenge is part of what names a run, so two runs under different ones
## are not the same rules even with identical flags.
func test_the_challenge_is_part_of_what_makes_two_rule_sets_equal() -> void:
	var vanilla := Gen2Rules.new()
	var nuzlocke: Gen2Rules = vanilla.duplicate_rules()
	nuzlocke.challenge = Gen2Rules.CHALLENGE_NUZLOCKE
	assert_false(vanilla.matches(nuzlocke))
	assert_true(nuzlocke.is_nuzlocke())
	assert_false(vanilla.is_nuzlocke())
	assert_true(nuzlocke.duplicate_rules().matches(nuzlocke))


## One installed set at a time, because the statics that read the rules
## ([Gen2Damage], [Gen2Experience], [Gen2BattleAI]) take no engine object and two
## sources would let them disagree with the battle they are resolving.
func test_the_installed_set_is_what_a_static_reads() -> void:
	assert_false(Gen2Rules.hardware(FIRST_FLAG))
	var rules := Gen2Rules.new()
	rules.set_flag(FIRST_FLAG, true)
	Gen2Rules.install(rules)
	assert_true(Gen2Rules.hardware(FIRST_FLAG))
	assert_same(Gen2Rules.active(), rules)

	Gen2Rules.install(null)
	assert_false(Gen2Rules.hardware(FIRST_FLAG), "and nothing is left installed")
	assert_false(Gen2Rules.hardware(&"no_such_bug"), "an unknown flag is not hardware")


func test_a_copy_is_independent_of_what_it_was_copied_from() -> void:
	var rules := Gen2Rules.new()
	rules.set_flag(FIRST_FLAG, true)
	var copy: Gen2Rules = rules.duplicate_rules()
	assert_true(copy.matches(rules))
	copy.set_flag(FIRST_FLAG, false)
	assert_true(rules.reproduces(FIRST_FLAG))
	assert_false(copy.matches(rules))
	assert_false(rules.matches(null))
