#!/bin/bash
# AETHER installer for Omarchy (Hyprland + omarchy-shell).
#
#   ./install.sh                 install everything
#   ./install.sh --no-packages   skip the cursor theme and ble.sh downloads
#   ./install.sh --no-shell      leave ~/.bashrc and the prompt alone
#   ./install.sh --no-lock       keep Omarchy's stock lock screen
#   ./install.sh --no-bar        keep the current bar, workspaces and media widgets
#
# Safe to re-run. Every file it changes is backed up first (backup/<stamp>/),
# repo content is symlinked rather than copied, and nothing it does not own is
# overwritten. ./uninstall.sh reverses it.
set -euo pipefail

AETHER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$HOME/.local/state/aether"
PLUGINS_DIR="$HOME/.config/omarchy/plugins"
THEMES_DIR="$HOME/.config/omarchy/themes"
HOOK_DEST="$HOME/.config/omarchy/hooks/theme-set.d/aether"
MARK="AETHER"

DO_PACKAGES=1 DO_SHELL=1 DO_LOCK=1 DO_BAR=1
for arg in "$@"; do
  case "$arg" in
    --no-packages) DO_PACKAGES=0 ;;
    --no-shell) DO_SHELL=0 ;;
    --no-lock) DO_LOCK=0 ;;
    --no-bar) DO_BAR=0 ;;
    -h | --help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

CHANGES=()
NOTES=()
say() { printf '\033[38;2;85;214;255m::\033[0m %s\n' "$*"; }
changed() { CHANGES+=("$*"); }
note() { NOTES+=("$*"); }

# ------------------------------------------------------------------ 1. detect
say "Detecting environment"
command -v omarchy >/dev/null || { echo "AETHER targets Omarchy; 'omarchy' was not found." >&2; exit 1; }
command -v hyprctl >/dev/null && hyprctl version >/dev/null 2>&1 || { echo "Hyprland is not running." >&2; exit 1; }
omarchy-shell shell ping >/dev/null 2>&1 || { echo "omarchy-shell is not running." >&2; exit 1; }
echo "   Omarchy $(omarchy version 2>/dev/null), $(hyprctl version | head -1 | cut -d' ' -f1-2), shell: ${SHELL##*/}"

# ------------------------------------------------------------- 2. dependencies
say "Checking dependencies"
missing=()
for bin in jq gsettings starship ghostty curl tar; do
  command -v "$bin" >/dev/null || missing+=("$bin")
done
if (( ${#missing[@]} )); then
  echo "   Missing: ${missing[*]} (related components will be skipped)"
fi
fc-list : family | grep -i "JetBrainsMono Nerd Font" >/dev/null || note "JetBrainsMono Nerd Font not found: install with 'omarchy pkg add ttf-jetbrains-mono-nerd'"

# ------------------------------------------------------------------ 3. backup
say "Backing up current configuration"
BACKUP="$("$AETHER_DIR/backup.sh")"
echo "   $BACKUP"
mkdir -p "$STATE_DIR"
previous_theme="$(cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null || true)"
if [[ $previous_theme != aether && ! -f $STATE_DIR/previous-theme ]]; then
  echo "$previous_theme" >"$STATE_DIR/previous-theme"
fi
if [[ ! -f $STATE_DIR/previous-bar ]]; then
  jq -r '.bar.id // "omarchy.bar"' "$HOME/.config/omarchy/shell.json" >"$STATE_DIR/previous-bar" 2>/dev/null || echo omarchy.bar >"$STATE_DIR/previous-bar"
fi

# ---------------------------------------------------------------- 4. packages
# Returns 0 when newly installed, 1 when it already was, 2 on failure.
install_system_package() {
  local pkg="$1"
  pacman -Qq "$pkg" >/dev/null 2>&1 && { echo "   $pkg already installed"; return 1; }
  echo "   Installing $pkg (needs administrator rights)"
  if sudo -n true 2>/dev/null; then
    sudo pacman -S --needed --noconfirm "$pkg"
  elif [[ -t 0 ]]; then
    sudo pacman -S --needed "$pkg"
  else
    pkexec pacman -S --needed --noconfirm "$pkg"
  fi || return 2
}

if (( DO_PACKAGES )); then
  say "Packages"
  status=0
  install_system_package capitaine-cursors || status=$?
  case $status in
    0) changed "package: capitaine-cursors" ;;
    2) note "capitaine-cursors not installed; the cursor stays as it is" ;;
  esac

  # ble.sh is AUR-only; install the upstream nightly into ~/.local/share/blesh
  # (no root, no AUR helper). Update later with: ble-update
  if (( DO_SHELL )) && [[ ! -f $HOME/.local/share/blesh/ble.sh && ! -f /usr/share/blesh/ble.sh ]]; then
    echo "   Installing ble.sh into ~/.local/share/blesh"
    tmp="$(mktemp -d)"
    if curl -fsSL https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz | tar -xJ -C "$tmp"; then
      bash "$tmp"/ble-nightly*/ble.sh --install "$HOME/.local/share" >/dev/null
      changed "ble.sh installed to ~/.local/share/blesh"
    else
      note "ble.sh download failed; shell suggestions/highlighting skipped"
    fi
    rm -rf "$tmp"
  fi
fi

# ------------------------------------------------------------------- helpers
# link SRC DEST: symlink unless DEST is something else that we did not create.
link() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [[ -L $dest && $(readlink "$dest") == "$src" ]]; then
    return 0
  elif [[ -e $dest || -L $dest ]]; then
    echo "   ! $dest exists and is not AETHER's; leaving it" >&2
    return 1
  fi
  ln -s "$src" "$dest"
  changed "link: ${dest/#$HOME/~} -> ${src/#$HOME/~}"
}

