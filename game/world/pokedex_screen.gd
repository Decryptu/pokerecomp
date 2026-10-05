class_name Gen2PokedexScreen
extends Control

## The Pokedex (engine/pokedex/pokedex.asm), embedded in the overworld like the
## start menu and drawn on the hardware's own tile grid: [Gen2Pokedex] owns the
## listing, the cursor and the mode and [Gen2PokedexPage] the picture. AREA is
## `Pokedex_GetArea`'s own region map, so it opens [Gen2TownMapScreen]. PRNT has
## no printer to talk to and ends on the connection error.

## Set by [method open_entry]: `NewPokedexEntry` has no listing behind it, so B
## on the entry closes the dex rather than going back to one.
var _entry_only: bool = false

signal closed  ## Emitted on B from the listing, which is where `DEXSTATE_EXIT` lands.

## Every entry page's load (`PlayMonCry` / `PlayCry`) and the CRY button; the
## overworld's player answers it, as for a script's cry.
signal cry_requested(species: int)

## `PlaySFX`: the changing-modes message's, the exit's and Generation 1's page turn.
signal sfx_requested(index: int)

## The printer's music for as long as PRNT's error box is up.
signal printer_music_requested(on: bool)

enum Mode { LIST, ENTRY, OPTION, SEARCH, SEARCH_RESULTS, AREA, UNOWN, SIDE, PRINT }

## The dex is drawn in hardware pixels and the start menu it opens over is
## ordinary UI at window resolution, so it carries a [Gen2Screen] of its own the
## way [Gen2TownMapScreen] does.

## `Pokedex_BlinkArrowCursor` counts its own frames and shows the arrow on the
## eight it is off `$8`, so the cursor is up for eight frames and down for eight.
const CURSOR_BLINK_FRAMES: int = 8

## `Pokedex_DisplayChangingModesMessage`'s two `ld c, 64` / `call DelayFrames`,
## with `SFX_CHANGE_DEX_MODE` played between them.
const CHANGING_MODES_FRAMES: int = 64

## `AnimateDexSearchSlowpoke`: twenty-five steps of seven frames each, then
## thirty-two more with the Slowpoke back on its first frame. The whole run is
## spent between BEGIN SEARCH and the results, the way the source spends it.
const _SEARCH_ANIMATION_FRAMES: int = \
	Gen2PokedexPage.SLOWPOKE_STEPS * Gen2PokedexPage.SLOWPOKE_FRAME_HOLD
const SEARCH_FRAMES: int = _SEARCH_ANIMATION_FRAMES + Gen2PokedexPage.SLOWPOKE_SETTLE
const TYPE_NOT_FOUND_FRAMES: int = 0x80  ## `Pokedex_DisplayTypeNotFoundMessage`'s own `ld c, $80`.

## `DexEntryScreen_ArrowCursorData`'s four positions, in its own order.
const ENTRY_BUTTONS: Array[String] = ["PAGE", "AREA", "CRY", "PRNT"]
const ENTRY_BUTTON_PAGE: int = 0
const ENTRY_BUTTON_AREA: int = 1
const ENTRY_BUTTON_CRY: int = 2
const ENTRY_BUTTON_PRNT: int = 3

## Frames from one input read to the next, measured with PyBoy on Crystal (Gold
## is within two). The screen draws on the press and then reads no pad for the
## gap ([method Gen2InputRuntime.stall]). Opening from START adds `Pokedex` and
## `InitPokedex`'s 24 to `Pokedex_InitMainScreen`'s 40.
const OPEN_FRAMES: int = 64
const LISTING_FRAMES: int = 41
const LISTING_MOVE_FRAMES: int = 16
## Frames behind `PlayMonCry` on a new entry page and on a step to the next.
const ENTRY_OPEN_FRAMES: int = 13
const ENTRY_STEP_FRAMES: int = 23
const PAGE_FRAMES: int = 6
const OPTION_FRAMES: int = 14
const SEARCH_OPEN_FRAMES: int = 13
const AREA_FRAMES: int = 35
const AREA_BACK_FRAMES: int = 23
const PRINT_BACK_FRAMES: int = 25

## `wDexArrowCursorDelayCounter`'s `ld a, 12`: repeats are ignored for this long
## after the arrow moves; a fresh press always moves.
const ARROW_CURSOR_DELAY_FRAMES: int = 12

var _dex: Gen2Pokedex = null
var _world: Gen2WorldAPI = null
var _data: GameData = null
## `Pokedex_InitDexEntryScreen`'s `LowVolume` holds through AREA and PRNT: only the
## way back to the listing calls `MaxVolume`.
var _mode: Mode = Mode.LIST:
	set(value):
		if _low_volume_mode(value) != _low_volume_mode(_mode):
			Gen2AudioPlayer.hold_low_volume(_low_volume_mode(value))
		_mode = value
