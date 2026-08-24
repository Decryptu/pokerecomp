extends RefCounted

## Sweeps every imported phone contact and special call on all three cartridges.
##
## `PhoneContacts` is a fixed-width table of two scripts per row and
## `SpecialPhoneCallList` a table of a condition and a third, and every one of
## them is reached by a routine rather than by a script the catalog walks: an
## incoming call takes `PHONE_CONTACT_SCRIPT1`, `Script_SpecialBillCall` takes
## `PHONE_CONTACT_SCRIPT2` for `PHONE_BILL` alone, and `CheckSpecialPhoneCall`
## takes the list's own. So a row the importer read short reaches no test and no
## story walk; it reaches a silent phone.
##
##   Godot --headless --path . -s res://tools/validate.gd -- phone

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
