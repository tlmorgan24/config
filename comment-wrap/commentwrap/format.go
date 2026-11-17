package commentwrap

import (
	"strings"
	"unicode"
)

// Options controls comment wrapping.
type Options struct {
	Width       int
	TabWidth    int
	MinColWidth int
}

// Comment describes a line comment found by a language-specific scanner.
type Comment struct {
	Line         int
	Column       int
	Content      string
	Standalone   bool
	LineContents string
}

// Style defines how wrapped comments are written.
type Style struct {
	Prefix string
}

type edit struct {
	first, last int
	replacement []string
}

// Format reflows comments. All replacements are computed against the original
// line numbers and then applied from bottom to top, so replacing one comment
// cannot invalidate the locations of comments that have not been applied yet.
func Format(lines []string, comments []Comment, style Style, options Options) []string {
	var edits []edit
	for i := 0; i < len(comments); {
		c := comments[i]
		if !c.Standalone {
			if e, ok := trailingEdit(c, style, options); ok {
				edits = append(edits, e)
			}
			i++
			continue
		}

		// A run is a sequence of standalone comments on consecutive lines whose
		// comment marks are aligned.
		indent := lineIndent(c.LineContents, c.Column)
		j := i
		for j+1 < len(comments) &&
			comments[j+1].Standalone &&
			comments[j+1].Line == comments[j].Line+1 &&
			lineIndent(comments[j+1].LineContents, comments[j+1].Column) == indent {
			j++
		}
		run := comments[i : j+1]
		i = j + 1
		if !hasText(run) {
			continue
		}
		edits = append(edits, edit{
			first:       run[0].Line,
			last:        run[len(run)-1].Line,
			replacement: formatRun(run, indent, style, options),
		})
	}

	for k := len(edits) - 1; k >= 0; k-- {
		e := edits[k]
		lines = replaceRange(lines, e.first, e.last, e.replacement)
	}
	return lines
}

func hasText(run []Comment) bool {
	for _, c := range run {
		if strings.TrimSpace(c.Content) != "" {
			return true
		}
	}
	return false
}

func trailingEdit(c Comment, style Style, options Options) (edit, bool) {
	content := strings.TrimSpace(c.Content)
	if content == "" {
		return edit{}, false
	}
	if displayWidth(strings.TrimRight(c.LineContents, "\r\n"), options) <= options.Width {
		return edit{}, false
	}
	prefix := lineIndent(c.LineContents, c.Column) + style.Prefix + commentIndent(c.Content)
	wrapped := wrapWithPrefix(content, prefix, options)
	code := strings.TrimRight(c.LineContents[:c.Column], " \t")
	return edit{first: c.Line, last: c.Line, replacement: append(wrapped, code)}, true
}

// Wrap breaks comment content into lines using the supplied comment style.
func Wrap(content, indent string, style Style, options Options) []string {
	return wrapWithPrefix(content, indent+style.Prefix+" ", options)
}

func wrapWithPrefix(content, prefix string, options Options) []string {
	avail := options.Width - displayWidth(prefix, options)
	lines := wrapText(strings.Fields(content), avail, avail, options)
	for i := range lines {
		lines[i] = prefix + lines[i]
	}
	return lines
}

// ---------------------------------------------------------------------------
// Parsing a run of comment lines
// ---------------------------------------------------------------------------

type cline struct {
	blank  bool
	lead   string // whitespace between the comment mark and the text
	rest   string // everything after lead (only the line ending removed)
	text   string // rest without trailing whitespace
	indent int    // display width of lead
	items  []string
	seps   []string
}

func parseLines(run []Comment, options Options) []cline {
	out := make([]cline, len(run))
	for i, c := range run {
		content := strings.TrimRight(c.Content, "\r\n")
		lead := leadingSpace(content)
		rest := content[len(lead):]
		text := strings.TrimRight(rest, " \t")
		ln := cline{lead: lead, rest: rest, text: text, blank: text == "", indent: displayWidth(lead, options)}
		if !ln.blank {
			ln.items, ln.seps = splitItems(text)
		}
		out[i] = ln
	}
	return out
}

