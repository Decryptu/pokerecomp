extends GutTest

## `TradeAnimation`'s jumptable, driven without a cache. Every frame count here
## is the cartridge's own: the commands count in `wFrameCounter` and spend
## `DelayFrames`, neither of which depends on the art being imported, so both
## scripts run with no [GameData] at all. `AnimateTrademonFrontpic` is the one
## command that does depend on it and advances instead. tools/checks/link.gd is
## what checks the art it draws with.

const FRAME_CAP: int = 20000

## Both scripts with no pic animation behind them. Crystal's halves differ by its
## `wait_96` against a `wait_40`; Gold and Silver's are the same length, their
## two halves being the same commands in the other order.
const CRYSTAL_FRAMES: Array[int] = [2329, 2192]
const GOLD_SILVER_FRAMES: Array[int] = [2480, 2480]

## `SFX_BALL_POOF` twice, `SFX_POTION` twice, the give and get pair, and the
## twenty-six clicks the two tube bulges and the two balls between them ask for.
const SFX_TOTAL: int = 32
## `SFX_GIVE_TRADEMON` and `SFX_GET_TRADEMON`, one each per half.
const SFX_GIVE_TRADEMON: int = Gen2TradeAnimation.SFX_GIVE_TRADEMON
const SFX_GET_TRADEMON: int = Gen2TradeAnimation.SFX_GET_TRADEMON

const GIVEN: int = 152
const RECEIVED: int = 25


func _movie(half: int = 0, given: int = GIVEN, received: int = RECEIVED) -> Gen2TradeAnimation:
	return Gen2TradeAnimation.create(null, null, {
		"player": {
			"species": given, "species_name": "CHIKORITA", "sender_name": "RED",
			"ot_name": "RED", "ot_id": 12345, "caught_gender": 1,
		},
		"ot": {
			"species": received, "species_name": "PIKACHU", "sender_name": "BLUE",
			"ot_name": "BLUE", "ot_id": 54321, "caught_gender": 2,
		},
		"link_mode": Gen2LinkSession.LINK_TRADECENTER,
	}, half)


func _run(movie: Gen2TradeAnimation) -> Array:
	var events: Array = []
	while not movie.finished() and movie.frame() < FRAME_CAP:
		events.append_array(movie.advance_frame())
	return events


## Both halves reach `TradeAnim_End` on the cartridge's own frame.
func test_both_halves_run_to_the_exit_bit() -> void:
	for half: int in 2:
		var movie: Gen2TradeAnimation = _movie(half)
		_run(movie)
		assert_true(movie.finished(), "half %d never finished" % half)
		assert_eq(movie.frame(), CRYSTAL_FRAMES[half], "half %d" % half)


## `RunTradeAnimScript` opens on `PlayMusic2 MUSIC_EVOLUTION` and asks for
## nothing else.
func test_the_music_is_asked_for_once_and_first() -> void:
	var movie: Gen2TradeAnimation = _movie()
	var events: Array = movie.drain_events()
	events.append_array(_run(movie))
	var music: Array = []
	for event: Dictionary in events:
		if StringName(event["type"]) == &"play_music":
			music.append(event)
	assert_eq(music.size(), 1)
	assert_eq(int(music[0]["music"]), Gen2TradeAnimation.MUSIC_EVOLUTION)
	assert_eq(int(music[0]["frame"]), 0)


## The sounds both halves ask for, and the one pair that says which way a
## Pokemon is moving: the giving half sends before it receives.
func test_each_half_asks_for_the_same_sounds_in_its_own_order() -> void:
	for half: int in 2:
		var sfx: Array = []
		for event: Dictionary in _run(_movie(half)):
			if StringName(event["type"]) == &"play_sfx":
				sfx.append(int(event["sfx"]))
		assert_eq(sfx.size(), SFX_TOTAL, "half %d" % half)
		var sent: int = sfx.find(SFX_GIVE_TRADEMON)
		var received: int = sfx.find(SFX_GET_TRADEMON)
		assert_true(
			sent >= 0 and received >= 0, "half %d is missing a trade sound" % half
		)
		assert_eq(sent < received, half == 0, "half %d traded the wrong way" % half)


## `TradeAnim_ShowGivemonData`'s cry. With no cache behind it Crystal's
## `AnimateTrademonFrontpic` never runs, so the offered Pokemon's is the one cry.
func test_the_offered_pokemon_cries() -> void:
	var cries: Array = []
	for event: Dictionary in _run(_movie()):
		if StringName(event["type"]) == &"play_cry":
			cries.append(int(event["species"]))
	assert_eq(cries, [GIVEN])


## `IsOTTrademonEgg`, which advances the script pointer before it looks: an egg
## adds eighty frames to the first half and a hundred and eighty to the second.
func test_an_egg_partner_adds_its_own_wait() -> void:
	for half: int in 2:
		var movie: Gen2TradeAnimation = _movie(half, GIVEN, Gen2TradeAnimation.EGG)
		_run(movie)
		assert_eq(
			movie.frame() - CRYSTAL_FRAMES[half], 80 if half == 0 else 180,
			"half %d" % half
		)