## `ShowPokedexMenu` is a listing, a side menu and an entry page and none of the
## other five states, so every branch below reads this rather than the cache.
var _gen1: bool = false
## `HandlePokedexSideMenu`'s `wCurrentMenuItem`, or -1 while that menu is closed.
var _side_cursor: int = -1
## The OPTION screen's own cursor (`wDexArrowCursorPosIndex`), which opens on
## the row matching the current mode.
var _option_cursor: int = 0
## The entry screen's own `wDexArrowCursorPosIndex`, which
## `Pokedex_ReinitDexEntryScreen` puts back on PAGE for each new entry.
var _entry_cursor: int = 0
## `wPrevDexEntryJumptableIndex`, the listing an entry screen was opened from.
var _entry_from: Mode = Mode.LIST
var _mode_rows: Array = []
## Frames still owed to `Pokedex_DisplayChangingModesMessage`. The routine is a
## pair of blocking `DelayFrames`, so nothing else on this screen runs while it
## is above zero, the arrow's own blink included.
var _changing_modes_frames: int = 0
## Frames still owed to `AnimateDexSearchSlowpoke`, which holds the search screen
## the same way. Zero whenever no search is being spent.
var _search_frames: int = 0
## What `Pokedex_SearchForMons` answered, held until the animation is spent.
var _search_result: int = 0
## Frames still owed to `Pokedex_DisplayTypeNotFoundMessage`, which holds its own
## two lines up for $80 frames before the search screen is drawn clean again.
var _message_frames: int = 0

var _area: Gen2TownMapScreen = null
## `PlayMonCry`'s and the exit's `WaitSFX`; [member sound_busy] answers whether it
## still sounds, given the wait's watch.
var sound_busy: Callable = Gen2AudioPlayer.sound_wait
var _sound_holding: bool = false
var _sound_watch: Dictionary = {}
var _sound_then: Callable = Callable()
## `wDexArrowCursorDelayCounter`.
var _arrow_delay: int = 0
var _listing_opened: bool = false

var _page: Gen2PokedexPage = null
var _screen: Gen2Screen = null
var _field: Control = null
var _background: TextureRect = null
## `Pokedex_DisplayChangingModesMessage` and `Pokedex_DisplayTypeNotFoundMessage`
## both replace the bottom box's own words; empty means the box says what its
## screen normally says.
var _message: String = ""
## `wDexArrowCursorBlinkCounter`, and the leftover of a hardware frame this
## screen has not counted yet.
var _blink: int = 0
var _read_only: bool = false
var _frame_clock := Gen2WorldAnimation.FrameClock.new()


## Optional the way the trainer card is: without a world, its state or a cache
## carrying the dex order tables there is no listing, so this answers false and
## the caller keeps the start menu open.
func open(data: GameData, world: Gen2WorldAPI, start_entry: int = 0) -> bool:
	_data = data
	_world = world
	if _data == null or _world == null or _world.state == null:
		return false
	## Generation 1 lists the dex numbers themselves, so it needs neither order
	## table; everything else on this screen is behind [member _gen1].
	_gen1 = _data.generation == RomRegistry.GEN1
	if not _gen1 \
		and (_data.dex_order_new().is_empty() or _data.dex_order_alpha().is_empty()):
		return false
	_page = Gen2PokedexPage.from_data(_data)
	if _page == null or not _page.ready():
		return false
	_dex = Gen2Pokedex.open_gen1(_data, _world.state) if _gen1 else Gen2Pokedex.open(
		_data, _world.state, _world.state.last_dex_mode(), start_entry
	)
	if is_inside_tree() and _background != null:
		_open_list_mode()
	return true


## `NewPokedexEntry`, which is the entry page for one species with no listing in
## front of it: `GameCornerPrizeMonCheckDex` and every catch reach the dex this
## way. Answers false when the species has no entry in this cache's order.
func open_entry(data: GameData, world: Gen2WorldAPI, species: int) -> bool:
	if not open(data, world, species):
		return false
	## `ShowPokedexData` is handed a dex number and no listing, so the cursor is
	## put on it rather than sought through an order table.
	if _gen1 and _dex != null:
		_dex.gen1_show(species)
	if _dex == null or _dex.selected_species() != species:
		return false
	_entry_only = true
	if is_inside_tree() and _background != null:
		_open_entry_mode()
	return true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	if _dex != null:
		if _entry_only:
			_open_entry_mode()
		else:
			_open_list_mode()


## `wPrevDexEntry`, so the caller can carry it into the next open() the way the
## cartridge's own byte survives the dex closing.
func previous_entry() -> int:
	return _dex.prev_entry if _dex != null else 0


## Which species the listing's cursor is on, which every screen here draws the
## picture of. A preview and a test read it rather than the model, since the
## screen is what owns the mode.
func selected_species() -> int:
	return _dex.selected_species() if _dex != null else 0


func current_mode() -> Mode:
	return _mode


## Generation 1's side-menu AREA and PRNT sit on the listing, at full volume.
func _low_volume_mode(mode: Mode) -> bool:
	return mode == Mode.ENTRY or (not _gen1 and (mode == Mode.AREA or mode == Mode.PRINT))


