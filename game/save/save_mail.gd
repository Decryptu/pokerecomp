class_name Gen2SaveMail
extends RefCounted

## One `mailmsg` struct and the four routines in `engine/pokemon/mail.asm` that
## move one between a party member and the PC. The cartridge keeps party mail in
## `sPartyMail` indexed by party slot and the mailbox in `sMailboxes`; the mailbox
## is kept the same way here, but a party member's mail is kept on the member
## rather than on its slot, because everything that moves a slot moves its mail
## with it and nothing can put a mailed Pokemon anywhere else. Scene-free and
## cache-free, like the rest of `game/save/`.

## `MAIL_LINE_LENGTH`, `MAIL_MSG_LENGTH` and `MAILBOX_CAPACITY`.
const LINE_LENGTH: int = Gen2Layout.MAIL_LINE_LENGTH
const MESSAGE_LENGTH: int = Gen2Layout.MAIL_MSG_LENGTH
const CAPACITY: int = Gen2Layout.MAILBOX_CAPACITY
## The `<NEXT>` byte between the two lines, which `_ComposeMailMessage` writes
## once and neither the entry nor the delete may overwrite.
const LINE_BREAK: int = Gen2Text.NEXT_LINE
const TERMINATOR: int = Gen2Text.TERMINATOR
## The whole buffer the screen types into: two lines and the break between them.
const BUFFER_LENGTH: int = MESSAGE_LENGTH + 1
## `PLAYER_NAME_LENGTH` is 8 and both writers copy `NAME_LENGTH - 1`, so the
## author runs two bytes into the `Nationality` word behind it and no cartridge
## in this project's allowlist ever writes a nationality. Ten is what is stored
## and ten is what `MailboxPC_GetMailAuthor` reads back.
const AUTHOR_LENGTH: int = Gen2Layout.MAIL_AUTHOR_LENGTH

## The typed message, `BUFFER_LENGTH` raw codes with `'@'` behind what was
## entered. Raw rather than a String because the break is a code and the two
## lines are fixed-width fields, which is how every reader addresses them.
var message: PackedByteArray = PackedByteArray()
var author: String = ""
## `wPlayerID`, the author's own trainer number.
var author_id: int = 0
## `wCurPartySpecies` at the moment the mail was written, which is what
## PORTRAITMAIL draws.
var species: int = 0
## The mail item's own number, which is what `MailGFXPointers` is walked with.
var item: int = 0


func _init() -> void:
	message = blank_message()


## `NamingScreen_InitNameEntry` followed by `_ComposeMailMessage.InitBlankMail`'s
## `ld [hl], '<NEXT>'`: a terminated buffer with the break already in place.
static func blank_message() -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(BUFFER_LENGTH)
	out.fill(TERMINATOR)
	out[LINE_LENGTH] = LINE_BREAK
	return out


## `ComposeMailMessage` (`engine/pokemon/mon_menu.asm`): the entry the naming
## screen stored, then the player's name, id, the species holding it and the
## item itself.
static func compose(
	entry: PackedByteArray, player_name: String, player_id: int, held_by: int, mail_item: int
) -> Gen2SaveMail:
	var out := Gen2SaveMail.new()
	var buffer: PackedByteArray = blank_message()
	for index: int in mini(entry.size(), BUFFER_LENGTH):
		buffer[index] = entry[index]
	buffer[LINE_LENGTH] = LINE_BREAK
	out.message = buffer
	out.author = player_name.substr(0, AUTHOR_LENGTH)
	out.author_id = player_id & 0xFFFF
	out.species = held_by
	out.item = mail_item
	return out


## `GivePokeMail`, which copies a script's own bytes into the mail struct and
## blanks nothing first: the message is whatever the pointer holds, and the
## author, ID and species are read off the party member rather than the player.
static func from_script(
	bytes: PackedByteArray, author_name: String, id: int, held_by: int, mail_item: int
) -> Gen2SaveMail:
	var out := Gen2SaveMail.new()
	var buffer: PackedByteArray = blank_message()
	for index: int in mini(bytes.size(), BUFFER_LENGTH):
		buffer[index] = bytes[index]
	out.message = buffer
	out.author = author_name.substr(0, AUTHOR_LENGTH)
	out.author_id = id & 0xFFFF
	out.species = held_by
	out.item = mail_item
	return out


