#!/usr/bin/env bash
# sync-key-stick — make or refresh a SPARE key stick from the key stick the running system booted from.
# Installed as the command `sync-key-stick` (modules/nixos/key-stick.nix wraps this file with its tools).
#
# What is copied (the layout is hosts/cobalt/disko.nix; the system finds its parts by GPT partition label,
# never by USB serial, so a spare needs the same labels and the same bytes, not the same stick):
#   partition 1  disk-a-usb-ESP        the /boot files (signed boot entries, kernels, initrds, rescue.efi)  rsync
#   partition 2  disk-a-usb-reserved   the detached LUKS2 header, 32 MiB, raw                               dd
#   partition 3  disk-a-usb-installer  the rescue system (iso9660 image, label NIXOS_RESCUE)               dd: with
#                                      --init or --rescue, or when the spare has no NIXOS_RESCUE yet
#   partition 4  disk-a-usb-interop    exFAT exchange area: created by --init, never synced
#
# Two sticks with the same labels confuse the running system. udev may point /dev/disk/by-partlabel/* at the
# spare, and when the spare's partitions are created or re-read, systemd can take /boot's device for gone and
# unmount /boot (fstab mounts are BindsTo= their device unit). The VM rehearsal of 2026-10-25 saw it during
# --init, where the first version of this command then copied an empty /boot; plugging an existing spare in
# and out did not unmount /boot there. So the live stick is resolved by
# kernel device name before the spare is touched, /boot is copied from a private bind mount taken first, and
# at the end the command waits until the spare is unplugged and puts the links and /boot back on the key
# stick. `sync-key-stick --heal` does that last step on its own.
#
# Safety: the target must be a whole, removable USB disk that is not the live key stick, not mounted and not
# backing any filesystem of the running system; its path is typed again before anything is written; --init
# also asks for the word "erase". Every copy is read back from the spare and compared with its source.
# STATUS: rehearsed in the QEMU VM (https://nixos.ssf.network/runbook/vm-rehearsal/).
set -euo pipefail

LABELS=(disk-a-usb-ESP disk-a-usb-reserved disk-a-usb-installer disk-a-usb-interop)
HEADER_BYTES=$((32 * 1024 * 1024))

usage() {
  cat <<'EOT'
usage: sync-key-stick                  list the USB disks present and what the USB policy blocks
       sync-key-stick --allow ID       admit blocked USB device ID for this session, then list again
       sync-key-stick [--rescue] DEV   refresh the spare DEV: /boot and the LUKS header (--rescue: the rescue system too)
       sync-key-stick --init DEV       ERASE DEV, lay it out like the key stick, copy everything
       sync-key-stick --heal           after a spare was unplugged: links and /boot back on the key stick
EOT
  exit 2
}
say() { printf '\n== %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }
part() { # partition N of a whole-disk device: /dev/sdb → /dev/sdb1, /dev/nvme0n1 → /dev/nvme0n1p1
  case $1 in *[0-9]) printf '%sp%s\n' "$1" "$2" ;; *) printf '%s%s\n' "$1" "$2" ;; esac
}
by_label() { # partition of whole disk $1 carrying GPT label $2 (empty if none)
  lsblk -nro PATH,PARTLABEL "$1" | awk -v l="$2" '$2 == l { print $1; exit }'
}
iso_label() { blkid -p -s LABEL -o value "$1" 2>/dev/null || true; }

list_usb() {
  say "USB disks present"
  lsblk -o PATH,SIZE,MODEL,TRAN,RM,PARTLABEL -e 7 | awk 'NR == 1 || $4 == "usb" || $0 ~ /disk-a-usb/'
  say "USB devices the USB policy is blocking"
  if ! usbguard list-devices -b 2>/dev/null | grep -v '^$'; then
    echo "  (none, or usbguard is not running)"
  fi
  echo
  echo "A spare plugged in after boot is blocked. Admit it for this session with:"
  echo "  sudo sync-key-stick --allow ID      (ID = the number at the start of its line above)"
  echo "then: sudo sync-key-stick [--init] /dev/sdX"
}

