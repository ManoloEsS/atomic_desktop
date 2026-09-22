# Atomic Desktop

Automated Fedora Silverblue (44 or newer) setup for the desktop currently
described by
`deomarchyfy_fedora`. Host layers and application manifests are declarative;
user-local Mise tools intentionally track the latest releases when the
installer is rerun. This project recreates desktop functionality on a fresh
system; it does not migrate credentials, application state, containers, or
machine identities.

## Scope

The desktop profile preserves:

- Niri with the current Acer landscape and Samsung portrait layout.
- Noctalia bar, launcher, notifications, lock screen, power controls, and
  desktop-specific output widgets.
- Ghostty, Zen Browser, Brave, FreeRDP, Spotify, and the existing shell
  workflow. Standalone GUI applications are installed as Flatpaks.
- Docker CE, OpenSSH server, Tailscale, firewalld, tuned-ppd, and fstrim.
- Mise-managed CLI tools, Yazi, Herdr, tmux, and the Toolbx development
  container.

Laptop-only touchpad toggling, keyd remapping, and WiFi powersave policy are
not part of this profile.

## Layer Model

```text
Silverblue base image (assumed)
  GNOME/GDM, git, openssh client, toolbox, podman, flatpak, fontconfig,
  portals, PipeWire, NetworkManager, Nautilus, polkit, firewalld.

Host rpm-ostree layers
  niri, noctalia, ghostty, wtype, neovim, tailscale, openssh-server, Docker CE,
  Compose, buildx.

User-local Mise
  latest Herdr, Yazi, tmux, fzf, bat, eza, zoxide, gh, and jj. Dotfiles are
  applied through Mise native dotfiles. Neovim's configuration is kept in the
  independent kickstart.nvim repository and follows its `master` branch.

Toolbx
  fedora-desktop-dev with the minimal native packages from
  manifests/toolbox-packages.txt. The same rolling Mise CLI tools are
  available inside the container, with Starship enabled only by the Toolbox
  overlay.

Flatpak
  Zen Browser, Brave, FreeRDP, and Spotify from Flathub.
```

The host remains small enough for rpm-ostree rollback. Runtime state is kept
outside the repository and is intentionally empty on a fresh installation.

Neovim itself is layered into the host and installed in Toolbx for use from
either environment. The configuration repository is cloned to
`~/.local/share/fedora-desktop/sources/nvim` and linked to `~/.config/nvim`.
The installer fetches the current `master` tip on each run, so changes in the
independent configuration repository become part of the next setup run.

## Repositories

Only repositories needed by the declared host layers are configured:

- Fedora and Fedora Updates from the Silverblue base.
- Ghostty COPR `scottames/ghostty`.
- Docker CE's official Fedora repository.
- Tailscale's official Fedora repository.

COPR and vendor signing keys are fingerprint-checked before repository files
are installed. Recheck upstream fingerprints before changing the manifests.
All vendor and COPR repositories (including Tailscale) are declared
data-driven in `manifests/vendor-repositories.conf` and
`manifests/external-repositories.conf`. Flathub relies on its embedded
`.flatpakrepo` signature over TLS instead of a pinned fingerprint.

## Assumptions

- Fedora Silverblue `>= 44`, booted via ostree, with `sudo` available.
- GNU bash and coreutils on the host and in Toolbx.
- `XDG_CONFIG_HOME` is honored when set, otherwise `~/.config`.
- Mise tools track rolling `latest` and carry no lockfile by design; run
  `mise upgrade` manually between installer runs if desired. The Mise
  installer itself is TLS-trusted (`https://mise.run`), while repository keys
  and fonts stay fingerprint/SHA-pinned.
- The Neovim config follows its `master` tip on every run (non-idempotent by
  design).
- The verifier treats machine-specific state (monitor layout, Niri/Noctalia
  validators, firewall SSH, FreeRDP launch probe) as warnings, not failures,
  so headless runs and firmware refresh-rate changes do not fail verification.

## Installation

Review the scripts, manifests, and desktop profile first:

```sh
bash install.sh --dry-run --profile desktop --replace-dotfiles
bash install.sh --profile desktop --replace-dotfiles
```

On a fresh Fedora account, use `--replace-dotfiles` because Fedora creates
standard shell dotfiles such as `.bashrc` and `.bash_profile`. Conflicting
regular files are backed up under
`~/.local/state/fedora-desktop/backups/` before replacement.

The first pass performs preflight and layers host packages. If rpm-ostree
creates a new deployment, the command exits with status `10`; reboot manually
and run the same command again. The second pass installs the latest configured
Mise CLI tools, applies dotfiles, installs Flatpaks,
creates Toolbx, and verifies the result.

The installer enables Docker, `sshd`, and `tailscaled`, but does not authenticate
or populate them. Authenticate a fresh machine manually:

```sh
sudo tailscale up
gh auth login
```

Docker starts with no migrated containers, images, or volumes. The installer
does not add the user to Docker's root-equivalent group automatically.

On a host that already layered the old desktop browser and FreeRDP packages,
remove those host layers manually before or after applying this manifest:

```sh
sudo rpm-ostree uninstall zen-browser brave-origin freerdp
sudo reboot
```

Existing repository files are not removed automatically. Inspect them and
remove old Zen or Brave repository files separately once no installed package
needs them.

## Dotfiles and Profile

Dotfiles are managed by the Mise configuration in `mise.toml`; GNU Stow is not
used. Inspect convergence before applying changes:

```sh
mise bootstrap dotfiles status
mise bootstrap dotfiles diff
mise bootstrap dotfiles apply --dry-run
```

Global Mise tools are intentionally rolling. Project language runtimes are not
installed by this desktop profile; declare them in each project instead:

```sh
cd /path/to/project
mise use python@3.13
mise use go@1.24
```

Projects that need reproducible tool resolution can maintain their own
`mise.lock` and use `mise install --locked`; that policy is independent of
this desktop bootstrap.

The desktop output rules are installed from
`profiles/desktop/local.kdl.example`. They are tracked because this repository
describes one known desktop. Confirm the result with:

```sh
niri msg outputs
```

`profiles/desktop/profile.env` is ignored and may contain an optional RDP host
and username. It must never contain passwords, tokens, or private keys.

## Fresh-System Boundary

This project does not restore or copy:

- SSH or GPG keys, GitHub credentials, browser profiles, or Tailscale state.
- SSH host keys or old `/etc` configuration.
- Docker containers, images, volumes, or `/var/lib/docker`.
- Flatpak application data or old home-directory state.

The clean install creates new identities and fresh application state. User data
and credentials must be restored or authenticated separately if desired.

## Verification and Recovery

The final phase runs the read-only verifier:

```sh
bash scripts/verify.sh --profile desktop
rpm-ostree status
systemctl status docker sshd tailscaled
niri msg outputs
nvim --version
```

Verification checks the Silverblue deployment, host layers, rolling Mise tools
and links, Niri and Noctalia configuration, exact monitor modes, Docker/SSH/
Tailscale services, firewalld SSH access, Flatpaks, Toolbx, fonts, and Ghostty
terminfo.

If a deployment fails, select the previous boot entry or run:

```sh
sudo rpm-ostree rollback
sudo reboot
```

Rollback reverts `/usr`; service state and home configuration are managed
separately by the installer and are not credential backups.
