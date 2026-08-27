extends RefCounted

## Everything a mod can register that is not a renderer, in one file.
##
## Nothing here is a scene node, a cartridge read or an engine internal: the mod
## is handed the host, registers, and returns. What it registers is then read
## back by the ordinary engine, which never learns that a mod defined any of it.
##
## Copy this directory into `user://mods/` to run it.

## Mod numbers start at Gen2ContentOverlay.FIRST_MOD_NUMBER, which is 256: every
## cartridge content number fits in a byte, so anything above one is
## unambiguously not the cartridge's, and these numbers mean the same thing on
## Gold, Silver and Crystal.
## Numbering is per kind, so the first species and the first move share one.
const VOLTLING: int = Gen2ContentOverlay.FIRST_MOD_NUMBER
## What VOLTLING becomes, a cartridge species so the evolution is visibly the
## engine's own rather than one more defined row.
const RAICHU: int = 26
const STATIC_FIELD: int = Gen2ContentOverlay.FIRST_MOD_NUMBER
## An effect byte no cartridge move carries.
const RECOIL_AND_PARALYSE: int = 0xF0

const ELECTRIC: int = RomLayout.TYPE_ELECTRIC
## A type of the mod's own. Types are the one kind numbered from zero, the
## cartridge chart being zero-based, so a DEFINED one still sits past 256.
const PLASMA: int = Gen2ContentOverlay.FIRST_MOD_NUMBER
## An item of the mod's own, and the pack pocket it lands in. A mod pocket is at
## or above Gen2ModHost.FIRST_MOD_POCKET; 1 to 4 are the cartridge's.
const CELL_BATTERY: int = Gen2ContentOverlay.FIRST_MOD_NUMBER
const CURIOS_POCKET: int = Gen2ModHost.FIRST_MOD_POCKET
## Cartridge numbers, for the two rows this mod changes rather than adds.
const PIKACHU: int = 25
const THUNDERBOLT: int = 85

## This mod's own id, kept because a subscriber is called back long after
## `register` returned and a request the host records names whose it was.
var _id: StringName = &""


func register(host: Gen2ModHost, manifest: Gen2ModManifest) -> void:
	_id = manifest.id
	_add_a_type(host, manifest.id)
	_add_a_species(host, manifest.id)
	_add_a_move(host, manifest.id)
	_add_an_item_and_its_shelf(host, manifest.id)
	_add_a_control(host, manifest.id)
	_populate_the_map(host, manifest.id)
	_walk_something_behind_the_player(host, manifest.id)
	_add_a_stats_page(host, manifest.id)
	_rebalance(host, manifest.id)
	_play_differently(host, manifest)
	_watch(host, manifest.id)


## A type, and the two chart exceptions that make it mean something
## (`api_version` 4).
##
## The chart is a sparse table of exceptions, so a pair nobody names is already
## neutral: there is no row to define and matchups are patched even for a type
## this mod invented. `physical` is which stat pair the type uses, which
## Generation II decides by type number rather than per move, so a number past
## the cartridge chart has to say.
func _add_a_type(host: Gen2ModHost, id: StringName) -> void:
	host.register_content(Gen2ContentOverlay.KIND_TYPE, id, PLASMA, {
		"name": "PLASMA",
		"physical": false,
	})
	# Multipliers are in tenths, the way the damage formula divides.
	host.patch_type_matchup(id, PLASMA, RomLayout.TYPE_STEEL, {
		"multiplier": RomLayout.MATCHUP_SUPER_EFFECTIVE,
	})
	host.patch_type_matchup(id, RomLayout.TYPE_GROUND, PLASMA, {
		"multiplier": RomLayout.MATCHUP_NOT_VERY_EFFECTIVE,
	})


