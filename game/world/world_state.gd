class_name Gen2WorldState
extends RefCounted

## Mutable state shared by the scene-free overworld systems.
##
## Cartridge-derived map records remain immutable in GameData. This record is
## the runtime boundary for event flags and can later be serialized by the
## save model without making Gen2WorldAPI own a save file.

signal changed

const PHONE_CONTACT_CAPACITY: int = 10
## constants/music_constants.asm. `wMapMusic` starts here and TryRestartMapMusic
## puts it back when a map asks not to restart its own track.
const MUSIC_NONE: int = 0
## `readmem`/`writemem`/`loadmem` address plain WRAM bytes. Only a bounded
## handful of them carry script state (`wFarfetchdPosition`,
## `wUndergroundSwitchPositions`, the phone rematch counters), so they are
## kept as an address-keyed byte map rather than a WRAM image.
const SCRIPT_MEMORY_CAPACITY: int = 64

## `CountStep`'s `cp $80`: the step count `DoEggStep` runs on, half a wrap away
## from the `StepHappiness` pass at zero.
const EGG_STEP_PHASE: int = 0x80
## `CountStep`'s own `cp 4` on `wPoisonStepCount`: the pass that reaches
## `DoPoisonStep`, counted in steps rather than in frames.
const POISON_STEP_PHASE: int = 4
const PHONE_RECEIVE_DELAYS: Array[int] = [20, 10, 5, 3]
## `SPECIALCALL_BIKESHOP` (`constants/phone_constants.asm`), the same index on
## both pins.
const SPECIALCALL_BIKESHOP: int = 6
## `DoBikeStep`'s own `cp HIGH(1024)` on the high byte, and the `$ffff` its two
## `cp 255` tests saturate the counter at.
const BIKE_SHOP_CALL_STEPS: int = 1024
const MAX_BIKE_STEP: int = 0xFFFF
## `wStatusFlags2`' `STATUSFLAGS2_BIKE_SHOP_CALL_F`, which the bike shop owner
## sets when he takes the player's number and which `DoBikeStep` clears behind
## the call it queues. Crystal index; see the badge comment for the split.
const ENGINE_BIKE_SHOP_CALL: int = 20
const ENGINE_BIKE_SHOP_CALL_GOLD_SILVER: int = 19
## `GROUP_N_A`/`MAP_N_A`, which `BattleEnd_HandleRoamMons` writes over a
## roamer's map bytes once it has been caught or defeated.
const ROAM_MAP_N_A: int = -1
## Both source reroll loops are unbounded; the cap stops a mod's dead-end graph.
const ROAM_ROLL_ATTEMPTS: int = 128
## `StoreSwarmMapIndices`' own two arguments, `constants/script_constants.asm`.
const SWARM_DUNSPARCE: int = 0
const SWARM_YANMA: int = 1
const TEMPORARY_MAP_RELOAD_FLAGS: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7]
## Crystal maps STATUSFLAGS_HALL_OF_FAME_F through the source engine flag
## table to ENGINE_CREDITS_SKIP, and the Goldenrod bargain merchant uses the
## daily ENGINE_GOLDENROD_UNDERGROUND_MERCHANT_CLOSED flag. Both names are
## Crystal indices, called out explicitly because pokegold's shorter engine
## flag table (see the badge comment below) puts the same symbol one index
## lower there.
const ENGINE_CREDITS_SKIP: int = 15
const ENGINE_HALL_OF_FAME: int = ENGINE_CREDITS_SKIP
## `CheckReceivedDex`'s own flag, which is what the Pokemon Center PC's list
## selection reads before the Hall of Fame one.
const ENGINE_POKEDEX: int = 11
## The next bit of the same `wStatusFlags` byte, `STATUSFLAGS_UNOWN_DEX_F`, which
## `Pokedex_CheckUnlockedUnownMode` reads and only the Ruins of Alph research
## centre's scientist sets. Ahead of ENGINE_MOBILE_SYSTEM, so it is one index on
## every profile.
const ENGINE_UNOWN_DEX: int = 12
## The one entry pokegold does not ship, and so the index every profile split in
## this table is measured from. See engine_flag().
const ENGINE_MOBILE_SYSTEM: int = 16
## `wUnlockedUnowns`, one engine flag per puzzle: the four `UnlockedUnownLetterSets`
## in source order, A-K first. `CheckUnownLetter` refuses a letter no unlocked set
## holds, and `ChooseWildEncounter` refuses a wild UNOWN outright while none is
## set. Crystal indices; engine_flag() moves them for Gold and Silver.
const ENGINE_UNLOCKED_UNOWNS_FIRST: int = 43
## The letters each set holds, 1 being A, in the order the table names them.
const UNOWN_LETTER_SETS: Array = [
	[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
	[12, 13, 14, 15, 16, 17, 18],
	[19, 20, 21, 22, 23],
	[24, 25, 26],
]
## The three wPokegearFlags/wStatusFlags bits the radio card reads
## (data/events/engine_flags.asm). Only the last is profile split, since it sits
## in the wStatusFlags2 run after Crystal's extra entry.
const ENGINE_RADIO_CARD: int = 0
const ENGINE_MAP_CARD: int = 1
const ENGINE_PHONE_CARD: int = 2
const ENGINE_EXPN_CARD: int = 3
const ENGINE_ROCKET_SIGNAL: int = 14
const ENGINE_ROCKETS_IN_RADIO_TOWER: int = 19
const ENGINE_ROCKETS_IN_RADIO_TOWER_GOLD_SILVER: int = 18
const ENGINE_GOLDENROD_UNDERGROUND_MERCHANT_CLOSED: int = 86
const ENGINE_GOLDENROD_UNDERGROUND_MERCHANT_CLOSED_GOLD_SILVER: int = 85
## `CELEBIEVENT_FOREST_IS_RESTLESS_F`, which `ForestTreeLeftAnimation` and its
## three neighbours read every tick: while it is set, Ilex Forest's two tree
## tiles cycle instead of standing on their first frame. Crystal only, the Gold
## and Silver `TilesetForestAnim` carrying no tree frame at all.
const ENGINE_FOREST_IS_RESTLESS: int = 100
## The first entry in the same `wDailyFlags1` byte. `KurtsHouse.asm` sets it
## when the apricorns are handed over and reads it to decide whether the ball is
## ready, so the day boundary is the whole of the errand's wait.
const ENGINE_KURT_MAKING_BALLS: int = 80
## Also `wDailyFlags1`. Not "every tree has fruit" but "the trees have already
## been refilled today": `TryResetFruitTrees` refills them only while this is
## clear, and `ResetFruitTrees` sets it behind itself.
const ENGINE_ALL_FRUIT_TREES: int = 84

## wBikeFlags' BIKEFLAGS_STRENGTH_ACTIVE_F, three engine flags ahead of the badge
## section and so profile split the same way. `SetStrengthFlag` is its one writer
## and `ResetBikeFlags` its one clear, so it lives exactly one map load.
const ENGINE_STRENGTH_ACTIVE: int = 24
const ENGINE_STRENGTH_ACTIVE_GOLD_SILVER: int = 23
## The next two flags in the same byte: `BIKEFLAGS_ALWAYS_ON_BIKE_F` is the whole
## of `.CantGetOffBike`, and `BIKEFLAGS_DOWNHILL_F` is Route 17's, unmodelled.
const ENGINE_ALWAYS_ON_BIKE: int = 25
const ENGINE_ALWAYS_ON_BIKE_GOLD_SILVER: int = 24
const ENGINE_DOWNHILL: int = 26

## wBadges spans wJohtoBadges then wKantoBadges as one contiguous flag_array, and
## VAR_BADGES counts both bytes, not Johto alone. These are Crystal indices:
## pokegold's constants/engine_flags.asm has no ENGINE_MOBILE_SYSTEM, which
## pokecrystal inserts ahead of the badge section, so every pokegold badge (and
## the merchant flag above) sits one index lower. `_GetVarAction.CountBadges` and
## the flag order are otherwise identical.
const ENGINE_ZEPHYRBADGE: int = 27
const ENGINE_HIVEBADGE: int = 28
const ENGINE_PLAINBADGE: int = 29
const ENGINE_FOGBADGE: int = 30
const ENGINE_MINERALBADGE: int = 31
const ENGINE_STORMBADGE: int = 32
const ENGINE_GLACIERBADGE: int = 33
const ENGINE_RISINGBADGE: int = 34
const ENGINE_BOULDERBADGE: int = 35
const ENGINE_CASCADEBADGE: int = 36
const ENGINE_THUNDERBADGE: int = 37
const ENGINE_RAINBOWBADGE: int = 38
const ENGINE_SOULBADGE: int = 39
const ENGINE_MARSHBADGE: int = 40
const ENGINE_VOLCANOBADGE: int = 41
const ENGINE_EARTHBADGE: int = 42
const BADGE_ENGINE_FLAGS: Array[int] = [
	ENGINE_ZEPHYRBADGE, ENGINE_HIVEBADGE, ENGINE_PLAINBADGE, ENGINE_FOGBADGE,
	ENGINE_MINERALBADGE, ENGINE_STORMBADGE, ENGINE_GLACIERBADGE, ENGINE_RISINGBADGE,
	ENGINE_BOULDERBADGE, ENGINE_CASCADEBADGE, ENGINE_THUNDERBADGE, ENGINE_RAINBOWBADGE,
	ENGINE_SOULBADGE, ENGINE_MARSHBADGE, ENGINE_VOLCANOBADGE, ENGINE_EARTHBADGE,
]
const BADGE_ENGINE_FLAGS_GOLD_SILVER: Array[int] = [
	ENGINE_ZEPHYRBADGE - 1, ENGINE_HIVEBADGE - 1, ENGINE_PLAINBADGE - 1, ENGINE_FOGBADGE - 1,
	ENGINE_MINERALBADGE - 1, ENGINE_STORMBADGE - 1, ENGINE_GLACIERBADGE - 1, ENGINE_RISINGBADGE - 1,
	ENGINE_BOULDERBADGE - 1, ENGINE_CASCADEBADGE - 1, ENGINE_THUNDERBADGE - 1, ENGINE_RAINBOWBADGE - 1,
	ENGINE_SOULBADGE - 1, ENGINE_MARSHBADGE - 1, ENGINE_VOLCANOBADGE - 1, ENGINE_EARTHBADGE - 1,
]

var _event_flags: Dictionary = {}
var _engine_flags: Dictionary = {}
var _map_scenes: Dictionary = {}
var _items: Dictionary = {}
## `wPCItems`, which is its own array on the cartridge rather than a pocket of
## the bag: `PlayersPC` moves stacks between the two and nothing else reads it.
## Absent in a state written before the item PC existed, which restores as an
## empty PC and needs no migration.
var _pc_items: Dictionary = {}
var _money: Dictionary = {}
var _coins: int = 0
var _phone_contacts: Dictionary = {}
var _just_battled: bool = false
var _repel_steps: int = 0
## Set by the step that took `_repel_steps` from one to zero and cleared by
## whoever spends it. See [method take_repel_expired].
var _repel_expired: bool = false
## `wBattleResult`'s BATTLERESULT_BOX_FULL bit. See [method battle_box_full].
var _battle_box_full: bool = false
## `wBattleResult`'s BATTLERESULT_CAUGHT_CELEBI, the sibling of the bit above.
## `CheckCaughtCelebi` is the one reader, and the Ilex Forest shrine script asks
## it once the fight is over.
var _battle_caught_celebi: bool = false
## `wWildEncounterCooldown`, which `EnterMap` sets to five and every step
## decrements. Scratch on the cartridge rather than saved data, kept here
## because this is where the world's own per-step counters live; a state written
## before it existed restores as zero, which is the value a walk reaches after
## its first four steps anyway.
var _wild_encounter_cooldown: int = 0
## `CountStep`'s own two bytes and `StepHappiness`'s, all three of them byte
## counters that wrap. `wStepCount` wrapping to zero is what `jr nz` reads to
## reach `StepHappiness`, and `wHappinessStepCount`'s `and 1` makes that act on
## every second visit, so the party gains a point every 512 steps.
## `wPoisonStepCount` is what `CountStep`'s own `cp 4` reads before it calls
## `DoPoisonStep`, and `EnterMap` zeroes it on MAPSETUP_RELOADMAP alone.
var _step_count: int = 0
var _poison_step_count: int = 0
var _happiness_step_count: int = 0
## How many `StepHappiness` passes the walk owes but no party owner has spent.
## The state has no party; the screen that does drains this.
var _pending_step_happiness: int = 0
## The same for `DoEggStep`, which `CountStep` reaches on the pass `wStepCount`
## is `$80`, so an egg loses one hatch cycle every 256 steps offset 128 from the
## happiness pass.
var _pending_egg_steps: int = 0
## `wDayCareMan` and `wDayCareLady`, their two boxmon slots, `wStepsToEgg` and
## the `wEggMon` the pair built. The slots are [Gen2SaveMon] rather than party
## members: a deposited Pokemon leaves the party whole and comes back recomputed,
## which is what `DepositBreedmon` and `RetrieveBreedmon` do.
var _day_care_man: int = 0
var _day_care_lady: int = 0
var _day_care_mons: Array = [null, null]
var _steps_to_egg: int = 0
var _day_care_egg: Gen2SaveMon = null
## `DayCareStep` runs on every step, not on a phase of the counter, so this is
## the whole step rather than a 256-step remainder.
var _pending_day_care_steps: int = 0
## `wStatusFlags`' `STATUSFLAGS_NO_WILD_ENCOUNTERS_F`, which `wildoff` sets and
## `wildon` clears around a scripted sequence.
var _wild_encounters_off: bool = false
## No cartridge byte: a staged run's own switch beside the one above. The
## trainer still stands, still draws and still talks; only the sighting is gone.
var _trainer_sightings_off: bool = false
## The Bug Catching Contest's own counters. `wParkBallsRemaining` and the clock
## reading `StartBugContestTimer` copies to `wBugContestStartTime`; whether a
## contest is running at all is `ENGINE_BUG_CONTEST_TIMER`, which is an engine
## flag and lives with the rest of them.
var _park_balls: int = 0
var _bug_contest_started: Dictionary = {}
## `wContestMon`, the party-struct-shaped Pokemon `BugContest_SetCaughtContestMon`
## generates. Kept as the fields `ContestScore` reads rather than a whole
## [Gen2BattleMon], because judging is all anything does with it.
var _contest_mon: Dictionary = {}
## `wBugContestSecondPartySpecies`: the byte `ContestDropOffMons` moves out of
## the way so the party is one Pokemon long, and `ContestReturnMons` puts back.
var _contest_second_party_species: int = 0
## `wDunsparceMapGroup`/`wDunsparceMapNumber` and `wYanmaMapGroup`/
## `wYanmaMapNumber`: Crystal's two swarms are independent, each with its own
## `wSwarmFlags` bit, and `_SwarmWildmonCheck` tries Dunsparce before Yanma.
## Gold and Silver hold one `wSwarmMapGroup` and their own
## `StoreSwarmMapIndices` takes no kind, so only [constant SWARM_DUNSPARCE] is
## ever written on those two.
var _swarm_maps: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(-1, -1)]
var _fishing_swarm_species: int = 0
var _roaming_mons: Array = []
## `wRoamMons_Cur*` and `wRoamMons_Last*`, `_BackUpMapIndices`' two pairs.
var _roam_cur_map := Vector2i(ROAM_MAP_N_A, ROAM_MAP_N_A)
var _roam_last_map := Vector2i(ROAM_MAP_N_A, ROAM_MAP_N_A)
var _seen_species: Dictionary = {}
## wPokedexCaught, the second half of `SetSeenAndCaughtMon`. Kept beside the
## seen array rather than derived from the party, because the cartridge's own
## flag survives releasing, trading away or boxing the Pokemon that set it.
var _caught_species: Dictionary = {}
## `wUnownDex`: the Unown forms caught, in catching order rather than by letter,
## and only the ones that reached the party. Twenty-six slots on the cartridge,
## where an empty one is a zero; here the list is as long as it is full, so its
## size is `.count_unown`'s own answer.
var _unown_dex: Array[int] = []
## `wFirstUnownSeen`, the letter every Pokedex entry for UNOWN is drawn with:
## `Pokedex_LoadSelectedMonTiles` copies it into `wUnownLetter` before it asks
## for the front picture. Written once, by whichever of the first sighting and
## the first party addition comes first, and saved with the rest of
## `wPokemonData`. Zero is a save that has met no Unown.
var _first_unown_seen: int = 0
var _phone_receive_cycle: int = 0
var _phone_receive_minutes: int = PHONE_RECEIVE_DELAYS[0]
var _pending_special_phone_call: int = 0
var _script_memory: Dictionary = {}
## `wMapMusic`, `wRadioTuningKnob` and `wCurRadioLine`. The music is state rather
## than something derived from the current map because `PlayMapMusic` writes it and
## compares against it, and because a tuned radio station overwrites it and survives
## the Pokegear closing; `SnorlaxAwake` reads exactly that byte. Below,
## `wStatusFlags`' `STATUSFLAGS_FLASH_F`, its own byte on the cartridge rather than
## an engine flag: `ResetFlashIfOutOfCave` clears it on entering a ROUTE or a TOWN,
## so a lit cave goes dark again the moment the player leaves and comes back.
var _used_flash: bool = false

