# sops-nix wiring. Secrets are committed as sops ciphertext under secrets/ and decrypted at activation
# into /run/secrets (tmpfs, root:root 0400 by default). Plaintext never enters the Nix store.
#
# Under systemd stage-1 the activation script (including sops' setupSecrets) runs inside the initrd, so
# the host's age key has to live on a filesystem that is mounted there → /persist (sops-nix README).
# Key lifecycle: https://nixos.ssf.network/runbook/secrets/ (generate on the workstation, add the public key to .sops.yaml).
{ ... }:
{
  sops = {
    age.keyFile = "/persist/var/lib/sops-nix/key.txt";
    age.generateKey = false; # generated deliberately, not on first boot (its public key must be a recipient)
    age.sshKeyPaths = [ ];
    gnupg.sshKeyPaths = [ ];
  };
}
