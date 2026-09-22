#!/usr/bin/env bash
# Configure services that are part of the desktop functionality contract.
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

usage() {
  printf 'Usage: %s [--profile NAME] [--dry-run]\n' "${0##*/}"
}

while (($#)); do
  case $1 in
    --dry-run) DRY_RUN=true ;;
    --profile)
      (($# >= 2)) || usage_error "--profile requires a value"
      select_profile "$2"
      shift
      ;;
    -h|--help) usage; exit 0 ;;
    *) usage_error "unknown option: $1" ;;
  esac
  shift
done

reject_root
require_silverblue
require_booted_deployment_current
require_command sudo
require_command systemctl

enable_service() {
  local unit=$1
  if ! unit_exists "$unit"; then
    warn "required desktop service is not installed: $unit"
    return
  fi
  # `enable --now` is idempotent; no need to probe state first.
  run_root systemctl enable --now "$unit"
  info "Enabled desktop service: $unit"
}

report_base_service() {
  local unit=$1
  if ! unit_exists "$unit"; then
    warn "base service absent (left alone): $unit"
  elif systemctl is-active --quiet "$unit"; then
    info "base service active (left alone): $unit"
  else
    warn "base service inactive (left alone): $unit"
  fi
}

allow_ssh_in_default_zone() {
  if ! unit_exists firewalld.service || ! systemctl is-active --quiet firewalld.service; then
    warn "firewalld is unavailable; SSH firewall access was not changed"
    return
  fi

  command -v firewall-cmd >/dev/null 2>&1 || { warn "firewall-cmd is unavailable; SSH firewall access was not changed"; return; }
  local zone
  zone=$(firewall-cmd --get-default-zone)
  if firewall-cmd --zone "$zone" --query-service ssh >/dev/null 2>&1; then
    info "SSH already allowed in firewalld zone: $zone"
  else
    run_root firewall-cmd --permanent --zone "$zone" --add-service ssh
    run_root firewall-cmd --reload
    info "Allowed SSH in firewalld zone: $zone"
  fi
}

for unit in "${DESKTOP_SERVICES[@]}"; do
  enable_service "$unit"
done
allow_ssh_in_default_zone

report_base_service NetworkManager.service
report_base_service firewalld.service
report_base_service fstrim.timer
if systemctl is-active --quiet tuned-ppd.service || systemctl is-active --quiet power-profiles-daemon.service; then
  info "power-profile backend active (left alone)"
else
  warn "no active power-profile backend (Noctalia power controls may be unavailable)"
fi

info 'Tailscale service is ready; authenticate this fresh machine with "sudo tailscale up"'
info 'Docker service is ready with no migrated containers or volumes'
info "System configuration complete for profile: $PROFILE"
