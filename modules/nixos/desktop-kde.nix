# Desktop: KDE Plasma 6 on Wayland with SDDM. Wayland gives per-app input/screen
# isolation that X11 lacks; portals (xdg-desktop-portal-kde) provide the consent prompts used by Flatpak
# apps (hardening/sandbox.nix). Audio via PipeWire with Bluetooth codecs for the headphones.
{ pkgs, lib, ... }:
{
  services.desktopManager.plasma6.enable = true;
  services.displayManager = {
    sddm = {
      enable = true;
      wayland.enable = true;
      wayland.compositor = "kwin";
    };
    defaultSession = "plasma";
  };

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
