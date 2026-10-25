#!/bin/sh
# install.sh — one-shot installation of cobalt from the live installer (run as root).
#
# Two modes:
#   OFFLINE (default)  The image was built from the FINAL configuration: real disk ids in my/private.nix,
#                      secrets/*.yaml present. Nothing is evaluated or built here — the disko script and
#                      the system closure embedded in the image are used as they are (`nixos-install
#                      --system` is a store copy). This is what "offline install" means.
#   ONLINE (COBALT_ONLINE=1)  The image was built with placeholders; the configuration is completed here
#                      (prompts) and re-evaluated with `--flake`. Needs a network: every derivation nixpkgs
#                      marks non-substitutable (buildEnv paths, unit and etc files, shell completions, …)
#                      is rebuilt on the target and their build-time inputs are fetched — the QEMU rehearsal
#                      of 2026-10-17 measured 636 derivations and 160 MB of downloads for that.
#
# Phases: preflight → config + private data → host age key → disko (ONCE) → Secure Boot keys →
#         FIDO2 + recovery enrollment on the detached header → nixos-install →
#         the anonymous rescue system onto the key stick → summary.
# Every destructive step prints what it is about to do and asks for the exact device id.
# STATUS: exercised in the QEMU rehearsal (https://nixos.ssf.network/runbook/vm-rehearsal/) and on the laptop
#         (2026-10-25: offline install, first boot to the desktop).
set -eu
# Independent of the caller's umask: with 077 inherited from the shell (as when the host key was typed in
# with `umask 077`), disko creates /mnt as 0700 and nixos-install refuses to continue ("path /mnt should
# have permissions 755"). Secret files get explicit modes below (install -m 600 …).
umask 022

CONFIG_SRC=${COBALT_CONFIG:-/etc/cobalt/config}
SYSTEM_LINK=${COBALT_SYSTEM:-/etc/cobalt/system}                     # → embedded cobalt toplevel
DISKO_SCRIPT=${COBALT_DISKO:-/etc/cobalt/disko-destroy-format-mount} # → embedded disko script
WORK=${COBALT_WORK:-/tmp/cobalt}
HOST=${COBALT_HOST:-cobalt}
ONLINE=${COBALT_ONLINE:-0}
HDR=/dev/disk/by-partlabel/disk-a-usb-reserved
INSTALLER_PART=/dev/disk/by-partlabel/disk-a-usb-installer

