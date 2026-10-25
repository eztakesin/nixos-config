# KDE Plasma for the operator, declared with plasma-manager (https://github.com/nix-community/plasma-manager),
# which writes the keys below into Plasma's own config files at login and leaves every other key alone.
#  - Look: Catppuccin colours, window decorations, cursors and folder icons from nixpkgs' packages; the NixOS
#    Catppuccin wallpaper on the desktop and the lock screen. One flavour and accent: my.look (my/default.nix).
#  - Layout, after macOS: a thin top bar (launcher, virtual desktops, tray, clock) and a floating dock that stays
#    hidden until the pointer touches the bottom edge. plasma-manager re-creates the panels at each login, so
#    panel changes made by hand do not survive a rebuild.
#  - Tiling with Polonium (https://github.com/zeroxoneafour/polonium), on KWin's own tiles. Engine "half" is dwm's
#    master and stack (master area 50 %, as in the operator's dwm patch); Meta+| (Polonium's default) cycles
#    through its other engines, the i3-style binary tree among them.
#  - Shortcuts after the operator's i3 and dwm setups (Super as the modifier); the KDE defaults they collide
#    with are moved or unbound below.
#  - fcitx5 as KWin's input method, so it runs as the Wayland input method and not as an ordinary client.
{ pkgs, lib, my, ... }:
let
  flavor = my.look.flavor or "latte";
  accent = my.look.accent or "blue";
  cap = s: lib.toUpper (lib.substring 0 1 s) + lib.substring 1 (-1) s;
  dark = flavor != "latte";
  wallpaper = "${pkgs.nixos-artwork.wallpapers."catppuccin-${flavor}"}/share/wallpapers/catppuccin-${flavor}/contents/images/nixos-wallpaper-catppuccin-${flavor}.png";

  # Desktop n (1–10) on Super+n; Super+Shift+n moves the window there (Shift+digit as KDE records it, US layout).
  digits = [ "1" "2" "3" "4" "5" "6" "7" "8" "9" "0" ];
  shifted = [ "!" "@" "#" "$" "%" "^" "&" "*" "(" ")" ];
  perDesktop = f: lib.listToAttrs (lib.imap1 f digits);
