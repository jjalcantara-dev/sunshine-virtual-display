#!/bin/sh
# Sunshine "undo" command: bring back the monitors that were on, turn the virtual display off, lock.
. "$(dirname "$(readlink -f "$0")")/common.sh"
restore_real "$(cat "$STATE" 2>/dev/null)"
[ "$LOCK_ON_STREAM_END" = 1 ] && session_lock
exit 0
