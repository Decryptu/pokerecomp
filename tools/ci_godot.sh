#!/bin/sh
# Bound Godot work and allow a short teardown after a successful GUT verdict.
# GODOT_CAP and GODOT_GRACE are seconds; GODOT_DONE is an optional verdict line.
set -u
cap="${GODOT_CAP:-480}"
grace="${GODOT_GRACE:-3}"
done_line="${GODOT_DONE:-}"
work="$(mktemp -d)"
mkfifo "$work/stream"
trap 'rm -rf "$work"' EXIT
tee "$work/output" <"$work/stream" &
reader=$!
"$@" >"$work/stream" 2>&1 &
run=$!
(
	elapsed=0
	remaining=""
	while :; do
		sleep 1
		kill -0 "$run" 2>/dev/null || exit 0
		elapsed=$((elapsed + 1))
		if [ -n "$done_line" ] && [ -z "$remaining" ] && grep -qF -e "$done_line" "$work/output"; then
			remaining="$grace"
		fi
		if [ -n "$remaining" ]; then
			remaining=$((remaining - 1))
			[ "$remaining" -gt 0 ] || break
		fi
		[ "$elapsed" -lt "$cap" ] || break
	done
	: >"$work/capped"
	kill -TERM "$run" 2>/dev/null
	sleep 1
	kill -KILL "$run" 2>/dev/null
) &
watchdog=$!
trap 'kill -TERM "$run" "$watchdog" 2>/dev/null; exit 143' TERM INT HUP
wait "$run"
status=$?
kill "$watchdog" 2>/dev/null
wait "$reader" 2>/dev/null
if [ ! -f "$work/capped" ]; then
	exit "$status"
fi
if [ -n "$done_line" ] && grep -qF -e "$done_line" "$work/output"; then
	echo "::warning::Godot passed but exceeded ${grace}s teardown grace; stopped."
	exit 0
fi
echo "::error::Godot exceeded ${cap}s without finishing."
exit 124
