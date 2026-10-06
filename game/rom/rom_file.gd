class_name RomFile
extends RefCounted

## A cartridge dump held in memory for an import. [method open_verified] refuses
## a dump [RomVerifier] has not accepted, since each layout's offsets belong to one
## dump. Reads are bounds-checked and return zero, so a corrupt stream ends as
## "did not decode" rather than a fault.

## Game Boy banks are 16 KiB; the bank helpers below are Game Boy only.
const BANK_SIZE: int = 0x4000

var path: String = ""
var sha1: String = ""
var id: StringName = &""

var _bytes: PackedByteArray = PackedByteArray()


## Null unless the dump verifies; [method RomVerifier.identify] says why.
static func open_verified(rom_path: String) -> RomFile:
	var info: Dictionary = RomVerifier.identify(rom_path)
	if info["status"] != RomVerifier.Status.OK:
		return null

	var file: FileAccess = FileAccess.open(rom_path, FileAccess.READ)
	if file == null:
		return null

	var rom := RomFile.new()
	rom.path = rom_path
	rom.sha1 = info["sha1"]
	rom.id = info["id"]
	rom._bytes = file.get_buffer(file.get_length())
	file.close()
	return rom


## For tests and tooling; production goes through [method open_verified].
static func from_bytes(data: PackedByteArray, game_id: StringName = &"") -> RomFile:
	var rom := RomFile.new()
	rom.id = game_id
	rom._bytes = data
	return rom


## A bank and CPU address as a dump offset. Only the low 14 bits of an address
## locate it within a bank, so the fixed and switchable windows both resolve.
static func linear(bank: int, address: int) -> int:
	return bank * BANK_SIZE + (address & 0x3FFF)


## The bank a dump offset falls in, for a pointer that carries no bank.
static func bank_of(offset: int) -> int:
	@warning_ignore("integer_division")
	return offset / BANK_SIZE


## Where a run with no stated length stops, as a Generation 1 `text_far` target.
static func bank_end(bank: int) -> int:
	return (bank + 1) * BANK_SIZE


func size() -> int:
	return _bytes.size()


func bytes() -> PackedByteArray:
	return _bytes


func in_bounds(offset: int, length: int = 1) -> bool:
	return offset >= 0 and length >= 0 and offset + length <= _bytes.size()


func u8(offset: int) -> int:
	return _bytes[offset] if in_bounds(offset) else 0


func s8(offset: int) -> int:
	return signed_byte(u8(offset))


static func signed_byte(value: int) -> int:
	return value - 0x100 if (value & 0x80) != 0 else value


func u16le(offset: int) -> int:
	if not in_bounds(offset, 2):
		return 0
	return _bytes[offset] | (_bytes[offset + 1] << 8)


func u32le(offset: int) -> int:
	if not in_bounds(offset, 4):
		return 0
	return u16le(offset) | (u16le(offset + 2) << 16)


func slice(offset: int, length: int) -> PackedByteArray:
	if not in_bounds(offset, length):
		return PackedByteArray()
	return _bytes.slice(offset, offset + length)


## A three-byte bank and little-endian address pointer, as { bank, address }.
func far_pointer(offset: int) -> Dictionary:
	return {"bank": u8(offset), "address": u16le(offset + 1)}
