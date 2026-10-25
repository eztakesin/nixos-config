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
  # inserted later is blocked unless a rule allows it. Rules: every Yubico device, then the exact rules for
  # the operator's own devices from my/private.nix (`usbguard.rules`: they name serial numbers, so they stay
  # out of the public repository). A blocked device can be admitted until it is unplugged:
  # `sudo usbguard list-devices --blocked`, then `sudo usbguard allow-device <number>`.
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
    dbus.enable = true; # for usbguard-notifier
    rules = ''
      allow id 1050:*
    ''
    + (my.usbguard.rules or "");
  };
  environment.systemPackages = [ pkgs.usbguard-notifier ];

  # usbguard-notifier: a desktop notice for every blocked device, with Allow and Reject buttons; Allow admits it
  # until it is unplugged, like the command above. The package's own unit sits in share/systemd/user, where
  # NixOS does not look, so it is declared here, for the operator only: the one account besides root allowed
  # on the IPC socket.
  systemd.user.services.usbguard-notifier = {
    description = "USBGuard notifier";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    unitConfig.ConditionUser = my.user.username;
    serviceConfig = {
      ExecStart = "${pkgs.usbguard-notifier}/bin/usbguard-notifier";
      Restart = "on-failure";
    };
  };

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
