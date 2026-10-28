package main

import (
	"slices"
	"strings"
	"unicode/utf8"
)

// Private modes (as in ESC [ ? <mode> h/l) that only interactive programs turn on: the alternate screen (vim, less,
// htop...), mouse tracking, and bracketed paste (anything reading keyboard input itself, e.g. fzf even when not
// full-screen; zsh turns it on too, but only while editing the command line, never during a command). What such a
// program draws is a sequence of screen updates rather than readable output, so it isn't kept.
var interactiveModes = []string{"47", "1047", "1049", "1000", "1002", "1003", "2004"}

// Application cursor keys mode (changes what the arrow keys send) is turned on by programs that read the arrow keys,
// such as less as git's pager. But less turns it on even when the output fits on one screen and it exits straight away,
// so it only counts as interactive if keys were pressed while the command ran (e.g. to scroll, or q to quit).
const cursorKeysMode = "1"

// token is one printable character, or one colour (SGR) escape sequence.
type token struct {
	s         string
	printable bool
}

// cleanOutput turns a command's raw terminal output into text worth storing:
//   - Colour codes are kept (in `colored` only), every other escape sequence is removed.
//   - A carriage return not followed by a newline restarts the line, so a progress bar keeps only its final state.
//   - Backspaces delete the previous character (as used by e.g. man pages for bold/underline).
//   - If an interactive program ran, only the output after it last exited is kept, and interactive is true.
//
// keysPressed says whether anything was typed while the command ran (see cursorKeysMode).
func cleanOutput(raw []byte, keysPressed bool) (colored, plain string, interactive bool) {
	var coloredOut, plainOut strings.Builder
	var line []token

	endLine := func() {
		for _, t := range line {
			coloredOut.WriteString(t.s)
			if t.printable {
				plainOut.WriteString(t.s)
			}
		}
		line = line[:0]
	}

	for i := 0; i < len(raw); {
		b := raw[i]
		switch {
		case b == 0x1b:
			n, seq := escapeSequence(raw[i:])
			i += n
			switch {
			case seq == "":
			case strings.HasSuffix(seq, "m"): // Colour
				line = append(line, token{s: seq})
			case strings.HasPrefix(seq, "\x1b[?") && (strings.HasSuffix(seq, "h") || strings.HasSuffix(seq, "l")):
				for mode := range strings.SplitSeq(seq[3:len(seq)-1], ";") {
					if slices.Contains(interactiveModes, mode) || (mode == cursorKeysMode && keysPressed) {
						interactive = true
						if strings.HasSuffix(seq, "l") { // Program exiting, so discard everything it (or anything before it) drew.
							coloredOut.Reset()
							plainOut.Reset()
							line = line[:0]
						}
					}
				}
			case seq == "\x1b[G" || seq == "\x1b[1G" || seq == "\x1b[0G": // Move to column 1, same as \r.
				line = line[:0]
			}
		case b == '\r':
			if i+1 < len(raw) && raw[i+1] == '\n' { // The terminal's normal line ending, handled by '\n'
				i++
				continue
			}
			line = line[:0]
			i++
		case b == '\n':
			endLine()
			coloredOut.WriteByte('\n')
			plainOut.WriteByte('\n')
			i++
		case b == '\b':
			if n := len(line); n > 0 && line[n-1].printable {
				line = line[:n-1]
			}
			i++
		case b == '\t':
			line = append(line, token{s: "\t", printable: true})
			i++
		case b < 0x20 || b == 0x7f: // Other control characters (e.g. BEL)
			i++
		default:
			r, size := utf8.DecodeRune(raw[i:])
			line = append(line, token{s: string(r), printable: true})
			i += size
		}
	}
	endLine()

	colored = strings.TrimRight(coloredOut.String(), "\n")
	plain = strings.TrimRight(plainOut.String(), "\n")
	if strings.Contains(colored, "\x1b[") {
		colored += "\x1b[0m" // Don't let a colour leak past the end of the output.
	}
	return colored, plain, interactive
}

// escapeSequence returns the length of the escape sequence at the start of b (which begins with ESC), and the sequence
// itself if it is a CSI sequence (ESC [ ...), which is the only kind the caller inspects.
func escapeSequence(b []byte) (int, string) {
	if len(b) < 2 {
		return len(b), ""
	}
	switch b[1] {
	case '[': // CSI: parameter bytes, then intermediate bytes, then one final byte
		j := 2
		for j < len(b) && b[j] >= 0x20 && b[j] <= 0x3f {
			j++
		}
		if j < len(b) && b[j] >= 0x40 && b[j] <= 0x7e {
			return j + 1, string(b[:j+1])
		}
		return j, ""
	case ']', 'P', '_', '^', 'X': // OSC, DCS, APC, PM, SOS: a string ended by BEL or ESC \
		for j := 2; j < len(b); j++ {
			if b[j] == '\a' {
				return j + 1, ""
			}
			if b[j] == 0x1b && j+1 < len(b) && b[j+1] == '\\' {
				return j + 2, ""
			}
		}
		return len(b), ""
	case '(', ')', '*', '+': // Character set designation, e.g. ESC ( B
		return min(3, len(b)), ""
	default:
		return 2, ""
	}
}
