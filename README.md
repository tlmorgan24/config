# How to use

1. Clone this repo
2. Run `./setup.sh`

I.e.:
```bash
git clone https://github.com/tlmorgan24/config.git
config/setup.sh
rm -r config
```

This runs the two separate scripts required to set everything up. You can run them separately if you prefer:
* `./install.sh` - install the tools I use and add them to PATH.
* `./copy.sh` - to copy the associated config files into their appropriate places in your home directory (assumes same structure as on my mac), and apply any app settings that are set with commands rather than config files.

WARNING: the copying of files into the appropriate places in your home directory will overwrite any file that already exists at the same filepath. If you have parts of an existing config file you want to preserve, copy them into the repo files before running `./setup.sh` or `./copy.sh`.

Note, no `chmod +x` is needed for the setup scripts if cloning from my repo, as they are already tracked as executable. The .local/bin executables are also tracked as such, and `./copy.sh` (therefore `./setup.sh`) preserves these permissions, so no `chmod +x` is needed for these either.

Note .zprofile is not shown in the repo, because your .zprofile is instead appended to programmatically in `./install.sh`.

# Shortcuts

A terminal sends the commands you type to the command-line program it is connected to (e.g. Zsh). It’s easy to assume that the terminal “holds” the text you type, and only sends it once you press enter. But actually, everything you type immediately gets sent to the program (and the program usually prints the character you sent, so you can see it).

For this reason, if you want to edit the command you’re typing, it’s the program’s job (not the terminal’s). I.e.: you type a character → terminal sends character (or an associated **keybinding**) to the program → programs responds according to its own rules/config.

While it’s up to the program, there are some common shortcuts many implement. E.g. `Ctrl + A` usually moves cursor to start of line. But these shortcuts are not always intuitive, and generally do not match the natural Mac text-editing shortcuts (e.g. `Cmd + ←` to move to start of line). Therefore, I prefer to give the terminal a keybinding to let me type the natural shortcut while the command-line program handles its more expected shortcut (e.g. `Cmd + ←` gets sent as `Ctrl + A`). If the program still does not respond to the shortcut as I want, I edit its config on a program-by-program basis.

Note there are different notations to represent the same bytes:

- `^X` for given `X` may equivalently be written as `Ctrl + X`.
- `^?` (**delete**) may equivalently be written as `DEL`.
- `\e` (**escape**) may equivalently be written as `ESC`, `^[`, `\x1b` or `\u001b`. Also, pressing `Alt + X` for given X is mapped by most terminals to send the same as `\eX`.

## Terminal keybindings and the program shortcuts configured to respond to them

The keybinding I choose is either the most standard one for the intended behaviour (maximising the likelihood it will be properly interpreted by various programs, therefore minimising amount of program-specific config required), or the one already used by Ghostty & VS Code (presumably with the same reason in mind).

In the table, I specify whether the keybinding is already used by the terminal (Ghostty / VS Code) by default or if I custom-specified it. I also specify whether the keybinding used is responded to by the program (Zsh) with the intended behaviour by default or if I wrote a custom function for it.

