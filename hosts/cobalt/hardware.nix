# Hardware tuning for the Acer Aspire 3 A315-24P-R70F.
#   CPU Ryzen 3 7320U (Zen2) · GPU Radeon 610M (RDNA2) · 16 GB LPDDR5 soldered
#   SSD  WD SN740 (Gen4 NVMe, DRAM-less)
#   Wi-Fi/BT  internal MediaTek MT7902 — kept (no hardware swap), driven by the testing kernel
#             (in-tree mt7921e + btmtk since Linux 7.1; blobs in linux-firmware ≥ 20260309).
# nixos-hardware has NO module for this exact model → compose the generic common-* modules.
# Sources: nixos-hardware flake.nix.
{ inputs, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-amd # amd microcode (gated on redistributable firmware)
    inputs.nixos-hardware.nixosModules.common-cpu-amd-pstate # amd_pstate=active on kernel >= 6.3
    inputs.nixos-hardware.nixosModules.common-gpu-amd # amdgpu + hardware.graphics
    inputs.nixos-hardware.nixosModules.common-pc-laptop # TLP unless power-profiles-daemon is on
    inputs.nixos-hardware.nixosModules.common-pc-ssd # fstrim (good for the SN740)
  ];

  # Firmware: AMD microcode, Radeon 610M, and the MediaTek MT7902 blobs
  # (mediatek/WIFI_MT7902_patch_mcu_1_1_hdr.bin, WIFI_RAM_CODE_MT7902_1.bin, BT_RAM_CODE_MT7902_1_1_hdr.bin).
  hardware.enableRedistributableFirmware = true;

  # GPU (RDNA2, VCN3 → AV1/HEVC/VP9 decode via mesa radeonsi). `hardware.graphics` is the 24.11+ name.
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Power: KDE → power-profiles-daemon (integrates with amd-pstate-epp). Must NOT also run TLP;
  # common-pc-laptop disables TLP automatically when PPD is enabled.
  services.power-profiles-daemon.enable = true;

  # initrd modules (USB stack for the boot key + YubiKey, nvme for the root) are set in
  # modules/nixos/boot-crypto.nix. The Wi-Fi driver is a normal-boot module, not needed in the initrd.

  # Known quirks on this model:
  #   - MT7902 Wi-Fi/BT may drop / re-authenticate / btmtk may crash even in-tree → USB dongle fallback
  #   - internal mic may be silent (AMD digital-mic-over-ACP; may need sof-firmware)
  #   - touchpad (I2C-HID) may die after suspend: `modprobe -r i2c_hid && modprobe i2c_hid`
  #   - s2idle only; SN740 + A315: watch for "NVMe not visible until a suspend/wake cycle" (nvme APST;
  #     if it bites, try boot.kernelParams = [ "nvme_core.default_ps_max_latency_us=0" ])
}
