class_name Gen2MysteryGift
extends RefCounted

## `engine/link/mystery_gift.asm`: the SRAM block, the staged block the two Game
## Boys swap over IR, and `DoMysteryGift`'s own chain of refusals between the
## exchange and the gift. Not the cable link play [Gen2LinkSession] runs: it never
## touches `wLinkMode`, it has its own `sMysteryGiftData` section outside the
## checksummed save, and its peer is an infrared window rather than a wire, so the
## transport is its own too. Everything here is the section and the decision; the
## pixels are [Gen2MysteryGiftPage] and the host is [Gen2MysteryGiftScreen].

## `constants/serial_constants.asm`. Five gifts in a day, and one per person.
const MAX_PARTNERS: int = 5

## `constants/deco_constants.asm`. The two trophy dolls sit past it, so a
## received decoration can never be one.
const NUM_NON_TROPHY_DECOS: int = 43

## `MysteryGiftFallbackItem`, which both tables share: `DECOFLAG_RED_CARPET` and
## `GREAT_BALL` are the same byte, and which one it means is which table the
## index missed.
const FALLBACK_GIFT: int = 4

## `hMGStatusFlags`. `MG_OKAY` is every error bit clear, which is what
## `ExchangeMysteryGiftData` returns on a finished exchange.
const MG_OKAY: int = 0
const MG_WRONG_CHECKSUM: int = 1 << 0
const MG_TIMED_OUT: int = 1 << 1
const MG_CANCELED: int = 1 << 4
const MG_WRONG_PREFIX: int = 1 << 7

## `constants/misc_constants.asm`. Mystery Gift sends `GS_VERSION + 1`, so a
## Game Boy game is 1 or 2; the two above it are the Pokemon Pikachu 2 and the
## version reserved beside it, and both skip parts of the chain.
const GAME_VERSION_GS: int = 1
const POKEMON_PIKACHU_2_VERSION: int = 3
const RESERVED_GAME_VERSION: int = 4

## `NAME_LENGTH`, which is what `.SaveMysteryGiftTrainerName` copies.
const NAME_LENGTH: int = 11

## Which box `DoMysteryGift` ends on. Each names one of the eight `text_far`
## stubs behind the routine, in the run's own order, so the key is the string
## the importer reads rather than a message written here.
const OUTCOME_CANCELED: StringName = &"canceled"
const OUTCOME_COMM_ERROR: StringName = &"comm_error"
const OUTCOME_RETRIEVE: StringName = &"retrieve"
const OUTCOME_FRIEND_NOT_READY: StringName = &"friend_not_ready"
const OUTCOME_FIVE_A_DAY: StringName = &"five_a_day"
const OUTCOME_ONE_A_DAY: StringName = &"one_a_day"
const OUTCOME_SENT: StringName = &"sent"
const OUTCOME_SENT_HOME: StringName = &"sent_home"

## The stub run's own order, which is the order `SPECIAL_TEXT_RUNS` reads it in.
const OUTCOME_ORDER: Array[StringName] = [
	OUTCOME_CANCELED, OUTCOME_COMM_ERROR, OUTCOME_RETRIEVE,
	OUTCOME_FRIEND_NOT_READY, OUTCOME_FIVE_A_DAY, OUTCOME_ONE_A_DAY,
	OUTCOME_SENT, OUTCOME_SENT_HOME,
]

## `sMysteryGiftUnlocked` and `sNumDailyMysteryGiftPartnerIDs` before Carrie has
## explained the machine. `UnlockMysteryGift` is the only thing that clears it,
## and the main menu reads the second byte rather than the first.
const LOCKED: int = 0xFF


## The section a slot that has never seen a Mystery Gift carries.
##
## `sMysteryGiftData` is two pairs rather than one block, and the pairing is
## what `BackupMysteryGift` and `RestoreMysteryGift` copy between: `item` and
## `unlocked` are the working bytes the exchange writes, `backup_item` and
## `daily_partners` are the pair a save writes and a load reads back. The
## second byte of the backup pair is also the day's partner counter, which is
## why the main menu's row does not appear until the game after Carrie.
static func default_section() -> Dictionary:
	return {
		"item": 0,
		"unlocked": LOCKED,
		"backup_item": 0,
		"daily_partners": LOCKED,
		"partner_ids": [],
		"decorations_received": [],
		"timer": 0,
		"trainer_house_flag": 0,
		"partner_name": "",
		"trainer": {},
	}


