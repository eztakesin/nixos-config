# Offline-capable live installer for cobalt.
# - carries the FULL cobalt system closure in its store (isoImage.storeContents) plus the generated disko
#   scripts, so install.sh's default mode (`nixos-install --system`, a store copy) needs no network;
# - ships disko, cryptsetup/systemd-cryptenroll, sbctl, age/sops and scripts/install.sh;
# - carries the anonymous rescue system (installer/rescue.nix) that install.sh writes to the key stick —
#   this image itself holds personal data and stays OFF the key stick;
# - uses the "new kernel" ISO profile (linuxPackages_latest ≥ 7.1 → in-tree MT7902 Wi-Fi) without ZFS.
# Build: nix build .#images.installer  (x86_64-linux builder). Flash: scripts/flash-usb.sh <iso> <device>.
# NOTE: the embedded closure must match the real target — build the image from a path reference that
# includes my/private.nix (`nix build path:.#images.installer`) once the disk ids are known.
{
  inputs,
  self,
  cobaltSource,
  config,
  pkgs,
  lib,
  ...
}:
let
  cobalt = self.nixosConfigurations.cobalt;
  rescue = self.nixosConfigurations.rescue.config;
  # Identity of the installer UKI in the systemd-boot menu (boot.c, type #2 entries: title = PRETTY_NAME,
  # version = VERSION_ID, sort key = IMAGE_ID). The NixOS generations carry lanzaboote's sort key and
  # loader.conf keeps `default nixos-*`, so this entry is listed but never selected by default.
  ukiOsRelease = pkgs.writeText "cobalt-installer-os-release" ''
    NAME="cobalt installer"
    ID=cobalt-installer
    IMAGE_ID=cobalt-installer
    PRETTY_NAME="cobalt installer"
    VERSION_ID="${config.system.nixos.label}"
  '';
in
{
  imports = [
    "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal-new-kernel-no-zfs.nix"
  ];

  image.baseName = lib.mkForce "cobalt-installer";
  isoImage = {
    # The volume id is what the installer's own stage 1 looks for: with systemd stage 1, iso-image.nix mounts
    # /dev/disk/by-label/<volumeID> as iso9660 (fileSystems."/iso"); there is no root=LABEL= on the command
    # line. scripts/install.sh therefore writes the iso9660 image itself into the key's installer partition.
    volumeID = "COBALT_INSTALL";
    squashfsCompression = "zstd -Xcompression-level 6";
    storeContents = [ cobalt.config.system.build.toplevel ];
    # The anonymous rescue system (installer/rescue.nix) that install.sh step 7 writes to the key stick: its
    # ISO image for the installer partition and its (unsigned) UKI for the ESP. Plain files on the medium,
    # outside the squashfs, read from /iso/rescue/.
    contents = [
      {
        source = "${rescue.system.build.isoImage}/iso/${rescue.image.baseName}.iso";
        target = "/rescue/rescue.iso";
      }
      {
        source = "${rescue.system.build.uki}/${rescue.system.boot.loader.ukiFile}";
        target = "/rescue/rescue.efi";
      }
    ];
  };

  # Unified Kernel Image of this live system (nixpkgs uki.nix → system.build.uki): kernel, initrd, command
  # line and os-release in ONE PE. Used by the QEMU rehearsal to boot the installer directly
  # (scripts/vm-rehearsal.sh, COBALT_VM_UKI); the key stick gets the rescue system's UKI instead
  # (installer/rescue.nix). The command line is uki.nix's default, `init=<toplevel>/init <boot.kernelParams>`.
  # Build alone: nix build .#images.installer-uki
  boot.uki = {
    name = "cobalt-installer";
    version = null; # fixed file name (no _<version> infix): a reinstall overwrites instead of accumulating
    settings.UKI.OSRelease = "@${ukiOsRelease}";
  };

  # The configuration tree (filtered in flake.nix: no node_modules, build output, .git or local-only
  # directories — `self.outPath` of a `path:` reference carries all of that) and the install script,
  # readable from the live system.
  environment.etc."cobalt/config".source = cobaltSource;
  # What the OFFLINE mode of install.sh consumes: the system closure as built, and the
  # disko scripts generated for exactly this configuration — `disko --mode destroy,format,mount --flake`
  # would evaluate and build the same derivation on the target, needing nixpkgs inputs that no runtime
  # closure contains. Referencing them from /etc pulls them into the image's store.
  environment.etc."cobalt/system".source = cobalt.config.system.build.toplevel;
  # The disko derivations output a directory with the script under bin/ (what the disko CLI runs as
  # "$script"/bin/*); link the scripts themselves so /etc/cobalt/disko-* are directly executable.
  environment.etc."cobalt/disko-destroy-format-mount".source =
    "${cobalt.config.system.build.destroyFormatMount}/bin/disko-destroy-format-mount";
  environment.etc."cobalt/disko-mount".source = "${cobalt.config.system.build.mount}/bin/disko-mount";
  environment.etc."cobalt/install.sh" = {
    source = ../scripts/install.sh;
    mode = "0755";
  };

  environment.systemPackages = with pkgs; [
    disko
    sbctl
    cryptsetup
    age
    sops
    git
    gptfdisk
    dosfstools
    exfatprogs
    e2fsprogs
    btrfs-progs
    lvm2
    yubikey-manager
    jq
    mkpasswd
  ];

  # Wi-Fi via NetworkManager; no remote shell. Do NOT force networking.wireless.enable off: with the
  # wpa_supplicant backend the NetworkManager module turns it on itself and drives the supplicant over
  # D-Bus (nixpkgs networkmanager.nix, "Enable wpa_supplicant but fully control it over DBus") — the
  # hardware survey of 2026-10-17 showed NM failing with "Failed to D-Bus activate wpa_supplicant service"
  # because that line was here.
  networking.networkmanager.enable = true;
  services.openssh.enable = lib.mkForce false;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    fallback = true; # build locally if a path is neither embedded nor reachable
  };
}
