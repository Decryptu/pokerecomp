class_name Gen3TilesetAnims
extends RefCounted

## A tileset's callback is an `InitTilesetAnim_*` (Ruby: `TilesetCB_*`) routine,
## copied as rows: when `timer % every == at`, queue `table[(timer / div - sub) % count]`
## (u16 subtraction) at `tile` or BG `palette`. `dests` unrolls the `timer_mod`
## families over that VRAM pointer table; `length` -1 is the primary's length.

const VRAM_BASE: int = 0x06000000
const TILE_BYTES: int = 32

const RS_ANIMS: Dictionary = {
	"General": {"length": 256, "rows": [
		{"every": 16, "at": 0, "div": 16, "table": "General0", "count": 4, "tile": 508, "bytes": 0x80},
		{"every": 16, "at": 1, "div": 16, "table": "General1", "count": 8, "tile": 432, "bytes": 0x3C0},
		{"every": 16, "at": 2, "div": 16, "table": "General2", "count": 8, "tile": 464, "bytes": 0x140},
		{"every": 16, "at": 3, "div": 16, "table": "General3", "count": 4, "tile": 496, "bytes": 0xC0},
		{"every": 16, "at": 4, "div": 16, "table": "General4", "count": 4, "tile": 480, "bytes": 0x140}]},
	"Building": {"length": 256, "rows": [
		{"every": 8, "at": 0, "div": 8, "table": "InsideBuilding0", "count": 2, "tile": 496, "bytes": 0x80}]},
	"Petalburg": {}, "Dewford": {}, "Slateport": {}, "Fallarbor": {}, "Fortree": {},
	"Lilycove": {}, "Mossdeep": {}, "Sootopolis": {},
	"Rustboro": {"rows": [
		{"every": 8, "div": 8, "table": "Rustboro0", "count": 8, "dests": "RustboroVDests0", "bytes": 0x80},
		{"every": 8, "at": 0, "div": 8, "table": "Rustboro1", "count": 2, "tile": 960, "bytes": 0x80}]},
	"Mauville": {"sync": true, "rows": [
		{"every": 8, "div": 8, "table": "Mauville0", "count": 12, "below": 12, "dests": "MauvilleVDests0", "bytes": 0x80},
		{"every": 8, "div": 8, "table": "Mauville1", "count": 12, "below": 12, "dests": "MauvilleVDests1", "bytes": 0x80},
		{"every": 8, "div": 8, "table": "Mauville2", "count": 4, "from": 12, "dests": "MauvilleVDests0", "bytes": 0x80},
		{"every": 8, "div": 8, "table": "Mauville3", "count": 4, "from": 12, "dests": "MauvilleVDests1", "bytes": 0x80}]},
	"Lavaridge": {"rows": [
		{"every": 16, "at": 0, "div": 16, "table": "Lavaridge0", "count": 4, "tile": 800, "bytes": 0x80},
		{"every": 16, "at": 0, "div": 16, "add": 2, "table": "Lavaridge0", "count": 4, "tile": 804, "bytes": 0x80},
		{"every": 16, "at": 1, "div": 16, "table": "Lavaridge1_Cave0", "count": 4, "tile": 672, "bytes": 0x80}]},
	"EverGrande": {"rows": [
		{"every": 8, "div": 8, "table": "EverGrande0", "count": 8, "dests": "EverGrandeVDests0", "bytes": 0x80}]},
	"Pacifidlog": {"sync": true, "rows": [
		{"every": 16, "at": 0, "div": 16, "table": "Pacifidlog0", "count": 4, "tile": 976, "bytes": 0x3C0},
		{"every": 16, "at": 1, "div": 16, "table": "Pacifidlog1", "count": 8, "tile": 1008, "bytes": 0x100}]},
	"Underwater": {"length": 128, "rows": [
		{"every": 16, "at": 0, "div": 16, "table": "Underwater0", "count": 4, "tile": 1008, "bytes": 0x80}]},
	"SootopolisGym": {"length": 240, "rows": [
		{"every": 8, "at": 0, "div": 8, "table": "SootopolisGym0", "count": 3, "tile": 1008, "bytes": 0x180},
		{"every": 8, "at": 0, "div": 8, "table": "SootopolisGym1", "count": 3, "tile": 976, "bytes": 0x280}]},
	"Cave": {"rows": [
		{"every": 16, "at": 1, "div": 16, "table": "Lavaridge1_Cave0", "count": 4, "tile": 928, "bytes": 0x80}]},
	"EliteFour": {"length": 128, "rows": [
		{"every": 64, "at": 0, "div": 64, "table": "EliteFour0", "count": 2, "tile": 992, "bytes": 0x80},
		{"every": 8, "at": 1, "div": 8, "table": "EliteFour1", "count": 4, "tile": 1016, "bytes": 0x20}]},
	"MauvilleGym": {"rows": [
		{"every": 2, "at": 0, "div": 2, "table": "MauvilleGym0", "count": 2, "tile": 656, "bytes": 0x200}]},
	"BikeShop": {"rows": [
		{"every": 4, "at": 0, "div": 4, "table": "BikeShop0", "count": 2, "tile": 1008, "bytes": 0x120}]},
}