# After the spare is gone: udev links and /boot back on the one stick that still carries the labels.
heal() {
  local esps n l link want disk remounted=0
  udevadm trigger --action=change --subsystem-match=block
  udevadm settle
  esps=$(lsblk -nro PATH,PARTLABEL | awk '$2 == "disk-a-usb-ESP" { print $1 }')
  n=$(printf '%s\n' "$esps" | grep -c . || true)
  if [ "$n" = 0 ]; then
    die "no partition labelled disk-a-usb-ESP is visible. Is the key stick inserted? A stick plugged in after boot is blocked by the USB policy: 'sudo sync-key-stick' lists it, 'sudo sync-key-stick --allow ID' admits it."
  fi
  [ "$n" = 1 ] || die "$n partitions are labelled disk-a-usb-ESP ($(printf '%s' "$esps" | tr '\n' ' ')): unplug the spare, then run: sudo sync-key-stick --heal"
  disk=/dev/$(lsblk -nro PKNAME "$esps")
  for l in "${LABELS[@]}"; do
    link=$(readlink -f "/dev/disk/by-partlabel/$l" 2>/dev/null || true)
    want=$(by_label "$disk" "$l")
    [ "$link" = "$want" ] || die "/dev/disk/by-partlabel/$l points at '${link:-nothing}', not at $want on the key stick"
  done
  if ! findmnt -n /boot >/dev/null; then
    systemctl reset-failed boot.mount 2>/dev/null || true
    systemctl start boot.mount
    remounted=1
  fi
  [ "$(findmnt -no SOURCE /boot)" = "$esps" ] || die "/boot is mounted from $(findmnt -no SOURCE /boot), not from the key stick's $esps"
  if [ "$remounted" = 1 ]; then
    echo "  /boot was not mounted: mounted again from $esps"
  else
    echo "  /boot is mounted from $esps; the partition labels point at $disk"
  fi
}

[ "$(id -u)" = 0 ] || die "run as root: sudo sync-key-stick …"

init=0 rescue=0 heal_only=0 target=
while [ $# -gt 0 ]; do
  case $1 in
    --init) init=1 ;;
    --rescue) rescue=1 ;;
    --heal) heal_only=1 ;;
    --allow)
      [ -n "${2:-}" ] || usage
      usbguard allow-device "$2" || die "usbguard refused to allow device $2"
      echo "device $2 admitted for this session (not persisted)"
      udevadm settle; sleep 2; list_usb; exit 0 ;;
    -h | --help) usage ;;
    -*) usage ;;
    *) target=$1 ;;
  esac
  shift
done
if [ "$heal_only" = 1 ]; then say "partition labels and /boot"; heal; exit 0; fi
if [ -z "$target" ]; then list_usb; exit 0; fi

src='' mnt='' tname=''
cleanup() {
  if [ -n "$mnt" ]; then umount "$mnt" 2>/dev/null || true; rmdir "$mnt" 2>/dev/null || true; fi
  if [ -n "$src" ]; then umount "$src" 2>/dev/null || true; rmdir "$src" 2>/dev/null || true; fi
  if [ -n "$tname" ] && [ -e "/sys/block/$tname" ]; then
    echo "The spare is still attached. Unplug it, then run: sudo sync-key-stick --heal" >&2
  fi
}
trap cleanup EXIT

# ── the live key stick, resolved by kernel name from what is mounted right now ────────────────────────
say "the key stick in use"
live_esp=$(findmnt -no SOURCE /boot) || die "/boot is not mounted. If a spare was plugged in and pulled out, run: sudo sync-key-stick --heal"
[ "$(lsblk -nro PARTLABEL "$live_esp")" = disk-a-usb-ESP ] || die "/boot ($live_esp) is not the partition labelled disk-a-usb-ESP"
live_disk=/dev/$(lsblk -nro PKNAME "$live_esp")
[ "$(lsblk -dnro TRAN "$live_disk")" = usb ] || die "$live_disk (behind /boot) is not a USB disk"
live_hdr=$(by_label "$live_disk" disk-a-usb-reserved)
live_rescue=$(by_label "$live_disk" disk-a-usb-installer)
[ -b "$live_hdr" ] || die "no partition labelled disk-a-usb-reserved on $live_disk"
[ -b "$live_rescue" ] || die "no partition labelled disk-a-usb-installer on $live_disk"
live_rescue_label=$(iso_label "$live_rescue")
echo "  disk    $live_disk  ($(lsblk -dnro SIZE,MODEL "$live_disk" | tr -s ' '))"
echo "  /boot   $live_esp"
echo "  header  $live_hdr"
echo "  rescue  $live_rescue  (label: ${live_rescue_label:-none})"