## Reads a stored section back, clamping every byte to what SRAM could hold.
## A slot written before Mystery Gift existed has no key at all, and every one
## of them then defaults, which is the truth about it.
static func normalize(source: Variant) -> Dictionary:
	var out: Dictionary = default_section()
	if source is not Dictionary:
		return out
	var raw: Dictionary = source as Dictionary
	for key: String in ["item", "unlocked", "backup_item", "daily_partners",
			"trainer_house_flag"]:
		out[key] = int(raw.get(key, out[key])) & 0xFF
	out["timer"] = int(raw.get("timer", 0)) & 0xFFFF
	out["partner_name"] = String(raw.get("partner_name", "")).substr(0, NAME_LENGTH)
	var ids: Variant = raw.get("partner_ids", [])
	if ids is Array:
		for id: Variant in (ids as Array).slice(0, MAX_PARTNERS):
			(out["partner_ids"] as Array).append(int(id) & 0xFFFF)
	var received: Variant = raw.get("decorations_received", [])
	if received is Array:
		for deco: Variant in received as Array:
			var index: int = int(deco)
			if index >= 0 and index < NUM_NON_TROPHY_DECOS \
					and index not in out["decorations_received"]:
				(out["decorations_received"] as Array).append(index)
	var trainer: Variant = raw.get("trainer", {})
	if trainer is Dictionary:
		out["trainer"] = (trainer as Dictionary).duplicate(true)
	return out


## `UnlockMysteryGift`, Carrie's own special. `sMysteryGiftUnlocked` of -1 is
## the locked state, and clearing it clears `sMysteryGiftItem` with it; a byte
## that is anything else is left alone, so talking to her twice is not a way to
## throw a waiting gift away.
static func unlock(section: Dictionary) -> bool:
	if int(section.get("unlocked", LOCKED)) != LOCKED:
		return false
	section["unlocked"] = 0
	section["item"] = 0
	return true


## `CheckMysteryGift`'s own answer into `wScriptVar`: zero when no gift is
## waiting, and the item plus one when one is. POKECENTER_2F's scene script
## branches on the zero and nothing reads the value it puts there otherwise.
static func check_value(section: Dictionary) -> int:
	var item: int = int(section.get("item", 0)) & 0xFF
	return 0 if item == 0 else (item + 1) & 0xFF


## `GetMysteryGiftItem`'s SRAM half. The bag is the caller's, so this answers
## which item is waiting and clears the byte only once the caller says it went
## in: `.no_room` closes SRAM without clearing, so a full bag keeps the gift.
static func take_item(section: Dictionary) -> int:
	return int(section.get("item", 0)) & 0xFF


static func clear_item(section: Dictionary) -> void:
	section["item"] = 0


## `ResetDailyMysteryGiftLimitIfUnlocked`, which `DoMysteryGiftIfDayHasPassed`
## calls once a day has passed. A locked file keeps its -1: clearing the
## counter there would unlock the main menu's row on the first midnight.
static func reset_daily_limit_if_unlocked(section: Dictionary) -> bool:
	if int(section.get("daily_partners", LOCKED)) == LOCKED:
		return false
	section["daily_partners"] = 0
	(section["partner_ids"] as Array).clear()
	return true


## `BackupMysteryGift`, which every save runs: the working pair goes to the
## backup pair.
static func backup(section: Dictionary) -> void:
	section["backup_item"] = int(section.get("item", 0)) & 0xFF
	section["daily_partners"] = int(section.get("unlocked", LOCKED)) & 0xFF


## `RestoreMysteryGift`, which `TryLoadSaveFile` runs: the backup pair comes
## back into the working pair. The exchange happens outside a loaded game, so
## this is what carries a gift received at the menu into the file.
static func restore(section: Dictionary) -> void:
	section["item"] = int(section.get("backup_item", 0)) & 0xFF
	section["unlocked"] = int(section.get("daily_partners", LOCKED)) & 0xFF


## `MainMenu_GetWhichMenu`'s own test: the row is on the menu when
## `sNumDailyMysteryGiftPartnerIDs` is not -1, which is the byte a save wrote
## rather than the one Carrie cleared.
static func menu_row_unlocked(section: Dictionary) -> bool:
	return int(section.get("daily_partners", LOCKED)) != LOCKED


## `CheckAndSetMysteryGiftDecorationAlreadyReceived`. Answers whether the
## decoration is new, and records it when it is; the flag array is
## `sMysteryGiftDecorationsReceived` and it is what
## `CopyMysteryGiftReceivedDecorationsToPC` walks on the next Continue.
static func receive_decoration(section: Dictionary, deco: int) -> bool:
	var received: Array = section["decorations_received"] as Array
	if deco in received:
		return false
	received.append(deco)
	return true


