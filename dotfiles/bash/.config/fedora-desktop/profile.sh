profile_env="${XDG_CONFIG_HOME:-$HOME/.config}/fedora-desktop/profile.env"
if [[ -r "$profile_env" ]]; then
  # shellcheck disable=SC1090
  source "$profile_env"
fi

if [[ -n "${FEDORA_DESKTOP_RDP_HOST:-}" && -n "${FEDORA_DESKTOP_RDP_USER:-}" ]]; then
  alias win-rdp="sdl-freerdp /v:${FEDORA_DESKTOP_RDP_HOST} /u:${FEDORA_DESKTOP_RDP_USER} /dynamic-resolution +clipboard"
fi
