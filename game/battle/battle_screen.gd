class_name Gen2BattleScreen
extends Control

signal battle_finished(result: Dictionary)
signal capture_requested(ball: int)
## `NewPokedexEntry` behind `Text_GotchaMonWasCaught`: the page belongs to the
## world, which owns the dex, so the battle asks for it and waits.
signal dex_entry_requested(species: int)
## A bag item spent inside the battle, so the world takes one off the pocket.
## `target` is the party index an ITEMMENU_PARTY item was used on, or -1.
signal item_used(item: int, target: int)
## `LoadEnemyMon`'s own `wPokedexSeen` write (engine/battle/core.asm:6407). Every
## enemy sent out sets it, a trainer's party as much as a wild, so this is the
## event rather than the battle result. The host owns the flag, since the battle
## engine is scene-free and holds no world state.
signal enemy_seen(species: int, unown_form: int)

## Owns the battle, the events and the text box; decides nothing about how they
## are drawn. A [Gen2Battle] resolves the turn and answers with events; this shows
## them one at a time, reading every number out of the event rather than asking
## the engine again. Presentation is a registered renderer, the same boundary the
## overworld's map goes through, with the text box staying hardware pixels over it.

## `anim_sound` and `anim_cry` have to reach a player, and a battle had none:
## this is the world screen's own route (`game/world/world_screen.gd`).
const AUDIO_PLAYER_SCRIPT := preload("res://game/audio/gen2_audio_player.gd")

## What is on screen before a caller says otherwise: the first battle a player
## of Gold or Silver is likely to have.
const DEFAULT_ENEMY: int = 16
const DEFAULT_PLAYER: int = 155
const DEFAULT_LEVEL: int = 5

## How many Pokémon [method _party_from] makes up for the fallback development
## matchup. A validated save supplies the player's real party instead.
const PARTY_SIZE: int = 2

## What a status says when it stops a Pokémon moving, and when it lands on one.
## Keyed by the names [Gen2Status] answers with, so a status the engine grows
## later shows up here as a missing key rather than as a wrong sentence.
const STOPPED_BY: Dictionary = {
	&"ignored_sleeping": "ignored orders…sleeping!",
	&"began_to_nap": "began to nap!",
	&"loafing": "is loafing around!",
	&"wont_obey": "won't obey!",
	&"turned_away": "turned away!",
	&"ignored_orders": "ignored orders!",
	&"sleep": "is fast asleep!",
	&"freeze": "is frozen solid!",
	&"paralysis": "is fully paralyzed!",
	&"flinch": "flinched!",
	&"recharge": "must recharge!",
	&"disabled": "is disabled!",
	&"attract": "is immobilized by love!",
	## `_CantMoveText`, Generation 1's alone: the target of a trapping move
	## spends every turn of it held in place.
	&"held_in_place": "can't move!",
}

const INFLICTED: Dictionary = {
	&"sleep": "fell asleep!",
	&"poison": "was poisoned!",
	&"toxic": "was badly poisoned!",
	&"burn": "was burned!",
	&"freeze": "was frozen solid!",
	&"paralysis": "is paralyzed!",
}

## What a two-turn move says on its charge turn, from
## `BattleCommand_Charge.UsedText` (data/text/common_2.asm), which picks its line
## by move number rather than by effect: Fly and Dig share an effect byte and do
## not share a sentence.
##
## The source's own `line` is a line break in a fixed-width box rather than part
## of the sentence, so these read as one flowing string the way every other
## message here does.
const CHARGE_TEXT: Dictionary = {
	Gen2MoveEffect.RAZOR_WIND_MOVE: "made a whirlwind!",
	Gen2MoveEffect.SOLARBEAM_MOVE: "took in sunlight!",
	Gen2MoveEffect.SKULL_BASH_MOVE: "lowered its head!",
	Gen2MoveEffect.SKY_ATTACK_MOVE: "is glowing!",
	Gen2MoveEffect.FLY_MOVE: "flew up high!",
	Gen2MoveEffect.DIG_MOVE: "dug a hole!",
}
## `.UsedText`'s own fallthrough: the Dig branch is the only one of the six with
## no `jr z` behind it, so a move that is none of the other five prints its line.
const CHARGE_DUG: String = "dug a hole!"

## The word the games print for a stat, keyed the way [Gen2BattleMon] keeps the
## stat itself. A key the engine grows later shows up here as its own snake_case
## name in capitals rather than as a wrong word, the same fallback
## [method _battler_name] gives a status it does not recognise.
const STAT_NAMES: Dictionary = {
	"attack": "ATTACK",
	"defense": "DEFENSE",
	"speed": "SPEED",
	"sp_attack": "SP.ATK",
	"sp_defense": "SP.DEF",
	"accuracy": "ACCURACY",
	"evasion": "EVASIVENESS",
	# `StatNames`' eighth row, which no stat uses: `BattleCommand_Curse` names it
	# when neither Attack nor Defense can rise.
	"ability": "ABILITY",
}

## The three trapping moves whose landing line spells the move out, since
## `BattleCommand_TrapTarget`'s `.Traps` table writes them into the text rather
## than reading a name buffer. Fire Spin and Whirlpool share the line that names
## nothing, so neither needs a number here.
const BIND: int = 20
const WRAP: int = 35
const CLAMP: int = 128

## The three lines each weather has, which are the cartridge's own and are keyed
## by the weather rather than by the move: `HandleWeather`'s `.WeatherMessages`
## and `.WeatherEndedMessages`, plus each setter's own.
const WEATHER_STARTED_TEXT: Dictionary = {
	Gen2Weather.RAIN: "A downpour started!",
	Gen2Weather.SUN: "The sunlight got bright!",
	Gen2Weather.SANDSTORM: "A SANDSTORM brewed!",
}
const WEATHER_CONTINUES_TEXT: Dictionary = {
	Gen2Weather.RAIN: "Rain continues to fall.",
	Gen2Weather.SUN: "The sunlight is strong.",
	Gen2Weather.SANDSTORM: "The SANDSTORM rages.",
}
const WEATHER_ENDED_TEXT: Dictionary = {
	Gen2Weather.RAIN: "The rain stopped.",
	Gen2Weather.SUN: "The sunlight faded.",
	Gen2Weather.SANDSTORM: "The SANDSTORM subsided.",
}

## The two lines each screen has. The set lines are `BattleCommand_Screen`'s and
## `BattleCommand_Safeguard`'s own, which describe the stat rather than the
## screen. The faded lines are `HandleScreens`', and they name the side rather
## than the Pokémon: `.Copy` fills `wStringBuffer1` with "Your" or "Enemy" ahead
## of " #MON's", which is the wording that fits a screen outliving whoever put it
## up. `HandleSafeguard`'s is the odd one and is a plain `<USER>`.
const SCREEN_SET_TEXT: Dictionary = {
	Gen2Screens.LIGHT_SCREEN: "%s's SPCL.DEF rose!",
	Gen2Screens.REFLECT: "%s's DEFENSE rose!",
	Gen2Screens.SAFEGUARD: "%s's covered by a veil!",
}
const SCREEN_FADED_TEXT: Dictionary = {
	Gen2Screens.LIGHT_SCREEN: "%s's LIGHT SCREEN fell!",
	Gen2Screens.REFLECT: "%s's REFLECT faded!",
}

const DUDE_NAME: String = "DUDE"

## `CatchTutorial.LoadDudeData`: one POTION, and five POKE BALLs because
## `ld a, POKE_BALL` writes the quantity byte too.
const DUDE_PACK: Array[int] = [
	Gen2WorldPartyHost.ITEM_POTION, Gen2WorldPartyHost.ITEM_POKE_BALL,
]
const DUDE_PACK_QUANTITIES: Dictionary = {
	Gen2WorldPartyHost.ITEM_POTION: 1,
	Gen2WorldPartyHost.ITEM_POKE_BALL: Gen2WorldPartyHost.ITEM_POKE_BALL,
}

## `DudeAutoInputs`: a button and the byte after it, held for one `GetJoypad`
## poll more than its value (`home/joypad.asm`'s `.auto`), which is not a frame.
## See [constant DUDE_POLLS_PER_FRAME].
const DUDE_AUTO_INPUT: Dictionary = {
	&"text": [[PokeButton.NONE, 0x50], [PokeButton.A, 0x00]],
	&"pack": [
		[PokeButton.NONE, 0x08], [PokeButton.RIGHT, 0x00],
		[PokeButton.NONE, 0x08], [PokeButton.A, 0x00],
	],
	&"menu": [
		[PokeButton.NONE, 0xFE], [PokeButton.NONE, 0xFE], [PokeButton.NONE, 0xFE],
		[PokeButton.NONE, 0xFE], [PokeButton.DOWN, 0x00],
		[PokeButton.NONE, 0xFE], [PokeButton.NONE, 0xFE], [PokeButton.NONE, 0xFE],
		[PokeButton.NONE, 0xFE], [PokeButton.A, 0x00],
	],
}

## Polls one frame of each stage is worth: `.wait_input` spends a `DelayFrame` a
## pass and `Do2DMenuRTCJoypad.loopRTC` spends none. Measured on a cartridge
## through Route 29's tutorial, from the `_DudeAutoInput_*` call: A lands on
## frame 80 of the text stream, DOWN on 29 and A on 53 of the menu's, RIGHT on 51
## and A on 102 of the pack's.
const DUDE_POLLS_PER_FRAME: Dictionary = {
	&"text": 1.0, &"menu": 36.0, &"pack": 0.176,
}

var _data: GameData = null
var _injected_data: GameData = null
## Whatever the mod host supplies. Typed as Node because a registered renderer
## only has to satisfy Gen2ModHost.BATTLE_RENDERER_METHODS, not extend the
## built-in one.
var _renderer: Node = null
var _renderer_ready: bool = false:
	set(value):
		_renderer_ready = value
		_gate_annotations()

## The battle behind the screen, and the two Pokémon in it. The display state
## below is what is currently drawn, which is not always where the battle has
## got to: a turn resolves at once and is then shown an event at a time.
var _battle: Gen2Battle = null
var _pending: Array = []
var _rng := RandomNumberGenerator.new()
## Whether something else owns the funnel every button arrives through. Set while
## this screen is an overlay inside the overworld, so a press is recorded once, by
## the world, and a replayed log reaches the fight: see
## [method Gen2WorldScreen.press_button] and `tools/replay_world.gd`.
## Whether the screen that opened this one owns its input and its frames. See
## [method set_driven].
var _driven: bool = false
var _save_slot: int = -1
var _save_written: bool = false
var _source_save: Gen2SaveData = null
var _world_battle_active: bool = false
var _world_battle_tutorial: bool = false
var _world_battle_request: Dictionary = {}
## The run's rules, handed over by whoever opened this screen. A development
## battle has none and plays the installed set.
var _injected_rules: Gen2Rules = null
var _world_battle_completion_sent: bool = false
var _world_battle_result_picture_shown: bool = false
var _world_battle_terminal_text_shown: bool = false
var _world_battle_recovery_shown: bool = false
var _world_battle_recovery: Dictionary = {}
## `.give_money` and `CheckPayDay`, the two credits the way out of a won battle
## pays. Computed once by [method _earnings] and then read by the snapshot
## [method _save_battle_result] writes, by the line that announces the prize and
## by the completion result the world credits its live state from, so no two of
## the three can disagree about what the fight was worth.
var _earnings_computed: Dictionary = {}
var _prize_text_shown: bool = false
var _pay_day_text_shown: bool = false
var _last_message: String = ""
## A running [Gen2HpBarAnimation] per side. A side with no entry is not moving.
var _bars: Dictionary = {}
## `MonFaintedAnimation`s still running, oldest first. A double faint runs two,
## one after the other, the way the source's two calls do.
var _faints: Array[Dictionary] = []
## The running [Gen2ExpBarAnimation], or null when the exp bar is not filling.
var _exp_bar: Gen2ExpBarAnimation = null
## The running [Gen2BattleIntro], or null once the pics have slid into place.
var _intro: Gen2BattleIntro = null:
	set(value):
		_intro = value
		_gate_annotations()
## What `BattleStartMessage` will say. It is held for the whole slide, because
## `InitBattleDisplay` returns before it is called and the box drawn before the
## slide is an empty one.
var _intro_message: String = ""
## `BattleStartMessage` and `DoBattle`'s own opening, one step per entry, spent
## once the pics have finished sliding. See [method _build_entrance].
var _entrance_stages: Array[Dictionary] = []
## Which panel is on the map. `InitBattleDisplay` clears the player's box and its
## caller only reaches `UpdateEnemyHUD` for a wild battle, so a battle opens with
## neither: the enemy's arrives when the opening line is pressed past (wild) or
## when the trainer has sent something out, and the player's inside
## `SendOutPlayerMon`.
var _enemy_hud_visible: bool = true
var _player_hud_visible: bool = true
## `GetTrainerBackpic`: which of the player's own pictures is standing on the
## player's square, empty once a Pokemon has taken it.
var _player_backpic: String = ""
## `InitEnemyTrainer`'s `PlaceGraphic`: the trainer class whose picture is on the
## enemy's square, zero once that trainer has sent something out.
var _enemy_trainer_pic: int = 0
## `LoadTrainerHudOAM`'s six sprites a side and the border they hang in.
var _hud_balls: Array = []
var _hud_border: Array = []
## `SlideBattlePicOut`, one entry per square still sliding off.
var _slides: Array[Dictionary] = []
## How far each square's picture has walked off it, in pixels along x, signed the
## way the walk goes: the player leaves to the left and the opponent to the
## right. Kept after the walk ends rather than dropped with the slide's entry,
## because the picture stays off the square until the ball puts a Pokemon there;
## that stretch is the `none` [method battler_side] reports.
var _slid_pixels: Dictionary = {Gen2Battle.PLAYER: 0.0, Gen2Battle.ENEMY: 0.0}
## What the tilemap effects last did to each battler's picture, carried past the
## animation that did it: `BattleBGEffect_HideMon` leaves a Fly or Dig user off
## the field for a turn, and `..._RemoveMon` leaves a recalled Pokemon off the
## square until the next send-out. The anim background reports both while it runs
## and this is where they outlive it; see [method battler_side].
var _battler_visible: Dictionary = {Gen2Battle.PLAYER: true, Gen2Battle.ENEMY: true}
var _battler_scale: Dictionary = {Gen2Battle.PLAYER: 1.0, Gen2Battle.ENEMY: 1.0}
var _battler_shift: Dictionary = {
	Gen2Battle.PLAYER: Vector2.ZERO, Gen2Battle.ENEMY: Vector2.ZERO,
}
## `AnimateFrontpic` over the enemy's square, or null when none is running.
var _frontpic: Gen2PicAnimation = null
## `wAttrmap` bit 3, which `PokeAnim_SetVBank1` sets over that square while the
## animation runs and `PokeAnim_SetVBank0` clears in `PokeAnim_DeinitFrames`. It
## is the whole reason the animation's tile numbers may sit on top of the
## player's: bank 1 holds the enemy's picture and its frames and nothing else.
var _bg_vbank1: PackedByteArray = PackedByteArray()
## The text the event pump produced while a bar was still draining. The source
## prints it after the bar arrives, since `applydamage` runs before
## `criticaltext` and `supereffectivetext`.
var _held_message: String = ""
## Whether the box is holding a line nobody has pressed past yet. Only a box
## waits for a button in `DoMove`'s loop, so this is what tells the frame pump
## that the run of frames it just finished owes a press rather than the next
## command; see [method _resume_after_frames].
var _message_awaits_press: bool = false
## `wAutoInputAddress`, `wAutoInputLength` and `wInputType`, in that order.
var _auto_input: Array = []
var _auto_input_index: int = 0
var _auto_input_delay: int = 0
var _auto_input_stage: StringName = &""
var _auto_input_polls: float = 0.0
## The bars' and the intro's clock: see [method _process].
var _frame_clock := Gen2WorldAnimation.FrameClock.new()
## The same, for the party page's icons. Kept apart because they animate while
## nothing else does, and [method frames_running] must stay false there: a
## caller draining frames to a terminal state would never reach one.
var _icon_clock := Gen2WorldAnimation.FrameClock.new()
## What the overworld clock said when the battle started, for the three heals
## that read it. Only the world path supplies one; the development drivers below
## leave [Gen2Battle] at its own midday default.
var _time_of_day: int = Gen2WorldPalette.TIME_DAY
## Where the battle is being fought, for a renderer that draws the place rather
## than a white field. Null unless the caller supplied one; see
## [method set_world_context].
var _world_context: Gen2BattleWorldContext = null
## `BattlePack`'s own rows and cursor, and the item held while
## `UseItem_SelectMon` picks a target for it.
var _pack_rows: Array[int] = []
var _pack_quantities: Dictionary = {}
var _pack_index: int = 0
## `wMenuScrollPosition` for each list that can outgrow its window, kept apart so
## a sub-list opened over the pack does not move the pack's own.
var _list_scroll: Dictionary = {}
var _pack_selecting: bool = false:
	set(value):
		_pack_selecting = value
		_list_state_changed()
var _pack_item: int = 0
## `RestorePPEffect`'s own `.loop`, which asks which move before it restores
## anything. Only the three items that fill one slot ever open it.
var _pack_move_slots: Array = []
var _pack_move_index: int = 0
var _pack_move_target: int = -1
var _pack_move_selecting: bool = false:
	set(value):
		_pack_move_selecting = value
		_list_state_changed()

var _capture_balls: Array[int] = []
var _capture_quantities: Dictionary = {}
var _capture_ball_index: int = 0
## `ItemSubmenu`, which stands between a pack row and its effect. Empty when no
## submenu is up; `&"pack"` and `&"capture"` name the list it was opened over.
var _pack_action_stage: StringName = &""
var _pack_action_index: int = 0
## The action `.UseItem` returning with `wBattlePlayerAction` still
## BATTLEPLAYERACTION_USEITEM owes the enemy. Empty when the throw was refused
## before `_DoItemEffect` ran, which is what `.didnt_use_item` takes it back to.
var _capture_spent_turn: Dictionary = {}
## Which list the ball was chosen from, so a refused throw reopens it the way
## `.didnt_use_item` drops back into the pack it was still standing in.
var _capture_origin: StringName = &"capture"
## What [method begin_capture] says instead of opening, when the run's rules
## forbid a catch in this fight. Empty means the selector opens.
var _capture_refusal: String = ""
var _capture_selecting: bool = false:
	set(value):
		_capture_selecting = value
		_list_state_changed()
var _capture_waiting: bool = false
var _capture_messages: Array[String] = []
## The [constant Gen2Battle.CAUGHT] event built by [method complete_capture] and
## published on the box that prints its Gotcha line, so a subscriber has moved
## before the nickname prompt opens.
var _capture_caught_event: Dictionary = {}
var _capture_terminal: bool = false
## Whether `DisplayAlreadyCaughtText` has been said for this throw. The line
## comes once, before the switch question, and the question is asked again on
## every pump until it is answered.
var _contest_already_caught_said: bool = false
## Whether this capture's experience award has already run. See
## [method _spend_capture_experience].
var _capture_experience_spent: bool = false
## The layer registered battle-information providers draw on, and the page that
## writes their placements. See [method info_snapshot].
var _annotation_layer: TextureRect = null
## The interface field the flagged placements asked for, drawn under the ink.
## See [method _refresh_annotations].
var _annotation_field_layer: TextureRect = null
var _annotations: Gen2BattleAnnotations = null
## What [method _annotations_visible] last answered when the layer was built, so
## a modal that opens or closes is noticed by [method _gate_annotations] rather
## than by whichever caller happened to remember to refresh.
var _annotations_ungated: bool = false
## What the layer is currently holding, so it is rebuilt only when a provider
## would answer something different. Same shape as [member _menu_drawn].
var _annotations_drawn: String = ""
## Whether the enemy species was in this save's Pokedex before the battle began,
## read once at the start because the first sight of it registers immediately.
var _enemy_seen_before: bool = false
## `CheckCaughtMon` and `CheckReceivedDex`, both read before the throw registers
## anything: a species already in the dex adds no data, and a player who has not
## been handed the dex is shown no page at all.
var _enemy_caught_before: bool = false
var _dex_received: bool = false
## How far `NewDexDataText` and the page behind it have got. Empty until the
## catch is terminal.
var _capture_dex_stage: StringName = &""
var _capture_result: Dictionary = {}
## `PokeBallEffect`'s own `AskGiveNicknameText`, which stands over the battle
## because the whole routine runs inside it. Null while nothing is being named.
var _capture_nickname_host: Gen2NicknamePromptScreen = null:
	set(value):
		_capture_nickname_host = value
		_gate_annotations()
## `wStringBuffer1` after `InitName`: the species name until the player answers
## the naming screen with something else.
var _capture_nickname: String = ""
## Whether the prompt for the catch now on screen has already been answered, so
## the pump finishes the capture instead of asking twice.
var _capture_nickname_asked: bool = false

## Where a level-up's move offer has got to, following LearnMove and ForgetMove
## (engine/pokemon/learn.asm): [code]&"ask"[/code] is AskForgetMoveText's yes/no,
## [code]&"list"[/code] ForgetMove's own .loop, [code]&"stop"[/code]
## LearnMove.cancel's StopLearningMoveText. Empty when nothing is pending.
var _forget_stage: StringName = &"":
	set(value):
		_forget_stage = value
		_list_state_changed()
var _forget_moves: Array = []
var _forget_cursor: int = 0
var _forget_confirm_cursor: int = 0

## Where a switch has got to. [code]&"offer"[/code] is `OfferSwitch`'s
## `PlaceYesNoBox`, [code]&"use_next"[/code] `AskUseNextPokemon`'s own box in the
## same place, and [code]&"pick"[/code] the party menu `SetUpBattlePartyMenu`
## puts up behind either, which Baton Pass and a replacement open straight into.
## Empty when none of them is on screen.
var _switch_stage: StringName = &"":
	set(value):
		_switch_stage = value
		_gate_annotations()
## Which question the list is answering: [code]&"offer"[/code] is `OfferSwitch`'s
## YES, [code]&"baton_pass"[/code] the target `ForcePickSwitchMonInBattle` asks
## for inside the move, and [code]&"replace"[/code] `ForcePlayerMonChoice` after
## a faint. Only the first can be backed out of.
var _switch_reason: StringName = &""
var _switch_menu: Gen2BattleSwitchMenu = null
## The yes/no box's own cursor, which is a two-row `VerticalMenu`.
var _switch_offer: Gen2WorldMenu = null

## `BattleMenu`'s own loop: [code]&"main"[/code] is FIGHT/PKMN/PACK/RUN,
## [code]&"move"[/code] `MoveSelectionScreen`'s list and [code]&"refused"[/code]
## the line it prints over that list before reopening it.
var _menu_stage: StringName = &"":
	set(value):
		_menu_stage = value
		_gate_annotations()
## `wBattleMenuCursorPosition`, which is written back after every visit and so
## opens on whatever was chosen last.
var _menu_position: int = Gen2BattleMenu.FIGHT
## `wListMoves_MoveIndicesBuffer` as [method Gen2BattleMenu.move_rows] shapes it,
## rebuilt every time the list is opened because PP and Disable move under it.
var _move_rows: Array = []
## `wCurMoveNum`, which the list opens its cursor on.
var _move_cursor: int = 0
## `MoveInfoBox`, which is its own `Textbox` beside the list rather than part of
## it, so it is drawn into a layer of its own.
var _info_layer: TextureRect = null
## `.skip_exp_bar_animation`'s stats box, over the upper screen while the
## grew-to-level line it accompanies is up.
var _level_up_layer: TextureRect = null
## The stats that box is showing, empty while there is no box.
var _level_up_stats: Dictionary = {}
## The menu itself, which unlike [member _menu_layer] sits over the text box.
var _battle_menu_layer: TextureRect = null

## The trainer class behind the enemy's own moves, or zero for
## [method show_matchup]'s invented pairing, which has no class and so no AI
## flags of its own to read: it falls back to [method _random_slot], same as
## before this existed. Reset by both, set only by [method show_trainer].
var _enemy_trainer_class: int = 0
## Which trainer of that class, for the view. Both are zero in a wild battle,
## which is what `wOtherTrainerClass` holds there too.
var _enemy_trainer_index: int = 0

var _enemy: int = 1
var _player: int = 1
## Which Unown letter each side's picture is, and zero for every other species.
## Drawn values like the two above: they follow the events rather than the party.
var _enemy_unown_form: int = 0
var _player_unown_form: int = 0
var _enemy_shiny: bool = false
var _player_shiny: bool = false
var _enemy_level: int = 5
var _player_level: int = 5
var _enemy_hp: int = 0
var _enemy_max_hp: int = 0
var _player_hp: int = 0
var _player_max_hp: int = 0
## The committed exp bar, in `PlaceExpBar`'s pixels.
var _exp: int = 0

var _box: Gen2TextBox = null

## The two menus a switch is made with, and the one layer both are drawn on:
## `PlaceYesNoBox`'s frame over the field, or the whole party page in place of
## it, which is what `SetUpBattlePartyMenu` clearing the screen amounts to.
var _menu_page: Gen2MenuPage = null
var _party_page: Gen2PartyMenuPage = null
var _menu_layer: TextureRect = null
## What the layer currently holds, so a per-frame refresh redraws nothing.
var _menu_drawn: String = ""

## `wTilemap` as this battle leaves it, which is what an animation edits and
## what the renderer draws both pictures out of.
var _bg_map: PackedByteArray = Gen2BattleScreenMap.seeded()

## The animation layer. `_anim` is the running `RunBattleAnimScript`, `_plan`
## the rest of `PlayBattleAnim`'s own framing waiting behind it, and `_anim_data`
## the imported tables, opened once.
var _anim_data: Gen2BattleAnimData = null
var _anim: Gen2BattleAnimPlayer = null
## `anim_keepsprites`: what the last script left on the screen. `BattleAnim_ClearOAM`
## is skipped for it, so the objects stay drawn after the script has returned and
## until something clears OAM. The catch is the one script that asks
## (`BattleAnim_ThrowPokeBall.Click`), and the ball has to stay under
## `Text_GotchaMonWasCaught`.
var _kept_sprites: Array = []
var _kept_tiles: Array = []
var _anim_plan: Array = []
var _anim_delay: int = 0
var _anim_event: Dictionary = {}
## `ClearActorHud` clears the panel of whoever's turn it is and leaves the other
## one alone, so this is the side an animation has taken off the map rather than
## a flag for both.
var _anim_hud_hidden: int = -1
var _audio_player: Gen2AudioPlayer = null
## False while the driver belongs to the screen that opened this one, which is
## what says this screen may not stop or free it.
var _owns_audio_player: bool = false
## `PlayBattleMusic`'s answer for this fight; see [method battle_music].
var _battle_music: int = Gen2Battle.MUSIC_NONE

@onready var _screen: Gen2Screen = %Screen


## Bars drain and the intro slides on hardware frames, not on rendered ones, the
## same reason [Gen2WorldAnimation] paces the overworld that way: the two-frame
## step `HPBarAnim_BGMapUpdate` waits and `BattleIntroSlidingPics`' own
## `DelayFrame` are both hardware frame counts.
func _process(delta: float) -> void:
	if _box != null:
		_box.accelerated = PokeButton.text_accelerating()
	## A screen someone else spends frames for must not also spend them off real
	## time. The world drives a battle from its own pump
	## ([method advance_hardware_frame]), so with this clock running as well every
	## bar drained, every animation ran and the box's own arrow blinked at twice
	## the source's rate. Same rule, and the same caller, as
	## [member Gen2TextBox.driven].
	if _driven:
		return
	## The yes/no box appears when the question above it has finished printing,
	## and the box prints on its own clock rather than on a press.
	if _switch_stage != &"":
		_advance_party_icons(delta)
		_refresh_menu_layer()
	## The box is on the same hardware clock as everything else the screen draws,
	## and it keeps counting while nothing else does: a text prints, scrolls and
	## blinks its arrow whether or not a bar or an animation is running.
	## [method frames_running] deliberately does not answer for it, since a box
	## waiting at a page is waiting on a press and a caller draining frames on
	## that answer would never stop.
	var running: bool = frames_running()
	if not running and (_box == null or not _box.visible):
		_frame_clock.reset()
		return
	for _frame: int in _frame_clock.tick(delta):
		_tick_auto_input()
		if frames_running():
			advance_frame()
		elif _box != null:
			_box.advance_frame()
		else:
			break


## Whether anything is counting hardware frames right now. Public with
## [method advance_frame] so a test or a screenshot driver can settle the screen
## without waiting on real time. An exp bar stopped at a level boundary is waiting
## on the press that dismisses `.LoopLevels`' textbox rather than on frames, so it
## is excluded and a caller draining frames stops instead of spinning.
func frames_running() -> bool:
	var bars: bool = not _bars.is_empty() or (_exp_bar != null and not _exp_bar.paused())
	return bars or _intro != null or animation_running() or fainting() or sliding() \
		or animating_frontpic()


## One hardware frame of everything that counts them. Public through
## [method advance_bars] and [method advance_intro] so a test or a screenshot
## driver can settle either without waiting on real time.
func advance_frame() -> bool:
	if _box != null:
		_box.advance_frame()
	var was_running: bool = frames_running()
	var moved: bool = advance_intro()
	moved = advance_bars() or moved
	moved = advance_faint() or moved
	moved = advance_slide() or moved
	moved = advance_frontpic() or moved
	moved = advance_animation() or moved
	_resume_after_frames(was_running)
	return moved


## What the source does when the frames a command spends run out: it runs on to
## the next command. Nothing in `DoMove`'s loop reads a button between an
## animation, `AnimateHPBar` and `MonFaintedAnimation` and whatever follows them,
## so the pump continues here rather than standing still until a press.
##
## The waits that are real are all a box, and [method _continue_after_messages]
## owns that test: a message on screen is left alone, and so is a bar holding one.
func _resume_after_frames(was_running: bool) -> void:
	if not was_running or frames_running():
		return
	_continue_after_messages()


func fainting() -> bool:
	return not _faints.is_empty()


## One hardware frame of `MonFaintedAnimation`. Public so a test or a screenshot
## driver can settle or step one without waiting on real time.
func advance_faint() -> bool:
	if _faints.is_empty():
		return false
	var faint: Dictionary = _faints[0]
	faint["delay"] = int(faint["delay"]) - 1
	if int(faint["delay"]) > 0:
		return true
	faint["delay"] = Gen2BattleScreenMap.FAINT_STEP_FRAMES
	faint["step"] = int(faint["step"]) + 1
	Gen2BattleScreenMap.faint_step(_bg_map, bool(faint["player_side"]))
	if int(faint["step"]) >= Gen2BattleScreenMap.FAINT_STEPS:
		_faints.remove_at(0)
		if bool(faint["player_side"]):
			_player_hud_visible = false
		else:
			_enemy_hud_visible = false
	_push_view()
	return true


func sliding() -> bool:
	return not _slides.is_empty()


## One hardware frame of `SlideBattlePicOut`, whose outer loop spends
## [constant Gen2BattleScreenMap.SLIDE_STEP_FRAMES] on each column it shifts.
func advance_slide() -> bool:
	if _slides.is_empty():
		return false
	var slide: Dictionary = _slides[0]
	if bool(slide.get("incoming", false)):
		return _advance_result_slide(slide)
	slide["delay"] = int(slide["delay"]) - 1
	if int(slide["delay"]) > 0:
		return true
	slide["delay"] = Gen2BattleScreenMap.SLIDE_STEP_FRAMES
	slide["step"] = int(slide["step"]) + 1
	var player_side: bool = bool(slide["player_side"])
	Gen2BattleScreenMap.slide_step(_bg_map, player_side)
	var side: int = Gen2Battle.PLAYER if player_side else Gen2Battle.ENEMY
	_slid_pixels[side] = float(_slid_pixels[side]) + (
		-float(PokeTiles.TILE_WIDTH) if player_side else float(PokeTiles.TILE_WIDTH)
	)
	if int(slide["step"]) >= int(Gen2BattleScreenMap.SLIDE_STEPS[player_side]):
		_slides.remove_at(0)
	_push_view()
	return true


func _advance_result_slide(slide: Dictionary) -> bool:
	slide["delay"] = int(slide["delay"]) - 1
	if int(slide["delay"]) > 0:
		return true
	var step: int = int(slide["step"])
	if step == 6:
		_slides.remove_at(0)
		return true
	step += 1
	slide["step"] = step
	slide["delay"] = 44 if step == 6 else 4
	Gen2BattleScreenMap.result_trainer_step(_bg_map, step)
	_slid_pixels[Gen2Battle.ENEMY] = float((8 - step) * PokeTiles.TILE_WIDTH)
	_push_view()
	return true


## Whether the enemy's picture is still wobbling through `AnimateFrontpic`.
func animating_frontpic() -> bool:
	return _frontpic != null


