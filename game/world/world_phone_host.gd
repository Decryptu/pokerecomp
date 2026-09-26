class_name Gen2WorldPhoneHost
extends RefCounted

## Phone policy: it picks a cartridge script, and the script runner commits its writes.

const TIME_MORNING: int = 1
const TIME_DAY: int = 2
const TIME_NIGHT: int = 4
const TIME_ANY: int = TIME_MORNING | TIME_DAY | TIME_NIGHT
const ENVIRONMENT_TOWN: int = 1
const ENVIRONMENT_ROUTE: int = 2

const CONDITION_OUTSIDE: StringName = &"outside"
const CONDITION_ANYWHERE: StringName = &"anywhere"


## `CheckTime`'s `.TimeOfDayTable`: `wTimeOfDay` as one bit of MORN, DAY and NITE.
static func time_mask_for_hour(hour: int) -> int:
	return 1 << Gen2WorldClock.time_of_day_at(hour)


static func time_mask_matches(mask: int, hour: int) -> bool:
	return (mask & time_mask_for_hour(hour) & TIME_ANY) != 0


static func map_has_phone_service(map: Gen2WorldMap) -> bool:
	## Map macro comment: TRUE prevents phone calls. The importer stores this
	## field as phone_flag, so zero is the service-enabled state.
	return map != null and map.phone_flag == 0


static func is_outside_environment(environment: int) -> bool:
	return environment in [ENVIRONMENT_TOWN, ENVIRONMENT_ROUTE]


static func contact_summary(data: GameData, contact: Dictionary) -> Dictionary:
	if data == null or contact.is_empty():
		return {}
	var trainer_class: int = int(contact.get("trainer_class", 0))
	return {
		"index": int(contact.get("index", -1)),
		"trainer_class": trainer_class,
		"trainer_name": data.trainer_name(trainer_class),
		"trainer_number": int(contact.get("trainer_number", 0)),
		"non_trainer_id": int(contact.get("non_trainer_id", -1)),
		"caller_label": String(contact.get("caller_label", "")),
		"map_group": int(contact.get("map_group", -1)),
		"map_number": int(contact.get("map_number", -1)),
		"callee_time": int(contact.get("callee_time", 0)),
		"caller_time": int(contact.get("caller_time", 0)),
		"callee_script": (contact.get("callee_script", {}) as Dictionary).duplicate(true),
		"caller_script": (contact.get("caller_script", {}) as Dictionary).duplicate(true),
	}


static func special_call_summary(data: GameData, special_call: Dictionary) -> Dictionary:
	if data == null or special_call.is_empty():
		return {}
	return {
		"index": int(special_call.get("index", -1)),
		"condition": int(special_call.get("condition", 0)),
		"condition_kind": StringName(special_call.get("condition_kind", &"unknown")),
		"contact": int(special_call.get("contact", -1)),
		"script": (special_call.get("script", {}) as Dictionary).duplicate(true),
	}


static func available_incoming_contacts(
	data: GameData, state: Gen2WorldState, map: Gen2WorldMap, hour: int
) -> Array:
	if data == null or state == null or not map_has_phone_service(map):
		return []
	var available: Array = []
	for index: int in registered_contacts(data, state):
		## `GetAvailableCallers` reads `PHONE_CONTACT_SCRIPT2_TIME`.
		var contact: Dictionary = data.world_phone_contact(index)
		if contact.is_empty() or not time_mask_matches(int(contact.get("caller_time", 0)), hour):
			continue
		if int(contact.get("map_group", -1)) == map.group \
			and int(contact.get("map_number", -1)) == map.number:
			continue
		available.append(contact)
	return available


