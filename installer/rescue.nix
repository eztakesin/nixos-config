# Generic rescue system for the key stick's installer partition (scripts/install.sh step 7).
#
# The key stick is not encrypted apart from the LUKS header, so whatever sits on it can be read by whoever
# holds it. The full installer (installer/default.nix) carries the whole installed system, and with it user
# names, the e-mail and key fingerprint in the git/GnuPG settings, the time zone and the languages. This
# image carries none of that: no part of the configuration, no user or host names, no disk serials, and no
# project name in labels or boot entries. It only has to unlock and mount the installed system so it can be
# inspected, repaired or rebuilt from the configuration stored inside the encrypted disk
# (/persist/etc/cobalt/config). A full reinstall uses the full installer, kept on a separate stick.
{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
let
  # systemd-boot menu entry of the signed UKI on the key's ESP (type #2 entry: title = PRETTY_NAME).
  osRelease = pkgs.writeText "rescue-os-release" ''
    NAME="NixOS rescue"
    ID=nixos-rescue
    IMAGE_ID=nixos-rescue
    PRETTY_NAME="NixOS rescue system"
    VERSION_ID="${config.system.nixos.label}"
  '';

  # Unlock and mount the installed system under /mnt. The internal disk is found as the only NVMe drive
  # unless given; the header is found by its GPT label, which every clone of the key stick shares.
  rescueMount = pkgs.writeShellApplication {
    name = "rescue-mount";
    runtimeInputs = with pkgs; [
      systemd
      cryptsetup
      lvm2
      btrfs-progs
      util-linux
    ];
    text = ''
      hdr=/dev/disk/by-partlabel/disk-a-usb-reserved
      esp=/dev/disk/by-partlabel/disk-a-usb-ESP
      disk=''${1:-/dev/nvme0n1}
      [ -b "$hdr" ] || { echo "header partition $hdr not found: is the key stick plugged in?" >&2; exit 1; }
      [ -b "$disk" ] || { echo "disk $disk not found; pass it as the first argument" >&2; exit 1; }
      # YubiKey first (PIN + touch); without a token systemd-cryptsetup asks for the passphrase or the
      # recovery key instead.
      if [ ! -e /dev/mapper/cryptroot ]; then
        systemd-cryptsetup attach cryptroot "$disk" - "header=$hdr,fido2-device=auto"
      fi
      vgchange -ay vg
      mkdir -p /mnt
      mount -o subvol=@ /dev/vg/root /mnt
      for sv in home nix persist; do
        mkdir -p "/mnt/$sv"
        mount -o "subvol=@$sv" /dev/vg/root "/mnt/$sv"
      done
      mkdir -p /mnt/var/lib/flatpak /mnt/boot
      mount -o subvol=@flatpak /dev/vg/root /mnt/var/lib/flatpak
      if [ -b "$esp" ]; then mount -o umask=0077 "$esp" /mnt/boot; fi
      echo "mounted under /mnt. The configuration is in /mnt/persist/etc/cobalt/config."
      echo "Note: / of the installed system (@) is reset at every boot; persistent state is under /mnt/persist."
      echo "Enter the system with: nixos-enter --root /mnt"
    '';
  };
in
{
  imports = [
    "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal-new-kernel-no-zfs.nix"
  ];

  image.baseName = lib.mkForce "nixos-rescue";
  isoImage = {
    # What this image's own stage 1 looks for (fileSystems."/iso", by label) once it sits in the key's
    # installer partition. Neutral on purpose, like everything else here.
    volumeID = "NIXOS_RESCUE";
    squashfsCompression = "zstd -Xcompression-level 6";
  };

  # The signed boot entry on the key's ESP: install.sh signs this UKI and places it at EFI/Linux/rescue.efi.
  # lanzaboote's garbage collection only touches EFI/nixos/ and EFI/Linux/nixos-*, so the name must not
  # start with "nixos-".
  boot.uki = {
    name = "rescue";
    version = null;
    settings.UKI.OSRelease = "@${osRelease}";
  };

  environment.systemPackages = [
    rescueMount
  ]
  ++ (with pkgs; [
    cryptsetup
    lvm2
    btrfs-progs
    sbctl
    yubikey-manager
    gptfdisk
    dosfstools
    exfatprogs
    e2fsprogs
    git
    jq
  ]);

  # Wi-Fi via NetworkManager, for an online rebuild from the stored configuration; no remote shell.
  networking.networkmanager.enable = true;
  services.openssh.enable = lib.mkForce false;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
}
