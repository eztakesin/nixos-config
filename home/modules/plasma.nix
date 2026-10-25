# KDE Plasma for the operator, declared with plasma-manager (https://github.com/nix-community/plasma-manager),
# which writes the keys below into Plasma's own config files at login and leaves every other key alone.
#  - Look: the Itchy global theme as the base (colours, Plasma style, window decoration: pkgs/itchy-kde-theme.nix),
#    Zafiro icons and a macOS-shaped cursor in the Mac's pointer colours (pkgs/cursor-macos-transflag.nix). The
#    Mac's wallpaper on the desktop and the lock screen; the login screen keeps a neutral one, because both
#    accounts share it (modules/nixos/desktop-kde.nix).
#  - Layout, after macOS: a thin top bar (launcher, virtual desktops, tray, clock) and a floating dock that stays
#    hidden until the pointer touches the bottom edge. plasma-manager re-creates the panels at each login, so
#    panel changes made by hand do not survive a rebuild.
#  - Tiling with Polonium (https://github.com/zeroxoneafour/polonium), on KWin's own tiles. Engine "half" is dwm's
#    master and stack (master area 50 %, as in the operator's dwm patch); Meta+| (Polonium's default) cycles
#    through its other engines, the i3-style binary tree among them.
#  - Shortcuts after the operator's i3 and dwm setups (Super as the modifier); the KDE defaults they collide
#    with are moved or unbound below.
#  - fcitx5 as KWin's input method, so it runs as the Wayland input method and not as an ordinary client.
#  - Clock: 24-hour time with seconds and the long date, in the top bar and on the lock screen. Display scale
#    125 % on the built-in panel.
#  - Power on AC: no sleep, no dimming, no blank screen; no automatic screen lock (locking after sleep stays).
#  - Every login starts with an empty session. Privacy: no file indexing, no recent-files history, X11 apps
#    cannot read keys typed into other apps, and the day-night cycle runs on fixed times, not on a location.
{ pkgs, lib, ... }:
let
  # The Mac's wallpaper, an illustration in the operator's public nix-darwin repository, pinned to the commit
  # that added it, so that both machines show the same picture.
  wallpaper = pkgs.fetchurl {
    name = "wallpaper.png";
    url = "https://raw.githubusercontent.com/eztakesin/nix-darwin-kickstarter/14d9f68d5208924a296f162db197bc59a02dbf1b/macbook/dotfiles/wallpapers/wallpaper.png";
    hash = "sha256-I7MVmq46VeJ/6M2x8jUQt3tfnQtbz2ZbTh+GkoyPN9U=";
  };
  kscreenDoctor = "${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor";

  # Desktop n (1–10) on Super+n; Super+Shift+n moves the window there (Shift+digit as KDE records it, US layout).
  digits = [ "1" "2" "3" "4" "5" "6" "7" "8" "9" "0" ];
  shifted = [ "!" "@" "#" "$" "%" "^" "&" "*" "(" ")" ];
  perDesktop = f: lib.listToAttrs (lib.imap1 f digits);
