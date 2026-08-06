#!/usr/bin/env bash
# Probes which OpenRouter endpoints actually answer with the keys stored in
# the widget. The keys themselves are never printed - only status codes and
# the fields that came back.
set -uo pipefail

read_key() {
    python3 - "$1" <<'PY'
import sys, os, re
name = sys.argv[1]
p = os.path.expanduser("~/.config/plasma-org.kde.plasma.desktop-appletsrc")
cur, val = None, ""
for line in open(p, encoding="utf-8", errors="replace"):
    line = line.rstrip("\n")
    if line.startswith("["):
        cur = line
    elif "=" in line and cur and "teodorgross.openrouter" not in line:
        k, v = line.split("=", 1)
        if k.strip() == name and "Configuration][General]" in (cur or ""):
            val = v.strip()
print(val)
PY
}

probe() {
    local path="$1" key="$2" label="$3"
    if [ -z "$key" ]; then
        printf '%-28s %s\n' "$label" "skipped (no key configured)"
        return
    fi
    local body status
    body=$(curl -s -w $'\n%{http_code}' -H "Authorization: Bearer ${key}" \
        "https://openrouter.ai/api/v1${path}")
    status=$(printf '%s' "$body" | tail -n1)
    body=$(printf '%s' "$body" | sed '$d')
    printf '%-28s HTTP %s\n' "$label" "$status"
    printf '%s' "$body" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    print("    (no JSON response)"); raise SystemExit
if "error" in d:
    print("    error:", d["error"].get("message"))
    raise SystemExit
data = d.get("data")
if isinstance(data, list):
    print("    records:", len(data))
    if data:
        print("    fields:", ", ".join(sorted(data[0].keys())))
elif isinstance(data, dict):
    for k in sorted(data):
        print("   ", k, "=", data[k])
'
    echo
}

API_KEY="$(read_key apiKey)"
MGMT_KEY="$(read_key managementKey)"

describe_key() {
    if [ -n "$1" ]; then
        echo "set (${#1} characters)"
    else
        echo "NOT set"
    fi
}

echo "Keys read from the widget configuration:"
echo "  API key:        $(describe_key "$API_KEY")"
echo "  Management key: $(describe_key "$MGMT_KEY")"
echo

probe "/key"      "$API_KEY"  "/key with API key"
probe "/credits"  "$MGMT_KEY" "/credits with mgmt key"
probe "/credits"  "$API_KEY"  "/credits with API key"
probe "/activity" "$MGMT_KEY" "/activity with mgmt key"