func handle_button(button: int) -> bool:
	if _dex == null or _changing_modes_frames > 0 or _search_frames > 0 \
		or _message_frames > 0 or _sound_holding:
		return false
	if _mode == Mode.AREA:
		return _area.handle_button(button)
	match _mode:
		Mode.LIST:
			return _handle_gen1_list(button) if _gen1 else _handle_list(button)
		Mode.SIDE:
			return _handle_gen1_side(button)
		Mode.PRINT:
			return _handle_print(button)
		Mode.ENTRY:
			return _handle_entry(button)
		Mode.OPTION:
			return _handle_option(button)
		Mode.SEARCH:
			return _handle_search(button)
		Mode.SEARCH_RESULTS:
			return _handle_search_results(button)
		Mode.UNOWN:
			return _handle_unown(button)
	return false


## The dex area is the one state here that reads a released button: its SELECT
## shows the player icon only while it is held.
func release_button(button: int) -> void:
	if _mode == Mode.AREA and _area != null:
		_area.release_button(button)


## `Pokedex_UpdateMainScreen`.
func _handle_list(button: int) -> bool:
	match button:
		PokeButton.B:
			_exit()
			return true
		PokeButton.A:
			if _dex.can_open_entry():
				_dex.open_entry()
				_open_entry_mode(Mode.LIST)
			return true
		PokeButton.SELECT:
			_open_option_mode()
			_spend(OPTION_FRAMES)
			return true
		PokeButton.START:
			_open_search_mode()
			_spend(SEARCH_OPEN_FRAMES)
			return true
	return _move_listing(button)


## `Pokedex_UpdateDexEntryScreen`: left and right move the arrow, A takes the
## button, B returns to the listing, up and down step to the next entry.
func _handle_entry(button: int) -> bool:
	if _gen1:
		return _handle_gen1_entry(button)
	if _entry_only:
		return _handle_new_entry(button)
	match button:
		PokeButton.B:
			## `wPrevDexEntryJumptableIndex`, which `Pokedex_UpdateMainScreen`
			## and `Pokedex_UpdateSearchResultsScreen` each write before they
			## open an entry: B goes back to whichever listing that was, not
			## always the main one.
			if _entry_from == Mode.SEARCH_RESULTS:
				_open_search_results_mode()
				return true
			_open_list_mode()
			return true
		PokeButton.A:
			_entry_action()
			return true
		PokeButton.LEFT, PokeButton.RIGHT:
			## `DexEntryScreen_ArrowCursorData` allows left and right only, over
			## four positions, and stops at either end.
			_entry_cursor = _arrow_move(
				_entry_cursor, 1 if button == PokeButton.RIGHT else -1, ENTRY_BUTTONS.size()
			)
			_refresh()
			return true
		PokeButton.UP, PokeButton.DOWN:
			if _dex.step_entry(button):
				## `Pokedex_ReinitDexEntryScreen` calls `Pokedex_InitArrowCursor`,
				## so a new entry opens on PAGE whatever the last one ended on.
				_entry_cursor = 0
				_refresh()
				_play_entry_cry(ENTRY_STEP_FRAMES)
			return true
	return false


func _move_listing(button: int) -> bool:
	if _dex.move_listing(button):
		_refresh()
		_spend(LISTING_MOVE_FRAMES)
	return PokeButton.is_direction(button)


## Reads no pad for [param frames]; see [constant OPEN_FRAMES].
func _spend(frames: int) -> void:
	var input: Gen2InputRuntime = Gen2InputRuntime.instance()
	if input != null and frames > 0:
		input.stall(frames)


## `Pokedex_MoveArrowCursor`: the arrow's row after [param step], unmoved at an
## end or for a repeat inside `Pokedex_ArrowCursorDelay`; a move arms the delay.
func _arrow_move(at: int, step: int, count: int) -> int:
	var to: int = clampi(at + step, 0, count - 1)
	if to == at:
		return at
	var input: Gen2InputRuntime = Gen2InputRuntime.instance()
	if _arrow_delay > 0 and input != null and input.press_is_repeat:
		return at
	_arrow_delay = ARROW_CURSOR_DELAY_FRAMES
	return to


## `NewPokedexEntry` runs no jumptable: `WaitPressAorB_BlinkCursor`, page 2, that
## wait again. A and B are one button and nothing else does anything.
func _handle_new_entry(button: int) -> bool:
	if button != PokeButton.A and button != PokeButton.B:
		return false
	if _dex.page == Gen2Pokedex.PAGE_1:
		_dex.toggle_page()
		_refresh()
		return true
	closed.emit()
	return true


## `DexEntryScreen_MenuActionJumptable`.
func _entry_action() -> void:
	match _entry_cursor:
		ENTRY_BUTTON_PAGE:
			_dex.toggle_page()
			_refresh()
			_spend(PAGE_FRAMES)
		ENTRY_BUTTON_AREA:
			_open_area()
		ENTRY_BUTTON_CRY:
			## `.Cry` is `GetCryIndex` and `PlayCry`, which is the species number
			## less one straight into `PokemonCries`, not a lookup through the
			## cry table: the row and the species share an index.
			cry_requested.emit(_dex.selected_species())
		ENTRY_BUTTON_PRNT:
			_open_print()


