# Project-global data injected into every NixOS + Home-Manager evaluation via specialArgs
# (the "my" pattern from oxalica: plain data, no module system).
#
# This file is PUBLIC. It holds only non-identifying placeholders. Real values (operator identity,
# secondary account, cache keys) live in `my/private.nix`, which is gitignored and shallow-merged over
# these defaults at eval time. Keep real data out of the public repo.
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
    # Self-hosted binary cache (attic/harmonia). Empty = cache.nixos.org only.
    cache = {
      url = "";
      publicKey = "";
    };
    # Catppuccin flavour and accent for the desktop, the login screen and the fcitx5 candidate window
    # (modules/nixos/desktop-kde.nix, modules/nixos/locale-fonts.nix, home/modules/plasma.nix).
    # Flavours: latte (light), frappe, macchiato, mocha (dark); accents: https://catppuccin.com/palette
    look = {
      flavor = "latte";
      accent = "blue";
    };
    # Opt-in features (https://nixos.ssf.network/reference/packages/): zoom, java, julia, foundry, azure, android, killSwitch.
    features = { };
  };
  private = if builtins.pathExists ./private.nix then import ./private.nix else { };
in
public // private
