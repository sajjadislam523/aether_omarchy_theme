# Changelog

## Unreleased

- Lock screen clock uses 12-hour time with a small AM/PM. Set `use24h: true`
  near the top of `config/lockscreen/aether.lock/LockView.qml` for 24-hour.

## 0.1.0 — 2026-10-05

Initial release.

- Omarchy theme `aether`: palette, shell surface tokens, Hyprland borders,
  rounding, shadows and layer blur, Ghostty palette.
- Shell plugins:
  - `aether.bar`: floating glass bar.
  - `aether.workspaces`: cyan pill for the active workspace, dots or numbers
    for the rest.
  - `aether.media`: MPRIS controller with a panel. It reads MPRIS directly,
    because a replacement bar cannot reach Omarchy's media service. It
    follows the pinned player, then whatever is playing (Spotify first), then
    the one that played last.
  - `aether.lock`: cinematic lock view with radial atmosphere glows.
    Omarchy's authentication service is unchanged.
- GTK 3/4 + libadwaita overrides and cursor, applied by a theme-set hook only
  while AETHER is active.
- Bash: ble.sh autosuggestions/highlighting and a compact Starship prompt.
  Works wherever the repo is cloned.
- Procedural "Obsidian Horizon" desktop and lock wallpapers.
- `install.sh`, `uninstall.sh`, `backup.sh`, `restore.sh`. The uninstall →
  reinstall round trip restores personal config files byte-for-byte.