// splitItems splits text on runs of 2+ whitespace characters (table-item
// separators). text must have no leading or trailing whitespace.
func splitItems(text string) (items, seps []string) {
	start := 0
	for i := 0; i < len(text); {
		if !isSpace(text[i]) {
			i++
			continue
		}
		j := i
		for j < len(text) && isSpace(text[j]) {
			j++
		}
		if j-i >= 2 {
			items = append(items, text[start:i])
			seps = append(seps, text[i:j])
			start = j
		}
		i = j
	}
	items = append(items, text[start:])
	return items, seps
}

type markerInfo struct {
	style     string
	prefixLen int // bytes of rest up to the first non-whitespace after the marker
}

// stdBullet recognises `- `, `* `, `(1) `, `1) ` and `1. `.
func stdBullet(rest string) (markerInfo, bool) {
	var style string
	var end int // index just after the marker, before its mandatory space
	switch {
	case strings.HasPrefix(rest, "- "):
		style, end = "-", 1
	case strings.HasPrefix(rest, "* "):
		style, end = "*", 1
	case strings.HasPrefix(rest, "("):
		d := digitsFrom(rest, 1)
		if d == 1 || d >= len(rest) || rest[d] != ')' {
			return markerInfo{}, false
		}
		style, end = "(n)", d+1
	default:
		d := digitsFrom(rest, 0)
		if d == 0 || d >= len(rest) || (rest[d] != '.' && rest[d] != ')') {
			return markerInfo{}, false
		}
		style, end = "n"+string(rest[d]), d+1
	}
	if end >= len(rest) || rest[end] != ' ' {
		return markerInfo{}, false
	}
	return markerInfo{style: style, prefixLen: skipSpace(rest, end+1)}, true
}

// wordBullet recognises a single word followed by `: ` or ` - `. It only
// applies inside a list introduced by a line ending in a colon.
func wordBullet(rest string) (markerInfo, bool) {
	tokEnd := strings.IndexAny(rest, " \t")
	if tokEnd <= 0 {
		return markerInfo{}, false
	}
	tok := rest[:tokEnd]
	switch {
	case len(tok) > 1 && strings.HasSuffix(tok, ":"):
		return markerInfo{style: "word:", prefixLen: skipSpace(rest, tokEnd)}, true
	case strings.HasPrefix(rest[tokEnd:], " - "):
		return markerInfo{style: "word-", prefixLen: skipSpace(rest, tokEnd+3)}, true
	}
	return markerInfo{}, false
}

func digitsFrom(s string, start int) int {
	for start < len(s) && s[start] >= '0' && s[start] <= '9' {
		start++
	}
	return start
}

func skipSpace(s string, i int) int {
	for i < len(s) && isSpace(s[i]) {
		i++
	}
	return i
}

func isSpace(b byte) bool { return b == ' ' || b == '\t' }

// ---------------------------------------------------------------------------
// Grouping lines into logical blocks
// ---------------------------------------------------------------------------

type blockKind int

const (
	kBlank blockKind = iota
	kProse
	kBullet
	kTable
)

type tableRow struct {
	cells []string // every item except the last
	seps  []string
	words []string // the last item plus any continuation lines
}

type block struct {
	kind   blockKind
	lead   string // whitespace after the comment mark, first line
	indent int    // display width of lead
	words  []string

	// Bullets. marker is what precedes the text on the first line (including
	// the gap); contPad is how far continuation lines are indented relative to
	// lead. textLevel is the absolute indent continuation lines must have to be
	// recognised as part of this bullet.
	marker    string
	contPad   int
	textLevel int

	// Tables.
	count int
	rows  []*tableRow
}

// listCtx is a list introduced by a line ending in a colon followed by a more
// indented line.
type listCtx struct {
	introIndent, listIndent int
	style                   string // "-", "*", "(n)", "n)", "n.", "word:", "word-" or "ws"
}

func (l *listCtx) matches(ln cline) bool {
	sb, isStd := stdBullet(ln.rest)
	wb, isWord := wordBullet(ln.rest)
	switch l.style {
	case "ws":
		return !isStd && !isWord
	case "word:", "word-":
		return !isStd && isWord && wb.style == l.style
	default:
		return isStd && sb.style == l.style
	}
}

