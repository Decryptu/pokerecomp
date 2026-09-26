class_name Gen2Battle
extends RefCounted

## A battle: two parties, a turn at a time, scene-free with randomness injected.
## A turn answers with events carrying numbers, never a string; one ending with
## somebody down stands still until [method replace_fallen].

## Plain numbers rather than an enum: they are dictionary keys and event payloads
## throughout, and everything reading one compares it against these two.
const PLAYER: int = 0
const ENEMY: int = 1

## What a turn can report. Every event carries [code]side[/code], which is
## whoever acted, and the rest depends on the type.
const USED_MOVE: StringName = &"used_move"
const MISSED: StringName = &"missed"
const NO_EFFECT: StringName = &"no_effect"
## `GetFailureResultText`'s `ItFailedText`.
const IT_FAILED: StringName = &"it_failed"
const HIT: StringName = &"hit"
const RECOIL: StringName = &"recoil"
const FAINTED: StringName = &"fainted"
## A multi-hit move's summary, once every planned hit has landed. A target that
## faints partway gets none, the loop ending the move first.
const HIT_TIMES: StringName = &"hit_times"
const DRAINED: StringName = &"drained"  ## A draining move healed the attacker off what it dealt.
## A one-hit KO landed. Its own event rather than a flag on [constant HIT]: the
## cartridge shows neither a critical nor an effectiveness line, the damage
## having been multiplied by neither.
const OHKO: StringName = &"ohko"
## `criticaltext`: the critical line or ([code]ohko[/code]) the one-hit line.
const CRITICAL_HIT: StringName = &"critical_hit"
## `supereffectivetext`: `SuperEffectiveText` or `NotVeryEffectiveText`.
const EFFECTIVENESS: StringName = &"effectiveness"
## A status stopped a Pokémon moving, [code]reason[/code] being which:
## [code]&"sleep"[/code], [code]&"freeze"[/code], [code]&"paralysis"[/code],
## [code]&"flinch"[/code], [code]&"recharge"[/code].
const CANNOT_MOVE: StringName = &"cannot_move"
const WOKE_UP: StringName = &"woke_up"
## A freeze cleared, `side` being whoever thawed rather than whoever acted: a
## Flame Wheel, `BurnTarget`'s `Defrost`, or `HandleDefrost`'s roll.
const THAWED: StringName = &"thawed"
## A status put on a Pokémon, and a slice taken off by one it already had.
const STATUS_INFLICTED: StringName = &"status_inflicted"
const HURT_BY_STATUS: StringName = &"hurt_by_status"
const IN_LOVE_WITH: StringName = &"in_love_with"
## Confusion put on a target. Not [constant STATUS_INFLICTED]: confusion lives
## on [Gen2Substatus] rather than the status byte, and a Pokémon can carry both
## at once.
const CONFUSE_INFLICTED: StringName = &"confuse_inflicted"
## Confusion said every turn it is still there, and the turn it lifts.
const CONFUSED: StringName = &"confused"
const SNAPPED_OUT: StringName = &"snapped_out"
const HURT_ITSELF: StringName = &"hurt_itself"  ## A confused Pokémon hit itself instead of moving.
## The first half of a two-turn move: the user is locked in and nothing else
## happens this turn. See [method move_for] for the second half.
const CHARGING_UP: StringName = &"charging_up"
## Haze: every stage on both sides is gone. About both sides, like [constant OVER].
const STAGES_CLEARED: StringName = &"stages_cleared"
## Psych Up: the target's stages, now the user's too.
const STAGES_COPIED: StringName = &"stages_copied"
## A stat moved a stage, or tried to and could not. [code]stat[/code] is the key
## [Gen2BattleMon] keeps it under; [code]by[/code] is how many stages, signed.
const STAT_CHANGED: StringName = &"stat_changed"
const STAT_CHANGE_FAILED: StringName = &"stat_change_failed"
## A Pokémon called back, and a Pokémon put out. They are two events rather than
## one because a replacement after a faint is only the second half: there is
## nobody to call back, and the screen has one sentence to say rather than two.
## Either carries [code]quiet[/code] when the entrance prints no line of its own.
const WITHDREW: StringName = &"withdrew"
const SENT_OUT: StringName = &"sent_out"
## `SendOutMonText`'s four lines, chosen off the opponent's remaining HP: the
## `line` field of a player [constant SENT_OUT].
const SEND_OUT_GO: int = 0
const SEND_OUT_DO_IT: int = 1
const SEND_OUT_GO_FOR_IT: int = 2
const SEND_OUT_FOES_WEAK: int = 3
## `WithdrawMonText`'s four lines: the `line` of a player [constant WITHDREW].
const WITHDRAW_ENOUGH: int = 0
const WITHDRAW_COME_BACK: int = 1
const WITHDRAW_OK: int = 2
const WITHDRAW_GOOD: int = 3
## How a Pokémon comes in; a replacement is a switch with nobody to call back.
const ENTRANCE_SWITCH: int = 0
const ENTRANCE_BATON_PASS: int = 1
const ENTRANCE_DRAGGED: int = 2
## `ld c, n / call DelayFrames`: [code]frames[/code] with nothing drawn or read.
const DELAY: StringName = &"delay"
## `ANIM_RETURN_MON`, which `RecallPlayerMon` plays after `PursuitSwitch`.
const ANIM_RETURN_MON: int = 0x102
## The `ld c, 50` of `BattleMonEntrance` and `PassedBattleMonEntrance`.
const SWITCH_DELAY_FRAMES: int = 50
## `ResidualDamage.fainted`'s and `HandleEnemyMonFaint`'s own holds.
const RESIDUAL_FAINT_FRAMES: int = 20
const ENEMY_FAINT_FRAMES: int = 60
## `PlayStereoCry` behind an entrance: the cry `CheckFaintedFrzSlp` allows, on
## the entering side's own tracks. Silent on its own, so nothing is printed for
## it.
const CRY: StringName = &"cry"
## `UpdatePlayerHUD` or `UpdateEnemyHUD` closing an entrance.
const HUD_DRAWN: StringName = &"hud_drawn"
## The player got away, `how` naming the branch: [code]&"battle_type"[/code] for
## the two that always escape, [code]&"item"[/code] for the Smoke Ball,
## [code]&"speed"[/code], [code]&"odds"[/code] and [code]&"roll"[/code].
const FLED: StringName = &"fled"
## The roll came up short. The turn is spent and the enemy still acts, which is
## `.cant_escape_2` setting `wBattlePlayerAction` to `BATTLEPLAYERACTION_USEITEM`.
const RUN_FAILED: StringName = &"run_failed"
## Running was refused outright, which costs no turn at all: `BattleMenu_Run`
## reopens the menu. `reason` is [code]&"trainer"[/code] or
## [code]&"battle_type"[/code].
const RUN_BLOCKED: StringName = &"run_blocked"
const OVER: StringName = &"over"

## `Text_GotchaMonWasCaught`: the wild is caught and kept. Published rather than
## printed, because the line beside it is `PokeBallEffect`'s own and not one of
## the turn's. Carries what identifies the catch: `species`, `level`, `dvs`,
## `shiny`, `ball`, `method`, `map_group`, `map_number`, `battle_type`,
## `destination` (&"party" or &"box"), `tutorial` and `contest`.
const CAUGHT: StringName = &"caught"

## Experience, once the fainted Pokémon's opponent has somebody to award it to.
## Never for [constant ENEMY]: `GiveExperiencePoints` reads the player's party
## alone, so a trainer's Pokémon are the reason and never the recipient.
const EXP_GAINED: StringName = &"exp_gained"
## A wild win's `PlayVictoryMusic`, ahead of the experience; [code]silent[/code]
## is its `.lost` branch (no Exp. Share, Pay Day or participant standing).
const VICTORY_MUSIC: StringName = &"victory_music"
## The five stats in [constant Gen2Experience.STAT_EXP_KEYS], out of the block
## [constant EXP_GAINED] came from ([method Gen2Experience.shared_block]) and
## divided by the same count, but a base stat rather than a level figure.
const STAT_EXP_GAINED: StringName = &"stat_exp_gained"
## A level gained from the experience just awarded. [code]old_stats[/code] and
## [code]new_stats[/code] are both [Gen2BattleMon.stats], so a screen can show
## what moved without asking the Pokémon twice.
const GREW_LEVEL: StringName = &"grew_level"
## A move learned into a slot that had nothing in it, no question asked because
## the cartridge does not ask one when there is nowhere for the answer to go.
const MOVE_LEARNED: StringName = &"move_learned"
## Every slot already held something, so nothing was learned automatically:
## see [method must_learn_move].
const MOVE_OFFERED: StringName = &"move_offered"
## The offer from [constant MOVE_OFFERED] was answered, one way or the other.
const MOVE_FORGOTTEN: StringName = &"move_forgotten"
const MOVE_DECLINED: StringName = &"move_declined"

## Disable, Attract, Encore, Mist and Focus Energy refuse for their own reasons
## rather than missing a roll ([constant MISSED]) or losing to a type
## ([constant NO_EFFECT]): the "but it failed!" the cartridge shares.
const MOVE_FAILED: StringName = &"move_failed"
const MIRROR_MOVE_FAILED: StringName = &"mirror_move_failed"
## `BellyDrumText`.
const ATTACK_MAXIMIZED: StringName = &"attack_maximized"
## `BattleCommand_Charge`'s `IgnoredOrders2Text`.
const IGNORED_ORDERS: StringName = &"ignored_orders"
## `BattleCommand_DoTurn.out_of_pp`; [code]continuous[/code] is `HasNoPPLeftText`.
const NO_PP_LEFT: StringName = &"no_pp_left"
const BIDE_STORING: StringName = &"bide_storing"
const BIDE_UNLEASHED: StringName = &"bide_unleashed"
const RAGE_BUILDING: StringName = &"rage_building"
const FUTURE_SIGHT_SET: StringName = &"future_sight_set"
const FUTURE_SIGHT_HIT: StringName = &"future_sight_hit"
const COINS_SCATTERED: StringName = &"coins_scattered"
const TRANSFORMED: StringName = &"transformed"
## Mimic and Sketch both replace their own slot with the opponent's last move,
## but only Sketch persists after battle. Separate events keep their two source
## lines distinct in the battle screen.
const MIMIC_LEARNED: StringName = &"mimic_learned"
const SKETCHED_MOVE: StringName = &"sketched_move"
## Conversion and Conversion2 both print `TransformedTypeText` after replacing
## both of the user's active type bytes.
const TYPE_CHANGED: StringName = &"type_changed"
## `_ConvertedTypeText`: Generation 1's Conversion copies the target's pair
## rather than picking one, so its line names the target and not a type.
const TYPE_COPIED: StringName = &"type_copied"

## Disable locked a slot and later let it go, [code]slot[/code] and
## [code]move[/code] being the target's. A Pokémon locked into the disabled move
## is refused through [constant CANNOT_MOVE]'s [code]&"disabled"[/code].
const DISABLE_INFLICTED: StringName = &"disable_inflicted"
const DISABLE_ENDED: StringName = &"disable_ended"

## Falling in love, [constant Gen2Substatus.ATTRACTED] until a switch. A turn it
## costs is [constant CANNOT_MOVE]'s [code]&"attract"[/code], the shape flinch
## and confusion use.
const ATTRACT_INFLICTED: StringName = &"attract_inflicted"

## Encore locked a slot, and later let it go, the same pair
## [constant DISABLE_INFLICTED] and [constant DISABLE_ENDED] are for Disable.
const ENCORE_INFLICTED: StringName = &"encore_inflicted"
const ENCORE_ENDED: StringName = &"encore_ended"

## What a held item gave back between turns. Leftovers has its own line
## ("recovered with"); [constant RECOVERED_USING_ITEM] covers the HP berry and the
## status berries, which share `UseOpponentItem`. [code]item[/code] is what did it,
## and on the consumable three what is no longer held.
const RECOVERED_WITH_ITEM: StringName = &"recovered_with_item"
const RECOVERED_USING_ITEM: StringName = &"recovered_using_item"
const RESTORED_PP: StringName = &"restored_pp"
const ITEM_HEALED_CONFUSION: StringName = &"item_healed_confusion"
## `BattleText_UsersStringBuffer1Activated`, the line a held item says when it
## works on its own holder. Only the Berserk Gene reaches it with cartridge data.
const ITEM_ACTIVATED: StringName = &"item_activated"

## `HungOnText`: a Focus Band held the Pokémon on one hit point. The line names
## the item, which is why [code]item[/code] is on it. Endure's own line is
## [constant ENDURED_HIT] and neither text stands in for the other.
const ENDURED: StringName = &"endured"

## Protect and Detect: `ProtectedItselfText` when the flag goes up, and
## `ProtectingItselfText` on every move it then turns away, which is printed
## ahead of that move's own [constant MISSED].
const PROTECTED_ITSELF: StringName = &"protected_itself"
const PROTECTING_ITSELF: StringName = &"protecting_itself"

## Endure: `BracedItselfText` when the flag goes up and `EnduredText` on each hit
## it survives. A hit can be clamped more than once a turn, since nothing spends
## the flag.
const BRACED_ITSELF: StringName = &"braced_itself"
const ENDURED_HIT: StringName = &"endured_hit"

## `DestinyBondEffectText` when it is used and `TookDownWithItText` when it
## collects, where [code]target[/code] is the Pokémon that went down holding it
## and [code]side[/code] the attacker it takes with it, in that order.
const DESTINY_BOND_SET: StringName = &"destiny_bond_set"
const TOOK_DOWN_WITH_IT: StringName = &"took_down_with_it"

## Whirlwind and Roar against a trainer: `DraggedOutText`, after the replacement
## is out and before any spikes. The line is `<USER>` in both directions, mirrored
## rather than corrected, so [code]side[/code] is the user.
const DRAGGED_OUT: StringName = &"dragged_out"

## The same pair against a wild, where the battle ends: `FledInFearText` for
## Roar and `BlownAwayText` for Whirlwind, told apart by the move number.
## [code]target[/code] is whoever left, either way round.
const FLED_IN_FEAR: StringName = &"fled_in_fear"
const BLOWN_AWAY: StringName = &"blown_away"

## `FledFromBattleText`: Teleport, which takes its own user out rather than the
## other side. Named for `<USER>`, so [code]side[/code] is who left.
const FLED_FROM_BATTLE: StringName = &"fled_from_battle"
## `UnaffectedText`, and Generation 1's `IsUnaffectedText` for Roar on a trainer.
const UNAFFECTED: StringName = &"unaffected"

const WILD_FLED: StringName = &"wild_fled"

## Foresight and Lock On, whose flags sit on [code]target[/code] rather than on
## the Pokémon that used the move. `TookAimText` names only the aimer, which is
## why [constant TOOK_AIM] carries nothing beyond the side.
const IDENTIFIED_SET: StringName = &"identified_set"
const TOOK_AIM: StringName = &"took_aim"

## Spite, carrying the [code]slot[/code] drained, the [code]move[/code] in it and
## the [code]amount[/code] taken, which is the number `SpiteEffectText` prints.
const PP_REDUCED: StringName = &"pp_reduced"

## Pain Split, which names neither Pokémon. Both sides' health is on the event
## because both moved: [code]hp[/code] is the user's and [code]target_hp[/code] the
## other's.
const SHARED_PAIN: StringName = &"shared_pain"

## Thief, carrying the [code]item[/code] that moved. `StoleText` names the thief
## and the item and calls the loser "its foe", so nothing else is needed.
const STOLE_ITEM: StringName = &"stole_item"

## `BeatUpAttackText`, once per party member Beat Up sends in. [code]index[/code]
## is that member's party slot, or -1 for a wild Pokémon, which has no party and
## swings once as itself.
const BEAT_UP_ATTACK: StringName = &"beat_up_attack"

## Rain Dance, Sunny Day and Sandstorm, [code]weather[/code] being the
## [Gen2Weather] value. [constant WEATHER_CONTINUES] is printed on every turn the
## weather survives, which is the turn a Sandstorm's damage lands on.
const WEATHER_STARTED: StringName = &"weather_started"
const WEATHER_CONTINUES: StringName = &"weather_continues"
const WEATHER_ENDED: StringName = &"weather_ended"
const HURT_BY_SANDSTORM: StringName = &"hurt_by_sandstorm"

## Reflect, Light Screen and Safeguard going up and running out, one pair for the
## three: [code]screen[/code] is the [Gen2Screens] flag and the side the one it
## protects. [constant SAFEGUARD_PROTECTED] is
## `BattleCommand_CheckSafeguard`'s line, with the `target` it failed against.
const SCREEN_SET: StringName = &"screen_set"
const SCREEN_FADED: StringName = &"screen_faded"
const SAFEGUARD_PROTECTED: StringName = &"safeguard_protected"

## `StartPerishText` names both Pokémon, so its [code]side[/code] is only whoever
## sang. [constant PERISH_COUNT] carries the side counting down and the
## [code]count[/code] reached, the killing zero included.
const PERISH_SONG_STARTED: StringName = &"perish_song_started"
const PERISH_COUNT: StringName = &"perish_count"

## A trainer spent one of its two items, [code]effect[/code] being
## [method Gen2AIItems.apply]'s answer so a screen follows the bar without asking
## again. One event rather than thirteen: the cartridge prints one line.
const TRAINER_USED_ITEM: StringName = &"trainer_used_item"

## [constant HP_RESTORED] carries `hp` and `max_hp` so a screen moves the bar
## without reading the battle back; [constant HP_ALREADY_FULL] is
## `BattleCommand_Heal`'s refusal, which costs the turn. Rest's two lines are two
## events, the cartridge picking on whether a status was cleared.
const HP_RESTORED: StringName = &"hp_restored"
const HP_ALREADY_FULL: StringName = &"hp_already_full"
const WENT_TO_SLEEP: StringName = &"went_to_sleep"
const RESTED: StringName = &"rested"

## Heal Bell, whose text names nobody: `BellChimedText` is one line about a bell
## and the party it cleared is the acting side's.
const BELL_CHIMED: StringName = &"bell_chimed"

## Splash, and the one line it exists to print.
const NOTHING_HAPPENED: StringName = &"nothing_happened"

## Magnitude, which says which of the seven it rolled before it lands.
## [code]magnitude[/code] is the number in the line, 4 to 10, not the power.
const MAGNITUDE: StringName = &"magnitude"

## Present's fourth row against a target that is already at full health.
## [code]target[/code] is who refused, since `PresentFailedText` names them.
const PRESENT_REFUSED: StringName = &"present_refused"

## A missed Jump Kick or Hi Jump Kick, which costs its user an eighth of the
## damage it would have dealt. Carries the user's own `hp` and `max_hp`, the way
## [constant RECOIL] does, so a screen moves the bar without asking again.
const CRASHED: StringName = &"crashed"

## Bind, Wrap, Fire Spin, Clamp and Whirlpool: bound, taking a sixteenth, or let
## go. [code]move[/code] is what the texts name through `wStringBuffer1`; the
## release carries no damage, the turn the counter empties costing nothing.
const TRAPPED: StringName = &"trapped"
const HURT_BY_TRAP: StringName = &"hurt_by_trap"
const RELEASED_FROM_TRAP: StringName = &"released_from_trap"
## `AttackContinuesText`, which only Generation 1's trapping moves print: the
## user repeats the move and the target spends the turn held in place.
const ATTACK_CONTINUES: StringName = &"attack_continues"
const THRASHING_ABOUT: StringName = &"thrashing_about"

## Mean Look and Spider Web landed. Set on the user, cleared by any send-out;
## a second one from the same user is [constant MOVE_FAILED].
const CANT_ESCAPE_SET: StringName = &"cant_escape_set"

## A switch `TryPlayerSwitch` refused: `BattleText_MonCantBeRecalled`, then back
## to `BattleMenuPKMN_Loop`, so no turn is spent. As [constant RUN_BLOCKED] is.
const SWITCH_BLOCKED: StringName = &"switch_blocked"

## `OfferSwitch`'s question, which only SHIFT reaches: the trainer is about to
## send [code]index[/code] out and the player may change too, until
## [method answer_switch_offer]. Raised from both places `EnemySwitch` is.
const SWITCH_OFFERED: StringName = &"switch_offered"

## Mist and Focus Energy, set on the user. Both fail with [constant MOVE_FAILED]
## on a second use rather than silently re-applying.
const MIST_SET: StringName = &"mist_set"
const FOCUS_ENERGY_SET: StringName = &"focus_energy_set"

## Substitute. Two refusals, because the cartridge picks between
## `HasSubstituteText` and `TooWeakSubText` on which precondition failed. The last
## two carry no amount: `SubTookDamageText` reports none and the health never
## moved.
const SUBSTITUTE_MADE: StringName = &"substitute_made"
const SUBSTITUTE_ALREADY: StringName = &"substitute_already"
const SUBSTITUTE_TOO_WEAK: StringName = &"substitute_too_weak"
const SUBSTITUTE_TOOK_DAMAGE: StringName = &"substitute_took_damage"
const SUBSTITUTE_FADED: StringName = &"substitute_faded"

## `BattleCommand_RaiseSubNoAnim` and `..._LowerSubNoAnim`: once `WaitBGMap` is
## discounted, the doll drawn over a picture or taken off it, no frames and no
## battle state. An animated drop is the animation's own `anim_dropsub`.
const SUBSTITUTE_PIC: StringName = &"substitute_pic"

## `MinimizeDropSub`: `wPlayerMinimized` reloads the actor's square as
## `GetMinimizePic`'s dot for as long as the Pokemon stays in, and a send-out
## clears it with every other volatile, so there is no event the other way.
const MINIMIZED: StringName = &"minimized"

