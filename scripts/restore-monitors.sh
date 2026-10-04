#!/bin/sh
# Emergency shortcut: bring the real monitors back right now (e.g. the TV froze or was turned off
# mid-stream), then end the Sunshine session without locking, since you are at the PC.
. "$(dirname "$(readlink -f "$0")")/common.sh"
mkdir -p "$(dirname "$NO_LOCK_FLAG")"
touch "$NO_LOCK_FLAG"
restore_real "$(cat "$STATE" 2>/dev/null)"
sunshine_close_app
exit 0
