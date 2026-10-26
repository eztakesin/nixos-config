# Application confinement. Three layers, none complete on its own:
#   - Flatpak + xdg-desktop-portal for the messengers (messaging.nix): each app sees its own data, files come
#     through the portal's file chooser.
#   - bubblewrap wrappers (pkgs/bwrap-app.nix, oxalica's pattern) for the programs that open untrusted
#     content: Firefox, Tor Browser (tor.nix) and the document viewer. Firefox gets a filtered session bus with
#     the desktop portal and its own name (pkgs/default.nix): links for other apps leave through the portal, and
#     links from other apps reach the running Firefox. Tor Browser and the viewer get no bus. Uploads and
#     downloads go through the Downloads folder.
#   - AppArmor profiles for those same programs, in COMPLAIN mode: they log what a program does beyond its
#     profile without blocking it. On the laptop, collect the log, complete the profiles, then switch them to
#     enforce (state = "enforce"):
#       journalctl -k --grep 'apparmor="ALLOWED"'
#     Profiles attach to the real executables in /nix/store (upstream's FHS-path profiles never attach here,
#     which is why apparmor-profiles' own browser profiles are not used). D-Bus mediation stays off
#     (services.dbus.apparmor), so these profiles cannot restrict D-Bus.
# firejail is deliberately not used (setuid-root helper).
{
  config,
  pkgs,
  lib,
  mypkgs,
  ...
}:
let
  inherit (mypkgs) firefox-bwrap zathura-bwrap;
  firefox = firefox-bwrap.passthru.package;
  zathura = zathura-bwrap.passthru.package;
  closure = name: roots: pkgs.apparmorRulesFromClosure { inherit name; } roots;
  graphics = closure "graphics" [ config.hardware.graphics.package ];

  # Shared by the two browsers: GPU, audio, fonts, TLS, the network, and Firefox's own content sandbox
  # (a user namespace, chroot and seccomp — hence userns and the three capabilities inside it).
  browserCommon = ''
    include <abstractions/base>
    include <abstractions/audio>
    include <abstractions/dri-common>
    include <abstractions/fonts>
    include <abstractions/nameservice>
    include <abstractions/ssl_certs>
    include <abstractions/vulkan>
    include "${graphics}"
    userns,
    capability sys_admin,
    capability sys_chroot,
    capability sys_ptrace,
    network inet stream,
    network inet6 stream,
    network inet dgram,
    network inet6 dgram,
    network netlink raw,
    /etc/** r,
    /sys/** r,
    /dev/dri/* rw,
    @{PROC}/** r,
    owner /tmp/** rwlk,
    owner /dev/shm/** rwlk,
    owner @{HOME}/Downloads/** rwl,
    owner @{HOME}/.config/user-dirs.dirs r,
    owner @{HOME}/.config/gtk-{3,4}.0/** r,
    owner @{HOME}/{.icons,.local/share/icons}/** r,
  '';

  profiles = {
    firefox-bwrap = ''
      abi <abi/4.0>,
      include <tunables/global>
      profile firefox-bwrap ${firefox}/lib/firefox/firefox{,-bin} {
        ${browserCommon}
        include "${closure "firefox" [ firefox ]}"
        ${firefox}/lib/firefox/** mrix,
        owner @{HOME}/.config/mozilla/** rwlk,
        owner @{HOME}/.cache/mozilla/** rwlk,
      }
    '';
    zathura-bwrap = ''
      abi <abi/4.0>,
      include <tunables/global>
      profile zathura-bwrap ${pkgs.zathuraPkgs.zathura_core.bin}/bin/zathura-sandbox {
        include <abstractions/base>
        include <abstractions/fonts>
        include "${closure "zathura" [ zathura ]}"
        /etc/** r,
        @{PROC}/** r,
        owner /tmp/** rw,
        # The opened document can be anywhere the user keeps files; the sandbox binds only that one file.
        owner @{HOME}/** r,
        /{media,run/media,mnt}/** r,
      }
    '';
  }
  // lib.optionalAttrs (mypkgs ? tor-browser-bwrap) {
    tor-browser-bwrap =
      let
        tbb = "${mypkgs.tor-browser-bwrap.passthru.package}/share/tor-browser";
      in
      ''
        abi <abi/4.0>,
        include <tunables/global>
        profile tor-browser-bwrap ${tbb}/firefox {
          ${browserCommon}
          include "${closure "tor-browser" [ mypkgs.tor-browser-bwrap.passthru.package ]}"
          ${tbb}/** mrix,
          owner "@{HOME}/.tor project/**" rwlk,
          owner "@{HOME}/.cache/tor project/**" rwlk,
        }
      '';
  };
in
{
  security.apparmor = {
    enable = true;
    # Off: it kills a running program whenever its profile is (re)loaded, so every rebuild that touches the
    # browser would close the browser. The profiles below are in complain mode anyway.
    killUnconfinedConfinables = false;
    # The abstractions from apparmor-profiles are already on the include path
    # (nixos/modules/security/apparmor/profiles.nix); profiles load only when listed here.
    policies = lib.mapAttrs (_: profile: {
      state = "complain";
      inherit profile;
    }) profiles;
  };

  environment.systemPackages = [
    pkgs.bubblewrap
    firefox-bwrap
    zathura-bwrap
  ];

  # Firefox enterprise policies, system-wide. Firefox on Linux reads /etc/firefox/policies/policies.json in
  # preference to the copy inside its package, and the sandbox sees /etc read-only. (Home-Manager can only
  # attach policies to a package it installs itself, and Firefox is installed here, sandboxed.)
  # https://mozilla.github.io/policy-templates/
  environment.etc."firefox/policies/policies.json".text = builtins.toJSON {
    policies = {
      DisableAppUpdate = true; # updates come with the system
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DontCheckDefaultBrowser = true;
      ExtensionSettings = {
        # uBlock Origin, pinned installed (arkenfox's recommended content blocker)
        "uBlock0@raymondhill.net" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
        };
      };
    };
  };

  # Documents open in the sandboxed viewer. Okular, Plasma's default viewer, runs unconfined and is left out.
  environment.plasma6.excludePackages = [ pkgs.kdePackages.okular ];
  xdg.mime.defaultApplications = {
    "application/pdf" = "org.pwmt.zathura-pdf-mupdf.desktop";
    "application/epub+zip" = "org.pwmt.zathura-pdf-mupdf.desktop";
    "application/postscript" = "org.pwmt.zathura-ps.desktop";
    "image/vnd.djvu" = "org.pwmt.zathura-djvu.desktop";
    "text/html" = "firefox.desktop";
    "x-scheme-handler/http" = "firefox.desktop";
    "x-scheme-handler/https" = "firefox.desktop";
  };

  services.flatpak.enable = true;
  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
  };
}
