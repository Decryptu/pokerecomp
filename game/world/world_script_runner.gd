class_name Gen2WorldScriptRunner
extends RefCounted

## Bounded, scene-free execution of the supported overworld script commands.
##
## A runner owns one event invocation. It never opens a ROM and it never
## changes the world state until the invocation reaches END or ENDCALLBACK.
## Text and explicit warps are returned as structured pauses for the screen or
## another caller to acknowledge.

var data: GameData = null
var state: Gen2WorldState = null
var warp_validator: Callable = Callable()

var _request: Dictionary = {}
var _frames: Array = []
var _staged_flags: Dictionary = {}
var _staged_engine_flags: Dictionary = {}
var _staged_scenes: Dictionary = {}
var _staged_day_of_week: int = -1
var _staged_dst_enabled: bool = false
var _has_staged_dst: bool = false
var _staged_items: Dictionary = {}
var _staged_money: Dictionary = {}
var _staged_coins: int = -1
var _staged_phone_contacts: Dictionary = {}
var _staged_script_memory: Dictionary = {}
var _staged_just_battled: bool = false
var _has_staged_just_battled: bool = false
var _staged_swarm: Dictionary = {}
var _has_staged_swarm: bool = false
var _has_staged_special_phone_call: bool = false
var _staged_special_phone_call: int = 0
var _has_staged_kurt_apricorn_quantity: bool = false
var _staged_kurt_apricorn_quantity: int = 0
var _staged_fruit_trees: Dictionary = {}
## `wTradeFlags`, and the audio steps `TradedForText` owes before the last box.
var _staged_npc_trades: Dictionary = {}
var _npc_trade_after_sound: Dictionary = {}
var _has_staged_kenji_break_timer: bool = false
var _staged_kenji_break_timer: int = 0
var _has_staged_lucky_number_days_left: bool = false
var _staged_lucky_number_days_left: int = 0
## `LoadOrRegenerateLuckyIDNumber` rolls today's number where it is first read,
## so a runner that reaches one of the three lucky-number specials draws it and
## stages the pair the way the source writes both SRAM bytes at once.
var _has_staged_lucky_id_number: bool = false
var _staged_lucky_id_number: int = 0
var _staged_lucky_number_day: int = 0
var _staged_caught_species: Dictionary = {}
var _staged_best_magikarp: Dictionary = {}
var _staged_blue_card_balance: int = -1
## `wBT_OTTrainer`, which `LoadOpponentTrainerAndPokemon` fills and both
## `BattleTowerBattle` and `battletowertext` read back.
var _battle_tower_opponent: Dictionary = {}
## `wBT_TrainerTextIndex`, the personality the greeting rolled. -1 until one has.
var _battle_tower_text_index: int = -1
var _staged_mom_savings_flags: int = -1
## `SFX_TRANSACTION` and the `WaitSFX` behind it, which stand between the
## transfer and the box that reports it.
var _bank_of_mom_after_sound: int = -1
var _mom_receipt_box: String = ""
var _reset_phone_receive_timer: bool = false
var _events: Array = []
var _pending: Dictionary = {}
var _last_text: Dictionary = {}

## The text the still-open box is showing. `Script_yesorno`'s `YesNoBox` and
## `Script_verticalmenu`'s `_2DMenu` draw over that box rather than replacing it,
## so the question a choice answers is the last text the script wrote; without it
## a host has nothing but the command's own name to print.
var _standing_text: String = ""
var _last_talked_object_index: int = Gen2WorldObject.NONE_INDEX
var _last_item: int = 0
var _staged_warp: Dictionary = {}
var _script_value: int = 0
var _command_count: int = 0
## `RunScriptCommand`'s own artefact: every command executed, with the
## `bank:address` the cartridge would have in wScriptBank:wScriptPos when it
## ran. Collected only while `trace_commands` is on, which
## `tools/trace_world_script.gd` turns on for every runner a world builds so a
## walked conversation can be diffed against `.claude/oracle/overworld/
## trace_script.py`'s reading of the same one.
static var trace_commands: bool = false
var command_trace: Array[Dictionary] = []
## `Script_sdefer`'s own `RUN_DEFERRED_SCRIPT`, which is the only thing that
## makes `RunSceneScript` answer `PlayerEvents` with carry: a scene script that
## does not set it has run and raised no player event
## (engine/overworld/events.asm).
var _ran_deferred: bool = false
var _active: bool = false
var _completed: bool = false
var _failure: Dictionary = {}
var _finish_after_pending: bool = false
var _loaded_menu: Dictionary = {}
var _loaded_emote: int = -1
## wScriptDelay. `Script_pause` reuses whatever is in it when its own operand is
## zero, which is how `Script_showemote` sets the emote's duration: it writes the
## delay and then calls `ShowEmoteScript`, whose middle command is `pause 0`.
var _script_delay: int = 0
var _trainer_intro_approach_pending: bool = false
## Set while RockSmashScript's `playsound SFX_STRENGTH` is out with the host, so
## its acknowledge continues into the earthquake, the disappear and the roll.
## The same shape _trainer_intro_approach_pending has for encounter music.
var _rock_smash_after_sound: bool = false
## Set while a receipt's own `specialsound` is out with the host, so its
## completion continues into `itemnotify`'s box. `{ item, finish }`, the same
## shape _rock_smash_after_sound has.
var _item_notify_after_sound: Dictionary = {}
var _battle_setup: Dictionary = {}
var _loaded_battle_type: int = -1
var _phone_context: Dictionary = {}
var _phone_started: bool = false
var _text_buffers: Dictionary = {}
## The WRAM buffers a deferred routine fills that are not string buffers: the
## Magikarp record holder's name and the Poke Seer's five. Keyed by address so
## they reach `TextCommand_RAM` through the same map the string buffers do.
var _text_ram: Dictionary = {}
var _rival_name: String = "???"
## wPlayerName, mirrored from the selected save the way Gen2WorldAPI mirrors
## wPlayerID. `<PLAYER>` is a `CheckDict` entry, so a text carrying one cannot
## be printed without it; empty leaves the marker visible rather than inventing
## a trainer.
var player_name: String = ""
## Everything this invocation rolls: the source RANDOM command and the phone
## routines that pick a caller line or an unseen species. Injected like the rest
## of the project's randomness, so a caller can reproduce a branch; a runner
## started without one randomizes its own rather than reaching for the engine's
## global generator, which no seed can reach.
var _random := RandomNumberGenerator.new()
## wCurPartySpecies, which is not wScriptVar: `PartyMenuSelect` writes it from
## the row the player chose and `pokepic`, `givepoke` and `giveegg` from their
## own operands. `PlayCurMonCry` is the one special that reads it, and all four
## of its scripts reach it with a grooming routine's own wScriptVar standing.
var _cur_party_species: int = 0
## Which balance window `engine/menus/menu_2.asm` left standing, empty for none.
var _money_window: StringName = &""

const PIKACHU: int = 25
const PIKACHU_DEBUG_LEVEL: int = 5

const PHONE_RARE_ROLL_ATTEMPTS: int = 128
const PHONE_CONTACT_GOT: int = 0
const PHONE_CONTACTS_FULL: int = 1
const PHONE_CONTACT_REFUSED: int = 2
## Mystery Gift's whole script surface (`engine/link/mystery_gift.asm`). The
## exchange itself is not a special: it happens at the main menu with no file
## loaded, and what a script can reach is the gift it left behind.
const SPECIAL_CHECK_MYSTERY_GIFT: int = 17
const SPECIAL_GET_MYSTERY_GIFT_ITEM: int = 18
const SPECIAL_UNLOCK_MYSTERY_GIFT: int = 19
## The Bug Catching Contest's own six, all below the index where Gold and
## Silver's table diverges except the contestant draw, which special_index()
## normalizes (engine/events/special_pointers.asm).
const SPECIAL_BUG_CONTEST_JUDGING: int = 20
const SPECIAL_CHECK_PARTY_FULL_AFTER_CONTEST: int = 21
const SPECIAL_CONTEST_DROP_OFF_MONS: int = 22
const SPECIAL_CONTEST_RETURN_MONS: int = 23
## `WarpToSpawnPoint`, which clears `STATUSFLAGS2_SAFARI_GAME_F` and
## `STATUSFLAGS2_BUG_CONTEST_TIMER_F` and does no warping at all. The four
## escape scripts that call it are the port's own
## ([method Gen2WorldAPI.warp_to_spawn_point]); this is the entry a decoded
## script reaches it by.
const SPECIAL_WARP_TO_SPAWN_POINT: int = 0
const SPECIAL_GIVE_PARK_BALLS: int = 24
const SPECIAL_SELECT_RANDOM_BUG_CONTESTANTS: int = 71
const SPECIAL_ACTIVATE_FISHING_SWARM: int = 72
const SPECIAL_TOGGLE_MAPTILE_DECORATIONS: int = 73
const SPECIAL_TOGGLE_DECORATIONS_VISIBILITY: int = 74
const SPECIAL_POKEMON_CENTER_PC: int = 28
const SPECIAL_PLAYERS_HOUSE_PC: int = 29
## OverworldTownMap, engine/events/special_pointers.asm index 38. The source
## describedecoration path reaches this special only for a town-map poster.
const SPECIAL_OVERWORLD_TOWN_MAP: int = 38
const SPECIAL_SET_DAY_OF_WEEK: int = 37
const SPECIAL_PLAY_MAP_MUSIC: int = 60
const SPECIAL_RESTART_MAP_MUSIC: int = 61
const SPECIAL_HEAL_MACHINE_ANIM: int = 62
## `HealMachineAnim.Pointers`' three sequences. Only the Hall of Fame's differs:
## it loads its balls from a second OAM table and plays two effects where the
## other two play `MUSIC_HEAL`. The routine's own frame costs belong to the
## animation, so they are read from the class that draws it.
const HEAL_MACHINE_HALL_OF_FAME: int = Gen2WorldEffects.HEAL_MACHINE_HALL_OF_FAME
const HEAL_MACHINE_BALL_FRAMES: int = Gen2WorldEffects.HEAL_MACHINE_BALL_FRAMES
const HEAL_MACHINE_FLASH_FRAMES: int = Gen2WorldEffects.HEAL_MACHINE_FLASHES \
	* Gen2WorldEffects.HEAL_MACHINE_FLASH_INTERVAL
## constants/sfx_constants.asm. The first is played once a ball by
## `.LoadBallsOntoMachine`; the other two are `.HOF_PlaySFX`'s pair.
const SFX_SECOND_PART_OF_ITEMFINDER: int = 0x12
## `ItemFinder.ItemfinderSound`'s other half, and `PlayTransactionSound`'s.
const SFX_TRANSACTION: int = 0x22
## `.ItemfinderSound`'s own `ld c, 4`.
const ITEMFINDER_SFX_PASSES: int = 4
const SFX_GAME_FREAK_LOGO_GS: int = 0xAA
const SFX_BOOT_PC: int = 0x0D
## constants/music_constants.asm's MUSIC_HEAL, which `.PlayHealMusic` starts
## under the flashes rather than after them.
const MUSIC_HEAL: int = 0x0D
const SPECIAL_CHECK_POKERUS: int = 78
## MagnetTrain, the ride's cutscene. wScriptVar picks the direction, which a
## preceding SETVAL loads: TRUE for Saffron to Goldenrod, FALSE for the return
## (maps/SaffronMagnetTrainStation.asm, maps/GoldenrodMagnetTrainStation.asm).
const SPECIAL_MAGNET_TRAIN: int = 35
## ProfOaksPCBoot, 101 in Crystal and 100 in Gold/Silver, which special_index()
## already normalizes. Oak's Kanto script reaches it on every branch
## (maps/OaksLab.asm's `.CheckPokedex`).
const SPECIAL_PROF_OAKS_PC_BOOT: int = 101
## SnorlaxAwake, 96 in Crystal and 95 in Gold/Silver, which special_index()
## already normalizes. Its five proximity coordinates are the cells the source
## lists, in its own x,y order (engine/events/specials.asm's .ProximityCoords),
## and are the same in both pins.
const SPECIAL_SNORLAX_AWAKE: int = 96
const SNORLAX_PROXIMITY_CELLS: Array[Vector2i] = [
	Vector2i(33, 8), Vector2i(34, 10), Vector2i(35, 10), Vector2i(36, 8), Vector2i(36, 9),
]
## SelectApricornForKurt, 86 in Crystal and 85 in Gold/Silver, which
## special_index() already normalizes. maps/KurtsHouse.asm's `.AskApricorn`
## branches on wScriptVar afterwards, one label per apricorn.
const SPECIAL_SELECT_APRICORN_FOR_KURT: int = 86
## MoveDeletion, 33 in both profiles: it sits below the first index the two tables
## disagree on, so `special_index()` leaves it alone, and it owns the same shape
## `NameRater` does one house further on. Below, the Battle Tower's own six
## specials, Crystal's alone: `BattleTowerAction` is one routine reached with a
## `setval` in front of it, two of them are the menus the receptionist opens, one
## samples the next opponent and one fights it, and `CheckForBattleTowerRules` is
## the party check in front of the whole challenge.
const SPECIAL_BATTLE_TOWER_ROOM_MENU: int = 116
const SPECIAL_BATTLE_TOWER_BATTLE: int = 119
const SPECIAL_LOAD_BATTLE_TOWER_OPPONENT: int = 122
const SPECIAL_CHECK_BATTLE_TOWER_RULES: int = 124
const SPECIAL_BATTLE_TOWER_ACTION: int = 134
const SPECIAL_CHALLENGE_MENU: int = 136
## `TryQuickSave`, which the challenge asks for before it starts, and `Reset`,
## `home/init.asm`'s own soft reset of the console. Both are in the link block of
## `SpecialsPointers` and neither is link play: the tower is the only thing in
## either corpus that reaches them.
const SPECIAL_TRY_QUICK_SAVE: int = 4
const SPECIAL_RESET: int = 126

## The cable club's own block of `SpecialsPointers`, in index order. Three
## scripts reach it: the trade and battle receptionists on POKECENTER_2F, which
## share one shape, and the Time Capsule's, which asks for no room at all. The
## last three are the rooms themselves, reached from the console each one is
## built around, and `CableClubCheckWhichChris` is the callback that decides
## which of the two identical friends is standing in it.
const SPECIAL_SET_BITS_FOR_LINK_TRADE_REQUEST: int = 1
const SPECIAL_WAIT_FOR_LINKED_FRIEND: int = 2
const SPECIAL_CHECK_LINK_TIMEOUT_RECEPTIONIST: int = 3
const SPECIAL_CHECK_BOTH_SELECTED_SAME_ROOM: int = 5
const SPECIAL_FAILED_LINK_TO_PAST: int = 6
const SPECIAL_CLOSE_LINK: int = 7
const SPECIAL_WAIT_FOR_OTHER_PLAYER_TO_EXIT: int = 8
const SPECIAL_SET_BITS_FOR_BATTLE_REQUEST: int = 9
const SPECIAL_SET_BITS_FOR_TIME_CAPSULE_REQUEST: int = 10
const SPECIAL_CHECK_TIME_CAPSULE_COMPATIBILITY: int = 11
const SPECIAL_ENTER_TIME_CAPSULE: int = 12
const SPECIAL_TRADE_CENTER: int = 13
const SPECIAL_COLOSSEUM: int = 14
const SPECIAL_TIME_CAPSULE: int = 15
const SPECIAL_CABLE_CLUB_CHECK_WHICH_CHRIS: int = 16
## `DisplayLinkRecord`, the sign beside the three receptionists. It is in the
## same block and it is not link play: it reads `sLinkBattleStats` and draws it,
## which is one page over a save field the link battle writes.
const SPECIAL_DISPLAY_LINK_RECORD: int = 88
## `CheckMobileAdapterStatusSpecial`, which both Crystal receptionists ask before
## anything else. It is the Mobile Adapter's, and its FALSE is what reaches the
## cable club: a script that cannot answer it stops in front of the whole room.
const SPECIAL_CHECK_MOBILE_ADAPTER_STATUS: int = 160
## Which `wLinkMode` each room's console writes on the way into
## `LinkCommunications`.
const LINK_ROOM_MODES: Dictionary = {
	SPECIAL_TRADE_CENTER: Gen2LinkSession.LINK_TRADECENTER,
	SPECIAL_COLOSSEUM: Gen2LinkSession.LINK_COLOSSEUM,
	SPECIAL_TIME_CAPSULE: Gen2LinkSession.LINK_TIMECAPSULE,
}
## `Menu_ChallengeExplanationCancel`'s own answers: the three rows are 1 to 3 and
## B is 4, which is why `Script_Menu_ChallengeExplanationCancel` tests only 1 and
## 2 and treats everything else as leaving.
const CHALLENGE_MENU_CHALLENGE: int = 1
const CHALLENGE_MENU_EXPLANATION: int = 2
const CHALLENGE_MENU_CANCEL: int = 4
## What `special BattleTowerRoomMenu` leaves in wScriptVar: zero for a chosen
## room, `$a` for a cancelled menu. `Script_ChooseChallenge` branches on both and
## treats anything else as the mobile error it cannot reach here.
const ROOM_MENU_CHOSEN: int = 0
const ROOM_MENU_CANCELLED: int = 0x0A
## `wcd49`, which `BattleTower_UbersCheck` copies the offending member's name
## into and `Text_UberRestriction` prints as `text_ram`.
const BATTLE_TOWER_NAME_BUFFER: int = 0xCD49
## `wNrOfBeatenBattleTowerTrainers`, the WRAM copy the room script `readmem`s
## after each win.
const BEATEN_TRAINERS_ADDRESS: int = 0xCF64

const SPECIAL_MOVE_DELETION: int = 33
## MoveTutor, 131, Crystal's alone: pokegold's SpecialsPointers has no row for
## it and no Gold or Silver script reaches one. `MoveTutor` owns the party list
## `ChooseMonToLearnTMHM` opens and the `.loop` behind it, so the whole routine
## is one host request; the map script reads wScriptVar afterwards.
const SPECIAL_MOVE_TUTOR: int = 131
## The Day-Care's five, all below the first index the two tables disagree on, so
## `special_index()` leaves them alone. `DayCareMan` and `DayCareLady` are the
## deposit and withdrawal counters; `DayCareManOutside` is the man who brings the
## egg out and the only one of the five that writes wScriptVar, which its map
## script branches on; `DayCareMon1` and `DayCareMon2` are the two signs inside,
## each a line, a cry and the pair's compatibility.
const SPECIAL_DAY_CARE_MAN: int = 30
const SPECIAL_DAY_CARE_LADY: int = 31
const SPECIAL_DAY_CARE_MAN_OUTSIDE: int = 32
const SPECIAL_DAY_CARE_MON_1: int = 69
const SPECIAL_DAY_CARE_MON_2: int = 70
## Which routine each index opens, in the request the host answers.
const DAY_CARE_ROLE_OF: Dictionary = {
	SPECIAL_DAY_CARE_MAN: &"man",
	SPECIAL_DAY_CARE_LADY: &"lady",
	SPECIAL_DAY_CARE_MAN_OUTSIDE: &"outside",
	SPECIAL_DAY_CARE_MON_1: &"mon1",
	SPECIAL_DAY_CARE_MON_2: &"mon2",
}

## NameRater, 87 in Crystal and 86 in Gold/Silver, which special_index()
## already normalizes. `_NameRater` owns its own texts, its two `YesNoBox`es and
## the party list `SelectMonFromParty` opens, so the whole routine is one host
## request; the map script's own `waitbutton` follows it.
const SPECIAL_NAME_RATER: int = 87
## `engine/events/haircut.asm`'s four routines, each of them
## `SelectMonFromParty` and then a read. `BillsGrandfather` answers the chosen
## member's *species*, since it names it with `GetPokemonName`; the three
## grooming routines answer `HappinessData_*`'s own row and name the member with
## `GetCurNickname`.
const SPECIAL_BILLS_GRANDFATHER: int = 77
const SPECIAL_OLDER_HAIRCUT_BROTHER: int = 97
const SPECIAL_YOUNGER_HAIRCUT_BROTHER: int = 98
const SPECIAL_DAISYS_GROOMING: int = 99
## Which `HappinessData_*` table each of the three walks.
const GROOMING_TABLE_OF: Dictionary = {
	SPECIAL_OLDER_HAIRCUT_BROTHER: &"older_haircut",
	SPECIAL_YOUNGER_HAIRCUT_BROTHER: &"younger_haircut",
	SPECIAL_DAISYS_GROOMING: &"grooming",
}
## `EGG`, which `HaircutOrGrooming` answers 1 for rather than grooming.
const SPECIES_EGG: int = 0xFD

## `constants/script_constants.asm`'s YOUR_MONEY, the account every
## `PlaceMoneyTextbox` prints and the one `checkmoney`/`takemoney` default to.
const ACCOUNT_YOUR_MONEY: int = 0

## The three balance windows of `engine/menus/menu_2.asm`. Each writes the
## tilemap and returns, so the box stands over the map until `closetext`
## redraws it, which is the same lifetime `Script_pokepic`'s box has.
const SPECIAL_DISPLAY_COIN_CASE_BALANCE: int = 79
const SPECIAL_DISPLAY_MONEY_AND_COIN_BALANCE: int = 80
const SPECIAL_PLACE_MONEY_TOP_RIGHT: int = 81
const MONEY_WINDOW_KIND_OF: Dictionary = {
	SPECIAL_DISPLAY_COIN_CASE_BALANCE: &"coin_case",
	SPECIAL_DISPLAY_MONEY_AND_COIN_BALANCE: &"money_and_coins",
	SPECIAL_PLACE_MONEY_TOP_RIGHT: &"money_top_right",
}

## DisplayUnownWords, Crystal's alone: pokegold's table stops well before it and
## neither dump ships the words. The four wall patterns are Crystal bg events, two
## per chamber, where Gold and Silver's cells carry only the puzzle sign. Not to be
## read as 41, which is `UnownPuzzle` on both. That one is the sliding puzzle each
## chamber opens, its `setval` naming the picture and its answer read by the
## `iftrue`; 42 is `SlotMachine`, whose `setval` is what `Slots_InitBias` reads,
## TRUE picking `.Lucky`'s own bias table. Both are under `special_index`'s split.
const SPECIAL_SLOT_MACHINE: int = 42
## `CardFlip`, the Game Corner's other machine. Both Game Corners reach it and
## neither puts a `setval` in front of it: the routine reads no `wScriptVar` and
## writes none, so the request carries the coins alone. 43 on both profiles,
## being under `special_index`'s split.
const SPECIAL_CARD_FLIP: int = 43
const SPECIAL_UNOWN_PUZZLE: int = 41
const SPECIAL_DISPLAY_UNOWN_WORDS: int = 135
const SPECIAL_RANDOM_UNSEEN_WILD_MON: int = 91
const SPECIAL_RANDOM_PHONE_WILD_MON: int = 92
const SPECIAL_RANDOM_PHONE_MON: int = 93
const SPECIAL_INITIAL_SET_DST_FLAG: int = 166
const SPECIAL_INITIAL_CLEAR_DST_FLAG: int = 167
const SPECIAL_FADE_OUT_MUSIC: int = 106
const SPECIAL_INIT_ROAM_MONS: int = 105
## The five map fades. `BattleTowerFade` is Crystal's own insertion at 47, which
## is why the four either side of it need no profile split.
const SPECIAL_FADE_OUT_TO_WHITE: int = 46
const SPECIAL_BATTLE_TOWER_FADE: int = 47
const SPECIAL_FADE_OUT_TO_BLACK: int = 48
const SPECIAL_FADE_IN_FROM_WHITE: int = 49
const SPECIAL_FADE_IN_FROM_BLACK: int = 50
## Which four rows of `.cgbfade` each of them walks, and in which direction.
const FADE_ORDERS_OF: Dictionary = {
	SPECIAL_FADE_OUT_TO_WHITE: Gen2WorldPalette.FADE_OUT_ORDERS,
	SPECIAL_BATTLE_TOWER_FADE: Gen2WorldPalette.FADE_OUT_ORDERS,
	SPECIAL_FADE_IN_FROM_WHITE: Gen2WorldPalette.FADE_IN_ORDERS,
	SPECIAL_FADE_OUT_TO_BLACK: Gen2WorldPalette.FADE_TO_BLACK_ORDERS,
	SPECIAL_FADE_IN_FROM_BLACK: Gen2WorldPalette.FADE_FROM_BLACK_ORDERS,
}
## `FillWhiteBGColor` runs in front of the two fades that end white and nowhere
## else, so the way to black flattens onto the map's own colour 0.
const FADE_WHITE_FILL_SPECIALS: Array[int] = [
	SPECIAL_FADE_OUT_TO_WHITE, SPECIAL_BATTLE_TOWER_FADE,
]
## `GameboyCheck`'s three answers (`constants/misc_constants.asm`). Every screen
## here is drawn in the CGB palettes, so `hCGB` is set and the other two are
## unreachable.
const GBCHECK_CGB: int = 2
## `BeastsCheck`'s three, in the order it asks about them.
const BEAST_SPECIES: Array[int] = [243, 244, 245]
## StrengthBoulderScript's index in StdScripts (engine/events/std_scripts.asm),
## the same 14 in both pins despite the tables being 52 and 46 long. Every
## boulder object in every map reaches Strength through `jumpstd` on it.
const STD_STRENGTH_BOULDER: int = 14
## SmashRockScript's index, directly after the boulder's and the same 15 in both
## pins. Every rock object in every map reaches Rock Smash through `jumpstd` on
## it, exactly as every boulder reaches Strength through 14.
const STD_SMASH_ROCK: int = 15
## TryStrengthOW's three wScriptVar answers. `.already_using` names the branch
## taken when `bit` sets Z, that is when the flag is still *clear*, so 0 is the
## value that asks and 2 the value that reports the flag already set.
const STRENGTH_OW_ASK: int = 0
const STRENGTH_OW_UNABLE: int = 1
const STRENGTH_OW_ALREADY_ACTIVE: int = 2
## data/text/common_2.asm. Synthesized rather than decoded because the script
## that shows them is reached only through `callasm`, which has no runner; see
## _stage_strength_boulder().
const STRENGTH_ASK_TEXT: String = \
	"A #MON may be\nable to move this." + Gen2TextStream.PAGE_BREAK \
	+ "Want to use\nSTRENGTH?"
const STRENGTH_MAY_MOVE_TEXT: String = "A #MON may be\nable to move this."
const STRENGTH_BOULDERS_MOVE_TEXT: String = "Boulders may now\nbe moved!"
## data/text/common_2.asm again, for AskRockSmashScript. `HasRockSmash` answers
## 1 when CheckPartyMove fails, which is the `ifequal 1, .no` that reaches
## _MaySmashText; anything else asks.
const ROCK_SMASH_ASK_TEXT: String = \
	"This rock looks\nbreakable." + Gen2TextStream.PAGE_BREAK \
	+ "Want to use ROCK\nSMASH?"
const ROCK_SMASH_MAY_SMASH_TEXT: String = "Maybe a #MON\ncan break this."
const ROCK_SMASH_EARTHQUAKE: int = 84
static var ROCK_SMASH_MOVEMENT: PackedByteArray = PackedByteArray([0x57, 10, 0x47])
## constants/sfx_constants.asm, whose comment column is hex. RockSmashScript
## plays the boulder's own sound rather than one of its own.
const SFX_STRENGTH: int = 0x1B

## `TradeTexts`' five rows.
const TRADE_DIALOG_INTRO: int = 0
const TRADE_DIALOG_CANCEL: int = 1
const TRADE_DIALOG_WRONG: int = 2
const TRADE_DIALOG_COMPLETE: int = 3
const TRADE_DIALOG_AFTER: int = 4
## `GetTradeMonNames`' tail, written over the name's terminator when the row
## asks for a gender. TRADE_GENDER_EITHER writes nothing.
const TRADE_GENDER_SYMBOLS: Dictionary = {
	RomLayout.TRADE_GENDER_MALE: "\u2642", RomLayout.TRADE_GENDER_FEMALE: "\u2640",
}
## `TradedForText`'s own tail in order: the `PlayMusic MUSIC_NONE` its `text_asm`
## spends, the `sound_dex_fanfare_80_109` behind it, and the `RestartMapMusic`
## `NPCTrade` runs before the last box. The movie leaves MUSIC_EVOLUTION playing.
const TRADE_AFTER_TEXT_AUDIO: Array[Array] = [
	[&"music", {"address": 0}],
	[&"sound", {"address": 0x0A}],
	[&"map_music", {"restart": true}],
]

## data/text/common_2.asm, for the five Ask*Scripts TryTileCollisionEvent
## reaches. Synthesized rather than decoded for the reason AskStrengthScript's
## are: each is reached through `CallScript` on a link-time address, so there is
## no pointer in the pins to follow. All five are byte identical between them.
const CUT_ASK_TEXT: String = "This tree can be\nCUT!" \
	+ Gen2TextStream.PAGE_BREAK + "Want to use CUT?"
const CUT_CAN_TEXT: String = "This tree can be\nCUT!"
const SURF_ASK_TEXT: String = "The water is calm.\nWant to SURF?"
const WHIRLPOOL_ASK_TEXT: String = \
	"A whirlpool is in\nthe way." + Gen2TextStream.PAGE_BREAK \
	+ "Want to use\nWHIRLPOOL?"
const WHIRLPOOL_MAY_PASS_TEXT: String = \
	"It's a vicious\nwhirlpool!" + Gen2TextStream.PAGE_BREAK \
	+ "A #MON may be\nable to pass it."
const WATERFALL_ASK_TEXT: String = "Do you want to use\nWATERFALL?"
const WATERFALL_HUGE_TEXT: String = "Wow, it's a huge\nwaterfall."
const HEADBUTT_ASK_TEXT: String = \
	"A #MON could be\nin this tree." + Gen2TextStream.PAGE_BREAK \
	+ "Want to HEADBUTT\nit?"
## A field-move prompt has no source address to push a frame at, since
## CallScript's operand is a link-time one the pins do not resolve. The bare
## `end` frame still has to sit in the CPU's switchable window for _push_frame,
## so it is put at its base; nothing ever reads the address back.
const FIELD_MOVE_PROMPT_FRAME: int = RomFile.BANK_SIZE
## A mod's item gift has no source address either, and for a stronger reason: no
## script anywhere gives that item. Shares the base for the reason above.
const ITEM_GIFT_FRAME: int = RomFile.BANK_SIZE
## data/text/common_2.asm's _FoundItemText, less its <PLAYER>; see
## _stage_item_ball(). The source line break sits before the item name.
const FOUND_ITEM_TEXT: String = "Found\n%s!"
## Two source boxes, so four lines and no blank between them: the box is two
## rows, and a blank line would spend a third page drawing nothing.
const NO_SPACE_ITEM_TEXT: String = "Found\n%s!\nBut you have\nno space left."
## data/text/common_2.asm's `_ReceivedItemText`, `_PutItemInPocketText` and
## `_PocketIsFullText`, each less its `<PLAYER>` for the reason FOUND_ITEM_TEXT
## drops it: nothing writes `wPlayerName` yet. `GiveItemScript` prints the first
## two around every `verbosegiveitem`, and `itemnotify` the second on its own.
const RECEIVED_ITEM_TEXT: String = "Received\n%s."
## The pocket line's own `cont` is a scroll rather than a page, so the item it
## names is still on screen above it.
const PUT_ITEM_TEXT: String = "Put the\n%s in" + Gen2TextStream.SCROLL_BREAK + "the %s."
const POCKET_FULL_TEXT: String = "The %s\nis full…"
## constants/sfx_constants.asm. `FindItemInBallScript` plays SFX_ITEM by name
## rather than through `specialsound`, so a TM lying in a ball gets the ordinary
## item jingle and the same TM handed over by an NPC gets SFX_GET_TM.
const SFX_ITEM: int = 0x01
## data/text/common_1.asm's four fruit tree texts, paired the same way.
## `_HeyItsFruitText` and `_ObtainedFruitText` are one staged text because the
## source's `giveitem` sits between them and has nothing to show; they still
## paginate into the two boxes the cartridge draws.
const FRUIT_TREE_TEXT: String = "It's a fruit-\nbearing tree."
const FRUIT_TREE_EMPTY_TEXT: String = "There's nothing\nhere…"
const FRUIT_TREE_OBTAINED_TEXT: String = "Hey! It's\n%s!\nObtained\n%s!"
const FRUIT_TREE_FULL_TEXT: String = "Hey! It's\n%s!\nBut the PACK is\nfull…"
## The `disappear LAST_TALKED` operand (constants/map_object_constants.asm).
const LAST_TALKED: int = 0xFE
## PLAYER and the first `object_const_def` id.
const PLAYER_OBJECT_ID: int = 0
const FIRST_MAP_OBJECT_ID: int = 2
## wBattleResult, which startbattle copies into wScriptVar
## (constants/battle_constants.asm).
const BATTLE_RESULT_WIN: int = 0
const BATTLE_RESULT_LOSE: int = 1
const BATTLE_RESULT_DRAW: int = 2
const TEXT_STRING_BUFFER: int = 0x14
## The two waits `ScriptEvents` spends frames in rather than asking for anything
## (`engine/overworld/scripting.asm`). WAIT_MOVEMENT is SCRIPT_WAIT_MOVEMENT,
## which runs until the stream an `applymovement` started clears
## SCRIPTED_MOVEMENT_STATE_F; WAIT_FRAMES is the counted delay `Script_pause`,
## `Script_wait` and `Script_deactivatefacing` spend. Neither takes a button, so
## both resolve through complete_wait() rather than through advance().
const WAIT_MOVEMENT: StringName = &"movement"
const WAIT_FRAMES: StringName = &"frames"
## `Script_pause` delays `DelayFrames 2` per counted unit and `Script_wait`
## delays six.
const PAUSE_FRAMES_PER_UNIT: int = 2
const WAIT_FRAMES_PER_UNIT: int = 6
## `SetDayOfWeek.WeekdayStrings`, padded the way the source pads them so the
## name is centred in its nine-wide box. One list, in [Gen2ClockSetScreen],
## because the dial that draws it is shared with `InitClock`.
const WEEKDAY_NAMES: Array[String] = Gen2ClockSetScreen.DAYS

## Crystal event flags used by the player's room decoration callbacks. The
## importer keeps raw cartridge flag numbers, so these values match the
## source event flag table rather than a project-local enum.
const EVENT_TEMPORARY_UNTIL_MAP_RELOAD_8: int = 7
const EVENT_PLAYERS_ROOM_POSTER: int = 716
const EVENT_PLAYERS_HOUSE_2F_CONSOLE: int = 1857
const EVENT_PLAYERS_HOUSE_2F_DOLL_1: int = 1858
const EVENT_PLAYERS_HOUSE_2F_DOLL_2: int = 1859
const EVENT_PLAYERS_HOUSE_2F_BIG_DOLL: int = 1860
## `engine/events/unown_walls.asm`'s two `special` chambers. Crystal's alone: the
## other two are farcalled from field-move code rather than reached by a script,
## so they live with the moves that open them (Gen2WorldAPI.unown_wall_event).
const EVENT_WALL_OPENED_IN_HO_OH_CHAMBER: int = 806
const EVENT_WALL_OPENED_IN_OMANYTE_CHAMBER: int = 808

## The species and items the deferred routines name, by their own constants.
const SPECIES_HO_OH: int = 250
const ITEM_WATER_STONE: int = 24

## `engine/events/specials.asm` and the routines behind it, the second group of
## `tools/checks/specials.gd`'s deferred list.
const SPECIAL_CHECK_MAGIKARP_LENGTH: int = 25
const SPECIAL_MAGIKARP_HOUSE_SIGN: int = 26
const SPECIAL_BANK_OF_MOM: int = 34
const SPECIAL_UNOWN_PRINTER: int = 39
const SPECIAL_MAP_RADIO: int = 40
## `constants/script_constants.asm`'s MOMS_MONEY, the account her bank holds.
const ACCOUNT_MOMS_MONEY: int = 1
## `ram_constants.asm`'s wMomSavingMoney. Bit 7 is whether the bank has ever
## been opened; the low three are how much of a battle prize she keeps, and only
## MOM_SAVING_SOME_MONEY is ever written, since that is the one tier her menu
## offers. [method Gen2Battle.prize_money_split] is what spends the tier.
const MOM_ACTIVE: int = 1 << 7
const MOM_SAVING_SOME_MONEY: int = 1 << 0
const MOM_SAVING_MONEY_MASK: int = 0b111
## `BankOfMom.dw`, the jumptable this routine walks. `wJumptableIndex` is the
## whole of its state, so each index below is one staged box, menu or dial and
## the loop around `.RunJumptable` is the chain of them.
const MOM_CHECK_INITIALIZED: int = 0
const MOM_INITIALIZE: int = 1
const MOM_IS_THIS_ABOUT_YOUR_MONEY: int = 2
const MOM_ACCESS_BANK: int = 3
const MOM_STORE_MONEY: int = 4
const MOM_TAKE_MONEY: int = 5
const MOM_STOP_OR_START_SAVING: int = 6
const MOM_JUST_DO_WHAT_YOU_CAN: int = 7
## `.AskDST`, which sets JUMPTABLE_EXIT_F and asks nothing: `DSTChecks` is
## reached from `.IsThisAboutYourMoney` instead.
const MOM_EXIT: int = 8
## `BankOfMom_MenuHeader.MenuData`'s four rows and the index each reaches.
const MOM_MENU_ROWS: Array[String] = ["GET", "SAVE", "CHANGE", "CANCEL"]
const MOM_MENU_TARGETS: Array[int] = [
	MOM_TAKE_MONEY, MOM_STORE_MONEY, MOM_STOP_OR_START_SAVING, MOM_JUST_DO_WHAT_YOU_CAN,
]
## Which way `Mom_WithdrawDepositMenuJoypad`'s dial moves the money, named by
## the model that draws it rather than a second time here.
const MOM_DIAL_DEPOSIT: StringName = Gen2WorldMoneyDial.MODE_DEPOSIT
const MOM_DIAL_WITHDRAW: StringName = Gen2WorldMoneyDial.MODE_WITHDRAW
const SPECIAL_GAME_CORNER_PRIZE_MON_CHECK_DEX: int = 57
const SPECIAL_GIVE_SHUCKLE: int = 75
const SPECIAL_RETURN_SHUCKIE: int = 76
const SPECIAL_CHECK_FOR_LUCKY_NUMBER_WINNERS: int = 82
const SPECIAL_CHECK_LUCKY_NUMBER_SHOW_FLAG: int = 83
const SPECIAL_RESET_LUCKY_NUMBER_SHOW_FLAG: int = 84
const SPECIAL_PRINT_TODAYS_LUCKY_NUMBER: int = 85
const SPECIAL_TRAINER_HOUSE: int = 103
const SPECIAL_PHOTO_STUDIO: int = 104
const SPECIAL_DIPLOMA: int = 107
const SPECIAL_PRINT_DIPLOMA: int = 108
## `_GiveOddEgg`. The special itself sits in the mobile bank, but nothing in it
## is mobile: `DayCareManScript_Inside` calls it and the routine reads a ROM
## table and appends a party member.
const SPECIAL_GIVE_ODD_EGG: int = 125
## `AskRememberPassword`. In the mobile bank beside `GiveOddEgg` and no more
## mobile than it is: `Buena` in RadioTower2F calls it to ask whether the player
## remembers today's password, and the routine is a yes/no box in a corner.
const SPECIAL_ASK_REMEMBER_PASSWORD: int = 163
## `.DoMenu`'s `lb bc, 14, 7` with `YesNoMenuHeader`'s own width and height
## added, which puts the box in the bottom-right rather than the standard
## `menu_coords 10, 5, 15, 9`.
const ASK_REMEMBER_PASSWORD_BOX: Dictionary = {
	"default": 1, "left": 14, "top": 7, "right": 19, "bottom": 11,
}
## `ld c, 15 / call DelayFrames` and `Buena_ExitMenu`'s own `DelayFrame`, spent
## after the answer and before the script reads it.
const ASK_REMEMBER_PASSWORD_CLOSE_FRAMES: int = 16
## `EGG_TICKET`, which `_GiveOddEgg` tosses one of on its way past. The
## international cartridges ship no way to hold one, so the toss is a no-op
## every time a player reaches it.
const ITEM_EGG_TICKET: int = 81
const SPECIAL_OMANYTE_CHAMBER: int = 132
const SPECIAL_HO_OH_CHAMBER: int = 141
const SPECIAL_CELEBI_SHRINE_EVENT: int = 143
const SPECIAL_CHECK_CAUGHT_CELEBI: int = 144
const SPECIAL_POKE_SEER: int = 145
const SPECIAL_BUENAS_PASSWORD: int = 146
const SPECIAL_BUENA_PRIZE: int = 147
const SPECIAL_GIVE_DRATINI: int = 148
const SPECIAL_SAMPLE_KENJI_BREAK_COUNTDOWN: int = 149
## The three routines whose whole body is `SelectMonFromParty` and a branch on
## what came back, by the name `_finish_party_selection` reads them under.
const PARTY_SELECTION_ROUTINE_OF: Dictionary = {
	SPECIAL_CHECK_MAGIKARP_LENGTH: &"magikarp_length",
	SPECIAL_PHOTO_STUDIO: &"photo_studio",
	SPECIAL_RETURN_SHUCKIE: &"return_shuckie",
	SPECIAL_POKE_SEER: &"poke_seer",
}
## What each of them writes to wScriptVar when the list is backed out of. The
## four grooming routines and the Photo Studio all answer zero, which is the
## default; the other two name their own refusal.
const PARTY_SELECTION_REFUSAL_OF: Dictionary = {
	&"magikarp_length": Gen2WorldPartyHost.MAGIKARPLENGTH_REFUSED,
	&"return_shuckie": Gen2WorldPartyHost.SHUCKIE_REFUSED,
	&"check_poke_mail": Gen2WorldPartyHost.POKEMAIL_REFUSED,
}

## `CelebiShrineEvent`'s own loop: `ld a, 160` into wFrameCounter and
## `ld c, 2 / call DelayFrames` per pass, so the cutscene stands for twice its
## own counter. There is no sprite-anim layer outside the intro, so what it owes
## a script is the wait and the battle type it leaves behind.
## `engine/events/poke_seer.asm`'s own readings.
const SEER_UNKNOWN: String = "Unknown"
const SEER_TIMES: Array[String] = ["Morning", "Day", "Night"]
## `CAUGHT_EGG_LEVEL` and the level `EGG_LEVEL` says an egg hatches at, which is
## what the Seer prints for a row stamped with the egg marker.
const SEER_CAUGHT_EGG_LEVEL: int = 1
const SEER_EGG_LEVEL: int = 5
const SEER_LANDMARK_EVENT: int = 0x7F
## `SeerAdviceTexts`, the levels gained since the catch and the box each band
## reaches. The last row is the first one again, which is what a wrapped
## subtraction lands on.
const SEER_ADVICE: Array = [
	[9, "more_care"], [29, "more_confident"], [59, "much_strength"],
	[89, "mighty"], [100, "impressed"], [255, "more_care"],
]

const CELEBI_SHRINE_PASSES: int = 160
const CELEBI_SHRINE_FRAMES_PER_PASS: int = 2
const VARIABLE_SPRITE_BASE: int = 0xF0


static func begin(
	game_data: GameData,
	world_state: Gen2WorldState,
	request: Dictionary,
	validator: Callable = Callable(),
	random: RandomNumberGenerator = null,
) -> Gen2WorldScriptRunner:
	var runner := Gen2WorldScriptRunner.new()
	runner.data = game_data
	runner.state = world_state
	runner.warp_validator = validator
	runner._request = request.duplicate(true)
	runner._phone_context = request.get("phone", {}).duplicate(true)
	if random != null:
		runner._random = random
	else:
		runner._random.randomize()
	runner._reset_phone_receive_timer = bool(request.get("reset_receive_timer", false))
	runner._last_talked_object_index = int(
		request.get("object_index", Gen2WorldObject.NONE_INDEX)
	)
	runner._last_item = int(request.get("item", 0))
	runner.player_name = String(request.get("player_name", ""))
	var bank: int = int(request.get("bank", 0))
	var address: int = int(request.get("script", request.get("address", 0)))
	var trainer_phase: StringName = StringName(request.get("trainer_phase", &""))
	var trainer: Variant = request.get("trainer", {})
	var started: bool = false
	if not trainer_phase.is_empty():
		## LoadTrainer_continue clears wRunningTrainerBattleScript for every
		## trainer encounter, talked to or seen (home/trainers.asm), and only
		## StartBattleWithMapTrainerScript's `loadmem wRunningTrainerBattleScript,
		## -1` sets it again. Without this the flag committed by one battle
		## outlives it, so `endifjustbattled` ends the after-battle script on
		## every later conversation and nothing past that command ever runs. The
		## Rocket hideout's two password grunts are the first place on the walked
		## route where that content is load bearing.
		runner._stage_just_battled(false)
	if trainer_phase == &"initial" and trainer is Dictionary:
		started = runner._push_frame(
			bank, address, runner._trainer_intro_script(trainer as Dictionary)
		)
		## Only SeenByTrainerScript shows the shock emote and walks the trainer
		## over; TalkToTrainerScript is faceplayer, the flag check and
		## encountermusic, then the same StartBattleWithMapTrainerScript
		## (engine/events/trainer_scripts.asm). A sight request is the one that
		## carries the direction the trainer saw along, so it is the one that
		## approaches.
		runner._trainer_intro_approach_pending = request.get("direction", Vector2i.ZERO) \
			in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	elif StringName(request.get("kind", &"")) == &"field_move_prompt":
		## TryTileCollisionEvent's five field-move branches each reach an
		## Ask*Script through CallScript on a link-time address, so there is no
		## pointer to push and the frame that stands in for one is a bare `end`,
		## exactly as an item ball's is.
		started = runner._push_frame(
			bank, FIELD_MOVE_PROMPT_FRAME, PackedByteArray([
				Gen2WorldScript.raw_opcode(Gen2WorldScript.GOLD_END, runner._crystal_commands())
			])
		)
		if started:
			runner._stage_field_move_prompt()
	elif StringName(request.get("kind", &"")) == &"item_gift":
		## A mod's ask through [method Gen2ModHost.request_item_gift]. There is
		## no script behind it at all, not even two bytes of data, so the frame
		## is the same bare `end` an item ball's is and the staging call is
		## `verbosegiveitem` with nothing in front of it.
		started = runner._push_frame(bank, ITEM_GIFT_FRAME, PackedByteArray([
			Gen2WorldScript.raw_opcode(Gen2WorldScript.GOLD_END, runner._crystal_commands())
		]))
		if started:
			runner._stage_item_gift()
	elif StringName(request.get("kind", &"")) in [&"item_ball", &"hidden_item"]:
		## Neither pointer is code, so the frame that stands in for it is a bare
		## `end` and the staging call replays FindItemInBallScript or
		## HiddenItemScript.
		started = runner._push_frame(bank, address, PackedByteArray([
			Gen2WorldScript.raw_opcode(Gen2WorldScript.GOLD_END, runner._crystal_commands())
		]))
		if started:
			if StringName(request.get("kind", &"")) == &"item_ball":
				runner._stage_item_ball()
			else:
				runner._stage_hidden_item()
	else:
		started = runner._push_frame(bank, address)
		## A label inside another script has no pointer of its own, so a caller
		## that resolved one names the script containing it and how far in it
		## starts. `WateredWeirdTreeScript` is the only one.
		var offset: int = int(request.get("offset", 0))
		if started and offset > 0:
			var frame: Dictionary = runner._frames[runner._frames.size() - 1]
			if offset >= (frame["data"] as PackedByteArray).size():
				started = false
			else:
				frame["offset"] = offset
				runner._frames[runner._frames.size() - 1] = frame
	if not started:
		runner._fail(&"missing_script", {"bank": bank, "address": address})
	else:
		runner._active = true
	return runner


## `_pending`'s type and `special` tag to the method that resumes it, taking the
## caller's choice and answering a result. A pause with no row here gets the
## generic answer in [method _resume_pending].
const PENDING_RESUMES: Dictionary = {
	&"menu/set_day_of_week": &"_resume_day_of_week_menu",
	&"menu/battle_tower_challenge_menu": &"_resume_challenge_menu",
	&"menu/battle_tower_room_menu": &"_resolve_room_menu",
	&"text/battle_tower_room_refusal": &"_resume_room_refusal",
	&"menu/buenas_password": &"_resume_buenas_password",
	&"text/set_day_of_week_confirmation": &"_resume_day_of_week_text",
	&"choice/set_day_of_week_confirmation": &"_resume_day_of_week_choice",
	&"text/strength_ask": &"_resume_strength_ask_text",
	&"choice/strength_ask": &"_resume_strength_ask_choice",
	&"text/fruit_tree": &"_resume_fruit_tree",
	&"text/item_received": &"_resume_item_received",
	&"text/pocket_is_full": &"_resume_pocket_is_full",
	&"text/strength_used": &"_resume_strength_used",
	&"menu/buena_prize": &"_resume_buena_prize_menu",
	&"choice/buena_prize_confirm": &"_resume_buena_prize_confirm",
	&"menu/bank_of_mom_menu": &"_resume_mom_menu",
	&"choice/bank_of_mom_choice": &"_resume_mom_choice",
	&"text/field_move_ask": &"_resume_field_move_text",
	&"choice/field_move_ask": &"_resume_field_move_choice",
	&"choice/ask_remember_password": &"_resume_remember_password",
	&"text/rock_smash_ask": &"_resume_rock_smash_text",
	&"choice/rock_smash_ask": &"_resume_rock_smash_choice",
	&"text/rock_smash_used": &"_resume_rock_smash_used",
	&"choice/npc_trade_intro": &"_resume_trade_intro",
}

## The continuations that carry their payload in a `_pending` key rather than a
## tag, in the order a pause carrying two of them is resumed.
const PENDING_CONTINUATIONS: Dictionary = {
	"next_internal_texts": &"_resume_internal_texts",
	"bank_of_mom_after_text": &"_resume_mom_after_text",
	"bank_of_mom_dial": &"_resume_mom_dial",
	"buena_prize_after_text": &"_resume_buena_after_text",
	"party_selection_after_text": &"_resume_party_selection",
	"special_after_text": &"_resume_special_after_text",
	"npc_trade_after_cable": &"_resume_trade_cable",
	"npc_trade_after_traded": &"_resume_trade_traded",
}


## Advances until a text/button pause, completion or a bounded failure.
func advance(acknowledge: bool = false, choice: int = -1) -> Dictionary:
	if not _phone_context.is_empty() and not _phone_started:
		_phone_started = true
		_emit_runtime_event(&"phone_call_started", _phone_context)
	if _pending:
		var resumed: Dictionary = _resume_pending(acknowledge, choice)
		if not resumed.is_empty():
			return resumed
	if not _active:
		return _failure_result() if not _failure.is_empty() else _complete_result()

	while _active:
		if _command_count >= Gen2WorldScript.MAX_COMMANDS:
			return _fail(&"command_limit", {"limit": Gen2WorldScript.MAX_COMMANDS})
		if _frames.is_empty():
			return _complete()

		var frame: Dictionary = _frames[_frames.size() - 1]
		var command: Dictionary = Gen2WorldScript.command_at(
			frame["data"], int(frame["offset"]), _crystal_commands()
		)
		if not bool(command.get("ok", false)):
			return _fail(StringName(command.get("reason", &"invalid_command")), command)
		if trace_commands:
			command_trace.append({
				"bank": int(frame["bank"]),
				"address": int(frame["address"]) + int(frame["offset"]),
				"opcode": int(command["opcode"]),
				"name": String(command["name"]),
			})
		frame["offset"] = int(frame["offset"]) + int(command["width"])
		_frames[_frames.size() - 1] = frame
		_command_count += 1

		var outcome: Dictionary = _execute(command, frame)
		if not bool(outcome.get("ok", true)):
			return _fail(StringName(outcome.get("reason", &"script_failed")), outcome)
		if _pending:
			## As below: a command with a waiting result of its own has drained
			## the events, and a second loses them. `faceplayer` before a `trade`
			## or a `special BankOfMom` is the visible half.
			return outcome if outcome.has("status") else _waiting_result()
		if _completed:
			## A terminal command returns _complete()'s own result, which has
			## already drained the events; asking for a second one would hand the
			## caller an empty list in its place.
			return outcome if outcome.has("status") else _complete_result()

	return _complete()


## The open pause's own answer to [param acknowledge] and [param choice], or an
## empty result when it is spent and the command loop takes over.
func _resume_pending(acknowledge: bool, choice: int) -> Dictionary:
	if _pending.has("text"):
		_standing_text = String(_pending["text"])
	var pending_type: StringName = StringName(_pending.get("type", &""))
	var request: Dictionary = _pending.get("request", {})
	if pending_type == &"runtime_request" \
		and StringName(request.get("kind", &"")) == &"battle_requested":
		return _waiting_result()
	## Only frames end a wait, so a button press cannot: the source is inside
	## WaitScriptMovement or a DelayFrames loop, which read no input at all.
	if pending_type == &"wait" or not acknowledge:
		return _waiting_result()

	var resume: StringName = PENDING_RESUMES.get(
		StringName("%s/%s" % [pending_type, _pending_tag()]), &""
	)
	if resume != &"":
		return call(resume, choice) as Dictionary
	for key: String in PENDING_CONTINUATIONS:
		if pending_type == &"text" and _pending.has(key):
			return call(PENDING_CONTINUATIONS[key], choice) as Dictionary

	if pending_type in [&"choice", &"menu"]:
		if choice < 0:
			return _waiting_result()
		_script_value = _answered_value(pending_type, choice)
	if pending_type == &"choice" and _pending.has("contact"):
		var refused: Dictionary = _resume_phone_contact(choice)
		if not refused.is_empty():
			return refused
	if pending_type == &"battle":
		_stage_just_battled(true)
	var finish_after_pending: bool = _finish_after_pending
	_pending = {}
	_finish_after_pending = false
	return _complete() if finish_after_pending else {}


## What a row or a yes/no answers with. Script_verticalmenu and Script__2dmenu
## store wMenuCursorY and wMenuCursorPosition, which count from one, and
## cancel_input() already writes the zero their carry branch does.
func _answered_value(pending_type: StringName, choice: int) -> int:
	if pending_type == &"menu":
		return choice + 1
	if _pending.get("choices", []) == [&"yes", &"no"]:
		return 1 if choice == 0 else 0
	return choice


## `AskNumber1M`'s yes: the number is taken or refused, and either way the caller
## is told which. Answers empty unless the contact itself failed.
func _resume_phone_contact(choice: int) -> Dictionary:
	var contact: int = int(_pending.get("contact", -1))
	if choice == 0:
		var phone_result: Dictionary = _stage_phone_contact(contact)
		if not bool(phone_result.get("ok", false)):
			return _fail(
				StringName(phone_result.get("reason", &"phone_contact_failed")),
				phone_result
			)
	else:
		_script_value = PHONE_CONTACT_REFUSED
	_emit_runtime_event(&"phone_number_result", {
		"contact": contact,
		"accepted": choice == 0 and _script_value == PHONE_CONTACT_GOT,
		"result": _script_value,
	})
	return {}


func _resume_day_of_week_menu(choice: int) -> Dictionary:
	if choice < 0:
		return _waiting_result()
	var selected_day: int = posmod(choice, WEEKDAY_NAMES.size())
	_pending = {
		"type": &"text",
		## `.ConfirmWeekdayText` places the weekday at `hlcoord 1, 14` and
		## `_OakTimeIsItText` carries on from where `PlaceString` left off, so the
		## two are one line.
		"text": "%s, is it?" % WEEKDAY_NAMES[selected_day],
		"special": &"set_day_of_week_confirmation",
		"day": selected_day,
		"source": _request.duplicate(true),
	}
	return _waiting_result()


## `Function17d246`: a row answers its own one-based number and B answers the
## same 4 the routine writes before it opens the menu.
func _resume_challenge_menu(choice: int) -> Dictionary:
	_pending = {}
	_script_value = CHALLENGE_MENU_CANCEL if choice < 0 else choice + 1
	return advance()


## The two refusals the room menu prints put its jumptable back at zero rather
## than leaving the routine, so the menu opens again behind them.
func _resume_room_refusal(_choice: int) -> Dictionary:
	_pending = {}
	return _stage_room_menu()


## `STATICMENU_DISABLE_B`: B does not close the list, so the only way out is a
## row. The answer is whether it is the row the byte's own low nibble names,
## which `maskbits NUM_PASSWORDS_PER_CATEGORY` takes off it.
func _resume_buenas_password(choice: int) -> Dictionary:
	if choice < 0:
		return _waiting_result()
	var password: int = int(_pending.get("password", 0))
	_pending = {}
	_script_value = 1 if choice == (password & 0x3) else 0
	return advance()


func _resume_day_of_week_text(_choice: int) -> Dictionary:
	_stage_day_of_week_confirmation(int(_pending.get("day", 0)))
	return _waiting_result()


func _resume_day_of_week_choice(choice: int) -> Dictionary:
	var confirmed_day: int = int(_pending.get("day", 0))
	_pending = {}
	if choice != 0:
		_stage_day_of_week_menu()
		return _waiting_result()
	_staged_day_of_week = confirmed_day
	_script_value = 1
	return advance()


## AskStrengthScript's `.AskStrength`: opentext, writetext, yesorno. The text
## pause is acknowledged first, then the choice is offered.
func _resume_strength_ask_text(_choice: int) -> Dictionary:
	return _stage_yes_or_no(&"strength_ask", {"slot": int(_pending.get("slot", -1))})


func _resume_strength_ask_choice(choice: int) -> Dictionary:
	var chosen_slot: int = int(_pending.get("slot", -1))
	_pending = {}
	## `iftrue Script_UsedStrength`, and a no falls to closetext/end.
	_script_value = 1 if choice == 0 else 0
	if choice != 0:
		return _complete()
	_stage_strength_used(chosen_slot)
	return _waiting_result()


## FruitTreeScript's promptbutton, behind which its two callasms sit.
func _resume_fruit_tree(_choice: int) -> Dictionary:
	var fruit_tree: int = int(_pending.get("tree_id", 0))
	var fruit_item: int = int(_pending.get("item", 0))
	_pending = {}
	_finish_after_pending = false
	var picked: Dictionary = _resolve_fruit_tree(fruit_tree, fruit_item)
	if not bool(picked.get("ok", false)):
		return _fail(StringName(picked.get("reason", &"fruit_tree_failed")), picked)
	return _waiting_result()


## The tail every item receipt shares behind its own line: the sound, and then
## `itemnotify`'s box once the host has played it.
func _resume_item_received(_choice: int) -> Dictionary:
	var receipt_item: int = int(_pending.get("item", 0))
	var receipt_sfx: int = int(_pending.get("sfx", 0))
	var receipt_finish: bool = bool(_pending.get("finish", false))
	_pending = {}
	_finish_after_pending = false
	_stage_receipt_tail(receipt_item, receipt_sfx, receipt_finish)
	return _waiting_result()


## `GiveItemScript.Full`, whose `promptbutton` is the acknowledge above.
func _resume_pocket_is_full(_choice: int) -> Dictionary:
	var full_item: int = int(_pending.get("item", 0))
	var full_finish: bool = bool(_pending.get("finish", false))
	_pending = {}
	_finish_after_pending = false
	_stage_pocket_is_full(full_item, full_finish)
	return _waiting_result()


func _resume_strength_used(_choice: int) -> Dictionary:
	_stage_internal_text(
		Gen2WorldFieldMove.move_boulders_text(String(_pending.get("name", "#MON"))), true
	)
	return _waiting_result()


## A run of boxes with nothing between them, which is what `PokeSeer`'s own
## actions print and what `PhotoStudio` prints once the printer it cannot reach
## has answered.
func _resume_internal_texts(_choice: int) -> Dictionary:
	var chained: Array = (_pending["next_internal_texts"] as Array).duplicate()
	_pending = {}
	_finish_after_pending = false
	if chained.is_empty():
		return advance()
	var head: String = String(chained.pop_front())
	_stage_internal_text(head, false, {} if chained.is_empty() else {
		"next_internal_texts": chained,
	})
	return _waiting_result()


func _resume_buena_prize_menu(choice: int) -> Dictionary:
	var prize_special: int = int(_pending.get("prize_special", 0))
	if choice < 0:
		## `Buena_PrizeMenu`'s `.cancel`: B leaves the counter, and both
		## `CloseWindow`s are behind her own parting box.
		_pending = {}
		return _buena_prize_box(prize_special, "come_again", true)
	var prize_row: int = clampi(choice, 0, BUENA_PRIZES.size() - 1)
	_pending = {}
	_set_text_buffer(
		RomLayout.STRING_BUFFER_1,
		data.item_name(int(BUENA_PRIZES[prize_row][0])) if data != null else "",
		&"buena_prize", {"special": prize_special, "prize": prize_row}
	)
	var confirm_box: String = _special_box("buena_prize", "is_that_right")
	if confirm_box.is_empty():
		return _fail(&"missing_special_text", {"special": prize_special})
	_pending = {
		"type": &"choice",
		"command": &"buena_prize_confirm",
		"choices": [&"yes", &"no"],
		"text": confirm_box,
		"special": &"buena_prize_confirm",
		"prize": prize_row,
		"prize_special": prize_special,
		"source": _request.duplicate(true),
	}
	return _waiting_result()


func _resume_buena_prize_confirm(choice: int) -> Dictionary:
	var confirm_row: int = int(_pending.get("prize", 0))
	var confirm_special: int = int(_pending.get("prize_special", 0))
	_pending = {}
	if choice != 0:
		return _stage_buena_prize_menu(confirm_special)
	return _buy_buena_prize(confirm_special, confirm_row)


func _resume_mom_menu(choice: int) -> Dictionary:
	_pending = {}
	if choice < 0:
		return _mom_result(_bank_of_mom(MOM_JUST_DO_WHAT_YOU_CAN))
	return _mom_result(_bank_of_mom(
		MOM_MENU_TARGETS[clampi(choice, 0, MOM_MENU_TARGETS.size() - 1)]
	))


func _resume_mom_choice(choice: int) -> Dictionary:
	var mom_state: int = int(_pending.get("mom_state", MOM_EXIT))
	var mom_yes: bool = choice == 0
	_pending = {}
	match mom_state:
		MOM_INITIALIZE:
			## `MomLeavingText3` is printed either way; YES adds the tier she
			## keeps and NO leaves the account open and saving nothing.
			_staged_mom_savings_flags = MOM_ACTIVE \
				| (MOM_SAVING_SOME_MONEY if mom_yes else 0)
			if not mom_yes:
				return _mom_result(_mom_box("leaving_3", MOM_EXIT))
			var second: String = _special_box("bank_of_mom", "leaving_2")
			var third: String = _special_box("bank_of_mom", "leaving_3")
			if second.is_empty() or third.is_empty():
				return _fail(&"missing_special_text", {"special": SPECIAL_BANK_OF_MOM})
			return _mom_result(_stage_internal_text(second, false, {
				"special": SPECIAL_BANK_OF_MOM, "next_internal_texts": [third],
			}))
		MOM_IS_THIS_ABOUT_YOUR_MONEY:
			return _mom_result(_bank_of_mom(
				MOM_ACCESS_BANK if mom_yes else MOM_JUST_DO_WHAT_YOU_CAN
			))
		MOM_STOP_OR_START_SAVING:
			_staged_mom_savings_flags = MOM_ACTIVE \
				| (MOM_SAVING_SOME_MONEY if mom_yes else 0)
			if not mom_yes:
				return _mom_result(_bank_of_mom(MOM_JUST_DO_WHAT_YOU_CAN))
			return _mom_result(_mom_box("start_saving_money", MOM_EXIT))
	return _fail(&"invalid_bank_of_mom_state", {"state": mom_state})


## Her own boxes, each with the jumptable index that follows it.
func _resume_mom_after_text(_choice: int) -> Dictionary:
	var mom_next: int = int(_pending["bank_of_mom_after_text"])
	_pending = {}
	_finish_after_pending = false
	return _mom_result(_bank_of_mom(mom_next))


## `Mom_SetUpDepositMenu` stands behind the question rather than over it.
func _resume_mom_dial(_choice: int) -> Dictionary:
	var mom_mode: StringName = StringName(_pending["bank_of_mom_dial"])
	_pending = {}
	_finish_after_pending = false
	_stage_runtime_request(&"mom_bank_dial_requested", {
		"special": SPECIAL_BANK_OF_MOM,
		"mode": mom_mode,
		"saved": _money_balance(ACCOUNT_MOMS_MONEY),
		"held": _money_balance(ACCOUNT_YOUR_MONEY),
	})
	return _waiting_result()


## A box the prize counter printed, which goes back to her list rather than
## ending: `.print` falls into `.loop`.
func _resume_buena_after_text(_choice: int) -> Dictionary:
	var after_special: int = int(_pending["buena_prize_after_text"])
	_pending = {}
	_finish_after_pending = false
	return _stage_buena_prize_menu(after_special)


## `PokeSeer` prints its opening box, waits for a button and only then opens the
## list; the box is not the list's own backdrop.
func _resume_party_selection(_choice: int) -> Dictionary:
	var selection: Dictionary = _pending["party_selection_after_text"]
	_pending = {}
	_finish_after_pending = false
	_stage_runtime_request(&"party_selection_requested", selection)
	return _waiting_result()


## describedecoration is a local script in the cartridge. Its text must be
## acknowledged before the one decoration that needs a host, the town map, calls
## OverworldTownMap, which preserves the source's
## opentext/waitbutton/special/closetext/end order.
func _resume_special_after_text(_choice: int) -> Dictionary:
	var decoration_special: int = int(_pending.get("special_after_text", -1))
	_pending = {}
	_finish_after_pending = false
	var special_result: Dictionary = _execute_special(decoration_special)
	if not bool(special_result.get("ok", false)):
		return _fail(
			StringName(special_result.get("reason", &"special_failed")), special_result
		)
	return _waiting_result() if _pending else advance()


## The five Ask*Scripts TryTileCollisionEvent reaches, all one shape: opentext,
## writetext, yesorno, iftrue <the move>, closetext, end.
func _resume_field_move_text(_choice: int) -> Dictionary:
	return _stage_yes_or_no(&"field_move_ask", {
		"move": int(_pending.get("move", 0)), "slot": int(_pending.get("slot", -1)),
	})


func _resume_field_move_choice(choice: int) -> Dictionary:
	var asked_move: int = int(_pending.get("move", 0))
	var asked_slot: int = int(_pending.get("slot", -1))
	_pending = {}
	_script_value = 1 if choice == 0 else 0
	if choice == 0:
		## `iftrue Script_Cut` and its four counterparts. The move itself belongs
		## to the host, which owns the staged request and the commit the party
		## submenu already reaches.
		_emit_runtime_event(&"field_move_confirmed", {
			"move": asked_move, "slot": asked_slot,
		})
	return _complete()


func _resume_remember_password(choice: int) -> Dictionary:
	_pending = {}
	_script_value = 1 if choice == 0 else 0
	_stage_frame_wait(ASK_REMEMBER_PASSWORD_CLOSE_FRAMES)
	return _waiting_result()


## AskRockSmashScript, the same opentext/writetext/yesorno shape.
func _resume_rock_smash_text(_choice: int) -> Dictionary:
	return _stage_yes_or_no(&"rock_smash_ask", {"slot": int(_pending.get("slot", -1))})


func _resume_rock_smash_choice(choice: int) -> Dictionary:
	var smash_slot: int = int(_pending.get("slot", -1))
	_pending = {}
	## `iftrue RockSmashScript`, and a no falls to closetext/end.
	_script_value = 1 if choice == 0 else 0
	if choice != 0:
		return _complete()
	_stage_rock_smash_used(smash_slot)
	return _waiting_result()


## RockSmashScript's `closetext`, `special WaitSFX` and `playsound SFX_STRENGTH`.
## The rest of the script waits on the sound the way a trainer's approach waits
## on its encounter music.
func _resume_rock_smash_used(_choice: int) -> Dictionary:
	_pending = {}
	_rock_smash_after_sound = true
	_stage_audio_request(&"sound", {"address": SFX_STRENGTH})
	return _waiting_result()


## The yesorno an Ask*Script offers behind the box it has just printed, carrying
## [param values] through to the answer.
func _stage_yes_or_no(tag: StringName, values: Dictionary) -> Dictionary:
	_pending = {
		"type": &"choice",
		"command": &"yesorno",
		"choices": [&"yes", &"no"],
		"text": _standing_text,
		"special": tag,
		"source": _request.duplicate(true),
	}
	for key: Variant in values:
		_pending[key] = values[key]
	return _waiting_result()


## What answers each runtime request the host has finished, as the handler that
## reads it. The key is the pending request's own kind. `_complete_plain_request`
## puts the host's answer in wScriptVar and runs on, and for most of these that
## answer is nothing: the routine drew a page, held for a button and wrote
## nothing a script reads, and the map's own `waitbutton` presses what it left
## standing. The five that do answer a value say so beside them.
const COMPLETION_HANDLERS: Dictionary = {
	&"catch_tutorial_requested": &"_complete_catch_tutorial",
	&"swarm_requested": &"_complete_swarm",
	&"phone_call_requested": &"_complete_phone_call",
	&"special_phone_call_requested": &"_complete_phone_call",
	&"mom_bank_dial_requested": &"_complete_mom_bank_dial",
	&"party_selection_requested": &"_complete_party_selection",
	&"apricorn_selection_requested": &"_complete_apricorn_selection",
	&"elevator_requested": &"_complete_elevator",
	&"trainer_approach_requested": &"_complete_trainer_approach",
	&"day_care_requested": &"_complete_day_care",
	&"slot_machine_requested": &"_complete_coin_game",
	&"card_flip_requested": &"_complete_coin_game",
	&"mart_requested": &"_complete_plain_request",
	&"audio_requested": &"_complete_plain_request",
	&"pokemon_requested": &"_complete_plain_request",
	&"trade_requested": &"_complete_trade",
	&"pc_requested": &"_complete_plain_request",
	&"party_heal_requested": &"_complete_plain_request",
	&"town_map_requested": &"_complete_plain_request",
	## `BugContestJudging` answers with the placing, which the results script
	## reads out of wScriptVar exactly as the marts and the PC do.
	&"bug_contest_judging_requested": &"_complete_plain_request",
	&"name_rater_requested": &"_complete_plain_request",
	&"move_deleter_requested": &"_complete_plain_request",
	## `MoveTutor` answers FALSE when the move was learned and -1 when the
	## list was backed out of, which is the one branch its script reads.
	&"move_tutor_requested": &"_complete_plain_request",
	## `UnownPuzzle` answers `wSolvedUnownPuzzle`, which is zero for a board
	## left on START and one for a solved one.
	&"unown_puzzle_requested": &"_complete_plain_request",
	## `CheckPartyFullAfterContest`'s own three answers, which
	## `BugContestResults_DidNotLeaveMons` branches on twice.
	&"contest_mon_requested": &"_complete_plain_request",
	## `PlayRadio` opens the request's own station.
	&"map_radio_requested": &"_complete_plain_request",
	## `NewPokedexEntry` behind `GameCornerPrizeMonCheckDex`'s dex writes,
	## which are staged here rather than in the screen.
	&"pokedex_entry_requested": &"_complete_plain_request",
	&"dratini_moveset_requested": &"_complete_plain_request",
	&"diploma_requested": &"_complete_plain_request",
	&"unown_printer_requested": &"_complete_plain_request",
	## `TryQuickSave` answers TRUE for a save that was written and FALSE for
	## one that was not, which is the branch both of its sites read.
	&"quick_save_requested": &"_complete_plain_request",
	&"link_record_requested": &"_complete_plain_request",
	&"link_room_requested": &"_complete_plain_request",
	&"rival_name_requested": &"_complete_rival_name",
	&"battle_requested": &"_complete_battle",
}


## Completes a host-owned runtime request without treating a button press as its
## result. A confirmed loss ends this invocation through the explicit blackout
## recovery result without committing its staged world state.
func complete_runtime_request(result: Dictionary) -> Dictionary:
	if _pending.is_empty() or _pending.get("type", &"") != &"runtime_request":
		return {
			"ok": false, "status": &"failed", "reason": &"runtime_request_not_pending",
			"details": result.duplicate(true),
		}
	var request: Dictionary = _pending.get("request", {})
	var kind: StringName = StringName(request.get("kind", &""))
	if not COMPLETION_HANDLERS.has(kind):
		return {
			"ok": false, "status": &"failed", "reason": &"runtime_request_kind_mismatch",
			"details": {"kind": kind},
		}
	return call(COMPLETION_HANDLERS[kind], kind, request, result)


func _complete_catch_tutorial(
	_kind: StringName, request: Dictionary, result: Dictionary
) -> Dictionary:
	if not bool(result.get("ok", false)):
		return _fail(
			StringName(result.get("reason", &"catch_tutorial_failed")), result
		)
	var catch_outcome: StringName = StringName(result.get("outcome", &""))
	if catch_outcome != Gen2WorldBattleAdapter.OUTCOME_CAUGHT:
		return _fail(&"invalid_catch_tutorial_outcome", result)
	_script_value = 1
	_events.append({
		"type": &"catch_tutorial_completed",
		"request": request.duplicate(true),
		"result": result.duplicate(true),
	})
	_events.append({"type": &"battle_map_reload_requested", "tutorial": true})
	_pending = {}
	return advance()


func _complete_swarm(
	_kind: StringName, request: Dictionary, result: Dictionary
) -> Dictionary:
	if not bool(result.get("ok", false)):
		return _fail(
			StringName(result.get("reason", &"swarm_request_failed")), result
		)
	var values: Dictionary = request.get("values", {})
	var active: bool = bool(result.get("active", true))
	var map_group: int = int(result.get("map_group", values.get("map_group", -1)))
	var map_number: int = int(result.get("map_number", values.get("map_number", -1)))
	var fishing_species: int = int(result.get("fishing_species", 0))
	var swarm_kind: int = int(
		result.get("kind", values.get("kind", Gen2WorldState.SWARM_DUNSPARCE))
	)
	if active and (map_group < 0 or map_number < 0):
		return _fail(&"invalid_swarm_map", result)
	if fishing_species not in [0, 0xD3, 0xDF]:
		return _fail(&"invalid_fishing_swarm_species", result)
	if swarm_kind not in [Gen2WorldState.SWARM_DUNSPARCE, Gen2WorldState.SWARM_YANMA]:
		return _fail(&"invalid_swarm_kind", result)
	_staged_swarm = {
		"active": active,
		"kind": swarm_kind,
		"map_group": map_group,
		"map_number": map_number,
		"fishing_species": fishing_species,
	}
	_has_staged_swarm = true
	_events.append({
		"type": &"swarm_changed",
		"kind": swarm_kind,
		"map_group": map_group,
		"map_number": map_number,
		"active": active,
		"fishing_species": fishing_species,
	})
	_pending = {}
	return advance()


func _complete_phone_call(
	kind: StringName, request: Dictionary, result: Dictionary
) -> Dictionary:
	if not bool(result.get("ok", false)):
		return _fail(
			StringName(result.get("reason", "runtime_request_failed")), result
		)
	var phone_data: Dictionary = result.get("data", {})
	_events.append({
		"type": &"runtime_request_completed",
		"kind": kind,
		"request": request.duplicate(true),
		"result": result.duplicate(true),
	})
	_pending = {}
	if bool(phone_data.get("clear", false)):
		_phone_context = {}
		_script_value = 1
		return advance()
	var phone_script: Dictionary = phone_data.get("script", {})
	if phone_script.is_empty():
		_script_value = int(result.get("script_value", 1))
		return advance()
	_phone_context = phone_data.get("phone", {}).duplicate(true)
	_phone_started = false
	if not _push_frame(
		int(phone_script.get("bank", -1)), int(phone_script.get("address", -1))
	):
		return _fail(&"phone_script_missing", phone_script)
	return advance()


func _complete_mom_bank_dial(
	kind: StringName, request: Dictionary, result: Dictionary
) -> Dictionary:
	if not bool(result.get("ok", false)):
		return _fail(
			StringName(result.get("reason", &"mom_bank_dial_failed")), result
		)
	var dial_mode: StringName = StringName(
		(request.get("values", {}) as Dictionary).get("mode", MOM_DIAL_DEPOSIT)
	)
	## A cancelled box answers -1, which is `.CancelDeposit`'s own zero
	## amount one step earlier.
	var dial_amount: int = int(result.get("amount", -1))
	_events.append({
		"type": &"runtime_request_completed",
		"kind": kind,
		"request": request.duplicate(true),
		"result": result.duplicate(true),
	})
	_pending = {}
	return _mom_result(_finish_mom_bank_dial(dial_mode, maxi(dial_amount, 0)))


func _complete_party_selection(
	_kind: StringName, request: Dictionary, result: Dictionary
) -> Dictionary:
	if not bool(result.get("ok", false)):
		return _fail(
			StringName(result.get("reason", &"party_selection_failed")), result
		)
	return _finish_party_selection(request, result)


func _complete_apricorn_selection(
	kind: StringName, request: Dictionary, result: Dictionary
) -> Dictionary:
	if not bool(result.get("ok", false)):
		return _fail(
			StringName(result.get("reason", &"apricorn_selection_failed")), result
		)
	var apricorn: int = int(result.get("item", 0))
	var apricorn_quantity: int = int(result.get("quantity", 0))
	if apricorn != 0 and not Gen2WorldApricorn.is_apricorn(apricorn):
		return _fail(&"invalid_apricorn", result)
	## `SelectApricornForKurt` zeroes wKurtApricornQuantity on entry and
	## writes it only past `Kurt_SelectQuantity`'s carry, so a cancelled
	## selection leaves both bytes at zero.
	if apricorn == 0:
		apricorn_quantity = 0
	elif apricorn_quantity < 1 or apricorn_quantity > Gen2WorldApricorn.MAX_QUANTITY:
		return _fail(&"invalid_apricorn_quantity", result)
	_script_value = apricorn
	_staged_kurt_apricorn_quantity = apricorn_quantity
	_has_staged_kurt_apricorn_quantity = true
	_events.append({
		"type": &"runtime_request_completed",
		"kind": kind,
		"request": request.duplicate(true),
		"result": result.duplicate(true),
	})
	_pending = {}
	return advance()


func _complete_elevator(
	kind: StringName, request: Dictionary, result: Dictionary
) -> Dictionary:
	## `Script_elevator` zeroes `wScriptVar` before the call and writes TRUE
	## only past `ret c`, so a cancelled ride and a car with no floor to
	## match both leave the script's own FALSE branch standing.
	if not bool(result.get("ok", false)):
		return _fail(StringName(result.get("reason", &"elevator_failed")), result)
	var rode: bool = result.has("floor") and result["floor"] is Dictionary
	if rode:
		## `Elevator_GoToFloor` copies the chosen row's last three bytes
		## straight over `wBackupWarpNumber`, and the -1 warp out of the car
		## is what spends them.
		var floor_row: Dictionary = result["floor"]
		_emit_runtime_event(&"backup_warp_changed", {
			"warp": int(floor_row.get("warp", 0)),
			"map_group": int(floor_row.get("map_group", 0)),
			"map_number": int(floor_row.get("map_number", 0)),
		})
	_script_value = 1 if rode else 0
	_events.append({
		"type": &"runtime_request_completed",
		"kind": kind,
		"request": request.duplicate(true),
		"result": result.duplicate(true),
	})
	_pending = {}
	return advance()


func _complete_trainer_approach(
	_kind: StringName, request: Dictionary, result: Dictionary
) -> Dictionary:
	if not bool(result.get("ok", false)):
		return _fail(
			StringName(result.get("reason", &"trainer_approach_failed")), result
		)
	_events.append({
		"type": &"trainer_approach_completed",
		"request": request.duplicate(true),
		"result": result.duplicate(true),
	})
	_pending = {}
	return advance()


func _complete_day_care(
	kind: StringName, request: Dictionary, result: Dictionary
) -> Dictionary:
	## Four of the five write nothing a script reads, so wScriptVar is left
	## where it stood unless the result carries one: `DayCareManOutside` is
	## the only routine of the five with an `ld [wScriptVar], a` in it.
	if not bool(result.get("ok", false)):
		return _fail(
			StringName(result.get("reason", &"runtime_request_failed")), result
		)
	if result.has("script_value"):
		_script_value = int(result["script_value"])
	_events.append({
		"type": &"runtime_request_completed",
		"kind": kind,
		"request": request.duplicate(true),
		"result": result.duplicate(true),
	})
	_pending = {}
	return advance()


func _complete_coin_game(
	kind: StringName, request: Dictionary, result: Dictionary
) -> Dictionary:
	## `_SlotMachine` and `_CardFlip` both write `wCoins` themselves, over
	## and over, so what comes back is the balance rather than a delta.
	## Nothing reads `wScriptVar` after either: every map `closetext` and
	## `end`.
	if not bool(result.get("ok", false)):
		return _fail(
			StringName(result.get("reason", &"slot_machine_failed")), result
		)
	var slot_coins: int = int(result.get("coins", _coins_value()))
	if slot_coins < 0 or slot_coins > Gen2SlotMachine.MAX_COINS:
		return _fail(&"invalid_coins", result)
	_staged_coins = slot_coins
	_events.append({
		"type": &"runtime_request_completed",
		"kind": kind,
		"request": request.duplicate(true),
		"result": result.duplicate(true),
	})
	_pending = {}
	return advance()


func _complete_plain_request(
	kind: StringName, request: Dictionary, result: Dictionary
) -> Dictionary:
	if not bool(result.get("ok", false)):
		return _fail(
			StringName(result.get("reason", "runtime_request_failed")), result
		)
	_script_value = int(result.get("script_value", 1))
	_events.append({
		"type": &"runtime_request_completed",
		"kind": kind,
		"request": request.duplicate(true),
		"result": result.duplicate(true),
	})
	var approach_after_audio: bool = kind == &"audio_requested" \
		and StringName((request.get("values", {}) as Dictionary).get("kind", &"")) \
		== &"encounter_music" and _trainer_intro_approach_pending
	var smash_after_sound: bool = kind == &"audio_requested" \
		and StringName((request.get("values", {}) as Dictionary).get("kind", &"")) \
		== &"sound" and _rock_smash_after_sound
	var notify_after_sound: Dictionary = _item_notify_after_sound \
		if kind == &"audio_requested" else {}
	var mom_after_sound: int = _bank_of_mom_after_sound \
		if kind == &"audio_requested" else -1
	var trade_after_sound: Dictionary = _npc_trade_after_sound \
		if kind == &"audio_requested" else {}
	_pending = {}
	if not trade_after_sound.is_empty():
		_npc_trade_after_sound = {}
		return _trade_result(_stage_trade_audio(
			trade_after_sound["trade"], int(trade_after_sound["step"])
		))
	if mom_after_sound >= 0:
		_bank_of_mom_after_sound = -1
		var receipt: String = _mom_receipt_box
		_mom_receipt_box = ""
		return _mom_result(_mom_box(receipt, mom_after_sound))
	if approach_after_audio:
		_trainer_intro_approach_pending = false
		_stage_trainer_approach()
	if smash_after_sound:
		_rock_smash_after_sound = false
		_stage_rock_smash_shake()
	if not notify_after_sound.is_empty():
		_item_notify_after_sound = {}
		_stage_item_notify(
			int(notify_after_sound.get("item", 0)),
			bool(notify_after_sound.get("finish", false))
		)
	return advance()


## `NPCTrade` past `DoNPCTrade` and its movie: `GetTradeMonNames` again, then
## `TradedForText`. A request that settled itself falls back to the plain
## completion, so a driver that draws nothing still reads the host's answer.
func _complete_trade(
	kind: StringName, request: Dictionary, result: Dictionary
) -> Dictionary:
	var values: Dictionary = request.get("values", {})
	var record: Dictionary = Gen2WorldPartyHost.trade_record(data, values)
	if record.is_empty() or not values.has("party_index") \
		or not bool(result.get("ok", false)) \
		or not bool(result.get("accepted", false)):
		return _complete_plain_request(kind, request, result)
	_script_value = int(result.get("script_value", 1))
	_events.append({
		"type": &"runtime_request_completed",
		"kind": kind,
		"request": request.duplicate(true),
		"result": result.duplicate(true),
	})
	_pending = {}
	_set_trade_names(record)
	var traded: String = _special_box("npc_trade", "traded_for")
	if traded.is_empty():
		return _fail(&"missing_special_text", values)
	return _trade_result(_stage_internal_text(traded, false, {
		"npc_trade_after_traded": values.duplicate(),
	}))


func _complete_rival_name(
	_kind: StringName, request: Dictionary, result: Dictionary
) -> Dictionary:
	if not bool(result.get("ok", false)):
		return _fail(
			StringName(result.get("reason", &"runtime_request_failed")), result
		)
	var default_name: String = String(
		(request.get("values", {}) as Dictionary).get("default_name", "SILVER")
	)
	_rival_name = String(result.get("name", default_name)).strip_edges()
	if _rival_name.is_empty():
		_rival_name = default_name
	_script_value = 1
	_events.append({"type": &"rival_name_changed", "name": _rival_name})
	_pending = {}
	return advance()


func _complete_battle(
	_kind: StringName, request: Dictionary, result: Dictionary
) -> Dictionary:
	if not bool(result.get("ok", false)):
		return _fail(
			StringName(result.get("reason", &"runtime_request_failed")), result
		)
	var outcome: StringName = StringName(result.get("outcome", &""))
	if String(outcome).is_empty():
		return _fail(&"invalid_battle_outcome", result)
	var battle_values: Dictionary = request.get("values", {})
	if outcome == Gen2WorldBattleAdapter.OUTCOME_LOST \
		and StringName(battle_values.get("kind", &"")) == &"battle_tower":
		## The tower's own loss: `RunBattleTowerTrainer` heals the party and
		## returns, and the room script warps the player out. There is no
		## `reloadmapafterbattle` anywhere in it, so nothing blacks out.
		_battle_tower_opponent = {}
		_script_value = BATTLE_RESULT_LOSE
		_events.append({
			"type": &"battle_lost",
			"outcome": outcome,
			"battle_tower": true,
			"request": request.duplicate(true),
			"result": result.duplicate(true),
		})
		_pending = {}
		return advance()
	if outcome == Gen2WorldBattleAdapter.OUTCOME_LOST and bool(battle_values.get("can_lose", false)):
		## `Script_startbattle` writes `wBattleResult & ~BATTLERESULT_BITMASK`
		## whatever the battle type was, so a lost CANLOSE battle answers LOSE.
		## Cherrygrove's three sites are the only ones in either corpus and their
		## two branches print the same text, which is what hid a zero here.
		_script_value = BATTLE_RESULT_LOSE
		_events.append({
			"type": &"battle_lost",
			"outcome": outcome,
			"can_lose": true,
			"request": request.duplicate(true),
			"result": result.duplicate(true),
		})
		_pending = {}
		return advance()
	if outcome == Gen2WorldBattleAdapter.OUTCOME_LOST:
		var recovery: Variant = result.get("recovery", {})
		if not recovery is Dictionary or not bool((recovery as Dictionary).get("ok", false)):
			return _fail(&"battle_recovery_failed", result)
		_events.append({
			"type": &"battle_lost",
			"outcome": outcome,
			"request": request.duplicate(true),
			"result": result.duplicate(true),
		})
		_events.append({
			"type": &"blackout",
			"recovery": (recovery as Dictionary).duplicate(true),
		})
		_pending = {}
		_active = false
		_completed = true
		return _recovered_result(recovery as Dictionary)
	if outcome == Gen2WorldBattleAdapter.OUTCOME_CAUGHT:
		_script_value = BATTLE_RESULT_WIN
		_events.append({
			"type": &"battle_captured",
			"outcome": outcome,
			"request": request.duplicate(true),
			"result": result.duplicate(true),
		})
		_pending = {}
		return advance()
	if outcome == Gen2WorldBattleAdapter.OUTCOME_RAN:
		## `.can_escape` writes DRAW into wBattleResult, and the script carries
		## on: `reloadmapafterbattle` only branches on LOSE. The eight corpus
		## scripts that `iftrue` straight after `startbattle` are asking "did I
		## not win", and a run answers yes.
		_stage_just_battled(true)
		_script_value = BATTLE_RESULT_DRAW
		_events.append({
			"type": &"battle_completed",
			"outcome": outcome,
			"request": request.duplicate(true),
			"result": result.duplicate(true),
		})
		_pending = {}
		return advance()
	if outcome != Gen2WorldBattleAdapter.OUTCOME_WON:
		return _fail(StringName("battle_%s" % outcome), result)

	if StringName(battle_values.get("kind", &"")) == &"battle_tower":
		## `RunBattleTowerTrainer`'s win branch: the SRAM count is read back into
		## `wNrOfBeatenBattleTowerTrainers`, which the room script's `readmem`
		## then compares against the streak length, and the same number plus
		## `'1'` goes into wStringBuffer3 for "Next up, opponent no. N".
		var beaten: int = _battle_tower().beaten
		var counted: Dictionary = _stage_script_memory(BEATEN_TRAINERS_ADDRESS, beaten)
		if not bool(counted.get("ok", true)):
			return counted
		_set_text_buffer(
			RomLayout.STRING_BUFFER_3, str(beaten + 1), &"battle_tower_opponent"
		)
		_battle_tower_opponent = {}
		_script_value = BATTLE_RESULT_WIN
		_events.append({
			"type": &"battle_completed",
			"outcome": outcome,
			"request": request.duplicate(true),
			"result": result.duplicate(true),
		})
		_pending = {}
		return advance()
	_stage_just_battled(true)
	## Script_startbattle leaves `wBattleResult & ~BATTLERESULT_BITMASK` in
	## wScriptVar, and WIN is zero there, so the eight corpus scripts that put
	## an `iftrue` straight after `startbattle` are asking "did I not win".
	## Catching masks its own bit off and also reads as WIN.
	_script_value = BATTLE_RESULT_WIN
	_events.append({
		"type": &"battle_completed",
		"outcome": outcome,
		"request": request.duplicate(true),
		"result": result.duplicate(true),
	})
	_pending = {}
	return advance()
func pending_runtime_request() -> Dictionary:
	if _pending.get("type", &"") != &"runtime_request":
		return {}
	var request: Dictionary = (_pending.get("request", {}) as Dictionary).duplicate(true)
	request["source"] = (_pending.get("source", {}) as Dictionary).duplicate(true)
	return request


func pending_input() -> Dictionary:
	return _pending.duplicate(true)


## The frame wait this invocation is standing in, empty when it is not standing
## in one. A caller spends the frames and calls [method complete_wait]; nothing
## else ends it.
func pending_wait() -> Dictionary:
	if StringName(_pending.get("type", &"")) != &"wait":
		return {}
	return _pending.duplicate(true)


## Resumes after the wait above. `ShowEmoteScript`'s trailing
## `applymovementlasttalked .Hide` is the one continuation a wait carries: the
## emote is put up by the script the source calls and taken down by the same
## script, so the hide belongs to the end of the pause rather than to a host.
func complete_wait() -> Dictionary:
	if StringName(_pending.get("type", &"")) != &"wait":
		return {
			"ok": false, "status": &"failed", "reason": &"script_wait_not_pending",
		}
	var hide_emote_object: int = int(
		_pending.get("hide_emote_object", Gen2WorldObject.NONE_INDEX)
	)
	var rock_smash_step: int = int(_pending.get("rock_smash_step", 0))
	_pending = {}
	if rock_smash_step == 1:
		_stage_rock_smash_movement()
		return advance()
	if rock_smash_step == 2:
		_stage_rock_smashed()
		return advance()
	if hide_emote_object != Gen2WorldObject.NONE_INDEX:
		_emit_object_event(&"object_emote", {
			"object_index": hide_emote_object,
			"emote_id": _loaded_emote,
			"visible": false,
			"duration": 0,
		})
	return advance()


## Cancels a pending menu or choice without inventing a cartridge option. The
## script receives zero, matching the false branch used by yes/no commands.
## The pendings a built-in routine owns the B of. Everything else staged as a
## `choice` or a `menu` is the cartridge's own command, whose B is the false
## answer `cancel_input` writes.
const CANCEL_OWNED_PENDINGS: Array[StringName] = [
	&"buena_prize", &"buena_prize_confirm", &"bank_of_mom_menu", &"bank_of_mom_choice",
	&"ask_remember_password",
	&"strength_ask", &"field_move_ask", &"rock_smash_ask",
	&"set_day_of_week_confirmation",
]


func cancel_input() -> Dictionary:
	if _pending.is_empty() or StringName(_pending.get("type", &"")) not in [&"choice", &"menu"]:
		return {
			"ok": false,
			"status": &"failed",
			"reason": &"script_input_not_cancellable",
		}
	var pending_type: StringName = StringName(_pending.get("type", &""))
	## A box one of the built-in routines put up answers its own B rather than
	## resuming: Buena's counter prints her parting line, Mom falls to
	## `.JustDoWhatYouCan`, and every `YesNoBox` among them reads it as its NO,
	## which is the carry the routine returns. A `Script_yesorno` or a
	## `Script_verticalmenu` the cartridge staged is the false answer below.
	if _pending_tag() in CANCEL_OWNED_PENDINGS:
		return advance(true, -1)
	if pending_type == &"choice" and _pending.has("contact"):
		_emit_runtime_event(&"phone_number_result", {
			"contact": int(_pending.get("contact", -1)), "accepted": false,
		})
	_script_value = 0
	var finish_after_pending: bool = _finish_after_pending
	_pending = {}
	_finish_after_pending = false
	if finish_after_pending:
		return _complete()
	return advance()


func is_waiting() -> bool:
	return not _pending.is_empty()


func is_finished() -> bool:
	return _completed or not _failure.is_empty()


## Every script command this runner runs, as the handler that runs it.
const COMMAND_HANDLERS: Dictionary = {
	Gen2WorldScript.SCALL: &"_command_scall",
	Gen2WorldScript.FARSCALL: &"_command_farscall",
	Gen2WorldScript.MEMCALL: &"_command_memcall",
	Gen2WorldScript.MEMJUMP: &"_command_memcall",
	Gen2WorldScript.WARPMOD: &"_command_warpmod",
	Gen2WorldScript.BLACKOUTMOD: &"_command_blackoutmod",
	Gen2WorldScript.SJUMP: &"_command_sjump",
	Gen2WorldScript.FARSJUMP: &"_command_farsjump",
	Gen2WorldScript.IFEQUAL: &"_command_ifequal",
	Gen2WorldScript.IFNOTEQUAL: &"_command_ifnotequal",
	Gen2WorldScript.IFFALSE: &"_command_iffalse",
	Gen2WorldScript.IFTRUE: &"_command_iftrue",
	Gen2WorldScript.IFGREATER: &"_command_ifgreater",
	Gen2WorldScript.IFLESS: &"_command_ifless",
	Gen2WorldScript.JUMPSTD: &"_command_jumpstd",
	Gen2WorldScript.CALLSTD: &"_command_callstd",
	Gen2WorldScript.CHECKMAPSCENE: &"_command_checkmapscene",
	Gen2WorldScript.SETMAPSCENE: &"_command_setmapscene",
	Gen2WorldScript.CHECKSCENE: &"_command_checkscene",
	Gen2WorldScript.SETSCENE: &"_command_setscene",
	Gen2WorldScript.CHECKVER: &"_command_checkver",
	Gen2WorldScript.SETVAL: &"_command_setval",
	Gen2WorldScript.ADDVAL: &"_command_addval",
	Gen2WorldScript.READMEM: &"_command_readmem",
	Gen2WorldScript.WRITEMEM: &"_command_writemem",
	Gen2WorldScript.LOADMEM: &"_command_loadmem",
	Gen2WorldScript.READVAR: &"_command_readvar",
	Gen2WorldScript.WRITEVAR: &"_command_writevar",
	Gen2WorldScript.LOADVAR: &"_command_loadvar",
	Gen2WorldScript.CHECKTIME: &"_command_checktime",
	Gen2WorldScript.ADDCELLNUM: &"_command_addcellnum",
	Gen2WorldScript.DELCELLNUM: &"_command_delcellnum",
	Gen2WorldScript.CHECKCELLNUM: &"_command_checkcellnum",
	Gen2WorldScript.SPECIAL: &"_command_special",
	Gen2WorldScript.RANDOM: &"_command_random",
	Gen2WorldScript.XYCOMPARE: &"_command_xycompare",
	Gen2WorldScript.GIVEITEM: &"_command_giveitem",
	Gen2WorldScript.TAKEITEM: &"_command_takeitem",
	Gen2WorldScript.CHECKITEM: &"_command_checkitem",
	Gen2WorldScript.GIVEMONEY: &"_command_givemoney",
	Gen2WorldScript.TAKEMONEY: &"_command_givemoney",
	Gen2WorldScript.CHECKMONEY: &"_command_checkmoney",
	Gen2WorldScript.GIVECOINS: &"_command_givecoins",
	Gen2WorldScript.TAKECOINS: &"_command_givecoins",
	Gen2WorldScript.CHECKCOINS: &"_command_checkcoins",
	Gen2WorldScript.GETMONEY: &"_command_getmoney",
	Gen2WorldScript.GETCOINS: &"_command_getcoins",
	Gen2WorldScript.GETITEMNAME: &"_command_getitemname",
	Gen2WorldScript.GETMONNAME: &"_command_getmonname",
	Gen2WorldScript.GETTRAINERNAME: &"_command_gettrainername",
	Gen2WorldScript.GETSTRING: &"_command_getstring",
	Gen2WorldScript.CLEAREVENT: &"_command_clearevent",
	Gen2WorldScript.SETEVENT: &"_command_setevent",
	Gen2WorldScript.CHECKEVENT: &"_command_checkevent",
	Gen2WorldScript.CLEARFLAG: &"_command_clearflag",
	Gen2WorldScript.SETFLAG: &"_command_setflag",
	Gen2WorldScript.CHECKFLAG: &"_command_checkflag",
	Gen2WorldScript.WILDON: &"_command_wildon",
	Gen2WorldScript.WILDOFF: &"_command_wildoff",
	Gen2WorldScript.WARP: &"_command_warp",
	Gen2WorldScript.OPENTEXT: &"_command_opentext",
	Gen2WorldScript.REANCHORMAP: &"_command_opentext",
	Gen2WorldScript.CLOSETEXT: &"_command_opentext",
	Gen2WorldScript.WRITEUNUSEDBYTE: &"_command_opentext",
	Gen2WorldScript.CLOSEWINDOW: &"_command_opentext",
	Gen2WorldScript.ITEMNOTIFY: &"_command_itemnotify",
	Gen2WorldScript.POCKETISFULL: &"_command_pocketisfull",
	Gen2WorldScript.WRITETEXT: &"_command_writetext",
	Gen2WorldScript.FARWRITETEXT: &"_command_farwritetext",
	Gen2WorldScript.JUMPTEXTFACEPLAYER: &"_command_jumptextfaceplayer",
	Gen2WorldScript.REPEATTEXT: &"_command_repeattext",
	Gen2WorldScript.YESORNO: &"_command_yesorno",
	Gen2WorldScript.LOADMENU: &"_command_loadmenu",
	Gen2WorldScript.CHECKPOKE: &"_command_checkpoke",
	Gen2WorldScript.GIVEPOKE: &"_command_givepoke",
	Gen2WorldScript.GIVEEGG: &"_command_givepoke",
	Gen2WorldScript.GIVEPOKEMAIL: &"_command_givepokemail",
	Gen2WorldScript.CHECKPOKEMAIL: &"_command_checkpokemail",
}

## The two commands with nothing behind them yet: `getnum` reads a number into
## a text buffer and `getcurlandmarkname` the landmark the player stands on, and
## no script in either pin prints what they leave.
const HANDLED_BASE: Array[int] = [
	Gen2WorldScript.GETNUM, Gen2WorldScript.GETCURLANDMARKNAME,
]


## Whether [method _execute] dispatches [param opcode]; the corpus sweeps it.
static func handles_opcode(opcode: int, crystal_commands: bool = true) -> bool:
	if opcode == Gen2WorldScript.FARJUMPTEXT \
		or (crystal_commands and opcode == Gen2WorldScript.JUMPTEXT) \
		or Gen2WorldScript.is_waitbutton(opcode, crystal_commands) \
		or Gen2WorldScript.is_promptbutton(opcode, crystal_commands) \
		or Gen2WorldScript.is_terminal(opcode, crystal_commands):
		return true
	if crystal_commands and (opcode in [0x9F, 0xA8, 0xA9] \
		or CRYSTAL_NAME_COMMANDS.has(opcode)):
		return true
	var source: int = Gen2WorldScript.source_opcode(opcode, crystal_commands)
	return source in OBJECT_SOURCE_OPCODES or LATER_HANDLERS.has(source) \
		or COMMAND_HANDLERS.has(opcode) or opcode in HANDLED_BASE


const OBJECT_SOURCE_OPCODES: Array[int] = [
	0x67, 0x68, 0x69, 0x6A, 0x6B, 0x6D, 0x6E, 0x6F, 0x70, 0x71, 0x72, 0x75, 0x76,
]


func _execute(command: Dictionary, frame: Dictionary) -> Dictionary:
	var opcode: int = int(command["opcode"])
	var bank: int = int(frame["bank"])
	command = _catalogued(command, frame)
	var early: Dictionary = _execute_early_command(opcode, command, bank)
	if not early.is_empty():
		return early
	var source: int = Gen2WorldScript.source_opcode(opcode, _crystal_commands())
	var object_result: Dictionary = _execute_object_command(source, command)
	if not object_result.is_empty():
		return object_result
	var later_result: Dictionary = _execute_later_command(source, command, bank)
	if not later_result.is_empty():
		return later_result
	if Gen2WorldScript.is_terminal(opcode, _crystal_commands()):
		_frames.pop_back()
		if _frames.is_empty():
			return _complete()
		return {"ok": true}
	if COMMAND_HANDLERS.has(opcode):
		return call(COMMAND_HANDLERS[opcode], opcode, command, bank)
	if opcode in HANDLED_BASE:
		return {"ok": true}
	return {
		"ok": false,
		"reason": &"unsupported_runtime_command",
		"command": command,
	}


## The commands that answer before the opcode is normalized: two text jumps whose
## bank depends on the profile, the two button pauses, and the two raw bytes
## Crystal added over pokegold commands. Empty when the command is not one of them.
func _execute_early_command(opcode: int, command: Dictionary, bank: int) -> Dictionary:
	if opcode == Gen2WorldScript.FARJUMPTEXT:
		if _crystal_commands():
			return _show_text(int(command["bank"]), int(command["address"]), true)
		return _show_text(bank, int(command["address"]), true)
	if opcode == Gen2WorldScript.JUMPTEXT and _crystal_commands():
		return _show_text(bank, int(command["address"]), true)
	if Gen2WorldScript.is_waitbutton(opcode, _crystal_commands()) \
		or Gen2WorldScript.is_promptbutton(opcode, _crystal_commands()):
		return _stage_button(command)
	if opcode == 0xA8 and _crystal_commands():
		## `wait` is one of the commands Crystal added, so it has no pokegold
		## opcode to resolve through and has to answer from the raw byte.
		## Script_wait delays its operand times six frames and reads nothing.
		## The two Magnet Train stations are its only call sites in either pin.
		_emit_runtime_event(&"script_timing_requested", {
			"kind": &"wait",
			"value": int(command.get("value", 0)),
			"frames": int(command.get("value", 0)) * WAIT_FRAMES_PER_UNIT,
		})
		return _stage_frame_wait(int(command.get("value", 0)) * WAIT_FRAMES_PER_UNIT)
	if _crystal_commands() and CRYSTAL_NAME_COMMANDS.has(opcode):
		return call(CRYSTAL_NAME_COMMANDS[opcode], command)
	if opcode == 0xA9 and _crystal_commands():
		_script_value = 1
		return {"ok": true}
	if opcode == 0x9F and _crystal_commands():
		## Crystal inserts verbosegiveitemvar at this raw byte. Normalizing first
		## turns it into pokegold's swarm command.
		var quantity_result: Dictionary = _read_runtime_variable(
			int(command.get("variable", 0))
		)
		if not bool(quantity_result.get("ok", false)):
			return quantity_result
		var variable_item: int = int(command.get("item", 0))
		var variable_name: String = data.item_name(variable_item) if data != null else ""
		_set_text_buffer(
			RomLayout.STRING_BUFFER_4, variable_name, &"item_name",
			{"item": variable_item}
		)
		var variable_given: Dictionary = _stage_item_delta(variable_item, _script_value)
		if not bool(variable_given.get("ok", true)):
			return variable_given
		return _stage_give_item_script(variable_item, variable_name)
	return {}


const CRYSTAL_NAME_COMMANDS: Dictionary = {
	0xA5: &"_command_getlandmarkname",
	0xA6: &"_command_gettrainerclassname",
	0xA7: &"_command_getname",
}

const NAME_TYPE_MON: int = 1
const NAME_TYPE_MOVE: int = 2
const NAME_TYPE_ITEM: int = 4
const NAME_TYPE_TRAINER: int = 7


func _command_getlandmarkname(command: Dictionary) -> Dictionary:
	var landmark: int = int(command.get("landmark", 0))
	_set_text_buffer(
		int(command.get("string_buffer", 0)),
		data.landmark_name(landmark) if data != null else "",
		&"landmark_name", {"landmark": landmark}
	)
	return {"ok": true}


func _command_gettrainerclassname(command: Dictionary) -> Dictionary:
	return _fill_name_buffer(
		NAME_TYPE_TRAINER, int(command.get("trainer_group", 0)),
		int(command.get("string_buffer", 0))
	)


func _command_getname(command: Dictionary) -> Dictionary:
	return _fill_name_buffer(
		int(command.get("name_type", 0)), int(command.get("value", 0)),
		int(command.get("string_buffer", 0))
	)


func _fill_name_buffer(name_type: int, index: int, buffer: int) -> Dictionary:
	var named: String = ""
	if data != null:
		match name_type:
			NAME_TYPE_MON:
				named = String(data.species(index).get("name", ""))
			NAME_TYPE_MOVE:
				named = String(data.move(index).get("name", ""))
			NAME_TYPE_ITEM:
				named = data.item_name(index)
			NAME_TYPE_TRAINER:
				named = data.trainer_name(index)
	_set_text_buffer(
		buffer, named, &"object_name", {"name_type": name_type, "index": index}
	)
	return {"ok": true}


func _command_xycompare(_opcode: int, _command: Dictionary, _bank: int) -> Dictionary:
	return {"ok": true}


func _command_scall(_opcode: int, command: Dictionary, bank: int) -> Dictionary:
	return {"ok": _push_frame(bank, int(command["address"]))}


func _command_farscall(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	return {"ok": _push_frame(int(command["bank"]), int(command["address"]))}


func _command_memcall(opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	var runtime_pointer: Dictionary = _runtime_memory_pointer(
		int(command.get("address", 0))
	)
	if runtime_pointer.is_empty():
		return {
			"ok": false, "reason": &"missing_runtime_pointer",
			"address": int(command.get("address", 0)), "command": command,
		}
	var pointer_bank: int = int(runtime_pointer.get("bank", -1))
	var pointer_address: int = int(runtime_pointer.get("address", -1))
	if opcode == Gen2WorldScript.MEMCALL:
		if not _push_frame(pointer_bank, pointer_address):
			return {
				"ok": false, "reason": &"missing_runtime_script",
				"bank": pointer_bank, "address": pointer_address,
			}
		return {"ok": true}
	var jump_result: Dictionary = _replace_frame(pointer_bank, pointer_address)
	return jump_result


## `Script_warpmod` writes `wBackupWarpNumber`, `wBackupMapGroup` and
## `wBackupMapNumber` outright, which is how a map whose only exit is a -1 warp is
## given one before the player can reach it: both dept store elevators and the Fast
## Ship's cabin are entered by a script that runs this first.
func _command_warpmod(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	_emit_runtime_event(&"backup_warp_changed", {
		"warp": int(command.get("warp_id", 0)),
		"map_group": int(command.get("map_group", 0)),
		"map_number": int(command.get("map_number", 0)),
	})
	return {"ok": true}


## `Script_blackoutmod` writes `wLastSpawnMapGroup` and `wLastSpawnMapNumber`, which
## is the pair `GetWhiteoutSpawn` reads back through `IsSpawnPoint`. Writing it here
## is what makes a scripted destination reach the blackout: nothing else consults the
## command.
func _command_blackoutmod(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	_emit_runtime_event(&"blackout_destination_changed", {
		"map_group": int(command.get("map_group", 0)),
		"map_number": int(command.get("map_number", 0)),
	})
	return {"ok": true}


func _command_sjump(_opcode: int, command: Dictionary, bank: int) -> Dictionary:
	return _replace_frame(bank, int(command["address"]))


func _command_farsjump(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	return _replace_frame(int(command["bank"]), int(command["address"]))


func _command_ifequal(_opcode: int, command: Dictionary, bank: int) -> Dictionary:
	return _branch(int(_script_value) == int(command["value"]), bank, int(command["address"]))


func _command_ifnotequal(_opcode: int, command: Dictionary, bank: int) -> Dictionary:
	return _branch(int(_script_value) != int(command["value"]), bank, int(command["address"]))


func _command_iffalse(_opcode: int, command: Dictionary, bank: int) -> Dictionary:
	return _branch(_script_value == 0, bank, int(command["address"]))


func _command_iftrue(_opcode: int, command: Dictionary, bank: int) -> Dictionary:
	return _branch(_script_value != 0, bank, int(command["address"]))


func _command_ifgreater(_opcode: int, command: Dictionary, bank: int) -> Dictionary:
	return _branch(_script_value > int(command["value"]), bank, int(command["address"]))


func _command_ifless(_opcode: int, command: Dictionary, bank: int) -> Dictionary:
	return _branch(_script_value < int(command["value"]), bank, int(command["address"]))


func _command_jumpstd(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	if int(command["address"]) == STD_STRENGTH_BOULDER:
		return _stage_strength_boulder()
	if int(command["address"]) == STD_SMASH_ROCK:
		return _stage_smash_rock()
	var jump_standard: Dictionary = _standard_script(int(command["address"]))
	if jump_standard.is_empty():
		return {
			"ok": false,
			"reason": &"missing_standard_script",
			"standard_index": int(command["address"]),
		}
	return _replace_frame(
		int(jump_standard["bank"]), int(jump_standard["address"]),
		jump_standard["data"]
	)


func _command_callstd(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	if int(command["address"]) == STD_STRENGTH_BOULDER:
		return _stage_strength_boulder()
	if int(command["address"]) == STD_SMASH_ROCK:
		return _stage_smash_rock()
	var call_standard: Dictionary = _standard_script(int(command["address"]))
	if call_standard.is_empty():
		return {
			"ok": false,
			"reason": &"missing_standard_script",
			"standard_index": int(command["address"]),
		}
	return {
		"ok": _push_frame(
			int(call_standard["bank"]), int(call_standard["address"]),
			call_standard["data"]
		)
	}


func _command_checkmapscene(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	_script_value = _map_scene_value(
		int(command["map_group"]), int(command["map_number"])
	)
	return {"ok": true}


func _command_setmapscene(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	var target_key: String = Gen2WorldState.map_scene_key(
		int(command["map_group"]), int(command["map_number"])
	)
	_staged_scenes[target_key] = int(command["scene"])
	return {"ok": true}


func _command_checkscene(_opcode: int, _command: Dictionary, _bank: int) -> Dictionary:
	_script_value = _map_scene_value(
		int(_request.get("map_group", 0)), int(_request.get("map_number", 0))
	)
	return {"ok": true}


func _command_setscene(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	var map_key: String = Gen2WorldState.map_scene_key(
		int(_request.get("map_group", 0)), int(_request.get("map_number", 0))
	)
	_staged_scenes[map_key] = int(command["scene"])
	return {"ok": true}


## Script_checkver answers GS_VERSION, which `constants/misc_constants.asm` defines as
## 0 for Gold and 1 for Silver; pokecrystal defines it 0 unconditionally.
func _command_checkver(_opcode: int, _command: Dictionary, _bank: int) -> Dictionary:
	_script_value = 1 if data != null and data.id == &"silver" else 0
	return {"ok": true}


func _command_setval(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	_script_value = int(command["value"])
	return {"ok": true}


## Script_addval adds into wScriptVar, one byte, so it wraps there and not only where
## the value is later written. Goldenrod's switch room turns a switch off with `addval
## -1` and branches on it.
func _command_addval(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	_script_value = (_script_value + int(command["value"])) & 0xFF
	return {"ok": true}


func _command_readmem(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	_script_value = _script_memory_value(int(command["address"]))
	return {"ok": true}


func _command_writemem(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	return _stage_script_memory(int(command["address"]), _script_value)


func _command_loadmem(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	return _stage_script_memory(int(command["address"]), int(command["value"]))


func _command_readvar(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	return _read_runtime_variable(int(command["value"]))


func _command_writevar(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	return _write_runtime_variable(int(command["value"]))


func _command_loadvar(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	return _load_runtime_variable(
		int(command["value"]), int(command["value_2"])
	)


func _command_checktime(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	_script_value = 1 if Gen2WorldPhoneHost.time_mask_matches(
		int(command["value"]), _clock_hour()
	) else 0
	return {"ok": true}


func _command_addcellnum(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	return _stage_phone_contact(int(command["value"]))


func _command_delcellnum(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	return _stage_phone_contact(int(command["value"]), false)


func _command_checkcellnum(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	_script_value = 1 if _phone_contact_registered(int(command["value"])) else 0
	return {"ok": true}


func _command_special(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	return _execute_special(
		Gen2WorldScript.special_index(int(command["value"]), _crystal_commands())
	)


func _command_random(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	var maximum: int = int(command["value"])
	_script_value = _random.randi_range(0, maximum - 1) if maximum > 0 else 0
	return {"ok": true}


func _command_giveitem(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	return _stage_item_delta(int(command["value"]), int(command["value_2"]))


func _command_takeitem(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	return _stage_item_delta(int(command["value"]), -int(command["value_2"]))


func _command_checkitem(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	_script_value = 1 if _item_quantity(int(command["value"])) > 0 else 0
	return {"ok": true}


func _command_givemoney(opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	return _stage_money_delta(
		int(command["account"]), _decode_bcd(command["amount_bytes"]),
		opcode == Gen2WorldScript.GIVEMONEY
	)


func _command_checkmoney(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	_script_value = _compare_amount(
		_money_balance(int(command["account"])),
		_decode_bcd(command["amount_bytes"])
	)
	return {"ok": true}


func _command_givecoins(opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	return _stage_coins_delta(
		int(command["value"]), opcode == Gen2WorldScript.GIVECOINS
	)


func _command_checkcoins(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	_script_value = _compare_amount(_coins_value(), int(command["value"]))
	return {"ok": true}


func _command_getmoney(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	var money: int = _money_balance(int(command["account"]))
	_set_text_buffer(int(command["string_buffer"]), str(money), &"money")
	_emit_runtime_event(&"text_value_requested", {
		"value_kind": &"money", "account": int(command["account"]),
		"value": money,
		"string_buffer": int(command["string_buffer"]),
	})
	return {"ok": true}


func _command_getcoins(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	var coins: int = _coins_value()
	_set_text_buffer(int(command["string_buffer"]), str(coins), &"coins")
	_emit_runtime_event(&"text_value_requested", {
		"value_kind": &"coins", "value": coins,
		"string_buffer": int(command["string_buffer"]),
	})
	return {"ok": true}


func _command_getitemname(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	_set_text_buffer(
		int(command["string_buffer"]),
		data.item_name(int(command["item"])) if data != null else "",
		&"item_name",
		{"item": int(command["item"])}
	)
	_emit_runtime_event(&"text_buffer_requested", command)
	return {"ok": true}


func _command_getmonname(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	_set_text_buffer(
		int(command["string_buffer"]),
		String(data.species(int(command["pokemon"])).get("name", "")) if data != null else "",
		&"mon_name",
		{"pokemon": int(command["pokemon"])}
	)
	_emit_runtime_event(&"text_buffer_requested", command)
	return {"ok": true}


func _command_gettrainername(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	var trainer_name: String = ""
	if data != null:
		trainer_name = String(data.trainer_party(
			int(command["trainer_group"]), int(command["trainer_id"]) - 1
		).get("name", ""))
	_set_text_buffer(
		int(command["string_buffer"]), trainer_name, &"trainer_name",
		{"trainer_group": int(command["trainer_group"]), "trainer_id": int(command["trainer_id"])}
	)
	_emit_runtime_event(&"text_buffer_requested", command)
	return {"ok": true}


## `Script_getstring` is `CopyName1`, which copies a plain character run up to its
## `@`. It is not a text: the first byte of `PokegearName` is `#`, which the command
## layer reads as an unknown command and refuses, so decoding this the way `writetext`
## is decoded leaves every `getstring` buffer empty and prints "<PLAYER> received !"
## with a hole where the name belongs.
func _command_getstring(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	var string_text: String = ""
	if data != null:
		var string_data: PackedByteArray = data.world_text(
			int(_request.get("bank", 0)), int(command["address"])
		)
		string_text = Gen2Text.decode(string_data, 0, string_data.size())
	_set_text_buffer(int(command["string_buffer"]), string_text, &"string", {
		"bank": int(_request.get("bank", 0)), "address": int(command["address"]),
	})
	_emit_runtime_event(&"text_buffer_requested", command)
	return {"ok": true}


func _command_clearevent(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	_staged_flags[int(command["flag"])] = false
	return {"ok": true}


func _command_setevent(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	_staged_flags[int(command["flag"])] = true
	return {"ok": true}


func _command_checkevent(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	_script_value = 1 if _event_flag_active(int(command["flag"])) else 0
	return {"ok": true}


func _command_clearflag(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	_staged_engine_flags[int(command["flag"])] = false
	return {"ok": true}


func _command_setflag(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	_staged_engine_flags[int(command["flag"])] = true
	return {"ok": true}


func _command_checkflag(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	_script_value = 1 if _engine_flag_active(int(command["flag"])) else 0
## `Script_wildon` and `Script_wildoff`, which write
## `STATUSFLAGS_NO_WILD_ENCOUNTERS_F` outright rather than through a
## staged flag: it is scratch the next map entry does not clear, and the
## scripts that turn it off all turn it back on themselves.
	return {"ok": true}


func _command_wildon(_opcode: int, _command: Dictionary, _bank: int) -> Dictionary:
	_emit_runtime_event(&"wild_encounters_changed", {"enabled": true})
	return {"ok": true}


func _command_wildoff(_opcode: int, _command: Dictionary, _bank: int) -> Dictionary:
	_emit_runtime_event(&"wild_encounters_changed", {"enabled": false})
	return {"ok": true}


func _command_warp(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	return _stage_warp(command)


## `Script_closetext` takes the box down, so nothing stands behind a later choice;
## leaving the last question there would print it under an unrelated menu.
func _command_opentext(opcode: int, _command: Dictionary, _bank: int) -> Dictionary:
	if opcode == Gen2WorldScript.CLOSETEXT:
		_standing_text = ""
		## The balance windows are tilemap, so the redraw behind the box
		## is what takes them away too.
		if _money_window != &"":
			_money_window = &""
			_emit_runtime_event(&"money_window_closed", {})
	return {"ok": true}


## `CurItemName` reads wCurItem, which whichever `giveitem` came before this wrote.
func _command_itemnotify(_opcode: int, _command: Dictionary, _bank: int) -> Dictionary:
	return _stage_item_notify(_last_item, false)


func _command_pocketisfull(_opcode: int, _command: Dictionary, _bank: int) -> Dictionary:
	return _stage_pocket_is_full(_last_item, false)


func _command_writetext(_opcode: int, command: Dictionary, bank: int) -> Dictionary:
	return _show_text(bank, int(command["address"]), false)


func _command_farwritetext(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	return _show_text(int(command["bank"]), int(command["address"]), false)


## `Script_jumptextfaceplayer` jumps to JumpTextFacePlayerScript, whose first command
## is `faceplayer`; `jumptext` and `farjumptext` enter the same script one command
## later, at JumpTextScript. The four commands after it are `opentext`, `repeattext
## -1, -1`, `waitbutton` and `closetext`, which is what _show_text spends.
func _command_jumptextfaceplayer(_opcode: int, command: Dictionary, bank: int) -> Dictionary:
	_face_player()
	return _show_text(bank, int(command["address"]), true)


func _command_repeattext(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	if int(command["value"]) == 0xFF and int(command["value_2"]) == 0xFF:
		if _last_text.is_empty():
			return {"ok": false, "reason": &"repeat_without_text"}
		return _show_text(int(_last_text["bank"]), int(_last_text["address"]), false)
	return {"ok": true}


func _command_yesorno(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	return _stage_choice(command, [&"yes", &"no"])


func _command_loadmenu(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	_loaded_menu = {
		"bank": int(_request.get("bank", 0)),
		"address": int(command["address"]),
	}
	if data != null:
		var cached_menu: Dictionary = data.world_menu(
			int(_request.get("bank", 0)), int(command["address"])
		)
		for key: String in cached_menu:
			_loaded_menu[key] = cached_menu[key]
	_emit_runtime_event(&"menu_loaded", _loaded_menu)
	return {"ok": true}


## Script_checkpoke sets wScriptVar from whether the species is in wPartySpecies
## (engine/overworld/scripting.asm). The read-only party summary is the only party
## this scene-free runner may read, and an absent one fails the way VAR_PARTYCOUNT
## does. A summary carrying an empty species list answers 0, not a failure.
func _command_checkpoke(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	var party: Dictionary = _request.get("party", {})
	if party.is_empty():
		return {"ok": false, "reason": &"missing_party_summary", "command": command}
	var species: Array = party.get("species", [])
	_script_value = 1 if int(command.get("value", 0)) in species else 0
	return {"ok": true}


## Both write their species operand to wCurPartySpecies before the routine runs,
## whether or not the party had room for it.
func _command_givepoke(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	_cur_party_species = int(command.get("pokemon", 0))
	return _stage_runtime_request(&"pokemon_requested", command)


func _command_givepokemail(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	return _give_poke_mail(command)


func _command_checkpokemail(_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	return _check_poke_mail(command)


## A command whose numbers a mod may have moved, substituted before it runs.
##
## The site is addressed by the byte it sits at, `frame.address + offset`, which
## is exactly the id [Gen2WorldCatalog] gave it. Only the OPERANDS change: the
## command still runs, its script still sets its own completion flag, prints its
## own dialogue and takes its own money, and nothing here can replace any of
## that. A cartridge with no mod patch pays one dictionary read.
func _catalogued(command: Dictionary, frame: Dictionary) -> Dictionary:
	if data == null or not data.has_content_overlay():
		return command
	var linked: Dictionary = data.catalog().link_at(
		int(frame["bank"]), int(frame["address"]) + int(command["offset"])
	)
	if not linked.is_empty():
		return _linked_command(command, linked)
	var candidates: Array = CATALOG_KINDS.get(StringName(command["name"]), [])
	if candidates.is_empty():
		return command
	var at: int = int(frame["address"]) + int(command["offset"])
	var row: Dictionary = {}
	var kind: StringName = &""
	for candidate: StringName in candidates:
		row = data.catalog().check(
			Gen2WorldCatalog.pack_id(candidate, int(frame["bank"]), at)
		)
		if not row.is_empty():
			kind = candidate
			break
	if row.is_empty():
		return command
	var out: Dictionary = command.duplicate(true)
	match kind:
		Gen2WorldCatalog.KIND_STATIC:
			out["pokemon"] = int(row["species"])
			out["level"] = int(row["level"])
		Gen2WorldCatalog.KIND_SHOP:
			out["address"] = int(row["mart"])
			## The inventory this site sells, carried to the mart host so a
			## patched shelf reaches the shop rather than a different mart id.
			out["mart_items"] = row.get("items", [])
		Gen2WorldCatalog.KIND_TRADE:
			out["value"] = int(row["trade"])
			## Both halves, carried beside the record rather than written into
			## it: one cartridge trade row can be named by two sites.
			out["offered_species"] = int(row["species"])
			out["requested_species"] = int(row["requested_species"])
		Gen2WorldCatalog.KIND_BADGE:
			## The badge a flag grants IS the flag, so moving one moves which
			## bit the site sets. An index outside the list leaves it alone.
			var flags: Array[int] = Gen2WorldState.BADGE_ENGINE_FLAGS \
				if Gen2WorldState.is_crystal_profile(data) \
				else Gen2WorldState.BADGE_ENGINE_FLAGS_GOLD_SILVER
			var badge: int = int(row["badge"])
			if badge >= 0 and badge < flags.size():
				out["flag"] = flags[badge]
		Gen2WorldCatalog.KIND_ITEM:
			out["item"] = int(row["item"])
			out["value"] = int(row["item"])
			out["quantity"] = maxi(1, int(row["quantity"]))
			out["value_2"] = maxi(1, int(row["quantity"]))
		_:
			## Every giving kind: a starter, a gift and a prize are one command.
			out["pokemon"] = int(row["species"])
			out["value"] = int(row["species"])
			out["level"] = int(row["level"])
			out["value_2"] = int(row["level"])
			out["item"] = int(row.get("item", command.get("item", 0)))
	return out


## A command that is not the site itself but carries one of its numbers: the
## `pokepic` a starter's ball shows, and the `checkcoins`/`takecoins` a prize
## charges with. Substituting only the `givepoke` would show one Pokemon and hand
## over another, and price a prize the player could not afford.
func _linked_command(command: Dictionary, linked: Dictionary) -> Dictionary:
	var row: Dictionary = data.catalog().check(int(linked["id"]))
	if row.is_empty():
		return command
	var out: Dictionary = command.duplicate(true)
	match StringName(linked["role"]):
		&"picture":
			out["pokemon"] = int(row["species"])
		&"price":
			out["value"] = int(row["price"])
	return out


## Which catalog kinds a command name can be a site for. `givepoke` is three at
## once, and which one it is was decided when the catalog walked the script, so
## the id is tried under each until one answers. A site the catalog never
## recorded answers empty under all of them and the command runs untouched.
const CATALOG_KINDS: Dictionary = {
	&"loadwildmon": [Gen2WorldCatalog.KIND_STATIC],
	&"trade": [Gen2WorldCatalog.KIND_TRADE],
	&"pokemart": [Gen2WorldCatalog.KIND_SHOP],
	&"setflag": [Gen2WorldCatalog.KIND_BADGE],
	&"giveitem": [Gen2WorldCatalog.KIND_ITEM],
	&"verbosegiveitem": [Gen2WorldCatalog.KIND_ITEM],
	&"givepoke": [
		Gen2WorldCatalog.KIND_GIFT, Gen2WorldCatalog.KIND_STARTER,
		Gen2WorldCatalog.KIND_PRIZE,
	],
	&"giveegg": [Gen2WorldCatalog.KIND_GIFT],
}


## The commands numbered past the two profiles' seam, as the handler that runs
## each. The key is the pokegold opcode [method Gen2WorldScript.source_opcode]
## normalizes to, so one row serves both profiles.
const LATER_HANDLERS: Dictionary = {
	0x55: &"_command_pokepic",
	0x56: &"_command_closepokepic",
	0x57: &"_command_two_d_menu",
	0x58: &"_command_two_d_menu",
	0x59: &"_command_loadpikachudata",
	0x5A: &"_command_randomwildmon",
	0x5B: &"_command_loadtemptrainer",
	0x5C: &"_command_loadwildmon",
	0x5D: &"_command_loadtrainer",
	0x5E: &"_command_startbattle",
	0x5F: &"_command_reloadmapafterbattle",
	0x60: &"_command_catchtutorial",
	0x61: &"_command_trainertext",
	0x62: &"_command_trainerflagaction",
	0x63: &"_command_winlosstext",
	0x64: &"_command_scripttalkafter",
	0x65: &"_command_endifjustbattled",
	0x66: &"_command_checkjustbattled",
	0x73: &"_command_loademote",
	0x74: &"_command_showemote",
	0x77: &"_command_earthquake",
	0x78: &"_command_changemapblocks",
	0x79: &"_command_changeblock",
	0x7A: &"_command_reloadmap",
	0x7B: &"_command_refreshmap",
	0x7C: &"_command_writecmdqueue",
	0x7D: &"_command_delcmdqueue",
	0x7E: &"_command_playmusic",
	0x7F: &"_command_encountermusic",
	0x80: &"_command_musicfadeout",
	0x81: &"_command_playmapmusic",
	0x82: &"_command_dontrestartmapmusic",
	0x83: &"_command_cry",
	0x84: &"_command_playsound",
	0x85: &"_command_waitsfx",
	0x86: &"_command_warpsound",
	0x87: &"_command_specialsound",
	0x6C: &"_command_variablesprite",
	0x8A: &"_command_pause",
	0x8B: &"_command_pause",
	0x88: &"_command_autoinput",
	0x89: &"_command_newloadmap",
	0x8C: &"_command_sdefer",
	0x8D: &"_command_warpcheck",
	0x8E: &"_command_stopandsjump",
	0x91: &"_command_reloadend",
	0x92: &"_command_endall",
	0x93: &"_command_pokemart",
	0x94: &"_command_elevator",
	0x95: &"_command_trade",
	0x96: &"_command_askforphonenumber",
	0x97: &"_command_phonecall",
	0x98: &"_command_hangup",
	0x99: &"_command_describedecoration",
	0x9A: &"_command_fruittree",
	0x9B: &"_command_specialphonecall",
	0x9C: &"_command_checkphonecall",
	0x9D: &"_command_verbosegiveitem",
	0x9E: &"_command_swarm",
	0x9F: &"_command_halloffame",
	0xA0: &"_command_credits",
	0xA1: &"_command_warpfacing",
	0xA2: &"_command_battletowertext",
}


func _execute_later_command(
	source_opcode: int, command: Dictionary, bank: int
) -> Dictionary:
	if not LATER_HANDLERS.has(source_opcode):
		return {}
	return call(LATER_HANDLERS[source_opcode], source_opcode, command, bank)


## `Script_pokepic` takes wScriptVar when its operand is zero and writes whichever it
## settled on to wCurPartySpecies, which is what a later `special PlayCurMonCry`
## reads.
func _command_pokepic(_source_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	var pic_species: int = int(command.get("pokemon", 0))
	if pic_species == 0:
		pic_species = _script_value
	_cur_party_species = pic_species
	_emit_runtime_event(&"pokemon_picture_requested", {
		"pokemon": pic_species,
	})
	return {"ok": true}


func _command_closepokepic(_source_opcode: int, _command: Dictionary, _bank: int) -> Dictionary:
	_emit_runtime_event(&"pokemon_picture_closed", {})
	return {"ok": true}


func _command_two_d_menu(source_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	return _stage_menu(source_opcode == 0x57, command)


func _command_loadpikachudata(_source_opcode: int, _command: Dictionary, _bank: int) -> Dictionary:
	_battle_setup = _new_battle_setup({
		"kind": &"wild", "pokemon": PIKACHU, "level": PIKACHU_DEBUG_LEVEL,
	})
	_emit_runtime_event(&"battle_setup_changed", _battle_setup)
	return {"ok": true}


func _command_randomwildmon(_source_opcode: int, _command: Dictionary, _bank: int) -> Dictionary:
	return {"ok": true}


func _command_autoinput(_source_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	_emit_runtime_event(&"auto_input_requested", {
		"bank": int(command.get("bank", 0)),
		"address": int(command.get("address", 0)),
	})
	return {"ok": true}


func _command_stopandsjump(_source_opcode: int, command: Dictionary, bank: int) -> Dictionary:
	var jumped: Dictionary = _replace_frame(bank, int(command.get("address", 0)))
	if not bool(jumped.get("ok", false)):
		return jumped
	return _stage_frame_wait(Gen2WorldAPI.passes_in_frames(1))


func _command_reloadend(source_opcode: int, command: Dictionary, bank: int) -> Dictionary:
	var reloaded: Dictionary = _command_newloadmap(source_opcode, command, bank)
	if not bool(reloaded.get("ok", false)):
		return reloaded
	_frames.pop_back()
	if _frames.is_empty():
		return _complete()
	return {"ok": true}


func _command_endall(_source_opcode: int, _command: Dictionary, _bank: int) -> Dictionary:
	_frames.clear()
	return _complete()


func _command_loadtemptrainer(_source_opcode: int, _command: Dictionary, bank: int) -> Dictionary:
	var trainer_value: Variant = _request.get("trainer", {})
	if trainer_value is Dictionary and not (trainer_value as Dictionary).is_empty():
		var trainer: Dictionary = trainer_value as Dictionary
		_battle_setup = _new_battle_setup({
			"kind": &"trainer",
			"trainer_group": int(trainer.get("trainer_group", 0)),
			"trainer_id": maxi(int(trainer.get("trainer_id", 0)) - 1, 0),
			"trainer_flag": int(trainer.get("event_flag", -1)),
			"win_text": _trainer_text_pointer(trainer, "win_text", bank),
			"loss_text": _trainer_text_pointer(trainer, "loss_text", bank),
		})
		_emit_runtime_event(&"battle_setup_changed", _battle_setup)
	return {"ok": true}


func _command_loadwildmon(_source_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	_battle_setup = _new_battle_setup({
		"kind": &"wild", "pokemon": int(command.get("pokemon", 0)),
		"level": int(command.get("level", 0)),
	})
	_emit_runtime_event(&"battle_setup_changed", _battle_setup)
	return {"ok": true}


func _command_loadtrainer(_source_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	_loaded_battle_type = -1
	_battle_setup = _new_battle_setup({
		"kind": &"trainer", "trainer_group": int(command.get("trainer_group", 0)),
		# The cartridge's loadtrainer operand is one-based; the imported
		# party table API is zero-based.
		"trainer_id": maxi(int(command.get("trainer_id", 0)) - 1, 0),
	})
	_emit_runtime_event(&"battle_setup_changed", _battle_setup)
	return {"ok": true}


func _command_startbattle(_source_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	if _battle_setup.is_empty():
		return {
			"ok": false, "reason": &"battle_setup_missing", "command": command,
		}
	return _stage_runtime_request(&"battle_requested", _battle_request_values())


func _command_reloadmapafterbattle(_source_opcode: int, _command: Dictionary, _bank: int) -> Dictionary:
	_emit_runtime_event(&"battle_map_reload_requested", {"requested": true})
	return {"ok": true}


func _command_catchtutorial(_source_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	var tutorial_setup: Dictionary = _battle_setup.duplicate(true)
	if tutorial_setup.is_empty() or StringName(tutorial_setup.get("kind", &"")) != &"wild":
		return {"ok": false, "reason": &"tutorial_battle_setup_missing"}
	tutorial_setup["tutorial"] = true
	tutorial_setup["battle_type"] = int(command.get("value", 0))
	tutorial_setup["can_lose"] = false
	return _stage_runtime_request(&"catch_tutorial_requested", tutorial_setup)


func _command_trainertext(_source_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	return _stage_runtime_request(&"trainer_text_requested", {
		"text_id": int(command.get("value", 0)),
		"setup": _battle_setup.duplicate(true),
	})


func _command_trainerflagaction(_source_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	var trainer_event: Dictionary = _request.get("event", {})
	var trainer_data: Variant = _request.get("trainer", {})
	var trainer_flag: int = int(trainer_event.get("event_flag", 0))
	if trainer_data is Dictionary and not (trainer_data as Dictionary).is_empty():
		trainer_flag = int((trainer_data as Dictionary).get("event_flag", -1))
	var action: int = int(command.get("value", 0))
	if action == 0:
		_staged_flags[trainer_flag] = false
	elif action == 1:
		_staged_flags[trainer_flag] = true
	elif action == 2:
		_script_value = 1 if _event_flag_active(trainer_flag) else 0
	else:
		return {"ok": false, "reason": &"unsupported_trainer_flag_action", "action": action}
	_emit_runtime_event(&"trainer_flag_action", {
		"action": action, "event_flag": trainer_flag,
		"script_value": _script_value,
	})
	return {"ok": true}


func _command_winlosstext(_source_opcode: int, command: Dictionary, bank: int) -> Dictionary:
	_battle_setup["win_text"] = {
		"bank": bank, "address": int(command.get("win_address", 0)),
	}
	_battle_setup["loss_text"] = {
		"bank": bank, "address": int(command.get("loss_address", 0)),
	}
	return {"ok": true}


## Script_scripttalkafter jumps to wScriptAfterPointer in wSeenTrainerBank, which is
## the map's own script bank here. A record without one leaves the script to end,
## since the source always writes the pointer the trainer macro carries.
func _command_scripttalkafter(_source_opcode: int, _command: Dictionary, bank: int) -> Dictionary:
	var after_trainer: Variant = _request.get("trainer", {})
	var after_address: int = int((after_trainer as Dictionary).get("after_script", 0)) \
		if after_trainer is Dictionary else 0
	_emit_runtime_event(&"trainer_talk_after_requested", {
		"bank": bank, "address": after_address,
	})
	if after_address > 0:
		_frames.clear()
		if not _push_frame(bank, after_address):
			return {
				"ok": false, "reason": &"missing_trainer_after_script",
				"bank": bank, "address": after_address,
			}
	return {"ok": true}


func _command_endifjustbattled(_source_opcode: int, _command: Dictionary, _bank: int) -> Dictionary:
	if not _just_battled():
		return {"ok": true}
	_frames.pop_back()
	if _frames.is_empty():
		return _complete()
	return {"ok": true}


func _command_checkjustbattled(_source_opcode: int, _command: Dictionary, _bank: int) -> Dictionary:
	_script_value = 1 if _just_battled() else 0
	return {"ok": true}


func _command_loademote(_source_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	_loaded_emote = int(command.get("value", -1))
	if _loaded_emote == 0xFF:
		_loaded_emote = _script_value
	_emit_runtime_event(&"emote_loaded", {"emote_id": _loaded_emote})
	return {"ok": true}


## Script_showemote is `ScriptCall ShowEmoteScript`: loademote, an applymovement that
## shows the emote, `pause 0` over the delay this command just wrote, and an
## applymovement that hides it again. The two one-command movements are folded into
## the emote event and its hide; the pause is the wait, and it is what the operand
## measures.
func _command_showemote(_source_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	var emote_id: int = int(command.get("value", _loaded_emote))
	if emote_id == 0xFF:
		emote_id = _loaded_emote
	_loaded_emote = emote_id
	## `cp LAST_TALKED / jr z` keeps hLastTalked as it was only when the
	## operand is LAST_TALKED itself; every other id becomes the new one,
	## which is what the two `applymovementlasttalked`s inside
	## ShowEmoteScript then move.
	var emote_object_id: int = int(command.get("object_id", 0))
	if emote_object_id != LAST_TALKED:
		_last_talked_object_index = _object_index_from_id(emote_object_id)
	var emote_object: int = _object_index_from_id(emote_object_id)
	_script_delay = int(command.get("value_2", 0))
	_emit_object_event(&"object_emote", {
		"object_index": emote_object,
		"emote_id": emote_id,
		"visible": true,
		## Zero is "until the hide", not "for no time": the source takes the
		## emote down from ShowEmoteScript's last command, not on a counter.
		"duration": 0,
	})
	return _stage_frame_wait(
		_script_delay * PAUSE_FRAMES_PER_UNIT,
		{"hide_emote_object": emote_object, "emote_id": emote_id}
	)


func _command_earthquake(_source_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	return _stage_earthquake(int(command.get("value", 0)))


## `Script_earthquake` is `ScriptCall` on `applymovement PLAYER,
## wEarthquakeMovementDataBuffer`; its sleep is in passes like every movement.
func _stage_earthquake(value: int, values: Dictionary = {}) -> Dictionary:
	_emit_object_event(&"player_movement_requested", {
		"bank": int(_request.get("bank", 0)),
		"movement": Gen2WorldMovement.earthquake_stream(value),
	})
	var wait: Dictionary = {"object_index": Gen2WorldObject.PLAYER_INDEX}
	for key: Variant in values:
		wait[key] = values[key]
	return _stage_movement_wait(wait)


func _command_changemapblocks(_source_opcode: int, command: Dictionary, bank: int) -> Dictionary:
	_emit_runtime_event(&"map_blocks_requested", {
		"bank": bank, "address": int(command.get("address", 0)),
	})
	return {"ok": true}


func _command_changeblock(_source_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	_emit_runtime_event(&"map_block_changed", {
		"x": int(command.get("x", 0)), "y": int(command.get("y", 0)),
		"block": int(command.get("block", 0)),
	})
	return {"ok": true}


func _command_reloadmap(_source_opcode: int, _command: Dictionary, _bank: int) -> Dictionary:
	_emit_runtime_event(&"map_reload_requested", {})
	return {"ok": true}


func _command_refreshmap(_source_opcode: int, _command: Dictionary, _bank: int) -> Dictionary:
	_emit_runtime_event(&"map_refresh_requested", {})
	return {"ok": true}


func _command_writecmdqueue(_source_opcode: int, command: Dictionary, bank: int) -> Dictionary:
	_emit_runtime_event(&"command_queue_written", {
		"bank": bank, "address": int(command.get("address", 0)),
	})
	return {"ok": true}


func _command_delcmdqueue(_source_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	_script_value = 1
	_emit_runtime_event(&"command_queue_deleted", {
		"queue_id": int(command.get("value", -1)),
	})
	return {"ok": true}


func _command_playmusic(_source_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	return _stage_audio_request(&"music", {
		"address": int(command.get("address", 0)),
	})


func _command_encountermusic(_source_opcode: int, _command: Dictionary, _bank: int) -> Dictionary:
	return _stage_audio_request(&"encounter_music", {})


func _command_musicfadeout(_source_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	return _stage_audio_request(&"music_fadeout", {
		"music": int(command.get("value", 0)),
		"fade_time": int(command.get("value_2", 0)),
	})


func _command_playmapmusic(_source_opcode: int, _command: Dictionary, _bank: int) -> Dictionary:
	return _stage_audio_request(&"map_music", {})


func _command_dontrestartmapmusic(_source_opcode: int, _command: Dictionary, _bank: int) -> Dictionary:
	_emit_runtime_event(&"map_music_restart_disabled", {})
	return {"ok": true}


func _command_cry(_source_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	return _stage_audio_request(&"cry", {"species": int(command.get("value", 0))})


func _command_playsound(_source_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	return _stage_audio_request(&"sound", {"address": int(command.get("value", 0))})


func _command_waitsfx(_source_opcode: int, _command: Dictionary, _bank: int) -> Dictionary:
	return _stage_audio_request(&"sound_wait", {})


func _command_warpsound(_source_opcode: int, _command: Dictionary, _bank: int) -> Dictionary:
	return _stage_audio_request(&"warp_sound", {
		"collision": int(_request.get("collision", -1)),
	})


func _command_specialsound(_source_opcode: int, _command: Dictionary, _bank: int) -> Dictionary:
	return _stage_audio_request(&"special_sound", {"item": _last_item})


## variablesprite stores a sprite id in the source's variable-sprite table. The first
## operand is an index relative to SPRITE_VARS.
func _command_variablesprite(_source_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	_emit_runtime_event(&"variable_sprite_changed", {
		"variable_sprite": VARIABLE_SPRITE_BASE + int(command.get("value", 0)),
		"sprite": int(command.get("value_2", 0)),
	})
	return {"ok": true}


## Both write wScriptDelay when their operand is nonzero and reuse whatever is in it
## when it is zero, and both cost two hardware frames a unit: `Script_pause`
## spends `DelayFrames 2` inside the command, and SCRIPT_WAIT's own `WaitScript`
## runs once per overworld pass.
func _command_pause(source_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	var delay_operand: int = int(command.get("value", 0))
	if delay_operand != 0:
		_script_delay = delay_operand
	var delay_frames: int = _script_delay * PAUSE_FRAMES_PER_UNIT \
		if source_opcode == 0x8A else Gen2WorldAPI.passes_in_frames(_script_delay)
	_emit_runtime_event(&"script_timing_requested", {
		"kind": &"pause" if source_opcode == 0x8A else &"deactivate_facing",
		"value": delay_operand,
		"frames": delay_frames,
	})
	return _stage_frame_wait(delay_frames)


func _command_sdefer(_source_opcode: int, command: Dictionary, bank: int) -> Dictionary:
	_ran_deferred = true
	if not _push_frame(bank, int(command.get("address", 0))):
		return {
			"ok": false, "reason": &"missing_deferred_script",
			"bank": bank, "address": int(command.get("address", 0)),
		}
	return {"ok": true}


## Script_newloadmap sets hMapEntryMethod and re-enters the current map. It yields
## rather than ending: StopScript only clears SCRIPT_RUNNING in wScriptFlags, so the
## commands after it run, as FallIntoMapScript's pitfall animation shows
## (engine/overworld/events.asm). The re-entry itself is already queued here, because
## the `warpcheck` before it took a warp and every map change queues its own
## callbacks, so what is left to carry is the entry method the transition is drawn
## with.
func _command_newloadmap(_source_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	_emit_runtime_event(&"map_entry_method_requested", {
		"method": int(command.get("value", 0)),
	})
	return {"ok": true}


## Script_warpcheck runs WarpCheck against the cell the player is standing on, so the
## destination is the world's to resolve, not the script's. Burned Tower's rival scene
## opens the hole under the player and then relies on this to drop them through it.
func _command_warpcheck(_source_opcode: int, _command: Dictionary, _bank: int) -> Dictionary:
	_emit_runtime_event(&"warp_check_requested", {})
	return {"ok": true}


func _command_pokemart(_source_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	var mart: Dictionary = {
		"dialog": int(command.get("value", 0)),
		"address": int(command.get("address", 0)),
	}
	if command.has("mart_items"):
		mart["items"] = command["mart_items"]
	return _stage_runtime_request(&"mart_requested", mart)


## `Script_elevator` hands `Elevator` the pointer in `de` and the running script's own
## bank in `b`, which is where the `elevfloor` list lives.
func _command_elevator(_source_opcode: int, command: Dictionary, bank: int) -> Dictionary:
	return _stage_runtime_request(&"elevator_requested", {
		"bank": bank,
		"address": int(command.get("address", 0)),
	})


## `NPCTrade` (`engine/events/npc_trade.asm`), which `Script_trade` is a
## `farcall` to and nothing else: every word a trader says is in that routine
## rather than in the map script, and so is the once-only gate.
func _command_trade(_source_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	var trade: Dictionary = {"trade_id": int(command.get("value", 0))}
	## A patched site names both halves; an unpatched one names neither
	## and the record answers for both, as it always has.
	for key: String in ["offered_species", "requested_species"]:
		if command.has(key):
			trade[key] = int(command[key])
	var record: Dictionary = Gen2WorldPartyHost.trade_record(data, trade)
	if record.is_empty():
		return _stage_runtime_request(&"trade_requested", trade)
	_set_trade_names(record)
	## `PrintTradeText TRADE_DIALOG_INTRO` and the `YesNoBox` over it. A cache
	## with no `npc_trade` run has no conversation, so the swap settles alone.
	var asked: String = _trade_dialog_text(record, TRADE_DIALOG_INTRO)
	if asked.is_empty():
		return _stage_runtime_request(&"trade_requested", trade)
	if _npc_trade_done(int(trade["trade_id"])):
		return _trade_box(record, TRADE_DIALOG_AFTER, true)
	_pending = {
		"type": &"choice",
		"command": &"trade",
		"choices": [&"yes", &"no"],
		"text": asked,
		"special": &"npc_trade_intro",
		"trade": trade,
		"source": _request.duplicate(true),
	}
	return _waiting_result()


## `GetTradeMonNames`, run in front of every box: the wanted species into
## `wStringBuffer1` with the row's gender symbol on it, the offered one into
## `wStringBuffer2`, and the wanted name again, plain, into
## `wMonOrItemNameBuffer`.
func _set_trade_names(record: Dictionary) -> void:
	if data == null:
		return
	var wanted: String = String(
		data.species(int(record.get("requested_species", 0))).get("name", "")
	)
	_set_text_ram("mon_or_item_name", wanted)
	_set_text_buffer(
		RomLayout.STRING_BUFFER_2,
		String(data.species(int(record.get("offered_species", 0))).get("name", "")),
		&"npc_trade_names"
	)
	_set_text_buffer(
		RomLayout.STRING_BUFFER_1,
		wanted + String(TRADE_GENDER_SYMBOLS.get(int(record.get("gender", 0)), "")),
		&"npc_trade_names"
	)


## One `TradeTexts` cell. Crystal's two NEWBIE boxes sit in their own run.
func _trade_dialog_text(record: Dictionary, dialog: int) -> String:
	var name: String = RomLayout.trade_text_name(
		_crystal_commands(), dialog, int(record.get("dialog", 0))
	)
	if name.is_empty():
		return ""
	return _special_box(
		"npc_trade_newbie" if name in RomLayout.TRADE_NEWBIE_TEXTS else "npc_trade",
		name
	)


func _trade_box(
	record: Dictionary, dialog: int, finish: bool, values: Dictionary = {}
) -> Dictionary:
	var box: String = _trade_dialog_text(record, dialog)
	if box.is_empty():
		return _fail(&"missing_special_text", {"trade_dialog": dialog})
	return _stage_internal_text(box, finish, values)


## `TradeFlagAction`'s CHECK_FLAG, over the staged bit and the saved one.
func _npc_trade_done(trade_id: int) -> bool:
	if _staged_npc_trades.has(trade_id):
		return bool(_staged_npc_trades[trade_id])
	return state != null and state.npc_trade_done(trade_id)


## The `YesNoBox` behind TRADE_DIALOG_INTRO. NO is TRADE_DIALOG_CANCEL; YES opens
## the party list under PARTYMENUACTION_GIVE_MON.
func _resume_trade_intro(choice: int) -> Dictionary:
	var trade: Dictionary = (_pending.get("trade", {}) as Dictionary).duplicate()
	_pending = {}
	if choice != 0:
		return _trade_result(_trade_box(
			Gen2WorldPartyHost.trade_record(data, trade), TRADE_DIALOG_CANCEL, true
		))
	_stage_runtime_request(&"party_selection_requested", {
		"routine": &"npc_trade", "trade": trade,
	})
	return _waiting_result()


## `SelectTradeOrDayCareMon` and the two tests behind it: the row's own species
## and `CheckTradeGender`. A refusal of either is TRADE_DIALOG_WRONG.
func _finish_trade_selection(trade: Dictionary, result: Dictionary) -> Dictionary:
	var record: Dictionary = Gen2WorldPartyHost.trade_record(data, trade)
	_set_trade_names(record)
	var party_index: int = int(result.get("party_index", -1))
	if party_index < 0:
		return _trade_result(_trade_box(record, TRADE_DIALOG_CANCEL, true))
	var dvs: Array = result.get("dvs", [])
	var species: int = int(result.get("species", 0))
	var dv_word: int = ((int(dvs[0]) << 8) | int(dvs[1])) if dvs.size() >= 2 else 0
	if species != int(record.get("requested_species", 0)) \
		or not Gen2WorldPartyHost.trade_gender_matches(
			data, species, dv_word,
			int(record.get("gender", RomLayout.TRADE_GENDER_EITHER))
		):
		return _trade_result(_trade_box(record, TRADE_DIALOG_WRONG, true))
	## `ld b, SET_FLAG`, spent in front of the cable line and of the swap.
	_staged_npc_trades[int(trade["trade_id"])] = true
	var carried: Dictionary = trade.duplicate()
	carried["party_index"] = party_index
	var cable: String = _special_box("npc_trade", "cable")
	if cable.is_empty():
		return _fail(&"missing_special_text", carried)
	return _trade_result(_stage_internal_text(cable, false, {
		"npc_trade_after_cable": carried,
	}))


## `NPCTradeCableText`'s prompt, behind which `DoNPCTrade` and the movie run.
func _resume_trade_cable(_choice: int) -> Dictionary:
	var carried: Dictionary = _pending["npc_trade_after_cable"]
	_pending = {}
	_finish_after_pending = false
	_stage_runtime_request(&"trade_requested", carried)
	return _waiting_result()


## `TradedForText`, printed once the movie is over, and the three audio steps
## it and `RestartMapMusic` spend before TRADE_DIALOG_COMPLETE.
func _resume_trade_traded(_choice: int) -> Dictionary:
	var carried: Dictionary = _pending["npc_trade_after_traded"]
	_pending = {}
	_finish_after_pending = false
	return _trade_result(_stage_trade_audio(carried, 0))


func _stage_trade_audio(carried: Dictionary, step: int) -> Dictionary:
	if step >= TRADE_AFTER_TEXT_AUDIO.size():
		return _trade_box(
			Gen2WorldPartyHost.trade_record(data, carried), TRADE_DIALOG_COMPLETE, true
		)
	_npc_trade_after_sound = {"trade": carried, "step": step + 1}
	var row: Array = TRADE_AFTER_TEXT_AUDIO[step]
	return _stage_audio_request(StringName(row[0]), (row[1] as Dictionary).duplicate())


## `advance` turns a staged pending into a result, the way the Bank of Mom's
## steps are answered.
func _trade_result(staged: Dictionary) -> Dictionary:
	if staged.has("status") or not bool(staged.get("ok", false)):
		return staged
	return advance()


func _command_askforphonenumber(_source_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	return _stage_phone_choice(int(command.get("value", 0)))


func _command_phonecall(_source_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	return _stage_runtime_request(&"phone_call_requested", {
		"address": int(command.get("address", 0)),
	})


## `Script_hangup` is `HangUp` inline: seven twenty-frame waits with its own two lines
## on the box, and no button anywhere in it.
func _command_hangup(_source_opcode: int, _command: Dictionary, _bank: int) -> Dictionary:
	_emit_runtime_event(&"phone_hangup", {
		"frames": Gen2WorldPhoneRing.HANG_UP_FRAMES,
	})
	return _stage_frame_wait(
		Gen2WorldPhoneRing.HANG_UP_FRAMES, {"hang_up": true}
	)


func _command_describedecoration(_source_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	return _stage_decoration_description(int(command.get("value", 0)))


func _command_fruittree(_source_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	return _stage_fruit_tree(int(command.get("value", 0)))


## The cartridge uses specialphonecall to store the pending special call. Imported
## phone scripts also use SPECIALCALL_NONE to clear it. This command never starts the
## call directly. CheckSpecialPhoneCall consumes the staged value during a later step.
func _command_specialphonecall(_source_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	var special_call_id: int = int(command.get("address", 0))
	if not _phone_context.is_empty():
		_phone_context["special_call_id"] = special_call_id
	_staged_special_phone_call = special_call_id
	_has_staged_special_phone_call = true
	_script_value = 1
	_emit_runtime_event(&"special_phone_call_changed", {
		"call_id": special_call_id,
	})
	return {"ok": true}


func _command_checkphonecall(_source_opcode: int, _command: Dictionary, _bank: int) -> Dictionary:
	_script_value = 1 if _current_special_phone_call() != 0 else 0
	return {"ok": true}


## Script_verbosegiveitem is Script_giveitem plus `CurItemName` and a
## CopyConvertedText into STRING_BUFFER_4, which is what GiveItemScript's
## _ReceivedItemText then prints as `text_ram wStringBuffer4`. Staging the item
## without filling the buffer leaves that text unresolved.
func _command_verbosegiveitem(_source_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	var verbose_item: int = int(command.get("item", 0))
	var verbose_name: String = data.item_name(verbose_item) if data != null else ""
	_set_text_buffer(
		RomLayout.STRING_BUFFER_4, verbose_name, &"item_name",
		{"item": verbose_item}
	)
	var given: Dictionary = _stage_item_delta(
		verbose_item, int(command.get("quantity", 1))
	)
	if not bool(given.get("ok", true)):
		return given
	return _stage_give_item_script(verbose_item, verbose_name)


## Crystal's `swarm` carries which of the two swarms it is setting and pokegold's does
## not, because `StoreSwarmMapIndices` there writes one pair whatever `c` holds.
func _command_swarm(_source_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	return _stage_runtime_request(&"swarm_requested", {
		"kind": int(command.get("flag", Gen2WorldState.SWARM_DUNSPARCE)),
		"map_group": int(command.get("map_group", 0)),
		"map_number": int(command.get("map_number", 0)),
	})


func _command_halloffame(_source_opcode: int, _command: Dictionary, _bank: int) -> Dictionary:
	_staged_engine_flags[Gen2WorldState.ENGINE_HALL_OF_FAME] = true
	_events.append({"type": &"hall_of_fame_requested"})
	return {"ok": true}


## Script_credits farcalls RedCredits and then falls into Script_endall the way
## Script_halloffame does (engine/overworld/scripting.asm's ReturnFromCredits). No
## flag and no state: presentation only, and both call sites are followed by the
## source's own `end`, so this runs on rather than stopping.
func _command_credits(_source_opcode: int, _command: Dictionary, _bank: int) -> Dictionary:
	_events.append({"type": &"credits_requested"})
	return {"ok": true}


func _command_warpfacing(_source_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	return _stage_warp_facing_request(command)


## Crystal's own `battletowertext`, raw $a4. Gold and Silver's command table stops at
## $a1, so nothing of theirs reaches here.
func _command_battletowertext(_source_opcode: int, command: Dictionary, _bank: int) -> Dictionary:
	return _stage_battle_tower_text(int(command.get("value", 1)))


func _apply_movement(object_index: int, address: int) -> Dictionary:
	var walks_player: bool = object_index == Gen2WorldObject.PLAYER_INDEX
	var values: Dictionary = {
		"bank": int(_request.get("bank", 0)), "address": address,
	}
	if not walks_player:
		values["object_index"] = object_index
	_emit_object_event(
		&"player_movement_requested" if walks_player else &"object_movement_requested",
		values
	)
	return _stage_movement_wait({"object_index": object_index})


func _execute_object_command(source_opcode: int, command: Dictionary) -> Dictionary:
	match source_opcode:
		0x67:
			_last_talked_object_index = _object_index_from_id(int(command["object_id"]))
		0x68:
			return _apply_movement(
				_object_index_from_id(int(command.get("object_id", 0))),
				int(command.get("address", 0))
			)
		0x69:
			return _apply_movement(
				_last_talked_object_index, int(command.get("address", 0))
			)
		0x6A:
			_face_player()
		0x6B:
			var first_object_id: int = int(command.get("object_id", 0))
			var first_object: int = _object_index_from_id(first_object_id)
			var second_object: int = _object_index_from_id(int(command.get("object_id_2", 0)))
			if first_object_id == 0 and second_object >= 0:
				# faceobject PLAYER, LAST_TALKED faces the player toward the
				# trainer. The cache omits PLAYER from its object array.
				_emit_object_event(&"player_face_object", {
					"target_index": second_object,
				})
			elif first_object >= 0 and second_object >= 0:
				_emit_object_event(&"object_face_object", {
					"object_index": first_object,
					"target_index": second_object,
				})
		0x6D:
			_emit_object_event(&"object_visibility", {
				"object_index": _object_index_from_id(int(command.get("object_id", 0))),
				"active": false,
			})
			_emit_object_event(&"object_event_flag", {
				"object_index": _object_index_from_id(int(command.get("object_id", 0))),
				"active": true,
			})
			_stage_object_event_flag(int(command.get("object_id", 0)), true)
		0x6E:
			_emit_object_event(&"object_visibility", {
				"object_index": _object_index_from_id(int(command.get("object_id", 0))),
				"active": true,
			})
			_emit_object_event(&"object_event_flag", {
				"object_index": _object_index_from_id(int(command.get("object_id", 0))),
				"active": false,
			})
			_stage_object_event_flag(int(command.get("object_id", 0)), false)
		0x6F, 0x76:
			## `StartFollow` takes the FIRST operand through `SetLeaderIfVisible`
			## and the second through `SetFollowerIfVisible`, which is the object
			## that takes SPRITEMOVEDATA_FOLLOWING. So the first leads and the
			## second follows; the macro's own operand comments say the reverse.
			## Reading them the other way round leaves the player standing where
			## `NewBarkTown_TeacherBringsYouBackMovement` should have walked them
			## and steps the rival out of the cell he pushed the player from.
			_emit_object_event(&"object_follow", {
				"object_index": _object_index_from_id(int(command.get("object_id_2", 0))),
				"target_index": _object_index_from_id(int(command.get("object_id", 0))),
				"exact": source_opcode == 0x6F,
			})
		0x70:
			_emit_object_event(&"object_stop_follow", {})
		0x71:
			_emit_object_event(&"object_position", {
				"object_index": _object_index_from_id(int(command.get("object_id", 0))),
				"cell": Vector2i(int(command.get("x", 0)), int(command.get("y", 0))),
			})
		0x72:
			_emit_object_event(&"object_write_position", {
				"object_index": _object_index_from_id(int(command.get("object_id", 0))),
			})
		0x75:
			_emit_object_event(&"object_facing", {
				"object_index": _object_index_from_id(int(command.get("object_id", 0))),
				"facing": int(command.get("facing", Gen2WorldSprite.FACING_DOWN)),
			})
		_:
			return {}
	return {"ok": true}


## The live `sMysteryGiftData`, which [Gen2WorldState] mirrors out of the save
## so a scene script reaching `CheckMysteryGift` on a map-load frame has an
## answer rather than a request to wait on.
func _mystery_gift_section() -> Dictionary:
	if state == null:
		return Gen2MysteryGift.default_section()
	return state.mystery_gift()


## `GetMysteryGiftItem`: the waiting item into the bag, its own received box,
## and `wScriptVar` for the officer's `iffalse`. `.no_room` closes SRAM without
## clearing the byte, so a full pack leaves the gift where it is and the player
## can come back for it.
func _stage_mystery_gift_item(special: int) -> Dictionary:
	var section: Dictionary = _mystery_gift_section()
	var item: int = Gen2MysteryGift.take_item(section)
	if item <= 0:
		_script_value = 0
		return {"ok": true}
	var given: Dictionary = _stage_item_delta(item, 1)
	if not bool(given.get("ok", true)):
		return given
	if _script_value == 0:
		return {"ok": true}
	Gen2MysteryGift.clear_item(section)
	var item_name: String = data.item_name(item) if data != null else ""
	_set_text_buffer(
		RomLayout.STRING_BUFFER_4, item_name, &"item_name", {"item": item}
	)
	return _stage_internal_text(RECEIVED_ITEM_TEXT % item_name, false, {
		"special": special, "item": item,
	})

func _stage_item_delta(item: int, delta: int) -> Dictionary:
	if item > 0:
		_last_item = item
	if item <= 0 or delta == 0:
		_script_value = 1 if delta >= 0 else 0
		return {"ok": true}
	var current: int = _item_quantity(item)
	var next: int = current + delta
	if next < 0:
		_script_value = 0
		_emit_runtime_event(&"item_change_rejected", {
			"item": item, "quantity": abs(delta), "available": current,
		})
		return {"ok": true}
	if delta > 0 and data != null and state != null:
		var owned: Dictionary = state.items()
		for staged_item: Variant in _staged_items:
			owned[int(staged_item)] = int(_staged_items[staged_item])
		var receive: Dictionary = Gen2WorldPack.receive_check(data, owned, item, delta)
		if not bool(receive.get("ok", false)):
			_script_value = 0
			_emit_runtime_event(&"item_change_rejected", {
				"item": item, "quantity": delta, "available": receive.get("available", 0),
				"reason": receive.get("reason", &"item_receive_rejected"),
			})
			return {"ok": true, "accepted": false, "reason": receive.get("reason", &"item_receive_rejected")}
	_staged_items[item] = next
	_script_value = 1
	_emit_runtime_event(&"item_changed", {
		"item": item, "quantity": abs(delta), "total": next,
		"direction": &"give" if delta > 0 else &"take",
	})
	return {"ok": true}


## `GiveMoney` and `TakeMoney` (`engine/events/money.asm`). Neither refuses and
## neither leaves the account alone: a gift past `MAX_MONEY` writes the ceiling
## and a payment past the balance writes zero, both returning the carry that
## only `BankOfMom` reads. `Script_givemoney` and `Script_takemoney` write no
## wScriptVar of their own, so what they answer is the balance rather than a
## rejection.
func _stage_money_delta(account: int, amount: int, give: bool) -> Dictionary:
	if account < 0 or amount < 0:
		return {"ok": false, "reason": &"invalid_money_command"}
	var current: int = _money_balance(account)
	var next: int = clampi(
		current + amount if give else current - amount, 0, Gen2WorldInventory.MAX_MONEY
	)
	_staged_money[account] = next
	_emit_runtime_event(&"money_changed", {
		"account": account, "amount": amount, "balance": next,
		"direction": &"give" if give else &"take",
	})
	return {"ok": true}


## `GiveCoins` and `TakeCoins`, the same pair of ceilings one account over.
func _stage_coins_delta(amount: int, give: bool) -> Dictionary:
	if amount < 0:
		return {"ok": false, "reason": &"invalid_coins_command"}
	var current: int = _coins_value()
	var next: int = clampi(
		current + amount if give else current - amount, 0, Gen2WorldInventory.MAX_COINS
	)
	_staged_coins = next
	_emit_runtime_event(&"coins_changed", {
		"amount": amount, "balance": next,
		"direction": &"give" if give else &"take",
	})
	return {"ok": true}


func _stage_menu(two_dimensional: bool, command: Dictionary) -> Dictionary:
	if _loaded_menu.is_empty():
		return {"ok": false, "reason": &"menu_header_missing", "command": command}
	if _loaded_menu.has("decode_error"):
		return {
			"ok": false,
			"reason": &"menu_data_invalid",
			"details": _loaded_menu.get("decode_error", ""),
		}
	_pending = {
		"type": &"menu",
		"menu_kind": &"2d" if two_dimensional else &"vertical",
		"header": _loaded_menu.duplicate(true),
		"options": _loaded_menu.get("options", []).duplicate(true),
		"text": _standing_text,
		"source": _request.duplicate(true),
	}
	return {"ok": true}


func _stage_audio_request(kind: StringName, values: Dictionary) -> Dictionary:
	var event: Dictionary = {"kind": kind}
	for key: Variant in values:
		event[key] = values[key]
	return _stage_runtime_request(&"audio_requested", event)


func _phone_contact_registered(contact: int) -> bool:
	if _staged_phone_contacts.has(contact):
		return bool(_staged_phone_contacts[contact])
	return state != null and state.has_phone_contact(contact)


func _phone_contact_candidate() -> Dictionary:
	var candidate: Dictionary = state.phone_contacts() if state != null else {}
	for raw_contact: Variant in _staged_phone_contacts:
		var contact: int = int(raw_contact)
		if bool(_staged_phone_contacts[raw_contact]):
			candidate[contact] = true
		else:
			candidate.erase(contact)
	return candidate


func _stage_phone_contact(contact: int, add: bool = true) -> Dictionary:
	if data == null or contact < 0 or contact >= data.world_phone_contact_count():
		return {"ok": false, "reason": &"invalid_phone_contact", "contact": contact}
	if add:
		if _phone_contact_registered(contact):
			_script_value = PHONE_CONTACTS_FULL
			_emit_runtime_event(&"phone_contact_changed", {
				"contact": contact, "added": false, "result": _script_value,
			})
			return {"ok": true, "added": false, "result": _script_value}
		var candidate: Dictionary = _phone_contact_candidate()
		if candidate.size() >= Gen2WorldState.PHONE_CONTACT_CAPACITY:
			_script_value = PHONE_CONTACTS_FULL
			_emit_runtime_event(&"phone_contact_changed", {
				"contact": contact, "added": false, "result": _script_value,
			})
			return {"ok": true, "added": false, "result": _script_value}
		_staged_phone_contacts[contact] = true
		_script_value = PHONE_CONTACT_GOT
		_emit_runtime_event(&"phone_contact_changed", {
			"contact": contact, "added": true, "result": _script_value,
		})
		return {"ok": true, "added": true, "result": _script_value}
	if not _phone_contact_registered(contact):
		_script_value = 1
		_emit_runtime_event(&"phone_contact_changed", {
			"contact": contact, "added": false, "removed": false, "result": _script_value,
		})
		return {"ok": true, "removed": false, "result": _script_value}
	_staged_phone_contacts[contact] = false
	_script_value = 0
	_emit_runtime_event(&"phone_contact_changed", {
		"contact": contact, "added": false, "removed": true, "result": _script_value,
	})
	return {"ok": true, "removed": true, "result": _script_value}


func _stage_phone_choice(contact: int) -> Dictionary:
	_pending = {
		"type": &"choice",
		"command": &"askforphonenumber",
		"choices": [&"accept", &"refuse"],
		"contact": contact,
		"source": _request.duplicate(true),
	}
	return {"ok": true}


## Holds the script until the stream an `applymovement` just queued has been
## drawn. The cells committed when the command applied, exactly as the source
## commits them in `InitStep`; what is left is the drawing, and the source waits
## for it (`WaitScriptMovement`).
func _stage_movement_wait(values: Dictionary = {}) -> Dictionary:
	var wait: Dictionary = {
		"type": &"wait",
		"wait": WAIT_MOVEMENT,
		"source": _request.duplicate(true),
	}
	for key: Variant in values:
		wait[key] = values[key]
	_pending = wait
	return {"ok": true}


## Holds it for a counted number of hardware frames.
func _stage_frame_wait(frames: int, values: Dictionary = {}) -> Dictionary:
	var wait: Dictionary = {
		"type": &"wait",
		"wait": WAIT_FRAMES,
		"frames": maxi(0, frames),
		"source": _request.duplicate(true),
	}
	for key: Variant in values:
		wait[key] = values[key]
	_pending = wait
	return {"ok": true}


func _stage_runtime_request(kind: StringName, values: Dictionary) -> Dictionary:
	_pending = {
		"type": &"runtime_request",
		"request": {"kind": kind, "values": values.duplicate(true)},
		"source": _request.duplicate(true),
	}
	return {"ok": true}


## engine/overworld/decorations.asm's DescribeDecoration dispatch. These
## scripts are local to the current map. They do not ask a host to interpret a
## decoration; only the poster's DECO_TOWN_MAP branch reaches special 38.
const DECODESC_POSTER: int = 0
const DECODESC_LEFT_DOLL: int = 1
const DECODESC_RIGHT_DOLL: int = 2
const DECODESC_BIG_DOLL: int = 3
const DECODESC_CONSOLE: int = 4
const DECO_TOWN_MAP: int = 0x10
const DECO_PIKACHU_POSTER: int = 0x11
const DECO_CLEFAIRY_POSTER: int = 0x12
const DECO_JIGGLYPUFF_POSTER: int = 0x13
## Which `wDeco*` slot each of the three name-a-decoration descriptions reads.
const DECODESC_SLOTS: Dictionary = {
	DECODESC_LEFT_DOLL: Gen2WorldDecoration.SLOT_LEFT_ORNAMENT,
	DECODESC_RIGHT_DOLL: Gen2WorldDecoration.SLOT_RIGHT_ORNAMENT,
	DECODESC_CONSOLE: Gen2WorldDecoration.SLOT_CONSOLE,
}


func _stage_decoration_description(description: int) -> Dictionary:
	match description:
		DECODESC_POSTER:
			var poster: int = state.maptile_decoration(
				Gen2WorldDecoration.SLOT_POSTER
			) if state != null else 0
			match poster:
				DECO_TOWN_MAP:
					_stage_internal_text("It's the TOWN MAP.", false)
					_pending["special_after_text"] = SPECIAL_OVERWORLD_TOWN_MAP
					return {"ok": true}
				DECO_PIKACHU_POSTER:
					return _stage_internal_text("It's a poster of a\ncute PIKACHU.", false)
				DECO_CLEFAIRY_POSTER:
					return _stage_internal_text("It's a poster of a\ncute CLEFAIRY.", false)
				DECO_JIGGLYPUFF_POSTER:
					return _stage_internal_text("It's a poster of a\ncute JIGGLYPUFF.", false)
				_:
					## `DecorationDesc_NullPoster` is an `end` and prints nothing.
					return {"ok": true}
		DECODESC_BIG_DOLL:
			return _stage_internal_text("A giant doll! It's\nfluffy and cuddly.", false)
		DECODESC_LEFT_DOLL, DECODESC_RIGHT_DOLL, DECODESC_CONSOLE:
			## `DecorationDesc_OrnamentOrConsole` names whatever stands in that
			## slot; the box is one text with the name written into it.
			return _stage_internal_text("It's an adorable\n%s." % Gen2WorldDecoration.decoration_name(
				data, state.maptile_decoration(DECODESC_SLOTS[description]) if state != null else 0
			), false)
	return _fail(&"invalid_decoration_description", {"description": description})


func _stage_trainer_approach() -> void:
	_stage_runtime_request(&"trainer_approach_requested", {
		"object_index": int(_request.get("object_index", -1)),
		"distance": int(_request.get("distance", 0)),
		"direction": _request.get("direction", Vector2i.ZERO),
	})


## `Script_faceplayer`, which turns the object the player is standing in front
## of. Shared with `jumptextfaceplayer`, whose own script runs one before the
## text.
func _face_player() -> void:
	if _last_talked_object_index >= 0:
		_emit_object_event(&"object_face_player", {
			"object_index": _last_talked_object_index,
		})


## `FindThatSpecies`, and `CheckOwnMon`'s ID and OT test on top of it when
## [param own_only]. The walk is `wPartySpecies`, so an EGG's slot carries EGG
## rather than what is inside it and cannot match a species.
func _party_slot_of_species(party: Dictionary, species: int, own_only: bool) -> int:
	var listed: Array = party.get("species", [])
	var eggs: Array = party.get("eggs", [])
	var own_ot: Array = party.get("own_ot", [])
	for slot: int in listed.size():
		if slot < eggs.size() and bool(eggs[slot]):
			continue
		if int(listed[slot]) != species:
			continue
		if own_only and (slot >= own_ot.size() or not bool(own_ot[slot])):
			return -1
		return slot
	return -1


## `wXCoord`/`wYCoord`, mirrored onto the request the way the party count is.
func _player_cell() -> Vector2i:
	var standing: Variant = _request.get("player_cell", Vector2i(-1, -1))
	return standing if standing is Vector2i else Vector2i(-1, -1)


func _read_runtime_variable(variable: int) -> Dictionary:
	var readers: Dictionary = _runtime_variable_readers()
	if not readers.has(variable):
		return {
			"ok": false,
			"reason": &"unsupported_runtime_variable",
			"variable": variable,
		}
	var answer: Variant = (readers[variable] as Callable).call()
	if answer == null:
		return {"ok": false, "reason": &"missing_party_summary", "variable": variable}
	_script_value = int(answer)
	return {"ok": true}


## `_GetVarAction`'s table. A reader answers null for state nothing staged.
func _runtime_variable_readers() -> Dictionary:
	var clock: Dictionary = _request.get("clock", {})
	var hour: int = int(clock.get("hour", _clock_hour()))
	var day: int = int(clock.get("day", 0))
	return {
		0x01: _var_party_count, # VAR_PARTYCOUNT
		0x04: func() -> Variant: return Gen2WorldClock.new(hour, 0, day).time_of_day(), # VAR_TIMEOFDAY
		0x05: func() -> Variant: return state.caught_count() if state != null else 0, # VAR_DEXCAUGHT
		0x06: func() -> Variant: return state.seen_count() if state != null else 0, # VAR_DEXSEEN
		0x07: func() -> Variant: return _staged_badge_count(), # VAR_BADGES
		0x09: func() -> Variant: return int(_request.get("facing", -1)), # VAR_FACING
		0x0A: func() -> Variant: return hour, # VAR_HOUR
		0x0B: func() -> Variant: return day, # VAR_WEEKDAY
		0x0C: func() -> Variant: return int(_request.get("map_group", -1)), # VAR_MAPGROUP
		0x0D: func() -> Variant: return int(_request.get("map_number", -1)), # VAR_MAPNUMBER
		0x0E: _var_unown_count, # VAR_UNOWNCOUNT
		0x0F: func() -> Variant: return int(_request.get("environment", -1)), # VAR_ENVIRONMENT
		0x10: _var_box_free_space, # VAR_BOXSPACE
		0x12: func() -> Variant: return _player_cell().x, # VAR_XCOORD
		0x13: func() -> Variant: return _player_cell().y, # VAR_YCOORD
		0x14: func() -> Variant: return _current_special_phone_call(), # VAR_SPECIALPHONECALL
		0x16: _var_kurt_apricorns, # VAR_KURT_APRICORNS
		0x17: func() -> Variant: return int(_phone_context.get("caller_id", -1)), # VAR_CALLERID
		0x18: func() -> Variant: return _blue_card_balance(), # VAR_BLUECARDBALANCE
		0x19: func() -> Variant: return state.buenas_password() if state != null else 0, # VAR_BUENAS_PASSWORD
		0x1A: _var_kenji_break_timer, # VAR_KENJI_BREAK_TIMER
	}


func _var_party_count() -> Variant:
	var party: Dictionary = _request.get("party", {})
	if party.is_empty():
		return null
	return int(party.get("count", 0))


## `.BoxFreeSpace` opens SRAM for the count; the party mirror carries it here for
## the same reason it carries VAR_PARTYCOUNT, and an absent mirror fails rather
## than inventing an empty box.
func _var_box_free_space() -> Variant:
	var storage: Dictionary = _request.get("party", {})
	if not storage.has("box_free_space"):
		return null
	return int(storage.get("box_free_space", 0))


## `.count_unown` walks wUnownDex and stops at the first empty slot, which is the
## size of the list here. All three Ruins of Alph scientists and the Kabuto
## chamber's wall read it.
func _var_unown_count() -> Variant:
	return state.unown_caught_count() if state != null else 0


## _GetVarAction reads wKurtApricornQuantity, saved player data whose only writer
## is SelectApricornForKurt. A selection made inside this invocation shadows the
## committed byte, as the WRAM write does.
func _var_kurt_apricorns() -> Variant:
	return _kurt_apricorn_quantity()


func _var_kenji_break_timer() -> Variant:
	return _staged_kenji_break_timer if _has_staged_kenji_break_timer \
		else (state.kenji_break_timer() if state != null else 0)


## `writevar`, which is `_GetVarAction` for a RETVAR_ADDR_DE row and then a
## store of wScriptVar into the address it answered. Only those rows can be
## written: every other entry hands back a copy in wStringBuffer2 or runs a
## routine, so a `writevar` naming one writes nothing the script can read back.
##
## Every `writevar` in either game is RadioTower2F's own award of a Blue Card
## point, which stopped the script here until this existed.
func _write_runtime_variable(variable: int) -> Dictionary:
	match variable:
		0x18: # VAR_BLUECARDBALANCE
			_staged_blue_card_balance = _script_value & 0xFF
		_:
			return {
				"ok": false,
				"reason": &"unsupported_runtime_writevar",
				"variable": variable,
			}
	return {"ok": true}


func _blue_card_balance() -> int:
	if _staged_blue_card_balance >= 0:
		return _staged_blue_card_balance
	return state.blue_card_balance() if state != null else 0


func _load_runtime_variable(variable: int, value: int) -> Dictionary:
	## Phone scripts use LOADVAR for the two runtime values that are not
	## ordinary world-state variables. Battles also load VAR_BATTLETYPE before
	## STARTBATTLE so a source can explicitly permit a non-blackout loss.
	match variable:
		0x03: # VAR_BATTLETYPE
			if _battle_setup.is_empty():
				_loaded_battle_type = value
			else:
				_battle_setup["battle_type"] = value
				_battle_setup["can_lose"] = value == 1
		0x14: # VAR_SPECIALPHONECALL
			if not _phone_context.is_empty():
				_phone_context["special_call_id"] = value
			_staged_special_phone_call = value
			_has_staged_special_phone_call = true
		0x17: # VAR_CALLERID
			_phone_context["caller_id"] = value
		_:
			return {
				"ok": false,
				"reason": &"unsupported_runtime_loadvar",
				"variable": variable,
				"value": value,
			}
	return {"ok": true}


func _current_special_phone_call() -> int:
	## A staged specialphonecall updates the script-visible variable before
	## the transaction commits, just as the source WRAM byte does.
	if _has_staged_special_phone_call:
		return _staged_special_phone_call
	var context_value: int = int(_phone_context.get("special_call_id", 0))
	if context_value != 0:
		return context_value
	var request_value: Variant = _request.get("special_phone_call", 0)
	if request_value is int or request_value is float:
		if int(request_value) != 0:
			return int(request_value)
	return state.pending_special_phone_call() if state != null else 0


func _kurt_apricorn_quantity() -> int:
	if _has_staged_kurt_apricorn_quantity:
		return _staged_kurt_apricorn_quantity
	if _request.has("kurt_apricorn_quantity"):
		return clampi(int(_request["kurt_apricorn_quantity"]), 0, 0xFF)
	return state.kurt_apricorn_quantity() if state != null else 0


func _clock_hour() -> int:
	var clock: Dictionary = _request.get("clock", {})
	return clampi(int(clock.get("hour", 0)), 0, 23)


func _clock_minute() -> int:
	var clock: Dictionary = _request.get("clock", {})
	return clampi(int(clock.get("minute", 0)), 0, 59)


## `wCurDay`, which is a weekday here rather than a running day count. Every
## day-counted timer this project keeps is stepped by the rollover instead.
func _clock_day() -> int:
	var clock: Dictionary = _request.get("clock", {})
	return posmod(int(clock.get("day", 0)), Gen2WorldClock.DAYS_PER_WEEK)


## `HealMachineAnim`'s sounds and the frame of its own wait each is played on.
## `.LoadBallsOntoMachine` plays one effect a ball and then delays thirty frames,
## so ball zero sounds on the frame the routine starts. `.PlayHealMusic` starts
## `MUSIC_HEAL` under `.FlashPalettes8Times` rather than after it; the Hall of
## Fame's sequence plays one effect there instead and a second once the flashes
## are done. Its `WaitSFX` between the two is not spent, like the other two the
## world leaves unspent.
static func heal_machine_sounds(machine_type: int, balls: int) -> Array:
	if balls <= 0:
		return []
	var schedule: Array = []
	for ball: int in balls:
		schedule.append({
			"frame": ball * HEAL_MACHINE_BALL_FRAMES,
			"kind": &"sound", "index": SFX_SECOND_PART_OF_ITEMFINDER,
		})
	var flashes_at: int = balls * HEAL_MACHINE_BALL_FRAMES
	if machine_type == HEAL_MACHINE_HALL_OF_FAME:
		schedule.append({
			"frame": flashes_at, "kind": &"sound", "index": SFX_GAME_FREAK_LOGO_GS,
		})
		schedule.append({
			"frame": flashes_at + HEAL_MACHINE_FLASH_FRAMES,
			"kind": &"sound", "index": SFX_BOOT_PC,
		})
	else:
		schedule.append({"frame": flashes_at, "kind": &"music", "index": MUSIC_HEAL})
	return schedule


## `ItemFinder.ItemfinderSound`, which its found branch runs as a `callasm`
## before the line: four passes of `WaitPlaySFX SFX_SECOND_PART_OF_ITEMFINDER`
## and `WaitPlaySFX SFX_TRANSACTION`. Each holds until the four effect channels
## are free, so the eight are a run rather than eight sounds on one frame, and
## `.Script_FoundNothing` has none of it.
static func itemfinder_sounds() -> Array:
	var schedule: Array = []
	for _pass: int in ITEMFINDER_SFX_PASSES:
		schedule.append({
			"kind": &"sound", "wait": true, "index": SFX_SECOND_PART_OF_ITEMFINDER,
		})
		schedule.append({"kind": &"sound", "wait": true, "index": SFX_TRANSACTION})
	return schedule


## Every special this runner answers, as the handler that answers it. SPECIAL is a
## shared cartridge dispatch table: phone routines are one part of it, and map
## callbacks and the new-game clock setup use the same table.
const SPECIAL_HANDLERS: Dictionary = {
	SPECIAL_OVERWORLD_TOWN_MAP: &"_special_overworld_town_map",
	SPECIAL_PLAYERS_HOUSE_PC: &"_special_players_house_pc",
	SPECIAL_POKEMON_CENTER_PC: &"_special_pokemon_center_pc",
	SPECIAL_BATTLE_TOWER_ACTION: &"_special_battle_tower_action",
	SPECIAL_CHECK_BATTLE_TOWER_RULES: &"_special_check_battle_tower_rules",
	SPECIAL_TRY_QUICK_SAVE: &"_special_try_quick_save",
	SPECIAL_RESET: &"_special_reset",
	SPECIAL_CHALLENGE_MENU: &"_special_challenge_menu",
	SPECIAL_SET_BITS_FOR_LINK_TRADE_REQUEST: &"_special_request_link_room",
	SPECIAL_SET_BITS_FOR_BATTLE_REQUEST: &"_special_request_link_room",
	SPECIAL_SET_BITS_FOR_TIME_CAPSULE_REQUEST: &"_special_set_bits_for_time_capsule_request",
	SPECIAL_WAIT_FOR_LINKED_FRIEND: &"_special_wait_for_linked_friend",
	SPECIAL_CHECK_LINK_TIMEOUT_RECEPTIONIST: &"_special_check_link_timeout_receptionist",
	SPECIAL_CHECK_BOTH_SELECTED_SAME_ROOM: &"_special_check_both_selected_same_room",
	SPECIAL_FAILED_LINK_TO_PAST: &"_special_failed_link_to_past",
	SPECIAL_CLOSE_LINK: &"_special_close_link",
	SPECIAL_WAIT_FOR_OTHER_PLAYER_TO_EXIT: &"_special_wait_for_other_player_to_exit",
	SPECIAL_CHECK_TIME_CAPSULE_COMPATIBILITY: &"_special_check_time_capsule_compatibility",
	SPECIAL_ENTER_TIME_CAPSULE: &"_special_enter_time_capsule",
	SPECIAL_TRADE_CENTER: &"_special_link_room",
	SPECIAL_COLOSSEUM: &"_special_link_room",
	SPECIAL_TIME_CAPSULE: &"_special_link_room",
	SPECIAL_CHECK_MOBILE_ADAPTER_STATUS: &"_special_check_mobile_adapter_status",
	SPECIAL_CABLE_CLUB_CHECK_WHICH_CHRIS: &"_special_cable_club_check_which_chris",
	SPECIAL_DISPLAY_LINK_RECORD: &"_special_display_link_record",
	SPECIAL_BATTLE_TOWER_ROOM_MENU: &"_special_battle_tower_room_menu",
	SPECIAL_LOAD_BATTLE_TOWER_OPPONENT: &"_special_load_battle_tower_opponent",
	SPECIAL_BATTLE_TOWER_BATTLE: &"_special_battle_tower_battle",
	SPECIAL_SET_DAY_OF_WEEK: &"_special_set_day_of_week",
	SPECIAL_INITIAL_SET_DST_FLAG: &"_special_initial_set_dst_flag",
	SPECIAL_INITIAL_CLEAR_DST_FLAG: &"_special_initial_clear_dst_flag",
	SPECIAL_PLAY_MAP_MUSIC: &"_special_map_music",
	SPECIAL_RESTART_MAP_MUSIC: &"_special_map_music",
	SPECIAL_FADE_OUT_MUSIC: &"_special_fade_out_music",
	36: &"_special_rival_name",
	27: &"_special_heal_party",
	SPECIAL_HEAL_MACHINE_ANIM: &"_special_heal_machine_anim",
	SPECIAL_MAGNET_TRAIN: &"_special_magnet_train",
	SPECIAL_PROF_OAKS_PC_BOOT: &"_special_prof_oaks_pc_boot",
	SPECIAL_CHECK_POKERUS: &"_special_check_pokerus",
	SPECIAL_SNORLAX_AWAKE: &"_special_snorlax_awake",
	SPECIAL_FADE_OUT_TO_WHITE: &"_special_palette_fade",
	SPECIAL_BATTLE_TOWER_FADE: &"_special_palette_fade",
	SPECIAL_FADE_OUT_TO_BLACK: &"_special_palette_fade",
	SPECIAL_FADE_IN_FROM_WHITE: &"_special_palette_fade",
	SPECIAL_FADE_IN_FROM_BLACK: &"_special_palette_fade",
	51: &"_special_presentation_only",
	52: &"_special_presentation_only",
	53: &"_special_presentation_only",
	55: &"_special_presentation_only",
	56: &"_special_presentation_only",
	94: &"_special_presentation_only",
	152: &"_special_presentation_only",
	157: &"_special_presentation_only",
	158: &"_special_presentation_only",
	164: &"_special_presentation_only",
	95: &"_special_cry",
	100: &"_special_cry",
	59: &"_special_wait_sfx",
	66: &"_special_find_party_mon",
	67: &"_special_find_party_mon",
	89: &"_special_first_mon_happiness",
	90: &"_special_first_mon_is_egg",
	102: &"_special_gameboy_check",
	150: &"_special_mon_check",
	151: &"_special_mon_check",
	SPECIAL_INIT_ROAM_MONS: &"_special_init_roam_mons",
	SPECIAL_BILLS_GRANDFATHER: &"_special_grooming",
	SPECIAL_OLDER_HAIRCUT_BROTHER: &"_special_grooming",
	SPECIAL_YOUNGER_HAIRCUT_BROTHER: &"_special_grooming",
	SPECIAL_DAISYS_GROOMING: &"_special_grooming",
	SPECIAL_DISPLAY_COIN_CASE_BALANCE: &"_special_money_window",
	SPECIAL_DISPLAY_MONEY_AND_COIN_BALANCE: &"_special_money_window",
	SPECIAL_PLACE_MONEY_TOP_RIGHT: &"_special_money_window",
	SPECIAL_DAY_CARE_MAN: &"_special_day_care",
	SPECIAL_DAY_CARE_LADY: &"_special_day_care",
	SPECIAL_DAY_CARE_MAN_OUTSIDE: &"_special_day_care",
	SPECIAL_DAY_CARE_MON_1: &"_special_day_care",
	SPECIAL_DAY_CARE_MON_2: &"_special_day_care",
	SPECIAL_NAME_RATER: &"_special_name_rater",
	SPECIAL_MOVE_DELETION: &"_special_move_deletion",
	SPECIAL_MOVE_TUTOR: &"_special_move_tutor",
	SPECIAL_SELECT_APRICORN_FOR_KURT: &"_special_select_apricorn_for_kurt",
	SPECIAL_GIVE_PARK_BALLS: &"_special_give_park_balls",
	SPECIAL_SELECT_RANDOM_BUG_CONTESTANTS: &"_special_select_random_bug_contestants",
	SPECIAL_CONTEST_DROP_OFF_MONS: &"_special_contest_drop_off_mons",
	SPECIAL_CONTEST_RETURN_MONS: &"_special_contest_return_mons",
	SPECIAL_WARP_TO_SPAWN_POINT: &"_special_warp_to_spawn_point",
	SPECIAL_CHECK_PARTY_FULL_AFTER_CONTEST: &"_special_check_party_full_after_contest",
	SPECIAL_BUG_CONTEST_JUDGING: &"_special_bug_contest_judging",
	SPECIAL_ACTIVATE_FISHING_SWARM: &"_special_activate_fishing_swarm",
	SPECIAL_TOGGLE_MAPTILE_DECORATIONS: &"_special_toggle_maptile_decorations",
	SPECIAL_TOGGLE_DECORATIONS_VISIBILITY: &"_special_toggle_decorations_visibility",
	SPECIAL_SLOT_MACHINE: &"_special_slot_machine",
	SPECIAL_CARD_FLIP: &"_special_card_flip",
	SPECIAL_UNOWN_PUZZLE: &"_special_unown_puzzle",
	SPECIAL_DISPLAY_UNOWN_WORDS: &"_special_display_unown_words",
	SPECIAL_SAMPLE_KENJI_BREAK_COUNTDOWN: &"_special_sample_kenji_break_countdown",
	SPECIAL_TRAINER_HOUSE: &"_special_trainer_house",
	SPECIAL_CHECK_MYSTERY_GIFT: &"_special_check_mystery_gift",
	SPECIAL_UNLOCK_MYSTERY_GIFT: &"_special_unlock_mystery_gift",
	SPECIAL_GET_MYSTERY_GIFT_ITEM: &"_special_get_mystery_gift_item",
	SPECIAL_HO_OH_CHAMBER: &"_special_ho_oh_chamber",
	SPECIAL_OMANYTE_CHAMBER: &"_special_omanyte_chamber",
	SPECIAL_CHECK_CAUGHT_CELEBI: &"_special_check_caught_celebi",
	SPECIAL_CELEBI_SHRINE_EVENT: &"_special_celebi_shrine_event",
	SPECIAL_MAP_RADIO: &"_special_map_radio",
	SPECIAL_CHECK_LUCKY_NUMBER_SHOW_FLAG: &"_special_check_lucky_number_show_flag",
	SPECIAL_RESET_LUCKY_NUMBER_SHOW_FLAG: &"_special_reset_lucky_number_show_flag",
	SPECIAL_PRINT_TODAYS_LUCKY_NUMBER: &"_special_print_todays_lucky_number",
	SPECIAL_CHECK_FOR_LUCKY_NUMBER_WINNERS: &"_special_check_for_lucky_number_winners",
	SPECIAL_MAGIKARP_HOUSE_SIGN: &"_special_magikarp_house_sign",
	SPECIAL_BANK_OF_MOM: &"_special_bank_of_mom",
	SPECIAL_UNOWN_PRINTER: &"_special_unown_printer",
	SPECIAL_DIPLOMA: &"_special_diploma",
	SPECIAL_PRINT_DIPLOMA: &"_special_diploma",
	SPECIAL_BUENA_PRIZE: &"_special_buena_prize",
	SPECIAL_POKE_SEER: &"_special_poke_seer",
	SPECIAL_CHECK_MAGIKARP_LENGTH: &"_special_party_selection",
	SPECIAL_PHOTO_STUDIO: &"_special_party_selection",
	SPECIAL_RETURN_SHUCKIE: &"_special_party_selection",
	SPECIAL_GIVE_SHUCKLE: &"_special_give_shuckle",
	SPECIAL_ASK_REMEMBER_PASSWORD: &"_special_ask_remember_password",
	SPECIAL_GIVE_ODD_EGG: &"_special_give_odd_egg",
	SPECIAL_GIVE_DRATINI: &"_special_give_dratini",
	SPECIAL_GAME_CORNER_PRIZE_MON_CHECK_DEX: &"_special_game_corner_prize_mon_check_dex",
	SPECIAL_BUENAS_PASSWORD: &"_special_buenas_password",
	SPECIAL_RANDOM_UNSEEN_WILD_MON: &"_special_random_unseen_wild_mon",
	SPECIAL_RANDOM_PHONE_WILD_MON: &"_special_random_phone_wild_mon",
	SPECIAL_RANDOM_PHONE_MON: &"_special_random_phone_mon",
}


## [param special] is the Crystal-canonical index from
## Gen2WorldScript.special_index(), not the raw stream byte, so the payloads
## below report that index on both profiles.
func _execute_special(special: int) -> Dictionary:
	if not SPECIAL_HANDLERS.has(special):
		return {
			"ok": false,
			"reason": &"unsupported_phone_special",
			"special": special,
		}
	return call(SPECIAL_HANDLERS[special], special)


func _special_overworld_town_map(special: int) -> Dictionary:
	return _stage_runtime_request(&"town_map_requested", {
		"special": special,
		"landmark": int(_request.get("landmark", 0)),
	})


func _special_players_house_pc(special: int) -> Dictionary:
	return _stage_runtime_request(&"pc_requested", {
		"special": special,
		"mode": &"players_house",
	})


func _special_pokemon_center_pc(special: int) -> Dictionary:
	return _stage_runtime_request(&"pc_requested", {
		"special": special,
		"mode": &"pokemon_center",
	})


## `jumptable .dw, wScriptVar`: the `setval` in front of the special names the row,
## and the row's own answer replaces it.
func _special_battle_tower_action(_special: int) -> Dictionary:
	var answered: int = _battle_tower().action(_script_value, {
		"party": _battle_tower_party(),
		"pack": _pack_items(),
		"save_is_yours": true,
		"random": _battle_tower_random(0),
	})
	if answered >= 0:
		_script_value = answered
	return {"ok": true}


func _special_check_battle_tower_rules(_special: int) -> Dictionary:
	return _check_battle_tower_rules()


func _special_try_quick_save(special: int) -> Dictionary:
	return _stage_runtime_request(&"quick_save_requested", {"special": special})


## The console restarting, which is how a saved-and-left challenge leaves the battle
## room. Nothing follows it in any script.
func _special_reset(_special: int) -> Dictionary:
	_events.append({"type": &"soft_reset_requested"})
	_pending = {}
	_active = false
	_completed = true
	return {"ok": true}


func _special_challenge_menu(_special: int) -> Dictionary:
	return _stage_challenge_menu()


func _special_request_link_room(special: int) -> Dictionary:
	_link_session().request_room(
		Gen2LinkSession.CABLECLUBROOM_TRADECENTER \
			if special == SPECIAL_SET_BITS_FOR_LINK_TRADE_REQUEST \
			else Gen2LinkSession.CABLECLUBROOM_COLOSSEUM
	)
	return {"ok": true}


## The Time Capsule asks for `CABLECLUBROOM_NULL`, which is why its own script never
## reaches `CheckBothSelectedSameRoom` on a branch that could pass.
func _special_set_bits_for_time_capsule_request(_special: int) -> Dictionary:
	_link_session().request_time_capsule()
	return {"ok": true}


func _special_wait_for_linked_friend(special: int) -> Dictionary:
	_script_value = _link_session().wait_for_linked_friend(_link_transport())
	if _script_value == 0:
		return {"ok": true}
	return _stage_frame_wait(
		Gen2LinkSession.WAIT_FOR_FRIEND_CONNECTED_FRAMES,
		{"special": special, "kind": &"link_wait"}
	)


func _special_check_link_timeout_receptionist(special: int) -> Dictionary:
	var session: Gen2LinkSession = _link_session()
	_script_value = session.check_link_timeout(_link_transport())
	## The `readmem wOtherPlayerLinkMode` every one of the three scripts
	## runs on the next line reads this byte and not wScriptVar.
	var stored: Dictionary = _stage_script_memory(
		data.other_player_link_mode_address() if data != null else -1,
		session.other_player_link_mode
	)
	if not bool(stored.get("ok", true)):
		return stored
	return _stage_frame_wait(
		Gen2LinkSession.CHECK_LINK_TIMEOUT_FRAMES,
		{"special": special, "kind": &"link_wait"}
	)


func _special_check_both_selected_same_room(_special: int) -> Dictionary:
	_script_value = _link_session().check_both_selected_same_room(_link_transport())
	return {"ok": true}


func _special_failed_link_to_past(special: int) -> Dictionary:
	_link_session().failed_link_to_past(_link_transport())
	return _stage_frame_wait(
		Gen2LinkSession.FAILED_LINK_TO_PAST_FRAMES,
		{"special": special, "kind": &"link_wait"}
	)


func _special_close_link(special: int) -> Dictionary:
	_link_session().close_link(_link_transport())
	return _stage_frame_wait(
		Gen2LinkSession.CLOSE_LINK_FRAMES,
		{"special": special, "kind": &"link_wait"}
	)


func _special_wait_for_other_player_to_exit(special: int) -> Dictionary:
	_link_session().wait_for_other_player_to_exit(_link_transport())
	return _stage_frame_wait(
		Gen2LinkSession.WAIT_FOR_OTHER_PLAYER_FRAMES,
		{"special": special, "kind": &"link_wait"}
	)


func _special_check_time_capsule_compatibility(_special: int) -> Dictionary:
	return _check_time_capsule_compatibility()


func _special_enter_time_capsule(special: int) -> Dictionary:
	_link_session().enter_time_capsule(_link_transport())
	return _stage_frame_wait(
		Gen2LinkSession.ENTER_TIME_CAPSULE_FRAMES,
		{"special": special, "kind": &"link_wait"}
	)


func _special_link_room(special: int) -> Dictionary:
	return _stage_link_room(special)


## `CheckMobileAdapterStatusSpecial` answers whether a Mobile Adapter GB is plugged
## in, and none is: there is no such peripheral on any platform this runs on. FALSE is
## what both Crystal receptionists branch on to reach `.NoMobile`, which is the cable
## club proper, so this is the answer that opens the room rather than the one that
## closes it.
func _special_check_mobile_adapter_status(_special: int) -> Dictionary:
	_script_value = 0
	return {"ok": true}


func _special_cable_club_check_which_chris(_special: int) -> Dictionary:
	_script_value = _link_session().which_chris(_link_transport())
	return {"ok": true}


## `_DisplayLinkRecord` draws `sLinkBattleStats` and holds for A or B. It writes
## nothing, so the script runs straight on behind it.
func _special_display_link_record(special: int) -> Dictionary:
	return _stage_runtime_request(&"link_record_requested", {"special": special})


func _special_battle_tower_room_menu(_special: int) -> Dictionary:
	return _stage_room_menu()


func _special_load_battle_tower_opponent(_special: int) -> Dictionary:
	return _load_battle_tower_opponent()


func _special_battle_tower_battle(_special: int) -> Dictionary:
	return _stage_battle_tower_battle()


func _special_set_day_of_week(_special: int) -> Dictionary:
	_stage_day_of_week_menu()
	return {"ok": true}


func _special_initial_set_dst_flag(_special: int) -> Dictionary:
	_staged_dst_enabled = true
	_has_staged_dst = true
	_stage_dst_confirmation_text(true)
	return {"ok": true}


func _special_initial_clear_dst_flag(_special: int) -> Dictionary:
	_staged_dst_enabled = false
	_has_staged_dst = true
	_stage_dst_confirmation_text(false)
	return {"ok": true}


func _special_map_music(special: int) -> Dictionary:
	# Entering a map with the music already playing does not restart it,
	# which is why crossing a route boundary is one continuous track.
	# RestartMapMusic exists to override exactly that, so it says so.
	return _stage_audio_request(&"map_music", {
		"special": special,
		"restart": special == SPECIAL_RESTART_MAP_MUSIC,
	})


func _special_fade_out_music(special: int) -> Dictionary:
	_emit_runtime_event(&"music_fadeout_requested", {"special": special})
	return {"ok": true}


func _special_rival_name(special: int) -> Dictionary:
	return _stage_runtime_request(&"rival_name_requested", {
		"special": special, "default_name": "SILVER",
	})


## HealParty is a save-owned transaction. It is deliberately a host request so HP,
## status and PP are changed together with the selected project save.
func _special_heal_party(special: int) -> Dictionary:
	return _stage_runtime_request(&"party_heal_requested", {"special": special})


## wScriptVar selects the machine's screen position: 0 Pokemon Center, 1 Elm's Lab, 2
## Hall of Fame. A preceding SETVAL loads it. Nothing here changes state, but the
## routine is not free: it spends thirty frames a ball and `.FlashPalettes8Times`'
## eighty, with a sound on each ball, so the script waits for it the way the cartridge
## does.
func _special_heal_machine_anim(special: int) -> Dictionary:
	var machine_type: int = clampi(_script_value, 0, HEAL_MACHINE_HALL_OF_FAME)
	var balls: int = int((_request.get("party", {}) as Dictionary).get("count", 0))
	var sounds: Array = heal_machine_sounds(machine_type, balls)
	_emit_runtime_event(&"presentation_special_applied", {
		"special": special, "kind": &"heal_machine_anim",
		"machine_type": machine_type,
		"balls": balls,
		"sounds": sounds.duplicate(true),
	})
	## `ld a, [wPartyCount] / and a / ret z`: an empty party leaves the
	## machine alone and spends nothing.
	if balls > 0:
		## `machine_type` rides along for [method Gen2WorldAPI.party_holder].
		return _stage_frame_wait(
			balls * HEAL_MACHINE_BALL_FRAMES + HEAL_MACHINE_FLASH_FRAMES,
			{
				"special": special, "kind": &"heal_machine_anim",
				"machine_type": machine_type,
			}
		)
	return {"ok": true}


## engine/events/magnet_train.asm's MagnetTrain is scroll positions, graphics, music
## and a VBlank cutscene handler. It reads wScriptVar for the direction and writes
## nothing the overworld can observe; the warp itself is the `warpcheck` that follows
## it.
func _special_magnet_train(special: int) -> Dictionary:
	_emit_runtime_event(&"presentation_special_applied", {
		"special": special, "kind": &"magnet_train",
		"to_goldenrod": _script_value != 0,
	})
	return {"ok": true}


## engine/events/prof_oaks_pc.asm's ProfOaksPCBoot prints, counts the set bits in
## wPokedexSeen and wPokedexCaught for `Rate`, plays that rating's sound and waits for
## A or B. Presentation only: it writes nothing, so the script runs straight on to its
## own `end` and [Gen2ProfOaksPC] is handed the counts by whoever draws this.
func _special_prof_oaks_pc_boot(special: int) -> Dictionary:
	_emit_runtime_event(&"presentation_special_applied", {
		"special": special, "kind": &"prof_oaks_pc_boot",
	})
	return {"ok": true}


func _special_check_pokerus(special: int) -> Dictionary:
	var party: Dictionary = _request.get("party", {})
	if party.is_empty():
		return {"ok": false, "reason": &"missing_party_summary", "special": special}
	_script_value = 1 if bool(party.get("pokerus", false)) else 0
	return {"ok": true}


## Two reads and nothing else: the track in wMapMusic and the cell the player stands
## on. The Poke Flute channel reaches wMapMusic through StartRadioStation and stays
## there because closing the Pokegear restores the map's music only for its two
## sentinel ids.
func _special_snorlax_awake(_special: int) -> Dictionary:
	var cell: Vector2i = _player_cell()
	_script_value = 1 if state != null \
		and state.map_music() == Gen2WorldRadio.MUSIC_POKE_FLUTE_CHANNEL \
		and cell in SNORLAX_PROXIMITY_CELLS else 0
	return {"ok": true}


## `FadeOutToWhite` is 46 in both pins, since Crystal's inserted `BattleTowerFade`
## sits at 47; `FadeInFromWhite` is 49 here and 48 in Gold/Silver, which
## `special_index()` already normalizes. Each of the five is `GetTimePalFade` and then
## four rows of the fade table, and none is free: `ConvertTimePals*HL` spends `ld c,
## 2` on every row, so the script holds for the whole walk the way it does on the
## cartridge. `FillWhiteBGColor` is the two white fades' alone.
func _special_palette_fade(special: int) -> Dictionary:
	var orders: Array[int] = FADE_ORDERS_OF[special]
	var step_frames: int = Gen2WorldPalette.BATTLE_TOWER_FADE_STEP_FRAMES \
		if special == SPECIAL_BATTLE_TOWER_FADE \
		else Gen2WorldPalette.FADE_STEP_FRAMES
	_emit_runtime_event(&"presentation_special_applied", {
		"special": special, "kind": &"palette_fade",
		"orders": orders.duplicate(),
		"step_frames": step_frames,
		"white_fill": special in FADE_WHITE_FILL_SPECIALS,
	})
	return _stage_frame_wait(orders.size() * step_frames, {
		"special": special, "kind": &"palette_fade",
	})


## Sprite reload, palette reload and the dummied trainer-ranking bookkeeping affect
## presentation or source-only counters rather than scene-free state.
## `LoadUsedSpritesGFX`, `UpdateSprites`, `UpdatePlayerSprite`,
## `ReloadSpritesNoPalettes` and `RefreshSprites` reload the sprite set a
## `variablesprite` just changed; `ClearBGPalettes`, `UpdateTimePals`,
## `SetPlayerPalette` and `LoadMapPalettes` are the palette pair the day/night scripts
## open with, and the renderer takes its palettes from the map and the clock.
func _special_presentation_only(special: int) -> Dictionary:
	_emit_runtime_event(&"presentation_special_applied", {"special": special})
	return {"ok": true}


## `PlaySlowCry` (95) is `LoadCry` with the record's own pitch lowered by `$140` and
## its length raised by `$60`, and `PlayCurMonCry` (100) is `PlayMonCry` straight.
## Neither writes anything back, so what they owe is the sound and the `WaitSFX` each
## ends on. They do not read the same byte: 95 is `ld a, [wScriptVar]`, which the
## `setval` in front of it has just set, and 100 is `ld a, [wCurPartySpecies]`, all
## four of whose scripts are a grooming routine's.
func _special_cry(special: int) -> Dictionary:
	return _stage_audio_request(&"cry", {
		"special": special,
		"species": _script_value if special == 95 else _cur_party_species,
		"slow": special == 95,
	})


## `SpecialWaitSFX` is `WaitSFX`: it holds until the four effect channels are free
## rather than spending a counted number of frames, which is `Script_waitsfx`'s own
## request.
func _special_wait_sfx(special: int) -> Dictionary:
	return _stage_audio_request(&"sound_wait", {"special": special})


## `FindPartyMonThatSpecies` and its ID-checking twin. Both answer TRUE/FALSE in
## wScriptVar off the species wScriptVar was loaded with; the second adds
## `CheckOwnMon`'s ID and OT test on the slot the first one found.
func _special_find_party_mon(special: int) -> Dictionary:
	var party: Dictionary = _request.get("party", {})
	if party.is_empty():
		return {"ok": false, "reason": &"missing_party_summary", "special": special}
	_script_value = 1 if _party_slot_of_species(
		party, _script_value, special == 67
	) >= 0 else 0
	return {"ok": true}


## `GetFirstPokemonHappiness` walks past every EGG in the list and answers the first
## hatched member's happiness byte, naming that member in the buffer its two boxes
## print.
func _special_first_mon_happiness(special: int) -> Dictionary:
	var happy_party: Dictionary = _request.get("party", {})
	if happy_party.is_empty():
		return {"ok": false, "reason": &"missing_party_summary", "special": special}
	var eggs: Array = happy_party.get("eggs", [])
	var happiness: Array = happy_party.get("happiness", [])
	var names: Array = happy_party.get("names", [])
	var slot: int = 0
	while slot < eggs.size() and bool(eggs[slot]):
		slot += 1
	_script_value = int(happiness[slot]) if slot < happiness.size() else 0
	if slot < names.size():
		_set_text_buffer(3, String(names[slot]), &"first_party_mon", {
			"special": special, "slot": slot,
		})
	return {"ok": true}


## `CheckFirstMonIsEgg` reads slot zero alone, and names it whether or not it is an
## egg: `GetPokemonName` runs on both branches.
func _special_first_mon_is_egg(special: int) -> Dictionary:
	var first_party: Dictionary = _request.get("party", {})
	if first_party.is_empty():
		return {"ok": false, "reason": &"missing_party_summary", "special": special}
	var first_eggs: Array = first_party.get("eggs", [])
	var first_names: Array = first_party.get("names", [])
	_script_value = 1 if not first_eggs.is_empty() and bool(first_eggs[0]) else 0
	if not first_names.is_empty():
		_set_text_buffer(3, String(first_names[0]), &"first_party_mon", {
			"special": special, "slot": 0,
		})
	return {"ok": true}


## `GameboyCheck` reports which console the game booted on. This one is a Game Boy
## Color every time, since every screen here is drawn in the CGB palettes `hCGB`
## selects.
func _special_gameboy_check(_special: int) -> Dictionary:
	_script_value = GBCHECK_CGB
	return {"ok": true}


## `MonCheck` answers whether the player owns the species in wScriptVar and
## `BeastsCheck` runs the same test on all three beasts, leaving the last species it
## asked about behind in wScriptVar when one is missing.
func _special_mon_check(special: int) -> Dictionary:
	var owner_party: Dictionary = _request.get("party", {})
	if owner_party.is_empty():
		return {"ok": false, "reason": &"missing_party_summary", "special": special}
	var owned: Array = owner_party.get("owned_species", [])
	if special == 151:
		_script_value = 1 if owned.has(_script_value) else 0
	else:
		_script_value = 1
		for beast: int in BEAST_SPECIES:
			if not owned.has(beast):
				_script_value = beast
				break
	return {"ok": true}


## InitRoamMons seeds the roam structs with Raikou and Entei at level 40 on their
## starting maps. Gen2WorldAPI.open() already seeds the same imported records, and
## ensure_roaming_mons() keeps positions a player has already moved, so this reports
## rather than resetting a beast that is already loose.
func _special_init_roam_mons(special: int) -> Dictionary:
	if state != null and data != null:
		state.ensure_roaming_mons(data.world_roaming_mons())
	_emit_runtime_event(&"roaming_mons_initialized", {
		"special": special,
		"count": state.roaming_mons().size() if state != null else 0,
	})
	return {"ok": true}


## `engine/events/haircut.asm`. All four open `SelectMonFromParty` and nothing else:
## every box either routine's script shows is the script's own, so the host owes a
## party list and an answer.
func _special_grooming(special: int) -> Dictionary:
	return _stage_runtime_request(&"party_selection_requested", {
		"special": special,
		"routine": GROOMING_TABLE_OF.get(special, &"bills_grandfather"),
	})


## Three tilemap writes and a `ret`. The window stands over the map until `closetext`
## redraws it, so a script that spends money between two of them (the haircut
## brothers' `takemoney`) draws the second over the first.
func _special_money_window(special: int) -> Dictionary:
	_money_window = MONEY_WINDOW_KIND_OF[special]
	_emit_runtime_event(&"money_window_opened", {
		"special": special,
		"kind": _money_window,
		"money": _money_balance(ACCOUNT_YOUR_MONEY),
		"coins": _coins_value(),
	})
	return {"ok": true}


## Each of the five owns its own boxes, and the two counters own the party list and
## both `YesNoBox`es as well, so the whole routine is one host request the way
## `NameRater` is.
func _special_day_care(special: int) -> Dictionary:
	return _stage_runtime_request(&"day_care_requested", {
		"special": special,
		"role": DAY_CARE_ROLE_OF[special],
	})


func _special_name_rater(special: int) -> Dictionary:
	return _stage_runtime_request(&"name_rater_requested", {
		"special": special,
	})


func _special_move_deletion(special: int) -> Dictionary:
	return _stage_runtime_request(&"move_deleter_requested", {
		"special": special,
	})


## `.GetMoveTutorMove` reads the value the map's own `setval` left, and a cartridge
## whose TMHMMoves stops at HM07 has no move to teach, which is the refusal rather
## than a guessed one.
func _special_move_tutor(special: int) -> Dictionary:
	var tutor_move: int = Gen2MoveTutor.move_for_value(data, _script_value)
	if tutor_move <= 0:
		return {
			"ok": false,
			"reason": &"unknown_move_tutor_move",
			"special": special,
			"value": _script_value,
		}
	return _stage_runtime_request(&"move_tutor_requested", {
		"special": special,
		"value": _script_value,
		"move": tutor_move,
	})


## Both of the special's boxes are the host's; it answers with the chosen apricorn and
## how many of it, and a backed-out box is the source's own `wScriptVar = 0`.
func _special_select_apricorn_for_kurt(special: int) -> Dictionary:
	return _stage_runtime_request(&"apricorn_selection_requested", {
		"special": special,
	})


## `GiveParkBalls` clears wContestMon, loads twenty balls and starts the timer. The
## flag itself is the script's own `setflag`, which has already run by here.
func _special_give_park_balls(special: int) -> Dictionary:
	_emit_runtime_event(&"bug_contest_started", {"special": special})
	return {"ok": true}


## Five of the ten contestant flags set, which is both who competes in the judging and
## which sprites the park does not draw.
func _special_select_random_bug_contestants(special: int) -> Dictionary:
	_emit_runtime_event(&"bug_contestants_selected", {"special": special})
	return {"ok": true}


## `ContestDropOffMons` answers 1 when the lead is fainted, which is the one branch
## its callers read, and otherwise masks the party to its first member.
func _special_contest_drop_off_mons(special: int) -> Dictionary:
	var contest_party: Dictionary = _request.get("party", {})
	if contest_party.is_empty():
		return {"ok": false, "reason": &"missing_party_summary", "special": special}
	var lead_fainted: bool = bool(contest_party.get("lead_fainted", false))
	_script_value = 1 if lead_fainted else 0
	if not lead_fainted:
		_emit_runtime_event(&"contest_mons_dropped_off", {
			"special": special,
			"second_species": int(contest_party.get("second_species", 0)),
		})
	return {"ok": true}


func _special_contest_return_mons(special: int) -> Dictionary:
	_emit_runtime_event(&"contest_mons_returned", {"special": special})
	return {"ok": true}


func _special_warp_to_spawn_point(special: int) -> Dictionary:
	_emit_runtime_event(&"warp_to_spawn_point", {"special": special})
	return {"ok": true}


## `CheckPartyFullAfterContest` does not only answer where the Pokemon caught in the
## contest would go: it takes it home, asks `GiveANickname_YesNo` about it and clears
## `wContestMon`. The answer is the party host's, since a nickname is a screen.
func _special_check_party_full_after_contest(special: int) -> Dictionary:
	return _stage_runtime_request(&"contest_mon_requested", {
		"special": special,
	})


## The judging prints three placings and leaves the player's own in wScriptVar, which
## the results script branches on.
func _special_bug_contest_judging(special: int) -> Dictionary:
	return _stage_runtime_request(&"bug_contest_judging_requested", {
		"special": special,
	})


func _special_activate_fishing_swarm(special: int) -> Dictionary:
	_emit_runtime_event(&"phone_special_requested", {
		"special": special, "kind": &"activate_fishing_swarm",
		"species": _script_value,
	})
	return {"ok": true}


func _special_toggle_maptile_decorations(special: int) -> Dictionary:
	_apply_maptile_decorations()
	_emit_runtime_event(&"decoration_callback_applied", {
		"special": special,
		"kind": &"toggle_maptile_decorations",
		"decorations": state.maptile_decorations() if state != null else {},
	})
	return {"ok": true}


## `ToggleDecorationVisibility` per slot: an empty slot sets the object's event flag
## and the renderer removes it, and a filled one clears the flag and writes the
## decoration's own variable sprite.
func _special_toggle_decorations_visibility(special: int) -> Dictionary:
	var shown: Dictionary = {}
	for row: Dictionary in Gen2WorldDecoration.OBJECT_SLOTS:
		var deco: int = state.maptile_decoration(
			StringName(row["slot"])
		) if state != null else 0
		var sprite: int = int(data.decoration(deco).get("sprite", 0)) \
			if data != null and deco > 0 else 0
		_staged_flags[int(row["flag"])] = sprite <= 0
		if sprite <= 0:
			continue
		shown[int(row["variable_sprite"])] = sprite
		_emit_runtime_event(&"variable_sprite_changed", {
			"variable_sprite": int(row["variable_sprite"]),
			"sprite": sprite,
		})
	_emit_runtime_event(&"decoration_callback_applied", {
		"special": special,
		"kind": &"toggle_decorations_visibility",
		"sprites": shown,
	})
	return {"ok": true}


func _special_slot_machine(special: int) -> Dictionary:
	return _stage_runtime_request(&"slot_machine_requested", {
		"special": special,
		## `Slots_InitBias`' own `ld a, [wScriptVar] / and a`, which is
		## the only thing the operand decides.
		"lucky": _script_value != 0,
		"coins": _coins_value(),
	})


func _special_card_flip(special: int) -> Dictionary:
	return _stage_runtime_request(&"card_flip_requested", {
		"special": special,
		"coins": _coins_value(),
	})


func _special_unown_puzzle(special: int) -> Dictionary:
	return _stage_runtime_request(&"unown_puzzle_requested", {
		"special": special,
		## `maskbits NUM_UNOWN_PUZZLES` is what bounds the operand, so a
		## value outside the four wraps rather than failing.
		"puzzle": _script_value & 0x3,
	})


## The word the wall spells, staged as the text `JoyWaitAorB` holds until a button. A
## host that can reach the chamber's own tileset draws it as
## `_DisplayUnownWords_CopyWord`'s 2x2 letter blocks instead ([Gen2UnownWallPage]);
## the wait it answers is this one.
func _special_display_unown_words(special: int) -> Dictionary:
	var wall_word: String = data.unown_wall_word(_script_value) if data != null \
		else ""
	if wall_word.is_empty():
		return {
			"ok": false,
			"reason": &"unknown_unown_wall",
			"special": special,
			"wall": _script_value,
		}
	## `special` is a StringName tag on a pending text, not the index, so
	## the wall is named under its own key.
	return _stage_internal_text(wall_word, false, {"unown_wall": _script_value})


## `Random` masked to two bits plus three. The same byte is stepped by
## `CheckDailyResetTimer` on every day that passes, which is
## `Gen2WorldState.reset_daily_flags`; this is the resample its own script asks for.
func _special_sample_kenji_break_countdown(_special: int) -> Dictionary:
	_staged_kenji_break_timer = Gen2WorldState.kenji_break_countdown(_random)
	_has_staged_kenji_break_timer = true
	return {"ok": true}


## `sMysteryGiftTrainerHouseFlag` straight into wScriptVar: a player who has never
## received a Mystery Gift is turned away, and one who has fights CAL under the
## partner's name.
func _special_trainer_house(_special: int) -> Dictionary:
	_script_value = int(_mystery_gift_section().get("trainer_house_flag", 0))
	return {"ok": true}


## Zero when nothing is waiting and the item plus one when something is.
## POKECENTER_2F's scene script branches on the zero, and the officer it puts on the
## floor is what hands the gift over.
func _special_check_mystery_gift(_special: int) -> Dictionary:
	_script_value = Gen2MysteryGift.check_value(_mystery_gift_section())
	return {"ok": true}


## Carrie's own row on GOLDENROD DEPT. STORE 5F, behind a `GameboyCheck` this project
## always passes: there is no Game Boy here that is not a colour one.
func _special_unlock_mystery_gift(_special: int) -> Dictionary:
	Gen2MysteryGift.unlock(_mystery_gift_section())
	return {"ok": true}


func _special_get_mystery_gift_item(special: int) -> Dictionary:
	return _stage_mystery_gift_item(special)


## `wPartySpecies`' first byte and nothing else: the wall opens for a party led by
## Ho-Oh. `GetMapAttributesPointer` in front of it is marked pointless in the pin and
## answers nothing.
func _special_ho_oh_chamber(special: int) -> Dictionary:
	var chamber_party: Dictionary = _request.get("party", {})
	if chamber_party.is_empty():
		return {"ok": false, "reason": &"missing_party_summary", "special": special}
	var chamber_species: Array = chamber_party.get("species", [])
	if not chamber_species.is_empty() and int(chamber_species[0]) == SPECIES_HO_OH:
		_staged_flags[EVENT_WALL_OPENED_IN_HO_OH_CHAMBER] = true
	return {"ok": true}


## A WATER STONE in the bag opens it, and so does one held by any party member:
## `.loop` walks the party backwards reading MON_ITEM. The flag is tested first, so a
## wall already open spends nothing.
func _special_omanyte_chamber(special: int) -> Dictionary:
	if not _event_flag_active(EVENT_WALL_OPENED_IN_OMANYTE_CHAMBER):
		var stone_party: Dictionary = _request.get("party", {})
		if stone_party.is_empty():
			return {
				"ok": false, "reason": &"missing_party_summary", "special": special,
			}
		var opens: bool = _item_quantity(ITEM_WATER_STONE) > 0
		if not opens:
			for held: Variant in stone_party.get("held_items", []):
				if int(held) == ITEM_WATER_STONE:
					opens = true
					break
		if opens:
			_staged_flags[EVENT_WALL_OPENED_IN_OMANYTE_CHAMBER] = true
	return {"ok": true}


## `wBattleResult`'s BATTLERESULT_CAUGHT_CELEBI, which `PokeBallEffect` sets on a
## catch made in a BATTLETYPE_CELEBI fight and nothing else clears until the next
## battle.
func _special_check_caught_celebi(_special: int) -> Dictionary:
	_script_value = 1 if state != null and state.battle_caught_celebi() else 0
	return {"ok": true}


## The whole routine is a sprite-anim cutscene and a battle type. There is no
## sprite-anim layer outside the intro, so what it owes a script is the wait its own
## loop spends and the type the fight behind it starts with.
func _special_celebi_shrine_event(special: int) -> Dictionary:
	_loaded_battle_type = Gen2Battle.BATTLETYPE_CELEBI
	if not _battle_setup.is_empty():
		_battle_setup["battle_type"] = Gen2Battle.BATTLETYPE_CELEBI
	_emit_runtime_event(&"presentation_special_applied", {
		"special": special, "kind": &"celebi_shrine",
	})
	return _stage_frame_wait(
		CELEBI_SHRINE_PASSES * CELEBI_SHRINE_FRAMES_PER_PASS,
		{"special": special, "kind": &"celebi_shrine"}
	)


## `PlayRadio` opens the station wScriptVar names, prints its line in a four-row box
## and holds until A or B. It is the Pokegear's own radio without the Pokegear, so the
## station is the request and the host draws it.
func _special_map_radio(special: int) -> Dictionary:
	return _stage_runtime_request(&"map_radio_requested", {
		"special": special,
		"station": _script_value,
	})


## `ScriptReturnCarry`: TRUE once `wLuckyNumberDayTimer` has run out, which is the
## Friday the show comes round on.
func _special_check_lucky_number_show_flag(_special: int) -> Dictionary:
	_script_value = 1 if state != null and state.lucky_number_show_ready() else 0
	return {"ok": true}


## `RestartLuckyNumberCountdown`, then the GAME_OVER bit off the show flag, then
## `LoadOrRegenerateLuckyIDNumber`. The bit is the radio segment's own and this
## project's radio reads the timer instead, so what is left is the countdown and the
## number.
func _special_reset_lucky_number_show_flag(_special: int) -> Dictionary:
	_staged_lucky_number_days_left = _lucky_number_days_until_friday()
	_has_staged_lucky_number_days_left = true
	_refresh_lucky_id_number()
	return {"ok": true}


## `PrintNum` with PRINTNUM_LEADINGZEROS over five digits into wStringBuffer3, which
## the radio tower's own text prints.
func _special_print_todays_lucky_number(special: int) -> Dictionary:
	_refresh_lucky_id_number()
	_set_text_buffer(
		RomLayout.STRING_BUFFER_3, "%05d" % _lucky_id_number(), &"lucky_number",
		{"special": special}
	)
	return {"ok": true}


## The whole walk is over ID numbers the party mirror carries, so the routine is the
## host's arithmetic rather than a screen.
func _special_check_for_lucky_number_winners(special: int) -> Dictionary:
	var lucky_party: Dictionary = _request.get("party", {})
	if lucky_party.is_empty():
		return {"ok": false, "reason": &"missing_party_summary", "special": special}
	_refresh_lucky_id_number()
	var winner: Dictionary = Gen2WorldPartyHost.lucky_number_match(
		_lucky_id_number(),
		lucky_party.get("id_numbers", []),
		lucky_party.get("species", []),
		lucky_party.get("eggs", []),
		lucky_party.get("stored_id_numbers", []),
		lucky_party.get("stored_species", [])
	)
	_script_value = int(winner.get("script_value", 0))
	if _script_value == 0:
		return {"ok": true}
	## `GetPokemonName` on the matching row's species, into the buffer
	## both boxes print, and then the box the match's own location picks.
	var winner_species: int = int(winner.get("species", 0))
	_cur_party_species = winner_species
	var winner_name: String = String(
		data.species(winner_species).get("name", "")
	) if data != null else ""
	_set_text_buffer(RomLayout.STRING_BUFFER_1, winner_name, &"lucky_number_winner", {
		"special": special, "species": winner_species,
	})
	var lucky_box: String = _special_box(
		"lucky_number",
		"match_pc" if bool(winner.get("in_storage", false)) else "match_party"
	)
	if lucky_box.is_empty():
		return {"ok": false, "reason": &"missing_special_text", "special": special}
	return _stage_internal_text(lucky_box, false, {"special": special})


## The record straight out of the save into wMagikarpLength, printed the way
## `PrintMagikarpLength` prints it, and the sign's own box. An unbeaten record is two
## zero bytes, which is what the sign shows before anyone has measured one.
func _special_magikarp_house_sign(special: int) -> Dictionary:
	var record: Dictionary = state.best_magikarp() if state != null else {}
	_set_text_buffer(RomLayout.STRING_BUFFER_1, Gen2WorldPartyHost.magikarp_length_string(
		int(record.get("feet", 0)), int(record.get("inches", 0))
	), &"magikarp_length", {"special": special})
	_set_text_ram("magikarp_record_holder", String(record.get("ot", "")))
	var sign_box: String = _special_box("magikarp", "record")
	if sign_box.is_empty():
		return {"ok": false, "reason": &"missing_special_text", "special": special}
	return _stage_internal_text(sign_box, false, {"special": special})


func _special_bank_of_mom(_special: int) -> Dictionary:
	return _bank_of_mom(MOM_CHECK_INITIALIZED)


## `ld a, [wUnownDex] / and a / ret z`: with no Unown caught the routine draws nothing
## at all, which the host answers for since it is the one that holds the dex.
func _special_unown_printer(special: int) -> Dictionary:
	return _stage_runtime_request(&"unown_printer_requested", {
		"special": special,
		"caught": state.unown_caught_count() if state != null else 0,
	})


## `_Diploma` draws `PlaceDiplomaOnScreen`'s page and waits for a button;
## `_PrintDiploma` draws the same page and then holds in `SendScreenToPrinter`.
## Neither writes anything a script reads, so the request carries only which of the
## two loops is standing.
func _special_diploma(special: int) -> Dictionary:
	return _stage_runtime_request(&"diploma_requested", {
		"special": special,
		"printing": special == SPECIAL_PRINT_DIPLOMA,
	})


## The counter is one loop: the prize list, a yes/no on the row, and whichever of the
## four boxes the answer reaches. B on the list is the only way out and prints her
## parting line.
func _special_buena_prize(special: int) -> Dictionary:
	return _stage_buena_prize_menu(special)


## `PrintSeerText SEER_INTRO`, `JoyWaitAorB`, and only then the list.
func _special_poke_seer(special: int) -> Dictionary:
	var seer_intro: String = _special_box("poke_seer", "see_all")
	if seer_intro.is_empty():
		return {"ok": false, "reason": &"missing_special_text", "special": special}
	return _stage_internal_text(seer_intro, false, {
		"special": special,
		"party_selection_after_text": {
			"special": special,
			"routine": PARTY_SELECTION_ROUTINE_OF[special],
		},
	})


## All three open `SelectMonFromParty` and answer on what came back. `PhotoStudio`
## prints its own question in front of the list, which is the one box a script does
## not carry for it.
func _special_party_selection(special: int) -> Dictionary:
	if special == SPECIAL_PHOTO_STUDIO:
		var asked: String = _special_box("photo_studio", "which_mon")
		if asked.is_empty():
			return {"ok": false, "reason": &"missing_special_text", "special": special}
		_standing_text = asked
	return _stage_runtime_request(&"party_selection_requested", {
		"special": special,
		"routine": PARTY_SELECTION_ROUTINE_OF[special],
	})


## `TryAddMonToParty` with a level 15 SHUCKLE holding a BERRY, named SHUCKIE under
## MANIA's own OT and ID, and the daily flag behind it. A full party is `.NotGiven`,
## which answers zero and gives nothing: the box is never reached.
func _special_give_shuckle(special: int) -> Dictionary:
	return _stage_runtime_request(&"pokemon_requested", {
		"special": special,
		"kind": &"give_shuckle",
		"pokemon": Gen2WorldPartyHost.SHUCKLE,
		"level": Gen2WorldPartyHost.SHUCKIE_LEVEL,
		"item": Gen2WorldPartyHost.ITEM_BERRY,
		"nickname": Gen2WorldPartyHost.SHUCKIE_NICKNAME,
		"original_trainer": Gen2WorldPartyHost.MANIA_OT_NAME,
		"ot_id": Gen2WorldPartyHost.MANIA_OT_ID,
		"party_only": true,
	})


## The box alone: the question is the `writetext` in front of it, and the answer is
## `yesorno`'s own, YES writing 1 and B writing 0.
func _special_ask_remember_password(_special: int) -> Dictionary:
	_pending = {
		"type": &"choice",
		"command": &"yesorno",
		"choices": [&"yes", &"no"],
		"text": _standing_text,
		"special": &"ask_remember_password",
		"header": ASK_REMEMBER_PASSWORD_BOX.duplicate(),
		"source": _request.duplicate(true),
	}
	return _waiting_result()


## `AddMobileMonToParty` with one of `OddEggs`' fourteen rows, rolled against
## `OddEggProbabilities`. `TossKeyItem` runs first and removes nothing when the pack
## holds no ticket; it writes no wScriptVar either way, so the toss's own answer is
## put back.
func _special_give_odd_egg(special: int) -> Dictionary:
	if _item_quantity(ITEM_EGG_TICKET) > 0:
		var kept: int = _script_value
		var tossed: Dictionary = _stage_item_delta(ITEM_EGG_TICKET, -1)
		_script_value = kept
		if not bool(tossed.get("ok", true)):
			return tossed
	return _stage_runtime_request(&"pokemon_requested", {
		"special": special,
		"kind": &"give_odd_egg",
		"party_only": true,
	})


## Not a gift at all: the Dragon Shrine's `givepoke` has already run, and this
## rewrites the last DRATINI in the party with one of two movesets. A wScriptVar above
## one returns before the search, which is what the elder's third answer leaves
## standing.
func _special_give_dratini(special: int) -> Dictionary:
	if _script_value > 1:
		return {"ok": true}
	return _stage_runtime_request(&"dratini_moveset_requested", {
		"special": special,
		"moveset": _script_value,
	})


## `CheckCaughtMon` on wScriptVar less one, and nothing at all when it is already
## caught: the prize counter has handed the Pokemon over by here, so this is the
## new-entry screen alone. The species byte is one high, which is the `dec a` in front
## of both calls.
func _special_game_corner_prize_mon_check_dex(special: int) -> Dictionary:
	var prize_species: int = _script_value
	if prize_species <= 0:
		return {"ok": false, "reason": &"invalid_prize_species", "special": special}
	if state != null and state.has_caught_species(prize_species):
		return {"ok": true}
	_staged_caught_species[prize_species] = true
	return _stage_runtime_request(&"pokedex_entry_requested", {
		"special": special,
		"species": prize_species,
	})


## `DoNthMenu` over the five words of today's category, and the answer is whether the
## row matches the low nibble of `wBuenasPassword`. The category is the high nibble,
## which is what the radio show drew this morning.
func _special_buenas_password(special: int) -> Dictionary:
	var password: int = _buenas_password()
	if password < 0:
		return {"ok": false, "reason": &"missing_buenas_password", "special": special}
	_stage_buenas_password_menu(password)
	return {"ok": true}


func _special_random_unseen_wild_mon(special: int) -> Dictionary:
	var rare_species: int = _phone_unseen_rare_species()
	if rare_species <= 0:
		_emit_runtime_event(&"phone_special_requested", {
			"special": special, "kind": &"random_unseen_wild_mon",
			"internal_text": false, "script_value": 1,
		})
		_script_value = 1
	else:
		var rare_name: String = String(data.species(rare_species).get("name", ""))
		_set_text_buffer(1, rare_name, &"phone_unseen_wild_mon", {
			"special": special, "species": rare_species,
		})
		_emit_runtime_event(&"phone_special_requested", {
			"special": special, "kind": &"random_unseen_wild_mon",
			"internal_text": true, "buffer": 1, "value": rare_name,
			"species": rare_species, "script_value": 0,
		})
		_script_value = 0
	return {"ok": true}


func _special_random_phone_wild_mon(special: int) -> Dictionary:
	var wild_name: String = _phone_wild_mon_name()
	_set_text_buffer(1, wild_name, &"phone_wild_mon", {"special": special})
	_emit_runtime_event(&"phone_special_requested", {
		"special": special, "kind": &"random_phone_wild_mon",
		"buffer": 1, "value": wild_name,
	})
	return {"ok": true}


func _special_random_phone_mon(special: int) -> Dictionary:
	var trainer_mon_name: String = _phone_trainer_mon_name()
	_set_text_buffer(1, trainer_mon_name, &"phone_mon", {"special": special})
	_emit_runtime_event(&"phone_special_requested", {
		"special": special, "kind": &"random_phone_mon",
		"buffer": 1, "value": trainer_mon_name,
	})
	return {"ok": true}
## ToggleMaptileDecorations and SetDecorationTile
## (engine/overworld/decorations.asm). Coordinates are changeblock coordinates;
## Gen2WorldAPI applies their padded-buffer conversion.
func _apply_maptile_decorations() -> void:
	for slot: StringName in Gen2WorldDecoration.MAPTILE_AT:
		var block: int = _decoration_block(slot)
		if block <= 0:
			continue
		var at: Vector2i = Gen2WorldDecoration.MAPTILE_AT[slot]
		_emit_runtime_event(&"map_block_changed", {"x": at.x, "y": at.y, "block": block})
	var carpet_block: int = _decoration_block(Gen2WorldDecoration.SLOT_CARPET)
	if carpet_block > 0:
		for row: int in Gen2WorldDecoration.CARPET_AT.size():
			var at: Vector2i = Gen2WorldDecoration.CARPET_AT[row]
			_emit_runtime_event(&"map_block_changed", {
				"x": at.x, "y": at.y,
				"block": carpet_block + Gen2WorldDecoration.CARPET_BLOCK_STEP[row],
			})
	## `SetPosterVisibility` is the one slot that also masks a bg event.
	_staged_flags[EVENT_PLAYERS_ROOM_POSTER] = \
		_decoration_block(Gen2WorldDecoration.SLOT_POSTER) > 0


## `_GetDecorationSprite`: the block a slot's own decoration stamps, which is the
## imported row's `DECOATTR_SPRITE`. Zero when the slot is empty.
func _decoration_block(slot: StringName) -> int:
	if state == null or data == null:
		return 0
	var deco: int = state.maptile_decoration(slot)
	return int(data.decoration(deco).get("sprite", 0)) if deco > 0 else 0


## One `RomLayout.SPECIAL_TEXT_RUNS` box, with the buffers this runner has
## filled written into it. The imported string still carries
## [Gen2TextStream]'s markers, which is what lets one cached box serve both the
## screen that draws it and a text staged straight onto the map.
func _special_box(run: String, name: String) -> String:
	if data == null:
		return ""
	var text: String = data.special_text(run, name)
	if text.is_empty():
		return ""
	var ram: Dictionary = _text_buffer_ram()
	for raw_address: Variant in ram:
		text = Gen2TextStream.fill_all_markers(
			text,
			"%s%04X>" % [Gen2TextStream.RAM_MARKER, int(raw_address)],
			String(ram[raw_address])
		)
	if not player_name.is_empty():
		text = Gen2TextStream.fill_all_markers(text, "<PLAYER", player_name)
	return text


## `data/items/buena_prizes.asm`: the item and what it costs in Blue Card
## points. `.PrintPrizePoints` prints the cost as one character, so no row can
## cost more than nine.
const BUENA_PRIZES: Array = [
	[2, 2], [14, 2], [36, 3], [32, 3], [27, 5], [28, 5], [29, 5], [31, 5], [26, 5],
]


## `Buena_PlacePrizeMenuBox` and `Buena_PrizeMenu`, plus the question that
## stands over them. The rows are the prize names with their cost beside them,
## which is what `SCROLLINGMENU_ITEMS_NORMAL` draws in two columns.
func _stage_buena_prize_menu(special: int) -> Dictionary:
	var rows: Array[String] = []
	for prize: Array in BUENA_PRIZES:
		rows.append("%s %d" % [
			data.item_name(int(prize[0])) if data != null else "", int(prize[1]),
		])
	var asked: String = _special_box("buena_prize", "ask_which_prize")
	if asked.is_empty():
		return _fail(&"missing_special_text", {"special": special})
	_pending = {
		"type": &"menu",
		"command": &"buena_prize",
		"options": rows,
		## `.MenuHeader`'s `menu_coords 1, 1, 16, 9` and its `db 4, 13`, then
		## `db 1` for the row the cursor opens on. `ScrollingMenu` always draws
		## its own cursor and this list is a row longer than its window, which
		## is what the flags and the row count stand for here.
		"header": {
			"default": 1,
			"data_flags": Gen2MenuBox.STATICMENU_CURSOR,
			"left": 1, "top": 1, "right": 16, "bottom": 9,
			"rows": 4, "arrows": true,
		},
		"text": asked,
		"special": &"buena_prize",
		"prize_special": special,
		"balance": _blue_card_balance(),
		"source": _request.duplicate(true),
	}
	return _waiting_result()


## The three refusals and the one purchase, in the order the routine tests them:
## the balance first, then the bag, and only then the deduction.
func _buy_buena_prize(special: int, row: int) -> Dictionary:
	var item: int = int(BUENA_PRIZES[row][0])
	var cost: int = int(BUENA_PRIZES[row][1])
	if _blue_card_balance() < cost:
		return _buena_prize_box(special, "not_enough_points", false)
	var received: Dictionary = _stage_item_delta(item, 1)
	if not bool(received.get("ok", false)):
		return received
	if _script_value == 0:
		return _buena_prize_box(special, "no_room", false)
	_staged_blue_card_balance = _blue_card_balance() - cost
	return _buena_prize_box(special, "here_you_go", false)


## One of the counter's boxes. Every one of them but her parting line falls back
## into the list, which is `.print`'s own `jr .loop`.
func _buena_prize_box(special: int, name: String, closing: bool) -> Dictionary:
	var box: String = _special_box("buena_prize", name)
	if box.is_empty():
		return _fail(&"missing_special_text", {"special": special})
	return _stage_internal_text(box, closing, {"special": special} if closing else {
		"special": special, "buena_prize_after_text": special,
	})


## `BankOfMom`'s jumptable, one index at a time (`engine/events/mom.asm`). Every
## state either prints a box, opens her menu or opens the dial, so the source's
## `.loop` is the chain of pendings each of them leaves behind. `DSTChecks` is the
## one branch not built, and it is a save-format bump: `.nope` asks whether to move
## the clock an hour, which needs a saved `wDST` bit and the `wStartHour` shift
## behind it. The branch taken instead is `.JustDoWhatYouCan`, which is what a
## clock nowhere near a boundary reaches.
func _bank_of_mom(index: int) -> Dictionary:
	match index:
		MOM_CHECK_INITIALIZED:
			var flags: int = _mom_savings_flags()
			if flags & MOM_ACTIVE != 0:
				return _bank_of_mom(MOM_IS_THIS_ABOUT_YOUR_MONEY)
			## `.CheckIfBankInitialized` sets the bit before the question, so a
			## player who says NO has still opened the account.
			_staged_mom_savings_flags = flags | MOM_ACTIVE
			return _bank_of_mom(MOM_INITIALIZE)
		MOM_INITIALIZE:
			return _mom_yes_no("leaving_1", index)
		MOM_IS_THIS_ABOUT_YOUR_MONEY:
			return _mom_yes_no("is_this_about_your_money", index)
		MOM_ACCESS_BANK:
			return _stage_mom_menu()
		MOM_STORE_MONEY:
			return _mom_dial_box("store_money", MOM_DIAL_DEPOSIT)
		MOM_TAKE_MONEY:
			return _mom_dial_box("take_money", MOM_DIAL_WITHDRAW)
		MOM_STOP_OR_START_SAVING:
			return _mom_yes_no("save_money", index)
		MOM_JUST_DO_WHAT_YOU_CAN:
			return _mom_box("just_do_what_you_can", MOM_EXIT)
	return _fail(&"invalid_bank_of_mom_state", {"state": index})


## `.AccessBankOfMom`: the question, and `VerticalMenu` over the box it left.
func _stage_mom_menu() -> Dictionary:
	var asked: String = _special_box("bank_of_mom", "what_do_you_want_to_do")
	if asked.is_empty():
		return _fail(&"missing_special_text", {"special": SPECIAL_BANK_OF_MOM})
	_pending = {
		"type": &"menu",
		"command": &"bank_of_mom",
		"options": MOM_MENU_ROWS.duplicate(),
		## `db 1`, and STATICMENU_CURSOR without STATICMENU_DISABLE_B: B leaves,
		## which is `.cancel`.
		"header": {"default": 1, "data_flags": 0},
		"text": asked,
		"special": &"bank_of_mom_menu",
		"source": _request.duplicate(true),
	}
	return _waiting_result()


## One of her boxes, with the jumptable index the routine is on once it has been
## read. Every box but the two the dial stands behind takes this path.
func _mom_box(name: String, next_state: int) -> Dictionary:
	var box: String = _special_box("bank_of_mom", name)
	if box.is_empty():
		return _fail(&"missing_special_text", {"special": SPECIAL_BANK_OF_MOM})
	if next_state == MOM_EXIT:
		return _stage_internal_text(box, false, {"special": SPECIAL_BANK_OF_MOM})
	return _stage_internal_text(box, false, {"bank_of_mom_after_text": next_state})


## `.StoreMoney` and `.TakeMoney` print their question and then open the dial,
## so the box carries which way the transaction goes rather than an index.
func _mom_dial_box(name: String, mode: StringName) -> Dictionary:
	var box: String = _special_box("bank_of_mom", name)
	if box.is_empty():
		return _fail(&"missing_special_text", {"special": SPECIAL_BANK_OF_MOM})
	return _stage_internal_text(box, false, {"bank_of_mom_dial": mode})


## One of the three `YesNoBox` questions, over the box the state just printed.
func _mom_yes_no(name: String, state_index: int) -> Dictionary:
	var box: String = _special_box("bank_of_mom", name)
	if box.is_empty():
		return _fail(&"missing_special_text", {"special": SPECIAL_BANK_OF_MOM})
	_pending = {
		"type": &"choice",
		"command": &"bank_of_mom",
		"choices": [&"yes", &"no"],
		"text": box,
		"special": &"bank_of_mom_choice",
		"mom_state": state_index,
		"source": _request.duplicate(true),
	}
	return _waiting_result()


## `.StoreMoney`'s tail and `.TakeMoney`'s, which differ only in which account is
## which. Three things the source does that a rewrite loses: `GiveMoney` adds into
## `wStringBuffer2` rather than into an account, so the ceiling is tested against
## the balance the transaction would leave and nothing is written when it fails;
## both refusals `ret` with `wJumptableIndex` unchanged, so her question is asked
## again and the dial reopens; and a dial left at zero is `.CancelDeposit`, the
## same branch B takes.
func _finish_mom_bank_dial(mode: StringName, amount: int) -> Dictionary:
	var deposit: bool = mode == MOM_DIAL_DEPOSIT
	var state_index: int = MOM_STORE_MONEY if deposit else MOM_TAKE_MONEY
	if amount <= 0:
		return _bank_of_mom(MOM_JUST_DO_WHAT_YOU_CAN)
	var from_account: int = ACCOUNT_YOUR_MONEY if deposit else ACCOUNT_MOMS_MONEY
	var to_account: int = ACCOUNT_MOMS_MONEY if deposit else ACCOUNT_YOUR_MONEY
	if _money_balance(from_account) < amount:
		return _mom_box(
			"insufficient_funds_in_wallet" if deposit else "havent_saved_that_much",
			state_index
		)
	if _money_balance(to_account) + amount > Gen2WorldInventory.MAX_MONEY:
		return _mom_box(
			"not_enough_room_in_bank" if deposit else "not_enough_room_in_wallet",
			state_index
		)
	_move_mom_money(from_account, to_account, amount)
	_bank_of_mom_after_sound = MOM_EXIT
	_mom_receipt_box = "stored_money" if deposit else "taken_money"
	return _stage_audio_request(&"sound", {"address": SFX_TRANSACTION})


## The `TakeMoney`/`GiveMoney` pair the transaction is, without the wScriptVar
## neither of them writes.
func _move_mom_money(from_account: int, to_account: int, amount: int) -> void:
	for row: Array in [[from_account, -amount], [to_account, amount]]:
		var account: int = int(row[0])
		var next: int = _money_balance(account) + int(row[1])
		_staged_money[account] = next
		_emit_runtime_event(&"money_changed", {
			"account": account, "amount": amount, "balance": next,
			"direction": &"give" if int(row[1]) > 0 else &"take",
		})


## `advance` has to answer with a result, where the command loop is what turns a
## staged pending into one, so every step the routine takes from inside a pending
## handler is answered through here.
func _mom_result(staged: Dictionary) -> Dictionary:
	if staged.has("status") or not bool(staged.get("ok", false)):
		return staged
	return advance()


## `_pending`'s own `special`, which is a routine's name wherever a handler
## claims the box and the cartridge's index wherever nothing does. Read as a
## name, so an index is simply not one: comparing the two is an engine error
## rather than a false answer.
## `BattleTowerRoomMenu_UpdatePickLevelMenu`'s `.a_button` and `.b_button`: the
## CANCEL row and B both leave with `$a` in wScriptVar, and a level row is
## refused by either check before it is stored.
func _resolve_room_menu(choice: int) -> Dictionary:
	var groups: int = int(_pending.get("groups", RomLayout.BATTLETOWER_LEVEL_GROUPS))
	_pending = {}
	if choice < 0 or choice >= groups:
		_script_value = ROOM_MENU_CANCELLED
		return advance()
	var tower: Gen2BattleTower = _battle_tower()
	tower.chosen_group = choice + 1
	var party: Dictionary = _battle_tower_party()
	if Gen2BattleTower.level_check(party, tower.chosen_group) >= 0:
		return _stage_room_menu_refusal("party_mon_tops_this_level")
	var uber: int = Gen2BattleTower.ubers_check(party, tower.chosen_group)
	if uber >= 0:
		var names: Array = (_request.get("party", {}) as Dictionary).get("names", [])
		return _stage_room_menu_refusal(
			"uber_restriction", String(names[uber]) if uber < names.size() else ""
		)
	_script_value = ROOM_MENU_CHOSEN
	return advance()


## The Battle Tower's own SRAM section, which the runner writes in place: every
## byte of it is one the cartridge writes through `OpenSRAM` straight away, with
## no transaction between the receptionist and the section.
func _battle_tower() -> Gen2BattleTower:
	return state.battle_tower() if state != null else Gen2BattleTower.new()


func _link_session() -> Gen2LinkSession:
	return state.link_session() if state != null else Gen2LinkSession.new()


func _link_transport() -> Gen2LinkTransport:
	return state.link_transport() if state != null else Gen2LinkTransport.new()


## `CheckTimeCapsuleCompatibility`. The three failures each name a party member
## in wStringBuffer1 and the move failure names the move in front of it, which
## is `GetMoveName` and `CopyName1` before `GetIncompatibleMonName`.
func _check_time_capsule_compatibility() -> Dictionary:
	var party: Dictionary = _request.get("party", {})
	if party.is_empty():
		return {
			"ok": false, "reason": &"missing_party_summary",
			"special": SPECIAL_CHECK_TIME_CAPSULE_COMPATIBILITY,
		}
	var verdict: Dictionary = Gen2LinkSession.time_capsule_compatibility(party)
	_script_value = int(verdict["value"])
	if _script_value == Gen2LinkSession.TIME_CAPSULE_OK:
		return {"ok": true}
	if _script_value == Gen2LinkSession.TIME_CAPSULE_MOVE_TOO_NEW and data != null:
		_set_text_buffer(
			RomLayout.STRING_BUFFER_1,
			String(data.move(int(verdict["move"])).get("name", "")),
			&"time_capsule_move", {"move": int(verdict["move"])}
		)
	var names: Array = party.get("names", [])
	var slot: int = int(verdict["slot"])
	if slot >= 0 and slot < names.size():
		_set_text_buffer(
			RomLayout.STRING_BUFFER_3, String(names[slot]), &"time_capsule_mon",
			{"slot": slot, "species": int(verdict["species"])}
		)
	return {"ok": true}


## `TradeCenter`, `Colosseum` and `TimeCapsule`, which are one routine each
## around `LinkCommunications`: the room sets `wLinkMode` and then runs the
## exchange the console in front of the player is for. The exchange itself is a
## host request, because it is a party swap or a battle rather than anything the
## script can settle.
func _stage_link_room(special: int) -> Dictionary:
	var session: Gen2LinkSession = _link_session()
	session.open_room(LINK_ROOM_MODES[special])
	return _stage_runtime_request(&"link_room_requested", {
		"special": special,
		"link_mode": session.link_mode,
		"peer": session.peer.duplicate(true),
		"connection": session.connection_status,
	})


## The tower's own generator. `Random` is the cartridge's one RNG and this
## runner is scene free, so the seed comes in with the request and each draw
## takes its own offset: the opponent, its three lines and the reward are four
## separate rolls in the source and must not repeat here.
func _battle_tower_random(offset: int) -> RandomNumberGenerator:
	var random := RandomNumberGenerator.new()
	random.seed = int(_request.get("battle_tower_seed", randi())) + offset
	return random


## The item pocket as `BattleTower_GiveReward` walks it, staged rows over the
## saved ones. A row staged to zero is one the script has just spent and is not
## in the pack any more.
func _pack_items() -> Dictionary:
	var pack: Dictionary = state.items() if state != null else {}
	for item: Variant in _staged_items:
		var quantity: int = int(_staged_items[item])
		if quantity > 0:
			pack[item] = quantity
		else:
			pack.erase(item)
	return pack


## The cartridge's own Battle Tower block, empty when there is no cache behind
## the runner at all, which is what the specials probe runs with.
func _battle_tower_data() -> Dictionary:
	return data.battle_tower() if data != null else {}


## The party facts the tower's own checks read, off the read-only mirror.
func _battle_tower_party() -> Dictionary:
	var party: Dictionary = _request.get("party", {})
	return {
		"species": party.get("species", []),
		"levels": party.get("levels", []),
		"held_items": party.get("held_items", []),
		"eggs": party.get("eggs", []),
	}


## `_CheckForBattleTowerRules`: every rule is run rather than stopping at the
## first failure, so a party can fail more than one and the receptionist says so
## once per failure. `BattleTower_PleaseReturnWhenReady` closes the run.
##
## wScriptVar is TRUE when something failed, which is what
## `ifnotequal FALSE, Script_WaitButton` refuses the challenge on.
func _check_battle_tower_rules() -> Dictionary:
	var failures: Array = Gen2BattleTower.rule_failures(_battle_tower_party())
	if failures.is_empty():
		_script_value = 0
		return {"ok": true}
	_script_value = 1
	## `ld [hl], '3'` at the top of the routine: the box that names how many may
	## be entered prints the number out of `wStringBuffer2` rather than spelling
	## it, so a party of the wrong size is told the rule and not just refused.
	_set_text_buffer(
		RomLayout.STRING_BUFFER_2, str(Gen2BattleTower.PARTY_LENGTH), &"battle_tower_rules"
	)
	var boxes: Array = [_special_box("battle_tower", "excuse_me")]
	for failure: String in failures:
		boxes.append(_special_box("battle_tower", failure))
	boxes.append(_special_box("battle_tower", "return_when_ready"))
	for box: String in boxes:
		if box.is_empty():
			return _fail(
				&"missing_special_text", {"special": SPECIAL_CHECK_BATTLE_TOWER_RULES}
			)
	var head: String = String(boxes.pop_front())
	return _stage_internal_text(head, false, {
		"special": &"battle_tower_rules", "next_internal_texts": boxes,
	})


## `Menu_ChallengeExplanationCancel`, a three-row `VerticalMenu` whose rows are
## the cartridge's own strings. A row answers its own one-based number and B
## answers 4, which is why the script tests only Challenge and Explanation.
func _stage_challenge_menu() -> Dictionary:
	var rows: Array = (_battle_tower_data().get("menu_rows", []) as Array).duplicate()
	if rows.size() != RomLayout.BATTLETOWER_CHALLENGE_MENU_ROWS:
		return _fail(&"missing_battle_tower_menu", {"special": SPECIAL_CHALLENGE_MENU})
	_pending = {
		"type": &"menu",
		"command": &"challenge_menu",
		"options": rows,
		## `MenuHeader_ChallengeExplanationCancel`: `menu_coords 0, 0, 14, 7`,
		## `db 1` for the row the cursor opens on, and its own two menu flags.
		"header": {
			"default": 1,
			"data_flags": Gen2MenuBox.STATICMENU_CURSOR | Gen2WorldMenu.STATICMENU_WRAP,
			"left": 0, "top": 0, "right": 14, "bottom": 7,
		},
		## `Script_Menu_ChallengeExplanationCancel` writes its question and then
		## opens the menu over it, so the box already on screen is the prompt.
		"text": _standing_text,
		"special": &"battle_tower_challenge_menu",
		"source": _request.duplicate(true),
	}
	return _waiting_result()


## `BattleTowerRoomMenu_PlacePickLevelMenu`: four rooms before the Hall of Fame
## and all ten after it, CANCEL behind either.
func _stage_room_menu() -> Dictionary:
	var rows: Array = (_battle_tower_data().get("level_rows", []) as Array).duplicate()
	if rows.size() != RomLayout.BATTLETOWER_LEVEL_ROWS:
		return _fail(&"missing_battle_tower_menu", {"special": SPECIAL_BATTLE_TOWER_ROOM_MENU})
	var groups: int = RomLayout.BATTLETOWER_LEVEL_GROUPS if _hall_of_fame_entered() \
		else Gen2BattleTower.PRE_HALL_OF_FAME_GROUPS
	var options: Array = rows.slice(0, groups)
	options.append(rows[RomLayout.BATTLETOWER_LEVEL_GROUPS])
	_pending = {
		"type": &"menu",
		"command": &"battle_tower_room",
		"options": options,
		## `BattleTowerRoomMenu_PlacePickLevelMenu` draws one room at a time
		## between two arrows rather than a list under a cursor, so this menu is
		## its own kind. `MenuHeader_119cf7` carries `menu_coords 12, 7,
		## SCREEN_WIDTH - 1, TEXTBOX_Y - 1` and `db 0` for its flags: no cursor
		## and no title, which puts the room name at `hlcoord 13, 9` where
		## `BattleTowerRoomMenu_UpdatePickLevelMenu` places it.
		"menu_kind": &"room",
		"header": {
			"default": 1,
			"data_flags": 0,
			"left": 12, "top": 7, "right": 19, "bottom": 11,
		},
		"text": String((_battle_tower_data().get("menu_text", {}) as Dictionary).get(
			"what_level", ""
		)),
		"special": &"battle_tower_room_menu",
		"groups": groups,
		"source": _request.duplicate(true),
	}
	return _waiting_result()


func _hall_of_fame_entered() -> bool:
	return state != null and state.hall_of_fame()


## One of the room menu's two refusals, printed and then followed by the menu
## again: `BattleTowerRoomMenu_DelayRestartMenu` puts the jumptable back at zero
## rather than leaving the routine.
func _stage_room_menu_refusal(name: String, buffer_name: String = "") -> Dictionary:
	var text: String = String(
		(_battle_tower_data().get("menu_text", {}) as Dictionary).get(name, "")
	)
	if text.is_empty():
		return _fail(
			&"missing_special_text", {"special": SPECIAL_BATTLE_TOWER_ROOM_MENU}
		)
	if not buffer_name.is_empty():
		## `Text_UberRestriction` is `text_ram wcd49`, which
		## `BattleTower_UbersCheck` fills with the offending member's name.
		text = Gen2TextStream.fill_all_markers(
			text, "%s%04X>" % [Gen2TextStream.RAM_MARKER, BATTLE_TOWER_NAME_BUFFER],
			buffer_name
		)
	return _stage_internal_text(text, false, {
		"special": &"battle_tower_room_refusal",
	})


## `LoadOpponentTrainerAndPokemonWithOTSprite`. The sampled trainer and team go
## into the runner's own `wBT_OTTrainer`, and the sprite the class carries is
## given to the map object `wScriptVar` names, which the battle room's own
## `setval BATTLETOWERBATTLEROOM_YOUNGSTER` chose.
func _load_battle_tower_opponent() -> Dictionary:
	var opponent: Dictionary = _battle_tower().load_opponent(data, _battle_tower_random(1))
	if opponent.is_empty():
		return _fail(
			&"missing_battle_tower_data", {"special": SPECIAL_LOAD_BATTLE_TOWER_OPPONENT}
		)
	var mons: Array = []
	for mon: Gen2SaveMon in opponent["mons"] as Array:
		mons.append(mon.to_dict())
	_battle_tower_opponent = {
		"trainer": int(opponent["trainer"]),
		"name": String(opponent["name"]),
		"class": int(opponent["class"]),
		"mons": mons,
	}
	_events.append({
		"type": &"battle_tower_opponent_loaded",
		"object": _script_value,
		"sprite": Gen2BattleTower.class_sprite(data, int(opponent["class"])),
		"trainer": int(opponent["trainer"]),
		"trainer_class": int(opponent["class"]),
		"name": String(opponent["name"]),
	})
	return {"ok": true}


## `BattleTowerBattle`, which is `RunBattleTowerTrainer` around one
## `predef StartBattle`: the party is healed on the way in and on the way out,
## SET MODE is forced for the fight, and `wBattleResult` is what the room script
## reads afterwards.
func _stage_battle_tower_battle() -> Dictionary:
	if _battle_tower_opponent.is_empty():
		return _fail(
			&"missing_battle_tower_opponent", {"special": SPECIAL_BATTLE_TOWER_BATTLE}
		)
	## `CopyBTTrainer_FromBT_OT_TowBT_OTTemp` runs in front of the battle, so the
	## challenge is in progress and the trainer counted before a blow is struck.
	var tower: Gen2BattleTower = _battle_tower()
	tower.challenge_state = Gen2BattleTower.CHALLENGE_IN_PROGRESS
	tower.beaten = mini(tower.beaten + 1, Gen2BattleTower.STREAK_LENGTH)
	return _stage_runtime_request(&"battle_requested", {
		"kind": &"battle_tower",
		"special": SPECIAL_BATTLE_TOWER_BATTLE,
		## `set BATTLE_SHIFT, [hl]` for the length of the fight and
		## `farcall HealParty` on both sides of it.
		"force_switch_mode": true,
		"heal_party": true,
		"trainer_class": int(_battle_tower_opponent["class"]),
		"trainer_name": String(_battle_tower_opponent["name"]),
		"enemy_party": (_battle_tower_opponent["mons"] as Array).duplicate(true),
	})


## `battletowertext`, which is `BattleTowerText` for the opponent's own class:
## the greeting rolls a personality and the win and loss lines read the same one
## back, so all three come from one trainer rather than three.
func _stage_battle_tower_text(kind: int) -> Dictionary:
	if _battle_tower_opponent.is_empty():
		return _fail(&"missing_battle_tower_opponent", {"kind": kind})
	var line: Dictionary = _battle_tower().trainer_line(
		data, int(_battle_tower_opponent["class"]), clampi(kind - 1, 0, 2),
		_battle_tower_random(1 + kind), _battle_tower_text_index
	)
	_battle_tower_text_index = int(line["index"])
	var text: String = String(line["text"])
	if text.is_empty():
		return _fail(&"missing_battle_tower_text", {"kind": kind})
	return _stage_internal_text(text, false)


func _pending_tag() -> StringName:
	var tag: Variant = _pending.get("special", &"")
	return tag if tag is StringName else &""


## `wMomSavingMoney` as the routine reads it: staged first, then the save.
func _mom_savings_flags() -> int:
	if _staged_mom_savings_flags >= 0:
		return _staged_mom_savings_flags
	return state.mom_savings_flags() if state != null else 0


## `RestartLuckyNumberCountdown.GetDaysUntilNextFriday`, which answers seven on
## a Friday or a Saturday rather than nought or a negative.
## One of the WRAM buffers `RomLayout`'s `special_text_ram` names, by that name
## rather than by its address: Gold and Crystal put the same buffer in different
## places, and a cartridge that ships no such buffer takes no write.
func _set_text_ram(name: String, value: String) -> void:
	if data == null:
		return
	var address: int = data.special_text_ram(name)
	if address >= 0:
		_text_ram[address] = value


func _lucky_number_days_until_friday() -> int:
	var until: int = Gen2WorldClock.FRIDAY - posmod(
		_clock_day(), Gen2WorldClock.DAYS_PER_WEEK
	)
	return until + Gen2WorldClock.DAYS_PER_WEEK if until <= 0 else until


## `LoadOrRegenerateLuckyIDNumber`, staged. `sLuckyNumberDay` holds the day plus
## one, so a stored zero is "never drawn"; a day whose stamp already matches
## keeps its number and spends no roll.
func _refresh_lucky_id_number() -> void:
	if _has_staged_lucky_id_number:
		return
	var stamp: int = (_clock_day() + 1) & 0xFF
	if state != null and state.lucky_number_day() == stamp:
		return
	var low: int = _random.randi() & 0xFF
	var high: int = _random.randi() & 0xFF
	_staged_lucky_id_number = ((high << 8) | low) & 0xFFFF
	_staged_lucky_number_day = stamp
	_has_staged_lucky_id_number = true


func _lucky_id_number() -> int:
	if _has_staged_lucky_id_number:
		return _staged_lucky_id_number
	return state.lucky_id_number() if state != null else 0


## `wBuenasPassword`: the high nibble is the category the radio show drew this
## morning and the low nibble is today's word inside it.
func _buenas_password() -> int:
	return state.buenas_password() if state != null else -1


## `BuenasPassword`'s own menu: the five words of today's category in a box ten
## wide, with B disabled, so a player who has tuned in picks one of them and a
## player who has not is looking at the same five.
func _stage_buenas_password_menu(password: int) -> void:
	var words: Array[String] = Gen2RadioShow.buenas_password_words(data, password)
	_pending = {
		"type": &"menu",
		"command": &"buenas_password",
		"options": words,
		## `STATICMENU_CURSOR | STATICMENU_DISABLE_B`, and `db 1` for the row the
		## cursor opens on.
		"header": {"default": 1, "data_flags": 0},
		"disable_b": true,
		"text": _standing_text,
		"special": &"buenas_password",
		"password": password,
		"source": _request.duplicate(true),
	}


func _stage_day_of_week_menu() -> void:
	_pending = {
		"type": &"menu",
		## `SetDayOfWeek` is a dial, not a list: one weekday in a nine-wide box at
		## `hlcoord 9, 3` between two arrows, with `.GetJoypadAction` stepping
		## `wTempDayOfWeek` and A accepting. The selection rules are a wrapping
		## vertical menu's, so only the drawing differs from one.
		"menu_kind": &"spinner",
		"command": &"set_day_of_week",
		"options": WEEKDAY_NAMES.duplicate(),
		"header": {"default": 1, "data_flags": 1 << 5},
		"text": _standing_text,
		"special": &"set_day_of_week",
		"source": _request.duplicate(true),
	}


func _stage_day_of_week_confirmation(day: int) -> void:
	_pending = {
		"type": &"choice",
		"command": &"set_day_of_week_confirmation",
		"choices": [&"yes", &"no"],
		"text": _standing_text,
		"special": &"set_day_of_week_confirmation",
		"day": posmod(day, WEEKDAY_NAMES.size()),
		"source": _request.duplicate(true),
	}


func _stage_dst_confirmation_text(enabled: bool) -> void:
	var clock: Dictionary = _request.get("clock", {})
	var hour: int = clampi(int(clock.get("hour", 0)), 0, 23)
	var minute: int = clampi(int(clock.get("minute", 0)), 0, 59)
	var time_text: String = "%02d:%02d" % [hour, minute]
	_pending = {
		"type": &"text",
		"text": "%s%s,\nis that OK?" % [time_text, " DST" if enabled else ""],
		"special": &"initial_dst_confirmation",
		"source": _request.duplicate(true),
	}


func _phone_contact() -> Dictionary:
	if data == null:
		return {}
	var contact_id: int = int(_phone_context.get(
		"caller_id", _phone_context.get("contact_id", -1)
	))
	return data.world_phone_contact(contact_id)


## `LookUpWildmonsForMapDE` over the Johto grass table and then the Kanto one,
## as `[morning_row, current_time_row]`. Empty when neither names the caller.
func _phone_grass_rows() -> Array:
	var contact: Dictionary = _phone_contact()
	var record: Dictionary = data.world_encounter(
		Gen2WorldEncounter.METHOD_GRASS,
		int(contact.get("map_group", -1)), int(contact.get("map_number", -1))
	) if data != null else {}
	var slots: Variant = record.get("slots", [])
	if not slots is Array:
		return []
	var hour: int = int((_request.get("clock", {}) as Dictionary).get("hour", 0))
	var time_of_day: int = Gen2WorldClock.new(hour).time_of_day()
	if time_of_day < 0 or time_of_day >= (slots as Array).size():
		return []
	var rows: Array = [(slots as Array)[0], (slots as Array)[time_of_day]]
	for row: Variant in rows:
		if not row is Array or (row as Array).size() < RomLayout.WILD_GRASS_SLOT_COUNT:
			return []
	return rows


## `RandomPhoneWildMon`, which masks its roll to one of the first four grass
## slots rather than taking the weighted encounter draw.
func _phone_wild_mon_name() -> String:
	var rows: Array = _phone_grass_rows()
	if rows.is_empty():
		return ""
	var slot: Variant = (rows[1] as Array)[_random.randi_range(0, 3)]
	if not slot is Dictionary:
		return ""
	var species: int = int((slot as Dictionary).get("species", 0))
	if species <= 0 or data.species(species).is_empty():
		return ""
	return String(data.species(species).get("name", ""))


## `RandomUnseenWildMon`: one of the three rarest slots at the current time of
## day, refused when it is common or already seen. `.GetGrassmon` takes that slot
## from the time-of-day row and `pop hl` then restores the pointer from before
## the offset, so the four commons weighed against it are always the morning
## ones. That half is what `docs/bugs_and_glitches.md`'s fix closes.
func _phone_unseen_rare_species() -> int:
	var rows: Array = _phone_grass_rows()
	if rows.is_empty():
		return 0
	var common: Array[int] = []
	for index: int in 4:
		var entry: Variant = (rows[0] as Array)[index]
		if entry is Dictionary:
			common.append(int((entry as Dictionary).get("species", 0)))
	var species: int = _phone_rare_slot_species(rows[1] as Array)
	if species <= 0 or common.has(species) or data.species(species).is_empty() \
		or (state != null and state.has_seen_species(species)):
		return 0
	return species


## `.randloop1`, a two-bit draw rerolled until it is not zero.
func _phone_rare_slot_species(row: Array) -> int:
	for _attempt: int in PHONE_RARE_ROLL_ATTEMPTS:
		var roll: int = _random.randi() & 0x03
		if roll == 0:
			continue
		var rare: Variant = row[4 + roll - 1]
		return int((rare as Dictionary).get("species", 0)) if rare is Dictionary else 0
	return 0


func _phone_trainer_mon_name() -> String:
	var contact: Dictionary = _phone_contact()
	var trainer_group: int = int(contact.get("trainer_class", 0))
	var trainer_id: int = int(contact.get("trainer_number", 0)) - 1
	var party: Array = data.trainer_party(trainer_group, trainer_id).get("party", []) if data != null else []
	var candidates: Array[int] = []
	for mon: Dictionary in party:
		var party_species: int = int(mon.get("species", 0))
		if party_species > 0 and data.species(party_species).size() > 0:
			candidates.append(party_species)
	if candidates.is_empty():
		return ""
	var species: int = candidates[_random.randi_range(0, candidates.size() - 1)]
	return String(data.species(species).get("name", ""))


func _stage_warp_facing_request(command: Dictionary) -> Dictionary:
	var warp: Dictionary = {
		"facing": int(command.get("facing", Gen2WorldSprite.FACING_DOWN)),
		"map_group": int(command.get("map_group", 0)),
		"map_number": int(command.get("map_number", 0)),
		"x": int(command.get("x", 0)), "y": int(command.get("y", 0)),
	}
	_events.append({"type": &"player_facing_requested", "facing": warp["facing"]})
	return _stage_warp(command)


## `wRunningTrainerBattleScript` as this script sees it: a value staged during
## the run wins over the committed one, since a script that stages false has
## cleared the flag for everything after it. Reading only the "has a staged
## value" side made `endifjustbattled` true whenever anything had touched it.
func _just_battled() -> bool:
	if _has_staged_just_battled:
		return _staged_just_battled
	return state != null and state.just_battled()


## `disappear` and `appear` set and clear the object's own event flag where the
## source does, so a `checkevent` later in the same script reads it back.
## TeamRocketBaseB2F's third Electrode checks all three straight after
## disappearing its own, and read the committed value without this.
func _stage_object_event_flag(object_id: int, active: bool) -> void:
	var index: int = _object_index_from_id(object_id)
	var flags: Array = _request.get("object_event_flags", [])
	if index < 0 or index >= flags.size():
		return
	var flag: int = int(flags[index])
	if flag > 0:
		_staged_flags[flag] = active


func _stage_just_battled(value: bool) -> void:
	_staged_just_battled = value
	_has_staged_just_battled = true


## The byte a script memory address holds, staged writes first. Reading an
## address never written answers zero, the way cleared WRAM does.
func _script_memory_value(address: int) -> int:
	if _staged_script_memory.has(address):
		return int(_staged_script_memory[address])
	return state.script_memory(address) if state != null else 0


func _stage_script_memory(address: int, value: int) -> Dictionary:
	if address <= 0:
		return {"ok": false, "reason": &"invalid_script_memory_address", "address": address}
	_staged_script_memory[address] = value & 0xFF
	_emit_runtime_event(&"script_memory_changed", {
		"address": address, "value": value & 0xFF,
	})
	return {"ok": true}


func _item_quantity(item: int) -> int:
	if _staged_items.has(item):
		return int(_staged_items[item])
	return state.item_quantity(item) if state != null else 0


func _money_balance(account: int) -> int:
	if _staged_money.has(account):
		return int(_staged_money[account])
	return state.money(account) if state != null else 0


func _coins_value() -> int:
	if _staged_coins >= 0:
		return _staged_coins
	return state.coins() if state != null else 0


## `CompareBytes`' three answers: 0 short, 1 exact, 2 over.
func _compare_amount(current: int, requested: int) -> int:
	if current < requested:
		return 0
	return 1 if current == requested else 2


func _decode_bcd(bytes: PackedByteArray) -> int:
	var value: int = 0
	for byte: int in bytes:
		value = value * 100 + ((byte >> 4) * 10) + (byte & 0x0F)
	return value


## `engine/events/haircut.asm` past its `farcall SelectMonFromParty`. The carry
## the party list answers a B press or its CANCEL row with is `.nope`/`.cancel`,
## `xor a` in all four; an EGG is `.egg`'s own 1, tested by the three grooming
## routines alone, since `BillsGrandfather` answers EGG as a species like any
## other. `GetCurNickname` names the member for the three and `GetPokemonName`
## the species for the fourth, both into wStringBuffer3.
func _finish_party_selection(request: Dictionary, result: Dictionary) -> Dictionary:
	var values: Dictionary = request.get("values", {})
	var special: int = int(values.get("special", 0))
	var routine: StringName = StringName(values.get("routine", &""))
	if routine == &"npc_trade":
		_pending = {}
		return _finish_trade_selection(values.get("trade", {}), result)
	var party_index: int = int(result.get("party_index", -1))
	if party_index < 0:
		## `SelectMonFromParty`'s carry. Three of the six routines answer
		## something other than zero for it, so the refusal is theirs to name.
		_script_value = int(PARTY_SELECTION_REFUSAL_OF.get(routine, 0))
		_pending = {}
		return advance()
	var species: int = int(result.get("species", 0))
	_cur_party_species = species
	if routine == &"bills_grandfather":
		_script_value = species
		_set_text_buffer(3, String(result.get("species_name", "")), &"chosen_party_mon", {
			"special": special, "slot": party_index,
		})
		_pending = {}
		return advance()
	if routine in [
		&"magikarp_length", &"photo_studio", &"return_shuckie", &"poke_seer",
		&"check_poke_mail",
	]:
		_pending = {}
		return _finish_deferred_party_selection(routine, special, result, values)
	if species == SPECIES_EGG:
		_script_value = 1
		_pending = {}
		return advance()
	_set_text_buffer(3, String(result.get("nickname", "")), &"chosen_party_mon", {
		"special": special, "slot": party_index,
	})
	## `call Random` sits behind the name copy, so the roll is spent whether or
	## not the row it picks changes anything.
	var outcome: Dictionary = Gen2WorldPartyHost.groom_outcome(
		routine, _random.randi() & 0xFF, _crystal_commands()
	)
	_script_value = int(outcome["script_value"])
	_emit_runtime_event(&"party_happiness_changed", {
		"special": special,
		"slot": party_index,
		"happiness_kind": int(outcome["happiness_kind"]),
	})
	_pending = {}
	return advance()


## The four routines whose whole body is `SelectMonFromParty` and a branch on
## the row it answered with. Each writes wScriptVar, and two of them write
## something else besides.
func _finish_deferred_party_selection(
	routine: StringName, special: int, result: Dictionary, values: Dictionary = {}
) -> Dictionary:
	var species: int = int(result.get("species", 0))
	match routine:
		&"photo_studio":
			## `IsAPokemon` is the egg test and nothing else here can fail it, so
			## the two branches are the egg's line and the shoot.
			var photo_box: String = _special_box(
				"photo_studio", "egg" if species == SPECIES_EGG else "hold_still"
			)
			if photo_box.is_empty():
				return {"ok": false, "reason": &"missing_special_text", "special": special}
			if species == SPECIES_EGG:
				return _stage_internal_text(photo_box, false, {"special": special})
			## `PrintPartymon` is a Game Boy Printer transfer, and `hPrinter`
			## reports an error for every attempt made without one attached, so
			## `.cancel` is the branch this project can reach and the picture is
			## never taken.
			return _stage_internal_text(photo_box, false, {
				"special": special,
				"next_internal_texts": [_special_box("photo_studio", "no_photo")],
			})
		&"magikarp_length":
			if species != Gen2WorldPartyHost.SPECIES_MAGIKARP:
				_script_value = Gen2WorldPartyHost.MAGIKARPLENGTH_NOT_MAGIKARP
				return advance()
			var length: Vector2i = Gen2WorldPartyHost.magikarp_length(
				_dv_bytes(result.get("dvs", [])), int(result.get("ot_id", 0))
			)
			_set_text_buffer(
				RomLayout.STRING_BUFFER_1,
				Gen2WorldPartyHost.magikarp_length_string(length.x, length.y),
				&"magikarp_length", {"special": special}
			)
			var record: Dictionary = state.best_magikarp() if state != null else {}
			## `PrintText` runs in front of the comparison, so the Guru says the
			## measurement whether or not it beats what he has written down.
			var beats: bool = Gen2WorldPartyHost.magikarp_beats_record(length, record)
			_script_value = Gen2WorldPartyHost.MAGIKARPLENGTH_BEAT_RECORD if beats \
				else Gen2WorldPartyHost.MAGIKARPLENGTH_TOO_SHORT
			if beats:
				## The two bytes and then `SkipNames`' own eleven, which is the
				## OT of the row that was measured rather than the player.
				_staged_best_magikarp = {
					"feet": length.x,
					"inches": length.y,
					"ot": String(result.get("original_trainer", "")),
				}
			var measure_box: String = _special_box("magikarp", "measure")
			if measure_box.is_empty():
				return {"ok": false, "reason": &"missing_special_text", "special": special}
			return _stage_internal_text(measure_box, false, {"special": special})
		&"poke_seer":
			return _finish_poke_seer(special, result)
		&"check_poke_mail":
			return _finish_check_poke_mail(result, values)
		&"return_shuckie":
			## Three tests in order and each has its own answer: the species, then
			## MANIA's ID, then MANIA's OT name. A row that fails any of them is
			## SHUCKIE_WRONG_MON, which is the same zero a stranger's SHUCKLE
			## gets.
			if species != Gen2WorldPartyHost.SHUCKLE \
				or int(result.get("ot_id", -1)) != Gen2WorldPartyHost.MANIA_OT_ID \
				or String(result.get("original_trainer", "")) != Gen2WorldPartyHost.MANIA_OT_NAME:
				_script_value = Gen2WorldPartyHost.SHUCKIE_WRONG_MON
				return advance()
			if bool(result.get("fainted", false)):
				_script_value = Gen2WorldPartyHost.SHUCKIE_FAINTED
				return advance()
			if int(result.get("happiness", 0)) >= Gen2WorldPartyHost.SHUCKIE_HAPPY_THRESHOLD:
				## `.HappyToStayWithYou` writes the answer and removes nothing.
				_script_value = Gen2WorldPartyHost.SHUCKIE_HAPPY
				return advance()
			_script_value = Gen2WorldPartyHost.SHUCKIE_RETURNED
			_emit_runtime_event(&"party_member_removed", {
				"special": special,
				"slot": int(result.get("party_index", -1)),
				"routine": routine,
			})
			return advance()
	return advance()


## `Script_givepokemail`, which copies the pointer's `db item` and the
## `MAIL_MSG_LENGTH` bytes behind it into `wMonMailMessageBuffer`, and
## `GivePokeMail`, which hangs both on the last party member. Nothing is asked and
## nothing is answered: the routine writes no wScriptVar and cannot fail, so the
## write is an event the way a happiness change is. The mail's author, ID and
## species are the member's own, so the screen reads the first two off the row it
## is writing and the runner carries the third.
func _give_poke_mail(command: Dictionary) -> Dictionary:
	var bytes: PackedByteArray = _mail_bytes(int(command.get("address", 0)))
	if bytes.size() < Gen2SaveMail.MESSAGE_LENGTH + 1:
		return {"ok": false, "reason": &"missing_mail_data", "command": command}
	var party: Dictionary = _request.get("party", {})
	if party.is_empty():
		return {"ok": false, "reason": &"missing_party_summary", "command": command}
	var count: int = int(party.get("count", 0))
	if count <= 0:
		return {"ok": false, "reason": &"empty_party", "command": command}
	_emit_runtime_event(&"party_mail_given", {
		"slot": count - 1,
		"item": int(bytes[0]),
		"message": Array(bytes.slice(1, Gen2SaveMail.MESSAGE_LENGTH + 1)),
		"species": _cur_party_species,
	})
	return {"ok": true}


## `Script_checkpokemail`, whose whole body is `CheckPokeMail`: the party list,
## then the held item, then the message byte for byte. The list is the same
## staged selection the Seer and the haircut open.
func _check_poke_mail(command: Dictionary) -> Dictionary:
	var bytes: PackedByteArray = _mail_bytes(int(command.get("address", 0)))
	if bytes.is_empty():
		return {"ok": false, "reason": &"missing_mail_data", "command": command}
	return _stage_runtime_request(&"party_selection_requested", {
		"routine": &"check_poke_mail",
		"expected": Array(bytes),
	})


## The bytes a `givepokemail` or `checkpokemail` points at, in the running
## script's own bank (`wScriptBank`). Both sit behind the script that names
## them rather than at a pointer key of their own, which is what
## [method GameData.world_script_at] reaches.
func _mail_bytes(address: int) -> PackedByteArray:
	if data == null:
		return PackedByteArray()
	return data.world_script_at(int(_request.get("bank", 0)), address)


## `CheckPokeMail` past its `farcall SelectMonFromParty`: the four refusals in
## the order the routine tests them, and the removal the fifth answer pays for.
func _finish_check_poke_mail(result: Dictionary, values: Dictionary) -> Dictionary:
	var slot: int = int(result.get("party_index", -1))
	if not Gen2HeldItem.is_mail(int(result.get("item", 0))):
		## `ItemIsMail` on MON_ITEM, which an egg and an empty hand both fail.
		_script_value = Gen2WorldPartyHost.POKEMAIL_NO_MAIL
		return advance()
	var expected: PackedByteArray = _byte_array(values.get("expected", []))
	var carried: PackedByteArray = _byte_array(result.get("mail_message", []))
	if not _mail_message_matches(expected, carried):
		_script_value = Gen2WorldPartyHost.POKEMAIL_WRONG_MAIL
		return advance()
	## `CheckCurPartyMonFainted`: carry when every other slot is fainted, so
	## handing this one over would black the player out. An egg is HP 0 and
	## counts as fainted here, which is the routine reading `wPartyMon1HP` and
	## nothing else.
	var fainted: Array = result.get("party_fainted", [])
	var healthy_elsewhere: bool = false
	for index: int in fainted.size():
		if index != slot and not bool(fainted[index]):
			healthy_elsewhere = true
			break
	if not healthy_elsewhere:
		_script_value = Gen2WorldPartyHost.POKEMAIL_LAST_MON
		return advance()
	_script_value = Gen2WorldPartyHost.POKEMAIL_CORRECT
	_emit_runtime_event(&"party_member_removed", {
		"slot": slot,
		"routine": &"check_poke_mail",
	})
	return advance()


## The compare loop's own two exits: the expected message's `'@'` ends it as a
## match, and any other difference inside `MAIL_MSG_LENGTH` bytes does not.
func _mail_message_matches(expected: PackedByteArray, carried: PackedByteArray) -> bool:
	for index: int in Gen2SaveMail.MESSAGE_LENGTH:
		var wanted: int = expected[index] if index < expected.size() else Gen2Text.TERMINATOR
		if wanted == Gen2Text.TERMINATOR:
			return true
		if index >= carried.size() or carried[index] != wanted:
			return false
	return true


func _byte_array(raw: Variant) -> PackedByteArray:
	var out := PackedByteArray()
	if raw is PackedByteArray:
		return raw as PackedByteArray
	if raw is Array:
		for value: Variant in raw as Array:
			out.append(int(value) & 0xFF)
	return out


## `ReadCaughtData` and `SeerAction`, which are one reading of the row and then
## the boxes that reading picked.
##
## Nothing here writes anything: every branch is a run of `PrintText`s and the
## five buffers they read, so the whole routine is text.
func _finish_poke_seer(special: int, result: Dictionary) -> Dictionary:
	if int(result.get("species", 0)) == SPECIES_EGG:
		return _seer_boxes(special, ["egg"])
	var caught_level: int = int(result.get("caught_level", 0))
	var caught_time: int = int(result.get("caught_time", 0))
	var caught_location: int = int(result.get("caught_location", 0))
	var caught_gender: int = int(result.get("caught_gender", 0))
	## `.error`: both caught bytes zero. The level and time share one byte and
	## the gender and location the other, so a row that has never been stamped
	## is the one the Seer cannot read.
	if caught_level == 0 and caught_time == 0 \
		and caught_location == 0 and caught_gender == 0:
		return _seer_boxes(special, ["cant_tell_a_thing"])
	_set_text_ram("seer_nickname", String(result.get("nickname", "")))
	_set_text_ram("seer_ot", String(result.get("original_trainer", "")))
	## The level the Seer says, which is `CAUGHT_EGG_LEVEL` read back as the
	## level an egg hatches at and "???" for a row with no level at all.
	_set_text_ram("seer_caught_level", "???" if caught_level == 0 else str(
		SEER_EGG_LEVEL if caught_level == SEER_CAUGHT_EGG_LEVEL else caught_level
	))
	_set_text_ram("seer_time_of_day", SEER_UNKNOWN if caught_time == 0 \
		else SEER_TIMES[mini(caught_time - 1, SEER_TIMES.size() - 1)])
	## `GetCaughtLocation` is the one reading that can change the action: an
	## event landmark leaves only the level tellable and a gift leaves nothing.
	var traded: bool = _seer_was_traded(result)
	var boxes: PackedStringArray = PackedStringArray()
	if caught_location == 0:
		_set_text_ram("seer_caught_location", SEER_UNKNOWN)
		boxes = PackedStringArray(["trade" if traded else "name_location", "time_level"])
	elif caught_location == SEER_LANDMARK_EVENT:
		boxes = PackedStringArray(["no_location"])
	elif caught_location == Gen2WorldPartyHost.LANDMARK_GIFT:
		return _seer_boxes(special, ["cant_tell_a_thing"])
	else:
		_set_text_ram("seer_caught_location", data.landmark_name(caught_location) \
			if data != null else SEER_UNKNOWN)
		boxes = PackedStringArray(["trade" if traded else "name_location", "time_level"])
	## `SeerAdvice`, which every telling branch ends on: the levels gained since
	## the row was caught, banded by `SeerAdviceTexts`' own thresholds.
	var gained: int = (int(result.get("level", 0)) - caught_level) & 0xFF
	for row: Array in SEER_ADVICE:
		if gained <= int(row[0]):
			boxes.append(String(row[1]))
			break
	return _seer_boxes(special, boxes)


## `ReadCaughtData`'s trade test. wPlayerID is stored high byte first, and the
## `cp [hl]` behind `ld a, [wPlayerID + 1]` is commented out in the pin: the low
## byte is loaded and never compared, and `ld a, [hl]` sets no flags, so the
## `jr nz` after it reads the high byte's own comparison a second time. A row
## whose high ID byte matches the player's is "met" whatever its low byte says.
func _seer_was_traded(result: Dictionary) -> bool:
	var player_id: int = int(_request.get("player_id", 0))
	return ((int(result.get("ot_id", 0)) >> 8) & 0xFF) != ((player_id >> 8) & 0xFF)


func _seer_boxes(special: int, names: Array) -> Dictionary:
	var texts: Array = []
	for name: Variant in names:
		var box: String = _special_box("poke_seer", String(name))
		if box.is_empty():
			return {"ok": false, "reason": &"missing_special_text", "special": special}
		texts.append(box)
	var head: String = String(texts.pop_front())
	return _stage_internal_text(head, false, {"special": special} if texts.is_empty() \
		else {"special": special, "next_internal_texts": texts})


## MON_DVS' two bytes off a party-selection answer, whatever shape the host
## handed them over in.
func _dv_bytes(raw: Variant) -> PackedByteArray:
	var out := PackedByteArray([0, 0])
	if raw is PackedByteArray:
		var packed: PackedByteArray = raw
		for index: int in mini(packed.size(), 2):
			out[index] = packed[index]
	elif raw is Array:
		var values: Array = raw
		for index: int in mini(values.size(), 2):
			out[index] = int(values[index]) & 0xFF
	return out


func _emit_runtime_event(kind: StringName, values: Dictionary) -> void:
	var event: Dictionary = {
		"type": kind,
		"map_group": int(_request.get("map_group", 0)),
		"map_number": int(_request.get("map_number", 0)),
	}
	for key: Variant in values:
		event[key] = values[key]
	_events.append(event)


func _object_index_from_id(object_id: int) -> int:
	if object_id in [0xFE, 0xFF]:
		return _last_talked_object_index
	if object_id == PLAYER_OBJECT_ID:
		return Gen2WorldObject.PLAYER_INDEX
	if object_id < FIRST_MAP_OBJECT_ID:
		return Gen2WorldObject.NONE_INDEX
	# object_const_def starts map-object constants at 2. The cache omits the
	# player object, so source id 2 is array index zero.
	return object_id - FIRST_MAP_OBJECT_ID


func _emit_object_event(event_type: StringName, values: Dictionary) -> void:
	var event: Dictionary = {
		"type": event_type,
		"map_group": int(_request.get("map_group", 0)),
		"map_number": int(_request.get("map_number", 0)),
	}
	for key: Variant in values:
		event[key] = values[key]
	_events.append(event)


## engine/events/overworld.asm's AskStrengthScript, synthesized. StrengthBoulderScript
## is `farsjump AskStrengthScript`, whose first command is `callasm TryStrengthOW`;
## `callasm` has no runner here and its operand is a link-time address absent from
## the pinned disassemblies, so the seam sits on the standard-script index instead,
## which is 14 in both pins and verified by the imported table. The synthesized
## body is the same shape trainer object dispatch takes. Every branch of
## AskStrengthScript terminates, so this never returns to a caller.
func _stage_strength_boulder() -> Dictionary:
	var party: Dictionary = _request.get("party", {})
	if party.is_empty():
		return {"ok": false, "reason": &"missing_party_summary", "standard_index": STD_STRENGTH_BOULDER}
	var source: Dictionary = _field_move_source(Gen2WorldFieldMove.MOVE_STRENGTH)
	var slot: int = int(source.get("slot", -1))
	var has_badge: bool = _engine_flag_active(
		Gen2WorldState.badge_flag(Gen2WorldFieldMove.BADGE_PLAIN, _crystal_commands())
	)
	if source.is_empty() or not has_badge:
		_script_value = STRENGTH_OW_UNABLE
		return _stage_internal_text(STRENGTH_MAY_MOVE_TEXT, true)
	if _engine_flag_active(Gen2WorldState.strength_active_flag(_crystal_commands())):
		_script_value = STRENGTH_OW_ALREADY_ACTIVE
		return _stage_internal_text(STRENGTH_BOULDERS_MOVE_TEXT, true)
	_script_value = STRENGTH_OW_ASK
	_pending = {
		"type": &"text",
		"text": STRENGTH_ASK_TEXT,
		"internal_text": true,
		"special": &"strength_ask",
		"slot": slot,
		"source": _request.duplicate(true),
	}
	_finish_after_pending = false
	return {"ok": true}


## engine/events/misc_scripts.asm's FindItemInBallScript, synthesized. An item
## ball's script pointer is not code but the `itemball` macro's
## `db item, quantity`, copied into wItemBallData before PLAYEREVENT_ITEMBALL is
## raised, so the seam is the object type rather than a script address. Source
## order is receive, `disappear LAST_TALKED`, then the text, so the ball is gone
## when the box is drawn; its `pause 60` is the acknowledge here. The receive
## seam preserves the no-room branch without committing anything.
func _stage_item_ball() -> Dictionary:
	var item: int = int(_request.get("item", 0))
	var quantity: int = maxi(1, int(_request.get("quantity", 1)))
	if item <= 0:
		return _fail(&"invalid_item_ball", {"item": item, "quantity": quantity})
	var received: Dictionary = _stage_item_delta(item, quantity)
	if not bool(received.get("accepted", true)):
		var no_space_name: String = data.item_name(item) if data != null else "ITEM"
		return _stage_internal_text(NO_SPACE_ITEM_TEXT % no_space_name, true)
	_emit_object_event(&"object_visibility", {
		"object_index": _last_talked_object_index, "active": false,
	})
	_emit_object_event(&"object_event_flag", {
		"object_index": _last_talked_object_index, "active": true,
	})
	_stage_object_event_flag(LAST_TALKED, true)
	var item_name: String = data.item_name(item) if data != null else ""
	if item_name.is_empty():
		item_name = "ITEM"
	return _stage_internal_text(FOUND_ITEM_TEXT % item_name, false, {
		"special": &"item_received", "item": item, "sfx": SFX_ITEM, "finish": true,
	})


## `FruitTreeScript` (`engine/events/fruit_trees.asm`). Like an item ball it is
## a script rather than a host request: `fruittree` is the whole of the object's
## own script, and the routine below it is text, a flag and a `giveitem`.
##
## The first pause is `FruitBearingTreeText`; `TryResetFruitTrees` and
## `CheckFruitTree` run on its acknowledge, since the source's own `callasm`s sit
## behind the `promptbutton`.
func _stage_fruit_tree(tree_id: int) -> Dictionary:
	if data == null:
		return _fail(&"missing_world_data", {"tree_id": tree_id})
	var item: int = data.world_fruit_tree_item(tree_id)
	if item <= 0:
		return _fail(&"invalid_fruit_tree", {"tree_id": tree_id, "item": item})
	_pending = {
		"type": &"text",
		"text": FRUIT_TREE_TEXT,
		"internal_text": true,
		"special": &"fruit_tree",
		"tree_id": tree_id,
		"item": item,
		"source": _request.duplicate(true),
	}
	return {"ok": true}


## The second half, run once the tree's own line has been acknowledged.
func _resolve_fruit_tree(tree_id: int, item: int) -> Dictionary:
	_stage_fruit_tree_reset()
	if _fruit_tree_picked(tree_id):
		return _stage_internal_text(FRUIT_TREE_EMPTY_TEXT, true)
	var item_name: String = data.item_name(item)
	if item_name.is_empty():
		item_name = "FRUIT"
	var received: Dictionary = _stage_item_delta(item, 1)
	if not bool(received.get("accepted", true)):
		return _stage_internal_text(FRUIT_TREE_FULL_TEXT % item_name, true)
	## PickedFruitTree, which the source runs after the item is in the bag, then
	## its own `specialsound` and `itemnotify`.
	_staged_fruit_trees[tree_id] = true
	return _stage_internal_text(
		FRUIT_TREE_OBTAINED_TEXT % [item_name, item_name], false,
		{"special": &"item_received", "item": item, "finish": true}
	)


## `TryResetFruitTrees`: `ResetFruitTrees` refills every tree at once and sets
## ENGINE_ALL_FRUIT_TREES behind itself, so it runs once per day, on whichever
## tree the player touches first after the daily reset cleared that flag.
func _stage_fruit_tree_reset() -> void:
	var all_trees: int = Gen2WorldState.engine_flag(
		Gen2WorldState.ENGINE_ALL_FRUIT_TREES, _crystal_commands()
	)
	if bool(_staged_engine_flags.get(all_trees, state.is_engine_flag_active(all_trees))):
		return
	for raw_tree: Variant in state.picked_fruit_trees():
		_staged_fruit_trees[int(raw_tree)] = false
	_staged_engine_flags[all_trees] = true


func _fruit_tree_picked(tree_id: int) -> bool:
	if _staged_fruit_trees.has(tree_id):
		return bool(_staged_fruit_trees[tree_id])
	return state.fruit_tree_picked(tree_id)


## HiddenItemScript, the BGEVENT_ITEM half of the same source area. The pointer
## is the `hiddenitem` macro's `dwb event, item`, handed over the way an item
## ball's two bytes are. It differs from [method _stage_item_ball] in the flag and
## the object: nothing is hidden, and the flag `callasm SetMemEvent` writes is the
## record's rather than the object's. `_PlayerFoundItemText` is `_FoundItemText`'s
## wording, so the two share a constant. The source writes the text before
## `giveitem` and sets the flag after it, so a full pocket changes neither.
func _stage_hidden_item() -> Dictionary:
	var item: int = int(_request.get("item", 0))
	var flag: int = int(_request.get("flag", -1))
	if item <= 0 or flag < 0:
		return _fail(&"invalid_hidden_item", {"item": item, "flag": flag})
	var received: Dictionary = _stage_item_delta(item, 1)
	if not bool(received.get("accepted", true)):
		var no_space_name: String = data.item_name(item) if data != null else "ITEM"
		return _stage_internal_text(NO_SPACE_ITEM_TEXT % no_space_name, true)
	_staged_flags[flag] = true
	var item_name: String = data.item_name(item) if data != null else ""
	if item_name.is_empty():
		item_name = "ITEM"
	return _stage_internal_text(FOUND_ITEM_TEXT % item_name, false, {
		"special": &"item_received", "item": item, "finish": true,
	})


## CheckPartyMove: the first slot whose move list carries [param move], or -1.
## The mirror's per-slot lists are the only party this scene-free runner reads.
## Eggs are skipped, the way the source's own `cp EGG` branch skips them.
func _party_slot_with_move(move: int) -> int:
	var party: Dictionary = _request.get("party", {})
	var moves: Array = party.get("moves", [])
	var eggs: Array = party.get("eggs", [])
	for slot: int in moves.size():
		if slot < eggs.size() and bool(eggs[slot]):
			continue
		if moves[slot] is Array and (moves[slot] as Array).has(move):
			return slot
	return -1


## The same question [method Gen2WorldAPI.field_move_source] answers, on the two
## facts a scene-free runner has: the party mirror, and the alternate sources the
## world resolved and handed over in `field_move_items`. Empty when neither
## supplies the move, which is what every gate here refuses on.
func _field_move_source(move: int) -> Dictionary:
	var slot: int = _party_slot_with_move(move)
	if slot >= 0:
		return {"slot": slot, "item": 0}
	var item: int = int((_request.get("field_move_items", {}) as Dictionary).get(move, 0))
	return {"slot": -1, "item": item} if item > 0 else {}


## `GetPartyNickname`, or the player's own name for a move used from an HM: no
## Pokemon took part, so the line the source names its user in says who did.
func _field_move_user_name(slot: int) -> String:
	if slot < 0:
		var player: String = String(_request.get("player_name", ""))
		return player if not player.is_empty() else "PLAYER"
	var names: Array = _request.get("party", {}).get("names", [])
	return String(names[slot]) if slot < names.size() else "#MON"


## SetStrengthFlag plus Script_UsedStrength. `_UseStrengthText` ends in `done`
## with no `waitbutton` behind it, so its box owes no press, and the `cry 0` is
## `wStrengthSpecies`. Only `pause 3` is dropped, six frames before the next box.
func _stage_strength_used(slot: int) -> Dictionary:
	_staged_engine_flags[Gen2WorldState.strength_active_flag(_crystal_commands())] = true
	var name: String = _field_move_user_name(slot)
	var species: Array = _request.get("party", {}).get("species", [])
	_pending = {
		"type": &"text",
		"text": Gen2WorldFieldMove.used_text(
			Gen2WorldFieldMove.MOVE_STRENGTH, name
		),
		"internal_text": true,
		"prompt": false,
		"cry": int(species[slot]) if slot >= 0 and slot < species.size() else 0,
		"special": &"strength_used",
		"name": name,
		"source": _request.duplicate(true),
	}
	_finish_after_pending = false
	return {"ok": true}


## engine/overworld/events.asm's TryTileCollisionEvent, from `.cut` on: the five
## field-move branches a faced tile can reach, each a `Try*OW` gate and then an
## `Ask*Script`. Synthesized for the reason AskStrengthScript is, and dispatched
## on the request kind rather than a standard-script index because these are
## reached through `CallScript`. Which move the tile offers is [Gen2WorldAPI]'s
## answer; what is left here is the party and the badge. TryHeadbuttOW and
## TrySurfOW have no refusal text: they return no carry and nothing is shown.
func _stage_field_move_prompt() -> Dictionary:
	var party: Dictionary = _request.get("party", {})
	if party.is_empty():
		return {"ok": false, "reason": &"missing_party_summary", "kind": &"field_move_prompt"}
	var move: int = int(_request.get("move", 0))
	var source: Dictionary = _field_move_source(move)
	var slot: int = int(source.get("slot", -1))
	var badge: int = _field_move_prompt_badge(move)
	var allowed: bool = not source.is_empty()
	if allowed and badge >= 0:
		allowed = _engine_flag_active(
			Gen2WorldState.badge_flag(badge, _crystal_commands())
		)
	if allowed and not bool(_request.get("tile_ok", true)):
		allowed = false
	if not allowed:
		var refusal: String = _field_move_prompt_refusal(move)
		if refusal.is_empty():
			## `.noevent`: TryHeadbuttOW and TrySurfOW answer no carry, so the
			## player event ends and nothing is shown at all.
			_script_value = 0
			return _complete()
		return _stage_internal_text(refusal, true)
	_pending = {
		"type": &"text",
		"text": _field_move_prompt_ask(move),
		"internal_text": true,
		"special": &"field_move_ask",
		"move": move,
		"slot": slot,
		"source": _request.duplicate(true),
	}
	_finish_after_pending = false
	return {"ok": true}


## Each Try*OW's own CheckEngineFlag argument, as a badge-order index, or -1 for
## the one that checks none. TryHeadbuttOW is CheckPartyMove and nothing else.
func _field_move_prompt_badge(move: int) -> int:
	match move:
		Gen2WorldFieldMove.MOVE_CUT:
			return Gen2WorldFieldMove.BADGE_HIVE
		Gen2WorldFieldMove.MOVE_SURF:
			return Gen2WorldFieldMove.BADGE_FOG
		Gen2WorldFieldMove.MOVE_WHIRLPOOL:
			return Gen2WorldFieldMove.BADGE_GLACIER
		Gen2WorldFieldMove.MOVE_WATERFALL:
			return Gen2WorldFieldMove.BADGE_RISING
	return -1


func _field_move_prompt_ask(move: int) -> String:
	match move:
		Gen2WorldFieldMove.MOVE_CUT:
			return CUT_ASK_TEXT
		Gen2WorldFieldMove.MOVE_SURF:
			return SURF_ASK_TEXT
		Gen2WorldFieldMove.MOVE_WHIRLPOOL:
			return WHIRLPOOL_ASK_TEXT
		Gen2WorldFieldMove.MOVE_WATERFALL:
			return WATERFALL_ASK_TEXT
	return HEADBUTT_ASK_TEXT


## CantCutScript, Script_MightyWhirlpool and Script_CantDoWaterfall. Headbutt
## and Surf have none, which is what the empty String means.
func _field_move_prompt_refusal(move: int) -> String:
	match move:
		Gen2WorldFieldMove.MOVE_CUT:
			return CUT_CAN_TEXT
		Gen2WorldFieldMove.MOVE_WHIRLPOOL:
			return WHIRLPOOL_MAY_PASS_TEXT
		Gen2WorldFieldMove.MOVE_WATERFALL:
			return WATERFALL_HUGE_TEXT
	return ""


## engine/events/overworld.asm's AskRockSmashScript, synthesized for the same
## reason AskStrengthScript is: SmashRockScript is `farsjump AskRockSmashScript`
## and its first command is `callasm HasRockSmash`, whose operand is a link-time
## address absent from the pins, so the seam is the standard-script index, 15 in
## both. `HasRockSmash` is CheckPartyMove and nothing else, so unlike the boulder
## there is no badge and no already-active flag to check: the whole gate is whether
## a party member knows ROCK SMASH.
func _stage_smash_rock() -> Dictionary:
	var party: Dictionary = _request.get("party", {})
	if party.is_empty():
		return {"ok": false, "reason": &"missing_party_summary", "standard_index": STD_SMASH_ROCK}
	var slot: int = _party_slot_with_move(Gen2WorldFieldMove.MOVE_ROCK_SMASH)
	if slot < 0:
		return _stage_internal_text(ROCK_SMASH_MAY_SMASH_TEXT, true)
	_pending = {
		"type": &"text",
		"text": ROCK_SMASH_ASK_TEXT,
		"internal_text": true,
		"special": &"rock_smash_ask",
		"slot": slot,
		"source": _request.duplicate(true),
	}
	_finish_after_pending = false
	return {"ok": true}


## RockSmashScript's `callasm GetPartyNickname` and `writetext UseRockSmashText`.
func _stage_rock_smash_used(slot: int) -> Dictionary:
	var name: String = _field_move_user_name(slot)
	_pending = {
		"type": &"text",
		"text": Gen2WorldFieldMove.used_text(Gen2WorldFieldMove.MOVE_ROCK_SMASH, name),
		"internal_text": true,
		"special": &"rock_smash_used",
		"source": _request.duplicate(true),
	}
	_finish_after_pending = false
	return {"ok": true}


## RockSmashScript past its sound, a staged wait at a time.
func _stage_rock_smash_shake() -> Dictionary:
	return _stage_earthquake(ROCK_SMASH_EARTHQUAKE, {"rock_smash_step": 1})


func _stage_rock_smash_movement() -> Dictionary:
	_emit_object_event(&"object_movement_requested", {
		"object_index": _last_talked_object_index,
		"bank": int(_request.get("bank", 0)),
		"movement": ROCK_SMASH_MOVEMENT,
	})
	return _stage_movement_wait({
		"object_index": _last_talked_object_index, "rock_smash_step": 2,
	})


func _stage_rock_smashed() -> void:
	## `disappear LAST_TALKED` is DeleteObjectStruct plus
	## ApplyEventActionAppearDisappear. The delete is reported as
	## `object_deleted` rather than a visibility override, so a rock with no
	## event flag is back on the next map load exactly as the cartridge's is;
	## the flag half is what makes Mt. Moon Square's stay smashed.
	_emit_object_event(&"object_deleted", {
		"object_index": _last_talked_object_index,
	})
	_emit_object_event(&"object_event_flag", {
		"object_index": _last_talked_object_index, "active": true,
	})
	_stage_object_event_flag(LAST_TALKED, true)
	var encounter: Dictionary = _rock_encounter()
	if encounter.is_empty():
		## `readmem wTempWildMonSpecies` then `iffalse .done`, and `.done` is
		## `end`. Clearing the frames is what reaching that end looks like here.
		_script_value = 0
		_frames.clear()
		return
	_battle_setup = _new_battle_setup({
		"kind": &"wild",
		"pokemon": int(encounter["species"]),
		"level": int(encounter["level"]),
	})
	_emit_runtime_event(&"battle_setup_changed", _battle_setup)
	_emit_runtime_event(&"battle_map_reload_requested", {"requested": true})
	_stage_runtime_request(&"battle_requested", _battle_request_values())


## RockMonEncounter over the imported RockMonMaps and the ROCK set, rolled on
## this invocation's own generator like every other roll the runner makes.
func _rock_encounter() -> Dictionary:
	if data == null:
		return {}
	var group: int = int(_request.get("map_group", -1))
	var number: int = int(_request.get("map_number", -1))
	var set_number: int = data.treemon_set_for_map(group, number, true)
	if not Gen2WorldTreemon.set_is_usable(set_number, _crystal_commands()):
		return {}
	return Gen2WorldTreemon.rock_encounter(data.treemon_set(set_number), _random)


## `Script_itemnotify`: `GetPocketName` and `CurItemName` into
## `PutItemInPocketText`, which `MapTextbox` prints and the script resumes
## behind. Every receipt in the source ends on this box.
func _stage_item_notify(item: int, finish_after: bool) -> Dictionary:
	var item_name: String = data.item_name(item) if data != null else ""
	if item_name.is_empty():
		item_name = "ITEM"
	return _stage_internal_text(
		PUT_ITEM_TEXT % [item_name, Gen2WorldPack.source_pocket_name(data, item)],
		finish_after
	)


## `Script_pocketisfull`, which is the same box with only the pocket in it.
func _stage_pocket_is_full(item: int, finish_after: bool) -> Dictionary:
	return _stage_internal_text(
		POCKET_FULL_TEXT % Gen2WorldPack.source_pocket_name(data, item), finish_after
	)


## `Script_verbosegiveitem` with no script around it, which is what a mod's ask
## through [method Gen2ModHost.request_item_gift] is: the same STRING_BUFFER_4
## fill, the same bag write and the same GiveItemScript tail the 0x9D command
## runs, finishing after the last box rather than resuming a caller, since there
## is no caller.
func _stage_item_gift() -> Dictionary:
	var item: int = int(_request.get("item", 0))
	var item_name: String = data.item_name(item) if data != null else ""
	if item <= 0 or item_name.is_empty():
		return _fail(&"invalid_item_gift", {"item": item})
	_set_text_buffer(
		RomLayout.STRING_BUFFER_4, item_name, &"item_name", {"item": item}
	)
	var given: Dictionary = _stage_item_delta(item, maxi(1, int(_request.get("quantity", 1))))
	if not bool(given.get("ok", true)):
		return given
	return _stage_give_item_script(item, item_name)


## `GiveItemScript`, which is the whole of `verbosegiveitem` past the receive:
## the received line, and then either the sound and `itemnotify` or, on a full
## pack, `pocketisfull`. The line is printed either way, because the source's
## `iffalse` sits behind its own `writetext`. Both boxes resume the caller.
func _stage_give_item_script(item: int, item_name: String) -> Dictionary:
	var named: String = item_name if not item_name.is_empty() else "ITEM"
	return _stage_internal_text(RECEIVED_ITEM_TEXT % named, false, {
		"special": &"item_received" if _script_value != 0 else &"pocket_is_full",
		"item": item,
	})


## The tail a receipt shares once its own line has been read: the sound, and
## then `itemnotify` behind it. [param sfx] is the id a script plays by name,
## or 0 for `specialsound`'s own pocket-dependent choice.
func _stage_receipt_tail(item: int, sfx: int, finish_after: bool) -> Dictionary:
	_item_notify_after_sound = {"item": item, "finish": finish_after}
	if sfx > 0:
		return _stage_audio_request(&"sound", {"address": sfx})
	return _stage_audio_request(&"special_sound", {"item": item})


func _stage_internal_text(
	text: String, finish_after: bool, values: Dictionary = {}
) -> Dictionary:
	var pending: Dictionary = {
		"type": &"text",
		"text": text,
		"internal_text": true,
		"source": _request.duplicate(true),
	}
	for key: Variant in values:
		pending[key] = values[key]
	_pending = pending
	_finish_after_pending = finish_after
	return {"ok": true}


func _stage_button(command: Dictionary) -> Dictionary:
	_pending = {
		"type": &"button",
		"command": command.get("name", &"button"),
		"source": _request.duplicate(true),
	}
	return {"ok": true}


func _stage_choice(command: Dictionary, choices: Array) -> Dictionary:
	_pending = {
		"type": &"choice",
		"command": command.get("name", &"choice"),
		"choices": choices.duplicate(true),
		"text": _standing_text,
		"source": _request.duplicate(true),
	}
	return {"ok": true}


func _show_text(bank: int, address: int, finish_after: bool) -> Dictionary:
	var raw: PackedByteArray = data.world_text(bank, address) if data != null else PackedByteArray()
	var decoded: Dictionary = _decode_text_with_buffers(raw)
	if not bool(decoded.get("ok", false)):
		return {
			"ok": false,
			"reason": decoded.get("reason", &"invalid_text"),
			"bank": bank,
			"address": address,
		}
	_last_text = {"bank": bank, "address": address}
	_pending = {
		"type": &"text",
		"text": String(decoded.get("text", "")),
		"bank": bank,
		"address": address,
		## `Script_writetext` is `MapTextbox` and returns: only `<PROMPT>`,
		## `text_promptbutton` and `text_waitbutton` spend a press inside the
		## text. A text ending in `<DONE>` therefore owes none of its own, and
		## the press belongs to the `waitbutton` behind the command.
		## `JumpTextScript` carries that `waitbutton` itself, which is what
		## [param finish_after] names.
		"prompt": finish_after or bool(decoded.get("prompt", false)),
		"source": _request.duplicate(true),
	}
	_finish_after_pending = finish_after
	return {"ok": true}


func _set_text_buffer(
	buffer: int, value: String, kind: StringName, details: Dictionary = {}
) -> void:
	_text_buffers[buffer] = value
	var event: Dictionary = {
		"buffer": buffer, "value": value, "kind": kind,
	}
	for key: Variant in details:
		event[key] = details[key]
	_emit_runtime_event(&"text_buffer_changed", event)


## The runner's own print-time context: the buffers `getstring` and
## `verbosegiveitem` fill, and the two names a map text can name.
func _decode_text_with_buffers(raw: PackedByteArray) -> Dictionary:
	return Gen2TextStream.decode(raw, 0, text_context())


## What `CheckDict` and `TX_STRINGBUFFER` read when this runner prints.
func text_context() -> Dictionary:
	var context: Dictionary = {
		"buffers": _text_buffers,
		"ram": _text_buffer_ram(),
		"rival": _rival_name,
	}
	if not player_name.is_empty():
		context["player"] = player_name
	if data != null:
		context["far"] = func(bank: int, address: int) -> PackedByteArray:
			return data.world_text(bank, address)
	return context


## The buffers this runner filled, keyed the way `TextCommand_RAM` asks for them.
##
## `getstring` and `verbosegiveitem` fill buffers by `text_buffer` number, but a
## `text_ram` names the same storage by its WRAM address, so the item texts read
## through StringBufferPointers rather than the number. Addresses come from the
## cartridge, since Gold and Crystal put the buffers in different places.
func _text_buffer_ram() -> Dictionary:
	if data == null or (_text_buffers.is_empty() and _text_ram.is_empty()):
		return {}
	var addresses: Array[int] = data.string_buffer_addresses()
	var out: Dictionary = _text_ram.duplicate()
	for buffer: Variant in _text_buffers:
		var index: int = int(buffer)
		if index >= 0 and index < addresses.size():
			out[addresses[index]] = _text_buffers[buffer]
	return out


func _runtime_memory_pointer(address: int) -> Dictionary:
	## memcall and memjump read a three-byte far pointer from a live RAM
	## address. The host supplies that RAM snapshot explicitly because the
	## runner does not emulate the cartridge's whole WRAM address space.
	var pointers: Variant = _request.get("memory_pointers", {})
	if not pointers is Dictionary:
		return {}
	var value: Variant = null
	if (pointers as Dictionary).has(address):
		value = (pointers as Dictionary)[address]
	else:
		for raw_address: Variant in pointers as Dictionary:
			if _runtime_memory_address(raw_address) == address:
				value = (pointers as Dictionary)[raw_address]
				break
	if not value is Dictionary:
		return {}
	var pointer: Dictionary = value as Dictionary
	var bank: int = int(pointer.get("bank", -1))
	var target: int = int(pointer.get("address", -1))
	if bank < 0 or target < RomFile.BANK_SIZE or target >= RomFile.BANK_SIZE * 2:
		return {}
	return {"bank": bank, "address": target}


static func _runtime_memory_address(value: Variant) -> int:
	if value is int or value is float:
		return int(value)
	var text: String = String(value).strip_edges()
	if text.begins_with("0x") or text.begins_with("0X"):
		return text.substr(2).hex_to_int()
	return text.to_int()


func _stage_warp(command: Dictionary) -> Dictionary:
	var request: Dictionary = {
		"map_group": int(command["map_group"]),
		"map_number": int(command["map_number"]),
		"x": int(command["x"]),
		"y": int(command["y"]),
	}
	# Script_warpfacing sets PLAYERSPRITESETUP_CUSTOM_FACING_F before falling
	# through Script_warp. Carry the same marker through map setup so the normal
	# destination-tile facing rule cannot overwrite it.
	if command.has("facing"):
		request["facing"] = int(command["facing"])
	if warp_validator.is_valid():
		var validation: Variant = warp_validator.call(
			request["map_group"], request["map_number"], Vector2i(request["x"], request["y"])
		)
		if not validation is Dictionary or not bool((validation as Dictionary).get("ok", false)):
			return {
				"ok": false,
				"reason": &"invalid_warp",
				"warp": request,
				"validation": validation,
			}
	_staged_warp = request
	_events.append({"type": &"warp_requested", "warp": request.duplicate(true)})
	return {"ok": true}


func _push_frame(
	bank: int, address: int, raw_override: PackedByteArray = PackedByteArray()
) -> bool:
	if data == null or address < RomFile.BANK_SIZE or address >= RomFile.BANK_SIZE * 2:
		return false
	if _frames.size() >= Gen2WorldScript.MAX_CALL_DEPTH:
		_fail(&"call_depth_limit", {"limit": Gen2WorldScript.MAX_CALL_DEPTH})
		return false
	var raw: PackedByteArray = raw_override if not raw_override.is_empty() else data.world_script(bank, address)
	if raw.is_empty():
		return false
	_frames.append({"bank": bank, "address": address, "data": raw, "offset": 0})
	return true


func _standard_script(index: int) -> Dictionary:
	if data == null or index < 0:
		return {}
	var entry: Dictionary = data.world_standard_script(index)
	var raw: Variant = entry.get("data", PackedByteArray())
	if entry.is_empty() or not raw is PackedByteArray or (raw as PackedByteArray).is_empty():
		return {}
	return entry


func _branch(taken: bool, bank: int, address: int) -> Dictionary:
	if not taken:
		return {"ok": true}
	return _replace_frame(bank, address)


func _event_flag_active(flag: int) -> bool:
	if _staged_flags.has(flag):
		return bool(_staged_flags[flag])
	return state != null and state.is_event_flag_active(flag)


func _engine_flag_active(flag: int) -> bool:
	if _staged_engine_flags.has(flag):
		return bool(_staged_engine_flags[flag])
	return state != null and state.is_engine_flag_active(flag)


## _GetVarAction's .CountBadges, over staged flags rather than committed ones.
##
## The cartridge has no staging: `setflag` writes wBadges and the `readvar`
## after it reads what was just written. Mahogany Gym is where that matters:
## PryceScript sets ENGINE_GLACIERBADGE, reads VAR_BADGES and branches on 7 to
## RadioTowerRocketsScript, which is what opens Mahogany's east exit. Counting
## committed flags answered 6 there and took the Goldenrod branch instead.
func _staged_badge_count() -> int:
	var crystal: bool = _crystal_commands()
	var count: int = 0
	for flag: int in (
		Gen2WorldState.BADGE_ENGINE_FLAGS if crystal
		else Gen2WorldState.BADGE_ENGINE_FLAGS_GOLD_SILVER
	):
		if _engine_flag_active(flag):
			count += 1
	return count


func _map_scene_value(map_group: int, map_number: int) -> int:
	var key: String = Gen2WorldState.map_scene_key(map_group, map_number)
	if _staged_scenes.has(key):
		return int(_staged_scenes[key])
	if state != null and state.map_scenes().has(key):
		return state.map_scene(map_group, map_number)
	if data != null:
		var map: Gen2WorldMap = data.world_map(map_group, map_number)
		if map != null and not (map.scripts.get("scenes", []) as Array).is_empty():
			# Crystal clears the map-scene table on a new game. Maps with scene
			# records therefore start at scene 0; maps without records use the
			# source no-scene sentinel below.
			return 0
	return 0xFF


func _replace_frame(
	bank: int, address: int, raw_override: PackedByteArray = PackedByteArray()
) -> Dictionary:
	if data == null or address < RomFile.BANK_SIZE or address >= RomFile.BANK_SIZE * 2:
		return {"ok": false, "reason": &"missing_jump_target", "bank": bank, "address": address}
	var raw: PackedByteArray = raw_override if not raw_override.is_empty() else data.world_script(bank, address)
	if raw.is_empty():
		return {"ok": false, "reason": &"missing_jump_target", "bank": bank, "address": address}
	_frames[_frames.size() - 1] = {
		"bank": bank, "address": address, "data": raw, "offset": 0,
	}
	return {"ok": true}


func _complete() -> Dictionary:
	if _completed:
		return _complete_result()
	if state == null:
		return _fail(&"missing_world_state", {})
	var runtime_changes: Dictionary = _staged_runtime_changes()
	var applied: Dictionary = state.apply_changes(
		_staged_flags, _staged_scenes, runtime_changes
	)
	if not bool(applied.get("ok", false)):
		return _fail(StringName(applied.get("reason", &"state_transaction_failed")), applied)
	_completed = true
	_active = false
	if not _staged_flags.is_empty() or not _staged_scenes.is_empty() \
		or not runtime_changes.is_empty():
		_events.append({
			"type": &"state_changed",
			"flags": _staged_flags.duplicate(true),
			"scenes": _staged_scenes.duplicate(true),
			"runtime": runtime_changes.duplicate(true),
		})
	if _staged_day_of_week >= 0:
		_events.append({
			"type": &"world_clock_changed",
			"day": _staged_day_of_week,
			"hour": _clock_hour(),
			"minute": _clock_minute(),
		})
	if _has_staged_dst:
		_events.append({"type": &"dst_changed", "enabled": _staged_dst_enabled})
	return _complete_result()


func _staged_runtime_changes() -> Dictionary:
	var out: Dictionary = {}
	for row: Array in [
		["items", not _staged_items.is_empty(), _staged_items.duplicate()],
		["money", not _staged_money.is_empty(), _staged_money.duplicate()],
		["coins", _staged_coins >= 0, _staged_coins],
		["phone_contacts", not _staged_phone_contacts.is_empty(),
			_staged_phone_contacts.duplicate()],
		["script_memory", not _staged_script_memory.is_empty(),
			_staged_script_memory.duplicate()],
		["just_battled", _has_staged_just_battled, _staged_just_battled],
		["swarm", _has_staged_swarm, _staged_swarm.duplicate()],
		["pending_special_phone_call", _has_staged_special_phone_call,
			_staged_special_phone_call],
		["kurt_apricorn_quantity", _has_staged_kurt_apricorn_quantity,
			_staged_kurt_apricorn_quantity],
		["fruit_trees", not _staged_fruit_trees.is_empty(), _staged_fruit_trees.duplicate()],
		["npc_trades", not _staged_npc_trades.is_empty(), _staged_npc_trades.duplicate()],
		["kenji_break_timer", _has_staged_kenji_break_timer, _staged_kenji_break_timer],
		["lucky_number_days_left", _has_staged_lucky_number_days_left,
			_staged_lucky_number_days_left],
		["lucky_id_number", _has_staged_lucky_id_number, _staged_lucky_id_number],
		["lucky_number_day", _has_staged_lucky_id_number, _staged_lucky_number_day],
		["caught_species", not _staged_caught_species.is_empty(),
			_staged_caught_species.duplicate()],
		["best_magikarp", not _staged_best_magikarp.is_empty(),
			_staged_best_magikarp.duplicate()],
		["blue_card_balance", _staged_blue_card_balance >= 0, _staged_blue_card_balance],
		["mom_savings_flags", _staged_mom_savings_flags >= 0, _staged_mom_savings_flags],
		["engine_flags", not _staged_engine_flags.is_empty(), _staged_engine_flags.duplicate()],
		["phone_receive_cycle", _reset_phone_receive_timer, 0],
		["phone_receive_minutes", _reset_phone_receive_timer,
			Gen2WorldState.PHONE_RECEIVE_DELAYS[0]],
	]:
		if bool(row[1]):
			out[row[0]] = row[2]
	return out


func _complete_result() -> Dictionary:
	var result: Dictionary = {
		"ok": true,
		"status": &"complete",
		"events": _drain_events(),
		"source": _request.duplicate(true),
		"warp": _staged_warp.duplicate(true),
		"commands": _command_count,
		"deferred": _ran_deferred,
	}
	if _staged_day_of_week >= 0:
		result["clock"] = {
			"day": _staged_day_of_week,
			"hour": _clock_hour(),
			"minute": _clock_minute(),
		}
	if _has_staged_dst:
		result["dst_enabled"] = _staged_dst_enabled
	return result


func _recovered_result(recovery: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"status": &"recovered",
		"events": _drain_events(),
		"source": _request.duplicate(true),
		"recovery": recovery.duplicate(true),
		"commands": _command_count,
	}


func _new_battle_setup(base: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	if _loaded_battle_type >= 0:
		out["battle_type"] = _loaded_battle_type
		out["can_lose"] = _loaded_battle_type == 1
	for key: String in ["win_text", "loss_text"]:
		if _battle_setup.has(key):
			out[key] = (_battle_setup[key] as Dictionary).duplicate(true)
	return out


func _trainer_text_pointer(trainer: Dictionary, key: String, default_bank: int) -> Dictionary:
	var raw: Variant = trainer.get(key, {})
	if raw is Dictionary:
		var pointer: Dictionary = (raw as Dictionary).duplicate(true)
		pointer["bank"] = int(pointer.get("bank", default_bank))
		pointer["address"] = int(pointer.get("address", 0))
		return pointer
	return {"bank": default_bank, "address": 0}


## Builds the source SeenByTrainerScript/StartBattleWithMapTrainerScript
## sequence: loadtemptrainer, encountermusic, farwritetext, waitbutton,
## loadtemptrainer, startbattle, reloadmapafterbattle, trainerflagaction, end.
## The sequence is identical between profiles at the source-opcode level;
## only the raw bytes differ, so every command goes through
## Gen2WorldScript.raw_opcode() rather than hard-coding either profile's byte.
func _trainer_intro_script(trainer: Dictionary) -> PackedByteArray:
	var seen: Dictionary = _trainer_text_pointer(
		trainer, "seen_text", int(_request.get("bank", 0))
	)
	var bank: int = int(seen.get("bank", _request.get("bank", 0)))
	var address: int = int(seen.get("address", 0))
	var crystal: bool = _crystal_commands()
	var raw: Callable = func(source_opcode: int) -> int:
		return Gen2WorldScript.raw_opcode(source_opcode, crystal)
	var bytes: Array = [
		# loadtemptrainer points at the request's trainer record.
		raw.call(Gen2WorldScript.GOLD_LOADTEMPTRAINER),
		raw.call(Gen2WorldScript.GOLD_ENCOUNTERMUSIC),
		Gen2WorldScript.FARWRITETEXT, bank, address & 0xFF, address >> 8,
		raw.call(0x53), # waitbutton
		raw.call(Gen2WorldScript.GOLD_LOADTEMPTRAINER),
		raw.call(Gen2WorldScript.GOLD_STARTBATTLE),
		raw.call(Gen2WorldScript.GOLD_RELOADMAPAFTERBATTLE),
		raw.call(Gen2WorldScript.GOLD_TRAINERFLAGACTION), 1,
		# StartBattleWithMapTrainerScript falls through into
		# AlreadyBeatenTrainerScript's scripttalkafter, with
		# wRunningTrainerBattleScript already set, so the after-battle script
		# runs now and its own endifjustbattled is what usually ends it. A
		# trainer that omits that command keeps going: Slowpoke Well's
		# TrainerGruntM1 clears the well from there.
		raw.call(Gen2WorldScript.GOLD_SCRIPTTALKAFTER),
		raw.call(Gen2WorldScript.GOLD_END),
	]
	return PackedByteArray(bytes)


func _battle_request_values() -> Dictionary:
	var out: Dictionary = _battle_setup.duplicate(true)
	var source_event: Variant = _request.get("event", {})
	if source_event is Dictionary:
		out["event"] = (source_event as Dictionary).duplicate(true)
	for key: String in [
		"map_group", "map_number", "object_index", "distance", "direction", "trigger",
	]:
		if _request.has(key):
			out[key] = _request[key]
	return out


## The events emitted since the last result, and only those. An invocation that
## stops four times hands each event to its caller once, because a caller applies
## and reacts to what a result carries: repeating the list would move an object
## twice and start a screen shake on every later pause.
func _drain_events() -> Array:
	var drained: Array = _events.duplicate(true)
	_events.clear()
	return drained


func _waiting_result() -> Dictionary:
	return {
		"ok": true,
		"status": &"waiting",
		"event": _pending.duplicate(true),
		"events": _drain_events(),
		"source": _request.duplicate(true),
		"commands": _command_count,
		"deferred": _ran_deferred,
	}


func _fail(reason: StringName, details: Dictionary) -> Dictionary:
	_active = false
	_failure = {"reason": reason, "details": details.duplicate(true)}
	return _failure_result()


func _failure_result() -> Dictionary:
	return {
		"ok": false,
		"status": &"failed",
		"reason": _failure.get("reason", &"script_failed"),
		"details": _failure.get("details", {}),
		"events": _drain_events(),
		"source": _request.duplicate(true),
		"commands": _command_count,
	}


func _crystal_commands() -> bool:
	if data == null:
		return true
	return data.id != &"gold" and data.id != &"silver"
