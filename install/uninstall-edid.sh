#!/bin/sh
# Undo install-edid.sh. Usage: sudo install/uninstall-edid.sh HDMI-A-1
set -e
CONN="${1:?usage: $0 <connector, e.g. HDMI-A-1>}"
PARAMS="drm.edid_firmware=$CONN:edid/sunshine-4k60.bin video=$CONN:e"
[ "$(id -u)" = 0 ] || { echo "Run as root" >&2; exit 1; }

if [ -f /etc/sdboot-manage.conf ] && grep -q "drm.edid_firmware=$CONN" /etc/sdboot-manage.conf; then
    sed -i "s| $PARAMS||" /etc/sdboot-manage.conf
    command -v sdboot-manage >/dev/null && sdboot-manage gen
else
    echo "Remove '$PARAMS' from your kernel parameters if you added them manually."
fi
rm -f /etc/mkinitcpio.conf.d/sunshine-edid.conf /etc/dracut.conf.d/sunshine-edid.conf
if command -v mkinitcpio >/dev/null; then
    mkinitcpio -P
elif command -v dracut >/dev/null; then
    dracut --regenerate-all --force
fi
rm -f /usr/lib/firmware/edid/sunshine-4k60.bin
echo "Done. Reboot to apply."
