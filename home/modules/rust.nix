# Rust toolchain via oxalica's rust-overlay (nightly, with rust-analyzer matched to the toolchain) and
# the cargo subcommands the operator uses. Ported from macOS; the macOS-keychain credential provider is
# gone (cargo:token only).
{ config, pkgs, ... }:
let
  rustToolchain = pkgs.rust-bin.selectLatestNightlyWith (
    toolchain:
    # `minimal` profile (rustc, cargo, rust-std) + explicit extensions — still the nightly channel; this is the
    # `default` profile (incl. rust-docs for offline documentation, 722 MB — operator choice) plus rust-src,
    # llvm-tools and rust-analyzer.
    toolchain.minimal.override {
      extensions = [
        "rust-src"
        "llvm-tools"
        "rust-analyzer"
        "clippy"
        "rustfmt"
        "rust-docs"
      ];
      targets = [
        "wasm32-unknown-unknown"
        "x86_64-unknown-linux-musl"
      ];
    }
  );
in
{
  home.packages = with pkgs; [
    rustToolchain
    cargo-edit
    cargo-outdated
    cargo-audit
    cargo-machete
    cargo-expand
    cargo-llvm-cov
    cargo-zigbuild
    zig
  ];

  home.file.".cargo/config.toml".text = ''
    [build]
    target-dir = "${config.xdg.cacheHome}/cargo/target"
    [resolver]
    incompatible-rust-versions = "fallback"
    [registry]
    global-credential-providers = ["cargo:token"]
  '';
}