## Leech Seed, on the Pokémon that was seeded rather than the one that seeded it.
## [constant LEECH_SEED_SAPPED] carries the healed side under `to`, `to_amount`,
## `to_hp` and `to_max_hp`, since one event moves health across the field.
const WAS_SEEDED: StringName = &"was_seeded"
const LEECH_SEED_SAPPED: StringName = &"leech_seed_sapped"

## Nightmare and Curse, both quarters and both on the sufferer.
## [constant CURSE_SET] carries the user's own `hp` after the half it cut.
const NIGHTMARE_STARTED: StringName = &"nightmare_started"
const HURT_BY_NIGHTMARE: StringName = &"hurt_by_nightmare"
const CURSE_SET: StringName = &"curse_set"
const HURT_BY_CURSE: StringName = &"hurt_by_curse"

## Spikes, which are field state on the side they were scattered onto.
const SPIKES_SET: StringName = &"spikes_set"
const HURT_BY_SPIKES: StringName = &"hurt_by_spikes"

## `BattleCommand_ClearHazards`' three lines, all about the user's own side. Not
## [constant RELEASED_FROM_TRAP]: `HandleWrap`'s release names the move, this one
## the Pokémon that spun out of it.
const SHED_LEECH_SEED: StringName = &"shed_leech_seed"
const BLEW_SPIKES: StringName = &"blew_spikes"
const RELEASED_BY: StringName = &"released_by"

## `EvadedText`, which only `BattleCommand_LeechSeed` prints. Not
## [constant MISSED], which is `GetFailureResultText`'s own line.
const EVADED: StringName = &"evaded"

## `DidntAffect1Text` and `AlreadyAsleepText`'s three, in place of [constant MISSED].
const STATUS_DIDNT_AFFECT: StringName = &"status_didnt_affect"
const STATUS_ALREADY: StringName = &"status_already"

## A drop blocked by Mist. Not [constant STAT_CHANGE_FAILED]: the cartridge's own
## "It's protected by mist!" rather than the "won't go any lower" a drop at its
## floor gets.
const MIST_PROTECTED: StringName = &"mist_protected"

## `ANIM_SEND_OUT_MON` and its two `wBattleAnimParam` values: `$0` the ball,
## `$1` the shiny sparkle. `$101`, not 101: read as a decimal it is NIGHT SHADE,
## which decodes and draws, so the ball was a night shade for a while.
const ANIM_SEND_OUT_MON: int = 0x101
const SEND_OUT_ANIM_NORMAL: int = 0
const SEND_OUT_ANIM_SHINY: int = 1

## `PlayFXAnimID`: `index` (`wFXAnimID`), `param` (`wBattleAnimParam`),
## `after_anim`, `enemy_turn`, `effectiveness` (which `PlayHitSound` reads) and
## `restore_user_pic`, the `AppearUserLowerSub` after Fly and Dig.
const ANIMATION: StringName = &"animation"

## `AppearUserRaiseSub` with no animation: the picture, or the doll when
## `raised`, stamped back after a missed or cancelled Fly or Dig.
const APPEAR_USER: StringName = &"appear_user"
## `DisappearUser`: Fly's or Dig's charge clears the square, scene on or off.
const DISAPPEAR_USER: StringName = &"disappear_user"

## What a side does with its turn. Switching is settled before priority is looked
## at, which is why it is an action rather than a very fast move.
const ACTION_MOVE: StringName = &"move"
const ACTION_SWITCH: StringName = &"switch"
## `BattleMenu_Run` runs at menu time, so running is settled before the turn: a
## success ends the battle before either side moves and a refusal spends none.
const ACTION_RUN: StringName = &"run"
## `AI_TryItem`'s action, and `BATTLEPLAYERACTION_USEITEM` on the player's side.
## The enemy's costs the turn and lands before the player's move whatever the
## speeds say, `AI_SwitchOrTryItem` setting `wEnemyGoesFirst`; the player's is
## banked once [method use_bag_item] has already applied the effect.
const ACTION_ITEM: StringName = &"item"

## `HandleBerserkGene`'s `BattleCommand_AttackUp2`, and the count it never
## writes: a zero byte decremented once is 255 more turns after this one.
const BERSERK_GENE_STAGES: int = 2
const BERSERK_GENE_CONFUSION_TURNS: int = 256

## `wBattleType`. Only the values `TryToRunAwayFromBattle` branches on are named;
## everything else reaches the ordinary speed check.
const BATTLETYPE_NORMAL: int = 0
const BATTLETYPE_FORCEITEM: int = 1
const BATTLETYPE_DEBUG: int = 2
## The Dude's tutorial, which `PokeBallEffect` catches without a roll.
const BATTLETYPE_TUTORIAL: int = 3
## Written by `FishFunction`'s `.goodtofish`. It names the battle-start line and
## is the one condition `LureBallMultiplier` boosts on.
const BATTLETYPE_FISH: int = 4
const BATTLETYPE_CONTEST: int = 6
const BATTLETYPE_FORCESHINY: int = 7
## Named by `PlayBattleMusic` alone: nothing else here branches on it.
const BATTLETYPE_ROAMING: int = 5
## What TreeMonEncounter writes before a headbutt battle. CheckSleepingTreeMon
## is the only thing that reads it.
const BATTLETYPE_TREE: int = 8
const BATTLETYPE_TRAP: int = 9
const BATTLETYPE_CELEBI: int = 11
const BATTLETYPE_SUICUNE: int = 12
## Generation 1's `BATTLE_TYPE_SAFARI`, whose own byte is 2 and which Crystal
## has no row for at all.
const BATTLETYPE_SAFARI: int = 13
## The two lists it reads them against, in source order.
const ALWAYS_ESCAPES: Array[int] = [
	BATTLETYPE_DEBUG, BATTLETYPE_CONTEST, BATTLETYPE_SAFARI,
]
const NEVER_ESCAPES: Array[int] = [
	BATTLETYPE_TRAP, BATTLETYPE_CELEBI, BATTLETYPE_FORCESHINY, BATTLETYPE_SUICUNE,
]

## `TryToRunAwayFromBattle`: `player_speed * 32 / ((enemy_speed / 4) & $ff)`, plus
## 30 per attempt after the first, and over a byte gets away without a roll.
const FLEE_SPEED_MULTIPLIER: int = 32
const FLEE_ENEMY_SPEED_SHIFT: int = 2
const FLEE_ATTEMPT_BONUS: int = 30
const FLEE_ODDS_RANGE: int = 256

## `data/wild/flee_mons.asm` (pokegold adds SUICUNE), rolled below `50 percent + 1` and `10 percent + 1`.
const ALWAYS_FLEE_MONS: Array[int] = [243, 244]
const GOLD_SILVER_ALWAYS_FLEE_MONS: Array[int] = [243, 244, 245]
const OFTEN_FLEE_MONS: Array[int] = [104, 144, 145, 146, 195, 225, 231, 216]
const SOMETIMES_FLEE_MONS: Array[int] = [
	81, 88, 114, 122, 133, 137, 147, 148, 176, 197, 201, 209, 214,
]
const OFTEN_FLEE_BOUND: int = 128
const SOMETIMES_FLEE_BOUND: int = 26

## Priority runs 0 to 3 with most moves at 1, so a move can go below the ordinary
## as well as above it. Keyed by effect byte, which the cache carries.
const BASE_PRIORITY: int = 1
## `MainInBattleLoop`'s two `cp`s in order: QUICK_ATTACK's user moves first,
## COUNTER's last, and `50 percent + 1` bounds the tie.
const GEN1_PRIORITY_MOVES: Array = [[0x62, true], [0x44, false]]
const GEN1_TIE_BOUND: int = 129

const EFFECT_PRIORITIES: Dictionary = {
	Gen2MoveEffect.PROTECT: 3,
	Gen2MoveEffect.ENDURE: 3,
	0x67: 2,  # Quick Attack, Extreme Speed, Mach Punch
	Gen2MoveEffect.FORCE_SWITCH: 0,
	Gen2MoveEffect.COUNTER: 0,
	Gen2MoveEffect.MIRROR_COAT: 0,
}

## Vital Throw is slower than everything and says so in the move itself rather
## than through its effect, so it is the one move the table cannot answer for.
const VITAL_THROW: int = 0xE9


var data: GameData = null
var rng: RandomNumberGenerator = null
## The run's own divergences and difficulty. Set by [method create_parties], which
## also installs it, so the statics in the formula read the same set.
var rules: Gen2Rules = null

## Whether beating this opponent is worth [Gen2Experience]'s trainer 1.5x. A wild
## encounter, which is the default, never sets it.
var is_trainer_battle: bool = false

var in_battle_tower: bool = false
var is_link_battle: bool = false
## Yellow's `wUnknownSerialFlag_d499`, a COLOSSEUM2 cup's rules on the fight.
var gen1_stadium_cup: bool = false
## `IsGhostBattle`: nobody moves, the ball is dodged and every run succeeds.
var gen1_ghost: bool = false
var player_id: int = -1

## `wBattleType`, set by `loadvar VAR_BATTLETYPE` before `startbattle`.
var battle_type: int = BATTLETYPE_NORMAL

## `wSafariBaitFactor`, `wSafariEscapeFactor` and `wEnemyMonActualCatchRate`.
var safari_bait_factor: int = 0
var safari_escape_factor: int = 0
var safari_catch_rate: int = 0

## Earned player badges as source-order bits. Zero is the battle-safe default
## for wild fixtures and development matchups without a world save.
var player_badge_mask: int = 0

## `wNumFleeAttempts`. Every failed run raises the odds behind the next one, and
## choosing FIGHT clears it again, which is `BattleMenu_Fight`'s own `xor a`.
var flee_attempts: int = 0

## `wBattleWeather` and `wWeatherCount`: one of each for the battle rather than
## per side, and neither survives it.
var weather: int = Gen2Weather.NONE
var weather_turns: int = 0

## `wPlayerScreens`/`wEnemyScreens` and their counters. Field state, not Pokémon
## state: a switch clears none of it, so a Reflect outlives whoever put it up.
var screens: Dictionary = {PLAYER: Gen2Screens.NONE, ENEMY: Gen2Screens.NONE}
var light_screen_turns: Dictionary = {PLAYER: 0, ENEMY: 0}
var reflect_turns: Dictionary = {PLAYER: 0, ENEMY: 0}
var safeguard_turns: Dictionary = {PLAYER: 0, ENEMY: 0}

## `wTimeOfDay`, read by the three time-based heals alone: `MORN_F`/`DAY_F`/
## `NITE_F` as bit indices rather than shifted flags, which is what
## [Gen2WorldPalette] holds too, so the overworld's value is written here
## unmapped. A battle nobody told stands at midday.
var time_of_day: int = Gen2WorldPalette.TIME_DAY

## `GetWorldMapLocation`'s answer for the map this is being fought on, which
## `LevelUpHappinessMod` compares a Pokémon's caught location against. A battle
## nobody told is nowhere, and no Pokémon was caught there.
var landmark: int = LANDMARK_NONE

## `HandleEnemyMonFainted`'s `IsItemInBag EXP_ALL`; nothing past Generation 1.
var exp_all_in_bag: bool = false

## `wEnemyTrainerItem1` and `wEnemyTrainerItem2`, one copy for the whole battle
## and each removed as it is spent (`xor a; ld [de], a`). Empty for a wild battle
## and for a class carrying `NO_ITEM` twice.
var enemy_items: Array[int] = []

var enemy_trainer_class: int = 0  ## `wTrainerClass`, zero for a wild.
## `wAICount` and `wAILayer2Encouragement`, the `ExecuteEnemyMove`s since a
## faint replacement. Generation 1 alone reads either.
var gen1_ai_count: int = Gen1TrainerAI.COUNT_UNLOADED
var gen1_enemy_moves: int = 0

## `wPlayerUsedMoves`, oldest first: all the switch AI has to go on about what it
## is facing. `NewBattleMonStatus` clears it on every send-out, so it describes
## the Pokémon rather than the battle, and `UpdateUsedMoves` keeps four.
var player_used_moves: Array[int] = []

## `wBattleAnimParam`, the animation's input byte. Battle state rather than turn
## state: it sits outside the run `ClearBattleAnims` zeroes, and the five
## multi-hit effects alternate its low bit from whatever the last hit left.
var battle_anim_param: int = 0

## `wPlayerJustGotFrozen` and `wEnemyJustGotFrozen`: frozen during the turn now
## ending, which `HandleDefrost` refuses to thaw, so a freeze costs the turn it
## landed on. Cleared at the top of every turn, as `BattleTurn.loop` clears it.
var _just_got_frozen: Dictionary = {PLAYER: false, ENEMY: false}

## `wEnemyGoesFirst`, written once a turn by `DetermineMoveOrder`: [method order]'s
## answer kept rather than decided twice, and [method opponent_went_first] is the
## `wEnemyGoesFirst XOR hBattleTurn` the three commands asking are given.
var enemy_goes_first: bool = false

## Set once the player has run. The battle is over with no winner, which is the
## DRAW `wBattleResult` the cartridge writes.
var _fled: bool = false

## `wForcedSwitch`: Whirlwind or Roar in a wild battle blows a side out rather
## than switching anybody. `BattleTurn`'s `jr nz, .quit` ends it and the
## `SetBattleDraw` beside it is why [method winner] answers nobody.
var _forced_out: bool = false
var _forced_out_side: int = -1  ## Which side was blown out, for a screen that has to say who left.

## The half-run turn a question stopped, as [code]{"acting": Array, "actions":
## Dictionary, "index": int, "acted": bool}[/code], which its answer finishes.
var _pending_turn: Dictionary = {}

## The side owing a Baton Pass target, or -1. `ForcePickSwitchMonInBattle` cannot
## be backed out of, so everything else is refused until it is answered.
var _pending_baton_pass: int = -1
## `MimicEffect.letPlayerChooseMove`: the slot MIMIC was used from while the
## player picks one of the target's moves, empty otherwise.
var _pending_mimic: Dictionary = {}
## `OfferSwitch`'s pending question, the slot the enemy is about to send out or
## -1. SHIFT alone sets it, and the turn stands still until
## [method answer_switch_offer] closes it.
var _pending_switch_offer: int = -1
## `wOptions`' BATTLE_SHIFT bit, as the caller's own setting rather than a read
## of the options file: the engine is scene-free and takes its rules injected.
var battle_style_set: bool = false
## `CheckBattleScene`'s answer, injected the same way and read by `present` alone.
var battle_scene_on: bool = true

## Whether `AskUseNextPokemon` was answered for the faint standing. Asked once,
## a NO whose run fails falling through to `ForcePlayerMonChoice`.
var _use_next_answered: bool = false

## The side whose Pursuit already ran in front of the switch it answered, or -1.
## `PursuitSwitch` writes `CANNOT_MOVE` over that side's move and `CheckTurn`
## ends the turn on it, so the action it would have taken is spent.
var _pursuit_spent: int = -1
var _turn_begun: bool = false
## `wCriticalHit` as the last list left it, which only `criticaltext` and
## `GetFailureResultText` clear: Present's heal leaves one for the enemy's
## confusion, whose `CheckEnemyTurn` never zeroes it the way `HitConfusion` does.
var stale_critical: bool = false
## [method Gen2SaveBattleAdapter.first_slot_speed], an egg's in the first slot.
var first_slot_speed: int = -1
var _pursuing: bool = false

## `wEnemyHPAtTimeOfPlayerSwitch`: the opponent's HP when it last came in or
## the player's `SendOutMonText` last ran.
var enemy_hp_at_switch: int = 0

var parties: Dictionary = {}  ## The two sides, keyed by [constant PLAYER] and [constant ENEMY].

## `wBattleParticipantsIncludingFainted` as keys, `...NotFainted` as values: a
## faint clears only the value.
var _participants: Dictionary = {PLAYER: {}, ENEMY: {}}

## Which of the player's Pokemon have been charged `UpdateFaintedPlayerMon`'s
## happiness, by instance id: a faint is reported from a dozen places here and
## must cost once. A revive clears the entry.
var _faint_charged: Dictionary = {}
## `ModifyPikachuHappiness`'s battle callers, each by the party index it named,
## read by the world once the fight is over.
var party_log: Dictionary = {"grew": [], "faints": [], "x_items": [], "learned": []}

## The last direct damage each side took this action pair, which Counter and
## Mirror Coat read after the faster side has acted. Cleared each pair: the
## cartridge's `wCurDamage` is move-local, not a history.
var _last_damage_taken: Dictionary = {PLAYER: {}, ENEMY: {}}

## `wPlayerSelectedMove` and `wEnemySelectedMove`, which a switch or an item
## leaves standing and `HandleCounterMove` reads off the target.
var gen1_selected_moves: Dictionary = {PLAYER: 0, ENEMY: 0}

## `wDamage` outliving the move that wrote it. Generation 1's trapping moves are
## the one reader: `.MultiturnMoveCheck` jumps past the damage calculation, so a
## continuation deals the first hit's figure again.
var last_damage_dealt: int = 0

## `DoMove`'s own artefact: every effect command executed, in the order the read
## cycle reached it, skips and loop passes included. Collected only while
## `trace_commands` is on, which `tools/trace_battle_commands.gd` turns on so a
## fought turn can be diffed against the same trace taken off a real cartridge.
static var trace_commands: bool = false
var command_trace: Array[StringName] = []

## `wPlayerFutureSightCount/Damage` and the enemy pair. Keyed by the side that
## foresaw the attack, so switching either active Pokémon leaves it intact and
## the eventual target is whoever is opposite when the count reaches one.
var _future_sight: Dictionary = {
	PLAYER: {"count": 0, "damage": 0},
	ENEMY: {"count": 0, "damage": 0},
}

## `GotMoneyForWinningText` and `.SentToMomTexts`, which
## [method prize_money_split] picks between. The screen owns the words.
const PRIZE_KEPT_IT_ALL: StringName = &"kept_it_all"
const PRIZE_SENT_SOME_TO_MOM: StringName = &"sent_some_to_mom"
const PRIZE_SENT_HALF_TO_MOM: StringName = &"sent_half_to_mom"
const PRIZE_SENT_ALL_TO_MOM: StringName = &"sent_all_to_mom"
const PRIZE_MOM_LINES: Array[StringName] = [
	PRIZE_SENT_SOME_TO_MOM, PRIZE_SENT_HALF_TO_MOM, PRIZE_SENT_ALL_TO_MOM,
]

## `wPayDayMoney`, capped to its three-byte storage. Awarding it belongs to the
## world completion boundary; the move command only scatters the coins.
var pay_day_money: int = 0

## `wBattleReward`, `ComputeTrainerReward`'s base reward times the level of the
## last party member `ReadTrainerParty` loaded. A quarter of what a win pays:
## `.give_money` credits it four times over.
var battle_reward: int = 0

## `wAmuletCoin`. `CheckAmuletCoin` sets it at every player send-out and clears
## it nowhere, so one Amulet Coin doubles the reward and the Pay Day money for
## the rest of the battle whatever is holding it later.
var amulet_coin: bool = false

## `wEvolvableFlags`, cleared by `FindFirstAliveMonAndStartBattle` and set per
## party member that gained a level. `ExitBattle` hands it to `EvolveAfterBattle`
## on the overworld, so it is read at the completion boundary the way
## [member pay_day_money] is.
var _evolvable: Array[int] = []

## Moves waiting on [method learn_move] or [method decline_move], one queue per
## side, FIFO: a level that teaches two moves into a full six-move team asks
## about both, one at a time, in the order they were learned.
var _move_learn_queue: Dictionary = {PLAYER: [], ENEMY: []}

## Whoever is out on each side. Read through the party every time rather than
## kept in step with it: a switch changes who this is, and a copy that had to be
## updated is a copy that will one day not be.
var player: Gen2BattleMon:
	get:
		return party(PLAYER).active_mon()
var enemy: Gen2BattleMon:
	get:
		return party(ENEMY).active_mon()


static func create_parties(
	game_data: GameData,
	player_party: Gen2Party,
	enemy_party: Gen2Party,
	generator: RandomNumberGenerator,
	trainer_battle: bool = false,
	player_badges: int = 0,
	battle_rules: Gen2Rules = null
) -> Gen2Battle:
	if game_data == null or player_party == null or enemy_party == null:
		return null
	if player_party.is_wiped() or enemy_party.is_wiped():
		return null

	## `DoBattle.loop2` and `.findFirstAliveMonLoop`: the first fit member leads.
	player_party.active = player_party.first_healthy()
	var out := Gen2Battle.new()
	out.data = game_data
	out.parties = {PLAYER: player_party, ENEMY: enemy_party}
	out.rng = generator if generator != null else RandomNumberGenerator.new()
	out.is_trainer_battle = trainer_battle
	# The rules the fight is fought under, installed for its duration: the damage
	# formula and the experience curves are statics with no battle in hand.
	out.rules = battle_rules if battle_rules != null else Gen2Rules.active()
	Gen2Rules.install(out.rules)
	out.player_badge_mask = player_badges & 0xFFFF
	out._participants = {PLAYER: {player_party.active: true}, ENEMY: {enemy_party.active: true}}
	out._apply_player_badges()
	if out.is_gen1():
		out.mon(ENEMY).gen1_load_stats(0)
	out.enemy_hp_at_switch = out.mon(ENEMY).hp
	return out


