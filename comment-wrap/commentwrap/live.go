package commentwrap

import (
	"strings"
	"unicode"
	"unicode/utf16"
	"unicode/utf8"
)

// Position uses the editor's zero-based lines and UTF-16 character offsets.
type Position struct {
	Line      int `json:"line"`
	Character int `json:"character"`
}

// LiveResult describes one logical paragraph and, when needed, a replacement
// for the active part of it. Protected boundaries divide a paragraph only for
// editing; they do not change the parser's list or table context.
type LiveResult struct {
	First int       `json:"first"`
	Last  int       `json:"last"`
	Edit  *LiveEdit `json:"edit,omitempty"`
}

type LiveEdit struct {
	First  int      `json:"first"`
	Last   int      `json:"last"`
	Text   string   `json:"text"`
	Cursor Position `json:"cursor"`
}

// Live reuses the document formatter's scanner and renderer, but touches only
// the block containing cursor. Code, directives, trailing comments and empty
// comments are never rewritten. A protected line starts a new editing segment.
func Live(source string, comments []Comment, style Style, options Options, cursor Position, protected []int) *LiveResult {
	lines := strings.Split(source, "\n")
	for i := range lines {
		lines[i] = strings.TrimSuffix(lines[i], "\r")
	}
	for i := 0; i < len(comments); {
		start := i
		c := comments[i]
		i++
		if !c.Standalone {
			continue
		}
		indent := lineIndent(c.LineContents, c.Column)
		for i < len(comments) && comments[i].Standalone && comments[i].Line == comments[i-1].Line+1 && lineIndent(comments[i].LineContents, comments[i].Column) == indent {
			i++
		}
		run := comments[start:i]
		if cursor.Line < c.Line || cursor.Line > run[len(run)-1].Line {
			continue
		}
		parsed := parseLines(run, options)
		blocks := scan(parsed, options)
		for bi, b := range blocks {
			first, last := c.Line+b.first, c.Line+b.last
			if cursor.Line < first || cursor.Line > last {
				continue
			}
			result := &LiveResult{First: first, Last: last}
			for _, cut := range protected {
				if cut == last+1 && b.last+1 < len(parsed) && parsed[b.last+1].blank {
					result.Last = cut
				}
				if cut == first && b.kind == kBlank && bi > 0 {
					result.First = c.Line + blocks[bi-1].first
				}
			}
			if b.kind == kBlank {
				return result
			}
			prefix := indent + style.Prefix
			column := byteColumn(lines[cursor.Line], cursor.Character)
			// Editing indentation or a comment marker must not trigger normalization.
			if column < len(prefix)+len(leadingSpace(strings.TrimPrefix(lines[cursor.Line], prefix))) {
				return result
			}
			lo, hi := b.first, b.last
			for _, line := range protected {
				cut := line - c.Line
				if cut > lo && cut <= cursor.Line-c.Line {
					lo = cut
				}
				if cut > cursor.Line-c.Line && cut <= hi {
					hi = cut - 1
				}
			}
			part := *b
			if lo != b.first || hi != b.last {
				// Table alignment requires the complete table; defer it while a boundary
				// within it is protected rather than accidentally joining across it.
				if b.kind == kTable {
					return result
				}
				part.words = nil
				for j := lo; j <= hi; j++ {
					text := parsed[j].text
					if j == b.first && b.kind == kBullet {
						if b.ownLine {
							continue
						}
						text = strings.TrimPrefix(text, b.marker)
						// A bare standard marker has a synthesized trailing space.
						if len(b.words) > 0 && strings.TrimSpace(text) == strings.TrimSpace(b.marker) {
							continue
						}
					}
					part.words = append(part.words, strings.Fields(text)...)
				}
				if lo > b.first {
					part.kind = kProse
					part.lead = b.lead
					if b.kind == kBullet {
						if b.ownLine {
							part.lead = b.cLead
						} else {
							part.lead += spaces(b.contPad)
						}
					}
					part.indent = displayWidth(part.lead, options)
				}
			}
			replacement := part.render(prefix, displayWidth(prefix, options), options)
			first, last = c.Line+lo, c.Line+hi
			original := lines[first : last+1]
			replacement, mapped, ok := liveCursor(original, replacement, prefix, Position{cursor.Line - first, cursor.Character}, b.kind != kTable)
			if !ok {
				return result
			}
			eol := "\n"
			if strings.Contains(source, "\r\n") {
				eol = "\r\n"
			}
			text := strings.Join(replacement, eol)
			if text != strings.Join(original, eol) {
				mapped.Line += first
				result.Edit = &LiveEdit{First: first, Last: last, Text: text, Cursor: mapped}
			}
			return result
		}
	}
	return nil
}

