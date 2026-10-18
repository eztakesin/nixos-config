# Host: cobalt — Acer Aspire 3 A315-24P-R70F (chassis N23C3).
#   Ryzen 3 7320U (Zen2 "Mendocino") · Radeon 610M (RDNA2) · 16 GB LPDDR5 soldered
#   Wi-Fi/BT: MediaTek MT7902 (in-tree driver since Linux 7.1, see hardware.nix).
# Storage/crypto/boot model: https://nixos.ssf.network/reference/architecture/
{ inputs, my, lib, pkgs, ... }:
{
  imports = [
    ./hardware.nix # nixos-hardware common-* + firmware + device quirks
    ./disko.nix # declarative partition / LUKS2 / LVM / btrfs layout
    ../../modules/nixos # the shared hardened module set
  ];

  # Kernel: owned by modules/nixos/hardening/kernel.nix — the stock, cache-served `linuxPackages_testing`
  # (it carries the in-tree MT7902 driver). A self-compiled hardened kernel is defined there but not used
  # until an x86_64 builder and a binary cache exist.

  # The hostname is the operator's choice (my/default.nix); it need not match the `cobalt` codename.
  networking.hostName = my.hostName;

  time.timeZone = my.user.timeZone;

  # The NixOS release whose stateful defaults this host was built against. Do NOT bump casually.
  system.stateVersion = "26.05";
}
