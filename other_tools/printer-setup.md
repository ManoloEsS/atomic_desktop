# Optional Printer Setup on Fedora Atomic

This project uses Fedora Silverblue with Niri and Noctalia. Printer setup is
optional and is not part of the desktop installer. Configure printing on the
host; do not install CUPS in Toolbx or as a Flatpak.

## Check CUPS

Check whether CUPS and its driverless printing support are installed, and
whether the scheduler is running:

```bash
rpm -q cups cups-filters-driverless
lpstat -r
```

If either package is missing, layer the host packages and reboot into the new
deployment:

```bash
sudo rpm-ostree install cups cups-filters-driverless
sudo systemctl reboot
```

After reboot, enable and start the CUPS service:

```bash
sudo systemctl enable --now cups.service
```

Check that the scheduler is running:

```bash
lpstat -r
```

## Check network discovery

Make sure the printer is powered on and connected to the same local network as
the computer, rather than a guest or isolated Wi-Fi network.

List printers discovered on the network:

```bash
lpstat -e
```

This can list network-discovered destinations without a local printer queue
being configured. If the printer is not listed, find its IP address on the
printer's network/status screen or in the router's connected-device list. You
may be able to add it by IP if it supports IPP.

Automatic discovery uses local-network DNS-SD/mDNS. If the printer is on the
same network but still is not discovered, check Avahi:

```bash
systemctl status avahi-daemon.service
```

If the service is installed but inactive, start it:

```bash
sudo systemctl enable --now avahi-daemon.service
```

## Add the printer in CUPS

Open CUPS's local web interface:

<http://localhost:631>

Choose **Administration → Add Printer**. If prompted, authenticate with an
account authorized to administer CUPS.

Select the discovered printer. For a network printer that supports it, choose a
**driverless** or **IPP Everywhere** option. Leave printer sharing disabled
unless you specifically want other computers to print through this computer.

Complete the wizard to create a local CUPS queue for the printer.

## Verify and test

Check that the queue was added:

```bash
lpstat -p -d
lpstat -v
```

The first command shows configured queues and the default printer; the second
shows each queue's device URI. In the CUPS interface, open the printer's queue
and choose **Maintenance → Print Test Page**.

To make the Epson the default printer from the terminal, use its queue name:

```bash
lpoptions -d EPSON_XP_4100_Series
```

## Print from an application

Close and reopen the document app, then select the printer in its print dialog.
If it still does not appear, first check whether the queue appears in
`lpstat -p -d`. If the queue is listed but missing from only one Flatpak app,
the issue is likely specific to that app's print integration.

## Troubleshooting

- **`lpstat -e` lists the printer, but `cupsenable` says
  `client-error-not-found`:** the printer is discoverable, but no local queue
  has been added yet. Add it through CUPS first. `cupsenable` applies to an
  existing queue.
- **`http://localhost:631` does not open:** check that the `cups` package is
  installed and inspect the service with `systemctl status cups.service`.
  Start it with `sudo systemctl enable --now cups.service` if it is inactive.
- **The printer does not appear in discovery:** check that it is awake and on
  the same non-guest network. If needed, try adding it by IP using the printer's
  IPP information.
- **The queue exists but printing fails:** check the queue status in CUPS and
  confirm that the printer is online. If driverless printing is unavailable,
  identify a Fedora-compatible driver for the exact model before installing
  one on the host.
