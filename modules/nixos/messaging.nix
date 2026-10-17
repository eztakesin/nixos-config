# Messengers: Signal (primary) and Element, installed declaratively as Flatpaks
# (nix-flatpak) so they run confined with portal-mediated access (hardening/sandbox.nix) instead of as
# unconfined Nix packages. Telegram is not installed by default — its cloud chats are not end-to-end
# encrypted; add "org.telegram.desktop" here on request.
#
# Disappearing-message timers are configured inside each app; they do not protect against the other
# endpoint keeping copies, and local state still relies on full-disk encryption + the per-boot root reset.
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
