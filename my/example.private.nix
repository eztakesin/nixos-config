# Template of my/private.nix. Copy it (`cp my/example.private.nix my/private.nix`) and fill in your own values.
# private.nix is git-ignored and merged over my/default.nix key by key, so whatever you leave out keeps its
# default there. Real names, disk serials, keys and device serial numbers go into private.nix only: never into
# this file or my/default.nix. Build from a path reference, so that the ignored file is included:
#   sudo nixos-rebuild switch --flake path:.#cobalt
# Docs: https://nixos.ssf.network/reference/personalisation/ (the desktop) and the install runbook (the rest).
{
  # Your account. gpgFingerprint: your signing key (gpg --list-secret-keys --keyid-format long).
  user = {
    username = "alice";
    fullName = "Alice";
    email = "alice@example.org";
    gpgFingerprint = "";
    timeZone = "UTC"; # e.g. "Europe/Berlin" (timedatectl list-timezones)
  };

  # The second local account.
  secondary = {
    username = "bob";
    fullName = "Bob";
    timeZone = "UTC";
  };

  # Disks by stable id (ls -l /dev/disk/by-id/): the key stick and the internal SSD. The REPLACE-ME values
  # cannot match a real disk, so nothing is formatted until you set them.
  disks = {
    usb = "/dev/disk/by-id/REPLACE-ME-usb"; # e.g. "/dev/disk/by-id/usb-Vendor_Model_<serial>-0:0"
    nvme = "/dev/disk/by-id/REPLACE-ME-nvme"; # e.g. "/dev/disk/by-id/nvme-Vendor_Model_<serial>"
  };

  # The default locale and further ones, as glibc entries.
  locale = {
    default = "en_US.UTF-8";
    extra = [
      "zh_CN.UTF-8/UTF-8"
      "ja_JP.UTF-8/UTF-8"
    ];
  };

  # Further input methods: the addon's nixpkgs attribute and its name in fcitx5.
  # inputMethods = {
  #   extraAddons = [ "fcitx5-chewing" ];
  #   extraItems = [ "chewing" ];
  # };

  # Your own USB devices, one line each from `sudo usbguard generate-policy` (keep id, serial, name and
  # with-interface; delete hash, parent-hash and with-connect-type).
  # usbguard.rules = ''
  #   allow id 0bda:0129 serial "000000000001" name "USB2.0-CRW" with-interface ff:06:50
  # '';

  # A self-hosted binary cache; empty means cache.nixos.org only.
  # cache = {
  #   url = "https://cache.example.org";
  #   publicKey = "cache.example.org-1:<public key>";
  # };

  # KDE Plasma, for your account: set only what you change. Every key and its default is in my/default.nix.
  desktop = {
    # Plasma's own Breeze instead of the Itchy theme:
    # lookAndFeel = "org.kde.breeze.desktop";
    # colorScheme = "BreezeLight";
    # plasmaStyle = "default";
    # windowDecoration = { library = "org.kde.breeze"; theme = "Breeze"; };

    # iconTheme = "Zafiro-icons-Dark";

    # The macOS cursor in other colours, here the trans flag's own blue and pink; or another theme.
    # cursor = { fill = "#5BCEFA"; outline = "#F5A9B8"; size = 32; };
    # cursor.theme = "breeze_cursors";

    # A picture next to this file (my/wallpaper.png, git-ignored), an absolute path, or a download:
    # wallpaper = ./wallpaper.png;
    # wallpaper = { url = "https://example.org/picture.png"; hash = "sha256-…"; }; # hash: nix store prefetch-file <url>

    # scale = 1.5; # or null: leave the scale to KDE

    # 12-hour clock without seconds and a short date in the top bar, and a 12-hour lock screen:
    # clock = { format = "12h"; seconds = false; date = "shortDate"; lockScreen = "h:mm AP"; };

    # Formats (Region & Language), a locale per LC_* category. The default locale's dates, US units and Letter paper:
    # formats = { LC_TIME = null; LC_MEASUREMENT = null; LC_PAPER = null; };
    # German numbers and money as well (a locale other than C.UTF-8 also goes into locale.extra above):
    # formats = { LC_NUMERIC = "de_DE.UTF-8"; LC_MONETARY = "de_DE.UTF-8"; };

    # Laptop defaults instead: sleep and screen blanking on AC, a lock after 10 idle minutes (true: KDE's 5), the
    # last session reopened.
    # keepAwakeOnAC = false;
    # autoLock = 10;
    # restoreSession = true;

    # "Shake pointer to find it" on again:
    # shakeCursor = true;

    # The dock's apps, by desktop file name:
    # dock = [ "org.kde.dolphin.desktop" "firefox.desktop" "kitty.desktop" "systemsettings.desktop" ];

    # Tiling: a gap between windows, more apps that float (the list replaces the default one), no global menu.
    # tileGap = 8;
    # floatingApps = [ "org.kde.spectacle" "xdg-desktop-portal-kde" "org.freedesktop.impl.portal.desktop.kde" "org.kde.kcalc" "org.kde.ark" ];
    # globalMenu = false;

    # Apps on fixed desktops, as in the earlier i3 configuration:
    # appDesktops = [
    #   { match = "(?i)(signal|element|telegram)"; desktop = 2; }
    #   { match = "(?i)^firefox"; desktop = 3; }
    #   { match = "(?i)(vscodium|codium)"; desktop = 8; }
    # ];
  };

  # The Catppuccin flavour of the login screen and the fcitx5 candidate window:
  # look = { flavor = "mocha"; accent = "mauve"; };

  # Opt-in features (https://nixos.ssf.network/reference/packages/), e.g. a Chrome for a browser wallet only, with
  # Rabby Wallet as its one extension (walletBrowser.extensions in my/default.nix):
  # features = { walletBrowser = true; };
}
