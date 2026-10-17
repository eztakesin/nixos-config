# Custom packages + per-app bubblewrap sandbox wrappers.
# Exposed as the flake's `packages.<system>` and injected into every eval as `mypkgs`.
#
# TODO(next increment):
#   - Auto-discovery scope (readDir + newScope + nvfetcher `source` auto-binding), as in oxalica's pkgs/.
#   - bubblewrap GUI wrappers for browser / Signal / Element, modelled on
#     oxalica's prismlauncher-bwrap.nix (--unshare-all, RO /nix /etc, selective Wayland socket, D-Bus block).
#   - arkenfox user.js builder (concatText of pinned arkenfox + user-overrides.js), from your macOS config.
{ pkgs, inputs, lib }:
{
  # (empty until the first custom package lands)
}
