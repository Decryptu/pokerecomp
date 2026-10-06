class_name RomRegistry
extends RefCounted

## The allowlist of dumps this project imports, matched by SHA-1 and never by
## filename before a byte is read for content. An unknown hash is refused: an
## uncharacterised layout produces corrupt assets rather than an honest error.

const GEN1: int = 1
const GEN2: int = 2
const GEN3: int = 3

## Dump size by generation: a pre-filter before hashing, which alone decides.
const SIZES: Dictionary = {
	GEN1: 1048576,
	GEN2: 2097152,
	GEN3: 16777216,
}

## Which files a picker, a drop or a folder scan offers to the hash gate.
const EXTENSIONS: PackedStringArray = ["gb", "gbc", "gba"]

const RED: StringName = &"red"
const BLUE: StringName = &"blue"
const YELLOW: StringName = &"yellow"
const GOLD: StringName = &"gold"
const SILVER: StringName = &"silver"
const CRYSTAL: StringName = &"crystal"
const RUBY: StringName = &"ruby"
const SAPPHIRE: StringName = &"sapphire"
const FIRERED: StringName = &"firered"
const LEAFGREEN: StringName = &"leafgreen"
const EMERALD: StringName = &"emerald"

## sha1 (lowercase hex) -> { id, title, revision, generation, playable, dev }
## `playable` false offers no Play. A `dev` cartridge is offered only under the
## dev setting ([method offered]); every other one reaches its Hall of Fame.
const BY_SHA1: Dictionary = {
	"ea9bcae617fdf159b045185467ae58b2e4a48b9a": {
		"id": RED,
		"title": "Red",
		"revision": "USA/Europe",
		"generation": GEN1,
		"playable": true,
	},
	"d7037c83e1ae5b39bde3c30787637ba1d4c48ce2": {
		"id": BLUE,
		"title": "Blue",
		"revision": "USA/Europe",
		"generation": GEN1,
		"playable": true,
	},
	"cc7d03262ebfaf2f06772c1a480c7d9d5f4a38e1": {
		"id": YELLOW,
		"title": "Yellow",
		"revision": "USA/Europe",
		"generation": GEN1,
		"playable": true,
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
	"5b64eacf892920518db4ec664e62a086dd5f5bc8": {
		"id": RUBY,
		"title": "Ruby",
		"revision": "USA Rev 2",
		"generation": GEN3,
		"playable": false,
		"dev": true,
	},
	"89b45fb172e6b55d51fc0e61989775187f6fe63c": {
		"id": SAPPHIRE,
		"title": "Sapphire",
		"revision": "USA Rev 2",
		"generation": GEN3,
		"playable": false,
		"dev": true,
	},
	"dd5945db9b930750cb39d00c84da8571feebf417": {
		"id": FIRERED,
		"title": "FireRed",
		"revision": "USA Rev 1",
		"generation": GEN3,
		"playable": false,
		"dev": true,
	},
	"7862c67bdecbe21d1d69ce082ce34327e1c6ed5e": {
		"id": LEAFGREEN,
		"title": "LeafGreen",
		"revision": "USA Rev 1",
		"generation": GEN3,
		"playable": false,
		"dev": true,
	},
	"f3ae088181bf583e55daf962a92bb46f4f1d07b7": {
		"id": EMERALD,
		"title": "Emerald",
		"revision": "USA",
		"generation": GEN3,
		"playable": false,
		"dev": true,
	},
}

## Display order for the launcher shelf, oldest cartridge first.
const ORDER: Array[StringName] = [
	RED, BLUE, YELLOW, GOLD, SILVER, CRYSTAL, RUBY, SAPPHIRE, FIRERED, LEAFGREEN, EMERALD,
]


static func is_known(sha1: String) -> bool:
	return BY_SHA1.has(sha1.to_lower())


## Returns the registry row for a hash, or an empty Dictionary if unknown.
static func lookup(sha1: String) -> Dictionary:
	return BY_SHA1.get(sha1.to_lower(), {})


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


static func is_dev(id: StringName) -> bool:
	return bool(row_for(id).get("dev", false))


## What the shelf, the About list and the import gate offer, in [constant ORDER].
static func offered(dev: bool) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in ORDER:
		if dev or not is_dev(id):
			out.append(id)
	return out


static func dev_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in ORDER:
		if is_dev(id):
			out.append(id)
	return out


static func titles_of(ids: Array[StringName]) -> String:
	var titles: PackedStringArray = []
	for id: StringName in ids:
		titles.append(title_for(id))
	if titles.size() < 2:
		return "".join(titles)
	var last: String = titles[titles.size() - 1]
	titles.remove_at(titles.size() - 1)
	return "%s and %s" % [", ".join(titles), last]


## Every id of a generation, in [constant ORDER].
static func ids_of_generation(generation: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in ORDER:
		if generation_for(id) == generation:
			out.append(id)
	return out


static func size_for(id: StringName) -> int:
	return int(SIZES.get(generation_for(id), 0))


## Whether a file of this length could be one of ours at all.
static func is_known_size(size: int) -> bool:
	return SIZES.values().has(size)
