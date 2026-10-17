# Egress kill-switch (opt-in: my.features.killSwitch = true). When mihomo is down, nothing leaves the
# physical interfaces except what the stack needs to get mihomo back up:
#   - loopback and the TUN device,
#   - mihomo's own sockets (it reaches the proxy servers directly), identified by a STATIC service user —
#     the upstream module uses DynamicUser, which cannot be matched by nftables, so it is overridden,
#   - DHCP / IPv6 neighbour discovery, and the local networks (LAN printers, SSH to local hosts),
#   - established/related replies.
# Captive portals are therefore unreachable while the switch is on: disable it temporarily for those.
# STATUS: evaluated only; not exercised on hardware.
{ config, lib, my, ... }:
let
  enabled = (my.features or { }).killSwitch or false;
  tun = "Meta";
in
lib.mkIf (enabled && config.services.mihomo.enable) {
  users.users.mihomo = {
    isSystemUser = true;
    group = "mihomo";
  };
  users.groups.mihomo = { };
  systemd.services.mihomo.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = "mihomo";
    Group = "mihomo";
  };
  # State moves out of /var/lib/private once the user is static.
  environment.persistence."/persist".directories = [ "/var/lib/mihomo" ];

  networking.nftables.tables.killswitch = {
    family = "inet";
    content = ''
      chain output {
        type filter hook output priority filter; policy drop;
        oifname "lo" accept
        oifname "${tun}" accept
        ct state established,related accept
        meta skuid mihomo accept
        udp sport 68 udp dport 67 accept
        udp dport 547 accept
        icmpv6 type { nd-router-solicit, nd-neighbor-solicit, nd-neighbor-advert, mld-listener-query, mld-listener-report, mld-listener-done } accept
        ip daddr { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 } accept
        ip6 daddr fe80::/10 accept
        log prefix "killswitch drop: " level warn
      }
    '';
  };
}
