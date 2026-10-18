# Per-user home encryption for the operator: systemd-homed with LUKS storage. Opt-in
# (my.features.homed = true), planned for after the first install
# (https://nixos.ssf.network/architecture/system-hardening/#home-encryption). The migration (rebuild with the
# flag from a root shell, then `homectl create`) gets its runbook once it has been rehearsed in the VM.
#
# What it adds: the operator's home becomes a LUKS2 image (/home/<user>.home, btrfs inside) that is
# unlocked with the login password at login and locked again at logout. With the disk unlocked but the
# operator logged out, their files stay encrypted. The second account stays a classic declarative account.
#
# What it costs / does not do (sources: systemd 261 homectl(1), homed.conf(5), pam_systemd_home(8),
# systemd-homed.service(8); https://systemd.io/HOME_DIRECTORY/):
#   - The operator account is no longer declarative: homed owns it (`homectl create`, `homectl passwd`).
#     users.nix keeps a disabled stub so Home-Manager still builds the profile.
#   - No lock on suspend under Plasma: the lock screen and KWin run inside the frozen user slice
#     (pam_systemd_home(8); upstream work: systemd PR #41633). Log out instead; logging out unmounts the
#     home and drops its key (KillUserProcesses below makes sure nothing keeps it busy).
#   - The account and the image are visible; only their contents are protected.
#   - homed signs user records with /var/lib/systemd/home/local.private; records signed by an unknown key
#     are refused, so that directory must survive the root reset (persisted below).
{ lib, my, ... }:
let
  enabled = (my.features or { }).homed or false;
in
lib.mkIf enabled {
  services.homed = {
    enable = true;
    settings.Home = {
      # The default picks an UNENCRYPTED btrfs subvolume when /home already sits on encrypted storage
      # (homed.conf(5)), which it does here. LUKS must be explicit.
      DefaultStorage = "luks";
      DefaultFileSystemType = "btrfs";
    };
  };
  # The nix build users (uid 30000+) sit in homed's "high system user" range; silence the warning.
  services.userdbd.silenceHighSystemUsers = true;
  # Logging out must end every process of the user so the home can be deactivated (unmounted, key dropped).
  services.logind.settings.Login.KillUserProcesses = true;

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/systemd/home";
      mode = "0700";
    }
  ];

  # Home-Manager normally activates at boot as a system unit, when the home is still locked. Activate at
  # login instead (home-manager PR #6981).
  home-manager.startAsUserService = true;
}
