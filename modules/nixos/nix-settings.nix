# Nix daemon policy: reproducibility, offline capability, supply-chain discipline,
# and the self-hosted binary cache that serves our custom hardened kernel.
# Patterns adopted from oxalica's nix-common.nix / nix-registry.nix / nix-keep-flake-inputs.nix.
{ inputs, lib, my, ... }:
{
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
      "auto-allocate-uids" # stronger build isolation (unique uid per build)
      "cgroups" # confine builds in their own cgroup
    ];
    auto-allocate-uids = true;
    use-cgroups = true;

    # ── Supply chain ────────────────────────────────────────────────
    # Keep signature verification ON. trusted-users beyond root is ROOT-EQUIVALENT (it can push
    # unsigned paths into your store), so it stays [root] — do NOT add @wheel here.
    require-sigs = true;
    trusted-users = [ "root" ];
    allow-import-from-derivation = false; # purity: no IFD

    # Substituters: cache.nixos.org + (optionally) your self-hosted attic/harmonia cache serving the
    # custom hardened kernel. Each cache MUST carry its own vetted public key. No China mirrors (user is
    # on VPN/mihomo). For a *fully offline* install use `substituters` (not extra-), so a missing default
    # doesn't stall — see installer notes.
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org" # lanzaboote: prebuilt lzbt + stub for its locked nixpkgs
    ] ++ lib.optional (my.cache.url != "") my.cache.url;
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ] ++ lib.optional (my.cache.publicKey != "") my.cache.publicKey;

    # Let a remote x86_64 builder pull deps from its own substituters instead of copying from the Mac.
    builders-use-substitutes = true;

    # Flaky-link tuning (you roam / route through mihomo; fail fast instead of hanging).
    connect-timeout = 10;
    download-attempts = 3;
    stalled-download-timeout = 10;
  };

  # Flakes-only: no imperative channels, and disable the ONLINE global flake registry for
  # reproducibility + to avoid leaking lookups (offline/privacy). Pin `nixpkgs#` to our input instead.
  nix.channel.enable = false;
  nix.settings.flake-registry = "";
  nix.registry.nixpkgs.flake = inputs.nixpkgs;
  nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];

  # Keep every flake input (recursively) pinned in the store so GC can't collect them and offline
  # eval/rebuild works without a network — oxalica's nix-keep-flake-inputs trick (serves #8).
  system.extraDependencies =
    let
      collect = input: [ input ] ++ builtins.concatMap collect (builtins.attrValues (input.inputs or { }));
    in
    builtins.concatMap collect (builtins.attrValues (builtins.removeAttrs inputs [ "self" ]));

  # GC + store optimise. Aggressive-ish GC also shrinks the /nix/store "software history" an examiner
  # could read (data-minimization, D13 — though impermanence does the heavy lifting). Prefer scheduled
  # `nix store optimise` over auto-optimise-store (the latter has had store-corruption edge cases).
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  nix.optimise.automatic = true;

  # Build nicely in the background (don't starve an interactive session on this low-power 7320U).
  nix.daemonCPUSchedPolicy = "idle";
  nix.daemonIOSchedClass = "idle";
}
