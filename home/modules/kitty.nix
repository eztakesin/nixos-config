# kitty — palette and settings ported verbatim from the operator's macOS config; macOS-only keys dropped.
# Font size reduced from 18 (Retina) to 13 for the 15.6" 1080p panel — adjust to taste. The palette lives in
# ../terminal-colors.nix, shared with Konsole.
{ lib, ... }:
let
  palette = import ../terminal-colors.nix;
  colors = lib.listToAttrs (lib.imap0 (i: c: lib.nameValuePair "color${toString i}" c) palette.colors);
in
{
  programs.kitty = {
    enable = true;

    font = {
      name = "FiraCode Nerd Font";
      size = 13;
    };

    settings = colors // {
      cursor = palette.cursor;
      scrollback_lines = 10000;
      enable_audio_bell = "no";
      confirm_os_window_close = 0;

      inherit (palette) foreground background;
      background_opacity = "1";
      selection_foreground = palette.selectionForeground;
      selection_background = palette.selectionBackground;

      shell_integration = "no-sudo";
      clipboard_control = "write-clipboard read-clipboard";
    };

    # Nerd Font symbol maps — https://github.com/ryanoasis/nerd-fonts/wiki/Glyph-Sets-and-Code-Points
    extraConfig = ''
      symbol_map U+E5FA-U+E6B5 Symbols Nerd Font Mono
      symbol_map U+e700-U+e7c5 Symbols Nerd Font Mono
      symbol_map U+ed00-U+f2ff Symbols Nerd Font Mono
      symbol_map U+e200-U+e2a9 Symbols Nerd Font Mono
      symbol_map U+f0001-U+f1af0 Symbols Nerd Font Mono
      symbol_map U+e300-U+e3e3 Symbols Nerd Font Mono
      symbol_map U+f400-U+f533 Symbols Nerd Font Mono
      symbol_map U+2665 Symbols Nerd Font Mono
      symbol_map U+26A1 Symbols Nerd Font Mono
      symbol_map U+e0a0-U+e0a2 Symbols Nerd Font Mono
      symbol_map U+e0b0-U+e0b3 Symbols Nerd Font Mono
      symbol_map U+e0b4-U+e0c8 Symbols Nerd Font Mono
      symbol_map U+e0cc-U+e0d7 Symbols Nerd Font Mono
      symbol_map U+e0a3 Symbols Nerd Font Mono
      symbol_map U+e0ca Symbols Nerd Font Mono
      symbol_map U+23fb-U+23fe Symbols Nerd Font Mono
      symbol_map U+2b58 Symbols Nerd Font Mono
      symbol_map U+f300-U+f375 Symbols Nerd Font Mono
      symbol_map U+e000-U+e00a Symbols Nerd Font Mono
      symbol_map U+ea60-U+ec1e Symbols Nerd Font Mono
      symbol_map U+276c-U+2771 Symbols Nerd Font Mono
      symbol_map U+2500-U+259f Symbols Nerd Font Mono
    '';
  };
}