## A whole Pokémon. Everything a species carries is a field on one row, so the
## learnset, the evolution and the TM flags are part of the definition rather
## than four separate registrations; anything left out gets the kind's default,
## which is why this does not have to name a hatch cycle or a gender ratio.
func _add_a_species(host: Gen2ModHost, id: StringName) -> void:
	host.register_content(Gen2ContentOverlay.KIND_SPECIES, id, VOLTLING, {
		"name": "VOLTLING",
		"stats": {
			"hp": 70, "attack": 65, "defense": 60,
			"speed": 115, "sp_attack": 110, "sp_defense": 70,
		},
		"types": [ELECTRIC, PLASMA],
		"catch_rate": 45,
		"base_exp": 180,
		"growth_rate": Gen2Experience.GROWTH_MEDIUM_FAST,
		"learnset": [
			{"level": 1, "move": 33},   # TACKLE
			{"level": 8, "move": 84},   # THUNDERSHOCK
			{"level": 20, "move": STATIC_FIELD},
			{"level": 36, "move": THUNDERBOLT},
		],
		# The item below names EVOLVE_TRADE, which is the method rather than the
		# target: a row with no held requirement ($FF) is what it answers.
		"evolutions": [{
			"method": RomLayout.EVOLVE_TRADE,
			"parameter": Gen2Evolution.TRADE_NO_ITEM,
			"condition": 0, "target": RAICHU,
		}],
		# The pic atlases hold the cartridge's own slots and nothing else, so a
		# defined species supplies decoded indices instead: two bits a pixel,
		# row-major, exactly tiles * tiles * 64 of them (`api_version` 4).
		"pics": {
			"front": {"tiles": 7, "indices": _plaid(7)},
			"back": {"tiles": 6, "indices": _plaid(6)},
		},
		# Eight tiles, the two 2x2 frames of the party menu's own strip. A
		# cartridge icon number, 1 to 38, borrows a picture that already exists.
		"icon": {"indices": _plaid(0, 8)},
		"palette": {"normal": [0x3F1F, 0x1084], "shiny": [0x7FE0, 0x1084]},
	})


## Two bits a pixel is four shades, and a readable placeholder is worth more here
## than a picture: the point of the example is the SHAPE the host takes.
func _plaid(tiles: int, count: int = 0) -> PackedByteArray:
	var pixels: int = count * 64 if count > 0 else tiles * tiles * 64
	var out: PackedByteArray = PackedByteArray()
	out.resize(pixels)
	for at: int in pixels:
		out[at] = ((at >> 3) + at) & 3
	return out


## A move, and the effect that decides what it does.
##
## The effect is registered before the move, because a move's effect byte is only
## a number until something answers for it, and a list naming a step that does
## not exist is refused at registration rather than failing mid-turn.
func _add_a_move(host: Gen2ModHost, id: StringName) -> void:
	# The cartridge's own lists are in Gen2MoveEffect and the steps in
	# Gen2EffectCommands. This is NORMAL_HIT with the recoil of Take Down and the
	# paralysis chance of Body Slam, which no cartridge effect combines.
	host.register_move_effect(id, RECOIL_AND_PARALYSE, [
		Gen2EffectCommands.USED_MOVE_TEXT,
		Gen2EffectCommands.DO_TURN,
		Gen2EffectCommands.DAMAGE_CALC,
		Gen2EffectCommands.CHECK_IMMUNE,
		Gen2EffectCommands.CHECK_HIT,
		Gen2EffectCommands.EFFECT_CHANCE,
		Gen2EffectCommands.APPLY_DAMAGE,
		Gen2EffectCommands.RECOIL,
		Gen2EffectCommands.CHECK_FAINT,
		Gen2EffectCommands.PARALYZE_TARGET,
		Gen2EffectCommands.END_MOVE,
	])
	host.register_content(Gen2ContentOverlay.KIND_MOVE, id, STATIC_FIELD, {
		"name": "STATICFIELD",
		"effect": RECOIL_AND_PARALYSE,
		"power": 95,
		"type": ELECTRIC,
		"accuracy": 230,
		"pp": 10,
		"effect_chance": 76,
	})


