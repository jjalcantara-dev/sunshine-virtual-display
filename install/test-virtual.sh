#!/bin/sh
# Temporary test (lost on reboot): force a virtual 4K60 display on a free connector using debugfs.
# Usage: sudo install/test-virtual.sh HDMI-A-1
set -e
CONN="${1:?usage: $0 <connector, e.g. HDMI-A-1>}"
EDID="$(dirname "$(readlink -f "$0")")/../edid/sunshine-4k60.bin"
[ "$(id -u)" = 0 ] || { echo "Run as root" >&2; exit 1; }

matches=$(ls -d /sys/class/drm/card*-"$CONN" 2>/dev/null | wc -l)
[ "$matches" -ge 1 ] || { echo "Connector $CONN not found in /sys/class/drm" >&2; exit 1; }
[ "$matches" -eq 1 ] || { echo "$CONN exists on more than one GPU; pick a connector name that is unique" >&2; exit 1; }
sysfs=$(ls -d /sys/class/drm/card*-"$CONN")
[ "$(cat "$sysfs/status")" = disconnected ] || { echo "$CONN is not free (status: $(cat "$sysfs/status"))" >&2; exit 1; }
card=$(basename "$sysfs" | cut -d- -f1)
pci=$(basename "$(readlink -f "/sys/class/drm/$card/device")")

for d in /sys/kernel/debug/dri/*/"$CONN"; do
    parent=$(dirname "$d")
    if grep -q "$pci" "$parent/name" 2>/dev/null || [ "$(basename "$parent")" = "$pci" ]; then
        cat "$EDID" > "$d/edid_override"
        echo on > "$sysfs/status"
        udevadm trigger --subsystem-match=drm --action=change
        echo "Virtual display connected on $CONN ($card, $pci). Check it with: kscreen-doctor -o"
        exit 0
    fi
done
echo "Could not find $CONN of $pci in debugfs (is debugfs mounted?)" >&2
exit 1
