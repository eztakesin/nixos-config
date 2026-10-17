# Catppuccin Latte for bat, btop and yazi. The upstream ports are
# fetched as pinned sources and linked into the XDG config tree at build time; nothing reads a
# derivation output during evaluation, so `allow-import-from-derivation = false` and evaluation on
# macOS keep working. kitty, starship and fish keep their own palettes.
#
# To bump a port: `nix flake prefetch github:catppuccin/<repo> --json` prints `rev` and `hash`.
{ pkgs, ... }:
let
  catppuccin-bat = pkgs.fetchFromGitHub {
    owner = "catppuccin";
    repo = "bat";
    rev = "6810349b28055dce54076712fc05fc68da4b8ec0";
    hash = "sha256-lJapSgRVENTrbmpVyn+UQabC9fpV1G1e+CdlJ090uvg=";
  };
  catppuccin-btop = pkgs.fetchFromGitHub {
    owner = "catppuccin";
    repo = "btop";
    rev = "f437574b600f1c6d932627050b15ff5153b58fa3";
    hash = "sha256-mEGZwScVPWGu+Vbtddc/sJ+mNdD2kKienGZVUcTSl+c=";
  };
  catppuccin-yazi = pkgs.fetchFromGitHub {
    owner = "catppuccin";
    repo = "yazi";
    rev = "d62802be39210ea10e54b3e3b09735c6cb9e57c1";
    hash = "sha256-bwzEO8exoBwa19q+jnYjHkaamGl2mhfukIEhDfUCRGI=";
  };

  # catppuccin/yazi ships one file per accent colour: themes/latte/catppuccin-latte-<accent>.toml.
  yaziAccent = "blue";
in
{
  # bat: the theme is linked to ~/.config/bat/themes/<name>.tmTheme and the Home-Manager module
  # rebuilds bat's cache on activation; bat refers to the theme by the file stem.
  programs.bat = {
    config.theme = "Catppuccin Latte";
    themes."Catppuccin Latte" = {
      src = catppuccin-bat;
      file = "themes/Catppuccin Latte.tmTheme";
    };
  };

  # btop: color_theme is matched against the file stems in ~/.config/btop/themes/.
  # programs.btop.themes is bypassed on purpose: it accepts only a Nix path or a top-level store
  # path and would write a sub-path string out as the theme's text.
  programs.btop.settings.color_theme = "catppuccin_latte";
  xdg.configFile."btop/themes/catppuccin_latte.theme".source =
    "${catppuccin-btop}/themes/catppuccin_latte.theme";

  # yazi: catppuccin/yazi provides complete theme.toml files rather than flavour packages, so the
  # file is linked as theme.toml (programs.yazi.theme must stay unset; it writes the same file).
  # Its `syntect_theme` points at ~/.config/yazi/Catppuccin-latte.tmTheme, which is provided from
  # catppuccin/bat so that code previews are themed as well.
  xdg.configFile."yazi/theme.toml".source =
    "${catppuccin-yazi}/themes/latte/catppuccin-latte-${yaziAccent}.toml";
  xdg.configFile."yazi/Catppuccin-latte.tmTheme".source =
    "${catppuccin-bat}/themes/Catppuccin Latte.tmTheme";
}
