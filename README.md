# How to use

1. Clone this repo
2. Run `./install.sh` to install the tools I use and add them to PATH
3. Run `./copy.sh` to copy the associated config files into their appropriate places in your home directory (assumes same structure as on my mac). WARNING: the sync will overwrite any file that already exists at the same filepath. If you have parts of an existing config file you want to preserve, copy them into the repo files before running this script.

E.g.:
```bash
git clone https://github.com/tlmorgan24/config.git
cd config
chmod +x ./install.sh
./install.sh
chmod +x ./copy.sh
./copy.sh
cd ..
rm -r config
```

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
| ⌫ | `^?` | `^H` | Default | Default | (1) If nothing selected, delete the character before cursor (2) Else, delete the selected text. | Default satisfies (1), wrote custom function to additionally satisfy (2) | Delete character before cursor in INSERT mode, delete selection in VISUAL mode | Default |
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
| Cmd + Shift + c | `\e[99;9u` |  | Custom | Custom | Copy program's selection to clipboard | Custom | No effect | Default |
| Cmd + x | `\e[120;9u` |  | Custom | Custom | Cut selection (i.e. delete and copy to clipboard) | Custom | No effect | Default |
| Cmd + v | | | | | (1) If text is selected, delete the selected text (2) Then, paste from clipboard. | Default (not sure specifically how Ghostty / VS Code handle it, but whatever it is they do, it ends up working exactly as desired in Zsh) | Paste from clipboard in INSERT mode | Default |
| Cmd + z | `^_` |  | Custom | Custom | Undo | Default | Undo | Custom |
| Cmd + Shift + z | `^[/` |  | Custom | Custom | Redo | Mapped existing function to respond as desired | Redo | Custom |

Note all selections refer to the PROGRAM's selection (e.g. as manipulated by above shortcuts), rather than TERMINAL's selection (e.g. from mouse drag in most situations). Both Ghostty and VS Code use Cmd+c to copy the terminal's selection, so I am forced to use Cmd+Shift+c if wanting to copy the program's selection. There is no way to merge the behaviours, because the program (e.g. Zsh) cannot know what/when the terminal (e.g. Ghostty) has highlighted text, and vice versa.

## Other shortcuts

### Vim

* Mouse click -	move cursor
* Mouse drag - enter visual mode and select dragged-over region
* Shift + mouse drag - terminal selection (rather than vim selection), copyable to clipboard with cmd+c