# Editor: VSCodium (telemetry-free build of VS Code) with the operator's extension set.
# Marketplace extensions are fetched and pinned by hash. Dropped vs. the macOS set: ms-python.vscode-pylance
# (its licence restricts it to Microsoft's own VS Code build; pyright is installed instead) and the
# macOS-only binary-plist extension. See https://nixos.ssf.network/reference/packages/ to switch back to `pkgs.vscode`.
{ pkgs, ... }:
{
  # home-manager ≥ 26.05 gives each fork its own module (programs.vscodium, programs.cursor, …) so the
  # settings land in the fork's own paths (~/.config/VSCodium) instead of Visual Studio Code's.
  programs.vscodium = {
    enable = true;
    profiles.default.extensions =
      with pkgs.vscode-extensions;
      [
        rust-lang.rust-analyzer
        ms-python.python
        njpwerner.autodocstring
        ms-toolsai.jupyter-renderers
        graphql.vscode-graphql
        prisma.prisma
        cweijan.vscode-database-client2
        esbenp.prettier-vscode
        davidanson.vscode-markdownlint
        gencer.html-slim-scss-css-class-completion
        styled-components.vscode-styled-components
        gruntfuggly.todo-tree
        pkief.material-icon-theme
        ms-vscode.hexeditor
        streetsidesoftware.code-spell-checker
        ms-vscode.anycode
        wix.vscode-import-cost
        christian-kohler.path-intellisense
        alexdima.copy-relative-path
      ]
      ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
        { name = "nix"; publisher = "bbenoist"; version = "1.0.1"; sha256 = "sha256-qwxqOGublQeVP2qrLF94ndX/Be9oZOn+ZMCFX1yyoH0="; }
        { name = "emojisense"; publisher = "bierner"; version = "0.10.0"; sha256 = "sha256-PD8edYuJu6QHPYIM08kV85LuKh0H0/MIgFmMxSJFK5M="; }
        { name = "markdown-checkbox"; publisher = "bierner"; version = "0.4.0"; sha256 = "sha256-AoPcdN/67WOzarnF+GIx/nans38Jan8Z5D0StBWIbkk="; }
        { name = "markdown-mermaid"; publisher = "bierner"; version = "1.32.0"; sha256 = "sha256-1LlRTkskBAlYV+fq3GVyOUGYXbILvKIByBu2uKwTUUc="; }
        { name = "file-browser"; publisher = "bodil"; version = "0.2.11"; sha256 = "sha256-yPVhhsAUZxnlhj58fXkk+yhxop2q7YJ6X4W9dXGKJfo="; }
        { name = "vscode-tailwindcss"; publisher = "bradlc"; version = "0.15.0"; sha256 = "sha256-W31OlLnRK4YECKToeG6gfpnvjbVHt4BToSF01lGwvEM="; }
        { name = "catppuccin-vsc"; publisher = "catppuccin"; version = "3.19.0"; sha256 = "sha256-6/NHZkg37b6RyZIP89FMltSii+7sC5UTfHYFgyYyl4A="; }
        { name = "gitignore"; publisher = "codezombiech"; version = "0.10.0"; sha256 = "sha256-WTKVHrhBeAocP+stskFsSFtd0aR3u1TTEMYtdxj1tlY="; }
        { name = "vscode-eslint"; publisher = "dbaeumer"; version = "3.0.24"; sha256 = "sha256-ZQVzpSSLf3tpO4QtLjbCOje3L5/EqzT9A9IOssl6e54="; }
        { name = "githistory"; publisher = "donjayamanne"; version = "0.6.20"; sha256 = "sha256-nEdYS9/cMS4dcbFje23a47QBZr9eDK3dvtkFWqA+OHU="; }
        { name = "protobuf-vsc"; publisher = "drblury"; version = "1.6.6"; sha256 = "sha256-uMyxdLptaLZBlLEugvYQgJTZCtysmnZix9faXsQfHGk="; }
        { name = "editorconfig"; publisher = "editorconfig"; version = "0.18.2"; sha256 = "sha256-y8A3D/IEvBbYSj7mgwU2/AQ1WFb6DolasGThoDz8uEo="; }
        { name = "vscode-firefox-debug"; publisher = "firefox-devtools"; version = "2.15.0"; sha256 = "sha256-hBj0V42k32dj2gvsNStUBNZEG7iRYxeDMbuA15AYQqk="; }
        { name = "shell-format"; publisher = "foxundermoon"; version = "7.2.8"; sha256 = "sha256-Z3vmRzqPCxkQbn39I54bh/ND+0HcE9iFUhKQ29GRd7o="; }
        { name = "go"; publisher = "golang"; version = "0.53.1"; sha256 = "sha256-sgZFI3iWioecvh05bTvT/gJU0zEf79P1xs6vzGkBTWU="; }
        { name = "vscode-graphql-syntax"; publisher = "graphql"; version = "1.3.10"; sha256 = "sha256-EY6BHl5ICcs3FuuenoadDXLLPSe8+2VAAydqo/YrtaE="; }
        { name = "vscode-env"; publisher = "irongeek"; version = "0.1.0"; sha256 = "sha256-URq90lOFtPCNfSIl2NUwihwRQyqgDysGmBc3NG7o7vk="; }
        { name = "nix-ide"; publisher = "jnoortheen"; version = "0.5.9"; sha256 = "sha256-hPOcp6Yksgfu1+In21/gJ3MthV8JUV5WaRpYHvo5GGk="; }
        { name = "alejandra"; publisher = "kamadorueda"; version = "1.0.0"; sha256 = "sha256-COlEjKhm8tK5XfOjrpVUDQ7x3JaOLiYoZ4MdwTL8ktk="; }
        { name = "rainbow-csv"; publisher = "mechatroner"; version = "3.24.1"; sha256 = "sha256-xZpK6pJNXnxudauzJihEi9VASRXi89+hn7vfF33qRgY="; }
        { name = "git-graph"; publisher = "mhutchie"; version = "1.30.0"; sha256 = "sha256-sHeaMMr5hmQ0kAFZxxMiRk6f0mfjkg2XMnA4Gf+DHwA="; }
        { name = "black-formatter"; publisher = "ms-python"; version = "2026.5.11321003"; sha256 = "sha256-4p/uKwSHg5HP4qp18eb35Lkb+SDhk4k+oIlEjIqBLOs="; }
        { name = "debugpy"; publisher = "ms-python"; version = "2026.7.11331010"; sha256 = "sha256-WG6uB+q3qnIw5+RWN/774dL04YSdGCE3bN8fzhjl4ck="; }
        { name = "isort"; publisher = "ms-python"; version = "2026.5.11331015"; sha256 = "sha256-zXFUMizE6ClEgzpKD/4mYUgOkoYCFHlkzLfcWDAJ/oY="; }
        { name = "vscode-python-envs"; publisher = "ms-python"; version = "1.33.2026051501"; sha256 = "sha256-V5anlwzLt0V08HsO6TCBIUPD3VPhyohg7YnSc/1++GE="; }
        { name = "jupyter"; publisher = "ms-toolsai"; version = "2025.10.2026051401"; sha256 = "sha256-bVdHaezdeu+SqjbfHK/6LddRuMkWK9FmSUZz6K8ktXE="; }
        { name = "jupyter-keymap"; publisher = "ms-toolsai"; version = "1.1.2"; sha256 = "sha256-9BLyBZzZ0Z6QQ05QSxFJYNZmZDc5O3eYkCxe/UsmKws="; }
        { name = "vscode-jupyter-cell-tags"; publisher = "ms-toolsai"; version = "0.1.9"; sha256 = "sha256-XODbFbOr2kBTzFc0JtjiDUcCDBX1Hd4uajlil7mhqPY="; }
        { name = "vscode-jupyter-slideshow"; publisher = "ms-toolsai"; version = "0.1.6"; sha256 = "sha256-fnsMrrcYdz6BzUWMd9pAOQGTjmtEbQeoVYG20VWxCsM="; }
        { name = "cmake-tools"; publisher = "ms-vscode"; version = "1.24.15"; sha256 = "sha256-y0X5D7fgFbMfJg3O3GOxuayCuvI/0otU0QBeeYOrGLk="; }
        { name = "cpp-devtools"; publisher = "ms-vscode"; version = "0.6.1"; sha256 = "sha256-8Mr5Dob8gBlvr5yBK6RTK/EBeMKBIPc8K2p/HH0O4C0="; }
        { name = "indent-rainbow"; publisher = "oderwat"; version = "8.3.1"; sha256 = "sha256-dOicya0B2sriTcDSdCyhtp0Mcx5b6TUaFKVb0YU3jUc="; }
        { name = "commandonallfiles"; publisher = "rioj7"; version = "0.6.0"; sha256 = "sha256-fPN1bQY96a0bnuq3OeUQTeI67uvPFYPnE6+fKYngUcU="; }
        { name = "trailing-spaces"; publisher = "shardulm94"; version = "0.4.1"; sha256 = "sha256-pLE1bfLRxjlm/kgU9nmtiPBOnP05giQnWq6bexrrIZY="; }
        { name = "even-better-toml"; publisher = "tamasfe"; version = "0.21.2"; sha256 = "sha256-IbjWavQoXu4x4hpEkvkhqzbf/NhZpn8RFdKTAnRlCAg="; }
        { name = "shellcheck"; publisher = "timonwong"; version = "0.39.5"; sha256 = "sha256-8f9LGmNE8ilPYZmbJpmmAx9DkKJXbQzAia11rM3wTec="; }
        { name = "markdown-all-in-one"; publisher = "yzhang"; version = "3.6.3"; sha256 = "sha256-xJhbFQSX1DDDp8iE/R8ep+1t5IRusBkvjHcNmvjrboM="; }
        { name = "json"; publisher = "zainchen"; version = "2.0.2"; sha256 = "sha256-nC3Q8KuCtn/jg1j/NaAxWGvnKe/ykrPm2PUjfsJz8aI="; }
      ];
  };
}
