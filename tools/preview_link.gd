extends SceneTree

## Captures the cable club's screens against a real imported cache, headless.
##   Godot --headless --path . -s res://tools/preview_link.gd -- <game> <out.png> [screen]
## [screen] is `trade`, `wait`, `confirm`, `record` or `all`, the default; a
## Generation 1 cache adds `stats`, `versus` and `verdict`. `anim` draws the
## movie behind the trade instead, six sampled frames; `anim:<frame>[,...]`
## names its own.

const COLUMNS: int = 2
const SCREENS: Array[String] = ["wait", "trade", "confirm", "record"]
const GEN1_SCREENS: Array[String] = ["wait", "trade", "stats", "confirm", "versus", "verdict"]

## A pair of parties long enough that both lists reach the cursor rows, with the
## partner's one shorter so the two halves are told apart in the picture.
const PLAYER_PARTY: Array[String] = [
	"CHIKORITA", "TOTODILE", "CYNDAQUIL", "PIDGEY", "RATTATA", "SENTRET",
]
const PARTNER_PARTY: Array[String] = ["BULBASAUR", "SQUIRTLE", "CHARMANDER"]
const PLAYER_NAME: String = "GOLD"
const PARTNER_NAME: String = "KRIS"

const ANIM_PLAYER: int = 152
const ANIM_PARTNER: int = 25
const ANIM_FRAMES: Array[int] = [40, 260, 420, 700, 1500, 2100]


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("Usage: preview_link.gd -- <game> <output.png> [screen|all]")
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
	var page: Gen2LinkPage = Gen2LinkPage.from_data(data)
	if page == null:
		push_error("The %s cache carries no trade screen border." % args[0])
		quit(1)
		return

	var wanted: String = args[2] if args.size() > 2 else "all"
	if wanted.begins_with("anim"):
		_capture_animation(data, args[0], args[1], wanted)
		return
	var screens: Array[String] = (GEN1_SCREENS if page.gen1 else SCREENS).duplicate() \
		if wanted == "all" else ([wanted] as Array[String])
	var columns: int = mini(COLUMNS, screens.size())
	@warning_ignore("integer_division")
	var rows: int = (screens.size() + columns - 1) / columns
	var sheet: Image = Image.create_empty(
		columns * Gen2Screen.WIDTH, rows * Gen2Screen.HEIGHT, false, Image.FORMAT_RGBA8
	)
	for index: int in screens.size():
		var tile: Image = page.image(_draw(page, screens[index]))
		@warning_ignore("integer_division")
		sheet.blit_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), Vector2i(
			(index % columns) * Gen2Screen.WIDTH, (index / columns) * Gen2Screen.HEIGHT
		))
	if sheet.save_png(args[1]) != OK:
		push_error("Could not write %s" % args[1])
		quit(1)
		return
	print("Wrote %s (%dx%d), %d screens, %s border." % [
		args[1], sheet.get_width(), sheet.get_height(), screens.size(),
		"tilemap" if page.has_screen_tilemap() else "textbox",
	])
	quit(0)


func _draw(page: Gen2LinkPage, screen: String) -> PackedByteArray:
	if page.gen1:
		return _draw_gen1(page, screen)
	match screen:
		"wait":
			return page.draw_please_wait()
		"record":
			return page.draw_record(_record(), PLAYER_NAME)
		"confirm":
			return page.draw_trade(_trade_state({
				"partner_choice": 1,
				"confirm": 0,
				"message": ["Trade CHIKORITA", "for SQUIRTLE?"],
			}))
		_:
			return page.draw_trade(_trade_state({"footer": Gen2LinkScreen.FOOTER_TRADE}))