func byteColumn(line string, character int) int {
	units := 0
	for i, r := range line {
		if units >= character {
			return i
		}
		units += utf16.RuneLen(r)
	}
	return len(line)
}

type liveChar struct {
	r          rune
	start, end int
}

// Flatten only the comment content: prefixes are structural, never characters
// to count when following a cursor through inserted and removed line breaks.
func liveText(lines []string, prefix string) (string, []liveChar) {
	content := make([]string, len(lines))
	for i, line := range lines {
		content[i] = strings.TrimPrefix(line, prefix)
	}
	text := strings.Join(content, "\n")
	var chars []liveChar
	for i, r := range text {
		if !unicode.IsSpace(r) {
			chars = append(chars, liveChar{r, i, i + utf8.RuneLen(r)})
		}
	}
	return text, chars
}

func liveCursor(original, replacement []string, prefix string, cursor Position, preserveGap bool) ([]string, Position, bool) {
	before, oldChars := liveText(original, prefix)
	after, newChars := liveText(replacement, prefix)
	if len(oldChars) != len(newChars) {
		return nil, Position{}, false
	}
	for i, c := range oldChars {
		if c.r != newChars[i].r {
			return nil, Position{}, false
		}
	}
	at := byteColumn(original[cursor.Line], cursor.Character) - len(prefix)
	for _, line := range original[:cursor.Line] {
		at += len(strings.TrimPrefix(line, prefix)) + 1
	}
	if at < 0 || at > len(before) {
		return nil, Position{}, false
	}
	n := 0
	for n < len(oldChars) && oldChars[n].end <= at {
		n++
	}
	oldEnd, newEnd := 0, 0
	if n > 0 {
		oldEnd, newEnd = oldChars[n-1].end, newChars[n-1].end
	}
	// Inside a multibyte character is not a valid editor caret position.
	if n < len(oldChars) && at > oldChars[n].start {
		return nil, Position{}, false
	}
	mapped := newEnd
	if at > oldEnd {
		oldNext, newNext := len(before), len(after)
		if n < len(oldChars) {
			oldNext, newNext = oldChars[n].start, newChars[n].start
		}
		gap := before[oldEnd:oldNext]
		outputGap := after[newEnd:newNext]
		firstNewline := strings.IndexByte(gap, '\n')
		if !preserveGap && n < len(oldChars) {
			// Follow the next cell or word through table alignment, including
			// when the cursor was inside padding that has been removed.
			mapped = newNext
		} else if firstNewline >= 0 && at-oldEnd <= firstNewline {
			// The caret is in trailing horizontal whitespace before an
			// existing newline. Preserve that typing gap on this line, even
			// when a marker intentionally keeps its content on the next one.
			horizontal := gap[:firstNewline]
			outputNewline := strings.IndexByte(outputGap, '\n')
			if outputNewline >= 0 {
				after = after[:newEnd] + horizontal + after[newEnd+outputNewline:]
			} else {
				after = after[:newEnd] + horizontal + after[newNext:]
			}
			mapped = newEnd + (at - oldEnd)
		} else if !strings.ContainsAny(gap, "\r\n") && !strings.ContainsAny(outputGap, "\r\n") {
			// Preserve the horizontal gap being edited, including a newly typed space
			// at the end of a paragraph.
			after = after[:newEnd] + gap + after[newNext:]
			mapped = newEnd + (at - oldEnd)
		} else {
			// A space became a line break. Continue at the next word, after its prefix
			// and indentation, so the next typed character cannot damage the marker.
			mapped = newNext
		}
	}
	content := strings.Split(after, "\n")
	line := strings.Count(after[:mapped], "\n")
	start := strings.LastIndex(after[:mapped], "\n") + 1
	character := len(utf16.Encode([]rune(prefix + after[start:mapped])))
	for i := range content {
		content[i] = prefix + content[i]
	}
	return content, Position{line, character}, true
}