## One turn of `AnimateFrontpic`'s own `.loop`, which is one `SetUpPokeAnim` and
## so one hardware frame. The animation edits the tilemap and nothing else, the
## way `PokeAnim_PlaceGraphic` does, so what it leaves is stamped into the
## screen's own map over the enemy's square.
func advance_frontpic() -> bool:
	if _frontpic == null:
		return false
	var cry: StringName = _frontpic.advance()
	if cry != &"":
		# `PokeAnim_StereoCry` is `PlayStereoCry2`, the sibling that does not
		# `WaitSFX`: the picture keeps moving over it, which is the whole reason
		# the cry is inside the animation rather than in front of it.
		_play_entrance_cry(Gen2Battle.ENEMY, _enemy)
	_stamp_frontpic()
	if _frontpic.finished():
		# `PokeAnim_DeinitFrames` ends with `PokeAnim_SetVBank0`, which puts the
		# square back on the sheet everything else is read from.
		_frontpic = null
		_bg_vbank1 = PackedByteArray()
	_push_view()
	return true


## The animation's 7x7 box into the enemy's square. Its cells are numbered the
## way `PokeAnim_PlaceGraphic` numbers them, which is the column-major order
## [method Gen2BattleScreenMap.stamp] already writes for that square.
func _stamp_frontpic() -> void:
	if _frontpic == null or _frontpic.box.size() != Gen2PicAnimation.BOX * Gen2PicAnimation.BOX:
		return
	if _bg_vbank1.size() != _bg_map.size():
		_bg_vbank1.resize(_bg_map.size())
		_bg_vbank1.fill(0)
	var at: Vector2i = Gen2BattleScreenMap.ENEMY_AT
	for column: int in Gen2PicAnimation.BOX:
		for row: int in Gen2PicAnimation.BOX:
			var x: int = at.x + column
			var y: int = at.y + row
			if x < 0 or x >= Gen2BattleScreenMap.COLUMNS \
					or y < 0 or y >= Gen2BattleScreenMap.ROWS:
				continue
			_bg_map[y * Gen2BattleScreenMap.COLUMNS + x] = (
				Gen2BattleScreenMap.ENEMY_BASE_TILE
				+ int(_frontpic.box[column * Gen2PicAnimation.BOX + row])
			) & 0xFF
			_bg_vbank1[y * Gen2BattleScreenMap.COLUMNS + x] = 1


## `PlayerMonFaintedAnimation` or `EnemyMonFaintedAnimation`, which
## `FaintYourPokemon` and `FaintEnemyPokemon` run before their own text box.
func _begin_faint(side: int) -> void:
	_faints.append({
		"player_side": side == Gen2Battle.PLAYER,
		"step": 0,
		"delay": Gen2BattleScreenMap.FAINT_STEP_FRAMES,
	})


func _ready() -> void:
	_data = _injected_data if _injected_data != null else _selected_runtime_data()
	if _data == null:
		_data = GameData.open_any()
	_build_renderer()
	if not _renderer_ready:
		return
	Gen2ModHost.instance().view_changed.connect(_on_view_changed)

	## The cartridge has one APU. A screen that opened this one hands its own
	## driver over so a cry here takes the channels the map music is holding
	## rather than sounding over a second copy of them; only a battle standing on
	## its own builds a player, and only that one owns it.
	if _audio_player == null:
		_audio_player = AUDIO_PLAYER_SCRIPT.new()
		_audio_player.name = "AudioPlayer"
		_owns_audio_player = true
		add_child(_audio_player)
	_anim_data = Gen2BattleAnimData.from_game_data(_data)

	## Under the text box, because the refusals a switch list is answered with are
	## `StdBattleTextbox` drawn over the party menu rather than into it. The
	## yes/no box sits above the box's own rows and never meets it.
	_menu_page = Gen2MenuPage.from_data(_data)
	_party_page = Gen2PartyMenuPage.from_data(_data)
	_menu_layer = TextureRect.new()
	_menu_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_menu_layer.visible = false
	_screen.display(_menu_layer)

	_box = Gen2TextBox.new()
	_box.driven = true
	_box.font = Gen2Font.from_data(_data)
	## wTextboxFrame and the TEXT SPEED delay: a battle's own boxes are the
	## player's boxes, drawn through `PrintLetterDelay` like every other one.
	var options: Gen2Options = Gen2OptionsStore.current()
	_box.set_frame_style(options.textbox_frame)
	## A line a mod asks for is spent in this box, so the queue lives exactly as
	## long as the box does.
	Gen2ModHost.instance().set_battle_messages_open(true)
	_box.reveal_speed = options.text_reveal_speed()
	_box.item_rect_changed.connect(_push_text_box_rect)
	_box.visibility_changed.connect(_push_text_box_rect)
	_screen.display(_box)
	_box.place_at_bottom()
	## Over the text box, unlike the two above: `LoadBattleMenu` draws its box
	## into the tilemap after `EmptyBattleTextbox` has drawn that one, so the
	## menu covers the box's right-hand half and `MoveSelectionScreen`'s list
	## covers all of it.
	_battle_menu_layer = TextureRect.new()
	_battle_menu_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_battle_menu_layer.visible = false
	_screen.display(_battle_menu_layer)
	_info_layer = TextureRect.new()
	_info_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_info_layer.visible = false
	_screen.display(_info_layer)
	_level_up_layer = TextureRect.new()
	_level_up_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_level_up_layer.visible = false
	_screen.display(_level_up_layer)
	## Last, so a registered provider's annotations sit over every box and menu
	## the interface draws, whichever renderer is under all of it.
	_annotations = Gen2BattleAnnotations.from_data(_data)
	## Immediately below the ink, so a placement that asked for a field gets the
	## cartridge's own interface behind exactly its cells and nothing else. The
	## built-in arena already has a white background and so is unchanged by it;
	## a native-layer renderer has the map there, and its own interface opacity.
	_annotation_field_layer = TextureRect.new()
	_annotation_field_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_annotation_field_layer.visible = false
	_screen.display(_annotation_field_layer)
	_annotation_layer = TextureRect.new()
	_annotation_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_annotation_layer.visible = false
	_screen.display(_annotation_layer)
	_apply_renderer_interface_style()

	## Whatever this screen was opened on its own for. A battle inside the
	## overworld is started by [method start_world_battle], from the frame the
	## encounter fired on, rather than from anything read here.
	var saved: Gen2SaveData = _selected_runtime_save()
	if saved != null and show_saved_party(saved):
		show_message("Save slot %d loaded. Wild %s appeared!" % [_save_slot + 1, _name_of(_enemy)])
	else:
		show_matchup(DEFAULT_ENEMY, DEFAULT_PLAYER, DEFAULT_LEVEL, DEFAULT_LEVEL)
		_announce()


## Supplies a cache-backed data source before the scene enters the tree; the
## launcher still resolves its own from GameRuntime.
func set_data(data: GameData) -> void:
	_injected_data = data


## Which generation's screen this is, for the two boxes the pictures sit in. A
## battle that never reached [method set_data] seeds Crystal's map.
func _generation() -> int:
	return _data.generation if _data != null else RomRegistry.GEN2


## `CleanUpBattleRAM` zeroes `wLowHealthAlarm`. A driver this screen does not own
## outlives it, so the byte is cleared where the screen goes rather than where a
## fight ends: every way out of a battle, including a wipe and a failed setup, is
## a way out of the tree.
func _exit_tree() -> void:
	if _audio_player != null and not _owns_audio_player:
		_audio_player.set_low_health_alarm(false)
	var host: Gen2ModHost = Gen2ModHost.instance()
	if host != null:
		host.set_battle_messages_open(false)


## Hands this screen the driver the opening screen is already running, before it
## enters the tree. Without one the screen builds its own, which is what a
## battle launched on its own does.
func set_audio_player(player: Gen2AudioPlayer) -> void:
	_audio_player = player
	_owns_audio_player = false


## The rules the world is being played under, so the fight inside it is fought
## under the same ones rather than under whatever was installed last.
func set_rules(battle_rules: Gen2Rules) -> void:
	_injected_rules = battle_rules


## Seeds everything this screen decides for itself: the enemy's move choice, its
## item and switch decisions, and the capture rolls.
##
## A battle inside a walk is drawn from the world's own generator, so the seed is
## part of the run's own chain and a replay reproduces the fight without recording
## anything about it. A battle with no world seeds itself randomly, which is what
## a development one should do.
func set_random_seed(value: int) -> void:
	_rng.seed = value


## Hands the input funnel and the frame pump to whoever opened this screen.
##
## The world does both while a battle is an overlay on it. One funnel is what
## makes a recorded log complete, and two would record every press twice or none;
## one pump is what makes a replay land on the same frame, and two spend every
## frame twice.
func set_driven(driven: bool) -> void:
	_driven = driven


## The request this fight was started from, as the adapter prepared it: the
## species, the level, the DVs and which visible encounter it was, for a test or a
## mod asking what is being fought rather than what is drawn.
func world_battle_request() -> Dictionary:
	return _world_battle_request.duplicate(true)


func _start_auto_input(stream: Array) -> void:
	_auto_input = stream
	_auto_input_index = 0
	_auto_input_delay = 0


func _stop_auto_input() -> void:
	_auto_input = []
	_auto_input_index = 0
	_auto_input_delay = 0
	_auto_input_stage = &""
	_auto_input_polls = 0.0


## Which of `_DudeAutoInput_A`, `_RightA` and `_DownA` this poll installs, from
## `.wait_input`'s box, `BattleMenu`'s loop and `TutorialPack`. The menu answers
## first: its stream is installed after the line above it has printed.
func _dude_auto_input_stage() -> StringName:
	if _pack_selecting:
		return &"pack"
	if _menu_stage == &"main":
		return &"menu"
	## `.wait_input` is reached once the line above it has printed and nothing
	## else is spending frames, which is exactly a box owing a press here.
	if _box != null and _box.visible and not _box.is_revealing() \
		and not frames_running():
		return &"text"
	return &""


## `GetJoypad`'s `.auto` branch, spent this frame's worth of polls.
func _tick_auto_input() -> void:
	if not _world_battle_active or not _world_battle_tutorial:
		return
	var stage: StringName = _dude_auto_input_stage()
	if stage != _auto_input_stage:
		_auto_input_stage = stage
		_auto_input_polls = 0.0
		if stage == &"":
			_auto_input = []
		else:
			_start_auto_input(DUDE_AUTO_INPUT[stage])
	if _auto_input_index >= _auto_input.size():
		return
	_auto_input_polls += float(DUDE_POLLS_PER_FRAME.get(_auto_input_stage, 1.0))
	while _auto_input_polls >= 1.0 and _auto_input_index < _auto_input.size():
		_auto_input_polls -= 1.0
		_spend_auto_input_poll()


func _spend_auto_input_poll() -> void:
	if _auto_input_delay > 0:
		_auto_input_delay -= 1
		return
	var entry: Array = _auto_input[_auto_input_index]
	_auto_input_index += 1
	_auto_input_delay = int(entry[1])
	var button: int = int(entry[0])
	if button != PokeButton.NONE:
		_handle_button(button)


## One button, from the funnel rather than from an [InputEvent]. Public so the
## world can forward what it consumed and a tool can drive a fight by hand.
func press_button(button: int) -> bool:
	if not is_ready() or button == PokeButton.NONE:
		return false
	return _handle_button(button)


## One hardware frame of everything this screen counts, including the party icons
## the switch menu animates, which [method _process] otherwise paces off real
## time. What lets the world spend a battle's frames from its own pump, so a
## replayed run reaches the same place at the same frame.
func advance_hardware_frame() -> bool:
	var moved: bool = false
	_tick_auto_input()
	## `PrintLetterDelay` is a frame count, and with nothing servicing the box's
	## own `_process` a message would never finish revealing, so a press would
	## complete the page forever and never acknowledge it.
	if _box != null:
		_box.advance_frame()
	## The prompt draws its own box, and its `YesNoBox` does not appear until
	## that box owes nothing, so it is spent a frame at a time like this one.
	if _capture_nickname_host != null:
		_capture_nickname_host.advance_frame()
		return true
	if _switch_stage in [&"pick", &"refused"]:
		moved = advance_party_icons()
		_refresh_menu_layer()
	if not frames_running():
		return moved
	return advance_frame() or moved


## Null rather than the first imported cache: a battle opened without a runtime
## is a development one, and the caller has already injected what it draws with.
func _selected_runtime_data() -> GameData:
	var runtime: Gen2GameRuntime = Gen2GameRuntime.instance()
	if runtime != null and runtime.has_selected_game():
		return runtime.selected_data()
	return null


func _selected_runtime_save() -> Gen2SaveData:
	return Gen2GameRuntime.selected_save_or_null()


func is_ready() -> bool:
	return _renderer_ready and _box != null


## Puts two Pokémon on the screen at a level each, both at full health, and
## starts a battle between them.
func show_matchup(
	enemy: int, player: int, enemy_level: int = 5, player_level: int = 5
) -> void:
	_reset_capture_state()
	_world_battle_active = false
	_world_battle_tutorial = false
	_world_battle_request = {}
	_world_battle_completion_sent = false
	_world_battle_result_picture_shown = false
	_world_battle_terminal_text_shown = false
	_world_battle_recovery_shown = false
	_earnings_computed = {}
	_prize_text_shown = false
	_pay_day_text_shown = false
	_world_battle_recovery = {}
	_enemy = _wrap_species(enemy)
	_player = _wrap_species(player)
	_enemy_level = enemy_level
	_player_level = player_level

	_pending = []
	_save_slot = -1
	_save_written = false
	_source_save = null
	_enemy_trainer_class = 0
	_enemy_trainer_index = 0
	_battle = Gen2Battle.create_parties(
		_data, _party_from(_player, _player_level), _party_from(_enemy, _enemy_level), _rng
	)
	if _battle == null:
		return

	_init_battle_display()
	_announce()


## Puts the player against one of a trainer class's own trainers, built from the
## cartridge's own party rather than invented. The player's side is the
## fallback development party when this method is called directly.
func show_trainer(
	trainer_class: int, index: int = 0, player_species: int = DEFAULT_PLAYER,
	player_level: int = DEFAULT_LEVEL
) -> void:
	_reset_capture_state()
	_world_battle_active = false
	_world_battle_tutorial = false
	_world_battle_request = {}
	_world_battle_completion_sent = false
	_world_battle_result_picture_shown = false
	_world_battle_terminal_text_shown = false
	_world_battle_recovery_shown = false
	_earnings_computed = {}
	_prize_text_shown = false
	_pay_day_text_shown = false
	_world_battle_recovery = {}
	var enemy_party: Gen2Party = Gen2TrainerParty.build(
		_data, trainer_class, index, _rules()
	)
	if enemy_party == null:
		return

	_player = _wrap_species(player_species)
	_player_level = player_level

	var lead: Gen2BattleMon = enemy_party.active_mon()
	_enemy = lead.species
	_enemy_level = lead.level

	_pending = []
	_save_slot = -1
	_save_written = false
	_source_save = null
	_enemy_trainer_class = trainer_class
	_enemy_trainer_index = index
	_battle = Gen2Battle.create_parties(
		_data, _party_from(_player, _player_level), enemy_party, _rng, true
	)
	if _battle == null:
		return
	_battle.init_enemy_trainer(trainer_class)

	_init_battle_display()

	show_message("%s\nwants to battle!" % _enemy_battler_label())


## Starts the development battle with the player party from a validated save
## slot. The enemy remains the existing wild demonstration, while the player
## side now carries persistent levels, HP, PP, status, DVs and stat experience.
func show_saved_party(save: Gen2SaveData) -> bool:
	_reset_capture_state()
	_world_battle_active = false
	_world_battle_tutorial = false
	_world_battle_request = {}
	_world_battle_completion_sent = false
	_world_battle_result_picture_shown = false
	_world_battle_terminal_text_shown = false
	_world_battle_recovery_shown = false
	_earnings_computed = {}
	_prize_text_shown = false
	_pay_day_text_shown = false
	_world_battle_recovery = {}
	var player_party: Gen2Party = Gen2SaveBattleAdapter.to_battle_party(_data, save)
	var enemy_party: Gen2Party = _party_from(DEFAULT_ENEMY, DEFAULT_LEVEL)
	if player_party == null or enemy_party == null:
		return false
	var player_lead: Gen2BattleMon = player_party.active_mon()
	var enemy_lead: Gen2BattleMon = enemy_party.active_mon()
	_pending = []
	_save_slot = save.slot
	_save_written = false
	_source_save = save
	_enemy_trainer_class = 0
	_enemy_trainer_index = 0
	_player = player_lead.species
	_player_level = player_lead.level
	_enemy = enemy_lead.species
	_enemy_level = enemy_lead.level
	var badge_mask: int = 0
	if save.world != null and save.world.world_state != null:
		badge_mask = save.world.world_state.badge_mask(
			Gen2WorldState.is_crystal_profile(_data)
		)
	_battle = Gen2Battle.create_parties(
		_data, player_party, enemy_party, _rng, false, badge_mask
	)
	if _battle == null:
		_save_slot = -1
		return false
	_init_battle_display()
	return true


## Starts a battle requested by the scene-free overworld runtime. The caller
## keeps the world API alive while this screen owns the battle presentation.
func start_world_battle(
	request: Dictionary, save: Gen2SaveData = null, player_badges: int = -1
) -> bool:
	_clear_capture_action()
	if _data == null or not is_ready():
		_emit_world_battle_failure(&"missing_battle_data")
		return false
	var player_party: Gen2Party = (
		Gen2SaveBattleAdapter.to_battle_party(_data, save)
		if save != null else Gen2WorldBattleAdapter.fallback_party(_data)
	)
	var crystal: bool = Gen2WorldState.is_crystal_profile(_data)
	var prepared: Dictionary = Gen2WorldBattleAdapter.prepare(
		_data, _stamped_request(request, save, crystal), player_party, _rng,
		_world_badge_mask(save, crystal, player_badges), _injected_rules,
		save.player_id if save != null else -1
	)
	if not bool(prepared.get("ok", false)):
		_emit_world_battle_failure(
			StringName(prepared.get("reason", &"battle_setup_failed")),
			prepared.get("details", {})
		)
		return false
	_begin_world_battle(prepared, save)
	if bool(prepared.get("trainer_battle", false)):
		show_message("%s\nwants to battle!" % _enemy_battler_label())
	else:
		_announce()
	return true


func _world_badge_mask(save: Gen2SaveData, crystal: bool, player_badges: int) -> int:
	if player_badges >= 0:
		return player_badges
	if save == null or save.world == null or save.world.world_state == null:
		return 0
	return maxi(save.world.world_state.badge_mask(crystal), 0)


## [param request] with `wUnlockedUnowns`, which `CheckUnownLetter` gates a rolled
## wild Unown's letter on. Stamped here because the adapter is scene-free and this
## is the one path that has the save; a request without it takes whatever it
## rolled.
func _stamped_request(request: Dictionary, save: Gen2SaveData, crystal: bool) -> Dictionary:
	var stamped: Dictionary = request.duplicate(true)
	if save == null or save.world == null or save.world.world_state == null:
		return stamped
	var stamped_values: Variant = stamped.get("values", stamped)
	if stamped_values is Dictionary:
		(stamped_values as Dictionary)["unlocked_unowns"] = \
			save.world.world_state.unlocked_unowns(crystal)
	return stamped


func _begin_world_battle(prepared: Dictionary, save: Gen2SaveData) -> void:
	_world_battle_active = true
	_world_battle_request = (prepared.get("request", {}) as Dictionary).duplicate(true)
	_world_battle_tutorial = bool(_world_battle_request.get("tutorial", false))
	_world_battle_completion_sent = false
	_world_battle_result_picture_shown = false
	_world_battle_terminal_text_shown = false
	_world_battle_recovery_shown = false
	_earnings_computed = {}
	_prize_text_shown = false
	_pay_day_text_shown = false
	_world_battle_recovery = {}
	_pending = []
	_save_slot = save.slot if save != null else -1
	_save_written = false
	_source_save = save
	_enemy_trainer_class = int(prepared.get("trainer_class", 0))
	_enemy_trainer_index = int(prepared.get("trainer_index", 0))
	_battle = prepared["battle"]
	_battle.time_of_day = _time_of_day
	## `GetWorldMapLocation`, the same reading [method _play_battle_music] uses:
	## `LevelUpHappinessMod` compares it against the winner's caught location.
	_battle.landmark = _world_context.landmark if _world_context != null \
		else Gen2Battle.LANDMARK_NONE
	var player_party_ready: Gen2Party = prepared["player_party"]
	var enemy_party_ready: Gen2Party = prepared["enemy_party"]
	_player = player_party_ready.active_mon().species
	_player_level = player_party_ready.active_mon().level
	_enemy = enemy_party_ready.active_mon().species
	_enemy_level = enemy_party_ready.active_mon().level
	## Read before anything registers this sight: `SetSeenMon` runs as the
	## opponent appears, so after the first frame the answer is always yes.
	_enemy_seen_before = save != null and save.world != null \
		and save.world.world_state != null \
		and save.world.world_state.has_seen_species(_enemy)
	_enemy_caught_before = false
	_dex_received = false
	_init_battle_display()
	_play_battle_music()
	if _world_battle_tutorial:
		_set_up_dude_tutorial()


## The Dude's bag, not the player's, which is why the world hands none.
func _set_up_dude_tutorial() -> void:
	## `.DudeTutorial` forces TEXT_DELAY_MED over the player's own TEXT SPEED.
	if _box != null:
		_box.reveal_speed = 1.0 / (Gen2Options.FRAME_SECONDS * Gen2Options.TEXT_DELAY_MED)
	_stop_auto_input()
	set_battle_pack(DUDE_PACK, DUDE_PACK_QUANTITIES)
	set_capture_balls([Gen2WorldPartyHost.ITEM_POKE_BALL], DUDE_PACK_QUANTITIES)


## Public screenshot driver for the overworld battle loss boundary. It starts a
## real host battle using the fallback development party and then completes it
## as a loss, which is the frame `LostBattle` returns on: the whiteout itself is
## the overworld's and is photographed there.
func preview_world_battle_loss() -> void:
	if _world_battle_active or _data == null:
		return
	if not start_world_battle({
		"kind": &"wild", "pokemon": DEFAULT_ENEMY, "level": DEFAULT_LEVEL,
	}):
		return
	call_deferred("_preview_world_battle_loss")


func _preview_world_battle_loss() -> void:
	if not _world_battle_active or _battle == null:
		return
	for mon: Gen2BattleMon in _battle.party(Gen2Battle.PLAYER).mons:
		mon.hp = 0
	_read_hp()
	finish()
	advance()
	finish()


func _emit_world_battle_failure(reason: StringName, details: Dictionary = {}) -> void:
	if _world_battle_completion_sent:
		return
	_world_battle_completion_sent = true
	battle_finished.emit({"ok": false, "reason": reason, "details": details.duplicate(true)})


## A fallback party led by [param species], with the species after it behind.
## The enemy's side no longer uses this; see [method show_trainer].
func _party_from(species: int, level: int) -> Gen2Party:
	var members: Array = []
	for offset: int in PARTY_SIZE:
		var number: int = _wrap_species(species + offset)
		members.append(
			Gen2BattleMon.create(_data, number, level, _data.moves_at_level(number, level))
		)
	return Gen2Party.create(members)


## Both HP totals, for a caller that has its own numbers. The committed HP,
## which is what [method battle_snapshot] and every caller that places state
## reads. It does not animate on its own: `AnimateHPBar` is called by
## `DoEnemyDamage` and its siblings, not by every write to `wBattleMonHP`, so
## the bar is started by the events that mean damage or healing and this snaps.
func set_hp(enemy: int, enemy_max: int, player: int, player_max: int) -> void:
	if enemy != _enemy_hp or enemy_max != _enemy_max_hp:
		_bars.erase(Gen2Battle.ENEMY)
	if player != _player_hp or player_max != _player_max_hp:
		_bars.erase(Gen2Battle.PLAYER)
	_enemy_hp = enemy
	_enemy_max_hp = enemy_max
	_player_hp = player
	_player_max_hp = player_max
	_push_view()


## Begins a bar animation from [param from_hp] to the HP now committed for
## [param side], which is what an event meaning damage or healing does after it
## has written the new value.
##
## A maximum that moved under the bar is not the same bar draining: a Pokemon
## coming out gets its bar drawn at once, the way `LoadHPBar` puts one up.
func _start_bar(side: int, from_hp: int, from_max: int) -> void:
	var to_hp: int = _enemy_hp if side == Gen2Battle.ENEMY else _player_hp
	var max_hp: int = _enemy_max_hp if side == Gen2Battle.ENEMY else _player_max_hp
	if max_hp != from_max or from_hp == to_hp:
		return
	var animation: Gen2HpBarAnimation = Gen2HpBarAnimation.create(from_hp, to_hp, max_hp)
	if animation.finished():
		return
	_bars[side] = animation
	_push_view()


## What the bar for [param side] is drawing: the animation's value while one is
## running, and the committed HP otherwise.
func _drawn_hp(side: int) -> int:
	var animation: Gen2HpBarAnimation = _bars.get(side, null)
	if animation == null:
		return _enemy_hp if side == Gen2Battle.ENEMY else _player_hp
	return animation.hp()


## `HandleHPPals`, which sets `wLowHealthAlarm`'s DANGER_ON bit while the
## player's own bar reads HP_RED and clears it otherwise. The colour follows what
## is drawn rather than the numbers behind it, so a draining bar arms the alarm
## on the frame it turns red. `StopDangerSound` silences it the moment the
## Pokemon faints and `CleanUpBattleRAM` at the end of the battle, which is what
## the two zero cases here are.
func _update_low_health_alarm() -> void:
	if _audio_player == null:
		return
	var hp: int = _drawn_hp(Gen2Battle.PLAYER)
	var over: bool = _battle != null and _battle.is_over()
	if hp <= 0 or _player_max_hp <= 0 or over:
		_audio_player.set_low_health_alarm(false)
		return
	var lit: int = Gen2BattleHud.bar_pixels(
		hp, _player_max_hp, Gen2BattleHud.HP_BAR_TILES * Gen2Font.TILE
	)
	_audio_player.set_low_health_alarm(GameData.hp_bar_palette_name(lit) == "hp_red")


func bars_animating() -> bool:
	return not _bars.is_empty() or _exp_bar != null


func intro_running() -> bool:
	return _intro != null


## Whether `BattleStartMessage` and `DoBattle`'s opening still owe something: a
## line to press past, frames to spend, or a ball to throw. A driver settling a
## battle to its first menu waits on this as well as on [method frames_running],
## because two of the steps are a box rather than a run of frames.
func entrance_running() -> bool:
	return not _entrance_stages.is_empty()


## `InitBattleDisplay`: the display a battle opens with, and the slide that puts
## it there. Every caller that has just built a battle reaches this, which is the
## same order the source uses, `InitBattleDisplay` before `BattleStartMessage`.
func _init_battle_display() -> void:
	## The engine is scene-free, so `wOptions` is injected here, the one place
	## every battle passes through.
	_battle.battle_style_set = _battle.in_battle_tower \
		or Gen2OptionsStore.current().battle_style_set
	_battle.battle_scene_on = Gen2OptionsStore.current().battle_scene
	## `InitBattleDisplay` draws both pics, so the letters start from the party
	## the same way the species above do; every later change is a send-out.
	_enemy_unown_form = Gen2Battle.unown_form_of(_battle.enemy)
	_player_unown_form = Gen2Battle.unown_form_of(_battle.player)
	_enemy_shiny = Gen2Stats.is_shiny(_battle.enemy.dvs)
	_player_shiny = Gen2Stats.is_shiny(_battle.player.dvs)
	_close_switch()
	_clear_level_up_box()
	_reseed_bg_map()
	set_hp(
		_battle.enemy.hp, _battle.enemy.max_hp(),
		_battle.player.hp, _battle.player.max_hp()
	)
	_refresh_exp_bar()
	_intro = Gen2BattleIntro.for_data(_data)
	# `InitBattleDisplay` clears the top of the player's square before the slide
	# and `PlaceGraphic` puts it back after, which is where [method
	# advance_intro] restamps it.
	Gen2BattleScreenMap.clear_intro_box(_bg_map)
	_intro_message = ""
	_entrance_stages = []
	_frontpic = null
	_bg_vbank1 = PackedByteArray()
	_hud_balls = []
	_hud_border = []
	## `InitBattleDisplay` clears both panels off the map, and the two pictures
	## the pics slide in with are the opponent and the player themselves:
	## `InitEnemyTrainer` places a trainer class on the enemy's square and
	## `GetTrainerBackpic` the player's own on the player's. A wild opponent is
	## the one battler already standing there as itself.
	_enemy_hud_visible = false
	_player_hud_visible = false
	_enemy_trainer_pic = _enemy_trainer_class
	_player_backpic = player_backpic_kind()
	_push_view()


## `GetTrainerBackpic`'s choice: the Dude for the catching tutorial, and the
## player's own picture otherwise.
func player_backpic_kind() -> String:
	## `GetTrainerBackPic` has two: the player, and the old man who borrows the
	## screen for the catching tutorial.
	if _data != null and _data.generation == RomRegistry.GEN1:
		return Gen1Layout.PLAYER_BACKPICS[1 if _world_battle_tutorial else 0]
	if _world_battle_tutorial:
		return "dude"
	return "kris" if player_is_female() else "chris"


## `wPlayerGender`'s `PLAYERGENDER_FEMALE_F`. Gold and Silver have one player
## character and no gender screen, so the answer there is always the male one.
func player_is_female() -> bool:
	if _source_save == null or _data == null:
		return false
	if not Gen2WorldState.is_crystal_profile(_data):
		return false
	return _source_save.gender == Gen2SaveData.GENDER_FEMALE


## One hardware frame of the intro. Public so a test or a screenshot driver can
## settle it without waiting on real time.
func advance_intro() -> bool:
	if _intro == null:
		return false
	if not _intro.advance_frame():
		return false
	if _intro.finished():
		# `InitBattleDisplay`'s own `xor a` / `ldh [hSCX], a` after the call, and
		# then `hGraphicStartTile = $31` / `hlcoord 2, 6` / `PlaceGraphic`, which
		# puts back the two tile rows its `ClearBox` took off before the slide.
		_intro = null
		_restamp_battler(true)
		_push_view()
		_build_entrance()
		_advance_entrance()
		return true
	_push_view()
	return true


## `BattleStartMessage` and the opening of `DoBattle`, which the sliding pics run
## straight into: one stage per step, spent in order by
## [method _advance_entrance]. Measured against a real cartridge frame by frame,
## which is where the frame counts and the two presses come from.
## `AnimateFrontpic` is the enemy's alone and is where its cry comes from, both
## send-outs `jr .skip_cry` past `PlayStereoCry`. Crystal's alone: pokegold has no
## `pic_animation.asm` and reaches `PlayStereoCry` directly, the `.cry_no_anim`
## branch this project falls back on. The player's send-out has no animation.
func _build_entrance() -> void:
	_entrance_stages = []
	var text: String = _intro_message
	_intro_message = ""
	if _battle == null:
		if not text.is_empty():
			show_message(text)
		return

	var trainer: bool = _battle.is_trainer_battle
	if trainer:
		_entrance_stages.append({
			"sfx": SFX_SHINE, "wait_sfx": true, "delay": TRAINER_START_FRAMES,
		})
	else:
		# `BattleCheckEnemyShininess` and the cry, both in front of the line.
		_entrance_stages.append(
			_with_frontpic(
				{"events": _battle.entrance_events(Gen2Battle.ENEMY, false)},
				Gen2PicAnimation.ANIM_MON_NORMAL
			)
		)
	# `BattleStart_TrainerHuds` is pushed in front of the line it is called with.
	_entrance_stages.append({"apply": ENTRANCE_START_HUDS, "message": text})
	# `EmptyBattleTextbox` and `ClearSprites` take the balls away the moment that
	# line is pressed past; the wild branch draws the enemy's panel there too.
	_entrance_stages.append({
		"apply": ENTRANCE_ENEMY_HUD if not trainer else ENTRANCE_CLEAR_HUDS,
	})
	if trainer:
		# `ResetEnemyBattleVars`, then `ShowBattleTextEnemySentOut` and
		# `ShowSetEnemyMonAndSendOutAnimation` inside `EnemySwitch`.
		_entrance_stages.append({"slide": Gen2Battle.ENEMY})
		_entrance_stages.append({
			"message": "%s\nsent out\n%s!" % [_enemy_battler_label(), _name_of(_enemy)],
		})
		_entrance_stages.append(
			_with_frontpic(
				{
					"apply": ENTRANCE_ENEMY_PIC,
					"events": _battle.entrance_events(Gen2Battle.ENEMY),
				},
				Gen2PicAnimation.ANIM_MON_SLOW
			)
		)
		_entrance_stages.append({"apply": ENTRANCE_ENEMY_HUD})
	# `DoBattle`'s own `ld c, 40`, then `SlideBattlePicOut` and `SendOutMonText`.
	_entrance_stages.append({"delay": PLAYER_ENTRANCE_FRAMES})
	_entrance_stages.append({"slide": Gen2Battle.PLAYER})
	_entrance_stages.append({
		"message": SEND_OUT_LINES[
			clampi(_battle.send_out_line(Gen2Battle.PLAYER), 0, SEND_OUT_LINES.size() - 1)
		] % _name_of(_player),
		"prompt": false,
	})
	_entrance_stages.append({
		"apply": ENTRANCE_PLAYER_PIC,
		"events": _battle.entrance_events(Gen2Battle.PLAYER),
	})
	_entrance_stages.append({"apply": ENTRANCE_PLAYER_HUD})