| **Shortcut** | **Keybinding used** | **Other popular bindings** | **Ghostty** | **VS Code** | **Intended Zsh behaviour** | **Zsh** | **Intended Vim behaviour** | **Vim** |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type a printable ASCII character | N/A | N/A | N/A | N/A | (1) If text is selected, erase that text (2) Insert the character | Default satisfies (2), wrote custom function to additionally satisfy (1) | Default Vim | Default |
| ← | `\e[D` | `^B` | Default | Default | (1) If nothing selected, move back one character (2) Else, cancel selection | Default satisfies (1), wrote custom function to additionally satisfy (2) | Move in NORMAL/INSERT mode, expand selection in VISUAL mode | Default |
| →  | `\e[C` | `^F` | Default | Default | (1) If nothing selected, move forward one character (2) Else, cancel selection | Default satisfies (1), wrote custom function to additionally satisfy (2) | Move in NORMAL/INSERT mode, expand selection in VISUAL mode | Default |
| Alt + ← | `\eb` | | Default | Default | Move back one word, cancelling selection if there is one | Default satisfies movement, wrote custom function to additionally cancel selection | Move in NORMAL/INSERT mode, expand selection in VISUAL mode | Custom |
| Alt + → | `\ef` | | Default | Default | Move forward one word, cancelling selection if there is one | Default satisfies movement, wrote custom function to additionally cancel selection | Move in NORMAL/INSERT mode, expand selection in VISUAL mode | Custom |
| Cmd + ← | `^A` | | Default | Default | Move to start of line, cancelling selection if there is one | Default satisfies movement, wrote custom function to additionally cancel selection | Move in NORMAL/INSERT mode, expand selection in VISUAL mode | Custom |
| Cmd + → | `^E` | | Default | Default | Move to end of line, cancelling selection if there is one | Default satisfies movement, wrote custom function to additionally cancel selection | Move in NORMAL/INSERT mode, expand selection in VISUAL mode | Custom |
| ↑ | `\e[A` | `^P` | Default | Default | (1) If nothing selected, move up a line (or to previous command if on first line) (2) Else, cancel selection and do the same | Default satisfies (1), wrote custom function to additionally satisfy (2) | Move in NORMAL/INSERT mode, expand selection in VISUAL mode | Default |
| ↓ | `\e[B` | `^N` | Default | Default | (1) If nothing selected, move down a line (or to next command if on last line) (2) Else, cancel selection and do the same | Default satisfies (1), wrote custom function to additionally satisfy (2) | Move in NORMAL/INSERT mode, expand selection in VISUAL mode | Default |
| Cmd + ↑ | `\e[1;9A` | | Custom | Custom | Move to start of command, cancelling selection if there is one | Custom | Move to start of file in NORMAL/INSERT mode, expand selection in VISUAL mode | Custom |
| Cmd + ↓ | `\e[1;9B` | | Custom | Custom | Move to end of command, cancelling selection if there is one | Custom | Move to end of file in NORMAL/INSERT mode, expand selection in VISUAL mode | Custom |
| ⌫ | `^?` | `^H` | Default | Default | (1) If nothing selected, delete the character before cursor (2) Else, delete the selected text. | Default satisfies (1), wrote custom function to additionally satisfy (2) | Delete character before cursor in INSERT mode, act like `c` in VISUAL mode | Default satisfies INSERT behaviour, custom adjustment to act like `c` in VISUAL mode instead of `d` |
| fn + ⌫ | `\e[3~` | `^D` | Default | Default | Delete character under cursor (i.e., after cursor, if cursor is a thin line rather than block) | Default | | |
| Alt + ⌫ | `\e^?` | `^W` | Default | Default | Delete back to start of word | Default | Do so in INSERT mode | Custom |
| Cmd + ⌫ | `^U` |  | Default | Default | Delete back to start of line | Custom | Do so in INSERT mode | Custom |
| Shift + ← | `\e[1;2D` |  | Default | Default | Expand selection left by one character | Custom | Do so in VISUAL mode (automatically enter VISUAL mode if currently in NORMAL/INSERT) | Custom |
| Shift + → | `\e[1;2C` |  | Default | Default | Expand selection right by one character | Custom | Do so in VISUAL mode (automatically enter VISUAL mode if currently in NORMAL/INSERT) | Custom |
| Alt + Shift + ← | `\e[1;4D` |  | Default | Default | Expand selection to start of word | Custom | Do so in VISUAL mode (automatically enter VISUAL mode if currently in NORMAL/INSERT) | Custom |
| Alt + Shift + → | `\e[1;4C` |  | Default | Default | Expand selection to end of word | Custom | Do so in VISUAL mode (automatically enter VISUAL mode if currently in NORMAL/INSERT) | Custom |
| Cmd + Shift + ← | `\e[1;10D` |  | Default | Custom | Expand selection to start of line | Custom | Do so in VISUAL mode (automatically enter VISUAL mode if currently in NORMAL/INSERT) | Custom |
| Cmd + Shift + → | `\e[1;10C` |  | Default | Custom | Expand selection to end of line | Custom | Do so in VISUAL mode (automatically enter VISUAL mode if currently in NORMAL/INSERT) | Custom |
| Shift + ↑ | `\e[1;2A` |  | Default | Default | Expand selection up a line (or to start of command if on first line) | Custom | Do so in VISUAL mode (automatically enter VISUAL mode if currently in NORMAL/INSERT) | Custom |
| Shift + ↓ | `\e[1;2B` |  | Default | Default | Expand selection down a line (or to end of command if on last line) | Custom | Do so in VISUAL mode (automatically enter VISUAL mode if currently in NORMAL/INSERT) | Custom |
| Cmd + Shift + ↑ | `\e[1;10A` |  | Custom | Custom | Expand selection to start of command | Custom | Expand selection to start of file in VISUAL mode (automatically enter VISUAL mode if currently in NORMAL/INSERT) | Custom |
| Cmd + Shift + ↓ | `\e[1;10B` |  | Custom | Custom | Expand selection to end of command | Custom | Expand selection to end of file in VISUAL mode (automatically enter VISUAL mode if currently in NORMAL/INSERT) | Custom |
| Cmd + Shift + c | `\e[99;9u` |  | Custom | Custom | Copy program's selection to clipboard | Custom | Copy visual mode selection to clipboard (not to Vim register, which is done with `y`) | Custom |
| Cmd + x | `\e[120;9u` |  | Custom | Custom | Cut selection (i.e. delete and copy to clipboard) | Custom | As for copy, but also erase selected text and enter insert mode | Custom |
| Cmd + v | | | | | (1) If text is selected, delete the selected text (2) Then, paste from clipboard. | Default (not sure specifically how Ghostty / VS Code handle it, but whatever it is they do, it ends up working exactly as desired in Zsh) | Paste from clipboard in INSERT mode | Default |
| Cmd + z | `^_` |  | Custom | Custom | Undo | Default | Undo | Custom |
| Cmd + Shift + z | `^[/` |  | Custom | Custom | Redo | Mapped existing function to respond as desired | Redo | Custom |
| Tab | `^I` |  | Default | Default | Autocomplete | Default | Insert indent in INSERT mode, indent selected lines by one level in VISUAL mode | Default satisfies INSERT behaviour, custom for VISUAL |
| Shift + Tab | `\e[Z` |  | Default | Default | | | Unindent current line (INSERT mode) or selected lines (VISUAL mode) by one level | Custom |
| Cmd + ] | `\e[93;9u` |  | Custom | Custom | | | Indent current line (NORMAL/INSERT mode) or selected lines (VISUAL mode) by one level | Custom |
| Cmd + [ | `\e[91;9u` |  | Custom | Custom | | | Unindent current line (NORMAL/INSERT mode) or selected lines (VISUAL mode) by one level | Custom |
| Cmd + Enter | `\e[13;9u` |  | Custom | Custom | Queue a command (see details below) | Custom | | |

Note all selections refer to the PROGRAM's selection (e.g. as manipulated by above shortcuts), rather than TERMINAL's selection (e.g. from mouse drag in most situations). Both Ghostty and VS Code use Cmd+c to copy the terminal's selection, so I am forced to use Cmd+Shift+c if wanting to copy the program's selection. There is no way to merge the behaviours, because the program (e.g. Zsh) cannot know what/when the terminal (e.g. Ghostty) has highlighted text, and vice versa.

## Other shortcuts

### Zsh

There are mostly the result of my config files.

Search and navigation:
* `fzf` - each line of its stdin becomes an option you can choose from interactively. Type to fuzzy search, navigate options with up/down arrows, then choose one by pressing enter. The chosen option then gets passed to its stdout.
* Tab - autocomplete command/argument (e.g. `vim fi<TAB>` might autocomplete as `vim file123.txt`)
* Ctrl+r (see `cmdlog` below) - type to fuzzy search through command history, navigate with up/down arrows. Press enter to paste the command into the command line at the cursor. The preview shows where and when the command was last run, its exit status and its output. Press Ctrl+r again to toggle between commands from all directories and only those run in the current directory. Press Ctrl+t to toggle syntax highlighting of the listed commands.
* `browse` - opens interactive file browser. Type to fuzzy search, navigate within directory with up/down arrows, navigate out/into directories with left/right. Press enter to send highlighted file/directory to stdout. E.g. `vim "$(browse)"` lets you interactively choose a file to edit. Can also select multiple entries with tab (enter to send all of them as separate lines of stdout). Press Ctrl+f to instead search every file below the current directory (hidden and git-ignored files excluded), and Ctrl+f again to go back to browsing, in the directory of the highlighted file.
* Ctrl+f - as with `browse`, but press enter to insert the chosen file(s)/directories into the command line at the cursor. E.g. type `vim `, press Ctrl+f, choose a file, then press enter to run `vim <file>`.
* `cd` (no arguments) - as with `browse`, but press enter to change directory to the highlighted directory (no multi-select).
* `z <directory-substring>` - changes to most likely directory based on substring and your previous directory changes.
* `z -` or `cd -` - changes to previous working directory
* `zi` - similar to my custom `cd`, but rank according to `z`'s likelihood, without changing order based off the search input. Also, lists all directories rather than a navigable tree.

Note fzf provides ctrl+r (search command history) ctrl+t (search for file/directory) and alt+c (search for directory to cd into) shortcuts, but these are superseded by my ctrl+r, ctrl+f, and cd. My ctrl+r replaces fzf's, but ctrl+t and alt+c remain available if desired.

Utilities:
* Ctrl+z then Cmd+Enter - queue commands. While a command runs, press Ctrl+z to suspend it, then type the next command and press Cmd+Enter to queue it and resume the first. Queued commands run in turn once the previous one succeeds (Ctrl+z/Cmd+Enter again to queue more). Cmd+Enter on an empty line just resumes without adding anything more to queue. A failure, ctrl+c, or `unqueue` drops the queue. `requeue` repopulates and executes the queue. E.g. if `cmd` fails, running `cmd && requeue` retries it with the same queue that the previous failure dropped.
* `calc` - open REPL calculator in terminal. Works as though everything you type is in `echo $((...))`, i.e., can use/define shell variables, do command substitution, etc. Unlike usual `((...))`, I chose to make it use float arithmetic, so e.g. `3/4` is 0.75 instead of 0. However, this does mean integers will be saved with trailing `.000...`, so avoid using saved variables string comparisons.
* `c` - copies its stdin to clipboard
* `v` - pastes clipboard to its stdout
* `lst [directory]` - list directory contents, including subdirectories etc, with a tree view. Uses CWD if no directory specified.
* `concat` - concatenate arguments directly (unlike `echo`, which separates them with a space, and `cat`, which reads files)
* `p` - alias for `perl -ane`, while still allowing extra flags to be passed without -e swallowing them. Also takes `-R<sep>`, where `<sep>` is a custom record separator, acting like the record counterpart of `-F` (separator is a regex pattern, just like `-F`).
* `pp` - like `p`, but slurps the whole input as one record (-0777), so don't use `-R`.
* `ff [fd args] <code>` - "for each file": runs arbitrary shell code for each file/directory `fd` finds, with the path in `$f`. E.g. `ff -e md 'echo "$f"; head -1 "$f"'` prints each Markdown file's name and first line.
* `fr <sep> <code> [files]` - "for each record": like `ff`, but for records split on a regex (as with `p -R`), with the record (excluding separator) in `$r` and the separator that ended it in `$s`. Reads stdin if no files given. E.g. `printf 'a,b,c' | fr , 'echo "item: $r"'`.
* `fl <code> [files]` - "for each line": `fr` with a newline separator, so the line is in `$r`. E.g. `fl 'mkdir "$r"' names.txt` makes a directory for each line.
* `mkcd <dir>` - like `cd`, but creates the directory first if does not exist.
* `mkcp [flags] <source>... <dest>` / `mkmv [flags] <source>... <dest>` - like `cp`/`mv`, but creates the destination directory first if does not exist. As per `cp`/`mv`'s rules, the directory is `dest` itself if it ends in `/` or there are multiple sources, otherwise its parent (or the directory given to GNU's `-t`).
* `mkp <path>` - creates the parent directory of `path` if it does not exist, then prints `path`. Useful for redirecting with automatic mkdir, e.g. `cmd > "$(mkp out/sub/file)"` (also works with `>>`, `2>`, etc).
* `govi [directory [module name]]` - quickly run a draft Go program: `mkcd`s into `directory` (uses current directory if empty string or not provided), inits a module (named `draft` if `module name` not provided), opens a hello world `main.go` in vim for you to edit, then formats, tidies modules and runs. Exits early if `main.go` already exists. Quit vim with `:cq` to skip running (loses unsaved changes).
* `goco [directory [module name]]` - like `govi`, but opens the directory in VS Code for more in-depth work, and doesn't format/tidy/run automatically.

