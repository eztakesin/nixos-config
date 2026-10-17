# ssh client — ported from the operator's macOS config. Defaults made explicit (enableDefaultConfig is
# deprecated); FIDO2 key (id_ed25519_sk, YubiKey touch per connection) for GitHub.
# Host aliases and addresses stay OUT of the repo in ~/.ssh/config.d/hosts (it is Include'd here).
{ pkgs, ... }:
{
  programs.ssh = {
    enable = true;
    package = pkgs.openssh;
    enableDefaultConfig = false;
    includes = [ "~/.ssh/config.d/hosts" ];

    settings = {
      "*" = {
        ForwardAgent = false;
        AddKeysToAgent = "no";
        Compression = false;
        ServerAliveInterval = 0;
        ServerAliveCountMax = 3;
        HashKnownHosts = true; # changed from false: known_hosts no longer lists where you have been
        UserKnownHostsFile = "~/.ssh/known_hosts";
        ControlMaster = "no";
        ControlPath = "~/.ssh/master-%r@%n:%p";
        ControlPersist = "no";
      };

      "github.com" = {
        User = "git";
        IdentityFile = "~/.ssh/id_ed25519_sk";
        IdentitiesOnly = true;
        ServerAliveInterval = 4;
        ServerAliveCountMax = 30;
      };
    };
  };
}
