extends GutTest

## `_FoundItemText`'s `<PLAYER>` is `wPlayerName`, which the runner fills from
## the name the world carries before the box is staged.

const Fixture := preload("res://tests/integration/world_trainer_fixture.gd")

const ITEM: int = 7

var _data: GameData = null


func before_each() -> void:
	_data = Fixture.build()


func after_each() -> void:
	RomCache.clear(Fixture.directory())


## `FindItemInBallScript` through the world: the ball in front of the player is
## an `.itemball` object, and a named player reads their own name in the box.
func test_a_named_player_finds_the_item_under_their_own_name() -> void:
	var world := Gen2WorldAPI.open(
		_data, Fixture.MAP_GROUP, Fixture.MAP_NUMBER, Vector2i(7, 6), Gen2WorldState.new()
	)
	var ball: Gen2WorldObject = world.objects[0]
	var event: Dictionary = world.current_map.events["objects"][0]
	var scripts: Dictionary = RomCache.read_json(RomCache.world_scripts_path(Fixture.directory()))
	scripts[Gen2WorldScript.pointer_key(Fixture.BANK, int(event["script"]))] = [ITEM, 1, 0x91]
	RomCache.write_json(RomCache.world_scripts_path(Fixture.directory()), scripts)
	_data = GameData.open_directory(Fixture.directory())
	world = Gen2WorldAPI.open(
		_data, Fixture.MAP_GROUP, Fixture.MAP_NUMBER, ball.cell + Vector2i.DOWN,
		Gen2WorldState.new()
	)
	world.objects[0].object_type = Gen2WorldObject.OBJECTTYPE_ITEMBALL
	world.player_facing = Gen2WorldSprite.FACING_UP
	assert_true(bool(world.set_player_name("GOLD").get("ok", false)))

	var results: Array = world.interact()
	assert_eq(results.size(), 1, JSON.stringify(results))
	assert_eq(results[0]["source"]["kind"], &"item_ball")
	assert_eq(results[0]["event"]["text"], "GOLD found\n%s!" % _data.item_name(ITEM))