static func resolve_incoming(
	data: GameData,
	state: Gen2WorldState,
	map: Gen2WorldMap,
	hour: int,
	on_entrance: bool = false,
	timer_ready: bool = true,
	random_byte: int = 0,
	force: bool = false,
	selection_byte: int = 0,
) -> Dictionary:
	if data == null or state == null or not map_has_phone_service(map):
		return _phone_unavailable(&"phone_service_unavailable")
	## `CheckPhoneCall`'s `jr z, .no_call` behind `CheckStandingOnEntrance`.
	if on_entrance:
		return _phone_unavailable(&"on_entrance")
	if not timer_ready:
		return _phone_unavailable(&"receive_timer_not_ready")
	## `CheckPhoneCall`'s 50 percent: a random byte with its high bit clear.
	if not force and (random_byte & 0x80) != 0:
		return _phone_unavailable(&"incoming_roll_failed")
	var available: Array = available_incoming_contacts(data, state, map, hour)
	if available.is_empty():
		return _phone_unavailable(&"no_available_caller")
	## `ChooseRandomCaller`: `swap(hRandomAdd) & $1f` modulo the caller count.
	var swapped: int = ((selection_byte >> 4) | (selection_byte << 4)) & 0x1F
	var selected: Dictionary = available[swapped % available.size()]
	return {
		"ok": true,
		"contact": selected.duplicate(true),
		"contact_id": int(selected.get("index", -1)),
		"role": &"callee",
		"script": (selected.get("caller_script", {}) as Dictionary).duplicate(true),
		"phone": {
			"contact_id": int(selected.get("index", -1)),
			"caller_id": int(selected.get("index", -1)),
			"role": &"incoming",
		},
	}


static func resolve_outgoing(
	data: GameData, state: Gen2WorldState, map: Gen2WorldMap, contact_id: int, hour: int
) -> Dictionary:
	if data == null or state == null:
		return _phone_unavailable(&"phone_data_unavailable")
	if contact_id < 0 or not state.has_phone_contact(contact_id):
		return _phone_unavailable(&"phone_number_not_registered")
	var contact: Dictionary = data.world_phone_contact(contact_id)
	if contact.is_empty():
		return _phone_unavailable(&"phone_contact_missing")
	# `.OutOfArea`, which the Pokegear's own `.no_service` refusal comes before.
	if not map_has_phone_service(map):
		return _out_of_area_result(data, contact, contact_id, &"phone_service_unavailable")
	## A call the player places reads `PHONE_CONTACT_SCRIPT1_TIME`.
	if not time_mask_matches(int(contact.get("callee_time", 0)), hour):
		return _out_of_area_result(data, contact, contact_id, &"caller_unavailable_at_this_time")
	if int(contact.get("map_group", -1)) == map.group \
		and int(contact.get("map_number", -1)) == map.number:
		var just_talk: Dictionary = data.world_phone_script(&"just_talk")
		if just_talk.is_empty():
			return _phone_unavailable(&"same_map_phone_script_unavailable")
		return {
			"ok": true,
			"contact": contact.duplicate(true),
			"contact_id": contact_id,
			"role": &"caller",
			"script": just_talk,
			"phone": {
				"contact_id": contact_id,
				"caller_id": contact_id,
				"role": &"outgoing",
				"same_map": true,
			},
		}
	return {
		"ok": true,
		"contact": contact.duplicate(true),
		"contact_id": contact_id,
		"role": &"caller",
		"script": (contact.get("callee_script", {}) as Dictionary).duplicate(true),
		"phone": {
			"contact_id": contact_id,
			"caller_id": contact_id,
			"role": &"outgoing",
		},
	}


## `wPhoneList` in slot order, which is registration order: `AddPhoneNumber`
## fills the first hole, and the Pokegear's delete closes the gap.
static func registered_contact_summaries(data: GameData, state: Gen2WorldState) -> Array:
	var summaries: Array = []
	if data == null or state == null:
		return summaries
	for index: int in registered_contacts(data, state):
		summaries.append(contact_summary(data, data.world_phone_contact(index)))
	return summaries


static func registered_contacts(data: GameData, state: Gen2WorldState) -> Array[int]:
	var contacts: Array[int] = []
	for raw_index: Variant in state.phone_contacts():
		var index: int = int(raw_index)
		if index >= 0 and index < data.world_phone_contact_count():
			contacts.append(index)
	return contacts


