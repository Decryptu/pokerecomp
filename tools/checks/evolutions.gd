extends RefCounted

var _r: RefCounted = null

## Verifies every evolution row on freshly imported real caches against
## `EvolveAfterBattle`, for all three cartridges. The predicates in [Gen2Evolution]
## are what the field host and any link host share, so the census is what pins them:
## every row of every species is walked and answered rather than spot checked, which
## is what catches a method the importer misread or a predicate that answers the
## wrong branch. The real-cartridge counterpart to tests/unit/test_evolution.gd.

## data/pokemon/evos_attacks.asm, counted from the pins: every `db EVOLVE_*` in
## the file. Identical across the three, since no evolution changed between them.
const EXPECTED_ROWS: int = 122
## The ten EVOLVE_TRADE rows, as species to the item the row asks be HELD.
## $FF is the four that ask for nothing: KADABRA, MACHOKE, GRAVELER and HAUNTER.
const EXPECTED_TRADES: Dictionary = {
	64: 0xFF, 67: 0xFF, 75: 0xFF, 93: 0xFF,
	61: 0x52,   # POLIWHIRL, KING'S ROCK
	79: 0x52,   # SLOWPOKE, KING'S ROCK
	95: 0x8F,   # ONIX, METAL COAT
	123: 0x8F,  # SCYTHER, METAL COAT
	117: 0x97,  # SEADRA, DRAGON SCALE
	137: 0xAC,  # PORYGON, UP-GRADE
}


## `EvolveMon`'s sounds in order and what every count it spends adds up to with
## no driver to wait on: the `ld c, 50`, the `Delay3` behind SFX_TINK, the two
## pictures' loads, a frame for the old cry, the `ld c, 80`, the eight passes' 72
## wait frames and 72 picture changes of `Delay3` each, the `Delay3` behind the
## last change, two frames for the jingle and the `ld c, 40`. The new cry's frame
## opens a box and counts with the reveals. Measured on Red: 288 frames of flicker.
const GEN1_SFX: Array[int] = [Gen1Sfx.SFX_TINK, Gen1Sfx.SFX_GET_ITEM_2]
const GEN1_MUSIC: Array[int] = [
	Gen2EvolutionScreen.MUSIC_NONE, Gen2EvolutionScreen.MUSIC_EVOLUTION,
	Gen2EvolutionScreen.MUSIC_NONE,
]
const GEN1_COUNTED_FRAMES: int = 50 + 3 + 1 + 80 + 72 + 72 * 3 + 3 + 2 + 40
## The same up to the first wait frame, which B ends, and one press behind it.
const GEN1_CANCEL_COUNTED_FRAMES: int = 50 + 3 + 1 + 80 + 1
## The fit's answer for BULBASAUR and IVYSAUR, where Red spent 73 from the
## palette to the cry; Yellow's pictures pack differently.
const GEN1_BULBASAUR_LOAD_FRAMES: Dictionary = {
	RomRegistry.RED: 68, RomRegistry.BLUE: 68, RomRegistry.YELLOW: 71,
}
const GEN1_BULBASAUR: int = 1
const GEN1_IVYSAUR: int = 2
## The stone-less evolutions Red and Blue's `wCurItem` read allows, as the
## index of the player's battler to the species behind it. $20 is FIRE_STONE and
## MISSINGNO, which no party carries.
const GEN1_STONE_INDICES: Dictionary = {0x0A: "EXEGGUTOR", 0x21: "GROWLITHE", 0x22: "ONIX", 0x2F: "PSYDUCK"}
const GEN1_STONE_ROWS: int = 13
const GEN1_GUARD_FRAMES: int = 3000


