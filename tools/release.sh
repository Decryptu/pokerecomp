#!/usr/bin/env bash
# The release, start to finish, and the gates in front of it.
#
#   tools/release.sh --gates          every check, changing nothing
#   tools/release.sh 0.1.19           the same checks, then the version bump
#
# The version lives in four files and `tests/unit/test_export_presets.gd` holds
# three of them to the fourth, so a hand edit that misses one fails a pull
# request. Everything below fails before a tag exists instead, because a tag
# costs seven builds and a quarter of an hour to tell you the same thing.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

fail() { echo "release: $1" >&2; exit 1; }

android_code() {
	local IFS=.
	# shellcheck disable=SC2086
	set -- $1
	echo $(( $1 * 10000 + $2 * 100 + $3 ))
}

notes_render() {
	sed '/^<!--/,/-->$/d' .github/release-notes.md | sed '/./,$!d'
}

# What `.github/workflows/release.yml` publishes as the body. An edit that
# rewrites the top section from the first `## Added` in the file lands inside
# the editing note, which names that heading in its own prose, and takes the
# closing marker with it: the range then runs to the end and the body is empty.
gate_notes() {
	local opens closes body
	opens=$(grep -c '^<!--' .github/release-notes.md || true)
	closes=$(grep -c -- '-->$' .github/release-notes.md || true)
	[ "$opens" = "1" ] || fail "release-notes.md opens $opens editing notes, expected 1"
	[ "$closes" = "$opens" ] || fail "release-notes.md leaves an editing note unclosed"
	body="$(notes_render)"
	[ -n "$body" ] || fail "release-notes.md renders to nothing"
	grep -q '^## ' <<<"$body" || fail "the rendered body carries no section"
	head -1 <<<"$body" | grep -q '^## ' \
		|| fail "the rendered body opens on prose rather than a section"
	# The escape, not the character, so this line does not match itself.
	! grep -q "$(printf '\u2014')" .github/release-notes.md \
		|| fail "release-notes.md carries an em dash"
	echo "  notes: $(grep -c '^## ' <<<"$body") sections, $(wc -l <<<"$body" | tr -d ' ') lines"
}

# The four places, against each other. `version/code` is
# `major * 10000 + minor * 100 + patch`, which is what
# `test_the_android_version_code_derives_from_the_app_version` holds it to: the
# installer refuses a code below the one already on the device.
gate_version() {
	local declared project code
	declared=$(sed -n 's/^const VERSION: String = "\(.*\)"$/\1/p' game/main/app_version.gd)
	[ -n "$declared" ] || fail "game/main/app_version.gd states no version"
	project=$(sed -n 's/^config\/version="\(.*\)"$/\1/p' project.godot)
	[ "$project" = "$declared" ] || fail "project.godot says $project, not $declared"
	for key in application/short_version application/version version/name; do
		while read -r value; do
			[ "$value" = "$declared" ] || fail "export_presets.cfg $key says $value, not $declared"
		done < <(sed -n "s|^${key}=\"\(.*\)\"$|\1|p" export_presets.cfg)
	done
	code=$(sed -n 's/^version\/code=\(.*\)$/\1/p' export_presets.cfg)
	[ "$code" = "$(android_code "$declared")" ] \
		|| fail "export_presets.cfg version/code is $code, not $(android_code "$declared")"
	echo "  version: $declared everywhere, android code $code"
}

# Comment lines under the three roots `tests/unit/test_source_budget.gd` counts,
# against the ceiling it records. The same number, reached without the engine,
# so a push cannot spend a CI run learning it.
gate_comments() {
	local ceiling total
	ceiling=$(sed -n 's/^const MAX_COMMENT_LINES: int = \([0-9]*\)$/\1/p' \
		tests/unit/test_source_budget.gd)
	total=$(find autoload game tools -name '*.gd' -print0 \
		| xargs -0 awk '{ s=$0; sub(/^[ \t]+/, "", s); if (substr(s, 1, 1) == "#") n++ }
			END { print n + 0 }')
	[ "$total" -le "$ceiling" ] \
		|| fail "$total comment lines under autoload, game, tools, ceiling $ceiling"
	echo "  comments: $total of $ceiling"
}

gate_tree() {
	git diff --quiet && git diff --cached --quiet \
		|| fail "the tree is dirty; commit or stash first"
}

gates() {
	echo "release gates:"
	gate_notes
	gate_version
	gate_comments
}

if [ "${1:-}" = "--gates" ]; then
	gates
	echo "release: gates pass"
	exit 0
fi

version="${1:-}"
[ -n "$version" ] || fail "usage: tools/release.sh --gates | tools/release.sh <version>"
grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$' <<<"$version" || fail "version must be X.Y.Z"
gate_tree
[ "$(git rev-parse --abbrev-ref HEAD)" != "main" ] \
	|| fail "branch first: main takes nothing but a pull request"

last="$(git describe --tags --abbrev=0 2>/dev/null || true)"
if [ -n "$last" ] && git diff --quiet "$last" -- .github/release-notes.md; then
	fail "release-notes.md is unchanged since $last; rewrite its top section first"
fi

sed -i.bak "s/^const VERSION: String = \".*\"$/const VERSION: String = \"$version\"/" \
	game/main/app_version.gd
sed -i.bak "s|^config/version=\".*\"$|config/version=\"$version\"|" project.godot
sed -i.bak \
	-e "s|^application/short_version=\".*\"$|application/short_version=\"$version\"|" \
	-e "s|^application/version=\".*\"$|application/version=\"$version\"|" \
	-e "s|^version/name=\".*\"$|version/name=\"$version\"|" \
	-e "s|^version/code=.*$|version/code=$(android_code "$version")|" \
	export_presets.cfg
rm -f game/main/app_version.gd.bak project.godot.bak export_presets.cfg.bak

gates
cat <<NEXT

release: $version written to the four places. What is left:

  git commit -am "Release $version"
  git push -u origin <branch> && gh pr create --title "Release $version" --body ...
  # merge it, then from main:
  git checkout main && git pull
  git tag v$version && git push origin v$version

The workflow builds the seven targets, publishes them with sha256sums.txt,
announces the release and opens the AltStore pull request itself. Do not run
tools/altstore_source.sh by hand and do not open a second one.
NEXT