shell_wait_for_plugin() {
  local id="$1"
  for _ in $(seq 40); do
    omarchy-plugin-list --json 2>/dev/null | jq -e --arg id "$id" 'any(.[]; .id == $id)' >/dev/null && return 0
    sleep 0.1
  done
  return 1
}

# ------------------------------------------------------------------- 5. theme
say "Theme"
# Wallpapers are generated (not stored in git). numpy + ImageMagick needed.
if [[ ! -f $AETHER_DIR/theme/backgrounds/1-obsidian-horizon.png || ! -f $AETHER_DIR/theme/lockscreen.png ]]; then
  if command -v magick >/dev/null && python3 -c 'import numpy' 2>/dev/null; then
    echo "   Rendering Obsidian Horizon wallpapers (about 20s)"
    python3 "$AETHER_DIR/scripts/generate-wallpapers.py" >/dev/null && changed "wallpapers rendered into theme/"
  else
    note "Wallpapers not rendered (needs python-numpy and imagemagick); see docs/installation.md"
  fi
fi
link "$AETHER_DIR/theme" "$THEMES_DIR/aether" || true

install -Dm755 /dev/null "$HOOK_DEST.tmp"
sed "s|__AETHER_DIR__|$AETHER_DIR|" "$AETHER_DIR/config/hooks/aether-theme-set" >"$HOOK_DEST.tmp"
if ! cmp -s "$HOOK_DEST.tmp" "$HOOK_DEST" 2>/dev/null; then
  mv "$HOOK_DEST.tmp" "$HOOK_DEST"
  changed "hook: ~/.config/omarchy/hooks/theme-set.d/aether (GTK CSS + cursor while AETHER is active)"
else
  rm -f "$HOOK_DEST.tmp"
fi

# --------------------------------------------------------------- 6. plugins
say "Shell plugins"
plugins=()
(( DO_BAR )) && plugins+=(bar/aether.bar workspaces/aether.workspaces media/aether.media)
(( DO_LOCK )) && plugins+=(lockscreen/aether.lock)
for rel in "${plugins[@]}"; do
  link "$AETHER_DIR/config/$rel" "$PLUGINS_DIR/${rel#*/}" || true
done
omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true

if (( DO_BAR )); then
  shell_wait_for_plugin aether.bar && omarchy bar use aether.bar >/dev/null && changed "bar: aether.bar"
  shell_wait_for_plugin aether.workspaces && omarchy plugin enable aether.workspaces >/dev/null && changed "bar widget: aether.workspaces"

  if shell_wait_for_plugin aether.media; then
    # A custom Spotify-only module from before AETHER is swapped in place;
    # its file stays in ~/.config/omarchy/bar/modules for easy return.
    if jq -e '[.bar.layout[][] | select(.id == "spotify")] | length > 0' "$HOME/.config/omarchy/shell.json" >/dev/null 2>&1; then
      tmp="$(mktemp)"
      jq '.bar.layout |= with_entries(.value |= map(if .id == "spotify" then {"id": "aether.media"} else . end))' \
        "$HOME/.config/omarchy/shell.json" >"$tmp" && mv "$tmp" "$HOME/.config/omarchy/shell.json"
      echo spotify >"$STATE_DIR/replaced-media"
    fi
    omarchy plugin enable aether.media >/dev/null 2>&1 || true
    changed "bar widget: aether.media (MPRIS)"
  fi
fi

if (( DO_LOCK )); then
  shell_wait_for_plugin aether.lock && omarchy plugin enable aether.lock >/dev/null && changed "lock screen: aether.lock (preview: omarchy-shell lock preview)"
fi

