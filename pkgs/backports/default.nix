# Temporary backports from nixpkgs master (see the header of each package.nix). Each attribute falls back to
# the pinned nixpkgs as soon as that ships the same or a newer fcitx5-mozc, so the overlay can be left in place
# until it is deleted. The condition sits inside the attributes: an overlay whose attribute *names* depend on
# `prev` would recurse infinitely.
final: prev:
let
  stale = prev.lib.versionOlder prev.fcitx5-mozc.version "3.35";
in
{
  merge-ut-dictionaries = if stale then final.callPackage ./merge-ut-dictionaries/package.nix { } else prev.merge-ut-dictionaries;
  mozc = if stale then final.callPackage ./mozc/package.nix { } else prev.mozc;
  fcitx5-mozc = if stale then final.callPackage ./fcitx5-mozc/package.nix { } else prev.fcitx5-mozc;
  # cargo-llvm-cov 0.9.0 is not in the binary cache on this nixpkgs: its test suite fails in the sandbox
  # (`cargo test` of the fixtures), so the package is built here with the tests skipped. Guarded by the
  # version so the override stops applying once nixpkgs ships a newer, cached build.
  cargo-llvm-cov =
    if prev.cargo-llvm-cov.version == "0.9.0" then prev.cargo-llvm-cov.overrideAttrs (_: { doCheck = false; }) else prev.cargo-llvm-cov;
}
