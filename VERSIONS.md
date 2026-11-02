# Working versions

The versions of every tool this config was last confirmed working with, recorded on 2026-11-02 by
`./versions.sh`. See README.md for how to update this file and how to go back to a version listed here.

## System

| Tool | Version |
| --- | --- |
| macOS | 26.4.1 (25E253) |
| Homebrew | 7.0.10 |
| Claude Code | 2.1.316 |

## Homebrew packages (from install.sh)

| Package | Version |
| --- | --- |
| ripgrep | 15.2.0 |
| fd | 10.5.0 |
| eza | 0.23.5 |
| bat | 0.26.1 |
| zoxide | 0.10.0 |
| fzf | 0.74.4 |
| jq | not installed with Homebrew |
| gnu-sed | 4.10 |
| grep | 3.12 |
| findutils | 4.11.0 |
| coreutils | 9.12 |
| git | not installed with Homebrew |
| gh | 2.102.0 |
| docker | not installed with Homebrew |
| zsh-syntax-highlighting | 0.8.0 |
| zsh-autopair | 1.0 |
| maccy | 2.7.1 |
| go | 1.27.1 |
| python | not installed with Homebrew |
| font-jetbrains-mono-nerd-font | 3.5.1 |
| ghostty | 1.3.1 |
| starship | 1.26.0 |
| visual-studio-code | not installed with Homebrew |
| poppler | 26.07.0 |

## Commands on PATH

What actually runs, which can differ from the Homebrew package above (e.g. macOS's own git, zsh, vim and jq, or
an app installed outside Homebrew).

| Command | Path | Version |
| --- | --- | --- |
| zsh | /bin/zsh | zsh 5.9 (arm64-apple-darwin25.0) |
| git | /usr/bin/git | git version 2.39.5 (Apple Git-154) |
| vim | /usr/bin/vim | VIM - Vi IMproved 9.1 (2024 Jan 02, compiled Feb 21 2026 19:49:52) |
| jq | /usr/bin/jq | jq-1.7.1-apple |
| go | /opt/homebrew/bin/go | go version go1.27.1 darwin/arm64 |
| python3 | /Library/Frameworks/Python.framework/Versions/3.13/bin/python3 | Python 3.13.2 |
| docker | /usr/local/bin/docker | Docker version 28.0.1, build 068a01e |
| code | /Applications/Visual Studio Code.app/Contents/Resources/app/bin/code | 1.142.0 |

## VS Code extensions

Every installed extension, including those pulled in by vscode-extensions.txt's packs/dependencies.

| Extension | Version |
| --- | --- |
| anthropic.claude-code | 2.1.314 |
| catppuccin.catppuccin-vsc | 3.19.0 |
| catppuccin.catppuccin-vsc-icons | 1.26.0 |
| github.vscode-github-actions | 0.32.3 |
| golang.go | 0.58.0 |
| mechatroner.rainbow-csv | 3.24.1 |
| ms-azuretools.vscode-containers | 2.5.3 |
| ms-azuretools.vscode-docker | 2.0.0 |
| ms-python.debugpy | 2026.6.0 |
| ms-python.python | 2026.4.0 |
| ms-python.vscode-pylance | 2026.4.1 |
| ms-python.vscode-python-envs | 1.40.0 |
| ms-toolsai.datawrangler | 1.24.2 |
| ms-toolsai.jupyter | 2025.9.1 |
| ms-toolsai.jupyter-keymap | 1.1.2 |
| ms-toolsai.jupyter-renderers | 1.3.0 |
| ms-toolsai.vscode-jupyter-cell-tags | 0.1.9 |
| ms-toolsai.vscode-jupyter-slideshow | 0.1.6 |
| redhat.java | 1.58.0 |
| ritwickdey.liveserver | 5.7.10 |
| tomoki1207.pdf | 1.2.2 |
| uctakeoff.vscode-counter | 3.8.1 |
| vscjava.vscode-gradle | 3.18.1 |
| vscjava.vscode-java-debug | 0.60.0 |
| vscjava.vscode-java-dependency | 0.27.7 |
| vscjava.vscode-java-pack | 0.31.2 |
| vscjava.vscode-java-test | 0.47.0 |
| vscjava.vscode-maven | 0.46.0 |
| xadillax.viml | 2.3.0 |
| yzhang.markdown-all-in-one | 3.6.3 |

## Go modules

cmdlog's and rebase's dependencies are pinned in their go.mod and go.sum files, so they need no record here.
