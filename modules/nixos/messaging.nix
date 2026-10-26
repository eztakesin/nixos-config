# Messengers and a Fediverse client, installed declaratively as Flatpaks (nix-flatpak) so they run confined with
# portal-mediated access (hardening/sandbox.nix) instead of as unconfined Nix packages:
#   - Signal (primary): end-to-end encrypted by default.
#   - Element (Matrix): end-to-end encrypted rooms.
#   - Telegram: ordinary chats are "cloud chats", encrypted only between the app and Telegram's servers,
#     which can read them; the end-to-end "secret chats" exist only in the mobile and macOS apps, not in
#     Telegram Desktop. Use it for what may be read server-side. https://telegram.org/faq#secret-chats
#   - Tokodon: KDE's client for Mastodon and compatible servers (the Fediverse). Bluesky has no Linux app; its
#     web app runs in the sandboxed Firefox.
#
# Files: none of them can read the home folder (overrides below). A file reaches an app only through the file
# dialog, which the desktop draws outside the sandbox (the file chooser portal, xdg-desktop-portal-kde) and which
# passes on just the files picked in it, as the open panel does for a sandboxed macOS app.
#
# Keys at rest: Signal and Element keep the key to their local data, Tokodon its login, in KWallet, which the login
# password opens at login (pam_kwallet, which the Plasma module enables for the login stack that SDDM uses).
#
# Disappearing-message timers are configured inside each app; they do not protect against the other
# endpoint keeping copies, and local state still relies on full-disk encryption.
{ inputs, ... }:
{
  imports = [ inputs.nix-flatpak.nixosModules.nix-flatpak ];

  services.flatpak = {
    remotes = [
      {
        name = "flathub";
        location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
      }
    ];
    packages = [
      "org.signal.Signal"
      "im.riot.Riot" # Element
      "org.telegram.desktop"
      "org.kde.tokodon"
    ];
    update.auto = {
      enable = true;
      onCalendar = "weekly";
    };
    overrides.settings = {
      # Tighter than the apps' own manifests: no host or home filesystem, even if a manifest update asks for it.
      global.Context.filesystems = [
        "!host"
        "!home"
      ];
      # Element reaches KWallet (Electron's safeStorage picks kwallet6 under Plasma 6) only with its bus name, which
      # its manifest lacks; without it Element offers to keep its keys unencrypted.
      # https://github.com/flathub/im.riot.Riot (im.riot.Riot.yaml, finish-args)
      "im.riot.Riot"."Session Bus Policy"."org.kde.kwalletd6" = "talk";
      # Signal's Flatpak writes its database key in plain text unless told otherwise (SIGNAL_PASSWORD_STORE=basic,
      # https://github.com/flathub/org.signal.Signal); its manifest already allows KWallet. On the first start Signal
      # stores the key in KWallet and keeps the plain-text copy; the next start deletes that copy once the wallet has
      # returned the same key (Signal-Desktop app/main.main.ts, getSQLKey). From then on Signal needs the wallet to
      # open its database.
      "org.signal.Signal".Environment.SIGNAL_PASSWORD_STORE = "kwallet6";
    };
  };
}
