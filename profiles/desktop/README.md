# Desktop Profile

This profile describes the fixed desktop hardware while shared defaults remain
portable. The tracked output rules are intentional: this repository recreates
the current desktop, not an arbitrary laptop.

The profile preserves the current two-monitor layout:

- Acer ED340CU on `DP-1`, landscape, `3440x1440@119.998`.
- Samsung LF24T35 on `HDMI-A-1`, rotated left, `1920x1080@74.973`.

`profile.env` is ignored and may contain non-secret local preferences such as
an RDP endpoint. Do not put passwords, tokens, private keys, or credentials in
the profile or repository.

The installer creates `~/.config/niri/local.kdl` from the tracked example and
does not overwrite it on later runs.
