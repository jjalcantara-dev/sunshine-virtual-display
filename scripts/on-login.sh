#!/bin/sh
# Autostart at login: the virtual display is only for streaming, so turn it off and show every
# connected monitor (KDE may have enabled the virtual display for a monitor combination it had not
# seen before). Then lock the session, which is meant for auto-login setups.
. "$(dirname "$(readlink -f "$0")")/common.sh"
sleep 3
restore_real "$(connected_real)"
if [ "${LOCK_ON_LOGIN:-1}" = 1 ]; then
    sleep 2
    session_lock
fi
exit 0
