# Firefox with a pinned arkenfox user.js + local overrides, declaratively (no updater.sh round trip).
# Same build-time concatenation the operator used on macOS; on NixOS the profile is Home-Manager owned,
# so the result is written straight into it (no bridge symlink). user.js is a derivation output used as
# a file source — not read at evaluation time — so this stays compatible with
# `allow-import-from-derivation = false` (nix-settings.nix).
#
# Bump arkenfox: change the tag, then
#   nix store prefetch-file https://raw.githubusercontent.com/arkenfox/user.js/<tag>/user.js
{ config, pkgs, ... }:
let
  arkenfox = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/arkenfox/user.js/144.0/user.js";
    hash = "sha256-5KszxpFImRdc9wNeDlei1/CKyIfY+VfxGZ5+Sbvn4z4=";
  };
  userJs = pkgs.concatTextFile {
    name = "firefox-user.js";
    files = [
      arkenfox
      ../dotfiles/firefox/user-overrides.js
    ];
  };
in
{
  programs.firefox = {
    enable = true;
    # Firefox itself is installed system-wide inside its bubblewrap sandbox, together with its enterprise
    # policies (modules/nixos/hardening/sandbox.nix); Home-Manager only manages the profile.
    package = null;
    configPath = ".config/mozilla/firefox"; # XDG location (HM default changed; pinned explicitly)

    profiles.default = {
      isDefault = true;
      userChrome = builtins.readFile ../dotfiles/firefox/userChrome.css;
      # (settings/extraConfig intentionally empty — user.js comes from the file below)
    };
  };

  home.file."${config.programs.firefox.configPath}/default/user.js".source = userJs;
}
