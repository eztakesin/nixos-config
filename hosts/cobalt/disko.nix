# Declarative disk layout (disko) — the single source of truth the installer consumes.
# Verified by evaluation against disko 725ea35 (2026-09-18) and in the QEMU rehearsal; NOT yet run on hardware.
#
#   USB key  (disk.a-usb, GPT)                           Internal NVMe, WD SN740 (disk.b-nvme)
#   ├─ ESP        FAT32   1G   → /boot (+ installer      NO partition table. The whole device is the LUKS2
#   │                           boot entry)              data area; the header is DETACHED → USB "reserved".
#   ├─ reserved   raw    32M   LUKS2 header               └─ LVM VG "vg"
#   ├─ installer  raw    16G   rescue system (ISO image)      ├─ swap  8G   (inside the LUKS container)
#   └─ interop    exFAT  rest  cross-OS files + VeraCrypt      └─ root  rest btrfs: @ / · @home · @nix · @persist
#                                                                              · @flatpak
#
# Device identity: the NVMe is referenced by its hardware id (/dev/disk/by-id/…, from
# my/private.nix) — it carries no partition table, no label and no LUKS header, so nothing on it identifies
# it as encrypted (what remains visible is the split between written extents and TRIMmed zeros, because
# allowDiscards is on). The key stick keeps GPT partition labels on purpose: a dd clone of the stick keeps
# labels, partuuids and filesystem uuids but NOT the USB serial, so by-id would break the spare sticks.
# The header partition is labelled "reserved" rather than "luksheader".
#
# Facts that follow from disko's source:
#  - disko has no `header` option. The detached header goes through extraFormatArgs/extraOpenArgs, and
#    `settings.header` is what reaches boot.initrd.luks.devices.cryptroot.header.
#  - Disks are created in attribute-name order, so the USB is `a-usb` and is partitioned BEFORE the NVMe
#    (otherwise cryptsetup would create the "header" as a plain file under /dev in RAM).
#  - disko's "already formatted?" check cannot see a headerless data area, so `--mode format` or
#    `destroy,format,mount` must run exactly ONCE (disko PR #1286 still open). Afterwards use `--mode mount`.
#  - Because disko formats the USB key, the install boots from a separate, dd'd installer stick;
#    scripts/install.sh then writes the anonymous rescue system (installer/rescue.nix) to the key stick.
#  - FIDO2 and recovery-key enrollment are done by hand against the HEADER partition (disko's enroll
#    options do not pass --header):
#      systemd-cryptenroll --fido2-device=auto /dev/disk/by-partlabel/disk-a-usb-reserved
#      systemd-cryptenroll --recovery-key      /dev/disk/by-partlabel/disk-a-usb-reserved
#      cryptsetup luksHeaderBackup /dev/disk/by-partlabel/disk-a-usb-reserved --header-backup-file <offline>
#  - Device paths come from my/private.nix (`my.disks.*`, /dev/disk/by-id/…) so serials stay out of git.
{ my, ... }:
let
  hdr = "/dev/disk/by-partlabel/disk-a-usb-reserved";
  common = [ "compress=zstd" "noatime" ];