# ----------------------------------------------------------------- 7. hyprland
say "Hyprland"
looknfeel="$HOME/.config/hypr/looknfeel.lua"
if [[ -f $looknfeel ]] && ! grep -q "$MARK" "$looknfeel"; then
  # Personal files load after the theme, so a personal rounding would win
  # over AETHER's 14px. Comment it out (restored by uninstall).
  if grep -qE '^\s*rounding\s*=' "$looknfeel"; then
    sed -i -E "s|^(\s*)(rounding\s*=.*)$|\1-- $MARK-ORIG: \2\n\1rounding = 14, -- $MARK|" "$looknfeel"
    changed "~/.config/hypr/looknfeel.lua: rounding -> 14"
  fi
fi

hyprland_lua="$HOME/.config/hypr/hyprland.lua"
if [[ -f $hyprland_lua ]] && ! grep -q "$MARK" "$hyprland_lua"; then
  # Translucency moves from Hyprland (which fades the text too) to Ghostty's
  # own background-opacity, which keeps the text crisp.
  if grep -qE '^o\.window\("com\.mitchellh\.ghostty".*opacity' "$hyprland_lua"; then
    sed -i -E "s|^(o\.window\(\"com\.mitchellh\.ghostty\".*opacity.*)$|-- $MARK-ORIG: \1\no.window(\"com.mitchellh.ghostty\", { tag = \"-default-opacity\", opacity = \"1.0 0.97\" }) -- $MARK|" "$hyprland_lua"
    changed "~/.config/hypr/hyprland.lua: Ghostty window opacity -> 1.0 / 0.97"
  fi
fi

# ------------------------------------------------------------------ 8. ghostty
say "Ghostty"
ghostty_cfg="$HOME/.config/ghostty/config"
if [[ -f $ghostty_cfg ]] && ! grep -q "$MARK" "$ghostty_cfg"; then
  printf '\n# >>> %s >>>\nbackground-opacity = 0.94\n# <<< %s <<<\n' "$MARK" "$MARK" >>"$ghostty_cfg"
  changed "~/.config/ghostty/config: background-opacity 0.94"
fi

# -------------------------------------------------------------------- 9. shell
if (( DO_SHELL )); then
  say "Shell (${SHELL##*/})"
  bashrc="$HOME/.bashrc"
  if [[ ${SHELL##*/} != bash ]]; then
    note "Login shell is ${SHELL##*/}, not bash: shell step skipped (AETHER's prompt works anywhere with STARSHIP_CONFIG=$AETHER_DIR/config/shell/starship.toml)"
  elif ! grep -q ">>> $MARK" "$bashrc"; then
    pre="# >>> $MARK (pre) >>>\n[[ -f \"$AETHER_DIR/config/shell/aether-pre.bash\" ]] \&\& source \"$AETHER_DIR/config/shell/aether-pre.bash\"\n# <<< $MARK (pre) <<<"
    # Insert right before Omarchy's rc is sourced, so ble.sh loads first.
    if grep -q 'source "\$OMARCHY_PATH/default/bash/rc"' "$bashrc"; then
      sed -i "s|^source \"\$OMARCHY_PATH/default/bash/rc\"|$pre\nsource \"\$OMARCHY_PATH/default/bash/rc\"|" "$bashrc"
    else
      printf '%b\n' "$pre" >>"$bashrc"
    fi
    printf '\n# >>> %s (post) >>>\n[[ -f "%s/config/shell/aether-post.bash" ]] && source "%s/config/shell/aether-post.bash"\n# <<< %s (post) <<<\n' \
      "$MARK" "$AETHER_DIR" "$AETHER_DIR" "$MARK" >>"$bashrc"
    changed "~/.bashrc: AETHER prompt + ble.sh blocks"
  fi
fi

# --------------------------------------------------------------- 10. activate
say "Applying the AETHER theme"
omarchy theme set aether >/dev/null 2>&1 && changed "theme: aether (was ${previous_theme:-unknown})"
hyprctl reload >/dev/null 2>&1 || true
errors="$(hyprctl configerrors 2>/dev/null | grep -v '^\s*$' || true)"
[[ -z $errors ]] || note "Hyprland reported config errors:\n$errors"

# ------------------------------------------------------------------ 11. report
echo
say "Done"
for c in "${CHANGES[@]}"; do echo "   + $c"; done
for n in "${NOTES[@]}"; do printf '   ! %b\n' "$n"; done
echo
echo "   Backup:     $BACKUP"
echo "   Lock test:  omarchy-shell lock preview   (click to dismiss)"
echo "   Undo:       $AETHER_DIR/uninstall.sh"
echo "   Open a new terminal for the prompt and autosuggestions."
