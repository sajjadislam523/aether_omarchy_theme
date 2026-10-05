#!/bin/bash
# AETHER restore: put files and settings back from a backup made by backup.sh.
#
# Usage: ./restore.sh [backup-dir]     (default: backup/latest)
# Does not touch the shell plugins — uninstall.sh switches those back.
set -euo pipefail

AETHER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${1:-$AETHER_DIR/backup/latest}"
SRC="$(cd "$SRC" && pwd -P)"

[[ -d $SRC/files && -f $SRC/state.env ]] || { echo "Not an AETHER backup: $SRC" >&2; exit 1; }

echo "Restoring from $SRC"

# Files that existed before AETHER: copy back (replacing AETHER symlinks).
while IFS= read -r -d '' file; do
  rel="${file#"$SRC/files/"}"
  mkdir -p "$HOME/$(dirname "$rel")"
  rm -f "$HOME/$rel"
  cp -a "$file" "$HOME/$rel"
  echo "  restored ~/$rel"
done < <(find "$SRC/files" -type f -print0)

# Files that did not exist before AETHER: remove only if AETHER created them.
while IFS= read -r rel; do
  [[ -n $rel ]] || continue
  target="$HOME/$rel"
  if [[ -L $target && $(readlink -f "$target") == "$AETHER_DIR"/* ]] || grep -qs 'AETHER' "$target"; then
    rm -f "$target"
    echo "  removed ~/$rel"
  fi
done <"$SRC/absent.txt"

# gsettings values.
if command -v gsettings >/dev/null; then
  while IFS='=' read -r key value; do
    [[ $key == gsettings.* && -n $value ]] || continue
    gsettings set org.gnome.desktop.interface "${key#gsettings.}" "$value" 2>/dev/null || true
  done <"$SRC/state.env"
fi

# Theme (re-applies Hyprland borders, terminal colors, etc).
theme="$(grep '^theme=' "$SRC/state.env" | cut -d= -f2-)"
if [[ -n $theme && $theme != aether ]] && command -v omarchy >/dev/null; then
  omarchy theme set "$theme" || true
fi

command -v hyprctl >/dev/null && hyprctl reload >/dev/null 2>&1 || true
echo "Done. Open a new terminal to pick up shell changes."