## Moves the enemy's cry out of [param stage]'s events and into
## `AnimateFrontpic`, where the cartridge plays it. A cache with no animation for
## this species, and a battle scene switched off, both leave the stage as it was,
## which is the source's own `.cry_no_anim`.
func _with_frontpic(stage: Dictionary, kind: int) -> Dictionary:
	if _data == null or _battle == null:
		return stage
	# `farcall CheckBattleScene / jr c, .cry_no_anim`: with the OPTION menu's
	# battle-scene row off, the picture is left alone and `PlayStereoCry` is
	# played where it stands.
	if not Gen2OptionsStore.current().battle_scene:
		return stage
	var record: Dictionary = _data.pic_animation(_enemy, _enemy_unown_form)
	if record.is_empty():
		return stage
	var events: Array = stage.get("events", []) as Array
	var kept: Array = []
	var animate: bool = false
	for event: Variant in events:
		# `CheckFaintedFrzSlp` and `CheckSleepingTreeMon` gate the cry, and both
		# gate the animation with it: the source's `jr c, .skip_cry` jumps past
		# the pair. So an entrance with no cry event has no animation either.
		if event is Dictionary and StringName((event as Dictionary)["type"]) == Gen2Battle.CRY:
			animate = true
			continue
		kept.append(event)
	if not animate:
		return stage
	stage["events"] = kept
	stage["frontpic"] = kind
	return stage


## What an entrance stage's `apply` names, each one routine of the source's.
const ENTRANCE_START_HUDS: StringName = &"start_huds"
const ENTRANCE_CLEAR_HUDS: StringName = &"clear_huds"
const ENTRANCE_ENEMY_HUD: StringName = &"enemy_hud"
const ENTRANCE_PLAYER_HUD: StringName = &"player_hud"
const ENTRANCE_ENEMY_PIC: StringName = &"enemy_pic"
const ENTRANCE_PLAYER_PIC: StringName = &"player_pic"


## One step of the entrance, in the order the fields are read here. Answers
## whether it took the turn, so the caller can run on when the list is empty.
func _advance_entrance() -> bool:
	## A stage's own events are still being shown one line at a time; the next
	## stage waits for the last of them.
	if not _pending.is_empty():
		return false
	while not _entrance_stages.is_empty():
		var stage: Dictionary = _entrance_stages[0]
		var apply: StringName = StringName(stage.get("apply", &""))
		if apply != &"":
			stage["apply"] = &""
			_apply_entrance_step(apply)
		var sfx: int = int(stage.get("sfx", 0))
		var delay: int = int(stage.get("delay", 0))
		var wait_sfx: bool = bool(stage.get("wait_sfx", false))
		if sfx > 0 or delay > 0 or wait_sfx:
			stage["sfx"] = 0
			stage["delay"] = 0
			stage["wait_sfx"] = false
			_anim_plan = []
			if sfx > 0:
				_step(ANIM_SFX, {"sfx": sfx})
			if wait_sfx:
				_step(ANIM_WAIT_SFX, {})
			if delay > 0:
				_step(ANIM_DELAY, {"frames": delay})
			_run_next_anim_step()
			return true
		if stage.has("slide"):
			var side: int = int(stage["slide"])
			stage.erase("slide")
			_begin_slide(side)
			return true
		var message: String = String(stage.get("message", ""))
		if not message.is_empty():
			## `SendOutMonText`'s line ends in `done` and prints with the ball
			## already in the air; every other line here ends in `prompt` or
			## carries a `cont`, and both of those wait on a press.
			var prompt: bool = bool(stage.get("prompt", true))
			stage["message"] = ""
			show_message(message, prompt)
			if prompt:
				return true
		if stage.has("frontpic"):
			var kind: int = int(stage["frontpic"])
			stage.erase("frontpic")
			_begin_frontpic(kind)
			if animating_frontpic():
				return true
		var events: Array = stage.get("events", []) as Array
		_entrance_stages.pop_front()
		if not events.is_empty():
			_pending = events
			_show_next_event()
			return true
	return false


func _apply_entrance_step(what: StringName) -> void:
	match what:
		ENTRANCE_START_HUDS:
			_build_trainer_huds()
		ENTRANCE_CLEAR_HUDS:
			# `EmptyBattleTextbox`, `ClearBox` over both panels and
			# `ClearSprites`, which is what takes the party balls away.
			_hud_balls = []
			_hud_border = []
		ENTRANCE_ENEMY_HUD:
			_hud_balls = []
			_hud_border = []
			_enemy_hud_visible = true
		ENTRANCE_PLAYER_HUD:
			_player_hud_visible = true
		ENTRANCE_ENEMY_PIC:
			# `GetEnemyMonFrontpic`: the trainer's picture is replaced in VRAM
			# before the ball is thrown, and the square itself is empty until
			# `BATTLE_BG_EFFECT_ENTER_MON` stamps the map back.
			_enemy_trainer_pic = 0
			_slid_pixels[Gen2Battle.ENEMY] = 0.0
		ENTRANCE_PLAYER_PIC:
			_player_backpic = ""
			_slid_pixels[Gen2Battle.PLAYER] = 0.0
	_push_view()


## `Battle_GetTrainerName`, which is the class and the trainer's own name, and
## `.linkbattle`, which is the other player's name with no class in front of it:
## a link battle is the one opponent with a name and no trainer behind it. A wild
## battle has neither.
func _enemy_battler_label() -> String:
	if _data == null:
		return "Enemy"
	if _enemy_trainer_class <= 0 or (_battle != null and _battle.is_link_battle):
		## `wOTPlayerName`, which the request carries: a link opponent is not in
		## any trainer table, so there is nothing to look the name up in.
		var linked: String = String(_world_battle_request.get("trainer_name", ""))
		return linked if not linked.is_empty() else "Enemy"
	return "%s %s" % [
		_data.trainer_name(_enemy_trainer_class), _enemy_trainer_name(),
	]


## What the opening is showing right now, for a frame by frame diff against a
## real cartridge: which squares hold what, which panels are up, whether a
## picture is sliding and what the box is saying.
func entrance_snapshot() -> Dictionary:
	return {
		"stages": _entrance_stages.size(),
		"message": _last_message,
		"awaits_press": _message_awaits_press,
		"enemy_hud": _enemy_hud_visible and _anim_hud_hidden != Gen2Battle.ENEMY,
		"player_hud": _player_hud_visible and _anim_hud_hidden != Gen2Battle.PLAYER,
		"enemy_trainer_pic": _enemy_trainer_pic,
		"player_backpic": _player_backpic,
		"balls": _hud_balls.size(),
		"sliding": sliding(),
		"frontpic": animating_frontpic(),
		"animating": animation_running(),
		"anim": int(_anim_event.get("index", 0)) if _anim != null else 0,
	}


## Whether both panels are on the map: neither side taken off by an animation,
## and both of them drawn by the entrance in the first place.
func _hud_visible() -> bool:
	return _enemy_hud_visible and _player_hud_visible and _anim_hud_hidden < 0


## `predef AnimateFrontpic` on the enemy's square, which `LoadMonAnimation` and
## `PokeAnim_InitPicAttributes` set up before the first frame is spent.
func _begin_frontpic(kind: int) -> void:
	if _data == null:
		return
	var record: Dictionary = _data.pic_animation(_enemy, _enemy_unown_form)
	if record.is_empty():
		return
	var animation := Gen2PicAnimation.new(record, kind)
	if animation.finished():
		return
	_frontpic = animation
	_stamp_frontpic()
	_push_view()


## `SlideBattlePicOut` over one square.
func _begin_slide(side: int) -> void:
	_slides.append({
		"player_side": side == Gen2Battle.PLAYER,
		"step": 0,
		"delay": Gen2BattleScreenMap.SLIDE_STEP_FRAMES,
	})


## `BattleStart_TrainerHuds`: the player's party balls always, the opponent's
## when a trainer is behind them, six sprites under a border of four tile kinds.
func _build_trainer_huds() -> void:
	_hud_balls = []
	_hud_border = []
	## Generation 1 draws party balls on the link battle's versus screen and
	## nowhere else: `SetupPlayerAndEnemyPokeballs` has that one caller.
	if _data != null and _data.generation == RomRegistry.GEN1:
		return
	_add_trainer_hud(Gen2Battle.PLAYER)
	if _battle != null and _battle.is_trainer_battle:
		_add_trainer_hud(Gen2Battle.ENEMY)


## One side of it. `LoadTrainerHudOAM` walks six slots from
## [constant HUD_BALL_AT] in [constant HUD_BALL_STEP]'s direction, and
## `PlaceHUDBorderTiles` draws the frame from a corner outwards the same way.
func _add_trainer_hud(side: int) -> void:
	var player_side: bool = side == Gen2Battle.PLAYER
	var at: Vector2i = HUD_BALL_AT[player_side]
	var step: int = int(HUD_BALL_STEP[player_side])
	var party: Gen2Party = _battle.party(side) if _battle != null else null
	for slot: int in Gen2Party.MAX_SIZE:
		_hud_balls.append({
			"x": at.x + slot * step, "y": at.y, "tile": _hud_ball_tile(party, slot),
		})
	var border: Vector2i = HUD_BORDER_AT[player_side]
	var tiles: Array = HUD_BORDER_TILES[player_side]
	var direction: int = 1 if player_side else -1
	_hud_border.append({"x": border.x, "y": border.y, "tile": int(tiles[0])})
	_hud_border.append({"x": border.x, "y": border.y + 1, "tile": int(tiles[1])})
	for index: int in HUD_BORDER_EDGE:
		_hud_border.append({
			"x": border.x - (index + 1) * direction, "y": border.y + 1,
			"tile": int(tiles[3]),
		})
	_hud_border.append({
		"x": border.x - (HUD_BORDER_EDGE + 1) * direction, "y": border.y + 1,
		"tile": int(tiles[2]),
	})


## `StageBallTilesData`: an empty slot, then a ball per party member, coloured by
## whether that member is fainted, statused or well.
func _hud_ball_tile(party: Gen2Party, slot: int) -> int:
	if party == null or slot >= party.size():
		return HUD_BALL_EMPTY
	var mon: Gen2BattleMon = party.at(slot)
	if mon == null:
		return HUD_BALL_EMPTY
	if mon.is_fainted():
		return HUD_BALL_FAINTED
	return HUD_BALL_STATUSED if mon.status != 0 else HUD_BALL_NORMAL


## One hardware frame of every running bar. Public so a test or a screenshot
## driver can settle the bars without waiting on real time.
func advance_bars() -> bool:
	if not bars_animating():
		return false
	var moved: bool = false
	for side: int in _bars.keys():
		var animation: Gen2HpBarAnimation = _bars[side]
		if animation.advance_frame():
			moved = true
		if animation.finished():
			_bars.erase(side)

	var boundary: bool = false
	if _exp_bar != null:
		if _exp_bar.advance_frame():
			moved = true
		boundary = _exp_bar.segment_finished()
		if _exp_bar.finished():
			_exp_bar = null
			# The levels crossed on the way did not touch the committed count, so
			# the end of the walk is where it catches up.
			_refresh_exp_bar()

	if moved:
		_push_view()

	if boundary and _exp_bar != null:
		# The bar has reached the end of the level it was filling and stopped
		# there. `.LoopLevels` prints its grew-to-level line at exactly this
		# point, so the pump runs on to the event that carries it.
		_show_next_event()
	return moved


## `_PlayBattleAnim`'s own framing, as steps the screen walks a frame at a time.
## Each is a dictionary carrying its own `kind`; the delays are
## `BattleAnimDelayFrame` counts and `script` is `RunBattleAnimScript`.
const ANIM_DELAY: StringName = &"delay"
const ANIM_SCRIPT: StringName = &"script"
const ANIM_CLEAR_HUD: StringName = &"clear_hud"
const ANIM_RESTORE_HUD: StringName = &"restore_hud"
const ANIM_WAIT_SFX: StringName = &"wait_sfx"
const ANIM_HIT_SOUND: StringName = &"hit_sound"
const ANIM_APPEAR_USER: StringName = &"appear_user"
## `PlaySFX` on its own, which only the entrance uses: an animation's own sounds
## come out of its script.
const ANIM_SFX: StringName = &"sfx"

## Whose square is showing the substitute's doll rather than the mon itself. The
## cartridge keeps this in VRAM rather than in a variable: `GetSubstitutePic`
## writes the doll over the battler's tiles and `DropPlayerSub` writes the picture
## back, so what is on the field is whatever was drawn last. The three writers are
## `anim_raisesub`/`anim_dropsub`, the two `noanim` commands the battle-scene
## option reaches instead, and a send-out.
var _substitute_pic: Dictionary = {Gen2Battle.PLAYER: false, Gen2Battle.ENEMY: false}

## The second answer the same three writers give. `GetBattleMonBackpic` tests
## `SUBSTATUS_SUBSTITUTE` first and `wPlayerMinimized` only after it, so a doll
## stands in front of the dot and the dot is what is underneath when it comes
## off. Written by [constant Gen2Battle.MINIMIZED] and cleared by a send-out.
var _minimize_pic: Dictionary = {Gen2Battle.PLAYER: false, Gen2Battle.ENEMY: false}

## `BattleAnimCmd_Minimize` writes `vTiles0`, which is off screen, and
## `..._UpdateActorPic` copies it onto the square 48 frames later. The dot is
## already on by then, `BattleCommand_StatUp` having set the byte two commands
## before the animation, so this only keeps the two halves of the source's own
## pair together. `BattleAnim_Transform` is the other user of the pair and no
## list here reaches it: `BattleCommand_Transform` calls `LoadMoveAnim` inline
## rather than through an `anim` command, and this port's Transform prints
## without an animation.
var _staged_minimize_pic: bool = false

## `wFXAnimID` is a word: an id past this is not a move and skips the whole
## battle-scene, hud and after-anim half of `BattleAnimRunScript`.
const ANIM_MOVE_LIMIT: int = 0x100
## `ANIM_THROW_POKE_BALL`, the first entry past the moves
## (constants/move_constants.asm).
const ANIM_THROW_POKE_BALL: int = 0x100

## `.shake_and_break_free`'s four texts, indexed by how many times the ball
## rocked. `PokeBallEffect` reads `wThrownBallWobbleCount`, one higher than the
## count of rocks, which is what [method Gen2WorldPartyHost._failed_wobbles]
## answers. There is no line for a rock on its own. Beside them:
## `BallBlockedText` and `BallDontBeAThiefText`, two boxes rather than one line,
## `BallBoxFullText`, said before the ball is thrown, and `_NewDexDataText`, which
## names the Pokemon and plays a sound of its own.
const NEW_DEX_DATA_TEXT: String = "%s's data\nwas newly added to\nthe #DEX."
const BALL_BLOCKED_TEXT: String = "The trainer\nblocked the BALL!"
const BALL_DONT_BE_A_THIEF_TEXT: String = "Don't be a thief!"
const BALL_BOX_FULL_TEXT: String = "The #MON BOX\nis full. That\ncan't be used now."
## `anim_if_param_equal NO_ITEM`, `BattleAnim_ThrowPokeBall`'s own first branch
## and the one `UseBallInTrainerBattle` sets `wBattleAnimParam` to.
const ANIM_PARAM_NO_ITEM: int = 0

const BREAK_FREE_TEXT: Array[String] = [
	"Oh no! The #MON\nbroke free!",
	"Aww! It appeared\nto be caught!",
	"Aargh!\nAlmost had it!",
	"Shoot! It was so\nclose too!",
]

## `SendOutMonText`'s four texts, in [constant Gen2Battle.SEND_OUT_GO]'s order.
const SEND_OUT_LINES: Array[String] = [
	"Go! %s!", "Do it! %s!", "Go for it,\n%s!", "Your foe's weak!\nGet'm, %s!",
]

## `PlayHitSound`'s three effects, by their `constants/sfx_constants.asm`
## numbers, which are the same in both pins.
const SFX_NOT_VERY_EFFECTIVE: int = 0xAB
## `wCryTracks`, which `PlayStereoCry` masks CHANNEL_TRACKS with: the enemy's
## cry keeps the low nibble's terminals and the player's the high nibble's.
const CRY_TRACKS_ENEMY: int = 0x0F
const CRY_TRACKS_PLAYER: int = 0xF0

const SFX_DAMAGE: int = 0xAC
const SFX_SUPER_EFFECTIVE: int = 0xAD

## `AnimateExpBar`'s two: `.PlayExpBarSound`'s at the head of every segment, and
## the one `.LoopLevels` and `.skip_exp_bar_animation` both play before their
## grew-to-level line. `BattleStartMessage`'s own, in front of a trainer's line.
const SFX_SHINE: int = 0x5E

## The twenty frames `BattleStartMessage` spends after `SFX_SHINE`, and the forty
## `DoBattle` spends before the player's Pokemon is sent out.
const TRAINER_START_FRAMES: int = 20
const PLAYER_ENTRANCE_FRAMES: int = 40

## `ShowPlayerMonsRemaining` and `ShowOTTrainerMonsRemaining`: where the first
## party ball sits and which way the other five are laid out. OAM coordinates
## subtract sixteen from the y and eight from the x, which is done here.
const HUD_BALL_AT: Dictionary = {
	false: Vector2i(9 * 8 - 8, 4 * 8 - 16), true: Vector2i(12 * 8 - 8, 12 * 8 - 16),
}
const HUD_BALL_STEP: Dictionary = {false: -8, true: 8}
## `StageBallTilesData`'s four tiles, as offsets into `LoadBallIconGFX`'s sheet.
const HUD_BALL_NORMAL: int = 0
const HUD_BALL_STATUSED: int = 1
const HUD_BALL_FAINTED: int = 2
const HUD_BALL_EMPTY: int = 3
## `DrawEnemyHUDBorder`'s `hlcoord 1, 2` and `DrawPlayerPartyIconHUDBorder`'s
## `hlcoord 18, 10`, and the four tiles each walks out from there: a side, the
## corner under it, the far corner and the bottom edge between them.
const HUD_BORDER_AT: Dictionary = {false: Vector2i(1, 2), true: Vector2i(18, 10)}
const HUD_BORDER_TILES: Dictionary = {
	false: [0x6D, 0x74, 0x78, 0x76], true: [0x73, 0x5C, 0x6F, 0x76],
}
## `ld b, 8`, the run of bottom edge between the two corners.
const HUD_BORDER_EDGE: int = 8

const SFX_EXP_BAR: int = 0x8C
const SFX_HIT_END_OF_EXP_BAR: int = 0xB6


## Whether an animation, or any of the delays `PlayBattleAnim` wraps it in, is
## still running.
func animation_running() -> bool:
	return _anim != null or not _anim_plan.is_empty() or _anim_delay > 0


## One hardware frame of the animation. Public so a test or a screenshot driver
## can settle or step one without waiting on real time.
func advance_animation() -> bool:
	if not animation_running():
		return false
	if _anim_delay > 0:
		_anim_delay -= 1
		return true
	if _anim != null:
		if _anim.advance_frame() and not _anim.finished():
			_after_anim_frame()
			return true
		_end_script()
		return true
	_run_next_anim_step()
	return true


## `PlayFXAnimID`: three frames of delay, then `PlayBattleAnim`. Builds the whole
## of `_PlayBattleAnim` and `BattleAnimRunScript` as a step list, since the parts
## of it that spend frames have to be spent one rendered frame at a time.
func _begin_animation(event: Dictionary) -> void:
	_anim_event = event
	_anim_plan = []
	_clear_kept_sprites()

	var index: int = int(event.get("index", 0))
	var after: int = int(event.get("after_anim", 0))
	var is_move: bool = index < ANIM_MOVE_LIMIT
	var gen1: bool = _anim_data != null and _anim_data.gen1()

	# `PlayFXAnimID`'s own `ld c, 3 / call DelayFrames`, then `_PlayBattleAnim`'s
	# six, `BattleAnimAssignPals`/`..._RequestPals` and one more. The two pal
	# calls write nothing here: the palettes an animation remaps are the battle's
	# own and are read back off the background every frame. An entrance comes
	# through `Call_PlayBattleAnim` instead, whose `WaitBGMap` is one frame.
	var lead: int = 1 if bool(event.get("called", false)) else 3
	_step(ANIM_DELAY, {"frames": lead + 6 + 1})

	if is_move:
		if Gen2OptionsStore.current().battle_scene:
			# `MoveAnimation` leaves the panels where they are: only Crystal's
			# `_PlayBattleAnim` takes the acting side's hud off the map first.
			if not gen1:
				_step(ANIM_CLEAR_HUD, {})
			_step(ANIM_SCRIPT, {"index": index})
			# `xor a / ldh [hSCX] / ldh [hSCY]`, a delay, then the huds.
			_step(ANIM_DELAY, {"frames": 1})
			if not gen1:
				_step(ANIM_RESTORE_HUD, {})
		else:
			_apply_sub_pic_no_anim(index, int(event.get("param", 0)))
		if after != 0:
			_step(ANIM_WAIT_SFX, {})
			_step(ANIM_HIT_SOUND, {})
			_step(ANIM_SCRIPT, {
				"index": after + Gen2BattleAnimPlayer.BATTLE_AFTERANIMS,
			})
	else:
		_step(ANIM_WAIT_SFX, {})
		_step(ANIM_HIT_SOUND, {})
		_step(ANIM_SCRIPT, {"index": index})

	# `hBGMapMode = 1`, three delays and `WaitSFX`.
	_step(ANIM_DELAY, {"frames": 3})
	_step(ANIM_WAIT_SFX, {})
	# A send-out draws the picture itself and the ball animation only shows it
	# arriving, so a cache with no animation layer still owes the square one.
	if bool(event.get("restore_user_pic", false)) or (not is_move and _anim_row(index) < 0):
		_step(ANIM_APPEAR_USER, {})
	_run_next_anim_step()


## The doll the animation would have drawn, written straight into the picture
## when the battle-scene option is off and the script never runs.
##
## `BattleCommand_LowerSub` and `..._RaiseSub` both branch to their own `noanim`
## routine on `_CheckBattleScene`, and `BattleCommand_Substitute`'s own
## `.no_anim` calls `RaiseSubNoAnim`, so the three animation parameters answer
## the same two pictures with the scenes turned off as with them on.
func _apply_sub_pic_no_anim(index: int, param: int) -> void:
	if index != Gen2EffectCommands.SUBSTITUTE_MOVE:
		return
	_set_substitute_pic(
		Gen2Battle.ENEMY if bool(_anim_event.get("enemy_turn", false)) else Gen2Battle.PLAYER,
		param != Gen2EffectCommands.SUBSTITUTE_ANIM_DROP
	)


func _set_substitute_pic(side: int, raised: bool) -> void:
	if bool(_substitute_pic.get(side, false)) == raised:
		return
	_substitute_pic[side] = raised
	_push_view()


## The dot `GetMinimizePic` answers with, which outlives the animation that drew
## it: nothing takes it off until the Pokemon leaves the field.
func _set_minimize_pic(side: int, minimized: bool) -> void:
	if bool(_minimize_pic.get(side, false)) == minimized:
		return
	_minimize_pic[side] = minimized
	_push_view()


## `hBattleTurn` inside an animation: whose animation this is.
func _anim_actor() -> int:
	return Gen2Battle.ENEMY if bool(_anim_event.get("enemy_turn", false)) \
		else Gen2Battle.PLAYER


func _step(kind: StringName, values: Dictionary) -> void:
	var entry: Dictionary = values.duplicate()
	entry["kind"] = kind
	_anim_plan.append(entry)


func _run_next_anim_step() -> void:
	while not _anim_plan.is_empty():
		var step: Dictionary = _anim_plan.pop_front()
		match StringName(step["kind"]):
			ANIM_DELAY:
				_anim_delay = int(step["frames"])
				return
			ANIM_CLEAR_HUD:
				# `BattleAnimClearHud`: a delay, the hud off the map, then three
				# more while the map reaches VRAM. `ClearActorHud` reads
				# `hBattleTurn` and clears that side's panel only, which is why
				# the target's bar is still there to watch while it drains.
				_anim_hud_hidden = Gen2Battle.ENEMY \
					if bool(_anim_event.get("enemy_turn", false)) else Gen2Battle.PLAYER
				_anim_delay = 4
				_push_view()
				return
			ANIM_RESTORE_HUD:
				_anim_hud_hidden = -1
				_anim_delay = 4
				_push_view()
				return
			ANIM_WAIT_SFX:
				## `WaitSFX`, bounded by
				## [constant Gen2AudioPlayer.SERVICE_GAP_FRAMES] as the world's is.
				if _audio_player != null and _audio_player.effect_playing():
					var rendered: int = _audio_player.timeline_updates()
					var still: int = 0 if int(step.get("rendered", -1)) != rendered \
						else int(step.get("still", 0)) + 1
					if still <= Gen2AudioPlayer.SERVICE_GAP_FRAMES:
						step["rendered"] = rendered
						step["still"] = still
						_anim_plan.push_front(step)
						_anim_delay = 1
						return
			ANIM_SFX:
				_play_sfx(int(step["sfx"]))
			ANIM_HIT_SOUND:
				_play_hit_sound()
			ANIM_SCRIPT:
				if _start_script(int(step["index"])):
					return
			ANIM_APPEAR_USER:
				# `AppearUserLowerSub`, which Fly and Dig reach after the
				# animation: `LowerSubNoAnim` writes the user's own picture and
				# `AppearUser` stamps it back into the map it was taken out of.
				var enemy_turn: bool = bool(_anim_event.get("enemy_turn", false))
				_set_substitute_pic(
					Gen2Battle.ENEMY if enemy_turn else Gen2Battle.PLAYER, false
				)
				_restamp_battler(not enemy_turn)
				_push_view()
	_anim = null
	_anim_event = {}
	_push_view()


## `AttackAnimationPointers`' rows for the ids the engine names past a move
## number. Generation 1 numbers those differently from Crystal, and both of the
## status pairs are picked by which side the animation is playing on.
const GEN1_ANIM_IDS: Dictionary = {
	Gen2BattleAnimPlayer.ANIM_CONFUSED: [190, 191],
	Gen2BattleAnimPlayer.ANIM_BRN: [186, 186],
	Gen2BattleAnimPlayer.ANIM_PSN: [186, 186],
	Gen2BattleAnimPlayer.ANIM_PAR: [184, 184],
}


## `wAnimationID` less one, which is what `AttackAnimationPointers` is indexed
## by. Crystal's own table is indexed by the id itself, so this is the identity
## there. -1 is an id this cartridge has no row for: `ANIM_SEND_OUT_MON`, the
## thrown ball and the four after-anims are all their own routines in Generation
## 1 rather than entries in the table, and `ANIM_FRZ` has no animation at all.
func _anim_row(index: int) -> int:
	if _anim_data == null:
		return -1
	if not _anim_data.gen1():
		return index
	if index < ANIM_MOVE_LIMIT:
		return index - 1
	var pair: Variant = GEN1_ANIM_IDS.get(index, null)
	if not pair is Array:
		return -1
	return int((pair as Array)[1 if bool(_anim_event.get("enemy_turn", false)) else 0]) - 1


## `RunBattleAnimScript`, which is `ClearBattleAnims` and then a frame loop. The
## tilemap the battle is showing is what the effects edit, so it goes in here
## and comes back out at the end. A cache carrying no animation layer answers
## with no player, and the step is skipped rather than the whole framing: the
## delays and the hud belong to the screen, not to the data.
func _start_script(index: int) -> bool:
	var row: int = _anim_row(index)
	if _anim_data == null or row < 0:
		return false
	var wobbles: Array[int] = []
	wobbles.assign(_anim_event.get("wobbles", []))
	_anim = Gen2BattleAnimPlayer.create_gen1(
		_anim_data, row, bool(_anim_event.get("enemy_turn", false))
	) if _anim_data.gen1() else Gen2BattleAnimPlayer.create(
		_anim_data, row, bool(_anim_event.get("enemy_turn", false)),
		int(_anim_event.get("param", 0)), wobbles
	)
	if _anim == null:
		return false
	_anim.background().set_bg_map(_bg_map)
	_after_anim_frame()
	return true


## What one `.playframe` produced: the sounds its commands asked for, and the
## video state for the renderer.
func _after_anim_frame() -> void:
	for command: Dictionary in _anim.frame_commands():
		match StringName(command["name"]):
			Gen2BattleAnimScript.SOUND:
				var sound: Array = command["operands"]
				_play_anim_sound(int(sound[1]), int(sound[0]))
			Gen2BattleAnimScript.CRY:
				_play_anim_cry(int((command["operands"] as Array)[0]))
			Gen2BattleAnimScript.RAISE_SUB, Gen2BattleAnimScript.DROP_SUB:
				# `BattleAnimCmd_RaiseSub` and `..._DropSub` write the actor's own
				# tiles, and the actor is `hBattleTurn`, which is whose animation
				# this is.
				_set_substitute_pic(
					_anim_actor(),
					StringName(command["name"]) == Gen2BattleAnimScript.RAISE_SUB
				)
			Gen2BattleAnimScript.MINIMIZE:
				_staged_minimize_pic = true
			Gen2BattleAnimScript.UPDATE_ACTOR_PIC:
				if _staged_minimize_pic:
					_staged_minimize_pic = false
					_set_minimize_pic(_anim_actor(), true)
			Gen2BattleAnimScript.MINIMIZE_OPP:
				# `GetMinimizePic` straight into `vTiles2`. No animation script
				# names it: `DropPlayerSub` and `DropEnemySub` are its only
				# callers, and both are the reload the byte already answers.
				_set_minimize_pic(_anim_actor(), true)
	_carry_battler_reports()
	_push_view()


## The anim background's own report, lifted onto the screen so it outlives the
## animation the way the tilemap it was written beside does.
func _carry_battler_reports() -> void:
	if _anim == null:
		return
	var background: Gen2BattleAnimBackground = _anim.background()
	for player_side: bool in [true, false]:
		var side: int = Gen2Battle.PLAYER if player_side else Gen2Battle.ENEMY
		_battler_visible[side] = bool(background.battler_visible[player_side])
		_battler_scale[side] = float(background.battler_scale[player_side])
		_battler_shift[side] = background.battler_shift[player_side] as Vector2


## `PlaceGraphic` putting a whole picture back on a square, which is the one
## thing that undoes every report above.
func _restamp_battler(player_side: bool) -> void:
	Gen2BattleScreenMap.stamp(_bg_map, player_side, _generation())
	var side: int = Gen2Battle.PLAYER if player_side else Gen2Battle.ENEMY
	_battler_visible[side] = true
	_battler_scale[side] = 1.0
	_battler_shift[side] = Vector2.ZERO


func _end_script() -> void:
	if _anim != null:
		_bg_map = _anim.background().bg_map.duplicate()
		## `BattleAnim_ClearOAM` has already run inside the player, so what is
		## left here is what `anim_keepsprites` kept.
		_kept_sprites = _anim.sprites()
		_kept_tiles = _anim.tiles()
	_anim = null
	_run_next_anim_step()


## `ClearSprites`. Nothing is drawn from the kept objects once they are gone, so
## a caller that has nothing to clear pays only the push.
func _clear_kept_sprites() -> void:
	if _kept_sprites.is_empty() and _kept_tiles.is_empty():
		return
	_kept_sprites = []
	_kept_tiles = []
	_push_view()


## `PlayBattleMusic`, which `FindFirstAliveMonAndStartBattle` runs in front of
## `DoBattleTransition`: the piece playing is stopped, the volume goes back to
## maximum, and the battle's own track starts. A world battle has already had it
## started by the screen that ran the transition, on the same driver and from the
## same request, so this asks for a track already playing and the driver
## continues it. A battle standing on its own is where it actually starts.
func _play_battle_music() -> void:
	_battle_music = Gen2Battle.MUSIC_NONE
	if _audio_player == null or _data == null or _battle == null:
		return
	var landmark: int = _world_context.landmark if _world_context != null \
		else Gen2WorldRadio.LANDMARK_SPECIAL
	_battle_music = Gen2WorldBattleAdapter.music_for(
		_world_battle_request, landmark, _time_of_day,
		Gen2WorldState.is_crystal_profile(_data),
	)
	var record: Dictionary = _data.world_audio(&"music", _battle_music)
	if record.is_empty():
		return
	_audio_player.play_record(record, &"map_music", _audio_assets())


## Which track [method _play_battle_music] chose, for a check or a test that
## cannot hear one. `MUSIC_NONE` until a world battle has started.
func battle_music() -> int:
	return _battle_music


## `PlaySFX`, which is every effect this screen plays that is not an animation's
## own. Its `wCurSFX` gate is what stops two of them piling up; [param waited] is
## a `WaitSFX` the source spends first, which the gate must not then refuse.
func _play_sfx(sfx: int, waited: bool = false) -> void:
	if _audio_player == null or _data == null:
		return
	var record: Dictionary = _data.world_audio(&"sfx", sfx)
	if record.is_empty():
		return
	_audio_player.play_record(
		record, &"waited_sfx" if waited else &"sound", _audio_assets()
	)


## `BattleAnimCmd_Sound`, the cartridge's one `PlayStereoSFX` caller: the second
## operand is the SFX id and the first is what it pans by.
func _play_anim_sound(sfx: int, tracks: int) -> void:
	if _audio_player == null or _data == null:
		return
	var record: Dictionary = _data.world_audio(&"sfx", sfx)
	if record.is_empty():
		return
	_audio_player.play_record(
		record, &"stereo_sfx", _audio_assets(), false, Gen2BattleAnimScript.sound_panning(
			tracks, bool(_anim_event.get("enemy_turn", false))
		)
	)