## One Pokémon a side, which is what a wild encounter is.
static func create(
	game_data: GameData,
	player_mon: Gen2BattleMon,
	enemy_mon: Gen2BattleMon,
	generator: RandomNumberGenerator,
	battle_rules: Gen2Rules = null
) -> Gen2Battle:
	if player_mon == null or enemy_mon == null:
		return null
	return create_parties(
		game_data, Gen2Party.of(player_mon), Gen2Party.of(enemy_mon), generator,
		false, 0, battle_rules
	)


## What a side asks for with its turn.
static func use_move(slot: int) -> Dictionary:
	return {"type": ACTION_MOVE, "slot": slot}


func set_player_badges(mask: int) -> void:
	player_badge_mask = mask & 0xFFFF
	_apply_player_badges()


func _apply_player_badges() -> void:
	if parties.is_empty():
		return
	var current: Gen2BattleMon = mon(PLAYER)
	if current != null:
		current.set_badge_boosts(gen1_badge_byte() if is_gen1() else player_badge_mask)


## `wObtainedBadges`: Kanto's eight sit behind Johto's in the shared mask.
func gen1_badge_byte() -> int:
	return (player_badge_mask >> Gen2WorldState.KANTO_BADGE_FIRST) & 0xFF


static func switch_to(index: int) -> Dictionary:
	return {"type": ACTION_SWITCH, "index": index}


static func run_away() -> Dictionary:
	return {"type": ACTION_RUN}


static func use_item(item: int) -> Dictionary:
	return {"type": ACTION_ITEM, "item": item}


## `InitEnemyTrainer`: the class's `TRNATTR_ITEM1` and `TRNATTR_ITEM2`, then
## `IsGymLeader`'s party walk. [param rewarded] is false for the Battle Tower and
## a link partner, which reach no `ComputeTrainerReward`.
func init_enemy_trainer(trainer_class: int, rewarded: bool = true) -> void:
	enemy_items = []
	enemy_trainer_class = maxi(trainer_class, 0)
	if data == null or trainer_class <= 0:
		return
	var attributes: Dictionary = data.trainer_attributes(trainer_class)
	for key: String in ["item1", "item2"]:
		var item: int = int(attributes.get(key, 0))
		if item != 0:
			enemy_items.append(item)
	_compute_trainer_reward(int(attributes.get("base_reward", 0)) if rewarded else 0)
	_gain_gym_battle_happiness(trainer_class)


## `ReadTrainerParty.LastLoop` adds `wTrainerBaseMoney` into `wAmountMoneyWon`
## once a level with `AddBCD` two bytes wide, whose `.fill` stops at 9999.
const GEN1_REWARD_CEILING: int = 9999


## `ComputeTrainerReward`, which `ReadTrainerParty` runs once the whole party is
## in: `wCurPartyLevel` is still the last member's, so a reward is the class's
## base times the level of whoever the trainer sends out last rather than of
## whoever is strongest.
func _compute_trainer_reward(base_reward: int) -> void:
	battle_reward = 0
	if base_reward <= 0:
		return
	var mons: Array = party(ENEMY).mons
	if mons.is_empty():
		return
	var last: Gen2BattleMon = mons[mons.size() - 1]
	if last == null:
		return
	var product: int = base_reward * last.level
	if is_gen1():
		battle_reward = mini(product, GEN1_REWARD_CEILING)
		return
	battle_reward = product & 0xFFFF


## `InitEnemyTrainer`'s `.partyloop`, which runs on the frame the trainer's pic
## is placed rather than on the win: standing in front of a gym leader is what
## pays, and a fainted member is skipped by `ld a, [hli] / or [hl] / jr z`.
func _gain_gym_battle_happiness(trainer_class: int) -> void:
	if not (KANTO_GYM_LEADERS.has(trainer_class) or JOHTO_GYM_LEADERS.has(trainer_class)):
		return
	for member: Gen2BattleMon in party(PLAYER).mons:
		if member == null or member.is_fainted():
			continue
		member.happiness = Gen2WorldPartyHost.change_happiness(
			data, member.happiness, HAPPINESS_GYMBATTLE
		)


## Reports one faint. Every site that knows a battler has gone down goes through
## here rather than appending the event itself, because `UpdateFaintedPlayerMon`
## hangs off the same moment and the cartridge reaches it once.
func note_faint(side: int, events: Array, extra: Dictionary = {}) -> void:
	var event: Dictionary = {"type": FAINTED, "side": side}
	event.merge(extra, true)
	events.append(event)
	## `PursuitSwitch` answers its own knockout, clearing only a participant bit.
	if _pursuing:
		event["pursuit"] = true
		event["index"] = party(side).active
		return
	## Both `UpdateFaintedPlayerMon` and the enemy's faint end the survivor's loop.
	mon(opponent_of(side)).substatus &= ~Gen2Substatus.IN_LOOP
	_charge_faint_happiness(side)


## `UpdateFaintedPlayerMon`: the status zeroed, then HAPPINESS_BEATENBYSTRONGFOE
## against a foe thirty levels up or more and HAPPINESS_FAINTED otherwise.
func _charge_faint_happiness(side: int) -> void:
	if side != PLAYER:
		return
	var fallen: Gen2BattleMon = mon(PLAYER)
	if fallen == null or not fallen.is_fainted():
		return
	var key: int = fallen.get_instance_id()
	if _faint_charged.has(key):
		return
	_faint_charged[key] = true
	fallen.status = Gen2Status.NONE
	var foe: Gen2BattleMon = mon(ENEMY)
	(party_log["faints"] as Array).append({
		"index": party(PLAYER).active, "level": fallen.level,
		"foe_level": foe.level if foe != null else 0,
	})
	var kind: int = HAPPINESS_FAINTED
	if foe != null and foe.level >= fallen.level + 30:
		kind = HAPPINESS_BEATENBYSTRONGFOE
	fallen.happiness = Gen2WorldPartyHost.change_happiness(data, fallen.happiness, kind)


func party(side: int) -> Gen2Party:
	return parties[side]


func mon(side: int) -> Gen2BattleMon:
	return party(side).active_mon()


## The events whose routine runs `UpdateBattleHuds` before its line. Each carries
## both status bytes, which the panels print the way a bar reads `hp`.
const HUD_STATUS_EVENTS: Array[StringName] = [
	SENT_OUT, STATUS_INFLICTED, WOKE_UP, THAWED, CANNOT_MOVE, RESTED, WENT_TO_SLEEP,
	STAGES_CLEARED, RECOVERED_USING_ITEM, TRAINER_USED_ITEM,
]


func stamp_statuses(event: Dictionary) -> Dictionary:
	if HUD_STATUS_EVENTS.has(event["type"]):
		event["statuses"] = [mon(PLAYER).status, mon(ENEMY).status]
	return event


func opponent_of(side: int) -> int:
	return ENEMY if side == PLAYER else PLAYER


## Which Unown letter a Pokémon is, 1 being A, zero for anything else.
## `_GetFrontpic` reads `UnownPicPointers` by `wUnownLetter`, which
## `GetUnownLetter` fills from the same DVs the stats came from: a display value
## like the level in an event, so it travels with the send-out.
static func unown_form_of(battler: Gen2BattleMon) -> int:
	if battler == null or battler.species != Gen2Layout.UNOWN_SPECIES:
		return 0
	return Gen2Stats.unown_letter(battler.persistent_dvs())


## `BattleCommand_FreezeTarget`'s own tail, which writes the flag on the side it
## just froze so [method _tick_defrost] leaves that one alone this turn.
func mark_just_got_frozen(side: int) -> void:
	_just_got_frozen[side] = true


## Clears the damage that Counter and Mirror Coat are allowed to remember.
## Residual damage is deliberately not recorded: the cartridge's counter move
## reads the damage produced by the opponent's move, not end-of-turn status loss.
func reset_damage_taken() -> void:
	_last_damage_taken = {PLAYER: {}, ENEMY: {}}


## `BattleCommand_ApplyDamage.update_damage_taken`, an add-with-carry capped at
## $ffff rather than an assignment. Bide accumulates the same raw word.
func record_damage_taken(target: int, source: int, move_number: int, effect: int, amount: int) -> void:
	if amount <= 0 or target not in [PLAYER, ENEMY] or source not in [PLAYER, ENEMY]:
		return
	var previous: Dictionary = _last_damage_taken.get(target, {})
	var total: int = mini(int(previous.get("damage", 0)) + amount, 0xFFFF)
	_last_damage_taken[target] = {
		"damage": total,
		"source": source,
		"move": move_number,
		"effect": effect,
	}
	var target_mon: Gen2BattleMon = mon(target)
	if Gen2Substatus.has(target_mon.substatus, Gen2Substatus.BIDE) and not is_gen1():
		target_mon.bide_damage = mini(target_mon.bide_damage + amount, 0xFFFF)


func last_damage_taken(side: int) -> Dictionary:
	return _last_damage_taken.get(side, {})


func future_sight_pending(side: int) -> bool:
	return int((_future_sight.get(side, {}) as Dictionary).get("count", 0)) > 0


func schedule_future_sight(side: int, damage: int) -> bool:
	if side not in [PLAYER, ENEMY] or future_sight_pending(side):
		return false
	_future_sight[side] = {"count": 4, "damage": clampi(damage, 0, 0xFFFF)}
	return true


## `BattleCommand_CheckFutureSight`'s own read: the count still standing, and on
## the turn it is one, the stored word taken and the count cleared.
func future_sight_count(side: int) -> int:
	return int((_future_sight.get(side, {}) as Dictionary).get("count", 0))


func take_future_sight_damage(side: int) -> int:
	var pending: Dictionary = _future_sight[side]
	pending["count"] = 0
	return int(pending.get("damage", 0))


## A battle is lost when a whole party is down, not when the Pokémon that is out
## has fainted. One of those is a defeat and the other is a Pokémon to replace.
func is_over() -> bool:
	return _fled or _forced_out or party(PLAYER).is_wiped() or party(ENEMY).is_wiped()


## `wForcedSwitch` and `SetBattleDraw`: a move, `TryEnemyFlee` or the Safari Zone
## taking [param side] out of a wild battle, the DRAW a run is.
func force_out(side: int) -> void:
	if is_over():
		return
	_forced_out = true
	_forced_out_side = side


## Which side [method force_out] took out, or -1.
func forced_out_side() -> int:
	return _forced_out_side


## Whether [method force_out] ended this battle: the same DRAW as a run, with a
## line of its own rather than `BattleText_GotAwaySafely`.
func was_forced_out() -> bool:
	return _forced_out


## Whether the player ran, one of the endings [method is_draw] answers.
func has_fled() -> bool:
	return _fled


## `wBattleResult`'s DRAW, which `reloadmapafterbattle` does not white out on.
## Generation 2's `.LostLinkBattle` writes it for two parties out at once.
func is_draw() -> bool:
	return _fled or _forced_out or (is_link_battle and not is_gen1() \
		and party(PLAYER).is_wiped() and party(ENEMY).is_wiped())


## `BattleEnd_HandleRoamMons`: a roamer not caught or beaten moves on, and any
## other battle moves them when `BattleRandom`'s low nibble is zero. Ask once.
func roamers_move_on(caught: bool) -> bool:
	if is_gen1():
		return false
	if battle_type == BATTLETYPE_ROAMING:
		return not caught and winner() != PLAYER
	return rng.randi_range(0, 255) & 0x0F == 0


## `TryToRunAwayFromBattle`, resolved without spending anything: `fled`,
## `failed` for the short roll, which costs the turn, or `blocked`, which does
## not, `.cant_escape` writing no `BATTLEPLAYERACTION_USEITEM`.
## [param runner_speed] is `wPartyMon1Speed` from `AskUseNextPokemon`.
func run_odds(runner_speed: int = -1) -> Dictionary:
	## `TryRunningFromBattle`'s first test.
	if gen1_ghost:
		return {"outcome": &"fled", "how": &"ghost"}
	if battle_type in ALWAYS_ESCAPES:
		return {"outcome": &"fled", "how": &"battle_type", "battle_type": battle_type}
	if battle_type in NEVER_ESCAPES:
		return {"outcome": &"blocked", "reason": &"battle_type", "battle_type": battle_type}
	## `.can_escape` on `wLinkMode`: a forfeit, a loss unless both sides do.
	if is_link_battle:
		return {"outcome": &"fled", "how": &"forfeit"}
	if is_trainer_battle:
		return {"outcome": &"blocked", "reason": &"trainer"}

	var runner: Gen2BattleMon = mon(PLAYER)
	var chaser: Gen2BattleMon = mon(ENEMY)

	# Both ahead of the Smoke Ball, which is the source's order, so a trapped
	# holder does not walk out on the item either. The flag is read off whoever
	# is doing the trapping and the counter off whoever is bound.
	if Gen2Substatus.has(chaser.substatus, Gen2Substatus.CANT_RUN):
		return {"outcome": &"blocked", "reason": &"cant_run"}
	if runner.trapped_turns > 0:
		return {"outcome": &"blocked", "reason": &"trapped", "move": runner.trapping_move}

	if _held_effect(runner) == Gen2HeldItem.ESCAPE:
		return {"outcome": &"fled", "how": &"item", "item": runner.item}

	# wNumFleeAttempts rises before the arithmetic reads it, so the first attempt
	# counts as one and the bonus loop below runs one fewer time than that.
	var attempts: int = flee_attempts + 1
	var speed: int = runner.stat("speed") if runner_speed < 0 else runner_speed
	var enemy_speed: int = chaser.stat("speed")
	if speed >= enemy_speed:
		return {"outcome": &"fled", "how": &"speed", "attempts": attempts}

	# The divisor is one byte of enemy_speed >> 2, so a fast enough enemy wraps
	# it to zero and the run simply succeeds. That is the cartridge's own
	# `and a; jr z, .can_escape`, not a guard against dividing by zero.
	var divisor: int = (enemy_speed >> FLEE_ENEMY_SPEED_SHIFT) & 0xFF
	if divisor == 0:
		return {"outcome": &"fled", "how": &"speed", "attempts": attempts}

	# The dividend is the low sixteen bits of the product, which is what taking
	# hProduct + 2 and + 3 leaves behind.
	var odds: int = ((speed * FLEE_SPEED_MULTIPLIER) & 0xFFFF) / divisor
	if odds > 0xFF:
		return {"outcome": &"fled", "how": &"odds", "odds": odds, "attempts": attempts}
	for _bonus: int in attempts - 1:
		odds += FLEE_ATTEMPT_BONUS
		if odds > 0xFF:
			return {"outcome": &"fled", "how": &"odds", "odds": odds, "attempts": attempts}
	return {
		"outcome": &"roll", "odds": odds, "attempts": attempts,
		"range": FLEE_ODDS_RANGE,
	}


## `ItemUseBait` and `ItemUseRock`: the other side's factor is zeroed and the
## chosen one grows by `.randomLoop`'s own 1 to 5.
func throw_bait_or_rock(bait: bool, rolls: Callable) -> void:
	if bait:
		safari_catch_rate >>= 1
		safari_escape_factor = 0
	else:
		safari_catch_rate = mini(safari_catch_rate * 2, 0xFF)
		safari_bait_factor = 0
	var grown: int = int(rolls.call()) & Gen1Layout.SAFARI_FACTOR_MASK
	while grown >= Gen1Layout.SAFARI_FACTOR_LIMIT:
		grown = int(rolls.call()) & Gen1Layout.SAFARI_FACTOR_MASK
	grown += 1
	if bait:
		safari_bait_factor = mini(safari_bait_factor + grown, 0xFF)
	else:
		safari_escape_factor = mini(safari_escape_factor + grown, 0xFF)


## `PrintSafariZoneBattleText`: the bait counter first, then the escape one,
## whose last turn puts `wMonHCatchRate` back.
func safari_battle_text(base_catch_rate: int) -> String:
	if safari_bait_factor > 0:
		safari_bait_factor -= 1
		return SAFARI_EATING_TEXT
	if safari_escape_factor <= 0:
		return ""
	safari_escape_factor -= 1
	if safari_escape_factor == 0:
		safari_catch_rate = base_catch_rate
	return SAFARI_ANGRY_TEXT


## `.notOutOfSafariBalls`' roll: twice the low byte of the enemy's Speed,
## quartered eating and doubled angry, a carry out of it taking the enemy away.
func safari_enemy_runs(rolls: Callable) -> bool:
	var doubled: int = (mon(ENEMY).stat("speed") & 0xFF) * 2
	if doubled > 0xFF:
		return true
	if safari_bait_factor != 0:
		doubled >>= 2
	if safari_escape_factor != 0:
		doubled = mini(doubled * 2, 0xFF)
	return int(rolls.call()) < doubled


const SAFARI_EATING_TEXT: String = "eating"
const SAFARI_ANGRY_TEXT: String = "angry"


## The held effect of whatever [param battler] is carrying, or zero. The item's
## own `effect` field is `ItemAttributes`' held effect byte.
func _held_effect(battler: Gen2BattleMon) -> int:
	if battler == null:
		return Gen2HeldItem.NONE
	return Gen2HeldItem.effect_of(data, battler.item)


## Who won, or null for a DRAW or a battle not over. Both faint handlers reach
## `LostBattle` once the player's party is out, whoever else went down with it.
func winner() -> Variant:
	if not is_over() or is_draw():
		return null
	return ENEMY if party(PLAYER).is_wiped() else PLAYER


## `wEvolvableFlags` read back: the party indices that gained a level in this
## battle, in party order. Battle-party indices, so a save carrying an egg maps
## them through [method Gen2SaveBattleAdapter.save_party_index].
func evolvable_indices() -> Array[int]:
	return _evolvable.duplicate()


## Whether a side is waiting for somebody to be sent out: the Pokémon that was
## out has fainted and there is still a party behind it. Nothing else can happen
## on either side until it is answered, which is the cartridge's order too.
## A battle already over owes nobody: `wBattleEnded` after a double faint or a run.
func must_replace(side: int) -> bool:
	if is_over():
		return false
	var current: Gen2Party = party(side)
	return current.active_mon().is_fainted() and not current.is_wiped()


func awaiting_replacement() -> bool:
	return must_replace(PLAYER) or must_replace(ENEMY)


## `TryToRunAwayFromBattle` spent rather than only weighed: the odds rolled,
## `wNumFleeAttempts` moved and the event appended. Answers the outcome, since
## every caller has a different tail behind it.
func _attempt_run(events: Array, runner_speed: int = -1) -> StringName:
	var attempt: Dictionary = run_odds(runner_speed)
	var outcome: StringName = StringName(attempt.get("outcome", &"roll"))
	if outcome == &"roll":
		# BattleRandom against the accumulated odds. The comparison is
		# `cp b; jr nc`, so the odds getting away on a tie is the source's.
		flee_attempts += 1
		var rolled: int = rng.randi_range(0, FLEE_ODDS_RANGE - 1)
		attempt["roll"] = rolled
		outcome = &"fled" if int(attempt["odds"]) >= rolled else &"failed"
		attempt["how"] = &"roll"
	elif outcome != &"blocked":
		flee_attempts += 1
	match outcome:
		&"fled":
			_fled = true
			events.append(_run_event(FLED, attempt))
		&"blocked":
			events.append(_run_event(RUN_BLOCKED, attempt))
		_:
			events.append(_run_event(RUN_FAILED, attempt))
	return outcome


## Whether `AskUseNextPokemon` has a question: the player owes a replacement and
## this is a wild battle. A trainer battle returns at once ("that decision is
## made for us"), and the question is asked once per faint.
func asking_use_next() -> bool:
	return must_replace(PLAYER) and not is_trainer_battle and not _use_next_answered


## `AskUseNextPokemon`'s yes/no. YES leaves `ForcePlayerMonChoice` standing; NO is
## `TryToRunAwayFromBattle`, which ends the battle or falls into that same forced
## choice. The Speed handed to the run is `wPartyMon1Speed`, the first slot's:
## the source reads the party here because the battle copy is a corpse.
func answer_use_next(use_next: bool) -> Array:
	if not asking_use_next():
		return []
	_use_next_answered = true
	if use_next:
		return []
	var events: Array = []
	if _attempt_run(events, _first_party_speed()) == &"fled":
		events.append({"type": OVER, "winner": winner(), "fled": true})
	return events


## `wPartyMon1Speed`: the stored stat, with neither a badge boost nor a stage on
## it, since neither is ever written back into the party structure.
func _first_party_speed() -> int:
	if first_slot_speed >= 0:
		return first_slot_speed
	var first: Gen2BattleMon = party(PLAYER).at(0)
	return 0 if first == null else int(first.stats.get("speed", 0))


## Who [param side] sends out to replace a faint: the enemy's is
## `FindMonInOTPartyToSwitchIntoBattle`'s type-matchup pick, and the player's is
## asked rather than answered, so this is the fallback for a caller with none.
func replacement_target(side: int) -> int:
	if side == ENEMY:
		return Gen2AISwitch.pick_target(self)
	return party(side).first_healthy()


## `HandlePlayerMonFaint`'s replacement tail. [param index] is the player's row
## out of `ForcePlayerMonChoice`, refused the way the party menu refuses. The
## order is `DoubleSwitch`'s: the player enters first and the AI scores its pick
## against that. Only a trainer replacing on its own reaches `EnemySwitch`.
func replace_fallen(index: int = -1) -> Array:
	var events: Array = []
	if is_over() or _pending_switch_offer >= 0 or _pending_baton_pass >= 0 \
		or not _pending_mimic.is_empty():
		return events

	if must_replace(PLAYER):
		if not party(PLAYER).can_send_out(index):
			return events
		var doubled: bool = must_replace(ENEMY)
		events.append_array(send_out(PLAYER, index))
		if doubled:
			_enemy_entrance(events, false)
		return events

	if must_replace(ENEMY):
		_enemy_entrance(events, should_offer_switch())
	return events


