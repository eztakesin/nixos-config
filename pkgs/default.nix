# Custom packages: bubblewrap sandbox wrappers for the programs that open untrusted content (pkgs/bwrap-app.nix).
# Exposed as the flake's `packages.<system>` and injected into every evaluation as `mypkgs`; the system installs
# them in modules/nixos/hardening/sandbox.nix, which also holds their AppArmor profiles.
{ pkgs, inputs, lib }:
let
  mkBwrapApp = pkgs.callPackage ./bwrap-app.nix { };
  # Read-only from $HOME for every GUI app: GTK settings written by Plasma, cursor and icon themes.
  desktopRo = [
    ".config/gtk-3.0"
    ".config/gtk-4.0"
    ".icons"
    ".local/share/icons"
  ];
in
{
  # Firefox. Profile in ~/.config/mozilla (Home-Manager writes user.js there), cache in ~/.cache/mozilla,
  # downloads and uploads through the Downloads folder only. Enterprise policies come from
  # /etc/firefox/policies (modules/nixos/hardening/sandbox.nix).
  firefox-bwrap = mkBwrapApp {
    pname = "firefox";
    package = pkgs.firefox;
    program = "${pkgs.firefox}/bin/firefox";
    binName = "firefox";
    network = true;
    gpu = true;
    audio = true;
    downloads = true;
    homeDirs = [
      ".config/mozilla"
      ".cache/mozilla"
    ];
    homeDirsRo = desktopRo;
    # A filtered session bus with two names. The desktop portal: links for other apps, such as an app's login
    # callback (io.element.desktop:, tokodon:) or mailto:, leave the sandbox through it (user-overrides.js turns
    # this on). Firefox's own name: a link opened while Firefox runs reaches the running instance instead of
    # stopping at the locked profile.
    dbusTalk = [ "org.freedesktop.portal.Desktop" ];
    dbusOwn = [ "org.mozilla.firefox.*" ];
  };

  # PDF, PostScript, DjVu and comic books: zathura's own sandboxed build (no network, landlock-limited file
  # access, seccomp) inside a bubblewrap sandbox that sees only the opened file. No GPU, no audio, no
  # Downloads, nothing written: viewing history stays in the throwaway home.
  zathura-bwrap = mkBwrapApp {
    pname = "zathura";
    package = pkgs.zathura;
    program = "${pkgs.zathura}/bin/zathura-sandbox";
    binName = "zathura";
    openFiles = true;
    homeDirsRo = desktopRo ++ [ ".config/zathura" ];
  };

  # The Itchy global theme: the base of the operator's desktop look (home/modules/plasma.nix).
  itchy-kde-theme = pkgs.callPackage ./itchy-kde-theme.nix { };

  # macOS-style cursors in the Mac's pointer colours (home/modules/plasma.nix, the login screen).
  cursor-macos-transflag = pkgs.callPackage ./cursor-macos-transflag.nix { };
}
// lib.optionalAttrs pkgs.stdenv.hostPlatform.isx86_64 {
  # Tor Browser (x86_64 only in nixpkgs). Its state lives in "~/.tor project" (the nixpkgs package marks
  # itself as a packaged app); its bundled tor runs inside the same sandbox.
  tor-browser-bwrap = mkBwrapApp {
    pname = "tor-browser";
    package = pkgs.tor-browser;
    program = "${pkgs.tor-browser}/bin/tor-browser";
    binName = "tor-browser";
    network = true;
    gpu = true;
    audio = true;
    downloads = true;
    homeDirs = [
      ".tor project"
      ".cache/tor project"
    ];
    homeDirsRo = desktopRo;
  };
}
