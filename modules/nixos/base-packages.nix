# System-wide baseline. uutils (Rust coreutils) outranks GNU coreutils in PATH via hiPrio — no NixOS
# module exists for this yet, which is the idiomatic approach.
{ pkgs, lib, ... }:
{
  environment.systemPackages = with pkgs; [
    (lib.hiPrio uutils-coreutils-noprefix)
    uutils-findutils
    uutils-diffutils
    git
    file
    tree
    pciutils
    usbutils
    smartmontools
    cryptsetup
    btrfs-progs
    lm_sensors
  ];
}
