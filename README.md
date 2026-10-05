# AETHER

**Obsidian glass · electric cyan · a little violet · floating surfaces.**

A desktop theme for Omarchy — [sajjadislam523/aether_omarchy_theme](https://github.com/sajjadislam523/aether_omarchy_theme)

AETHER is a complete dark desktop theme for [Omarchy](https://omarchy.org)
(Arch Linux + Hyprland + omarchy-shell). It aims for something calm, precise
and cinematic rather than neon: near-black surfaces, a single cyan accent,
violet used sparingly, hairline borders and soft depth.

| Component | What AETHER does | Implemented with |
|---|---|---|
| Palette | One token set used everywhere | `theme/colors.toml`, `theme/shell.toml` |
| Top bar | Floating, rounded glass bar with a hairline border and blur | `aether.bar` shell plugin + Hyprland layer rule |
| Workspaces | Cyan pill for the active workspace, dots (or `01 02 03`) for the rest | `aether.workspaces` shell plugin |
| Media | Any MPRIS player (Spotify, browsers, VLC, mpv…): compact now-playing, hover transport, glass panel with artwork and seekable progress | `aether.media` shell plugin |
| Windows | 14px rounding, 1px cyan→violet active border, soft wide shadows | `theme/hyprland.lua` |
| Lock screen | Thin clock, letter-spaced date, glass auth panel, dedicated darker wallpaper, slow atmospheric glow | `aether.lock` shell plugin (visual only — authentication is Omarchy's, unchanged) |
| Notifications, menus, popups, polkit | Glass cards, 1px `#263544` border, cyan selection | `theme/shell.toml` |
| GTK 3/4 + libadwaita | Near-black surfaces, cyan accent, hairline popovers | `config/gtk/*.css` (linked only while AETHER is active) |
| Terminal | Ghostty palette tuned for long sessions, 94% background opacity | `theme/ghostty.conf` |
| Shell | Bash autosuggestions + syntax highlighting (ble.sh), compact Starship prompt | `config/shell/` |
| Cursor | Capitaine Cursors (light) | `capitaine-cursors` package |
| Wallpapers | "Obsidian Horizon", desktop + lock variants, rendered locally | `scripts/generate-wallpapers.py` |

## Screenshots

Screenshots are not committed (they would capture whatever is on screen).
Take your own with `omarchy capture screenshot`, or preview the lock screen
safely with `omarchy-shell lock preview` (click to dismiss).

## Design tokens

| Token | Value | Use |
|---|---|---|
| base | `#070A0F` | desktop, deepest background |
| deep | `#0B1017` | bar, windows, menus |
| floating | `#101720` | popups, notifications, lock panel |
| elevated | `#151E29` | tooltips, raised controls |
| border | `#263544` | every hairline |
| text / secondary / muted | `#E8F0F7` / `#8A9AAA` / `#566574` | |
| cyan / bright cyan | `#55D6FF` / `#8BE7FF` | identity accent, active states |
| violet | `#9B8CFF` | secondary accent, sparingly |
| success / warning / error | `#58E6A5` / `#FFD166` / `#FF667D` | state only |

Radii follow Hyprland's `decoration:rounding` (14px) for windows, bar, popups,
notifications and menus; small controls use 8–12px. Motion is 120–180ms for
controls, ~180ms for panels, and slow (7–9s) only for the lock-screen glow.

## Requirements

- Omarchy 4.x (Hyprland ≥ 0.55 with Lua config, omarchy-shell / Quickshell)
- `jq`, `curl`, `tar`, `starship`, `ghostty` (all present on a stock Omarchy)
- `python-numpy` and `imagemagick` to render the wallpapers
- JetBrainsMono Nerd Font (Omarchy default) for terminal and bar glyphs
- Installed by `install.sh` if missing: `capitaine-cursors` (official repo, asks
  for your password once), [ble.sh](https://github.com/akinomyoga/ble.sh)
  (downloaded into `~/.local/share/blesh`, no root)

## Install

```bash
git clone https://github.com/sajjadislam523/aether_omarchy_theme.git ~/aether
cd ~/aether
./install.sh
```

The repo can live anywhere; `~/aether` is only a suggestion. Paths are
resolved at install time, and the files under `~/.config` point back into the
clone, so keep it after installing.

Options: `--no-packages`, `--no-shell`, `--no-lock`, `--no-bar`. The installer
backs up first, symlinks repo files into place, never overwrites a file it
did not create, and prints everything it changed. It is safe to re-run.

## Uninstall / restore

```bash
./uninstall.sh            # switch every component back, remove AETHER's edits
./uninstall.sh --purge    # …and delete ~/.local/share/blesh
./restore.sh [backup/…]   # file-level rollback to a snapshot (default: latest)
```

Backups live in `backup/<timestamp>/` (git-ignored): the files AETHER touches,
your previous theme, wallpaper and GNOME interface settings.

## Turning individual parts off

| Part | Off | On again |
|---|---|---|
| Whole theme | `omarchy theme set <other>` (GTK CSS and cursor revert automatically) | `omarchy theme set aether` |
| Floating bar | `omarchy bar reset` | `omarchy bar use aether.bar` |
| Workspaces | `omarchy plugin enable omarchy.workspaces` | `omarchy plugin enable aether.workspaces` |
| Media widget | `omarchy plugin enable omarchy.media` | `omarchy plugin enable aether.media` |
| Lock screen | `omarchy plugin enable omarchy.lock` | `omarchy plugin enable aether.lock` |
| Autosuggestions | `AETHER_NO_BLESH=1` in your environment, or delete the two `AETHER` blocks in `~/.bashrc` | re-run `./install.sh` |
| Prompt | `unset STARSHIP_CONFIG` (or remove the `AETHER (pre)` block) | re-run `./install.sh` |

## Configuration

- **Workspace style:** in `~/.config/omarchy/shell.json` set
  `{ "id": "aether.workspaces", "style": "numbers" }` for `01 02 03`.
- **Media title width:** `{ "id": "aether.media", "maxWidth": 200 }`.
- **Bar geometry:** `floatEdgeGap`, `floatSideGap`, `floatBorderWidth` near
  the top of `config/bar/aether.bar/Bar.qml`.
- **Colors:** edit `theme/colors.toml` / `theme/shell.toml`, then
  `omarchy theme set aether` (the theme is copied on apply, not live-linked).
- **Shell plugin edits** (`config/*/aether.*`) apply after `omarchy restart shell`.

## Media (MPRIS)

The widget reads MPRIS directly, so Spotify, Firefox/Chromium tabs, VLC and
mpv all work. Which player it follows: the one you picked in the panel, else
whatever is playing (Spotify first), else the one that played last, else
Spotify, else any player with a track. Bar: left-click opens the panel, right-click play/pause, middle-click
next, scroll prev/next; hovering reveals ◀ ❚❚ ▶. With several players the panel
lists them so you can pick one. With no player it shows a dim note and offers
"Open Spotify". Playback position is polled once a second only while the panel
is open and something is playing; everything else is event-driven.

Why not Omarchy's media service? A replacement bar (which `aether.bar` is)
hands third-party widgets a restricted API without access to built-in
services. The cloned media service is still loaded, so media keys, the OSD and
`omarchy-shell media …` IPC behave exactly as before.

## Lock screen

`aether.lock` replaces only `LockView.qml`. `Service.qml` — PAM password and
fingerprint flows, session lock, idle wake — is byte-for-byte Omarchy's, so
security behaviour is unchanged. Put a square image at `~/.face` to replace
the initial in the avatar. The dedicated wallpaper is `theme/lockscreen.png`;
other themes fall back to their (blurred) desktop wallpaper.

## Wallpapers

`scripts/generate-wallpapers.py [--width W --height H]` renders the desktop
(`theme/backgrounds/1-obsidian-horizon.png`), lock (`theme/lockscreen.png`) and
picker preview. Procedural, no downloaded artwork. Add more desktop images to
`theme/backgrounds/` and cycle with `omarchy theme bg next`.

## Updating

```bash
cd ~/aether && git pull
omarchy theme set aether      # theme/ is copied when applied
omarchy restart shell         # shell plugins are read at shell start
```

## Troubleshooting

See [docs/troubleshooting.md](docs/troubleshooting.md). Quick checks:
`hyprctl configerrors`, `journalctl --user -t omarchy-shell -n 50`,
`omarchy plugin list | grep aether`.

## Known limitations

See [docs/compatibility.md](docs/compatibility.md). In short: Omarchy-only;
the bar has no drop shadow (Hyprland does not shadow layer surfaces); Qt
popups cannot be blurred; the shell UI font stays the monospace system font;
the icon theme stays Yaru-blue (no outline icon theme in the official repos).

## Contributing

Issues and pull requests are welcome at
[sajjadislam523/aether_omarchy_theme](https://github.com/sajjadislam523/aether_omarchy_theme). Please test changes with
`./uninstall.sh && ./install.sh`, check `hyprctl configerrors` and the shell
log, and preview lock-screen changes with `omarchy-shell lock preview` before
locking for real. Do not commit screenshots of your desktop, the `backup/`
folder, or rendered wallpapers.

## License

MIT — see [LICENSE](LICENSE). Shell plugin files derived from Omarchy keep
Omarchy's MIT license.
