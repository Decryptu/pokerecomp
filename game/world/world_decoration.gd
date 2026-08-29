class_name Gen2WorldDecoration
extends RefCounted

## `engine/overworld/decorations.asm`: which decorations the player owns, the seven
## category menus `_PlayerDecorationMenu` opens over them, and the `DecoAction_*`
## that move one between a `wDeco*` slot and the room. Scene-free like the other
## world hosts. Ownership is an event flag and a placed decoration is a `wDeco*`
## slot, so nothing here is new save state. The imported `DecorationAttributes` row
## is the only source of a decoration's type, name parts, action, flag and block or
## sprite, so a mod repointing one takes all five with it.

## `constants/deco_constants.asm`' decoration types, which decide how
## `GetDecoName` spells a row rather than which category it is in.
const TYPE_PLANT: int = 1
const TYPE_BED: int = 2
const TYPE_CARPET: int = 3
const TYPE_POSTER: int = 4
const TYPE_DOLL: int = 5
const TYPE_BIG_DOLL: int = 6

## `DecorationNames` indices the name assembly reaches for by itself. Everything
## else a row names is either another entry of that list or a species.
const NAME_CANCEL: int = 0
const NAME_PUT_IT_AWAY: int = 1
const NAME_BED: int = 13
const NAME_CARPET: int = 14
const NAME_POSTER: int = 15
const NAME_DOLL: int = 16
const NAME_BIG: int = 17

## `DoDecorationAction2.DecoActions` indices. Zero is `DecoAction_nothing`, the
## CANCEL row's; every other action is a set-up/put-away pair over one slot.
const ACTION_NOTHING: int = 0

## The `wDeco*` slot each action pair owns. The ornament pair owns two, because
## `DecoAction_setupornament` asks which side of the room first.
const SLOT_BED: StringName = &"bed"
const SLOT_CARPET: StringName = &"carpet"
const SLOT_PLANT: StringName = &"plant"
const SLOT_POSTER: StringName = &"poster"
const SLOT_CONSOLE: StringName = &"console"
const SLOT_BIG_DOLL: StringName = &"big_doll"
const SLOT_LEFT_ORNAMENT: StringName = &"left_ornament"
const SLOT_RIGHT_ORNAMENT: StringName = &"right_ornament"

## `.DecoActions` as `{ action: [slot, sets up] }`. Read from the imported row
## rather than from the id, so the table decides which category a row is in.
const ACTIONS: Dictionary = {
	1: [SLOT_BED, true], 2: [SLOT_BED, false],
	3: [SLOT_CARPET, true], 4: [SLOT_CARPET, false],
	5: [SLOT_PLANT, true], 6: [SLOT_PLANT, false],
	7: [SLOT_POSTER, true], 8: [SLOT_POSTER, false],
	9: [SLOT_CONSOLE, true], 10: [SLOT_CONSOLE, false],
	11: [SLOT_BIG_DOLL, true], 12: [SLOT_BIG_DOLL, false],
	13: [SLOT_LEFT_ORNAMENT, true], 14: [SLOT_LEFT_ORNAMENT, false],
}

## `_PlayerDecorationMenu.category_pointers`' own order and its own strings,
## which are inline in the routine and reached by no script, so nothing imports
## them and they are this host's the way [Gen2WorldPC]'s BILL'S PC rows are.
## ORNAMENT is in front of BIG DOLL here and behind it in the id order.
const CATEGORIES: Array[Dictionary] = [
	{"slot": SLOT_BED, "name": "BED"},
	{"slot": SLOT_CARPET, "name": "CARPET"},
	{"slot": SLOT_PLANT, "name": "PLANT"},
	{"slot": SLOT_POSTER, "name": "POSTER"},
	{"slot": SLOT_CONSOLE, "name": "GAME CONSOLE"},
	{"slot": SLOT_LEFT_ORNAMENT, "name": "ORNAMENT"},
	{"slot": SLOT_BIG_DOLL, "name": "BIG DOLL"},
]
const CATEGORY_EXIT: String = "EXIT"

## `DecoAction_AskWhichSide`'s own three rows, and which slot each answers.
const SIDE_RIGHT: StringName = SLOT_RIGHT_ORNAMENT
const SIDE_LEFT: StringName = SLOT_LEFT_ORNAMENT
const SIDE_ROWS: Array[Dictionary] = [
	{"side": SIDE_RIGHT, "name": "RIGHT SIDE"},
	{"side": SIDE_LEFT, "name": "LEFT SIDE"},
	{"side": &"", "name": "CANCEL"},
]