const FRLG_ANIMS: Dictionary = {
	"General": {"length": 640, "rows": [
		{"every": 8, "at": 0, "div": 8, "table": "General_SandWatersEdge", "count": 8, "tile": 464, "bytes": 0x240},
		{"every": 16, "at": 1, "div": 16, "table": "General_Water_Current_LandWatersEdge", "count": 8, "tile": 416, "bytes": 0x600},
		{"every": 16, "at": 2, "div": 16, "table": "General_Flower", "count": 5, "tile": 508, "bytes": 0x80}]},
	"CeladonCity": {"length": 120, "rows": [
		{"every": 12, "at": 0, "div": 12, "table": "CeladonCity_Fountain", "count": 5, "tile": 744, "bytes": 0x100}]},
	"SilphCo": {"length": 160, "rows": [
		{"every": 10, "at": 0, "div": 10, "table": "SilphCo_Fountain", "count": 4, "tile": 976, "bytes": 0x100}]},
	"MtEmber": {"length": 256, "rows": [
		{"every": 16, "at": 0, "div": 16, "table": "MtEmber_Steam", "count": 4, "tile": 896, "bytes": 0x100}]},
	"VermilionGym": {"length": 240, "rows": [
		{"every": 2, "at": 0, "div": 2, "table": "VermilionGym_MotorizedDoor", "count": 2, "tile": 880, "bytes": 0xE0}]},
	"CeladonGym": {"length": 256, "rows": [
		{"every": 16, "at": 0, "div": 16, "table": "CeladonGym_Flowers", "count": 4, "tile": 739, "bytes": 0x80}]},
}

