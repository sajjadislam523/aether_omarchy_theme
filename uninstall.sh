#!/bin/bash
# AETHER uninstaller: switches every component back and removes what
# install.sh added, using the markers it left. Your other edits are kept.
#
#   ./uninstall.sh            undo AETHER (packages stay installed)
#   ./uninstall.sh --purge    also delete ~/.local/share/blesh
#
# For a full file-level rollback to a snapshot instead: ./restore.sh [backup-dir]
set -uo pipefail

AETHER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$HOME/.local/state/aether"
PLUGINS_DIR="$HOME/.config/omarchy/plugins"
MARK="AETHER"
PURGE=0
[[ ${1:-} == --purge ]] && PURGE=1

say() { printf '\033[38;2;85;214;255m::\033[0m %s\n' "$*"; }

unlink_ours() {
  local dest="$1"
  if [[ -L $dest && $(readlink -f "$dest") == "$AETHER_DIR"/* ]]; then
    rm -f "$dest" && echo "   removed ${dest/#$HOME/~}"
  fi
}

# 1. Theme first: the theme-set hook then removes the GTK CSS links and
#    restores the cursor on its own.
say "Theme"
previous_theme="$(cat "$STATE_DIR/previous-theme" 2>/dev/null)"
current_theme="$(cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null)"
if [[ $current_theme == aether ]]; then
  omarchy theme set "${previous_theme:-ethereal}" >/dev/null 2>&1 && echo "   theme -> ${previous_theme:-ethereal}"
fi
rm -f "$HOME/.config/omarchy/hooks/theme-set.d/aether"
unlink_ours "$HOME/.config/omarchy/themes/aether"
# In case the hook could not run: drop our GTK links directly.
unlink_ours "$HOME/.config/gtk-4.0/gtk.css"
unlink_ours "$HOME/.config/gtk-3.0/gtk.css"

# 2. Shell plugins: switch each clone back to what it replaced.
say "Shell plugins"
omarchy plugin enable omarchy.lock >/dev/null 2>&1 && echo "   lock screen -> omarchy.lock"
omarchy plugin enable omarchy.workspaces >/dev/null 2>&1 && echo "   workspaces -> omarchy.workspaces"
if [[ $(cat "$STATE_DIR/replaced-media" 2>/dev/null) == spotify ]]; then
  shell_json="$HOME/.config/omarchy/shell.json"
  tmp="$(mktemp)"
  jq '.bar.layout |= with_entries(.value |= map(if .id == "aether.media" then {"id": "spotify", "type": "qml"} else . end))' \
    "$shell_json" >"$tmp" && mv "$tmp" "$shell_json" && echo "   media -> spotify module"
  omarchy plugin disable aether.media >/dev/null 2>&1
else
  omarchy plugin enable omarchy.media >/dev/null 2>&1 && echo "   media -> omarchy.media"
fi
previous_bar="$(cat "$STATE_DIR/previous-bar" 2>/dev/null)"
omarchy bar use "${previous_bar:-omarchy.bar}" >/dev/null 2>&1 && echo "   bar -> ${previous_bar:-omarchy.bar}"
for id in aether.bar aether.workspaces aether.media aether.lock; do
  unlink_ours "$PLUGINS_DIR/$id"
done
omarchy-shell shell rescanPlugins >/dev/null 2>&1

# 3. Marked edits in personal config files.
say "Config files"
for file in "$HOME/.config/hypr/looknfeel.lua" "$HOME/.config/hypr/hyprland.lua"; do
  [[ -f $file ]] && grep -q "$MARK" "$file" || continue
  sed -i -E "/-- $MARK\$/d; s/^(\s*)-- $MARK-ORIG: /\1/" "$file"
  echo "   restored ${file/#$HOME/~}"
done
for file in "$HOME/.config/ghostty/config" "$HOME/.bashrc"; do
  [[ -f $file ]] && grep -q ">>> $MARK" "$file" || continue
  sed -i "/^# >>> $MARK.*>>>\$/,/^# <<< $MARK.*<<<\$/d" "$file"
  # Drop the blank line install.sh put before an appended block.
  sed -i -e ':a' -e '/^\n*$/{$d;N;ba' -e '}' "$file"
  echo "   restored ${file/#$HOME/~}"
done
hyprctl reload >/dev/null 2>&1

if (( PURGE )); then
  rm -rf "$HOME/.local/share/blesh" && echo "   removed ~/.local/share/blesh"
fi
rm -rf "$STATE_DIR"

say "AETHER removed"
echo "   Still installed: capitaine-cursors (remove with: sudo pacman -Rns capitaine-cursors)$( ((PURGE)) || echo ", ble.sh in ~/.local/share/blesh (--purge removes it)")"
echo "   Backups remain in $AETHER_DIR/backup/"
echo "   Open a new terminal to drop the AETHER prompt."
