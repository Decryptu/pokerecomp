extends GutTest

## `NamingScreen`'s `.Pokemon` row prints `GetGender`'s sign for the Pokemon being
## named. Both callers here name a Pokemon that already exists: `HatchEggs` has
## written the hatchling and `GivePoke` has added the gift before `InitNickname`,
## so the sign on the keyboard is the stored Pokemon's own.

const Fixture := preload("res://tests/integration/world_trainer_fixture.gd")
const BattleFixture := preload("res://tests/unit/battle_fixture.gd")

## A half-and-half species, so the sign is always one of the two and the DVs
## decide which.
const GENDERED_SPECIES: int = BattleFixture.CUBONE

var _data: GameData = null
var _world_screen: Gen2WorldScreen = null


func before_each() -> void:
	_data = Fixture.build()
	_data = GameData.open_directory(Fixture.directory())


func after_each() -> void:
	await get_tree().process_frame
	if is_instance_valid(_world_screen):
		_world_screen.free()
		_world_screen = null
	RomCache.clear(Fixture.directory())
	Gen2ModHost.reset()


func _open_world(seed_value: int = 0) -> void:
	var packed: PackedScene = load("res://game/world/world_screen.tscn")
	_world_screen = packed.instantiate() as Gen2WorldScreen
	_world_screen.map_group = Fixture.MAP_GROUP
	_world_screen.map_number = Fixture.MAP_NUMBER
	_world_screen.start_cell = Vector2i(4, 5)
	_world_screen.encounter_seed = seed_value
	_world_screen.set_data(_data)
	var player: Gen2BattleMon = Gen2BattleMon.create(
		_data, Fixture.TRAINER_SPECIES, 5, [BattleFixture.TACKLE]
	)
	var save: Gen2SaveData = Gen2SaveBattleAdapter.from_battle_party(
		_data.id, _data.sha1, 0, Gen2Party.of(player), "TEST"
	)
	var snapshot := Gen2WorldSnapshot.new()
	snapshot.map_id = Vector2i(Fixture.MAP_GROUP, Fixture.MAP_NUMBER)
	snapshot.player_cell = Vector2i(4, 5)
	snapshot.world_state = Gen2WorldState.new()
	save.world = snapshot
	_world_screen.set_save(save)
	add_child(_world_screen)
	await get_tree().process_frame


func _spend_answer_hold() -> void:
	_world_screen.advance_frames(Gen2WorldMenu.ANSWER_HOLD_FRAMES)


## `HatchEggs`' `.nickname` reaches `NamingScreen` under NAME_MON with the
## hatched slot, whose DVs are the ones the egg carried.
func test_the_hatch_keyboard_shows_the_hatchlings_own_gender() -> void:
	await _open_world()
	_world_screen.preview_egg_hatch(GENDERED_SPECIES)
	var save: Gen2SaveData = _world_screen._injected_save
	var screen: Gen2EggHatchScreen = _world_screen.get("_hatch_host")
	assert_not_null(screen)
	assert_eq(int(screen.current_hatch().get("dvs", -1)), save.party[0].dvs)
	for _frame: int in 4000:
		if screen.nickname_cursor() >= 0:
			break
		_world_screen.advance_frame()
		if screen.awaiting_press():
			_world_screen.press_button(PokeButton.A)
	_world_screen.press_button(PokeButton.A)
	_spend_answer_hold()
	assert_eq(screen.phase(), Gen2EggHatchScreen.Phase.NAMING)
	var gender_sign: int = int(screen.naming_screen().get("_gender"))
	assert_ne(gender_sign, 0, "a gendered species prints a sign")
	assert_eq(gender_sign, Gen2NamingScreenScreen.gender_sign(
		_data, GENDERED_SPECIES, save.party[0].dvs
	))


func _write_givepoke_script() -> void:
	var directory: String = Fixture.directory()
	var scripts: Dictionary = RomCache.read_json(RomCache.world_scripts_path(directory))
	scripts[Gen2WorldScript.pointer_key(Fixture.BANK, Fixture.TUTORIAL_SCRIPT)] = [
		Gen2WorldScript.GIVEPOKE, GENDERED_SPECIES, 5, 0, 0,
		Gen2WorldScript.END,
	]
	RomCache.write_json(RomCache.world_scripts_path(directory), scripts)
	_data = GameData.open_directory(directory)


## `GivePoke`'s `.wildmon` branch: the question is asked, and the keyboard's
## sign drawn, over the Pokemon the request then writes, so the row keeps the
## DVs the sign was read from. Seeds that roll both genders, so a sign that
## only matched by chance cannot pass them all.
func test_a_gifts_keyboard_sign_matches_the_pokemon_received() -> void:
	_write_givepoke_script()
	var signs: Dictionary = {}
	for seed_value: int in [1, 2, 3, 4, 5, 6]:
		if is_instance_valid(_world_screen):
			_world_screen.free()
		await _open_world(seed_value)
		var save: Gen2SaveData = _world_screen._injected_save
		var before: int = save.party.size()
		_world_screen._show_script_results(
			_world_screen._world.dispatch_script_events(Vector2i(4, 5))
		)
		var host: Gen2NicknamePromptScreen = _world_screen.get("_nickname_host")
		assert_not_null(host, "`GiveANickname_YesNo` is drawn")
		var gender_sign: int = int(host.get("_gender_sign"))
		host.closed.emit()
		assert_eq(save.party.size(), before + 1, "the gift is written behind the prompt")
		var received: Gen2SaveMon = save.party[before]
		assert_ne(gender_sign, 0)
		assert_eq(gender_sign, Gen2NamingScreenScreen.gender_sign(
			_data, GENDERED_SPECIES, received.dvs
		), "seed %d" % seed_value)
		signs[gender_sign] = true
	assert_eq(signs.size(), 2, "the seeds rolled both signs")