## `EnemyPartyMonEntrance`: `EnemySwitch_SetMode` when the replacement walks in,
## `EnemySwitch` when SHIFT makes it an offer, closed by
## [method answer_switch_offer] like a mid-turn switch's.
func _enemy_entrance(events: Array, offer: bool) -> void:
	var target: int = replacement_target(ENEMY)
	if target < 0:
		return
	if not offer:
		events.append_array(send_out(ENEMY, target))
		return
	_pending_switch_offer = target
	events.append({
		"type": SWITCH_OFFERED, "side": PLAYER, "index": target,
		"species": party(ENEMY).at(target).species,
	})


## `CheckWhetherToAskSwitch`: in SHIFT mode a trainer replacing a fainted
## Pokémon offers the player a switch, given somebody else to send, SET off and
## the player's own Pokémon standing. A wild has no trainer to switch.
func should_offer_switch() -> bool:
	return is_trainer_battle and not battle_style_set and not in_battle_tower \
		and not is_link_battle \
		and party(PLAYER).healthy_count() > 1 and not mon(PLAYER).is_fainted()


## The party slot the enemy is about to send out while the player is being asked
## whether to switch as well, or -1. `OfferSwitch` asks before that Pokémon
## appears, which is why the answer arrives with the enemy still on its way in.
func awaiting_switch_offer() -> int:
	return _pending_switch_offer


## `OfferSwitch`'s yes/no. [param index] below zero is the source's carry, the
## player staying; anything else is the player switching too, which
## `EnemySwitch` reaches by falling into `PlayerSwitch`. A slot the party would
## refuse leaves the question standing.
func answer_switch_offer(index: int = -1) -> Array:
	if _pending_switch_offer < 0:
		return []
	if index >= 0 and not party(PLAYER).can_send_out(index):
		return []
	var enemy_index: int = _pending_switch_offer
	_pending_switch_offer = -1
	# Only [method replace_fallen] raises one, so no turn stands behind it.
	# `EnemySwitch` runs `PlayerSwitch` before the enemy's reset and Spikes.
	var events: Array = send_out(ENEMY, enemy_index, ENTRANCE_SWITCH, index < 0)
	if index >= 0:
		events.append_array(send_out(PLAYER, index))
		_participants[PLAYER] = {party(PLAYER).active: true}
		_spikes_damage(ENEMY, events)
	return events


## Which side owes a Baton Pass target, or -1: [method must_replace]'s shape,
## except that this one stops a turn part way rather than between two.
func awaiting_baton_pass() -> int:
	return _pending_baton_pass


## Answers a pending Baton Pass by sending [param index] out and finishing the
## turn behind it. An index the party would refuse leaves the question standing,
## as `ForcePickSwitchMonInBattle` redisplays its list.
func pass_to(index: int) -> Array:
	var side: int = _pending_baton_pass
	if side < 0 or not party(side).can_send_out(index):
		return []

	var events: Array = []
	_pending_baton_pass = -1
	events.append_array(baton_pass_send_out(side, index))
	return _run_turn(events)


## Stops the turn and asks [param side] for a Baton Pass target.
## [method Gen2EffectCommands._baton_pass] is the only caller.
func request_baton_pass(side: int) -> void:
	_pending_baton_pass = side


func request_mimic(side: int, slot: int) -> void:
	_pending_mimic = {"side": side, "slot": slot}


func awaiting_mimic() -> int:
	return int(_pending_mimic.get("side", -1))


## `wEnemyMonMoves` as the list `MoveSelectionMenu` draws for MIMIC: the target's
## slots, empty ones included, so the cursor's row is the cartridge's index.
func mimic_choices() -> Array:
	if _pending_mimic.is_empty():
		return []
	return mon(opponent_of(int(_pending_mimic["side"]))).moves.duplicate()


## Answers a pending MIMIC with the target's slot [param choice] and finishes
## the turn behind it; the animation and the line play once the choice is made.
func answer_mimic(choice: int) -> Array:
	if _pending_mimic.is_empty():
		return []
	var side: int = int(_pending_mimic["side"])
	var slot: int = int(_pending_mimic["slot"])
	var copied: Array = mimic_choices()
	if choice < 0 or choice >= copied.size() or int(copied[choice]) == 0:
		return []
	_pending_mimic = {}
	var events: Array = []
	var turn: Gen2Turn = Gen2Turn.create(
		self, side, slot, Gen2MoveEffect.MIMIC_MOVE, data.move(Gen2MoveEffect.MIMIC_MOVE), events
	)
	Gen2EffectCommands.gen1_mimic_learn(turn, slot, int(copied[choice]))
	return _run_turn(events)


## `FindMonInOTPartyToSwitchIntoBattle`, reached because Baton Pass zeroes
## `wEnemySwitchMonIndex` rather than naming anybody:
## [method replacement_target]'s pick, without the question of whether to switch,
## which the move has already answered.
func baton_pass_target(side: int) -> int:
	return replacement_target(side)


## `PassedBattleMonEntrance` and the enemy's `EnemySwitch_SetMode`: an entrance
## that keeps what it is handed, neither calling `NewBattleMonStatus` nor
## resetting the stages, which is the whole difference from [method send_out].
## The Pokémon walking back to its ball still loses everything.
func baton_pass_send_out(side: int, index: int) -> Array:
	var passed: Dictionary = mon(side).capture_passed_state()
	var events: Array = send_out(side, index, ENTRANCE_BATON_PASS)
	if events.is_empty():
		return events
	mon(side).apply_passed_state(passed)
	_reset_baton_pass_status(side)
	# Both entrances end on `ApplyStatLevelMultiplierOnAllStats` alone.
	mon(side).hold_stats(Gen2BattleMon.HELD_STAGED)
	return events


## `ResetBatonPassStatus`: the five things a pass does not carry. Nightmare is
## easy to get backwards, the check running after the entrance, so the sleep it
## reads is the *arriving* Pokémon's. Attraction and the wrap counters clear on
## both sides, whoever was loved or bound having left the field.
func _reset_baton_pass_status(side: int) -> void:
	var arriving: Gen2BattleMon = mon(side)
	if not Gen2Status.is_asleep(arriving.status):
		arriving.substatus &= ~Gen2Substatus.NIGHTMARE

	arriving.disabled_slot = -1
	arriving.disable_turns = 0

	mon(PLAYER).substatus &= ~Gen2Substatus.ATTRACTED
	mon(ENEMY).substatus &= ~Gen2Substatus.ATTRACTED

	arriving.substatus &= ~(Gen2Substatus.ENCORED | Gen2Substatus.TRANSFORMED)
	arriving.encored_slot = -1
	arriving.encore_turns = 0

	arriving.last_move_used = 0

	for each: int in [PLAYER, ENEMY]:
		mon(each).trapped_turns = 0
		mon(each).trapping_move = 0


## A move waiting on [method learn_move] or [method decline_move]: every slot was
## full when a level taught a new one, [method must_replace]'s shape again.
func must_learn_move(side: int) -> bool:
	return not (_move_learn_queue.get(side, []) as Array).is_empty()


func awaiting_move_learn() -> bool:
	return must_learn_move(PLAYER) or must_learn_move(ENEMY)


## The offer waiting on [param side], or empty. [code]species[/code],
## [code]index[/code], [code]move[/code] and [code]level[/code] say "your FOO
## wants to learn BAR" without reading the Pokémon back.
func pending_learn(side: int) -> Dictionary:
	var queue: Array = _move_learn_queue.get(side, [])
	return queue[0] if not queue.is_empty() else {}


## Answers a pending offer by giving up [param forget_slot]. An HM slot is refused
## as `ForgetMove`'s `.hmmove` branch refuses it, and either refusal leaves the
## offer standing.
func learn_move(side: int, forget_slot: int) -> Array:
	if not must_learn_move(side):
		return []

	var offer: Dictionary = (_move_learn_queue[side] as Array)[0]
	var index: int = int(offer["index"])
	var learner: Gen2BattleMon = party(side).at(index)
	if learner == null or forget_slot < 0 or forget_slot >= learner.persistent_moves().size():
		return []

	var forgot: int = learner.persistent_move(forget_slot)
	if Gen2MoveForget.is_hm_move(forgot, data.generation if data != null else RomRegistry.GEN2):
		return []
	if not is_gen1():
		_clear_disable_naming(party(side).active_mon(), forgot)
	var replaced: Array = [false]
	learner.with_own_record(func() -> void:
		replaced[0] = learner.replace_move(forget_slot, int(offer["move"]))
	)
	if not bool(replaced[0]):
		return []
	_copy_learned_moves(side, learner, index)
	(_move_learn_queue[side] as Array).pop_front()
	if side == PLAYER:
		(party_log["learned"] as Array).append({"index": index, "move": int(offer["move"])})

	return [{
		"type": MOVE_FORGOTTEN, "side": side, "index": index,
		"species": learner.species, "name": learner.display_name(), "forgot": forgot, "learned": int(offer["move"]), "slot": forget_slot,
	}]


## `LearnMove`'s `wDisabledMove` test, which names the Pokemon out whichever
## party member forgot: a move number, so a benched learner can free it too.
static func _clear_disable_naming(out: Gen2BattleMon, forgot: int) -> void:
	if out == null or out.disabled_slot < 0 or out.disabled_slot >= out.moves.size():
		return
	if int(out.moves[out.disabled_slot]) == forgot:
		out.disabled_slot = -1
		out.disable_turns = 0


## `LearnMove`'s copy into the Pokemon out, skipped under Generation 2's Transform.
func _copy_learned_moves(side: int, learner: Gen2BattleMon, index: int) -> void:
	if index != party(side).active:
		return
	if not is_gen1() and Gen2Substatus.has(learner.substatus, Gen2Substatus.TRANSFORMED):
		return
	learner.adopt_persistent_moves()


## Answers a pending offer by refusing it: the Pokémon keeps its four moves and
## never learns the fifth.
func decline_move(side: int) -> Array:
	if not must_learn_move(side):
		return []

	var offer: Dictionary = (_move_learn_queue[side] as Array).pop_front()
	return [{
		"type": MOVE_DECLINED, "side": side, "index": int(offer["index"]),
		"species": int(offer["species"]), "name": String(offer.get("name", "")), "move": int(offer["move"]),
	}]


## Sends a side's [param index] out, as a replacement or between turns, with one
## event or none: an impossible switch is refused. [param entrance] is how it
## comes in; a drag prints `DraggedOutText` between `ForceEnemySwitch` and
## `SpikesDamage`, and a Baton Pass keeps the counter-move words.
func send_out(side: int, index: int, entrance: int = ENTRANCE_SWITCH, spikes: bool = true) -> Array:
	var events: Array = []
	if is_over():
		return events

	var current: Gen2Party = party(side)
	if not current.can_send_out(index):
		return events
	var withdrawing: bool = not current.active_mon().is_fainted()
	if withdrawing:
		_recall(side, entrance, events)
	if side == PLAYER and current.active_mon() != null:
		current.active_mon().clear_badge_boosts()
	if not current.send_out(index):
		return events
	if side == PLAYER:
		_apply_player_badges()
	elif is_gen1():
		current.active_mon().gen1_load_stats(0)
	if is_gen1():
		# `wPlayerBattleStatus3` goes with the Pokemon that held it.
		screens[side] &= ~(Gen2Screens.REFLECT | Gen2Screens.LIGHT_SCREEN)
		# `EnemySendOutFirstMon`'s `wAICount` reset, and `HandleEnemyMonFainted`'s
		# `wAILayer2Encouragement` one, which an `AISwitchIfEnoughMons` skips.
		gen1_ai_count = Gen1TrainerAI.COUNT_UNLOADED
		if not withdrawing:
			gen1_enemy_moves = 0
	_entrance_resets(side, entrance)
	_hold_entrance_stats(side)
	# The enemy's pass still reaches `ShowBattleTextEnemySentOut`.
	var quiet: bool = entrance == ENTRANCE_DRAGGED \
		or (side == PLAYER and entrance == ENTRANCE_BATON_PASS)
	events.append(stamp_statuses({
		"type": SENT_OUT, "side": side, "index": index,
		"species": current.active_mon().species, "level": current.active_mon().level,
		"name": current.active_mon().display_name(),
		"hp": current.active_mon().hp, "max_hp": current.active_mon().max_hp(),
		"unown_form": unown_form_of(current.active_mon()),
		## `BattleCheckPlayerShininess`/`BattleCheckEnemyShininess`, the reading
		## `CGB_BattleColors` and [method entrance_events] share.
		"shiny": Gen2Stats.is_shiny(current.active_mon().dvs),
		"gender": current.active_mon().gender(),
		"quiet": quiet,
		"line": SEND_OUT_GO if quiet else send_out_line(side),
	}))
	(_participants[side] as Dictionary)[index] = true
	# `ResetBattleParticipants` behind every enemy entrance.
	if side == ENEMY:
		_participants[PLAYER] = {party(PLAYER).active: true}
	# `SendOutPlayerMon` and `ShowSetEnemyMonAndSendOutAnimation` both run their
	# animation after the line that announced them, and `ForceEnemySwitch` runs
	# it before `DraggedOutText`.
	events.append_array(entrance_events(side))
	events.append({"type": HUD_DRAWN, "side": side})
	if entrance == ENTRANCE_DRAGGED:
		events.append({"type": DRAGGED_OUT, "side": opponent_of(side), "target": side})
	if spikes:
		_spikes_damage(side, events)
	return events


## `InitBattleMon`'s status then badges; `LoadEnemyMon`'s no status at all.
func _hold_entrance_stats(side: int) -> void:
	var entering: Gen2BattleMon = mon(side)
	if side == PLAYER:
		entering.hold_stats(Gen2BattleMon.HELD_ENTRANCE)
		return
	enemy_hp_at_switch = entering.hp
	if not is_link_battle and not in_battle_tower:
		entering.hold_stats(Gen2BattleMon.HELD_STAGED)


## What every entrance clears on the field around the Pokémon coming in.
func _entrance_resets(side: int, entrance: int) -> void:
	var passed: bool = entrance == ENTRANCE_BATON_PASS
	# A pass reaches no `NewBattleMonStatus`, so the opponent's Mean Look holds.
	_clear_trapping(opponent_of(side) if passed else -1)
	# Both counter-move words and `BreakAttraction`'s love, a pass included.
	for each: int in [PLAYER, ENEMY]:
		mon(each).last_counter_move = 0
		mon(each).substatus &= ~Gen2Substatus.ATTRACTED
	if side != PLAYER:
		return
	# `NewBattleMonStatus`'s used-move list, which a pass never reaches.
	if not passed:
		player_used_moves = []
	_use_next_answered = false


## `SendOutPlayerMon` and `ShowSetEnemyMonAndSendOutAnimation`:
## `ANIM_SEND_OUT_MON`, a second pass for a shiny, and the cry
## `CheckFaintedFrzSlp` allows. [param ball] is false for `BattleStartMessage`'s
## wild branch, the one entrance with no ball in it.
func entrance_events(side: int, ball: bool = true) -> Array:
	var entering: Gen2BattleMon = mon(side)
	if entering == null:
		return []
	if side == PLAYER:
		_check_amulet_coin()
	var enemy_turn: bool = side == ENEMY
	var out: Array = []
	if ball:
		out.append(_send_out_animation(enemy_turn, SEND_OUT_ANIM_NORMAL))
	# `BattleCheckPlayerShininess`/`BattleCheckEnemyShininess`, which read the
	# live DVs: a Transform has already copied the target's over them.
	if Gen2Stats.is_shiny(entering.dvs):
		out.append(_send_out_animation(enemy_turn, SEND_OUT_ANIM_SHINY))
	# `CheckFaintedFrzSlp`: no cry from a fainted, frozen or sleeping Pokemon.
	# Crystal's alone: pokegold's `SendOutPlayerMon` and
	# `ShowSetEnemyMonAndSendOutAnimation` both reach `PlayStereoCry` with no
	# test in front of it, the same place their own pic animation is missing.
	if Gen2WorldState.is_crystal_profile(data) and (entering.is_fainted() \
			or (entering.status & (Gen2Status.FREEZE | Gen2Status.SLEEP_MASK)) != 0):
		return out
	out.append(cry_event(side, entering))
	return out


## Yellow's `SendOutMon.starterPikachu`: `PikachuCry37` while it sleeps.
const PIKACHU_CLIP_SENT_OUT: int = 10
const PIKACHU_CLIP_SENT_OUT_ASLEEP: int = 36
const PIKACHU_CLIP_FAINTED: int = 3


func cry_event(side: int, battler: Gen2BattleMon, clip: int = -1) -> Dictionary:
	var event: Dictionary = {"type": CRY, "side": side, "species": battler.species}
	if battler.starter_pikachu:
		if clip < 0:
			clip = PIKACHU_CLIP_SENT_OUT_ASLEEP \
				if (battler.status & Gen2Status.SLEEP_MASK) != 0 else PIKACHU_CLIP_SENT_OUT
		event["pikachu_clip"] = clip
	return event


## `CheckAmuletCoin`, run by `SendOutPlayerMon` and so by the opening entrance
## too. It only ever writes a one, which is why the flag is sticky.
func _check_amulet_coin() -> void:
	if amulet_coin or data == null:
		return
	var entering: Gen2BattleMon = mon(PLAYER)
	if entering == null:
		return
	if Gen2HeldItem.effect_of(data, entering.item) == Gen2HeldItem.AMULET_COIN:
		amulet_coin = true


## `.DoubleReward` and `CheckPayDay`'s copy of it: a three-byte shift that
## saturates rather than wrapping.
static func double_reward(amount: int) -> int:
	return mini(amount * 2, 0xFFFFFF)


## `BattleWon.give_money`. [param reward] is a quarter of the prize: the Amulet
## Coin doubles it, four quarters go out one at a time, and `.DoubleReward` puts
## the total back for the line. Returns the two credits, the figure and the line.
static func prize_money_split(
	reward: int, amulet: bool, mom_flags: int, moms_money: int, max_money: int
) -> Dictionary:
	var quarter: int = double_reward(reward) if amulet else reward
	## `.CheckMaxedOutMomMoney`: a full account sends her nothing and says
	## nothing, whatever the savings bits are.
	var saving: int = mom_flags & Gen2WorldScriptRunner.MOM_SAVING_MONEY_MASK
	var to_mom: int = 0
	if moms_money < max_money:
		## `cp (1 << SOME) | (1 << HALF)` then `inc a`: both bits together mean
		## all four quarters, which is why the count is not the mask.
		to_mom = 4 if saving == 3 else mini(saving, 4)
	var shown: int = double_reward(double_reward(quarter))
	var line: StringName = PRIZE_KEPT_IT_ALL
	if to_mom > 0 and saving > 0:
		## `dec a` indexes `.SentToMomTexts`, three entries long. A savings mask
		## of 4 would read past it; no script writes one.
		line = PRIZE_MOM_LINES[mini(saving, 3) - 1]
	return {
		"wallet": quarter * (4 - to_mom),
		"mom": quarter * to_mom,
		"shown": shown,
		"line": line,
	}


## `Call_PlayBattleAnim` rather than `PlayFXAnimID`: `WaitBGMap` in place of the
## three-frame delay, which is what `called` says.
func _send_out_animation(enemy_turn: bool, param: int) -> Dictionary:
	return {
		"type": ANIMATION,
		"index": ANIM_SEND_OUT_MON,
		"param": param,
		"after_anim": 0,
		"enemy_turn": enemy_turn,
		# `SendOutPlayerMon` clears `wTypeModifier` on its way past; nothing in a
		# send-out reads it, since only a damage after-anim has a hit sound.
		"effectiveness": 0,
		"restore_user_pic": false,
		"called": true,
	}


## `SendOutMonText`: one of four lines off the remaining HP times 25 over the
## top quarter of the maximum, an eight-bit divisor. A maximum below four leaves
## it zero, `docs/bugs_and_glitches.md`'s freeze; here that is the first line.
func send_out_line(side: int) -> int:
	if side != PLAYER:
		return SEND_OUT_GO
	var foe: Gen2BattleMon = mon(opponent_of(side))
	if foe == null or foe.hp <= 0:
		return SEND_OUT_GO
	enemy_hp_at_switch = foe.hp
	var percent: int = _quarter_percent(foe.hp, foe)
	if percent >= 70:
		return SEND_OUT_GO
	if percent >= 40:
		return SEND_OUT_DO_IT
	if percent >= 10:
		return SEND_OUT_GO_FOR_IT
	return SEND_OUT_FOES_WEAK


## `WithdrawMonText`: the HP lost since [member enemy_hp_at_switch], a
## sixteen-bit `sub`/`sbc` that wraps when the opponent healed.
func withdraw_line() -> int:
	var foe: Gen2BattleMon = mon(ENEMY)
	if foe == null:
		return WITHDRAW_ENOUGH
	var percent: int = _quarter_percent((enemy_hp_at_switch - foe.hp) & 0xFFFF, foe)
	if percent == 0:
		return WITHDRAW_ENOUGH
	if percent < 30:
		return WITHDRAW_COME_BACK
	if percent < 70:
		return WITHDRAW_OK
	return WITHDRAW_GOOD


## `hQuotient + 3` of [param amount] times 25 over a one-byte quarter max HP.
static func _quarter_percent(amount: int, foe: Gen2BattleMon) -> int:
	var divisor: int = (foe.max_hp() >> 2) & 0xFF
	if divisor == 0:
		return 0
	return ((amount * 25) / divisor) & 0xFF


