# Accounts: the operator plus a second, ordinary local account.
# Fully declarative (`mutableUsers = false`): password hashes come from sops (secrets/users.yaml,
# see https://nixos.ssf.network/runbook/secrets/). Without that file the accounts have no password and cannot log in — prepare the
# hashes before the first install. Root is locked; privilege goes through sudo-rs (hardening/permissions.nix).
# Homes are 0700 and live on the persistent @home subvolume.
{
  config,
  lib,
  pkgs,
  my,
  ...
}:
let
  userSecrets = ../../secrets/users.yaml;
  haveUserSecrets = builtins.pathExists userSecrets;
  # With my.features.homed the operator account is owned by systemd-homed (modules/nixos/homed.nix).
  homed = (my.features or { }).homed or false;
in
{
  users.mutableUsers = false;
  # Until secrets/users.yaml exists no account has a password. Say so explicitly (and warn) instead of
  # failing evaluation; the installer flow creates the hashes first (https://nixos.ssf.network/runbook/secrets/).
  # Also true under homed: the only admin is then the homed operator, invisible to this check.
  users.allowNoPasswordLogin = !haveUserSecrets || homed;
  warnings = lib.optional (!haveUserSecrets) "secrets/users.yaml is missing: no account has a password yet. Create it per https://nixos.ssf.network/runbook/secrets/ before installing.";

  users.users.${my.user.username} =
    if homed then
      {
        # A disabled stub: the account itself comes from systemd-homed. Home-Manager reads the name and
        # home directory from here and still builds the profile (nixpkgs config/users-groups.nix).
        enable = false;
        isNormalUser = true;
      }
    else
      {
        isNormalUser = true;
        description = my.user.fullName;
        extraGroups = [
          "wheel"
          "networkmanager"
          "video"
          "audio"
        ];
        shell = pkgs.fish;
        homeMode = "0700";
        hashedPasswordFile = lib.mkIf haveUserSecrets config.sops.secrets."password-operator".path;
      };

  users.users.${my.secondary.username} = {
    isNormalUser = true;
    description = my.secondary.fullName;
    extraGroups = [ "networkmanager" ]; # no wheel
    shell = pkgs.bash;
    homeMode = "0700";
    hashedPasswordFile = lib.mkIf haveUserSecrets config.sops.secrets."password-secondary".path;
  };

  users.users.root.hashedPassword = "!"; # locked

  programs.fish.enable = true;

  sops.secrets = lib.mkIf haveUserSecrets {
    "password-operator" = lib.mkIf (!homed) {
      sopsFile = userSecrets;
      neededForUsers = true;
    };
    "password-secondary" = {
      sopsFile = userSecrets;
      neededForUsers = true;
    };
  };
}