## `PopulateDecoCategoryMenu`: eight rows fit the non-scrolling menu, and a
## ninth turns it into `ScrollingMenu` and costs the list its CANCEL row.
const CATEGORY_MENU_HEIGHT: int = 8

## `ToggleMaptileDecorations`' four `changeblock` coordinates. The carpet is
## four blocks rather than one, and its own three are the sprite byte plus one,
## two and one again.
const MAPTILE_AT: Dictionary = {
	SLOT_BED: Vector2i(0, 4),
	SLOT_PLANT: Vector2i(7, 4),
	SLOT_POSTER: Vector2i(6, 0),
}
const CARPET_AT: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(0, 2), Vector2i(2, 2), Vector2i(4, 2),
]
const CARPET_BLOCK_STEP: Array[int] = [0, 1, 2, 1]

## `ToggleDecorationsVisibility`: which object event flag each of the four object
## slots masks, and the `wVariableSprites` slot it fills when one is out.
## `EVENT_PLAYERS_HOUSE_2F_*` and `SPRITE_CONSOLE` and up are the same numbers on
## all three cartridges.
const OBJECT_SLOTS: Array[Dictionary] = [
	{"slot": SLOT_CONSOLE, "flag": 1857, "variable_sprite": 0xF0},
	{"slot": SLOT_LEFT_ORNAMENT, "flag": 1858, "variable_sprite": 0xF1},
	{"slot": SLOT_RIGHT_ORNAMENT, "flag": 1859, "variable_sprite": 0xF2},
	{"slot": SLOT_BIG_DOLL, "flag": 1860, "variable_sprite": 0xF3},
]

## The wording of the boxes `_PlayerDecorationMenu` prints, which are
## `text_far` stubs in `data/text/common_1.asm` that no script reaches, so they
## are this host's the way [Gen2WorldPack]'s hold and swap boxes are.
const TEXT_NOTHING_TO_CHOOSE: String = "There's nothing to\nchoose."
const TEXT_ALREADY_SET_UP: String = "That's already set\nup."
const TEXT_NOTHING_TO_PUT_AWAY: String = "There's nothing to\nput away."
const TEXT_WHICH_SIDE_PUT_ON: String = "Which side do you\nwant to put it on?"
const TEXT_WHICH_SIDE_PUT_AWAY: String = "Which side do you\nwant to put away?"


static func set_up_text(name: String) -> String:
	return "Set up the\n%s." % name


static func put_away_text(name: String) -> String:
	return "Put away the\n%s." % name


## `PutAwayAndSetUpText`, whose second half is a `para` rather than a line.
static func put_away_and_set_up_text(put_away: String, set_up: String) -> String:
	return "Put away the\n%s\n\nand set up the\n%s." % [put_away, set_up]


## `GetDecoName`: a row's type decides which parts its name is spelled from, and
## the poster, doll and big doll name a species where the others name a
## `DecorationNames` entry. Empty for a row outside the table.
static func decoration_name(data: GameData, deco: int) -> String:
	if data == null:
		return ""
	var row: Dictionary = data.decoration(deco)
	if row.is_empty():
		return ""
	var part: int = int(row.get("name", 0))
	match int(row.get("type", 0)):
		TYPE_PLANT:
			return data.decoration_name_part(part)
		TYPE_BED:
			return data.decoration_name_part(part) + data.decoration_name_part(NAME_BED)
		TYPE_CARPET:
			return data.decoration_name_part(part) + data.decoration_name_part(NAME_CARPET)
		TYPE_POSTER:
			return _species_name(data, part) + data.decoration_name_part(NAME_POSTER)
		TYPE_DOLL:
			return _species_name(data, part) + data.decoration_name_part(NAME_DOLL)
		TYPE_BIG_DOLL:
			return data.decoration_name_part(NAME_BIG) + _species_name(data, part)
	return ""


static func _species_name(data: GameData, species: int) -> String:
	return String(data.species(species).get("name", ""))


## The `wDeco*` slot a row's action belongs to, or an empty name for the CANCEL
## row and for an action no `DecoAction_*` answers.
static func slot_of(data: GameData, deco: int) -> StringName:
	var action: int = int(data.decoration(deco).get("action", ACTION_NOTHING)) \
		if data != null else ACTION_NOTHING
	var pair: Variant = ACTIONS.get(action, null)
	return StringName((pair as Array)[0]) if pair is Array else &""


