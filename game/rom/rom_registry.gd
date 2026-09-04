class_name RomRegistry
extends RefCounted

## The allowlist of ROMs this project can import from. The project ships no game
## data: a user-supplied dump is matched here by SHA-1 before a byte is read for
## content, and an unknown hash is a hard refusal, since an uncharacterised ROM
## has unknown bank layout and guessing produces corrupt assets rather than an
## honest error. Crystal's two common filenames are byte-identical and collapse to
## one entry: matching is by hash, never by filename.

const GEN1: int = 1
const GEN2: int = 2

## Cartridge size by generation, in bytes. Used only as a cheap pre-filter so a
## wrong file is rejected before we hash it; the hash is what decides.
const SIZES: Dictionary = {
	GEN1: 1048576,
	GEN2: 2097152,
}

const RED: StringName = &"red"
const BLUE: StringName = &"blue"
const YELLOW: StringName = &"yellow"
const GOLD: StringName = &"gold"
const SILVER: StringName = &"silver"
const CRYSTAL: StringName = &"crystal"

## sha1 (lowercase hex) -> { id, title, revision, generation, playable }
## `playable` is false while a generation has an importer but no world to walk:
## the launcher seats such a cartridge and reads it, and offers no Play.
const BY_SHA1: Dictionary = {
	"ea9bcae617fdf159b045185467ae58b2e4a48b9a": {
		"id": RED,
		"title": "Red",
		"revision": "USA/Europe",
		"generation": GEN1,
		"playable": false,
	},
	"d7037c83e1ae5b39bde3c30787637ba1d4c48ce2": {
		"id": BLUE,
		"title": "Blue",
		"revision": "USA/Europe",
		"generation": GEN1,
		"playable": false,
	},
	"cc7d03262ebfaf2f06772c1a480c7d9d5f4a38e1": {
		"id": YELLOW,
		"title": "Yellow",
		"revision": "USA/Europe",
		"generation": GEN1,
		"playable": false,
	},
	"d8b8a3600a465308c9953dfa04f0081c05bdcb94": {
		"id": GOLD,
		"title": "Gold",
		"revision": "USA/Europe",
		"generation": GEN2,
		"playable": true,
	},
	"49b163f7e57702bc939d642a18f591de55d92dae": {
		"id": SILVER,
		"title": "Silver",
		"revision": "USA/Europe",
		"generation": GEN2,
		"playable": true,
	},
	"f2f52230b536214ef7c9924f483392993e226cfb": {
		"id": CRYSTAL,
		"title": "Crystal",
		"revision": "USA/Europe Rev 1",
		"generation": GEN2,
		"playable": true,
	},
}

## Display order for the launcher shelf, oldest cartridge first.
const ORDER: Array[StringName] = [RED, BLUE, YELLOW, GOLD, SILVER, CRYSTAL]


static func is_known(sha1: String) -> bool:
	return BY_SHA1.has(sha1.to_lower())


## Returns the registry row for a hash, or an empty Dictionary if unknown.
static func lookup(sha1: String) -> Dictionary:
	return BY_SHA1.get(sha1.to_lower(), {})


## The registry row for a game id, or an empty Dictionary if the id is not ours.
static func row_for(id: StringName) -> Dictionary:
	for sha1: String in BY_SHA1:
		if BY_SHA1[sha1]["id"] == id:
			return BY_SHA1[sha1]
	return {}


## The hash that identifies a given game id, or "" if the id is not ours.
static func sha1_for(id: StringName) -> String:
	for sha1: String in BY_SHA1:
		if BY_SHA1[sha1]["id"] == id:
			return sha1
	return ""


static func title_for(id: StringName) -> String:
	return row_for(id).get("title", "")


static func generation_for(id: StringName) -> int:
	return int(row_for(id).get("generation", 0))


static func is_generation(id: StringName, generation: int) -> bool:
	return generation_for(id) == generation


## Whether selecting this cartridge in the launcher can start a game.
static func is_playable(id: StringName) -> bool:
	return bool(row_for(id).get("playable", false))


## Every id of a generation, in [constant ORDER].
static func ids_of_generation(generation: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in ORDER:
		if generation_for(id) == generation:
			out.append(id)
	return out


## The dump size a given cartridge must have, or 0 for an id we do not know.
static func size_for(id: StringName) -> int:
	return int(SIZES.get(generation_for(id), 0))


## Whether a file of this length could be one of ours at all.
static func is_known_size(size: int) -> bool:
	return SIZES.values().has(size)