## `BattleMonEntrance`: the line, fifty frames, `PursuitSwitch`, then
## `RecallPlayerMon` unless Pursuit felled it. `AI_Switch`: Pursuit, then
## `EnemyWithdrewText` for a survivor. A pass or a drag says nothing.
func _recall(side: int, entrance: int, events: Array) -> void:
	var leaving: Gen2BattleMon = mon(side)
	var withdrew: Dictionary = {
		"type": WITHDREW, "side": side, "index": party(side).active,
		"species": leaving.species, "name": leaving.display_name(),
		"quiet": entrance != ENTRANCE_SWITCH, "line": WITHDRAW_ENOUGH,
	}
	if entrance == ENTRANCE_BATON_PASS and side == PLAYER:
		events.append({"type": DELAY, "frames": SWITCH_DELAY_FRAMES})
	if entrance != ENTRANCE_SWITCH:
		events.append(withdrew)
		return
	if side == PLAYER:
		withdrew["line"] = withdraw_line()
		events.append(withdrew)
		events.append({"type": DELAY, "frames": SWITCH_DELAY_FRAMES})
	if not _pending_turn.is_empty():
		_pursuit_before_switch(side, _pending_turn["actions"], events)
	if leaving.is_fainted():
		return
	if side == ENEMY:
		events.append(withdrew)
		return
	events.append({
		"type": ANIMATION, "index": ANIM_RETURN_MON, "param": 0, "after_anim": 0,
		"enemy_turn": false, "effectiveness": 0, "restore_user_pic": false,
		"called": true,
	})


## `SpikesDamage`, behind each entrance's own `SetPlayerTurn`/`SetEnemyTurn`, so
## the spikes read are the ones on the side walking in.
func _spikes_damage(side: int, events: Array) -> void:
	if not Gen2Screens.has(screens[side], Gen2Screens.SPIKES):
		return

	var entering: Gen2BattleMon = mon(side)
	if entering.is_fainted() or Gen2Screens.spikes_spare(entering.types()):
		return

	var taken: int = entering.take_damage(Gen2Screens.spikes_damage(entering.max_hp()))
	events.append({
		"type": HURT_BY_SPIKES, "side": side, "amount": taken,
		"hp": entering.hp, "max_hp": entering.max_hp(),
	})
	if entering.is_fainted():
		note_faint(side, events)


## `UpdateUsedMoves`, on the player's own side alone: remembered once, four kept,
## and a fifth drops the oldest rather than being ignored.
func record_used_move(side: int, move_number: int) -> void:
	if side != PLAYER or move_number == 0 or player_used_moves.has(move_number):
		return
	player_used_moves.append(move_number)
	if player_used_moves.size() > Gen2BattleMon.MAX_MOVES:
		player_used_moves.remove_at(0)


## Ends the trapping relationship on both sides, as `NewBattleMonStatus` does.
## [method Gen2BattleMon.reset_volatile] cannot: half the state is on the Pokémon
## staying. [param keep_cant_run] names a side whose Mean Look stands.
func _clear_trapping(keep_cant_run: int = -1) -> void:
	for side: int in [PLAYER, ENEMY]:
		var battler: Gen2BattleMon = mon(side)
		battler.trapped_turns = 0
		battler.trapping_move = 0
		if side != keep_cant_run:
			battler.substatus &= ~Gen2Substatus.CANT_RUN


## Whether `TryPlayerSwitch` would refuse the recall: bound, or held by Mean Look
## or Spider Web. Player-only, `AI_Switch` making no such check. Generation 1's
## `MainInBattleLoop` opens `DisplayBattleMenu` in front of its trap test.
func switch_blocked() -> bool:
	return not is_gen1() and (mon(PLAYER).trapped_turns > 0 \
		or Gen2Substatus.has(mon(ENEMY).substatus, Gen2Substatus.CANT_RUN))


## Both sides act and the turn plays out. [method order] reads each side's move
## once before either acts, and what runs is recomputed just before
## [method _act]: Encore can land on a side that has not gone.
func take_actions(player_action: Dictionary, enemy_action: Dictionary) -> Array:
	var events: Array = []
	if is_over() or awaiting_replacement() or awaiting_move_learn():
		return events
	# A turn already part way through cannot be started again: the one standing
	# is finished by [method pass_to] and by nothing else.
	if _pending_baton_pass >= 0 or _pending_switch_offer >= 0 or not _pending_mimic.is_empty():
		return events

	events.append_array(begin_turn())

	# Settled before anything is spent, because `TryPlayerSwitch` runs at menu
	# time: the refusal jumps back to `BattleMenuPKMN_Loop` with no turn taken.
	if _is_switch(player_action) and switch_blocked():
		events.append({
			"type": SWITCH_BLOCKED, "side": PLAYER,
			"index": party(PLAYER).active, "species": mon(PLAYER).species,
			"name": mon(PLAYER).display_name(),
		})
		return events

	reset_damage_taken()
	_just_got_frozen = {PLAYER: false, ENEMY: false}

	if _is_run(player_action):
		var outcome: StringName = _attempt_run(events)
		if outcome == &"fled":
			events.append({"type": OVER, "winner": winner(), "fled": true})
			return events
		if outcome == &"blocked":
			# BattleMenu_Run's `jp BattleMenu`: nothing was spent, so no residual
			# damage and no enemy move either.
			return events
	_turn_begun = false

	if StringName(player_action.get("type", ACTION_MOVE)) == ACTION_MOVE:
		fight_chosen()

	var actions: Dictionary = {PLAYER: player_action, ENEMY: enemy_action.duplicate()}
	var chosen: Dictionary = {
		PLAYER: _move_for_action(PLAYER, player_action),
		ENEMY: _move_for_action(ENEMY, enemy_action),
	}
	for side: int in [PLAYER, ENEMY]:
		var action: Dictionary = actions[side]
		if StringName(action.get("type", ACTION_MOVE)) == ACTION_MOVE:
			gen1_selected_moves[side] = int(chosen[side])
		## `ParsePlayerAction` and `ParseEnemyAction` settle them before either moves.
		_reset_action_counters(side, int(data.move(int(chosen[side])).get("effect", -1)) \
			if _is_move(action) else -1)

	var acting: Array = order(chosen, actions)
	enemy_goes_first = int(acting[0]) == ENEMY
	_pursuit_spent = -1
	_pending_turn = {"acting": acting, "actions": actions, "index": 0, "chosen": chosen}
	return _run_turn(events)


## `BattleTurn` before `BattleMenu`, once a turn: `HandleBerserkGene`, and
## `CheckPlayerLockedIn`'s flinch clear unless the player is recharging.
func begin_turn() -> Array:
	var events: Array = []
	if _turn_begun or is_over():
		return events
	_turn_begun = true
	_handle_berserk_gene(events)
	if is_gen1() or not Gen2Substatus.has(mon(PLAYER).substatus, Gen2Substatus.RECHARGING):
		for side: int in [PLAYER, ENEMY]:
			mon(side).substatus &= ~Gen2Substatus.FLINCHED
	return events


func turn_begun() -> bool:
	return _turn_begun


## `AI_SwitchOrTryItem` for an action carrying `ai_item_switch` flags: at the top
## of `Battle_PlayerFirst`, or in `Battle_EnemyFirst`'s own place.
func _ask_enemy_ai(actions: Dictionary, events: Array) -> void:
	var action: Dictionary = actions[ENEMY]
	if not action.has("ai_item_switch"):
		return
	var flags: int = int(action["ai_item_switch"])
	action.erase("ai_item_switch")
	var decided: Dictionary = Gen2BattleAI.choose_action(
		self, flags, int(action.get("slot", 0)), rng
	)
	if not (_is_switch(decided) or _is_item(decided)):
		return
	decided["spent"] = true
	actions[ENEMY] = decided
	_run_action(ENEMY, decided, events)


## `TrainerAI` stands in front of `ExecuteEnemyMove` on both orderings, so an
## item or a switch replaces the move where it would have been, marked
## `trainer_ai`.
func _gen1_ai_action(side: int, actions: Dictionary) -> Dictionary:
	var action: Dictionary = actions[side]
	if side != ENEMY or not is_gen1() or _is_switch(action) or _is_item(action):
		return action
	var chosen: Dictionary = Gen1TrainerAI.trainer_action(self, rng)
	if chosen.is_empty():
		return action
	chosen["trainer_ai"] = true
	actions[side] = chosen
	return chosen




## The per-side loop and the end-of-turn tail, from wherever the turn last
## stopped. A question stops it part way, and [code]acted[/code] resumes on the
## tail behind the action it was asked inside.
func _run_turn(events: Array) -> Array:
	var acting: Array = _pending_turn["acting"]
	var actions: Dictionary = _pending_turn["actions"]
	if int(acting[0]) == PLAYER:
		_ask_enemy_ai(actions, events)

	while int(_pending_turn["index"]) < acting.size():
		var side: int = int(acting[int(_pending_turn["index"])])
		if not bool(_pending_turn.get("acted", false)):
			# `HasPlayerFainted`/`HasEnemyFainted` gate the whole second half
			# of the turn, so they are asked before the bracket opens.
			if mon(side).is_fainted() or mon(opponent_of(side)).is_fainted():
				break
			if _enemy_flees(side, actions[side], events):
				_pending_turn = {}
				events.append({"type": OVER, "winner": winner()})
				return events
			if side == ENEMY:
				_ask_enemy_ai(actions, events)
			_open_turn_bracket(side, _gen1_ai_action(side, actions))
			_pending_turn["acted"] = true
			if _run_action(side, actions[side], events):
				return events
		_pending_turn["acted"] = false
		_close_turn_bracket(side, actions[side])
		# `ld a, [wForcedSwitch] / and a / ret nz` in both orderings: a side
		# taken out of a wild battle ends the turn, tail included.
		if was_forced_out():
			_pending_turn = {}
			events.append({"type": OVER, "winner": winner()})
			return events
		_side_residual(side, events)
		_pending_turn["index"] = int(_pending_turn["index"]) + 1

	_pending_turn = {}
	## Knockouts pay where they land; `CheckFaint_*` stops on `wBattleEnded`.
	var paid: int = _award_experience(events, 0)
	for tick: Callable in [_tick_future_sight, _tick_weather, _tick_wrap, _tick_perish]:
		if is_over():
			break
		tick.call(events)
		paid = _award_experience(events, paid)
	if not is_over():
		_tick_held_items(events)
		_tick_encore(events)

	if is_over():
		events.append({"type": OVER, "winner": winner()})
	return events


## `TryEnemyFlee`, in front of the enemy's move in both `Battle_EnemyFirst` and
## `Battle_PlayerFirst`. `AlwaysFleeMons` leave without a roll.
func _enemy_flees(side: int, action: Dictionary, events: Array) -> bool:
	if side != ENEMY or is_gen1() or is_trainer_battle or is_link_battle \
			or _is_switch(action) or _is_item(action):
		return false
	var wild: Gen2BattleMon = mon(ENEMY)
	if Gen2Substatus.has(mon(PLAYER).substatus, Gen2Substatus.CANT_RUN) \
			or wild.trapped_turns > 0 \
			or Gen2Status.has(wild.status, Gen2Status.FREEZE) or Gen2Status.is_asleep(wild.status):
		return false
	var species: int = wild.base_species()
	var always: Array[int] = ALWAYS_FLEE_MONS if Gen2WorldState.is_crystal_profile(data) \
		else GOLD_SILVER_ALWAYS_FLEE_MONS
	if not species in always:
		var roll: int = rng.randi_range(0, 255)
		if roll >= OFTEN_FLEE_BOUND:
			return false
		if not species in OFTEN_FLEE_MONS \
				and (roll >= SOMETIMES_FLEE_BOUND or not species in SOMETIMES_FLEE_MONS):
			return false
	force_out(ENEMY)
	events.append({"type": WILD_FLED, "side": ENEMY, "species": species})
	return true


## One side's action; true when the turn cannot go on until somebody answers.
func _run_action(side: int, action: Dictionary, events: Array) -> bool:
	var action_event_start: int = events.size()
	var moving: bool = _is_move(action)
	if bool(action.get("spent", false)):
		return false
	if _is_switch(action):
		# `AI_Switch` raises `wBattleHasJustStarted`, so `CheckWhetherToAskSwitch`
		# offers nothing mid-turn.
		events.append_array(send_out(side, int(action.get("index", -1))))
	elif _is_item(action):
		## `BattleMenu_Pack` spends the player's item before the turn
		## resolves; only the enemy reaches into its bag inside one.
		if side == ENEMY:
			_use_trainer_item(side, int(action.get("item", 0)), events)
	elif moving and side != _pursuit_spent:
		var slot: int = effective_slot(side, int(action.get("slot", 0)))
		if side == ENEMY and is_gen1():
			gen1_enemy_moves += 1
		_act(side, slot, _move_to_run(side, slot), events)
		_report_unannounced_action_faints(events, action_event_start)
	return _pending_baton_pass >= 0 or not _pending_mimic.is_empty()


## Core checks both battlers after every action, whether or not the effect list
## carried `checkfaint`: this fills only the report an effect did not make.
func _report_unannounced_action_faints(events: Array, since: int) -> void:
	for side: int in [PLAYER, ENEMY]:
		if not mon(side).is_fainted():
			continue
		var reported: bool = false
		for index: int in range(since, events.size()):
			var event: Dictionary = events[index]
			if StringName(event.get("type", &"")) == FAINTED and int(event.get("side", -1)) == side:
				reported = true
				break
		if not reported:
			note_faint(side, events)


## `HandleFutureSight`, player then enemy: the count is decremented before it is
## tested, and the move is then run through `DoMove` like any other, so the
## stored word takes its spread, its hit roll and its faint check inside the
## effect list rather than beside it. `checkfuturesight` is what loads it.
func _tick_future_sight(events: Array) -> void:
	for side: int in [PLAYER, ENEMY]:
		var pending: Dictionary = _future_sight[side]
		var count: int = int(pending.get("count", 0))
		if count <= 0:
			continue
		count -= 1
		pending["count"] = count
		if count != 1:
			continue
		if mon(side).is_fainted() or mon(opponent_of(side)).is_fainted():
			pending["count"] = 0
			continue
		events.append({"type": FUTURE_SIGHT_HIT, "side": side, "target": opponent_of(side)})
		var number: int = Gen2MoveEffect.FUTURE_SIGHT_MOVE
		var turn: Gen2Turn = Gen2Turn.create(self, side, -1, number, data.move(number), events)
		run_move_effect(turn)


## `wPlayerIsSwitching` and `wEnemyIsSwitching`, zeroed each turn the way
## rebuilding [member _pending_turn] is. An enemy item is not a switch here though
## [method order] orders it as one: `AI_TryItem` sets no flag, and
## [method Gen2EffectCommands._pursuit] is the reader.
func is_switching(side: int) -> bool:
	if _pending_turn.is_empty():
		return false
	var actions: Dictionary = _pending_turn["actions"]
	return _is_switch(actions.get(side, {}))


## `PursuitSwitch`, in front of the recall: the pursuer spends its whole turn
## now with no speed test, which is why `EFFECT_PURSUIT` carries no priority
## entry. A chosen switch only: a Baton Pass and a replacement are not pursued.
func _pursuit_before_switch(side: int, actions: Dictionary, events: Array) -> void:
	var other: int = opponent_of(side)
	var action: Dictionary = actions.get(other, {})
	if _is_switch(action) or _is_run(action) or _is_item(action):
		return
	var slot: int = effective_slot(other, int(action.get("slot", 0)))
	var move_number: int = move_for(other, slot)
	if int(data.move(move_number).get("effect", -1)) != Gen2MoveEffect.PURSUIT:
		return

	_pursuing = true
	_act(other, slot, move_number, events)
	_pursuing = false
	_pursuit_spent = other


## `CheckOpponentWentFirst`, `wEnemyGoesFirst XOR hBattleTurn`. Protect and Endure
## fail outright on a yes, which is what makes two Protects a question of speed
## and a Protect behind a switch fail, a switching side always going first.
func opponent_went_first(side: int) -> bool:
	return (side == PLAYER) == enemy_goes_first


## `EndUserDestinyBond`, the front half of the wrapper each action runs inside.
## Ahead of `DoPlayerTurn`, so a Pokémon that cannot move still loses its bond.
func _open_turn_bracket(side: int, action: Dictionary) -> void:
	if not _brackets_turn(side, action):
		return
	mon(side).substatus &= ~Gen2Substatus.DESTINY_BOND


## `EndOpponentProtectEndureDestinyBond`, the back half: three flags only an
## opposing action ends, so a Protect covers one action and outlives its own turn
## when it was used going second.
func _close_turn_bracket(side: int, action: Dictionary) -> void:
	if not _brackets_turn(side, action):
		return
	var other: Gen2BattleMon = mon(opponent_of(side))
	other.substatus &= ~(
		Gen2Substatus.PROTECT | Gen2Substatus.ENDURE | Gen2Substatus.DESTINY_BOND
	)


## Whether an action runs inside that wrapper: the player's always, the
## enemy's not when `AI_SwitchOrTryItem` answers, so a player's Protect
## survives an enemy switch and an enemy's does not survive a player switch.
func _brackets_turn(side: int, action: Dictionary) -> bool:
	return side == PLAYER or not (_is_switch(action) or _is_item(action))


## `ParsePlayerAction` and `ParseEnemyAction`: the two counters a chain keeps only
## while it is the move being used, Protect and Endure sharing one. [param effect]
## is the move's own byte, which a broken Substitute cannot overwrite.
func _reset_action_counters(side: int, effect: int) -> void:
	var actor: Gen2BattleMon = mon(side)
	if effect != Gen2MoveEffect.FURY_CUTTER:
		actor.fury_cutter_count = 0
	if effect != Gen2MoveEffect.PROTECT and effect != Gen2MoveEffect.ENDURE:
		actor.protect_count = 0
	if effect != Gen2MoveEffect.BIDE:
		actor.substatus &= ~Gen2Substatus.BIDE
		actor.bide_turns = 0
		actor.bide_damage = 0
		actor.bide_move = 0
	if effect != Gen2MoveEffect.RAGE:
		actor.substatus &= ~Gen2Substatus.RAGE
		actor.rage_count = 0


func take_turn(player_slot: int, enemy_slot: int) -> Array:
	return take_actions(use_move(player_slot), use_move(enemy_slot))


## `HandlePoisonBurnLeechSeed`, which `MainInBattleLoop` calls behind each
## side's action while the other side stands: a switch pays it too, and no
## faint check parts the poison from the seed.
func _gen1_residual(side: int, events: Array) -> void:
	var current: Gen2BattleMon = mon(side)
	if current.is_fainted() or mon(opponent_of(side)).is_fainted():
		return
	if Gen2Status.has(current.status, Gen2Status.BURN | Gen2Status.POISON):
		var taken: int = current.take_damage(_gen1_residual_amount(current))
		events.append({
			"type": HURT_BY_STATUS, "side": side, "status": current.status,
			"name": Gen2Status.name_of(current.status), "amount": taken,
			"hp": current.hp, "max_hp": current.max_hp(),
		})
		events.append(status_animation_event(side, Gen1Layout.ANIM_ID_BURN_PSN))
	if Gen2Substatus.has(current.substatus, Gen2Substatus.LEECH_SEED):
		var sapper: Gen2BattleMon = mon(opponent_of(side))
		events.append(status_animation_event(opponent_of(side), Gen2MoveEffect.ABSORB_MOVE))
		# `bc` is the whole amount whatever the seeded side had left.
		var amount: int = _gen1_residual_amount(current)
		var taken: int = current.take_damage(amount)
		var healed: int = sapper.heal(amount)
		events.append({
			"type": LEECH_SEED_SAPPED, "side": side, "amount": taken,
			"hp": current.hp, "max_hp": current.max_hp(), "to": opponent_of(side),
			"to_amount": healed, "to_hp": sapper.hp, "to_max_hp": sapper.max_hp(),
		})
	if current.is_fainted():
		note_faint(side, events)


## `HandlePoisonBurnLeechSeed_DecreaseOwnHP`: a sixteenth, one at least, times
## the toxic counter, which every call steps first.
func _gen1_residual_amount(current: Gen2BattleMon) -> int:
	if current.toxic_counter <= 0:
		return maxi(current.max_hp() >> Gen1Layout.RESIDUAL_SHIFT, 1)
	var amount: int = Gen2Status.toxic_damage(current.max_hp(), current.toxic_counter)
	current.toxic_counter += 1
	return amount


## `ResidualDamage` behind each side's own action, once both faint checks pass.
func _side_residual(side: int, events: Array) -> void:
	if is_gen1():
		_gen1_residual(side, events)
	elif not mon(side).is_fainted() and not mon(opponent_of(side)).is_fainted():
		_residual_damage(side, events)


## `ResidualDamage`: burn or poison, Leech Seed, Nightmare, Curse, with
## `HasUserFainted` between each, so a faint to poison pays none of the rest.
func _residual_damage(side: int, events: Array) -> void:
	for step: Callable in [
		_residual_status, _residual_leech_seed, _residual_nightmare, _residual_curse,
	]:
		if mon(side).is_fainted():
			break
		step.call(side, events)
	if not mon(side).is_fainted():
		return
	# `.fainted`'s twenty frames, in front of the faint `HandlePlayerMonFaint` shows.
	for index: int in range(events.size() - 1, -1, -1):
		if events[index]["type"] == FAINTED and int(events[index]["side"]) == side:
			events.insert(index, {"type": DELAY, "frames": RESIDUAL_FAINT_FRAMES})
			return


