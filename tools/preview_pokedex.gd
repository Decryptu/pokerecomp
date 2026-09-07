extends SceneTree

## Captures the Pokedex against a real imported cache.
##   Godot --headless --path . -s res://tools/preview_pokedex.gd -- \
##       crystal /tmp/dex.png [list|entry|option|search|results|unown] [presses]
## A Generation 1 cartridge answers `list`, `side` and `entry` and none of the
## other four: `ShowPokedexMenu` has no mode, search or Unown screen.
## The world behind it is a new game with every species seen and every second one
## caught, which puts a full listing, both row states and a real entry on screen at
## once. `f<n>` in [presses] spends n hardware frames, which catches the arrow blink.

const NEW_BARK_GROUP: int = 24
const NEW_BARK_MAP: int = 7
## PALLET_TOWN, which a Generation 1 map id names on its own.
const PALLET_TOWN: int = 0
## How far down the dex the preview's save has been filled, per generation.
const SEEN: int = 251
const GEN1_SEEN: int = 151
## The one species left out of it, so the listing has an unseen row to draw.
## Generation 1 lists by dex number, so the hole has to be past the first page.
const UNSEEN: int = 1
const GEN1_UNSEEN: int = 4

const BUTTONS: Dictionary = {
	"u": PokeButton.UP, "d": PokeButton.DOWN,
	"l": PokeButton.LEFT, "r": PokeButton.RIGHT,
	"a": PokeButton.A, "b": PokeButton.B,
	"sel": PokeButton.SELECT, "start": PokeButton.START,
}

## Which presses each named screen is reached by, so a caller naming one does not
## have to know the walk.
const ROUTES: Dictionary = {
	"list": "",
	# BULBASAUR's own row, which is the one that is not seen: `NewPokedexOrder`
	# holds it at position 226, which is thirty-two pages down and one row on.
	"unseen": "r,r,r,r,r,r,r,r,r,r,r,r,r,r,r,r,r,r,r,r,r,r,r,r,r,r,r,r,r,r,r,r,d",
	"entry": "a",
	"option": "sel",
	"search": "start",
	# BEGIN SEARCH spends `AnimateDexSearchSlowpoke` before the results open, so
	# the walk has to wait it out.
	"results": "start,d,d,a,f%d" % Gen2PokedexScreen.SEARCH_FRAMES,
	"unown": "sel,d,d,d,a",
}

## `HandlePokedexSideMenu` and `ShowPokedexDataInternal`, the two screens behind
## Generation 1's listing.
const GEN1_ROUTES: Dictionary = {
	"list": "",
	"unseen": "d,d,d",
	"side": "a",
	"entry": "a,a",
}


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error(
			"Usage: preview_pokedex.gd -- <game> <output.png> "
			+ "[list|entry|option|search|results|unown] [presses]"
		)
		quit(1)
		return
	if PokeToolPath.refuses(args[1]):
		quit(2)
		return
	var data: GameData = GameData.open(StringName(args[0]))
	if data == null:
		push_error("No cache for %s. Import roms/%s.gbc first." % [args[0], args[0]])
		quit(1)
		return

	var gen1: bool = data.generation == RomRegistry.GEN1
	var screen: String = args[2] if args.size() > 2 else "list"
	var routes: Dictionary = GEN1_ROUTES if gen1 else ROUTES
	var tokens: String = String(routes.get(screen, ""))
	if args.size() > 3:
		tokens = "%s,%s" % [tokens, args[3]] if not tokens.is_empty() else args[3]

	var world: Gen2WorldAPI = Gen2WorldAPI.open(
		data, 0 if gen1 else NEW_BARK_GROUP, PALLET_TOWN if gen1 else NEW_BARK_MAP,
		Vector2i.ZERO, _state(gen1)
	)
	var host := Gen2PokedexScreen.new()
	root.add_child(host)
	if not host.open(data, world):
		push_error("The %s cache holds no Pokedex graphics." % args[0])
		quit(1)
		return
	# The screen counts hardware frames off wall clock in `_process`; the preview
	# spends them by hand so the arrow is where the presses left it.
	host.set_process(false)
	for token: String in tokens.split(",", false):
		var key: String = token.strip_edges().to_lower()
		if key.begins_with("f"):
			for _frame: int in maxi(1, int(key.substr(1))):
				host.advance_frame()
		elif BUTTONS.has(key):
			host.handle_button(int(BUTTONS[key]))

	var error: Error = host.render().save_png(args[1])
	if error != OK:
		push_error("Could not write %s (error %d)" % [args[1], error])
		quit(1)
		return
	print("Wrote %s: %s, mode %d, cursor on %s" % [
		args[1], screen, host.current_mode(),
		data.species(host.selected_species()).get("name", "?"),
	])
	quit(0)


## A world whose dex is filled far enough to draw every row state: seen up to
## [constant SEEN], caught on every second one, and the Unown dex unlocked so the
## OPTION screen offers its fourth row.
## [constant UNSEEN] is left out so one row is the not-seen one, which is the
## only row that draws `LoadQuestionMarkPic`'s picture.
static func _state(gen1: bool = false) -> Gen2WorldState:
	var state := Gen2WorldState.new({}, {}, {}, {})
	var last: int = GEN1_SEEN if gen1 else SEEN
	var hole: int = GEN1_UNSEEN if gen1 else UNSEEN
	for species: int in range(1, last + 1):
		if species == hole:
			continue
		state.set_species_seen(species)
		if species % 2 == 0:
			state.set_species_caught(species)
	state.set_engine_flag(Gen2WorldState.ENGINE_UNOWN_DEX)
	for form: int in range(1, 8):
		state.update_unown_dex(form)
	return state
