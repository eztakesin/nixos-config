# The key stick after the install.
#  - `sync-key-stick` makes or refreshes a spare stick from the one the system booted from
#    (scripts/sync-key-stick.sh, kept as a plain file so it reads as one; GNU tools ahead of the uutils).
#  - The boot-loader install refuses to run unless /boot is mounted from the stick. When the stick is pulled
#    out after boot, or a spare's partitions are rewritten while both sticks are in, systemd unmounts /boot (an
#    fstab mount is BindsTo= its device), and lanzaboote installs into whatever directory /boot is — its own tests use a
#    plain temporary directory (lanzaboote v1.2.0, rust/tool/systemd/tests/integration). The rebuild would
#    succeed, the boot entry would land on the root filesystem, and the stick would never see the generation.
{ config, lib, pkgs, ... }:
let
  util = pkgs.util-linux;
in
{
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "sync-key-stick";
      runtimeInputs = with pkgs; [
        coreutils
        findutils
        diffutils
        gawk
        gnugrep
        gnused
        util-linux # lsblk, findmnt, blkid, blockdev, mount
        gptfdisk # sgdisk
        dosfstools # mkfs.vfat
        exfatprogs # mkfs.exfat
        rsync
        usbguard
        systemd # udevadm, systemctl
      ];
      text = builtins.readFile ../../scripts/sync-key-stick.sh;
    })
  ];

  # nixos/modules/system/boot/loader/external/external.nix sets installBootLoader = installHook; this runs
  # the same hook after the check. nixos-install calls it inside the target, where /boot is the mounted ESP.
  system.build.installBootLoader = lib.mkForce (
    pkgs.writeShellScript "install-bootloader-on-key-stick" ''
      set -eu
      if ! ${util}/bin/mountpoint -q /boot || [ "$(${util}/bin/findmnt -no FSTYPE /boot)" != vfat ]; then
        echo "error: /boot is not mounted from the key stick, so this generation's boot entry cannot be written." >&2
        echo "       Insert the key stick, run 'sudo sync-key-stick --heal', then run the rebuild again." >&2
        exit 1
      fi
      exec ${config.boot.loader.external.installHook} "$@"
    ''
  );
}
