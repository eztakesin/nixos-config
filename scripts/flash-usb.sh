#!/bin/sh
# flash-usb.sh — write the cobalt installer image to a TEMPORARY USB stick (bootstrap medium).
# Works on macOS and Linux with only the OS's own tools + dd. The key stick itself is laid out later by
# disko from the running installer (hosts/cobalt/disko.nix); see https://nixos.ssf.network/runbook/install/.
#
#   usage: flash-usb.sh <installer.iso> <device>
#          macOS:  device = diskN      (whole disk, e.g. disk4 — never disk4s1)
#          Linux:  device = /dev/sdX   (whole disk, e.g. /dev/sdb — never /dev/sdb1)
#
# Safety: refuses internal/non-removable disks, disks that back / or /boot, and asks you to retype the
# device id. dd never asks anything, so this script does. STATUS: used on macOS for the laptop's install (2026-10-25).
set -eu

iso=${1:-}
dev=${2:-}
[ -n "$iso" ] && [ -n "$dev" ] || { echo "usage: $0 <installer.iso> <device>" >&2; exit 2; }
[ -f "$iso" ] || { echo "no such image: $iso" >&2; exit 2; }

confirm() {
  printf '%s\n' "$1"
  printf 'Type the device id exactly (%s) to continue, anything else aborts: ' "$2"
  read -r ans
  [ "$ans" = "$2" ] || { echo "aborted."; exit 1; }
}

case "$(uname)" in
Darwin)
  case "$dev" in
  disk0|disk1) echo "refusing $dev: internal disk" >&2; exit 1 ;;
  disk[0-9]*) ;;
  *) echo "device must look like diskN" >&2; exit 2 ;;
  esac
  case "$dev" in *s[0-9]*) echo "give the whole disk (diskN), not a slice" >&2; exit 2 ;; esac
  info=$(diskutil info -plist "$dev")
  printf '%s' "$info" | grep -A1 '<key>Internal</key>' | grep -q '<false/>' || { echo "refusing $dev: not external" >&2; exit 1; }
  printf '%s' "$info" | grep -A1 '<key>RemovableMedia</key>' | grep -q '<true/>' || { echo "refusing $dev: not removable" >&2; exit 1; }
  diskutil info "$dev" | grep -E 'Device / Media Name|Disk Size|Volume Name' || true
  confirm "This will ERASE everything on $dev and write $iso." "$dev"
  diskutil unmountDisk "/dev/$dev"
  echo "writing… (press Ctrl+T for progress)"
  sudo dd if="$iso" of="/dev/r$dev" bs=1m
  sync
  diskutil eject "/dev/$dev"
  ;;
Linux)
  case "$dev" in /dev/*) ;; *) echo "device must be a /dev path" >&2; exit 2 ;; esac
  name=$(basename "$dev")
  [ -b "$dev" ] || { echo "not a block device: $dev" >&2; exit 2; }
  case "$name" in *[0-9]) [ -e "/sys/block/$name" ] || { echo "give the whole disk, not a partition" >&2; exit 2; } ;; esac
  [ "$(cat "/sys/block/$name/removable" 2>/dev/null)" = "1" ] || { echo "refusing $dev: not removable" >&2; exit 1; }
  tran=$(lsblk -dno TRAN "$dev" 2>/dev/null || true)
  [ "$tran" = "usb" ] || { echo "refusing $dev: transport is '$tran', not usb" >&2; exit 1; }
  for mp in / /boot /nix /persist; do
    src=$(findmnt -no SOURCE "$mp" 2>/dev/null || true)
    case "$src" in "$dev"*) echo "refusing $dev: it backs $mp" >&2; exit 1 ;; esac
  done
  lsblk -o NAME,SIZE,MODEL,TRAN,MOUNTPOINTS "$dev"
  confirm "This will ERASE everything on $dev and write $iso." "$dev"
  for p in "$dev"?*; do [ -e "$p" ] && umount "$p" 2>/dev/null || true; done
  dd if="$iso" of="$dev" bs=4M status=progress oflag=sync conv=fsync
  sync
  ;;
*)
  echo "unsupported OS: $(uname)" >&2; exit 2 ;;
esac
echo "done. Boot the laptop from this stick, then run: sudo /etc/cobalt/install.sh"
