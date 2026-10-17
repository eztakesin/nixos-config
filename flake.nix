{
  description = "Hardened, privacy-first NixOS — FDE (LUKS2 + detached header on USB) + YubiKey FIDO2 + Secure Boot (lanzaboote) + impermanence. Host: cobalt (Acer A315-24P). Docs: https://nixos.ssf.network";

  inputs = {
    # Userspace + kernel channel: unstable, because req #17 wants the latest (security fixes land first)
    # and the kernel must be recent.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative disk layout (partitions + LUKS2 + LVM + btrfs subvols). Single source of truth
    # the one-click installer consumes. https://github.com/nix-community/disko
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Ephemeral root ("erase your darlings") for data-minimization; auditable, unlike a hand-rolled
    # /var. https://github.com/nix-community/impermanence  https://grahamc.com/blog/erase-your-darlings/
    impermanence.url = "github:nix-community/impermanence";

    # Secure Boot via signed UKIs. Pinned to a RELEASED tag (not a floating branch) per research.
    # v1.2.0 (2026-09-26). https://github.com/nix-community/lanzaboote
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.2.0";
      # NOT following our nixpkgs. lanzaboote CI pushes lzbt + the UEFI stub to the nix-community cache for
      # the nixpkgs in ITS flake.lock; matching that exactly makes them cache hits — which matters because
      # the stub cannot be built on the emulated builder on the Mac (rustc SIGSEGV in qemu-user). A plain
      # un-follow re-locks the branch head, so the rev is pinned explicitly. When bumping lanzaboote, copy
      # the nixpkgs rev from its flake.lock: nix flake metadata --json github:nix-community/lanzaboote/<tag>
      inputs.nixpkgs.url = "github:NixOS/nixpkgs/20b1ddd1aa5ace70c9468305030aa4f9ef79671b";
    };

    # Secrets at rest. YubiKey-PIV age + offline paper recovery. https://github.com/Mic92/sops-nix
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Generic AMD-laptop tuning. No module exists for the A315-24P, so we compose common-* modules.
    # https://github.com/NixOS/nixos-hardware
    nixos-hardware = {
    url = "github:NixOS/nixos-hardware";
    inputs.nixpkgs.follows = "nixpkgs";
  };

    # oxalica's Rust overlay (nightly toolchains; matches your existing kit). #17 Rust-first.
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative Flatpak (remotes, packages, overrides) for the portal-confined apps.
    # https://github.com/gmodena/nix-flatpak
    nix-flatpak.url = "github:gmodena/nix-flatpak";

    # NOTE: oxalica's "optional private flake" trick (a local-path `secrets` input layering
    # host hardware IDs and other personal specifics, guarded by `inputs ? secrets`) can be added later so the
    # public config stays buildable and auditable without leaking specifics. Not wired yet.
  };

  outputs =
    inputs@{ self, nixpkgs, ... }:
    let
      inherit (nixpkgs) lib;

      # Project-global data (identity, keys, hostnames) injected into every eval via specialArgs.
      # Adopted from oxalica: a plain data attrset, decoupled from the module graph. See my/default.nix.
      my = import ./my;

      # The configuration tree the installer ships (/etc/cobalt/config, installer/default.nix) and that
      # scripts/install.sh re-evaluates on the target. A `path:.` reference copies the WHOLE working
      # directory into the store — .git, the local documentation sources under docs/ (with the docs site's
      # node_modules), the old configuration kept for reference: 605 MB at one point, paid for three times
      # (the image, the live system's RAM, the target's /persist). lib.fileset keeps the flake, its modules
      # and the gitignored private data (my/private.nix, which is why the build uses `path:`), nothing else.
      # https://nixos.org/manual/nixpkgs/unstable/#sec-functions-library-fileset
      cobaltSource = lib.fileset.toSource {
        root = ./.;
        fileset = lib.fileset.difference ./. (
          lib.fileset.unions (
            map lib.fileset.maybeMissing [
              ./.git
              ./.direnv
              ./.claude
              ./.cursor
              ./docs
              ./nixos-config
              ./vm
              ./result
            ]
          )
        );
      };

      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = lib.genAttrs systems;

      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          overlays = [ inputs.rust-overlay.overlays.default ];
          # TODO: narrow to an explicit allowlist predicate for supply-chain hygiene.
          config.allowUnfree = true;
        };

      # Host factory. specialArgs carries the pinned inputs, the `my` data namespace, and custom pkgs.
      mkSystem =
        {
          hostName,
          system ? "x86_64-linux",
          extraModules ? [ ],
        }:
        lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs my;
            mypkgs = self.packages.${system};
          };
          modules = [
            inputs.disko.nixosModules.disko
            inputs.impermanence.nixosModules.impermanence
            inputs.lanzaboote.nixosModules.lanzaboote
            inputs.sops-nix.nixosModules.sops
            inputs.home-manager.nixosModules.home-manager
            {
              nixpkgs.overlays = [ inputs.rust-overlay.overlays.default ];
              nixpkgs.config.allowUnfree = true; # TODO: narrow to an allowlist predicate
            }
            { networking.hostName = lib.mkDefault hostName; }
            ./hosts/${hostName}
          ] ++ extraModules;
        };
    in
    {
      nixosConfigurations = {
        cobalt = mkSystem { hostName = "cobalt"; };

        # Offline-capable live installer carrying the full cobalt closure. Not built via mkSystem: a live
        # image must not import the hardened host modules (see installer/default.nix).
        installer = lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs my self cobaltSource; };
          modules = [ ./installer ];
        };
      };

      # nix build .#images.installer  →  result/iso/cobalt-installer.iso
      images.installer = self.nixosConfigurations.installer.config.system.build.isoImage;
      # nix build .#images.installer-uki  →  result/cobalt-installer.efi — the installer's Unified Kernel
      # Image (unsigned; scripts/install.sh signs it with sbctl onto the key's ESP). Also shipped inside the
      # ISO at /boot/cobalt-installer.efi (installer/default.nix).
      images.installer-uki = self.nixosConfigurations.installer.config.system.build.uki;

      # Custom packages + per-app bubblewrap sandbox wrappers. Exposed here and injected as `mypkgs`.
      packages = forAllSystems (
        system:
        import ./pkgs {
          pkgs = pkgsFor system;
          inherit inputs lib;
        }
      );

      # Tooling for working on this repo (secrets, disk, formatting, dead-code lints).
      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              nvfetcher
              sops
              age
              ssh-to-age
              disko
              sbctl
              nixpkgs-fmt
              deadnix
              statix
            ];
          };
        }
      );

      formatter = forAllSystems (system: (pkgsFor system).nixpkgs-fmt);

      # TODO(next increment): expose the custom installer image, e.g.
      #   images.installer = self.nixosConfigurations.installer.config.system.build.images.iso;
    };
}
