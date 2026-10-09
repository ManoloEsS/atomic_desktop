# Wireshark and TShark Packet Capture

This guide installs Wireshark on the Fedora Silverblue host so it can capture
traffic on host interfaces such as `wlp2s0`. The existing `dev` Toolbx remains
useful for inspecting saved capture files, but its rootless container cannot
open packet sockets on the host's physical interfaces.

## Install on the host

Layer the GUI and CLI packages onto Silverblue, then reboot into the new
deployment:

```bash
sudo rpm-ostree install wireshark wireshark-cli
sudo systemctl reboot
```

`wireshark` provides the GUI; `wireshark-cli` provides `tshark` and `dumpcap`.
Verify the host packages and capture helper after reboot:

```bash
wireshark --version
tshark --version
stat -c '%A %U:%G %n' /usr/bin/dumpcap
getcap /usr/bin/dumpcap
```

The helper should be executable by the `wireshark` group, usually with mode
`750`, and have `cap_net_admin,cap_net_raw` file capabilities.

## Enable capture for the user

On this Silverblue installation, the package-provided `wireshark` group was
available through the system group database but had no local entry in
`/etc/group`. Consequently, `usermod` did not add the membership and `gpasswd`
reported that the group did not exist in `/etc/group`.

First get the package's group ID:

```bash
getent group wireshark
```

Use `sudo vigr` to edit `/etc/group`, then add a local entry using the reported
GID and your login name. For this machine, the entry is:

```text
wireshark:x:958:manoloess
```

Use the GID and username reported for your own installation rather than
assuming these values on another host. Verify that `getent group wireshark`
lists your user.

On this host, adding the local group entry and restarting the login session
still left Wireshark launched from the app menu or a regular shell without
capture access. Start a shell with the group active, then launch Wireshark or
TShark from that shell:

```bash
newgrp wireshark
id -nG
wireshark
```

This is the working launch path on this machine; `id -nG` should include
`wireshark` in the new shell. Launching from the app menu or a shell without
`newgrp` still produces `Couldn't run dumpcap in child process: Permission denied`.
Do not launch the GUI with `sudo`; it should run as your regular user from the
`newgrp` shell and use `dumpcap` for capture.

## Capture and inspect traffic

List interfaces on the host:

```bash
tshark -D
```

Listing an interface does not prove capture access. Test a short capture as your
regular user, substituting the interface name shown on your host:

```bash
tshark -i wlp2s0 -a duration:5 -n
```

Start the GUI from the same host shell:

```bash
wireshark
```

Select the interface and start capturing. To save a capture for later analysis,
use `dumpcap` or TShark on the host, for example:

```bash
tshark -i wlp2s0 -w "$HOME/capture.pcapng"
```

Stop with **Ctrl+C**. Wireshark or TShark inside Toolbx can then read the saved
file:

```bash
wireshark "$HOME/capture.pcapng"
tshark -r "$HOME/capture.pcapng"
```

## Why live capture fails in Toolbx

The rootless Toolbx can enumerate host interfaces, so `tshark -D` may show
`wlp2s0`. Opening that interface requires `CAP_NET_RAW` in the user namespace
that owns the host network namespace. The Toolbx does not have that host-level
capability; adding the user to its `wireshark` group or setting capabilities on
its copy of `dumpcap` does not grant it. Errors such as
`Attempt to create packet socket failed - CAP_NET_RAW may be required` are a
capture-privilege failure, not a missing Toolbx package. Capture on the host,
then open the resulting file in Toolbx for analysis.