## [member Gen2BattleMon.toxic_counter] is `SUBSTATUS_TOXIC`, which ramps a burn
## as well as a poison; it rises here, so the turn it landed is the first.
func _residual_status(side: int, events: Array) -> void:
	var current: Gen2BattleMon = mon(side)
	if not Gen2Status.has(current.status, Gen2Status.BURN | Gen2Status.POISON):
		return

	var amount: int
	if current.toxic_counter > 0:
		amount = Gen2Status.toxic_damage(current.max_hp(), current.toxic_counter)
		current.toxic_counter += 1
	else:
		amount = Gen2Status.residual_damage(current.max_hp())

	var taken: int = current.take_damage(amount)
	var anim: int = Gen2BattleAnimPlayer.ANIM_BRN if Gen2Status.has(current.status, Gen2Status.BURN) \
		else Gen2BattleAnimPlayer.ANIM_PSN
	events.append({
		"type": HURT_BY_STATUS,
		"side": side,
		"status": current.status,
		"name": Gen2Status.name_of(current.status),
		"amount": taken,
		"hp": current.hp,
		"max_hp": current.max_hp(),
	})
	_status_animation(side, anim, side, events)
	if current.is_fainted():
		note_faint(side, events)


## `Call_PlayBattleAnim_OnlyIfVisible`, which [param hidden_side] in the air skips.
## Generation 1's `HandlePoisonBurnLeechSeed` plays its animations regardless.
func _status_animation(side: int, index: int, hidden_side: int, events: Array) -> void:
	if is_gen1() or mon(hidden_side).substatus & (Gen2Substatus.FLYING | Gen2Substatus.UNDERGROUND) == 0:
		events.append(status_animation_event(side, index))


func status_animation_event(side: int, index: int) -> Dictionary:
	return {
		"type": ANIMATION, "index": index, "param": battle_anim_param,
		"after_anim": Gen2BattleAnimPlayer.AFTER_ANIM_NONE, "enemy_turn": side == ENEMY,
		"effectiveness": Gen2Layout.MATCHUP_EFFECTIVE, "restore_user_pic": false,
		"off_field": off_field(),
	}


## `BGEffect_CheckFlyDigStatus` per side, as it stood when the animation was emitted.
func off_field() -> Array:
	return [
		mon(PLAYER).substatus & (Gen2Substatus.FLYING | Gen2Substatus.UNDERGROUND) != 0,
		mon(ENEMY).substatus & (Gen2Substatus.FLYING | Gen2Substatus.UNDERGROUND) != 0,
	]


## An eighth off the seeded Pokémon and onto the one opposite, capped by
## `RestoreHP`: what is healed is what `SubtractHP` left in `bc`, which is
## [method Gen2BattleMon.take_damage]'s answer. A fainted receiver cannot happen
## on the cartridge and can here, this running after both moves; nothing moves.
func _residual_leech_seed(side: int, events: Array) -> void:
	var current: Gen2BattleMon = mon(side)
	if not Gen2Substatus.has(current.substatus, Gen2Substatus.LEECH_SEED):
		return

	var sapper: Gen2BattleMon = mon(opponent_of(side))
	## The seeded side's Fly or Dig, then the sapper's in `_OnlyIfVisible`.
	if current.substatus & (Gen2Substatus.FLYING | Gen2Substatus.UNDERGROUND) == 0:
		_status_animation(
			opponent_of(side), Gen2BattleAnimPlayer.ANIM_SAP, opponent_of(side), events
		)
	var taken: int = current.take_damage(Gen2Substatus.leech_seed_damage(current.max_hp()))
	var healed: int = 0 if sapper.is_fainted() else sapper.heal(taken)
	events.append({
		"type": LEECH_SEED_SAPPED,
		"side": side,
		"amount": taken,
		"hp": current.hp,
		"max_hp": current.max_hp(),
		"to": opponent_of(side),
		"to_amount": healed,
		"to_hp": sapper.hp,
		"to_max_hp": sapper.max_hp(),
	})
	if current.is_fainted():
		note_faint(side, events)


## Nothing here asks whether the sufferer is still asleep: `.woke_up`,
## `BattleCommand_HealBell`, `HealStatus` and `UseHeldStatusHealingItem` each clear
## the flag. `AI_HealStatus` is the one that does not, a pret-recorded bug.
func _residual_nightmare(side: int, events: Array) -> void:
	var current: Gen2BattleMon = mon(side)
	if not Gen2Substatus.has(current.substatus, Gen2Substatus.NIGHTMARE):
		return

	_status_animation(side, Gen2BattleAnimPlayer.ANIM_IN_NIGHTMARE, side, events)
	var taken: int = current.take_damage(Gen2Substatus.quarter_damage(current.max_hp()))
	events.append({
		"type": HURT_BY_NIGHTMARE, "side": side, "amount": taken,
		"hp": current.hp, "max_hp": current.max_hp(),
	})
	if current.is_fainted():
		note_faint(side, events)


func _residual_curse(side: int, events: Array) -> void:
	var current: Gen2BattleMon = mon(side)
	if not Gen2Substatus.has(current.substatus, Gen2Substatus.CURSE):
		return

	_status_animation(side, Gen2BattleAnimPlayer.ANIM_IN_NIGHTMARE, side, events)
	var taken: int = current.take_damage(Gen2Substatus.quarter_damage(current.max_hp()))
	events.append({
		"type": HURT_BY_CURSE, "side": side, "amount": taken,
		"hp": current.hp, "max_hp": current.max_hp(),
	})
	if current.is_fainted():
		note_faint(side, events)


## `HandleWeather`: a turn off the count, its line, and a Sandstorm's eighth off
## whoever it reaches, ahead of [method _tick_wrap]. The countdown is before the
## message, so the turn it empties prints the ending line and deals no damage.
func _tick_weather(events: Array) -> void:
	if not Gen2Weather.is_active(weather):
		return

	weather_turns -= 1
	if weather_turns <= 0:
		var ended: int = weather
		weather = Gen2Weather.NONE
		weather_turns = 0
		events.append({"type": WEATHER_ENDED, "weather": ended})
		return

	events.append({"type": WEATHER_CONTINUES, "weather": weather})
	if weather != Gen2Weather.SANDSTORM:
		return

	for side: int in [PLAYER, ENEMY]:
		var current: Gen2BattleMon = mon(side)
		if current.is_fainted():
			continue
		if not Gen2Weather.hits_in_sandstorm(current.types(), current.substatus):
			continue

		var taken: int = current.take_damage(Gen2Weather.sandstorm_damage(current.max_hp()))
		events.append({
			"type": HURT_BY_SANDSTORM,
			"side": side,
			"amount": taken,
			"hp": current.hp,
			"max_hp": current.max_hp(),
		})
		if current.is_fainted():
			note_faint(side, events)


## `HandleWrap`: a turn off each bound Pokémon's counter and a sixteenth of its
## health, the player always first. The turn the counter empties is the release
## and costs nothing, so three to six rolled turns are two to five of damage.
func _tick_wrap(events: Array) -> void:
	## Generation 1 has no `ResidualDamage` entry for a trapping move: the
	## counter is spent by `.MultiturnMoveCheck` repeating the move instead, and
	## `CheckNumAttacksLeft` at the end of the whole turn is what lets go. So the
	## turn the counter empties still holds the target, whichever side moves
	## first on it.
	if is_gen1():
		for side: int in [PLAYER, ENEMY]:
			if mon(side).trapped_turns <= 0:
				mon(side).trapping_move = 0
		return
	for side: int in [PLAYER, ENEMY]:
		var current: Gen2BattleMon = mon(side)
		## `.do_it` returns for a Substitute before the count is touched.
		if current.is_fainted() or current.trapped_turns <= 0 \
				or Gen2Substatus.has(current.substatus, Gen2Substatus.SUBSTITUTE):
			continue

		var move_number: int = current.trapping_move
		current.trapped_turns -= 1
		if current.trapped_turns <= 0:
			current.trapping_move = 0
			events.append({"type": RELEASED_FROM_TRAP, "side": side, "move": move_number})
			continue

		var taken: int = current.take_damage(Gen2Substatus.trap_damage(current.max_hp()))
		events.append({
			"type": HURT_BY_TRAP,
			"side": side,
			"move": move_number,
			"amount": taken,
			"hp": current.hp,
			"max_hp": current.max_hp(),
		})
		if current.is_fainted():
			note_faint(side, events)


## `HandlePerishSong`: one off each count, said out loud on every tick, and
## the kill is `xor a` into the HP word rather than damage, so no held item
## can answer it.
func _tick_perish(events: Array) -> void:
	for side: int in [PLAYER, ENEMY]:
		var current: Gen2BattleMon = mon(side)
		if current.is_fainted():
			continue
		if not Gen2Substatus.has(current.substatus, Gen2Substatus.PERISH):
			continue

		current.perish_count -= 1
		events.append({"type": PERISH_COUNT, "side": side, "count": current.perish_count})
		if current.perish_count > 0:
			continue

		current.substatus &= ~Gen2Substatus.PERISH
		current.hp = 0
		note_faint(side, events)


## `HandleBetweenTurnEffects`' leftovers block: the first two read
## `GetUserItem` so the player is first, `HandleHealingItems` `GetOpponentItem`
## so the enemy is, and the defrost, Safeguard and screen ticks sit among them.
func _tick_held_items(events: Array) -> void:
	for side: int in [PLAYER, ENEMY]:
		_use_leftovers(side, events)
	for side: int in [PLAYER, ENEMY]:
		_use_pp_berry(side, events)
	_tick_defrost(events)
	_tick_safeguard(events)
	_tick_screens(events)
	for side: int in [ENEMY, PLAYER]:
		use_hp_berry(side, events)
		use_status_berry(side, events)
		use_confusion_berry(side, events)


## `HandleBerserkGene`, at the top of the loop: the holder spends the Gene, is
## confused with no count written, so a carried zero wraps to 256
## (`docs/bugs_and_glitches.md`), and takes `BattleCommand_AttackUp2`'s two.
func _handle_berserk_gene(events: Array) -> void:
	for side: int in [PLAYER, ENEMY]:
		var holder: Gen2BattleMon = mon(side)
		if holder == null or holder.item != Gen2HeldItem.BERSERK_GENE_ITEM:
			continue
		var used: int = holder.item
		holder.item = 0
		var was_confused: bool = Gen2Substatus.has(
			holder.substatus, Gen2Substatus.CONFUSED
		)
		holder.substatus |= Gen2Substatus.CONFUSED
		if holder.confusion_turns <= 0:
			holder.confusion_turns = BERSERK_GENE_CONFUSION_TURNS
		## `BattleCommand_AttackUp2` and `StatUpMessage`.
		var raised: bool = holder.change_stage("attack", BERSERK_GENE_STAGES)
		events.append({"type": ITEM_ACTIVATED, "side": side, "item": used})
		if raised:
			events.append({
				"type": STAT_CHANGED, "target": side, "stat": "attack",
				"by": BERSERK_GENE_STAGES,
			})
		if was_confused:
			continue
		events.append(status_animation_event(side, Gen2BattleAnimPlayer.ANIM_CONFUSED))
		events.append({"type": CONFUSE_INFLICTED, "target": side})


## `HandleDefrost`: each frozen side thaws on its own roll, the only thing making
## a Generation 2 freeze temporary. Player first, and `bit FRZ` comes before
## `BattleRandom`, so a battle with no freeze draws no randomness here.
func _tick_defrost(events: Array) -> void:
	# A Generation 1 freeze thaws only under a Fire move with a burn to give.
	if is_gen1():
		return
	for side: int in [PLAYER, ENEMY]:
		var current: Gen2BattleMon = mon(side)
		if not Gen2Status.has(current.status, Gen2Status.FREEZE):
			continue
		if bool(_just_got_frozen[side]):
			continue
		if not Gen2Status.rolls_thaw(rng):
			continue
		# `xor a / ld [wBattleMonStatus], a` clears the byte rather than the bit,
		# which is the same thing: a freeze is never on it with anything else.
		current.status = Gen2Status.NONE
		events.append(stamp_statuses({"type": THAWED, "side": side}))


## `HandleSafeguard`: a turn off each side's count and the line when it runs out.
## The count is read only while the flag is up, so a side without one is quiet.
func _tick_safeguard(events: Array) -> void:
	for side: int in [PLAYER, ENEMY]:
		if not Gen2Screens.has(screens[side], Gen2Screens.SAFEGUARD):
			continue
		safeguard_turns[side] = int(safeguard_turns[side]) - 1
		if int(safeguard_turns[side]) > 0:
			continue
		screens[side] &= ~Gen2Screens.SAFEGUARD
		safeguard_turns[side] = 0
		events.append({
			"type": SCREEN_FADED, "side": side, "screen": Gen2Screens.SAFEGUARD,
		})


## `HandleScreens`: Light Screen before Reflect, `.TickScreens`' own order, and
## the player first. The counts are separate bytes, so a side holds both.
func _tick_screens(events: Array) -> void:
	# `wPlayerBattleStatus3`'s two screen bits count no turns down.
	if is_gen1():
		return
	for side: int in [PLAYER, ENEMY]:
		for row: Array in [
			[Gen2Screens.LIGHT_SCREEN, light_screen_turns],
			[Gen2Screens.REFLECT, reflect_turns],
		]:
			var flag: int = int(row[0])
			var counts: Dictionary = row[1]
			if not Gen2Screens.has(screens[side], flag):
				continue
			counts[side] = int(counts[side]) - 1
			if int(counts[side]) > 0:
				continue
			screens[side] &= ~flag
			counts[side] = 0
			events.append({"type": SCREEN_FADED, "side": side, "screen": flag})


## `HandleLeftovers`: a sixteenth back every turn, and nothing at all on a
## Pokémon already at full health.
func _use_leftovers(side: int, events: Array) -> void:
	var holder: Gen2BattleMon = mon(side)
	if holder.is_fainted() or holder.hp >= holder.max_hp():
		return
	if _held_effect(holder) != Gen2HeldItem.LEFTOVERS:
		return

	var healed: int = holder.heal(Gen2HeldItem.leftovers_healing(holder.max_hp()))
	events.append({
		"type": RECOVERED_WITH_ITEM, "side": side, "item": holder.item,
		"amount": healed, "hp": holder.hp, "max_hp": holder.max_hp(),
	})


## `HandleMysteryberry`: five points into the first move that ran out, one for
## Sketch. Consumed by its own code, which is why it is not on
## `ConsumableEffects`.
func _use_pp_berry(side: int, events: Array) -> void:
	var holder: Gen2BattleMon = mon(side)
	if holder.is_fainted() or _held_effect(holder) != Gen2HeldItem.RESTORE_PP:
		return

	for slot: int in holder.moves.size():
		if int(holder.moves[slot]) == 0:
			break
		if holder.pp_left(slot) > 0:
			continue

		var move_number: int = int(holder.moves[slot])
		var restored: int = Gen2HeldItem.restored_pp(move_number)
		holder.pp[slot] = holder.pp_left(slot) + restored
		var used: int = holder.item
		holder.item = 0
		events.append({
			"type": RESTORED_PP, "side": side, "item": used,
			"slot": slot, "move": move_number, "amount": restored,
		})
		return


## `HandleHPHealingItem`: a Berry, Gold Berry or Berry Juice puts its own
## parameter back once the holder is strictly under half health, and is spent.
func use_hp_berry(side: int, events: Array) -> bool:
	var holder: Gen2BattleMon = mon(side)
	if holder.is_fainted() or _held_effect(holder) != Gen2HeldItem.BERRY:
		return false
	if not Gen2HeldItem.wants_hp_berry(holder.hp, holder.max_hp()):
		return false

	var healed: int = holder.heal(Gen2HeldItem.parameter_of(data, holder.item))
	var used: int = holder.item
	holder.item = 0
	events.append({
		"type": RECOVERED_USING_ITEM, "side": side, "item": used,
		"amount": healed, "hp": holder.hp, "max_hp": holder.max_hp(),
	})
	return true


## `UseHeldStatusHealingItem`, reached here and the moment a status lands: the
## berry answers at once rather than at the end of the turn.
func use_status_berry(side: int, events: Array) -> bool:
	var holder: Gen2BattleMon = mon(side)
	if holder.status == Gen2Status.NONE:
		return false
	if not Gen2HeldItem.heals_status(_held_effect(holder), holder.status):
		return false

	# `UseHeldStatusHealingItem`; an `ALL_STATUS` row clears confusion too.
	holder.status = Gen2Status.NONE
	holder.toxic_counter = 0
	holder.substatus &= ~Gen2Substatus.NIGHTMARE
	holder.release_stats()
	if _held_effect(holder) == Gen2HeldItem.HEAL_STATUS:
		holder.substatus &= ~Gen2Substatus.CONFUSED
		holder.confusion_turns = 0
	var used: int = holder.item
	holder.item = 0
	events.append(stamp_statuses({"type": RECOVERED_USING_ITEM, "side": side, "item": used}))
	return true


## `UseConfusionHealingItem`. A Miracleberry answers here and for the status byte,
## spent by whichever came first, which is why the calls are separate.
func use_confusion_berry(side: int, events: Array) -> bool:
	var holder: Gen2BattleMon = mon(side)
	if not Gen2Substatus.has(holder.substatus, Gen2Substatus.CONFUSED):
		return false
	if not Gen2HeldItem.heals_confusion(_held_effect(holder)):
		return false

	holder.substatus &= ~Gen2Substatus.CONFUSED
	holder.confusion_turns = 0
	var used: int = holder.item
	holder.item = 0
	events.append({"type": ITEM_HEALED_CONFUSION, "side": side, "item": used})
	return true


## `HandleEncore`, player then enemy, ending early on an empty slot.
func _tick_encore(events: Array) -> void:
	for side: int in [PLAYER, ENEMY]:
		var current: Gen2BattleMon = mon(side)
		if current.is_fainted() or current.encored_slot < 0:
			continue

		current.encore_turns -= 1
		if current.encore_turns > 0 and current.pp_left(current.encored_slot) > 0:
			continue

		current.encored_slot = -1
		current.encore_turns = 0
		events.append({"type": ENCORE_ENDED, "side": side})


## Experience for the enemy faints from [param since] on, answering where the
## next call starts; none in a link or the Battle Tower.
func _award_experience(events: Array, since: int) -> int:
	var end: int = events.size()
	if is_link_battle or in_battle_tower:
		return end
	for index: int in range(since, end):
		var event: Dictionary = events[index]
		if StringName(event.get("type", "")) != FAINTED:
			continue
		var side: int = int(event["side"])
		if bool(event.get("pursuit", false)):
			(_participants[side] as Dictionary)[int(event["index"])] = false
			continue
		(_participants[side] as Dictionary)[party(side).active] = false
		if side == ENEMY:
			if not is_trainer_battle and not party(PLAYER).is_wiped():
				events.append({"type": VICTORY_MUSIC, "silent": not is_gen1() \
					and _exp_share_holders().is_empty() and pay_day_money <= 0 \
					and _standing_participants().is_empty()})
			_give_experience_for(mon(ENEMY), events)
			if not is_gen1():
				events.append({"type": DELAY, "frames": ENEMY_FAINT_FRAMES})
	return events.size()


func _standing_participants() -> Array:
	var fought: Dictionary = _participants[PLAYER]
	return fought.keys().filter(
		func(index: int) -> bool: return fought[index] and not party(PLAYER).at(index).is_fainted()
	)


## Splits what [param defeated] is worth, then resets the participant set. With
## an Exp. Share out the block is halved and split twice, a Pokémon in both paid twice.
func _give_experience_for(defeated: Gen2BattleMon, events: Array) -> void:
	var fought: Dictionary = _participants[PLAYER]
	var participants: Array = fought.keys().filter(func(index: int) -> bool: return fought[index])
	var holders: Array = _exp_share_holders()
	var living: Array = _living_party_indices()
	## Neither later generation halves, so a claimed share suppresses the halving.
	var share: float = Gen2ModHost.experience_bystander_share({
		"participants": participants.duplicate(),
		"exp_share_holders": holders.duplicate(),
		"living": living.duplicate(),
		"is_trainer_battle": is_trainer_battle,
	})
	var halved: bool = not holders.is_empty() and share <= 0.0

	var award: int = _gen1_award(defeated, participants, halved, events) if is_gen1() \
		else _award_share(defeated, participants, halved, false, events)
	if not is_gen1():
		_award_share(defeated, holders, halved, true, events)
	_award_bystanders(defeated, participants, holders, living, halved, share, award, events)

	_participants[PLAYER] = {party(PLAYER).active: true}


## EXP.ALL: the block halved in place, `GainExperience` for the participants,
## then again for the whole party off the quotients the first run wrote back.
func _gen1_award(defeated: Gen2BattleMon, participants: Array, halved: bool, events: Array) -> int:
	var block: Dictionary = Gen2Experience.shared_block(
		defeated.base_stat_exp_shape(), defeated.base_exp(), halved, participants.size()
	)
	var award: int = _award_block(defeated, block, participants, false, events)
	if exp_all_in_bag:
		var everyone: Array = range(party(PLAYER).size())
		block = Gen2Experience.shared_block(
			block["stats"], int(block["base_exp"]), false, everyone.size()
		)
		_award_block(defeated, block, everyone, true, events)
	return award


