# Tor: application-level only — Tor Browser for browsing, and a local client
# daemon (SOCKS on 9050) + torsocks for individual command-line tools. No system-wide transparent
# routing: it breaks applications and gives false confidence.
#
# Interaction with mihomo: with the TUN active, Tor's own connections to guard relays leave through the
# proxy like everything else (the guard sees the proxy exit, the proxy exit sees a Tor handshake). To send
# Tor directly instead, add `PROCESS-NAME,tor,DIRECT` to the mihomo rules.
{ pkgs, ... }:
{
  services.tor = {
    enable = true;
    client.enable = true;
    torsocks.enable = true;
    settings = {
      ClientUseIPv6 = true;
    };
  };

  environment.systemPackages = [ pkgs.tor-browser ];
}
