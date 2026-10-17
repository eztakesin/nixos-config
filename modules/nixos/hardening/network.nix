# Network layer: NetworkManager on the iwd backend, MAC/IPv6 address privacy, nftables firewall
# (default-deny inbound), systemd-resolved, and mihomo (TUN) as the primary egress.
# mihomo/firewall interplay verified against
# nixpkgs 55bfb4d (services.mihomo) and sing-tun v0.4.27.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  mihomoSecret = ../../../secrets/mihomo.yaml;
  haveMihomo = builtins.pathExists mihomoSecret; # the module is inert until the encrypted config exists
  tunDevice = "Meta"; # must match `tun.device` in the mihomo config
in
{
  # ── Wi-Fi / Ethernet ──────────────────────────────────────────────────────────
  networking.networkmanager = {
    enable = true;
    wifi.backend = "iwd";
    # Under the iwd backend NetworkManager's own Wi-Fi MAC randomisation is inactive; it is configured in
    # iwd below. Ethernet is still NM's job.
    ethernet.macAddress = "random";
    dns = "systemd-resolved";
    # Do not announce our hostname to DHCP servers.
    settings.connection = {
      "ipv4.dhcp-send-hostname" = false;
      "ipv6.dhcp-send-hostname" = false;
    };
  };
  networking.wireless.iwd = {
    enable = true;
    settings = {
      General = {
        # Per-network stable random MAC: a different address on every SSID, stable within one, so DHCP
        # leases and captive portals keep working. ("once" = random per boot.)
        AddressRandomization = "network";
        AddressRandomizationRange = "full";
      };
      Scan.DisablePeriodicScan = false;
    };
  };
  # Prefer rotating temporary IPv6 addresses for outbound traffic (no EUI-64 derived from the MAC).
  networking.tempAddresses = "enabled";

  # ── DNS ──────────────────────────────────────────────────────────────────────
  # systemd-resolved talks plain DNS to Quad9 for *all* domains (DHCP-pushed resolvers are not used).
  # With mihomo up, every port-53 query is redirected into mihomo's DNS (fake-ip) by the TUN dns-hijack,
  # which is what makes domain-based routing work — so DNS-over-TLS must stay OFF here (DoT on 853 would
  # bypass the hijack). With mihomo down, this is plain DNS straight to Quad9.
  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNS = [
        "9.9.9.9"
        "149.112.112.112"
        "2620:fe::fe"
      ];
      Domains = [ "~." ];
      DNSOverTLS = false;
      DNSSEC = false;
      MulticastDNS = false; # no local-name chatter
      LLMNR = false;
    };
  };

  # ── Firewall ─────────────────────────────────────────────────────────────────
  networking.nftables.enable = true;
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ ]; # nothing listens for the LAN; mihomo's local ports stay loopback-only
    allowedUDPPorts = [ ];
    logRefusedConnections = true;
    # mihomo docs: with the firewall on, the `system`/`mixed` TUN stacks need the TUN device trusted.
    trustedInterfaces = lib.optional haveMihomo tunDevice;
    # Reverse-path filtering vs. TUN auto-route: keep "loose" (the current default) and exempt the TUN.
    checkReversePath = "loose";
    extraReversePathFilterRules = lib.optionalString haveMihomo ''iifname "${tunDevice}" accept'';
  };
  # Kill-switch: hardening/killswitch.nix (opt-in, my.features.killSwitch) adds an nftables output chain
  # that drops everything except loopback, the LAN, the TUN and mihomo's own sockets, so nothing leaves the
  # physical interface while mihomo is down.

  # ── mihomo (primary egress) ──────────────────────────────────────────────────
  # Config = sops secret (it holds node credentials). `configFile` takes the absolute /run/secrets path as
  # a string, so it is NOT copied into the world-readable store. TUN mode grants CAP_NET_ADMIN and exposes
  # /dev/net/tun; the service stays DynamicUser + sandboxed, with state in /var/lib/private/mihomo
  # (persisted). The dashboard is served locally via -ext-ui.
  sops.secrets."mihomo.yaml" = lib.mkIf haveMihomo {
    sopsFile = mihomoSecret;
    format = "yaml";
    key = ""; # whole file
    restartUnits = [ "mihomo.service" ];
  };
  services.mihomo = lib.mkIf haveMihomo {
    enable = true;
    tunMode = true;
    configFile = config.sops.secrets."mihomo.yaml".path;
    webui = pkgs.metacubexd;
  };
}