func run(r: RefCounted) -> void:
	_r = r
	for game_id: StringName in _r.GAME_IDS:
		var data: GameData = GameData.open(game_id)
		if data == null:
			_r.fail("%s cache is unavailable. Import roms/%s.gbc first." % [game_id, game_id])
			continue
		_census(game_id, data)
		_verify_trades(game_id, data)
	_r.each_game_of(RomRegistry.GEN1, func() -> void:
		_verify_gen1_texts(_r.game_id, _r.data)
		_verify_gen1_stone_rows(_r.game_id, _r.data)
		_verify_gen1_screen(_r.game_id, _r.data, false)
		_verify_gen1_screen(_r.game_id, _r.data, true)
	)


## `evos_moves.asm`'s four boxes and Yellow's `RefusingText`.
func _verify_gen1_texts(game_id: StringName, data: GameData) -> void:
	for name: String in Gen1Layout.EVOLUTION_TEXT_AT:
		var text: String = data.special_text("evolution", name)
		_r.check(
			text.contains(Gen2TextStream.RAM_MARKER),
			"%s: the %s box carries no name marker: %s" % [game_id, name, JSON.stringify(text)]
		)
	_r.check(
		data.has_special_text("stone_refusal") == (game_id == RomRegistry.YELLOW),
		"%s: RefusingText is Yellow's alone." % game_id
	)
	if game_id == RomRegistry.YELLOW:
		_r.check(
			data.special_text("stone_refusal", "refusing").contains("refusing"),
			"%s: RefusingText does not decode." % game_id
		)


## Every species with a stone row against every species a player can have out:
## the row answers exactly when the battler's index is the stone's id, and Yellow
## never answers.
func _verify_gen1_stone_rows(game_id: StringName, data: GameData) -> void:
	var rows: int = 0
	var reachable: Array[String] = []
	for species: int in range(1, data.species_count() + 1):
		var mon: Gen2BattleMon = Gen2BattleMon.create(data, species, 20)
		if mon == null:
			continue
		for active: int in range(1, data.species_count() + 1):
			var index: int = int(data.species(active).get("index", 0))
			var expected: Dictionary = {}
			for row: Dictionary in data.evolutions(species):
				if int(row.get("method", 0)) == Gen2Layout.EVOLVE_ITEM \
					and int(row.get("parameter", 0)) == index:
					expected = row
					break
			var answered: Dictionary = Gen2Evolution.red_blue_stone_row(data, mon, active)
			if game_id == RomRegistry.YELLOW:
				expected = {}
			if not _r.check(
				answered.get("target", 0) == expected.get("target", 0),
				"%s: species %d with %d out answered %s, not %s." % [
					game_id, species, active, answered, expected,
				]
			):
				continue
			if not expected.is_empty():
				rows += 1
				reachable.append("%s+%s" % [
					data.species(species).get("name", ""), GEN1_STONE_INDICES.get(index, "?"),
				])
	_r.check(
		rows == (0 if game_id == RomRegistry.YELLOW else GEN1_STONE_ROWS),
		"%s: %d stone-less rows, not %d: %s" % [game_id, rows, GEN1_STONE_ROWS, reachable]
	)
	_r.note("%s: stone-less rows %s" % [game_id, ", ".join(reachable)])


