# neovim — as on macOS. The fish `nvim` function (fish.nix) launches it with NVIM_APPNAME=nvim-Lazyman,
# so the editor configuration itself lives in ~/.config/nvim-Lazyman (persistent home).
{ pkgs, ... }:
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withNodeJs = false; # no node-based plugins in use
    withPython3 = true;
    withRuby = true;
    extraPackages = with pkgs; [ neovim-remote ];
  };
}
