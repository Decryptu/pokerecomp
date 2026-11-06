class_name Gen3ScriptServices
extends RefCounted

## `scrcmd.c`'s frameless item, money, party, string and trainer-flag commands.

const VAR_RESULT: int = 0x800D
const VAR_0X8004: int = 0x8004
const PARTY_SIZE: int = 6
const COMMANDS: Array[String] = ["additem", "removeitem", "checkitem", "checkitemspace", "checkitemtype",
	"addpcitem", "checkpcitem", "addmoney", "removemoney", "checkmoney", "checkcoins", "addcoins", "removecoins",
	"bufferspeciesname", "bufferleadmonspeciesname", "bufferpartymonnick", "bufferitemname", "bufferitemnameplural",
	"buffermovename", "buffernumberstring", "bufferstdstring", "bufferstring", "checkplayergender", "getpartysize",
	"checkpartymove", "checktrainerflag", "settrainerflag", "cleartrainerflag", "setrespawn", "setworldmapflag",
	"comparestat"]
const VERSION_NAMES: Dictionary = {
	RomRegistry.RUBY: "RUBY", RomRegistry.SAPPHIRE: "SAPPHIRE", RomRegistry.FIRERED: "FIRERED",
	RomRegistry.LEAFGREEN: "LEAFGREEN", RomRegistry.EMERALD: "EMERALD",
}

var strings: Array[String] = ["", "", ""] # `gStringVar1` to `gStringVar3`, decoded.
var gender: int = 0
var _data: GameData
var _events: Gen3EventData


func _init(data: GameData, events: Gen3EventData) -> void:
	_data = data
	_events = events
	if events.bag == null:
		events.bag = Gen3Bag.new(data, events)


func run(command: String, operands: Array, context: Gen3ScriptContext) -> bool: # False for a command the current data cannot honor, which the host reports as a fault.
	if command.begins_with("buffer"):
		return _buffer(command, operands)
	if command in ["checkmoney", "addmoney", "removemoney", "checkcoins", "addcoins", "removecoins"]:
		_money(command, operands)
		return true
	if command.ends_with("item") or command in ["checkitemspace", "checkitemtype"]:
		_item(command, operands)
		return true
	return _record(command, operands, context)


func _item(command: String, operands: Array) -> void:
	var bag: Gen3Bag = _events.bag
	var item: int = _events.var_get(int(operands[0]))
	var amount: int = _events.var_get(int(operands[1])) if operands.size() > 1 else 0
	var result: int = 0
	match command:
		"additem": result = int(bag.add(item, amount & 0xFF)) # scrcmd.c truncates these four quantities to u8.
		"removeitem": result = int(bag.remove(item, amount & 0xFF))
		"checkitem": result = int(bag.has(item, amount & 0xFF))
		"checkitemspace": result = int(bag.has_space(item, amount & 0xFF))
		"checkitemtype": result = bag.pocket_of(item)
		"addpcitem": result = int(bag.pc_add(item, amount))
		"checkpcitem": result = int(bag.pc_has(item, amount))
	_events.var_set(VAR_RESULT, result)


func _money(command: String, operands: Array) -> void:
	var bag: Gen3Bag = _events.bag
	if command.ends_with("money"):
		if int(operands[1]) != 0:
			return
		var amount: int = int(operands[0])
		match command:
			"addmoney": bag.add_money(amount)
			"removemoney": bag.remove_money(amount)
			"checkmoney": _events.var_set(VAR_RESULT, int(bag.money >= amount))
		return
	match command:
		"checkcoins": _events.var_set(int(operands[0]), bag.coins)
		"addcoins": _events.var_set(VAR_RESULT, int(not bag.add_coins(_events.var_get(int(operands[0])))))
		"removecoins": _events.var_set(VAR_RESULT, int(not bag.remove_coins(_events.var_get(int(operands[0])))))


func _buffer(command: String, operands: Array) -> bool:
	var slot: int = int(operands[0])
	if slot < 0 or slot >= strings.size():
		return false
	if command == "bufferstring":
		var row: Dictionary = _data.world_script_data("texts", Gen3Layout.rom_offset(int(operands[1])))
		if row.is_empty():
			return false
		var bytes := PackedByteArray(row["bytes"])
		strings[slot] = Gen3Text.decode_fixed(_events.game, bytes, 0, bytes.size())
		return true
	var value: int = _events.var_get(int(operands[1])) if operands.size() > 1 else 0
	var text: String = ""
	match command:
		"bufferspeciesname": text = String(_data.species(value).get("name", ""))
		"bufferleadmonspeciesname": text = _lead_species_name()
		"bufferpartymonnick":
			if value >= _events.party.size():
				return false
			text = String(_events.party[value]["nickname"])
		"bufferitemname": text = _item_name(value)
		"bufferitemnameplural": text = _item_name_plural(value, _events.var_get(int(operands[2])))
		"buffermovename": text = String(_data.move(value).get("name", ""))
		"buffernumberstring": text = str(value)
		"bufferstdstring": text = _data.world_std_string(value)
		_: return false
	strings[slot] = text
	return true


