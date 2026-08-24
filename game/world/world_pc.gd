class_name Gen2WorldPC
extends RefCounted

## `engine/events/pokecenter_pc.asm`: the Pokemon Center's top menu, the item
## PC behind its `<PLAYER>'S PC` row, and the two transactions that move a stack
## between the bag and `wPCItems`.
##
## Scene-free like the other world hosts. The rows and their per-state lists are
## the source's own tables; a host draws whichever list [method top_menu] and
## [method players_pc_menu] return and calls the transactions below. The commit
## boundary is [Gen2WorldTransaction], the same one the mart, Kurt and the bag
## go through.
##
## Every row of both lists is built. MAIL BOX is `_PlayerMailBoxMenu` over
## [member Gen2SaveData.mailbox] and its own submenu below, DECORATION is
## [Gen2WorldDecoration]'s and HALL OF FAME is [Gen2HallOfFame]'s viewer over
## [member Gen2SaveData.hall_of_fame].

## `PokemonCenterPC.Jumptable` indexes.
const PCPCITEM_PLAYERS_PC: int = 0
const PCPCITEM_BILLS_PC: int = 1
const PCPCITEM_OAKS_PC: int = 2
const PCPCITEM_HALL_OF_FAME: int = 3
const PCPCITEM_TURN_OFF: int = 4

## `PokemonCenterPC.WhichPC`, the three lists `.ChooseWhichPCListToUse` picks
## between: before the Pokedex, after it, and after the Hall of Fame. The lists
## themselves are imported.
const PCPC_BEFORE_POKEDEX: int = 0
const PCPC_BEFORE_HOF: int = 1
const PCPC_POSTGAME: int = 2

## `PlayersPCMenuData.PlayersPCMenuPointers` indexes.
const PLAYERSPCITEM_WITHDRAW_ITEM: int = 0
const PLAYERSPCITEM_DEPOSIT_ITEM: int = 1
const PLAYERSPCITEM_TOSS_ITEM: int = 2
const PLAYERSPCITEM_MAIL_BOX: int = 3
const PLAYERSPCITEM_DECORATION: int = 4
const PLAYERSPCITEM_LOG_OFF: int = 5
const PLAYERSPCITEM_TURN_OFF: int = 6

## `PlayersPCMenuData.WhichPC`. The bedroom's own list is the one that ends in
## TURN OFF and carries DECORATION; a Pokemon Center's ends in LOG OFF, because
## the top menu is still open behind it.
const PLAYERSPC_NORMAL: int = 0
const PLAYERSPC_HOUSE: int = 1

## What `PlaceNthMenuStrings` would draw the player's own name for. The importer
## keeps the cartridge's marker rather than a placeholder.
const PLAYER_MARKER: String = "<PLAYER>"

## The rows above with nothing behind them, dropped from every list rather than
## offered and refused. See the class comment for what each needs first.
const UNBUILT_TOP_MENU_ROWS: Array[int] = []
const UNBUILT_PLAYERS_PC_ROWS: Array[int] = []


## `_BillsPC.MenuData`'s five rows, in its `.Jumptable`'s own order. Inline menu
## strings inside `bills_pc_top.asm` that no script points at, so nothing imports
## them and they are the host's, the way [Gen2BoxScreen]'s own two are.
const BILLSPCITEM_WITHDRAW: int = 0
const BILLSPCITEM_DEPOSIT: int = 1
const BILLSPCITEM_CHANGE_BOX: int = 2
const BILLSPCITEM_MOVE_WITHOUT_MAIL: int = 3
const BILLSPCITEM_SEE_YA: int = 4
const BILLS_PC_ROWS: Array[String] = [
	"WITHDRAW PKMN", "DEPOSIT PKMN", "CHANGE BOX", "MOVE PKMN W/O MAIL", "SEE YA!",
]
## `_PCWhatText` and `_PCGottaHavePokemonText`, the two lines `.LogIn` and
## `.CheckCanUsePC` print. Both are `text_far` stubs in `data/text/common_2.asm`
## that no script reaches either.
const BILLS_PC_WHAT: String = "What?"
const BILLS_PC_NEEDS_POKEMON: String = "You gotta have\n#MON to call!"

