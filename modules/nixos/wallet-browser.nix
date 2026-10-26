# A Chrome for a browser wallet only (opt-in: my.features.walletBrowser = true). Google's dev channel from Flathub
# (com.google.ChromeDev), the nearest to Chrome Canary that can be kept declaratively: Canary for Linux exists
# (google-chrome-canary in Google's apt repository) but is rebuilt every day and its old packages disappear, so no
# fixed hash outlives a day, and Flathub has no Canary. The Flathub package pins each dev release by its hash and runs
# Chrome's own sandbox inside Flatpak's (zypak); nix-flatpak installs it and updates it weekly (messaging.nix).
#
# Extensions: only the ones in my.walletBrowser.extensions (Rabby Wallet by default), installed from the Chrome Web
# Store by their ids, so a look-alike extension under another id cannot be added. Policies are a plain file under
# /etc/opt/chrome/policies/managed: the Flatpak's launcher links the host's policy files into its own /etc
# (chrome.sh in https://github.com/flathub/com.google.ChromeDev), but only regular files (find -type f), so the file
# is copied (mode), not linked into the store. Policy names: https://chromeenterprise.google/policies/
{ lib, my, ... }:
let
  enabled = (my.features or { }).walletBrowser or false;
  extensions = my.walletBrowser.extensions;
in
lib.mkIf enabled {
  services.flatpak.packages = [ "com.google.ChromeDev" ];

  services.flatpak.overrides.settings."com.google.ChromeDev" = {
    Context = {
      # The Downloads folder stays (exports, statements); Documents, Pictures, Music and Videos go. The home folder is
      # gone for every Flatpak app already (messaging.nix); host-etc stays, for the policies above.
      filesystems = [
        "!xdg-documents"
        "!xdg-pictures"
        "!xdg-music"
        "!xdg-videos"
      ];
      # The GPU only: no USB, HID or camera devices (no hardware wallet is used), and no smart cards, which would
      # include the YubiKey.
      devices = [
        "!all"
        "dri"
      ];
      sockets = [ "!pcsc" ];
    };
    # No Bluetooth (Web Bluetooth). KWallet for Chrome's own key, which encrypts its cookies and saved passwords: Chrome
    # picks KWallet under Plasma, and the manifest only allows the Secret Service name. Rabby encrypts its keys with its
    # own password, inside the profile.
    "System Bus Policy"."org.bluez" = "none";
    "Session Bus Policy"."org.kde.kwalletd6" = "talk";
  };

  environment.etc."opt/chrome/policies/managed/wallet-browser.json" = {
    mode = "0444";
    text = builtins.toJSON {
      ExtensionInstallForcelist = map (id: "${id};https://clients2.google.com/service/update2/crx") extensions;
      ExtensionInstallBlocklist = [ "*" ];
      ExtensionInstallAllowlist = extensions;
      BlockExternalExtensions = true;
      # No Google account and no sync in the wallet's browser, and no usage statistics.
      BrowserSignin = 0;
      SyncDisabled = true;
      MetricsReportingEnabled = false;
    };
  };
}
