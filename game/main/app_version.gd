class_name PokeAppVersion
extends RefCounted

## Release metadata and export versions must agree.
const VERSION: String = "0.1.55"
const CHANNEL: String = "alpha"

const REPOSITORY: String = "https://github.com/Decryptu/pokerecomp"
const ISSUES: String = "https://github.com/Decryptu/pokerecomp/issues/new"
const DISCORD: String = "https://discord.gg/twkrHkHprk"


static func display() -> String:
	return "%s (%s)" % [VERSION, CHANNEL]
