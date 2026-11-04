# Usage: `zsh -f fzf-help.zsh <key> <description> [<key> <description> ...]`
#
# Print the help for an fzf tool's keys, as a label for the top of its border (see _fzf_help in .zshrc), with as many
# of the items as fit in fzf's width ($FZF_COLUMNS), dropping the rest from the end. fzf can't shorten a label itself:
# one too wide is drawn as just its last character. Coloured like rebase's help (see rebase/ui.go), with each key in
# the text colour, then what it does in a dimmer one.

local key=$'\e[38;2;205;214;244m' desc=$'\e[38;2;166;173;200m'
# The widest label fzf draws with at least one `─` after it, padding included
local room=$(( ${FZF_COLUMNS:-$COLUMNS} - 1 ))
local label= item
local -i width=2  # The padding either side
while (( $# >= 2 )); do
  item="$1 $2"
  (( width + (${#label} ? 2 : 0) + ${(m)#item} > room )) && break
  (( width += (${#label} ? 2 : 0) + ${(m)#item} ))
  label+="${label:+  }$key$1 $desc$2"
  shift 2
done
[[ -n $label ]] && print -r -- " $label "
