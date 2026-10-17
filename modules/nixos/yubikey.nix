# YubiKey support on the system side: pcscd for the smart-card interface (gpg via scdaemon with
# disable-ccid, ykman, age-plugin-yubikey), FIDO2 udev rules, and the management tools.
# The LUKS FIDO2 unlock itself needs none of this (systemd-cryptsetup talks to the token directly).
{ pkgs, ... }:
{
  services.pcscd.enable = true;
  services.udev.packages = [ pkgs.yubikey-personalization ];
  environment.systemPackages = with pkgs; [
    yubikey-manager
    age-plugin-yubikey
    age
    sops
  ];
}
