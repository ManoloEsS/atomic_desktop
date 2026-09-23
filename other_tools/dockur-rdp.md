# RDP to the Dockur Windows VM

The `windows-lab` Dockur container runs on the Linux host reachable as `old`
(`ssh tlaloch@old`). The Windows guest has its own LAN address; connect to the
guest, not the Linux host or the container's console address:

- Windows RDP endpoint: `192.168.1.24:3389`
- Dockur web console: `http://192.168.1.240:8006`
- Current Windows username: `labuser` (from the Compose configuration)

The container is configured on the `windows-lan` network and the Windows guest
gets its own address. Docker's `PORTS` column may therefore be empty; that does
not mean RDP needs a host port mapping. The guest's TCP port 3389 must be
reachable directly at `192.168.1.24`.

## Configure the Bash alias

The Bash profile defines `win-rdp` when both endpoint variables are set in the
local, ignored `profiles/desktop/profile.env` file:

```bash
FEDORA_DESKTOP_RDP_HOST=192.168.1.24
FEDORA_DESKTOP_RDP_USER=labuser
```

The dotfile installer links this file to
`~/.config/fedora-desktop/profile.env`. Do not put the Windows password in this
file or in the repository; FreeRDP prompts for it when connecting.

Open a new Bash shell, or reload the current one, then run:

```bash
source ~/.bashrc
win-rdp
```

The alias launches the FreeRDP Flatpak with dynamic resolution and clipboard
sharing. It uses `flatpak` on the host and falls back to
`flatpak-spawn --host flatpak` when run from a Toolbx that provides
`flatpak-spawn`.

## Direct launch and troubleshooting

If the alias is not loaded, launch FreeRDP directly from the host:

```bash
flatpak run --command=sdl-freerdp com.freerdp.FreeRDP \
  /v:192.168.1.24 /u:labuser /dynamic-resolution +clipboard
```

From a Toolbx with `flatpak-spawn` available, prefix that command with
`flatpak-spawn --host`:

```bash
flatpak-spawn --host flatpak run --command=sdl-freerdp com.freerdp.FreeRDP \
  /v:192.168.1.24 /u:labuser /dynamic-resolution +clipboard
```

If the connection fails, check that Windows has finished booting, Remote
Desktop is enabled, and TCP port 3389 is reachable at the guest address. The
Dockur web console at `http://192.168.1.240:8006` is useful for checking the
guest state.