## Whether a row is its category's PUT IT AWAY header rather than a decoration.
static func is_put_away(data: GameData, deco: int) -> bool:
	var action: int = int(data.decoration(deco).get("action", ACTION_NOTHING)) \
		if data != null else ACTION_NOTHING
	var pair: Variant = ACTIONS.get(action, null)
	return pair is Array and not bool((pair as Array)[1])


## `DecorationFlagAction CHECK_FLAG`: the row's own `DECOATTR_EVENT_FLAG`. The
## header rows all name `EVENT_TEMPORARY_UNTIL_MAP_RELOAD_1`, so ownership is
## only ever asked of a set-up row.
static func owns(data: GameData, state: Gen2WorldState, deco: int) -> bool:
	if data == null or state == null:
		return false
	var row: Dictionary = data.decoration(deco)
	if row.is_empty():
		return false
	return state.is_event_flag_active(int(row.get("flag", -1)))


## `DecorationIDs` indices the code names for itself. The two trophy dolls sit
## past `NUM_NON_TROPHY_DECOS`, which is why Mystery Gift can never send one.
const DECOFLAG_GOLD_TROPHY_DOLL: int = 43
const DECOFLAG_SILVER_TROPHY_DOLL: int = 44


## `GetDecorationID`: which decoration a `DECOFLAG_*` index names. The two orders
## are not the same, and neither is a rule: the flag order runs the dolls in
## front of the big dolls where the id order runs them behind, and the flag order
## has no header rows in it at all. Answers 0, the CANCEL row, for an index the
## imported table does not carry.
static func decoration_for_flag(data: GameData, flag_index: int) -> int:
	return data.decoration_id_for_flag(flag_index) if data != null else 0


## `SetSpecificDecorationFlag`, the one entry every gift takes: Mystery Gift's
## own copy walk, and the two trophy boxes. Its argument is a `DECOFLAG_*`, so it
## runs `GetDecorationID` first.
static func set_owned_by_flag(
	data: GameData, state: Gen2WorldState, flag_index: int, owned: bool = true
) -> bool:
	return set_owned(data, state, decoration_for_flag(data, flag_index), owned)


## `DecorationFlagAction SET_FLAG` on a decoration id, which is what
## `SetSpecificDecorationFlag` reaches once the index is resolved.
static func set_owned(
	data: GameData, state: Gen2WorldState, deco: int, owned: bool = true
) -> bool:
	if data == null or state == null:
		return false
	var row: Dictionary = data.decoration(deco)
	if row.is_empty() or is_put_away(data, deco):
		return false
	state.set_event_flag(int(row.get("flag", -1)), owned)
	return true


## `.FindCategoriesWithOwnedDecos`: only a category the player owns something in
## is on the top menu, and EXIT is always its last row.
static func categories(data: GameData, state: Gen2WorldState) -> Array:
	var out: Array = []
	for category: Dictionary in CATEGORIES:
		var slot: StringName = StringName(category["slot"])
		if _owned_in(data, state, slot).is_empty():
			continue
		out.append({"slot": slot, "name": String(category["name"])})
	out.append({"slot": &"", "name": CATEGORY_EXIT})
	return out


## `FindOwnedDecosInCategory`: the owned rows in id order, then the category's
## own PUT IT AWAY, then CANCEL. `PopulateDecoCategoryMenu.beyond_eight` drops
## that last row once the list is longer than the menu, which is what the
## ornament category reaches.
static func category_rows(
	data: GameData, state: Gen2WorldState, slot: StringName
) -> Array:
	var owned: Array = _owned_in(data, state, slot)
	if owned.is_empty():
		return []
	var out: Array = []
	for deco: int in owned:
		out.append({"deco": deco, "name": decoration_name(data, deco)})
	var header: int = _header_of(data, slot)
	if header >= 0:
		out.append({"deco": header, "name": decoration_name(data, header)})
	if out.size() < CATEGORY_MENU_HEIGHT:
		out.append({"deco": 0, "name": decoration_name(data, 0)})
	return out


static func _owned_in(
	data: GameData, state: Gen2WorldState, slot: StringName
) -> Array:
	var out: Array = []
	if data == null or state == null or slot.is_empty():
		return out
	## The two ornament slots are one category, and `FindOwnedOrnaments` is the
	## left one's action either way.
	var wanted: StringName = SLOT_LEFT_ORNAMENT if slot == SLOT_RIGHT_ORNAMENT else slot
	for deco: int in data.decoration_count():
		if slot_of(data, deco) != wanted or is_put_away(data, deco):
			continue
		if owns(data, state, deco):
			out.append(deco)
	return out


