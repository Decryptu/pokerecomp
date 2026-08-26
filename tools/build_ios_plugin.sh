#!/usr/bin/env bash
# Builds the iOS plugins under ios/plugins into the static libraries the iOS
# exporter links into the generated Xcode project.
#
#   tools/build_ios_plugin.sh
#
# The engine is linked, not bundled: a plugin compiles against the headers of
# the exact engine the export templates were built from, so GODOT_SOURCE must be
# a checkout at the pin in DEVICES.md. Two libraries are built per plugin
# because DEBUG_ENABLED changes what the engine's headers declare, and an
# export-debug build links the one that matches it.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_SOURCE="${GODOT_SOURCE:-$ROOT/.references/godot}"
MIN_IOS="${MIN_IOS:-14.0}"

if [ ! -f "$GODOT_SOURCE/core/object/object.h" ]; then
	echo "No engine headers at $GODOT_SOURCE. See DEVICES.md for the checkout." >&2
	exit 1
fi

SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
# The defines the engine's own iOS template is built with; anything that changes
# a header has to match or the plugin and the engine disagree about layout.
BASE_DEFINES=(-DIOS_ENABLED -DAPPLE_EMBEDDED_ENABLED -DUNIX_ENABLED
	-DCOREAUDIO_ENABLED -DTHREADS_ENABLED -DNDEBUG)

build_one() {
	local plugin_dir="$1" target="$2" out="$3"
	local defines=("${BASE_DEFINES[@]}")
	[ "$target" = "debug" ] && defines+=(-DDEBUG_ENABLED)

	local work
	work="$(mktemp -d)"
	local objects=()
	local source object
	for source in "$plugin_dir"*.cpp "$plugin_dir"*.mm; do
		[ -e "$source" ] || continue
		object="$work/$(basename "$source").o"
		local arc=()
		[ "${source##*.}" = "mm" ] && arc=(-fobjc-arc)
		# `"${arc[@]}"` on an empty array is an unbound variable under `set -u`
		# in bash 3.2, which is the bash a macOS runner has and this machine
		# does not. The `+` form expands to nothing instead.
		xcrun --sdk iphoneos clang++ -c "$source" -o "$object" \
			-arch arm64 -isysroot "$SDK" "-miphoneos-version-min=$MIN_IOS" \
			-std=gnu++17 -fno-exceptions -fblocks ${arc[@]+"${arc[@]}"} \
			"${defines[@]}" -I "$GODOT_SOURCE" -I "$GODOT_SOURCE/platform/ios" \
			-I "$plugin_dir" \
			-Wall -Werror=return-type -Wno-unused-parameter
		objects+=("$object")
	done
	xcrun --sdk iphoneos libtool -static -o "$out" "${objects[@]}"
	rm -rf "$work"
	echo "  $(basename "$out")  $(du -h "$out" | awk '{print $1}')"
}

for plugin_dir in "$ROOT"/ios/plugins/*/; do
	[ -d "$plugin_dir" ] || continue
	config="$(ls "$plugin_dir"*.gdip 2>/dev/null | head -1 || true)"
	[ -n "$config" ] || continue
	stem="$(basename "$config" .gdip)"
	echo "$(basename "$plugin_dir"):"
	build_one "$plugin_dir" debug "$plugin_dir$stem.debug.a"
	build_one "$plugin_dir" release "$plugin_dir$stem.release.a"
done
