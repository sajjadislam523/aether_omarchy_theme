# Architecture

AETHER is built entirely from Omarchy's supported extension points, so an
`omarchy update` never overwrites it and nothing in `/usr/share/omarchy` is
modified.

```
~/aether/                                    (this repo)
├── theme/  ──symlink──▶ ~/.config/omarchy/themes/aether
│   ├── colors.toml        palette → Omarchy generates btop, browser, editors, alacritty/kitty/foot…
│   ├── shell.toml         omarchy-shell surfaces: bar, popups, notifications, menus, polkit, lock
│   ├── hyprland.lua       rounding, 1px gradient border, shadows, layer blur
│   ├── ghostty.conf       terminal palette
│   ├── icons.theme        Yaru-blue
│   ├── backgrounds/       desktop wallpaper(s)       ┐ rendered by
│   ├── lockscreen.png     lock wallpaper             │ scripts/generate-wallpapers.py
│   └── preview.png        theme-picker thumbnail     ┘
├── config/
│   ├── bar/aether.bar/            ┐
│   ├── workspaces/aether.workspaces│ symlinked into ~/.config/omarchy/plugins/
│   ├── media/aether.media/        │ and enabled as clones of the built-ins
│   ├── lockscreen/aether.lock/    ┘
│   ├── gtk/gtk-{3,4}.0.css        linked to ~/.config/gtk-*/gtk.css by the hook
│   ├── hooks/aether-theme-set     copied to ~/.config/omarchy/hooks/theme-set.d/aether
│   └── shell/                     aether-pre.bash, aether-post.bash, starship.toml
└── scripts/generate-wallpapers.py
```

## How each layer is applied

**Theme.** `omarchy theme set aether` copies `theme/` into
`~/.local/state/omarchy/current/theme/`, fills in any app config the theme
does not ship from Omarchy's templates, pushes `colors.toml`/`shell.toml` to
the running shell, reloads Hyprland, restarts terminals and sets the
wallpaper. Edits under `theme/` therefore need `omarchy theme set aether`.

**Shell plugins.** omarchy-shell (Quickshell) loads user plugins from
`~/.config/omarchy/plugins/<id>/`. Each AETHER plugin declares
`"omarchy": { "clonedFrom": "omarchy.<x>" }`, which makes the shell route the
built-in id (IPC targets, service lookups) to the clone once it is enabled,
and disables the original. Switching back is `omarchy plugin enable omarchy.<x>`.

- `aether.bar` — Omarchy's bar engine with the window inset from the screen
  edges (layer-shell margins), a rounded surface, hairline border and top
  sheen. Radius follows `decoration:rounding`.
- `aether.workspaces` — event-driven via `Quickshell.Hyprland`.
- `aether.media` — Omarchy's media `Service.qml` (player selection, OSD,
  IPC) unchanged, plus a new `BarWidget.qml`.
- `aether.lock` — Omarchy's lock `Service.qml` (PAM, fingerprint,
  `WlSessionLock`) unchanged, plus a new `LockView.qml`.

**Theme hook.** Omarchy runs `~/.config/omarchy/hooks/theme-set.d/*` after
every theme change. AETHER's hook links the GTK CSS and sets the cursor only
when the theme is `aether`, and undoes exactly that otherwise — so other
themes are never tinted cyan.

**Personal config edits.** Three small, marked edits that must live in
personal files because those load after the theme:

| File | Edit | Marker |
|---|---|---|
| `~/.config/hypr/looknfeel.lua` | personal `rounding` → 14 | `-- AETHER` / `-- AETHER-ORIG:` |
| `~/.config/hypr/hyprland.lua` | Ghostty window opacity → 1.0/0.97 (translucency moves to Ghostty) | same |
| `~/.config/ghostty/config` | `background-opacity = 0.94` | `# >>> AETHER >>>` block |
| `~/.bashrc` | source `aether-pre.bash` before Omarchy's rc, `aether-post.bash` at the end | `# >>> AETHER (pre/post) >>>` blocks |

`uninstall.sh` reverses these by marker, leaving your other edits alone.

## Runtime cost

No daemons or timers are added. Bar widgets react to Hyprland/MPRIS/UPower
signals. The only timers are the media panel's 1s position refresh (only
while the panel is open and playing) and the lock screen's opacity
"breathing" (only while the lock is visible). Blur is limited to the bar,
notifications and OSD via `ignore_alpha`.
