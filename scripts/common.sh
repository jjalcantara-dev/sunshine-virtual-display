#!/bin/sh
# Shared settings and helpers for the stream/login scripts.
# Settings are read from $XDG_CONFIG_HOME/sunshine-virtual-display/config (see examples/config).

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/sunshine-virtual-display/config"
[ -f "$CONFIG" ] && . "$CONFIG"

VIRTUAL="${VIRTUAL:-HDMI-A-1}"                 # connector forced on with the fake EDID
VIRTUAL_MODE="${VIRTUAL_MODE:-3840x2160@60}"  # fallback when the client's resolution is not available
VIRTUAL_SCALE="${VIRTUAL_SCALE:-auto}"         # auto: 2 for 4K, 1.5 for 1440p, 1 below
MATCH_CLIENT="${MATCH_CLIENT:-1}"              # use the resolution/fps requested by the Moonlight client
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

# Mode id of the virtual display for WIDTH HEIGHT FPS: exact resolution, closest refresh rate.
# Prints nothing if the virtual display has no mode with that resolution.
virtual_mode_id() {
    kscreen-doctor -j | python3 -c '
import json, sys
virtual, w, h, fps = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), float(sys.argv[4])
if fps > 1000:  # some clients report millihertz
    fps /= 1000
outs = [o for o in json.load(sys.stdin)["outputs"] if o["name"] == virtual]
modes = [m for o in outs for m in o["modes"] if m["size"]["width"] == w and m["size"]["height"] == h]
if modes:
    print(min(modes, key=lambda m: abs(m["refreshRate"] - fps))["id"])
' "$VIRTUAL" "$1" "$2" "$3" 2>/dev/null
}

# Pick the virtual display mode: the client's request (Sunshine exports SUNSHINE_CLIENT_WIDTH,
# SUNSHINE_CLIENT_HEIGHT and SUNSHINE_CLIENT_FPS to prep commands), else VIRTUAL_MODE.
# Prints "<mode id> <height>".
choose_virtual_mode() {
    if [ "$MATCH_CLIENT" = 1 ] && [ -n "$SUNSHINE_CLIENT_WIDTH" ] && [ -n "$SUNSHINE_CLIENT_HEIGHT" ]; then
        id=$(virtual_mode_id "$SUNSHINE_CLIENT_WIDTH" "$SUNSHINE_CLIENT_HEIGHT" "${SUNSHINE_CLIENT_FPS:-60}")
        if [ -n "$id" ]; then
            echo "$id $SUNSHINE_CLIENT_HEIGHT"
            return
        fi
        log "no ${SUNSHINE_CLIENT_WIDTH}x${SUNSHINE_CLIENT_HEIGHT} mode on $VIRTUAL, using $VIRTUAL_MODE (Moonlight will scale)"
    fi
    size=${VIRTUAL_MODE%@*}
    rate=${VIRTUAL_MODE#*@}
    [ "$rate" != "$VIRTUAL_MODE" ] || rate=60
    id=$(virtual_mode_id "${size%x*}" "${size#*x}" "$rate")
    [ -n "$id" ] && echo "$id ${size#*x}"
}

# Scale for a given height when VIRTUAL_SCALE=auto, so the desktop stays readable from the couch
scale_for_height() {
    if [ "$VIRTUAL_SCALE" != auto ]; then echo "$VIRTUAL_SCALE"
    elif [ "$1" -ge 2160 ]; then echo 2
    elif [ "$1" -ge 1440 ]; then echo 1.5
    else echo 1
    fi
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