## `MailboxPC.SubMenuData`'s four rows, inline menu strings the way BILL'S PC's
## own five are, and the five `text_far` stubs `.PutInPack` and `.AttachMail`
## print through. Kept here rather than imported for the same reason: nothing
## points at them, so there is no table to walk.
const MAILBOXITEM_READ: int = 0
const MAILBOXITEM_PUT_IN_PACK: int = 1
const MAILBOXITEM_ATTACH: int = 2
const MAILBOXITEM_CANCEL: int = 3
const MAILBOX_ROWS: Array[String] = [
	"READ MAIL", "PUT IN PACK", "ATTACH MAIL", "CANCEL",
]
const MAILBOX_EMPTY: String = "There's no MAIL\nhere."
const MAILBOX_MESSAGE_LOST: String = "The MAIL's message\nwill be lost. OK?"
const MAILBOX_PACK_FULL: String = "The PACK is full."
const MAILBOX_CLEARED: String = "The cleared MAIL\nwas put away."
const MAILBOX_ALREADY_HOLDING: String = "It's already hold-\ning an item."
const MAILBOX_EGG: String = "An EGG can't hold\nany MAIL."
const MAILBOX_MOVED: String = "The MAIL was moved\nfrom the MAILBOX."

## Every row of the machine's own menu is built: MOVE PKMN W/O MAIL is
## [Gen2BoxScreen]'s `MODE_MOVE`, which is `_MovePKMNWithoutMail`'s own two
## joypad passes over the same listing.
const UNBUILT_BILLS_PC_ROWS: Array[int] = []


## The top menu behind BILL'S PC, as `{row, name}` in the source's own order.
static func bills_pc_menu() -> Array:
	var out: Array = []
	for row: int in BILLS_PC_ROWS.size():
		if row in UNBUILT_BILLS_PC_ROWS:
			continue
		out.append({"row": row, "name": BILLS_PC_ROWS[row]})
	return out


## `.ChooseWhichPCListToUse`: the Pokedex first, then `wHallOfFameCount`, which
## is the induction flag here because the save model counts no records.
static func top_menu_list(state: Gen2WorldState) -> int:
	if state == null or not state.is_engine_flag_active(Gen2WorldState.ENGINE_POKEDEX):
		return PCPC_BEFORE_POKEDEX
	return PCPC_POSTGAME if state.hall_of_fame() else PCPC_BEFORE_HOF


## The top menu's rows for [param state], as `{row, name}` in the source list's
## own order. [param player_name] fills the `<PLAYER>` the cartridge stores in
## the first row's own string.
static func top_menu(
	data: GameData, state: Gen2WorldState, player_name: String = ""
) -> Array:
	return _rows(
		data, false, _list(data, false, top_menu_list(state)),
		UNBUILT_TOP_MENU_ROWS, player_name
	)


## The item PC's own rows. [param house] picks `PLAYERSPC_HOUSE`, which is what
## `_PlayersHousePC` passes and the Pokemon Center's `PlayersPC` does not.
static func players_pc_menu(data: GameData, house: bool) -> Array:
	return _rows(
		data, true, _list(data, true, PLAYERSPC_HOUSE if house else PLAYERSPC_NORMAL),
		UNBUILT_PLAYERS_PC_ROWS, ""
	)


## One imported `.WhichPC` list, or an empty one on a cache without the tables,
## which leaves the menu with nothing to offer rather than a guessed order.
static func _list(data: GameData, players: bool, index: int) -> Array:
	if data == null:
		return []
	var lists: Array = data.pokecenter_pc_lists(players)
	if index < 0 or index >= lists.size() or not lists[index] is Array:
		return []
	return lists[index]