Git 1:
* `gaa` - alias for `git add -u` - adds tracked files (like the -a in `git commit -a`)
* `gad` - alias for `git add .` - 'd' stands for 'dot' or 'directory', as stages entire current directory (except .gitignored files)
* `gap` - alias for `git add -p .` - stages changes interactively, patch by patch (instead of entire files)
* `gaar` - alias for `git add -u && git restore --staged`
* `gadr` - alias for `git add . && git restore --staged`
* `gc` - alias for `git commit -m`
* `gca` - alias for `git add -u && git commit -m` (like `git commit -am`)
* `gcd` - alias for `git add . && git commit -m`
* `gcp` - alias for `git add -p . && git commit -m`
* `gcf` - alias for `git commit --amend --no-edit` - gcf stands for 'git commit fixup', because its effect is equivalent to fixing up the previous commit
* `gci` - alias for `git add . && git restore --staged .gitignore && git commit -m` - so you can locally change the .gitignore to ignore personal files without worrying about committing the gitignore itself
* `gcaf` - alias for `git commit -a --amend --no-edit`
* `gcdf` - alias for `git add . && git commit --amend --no-edit`
* `gcif` - alias for `git add . && git restore --staged .gitignore && git commit --amend --no-edit`
* `gl` - alias for `git log --oneline`
* `gt` - alias for `git log --graph --oneline --all` - tree view of all commits
* `gs` - alias for `git status`

