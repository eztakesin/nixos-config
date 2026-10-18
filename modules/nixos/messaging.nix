# Messengers, installed declaratively as Flatpaks (nix-flatpak) so they run confined with portal-mediated
# access (hardening/sandbox.nix) instead of as unconfined Nix packages:
#   - Signal (primary): end-to-end encrypted by default.
#   - Element (Matrix): end-to-end encrypted rooms.
#   - Telegram: ordinary chats are "cloud chats", encrypted only between the app and Telegram's servers,
#     which can read them; the end-to-end "secret chats" exist only in the mobile and macOS apps, not in
#     Telegram Desktop. Use it for what may be read server-side. https://telegram.org/faq#secret-chats
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
    ];
    update.auto = {
      enable = true;
      onCalendar = "weekly";
    };
    # Tighten the sandbox beyond the apps' own manifests (no host filesystem access by default).
    overrides.global = {
      Context.filesystems = [ "!host" ];
    };
  };
}