## `TilesetAnim_BattleDome2`, run during a battle transition, is not a row.
const EMERALD_ANIMS: Dictionary = {
	"General": {"length": 256, "rows": [
		{"every": 16, "at": 0, "div": 16, "table": "General_Flower", "count": 4, "tile": 508, "bytes": 0x80},
		{"every": 16, "at": 1, "div": 16, "table": "General_Water", "count": 8, "tile": 432, "bytes": 0x3C0},
		{"every": 16, "at": 2, "div": 16, "table": "General_SandWaterEdge", "count": 8, "tile": 464, "bytes": 0x140},
		{"every": 16, "at": 3, "div": 16, "table": "General_Waterfall", "count": 4, "tile": 496, "bytes": 0xC0},
		{"every": 16, "at": 4, "div": 16, "table": "General_LandWaterEdge", "count": 4, "tile": 480, "bytes": 0x140}]},
	"Building": {"length": 256, "rows": [
		{"every": 8, "at": 0, "div": 8, "table": "Building_TvTurnedOn", "count": 2, "tile": 496, "bytes": 0x80}]},
	"Petalburg": {}, "Fallarbor": {}, "Fortree": {}, "Lilycove": {}, "Mossdeep": {},
	"Rustboro": {"rows": [
		{"every": 8, "div": 8, "table": "Rustboro_WindyWater", "count": 8, "dests": "Rustboro_WindyWater_VDests", "bytes": 0x80},
		{"every": 8, "at": 0, "div": 8, "table": "Rustboro_Fountain", "count": 2, "tile": 960, "bytes": 0x80}]},
	"Dewford": {"rows": [
		{"every": 8, "at": 0, "div": 8, "table": "Dewford_Flag", "count": 4, "tile": 682, "bytes": 0xC0}]},
	"Slateport": {"rows": [
		{"every": 16, "at": 0, "div": 16, "table": "Slateport_Balloons", "count": 4, "tile": 736, "bytes": 0x80}]},
	"Mauville": {"sync": true, "rows": [
		{"every": 8, "div": 8, "table": "Mauville_Flower1", "count": 12, "below": 12, "dests": "Mauville_Flower1_VDests", "bytes": 0x80},
		{"every": 8, "div": 8, "table": "Mauville_Flower2", "count": 12, "below": 12, "dests": "Mauville_Flower2_VDests", "bytes": 0x80},
		{"every": 8, "div": 8, "table": "Mauville_Flower1_B", "count": 4, "from": 12, "dests": "Mauville_Flower1_VDests", "bytes": 0x80},
		{"every": 8, "div": 8, "table": "Mauville_Flower2_B", "count": 4, "from": 12, "dests": "Mauville_Flower2_VDests", "bytes": 0x80}]},
	"Lavaridge": {"rows": [
		{"every": 16, "at": 0, "div": 16, "table": "Lavaridge_Steam", "count": 4, "tile": 800, "bytes": 0x80},
		{"every": 16, "at": 0, "div": 16, "add": 2, "table": "Lavaridge_Steam", "count": 4, "tile": 804, "bytes": 0x80},
		{"every": 16, "at": 1, "div": 16, "table": "Lavaridge_Cave_Lava", "count": 4, "tile": 672, "bytes": 0x80}]},
	"EverGrande": {"rows": [
		{"every": 8, "div": 8, "table": "EverGrande_Flowers", "count": 8, "dests": "EverGrande_VDests", "bytes": 0x80}]},
	"Pacifidlog": {"sync": true, "rows": [
		{"every": 16, "at": 0, "div": 16, "table": "Pacifidlog_LogBridges", "count": 4, "tile": 976, "bytes": 0x3C0},
		{"every": 16, "at": 1, "div": 16, "table": "Pacifidlog_WaterCurrents", "count": 8, "tile": 1008, "bytes": 0x100}]},
	"Sootopolis": {"rows": [
		{"every": 16, "at": 0, "div": 16, "table": "Sootopolis_StormyWater", "count": 8, "tile": 752, "bytes": 0xC00}]},
	"BattleFrontierOutsideWest": {"rows": [
		{"every": 8, "at": 0, "div": 8, "table": "BattleFrontierOutsideWest_Flag", "count": 4, "tile": 730, "bytes": 0xC0}]},
	"BattleFrontierOutsideEast": {"rows": [
		{"every": 8, "at": 0, "div": 8, "table": "BattleFrontierOutsideEast_Flag", "count": 4, "tile": 730, "bytes": 0xC0}]},
	"Underwater": {"length": 128, "rows": [
		{"every": 16, "at": 0, "div": 16, "table": "Underwater_Seaweed", "count": 4, "tile": 1008, "bytes": 0x80}]},
	"SootopolisGym": {"length": 240, "rows": [
		{"every": 8, "at": 0, "div": 8, "table": "SootopolisGym_SideWaterfall", "count": 3, "tile": 1008, "bytes": 0x180},
		{"every": 8, "at": 0, "div": 8, "table": "SootopolisGym_FrontWaterfall", "count": 3, "tile": 976, "bytes": 0x280}]},
	"Cave": {"rows": [
		{"every": 16, "at": 1, "div": 16, "table": "Lavaridge_Cave_Lava", "count": 4, "tile": 928, "bytes": 0x80}]},
	"EliteFour": {"length": 128, "rows": [
		{"every": 64, "at": 1, "div": 64, "table": "EliteFour_FloorLight", "count": 2, "tile": 992, "bytes": 0x80},
		{"every": 8, "at": 1, "div": 8, "table": "EliteFour_WallLights", "count": 4, "tile": 1016, "bytes": 0x20}]},
	"MauvilleGym": {"rows": [
		{"every": 2, "at": 0, "div": 2, "table": "MauvilleGym_ElectricGates", "count": 2, "tile": 656, "bytes": 0x200}]},
	"BikeShop": {"rows": [
		{"every": 4, "at": 0, "div": 4, "table": "BikeShop_BlinkingLights", "count": 2, "tile": 1008, "bytes": 0x120}]},
	"BattlePyramid": {"rows": [
		{"every": 8, "at": 0, "div": 8, "table": "BattlePyramid_Torch", "count": 3, "tile": 663, "bytes": 0x100},
		{"every": 8, "at": 0, "div": 8, "table": "BattlePyramid_StatueShadow", "count": 3, "tile": 647, "bytes": 0x100}]},
	"BattleDome": {"rows": [
		{"every": 4, "at": 0, "div": 4, "table": "BattleDomeFloorLightPals", "count": 4, "palette": 8, "bytes": 0x20}]},
}

