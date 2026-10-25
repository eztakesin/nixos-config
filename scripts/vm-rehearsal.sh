#!/bin/sh
# vm-rehearsal.sh — rehearse cobalt's first-install flow in a QEMU virtual machine before touching the
# laptop (https://nixos.ssf.network/runbook/vm-rehearsal/). Two sparse disk images stand in for the two real devices:
#
#   usb.qcow2   32G  the KEY STICK    — USB mass storage behind an xHCI controller, so the guest sees a
#                    removable disk with a /dev/disk/by-id/usb-* name (what my/private.nix expects);
#   nvme.qcow2  64G  the INTERNAL SSD — an NVMe controller (/dev/disk/by-id/nvme-*).
#
# The installer ISO is a SATA CD-ROM. The firmware is OVMF (EDK2) with a writable copy of its variable
# store, so EFI boot entries and Secure Boot state survive between `install` and `boot` like real NVRAM.
#
#   usage: vm-rehearsal.sh prepare <installer.iso>   create the disks + fresh UEFI variables in the work dir
#          vm-rehearsal.sh install [installer.iso]   boot the ISO with both disks attached (the first install)
#          vm-rehearsal.sh boot                      boot the installed system from the two disks (no ISO)
#
# Environment (all optional):
#   COBALT_VM_DIR       work dir (default ./vm, which .gitignore excludes)
#   COBALT_VM_OVMF      OVMF directory containing FV/OVMF_CODE.fd and FV/OVMF_VARS.fd
#                       (default $COBALT_VM_DIR/ovmf, i.e. the `nix build … -o vm/ovmf` result link)
#   COBALT_VM_QEMU      qemu-system-x86_64 to run (default: PATH; `nix shell nixpkgs#qemu`)
#   COBALT_VM_QEMU_IMG  qemu-img to run (default: PATH)
#   COBALT_VM_MEM       guest RAM in QEMU syntax (default 4G)
#   COBALT_VM_CPUS      guest CPUs (default 4)
#   COBALT_VM_ACCEL     accelerator (default: kvm when /dev/kvm exists, else tcg)
#   COBALT_VM_SMM       1 = always add the SMM/Secure Boot flags, 0 = never (default: add them when the
#                       firmware descriptor shipped with OVMF says "requires-smm", i.e. an OVMFFull build)
#   COBALT_VM_HEADLESS  1 = no graphics window (-display none); the serial console on stdio remains
#   COBALT_VM_FORCE     1 = `prepare` replaces an existing rehearsal without asking
#   COBALT_VM_DRY_RUN   1 = print the QEMU command line instead of running it
#   COBALT_VM_EXTRA     extra QEMU arguments appended verbatim (word-split)
#   COBALT_VM_SERIAL    chardev for the serial console instead of this terminal (unattended runs), e.g.
#                       pipe:/path/serial — QEMU then reads /path/serial.in and writes /path/serial.out
#                       (two FIFOs made with mkfifo) and the monitor listens on $COBALT_VM_DIR/monitor.sock
#   COBALT_VM_OFFLINE   1 = no network for the guest (user-mode NAT with restrict=on): the install has to
#                       work from the embedded closure alone
#   COBALT_VM_UKI       install mode: boot this UKI (`nix build .#images.installer-uki`) directly through the
#                       firmware instead of the ISO's GRUB menu; the ISO stays attached as the live medium
#   COBALT_VM_CMDLINE_EXTRA  with COBALT_VM_UKI: appended to the UKI's kernel command line through the
#                       SMBIOS string io.systemd.stub.kernel-cmdline-extra (systemd-stub(7), Secure Boot off)
#
# Every flag is checked against qemu(1) of QEMU 11.1 and the sources cited inline: nixpkgs 319e4ce
# (2026-10-14) nixos/tests/systemd-initrd-luks-fido2.nix, nixos/tests/boot.nix, nixos/tests/iosched.nix,
# nixos/lib/qemu-common.nix, nixos/modules/virtualisation/qemu-vm.nix, pkgs/applications/virtualization/OVMF;
# the QEMU manual chapters system/devices/{usb,nvme,canokey} and system/bootindex; edk2 OvmfPkg/README
# ("SMM support") and OvmfPkg/Library/QemuBootOrderLib. STATUS: install phase rehearsed on 2026-10-17 (unattended mode, TCG on an Apple-silicon host); first boot pending.
set -eu

