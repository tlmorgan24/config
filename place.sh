#!/bin/bash
# Copies all files in this repo (relative to the repo root) into the corresponding
# location relative to the home directory (~), excluding .git and this script itself.
# All the files in the repo are structured with this in mind, so running this script
# should place them all in the correct locations automatically
set -euo pipefail
script_dir="$(cd "$(dirname "$(realpath "$0")")" && pwd)"

rsync -av \
  --filter=':- .gitignore' \
  --exclude='.git/' \
  --exclude='.gitignore' \
  --exclude='README.md' \
  --exclude="$(basename "$0")" \
  "$script_dir/" \
  "$HOME/"
