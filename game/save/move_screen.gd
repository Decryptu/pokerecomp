class_name Gen2MoveScreen
extends RefCounted

## The move screen's model (`MoveScreenLoop` in `engine/pokemon/mon_menu.asm`):
## which member is shown, which move the cursor is on and which is being moved.
## [Gen2MoveScreenPage] draws it. Like [Gen2MonStatsScreen] it owns no nodes, and
## two moves that trade places trade their PP too (`.place_move`).

signal closed  ## `.exit`, which is B with nothing held.
## `PlayClickSFX` on every press this screen answers, and `SFX_SWITCH_POKEMON`
## twice once two moves have traded places.
signal sfx_requested(index: int, waited: bool)
## `ChooseMoveToDelete`'s own answer, when the screen was opened as the move
## deleter's list rather than as `ManagePokemonMoves`: the row A landed on, or
## -1 for the carry `.b_button` sets.
signal selection_made(move_index: int)

var _data: GameData = null
var _party: Array = []
var _cursor: int = 0
var _row: int = 0  ## `wMenuCursorY` less one: the row the arrow is on.
var _held: int = -1  ## `wSwappingMove` less one: the row being moved, or -1 when nothing is held.
## `ChooseMoveToDelete`'s own list. `DeleteMoveScreen2DMenuData` accepts
## `PAD_UP | PAD_DOWN | PAD_A | PAD_B` and nothing else, so there is no cycling
## between members and no move to hold: A answers the caller and B is its carry.
var _deleting: bool = false
## `WaitSFX` behind every effect: no press is read while [member sound_busy] says one sounds.
var sound_busy: Callable = Gen2AudioPlayer.sound_wait
var _sound_holding: bool = false
var _sound_watch: Dictionary = {}
var _sound_then: Callable = Callable()


static func create(data: GameData, party: Array, start_cursor: int = 0) -> Gen2MoveScreen:
	var out := Gen2MoveScreen.new()
	out._data = data
	out._party = party
	out._cursor = clampi(start_cursor, 0, maxi(party.size() - 1, 0))
	return out


func current() -> Gen2SaveMon:
	if _cursor < 0 or _cursor >= _party.size():
		return null
	return _party[_cursor] as Gen2SaveMon


func cursor() -> int:
	return _cursor


## `ChooseMoveToDelete`: the same screen with the swap and the cycle taken off
## its accepted buttons.
func open_deletion() -> void:
	_deleting = true
	_held = -1
	_row = 0


## `MoveScreenLoop`'s joypad block, which `ScrollingMenuJoypad` has already
## narrowed to the control pad, A and B. Returns whether the button was used.
func handle_button(button: int) -> bool:
	if _sound_holding:
		return true
	match button:
		PokeButton.B:
			## `.ChooseMoveToDelete`'s own `.a_button` and `.b_button` reach
			## neither `PlayClickSFX` nor `WaitSFX`, where `MoveScreenLoop`'s
			## both do, so the deleter's list answers silently.
			if _deleting:
				selection_made.emit(-1)
				return true
			_play_then(Gen2Sfx.SFX_READ_TEXT_2, _press_b)
			return true
		PokeButton.A:
			if _deleting:
				selection_made.emit(_row)
				return true
			_play_then(Gen2Sfx.SFX_READ_TEXT_2, _press_a)
			return true
		PokeButton.UP:
			return _move_row(-1)
		PokeButton.DOWN:
			return _move_row(1)
		PokeButton.LEFT:
			return _cycle(-1)
		PokeButton.RIGHT:
			return _cycle(1)
	return false


## `.b_button` after its click: a held move is put back where it came from and
## the screen stays up; nothing held is the way out.
func _press_b() -> void:
	if _held >= 0:
		_row = _held
		_held = -1
		return
	closed.emit()


## `.a_button` after its click: the first press holds a move, the second places it.
func _press_a() -> void:
	if _held < 0:
		_held = _row
		return
	_swap(_held, _row)
	_held = -1


func _play_then(index: int, then: Callable = Callable()) -> void:
	sfx_requested.emit(index, true)
	_sound_watch = {}
	_sound_then = then
	_sound_holding = true
	advance_frame()


