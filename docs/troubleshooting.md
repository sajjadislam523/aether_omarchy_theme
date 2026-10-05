# Troubleshooting

## Something in the shell looks wrong or is missing

```bash
journalctl --user -t omarchy-shell -n 80 | grep -v DEBUG
omarchy restart shell
```

Edits to files under `config/*/aether.*` are behind a symlink, which the
shell's file watcher does not follow — restart the shell after editing.

To isolate a plugin, switch it back to the built-in:
`omarchy plugin enable omarchy.media` (or `.workspaces`, `.lock`),
`omarchy bar reset` for the bar.

## Hyprland errors after install

```bash
hyprctl reload; hyprctl configerrors
```

The theme's rules live in `~/.local/state/omarchy/current/theme/hyprland.lua`
(copied from `theme/hyprland.lua`). Switching to another theme removes them.

## Locked out / lock screen does not accept input

The authentication service is Omarchy's own, so this should not happen. If it
does, go back to the stock lock view from a TTY. Hyprland keeps the session
locked (`allow_session_lock_restore`), and a restarted shell re-takes the
lock with the stock view:

1. `Ctrl + Alt + F3`, log in.
2. Switch the lock back to Omarchy's and restart the shell inside the
   Hyprland session:
   ```bash
   rm ~/.config/omarchy/plugins/aether.lock
   jq '.disabledPlugins -= ["omarchy.lock"] | .plugins -= [{"id":"aether.lock"}]' \
     ~/.config/omarchy/shell.json > /tmp/s.json && mv /tmp/s.json ~/.config/omarchy/shell.json
   hyprctl -i 0 dispatch 'hl.dsp.exec_cmd("omarchy restart shell")'
   ```
3. Return with `Ctrl + Alt + F1` (or F2) and unlock on the stock screen.

## Autosuggestions / highlighting missing

- Only in interactive bash in a real terminal. `echo $BLE_VERSION` should
  print a version.
- Start a shell without it: `AETHER_NO_BLESH=1 bash`.
- ble.sh reinstall: `rm -rf ~/.local/share/blesh && ./install.sh --no-bar --no-lock`.

## Prompt looks like the old one

`echo $STARSHIP_CONFIG` should point to `.../aether/config/shell/starship.toml`.
Open a new terminal after installing.

## Cursor did not change everywhere

Already-running apps keep their cursor until restarted. XWayland apps read
`XCURSOR_THEME`, which Omarchy does not set; most apps follow the GNOME
setting AETHER changes.

## GTK app still looks stock

Restart the app. AETHER links `~/.config/gtk-4.0/gtk.css` and
`~/.config/gtk-3.0/gtk.css` only if those files did not already exist — the
hook prints `aether: leaving existing … in place` otherwise. Apps with their
own theming (Chromium, Electron, Qt) do not read these files.

## Restore everything from a snapshot

```bash
./uninstall.sh
./restore.sh backup/<timestamp>
```