## Every living index neither pass paid, at [param share] of [param award]. Its
## stat experience is the participant pass's block unchanged.
func _award_bystanders(
	defeated: Gen2BattleMon, participants: Array, holders: Array, living: Array,
	halved: bool, share: float, award: int, events: Array
) -> void:
	if share <= 0.0 or award <= 0 or participants.is_empty():
		return
	var block: Dictionary = Gen2Experience.shared_block(
		defeated.base_stat_exp_shape(), defeated.base_exp(), halved, participants.size()
	)
	var scaled: int = clampi(maxi(int(float(award) * share), 1), 0, Gen2Experience.MAX_EXP)
	for index: int in living:
		if participants.has(index) or holders.has(index):
			continue
		var learner: Gen2BattleMon = party(PLAYER).at(int(index))
		if learner == null:
			continue
		_give_experience_to(
			learner, int(index), scaled, block["stats"], false, events, true
		)


func _living_party_indices() -> Array:
	var out: Array = []
	var party_side: Gen2Party = party(PLAYER)
	for index: int in party_side.size():
		var member: Gen2BattleMon = party_side.at(index)
		if member != null and not member.is_fainted():
			out.append(index)
	return out


## One of the two passes: the block divided among [param recipients], then handed
## to each of them that is still standing. Answers what one recipient was paid.
func _award_share(
	defeated: Gen2BattleMon, recipients: Array, halved: bool, by_exp_share: bool, events: Array
) -> int:
	if recipients.is_empty():
		return 0
	var block: Dictionary = Gen2Experience.shared_block(
		defeated.base_stat_exp_shape(), defeated.base_exp(), halved, recipients.size()
	)
	return _award_block(defeated, block, recipients, by_exp_share, events)


func _award_block(
	defeated: Gen2BattleMon, block: Dictionary, recipients: Array, by_exp_share: bool, events: Array
) -> int:
	var stat_gains: Dictionary = block["stats"]
	for index: int in recipients:
		var learner: Gen2BattleMon = party(PLAYER).at(int(index))
		if learner != null and not learner.is_fainted():
			_give_experience_to(learner, int(index), _award_to(learner, defeated, block),
				stat_gains, by_exp_share, events)
	return _scaled_award(Gen2Experience.award_for(
		defeated.level, int(block["base_exp"]), is_trainer_battle
	))


## `wPlayerID` against `MON_ID`, and `MON_ITEM` against LUCKY_EGG, which no
## Generation 1 row carries: its byte there is the catch rate.
func _award_to(learner: Gen2BattleMon, defeated: Gen2BattleMon, block: Dictionary) -> int:
	return _scaled_award(Gen2Experience.award_for(
		defeated.level, int(block["base_exp"]), is_trainer_battle, _is_traded(learner),
		not is_gen1() and learner.item == Gen2Experience.LUCKY_EGG_ITEM
	))


func _is_traded(learner: Gen2BattleMon) -> bool:
	return player_id >= 0 and learner.ot_id >= 0 and learner.ot_id != player_id


## The one place a registered experience scale is applied; a non-zero award is
## floored at 1 or a 0.5x run would never level at all.
func _scaled_award(award: int) -> int:
	var scale: float = Gen2ModHost.experience_scale()
	if is_equal_approx(scale, 1.0) or award <= 0:
		return award
	return clampi(maxi(int(float(award) * scale), 1), 0, Gen2Experience.MAX_EXP)


## What a won battle owes when nothing simulated the turns that won it: every
## enemy Pokémon fainted in party order through [method _give_experience_for].
func award_win_experience() -> Array:
	var events: Array = []
	if data == null or parties.is_empty():
		return events
	var beaten: Gen2Party = party(ENEMY)
	for index: int in beaten.size():
		var defeated: Gen2BattleMon = beaten.at(index)
		if defeated == null or defeated.is_fainted():
			continue
		defeated.hp = 0
		_give_experience_for(defeated, events)
	return events


## What a capture owes under [method Gen2ModHost.awards_catch_experience]:
## `PokeBallEffect` awards none, so this is off by default.
func award_capture_experience() -> Array:
	var events: Array = []
	if data == null or parties.is_empty():
		return events
	_give_experience_for(mon(ENEMY), events)
	return events


## Spends one of the trainer's two items, which costs the turn: `AI_TryItem`
## clears the slot the moment a check said yes, whether or not it changed anything.
func _use_trainer_item(side: int, item: int, events: Array) -> void:
	if item == 0:
		return
	enemy_items.erase(item)
	var user: Gen2BattleMon = mon(side)
	var effect: Dictionary = Gen1TrainerAI.apply_item(self, user, item) if is_gen1() \
		else Gen2AIItems.apply(user, item)
	events.append(stamp_statuses({
		"type": TRAINER_USED_ITEM, "side": side, "item": item,
		"species": user.species, "name": user.display_name(), "effect": effect,
		"hp": user.hp, "max_hp": user.max_hp(),
	}))


func allows_bag_items() -> bool:
	return not in_battle_tower and not is_link_battle


## `DoItemEffect` with `wBattleMode` set, applied in the menu as the cartridge
## does and the turn spent as `BATTLEPLAYERACTION_USEITEM`. A refusal is any
## branch leaving `wItemEffectSucceeded` clear, and spends nothing.
func use_bag_item(item: int, target_index: int = -1, move_slot: int = -1) -> Dictionary:
	if data == null or is_over():
		return _item_failure(&"battle_not_running")
	if not allows_bag_items():
		return _item_failure(&"items_cant_be_used_here")
	var definition: Dictionary = data.item(item)
	if definition.is_empty():
		return _item_failure(&"unknown_item")
	## `ItemUseNotTime`, which only a Generation 1 list ever reaches.
	if int(definition.get("battle_menu", 0)) == Gen2Layout.ITEMMENU_NOUSE:
		return _item_failure(&"item_not_usable_here")
	var roles: Dictionary = Gen2WorldPartyHost.item_effects(data)
	if item == int(roles["poke_doll"]):
		## `PokeDollEffect` and `ItemUsePokeDoll`: a DRAW in the wild, `.Oak` otherwise.
		if is_trainer_battle:
			return _item_failure(&"item_not_usable_here")
		force_out(PLAYER)
		return {"ok": true, "kind": &"fled", "item": item}
	if item == int(roles["poke_flute"]):
		return _play_poke_flute(item)
	if (roles["x_stat"] as Dictionary).has(item) \
		or (roles["x_substatus"] as Dictionary).has(item):
		return _use_active_item(item)
	if item == int(roles["confusion_cure"]):
		var cured: Dictionary = _cure_confusion()
		if not bool(cured.get("ok", false)):
			return _item_failure(&"item_has_no_effect")
		return {"ok": true, "kind": &"active_item", "item": item, "effect": cured,
			"events": [stamp_statuses({"type": SNAPPED_OUT, "side": PLAYER})]}
	var target: Gen2BattleMon = party(PLAYER).at(target_index)
	if target == null:
		return _item_failure(&"party_member_required")
	var result: Dictionary = _apply_party_item(
		target, item, definition, move_slot, target_index == party(PLAYER).active
	)
	if not bool(result.get("ok", false)):
		return _item_failure(StringName(result.get("reason", &"item_has_no_effect")))
	## `RevivePokemon` restores only a participant that had fought this opponent.
	if bool(result.get("revived", false)) and (_participants[PLAYER] as Dictionary).has(target_index):
		(_participants[PLAYER] as Dictionary)[target_index] = true
	return {
		"ok": true, "kind": &"party_item", "item": item,
		"target": target_index, "effect": result,
	}


## `ItemUsePokeFlute`'s in-battle branch: everything asleep on the field and in
## both parties wakes, `WakeUpEntireParty` reaching the enemy's party only in a
## trainer battle. `woken` is `wWereAnyMonsAsleep`, which picks the box behind
## it. The turn is spent either way and the key item is not.
func _play_poke_flute(item: int) -> Dictionary:
	var woken: int = 0
	for index: int in party(PLAYER).size():
		woken += _wake_up(party(PLAYER).at(index))
	if is_trainer_battle:
		for index: int in party(ENEMY).size():
			woken += _wake_up(party(ENEMY).at(index))
	else:
		var wild: int = _wake_up(mon(ENEMY))
		if Gen1Layout.flute_counts_wild(data.id):
			woken += wild
	return {"ok": true, "kind": &"poke_flute", "item": item, "woken": woken, "spent": false}


func _wake_up(sleeper: Gen2BattleMon) -> int:
	if sleeper == null or not Gen2Status.is_asleep(sleeper.status):
		return 0
	sleeper.status &= ~Gen2Status.SLEEP_MASK
	return 1


## `XItemEffect`'s `UseItemText` spends the item before `RaiseStat` can fail, and
## `HAPPINESS_USEDXITEM` is charged either way.
func _use_active_item(item: int) -> Dictionary:
	var user: Gen2BattleMon = mon(PLAYER)
	var applied: Dictionary = _apply_active_item(user, item)
	if not bool(applied.get("ok", false)):
		return _item_failure(StringName(applied.get("reason", &"item_has_no_effect")))
	(party_log["x_items"] as Array).append(party(PLAYER).active)
	var used: Dictionary = {"ok": true, "kind": &"active_item", "item": item, "effect": applied}
	if not applied.has("stat"):
		return used
	user.happiness = Gen2WorldPartyHost.change_happiness(data, user.happiness, HAPPINESS_USEDXITEM)
	var moved: bool = bool(applied["moved"])
	var events: Array = []
	## `ItemUseXStat` points `wPlayerMoveNum` at XSTATITEM_ANIM for `UpdateStatDone`.
	if moved and is_gen1():
		events.append(stamp_statuses({
			"type": ANIMATION, "side": PLAYER, "index": Gen1Layout.ANIM_ID_XSTATITEM[0],
			"param": 0, "after_anim": Gen2BattleAnimPlayer.AFTER_ANIM_NONE,
			"enemy_turn": false, "restore_user_pic": false, "off_field": off_field(),
		}))
	events.append(stamp_statuses({
		"type": STAT_CHANGED if moved else STAT_CHANGE_FAILED, "side": PLAYER,
		"target": PLAYER, "stat": String(applied["stat"]), "by": 1,
	}))
	used["events"] = events
	return used


## `AIIncreaseStat` reaches the same routine for Generation 1's enemy.
func apply_x_item(user: Gen2BattleMon, item: int) -> Dictionary:
	return _apply_active_item(user, item)


## Generation 1's three flag items set their bit without testing it.
func _apply_active_item(user: Gen2BattleMon, item: int) -> Dictionary:
	if user == null or user.is_fainted():
		return {"ok": false, "reason": &"item_has_no_effect"}
	var roles: Dictionary = Gen2WorldPartyHost.item_effects(data)
	var substatuses: Dictionary = roles["x_substatus"]
	if substatuses.has(item):
		var flag: int = int(substatuses[item])
		if Gen2Substatus.has(user.substatus, flag) and not is_gen1():
			return {"ok": false, "reason": &"item_has_no_effect"}
		user.substatus |= flag
		return {"ok": true, "substatus": flag}
	var stat: String = String((roles["x_stat"] as Dictionary)[item])
	var moved: bool = user.change_stage(stat, 1)
	if moved and is_gen1():
		var side: int = PLAYER if user == mon(PLAYER) else ENEMY
		gen1_stat_moved(side, stat, side)
	return {"ok": true, "stat": stat, "moved": moved}


## `UpdateStatDone`'s tail for a stage moved outside a move: the stat
## recalculated bare, the badges back over all four of the player's, and the
## two penalties on [param user]'s opponent again.
func gen1_stat_moved(side: int, stat: String, user: int) -> void:
	var changed: Gen2BattleMon = mon(side)
	if Gen2BattleMon.STAGED_STATS.has(stat):
		changed.gen1_recalculate_stat(stat)
	if side == PLAYER:
		changed.gen1_apply_badge_boosts()
	mon(opponent_of(user)).gen1_apply_penalties()


## The ITEMMENU_PARTY half in the source's refusal order: a fainted target takes
## only a revive or a PP item, and a revive only a fainted one. [param active]
## decides what `IsItemUsedOnBattleMon` gates.
func _apply_party_item(
	target: Gen2BattleMon, item: int, definition: Dictionary,
	move_slot: int, active: bool
) -> Dictionary:
	var roles: Dictionary = Gen2WorldPartyHost.item_effects(data)
	var revives: Dictionary = roles["revive"]
	if revives.has(item):
		if not target.is_fainted():
			return {"ok": false, "reason": &"item_has_no_effect"}
		target.hp = maxi(target.max_hp() / 2, 1) if bool(revives[item]) else target.max_hp()
		_faint_charged.erase(target.get_instance_id())
		return _with_bitterness(target, item, {"ok": true, "revived": true, "healed": target.hp})
	if (roles["pp_restore"] as Dictionary).has(item):
		return _restore_pp(target, item, move_slot, active)
	if target.is_fainted():
		return {"ok": false, "reason": &"item_has_no_effect"}
	var healed: int = 0
	var heal_amount: int = int(definition.get("heal_amount", 0))
	if heal_amount > 0:
		healed = target.heal(
			target.max_hp() if heal_amount >= Gen2Stats.MAX_STAT_VALUE else heal_amount
		)
	var mask: int = int(definition.get("status_mask", 0))
	var cured: int = target.status & mask
	## `IsItemUsedOnConfusedMon`; Generation 1's Full Heal reads the status byte alone.
	var unconfused: bool = mask == 0xFF and active and not is_gen1() \
		and Gen2Substatus.has(target.substatus, Gen2Substatus.CONFUSED)
	if healed <= 0 and cured == 0 and not unconfused:
		return {"ok": false, "reason": &"item_has_no_effect"}
	if cured != 0:
		target.status = Gen2Status.NONE
		target.toxic_counter = 0
		target.release_stats()
	if active and mask != 0 and not is_gen1():
		_heal_status(target, mask)
	return _with_bitterness(target, item, {
		"ok": true, "healed": healed, "status_cleared": cured, "unconfused": unconfused,
	})


## `HealStatus`: `CalcPlayerStats` runs whether or not a status was cleared.
func _heal_status(target: Gen2BattleMon, mask: int) -> void:
	target.toxic_counter = 0
	target.substatus &= ~Gen2Substatus.NIGHTMARE
	if mask == 0xFF:
		target.substatus &= ~Gen2Substatus.CONFUSED
		target.confusion_turns = 0
	target.release_stats()


## `LooksBitterMessage`'s `ChangeHappiness`, on whichever branch spent the item.
func _with_bitterness(target: Gen2BattleMon, item: int, effect: Dictionary) -> Dictionary:
	if Gen2WorldPartyHost.BITTER_ITEMS.has(item):
		target.happiness = Gen2WorldPartyHost.change_happiness(
			data, target.happiness, int(Gen2WorldPartyHost.BITTER_ITEMS[item])
		)
		effect["bitter"] = true
	return effect


## `BitterBerryEffect` asks for no target: it reads `wPlayerSubStatus3`.
func _cure_confusion() -> Dictionary:
	var user: Gen2BattleMon = mon(PLAYER)
	if user == null or not Gen2Substatus.has(user.substatus, Gen2Substatus.CONFUSED):
		return {"ok": false, "reason": &"item_has_no_effect"}
	user.substatus &= ~Gen2Substatus.CONFUSED
	user.confusion_turns = 0
	return {"ok": true, "unconfused": true}


## Whether a PP item asks which slot to fill: the two Elixers fill every slot and
## ask nothing. [method Gen2WorldPartyHost.item_effects] is what tells the two
## cartridges' item numbers apart, here and in every branch around it.
static func asks_for_move_slot(item_data: GameData, item: int) -> bool:
	var rows: Dictionary = Gen2WorldPartyHost.item_effects(item_data)["pp_restore"]
	return rows.has(item) and not bool(rows[item])


## `RestorePP` fills the party struct, which `BattleRestorePP` copies only into a
## matching slot of the one out; Generation 1 copies all four.
func _restore_pp(target: Gen2BattleMon, item: int, move_slot: int, active: bool) -> Dictionary:
	var every: bool = bool((Gen2WorldPartyHost.item_effects(data)["pp_restore"] as Dictionary)[item])
	var restored: int = 0
	for slot: int in target.moves.size():
		var move: int = target.persistent_move(slot)
		if move <= 0 or (not every and slot != move_slot):
			continue
		var next: int = Gen2WorldPartyHost.pp_after_item(
			data, item, move, target.persistent_pp(slot), target.persistent_pp_ups(slot)
		)
		if next >= 0:
			target.set_persistent_pp(slot, next)
			restored += 1
	if restored <= 0:
		return {"ok": false, "reason": &"item_has_no_effect"}
	if active and is_gen1():
		for slot: int in target.moves.size():
			target.pp[slot] = target.persistent_pp(slot)
	return {"ok": true, "pp_restored": restored}


static func _item_failure(reason: StringName) -> Dictionary:
	return {"ok": false, "kind": &"item_failed", "reason": reason}


## `IsAnyMonHoldingExpShare`: every living party index carrying one, in order.
## Generation 1's is the bag's EXP.ALL: every living index or none.
func _exp_share_holders() -> Array:
	if is_gen1():
		return _living_party_indices() if exp_all_in_bag else []
	var out: Array = []
	var party_side: Gen2Party = party(PLAYER)
	for index: int in party_side.size():
		var member: Gen2BattleMon = party_side.at(index)
		if member != null and not member.is_fainted() \
				and member.item == Gen2Experience.EXP_SHARE_ITEM:
			out.append(index)
	return out


func _give_experience_to(
	learner: Gen2BattleMon, index: int, award: int, stat_gains: Dictionary,
	by_exp_share: bool, events: Array, bystander: bool = false
) -> void:
	learner.gain_exp(award)
	events.append({
		"type": EXP_GAINED, "side": PLAYER, "index": index,
		"species": learner.species, "name": learner.display_name(), "amount": award, "exp": learner.exp,
		# Which pass this came from: a Pokémon in both passes is paid twice.
		"exp_share": by_exp_share,
		# Neither pass: a BYSTANDER SHARE paid a Pokemon that never fought.
		"bystander": bystander,
		# `wStringBuffer2 + 2` and `wGainBoostedExp`: the traded line, and only it.
		"boosted": _is_traded(learner),
	})

	learner.gain_stat_exp(stat_gains)
	if learner.pokerus != 0:
		learner.gain_stat_exp(stat_gains)
	events.append({
		"type": STAT_EXP_GAINED, "side": PLAYER, "index": index, "gains": stat_gains,
	})

	var grew: bool = learner.level < learner.level_for_exp()
	var learned_before: int = (party_log["learned"] as Array).size()
	learner.with_own_record(_raise_levels.bind(learner, index, events))
	if (party_log["learned"] as Array).size() > learned_before:
		_copy_learned_moves(PLAYER, learner, index)
	if grew and index == party(PLAYER).active:
		learner.hold_stats(Gen2BattleMon.HELD_LEVEL_UP)

	## `LevelUpHappinessMod` and the `SmallFarFlagAction SET_FLAG` both sit after
	## `.level_loop`, once an award; `EvolveAfterBattle` runs on the overworld.
	if grew:
		(party_log["grew"] as Array).append(index)
		_gain_level_happiness(learner)
		if not _evolvable.has(index):
			_evolvable.append(index)


## The Pokemon out says each level on its bar and a benched one the last;
## `.level_loop` teaches every level crossed behind them. Generation 1 says
## and teaches the last alone.
func _raise_levels(learner: Gen2BattleMon, index: int, events: Array) -> void:
	var start: int = learner.level
	var target_level: int = learner.level_for_exp()
	var says_each: bool = not is_gen1() and index == party(PLAYER).active
	while learner.level < target_level:
		var old_level: int = learner.level
		var old_stats: Dictionary = learner.stats.duplicate()
		var step_to: int = old_level + 1 if says_each else target_level
		while learner.level < step_to:
			learner.level_up()
		events.append({
			"type": GREW_LEVEL, "side": PLAYER, "index": index, "species": learner.species,
			"name": learner.display_name(),
			"old_level": old_level, "new_level": learner.level,
			"old_stats": old_stats, "new_stats": learner.stats.duplicate(),
		})
	if learner.level == start:
		return
	var first_taught: int = learner.level if is_gen1() else start + 1
	for level: int in range(first_taught, learner.level + 1):
		_offer_moves_learned_at(learner, index, level, events)


func _gain_level_happiness(learner: Gen2BattleMon) -> void:
	learner.happiness = Gen2WorldPartyHost.change_happiness(
		data, learner.happiness, level_up_happiness(data, learner.caught_location, landmark)
	)


## `LevelUpHappinessMod` compares the map the player is on, Crystal alone; Gold
## and Silver inline HAPPINESS_GAINLEVEL.
static func level_up_happiness(game: GameData, caught_location: int, here: int) -> int:
	if Gen2WorldState.is_crystal_profile(game) and here != LANDMARK_NONE and caught_location == here:
		return HAPPINESS_GAINLEVELATHOME
	return HAPPINESS_GAINLEVEL


## What [param learner] is taught at exactly [param level]: into an empty slot
## unasked, or queued for [method learn_move] when every slot is full.
func _offer_moves_learned_at(learner: Gen2BattleMon, index: int, level: int, events: Array) -> void:
	for move: int in data.moves_learned_at(learner.species, level):
		if learner.persistent_moves().has(move):
			continue
		if learner.learn_move(move):
			(party_log["learned"] as Array).append({"index": index, "move": move})
			events.append({
				"type": MOVE_LEARNED, "side": PLAYER, "index": index,
				"species": learner.species, "name": learner.display_name(), "move": move,
				"slot": learner.moves.size() - 1,
			})
		else:
			(_move_learn_queue[PLAYER] as Array).append({
				"index": index, "move": move, "level": level, "species": learner.species,
				"name": learner.display_name(),
			})
			events.append({
				"type": MOVE_OFFERED, "side": PLAYER, "index": index,
				"species": learner.species, "name": learner.display_name(), "move": move, "level": level,
			})


