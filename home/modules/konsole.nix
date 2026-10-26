# Konsole, KDE's terminal, in kitty's palette and font (../terminal-colors.nix, modules/kitty.nix), running fish;
# zellij starts from fish in the graphical session as in kitty (modules/cli.nix). plasma-manager writes the profile
# and the colour scheme into ~/.local/share/konsole (its konsole module).
{ config, lib, ... }:
let
  palette = import ../terminal-colors.nix;
  kitty = config.programs.kitty;
  # "#RRGGBB" -> "R,G,B", Konsole's colour format.
  rgb =
    hex:
    let
      byte = i: toString (lib.fromHexString (builtins.substring i 2 (lib.removePrefix "#" hex)));
    in
    "${byte 0},${byte 2},${byte 4}";
  color = i: { Color = rgb (builtins.elemAt palette.colors i); };
in
{
  programs.konsole = {
    enable = true;
    defaultProfile = "Kitty";

    # Colour n with its bright form (kitty's color8–15) as Konsole's "Intense"; "Faint" keeps the normal colour.
    customColorSchemes.Kitty = {
      General = {
        Description = "Kitty (the macOS palette)";
        Opacity = 1;
      };
      Foreground.Color = rgb palette.foreground;
      ForegroundIntense.Color = rgb palette.foreground;
      ForegroundFaint.Color = rgb palette.foreground;
      Background.Color = rgb palette.background;
      BackgroundIntense.Color = rgb palette.background;
      BackgroundFaint.Color = rgb palette.background;
    }
    // lib.listToAttrs (
      lib.concatMap (i: [
        (lib.nameValuePair "Color${toString i}" (color i))
        (lib.nameValuePair "Color${toString i}Faint" (color i))
        (lib.nameValuePair "Color${toString i}Intense" (color (i + 8)))
      ]) (lib.range 0 7)
    );

    profiles.Kitty = {
      colorScheme = "Kitty";
      command = lib.getExe config.programs.fish.package;
      font = {
        inherit (kitty.font) name size;
      };
      extraConfig = {
        "Cursor Options" = {
          UseCustomCursorColor = true;
          CustomCursorColor = rgb palette.cursor;
        };
        Scrolling = {
          HistoryMode = 1; # a fixed number of lines, as kitty's scrollback
          HistorySize = kitty.settings.scrollback_lines;
        };
      };
    };
  };
}
