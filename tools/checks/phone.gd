extends RefCounted

## Sweeps every imported phone contact and special call on all three cartridges.
## `PhoneContacts` is a fixed-width table of two scripts per row and
## `SpecialPhoneCallList` a table of a condition and a third, and every one of them
## is reached by a routine rather than by a script the catalog walks: an incoming
## call takes `PHONE_CONTACT_SCRIPT1`, `Script_SpecialBillCall` takes `SCRIPT2` for
## `PHONE_BILL` alone, and `CheckSpecialPhoneCall` takes the list's own. So a row
## the importer read short reaches no test and no story walk; it reaches a silent
## phone.

var _r: RefCounted = null


func run(r: RefCounted) -> void:
	_r = r
	for game_id: StringName in _r.GAME_IDS:
		var data: GameData = GameData.open(game_id)
		if data == null:
			_r.fail("%s cache is unavailable. Import roms/%s.gbc first." % [game_id, game_id])
			continue
		_contacts(game_id, data)
		_special_calls(game_id, data)
		_mom_purchases(game_id, data)
		_hang_up_texts(game_id, data)


## `HangUp`'s own two lines, transcribed from `data/text/common_3.asm` rather
## than read off the importer: they are pinned by one offset per cartridge and a
## wrong one decodes to something rather than to nothing.
const HANG_UP_TEXTS: Dictionary = {"hang_up_click": "Click!", "hang_up_ellipse": "……"}


func _hang_up_texts(game_id: StringName, data: GameData) -> void:
	var metadata: Dictionary = data.world_phone_metadata()
	for key: String in HANG_UP_TEXTS:
		_r.check(
			String(metadata.get(key, "")) == String(HANG_UP_TEXTS[key]),
			"%s: %s decoded as %s, wanted %s." % [
				game_id, key, String(metadata.get(key, "")), String(HANG_UP_TEXTS[key]),
			]
		)


## Every row carries both scripts, and `PHONE_BILL` resolves through the seam
## `Script_SpecialBillCall` reaches it by.
func _contacts(game_id: StringName, data: GameData) -> void:
	var count: int = data.world_phone_contact_count()
	if not _r.check(
		count > Gen2WorldPhoneHost.CONTACT_BILL,
		"%s: %d phone contacts, too few for PHONE_BILL." % [game_id, count]
	):
		return
	for index: int in count:
		var contact: Dictionary = data.world_phone_contact(index)
		if not _r.check(not contact.is_empty(), "%s: phone contact %d is absent." % [
			game_id, index,
		]):
			continue
		for role: String in ["callee_script", "caller_script"]:
			var script: Dictionary = contact.get(role, {})
			_r.check(
				not script.is_empty() and int(script.get("bank", 0)) > 0,
				"%s: phone contact %d has no %s." % [game_id, index, role]
			)
	var bill: Dictionary = Gen2WorldPhoneHost.resolve_caller(
		data, Gen2WorldPhoneHost.CONTACT_BILL
	)
	_r.check(
		bool(bill.get("ok", false)),
		"%s: PHONE_BILL's caller script does not resolve: %s." % [
			game_id, String(bill.get("reason", &"unknown")),
		]
	)


## `MomTriesToBuySomething`'s whole block against `data/items/mom_phone.asm`.
##
## The two tables are pinned here rather than read off the cache, so a wrong
## address fails on content: the ladder's ten triggers and costs, the five she
## picks between, and which of each is a doll. Both scripts have to reach Mom's
## own four lines through the `text_far` each `writetext` names, which is the
## seam a stub collected without its target used to leave blank.
const EXPECTED_LADDER: Array[Array] = [
	[900, 600, 1, "SUPER POTION"],
	[4000, 270, 1, "REPEL"],
	[7000, 600, 1, "SUPER POTION"],
	[10000, 1800, 2, "CHARMANDER DOLL"],
	[15000, 3000, 1, "MOON STONE"],
	[19000, 600, 1, "SUPER POTION"],
	[30000, 4800, 2, "CLEFAIRY DOLL"],
	[40000, 900, 1, "HYPER POTION"],
	[50000, 8000, 2, "PIKACHU DOLL"],
	[100000, 22800, 2, "BIG SNORLAX"],
]
const EXPECTED_RANDOM: Array[Array] = [
	[0, 600, 1, "SUPER POTION"],
	[0, 90, 1, "ANTIDOTE"],
	[0, 180, 1, "POKé BALL"],
	[0, 450, 1, "ESCAPE ROPE"],
	[0, 500, 1, "GREAT BALL"],
]
## Her four lines, in `.ItemScript`'s order and then `.DollScript`'s. The first
## and third are shared, which is what says both pointers were read right.
const EXPECTED_SCRIPTS: Dictionary = {
	false: ["Hi, ", "I found a useful", "I bought it with", "It's in your PC."],
	true: ["Hi, ", "While shopping", "I bought it with", "It's in your room."],
}