## An item, the pocket it lands in, and the mart shelf it is sold from
## (`api_version` 3).
##
## The shelf row is a MENU entry rather than content: the item exists whatever a
## mart sells, and `available` decides which marts carry it. A filter is handed
## the resolved mart, `mart_id` included, and a row is dropped when it answers
## false or when the cartridge shelf already sells that item.
func _add_an_item_and_its_shelf(host: Gen2ModHost, id: StringName) -> void:
	host.register_content(Gen2ContentOverlay.KIND_ITEM, id, CELL_BATTERY, {
		"name": "CELLBATTERY",
		"price": 800,
		"pocket": CURIOS_POCKET,
		# USE opens the party list, and the evolution it causes is a fact the
		# host acts on rather than a callback (`api_version` 9).
		"field_menu": Gen2WorldPack.ITEMMENU_PARTY,
		"evolution": {"method": RomLayout.EVOLVE_TRADE},
	})
	host.register_menu_entry(Gen2ModHost.MENU_PACK_POCKET, id, {
		"label": "CURIOS",
		"pocket": CURIOS_POCKET,
	})
	host.register_menu_entry(Gen2ModHost.MENU_MART, id, {
		"label": "CELLBATTERY",
		"item": CELL_BATTERY,
		# Half what the pack values it at, so the shelf price is visibly the
		# shelf's rather than the item's.
		"price": 400,
		"available": func(mart: Dictionary) -> bool:
			return int(mart.get("variant", 0)) == 0,
	})


## A control of the mod's own, as the two halves of one named axis
## (`api_version` 3).
##
## A mod cannot see the cartridge's eight and the screen claims every one of them
## first, so a raw keycode read out of `handle_world_input` would produce a
## control that cannot be rebound and does not exist on a touchscreen. A default
## already bound to one of the eight is dropped and reported rather than
## silently never firing, which is why neither of these is `A` or `D`.
func _add_a_control(host: Gen2ModHost, id: StringName) -> void:
	host.register_action(id, {
		"key": "survey_left", "label": "Survey left",
		"default": [{"kind": "key", "code": KEY_Q}],
	})
	host.register_action(id, {
		"key": "survey_right", "label": "Survey right",
		"default": [{"kind": "key", "code": KEY_E}],
	})


## Wild Pokemon standing on the map instead of a roll on every step
## (`api_version` 2), and the run's own rules deciding how they behave
## (`api_version` 5).
##
## The provider owns its population and nothing else: which cells a wild may
## stand on, which table each is checked against and what a battle costs all stay
## the host's. It is a RefCounted and never a Node, and its four methods are
## refused by name at registration.
func _populate_the_map(host: Gen2ModHost, id: StringName) -> void:
	host.register_visible_encounters(id, Population.new())


## One sprite in the world, petted and picking things up (`api_version` 7).
##
## An actor is PRESENTATION: it occupies no cell, blocks nothing and is in no
## snapshot. The three methods below it are required; `interact`, `take_requests`
## and a `sprites()` entry's `emote` are the optional three that make it a pet.
func _walk_something_behind_the_player(host: Gen2ModHost, id: StringName) -> void:
	host.register_world_actor(id, Pet.new())


## A fourth page on a Pokémon's stats screen (`api_version` 8).
##
## The mod answers WHERE its strings go and the host writes them with the
## screen's own font, so a page needs no node, no renderer and no art of its own.
## The lower half is rows 8 to 17 and a placement outside it is dropped, which is
## what keeps a page off the name, the level and the front pic. The snapshot is
## the same one the cartridge pages are drawn from, plus the two halves of a
## Pokémon none of them prints: the packed DV word and the stat experience.
func _add_a_stats_page(host: Gen2ModHost, id: StringName) -> void:
	host.register_stats_page(id, {"build": _build_stats_page})


func _build_stats_page(page: Dictionary) -> Array:
	var dvs: int = int(page.get("dvs", 0))
	var trained: Dictionary = page.get("stat_exp", {})
	var out: Array = [
		## The pink and blue pages' own divider, so the columns line up when a
		## player turns between them.
		{"divider": 10},
		{"text": "DV", "at": Vector2i(8, 8)},
		{"text": "STAT EXP", "at": Vector2i(11, 8)},
	]
	## HP's DV is derived from the low bit of the other four rather than stored,
	## and both special stats read one stat-experience counter, so five rows is
	## what the hardware has to say.
	var rows: Array = [
		["HP", Gen2Stats.hp_dv(dvs), "hp"],
		["ATTACK", Gen2Stats.attack_dv(dvs), "attack"],
		["DEFENSE", Gen2Stats.defense_dv(dvs), "defense"],
		["SPECIAL", Gen2Stats.special_dv(dvs), "special"],
		["SPEED", Gen2Stats.speed_dv(dvs), "speed"],
	]
	for index: int in rows.size():
		## `wListMovesLineSpacing`'s two rows, which every list on this screen
		## steps.
		var row: int = 9 + index * 2
		out.append({"text": String(rows[index][0]), "at": Vector2i(0, row)})
		out.append({"text": str(int(rows[index][1])).lpad(2), "at": Vector2i(8, row)})
		out.append({
			"text": str(int(trained.get(String(rows[index][2]), 0))).lpad(5),
			"at": Vector2i(14, row),
		})
	return out