## `.Area`: `wDexCurLocation` is where the player is standing, and the nests are
## `FindNest`'s answer for each region, walked here because the screen owns no
## world state of its own. A cache with no region map leaves the entry up, the
## way an unimported card leaves the Pokegear's list up.
func _open_area() -> void:
	if _area != null:
		return
	var species: int = _dex.selected_species()
	var host := Gen2TownMapScreen.new()
	host.z_index = 10
	add_child(host)
	if not _open_area_screen(host, species):
		Gen2Screen.drop(host)
		return
	host.closed.connect(_on_area_closed)
	_area = host
	_mode = Mode.AREA
	_spend(AREA_FRAMES)


## `predef LoadTownMap_Nest` on a Generation 1 cartridge, whose nests are one
## list of map ids and whose header is the species itself.
func _open_area_screen(host: Gen2TownMapScreen, species: int) -> bool:
	if _gen1:
		return host.open_gen1_dex_area(
			_data, species, Gen2WorldEncounter.gen1_nests(_data, species),
			_world.landmark_backup()
		)
	var roaming: Array = _world.state.roaming_mons()
	var nests: Array = []
	for region: int in Gen2TownMap.REGION_NAMES.size():
		nests.append(Gen2WorldEncounter.nests(
			_data, species, Gen2TownMap.region_name(region), roaming
		))
	return host.open_dex_area(
		_data, species, nests, _world.landmark_backup(), _world.state.hall_of_fame(),
		_world.player_female(), _world.map_time_of_day()
	)


func _on_area_closed() -> void:
	if _area != null:
		Gen2Screen.drop(_area)
		_area = null
	if _gen1:
		## `.choseArea` leaves `b = 0`, which is `.exitSideMenu`'s own way back
		## to the listing rather than to the entry page.
		_open_list_mode()
		return
	## `.Area` redisplays the entry it left, cursor and page included.
	_mode = Mode.ENTRY
	_refresh()
	_spend(AREA_BACK_FRAMES)


## `Pokedex_UpdateOptionScreen`: SELECT and B both return to the listing, and A
## takes the row's mode.
func _handle_option(button: int) -> bool:
	match button:
		PokeButton.B, PokeButton.SELECT:
			_open_list_mode()
			return true
		PokeButton.A:
			_choose_mode()
			return true
		PokeButton.UP, PokeButton.DOWN:
			## `.ArrowCursorData` allows up and down only, and
			## `Pokedex_MoveArrowCursor` stops at either end rather than wrapping.
			_option_cursor = _arrow_move(
				_option_cursor, 1 if button == PokeButton.DOWN else -1, _mode_rows.size()
			)
			_refresh()
			return true
	return false


## `.ChangeMode`, including the message it shows while the order is rebuilt.
## Choosing the mode already in use returns to the listing untouched.
## UNOWN is not one of them: `.MenuAction_UnownMode` never writes `wCurDexMode`,
## it jumps straight to DEXSTATE_UNOWN_MODE, so the listing keeps the mode it
## had and the Unown screen answers back to OPTION rather than to the listing.
func _choose_mode() -> void:
	var row: Dictionary = _mode_rows[_option_cursor]
	if int(row["mode"]) == Gen2Layout.DEXMODE_UNOWN:
		_open_unown_mode()
		return
	if _dex.change_mode(int(row["mode"])):
		_world.state.set_last_dex_mode(_dex.mode)
		# `Pokedex_DisplayChangingModesMessage` puts its two lines in the option
		# screen's own description box and holds there for 64 frames, the sound
		# and 64 more. The listing opens when they are spent, which is
		# `.skip_changing_mode` falling through to `Pokedex_BlackOutBG`.
		_message = Gen2Pokedex.CHANGING_MODES_TEXT
		_changing_modes_frames = CHANGING_MODES_FRAMES * 2
		_refresh()
		return
	# `.skip_changing_mode`: the mode already in use shows no message and waits
	# no frames.
	_open_list_mode()


## `.exit` writes the mode back to `wLastDexMode` before it leaves.
## `SFX_READ_TEXT_2` and its `WaitSFX` come first.
func _exit() -> void:
	_world.state.set_last_dex_mode(_dex.mode)
	sfx_requested.emit(Gen2Sfx.SFX_READ_TEXT_2)
	_hold_for_sound(closed.emit)


## `Pokedex_InitMainScreen`, whose own `ld a, 7` is what puts the listing height
## back after the search results screen has set it to four.
func _open_list_mode() -> void:
	_message = ""
	_mode = Mode.LIST
	_side_cursor = -1
	_dex.listing_height = Gen2Pokedex.LISTING_HEIGHT
	_refresh()
	if not _gen1:
		_spend(LISTING_FRAMES if _listing_opened else OPEN_FRAMES)
		_listing_opened = true


## `HandlePokedexListMenu`: B leaves, A opens the side menu, the rest walks.
func _handle_gen1_list(button: int) -> bool:
	match button:
		PokeButton.B:
			closed.emit()
			return true
		PokeButton.A:
			## `HandlePokedexSideMenu` opens whatever the row is and answers
			## `b = 2` at once for a species not yet seen, which is back here.
			if _dex.can_open_entry():
				_open_gen1_side()
			return true
	if _dex.gen1_move_listing(button):
		_refresh()
	return PokeButton.is_direction(button)