## Init routines and pointer tables by dump offset, from `nm -S` on each pret build.
const RUBY_SYMBOLS: Dictionary = {
	"callbacks": {0x72FE4: "General", 0x7300C: "Building", 0x73130: "Petalburg",
		0x73158: "Rustboro", 0x73184: "Dewford", 0x731AC: "Slateport", 0x731D4: "Mauville",
		0x73204: "Lavaridge", 0x73230: "Fallarbor", 0x73258: "Fortree", 0x73280: "Lilycove",
		0x732A8: "Mossdeep", 0x732D0: "EverGrande", 0x732FC: "Pacifidlog", 0x7332C: "Sootopolis",
		0x73354: "Underwater", 0x73378: "SootopolisGym", 0x7339C: "Cave", 0x733C8: "EliteFour",
		0x733EC: "MauvilleGym", 0x73418: "BikeShop"},
	"tables": {"General0": 0x376F3C, "General1": 0x378D4C, "General2": 0x37962C,
		"General3": 0x37994C, "General4": 0x379E5C, "InsideBuilding0": 0x37CA94,
		"Lavaridge0": 0x37A06C, "Lavaridge1_Cave0": 0x37C524, "Pacifidlog0": 0x37ABBC,
		"Pacifidlog1": 0x37B5DC, "Underwater0": 0x37ADCC, "Mauville0": 0x37BB3C,
		"Mauville1": 0x37BB6C, "Mauville2": 0x37BB9C, "Mauville3": 0x37BBAC,
		"MauvilleVDests0": 0x37BAFC, "MauvilleVDests1": 0x37BB1C, "Rustboro0": 0x37BFDC,
		"Rustboro1": 0x37C0FC, "RustboroVDests0": 0x37BFBC, "EverGrande0": 0x37C974,
		"EverGrandeVDests0": 0x37C954, "SootopolisGym0": 0x37D69C, "SootopolisGym1": 0x37D6A8,
		"EliteFour0": 0x37D864, "EliteFour1": 0x37D854, "MauvilleGym0": 0x37DC8C,
		"BikeShop0": 0x37DEF4},
}

