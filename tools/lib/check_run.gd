extends RefCounted

## The harness every `tools/validate.gd` topic shares: the cartridges, the
## failure list, and the world helpers a map check needs.
## A topic is a script under `tools/checks/` with `func run(r) -> void`. It
## reports through [method check] and prints its own census lines with
## [method note]; the runner owns the exit code.

## The cartridges used by topics that call `each_game`.
static var GAME_IDS: Array[StringName] = RomRegistry.ids_of_generation(RomRegistry.GEN2)

## The party [code]CheckPartyMove[/code] gates every field move against. These
## checks are about the tables and the map rather than the party, so a world one
## opens carries a member that knows all five. The story route is where a real
## party earning them is proved.
const FIELD_MOVE_PARTY_SIZE: int = 1

var failures: PackedStringArray = []

## Godot ends the function a runtime error happened in and returns to its
## caller, so a topic that throws goes on to print its own verdict:
## `gen1_maps` said PASS for every run in which its hidden event census had not
## run at all. `OS.add_logger` is the only thing in the engine that sees one.
class RuntimeErrors extends Logger:
	var seen: PackedStringArray = []

	func _log_error(
		function: String, file: String, line: int, code: String,
		rationale: String, _editor_notify: bool, _error_type: int,
		_backtraces: Array[ScriptBacktrace]
	) -> void:
		seen.append("%s:%d in %s(): %s" % [
			file, line, function, code if rationale.is_empty() else rationale,
		])


var _errors: RuntimeErrors = RuntimeErrors.new()

## Set per game by [method each_game] so a topic can read them without threading
## them through every helper.
var game_id: StringName = &""
var data: GameData = null
var crystal: bool = false


## Records [param message] when [param condition] is false, and answers it so a
## caller can stop after a failed precondition.
func check(condition: bool, message: String) -> bool:
	if not condition:
		failures.append("%s: %s" % [game_id, message] if game_id != &"" else message)
	return condition


func fail(message: String) -> void:
	check(false, message)


func watch() -> void:
	OS.add_logger(_errors)


## Stops, and answers for every error raised while it was watching.
func unwatch() -> void:
	OS.remove_logger(_errors)
	for error: String in _errors.seen:
		fail("a runtime error stopped a check: %s" % error)


## A census or landmark line. Kept apart from [method fail] so a topic reads the
## same whether it is passing or not.
func note(message: String) -> void:
	print("%s: %s" % [game_id, message] if game_id != &"" else message)


## Whether [param lines] hash to [param digest]. With `CHECK_DUMP` naming a
## directory the lines are written there, so a wrong digest can be diffed.
func digest_matches(name: String, lines: PackedStringArray, digest: String) -> bool:
	var text: String = "\n".join(lines) + "\n"
	var dump_dir: String = OS.get_environment("CHECK_DUMP")
	if not dump_dir.is_empty():
		var file: FileAccess = FileAccess.open(
			"%s/%s.%s.txt" % [dump_dir, name, game_id], FileAccess.WRITE
		)
		if file != null:
			file.store_string(text)
	var answered: String = text.sha1_text()
	return check(answered == digest, "the %d-case %s sweep is %s, the cartridge %s." % [
		lines.size() - 1, name, answered, digest,
	])


## Runs [param body] once per Generation 2 cartridge with [member data],
## [member game_id] and [member crystal] set.
func each_game(body: Callable) -> void:
	each_game_of(RomRegistry.GEN2, body)


## The same for one generation's cartridges. A cache that will not open is one
## failure, not a crash. [member crystal] is meaningless outside Generation 2
## and stays false there.
func each_game_of(generation: int, body: Callable) -> void:
	for id: StringName in RomRegistry.ids_of_generation(generation):
		var opened: GameData = GameData.open(id)
		if opened == null:
			game_id = &""
			fail("%s cache is unavailable. Import its dump into roms/ first." % id)
			continue
		game_id = id
		data = opened
		crystal = generation == RomRegistry.GEN2 and Gen2WorldState.is_crystal_profile(opened)
		body.call()
	game_id = &""
	data = null
	crystal = false


## A world opened on [param cell], with [param state] or a fresh one. Answers
## null and records the failure when the map is not in the cache.
func open_world(
	group: int, number: int, cell: Vector2i, state: Gen2WorldState = null
) -> Gen2WorldAPI:
	var world: Gen2WorldAPI = Gen2WorldAPI.open(
		data, group, number, cell, state if state != null else Gen2WorldState.new()
	)
	if world == null:
		fail("map %d/%d is missing." % [group, number])
	return world


func open_screen(group: int, number: int, cell: Vector2i, party: bool = true) -> Gen2WorldScreen:
	var screen: Gen2WorldScreen = (load("res://game/world/world_screen.tscn") as PackedScene).instantiate()
	screen.map_group = group
	screen.map_number = number
	screen.start_cell = cell
	screen.encounter_seed = 1
	screen.set_data(data)
	var save: Gen2SaveData = Gen2SaveStore.create_development_save(data, 0)
	if not party:
		save.party = []
	screen.set_save(save)
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.set_process(false)
	return screen


func close_screen(screen: Gen2WorldScreen) -> void:
	(Engine.get_main_loop() as SceneTree).root.remove_child(screen)
	screen.free()


## A prompt's box printed to its end or its YES/NO, every line held once.
func settle_prompt(
	screen: Gen2WorldScreen, prompt: Gen2NicknamePromptScreen, frames: int = 2000
) -> PackedStringArray:
	for _frame: int in frames:
		if prompt.phase() == Gen2NicknamePromptScreen.Phase.ASK and prompt.question_ready():
			break
		var box: Gen2TextBox = prompt.get("_text_box")
		if box != null and not box.is_revealing():
			if not box.has_pages_left():
				break
			screen.press_button(PokeButton.A)
		screen.advance_frame()
	var out: PackedStringArray = PackedStringArray()
	for line: String in prompt.text_lines():
		if out.is_empty() or out[out.size() - 1] != line:
			out.append(line)
	return out


## Every cell reachable on foot from [param from], which is what says two parts
## of a map are joined or sealed off from each other.
func region(world: Gen2WorldAPI, from: Vector2i) -> Dictionary:
	var seen: Dictionary = {from: true}
	var frontier: Array[Vector2i] = [from]
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_back()
		for step: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = cell + step
			if seen.has(next) or not world.can_walk_to(next):
				continue
			seen[next] = true
			frontier.append(next)
	return seen


func field_move_party(world: Gen2WorldAPI) -> void:
	world.set_party_summary(
		FIELD_MOVE_PARTY_SIZE, false, [1] as Array[int],
		[Gen2WorldFieldMove.FIELD_MOVES.duplicate()], ["MON"], [false]
	)
