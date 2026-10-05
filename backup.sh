#!/bin/bash
# AETHER backup: snapshot every file and setting AETHER touches, so restore.sh
# can put the desktop back exactly as it was.
#
# Usage: ./backup.sh            -> prints the new backup directory
set -euo pipefail

AETHER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
DEST="$AETHER_DIR/backup/$STAMP"

# Paths relative to $HOME. Missing paths are recorded as absent so restore
# knows to delete what AETHER created there.
FILES=(
  .bashrc
  .config/starship.toml
  .config/ghostty/config
  .config/hypr/hyprland.lua
  .config/hypr/looknfeel.lua
  .config/omarchy/shell.json
  .config/omarchy/shell.toml
  .config/gtk-3.0/gtk.css
  .config/gtk-4.0/gtk.css
  .config/omarchy/hooks/theme-set.d/aether
)

mkdir -p "$DEST/files"
: >"$DEST/absent.txt"

for rel in "${FILES[@]}"; do
  if [[ -e $HOME/$rel ]]; then
    mkdir -p "$DEST/files/$(dirname "$rel")"
    cp -aL "$HOME/$rel" "$DEST/files/$rel"
  else
    echo "$rel" >>"$DEST/absent.txt"
  fi
done

# Desktop state that lives outside files.
{
  echo "theme=$(cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null || true)"
  echo "background=$(readlink "$HOME/.local/state/omarchy/current/background" 2>/dev/null || true)"
  if command -v gsettings >/dev/null; then
    for key in gtk-theme icon-theme cursor-theme cursor-size color-scheme font-name; do
      echo "gsettings.$key=$(gsettings get org.gnome.desktop.interface "$key" 2>/dev/null || true)"
    done
  fi
} >"$DEST/state.env"

# Which shell plugins were active (bar choice, clones), for the record.
command -v omarchy-plugin-list >/dev/null && omarchy-plugin-list --json >"$DEST/plugins.json" 2>/dev/null || true

ln -nsf "$STAMP" "$AETHER_DIR/backup/latest"
echo "$DEST"
