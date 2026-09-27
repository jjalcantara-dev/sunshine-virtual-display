#!/bin/sh
# Permanent install: EDID firmware + initramfs (mkinitcpio) + kernel parameters.
# Usage: sudo install/install-edid.sh HDMI-A-1
set -e
CONN="${1:?usage: $0 <connector, e.g. HDMI-A-1>}"
SRC="$(dirname "$(readlink -f "$0")")/../edid/sunshine-4k60.bin"
PARAMS="drm.edid_firmware=$CONN:edid/sunshine-4k60.bin video=$CONN:e"
[ "$(id -u)" = 0 ] || { echo "Run as root" >&2; exit 1; }

install -Dm644 "$SRC" /usr/lib/firmware/edid/sunshine-4k60.bin

# The GPU driver usually loads from the initramfs, so the EDID must be inside it
if command -v mkinitcpio >/dev/null; then
    mkdir -p /etc/mkinitcpio.conf.d
    echo 'FILES+=(/usr/lib/firmware/edid/sunshine-4k60.bin)' > /etc/mkinitcpio.conf.d/sunshine-edid.conf
    mkinitcpio -P
elif command -v dracut >/dev/null; then
    echo 'install_items+=" /usr/lib/firmware/edid/sunshine-4k60.bin "' > /etc/dracut.conf.d/sunshine-edid.conf
    dracut --regenerate-all --force
else
    echo "WARNING: unknown initramfs tool; add /usr/lib/firmware/edid/sunshine-4k60.bin to your initramfs manually" >&2
fi

if [ -f /etc/sdboot-manage.conf ] && command -v sdboot-manage >/dev/null; then
    cp -n /etc/sdboot-manage.conf /etc/sdboot-manage.conf.bak-sunshine
    if ! grep -q "drm.edid_firmware=$CONN" /etc/sdboot-manage.conf; then
        sed -i "s|^LINUX_OPTIONS=\"\(.*\)\"|LINUX_OPTIONS=\"\1 $PARAMS\"|" /etc/sdboot-manage.conf
    fi
    sdboot-manage gen
    echo "Kernel parameters added via sdboot-manage."
else
    echo "Add these kernel parameters with your bootloader (GRUB: GRUB_CMDLINE_LINUX_DEFAULT, then regenerate):"
    echo "    $PARAMS"
fi
echo "Done. Reboot to apply."
