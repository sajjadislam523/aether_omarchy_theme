# AETHER shell setup, part 2 — sourced at the very END of ~/.bashrc.

if [[ ${BLE_VERSION-} ]]; then
  # Autosuggestions: dimmed history completion; → or End accepts it.
  bleopt complete_auto_complete=1
  bleopt complete_auto_delay=60
  bleopt complete_menu_style=align-nowrap
  bleopt exec_errexit_mark=          # no "[ble: exit N]" line; the prompt ❯ turns red instead
  bleopt prompt_eol_mark=''

  # AETHER faces (syntax highlighting). Calm: mostly text color, cyan for
  # commands, violet for keywords, red only for real errors.
  ble-face -s auto_complete           fg=#566574
  ble-face -s command_builtin         fg=#55D6FF
  ble-face -s command_alias           fg=#55D6FF
  ble-face -s command_function        fg=#55D6FF
  ble-face -s command_file            fg=#55D6FF
  ble-face -s command_keyword         fg=#9B8CFF
  ble-face -s command_directory       fg=#8BE7FF,underline
  ble-face -s syntax_error            fg=#FF667D
  ble-face -s syntax_quoted           fg=#58E6A5
  ble-face -s syntax_quotation        fg=#58E6A5
  ble-face -s syntax_param_expansion  fg=#B8ADFF
  ble-face -s syntax_varname          fg=#B8ADFF
  ble-face -s syntax_comment          fg=#566574
  ble-face -s filename_directory      fg=#8BE7FF,underline
  ble-face -s filename_executable     fg=#55D6FF
  ble-face -s argument_option         fg=#8A9AAA
  ble-face -s region_insert           fg=#8BE7FF,bg=#1C3542
  ble-face -s region                  bg=#1C3542

  # fzf's Ctrl-R / Ctrl-T bindings, adapted for ble.sh.
  if command -v fzf >/dev/null 2>&1; then
    ble-import -d integration/fzf-key-bindings 2>/dev/null
  fi

  ble-attach
fi