## Rewriting how an event is PRESENTED, without changing what happened
## (`api_version` 4).
##
## One mutator per channel, ahead of every watcher, and the host refuses a return
## that changed the event's own kind: a mutator may dress a result and may not
## turn one result into another. This is why the pair is registered rather than
## the subscriber doing both jobs.
func _rewrite_presentation(host: Gen2ModHost, id: StringName) -> void:
	host.register_event_mutator(Gen2ModHost.CHANNEL_WORLD, id, _dress_world_event)


## `status` is the world channel's routing key and is left exactly as it came:
## the text a waiting result is showing is presentation, and which screen
## operation the result is is not.
func _dress_world_event(result: Dictionary) -> Dictionary:
	var event: Dictionary = result.get("event", {})
	if StringName(event.get("type", &"")) == &"text":
		event["text"] = String(event.get("text", "")).replace("PIKACHU", "VOLTLING")
		result["event"] = event
	return result


## A Pokemon walking one cell behind the player, which is what a follower mod is,
## and every optional half of the actor contract in one object.
class Pet:
	extends RefCounted

	## How long the heart stays up after a press, in world frames. The mod owns
	## the duration because the emote is a pose the host draws while it is asked
	## for, rather than an edge the host times.
	const HEART_FRAMES: int = 60
	const CYNDAQUIL: int = 155

	var _world: Gen2WorldAPI = null
	var _heart: int = 0
	var _outbox: Array = []

	func set_world(world: Gen2WorldAPI) -> void:
		_world = world

	func advance_frame() -> void:
		_heart = maxi(0, _heart - 1)
		_pick_up_what_it_walked_over()

	func sprites() -> Array:
		if _world == null:
			return []
		var entry: Dictionary = {
			"icon": _world.data.mon_menu_icon(CYNDAQUIL),
			"facing": _world.player_facing,
			"position_cells": Vector2(_cell()),
		}
		if _heart > 0:
			entry["emote"] = Gen2WorldActors.EMOTE_HEART
		return [entry]

	## Offered only a press no cartridge object, background event or tile branch
	## answered, so this can never shadow one. Answering true consumes it.
	func interact(cell: Vector2i, _facing: int) -> bool:
		if _world == null or cell != _cell():
			return false
		_heart = HEART_FRAMES
		## A mod may not play a sound, so it asks and the host spends it.
		_outbox.append({"kind": Gen2WorldActors.REQUEST_CRY, "species": CYNDAQUIL})
		return true

	## The one-shot outbox, drained once a world frame and emptied by the drain.
	func take_requests() -> Array:
		var out: Array = _outbox
		_outbox = []
		return out

	## And the other half a follower wants: a hidden item under the cell it is
	## standing on. The mod reads the map and names the cell; taking one is the
	## HOST's, because it writes the bag, the flag and the save.
	##
	## Asked from the read every frame and not remembered: the host drops an ask
	## for a cell already queued or already taken (`api_version` 18), so a mod
	## keeping its own set of what it has named would be holding a copy of host
	## state, and would never retry a cell the pack-full branch left clear.
	func _pick_up_what_it_walked_over() -> void:
		if _world == null:
			return
		for record: Dictionary in _world.hidden_items():
			if bool(record["taken"]) or (record["cell"] as Vector2i) != _cell():
				continue
			Gen2ModHost.instance().request_hidden_item(record["cell"])
			return

	## One cell behind the player, which is where a follower walks: the faced
	## cell reflected through the player, so no direction table is needed here.
	func _cell() -> Vector2i:
		return _world.player_cell - (_world.facing_cell() - _world.player_cell)