say() { printf '\n== %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }
ask() { printf '%s ' "$1"; read -r REPLY; }

# ── 0. preflight ───────────────────────────────────────────────────────────────
[ "$(id -u)" = 0 ] || die "run as root"
[ -d /sys/firmware/efi ] || die "not booted in UEFI mode"
[ -d "$CONFIG_SRC" ] || die "configuration not found at $CONFIG_SRC"
for t in disko nixos-install cryptsetup systemd-cryptenroll sbctl age-keygen; do
  command -v "$t" >/dev/null || die "missing tool: $t"
done
# The embedded disko entries are derivation OUTPUTS: a directory holding bin/<one script> (what the disko
# CLI itself runs as "$script"/bin/*) — the second rehearsal ran the directory and got "Is a directory".
disko_script() { if [ -d "$1" ]; then set -- "$1"/bin/*; fi; [ -f "$1" ] && [ -x "$1" ] && printf '%s\n' "$1"; }
if [ "$ONLINE" != 1 ]; then
  [ -e "$SYSTEM_LINK" ] || die "no embedded system at $SYSTEM_LINK (image built without it?) — or run with COBALT_ONLINE=1"
  DISKO_RUN=$(disko_script "$DISKO_SCRIPT") || true
  [ -n "$DISKO_RUN" ] || die "no embedded disko script at $DISKO_SCRIPT — or run with COBALT_ONLINE=1"
  say "offline install: system $(readlink -f "$SYSTEM_LINK")"
  # Nothing below needs a binary cache, but the live system's nix.conf lists cache.nixos.org: without a
  # network every nix invocation would retry the DNS lookup and then "disable the binary cache for 60
  # seconds" (seen in the rehearsal). NIX_CONFIG applies to every nix process started from here.
  export NIX_CONFIG="substituters =
connect-timeout = 2"
else
  say "ONLINE install: the configuration will be re-evaluated and partly rebuilt here (needs a network)"
fi

# ── 1. writable copy of the configuration + private data ──────────────────────
say "preparing configuration in $WORK"
rm -rf "$WORK"; mkdir -p "$WORK"
cp -r "$CONFIG_SRC"/. "$WORK"/; chmod -R u+w "$WORK"
cd "$WORK"
if [ "$ONLINE" = 1 ] && [ ! -f my/private.nix ]; then
  echo "my/private.nix is not present. Disks by stable id:"
  ls -l /dev/disk/by-id/ | grep -vE 'part[0-9]|wwn-|nvme-eui' | awk '{print "  " $9}'
  ask "Path to a prepared my/private.nix (empty = write a minimal one now):"
  if [ -n "$REPLY" ]; then cp "$REPLY" my/private.nix
  else
    ask "USB key by-id path:"; usb=$REPLY
    ask "NVMe by-id path:"; nvme=$REPLY
    ask "operator login name:"; op=$REPLY
    ask "operator full name:"; opn=$REPLY
    ask "operator email:"; ope=$REPLY
    ask "second account login name:"; sec=$REPLY
    ask "second account full name:"; secn=$REPLY
    cat > my/private.nix <<EOT
{
  user = { username = "$op"; fullName = "$opn"; email = "$ope"; gpgFingerprint = ""; timeZone = "UTC"; };
  secondary = { username = "$sec"; fullName = "$secn"; timeZone = "UTC"; };
  cache = { url = ""; publicKey = ""; };
  disks = { usb = "$usb"; nvme = "$nvme"; };
}
EOT
  fi
fi
[ -f my/private.nix ] || die "my/private.nix missing from the image (built from a git reference instead of path:.?)"
chmod 600 my/private.nix
if [ "$ONLINE" != 1 ] && grep -q 'REPLACE-ME' my/private.nix; then
  die "my/private.nix still has placeholder disk ids: the embedded system and disko script were built from them.
  Fill in the real /dev/disk/by-id paths, rebuild the image (https://nixos.ssf.network/runbook/install/, 'Prepare') — or run this
  script with COBALT_ONLINE=1 to complete the configuration here over the network."
fi
if [ ! -f secrets/users.yaml ]; then
  if [ "$ONLINE" = 1 ]; then echo "WARNING: secrets/users.yaml missing — no account will have a password (see https://nixos.ssf.network/runbook/secrets/)."
  elif [ "${COBALT_ALLOW_NO_PASSWORDS:-0}" = 1 ]; then echo "WARNING: secrets/users.yaml missing — the embedded system has NO passwords."
  else die "secrets/users.yaml missing: the embedded system has no login passwords at all. Create it (https://nixos.ssf.network/runbook/secrets/),
  rebuild the image — or set COBALT_ALLOW_NO_PASSWORDS=1 if that is really intended."
  fi
fi
usb=$(nix eval --raw --impure --expr "(import $WORK/my).disks.usb")
nvme=$(nix eval --raw --impure --expr "(import $WORK/my).disks.nvme")
[ -b "$usb" ] || die "USB key not found: $usb"
[ -b "$nvme" ] || die "NVMe not found: $nvme"
case "$(findmnt -no SOURCE /iso 2>/dev/null || true)" in
  "$usb"*) die "the live installer is running FROM the key stick; disko would destroy it. Boot from a temporary stick (https://nixos.ssf.network/runbook/install/)." ;;
esac

# ── 2. host age key (must be a recipient in .sops.yaml before secrets can be read) ────────────
say "host age key"
# Staged inside $WORK (freshly created above), so a prepared key can live anywhere in /tmp — the first
# rehearsal died here on `cp` refusing to copy a file onto itself.
KEY=$WORK/host-age.txt
ask "Path to a prepared host age key (empty = generate now):"
if [ -n "$REPLY" ]; then cp "$REPLY" "$KEY"
else
  [ "$ONLINE" = 1 ] || echo "NOTICE: offline install with a key generated now — the embedded secrets were encrypted to OTHER recipients; they stay unreadable until you re-encrypt them with this key and rebuild (https://nixos.ssf.network/runbook/secrets/)."
  age-keygen -o "$KEY"
  echo "Public key: $(age-keygen -y "$KEY")"
  echo "Add it to .sops.yaml as &cobalt, run 'sops updatekeys secrets/*.yaml' on your workstation, and copy the"
  echo "updated secrets/ into $WORK/secrets before continuing (or continue now and fix on first boot)."
  ask "Press Enter to continue."
fi
chmod 600 "$KEY"

# ── 3. disko — runs exactly once ──────────────────────────────────────────────
say "disk layout (DESTROYS everything on both devices)"
lsblk -o NAME,SIZE,MODEL,TRAN "$usb" "$nvme"
printf 'Type the NVMe by-id path exactly to continue: '; read -r c; [ "$c" = "$nvme" ] || die "aborted"
printf 'Type the USB by-id path exactly to continue: '; read -r c; [ "$c" = "$usb" ] || die "aborted"
echo "You will be asked for the LUKS passphrase — this keyslot is the recovery fallback; use a long diceware phrase."
if [ "$ONLINE" = 1 ]; then
  disko --mode destroy,format,mount --flake "path:$WORK#$HOST"
else
  # The script disko generated for THIS configuration at image build time (system.build.destroyFormatMount,
  # what `disko --mode destroy,format,mount` would evaluate and build here); it still asks for confirmation.
  "$DISKO_RUN"
fi
# Never run --mode format again on this layout (detached header: disko cannot see it is formatted).

# ── 4. persistent state that must exist before the first boot ────────────────
say "seeding /persist"
install -d -m 700 /mnt/persist/var/lib/sops-nix
install -m 600 "$KEY" /mnt/persist/var/lib/sops-nix/key.txt
if [ ! -d /var/lib/sbctl ]; then sbctl create-keys; fi
install -d -m 700 /mnt/persist/var/lib /mnt/var/lib
cp -a /var/lib/sbctl /mnt/persist/var/lib/   # runtime location (bind-mounted by impermanence)
cp -a /var/lib/sbctl /mnt/var/lib/           # used by lanzaboote during nixos-install

# ── 5. enrollment on the detached header ─────────────────────────────────────
say "FIDO2 + recovery enrollment on $HDR"
if [ "${COBALT_SKIP_FIDO2:-0}" = 1 ]; then
  # VM rehearsal without a hardware token. The passphrase keyslot stays the only interactive unlock
  # (crypttab keeps fido2-device=auto; without enrolled FIDO2 metadata systemd-cryptsetup falls back to
  # the passphrase). Enroll later from the installed system:
  #   systemd-cryptenroll --fido2-device=auto /dev/disk/by-partlabel/disk-a-usb-reserved
  echo "NOTICE: COBALT_SKIP_FIDO2=1 — skipping FIDO2 enrollment; unlock relies on the passphrase keyslot."
else
  echo "Insert exactly one YubiKey (with a FIDO2 PIN set). Touch it when it blinks."
  systemd-cryptenroll --fido2-device=auto "$HDR"
fi
echo "Recovery key (store OFFLINE, never on this machine):"
systemd-cryptenroll --recovery-key "$HDR"
cryptsetup luksDump "$HDR" | grep -E 'Keyslots|systemd-fido2|systemd-recovery|luks2' || true
ask "Path for the LUKS header backup (another medium; empty = skip, NOT recommended):"
[ -n "$REPLY" ] && cryptsetup luksHeaderBackup "$HDR" --header-backup-file "$REPLY" && echo "header backup written to $REPLY"

# ── 6. install ───────────────────────────────────────────────────────────────
say "nixos-install"
if [ "$ONLINE" = 1 ]; then
  nixos-install --root /mnt --no-root-passwd --flake "path:$WORK#$HOST"
else
  # A store copy of the embedded closure (nixos-install: `nix copy --to local?root=/mnt`), then the
  # bootloader install inside the target (lanzaboote signs with the keys seeded in step 4). No evaluation,
  # no builds, no network.
  nixos-install --root /mnt --no-root-passwd --system "$(readlink -f "$SYSTEM_LINK")"
fi
install -d -m 700 /mnt/persist/etc/cobalt
cp -r "$WORK" /mnt/persist/etc/cobalt/config   # the exact configuration that was installed (incl. private.nix)

# ── 7. the rescue system: the key's installer partition + a signed boot entry ─
# The key stick is readable by whoever holds it (only the header is encrypted), so it gets the anonymous
# rescue system (installer/rescue.nix), not this installer: the installer carries the whole installed
# system, user names and e-mail address included. The rescue files sit on this medium under /iso/rescue/.
# 7a. The installer partition receives the rescue ISO image byte for byte: its stage 1 mounts
#     /dev/disk/by-label/NIXOS_RESCUE as iso9660 (nixpkgs iso-image.nix, fileSystems."/iso"), so only an
#     iso9660 volume with that label boots.
say "rescue system on the key's installer partition"
rescue_iso=/iso/rescue/rescue.iso
if [ -f "$rescue_iso" ] && [ -b "$INSTALLER_PART" ]; then
  iso_bytes=$(stat -c %s "$rescue_iso")
  part_bytes=$(blockdev --getsize64 "$INSTALLER_PART")
  if [ "$iso_bytes" -le "$part_bytes" ]; then
    dd if="$rescue_iso" of="$INSTALLER_PART" bs=4M conv=fsync status=progress
    udevadm settle 2>/dev/null || true
    echo "written: $iso_bytes bytes, iso9660 volume NIXOS_RESCUE on $INSTALLER_PART"
  else
    echo "skipped: the rescue image ($iso_bytes bytes) does not fit the installer partition ($part_bytes bytes)"
  fi
else
  echo "skipped ($rescue_iso missing — image built without installer/rescue.nix? — or installer partition not found)"
fi

# 7b. Boot entry: the rescue system's Unified Kernel Image — kernel, initrd, command line and os-release in
#     ONE file — signed with the db key from step 4 (sbctl keydir /var/lib/sbctl/keys) and placed in
#     EFI/Linux/, where systemd-boot auto-discovers it (type #2 entry, "NixOS rescue system").
#     lanzaboote v1.2.0 only garbage-collects EFI/nixos/ and EFI/Linux/nixos-* (lzbt install.rs), so the
#     file survives every nixos-rebuild; loader.conf keeps `default nixos-*`, so it never boots by default.
#     Not `-s`aved to sbctl's files.json: that database was copied to the target in step 4 and the path
#     would differ on the installed system (/boot/... vs /mnt/boot/...).
say "rescue boot entry (signed UKI on the ESP)"
uki_src=/iso/rescue/rescue.efi
uki_dst=/mnt/boot/EFI/Linux/rescue.efi
if [ -f "$uki_src" ]; then
  install -d /mnt/boot/EFI/Linux
  rm -f /mnt/boot/EFI/Linux/cobalt-installer.efi   # the entry earlier versions of this script installed
  sbctl sign -o "$uki_dst" "$uki_src"
  # sbctl locates the ESP itself (sbctl.go GetESP: $SYSTEMD_ESP_PATH, $ESP_PATH, then the usual mount
  # points); here it is mounted at /mnt/boot — the first rehearsal stopped on "failed to find EFI system partition".
  ESP_PATH=/mnt/boot sbctl verify "$uki_dst"
  echo "entry: EFI/Linux/rescue.efi — shown as 'NixOS rescue system' in the boot menu"
else
  echo "skipped: $uki_src not found (image built without installer/rescue.nix?)"
fi

# ── 8. summary ───────────────────────────────────────────────────────────────
say "done"
cat <<'EOT'
Next:
  1. reboot into firmware: set a SUPERVISOR PASSWORD, then put Secure Boot into Setup Mode
     ("Reset to Setup Mode" / "Erase all Secure Boot settings"), update the BIOS first if you have not.
  2. boot cobalt (USB key inserted, YubiKey inserted BEFORE power-on), log in, then:
       sudo sbctl enroll-keys --microsoft && sudo sbctl verify
     reboot, enable Secure Boot in firmware, confirm with: bootctl status   (→ "Secure Boot: enabled (user)")
  3. verify: cryptsetup luksDump on the header shows the FIDO2 + recovery slots; usbguard list-devices;
     systemctl status mihomo (after secrets/mihomo.yaml exists).
  4. keep ≥2 cloned key sticks + the header backup offline. Losing the stick = losing the data.
EOT
