#!/usr/bin/env bash
# Install the latest Mise release to ~/.local/bin (user-local, no host layer).
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

readonly MISE_PATH="$HOME/.local/bin/mise"

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

installed_version=
if [[ -x $MISE_PATH ]]; then
  installed_version=$("$MISE_PATH" --version 2>/dev/null || true)
fi

if [[ -n $installed_version ]]; then
  info "Updating Mise ${installed_version%% *} to the latest release at $MISE_PATH"
else
  info "Installing the latest Mise release to $MISE_PATH"
fi

if [[ $DRY_RUN == true ]]; then
  info "Would install/update the latest Mise release to $MISE_PATH via the official installer"
  exit 0
fi

require_command curl
run mkdir -p -- "$HOME/.local/bin"
curl -fsSL https://mise.run | MISE_INSTALL_PATH="$MISE_PATH" sh
installed_version=$("$MISE_PATH" --version 2>/dev/null || true)
[[ -n $installed_version ]] || die "Mise installation failed or produced no version"
info "Using Mise $installed_version"

if [[ $DRY_RUN == true ]]; then
  info "Would run: $MISE_PATH trust + install/upgrade from $REPO_ROOT/mise.toml"
  exit 0
fi

"$MISE_PATH" trust "$REPO_ROOT/mise.toml"
(
  cd "$REPO_ROOT"
  "$MISE_PATH" install
  "$MISE_PATH" upgrade
  MISE_ENV=toolbox "$MISE_PATH" install
  MISE_ENV=toolbox "$MISE_PATH" upgrade
)

# Make repo tools resolve in EVERY directory (not just the checkout) by
# pointing the global Mise configs at the repo files. Dotfile sources stay
# relative to the repo root, so this is safe.
mkdir -p -- "$HOME/.config/mise"
# config.toolbox.toml is the MISE_ENV=toolbox overlay.
for pair in "config.toml:mise.toml" "config.toolbox.toml:mise.toolbox.toml"; do
  target="$HOME/.config/mise/${pair%%:*}"
  source="$REPO_ROOT/${pair##*:}"
  if [[ -L $target && $(readlink -f -- "$target" 2>/dev/null || true) == "$source" ]]; then
    info "global Mise ${pair%%:*} already points at repository"
  elif [[ -e $target || -L $target ]]; then
    die "global Mise ${pair%%:*} conflicts at $target; back it up or remove it manually"
  else
    ln -s -- "$source" "$target"
    info "linked global Mise ${pair%%:*} to repository"
  fi
done

# Remove lockfile links created by older desktop revisions, but refuse to
# remove unrelated files from the user's Mise configuration directory.
for pair in "mise.lock:mise.lock" "mise.toolbox.lock:mise.toolbox.lock"; do
  target="$HOME/.config/mise/${pair%%:*}"
  source="$REPO_ROOT/${pair##*:}"
  if [[ -L $target && $(readlink -f -- "$target" 2>/dev/null || true) == "$source" ]]; then
    rm -- "$target"
    info "removed legacy global Mise lockfile link: ${pair%%:*}"
  elif [[ -e $target || -L $target ]]; then
    die "legacy Mise lockfile conflicts at $target; remove it manually"
  fi
done