## `PlaceNthMenuStrings`: each list entry names a jumptable row, and the row
## names its own string.
static func _rows(
	data: GameData, players: bool, list: Array, unbuilt: Array[int],
	player_name: String
) -> Array:
	var order: Array[String] = RomLayout.POKECENTER_PC_PLAYERS_ORDER if players \
		else RomLayout.POKECENTER_PC_ROWS
	var out: Array = []
	for raw_row: Variant in list:
		var row: int = int(raw_row)
		if row < 0 or row >= order.size() or row in unbuilt:
			continue
		var name: String = data.pokecenter_pc_row(String(order[row]), players)
		if name.is_empty():
			continue
		out.append({
			"row": row,
			"name": name.replace(
				PLAYER_MARKER, player_name if not player_name.is_empty() else "PLAYER"
			),
		})
	return out


## `PC_CheckPartyForPokemon`: an empty party cannot open the Pokemon Center's PC
## at all, which is the one refusal the top menu has of its own.
static func can_open(save: Gen2SaveData) -> bool:
	return save != null and not save.party.is_empty()


## The bag as rows a deposit list can draw, and the PC as rows a withdraw or
## toss list can. Both are sorted by item number, which is the only order a flat
## map has; the source's packed arrays keep insertion order instead.
static func bag_entries(data: GameData, state: Gen2WorldState) -> Array:
	return _entries(data, state.items() if state != null else {})


static func pc_entries(data: GameData, state: Gen2WorldState) -> Array:
	return _entries(data, state.pc_items() if state != null else {})


static func _entries(data: GameData, owned: Dictionary) -> Array:
	var out: Array = []
	if data == null:
		return out
	var numbers: Array = owned.keys()
	numbers.sort()
	for raw_item: Variant in numbers:
		var item: int = int(raw_item)
		var quantity: int = int(owned[raw_item])
		if quantity <= 0:
			continue
		var definition: Dictionary = data.item(item)
		if definition.is_empty():
			continue
		out.append({
			"item": item,
			"name": String(definition.get("name", "UNKNOWN")),
			"quantity": quantity,
		})
	return out


## `PlayerDepositItemMenu`: the stack leaves `wNumItems` and arrives in
## `wNumPCItems`. The source refuses an item whose `CheckItemMenu` attribute is
## one of the three `.no_toss` rows, which is what keeps a key item out of the
## PC.
static func deposit(
	world: Gen2WorldAPI, save: Gen2SaveData, item: int, quantity: int = 1,
	persist: bool = true
) -> Dictionary:
	return _transfer(world, save, item, quantity, true, persist)


## `PlayerWithdrawItemMenu`, which is the same move the other way and refuses
## nothing: anything in the PC came out of the bag.
static func withdraw(
	world: Gen2WorldAPI, save: Gen2SaveData, item: int, quantity: int = 1,
	persist: bool = true
) -> Dictionary:
	return _transfer(world, save, item, quantity, false, persist)


## `PlayerTossItemMenu`'s `TossItemFromPC`, which is `TossItem` on the PC's own
## array. `CanToss` is read the same way it is for the bag.
static func toss(
	world: Gen2WorldAPI, save: Gen2SaveData, item: int, quantity: int = 1,
	persist: bool = true
) -> Dictionary:
	if world == null or world.data == null or world.state == null:
		return Gen2WorldTransaction.failure(&"missing_world", {})
	var definition: Dictionary = world.data.item(item)
	if definition.is_empty():
		return Gen2WorldTransaction.failure(&"unknown_item", {"item": item})
	if not Gen2WorldPack.can_toss(world.data, item):
		return Gen2WorldTransaction.failure(&"item_cannot_be_tossed", {"item": item})
	var owned: int = world.state.pc_item_quantity(item)
	if quantity < 1 or quantity > owned:
		return Gen2WorldTransaction.failure(&"invalid_toss_quantity", {
			"item": item, "quantity": quantity, "owned": owned,
		})
	return _commit(world, save, persist, {"pc_items": {item: owned - quantity}}, {
		"item": item,
		"name": String(definition.get("name", "UNKNOWN")),
		"quantity": quantity,
		"bag": world.state.item_quantity(item),
		"pc": owned - quantity,
	})


