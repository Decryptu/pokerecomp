extends SceneTree

## Every hardware frame of a walk on the real world screen: the scroll, the
## player's drawn pixel and which of `Facings` is up, after ten standing frames.
## Diff `screen_x` against the cartridge's OAM slot 0 minus rSCX, not against
## `wPlayerSpriteX - hSCX`: `HandleMapObjects` writes that two frames early.
## `<game> <group> <map> <x> <y> <direction> <frames> <out.txt> [facing] [pikachu]`;
## `direction` may be `dir:frames,...` (`none` releases) held in turn. `pikachu`
## makes the lead the starter and appends slot fifteen's columns:
## `status image facing y x ypix xpix anim walk_anim | bufsize buf | flags spawn collision`.

const STANDING_FRAMES: int = 10


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 8:
		push_error("usage: <game> <group> <map> <x> <y> <direction> <frames> <out.txt>")
		quit(2)
		return
	var data: GameData = GameData.open(StringName(args[0]))
	if data == null:
		push_error("no imported cache for %s" % args[0])
		quit(2)
		return
	var segments: Array = _segments(args[5])
	if segments.is_empty():
		push_error("direction is one of up, down, left, right, or dir:frames,... with none")
		quit(2)
		return
	var frames: int = maxi(1, int(args[6]))
	var pikachu: bool = args.has("pikachu")

	var packed: PackedScene = load("res://game/world/world_screen.tscn")
	var screen: Gen2WorldScreen = packed.instantiate() as Gen2WorldScreen
	screen.set_data(data)
	screen.map_group = int(args[1])
	screen.map_number = int(args[2])
	screen.start_cell = Vector2i(int(args[3]), int(args[4]))
	if args.size() >= 9 and _facing_for(args[8]) >= 0:
		screen.start_facing = _facing_for(args[8])
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(screen)
	await process_frame
	if screen._world == null:
		push_error("the world did not open: %s" % screen._caption.text)
		quit(2)
		return
	screen.set_process(false)
	if pikachu:
		## The cartridge's own two pixels a pass, so the camera the follower's
		## screen pixels are measured from is `hSCX` rather than a smoothed one.
		Gen2OptionsStore.current().smooth_scroll = false
		screen.preview_pikachu()
		## EVENT_FOLLOWED_OAK_INTO_LAB, which the cartridge trace sets too, so
		## Pallet Town's north exit is a connection rather than Oak's box.
		screen._world.state.set_event_flag(0, true)
		## Level 100 under a Repel on both sides: the grass rolls no fight.
		screen._injected_save.party[0].level = 100
		screen._refresh_party_summary()
		screen._world.set_repel_steps(250)
		## `trace_pikachu.py` answers slot fifteen's `Random` from the same list.
		var rolls: Array[int] = [0x00, 0x55, 0xAA, 0xFF, 0x11, 0x22, 0x33, 0x44]
		var dealt: Array[int] = [0]
		screen._world.pikachu.roll_source = func() -> int:
			var value: int = rolls[dealt[0] % rolls.size()]
			dealt[0] += 1
			return value

	## Held from the eleventh frame on, which is where the cartridge trace
	## presses, and released once the run has spent its frames. A replay entry
	## is keyed by `frame_number`, which `advance_frame` steps before it reads
	## the entry, so the line sampled as frame N is frame_number N + 1.
	var log_lines: Array = []
	var at: int = STANDING_FRAMES
	for segment: Array in segments:
		var button: int = int(segment[0])
		var held: int = int(segment[1]) if int(segment[1]) > 0 else frames - at
		for frame: int in range(at, mini(frames, at + held)):
			log_lines.append({"frame": frame + 1, "kind": "hold", "button": button})
		at += held
	screen.replay_input(log_lines)

	var lines: PackedStringArray = PackedStringArray([
		"# frame cam_x cam_y x y screen_x screen_y facing walk_frame"
		+ (" | status image facing y x ypix xpix anim walk_anim | bufsize buf"
			+ " | flags spawn collision" if pikachu else "")
	])
	for frame: int in frames:
		screen.advance_frame()
		lines.append(_sample(screen._world, frame) + (_sample_pikachu(screen._world) if pikachu else ""))
	var out: String = args[7]
	if PokeToolPath.refuses(out):
		quit(2)
		return
	FileAccess.open(out, FileAccess.WRITE).store_string("\n".join(lines) + "\n")
	print("wrote %d frames to %s" % [frames, out])
	root.remove_child(screen)
	screen.free()
	quit(0)


## Read after the frame is spent, which is where the emulator samples: a line is
## the state the frame it names left behind.
func _sample(world: Gen2WorldAPI, frame: int) -> String:
	var camera: Vector2 = world.visible_origin_cells() * float(Gen2WorldAPI.CELL_PIXELS)
	var screen_pixel: Vector2i = world.player_pixel_position()
	return "%d %d %d %d %d %d %d %d %d" % [
		frame, roundi(camera.x), roundi(camera.y),
		world.player_cell.x, world.player_cell.y,
		screen_pixel.x, screen_pixel.y,
		world.player_facing, world.player_walk_frame(),
	]


## Slot fifteen in the cartridge's own units: map coordinates four past the
## cell, and screen pixels measured from the player at (64, 60).
func _sample_pikachu(world: Gen2WorldAPI) -> String:
	var pikachu: Gen1Pikachu = world.pikachu
	if pikachu == null:
		return " | -"
	var camera: Vector2i = Vector2i(world.visible_origin_cells() * float(Gen2WorldAPI.CELL_PIXELS))
	var screen_pixel: Vector2i = pikachu.pixel - camera + Vector2i(0, -4)
	var buffer: PackedStringArray = PackedStringArray()
	for command: int in pikachu.buffer:
		buffer.append(str(command))
	return " | %d %d %d %d %d %d %d %d %d | %d %s | %d %d %d" % [
		pikachu.status, (Gen1Pikachu.IMAGE_BASE | pikachu.image) if pikachu.image >= 0 else 255,
		pikachu.facing, pikachu.cell.y + 4, pikachu.cell.x + 4,
		screen_pixel.y & 0xFF, screen_pixel.x & 0xFF,
		pikachu.anim_frame, pikachu.walk_counter,
		pikachu.buffer.size(), ",".join(buffer),
		pikachu.flags, pikachu.spawn_state, pikachu.collision_counter,
	]


## `dir` or `dir:frames,...`; a segment with no count runs to the end.
func _segments(spec: String) -> Array:
	var out: Array = []
	for part: String in spec.split(","):
		var halves: PackedStringArray = part.split(":")
		var button: int = _button_for(halves[0])
		if button == PokeButton.NONE and halves[0].to_lower() != "none":
			return []
		out.append([button, int(halves[1]) if halves.size() > 1 else 0])
	return out


func _button_for(name: String) -> int:
	match name.to_lower():
		"up": return PokeButton.UP
		"down": return PokeButton.DOWN
		"left": return PokeButton.LEFT
		"right": return PokeButton.RIGHT
	return PokeButton.NONE


func _facing_for(name: String) -> int:
	match name.to_lower():
		"down": return Gen2WorldSprite.FACING_DOWN
		"up": return Gen2WorldSprite.FACING_UP
		"left": return Gen2WorldSprite.FACING_LEFT
		"right": return Gen2WorldSprite.FACING_RIGHT
	return -1
