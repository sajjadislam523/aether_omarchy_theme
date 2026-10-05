# Installation

## 1. Get the repo

```bash
git clone <url> ~/aether        # any location works; paths are resolved at install time
cd ~/aether
```

## 2. Run the installer

```bash
./install.sh
```

What it does, in order:

1. Checks it is running on Omarchy with Hyprland and omarchy-shell up.
2. Checks dependencies and reports anything missing.
3. Runs `backup.sh` → `backup/<timestamp>/` (+ `backup/latest`).
4. Installs `capitaine-cursors` with pacman if missing (one password prompt)
   and ble.sh into `~/.local/share/blesh` if missing.
5. Renders the wallpapers if they are not there yet, links the theme, installs
   the theme-set hook.
6. Links and enables the shell plugins (bar, workspaces, media, lock).
   A pre-existing Spotify-only `spotify` bar module is swapped in place for
   `aether.media` (its file is kept).
7. Makes the marked Hyprland / Ghostty / `.bashrc` edits.
8. Applies the theme and reloads Hyprland, then lists every change.

Skip parts with `--no-packages`, `--no-shell`, `--no-lock`, `--no-bar`.

## 3. Check it

```bash
hyprctl configerrors                 # should print nothing
omarchy plugin list | grep aether    # four plugins, enabled
omarchy-shell lock preview           # look at the lock screen; click to dismiss
```

Open a new terminal: the prompt should be two lines (`┌─ ~` / `└─❯`) and
typing part of a previous command should show the rest dimmed — press → or
End to accept.

Then lock for real once (`Super + Ctrl + L`, or `omarchy system lock`) and
unlock with your password.

## Wallpapers without numpy

The wallpapers need `python-numpy` and `imagemagick`
(`omarchy pkg add python-numpy imagemagick`). Without them the theme still
works; put any images in `theme/backgrounds/` and a `theme/lockscreen.png`
yourself, then `omarchy theme set aether`.

## Updating

```bash
cd ~/aether && git pull
omarchy theme set aether      # theme files are copied on apply
omarchy restart shell         # plugin files are read at shell start
ble-update                    # optional: update ble.sh
```
