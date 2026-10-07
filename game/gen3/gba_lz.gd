class_name GbaLz
extends RefCounted

## GBA BIOS LZ77 (type 0x10): flag bits run high to low; references may overlap.
static func decompress(data: PackedByteArray, offset: int, limit: int = 0x8000) -> PackedByteArray:
	if offset < 0 or offset + 4 > data.size() or data[offset] != 0x10:
		return PackedByteArray()
	var size: int = data[offset + 1] | data[offset + 2] << 8 | data[offset + 3] << 16
	if size <= 0 or size > limit:
		return PackedByteArray()
	var out := PackedByteArray()
	var at: int = offset + 4
	while out.size() < size:
		if at >= data.size():
			return PackedByteArray()
		var flags: int = data[at]
		at += 1
		for bit: int in range(7, -1, -1):
			if out.size() == size:
				return out
			if at >= data.size():
				return PackedByteArray()
			if flags & (1 << bit) == 0:
				out.append(data[at])
				at += 1
			else:
				if at + 2 > data.size():
					return PackedByteArray()
				var length: int = (data[at] >> 4) + 3
				var distance: int = ((data[at] & 15) << 8 | data[at + 1]) + 1
				at += 2
				if distance > out.size() or out.size() + length > size:
					return PackedByteArray()
				for copied: int in length:
					out.append(out[out.size() - distance])
	return out