static func _header_of(data: GameData, slot: StringName) -> int:
	if data == null:
		return -1
	var wanted: StringName = SLOT_LEFT_ORNAMENT if slot == SLOT_RIGHT_ORNAMENT else slot
	for deco: int in data.decoration_count():
		if slot_of(data, deco) == wanted and is_put_away(data, deco):
			return deco
	return -1


## Whether the chosen row needs `DecoAction_AskWhichSide` in front of it, which
## is the ornament category and nothing else.
static func asks_side(data: GameData, deco: int) -> bool:
	return slot_of(data, deco) == SLOT_LEFT_ORNAMENT


## `DoDecorationAction2`: set the chosen decoration up in its slot, or put away
## whatever stands there. [param side] is the ornament slot
## `DecoAction_AskWhichSide` answered with and is ignored by every other
## category. The answer carries the box the source prints and whether the room
## changed, which is `wChangedDecorations` and what makes the map reload.
static func apply(
	world: Gen2WorldAPI, save: Gen2SaveData, deco: int, side: StringName = &"",
	persist: bool = true
) -> Dictionary:
	if world == null or world.data == null or world.state == null:
		return Gen2WorldTransaction.failure(&"missing_world", {})
	var data: GameData = world.data
	var row: Dictionary = data.decoration(deco)
	if row.is_empty():
		return Gen2WorldTransaction.failure(&"unknown_decoration", {"decoration": deco})
	var slot: StringName = slot_of(data, deco)
	if slot.is_empty():
		return {"ok": true, "changed": false, "text": ""}
	if slot == SLOT_LEFT_ORNAMENT:
		if side != SLOT_LEFT_ORNAMENT and side != SLOT_RIGHT_ORNAMENT:
			return Gen2WorldTransaction.failure(&"decoration_side_required", {
				"decoration": deco,
			})
		slot = side
	var standing: int = world.state.maptile_decoration(slot)
	var change: Dictionary = _decoration_change(data, world, deco, standing)
	if not change.has("next"):
		return change
	var next: int = int(change["next"])
	var text: String = String(change["text"])
	var writes: Dictionary = _decoration_writes(world, slot, next)
	var before: Gen2WorldSnapshot = world.snapshot()
	for written: StringName in writes:
		if world.state.set_maptile_decoration(written, int(writes[written])):
			continue
		Gen2WorldTransaction.restore(world, before)
		return Gen2WorldTransaction.failure(&"decoration_state_failed", {
			"decoration": deco, "slot": written,
		})
	var committed: Dictionary = Gen2WorldTransaction.run(world, save, before, persist)
	if not bool(committed.get("ok", false)):
		return committed
	return {
		"ok": true, "changed": true, "text": text, "slot": slot, "decoration": next,
	}


static func _decoration_change(
	data: GameData, world: Gen2WorldAPI, deco: int, standing: int
) -> Dictionary:
	if is_put_away(data, deco):
		## `DecoAction_TryPutItAway` clears the slot before it looks at what was
		## in it, so an empty slot is still cleared and the box is the refusal.
		if standing == 0:
			return {"ok": true, "changed": false, "text": TEXT_NOTHING_TO_PUT_AWAY}
		return {"next": 0, "text": put_away_text(decoration_name(data, standing))}
	if not owns(data, world.state, deco):
		return Gen2WorldTransaction.failure(&"decoration_not_owned", {"decoration": deco})
	if standing == deco:
		## `DecoAction_SetItUp.alreadythere` is the one refusal that leaves the
		## slot alone.
		return {"ok": true, "changed": false, "text": TEXT_ALREADY_SET_UP}
	var text: String = set_up_text(decoration_name(data, deco)) if standing == 0 \
		else put_away_and_set_up_text(
			decoration_name(data, standing), decoration_name(data, deco)
		)
	return {"next": deco, "text": text}


## `DecoAction_SetItUp_Ornament.getwhichside`: a doll set up on one side is taken
## off the other, so the room never holds two of the same ornament.
static func _decoration_writes(world: Gen2WorldAPI, slot: StringName, next: int) -> Dictionary:
	var writes: Dictionary = {slot: next}
	if next == 0 or (slot != SLOT_LEFT_ORNAMENT and slot != SLOT_RIGHT_ORNAMENT):
		return writes
	var other: StringName = SLOT_RIGHT_ORNAMENT if slot == SLOT_LEFT_ORNAMENT \
		else SLOT_LEFT_ORNAMENT
	if world.state.maptile_decoration(other) == next:
		writes[other] = 0
	return writes
