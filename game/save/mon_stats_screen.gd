class_name Gen2MonStatsScreen
extends RefCounted

## The stats screen's model: which member of a list is shown, which page is open,
## and what each page has to say about it. The pages are the cartridge's three plus
## whatever mods have registered, and [Gen2StatsScreenPage] draws the answer.
## `StatsScreenInit` is opened over whatever screen asked for it and hands control
## back on the way out, so this owns no nodes. The list is the party in the two
## places STATS is reached from today; `wMonType` picks a different list on the
## cartridge, but the shape is the same for any of them, which is why the mons are
## passed in rather than read out of a save.

## `StatsScreen_Exit`: B, or A on the last page.
signal closed
## `PlayMonCry2`, which `StatsScreen_PlaceFrontpic` plays when a mon is loaded
## and not when a page is turned. Emitted rather than played: the audio player
## belongs to whoever embedded this.
signal cry_requested(species: int)

const PINK_PAGE: int = Gen2StatsScreenPage.PINK_PAGE

var _data: GameData = null
var _mons: Array = []
var _cursor: int = 0
## `wStatsScreenFlags`' page bits, `StatsScreenMain` opening on `PINK_PAGE`.
var _page: int = PINK_PAGE
## `.AnimateEgg`'s `ANIM_MON_MENU` and the strip it walks. Crystal alone ships
## them, so both stay empty on Gold and Silver.
var _animation: Gen2PicAnimation = null
var _animation_pixels: PackedByteArray = PackedByteArray()


static func create(data: GameData, mons: Array, start_cursor: int = 0) -> Gen2MonStatsScreen:
	var out := Gen2MonStatsScreen.new()
	out._data = data
	out._mons = mons
	out._cursor = clampi(start_cursor, 0, maxi(mons.size() - 1, 0))
	return out


## `StatsScreen_PlaceFrontpic`, called once the screen is up and again by
## [method handle_button] on every UP or DOWN. Crystal's cry is `ANIM_MON_MENU`'s
## opening `PokeAnim_CryNoWait`, so a Pokemon `CheckFaintedFrzSlp` answers yes
## for takes `.AnimateMon`'s still picture and is silent; Gold and Silver ship no
## animation and call `PlayMonCry` themselves, whatever the status.
func announce() -> void:
	_animation = null
	_animation_pixels = PackedByteArray()
	var mon: Gen2SaveMon = current()
	if mon == null or mon.is_egg or _data == null:
		return
	var record: Dictionary = _data.pic_animation(mon.species, _unown_form(mon))
	if record.is_empty():
		cry_requested.emit(mon.species)
		return
	if mon.hp <= 0 or Gen2Status.has(mon.status, Gen2Status.FREEZE) \
		or Gen2Status.is_asleep(mon.status):
		return
	var mirrored: bool = Gen2StatsScreenPage.pic_mirrored(mon.species, false)
	_animation = Gen2PicAnimation.new(
		record, Gen2PicAnimation.ANIM_MON_MENU, mirrored
	)
	_animation_pixels = Gen2BattleRenderer.padded_pic(
		_data, Gen2StatsScreenPage.pic_record(_data, snapshot()),
		Gen2PicAnimation.BOX, true,
		_data.species_pic_animation(mon.species, _unown_form(mon)), mirrored
	)


## One hardware frame of `StatsScreen_WaitAnim`'s `SetUpPokeAnim`, which stops on
## the frame `PokeAnim_Finish` sets its own exit and leaves the base picture up.
func advance_animation() -> void:
	if _animation == null:
		return
	var mon: Gen2SaveMon = current()
	if _animation.advance() != &"" and mon != null:
		cry_requested.emit(mon.species)
	if _animation.finished():
		_animation = null
		_animation_pixels = PackedByteArray()


## The box the animation is on, empty once it has ended and where there is none.
func animation_indices() -> PackedByteArray:
	if _animation == null:
		return PackedByteArray()
	return Gen2PicImage.animation_box_indices(
		_animation.box, _animation_pixels, Gen2PicAnimation.BOX
	)


## `GetUnownLetter` over the row's DVs, which the screen runs before it draws.
func _unown_form(mon: Gen2SaveMon) -> int:
	if mon == null or mon.species != Gen2Layout.UNOWN_SPECIES:
		return 0
	return Gen2Stats.unown_letter(mon.dvs)


func current() -> Gen2SaveMon:
	if _cursor < 0 or _cursor >= _mons.size():
		return null
	return _mons[_cursor] as Gen2SaveMon


func cursor() -> int:
	return _cursor


## `StatsScreen_JoypadAction`. Returns whether the button was used.
func handle_button(button: int) -> bool:
	## `EggStatsJoypad` masks the joypad down to `PAD_DOWN | PAD_UP | PAD_A |
	## PAD_B` before it reaches the same action, and answers A with the exit
	## rather than with a page: an egg has no pages to turn.
	var egg: bool = current() != null and current().is_egg
	match button:
		PokeButton.B:
			closed.emit()
			return true
		PokeButton.A:
			if egg or _page == _last_page():
				closed.emit()
				return true
			_turn_page(1)
			return true
		PokeButton.RIGHT:
			if egg:
				return false
			_turn_page(1)
			return true
		PokeButton.LEFT:
			if egg:
				return false
			_turn_page(-1)
			return true
		PokeButton.UP:
			return _move_cursor(-1)
		PokeButton.DOWN:
			return _move_cursor(1)
	return false


