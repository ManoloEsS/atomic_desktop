#!/usr/bin/env bash
# Install the tracked external Neovim configuration for the desktop profile.
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

REPLACE=false
NVIM_SOURCE_ROOT="$HOME/.local/share/fedora-desktop/sources/nvim"
NVIM_TARGET="$HOME/.config/nvim"

usage() {
  printf 'Usage: %s [--profile NAME] [--dry-run] [--replace-dotfiles]\n' "${0##*/}"
}

while (($#)); do
  case $1 in
    --dry-run) DRY_RUN=true ;;
    --profile)
      (($# >= 2)) || usage_error "--profile requires a value"
      select_profile "$2"
      shift
      ;;
    --replace|--replace-dotfiles) REPLACE=true ;;
    -h|--help) usage; exit 0 ;;
    *) usage_error "unknown option: $1" ;;
  esac
  shift
done

reject_root
source_profile="$REPO_ROOT/profiles/$PROFILE/nvim-source.conf"
[[ -r $source_profile ]] || die "Neovim source manifest is missing: $source_profile"
# shellcheck disable=SC1090
source "$source_profile"

: "${NVIM_CONFIG_URL:?NVIM_CONFIG_URL is missing from $source_profile}"
: "${NVIM_CONFIG_REF:?NVIM_CONFIG_REF is missing from $source_profile}"
: "${NVIM_CONFIG_SUBDIR:?NVIM_CONFIG_SUBDIR is missing from $source_profile}"

config_dir="$NVIM_SOURCE_ROOT/$NVIM_CONFIG_SUBDIR"
backup_root="$HOME/.local/state/fedora-desktop/backups/$(date -u +%Y%m%dT%H%M%SZ)"

if [[ $DRY_RUN == true ]]; then
  info "Would clone/update $NVIM_CONFIG_URL at $NVIM_SOURCE_ROOT"
  info "Would check out the latest Neovim config from $NVIM_CONFIG_REF"
  info "Would link $NVIM_TARGET to $config_dir"
  exit 0
fi

require_command git
mkdir -p -- "$(dirname -- "$NVIM_SOURCE_ROOT")"

if [[ -e $NVIM_SOURCE_ROOT && ! -d $NVIM_SOURCE_ROOT ]]; then
  die "Neovim source path is not a directory: $NVIM_SOURCE_ROOT"
fi

if [[ ! -d "$NVIM_SOURCE_ROOT/.git" ]]; then
  [[ ! -e $NVIM_SOURCE_ROOT ]] || die "Neovim source directory exists without Git metadata: $NVIM_SOURCE_ROOT"
  git clone --filter=blob:none --no-checkout "$NVIM_CONFIG_URL" "$NVIM_SOURCE_ROOT"
else
  configured_url=$(git -C "$NVIM_SOURCE_ROOT" remote get-url origin 2>/dev/null || true)
  [[ $configured_url == "$NVIM_CONFIG_URL" ]] || die "Neovim source origin differs: $configured_url"
  git -C "$NVIM_SOURCE_ROOT" diff --quiet || die "Neovim source checkout has unstaged changes"
  git -C "$NVIM_SOURCE_ROOT" diff --cached --quiet || die "Neovim source checkout has staged changes"
fi

git -C "$NVIM_SOURCE_ROOT" fetch --depth=1 origin "$NVIM_CONFIG_REF"
git -C "$NVIM_SOURCE_ROOT" checkout --detach --force FETCH_HEAD
resolved_ref=$(git -C "$NVIM_SOURCE_ROOT" rev-parse HEAD)
fetched_ref=$(git -C "$NVIM_SOURCE_ROOT" rev-parse FETCH_HEAD)
[[ $resolved_ref == "$fetched_ref" ]] || die "Neovim source resolved to $resolved_ref, expected fetched ref $fetched_ref"
[[ -d $config_dir ]] || die "Neovim config subdirectory is missing: $config_dir"
config_dir=$(cd -- "$config_dir" && pwd -P)

if [[ -L $NVIM_TARGET ]]; then
  if [[ $(readlink -f -- "$NVIM_TARGET") == "$config_dir" ]]; then
    info "Neovim config link already points at the tracked checkout"
    exit 0
  fi
  rm -- "$NVIM_TARGET"
elif [[ -e $NVIM_TARGET ]]; then
  if [[ $REPLACE != true ]]; then
    die "$NVIM_TARGET is a real file or directory; rerun with --replace-dotfiles after review"
  fi
  mkdir -p -- "$backup_root/.config"
  mv -- "$NVIM_TARGET" "$backup_root/.config/nvim"
  info "Backed up existing Neovim config to $backup_root/.config/nvim"
fi

mkdir -p -- "$(dirname -- "$NVIM_TARGET")"
ln -s -- "$config_dir" "$NVIM_TARGET"
info "Linked Neovim config to $NVIM_CONFIG_REF at $resolved_ref"