static func _transfer(
	world: Gen2WorldAPI, save: Gen2SaveData, item: int, quantity: int,
	to_pc: bool, persist: bool
) -> Dictionary:
	if world == null or world.data == null or world.state == null:
		return Gen2WorldTransaction.failure(&"missing_world", {})
	var definition: Dictionary = world.data.item(item)
	if definition.is_empty():
		return Gen2WorldTransaction.failure(&"unknown_item", {"item": item})
	if to_pc and not Gen2WorldPack.can_toss(world.data, item):
		return Gen2WorldTransaction.failure(&"item_cannot_be_deposited", {"item": item})
	var bag: int = world.state.item_quantity(item)
	var pc: int = world.state.pc_item_quantity(item)
	var source: int = bag if to_pc else pc
	var destination: int = pc if to_pc else bag
	if quantity < 1 or quantity > source:
		return Gen2WorldTransaction.failure(&"invalid_transfer_quantity", {
			"item": item, "quantity": quantity, "owned": source,
		})
	if destination + quantity > Gen2WorldPack.MAX_ITEM_STACK:
		return Gen2WorldTransaction.failure(&"item_stack_full", {
			"item": item, "quantity": quantity, "owned": destination,
		})
	## `ReceiveItem` fails on a full destination list before anything is taken
	## from the source, which is what `.PackFull` and `.NoRoomInPC` report. The
	## bag's own check is per pocket, so it goes through the pack's; the PC is
	## one flat list of fifty.
	if to_pc:
		if destination == 0 and world.state.pc_items().size() >= Gen2WorldPack.MAX_PC_ITEMS:
			return Gen2WorldTransaction.failure(&"pc_full", {"item": item})
	else:
		var room: Dictionary = Gen2WorldPack.receive_check(
			world.data, world.state.items(), item, quantity
		)
		if not bool(room.get("ok", false)):
			return Gen2WorldTransaction.failure(
				StringName(room.get("reason", &"pack_full")), {"item": item}
			)
	var changes: Dictionary = {
		"items": {item: bag - quantity if to_pc else bag + quantity},
		"pc_items": {item: pc + quantity if to_pc else pc - quantity},
	}
	return _commit(world, save, persist, changes, {
		"item": item,
		"name": String(definition.get("name", "UNKNOWN")),
		"quantity": quantity,
		"bag": changes["items"][item],
		"pc": changes["pc_items"][item],
	})


## `MailboxPC`'s own rows: one per stored message, printed by
## `MailboxPC_PrintMailAuthor`, which is the author and nothing else.
static func mailbox_entries(save: Gen2SaveData) -> Array:
	var out: Array = []
	if save == null:
		return out
	for index: int in save.mailbox.size():
		var mail: Gen2SaveMail = save.mailbox[index]
		out.append({"row": index, "name": mail.author if mail != null else ""})
	return out


## `MonMailAction`'s TAKE and its `SendMailToPC`. The mail leaves the party
## member with its item; nothing in the bag or the world moves, so the only
## change is to the save.
static func mailbox_send(
	world: Gen2WorldAPI, save: Gen2SaveData, slot: int, persist: bool = true
) -> Dictionary:
	var opened: Dictionary = Gen2WorldTransaction.begin(world, save)
	if not bool(opened.get("ok", false)):
		return opened
	var candidate: Gen2SaveData = opened["candidate"]
	if not Gen2SaveMail.send_to_pc(candidate, slot):
		## `.MailboxFull` is the one refusal the routine has; a member holding
		## no mail cannot reach the row that calls it.
		return Gen2WorldTransaction.failure(&"mailbox_full", {"slot": slot})
	return _committed(world, save, candidate, persist, {"slot": slot})


