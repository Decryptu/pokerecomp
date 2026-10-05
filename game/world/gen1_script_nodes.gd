class_name Gen1ScriptNodes
extends RefCounted


const GEN1_PICK_UP_RUN: String = "pick_up_item"

## `CardKeySuccessText` and `CardKeyFailText`, the two `TextPredefs` rows
## `PrintCardKeyText` prints.
const GEN1_CARD_KEY_RUN: String = "card_key"

## What each node [method Gen1WorldImporter.decode_script] wrote becomes. False
## drops the whole interaction, the way an undecoded row does.
const GEN1_SCRIPT_NODES: Dictionary = {
	"text": &"_gen1_node_text",
	"serial_status": &"_gen1_node_serial_status",
	"link_state": &"_gen1_node_link_state",
	"flag": &"_gen1_node_flag",
	"branch": &"_gen1_node_branch",
	"flag_test": &"_gen1_node_flag_test",
	"has_item": &"_gen1_node_has_item",
	"has_money": &"_gen1_node_has_money",
	"has_coins": &"_gen1_node_has_coins",
	"spend_money": &"_gen1_node_spend_money",
	"add_coins": &"_gen1_node_add_coins",
	"money_box": &"_gen1_node_money_box",
	"coin_box": &"_gen1_node_coin_box",
	"give_item": &"_gen1_resolve_gift",
	"take_item": &"_gen1_take_item",
	"toggle_object": &"_gen1_node_toggle",
	"pick_up_item": &"_gen1_pick_up_item",
	"give_pokemon": &"_gen1_resolve_gift_pokemon",
	"pokedex": &"_gen1_node_pokedex",
	"facing": &"_gen1_node_facing",
	"badge": &"_gen1_node_badge",
	"dex_count": &"_gen1_node_dex_count",
	"tileset": &"_gen1_node_tileset",
	"destination_warp": &"_gen1_node_destination_warp",
	"diploma": &"_gen1_node_diploma",
	"slot_machine": &"_gen1_node_slot_machine",
	"surfing_minigame": &"_gen1_node_surfing_minigame",
	"printer": &"_gen1_node_printer",
	"picture": &"_gen1_node_picture",
	"help_menu": &"_gen1_node_help_menu",
	"ss_anne_leaves": &"_gen1_node_ss_anne_leaves",
	"screen_tile": &"_gen1_node_screen_tile",
	"name_item": &"_gen1_node_name_item",
	"map_text": &"_gen1_node_map_text",
	"facility": &"_gen1_node_facility",
	"replace_block": &"_gen1_node_replace_block",
	"player_coord": &"_gen1_node_player_coord",
	"walk": &"_gen1_node_walk",
	"day_care": &"_gen1_node_day_care",
	"town_map": &"_gen1_node_town_map",
	"elevator": &"_gen1_node_elevator",
	"set_map_script": &"_gen1_node_set_map_script",
	"player_in_array": &"_gen1_node_player_in_array",
	"object_facing": &"_gen1_node_object_facing",
	"object_move": &"_gen1_node_object_move",
	"object_stay": &"_gen1_node_object_stay",
	"movement_running": &"_gen1_node_movement_running",
	"coord_index": &"_gen1_node_coord_index",
	"guard_drink": &"_gen1_node_guard_drink",
	"arrow_movement": &"_gen1_node_arrow_movement",
	"wild_battle": &"_gen1_node_wild_battle",
	"battle_outcome": &"_gen1_node_battle_outcome",
	"save_coord_index": &"_gen1_node_save_coord_index",
	"saved_coord_index": &"_gen1_node_saved_coord_index",
	"player_facing": &"_gen1_node_player_facing",
	"map_script_table": &"_gen1_node_map_script_table",
	"set_last_map": &"_gen1_node_set_last_map",
	"safari_balls": &"_gen1_node_safari_balls",
	"safari_admission": &"_gen1_node_safari_admission",
	"safari_steps": &"_gen1_node_safari_steps",
	"set_blackout_map": &"_gen1_node_set_blackout_map",
	"set_player_coord": &"_gen1_node_set_player_coord",
	"set_starter": &"_gen1_node_set_starter",
	"set_riding": &"_gen1_node_set_riding",
	"starter": &"_gen1_node_starter",
	"riding": &"_gen1_node_riding",
	"movement_script_running": &"_gen1_node_movement_script_running",
	"npc_movement_script": &"_gen1_node_npc_movement_script",
	"volatile": &"_gen1_node_volatile",
	"map_load_bit": &"_gen1_node_map_load_bit",
	"store_byte": &"_gen1_node_store_byte",
	"gym_trash": &"_gen1_node_gym_trash",
	"object_coord_move": &"_gen1_node_object_coord_move",
	"volatile_test": &"_gen1_node_volatile_test",
	"boulder_on": &"_gen1_node_boulder_on",
	"coord_lookup": &"_gen1_node_coord_lookup",
	"emote": &"_gen1_node_emote",
	"object_path": &"_gen1_node_object_path",
	"trainer_battle": &"_gen1_node_trainer_battle",
	"trainer_battle_object": &"_gen1_node_trainer_battle_object",
	"warp_to": &"_gen1_node_warp_to",
	"text_table": &"_gen1_node_text_table",
	"object_position": &"_gen1_node_object_position",
	"object_position_save": &"_gen1_node_object_position_kept",
	"object_position_restore": &"_gen1_node_object_position_kept",
	"heal_party": &"_gen1_node_heal_party",
	"hall_of_fame": &"_gen1_node_hall_of_fame",
	"save_game": &"_gen1_node_save_game",
	"reset_game": &"_gen1_node_reset_game",
	"flag_range": &"_gen1_node_flag_range",
	"badge_guards": &"_gen1_node_badge_guards",
	"badges_byte": &"_gen1_node_badges_byte",
	"name_species": &"_gen1_node_name_species",
	"name_badge": &"_gen1_node_name_badge",
	"scratch": &"_gen1_node_scratch",
	"scratch_test": &"_gen1_node_scratch_test",
	"random": &"_gen1_node_random",
	"random_bit": &"_gen1_node_random_bit",
	"talking_to": &"_gen1_node_talking_to",
	"pikachu_test": &"_gen1_node_pikachu_test",
	"sound": &"_gen1_node_sound",
	"pikachu": &"_gen1_node_pikachu",
	"pikachu_text": &"_gen1_node_pikachu_text",
	"pikachu_movement": &"_gen1_node_pikachu_movement",
	"pikachu_talk": &"_gen1_node_pikachu_talk",
	"jigglypuff": &"_gen1_node_jigglypuff",
	"oaks_aide": &"_gen1_node_oaks_aide",
	"filtered_bag": &"_gen1_node_filtered_bag",
	"menu_cancel": &"_gen1_node_menu_cancel",
	"menu_row": &"_gen1_node_menu_row",
	"menu_item": &"_gen1_node_menu_item",
	"dex_rating": &"_gen1_node_dex_rating",
	"set_fossil": &"_gen1_node_set_fossil",
	"redraw_map_view": &"_gen1_node_redraw",
	"delay": &"_gen1_node_delay",
	"fade": &"_gen1_node_fade",
	"copy_name": &"_gen1_node_copy_name",
	"party_menu": &"_gen1_node_party_menu",
	"name_mon": &"_gen1_node_name_mon",
	"name_party_mon": &"_gen1_node_name_party_mon",
	"mon_ot": &"_gen1_node_mon_ot",
	"list_menu": &"_gen1_node_list_menu",
}


## `CheckForHiddenEventOrBookshelfOrCardKeyDoor` runs first on A and a row
## found spends the press; a card key door alone leaves `hItemAlreadyFound` at
## $ff, so the sign and sprite check still runs.
static func _gen1_interact(world: Gen2WorldAPI) -> Array:
	if world.current_map == null:
		return []
	var hidden: Variant = _gen1_hidden_nodes(world)
	if hidden != null:
		world._gen1_steps = _gen1_script_steps(world, {"script": hidden})
		return Gen1MapScripts._gen1_result(world)
	world._gen1_steps = _gen1_card_key_steps(world) + _gen1_sign_or_sprite(world)
	return Gen1MapScripts._gen1_result(world) if not world._gen1_steps.is_empty() else []


## `CheckForHiddenEvent`, then `PrintBookshelfText`, or null when neither found
## anything. An empty list is a row that answered and printed nothing.
static func _gen1_hidden_nodes(world: Gen2WorldAPI) -> Variant:
	for row: Dictionary in world.current_map.events.get("hidden_events", []) as Array:
		if Vector2i(int(row["x"]), int(row["y"])) == world.facing_cell():
			return row.get("script", [])
	var shelf: Array = _gen1_bookshelf_nodes(world)
	if shelf.is_empty():
		return null
	return shelf


## `PrintBookshelfText` reads `lda_coord 8, 7`, the faced cell's bottom left
## tile, and answers a player facing up alone.
static func _gen1_bookshelf_nodes(world: Gen2WorldAPI) -> Array:
	if world.current_tileset == null or world.player_facing != Gen2WorldSprite.FACING_UP:
		return []
	return (world.current_tileset.bookshelves as Dictionary).get(
		world._gen1_tile_drawn_at(world.facing_cell()), []
	) as Array


## `IsSpriteOrSignInFrontOfPlayer`: a sign on the faced cell answers first and
## returns, and only then is a sprite looked for.
static func _gen1_sign_or_sprite(world: Gen2WorldAPI) -> Array:
	var event: Dictionary = Gen1FacilityScripts._gen1_event_at(world, world.facing_cell(), &"bg_events")
	if event.is_empty():
		event = Gen1FacilityScripts._gen1_event_at(world, world.object_facing_cell(), &"objects")
		world._gen1_last_sprite_index = int(event.get("object_index", -1))
		_gen1_face_talked_object(world, world._gen1_last_sprite_index)
	if event.is_empty() and world.pikachu != null \
		and world.pikachu.stands_in_front(world.player_cell, world.facing_direction()):
		world.pikachu.status |= Gen1Pikachu.STATUS_FACE_PLAYER
		return _gen1_pikachu_talk_steps(world)
	var text_id: int = int(event.get("text", 0))
	var row: Dictionary = gen1_text_at(world, text_id)
	var steps: Array = Gen1FacilityScripts._gen1_trainer_steps(world, row, event)
	if steps.is_empty():
		steps = Gen1FacilityScripts._gen1_facility_steps(world, row, text_id)
	if steps.is_empty():
		steps = _gen1_script_steps(world, row, event)
	if not steps.is_empty():
		return steps
	var text: String = gen1_filled_text(world, String(row.get("text", "")))
	return [] if text.is_empty() else [{"type": &"text", "text": text}]


## `IsSpriteInFrontOfPlayer`'s BIT_FACE_PLAYER; the talk's $7f lands on slot fifteen.
static func _gen1_face_talked_object(world: Gen2WorldAPI, index: int) -> void:
	if index < 0 or index >= world.objects.size() \
		or bool(world._gen1_volatile.get("no_npc_face_player", false)):
		return
	(world.objects[index] as Gen2WorldObject).facing = world._facing_toward(
		(world.objects[index] as Gen2WorldObject).cell, world.player_cell
	)


## `PrintCardKeyText`: the CARD KEY opens the door in front of the player and
## the world remembers where it stood; without the key there is only a refusal.
static func _gen1_card_key_steps(world: Gen2WorldAPI) -> Array:
	var door: Dictionary = _gen1_card_key_door(world)
	if door.is_empty():
		return []
	if world.state == null or int((world.state.items() as Dictionary).get(
		Gen1Layout.ITEM_CARD_KEY, 0
	)) < 1:
		return [_gen1_card_key_box(world, "card_key_fail")]
	door["type"] = &"block"
	door["card_key"] = true
	## `set BIT_CUR_MAP_LOADED_1` behind the block: the floor's callback flags
	## the door on the next frame, so leaving and returning keeps it open.
	return [_gen1_card_key_box(world, "card_key_success"), door,
		{"type": &"map_load", "bit": Gen1Layout.MAP_LOADED_1_BIT},
		_gen1_sound_step(world, "sound", {"index": Gen1Sfx.SFX_GO_INSIDE})]