static func _is_switch(action: Dictionary) -> bool:
	return StringName(action.get("type", ACTION_MOVE)) == ACTION_SWITCH


static func _is_run(action: Dictionary) -> bool:
	return StringName(action.get("type", ACTION_MOVE)) == ACTION_RUN


static func _is_item(action: Dictionary) -> bool:
	return StringName(action.get("type", ACTION_MOVE)) == ACTION_ITEM


static func _is_move(action: Dictionary) -> bool:
	return not (_is_switch(action) or _is_run(action) or _is_item(action))


func _run_event(type: StringName, attempt: Dictionary) -> Dictionary:
	var out: Dictionary = attempt.duplicate(true)
	out.erase("outcome")
	out["type"] = type
	out["side"] = PLAYER
	return out


## The move an action commits a side to, Struggle standing in for a switch so
## the order needs no special case. A switching side never uses it.
func _move_for_action(side: int, action: Dictionary) -> int:
	if _is_switch(action) or _is_run(action) or _is_item(action):
		return Gen2Damage.STRUGGLE
	return move_for(side, int(action.get("slot", 0)))


## The slot PP is spent from, not always the one asked for: Encore forces the
## slot it locked in, untested, so `CheckTurn` refuses a disabled one.
func effective_slot(side: int, requested_slot: int) -> int:
	var attacker: Gen2BattleMon = mon(side)
	if attacker.encored_slot >= 0:
		return attacker.encored_slot
	return requested_slot


## Which move a side will actually use: the charged, Rollout or rampage move
## whatever slot was asked for, then Encore's, and Struggle for an empty, spent
## or disabled slot.
func move_for(side: int, slot: int) -> int:
	var attacker: Gen2BattleMon = mon(side)
	if attacker.charged_move != 0:
		return attacker.charged_move
	if Gen2Substatus.has(attacker.substatus, Gen2Substatus.BIDE) and attacker.bide_move != 0:
		return attacker.bide_move
	if Gen2Substatus.has(attacker.substatus, Gen2Substatus.ROLLOUT):
		return Gen2MoveEffect.ROLLOUT_MOVE
	if Gen2Substatus.has(attacker.substatus, Gen2Substatus.RAMPAGING) \
		and attacker.rampage_move != 0:
		return attacker.rampage_move
	var held: int = gen1_trapping_move(side)
	if held != 0:
		return held
	# `.RageCheck`: `USING_RAGE` is never cleared but by a switch, so the user
	# thrashes with RAGE for the rest of its stay, and `PlayerCanExecuteMove`
	# spends no PP on it.
	if is_gen1() and Gen2Substatus.has(attacker.substatus, Gen2Substatus.RAGE):
		return Gen2MoveEffect.RAGE_MOVE
	var chosen_slot: int = effective_slot(side, slot)
	if attacker.encored_slot >= 0 and chosen_slot < attacker.moves.size():
		return int(attacker.moves[chosen_slot])
	return int(attacker.moves[chosen_slot]) if attacker.can_use(chosen_slot) else Gen2Damage.STRUGGLE


func is_gen1() -> bool:
	return data != null and data.generation == RomRegistry.GEN1


## `CheckPlayerLockedIn`, which `BattleTurn` asks before `BattleMenu`: a
## recharge, a charged move, a rampage or a Rollout opens no menu at all.
## `MainInBattleLoop` asks the same of a recharge, Rage, a rampage and a charge.
func player_menu_skipped() -> bool:
	var out: Gen2BattleMon = mon(PLAYER)
	if Gen2Substatus.has(out.substatus, Gen2Substatus.RECHARGING | Gen2Substatus.RAMPAGING):
		return true
	if out.charged_move != 0:
		return true
	if is_gen1():
		return Gen2Substatus.has(out.substatus, Gen2Substatus.RAGE)
	return Gen2Substatus.has(out.substatus, Gen2Substatus.ROLLOUT)


## `BattleMenu_Fight` clears `wNumFleeAttempts` whether or not a move follows.
func fight_chosen() -> void:
	flee_attempts = 0


## `ParsePlayerAction`'s `.encored` and `.locked_in`: no move list under Encore
## or Bide, and on Generation 1 asleep, frozen or bound either way.
func player_move_menu_skipped() -> bool:
	var out: Gen2BattleMon = mon(PLAYER)
	if Gen2Substatus.has(out.substatus, Gen2Substatus.BIDE) or out.encored_slot >= 0:
		return true
	if not is_gen1():
		return false
	return Gen2Status.is_asleep(out.status) \
		or Gen2Status.has(out.status, Gen2Status.FREEZE) \
		or gen1_trapping_move(PLAYER) != 0 or gen1_trapping_move(ENEMY) != 0


## `USING_TRAPPING_MOVE` read from the user's side: while the opponent is bound,
## Generation 1 repeats the move that bound it and spends no PP on the repeat.
## Answers 0 on Generation 2, where a bound target still takes its turn.
func gen1_trapping_move(side: int) -> int:
	if not is_gen1():
		return 0
	return mon(1 - side).trapping_move


## `wCurPlayerMove` was settled at choice time: a Disable or Spite since is
## `CheckTurn`'s and `DoTurn`'s to refuse, not a Struggle.
func _move_to_run(side: int, slot: int) -> int:
	var number: int = move_for(side, slot)
	var chosen: Dictionary = _pending_turn.get("chosen", {})
	if number != Gen2Damage.STRUGGLE or int(chosen.get(side, Gen2Damage.STRUGGLE)) == Gen2Damage.STRUGGLE:
		return number
	var attacker: Gen2BattleMon = mon(side)
	return int(attacker.moves[slot]) if slot >= 0 and slot < attacker.moves.size() else number


## Who goes first. A switch is settled first at any speed, two switches go to
## the player, and otherwise priority, then a Quick Claw, then speed with
## stages applied, then a coin flip.
func order(chosen: Dictionary, actions: Dictionary = {}) -> Array:
	# A failed run is settled before the enemy moves, as a switch is: the turn is
	# spent as BATTLEPLAYERACTION_USEITEM, which resolves at once.
	var player_switching: bool = _is_switch(actions.get(PLAYER, {})) \
		or _is_run(actions.get(PLAYER, {})) \
		or _is_item(actions.get(PLAYER, {}))
	# An enemy item is `wEnemyGoesFirst` for the same reason an enemy switch is,
	# and both lose to a player switch, which was settled at menu time.
	var enemy_switching: bool = _is_switch(actions.get(ENEMY, {})) \
		or _is_item(actions.get(ENEMY, {}))
	if player_switching or enemy_switching:
		return _sides(player_switching)
	if is_gen1():
		return _gen1_order(chosen)

	var player_priority: int = priority_of(data.move(int(chosen[PLAYER])))
	var enemy_priority: int = priority_of(data.move(int(chosen[ENEMY])))
	if player_priority != enemy_priority:
		return _sides(player_priority > enemy_priority)

	var claw: Variant = _quick_claw()
	if claw != null:
		return _sides(bool(claw))

	var player_speed: int = player.stat("speed")
	var enemy_speed: int = enemy.stat("speed")
	if player_speed != enemy_speed:
		return _sides(player_speed > enemy_speed)

	return _sides(rng.randi_range(0, 255) < 128)


## `MainInBattleLoop` from `.noLinkBattle`: a priority is a move number, both
## effect bytes being NO_ADDITIONAL_EFFECT, then speed, then one byte.
func _gen1_order(chosen: Dictionary) -> Array:
	var player_move: int = int(chosen[PLAYER])
	var enemy_move: int = int(chosen[ENEMY])
	for priority: Array in GEN1_PRIORITY_MOVES:
		var move: int = int(priority[0])
		if (player_move == move) != (enemy_move == move):
			return _sides((player_move == move) == bool(priority[1]))
	var player_speed: int = player.stat("speed")
	var enemy_speed: int = enemy.stat("speed")
	if player_speed != enemy_speed:
		return _sides(player_speed > enemy_speed)
	return _sides(rng.randi_range(0, 255) < GEN1_TIE_BOUND)


## `DetermineMoveOrder`'s `.equal_priority` block: true for the player first,
## false for the enemy, null for a claw that said nothing, which falls through to
## speed. The player's claw is rolled first and the enemy's only when the player
## has none, except that with one on each side the enemy's roll is taken first.
func _quick_claw() -> Variant:
	var player_claw: bool = _held_effect(mon(PLAYER)) == Gen2HeldItem.QUICK_CLAW
	var enemy_claw: bool = _held_effect(mon(ENEMY)) == Gen2HeldItem.QUICK_CLAW
	if not player_claw and not enemy_claw:
		return null

	if player_claw and not enemy_claw:
		if _claw_fires(mon(PLAYER)):
			return true
		return null
	if enemy_claw and not player_claw:
		if _claw_fires(mon(ENEMY)):
			return false
		return null

	# `.both_have_quick_claw`: two rolls, the enemy's read first, and the player
	# only wins on its own roll after the enemy's has already come up short.
	if _claw_fires(mon(ENEMY)):
		return false
	if _claw_fires(mon(PLAYER)):
		return true
	return null


func _claw_fires(battler: Gen2BattleMon) -> bool:
	return Gen2HeldItem.rolls_under(rng, Gen2HeldItem.parameter_of(data, battler.item))


func _sides(player_first: bool) -> Array:
	return [PLAYER, ENEMY] if player_first else [ENEMY, PLAYER]


static func priority_of(move: Dictionary) -> int:
	if int(move.get("number", 0)) == VITAL_THROW:
		return 0
	return int(EFFECT_PRIORITIES.get(int(move.get("effect", -1)), BASE_PRIORITY))


## One side's move, as the list of commands its effect is made of: the effect byte
## picks a sequence out of [Gen2MoveEffect] and its commands run against a
## [Gen2Turn] until one ends the move. Announcing, spending, rolling, applying and
## fainting are all commands, which is why no move lives here.
func _act(side: int, slot: int, move_number: int, events: Array) -> void:
	var move: Dictionary = data.move(move_number)
	if move.is_empty():
		return

	var turn: Gen2Turn = Gen2Turn.create(self, side, slot, move_number, move, events)
	# The release turn of a two-turn move, or any Rollout/rampage continuation:
	# the PP was already spent on the first turn, and
	# [method Gen2EffectCommands._do_turn] reads this so it is not spent again.
	var active_substatus: int = mon(side).substatus
	turn.locked = (
		mon(side).charged_move == move_number
		or Gen2Substatus.has(active_substatus, Gen2Substatus.ROLLOUT)
		or Gen2Substatus.has(active_substatus, Gen2Substatus.RAMPAGING)
		or Gen2Substatus.has(active_substatus, Gen2Substatus.BIDE)
		or gen1_trapping_move(side) == move_number
		or (is_gen1() and Gen2Substatus.has(active_substatus, Gen2Substatus.RAGE))
	) and move_number != 0

	if _gen1_ghost_holds(turn):
		return
	# Whether the Pokémon can move at all is asked before the effect is looked up,
	# which is the cartridge's arrangement: every move goes through it, so no
	# sequence has to remember to include it.
	Gen2EffectCommands.run(Gen2EffectCommands.CHECK_STATUS, turn)
	run_move_effect(turn)


## `PrintGhostText`: a sleeping or frozen player reads its own status line instead.
func _gen1_ghost_holds(turn: Gen2Turn) -> bool:
	if not gen1_ghost:
		return false
	if turn.side == PLAYER:
		var status: int = mon(PLAYER).status
		if Gen2Status.is_asleep(status) or (status & Gen2Status.FREEZE) != 0:
			return false
		turn.emit(CANNOT_MOVE, {"reason": &"scared"})
	else:
		turn.emit(CANNOT_MOVE, {"reason": &"get_out"})
	turn.end()
	return true


## `DoMove`'s read cycle over the list an effect byte picks, with
## `SkipToBattleCommand` and `endloop`'s rewind. `ResetTurn` (Metronome, Mirror
## Move, Sleep Talk) is a fresh [Gen2Turn] over the called move.
func run_move_effect(turn: Gen2Turn, depth: int = 0) -> void:
	if turn.ended:
		return
	Gen2EffectCommands.check_obedience(turn)
	var sequence: Array = Gen2MoveEffect.sequence_for(
		turn.effect(), data.generation if data != null else RomRegistry.GEN2
	)
	var counter: int = 0
	while counter < sequence.size():
		if turn.ended:
			return
		var command: StringName = sequence[counter]
		counter += 1
		# `SkipToBattleCommand` walks the pointer past the byte it matched, so
		# the command it was sent to find is not run either.
		if turn.skip_to != &"":
			if command == turn.skip_to:
				turn.skip_to = &""
			continue
		if trace_commands:
			command_trace.append(command)
		Gen2EffectCommands.run(command, turn)
		if turn.ended:
			return
		if turn.loop_back:
			# `.loop_back_to_critical` scans down for `critical` and resumes on
			# it, not behind it.
			turn.loop_back = false
			# `jp nz, GetPlayerAnimationType`: Generation 1 works the damage and
			# the hit out once and replays the animation and the hit alone.
			var back: int = sequence.rfind(
				Gen2EffectCommands.MOVE_ANIM_NO_SUB if is_gen1() else Gen2EffectCommands.CRITICAL,
				counter - 1
			)
			if back < 0:
				push_error("a looping effect has no critical to return to")
				return
			counter = back
			continue
		if turn.called_move_number == 0:
			continue
		if depth >= 16:
			turn.emit(MOVE_FAILED)
			turn.end()
			return
		var number: int = turn.called_move_number
		var called_move: Dictionary = data.move(number)
		if called_move.is_empty():
			turn.emit(MOVE_FAILED)
			turn.end()
			return
		var called_turn: Gen2Turn = Gen2Turn.create(
			self, turn.side, -1, number, called_move, turn.events
		)
		called_turn.called = true
		run_move_effect(called_turn, depth + 1)
		return


## `PlayBattleMusic` with `RegionCheck` and `IsGymLeader`, kept here because
## every input is battle state. `MUSIC_SUICUNE_BATTLE` is Crystal's alone: Gold
## and Silver never write the two `BATTLETYPE_` rows that reach it.
const MUSIC_NONE: int = 0x00
const MUSIC_KANTO_GYM_LEADER_BATTLE: int = 0x06
const MUSIC_KANTO_TRAINER_BATTLE: int = 0x07
const MUSIC_KANTO_WILD_BATTLE: int = 0x08
const MUSIC_JOHTO_WILD_BATTLE: int = 0x29
const MUSIC_JOHTO_TRAINER_BATTLE: int = 0x2A
const MUSIC_JOHTO_GYM_LEADER_BATTLE: int = 0x2E
const MUSIC_CHAMPION_BATTLE: int = 0x2F
const MUSIC_RIVAL_BATTLE: int = 0x30
const MUSIC_ROCKET_BATTLE: int = 0x31
## `PlayVictoryMusic`'s three.
const MUSIC_TRAINER_VICTORY: int = 0x11
const MUSIC_WILD_VICTORY: int = 0x12
const MUSIC_GYM_VICTORY: int = 0x13
const MUSIC_JOHTO_WILD_BATTLE_NIGHT: int = 0x4A
const MUSIC_CAPTURE: int = 0x4C  ## `Text_GotchaMonWasCaught`'s.
const MUSIC_SUICUNE_BATTLE: int = 0x64

## constants/trainer_constants.asm. The `trainerclass` indexes agree byte for
## byte between the two pins, so there is no profile conversion here.
const TRAINER_CLASS_RIVAL1: int = 0x09
const TRAINER_CLASS_CHAMPION: int = 0x10
const TRAINER_CLASS_GRUNTM: int = 0x1F
const TRAINER_CLASS_RIVAL2: int = 0x2A
const TRAINER_CLASS_RED: int = 0x3F
const TRAINER_CLASS_GRUNTF: int = 0x42
## `RIVAL2_2_CHIKORITA`. `trainerclass` restarts the id count at 1, so the
## Indigo Plateau rematch is the fourth id of the class and `jr c, .done` keeps
## the three below it on `MUSIC_RIVAL_BATTLE`.
const TRAINER_ID_RIVAL2_2_CHIKORITA: int = 4

## `data/trainers/leaders.asm`. `GymLeaders` falls through into
## `KantoGymLeaders`, so `IsGymLeader` matches both rows and `IsKantoGymLeader`
## only the second. CHAMPION and RED sit in the first list and are unreachable
## from the music check, which the file's own comment says.
const KANTO_GYM_LEADERS: Array[int] = [
	0x11, 0x12, 0x13, 0x15, 0x1A, 0x23, 0x2E, 0x40,
]
const JOHTO_GYM_LEADERS: Array[int] = [
	0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
	0x0B, 0x0D, 0x0E, 0x0F, TRAINER_CLASS_CHAMPION, TRAINER_CLASS_RED,
]

## A landmark no map has, so an untold battle matches nobody's caught location.
const LANDMARK_NONE: int = -1

## `constants/pokemon_data_constants.asm`, one-based the way `ChangeHappiness`
## takes it. Gold and Silver ship neither the second row nor the compare in
## front of it: their `.skip_active_mon_update` passes HAPPINESS_GAINLEVEL flat.
const HAPPINESS_GAINLEVEL: int = 0x01
const HAPPINESS_USEDITEM: int = 0x02
const HAPPINESS_USEDXITEM: int = 0x03
const HAPPINESS_GYMBATTLE: int = 0x04
const HAPPINESS_FAINTED: int = 0x06
const HAPPINESS_POISONFAINT: int = 0x07
const HAPPINESS_BEATENBYSTRONGFOE: int = 0x08
const HAPPINESS_OLDERCUT1: int = 0x09
const HAPPINESS_OLDERCUT2: int = 0x0A
const HAPPINESS_OLDERCUT3: int = 0x0B
const HAPPINESS_YOUNGCUT1: int = 0x0C
const HAPPINESS_YOUNGCUT2: int = 0x0D
const HAPPINESS_YOUNGCUT3: int = 0x0E
const HAPPINESS_BITTERPOWDER: int = 0x0F
const HAPPINESS_ENERGYROOT: int = 0x10
const HAPPINESS_REVIVALHERB: int = 0x11
const HAPPINESS_GROOMING: int = 0x12
const HAPPINESS_GAINLEVELATHOME: int = 0x13


## constants/landmark_constants.asm, Crystal-canonical like
## [constant Gen2WorldRadio.KANTO_LANDMARK], which is where the Gold and Silver
## conversion lives.
const LANDMARK_VICTORY_ROAD: int = 0x58


## `RegionCheck`, which is not `IsInJohto`: the Fast Ship, everything below
## `KANTO_LANDMARK` and Victory Road up count as Johto, `jr c, .kanto` taking
## Kanto below that row alone. The landmark arrives through `landmark_backup`.
static func region_is_kanto(landmark_id: int, crystal: bool = true) -> bool:
	if landmark_id == Gen2WorldRadio.fast_ship_landmark(crystal):
		return false
	if landmark_id < Gen2WorldRadio.kanto_landmark(crystal):
		return false
	return landmark_id < Gen2WorldRadio.profile_landmark(LANDMARK_VICTORY_ROAD, crystal)


## `PlayBattleMusic`'s answer: the track a battle opens on.
## [param landmark_id] is `GetWorldMapLocation`'s, [param trainer_class] and
## [param trainer_id] are `wOtherTrainerClass` and `wOtherTrainerID` (class 0
## being a wild fight), and [param day_period] is `wTimeOfDay`.
static func battle_music(
	battle_kind: int,
	trainer_class: int,
	trainer_id: int,
	landmark_id: int,
	day_period: int,
	crystal: bool = true,
) -> int:
	# `ld de, MUSIC_SUICUNE_BATTLE` sits in front of both compares, so the
	# roaming branch reaches `.done` with the same track still in `de`.
	if battle_kind == BATTLETYPE_SUICUNE or battle_kind == BATTLETYPE_ROAMING:
		return MUSIC_SUICUNE_BATTLE
	var kanto: bool = region_is_kanto(landmark_id, crystal)
	if trainer_class <= 0:
		if kanto:
			return MUSIC_KANTO_WILD_BATTLE
		return MUSIC_JOHTO_WILD_BATTLE_NIGHT \
			if day_period == Gen2WorldPalette.TIME_NIGHT else MUSIC_JOHTO_WILD_BATTLE
	if trainer_class == TRAINER_CLASS_CHAMPION or trainer_class == TRAINER_CLASS_RED:
		return MUSIC_CHAMPION_BATTLE
	# `docs/bugs_and_glitches.md`: only the two grunt classes reach the Rocket
	# track, so an Executive or a Scientist falls through to the trainer rows.
	if trainer_class == TRAINER_CLASS_GRUNTM or trainer_class == TRAINER_CLASS_GRUNTF:
		return MUSIC_ROCKET_BATTLE
	if KANTO_GYM_LEADERS.has(trainer_class):
		return MUSIC_KANTO_GYM_LEADER_BATTLE
	if JOHTO_GYM_LEADERS.has(trainer_class):
		return MUSIC_JOHTO_GYM_LEADER_BATTLE
	if trainer_class == TRAINER_CLASS_RIVAL1:
		return MUSIC_RIVAL_BATTLE
	if trainer_class == TRAINER_CLASS_RIVAL2:
		return MUSIC_CHAMPION_BATTLE \
			if trainer_id >= TRAINER_ID_RIVAL2_2_CHIKORITA else MUSIC_RIVAL_BATTLE
	return MUSIC_KANTO_TRAINER_BATTLE if kanto else MUSIC_JOHTO_TRAINER_BATTLE
