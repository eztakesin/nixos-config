# git — ported from the operator's macOS config (delta pager, difftastic on demand, nvimdiff, aliases).
# Identity comes from `my.user` (real values in my/private.nix); signing is enabled only when a GPG
# fingerprint is set. The macOS "work identity include" was dropped (single identity on this machine).
{
  lib,
  pkgs,
  my,
  ...
}:
let
  signing = my.user.gpgFingerprint != "";
in
{
  # programs.git writes ~/.config/git/config; a stray ~/.gitconfig would shadow it.
  home.activation.removeExistingGitconfig = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    rm -f ~/.gitconfig
  '';

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };

  programs.git = {
    enable = true;
    lfs.enable = true;

    ignores = [
      "*~"
      "*.swp"
      "\\#*\\#"
      ".\\#*"
      ".vim/coc-settings.json"
      ".vscode"
      ".envrc"
    ];

    settings = {
      user.name = my.user.fullName;
      user.email = my.user.email;
      user.signingKey = lib.mkIf signing my.user.gpgFingerprint;
      commit.gpgSign = signing;
      tag.gpgSign = signing;

      pull.ff = "only";
      rebase.autoSquash = true;
      rebase.abbreviateCommands = true;

      # delta owns everyday diff rendering; difftastic stays available on demand via `git dft`.
      difftool.difftastic.cmd = "${pkgs.difftastic}/bin/difft \"$LOCAL\" \"$REMOTE\"";
      diff.tool = "nvimdiff";
      difftool.prompt = false;
      merge.tool = "nvimdiff";
      merge.conflictstyle = "zdiff3";
      mergetool.prompt = false;
      rerere.enabled = true;

      pager.branch = "less --quit-if-one-screen";
      pager.stash = "less --quit-if-one-screen";

      log.decorate = true;
      stash.showPatch = true;

      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      advice.detachedHead = false;

      alias = {
        br = "branch";
        cmt = "commit -m";
        ca = "commit --amend -m";
        co = "checkout";
        cp = "cherry-pick";
        d = "diff";
        dc = "diff --cached";
        dt = "difftool";
        dft = "difftool --tool difftastic";
        ls = "log --pretty=format:\"%C(yellow)%h%Cred%d\\\\ %Creset%s%Cblue\\\\ [%cn]\" --decorate";
        ll = "log --pretty=format:\"%C(yellow)%h%Cred%d\\\\ %Creset%s%Cblue\\\\ [%cn]\" --decorate --numstat";
        mt = "mergetool";
        st = "status";
        sub = "submodule";
        update = "submodule update --init --recursive";
        foreach = "submodule foreach";
      };
    };
  };
}
