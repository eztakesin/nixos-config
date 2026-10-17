# GnuPG + YubiKey — ported from the operator's macOS config (drduh/YubiKey-Guide hardened defaults).
# Linux changes: gpg-agent is a proper Home-Manager service (sets GPG_TTY / SSH_AUTH_SOCK for fish),
# pinentry is the Qt one for Plasma, and the card is reached through pcscd (system module yubikey.nix)
# so ykman / age-plugin-yubikey can share it.
{
  lib,
  pkgs,
  my,
  ...
}:
{
  programs.gpg = {
    enable = true;
    settings = {
      default-key = lib.mkIf (my.user.gpgFingerprint != "") my.user.gpgFingerprint;

      personal-cipher-preferences = "AES256 AES192 AES";
      personal-digest-preferences = "SHA512 SHA384 SHA256";
      personal-compress-preferences = "ZLIB BZIP2 ZIP Uncompressed";
      default-preference-list = "SHA512 SHA384 SHA256 AES256 AES192 AES ZLIB BZIP2 ZIP Uncompressed";
      cert-digest-algo = "SHA512";
      s2k-digest-algo = "SHA512";
      s2k-cipher-algo = "AES256";

      charset = "utf-8";
      no-comments = true;
      no-emit-version = true;
      no-greeting = true;
      keyid-format = "0xlong";
      list-options = "show-uid-validity";
      verify-options = "show-uid-validity";
      with-fingerprint = true;
      armor = true;

      require-cross-certification = true;
      no-symkey-cache = true;
      use-agent = true;
      require-secmem = true; # mlock works on Linux (omitted on macOS for that reason)

      keyserver = "hkps://keys.openpgp.org";
    };
    scdaemonSettings = {
      disable-ccid = true; # go through pcscd (shared with ykman / age-plugin-yubikey)
    };
  };

  services.gpg-agent = {
    enable = true;
    enableSshSupport = true; # YubiKey authentication subkey as the SSH key
    enableFishIntegration = true;
    pinentry.package = pkgs.pinentry-qt;
    defaultCacheTtl = 600;
    maxCacheTtl = 1800;
    defaultCacheTtlSsh = 600;
    maxCacheTtlSsh = 1800;
  };

  # fish ports of drduh's helpers
  programs.fish.functions = lib.mkIf (my.user.gpgFingerprint != "") {
    secret = {
      description = "Encrypt a file for yourself with gpg, write <file>.<ts>.enc";
      body = ''
        if test (count $argv) -lt 1
            echo "usage: secret <file>" >&2
            return 1
        end
        set -l in $argv[1]
        if not test -f "$in"
            echo "secret: '$in' is not a regular file" >&2
            return 1
        end
        set -l out "$in".(date +%s).enc
        gpg --encrypt --armor --output $out -r ${my.user.gpgFingerprint} -- $in
        and echo "$in -> $out"
      '';
    };
    reveal = {
      description = "Decrypt a <file>.<ts>.enc produced by `secret`";
      body = ''
        if test (count $argv) -lt 1
            echo "usage: reveal <file.<ts>.enc>" >&2
            return 1
        end
        set -l in $argv[1]
        set -l out (string replace -r '\.\d+\.enc$' "" -- $in)
        if test "$in" = "$out"
            echo "reveal: '$in' does not look like a secret-encoded file" >&2
            return 1
        end
        gpg --decrypt --output $out -- $in
        and echo "$in -> $out"
      '';
    };
    yk-swap = {
      description = "After physically swapping YubiKeys, force gpg to re-detect";
      body = ''
        gpgconf --kill scdaemon
        gpg --card-status
      '';
    };
  };
}