## The screen driven on its own frames for the cartridge's first level evolution:
## the sounds, the palettes and the count it closes on, run through and cancelled.
func _verify_gen1_screen(game_id: StringName, data: GameData, cancel: bool) -> void:
	var plan: Dictionary = _first_gen1_plan(data)
	if not _r.check(not plan.is_empty(), "%s: no level evolution to drive." % game_id):
		return
	var screen := Gen2EvolutionScreen.new()
	screen.set_context(data, [plan])
	var heard: Dictionary = {"sfx": [], "music": [], "cries": [], "palettes": [], "map_music": 0}
	screen.sfx_requested.connect(func(index: int) -> void: (heard["sfx"] as Array).append(index))
	screen.music_requested.connect(func(index: int) -> void: (heard["music"] as Array).append(index))
	screen.cry_requested.connect(func(species: int) -> void: (heard["cries"] as Array).append(species))
	screen.map_music_requested.connect(func() -> void: heard["map_music"] += 1)
	var resolved: Array = []
	screen.resolved.connect(func(_plan: Dictionary, canceled: bool) -> void: resolved.append(canceled))
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	var frames: int = 0
	var reveal: int = 0
	var palette: PackedColorArray = PackedColorArray()
	while screen.phase() != Gen2EvolutionScreen.Phase.DONE and frames < GEN1_GUARD_FRAMES:
		frames += 1
		screen.advance_frame()
		if screen.gen1_palette() != palette:
			palette = screen.gen1_palette()
			(heard["palettes"] as Array).append(palette[1])
		var box: Gen2TextBox = screen.get("_text_box")
		if box.visible and box.is_revealing():
			reveal += 1
		if cancel and screen.phase() == Gen2EvolutionScreen.Phase.FLASH:
			screen.handle_button(PokeButton.B)
		elif screen.awaiting_press():
			screen.handle_button(PokeButton.A)
	(Engine.get_main_loop() as SceneTree).root.remove_child(screen)
	screen.free()
	var old_species: int = int(plan["old_species"])
	var new_species: int = int(plan["new_species"])
	var black: Color = data.world_palette(Gen1Layout.PAL_BLACK)[1]
	var expected_palettes: Array = [data.palette(old_species)[1], black]
	expected_palettes.append(data.palette(old_species if cancel else new_species)[1])
	var expected_cries: Array = [old_species, old_species if cancel else new_species]
	var loading: int = data.gen1_pic_load_frames(new_species) + Gen1Layout.PIC_BACK_COPY_FRAMES \
		+ data.gen1_pic_load_frames(old_species)
	var counted: int = loading + (GEN1_CANCEL_COUNTED_FRAMES if cancel else GEN1_COUNTED_FRAMES)
	var what: String = "cancelled" if cancel else "whole"
	_r.check(resolved == [cancel], "%s: the %s run resolved %s." % [game_id, what, resolved])
	_r.check(
		heard["sfx"] == (GEN1_SFX.slice(0, 1) if cancel else GEN1_SFX),
		"%s: %s sounds %s." % [game_id, what, heard["sfx"]]
	)
	_r.check(heard["music"] == GEN1_MUSIC, "%s: %s music %s." % [game_id, what, heard["music"]])
	_r.check(heard["cries"] == expected_cries, "%s: %s cries %s." % [game_id, what, heard["cries"]])
	_r.check(
		heard["palettes"] == expected_palettes,
		"%s: %s palettes %s, not %s." % [game_id, what, heard["palettes"], expected_palettes]
	)
	_r.check(int(heard["map_music"]) == 1, "%s: %s run restarted the map music %d times." % [
		game_id, what, heard["map_music"],
	])
	_r.check(
		frames == counted + reveal,
		"%s: the %s run took %d frames, not %d counted and %d revealing." % [
			game_id, what, frames, counted, reveal,
		]
	)
	_r.note("%s: %s run %d frames, %d of them printing, %d loading pictures" % [
		game_id, what, frames, reveal, loading,
	])
	var bulbasaur: int = data.gen1_pic_load_frames(GEN1_IVYSAUR) \
		+ Gen1Layout.PIC_BACK_COPY_FRAMES + data.gen1_pic_load_frames(GEN1_BULBASAUR)
	_r.check(
		bulbasaur == int(GEN1_BULBASAUR_LOAD_FRAMES.get(game_id, 0)),
		"%s: BULBASAUR's pictures loading in %d frames, not %d." % [
			game_id, bulbasaur, int(GEN1_BULBASAUR_LOAD_FRAMES.get(game_id, 0)),
		]
	)