# ── the target: a whole USB disk that is not the live stick and holds nothing of this system ───────────
say "the spare"
[ -b "$target" ] || die "no such block device: $target"
tname=$(basename "$target")
[ -e "/sys/block/$tname" ] || { tname=; die "$target is not a whole disk (give /dev/sdX, not a partition)"; }
[ "$target" != "$live_disk" ] || { tname=; die "$target is the key stick in use: refusing"; }
[ "$(lsblk -dnro TRAN "$target")" = usb ] || die "$target is not a USB disk (transport: $(lsblk -dnro TRAN "$target"))"
[ "$(lsblk -dnro RM "$target")" = 1 ] || die "$target is not a removable disk"
if findmnt -nro SOURCE | grep -q -E "^${target}(p?[0-9]+)?$"; then die "$target has mounted partitions: unmount them first"; fi
for mp in / /nix /persist /home /boot; do
  s=$(findmnt -no SOURCE "$mp" 2>/dev/null || true)
  case $s in "$target"*) die "$target backs $mp: refusing" ;; esac
done
lsblk -o PATH,SIZE,TYPE,FSTYPE,PARTLABEL,LABEL "$target"

have_layout=1
for l in "${LABELS[@]}"; do [ -n "$(by_label "$target" "$l")" ] || have_layout=0; done
if [ "$init" = 1 ]; then
  echo
  echo "--init: EVERYTHING on $target will be erased and replaced by the key-stick layout."
elif [ "$have_layout" = 0 ]; then
  die "$target does not carry the key-stick partition labels. A blank or foreign stick needs: sudo sync-key-stick --init $target"
fi
printf 'Type the device path exactly (%s) to continue, anything else aborts: ' "$target"
read -r ans; [ "$ans" = "$target" ] || die "aborted"
if [ "$init" = 1 ]; then
  printf 'Type "erase" to confirm erasing %s: ' "$target"
  read -r ans; [ "$ans" = erase ] || die "aborted"
fi

# ── /boot, as it is now, on a private read-only bind mount: /boot itself may be unmounted from here on ──
src=$(mktemp -d /run/sync-key-stick-src.XXXXXX)
mount --bind /boot "$src"
mount -o remount,bind,ro "$src"
for f in EFI/BOOT/BOOTX64.EFI EFI/systemd/systemd-bootx64.efi loader/loader.conf; do
  [ -f "$src/$f" ] || die "the key stick's /boot has no $f: is /boot mounted from it?"
done

# ── --init: the same table as disko makes, by label; sizes from hosts/cobalt/disko.nix ─────────────────
if [ "$init" = 1 ]; then
  say "partitioning $target"
  size_bytes=$(blockdev --getsize64 "$target")
  need=$(( (1 + 16) * 1024 * 1024 * 1024 + 64 * 1024 * 1024 ))
  [ "$size_bytes" -ge "$need" ] || die "$target is too small: the ESP, header and rescue partitions alone need 17 GiB"
  sgdisk --zap-all "$target" >/dev/null
  sgdisk \
    --new=1:0:+1G --typecode=1:EF00 --change-name=1:disk-a-usb-ESP \
    --new=2:0:+32M --typecode=2:8300 --change-name=2:disk-a-usb-reserved \
    --new=3:0:+16G --typecode=3:8300 --change-name=3:disk-a-usb-installer \
    --new=4:0:0 --typecode=4:0700 --change-name=4:disk-a-usb-interop \
    "$target" >/dev/null
  blockdev --rereadpt "$target" 2>/dev/null || true
  udevadm settle
  mkfs.vfat -F 32 "$(part "$target" 1)" >/dev/null
  mkfs.exfat -L INTEROP "$(part "$target" 4)" >/dev/null
  udevadm settle
  rescue=1
fi

