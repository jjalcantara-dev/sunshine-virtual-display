#!/bin/sh
# Shared settings and helpers for the stream/login scripts.
# Settings are read from $XDG_CONFIG_HOME/sunshine-virtual-display/config (see examples/config).

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/sunshine-virtual-display/config"
[ -f "$CONFIG" ] && . "$CONFIG"

VIRTUAL="${VIRTUAL:-HDMI-A-1}"                 # connector forced on with the fake EDID
VIRTUAL_MODE="${VIRTUAL_MODE:-3840x2160@60}"
VIRTUAL_SCALE="${VIRTUAL_SCALE:-2}"
PRIMARY="${PRIMARY:-}"                         # preferred real monitor, e.g. DP-2 (optional)
PRIMARY_MODE="${PRIMARY_MODE:-}"               # its mode, e.g. 2560x1440@144 (optional)
UNLOCK_ON_STREAM="${UNLOCK_ON_STREAM:-1}"      # unlock the session when a stream starts
LOCK_ON_STREAM_END="${LOCK_ON_STREAM_END:-1}"  # lock it again when the stream ends
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/sunshine-virtual-display/active-outputs"

log() { echo "sunshine-virtual-display: $*" >&2; }

# Space-separated names of outputs matching a condition on KDE's JSON ("connected" or "enabled"),
# excluding the virtual display
outputs_where() {
    kscreen-doctor -j | python3 -c '
import json, sys
field, virtual = sys.argv[1], sys.argv[2]
print(" ".join(o["name"] for o in json.load(sys.stdin)["outputs"] if o.get(field) and o["name"] != virtual))
' "$1" "$VIRTUAL"
}

# Real monitors KDE currently reports as connected
connected_real() { outputs_where connected; }

# Real monitors currently enabled in KDE
enabled_real() { outputs_where enabled; }

# Whether a given output is currently enabled
is_enabled() {
    kscreen-doctor -j | python3 -c '
import json, sys
sys.exit(0 if any(o["name"] == sys.argv[1] and o["enabled"] for o in json.load(sys.stdin)["outputs"]) else 1)
' "$1"
}

# The user's graphical session. Sunshine runs these scripts from a systemd user service, which is not
# inside the session, so the session is looked up explicitly instead of relying on XDG_SESSION_ID.
graphical_session() {
    loginctl show-user "$(id -un)" -p Display --value 2>/dev/null
}

session_unlock() { loginctl unlock-session $(graphical_session); }
session_lock()   { loginctl lock-session $(graphical_session); }

# Turn real monitors back on and the virtual display off.
# Tries the given outputs, the preferred monitor and every connected monitor: a monitor in standby
# may stop reporting itself as connected, so it is tried anyway. The virtual display is only turned
# off if at least one real monitor ends up enabled, so the session never loses every screen.
restore_real() {
    candidates=""
    for o in $1 $PRIMARY $(connected_real); do
        case " $candidates " in *" $o "*) ;; *) candidates="$candidates $o" ;; esac
    done
    # In our tests KDE silently rejected enabling a monitor that would overlap the virtual display,
    # so move the virtual display out of the way first
    kscreen-doctor "output.$VIRTUAL.position.20000,0"
    for o in $candidates; do
        if [ "$o" = "$PRIMARY" ] && [ -n "$PRIMARY_MODE" ]; then
            kscreen-doctor "output.$o.enable" "output.$o.mode.$PRIMARY_MODE" "output.$o.position.0,0"
            # A mode that does not exist makes kscreen-doctor ignore the whole command: retry without it
            is_enabled "$o" || kscreen-doctor "output.$o.enable" "output.$o.position.0,0"
        else
            kscreen-doctor "output.$o.enable"
        fi
    done
    sleep 2
    active=$(enabled_real)
    if [ -z "$active" ]; then
        log "no real monitor could be enabled; keeping the virtual display on"
        return 0
    fi
    main=""
    for o in $active; do [ "$o" = "$PRIMARY" ] && main=$o; done
    [ -n "$main" ] || main=${active%% *}
    kscreen-doctor "output.$main.priority.1"
    kscreen-doctor "output.$VIRTUAL.disable"
}