func _handle_gen1_side(button: int) -> bool:
	match button:
		PokeButton.B:
			_open_list_mode()
			return true
		PokeButton.A:
			_gen1_side_action()
			return true
		PokeButton.UP, PokeButton.DOWN:
			var next: int = _side_cursor + (1 if button == PokeButton.DOWN else -1)
			_side_cursor = clampi(next, 0, _page.gen1_side_rows.size() - 1)
			_refresh()
			return true
	return false


## What each row leaves `b` as: DATA and AREA redraw the listing, PRNT goes round
## `.loop`, QUIT closes the dex and CRY stays.
func _gen1_side_action() -> void:
	match _page.gen1_side_rows[_side_cursor]:
		"DATA":
			_dex.open_entry()
			_open_entry_mode(Mode.LIST)
		"CRY":
			cry_requested.emit(_dex.selected_species())
		"AREA":
			_open_area()
		"PRNT":
			_open_print()
		"QUIT":
			closed.emit()


## `PrintDexEntry` and `PrintPokedexEntry` with no printer: `Printer Error 2` until
## B. `CheckCancelPrint` reads B alone.
func _open_print() -> void:
	if _printer_status().is_empty():
		return
	_mode = Mode.PRINT
	printer_music_requested.emit(true)
	_refresh()


## Generation 1 goes round `.loop` to the listing. `.Print` redisplays the entry
## and ends in `PlayMonCry`.
func _handle_print(button: int) -> bool:
	if button != PokeButton.B:
		return false
	printer_music_requested.emit(false)
	if _gen1:
		_open_list_mode()
		return true
	_mode = Mode.ENTRY
	_refresh()
	_play_entry_cry(PRINT_BACK_FRAMES)
	return true


func _printer_status() -> String:
	return _data.printer_status_string(Gen2DiplomaScreen.STATUS_CONNECTION_ERROR)


func _open_gen1_side() -> void:
	_message = ""
	_mode = Mode.SIDE
	_side_cursor = 0
	_refresh()


## `ShowPokedexDataInternal` waits on A or B twice: `PageChar`'s
## `ManualTextScroll` between the description pages and `.waitForButtonPress`
## behind the second. A species not owned prints no description and waits once.
func _handle_gen1_entry(button: int) -> bool:
	if button != PokeButton.A and button != PokeButton.B:
		return false
	if _gen1_entry_pages() > 1 and _dex.page == Gen2Pokedex.PAGE_1:
		sfx_requested.emit(Gen2Sfx.SFX_READ_TEXT_2)
		_dex.toggle_page()
		_refresh()
		return true
	if _entry_only:
		closed.emit()
		return true
	## `.choseData`'s `b = 0` lands on `.setUpGraphics`, which redraws the
	## listing and re-enters it with the cursor where the side menu left it.
	_open_list_mode()
	return true


func _gen1_entry_pages() -> int:
	var entry: Dictionary = _dex.entry()
	if not bool(entry.get("caught", false)):
		return 0
	return (_data.dex_entry(_dex.selected_species()).get(
		"pages", PackedStringArray()
	) as PackedStringArray).size()


## `ShowPokedexMenu`'s listing and `ShowPokedexDataInternal`'s page.
func _render_gen1() -> Image:
	if _mode != Mode.ENTRY:
		var printing: bool = _mode == Mode.PRINT
		var map: PackedInt32Array = _page.gen1_list_map(
			_dex.gen1_rows(), _dex.seen_count(), _dex.caught_count(),
			-1 if printing else _listing_cursor(), -1 if printing else _side_cursor
		)
		if printing:
			_page.gen1_status_box(map, _printer_status(), _data.printer_status_string("press_b"))
		return _page.image(map)
	var species: int = _dex.selected_species()
	var entry: Dictionary = _dex.entry()
	var page: int = int(entry["page"])
	return _page.image(_page.gen1_entry_map(
		species, String(entry["name"]), _data.dex_entry(species),
		bool(entry["caught"]), page,
		_gen1_entry_pages() > 1 and page == Gen2Pokedex.PAGE_1
	), _gen1_entry_pic(species), Gen2PokedexPage.GEN1_ENTRY_PIC_AT)


## `LoadFlippedFrontSpriteByMonIndex`: the front pic mirrored, centred in
## `LoadUncompressedSpriteData`'s 7x7 block, and drawn through the species' own
## palette, which is `BlkPacket_Pokedex`'s one block.
func _gen1_entry_pic(species: int) -> Image:
	var pic: Dictionary = _data.species_pic(species)
	var palette: PackedColorArray = _data.palette(species)
	if pic.is_empty() or palette.size() < PokePalette.COLORS_PER_PIC:
		return null
	var art: Image = Gen2PicImage.from_atlas(
		_data.atlas_indices(pic["atlas"]), _data.atlas(pic["atlas"]), pic, palette
	)
	if art == null:
		return null
	return Gen2PokedexPage.pad_pic(
		Gen2PicImage.x_flipped(art), palette[0], RomRegistry.GEN1
	)


## `Pokedex_InitDexEntryScreen`, `_NewPokedexEntry` and pokered's
## `ShowPokedexDataInternal`, which each end by playing the cry and waiting.
func _open_entry_mode(from: Mode = Mode.LIST) -> void:
	_message = ""
	_entry_from = from
	_mode = Mode.ENTRY
	_entry_cursor = 0
	_arrow_delay = 0
	_refresh()
	_play_entry_cry(ENTRY_OPEN_FRAMES)