## One of the two lines as text, decoded up to its terminator. `MailGFX_Place
## Message` prints the whole buffer with one `PlaceString` and `<NEXT>` is what
## splits it, so the break is found rather than assumed: a script's own mail
## (`GiftSpearowMail`) writes it behind a fifteen-letter line, where the naming
## screen's fixed fields put it at `LINE_LENGTH`.
func line(index: int) -> String:
	var at: int = 0
	var wanted: int = index
	while wanted > 0:
		if at >= message.size() or message[at] == TERMINATOR:
			return ""
		if message[at] == LINE_BREAK:
			wanted -= 1
		at += 1
	var codes := PackedByteArray()
	while at < message.size():
		var code: int = message[at]
		if code == TERMINATOR or code == LINE_BREAK:
			break
		codes.append(code)
		at += 1
	return Gen2Text.decode(codes, 0, codes.size())


func to_dict() -> Dictionary:
	return {
		"message": Array(message),
		"author": author,
		"author_id": author_id,
		"species": species,
		"item": item,
	}


static func from_dict(raw: Variant) -> Gen2SaveMail:
	if not raw is Dictionary:
		return null
	var source: Dictionary = raw
	var out := Gen2SaveMail.new()
	var buffer: PackedByteArray = blank_message()
	var stored: Variant = source.get("message", [])
	if stored is Array:
		var codes: Array = stored
		for index: int in mini(codes.size(), BUFFER_LENGTH):
			buffer[index] = int(codes[index]) & 0xFF
	out.message = buffer
	out.author = String(source.get("author", "")).substr(0, AUTHOR_LENGTH)
	out.author_id = int(source.get("author_id", 0)) & 0xFFFF
	out.species = int(source.get("species", 0))
	out.item = int(source.get("item", 0))
	return out


## `GetMailboxCount`, which reads `sMailboxCount` and nothing else.
static func mailbox_count(save: Gen2SaveData) -> int:
	return save.mailbox.size() if save != null else 0


## `IsAnyMonHoldingMail`, the guard `SaveGameData` runs before a link and the
## day care runs before a deposit.
static func any_mon_holding_mail(save: Gen2SaveData) -> bool:
	if save == null:
		return false
	for mon: Gen2SaveMon in save.party:
		if mon != null and mon.mail != null:
			return true
	return false


## `SendMailToPC`. The mail leaves the party member, its item goes with it and
## `sMailboxCount` is incremented; a full mailbox or a member holding no mail is
## the routine's own `scf`.
static func send_to_pc(save: Gen2SaveData, slot: int) -> bool:
	if save == null or slot < 0 or slot >= save.party.size():
		return false
	var mon: Gen2SaveMon = save.party[slot]
	if mon == null or mon.mail == null:
		return false
	if save.mailbox.size() >= CAPACITY:
		return false
	save.mailbox.append(mon.mail)
	mon.mail = null
	mon.item = 0
	return true


## `DeleteMailFromPC`, which shifts every message behind the deleted one down
## and clears the last slot.
static func delete_from_pc(save: Gen2SaveData, index: int) -> bool:
	if save == null or index < 0 or index >= save.mailbox.size():
		return false
	save.mailbox.remove_at(index)
	return true


## `MoveMailFromPCToParty`: the message is copied onto the party member, its own
## `Type` byte becomes the member's held item, and the mailbox entry is deleted
## behind it. The caller has already refused an egg and a member holding
## anything, which is `.AttachMail`'s own two branches.
static func move_from_pc_to_party(save: Gen2SaveData, index: int, slot: int) -> bool:
	if save == null or index < 0 or index >= save.mailbox.size():
		return false
	if slot < 0 or slot >= save.party.size():
		return false
	var mon: Gen2SaveMon = save.party[slot]
	if mon == null:
		return false
	var mail: Gen2SaveMail = save.mailbox[index]
	mon.mail = mail
	mon.item = mail.item
	save.mailbox.remove_at(index)
	return true