## `BattleAnimCmd_Cry`: whichever battler `hBattleTurn` names, at its own
## `PokemonCries` pitch and length plus the command's own `.CryData` row.
func _play_anim_cry(pitch: int) -> void:
	if _audio_player == null or _data == null:
		return
	var enemy_turn: bool = bool(_anim_event.get("enemy_turn", false))
	var record: Dictionary = _data.species_cry(_enemy if enemy_turn else _player)
	if record.is_empty():
		return
	_audio_player.play_record(
		Gen2BattleAnimScript.cry_with_offsets(record, pitch), &"cry", _audio_assets(),
		false, cry_tracks(enemy_turn)
	)


## `PlayStereoCry` behind an entrance, which names its own species rather than
## reading the field: the event is spent before its own panel is drawn.
func _play_entrance_cry(side: int, species: int) -> void:
	if _audio_player == null or _data == null:
		return
	var record: Dictionary = _data.species_cry(species)
	if record.is_empty():
		return
	_audio_player.play_record(
		record, &"cry", _audio_assets(), false, cry_tracks(side == Gen2Battle.ENEMY)
	)


## `wCryTracks`: every `PlayStereoCry` in `engine/battle/core.asm` writes `$0f`
## for the enemy's cry and `$f0` for the player's, which is what puts each
## battler's cry on its own side of the field.
static func cry_tracks(enemy: bool) -> int:
	return CRY_TRACKS_ENEMY if enemy else CRY_TRACKS_PLAYER


## `PlayHitSound`: only the two damage after-anims have one, and which of the
## three it is comes off `wTypeModifier`.
func _play_hit_sound() -> void:
	var after: int = int(_anim_event.get("after_anim", 0))
	if after != Gen2BattleAnimPlayer.AFTER_ANIM_ENEMY_DAMAGE \
			and after != Gen2BattleAnimPlayer.AFTER_ANIM_PLAYER_DAMAGE:
		return
	var effectiveness: int = int(_anim_event.get("effectiveness", Gen2Layout.MATCHUP_EFFECTIVE))
	if effectiveness == 0:
		return
	var sfx: int = SFX_DAMAGE
	if effectiveness > Gen2Layout.MATCHUP_EFFECTIVE:
		sfx = SFX_SUPER_EFFECTIVE
	elif effectiveness < Gen2Layout.MATCHUP_EFFECTIVE:
		sfx = SFX_NOT_VERY_EFFECTIVE
	_play_sfx(sfx, true)


func _audio_assets() -> Dictionary:
	if _data == null:
		return {}
	return {
		"wave_samples": _data.world_audio_asset(&"wave_samples"),
		"drumkits": _data.world_audio_asset(&"drumkits"),
	}


## The two pictures put back where a battle draws them, which every send-out and
## every fresh battle does. `ClearBattleAnims` never touches the map, so a Fly
## that took a picture off it leaves it off until something stamps it back.
func _reseed_bg_map() -> void:
	_bg_map = Gen2BattleScreenMap.seeded(_generation())
	_faints.clear()
	## A slide still owed walks the picture this put back off its own square.
	_slides.clear()
	_slid_pixels = {Gen2Battle.PLAYER: 0.0, Gen2Battle.ENEMY: 0.0}


## How full the exp bar is, in `PlaceExpBar`'s own pixels. The committed value:
## the animation below draws its own while it runs, the way the HP bars do, and
## a write that moves the committed count cancels it for the same reason
## [method set_hp] cancels a drain.
func set_exp(pixels: int) -> void:
	var value: int = clampi(pixels, 0, Gen2ExpBarAnimation.LENGTH_PX)
	if value != _exp:
		_exp_bar = null
	_exp = value
	_push_view()


## Where the player's Pokémon sits between its current level's threshold and the
## next, on its growth curve. Recomputed at battle start and whenever
## [constant Gen2Battle.EXP_GAINED] or [constant Gen2Battle.GREW_LEVEL] moves the
## number behind it.
func _refresh_exp_bar() -> void:
	if _battle == null or _battle.player == null:
		set_exp(0)
		return

	var mon: Gen2BattleMon = _battle.player
	set_exp(Gen2ExpBarAnimation.pixels_for(mon.growth_rate(), mon.level, mon.exp))


## What the exp bar is drawing: the animation's pixels while one runs, and the
## committed count otherwise.
func _drawn_exp() -> int:
	return _exp if _exp_bar == null else _exp_bar.pixels()


## Begins the fill [param event]'s award earns, which is `AnimateExpBar`, from
## the [param from_pixels] the bar stood at before the award was committed. The
## segments are read out of the events still queued behind this one: one per level
## crossed, then `.FinishExpBar`'s partial fill. Both of the routine's own guards
## are kept: a gainer who is not the Pokemon on the field animates nothing
## (`wCurPartyMon` against `wCurBattleMon`), and neither does one at `MAX_LEVEL`.
func _start_exp_bar(event: Dictionary, from_pixels: int) -> void:
	_exp_bar = null
	if _battle == null or _battle.player == null:
		return

	var index: int = int(event["index"])
	if index != _battle.party(Gen2Battle.PLAYER).active:
		return

	var mon: Gen2BattleMon = _battle.player
	var rate: int = mon.growth_rate()
	# Only this award's own level-ups: a second [constant Gen2Battle.EXP_GAINED]
	# behind it is the Exp. Share pass, and its levels belong to its own bar.
	var levels: int = 0
	for queued: Dictionary in _pending:
		var kind: StringName = StringName(queued["type"])
		if kind == Gen2Battle.EXP_GAINED:
			break
		if kind == Gen2Battle.GREW_LEVEL and int(queued["index"]) == index:
			levels += 1
	if mon.level - levels >= Gen2Experience.MAX_LEVEL:
		return

	var targets: Array[int] = []
	for _level: int in levels:
		targets.append(Gen2ExpBarAnimation.LENGTH_PX)
	targets.append(Gen2ExpBarAnimation.pixels_for(rate, mon.level, mon.exp))
	_exp_bar = Gen2ExpBarAnimation.create(from_pixels, targets)
	## `.PlayExpBarSound` runs before the first `.LoopBarAnimation`, so the sound
	## leads the fill by its own ten frames.
	if not _exp_bar.finished():
		_play_sfx(SFX_EXP_BAR, true)
	_push_view()


## Whether [param index] has another [constant Gen2Battle.GREW_LEVEL] still
## queued before the next award. `.level_loop` raises every level first and the
## box is drawn once after it, so only the last one carries a box.
func _more_levels_queued(index: int) -> bool:
	for queued: Dictionary in _pending:
		var kind: StringName = StringName(queued["type"])
		if kind == Gen2Battle.EXP_GAINED:
			return false
		if kind == Gen2Battle.GREW_LEVEL and int(queued["index"]) == index:
			return true
	return false


## `.skip_exp_bar_animation`'s `Textbox` and `PrintTempMonStats`, or nothing
## while [member _level_up_stats] is empty. `SafeLoadTempTilemapToTilemap` puts
## the screen back afterwards, which is what clearing it is.
func _refresh_level_up_box() -> void:
	if _level_up_layer == null:
		return
	if _level_up_stats.is_empty() or _menu_page == null:
		_level_up_layer.visible = false
		return
	var box: Gen2MenuBox = Gen2BattleMenu.level_up_box()
	_show_layer_image(
		_level_up_layer,
		_menu_page.render(
			box, [], -1, "", 0,
			Gen2StatsScreenPage.stats_placements(
				Gen2BattleMenu.LEVEL_UP_STATS_AT, _level_up_stats,
				Gen2BattleMenu.LEVEL_UP_STATS_SPACING
			)
		),
		box.border_position() * Gen2Font.TILE
	)


func _clear_level_up_box() -> void:
	if _level_up_stats.is_empty():
		return
	_level_up_stats = {}
	_refresh_level_up_box()


## [param prompt] is the text's own terminator: `prompt` waits for a press and
## `done` does not, which is the difference between the line a battle opens with
## and the two send-out lines an animation is played underneath.
func show_message(text: String, prompt: bool = true) -> void:
	# `BattleStartMessage` is called after `InitBattleDisplay` returns, so
	# nothing is said while the pics are still sliding: the box drawn before the
	# slide is an empty one.
	if _intro != null:
		_intro_message = text
		return
	_last_message = text
	## `StdBattleTextbox` blocks on a press for a line it printed; an empty box
	## is the one a menu is drawn over and owes nothing.
	_message_awaits_press = prompt and not text.is_empty()
	if _box != null:
		_box.show_text(text, prompt)


## What the animation layer is doing right now, for a scene test or a screenshot
## driver: which animation, whose turn it is, whether a script is actually
## running (a battle scene turned off spends the delays and runs none), and how
## much it is drawing.
func animation_snapshot() -> Dictionary:
	return {
		"running": animation_running(),
		"playing": _anim != null,
		"index": int(_anim_event.get("index", 0)),
		"enemy_turn": bool(_anim_event.get("enemy_turn", false)),
		"after_anim": int(_anim_event.get("after_anim", 0)),
		"sprites": (_anim.sprites() as Array).size() if _anim != null else 0,
		"hud_visible": _hud_visible(),
		## Whether each square still carries its picture. An animation may leave
		## one off, and `AppearUser` is the only thing that puts a whole one back,
		## so a driver photographing a turn has to be able to read it.
		"battler_visible": [
			bool(_battler_visible[Gen2Battle.PLAYER]),
			bool(_battler_visible[Gen2Battle.ENEMY]),
		],
	}


## Compact state for scene tests and screenshot drivers. It reports the message
## currently shown by the text box rather than reaching into its texture.
func battle_snapshot() -> Dictionary:
	return {
		"ready": is_ready(),
		"world_battle_active": _world_battle_active,
		"battle_over": _battle != null and _battle.is_over(),
		"winner": _battle.winner() if _battle != null and _battle.is_over() else -1,
		"enemy": _enemy,
		"player": _player,
		"message": _last_message,
		"completion_sent": _world_battle_completion_sent,
		"entrance_running": entrance_running(),
		## Whether the line on screen is one `<PROMPT>` or `<CONT>` blocks on.
		"awaits_press": _message_awaits_press,
		"switch_stage": _switch_stage,
		"switch_cursor": (
			_switch_offer.selected_index() if _switch_offer != null
			else (_switch_menu.cursor if _switch_menu != null else -1)
		),
		"switch_forced": _switch_menu != null and _switch_menu.forced,
		"switch_reason": _switch_reason,
		"menu_stage": _menu_stage,
		"menu_position": _menu_position,
		"move_cursor": _move_cursor,
		"move_rows": _move_rows.duplicate(true),
		"capture_selecting": _capture_selecting,
		"capture_waiting": _capture_waiting,
		"capture_ball": _selected_capture_ball(),
		"capture_balls": _capture_balls.duplicate(),
		"capture_quantities": _capture_quantities.duplicate(),
		"level_up_stats": _level_up_stats.duplicate(),
	}


## The plain reading a registered battle-information provider annotates from:
## both sides' live stat stages, the weather and what is left of it, who is
## standing, what is on screen, whether this opponent had been seen in this save,
## and each move's exact effectiveness against the defender. That effectiveness is
## [method GameData.type_effectiveness] over [method Gen2BattleMon.types] carrying
## Foresight's identified state, so a provider never copies the type chart and
## never rebuilds state from the event stream.
func info_snapshot() -> Dictionary:
	var player: Gen2BattleMon = _battle.mon(Gen2Battle.PLAYER) if _battle != null else null
	var enemy: Gen2BattleMon = _battle.mon(Gen2Battle.ENEMY) if _battle != null else null
	var defending: Array = enemy.types() if enemy != null else []
	var identified: bool = enemy != null and Gen2Substatus.has(
		enemy.substatus, Gen2Substatus.IDENTIFIED
	)
	var rows: Array = []
	for row: Dictionary in _move_rows:
		var out: Dictionary = row.duplicate(true)
		out["effectiveness"] = _data.type_effectiveness(
			int(row.get("type", 0)), defending, identified
		) if _data != null else Gen2Layout.MATCHUP_EFFECTIVE
		rows.append(out)
	return {
		"ready": is_ready(),
		"player_species": _player, "enemy_species": _enemy,
		"player_level": _player_level, "enemy_level": _enemy_level,
		"player_stages": player.stages.duplicate() if player != null else {},
		"enemy_stages": enemy.stages.duplicate() if enemy != null else {},
		"enemy_types": defending.duplicate(),
		"enemy_identified": identified,
		"enemy_seen_before": _enemy_seen_before,
		"weather": _battle.weather if _battle != null else Gen2Weather.NONE,
		"weather_turns": _battle.weather_turns if _battle != null else 0,
		"hud_visible": _hud_visible(),
		"enemy_hud_visible": _enemy_hud_visible and _anim_hud_hidden != Gen2Battle.ENEMY,
		"player_hud_visible": _player_hud_visible and _anim_hud_hidden != Gen2Battle.PLAYER,
		"menu_stage": _menu_stage,
		"menu_position": _menu_position,
		"move_cursor": _move_cursor,
		"move_rows": rows,
		## Where `MoveSelectionScreen` puts its first row and how far apart the
		## rest are, so a provider annotating the list never has to know the
		## menu's own coordinates, and the box's right-hand column, which is the
		## one cell of a row nothing else is written in.
		"move_rows_at": Gen2BattleMenu.move_box().item_position(0),
		"move_rows_step": Gen2BattleMenu.move_box().item_position(1) \
			- Gen2BattleMenu.move_box().item_position(0),
		"move_rows_right": Gen2BattleMenu.MOVE_RIGHT - 1,
		## `EFFECTIVE` itself, so a provider compares against the engine's own
		## neutral rather than repeating the number.
		"neutral": Gen2Layout.MATCHUP_EFFECTIVE,
	}


## Whether the annotation layer may draw at all. Hidden wherever one of the
## host's own full-screen subflows owns the same cells: the party page, the pack
## and its two sub-lists, ball selection, the forget offer, the naming prompt and
## the entrance, each of which is the whole interface rather than a box in it.
func _annotations_visible() -> bool:
	return _renderer_ready and _annotations != null and _intro == null \
		and _capture_nickname_host == null and _switch_stage == &"" \
		and not _pack_selecting and not _pack_move_selecting \
		and not _capture_selecting and _forget_stage == &""


## One of the four lists in front of the fight opened or closed: the pack, its
## two sub-lists and the forget offer. Both layers follow the state rather than
## every call site that changes one remembering to take it down. A ball thrown
## from the pack left its list standing over the whole fight, because the throw
## is a message and no message redraws a menu.
func _list_state_changed() -> void:
	_gate_annotations()
	_reopen_menu_layer()


## Rebuilds the layer the frame a modal takes the interface or gives it back.
##
## Every state [method _annotations_visible] reads writes through a setter that
## reaches here, so ownership is answered where it changes rather than at each
## caller that opens a subflow: a modal built next year hides the annotations by
## being made of the same flags, and nothing has to remember to refresh.
func _gate_annotations() -> void:
	if _annotation_layer == null:
		return
	if _annotations_visible() == _annotations_ungated:
		return
	_refresh_annotations()


## Rebuilds the annotation layer when what a provider would answer has changed.
## Cheap to call on every push: with no provider registered the signature is
## empty for the whole battle and nothing is ever drawn.
func _refresh_annotations() -> void:
	if _annotation_layer == null:
		return
	_annotations_ungated = _annotations_visible()
	if not _annotations_ungated or Gen2ModHost.instance().battle_info_ids().is_empty():
		_hide_annotations()
		return
	var placements: Array = Gen2ModHost.instance().battle_info_placements(info_snapshot())
	var signature: String = str(placements)
	if signature == _annotations_drawn:
		var shown: bool = not placements.is_empty()
		_annotation_layer.visible = shown
		if _annotation_field_layer != null:
			_annotation_field_layer.visible = shown \
				and Gen2BattleAnnotations.any_field(placements)
		return
	_annotations_drawn = signature
	if placements.is_empty():
		_hide_annotations()
		return
	var indices := PackedByteArray()
	indices.resize(Gen2Screen.WIDTH * Gen2Screen.HEIGHT)
	_annotations.draw(placements, indices, Gen2Screen.WIDTH)
	_show_layer_image(
		_annotation_layer,
		Gen2PicImage.from_indices(
			indices, Gen2Screen.WIDTH, Gen2Screen.HEIGHT,
			PokePalette.pic_palette(PackedColorArray([Color.WHITE, Color.BLACK])),
			true
		),
		Vector2i.ZERO
	)
	_refresh_annotation_field(placements)


## The field layer under the ink: the cells the flagged placements own, painted
## in the same white the cartridge's own boxes are and at the opacity the
## selected renderer asks its interface to be drawn at, which is 1.0 for the
## built-in arena and for anything on the hardware viewport.
func _refresh_annotation_field(placements: Array) -> void:
	if _annotation_field_layer == null:
		return
	if not Gen2BattleAnnotations.any_field(placements):
		_annotation_field_layer.visible = false
		return
	var indices := PackedByteArray()
	indices.resize(Gen2Screen.WIDTH * Gen2Screen.HEIGHT)
	_annotations.draw_field(placements, indices, Gen2Screen.WIDTH)
	var opacity: float = Gen2ModHost.renderer_interface_opacity(_renderer)
	var field := Color(Color.WHITE, opacity)
	_show_layer_image(
		_annotation_field_layer,
		Gen2PicImage.from_indices(
			indices, Gen2Screen.WIDTH, Gen2Screen.HEIGHT,
			PackedColorArray([field, field, field, field]),
			true
		),
		Vector2i.ZERO
	)


## Both annotation layers away together: the field exists only to sit under ink
## that is being drawn, so it never outlives it by a frame.
func _hide_annotations() -> void:
	_annotation_layer.visible = false
	if _annotation_field_layer != null:
		_annotation_field_layer.visible = false
	_annotations_drawn = ""


## Supplies the battle with the overworld's own clock reading, which Morning Sun,
## Synthesis and Moonlight are the only things to read. Set before the request is
## started; a battle begun without it stands at midday.
func set_time_of_day(value: int) -> void:
	_time_of_day = value


## Supplies where the battle is being fought, for a renderer that stages it on
## the map. Set before the scene enters the tree, the way the data source is:
## the renderer is built in _ready() and is handed this straight after
## [method Gen2BattleRenderer.set_battle_data]. Nothing in the battle itself
## reads it.
func set_world_context(context: Gen2BattleWorldContext) -> void:
	_world_context = context
	_push_world_context()


func world_context() -> Gen2BattleWorldContext:
	return _world_context


## `BattlePack`, which is the same pack with `wBattleMode` set: the bag rows the
## world hands over, already filtered to what `CheckItemMenu`'s battle nibble
## says can be used at all. Balls stay in the list and reach the ball selector,
## since that is where the throw is drawn.
func set_battle_pack(items: Array, quantities: Dictionary = {}) -> void:
	_pack_rows.clear()
	for raw_item: Variant in items:
		var item: int = int(raw_item)
		if item > 0 and not _pack_rows.has(item):
			_pack_rows.append(item)
	_pack_quantities = quantities.duplicate()
	if _pack_index >= _pack_rows.size():
		_pack_index = 0


func battle_pack_items() -> Array[int]:
	return _pack_rows.duplicate()


## `BattleMenu_Pack`'s own list. A row is chosen with left and right, used with A
## and left with B, the way ball selection already is.
func open_battle_pack() -> Dictionary:
	if _battle == null or _battle.is_over() or not _pending.is_empty():
		return {"ok": false, "reason": &"battle_events_pending"}
	_close_battle_menu()
	if not _battle.allows_bag_items():
		show_message("Items can't be\nused here.")
		return {"ok": false, "reason": &"items_cant_be_used_here"}
	if _pack_rows.is_empty():
		show_message("You have no items to use!")
		return {"ok": false, "reason": &"no_usable_items"}
	_pack_selecting = true
	_pack_index = mini(_pack_index, _pack_rows.size() - 1)
	_show_pack_selection()
	return {"ok": true, "item": selected_pack_item()}


func selected_pack_item() -> int:
	if _pack_rows.is_empty():
		return 0
	return int(_pack_rows[posmod(_pack_index, _pack_rows.size())])


func select_pack_row(index: int) -> Dictionary:
	if not _pack_selecting or _pack_rows.is_empty():
		return {"ok": false, "reason": &"pack_not_open"}
	_pack_index = posmod(index, _pack_rows.size())
	_show_pack_selection()
	return {"ok": true, "item": selected_pack_item()}


## The list itself is the menu layer's; the box below it is
## `UpdateItemDescription`'s, which prints the row the cursor is on.
func _show_pack_selection() -> void:
	show_message(Gen2WorldPack.row_description(_data, selected_pack_item()))
	_reopen_menu_layer()


func close_battle_pack() -> void:
	_pack_selecting = false
	_pack_item = 0
	_open_battle_menu()


## `UseItem`'s jumptable inside a battle. A ball reaches the throw the screen
## already draws, an ITEMMENU_PARTY row asks `UseItem_SelectMon` for a target
## first, and everything else is applied to whoever is out.
func use_selected_pack_item() -> Dictionary:
	if not _pack_selecting or _battle == null:
		return {"ok": false, "reason": &"pack_not_open"}
	var item: int = selected_pack_item()
	if _data != null and int(_data.item(item).get("pocket", 0)) == Gen2WorldPack.TYPE_BALL:
		_pack_selecting = false
		if not _is_wild_battle():
			return _block_ball_in_trainer_battle(item)
		var refused: Dictionary = _capture_guard()
		if not refused.is_empty():
			return refused
		return _throw_ball(item, &"pack")
	if _data != null \
		and int(_data.item(item).get("battle_menu", 0)) == Gen2WorldPack.ITEMMENU_PARTY:
		_pack_selecting = false
		_pack_item = item
		_open_switch_pick(&"item")
		return {"ok": true, "status": &"choosing_target", "item": item}
	return _use_pack_item(item, -1)


## `UseBallInTrainerBattle`, which is where `PokeBallEffect` jumps before it says
## anything at all: no ITEM USED line, the throw animation on
## `BattleAnim_ThrowPokeBall`'s own NO_ITEM branch, two boxes, and then
## `UseDisposableItem` spends the ball anyway. The turn goes with it, because
## `wItemEffectSucceeded` and `wBattlePlayerAction` are one byte and
## `_DoItemEffect` set it to BATTLEPLAYERACTION_USEITEM on the way in.
func _block_ball_in_trainer_battle(ball: int) -> Dictionary:
	_capture_messages.clear()
	_capture_messages.append(BALL_BLOCKED_TEXT)
	_capture_messages.append(BALL_DONT_BE_A_THIEF_TEXT)
	_begin_animation({
		"param": ANIM_PARAM_NO_ITEM,
		"index": ANIM_THROW_POKE_BALL,
		"enemy_turn": false,
	})
	item_used.emit(ball, -1)
	if not _battle.is_over():
		_capture_spent_turn = Gen2Battle.use_item(ball)
	return {"ok": true, "status": &"blocked", "ball": ball}


## `RestorePPEffect`'s question: which of the target's moves the Ether goes on.
## The Elixers fill every slot and never open this.
func _open_pack_move(item: int, target: int) -> void:
	var mon: Gen2BattleMon = _battle.party(Gen2Battle.PLAYER).at(target)
	_pack_move_slots = []
	if mon != null:
		for slot: int in mon.moves.size():
			if int(mon.moves[slot]) > 0:
				_pack_move_slots.append(slot)
	if _pack_move_slots.is_empty():
		_use_pack_item(item, target)
		return
	_pack_item = item
	_pack_move_target = target
	_pack_move_index = 0
	_pack_move_selecting = true
	_show_pack_move_selection()


func _show_pack_move_selection() -> void:
	show_message(String(_selected_pack_move().get("description", "")))
	_reopen_menu_layer()


func _selected_pack_move() -> Dictionary:
	if _data == null or _pack_move_slots.is_empty():
		return {}
	var mon: Gen2BattleMon = _battle.party(Gen2Battle.PLAYER).at(_pack_move_target)
	if mon == null:
		return {}
	var slot: int = int(_pack_move_slots[posmod(_pack_move_index, _pack_move_slots.size())])
	return _data.move(int(mon.moves[slot]))


func _close_pack_move() -> void:
	_pack_move_selecting = false
	_pack_move_slots = []
	_pack_move_target = -1


## The chosen row, applied and then paid for with the turn:
## `BATTLEPLAYERACTION_USEITEM` leaves the enemy's own move behind it.
func _use_pack_item(item: int, target: int, move_slot: int = -1) -> Dictionary:
	_pack_selecting = false
	_pack_item = 0
	_close_pack_move()
	var used: Dictionary = _battle.use_bag_item(item, target, move_slot)
	if not bool(used.get("ok", false)):
		## `.Field`'s battle twin: every refused effect is one line and the pack
		## again, so nothing is spent and the turn is still the player's.
		show_message("It won't have any effect.")
		_pack_selecting = true
		return used
	item_used.emit(item, target)
	show_message(_item_used_text(item))
	if _battle.is_over():
		## `PokeDollEffect`'s `wForcedSwitch`: the battle is already over, so no
		## turn is taken and the terminal text is what follows this line.
		return used
	_pending = _battle.take_actions(Gen2Battle.use_item(item), _enemy_action())
	return used


## Refuses the ball selector for this fight and says why. The world sets it when
## the run's rules have already spent this area's one encounter.
func set_capture_refusal(message: String) -> void:
	_capture_refusal = message


## `SetSeenMon`, `CheckCaughtMon` and `CheckReceivedDex`, off the world's live
## state rather than off the save's own snapshot: that snapshot is only as fresh
## as the last write to disk, so a species seen or caught since then reads as
## new. Called by the host that owns the world, before the entrance runs and
## therefore before anything registers this sight.
func set_dex_context(seen: bool, caught: bool, received: bool) -> void:
	_enemy_seen_before = seen
	_enemy_caught_before = caught
	_dex_received = received


## Supplies the wild battle with the supported balls currently owned by the
## overworld. The battle scene never reads or mutates world inventory itself.
func set_capture_balls(balls: Array, quantities: Dictionary = {}) -> void:
	_capture_balls.clear()
	_capture_quantities.clear()
	for raw_ball: Variant in balls:
		var ball: int = int(raw_ball)
		if ball > 0 and not _capture_balls.has(ball):
			_capture_balls.append(ball)
	for raw_ball: Variant in quantities:
		var quantity: int = int(quantities[raw_ball])
		if quantity > 0:
			_capture_quantities[int(raw_ball)] = quantity
	if _capture_ball_index >= _capture_balls.size():
		_capture_ball_index = 0


func available_capture_balls() -> Array[int]:
	return _capture_balls.duplicate()


## Returns the live enemy only for a wild overworld battle. The world host uses
## this object as the source for the existing catch calculation and save adapter.
func capture_target() -> Gen2BattleMon:
	return _battle.enemy if _is_wild_battle() and _battle != null else null


## The battler the ball is thrown past, which LEVEL_BALL reads a level off and
## LOVE_BALL a species and a gender (`wBattleMonLevel`, `wTempBattleMonSpecies`).
func capture_thrower() -> Gen2BattleMon:
	return _battle.player if _is_wild_battle() and _battle != null else null


## `wBattleType`, which `PokeBallEffect` reads once the catch has landed: a
## BATTLETYPE_CELEBI catch is the one that raises BATTLERESULT_CAUGHT_CELEBI.
func capture_battle_type() -> int:
	return _battle.battle_type if _battle != null else Gen2Battle.BATTLETYPE_NORMAL


## Opens the small wild-battle ball selector. The full bag UI remains a later
## world-service host; this boundary exposes only the capture action.
func begin_capture() -> Dictionary:
	var refused: Dictionary = _capture_guard()
	if not refused.is_empty():
		return refused
	if _capture_selecting:
		return _capture_failure(&"capture_input_busy")
	if _capture_balls.is_empty():
		show_message("You have no POKE BALLS!")
		return _capture_failure(&"no_capture_balls")
	_capture_selecting = true
	_capture_ball_index = 0
	_show_capture_selection()
	return {"ok": true, "ball": _selected_capture_ball()}


## Every refusal a throw is reached through, shared by the pack's own BALL row
## and by the small selector a fight with no bag behind it is handed. Empty means
## the ball may be thrown.
func _capture_guard() -> Dictionary:
	if not _is_wild_battle() or _battle == null or _battle.is_over():
		return _capture_failure(&"capture_not_available")
	## A Nuzlocke area that has already given up its encounter, said the way the
	## empty-bag line above is said: the ball is in the bag, the rules are what
	## refuse it.
	if not _capture_refusal.is_empty():
		show_message(_capture_refusal)
		return _capture_failure(&"capture_refused_by_rules")
	if _capture_waiting or not _capture_messages.is_empty() \
		or not _capture_result.is_empty():
		return _capture_failure(&"capture_input_busy")
	if not _pending.is_empty():
		return _capture_failure(&"battle_events_pending")
	return {}


func select_capture_ball(index: int) -> Dictionary:
	if not _capture_selecting or _capture_balls.is_empty():
		return _capture_failure(&"capture_selection_not_active")
	_capture_ball_index = posmod(index, _capture_balls.size())
	_show_capture_selection()
	return {"ok": true, "ball": _selected_capture_ball()}


func throw_capture_ball() -> Dictionary:
	if not _capture_selecting or _capture_balls.is_empty():
		return _capture_failure(&"capture_selection_not_active")
	_capture_selecting = false
	return _throw_ball(_selected_capture_ball(), &"capture")


## `PokeBallEffect` from the item onwards, which the pack's own BALL row and the
## selector both arrive at: `ItemUsedText`, and then the world resolves the
## throw. The turn is banked here because `_DoItemEffect` has already written
## BATTLEPLAYERACTION_USEITEM into the byte it shares with
## `wItemEffectSucceeded`; a refusal takes it back.
func _throw_ball(ball: int, origin: StringName = &"capture") -> Dictionary:
	if ball <= 0:
		return _capture_failure(&"capture_selection_not_active")
	_capture_origin = origin
	_capture_waiting = true
	_capture_spent_turn = Gen2Battle.use_item(ball)
	show_message(_item_used_text(ball))
	capture_requested.emit(ball)
	return {"ok": true, "status": &"waiting", "ball": ball}


## Delivers the world host's resolved throw. The battle screen only turns the
## structured result into messages and emits completion after those messages.
func complete_capture(result: Dictionary) -> Dictionary:
	if not _capture_waiting:
		return _capture_failure(&"capture_result_not_pending")
	_capture_waiting = false
	_capture_messages.clear()
	_capture_result = result.duplicate(true)
	_capture_terminal = false
	if not bool(result.get("ok", false)):
		## `Ball_BoxIsFullMessage` writes `$2` into the byte that is also
		## `wBattlePlayerAction`, so `.didnt_use_item` zeroes it and the pack is
		## reopened with the ball still in the bag and the turn still the
		## player's. Every other refusal this host can answer with is the same
		## shape, which is why the box takes them all back.
		_capture_result.clear()
		_capture_spent_turn = {}
		show_message(
			BALL_BOX_FULL_TEXT if StringName(result.get("reason", &"")) == &"storage_full"
			else "The capture could not be completed."
		)
		if _capture_origin == &"pack" and not _pack_rows.is_empty():
			_pack_selecting = true
		elif not _capture_balls.is_empty():
			_capture_selecting = true
		_reopen_menu_layer()
		return result
	var result_ball: int = int(result.get("ball", 0))
	if result_ball > 0 and result.has("quantity"):
		var next_quantity: int = int(result.get("quantity", 0))
		if next_quantity > 0:
			_capture_quantities[result_ball] = next_quantity
		else:
			_capture_quantities.erase(result_ball)
			_capture_balls.erase(result_ball)
			_capture_ball_index = mini(_capture_ball_index, maxi(_capture_balls.size() - 1, 0))

	var wobbles: int = clampi(int(result.get("wobbles", 0)), 0, 3)
	var caught: bool = bool(result.get("caught", false))
	if caught:
		_capture_messages.append("Gotcha! %s was caught!" % _name_of(_enemy))
		## `.catch_bug_contest_mon` runs after `Text_GotchaMonWasCaught`, and
		## `BugContest_SetCaughtContestMon`'s `.firstcatch` says a second line.
		## A catch that has one to replace says `DisplayAlreadyCaughtText`
		## instead, which comes with the switch question rather than here.
		if bool(result.get("contest", false)) \
			and not bool(result.get("replace_offer", false)):
			_capture_messages.append("Caught %s!" % _name_of(_enemy))
		_capture_terminal = true
		_capture_caught_event = _caught_event(result)
	else:
		_capture_messages.append(BREAK_FREE_TEXT[wobbles])
	_begin_capture_animation(result_ball, wobbles, caught)
	return result


