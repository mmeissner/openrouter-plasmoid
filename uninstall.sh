#!/usr/bin/env bash
# Remove the OpenRouter Monitor widget for the current user.
set -euo pipefail

ID="com.github.teodorgross.openrouter"
ICON="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/scalable/apps/openrouter.svg"

if kpackagetool6 --type Plasma/Applet --list 2>/dev/null | grep -qx "$ID"; then
    kpackagetool6 --type Plasma/Applet --remove "$ID"
else
    echo "$ID is not installed."
fi

rm -f "$ICON"

cat <<'EOF'

Removed. Reload the shell so the widget disappears from the panel:

  systemctl --user restart plasma-plasmashell.service

Your API keys stay in ~/.config/plasma-org.kde.plasma.desktop-appletsrc until
the widget instance is deleted from the panel.
EOF