## The first species with a level row, at that level, as `after_battle` plans it.
func _first_gen1_plan(data: GameData) -> Dictionary:
	for species: int in range(1, data.species_count() + 1):
		for row: Dictionary in data.evolutions(species):
			if int(row.get("method", 0)) != Gen2Layout.EVOLVE_LEVEL:
				continue
			var mon := Gen2SaveMon.new()
			mon.species = species
			mon.level = int(row["parameter"])
			mon.hp = 1
			mon.dvs = 0
			return Gen2Evolution.plan(data, mon, 0, row, true)
	return {}


## Every row of every species: the method is one the source defines, the target
## is a species this cache has, and `EVOLVE_STAT` carries the extra condition
## byte its four-byte entry is read for.
func _census(game_id: StringName, data: GameData) -> void:
	var rows: int = 0
	for species: int in range(1, data.species_count() + 1):
		for row: Dictionary in data.evolutions(species):
			rows += 1
			var method: int = int(row.get("method", 0))
			if not _r.check(
				method in Gen2Layout.EVOLVE_METHODS,
				"%s: species %d carries evolution method %d." % [game_id, species, method]
			):
				continue
			var target: int = int(row.get("target", 0))
			_r.check(
				target >= 1 and target <= data.species_count()
					and not data.species(target).is_empty(),
				"%s: species %d evolves into %d, which this cache has no row for." % [
					game_id, species, target,
				]
			)
			_r.check(
				method != Gen2Layout.EVOLVE_STAT or int(row.get("condition", 0)) in [
					Gen2Layout.ATTACK_OVER_DEFENSE, Gen2Layout.ATTACK_UNDER_DEFENSE,
					Gen2Layout.ATTACK_EQUALS_DEFENSE,
				],
				"%s: species %d's EVOLVE_STAT row has no Attack/Defense condition." % [
					game_id, species,
				]
			)
	_r.check(
		rows == EXPECTED_ROWS,
		"%s: %d evolution rows, not %d." % [game_id, rows, EXPECTED_ROWS]
	)


## `.trade`, over the whole corpus rather than the ten rows alone: every species
## is asked, so a predicate that answered the wrong row would be as loud as one
## that answered none. An EVERSTONE refuses; a row with a held requirement
## refuses until the item is held and then says it is spent.
func _verify_trades(game_id: StringName, data: GameData) -> void:
	var found: Dictionary = {}
	for species: int in range(1, data.species_count() + 1):
		var mon: Gen2BattleMon = Gen2BattleMon.create(data, species, 50)
		if mon == null:
			continue
		var bare: Dictionary = Gen2Evolution.trade_evolution(data, mon)
		var wanted: int = int(EXPECTED_TRADES.get(species, 0))
		if wanted == 0:
			_r.check(
				bare.is_empty(),
				"%s: species %d answered a trade evolution it has no row for." % [
					game_id, species,
				]
			)
			continue
		found[species] = true
		if wanted == Gen2Evolution.TRADE_NO_ITEM:
			_r.check(
				not bare.is_empty() and not bare.has("consumes_held_item"),
				"%s: species %d asks for a held item it should not." % [game_id, species]
			)
		else:
			_r.check(
				bare.is_empty(),
				"%s: species %d evolved without holding $%02X." % [game_id, species, wanted]
			)
			mon.item = wanted
			var held: Dictionary = Gen2Evolution.trade_evolution(data, mon)
			_r.check(
				int(held.get("consumes_held_item", 0)) == wanted,
				"%s: species %d does not spend the $%02X it evolved by." % [
					game_id, species, wanted,
				]
			)
		mon.item = Gen2Evolution.EVERSTONE
		_r.check(
			Gen2Evolution.trade_evolution(data, mon).is_empty(),
			"%s: species %d evolved by trade while holding an EVERSTONE." % [game_id, species]
		)
	_r.check(
		found.size() == EXPECTED_TRADES.size(),
		"%s: %d trade evolutions, not %d." % [game_id, found.size(), EXPECTED_TRADES.size()]
	)
