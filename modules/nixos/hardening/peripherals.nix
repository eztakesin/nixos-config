# Peripheral hardening: USB device policy, Bluetooth kept but tightened, DMA/IOMMU,
# unused kernel modules disabled, firmware updates.
{ pkgs, lib, my, ... }:
let
  # Protocols and filesystems this laptop never uses. A blacklist only stops autoloading, so an
  # `install … false` rule is added as well to refuse explicit loads.
  unusedModules = [
    "firewire_core"
    "firewire_ohci"
    "ax25"
    "netrom"
    "rose"
    "dccp"
    "sctp"
    "rds"
    "tipc"
    "cramfs"
    "freevxfs"
    "jffs2"
    "hfs"
    "hfsplus"
    "udf"
  ];
in
{
  # ── USB ──────────────────────────────────────────────────────────────────────
  # Devices present at boot (boot key, internal webcam/BT, a plugged-in YubiKey) are kept; anything
  # inserted later is blocked until allowed (`usbguard allow-device <id>` or the desktop notifier).
  # Generate a full allow-list on the real machine with `usbguard generate-policy` and merge it here.
  services.usbguard = {
    enable = true;
    implicitPolicyTarget = "block";
    presentDevicePolicy = "keep";
    presentControllerPolicy = "keep";
    insertedDevicePolicy = "apply-policy";
    IPCAllowedUsers = [
      "root"
      my.user.username
    ];
    dbus.enable = true; # for usbguard-notifier / applets
    rules = ''
      allow id 1050:*
    '';
  };
  environment.systemPackages = [ pkgs.usbguard-notifier ];

  # ── Bluetooth (kept: headphones, keyboard, mouse) ─────────────────────────────
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false; # radio off until turned on
    settings.General = {
      Privacy = "device"; # use resolvable private addresses where the adapter supports it
      JustWorksRepairing = "never"; # refuse silent re-pairing of an already-paired address
      FastConnectable = false;
      Experimental = true; # battery level reporting for headphones
    };
  };

  # ── DMA / IOMMU ──────────────────────────────────────────────────────────────
  # The A315-24P has no Thunderbolt; still force the IOMMU on for DMA isolation of internal devices.
  boot.kernelParams = [
    "amd_iommu=on"
    "iommu=force"
  ];

  # ── Unused kernel modules ────────────────────────────────────────────────────
  boot.blacklistedKernelModules = unusedModules;
  boot.extraModprobeConfig = lib.concatMapStringsSep "\n" (
    m: "install ${m} ${pkgs.coreutils}/bin/false"
  ) unusedModules;

  # ── Firmware updates ─────────────────────────────────────────────────────────
  services.fwupd.enable = true;
}