static func _gen1_card_key_box(world: Gen2WorldAPI, name: String) -> Dictionary:
	return {
		"type": &"text",
		"text": world.data.special_text(GEN1_CARD_KEY_RUN, name) if world.data != null else "",
	}


## `GetTileAndCoordsInFrontOfPlayer` against the door tiles, and the block
## coordinates `srl d` and `srl e` leave.
static func _gen1_card_key_door(world: Gen2WorldAPI) -> Dictionary:
	if (world.current_map.events["card_key"] as Array).is_empty():
		return {}
	var top_floor: bool = world.current_map.number == Gen1Layout.SILPH_CO_TOP_FLOOR
	var cell: Vector2i = world.facing_cell()
	var tile: int = world._gen1_tile_drawn_at(cell)
	if not Gen1Layout.CARD_KEY_DOOR_TILES.has(tile) \
		and not (top_floor and tile == Gen1Layout.CARD_KEY_TOP_FLOOR_TILE):
		return {}
	return {
		"x": cell.x >> 1, "y": cell.y >> 1,
		"block": Gen1Layout.CARD_KEY_TOP_FLOOR_BLOCK if top_floor \
			else Gen1Layout.CARD_KEY_OPEN_BLOCK,
	}


static func gen1_text_at(world: Gen2WorldAPI, text_id: int) -> Dictionary:
	if world.current_map == null:
		return {}
	if world._gen1_text_table >= 0 and world.current_map.alternate_texts.has(world._gen1_text_table):
		var rows: Array = world.current_map.alternate_texts[world._gen1_text_table]
		return rows[text_id - 1] if text_id >= 1 and text_id <= rows.size() else {}
	return world.current_map.text_at(text_id)


## The print-time names still standing in an imported Generation 1 box, which
## is every box the world or a screen hosting one of its facilities prints.
static func gen1_filled_text(world: Gen2WorldAPI, text: String) -> String:
	return Gen2TextStream.fill_names(text, {
		"player": world._player_name if not world._player_name.is_empty() \
			else Gen2WorldScriptRunner.UNNAMED,
		"rival": world.rival_name,
	})


## The boxes a `text_asm` row prints, with its branches resolved against the
## save. A taken side the importer did not read answers nothing at all, the way
## an undecoded row does.
static func _gen1_script_steps(world: Gen2WorldAPI, row: Dictionary, event: Dictionary = {}) -> Array:
	var nodes: Variant = row.get("script", [])
	if not nodes is Array or (nodes as Array).is_empty():
		return []
	var steps: Array = []
	return steps if _gen1_resolve_script(world, nodes as Array, steps, _gen1_run(world, event)) else []


## The bag, purse and object a row is walked against.
static func _gen1_run(world: Gen2WorldAPI, event: Dictionary) -> Dictionary:
	return {
		"bag": world.state.items() if world.state != null else {}, "named": "", "object": event,
		"money": world.state.money(Gen2WorldMartHost.MONEY_ACCOUNT) if world.state != null else 0,
		"coins": world.state.coins() if world.state != null else 0,
		"flags": {}, "engine_flags": {}, "flag_tests": {}, "scratch": _gen1_run_scratch(world),
	}


## `wSpriteIndex` counts objects from one.
static func _gen1_run_scratch(world: Gen2WorldAPI) -> Dictionary:
	var scratch: Dictionary = world._gen1_scratch.duplicate()
	if world.data != null and world._gen1_last_sprite_index >= 0:
		scratch[int(Gen1Layout.for_id(world.data.id)["sprite_index_wram"])] = world._gen1_last_sprite_index + 1
	return scratch


## [param run] is the bag the row is walked against, carrying what its own gifts
## have already put in it, and the name `CopyToStringBuffer` last wrote.
static func _gen1_resolve_script(world: Gen2WorldAPI, nodes: Array, steps: Array, run: Dictionary) -> bool:
	for index: int in nodes.size():
		var node: Dictionary = nodes[index]
		var op: String = String(node.get("op", ""))
		## Each of the three owns every step behind it, so the row ends there.
		if op == "trade":
			return Gen1FacilityScripts._gen1_trade(world, node, steps)
		if op == "choice":
			return Gen1FacilityScripts._gen1_script_choice(world, node, steps, run)
		if op == "menu":
			return Gen1FacilityScripts._gen1_script_menu(world, node, nodes.slice(index + 1), steps, run)
		if not GEN1_SCRIPT_NODES.has(op):
			return false
		if not Callable(Gen1ScriptNodes, GEN1_SCRIPT_NODES[op]).call(world, node, steps, run):
			return false
	return true


