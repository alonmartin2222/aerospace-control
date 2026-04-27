#!/usr/bin/env bash
# aerospace-control uninstaller
#
# Removes the binary, LaunchAgent, and (optionally) config dir + marker blocks.
#
# Usage: ./uninstall.sh [--prefix=DIR] [--purge]
#   --prefix=DIR  prefix used at install (default: /usr/local)
#   --purge       also delete ~/.config/aerospace-control/ and remove
#                 the BEGIN/END GENERATED blocks from aerospace.toml

set -euo pipefail

PREFIX="/usr/local"
PURGE=0

for arg in "$@"; do
    case "$arg" in
        --prefix=*) PREFIX="${arg#*=}" ;;
        --purge)    PURGE=1 ;;
        -h|--help)
            sed -n '2,11p' "$0"
            exit 0 ;;
        *)
            echo "unknown arg: $arg" >&2
            exit 1 ;;
    esac
done

BIN_PATH="$PREFIX/bin/aerospace-control"
PLIST_LABEL="dev.aerospace-control.watcher"
PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_LABEL}.plist"
CONFIG_DIR="$HOME/.config/aerospace-control"
AEROSPACE_TOML="$HOME/.config/aerospace/aerospace.toml"

# ── Watcher ───────────────────────────────────────────────────────────────────
if [ -f "$PLIST_PATH" ]; then
    echo "→ Unloading watcher"
    launchctl unload "$PLIST_PATH" 2>/dev/null || true
    rm -f "$PLIST_PATH"
fi

# ── Binary ────────────────────────────────────────────────────────────────────
if [ -e "$BIN_PATH" ]; then
    echo "→ Removing $BIN_PATH"
    if [ -w "$BIN_PATH" ]; then rm -f "$BIN_PATH"
    else sudo rm -f "$BIN_PATH"
    fi
fi

# ── Optional purge ────────────────────────────────────────────────────────────
if [ "$PURGE" -eq 1 ]; then
    if [ -d "$CONFIG_DIR" ]; then
        echo "→ Removing $CONFIG_DIR"
        rm -rf "$CONFIG_DIR"
    fi
    if [ -f "$AEROSPACE_TOML" ]; then
        echo "→ Stripping generator markers from aerospace.toml"
        # Delete the entire BEGIN..END block (inclusive) for each marker
        for marker in workspace-bindings app-assignments; do
            sed -i.ac-bak "/# === BEGIN GENERATED: ${marker} ===/,/# === END GENERATED: ${marker} ===/d" \
                "$AEROSPACE_TOML"
        done
        rm -f "${AEROSPACE_TOML}.ac-bak"
    fi
fi

echo "✓ aerospace-control uninstalled."