const SAPPHIRE_SYMBOLS: Dictionary = {
	"callbacks": {0x72FE8: "General", 0x73010: "Building", 0x73134: "Petalburg",
		0x7315C: "Rustboro", 0x73188: "Dewford", 0x731B0: "Slateport", 0x731D8: "Mauville",
		0x73208: "Lavaridge", 0x73234: "Fallarbor", 0x7325C: "Fortree", 0x73284: "Lilycove",
		0x732AC: "Mossdeep", 0x732D4: "EverGrande", 0x73300: "Pacifidlog", 0x73330: "Sootopolis",
		0x73358: "Underwater", 0x7337C: "SootopolisGym", 0x733A0: "Cave", 0x733CC: "EliteFour",
		0x733F0: "MauvilleGym", 0x7341C: "BikeShop"},
	"tables": {"General0": 0x376ECC, "General1": 0x378CDC, "General2": 0x3795BC,
		"General3": 0x3798DC, "General4": 0x379DEC, "InsideBuilding0": 0x37CA24,
		"Lavaridge0": 0x379FFC, "Lavaridge1_Cave0": 0x37C4B4, "Pacifidlog0": 0x37AB4C,
		"Pacifidlog1": 0x37B56C, "Underwater0": 0x37AD5C, "Mauville0": 0x37BACC,
		"Mauville1": 0x37BAFC, "Mauville2": 0x37BB2C, "Mauville3": 0x37BB3C,
		"MauvilleVDests0": 0x37BA8C, "MauvilleVDests1": 0x37BAAC, "Rustboro0": 0x37BF6C,
		"Rustboro1": 0x37C08C, "RustboroVDests0": 0x37BF4C, "EverGrande0": 0x37C904,
		"EverGrandeVDests0": 0x37C8E4, "SootopolisGym0": 0x37D62C, "SootopolisGym1": 0x37D638,
		"EliteFour0": 0x37D7F4, "EliteFour1": 0x37D7E4, "MauvilleGym0": 0x37DC1C,
		"BikeShop0": 0x37DE84},
}

const FRLG_CALLBACKS: Dictionary = {0x70168: "General", 0x701EC: "CeladonCity",
	0x70264: "SilphCo", 0x702C8: "MtEmber", 0x70330: "VermilionGym", 0x70394: "CeladonGym"}

const FIRERED_SYMBOLS: Dictionary = {
	"callbacks": FRLG_CALLBACKS,
	"tables": {"General_Flower": 0x3A76D0, "General_Water_Current_LandWatersEdge": 0x3AA6C4,
		"General_SandWatersEdge": 0x3AB8E4, "CeladonCity_Fountain": 0x3ABE24,
		"SilphCo_Fountain": 0x3AC258, "MtEmber_Steam": 0x3AC668,
		"VermilionGym_MotorizedDoor": 0x3AC838, "CeladonGym_Flowers": 0x3AC9C0},
}

const LEAFGREEN_SYMBOLS: Dictionary = {
	"callbacks": FRLG_CALLBACKS,
	"tables": {"General_Flower": 0x3A76B0, "General_Water_Current_LandWatersEdge": 0x3AA6A4,
		"General_SandWatersEdge": 0x3AB8C4, "CeladonCity_Fountain": 0x3ABE04,
		"SilphCo_Fountain": 0x3AC238, "MtEmber_Steam": 0x3AC648,
		"VermilionGym_MotorizedDoor": 0x3AC818, "CeladonGym_Flowers": 0x3AC9A0},
}

