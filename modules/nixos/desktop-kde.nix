# Desktop: KDE Plasma 6 on Wayland with SDDM. Wayland gives per-app input/screen
# isolation that X11 lacks; portals (xdg-desktop-portal-kde) provide the consent prompts used by Flatpak
# apps (hardening/sandbox.nix). Audio via PipeWire with Bluetooth codecs for the headphones.
{ pkgs, lib, my, ... }:
let
  flavor = my.look.flavor or "latte";
  accent = my.look.accent or "blue";
  wallpaper = "${pkgs.nixos-artwork.wallpapers."catppuccin-${flavor}"}/share/wallpapers/catppuccin-${flavor}/contents/images/nixos-wallpaper-catppuccin-${flavor}.png";
in
{
  services.desktopManager.plasma6.enable = true;
  services.displayManager = {
    sddm = {
      enable = true;
      wayland.enable = true;
      wayland.compositor = "kwin";
      # Login screen: Catppuccin, with a typed user name and a password and no list of accounts, so the screen
      # does not show which accounts exist. The theme has no user list at all (its UserField is a text field,
      # catppuccin/sddm templates/Components/UserField.tera); with RememberLastUser off that field starts empty
      # instead of holding the last name.
      theme = "catppuccin-${flavor}-${accent}";
      settings.Users.RememberLastUser = false;
    };
    defaultSession = "plasma";
  };

  environment.systemPackages = [
    ((pkgs.catppuccin-sddm.override {
      inherit flavor accent;
      font = "Noto Sans";
      fontSize = "11";
      background = wallpaper; # the same NixOS Catppuccin wallpaper as the desktop (home/modules/plasma.nix)
      loginBackground = true;
    }).overrideAttrs (old: {
      # Two patches to the generated QML, after a VM test in which a typed name went into the password field
      # (the theme focuses the password, which suits a remembered name): the focus starts in the name field
      # while no name is remembered (RememberLastUser is off), and Return in the name field moves on to the
      # password, as on the macOS login window (the theme handles Return only in the password field).
      postInstall = (old.postInstall or "") + ''
        c=$out/share/sddm/themes/catppuccin-${flavor}-${accent}/Components
        substituteInPlace $c/PasswordField.qml --replace-fail 'focus: true' 'focus: userModel.lastUser != ""'
        substituteInPlace $c/UserField.qml --replace-fail 'selectByMouse: true' 'selectByMouse: true
          focus: userModel.lastUser == ""'
        substituteInPlace $c/LoginPanel.qml --replace-fail 'id: userField' 'id: userField
              onAccepted: passwordField.forceActiveFocus()'
      '';
    }))
  ];

  # Chromium/Electron apps on native Wayland.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # Trim defaults we do not need.
  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    elisa
    khelpcenter
    plasma-workspace-wallpapers # 255 MB of stock wallpapers
    # NOTE: plasma-systemmonitor / ksystemstats / libksysguard are in the module's REQUIRED list, so they
    # cannot be excluded here (QtWebEngine, 466 MB, stays); btop is the preferred monitor anyway.
  ];

  # Audio
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    wireplumber = {
      enable = true;
      # Bluetooth: better codecs + hardware volume for Bluetooth headphones; unsupported codecs are ignored.
      extraConfig."10-bluez" = {
        "monitor.bluez.properties" = {
          "bluez5.enable-sbc-xq" = true;
          "bluez5.enable-msbc" = true;
          "bluez5.enable-hw-volume" = true;
          "bluez5.codecs" = [
            "sbc"
            "sbc_xq"
            "aac"
            "ldac"
            "aptx"
            "aptx_hd"
          ];
        };
      };
    };
  };

  # No network service discovery from the desktop (mDNS is also off in resolved).
  services.avahi.enable = false;

  # Location service off. Plasma enables geoclue (nixpkgs plasma6.nix, mkDefault); whenever an app asks for
  # the location it sends the Wi-Fi networks around the laptop (their BSSIDs) to an online lookup service
  # (beacondb.net). Night Color then needs a manual location or fixed times.
  services.geoclue2.enable = false;
  services.printing.enable = false; # enable per-need

  # The Plasma module enables speech-dispatcher (screen-reader TTS). It pulls espeak-ng + mbrola + ~650 MB of
  # mbrola voices into the closure. Off here (data minimization, closure size); set true if a screen reader
  # is needed.
  services.speechd.enable = lib.mkForce false;

  # The Plasma module also enables KDE PIM (Akonadi + a MariaDB server, ~400 MB). Mail/calendar here is
  # Thunderbird, so the suite — and the database server — are dropped.
  programs.kde-pim.enable = lib.mkForce false;
}