WORK=${COBALT_VM_DIR:-./vm}
USB_IMG=$WORK/usb.qcow2
NVME_IMG=$WORK/nvme.qcow2
EFIVARS=$WORK/efivars.fd           # writable copy of OVMF_VARS.fd = the VM's NVRAM
CANOKEY_STATE=$WORK/canokey-state  # state of the emulated FIDO2 token (only if QEMU has canokey support)
ISO_LINK=$WORK/installer.iso       # recorded by `prepare`, the default for `install`
OVMF_DIR=${COBALT_VM_OVMF:-$WORK/ovmf}
QEMU=${COBALT_VM_QEMU:-qemu-system-x86_64}
QEMU_IMG=${COBALT_VM_QEMU_IMG:-qemu-img}
MEM=${COBALT_VM_MEM:-4G}
CPUS=${COBALT_VM_CPUS:-4}
USB_SIZE=32G
NVME_SIZE=64G
# Serial numbers → stable names in the guest (udev: usb-<vendor>_<model>_<serial>-0:0 and nvme-<model>_<serial>;
# QEMU's vendor/model strings are "QEMU"/"QEMU HARDDISK" and "QEMU NVMe Ctrl"). Expected, not guaranteed —
# confirm with `ls -l /dev/disk/by-id/` inside the guest before writing my/private.nix:
#   /dev/disk/by-id/usb-QEMU_QEMU_HARDDISK_cobaltvmusb-0:0
#   /dev/disk/by-id/nvme-QEMU_NVMe_Ctrl_cobaltvmnvme
USB_SERIAL=cobaltvmusb
NVME_SERIAL=cobaltvmnvme