## The population itself. A separate object because a provider is a RefCounted
## the host holds by name, and because everything it is told is a SNAPSHOT: the
## context is a copy taken when the map or the player's pose changed, never a
## live handle on the world.
class Population:
	extends RefCounted

	## How many wanderers stand on a map, out of the cells the host says a wild
	## is allowed on at all.
	const POPULATION: int = 3

	## The light an entry's own colours are walked toward, and how far, on the
	## breath below. `api_version` 15: the host rounds the amount onto
	## `Gen2WorldEncounters.GLOW_RUNGS` and applies it where it already resolves
	## the species' palette, so nothing here draws a pixel and both views get it.
	const GLOW_COLOR := Color(1.0, 0.87, 0.35)
	const GLOW_PEAK: float = 0.5
	const GLOW_PERIOD_FRAMES: int = 48

	var _context: Dictionary = {}
	var _entries: Array = []
	var _generation: int = -1
	var _frame: int = 0

	func set_context(context: Dictionary) -> void:
		_context = context
		# `generation` is bumped on every map change, so this is the one test
		# that says "a new map" rather than "the player moved".
		if int(context.get("generation", -1)) == _generation:
			return
		_generation = int(context.get("generation", -1))
		_repopulate()

	## A raised cosine over `GLOW_PERIOD_FRAMES`, so a wanderer breathes gold
	## rather than wearing a badge. Send whatever curve you like: what reaches
	## the palette is the nearest of the host's own rungs, and an amount that
	## rounds to nothing carries no glow at all.
	func advance_frame() -> void:
		_frame += 1
		var phase: float = TAU * float(_frame % GLOW_PERIOD_FRAMES) \
			/ float(GLOW_PERIOD_FRAMES)
		var amount: float = 0.5 * (1.0 - cos(phase)) * GLOW_PEAK
		for entry: Dictionary in _entries:
			entry["glow"] = {"color": GLOW_COLOR, "amount": amount}

	func encounters() -> Array:
		return _entries

	## This provider's rule, which every provider owes its reader: an entry the
	## player fought is gone whatever the battle did.
	func battle_finished(id: StringName, _result: Dictionary) -> void:
		for at: int in _entries.size():
			if StringName((_entries[at] as Dictionary)["id"]) == id:
				_entries.remove_at(at)
				return

	func _repopulate() -> void:
		_entries = []
		var cells: PackedVector2Array = (
			_context.get("eligible", {}).get("grass", PackedVector2Array())
		)
		var table: Array = _context.get("tables", {}).get("grass", {}).get("slots", [])
		if cells.is_empty() or table.is_empty():
			return
		# `occupied` is who is standing where this frame: NPCs, item balls and
		# every other map object. It is beside `eligible` rather than inside it,
		# because the host would delete an entry an NPC walked over; refusing a
		# taken cell on spawn is this provider's own rule.
		var taken: Dictionary = {}
		for cell: Vector2 in _context.get("occupied", PackedVector2Array()):
			taken[Vector2i(cell)] = true
		# The run's seed rather than a fresh generator, so the same save walking
		# back onto the same map meets the same population.
		var rolls := RandomNumberGenerator.new()
		rolls.seed = int(_context.get("run_seed", 0)) ^ _generation
		# `Gen2Rules` is the run's own divergence flags and its challenge. Read
		# it, never write it, since a rule that changed mid-run would make the
		# save it produced unreproducible.
		var count: int = POPULATION
		if Gen2Rules.active().challenge == Gen2Rules.CHALLENGE_HARD:
			count += 1
		for at: int in mini(count, cells.size()):
			var slot: Dictionary = table[rolls.randi_range(0, table.size() - 1)]
			var cell: Vector2i = Vector2i(cells[rolls.randi_range(0, cells.size() - 1)])
			if taken.has(cell):
				continue
			_entries.append({
				"id": StringName("voltling_%d_%d" % [_generation, at]),
				"cell": cell,
				"facing": Gen2WorldSprite.FACING_DOWN,
				"species": int(slot.get("species", 0)),
				"level": int(slot.get("min_level", 2)),
				"dvs": Gen2BattleMon.PERFECT_DVS,
				# Asked for on spawn; the host drops a repeat inside
				# Gen2WorldEncounters.PULSE_FRAMES and draws nothing over a
				# Pokemon that is not shiny.
				"pulse": true,
			})


