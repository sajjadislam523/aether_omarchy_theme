# AETHER shell setup, part 1 — sourced from ~/.bashrc BEFORE Omarchy's rc.
# Sets the prompt config and loads ble.sh without attaching yet (ble.sh must
# be loaded early and attached last; see aether-post.bash).

# The repo can live anywhere: resolve it from this file's location.
AETHER_DIR="${AETHER_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# Compact AETHER prompt; ~/.config/starship.toml stays as it was.
if [[ -f $AETHER_DIR/config/shell/starship.toml ]]; then
  export STARSHIP_CONFIG="$AETHER_DIR/config/shell/starship.toml"
fi

# ble.sh: fish-style autosuggestions + syntax highlighting for bash.
# Skip with AETHER_NO_BLESH=1 (e.g. `AETHER_NO_BLESH=1 bash`).
if [[ $- == *i* && -z ${AETHER_NO_BLESH:-} && ${TERM:-} != dumb ]]; then
  for _aether_ble in "$HOME/.local/share/blesh/ble.sh" /usr/share/blesh/ble.sh; do
    if [[ -f $_aether_ble ]]; then
      source "$_aether_ble" --noattach
      break
    fi
  done
  unset _aether_ble
fi