in
{
  home.packages = [
    (pkgs.catppuccin-kde.override {
      flavour = [ flavor ];
      accents = [ accent ];
      winDecStyles = [ "modern" ];
    })
    pkgs.catppuccin-cursors."${flavor}${cap accent}"
    (pkgs.catppuccin-papirus-folders.override { inherit flavor accent; })
  ];

  programs.plasma = {
    enable = true;

    workspace = {
      colorScheme = "Catppuccin${cap flavor}${cap accent}";
      cursor = {
        theme = "catppuccin-${flavor}-${accent}-cursors";
        size = 24;
      };
      iconTheme = if dark then "Papirus-Dark" else "Papirus-Light";
      windowDecorations = {
        library = "org.kde.kwin.aurorae";
        theme = "__aurorae__svg__Catppuccin${cap flavor}-Modern";
      };
      inherit wallpaper;
    };
    kscreenlocker.appearance.wallpaper = wallpaper;

    panels = [
      {
        location = "top";
        height = 30;
        widgets = [
          "org.kde.plasma.kickoff"
          { pager.general.displayedText = "desktopNumber"; } # the desktops as numbers, like i3's workspaces
          "org.kde.plasma.panelspacer"
          "org.kde.plasma.systemtray"
          "org.kde.plasma.digitalclock"
        ];
      }
      {
        location = "bottom";
        floating = true;
        hiding = "autohide";
        lengthMode = "fit";
        alignment = "center";
        height = 56;
        widgets = [
          {
            iconTasks.launchers = [
              "applications:org.kde.dolphin.desktop"
              "applications:firefox.desktop"
              "applications:tor-browser.desktop" # the desktop file of the bwrap wrapper (pkgs/default.nix)
              "applications:kitty.desktop"
              "applications:thunderbird.desktop"
              "applications:codium.desktop"
              "applications:org.signal.Signal.desktop"
              "applications:im.riot.Riot.desktop"
              "applications:org.telegram.desktop.desktop"
              "applications:systemsettings.desktop"
            ];
          }
        ];
      }
    ];

    kwin = {
      virtualDesktops = {
        number = 10;
        rows = 1;
      };
      # plasma-manager installs and enables the script; its settings options still write Polonium 1.1's keys
      # (EngineType …), which Polonium 1.2 ignores, so the 1.2 keys are set directly below (res/main.xml,
      # src/controller/config.ts of Polonium 1.2.1). Seen in a VM test: the engine stayed the binary tree.
      scripts.polonium.enable = true;
    };

    # From the i3 config's `for_window [class=…] move to workspace N`, for the apps still in use: the app opens on
    # its desktop and can be moved from there (i3 had Telegram on 2, Firefox on 3, Code on 8). plasma-manager
    # gives the desktops the fixed ids Desktop_1 … Desktop_10, which the rules refer to.
    window-rules = [
      {
        description = "Messaging on desktop 2";
        match.window-class = { value = "(?i)(signal|element|telegram)"; type = "regex"; };
        apply.desktops = { value = "Desktop_2"; apply = "initially"; };
      }
      {
        description = "Firefox on desktop 3";
        match.window-class = { value = "(?i)^firefox"; type = "regex"; };
        apply.desktops = { value = "Desktop_3"; apply = "initially"; };
      }
      {
        description = "VSCodium on desktop 8";
        match.window-class = { value = "(?i)(vscodium|codium)"; type = "regex"; };
        apply.desktops = { value = "Desktop_8"; apply = "initially"; };
      }
    ];

    configFile.kwinrc.Wayland.InputMethod = "/run/current-system/sw/share/applications/org.fcitx.Fcitx5.desktop";
    configFile.kwinrc."Script-polonium" = {
      DefaultEngine = 1; # 0 binary tree (i3), 1 half (dwm), 2 three columns, 3 pillars, 4 pager, 5 KWin
      HalfMiddleSplit = 0.5; # master area 50 %, dwm's mfact in the earlier patch
      HalfKeepMaster = true; # one window in the master area, the others in the stack
      # plasma-manager's Polonium module declares this key itself (empty unless its settings are used): force.
      Borders = lib.mkForce 2; # a border on the focused window only (0 none … 4 all)
    };

    shortcuts = {
      kwin = {
        # Polonium: its own defaults are Meta+H/J/K/L (focus) and Meta+Shift+H/J/K/L (move); the arrows as in i3.
        PoloniumActivateLeft = [ "Meta+H" "Meta+Left" ];
        PoloniumActivateBelow = [ "Meta+J" "Meta+Down" ];
        PoloniumActivateAbove = [ "Meta+K" "Meta+Up" ];
        PoloniumActivateRight = [ "Meta+L" "Meta+Right" ];
        PoloniumPlaceLeft = [ "Meta+Shift+H" "Meta+Shift+Left" ];
        PoloniumPlaceBelow = [ "Meta+Shift+J" "Meta+Shift+Down" ];
        PoloniumPlaceAbove = [ "Meta+Shift+K" "Meta+Shift+Up" ];
        PoloniumPlaceRight = [ "Meta+Shift+L" "Meta+Shift+Right" ];
        # Resizing moves from Meta+Ctrl to Meta+Alt, so that Meta+Ctrl+L can lock the screen as in i3.
        PoloniumResizeLeft = "Meta+Alt+H";
        PoloniumResizeDown = "Meta+Alt+J";
        PoloniumResizeUp = "Meta+Alt+K";
        PoloniumResizeRight = "Meta+Alt+L";
        PoloniumToggleActiveTiling = "Meta+Shift+Space"; # i3's floating toggle
        "Window Close" = [ "Meta+Shift+Q" "Alt+F4" ];
        "Window Fullscreen" = "Meta+F";
        # Freed for the bindings above: quick tiling on Meta+arrows, "show desktop" on Meta+D.
        "Window Quick Tile Left" = [ ];
        "Window Quick Tile Right" = [ ];
        "Window Quick Tile Top" = [ ];
        "Window Quick Tile Bottom" = [ ];
        "Show Desktop" = [ ];
      }
      // perDesktop (i: d: lib.nameValuePair "Switch to Desktop ${toString i}" "Meta+${d}")
      // perDesktop (i: _: lib.nameValuePair "Window to Desktop ${toString i}" "Meta+${lib.elemAt shifted (i - 1)}");
      # Meta+1…0 belong to the virtual desktops, not to the dock's entries.
      plasmashell = perDesktop (i: _: lib.nameValuePair "activate task manager entry ${toString i}" [ ]);
      ksmserver."Lock Session" = [ "Meta+Ctrl+L" "Screensaver" ];
      # fcitx5 switches layouts; Meta+Alt+K goes to Polonium.
      "KDE Keyboard Layout Switcher"."Switch to Next Keyboard Layout" = [ ];
      "services/org.kde.krunner.desktop"._launch = [ "Meta+D" "Alt+Space" "Alt+F2" "Search" ]; # i3: dmenu/rofi
      "services/kitty.desktop"._launch = "Meta+Shift+Return";
      "services/org.kde.dolphin.desktop"._launch = [ "Meta+Shift+F" "Meta+E" ];
      "services/firefox.desktop"._launch = "Meta+Shift+B";
    };
  };
}