func _item_name(item: int) -> String:
	return String(_data.item(item).get("name", ""))


func _item_name_plural(item: int, quantity: int) -> String: # `CopyItemNameHandlePlural`, with `GetBerryCountString` taking `gBerries`' short name from the item's.
	if item == Gen3Bag.POKE_BALL:
		return _item_name(item) if quantity < 2 else "POKé BALLS"
	if item >= Gen3Bag.FIRST_BERRY and item <= Gen3Bag.LAST_BERRY and quantity >= 2:
		return _item_name(item).trim_suffix("BERRY") + "BERRIES"
	return _item_name(item)


func _lead_species_name() -> String: # `GetLeadMonIndex`: the first Pokémon that is not an egg, else the first row.
	for mon: Dictionary in _events.party:
		if not bool(mon["egg"]):
			return String(_data.species(int(mon["species"])).get("name", ""))
	return String(_data.species(int(_events.party[0]["species"])).get("name", "")) if not _events.party.is_empty() else ""


func _record(command: String, operands: Array, context: Gen3ScriptContext) -> bool:
	var value: int = _events.var_get(int(operands[0])) if not operands.is_empty() else 0
	match command:
		"checkplayergender": _events.var_set(VAR_RESULT, gender)
		"getpartysize": _events.var_set(VAR_RESULT, _events.party.size())
		"checkpartymove": _check_party_move(int(operands[0]))
		"checktrainerflag": context.comparison = int(_events.flag_get(Gen3TrainerBattle.TRAINER_FLAGS_START + value))
		"settrainerflag": _events.flag_set(Gen3TrainerBattle.TRAINER_FLAGS_START + value)
		"cleartrainerflag": _events.flag_clear(Gen3TrainerBattle.TRAINER_FLAGS_START + value)
		"setrespawn": _events.respawn = value
		"setworldmapflag": _events.flag_set(int(operands[0]))
		"comparestat":
			context.comparison = Gen3ScriptContext._compare(int(_events.stats.get(int(operands[0]), 0)), int(operands[1]))
		_: return false
	return true


func _check_party_move(move: int) -> void:
	_events.var_set(VAR_RESULT, PARTY_SIZE)
	for index: int in _events.party.size():
		var mon: Dictionary = _events.party[index]
		if not bool(mon["egg"]) and move in mon["moves"]:
			_events.var_set(VAR_RESULT, index)
			_events.var_set(VAR_0X8004, int(mon["species"]))
			return


func usable_mons() -> int: # `GetMonsStateToDoubles_2`: how many unfainted, hatched Pokémon the player can send out.
	var count: int = 0
	for mon: Dictionary in _events.party:
		if not bool(mon["egg"]) and int(mon["hp"]) != 0:
			count += 1
	return count


func doubles_state() -> int: # `HasEnoughMonsForDoubleBattle`'s `PLAYER_HAS_*`: two usable 0, a lone Pokémon 1, one usable of several 2.
	if _events.party.size() == 1:
		return 1
	return 0 if usable_mons() > 1 else 2


func placeholders() -> Dictionary: # The values of `GetExpandedPlaceholder`, the string buffers first so that their own placeholders expand too.
	var frlg: bool = _events.game in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN]
	var rival: String = _events.rival_name
	if rival.is_empty():
		rival = ("GREEN" if gender == 0 else "RED") if frlg else ("MAY" if gender == 0 else "BRENDAN")
	return {"STR_VAR_1": strings[0], "STR_VAR_2": strings[1], "STR_VAR_3": strings[2], "UNKNOWN_STR": "", "KUN": "",
		"PLAYER": _events.player_name, "RIVAL": rival, "VERSION": VERSION_NAMES[_events.game],
		"AQUA": "AQUA", "MAGMA": "MAGMA", "ARCHIE": "ARCHIE", "MAXIE": "MAXIE", "KYOGRE": "KYOGRE",
		"GROUDON": "GROUDON"}