## `wBikeStep`, the two bytes `DoBikeStep` counts a bike ride in. Saved player
## data on the cartridge, and the whole of how far off the bike shop owner's
## call still is.
var _bike_step: int = 0

var _map_music: int = MUSIC_NONE
var _radio_knob: int = Gen2WorldRadio.KNOB_MIN
var _radio_channel: int = -1
## `wLastDexMode`, which sits in the saved player data beside `wPokegearFlags`
## and `wRadioTuningKnob` rather than in the Pokedex's own cleared block: the
## dex takes its mode from here on opening and writes the mode back on exit.
var _last_dex_mode: int = RomLayout.DEXMODE_NEW
## The eight `wDeco*` slots, four of which stamp a block into the bedroom and
## four of which fill a variable sprite. Values are decoration ids from
## data/decorations/decorations.asm, not the blocks or sprites they stamp.
## [Gen2WorldDecoration] owns what each one means.
const MAPTILE_DECORATION_SLOTS: Array[StringName] = [
	&"bed", &"carpet", &"plant", &"poster",
	&"console", &"big_doll", &"left_ornament", &"right_ornament",
]
var _maptile_decorations: Dictionary = {}
## `wKurtApricornQuantity`. Saved player data, not scratch: `SelectApricornForKurt`
## writes it and `VAR_KURT_APRICORNS` is read a day later, by a different script
## invocation, to size the balls Kurt hands back.
var _kurt_apricorn_quantity: int = 0
## `wFruitTreeFlags`, one bit per `FRUITTREE_*` constant, set by `PickedFruitTree`
## and cleared for every tree at once by `ResetFruitTrees`. Kept as the set of
## picked tree ids because the source's own question is per tree.
var _picked_fruit_trees: Dictionary = {}
## `wTradeFlags`, one bit per `NPC_TRADE_*` index. `TradeFlagAction` is an NPC
## trade's whole once-only gate: no map script guards one.
var _npc_trades: Dictionary = {}
## `wRegisteredItem`. `wWhichRegisteredItem`'s pocket and slot number have no
## counterpart in the flat item model: `CheckRegisteredItem` uses them to find
## the entry again in its packed pocket array and clears both when the item is
## not there, which here is the quantity the item number already answers.
var _registered_item: int = 0
## `wLuckyIDNumber`, the five-digit number the Lucky Number Show draws every
## day, and `sLuckyNumberDay`, which is `wCurDay + 1` on the day it was drawn so
## that day zero is told from "never drawn"
## (`LoadOrRegenerateLuckyIDNumber`). Kept together because the pair is what
## says whether today's number has been rolled yet.
var _lucky_id_number: int = 0
var _lucky_number_day: int = 0
## `wLuckyNumberDayTimer`'s own days-remaining byte.
## `RestartLuckyNumberCountdown` sets it to the days until the next Friday and
## the day rollover steps it, which is `CheckDayDependentEventHL`'s answer with
## no absolute day to subtract.
var _lucky_number_days_left: int = 0
## `wKenjiBreakTimer`, three to six days between the Route 27 sailor's breaks.
## `CheckDailyResetTimer` decrements it on every day that passes and resamples
## when it reaches zero.
var _kenji_break_timer: int = 0
## `wBestMagikarpLengthFeet`, `..Inches` and the record holder's OT name, which
## `CheckMagikarpLength` writes together and the house's sign prints.
var _best_magikarp_feet: int = 0
var _best_magikarp_inches: int = 0
var _best_magikarp_ot: String = ""
## `wMomSavingMoney`, whose three bits are whether Mom's bank has been opened at
## all and how much of a prize she keeps. Her balance itself is
## `ACCOUNT_MOMS_MONEY`, which the money dictionary already carries.
var _mom_savings_flags: int = 0
## `wBuenasPassword`: the high nibble is the category the Lucky Channel drew
## this morning and the low nibble the word inside it. Saved player data, so a
## player who heard the show and then saved still knows the password when they
## reach the Radio Tower.
var _buenas_password: int = 0

## `wBlueCardBalance`, the points Buena's password earns and her prize counter
## spends. One byte and uncapped here: `BLUE_CARD_POINT_CAP` is RadioTower2F's
## own `ifequal` in front of the award, not a rule the byte enforces.
var _blue_card_balance: int = 0

## `wWhichMomItem`, `wWhichMomItemSet` and `wMomItemTriggerBalance`, the three
## `MomTriesToBuySomething` reads and writes. The index walks `MomItems_2` in
## order and never goes back; the set is 0 for that ladder and 1 plus a row for
## the five she picks from at random; the balance is the next `MOM_MONEY`
## boundary her savings have to land on exactly.
var _mom_item_index: int = 0
var _mom_item_set: int = 0
var _mom_item_trigger_balance: int = RomLayout.MOM_MONEY

## `wVariableSprites`, the sixteen `SPRITE_VARS` slots `GetMonSprite` resolves a
## variable sprite through. It sits inside `wPlayerData`, which `SaveData` copies
## whole into `sPlayerData`, so the table is saved and restored: an assignment
## made in one session is still there in the next. Keeping it on the world
## instead cost the port every one of them on reload, which drew the nine
## `InitializeEventsScript` rows as `SPRITE_CHRIS` (see [constant
## INITIAL_VARIABLE_SPRITES]).
var _variable_sprites: Dictionary = {}

## `InitializeEventsScript`, which the player's bedroom runs once at new game
## behind `EVENT_INITIALIZED_EVENTS`. A fresh state starts with these for the same
## reason [method Gen2WorldSpawn.apply_initial_decorations] exists: every state the
## game can be in has run it, and a slot with no row is `.NoBreedmon`'s
## `WALKING_SPRITE`, which is the player. The four `SPRITE_CONSOLE`..`SPRITE_BIG_DOLL`
## slots are deliberately absent, `ToggleDecorationsVisibility` filling those on
## every entry to the bedroom. The numbers are the same on all three cartridges.
const INITIAL_VARIABLE_SPRITES: Dictionary = {
	0xF4: 0x52,  # SPRITE_WEIRD_TREE      -> SPRITE_SUDOWOODO
	0xF5: 0x04,  # SPRITE_OLIVINE_RIVAL   -> SPRITE_RIVAL
	0xF6: 0x35,  # SPRITE_AZALEA_ROCKET   -> SPRITE_ROCKET
	0xF7: 0x0A,  # SPRITE_FUCHSIA_GYM_1   -> SPRITE_JANINE
	0xF8: 0x0A,  # SPRITE_FUCHSIA_GYM_2   -> SPRITE_JANINE
	0xF9: 0x0A,  # SPRITE_FUCHSIA_GYM_3   -> SPRITE_JANINE
	0xFA: 0x0A,  # SPRITE_FUCHSIA_GYM_4   -> SPRITE_JANINE
	0xFB: 0x28,  # SPRITE_COPYCAT         -> SPRITE_LASS
	0xFC: 0x28,  # SPRITE_JANINE_IMPERSONATOR -> SPRITE_LASS
}

## `SECTION "SRAM Battle Tower"`, which the cartridge keeps beside the save
## rather than inside it because a challenge can be saved and left between
## battles. Never null; see [Gen2BattleTower].
var _battle_tower: Gen2BattleTower = Gen2BattleTower.new()

## `SECTION "Link Battle Data"`'s WRAM half and the cable behind it. Neither is
## in [method to_dict]: the cartridge keeps none of `wLinkMode`,
## `wChosenCableClubRoom` or the serial registers across a reset, and a transport
## is injected by whoever owns the peer rather than saved with the world. A
## slot loaded from disk therefore starts outside the cable club, which is the
## truth about it.
var _link_session: Gen2LinkSession = Gen2LinkSession.new()
var _link_transport: Gen2LinkTransport = Gen2LinkTransport.new()

## `sMysteryGiftData`, mirrored here so the three specials can read and write it
## the way `OpenSRAM` does rather than through a runtime request: a scene script
## reaches `CheckMysteryGift` on the frame the map loads and has nothing to wait
## on. It is deliberately outside [method to_dict], because the section is not
## part of the checksummed save on the cartridge either: [Gen2SaveData] owns it
## and `RestoreMysteryGift` and `BackupMysteryGift` are what move it in and out
## ([method Gen2MysteryGift.restore], [method Gen2MysteryGift.backup]).
var _mystery_gift: Dictionary = Gen2MysteryGift.default_section()


