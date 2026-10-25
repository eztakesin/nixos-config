# Itchy, a light Plasma 6 global theme on the Catppuccin Latte palette, by jomada:
# https://gitlab.com/jomada/Itchy (also on the KDE Store, https://store.kde.org/p/1898336). Installed as the
# KDE Store would place its parts: the global theme (look-and-feel), the Plasma style (desktoptheme), the
# colour scheme, the Aurorae window decoration, two wallpapers and a Konsole colour scheme. Nothing is run:
# the global theme's own panel layout script is only used by `plasma-apply-lookandfeel --resetLayout`, which
# plasma-manager does not call, so the panels stay those of home/modules/plasma.nix.
{
  lib,
  stdenvNoCC,
  fetchFromGitLab,
}:
stdenvNoCC.mkDerivation {
  pname = "itchy-kde-theme";
  version = "0-unstable-2025-11-29";

  src = fetchFromGitLab {
    owner = "jomada";
    repo = "Itchy";
    rev = "1c712e69c982913413d6b6772e9922bdda413e87"; # "add wallpaper", the latest commit
    hash = "sha256-jABn43nnc0JcROzhAJExcRbjfk2SkiHVn9T0DNMcvzc=";
  };

  dontBuild = true;
  installPhase = ''
    runHook preInstall
    share=$out/share
    install -d $share/aurorae/themes $share/color-schemes $share/konsole $share/plasma/look-and-feel \
      $share/plasma/desktoptheme $share/wallpapers
    cp -r aurorae/Itchy $share/aurorae/themes/
    cp color-schemes/Itchy.colors $share/color-schemes/
    cp konsole/Itchy.colorscheme $share/konsole/
    cp -r look-and-feel/Itchy $share/plasma/look-and-feel/
    cp -r plasma/Itchy $share/plasma/desktoptheme/
    cp -r wallpaper/Itchy wallpaper/Itchy-V2 $share/wallpapers/
    runHook postInstall
  '';

  meta = {
    description = "Itchy, a light KDE Plasma 6 global theme on the Catppuccin Latte palette";
    homepage = "https://gitlab.com/jomada/Itchy";
    # The repository's LICENSE is MIT; the parts' own metadata name GPL-3.0+ (global theme, decoration),
    # LGPL (Plasma style) and CC-BY-SA-4.0 (wallpaper).
    license = with lib.licenses; [
      mit
      gpl3Plus
      lgpl3Plus
      cc-by-sa-40
    ];
    platforms = lib.platforms.linux;
  };
}
