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
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/sunshine-virtual-display/active-outputs"

# Real monitors KDE currently reports as connected
connected_real() {
    kscreen-doctor -j | python3 -c 'import json,sys; print(" ".join(o["name"] for o in json.load(sys.stdin)["outputs"] if o.get("connected") and o["name"] != sys.argv[1]))' "$VIRTUAL"
}

# Real monitors currently enabled in KDE
enabled_real() {
    kscreen-doctor -j | python3 -c 'import json,sys; print(" ".join(o["name"] for o in json.load(sys.stdin)["outputs"] if o["enabled"] and o["name"] != sys.argv[1]))' "$VIRTUAL"
}

# Turn real monitors back on and the virtual display off.
# Tries the given outputs, the preferred monitor and every connected monitor: a monitor in standby
# may stop reporting itself as connected, so it is tried anyway. The virtual display is only turned
# off if at least one real monitor ends up enabled, so the session never loses every screen.
restore_real() {
    candidates=""
    for o in $1 $PRIMARY $(connected_real); do
        case " $candidates " in *" $o "*) ;; *) candidates="$candidates $o" ;; esac
    done
    # KDE silently rejects enabling a monitor that would overlap the virtual display, so move it away first
    kscreen-doctor "output.$VIRTUAL.position.20000,0"
    for o in $candidates; do
        if [ "$o" = "$PRIMARY" ] && [ -n "$PRIMARY_MODE" ]; then
            kscreen-doctor "output.$o.enable" "output.$o.mode.$PRIMARY_MODE" "output.$o.position.0,0"
        else
            kscreen-doctor "output.$o.enable"
        fi
    done
    sleep 2
    active=$(enabled_real)
    [ -n "$active" ] || return 0
    main=""
    for o in $active; do [ "$o" = "$PRIMARY" ] && main=$o; done
    [ -n "$main" ] || main=$(echo $active | cut -d' ' -f1)
    kscreen-doctor "output.$main.priority.1"
    kscreen-doctor "output.$VIRTUAL.disable"
}
