# Locale, fonts (Latin + CJK), and input method (fcitx5: Rime for Chinese, Mozc for Japanese, plus the
# addons listed in my/private.nix). Font stack carried over from the operator's existing configs.
{ pkgs, lib, my, ... }:
{
  i18n.defaultLocale = my.locale.default;
  i18n.supportedLocales = [ "${my.locale.default}/UTF-8" ] ++ my.locale.extra;

  fonts = {
    enableDefaultPackages = false; # curated set below
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-color-emoji
      sarasa-gothic
      fira-code
      jetbrains-mono
      nerd-fonts.fira-code
      nerd-fonts.jetbrains-mono
    ];
    fontconfig = {
      enable = true;
      defaultFonts = {
        monospace = [
          "Sarasa Mono SC"
          "FiraCode Nerd Font"
          "Noto Sans Mono CJK SC"
        ];
        sansSerif = [
          "Noto Sans"
          "Noto Sans CJK SC"
        ];
        serif = [
          "Noto Serif"
          "Noto Serif CJK SC"
        ];
        emoji = [ "Noto Color Emoji" ];
      };
    };
  };

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      addons =
        (with pkgs; [
          fcitx5-rime
          fcitx5-mozc
        ])
        # my.inputMethods.extraAddons: nixpkgs attribute paths from my/private.nix
        ++ map (path: lib.getAttrFromPath (lib.splitString "." path) pkgs) (my.inputMethods.extraAddons or [ ])
        ++ (with pkgs; [
          fcitx5-gtk
          kdePackages.fcitx5-qt
        ]);
    };
  };
}