## `CopyMysteryGiftReceivedDecorationsToPC`, run once per Continue: every flag
## the array carries becomes the decoration's own event flag, which is where
## ownership lives ([Gen2WorldDecoration]). The array holds `DECOFLAG_*` indices
## and the walk is `SetSpecificDecorationFlag`, so `GetDecorationID` maps each
## one onto a decoration first. The array is not cleared, so the
## walk is idempotent and a decoration received while a different slot was
## loaded still arrives.
static func copy_decorations_to_pc(
	section: Dictionary, data: GameData, state: Gen2WorldState
) -> int:
	var given: int = 0
	for deco: int in section.get("decorations_received", []) as Array:
		if Gen2WorldDecoration.set_owned_by_flag(data, state, deco):
			given += 1
	return given


## `MysteryGiftGetItem` and `MysteryGiftGetDecoration`, which share
## `MysteryGiftFallbackItem`: an index past either table's end is a RED CARPET
## as a decoration and a GREAT BALL as an item, the same byte read two ways.
##
## [param table] is the imported `MysteryGiftItems` or `MysteryGiftDecos`.
static func gift_at(table: Array, index: int) -> int:
	if index < 0 or index >= table.size():
		return FALLBACK_GIFT
	return int(table[index]) & 0xFF


## `StageDataForMysteryGift`: the twenty bytes this Game Boy holds out to the
## other one. Every field is read at the moment the window opens, so the item
## and the decoration a partner offers are rolled here rather than by whoever
## receives them.
static func stage_player_data(
	save: Gen2SaveData, section: Dictionary, dex_caught: int,
	random: RandomNumberGenerator
) -> Dictionary:
	var id: int = (save.player_id if save != null else 0) & 0xFFFF
	var id_high: int = (id >> 8) & 0xFF
	var id_low: int = id & 0xFF
	return {
		"game_version": GAME_VERSION_GS,
		"id": id,
		"name": save.player_name if save != null else "",
		"dex_caught": dex_caught & 0xFF,
		## `Random / and 1`: which of the two tables this side is offering from.
		"sent_deco": random.randi() & 1,
		"which_item": _random_sample(id_high, id_low, random),
		## The second call swaps b and c, so the two rolls read the ID's two
		## bytes the other way round.
		"which_deco": _random_sample(id_low, id_high, random),
		"backup_item": int(section.get("backup_item", 0)) & 0xFF,
		"daily_partners": int(section.get("daily_partners", LOCKED)) & 0xFF,
	}


## `StageDataForMysteryGift.RandomSample`, which is four weighted bands rather
## than an index: about 90% of the time a row of the table's first sixteen,
## then eight, then eight, then one of the last two. The player's own ID picks
## the odd row inside a band, so two players sitting down together do not offer
## the same thing.
static func _random_sample(
	high: int, low: int, random: RandomNumberGenerator
) -> int:
	if (random.randi() & 0xFF) >= 25:
		var pick: int = random.randi() & 0x7
		return (pick << 1) + (1 if _rotated_bit(pick) & low else 0)
	if (random.randi() & 0xFF) >= 50:
		var pick: int = random.randi() & 0x3
		return 0x10 + (pick << 1) + (1 if _rotated_bit(pick) & high else 0)
	if (random.randi() & 0xFF) >= 50:
		## `swap a / and $7`: the ID byte's high nibble, three bits of it.
		return 0x18 + ((high >> 4) & 0x7)
	return 0x21 if high & 0x80 else 0x20


## The `rlc e` loop the sample tests its ID byte with: `e` starts at $80 and is
## rotated once per count, so a count of zero rotates 256 times and lands back
## where it started rather than not rotating at all.
static func _rotated_bit(count: int) -> int:
	return 1 << ((7 + (count if count > 0 else 256)) % 8)