## `PokeBallEffect`'s own `PlayBattleAnim` on `ANIM_THROW_POKE_BALL`: the throw,
## the poof, the opponent going in, the wobbles and the click or the break free,
## one script rather than five. The catch is already resolved when this runs, the
## way the source resolves it in front of the animation and hands the drawing
## `wThrownBallWobbleCount` rather than a roll, so the queue is
## `GetPokeBallWobble`'s answers in order. The opponent leaving and coming back
## are `BATTLE_BG_EFFECT_RETURN_MON` and `..._ENTER_MON` inside the script, which
## is why nothing here touches the picture.
func _begin_capture_animation(ball: int, wobbles: int, caught: bool) -> void:
	if ball <= 0:
		return
	var answers: Array[int] = []
	for _wobble: int in wobbles:
		answers.append(Gen2BattleAnimScript.WOBBLE_NEXT)
	answers.append(
		Gen2BattleAnimScript.WOBBLE_CAUGHT if caught \
			else Gen2BattleAnimScript.WOBBLE_ESCAPED
	)
	_begin_animation({
		## `.not_kurt_ball`: every ball Kurt makes is drawn as a POKE BALL,
		## which is what the `cp POKE_BALL + 1` in front of it decides.
		"param": mini(ball, Gen2WorldPartyHost.ITEM_POKE_BALL),
		"index": ANIM_THROW_POKE_BALL,
		## `xor a / ldh [hBattleTurn]`: the throw is the player's, so the
		## script's `BG_EFFECT_TARGET` is the opponent.
		"enemy_turn": false,
		"wobbles": answers,
	})


## `ItemSubmenu` over the list [param over] names, opened on USE the way
## `.UsableMenuHeader`'s `db 1 ; default option` does.
func _open_pack_action(over: StringName) -> void:
	_pack_action_stage = over
	_pack_action_index = 0
	_reopen_menu_layer()


func _show_capture_selection() -> void:
	show_message(Gen2WorldPack.row_description(_data, _selected_capture_ball()))
	_reopen_menu_layer()


func _show_next_capture_message() -> void:
	if _capture_messages.is_empty():
		return
	show_message(_capture_messages.pop_front())
	## `Text_GotchaMonWasCaught` is always the last line of a caught throw, so
	## the queue running dry on a terminal capture is that box. Published here
	## rather than in [method complete_capture] because a subscriber asking for a
	## line of its own owes the same ordering every event gets: after the line
	## being shown when it asked.
	if _capture_terminal and _capture_messages.is_empty() \
		and not _capture_caught_event.is_empty():
		var event: Dictionary = _capture_caught_event
		_capture_caught_event = {}
		Gen2ModHost.publish(Gen2ModHost.CHANNEL_BATTLE, event)


## What a capture publishes: the Pokemon kept and the circumstances of the throw.
## The screen is the one place that holds all three, the resolved result, the
## wild itself and the request the world made.
func _caught_event(result: Dictionary) -> Dictionary:
	var values: Variant = _world_battle_request.get("values", _world_battle_request)
	var request: Dictionary = values as Dictionary if values is Dictionary else {}
	var wild: Gen2BattleMon = _battle.enemy if _battle != null else null
	var dvs: int = wild.dvs if wild != null else 0
	var destination: Dictionary = result.get("destination", {})
	return {
		"type": Gen2Battle.CAUGHT,
		"species": wild.species if wild != null else int(result.get("species", 0)),
		"level": wild.level if wild != null else 0,
		"dvs": dvs,
		"shiny": Gen2Stats.is_shiny(dvs),
		"ball": int(result.get("ball", 0)),
		"method": StringName(request.get("method", &"")),
		"map_group": int(request.get("map_group", -1)),
		"map_number": int(request.get("map_number", -1)),
		"battle_type": _battle.battle_type if _battle != null else 0,
		"destination": StringName(destination.get("destination", &"party")),
		"tutorial": _world_battle_tutorial,
		"contest": bool(result.get("contest", false)),
	}


## The next line a mod asked the battle to print, shown in its own box. Drained
## one at a time so a mod that asks from the handler of the line it is reading is
## still spent in order.
func _show_next_mod_message() -> bool:
	var host: Gen2ModHost = Gen2ModHost.instance()
	if host == null:
		return false
	var request: Dictionary = host.take_battle_message()
	if request.is_empty():
		return false
	show_message(String(request["text"]))
	return true


func _selected_capture_ball() -> int:
	return _capture_balls[_capture_ball_index] if not _capture_balls.is_empty() else 0


func _capture_quantity(ball: int) -> int:
	return int(_capture_quantities.get(ball, 0))


func _item_name(item: int) -> String:
	if _data == null:
		return "BALL"
	var item_name: String = _data.item_name(item)
	return item_name if not item_name.is_empty() else "BALL %d" % item


## `ItemUsedText`, the one line `PokeBallEffect` and every other battle item
## print before their effect runs. A ball says it too: the throw, the rocking and
## the click are the animation behind this line, and the next thing said is
## already the outcome.
func _item_used_text(item: int) -> String:
	return "%s used the\n%s." % [_player_label(), _item_name(item)]


func _is_wild_battle() -> bool:
	if not _world_battle_active:
		return false
	var values: Variant = _world_battle_request.get("values", _world_battle_request)
	return values is Dictionary and StringName((values as Dictionary).get("kind", &"")) == &"wild"


## `wBattleType` being BATTLETYPE_CONTEST, which is what makes the menu the
## contest's own and the ball a Park Ball.
func _is_bug_contest_battle() -> bool:
	return _battle != null and _battle.battle_type == Gen2Battle.BATTLETYPE_CONTEST


## The screen the fight draws on, for an overlay the world opens over it.
func hardware_screen() -> Gen2Screen:
	return _screen


func _capture_failure(reason: StringName) -> Dictionary:
	return {"ok": false, "reason": reason}


## `AskGiveNicknameText`, `YesNoBox` and `NamingScreen`, which `PokeBallEffect`
## runs for a caught Pokemon whether it went to the party or to the box, and
## which `.catch_bug_contest_mon` and `.FinishTutorial` both jump past.
##
## True while the prompt stands, so the pump that called this waits for it.
func _open_capture_nickname() -> bool:
	if _capture_nickname_host != null:
		return true
	if _capture_nickname_asked or _data == null or _screen == null:
		return false
	## `.FinishTutorial` and `.catch_bug_contest_mon` both return in front of
	## `AskGiveNicknameText`: neither catch is kept.
	if not bool(_capture_result.get("caught", false)) \
		or bool(_capture_result.get("contest", false)) or _world_battle_tutorial:
		return false
	var species_name: String = _name_of(_enemy)
	if species_name.is_empty():
		return false
	## `PokeBallEffect` reaches `AskGiveNicknameText` only once
	## `Text_GotchaMonWasCaught` has finished printing, so the prompt waits for
	## the box rather than opening over it. True, because the pump is meant to
	## wait here: without it a Nuzlocke, whose question is skipped, put its
	## keyboard on screen halfway through "Gotcha! X was caught!".
	if _box != null and (_box.is_revealing() or _box.has_pages_left()):
		return true
	_capture_nickname_asked = true
	_capture_nickname = species_name
	var host := Gen2NicknamePromptScreen.new()
	## `.SendToPC` prints `BallSentToPCText` behind the naming and the party
	## branch prints nothing, which is the one difference between the two.
	var destination: Dictionary = _capture_result.get("destination", {})
	host.set_context(
		_data, species_name,
		Gen2WorldPartyHost.SENT_TO_BOX_FORMAT \
			if StringName(destination.get("destination", &"")) == &"box" else "",
		Gen2WorldPartyHost.capture_nickname_question(species_name),
		## A Nuzlocke nicknames every catch, so the question is not asked.
		_rules().is_nuzlocke()
	)
	## `.Pokemon`'s icon and sign, off the DVs the battle already rolled.
	host.set_species(
		_enemy, _battle.enemy.dvs if _battle != null else -1
	)
	host.named.connect(_on_capture_named)
	host.closed.connect(_on_capture_nickname_closed)
	host.z_index = 30
	_capture_nickname_host = host
	_screen.display(host)
	if _capture_nickname_host == null:
		return false
	## The battle's own box is what the prompt stands over, and it is left where
	## `Text_GotchaMonWasCaught` put it: `ClearSprites` takes the sprites down,
	## not the box.
	return true


## `NewDexDataText`, then the page. True while either is still owed, so the pump
## that called this waits. The world owns the dex and draws the page; this only
## says when.
func _open_new_dex_entry() -> bool:
	if _capture_dex_stage == &"done" or _world_battle_tutorial \
		or bool(_capture_result.get("contest", false)) \
		or not bool(_capture_result.get("caught", false)) \
		or _enemy_caught_before or not _dex_received:
		return false
	match _capture_dex_stage:
		&"":
			_capture_dex_stage = &"text"
			show_message(NEW_DEX_DATA_TEXT % _name_of(_enemy))
			return true
		&"text":
			## `call ClearSprites` between the line and the page, which is the
			## same call the catch's own box is followed by.
			_clear_kept_sprites()
			_capture_dex_stage = &"page"
			dex_entry_requested.emit(_enemy)
			return true
	return true


## The page closing, which is `ExitAllMenus` behind `NewPokedexEntry`.
func complete_dex_entry() -> void:
	if _capture_dex_stage != &"page":
		return
	_capture_dex_stage = &"done"
	_continue_after_messages()


func _on_capture_named(nickname: String) -> void:
	_capture_nickname = nickname


func _on_capture_nickname_closed() -> void:
	_close_capture_nickname()
	_continue_after_messages()


func _close_capture_nickname() -> void:
	var host: Gen2NicknamePromptScreen = _capture_nickname_host
	_capture_nickname_host = null
	if host != null:
		Gen2Screen.drop(host)


## `PokeBallEffect` gives no experience of its own: this is what a registered
## policy adds, and with none registered it answers false and the capture flow
## above is the one the cartridge has.
##
## The catching tutorial and a Bug Contest catch are excluded: neither is an
## ordinary capture, and the contest's is a score rather than a Pokemon kept.
func _spend_capture_experience() -> bool:
	if _capture_experience_spent or _battle == null or _world_battle_tutorial \
		or bool(_capture_result.get("contest", false)) \
		or not Gen2ModHost.awards_catch_experience():
		return false
	_capture_experience_spent = true
	_pending.append_array(_battle.award_capture_experience())
	if _pending.is_empty():
		return false
	_show_next_event()
	return true


func _clear_capture_action() -> void:
	_capture_experience_spent = false
	_pack_action_stage = &""
	_capture_dex_stage = &""
	_capture_spent_turn = {}
	_capture_selecting = false
	_capture_waiting = false
	_capture_messages.clear()
	_capture_caught_event = {}
	_capture_terminal = false
	_contest_already_caught_said = false
	_capture_result.clear()
	_close_capture_nickname()
	_capture_nickname = ""
	_capture_nickname_asked = false


func _reset_capture_state() -> void:
	_capture_spent_turn = {}
	_capture_balls.clear()
	_capture_quantities.clear()
	_capture_ball_index = 0
	_capture_refusal = ""
	_clear_capture_action()


## Reveals the rest of the message at once, so a photograph of the screen does
## not depend on how long the capture took to arrive.
func finish() -> void:
	if _box != null:
		_box.finish()


func next_enemy() -> void:
	show_matchup(_enemy + 1, _player, _enemy_level, _player_level)


func next_player() -> void:
	show_matchup(_enemy, _player + 1, _enemy_level, _player_level)


## Takes a quarter of the enemy's health off, which is the fastest way to see
## that a bar and its numbers agree. It goes through the Pokémon rather than
## through the display, so the battle and the screen do not drift apart.
func hurt_enemy() -> void:
	_hurt(_battle.enemy if _battle != null else null)


func hurt_player() -> void:
	_hurt(_battle.player if _battle != null else null)


func _hurt(mon: Gen2BattleMon) -> void:
	if mon == null:
		return
	@warning_ignore("integer_division")
	mon.take_damage(maxi(mon.max_hp() / 4, 1))
	_read_hp()


## Development turn driver: random player move and the opponent's usual policy.
func take_turn() -> void:
	if _battle == null or _battle.is_over() or not _pending.is_empty():
		return
	## An unanswered move offer stops everything, the way an unanswered
	## replacement does: KEY_A reaches here without going through
	## [method advance].
	if _battle.awaiting_move_learn():
		return
	_pending = _battle.take_actions(
		Gen2Battle.use_move(_random_slot(Gen2Battle.PLAYER)), _enemy_action()
	)
	_show_next_event()


## The same turn with both slots named rather than rolled, so a test or a
## screenshot driver can photograph one chosen animation instead of whichever
## move a random slot picked. Development only, like [method hurt_enemy].
func take_turn_with(player_slot: int, enemy_slot: int) -> void:
	if _battle == null or _battle.is_over() or not _pending.is_empty():
		return
	_pending = _battle.take_actions(
		Gen2Battle.use_move(player_slot), Gen2Battle.use_move(enemy_slot)
	)
	_show_next_event()


func _random_slot(side: int) -> int:
	var mon: Gen2BattleMon = _battle.mon(side)
	var usable: Array = []
	for slot: int in mon.moves.size():
		if mon.can_use(slot):
			usable.append(slot)
	return usable[_rng.randi_range(0, usable.size() - 1)] if not usable.is_empty() else 0


## The enemy's own move choice: [Gen2BattleAI] against a real trainer's AI
## flags, or [method _random_slot] for [method show_matchup]'s invented
## pairing, which is not one of the cartridge's own trainers and so has no AI
## flags to read.
func _enemy_slot() -> int:
	if _enemy_trainer_class == 0:
		return _random_slot(Gen2Battle.ENEMY)
	var policy: Dictionary = Gen2BattleAI.trainer_policy(
		_data, _enemy_trainer_class, _battle.in_battle_tower
	)
	var weights: int = _rules().ai_move_weights(int(policy["move_weights"]))
	return Gen2BattleAI.choose_slot(
		_battle.mon(Gen2Battle.ENEMY), _battle.mon(Gen2Battle.PLAYER), _data, weights, _rng,
		_battle.mon(Gen2Battle.ENEMY).turns_taken, _battle.mon(Gen2Battle.PLAYER).turns_taken,
		_battle.weather,
		_battle.screens[Gen2Battle.ENEMY], _battle.screens[Gen2Battle.PLAYER],
		Gen2AISwitch.has_bench(_battle), Gen2AISwitch.matchup_score(_battle),
		Gen2AISwitch.has_bench(_battle, Gen2Battle.PLAYER), _battle.player_used_moves,
		_party_status_mask(Gen2Battle.ENEMY), _battle.is_link_battle
	)


## `AI_Smart_HealBell`'s walk of `wOTPartyMon1HP`: every living party member's
## status byte ored together, the one that is out included.
func _party_status_mask(side: int) -> int:
	var party: Gen2Party = _battle.party(side)
	var mask: int = Gen2Status.NONE
	for index: int in party.size():
		var member: Gen2BattleMon = party.at(index)
		if member != null and not member.is_fainted():
			mask |= member.status
	return mask


## What the enemy does with the turn, which is a move unless its trainer reaches
## into the bag first. `show_matchup`'s invented pairing is not one of the
## cartridge's trainers, so it has no class flags and never uses an item.
func _enemy_action() -> Dictionary:
	var slot: int = _enemy_slot()
	if _enemy_trainer_class == 0:
		return Gen2Battle.use_move(slot)
	var policy: Dictionary = Gen2BattleAI.trainer_policy(
		_data, _enemy_trainer_class, _battle.in_battle_tower
	)
	var flags: int = _rules().ai_item_switch(int(policy["item_switch"]))
	return Gen2BattleAI.choose_action(_battle, flags, slot, _rng)


## The run's rules, which the battle carries once it exists and the installed set
## answers for before that: a screen builds its menus before its battle.
func _rules() -> Gen2Rules:
	if _battle != null and _battle.rules != null:
		return _battle.rules
	return _injected_rules if _injected_rules != null else Gen2Rules.active()


## Tries to run, which is `BattleMenu_Run` and settles before the turn does.
##
## Offered in a trainer battle too, because the cartridge offers it there and
## answers with its own refusal rather than greying the entry out.
func run_from_battle() -> void:
	if _battle == null or _battle.is_over() or not _pending.is_empty():
		return
	if _battle.awaiting_move_learn():
		return
	_pending = _battle.take_actions(Gen2Battle.run_away(), _enemy_action())
	_show_next_event()


## Swaps the player's Pokémon for the next one that is standing, as a turn.
##
## The enemy attacks while it happens, because a switch is not free: this is the
## whole point of the ordering rule, and it is worth being able to look at.
func switch_player() -> void:
	if _battle == null or _battle.is_over() or not _pending.is_empty():
		return
	if _battle.awaiting_move_learn():
		return
	var next: int = _next_healthy(Gen2Battle.PLAYER)
	if next < 0:
		return
	_pending = _battle.take_actions(Gen2Battle.switch_to(next), _enemy_action())
	_show_next_event()


## The development shortcut's own pick, with no menu in front of it. Every switch
## the cartridge makes is either chosen from the party list or
## [method Gen2Battle.replacement_target]'s.
func _next_healthy(side: int) -> int:
	var party: Gen2Party = _battle.party(side)
	for index: int in party.size():
		if party.can_send_out(index):
			return index
	return -1


## Opens LearnMove's full-slot branch, or keeps it open. Answered through
## [method _handle_button], the same way capture ball selection is.
##
## Only the player side is ever queued
## ([method Gen2Battle._offer_moves_learned_at]), so there is one stage rather
## than one per side.
func _open_move_learn() -> bool:
	if _battle == null:
		return false
	if _forget_stage == &"":
		if not _battle.must_learn_move(Gen2Battle.PLAYER):
			return false
		var offer: Dictionary = _battle.pending_learn(Gen2Battle.PLAYER)
		var learner: Gen2BattleMon = _battle.party(Gen2Battle.PLAYER).at(int(offer["index"]))
		if learner == null:
			return false
		_forget_moves = Gen2MoveForget.options(_data, learner.moves)
		if _forget_moves.is_empty():
			return false
		_forget_cursor = 0
		_forget_confirm_cursor = 0
		_show_forget_stage(&"ask")
	return true


func _show_forget_stage(stage: StringName) -> void:
	_forget_stage = stage
	_forget_confirm_cursor = 0
	if stage == &"list":
		_show_forget_list()
	else:
		_show_forget_confirm()


## The two yes/no boxes, which open on YES the way YesNoBox does. The question is
## the box's own and the answer is `PlaceYesNoBox`', drawn over the field once the
## question has been read.
func _show_forget_confirm() -> void:
	show_message(_forget_prompt_text())
	_reopen_menu_layer()


## `ForgetMove.loop`: `MoveAskForgetText` in the box and the list in its own
## frame over the field, both drawn again on every pass round the loop.
func _show_forget_list() -> void:
	show_message(Gen2MoveForget.which_text())
	_reopen_menu_layer()


## The offer's own name fields, which [method Gen2Battle.pending_learn] carries
## so neither is re-derived from a party that may already have changed.
func _forget_move_name() -> String:
	var offer: Dictionary = _battle.pending_learn(Gen2Battle.PLAYER)
	return String(_data.move(int(offer.get("move", 0))).get("name", ""))


func _forget_learner_name() -> String:
	var offer: Dictionary = _battle.pending_learn(Gen2Battle.PLAYER)
	return _name_of(int(offer.get("species", 0)))


## The yes/no boxes and the list, in LearnMove's own order. An HM row prints
## MoveCantForgetHMText and leaves the list open, since .hmmove is `jr .loop`.
func _answer_forget(button: int) -> void:
	## AskForgetMoveText is three paragraphs, so the box still has pages to turn.
	## A confirm reveals and pages first, the way [method advance] does, rather
	## than answering a question the player has not finished reading.
	if button == PokeButton.A and _box != null and _box.advance():
		return
	match _forget_stage:
		&"ask", &"stop":
			if PokeButton.is_direction(button):
				_forget_confirm_cursor = 1 - _forget_confirm_cursor
				_show_forget_confirm()
			elif button == PokeButton.A:
				_confirm_forget_stage()
		&"list":
			match button:
				PokeButton.UP:
					_forget_cursor = wrapi(_forget_cursor - 1, 0, _forget_moves.size())
					_show_forget_list()
				PokeButton.DOWN:
					_forget_cursor = wrapi(_forget_cursor + 1, 0, _forget_moves.size())
					_show_forget_list()
				PokeButton.A:
					_confirm_forget_slot()
				PokeButton.B:
					_show_forget_stage(&"stop")


func _forget_prompt_text() -> String:
	if _forget_stage == &"stop":
		return Gen2MoveForget.stop_text(_forget_move_name())
	return Gen2MoveForget.ask_text(_forget_learner_name(), _forget_move_name())


func _confirm_forget_stage() -> void:
	var yes: bool = _forget_confirm_cursor == 0
	if _forget_stage == &"ask":
		# No is YesNoBox's carry, which is LearnMove.cancel.
		_show_forget_stage(&"list" if yes else &"stop")
		return
	if not yes:
		# `jp .loop` reaches ForgetMove's ask again.
		_show_forget_stage(&"ask")
		return
	_forget_stage = &""
	_pending = _battle.decline_move(Gen2Battle.PLAYER)
	_show_next_event()


func _confirm_forget_slot() -> void:
	if _forget_cursor < 0 or _forget_cursor >= _forget_moves.size():
		return
	var entry: Dictionary = _forget_moves[_forget_cursor]
	if not bool(entry.get("forgettable", false)):
		show_message("%s %s" % [
			Gen2MoveForget.cant_forget_hm_text(), Gen2MoveForget.which_text(),
		])
		return
	var events: Array = _battle.learn_move(Gen2Battle.PLAYER, int(entry.get("slot", -1)))
	if events.is_empty():
		return
	_forget_stage = &""
	_pending = events
	_show_next_event()


## What a button press does. Finishes the current message if it is still
## revealing, then moves on to the next event, sends out whoever is owed, and
## starts a turn when there is nothing left to say.
func advance() -> void:
	if _box == null:
		return
	## The exp bar stopped at a level boundary is under `.LoopLevels`' own
	## `StdBattleTextbox`, which blocks on a button: this press is that button,
	## and it lets the loop run on into the next level's fill rather than
	## advancing the battle.
	if _exp_bar != null and _exp_bar.paused():
		if _box.advance():
			return
		_exp_bar.resume()
		## The loop reaches `.PlayExpBarSound` again for the segment this press
		## releases, the same as the first one.
		_play_sfx(SFX_EXP_BAR, true)
		return
	## `BattleIntroSlidingPics`, `SlideBattlePicOut` and every other run of frames
	## this screen counts is delays with nothing reading a button.
	if frames_running():
		return
	if _box.advance():
		return
	_message_awaits_press = false
	## The battle menu is answered with A, which is what this call is: the source
	## reads one joypad for the box and for the menu over it.
	if _menu_stage != &"":
		_answer_menu(PokeButton.A)
		return
	_continue_after_messages()


## What the source runs on to once nothing is left to say. `DoTurn` falls
## straight out of the last command into `HandleBetweenTurnEffects` and then
## into `BattleMenu`, and nothing between them reads a button, so this is
## reached both by the press that dismissed the last box and by
## [method _show_next_event] finding no line left to print.
func _continue_after_messages() -> void:
	if _messages_held():
		return
	## Nothing is left to print, so the line the box stood beside is gone even
	## though no event was popped to take it away.
	_clear_level_up_box()
	if _capture_selecting or _capture_waiting:
		return
	if _a_list_owns_the_joypad():
		return
	if not _capture_messages.is_empty():
		_show_next_capture_message()
		return
	## `PokeBallEffect`'s own `call ClearSprites`, which is the first thing after
	## `Text_GotchaMonWasCaught` has been pressed past: the ball `anim_keepsprites`
	## left at rest stays under that box and goes with it.
	_clear_kept_sprites()
	## After the line a mod asked from and before the nickname prompt, which is
	## where a line about the catch reads.
	if _show_next_mod_message():
		return
	if _capture_terminal:
		_continue_capture()
		return
	if _continue_capture_turn():
		return
	if not _pending.is_empty():
		_show_next_event()
		return
	## LearnMove runs inside the experience handler, before the loop asks for a
	## replacement, so the offer is answered first.
	if _open_move_learn():
		return
	if _answer_baton_pass():
		return
	if _answer_switch_offer():
		return
	if _replace_the_fallen():
		return
	if _battle != null and _battle.is_over():
		_finish_battle()
		return
	_open_battle_menu()


## A list already up owns the joypad: the battle menu, the pack and its two
## sub-lists, and the forget offer are each answered by a press rather than run
## past by the pump.
func _a_list_owns_the_joypad() -> bool:
	return _menu_stage != &"" or _pack_selecting or _pack_move_selecting \
		or _pack_action_stage != &"" or _forget_stage != &""


## Whether a box, a bar or a frame nobody has spent yet still owns the screen.
## The same waits [method _resume_after_frames] respects.
func _messages_held() -> bool:
	if _box == null:
		return true
	## `PokeBallEffect` does not return until the naming is over, so nothing
	## behind it runs while the prompt is up.
	if _capture_nickname_host != null:
		return true
	if _intro != null or bars_animating() or fainting() or animation_running():
		return true
	## `applydamage` animates the bar and sinks the picture before `criticaltext`
	## prints, so a line produced while either was running was held rather than
	## raced. Released here, where every wait it can be held behind ends: a faint
	## with no bar beside it is one, and the bar pump never sees that frame.
	if not _held_message.is_empty():
		var held: String = _held_message
		_held_message = ""
		show_message(held)
		return true
	if _message_awaits_press:
		return true
	## `BattleStartMessage` and `DoBattle`'s opening: each step is either frames
	## or a line, so the pump and the press both arrive back here for the next.
	return _advance_entrance()


## Everything `PokeBallEffect` does between `Text_GotchaMonWasCaught` and handing
## the catch back to the world.
func _continue_capture() -> void:
	## `BugContest_SetCaughtContestMon` asks before replacing the Pokemon
	## already caught, over the same `PlaceYesNoBox` a switch offer uses.
	if bool(_capture_result.get("replace_offer", false)) and _switch_stage == &"":
		## `DisplayAlreadyCaughtText` before `DisplayCaughtContestMonStats`
		## and the box: the line about the one already held is prompted past
		## first, and the question is asked over the comparison.
		if not _contest_already_caught_said:
			_contest_already_caught_said = true
			show_message(CONTEST_ALREADY_CAUGHT_TEXT % _contest_stock_name())
			return
		_open_yes_no(&"contest_replace", CONTEST_REPLACE_TEXT)
		return
	## `NewDexDataText` and `NewPokedexEntry`, which stand between
	## `Text_GotchaMonWasCaught` and everything else a catch does. Only for a
	## species the dex had not caught yet, and only once the player has the
	## dex at all: `CheckCaughtMon` and `CheckReceivedDex` are both read
	## before the throw, because the throw is what registers the catch.
	if _open_new_dex_entry():
		return
	## A registered policy's award and every level up, move offer and
	## evolution flag behind it, spent between `Text_GotchaMonWasCaught` and
	## `AskGiveNicknameText` so nothing is filed with a level up still owed.
	if _spend_capture_experience():
		return
	if _capture_experience_spent:
		if not _pending.is_empty():
			_show_next_event()
			return
		if _open_move_learn():
			return
	## `.skip_pokedex` reaches `.catch_bug_contest_mon` before either
	## `AskGiveNicknameText`, so a contest catch is never named.
	if _open_capture_nickname():
		return
	var capture: Dictionary = _capture_result.duplicate(true)
	if not _capture_nickname.is_empty():
		capture["nickname"] = _capture_nickname
	if _capture_experience_spent:
		## The experience landed on the party the battle owns, so the save
		## the world holds needs it before that world files the catch.
		sync_live_party()
		capture["experience_awarded"] = true
	_clear_capture_action()
	_finish_world_capture(capture)


## The turn a throw was paid with. `.UseItem` returns with no carry on a ball
## that did not land, so `BattleMenu` falls back into `DoBattle` and the enemy
## takes it; only a catch escapes, through `.run`. Answers whether the turn it
## started owns the screen.
func _continue_capture_turn() -> bool:
	var thrown: bool = not _capture_result.is_empty()
	if not thrown and _capture_spent_turn.is_empty():
		return false
	## The blocked throw in a trainer battle, whose two boxes are behind it.
	var spent: Dictionary = _capture_spent_turn
	_capture_spent_turn = {}
	if thrown:
		_clear_capture_action()
	if not spent.is_empty() and _battle != null and not _battle.is_over():
		_pending = _battle.take_actions(spent, _enemy_action())
		if not _pending.is_empty():
			_show_next_event()
			return true
	return thrown


## `.HandleEndOfBattle`, outside the battle loop.
func _finish_battle() -> void:
	if _world_battle_active and not _battle.has_fled():
		# A run shows neither a win nor a loss text and blacks nobody out:
		# `wBattleResult` is DRAW and the party is still standing.
		if _show_world_battle_result_picture():
			return
		if _show_world_battle_terminal_text():
			return
		## `.give_money` is the next thing `BattleWon` does once
		## `PrintWinLossText` has been answered.
		if _show_prize_money_text():
			return
		## `LostBattle`'s `.not_canlose` is the grayscale and a `ret`: the
		## battle prints nothing about blacking out, because `_WhitedOutText`
		## belongs to `Script_Whiteout` on the overworld. What is checked
		## here is only that the party the whiteout will heal can be read.
		if _battle.winner() != Gen2Battle.PLAYER and not _world_battle_recovery_shown:
			if not _prepare_world_battle_recovery():
				return
			_world_battle_recovery_shown = true
	## `CheckPayDay` is `.HandleEndOfBattle`'s, outside the battle loop and
	## behind whichever of the two win or loss texts was printed. A wild
	## battle reaches it with no `_world_battle_active` in front of it.
	if _show_pay_day_text():
		return
	if _save_battle_result() and _world_battle_active:
		_finish_world_battle()


## The fought party over the live save, with nothing written to disk.
##
## A ball is thrown mid-battle and the catch is its own transaction, which
## builds its candidate from the live save; without this the party that reaches
## the candidate is the pre-battle one, so the HP and PP spent weakening the
## wild are given back the moment it is caught.
func sync_live_party() -> bool:
	if _source_save == null or _battle == null or _data == null:
		return false
	if _battle.in_battle_tower:
		return true
	var fought: Gen2SaveData = Gen2SaveBattleAdapter.from_battle_party(
		_data.id, _data.sha1, _source_save.slot, _battle.party(Gen2Battle.PLAYER),
		"", _source_save
	)
	if fought == null:
		return false
	_source_save.party = fought.party
	return true


## Writes back only after every event from a finished battle has been shown.
## Saving during a resolved turn would capture battle state the player has not
## seen yet, while the persistent save model intentionally has no such state.
func _save_battle_result() -> bool:
	if _save_slot < 0 or _save_written or _battle == null:
		return true
	var save: Gen2SaveData = Gen2SaveBattleAdapter.from_world_battle(_data, _battle, _source_save)
	# The world host credits its live state from the completion result below;
	# mirror the same award into the snapshot being written now so neither the
	# prize nor the Pay Day money is lost between the battle save and that
	# callback.
	if save != null and save.world != null:
		Gen2WorldBattleAdapter.credit_earnings(
			save.world.world_state, _earnings()["money"]
		)
	var result: Dictionary = Gen2SaveStore.save(save, _data)
	if not result["ok"]:
		push_error("Could not save battle result: %s" % result["message"])
		if _world_battle_active:
			_emit_world_battle_failure(&"battle_save_failed", {
				"message": result.get("message", ""),
			})
		return false
	# Publish the saved candidate to the live world before its next battle.
	Gen2WorldTransaction.copy_into(_source_save, save)
	_save_written = true
	return true


func _finish_world_battle() -> void:
	if _world_battle_completion_sent or _battle == null or not _battle.is_over():
		return
	var winner: Variant = _battle.winner()
	var outcome: StringName = (
		Gen2WorldBattleAdapter.OUTCOME_RAN
		if _battle.has_fled()
		else (
			Gen2WorldBattleAdapter.OUTCOME_WON
			if winner == Gen2Battle.PLAYER
			else Gen2WorldBattleAdapter.OUTCOME_LOST
		)
	)
	var result: Dictionary = {
		"ok": true,
		"outcome": outcome,
		"winner": winner,
		"request": _world_battle_request.duplicate(true),
		"save_written": _save_written,
	}
	if outcome == Gen2WorldBattleAdapter.OUTCOME_WON:
		## `.give_money` and `CheckPayDay` as one credit per account, so the
		## world applies exactly what the save already carries.
		var earned: Dictionary = _earnings()["money"]
		if not earned.is_empty():
			result["money_awarded"] = earned.duplicate()
		## `ExitBattle`'s `and $f / ret nz`: `wEvolvableFlags` is only ever read
		## after a battle that was WON, so a fight that was lost or run from
		## carries nothing for the overworld's own `EvolveAfterBattle` to walk.
		result["evolvable"] = _battle.evolvable_indices()
	if outcome == Gen2WorldBattleAdapter.OUTCOME_LOST:
		result["recovery"] = _world_battle_recovery.duplicate(true)
	result["enemy"] = _enemy_battler_record()
	_world_battle_completion_sent = true
	battle_finished.emit(result)


## What `BattleEnd_HandleRoamMons` reads out of `wEnemyMon` on the way out of a
## wild battle: the species it was, the HP it is leaving on and the DVs it was
## built with, plus the level `wEnemyMonLevel` keeps past the fight. Empty when
## there is no enemy to read, which is every path that ends before one exists.
func _enemy_battler_record() -> Dictionary:
	if _battle == null:
		return {}
	var enemy: Gen2BattleMon = _battle.party(Gen2Battle.ENEMY).active_mon()
	if enemy == null:
		return {}
	return {"species": enemy.species, "hp": enemy.hp, "dvs": enemy.dvs, "level": enemy.level}


