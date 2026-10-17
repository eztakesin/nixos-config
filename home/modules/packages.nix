# Desktop applications, language servers and developer tooling for the operator — the Linux port of the
# macOS manifest. Rationale and the opt-in items: https://nixos.ssf.network/reference/packages/. Items the operator must decide
# on are behind `my.features.*` toggles (default off) so the default closure stays lean.
{ pkgs, lib, my, ... }:
let
  features = my.features or { };
  on = name: features.${name} or false;

  myPython = pkgs.python3.withPackages (
    ps: with ps; [
      aiohttp
      numpy
      pylint
      pyyaml
      requests
      toml
      python-lsp-server
      pylsp-mypy
      pyls-isort
      pylsp-rope
      python-lsp-ruff
      ipykernel
      six
      inflect
      mnemonic
    ]
  );

  lsp = with pkgs; [
    bash-language-server
    ccls
    dockerfile-language-server
    fish-lsp
    lua-language-server
    pyright
    stylua
    nil
    topiary
    eslint
    vscode-langservers-extracted
    yaml-language-server
    yamlfmt
  ];

  cli = with pkgs; [
    myPython
    deno
    go
    nodejs_26
    pnpm
    pipx
    uv
    luarocks
    tree-sitter
    nix-prefetch
    caddy
    mkcert
    rclone
    wget
    rich-cli
    trash-cli
    _7zz
    unar
    ascii-image-converter
    djvulibre
    figlet
    glow
    gnuplot
    imagemagick
    librsvg
    libqalculate
    lolcat
    lynx
    numbat
    pandoc
    pngcrush
    poppler-utils
    w3m
    protonmail-bridge
    claude-code
  ];

  gui = with pkgs; [
    mpv
    inkscape-with-extensions
    qbittorrent-enhanced
    thunderbird
    wireshark
    xournalpp
    protonmail-desktop
    qalculate-qt
    easylpac
  ];
in
{
  home.packages =
    lsp
    ++ cli
    ++ gui
    ++ lib.optionals (on "zoom") [ pkgs.zoom-us ]
    ++ lib.optionals (on "java") [ pkgs.temurin-bin ]
    ++ lib.optionals (on "julia") [ pkgs.julia-bin ]
    ++ lib.optionals (on "foundry") [ pkgs.foundry ]
    ++ lib.optionals (on "azure") [ pkgs.azure-cli ];
}