## `DoMysteryGift` from the exchange down: every refusal in the routine's own
## order, and the gift behind the last of them. The section is written in place,
## which is what the cartridge does to SRAM between one box and the next: the
## partner ID is added and the trainer name saved before the gift is chosen, so a
## partner who offers a decoration this side already owns still counts against
## both daily limits. Answers `{ outcome, name, item, deco, retry }`, where
## `outcome` names one of the eight `text_far` stubs and `retry` is
## `.CommunicationError`'s own `jp DoMysteryGift`.
static func exchange(
	section: Dictionary, transport: Gen2MysteryGiftTransport,
	player: Dictionary, tables: Dictionary, data: GameData = null
) -> Dictionary:
	var status: int = transport.status()
	var partner: Dictionary = transport.exchange(player) if status == MG_OKAY else {}
	if status == MG_CANCELED:
		return _outcome(OUTCOME_CANCELED)
	if status != MG_OKAY or partner.is_empty():
		return _outcome(OUTCOME_COMM_ERROR, "", true)

	var version: int = int(partner.get("game_version", GAME_VERSION_GS))
	if version != POKEMON_PIKACHU_2_VERSION:
		if int(section.get("daily_partners", 0)) >= MAX_PARTNERS:
			return _outcome(OUTCOME_FIVE_A_DAY)
		var seen: Array = section.get("partner_ids", []) as Array
		if int(partner.get("id", 0)) in seen:
			return _outcome(OUTCOME_ONE_A_DAY)
	## `wMysteryGiftPlayerBackupItem` is this side's own waiting gift, so a
	## player who has not been to the counter cannot take a second one.
	if int(section.get("backup_item", 0)) != 0:
		return _outcome(OUTCOME_RETRIEVE)
	if int(partner.get("backup_item", 0)) != 0:
		return _outcome(OUTCOME_FRIEND_NOT_READY)

	if version != POKEMON_PIKACHU_2_VERSION:
		_add_partner_id(section, int(partner.get("id", 0)))
		if version != RESERVED_GAME_VERSION:
			_save_partner_trainer(section, partner)

	if int(partner.get("sent_deco", 0)) != 0:
		var deco: int = gift_at(
			tables.get("decos", []) as Array, int(partner.get("which_deco", 0))
		)
		if receive_decoration(section, deco):
			return _outcome(
				OUTCOME_SENT_HOME, Gen2WorldDecoration.decoration_name(data, deco)
			)
	var item: int = gift_at(
		tables.get("items", []) as Array, int(partner.get("which_item", 0))
	)
	## The gift lands in the backup pair, which is where the counter reads it
	## from once `RestoreMysteryGift` has carried it into the loaded file.
	section["backup_item"] = item
	return _outcome(OUTCOME_SENT, _item_name(data, item))


static func _outcome(
	outcome: StringName, name: String = "", retry: bool = false
) -> Dictionary:
	return {"outcome": outcome, "name": name, "retry": retry}


## `.AddMysteryGiftPartnerID`, which counts the partner whether or not the gift
## behind it is one this side keeps.
static func _add_partner_id(section: Dictionary, id: int) -> void:
	var ids: Array = section["partner_ids"] as Array
	if ids.size() < MAX_PARTNERS:
		ids.append(id & 0xFFFF)
	section["daily_partners"] = mini(
		int(section.get("daily_partners", 0)) + 1, 0xFF
	)


## `.SaveMysteryGiftTrainerName`, which is what the Trainer House reads: the
## partner's name and the flag that says somebody has linked.
##
## The party beside them is deliberately empty, because a real cartridge's is:
## `StagePartyDataForMysteryGift` sits behind a `vc_patch` and is unreferenced
## in the retail build, so `ClearMysteryGiftTrainer` zeroes `wMysteryGiftTrainer`
## and nothing ever fills it. `GetTrainerName` still reads the name, which is
## the half that works.
static func _save_partner_trainer(section: Dictionary, partner: Dictionary) -> void:
	section["trainer_house_flag"] = 1
	section["partner_name"] = String(partner.get("name", "")).substr(0, NAME_LENGTH)
	section["trainer"] = {"name": section["partner_name"], "party": []}


static func _item_name(data: GameData, item: int) -> String:
	if data == null:
		return ""
	return String((data.item(item) as Dictionary).get("name", ""))


## `DoMysteryGiftIfDayHasPassed`, which is the only thing that resets the day's
## partner list and runs when the menu row is chosen rather than at midnight.
##
## `sMysteryGiftTimer` is `InitOneDayCountdown`'s own two bytes: the days still
## to run, and the day the countdown started on. `CheckDayDependentEventHL`
## takes the days since that start off the first byte and reports the borrow,
## so the limit lifts on the first opening a day or more later.
static func day_has_passed(section: Dictionary, day: int) -> bool:
	var timer: int = int(section.get("timer", 0)) & 0xFFFF
	var remaining: int = (timer >> 8) & 0xFF
	var started: int = timer & 0xFF
	var elapsed: int = posmod(day - started, Gen2WorldClock.DAYS_PER_WEEK)
	return elapsed >= remaining


## `InitOneDayCountdown`: one day to run, from today.
static func start_countdown(section: Dictionary, day: int) -> void:
	section["timer"] = (1 << 8) | (day & 0xFF)


## `MysteryGift`'s own two calls in front of the screen: the countdown is read,
## the day's partners are cleared if it has run out, and it is restarted.
static func begin_session(section: Dictionary, day: int) -> bool:
	var lifted: bool = false
	if day_has_passed(section, day):
		lifted = reset_daily_limit_if_unlocked(section)
		start_countdown(section, day)
	return lifted
