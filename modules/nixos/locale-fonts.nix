# Locales, fonts and input methods.
#  - Locales: the default from my/private.nix, Simplified and Traditional Chinese, Japanese, Spanish, German and
#    French, plus whatever my/private.nix adds.
#  - Fonts: Noto (Latin and most other scripts, emoji), Noto CJK, Sarasa (monospace with CJK at double width),
#    Liberation (metric-compatible with Arial, Times and Courier, for documents) and HanaMin (rare Han characters).
#    fontconfig picks the regional CJK forms by the text's language, the pattern of oxalica's nixos-config
#    (nixos/modules/l10n.nix, after https://catcat.cc/post/2021-03-07/): Japanese text gets Japanese glyph
#    forms, Traditional Chinese gets Taiwanese ones, instead of one CJK font for every language.
#  - Input methods: fcitx5, started by KWin as the Wayland input method (home/modules/plasma.nix). Rime for
#    Chinese (Simplified and Traditional schemas, home/modules/input-method.nix), Mozc for Japanese, one US layout
#    with AltGr dead keys for Spanish, German and French, then the addons and entries from my/private.nix.
#    The profile below is the default for every account; the operator's home links to it.
{ pkgs, lib, my, ... }:
let
  flavor = my.look.flavor or "latte";
  accent = my.look.accent or "blue";

  # Order = the order of the Ctrl+Space cycle and of the tray list; the first entry is the "off" state.
  imItems = [
    "keyboard-us"
    "rime"
    "mozc"
    "keyboard-us-altgr-intl" # é è ê ë ñ ü ß ç œ « » ¿ ¡ with AltGr (right Alt), US letters otherwise
  ] ++ (my.inputMethods.extraItems or [ ]);
  profile = {
    "Groups/0" = {
      Name = "Default";
      "Default Layout" = "us";
      DefaultIM = "rime";
    };
    GroupOrder."0" = "Default";
  }
  // lib.listToAttrs (
    lib.imap0 (
      i: name:
      lib.nameValuePair "Groups/0/Items/${toString i}" {
        Name = name;
        Layout = "";
      }
    ) imItems
  );

  # fontconfig: put the regional font first when the text's language matches.
  prefer = lang: generic: family: ''
    <match target="pattern">
      <test name="lang" compare="contains"><string>${lang}</string></test>
      <test name="family"><string>${generic}</string></test>
      <edit name="family" binding="strong" mode="prepend_first"><string>${family}</string></edit>
    </match>
  '';
  # Ordered like oxalica's list: "zh" also matches zh-TW and zh-HK, whose rules come later and win.
  cjk = [
    { lang = "zh"; noto = "SC"; sarasa = "SC"; }
    { lang = "zh-TW"; noto = "TC"; sarasa = "TC"; }
    { lang = "zh-HK"; noto = "HK"; sarasa = "HC"; }
    { lang = "ja"; noto = "JP"; sarasa = "J"; }
    { lang = "ko"; noto = "KR"; sarasa = "K"; }
  ];
in
{
  i18n.defaultLocale = my.locale.default;
  i18n.supportedLocales = lib.unique (
    [
      "${my.locale.default}/UTF-8"
      "zh_CN.UTF-8/UTF-8"
      "zh_TW.UTF-8/UTF-8"
      "ja_JP.UTF-8/UTF-8"
      "es_ES.UTF-8/UTF-8"
      "de_DE.UTF-8/UTF-8"
      "fr_FR.UTF-8/UTF-8"
    ]
    ++ my.locale.extra
  );

  fonts = {
    enableDefaultPackages = false; # curated set below
    fontDir.enable = true; # /run/current-system/sw/share/X11/fonts, as in oxalica's configuration
    packages = with pkgs; [
      noto-fonts # Latin and most other scripts; fontconfig falls back to them by coverage
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-color-emoji
      sarasa-gothic
      fira-code
      jetbrains-mono
      nerd-fonts.fira-code
      nerd-fonts.jetbrains-mono
      liberation_ttf
      hanazono
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
      localConf = ''
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
        <fontconfig>
          <!-- Regional variants by language (modules/nixos/locale-fonts.nix). -->
        ${lib.concatMapStrings (
          c:
          prefer c.lang "sans-serif" "Noto Sans CJK ${c.noto}"
          + prefer c.lang "serif" "Noto Serif CJK ${c.noto}"
          + prefer c.lang "monospace" "Sarasa Mono ${c.sarasa}"
        ) cjk}
        </fontconfig>
      '';
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
          catppuccin-fcitx5 # candidate-window themes, one per flavour and accent
        ])
        # my.inputMethods.extraAddons: nixpkgs attribute paths from my/private.nix
        ++ map (path: lib.getAttrFromPath (lib.splitString "." path) pkgs) (my.inputMethods.extraAddons or [ ])
        ++ (with pkgs; [
          fcitx5-gtk
          kdePackages.fcitx5-qt
        ]);
      settings = {
        inputMethod = profile;
        addons.classicui.globalSection = {
          Theme = "catppuccin-${flavor}-${accent}";
          DarkTheme = "catppuccin-${flavor}-${accent}";
          "Vertical Candidate List" = "False";
          Font = "Noto Sans 11";
        };
      };
    };
  };
}
