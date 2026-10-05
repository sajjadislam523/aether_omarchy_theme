# Compatibility and limitations

## Supported

- **Omarchy 4.x** on Arch Linux: Hyprland with Lua config (≥ 0.55),
  omarchy-shell (Quickshell, Qt 6.8+ for `QtQuick.Shapes` `PathRectangle`).
- Wayland only. Tested on Omarchy 4.0.4, Hyprland 0.56.2, Qt 6.11, a
  1366×768 laptop panel at scale 1.
- Bash (ble.sh). The Starship prompt works in any shell via `STARSHIP_CONFIG`;
  the installer only edits `~/.bashrc`.

Other desktops (GNOME, KDE, Sway, plain Hyprland without omarchy-shell) are
not supported: the bar, lock screen and notifications are omarchy-shell
plugins, and the theme format is Omarchy's.

## Multi-monitor and scaling

- The bar is drawn per monitor; the floating inset and radius are logical
  pixels, so they scale with `hyprctl` monitor scale.
- The workspace indicator shows workspaces 1–5 plus any other occupied ones up
  to 10, across all monitors (same as Omarchy's).
- Lock-screen layout is proportional to each screen's height; the clock is
  capped by width for ultrawide displays.
- Wallpapers are rendered at 3840×2160 and cropped to fill; re-render for
  unusual aspect ratios: `scripts/generate-wallpapers.py --width 5120 --height 1440`.

## Known limitations

| Limitation | Why |
|---|---|
| No drop shadow under the bar | Hyprland does not draw shadows for layer surfaces; drawing one in QML would enlarge the bar's reserved area. |
| Bar popups are not blurred | They are xdg-popups, not layer surfaces, so Hyprland layer rules do not apply. They use a 94% opaque surface instead. |
| Shell UI font is monospace | omarchy-shell uses the system monospace font (`omarchy font set`) for its glyph metrics. The lock screen uses Adwaita Sans. |
| Icon theme stays Yaru-blue | No complete outline (Lucide/Fluent-style) icon theme is in the official repos. The bar's icons are Nerd Font Material Design glyphs, which are consistent outline shapes. |
| "Reduced motion" is not detected | Qt/Quickshell expose no such preference on Linux. AETHER keeps motion short (≤180ms) and the only continuous motion is the lock screen's slow glow. |
| No Wi-Fi status on the lock screen | It would need polling `nmcli`; battery (UPower) and now-playing (MPRIS) are event-driven and shown instead. |
| Media artwork depends on the player | Players that do not publish `mpris:artUrl` show a note glyph. |
| GTK only | Chromium/Electron/Qt apps follow their own theming; Omarchy themes Chromium from `colors.toml`. |
