#!/bin/sh
# Sunshine "do" command: switch to the virtual display only and unlock the session.
. "$(dirname "$(readlink -f "$0")")/common.sh"
mkdir -p "$(dirname "$STATE")"
enabled_real > "$STATE"
kscreen-doctor "output.$VIRTUAL.enable" "output.$VIRTUAL.mode.$VIRTUAL_MODE" "output.$VIRTUAL.scale.$VIRTUAL_SCALE" "output.$VIRTUAL.position.0,0"
sleep 1
for o in $(cat "$STATE"); do kscreen-doctor "output.$o.disable"; done
sleep 1
loginctl unlock-session
exit 0