## `PermanentNumbers`: Mom and Elm. `GetRemainingSpaceInPhoneList` keeps a slot
## free for each of them not yet registered, [param contact] itself excepted.
const PERMANENT_CONTACTS: Array[int] = [1, 4]


static func phone_list_room(registered: Dictionary, contact: int) -> int:
	var room: int = Gen2WorldState.PHONE_CONTACT_CAPACITY
	for permanent: int in PERMANENT_CONTACTS:
		if permanent != contact and not registered.has(permanent):
			room -= 1
	return room


## `PHONE_BILL`, the one contact an event rather than the player or the timer
## can put on the line. Third in `PhoneContacts` on all three cartridges.
const CONTACT_BILL: int = 3


## `LoadCallerScript`: the contact's own *caller* script, which is
## `PHONE_CONTACT_SCRIPT2` and the one `Script_ReceivePhoneCall`'s `memcall`
## runs. No entrance, timer, roll, registration or time test stands in front of
## it: the event that asks for the call has already decided there is one.
static func resolve_caller(data: GameData, contact_id: int) -> Dictionary:
	if data == null:
		return _phone_unavailable(&"phone_data_unavailable")
	var contact: Dictionary = data.world_phone_contact(contact_id)
	if contact.is_empty():
		return _phone_unavailable(&"phone_contact_missing")
	var script: Dictionary = contact.get("caller_script", {})
	if script.is_empty():
		return _phone_unavailable(&"phone_caller_script_missing")
	return {
		"ok": true,
		"contact": contact.duplicate(true),
		"contact_id": contact_id,
		"role": &"caller",
		"script": script.duplicate(true),
		"phone": {
			"contact_id": contact_id,
			"caller_id": contact_id,
			"role": &"caller",
		},
	}


static func resolve_special(
	data: GameData, map: Gen2WorldMap, call_id: int, _hour: int
) -> Dictionary:
	## SPECIALCALL_NONE clears the pending call and rings nothing.
	if call_id == 0:
		return {"ok": true, "clear": true, "call_id": 0}
	if data == null:
		return _phone_unavailable(&"phone_data_unavailable")
	var special_call: Dictionary = data.world_special_phone_call(call_id - 1)
	if special_call.is_empty():
		return _phone_unavailable(&"special_phone_call_missing")
	var condition: StringName = StringName(special_call.get("condition_kind", &"unknown"))
	if condition == &"unknown":
		return _phone_unavailable(&"unknown_special_call_condition")
	if condition == CONDITION_OUTSIDE and not is_outside_environment(map.environment):
		return _phone_unavailable(&"special_call_requires_outside")
	if condition != CONDITION_OUTSIDE and condition != CONDITION_ANYWHERE:
		return _phone_unavailable(&"unsupported_special_call_condition")
	var contact_id: int = int(special_call.get("contact", -1))
	var contact: Dictionary = data.world_phone_contact(contact_id)
	var script: Dictionary = special_call.get("script", {})
	if contact.is_empty() or script.is_empty():
		return _phone_unavailable(&"special_phone_call_data_missing")
	return {
		"ok": true,
		"call_id": call_id,
		"special_call": special_call.duplicate(true),
		"contact": contact,
		"contact_id": contact_id,
		"role": &"callee",
		"script": script.duplicate(true),
		"phone": {
			"contact_id": contact_id,
			"caller_id": contact_id,
			"special_call_id": call_id,
			"role": &"special",
		},
	}


static func _phone_unavailable(reason: StringName) -> Dictionary:
	return {"ok": false, "reason": reason}


static func _out_of_area_result(
	data: GameData, contact: Dictionary, contact_id: int, reason: StringName
) -> Dictionary:
	var script: Dictionary = data.world_phone_script(&"out_of_area")
	if script.is_empty():
		return _phone_unavailable(reason)
	return {
		"ok": true,
		"reason": reason,
		"out_of_area": true,
		"contact": contact.duplicate(true),
		"contact_id": contact_id,
		"role": &"caller",
		"script": script,
		"phone": {
			"contact_id": contact_id,
			"caller_id": contact_id,
			"role": &"outgoing",
			"out_of_area": true,
		},
	}
