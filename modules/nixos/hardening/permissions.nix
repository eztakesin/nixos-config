# File and privilege permissions.
{ lib, ... }:
{
  # Memory-safe sudo/su. The two sudo modules are mutually exclusive; rules must be declared here.
  security.sudo.enable = false;
  security.sudo-rs = {
    enable = true;
    wheelNeedsPassword = true;
    execWheelOnly = true;
  };

  # Default umask 077 for every session (console, SDDM/Plasma, the systemd user manager, sudo): new files
  # are private to their owner. login.defs only holds the value; pam_umask is what applies it, and NixOS
  # does not load pam_umask unless asked (security.pam.enableUMask, off by default). Homes are 0700 via
  # users.nix homeMode.
  security.loginDefs.settings.UMASK = "077";
  security.pam.enableUMask = true;

  # Kernel-side protections against symlink/hardlink/FIFO/regular-file tricks in world-writable dirs,
  # and no dumps from setuid programs.
  boot.kernel.sysctl = {
    "fs.protected_hardlinks" = 1;
    "fs.protected_symlinks" = 1;
    "fs.protected_fifos" = 2;
    "fs.protected_regular" = 2;
    "fs.suid_dumpable" = 0;
  };

  # polkit is needed by the desktop; admin identity stays the wheel group.
  security.polkit.enable = true;

  # No remote shell by default; enable per-need with key-only auth.
  services.openssh.enable = lib.mkDefault false;

  # Drop the implicit default package set (perl, rsync, strace, …) — smaller surface, explicit manifest.
  environment.defaultPackages = lib.mkForce [ ];
}
