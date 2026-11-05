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

# Versions

`VERSIONS.md` records the version of every tool this config was last confirmed working with (macOS, Homebrew, every package `./install.sh` installs, the commands that actually run, VS Code extensions and Claude Code). `./install.sh` always installs the latest versions, so if something breaks after an upgrade, this is what to go back to.

* Update it - run `./versions.sh` once everything is confirmed working (e.g. after `brew upgrade`), check what changed with `git diff VERSIONS.md`, then commit it. It reads the package list from `./install.sh`, so new packages are picked up automatically.
* Go back to a Homebrew formula's version - Homebrew only installs the latest version, so copy the old one into a local tap: `brew tap-new $USER/local`, `brew extract --version=<version> <formula> $USER/local`, then `brew uninstall <formula>` and `brew install $USER/local/<formula>@<version>`. Run `brew pin <formula>` to stop a working version from being upgraded in the first place.
* Go back to a Homebrew cask's (app's) version - download that version from the app's website or GitHub releases.
* Go back to a VS Code extension's version - `code --install-extension <id>@<version>`, then turn off auto-update for it (right-click it in the Extensions view).
* Go back to Claude Code's version - `claude install <version>`.
* Go modules (for cmdlog and rebase) are already pinned in their `go.mod` and `go.sum`.

# Keybindings

## Background

A terminal sends the commands you type to the command-line program it is connected to (e.g. Zsh). It’s easy to assume that the terminal “holds” the text you type, and only sends it once you press enter. But actually, everything you type immediately gets sent to the program (and the program usually prints the character you sent, so you can see it).

For this reason, if you want to edit the command you’re typing, it’s the program’s job (not the terminal’s). I.e.: you type a character → terminal sends character (or an associated **keybinding**) to the program → programs responds according to its own rules/config.

While it’s up to the program, there are some common shortcuts many implement. E.g. `Ctrl + A` usually moves cursor to start of line. But these shortcuts are not always intuitive, and generally do not match the natural Mac text-editing shortcuts (e.g. `Cmd + ←` to move to start of line). Therefore, I prefer to give the terminal a keybinding to let me type the natural shortcut while the command-line program handles its more expected shortcut (e.g. `Cmd + ←` gets sent as `Ctrl + A`). If the program still does not respond to the shortcut as I want, I edit its config on a program-by-program basis.

Note there are different notations to represent the same bytes:

- `^X` for given `X` may equivalently be written as `Ctrl + X`.
- `^?` (**delete**) may equivalently be written as `DEL`.
- `\e` (**escape**) may equivalently be written as `ESC`, `^[`, `\x1b` or `\u001b`. Also, pressing `Alt + X` for given X is mapped by most terminals to send the same as `\eX`.

## My keybindings & associated shortcuts

The keybinding I choose is either the most standard one for the intended behaviour (maximising the likelihood it will be properly interpreted by various programs, therefore minimising amount of program-specific config required), or the one already used by Ghostty & VS Code (presumably with the same reason in mind).

In the table, I specify whether the keybinding is already used by the terminal (Ghostty / Kitty / VS Code) by default or if I custom-specified it. The Zsh and Vim columns give the intended behaviour in each program, followed by whether the program does it by default or through my custom config (e.g. "Default (1), custom (2)" when the default only does part (1)). The Claude Code column compares Claude Code's prompt box with the intended Zsh behaviour, saying whether it does so by default or through my `prompt-select` mod (see Claude Code below).

