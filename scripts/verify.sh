#!/usr/bin/env bash
# Read-only verification for the Atomic desktop setup.
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

failures=0
warnings=0

pass() { printf 'PASS: %s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; ((failures += 1)); }
verify_warn() { printf 'WARN: %s\n' "$*" >&2; ((warnings += 1)); }

check_command() {
  local command_name=$1
  if command -v "$command_name" >/dev/null 2>&1; then
    pass "command available: $command_name"
  else
    fail "command unavailable: $command_name"
  fi
}

check_service() {
  local unit=$1
  if ! unit_exists "$unit"; then
    fail "$unit is not installed"
  elif ! systemctl is-enabled --quiet "$unit"; then
    fail "$unit is not enabled"
  elif ! systemctl is-active --quiet "$unit"; then
    fail "$unit is not active"
  else
    pass "$unit is enabled and active"
  fi
}

check_link() {
  local target=$1 expected=$2
  if [[ -L "$target" && $(readlink -f -- "$target") == "$expected" ]]; then
    pass "managed link: $target"
  else
    fail "managed link missing or incorrect: $target"
  fi
}

check_output_layout() {
  local outputs
  if ! outputs=$(niri msg outputs 2>/dev/null); then
    verify_warn "Niri output state unavailable outside the graphical session"
    return
  fi

  if [[ $outputs == *'Acer Technologies ED340CU J0 54520961D3W01 (DP-1)'* &&
        $outputs == *'Current mode: 3440x1440 @ 119.998 Hz'* &&
        $outputs == *'Logical position: 0, 0'* ]]; then
    pass "Acer desktop output layout"
  else
    fail "Acer desktop output layout differs"
  fi

  if [[ $outputs == *'Samsung Electric Company LF24T35 HCNR501668 (HDMI-A-1)'* &&
        $outputs == *'Current mode: 1920x1080 @ 74.973 Hz'* &&
        $outputs == *'Logical position: -1080, 0'* &&
        $outputs == *'Transform: 90° counter-clockwise'* ]]; then
    pass "Samsung desktop output layout"
  else
    fail "Samsung desktop output layout differs"
  fi
}

while (($#)); do
  case $1 in
    --dry-run) DRY_RUN=true ;;
    --profile)
      (($# >= 2)) || usage_error "--profile requires a value"
      select_profile "$2"
      shift
      ;;
    -h|--help)
      printf 'Usage: %s [--profile NAME] [--dry-run]\n' "${0##*/}"
      exit 0
      ;;
    *) usage_error "unknown option: $1" ;;
  esac
  shift
done

reject_root
require_silverblue_44

if pending_deployment_exists; then
  fail "an rpm-ostree deployment is pending; reboot is required"
else
  pass "booted deployment is current"
fi

while IFS= read -r package; do
  if rpm -q --quiet "$package"; then
    pass "host package installed: $package"
  else
    fail "host package missing: $package"
  fi
done < <(read_manifest "$MANIFEST_DIR/host-packages.txt")

for command_name in niri noctalia ghostty wtype tailscale zen-browser brave-origin sdl-freerdp ssh docker; do
  check_command "$command_name"
done

MISE_BIN="$HOME/.local/bin/mise"
command -v "$MISE_BIN" >/dev/null 2>&1 || MISE_BIN=mise
if command -v "$MISE_BIN" >/dev/null 2>&1; then
  pass "mise available: $MISE_BIN"
  for tool in herdr yazi nvim tmux fzf bat eza zoxide gh jj python go starship; do
    if "$MISE_BIN" which "$tool" >/dev/null 2>&1; then
      pass "mise tool installed: $tool"
    else
      fail "mise tool missing: $tool"
    fi
  done
  links_ok=true
  for pair in "config.toml:mise.toml" "mise.lock:mise.lock" "config.toolbox.toml:mise.toolbox.toml" "mise.toolbox.lock:mise.toolbox.lock"; do
    [[ $(readlink -f -- "$HOME/.config/mise/${pair%%:*}" 2>/dev/null || true) == "$REPO_ROOT/${pair##*:}" ]] || links_ok=false
  done
  if [[ $links_ok == true ]]; then
    pass "global Mise config and lockfiles point at repository"
  else
    fail "global Mise links are missing or incorrect"
  fi
  if (cd "$HOME" && "$MISE_BIN" which zoxide >/dev/null 2>&1); then
    pass "Mise tools resolve from home directory"
  else
    fail "Mise tools do not resolve from home directory"
  fi
else
  fail "Mise is unavailable at ~/.local/bin/mise"
fi

if command -v "$MISE_BIN" >/dev/null 2>&1 && "$MISE_BIN" bootstrap dotfiles status --missing >/dev/null 2>&1; then
  pass "Mise dotfiles converge"
else
  fail "Mise dotfiles have missing or conflicting entries"
fi

for pair in \
  "$HOME/.bashrc:dotfiles/bash/.bashrc" \
  "$HOME/.config/niri/config.kdl:dotfiles/niri/.config/niri/config.kdl" \
  "$HOME/.config/niri/local.kdl:profiles/$PROFILE/local.kdl.example" \
  "$HOME/.config/noctalia/config.toml:dotfiles/noctalia/.config/noctalia/config.toml" \
  "$HOME/.config/ghostty/config:dotfiles/ghostty/.config/ghostty/config" \
  "$HOME/.config/tmux/tmux.conf:dotfiles/tmux/.config/tmux/tmux.conf"; do
  target=${pair%%:*}
  source=${pair#*:}
  if [[ $source == profiles/* ]]; then
    [[ -r $target ]] && pass "desktop profile file present: $target" || fail "desktop profile file missing: $target"
  else
    check_link "$target" "$REPO_ROOT/$source"
  fi
done

check_service docker.service
check_service sshd.service
check_service tailscaled.service
if command -v sshd >/dev/null 2>&1; then
  if sudo -n sshd -t 2>/dev/null || sshd -t 2>/dev/null; then
    pass "sshd configuration validates"
  else
    verify_warn "sshd configuration could not be checked without sudo authentication"
  fi
else
  fail "sshd command unavailable"
fi

for unit in NetworkManager.service firewalld.service fstrim.timer; do
  if unit_exists "$unit" && systemctl is-active --quiet "$unit"; then
    pass "base service active: $unit"
  else
    verify_warn "base service inactive or absent: $unit"
  fi
done
if systemctl is-active --quiet tuned-ppd.service || systemctl is-active --quiet power-profiles-daemon.service; then
  pass "power-profile backend active"
else
  verify_warn "no power-profile backend active"
fi

if command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state >/dev/null 2>&1 &&
   firewall-cmd --zone "$(firewall-cmd --get-default-zone)" --query-service ssh >/dev/null 2>&1; then
  pass "SSH allowed in the default firewalld zone"
else
  fail "SSH is not allowed in the default firewalld zone"
fi

if command -v flatpak >/dev/null 2>&1; then
  while IFS= read -r app; do
    if flatpak info --system "$app" >/dev/null 2>&1; then
      pass "Flatpak installed: $app"
    else
      fail "Flatpak missing: $app"
    fi
  done < <(read_manifest "$MANIFEST_DIR/flatpaks.txt")
else
  fail "Flatpak command unavailable"
fi

if command -v toolbox >/dev/null 2>&1; then
  if toolbox list --containers 2>/dev/null | grep -q fedora-desktop-dev; then
    pass "Toolbx container present: fedora-desktop-dev"
    if toolbox run --container fedora-desktop-dev env MISE_ENV=toolbox "$MISE_BIN" which starship >/dev/null 2>&1; then
      pass "Starship resolves inside Toolbx"
    else
      fail "Starship missing inside Toolbx"
    fi
  else
    fail "Toolbx container missing: fedora-desktop-dev"
  fi
else
  fail "Toolbox command unavailable"
fi

if command -v fc-match >/dev/null 2>&1 && [[ $(fc-match --format '%{family}' 'JetBrainsMono Nerd Font' 2>/dev/null) == *'JetBrainsMono Nerd Font'* ]]; then
  pass "JetBrainsMono Nerd Font is available"
else
  fail "JetBrainsMono Nerd Font is unavailable"
fi

if infocmp xterm-ghostty >/dev/null 2>&1; then
  pass "terminfo entry resolves: xterm-ghostty"
else
  fail "terminfo entry missing: xterm-ghostty"
fi

yazi_flavor=${XDG_CONFIG_HOME:-$HOME/.config}/yazi/flavors/tokyo-night.yazi/flavor.toml
[[ -r $yazi_flavor ]] && pass "Yazi Tokyo Night flavor is installed" || fail "Yazi Tokyo Night flavor is missing"

niri_config=${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl
if niri validate --config "$niri_config" >/dev/null 2>&1; then
  pass "Niri configuration validates"
else
  fail "Niri configuration validation failed"
fi
check_output_layout

if noctalia config validate >/dev/null 2>&1; then
  pass "Noctalia configuration validates"
else
  fail "Noctalia configuration validation failed"
fi

printf '\nVerification complete: %d failure(s), %d warning(s).\n' "$failures" "$warnings"
((failures == 0))