static func _gen1_node_text(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	var box: Dictionary = Gen1FacilityScripts._gen1_script_box(world, node, String(run["named"]), run.get("buffers", {}))
	steps.append(box)
	if run.has("cable_club_run"):
		box["press"] = false
		steps.append_array(Gen1FacilityScripts._gen1_cable_club_run_steps(int(run["cable_club_run"])))
		run.erase("cable_club_run")
	return true


static func _gen1_node_flag_index(_world: Gen2WorldAPI, node: Dictionary, run: Dictionary) -> int:
	var index: int = int(node["flag"])
	if node.has("index_source"):
		index += (int((run["scratch"] as Dictionary).get(int(node["index_source"]), 0))
			+ int(node.get("index_offset", 0))) & 0xFF
	return index


static func _gen1_node_flag(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	var shadow: Dictionary = run["engine_flags" if bool(node.get("engine", false)) else "flags"]
	var flag: int = _gen1_badge_flag_granted(world, node, _gen1_node_flag_index(world, node, run))
	shadow[flag] = bool(node["set"])
	steps.append({
		"type": &"flag",
		"flag": flag,
		"set": bool(node["set"]),
		"engine": bool(node.get("engine", false)),
	})
	return true


## The badge a site grants IS its engine flag, so a patched row moves the bit.
static func _gen1_badge_flag_granted(world: Gen2WorldAPI, node: Dictionary, flag: int) -> int:
	if world.data == null or not world.data.has_content_overlay() or not node.has("at") \
		or not bool(node.get("engine", false)):
		return flag
	var badge: int = world.data.catalog().badge_for_engine_flag(flag)
	if badge < 0:
		return flag
	var site: Dictionary = world.data.catalog().gen1_site(
		Gen2WorldCatalog.KIND_BADGE, int(node["at"]), {"badge": badge}
	)
	var moved: int = int(site.get("badge", badge)) - Gen2WorldState.KANTO_BADGE_FIRST
	return Gen2WorldState.gen1_badge_flag(moved) if moved >= 0 and moved < Gen1Layout.BADGE_COUNT else flag


static func _gen1_node_replace_block(_world: Gen2WorldAPI, node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	steps.append({
		"type": &"block", "x": int(node["x"]), "y": int(node["y"]),
		"block": int(node["block"]), "redraw": bool(node.get("redraw", true)),
	})
	return true


static func _gen1_node_delay(_world: Gen2WorldAPI, node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	steps.append(Gen1FacilityScripts._gen1_wait_step(&"gen1_delay", int(node["frames"])))
	return true


## A palette fade a step at a time; `LoadGBPal`'s has no hold.
static func _gen1_node_fade(_world: Gen2WorldAPI, node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	var fade: Array = Gen1Layout.GB_FADES[String(node["fade"])]
	var orders: Array = fade[0]
	var event: Dictionary = {"orders": orders.duplicate(), "step_frames": maxi(int(fade[1]), 1)}
	if int(fade[1]) > 0:
		steps.append(Gen1FacilityScripts._gen1_wait_step(&"palette_fade", orders.size() * int(fade[1]), event))
		return true
	event.merge({"type": &"presentation_special_applied", "kind": &"palette_fade"})
	steps.append({"type": &"event", "event": event})
	return true


static func _gen1_node_redraw(_world: Gen2WorldAPI, _node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	steps.append(Gen1MapScripts._gen1_redraw_step())
	return true


static func _gen1_node_branch(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	return _gen1_resolve_side(world, node, _gen1_branch_set(world, node, run), steps, run)


static func _gen1_node_has_item(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	var bag: Dictionary = run["bag"]
	return _gen1_resolve_side(world,
		node, int(bag.get(int(node["item"]), 0)) > 0, steps, run
	)


static func _gen1_node_has_money(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	var price: int = int(_gen1_linked_site(world,
		Gen2WorldCatalog.KIND_PRIZE, "ask_address", node, {"price": int(node["price"])}
	)["price"])
	return _gen1_resolve_side(world, node, int(run["money"]) >= price, steps, run)


static func _gen1_node_has_coins(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	var coins: int = int(run["coins"])
	var wanted: int = int(node["coins"])
	var holds: bool = coins == wanted if String(node["test"]) == "exactly" \
		else coins >= wanted
	return _gen1_resolve_side(world, node, holds, steps, run)


## `SubBCD` over `wPlayerMoney`, whose `.fill` writes zeroes across a balance it
## borrowed past.
static func _gen1_node_spend_money(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	var amount: int = int(_gen1_linked_site(world,
		Gen2WorldCatalog.KIND_PRIZE, "spend_address", node, {"price": int(node["amount"])}
	)["price"])
	var left: int = maxi(int(run["money"]) - amount, 0)
	run["money"] = left
	steps.append({"type": &"money", "amount": left})
	return true


static func _gen1_node_add_coins(_world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	var held: int = mini(
		int(run["coins"]) + int(node["amount"]), Gen1Layout.COIN_CEILING
	)
	run["coins"] = held
	steps.append({"type": &"coins", "amount": held})
	return true


## A routine's own `cp SPRITE_FACING_*`: which side of its cell it answers.
static func _gen1_node_facing(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	return _gen1_resolve_side(world,
		node, Gen1Layout.FACING_STEPS.get(int(node["facing"]), Vector2i.ZERO)
			== world.facing_direction(),
		steps, run
	)


## `wBeatGymFlags`, whose eight bits are Kanto's badges in the engine flags'
## own order.
static func _gen1_node_badge(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	var flag: int = Gen2WorldState.gen1_badge_flag(int(node["badge"]))
	return _gen1_resolve_side(world,
		node, world.state != null and world.state.is_engine_flag_active(flag), steps, run
	)


## `CountSetBits` over `wPokedexOwned`, which only Oak's right poster reads.
static func _gen1_node_dex_count(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	return _gen1_resolve_side(world,
		node, world.state != null and world.state.caught_count() >= int(node["count"]),
		steps, run
	)


## `DisplayDiploma`, a page of its own behind the game designer's last line.
static func _gen1_node_diploma(_world: Gen2WorldAPI, _node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	steps.append({"type": &"request", "values": {
		"kind": &"diploma_requested", "values": {"printing": false},
	}})
	return true


## `LinkCableHelp`'s `.linkHelpLoop`: the menu again after a row's own text or page.
static func _gen1_node_help_menu(_world: Gen2WorldAPI, node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	var step: Dictionary = {
		"type": &"request", "quit": node["quit"],
		"values": {"kind": &"gen1_menu_requested", "values": {
			"box": node["box"], "rows": node["rows"], "grid": node["grid"],
			"text": String(node["prompt"]),
		}},
	}
	for key: String in ["replies", "pokedex"]:
		if node.has(key):
			step[key] = node[key]
	steps.append(step)
	return true


## `DisplayMonFrontSpriteInBox`: the box up under `WaitForTextScrollButtonPress`.
static func _gen1_node_picture(_world: Gen2WorldAPI, node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	var shown: Dictionary = {"type": &"pokemon_picture_requested"}
	if node.has("special"):
		shown["special"] = String(node["special"])
	else:
		shown["pokemon"] = int(node["species"])
	steps.append({"type": &"button", "events": [shown]})
	steps.append({"type": &"event", "event": {"type": &"pokemon_picture_closed"}})
	return true


## `PromptUserToPlaySlots`' YES; the coins the loop leaves come back as the answer.
static func _gen1_node_slot_machine(world: Gen2WorldAPI, node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	steps.append({"type": &"request", "slot_machine": true, "values": {
		"kind": &"slot_machine_requested",
		"values": {
			"generation": RomRegistry.GEN1,
			"coins": world.state.coins() if world.state != null else 0,
			"lucky": world.state != null
				and world.state.gen1_byte(Gen2WorldAPI.GEN1_LUCKY_SLOT) == int(node["lucky_index"]),
		},
	}})
	return true


## `wSurfingMinigameHiScore`.
const GEN1_SURF_HI_SCORE: Array[String] = ["surf_hi_score_low", "surf_hi_score_high"]


static func gen1_surf_hi_score(world: Gen2WorldAPI) -> int:
	if world.state == null:
		return 0
	return world.state.gen1_byte(GEN1_SURF_HI_SCORE[1]) << 8 | world.state.gen1_byte(GEN1_SURF_HI_SCORE[0])


static func set_gen1_surf_hi_score(world: Gen2WorldAPI, score: int) -> void:
	if world.state == null:
		return
	world.state.set_gen1_byte(GEN1_SURF_HI_SCORE[0], score & 0xFF)
	world.state.set_gen1_byte(GEN1_SURF_HI_SCORE[1], (score >> 8) & 0xFF)


## `farcall SurfingPikachuMinigame`; BIT_PIKACHU_MAP_SURF_SELECT lets SELECT quit it.
static func _gen1_node_surfing_minigame(world: Gen2WorldAPI, _node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	steps.append({"type": &"request", "surfing": true, "values": {
		"kind": &"surfing_minigame_requested",
		"values": {
			"hi_score": gen1_surf_hi_score(world),
			"surfing_pikachu": world.pikachu != null and world.pikachu.surfing(),
			"select_quits": world.event_flag_active(
				Gen1Layout.engine_flag_base("pikachu_map_script_flags")
				+ Gen1Layout.PIKACHU_MAP_SURF_SELECT_BIT
			),
		},
	}})
	return true


## A printer page, its arms `hCanceledPrinting`'s; a preview is held for a press.
static func _gen1_node_printer(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	var values: Dictionary = {
		"kind": &"printer_requested",
		"values": {
			"page": String(node["page"]), "preview": bool(node.get("preview", false)),
			"hi_score": gen1_surf_hi_score(world),
			"party_index": int((run.get("party", {}) as Dictionary).get("index", -1)),
		},
	}
	if bool(node.get("preview", false)):
		steps.append({"type": &"request", "values": values})
		return true
	return _gen1_stage_later(node, steps, run, values, &"printed")


## `wDestinationWarpID`: the warp the last `LoadDestinationWarpPosition` landed
## on, counted from zero.
static func _gen1_node_destination_warp(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	return _gen1_resolve_side(world, node, world._gen1_destination_warp == int(node["warp"]), steps, run)


## `VermilionDockSSAnneLeavesScript` on demand, through the ordinary step runner.
static func gen1_ss_anne_leaves(world: Gen2WorldAPI) -> Array:
	world._gen1_steps = []
	_gen1_node_ss_anne_leaves(world, {}, world._gen1_steps, {})
	return Gen1MapScripts._gen1_result(world)


## `VermilionDockSSAnneLeavesScript`: MUSIC_SURFING, the horn behind the lead,
## the drift, `EraseSSAnne`'s five water blocks under the second horn, and
## `dec [wNumberOfWarps]`.
static func _gen1_node_ss_anne_leaves(_world: Gen2WorldAPI, _node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	var horn_at: int = Gen1Layout.SS_ANNE_LEAD_FRAMES
	var drifted: int = horn_at + Gen1Layout.SS_ANNE_COLUMNS * Gen1Layout.SS_ANNE_DRIFTS \
		* Gen1Layout.SS_ANNE_DRIFT_FRAMES + Gen1Layout.SS_ANNE_ERASE_FRAMES
	## `ld [wSpritePlayerStateData1ImageIndex]` of zero turns the player down.
	steps.append({"type": &"player_facing", "facing": Gen2WorldSprite.FACING_DOWN})
	steps.append(Gen1FacilityScripts._gen1_wait_step(&"ss_anne_leaves", drifted + Gen1Layout.SS_ANNE_TAIL_FRAMES, {"sounds": [
			{"frame": 0, "kind": &"music", "index": Gen2WorldFieldMove.MUSIC_SURF},
			{"frame": horn_at, "gen1": true, "index": Gen1Sfx.SFX_SS_ANNE_HORN},
			{"frame": drifted, "gen1": true, "index": Gen1Sfx.SFX_SS_ANNE_HORN},
		]}
	))
	steps.append({
		"type": &"erase_rows", "first_row": Gen1Layout.SS_ANNE_BAND_TOP / PokeTiles.TILE_HEIGHT,
		"rows": (Gen1Layout.SS_ANNE_BAND_BOTTOM - Gen1Layout.SS_ANNE_BAND_TOP) / PokeTiles.TILE_HEIGHT,
		"tile": Gen1Layout.SS_ANNE_WATER_TILE,
	})
	for column: int in Gen1Layout.SS_ANNE_ERASE_BLOCKS:
		steps.append({
			"type": &"block", "x": Gen1Layout.SS_ANNE_ERASE_AT.x + column,
			"y": Gen1Layout.SS_ANNE_ERASE_AT.y, "block": Gen1Layout.SS_ANNE_WATER_BLOCK,
		})
	steps.append({"type": &"drop_last_warp"})
	return true


static func _gen1_node_tileset(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	return _gen1_resolve_side(world,
		node, world.current_map != null and world.current_map.tileset == int(node["tileset"]),
		steps, run
	)


## `lda_coord`: one position of the 20x18 screen, which `BookOrSculptureText`
## reads a row above the shelf's own tile.
static func _gen1_node_screen_tile(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	var screen: int = int(node["screen"])
	@warning_ignore("integer_division")
	var row: int = screen / Gen1Layout.SCREEN_WIDTH_TILES
	return _gen1_resolve_side(world,
		node,
		world._gen1_screen_tile(screen % Gen1Layout.SCREEN_WIDTH_TILES, row)
			== int(node["tile"]),
		steps, run
	)


static func _gen1_node_player_coord(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	var axis: int = int(node["axis"])
	var standing: int = world.player_cell.y if axis == 0 else world.player_cell.x
	var value: int = int(node["value"])
	var holds: bool = standing == value
	match String(node.get("test", "exactly")):
		"below":
			holds = standing < value
		"bit":
			holds = standing & (1 << value) != 0
	return _gen1_resolve_side(world, node, holds, steps, run)


## `ArePlayerCoordsInArray`, whose carry is the player standing on one row of
## the `db y, x` list the caller named.
static func _gen1_node_player_in_array(
	world: Gen2WorldAPI,
	node: Dictionary, steps: Array, run: Dictionary
) -> bool:
	var standing: bool = false
	var cells: Array = node["cells"]
	for index: int in cells.size():
		var cell: Dictionary = cells[index]
		if world.player_cell == Vector2i(int(cell["x"]), int(cell["y"])):
			## `CheckCoords` counts the row up before it compares, so the index
			## a body reads back starts at one.
			run["coord_index"] = index + 1
			standing = true
			break
	return _gen1_resolve_side(world, node, standing, steps, run)


## One object's own byte of `wSpriteStateData1`, which a script writes by hand
## to turn an NPC where `applymovement` would turn one on Generation 2.
static func _gen1_node_object_facing(
	world: Gen2WorldAPI,
	node: Dictionary, steps: Array, run: Dictionary
) -> bool:
	steps.append({
		"type": &"object_facing", "index": _gen1_object_index(node, run),
		"facing": world.facing_for_direction(Gen1Layout.FACING_STEPS[int(node["facing"])]),
	})
	return true


## The store `CallFunctionInTable` dispatches on next frame; a map with no
## dispatch has no byte for `wCurMapScript` to be copied into.
static func _gen1_node_set_map_script(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	var byte: int = int(node["byte"])
	if byte < 0:
		return true
	## `wNextSafariZoneGateScript`: the state the walk before it is to land on.
	var value: int = _gen1_run_saved_index(world, run) if node.has("from") else int(node["value"])
	steps.append({"type": &"map_script", "byte": byte, "value": value})
	return true


## `CallFunctionInTable` itself: the body the map's own byte selects, resolved
## where the entry script reaches the dispatch. An index the importer read no
## body for runs nothing, the way an undecoded row says nothing.
static func _gen1_node_map_script_table(
	world: Gen2WorldAPI,
	node: Dictionary, steps: Array, run: Dictionary
) -> bool:
	if world.state == null or world.current_map == null:
		return false
	return _gen1_resolve_script(world,
		Gen1MapScripts._gen1_map_state_nodes(world, world.state.gen1_map_script(int(node["byte"]))), steps, run
	)


## The two Snorlax and the Pokemon Tower's Marowak, fought once a state returns.
## `wIsInBattle` and `wBattleResult`, read by a post-battle state.
static func _gen1_node_battle_outcome(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	var taken: bool = false
	match String(node["outcome"]):
		Gen1Layout.BATTLE_OUTCOME_LOST:
			taken = world._gen1_battle_outcome == Gen2WorldBattleAdapter.OUTCOME_LOST
		Gen1Layout.BATTLE_OUTCOME_ESCAPED:
			taken = world._gen1_battle_result == 2
		Gen1Layout.BATTLE_OUTCOME_WON:
			taken = world._gen1_battle_result == 0
	return _gen1_resolve_side(world, node, taken, steps, run)


static func _gen1_node_wild_battle(world: Gen2WorldAPI, node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	var site: Dictionary = _gen1_site(world,
		[Gen2WorldCatalog.KIND_STATIC], node,
		{"species": int(node["species"]), "level": int(node["level"])}
	)
	var values: Dictionary = {
		"kind": &"wild", "pokemon": int(site["species"]), "level": int(site["level"]),
	}
	values.merge(Gen1Layout.battle_type_values(int(node.get("battle_type", 0))))
	steps.append({"type": &"request", "values": {"kind": &"battle_requested", "values": values}})
	return true


static func gen1_tutorial_ball_lands(world: Gen2WorldAPI) -> bool:
	if world.data == null or world.state == null:
		return true
	var values: Dictionary = world.pending_runtime_request().get("values", {})
	return Gen1Layout.tutorial_ball_lands(
		world.data.id, int(values.get("gen1_battle_type", 0)), world.state.is_event_flag_active
	)


## `DecodeArrowMovementRLE`: the arrow tile the player stands on queues its own
## legs, and a cell with no row of its own leaves the map's trainers alone.
static func _gen1_node_arrow_movement(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	for cell: Dictionary in node["cells"] as Array:
		if world.player_cell != Vector2i(int(cell["x"]), int(cell["y"])):
			continue
		steps.append({
			"type": &"walk", "moves": (cell["moves"] as Array).duplicate(true), "spinner": true,
		})
		return _gen1_resolve_side(world, node, true, steps, run)
	return _gen1_resolve_side(world, node, false, steps, run)


static func _gen1_node_object_coord_move(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	var object: int = _gen1_object_index(node, run)
	var rows: Array = node["rows"]
	for index: int in range(object * Gen1Layout.OBJECT_COORD_ROWS,
		mini(rows.size(), (object + 1) * Gen1Layout.OBJECT_COORD_ROWS)):
		var row: Dictionary = rows[index]
		if world.player_cell != Vector2i(int(row["x"]), int(row["y"])):
			continue
		steps.append({"type": &"object_move", "index": object, "moves": (row["moves"] as Array).duplicate()})
		return true
	return true


static func _gen1_node_walk(_world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	var moves: Array = (node["moves"] as Array).duplicate(true)
	if node.has("steps_offset"):
		var count: int = int(run.get("coord_index", 0)) + int(node["steps_offset"])
		if count < 1:
			return true
		(moves[0] as Dictionary)["steps"] = count
	steps.append({"type": &"walk", "moves": moves})
	return true


## `MoveSprite` returns as soon as it has copied the list, so its steps are
## drawn behind the script rather than in front of it.
static func _gen1_node_object_move(_world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	steps.append({
		"type": &"object_move", "index": _gen1_object_index(node, run),
		"moves": _gen1_filled_moves(node["fill"], run) if node.has("fill") \
			else (node["moves"] as Array).duplicate(),
	})
	return true


## `FillMemory` over `wNPCMovementDirections2`: one direction, `c` times.
static func _gen1_filled_moves(fill: Dictionary, run: Dictionary) -> Array:
	var count: int = _gen1_scratch_read(run, int(fill["from"]), int(fill["offset"])) \
		if fill.has("from") else int(fill["count"])
	var moves: Array = []
	moves.resize(mini(count, Gen1Layout.NPC_MOVEMENT_MAX))
	moves.fill(int(fill["direction"]))
	return moves


static func _gen1_node_object_stay(_world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	steps.append({"type": &"object_stay", "index": _gen1_object_index(node, run)})
	return true


## The bits a state reads to hold still while the walk before it is drawn.
static func _gen1_node_movement_running(
	world: Gen2WorldAPI,
	node: Dictionary, steps: Array, run: Dictionary
) -> bool:
	if node.has("remaining"):
		var remaining: int = world.gen1_object_steps_remaining() \
			if String(node["who"]) == Gen1Layout.MOVEMENT_TEST_OBJECT \
			else world.gen1_player_steps_remaining()
		return _gen1_resolve_side(world, node, remaining == int(node["remaining"]), steps, run)
	var running: bool = world.gen1_object_movement_running() \
		if String(node["who"]) == Gen1Layout.MOVEMENT_TEST_OBJECT \
		else world.gen1_player_movement_running()
	return _gen1_resolve_side(world, node, running, steps, run)


## `wCoordIndex`, the row `ArePlayerCoordsInArray` matched on, counted from 1.
static func _gen1_node_coord_index(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	return _gen1_resolve_side(world,
		node, _gen1_index_matches(node, int(run.get("coord_index", 0))), steps, run
	)


## `wSavedCoordIndex`, which outlives the state that wrote it.
static func _gen1_node_saved_coord_index(
	world: Gen2WorldAPI,
	node: Dictionary, steps: Array, run: Dictionary
) -> bool:
	return _gen1_resolve_side(world,
		node, _gen1_index_matches(node, _gen1_run_saved_index(world, run)), steps, run
	)


static func _gen1_index_matches(node: Dictionary, index: int) -> bool:
	var value: int = int(node["index"])
	return index < value if String(node["test"]) == "below" else index == value


## The store, whose -1 is `wCoordIndex` itself. The run keeps the copy the rest
## of the row reads and the world takes it when spent: both sides of the gate's
## "Leaving early?" resolve before the answer, and NO's 5 had overwritten YES's 0.
static func _gen1_node_save_coord_index(
	_world: Gen2WorldAPI,
	node: Dictionary, steps: Array, run: Dictionary
) -> bool:
	var value: int = int(node["value"])
	run["saved_coord_index"] = int(run.get("coord_index", 0)) if value < 0 else value
	steps.append({"type": &"saved_coord_index", "value": int(run["saved_coord_index"])})
	return true


static func _gen1_run_saved_index(world: Gen2WorldAPI, run: Dictionary) -> int:
	return int(run.get("saved_coord_index", world._gen1_saved_coord_index))


static func _gen1_node_player_facing(world: Gen2WorldAPI, node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	steps.append({
		"type": &"player_facing",
		"facing": world.facing_for_direction(Gen1Layout.FACING_STEPS[int(node["facing"])]),
	})
	return true


## `farcall DisplayTownMap`, which the bookshelf poster and the TOWN MAP item
## both reach. The screen is the whole of the step: it takes B and leaves.
static func _gen1_node_town_map(world: Gen2WorldAPI, _node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	steps.append({"type": &"request", "values": {
		"kind": &"town_map_requested", "values": {"landmark": world.landmark_backup()},
	}})
	return true


## `<Map>ElevatorStoreWarpEntriesScript`, run by the map an `elevator` row is on.
static func _gen1_seed_warp_entry(world: Gen2WorldAPI, target_map: Gen2WorldMap) -> void:
	world._gen1_warp_entry = world._gen1_warped_from.duplicate() \
		if _gen1_map_elevator(target_map) else {}


static func _gen1_map_elevator(target_map: Gen2WorldMap) -> bool:
	for row: Dictionary in target_map.texts:
		for node: Dictionary in (row.get("script", []) as Array):
			if String(node.get("op", "")) == "elevator":
				return true
	return false


static func _gen1_warp_entry_over(world: Gen2WorldAPI, cell: Vector2i, source_warp: Dictionary) -> Dictionary:
	if not world._gen1 or world._gen1_warp_entry.is_empty() or world.warp_index_at(cell) != 1:
		return source_warp
	var written: Dictionary = source_warp.duplicate(true)
	written["destination"] = int(world._gen1_warp_entry["warp"])
	written["map_group"] = 0
	written["map_number"] = int(world._gen1_warp_entry["map"])
	return written


## `DisplayElevatorFloorMenu`, whose `WhichFloorText` ends on `text_end`.
static func _gen1_node_elevator(_world: Gen2WorldAPI, node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	var floors: Array = node.get("floors", [])
	if floors.is_empty():
		return false
	steps.append({"type": &"request", "elevator": true, "values": {
		"kind": &"elevator_requested",
		"values": {
			"generation": RomRegistry.GEN1, "floors": floors.duplicate(true),
		},
	}})
	return true


## `GetItemName` into `wStringBuffer`, which names a hidden item's receipt
## before the bag has been asked whether it can take one.
static func _gen1_node_name_item(world: Gen2WorldAPI, node: Dictionary, _steps: Array, run: Dictionary) -> bool:
	var item: int = _gen1_fossil_byte(world, run, "item") \
		if String(node.get("from", "")) == "fossil_item" \
		else _gen1_item_of(world, int(node["item"]), run)
	_gen1_named(node, run, world.data.item_name(item) if world.data != null else "")
	return true


static func _gen1_item_of(world: Gen2WorldAPI, item: int, run: Dictionary) -> int:
	if item == Gen1Layout.SCRIPT_FOSSIL_ITEM_SOURCE:
		return _gen1_fossil_byte(world, run, "item")
	if item != Gen1Layout.SCRIPT_MENU_ITEM_SOURCE:
		return item
	return int((run.get("menu", {}) as Dictionary).get("item", -1))


static func _gen1_node_safari_balls(world: Gen2WorldAPI, node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	steps.append({"type": &"safari_balls", "count": int(node.get(
		"count", world._gen1_safari_admitted.get("balls", 0)
	))})
	return true


static func _gen1_node_safari_steps(_world: Gen2WorldAPI, node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	steps.append({"type": &"safari_steps", "steps": int(node["steps"])})
	return true


## Yellow's two admission routines for a purse that cannot pay ¥500, both of
## which answer carry when nothing was won, which is the branch's `else`.
static func _gen1_node_safari_admission(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	world._gen1_safari_admitted = {}
	if String(node["kind"]) == "low_cost":
		_gen1_safari_low_cost(world, steps, run)
	else:
		_gen1_safari_nag(world, steps)
	return _gen1_resolve_side(world, node, not world._gen1_safari_admitted.is_empty(), steps, run)


static func _gen1_safari_low_cost(world: Gen2WorldAPI, steps: Array, run: Dictionary) -> void:
	## `DivideBCDPredef3` divides the balance by the byte `ld a, 23` wrote, which
	## packed decimal reads as seventeen; `SafariZoneEntranceConvertBCDtoNumber`
	## then takes the quotient's last byte, so only its last two digits count.
	@warning_ignore("integer_division")
	var quotient: int = int(run["money"]) / Gen1Layout.SAFARI_LOW_COST_DIVISOR
	var balls: int = quotient % Gen1Layout.SAFARI_LOW_COST_DIGITS + 1
	## `FillMemory` empties the purse before either line is printed.
	run["money"] = 0
	steps.append({"type": &"money", "amount": 0})
	steps.append(Gen1MapScripts._gen1_safari_box(world, "low_cost_1"))
	steps.append({"type": &"money_box", "kind": &"money_top_right"})
	steps.append(Gen1MapScripts._gen1_safari_box(world, "low_cost_2"))
	world._gen1_safari_admitted = {
		"balls": mini(balls, Gen1Layout.SAFARI_LOW_COST_MAX_BALLS),
		"steps": Gen1Layout.SAFARI_STEPS,
	}


static func _gen1_safari_nag(world: Gen2WorldAPI, steps: Array) -> void:
	var visit: int = world.state.safari_steps() >> 8
	steps.append(Gen1MapScripts._gen1_safari_box(world, "nag_%d" % mini(
		visit, Gen1Layout.SAFARI_NAG_LINES - 1
	)))
	world.state.set_safari_steps(world.state.safari_steps() + (1 << 8))
	if visit != Gen1Layout.SAFARI_NAG_GIFT_VISIT:
		return
	steps.append(Gen1MapScripts._gen1_safari_box(world, "one_ball"))
	world._gen1_safari_admitted = {
		"balls": Gen1Layout.SAFARI_NAG_BALLS, "steps": Gen1Layout.SAFARI_STEPS,
	}


static func _gen1_node_set_last_map(_world: Gen2WorldAPI, node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	steps.append({"type": &"last_map", "map": int(node["map"])})
	return true


static func _gen1_node_set_blackout_map(_world: Gen2WorldAPI, node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	steps.append({"type": &"blackout_map", "map": int(node["map"])})
	return true


static func _gen1_node_set_player_coord(_world: Gen2WorldAPI, node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	steps.append({"type": &"player_coord", "axis": int(node["axis"]), "value": int(node["value"])})
	return true


static func _gen1_node_set_starter(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	var value: int = _gen1_scratch_read(run, int(node["scratch"]), 0) if node.has("scratch") \
		else int(node["value"])
	if String(node["who"]) == "player" and world.data != null:
		var linked: Dictionary = _gen1_linked_site(world,
			Gen2WorldCatalog.KIND_STARTER, "starter_address", node,
			{"species": world.data.gen1_dex_of_index(value)}
		)
		if linked.has("species"):
			value = int(world.data.species(int(linked["species"])).get("index", value))
	steps.append({"type": &"starter", "who": String(node["who"]), "value": value})
	return true


static func _gen1_node_name_species(world: Gen2WorldAPI, node: Dictionary, _steps: Array, run: Dictionary) -> bool:
	var species: int = int(node.get("species", 0))
	if String(node.get("from", "")) == "player_starter" and world.state != null and world.data != null:
		species = world.data.gen1_dex_of_index(world.state.gen1_starter("player"))
	elif String(node.get("from", "")) == "fossil_mon":
		species = _gen1_fossil_species(world, run)
	elif node.has("scratch") and world.data != null:
		species = world.data.gen1_dex_of_index(_gen1_scratch_read(run, int(node["scratch"]), 0))
	_gen1_named(node, run, String(world.data.species(species).get("name", "")) \
		if world.data != null and species > 0 else "")
	return true


## Both name routines answer in `wNameBuffer`, and `CopyToStringBuffer` moves the
## first out. A node naming its buffer fills that marker alone.
static func _gen1_named(node: Dictionary, run: Dictionary, name: String) -> void:
	run["named"] = name
	if not node.has("buffer"):
		return
	var buffers: Dictionary = run.get("buffers", {})
	buffers[int(node["buffer"])] = name
	run["buffers"] = buffers


## `DisplayPartyMenu` and `DisplayNameRaterScreen`: what either answers decides
## the boxes behind it, so both sides ride the request unresolved.
static func _gen1_node_party_menu(_world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	return _gen1_stage_later(node, steps, run, {
		"kind": &"party_selection_requested", "values": {"routine": &"name_rater"},
	}, &"party_index")


static func _gen1_node_name_mon(_world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	var chosen: Dictionary = run.get("party", {})
	if chosen.is_empty():
		return false
	return _gen1_stage_later(node, steps, run, {
		"kind": &"gen1_nickname_requested", "values": {
			"party_index": int(chosen.get("index", -1)),
			"buffer": int(node.get("buffer", -1)),
		},
	}, &"name")


static func _gen1_stage_later(node: Dictionary, steps: Array, run: Dictionary, values: Dictionary, answer: StringName
) -> bool:
	steps.append({
		"type": &"request", "values": values, "answer": answer,
		"later": {"then": node["then"], "else": node["else"]},
		"run": Gen1FacilityScripts._gen1_run_copy(run),
	})
	return true


## `GetPartyMonName2` into `wNameBuffer`: the nickname the list came back with.
static func _gen1_node_name_party_mon(_world: Gen2WorldAPI, node: Dictionary, _steps: Array, run: Dictionary) -> bool:
	_gen1_named(node, run, String((run.get("party", {}) as Dictionary).get("nickname", "")))
	return true


## `NameRatersHouseCheckMonOTScript`: carry when either half of the OT differs.
static func _gen1_node_mon_ot(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	var chosen: Dictionary = run.get("party", {})
	return _gen1_resolve_side(world, node, not Gen2NameRater.matches_ot(
		String(chosen.get("original_trainer", "")), int(chosen.get("ot_id", -1)),
		world._player_name, world._player_id
	), steps, run)


static func _gen1_node_copy_name(_world: Gen2WorldAPI, node: Dictionary, _steps: Array, run: Dictionary) -> bool:
	var buffers: Dictionary = run.get("buffers", {})
	buffers[int(node["to"])] = String(buffers.get(int(node["from"]), ""))
	run["buffers"] = buffers
	return true


static func _gen1_node_set_fossil(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	var which: String = String(node["which"])
	var value: int = _gen1_item_of(world,
		Gen1Layout.SCRIPT_MENU_ITEM_SOURCE if node.has("from") else int(node["value"]), run
	)
	## Read again inside the same row, so the walk carries them like the bag.
	var fossil: Dictionary = run.get("fossil", {})
	fossil[which] = value
	run["fossil"] = fossil
	steps.append({"type": &"fossil", "which": which, "value": value})
	return true


static func _gen1_fossil_byte(world: Gen2WorldAPI, run: Dictionary, which: String) -> int:
	var walked: Dictionary = run.get("fossil", {})
	return int(walked[which]) if walked.has(which) else int(world.gen1_fossil.get(which, 0))


static func _gen1_fossil_species(world: Gen2WorldAPI, run: Dictionary) -> int:
	var stored: int = _gen1_fossil_byte(world, run, "mon")
	return world.data.gen1_dex_of_index(stored) if world.data != null and stored > 0 else 0


static func _gen1_node_name_badge(_world: Gen2WorldAPI, node: Dictionary, _steps: Array, run: Dictionary) -> bool:
	run["named"] = String(node["name"])
	return true


static func _gen1_node_scratch(_world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	var value: int = int(node["value"]) if node.has("value") \
		else _gen1_scratch_read(run, int(node["from"]), int(node["offset"]))
	(run["scratch"] as Dictionary)[int(node["address"])] = value
	steps.append({"type": &"scratch", "address": int(node["address"]), "value": value})
	return true


static func _gen1_scratch_read(run: Dictionary, address: int, offset: int) -> int:
	return (int((run["scratch"] as Dictionary).get(address, 0)) + offset) & 0xFF


static func _gen1_object_index(node: Dictionary, run: Dictionary) -> int:
	if node.has("object"):
		return int(node["object"])
	return _gen1_scratch_read(run, int(node["object_from"]), int(node["object_offset"]))


static func _gen1_node_scratch_test(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	return _gen1_resolve_side(world,
		node, int((run["scratch"] as Dictionary).get(int(node["address"]), 0)) == int(node["value"]), steps, run
	)


## `Random`'s byte stays in `a` on both sides, so a store behind the branch
## reads the same roll rather than a second one.
static func _gen1_node_random(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	var roll: int = _gen1_roll(world)
	run["roll"] = roll
	return _gen1_resolve_side(world, node, roll < int(node["below"]), steps, run)


static func _gen1_node_random_bit(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	return _gen1_resolve_side(world, node, _gen1_roll(world) & (1 << int(node["bit"])) != 0, steps, run)


static func _gen1_node_talking_to(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	return _gen1_resolve_side(world, node, world._gen1_last_sprite_index == int(node["object"]), steps, run)


## Red and Blue have no follower, so every fact about it reads false there.
static func _gen1_node_pikachu_test(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	var taken: bool = false
	if world.pikachu != null:
		match String(node["what"]):
			"starter":
				taken = world.pikachu.starter_alive()
			"surfing":
				taken = world.pikachu.surfing()
			"following":
				taken = world.pikachu.following()
			"ailing":
				taken = world.pikachu.ailing
			"happiness":
				taken = world.pikachu.happiness < int(node["below"])
	return _gen1_resolve_side(world, node, taken, steps, run)


static func _gen1_node_pikachu(_world: Gen2WorldAPI, node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	steps.append({"type": &"pikachu", "what": String(node["what"]),
		"value": node.get("value", 0)})
	return true


## `ApplyPikachuMovementData` holds the script until its last command, and
## `TryApplyPikachuMovementData` runs it only for a walking follower already
## facing the way the row names.
static func _gen1_node_pikachu_movement(world: Gen2WorldAPI, node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	if node.has("facing") and (world.pikachu == null or not world.pikachu.starter_alive()
		or world.movement_mode != Gen2WorldAPI.MOVEMENT_WALK
		or world.pikachu.facing_toward_player(world.player_cell) != int(node["facing"])):
		return true
	steps.append({"type": &"pikachu_movement", "bytes": PackedByteArray(node["bytes"]),
		"refresh": bool(node.get("refresh", false))})
	steps.append({"type": &"wait", "values": {
		"type": &"wait", "wait": Gen2WorldScriptRunner.WAIT_MOVEMENT,
	}})
	return true


## `PewterPokecenterJigglypuffText`'s song, which the host plays and spins
## `wSprite03` through until the driver's channels fall silent.
static func _gen1_node_jigglypuff(_world: Gen2WorldAPI, node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	steps.append(Gen1FacilityScripts._gen1_wait_step(&"jigglypuff", Gen2WorldAPI.WAIT_UNTIL_FINISHED,
		{"object": int(node["object"])}))
	return true


## `wSprite03StateData1ImageIndex` written by hand: the standing frame of the
## next facing of `.FacingDirections`' ring.
static func gen1_turn_object(world: Gen2WorldAPI, index: int, facing: int) -> void:
	Gen1MapScripts._turn_gen1_object(world, index, facing, [])


static func _gen1_node_pikachu_talk(world: Gen2WorldAPI, _node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	steps.append_array(_gen1_pikachu_talk_steps(world))
	return true


## `TalkToPikachu`: `MapSpecificPikachuExpression`'s named cases first, the
## mood and happiness tables last.
static func _gen1_pikachu_emotion(world: Gen2WorldAPI) -> int:
	var map: int = world.current_map.number if world.current_map != null else -1
	if map == Gen1Layout.POKEMON_FAN_CLUB:
		if not world._gen1_pikachu_script_active():
			return Gen1Layout.PIKACHU_EMOTION_FAN_CLUB_SEEL
		if not world.pikachu.following():
			return Gen1Layout.PIKACHU_EMOTION_FAN_CLUB_LEFT
	elif map == Gen1Layout.PEWTER_POKECENTER and not world.pikachu.following():
		return Gen1Layout.PIKACHU_EMOTION_PEWTER_ASLEEP
	elif map == Gen1Layout.BILLS_HOUSE and not world.pikachu.following():
		return _gen1_bills_house_emotion(world)
	if world.pikachu.asleep:
		return Gen1Layout.PIKACHU_EMOTION_ASLEEP
	if world.pikachu.ailing:
		return Gen1Layout.PIKACHU_EMOTION_AILING
	if map >= Gen1Layout.POKEMON_TOWER_1F and map <= Gen1Layout.POKEMON_TOWER_7F:
		return Gen1Layout.PIKACHU_EMOTION_TOWER
	if world.pikachu.emotion_modifier > 0:
		return Gen1Layout.PIKACHU_MODIFIER_EMOTIONS[world.pikachu.emotion_modifier - 1]
	return world.pikachu.mood_emotion(world.data.gen1_pikachu())


## `BillsHouse_CheckPikachuEmotion`, off `wBillsHouseCurScript`.
static func _gen1_bills_house_emotion(world: Gen2WorldAPI) -> int:
	var layout: Dictionary = Gen1Layout.for_id(world.data.id)
	var script: int = world.state.gen1_map_script(
		int(layout["bills_house_script"]) - int(layout["map_scripts"])
	) if world.state != null else 0
	if script == Gen1Layout.BILLS_HOUSE_SCRIPT_HEALED:
		return Gen1Layout.PIKACHU_EMOTION_BILL_HEALED
	if script == Gen1Layout.BILLS_HOUSE_SCRIPT_ARRIVED:
		return Gen1Layout.PIKACHU_EMOTION_BILL_ARRIVED
	if not world.event_flag_active(Gen1Layout.MET_BILL_2_EVENT):
		return Gen1Layout.PIKACHU_EMOTION_BILL_UNMET
	return Gen1Layout.PIKACHU_EMOTION_BILL_MET


## `DoStarterPikachuEmotions`: one emotion's commands as steps. A bubble and a
## redraw are counted waits, a movement waits on the follower, and the clip and
## the portrait go out as events for whoever draws them.
static func _gen1_pikachu_talk_steps(world: Gen2WorldAPI, emotion: int = -1) -> Array:
	var steps: Array = []
	if world.pikachu == null or world.data == null:
		return steps
	var emotions: Array = world.data.gen1_pikachu().get("emotions", [])
	var index: int = _gen1_pikachu_emotion(world) if emotion < 0 else emotion
	if index < 0 or index >= emotions.size():
		return steps
	if emotion < 0:
		steps.append(Gen1FacilityScripts._gen1_wait_step(&"text_init", Gen1Layout.TEXT_INIT_FRAMES))
	for row: Dictionary in emotions[index]:
		match String(row["cmd"]):
			"text":
				steps.append({"type": &"text", "text": String(row["text"])})
			"emote":
				steps.append({"type": &"pikachu", "what": "emote", "value": int(row["value"])})
				steps.append(Gen1FacilityScripts._gen1_wait_step(&"emote", Gen1Layout.EMOTE_FRAMES))
			"movement":
				_gen1_node_pikachu_movement(world, {"bytes": row["bytes"]}, steps, {})
			"delay":
				steps.append(Gen1FacilityScripts._gen1_wait_step(&"pikachu_delay", int(row["value"])))
			"subcmd":
				steps.append_array(_gen1_pikachu_subcommand_steps(world, int(row["value"])))
			"pikapic":
				steps.append(Gen1FacilityScripts._gen1_wait_step(&"pikapic", Gen2WorldAPI.WAIT_UNTIL_FINISHED,
					{"index": int(row["value"])}))
			"pcm":
				steps.append(_gen1_sound_step(world, "pikachu_clip", {"index": int(row["value"])}))
			_:
				steps.append({"type": &"pikachu", "what": String(row["cmd"]),
					"value": int(row.get("value", 0))})
	return steps


## `PlayPikachuSoundClip`: three `DelayFrame`s, then the clip's one-bit samples
## with interrupts off, at the rate measured on the cartridge.
static func _gen1_pikachu_cry_frames(world: Gen2WorldAPI, index: int) -> int:
	var cries: Array = world.data.gen1_pikachu().get("cries", []) if world.data != null else []
	if index < 0 or index >= cries.size():
		return 0
	return Gen1Layout.pikachu_cry_frames(int(cries[index]))


## A row's `PlaySound`, `PlayCry`, `WaitForSoundToFinish` or Yellow's
## `PlayPikachuSoundClip`: a schedule the screen sounds, and the hold behind it.
static func _gen1_node_sound(world: Gen2WorldAPI, node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	steps.append(_gen1_sound_step(world, String(node["what"]), node))
	return true


static func _gen1_sound_step(world: Gen2WorldAPI, what: String, node: Dictionary = {}) -> Dictionary:
	var index: int = int(node.get("index", 0))
	match what:
		"cry":
			return _gen1_sound_wait([{"frame": 0, "cry": index}])
		"wait":
			return _gen1_sound_wait([], bool(node.get("music", false)))
		"channel":
			var held: Dictionary = _gen1_sound_wait([], true)
			(held["values"] as Dictionary).merge({
				"channel": int(node["channel"]), "sound": index,
			})
			return held
		"map_music":
			## `PlayDefaultMusic` waits for the effect channels first.
			if bool(node.get("wait", false)):
				return _gen1_sound_wait([{"wait": true, "map_music": true}])
			return _gen1_sound_event([{"frame": 0, "map_music": true}])
		"pikachu_clip":
			return Gen1FacilityScripts._gen1_wait_step(&"gen1_sound", _gen1_pikachu_cry_frames(world, index), {
				"sounds": [{"frame": 0, "pikachu_clip": index}],
			})
		"alternate_music":
			return _gen1_alternate_music_step(world, String(node.get("name", "")))
		"music":
			return _gen1_sound_event([{
				"frame": 0, "gen1": true, "kind": &"music", "index": index,
				"bank": int(node.get("bank", -1)),
			}])
	return _gen1_sound_event([
		{"frame": 0, "gen1": true, "index": index, "wait": bool(node.get("wait", false))},
	])


## `Music_Cities1AlternateTempo` fades the room's piece out and spends
## `DelayFrames` in front of its `PlayMusic`; the rival's three start at once.
static func _gen1_alternate_music_step(world: Gen2WorldAPI, name: String) -> Dictionary:
	var record: Dictionary = world.data.gen1_alternate_music(name) if world.data != null else {}
	var delay: int = int(record.get("delay_frames", 0))
	var sounds: Array = [{"frame": delay, "alternate_music": name}]
	if int(record.get("fade_frames", 0)) > 0:
		sounds.push_front({"frame": 0, "fade": int(record["fade_frames"])})
	if delay > 0:
		return Gen1FacilityScripts._gen1_wait_step(&"gen1_sound", delay, {"sounds": sounds})
	return _gen1_sound_event(sounds)


## A `WaitForSoundToFinish` behind whatever [param sounds] start.
static func _gen1_sound_wait(sounds: Array, music: bool = false) -> Dictionary:
	var step: Dictionary = Gen1FacilityScripts._gen1_wait_step(&"gen1_sound", 0, {"sounds": sounds})
	(step["values"] as Dictionary)["until_sound"] = true
	(step["values"] as Dictionary)["music"] = music
	return step


static func _gen1_sound_event(sounds: Array) -> Dictionary:
	return {"type": &"event", "event": {
		"type": &"presentation_special_applied", "kind": &"gen1_sound", "sounds": sounds,
	}}


## `.Subcommands`: the redraw spends `Delay3`, and the three map checks put the
## follower back behind the player.
static func _gen1_pikachu_subcommand_steps(world: Gen2WorldAPI, which: int) -> Array:
	if which == Gen1Layout.PIKACHU_SUBCMD_REDRAW:
		return [Gen1FacilityScripts._gen1_wait_step(&"pikachu_delay", Gen1Layout.PIKACHU_REDRAW_FRAMES)]
	var maps: Dictionary = {
		Gen1Layout.PIKACHU_SUBCMD_PEWTER: Gen1Layout.PEWTER_POKECENTER,
		Gen1Layout.PIKACHU_SUBCMD_FAN_CLUB: Gen1Layout.POKEMON_FAN_CLUB,
		Gen1Layout.PIKACHU_SUBCMD_BILLS: Gen1Layout.BILLS_HOUSE,
	}
	if not maps.has(which) or world.current_map == null or world.current_map.number != int(maps[which]):
		return []
	var steps: Array = [{"type": &"pikachu", "what": "following", "value": true}]
	if which != Gen1Layout.PIKACHU_SUBCMD_BILLS:
		steps.append({"type": &"pikachu", "what": "turn_away", "value": 0})
	return steps


## `Func_f1ea2`: the first row the happiness is below, the last row otherwise.
static func _gen1_node_pikachu_text(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	var happiness: int = world.pikachu.happiness if world.pikachu != null else 0
	var texts: Array = node["texts"]
	var chosen: Dictionary = texts[-1]
	for row: Dictionary in texts:
		if int(row["below"]) > 0 and happiness < int(row["below"]):
			chosen = row
			break
	return _gen1_node_text(world, {"op": "text", "text": String(chosen["text"])}, steps, run)


static func _gen1_node_oaks_aide(world: Gen2WorldAPI, raw: Dictionary, steps: Array, run: Dictionary) -> bool:
	var node: Dictionary = raw.duplicate()
	node["item"] = int(_gen1_site(world,
		[Gen2WorldCatalog.KIND_ITEM], raw, {"item": int(raw["item"]), "quantity": 1}
	)["item"])
	var other: Array = [_gen1_aide_box(world, "come_back", node)]
	if not _gen1_resolve_script(world, node["other"] as Array, other, Gen1FacilityScripts._gen1_run_copy(run)):
		return false
	var yes: Array = []
	if world.state != null and world.state.caught_count() >= int(node["requirement"]):
		## `OaksAideScript`: HereYouGo, `GiveItem`, then GotItem or NoRoom.
		yes.append(_gen1_aide_box(world, "here_you_go", node))
		var gift_run: Dictionary = Gen1FacilityScripts._gen1_run_copy(run)
		var before: int = yes.size()
		if not _gen1_resolve_gift(world,
			{"op": "give_item", "item": int(node["item"]), "count": 1}, yes, gift_run
		):
			return false
		var taken: bool = yes.size() > before
		yes.append(_gen1_aide_box(world, "got_item" if taken else "no_room", node))
		if not _gen1_resolve_script(world, node["got" if taken else "other"] as Array, yes, gift_run):
			return false
	else:
		yes.append(_gen1_aide_box(world, "uh_oh", node))
		if not _gen1_resolve_script(world, node["other"] as Array, yes, Gen1FacilityScripts._gen1_run_copy(run)):
			return false
	steps.append({
		"type": &"choice", "text": String(_gen1_aide_box(world, "hi", node)["text"]), "yes": yes, "no": other,
	})
	return true


## `hOaksAideRequirement` and `hOaksAideNumMonsOwned`, three-digit fields.
const GEN1_AIDE_REQUIREMENT: int = 0xFFDB
const GEN1_AIDE_OWNED: int = 0xFFDD


static func _gen1_aide_box(world: Gen2WorldAPI, name: String, node: Dictionary) -> Dictionary:
	var text: String = gen1_filled_text(world,
		world.data.special_text(GEN1_OAKS_AIDE_RUN, name) if world.data != null else ""
	)
	var numbers: Dictionary = {
		GEN1_AIDE_REQUIREMENT: int(node["requirement"]),
		GEN1_AIDE_OWNED: world.state.caught_count() if world.state != null else 0,
	}
	for address: int in numbers:
		text = Gen2TextStream.fill_all_markers(
			text, "%s%04X>" % [Gen2TextStream.NUMBER_MARKER, address],
			str(numbers[address]).lpad(3)
		)
	return {"type": &"text", "text": Gen2TextStream.fill_all_markers(
		text, Gen2TextStream.RAM_MARKER, world.data.item_name(int(node["item"])) if world.data != null else ""
	)}


const GEN1_OAKS_AIDE_RUN: StringName = &"oaks_aide"

## A `give_pokemon` is one of three kinds; the site is tried under each.
const GEN1_GIVING_KINDS: Array[StringName] = [
	Gen2WorldCatalog.KIND_STARTER, Gen2WorldCatalog.KIND_PRIZE, Gen2WorldCatalog.KIND_GIFT,
]


## A site node's numbers with any mod patch folded in, the way
## [method Gen2WorldScriptRunner._catalogued] substitutes a command's operands.
static func _gen1_site(world: Gen2WorldAPI, kinds: Array, node: Dictionary, fields: Dictionary) -> Dictionary:
	if world.data == null or not world.data.has_content_overlay() or not node.has("at"):
		return fields
	for kind: StringName in kinds:
		var row: Dictionary = world.data.catalog().gen1_site(kind, int(node["at"]), fields)
		if not row.is_empty():
			return row
	return fields


## The same for a table row of this map: an object, a hidden item, a clerk, a prize.
static func _gen1_event_site(world: Gen2WorldAPI, kind: StringName, source: int, index: int, fields: Dictionary) -> Dictionary:
	if world.data == null or world.current_map == null or index < 0 or not world.data.has_content_overlay():
		return fields
	var row: Dictionary = world.data.catalog().check(Gen2WorldCatalog.pack_event_id(
		kind, source, world.current_map.number, index
	))
	return row if not row.is_empty() else fields


## A node carrying one of a site's numbers: the `wPlayerStarter` store beside
## Oak's give, the money test and spend around the salesman's. See `LINK_ROLES`.
static func _gen1_linked_site(world: Gen2WorldAPI, kind: StringName, key: String, node: Dictionary, fields: Dictionary) -> Dictionary:
	if world.data == null or not world.data.has_content_overlay() or not node.has("at"):
		return fields
	var row: Dictionary = world.data.catalog().gen1_linked(kind, key, int(node["at"]), fields)
	return row if not row.is_empty() else fields


static func _gen1_node_starter(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	var held: int = world.state.gen1_starter(String(node["who"])) if world.state != null else 0
	return _gen1_resolve_side(world, node, held == int(node["value"]), steps, run)


static func _gen1_node_riding(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	return _gen1_resolve_side(world, node, world.movement_mode != Gen2WorldAPI.MOVEMENT_WALK, steps, run)


## `wWalkBikeSurfState`'s three values, in `LoadPlayerSpriteGraphics`' order.
const GEN1_RIDING_MODES: Array[StringName] = [Gen2WorldAPI.MOVEMENT_WALK, Gen2WorldAPI.MOVEMENT_BIKE, Gen2WorldAPI.MOVEMENT_SURF]


static func _gen1_node_set_riding(_world: Gen2WorldAPI, node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	var mode: int = int(node["mode"])
	if mode < 0 or mode >= GEN1_RIDING_MODES.size():
		return false
	steps.append({"type": &"riding", "mode": GEN1_RIDING_MODES[mode]})
	return true


static func _gen1_node_movement_script_running(
	world: Gen2WorldAPI,
	node: Dictionary, steps: Array, run: Dictionary
) -> bool:
	return _gen1_resolve_side(world, node, not world._gen1_movement_script.is_empty(), steps, run)


static func _gen1_node_npc_movement_script(_world: Gen2WorldAPI, node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	steps.append({
		"type": &"npc_movement_script", "table": int(node["table"]),
		"object": int(node["object"]),
	})
	return true


static func _gen1_node_store_byte(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	var value: int = int(node.get("value", 0))
	if bool(node.get("random", false)):
		var roll: int = int(run["roll"]) if bool(node.get("rolled", false)) and run.has("roll") \
			else _gen1_roll(world)
		value = (roll & int(node["mask"])) >> int(node["shift"])
	steps.append({"type": &"byte", "name": String(node["name"]), "value": value})
	return true


## `GymTrashScript`, whose second lock sets `VermilionGymSetDoorTile`'s bit.
static func _gen1_node_gym_trash(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	var can: int = int(node["can"])
	var side: String = "trash"
	if world.state != null and not _gen1_run_flag(world, Gen1Layout.LOCK_2ND_EVENT, run):
		if not _gen1_run_flag(world, Gen1Layout.LOCK_1ST_EVENT, run):
			if can == world.state.gen1_byte(Gen2WorldAPI.GEN1_FIRST_LOCK):
				_gen1_node_flag(world, {"flag": Gen1Layout.LOCK_1ST_EVENT, "set": true}, steps, run)
				_gen1_draw_second_can(world, node, steps)
				side = "first_lock"
		elif can in [world.state.gen1_byte(Gen2WorldAPI.GEN1_SECOND_LOCK), world.state.gen1_byte(Gen2WorldAPI.GEN1_SECOND_LOCK_ALT)]:
			_gen1_node_flag(world, {"flag": Gen1Layout.LOCK_2ND_EVENT, "set": true}, steps, run)
			steps.append({"type": &"map_load", "bit": Gen1Layout.MAP_LOADED_2_BIT})
			side = "second_lock"
		else:
			_gen1_node_flag(world, {"flag": Gen1Layout.LOCK_1ST_EVENT, "set": false}, steps, run)
			steps.append({"type": &"byte", "name": Gen2WorldAPI.GEN1_FIRST_LOCK,
				"value": _gen1_roll(world) & Gen1Layout.TRASH_FIRST_MASK})
			side = "reset"
	return _gen1_resolve_script(world, node[side] as Array, steps, run)


static func _gen1_draw_second_can(world: Gen2WorldAPI, node: Dictionary, steps: Array) -> void:
	var table: Array = node["table"]
	var row: int = int(node["can"]) * int(node["row_size"])
	var roll: int = _gen1_roll(world)
	var swapped: int = ((roll & 0xF) << 4) | (roll >> 4)
	if int(node["row_size"]) == Gen1Layout.TRASH_ROW_SIZE:
		var masked: int = ((int(table[row]) & swapped) - 1) & 0xFF
		steps.append({"type": &"byte", "name": Gen2WorldAPI.GEN1_SECOND_LOCK,
			"value": int(table[row + 1 + masked]) & Gen1Layout.TRASH_CAN_MASK})
		steps.append({"type": &"byte", "name": Gen2WorldAPI.GEN1_SECOND_LOCK_ALT, "value": 0})
		return
	var pair: int = {2: roll & 1, 3: swapped, 4: roll & 3}.get(int(table[row]), 0)
	steps.append({"type": &"byte", "name": Gen2WorldAPI.GEN1_SECOND_LOCK,
		"value": int(table[row + 1 + 2 * pair])})
	steps.append({"type": &"byte", "name": Gen2WorldAPI.GEN1_SECOND_LOCK_ALT,
		"value": int(table[row + 2 + 2 * pair])})


static func _gen1_roll(world: Gen2WorldAPI) -> int:
	return world.script_random.randi_range(0, 255) if world.script_random != null else 0


static func _gen1_node_map_load_bit(_world: Gen2WorldAPI, node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	steps.append({"type": &"map_load", "bit": int(node["bit"])})
	return true


static func _gen1_node_volatile(_world: Gen2WorldAPI, node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	steps.append({
		"type": &"volatile", "name": String(node["name"]), "set": bool(node["set"]),
		"value": int(node.get("value", 1 if bool(node["set"]) else 0)),
	})
	return true


static func _gen1_node_volatile_test(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	return _gen1_resolve_side(world,
		node, bool(world._gen1_volatile.get(String(node["name"]), false)), steps, run
	)


static func _gen1_node_boulder_on(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	var standing: bool = false
	if world._gen1_last_boulder >= 0 and world._gen1_last_boulder < world.objects.size():
		var cell: Vector2i = (world.objects[world._gen1_last_boulder] as Gen2WorldObject).cell
		standing = _gen1_cell_index(node["cells"] as Array, cell, run)
	return _gen1_resolve_side(world, node, standing, steps, run)


static func _gen1_node_coord_lookup(world: Gen2WorldAPI, node: Dictionary, _steps: Array, run: Dictionary) -> bool:
	_gen1_cell_index(node["cells"] as Array, world.player_cell, run)
	return true


static func _gen1_cell_index(cells: Array, cell: Vector2i, run: Dictionary) -> bool:
	for index: int in cells.size():
		var row: Dictionary = cells[index]
		if cell == Vector2i(int(row["x"]), int(row["y"])):
			run["coord_index"] = index + 1
			return true
	return false


static func _gen1_node_emote(_world: Gen2WorldAPI, node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	steps.append({"type": &"emote", "object": int(node["object"]), "kind": int(node["kind"])})
	steps.append(Gen1FacilityScripts._gen1_wait_step(&"emote", Gen1Layout.EMOTE_FRAMES))
	return true


static func _gen1_node_object_path(_world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	steps.append({
		"type": &"object_path", "index": _gen1_object_index(node, run), "target": int(node["target"]),
		"perspective": int(node["perspective"]), "y_adjust": int(node["y_adjust"]),
	})
	return true


static func _gen1_node_trainer_battle(world: Gen2WorldAPI, node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	var number: int = int(node.get("number", 1))
	if String(node.get("number_from", "")) == "rival_starter" and world.state != null:
		number += world.state.gen1_starter("rival")
	steps.append(_gen1_trainer_request(world, int(node["class"]), number, node.get("end_texts", {}), -1))
	return true


static func _gen1_node_trainer_battle_object(
	world: Gen2WorldAPI,
	node: Dictionary, steps: Array, _run: Dictionary
) -> bool:
	var index: int = world._gen1_last_sprite_index
	if index < 0 or index >= world.objects.size():
		return false
	var rows: Array = world.current_map.events.get("objects", [])
	if index >= rows.size():
		return false
	var trainer: Dictionary = rows[index]
	if not trainer.has("species") and not trainer.has("trainer_class"):
		return false
	Gen1FacilityScripts._gen1_engage_music(world, trainer, steps)
	if trainer.has("species"):
		steps.append({"type": &"request", "values": {"kind": &"battle_requested",
			"values": Gen1FacilityScripts._gen1_battle_values(world, {}, trainer)}})
		return true
	steps.append(_gen1_trainer_request(world,
		int(trainer.get("trainer_class", 0)), int(trainer.get("trainer_number", 1)),
		node.get("end_texts", {}), index
	))
	return true


static func _gen1_trainer_request(
	world: Gen2WorldAPI,
	trainer_class: int, number: int, end_texts: Dictionary, object_index: int
) -> Dictionary:
	var won: Dictionary = {"text": "%s: %s" % [
		Gen1FacilityScripts._gen1_trainer_name(world, trainer_class), String(end_texts.get("won", "")),
	]}
	return {
		"type": &"request",
		"values": {"kind": &"battle_requested", "values": {
			"kind": &"trainer", "trainer_group": trainer_class, "trainer_class": trainer_class,
			"trainer_id": maxi(number - 1, 0), "object_index": object_index,
			"trainer_name": Gen1FacilityScripts._gen1_trainer_name(world, trainer_class),
			"win_text": won, "loss_text": Gen1FacilityScripts._gen1_loss_text(world, trainer_class),
			"defeated_text": Gen1FacilityScripts._gen1_defeated_text(world, trainer_class),
		}},
		"object_index": object_index,
	}


static func _gen1_node_warp_to(_world: Gen2WorldAPI, node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	steps.append({"type": &"warp_to", "map": int(node["map"]), "warp": int(node["warp"])})
	return true


static func _gen1_node_text_table(_world: Gen2WorldAPI, node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	steps.append({"type": &"text_table", "table": int(node["table"])})
	return true


static func _gen1_node_object_position(_world: Gen2WorldAPI, node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	steps.append({
		"type": &"object_position", "index": int(node["object"]),
		"axis": String(node["axis"]), "value": int(node["value"]),
	})
	return true


## `GetSpritePosition2` and `SetSpritePosition2`, WRAM the same visit reads back.
static func _gen1_node_object_position_kept(_world: Gen2WorldAPI, node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	steps.append({"type": StringName(node["op"]), "index": int(node["object"])})
	return true


static func _gen1_node_heal_party(_world: Gen2WorldAPI, _node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	steps.append({"type": &"request", "values": {
		"kind": &"party_heal_requested", "values": {},
	}})
	return true


## `HallOfFamePC` writes the team into `sHallOfFame` and counts it in
## `wNumHoFTeams` in front of the animation, which is the induction the shelf
## and the Pokemon Center's machine read as `ENGINE_HALL_OF_FAME`.
static func _gen1_node_hall_of_fame(world: Gen2WorldAPI, _node: Dictionary, steps: Array, run: Dictionary) -> bool:
	_gen1_node_flag(world, {"flag": Gen2WorldState.ENGINE_HALL_OF_FAME, "engine": true, "set": true}, steps, run)
	steps.append({"type": &"request", "values": {
		"kind": &"hall_of_fame_requested", "values": {},
	}})
	return true


static func _gen1_node_save_game(_world: Gen2WorldAPI, _node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	steps.append({"type": &"request", "values": {
		"kind": &"quick_save_requested", "values": {},
	}})
	return true


static func _gen1_node_reset_game(_world: Gen2WorldAPI, _node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	steps.append({"type": &"request", "values": {
		"kind": &"soft_reset_requested", "values": {},
	}})
	return true


static func _gen1_node_flag_range(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	var first: int = int(node["first"])
	for offset: int in int(node["count"]):
		_gen1_node_flag(world, {"flag": first + offset, "set": bool(node["set"])}, steps, run)
	return true


## The top row is skipped past Victory Road; the badge name fills `wNameBuffer`.
static func _gen1_node_badge_guards(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	for row: Dictionary in node["rows"] as Array:
		if world.player_cell.y != int(row["y"]):
			continue
		if world.player_cell.y == int(node["past_y"]) and world.player_cell.x >= int(node["past_x"]):
			return true
		if world.event_flag_active(int(row["flag"])):
			return true
		run["named"] = String(row["badge"])
		return _gen1_node_map_text(world, {"text": int(row["text"])}, steps, run)
	return true


static func _gen1_node_badges_byte(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	var byte: int = 0
	for bit: int in Gen1Layout.BADGE_COUNT:
		if world.state != null and world.state.is_engine_flag_active(Gen2WorldState.gen1_badge_flag(bit)):
			byte |= 1 << bit
	return _gen1_resolve_side(world, node, byte == int(node["value"]), steps, run)


## `jp DisplayTextID`: the map's own row, which the Mansion switches print.
static func _gen1_node_map_text(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	if world.current_map == null:
		return false
	var text_id: int = int(node["text"]) if node.has("text") \
		else _gen1_scratch_read(run, int(node["from"]), int(node["offset"]))
	## `hTextID` and `hSpriteIndex` are one HRAM byte, so a row a map script
	## opens by id leaves that id where `EngageMapTrainer` reads a sprite: the
	## object of that index is the trainer, which is how Lance's room fights him.
	world._gen1_last_sprite_index = text_id - 1
	var row: Dictionary = gen1_text_at(world, text_id)
	## `DisplayTextID` over a trainer's row is `TalkToTrainer` after the fight.
	var trainer: Array = Gen1FacilityScripts._gen1_trainer_steps(world, row, world._gen1_object_event(text_id - 1))
	if not trainer.is_empty():
		steps.append_array(trainer)
		return true
	var nodes: Variant = row.get("script", [])
	if nodes is Array and not (nodes as Array).is_empty():
		return _gen1_resolve_script(world, nodes as Array, steps, run)
	if String(row.get("text", "")).is_empty():
		return false
	## `wStringBuffer` outlives the row that filled it: Lt. Surge's receipt is
	## the `DisplayTextID` after his `GiveItem`.
	steps.append(Gen1FacilityScripts._gen1_script_box(world, row, String(run.get("named", "")), run.get("buffers", {})))
	return true


## A `TX_SCRIPT_*` a hidden event reached, which `DisplayTextID` dispatches the
## same way it does one standing on a sign.
static func _gen1_node_facility(world: Gen2WorldAPI, node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	var facility: Array = Gen1FacilityScripts._gen1_facility_steps(world, {"command": int(node["command"])})
	if facility.is_empty():
		return false
	steps.append_array(facility)
	return true


static func _gen1_node_money_box(_world: Gen2WorldAPI, _node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	steps.append({"type": &"money_box", "kind": &"money_top_right"})
	return true


static func _gen1_node_coin_box(_world: Gen2WorldAPI, _node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	steps.append({"type": &"money_box", "kind": &"game_corner"})
	return true


static func _gen1_node_toggle(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	steps.append({
		"type": &"toggle",
		"index": int(node["index"]) if node.has("index") \
			else Gen1MapScripts._gen1_toggle_index(world, _gen1_object_index(node, run)),
		"hidden": bool(node["hidden"]),
	})
	return true


## `_DisplayPokedex` opens on one entry and the page the world already has for
## `pokedex_entry_requested` is that same one.
static func _gen1_node_pokedex(_world: Gen2WorldAPI, node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	steps.append({"type": &"request", "values": {
		"kind": &"pokedex_entry_requested",
		"values": {"species": int(node["species"])},
	}})
	return true


static func _gen1_run_flag(world: Gen2WorldAPI, flag: int, run: Dictionary) -> bool:
	return bool((run["flags"] as Dictionary).get(flag, world.event_flag_active(flag)))


static func _gen1_node_flag_test(world: Gen2WorldAPI, node: Dictionary, _steps: Array, run: Dictionary) -> bool:
	var condition: Dictionary = node.duplicate()
	condition.erase("snapshot")
	run["flag_tests"][int(node["snapshot"])] = _gen1_branch_set(world, condition, run)
	return true


static func _gen1_branch_set(world: Gen2WorldAPI, node: Dictionary, run: Dictionary) -> bool:
	if node.has("snapshot"):
		return bool(run["flag_tests"][int(node["snapshot"])])
	if bool(node.get("engine", false)):
		return bool((run["engine_flags"] as Dictionary).get(int(node["flag"]),
			world.state != null and world.state.is_engine_flag_active(int(node["flag"]))))
	var first: bool = _gen1_run_flag(world, _gen1_node_flag_index(world, node, run), run)
	for flag: int in node.get("clear", []):
		if _gen1_run_flag(world, flag, run):
			return false
	if node.has("all"):
		for flag: int in node["all"] as Array:
			first = first and _gen1_run_flag(world, flag, run)
		return first
	if first:
		return true
	for flag: int in node.get("either", []):
		if _gen1_run_flag(world, flag, run):
			return true
	return false


static func _gen1_resolve_side(
	world: Gen2WorldAPI,
	node: Dictionary, taken: bool, steps: Array, run: Dictionary
) -> bool:
	return _gen1_resolve_script(world, node["then" if taken else "else"] as Array, steps, run)


## `_GivePokemon`, whose carry the caller's own `jr nc` reads: the party first,
## the box behind it, and no room at all is the one answer that clears it. Only
## the screen holding the save knows which, so both sides are resolved here and
## the request carries them until it comes back.
static func _gen1_resolve_gift_pokemon(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	var species: int = _gen1_fossil_species(world, run) \
		if String(node.get("from", "")) == "fossil_mon" else int(node["species"])
	if species < 1:
		return false
	var site: Dictionary = _gen1_site(world,
		GEN1_GIVING_KINDS, node, {"species": species, "level": int(node["level"])}
	)
	var step: Dictionary = {"type": &"request", "values": {
		"kind": &"pokemon_requested",
		"values": {"pokemon": int(site["species"]), "level": int(site["level"])},
	}}
	if node.has("routine"):
		(step["values"]["values"] as Dictionary)["routine"] = StringName(node["routine"])
	if node.has("ok"):
		var taken: Array = []
		var full: Array = []
		if not _gen1_resolve_script(world, node["ok"] as Array, taken, Gen1FacilityScripts._gen1_run_copy(run)) \
			or not _gen1_resolve_script(world, node["full"] as Array, full, Gen1FacilityScripts._gen1_run_copy(run)):
			return false
		step["ok"] = taken
		step["full"] = full
	steps.append(step)
	return true


## `AddItemToInventory` and its carry; only a gift that landed is named.
static func _gen1_resolve_gift(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	var site: Dictionary = {"item": int(node["item"]), "quantity": int(node["count"])}
	if node.has("hidden"):
		site = _gen1_event_site(world,
			Gen2WorldCatalog.KIND_ITEM, Gen2WorldCatalog.GEN1_SOURCE_HIDDEN, int(node["hidden"]), site
		)
	else:
		site = _gen1_site(world, [Gen2WorldCatalog.KIND_ITEM], node, site)
	var item: int = int(site["item"])
	var bag: Dictionary = run["bag"]
	var room: Dictionary = Gen2WorldPack.receive_check(
		world.data, bag, item, maxi(1, int(site["quantity"]))
	)
	var taken: bool = bool(room.get("ok", false))
	if taken:
		bag[item] = int(room["quantity"])
		run["named"] = world.data.item_name(item) if world.data != null else ""
		steps.append({"type": &"items", "items": {item: int(room["quantity"])}})
	if not node.has("ok"):
		return true
	return _gen1_resolve_script(world, node["ok" if taken else "full"] as Array, steps, run)


## `PickUpItem`: the object's own item, `HideObject` on it, and the receipt
## behind `wDoNotWaitForButtonPress`. Its own `ret z` says nothing at all for an
## item object outside `ToggleableObjectStates`.
static func _gen1_pick_up_item(world: Gen2WorldAPI, _node: Dictionary, steps: Array, run: Dictionary) -> bool:
	var object: Dictionary = run.get("object", {})
	var item: int = int(_gen1_event_site(world,
		Gen2WorldCatalog.KIND_ITEM, Gen2WorldCatalog.GEN1_SOURCE_OBJECT,
		int(object.get("object_index", -1)), {"item": int(object.get("item", 0))}
	)["item"])
	var toggle: int = int(object.get("toggle_index", -1))
	if item < 1 or toggle < 0:
		return false
	var bag: Dictionary = run["bag"]
	var room: Dictionary = Gen2WorldPack.receive_check(world.data, bag, item, 1)
	if not bool(room.get("ok", false)):
		steps.append(Gen1FacilityScripts._gen1_facility_box(world, GEN1_PICK_UP_RUN, "no_room"))
		return true
	bag[item] = int(room["quantity"])
	steps.append({"type": &"items", "items": {item: int(room["quantity"])}})
	steps.append({"type": &"toggle", "index": toggle, "hidden": true})
	var box: Dictionary = Gen1FacilityScripts._gen1_facility_box(world, GEN1_PICK_UP_RUN, "found")
	box["text"] = Gen2TextStream.fill_all_markers(
		String(box["text"]), Gen2TextStream.RAM_MARKER,
		world.data.item_name(item) if world.data != null else ""
	)
	box["press"] = false
	steps.append(box)
	return true


## `RemoveGuardDrink`: the first row of `GuardDrinksList` the bag holds is spent
## and named in `hItemToRemoveID`. The Saffron gate guards are its only callers.
static func _gen1_node_guard_drink(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	var bag: Dictionary = run["bag"]
	for item: int in node["items"] as Array:
		if int(bag.get(item, 0)) < 1:
			continue
		_gen1_take_item(world, {"item": item}, steps, run)
		return _gen1_resolve_side(world, node, true, steps, run)
	return _gen1_resolve_side(world, node, false, steps, run)


static func _gen1_take_item(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	var bag: Dictionary = run["bag"]
	var item: int = _gen1_item_of(world, int(node["item"]), run)
	var left: int = int(bag.get(item, 0)) - 1
	if left < 0:
		return true
	if left == 0:
		bag.erase(item)
	else:
		bag[item] = left
	steps.append({"type": &"items", "items": {item: left}})
	return true


## `DaycareGentlemanText`, which owns the whole row: the offer and a party list
## on one side of `wDayCareInUse`, the growth and the price on the other.
static func _gen1_node_day_care(world: Gen2WorldAPI, _node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	if world.data == null or world.state == null:
		return false
	if not world.state.day_care_has_mon(Gen2WorldDayCare.SLOT_MAN):
		steps.append(Gen1FacilityScripts._gen1_day_care_offer(world))
		return true
	return Gen1FacilityScripts._gen1_day_care_visit(world, steps)


static func _gen1_node_filtered_bag(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	return _gen1_resolve_side(world,
		node, not Gen1FacilityScripts._gen1_menu_rows(world, {"filter": node.get("items", [])}, run).is_empty(),
		steps, run
	)


## `DisplayListMenuID` over `SPECIALLISTMENU`, reopened behind every line it
## prints: the loop is the node and the `jr c` B answers the way out.
static func _gen1_node_list_menu(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	var done: Array = []
	if not _gen1_resolve_script(world, node["done"] as Array, done, Gen1FacilityScripts._gen1_run_copy(run)):
		return false
	var rows: Array = []
	for row: Dictionary in node["rows"] as Array:
		rows.append({
			"item": int(row["item"]),
			"name": world.data.item_name(int(row["item"])) if world.data != null else "",
			"text": gen1_filled_text(world, String(row["text"])),
		})
	steps.append({
		"type": &"request", "list_menu": true, "rows": rows, "done": done,
		"values": {"kind": &"gen1_list_menu_requested", "values": {"rows": rows}},
	})
	return true


static func _gen1_node_menu_cancel(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	return _gen1_resolve_side(world,
		node, bool((run.get("menu", {}) as Dictionary).get("cancelled", false)), steps, run
	)


static func _gen1_node_menu_row(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	return _gen1_resolve_side(world,
		node, int((run.get("menu", {}) as Dictionary).get("row", -1)) == int(node["row"]),
		steps, run
	)


static func _gen1_node_menu_item(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	return _gen1_resolve_side(world,
		node, int((run.get("menu", {}) as Dictionary).get("item", -1)) == int(node["item"]),
		steps, run
	)


static func _gen1_node_dex_rating(world: Gen2WorldAPI, _node: Dictionary, steps: Array, _run: Dictionary) -> bool:
	var rated: Dictionary = Gen2ProfOaksPC.rate(world.data, world.state)
	if rated.is_empty():
		return false
	for page: String in rated["pages"] as Array:
		steps.append({"type": &"text", "text": gen1_filled_text(world, page)})
	return true


static func _gen1_node_serial_status(world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	var status: int = world.state.link_transport().status() if world.state != null \
		else Gen2LinkTransport.CONNECTION_NOT_ESTABLISHED
	return _gen1_resolve_side(world, node, status == int(node["status"]), steps, run)


## `CableClub_Run` reads a `LINK_STATE_START_*` store on the next box's first
## joypad poll, so that box owes no press.
static func _gen1_node_link_state(_world: Gen2WorldAPI, node: Dictionary, steps: Array, run: Dictionary) -> bool:
	var value: int = int(node["value"])
	steps.append({"type": &"link_state", "value": value})
	if value in [Gen1Layout.LINK_STATE_START_TRADE, Gen1Layout.LINK_STATE_START_BATTLE]:
		run["cable_club_run"] = value
	return true
