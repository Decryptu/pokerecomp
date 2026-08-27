#!/bin/sh
# Runs one Godot invocation under a wall-clock cap and says what it was doing if
# the cap has to be used. Every workflow step that starts Godot goes through
# this; a bare invocation has no bound but the job's own timeout, which is
# twenty minutes of a paid runner after the work was finished and printed.
#
# GODOT_CAP  seconds before the run is killed. Default 900.
# GODOT_DONE a line the run prints when its work is complete. A run killed at
#            the cap having printed it is reported as a warning and passes: the
#            step asserts the work, not the engine's teardown. A run killed
#            without it fails, and so does one with no GODOT_DONE set.
#
# Usage: GODOT_DONE='---- All tests passed! ----' tools/ci_godot.sh godot --headless ...
set -u

cap="${GODOT_CAP:-900}"
done_line="${GODOT_DONE:-}"

work="$(mktemp -d)"
log="$work/output"
fifo="$work/stream"
mkfifo "$fifo"
trap 'rm -rf "$work"' EXIT

# The reader is started first: opening a fifo for writing blocks until there is
# one, and `tee` is what keeps the step's log live rather than arriving in one
# block when the run is over.
tee "$log" <"$fifo" &
reader=$!

"$@" >"$fifo" 2>&1 &
run=$!

# Every thread's stack, so a run that had to be killed is evidence rather than
# another attempt. Nothing here is installed by the workflow: gdb ships with the
# Linux images and sample with macOS, and /proc answers even when neither does.
diagnose() {
	stacks="$work/stacks"
	: >"$stacks"
	# `sudo -n` because Ubuntu's yama only lets a debugger attach to its own
	# child and the run is this watchdog's sibling. Passwordless on the images
	# and absent on nothing that matters: an attach that is refused leaves the
	# /proc lines below, which name the syscall every thread is parked in.
	if command -v gdb >/dev/null 2>&1; then
		gdb_run=gdb
		sudo -n true 2>/dev/null && gdb_run="sudo -n gdb"
		$gdb_run -p "$1" -batch -ex 'set pagination off' \
			-ex 'thread apply all bt' >>"$stacks" 2>&1
	elif command -v sample >/dev/null 2>&1; then
		sample "$1" 3 -f "$stacks" >/dev/null 2>&1
	fi
	for task in /proc/"$1"/task/*; do
		[ -d "$task" ] || continue
		echo "thread $(basename "$task") $(cat "$task/comm" 2>/dev/null)" \
			"state=$(awk '{print $3}' "$task/stat" 2>/dev/null)" \
			"wchan=$(cat "$task/wchan" 2>/dev/null)" >>"$stacks"
	done
	echo "----- $1 was still running -----"
	head -400 "$stacks"
	echo "----- end -----"
}

# The watchdog rather than the wait is what is bounded: POSIX `wait` takes no
# timeout, and polling `kill -0` on an unreaped child answers yes forever.
(
	slept=0
	while [ "$slept" -lt "$cap" ]; do
		sleep 1
		slept=$((slept + 1))
		kill -0 "$run" 2>/dev/null || exit 0
	done
	: >"$work/capped"
	diagnose "$run"
	kill -TERM "$run" 2>/dev/null
	sleep 5
	kill -KILL "$run" 2>/dev/null
) >&2 &
watchdog=$!

trap 'kill -TERM "$run" "$watchdog" 2>/dev/null; exit 143' TERM INT HUP

wait "$run"
status=$?
kill "$watchdog" 2>/dev/null
wait "$reader" 2>/dev/null

if [ ! -f "$work/capped" ]; then
	exit "$status"
fi

if [ -n "$done_line" ] && grep -qF "$done_line" "$log"; then
	echo "::warning::the run printed \"$done_line\" and then never exited;" \
		"it was killed after ${cap}s and the stacks above say where it was"
	exit 0
fi
echo "::error::the run reached its ${cap}s cap without finishing"
exit 124
