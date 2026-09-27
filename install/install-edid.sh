#!/bin/sh
# Permanent install: EDID firmware + initramfs + kernel parameters.
# Usage: sudo install/install-edid.sh HDMI-A-1
set -e
CONN="${1:?usage: $0 <connector, e.g. HDMI-A-1>}"
SRC="$(dirname "$(readlink -f "$0")")/../edid/sunshine-4k60.bin"
FW=/usr/lib/firmware/edid/sunshine-4k60.bin
PARAMS="drm.edid_firmware=$CONN:edid/sunshine-4k60.bin video=$CONN:e"
[ "$(id -u)" = 0 ] || { echo "Run as root" >&2; exit 1; }

# The connector must exist exactly once (the kernel parameters apply to every GPU with that name)
matches=$(ls -d /sys/class/drm/card*-"$CONN" 2>/dev/null | wc -l)
[ "$matches" -ge 1 ] || { echo "Connector $CONN not found in /sys/class/drm" >&2; exit 1; }
[ "$matches" -eq 1 ] || { echo "$CONN exists on more than one GPU; pick a connector name that is unique" >&2; exit 1; }
status=$(cat /sys/class/drm/card*-"$CONN"/status)
if [ "$status" = connected ] && ! grep -q "drm.edid_firmware=$CONN" /proc/cmdline; then
    echo "A monitor is connected to $CONN. Use a free connector." >&2
    exit 1
fi

install -Dm644 "$SRC" "$FW"

# The GPU driver is usually loaded from the initramfs, so the EDID must be inside it
if command -v mkinitcpio >/dev/null; then
    mkdir -p /etc/mkinitcpio.conf.d
    echo "FILES+=($FW)" > /etc/mkinitcpio.conf.d/sunshine-edid.conf
    mkinitcpio -P
elif command -v dracut >/dev/null; then
    mkdir -p /etc/dracut.conf.d
    echo "install_items+=\" $FW \"" > /etc/dracut.conf.d/sunshine-edid.conf
    dracut --regenerate-all --force
else
    echo "WARNING: unknown initramfs tool; add $FW to your initramfs manually" >&2
fi

if [ -f /etc/sdboot-manage.conf ] && command -v sdboot-manage >/dev/null; then
    [ -e /etc/sdboot-manage.conf.bak-sunshine ] || cp /etc/sdboot-manage.conf /etc/sdboot-manage.conf.bak-sunshine
    if grep -q "drm.edid_firmware=$CONN" /etc/sdboot-manage.conf; then
        msg="Kernel parameters already present in /etc/sdboot-manage.conf."
    else
        sed -i "s|^LINUX_OPTIONS=\"\(.*\)\"|LINUX_OPTIONS=\"\1 $PARAMS\"|" /etc/sdboot-manage.conf
        msg="Kernel parameters added via sdboot-manage (backup: /etc/sdboot-manage.conf.bak-sunshine)."
    fi
    if grep -q "drm.edid_firmware=$CONN" /etc/sdboot-manage.conf; then
        sdboot-manage gen
        echo "$msg"
    else
        echo "Could not find a LINUX_OPTIONS=\"...\" line in /etc/sdboot-manage.conf. Add these parameters manually:" >&2
        echo "    $PARAMS" >&2
        exit 1
    fi
else
    echo "Add these kernel parameters with your bootloader and regenerate its config:"
    echo "    $PARAMS"
    echo "(GRUB: GRUB_CMDLINE_LINUX_DEFAULT in /etc/default/grub; Limine: KERNEL_CMDLINE in /etc/default/limine;"
    echo " systemd-boot: the options line of your entry or /etc/kernel/cmdline)"
fi
echo "Done. Reboot to apply."