func _finish_world_capture(capture: Dictionary) -> void:
	if _world_battle_completion_sent:
		return
	_world_battle_completion_sent = true
	battle_finished.emit({
		"ok": true,
		"outcome": Gen2WorldBattleAdapter.OUTCOME_CAUGHT,
		"request": _world_battle_request.duplicate(true),
		"capture": capture.duplicate(true),
		"enemy": _enemy_battler_record(),
	})


## [method Gen2WorldBattleAdapter.earnings] for this battle, worked out once so
## the snapshot [method _save_battle_result] writes, the line that announces the
## prize and the completion result the world credits its live state from cannot
## disagree about what the fight was worth.
func _earnings() -> Dictionary:
	if _earnings_computed.is_empty():
		_earnings_computed = Gen2WorldBattleAdapter.earnings(
			_battle,
			_source_save.world.world_state
			if _source_save != null and _source_save.world != null else null,
			_battle != null and not _battle.has_fled() \
				and _battle.winner() == Gen2Battle.PLAYER
		)
	return _earnings_computed


## `GotMoneyForWinningText` and the three `.SentToMomTexts`, printed by
## `.give_money` right behind `PrintWinLossText`.
func _show_prize_money_text() -> bool:
	if _prize_text_shown:
		return false
	_prize_text_shown = true
	var earned: Dictionary = _earnings()
	if int(earned["prize_shown"]) <= 0:
		return false
	var got: String = "%s got ¥%d\nfor winning!" % [
		_player_label(), int(earned["prize_shown"]),
	]
	match StringName(earned["prize_line"]):
		Gen2Battle.PRIZE_SENT_SOME_TO_MOM:
			show_message("%s\nSent some to MOM!" % got)
		Gen2Battle.PRIZE_SENT_HALF_TO_MOM:
			show_message("Sent half to MOM!")
		Gen2Battle.PRIZE_SENT_ALL_TO_MOM:
			show_message("Sent all to MOM!")
		_:
			show_message(got)
	return true


## `BattleText_PlayerPickedUpPayDayMoney`, which `CheckPayDay` prints once the
## coins have been added.
func _show_pay_day_text() -> bool:
	if _pay_day_text_shown:
		return false
	_pay_day_text_shown = true
	if int(_earnings()["pay_day"]) <= 0:
		return false
	show_message("%s picked up\n¥%d!" % [_player_label(), int(_earnings()["pay_day"])])
	return true


# `BattleWinSlideInEnemyTrainerFrontpic`: six columns at four frames, then 40 frames.
func _show_world_battle_result_picture() -> bool:
	if _world_battle_result_picture_shown:
		return false
	_world_battle_result_picture_shown = true
	if not _battle.is_trainer_battle or _battle.is_link_battle:
		return false
	if _battle.winner() != Gen2Battle.PLAYER:
		if not _battle.in_battle_tower and not bool(_world_battle_request.get("can_lose", false)):
			return false
		_enemy_hud_visible = false
		for index: int in 8 * Gen2BattleScreenMap.COLUMNS:
			_bg_map[index] = Gen2BattleScreenMap.BLANK_TILE
	_enemy_hud_visible = false
	_enemy_trainer_pic = _enemy_trainer_class
	_slid_pixels[Gen2Battle.ENEMY] = 56.0
	Gen2BattleScreenMap.result_trainer_step(_bg_map, 1)
	_slides.append({"incoming": true, "step": 1, "delay": 4})
	_push_view()
	return true


func _show_world_battle_terminal_text() -> bool:
	if _world_battle_terminal_text_shown:
		return false
	_world_battle_terminal_text_shown = true
	var key: String = (
		"win_text" if _battle.winner() == Gen2Battle.PLAYER else "loss_text"
	)
	var raw_pointer: Variant = _world_battle_request.get(key, {})
	if not raw_pointer is Dictionary:
		return false
	var pointer: Dictionary = raw_pointer as Dictionary
	var text: String = String(pointer.get("text", ""))
	if not text.is_empty():
		show_message(text)
		return true
	var address: int = int(pointer.get("address", 0))
	if address <= 0:
		return false
	var bank: int = int(pointer.get("bank", 0))
	var raw: PackedByteArray = _data.world_text(bank, address)
	var decoded: Dictionary = Gen2WorldScript.decode_text(raw)
	if not bool(decoded.get("ok", false)):
		_emit_world_battle_failure(&"missing_battle_result_text", {
			"bank": bank, "address": address, "text_kind": key,
		})
		return true
	text = String(decoded.get("text", ""))
	if text.is_empty():
		return false
	show_message(text)
	return true


func _prepare_world_battle_recovery() -> bool:
	if _source_save == null:
		_world_battle_recovery = {"ok": true, "source": &"development"}
		return true
	var validation: Dictionary = Gen2SaveValidator.validate(_source_save, _data)
	if not bool(validation.get("ok", false)):
		_emit_world_battle_failure(&"battle_recovery_failed", {
			"message": validation.get("message", "invalid source save"),
		})
		return false
	if Gen2SaveBattleAdapter.to_battle_party(_data, _source_save) == null:
		_emit_world_battle_failure(&"battle_recovery_failed", {
			"message": "the saved party could not be reconstructed",
		})
		return false
	_world_battle_recovery = {
		"ok": true, "source": &"save", "slot": _source_save.slot,
	}
	return true


## Answers a Baton Pass that stopped the turn, and whether there was one. The
## player's target is `ForcePickSwitchMonInBattle`, the party menu with no way out
## of it, so the list stays open until a row answers; the enemy's is
## `FindMonInOTPartyToSwitchIntoBattle`, which
## [method Gen2Battle.baton_pass_target] makes. Answered before a replacement,
## because a turn left standing here has not finished.
func _answer_baton_pass() -> bool:
	if _battle == null:
		return false
	var side: int = _battle.awaiting_baton_pass()
	if side < 0:
		return false
	if side == Gen2Battle.PLAYER:
		if _switch_stage == &"":
			_open_switch_pick(&"baton_pass")
		return true
	var next: int = _battle.baton_pass_target(side)
	if next < 0:
		return false
	_pending = _battle.pass_to(next)
	_show_next_event()
	return true


## `BattleMenu`: what the player is asked once the turn before it has finished
## being shown. `EmptyBattleTextbox` first, so the menu opens over a clear box
## rather than over the last line of the turn.
##
## `CheckPlayerHasUsableMoves` runs inside `MoveSelectionScreen` rather than
## here, so a Pokemon with nothing left still opens the menu and Struggle is
## chosen when FIGHT is.
func _open_battle_menu() -> void:
	if _battle == null or _battle.is_over() or not _pending.is_empty():
		return
	if _battle.awaiting_move_learn() or _battle.must_replace(Gen2Battle.PLAYER):
		return
	_menu_stage = &"main"
	show_message("")
	_reopen_menu_layer()


func _close_battle_menu() -> void:
	_menu_stage = &""
	_move_rows = []
	_reopen_menu_layer()


## `MoveSelectionScreen`. `wCurMoveNum` opens the cursor, and a Pokemon with no
## usable move at all does not get a list: `CheckPlayerHasUsableMoves` returns
## before the box is drawn and the turn is spent on Struggle.
func _open_move_menu() -> void:
	var mon: Gen2BattleMon = _battle.mon(Gen2Battle.PLAYER)
	_move_rows = Gen2BattleMenu.move_rows(mon, _data)
	if _move_rows.is_empty() or mon.is_out_of_pp():
		_close_battle_menu()
		_take_turn_with_slot(0)
		return
	_move_cursor = clampi(_move_cursor, 0, _move_rows.size() - 1)
	_menu_stage = &"move"
	show_message("")
	_reopen_menu_layer()


func _answer_menu(button: int) -> void:
	match _menu_stage:
		&"main":
			_answer_battle_menu(button)
		&"move":
			_answer_move_menu(button)
		&"refused":
			## `.place_textbox_start_over` blocks on the line and then jumps back
			## to `MoveSelectionScreen`, which redraws the list.
			if _box != null and _box.advance():
				return
			_open_move_menu()


## `BattleMenu.loop`: the cursor moves, A picks, and B is disabled by the
## header's own STATICMENU_DISABLE_B.
func _answer_battle_menu(button: int) -> void:
	match button:
		PokeButton.UP, PokeButton.DOWN, PokeButton.LEFT, PokeButton.RIGHT:
			var moved: int = Gen2BattleMenu.main_moved(_menu_position, button)
			if moved == _menu_position:
				return
			_menu_position = moved
			_refresh_menu_layer()
		PokeButton.A:
			_choose_battle_menu()


func _choose_battle_menu() -> void:
	match _menu_position:
		Gen2BattleMenu.FIGHT:
			_open_move_menu()
		Gen2BattleMenu.PKMN:
			## `BattleMenu_PKMN`'s list, whose SWITCH row is the only one of its
			## three this screen answers: STATS is the summary screen and CANCEL
			## comes back here.
			_close_battle_menu()
			_open_switch_pick(&"player")
		Gen2BattleMenu.PACK:
			# `BattleMenu_Pack.contest` skips the pack and throws a Park Ball.
			_close_battle_menu()
			if _is_bug_contest_battle():
				if bool(begin_capture().get("ok", false)):
					throw_capture_ball()
				return
			if not _battle.allows_bag_items() or not _pack_rows.is_empty():
				open_battle_pack()
				return
			## No bag was handed over, which is every battle outside the world
			## host: a wild one still reaches the throw the screen owns.
			if _is_wild_battle():
				begin_capture()
				return
			show_message("No item can be used here.")
		Gen2BattleMenu.RUN:
			_close_battle_menu()
			run_from_battle()


## `.interpret_joypad`: the cursor wraps, B leaves the list for the menu behind
## it, and A either refuses the slot or spends the turn on it.
func _answer_move_menu(button: int) -> void:
	match button:
		PokeButton.UP, PokeButton.DOWN:
			_move_cursor = Gen2BattleMenu.move_cursor_moved(
				_move_cursor, button, _move_rows.size()
			)
			_refresh_menu_layer()
		PokeButton.B:
			_menu_stage = &"main"
			_reopen_menu_layer()
		PokeButton.A:
			var row: Dictionary = _move_rows[_move_cursor]
			var refusal: String = Gen2BattleMenu.refusal_for(row)
			if not refusal.is_empty():
				_menu_stage = &"refused"
				show_message(refusal)
				_reopen_menu_layer()
				return
			_close_battle_menu()
			_take_turn_with_slot(int(row.get("slot", 0)))


## The turn `BattleMenu_Fight` leads to, with the slot the list chose. The
## enemy's own action is picked here rather than in the menu, the way
## `wEnemyAction` is decided after the player's choice.
func _take_turn_with_slot(slot: int) -> void:
	if _battle == null or _battle.is_over() or not _pending.is_empty():
		return
	_move_cursor = slot
	_pending = _battle.take_actions(Gen2Battle.use_move(slot), _enemy_action())
	_show_next_event()


## Opens `OfferSwitch`'s yes/no, which only SHIFT ever reaches, and answers
## whether there was a question to put up.
##
## Answered before a replacement for the same reason a Baton Pass is: the turn it
## stopped has not finished, and nothing behind it can be asked yet.
func _answer_switch_offer() -> bool:
	if _battle == null or _battle.awaiting_switch_offer() < 0:
		return false
	if _switch_stage == &"":
		_open_switch_offer()
	return true


## `OfferSwitch`'s own `lb bc, 1, 7` through `_YesNoBox`, which stores the left
## and top it is handed and adds five and four for the other two. The flags, the
## options and the `db 1` that opens the cursor on YES are `YesNoMenuHeader`'s.
## `InterpretTwoOptionMenu`'s fifteen frames are not spent, as no menu delay here
## is. Below: `ItemSubmenu.UsableMenuHeader`'s two rows. Every item a battle lists
## is usable, so `.UnusableMenuData`'s single QUIT row is unreachable here.
const PACK_ACTION_LEFT: int = 13
const PACK_ACTION_TOP: int = 7
const PACK_ACTION_SPAN: Vector2i = Vector2i(6, 4)
const PACK_ACTIONS: Array[String] = ["USE", "QUIT"]

const YES_NO_LEFT: int = 1
const YES_NO_TOP: int = 7
const YES_NO_SPAN: Vector2i = Vector2i(5, 4)
const YES_NO_OPTIONS: Array[String] = ["YES", "NO"]
const YES_NO_FLAGS: int = Gen2MenuBox.STATICMENU_CURSOR \
	| Gen2MenuBox.STATICMENU_NO_TOP_SPACING


## Puts `OfferSwitch`'s question and its yes/no box up. The enemy's Pokémon is
## named while it is still on its way in, which is the whole point of asking
## before `ShowSetEnemyMonAndSendOutAnimation`.
func _open_switch_offer() -> void:
	var incoming: Gen2BattleMon = _battle.party(Gen2Battle.ENEMY).at(
		_battle.awaiting_switch_offer()
	)
	_open_yes_no(&"offer", Gen2BattleSwitchMenu.offer_text(
		_enemy_label(), incoming.name_text() if incoming != null else "", _player_label()
	))


## `AskUseNextPokemon`'s question, over the box its own `lb bc, 1, 7` puts in the
## same place `OfferSwitch`'s goes.
func _open_use_next() -> void:
	_open_yes_no(&"use_next", Gen2BattleSwitchMenu.use_next_text())


func _open_yes_no(stage: StringName, question: String) -> void:
	show_message(question)
	_switch_offer = Gen2WorldMenu.new()
	_switch_offer.options = YES_NO_OPTIONS.duplicate()
	_switch_offer.flags = YES_NO_FLAGS
	_switch_offer.rows = YES_NO_OPTIONS.size()
	_switch_offer.cursor = 0
	_switch_stage = stage
	_reopen_menu_layer()


## `SetUpBattlePartyMenu` and the list behind it. [param reason] is which question
## the row will answer; every one but `OfferSwitch`'s is a list with no way out.
func _open_switch_pick(reason: StringName) -> void:
	_switch_reason = reason
	## `PickSwitchMonInBattle` rather than `ForcePickSwitchMonInBattle` for the
	## two the player opened themselves: `OfferSwitch`'s YES and the battle
	## menu's own PKMN, both of which can be backed out of.
	_switch_menu = Gen2BattleSwitchMenu.for_party(
		_battle.party(Gen2Battle.PLAYER), reason not in [&"offer", &"player", &"item"]
	)
	_switch_offer = null
	_switch_stage = &"pick"
	## `InitPartyMenuGFX` spawns the icons where the list is built, so a reopened
	## list opens on the first frame of their animation rather than resuming.
	if _party_page != null:
		_party_page.reset(_switch_menu.rows)
	_icon_clock.reset()
	## The party menu is the whole screen rather than a box on it, so the battle's
	## own box goes with the field it belongs to.
	if _box != null:
		_box.visible = false
	_reopen_menu_layer()


func _close_switch() -> void:
	_switch_stage = &""
	_switch_reason = &""
	_switch_menu = null
	_switch_offer = null
	if _box != null:
		_box.visible = true
	_reopen_menu_layer()


func _answer_switch(button: int) -> void:
	match _switch_stage:
		&"offer":
			_answer_switch_offer_button(button)
		&"use_next":
			_answer_use_next_button(button)
		&"pick":
			_answer_switch_pick(button)
		&"contest_replace":
			_answer_contest_replace(button)
		&"refused":
			## `StdBattleTextbox` blocks on a button and `jr .loop` reopens the
			## list behind it.
			if _box != null and _box.advance():
				return
			_open_switch_pick(_switch_reason)


## `BugContest_SetCaughtContestMon`'s own `PlaceYesNoBox`, which `ret c` reads as
## keeping the Pokemon already caught. The answer rides out on the capture
## result, since what it decides is world state rather than battle state.
## `_ContestAskSwitchText`, which is what `PlaceYesNoBox` stands under.
const CONTEST_REPLACE_TEXT: String = "Switch #MON?"
## `_ContestAlreadyCaughtText`, said first and prompted past.
## `DisplayAlreadyCaughtText` names the Pokemon already held.
const CONTEST_ALREADY_CAUGHT_TEXT: String = "You already caught\na %s."

## `DisplayCaughtContestMonStats`' two `Textbox` calls, each `hlcoord 0, n` with
## `ld b, 4 / ld c, 13`: an interior four rows by thirteen columns, so the border
## runs to column 14 and five rows down from its own top.
const CONTEST_STATS_LEFT: int = 0
const CONTEST_STATS_RIGHT: int = 14
const CONTEST_STOCK_TOP: int = 0
const CONTEST_THIS_TOP: int = 6
const CONTEST_STATS_HEIGHT: int = 5

## Where the routine's own `PlaceString` calls land, relative to each box's top.
## `.Stock` and `.This` are written at column 2 on the border row itself, spaces
## and all, so the frame is blanked either side of the title.
const CONTEST_TITLE_AT: Vector2i = Vector2i(2, 0)
const CONTEST_NAME_AT: Vector2i = Vector2i(1, 2)
const CONTEST_HEALTH_AT: Vector2i = Vector2i(5, 4)
const CONTEST_HP_AT: Vector2i = Vector2i(11, 4)
## `PrintNum` with `lb bc, 2, 3`: three digits out of two bytes, space padded.
const CONTEST_HP_DIGITS: int = 3
const CONTEST_STOCK_TITLE: String = " STOCK <PKMN> "
const CONTEST_THIS_TITLE: String = " THIS <PKMN>  "
const CONTEST_HEALTH: String = "HEALTH"

## `lb bc, 14, 7` into `PlaceYesNoBox`, which is `YesNoBox`'s own corner rather
## than `OfferSwitch`'s [constant YES_NO_LEFT]: the question stands beside the
## THIS box rather than over the STOCK one.
const CONTEST_YES_NO_LEFT: int = 14
const CONTEST_YES_NO_TOP: int = 7

## `LoadFontsBattleExtra`, so the page is drawn with the strip `<LV>` lives on,
## the way the Hall of Fame panel is.
const CONTEST_FONT: StringName = Gen2Text.FONT_BATTLE_EXTRA
## `PrintLevel`'s `ld [hl], '<LV>'`, which puts a byte down rather than printing
## a string, so it is placed as a code the way [Gen2HallOfFamePage] places one.
const CONTEST_LEVEL_CODE: int = 0x6E


func _answer_contest_replace(button: int) -> void:
	if _offer_still_reading():
		if button == PokeButton.A:
			_box.advance()
			_refresh_menu_layer()
		return
	match button:
		PokeButton.UP, PokeButton.DOWN:
			_switch_offer.move(Vector2i(0, 1 if button == PokeButton.DOWN else -1))
			_refresh_menu_layer()
		PokeButton.A, PokeButton.B:
			var replace: bool = button == PokeButton.A \
				and _switch_offer.selected_index() == 0
			_close_switch()
			var capture: Dictionary = _capture_result.duplicate(true)
			capture["replace"] = replace
			_clear_capture_action()
			_finish_world_capture(capture)


## `InterpretTwoOptionMenu` over `YesNoMenuHeader`: two rows that do not wrap,
## and a B that is the same answer as NO.
func _answer_switch_offer_button(button: int) -> void:
	## The question is two paragraphs, so a press reads it before it answers
	## anything, the way [method _answer_forget] does. The box is not up on
	## hardware until the text is either.
	if _offer_still_reading():
		if button == PokeButton.A:
			_box.advance()
			_refresh_menu_layer()
		return
	match button:
		PokeButton.UP, PokeButton.DOWN:
			_switch_offer.move(Vector2i(0, 1 if button == PokeButton.DOWN else -1))
			_refresh_menu_layer()
		PokeButton.A:
			if _switch_offer.selected_index() == 0:
				_open_switch_pick(&"offer")
			else:
				_decline_switch_offer()
		PokeButton.B:
			_decline_switch_offer()


## `AskUseNextPokemon`'s own loop. Its `.pressed_b` branch back to YES is
## unreachable: `InterpretTwoOptionMenu` writes cursor NO on every carry it
## returns, so a B is the same answer as NO, which is what the offer above does
## with one too.
func _answer_use_next_button(button: int) -> void:
	if _offer_still_reading():
		if button == PokeButton.A:
			_box.advance()
			_refresh_menu_layer()
		return
	match button:
		PokeButton.UP, PokeButton.DOWN:
			_switch_offer.move(Vector2i(0, 1 if button == PokeButton.DOWN else -1))
			_refresh_menu_layer()
		PokeButton.A:
			_answer_use_next(_switch_offer.selected_index() == 0)
		PokeButton.B:
			_answer_use_next(false)


## YES falls straight into `ForcePlayerMonChoice` with no press in between; NO
## runs, and a run that does not get away leaves its own line up and reaches the
## same list on the press that reads it.
func _answer_use_next(use_next: bool) -> void:
	var events: Array = _battle.answer_use_next(use_next)
	_close_switch()
	if not events.is_empty():
		_pending = events
		_show_next_event()
		return
	_replace_the_fallen()


## Whether `StdBattleTextbox` is still printing the question the box belongs to.
func _offer_still_reading() -> bool:
	return _box != null and (_box.is_revealing() or _box.has_pages_left())


## `PartyMenuSelect`'s own joypad filter: the cursor, A and B, with everything
## else ignored.
func _answer_switch_pick(button: int) -> void:
	match button:
		PokeButton.UP:
			_switch_menu.move(-1)
			_refresh_menu_layer()
		PokeButton.DOWN:
			_switch_menu.move(1)
			_refresh_menu_layer()
		PokeButton.A:
			## `UseItem_SelectMon` makes neither of `PickPartyMonInBattle`'s two
			## checks: a fainted member is exactly what a Revive wants, and the
			## one already out is what a potion usually goes on. The item's own
			## effect is what refuses.
			if _switch_reason == &"item" and not _switch_menu.is_cancel(_switch_menu.cursor):
				_resolve_switch({
					"result": Gen2BattleSwitchMenu.CHOSEN,
					"index": int(_switch_menu.rows[_switch_menu.cursor].get("index", -1)),
				})
				return
			_resolve_switch(_switch_menu.confirm())
		PokeButton.B:
			_resolve_switch(_switch_menu.cancel())


func _resolve_switch(answer: Dictionary) -> void:
	match StringName(answer.get("result", &"")):
		Gen2BattleSwitchMenu.CHOSEN:
			_play_sfx(Gen2BattleSwitchMenu.SFX_READ_TEXT_2)
			_commit_switch(int(answer.get("index", -1)))
		Gen2BattleSwitchMenu.CANCELLED:
			_play_sfx(Gen2BattleSwitchMenu.SFX_READ_TEXT_2)
			## A target list backed out of leaves the item where it was and
			## reopens the pack it was chosen from.
			if _switch_reason == &"item":
				_close_switch()
				open_battle_pack()
				return
			## `BattleMenuPKMN_Loop`'s `.Cancel` is a `jp BattleMenu`: the list
			## the player opened themselves goes back to the menu it came from.
			if _switch_reason == &"player":
				_close_switch()
				_open_battle_menu()
				return
			## `OfferSwitch.canceled_switch` falls into `.said_no`: backing out of
			## the list is the same answer as NO.
			_decline_switch_offer()
		Gen2BattleSwitchMenu.CANNOT_CANCEL:
			_play_sfx(int(answer.get("sfx", 0)))
		_:
			_show_switch_refusal(String(answer.get("text", "")))


func _commit_switch(index: int) -> void:
	var reason: StringName = _switch_reason
	_close_switch()
	match reason:
		&"item":
			## `StatusHealer_Jumptable`'s way back: the pack is where a used item
			## leaves the player, and where a cancelled one does too.
			if _pack_item in Gen2Battle.SLOT_PP_ITEMS:
				_open_pack_move(_pack_item, index)
				return
			_use_pack_item(_pack_item, index)
			return
		&"baton_pass":
			_pending = _battle.pass_to(index)
		&"replace":
			_pending = _battle.replace_fallen(index)
		&"player":
			## `TryPlayerSwitch` spends the turn: the switch is the player's
			## action and the enemy answers it, which is what makes a free switch
			## cost a hit.
			_pending = _battle.take_actions(
				Gen2Battle.switch_to(index), _enemy_action()
			)
		_:
			_pending = _battle.answer_switch_offer(index)
	_show_next_event()


func _decline_switch_offer() -> void:
	_close_switch()
	_pending = _battle.answer_switch_offer(-1)
	_show_next_event()


## `BattleText_MonIsAlreadyOut` and `BattleText_TheresNoWillToBattle`, which the
## source prints in a battle text box over the party menu and then redraws the
## list behind.
func _show_switch_refusal(text: String) -> void:
	_switch_stage = &"refused"
	if _box != null:
		_box.visible = true
	show_message(text)
	_reopen_menu_layer()


## `PlaceEnemysName`: the opponent's class name, a space, and their own name.
func _enemy_label() -> String:
	if _battle == null or not _battle.is_trainer_battle:
		return _name_of(_enemy)
	return _enemy_battler_label()


## `<PLAYER>`. A development battle has no save to read a name off, so
## `NewGame`'s own default stands in rather than a blank in the middle of a
## sentence.
func _player_label() -> String:
	if _world_battle_tutorial:
		return DUDE_NAME
	if _source_save != null and not _source_save.player_name.is_empty():
		return _source_save.player_name
	return Gen2OakSpeech.DEFAULT_MALE


## Redraws the menu layer even when nothing about the cursor moved, which is what
## opening a list has to do: the same stage and cursor can be looking at a
## different party.
func _reopen_menu_layer() -> void:
	_menu_drawn = ""
	_refresh_menu_layer()


## The yes/no frame over the field, or the whole party page in place of it.
## Cheap to call every frame: it rebuilds only when what it would draw changed.
func _refresh_menu_layer() -> void:
	if _menu_layer == null:
		return
	var signature: String = _menu_signature()
	if signature == _menu_drawn:
		return
	_menu_drawn = signature
	## The move rows and which one the cursor is on are part of the snapshot, so
	## the annotations move with the menu as well as with the battle.
	_refresh_annotations()

	if _info_layer != null:
		_info_layer.visible = false
	if _battle_menu_layer != null:
		_battle_menu_layer.visible = false
	_draw_menu_layer()


func _menu_signature() -> String:
	return "%s|%s|%d|%d|%d|%s|%s|%s" % [
		_switch_stage, _menu_stage,
		_switch_offer.selected_index() if _switch_offer != null else (
			_switch_menu.cursor if _switch_menu != null else -1
		),
		int(_offer_still_reading()),
		_menu_position * 8 + _move_cursor,
		## The four lists in front of the fight, each with the cursor it is
		## drawn from: which one is up is part of what the layer is holding.
		"%s%d,%d,%d,%d,%d,%d" % [
			_forget_stage, _forget_cursor, _forget_confirm_cursor,
			_pack_index if _pack_selecting else -1,
			_pack_move_index if _pack_move_selecting else -1,
			_capture_ball_index if _capture_selecting else -1,
			_pack_rows.size(),
		],
		"%s%d" % [_pack_action_stage, _pack_action_index],
		## The icons move on their own clock, so the cursor alone does not say
		## whether the page still draws what the layer is holding.
		_party_page.animation_signature() if _party_page != null else "",
	]


func _draw_menu_layer() -> void:
	match _switch_stage:
		&"contest_replace":
			_draw_contest_stats()
			return
		&"offer", &"use_next":
			_draw_yes_no_box()
			return
		&"pick", &"refused":
			_draw_party_page()
			return
	if _forget_stage != &"":
		_draw_forget_stage()
		return
	if _pack_action_stage != &"":
		## `MENU_BACKUP_TILES`: the submenu's box is drawn over the list the row
		## was chosen from, which stays where it was.
		if _pack_action_stage == &"capture":
			_draw_capture_menu()
		else:
			_draw_pack_menu()
		_draw_pack_action_menu()
		return
	if _pack_move_selecting:
		_draw_pack_move_menu()
		return
	if _pack_selecting:
		_draw_pack_menu()
		return
	if _capture_selecting:
		_draw_capture_menu()
		return
	match _menu_stage:
		&"main":
			_draw_battle_menu()
		&"move":
			_draw_move_menu()
		_:
			_menu_layer.visible = false


## `DisplayCaughtContestMonStats`: the screen is cleared and the two boxes are
## drawn over it, STOCK #MON above THIS #MON, each with a name, a level and a
## HEALTH number, with `PlaceYesNoBox`' own box beside the lower one.
##
## One image on the menu layer, the way the party page is: all three boxes go
## into the tilemap on the cartridge too, and the text box under them is this
## screen's own, which is where `ContestAskSwitchText` is already being said.
func _draw_contest_stats() -> void:
	if _menu_page == null or _menu_page.font == null:
		_menu_layer.visible = false
		return
	var width: int = Gen2Screen.WIDTH
	var indices := PackedByteArray()
	indices.resize(width * Gen2Screen.HEIGHT)
	var caught: Dictionary = _capture_result.get("mon", {})
	_draw_contest_box(
		indices, width, CONTEST_STOCK_TOP, CONTEST_STOCK_TITLE,
		_contest_stock_name(),
		int(_capture_result.get("stock_level", 0)),
		int(_capture_result.get("stock_max_hp", 0))
	)
	_draw_contest_box(
		indices, width, CONTEST_THIS_TOP, CONTEST_THIS_TITLE,
		_name_of(int(caught.get("species", 0))),
		int(caught.get("level", 0)),
		int(caught.get("max_hp", 0))
	)
	var box: Gen2MenuBox = Gen2MenuBox.from_coords(
		CONTEST_YES_NO_LEFT, CONTEST_YES_NO_TOP,
		CONTEST_YES_NO_LEFT + YES_NO_SPAN.x, CONTEST_YES_NO_TOP + YES_NO_SPAN.y,
		YES_NO_FLAGS
	)
	## The question is read before it is answered, the way every other offer here
	## is: the box comes up once the line has finished appearing.
	if not _offer_still_reading():
		_menu_page.draw(
			box, YES_NO_OPTIONS,
			_switch_offer.selected_index() if _switch_offer != null else 0,
			indices, width
		)
	## Only the rows the page occupies. Rows 12 to 17 are the text box's own, and
	## this screen draws that itself.
	var rows: int = (CONTEST_THIS_TOP + CONTEST_STATS_HEIGHT + 1) * Gen2Font.TILE
	var image: Image = Gen2PicImage.from_indices(
		indices, width, Gen2Screen.HEIGHT,
		PokePalette.pic_palette(PackedColorArray([Color.WHITE, Color.BLACK]))
	).get_region(Rect2i(0, 0, width, rows))
	_show_menu_image(image, Vector2i.ZERO)


## One of the two, at [param top]. The strings are the routine's own and land
## where its `hlcoord`s put them, measured from the box rather than the screen.
func _draw_contest_box(
	indices: PackedByteArray, width: int, top: int,
	title: String, mon_name: String, level: int, max_hp: int
) -> void:
	var tile: int = Gen2Font.TILE
	var box: Gen2MenuBox = Gen2MenuBox.from_coords(
		CONTEST_STATS_LEFT, top, CONTEST_STATS_RIGHT, top + CONTEST_STATS_HEIGHT, 0
	)
	_menu_page.draw(box, [], -1, indices, width, "", 0, [
		{"text": mon_name, "at": CONTEST_NAME_AT + Vector2i(0, top)},
		{"text": CONTEST_HEALTH, "at": CONTEST_HEALTH_AT + Vector2i(0, top)},
		{
			"text": String("%d" % max_hp).lpad(CONTEST_HP_DIGITS, " "),
			"at": CONTEST_HP_AT + Vector2i(0, top),
		},
	])
	## The title sits on the border row, and `PlaceString` writes its own leading
	## and trailing spaces as $7f, which is a tile write like any other and blanks
	## the frame under them. [method Gen2Font.draw_code] draws nothing for a
	## space, on purpose, so the cells are cleared here first: without it the
	## border shows through the gaps either side of STOCK #MON. Drawn after the
	## box for the same reason the source places it after `Textbox`.
	var title_at: Vector2i = CONTEST_TITLE_AT + Vector2i(0, top)
	_blank_tiles(indices, width, title_at, Gen2Text.encoded_length(title))
	_menu_page.font.draw_text(
		title, indices, width, title_at.x * tile, title_at.y * tile
	)
	## `ld h, b / ld l, c`: `PlaceString` answers the cell after the name it
	## wrote, and `PrintLevel` starts there.
	var at: Vector2i = CONTEST_NAME_AT + Vector2i(Gen2Text.encoded_length(name), top)
	_menu_page.font.draw_code(
		CONTEST_LEVEL_CODE, indices, width, at.x * tile, at.y * tile, CONTEST_FONT
	)
	_menu_page.font.draw_text(
		str(level), indices, width, (at.x + 1) * tile, at.y * tile, CONTEST_FONT
	)


## [param count] tiles of index 0 from [param at], which is what the source's own
## $7f blank draws as.
func _blank_tiles(
	indices: PackedByteArray, width: int, at: Vector2i, count: int
) -> void:
	var tile: int = Gen2Font.TILE
	for row: int in tile:
		var start: int = (at.y * tile + row) * width + at.x * tile
		for column: int in count * tile:
			var offset: int = start + column
			if offset >= 0 and offset < indices.size():
				indices[offset] = 0


