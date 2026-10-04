class_name Gen2PlayerNameChoices
extends RefCounted


const NEW_NAME: String = "NEW NAME"


static func options(data: GameData, gender: int, rival: bool = false) -> Array[String]:
	if data != null and data.generation == RomRegistry.GEN1:
		return data.gen1_default_names(rival)
	if Gen2WorldState.is_crystal_profile(data):
		if gender == Gen2SaveData.GENDER_FEMALE:
			return [NEW_NAME, "KRIS", "AMANDA", "JUANA", "JODI"]
		return [NEW_NAME, "CHRIS", "MAT", "ALLAN", "JON"]
	if data != null and data.id == &"silver":
		return [NEW_NAME, "SILVER", "KAMON", "OSCAR", "MAX"]
	return [NEW_NAME, "GOLD", "HIRO", "TAYLOR", "KARL"]


## `NameRival.DefaultName`: Gold's rival is SILVER and Silver's is GOLD, Crystal's SILVER.
static func default_rival_name(data: GameData) -> String:
	return "GOLD" if data != null and data.id == &"silver" else "SILVER"
