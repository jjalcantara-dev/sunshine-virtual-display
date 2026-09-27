#!/bin/sh
# Install the display scripts for the current user (no root needed).
set -e
REPO="$(dirname "$(readlink -f "$0")")/.."
DEST="${XDG_DATA_HOME:-$HOME/.local/share}/sunshine-virtual-display"
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/sunshine-virtual-display"
AUTOSTART="${XDG_CONFIG_HOME:-$HOME/.config}/autostart"

mkdir -p "$DEST" "$CONF_DIR" "$AUTOSTART"
install -m755 "$REPO"/scripts/*.sh "$DEST/"
[ -f "$CONF_DIR/config" ] || install -m644 "$REPO/examples/config" "$CONF_DIR/config"
sed "s|@DEST@|$DEST|" "$REPO/examples/sunshine-virtual-display-login.desktop" > "$AUTOSTART/sunshine-virtual-display-login.desktop"

. "$CONF_DIR/config"
cat <<MSG
Installed scripts in $DEST
Edit your settings in $CONF_DIR/config

Add this to ~/.config/sunshine/sunshine.conf and restart Sunshine:

output_name = ${VIRTUAL:-HDMI-A-1}
global_prep_cmd = [{"do":"$DEST/stream-start.sh","undo":"$DEST/stream-stop.sh"}]
MSG