## [param cursor] is which row is chosen, and -1 asks the switch offer that owns
## every other one of these boxes.
func _draw_yes_no_box(cursor: int = -1) -> void:
	if _menu_page == null or _offer_still_reading():
		_menu_layer.visible = false
		return
	var box: Gen2MenuBox = Gen2MenuBox.from_coords(
		YES_NO_LEFT, YES_NO_TOP,
		YES_NO_LEFT + YES_NO_SPAN.x, YES_NO_TOP + YES_NO_SPAN.y, YES_NO_FLAGS
	)
	_show_menu_image(
		_menu_page.render(
			box, YES_NO_OPTIONS,
			cursor if cursor >= 0 else _switch_offer.selected_index()
		),
		box.border_position() * Gen2Font.TILE
	)


## `BattleMenuHeader`'s two-by-two, drawn where its own `menu_coords` put it.
func _draw_battle_menu() -> void:
	if _menu_page == null:
		return
	var contest: bool = _is_bug_contest_battle()
	var box: Gen2MenuBox = Gen2BattleMenu.main_box(contest)
	var extras: Array = []
	if contest:
		## `.PrintParkBallsRemaining`, which prints the count beside the row
		## rather than inside it.
		extras.append({
			"text": "%2d" % _capture_quantity(Gen2WorldPartyHost.ITEM_PARK_BALL),
			"at": Gen2BattleMenu.CONTEST_BALLS_AT,
		})
	_show_layer_image(
		_battle_menu_layer,
		_menu_page.render(
			box, Gen2BattleMenu.main_options(contest), _menu_position - 1,
			"", 0, extras
		),
		box.border_position() * Gen2Font.TILE
	)


## `MoveSelectionScreen`'s list and the `MoveInfoBox` beside it.
func _draw_move_menu() -> void:
	if _menu_page == null or _move_rows.is_empty():
		return
	var names: Array = []
	for row: Dictionary in _move_rows:
		names.append(String(row.get("name", "")))
	var box: Gen2MenuBox = Gen2BattleMenu.move_box()
	_show_layer_image(
		_battle_menu_layer,
		_menu_page.render(box, names, _move_cursor),
		box.border_position() * Gen2Font.TILE
	)
	_draw_move_info(_move_rows[_move_cursor])


## One of the lists standing in front of the fight, windowed onto
## [constant Gen2BattleMenu.LIST_ROWS] rows with the cursor kept inside it.
func _draw_list_menu(key: StringName, labels: Array, cursor: int) -> void:
	_menu_layer.visible = false
	if _menu_page == null or labels.is_empty():
		return
	var scroll: int = Gen2BattleMenu.list_scrolled(
		int(_list_scroll.get(key, 0)), cursor, labels.size()
	)
	_list_scroll[key] = scroll
	var box: Gen2MenuBox = Gen2BattleMenu.list_box(
		scroll, labels.size() > Gen2BattleMenu.LIST_ROWS
	)
	_show_layer_image(
		_battle_menu_layer,
		_menu_page.render(
			box,
			labels.slice(scroll, scroll + Gen2BattleMenu.LIST_ROWS),
			cursor - scroll
		),
		box.border_position() * Gen2Font.TILE
	)


## A row with [param tail] against the box's right-hand edge, which is where the
## pack writes a count and the move list a PP pair.
static func _list_row(text: String, tail: String) -> String:
	var room: int = maxi(Gen2BattleMenu.LIST_TEXT_WIDTH - tail.length(), 0)
	return text.left(room).rpad(room) + tail


## `Pack`'s own rows for the items a battle can use, with what is left of each.
func _draw_pack_menu() -> void:
	var labels: Array = []
	for item: int in _pack_rows:
		labels.append(
			_list_row(_item_name(item), "×%d" % int(_pack_quantities.get(item, 1)))
		)
	_draw_list_menu(&"pack", labels, _pack_index)


## The BALL pocket of the same list: what choosing a ball in the pack opens, and
## the whole of what a fight with no bag behind it is handed.
func _draw_capture_menu() -> void:
	var labels: Array = []
	for ball: int in _capture_balls:
		labels.append(_list_row(_item_name(ball), "×%d" % _capture_quantity(ball)))
	_draw_list_menu(&"capture", labels, _capture_ball_index)


## `ItemSubmenu`'s USE/QUIT box, which stands over the list the row was chosen
## from and is what the second A press answers.
##
## On [member _info_layer] rather than on the menu layer, which is under the
## list: `LoadMenuHeader` draws this box into the tilemap after the pack's own,
## so it covers the rows it was opened from.
func _draw_pack_action_menu() -> void:
	if _menu_page == null:
		return
	var box: Gen2MenuBox = Gen2MenuBox.from_coords(
		PACK_ACTION_LEFT, PACK_ACTION_TOP,
		PACK_ACTION_LEFT + PACK_ACTION_SPAN.x, PACK_ACTION_TOP + PACK_ACTION_SPAN.y,
		YES_NO_FLAGS
	)
	_show_layer_image(
		_info_layer,
		_menu_page.render(box, PACK_ACTIONS, _pack_action_index),
		box.border_position() * Gen2Font.TILE
	)


## `RestorePPEffect`'s question, as the pack's own move list: which slot the
## Ether goes on, with the PP it stands on.
func _draw_pack_move_menu() -> void:
	var mon: Gen2BattleMon = _battle.party(Gen2Battle.PLAYER).at(_pack_move_target) \
		if _battle != null else null
	if mon == null or _data == null:
		_menu_layer.visible = false
		return
	var labels: Array = []
	for raw_slot: int in _pack_move_slots:
		var record: Dictionary = _data.move(int(mon.moves[raw_slot]))
		labels.append(_list_row(
			String(record.get("name", "")),
			"%2d/%2d" % [mon.pp_left(raw_slot), int(record.get("pp", 0))]
		))
	_draw_list_menu(&"pack_move", labels, _pack_move_index)


## `ForgetMove`'s own frame over the field, or the `YesNoBox` of the two
## questions either side of the list.
func _draw_forget_stage() -> void:
	if _forget_stage != &"list":
		_draw_yes_no_box(_forget_confirm_cursor)
		return
	_menu_layer.visible = false
	if _menu_page == null or _forget_moves.is_empty():
		return
	var labels: Array = []
	for entry: Dictionary in _forget_moves:
		labels.append(String(entry.get("name", "")))
	var box: Gen2MenuBox = Gen2BattleMenu.forget_box()
	_show_layer_image(
		_battle_menu_layer, _menu_page.render(box, labels, _forget_cursor),
		box.border_position() * Gen2Font.TILE
	)


## `MoveInfoBox`: the type and the PP pair of the row the cursor is on, or its
## `.Disabled` line in place of both.
func _draw_move_info(row: Dictionary) -> void:
	var box: Gen2MenuBox = Gen2BattleMenu.info_box()
	var extras: Array = []
	if bool(row.get("disabled", false)):
		extras.append({
			"text": Gen2BattleMenu.INFO_DISABLED,
			"at": Gen2BattleMenu.INFO_DISABLED_AT,
		})
	else:
		extras.append({
			"text": Gen2BattleMenu.INFO_TYPE_LABEL,
			"at": Gen2BattleMenu.INFO_TYPE_LABEL_AT,
		})
		extras.append({
			"text": _data.type_name(int(row.get("type", 0))),
			"at": Gen2BattleMenu.INFO_TYPE_AT,
		})
		## `PrintNum` with `lb bc, 1, 2`: two digits, space padded, either side
		## of the '/' the routine writes itself.
		extras.append({
			"text": "%2d/%2d" % [int(row.get("pp", 0)), int(row.get("max_pp", 0))],
			"at": Gen2BattleMenu.INFO_PP_AT,
		})
	_show_layer_image(
		_info_layer, _menu_page.render(box, [], -1, "", 0, extras),
		box.border_position() * Gen2Font.TILE
	)


## `PlaySpriteAnimations` over the party page's icons, on the hardware clock the
## bars use.
func _advance_party_icons(delta: float) -> void:
	if _party_page == null or _switch_menu == null or _switch_stage not in [&"pick", &"refused"]:
		_icon_clock.reset()
		return
	for _frame: int in _icon_clock.tick(delta):
		advance_party_icons()


## One pass of the party page's icons. Public with [method advance_frame] so a
## test or a screenshot driver can step them without waiting on real time.
func advance_party_icons() -> bool:
	if _party_page == null or _switch_menu == null:
		return false
	_party_page.advance(_switch_menu.rows, _switch_menu.cursor)
	return true


func _draw_party_page() -> void:
	if _party_page == null or _switch_menu == null:
		_menu_layer.visible = false
		return
	_show_menu_image(
		_party_page.render(
			_switch_menu.rows, _switch_menu.cursor, Gen2BattleSwitchMenu.prompt_text()
		),
		Vector2i.ZERO
	)


func _show_menu_image(image: Image, at: Vector2i) -> void:
	_show_layer_image(_menu_layer, image, at)


func _show_layer_image(layer: TextureRect, image: Image, at: Vector2i) -> void:
	if layer == null:
		return
	Gen2PicImage.show(layer, image)
	layer.position = Vector2(at)
	layer.size = Vector2(image.get_size())
	layer.visible = true


## `HandlePlayerMonFaint` and `HandleEnemyMonFaint`'s replacement tail put on
## screen, and whether any of it had something to do.
##
## The three steps are the source's own order: `AskUseNextPokemon`'s wild
## question, `ForcePlayerMonChoice`'s list, and then the trainer's own entrance,
## which [method Gen2Battle.replace_fallen] picks and which SHIFT turns into
## another offer.
func _replace_the_fallen() -> bool:
	if _battle == null:
		return false

	if _battle.asking_use_next():
		if _switch_stage == &"":
			_open_use_next()
		return true

	if _battle.must_replace(Gen2Battle.PLAYER):
		if _switch_stage == &"":
			_open_switch_pick(&"replace")
		return true

	if not _battle.must_replace(Gen2Battle.ENEMY):
		return false
	var events: Array = _battle.replace_fallen()
	if events.is_empty():
		return false
	_pending = events
	_show_next_event()
	## `EnemySwitch` asks before that Pokémon is on the field, so the question
	## goes up in the same step rather than a press later.
	if _pending.is_empty():
		_answer_switch_offer()
	return true


## The next event, with whatever it changes applied first.
##
## Every number drawn comes from the event, not the Pokémon: the turn has already
## resolved by the time the first event is shown, so reading the Pokémon would
## draw the end of the turn during the middle of it.
func _show_next_event() -> void:
	while not _pending.is_empty():
		var event: Dictionary = _pending.pop_front()
		## The box lasts exactly as long as the line it was drawn beside, and
		## this is the press that took that line away.
		_clear_level_up_box()
		event = Gen2ModHost.publish(Gen2ModHost.CHANNEL_BATTLE, event)
		if StringName(event["type"]) == Gen2Battle.CRY:
			## `PlayStereoCry` is `_PlayMonCry` and then `WaitSFX`, so an
			## entrance stands still for as long as the cry lasts. Its silent
			## sibling `PlayStereoCry2` is what a pic animation uses and is not
			## this.
			_apply_event(event)
			_anim_plan = []
			_step(ANIM_WAIT_SFX, {})
			_run_next_anim_step()
			if animation_running():
				return
			continue
		if StringName(event["type"]) == Gen2Battle.APPEAR_USER:
			## `AppearUser` alone: no script and no frames, just the picture back
			## in the map. It goes through the plan anyway, since that is where
			## the step knows which side it is putting back.
			_anim_plan = []
			_anim_event = {
				"enemy_turn": int(event.get("side", Gen2Battle.PLAYER)) == Gen2Battle.ENEMY,
			}
			_step(ANIM_APPEAR_USER, {})
			_run_next_anim_step()
			if animation_running():
				return
			continue
		if StringName(event["type"]) == Gen2Battle.ANIMATION:
			## The engine has already resolved; this event is the frames the
			## screen owes for it, and nothing behind it is shown until they are
			## spent. `PlayFXAnimID` blocks the same way.
			_begin_animation(event)
			if animation_running():
				return
			continue
		_apply_event(event)
		var text: String = _describe(event)
		if not text.is_empty():
			## `applydamage` animates the bar and only then does `criticaltext`
			## print, so a message caused by an event that moved a bar waits for
			## it rather than racing it.
			if not _bars.is_empty() or fainting():
				_held_message = text
			else:
				show_message(text)
			return
		## `AnimateHPBar` and `MonFaintedAnimation` both block: the source does
		## not reach the next command until the bar has emptied and the picture
		## has sunk. Without this stop, a hit with no line of its own popped the
		## faint in the same pass and the picture left the field while its own bar
		## was still draining. [method _resume_after_frames] brings the queue back
		## when the frames are spent.
		if not _bars.is_empty() or fainting():
			return
	## The queue ran dry with nothing to print. `DoTurn` does not read a button
	## between its last command and `BattleMenu`, so the screen runs on rather
	## than leaving a stale box up until a press nobody owes.
	_continue_after_messages()


## The events that mean a bar moved rather than a bar was placed: each is a
## point where the source reaches `AnimateHPBar` through `DoEnemyDamage`,
## `DoPlayerDamage` or one of the heal commands. `SENT_OUT` is deliberately not
## among them, because that bar is drawn rather than drained.
const HP_BAR_EVENTS: Array[StringName] = [
	Gen2Battle.HIT, Gen2Battle.RECOIL, Gen2Battle.DRAINED, Gen2Battle.OHKO,
	Gen2Battle.HURT_BY_STATUS, Gen2Battle.HURT_ITSELF, Gen2Battle.HP_RESTORED,
	Gen2Battle.TRAINER_USED_ITEM,
]


func _apply_event(event: Dictionary) -> void:
	var before_enemy: int = _enemy_hp
	var before_enemy_max: int = _enemy_max_hp
	var before_player: int = _player_hp
	var before_player_max: int = _player_max_hp
	var before_exp: int = _exp
	_apply_event_state(event)
	## Stages, weather, Haze, a Baton Pass and a switch all land here and only
	## some of them move a bar, so the annotations follow the event rather than
	## waiting for the next view push.
	_refresh_annotations()
	if StringName(event["type"]) == Gen2Battle.EXP_GAINED:
		_start_exp_bar(event, before_exp)
		return
	if not HP_BAR_EVENTS.has(StringName(event["type"])):
		return
	_start_bar(Gen2Battle.ENEMY, before_enemy, before_enemy_max)
	_start_bar(Gen2Battle.PLAYER, before_player, before_player_max)


func _apply_event_state(event: Dictionary) -> void:
	match event["type"]:
		Gen2Battle.HIT, Gen2Battle.RECOIL, Gen2Battle.DRAINED, Gen2Battle.OHKO:
			var target: int = int(event.get("target", event["side"]))
			if target == Gen2Battle.ENEMY:
				set_hp(int(event["hp"]), int(event["max_hp"]), _player_hp, _player_max_hp)
			else:
				set_hp(_enemy_hp, _enemy_max_hp, int(event["hp"]), int(event["max_hp"]))
		Gen2Battle.HURT_BY_STATUS, Gen2Battle.HURT_ITSELF, Gen2Battle.HP_RESTORED, \
			Gen2Battle.TRAINER_USED_ITEM:
			if int(event["side"]) == Gen2Battle.ENEMY:
				set_hp(int(event["hp"]), int(event["max_hp"]), _player_hp, _player_max_hp)
			else:
				set_hp(_enemy_hp, _enemy_max_hp, int(event["hp"]), int(event["max_hp"]))
		Gen2Battle.FAINTED:
			# `FaintYourPokemon` and `FaintEnemyPokemon` sink the picture before
			# either prints, so the line waits on the animation.
			_begin_faint(int(event["side"]))
		Gen2Battle.MOVE_FORGOTTEN:
			_play_sfx(Gen2MoveForget.SFX_SWITCH_POKEMON)
		Gen2Battle.SUBSTITUTE_PIC:
			_set_substitute_pic(int(event["side"]), bool(event["raised"]))
		Gen2Battle.MINIMIZED:
			_set_minimize_pic(int(event["side"]), true)
		Gen2Battle.TRANSFORMED:
			# `BattleCommand_Transform` copies the species and the DVs onto the
			# actor, and every reload of the square after it draws the target.
			if int(event["side"]) == Gen2Battle.ENEMY:
				_enemy = int(event["species"])
				_enemy_unown_form = int(event.get("unown_form", 0))
				_enemy_shiny = bool(event.get("shiny", false))
			else:
				_player = int(event["species"])
				_player_unown_form = int(event.get("unown_form", 0))
				_player_shiny = bool(event.get("shiny", false))
			_push_view()
		Gen2Battle.CRY:
			_play_entrance_cry(int(event["side"]), int(event["species"]))
		Gen2Battle.SENT_OUT:
			# The pic and the panel both change, and both come out of the event
			# rather than out of the party, for the same reason every other number
			# here does. The level is part of that: a trainer's own party is not
			# all one level the way the invented one used to be.
			if int(event["side"]) == Gen2Battle.ENEMY:
				if not _battle.in_battle_tower and not _battle.is_link_battle:
					enemy_seen.emit(int(event["species"]), int(event.get("unown_form", 0)))
				_enemy = int(event["species"])
				_enemy_unown_form = int(event.get("unown_form", 0))
				_enemy_shiny = bool(event.get("shiny", false))
				_enemy_hud_visible = true
				_enemy_level = int(event["level"])
				set_hp(int(event["hp"]), int(event["max_hp"]), _player_hp, _player_max_hp)
			else:
				_player = int(event["species"])
				_player_unown_form = int(event.get("unown_form", 0))
				_player_shiny = bool(event.get("shiny", false))
				_player_hud_visible = true
				_player_level = int(event["level"])
				set_hp(_enemy_hp, _enemy_max_hp, int(event["hp"]), int(event["max_hp"]))
			# A send-out draws a picture through `GetBattleMonBackpic` or
			# `GetEnemyMonFrontpic`, and the doll it would answer with belongs to
			# a Substitute that switching has already taken away.
			_set_substitute_pic(int(event["side"]), false)
			# `wPlayerMinimized` is one of the bytes a send-out zeroes, so the
			# fresh picture is the Pokemon's own however the last one left.
			_set_minimize_pic(int(event["side"]), false)
			_reseed_bg_map()
			_refresh_exp_bar()
		Gen2Battle.EXP_GAINED:
			# Never [constant Gen2Battle.ENEMY]: see the event's own doc comment.
			# [method _refresh_exp_bar] always reads whoever is active right now,
			# which answers correctly on its own even when the index that gained
			# it is a benched participant rather than the one on screen.
			_refresh_exp_bar()
		Gen2Battle.GREW_LEVEL:
			# The level number in the panel belongs to whoever is on screen, so
			# it only moves when the index that grew is the one currently
			# active: a benched participant can level up too, and this screen
			# has no bench to show it on. The bar itself is not recomputed here:
			# `.LoopLevels` is inside `AnimateExpBar`, so from the award until
			# the walk ends the animation owns the bar and [method advance_bars]
			# commits the real count when it arrives.
			if int(event["index"]) == _battle.party(Gen2Battle.PLAYER).active:
				_player_level = int(event["new_level"])
				_push_view()
			if _exp_bar == null:
				_refresh_exp_bar()
			## `SFX_HIT_END_OF_EXP_BAR`, then `WaitSFX`, then the line. Both
			## paths play it: `.LoopLevels` for whoever is out and
			## `.skip_exp_bar_animation` for a benched participant.
			_play_sfx(SFX_HIT_END_OF_EXP_BAR)
			## `.skip_exp_bar_animation` draws the box once per award, after the
			## last level it crossed, so a walk of several levels shows the
			## stats it finished on rather than one box a level.
			if not _more_levels_queued(int(event["index"])):
				_level_up_stats = (event["new_stats"] as Dictionary).duplicate()
			_refresh_level_up_box()


## Every event that reads as one sentence, as the sentence and the arguments it
## takes. An argument is `kind:field`, which [method _line_argument] resolves off
## the event: a battler's name, a move, an item, a species, a type or a number.
const LINES: Dictionary = {
	Gen2Battle.USED_MOVE: ["%s used %s!", &"name:side", &"move:move"],
	Gen2Battle.MISSED: ["%s's attack missed!", &"name:side"],
	Gen2Battle.NO_EFFECT: ["It doesn't affect %s!", &"name:target"],
	Gen2Battle.RECOIL: ["%s is hit with recoil!", &"name:side"],
	Gen2Battle.DRAINED: ["%s sucked health from %s!", &"name:side", &"name:from"],
	Gen2Battle.OHKO: ["It's a one-hit KO!"],
	Gen2Battle.WOKE_UP: ["%s woke up!", &"name:side"],
	# `WasDefrostedText` and `DefrostedOpponentText` are the same line under two
	# names, differing only in whether it is the user or the target that is named.
	Gen2Battle.THAWED: ["%s was defrosted!", &"name:side"],
	Gen2Battle.CONFUSE_INFLICTED: ["%s became confused!", &"name:target"],
	Gen2Battle.CONFUSED: ["%s is confused!", &"name:side"],
	Gen2Battle.SNAPPED_OUT: ["%s snapped out of confusion!", &"name:side"],
	Gen2Battle.HURT_ITSELF: ["It hurt itself in its confusion!"],
	Gen2Battle.STAGES_CLEARED: ["All stat changes were eliminated!"],
	Gen2Battle.STAGES_COPIED: ["%s copied the target's stat changes!", &"name:side"],
	# `PlayStereoCry` prints nothing.
	Gen2Battle.CRY: [""],
	Gen2Battle.EXP_GAINED: [
		"%s gained %d EXP. Points!",
		&"species:species",
		&"int:amount",
	],
	# The cartridge never prints a line of its own for this: it happens silently
	# behind the EXP. Points message above it.
	Gen2Battle.STAT_EXP_GAINED: [""],
	Gen2Battle.GREW_LEVEL: [
		"%s grew to level %d!",
		&"species:species",
		&"int:new_level",
	],
	Gen2Battle.MOVE_LEARNED: ["%s learned %s!", &"species:species", &"move:move"],
	Gen2Battle.MOVE_OFFERED: [
		"%s wants to learn %s!",
		&"species:species",
		&"move:move",
	],
	Gen2Battle.MOVE_FORGOTTEN: [
		"%s forgot %s and learned %s!",
		&"species:species",
		&"move:forgot",
		&"move:learned",
	],
	Gen2Battle.MOVE_DECLINED: [
		"%s did not learn %s.",
		&"species:species",
		&"move:move",
	],
	Gen2Battle.MOVE_FAILED: ["But it failed!"],
	Gen2Battle.BIDE_STORING: ["%s is storing energy!", &"name:side"],
	Gen2Battle.BIDE_UNLEASHED: ["%s unleashed energy!", &"name:side"],
	Gen2Battle.RAGE_BUILDING: ["%s's RAGE is building!", &"name:target"],
	Gen2Battle.FUTURE_SIGHT_SET: ["%s foresaw an attack!", &"name:side"],
	Gen2Battle.FUTURE_SIGHT_HIT: ["%s was hit by FUTURE SIGHT!", &"name:target"],
	Gen2Battle.MIMIC_LEARNED: ["%s learned %s!", &"name:side", &"move:move"],
	Gen2Battle.SKETCHED_MOVE: ["%s SKETCHED %s!", &"name:side", &"move:move"],
	Gen2Battle.TYPE_CHANGED: [
		"%s transformed into the %s-type!",
		&"name:side",
		&"type:type_number",
	],
	Gen2Battle.TYPE_COPIED: ["Converted type to %s's!", &"name:target"],
	Gen2Battle.DISABLE_INFLICTED: [
		"%s's %s was disabled!",
		&"name:target",
		&"move:move",
	],
	Gen2Battle.DISABLE_ENDED: ["%s is disabled no more!", &"name:side"],
	Gen2Battle.ATTRACT_INFLICTED: ["%s fell in love!", &"name:target"],
	Gen2Battle.ENCORE_INFLICTED: ["%s got an encore!", &"name:target"],
	Gen2Battle.ENCORE_ENDED: ["%s's encore ended!", &"name:side"],
	# `EnemyUsedOnText`, one line for all thirteen: the trainer's own name is not in
	# the event, so the class is all this can say.
	Gen2Battle.TRAINER_USED_ITEM: ["Enemy used %s on %s!", &"item:item", &"name:side"],
	Gen2Battle.HP_RESTORED: ["%s regained health!", &"name:side"],
	Gen2Battle.HP_ALREADY_FULL: ["%s's HP is full!", &"name:side"],
	Gen2Battle.WENT_TO_SLEEP: ["%s went to sleep!", &"name:side"],
	Gen2Battle.RESTED: ["%s fell asleep and became healthy!", &"name:side"],
	# `BellChimedText` names nobody, since the bell was heard by a party rather than
	# by a Pokémon.
	Gen2Battle.BELL_CHIMED: ["A bell chimed!"],
	Gen2Battle.NOTHING_HAPPENED: ["But nothing happened."],
	Gen2Battle.MAGNITUDE: ["Magnitude %d!", &"int:magnitude"],
	Gen2Battle.PRESENT_REFUSED: ["%s refused the gift!", &"name:target"],
	Gen2Battle.CRASHED: ["%s kept going and crashed!", &"name:side"],
	Gen2Battle.HURT_BY_SANDSTORM: ["The SANDSTORM hits %s!", &"name:side"],
	Gen2Battle.RECOVERED_WITH_ITEM: [
		"%s recovered with %s.",
		&"name:side",
		&"item:item",
	],
	Gen2Battle.RECOVERED_USING_ITEM: [
		"%s recovered using a %s!",
		&"name:side",
		&"item:item",
	],
	Gen2Battle.RESTORED_PP: ["%s recovered PP using %s.", &"name:side", &"item:item"],
	Gen2Battle.ITEM_HEALED_CONFUSION: [
		"A %s rid %s of its confusion.",
		&"item:item",
		&"name:side",
	],
	Gen2Battle.ITEM_ACTIVATED: ["%s's %s activated!", &"name:side", &"item:item"],
	Gen2Battle.ENDURED: ["%s hung on with %s!", &"name:target", &"item:item"],
	Gen2Battle.PROTECTED_ITSELF: ["%s PROTECTED itself!", &"name:side"],
	Gen2Battle.PROTECTING_ITSELF: ["%s's PROTECTING itself!", &"name:target"],
	Gen2Battle.BRACED_ITSELF: ["%s braced itself!", &"name:side"],
	Gen2Battle.ENDURED_HIT: ["%s ENDURED the hit!", &"name:target"],
	Gen2Battle.DESTINY_BOND_SET: [
		"%s's trying to take its opponent with it!",
		&"name:side",
	],
	Gen2Battle.TOOK_DOWN_WITH_IT: [
		"%s took down with it, %s!",
		&"name:target",
		&"name:side",
	],
	# `DraggedOutText` is `<USER>`, so it names the Pokemon that used the move rather
	# than the one dragged out. Mirrored, not corrected.
	Gen2Battle.DRAGGED_OUT: ["%s was dragged out!", &"name:side"],
	Gen2Battle.FLED_IN_FEAR: ["%s fled in fear!", &"name:target"],
	Gen2Battle.BLOWN_AWAY: ["%s was blown away!", &"name:target"],
	Gen2Battle.FLED_FROM_BATTLE: ["%s fled from battle!", &"name:side"],
	Gen2Battle.IDENTIFIED_SET: ["%s identified %s!", &"name:side", &"name:target"],
	Gen2Battle.TOOK_AIM: ["%s took aim!", &"name:side"],
	Gen2Battle.PP_REDUCED: [
		"%s's %s was reduced by %d!",
		&"name:target",
		&"move:move",
		&"int:amount",
	],
	# SharedPainText names neither Pokemon, since both were levelled.
	Gen2Battle.SHARED_PAIN: ["The battlers shared pain!"],
	Gen2Battle.STOLE_ITEM: ["%s stole %s from its foe!", &"name:side", &"item:item"],
	# BeatUpAttackText names the party member that is swinging, which is only
	# sometimes the Pokemon on the field.
	Gen2Battle.BEAT_UP_ATTACK: ["%s's attack!", &"species:species"],
	Gen2Battle.HURT_BY_TRAP: ["%s's hurt by %s!", &"name:side", &"move:move"],
	Gen2Battle.RELEASED_FROM_TRAP: [
		"%s was released from %s!",
		&"name:side",
		&"move:move",
	],
	Gen2Battle.CANT_ESCAPE_SET: ["%s can't escape now!", &"name:target"],
	Gen2Battle.SWITCH_BLOCKED: ["%s can't be recalled!", &"name:side"],
	Gen2Battle.SAFEGUARD_PROTECTED: ["%s is protected by SAFEGUARD!", &"name:target"],
	# StartPerishText names neither Pokémon, since the song caught both.
	Gen2Battle.PERISH_SONG_STARTED: ["Both #MON will faint in 3 turns!"],
	Gen2Battle.PERISH_COUNT: ["%s's PERISH count is %d!", &"name:side", &"int:count"],
	Gen2Battle.SUBSTITUTE_MADE: ["%s made a SUBSTITUTE!", &"name:side"],
	Gen2Battle.SUBSTITUTE_ALREADY: ["%s has a SUBSTITUTE!", &"name:side"],
	# TooWeakSubText names nobody at all.
	Gen2Battle.SUBSTITUTE_TOO_WEAK: ["Too weak to make a SUBSTITUTE!"],
	Gen2Battle.SUBSTITUTE_TOOK_DAMAGE: [
		"The SUBSTITUTE took damage for %s!",
		&"name:target",
	],
	Gen2Battle.SUBSTITUTE_FADED: ["%s's SUBSTITUTE faded!", &"name:target"],
	Gen2Battle.WAS_SEEDED: ["%s was seeded!", &"name:target"],
	Gen2Battle.LEECH_SEED_SAPPED: ["LEECH SEED saps %s!", &"name:side"],
	Gen2Battle.EVADED: ["%s evaded the attack!", &"name:target"],
	Gen2Battle.NIGHTMARE_STARTED: ["%s started to have a NIGHTMARE!", &"name:target"],
	Gen2Battle.HURT_BY_NIGHTMARE: ["%s has a NIGHTMARE!", &"name:side"],
	# PutACurseText is one text with a paragraph break in it, so the two halves are
	# one line here rather than two events.
	Gen2Battle.CURSE_SET: [
		"%s cut its own HP and put a CURSE on %s!",
		&"name:side",
		&"name:target",
	],
	Gen2Battle.HURT_BY_CURSE: ["%s's hurt by the CURSE!", &"name:side"],
	Gen2Battle.SPIKES_SET: ["SPIKES scattered all around %s!", &"name:target"],
	Gen2Battle.HURT_BY_SPIKES: ["%s's hurt by SPIKES!", &"name:side"],
	Gen2Battle.SHED_LEECH_SEED: ["%s shed LEECH SEED!", &"name:side"],
	Gen2Battle.BLEW_SPIKES: ["%s blew away SPIKES!", &"name:side"],
	Gen2Battle.RELEASED_BY: ["%s was released by %s!", &"name:side", &"name:target"],
	Gen2Battle.MIST_SET: ["%s is shrouded in mist!", &"name:side"],
	Gen2Battle.FOCUS_ENERGY_SET: ["%s is getting pumped!", &"name:side"],
	Gen2Battle.MIST_PROTECTED: ["%s's stat drop was blocked by mist!", &"name:target"],
	Gen2Battle.RUN_FAILED: ["Can't escape!"],
	Gen2Battle.COINS_SCATTERED: ["Coins scattered everywhere!"],
	Gen2Battle.TRANSFORMED: ["%s transformed into %s!", &"name:side", &"name:target"],
}

## The events whose sentence is a branch rather than a template.
const LINE_HANDLERS: Dictionary = {
	Gen2Battle.HIT: &"_hit_text",
	Gen2Battle.HIT_TIMES: &"_hit_times_text",
	Gen2Battle.FAINTED: &"_fainted_text",
	Gen2Battle.CANNOT_MOVE: &"_cannot_move_text",
	Gen2Battle.STATUS_INFLICTED: &"_status_inflicted_text",
	Gen2Battle.HURT_BY_STATUS: &"_hurt_by_status_text",
	Gen2Battle.CHARGING_UP: &"_charging_up_text",
	Gen2Battle.STAT_CHANGED: &"_stat_changed_text",
	Gen2Battle.STAT_CHANGE_FAILED: &"_stat_failed_text",
	Gen2Battle.WITHDREW: &"_withdrew_text",
	Gen2Battle.SENT_OUT: &"_sent_out_text",
	Gen2Battle.WEATHER_STARTED: &"_weather_text",
	Gen2Battle.WEATHER_CONTINUES: &"_weather_text",
	Gen2Battle.WEATHER_ENDED: &"_weather_text",
	Gen2Battle.TRAPPED: &"_trapped_text",
	Gen2Battle.ATTACK_CONTINUES: &"_attack_continues_text",
	Gen2Battle.SCREEN_SET: &"_screen_set_text",
	Gen2Battle.SCREEN_FADED: &"_screen_faded_text",
	Gen2Battle.FLED: &"_fled_text",
	Gen2Battle.RUN_BLOCKED: &"_run_blocked_text",
	Gen2Battle.OVER: &"_over_text",
}

