# Application confinement:
#   - AppArmor as the system-wide mandatory-access-control layer,
#   - Flatpak + xdg-desktop-portal (bubblewrap underneath) for per-app confinement with consent prompts —
#     the closest Linux analogue to the macOS App Sandbox + TCC model. Browser and messengers run here.
#   - bubblewrap available for ad-hoc wrappers (pkgs/).
# firejail is deliberately not used (setuid root helper).
{ pkgs, ... }:
{
  security.apparmor = {
    enable = true;
    killUnconfinedConfinables = true;
    packages = [ pkgs.apparmor-profiles ];
  };

  services.flatpak.enable = true; # add the remote once: flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
  };

  environment.systemPackages = [ pkgs.bubblewrap ];
}
