#!/bin/sh
# Sunshine "do" command: switch to the virtual display only and unlock the session.
. "$(dirname "$(readlink -f "$0")")/common.sh"

active=$(enabled_real)
mkdir -p "$(dirname "$STATE")"
# If the previous stream did not end cleanly the monitors may already be off: keep the saved list then
[ -n "$active" ] && echo "$active" > "$STATE"

kscreen-doctor "output.$VIRTUAL.enable" "output.$VIRTUAL.mode.$VIRTUAL_MODE" "output.$VIRTUAL.scale.$VIRTUAL_SCALE" "output.$VIRTUAL.position.0,0"
sleep 1
if ! is_enabled "$VIRTUAL"; then
    # Never turn the real monitors off without a screen to stream; a non-zero exit makes Sunshine abort
    log "could not enable $VIRTUAL (is the EDID installed? see install/install-edid.sh)"
    exit 1
fi
for o in $active; do kscreen-doctor "output.$o.disable"; done
sleep 1
[ "$UNLOCK_ON_STREAM" = 1 ] && session_unlock
exit 0