## `TradeAnim_SentToOTText`'s `LINK_TIMECAPSULE` branch, which prints the one
## line and leaves rather than standing on an empty box for 189 frames.
func test_a_time_capsule_trade_skips_the_empty_box() -> void:
	var movie: Gen2TradeAnimation = Gen2TradeAnimation.create(null, null, {
		"player": {"species": GIVEN}, "ot": {"species": RECEIVED},
		"link_mode": Gen2LinkSession.LINK_TIMECAPSULE,
	})
	_run(movie)
	assert_eq(movie.frame(), CRYSTAL_FRAMES[0] - (189 + 128))


## `TradeAnim_EnterLinkTube2` and `TradeAnim_ExitLinkTube` walk `hSCX` between
## `$a0` and zero four pixels at a time, and `TradeAnim_DoGivemonScroll` walks
## `hWX` down to the seven every other command leaves it on.
func test_the_scroll_and_the_window_land_where_the_source_leaves_them() -> void:
	var movie: Gen2TradeAnimation = _movie()
	var scrolls: Dictionary = {}
	var windows: Dictionary = {}
	while not movie.finished() and movie.frame() < FRAME_CAP:
		movie.advance_frame()
		scrolls[movie.scroll_x()] = true
		windows[movie.window().x] = true
	assert_eq(movie.scroll_x(), 0)
	assert_eq(movie.window(), Vector2i(7, 0x90))
	assert_true(scrolls.has(0xA0), "the tube never scrolled in from $a0")
	assert_true(windows.has(0x8F), "the stats window never opened off screen")


## `PlaySpriteAnimations` over `wShadowOAM`: the ball, its poof, the tube bulge
## and the trademon's icon and bubble all reach the buffer, and none outlives
## the movie.
func test_every_sprite_the_movie_spawns_reaches_shadow_oam() -> void:
	var movie: Gen2TradeAnimation = _movie()
	var sets: Dictionary = {}
	var peak: int = 0
	while not movie.finished() and movie.frame() < FRAME_CAP:
		movie.advance_frame()
		peak = maxi(peak, movie.sprites().size())
		for sprite: Dictionary in movie.sprites():
			sets[int(sprite["set"])] = true
	var seen: Array = sets.keys()
	seen.sort()
	assert_eq(seen, [
		Gen2TradeAnimation.OAM_BALL_1, Gen2TradeAnimation.OAM_BALL_2,
		Gen2TradeAnimation.OAM_POOF_1, Gen2TradeAnimation.OAM_POOF_2,
		Gen2TradeAnimation.OAM_POOF_3, Gen2TradeAnimation.OAM_BULGE_1,
		Gen2TradeAnimation.OAM_BULGE_2, Gen2TradeAnimation.OAM_ICON_1,
		Gen2TradeAnimation.OAM_ICON_2, Gen2TradeAnimation.OAM_BUBBLE,
	])
	assert_eq(peak, 2, "more than the icon and its bubble were up at once")
	assert_eq(movie.sprites().size(), 0, "a sprite outlived the movie")


## `TradeAnim_AnimateTrademonInTube`: right to `$94` then down to `$4c` on one
## leg, up to `$2c` then left to `$58` on the other. Both halves run both legs,
## so the three corners the two walks share are all reached and `(88, 76)`,
## which neither turns on, is not.
func test_the_trademon_crosses_the_tube_both_ways() -> void:
	for half: int in 2:
		var movie: Gen2TradeAnimation = _movie(half)
		var seen: Dictionary = {}
		while not movie.finished() and movie.frame() < FRAME_CAP:
			movie.advance_frame()
			for sprite: Dictionary in movie.sprites():
				if int(sprite["set"]) in [
					Gen2TradeAnimation.OAM_ICON_1, Gen2TradeAnimation.OAM_ICON_2,
				]:
					seen[sprite["at"]] = true
		for corner: Vector2i in [
			Vector2i(0x58, 0x2C), Vector2i(0x94, 0x2C), Vector2i(0x94, 0x4C),
		]:
			assert_true(
				seen.has(corner), "half %d never put the icon on %s" % [half, corner]
			)
		assert_false(
			seen.has(Vector2i(0x58, 0x4C)), "half %d cut a corner" % half
		)


## `wFrameCounter2`'s low three bits, which `TradeAnim_FlashBGPals` gates the
## tube's own palette flash on: it xors `%00111100` and never lands anywhere
## else.
func test_the_tube_flashes_between_two_palette_orders() -> void:
	var movie: Gen2TradeAnimation = _movie()
	var orders: Dictionary = {}
	while not movie.finished() and movie.frame() < FRAME_CAP:
		movie.advance_frame()
		orders[movie.background_palette_index()] = true
	var seen: Array = orders.keys()
	seen.sort()
	assert_eq(seen, [0xD8, 0xE4])


## Gold and Silver run the same movie with four fewer commands: no `wait_96`, no
## `wait_40` and no pic animation, so their two halves are the same length.
func test_gold_and_silver_run_their_own_script() -> void:
	var data: GameData = GameData.open(&"gold")
	if data == null:
		pass_test("no Gold cache; the check topic runs this against all three")
		return
	for half: int in 2:
		var movie: Gen2TradeAnimation = Gen2TradeAnimation.create(
			data, null, {
				"player": {"species": GIVEN, "species_name": "CHIKORITA"},
				"ot": {"species": RECEIVED, "species_name": "PIKACHU"},
				"link_mode": Gen2LinkSession.LINK_TRADECENTER,
			}, half
		)
		_run(movie)
		assert_eq(movie.frame(), GOLD_SILVER_FRAMES[half], "half %d" % half)