## `.PutInPack`: the message is lost, its `Type` byte becomes an ordinary item
## in the bag, and the mailbox entry is deleted behind it. `ReceiveItem` is
## asked first, so a full pack leaves the message where it is.
static func mailbox_to_pack(
	world: Gen2WorldAPI, save: Gen2SaveData, index: int, persist: bool = true
) -> Dictionary:
	var opened: Dictionary = Gen2WorldTransaction.begin(world, save)
	if not bool(opened.get("ok", false)):
		return opened
	var candidate: Gen2SaveData = opened["candidate"]
	if index < 0 or index >= candidate.mailbox.size():
		return Gen2WorldTransaction.failure(&"unknown_mail", {"index": index})
	var item: int = (candidate.mailbox[index] as Gen2SaveMail).item
	var room: Dictionary = Gen2WorldPack.receive_check(
		world.data, world.state.items(), item, 1
	)
	if not bool(room.get("ok", false)):
		return Gen2WorldTransaction.failure(
			StringName(room.get("reason", &"pack_full")), {"item": item}
		)
	var before: Gen2WorldSnapshot = world.snapshot()
	var applied: Dictionary = world.state.apply_changes({}, {}, {
		"items": {item: world.state.item_quantity(item) + 1},
	})
	if not bool(applied.get("ok", false)):
		return Gen2WorldTransaction.failure(&"pc_state_failed", applied)
	Gen2SaveMail.delete_from_pc(candidate, index)
	var committed: Dictionary = Gen2WorldTransaction.commit(
		world, save, candidate, before, persist
	)
	if not bool(committed.get("ok", false)):
		return committed
	return {
		"ok": true, "item": item,
		"name": String(world.data.item(item).get("name", "UNKNOWN")),
	}


## `.AttachMail`, once `PartyMenuSelect` has picked a member. The two refusals
## in front of it are the caller's, because both print and go back to the same
## list: an egg cannot hold mail and a member already holding an item is not
## asked to swap.
static func mailbox_attach(
	world: Gen2WorldAPI, save: Gen2SaveData, index: int, slot: int,
	persist: bool = true
) -> Dictionary:
	var opened: Dictionary = Gen2WorldTransaction.begin(world, save)
	if not bool(opened.get("ok", false)):
		return opened
	var candidate: Gen2SaveData = opened["candidate"]
	var refusal: StringName = attach_refusal(candidate, slot)
	if refusal != &"":
		return Gen2WorldTransaction.failure(refusal, {"slot": slot})
	if not Gen2SaveMail.move_from_pc_to_party(candidate, index, slot):
		return Gen2WorldTransaction.failure(&"unknown_mail", {"index": index})
	return _committed(world, save, candidate, persist, {"slot": slot, "index": index})


## `.AttachMail`'s own two branches: `cp EGG` and the held-item test.
static func attach_refusal(save: Gen2SaveData, slot: int) -> StringName:
	if save == null or slot < 0 or slot >= save.party.size():
		return &"unknown_member"
	var mon: Gen2SaveMon = save.party[slot]
	if mon == null:
		return &"unknown_member"
	if mon.is_egg:
		return &"egg"
	return &"already_holding" if mon.item != 0 else &""


## A candidate the caller has already changed, written through the same
## boundary the item transactions use. The world is unchanged, so the snapshot
## a refusal would restore is the live one.
static func _committed(
	world: Gen2WorldAPI, save: Gen2SaveData, candidate: Gen2SaveData,
	persist: bool, answer: Dictionary
) -> Dictionary:
	var committed: Dictionary = Gen2WorldTransaction.commit(
		world, save, candidate, world.snapshot(), persist
	)
	if not bool(committed.get("ok", false)):
		return committed
	var out: Dictionary = answer.duplicate()
	out["ok"] = true
	return out


static func _commit(
	world: Gen2WorldAPI, save: Gen2SaveData, persist: bool,
	changes: Dictionary, answer: Dictionary
) -> Dictionary:
	var before: Gen2WorldSnapshot = world.snapshot()
	var applied: Dictionary = world.state.apply_changes({}, {}, changes)
	if not bool(applied.get("ok", false)):
		return Gen2WorldTransaction.failure(&"pc_state_failed", applied)
	var committed: Dictionary = Gen2WorldTransaction.run(world, save, before, persist)
	if not bool(committed.get("ok", false)):
		return committed
	var out: Dictionary = answer.duplicate()
	out["ok"] = true
	return out
