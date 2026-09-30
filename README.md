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

## My shortcuts

The keybinding I choose is either the most standard one for the intended behaviour (maximising the likelihood it will be properly interpreted by various programs, therefore minimising amount of program-specific config required), or the one already used by Ghostty & VS Code (presumably with the same reason in mind).

In the table, I specify whether the keybinding is already used by the terminal (Ghostty / VS Code) by default or if I custom-specified it. I also specify whether the keybinding used is responded to by the program (Zsh) with the intended behaviour by default or if I wrote a custom function for it.

| Shortcut | Intended behaviour | Keybinding used | Other popular bindings  | Ghostty | VS Code | Zsh |
| --- | --- | --- | --- | --- | --- | --- |
| Type a printable ASCII character | (1) If text is selected, erase that text (2) Insert the character | N/A | N/A | N/A | N/A | Default satisfies (2), wrote custom function to additionally satisfy (1) |
| ← | (1) If nothing selected, move back one character (2) Else, cancel selection | `\e[D` | `^B` | Default | Default | Default satisfies (1), wrote custom function to additionally satisfy (2) |
| →  | (1) If nothing selected, move forward one character (2) Else, cancel selection | `\e[C` | `^F` | Default | Default | Default satisfies (1), wrote custom function to additionally satisfy (2) |
| Alt + ← | Move back one word | `\eB` | `^B` | Default | Default | Default |
| Alt + →  | Move forward one word | `\eF` | `^F` | Default | Default | Default |
| Cmd + ← | Move to start of line | `^A` |  | Default | Default | Default |
| Cmd + →  | Move to end of line | `^E` |  | Default | Default | Default |
| ⌫ | (1) If nothing selected, delete the character before cursor (2) Else, delete the selected text. | `^?` | `^H` | Default | Default | Default satisfies (1), wrote custom function to additionally satisfy (2) |
| fn + ⌫ | Delete character under cursor (i.e., after cursor, if cursor is a thin line rather than block) | `\e[3~` | `^D` | Default | Default | Default |
| Alt + ⌫ | Delete back to start of word | `\e^?` | `^W` | Default | Default | Default |
| Cmd + ⌫ | Delete back to start of line | `^U` |  | Default | Default | Custom |
| Shift + ← | Expand selection left by one character | `\e[1;2D` |  | Default | Default | Custom |
| Shift + → | Expand selection right by one character | `\e[1;2C` |  | Default | Default | Custom |
| Alt + Shift + ← | Expand selection to start of word | `\e[1;4D` |  | Default | Default | Custom |
| Alt + Shift + → | Expand selection to end of word | `\e[1;4C` |  | Default | Default | Custom |
| Cmd + Shift + ← | Expand selection to start of line | `\e[1;10D` |  | Default | Custom | Custom |
| Cmd + Shift + → | Expand selection to end of line | `\e[1;10C` |  | Default | Custom | Custom |
| Cmd + C | Copy selection to clipboard | `\e[99;9u` |  | Custom bound to Cmd + Shift + C (see below) | Custom bound to Cmd + Shift + C (see below) | Custom |
| Cmd + X | Cut selection (i.e. delete and copy to clipboard) | `\e[120;9u` |  | Custom | Custom | Custom |
| Cmd + P | (1) If text is selected, delete the selected text (2) Then, paste from clipboard. |  |  |  |  | Default (not sure specifically how Ghostty / VS Code handle it, but whatever it is they do, it ends up working exactly as desired in Zsh) |
| Cmd + Z | Undo | `^_` |  | Custom | Custom | Default |
| Cmd + Shift + Z | Redo | `^[/` |  | Custom | Custom | Mapped existing function to respond as desired |

Note all selections refer to the PROGRAM’s selection (as manipulated by the above shortcuts), rather than TERMINAL’s selection (e.g. from mouse drag). Both Ghostty and VS Code use Cmd + C to copy the terminal’s selection, so I am forced to use Cmd + Shift + C to copy terminal’s selection. There is no way to merge the behaviours, because the program (e.g. Zsh) cannot know what/when the terminal (e.g. Ghostty) has highlighted text, and vice versa.