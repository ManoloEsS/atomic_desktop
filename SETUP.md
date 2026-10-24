# Set up the desktop

1. Review the README, manifests, and desktop profile. If you want the optional
   RDP launcher preconfigured, copy `profiles/desktop/profile.env.example` to
   `profiles/desktop/profile.env` and set its host and username.

2. From the repository root, preview the setup:

   ```sh
   bash install.sh --dry-run --profile desktop --replace-dotfiles
   ```

3. Start the installation:

   ```sh
   bash install.sh --profile desktop --replace-dotfiles
   ```

   If package installation stages an rpm-ostree deployment, the installer exits
   with status `10`. Reboot, then rerun the same command.

4. After setup, authenticate services as needed:

   ```sh
   sudo tailscale up --ssh
   gh auth login  # only if you plan to use GitHub CLI
   ```

5. Check the monitor layout and installation:

   ```sh
   niri msg outputs
   rpm-ostree status
   bash scripts/verify.sh --profile desktop
   ```

The installer runs verification at the end. See the README for service details,
updates, and recovery.