## `PlayMonCry` behind a freshly drawn page: no press is read until it ends, and
## [param frames_after] more are spent (unmeasured on Generation 1).
func _play_entry_cry(frames_after: int) -> void:
	cry_requested.emit(_dex.selected_species())
	_hold_for_sound(_spend.bind(0 if _gen1 else frames_after))


## `WaitSFX`: [param then] runs once the effect has ended, at once if none sounds.
func _hold_for_sound(then: Callable = Callable()) -> void:
	_sound_watch = {}
	_sound_then = then
	_sound_holding = true
	_release_sound()


func _release_sound() -> void:
	if not _sound_holding or bool(sound_busy.call(_sound_watch)):
		return
	_sound_holding = false
	var then: Callable = _sound_then
	_sound_then = Callable()
	if then.is_valid():
		then.call()


func _open_option_mode() -> void:
	_message = ""
	_mode = Mode.OPTION
	_arrow_delay = 0
	_mode_rows = Gen2Pokedex.mode_rows(_dex.unown_unlocked())
	## `Pokedex_InitOptionScreen` points the cursor at the current mode, which
	## it can do directly because the modes are the row indices.
	_option_cursor = 0
	for index: int in _mode_rows.size():
		if int(_mode_rows[index]["mode"]) == _dex.mode:
			_option_cursor = index
	_refresh()


## `Pokedex_UpdateUnownMode`: left and right walk the forms caught, and A or B
## both leave. `.a_b` goes back to DEXSTATE_OPTION_SCR, not to the listing.
func _handle_unown(button: int) -> bool:
	match button:
		PokeButton.A, PokeButton.B:
			_open_option_mode()
			return true
		PokeButton.LEFT, PokeButton.RIGHT:
			if _dex.move_unown(button):
				_refresh()
			return true
	return false


## `Pokedex_InitUnownMode`, which opens on the first form caught.
func _open_unown_mode() -> void:
	_message = ""
	_mode = Mode.UNOWN
	_dex.open_unown_mode()
	_refresh()


## `Pokedex_UpdateSearchScreen`: up and down move the four rows, left and right
## change a type on the two rows that carry one, A takes the row, and START or B
## both cancel back to the listing.
func _handle_search(button: int) -> bool:
	match button:
		PokeButton.B, PokeButton.START:
			_open_list_mode()
			return true
		PokeButton.A:
			_confirm_search_row()
			return true
		PokeButton.UP, PokeButton.DOWN:
			_dex.search_cursor = _arrow_move(
				_dex.search_cursor, 1 if button == PokeButton.DOWN else -1,
				Gen2Pokedex.SEARCH_ROWS.size()
			)
			_refresh()
			return true
		PokeButton.LEFT, PokeButton.RIGHT:
			if _dex.move_search_type(button):
				_refresh()
			return true
	return false


## `.MenuActionJumptable`: A on either type row steps it the way right does, A on
## BEGIN SEARCH runs the search, and A on CANCEL leaves.
func _confirm_search_row() -> void:
	match _dex.search_cursor:
		Gen2Pokedex.SEARCH_ROW_TYPE_1, Gen2Pokedex.SEARCH_ROW_TYPE_2:
			_dex.move_search_type(PokeButton.RIGHT)
			_refresh()
		Gen2Pokedex.SEARCH_ROW_BEGIN:
			## `.MenuAction_BeginSearch` searches first and only then spends
			## `AnimateDexSearchSlowpoke`, so the count is already known while
			## the Slowpoke is still moving.
			_search_result = _dex.begin_search()
			_search_frames = SEARCH_FRAMES
			_refresh()
		Gen2Pokedex.SEARCH_ROW_CANCEL:
			_open_list_mode()


## `Pokedex_UpdateSearchResultsScreen`: the same listing walk as the main screen
## over four rows instead of seven, A opens an entry and B goes back to SEARCH.
func _handle_search_results(button: int) -> bool:
	match button:
		PokeButton.B:
			_dex.leave_search_results()
			_open_search_mode()
			return true
		PokeButton.A:
			if _dex.can_open_entry():
				_dex.open_entry()
				_open_entry_mode(Mode.SEARCH_RESULTS)
			return true
	return _move_listing(button)


## `Pokedex_InitSearchScreen`, which resets both type rows every time.
## Coming back from the results screen resets them too: `.return_to_search_screen`
## jumps to DEXSTATE_SEARCH_SCR, and that jumptable entry is this Init rather
## than its Update, so the search is not remembered.
func _open_search_mode() -> void:
	_message = ""
	_message_frames = 0
	_search_frames = 0
	_search_result = 0
	_mode = Mode.SEARCH
	_arrow_delay = 0
	_dex.open_search()
	_refresh()


## What `.MenuAction_BeginSearch` does once `AnimateDexSearchSlowpoke` is spent:
## a result opens the results screen, and none redraws the search screen under
## `Pokedex_DisplayTypeNotFoundMessage`'s own two lines.
func _finish_search() -> void:
	if _search_result > 0:
		_open_search_results_mode()
		return
	_message = Gen2Pokedex.TYPE_NOT_FOUND_TEXT
	_message_frames = TYPE_NOT_FOUND_FRAMES
	_refresh()


