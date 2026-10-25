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
# The personal choices (theme, icons, cursor, wallpaper, scale, clock, power, locking, session, dock, tiling gap,
# floating apps, global menu, app desktops) come from my.desktop: defaults in my/default.nix, changes in
# my/private.nix. The privacy settings are fixed here.
{ pkgs, lib, my, ... }:
let
  d = my.desktop;
  # A download { url; hash; } (the default: the Mac's wallpaper, an illustration in the operator's public
  # nix-darwin repository, pinned to the commit that added it), or a file.
  wallpaper = if builtins.isAttrs d.wallpaper then pkgs.fetchurl d.wallpaper else d.wallpaper;
  kscreenDoctor = "${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor";
  kconfig = "${pkgs.kdePackages.kconfig}/bin";

  # The lock screen with d.clock.lockScreen as its time format. Plasma 6.8 takes the lock screen from the desktop
  # shell package, not from the global theme (kscreenlocker greeter/greeterapp.cpp: loadPackage("Plasma/Shell"),
  # "lockscreenmainscript"), and its clock prints the locale's short time format, which has no seconds, not even
  # in C. Plasma looks for shell packages in the home first, so the installed shell is mirrored there, unchanged
  # but for the clock: a copy of the Breeze one with a fixed format (its QML module prefers the compiled copy, so
  # the file cannot be patched in place). Built from the same plasma-desktop, so it follows Plasma updates.
  shellWithClock = pkgs.runCommand "plasma-shell-lockscreen-clock" { } ''
    cp -r ${pkgs.kdePackages.plasma-desktop}/share/plasma/shells/org.kde.plasma.desktop $out
    chmod -R u+w $out
    lock=$out/contents/lockscreen
    cp ${pkgs.kdePackages.plasma-workspace}/lib/qt-6/qml/org/kde/breeze/components/Clock.qml $lock/FormattedClock.qml
    chmod u+w $lock/FormattedClock.qml
    substituteInPlace $lock/FormattedClock.qml \
      --replace-fail 'Qt.formatTime(timeSource.dateTime, Qt.locale(), Locale.ShortFormat)' \
                     'Qt.formatTime(timeSource.dateTime, ${builtins.toJSON d.clock.lockScreen})' \
      --replace-fail 'trackSeconds: Qt.locale().timeFormat(Locale.ShortFormat).includes("s")' 'trackSeconds: true'
    substituteInPlace $lock/LockScreenUi.qml --replace-fail '        Clock {' '        FormattedClock {'
  '';

  # The gap between tiled windows (d.tileGap, in pixels). KWin 6.8 keeps it per virtual desktop and per screen,
  # under a key derived from the screen's EDID (src/tiles/tilemanager.cpp, readSettings), so no config file can set
  # it ahead. This KWin script sets it on every screen and desktop when KWin starts and whenever either changes
  # (scripting API: workspace.rootTile(output, desktop).padding); KWin then saves it.
  tileGapScript = {
    "kwin/scripts/tile-gap/metadata.json".text = builtins.toJSON {
      KPackageStructure = "KWin/Script";
      KPlugin = {
        Id = "tile-gap";
        Name = "Tile gap";
        Description = "Sets the gap between tiled windows on every screen and virtual desktop";
        License = "GPL-3.0-or-later";
        EnabledByDefault = false;
      };
      X-Plasma-API = "javascript";
      X-Plasma-MainScript = "code/main.js";
    };
    "kwin/scripts/tile-gap/contents/code/main.js".text = ''
      const padding = Number(readConfig("padding", 0));
      function apply() {
          for (const output of workspace.screens) {
              for (const desktop of workspace.desktops) {
                  const tile = workspace.rootTile(output, desktop);
                  if (tile && tile.padding !== padding) {
                      tile.padding = padding;
                  }
              }
          }
      }
      apply();
      workspace.screensChanged.connect(apply);
      workspace.desktopsChanged.connect(apply);
    '';
  };

  # Desktop n (1–10) on Super+n; Super+Shift+n moves the window there (Shift+digit as KDE records it, US layout).
  digits = [ "1" "2" "3" "4" "5" "6" "7" "8" "9" "0" ];
  shifted = [ "!" "@" "#" "$" "%" "^" "&" "*" "(" ")" ];
  perDesktop = f: lib.listToAttrs (lib.imap1 f digits);