in
{
  disko.devices = {
    disk.a-usb = {
      type = "disk";
      device = my.disks.usb;
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            priority = 1;
            type = "EF00";
            size = "1G";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" "nodev" "nosuid" "noexec" ];
            };
          };
          reserved = {
            # The detached LUKS2 header (16 MiB by default). Attribute name = GPT label suffix, hence the
            # neutral "reserved". No `content` → raw, filesystem-less partition.
            priority = 2;
            size = "32M";
          };
          installer = {
            priority = 3;
            size = "16G";
            # Raw partition: scripts/install.sh writes the rescue system's ISO image (iso9660, volume id
            # NIXOS_RESCUE) into it, so the rescue system's stage 1 finds it by label. No filesystem is
            # created here and nothing mounts it in the installed system.
          };
          interop = {
            priority = 4;
            size = "100%";
            type = "0700"; # Microsoft basic data → visible to macOS/Windows
            # Plain cross-OS exchange area; the VeraCrypt container for the cross-OS encrypted store
            # lives here as a file. Not mounted by the installed system.
            content = {
              type = "filesystem";
              format = "exfat";
              extraArgs = [ "-L" "INTEROP" ];
            };
          };
        };
      };
    };

    disk.b-nvme = {
      type = "disk";
      device = my.disks.nvme; # by-id — the installed system's crypttab references exactly this path
      # LUKS2 on the whole device, no partition table. disko passes the disk's `device`
      # to a disk-level `content`, so the crypttab entry becomes device = my.disks.nvme, header = ${hdr}.
      content = {
        type = "luks";
        name = "cryptroot";
        askPassword = true; # passphrase keyslot = the recovery fallback; FIDO2 is enrolled after
        preCreateHook = ''
          test -b ${hdr} || { echo "LUKS header device ${hdr} missing — is the USB key plugged in?" >&2; exit 1; }
        '';
        # cryptsetup 2.8 already defaults to LUKS2 / aes-xts-plain64 / argon2id / 512-bit XTS key; pinned
        # so the layout survives upstream default changes. --sector-size 4096 is what
        # cryptsetup picks for a 512e drive like the SN740 — confirm with
        # /sys/block/nvme0n1/queue/physical_block_size before the first format.
        extraFormatArgs = [
          "--type luks2"
          "--header ${hdr}"
          "--cipher aes-xts-plain64"
          "--key-size 512"
          "--pbkdf argon2id"
          "--sector-size 4096"
        ];
        extraOpenArgs = [ "--header ${hdr}" ];
        settings = {
          header = hdr;
          allowDiscards = true; # TRIM reaches the drive: performance and SSD health over hiding the used extents
          crypttabExtraOpts = [ "fido2-device=auto" ];
        };
        content = {
          type = "lvm_pv";
          vg = "vg";
        };
      };
    };

    lvm_vg.vg = {
      type = "lvm_vg";
      lvs = {
        swap = {
          size = "8G"; # no hibernation (protectKernelImage), so RAM-sized swap is unnecessary; zram supplements
          content = {
            type = "swap";
            # A fresh random key at every boot (plain dm-crypt over the LV, key never stored): what was swapped
            # out during one session is unreadable afterwards, even with the disk unlocked.
            randomEncryption = true;
            discardPolicy = "both";
            resumeDevice = false;
          };
        };
        root = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = [ "-f" ];
            subvolumes = {
              "@" = {
                mountpoint = "/";
                mountOptions = common;
              };
              "@home" = {
                mountpoint = "/home";
                mountOptions = common ++ [ "nodev" "nosuid" ];
              };
              "@nix" = {
                mountpoint = "/nix";
                mountOptions = common;
              };
              "@persist" = {
                mountpoint = "/persist";
                # Persisted state is data, never programs. The bind mounts impermanence makes from here inherit
                # these flags (mount(8): a bind mount keeps the mount options of the original).
                mountOptions = common ++ [ "nodev" "nosuid" "noexec" ];
              };
              # System-wide Flatpak apps and runtimes. Flatpak runs programs from here, so it cannot sit under
              # the noexec /persist; a subvolume of its own also keeps it out of the per-boot root reset.
              "@flatpak" = {
                mountpoint = "/var/lib/flatpak";
                mountOptions = common ++ [ "nodev" "nosuid" ];
              };
            };
            # Read-only blank snapshot of @, restored on every boot (modules/nixos/impermanence.nix).
            postCreateHook = ''
              MNT=$(mktemp -d)
              mount -t btrfs -o subvol=/ /dev/vg/root "$MNT"
              trap 'umount "$MNT"; rm -rf "$MNT"' EXIT
              btrfs subvolume show "$MNT/@root-blank" >/dev/null 2>&1 \
                || btrfs subvolume snapshot -r "$MNT/@" "$MNT/@root-blank"
            '';
          };
        };
      };
    };
  };
}
