class_name Gen2ProfOaksPC
extends RefCounted

## `ProfOaksPCBoot`, `ProfOaksPCRating` and `Rate` (engine/events/prof_oaks_pc.asm),
## as the pages a screen shows and the effect it plays.
##
## Presentation only: the routine counts `wPokedexSeen` and `wPokedexCaught` and
## writes nothing back. The pages are the source's own order, and each waits for
## A or B, which is why the sound is on the last of them rather than on the whole
## run.

## `PrintNum` with `PRINTNUM_LEFTALIGN | 1, 3`. Left aligned without leading
## zeros means `.AdvancePointer` does not step past a suppressed digit, so the
## buffer holds the significant digits and nothing else; the `@` fill
## `.UpdateRatingBuffer` laid down terminates it.
const COUNT_DIGITS: int = 3


## The whole boot, as [code]{ seen, caught, sfx, pages }[/code]. Empty for a
## cache imported without the rating table, which is the caller's cue to leave
## the script's own `end` alone.
##
## `ProfOaksPCBoot` is `_OakPCText2` in front of `Rate`.
static func boot(data: GameData, state: Gen2WorldState) -> Dictionary:
	var out: Dictionary = rate(data, state)
	if out.is_empty():
		return out
	(out["pages"] as Array).push_front(data.oak_pc_text("level"))
	return out


## `Rate`, which is also the whole of `ProfOaksPCRating` bar the music it stops.
static func rate(data: GameData, state: Gen2WorldState) -> Dictionary:
	if data == null or data.oak_ratings().is_empty():
		return {}
	var seen: int = state.seen_count() if state != null else 0
	var caught: int = state.caught_count() if state != null else 0
	var rating: Dictionary = rating_for(data, caught)
	return {
		"seen": seen,
		"caught": caught,
		"sfx": int(rating.get("sfx", 0)),
		"pages": [
			counts_text(data, seen, caught),
			String(rating.get("text", "")),
		],
	}


## `FindOakRating`: the first row whose threshold the caught count does not
## exceed. The table's last row is every species, so the walk always lands.
## Generation 1's `DisplayDexRating` compares the other way, `cp b / jr c`
## against `jr nc`, so its rows match under the threshold rather than at it.
static func rating_for(data: GameData, caught: int) -> Dictionary:
	var under: bool = data != null and data.generation == RomRegistry.GEN1
	for row: Variant in data.oak_ratings():
		var threshold: int = int((row as Dictionary).get("threshold", -1))
		if caught < threshold if under else caught <= threshold:
			return row
	return {}


## `_OakPCText3` with `.UpdateRatingBuffers`' two numbers in the `text_ram` slots
## it left for them. Generation 1's `_DexCompletionText` reads the same two
## counts with `text_decimal` instead, so its slots are number markers and
## `PrintNumber` right-aligns them in [constant COUNT_DIGITS] cells where
## `PRINTNUM_LEFTALIGN` does not.
static func counts_text(data: GameData, seen: int, caught: int) -> String:
	var text: String = data.oak_pc_text("counts")
	for value: int in [seen, caught]:
		var digits: String = String.num_int64(value)
		var number: int = text.find(Gen2TextStream.NUMBER_MARKER)
		var ram: int = text.find(Gen2TextStream.RAM_MARKER)
		if number >= 0 and (ram < 0 or number < ram):
			text = Gen2TextStream.fill_marker(
				text, Gen2TextStream.NUMBER_MARKER, digits.lpad(COUNT_DIGITS)
			)
			continue
		text = Gen2TextStream.fill_marker(text, Gen2TextStream.RAM_MARKER, digits)
	return text