## `Pokedex_InitSearchResultsScreen`, whose own `ld a, 4` is the shorter listing.
func _open_search_results_mode() -> void:
	_message = ""
	_mode = Mode.SEARCH_RESULTS
	_dex.listing_height = Gen2Pokedex.SEARCH_RESULTS_HEIGHT
	_refresh()


## The whole screen, redrawn from the model. One layer: every state here is a
## background the source writes as tiles, with the species picture blitted into
## the box its layout left blank.
func _refresh() -> void:
	if _background == null or _page == null or _dex == null:
		return
	Gen2PicImage.show(_background, render())
	_background.size = Vector2(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)


## The screen as one 160x144 image, for a preview or a test that wants pixels.
func render() -> Image:
	if _page == null or _dex == null:
		return Image.create_empty(
			Gen2Screen.WIDTH, Gen2Screen.HEIGHT, false, Image.FORMAT_RGBA8
		)
	## `LoadTownMap` clears the screen and draws the region map over it, so the
	## AREA row is the whole picture rather than a layer on the listing.
	if _mode == Mode.AREA and _area != null:
		return _area.render()
	if _gen1:
		return _render_gen1()
	if _mode == Mode.PRINT:
		return _page.print_image(_printer_status())
	## `Pokedex_BlinkArrowCursor`'s own off phase, and the same answer on every
	## frame for a screen that is being read rather than walked.
	var cursor: int = -1 if _read_only or _blink >= CURSOR_BLINK_FRAMES else 0
	match _mode:
		Mode.OPTION:
			return _page.image(_page.option_map(
				_dex.unown_unlocked(), _option_cursor if cursor == 0 else -1,
				_message if not _message.is_empty() else String(
					_mode_rows[_option_cursor]["description"]
				)
			))
		Mode.SEARCH:
			return _page.search_image(
				_page.search_map(
					_dex.search_type_string(_dex.search_type_1),
					_dex.search_type_string(_dex.search_type_2),
					_dex.search_cursor if cursor == 0 else -1, _message
				),
				_slowpoke_frame()
			)
		Mode.UNOWN:
			return _page.image(
				_page.unown_map(
					_dex.unown_forms(), _dex.unown_cursor, _dex.unown_word()
				),
				_selected_pic(), Vector2i(6, 5)
			)
		Mode.ENTRY:
			return _render_entry_image(cursor)
		Mode.SEARCH_RESULTS:
			# `Pokedex_InitSearchResultsScreen` puts its listing in the same
			# window the main screen uses, at DEXMODE_OLD's own `hWX`.
			return _page.image_main(
				_page.search_results_background(
					_dex.search_result_count, _search_type_line()
				),
				_page.results_window_map(_dex.rows()), true, _selected_pic(),
				Gen2PokedexPage.RESULTS_WINDOW_ROWS, _listing_cursor(),
				Vector2i.ZERO, true
			)
	# The listing's own cursor is an object frame rather than the arrow the other
	# screens blink, so it is up on every frame the listing is.
	var old_mode: bool = _dex.mode == Gen2Layout.DEXMODE_OLD
	return _page.image_main(
		_page.main_background(_dex.seen_count(), _dex.caught_count()),
		_page.window_map(_dex.rows(), old_mode), old_mode, _selected_pic(),
		Gen2PokedexPage.ROWS, _listing_cursor(),
		Vector2i(_dex.cursor + _dex.scroll, _dex.listing_end)
	)


## `wDexListingCursor`, or -1 for a screen being read: `ClearSprites` is what
## every other state opens with, and a readout draws no cursor at all.
func _listing_cursor() -> int:
	return -1 if _read_only else _dex.cursor


## Which `AnimateDexSearchSlowpoke` frame the search screen is showing.
## `Pokedex_InitSearchScreen` leaves `wDexSearchSlowpokeFrame` at zero, and the
## animation runs only while a search is being spent.
func _slowpoke_frame() -> int:
	if _search_frames <= 0 or _search_frames <= Gen2PokedexPage.SLOWPOKE_SETTLE:
		return 0
	var spent: int = _SEARCH_ANIMATION_FRAMES - (_search_frames - Gen2PokedexPage.SLOWPOKE_SETTLE)
	@warning_ignore("integer_division")
	return (spent / Gen2PokedexPage.SLOWPOKE_FRAME_HOLD) % Gen2PokedexPage.SLOWPOKE_FRAMES


## `Pokedex_InitDexEntryScreen`, which loads the species' footprint before it
## draws the grid that names its four tiles.
func _render_entry_image(cursor: int) -> Image:
	var entry: Dictionary = _dex.entry()
	var species: int = _dex.selected_species()
	_page.load_footprint(_data, species)
	return _page.image(_page.entry_map(
		species, String(entry["name"]), _data.dex_entry(species),
		bool(entry["caught"]), int(entry["page"]),
		_entry_cursor if cursor == 0 else -1,
		not _entry_only
	), _selected_pic())


