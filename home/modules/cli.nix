# Rust-first CLI kit, ported from the operator's per-tool modules. Each program is
# configured through its Home-Manager module; the fish aliases in fish.nix map the classic names onto
# these (ls→eza, du→dust, curl→xh, ping→gping, mtr→trip, tar→ouch, jq→jaq, fzf→sk, nmap→rustscan).
# Catppuccin Latte theming for bat/btop/yazi lives in theme.nix (pinned upstream theme files, no IFD).
{ config, lib, pkgs, ... }:
let
  # zellij starts by itself only in terminals of the graphical session (WAYLAND_DISPLAY/DISPLAY set), never
  # on a text-console login, and never nested. Same generated script as Home-Manager's shell integration.
  zellij = lib.getExe config.programs.zellij.finalPackage;
in
{
  programs = {
    fish.interactiveShellInit = ''
      if set -q WAYLAND_DISPLAY; or set -q DISPLAY
          if test "$TERM" != "dumb"
              eval (${zellij} setup --generate-auto-start fish | string collect)
          end
      end
    '';
    bash.initExtra = ''
      if [[ -n "''${WAYLAND_DISPLAY:-}''${DISPLAY:-}" && "$TERM" != "dumb" ]]; then
          eval "$(${zellij} setup --generate-auto-start bash)"
      fi
    '';
    bat.enable = true;
    btop = {
      enable = true;
      settings = {
        rounded_corners = true;
        graph_symbol = "braille";
        graph_symbol_cpu = "braille";
        graph_symbol_gpu = "braille";
        graph_symbol_mem = "braille";
        graph_symbol_net = "braille";
        graph_symbol_proc = "braille";
      };
    };
    eza = {
      enable = true;
      git = true;
      colors = "always";
      icons = "always";
      enableBashIntegration = true;
      enableFishIntegration = true;
      theme = {
        colourful = true;
        filekinds = {
          normal.foreground = "#BAC2DE";
          directory.foreground = "#89B4FA";
          symlink.foreground = "#89DCEB";
          pipe.foreground = "#7F849C";
          block_device.foreground = "#EBA0AC";
          char_device.foreground = "#EBA0AC";
          socket.foreground = "#585B70";
          special.foreground = "#CBA6F7";
          executable.foreground = "#A6E3A1";
          mount_point.foreground = "#74C7EC";
        };
        perms = {
          user_read.foreground = "#CDD6F4";
          user_write.foreground = "#F9E2AF";
          user_execute_file.foreground = "#A6E3A1";
          user_execute_other.foreground = "#A6E3A1";
          group_read.foreground = "#BAC2DE";
          group_write.foreground = "#F9E2AF";
          group_execute.foreground = "#A6E3A1";
          other_read.foreground = "#A6ADC8";
          other_write.foreground = "#F9E2AF";
          other_execute.foreground = "#A6E3A1";
          special_user_file.foreground = "#CBA6F7";
          special_other.foreground = "#585B70";
          attribute.foreground = "#A6ADC8";
        };
        size = {
          major.foreground = "#A6ADC8";
          minor.foreground = "#89DCEB";
          number_byte.foreground = "#CDD6F4";
          number_kilo.foreground = "#BAC2DE";
          number_mega.foreground = "#89B4FA";
          number_giga.foreground = "#CBA6F7";
          number_huge.foreground = "#CBA6F7";
          unit_byte.foreground = "#A6ADC8";
          unit_kilo.foreground = "#89B4FA";
          unit_mega.foreground = "#CBA6F7";
          unit_giga.foreground = "#CBA6F7";
          unit_huge.foreground = "#74C7EC";
        };
        users = {
          user_you.foreground = "#CDD6F4";
          user_root.foreground = "#F38BA8";
          user_other.foreground = "#CBA6F7";
          group_yours.foreground = "#BAC2DE";
          group_other.foreground = "#7F849C";
          group_root.foreground = "#F38BA8";
        };
        links = {
          normal.foreground = "#89DCEB";
          multi_link_file.foreground = "#74C7EC";
        };
        git = {
          new.foreground = "#A6E3A1";
          modified.foreground = "#F9E2AF";
          deleted.foreground = "#F38BA8";
          renamed.foreground = "#94E2D5";
          typechange.foreground = "#F5C2E7";
          ignored.foreground = "#7F849C";
          conflicted.foreground = "#EBA0AC";
        };
        git_repo = {
          branch_main.foreground = "#CDD6F4";
          branch_other.foreground = "#CBA6F7";
          git_clean.foreground = "#A6E3A1";
          git_dirty.foreground = "#F38BA8";
        };
      };
    };
    fd = {
      enable = true;
      hidden = true;
    };
    ripgrep.enable = true;
    zoxide = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
    };
    skim = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
    };
    yazi = {
      enable = true;
      shellWrapperName = "y"; # HM default moved from yy to y; pinned
      enableBashIntegration = true;
      enableFishIntegration = true;
      settings.mgr = {
        show_hidden = true;
        sort_dir_first = true;
      };
    };
    joshuto.enable = true;
    ranger.enable = true;
    zellij = {
      enable = true;
      # Home-Manager's shell integration starts zellij in EVERY interactive shell, a text-console login
      # included. It is replaced by the init below, which only starts it in the graphical session.
      enableBashIntegration = false;
      enableFishIntegration = false;
      settings = {
        theme = "catppuccin-latte";
        mouse_mode = true;
        scroll_buffer_size = 100000;
        copy_on_select = true;
        copy_command = "wl-copy"; # Wayland clipboard (was pbcopy)
        show_startup_tips = false;
        # Separate switch from the tips: the "What's new?" release-notes popup on the first start of a new
        # version (it swallowed keystrokes on a serial login during the VM rehearsal).
        show_release_notes = false;
      };
    };
    hyfetch = {
      enable = true;
      settings = {
        preset = "transgender";
        mode = "rgb";
        light_dark = "dark";
        color_align.mode = "horizontal";
        backend = "neofetch";
        # Required by hyfetch 2.x (crates/hyfetch/src/models.rs: a bool without a serde default); without it
        # every run stops with "missing field `pride_month_disable`". false = the pride-month animation plays
        # once in June (the "shown" marker lives in ~/.cache, so this read-only file is never written); true = never.
        pride_month_disable = false;
      };
    };
    tealdeer.enable = true;
    lazygit.enable = true;
    gh = {
      enable = true;
      settings = {
        version = 1;
        git_protocol = "https";
        prompt = "enabled";
        prefer_editor_prompt = "disabled";
        aliases.co = "pr checkout";
        color_labels = "disabled";
      };
    };
    htop.enable = true;
    jq.enable = true;
    bash.enable = true;
    less = {
      enable = true;
      options = {
        RAW-CONTROL-CHARS = true;
        mouse = true;
        wheel-lines = 5;
        LONG-PROMPT = true;
      };
    };
    aria2 = {
      enable = true;
      settings = {
        dir = "~/Downloads";
        input-file = "~/.aria2/aria2.session";
        save-session = "~/.aria2/aria2.session";
        save-session-interval = 60;
        continue = true;
        allow-overwrite = true;
        always-resume = true;
        auto-file-renaming = true;
        content-disposition-default-utf8 = true;
        log-level = "notice";
        quiet = true;
        # RPC stays loopback-only; set rpc-secret from a sops secret if a web UI is used.
        enable-rpc = true;
        rpc-listen-all = false;
        rpc-listen-port = 6800;
        max-concurrent-downloads = 5;
        max-connection-per-server = 16;
        min-split-size = "8M";
        split = 16;
        disk-cache = "64M";
        connect-timeout = 20;
        timeout = 60;
        retry-wait = 3;
        max-tries = 5;
        follow-torrent = true;
        bt-save-metadata = true;
        listen-port = "50101-50109";
        dht-listen-port = "50101-50109";
        enable-dht = true;
        enable-dht6 = true;
        enable-peer-exchange = true;
        seed-time = 0;
        seed-ratio = 0.1;
      };
    };
    yt-dlp = {
      enable = true;
      settings = {
        output = "~/Downloads/%(title)s [%(id)s].%(ext)s";
        embed-thumbnail = true;
        embed-metadata = true;
        embed-subs = true;
        sub-langs = "ja,zh-Hans,en";
        downloader = "aria2c";
        downloader-args = "aria2c:'-c -x8 -s8 -k1M'";
      };
    };
  };

  # Rust replacements referenced by the fish aliases, plus clipboard + archive helpers.
  home.packages = with pkgs; [
    dust # du
    xh # curl
    trippy # mtr  (binary: trip)
    bandwhich # iftop
    gping # ping
    rustscan # nmap
    ouch # tar/unzip/…
    jaq # jq
    tailspin # log highlighter
    wl-clipboard # wl-copy / wl-paste
    ripgrep-all
    hyperfine
    tokei
    procs
    sd
  ];
}
