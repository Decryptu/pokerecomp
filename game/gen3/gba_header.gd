class_name GbaHeader
extends RefCounted

## The Game Boy Advance header at $A0-$BF, [RomHeader]'s twin: what a dump
## claims to be, as pret's Makefiles write it with `gbafix`.

const TITLE: int = 0xA0
const TITLE_LENGTH: int = 12
const GAME_CODE: int = 0xAC
const MAKER_CODE: int = 0xB0
const VERSION: int = 0xBC
const COMPLEMENT: int = 0xBD

var title: String = ""
var game_code: String = ""
var maker_code: String = ""
var version: int = 0
var complement: int = 0


static func parse(rom: RomFile) -> GbaHeader:
	var header := GbaHeader.new()
	header.title = rom.slice(TITLE, TITLE_LENGTH).get_string_from_ascii()
	header.game_code = rom.slice(GAME_CODE, 4).get_string_from_ascii()
	header.maker_code = rom.slice(MAKER_CODE, 2).get_string_from_ascii()
	header.version = rom.u8(VERSION)
	header.complement = rom.u8(COMPLEMENT)
	return header


## What the BIOS checks before it boots: $A0-$BC summed, negated, less $19.
static func compute_complement(rom: RomFile) -> int:
	var sum: int = 0
	for offset: int in range(TITLE, COMPLEMENT):
		sum += rom.u8(offset)
	return (-sum - 0x19) & 0xFF


func describe() -> String:
	return "%s  code=%s  maker=%s  ver=%d" % [title, game_code, maker_code, version]