func _mom_purchases(game_id: StringName, data: GameData) -> void:
	for row: Array in [[0, EXPECTED_LADDER], [1, EXPECTED_RANDOM]]:
		var set_number: int = int(row[0])
		var expected: Array = row[1]
		if not _r.check(
			data.mom_item_count(set_number) == expected.size(),
			"%s: MomItems set %d holds %d rows, not %d." % [
				game_id, set_number, data.mom_item_count(set_number), expected.size(),
			]
		):
			continue
		for index: int in expected.size():
			_mom_row(game_id, data, set_number, index, expected[index] as Array)
	for doll: bool in [false, true]:
		_mom_script(game_id, data, doll)
	_r.note("%s: Mom's %d ladder rows and %d random rows, both scripts" % [
		game_id, EXPECTED_LADDER.size(), EXPECTED_RANDOM.size(),
	])


func _mom_row(
	game_id: StringName, data: GameData, set_number: int, index: int, expected: Array
) -> void:
	var actual: Dictionary = data.mom_item(set_number, index)
	var kind: int = int(actual.get("kind", 0))
	var item: int = int(actual.get("item", 0))
	var name: String = Gen2WorldDecoration.decoration_name(data, item) 		if kind == Gen2WorldMomPhone.KIND_DOLL else data.item_name(item)
	_r.check(
		int(actual.get("trigger", -1)) == int(expected[0])
			and int(actual.get("cost", -1)) == int(expected[1])
			and kind == int(expected[2]) and name == String(expected[3]),
		"%s: MomItems set %d row %d is %s (%s), not %s." % [
			game_id, set_number, index, JSON.stringify(actual), name, str(expected),
		]
	)


func _mom_script(game_id: StringName, data: GameData, doll: bool) -> void:
	var pointer: Dictionary = data.mom_phone_script(doll)
	if not _r.check(
		not pointer.is_empty(),
		"%s: Mom's %s script is absent." % [game_id, "doll" if doll else "item"]
	):
		return
	var bank: int = int(pointer["bank"])
	var bytes: PackedByteArray = data.world_script(bank, int(pointer["address"]))
	var crystal: bool = Gen2WorldState.is_crystal_profile(data)
	var lines: Array[String] = []
	var offset: int = 0
	while offset < bytes.size():
		var command: Dictionary = Gen2WorldScript.command_at(bytes, offset, crystal)
		if not bool(command.get("ok", false)):
			break
		if String(command.get("name", "")) == "writetext":
			lines.append(String(Gen2TextStream.decode(
				data.world_text(bank, int(command["address"])), 0, {
					"far": func(far_bank: int, address: int) -> PackedByteArray:
						return data.world_text(far_bank, address),
				}
			).get("text", "")))
		offset += int(command["width"])
		if not Gen2WorldScript.continues_after(int(command["opcode"]), crystal):
			break
	var expected: Array = EXPECTED_SCRIPTS[doll]
	if not _r.check(
		lines.size() == expected.size(),
		"%s: Mom's %s script says %d lines, not %d." % [
			game_id, "doll" if doll else "item", lines.size(), expected.size(),
		]
	):
		return
	for index: int in expected.size():
		_r.check(
			lines[index].begins_with(String(expected[index])),
			"%s: Mom's %s line %d is \"%s\"." % [
				game_id, "doll" if doll else "item", index, lines[index],
			]
		)


## `CheckSpecialPhoneCall` walks this list by index, so every row must name a
## contact this cache has and a condition the host answers.
func _special_calls(game_id: StringName, data: GameData) -> void:
	var index: int = 0
	while true:
		var call_row: Dictionary = data.world_special_phone_call(index)
		if call_row.is_empty():
			break
		index += 1
		var contact: int = int(call_row.get("contact", -1))
		_r.check(
			contact >= 0 and not data.world_phone_contact(contact).is_empty(),
			"%s: special call %d names contact %d, which this cache has no row for." % [
				game_id, index, contact,
			]
		)
		var script: Dictionary = call_row.get("script", {})
		_r.check(
			not script.is_empty() and int(script.get("bank", 0)) > 0,
			"%s: special call %d has no script." % [game_id, index]
		)
	_r.check(index > 0, "%s: no special phone calls were imported." % game_id)