// tableAhead reports whether line i, which has 2+ items, is the first row of a
// table, i.e. whether another row with the same indent and item count follows
// it (possibly after continuation lines, which are more indented).
func tableAhead(cl []cline, i int) bool {
	base := cl[i]
	for j := i + 1; j < len(cl); j++ {
		l := cl[j]
		if l.blank {
			return false
		}
		if _, ok := stdBullet(l.rest); ok {
			return false
		}
		if l.indent > base.indent {
			continue
		}
		return l.indent == base.indent && len(l.items) == len(base.items)
	}
	return false
}

// listStyleAt works out the style of a list whose first line is cl[k]. ok is
// false if the first line is the start of a table, in which case no list
// context is needed.
func listStyleAt(cl []cline, k int) (style string, ok bool) {
	if sb, isStd := stdBullet(cl[k].rest); isStd {
		return sb.style, true
	}
	if wb, isWord := wordBullet(cl[k].rest); isWord {
		return wb.style, true
	}
	if len(cl[k].items) >= 2 && tableAhead(cl, k) {
		return "", false
	}
	return "ws", true
}

func scan(cl []cline, options Options) []*block {
	var blocks []*block
	var cur *block
	var lists []*listCtx

	newBlock := func(b *block) {
		blocks = append(blocks, b)
		cur = b
	}

	for i, ln := range cl {
		if ln.blank {
			newBlock(&block{kind: kBlank})
			cur, lists = nil, nil
			continue
		}
		I := ln.indent

		// Lists end at a line that is less indented than the list, or that is at
		// the list's indent but not in its style.
		for len(lists) > 0 {
			top := lists[len(lists)-1]
			if I < top.listIndent || (I == top.listIndent && !top.matches(ln)) {
				lists = lists[:len(lists)-1]
				continue
			}
			break
		}
		var top *listCtx
		if len(lists) > 0 {
			top = lists[len(lists)-1]
		}

		sb, isStd := stdBullet(ln.rest)
		wb, isWord := wordBullet(ln.rest)
		wordInList := top != nil && I == top.listIndent && isWord &&
			(top.style == "word:" || top.style == "word-")

		switch {
		case isStd: // 1. standard bullets
			newBlock(newBullet(ln, sb, options))
		case wordInList: // 2. word bullets (only inside an intro list)
			newBlock(newBullet(ln, wb, options))
		case cur != nil && cur.kind == kBullet && I == cur.textLevel:
			// Continuation of the nearest bullet above.
			cur.words = append(cur.words, strings.Fields(ln.text)...)
		case cur != nil && cur.kind == kTable && I == cur.indent && len(ln.items) == cur.count:
			cur.addRow(ln)
		case cur != nil && cur.kind == kTable && I > cur.indent:
			// Continuation of the last column of the row above.
			last := cur.rows[len(cur.rows)-1]
			last.words = append(last.words, strings.Fields(ln.text)...)
		case len(ln.items) >= 2 && tableAhead(cl, i): // 3. tables
			t := &block{kind: kTable, lead: ln.lead, indent: I, count: len(ln.items)}
			t.addRow(ln)
			newBlock(t)
		case top != nil && top.style == "ws" && I == top.listIndent: // 4. whitespace bullets
			delta := top.listIndent - top.introIndent
			newBlock(&block{
				kind: kBullet, lead: ln.lead, indent: I,
				contPad: delta, textLevel: I + delta,
				words: strings.Fields(ln.text),
			})
		case cur != nil && cur.kind == kProse && cur.indent == I: // 5. prose
			cur.words = append(cur.words, strings.Fields(ln.text)...)
		default:
			newBlock(&block{kind: kProse, lead: ln.lead, indent: I, words: strings.Fields(ln.text)})
		}

		// A line ending in a colon, followed by a more indented line, introduces a
		// list. A non-bullet line at the text level of a bullet is a continuation
		// of that bullet instead, so it does not start a list.
		if cur.kind != kTable && strings.HasSuffix(ln.text, ":") && i+1 < len(cl) {
			next := cl[i+1]
			if !next.blank && next.indent > I {
				_, nextStd := stdBullet(next.rest)
				continuation := cur.kind == kBullet && next.indent == cur.textLevel && !nextStd
				if style, ok := listStyleAt(cl, i+1); ok && !continuation {
					lists = append(lists, &listCtx{introIndent: I, listIndent: next.indent, style: style})
				}
			}
		}
	}
	return blocks
}

