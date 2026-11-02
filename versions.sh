#!/bin/bash
# Record the version of every tool this config uses into VERSIONS.md, so there's a known-good version to go back to if
# an upgrade breaks something. Run it once everything is confirmed working (e.g. after `brew upgrade`), then commit
# VERSIONS.md. `git diff VERSIONS.md` beforehand shows exactly what changed since the last working record.
set -euo pipefail
script_dir="$(cd "$(dirname "$(realpath "$0")")" && pwd)"
out="$script_dir/VERSIONS.md"

# First line of a command's output, or "not found" if the command doesn't exist or fails.
first_line() {
  local output
  output="$("$@" 2>/dev/null)" || output=""
  echo "${output%%$'\n'*}" | grep . || echo "not found"
}

# Homebrew version of each formula/cask that install.sh installs (read from install.sh itself, so the list never
# drifts).
brew_rows() {
  local kind name version
  grep -oE '^[[:space:]]*brew install( --cask)? [^ #]+' "$script_dir/install.sh" | while read -r _ _ kind name; do
    if [[ "$kind" == --cask ]]; then
      version="$(brew list --cask --versions "$name" 2>/dev/null | awk '{print $NF}' || true)"
    else
      name="$kind"
      version="$(brew list --versions "$name" 2>/dev/null | awk '{print $NF}' || true)"
    fi
    echo "| $name | ${version:-not installed with Homebrew} |"
  done
}

{
  echo "# Working versions"
  echo
  echo "The versions of every tool this config was last confirmed working with, recorded on $(date +%Y-%m-%d) by"
  echo "\`./versions.sh\`. See README.md for how to update this file and how to go back to a version listed here."
  echo
  echo "## System"
  echo
  echo "| Tool | Version |"
  echo "| --- | --- |"
  echo "| macOS | $(sw_vers -productVersion) ($(sw_vers -buildVersion)) |"
  echo "| Homebrew | $(first_line brew --version | awk '{print $2}') |"
  echo "| Claude Code | $(first_line claude --version | awk '{print $1}') |"
  echo
  echo "## Homebrew packages (from install.sh)"
  echo
  echo "| Package | Version |"
  echo "| --- | --- |"
  brew_rows
  echo
  echo "## Commands on PATH"
  echo
  echo "What actually runs, which can differ from the Homebrew package above (e.g. macOS's own git, zsh, vim and jq, or"
  echo "an app installed outside Homebrew)."
  echo
  echo "| Command | Path | Version |"
  echo "| --- | --- | --- |"
  for entry in 'zsh --version' 'git --version' 'vim --version' 'jq --version' 'go version' 'python3 --version' \
    'docker --version' 'code --version'; do
    read -r cmd flag <<< "$entry"
    echo "| $cmd | $(command -v "$cmd" || echo -) | $(first_line "$cmd" "$flag") |"
  done
  echo
  echo "## VS Code extensions"
  echo
  echo "Every installed extension, including those pulled in by vscode-extensions.txt's packs/dependencies."
  echo
  echo "| Extension | Version |"
  echo "| --- | --- |"
  { code --list-extensions --show-versions 2>/dev/null || true; } | sed -E 's/(.*)@(.*)/| \1 | \2 |/'
  echo
  echo "## Go modules"
  echo
  echo "cmdlog's and rebase's dependencies are pinned in their go.mod and go.sum files, so they need no record here."
} > "$out"

echo "Wrote $out"