## The five registrations that change HOW the game is played rather than what is
## in it (`api_version` 13). Each is a read-only policy: the mod answers a
## question and the host owns the transaction, the screen and the text.
func _play_differently(host: Gen2ModHost, manifest: Gen2ModManifest) -> void:
	## An HM's field move without a party member who knows it. The host resolves
	## which item teaches which move, whether it is in the bag, the badge, the
	## tile and everything the move then does.
	host.register_field_move_source(manifest.id, FieldMoves.new())
	## The step an active Repel runs out on. The mod picks the weakest item it
	## owns; the prompt, the bag and the encounter ordering are the host's.
	host.register_repel_renewal(manifest.id, RepelRenewal.new())
	## How many DV words one wild is drawn with, which is the later games' charm.
	## The count is the mod's; the roll, the generator and the ceiling are the
	## host's, so an encounter stays inside the run's reproducible sequence.
	host.register_shiny_rolls(manifest.id, ShinyRolls.new())
	## Experience for a successful capture. Save bound, so the manifest
	## `register` was handed is the capability rather than the id.
	host.register_catch_experience(manifest, CatchExperience.new())
	## Read-only annotations on the battle interface, over whichever renderer is
	## selected. The snapshot carries the exact effectiveness of each move, so
	## nothing here copies the type chart.
	host.register_battle_info(manifest.id, BattleInfo.new())
	## A start-menu row that opens one of the HOST's screens: a mod never
	## receives one, so it names the opening and says when the row should be
	## there at all. The host applies its own party gate after the predicate.
	host.register_menu_entry(Gen2ModHost.MENU_START, manifest.id, {
		"label": "PC",
		"action": Gen2ModHost.START_ACTION_OPEN_BILLS_PC,
		"visible": func(_context: Dictionary) -> bool: return true,
	})
	_watch_the_run(host, manifest)


## What the run has achieved, what a mod does with it, and how it says so.
##
## Three seams, and they are one example because they are used together. The
## progress reading is every field the host already holds, as state the run has
## REACHED rather than a moment it passed, which is what lets a mod installed
## onto a save already played read what that save has. The page lists it. The
## notice says when a field moved.
func _watch_the_run(host: Gen2ModHost, manifest: Gen2ModManifest) -> void:
	## The page. The mod answers rows and nothing else: the host draws them with
	## the screen's own frame and font, so a page needs no node and no art.
	host.register_page(manifest.id, {"title": "BADGES", "rows": _badge_rows})
	## A second start-menu row, naming the page it opens. `page` is what lets a
	## mod with more than one row point one of them at its page.
	host.register_menu_entry(Gen2ModHost.MENU_START, &"new_content_badges", {
		"label": "BADGES",
		"action": Gen2ModHost.START_ACTION_OPEN_MOD_PAGE,
		"page": manifest.id,
	})
	_notice_id = manifest.id
	host.progress_changed.connect(_on_progress_changed)


var _notice_id: StringName = &""
## The last reading, so what moved is the difference rather than a copy of host
## state: a mod keeping its own count could not answer for a save it was
## installed onto, which is the whole reason the reading exists.
var _seen_badges: int = -1


## One row per badge, locked until it is won. `Gen2ModHost.progress` is the
## reading; `badges` is a Crystal-ordered mask whichever cartridge is open, so
## nothing here touches the Gold and Silver flag table.
func _badge_rows() -> Array:
	var mask: int = int(Gen2ModHost.instance().progress().get(&"badges", 0))
	var out: Array = []
	for badge: int in 8:
		out.append({
			"label": BADGE_NAMES[badge],
			"detail": "WON" if (mask & (1 << badge)) != 0 else "",
			"icon": {"badge": badge},
			"locked": (mask & (1 << badge)) == 0,
		})
	return out


const BADGE_NAMES: Array[String] = [
	"ZEPHYRBADGE", "HIVEBADGE", "PLAINBADGE", "FOGBADGE",
	"MINERALBADGE", "STORMBADGE", "GLACIERBADGE", "RISINGBADGE",
]


## A banner over the map when a badge is won. The first reading of a run is the
## save being opened rather than anything happening in it, so it is adopted
## silently: that is the difference between installing a mod onto a played save
## and playing the moment it awards.
func _on_progress_changed(progress: Dictionary) -> void:
	var mask: int = int(progress.get(&"badges", 0))
	var was: int = _seen_badges
	_seen_badges = mask
	if was < 0:
		return
	for badge: int in BADGE_NAMES.size():
		var bit: int = 1 << badge
		if (mask & bit) == 0 or (was & bit) != 0:
			continue
		## Refused rather than clipped when a line will not fit, and answered
		## with a reason either way. `get_badge` is one of the sounds the host
		## lends; the shiny sparkle is deliberately not among them.
		Gen2ModHost.instance().request_notice(_notice_id, {
			"title": "BADGE WON",
			"line": BADGE_NAMES[badge],
			"icon": {"badge": badge},
			"sound": &"get_badge",
		})


