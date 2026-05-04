#!/usr/bin/env bash
# aerospace-control installer
#
# Compiles the Swift binary, installs it to a chosen prefix, sets up the
# screen-change watcher LaunchAgent, and runs --setup so the config dir and
# aerospace.toml markers are in place.
#
# Usage: ./install.sh [--prefix=DIR] [--no-watcher]
#   --prefix=DIR    install binary into DIR/bin (default: /usr/local)
#                   use --prefix="$HOME/.local" for a user-level install
#   --no-watcher    skip the LaunchAgent that auto-restores layout on
#                   monitor changes; you can launch the watcher manually later

set -euo pipefail

PREFIX="/usr/local"
INSTALL_WATCHER=1

for arg in "$@"; do
    case "$arg" in
        --prefix=*)    PREFIX="${arg#*=}" ;;
        --no-watcher)  INSTALL_WATCHER=0 ;;
        -h|--help)
            sed -n '2,15p' "$0"
            exit 0 ;;
        *)
            echo "unknown arg: $arg" >&2
            exit 1 ;;
    esac
done

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$PREFIX/bin"
BIN_PATH="$BIN_DIR/aerospace-control"
LAUNCHAGENTS="$HOME/Library/LaunchAgents"
PLIST_LABEL="dev.aerospace-control.watcher"
PLIST_PATH="$LAUNCHAGENTS/${PLIST_LABEL}.plist"
PLIST_TEMPLATE="$REPO_DIR/launchagent/${PLIST_LABEL}.plist.template"

# ── Pre-flight checks ─────────────────────────────────────────────────────────
command -v swiftc >/dev/null || {
    echo "error: swiftc not found. Install Xcode Command Line Tools:"
    echo "  xcode-select --install"
    exit 1
}

command -v aerospace >/dev/null || {
    echo "warning: aerospace not found in PATH."
    echo "  Install AeroSpace first: https://github.com/nikitabobko/AeroSpace"
    echo "  Continuing anyway — you can install it later."
}

# ── Build ─────────────────────────────────────────────────────────────────────
echo "→ Building..."
make -C "$REPO_DIR" release

# ── Install binary ────────────────────────────────────────────────────────────
echo "→ Installing binary to $BIN_PATH"
if [ -w "$PREFIX" ] || [ -w "$BIN_DIR" ] 2>/dev/null; then
    install -d "$BIN_DIR"
    install -m 0755 "$REPO_DIR/bin/aerospace-control" "$BIN_PATH"
    # Re-apply ad-hoc signature: `install` (and `cp`) can break the
    # linker-signed Mach-O signature, leaving Gatekeeper to SIGKILL the
    # binary on launch ("Taskgated Invalid Signature").
    codesign --force -s - "$BIN_PATH" 2>/dev/null || true
else
    sudo install -d "$BIN_DIR"
    sudo install -m 0755 "$REPO_DIR/bin/aerospace-control" "$BIN_PATH"
    sudo codesign --force -s - "$BIN_PATH" 2>/dev/null || true
fi

# ── First-run setup ───────────────────────────────────────────────────────────
echo "→ Running setup (creates config + inserts aerospace.toml markers)"
"$BIN_PATH" --setup

# ── Watcher LaunchAgent ───────────────────────────────────────────────────────
if [ "$INSTALL_WATCHER" -eq 1 ]; then
    echo "→ Installing screen-change watcher LaunchAgent"
    mkdir -p "$LAUNCHAGENTS"
    sed "s|__BINARY__|${BIN_PATH}|g" "$PLIST_TEMPLATE" > "$PLIST_PATH"
    # Reload if already loaded
    launchctl unload "$PLIST_PATH" 2>/dev/null || true
    launchctl load "$PLIST_PATH"
    echo "  Watcher loaded: $PLIST_PATH"
fi

# ── Final instructions ────────────────────────────────────────────────────────
cat <<EOF

────────────────────────────────────────────────────────────────────
✓ aerospace-control installed.

Next steps:

1. Reload aerospace:   aerospace reload-config
2. Press ctrl+alt+r to open the mapper.

If ~/.config/aerospace/aerospace.toml already existed, ctrl+alt+r was NOT
added automatically. Add this inside the [mode.main.binding] section:

       ctrl-alt-r = "exec-and-forget ${BIN_PATH}"

Optional: run aerospace-control --auto on aerospace startup so layouts
restore on login. Add to your top-level after-startup-command list:

       after-startup-command = [
         "exec-and-forget sleep 2 && ${BIN_PATH} --auto",
       ]

Sketchybar integration is OFF by default. Enable in the config:
    "sketchybar": { "enabled": true }
See README.md for the marker block sketchybarrc needs.
────────────────────────────────────────────────────────────────────
EOF