func newBullet(ln cline, mi markerInfo, options Options) *block {
	marker := ln.rest[:mi.prefixLen]
	text := ln.rest[mi.prefixLen:]
	if strings.TrimSpace(text) == "" {
		marker = strings.TrimRight(marker, " \t") + " "
	}
	cols := displayWidth(marker, options)
	return &block{
		kind: kBullet, lead: ln.lead, indent: ln.indent,
		marker: marker, contPad: cols, textLevel: ln.indent + cols,
		words: strings.Fields(text),
	}
}

func (b *block) addRow(ln cline) {
	n := len(ln.items)
	b.rows = append(b.rows, &tableRow{
		cells: ln.items[:n-1],
		seps:  ln.seps,
		words: strings.Fields(ln.items[n-1]),
	})
}

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------

func formatRun(run []Comment, indentStr string, style Style, options Options) []string {
	prefix := indentStr + style.Prefix
	prefixCols := displayWidth(prefix, options)
	var out []string
	for _, b := range scan(parseLines(run, options), options) {
		switch b.kind {
		case kBlank:
			out = append(out, prefix)
		case kProse:
			avail := options.Width - prefixCols - b.indent
			for _, l := range wrapText(b.words, avail, avail, options) {
				out = append(out, prefix+b.lead+l)
			}
		case kBullet:
			out = append(out, b.renderBullet(prefix, prefixCols, options)...)
		case kTable:
			out = append(out, b.renderTable(prefix, prefixCols, options)...)
		}
	}
	return out
}

func (b *block) renderBullet(prefix string, prefixCols int, options Options) []string {
	if len(b.words) == 0 {
		return []string{prefix + b.lead + b.marker}
	}
	firstAvail := options.Width - prefixCols - b.indent - displayWidth(b.marker, options)
	contAvail := options.Width - prefixCols - b.indent - b.contPad
	contLead := b.lead + spaces(b.contPad)
	var out []string
	for i, l := range wrapText(b.words, firstAvail, contAvail, options) {
		if i == 0 {
			out = append(out, prefix+b.lead+b.marker+l)
		} else {
			out = append(out, prefix+contLead+l)
		}
	}
	return out
}

func (b *block) renderTable(prefix string, prefixCols int, options Options) []string {
	cols := b.count - 1
	colW := make([]int, cols)
	sum := 0
	for k := 0; k < cols; k++ {
		for _, r := range b.rows {
			if w := displayWidth(r.cells[k], options) + displayWidth(r.seps[k], options); w > colW[k] {
				colW[k] = w
			}
		}
		sum += colW[k]
	}
	avail := options.Width - prefixCols - b.indent - sum
	if avail < options.MinColWidth {
		avail = options.MinColWidth
	}
	contLead := b.lead + spaces(sum)

	var out []string
	for _, r := range b.rows {
		var sb strings.Builder
		sb.WriteString(prefix)
		sb.WriteString(b.lead)
		for k := 0; k < cols; k++ {
			sb.WriteString(r.cells[k])
			sb.WriteString(spaces(colW[k] - displayWidth(r.cells[k], options)))
		}
		lines := wrapText(r.words, avail, avail, options)
		if len(lines) == 0 {
			lines = []string{""}
		}
		out = append(out, strings.TrimRight(sb.String()+lines[0], " \t"))
		for _, l := range lines[1:] {
			out = append(out, prefix+contLead+l)
		}
	}
	return out
}