func _draw_gen1(page: Gen2LinkPage, screen: String) -> PackedByteArray:
	match screen:
		"wait":
			return page.draw_please_wait()
		"stats":
			return page.draw_gen1_trade(_trade_state({"footer": Gen2LinkScreen.FOOTER_STATS, "held": true}))
		"confirm":
			return page.draw_gen1_trade(_trade_state({
				"held": true, "partner_choice": 1, "confirm": 0,
				"message": ["CHIKORITA and", "SQUIRTLE will"],
			}))
		"versus", "verdict":
			return page.draw_gen1_versus({
				"player": {"name": PLAYER_NAME, "balls": [0, 1, 2, 0, 3, 3]},
				"enemy": {"name": PARTNER_NAME, "balls": [0, 0, 2, 3, 3, 3]},
				"result": "" if screen == "versus" else String(page.strings.get("win", "YOU WIN")),
			})
		_:
			return page.draw_gen1_trade(_trade_state({"list": Gen2LinkScreen.LIST_PARTNER, "index": 1}))


func _trade_state(extra: Dictionary) -> Dictionary:
	var state: Dictionary = {
		"player": {"name": PLAYER_NAME, "species": PLAYER_PARTY.duplicate()},
		"partner": {"name": PARTNER_NAME, "species": PARTNER_PARTY.duplicate()},
		"list": Gen2LinkScreen.LIST_PLAYER,
		"index": 0,
		"cancel": false,
		"partner_choice": -1,
		"footer": -1,
		"confirm": -1,
		"message": [],
		"waiting": false,
	}
	for key: Variant in extra:
		state[key] = extra[key]
	return state


## A record with two opponents in it and three rows still empty, which is what
## `_DisplayLinkRecord` prints its dashes for.
func _record() -> Dictionary:
	var record: Dictionary = Gen2LinkSession.normalize_record({})
	for _win: int in 12:
		record = Gen2LinkSession.add_battle_to_record(
			record, {"name": PARTNER_NAME, "id": 4242}, &"wins"
		)
	record = Gen2LinkSession.add_battle_to_record(
		record, {"name": "SILVER", "id": 7}, &"losses"
	)
	return record


func _capture_animation(data: GameData, game: String, path: String, wanted: String) -> void:
	var page: Gen2TradeAnimationPage = Gen2TradeAnimationPage.from_data(data)
	var movie: Gen2TradeAnimation = Gen2TradeAnimation.create(
		data, Gen2BattleAnimData.from_game_data(data), _anim_context(data)
	)
	if page == null or movie == null:
		push_error("The %s cache carries no trade animation art." % game)
		quit(1)
		return
	var frames: Array[int] = ANIM_FRAMES.duplicate()
	if wanted.contains(":"):
		frames.clear()
		for value: String in wanted.split(":")[1].split(","):
			frames.append(int(value))
	frames.sort()
	var columns: int = mini(3, frames.size())
	@warning_ignore("integer_division")
	var rows: int = (frames.size() + columns - 1) / columns
	var sheet: Image = Image.create_empty(
		columns * Gen2Screen.WIDTH, rows * Gen2Screen.HEIGHT, false, Image.FORMAT_RGBA8
	)
	for index: int in frames.size():
		while not movie.finished() and movie.frame() < frames[index]:
			movie.advance_frame()
		var tile: Image = page.draw(movie)
		@warning_ignore("integer_division")
		sheet.blit_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), Vector2i(
			(index % columns) * Gen2Screen.WIDTH, (index / columns) * Gen2Screen.HEIGHT
		))
	if sheet.save_png(path) != OK:
		push_error("Could not write %s" % path)
		quit(1)
		return
	print("Wrote %s (%dx%d), frames %s." % [
		path, sheet.get_width(), sheet.get_height(), str(frames),
	])
	quit(0)


func _anim_context(data: GameData) -> Dictionary:
	return {
		"player": {
			"species": ANIM_PLAYER,
			"species_name": String(data.species(ANIM_PLAYER).get("name", "")),
			"sender_name": PLAYER_NAME, "ot_name": PLAYER_NAME,
			"ot_id": 12345, "caught_gender": 1,
		},
		"ot": {
			"species": ANIM_PARTNER,
			"species_name": String(data.species(ANIM_PARTNER).get("name", "")),
			"sender_name": PARTNER_NAME, "ot_name": PARTNER_NAME,
			"ot_id": 54321, "caught_gender": 2,
		},
		"link_mode": Gen2LinkSession.LINK_TRADECENTER,
	}