Git 2:
* `push` - pushes current branch to its upstream (if one is configured) or the same-name branch on origin (setting this as the upstream)
* `pull` - merges current branch's remote into local
* `reset-origin <branch>` - hard-resets chosen local branch to its corresponding remote branch. The remote branch is automatically fetched.
* `reset-main` - equivalent to `reset-origin main`
* `rebase-origin <branch>` - rebases current branch onto chosen remote branch. The remote branch is automatically fetched before the rebase.
* `rebase-main` - equivalent to `rebase-origin main`
* `merge-origin <branch>` - merges chosen remote branch into current branch. The remote branch is automatically fetched before the merge.
* `merge-main` - equivalent to `merge-origin main`
* `drop <commit>` - removes a commit (e.g. `HEAD`, `HEAD~3` or a hash) from history, leaving files as if it had never been made, while keeping your staged and unstaged changes as they are. Refuses commits that are already pushed (use `git revert` for those). Uses `git rebase` internally, so if later commits conflict with the removal, it will stop so you can resolve them.
* `pr [options]` - pushes current branch and creates PR to merge it into main. The .md file passed with `--md <filepath>` (anywhere among the options) is parsed to use its level-1 header (e.g. `# My PR title`) as the PR title and the rest of the file as the body (assuming no other level-1 headers). Other options (e.g. `--draft`) are passed to `gh pr create`, except title/body options can't be combined with `--md`. If neither these nor `--md` are provided, will be prompted to enter title and body manually.
* `repo [gh repo create options] <path>` - creates a private GitHub repo (unless `--public`/`--internal` passed) set as the origin of the directory specified by `<path>`. If directory exists (e.g. `.`), it is `git init`ed (if not already), and any commits are pushed. If the directory doesn't exist, it is created and `git init`ed.
* `clonecd [flags] <repository> [directory]` - like `git clone`, but then `cd`s into the cloned repository. Arguments are same as `git clone`.
* `cloneco [flags] <repository> [directory]` - like `clonecd`, but also opens the repository in VS Code.
* `switch` - interactive `git switch` that previews the logs of each branch. Type to fuzzy search, navigate with up/down arrows. Choose the branch to switch to by pressing enter.
* `checkout` - interactive `git checkout` that previews the log of each commit and its surroundings.
* `rebase` - `git rebase -i --autostash` with interactive todo list showing the current branch's history. Mark the commit under the cursor with p/r/e/s/f/d (pick/reword/edit/squash/fixup/drop), unmark it with u, and move it up/down with Option+up/down. Shift+up/down scrolls the preview. Commit hashes are yellow if not yet pushed, and red if the upstream branch already has them. The rebase starts just below the oldest commit marked or moved (shown as "onto"), so you don't need to know the base upfront. Note that staged changes come back unstaged after the rebase (git's autostash doesn't keep the index). Written as a Go program in `rebase/`, built into `~/.local/bin` by `./copy.sh`.