## One question, per move. That is the whole of what an alternate field-move
## source decides.
class FieldMoves:
	extends RefCounted

	func allows_field_move(_move: int) -> bool:
		return true


## Which owned Repel to spend, out of a copy of the bag. The weakest first, so
## a MAX REPEL is kept for when it is wanted.
class RepelRenewal:
	extends RefCounted

	const REPEL: int = 0x14
	const SUPER_REPEL: int = 0x2A
	const MAX_REPEL: int = 0x2B

	func repel_to_use(inventory: Dictionary) -> int:
		for item: int in [REPEL, SUPER_REPEL, MAX_REPEL]:
			if int(inventory.get(item, 0)) > 0:
				return item
		return 0


## How many words a wild's DVs are drawn from. 1 is the cartridge's own roll.
class ShinyRolls:
	extends RefCounted

	## The charm's own item number, read from the LIVE bag rather than from a
	## snapshot the context could carry: a mod that was handed the bag per wild
	## would answer for a bag one encounter out of date.
	const SHINY_CHARM: int = 0x19

	func shiny_rolls(_context: Dictionary) -> int:
		return 3 if int(Gen2ModHost.instance().inventory().get(SHINY_CHARM, 0)) > 0 else 1


## Read on every throw rather than once, so a switch the player turns off
## mid-run is off from the next capture.
class CatchExperience:
	extends RefCounted

	func awards_catch_experience() -> bool:
		return true


## What the battle looks like with the type chart already applied. The snapshot
## is plain values; the answer is placements on the cartridge's own 20x18 grid.
class BattleInfo:
	extends RefCounted

	## The three marks, as tiles rather than text: the interface font has no `+`
	## and its `▲` is a code the main font does not carry, so a symbol the
	## cartridge never printed is supplied here. Eight bytes of 1bpp, one a row,
	## bit 7 leftmost. A circle with a centre dot for super effective, a triangle
	## for resisted and an X for no effect at all.
	const MARK_SUPER: Array[int] = [0x3C, 0x42, 0x81, 0x99, 0x99, 0x81, 0x42, 0x3C]
	const MARK_RESISTED: Array[int] = [0x00, 0x10, 0x38, 0x38, 0x7C, 0x7C, 0xFE, 0x00]
	const MARK_IMMUNE: Array[int] = [0x00, 0x42, 0x24, 0x18, 0x18, 0x24, 0x42, 0x00]
	## Where the weather sits: a free corner above the enemy's panel.
	const WEATHER_AT: Vector2i = Vector2i(0, 0)

	func annotate_battle(snapshot: Dictionary) -> Array:
		var out: Array = []
		out.append_array(_effectiveness(snapshot))
		out.append_array(_stages(snapshot))
		out.append_array(_weather(snapshot))
		return out

	## One symbol a row, and only for an opponent this save had already seen:
	## the first meeting is not something a Pokedex could have told the player.
	func _effectiveness(snapshot: Dictionary) -> Array:
		var out: Array = []
		if String(snapshot.get("menu_stage", "")) != "move" 			or not bool(snapshot.get("enemy_seen_before", false)):
			return out
		var neutral: int = int(snapshot.get("neutral", 10))
		for index: int in (snapshot.get("move_rows", []) as Array).size():
			var row: Dictionary = (snapshot["move_rows"] as Array)[index]
			var against: int = int(row.get("effectiveness", neutral))
			if against == neutral:
				continue
			var mark: Array[int] = MARK_IMMUNE if against == 0 else (
				MARK_SUPER if against > neutral else MARK_RESISTED
			)
			## Where the host says `MoveSelectionScreen`'s rows are, and the one
			## column of a row nothing else is written in.
			var at: Vector2i = (snapshot["move_rows_at"] as Vector2i) \
				+ (snapshot["move_rows_step"] as Vector2i) * index
			out.append({
				"tile": mark, "at": Vector2i(int(snapshot["move_rows_right"]), at.y),
			})
		return out

	## The seven keys `Gen2BattleMon.stages` carries, said the way a player reads
	## them. The interface font has no `+`: the charmap's own arrows are what a
	## direction is written with, and a mod wanting a `+` supplies it as a tile.
	const STAGE_LABELS: Dictionary = {
		"attack": "ATK", "defense": "DEF", "speed": "SPD",
		"sp_attack": "SP.A", "sp_defense": "SP.D",
		"accuracy": "ACC", "evasion": "EVA",
	}

	## Only the stages that moved, said beside the side they affect.
	func _stages(snapshot: Dictionary) -> Array:
		var out: Array = []
		var rows: Array = [
			["player_stages", Vector2i(0, 8)], ["enemy_stages", Vector2i(0, 1)],
		]
		for row: Array in rows:
			var at: Vector2i = row[1]
			for key: String in (snapshot.get(row[0], {}) as Dictionary):
				var stage: int = int((snapshot[row[0]] as Dictionary)[key])
				if stage == 0:
					continue
				## No sign on a raised stage: `-` is the only one the cartridge
				## font has, so a bare number is the unambiguous reading.
				out.append({
					"text": "%s%d" % [STAGE_LABELS.get(key, key.to_upper()), stage],
					"at": at,
					## Bare battle scenery under it: white in the built-in arena
					## and whatever a native renderer staged in the others, so
					## the host is asked for the interface field behind these
					## cells. The move-row marks above ask for none, because
					## `MoveSelectionScreen`'s own box is already under them.
					"field": true,
				})
				at += Vector2i(0, 1)
		return out

	## A tile of the mod's own, since the cartridge has no weather glyph: eight
	## bytes of 1bpp, one a row, bit 7 leftmost. A [PackedByteArray] is not a
	## constant expression in GDScript, so the rows are and the array is built
	## where it is asked for.
	const SUN_ROWS: Array[int] = [0x18, 0x3C, 0x7E, 0xFF, 0xFF, 0x7E, 0x3C, 0x18]

	func _weather(snapshot: Dictionary) -> Array:
		if not Gen2Weather.is_active(int(snapshot.get("weather", 0))):
			return []
		return [{"tile": SUN_ROWS, "at": WEATHER_AT, "field": true}]


