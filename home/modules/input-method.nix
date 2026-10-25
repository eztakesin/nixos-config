# fcitx5 for the operator. The profile (which input methods, in which order) and the candidate-window theme are
# links to the system defaults in /etc/xdg/fcitx5 (modules/nixos/locale-fonts.nix), replacing whatever fcitx5
# saved before, so a rebuild is the only thing that changes them. Rime's schema list is set here; its user data
# (learned words) stays writable under ~/.local/share/fcitx5/rime. The Rime part follows oxalica's nixos-config
# (home/modules/rime-fcitx.nix): a changed schema list clears Rime's build so that it redeploys.
{ config, lib, pkgs, ... }:
let
  rimeDir = "${config.xdg.dataHome}/fcitx5/rime";
  qdbus = "${pkgs.kdePackages.qttools}/bin/qdbus";
in
{
  xdg.configFile = {
    "fcitx5/profile" = {
      source = config.lib.file.mkOutOfStoreSymlink "/etc/xdg/fcitx5/profile";
      force = true;
    };
    "fcitx5/conf/classicui.conf" = {
      source = config.lib.file.mkOutOfStoreSymlink "/etc/xdg/fcitx5/conf/classicui.conf";
      force = true;
    };
  };

  # Simplified first, then Traditional (朙月拼音 outputs Traditional characters). F4 or Ctrl+` switches.
  xdg.dataFile."fcitx5/rime/default.custom.yaml" = {
    text = builtins.toJSON {
      patch = {
        schema_list = [
          { schema = "luna_pinyin_simp"; }
          { schema = "luna_pinyin"; }
        ];
        "menu/page_size" = 9;
      };
    };
    onChange = "rimeSettingChanged=1";
  };

  home.activation.rimeRedeploy = lib.hm.dag.entryAfter [ "writeBoundary" "onFilesChange" ] ''
    if [[ -v rimeSettingChanged ]]; then
      run rm -rf "${rimeDir}/build"
      # Redeploys at once in a running session; otherwise Rime deploys when fcitx5 next starts.
      run ${qdbus} org.fcitx.Fcitx5 /controller org.fcitx.Fcitx.Controller1.SetConfig "fcitx://config/addon/rime/deploy" "" 2>/dev/null || true
    fi
  '';
}
