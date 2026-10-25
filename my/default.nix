# Project-global data injected into every NixOS + Home-Manager evaluation via specialArgs
# (the "my" pattern from oxalica: plain data, no module system).
#
# This file is PUBLIC. It holds only non-identifying placeholders. Real values (operator identity,
# secondary account, cache keys) live in `my/private.nix`, which is gitignored and merged over these defaults
# key by key at eval time (see `merge` below). Keep real data out of the public repo. A commented template of
# private.nix: my/example.private.nix.
#
# A flake's source is the git tree, so the ignored private.nix is only seen when evaluating from a path
# reference (e.g. `nixos-rebuild --flake path:.#cobalt`); plain `.#cobalt` gets the placeholders below.
let
  public = {
    user = {
      username = "operator";
      fullName = "Operator";
      email = "operator@example.invalid";
      gpgFingerprint = ""; # set in my/private.nix
      timeZone = "UTC";
    };
    # Secondary local account (see https://nixos.ssf.network/reference/architecture/). Placeholder here.
    secondary = {
      username = "guest";
      fullName = "Guest";
      timeZone = "UTC";
    };
    # Hostname of the machine (operator choice). `cobalt` remains the internal codename used for the flake
    # attribute, hosts/ directory, disk labels and documentation.
    hostName = "macbook";
    # Block devices for disko, by stable /dev/disk/by-id/ path. Real serials live in my/private.nix.
    # The placeholders are deliberately invalid so disko can never format the wrong disk by accident.
    disks = {
      usb = "/dev/disk/by-id/REPLACE-ME-usb";
      nvme = "/dev/disk/by-id/REPLACE-ME-nvme";
    };
    locale = {
      default = "en_US.UTF-8";
      extra = [
        "zh_CN.UTF-8/UTF-8"
        "ja_JP.UTF-8/UTF-8"
      ];
    };
    # Further fcitx5 input-method addons, as nixpkgs attribute paths (e.g. "fcitx5-chewing"). Set in
    # my/private.nix together with any locale it needs, so the public configuration does not list every
    # language the operator types.
    inputMethods.extraAddons = [ ];
    # fcitx5 input methods to add to the profile after the public ones (rime, mozc, keyboard-us-altgr-intl),
    # by their fcitx5 names (e.g. "chewing", or "keyboard-de" for an XKB layout); also set in my/private.nix.
    inputMethods.extraItems = [ ];
    # Extra USBGuard rules for your own USB devices (sticks, a card reader, a second YubiKey): lines of the
    # USBGuard rule language, added after the public Yubico rule (modules/nixos/hardening/peripherals.nix).
    # They name serial numbers, so set them in my/private.nix. To get a device's line, plug it in on the
    # laptop and run `sudo usbguard generate-policy`; keep `id`, `serial`, `name` and `with-interface`, and
    # drop `hash`, `parent-hash`, `via-port` and `with-connect-type`, which can tie the rule to one port.
    # https://usbguard.github.io/documentation/rule-language.html
    usbguard.rules = "";
    # Self-hosted binary cache (attic/harmonia). Empty = cache.nixos.org only.
    cache = {
      url = "";
      publicKey = "";
    };
    # Catppuccin flavour and accent for the login screen and the fcitx5 candidate window
    # (modules/nixos/desktop-kde.nix, modules/nixos/locale-fonts.nix); the desktop itself uses the Itchy theme
    # (home/modules/plasma.nix).
    # Flavours: latte (light), frappe, macchiato, mocha (dark); accents: https://catppuccin.com/palette
    look = {
      flavor = "latte";
      accent = "blue";
    };
    # Opt-in features (https://nixos.ssf.network/reference/packages/): zoom, java, julia, foundry, azure, android, killSwitch.
    features = { };
    # KDE Plasma personalisation of the operator's account (home/modules/plasma.nix; the theme packages in
    # modules/nixos/desktop-kde.nix). Change single keys in my/private.nix; the others keep these values.
    # https://nixos.ssf.network/reference/personalisation/
    desktop = {
      # The global theme and its parts. Any installed one works: `plasma-apply-lookandfeel --list`,
      # `plasma-apply-colorscheme --list-schemes`, `plasma-apply-desktoptheme --list-themes`.
      lookAndFeel = "Itchy";
      colorScheme = "Itchy";
      plasmaStyle = "Itchy";
      windowDecoration = {
        library = "org.kde.kwin.aurorae";
        theme = "__aurorae__svg__Itchy";
      };
      iconTheme = "Zafiro-icons-Light"; # or "Zafiro-icons-Dark", "breeze", "breeze-dark"
      cursor = {
        theme = "macOS-TransFlag"; # or e.g. "breeze_cursors"
        size = 24;
        # The colours of macOS-TransFlag (pkgs/cursor-macos-transflag.nix), here the Mac's pointer colours.
        fill = "#93E4F3";
        outline = "#FFCCDA";
      };
      # Desktop and lock screen (the login screen keeps its own: both accounts share it). A download
      # { url; hash; }, a file next to private.nix (./wallpaper.png, git-ignored), or an absolute path.
      wallpaper = {
        url = "https://raw.githubusercontent.com/eztakesin/nix-darwin-kickstarter/14d9f68d5208924a296f162db197bc59a02dbf1b/macbook/dotfiles/wallpapers/wallpaper.png";
        hash = "sha256-I7MVmq46VeJ/6M2x8jUQt3tfnQtbz2ZbTh+GkoyPN9U=";
      };
      scale = 1.25; # the built-in panel; null leaves the scale to KDE
      clock = {
        format = "24h"; # top bar: "24h", "12h" or "default" (the locale's)
        seconds = true; # top bar
        date = "longDate"; # top bar: "shortDate", "longDate", "isoDate", or null for no date
        lockScreen = "HH:mm:ss"; # Qt time format of the lock-screen clock, e.g. "HH:mm" or "h:mm AP"
      };
      # LC_TIME of the Plasma session: "C.UTF-8" gives 24-hour time and the long date "Sunday, 25 October 2026" in
      # every KDE application; null leaves dates and times to the default locale.
      timeLocale = "C.UTF-8";
      keepAwakeOnAC = true; # on AC: no sleep, no dimming, no blank screen
      autoLock = false; # lock the screen after idle time, on AC and on battery; locking after sleep stays on
      restoreSession = false; # reopen the last session's applications at login
      tileGap = 0; # pixels between tiled windows and around them
      # Apps that open floating instead of tiled, by window class (exact names; a list here replaces this one
      # whole). Dialogs that belong to a window float anyway.
      floatingApps = [
        "org.kde.spectacle" # the screenshot tool's window
        "spectacle"
        "xdg-desktop-portal-kde" # file and other dialogs of sandboxed apps
        "org.freedesktop.impl.portal.desktop.kde"
        "pinentry-qt"
        "org.kde.kcalc"
      ];
      globalMenu = true; # the application's menus in the top bar, as on macOS (KDE and other Qt apps)
      # Apps that always open on one desktop, like i3's `for_window … move to workspace N`: regular expressions on
      # the window class. Empty: every app opens on the desktop in view.
      appDesktops = [ ];
      # The dock's apps, by desktop file name (ls /run/current-system/sw/share/applications ~/.nix-profile/share/applications).
      dock = [
        "org.kde.dolphin.desktop"
        "firefox.desktop"
        "tor-browser.desktop"
        "kitty.desktop"
        "thunderbird.desktop"
        "codium.desktop"
        "org.signal.Signal.desktop"
        "im.riot.Riot.desktop"
        "org.telegram.desktop.desktop"
        "systemsettings.desktop"
      ];
    };
  };
  private = if builtins.pathExists ./private.nix then import ./private.nix else { };
  # Key by key, recursively: a private `desktop = { iconTheme = "breeze"; };` changes that key and keeps the
  # other defaults. Lists and all other values are replaced whole.
  merge =
    a: b:
    a
    // builtins.mapAttrs (
      k: v: if builtins.isAttrs v && builtins.isAttrs (a.${k} or null) then merge a.${k} v else v
    ) b;
in
merge public private