## Which of the three weather tables an event reads.
const WEATHER_TEXT_OF: Dictionary = {
	Gen2Battle.WEATHER_STARTED: WEATHER_STARTED_TEXT,
	Gen2Battle.WEATHER_CONTINUES: WEATHER_CONTINUES_TEXT,
	Gen2Battle.WEATHER_ENDED: WEATHER_ENDED_TEXT,
}


## An event as a sentence, or an empty string for one there is nothing to say
## about. A neutral hit has no line of its own in these games: the bar moving is
## the whole of the message.
func _describe(event: Dictionary) -> String:
	var kind: Variant = event["type"]
	if LINE_HANDLERS.has(kind):
		return String(call(LINE_HANDLERS[kind], event))
	if not LINES.has(kind):
		return ""
	var row: Array = LINES[kind]
	var values: Array = []
	for code: StringName in row.slice(1):
		values.append(_line_argument(code, event))
	if values.is_empty():
		return String(row[0])
	return String(row[0]) % values


## One [constant LINES] argument. Every event carries a side except the one that
## ends the battle, which is about both of them, so a missing side is the player.
func _line_argument(code: StringName, event: Dictionary) -> Variant:
	var parts: PackedStringArray = String(code).split(":")
	var field: String = parts[1]
	match parts[0]:
		"name":
			return _battler_name(int(event.get(field, Gen2Battle.PLAYER)))
		"species":
			return _name_of(int(event[field]))
		"move":
			return String(_data.move(int(event[field])).get("name", ""))
		"item":
			return _data.item_name(int(event[field]))
		"type":
			return _data.type_name(int(event[field]))
	return int(event[field])


func _hit_text(event: Dictionary) -> String:
	if bool(event["critical"]):
		return "A critical hit!"
	if int(event["effectiveness"]) > Gen2Layout.MATCHUP_EFFECTIVE:
		return "It's super effective!"
	if int(event["effectiveness"]) < Gen2Layout.MATCHUP_EFFECTIVE:
		return "It's not very effective..."
	return ""


func _hit_times_text(event: Dictionary) -> String:
	var times: int = int(event["times"])
	return "Hit %d time%s!" % [times, "" if times == 1 else "s"]


## A Nuzlocke faint is a death, and it is said here rather than on the map: this
## is where the player is looking, and the row itself is taken off the party on
## the way out of the fight.
func _fainted_text(event: Dictionary) -> String:
	var side: int = int(event.get("side", Gen2Battle.PLAYER))
	var line: String = "%s fainted!" % _battler_name(side)
	if side == Gen2Battle.PLAYER and _rules().is_nuzlocke():
		line += Gen2TextStream.PAGE_BREAK + Gen2Nuzlocke.death_text(_battler_name(side))
	return line


func _cannot_move_text(event: Dictionary) -> String:
	return "%s %s" % [
		_battler_name(int(event.get("side", Gen2Battle.PLAYER))),
		STOPPED_BY.get(event["reason"], "cannot move!"),
	]


## `_AttackContinuesText`, printed by `.MultiturnMoveCheck` in front of the hit.
func _attack_continues_text(event: Dictionary) -> String:
	return "%s's\nattack continues!" % _battler_name(int(event["side"]))


func _status_inflicted_text(event: Dictionary) -> String:
	return "%s %s" % [
		_battler_name(int(event["target"])), INFLICTED.get(event["name"], "was hurt!"),
	]


func _hurt_by_status_text(event: Dictionary) -> String:
	return "%s is hurt by its %s!" % [
		_battler_name(int(event.get("side", Gen2Battle.PLAYER))), event["name"],
	]


func _charging_up_text(event: Dictionary) -> String:
	return "%s %s" % [
		_battler_name(int(event.get("side", Gen2Battle.PLAYER))),
		CHARGE_TEXT.get(int(event.get("move", 0)), CHARGE_DUG),
	]


## Named out of the event, because by the time this is read the one on the field
## is already the one that came in.
func _withdrew_text(event: Dictionary) -> String:
	if int(event.get("side", Gen2Battle.PLAYER)) == Gen2Battle.ENEMY:
		return "Enemy withdrew %s!" % _name_of(int(event["species"]))
	return "%s, come back!" % _name_of(int(event["species"]))


func _sent_out_text(event: Dictionary) -> String:
	if int(event.get("side", Gen2Battle.PLAYER)) == Gen2Battle.ENEMY:
		return "Enemy sent out %s!" % _name_of(int(event["species"]))
	return SEND_OUT_LINES[
		clampi(int(event.get("line", Gen2Battle.SEND_OUT_GO)), 0, SEND_OUT_LINES.size() - 1)
	] % _name_of(int(event["species"]))


func _weather_text(event: Dictionary) -> String:
	return String((WEATHER_TEXT_OF[event["type"]] as Dictionary).get(
		int(event["weather"]), ""
	))


func _screen_set_text(event: Dictionary) -> String:
	return SCREEN_SET_TEXT.get(int(event["screen"]), "") % _battler_name(
		int(event.get("side", Gen2Battle.PLAYER))
	)


func _screen_faded_text(event: Dictionary) -> String:
	var side: int = int(event.get("side", Gen2Battle.PLAYER))
	var faded: int = int(event["screen"])
	if faded == Gen2Screens.SAFEGUARD:
		return "%s's SAFEGUARD faded!" % _battler_name(side)
	return SCREEN_FADED_TEXT.get(faded, "") % (
		"Enemy #MON" if side == Gen2Battle.ENEMY else "Your #MON"
	)


## BattleText_UserFledUsingAStringBuffer1 is the Smoke Ball's own line; every
## other branch reaches BattleText_GotAwaySafely.
func _fled_text(event: Dictionary) -> String:
	if StringName(event.get("how", &"")) == &"item":
		return "%s fled using a %s!" % [
			_battler_name(Gen2Battle.PLAYER), _data.item_name(int(event.get("item", 0))),
		]
	return "Got away safely!"


func _run_blocked_text(event: Dictionary) -> String:
	if StringName(event.get("reason", &"")) == &"trainer":
		return "No! There's no running from a trainer battle!"
	return "Can't escape!"


## A run is a draw with both parties standing, and the line before this one
## already said so. Both sides can go down in the same turn, through recoil or a
## burn, and then there is nobody to declare.
func _over_text(event: Dictionary) -> String:
	if bool(event.get("fled", false)):
		return ""
	if event["winner"] == null:
		return "Both sides are out of Pokémon!"
	return "%s won!" % ("The enemy" if event["winner"] == Gen2Battle.ENEMY else "Player")


## The sentence a trapping move lands with, which is a per-move line rather than
## one sentence with the move's name in it: `BattleCommand_TrapTarget`'s `.Traps`
## table names five texts, three of which spell the move out and two of which do
## not name it at all. A move number the table does not know cannot happen, since
## those five are the whole of `EFFECT_TRAP_TARGET`.
func _trapped_text(event: Dictionary) -> String:
	var who: String = _battler_name(int(event["target"]))
	var user: String = _battler_name(int(event["side"]))
	match int(event["move"]):
		BIND:
			return "%s used BIND on %s!" % [user, who]
		WRAP:
			return "%s was WRAPPED by %s!" % [who, user]
		CLAMP:
			return "%s was CLAMPED by %s!" % [who, user]
	return "%s was trapped!" % who


## The sentence for a stat that actually moved. Ancientpower's [code]"all"[/code]
## reads as one sentence about the Pokémon rather than five about its stats,
## because that is the one thing the event says that a single stat's does not.
func _stat_changed_text(event: Dictionary) -> String:
	var who: String = _battler_name(int(event["target"]))
	if String(event["stat"]) == "all":
		return "%s's stats rose!" % who

	var stat_name: String = STAT_NAMES.get(event["stat"], String(event["stat"]).to_upper())
	var by: int = int(event["by"])
	if by > 0:
		return "%s's %s went way up!" % [who, stat_name] if by >= 2 \
			else "%s's %s went up!" % [who, stat_name]
	return "%s's %s sharply fell!" % [who, stat_name] if by <= -2 \
		else "%s's %s fell!" % [who, stat_name]


## The sentence for a stat that was already at the end of the line. Whether it
## reads "rise" or "drop" depends only on which end, not on how the move phrases
## itself, because that is the cartridge's own rule.
func _stat_failed_text(event: Dictionary) -> String:
	var who: String = _battler_name(int(event["target"]))
	var stat_name: String = STAT_NAMES.get(event["stat"], String(event["stat"]).to_upper())
	if int(event["by"]) > 0:
		return "%s's %s won't rise anymore!" % [who, stat_name]
	return "%s's %s won't drop anymore!" % [who, stat_name]


## How a battle refers to one of the two, which is by side and not by species:
## the enemy's name is prefixed and the player's is not.
func _battler_name(side: int) -> String:
	if side == Gen2Battle.ENEMY:
		return "Enemy %s" % _name_of(_enemy)
	return _name_of(_player)


## Re-reads both Pokémon. For the paths that change health outside a turn, where
## there is no event to read it out of.
func _read_hp() -> void:
	if _battle == null:
		return
	set_hp(
		_battle.enemy.hp, _battle.enemy.max_hp(),
		_battle.player.hp, _battle.player.max_hp()
	)


## The battle controls first, then the development drivers.
func _unhandled_input(event: InputEvent) -> void:
	if not is_ready() or _driven:
		return
	var button: int = PokeButton.pressed_in(event)
	if button != PokeButton.NONE:
		if _handle_button(button):
			accept_event()
		return
	if event.is_pressed() and _handle_debug_key(event):
		accept_event()
		return
	# A mod's own declared control, before the raw leftovers, exactly as
	# Gen2WorldScreen offers it.
	if _renderer_input_free():
		var action: Dictionary = Gen2ModHost.instance().action_in(event)
		if not action.is_empty():
			Gen2ModHost.instance().emit_action(
				action["id"], action["key"], bool(action["pressed"])
			)
			accept_event()
			return
	# Everything the screen wants has been claimed above, so what reaches here is
	# what a renderer may have a use for. Gen2WorldScreen offers its own renderer
	# the same leftovers for the same reason: a renderer that composes its own
	# shot has to be able to let someone steer it.
	if _renderer_input_free() \
		and Gen2ModHost.renderer_handles_battle_input(_renderer, event):
		accept_event()


## Whether the battle itself is idle enough to pass an event on.
##
## The modal input states are the ones that mean something by themselves: the
## forget-move prompt, a switch's yes/no or list, and ball selection. A draining
## bar, the opening slide and a move animation are deliberately not on that list.
## None of them reads input, and a camera that stops answering every time a bar
## drains is not a camera; the presses they do swallow are swallowed in
## [method _handle_button], which runs first and never reaches here.
func _renderer_input_free() -> bool:
	return is_ready() and _forget_stage == &"" and _switch_stage == &"" \
		and _menu_stage == &"" and not _capture_selecting and not _pack_selecting \
		and not _pack_move_selecting


func _handle_button(button: int) -> bool:
	if _capture_nickname_host != null:
		return _capture_nickname_host.handle_button(button)
	for row: Array in [
		[_forget_stage != &"", _answer_forget],
		[_switch_stage != &"", _answer_switch],
		[_menu_stage != &"", _answer_menu],
	]:
		if bool(row[0]):
			(row[1] as Callable).call(button)
			return true
	for row: Array in _keyed_modals():
		if bool(row[0]):
			return (row[1] as Callable).call(button)
	if button == PokeButton.A:
		advance()
		return true
	return false


## The modal states with a key map of their own, in the order they claim a press.
## A button none of them names is refused rather than falling through to the A
## press below them.
func _keyed_modals() -> Array:
	return [
		[_pack_move_selecting, _button_pack_move],
		[_pack_action_stage != &"", _button_pack_action],
		[_pack_selecting, _button_pack],
		[_capture_selecting, _button_capture],
	]


func _button_pack_move(button: int) -> bool:
	match button:
		PokeButton.RIGHT, PokeButton.DOWN:
			_pack_move_index = posmod(_pack_move_index + 1, _pack_move_slots.size())
			_show_pack_move_selection()
		PokeButton.LEFT, PokeButton.UP:
			_pack_move_index = posmod(_pack_move_index - 1, _pack_move_slots.size())
			_show_pack_move_selection()
		PokeButton.A:
			_use_pack_item(
				_pack_item, _pack_move_target, int(_pack_move_slots[_pack_move_index])
			)
		PokeButton.B:
			_close_pack_move()
			open_battle_pack()
		_:
			return false
	return true


func _button_pack_action(button: int) -> bool:
	match button:
		PokeButton.RIGHT, PokeButton.DOWN:
			_pack_action_index = posmod(_pack_action_index + 1, PACK_ACTIONS.size())
			_reopen_menu_layer()
		PokeButton.LEFT, PokeButton.UP:
			_pack_action_index = posmod(_pack_action_index - 1, PACK_ACTIONS.size())
			_reopen_menu_layer()
		PokeButton.A:
			var over: StringName = _pack_action_stage
			_pack_action_stage = &""
			if _pack_action_index != 0:
				_reopen_menu_layer()
			elif over == &"capture":
				throw_capture_ball()
			else:
				use_selected_pack_item()
		PokeButton.B:
			## `.Quit` is a bare `ret`, so the list the row was chosen from
			## is still standing under the box that just closed.
			_pack_action_stage = &""
			_reopen_menu_layer()
		_:
			return false
	return true


func _button_pack(button: int) -> bool:
	match button:
		PokeButton.RIGHT, PokeButton.DOWN:
			select_pack_row(_pack_index + 1)
		PokeButton.LEFT, PokeButton.UP:
			select_pack_row(_pack_index - 1)
		PokeButton.A:
			## `BattleMenu_Pack.tutorial` discards what `TutorialPack` answered
			## and throws a POKE BALL anyway, so there is no USE submenu.
			if _world_battle_tutorial:
				_pack_selecting = false
				_throw_ball(Gen2WorldPartyHost.ITEM_POKE_BALL, &"pack")
			else:
				_open_pack_action(&"pack")
		PokeButton.B:
			close_battle_pack()
		_:
			return false
	return true


func _button_capture(button: int) -> bool:
	match button:
		PokeButton.RIGHT, PokeButton.DOWN:
			select_capture_ball(_capture_ball_index + 1)
		PokeButton.LEFT, PokeButton.UP:
			select_capture_ball(_capture_ball_index - 1)
		PokeButton.A:
			_open_pack_action(&"capture")
		PokeButton.B:
			_clear_capture_action()
			show_message("Choose an action.")
		_:
			return false
	return true


## Development drivers for a screen with no battle menu: they take a turn, hurt
## a side, switch, run and step through species. Debug builds only, and off the
## keys a button is bound to, so nothing here competes with a real control.
func _handle_debug_key(event: InputEvent) -> bool:
	if not PokeDebugKeys.enabled():
		return false
	var key: InputEventKey = event as InputEventKey
	if key == null:
		return false
	match key.keycode:
		KEY_BRACKETRIGHT:
			next_enemy()
		KEY_BRACKETLEFT:
			next_player()
		KEY_H:
			hurt_enemy()
		KEY_G:
			hurt_player()
		KEY_T:
			take_turn()
		KEY_Y:
			switch_player()
		KEY_R:
			run_from_battle()
		KEY_V:
			cycle_view()
		_:
			return false
	return true


func _wrap_species(number: int) -> int:
	var count: int = _data.species_count() if _data != null else 0
	return wrapi(number, 1, maxi(count, 1) + 1) if count > 0 else 1


## Builds the view for the selected renderer and attaches it to the layer that
## renderer asked for. See [method Gen2WorldScreen._build_renderer], the same
## boundary for the map.
func _build_renderer() -> void:
	if _renderer != null:
		if _screen.native_size_changed.is_connected(_on_native_size_changed):
			_screen.native_size_changed.disconnect(_on_native_size_changed)
		_renderer.get_parent().remove_child(_renderer)
		Gen2Screen.drop(_renderer)
	_renderer = Gen2ModHost.instance().create_battle_renderer()
	## Before the layer is chosen, because the surface's size is what
	## `set_native_size` is about to be told.
	_apply_screen_fill()
	if Gen2ModHost.renderer_uses_hardware_viewport(_renderer):
		_screen.display_content(_renderer)
	else:
		_screen.display_native(_renderer)
		_screen.native_size_changed.connect(_on_native_size_changed)
		_on_native_size_changed(_screen.native_size())
	_renderer_ready = bool(_renderer.set_battle_data(_data))
	_push_world_context()
	_push_view()
	_apply_renderer_interface_style()


## Who fills the buffer SCREEN FILL gave the fight. The built-in arena is
## `_BattleScene`'s own 160x144 and has nothing to put in a wider buffer, so the
## screen fills the surround with the arena's own field. A renderer on the native
## layer, staged on the map the encounter fired on, fills the surface itself and
## the mask would only crop it. The interface does not move either way: panels,
## bars and boxes stay in the rectangle [Gen2Screen] centres in the buffer.
func _apply_screen_fill() -> void:
	_screen.interface_masked = Gen2ModHost.renderer_uses_hardware_viewport(_renderer)


## The text box over a native-layer renderer, the same seam
## [method Gen2WorldScreen._apply_renderer_interface_style] opens on the map: the
## renderer says how opaque the box's field should be and is told where the box
## is, since it is the screen's box and not the renderer's.
func _apply_renderer_interface_style() -> void:
	if _box == null:
		return
	_box.field_opacity = Gen2ModHost.renderer_interface_opacity(_renderer)
	_push_text_box_rect()
	## The annotation field is the same interface over the same renderer, so it
	## is repainted with the box rather than left at the last renderer's opacity.
	_annotations_drawn = ""
	_refresh_annotations()


func _push_text_box_rect() -> void:
	if _box == null:
		return
	Gen2ModHost.renderer_set_text_box_rect(_renderer, _box.occupied_rect())


## Hands the renderer where the battle is being fought, when the caller supplied
## it and the renderer asked for it. After set_battle_data() and before the first
## view, so a renderer that builds the place once has it before it draws; a
## renderer swapped in mid-battle gets it again here.
func _push_world_context() -> void:
	if not _renderer_ready or _world_context == null:
		return
	if _renderer.has_method(Gen2ModHost.RENDERER_WORLD_CONTEXT_METHOD):
		_renderer.call(Gen2ModHost.RENDERER_WORLD_CONTEXT_METHOD, _world_context)


func _on_native_size_changed(size_pixels: Vector2i) -> void:
	if _renderer != null and _renderer.has_method(Gen2ModHost.RENDERER_RESIZE_METHOD):
		_renderer.call(Gen2ModHost.RENDERER_RESIZE_METHOD, size_pixels)
	Gen2ModHost.renderer_set_screen_rect(_renderer, _screen.screen_rect())


## Switches the live view without disturbing the battle behind it. The same one
## choice the overworld makes: see [method Gen2WorldScreen.select_view].
func select_view(id: StringName) -> Dictionary:
	var result: Dictionary = Gen2ModHost.instance().select_view(id)
	if not bool(result.get("ok", false)):
		_report_view("Renderer unavailable: %s" % String(result.get("reason", "unknown")))
		return result
	_report_view("Renderer: %s" % Gen2ModHost.instance().view_label(id))
	return result


## Says what a view switch did, unless a menu is holding the interface.
##
## The acknowledgement is battle text, and the menu layer above it covers the
## box's right-hand half rather than the whole panel, so a line printed under an
## open menu leaks its first glyphs out beside the list. The cartridge's own
## transition cover already says the switch happened; the words are development
## chrome and are worth less than the menu underneath them staying intact. Said
## through the same log the refusals use, so nothing is silently dropped.
func _report_view(message: String) -> void:
	if _menu_owns_interface():
		print_verbose(message)
		return
	show_message(message)


## Whether one of the interface's own menus is on screen and holding the lower
## panel. Not the same question as [method _annotations_visible], which is about
## the cells a full-screen subflow takes: the main and move menus own the panel
## a battle message would print into while leaving the annotations correct.
func _menu_owns_interface() -> bool:
	return _menu_stage != &"" or _switch_stage != &"" or _forget_stage != &"" \
		or _pack_selecting or _pack_move_selecting or _capture_selecting


## The same one switch the overworld takes: see
## [method Gen2WorldScreen._on_view_changed].
func _on_view_changed(_id: StringName) -> void:
	_screen.play_view_cover(_build_renderer)


func cycle_view() -> Dictionary:
	var host: Gen2ModHost = Gen2ModHost.instance()
	var ids: Array[StringName] = host.view_ids()
	if ids.size() < 2:
		_report_view("No other renderer is registered")
		return {"ok": false, "reason": &"single_renderer"}
	var at: int = ids.find(host.selected_view())
	return select_view(ids[posmod(at + 1, ids.size())])


func _battle_kind() -> StringName:
	return &"trainer" if _battle != null and _battle.is_trainer_battle else &"wild"


func _enemy_trainer_name() -> String:
	var named: String = String(_world_battle_request.get("trainer_name", ""))
	if not named.is_empty():
		return named
	if _enemy_trainer_class <= 0 or _data == null:
		return ""
	return String(_data.trainer_party(_enemy_trainer_class, _enemy_trainer_index).get("name", ""))


## `BlkPacket_Battle`'s message box block names palette 2, so the box a
## Generation 1 battle prints in wears the player's own Pokemon's colours.
func _push_gen1_text_palette() -> void:
	if _box == null or _data == null or _data.generation != RomRegistry.GEN1:
		return
	## A renderer of a mod's own that does not answer leaves it white and black.
	if _renderer == null or not _renderer.has_method("gen1_screen_palette"):
		return
	_box.palette = _renderer.gen1_screen_palette(
		Gen2BattleRenderer.GEN1_PAL_PLAYER_MON
	)


## Pushes the current display values to the renderer. Plain values only, never
## the battle engine: a turn resolves at once and is then shown an event at a
## time, so what is drawn deliberately lags where the battle has got to.
func _push_view() -> void:
	_update_low_health_alarm()
	if not _renderer_ready:
		return
	_push_gen1_text_palette()
	_renderer.set_view({
		"enemy_species": _enemy, "player_species": _player,
		"enemy_unown_form": _enemy_unown_form,
		"player_unown_form": _player_unown_form,
		"enemy_shiny": _enemy_shiny,
		"player_shiny": _player_shiny,
		## Whose picture is the substitute's doll rather than the Pokémon's own.
		"enemy_substitute": bool(_substitute_pic[Gen2Battle.ENEMY]),
		"player_substitute": bool(_substitute_pic[Gen2Battle.PLAYER]),
		## And whose is the dot `GetMinimizePic` draws, which a doll stands in
		## front of for as long as one is up.
		"enemy_minimized": bool(_minimize_pic[Gen2Battle.ENEMY]),
		"player_minimized": bool(_minimize_pic[Gen2Battle.PLAYER]),
		"enemy_name": _name_of(_enemy), "player_name": _name_of(_player),
		"enemy_level": _enemy_level, "player_level": _player_level,
		## Who the fight is against, which the values above do not say. A wild
		## battle carries class 0 and an empty name, the way `wOtherTrainerClass`
		## is zero there; a class is what `GameData.trainer_pic()` and
		## `trainer_name()` take, so a renderer standing the opponent on the field
		## draws the cartridge's own picture of them.
		"battle_kind": _battle_kind(),
		"trainer_class": _enemy_trainer_class,
		"trainer_index": _enemy_trainer_index,
		"trainer_name": _enemy_trainer_name(),
		## The bars draw whatever the animation is on rather than the committed
		## HP, which is what makes them drain. Everything else, including
		## [method battle_snapshot], keeps reading the committed value.
		"enemy_hp": _drawn_hp(Gen2Battle.ENEMY), "enemy_max_hp": _enemy_max_hp,
		"player_hp": _drawn_hp(Gen2Battle.PLAYER), "player_max_hp": _player_max_hp,
		"exp_pixels": _drawn_exp(),
		## The background's own scroll, a value per scanline, empty when it is
		## sitting still.
		"raster_scx": _raster_offsets(),
		"raster_scy": _raster_rows(),
		## `CopyBackpic` puts the player's back pic on the tilemap before
		## `InitBattleDisplay` ever reaches the slide, so it is there through it
		## and comes in with the middle band. Its top three tile rows fall in the
		## band the enemy scrolls, which is what the eighteen sprites here are
		## for; `PlaceGraphic` afterwards is what settles the two pixels between
		## them.
		"intro_sprites": _intro.sprites() if _intro != null else [],
		## `GetSGBLayout SCGB_BATTLE_GRAYSCALE` is called where the battle is
		## entered and `SCGB_BATTLE_COLORS` only after `BattleIntroSlidingPics`,
		## so a battle slides in with no colour at all and gains it on the frame
		## the slide ends.
		"grayscale": _intro != null,
		## Which picture each square is holding and which panel is on the map.
		## Both change several times while a battle is opening: see
		## [method _build_entrance].
		"enemy_trainer_pic": _enemy_trainer_pic,
		"player_backpic": _player_backpic,
		"player_backpic_palette": "kris" if player_is_female() else "chris",
		"enemy_hud_visible": _enemy_hud_visible \
			and _anim_hud_hidden != Gen2Battle.ENEMY,
		"player_hud_visible": _player_hud_visible \
			and _anim_hud_hidden != Gen2Battle.PLAYER,
		## `DrawEnemyHUDBorder`'s last line, which leaves on `wBattleMode`: only
		## a wild battle marks a species the Pokedex already holds.
		"enemy_caught": _enemy_caught_before and _is_wild_battle(),
		## `BattleStart_TrainerHuds`' party balls and the frame they hang in.
		"trainer_hud_balls": _hud_balls,
		"trainer_hud_border": _hud_border,
		## `wTilemap` and the video state an animation writes over it. The
		## running animation's own copy is the live one: `RunBattleAnimScript`
		## hands the tilemap in and takes it back out, and every effect that
		## blanks, sinks or resizes a picture edits it a frame at a time, so a
		## view given the screen's copy meanwhile watched an animation happen to
		## a picture that never moved.
		"bg_map": _anim.background().bg_map if _anim != null else _bg_map,
		"bg_vbank1": _bg_vbank1,
		"bg_palette_maps": _background_maps(&"bg"),
		"ob_palette_maps": _background_maps(&"ob"),
		"anim_sprites": _anim.sprites() if _anim != null else _kept_sprites,
		"anim_tiles": _anim.tiles() if _anim != null else _kept_tiles,
		## Whether both panels are on the map, which is the summary of the two
		## keys above rather than a third state.
		"hud_visible": _hud_visible(),
		## Who is standing on each square, whether the picture is on it, how far
		## it is from resting there and how big it is drawn: see
		## [method battler_side].
		"battlers": {
			"player": battler_side(Gen2Battle.PLAYER),
			"enemy": battler_side(Gen2Battle.ENEMY),
		},
	})
	if _box != null:
		_box.raster_scx = _box_raster_offsets()
	## Every state change a provider could annotate reaches this, so the layer is
	## refreshed here rather than at each of the twenty callers: a turn, a switch,
	## Haze, a Baton Pass and a weather change are all one push.
	_refresh_annotations()


## What is standing on one side's square, whether it is on it, how far it is from
## resting there and how big it is drawn; `docs/MODS.md` documents the block.
## Every other battler field says it in the terms the hardware draws it in, so a
## renderer with no background plane would have to rebuild host state to read a
## faint, a recall or a deformation. These four are read out of the state the
## screen already runs rather than simulated again.
func battler_side(side: int) -> Dictionary:
	var player_side: bool = side == Gen2Battle.PLAYER
	var backpic: String = _player_backpic if player_side else ""
	var trainer_class: int = 0 if player_side else _enemy_trainer_pic
	var species: int = _player if player_side else _enemy
	var person: bool = not backpic.is_empty() if player_side else trainer_class > 0
	var offset: float = 0.0
	var kind: StringName = &"mon"
	if _intro != null:
		# Both squares are sliding in. A wild opponent is its own front pic
		# rather than a trainer, and slides in exactly the same way.
		offset = _intro.player_offset() if player_side else _intro.enemy_offset()
		kind = &"trainer" if person else &"mon"
	elif person:
		offset = float(_slid_pixels[side])
		var walked: float = float(
			int(Gen2BattleScreenMap.SLIDE_STEPS[player_side]) * PokeTiles.TILE_WIDTH
		)
		kind = &"none" if absf(offset) >= walked else &"trainer"
	return {
		"kind": kind,
		## Empty and zero on the side and in the state they do not describe: the
		## player is named by a back pic and the opponent by a class number, and
		## neither is on the square once a Pokemon has taken it.
		"backpic": backpic if kind == &"trainer" else "",
		"trainer_class": trainer_class if kind == &"trainer" else 0,
		"species": species if kind == &"mon" else 0,
		"visible": bool(_battler_visible[side]),
		"offset_pixels": Vector2(offset, 0.0) + Vector2(_battler_shift[side]) \
			+ _faint_offset(side) + _window_offset(player_side),
		"scale": Vector2.ONE * float(_battler_scale[side]),
	}


## `MonFaintedAnimation`'s outer loop, which takes the block's rows from the row
## above: seven steps of one tile row each, so the picture sinks a tile a step.
func _faint_offset(side: int) -> Vector2:
	for faint: Dictionary in _faints:
		var player_side: bool = side == Gen2Battle.PLAYER
		if bool(faint["player_side"]) != player_side:
			continue
		return Vector2(0.0, float(int(faint["step"]) * PokeTiles.TILE_HEIGHT))
	return Vector2.ZERO


## The scanline window over one side's own rows, which is how every per-battler
## deformation moves a picture; [method Gen2BattleAnimBackground.battler_window_offset]
## owns the reading and this is the frame it is asked on.
func _window_offset(player_side: bool) -> Vector2:
	if _anim == null:
		return Vector2.ZERO
	return _anim.background().battler_window_offset(player_side)


## The background scroll for the whole screen: the intro's own bands, or an
## animation's `hSCX` plus whatever its scanline table is writing over it.
func _raster_offsets() -> PackedInt32Array:
	if _intro != null:
		return _intro.offsets()
	return _anim_raster(Gen2BattleAnimBackground.LCDC_SCX)


## The same vertically, which only an animation ever asks for: `hSCY` and a
## scanline table pointed at `rSCY`.
func _raster_rows() -> PackedInt32Array:
	return _anim_raster(Gen2BattleAnimBackground.LCDC_SCY)


## One axis of the animation's scroll, per scanline.
##
## The whole-screen `hSCX`/`hSCY` is the base, and the scanline table replaces it
## on every line while `hLCDCPointer` names that axis' register. A table pointed
## at `rBGP` reaches nothing here: `UpdatePals` never touches that register on the
## Color hardware, which is the branch this project builds.
func _anim_raster(register: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if _anim == null:
		return out
	var background: Gen2BattleAnimBackground = _anim.background()
	var base: int = background.scx if register == Gen2BattleAnimBackground.LCDC_SCX \
		else background.scy
	var windowed: bool = background.lcdc_pointer == register
	if base == 0 and not windowed:
		return out
	out.resize(Gen2BattleAnimBackground.SCREEN_LINES)
	for line: int in Gen2BattleAnimBackground.SCREEN_LINES:
		out[line] = int(background.ly_overrides[line]) if windowed else base
	return out


## The eight DMG bytes `BattleAnimRequestPals` left on one set of palettes, or
## the identity permutation while no animation is running.
func _background_maps(kind: StringName) -> PackedByteArray:
	if _anim != null:
		var background: Gen2BattleAnimBackground = _anim.background()
		return background.bg_palette_maps if kind == &"bg" else background.ob_palette_maps
	var out: PackedByteArray = PackedByteArray()
	out.resize(Gen2BattleAnimBackground.PALETTE_COUNT)
	out.fill(Gen2BattleAnimBackground.PALETTE_IDENTITY)
	return out


## The same scroll, narrowed to the rows the text box occupies. A box is drawn
## into the background plane like everything else, so `Textbox`'s own rows move
## with whatever moves the plane.
func _box_raster_offsets() -> PackedInt32Array:
	if _intro == null:
		return PackedInt32Array()
	var top: int = Gen2TextBox.STANDARD_TOP * Gen2Font.TILE
	return _intro.offsets().slice(top, top + _box.rows * Gen2Font.TILE)


## The Pokemon `wContestMon` already holds, which is what
## `DisplayAlreadyCaughtText` names and the comparison's STOCK box shows.
func _contest_stock_name() -> String:
	return _name_of(int(_capture_result.get("stock_species", 0)))


func _name_of(species: int) -> String:
	return String(_data.species(species).get("name", ""))


## `.PrintBattleStartText`'s four lines, chosen by `wBattleType` in its order.
## BATTLETYPE_CELEBI takes `WildCelebiAppearedText`, which is
## `WildPokemonAppearedText` written a second time.
func _announce() -> void:
	var wild: String = _name_of(_enemy)
	match _battle.battle_type if _battle != null else Gen2Battle.BATTLETYPE_NORMAL:
		Gen2Battle.BATTLETYPE_FISH:
			show_message("The hooked\n%s\nattacked!" % wild)
		Gen2Battle.BATTLETYPE_TREE:
			show_message("%s fell\nout of the tree!" % wild)
		_:
			show_message("Wild %s\nappeared!" % wild)
