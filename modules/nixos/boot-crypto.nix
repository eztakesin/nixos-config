# Boot chain: Secure Boot via lanzaboote (signed UKIs on systemd-boot), systemd stage-1, and the LUKS2
# unlock by FIDO2. The LUKS device itself is declared by disko (hosts/<host>/disko.nix →
# boot.initrd.luks.devices.cryptroot with header= and fido2-device=auto); this module provides everything
# around it. Verified against nixpkgs 55bfb4d + lanzaboote v1.2.0.
#
# One-time enrollment after the first install (https://nixos.ssf.network/runbook/install/):
#   sbctl create-keys  →  firmware: Secure Boot "Setup Mode" + set a supervisor password  →
#   nixos-rebuild switch  →  sbctl enroll-keys --microsoft  →  reboot, enable Secure Boot  →
#   bootctl status  (expect "Secure Boot: enabled (user)")  →  sbctl verify
{ inputs, pkgs, lib, ... }:
{
  environment.systemPackages = [ pkgs.sbctl ];

  # lanzaboote replaces the stock systemd-boot module; this mkForce is mandatory.
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi = {
    canTouchEfiVariables = true;
    efiSysMountPoint = "/boot"; # the USB key's ESP (disko: disk.a-usb → ESP)
  };
  boot.lanzaboote = {
    enable = true;
    # The tool exactly as lanzaboote CI builds it (its own locked nixpkgs), so it is downloaded from the
    # nix-community cache instead of compiled here (the stub does not build under emulation).
    package = inputs.lanzaboote.packages.${pkgs.stdenv.hostPlatform.system}.lzbt;
    pkiBundle = "/var/lib/sbctl"; # persisted (modules/nixos/impermanence.nix)
  };

  # systemd stage-1, which the FIDO2 unlock path (systemd-cryptenroll + crypttab fido2-device=auto) needs, is
  # the only initrd since nixpkgs removed the scripted one (2026-10); boot.initrd.systemd.enable is gone with it.

  # The ESP and the LUKS header live on the USB key and the YubiKey is a USB HID device, so the initrd
  # needs the USB stack + HID; nvme for the SN740 root. Missing xhci_pci/usb_storage is the classic
  # "device did not appear" stage-1 failure.
  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "usb_storage"
    "uas"
    "usbhid"
    "sd_mod"
  ];

  # LVM-on-LUKS: /dev/vg/root only appears after cryptsetup + LVM activation. The cryptsetup generator
  # gives the mapper device an infinite job timeout but not the LV, so set it on / (26.05 release notes).
  fileSystems."/".options = [ "x-systemd.device-timeout=infinity" ];

  # The header device on the USB is waited for with DefaultDeviceTimeoutSec (90 s by default). Slow USB
  # enumeration must not drop to emergency mode. (With a PIN-protected token, plug the YubiKey in before
  # powering on — systemd issue #43342.)
  boot.initrd.systemd.settings.Manager.DefaultDeviceTimeoutSec = "180s";

  # No hibernation (security.protectKernelImage in hardening/kernel.nix disables it). Swap is the LV
  # inside the LUKS container (declared by disko), supplemented by compressed RAM swap.
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };
}