### Vim

There are mostly the result of my config files.

* Mouse click -	move cursor
* Mouse drag - enter visual mode and select dragged-over region
* Shift + mouse drag - terminal selection (rather than vim selection), copyable to clipboard with cmd+c
* Backspace - if in insert mode, deletes character before cursor. If in visual mode, acts like `c`

The usual vim keybindings continue to work (d/y/c to delete/yank/change, etc).

### VS Code

Useful default behaviours:

* Run `code <file>` or `code <directory>` to open files/folder in VS Code. If did not install VS Code through Homebrew, may have to manually add this to ~/.zprofile: `export PATH="/Applications/Visual Studio Code.app/Contents/Resources/app/bin:$PATH"`.
* Cmd+f - open find and replace. Can press buttons to make pattern case sensitive (insensitive by default) and match entire word. More powerfully, can press button to make pattern a regex pattern. Refer to captured groups in the "replace" box with e.g. `$1`, rather than `\1`.
* Alt+click - place additional cursor. Anything you type (inserts/deletes) will apply to all cursors simultaneously.
* Insert a 'wrapping' type of punctuation while have text selected - wraps the selected text. E.g. pressing `[` while `hello` is selected changes it to `[hello]`.
* Alt+up/down - swap current line with line before/after
* Alt+z: Toggle between views that wrap long lines vs let them run off the screen
* cmd+shift+o: Search for "symbols" (e.g. classes/methods/functions) within current file and jump to one. The symbols are indexed by the language server (e.g. Pylance), which is present if you have installed the appropriate extension.
* cmd+t: Like cmd+shift+o, but across entire repository. May be more picky (e.g. only show classes) unless specifically configure the language server.

