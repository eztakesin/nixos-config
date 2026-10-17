# fish — ported from the operator's macOS config: vi mode, colour scheme, Rust-tool aliases, greeting.
# Dropped as macOS-only: Homebrew PATH juggling and the Apple-Keychain secret helpers (sops-nix replaces
# them). zoxide / starship / gpg-agent are wired by their own Home-Manager modules (no manual `init|source`).
{ ... }:
{
  programs.fish = {
    enable = true;

    interactiveShellInit = ''
      fish_vi_key_bindings

      # Cursor shapes per vi mode
      set fish_cursor_default block blink
      set fish_cursor_insert line blink
      set fish_cursor_replace_one underscore blink

      # Colour scheme (verbatim)
      set fish_color_normal normal
      set fish_color_command blue
      set fish_color_quote yellow
      set fish_color_redirection cyan --bold
      set fish_color_end green
      set fish_color_error brred
      set fish_color_param cyan
      set fish_color_comment red
      set fish_color_match --background=brblue
      set fish_color_selection white --bold --background=brblack
      set fish_color_search_match bryellow --background=brblack
      set fish_color_history_current --bold
      set fish_color_operator brcyan
      set fish_color_escape brcyan
      set fish_color_cwd green
      set fish_color_cwd_root red
      set fish_color_valid_path --underline
      set fish_color_autosuggestion white
      set fish_color_user brgreen
      set fish_color_host normal
      set fish_color_cancel --reverse
      set fish_pager_color_prefix normal --bold --underline
      set fish_pager_color_progress brwhite --background=cyan
      set fish_pager_color_completion normal
      set fish_pager_color_description B3A06D --italics
      set fish_pager_color_selected_background --reverse

      # kitty shell integration: mark prompt start
      function mark_prompt_start --on-event fish_prompt
          echo -en "\e]133;A\e\\"
      end
    '';

    # Rust alternatives
    shellAliases = {
      ls = "eza --icons";
      ll = "eza -lh --icons --git";
      la = "eza -lah --icons --git";
      lt = "eza --tree --icons --level=2";
      jq = "jaq";
      fzf = "sk";
      du = "dust";
      curl = "xh";
      http = "xh";
      https = "xhs";
      ping = "gping";
      nmap = "rustscan";
      mtr = "trip";
      iftop = "sudo bandwhich";
      tar = "ouch";
      untar = "ouch decompress";
    };

    functions = {
      greeting.body = ''
        set_color -o EEA9A9; date +%T; set_color normal
      '';
      nvim = {
        body = ''
          env NVIM_APPNAME="nvim-Lazyman" command nvim $argv
        '';
        wraps = "nvim";
      };
    };
  };

  home.sessionPath = [
    "$HOME/.cargo/bin"
    "$HOME/.local/bin"
  ];

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    PAGER = "less";
    LESS = "--RAW-CONTROL-CHARS --mouse --wheel-lines=5 --LONG-PROMPT";
    LESSOPEN = "";
  };
}
