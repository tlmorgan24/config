# Usage: `zsh -f cmdlog-search-query.zsh`
#
# Print the search for fzf to run for the query typed into ctrl+r (see cmdlog-history-widget in .zshrc), in the search
# mode its prompt shows. fzf runs this (via transform-search) each time the query or the mode changes, and gives the
# query and prompt in $FZF_QUERY and $FZF_PROMPT. The query box keeps showing what was typed.
#
# fuzzy: the query as typed, so e.g. `git push` finds commands containing both words fuzzily, in any order.
#
# words: each word must appear exactly, in any order, like fzf's --exact (which can't be toggled while fzf runs). E.g.
# `git push` becomes `'git 'push`. Words using fzf's own syntax are left as they are (`!word`, `^word`, `word$`, `|`,
# `'word'`), except that `'word` drops its `'` to become fuzzy, as with --exact.
#
# phrase: the whole query must appear exactly as typed, spaces included, as with --exact --no-extended. E.g. `git push`
# becomes `'git\ push`, one exact term with its spaces escaped. fzf has no way to escape a `$` or `'` at the end of a
# term (`'word$` drops the `$`, and `'word'` matches at word boundaries), so one at the end of the query is left out.

local query=$FZF_QUERY word
local -a words
case $FZF_PROMPT in
  (phrase*)
    query=${query%[\$\']}
    [[ -n $query ]] && print -r -- "'${query// /\\ }"
    ;;
  (words*)
    for word in ${(s: :)query}; do
      # Rejoin a word fzf would keep whole, as it contains an escaped space (e.g. `a\ b`).
      if [[ $words[-1] == *\\ ]]; then
        words[-1]+=" $word"
        continue
      fi
      words+=$word
    done
    for word in $words; do
      case $word in
        (\'?*\'|[\!\^]*|*\$|\|) print -rn -- "$word " ;;
        (\'*) print -rn -- "${word#\'} " ;;
        (*) print -rn -- "'$word " ;;
      esac
    done
    print
    ;;
  (*)
    print -r -- $query
    ;;
esac
