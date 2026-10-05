# AETHER — context for Claude sessions

AETHER is a complete dark desktop theme for **Omarchy** (Arch Linux + Hyprland
with Lua config + omarchy-shell/Quickshell): an Omarchy theme plus four shell
plugins, GTK CSS, a bash prompt setup and generated wallpapers. Design
direction: obsidian glass, electric cyan `#55D6FF`, a little violet `#9B8CFF`,
hairline borders `#263544`. Calm and restrained, not neon. Full token table in
`README.md`. How the pieces fit together is in `docs/architecture.md`.

The local clone lives at `~/Projects/aether` and is **live**: `~/.config` symlinks
into it, so don't move or delete it without `./uninstall.sh` first.
Remote: https://github.com/sajjadislam523/aether_omarchy_theme (public).

## Layout

| Path | What | Applied by |
|---|---|---|
| `theme/` | Omarchy theme: `colors.toml`, `shell.toml`, `hyprland.lua`, `ghostty.conf`, `icons.theme` | **copied** on apply: `omarchy theme set aether` |
| `config/bar/aether.bar/` | floating bar (clone of Omarchy's `Bar.qml` + margins/rounded surface) | symlink → `omarchy restart shell` |
| `config/workspaces/aether.workspaces/` | workspace pill/dots | same |
| `config/media/aether.media/` | MPRIS media widget + panel (`BarWidget.qml`); `Service.qml` is Omarchy's, unchanged | same |
| `config/lockscreen/aether.lock/` | lock screen view (`LockView.qml`); `Service.qml` is Omarchy's, **unchanged** | same |
| `config/gtk/`, `config/hooks/aether-theme-set` | GTK CSS + cursor, linked only while the theme is `aether` | theme-set hook |
| `config/shell/` | `aether-pre.bash` (STARSHIP_CONFIG + ble.sh), `aether-post.bash` (ble faces, attach), `starship.toml` | new terminal |
| `scripts/generate-wallpapers.py` | procedural wallpapers → `theme/backgrounds/`, `theme/lockscreen.png`, `theme/preview.png` (gitignored) | `omarchy theme set aether` |
| `install.sh` / `uninstall.sh` / `backup.sh` / `restore.sh` | lifecycle; `backup/` is gitignored and holds the user's real configs | — |

## Applying and checking changes

- `theme/*` → `omarchy theme set aether` (the theme dir is copied to
  `~/.local/state/omarchy/current/theme/`; editing the repo alone does nothing).
- `config/*/aether.*` QML → `omarchy restart shell`. The shell's hot-reload
  watcher does **not** follow the plugin symlinks.
- Hyprland → `hyprctl reload && hyprctl configerrors` (must print nothing).
- Shell log: `journalctl --user -t omarchy-shell --since "-10s" | grep -v DEBUG`.
  Expected noise: `@plugins/bar/Bar.qml[1185]` handler-shadowed warning,
  portal registration warning, `Cannot open .../.face` (no avatar set).
- Lock screen: `omarchy-shell lock preview` then `omarchy-shell lock hidePreview`.
  **Never lock the session for real during testing**; the user must type the password.
- Visual checks: `grim -g "x,y wxh" <scratchpad>/file.png` and look at it.
- After changing install/uninstall: run `./uninstall.sh && ./install.sh` and
  diff the personal files against `backup/<oldest>/files/` (they must match byte-for-byte).

## Rules

- Load the `omarchy` skill before touching Hyprland/shell/theme config.
- **Never edit `/usr/share/omarchy/`** (package-owned). Reading it is how you learn APIs.
- `config/lockscreen/aether.lock/Service.qml` must stay identical to
  `/usr/share/omarchy/shell/plugins/lock/Service.qml` (PAM/fingerprint/session
  lock). Only `LockView.qml` is ours, and it must keep every property, signal
  and the `passwordInput` TextInput behaviour the service relies on.
- Edits to personal files are marked so uninstall can reverse them:
  `-- AETHER` / `-- AETHER-ORIG: <original line>` in Lua, `# >>> AETHER … >>>`
  blocks in `.bashrc` and Ghostty config. Keep install and uninstall symmetric.
- Never overwrite a file AETHER didn't create (`link()` in install.sh refuses).
- Don't commit `backup/`, rendered wallpapers, or anything personal. Scan before
  committing: `git grep -n -I -E "/home/|$(whoami)|token|secret"`.
- Commit locally when work is done; **ask before `git push`**. Add a line to the
  `## Unreleased` section of `CHANGELOG.md` for user-visible changes.

## Gotchas learned the hard way

- **Replacement-bar trust model:** `aether.bar` is a third-party bar, so
  third-party widgets inside it get a *service-less* API.
  `bar.shell.firstPartyServiceFor(...)` returns null for them. AETHER widgets
  read Quickshell services directly (`Quickshell.Services.Mpris`,
  `Quickshell.Hyprland`, `Quickshell.Services.UPower`). First-party Omarchy
  widgets in the bar still get proxies, so they keep working.
- Clones replace built-ins through `"omarchy": { "clonedFrom": "omarchy.<x>" }`
  plus `omarchy plugin enable <id>`. Switch back with
  `omarchy plugin enable omarchy.<x>`, or `omarchy bar use <id>` / `omarchy bar reset` for bars.
- Qt `formatTime(d, "h")` is 24-hour unless `AP` is in the same format string.
  The lock clock computes the 12-hour hour itself (`use24h` property toggles it).
- `decoration:rounding` drives `Style.cornerRadius` for the whole shell. The
  personal `~/.config/hypr/looknfeel.lua` loads *after* the theme, so a
  personal rounding wins (install.sh rewrites it with markers).
- Hyprland Lua uses snake_case rule fields (`hl.layer_rule({ …, blur = true, ignore_alpha = 0.3 })`).
- Relative workspace dispatch: `hyprctl dispatch 'hl.dsp.focus({ workspace = "e+1" })'`.
- MPRIS position isn't pushed. The media panel polls `positionChanged()` once a
  second only while open and playing. Keep everything else event-driven.
- Testing media silently: `ffmpeg -f lavfi -i anullsrc=r=44100:cl=stereo -t 240 -metadata title=… x.ogg`,
  then `mpv --ao=null --no-video --no-terminal x.ogg`. Stop it with
  `kill $(pgrep -x mpv)`. **Not** `pkill -f '<pattern>'`, which matches the
  calling shell's own command line and kills it.
- Typing into a demo terminal: `wtype`, only after checking
  `hyprctl activewindow` is the demo window. Keystrokes go to whatever is focused.
- Omarchy also ships an unrelated pacman package/app called `aether` (a
  wallpaper-to-theme generator). Different thing, same name.

## Screenshots (`docs/screenshots/`)

Take them on an empty workspace (7/8) with demo content only. Nothing personal:
no browser tab titles in the media widget or player list (use the silent mpv
track), no `ls -l` usernames (use `eza --icons`). The lock screen shows the
login name, which the user approved. Delete raw captures from the scratchpad afterwards.

## About the user's setup

- Shell is **bash** (ble.sh for autosuggestions, not zsh plugins). Terminal is
  Ghostty with **font size 8; never enlarge it**.
- Laptop panel 1366×768 at scale 1. Keep the bar uncrowded. The layout
  (clock centered, media at the start of the right section) was kept on purpose.
- Spotify opens with `Super + Shift + M` (Omarchy default binding). The user is
  happy with the generic MPRIS widget as is.
- Previous bar before AETHER: `<username>.bar` in `~/.config/omarchy/plugins/`
  (uninstall switches back to it). Old Spotify-only module:
  `~/.config/omarchy/bar/modules/spotify.qml`.

## Keeping up with Omarchy updates

The cloned files (`aether.bar/Bar.qml` and widgets, both `Service.qml` files)
can drift from upstream after `omarchy update`. To re-sync, diff against
`/usr/share/omarchy/shell/plugins/{bar,lock,services/media}/`, take upstream
changes, and re-apply AETHER's edits. In `Bar.qml` those are the `float*`
properties, the `margins {}` block and the `barSurface` rectangle in
`BarPanel`. Then restart the shell and re-check.
