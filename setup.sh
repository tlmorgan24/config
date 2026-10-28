#!/bin/bash
# Set everything up: install the tools I use (install.sh), then copy the config files into their places in the home
# directory (copy.sh).
set -euo pipefail
script_dir="$(cd "$(dirname "$(realpath "$0")")" && pwd)"

"$script_dir/install.sh"

# install.sh only adds Homebrew to PATH for its own process (and future shells, via ~/.zprofile), so add it here too:
# copy.sh needs Homebrew's `go` to build cmdlog.
for brew in /opt/homebrew/bin/brew /usr/local/bin/brew; do
  if [ -x "$brew" ]; then
    eval "$("$brew" shellenv)"
    break
  fi
done

"$script_dir/copy.sh"

echo "Setup complete. Open a new terminal to load the new config."