## Changing what the cartridge shipped, rather than adding to it. A patch names
## only the fields it changes, and a Dictionary field merges, so this moves one
## stat and one number and leaves everything else on both rows alone.
func _rebalance(host: Gen2ModHost, id: StringName) -> void:
	host.patch_content(Gen2ContentOverlay.KIND_SPECIES, id, PIKACHU, {
		"stats": {"speed": 110},
	})
	host.patch_content(Gen2ContentOverlay.KIND_MOVE, id, THUNDERBOLT, {"power": 90})


## Watching the game without changing it. Both channels carry the typed
## dictionaries the engine already produces, handed over as copies where the
## screen shows them, so a subscriber sees what the player sees and writing to
## one reaches nothing.
func _watch(host: Gen2ModHost, id: StringName) -> void:
	host.subscribe(Gen2ModHost.CHANNEL_BATTLE, id, _on_battle_event)
	host.subscribe(Gen2ModHost.CHANNEL_WORLD, id, _on_world_event)
	_rewrite_presentation(host, id)


func _on_battle_event(event: Dictionary) -> void:
	if StringName(event.get("type", &"")) == Gen2Battle.FAINTED:
		print("[new_content] side %d fainted" % int(event.get("side", -1)))
	## A capture arrives with its own `Gotcha!` line, so a line asked for here
	## lands behind it and in front of the nickname prompt. The tutorial catch
	## and a Bug Contest catch are excluded: neither is a Pokemon kept.
	if StringName(event.get("type", &"")) == Gen2Battle.CAUGHT \
		and not bool(event.get("tutorial", false)) \
		and not bool(event.get("contest", false)):
		Gen2ModHost.instance().request_battle_message(
			_id, "A shiny one!" if bool(event.get("shiny", false)) else "One for the DEX!"
		)


func _on_world_event(event: Dictionary) -> void:
	if StringName(event.get("status", &"")) == &"waiting":
		print("[new_content] the world is waiting on %s" % event.get("event", {}).get("type", ""))
