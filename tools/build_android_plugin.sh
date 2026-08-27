#!/usr/bin/env bash
# Builds the Android plugin under addons/second_screen into the AAR the Android
# exporter links into its gradle build.
#
#   tools/build_android_plugin.sh
#
# Unlike the iOS plugin beside it, nothing here is compiled against the engine's
# own headers: an Android plugin is Kotlin against `godot-lib`, and that library
# is a compile-time dependency only, so one AAR serves both export targets. The
# library is fetched once into .references/ and cached there.
#
# Needs a JDK, gradle and the Android SDK. See DEVICES.md for where each comes
# from; ANDROID_HOME and JAVA_HOME override the defaults below.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN="$ROOT/addons/second_screen"
# The engine pin, which is the release the Android library is taken from. Bump
# with the pin in DEVICES.md.
GODOT_TAG="${GODOT_TAG:-4.8-dev4}"
GODOT_LIB_VERSION="${GODOT_LIB_VERSION:-4.8.dev4}"
# Built through a wrapper at a pinned Gradle rather than whatever gradle is on
# the machine: 9.6 removed an internal API the Android plugin below still uses,
# and a CI runner picking up 9.7 failed a release while this machine's 9.5
# passed. Bump this with AGP, and only together.
GRADLE_VERSION="${GRADLE_VERSION:-9.5}"
NAMESPACE="io.github.decryptu.pokerecomp.secondscreen"
PACKAGE_PATH="io/github/decryptu/pokerecomp/secondscreen"

export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
if [ -z "${JAVA_HOME:-}" ] && [ -x /usr/libexec/java_home ]; then
	JAVA_HOME="$(/usr/libexec/java_home -v 21 2>/dev/null || /usr/libexec/java_home)"
	export JAVA_HOME
fi

if [ ! -d "$ANDROID_HOME" ]; then
	echo "No Android SDK at $ANDROID_HOME. See DEVICES.md." >&2
	exit 1
fi

CACHE="$ROOT/.references/godot-android"
mkdir -p "$CACHE"
LIB="$CACHE/godot-lib.aar"
if [ ! -f "$LIB" ]; then
	URL="https://github.com/godotengine/godot-builds/releases/download/$GODOT_TAG/godot-lib.$GODOT_LIB_VERSION.template_release.aar"
	echo "Fetching $URL"
	curl -fsSL -o "$LIB" "$URL"
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/src/main/java/$PACKAGE_PATH"
cp "$PLUGIN"/kotlin/*.kt "$WORK/src/main/java/$PACKAGE_PATH/"
cp "$LIB" "$WORK/godot-lib.aar"

# The meta-data name is the contract: `org.godotengine.plugin.v2.<PluginName>`
# has to match getPluginName(), which is what the game asks Engine for.
cat > "$WORK/src/main/AndroidManifest.xml" <<MANIFEST
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application>
        <meta-data
            android:name="org.godotengine.plugin.v2.Gen2SecondScreenPanel"
            android:value="$NAMESPACE.Gen2SecondScreenPlugin" />
    </application>
</manifest>
MANIFEST

cat > "$WORK/settings.gradle" <<'SETTINGS'
pluginManagement {
	repositories { google(); mavenCentral(); gradlePluginPortal() }
}
dependencyResolutionManagement {
	repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
	repositories { google(); mavenCentral() }
}
rootProject.name = 'second_screen'
SETTINGS

cat > "$WORK/build.gradle" <<GRADLE
plugins {
	id 'com.android.library' version '8.13.0'
	id 'org.jetbrains.kotlin.android' version '2.1.20'
}
android {
	namespace '$NAMESPACE'
	compileSdk 34
	defaultConfig { minSdk = 24 }
	compileOptions {
		sourceCompatibility JavaVersion.VERSION_17
		targetCompatibility JavaVersion.VERSION_17
	}
}
kotlin { jvmToolchain(17) }
dependencies { compileOnly files('godot-lib.aar') }
GRADLE

# The wrapper is generated in an empty directory, because `gradle wrapper` in
# this one would configure the project first and hit the very incompatibility
# the wrapper exists to avoid.
WRAPPER="$(mktemp -d)"
trap 'rm -rf "$WORK" "$WRAPPER"' EXIT
# Gradle 9 refuses `wrapper` where there is no build at all, and an empty
# settings file is a build with nothing in it.
: > "$WRAPPER/settings.gradle"
( cd "$WRAPPER" && gradle --quiet --no-daemon wrapper --gradle-version "$GRADLE_VERSION" )
cp -R "$WRAPPER/gradle" "$WRAPPER/gradlew" "$WORK/"

( cd "$WORK" && ./gradlew --quiet --no-daemon assembleRelease )

mkdir -p "$PLUGIN/bin"
OUT="$PLUGIN/bin/second_screen.aar"
cp "$WORK/build/outputs/aar/second_screen-release.aar" "$OUT"
echo "  $(basename "$OUT")  $(du -h "$OUT" | awk '{print $1}')"
