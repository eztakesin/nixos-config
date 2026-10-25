# Home-Manager as a NixOS module (oxalica pattern): one pkgs instance, user packages installed through
# the system profile, and `inputs` + `my` passed to every home module. Only the operator gets a managed
# home; the second account stays a plain, ordinary user.
{ inputs, my, ... }:
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = { inherit inputs my; };
    # plasma-manager (flake input): KDE Plasma settings as Home-Manager options (home/modules/plasma.nix).
    sharedModules = [ inputs.plasma-manager.homeModules.plasma-manager ];
    users.${my.user.username} = import ../../home/operator.nix;
  };
}
