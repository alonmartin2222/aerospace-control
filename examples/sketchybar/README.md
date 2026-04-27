# Sketchybar integration example

Two snippets to drop into your `~/.config/sketchybar/sketchybarrc` and
`~/.config/aerospace/aerospace.toml` to wire aerospace-control into sketchybar.

## 1. sketchybarrc — workspace-icon arrays

Replace your existing hardcoded `SPACE_ICONS` / `SPACE_COLORS` with a marker
block. aerospace-control will rewrite the contents on every Apply:

```bash
# === BEGIN GENERATED: workspaces ===
SPACE_ICONS=("1" "2" "3" "4")
SPACE_COLORS=($MAUVE $BLUE $GREEN $PEACH)
# === END GENERATED: workspaces ===

# Then build the workspace items as before:
for i in "${!SPACE_ICONS[@]}"; do
  sid=$(($i+1))
  sketchybar --add item space.$sid left \
             --set space.$sid icon="${SPACE_ICONS[i]}" \
                              icon.highlight_color=$BASE \
                              ...
done
```

Enable in `~/.config/aerospace-control/config.json`:

```json
"sketchybar": { "enabled": true }
```

## 2. aerospace.toml — show the bar on the focused workspace's monitor

`exec-on-workspace-change` runs whenever AeroSpace's focused workspace changes.
The generated `sketchybar-map.sh` knows which display each workspace sits on —
source it and route the bar.

```toml
exec-on-workspace-change = [
  "/bin/bash", "-c", '''
    FOCUSED="$AEROSPACE_FOCUSED_WORKSPACE"
    MAP_FILE="$HOME/.config/aerospace-control/sketchybar-map.sh"
    if [[ -f "$MAP_FILE" ]]; then
      source "$MAP_FILE"
      DISPLAY=$(ws_to_sketchybar_display "$FOCUSED")
    else
      DISPLAY=1
    fi
    sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE="$FOCUSED"
    sketchybar --bar display="$DISPLAY"
  '''
]
```

## 3. (optional) Highlight script that survives workspace add/remove

If you have a `highlight_space.sh` with a hardcoded `case` like
`T) SID=1; COLOR=...`, you can replace its workspace handling with the generated
lookups so it never goes stale:

```bash
#!/bin/bash
WS_CFG="$HOME/.config/aerospace-control"
[ -f "$WS_CFG/workspaces.sh" ]       && source "$WS_CFG/workspaces.sh"
[ -f "$WS_CFG/workspace-colors.sh" ] && source "$WS_CFG/workspace-colors.sh"

FOCUSED="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused)}"

# 1-based index of the focused workspace in WS_ALL
SID=1
for i in "${!WS_ALL[@]}"; do
    [ "${WS_ALL[$i]}" = "$FOCUSED" ] && { SID=$((i + 1)); break; }
done
COLOR=$(ws_color "$FOCUSED")
LENGTH=${#WS_ALL[@]}

for i in $(seq 1 "$LENGTH"); do
    sketchybar --set space_ex.$i icon.highlight=off
done
sketchybar --set space_ex.$SID icon.highlight=on
```