func _init(
	initial_event_flags: Dictionary = {}, initial_map_scenes: Dictionary = {},
	initial_items: Dictionary = {}, initial_money: Dictionary = {}, initial_coins: int = 0,
	initial_phone_contacts: Dictionary = {}, initial_repel_steps: int = 0,
	initial_swarm_map: Vector2i = Vector2i(-1, -1), initial_fishing_swarm_species: int = 0,
	initial_roaming_mons: Array = [], initial_just_battled: bool = false,
	initial_phone_receive_cycle: int = 0, initial_phone_receive_minutes: int = PHONE_RECEIVE_DELAYS[0],
	initial_pending_special_phone_call: int = 0,
	initial_seen_species: Dictionary = {},
	initial_engine_flags: Dictionary = {},
	initial_script_memory: Dictionary = {},
	initial_caught_species: Dictionary = {},
	initial_maptile_decorations: Dictionary = {},
) -> void:
	_seed_flags(_event_flags, initial_event_flags, 0)
	_seed_flags(_engine_flags, initial_engine_flags, 0)
	_seed_flags(_seen_species, initial_seen_species, 1)
	## Caught implies seen, the way `SetSeenAndCaughtMon` falls through, so a
	## restored state cannot hold a caught species it has not seen.
	_seed_flags(_caught_species, initial_caught_species, 1)
	for species: int in _caught_species:
		_seen_species[species] = true
	_seed_flags(_phone_contacts, initial_phone_contacts, 0, PHONE_CONTACT_CAPACITY)
	for map_key: Variant in initial_map_scenes:
		var scene: int = int(initial_map_scenes[map_key])
		if scene >= 0:
			_map_scenes[String(map_key)] = scene
	_seed_counts(_items, initial_items, 1)
	_seed_counts(_money, initial_money, 0)
	_seed_counts(_script_memory, initial_script_memory, 1, 0xFF, SCRIPT_MEMORY_CAPACITY)
	for category: StringName in MAPTILE_DECORATION_SLOTS:
		var decoration: int = int(initial_maptile_decorations.get(category, 0)) & 0xFF
		if decoration > 0:
			_maptile_decorations[category] = decoration
	_coins = maxi(0, initial_coins)
	_repel_steps = maxi(0, initial_repel_steps)
	_swarm_maps[SWARM_DUNSPARCE] = initial_swarm_map
	_fishing_swarm_species = initial_fishing_swarm_species \
		if initial_fishing_swarm_species in [0, 0xD3, 0xDF] else 0
	_roaming_mons = _copy_roaming_mons(initial_roaming_mons)
	_just_battled = initial_just_battled
	_phone_receive_cycle = clampi(
		initial_phone_receive_cycle, 0, PHONE_RECEIVE_DELAYS.size() - 1
	)
	_phone_receive_minutes = maxi(0, initial_phone_receive_minutes)
	_pending_special_phone_call = maxi(0, initial_pending_special_phone_call)
	_variable_sprites = INITIAL_VARIABLE_SPRITES.duplicate()


## Keeps the true keys of [param source] that are at least [param low], up to
## [param capacity] of them.
static func _seed_flags(
	target: Dictionary, source: Dictionary, low: int, capacity: int = UNBOUNDED
) -> void:
	for raw_key: Variant in source:
		var key: int = int(raw_key)
		if key >= low and bool(source[raw_key]) and target.size() < capacity:
			target[key] = true


## Keeps the non-zero counts of [param source] whose key is at least [param low],
## each masked to [param mask], up to [param capacity] of them.
static func _seed_counts(
	target: Dictionary, source: Dictionary, low: int, mask: int = -1,
	capacity: int = UNBOUNDED
) -> void:
	for raw_key: Variant in source:
		var key: int = int(raw_key)
		var value: int = int(source[raw_key]) & mask
		if key >= low and value > 0 and target.size() < capacity:
			target[key] = value


## JSON-safe representation of the mutable overworld state. Cartridge records
## are deliberately absent because they belong to GameData, not a save.
func to_dict() -> Dictionary:
	return {
		"event_flags": _event_flags.duplicate(),
		"engine_flags": _engine_flags.duplicate(),
		"map_scenes": _map_scenes.duplicate(),
		"items": _items.duplicate(),
		"pc_items": _pc_items.duplicate(),
		"money": _money.duplicate(),
		"coins": _coins,
		"phone_contacts": _phone_contacts.duplicate(),
		"just_battled": _just_battled,
		"repel_steps": _repel_steps,
		"wild_encounter_cooldown": _wild_encounter_cooldown,
		"step_count": _step_count,
		"poison_step_count": _poison_step_count,
		"happiness_step_count": _happiness_step_count,
		"wild_encounters_off": _wild_encounters_off,
		"trainer_sightings_off": _trainer_sightings_off,
		"park_balls": _park_balls,
		"bug_contest_started": _bug_contest_started.duplicate(),
		"contest_mon": _contest_mon.duplicate(),
		"contest_second_party_species": _contest_second_party_species,
		"swarm_map": [_swarm_maps[SWARM_DUNSPARCE].x, _swarm_maps[SWARM_DUNSPARCE].y],
		"yanma_swarm_map": [_swarm_maps[SWARM_YANMA].x, _swarm_maps[SWARM_YANMA].y],
		"fishing_swarm_species": _fishing_swarm_species,
		"roaming_mons": _copy_roaming_mons(_roaming_mons),
		"roam_cur_map": [_roam_cur_map.x, _roam_cur_map.y],
		"roam_last_map": [_roam_last_map.x, _roam_last_map.y],
		"seen_species": _seen_species.duplicate(),
		"caught_species": _caught_species.duplicate(),
		"unown_dex": _unown_dex.duplicate(),
		"first_unown_seen": _first_unown_seen,
		"phone_receive_cycle": _phone_receive_cycle,
		"phone_receive_minutes": _phone_receive_minutes,
		"pending_special_phone_call": _pending_special_phone_call,
		"script_memory": _script_memory.duplicate(),
		"used_flash": _used_flash,
		"bike_step": _bike_step,
		"map_music": _map_music,
		"radio_knob": _radio_knob,
		"radio_channel": _radio_channel,
		"last_dex_mode": _last_dex_mode,
		"maptile_decorations": _maptile_decorations.duplicate(),
		"kurt_apricorn_quantity": _kurt_apricorn_quantity,
		"picked_fruit_trees": _picked_fruit_trees.duplicate(),
		"npc_trades": _npc_trades.duplicate(),
		"registered_item": _registered_item,
		"day_care_man": _day_care_man,
		"day_care_lady": _day_care_lady,
		"day_care_mons": _day_care_mons_dict(),
		"steps_to_egg": _steps_to_egg,
		"day_care_egg": {} if _day_care_egg == null else _day_care_egg.to_dict(),
		"battle_caught_celebi": _battle_caught_celebi,
		"lucky_id_number": _lucky_id_number,
		"lucky_number_day": _lucky_number_day,
		"lucky_number_days_left": _lucky_number_days_left,
		"kenji_break_timer": _kenji_break_timer,
		"best_magikarp": {
			"feet": _best_magikarp_feet,
			"inches": _best_magikarp_inches,
			"ot": _best_magikarp_ot,
		},
		"mom_savings_flags": _mom_savings_flags,
		"mom_item_index": _mom_item_index,
		"mom_item_set": _mom_item_set,
		"mom_item_trigger_balance": _mom_item_trigger_balance,
		"blue_card_balance": _blue_card_balance,
		"buenas_password": _buenas_password,
		"variable_sprites": _variable_sprites.duplicate(),
		"battle_tower": _battle_tower.to_dict(),
	}


## Rehydrates only the bounded state shape. The selected GameData remains
## responsible for validating map, item and species references at save load.
static func from_dict(raw: Variant) -> Gen2WorldState:
	if not raw is Dictionary:
		return Gen2WorldState.new()
	var source: Dictionary = raw
	var restored: Gen2WorldState = Gen2WorldState.new(
		_map(source, "event_flags"), _map(source, "map_scenes"), _map(source, "items"),
		_map(source, "money"), int(source.get("coins", 0)),
		_map(source, "phone_contacts"), int(source.get("repel_steps", 0)),
		_vector_from_value(source.get("swarm_map", [-1, -1])),
		int(source.get("fishing_swarm_species", 0)),
		_list(source, "roaming_mons"), bool(source.get("just_battled", false)),
		int(source.get("phone_receive_cycle", 0)),
		int(source.get("phone_receive_minutes", PHONE_RECEIVE_DELAYS[0])),
		int(source.get("pending_special_phone_call", 0)),
		_map(source, "seen_species"), _map(source, "engine_flags"),
		_map(source, "script_memory"), _map(source, "caught_species"),
		_map(source, "maptile_decorations"),
	)
	_seed_counts(restored._pc_items, _map(source, "pc_items"), 1, -1, Gen2WorldPack.MAX_PC_ITEMS)
	_seed_flags(restored._picked_fruit_trees, _map(source, "picked_fruit_trees"), 1)
	_seed_flags(restored._npc_trades, _map(source, "npc_trades"), 0)
	restored._swarm_maps[SWARM_YANMA] = _vector_from_value(
		source.get("yanma_swarm_map", [-1, -1])
	)
	restored._roam_cur_map = _vector_from_value(
		source.get("roam_cur_map", [ROAM_MAP_N_A, ROAM_MAP_N_A])
	)
	restored._roam_last_map = _vector_from_value(
		source.get("roam_last_map", [ROAM_MAP_N_A, ROAM_MAP_N_A])
	)
	restored._used_flash = bool(source.get("used_flash", false))
	restored._bike_step = clampi(int(source.get("bike_step", 0)), 0, MAX_BIKE_STEP)
	restored._map_music = maxi(0, int(source.get("map_music", MUSIC_NONE)))
	restored.set_radio_knob(int(source.get("radio_knob", Gen2WorldRadio.KNOB_MIN)))
	restored._radio_channel = int(source.get("radio_channel", -1))
	restored.set_last_dex_mode(int(source.get("last_dex_mode", RomLayout.DEXMODE_NEW)))
	restored.set_kurt_apricorn_quantity(int(source.get("kurt_apricorn_quantity", 0)))
	## Absent in a state written before the Unown dex, which reads as an empty
	## one: the flag that unlocks the mode is an engine flag and survives on its
	## own, so an old save shows the mode with nothing listed under it, which is
	## what a player who has caught none would see anyway.
	## Read before the forms below, because [method update_unown_dex] writes this
	## byte too: a state that carries one keeps it, and one written before the
	## byte was kept falls back to the first form caught, which is the same
	## answer for every save whose first Unown was caught rather than only met.
	restored.note_first_unown_seen(int(source.get("first_unown_seen", 0)))
	for raw_form: Variant in _list(source, "unown_dex"):
		restored.update_unown_dex(int(raw_form))
	restored.set_registered_item(int(source.get("registered_item", 0)))
	restored.set_wild_encounter_cooldown(int(source.get("wild_encounter_cooldown", 0)))
	restored._step_count = int(source.get("step_count", 0)) & 0xFF
	restored._poison_step_count = int(source.get("poison_step_count", 0)) & 0xFF
	restored._happiness_step_count = int(source.get("happiness_step_count", 0)) & 1
	restored.set_wild_encounters_off(bool(source.get("wild_encounters_off", false)))
	restored.set_trainer_sightings_off(
		bool(source.get("trainer_sightings_off", false))
	)
	restored.set_park_balls(int(source.get("park_balls", 0)))
	restored._bug_contest_started = _clock_dict(_map(source, "bug_contest_started"))
	var caught: Dictionary = _map(source, "contest_mon")
	if int(caught.get("species", 0)) > 0:
		restored._contest_mon = caught.duplicate()
	restored.set_contest_second_party_species(
		int(source.get("contest_second_party_species", 0))
	)
	_restore_day_care(restored, source)
	_restore_deferred(restored, source)
	restored._battle_tower = Gen2BattleTower.from_dict(source.get("battle_tower", {}))
	var sprites: Dictionary = _map(source, "variable_sprites")
	for raw_slot: Variant in sprites:
		restored.set_variable_sprite(int(raw_slot), int(sprites[raw_slot]))
	return restored


