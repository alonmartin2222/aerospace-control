# aerospace-control

A visual control panel for
[AeroSpace](https://github.com/nikitabobko/AeroSpace). Drag-and-drop workspaces
between monitors, assign apps to workspaces, and create/edit/delete workspaces —
all synced back into your `aerospace.toml` keybindings, `on-window-detected`
rules, and (optionally) sketchybar.

Layouts are remembered per monitor combination, so switching between
laptop-only, dual-monitor, and triple-monitor setups restores your saved
arrangement automatically.

![tabs: Monitors / Apps / Workspaces](docs/screenshot.png)

## Features

- **Monitors tab** — drag colored workspace chips between detected monitors,
  with quick presets for laptop / 2-monitor / 3-monitor setups.
- **Apps tab** — running apps + already-assigned apps in one scrollable list,
  with a click-to-pick workspace badge per app.
- **Workspaces tab** — create / rename / recolor / reorder / delete workspaces.
  Deletes confirm before unassigning affected apps.
- **Per-signature memory** — each unique combination of monitor names gets its
  own saved layout. Plug in a different monitor and your previous layout for
  _that_ combo restores automatically.
- **Live screen-change watcher** — a small LaunchAgent re-applies the right
  saved layout whenever you plug or unplug a display.
- **Optional sketchybar integration** — off by default, but when enabled the app
  generates SPACE_ICONS / colors / display-routing for you.

## Requirements

- macOS 13+ (tested on Sonoma, Sequoia)
- [AeroSpace](https://github.com/nikitabobko/AeroSpace)
- Xcode Command Line Tools (`xcode-select --install`) for building
- (optional) [sketchybar](https://github.com/FelixKratz/SketchyBar)

## Install

### From source

```bash
git clone https://github.com/alonmartin2222/aerospace-control.git
cd aerospace-control
./install.sh                          # to /usr/local/bin (asks for sudo)
# or
./install.sh --prefix="$HOME/.local"  # user-local, no sudo
```

The installer will:

1. Compile the binary (`bin/aerospace-control`).
2. Install it to `<PREFIX>/bin/aerospace-control`.
3. Run `aerospace-control --setup` (creates `~/.config/aerospace-control/`,
   inserts marker blocks into your `aerospace.toml`).
4. Install and load a LaunchAgent at
   `~/Library/LaunchAgents/dev.aerospace-control.watcher.plist` that listens for
   screen changes and auto-restores the right layout (skip with `--no-watcher`).

After install, add this to `~/.config/aerospace/aerospace.toml` inside
`[mode.main.binding]`:

```toml
ctrl-alt-r = "exec-and-forget /usr/local/bin/aerospace-control"
```

And reload: `aerospace reload-config`.

### Uninstall

```bash
./uninstall.sh                # removes binary + LaunchAgent
./uninstall.sh --purge        # ALSO removes config dir + marker blocks
```

## Configuration

`~/.config/aerospace-control/config.json` is the single source of truth. The
defaults give you 4 generic workspaces (`1`, `2`, `3`, `4`) — open the GUI
(`ctrl-alt-r`) and customize.

```json
{
  "version": 1,
  "workspaces": [
    { "id": "T", "color": "mauve", "label": "Terminal" },
    { "id": "B", "color": "blue", "label": "Browser" }
  ],
  "apps": [
    {
      "app_id": "com.google.Chrome",
      "app_name": "Google Chrome",
      "workspace": "B"
    }
  ],
  "sketchybar": { "enabled": false }
}
```

### Available colors

`mauve`, `pink`, `blue`, `sapphire`, `lavender`, `teal`, `peach`, `green`,
`red`, `yellow`, `sky` (Catppuccin Mocha palette).

### What gets generated

When you click **Apply** in the GUI (or run `aerospace-control --setup`), the
following marker-wrapped sections are rewritten in-place:

| File                                         | Section              |
| -------------------------------------------- | -------------------- |
| `~/.config/aerospace/aerospace.toml`         | `workspace-bindings` |
| `~/.config/aerospace/aerospace.toml`         | `app-assignments`    |
| `~/.config/sketchybar/sketchybarrc` _opt-in_ | `workspaces`         |

Plus these _generated_ helper files (always written):

- `~/.config/aerospace-control/workspaces.sh` — `WS_ALL=(...)` for shell scripts
- `~/.config/aerospace-control/workspace-colors.sh` — `ws_color()` lookup
- `~/.config/aerospace-control/sketchybar-map.sh` — workspace → display index
- `~/.config/aerospace-control/reset-windows.sh` — moves existing windows to
  their assigned workspaces

Everything outside the BEGIN/END marker blocks in your `aerospace.toml` and
`sketchybarrc` is preserved verbatim.

## Sketchybar integration (optional)

If you use sketchybar:

1. Set `"sketchybar": { "enabled": true }` in `config.json`.
2. Add the marker block to your `sketchybarrc` where the SPACE_ICONS arrays
   should live:
   ```bash
   # === BEGIN GENERATED: workspaces ===
   SPACE_ICONS=("1" "2" "3" "4")
   SPACE_COLORS=($MAUVE $BLUE $GREEN $PEACH)
   # === END GENERATED: workspaces ===
   ```
3. To get per-workspace bar routing in `aerospace.toml`'s
   `exec-on-workspace-change`, source the generated map:
   ```bash
   MAP_FILE="$HOME/.config/aerospace-control/sketchybar-map.sh"
   if [[ -f "$MAP_FILE" ]]; then
     source "$MAP_FILE"
     SKETCHYBAR_DISPLAY=$(ws_to_sketchybar_display "$AEROSPACE_FOCUSED_WORKSPACE")
   fi
   ```

See `examples/sketchybar/` for a worked example.

## Modes

```
aerospace-control                # GUI (default)
aerospace-control --setup        # idempotent first-run setup
aerospace-control --auto         # restore saved layout for current monitors, exit
aerospace-control --watch        # long-running screen-change daemon
aerospace-control --version
```

## Keyboard shortcuts (in the GUI)

| Key                | Action                                     |
| ------------------ | ------------------------------------------ |
| `⏎`                | Apply                                      |
| `⎋`                | Cancel                                     |
| `⌘1` / `⌘2` / `⌘3` | Switch tabs (Monitors / Apps / Workspaces) |

## How it works

`aerospace-control` keeps `config.json` as the source of truth and rewrites
_marker-wrapped_ sections in your existing config files. Markers look like:

```toml
# === BEGIN GENERATED: workspace-bindings ===
... regenerated content ...
# === END GENERATED: workspace-bindings ===
```

If a marker block is missing, the app inserts it automatically the first time it
runs (`--setup` does this explicitly). If you uninstall, removing the block is
one `sed` command (or use `./uninstall.sh --purge`).

## License

MIT — see [LICENSE](LICENSE).