## `.d_right` and `.d_left`: the pages wrap in both directions, and a page change
## reloads the lower half without reloading the Pokémon.
func _turn_page(delta: int) -> void:
	_page = wrapi(
		_page - PINK_PAGE + delta, 0, Gen2StatsScreenPage.page_count()
	) + PINK_PAGE


## `.d_right`'s wrap point, which is the blue page until a mod registers one past
## it (see [method Gen2ModHost.register_stats_page]). A is the exit on this page
## and a page turn everywhere else, so both follow the count rather than BLUE.
func _last_page() -> int:
	return PINK_PAGE + Gen2StatsScreenPage.page_count() - 1


## `.d_up` and `.d_down`: neither wraps, and the row the party menu is left on
## follows the one this screen lands on (`wPartyMenuCursor`).
func _move_cursor(delta: int) -> bool:
	var next: int = _cursor + delta
	if next < 0 or next >= _mons.size():
		return false
	_cursor = next
	announce()
	return true


## Everything [Gen2StatsScreenPage] draws, for the member the cursor is on.
func snapshot() -> Dictionary:
	var mon: Gen2SaveMon = current()
	if mon == null or _data == null:
		return {"egg": true, "page": _page, "egg_message": ""}
	if mon.is_egg:
		## `wTempMonHappiness` holds an egg's remaining step count rather than a
		## happiness value, which is what `EggStatsScreen` reads it as.
		return {
			"egg": true,
			"page": _page,
			"species": mon.species,
			"egg_message": Gen2StatsScreenPage.egg_message(mon.happiness),
		}

	var battle_mon: Gen2BattleMon = Gen2SaveBattleAdapter.to_battle_mon(_data, mon)
	var species: Dictionary = _data.species(mon.species)
	var out: Dictionary = {
		"egg": false,
		"page": _page,
		"species": mon.species,
		"unown_form": _unown_form(mon),
		"dex_number": mon.species,
		"species_name": String(species.get("name", "")),
		"nickname": mon.nickname if not mon.nickname.is_empty() \
			else String(species.get("name", "")),
		"level": mon.level,
		"gender": Gen2BattleMon.gender_for(_data, mon.species, mon.dvs),
		"shiny": Gen2Stats.is_shiny(mon.dvs),
		"hp": mon.hp,
		"max_hp": battle_mon.max_hp() if battle_mon != null else 0,
		"status": mon.status,
		"fainted": mon.hp <= 0,
		"pokerus": mon.pokerus,
		"types": _types(species),
		## Neither is on a cartridge page. They are here because a registered
		## page is handed this snapshot and nothing else, and the two hidden
		## halves of a Pokémon are what such a page exists to say.
		"dvs": mon.dvs,
		"stat_exp": mon.stat_exp.duplicate(),
		"item_name": _data.item_name(mon.item) if mon.item != 0 \
			else Gen2StatsScreenPage.THREE_DASHES,
		"moves": _moves(mon),
		"ot_id": mon.ot_id,
		"ot_name": mon.original_trainer,
		## `.PlaceOTInfo` reads the whole caught-data byte, which this save model
		## splits into a gender bit and a location.
		"caught_gender": (mon.caught_gender << 7) | mon.caught_location,
		"stats": battle_mon.stats if battle_mon != null else {},
	}
	out.merge(_experience(mon))
	return out


## `PrintMonTypes`: a single-typed species really carries the same type twice and
## the second line is erased rather than printed.
func _types(species: Dictionary) -> Array:
	var pair: Array = species.get("types", [0, 0])
	var first: int = int(pair[0])
	var second: int = int(pair[1]) if pair.size() > 1 else first
	var out: Array = [_data.type_name(first)]
	if second != first:
		out.append(_data.type_name(second))
	return out


## `ListMoves` and `ListMovePP` over `wTempMonMoves`: an empty slot ends the list
## and the page draws dashes for the rest.
func _moves(mon: Gen2SaveMon) -> Array:
	var out: Array = []
	for slot: int in mon.moves.size():
		var number: int = int(mon.moves[slot])
		if number <= 0:
			break
		var record: Dictionary = _data.move(number)
		out.append({
			"name": String(record.get("name", "")),
			"pp": int(mon.pp[slot]) if slot < mon.pp.size() else 0,
			## `GetMaxPPOfMove` adds the PP Up bits, which this save model masks
			## off when it reads a party struct, so the base is the maximum.
			"max_pp": int(record.get("pp", 0)),
		})
	return out


## `.PrintNextLevel` and `.CalcExpToNextLevel`, which both leave a level 100
## Pokémon where it is: the next level is 100 again and the debt is zero.
func _experience(mon: Gen2SaveMon) -> Dictionary:
	var rate: int = int(
		_data.species(mon.species).get("growth_rate", Gen2Experience.GROWTH_MEDIUM_FAST)
	)
	if mon.level >= Gen2Experience.MAX_LEVEL:
		return {
			"exp": mon.exp,
			"next_level": Gen2Experience.MAX_LEVEL,
			"exp_to_next": 0,
			"exp_pixels": Gen2ExpBarAnimation.LENGTH_PX,
		}
	return {
		"exp": mon.exp,
		"next_level": mon.level + 1,
		"exp_to_next": maxi(Gen2Experience.total_exp_at(rate, mon.level + 1) - mon.exp, 0),
		"exp_pixels": Gen2ExpBarAnimation.pixels_for(rate, mon.level, mon.exp),
	}