## `Pokedex_LoadSelectedMonTiles`: the species' front picture, or the Slowpoke
## one for a species that has not been seen.
func _selected_pic() -> Image:
	var species: int = _dex.selected_species()
	# `Pokedex_LoadUnownFrontpicTiles` draws the cursor's own form rather than
	# the listing's species, which on this screen is UNOWN either way.
	if _mode == Mode.UNOWN:
		var forms: Array[int] = _dex.unown_forms()
		if _dex.unown_cursor < 0 or _dex.unown_cursor >= forms.size():
			return null
		# `ld a, UNOWN / ld [wCurPartySpecies], a`, so the box is drawn through
		# UNOWN's palette whatever the listing was left on.
		return _pic_image(
			_data.unown_pic(forms[_dex.unown_cursor] - 1), Gen2Layout.UNOWN_SPECIES
		)
	# `Pokedex_CheckSeen`, which is what `can_open_entry` already answers for the
	# selected row.
	if species <= 0 or not _dex.can_open_entry():
		return _page.unseen_pic()
	# `ld a, [wFirstUnownSeen] / ld [wUnownLetter], a` in front of `GetMonFrontpic`:
	# every UNOWN row in the listing and its entry are drawn as the first Unown
	# this save met, not as form A.
	if species == Gen2Layout.UNOWN_SPECIES and _dex.first_unown_seen() > 0:
		return _pic_image(_data.unown_pic(_dex.first_unown_seen() - 1), species)
	return _pic_image(_data.species_pic(species), species)


## One imported pic, or the question mark when the cache does not hold it.
## `_CGB_Pokedex` fills the picture box's attrmap with palette 1, and which
## palette that is turns on `wCurPartySpecies`: the two listing screens set it to
## `-1` and get `PokedexQuestionMarkPalette`, so every species is drawn in the
## dex's own green there, while the entry screen and the Unown screen set it to
## the species and get `LoadPalette_White_Col1_Col2_Black`'s four.
func _pic_image(pic: Dictionary, species: int) -> Image:
	if pic.is_empty():
		return _page.unseen_pic()
	var listing: bool = _mode == Mode.LIST or _mode == Mode.SEARCH_RESULTS
	var palette: PackedColorArray = _data.pokedex_palette("question_mark") \
		if listing else _data.palette(species)
	if palette.size() < PokePalette.COLORS_PER_PIC:
		return _page.unseen_pic()
	return Gen2PokedexPage.pad_pic(
		Gen2PicImage.from_atlas(
			_data.atlas_indices(pic["atlas"]), _data.atlas(pic["atlas"]), pic, palette
		),
		palette[0]
	)


## `Pokedex_PlaceSearchResultsTypeStrings`, which prints the second type only
## when there is one and it is not the first.
func _search_type_line() -> String:
	var first: String = _dex.search_type_name(_dex.search_type_1)
	if _dex.search_type_2 == Gen2Pokedex.SEARCH_TYPE_NONE \
		or _dex.search_type_2 == _dex.search_type_1:
		return first
	return "%s/%s" % [first, _dex.search_type_name(_dex.search_type_2)]


## `Pokedex_BlinkArrowCursor` is the only thing here that counts frames.
func _process(delta: float) -> void:
	if _dex == null:
		return
	for _frame: int in _frame_clock.tick(delta):
		advance_frame()


func advance_frame() -> void:
	if _sound_holding:
		_release_sound()
		return
	_arrow_delay = maxi(_arrow_delay - 1, 0)
	if _changing_modes_frames > 0:
		_changing_modes_frames -= 1
		if _changing_modes_frames == CHANGING_MODES_FRAMES:
			sfx_requested.emit(Gen2Sfx.SFX_CHANGE_DEX_MODE)
		elif _changing_modes_frames == 0:
			_open_list_mode()
		return
	if _message_frames > 0:
		_message_frames -= 1
		if _message_frames == 0:
			_message = ""
			_refresh()
		return
	if _search_frames > 0:
		var frame: int = _slowpoke_frame()
		_search_frames -= 1
		if _search_frames == 0:
			_finish_search()
		elif _slowpoke_frame() != frame:
			_refresh()
		return
	## `PlaceMenuCursor` writes its `▶` into the map, so nothing there blinks.
	if _gen1:
		return
	_blink = (_blink + 1) % (CURSOR_BLINK_FRAMES * 2)
	if _blink == 0 or _blink == CURSOR_BLINK_FRAMES:
		_refresh()


func _build_ui() -> void:
	var screen: Gen2Screen = Gen2Screen.host_for(self, _screen)
	if screen == null:
		return
	_screen = screen
	_field = Control.new()
	_field.size = Vector2(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.display(_field)
	_background = TextureRect.new()
	_background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field.add_child(_background)


## Draws the listing with no arrow on it, for a display that shows the dex
## without being able to walk it. The blink is left running: it costs nothing and
## the flag is checked where the arrow is placed.
func set_read_only(on: bool) -> void:
	_read_only = on


func set_screen(screen: Gen2Screen) -> void:
	_screen = screen


func _exit_tree() -> void:
	## `NewPokedexEntry`'s `MaxVolume` behind its second page.
	_mode = Mode.LIST
	if _field != null:
		Gen2Screen.drop_on_exit(_field)
		_field = null