say() { printf '\n== %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }
usage() {
  echo "usage: $0 prepare <installer.iso> | install [installer.iso] | boot" >&2
  exit 2
}

# Absolute path without realpath(1), which is not POSIX.
abspath() { case $1 in /*) printf '%s\n' "$1" ;; *) printf '%s/%s\n' "$PWD" "$1" ;; esac; }

need() { command -v "$1" >/dev/null 2>&1 || die "$1 not found. $2"; }

# OVMF as packaged by nixpkgs: the `fd` output holds FV/OVMF_CODE.fd (firmware, used read-only) and
# FV/OVMF_VARS.fd (variable template without any key → Setup Mode) — pkgs/applications/virtualization/OVMF,
# passthru.firmware / passthru.variables. Distribution packages ship the same two files without the FV/ dir.
find_ovmf() {
  for d in "$OVMF_DIR/FV" "$OVMF_DIR"; do
    if [ -f "$d/OVMF_CODE.fd" ] && [ -f "$d/OVMF_VARS.fd" ]; then
      OVMF_CODE=$d/OVMF_CODE.fd
      OVMF_VARS=$d/OVMF_VARS.fd
      return 0
    fi
  done
  die "OVMF firmware not found under $OVMF_DIR (expected FV/OVMF_CODE.fd + FV/OVMF_VARS.fd). Obtain it with
  nix build nixpkgs#OVMF.fd -o $WORK/ovmf                                # on an x86_64-linux host
  nix build nixpkgs#legacyPackages.x86_64-linux.OVMF.fd -o $WORK/ovmf    # on macOS (binary cache / linux-builder)
(OVMFFull.fd instead of OVMF.fd to rehearse Secure Boot — https://nixos.ssf.network/runbook/vm-rehearsal/)"
}

# Secure-Boot-capable OVMF builds (nixpkgs OVMFFull: secureBoot = true → SMM_REQUIRE) need
# `-machine q35,smm=on` and a write-protected variable flash: OvmfPkg/README "SMM support" lists exactly
# "-machine q35,smm=on,accel=(tcg|kvm)" and "-global driver=cfi.pflash01,property=secure,value=on";
# nixos/modules/virtualisation/qemu-vm.nix adds the same pair when OVMF.systemManagementModeRequired.
# nixpkgs installs a QEMU firmware descriptor next to the images whose "features" list says "requires-smm".
smm_required() {
  case ${COBALT_VM_SMM:-} in
    1) return 0 ;;
    0) return 1 ;;
  esac
  for f in "$OVMF_DIR"/share/qemu/firmware/*.json; do
    if [ -f "$f" ] && grep -q 'requires-smm' "$f"; then return 0; fi
  done
  return 1
}

# Accelerator: KVM exists only on a Linux host with /dev/kvm. Everywhere else — including Apple-silicon
# macOS, where an x86_64 guest can only be interpreted — it is QEMU's TCG (slow software emulation).
# qemu(1) -accel: "kvm, xen, hvf, … or tcg can be available. By default, tcg is used."
# nixos/lib/qemu-common.nix runs its x86_64 guests with "-machine accel=kvm:tcg -cpu max".
accel() {
  if [ -n "${COBALT_VM_ACCEL:-}" ]; then
    printf '%s\n' "$COBALT_VM_ACCEL"
  elif [ -e /dev/kvm ]; then
    echo kvm
  else
    echo tcg
  fi
}

# A QEMU built with --enable-canokey (nixpkgs: qemu.override { canokeySupport = true; }, the package the
# nixpkgs FIDO2 test uses as qemu_test.override { canokeySupport = true; }) lists the device.
has_canokey() {
  command -v "$QEMU" >/dev/null 2>&1 && "$QEMU" -device help 2>/dev/null | grep -q '^name "canokey"'
}

cmd_prepare() {
  iso=${1:-}
  [ -n "$iso" ] || usage
  [ -f "$iso" ] || die "no such image: $iso"
  need "$QEMU_IMG" "Install QEMU (nix shell nixpkgs#qemu) or set COBALT_VM_QEMU_IMG."
  find_ovmf
  mkdir -p "$WORK"
  if [ -e "$USB_IMG" ] || [ -e "$NVME_IMG" ] || [ -e "$EFIVARS" ]; then
    if [ "${COBALT_VM_FORCE:-0}" != 1 ]; then
      printf 'A rehearsal already exists in %s. Type "erase" to replace it (disks, NVRAM, token state): ' "$WORK"
      read -r ans
      [ "$ans" = erase ] || die "aborted"
    fi
    rm -f "$USB_IMG" "$NVME_IMG" "$EFIVARS" "$CANOKEY_STATE" "$ISO_LINK"
  fi

  # qemu-img(1) create: "Create the new disk image FILE of size SIZE and format FMT". qcow2 allocates
  # clusters on first write, so both files start at a few hundred KiB.
  say "creating sparse disks in $WORK"
  "$QEMU_IMG" create -f qcow2 "$USB_IMG" "$USB_SIZE"
  "$QEMU_IMG" create -f qcow2 "$NVME_IMG" "$NVME_SIZE"

  # The variable store must be a private writable copy (qemu-vm.nix copies cfg.efi.variables to
  # $NIX_EFI_VARS the same way). A fresh copy = empty NVRAM: no boot entries, Secure Boot in Setup Mode.
  say "fresh UEFI variables from $OVMF_VARS"
  cp "$OVMF_VARS" "$EFIVARS"
  chmod 644 "$EFIVARS"
  ln -sfn "$(abspath "$iso")" "$ISO_LINK"

  say "ready"
  echo "  disks:     $USB_IMG ($USB_SIZE), $NVME_IMG ($NVME_SIZE)"
  echo "  firmware:  $OVMF_CODE"
  if smm_required; then echo "  secure boot: SMM build detected — the Secure Boot flags will be added"; \
  else echo "  secure boot: plain OVMF build — the guest will report Secure Boot as unsupported/disabled"; fi
  echo "  accel:     $(accel)"
  if has_canokey; then echo "  fido2:     emulated token available (canokey)"; \
  else echo "  fido2:     none — install with COBALT_SKIP_FIDO2=1 (see the runbook)"; fi
  echo "  next:      $0 install"
}

run_vm() {
  mode=$1
  find_ovmf
  [ -f "$USB_IMG" ] && [ -f "$NVME_IMG" ] && [ -f "$EFIVARS" ] \
    || die "no rehearsal in $WORK — run: $0 prepare <installer.iso>"
  if [ "${COBALT_VM_DRY_RUN:-0}" != 1 ]; then
    need "$QEMU" "Install QEMU (nix shell nixpkgs#qemu) or set COBALT_VM_QEMU."
  fi
  ACCEL=$(accel)
  machine=q35
  if smm_required; then machine=q35,smm=on; fi
  usb_boot=
  [ "$mode" = boot ] && usb_boot=,bootindex=0

  # Machine, accelerator, CPU, memory: -machine q35 = PCIe chipset with an AHCI SATA controller (the
  # CD-ROM) and the only machine type OVMF's SMM build supports (OvmfPkg/README). -cpu max = every feature
  # the accelerator can provide (qemu-common.nix). -m accepts a G suffix, -smp a plain count (qemu(1)).
  set -- "$QEMU" -name cobalt-rehearsal -machine "$machine" -accel "$ACCEL" -cpu max -m "$MEM" -smp "$CPUS"

  # UEFI firmware: code and variables as two pflash units, only the variables writable — the pattern of
  # qemu-vm.nix (useEFIBoot) and OvmfPkg/README. With an SMM build the variable flash is additionally
  # write-protected from the guest OS (-global …,property=secure,value=on; same sources).
  set -- "$@" \
    -drive "if=pflash,format=raw,unit=0,readonly=on,file=$OVMF_CODE" \
    -drive "if=pflash,format=raw,unit=1,readonly=off,file=$EFIVARS"
  if [ "$machine" != q35 ]; then
    set -- "$@" -global driver=cfi.pflash01,property=secure,value=on
  fi

  # The key stick: USB mass storage (bulk-only transport, like most sticks) on an xHCI controller — QEMU
  # docs system/devices/usb: "XHCI supports USB 1.1, USB 2.0 and USB 3.0 devices, so this is the only
  # controller you need"; the bus of a controller with id=xhci is xhci.0. removable=on → the guest reports
  # the disk as removable; serial= → the USB serial number udev turns into the by-id name; bootindex=0 (boot
  # mode) → first in the fw_cfg boot order, which OVMF translates for USB storage (QemuBootOrderLib).
  # Properties checked with `-device usb-storage,help`; the drive/device split is nixos/tests/boot.nix's.
  # id=usbkeydev lets the monitor detach the stick (device_del usbkeydev), as the spare-stick rehearsal does.
  # A usb-tablet gives the graphics window an absolute pointer (qemu-vm.nix adds one on x86 as well).
  set -- "$@" \
    -drive "if=none,id=usbkey,format=qcow2,file=$USB_IMG" \
    -device qemu-xhci,id=xhci \
    -device "usb-storage,bus=xhci.0,drive=usbkey,removable=on,serial=$USB_SERIAL$usb_boot,id=usbkeydev" \
    -device usb-tablet,bus=xhci.0

  # The SSD: an NVMe controller with one namespace — nixos/tests/iosched.nix "nvme,serial=…,drive=…", QEMU
  # docs system/devices/nvme (model "QEMU NVMe Ctrl"). 512-byte logical / 4 KiB physical sectors mimic the
  # SN740 (512e), the assumption behind disko's `--sector-size 4096` (hosts/cobalt/disko.nix).
  set -- "$@" \
    -drive "if=none,id=nvme0,format=qcow2,file=$NVME_IMG" \
    -device "nvme,drive=nvme0,serial=$NVME_SERIAL,logical_block_size=512,physical_block_size=4096"

  case $mode in
    install)
      # The live medium as a SATA CD-ROM with the highest boot priority. OVMF reads the fw_cfg "bootorder"
      # list that bootindex= builds and translates Q35 SATA paths (QemuBootOrderLib "Q35 SATA"); `-boot
      # order=d` would not be used for that: qemu(1) -boot says order "should not be used together with the
      # bootindex property". Without bus=, QEMU puts the device on the first free port of the q35 AHCI.
      cd_boot=0
      if [ -n "${COBALT_VM_UKI:-}" ]; then
        # -kernel registers the linuxboot option ROM itself at bootindex 0 (QEMU hw/i386/x86.c,
        # x86_load_linux — "The bootindex 0 has already been used" otherwise), so the medium takes 1; OVMF
        # runs the fw_cfg kernel before any boot option anyway (OvmfPkg PlatformBootManagerLib,
        # TryRunningQemuKernel).
        cd_boot=1
      fi
      set -- "$@" \
        -drive "if=none,id=cd0,format=raw,media=cdrom,readonly=on,file=$ISO" \
        -device "ide-cd,drive=cd0,bootindex=$cd_boot"
      if [ -n "${COBALT_VM_UKI:-}" ]; then
        # Direct boot of a UKI through fw_cfg: OVMF loads the -kernel blob as a UEFI application
        # (OvmfPkg/Library/QemuLoadImageLib, "kernel" fw_cfg item), so the systemd-stub inside the UKI runs
        # exactly as it would from the key stick's ESP; the live medium is still the ISO (root by label),
        # only its GRUB menu is skipped. systemd-stub(7), "SMBIOS Type 11 strings": with Secure Boot off,
        # io.systemd.stub.kernel-cmdline-extra=… is appended to the embedded command line — the way to get
        # console=ttyS0 without editing anything (qemu(1) -smbios type=11,value=…).
        set -- "$@" -kernel "$COBALT_VM_UKI"
        if [ -n "${COBALT_VM_CMDLINE_EXTRA:-}" ]; then
          # qemu(1) option syntax: a comma inside a value is written as ",," (console=ttyS0,115200n8 would
          # otherwise be cut at the comma — "Invalid parameter '115200n8'").
          extra=$(printf '%s' "$COBALT_VM_CMDLINE_EXTRA" | sed 's/,/,,/g')
          set -- "$@" -smbios "type=11,value=io.systemd.stub.kernel-cmdline-extra=$extra"
        fi
      fi
      ;;
    boot) ;;
  esac

  # User-mode networking (NAT, no privileges — qemu(1) -netdev user) on a virtio NIC, as in
  # nixos/tests/boot.nix. The host is reachable from the guest as 10.0.2.2.
  net=user,id=net0
  if [ "${COBALT_VM_OFFLINE:-0}" = 1 ]; then
    # qemu(1) -netdev user: "restrict=on … isolate the guest from the host network". The NIC stays, so
    # the guest's network stack behaves normally, but nothing gets out: an offline install is really offline.
    net=$net,restrict=on
  fi
  set -- "$@" -netdev "$net" -device virtio-net-pci,netdev=net0

  # Serial console and QEMU monitor multiplexed on this terminal — qemu(1) -serial "mon:dev_string": "The
  # monitor is accessed with key sequence of Control-a and then pressing c"; Ctrl-a h lists the keys, Ctrl-a x
  # quits QEMU, and "Ctrl+C will not terminate QEMU any more but will be passed to the guest". The graphics
  # window stays unless COBALT_VM_HEADLESS=1 (-display none: "The guest will still see an emulated graphics
  # card, but its output will not be displayed").
  if [ -n "${COBALT_VM_SERIAL:-}" ]; then
    # Unattended run: ttyS0 on the given chardev, the monitor on a UNIX socket (qemu(1) -monitor; talk to it
    # with `nc -U`: screendump, sendkey, system_powerdown, quit).
    set -- "$@" -serial "$COBALT_VM_SERIAL" -monitor "unix:$WORK/monitor.sock,server=on,wait=off"
  else
    set -- "$@" -serial mon:stdio
  fi
  if [ "${COBALT_VM_HEADLESS:-0}" = 1 ]; then
    set -- "$@" -display none
  fi

  # Emulated FIDO2 token when this QEMU has canokey support: the device setup of
  # nixos/tests/systemd-initrd-luks-fido2.nix verbatim (a USB 1.1 OHCI controller of its own, then
  # "-device canokey,bus=usb-bus.0,file=…"). QEMU docs system/devices/canokey: "CanoKey QEMU stores all its
  # data on a file of the host … The first time when the file is used, it is created and initialized";
  # the same file must therefore be attached to `install` (enrollment) and `boot` (unlock).
  if has_canokey; then
    set -- "$@" -device pci-ohci,id=usb-bus -device "canokey,bus=usb-bus.0,file=$CANOKEY_STATE"
    say "emulated FIDO2 token attached (state file: $CANOKEY_STATE)"
  else
    say "NOTICE: this QEMU has no canokey device — there is no FIDO2 token in the VM."
    echo "   Run the installer with COBALT_SKIP_FIDO2=1 (passphrase-only unlock); https://nixos.ssf.network/runbook/vm-rehearsal/."
  fi

  if [ -n "${COBALT_VM_EXTRA:-}" ]; then
    # shellcheck disable=SC2086 # word-splitting is intended
    set -- "$@" $COBALT_VM_EXTRA
  fi

  say "$mode: machine=$machine accel=$ACCEL mem=$MEM cpus=$CPUS"
  case $mode in
    install)
      if [ -n "${COBALT_VM_UKI:-}" ]; then
        echo "   booting $COBALT_VM_UKI directly (no GRUB menu)${COBALT_VM_CMDLINE_EXTRA:+; cmdline += $COBALT_VM_CMDLINE_EXTRA}"
      else
        echo "   GRUB menu of the ISO: Options → \"Serial console=ttyS0,115200n8\" → the NixOS entry puts the"
        echo "   installer on this terminal (paste-friendly); otherwise work in the graphics window."
      fi
      ;;
    boot)
      echo "   The installed system has no console=ttyS0: stage 1, the unlock prompt and the login happen"
      echo "   in the graphics window. This terminal only carries the QEMU monitor (Ctrl-a c)."
      ;;
  esac
  printf '  '
  printf ' %s' "$@"
  echo
  if [ "${COBALT_VM_DRY_RUN:-0}" = 1 ]; then exit 0; fi
  exec "$@"
}

cmd_install() {
  ISO=${1:-$ISO_LINK}
  [ -e "$ISO" ] || die "installer image not found: $ISO (give it as an argument or run prepare first)"
  run_vm install
}

cmd_boot() {
  [ $# -eq 0 ] || usage
  run_vm boot
}

case ${1:-} in
  prepare) shift; cmd_prepare "$@" ;;
  install) shift; cmd_install "$@" ;;
  boot) shift; cmd_boot "$@" ;;
  *) usage ;;
esac
