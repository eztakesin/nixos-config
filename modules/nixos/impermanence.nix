# Per-boot root rollback on btrfs under systemd stage-1 ("erase your darlings"), plus the /persist
# allowlist. Only /home, /nix and /persist survive a reboot; everything else is recreated from the blank
# snapshot disko took at install time (@root-blank). Verified by evaluation against nixpkgs 55bfb4d +
# impermanence 7b1d382; unit shape follows impermanence PR #321 (the README's postDeviceCommands example
# is blocked by an assertion under systemd stage-1).
# Limits are documented at https://nixos.ssf.network/reference/architecture/ (§5) — this is a hygiene layer on top of FDE, not a
# confidentiality mechanism by itself.
{ utils, ... }:
let
  rootDev = "/dev/vg/root";
  rootDevUnit = "${utils.escapeSystemdPath rootDev}.device"; # → dev-vg-root.device
in
{
  boot.initrd.systemd.services.rollback-root = {
    description = "Roll back btrfs @ to the blank snapshot";
    unitConfig.DefaultDependencies = false;
    serviceConfig.Type = "oneshot";
    requiredBy = [ "initrd.target" ]; # fail closed: if the rollback fails, do not boot an un-reset root
    before = [ "sysroot.mount" ];
    requires = [ rootDevUnit ];
    after = [
      rootDevUnit
      "local-fs-pre.target" # let any resume check finish before altering data
    ];
    script = ''
      mkdir -p /btrfs_tmp
      mount -t btrfs -o subvol=/ ${rootDev} /btrfs_tmp
      trap 'umount /btrfs_tmp' EXIT
      if [ -e /btrfs_tmp/@ ]; then
        btrfs subvolume delete --recursive /btrfs_tmp/@
      fi
      if [ -e /btrfs_tmp/@root-blank ]; then
        btrfs subvolume snapshot /btrfs_tmp/@root-blank /btrfs_tmp/@
      else
        btrfs subvolume create /btrfs_tmp/@
      fi
    '';
  };

  # impermanence asserts this; disko's btrfs output sets only device/fsType/options.
  fileSystems."/persist".neededForBoot = true;

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/var/lib/nixos" # uid/gid maps — without this, users get renumbered on every boot
      "/var/lib/sbctl" # Secure Boot signing keys (lanzaboote pkiBundle)
      "/var/lib/bluetooth" # pairings: headphones, keyboard, mouse
      "/var/lib/iwd" # Wi-Fi network profiles
      "/etc/NetworkManager/system-connections"
      "/var/log" # bounded journal, see below
      {
        directory = "/var/lib/private";
        mode = "0700";
      } # DynamicUser service state (e.g. mihomo); mode works around impermanence #254/#93
    ];
    files = [ "/etc/machine-id" ];
  };

  # Journal: persistent but bounded — enough for auditing, not an unbounded history.
  # Set Storage = "volatile" for RAM-only logs.
  services.journald.settings.Journal = {
    Storage = "persistent";
    SystemMaxUse = "256M";
    MaxRetentionSec = "14day";
  };
}
