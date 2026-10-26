# Aggregator for the host-independent, hardened NixOS module set. Each module is small, heavily commented,
# and cites its sources inline.
{ ... }:
{
  imports = [
    ./nix-settings.nix
    ./boot-crypto.nix # lanzaboote + systemd stage-1 + FIDO2 surroundings (LUKS device comes from disko)
    ./impermanence.nix # btrfs root rollback + /persist allowlist
    ./secrets.nix # sops-nix
    ./hardening/kernel.nix # stock testing kernel now; hardened self-build defined + runtime hardening
    ./hardening/network.nix # NM+iwd, MAC/IPv6 privacy, resolved, nftables, mihomo (inert until the secret exists)
    ./hardening/permissions.nix # sudo-rs, umask, fs.protected_*, no sshd, no default packages
    ./hardening/peripherals.nix # USBGuard, Bluetooth kept+tightened, IOMMU, unused modules, fwupd
    ./hardening/sandbox.nix # AppArmor, Flatpak + portals, bubblewrap
    ./hardening/services.nix # systemd sandboxing for services with weak upstream units
    ./hardening/killswitch.nix # opt-in (my.features.killSwitch): egress drop when mihomo is down
    ./users.nix # operator + secondary account, sops password hashes
    ./homed.nix # opt-in (my.features.homed): the operator's home as a systemd-homed LUKS image
    ./desktop-kde.nix # Plasma 6 Wayland, SDDM, PipeWire (+ BT codecs)
    ./locale-fonts.nix # locales, CJK fonts, fcitx5
    ./base-packages.nix # uutils ahead of GNU coreutils, base tools
    ./yubikey.nix # pcscd, ykman, age-plugin-yubikey
    ./key-stick.nix # sync-key-stick: a spare key stick from the one in use
    ./home.nix # Home-Manager wiring for the operator
    ./messaging.nix # Signal + Element as confined Flatpaks (nix-flatpak)
    ./tor.nix # app-level Tor + Tor Browser
    ./wallet-browser.nix # opt-in (my.features.walletBrowser): Chrome (dev channel) for a browser wallet only
    # supply-chain settings (signatures, trusted users, substituters) live in nix-settings.nix
  ];
}