t_esp=$(by_label "$target" disk-a-usb-ESP)
t_hdr=$(by_label "$target" disk-a-usb-reserved)
t_rescue=$(by_label "$target" disk-a-usb-installer)
{ [ -b "$t_esp" ] && [ -b "$t_hdr" ] && [ -b "$t_rescue" ]; } || die "the spare's partitions did not appear"
[ "$(blockdev --getsize64 "$t_hdr")" -ge "$HEADER_BYTES" ] || die "the spare's header partition is smaller than 32 MiB"

# ── the header: 32 MiB, raw, partition to partition, read back from the stick ─────────────────────────
say "header → $t_hdr"
dd if="$live_hdr" of="$t_hdr" bs=4M count="$HEADER_BYTES" iflag=count_bytes conv=fsync status=none
blockdev --flushbufs "$t_hdr"
cmp -n "$HEADER_BYTES" "$live_hdr" "$t_hdr" || die "the header on $t_hdr differs from $live_hdr after the copy"
echo "  identical (32 MiB read back and compared)"

# ── /boot: the files, with deletions; FAT keeps no owners and 2-second timestamps ─────────────────────
say "/boot → $t_esp"
mnt=$(mktemp -d /run/sync-key-stick-esp.XXXXXX)
mount -o umask=0077 "$t_esp" "$mnt"
rsync -rt --delete --modify-window=2 "$src"/ "$mnt"/
umount "$mnt"                               # remounting drops the cache: the comparison reads the stick
mount -o ro,umask=0077 "$t_esp" "$mnt"
diff -r -q "$src" "$mnt" >/dev/null || die "the spare's ESP differs from /boot after the copy"
[ -f "$mnt/EFI/BOOT/BOOTX64.EFI" ] || die "the spare's ESP has no EFI/BOOT/BOOTX64.EFI after the copy"
echo "  $(find "$src" -type f | wc -l | tr -d ' ') files, read back and identical"
umount "$mnt"; rmdir "$mnt"; mnt=

# ── the rescue system: the iso9660 image, only as far as it reaches ───────────────────────────────────
if [ "$rescue" = 1 ] || { [ "$live_rescue_label" = NIXOS_RESCUE ] && [ "$(iso_label "$t_rescue")" != NIXOS_RESCUE ]; }; then
  say "rescue system → $t_rescue"
  if [ "$live_rescue_label" != NIXOS_RESCUE ]; then
    echo "  skipped: the key stick in use carries no NIXOS_RESCUE image"
  else
    # ISO 9660: the primary volume descriptor sits at byte 32768; bytes 80–83 hold the volume size in
    # 2048-byte sectors (little-endian). Copying that much copies the whole image and nothing beyond it.
    sectors=$(od -An -tu4 -j $((32768 + 80)) -N 4 "$live_rescue" | tr -d ' ')
    bytes=$((sectors * 2048))
    { [ "$bytes" -gt 0 ] && [ "$bytes" -le "$(blockdev --getsize64 "$t_rescue")" ]; } || die "rescue image size looks wrong ($bytes bytes)"
    dd if="$live_rescue" of="$t_rescue" bs=4M count="$bytes" iflag=count_bytes conv=fsync status=progress
    blockdev --flushbufs "$t_rescue"
    cmp -n "$bytes" "$live_rescue" "$t_rescue" || die "the rescue image on $t_rescue differs from $live_rescue after the copy"
    udevadm settle
    [ "$(iso_label "$t_rescue")" = NIXOS_RESCUE ] || die "the spare's rescue partition carries no NIXOS_RESCUE label after the copy"
    echo "  NIXOS_RESCUE image written, read back and identical ($bytes bytes)"
  fi
else
  say "rescue system: unchanged on the spare (--rescue rewrites it)"
fi
umount "$src"; rmdir "$src"; src=
sync

# ── unplug, then the links and /boot back on the key stick ────────────────────────────────────────────
say "unplug the spare now"
echo "  waiting for $target to disappear; then /boot and the partition labels are checked"
waited=0
while [ -e "/sys/block/$tname" ]; do
  sleep 2
  waited=$((waited + 2))
  if [ $((waited % 60)) = 0 ]; then echo "  still waiting for $target to be unplugged"; fi
done
tname=
say "partition labels and /boot"
heal

say "done"
echo "  The spare boots this system like the key stick: same labels, same header, same /boot."
echo "  Keep it away from the laptop. Never start the laptop with both sticks inserted."
echo "  Refresh it after every update you want to keep, and always after a keyslot change."
