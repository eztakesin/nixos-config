# macOS-style cursors in the Mac's own pointer colours: ful1e5's apple_cursor
# (https://github.com/ful1e5/apple_cursor, GPL-3.0), built from its SVG sources with the fill and the outline
# recoloured. The colours are the ones set on the Mac under System Settings, Accessibility, Display, Pointer
# (`defaults read com.apple.universalaccess`, cursorFill and cursorOutline): fill #93E4F3 and outline #FFCCDA,
# the pale blue and pink of the trans flag.
#
# Upstream renders the SVGs with cbmp, which drives a headless Chromium through puppeteer; resvg (Rust, no
# browser) renders the same 256 px bitmaps here, after the two placeholder colours of upstream's render.json
# (#00FF00 fill, #0000FF outline) are replaced. clickgen's ctgen then builds the Xcursor files from upstream's
# own X11 config (configs/x.build.toml: hotspots, sizes, frame delay, names, symlinks); the Windows cursors are
# not built. One addition to upstream: its three hands (hand1, hand2, move: grab, pointer, grabbing) draw a white
# body and a black outline instead of the placeholders, so both upstream variants keep them white; here they
# take the same two colours as the arrow (recolourHands = false keeps upstream's hands). The busy spinners keep
# their rainbow, as on the Mac.
#
# nixpkgs lists its prebuilt apple-cursor as unfree as well as GPL-3.0, "potentially a derivative work of
# copyrighted Apple designs" (pkgs/by-name/ap/apple-cursor/package.nix); that applies to this build too.
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  resvg,
  python3Packages,
  # Named after the Mac's keys; plain `fill`/`outline` would collide with nixpkgs attributes under callPackage
  # (pkgs.outline is a package).
  cursorFill ? "#93E4F3",
  cursorOutline ? "#FFCCDA",
  cursorThemeName ? "macOS-TransFlag",
  recolourHands ? true,
}:
let
  # Only in these three files are "white" and "black" the body and the outline; elsewhere the named colours
  # sit in masks and filters, which must stay as they are.
  recolourHand = lib.optionalString recolourHands ''
    case "$name" in
      hand1 | hand2 | move)
        sed -i -e 's/fill="white"/fill="${cursorFill}"/g' -e 's/stroke="black"/stroke="${cursorOutline}"/g' \
          "$name.recoloured.svg"
        ;;
    esac
  '';
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "cursor-macos-transflag";
  version = "2.0.1";

  src = fetchFromGitHub {
    owner = "ful1e5";
    repo = "apple_cursor";
    tag = "v${finalAttrs.version}";
    hash = "sha256-gWdumtTFeTOu//APtaf255v9Hx61H1KtCfWZ39wPkFo=";
  };

  nativeBuildInputs = [
    resvg
    python3Packages.clickgen
  ];

  buildPhase = ''
    runHook preBuild

    # svg/*.svg are the static cursors, svg/wait/ and svg/left_ptr_watch/ the 40 frames of the two animated
    # ones; ctgen expects all of them flat in one directory (the config globs wait-*.png).
    mkdir -p bitmaps
    for svg in svg/*.svg svg/*/*.svg; do
      name=$(basename "$svg" .svg)
      sed -e 's/#00FF00/${cursorFill}/gI' -e 's/#0000FF/${cursorOutline}/gI' "$svg" > "$name.recoloured.svg"
      ${recolourHand}
      resvg --width 256 --height 256 "$name.recoloured.svg" "bitmaps/$name.png"
    done

    ctgen configs/x.build.toml \
      --platforms x11 \
      --bitmaps-dir "$PWD/bitmaps" \
      --out-dir "$PWD/themes" \
      --theme-name ${lib.escapeShellArg cursorThemeName} \
      --theme-comment ${lib.escapeShellArg "macOS cursors, fill ${cursorFill}, outline ${cursorOutline} (apple_cursor v${finalAttrs.version})"}

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/icons
    cp -r themes/${lib.escapeShellArg cursorThemeName} $out/share/icons/
    runHook postInstall
  '';

  meta = {
    description = "macOS-style cursors (apple_cursor) in the trans flag colours of the Mac's pointer settings";
    homepage = "https://github.com/ful1e5/apple_cursor";
    license = [
      lib.licenses.gpl3Only
      # Potentially a derivative work of copyrighted Apple designs (nixpkgs' apple-cursor says the same)
      lib.licenses.unfree
    ];
    platforms = lib.platforms.linux;
  };
})
