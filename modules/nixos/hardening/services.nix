# systemd sandboxing for system services whose upstream units are weak and where a tighter unit carries
# little risk of breakage. The settings follow oxalica's nixos/invar/snapshot.nix. Exposure was measured
# offline with `systemd-analyze security` (systemd 261.3) against this configuration's units. Re-measure on
# the laptop before and after a change:
#   systemd-analyze security            # one line per service, 0 = fully sandboxed, 10 = unconfined
#   systemd-analyze security <unit>     # every setting, explained
#
# Already well confined by their own units, so not touched here: tor, polkit, power-profiles-daemon, pcscd,
# rtkit, timesyncd, resolved, upower, logind, usbguard, bluetooth, fwupd, and mihomo (DynamicUser,
# ProtectSystem=strict, a system-call filter, once its profile exists).
# Deliberately left alone for now: NetworkManager and iwd (new MT7902 driver; iwd needs AF_ALG and the
# kernel keyring), udisks2, dbus, the display manager and nix-daemon — they need privileges a generic
# profile would take away. Second round after the hardware is stable.
{ ... }:
let
  # A oneshot that reads and writes only its own directories: no network, no devices, no privileges.
  strictOneshot = {
    CapabilityBoundingSet = "";
    IPAddressDeny = "any";
    LockPersonality = true;
    MemoryDenyWriteExecute = true;
    NoNewPrivileges = true;
    PrivateDevices = true;
    PrivateNetwork = true;
    PrivateTmp = true;
    ProtectClock = true;
    ProtectControlGroups = true;
    ProtectHome = true;
    ProtectHostname = true;
    ProtectKernelLogs = true;
    ProtectKernelModules = true;
    ProtectKernelTunables = true;
    ProtectProc = "invisible";
    ProtectSystem = "strict";
    RestrictAddressFamilies = "AF_UNIX";
    RestrictNamespaces = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    SystemCallArchitectures = "native";
    SystemCallFilter = [
      "@system-service"
      "~@privileged"
      "~@resources"
    ];
  };
  # Flatpak installs and updates run bubblewrap for their triggers, which needs namespaces and privileges,
  # so only the parts that cannot interfere: no access to /home, private /tmp.
  flatpakInstall = {
    ProtectHome = true;
    PrivateTmp = true;
  };
in
{
  # man-page index (man-db): 8.8 → 0.4 in the offline measurement.
  systemd.services.mandb.serviceConfig = strictOneshot;

  # nix-flatpak's install and weekly update units: 9.4 → 9.0.
  systemd.services.flatpak-managed-install.serviceConfig = flatpakInstall;
  systemd.services.flatpak-managed-install-timer.serviceConfig = flatpakInstall;
}