// wrapText greedily fills lines of at most firstAvail (first line) and
// contAvail (other lines) columns. Words are never split, so a word wider than
// the line gets a line of its own. A line is never started with a word that
// would make it look like the start of a new bullet; the break moves to
// another word instead.
func wrapText(words []string, firstAvail, contAvail int, options Options) []string {
	if firstAvail < 1 {
		firstAvail = 1
	}
	if contAvail < 1 {
		contAvail = 1
	}
	var lines []string
	for i := 0; i < len(words); {
		avail := contAvail
		if len(lines) == 0 {
			avail = firstAvail
		}
		j, w := i, 0
		for j < len(words) {
			ww := displayWidth(words[j], options)
			if j > i && w+1+ww > avail {
				break
			}
			if j > i {
				w++
			}
			w += ww
			j++
		}
		if j < len(words) && looksLikeBullet(words, j) {
			k := j - 1
			for k > i && looksLikeBullet(words, k) {
				k--
			}
			if k > i {
				j = k
			} else {
				// Cannot break earlier: keep the marker on this line (overfull).
				j++
				for j < len(words) && looksLikeBullet(words, j) {
					j++
				}
			}
		}
		lines = append(lines, strings.Join(words[i:j], " "))
		i = j
	}
	return lines
}

// looksLikeBullet reports whether a line starting with words[b] would be read
// as a standard bullet (a marker followed by more text).
func looksLikeBullet(words []string, b int) bool {
	if b+1 >= len(words) {
		return false
	}
	_, ok := stdBullet(words[b] + " x")
	return ok
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

func spaces(n int) string {
	if n < 0 {
		n = 0
	}
	return strings.Repeat(" ", n)
}

func leadingSpace(s string) string {
	return s[:len(s)-len(strings.TrimLeft(s, " \t"))]
}

func lineIndent(line string, column int) string {
	beforeComment := line
	if column > 0 {
		beforeComment = line[:column]
	}
	return leadingSpace(beforeComment)
}

func commentIndent(content string) string {
	return leadingSpace(content)
}

// displayWidth measures s in terminal columns: a tab counts as the configured
// tab width, combining and format characters as 0, East Asian wide characters 
// and emoji as 2, everything else as 1.
func displayWidth(s string, options Options) int {
	w := 0
	for _, r := range s {
		switch {
		case r == '\t':
			w += options.TabWidth
		case r < 0x20 || r == 0x7f:
		case unicode.In(r, unicode.Mn, unicode.Me, unicode.Cf):
		case isWide(r):
			w += 2
		default:
			w++
		}
	}
	return w
}

func isWide(r rune) bool {
	switch {
	case r >= 0x1100 && r <= 0x115F,
		r >= 0x2E80 && r <= 0x303E,
		r >= 0x3041 && r <= 0x33FF,
		r >= 0x3400 && r <= 0x4DBF,
		r >= 0x4E00 && r <= 0x9FFF,
		r >= 0xA000 && r <= 0xA4CF,
		r >= 0xAC00 && r <= 0xD7A3,
		r >= 0xF900 && r <= 0xFAFF,
		r >= 0xFE30 && r <= 0xFE4F,
		r >= 0xFF00 && r <= 0xFF60,
		r >= 0xFFE0 && r <= 0xFFE6,
		r >= 0x1F300 && r <= 0x1F64F,
		r >= 0x1F900 && r <= 0x1F9FF,
		r >= 0x20000 && r <= 0x3FFFD:
		return true
	}
	return false
}

// replaceRange replaces lines[first..last] with replacement, giving each new
// line the line ending of the original range (the last new line takes the
// ending of the last original line, so a missing final newline stays missing).
func replaceRange(lines []string, first, last int, replacement []string) []string {
	mid := LineEnding(lines[first])
	if mid == "" {
		mid = "\n"
		if first > 0 {
			if e := LineEnding(lines[first-1]); e != "" {
				mid = e
			}
		}
	}
	end := LineEnding(lines[last])
	for i := range replacement {
		if i == len(replacement)-1 {
			replacement[i] += end
		} else {
			replacement[i] += mid
		}
	}
	tail := append([]string(nil), lines[last+1:]...)
	return append(append(lines[:first], replacement...), tail...)
}

func ReplaceLine(lines []string, line int, replacement []string, ending string) []string {
	return ReplaceLines(lines, line, line, replacement, ending)
}

func ReplaceLines(lines []string, firstLine, lastLine int, replacement []string, ending string) []string {
	for i := range replacement {
		replacement[i] += ending
	}
	return append(lines[:firstLine], append(replacement, lines[lastLine+1:]...)...)
}

func LineEnding(line string) string {
	if strings.HasSuffix(line, "\r\n") {
		return "\r\n"
	}
	if strings.HasSuffix(line, "\n") {
		return "\n"
	}
	return ""
}
