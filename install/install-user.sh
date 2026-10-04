#!/bin/sh
# Install the display scripts for the current user (no root needed).
set -e
REPO="$(dirname "$(readlink -f "$0")")/.."
DEST="${XDG_DATA_HOME:-$HOME/.local/share}/sunshine-virtual-display"
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/sunshine-virtual-display"
AUTOSTART="${XDG_CONFIG_HOME:-$HOME/.config}/autostart"

for cmd in kscreen-doctor loginctl python3 curl; do
    command -v "$cmd" >/dev/null || { echo "Missing dependency: $cmd (this project needs KDE Plasma 6 on Wayland)" >&2; exit 1; }
done

mkdir -p "$DEST" "$CONF_DIR" "$AUTOSTART"
install -m755 "$REPO"/scripts/*.sh "$DEST/"
[ -f "$CONF_DIR/config" ] || install -m644 "$REPO/examples/config" "$CONF_DIR/config"
sed "s|@DEST@|$DEST|" "$REPO/examples/sunshine-virtual-display-login.desktop" > "$AUTOSTART/sunshine-virtual-display-login.desktop"
install -m755 "$REPO/scripts/watchdog.py" "$DEST/"

# Watchdog: ends the Sunshine session (and brings the monitors back) when the client is gone
UNITS="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
mkdir -p "$UNITS"
sed "s|@DEST@|$DEST|" "$REPO/examples/sunshine-virtual-display-watchdog.service" > "$UNITS/sunshine-virtual-display-watchdog.service"
systemctl --user daemon-reload
systemctl --user enable --now sunshine-virtual-display-watchdog.service

# Emergency shortcut Meta+Shift+M: bring the monitors back without a working screen
APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
mkdir -p "$APPS"
sed "s|@DEST@|$DEST|" "$REPO/examples/sunshine-virtual-display-restore.desktop" > "$APPS/sunshine-virtual-display-restore.desktop"
if command -v kwriteconfig6 >/dev/null; then
    kwriteconfig6 --file kglobalshortcutsrc --group services --group sunshine-virtual-display-restore.desktop --key _launch "Meta+Shift+M"
fi

. "$CONF_DIR/config"
cat <<MSG
Installed scripts in $DEST
Edit your settings in $CONF_DIR/config

For the watchdog and the emergency shortcut to end the Sunshine session, put your Sunshine web UI
credentials in $CONF_DIR/credentials (chmod 600):
    SUNSHINE_USER=...
    SUNSHINE_PASSWORD=...
Log out and back in (or reboot) so KDE picks up the Meta+Shift+M shortcut.

Add this to ~/.config/sunshine/sunshine.conf and restart Sunshine:

output_name = ${VIRTUAL:-HDMI-A-1}
global_prep_cmd = [{"do":"$DEST/stream-start.sh","undo":"$DEST/stream-stop.sh"}]
MSG
