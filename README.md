# Atomic Desktop

Reproducible Fedora Silverblue 44 setup for the desktop currently described by
`deomarchyfy_fedora`. This project recreates desktop functionality on a fresh
system; it does not migrate credentials, application state, containers, or
machine identities.

## Scope

The desktop profile preserves:

- Niri with the current Acer landscape and Samsung portrait layout.
- Noctalia bar, launcher, notifications, lock screen, power controls, and
  desktop-specific output widgets.
- Ghostty, Zen Browser, Brave Origin, FreeRDP, Spotify, and the existing shell
  workflow.
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
  niri, noctalia, ghostty, wtype, tailscale, zen-browser, brave-origin,
  freerdp, openssh-server, rsync, inotify-tools, Docker CE, Compose, buildx.

User-local Mise
  starship, herdr, yazi, neovim, tmux, fzf, bat, eza, zoxide, gh, jj,
  Python, and Go. Dotfiles are applied through Mise native dotfiles.

Toolbx
  fedora-desktop-dev with the minimal native packages from
  manifests/toolbox-packages.txt. The same locked Mise toolset is available
  inside the container.

Flatpak
  FreeRDP and Spotify from Flathub.
```

The host remains small enough for rpm-ostree rollback. Runtime state is kept
outside the repository and is intentionally empty on a fresh installation.

## Repositories

Only repositories needed by the declared host layers are configured:

- Fedora and Fedora Updates from the Silverblue base.
- Ghostty COPR `scottames/ghostty`.
- Zen Browser COPR `sneexy/zen-browser`.
- Brave Browser's official RPM repository.
- Docker CE's official Fedora repository.
- Tailscale's official Fedora repository.

COPR and vendor signing keys are fingerprint-checked before repository files
are installed. Recheck upstream fingerprints before changing the manifests.

## Installation

Review the scripts, manifests, and desktop profile first:

```sh
bash install.sh --dry-run --profile desktop
bash install.sh --profile desktop
```

The first pass performs preflight and layers host packages. If rpm-ostree
creates a new deployment, the command exits with status `10`; reboot manually
and run the same command again. The second pass configures services, installs
Mise tools and dotfiles, installs Flatpaks, creates Toolbx, and verifies the
result.

The installer enables Docker, `sshd`, and `tailscaled`, but does not authenticate
or populate them. Authenticate a fresh machine manually:

```sh
sudo tailscale up
gh auth login
```

Docker starts with no migrated containers, images, or volumes. The installer
does not add the user to Docker's root-equivalent group automatically.

## Dotfiles and Profile

Dotfiles are managed by the locked Mise configuration in `mise.toml`; GNU Stow
is not used. Inspect convergence before applying changes:

```sh
mise bootstrap dotfiles status
mise bootstrap dotfiles diff
mise bootstrap dotfiles apply --dry-run
```

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
```

Verification checks the Silverblue deployment, host layers, Mise tools and
links, Niri and Noctalia configuration, exact monitor modes, Docker/SSH/
Tailscale services, firewalld SSH access, Flatpaks, Toolbx, fonts, and Ghostty
terminfo.

If a deployment fails, select the previous boot entry or run:

```sh
sudo rpm-ostree rollback
sudo reboot
```

Rollback reverts `/usr`; service state and home configuration are managed
separately by the installer and are not credential backups.