Thanks to extensions:
* cmd+b - bold in .md files.
* cmd+i - italicise in .md files.
* alt+shift+f - format table in .md files.
* ... and more markdown conveniences.

Extensions are listed in `vscode-extensions.txt` and automatically installed by `./install.sh`.

### Maccy (clipboard history)

* Cmd+Shift+v - open clipboard history. Type to fuzzy search, navigate with up/down arrows, press enter to paste the chosen item (without formatting).

Maccy's settings are applied by `./copy.sh` with `defaults write` (see the Maccy section there).

# cmdlog

Every command run in an interactive shell is recorded by `cmdlog` (a Go program in `cmdlog/`, built into `~/.local/bin` by `./copy.sh`), along with when and where it ran, its exit status and its output. Ctrl+r in Zsh searches this history. I.e., `cmdlog` is my alternative to fzf's or atuin's own ctrl+r shortcut, which I found not sufficiently customisable.

* Recording works by running zsh under `cmdlog record`, which passes everything between the terminal and zsh through untouched. zsh's preexec/precmd hooks print invisible markers telling it where each command's output starts and ends (see the cmdlog section of `.zshrc`, and `cmdlog/marker.go`).
* The history is a SQLite database at `~/.local/share/cmdlog/history.db` (table `commands`), readable only by you. Query it directly with e.g. `sqlite3 ~/.local/share/cmdlog/history.db "select command, status from commands where dir = '$PWD'"`.
* Output from interactive programs (vim, fzf, a pager you scrolled through like `git log`...) isn't kept (but if they print anything after they exit, this is kept). Output short enough that the pager exits by itself (e.g. `git log -1`) is kept. Each command keeps at most the last 4MB of its output.
* Ctrl+r can show commands with the same syntax highlighting as the command line. The ctrl+r widget points cmdlog (via `$CMDLOG_HIGHLIGHT`) at `.zsh/highlight-commands.zsh`, which runs zsh-syntax-highlighting with my settings from `.zsh/syntax-highlighting.zsh`, plus the shell's aliases, function names and options (saved by the widget). This takes about 2ms per command, so with a long history the list can take a moment to fill in (newest first). For better performance, the list starts uncoloured by default, with only the preview highlighted, which costs ~20ms per preview independent of history size. You can then choose to press ctrl+t to toggle whether the list is coloured. To start with it coloured, set `colour_rows=1` in .zshrc's `cmdlog-history-widget`.
* Errors are logged to `~/.local/share/cmdlog/errors.log`. If cmdlog can't record, the shell still starts, unrecorded. To stop recording entirely, delete `~/.local/bin/cmdlog`.

# Claude Code

`.claude/` is copied to `~/.claude` by `./copy.sh`, so it applies to every Claude Code account on the machine.

* `CLAUDE.md` - instructions for every project (e.g. no Claude attribution in anything it writes; never kill processes by name or pattern).
* `settings.json` - settings, including hooks. Note, this replaces the machine's `~/.claude/settings.json`, so settings changed from inside Claude Code (e.g. `/model`) are lost on the next `./copy.sh` unless copied into the repo.
* `hooks/guard-process-kill.sh` (requires `jq`) - runs before every shell command and file write Claude makes, and makes Claude Code ask before anything that could kill processes it didn't start (`pkill`, `killall`, `kill` with `pgrep`/`ps`/`lsof`, `kill -1`, process groups, `psutil`/`killpg` in code). Added after a pattern kill force-closed all my open terminals. If the hook itself fails (e.g. `jq` missing), it blocks the action rather than letting it through. Review or disable it with `/hooks` in Claude Code.

Also, Claude Code is prevented from loading my full .zshrc by the `[[ -n "$CLAUDECODE" ]] && return` line there. This prevents the shell commands it runs having behaviour it doesn't expect.

# Future work

* Enable shift + click to expand selection from old cursor position to new cursor position in vim