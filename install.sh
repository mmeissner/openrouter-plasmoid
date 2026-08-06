#!/usr/bin/env bash
# Install or update the OpenRouter Monitor widget for the current user.
set -euo pipefail

ID="com.github.teodorgross.openrouter"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$ROOT/package"

if ! command -v kpackagetool6 >/dev/null 2>&1; then
    echo "kpackagetool6 not found - install the KF6 kpackage tools first." >&2
    exit 1
fi

# Compile the translation catalogues into the package (pure Python, no gettext)
if [ -d "$ROOT/translate/po" ]; then
    python3 "$ROOT/translate/i18n.py" build
fi

# Ship the OpenRouter mark as a theme icon so it also shows up in the widget
# explorer and in notifications
ICONDIR="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/scalable/apps"
mkdir -p "$ICONDIR"
install -m 644 "$SRC/contents/icons/openrouter.svg" "$ICONDIR/openrouter.svg"
gtk-update-icon-cache -q -t -f "${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor" 2>/dev/null || true

if kpackagetool6 --type Plasma/Applet --list 2>/dev/null | grep -qx "$ID"; then
    echo "Updating $ID …"
    kpackagetool6 --type Plasma/Applet --upgrade "$SRC"
else
    echo "Installing $ID …"
    kpackagetool6 --type Plasma/Applet --install "$SRC"
fi

cat <<'EOF'

Done. Plasma keeps QML in memory, so reload the shell:

  systemctl --user restart plasma-plasmashell.service

Then: right click the panel -> Add Widgets -> "OpenRouter Monitor".
EOF
