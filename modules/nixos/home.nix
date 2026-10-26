# Home-Manager as a NixOS module (oxalica pattern): one pkgs instance, user packages installed through
# the system profile, and `inputs` + `my` passed to every home module. Only the operator gets a managed
# home; the second account stays a plain, ordinary user.
{ inputs, my, pkgs, ... }:
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    # A file in the way of a managed one is moved aside with a timestamp, so every earlier copy is kept and a second
    # clash on the same path cannot stop the activation (with a fixed extension it does: Home-Manager refuses to
    # overwrite an existing backup, modules/files/check-link-targets.sh). A symbolic link it does not own still stops
    # it, by design.
    backupCommand = pkgs.writeShellScript "hm-backup" ''
      exec ${pkgs.coreutils}/bin/mv -- "$1" "$1.hm-backup-$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S)"
    '';
    extraSpecialArgs = { inherit inputs my; };
    # plasma-manager (flake input): KDE Plasma settings as Home-Manager options (home/modules/plasma.nix).
    sharedModules = [ inputs.plasma-manager.homeModules.plasma-manager ];
    users.${my.user.username} = import ../../home/operator.nix;
  };
}