## [param source]'s [param key] when it is a Dictionary, and an empty one when it
## is missing or something else. A field absent from a state written by an older
## build reads as the value a new game holds, which is why nothing here versions.
static func _map(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	return value if value is Dictionary else {}


## The same for a list.
static func _list(source: Dictionary, key: String) -> Array:
	var value: Variant = source.get(key, [])
	return value if value is Array else []


static func _restore_day_care(restored: Gen2WorldState, source: Dictionary) -> void:
	restored._day_care_man = int(source.get("day_care_man", 0)) & 0xFF
	restored._day_care_lady = int(source.get("day_care_lady", 0)) & 0xFF
	restored._steps_to_egg = int(source.get("steps_to_egg", 0)) & 0xFF
	var stored: Array = _list(source, "day_care_mons")
	for slot: int in mini(stored.size(), 2):
		restored._day_care_mons[slot] = _mon_from_value(stored[slot])
	restored._day_care_egg = _mon_from_value(source.get("day_care_egg", {}))


## The lucky number, the Magikarp record, Mom's bank and Buena's password. Zero
## reads as "never drawn", "no record" and "Mom has not been asked"; the one
## field that does not default to zero is hers, because `NewGame` writes
## `MOM_MONEY` there rather than a balance she has already passed.
static func _restore_deferred(restored: Gen2WorldState, source: Dictionary) -> void:
	restored._battle_caught_celebi = bool(source.get("battle_caught_celebi", false))
	restored._lucky_id_number = int(source.get("lucky_id_number", 0)) & 0xFFFF
	restored._lucky_number_day = int(source.get("lucky_number_day", 0)) & 0xFF
	restored._lucky_number_days_left = int(source.get("lucky_number_days_left", 0)) & 0xFF
	restored._kenji_break_timer = int(source.get("kenji_break_timer", 0)) & 0xFF
	var record: Dictionary = _map(source, "best_magikarp")
	restored._best_magikarp_feet = int(record.get("feet", 0)) & 0xFF
	restored._best_magikarp_inches = int(record.get("inches", 0)) & 0xFF
	restored._best_magikarp_ot = String(record.get("ot", ""))
	restored._mom_savings_flags = int(source.get("mom_savings_flags", 0)) & 0xFF
	restored._mom_item_index = maxi(int(source.get("mom_item_index", 0)), 0)
	restored._mom_item_set = maxi(int(source.get("mom_item_set", 0)), 0)
	restored._mom_item_trigger_balance = clampi(
		int(source.get("mom_item_trigger_balance", RomLayout.MOM_MONEY)),
		0, Gen2WorldInventory.MAX_MONEY
	)
	restored._blue_card_balance = int(source.get("blue_card_balance", 0)) & 0xFF
	restored._buenas_password = int(source.get("buenas_password", 0)) & 0xFF


## Restores the mutable state after a host transaction could not be persisted.
## The state object stays alive so existing world systems keep their signal
## connection.
func restore_from_dict(raw: Variant) -> void:
	var restored: Gen2WorldState = Gen2WorldState.from_dict(raw)
	if restored == null:
		return
	_event_flags = restored._event_flags.duplicate()
	_engine_flags = restored._engine_flags.duplicate()
	_map_scenes = restored._map_scenes.duplicate()
	_items = restored._items.duplicate()
	_pc_items = restored._pc_items.duplicate()
	_money = restored._money.duplicate()
	_coins = restored._coins
	_phone_contacts = restored._phone_contacts.duplicate()
	_just_battled = restored._just_battled
	_repel_steps = restored._repel_steps
	_used_flash = restored._used_flash
	_bike_step = restored._bike_step
	_wild_encounter_cooldown = restored._wild_encounter_cooldown
	_step_count = restored._step_count
	_poison_step_count = restored._poison_step_count
	_happiness_step_count = restored._happiness_step_count
	_pending_step_happiness = 0
	_pending_egg_steps = 0
	_wild_encounters_off = restored._wild_encounters_off
	_trainer_sightings_off = restored._trainer_sightings_off
	_park_balls = restored._park_balls
	_bug_contest_started = restored._bug_contest_started.duplicate()
	_contest_mon = restored._contest_mon.duplicate()
	_contest_second_party_species = restored._contest_second_party_species
	_swarm_maps = restored._swarm_maps.duplicate()
	_fishing_swarm_species = restored._fishing_swarm_species
	_roaming_mons = _copy_roaming_mons(restored._roaming_mons)
	_roam_cur_map = restored._roam_cur_map
	_roam_last_map = restored._roam_last_map
	_seen_species = restored._seen_species.duplicate()
	_caught_species = restored._caught_species.duplicate()
	_unown_dex = restored._unown_dex.duplicate()
	_first_unown_seen = restored._first_unown_seen
	_phone_receive_cycle = restored._phone_receive_cycle
	_phone_receive_minutes = restored._phone_receive_minutes
	_pending_special_phone_call = restored._pending_special_phone_call
	_script_memory = restored._script_memory.duplicate()
	_map_music = restored._map_music
	_radio_knob = restored._radio_knob
	_radio_channel = restored._radio_channel
	_last_dex_mode = restored._last_dex_mode
	_maptile_decorations = restored._maptile_decorations.duplicate()
	_kurt_apricorn_quantity = restored._kurt_apricorn_quantity
	_picked_fruit_trees = restored._picked_fruit_trees.duplicate()
	_npc_trades = restored._npc_trades.duplicate()
	_registered_item = restored._registered_item
	_day_care_man = restored._day_care_man
	_day_care_lady = restored._day_care_lady
	_day_care_mons = restored._day_care_mons.duplicate()
	_steps_to_egg = restored._steps_to_egg
	_day_care_egg = restored._day_care_egg
	_pending_day_care_steps = 0
	_battle_caught_celebi = restored._battle_caught_celebi
	_lucky_id_number = restored._lucky_id_number
	_lucky_number_day = restored._lucky_number_day
	_lucky_number_days_left = restored._lucky_number_days_left
	_kenji_break_timer = restored._kenji_break_timer
	_best_magikarp_feet = restored._best_magikarp_feet
	_best_magikarp_inches = restored._best_magikarp_inches
	_best_magikarp_ot = restored._best_magikarp_ot
	_mom_savings_flags = restored._mom_savings_flags
	_mom_item_index = restored._mom_item_index
	_mom_item_set = restored._mom_item_set
	_mom_item_trigger_balance = restored._mom_item_trigger_balance
	_blue_card_balance = restored._blue_card_balance
	_buenas_password = restored._buenas_password
	_variable_sprites = restored._variable_sprites.duplicate()
	_battle_tower = restored._battle_tower
	changed.emit()


## The live Battle Tower record, which callers edit in place: every write to it
## is a write to SRAM the cartridge would have made straight away, and there is
## no transaction between the receptionist and the section.
func battle_tower() -> Gen2BattleTower:
	return _battle_tower


## The live link session, which callers edit in place the way they do the tower's
## record: every write is one the cartridge would have made to WRAM straight
## away.
func link_session() -> Gen2LinkSession:
	return _link_session


func link_transport() -> Gen2LinkTransport:
	return _link_transport


func mystery_gift() -> Dictionary:
	return _mystery_gift


## `RestoreMysteryGift`'s destination: the section a save slot carried.
func set_mystery_gift(section: Dictionary) -> void:
	_mystery_gift = Gen2MysteryGift.normalize(section)


## Injects the cable. A null transport is no cable at all, which is what the
## receptionist's "your friend is not ready" answers.
func set_link_transport(transport: Gen2LinkTransport) -> void:
	_link_transport = transport if transport != null else Gen2LinkTransport.new()


## `GetMonSprite`'s `.Variable` read. Zero is `.NoBreedmon`, whose
## `ld a, WALKING_SPRITE` the caller resolves.
func variable_sprite(slot: int) -> int:
	return int(_variable_sprites.get(slot, 0))


func variable_sprites() -> Dictionary:
	return _variable_sprites.duplicate()


## `Script_variablesprite`: one byte written into the table. A zero is refused
## rather than stored, because the table's own zero means "unassigned".
func set_variable_sprite(slot: int, sprite: int) -> bool:
	if slot < Gen2WorldScriptRunner.VARIABLE_SPRITE_BASE or slot > 0xFF \
		or sprite <= 0 or sprite > 0xFF:
		return false
	if variable_sprite(slot) == sprite:
		return true
	_variable_sprites[slot] = sprite
	changed.emit()
	return true


func maptile_decoration(category: StringName) -> int:
	return int(_maptile_decorations.get(category, 0))


func maptile_decorations() -> Dictionary:
	return _maptile_decorations.duplicate()


func set_maptile_decoration(category: StringName, decoration: int) -> bool:
	if category not in MAPTILE_DECORATION_SLOTS \
		or decoration < 0 or decoration > 0xFF:
		return false
	if maptile_decoration(category) == decoration:
		return true
	if decoration == 0:
		_maptile_decorations.erase(category)
	else:
		_maptile_decorations[category] = decoration
	changed.emit()
	return true


static func _vector_from_value(value: Variant) -> Vector2i:
	if value is Array and (value as Array).size() >= 2:
		return Vector2i(int((value as Array)[0]), int((value as Array)[1]))
	if value is Dictionary:
		return Vector2i(int((value as Dictionary).get("x", -1)), int((value as Dictionary).get("y", -1)))
	return Vector2i(-1, -1)


func is_event_flag_active(flag: int) -> bool:
	return flag >= 0 and bool(_event_flags.get(flag, false))


func set_event_flag(flag: int, active: bool = true) -> void:
	if flag < 0:
		return
	var was_active: bool = is_event_flag_active(flag)
	if was_active == active:
		return
	if active:
		_event_flags[flag] = true
	else:
		_event_flags.erase(flag)
	changed.emit()


func clear_event_flag(flag: int) -> void:
	set_event_flag(flag, false)


func event_flags() -> Dictionary:
	return _event_flags.duplicate()


func is_engine_flag_active(flag: int) -> bool:
	return flag >= 0 and bool(_engine_flags.get(flag, false))


func set_engine_flag(flag: int, active: bool = true) -> void:
	if flag < 0:
		return
	var was_active: bool = is_engine_flag_active(flag)
	if was_active == active:
		return
	if active:
		_engine_flags[flag] = true
	else:
		_engine_flags.erase(flag)
	changed.emit()


func clear_engine_flag(flag: int) -> void:
	set_engine_flag(flag, false)


func engine_flags() -> Dictionary:
	return _engine_flags.duplicate()


func hall_of_fame() -> bool:
	return is_engine_flag_active(ENGINE_HALL_OF_FAME)


func set_hall_of_fame(active: bool = true) -> void:
	set_engine_flag(ENGINE_HALL_OF_FAME, active)


## The `wUnlockedUnowns` byte this save holds, one bit per set, as
## `CheckUnownLetter` and `ChooseWildEncounter` read it.
func unlocked_unowns(crystal: bool = true) -> int:
	var mask: int = 0
	for set_index: int in UNOWN_LETTER_SETS.size():
		if is_engine_flag_active(
			engine_flag(ENGINE_UNLOCKED_UNOWNS_FIRST + set_index, crystal)
		):
			mask |= 1 << set_index
	return mask


## `CheckUnownLetter`: whether [param letter] (1 being A) is in any set
## [param unlocked] has the bit for. A negative mask is no gate at all, which is
## what a caller with no save behind it passes.
static func unown_letter_unlocked(letter: int, unlocked: int) -> bool:
	if unlocked < 0:
		return true
	for set_index: int in UNOWN_LETTER_SETS.size():
		if (unlocked & (1 << set_index)) == 0:
			continue
		if letter in (UNOWN_LETTER_SETS[set_index] as Array):
			return true
	return false


## `crystal` selects which game's engine flag table this state's raw flag
## numbers were written against; pass [method is_crystal_profile] with the
## active GameData. Defaults to Crystal, matching every existing caller.
func bargain_merchant_closed(crystal: bool = true) -> bool:
	return is_engine_flag_active(
		engine_flag(ENGINE_GOLDENROD_UNDERGROUND_MERCHANT_CLOSED, crystal)
	)


## The engine flag one badge occupies on the table [param crystal] selects,
## indexed in source badge order: 0 is ZEPHYRBADGE and 15 EARTHBADGE. Out of
## range answers -1, which is_engine_flag_active() reads as inactive. This is
## what a CheckBadge caller uses, so no caller indexes the two arrays itself.
static func badge_flag(badge: int, crystal: bool = true) -> int:
	var flags: Array[int] = BADGE_ENGINE_FLAGS if crystal else BADGE_ENGINE_FLAGS_GOLD_SILVER
	return flags[badge] if badge >= 0 and badge < flags.size() else -1


## [param crystal_index] resolved onto the table [param crystal] selects. The
## two tables differ only in that pokegold ships no ENGINE_MOBILE_SYSTEM, so
## everything past that one index sits one lower there. The named pairs above
## are this same shift written out for the flags a runtime path reads; a caller
## holding a Crystal index and no pair asks here. ENGINE_MOBILE_SYSTEM itself
## answers -1 off Crystal, which is_engine_flag_active() reads as inactive,
## since Gold and Silver have no flag to map it onto.
static func engine_flag(crystal_index: int, crystal: bool = true) -> int:
	if crystal or crystal_index < ENGINE_MOBILE_SYSTEM:
		return crystal_index
	return crystal_index - 1 if crystal_index > ENGINE_MOBILE_SYSTEM else -1


## The `ENGINE_FLYPOINT_*` run, which is `wVisitedSpawns` a bit at a time: the flag
## `CheckIfVisitedFlypoint` tests for spawn [param spawn], as a Crystal index
## resolved onto [param crystal]'s own table. The rows are the spawns in order with
## one hole in them: `SPAWN_UNION_CAVE` has no flag of its own, so every spawn past
## it sits one row lower than its own number. -1 for the Union Cave spawn and for
## anything outside the run, which [method is_engine_flag_active] reads as inactive.
static func flypoint_flag(spawn: int, crystal: bool = true) -> int:
	if spawn < 0 or spawn >= NUM_SPAWNS or spawn == SPAWN_UNION_CAVE:
		return -1
	var index: int = ENGINE_FLYPOINT_FIRST + spawn
	if spawn > SPAWN_UNION_CAVE:
		index -= 1
	return engine_flag(index, crystal)


## `ENGINE_FLYPOINT_PLAYERS_HOUSE`, where the run starts, and the one spawn the
## run skips.
const ENGINE_FLYPOINT_FIRST: int = 51
const SPAWN_UNION_CAVE: int = 17
const NUM_SPAWNS: int = RomLayout.SPAWN_COUNT


## The engine flag SetStrengthFlag sets and TryStrengthOW and
## DoPlayerMovement.CheckStrengthBoulder read, resolved for [param crystal] the
## way badge_flag() resolves a badge.
static func strength_active_flag(crystal: bool = true) -> int:
	return ENGINE_STRENGTH_ACTIVE if crystal else ENGINE_STRENGTH_ACTIVE_GOLD_SILVER


## `.GetOffBike`'s own `bit BIKEFLAGS_ALWAYS_ON_BIKE_F`, resolved for the profile
## [param data] names the way strength_active_flag() resolves its own.
static func always_on_bike_flag(data: GameData) -> int:
	return ENGINE_ALWAYS_ON_BIKE if is_crystal_profile(data) \
		else ENGINE_ALWAYS_ON_BIKE_GOLD_SILVER


## `ResetBikeFlags` (`home/flag.asm`), which zeroes `wBikeFlags` whole.
func reset_bike_flags(crystal: bool = true) -> bool:
	var did_change: bool = false
	for index: int in [ENGINE_STRENGTH_ACTIVE, ENGINE_ALWAYS_ON_BIKE, ENGINE_DOWNHILL]:
		var flag: int = engine_flag(index, crystal)
		if not _engine_flags.has(flag):
			continue
		_engine_flags.erase(flag)
		did_change = true
	if did_change:
		changed.emit()
	return did_change


## Mirrors _GetVarAction's .CountBadges: a popcount over both badge bytes.
func badge_count(crystal: bool = true) -> int:
	var count: int = 0
	for flag: int in (BADGE_ENGINE_FLAGS if crystal else BADGE_ENGINE_FLAGS_GOLD_SILVER):
		if is_engine_flag_active(flag):
			count += 1
	return count


## The source badge bytes as one mask in badge order, for the battle engine's
## `DoBadgeTypeBoosts` and `BadgeStatBoosts` readers.
func badge_mask(crystal: bool = true) -> int:
	var mask: int = 0
	var flags: Array[int] = BADGE_ENGINE_FLAGS if crystal else BADGE_ENGINE_FLAGS_GOLD_SILVER
	for badge: int in flags.size():
		if is_engine_flag_active(flags[badge]):
			mask |= 1 << badge
	return mask


## `CheckDailyResetTimer` (`engine/overworld/time.asm`) zeroes `wDailyFlags1`
## through `wSwarmFlags` and the three phone runs behind them, so every engine
## flag in those bytes goes together. Inclusive Crystal index runs, which
## `engine_flag()` resolves onto Gold and Silver.
const DAILY_ENGINE_FLAG_RUNS: Array[Vector2i] = [
	Vector2i(80, 97), Vector2i(101, 158), Vector2i(160, 161),
]


func reset_daily_flags(
	crystal: bool = true, random: RandomNumberGenerator = null
) -> bool:
	var did_change: bool = false
	for run: Vector2i in DAILY_ENGINE_FLAG_RUNS:
		for crystal_index: int in range(run.x, run.y + 1):
			var flag: int = engine_flag(crystal_index, crystal)
			if not _engine_flags.has(flag):
				continue
			_engine_flags.erase(flag)
			did_change = true
	## Crystal's `_SwarmWildmonCheck` reads `wSwarmFlags` before either map, so
	## the byte going is what ends a swarm; pokegold's reads the map alone.
	if crystal:
		for kind: int in _swarm_maps.size():
			if _swarm_maps[kind] == Vector2i(-1, -1):
				continue
			_swarm_maps[kind] = Vector2i(-1, -1)
			did_change = true
	## The same branch steps `wKenjiBreakTimer` and resamples it when it runs
	## out, and every day-counted timer this project keeps is stepped here too:
	## a weekday alone cannot say how many days have passed.
	if _lucky_number_days_left > 0:
		_lucky_number_days_left -= 1
		did_change = true
	if random != null:
		var next_timer: int = _kenji_break_timer
		if next_timer == 0:
			next_timer = kenji_break_countdown(random)
		else:
			next_timer -= 1
			if next_timer == 0:
				next_timer = kenji_break_countdown(random)
		if next_timer != _kenji_break_timer:
			_kenji_break_timer = next_timer
			did_change = true
	if did_change:
		changed.emit()
	return did_change


## `SampleKenjiBreakCountdown`: `Random` masked to two bits, plus three, so
## three to six days.
static func kenji_break_countdown(random: RandomNumberGenerator) -> int:
	return (random.randi() & 0x3) + 3


func kenji_break_timer() -> int:
	return _kenji_break_timer


func set_kenji_break_timer(days: int) -> void:
	var next: int = clampi(days, 0, 0xFF)
	if next == _kenji_break_timer:
		return
	_kenji_break_timer = next
	changed.emit()


func lucky_id_number() -> int:
	return _lucky_id_number


## `sLuckyNumberDay`, which is the day plus one so that a stored zero says the
## number has never been drawn.
func lucky_number_day() -> int:
	return _lucky_number_day


## `LoadOrRegenerateLuckyIDNumber`. `sLuckyNumberDay` holds `wCurDay + 1`, so a
## stored zero is "no number has ever been drawn" rather than "drawn on day
## zero", and a day whose stored value already matches keeps the number it had.
## [param random] is spent only when a new number is drawn, which is the two
## `Random` calls the source makes in that branch alone.
func refresh_lucky_id_number(day: int, random: RandomNumberGenerator) -> bool:
	var stamp: int = (day + 1) & 0xFF
	if _lucky_number_day == stamp:
		return false
	_lucky_number_day = stamp
	## The first roll is the low byte and the second the high one: `c` holds the
	## first and `a`, the second, is stored at `wLuckyIDNumber`, which `PrintNum`
	## reads big-endian.
	var low: int = random.randi() & 0xFF
	var high: int = random.randi() & 0xFF
	_lucky_id_number = ((high << 8) | low) & 0xFFFF
	changed.emit()
	return true


## `_CheckLuckyNumberShowFlag`: `CheckDayDependentEventHL` on
## `wLuckyNumberDayTimer`, which answers carry once the days it was started with
## have passed. The days remaining are stepped by the day rollover rather than
## derived from a stored start day, because this project's clock is a weekday
## and an hour: a seven-day countdown started on a Friday ends on the same
## weekday, which no difference of two weekdays can tell from no time passing.
func lucky_number_show_ready() -> bool:
	return _lucky_number_days_left <= 0


## `RestartLuckyNumberCountdown`: `InitNDaysCountdown` with the days until the
## next Friday, which is seven when today is Friday or Saturday, so the show
## never comes round again on the day it ran.
func restart_lucky_number_countdown(day: int) -> void:
	var until: int = Gen2WorldClock.FRIDAY - posmod(day, Gen2WorldClock.DAYS_PER_WEEK)
	if until <= 0:
		until += Gen2WorldClock.DAYS_PER_WEEK
	_lucky_number_days_left = until
	changed.emit()


func best_magikarp() -> Dictionary:
	return {
		"feet": _best_magikarp_feet,
		"inches": _best_magikarp_inches,
		"ot": _best_magikarp_ot,
	}


func set_best_magikarp(feet: int, inches: int, ot: String) -> void:
	_best_magikarp_feet = clampi(feet, 0, 0xFF)
	_best_magikarp_inches = clampi(inches, 0, 0xFF)
	_best_magikarp_ot = ot
	changed.emit()


func mom_savings_flags() -> int:
	return _mom_savings_flags


func set_mom_savings_flags(flags: int) -> void:
	var next: int = flags & 0xFF
	if next == _mom_savings_flags:
		return
	_mom_savings_flags = next
	changed.emit()


func blue_card_balance() -> int:
	return _blue_card_balance


func mom_item_index() -> int:
	return _mom_item_index


func mom_item_set() -> int:
	return _mom_item_set


func mom_item_trigger_balance() -> int:
	return _mom_item_trigger_balance


## The three written together, because `MomTriesToBuySomething` never moves one
## without the others: the balance climbs while the set is chosen, and the index
## advances only on the ladder.
func set_mom_purchase(index: int, set_number: int, trigger_balance: int) -> void:
	var next_index: int = maxi(index, 0)
	var next_set: int = maxi(set_number, 0)
	var next_balance: int = clampi(trigger_balance, 0, Gen2WorldInventory.MAX_MONEY)
	if next_index == _mom_item_index and next_set == _mom_item_set \
		and next_balance == _mom_item_trigger_balance:
		return
	_mom_item_index = next_index
	_mom_item_set = next_set
	_mom_item_trigger_balance = next_balance
	changed.emit()


func buenas_password() -> int:
	return _buenas_password


func set_buenas_password(password: int) -> void:
	var next: int = password & 0xFF
	if next == _buenas_password:
		return
	_buenas_password = next
	changed.emit()


func set_blue_card_balance(points: int) -> void:
	var next: int = points & 0xFF
	if next == _blue_card_balance:
		return
	_blue_card_balance = next
	changed.emit()


## True unless [param data] is a verified Gold or Silver cache, matching
## `Gen2WorldScriptRunner._crystal_commands()`. Both engine flag tables and
## `_GetVarAction.CountBadges` agree except on this table's offset, so every
## profile-dependent flag lookup keys off the question the script command-width
## split already answers. A null cache answers Crystal; a caller holding only an
## id asks [method is_crystal_game_id], which knows "not told" from "told Gold".
static func is_crystal_profile(data: GameData) -> bool:
	return data == null or is_crystal_game_id(data.id)


## The same question off a cartridge id rather than an open cache. A save carries
## one and a mod may have no [GameData] at all, so this is what keeps a Gold save
## from being read through Crystal's tables.
static func is_crystal_game_id(id: StringName) -> bool:
	return id != &"gold" and id != &"silver"


## The source resets its first eight event flags whenever a map reloads. These
## flags are used for temporary movement and scene branches, so they are not
## part of a permanent story save.
func reset_map_reload_flags() -> bool:
	var did_change: bool = false
	for flag: int in TEMPORARY_MAP_RELOAD_FLAGS:
		if not _event_flags.has(flag):
			continue
		_event_flags.erase(flag)
		did_change = true
	if did_change:
		changed.emit()
	return did_change


func item_quantity(item: int) -> int:
	return int(_items.get(item, 0))


func items() -> Dictionary:
	return _items.duplicate()


func pc_item_quantity(item: int) -> int:
	return int(_pc_items.get(item, 0))


func pc_items() -> Dictionary:
	return _pc_items.duplicate()


func money(account: int = 0) -> int:
	return int(_money.get(account, 0))


func money_balances() -> Dictionary:
	return _money.duplicate()


func coins() -> int:
	return _coins


func phone_contacts() -> Dictionary:
	return _phone_contacts.duplicate()


func phone_contact_count() -> int:
	return _phone_contacts.size()


func has_phone_contact(contact: int) -> bool:
	return bool(_phone_contacts.get(contact, false))


func phone_receive_cycle() -> int:
	return _phone_receive_cycle


func phone_receive_minutes() -> int:
	return _phone_receive_minutes


func pending_special_phone_call() -> int:
	return _pending_special_phone_call


## The byte a script memory address holds. An address never written reads zero,
## the way the cartridge's cleared WRAM does.
func script_memory(address: int) -> int:
	return int(_script_memory.get(address, 0))


func script_memory_values() -> Dictionary:
	return _script_memory.duplicate()


func reset_phone_receive_delay() -> void:
	_phone_receive_cycle = 0
	_phone_receive_minutes = PHONE_RECEIVE_DELAYS[0]
	changed.emit()


func advance_phone_receive_timer(minutes: int) -> bool:
	if _phone_receive_minutes <= 0:
		return false
	var ready: bool = false
	for _minute: int in maxi(0, minutes):
		_phone_receive_minutes = maxi(0, _phone_receive_minutes - 1)
		if _phone_receive_minutes > 0:
			continue
		ready = true
	if ready:
		changed.emit()
	return ready


func phone_receive_ready() -> bool:
	return _phone_receive_minutes <= 0


func consume_phone_receive_timer() -> bool:
	if not phone_receive_ready():
		return false
	_phone_receive_cycle = mini(_phone_receive_cycle + 1, PHONE_RECEIVE_DELAYS.size() - 1)
	_phone_receive_minutes = PHONE_RECEIVE_DELAYS[_phone_receive_cycle]
	changed.emit()
	return true


func set_pending_special_phone_call(call_id: int) -> bool:
	var next_call_id: int = maxi(0, call_id)
	if next_call_id == _pending_special_phone_call:
		return false
	_pending_special_phone_call = next_call_id
	changed.emit()
	return true


func just_battled() -> bool:
	return _just_battled


## `wBattleResult`'s BATTLERESULT_BOX_FULL bit, raised by `.SendToPC` when the
## caught Pokemon was the one that filled its box and read by
## `Script_reloadmapafterbattle`, which answers it with Bill on the phone.
## Runtime only, like the byte it models: `wBattleResult` is scratch, so a save
## reloaded after such a catch owes no call.
func battle_caught_celebi() -> bool:
	return _battle_caught_celebi


func set_battle_caught_celebi(caught: bool) -> void:
	if caught == _battle_caught_celebi:
		return
	_battle_caught_celebi = caught
	changed.emit()


func battle_box_full() -> bool:
	return _battle_box_full


func set_battle_box_full(full: bool) -> void:
	if full == _battle_box_full:
		return
	_battle_box_full = full
	changed.emit()


## `wMapMusic`: the track that is playing, not the track the current map asks
## for. The two differ whenever a radio station is tuned.
func used_flash() -> bool:
	return _used_flash


## `BlindingFlash`'s own `set STATUSFLAGS_FLASH_F`.
func set_used_flash(value: bool) -> void:
	if _used_flash == value:
		return
	_used_flash = value
	changed.emit()


## `ResetFlashIfOutOfCave`, called on entering a map: only a route or a town puts
## the light out, so walking from one cave room into another keeps it.
func clear_flash_if_outdoors(environment: int) -> void:
	if Gen2WorldPhoneHost.is_outside_environment(environment):
		set_used_flash(false)


func map_music() -> int:
	return _map_music


func set_map_music(music: int) -> void:
	var next_music: int = maxi(0, music)
	if next_music == _map_music:
		return
	_map_music = next_music
	changed.emit()


## PlayMapMusic: a map that asks for the track already playing does not restart
## it, which is what makes crossing a route boundary one continuous piece and
## what keeps a tuned station playing across a map reload. Answers whether the
## track changed, so a caller knows whether to restart playback.
func play_map_music(music: int) -> bool:
	if maxi(0, music) == _map_music:
		return false
	set_map_music(music)
	return true


func radio_knob() -> int:
	return _radio_knob


## Clamped and snapped to the source's own two-step dial.
func last_dex_mode() -> int:
	return _last_dex_mode


## `.exit`'s `ld a, [wCurDexMode]; ld [wLastDexMode], a`. A mode outside the
## three the listing can be in is refused rather than stored: the fourth,
## DEXMODE_UNOWN, is the Unown dex, which never becomes `wCurDexMode`.
func set_last_dex_mode(mode: int) -> void:
	if mode not in [
		RomLayout.DEXMODE_NEW, RomLayout.DEXMODE_OLD, RomLayout.DEXMODE_ABC,
	] or mode == _last_dex_mode:
		return
	_last_dex_mode = mode
	changed.emit()


func set_radio_knob(knob: int) -> void:
	var next_knob: int = clampi(knob, Gen2WorldRadio.KNOB_MIN, Gen2WorldRadio.KNOB_MAX)
	next_knob -= next_knob % Gen2WorldRadio.KNOB_STEP
	if next_knob == _radio_knob:
		return
	_radio_knob = next_knob
	changed.emit()


## `wCurRadioLine`, or -1 while the dial sits on dead air.
func radio_channel() -> int:
	return _radio_channel


func set_radio_channel(channel: int) -> void:
	var next_channel: int = channel if channel >= 0 else -1
	if next_channel == _radio_channel:
		return
	_radio_channel = next_channel
	changed.emit()


func wild_encounter_cooldown() -> int:
	return _wild_encounter_cooldown


## `SetUpFiveStepWildEncounterCooldown`'s own write, which `EnterMap` makes on
## every map entry, `reloadmapafterbattle` included.
const WILD_ENCOUNTER_COOLDOWN_STEPS: int = 5


func set_wild_encounter_cooldown(steps: int) -> void:
	var next_steps: int = clampi(steps, 0, 0xFF)
	if next_steps == _wild_encounter_cooldown:
		return
	_wild_encounter_cooldown = next_steps
	changed.emit()


## `CheckWildEncounterCooldown`: zero lets the step through, and so does the step
## that takes the counter to zero. Answers whether this step is blocked.
func consume_wild_encounter_cooldown() -> bool:
	if _wild_encounter_cooldown <= 0:
		return false
	_wild_encounter_cooldown -= 1
	changed.emit()
	return _wild_encounter_cooldown > 0


## `ENGINE_BUG_CONTEST_TIMER`, the flag `Route35NationalParkGate` sets on the
## way in and `BugContestResultsWarpScript` clears on the way out. It is
## `wStatusFlags2`' own bit, so it sits past `ENGINE_MOBILE_SYSTEM` and shifts on
## Gold and Silver like every other flag there.
const ENGINE_BUG_CONTEST_TIMER: int = 17
## `ENGINE_SAFARI_ZONE`, the next entry of the same `wStatusFlags2` run.
## `WarpToSpawnPoint` clears it beside the contest timer, and nothing in either
## pin sets it: Gen 2 ships no Safari Zone.
const ENGINE_SAFARI_ZONE: int = 18
## Five entries further down the same run (data/events/engine_flags.asm), so it
## shifts on Gold and Silver the way every flag past ENGINE_MOBILE_SYSTEM does.
const ENGINE_REACHED_GOLDENROD: int = 22
## The last entry of the same run, which `GetMapMusic` reads in Mahogany Mart.
const ENGINE_ROCKETS_IN_MAHOGANY: int = 23
## `ENGINE_DAILY_BUG_CONTEST`, the once-a-day flag the officer checks.
const ENGINE_DAILY_BUG_CONTEST: int = 81
## `BugCatchingContestantEventFlagTable`, whose ten entries are the same numbers
## in both pins. A set flag is a contestant who is not in this contest.
const EVENT_BUG_CATCHING_CONTESTANT_FIRST: int = 1814


## [param crystal] the way every other profile-shifted flag takes it: the state
## holds no GameData of its own, so the caller resolves the profile.
func bug_contest_active(crystal: bool = true) -> bool:
	return is_engine_flag_active(engine_flag(ENGINE_BUG_CONTEST_TIMER, crystal))


## `STATUSFLAGS2_REACHED_GOLDENROD_F`, the fifth entry of the same `wStatusFlags2`
## run: `GivePokerusAndConvertBerries` gates both of its halves on it, so neither
## Pokerus nor BERRY JUICE exists before Goldenrod has been walked into once.
func reached_goldenrod(crystal: bool = true) -> bool:
	return is_engine_flag_active(engine_flag(ENGINE_REACHED_GOLDENROD, crystal))


func park_balls() -> int:
	return _park_balls


func set_park_balls(count: int) -> void:
	var next_count: int = clampi(count, 0, 0xFF)
	if next_count == _park_balls:
		return
	_park_balls = next_count
	changed.emit()


## The clock `StartBugContestTimer` copied, as `{day, hour, minute}`, or an empty
## Dictionary when no contest has been started.
func bug_contest_started() -> Dictionary:
	return _bug_contest_started.duplicate()


func set_bug_contest_started(clock: Dictionary) -> void:
	_bug_contest_started = _clock_dict(clock)
	changed.emit()


static func _clock_dict(clock: Dictionary) -> Dictionary:
	if clock.is_empty():
		return {}
	return {
		"day": int(clock.get("day", 0)),
		"hour": int(clock.get("hour", 0)),
		"minute": int(clock.get("minute", 0)),
	}


func contest_mon() -> Dictionary:
	return _contest_mon.duplicate()


func set_contest_mon(mon: Dictionary) -> void:
	_contest_mon = mon.duplicate() if int(mon.get("species", 0)) > 0 else {}
	changed.emit()


func contest_second_party_species() -> int:
	return _contest_second_party_species


func set_contest_second_party_species(species: int) -> void:
	var next_species: int = clampi(species, 0, 0xFF)
	if next_species == _contest_second_party_species:
		return
	_contest_second_party_species = next_species
	changed.emit()


## `SelectRandomBugContestContestants`' own flags, as `{index: true}`.
func withdrawn_bug_contestants() -> Dictionary:
	var out: Dictionary = {}
	for index: int in Gen2WorldBugContest.NUM_CONTESTANTS:
		if is_event_flag_active(EVENT_BUG_CATCHING_CONTESTANT_FIRST + index):
			out[index] = true
	return out


func wild_encounters_off() -> bool:
	return _wild_encounters_off


func set_wild_encounters_off(value: bool) -> void:
	if _wild_encounters_off == value:
		return
	_wild_encounters_off = value
	changed.emit()


func trainer_sightings_off() -> bool:
	return _trainer_sightings_off


func set_trainer_sightings_off(value: bool) -> void:
	if _trainer_sightings_off == value:
		return
	_trainer_sightings_off = value
	changed.emit()


func repel_steps() -> int:
	return _repel_steps


## Whether a step has taken an active Repel to zero and nobody has spent the
## fact yet. Held rather than cleared by the read, so an offer that lands on a
## step already owned by a warp, a script or a battle waits for one that can
## spend it instead of being lost.
func repel_expired() -> bool:
	return _repel_expired


func clear_repel_expired() -> void:
	_repel_expired = false


func set_repel_steps(steps: int) -> void:
	var next_steps: int = maxi(0, steps)
	if next_steps == _repel_steps:
		return
	_repel_steps = next_steps
	changed.emit()


## The item SELECT uses, or zero for none. `RegisterItem` writes the number and
## `CheckRegisteredItem` clears it again the moment the pack no longer holds it,
## which is why the ownership test lives with the reader rather than here.
func registered_item() -> int:
	return _registered_item


func set_registered_item(item: int) -> void:
	var next_item: int = item if item > 0 else 0
	if next_item == _registered_item:
		return
	_registered_item = next_item
	changed.emit()


func kurt_apricorn_quantity() -> int:
	return _kurt_apricorn_quantity


func set_kurt_apricorn_quantity(quantity: int) -> void:
	var next_quantity: int = clampi(quantity, 0, 0xFF)
	if next_quantity == _kurt_apricorn_quantity:
		return
	_kurt_apricorn_quantity = next_quantity
	changed.emit()


func fruit_tree_picked(tree_id: int) -> bool:
	return bool(_picked_fruit_trees.get(tree_id, false))


func picked_fruit_trees() -> Dictionary:
	return _picked_fruit_trees.duplicate()


## `TradeFlagAction`'s CHECK_FLAG over `wTradeFlags`.
func npc_trade_done(trade_id: int) -> bool:
	return bool(_npc_trades.get(trade_id, false))


## `CountStep`: the two step counters, the Repel countdown, and `StepHappiness`
## on the pass `wStepCount` wraps, once per step the player finishes wherever it
## was taken. `DoRepelStep` stands in front of the counters and the step a Repel
## runs out on reaches `.doscript` with carry, so that step counts for neither
## poison, happiness, an egg nor the Day-Care. Answers whether it was counted.
func count_step() -> bool:
	if _repel_steps > 0:
		_repel_steps -= 1
		if _repel_steps == 0:
			## Where a renewal offer belongs: every way of taking a step reaches
			## CountStep, so this is the only place the edge exists. Runtime
			## only, and never saved: a save reloaded on the step a Repel ended
			## has no offer owed.
			_repel_expired = true
			changed.emit()
			return false
	_poison_step_count = (_poison_step_count + 1) & 0xFF
	_step_count = (_step_count + 1) & 0xFF
	if _step_count == 0:
		_happiness_step_count = (_happiness_step_count + 1) & 1
		if _happiness_step_count == 0:
			_pending_step_happiness += 1
	if _step_count == EGG_STEP_PHASE:
		_pending_egg_steps += 1
	## `farcall DayCareStep` sits after the egg branch and runs on every other
	## step; a step that hatches jumps over it, which the spender settles because
	## only it knows whether an egg came out.
	_pending_day_care_steps += 1
	changed.emit()
	return true


## `DoBikeStep`, which `CountStep` reaches behind the poison branch. The caller
## answers the three gates in front of the counter, since only it knows the map and
## the player's state: [param armed] is `STATUSFLAGS2_BIKE_SHOP_CALL_F` and the
## bike, and [param in_service] is `GetMapPhoneService`. The counter saturates at
## `$ffff` rather than wrapping, which is what the two `cp 255` tests do, and the
## call is queued the first counted step past 1024 that finds no other special call
## already waiting.
func do_bike_step(armed: bool, in_service: bool) -> bool:
	if not armed or not in_service:
		return false
	if _bike_step < MAX_BIKE_STEP:
		_bike_step += 1
		changed.emit()
	if _bike_step < BIKE_SHOP_CALL_STEPS:
		return false
	## `.NoCall`: a call already queued is not overwritten, and the flag stays
	## set so the next step tries again.
	if _pending_special_phone_call != 0:
		return false
	_pending_special_phone_call = SPECIALCALL_BIKESHOP
	changed.emit()
	return true


func bike_step() -> int:
	return _bike_step


func step_count() -> int:
	return _step_count


func poison_step_count() -> int:
	return _poison_step_count


## `CountStep`'s `ld [hl], 0`, which runs on the pass that reached the compare
## whether or not anything in the party was poisoned.
func clear_poison_step_count() -> void:
	if _poison_step_count == 0:
		return
	_poison_step_count = 0
	changed.emit()


## Takes the owed `StepHappiness` passes and forgets them, so a caller that has
## a party spends each one exactly once.
func take_pending_step_happiness() -> int:
	var owed: int = _pending_step_happiness
	_pending_step_happiness = 0
	return owed


## The same for the owed `DoEggStep` passes.
func take_pending_egg_steps() -> int:
	var owed: int = _pending_egg_steps
	_pending_egg_steps = 0
	return owed


## The same for the owed `DayCareStep` passes. `CountStep` reaches it on every
## step and skips it on the one a `DoEggStep` hatch takes, which is
## `jr nz, .hatch` jumping over the `farcall`.
func take_pending_day_care_steps() -> int:
	var owed: int = _pending_day_care_steps
	_pending_day_care_steps = 0
	return owed


func day_care_man_flags() -> int:
	return _day_care_man


func set_day_care_man_flags(flags: int) -> void:
	var next_flags: int = flags & 0xFF
	if _day_care_man == next_flags:
		return
	_day_care_man = next_flags
	changed.emit()


func day_care_lady_flags() -> int:
	return _day_care_lady


func set_day_care_lady_flags(flags: int) -> void:
	var next_flags: int = flags & 0xFF
	if _day_care_lady == next_flags:
		return
	_day_care_lady = next_flags
	changed.emit()


## Whether the slot holds a Pokemon. The bit is on the man's byte for slot 0 and
## the lady's for slot 1, and both are bit 0.
func day_care_has_mon(slot: int) -> bool:
	if slot == Gen2WorldDayCare.SLOT_MAN:
		return _day_care_man & Gen2WorldDayCare.MAN_HAS_MON != 0
	return _day_care_lady & Gen2WorldDayCare.LADY_HAS_MON != 0


func set_day_care_has_mon(slot: int, held: bool) -> void:
	if slot == Gen2WorldDayCare.SLOT_MAN:
		set_day_care_man_flags(
			(_day_care_man | Gen2WorldDayCare.MAN_HAS_MON) if held
			else (_day_care_man & ~Gen2WorldDayCare.MAN_HAS_MON)
		)
		return
	set_day_care_lady_flags(
		(_day_care_lady | Gen2WorldDayCare.LADY_HAS_MON) if held
		else (_day_care_lady & ~Gen2WorldDayCare.LADY_HAS_MON)
	)


## A copy of the slot's own record, so a caller that raises its experience has to
## put it back through [method set_day_care_mon] and cannot edit the state by
## reference.
func day_care_mon(slot: int) -> Gen2SaveMon:
	if slot < 0 or slot >= _day_care_mons.size():
		return null
	return _copy_mon(_day_care_mons[slot])


func set_day_care_mon(slot: int, mon: Gen2SaveMon) -> void:
	if slot < 0 or slot >= _day_care_mons.size():
		return
	_day_care_mons[slot] = _copy_mon(mon)
	changed.emit()


func steps_to_egg() -> int:
	return _steps_to_egg


func set_steps_to_egg(steps: int) -> void:
	var next_steps: int = steps & 0xFF
	if _steps_to_egg == next_steps:
		return
	_steps_to_egg = next_steps
	changed.emit()


## `wEggMon`, built when the counter starts and handed over when it runs out.
func day_care_egg() -> Gen2SaveMon:
	return _copy_mon(_day_care_egg)


func set_day_care_egg(mon: Gen2SaveMon) -> void:
	_day_care_egg = _copy_mon(mon)
	changed.emit()


func _day_care_mons_dict() -> Array:
	var out: Array = []
	for mon: Variant in _day_care_mons:
		out.append({} if mon == null else (mon as Gen2SaveMon).to_dict())
	return out


static func _copy_mon(mon: Gen2SaveMon) -> Gen2SaveMon:
	return null if mon == null else Gen2SaveMon.from_dict(mon.to_dict())


static func _mon_from_value(raw: Variant) -> Gen2SaveMon:
	if not raw is Dictionary or (raw as Dictionary).is_empty():
		return null
	if int((raw as Dictionary).get("species", 0)) <= 0:
		return null
	return Gen2SaveMon.from_dict(raw)


func swarm_map(kind: int = SWARM_DUNSPARCE) -> Vector2i:
	return _swarm_maps[clampi(kind, SWARM_DUNSPARCE, SWARM_YANMA)]


func set_swarm_map(
	map_id: Vector2i, active: bool = true, fishing_species: int = 0,
	kind: int = SWARM_DUNSPARCE,
) -> void:
	var slot: int = clampi(kind, SWARM_DUNSPARCE, SWARM_YANMA)
	var next_map: Vector2i = map_id if active else Vector2i(-1, -1)
	var next_species: int = fishing_species if fishing_species in [0, 0xD3, 0xDF] else 0
	if _swarm_maps[slot] == next_map and _fishing_swarm_species == next_species:
		return
	_swarm_maps[slot] = next_map
	_fishing_swarm_species = next_species
	changed.emit()


## `_SwarmWildmonCheck` tries Dunsparce and then Yanma, so two swarms stand at
## once and whichever names this map answers.
func swarm_active_on(map_group: int, map_number: int) -> bool:
	return _swarm_maps.has(Vector2i(map_group, map_number))


func fishing_swarm_species() -> int:
	return _fishing_swarm_species


func ensure_roaming_mons(source: Array) -> void:
	if not _roaming_mons.is_empty() or source.is_empty():
		return
	_roaming_mons = _copy_roaming_mons(source)
	changed.emit()


func roaming_mons() -> Array:
	return _copy_roaming_mons(_roaming_mons)


func roaming_mons_on(map_group: int, map_number: int) -> Array:
	var out: Array = []
	for index: int in _roaming_mons.size():
		var mon: Dictionary = _roaming_mons[index]
		if int(mon.get("species", 0)) <= 0:
			continue
		if int(mon.get("map_group", -1)) != map_group or int(mon.get("map_number", -1)) != map_number:
			continue
		var value: Dictionary = mon.duplicate(true)
		value["index"] = index
		out.append(value)
	return out


func has_caught_species(species: int) -> bool:
	return species > 0 and bool(_caught_species.get(species, false))


func caught_species() -> Dictionary:
	return _caught_species.duplicate()


## `CountSetBits` over wPokedexCaught, which is the number the trainer card
## prints and `_GetVarAction`'s dex-count variables read.
func caught_count() -> int:
	return _caught_species.size()


func seen_count() -> int:
	return _seen_species.size()


## `SetSeenAndCaughtMon` sets the caught flag and then falls through into
## `SetSeenMon`, so catching also marks seen and no caller does both.
func set_species_caught(species: int, caught: bool = true) -> void:
	if species <= 0:
		return
	if caught:
		_caught_species[species] = true
		set_species_seen(species, true)
	else:
		_caught_species.erase(species)


## `UpdateUnownDex`: appends the form unless it is already listed. The walk stops
## at the first empty slot, so a form only reaches the end of the list and a full
## twenty-six writes nothing. Its caller is the limit rather than the routine:
## `GeneratePartyMonStats` runs it only for a PARTYMON, so an Unown sent straight
## to the PC is caught without entering the dex.
func update_unown_dex(form: int) -> void:
	if form < 1 or form > RomLayout.UNOWN_FORMS:
		return
	## `.registerunowndex`'s own tail: the `wFirstUnownSeen` write sits behind the
	## `UpdateUnownDex` call and runs whether or not the form was new.
	note_first_unown_seen(form)
	if form in _unown_dex or _unown_dex.size() >= RomLayout.UNOWN_FORMS:
		return
	_unown_dex.append(form)


## The three `wFirstUnownSeen` writes, which are one test: a letter is stored
## only while the byte is still zero, so the first Unown the save meets is the
## one every dex entry is drawn as.
func note_first_unown_seen(form: int) -> void:
	if _first_unown_seen != 0 or form < 1 or form > RomLayout.UNOWN_FORMS:
		return
	_first_unown_seen = form
	changed.emit()


func first_unown_seen() -> int:
	return _first_unown_seen


## The forms caught, in catching order. `Pokedex_DrawUnownModeBG` walks exactly
## this and stops at the first empty slot.
func unown_dex() -> Array[int]:
	return _unown_dex.duplicate()


## `_GetVarAction.UnownCaught`, which is `VAR_UNOWNCOUNT`.
func unown_caught_count() -> int:
	return _unown_dex.size()


func has_seen_species(species: int) -> bool:
	return species > 0 and bool(_seen_species.get(species, false))


func seen_species() -> Dictionary:
	return _seen_species.duplicate()


## Clearing drops the entry rather than storing false, so the dictionary holds
## only what has been seen and round-trips through a snapshot unchanged.
func set_species_seen(species: int, seen: bool = true) -> void:
	if species <= 0:
		return
	if seen:
		_seen_species[species] = true
	else:
		_seen_species.erase(species)


## `UpdateRoamMons`: each active roamer walks one step of the connection graph.
## [param player_map] is `wMapGroup`/`wMapNumber`, the map being entered.
func advance_roaming(
	map_rows: Array, random: RandomNumberGenerator = null,
	player_map: Vector2i = Vector2i(ROAM_MAP_N_A, ROAM_MAP_N_A)
) -> Array:
	return _walk_roaming(map_rows, random, player_map, false)


## `JumpRoamMons`, run by Fly, Teleport and a Continue: every active roamer
## takes `JumpRoamMon` straight and none follows a connection.
func jump_roaming(
	map_rows: Array, random: RandomNumberGenerator = null,
	player_map: Vector2i = Vector2i(ROAM_MAP_N_A, ROAM_MAP_N_A)
) -> Array:
	return _walk_roaming(map_rows, random, player_map, true)


func _walk_roaming(
	map_rows: Array, random: RandomNumberGenerator, player_map: Vector2i, jump: bool
) -> Array:
	if _roaming_mons.is_empty() or map_rows.is_empty():
		return []
	## A schedule tick is stateful even when no mon moves: every failed attempt
	## consumes draws. Refuse the operation without a caller-owned stream rather
	## than introducing an unrepeatable random source inside persistent state.
	if random == null:
		return []
	var moved: Array = []
	var changed_state: bool = false
	for index: int in _roaming_mons.size():
		var mon: Dictionary = _roaming_mons[index]
		var current := Vector2i(int(mon.get("map_group", -1)), int(mon.get("map_number", -1)))
		## `cp GROUP_N_A / jr z`: a roamer caught or defeated is skipped, and
		## skipping it spends none of the draws it would have made.
		if current.x == ROAM_MAP_N_A:
			continue
		var step: Dictionary = _roam_jump(map_rows, player_map, random) if jump \
			else _roaming_target(map_rows, current, player_map, random)
		var target: Vector2i = step.get("to", Vector2i(ROAM_MAP_N_A, ROAM_MAP_N_A))
		if target == Vector2i(ROAM_MAP_N_A, ROAM_MAP_N_A) or target == current:
			continue
		mon["map_group"] = target.x
		mon["map_number"] = target.y
		changed_state = true
		moved.append({
			"index": index,
			"species": int(mon.get("species", 0)),
			"from": current,
			"to": target,
			## `.Update` jumps on a zero in its five-bit mask, so a connection
			## walk still scatters about one pass in thirty-two.
			"jumped": bool(step.get("jumped", false)),
		})
	_back_up_map_indices(player_map)
	if changed_state:
		changed.emit()
	return moved


## `_BackUpMapIndices`, which both roaming routines end on. `.Update` refuses to
## walk onto the Last pair, which is the player's map one roaming update ago.
func _back_up_map_indices(player_map: Vector2i) -> void:
	_roam_last_map = _roam_cur_map
	_roam_cur_map = player_map


static func map_scene_key(map_group: int, map_number: int) -> String:
	return "%d:%d" % [map_group, map_number]


func map_scene(map_group: int, map_number: int) -> int:
	return int(_map_scenes.get(map_scene_key(map_group, map_number), 0))


func map_scenes() -> Dictionary:
	return _map_scenes.duplicate()


## Every entry point for a roaming record funnels through here: the constructor,
## ensure_roaming_mons(), restore() and roaming_mons(). The importer writes these
## four fields as integers, but a cache or snapshot round-trips through JSON,
## where they come back as floats, so they are normalized once on the way in
## rather than at each read.
func _copy_roaming_mons(source: Array) -> Array:
	var out: Array = []
	for raw: Variant in source:
		if raw is Dictionary:
			var mon: Dictionary = (raw as Dictionary).duplicate(true)
			for field: String in ["species", "level", "map_group", "map_number", "hp", "dvs"]:
				if mon.has(field):
					mon[field] = int(mon[field])
			out.append(mon)
	return out


## `BattleEnd_HandleRoamMons`, which every roaming battle ends through. A win,
## the source's word for caught or defeated alike, empties the struct: HP 0, the
## map bytes `GROUP_N_A`/`MAP_N_A` and the species byte 0, so
## `CheckEncounterRoamMon` can never select that slot again. Any other ending
## stores the HP the fight left. [param dvs] is the word `.Roaming` rolled on the
## first encounter and read back after, so a roamer keeps the Pokemon it was.
func note_roam_battle_end(species: int, won: bool, hp: int, dvs: int) -> bool:
	for index: int in _roaming_mons.size():
		var mon: Dictionary = _roaming_mons[index]
		if int(mon.get("species", 0)) != species:
			continue
		if won:
			mon["species"] = 0
			mon["hp"] = 0
			mon["map_group"] = ROAM_MAP_N_A
			mon["map_number"] = ROAM_MAP_N_A
		else:
			## The struct's HP is one byte, and `GetRoamMonHP` stores
			## `wEnemyMonHP + 1` alone: a roamer above 255 HP would wrap, and at
			## level 40 none of the three can reach it.
			mon["hp"] = clampi(hp, 0, 0xFF)
			mon["dvs"] = dvs & 0xFFFF
		changed.emit()
		return true
	return false


## `.Update`: the row for [param current] is found before any roll, so a roamer
## on a map `RoamMaps` does not name spends nothing and stays. A zero in the
## five-bit mask hands it to `JumpRoamMon`; otherwise the low two bits index the
## row's connections, and a target is refused for being `wRoamMons_Last*` rather
## than for being where the roamer stands.
func _roaming_target(
	map_rows: Array, current: Vector2i, player_map: Vector2i, random: RandomNumberGenerator
) -> Dictionary:
	var connections: Array = _roam_connections(map_rows, current)
	if connections.is_empty():
		return {}
	for _attempt: int in ROAM_ROLL_ATTEMPTS:
		var roll: int = random.randi_range(0, 255)
		if (roll & 0x1F) == 0:
			return _roam_jump(map_rows, player_map, random)
		var connection_index: int = roll & 0x03
		if connection_index >= connections.size():
			continue
		var target: Variant = connections[connection_index]
		if not target is Dictionary:
			continue
		var next := Vector2i(
			int((target as Dictionary).get("map_group", ROAM_MAP_N_A)),
			int((target as Dictionary).get("map_number", ROAM_MAP_N_A))
		)
		if next != _roam_last_map:
			return {"to": next, "jumped": false}
	return {}


## `JumpRoamMon`: a uniform index into `RoamMaps`, rerolled while it names the
## map the PLAYER stands on. The roamer's own is not refused.
func _roam_jump(
	map_rows: Array, player_map: Vector2i, random: RandomNumberGenerator
) -> Dictionary:
	var mask: int = 1
	while mask < map_rows.size():
		mask <<= 1
	mask -= 1
	for _attempt: int in ROAM_ROLL_ATTEMPTS:
		var index: int = random.randi_range(0, 255) & mask
		if index >= map_rows.size():
			continue
		var row: Variant = map_rows[index]
		if not row is Dictionary:
			continue
		var jump := Vector2i(
			int((row as Dictionary).get("map_group", ROAM_MAP_N_A)),
			int((row as Dictionary).get("map_number", ROAM_MAP_N_A))
		)
		if jump != player_map:
			return {"to": jump, "jumped": true}
	return {}


func _roam_connections(map_rows: Array, current: Vector2i) -> Array:
	for raw: Variant in map_rows:
		if not raw is Dictionary:
			continue
		if int((raw as Dictionary).get("map_group", ROAM_MAP_N_A)) != current.x \
			or int((raw as Dictionary).get("map_number", ROAM_MAP_N_A)) != current.y:
			continue
		var connections: Variant = (raw as Dictionary).get("connections", [])
		return connections as Array if connections is Array else []
	return []


## Whether [param order] names every key of [param source] exactly once, which
## is the only shape a reorder may have: a list that dropped or repeated a row
## would change what is owned rather than where it sits.
static func _is_permutation(source: Dictionary, order: Array) -> bool:
	if order.size() != source.size():
		return false
	var seen: Dictionary = {}
	for entry: Variant in order:
		var key: int = int(entry)
		if not source.has(key) or seen.has(key):
			return false
		seen[key] = true
	return true


## [param source] rebuilt so its keys come out in [param order]. Insertion order
## is what a pack listing reads, so this is the whole of a reorder.
static func _reordered(source: Dictionary, order: Array) -> Dictionary:
	var result: Dictionary = {}
	for entry: Variant in order:
		var key: int = int(entry)
		result[key] = source[key]
	return result


## An unbounded key, value or capacity in [constant CHANGE_MAPS] and
## [constant CHANGE_SCALARS].
const UNBOUNDED: int = 0x7FFFFFFF
## A change map whose values are bools: a true sets the key, a false erases it.
const MERGE_FLAGS: int = 0
## A change map whose values are counts: a non-zero stores it, a zero erases it.
const MERGE_COUNTS: int = 1

## Every map [method apply_changes] accepts, in the order a bad one is reported:
## the `runtime_changes` key, the member, the merge mode, the smallest and
## largest key, the largest value ([constant UNBOUNDED] for a flag map), the
## reason a non-Dictionary answers with, the reason a bad entry answers with, and
## the capacity the merged map may not pass with the reason it answers with.
const CHANGE_MAPS: Array[Array] = [
	["items", "_items", MERGE_COUNTS, 1, UNBOUNDED, UNBOUNDED,
		&"invalid_items", &"invalid_item_quantity", UNBOUNDED, &""],
	["pc_items", "_pc_items", MERGE_COUNTS, 1, UNBOUNDED, UNBOUNDED,
		&"invalid_pc_items", &"invalid_pc_item_quantity",
		Gen2WorldPack.MAX_PC_ITEMS, &"pc_item_capacity"],
	["engine_flags", "_engine_flags", MERGE_FLAGS, 0, UNBOUNDED, UNBOUNDED,
		&"invalid_engine_flags", &"invalid_engine_flag", UNBOUNDED, &""],
	["money", "_money", MERGE_COUNTS, 0, UNBOUNDED, UNBOUNDED,
		&"invalid_money", &"invalid_money_balance", UNBOUNDED, &""],
	["phone_contacts", "_phone_contacts", MERGE_FLAGS, 0, UNBOUNDED, UNBOUNDED,
		&"invalid_phone_contacts", &"invalid_phone_contact",
		PHONE_CONTACT_CAPACITY, &"phone_contact_capacity"],
	["fruit_trees", "_picked_fruit_trees", MERGE_FLAGS, 1, RomLayout.FRUIT_TREE_COUNT,
		UNBOUNDED, &"invalid_fruit_trees", &"invalid_fruit_trees", UNBOUNDED, &""],
	["npc_trades", "_npc_trades", MERGE_FLAGS, 0, UNBOUNDED, UNBOUNDED,
		&"invalid_npc_trades", &"invalid_npc_trade", UNBOUNDED, &""],
	["seen_species", "_seen_species", MERGE_FLAGS, 1, UNBOUNDED, UNBOUNDED,
		&"invalid_seen_species", &"invalid_seen_species", UNBOUNDED, &""],
	["caught_species", "_caught_species", MERGE_FLAGS, 1, UNBOUNDED, UNBOUNDED,
		&"invalid_caught_species", &"invalid_caught_species", UNBOUNDED, &""],
	["script_memory", "_script_memory", MERGE_COUNTS, 1, UNBOUNDED, 0xFF,
		&"invalid_script_memory", &"invalid_script_memory",
		SCRIPT_MEMORY_CAPACITY, &"script_memory_capacity"],
]

## Every bounded integer `runtime_changes` may carry: the key, the member, the
## largest value and the reason a value outside 0..that answers with.
static var CHANGE_SCALARS: Array[Array] = [
	["coins", "_coins", UNBOUNDED, &"invalid_coins"],
	["phone_receive_cycle", "_phone_receive_cycle", PHONE_RECEIVE_DELAYS.size() - 1,
		&"invalid_phone_receive_cycle"],
	["phone_receive_minutes", "_phone_receive_minutes", UNBOUNDED,
		&"invalid_phone_receive_minutes"],
	["pending_special_phone_call", "_pending_special_phone_call", UNBOUNDED,
		&"invalid_special_phone_call"],
	["repel_steps", "_repel_steps", UNBOUNDED, &"invalid_repel_steps"],
	["kurt_apricorn_quantity", "_kurt_apricorn_quantity", 0xFF,
		&"invalid_kurt_apricorn_quantity"],
	["blue_card_balance", "_blue_card_balance", 0xFF, &"invalid_blue_card_balance"],
	["mom_savings_flags", "_mom_savings_flags", 0xFF, &"invalid_mom_savings_flags"],
	["kenji_break_timer", "_kenji_break_timer", 0xFF, &"invalid_kenji_break_timer"],
	["lucky_number_days_left", "_lucky_number_days_left", 0xFF,
		&"invalid_lucky_number_timer"],
	["lucky_id_number", "_lucky_id_number", 0xFFFF, &"invalid_lucky_id_number"],
	["lucky_number_day", "_lucky_number_day", 0xFF, &"invalid_lucky_number_day"],
]

## The members a pack listing reads in insertion order, so the same quantities in
## another order still count as a change.
const ORDERED_MEMBERS: Array[String] = ["_items", "_pc_items"]


## [param source] merged with [param changes] under [constant MERGE_FLAGS] or
## [constant MERGE_COUNTS].
static func _merged(source: Dictionary, changes: Dictionary, mode: int) -> Dictionary:
	var out: Dictionary = source.duplicate()
	for raw_key: Variant in changes:
		var key: int = int(raw_key)
		var value: int = int(changes[raw_key]) if mode == MERGE_COUNTS else int(bool(changes[raw_key]))
		if value == 0:
			out.erase(key)
		elif mode == MERGE_FLAGS:
			out[key] = true
		else:
			out[key] = value
	return out


## Why [param changes] is not a map of keys in [param low]..[param high] with
## values in 0..[param ceiling], or an empty name when it is.
static func _map_reason(
	changes: Dictionary, low: int, high: int, ceiling: int, reason: StringName
) -> StringName:
	for raw_key: Variant in changes:
		var key: int = int(raw_key)
		if key < low or key > high:
			return reason
		var value: int = int(changes[raw_key])
		if value < 0 or value > ceiling:
			return reason
	return &""


## Applies a script's staged state as one transaction. Nothing is replaced until
## every field validates, so a failed script cannot leave half a flag transition
## behind.
func apply_changes(
	flag_changes: Dictionary, scene_changes: Dictionary, runtime_changes: Dictionary = {}
) -> Dictionary:
	var next: Dictionary = {}
	var reason: StringName = _stage_changes(
		flag_changes, scene_changes, runtime_changes, next
	)
	if reason != &"":
		return {"ok": false, "reason": reason}

	var did_change: bool = false
	for member: String in next:
		var current: Variant = get(member)
		if current != next[member]:
			did_change = true
		elif member in ORDERED_MEMBERS and current.keys() != (next[member] as Dictionary).keys():
			did_change = true
		set(member, next[member])
	if did_change:
		changed.emit()
	return {"ok": true, "changed": did_change}


## Fills [param next] with the member values [method apply_changes] would commit,
## or answers why it may not.
func _stage_changes(
	flag_changes: Dictionary, scene_changes: Dictionary, runtime_changes: Dictionary,
	next: Dictionary
) -> StringName:
	for raw_flag: Variant in flag_changes:
		if int(raw_flag) < 0:
			return &"invalid_event_flag"
	next["_event_flags"] = _merged(_event_flags, flag_changes, MERGE_FLAGS)

	var next_scenes: Dictionary = _map_scenes.duplicate()
	for raw_map: Variant in scene_changes:
		if String(raw_map).is_empty() or int(scene_changes[raw_map]) < 0:
			return &"invalid_scene"
		next_scenes[String(raw_map)] = int(scene_changes[raw_map])
	next["_map_scenes"] = next_scenes

	for row: Array in CHANGE_MAPS:
		var changes: Variant = runtime_changes.get(row[0], {})
		if not changes is Dictionary:
			return row[6]
		var row_reason: StringName = _map_reason(changes, row[3], row[4], row[5], row[7])
		if row_reason != &"":
			return row_reason
		var merged: Dictionary = _merged(get(row[1]), changes, row[2])
		if merged.size() > int(row[8]):
			return row[9]
		next[row[1]] = merged
	## `SetSeenAndCaughtMon` sets both bits, so a species newly caught is seen
	## whatever the caller passed.
	var caught: Dictionary = runtime_changes.get("caught_species", {})
	for raw_species: Variant in caught:
		if bool(caught[raw_species]):
			(next["_seen_species"] as Dictionary)[int(raw_species)] = true

	var order_reason: StringName = _stage_orders(runtime_changes, next)
	if order_reason != &"":
		return order_reason

	for row: Array in CHANGE_SCALARS:
		var value: int = int(runtime_changes.get(row[0], get(row[1])))
		if value < 0 or value > int(row[2]):
			return row[3]
		next[row[1]] = value
	next["_just_battled"] = bool(runtime_changes.get("just_battled", _just_battled))

	var swarm_reason: StringName = _stage_swarm(runtime_changes, next)
	if swarm_reason != &"":
		return swarm_reason
	return _stage_magikarp(runtime_changes, next)


## `SwitchItemsInBag`'s whole effect: the same items in another order. A quantity
## map compares equal whatever order it holds, so a reorder has to be asked for
## by name.
func _stage_orders(runtime_changes: Dictionary, next: Dictionary) -> StringName:
	for row: Array in [
		["item_order", "_items", &"invalid_item_order"],
		["pc_item_order", "_pc_items", &"invalid_pc_item_order"],
	]:
		var order: Variant = runtime_changes.get(row[0], null)
		if order == null:
			continue
		if not order is Array or not _is_permutation(next[row[1]], order):
			return row[2]
		next[row[1]] = _reordered(next[row[1]], order)
	return &""


## The Dunsparce and Yanma swarm maps and the fishing swarm that shares their
## script. An inactive swarm clears its map rather than carrying one nothing
## reads.
func _stage_swarm(runtime_changes: Dictionary, next: Dictionary) -> StringName:
	var maps: Array[Vector2i] = _swarm_maps.duplicate()
	next["_swarm_maps"] = maps
	next["_fishing_swarm_species"] = _fishing_swarm_species
	var change: Variant = runtime_changes.get("swarm", null)
	if change == null:
		return &""
	if not change is Dictionary:
		return &"invalid_swarm"
	var swarm: Dictionary = change
	var active: bool = bool(swarm.get("active", true))
	var group: int = int(swarm.get("map_group", -1))
	var number: int = int(swarm.get("map_number", -1))
	if active and (group < 0 or number < 0):
		return &"invalid_swarm_map"
	var species: int = int(swarm.get("fishing_species", 0))
	if species not in [0, 0xD3, 0xDF]:
		return &"invalid_fishing_swarm_species"
	var kind: int = int(swarm.get("kind", SWARM_DUNSPARCE))
	if kind != SWARM_DUNSPARCE and kind != SWARM_YANMA:
		return &"invalid_swarm_kind"
	maps[kind] = Vector2i(group, number) if active else Vector2i(-1, -1)
	next["_fishing_swarm_species"] = species
	return &""


## `sBestMagikarpLength`: feet, inches and the trainer who caught it, written
## together or not at all.
func _stage_magikarp(runtime_changes: Dictionary, next: Dictionary) -> StringName:
	next["_best_magikarp_feet"] = _best_magikarp_feet
	next["_best_magikarp_inches"] = _best_magikarp_inches
	next["_best_magikarp_ot"] = _best_magikarp_ot
	var change: Variant = runtime_changes.get("best_magikarp", null)
	if change == null:
		return &""
	if not change is Dictionary:
		return &"invalid_best_magikarp"
	var feet: int = int((change as Dictionary).get("feet", 0))
	var inches: int = int((change as Dictionary).get("inches", 0))
	if feet < 0 or feet > 0xFF or inches < 0 or inches > 0xFF:
		return &"invalid_best_magikarp"
	next["_best_magikarp_feet"] = feet
	next["_best_magikarp_inches"] = inches
	next["_best_magikarp_ot"] = String((change as Dictionary).get("ot", ""))
	return &""
