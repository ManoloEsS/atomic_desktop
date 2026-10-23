#!/usr/bin/env bash
# Install declarative system Flatpaks from Flathub or verified publisher bundles.
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
require_command flatpak
require_command curl
require_command sha256sum

# --if-not-exists is already idempotent; no need to probe the remote first.
# Flathub ships its own GPG key inside the .flatpakrepo file (TLS + embedded
# signature), unlike COPR/vendor repos which we fingerprint-pin above.
run_root flatpak remote-add --if-not-exists --system flathub https://flathub.org/repo/flathub.flatpakrepo

mapfile -t apps < <(read_manifest "$MANIFEST_DIR/flatpaks.txt")
install_bundle() {
  local url=$1 checksum=$2 bundle_file
  bundle_file=$(mktemp --suffix=.flatpak)
  trap 'rm -f -- "$bundle_file"' RETURN
  curl --fail --silent --show-error --location "$url" --output "$bundle_file"
  printf '%s  %s\n' "$checksum" "$bundle_file" | sha256sum --check -
  run_root flatpak install --system -y "$bundle_file"
  rm -f -- "$bundle_file"
  trap - RETURN
}

for entry in "${apps[@]}"; do
  IFS='|' read -r app source url checksum <<< "$entry"
  case $source in
    flathub)
      [[ -z $url && -z $checksum ]] || die "Flathub entry must not specify a bundle URL or checksum: $app"
      ;;
    bundle)
      [[ $url == https://* && $checksum =~ ^[[:xdigit:]]{64}$ ]] \
        || die "invalid bundle URL or SHA-256 for $app in flatpaks.txt"
      ;;
    *)
      die "unsupported Flatpak source '$source' for $app in flatpaks.txt"
      ;;
  esac

  if flatpak info --system "$app" >/dev/null 2>&1; then
    info "Flatpak already installed: $app"
    continue
  fi

  case $source in
    flathub)
      run_root flatpak install --system -y flathub "$app"
      ;;
    bundle)
      if is_dry_run; then
        info "Would download and verify Flatpak bundle for $app from $url"
      else
        install_bundle "$url" "$checksum"
      fi
      ;;
    *)
      die "unsupported Flatpak source '$source' for $app in flatpaks.txt"
      ;;
  esac
done

# Brave Origin is provided by the host RPM and its desktop file is exported by
# the package. Set it as the default browser after the package phase/reboot.
if ! command -v xdg-settings >/dev/null 2>&1; then
  warn "xdg-settings is unavailable; default browser was not set"
elif [[ $(xdg-settings get default-web-browser 2>/dev/null || true) == "$BRAVE_DESKTOP_FILE" ]]; then
  info "Default browser is already Brave Origin"
elif is_dry_run; then
  info "Would set default browser to $BRAVE_DESKTOP_FILE"
else
  xdg-settings set default-web-browser "$BRAVE_DESKTOP_FILE"
  info "Set default browser to Brave Origin"
fi

info "Flatpak phase complete"
