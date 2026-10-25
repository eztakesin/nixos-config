# Home-Manager entry point for the operator account (wired in modules/nixos/home.nix).
# One file per program under ./modules, ported from the operator's existing configs.
{ my, ... }:
{
  imports = [
    ./modules/fish.nix
    ./modules/starship.nix
    ./modules/kitty.nix
    ./modules/git.nix
    ./modules/gpg.nix
    ./modules/ssh.nix
    ./modules/neovim.nix
    ./modules/firefox.nix
    ./modules/cli.nix
    ./modules/theme.nix
    ./modules/plasma.nix
    ./modules/input-method.nix
    ./modules/rust.nix
    ./modules/vscode.nix
    ./modules/packages.nix
  ];

  # sops with the YubiKey PIV age identity for the operator's own files (not system secrets).
  home.sessionVariables.SOPS_AGE_KEY_FILE = "$HOME/.config/sops/age/keys.txt";

  home.username = my.user.username;
  home.homeDirectory = "/home/${my.user.username}";
  home.stateVersion = "26.05";

  xdg.enable = true;
  programs.home-manager.enable = true;
}