const EMERALD_SYMBOLS: Dictionary = {
	"callbacks": {0xA0B20: "General", 0xA0B48: "Building", 0xA0C6C: "Petalburg",
		0xA0C94: "Rustboro", 0xA0CC0: "Dewford", 0xA0CEC: "Slateport", 0xA0D18: "Mauville",
		0xA0D48: "Lavaridge", 0xA0D74: "Fallarbor", 0xA0D9C: "Fortree", 0xA0DC4: "Lilycove",
		0xA0DEC: "Mossdeep", 0xA0E14: "EverGrande", 0xA0E40: "Pacifidlog", 0xA0E70: "Sootopolis",
		0xA0E9C: "BattleFrontierOutsideWest", 0xA0EC8: "BattleFrontierOutsideEast",
		0xA0EF4: "Underwater", 0xA0F18: "SootopolisGym", 0xA0F3C: "Cave", 0xA0F68: "EliteFour",
		0xA0F8C: "MauvilleGym", 0xA0FB8: "BikeShop", 0xA0FE4: "BattlePyramid", 0xA1010: "BattleDome"},
	"tables": {"General_Flower": 0x510764, "General_Water": 0x512574,
		"General_SandWaterEdge": 0x512E54, "General_Waterfall": 0x513174,
		"General_LandWaterEdge": 0x513684, "Building_TvTurnedOn": 0x516E3C,
		"Rustboro_WindyWater": 0x515824, "Rustboro_WindyWater_VDests": 0x515804,
		"Rustboro_Fountain": 0x515964, "Dewford_Flag": 0x5164FC, "Slateport_Balloons": 0x516D2C,
		"Mauville_Flower1": 0x515384, "Mauville_Flower2": 0x5153B4,
		"Mauville_Flower1_B": 0x5153E4, "Mauville_Flower2_B": 0x5153F4,
		"Mauville_Flower1_VDests": 0x515344, "Mauville_Flower2_VDests": 0x515364,
		"Lavaridge_Steam": 0x513894, "Lavaridge_Cave_Lava": 0x515D8C,
		"EverGrande_Flowers": 0x5161DC, "EverGrande_VDests": 0x5161BC,
		"Pacifidlog_LogBridges": 0x5143E4, "Pacifidlog_WaterCurrents": 0x514E04,
		"Sootopolis_StormyWater": 0x5202C4, "BattleFrontierOutsideWest_Flag": 0x51680C,
		"BattleFrontierOutsideEast_Flag": 0x516B1C, "Underwater_Seaweed": 0x5145F4,
		"SootopolisGym_SideWaterfall": 0x517A44, "SootopolisGym_FrontWaterfall": 0x517A50,
		"EliteFour_FloorLight": 0x517C0C, "EliteFour_WallLights": 0x517BFC,
		"MauvilleGym_ElectricGates": 0x518034, "BikeShop_BlinkingLights": 0x51829C,
		"BattlePyramid_Torch": 0x524864, "BattlePyramid_StatueShadow": 0x524870,
		"BattleDomeFloorLightPals": 0x52487C},
}


static func _engine(id: StringName) -> Array:
	match id:
		RomRegistry.RUBY:
			return [RS_ANIMS, RUBY_SYMBOLS]
		RomRegistry.SAPPHIRE:
			return [RS_ANIMS, SAPPHIRE_SYMBOLS]
		RomRegistry.FIRERED:
			return [FRLG_ANIMS, FIRERED_SYMBOLS]
		RomRegistry.LEAFGREEN:
			return [FRLG_ANIMS, LEAFGREEN_SYMBOLS]
		RomRegistry.EMERALD:
			return [EMERALD_ANIMS, EMERALD_SYMBOLS]
	return [{}, {}]


## Empty when the init routine is not one the source names.
static func read(rom: RomFile, callback_offset: int) -> Dictionary:
	var engine: Array = _engine(rom.id)
	var name: String = str(engine[1].get("callbacks", {}).get(callback_offset, ""))
	if name.is_empty():
		return {}
	var spec: Dictionary = engine[0][name]
	var frames: Dictionary = {}
	var rows: Array = []
	for source: Dictionary in spec.get("rows", []):
		for row: Dictionary in _unrolled(rom, engine[1]["tables"], source):
			if row.is_empty() or not _read_frames(rom, row, frames):
				return {}
			rows.append(row)
	return {"name": name, "length": int(spec.get("length", -1)),
		"sync": bool(spec.get("sync", false)), "rows": rows, "frames": frames}