| **Shortcut** | **Keybinding used** | **Other popular bindings** | **Ghostty** | **Kitty** | **VS Code** | **Zsh** | **Vim** | **Claude Code** |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type a printable ASCII character | N/A | N/A | N/A | N/A | N/A | (1) If text is selected, erase that text (2) Insert the character. Default (2), custom (1) | Default | Same as Zsh |
| ← | `\e[D` | `^B` | Default | Default | Default | (1) If nothing selected, move back one character (2) Else, cancel selection. Default (1), custom (2) | Move in NORMAL/INSERT mode, expand selection in VISUAL mode. Default | Same as Zsh |
| →  | `\e[C` | `^F` | Default | Default | Default | (1) If nothing selected, move forward one character (2) Else, cancel selection. Default (1), custom (2) | Move in NORMAL/INSERT mode, expand selection in VISUAL mode. Default | Same as Zsh |
| Alt + ← | `\eb` | | Default | Custom | Default | Move back one word, cancelling selection if there is one. Default movement, custom cancelling | Move in NORMAL/INSERT mode, expand selection in VISUAL mode. Custom | Same as Zsh |
| Alt + → | `\ef` | | Default | Custom | Default | Move forward one word, cancelling selection if there is one. Default movement, custom cancelling | Move in NORMAL/INSERT mode, expand selection in VISUAL mode. Custom | Same as Zsh |
| Cmd + ← | `^A` | | Default | Custom | Default | Move to start of line, cancelling selection if there is one. Default movement, custom cancelling | Move in NORMAL/INSERT mode, expand selection in VISUAL mode. Custom | Same as Zsh |
| Cmd + → | `^E` | | Default | Custom | Default | Move to end of line, cancelling selection if there is one. Default movement, custom cancelling | Move in NORMAL/INSERT mode, expand selection in VISUAL mode. Custom | Same as Zsh |
| ↑ | `\e[A` | `^P` | Default | Default | Default | (1) If nothing selected, move up a line (or to previous command if on first line) (2) Else, cancel selection and do the same. Default (1), custom (2) | Move in NORMAL/INSERT mode, expand selection in VISUAL mode. Default | Same as Zsh, except moves by line as wrapped on screen |
| ↓ | `\e[B` | `^N` | Default | Default | Default | (1) If nothing selected, move down a line (or to next command if on last line) (2) Else, cancel selection and do the same. Default (1), custom (2) | Move in NORMAL/INSERT mode, expand selection in VISUAL mode. Default | Same as Zsh, except moves by line as wrapped on screen |
| Cmd + ↑ | `\e[1;9A` | | Custom | Custom | Custom | Move to start of command, cancelling selection if there is one. Custom | Move to start of file in NORMAL/INSERT mode, expand selection in VISUAL mode. Custom | Same as Zsh |
| Cmd + ↓ | `\e[1;9B` | | Custom | Custom | Custom | Move to end of command, cancelling selection if there is one. Custom | Move to end of file in NORMAL/INSERT mode, expand selection in VISUAL mode. Custom | Same as Zsh |
| ⌫ | `^?` | `^H` | Default | Default | Default | (1) If nothing selected, delete the character before cursor (2) Else, delete the selected text. Default (1), custom (2) | Delete character before cursor in INSERT mode, act like `c` (rather than Vim's default `d`) in VISUAL mode. Default INSERT, custom VISUAL | Same as Zsh |
| fn + ⌫ | `\e[3~` | `^D` | Default | Default | Default | Delete character under cursor (i.e., after cursor, if cursor is a thin line rather than block). Default | | Same as Zsh |
| Alt + ⌫ | `\e^?` | `^W` | Default | Default | Default | Delete back to start of word. Default | Do so in INSERT mode. Custom | Same as Zsh |
| Cmd + ⌫ | `^U` |  | Default | Custom | Default | Delete back to start of line. Custom | Do so in INSERT mode. Custom | Same as Zsh |
| Shift + ← | `\e[1;2D` |  | Default | Default | Default | Expand selection left by one character. Custom | Do so in VISUAL mode (automatically enter VISUAL mode if currently in NORMAL/INSERT). Custom | Same as Zsh |
| Shift + → | `\e[1;2C` |  | Default | Default | Default | Expand selection right by one character. Custom | Do so in VISUAL mode (automatically enter VISUAL mode if currently in NORMAL/INSERT). Custom | Same as Zsh |
| Alt + Shift + ← | `\e[1;4D` |  | Default | Default | Default | Expand selection to start of word. Custom | Do so in VISUAL mode (automatically enter VISUAL mode if currently in NORMAL/INSERT). Custom | Same as Zsh |
| Alt + Shift + → | `\e[1;4C` |  | Default | Default | Default | Expand selection to end of word. Custom | Do so in VISUAL mode (automatically enter VISUAL mode if currently in NORMAL/INSERT). Custom | Same as Zsh |
| Cmd + Shift + ← | `\e[1;10D` |  | Default | Default | Custom | Expand selection to start of line. Custom | Do so in VISUAL mode (automatically enter VISUAL mode if currently in NORMAL/INSERT). Custom | Same as Zsh |
| Cmd + Shift + → | `\e[1;10C` |  | Default | Default | Custom | Expand selection to end of line. Custom | Do so in VISUAL mode (automatically enter VISUAL mode if currently in NORMAL/INSERT). Custom | Same as Zsh |
| Shift + ↑ | `\e[1;2A` |  | Default | Default | Default | Expand selection up a line (or to start of command if on first line). Custom | Do so in VISUAL mode (automatically enter VISUAL mode if currently in NORMAL/INSERT). Custom | Not possible: the prompt box handles Shift + ↑/↓ itself without telling mods, and no keybinding can take them first |
| Shift + ↓ | `\e[1;2B` |  | Default | Default | Default | Expand selection down a line (or to end of command if on last line). Custom | Do so in VISUAL mode (automatically enter VISUAL mode if currently in NORMAL/INSERT). Custom | Not possible (see Shift + ↑) |
| Cmd + Shift + ↑ | `\e[1;10A` |  | Custom | Default | Custom | Expand selection to start of command. Custom | Expand selection to start of file in VISUAL mode (automatically enter VISUAL mode if currently in NORMAL/INSERT). Custom | Same as Zsh, except forced to make the cursor end up at the far end of the selection rather than going to the start (a mod can't otherwise make ⌫ delete a selection reaching the start) |
| Cmd + Shift + ↓ | `\e[1;10B` |  | Custom | Default | Custom | Expand selection to end of command. Custom | Expand selection to end of file in VISUAL mode (automatically enter VISUAL mode if currently in NORMAL/INSERT). Custom | Same as Zsh |
| Cmd + Shift + c | `\e[99;9u` |  | Custom | Custom | Custom | Copy program's selection to clipboard. Custom | Copy visual mode selection to clipboard (not to Vim register, which is done with `y`). Custom | Same as Zsh, except if nothing selected in the prompt box, copies what is selected with the mouse instead |
| Cmd + x | `\e[120;9u` |  | Custom | Default | Custom | Cut selection (i.e. delete and copy to clipboard). Custom | As for copy, but also erase selected text and enter insert mode. Custom | Same as Zsh |
| Cmd + v | | | | | | (1) If text is selected, delete the selected text (2) Then, paste from clipboard. Default (not sure specifically how Ghostty / Kitty / VS Code handle it, but whatever it is they do, it ends up working exactly as desired in Zsh) | Paste from clipboard in INSERT mode. Default | Same as Zsh, except required custom for case (1) |
| Cmd + z | `^_` |  | Custom | Custom | Custom | Undo. Default | Undo. Custom | Same as Zsh |
| Cmd + Shift + z | `^[/` |  | Custom | Custom | Custom | Redo. Custom (mapped an existing function) | Redo. Custom | Not supported: Claude Code has no redo, and reads `^[/` as Alt + /, which types `/` (and reaches mods exactly like typing `/`, so a mod can't add redo) |
| Tab | `^I` |  | Default | Default | Default | Autocomplete. Default | Insert indent in INSERT mode, indent selected lines by one level in VISUAL mode. Default INSERT, custom VISUAL | Same as Zsh |
| Shift + Tab | `\e[Z` |  | Default | Default | Default | | Unindent current line (INSERT mode) or selected lines (VISUAL mode) by one level. Custom | |
| Cmd + ] | `\e[93;9u` |  | Custom | Default | Custom | | Indent current line (NORMAL/INSERT mode) or selected lines (VISUAL mode) by one level. Custom | |
| Cmd + [ | `\e[91;9u` |  | Custom | Default | Custom | | Unindent current line (NORMAL/INSERT mode) or selected lines (VISUAL mode) by one level. Custom | |
| Cmd + Enter | `\e[13;9u` |  | Custom | Custom | Custom | Queue a command (see details below). Custom | | Queue a prompt (see custom mod below) |
| Cmd + e | `\e[101;9u` | `^X^E` | Custom | Default | Custom | Edit command line (or just the selection, if there is one) in `$EDITOR` (Vim), starting in NORMAL mode at the cursor (INSERT mode if the command line is empty). Saving and quitting puts the edited text back on the command line, without running it. Custom: wrapped an existing function, to pass the shell's aliases etc to Vim, and ensured Vim colours the command exactly as zsh does. Vim starts in INSERT mode on an empty command line by `.vim/plugin/insert-when-empty.vim` | | Edit the whole prompt in `$EDITOR` (Vim), even if there is a selection (default action, bound in `keybindings.json`), starting in NORMAL mode at the start of the cursor's line (Claude Code tells Vim the cursor's line, but not its column), or in INSERT mode if the prompt is empty. |

Note all selections refer to the PROGRAM's selection (e.g. as manipulated by above shortcuts), rather than TERMINAL's selection (e.g. from mouse drag in most situations). Ghostty, Kitty and VS Code all use Cmd+c to copy the terminal's selection, so I am forced to use Cmd+Shift+c if wanting to copy the program's selection. There is no way to merge the behaviours, because the program (e.g. Zsh) cannot know what/when the terminal (e.g. Ghostty) has highlighted text, and vice versa. Claude Code is the exception, as it draws its own mouse selection rather than leaving that to the terminal, so Cmd+Shift+c there can copy either. Also, in Claude Code the first character of a leftward selection sadly shows unhighlighted, as Claude Code never highlights the character under the cursor.

# Terminals (Ghostty, Kitty & VS Code)

## Comparison

The differences I am aware of at the time of writing are:
* Ghostty's keybindings can't depend on what's running in the terminal (VS Code has `when` clauses, and Kitty can run a Python kitten), so Ghostty's Ctrl+↑/↓ prompt jumping can't hand the keys over to Claude Code instead.
* VS Code doesn't support the Kitty graphics protocol, and draws images badly with the two protocols it does have (Sixel and iTerm2's), so `browse` doesn't show images there.
* VS Code has cursor delay when switching vim mode (e.g. if insert mode is bar cursor and normal mode is block cursor, it takes about a second for it to change to a block cursor when entering normal mode). AI keeps saying it would be fixed by ttimeoutlen, but it is wrong.
* VS Code needs Option+click, while others just need a click, to move the cursor within the command at the zsh prompt. Kitty is has a massive delay when doing click-to-move, which I couldn't solve. None of the terminals allow clicking to move on a multi-line command (as the earlier lines have already been sent to e.g. Zsh).
* In programs that use the mouse themselves (e.g. Vim), Shift+drag makes a terminal selection in Ghostty and Kitty, but VS Code can only do this with Option+drag after turning on `terminal.integrated.macOptionClickForcesSelection`, which stops Option+click moving the cursor in the command, so I leave it off.
* VS Code requires opening the full app, which is more overhead.
* Programs run in VS Code's terminal can integrate with the rest of VS Code (e.g. cmd+click on a `file:line` path in any output opens the file at that line, Claude Code sees the lines selected in the editor, etc).

## Shortcuts

* Ctrl+↑/↓ - scroll to the previous/next command's prompt, e.g. to get back past a long output. `./copy.sh` turns off macOS's own Ctrl+↑/↓ (Mission Control / App Exposé) to free them up, and sets 4-finger swipe up/down for those features instead.

# Other shortcuts

## Zsh

### Search and navigation

* `fzf` - each line of its stdin becomes an option you can choose from interactively. Type to fuzzy search, navigate options with up/down arrows, then choose one by pressing enter. The chosen option then gets passed to its stdout.
* Tab - autocomplete command/argument (e.g. `vim fi<TAB>` might autocomplete as `vim file123.txt`)
* Ctrl+r (see `cmdlog` below) - type to fuzzy search through command history, navigate with up/down arrows. Press enter to paste the command into the command line at the cursor. The preview shows where and when the command was last run, its exit status and its output. Press Ctrl+r again to toggle between commands from all directories and only those run in the current directory. Press Ctrl+t to toggle syntax highlighting of the listed commands. Press Ctrl+s to cycle the search mode (shown in the prompt) between fuzzy, words (each word must appear exactly, in any order) and phrase (the whole query must appear exactly, spaces included).
* `browse` - opens interactive file browser. Type to fuzzy search, navigate within directory with up/down arrows, navigate out/into directories with left/right. Preview shows the highlighted file, directory, or image (images only in Ghostty and kitty, as VS Code draws them badly). Shift+up/down scrolls preview, alt+z toggles text wrapping of preview. Press enter to send highlighted file/directory to stdout. E.g. `vim "$(browse)"` lets you interactively choose a file to edit. Can also select multiple entries with tab (enter to send all of them as separate lines of stdout). Press Ctrl+f to toggle between default browsing mode (only shows/searches entries directly inside the directory) and searching everything below the current directory (any depth). Hidden and git-ignored files are never shown. When in "everything below" mode, press left to jump to browsing the directory the highlighted file directly sits in (useful for skipping lots of directory traversals). Press Ctrl+s to cycle the search mode, as in Ctrl+r above.
* Ctrl+f - as with `browse`, but press enter to insert the chosen file(s)/directories into the command line at the cursor. E.g. type `vim `, press Ctrl+f, choose a file, then press enter to run `vim <file>`.
* `cd` (no arguments) - as with `browse`, but press enter to change directory to the highlighted directory (no multi-select).
* `z <directory-substring>` - changes to most likely directory based on substring and your previous directory changes.
* `z -` or `cd -` - changes to previous working directory
* `zi` - similar to my custom `cd`, but rank according to `z`'s likelihood, without changing order based off the search input. Also, lists all directories rather than a navigable tree.

Note fzf provides ctrl+r (search command history) ctrl+t (search for file/directory) and alt+c (search for directory to cd into) shortcuts, but these are superseded by my ctrl+r, ctrl+f, and cd. My ctrl+r replaces fzf's, but ctrl+t and alt+c remain available if desired.

### Utilities

* Ctrl+z then Cmd+Enter - queue commands. While a command runs, press Ctrl+z to suspend it, then type the next command and press Cmd+Enter to queue it and resume the first. Queued commands run in turn once the previous one succeeds (Ctrl+z/Cmd+Enter again to queue more). Cmd+Enter on an empty line just resumes without adding anything more to queue. A failure, ctrl+c, or `unqueue` drops the queue. `requeue` repopulates and executes the queue. E.g. if `cmd` fails, running `cmd && requeue` retries it with the same queue that the previous failure dropped.
* `calc` - open REPL calculator in terminal. Works as though everything you type is in `echo $((...))`, i.e., can use/define shell variables, do command substitution, etc. Unlike usual `((...))`, I chose to make it use float arithmetic, so e.g. `3/4` is 0.75 instead of 0. However, this does mean integers will be saved with trailing `.000...`, so avoid using saved variables string comparisons.
* `c` - copies its stdin to clipboard
* `v` - pastes clipboard to its stdout
* `lst [directory]` - list directory contents, including subdirectories etc, with a tree view. Uses CWD if no directory specified.
* `concat` - concatenate arguments directly (unlike `echo`, which separates them with a space, and `cat`, which reads files)
* `p` - alias for `perl -ane`, while still allowing extra flags to be passed without -e swallowing them. Also takes `-R<sep>`, where `<sep>` is a custom record separator, acting like the record counterpart of `-F` (separator is a regex pattern, just like `-F`).
* `pp` - like `p`, but slurps the whole input as one record (-0777), so don't use `-R`.
* `ff [fd args] <code>` - "for each file": runs arbitrary shell code for each file/directory `fd` finds, with the path in `$f`. E.g. `ff -e md 'echo $f; head -1 $f'` prints each Markdown file's name and first line.
* `fr <sep> <code> [files]` - "for each record": like `ff`, but for records split on a regex (as with `p -R`), with the record (excluding separator) in `$r` and the separator that ended it in `$s`. Reads stdin if no files given. E.g. `printf 'a,b,c' | fr , 'echo "item: $r"'`.
* `fl <code> [files]` - "for each line": `fr` with a newline separator, but with the line in `$l`. E.g. `fl 'mkdir $l' names.txt` makes a directory for each line.
* `bf [fd args] <code>` / `br <sep> <code> [files]` / `bl <code> [files]` - "batch files/records/lines": like `ff`/`fr`/`fl`, but run the code once, with all the paths/records/lines in the array `$f`/`$r`/`$l` (and no `$s`). Can then make use of the fact that providing an array (without extra quotes) in Zsh passes each element as its own argument. E.g., while `ff -e md 'wc -l $f'` runs `wc` once per file (`wc -l file1`, `wc -l file2`, ...), `bf -e md 'wc -l $f'` runs it once on all of them (`wc -l file1 file2 ...`). This is like `fd -x` vs `fd -X`.
* `cp`/`mv` - ask before overwriting an existing file (declining is the default). Use `\cp`/`\mv` (or `command cp`/`command mv`) to overwrite without asking.
* `rm [-dfrRv] [<file>...]` - moves files/directories to the Bin instead of deleting them, so Finder's "Put Back" can restore them to where they were. Needs macOS 15 or later (for `/usr/bin/trash`). Also asks for confirmation before removing your home directory, a directory directly in it (e.g. `~/Downloads`), or a directory above it. Otherwise behaves like `rm` (e.g. directories need `-r`). If no paths provided, lets you choose interactively (i.e., works like `browse | bl 'rm -r [options] $l'`). Use `\rm` (or `command rm`) to delete permanently, e.g. to free up space straight away.
* `mkcd <dir>` - like `cd`, but creates the directory first if does not exist.
* `mkcp [flags] <source>... <dest>` / `mkmv [flags] <source>... <dest>` - like `cp`/`mv`, but creates the destination directory first if does not exist (and, like my `cp`/`mv`, asks before overwriting). As per `cp`/`mv`'s rules, the directory is `dest` itself if it ends in `/` or there are multiple sources, otherwise its parent (or the directory given to GNU's `-t`).
* `mkp <path>` - creates the parent directory of `path` if it does not exist, then prints `path`. Useful for redirecting with automatic mkdir, e.g. `cmd > "$(mkp out/sub/file)"` (also works with `>>`, `2>`, etc).
* `govi [directory [module name]]` - quickly run a draft Go program: `mkcd`s into `directory` (uses current directory if empty string or not provided), inits a module (named `draft` if `module name` not provided), opens a hello world `main.go` in vim for you to edit, then formats, tidies modules and runs. Exits early if `main.go` already exists. Quit vim with `:cq` to skip running (loses unsaved changes).
* `goco [directory [module name]]` - like `govi`, but opens the directory in VS Code for more in-depth work, and doesn't format/tidy/run automatically.

Note the `cp`/`mv`/`rm` protections only apply to commands the shell itself runs: typed directly, loops, subshells etc. Commands started by other programs get the real ones, e.g. `fd -x`, `find -exec`/`-delete`, `xargs`, `sudo`, `sh -c` and scripts. However, my custom `ff`/`fr`/`fl`/`bf`/`br`/`bl` are set up to run through the shell, so the protections apply. Therefore, prefer `ff`/`bf` over `fd -x`/`fd -X` for anything that might be destructive.

Limitations of `ff`/`fr`/`fl`/`bf`/`br`/`bl`:
* Single-quote the code, otherwise the shell expands `$f` etc. before the function sees it.
* When `fr`/`fl`/`br`/`bl` get their input from stdin (e.g. `cat list | fl ...`, rather than `fl ... list`), commands in the code would share that stdin by default (only overridden by pipe/redirect *inside* the code). This would be dangerous, as the parts read by the commands in the code would be stolen away from `fr`/`fl`/`br`/`bl` and wouldn't be part of the record parsing. So:
  * When `fr`/`fl`/`br`/`bl` get their input from stdin, commands in the code have their stdin redirected to read from terminal's keyboard input by default (so no clash). If there is no terminal, commands get empty input by default.
  * When `fr`/`fl`/`br`/`bl` get their input from a file argument, commands in the code can read stdin as normal.
* Zsh's behaviour is for an empty value to disappear when unquoted. E.g. for an empty line, `cat $l` becomes `cat`, meaning `cat` will wait for stdin to come from elsewhere (e.g. terminal input, as per above). To instead keep an empty argument, use e.g. `"$l"` in `fl` or `"$l[@]"` in `bl`.
* The code runs in the current shell, so a `cd` or variable assignment carries over to the next file/record and stays afterwards, and `exit` closes the terminal. Wrap the code in `( )` to prevent this.
* Records containing NUL bytes are split at them.
* Unlike `fd -X` and `xargs` (which split a long list of arguments across several runs), `bf`/`br`/`bl` pass all arguments at once. If it's a huge list (tens of thousands), the command taking the arguments can fail with "argument list too long".

## Git

### Simple aliases

* `ga` - alias for `git add` 
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
* `gcaf` - alias for `git commit -a --amend --no-edit`
* `gcdf` - alias for `git add . && git commit --amend --no-edit`
* `gl` - alias for `git log --oneline`
* `glt` - alias for `git log --graph --oneline --all` - tree view of all commits
* `gs` - alias for `git status`

### Syncing with remotes

* `push [options]` - pushes current branch to its upstream (if one is configured) or the same-name branch on origin (setting this as the upstream). Options (e.g. `--tags`) are passed to `git push`, except `-f`/`--force` becomes `--force-with-lease --force-if-includes`, so a force push can't overwrite remote commits you haven't integrated locally (use `git push --force` directly to overwrite them anyway).
* `pull [options]` - merges current branch's remote into local. Options (e.g. `--rebase`) are passed to `git pull`.
* `reset-origin <branch>` - resets chosen local branch to its corresponding remote branch, keeping uncommitted changes (aborts if any are in files that differ from the remote branch). The remote branch is automatically fetched. If the local branch has commits that the remote branch doesn't, lists them and asks for confirmation before dropping them.
* `reset-main` - equivalent to `reset-origin main`
* `rebase-origin <branch> [options]` - rebases current branch onto chosen remote branch. The remote branch is automatically fetched before the rebase. Options (e.g. `--autostash`) are passed to `git rebase`.
* `rebase-main [options]` - equivalent to `rebase-origin main [options]`
* `merge-origin <branch> [options]` - merges chosen remote branch into current branch. The remote branch is automatically fetched before the merge. Options (e.g. `--no-ff`) are passed to `git merge`.
* `merge-main [options]` - equivalent to `merge-origin main [options]`
* `clonecd [flags] <repository> [directory]` - like `git clone`, but then `cd`s into the cloned repository. Arguments are same as `git clone`.
* `cloneco [flags] <repository> [directory]` - like `clonecd`, but also opens the repository in VS Code.

### GitHub

* `pr [options]` - pushes current branch and creates PR to merge it into main. The .md file passed with `--md <filepath>` (anywhere among the options) is parsed to use its level-1 header (e.g. `# My PR title`) as the PR title and the rest of the file as the body (assuming no other level-1 headers). Other options (e.g. `--draft`) are passed to `gh pr create`, except title/body options can't be combined with `--md`. If neither these nor `--md` are provided, will be prompted to enter title and body manually.
* `repo [gh repo create options] <path>` - creates a private GitHub repo (unless `--public`/`--internal` passed) set as the origin of the directory specified by `<path>`. If directory exists (e.g. `.`), it is `git init`ed (if not already), and any commits are pushed. If the directory doesn't exist, it is created and `git init`ed. Refuses if the directory already has an `origin` remote.

### Interactive tools

* `rebase` - `git rebase -i --autostash` with interactive todo list, showing a graph of all branches as it will be once rebased. The preview shows the diff of the highlighted commit. Commit hashes are yellow if not yet pushed, and red if a remote branch (e.g. `origin/main`) already has them. Mark the commit with p/r/e/s/f/d for pick/reword/edit/squash/fixup/drop. Mark with b/c for base/cutoff. Can provide arguments like for `git rebase` to prepopulate the base/cutoff. Note that staged changes come back unstaged after the rebase (git's autostash doesn't keep the index). Written as a Go program in `rebase/`, built into `~/.local/bin` by `./copy.sh`.
* `pick` - interactive `git cherry-pick`, using same tool as `rebase`, but where any arguments are as per `git cherry-pick` to prepopulate the commits to pick. Press p on any commit to mark it for cherry-picking and Shift+p to pick every commit between it and the last p. Each newly picked commit goes on top (applied last). Internally implemented with `git rebase -i --autostash HEAD`, so after a conflict or edit, continue with `git rebase --continue` (or `git rebase --abort`), not `git cherry-pick --continue`. 
* `drop` - interactive removal of commits from history, using same tool as `rebase`, but where any arguments are like for `pick` to prepopulate the commits to drop. If later commits conflict with the removal, it stops so you can resolve them, then continue with `git rebase --continue` (or `git rebase --abort`).
* `checkout` - interactive `git checkout` of any commit, using same tool as `rebase`, but just to look around the graph of all branches, with the preview showing the diff of the highlighted commit. Starts on the current commit (HEAD). Choose the commit to check out (leaving HEAD detached there) by pressing enter. If given any arguments, runs `git checkout` with them directly (non-interactive).
* `switch` - interactive `git switch` that previews the logs of each branch. Type to fuzzy search, navigate with up/down arrows. Choose the branch to switch to by pressing enter. If given any arguments, runs `git switch` with them directly (non-interactive).

Note (to make the tools work intuitively), `pick` can mark any commit HEAD doesn't already contain, whereas `rebase` and `drop` can only mark commits it DOES contain (with further limitations if there are merge commits).

## Vim

* Mouse click -	move cursor
* Mouse drag - enter visual mode and select dragged-over region
* Shift + mouse drag (not in VS Code) - terminal selection (rather than vim selection), copyable to clipboard with cmd+c
* Backspace - if in insert mode, deletes character before cursor. If in visual mode, acts like `c`
* The insert mode text editing shortcuts in the table above also work on the command line (`:`, `/` and `?`): Alt + ←/→ (move by word, stopping where `b`/`w` do), Cmd + ←/→ and Cmd + ↑/↓ (start/end of command line), Alt + ⌫ and Cmd + ⌫ (delete back to start of word/line). The selection, undo and indent shortcuts have no command line equivalent
* Pasting a command that starts with `:` (e.g. `:set number`) onto an empty `:` command line drops the pasted `:`, so it doesn't end up as `::set number`

The usual vim keybindings continue to work (d/y/c to delete/yank/change, etc).

## Claude Code

`.claude/` is copied to `~/.claude` by `./copy.sh`, so it applies to every Claude Code account on the machine.

* `CLAUDE.md` - instructions for every project (e.g. no Claude attribution in anything it writes; never kill processes by name or pattern).
* `settings.json` - settings, including hooks/mods as below. Note, this replaces the machine's `~/.claude/settings.json`, so settings changed from inside Claude Code (e.g. `/model`) are lost on the next `./copy.sh` unless copied into the repo.
* Ctrl+R - opens `/resume`
* Esc Esc - opens `/rewind`
* Cmd+Enter - sends prompt to queue, only to be run when Claude has finished answering its current prompt (and any others already in the queue). Queued messages are listed above the prompt box until they are sent.
* Option+↑/↓ - navigate through queued messages for editing. Enter or Cmd+Enter puts the edited text back in its place in the queue, or deletes it if the box is empty. Option+Esc cancels the editing instead, undoing every edit since the first Option+↑. While editing queued messages, Claude is prevented from moving onto anything in the queue, to let you make any edits without fear that it will read anything before you are ready.
* Ctrl+↑/↓ - scroll the transcript to the previous/next prompt I sent, as the terminal does between shell prompts. From partway through a turn, Ctrl+↑ first goes to that turn's own prompt. Done by my `prompt-jump` mod. This replaces Claude Code's own Ctrl+↑/↓ for scrolling the diff view's file list. Only works in VS Code and Kitty's terminals, as Ghostty can't be configured to conditionally take Ctrl+↑/↓ for itself vs pass to claude.
* `/copy-session` - copy this session's transcript to the clipboard as Markdown, e.g. to search it with `v | rg <pattern>`. Runs straight away, even while Claude is answering. Done by my `copy-session` mod.
* `claude-search` (outside of Claude) - search every Claude Code session I've had, from any directory. Each line of every transcript is an option, labelled with its session's date and directory. Type to fuzzy search (Ctrl+s cycles the search mode, as in Ctrl+r), with newer sessions ranked first among equally good matches. Ctrl+r toggles between sessions in all directories and only those started in the current directory (as in the Ctrl+r tool). The preview shows the line in its session's transcript, with Markdown highlighting. Press enter to continue that session with `claude --resume`, in the directory it was started in (the shell then stays in that directory).
* `claude-transcripts` (outside of Claude) - bring the cache of every session's transcript (as Markdown) in `~/.cache/claude-transcripts` up to date, and print its path. E.g. `rg -i <pattern> $(claude-transcripts)`. `claude-search` runs it each time, so it is automatically up to date.
* `hooks/guard-process-kill.sh` - runs before every shell command and file write Claude makes, and makes Claude Code ask before anything that could kill processes it didn't start (`pkill`, `killall`, `kill` with `pgrep`/`ps`/`lsof`, `kill -1`, process groups, `psutil`/`killpg` in code). Added after a pattern kill force-closed all my open terminals. If the hook itself fails (e.g. `jq` missing), it blocks the action rather than letting it through. Review or disable it with `/hooks` in Claude Code.

Also, Claude Code is prevented from loading my full .zshrc by the `[[ -n "$CLAUDECODE" ]] && return` line there. This prevents the shell commands it runs having behaviour it doesn't expect.

### Review tool

Usage: `/review <spec-file> [--rounds <n>] [--model <model>] [--base <commit>]`

* Gets an independent reviewer to check the changes made in this session against a spec I wrote. All changes since the session started are included, regardless whether made by this session's agent (the "writer") or other means (me or another agent). Alternatively, pass `--base <commit>` to diff against a commit. The writer can fix or dispute each finding in a "fix round", and each fix round is followed by another review, which checks the fixes and looks for new problems in them. If the writer disputes a finding, it does not go back to the reviewer; if the reviewer confirms a fix, it does not go back to the writer. The back-and-forth continues until all are disputed/confirmed, or until `--rounds` fix rounds are finished (default 1), after which a summary is given to the user. E.g. `--rounds 0` means reviewer reports directly back without letting writer fix anything. The reviewer's instructions are in `review/reviewer-prompt.md`.
* Beyond the necessary communication between writer and reviewer, they are isolated from each other as much as possible. The reviewer is a separate headless Claude Code (`claude -p`, Sonnet by default, with read-only tools), and its prompt is built by `review/review.sh` rather than by the writer, so it only ever sees the spec, diff and repo. It never sees the original session's conversation. The spec is copied when the review starts, so the writer is less likely to change it between reviews (and so I can delete the original without waiting for the review to finish). The summary shown at the end by the `review-summary` mod is a "system notice" which (according to Claude's documentation) the session (writer) never reads. It's also saved in `~/.cache/claude-review/<session id>/`, and I can print it with `~/.claude/review/review.sh summary` in shell.

## VS Code

### Useful default behaviours

* Run `code <file>` or `code <directory>` to open files/folder in VS Code. If did not install VS Code through Homebrew, may have to manually add this to ~/.zprofile: `export PATH="/Applications/Visual Studio Code.app/Contents/Resources/app/bin:$PATH"`.
* Cmd+f - open find and replace. Can press buttons to make pattern case sensitive (insensitive by default) and match entire word. More powerfully, can press button to make pattern a regex pattern. Refer to captured groups in the "replace" box with e.g. `$1`, rather than `\1`.
* Alt+click - place additional cursor. Anything you type (inserts/deletes) will apply to all cursors simultaneously.
* Insert a 'wrapping' type of punctuation while have text selected - wraps the selected text. E.g. pressing `[` while `hello` is selected changes it to `[hello]`.
* Alt+up/down - swap current line with line before/after
* Alt+z: Toggle between views that wrap long lines vs let them run off the screen
* cmd+shift+o: Search for "symbols" (e.g. classes/methods/functions) within current file and jump to one. The symbols are indexed by the language server (e.g. Pylance), which is present if you have installed the appropriate extension.
* cmd+t: Like cmd+shift+o, but across entire repository. May be more picky (e.g. only show classes) unless specifically configure the language server.

### Thanks to extensions

* cmd+b - bold in .md files.
* cmd+i - italicise in .md files.
* alt+shift+f - format table in .md files.
* ... and more markdown conveniences.

Extensions are listed in `vscode-extensions.txt` and automatically installed by `./install.sh`.

## Maccy (clipboard history)

* Cmd+Shift+v - open clipboard history. Type to fuzzy search, navigate with up/down arrows, press enter to paste the chosen item (without formatting).

Maccy's settings are applied by `./copy.sh` with `defaults write` (see the Maccy section there).

# macOS

`./copy.sh` changes these from macOS's defaults (with `defaults write`, at the end of `copy.sh`). Most take effect at the next login.

* Ctrl+↑/↓ no longer open Mission Control / App Exposé, freeing them for other apps.
* Trackpad: tap to click, three-finger drag, four-finger swipes (up: Mission Control, down: App Exposé, left/right: spaces).
* Finder: show all file extensions, path bar, status bar, list view, delete items from the Bin after 30 days.
* Typing: no auto-capitalisation, no double-space full stop.
* Tab moves between all controls in dialogs.
* Screenshots save to Downloads.
* Clicking the wallpaper only shows the desktop in Stage Manager.
* No gaps between tiled windows.

# cmdlog

Every command run in an interactive shell is recorded by `cmdlog` (a Go program in `cmdlog/`, built into `~/.local/bin` by `./copy.sh`), along with when and where it ran, its exit status and its output. Ctrl+r in Zsh searches this history. I.e., `cmdlog` is my alternative to fzf's or atuin's own ctrl+r shortcut, which I found not sufficiently customisable.

* Recording works by running zsh under `cmdlog record`, which passes everything between the terminal and zsh through untouched. zsh's preexec/precmd hooks print invisible markers telling it where each command's output starts and ends (see the cmdlog section of `.zshrc`, and `cmdlog/marker.go`).
* The history is a SQLite database at `~/.local/share/cmdlog/history.db` (table `commands`), readable only by you. Query it directly with e.g. `sqlite3 ~/.local/share/cmdlog/history.db "select command, status from commands where dir = '$PWD'"`.
* Output from interactive programs (vim, fzf, a pager you scrolled through like `git log`...) isn't kept (but if they print anything after they exit, this is kept). Output short enough that the pager exits by itself (e.g. `git log -1`) is kept. Each command keeps at most the last 4MB of its output.
* Ctrl+r inserts the chosen command at the cursor, rather than replacing the command line, so e.g. `cmd1 && <ctrl+r>` can find cmd2 to follow cmd1. Therefore, unlike fzf's ctrl+r, the search starts empty, rather than with what's already typed. If prefer fzf's behaviour instead, drop commit 0692347.
* Ctrl+r can show commands with the same syntax highlighting as the command line. The ctrl+r widget points cmdlog (via `$CMDLOG_HIGHLIGHT`) at `.zsh/highlight-commands.zsh`, which runs zsh-syntax-highlighting with my settings from `.zsh/syntax-highlighting.zsh`, plus the shell's aliases, function names and options (saved by the widget). This takes about 2ms per command, so with a long history the list can take a moment to fill in (newest first). For better performance, the list starts uncoloured by default, with only the preview highlighted, which costs ~20ms per preview independent of history size. You can then choose to press ctrl+t to toggle whether the list is coloured. To start with it coloured, set `colour_rows=1` in .zshrc's `cmdlog-history-widget`.
* Errors are logged to `~/.local/share/cmdlog/errors.log`. If cmdlog can't record, the shell still starts, unrecorded. To stop recording entirely, delete `~/.local/bin/cmdlog`.
