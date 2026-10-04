#!/bin/sh
# Sunshine "undo" command: bring back the monitors that were on, turn the virtual display off, lock.
. "$(dirname "$(readlink -f "$0")")/common.sh"
restore_real "$(cat "$STATE" 2>/dev/null)"
# Skip the lock when restore-monitors.sh was just used from the PC itself (flag less than a minute old)
recent=$(find "$NO_LOCK_FLAG" -newermt '-60 seconds' 2>/dev/null)
rm -f "$NO_LOCK_FLAG"
if [ -z "$recent" ] && [ "$LOCK_ON_STREAM_END" = 1 ]; then
    # Locking while KDE is still switching outputs left the lock screen undrawn in our tests: wait first
    sleep 4
    session_lock
fi
exit 0