func advance_frame() -> void:
	if not _sound_holding or bool(sound_busy.call(_sound_watch)):
		return
	_sound_holding = false
	var then: Callable = _sound_then
	_sound_then = Callable()
	if then.is_valid():
		then.call()


## Neither `MoveScreen2DMenuData` nor `DeleteMoveScreen2DMenuData` sets
## `_2DMENU_WRAP_UP_DOWN`, so the cursor stops at either end.
func _move_row(delta: int) -> bool:
	var rows: int = _move_count()
	if rows <= 0:
		return false
	_row = clampi(_row + delta, 0, rows - 1)
	return true


## `.cycle_right` and `.cycle_left`: a step past either end and a step onto an
## egg both turn round, so the screen never lands on a member it cannot list.
## `.d_left` and `.d_right` refuse outright while a move is held.
func _cycle(delta: int) -> bool:
	if _held >= 0 or _deleting:
		return false
	var found: int = _next_listable(delta)
	if found < 0 or found == _cursor:
		return false
	_cursor = found
	_row = 0
	return true


## Whether there is a member that way worth an arrow, which is what
## `PlaceMoveScreenLeftArrow` and its sibling walk the party for.
func has_neighbour(delta: int) -> bool:
	var found: int = _next_listable(delta)
	return found >= 0 and found != _cursor


func _next_listable(delta: int) -> int:
	var at: int = _cursor + delta
	while at >= 0 and at < _party.size():
		var mon: Gen2SaveMon = _party[at] as Gen2SaveMon
		if mon != null and not mon.is_egg:
			return at
		at += delta
	return -1


func _move_count() -> int:
	var mon: Gen2SaveMon = current()
	if mon == null:
		return 0
	var count: int = 0
	for move: Variant in mon.moves:
		if int(move) <= 0:
			break
		count += 1
	return count


## `.place_move`: the two rows trade their move and their PP together, and the
## same row twice is a swap with itself, which changes nothing and still sounds.
func _swap(from: int, to: int) -> void:
	var mon: Gen2SaveMon = current()
	if mon == null:
		return
	if from != to:
		mon.swap_move_slots(from, to)
	## `.swap_moves` plays the same effect twice, waiting for each.
	_play_then(Gen2Sfx.SFX_SWITCH_POKEMON, _play_then.bind(Gen2Sfx.SFX_SWITCH_POKEMON))


## Everything [Gen2MoveScreenPage] draws.
func snapshot() -> Dictionary:
	var mon: Gen2SaveMon = current()
	if mon == null or _data == null:
		return {"moves": [], "cursor": 0, "held": -1}
	var moves: Array = []
	for slot: int in mon.moves.size():
		var number: int = int(mon.moves[slot])
		if number <= 0:
			break
		var record: Dictionary = _data.move(number)
		moves.append({
			"name": String(record.get("name", "")),
			"pp": int(mon.pp[slot]) if slot < mon.pp.size() else 0,
			"max_pp": mon.max_pp(_data, slot),
			"power": int(record.get("power", 0)),
			"type_name": _data.type_name(int(record.get("type", 0))),
			"description": String(record.get("description", "")),
		})
	## `SetUpMoveScreenBG`'s `SetHPPal` colours the box beside the nickname, and
	## the pixel count it reads is `wPlayerHPPal`'s last writer rather than a
	## fresh one, which in play is this Pokémon's own bar in the party list.
	var battle_mon: Gen2BattleMon = Gen2SaveBattleAdapter.to_battle_mon(_data, mon)
	return {
		"species": mon.species,
		"hp": mon.hp,
		"max_hp": battle_mon.max_hp() if battle_mon != null else 0,
		"nickname": mon.nickname if not mon.nickname.is_empty() \
			else String(_data.species(mon.species).get("name", "")),
		"level": mon.level,
		"moves": moves,
		"cursor": clampi(_row, 0, maxi(moves.size() - 1, 0)),
		"held": _held,
		## `PlaceMoveScreenArrows` is `MoveScreenLoop`'s own call and not
		## `SetUpMoveScreenBG`'s, so the deleter's list carries neither arrow:
		## `.ChooseMoveToDelete` never reaches it.
		"previous": not _deleting and has_neighbour(-1),
		"next": not _deleting and has_neighbour(1),
	}