static func _unrolled(rom: RomFile, tables: Dictionary, source: Dictionary) -> Array:
	var table: Array = _pointers(rom, int(tables[source["table"]]), int(source["count"]))
	var row: Dictionary = {"every": int(source["every"]), "div": int(source["div"]),
		"add": int(source.get("add", 0)), "below": int(source.get("below", 0x10000)),
		"from": int(source.get("from", 0)), "table": table, "bytes": int(source["bytes"])}
	if source.has("palette"):
		row["palette"] = int(source["palette"])
	if not source.has("dests"):
		row.merge({"at": int(source["at"]), "sub": 0, "tile": int(source.get("tile", -1))})
		return [row if not table.is_empty() else {}]
	var dests: Array = _pointers(rom, int(tables[source["dests"]]), int(source["every"]), VRAM_BASE)
	var out: Array = []
	for remainder: int in int(source["every"]):
		var tile: int = int(dests[remainder]) / TILE_BYTES if dests.size() == int(source["every"]) else -1
		var each: Dictionary = row.duplicate()
		each.merge({"at": remainder, "sub": remainder, "tile": tile})
		out.append(each if tile >= 0 and not table.is_empty() else {})
	return out


static func _pointers(rom: RomFile, at: int, count: int, base: int = Gen3Layout.ROM_BASE) -> Array:
	if not rom.in_bounds(at, count * 4):
		return []
	var out: Array = []
	for index: int in count:
		var offset: int = rom.u32le(at + index * 4) - base
		if offset < 0 or offset % 2 != 0 or offset >= Gen3Layout.ROM_WINDOW:
			return []
		out.append(offset)
	return out


static func _read_frames(rom: RomFile, row: Dictionary, frames: Dictionary) -> bool:
	for offset: int in row["table"]:
		var size: int = int(row["bytes"])
		var key: String = str(offset)
		if not rom.in_bounds(offset, size):
			return false
		if frames.has(key) and (frames[key]["bytes"] as Array).size() >= size:
			continue
		frames[key] = {"bytes": Array(rom.slice(offset, size))}
	return true


## The copies one routine call queues at counter `timer`, in cartridge order.
static func queue(animation: Dictionary, timer: int) -> Array:
	var out: Array = []
	for row: Dictionary in animation.get("rows", []):
		if timer % int(row["every"]) != int(row["at"]):
			continue
		var index: int = (timer / int(row["div"]) - int(row["sub"])) & 0xFFFF
		if index < int(row["from"]) or index >= int(row["below"]):
			continue
		var table: Array = row["table"]
		var frame: int = int(table[(index + int(row["add"])) % table.size()])
		var copy: Dictionary = {"frame": frame, "bytes": int(row["bytes"])}
		if row.has("palette"):
			copy["palette"] = int(row["palette"])
		else:
			copy["tile"] = int(row["tile"])
		out.append(copy)
	return out


## `InitTilesetAnimations`; an animation is empty for a tileset with no routine.
static func start(primary: Dictionary, secondary: Dictionary) -> Dictionary:
	var length: int = maxi(int(primary.get("length", 0)), 0)
	var state: Dictionary = {"animations": [primary, {}], "counters": [0, 0], "lengths": [length, 0]}
	restart_secondary(state, secondary)
	return state


## A connection's camera transition restarts only the secondary; `sync` keeps the primary's count.
static func restart_secondary(state: Dictionary, secondary: Dictionary) -> void:
	var own: int = int(secondary.get("length", 0))
	state["animations"][1] = secondary
	state["counters"][1] = int(state["counters"][0]) if bool(secondary.get("sync", false)) else 0
	state["lengths"][1] = int(state["lengths"][0]) if own < 0 else own


## One `UpdateTilesetAnimations`: both counters wrap at their length before either queues.
static func step(state: Dictionary) -> Array:
	var out: Array = []
	var counters: Array = state["counters"]
	for which: int in 2:
		counters[which] = int(counters[which]) + 1
		if int(counters[which]) >= int(state["lengths"][which]):
			counters[which] = 0
	for which: int in 2:
		out.append_array(queue(state["animations"][which], int(counters[which])))
	return out
