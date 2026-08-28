class_name Gen2PokedexScreen
extends Control

## The Pokedex (engine/pokedex/pokedex.asm), embedded in the overworld the way the
## start menu and its own submenus are. Drawn on the hardware's own tile grid:
## [Gen2Pokedex] owns the listing, the cursor and the mode and [Gen2PokedexPage]
## the picture. All six of the source's states are here, and the OPTION screen
## draws three rows until the Ruins of Alph research centre has set the flag. The
## entry screen's AREA is the exception to that split: `Pokedex_GetArea` is the
## cartridge's own region map, so it opens [Gen2TownMapScreen], which carries a
## hardware screen of its own.

## Set by [method open_entry]: `NewPokedexEntry` has no listing behind it, so B
## on the entry closes the dex rather than going back to one.
var _entry_only: bool = false

## Emitted on B from the listing, which is where `DEXSTATE_EXIT` lands.
signal closed

## Emitted by the entry screen's CRY button, since this screen owns no audio
## player: the overworld's own answers it, the way it answers a script's cry.
signal cry_requested(species: int)

## `PlaySFX`, for the one sound this screen makes of its own:
## `Pokedex_DisplayChangingModesMessage`'s. Answered by the overworld's player
## the way [signal cry_requested] is.
signal sfx_requested(index: int)

enum Mode { LIST, ENTRY, OPTION, SEARCH, SEARCH_RESULTS, AREA, UNOWN }

## The dex is drawn in hardware pixels and the start menu it opens over is
## ordinary UI at window resolution, so it carries a [Gen2Screen] of its own the
## way [Gen2TownMapScreen] does.

## `Pokedex_BlinkArrowCursor` counts its own frames and shows the arrow on the
## eight it is off `$8`, so the cursor is up for eight frames and down for eight.
const CURSOR_BLINK_FRAMES: int = 8

## `Pokedex_DisplayChangingModesMessage`'s two `ld c, 64` / `call DelayFrames`,
## with `SFX_CHANGE_DEX_MODE` played between them.
const CHANGING_MODES_FRAMES: int = 64
## constants/sfx_constants.asm.
const SFX_CHANGE_DEX_MODE: int = 0x15

## `AnimateDexSearchSlowpoke`: twenty-five steps of seven frames each, then
## thirty-two more with the Slowpoke back on its first frame. The whole run is
## spent between BEGIN SEARCH and the results, the way the source spends it.
const _SEARCH_ANIMATION_FRAMES: int = \
	Gen2PokedexPage.SLOWPOKE_STEPS * Gen2PokedexPage.SLOWPOKE_FRAME_HOLD
const SEARCH_FRAMES: int = _SEARCH_ANIMATION_FRAMES + Gen2PokedexPage.SLOWPOKE_SETTLE
## `Pokedex_DisplayTypeNotFoundMessage`'s own `ld c, $80`.
const TYPE_NOT_FOUND_FRAMES: int = 0x80

## `DexEntryScreen_ArrowCursorData`'s four positions, in its own order. PRNT
## wants a printer, which is deliberately out, so it is drawn and refuses.
const ENTRY_BUTTONS: Array[String] = ["PAGE", "AREA", "CRY", "PRNT"]
const ENTRY_BUTTON_PAGE: int = 0
const ENTRY_BUTTON_AREA: int = 1
const ENTRY_BUTTON_CRY: int = 2

var _dex: Gen2Pokedex = null
var _world: Gen2WorldAPI = null
var _data: GameData = null
var _mode: Mode = Mode.LIST
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