in
{
  # The tile-gap KWin script and the shell with the lock-screen clock (both above), in ~/.local/share.
  xdg.dataFile = tileGapScript // {
    "plasma/shells/org.kde.plasma.desktop".source = shellWithClock;
  };

  programs.plasma = {
    enable = true;

    # The themes, icons and cursor are installed system-wide (modules/nixos/desktop-kde.nix).
    workspace = {
      # Itchy as the base: applying it sets its colour scheme, Plasma style and window decoration; the entries
      # below then replace its cursor (WhiteSur, not installed), icons and wallpaper.
      lookAndFeel = d.lookAndFeel;
      colorScheme = d.colorScheme;
      theme = d.plasmaStyle;
      windowDecorations = d.windowDecoration;
      iconTheme = d.iconTheme; # Zafiro-icons-Light: the variant that inherits breeze, the other one breeze-dark
      cursor = { inherit (d.cursor) theme size; };
      inherit wallpaper;
    };
    kscreenlocker = {
      appearance.wallpaper = wallpaper;
      # Off by default, on request: no automatic lock after idle time. KDE has one setting for AC and battery, so
      # this holds on battery too. Locking after sleep stays on, and Meta+Ctrl+L locks by hand.
      autoLock = d.autoLock;
      lockOnResume = true;
    };

    panels = [
      {
        location = "top";
        height = 30;
        widgets = [
          "org.kde.plasma.kickoff"
          { pager.general.displayedText = "desktopNumber"; } # the desktops as numbers, like i3's workspaces
        ]
        # The application's menus in the top bar, as on macOS (KDE and other Qt applications; GTK, Firefox and
        # Electron keep theirs in the window).
        ++ lib.optional d.globalMenu "org.kde.plasma.appmenu"
        ++ [
          "org.kde.plasma.panelspacer"
          "org.kde.plasma.systemtray"
          {
            digitalClock = {
              time = {
                inherit (d.clock) format;
                showSeconds = if d.clock.seconds then "always" else "never";
              };
              date =
                if d.clock.date == null then
                  { enable = false; }
                else
                  {
                    enable = true;
                    format = d.clock.date;
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
            # tor-browser.desktop is the bwrap wrapper's (pkgs/default.nix); the messengers' come from Flatpak.
            iconTasks.launchers = map (app: "applications:${app}") d.dock;
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

    # Apps opened on a fixed desktop (d.appDesktops; empty by default), like i3's `for_window … move to workspace N`.
    # The app opens there even when another desktop is shown, which looked as if Flatpak apps opened only on an empty
    # desktop. plasma-manager gives the desktops the fixed ids Desktop_1 … Desktop_10.
    window-rules = map (rule: {
      description = "${rule.match} on desktop ${toString rule.desktop}";
      match.window-class = {
        value = rule.match;
        type = "regex";
      };
      apply.desktops = {
        value = "Desktop_${toString rule.desktop}";
        apply = "initially";
      };
    }) d.appDesktops;
    # plasma-manager writes no rules file for an empty list, so the three rules of the earlier configuration
    # (messaging on 2, Firefox on 3, VSCodium on 8) would stay. Removed once, by their names; other rules stay.
    startup.startupScript.dropOldWindowRules = lib.mkIf (d.appDesktops == [ ]) {
      text = ''
        f=kwinrulesrc
        keep=""
        n=0
        for id in $(${kconfig}/kreadconfig6 --file "$f" --group General --key rules | tr ',' ' '); do
          case "$(${kconfig}/kreadconfig6 --file "$f" --group "$id" --key Description)" in
            "Messaging on desktop 2" | "Firefox on desktop 3" | "VSCodium on desktop 8") ;;
            *)
              keep="''${keep:+$keep,}$id"
              n=$((n + 1))
              ;;
          esac
        done
        ${kconfig}/kwriteconfig6 --file "$f" --group General --key rules "$keep"
        ${kconfig}/kwriteconfig6 --file "$f" --group General --key count "$n"
        ${pkgs.dbus}/bin/dbus-send --session --type=method_call --dest=org.kde.KWin /KWin org.kde.KWin.reconfigure
      '';
    };

    configFile.kwinrc.Wayland.InputMethod = "/run/current-system/sw/share/applications/org.fcitx.Fcitx5.desktop";

    # Power on AC (keepAwakeOnAC): never sleep, never dim, never blank the screen. Hibernation cannot happen at
    # all: swap gets a new random key at every boot, and protectKernelImage disables it (hardening/kernel.nix).
    powerdevil.AC = lib.mkIf d.keepAwakeOnAC {
      autoSuspend.action = "nothing";
      dimDisplay.enable = false;
      turnOffDisplay.idleTimeout = "never";
    };

    # restoreSession false: every login starts empty, no applications reopened from the previous session.
    session.sessionRestore.restoreOpenApplicationsOnLogin =
      if d.restoreSession then "onLastLogout" else "startWithEmptySession";

    # The session's LC_TIME (Plasma exports [Formats] of plasma-localerc at login); empty means the default
    # locale. The lock-screen clock has its own format (pkgs/itchy-kde-theme.nix: the locale's short format has no
    # seconds, not even in C).
    configFile."plasma-localerc".Formats.LC_TIME = if d.timeLocale == null then "" else d.timeLocale;

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

    # Display scale of the built-in panel (d.scale, 1.25 = 125 %), set at each login: KWin keeps output settings
    # in its own state file (kwinoutputconfig.json), which plasma-manager does not write. External screens keep
    # their own scale.
    startup.startupScript.displayScale = lib.mkIf (d.scale != null) {
      text = ''
        for output in $(${kscreenDoctor} -j | ${pkgs.jq}/bin/jq -r '.outputs[] | select(.connected and .enabled) | .name | select(test("^(eDP|LVDS|DSI)"))'); do
          ${kscreenDoctor} "output.$output.scale.${builtins.toJSON d.scale}"
        done
      '';
      runAlways = true;
    };
    # The tile-gap script (above), and the apps that open floating instead of tiled (Polonium's untile list, exact
    # window classes): Spectacle's window, file and other portal dialogs, pinentry, the calculator. Dialogs that
    # belong to a window (transient ones) float anyway.
    configFile.kwinrc.Plugins.tile-gapEnabled = true;
    configFile.kwinrc."Script-tile-gap".padding = d.tileGap;
    configFile.kwinrc."Script-polonium" = {
      UntileWindowClasses = lib.concatStringsSep ", " d.floatingApps;
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
