# Kernel hardening = (1) a self-compiled hardened kernel built on the `linux_testing` source, plus
# (2) runtime hardening (sysctls, boot params, security.*).
#
# Why self-compile: nixpkgs REMOVED `linuxPackages_hardened` and the `hardened` profile
# (deprecation PR #383438 → removal #501199). "Hardened" now means rolling our own Kconfig via
# `structuredExtraConfig`. Knobs follow the Kernel Self Protection Project (KSPP) recommended settings
# and Kicksecure security-misc rationale. https://kspp.github.io/Recommended_Settings
# https://github.com/Kicksecure/security-misc  https://wiki.nixos.org/wiki/NixOS_Hardening
#
# BUILD COST: this hardened kernel is NOT served by cache.nixos.org — it must be compiled. That is
# impractical until an x86_64 builder + self-hosted cache (attic/harmonia, `my.cache`) exist, so we DEFAULT
# to the stock cached `linuxPackages_testing` for now. To switch to the self-compiled hardened kernel,
# set:  boot.kernelPackages = pkgs.linuxPackagesFor hardenedKernel;  (the derivation is defined below).
{ pkgs, lib, ... }:
let
  hardenedKernel = pkgs.linux_testing.override {
    # RC Kconfig symbols drift between releases; don't abort the build on a renamed/removed symbol.
    ignoreConfigErrors = true;
    structuredExtraConfig = with lib.kernel; {
      # ── Memory-safety / allocator hardening ──
      SLAB_MERGE_DEFAULT = no; # == slab_nomerge: keep caches separate (limits heap exploitation)
      SLAB_FREELIST_RANDOM = yes;
      SLAB_FREELIST_HARDENED = yes;
      SHUFFLE_PAGE_ALLOCATOR = yes;
      INIT_ON_ALLOC_DEFAULT_ON = yes; # zero on alloc — kills uninitialised-memory info leaks
      INIT_ON_FREE_DEFAULT_ON = yes; # zero on free — limits use-after-free data exposure
      HARDENED_USERCOPY = yes; # bounds-check copies to/from userspace
      FORTIFY_SOURCE = yes; # compile-time + runtime buffer-overflow checks

      # ── Control-flow / layout ──
      STACKPROTECTOR = yes;
      STACKPROTECTOR_STRONG = yes;
      VMAP_STACK = yes; # guard pages around kernel stacks
      SCHED_STACK_END_CHECK = yes;
      RANDOMIZE_BASE = yes; # KASLR
      RANDOMIZE_MEMORY = yes;
      STRICT_KERNEL_RWX = yes;
      STRICT_MODULE_RWX = yes;
      LEGACY_VSYSCALL_NONE = yes; # remove the fixed-address vsyscall ROP gadget

      # ── Integrity / reduce attack surface ──
      BUG_ON_DATA_CORRUPTION = yes;
      SECURITY_DMESG_RESTRICT = yes;
      SECURITY_LOCKDOWN_LSM = yes;
      SECURITY_LOCKDOWN_LSM_EARLY = yes;
      STRICT_DEVMEM = yes;
      IO_STRICT_DEVMEM = yes;
      IOMMU_DEFAULT_DMA_STRICT = yes; # strict IOMMU invalidation (DMA protection)

      # ── Opt-in, heavier (need GCC plugins / can break out-of-tree modules) — enable deliberately ──
      # GCC_PLUGINS = yes; RANDSTRUCT_FULL = yes; GCC_PLUGIN_STACKLEAK = yes;
    };
  };
in
{
  # Stock cached testing kernel for now (the self-compiled hardened kernel is deferred until a
  # builder + cache exist). `hardenedKernel` above stays defined, ready to swap in.
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_testing;

  # ── Runtime hardening: sysctls ────────────────────────────────────────────────
  boot.kernel.sysctl = {
    "kernel.kptr_restrict" = 2; # hide kernel pointers
    "kernel.dmesg_restrict" = 1; # kernel log can leak sensitive info
    "kernel.kexec_load_disabled" = 1; # block live kernel replacement
    "kernel.unprivileged_bpf_disabled" = 1;
    "net.core.bpf_jit_harden" = 2;
    "kernel.yama.ptrace_scope" = 2; # stop cross-process ptrace snooping
    "kernel.io_uring_disabled" = 2; # io_uring is a frequent LPE source
    "kernel.perf_event_paranoid" = 3;
    "kernel.sysrq" = 0; # disable magic SysRq

    # Network-stack hardening (firewall/DNS/MAC live in network.nix — no overlapping keys there)
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
    "net.ipv4.conf.all.accept_redirects" = false;
    "net.ipv4.conf.default.accept_redirects" = false;
    "net.ipv4.conf.all.send_redirects" = false;
    "net.ipv6.conf.all.accept_redirects" = false;
    "net.ipv6.conf.default.accept_redirects" = false;
    "net.ipv4.conf.all.accept_source_route" = false;
    "net.ipv6.conf.all.accept_source_route" = false;
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
    "net.ipv4.tcp_timestamps" = 0; # don't leak uptime/clock
  };

  # ── Runtime hardening: boot parameters ────────────────────────────────────────
  boot.kernelParams = [
    "slab_nomerge"
    "init_on_alloc=1"
    "init_on_free=1"
    "page_alloc.shuffle=1"
    "randomize_kstack_offset=1"
    "vsyscall=none"
    "debugfs=off"
    "lockdown=confidentiality" # Secure Boot pairs with this; blocks reading kernel memory
  ];

  # ── security.* ────────────────────────────────────────────────────────────────
  security.protectKernelImage = true; # disables kexec + hibernation (we use no hibernation)
  security.allowUserNamespaces = true; # KEEP ON: browser/flatpak/bubblewrap sandboxes need it
  # security.lockKernelModules: kept OFF — it blocks hotplug, which would break the USB Wi-Fi/BT dongle
  #   fallback for the MT7902 and any dock. Revisit once hardware is stable.
  # security.forcePageTableIsolation: NOT forced — KPTI mitigates Meltdown, which does not affect AMD Zen2;
  #   forcing it here would only add overhead.

  # No coredumps (they can write secrets/keys to disk).
  systemd.coredump.enable = false;
  security.pam.loginLimits = [
    { domain = "*"; item = "core"; type = "-"; value = "0"; }
  ];
}