var _page: Gen2PokedexPage = null
## The 160x144 field inside the hardware screen, and the one layer drawn into it.
## The screen this is drawn in, and the 160x144 layer inside it.
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
## Whether this is being read rather than driven. See [method set_read_only].
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
	if _data.dex_order_new().is_empty() or _data.dex_order_alpha().is_empty():
		return false
	_page = Gen2PokedexPage.from_data(_data)
	if _page == null or not _page.ready():
		return false
	_dex = Gen2Pokedex.open(
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


func handle_button(button: int) -> bool:
	if _dex == null or _changing_modes_frames > 0 or _search_frames > 0 \
		or _message_frames > 0:
		return false
	if _mode == Mode.AREA:
		return _area.handle_button(button)
	match _mode:
		Mode.LIST:
			return _handle_list(button)
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
		Gen2Button.B:
			_exit()
			return true
		Gen2Button.A:
			if _dex.can_open_entry():
				_dex.open_entry()
				_open_entry_mode(Mode.LIST)
			return true
		Gen2Button.SELECT:
			_open_option_mode()
			return true
		Gen2Button.START:
			_open_search_mode()
			return true
	if _dex.move_listing(button):
		_refresh()
	return Gen2Button.is_direction(button)


## `Pokedex_UpdateDexEntryScreen`: B returns to the listing, A turns the page,
## and up and down step to the neighbouring entry.
##
## The source's four-button row is PAGE, AREA, CRY and PRNT; only PAGE is built,
## so A always turns the page rather than moving a cursor along a row whose
## other three entries would refuse.
func _handle_entry(button: int) -> bool:
	match button:
		Gen2Button.B:
			## `NewPokedexEntry` has no listing under it, so B is what closes it.
			if _entry_only:
				closed.emit()
				return true
			## `wPrevDexEntryJumptableIndex`, which `Pokedex_UpdateMainScreen`
			## and `Pokedex_UpdateSearchResultsScreen` each write before they
			## open an entry: B goes back to whichever listing that was, not
			## always the main one.
			if _entry_from == Mode.SEARCH_RESULTS:
				_open_search_results_mode()
				return true
			_open_list_mode()
			return true
		Gen2Button.A:
			_entry_action()
			return true
		Gen2Button.LEFT, Gen2Button.RIGHT:
			## `DexEntryScreen_ArrowCursorData` allows left and right only, over
			## four positions, and stops at either end.
			var next: int = _entry_cursor + (1 if button == Gen2Button.RIGHT else -1)
			_entry_cursor = clampi(next, 0, ENTRY_BUTTONS.size() - 1)
			_refresh()
			return true
		Gen2Button.UP, Gen2Button.DOWN:
			if _dex.step_entry(button):
				## `Pokedex_ReinitDexEntryScreen` calls `Pokedex_InitArrowCursor`,
				## so a new entry opens on PAGE whatever the last one ended on.
				_entry_cursor = 0
				_refresh()
			return true
	return false


## `DexEntryScreen_MenuActionJumptable`. `.Print` needs a printer and does
## nothing rather than refusing out loud, since the cartridge's own row has no
## refusal for it either.
func _entry_action() -> void:
	match _entry_cursor:
		ENTRY_BUTTON_PAGE:
			_dex.toggle_page()
			_refresh()
		ENTRY_BUTTON_AREA:
			_open_area()
		ENTRY_BUTTON_CRY:
			## `.Cry` is `GetCryIndex` and `PlayCry`, which is the species number
			## less one straight into `PokemonCries`, not a lookup through the
			## cry table: the row and the species share an index.
			cry_requested.emit(_dex.selected_species())


## `.Area`: `wDexCurLocation` is where the player is standing, and the nests are
## `FindNest`'s answer for each region, walked here because the screen owns no
## world state of its own. A cache with no region map leaves the entry up, the
## way an unimported card leaves the Pokegear's list up.
func _open_area() -> void:
	if _area != null:
		return
	var species: int = _dex.selected_species()
	var roaming: Array = _world.state.roaming_mons()
	var nests: Array = []
	for region: int in Gen2TownMap.REGION_NAMES.size():
		nests.append(Gen2WorldEncounter.nests(
			_data, species, Gen2TownMap.region_name(region), roaming
		))
	var host := Gen2TownMapScreen.new()
	host.z_index = 10
	add_child(host)
	if not host.open_dex_area(
		_data, species, nests, _world.landmark_backup(), _world.state.hall_of_fame(),
		_world.player_female(), _world.map_time_of_day()
	):
		Gen2Screen.drop(host)
		return
	host.closed.connect(_on_area_closed)
	_area = host
	_mode = Mode.AREA


func _on_area_closed() -> void:
	if _area != null:
		Gen2Screen.drop(_area)
		_area = null
	## `.Area` redisplays the entry it left, cursor and page included.
	_mode = Mode.ENTRY
	_refresh()


## `Pokedex_UpdateOptionScreen`: SELECT and B both return to the listing, and A
## takes the row's mode.
func _handle_option(button: int) -> bool:
	match button:
		Gen2Button.B, Gen2Button.SELECT:
			_open_list_mode()
			return true
		Gen2Button.A:
			_choose_mode()
			return true
		Gen2Button.UP, Gen2Button.DOWN:
			## `.ArrowCursorData` allows up and down only, and
			## `Pokedex_MoveArrowCursor` stops at either end rather than wrapping.
			var next: int = _option_cursor + (1 if button == Gen2Button.DOWN else -1)
			_option_cursor = clampi(next, 0, _mode_rows.size() - 1)
			_refresh()
			return true
	return false


## `.ChangeMode`, including the message it shows while the order is rebuilt.
## Choosing the mode already in use returns to the listing untouched.
##
## UNOWN is not one of them: `.MenuAction_UnownMode` never writes `wCurDexMode`,
## it jumps straight to DEXSTATE_UNOWN_MODE, so the listing keeps the mode it
## had and the Unown screen answers back to OPTION rather than to the listing.
func _choose_mode() -> void:
	var row: Dictionary = _mode_rows[_option_cursor]
	if int(row["mode"]) == RomLayout.DEXMODE_UNOWN:
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
func _exit() -> void:
	_world.state.set_last_dex_mode(_dex.mode)
	closed.emit()


## `Pokedex_InitMainScreen`, whose own `ld a, 7` is what puts the listing height
## back after the search results screen has set it to four.
func _open_list_mode() -> void:
	_message = ""
	_mode = Mode.LIST
	_dex.listing_height = Gen2Pokedex.LISTING_HEIGHT
	_refresh()


func _open_entry_mode(from: Mode = Mode.LIST) -> void:
	_message = ""
	_entry_from = from
	_mode = Mode.ENTRY
	_entry_cursor = 0
	_refresh()


func _open_option_mode() -> void:
	_message = ""
	_mode = Mode.OPTION
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
		Gen2Button.A, Gen2Button.B:
			_open_option_mode()
			return true
		Gen2Button.LEFT, Gen2Button.RIGHT:
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
		Gen2Button.B, Gen2Button.START:
			_open_list_mode()
			return true
		Gen2Button.A:
			_confirm_search_row()
			return true
		Gen2Button.UP, Gen2Button.DOWN:
			var next: int = _dex.search_cursor + (1 if button == Gen2Button.DOWN else -1)
			_dex.search_cursor = clampi(next, 0, Gen2Pokedex.SEARCH_ROWS.size() - 1)
			_refresh()
			return true
		Gen2Button.LEFT, Gen2Button.RIGHT:
			if _dex.move_search_type(button):
				_refresh()
			return true
	return false


## `.MenuActionJumptable`: A on either type row steps it the way right does, A on
## BEGIN SEARCH runs the search, and A on CANCEL leaves.
func _confirm_search_row() -> void:
	match _dex.search_cursor:
		Gen2Pokedex.SEARCH_ROW_TYPE_1, Gen2Pokedex.SEARCH_ROW_TYPE_2:
			_dex.move_search_type(Gen2Button.RIGHT)
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
		Gen2Button.B:
			_dex.leave_search_results()
			_open_search_mode()
			return true
		Gen2Button.A:
			if _dex.can_open_entry():
				_dex.open_entry()
				_open_entry_mode(Mode.SEARCH_RESULTS)
			return true
	if _dex.move_listing(button):
		_refresh()
	return Gen2Button.is_direction(button)


## `Pokedex_InitSearchScreen`, which resets both type rows every time.
##
## Coming back from the results screen resets them too: `.return_to_search_screen`
## jumps to DEXSTATE_SEARCH_SCR, and that jumptable entry is this Init rather
## than its Update, so the search is not remembered.
func _open_search_mode() -> void:
	_message = ""
	_message_frames = 0
	_search_frames = 0
	_search_result = 0
	_mode = Mode.SEARCH
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
	var old_mode: bool = _dex.mode == RomLayout.DEXMODE_OLD
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
		_entry_cursor if cursor == 0 else -1
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
			_data.unown_pic(forms[_dex.unown_cursor] - 1), RomLayout.UNOWN_SPECIES
		)
	# `Pokedex_CheckSeen`, which is what `can_open_entry` already answers for the
	# selected row.
	if species <= 0 or not _dex.can_open_entry():
		return _page.unseen_pic()
	# `ld a, [wFirstUnownSeen] / ld [wUnownLetter], a` in front of `GetMonFrontpic`:
	# every UNOWN row in the listing and its entry are drawn as the first Unown
	# this save met, not as form A.
	if species == RomLayout.UNOWN_SPECIES and _dex.first_unown_seen() > 0:
		return _pic_image(_data.unown_pic(_dex.first_unown_seen() - 1), species)
	return _pic_image(_data.species_pic(species), species)


## One imported pic, or the question mark when the cache does not hold it.
##
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
	if palette.size() < Gen2Palette.COLORS_PER_PIC:
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
	if _changing_modes_frames > 0:
		_changing_modes_frames -= 1
		if _changing_modes_frames == CHANGING_MODES_FRAMES:
			sfx_requested.emit(SFX_CHANGE_DEX_MODE)
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


## The screen the opener wants this drawn in, handed over before it is added to
## the tree. Without one the field goes in whichever screen this ends up inside.
## Draws the listing with no arrow on it, for a display that shows the dex
## without being able to walk it. The blink is left running: it costs nothing and
## the flag is checked where the arrow is placed.
func set_read_only(on: bool) -> void:
	_read_only = on


func set_screen(screen: Gen2Screen) -> void:
	_screen = screen


## The field lives in a screen this node may not own, so it goes by hand.
func _exit_tree() -> void:
	if _field != null:
		Gen2Screen.drop_on_exit(_field)
		_field = null