in
{
  programs.plasma = {
    enable = true;

    # The themes, icons and cursor are installed system-wide (modules/nixos/desktop-kde.nix).
    workspace = {
      # Itchy as the base: applying it sets its colour scheme, Plasma style and window decoration; the entries
      # below then replace its cursor (WhiteSur, not installed), icons and wallpaper.
      lookAndFeel = "Itchy";
      colorScheme = "Itchy";
      theme = "Itchy";
      windowDecorations = {
        library = "org.kde.kwin.aurorae";
        theme = "__aurorae__svg__Itchy";
      };
      iconTheme = "Zafiro-icons-Light"; # the light variant (it inherits breeze, the other one breeze-dark)
      cursor = {
        theme = "macOS-TransFlag";
        size = 24;
      };
      inherit wallpaper;
    };
    kscreenlocker = {
      appearance.wallpaper = wallpaper;
      # On request: no automatic lock after idle time. KDE has one setting for AC and battery, so this holds on
      # battery too. Locking after sleep stays on, and Meta+Ctrl+L locks by hand.
      autoLock = false;
      lockOnResume = true;
    };

    panels = [
      {
        location = "top";
        height = 30;
        widgets = [
          "org.kde.plasma.kickoff"
          { pager.general.displayedText = "desktopNumber"; } # the desktops as numbers, like i3's workspaces
          "org.kde.plasma.panelspacer"
          "org.kde.plasma.systemtray"
          {
            digitalClock = {
              time = {
                format = "24h";
                showSeconds = "always";
              };
              date = {
                enable = true;
                format = "longDate";
                position = "besideTime";
              };
            };
          }
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

    # Power on AC, on request: never sleep, never dim, never blank the screen. Hibernation cannot happen at all:
    # swap gets a new random key at every boot, and protectKernelImage disables it (hardening/kernel.nix).
    powerdevil.AC = {
      autoSuspend.action = "nothing";
      dimDisplay.enable = false;
      turnOffDisplay.idleTimeout = "never";
    };

    # Every login starts empty: no applications reopened from the previous session.
    session.sessionRestore.restoreOpenApplicationsOnLogin = "startWithEmptySession";

    # Lock-screen clock: Breeze's lock screen prints the time in the locale's short format, and seconds only
    # when that format has them (org/kde/breeze/components/Clock.qml in plasma-workspace 6.8). The C locale's
    # short time format is HH:mm:ss and its long date "dddd, d MMMM yyyy", so LC_TIME=C.UTF-8 gives 24-hour
    # time with seconds and the long date there, and in the other KDE applications.
    configFile."plasma-localerc".Formats.LC_TIME = "C.UTF-8";

    # Privacy: no file indexing (Baloo); no history of opened files: the activity manager's "do not remember"
    # (what-to-remember 2, kactivitymanagerd_plugins_settings.kcfg), KDE's recent documents, GTK's
    # recently-used list, and KRunner's recent-documents search.
    configFile.baloofilerc."Basic Settings"."Indexing-Enabled" = false;
    configFile."kactivitymanagerd-pluginsrc"."Plugin-org.kde.ActivityManager.Resources.Scoring"."what-to-remember" = 2;
    configFile.kdeglobals.RecentDocuments = {
      UseRecent = false;
      MaxEntries = 0;
    };
    configFile.krunnerrc.Plugins.krunner_recentdocumentsEnabled = false;
    configFile."gtk-3.0/settings.ini".Settings.gtk-recent-files-enabled = false;
    configFile."gtk-4.0/settings.ini".Settings.gtk-recent-files-enabled = false;

    # "Legacy X11 App Support": X11 apps may not read keys typed into other apps (KWin's default lets them see
    # key combinations, kwin.kcfg XwaylandEavesdrops). The sandboxed apps get no X11 at all (pkgs/bwrap-app.nix);
    # this covers the rest, such as a Flatpak app that falls back to X11.
    configFile.kwinrc.Xwayland.XwaylandEavesdrops = "None";

    # Day-night cycle on fixed times (06:00 and 18:00) instead of the location (nighttimesettings.kcfg), so
    # nothing looks the location up, even if a location service came back (GeoClue2 is off: desktop-kde.nix).
    configFile.knighttimerc = {
      General.Source = "Times";
      Location.Automatic = false;
    };

    # Display scale 125 % on the built-in panel, set at each login: KWin keeps output settings in its own state
    # file (kwinoutputconfig.json), which plasma-manager does not write. External screens keep their own scale.
    startup.startupScript.displayScale = {
      text = ''
        for output in $(${kscreenDoctor} -j | ${pkgs.jq}/bin/jq -r '.outputs[] | select(.connected and .enabled) | .name | select(test("^(eDP|LVDS|DSI)"))'); do
          ${kscreenDoctor} "output.$output.scale.1.25"
        done
      '';
      runAlways = true;
    };
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
