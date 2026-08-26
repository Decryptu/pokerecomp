#!/usr/bin/env bash
# Builds Godot export templates carrying only what a published build can reach.
#
# Stock templates are where a release's weight comes from: the engine is around
# nine tenths of a download and the game's own data is the rest. They ship every
# renderer and every importable format, and they ship unstripped, so most of
# that engine is code this project cannot execute.
#
# What may be removed is bounded by the mod API, not by the game. Mods are
# interpreted GDScript with the whole engine in front of them, and one of them
# draws the overworld in 3D, so `disable_3d` is not available here however
# little of 3D the game itself uses. What goes is what no mod can reach: the
# renderers the project never selects, hardware nobody has, and formats with no
# loader in front of them.
#
# Usage: tools/build_export_templates.sh <godot-source-dir> <out-dir> <target...>
# A target is one of the case labels below. The built templates are named the
# way Godot's template directory expects, so the out directory can be copied
# over an installed one and only the targets built here are replaced.
set -euo pipefail

src="${1:?godot source directory}"
out="${2:?output directory}"
shift 2
[ "$#" -gt 0 ] || { echo "no targets given" >&2; exit 2; }

# Audio, image and archive formats stay: a mod ships its own assets and loads
# them through these. What goes is 3D asset pipelines with no runtime loader,
# XR and camera hardware, and the video and network services nothing calls.
DISABLED_MODULES=(
  camera csg dds fbx gltf glslang gridmap hdr jolt_physics jsonrpc ktx
  lightmapper_rd meshoptimizer mobile_vr mono msdfgen noise objectdb_profiler
  openxr raycast theora tinyexr upnp vhacd visionos_xr webrtc webxr
  xatlas_unwrap
)

flags=(
  platform=PLACEHOLDER
  target=template_release
  production=yes
  optimize=size
  lto=full
  debug_symbols=no
  vulkan=no
  d3d12=no
  metal=no
  opengl3=yes
)
for m in "${DISABLED_MODULES[@]}"; do flags+=("module_${m}_enabled=no"); done

build() { # <platform> <extra scons args...>
  local platform="$1"; shift
  ( cd "$src" && scons "${flags[@]/platform=PLACEHOLDER/platform=$platform}" "$@" )
}

mkdir -p "$out"
src="$(cd "$src" && pwd)"
out="$(cd "$out" && pwd)"

for t in "$@"; do
  case "$t" in
    linux-x86_64)
      build linuxbsd arch=x86_64
      cp "$src/bin/godot.linuxbsd.template_release.x86_64" "$out/linux_release.x86_64" ;;
    linux-arm64)
      build linuxbsd arch=arm64
      cp "$src/bin/godot.linuxbsd.template_release.arm64" "$out/linux_release.arm64" ;;
    windows-x86_64)
      build windows arch=x86_64
      cp "$src/bin/godot.windows.template_release.x86_64.exe" "$out/windows_release_x86_64.exe" ;;
    windows-arm64)
      build windows arch=arm64
      cp "$src/bin/godot.windows.template_release.arm64.exe" "$out/windows_release_arm64.exe" ;;
    macos)
      build macos arch=arm64
      build macos arch=x86_64
      lipo -create \
        "$src/bin/godot.macos.template_release.arm64" \
        "$src/bin/godot.macos.template_release.x86_64" \
        -output "$src/bin/godot.macos.template_release.universal"
      rm -rf "$src/bin/macos_template.app"
      cp -R "$src/misc/dist/macos_template.app" "$src/bin/"
      mkdir -p "$src/bin/macos_template.app/Contents/MacOS"
      cp "$src/bin/godot.macos.template_release.universal" \
        "$src/bin/macos_template.app/Contents/MacOS/godot_macos_release.universal"
      chmod +x "$src/bin/macos_template.app/Contents/MacOS/godot_macos_release.universal"
      rm -f "$out/macos.zip"
      ( cd "$src/bin" && zip -qry "$out/macos.zip" macos_template.app ) ;;
    # Only the release device slice is rebuilt. The iOS template is an Xcode
    # project around several xcframeworks, and the export only ever reaches for
    # this one, so the workflow splices it into the stock archive rather than
    # reassembling a project this cannot test.
    ios)
      build ios arch=arm64 ios_simulator=no
      cp "$src/bin/libgodot.ios.template_release.arm64.a" "$out/libgodot.ios.release.a" ;;
    android)
      build android arch=arm64 generate_android_binary=no
      build android arch=arm32 generate_android_binary=no
      ( cd "$src/platform/android/java" && ./gradlew generateGodotTemplates )
      cp "$src/bin/android_release.apk" "$out/android_release.apk" ;;
    *) echo "unknown target: $t" >&2; exit 2 ;;
  esac
done

ls -lh "$out"
