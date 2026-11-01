package main

import (
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"regexp"
	"strconv"
	"strings"
	"syscall"
	"unicode"
	"unicode/utf8"

	"golang.org/x/sys/unix"
	"golang.org/x/term"
)

// Colours from FZF_DEFAULT_OPTS in .zshrc (Catppuccin Mocha), so this looks like my fzf-based `switch` and `checkout`.
var (
	bg          = bgColour("#1e1e2e")
	bgCursor    = bgColour("#313244")
	bgPartner   = bgColour("#282839") // The other copy of the cursor's commit, when it's being moved
	text        = fgColour("#cdd6f4")
	dim         = fgColour("#6c7086")
	border      = fgColour("#585b70")
	pointer     = fgColour("#f38ba8")
	keyHint     = fgColour("#89b4fa")
	hash        = fgColour("#f9e2af")
	pushed      = fgColour("#f38ba8") // Red, like origin branches in display-logs
	refs        = fgColour("#94e2d5")
	errText     = fgColour("#f38ba8")
	ontoLabel   = fgColour("#89dceb")
	cutoffLabel = fgColour("#f5c2e7")
	arrow       = fgColour("#a6e3a1") // As pick, the moved commits' usual action

	actionColours = map[string]string{
		"pick":   fgColour("#a6e3a1"),
		"reword": fgColour("#89b4fa"),
		"edit":   fgColour("#f9e2af"),
		"squash": fgColour("#cba6f7"),
		"fixup":  fgColour("#fab387"),
		"drop":   fgColour("#f38ba8"),
	}
)

const tabWidth = 2 // As --tabstop in FZF_DEFAULT_OPTS

// help is the key and description of each item in the help shown under the summary.
var help = []struct{ key, desc string }{
	{"p", "pick"}, {"r", "reword"}, {"e", "edit"}, {"s", "squash"}, {"f", "fixup"}, {"d", "drop"}, {"u", "unmark"},
	{"b", "base"}, {"c", "cutoff"}, {"⌥↑/↓", "move"}, {"⇧↑/↓", "scroll preview"}, {"enter", "rebase"}, {"esc", "quit"},
}

type ui struct {
	p       *plan
	h       *history
	v       *preview
	rows    []row // The history as it will be once rebased
	limit   int   // How many commits to load into rows
	more    bool  // Whether there are more commits than rows has
	cursor  int   // Index of the row the cursor is on, which always has a commit
	offset  int   // Index of the row at the top of the list
	width   int
	height  int
	status  string              // Error shown in place of the summary until the next key
	scroll  int                 // Lines of the preview scrolled past
	preview map[string][]string // Each commit's preview lines by hash (nil while git is still producing them)
	events  chan func(*ui)      // Updates from other goroutines, applied by the main loop
	wake    *os.File            // Written to after sending an event, to wake the main loop up
}

// choose shows the history for the user to arrange, and returns the todo list of the rebase they confirm and what it
// goes onto and stops at (see rebase), or an empty todo list if they quit.
func choose(p *plan, h *history) (todo, onto, cutoff string, err error) {
	in, out := int(os.Stdin.Fd()), int(os.Stdout.Fd())
	if !term.IsTerminal(in) || !term.IsTerminal(out) {
		return "", "", "", fmt.Errorf("must be run in a terminal")
	}
	v, err := newPreview()
	if err != nil {
		return "", "", "", err
	}
	defer v.close()
	wakeRead, wakeWrite, err := os.Pipe()
	if err != nil {
		return "", "", "", err
	}
	defer wakeRead.Close()
	defer wakeWrite.Close()
	u := &ui{p: p, h: h, v: v, limit: pageSize, preview: map[string][]string{}, events: make(chan func(*ui), 64),
		wake: wakeWrite}
	if err := u.load(p.entries[0].hash, plain); err != nil {
		return "", "", "", err
	}

	state, err := term.MakeRaw(in)
	if err != nil {
		return "", "", "", err
	}
	defer term.Restore(in, state)
	// Use the alternate screen (like fzf with --height=100%), and hide the cursor, as the cursor row shows where it is.
	os.Stdout.WriteString("\x1b[?1049h\x1b[?25l")
	defer os.Stdout.WriteString("\x1b[0m\x1b[?25h\x1b[?1049l")

	u.width, u.height, err = term.GetSize(out)
	if err != nil {
		return "", "", "", err
	}

	resized := make(chan os.Signal, 1)
	signal.Notify(resized, syscall.SIGWINCH)
	defer signal.Stop(resized)
	go func() {
		for range resized {
			u.send(func(u *ui) {
				if w, h, err := term.GetSize(out); err == nil {
					u.width, u.height = w, h
				}
			})
		}
	}()

	// Wait for keys and events with select(2), rather than a goroutine blocked reading stdin, which would keep reading
	// after this returns and steal keys from git (e.g. its editor for a reword).
	buf := make([]byte, 256)
	wakeFd := int(wakeRead.Fd())
	for {
		u.draw()
		var fds unix.FdSet
		fds.Set(in)
		fds.Set(wakeFd)
		if _, err := unix.Select(max(in, wakeFd)+1, &fds, nil, nil, nil); err != nil {
			if err == unix.EINTR {
				continue
			}
			return "", "", "", err
		}
		if fds.IsSet(wakeFd) {
			unix.Read(wakeFd, buf)
			for len(u.events) > 0 {
				(<-u.events)(u)
			}
		}
		if fds.IsSet(in) {
			n, err := unix.Read(in, buf)
			if err != nil {
				return "", "", "", err
			}
			for b := buf[:n]; len(b) > 0; {
				var key string
				key, b = parseKey(b)
				if done, todo, onto, cutoff := u.handle(key); done {
					return todo, onto, cutoff, nil
				}
			}
		}
	}
}

func (u *ui) send(event func(*ui)) {
	u.events <- event
	u.wake.Write([]byte{0})
}

// handle acts on a key, and returns whether the user has finished, with the todo list and what it goes onto and stops
// at if they confirmed.
func (u *ui) handle(key string) (done bool, todo, onto, cutoff string) {
	u.status = ""
	page := u.listHeight()
	r := u.rows[u.cursor]
	switch key {
	case "up", "k", "ctrl-p":
		u.moveCursor(-1)
	case "down", "j", "ctrl-n":
		u.moveCursor(1)
	case "ctrl-u":
		u.moveCursor(-page / 2)
	case "ctrl-d":
		u.moveCursor(page / 2)
	case "pgup":
		u.moveCursor(-page)
	case "pgdn":
		u.moveCursor(page)
	case "home", "g":
		u.moveCursor(-u.cursor)
	case "end", "G":
		u.moveCursor(len(u.rows))
	case "shift-up":
		u.scroll = max(u.scroll-1, 0)
	case "shift-down":
		u.scroll++ // Limited when drawn, as the preview's length depends on the window size.
	case "ctrl-b":
		u.scroll = max(u.scroll-u.previewHeight(), 0)
	case "ctrl-f":
		u.scroll += u.previewHeight()
	case "u", "backspace":
		u.edit(func() error { return u.mark(r, "") }, r.hash, r.kind)
	case "alt-up", "alt-down": // Option+up/down (with option acting as alt), as in VS Code
		// Follow the commit to its copy, as moving it adds it to the rebase if it isn't already.
		u.edit(func() error {
			if r.entry < 0 {
				return fmt.Errorf("%s isn't on the current branch, so it can't be rebased", r.short)
			}
			if j := r.entry - 1; key == "alt-up" && j >= 0 {
				u.p.swap(r.entry, j)
			} else if j := r.entry + 1; key == "alt-down" && j < len(u.p.entries) {
				u.p.swap(r.entry, j)
			}
			return nil
		}, r.hash, copied)
	case "b":
		u.edit(func() error {
			if u.p.base.hash == r.hash {
				u.p.base, u.p.baseSize = commit{}, 0
				return nil
			}
			// Checked here, as the plan's check would only catch it if the new base kept the commit in the rebase.
			if r.kind != plain {
				return fmt.Errorf("can't rebase onto %s, as it's one of the commits being rebased", r.short)
			}
			out, err := git("rev-list", "--first-parent", "--count", "HEAD", "^"+r.hash)
			if err != nil {
				return err
			}
			n, err := strconv.Atoi(strings.TrimSpace(out))
			if err != nil {
				return err
			}
			u.p.base = commit{hash: r.hash, short: r.short, subject: r.subject}
			u.p.baseSize = n
			return u.h.fill(u.p, n+1) // Up to the commit the rebase stops at
		}, r.hash, plain)
	case "c":
		u.edit(func() error {
			if r.entry < 0 {
				return fmt.Errorf("%s isn't on the current branch, so the rebase can't stop at it", r.short)
			}
			if u.p.cutoff == r.hash {
				u.p.cutoff = ""
			} else {
				u.p.cutoff = r.hash
			}
			return nil
		}, r.hash, r.kind)
	case "enter":
		size := u.p.size()
		todo, err := u.p.todo(size)
		if err == nil {
			cutoff, err = u.p.cutoffAt(size)
		}
		if err != nil {
			u.status = err.Error()
			return false, "", "", ""
		}
		return true, todo, u.p.base.hash, cutoff
	case "esc", "q", "ctrl-c":
		return true, "", "", ""
	default:
		if action, ok := actionKeys[key]; ok {
			u.edit(func() error { return u.mark(r, action) }, r.hash, r.kind)
		}
	}
	return false, "", "", ""
}

// mark sets the action of row r's commit ("" to unmark it).
func (u *ui) mark(r row, action string) error {
	if r.entry < 0 {
		return fmt.Errorf("%s isn't on the current branch, so it can't be rebased", r.short)
	}
	u.p.entries[r.entry].action = action
	return nil
}

// edit applies a change to the plan and shows the result, with the cursor on the given commit (see load). If the
// change fails or leaves the plan not working, it's undone, and the error shown instead.
func (u *ui) edit(change func() error, hash string, kind int) {
	saved := u.p.clone()
	err := change()
	if err == nil {
		err = u.p.check()
	}
	if err == nil {
		err = u.load(hash, kind)
	}
	if err != nil {
		*u.p = *saved // The rows are still those of the saved plan, as load only replaces them if it succeeds.
		u.status = err.Error()
	}
}

// load redraws the rows from the plan, and puts the cursor on the given commit: on its row of the given kind if it
// has one, and otherwise its other row (e.g. its copy, if it's just been added to the rebase).
func (u *ui) load(hash string, kind int) error {
	if err := u.h.fill(u.p, u.limit+1); err != nil {
		return err
	}
	rows, more, err := u.v.rows(u.p, u.limit)
	if err != nil {
		return err
	}
	u.rows, u.more = rows, more
	found := -1
	for i, r := range u.rows {
		if r.hash == hash && (r.kind == kind || found < 0) {
			found = i
		}
	}
	if found < 0 {
		found = u.commitRow(min(u.cursor, len(u.rows)-1), 1)
	}
	u.cursor = found
	u.moved()
	return nil
}

// commitRow returns the nearest row to i that has a commit, looking downwards first if dir >= 0, else upwards.
func (u *ui) commitRow(i, dir int) int {
	step := 1
	if dir < 0 {
		step = -1
	}
	for _, s := range []int{step, -step} {
		for j := i; j >= 0 && j < len(u.rows); j += s {
			if u.rows[j].hash != "" {
				return j
			}
		}
	}
	return i
}

func (u *ui) moveCursor(by int) {
	target := u.cursor + by
	// Load a page beyond the cursor, so scrolling down doesn't run out of rows.
	if u.more && target+u.listHeight() >= len(u.rows) {
		u.limit += max(pageSize, target+u.listHeight()-len(u.rows)+1)
		if err := u.load(u.rows[u.cursor].hash, u.rows[u.cursor].kind); err != nil {
			u.status = err.Error()
		}
	}
	u.cursor = u.commitRow(min(max(target, 0), len(u.rows)-1), by)
	u.moved()
}

// moved starts producing the preview of the cursor's commit if it isn't already there.
func (u *ui) moved() {
	u.scroll = 0
	h := u.rows[u.cursor].hash
	if _, ok := u.preview[h]; ok {
		return
	}
	u.preview[h] = nil
	go func() {
		out, err := exec.Command("git", "show", "--color=always", "--stat", "--patch", h).Output()
		lines := strings.Split(strings.TrimSuffix(string(out), "\n"), "\n")
		if err != nil {
			lines = []string{errText + "git show failed: " + err.Error()}
		}
		u.send(func(u *ui) { u.preview[h] = lines })
	}()
}

// The window has the header (the summary then the help, each on as many rows as it wraps onto), then the list, a
// separator row and the preview.
func (u *ui) listHeight() int {
	return max(min((u.height-1-len(u.header()))*2/5, len(u.rows)), 1)
}

func (u *ui) previewHeight() int {
	return max(u.height-1-len(u.header())-u.listHeight(), 0)
}

func (u *ui) header() []string {
	return append(wrap(u.summary(u.p.size()), u.width), u.helpLines()...)
}

// helpLines wraps the help onto as many rows as it needs at the window's width, breaking only between items.
func (u *ui) helpLines() []string {
	const gap = "  "
	var lines []string
	line, width := "", 0
	for _, h := range help {
		item := keyHint + h.key + " " + dim + h.desc
		itemWidth := utf8.RuneCountInString(h.key + " " + h.desc)
		if width > 0 && width+len(gap)+itemWidth > u.width {
			lines = append(lines, line)
			line, width = "", 0
		}
		if width > 0 {
			line += gap
			width += len(gap)
		}
		line += item
		width += itemWidth
	}
	return append(lines, line)
}

func (u *ui) draw() {
	size := u.p.size()
	listHeight := u.listHeight()
	u.offset = min(max(u.offset, u.cursor-listHeight+1), u.cursor)

	var lines []string
	for _, h := range u.header() {
		lines = append(lines, u.line(h, bg))
	}
	l := u.labels(size)
	for i := u.offset; i < u.offset+listHeight; i++ {
		if i < len(u.rows) {
			lines = append(lines, u.row(i, size, l))
		} else {
			lines = append(lines, u.line("", bg))
		}
	}
	lines = append(lines, u.line(border+strings.Repeat("─", u.width), bg))

	preview, ok := u.preview[u.rows[u.cursor].hash]
	if !ok || preview == nil {
		preview = []string{dim + "Loading…"}
	}
	u.scroll = max(min(u.scroll, len(preview)-u.previewHeight()), 0)
	for i := u.scroll; len(lines) < u.height; i++ {
		if i < len(preview) {
			lines = append(lines, u.line(preview[i], bg))
		} else {
			lines = append(lines, u.line("", bg))
		}
	}

	// Bracket the frame in synchronised-output mode so the terminal shows it all at once, without flicker.
	os.Stdout.WriteString("\x1b[?2026h\x1b[H" + strings.Join(lines[:u.height], "\r\n") + "\x1b[?2026l")
}

func (u *ui) summary(size int) string {
	p := u.p
	switch {
	case u.status != "":
		return errText + u.status
	case size == 0 && p.cutoff != "":
		return dim + "Nothing to rebase above the cutoff"
	case size == 0 && p.base.hash != "":
		return dim + "Nothing to rebase: " + p.base.short + " already has all of the current branch's commits"
	case size == 0:
		return dim + "Mark or move commits to rebase (it starts below the oldest one), or choose a base to rebase onto"
	}
	s := fmt.Sprintf("Rebase %d commit%s onto ", size, plural(size))
	switch {
	case p.base.hash != "":
		s += hash + p.base.short + text + " " + p.base.subject
	case size < len(p.entries):
		s += hash + p.entries[size].short + text + " " + p.entries[size].subject
	default:
		s += "the root"
	}
	if n := p.pushed(); n > 0 {
		s += errText + fmt.Sprintf(" (rewrites %d already-pushed commit%s)", n, plural(n))
	}
	return s
}

// labels is what the rows are drawn with besides their own commits.
type labels struct {
	onto    string // Hash of the commit the rebase goes onto, labelled as such ("" for none)
	cutoff  string // Hash of the commit the rebase stops at, if it isn't the one it goes onto
	top     int    // First row of the arrow from moved commits' old positions to their copies (-1 for no arrow)
	bottom  int    // Last row of the arrow
	partner int    // Row of the cursor's commit's other copy, if it's being moved (else -1)
}

func (u *ui) labels(size int) labels {
	l := labels{top: -1, bottom: -1, partner: -1}
	cutoff, _ := u.p.cutoffAt(size)
	switch {
	case u.p.base.hash != "":
		l.onto = u.p.base.hash
		if u.p.moves(size) {
			l.cutoff = cutoff
		}
	case size > 0:
		l.onto = cutoff
	}
	if !u.p.moves(size) {
		return l
	}
	cur := u.rows[u.cursor]
	for i, r := range u.rows {
		if r.kind == plain {
			continue
		}
		if l.top < 0 {
			l.top = i
		}
		l.bottom = i
		if cur.kind != plain && r.hash == cur.hash && r.kind != cur.kind {
			l.partner = i
		}
	}
	return l
}

// row draws row i of the list: the cursor's pointer, the arrow, the action or label, the graph, the hash, then the
// subject and refs.
func (u *ui) row(i, size int, l labels) string {
	r := u.rows[i]
	rowBg, mark := bg, " "
	switch i {
	case u.cursor:
		rowBg, mark = bgCursor, pointer+"▌"
	case l.partner:
		rowBg = bgPartner
	}
	start := mark + " " + u.arrow(i, l)
	if r.hash == "" {
		return u.line(start+strings.Repeat(" ", 7)+text+r.graph, rowBg)
	}

	label := fmt.Sprintf("%-6s", "")
	subject := dim + r.subject
	switch {
	case r.kind == copied:
		action := u.p.action(r.entry, size)
		label = actionColours[action] + fmt.Sprintf("%-6s", action)
		subject = text + r.subject
		if action == "drop" {
			subject = dim + "\x1b[9m" + r.subject + "\x1b[29m" // Struck through
		}
	case r.kind == ghost:
		label = dim + "moved "
		subject = dim + "\x1b[9m" + r.subject + "\x1b[29m"
	case r.hash == l.onto:
		label = ontoLabel + "onto  " // Show where the rebase goes, as it isn't part of the rebase itself.
	case r.hash == l.cutoff:
		label = cutoffLabel + "cutoff"
	}

	hashColour := hash
	if !u.h.unpushed[r.hash] {
		hashColour = pushed
	}
	if r.refs != "" {
		subject += " " + refs + "(" + r.refs + ")"
	}
	return u.line(start+label+" "+text+r.graph+hashColour+r.short+" "+subject, rowBg)
}

// arrow draws row i's part (two columns and a space) of the arrow from moved commits' old positions to their copies.
func (u *ui) arrow(i int, l labels) string {
	if i < l.top || i > l.bottom {
		return "   "
	}
	r := u.rows[i]
	colour := arrow
	if r.kind != plain && (i == u.cursor || i == l.partner) {
		colour = pointer // Light up the cursor's commit's part of the arrow at both ends.
	}
	line, tip := "│", " "
	switch {
	case i == l.top:
		line = "╭"
	case i == l.bottom:
		line = "╰"
	case r.kind != plain:
		line = "├"
	}
	switch r.kind {
	case copied:
		tip = "▶"
	case ghost:
		tip = "─"
	}
	return colour + line + tip + " "
}

// line fits s to the window's width on the given background, and clears the rest of the row.
func (u *ui) line(s, lineBg string) string {
	base := lineBg + text
	return base + fit(s, u.width, base) + "\x1b[0m" + base + "\x1b[K\x1b[0m"
}

// fit cuts s down to width columns, keeping its colours and expanding tabs. Each colour reset in s (e.g. from git's
// colours) is followed by base, so the line keeps its background. Other escape sequences are dropped, so they can't
// move the cursor and break the layout.
func fit(s string, width int, base string) string {
	var b strings.Builder
	col := 0
	for i := 0; i < len(s); {
		if s[i] == 0x1b {
			j := i + 1
			if j < len(s) && s[j] == '[' {
				for j++; j < len(s) && (s[j] < 0x40 || s[j] > 0x7e); j++ {
				}
				if j < len(s) {
					j++
				}
				if seq := s[i:j]; strings.HasSuffix(seq, "m") {
					b.WriteString(seq)
					if resets(seq[2 : len(seq)-1]) {
						b.WriteString(base)
					}
				}
			}
			i = j
			continue
		}
		r, n := utf8.DecodeRuneInString(s[i:])
		i += n
		switch {
		case r == '\t':
			spaces := tabWidth - col%tabWidth
			if col+spaces > width {
				return b.String()
			}
			b.WriteString(strings.Repeat(" ", spaces))
			col += spaces
		case r < 0x20 || r == 0x7f:
			// Drop other control characters, as they could move the cursor too.
		default:
			w := runeWidth(r)
			if col+w > width {
				return b.String()
			}
			b.WriteRune(r)
			col += w
		}
	}
	return b.String()
}

var escapeSeq = regexp.MustCompile(`\x1b\[[0-9;?]*[A-Za-z]`)

// wrap splits s into rows of at most width columns, breaking at spaces (a word too long for a row is cut off when the
// row is drawn). Each row after the first starts with the last colour set before it, so colours carry across rows.
func wrap(s string, width int) []string {
	var lines []string
	line, col, colour := "", 0, ""
	for i, word := range strings.Split(s, " ") {
		w := 0
		for _, r := range escapeSeq.ReplaceAllString(word, "") {
			w += runeWidth(r)
		}
		switch {
		case i == 0:
		case col+1+w > width:
			lines = append(lines, line)
			line, col = colour, 0
		default:
			line += " "
			col++
		}
		line += word
		col += w
		for _, seq := range escapeSeq.FindAllString(word, -1) {
			if strings.HasSuffix(seq, "m") {
				colour = seq
			}
		}
	}
	return append(lines, line)
}

// resets returns whether the SGR parameters (e.g. "1;31") reset the foreground or background colour.
func resets(params string) bool {
	if params == "" {
		return true
	}
	fields := strings.Split(params, ";")
	for i := 0; i < len(fields); i++ {
		switch fields[i] {
		case "", "0", "39", "49":
			return true
		case "38", "48", "58":
			// Skip the colour's own parameters (5;N or 2;R;G;B), which could otherwise look like a reset.
			if i+1 < len(fields) && fields[i+1] == "5" {
				i += 2
			} else if i+1 < len(fields) && fields[i+1] == "2" {
				i += 4
			}
		}
	}
	return false
}

// runeWidth returns how many columns r takes up in the terminal: 2 for East Asian wide characters and most emoji, 0
// for combining marks.
func runeWidth(r rune) int {
	switch {
	case unicode.In(r, unicode.Mn, unicode.Me) || r == 0x200d || (r >= 0xfe00 && r <= 0xfe0f):
		return 0
	case r >= 0x1100 && (r <= 0x115f || r == 0x2329 || r == 0x232a || (r >= 0x2e80 && r <= 0xa4cf && r != 0x303f) ||
		(r >= 0xac00 && r <= 0xd7a3) || (r >= 0xf900 && r <= 0xfaff) || (r >= 0xfe30 && r <= 0xfe6f) ||
		(r >= 0xff00 && r <= 0xff60) || (r >= 0xffe0 && r <= 0xffe6) || (r >= 0x1f300 && r <= 0x1f64f) ||
		(r >= 0x1f900 && r <= 0x1f9ff) || (r >= 0x20000 && r <= 0x3fffd)):
		return 2
	}
	return 1
}

// escapeKeys names the escape sequences (after the ESC) of the keys used, in the forms terminals commonly send.
var escapeKeys = map[string]string{
	"[A": "up", "OA": "up", "[B": "down", "OB": "down",
	"[1;2A": "shift-up", "[1;2B": "shift-down", "[1;3A": "alt-up", "[1;3B": "alt-down",
	"[5~": "pgup", "[6~": "pgdn", "[H": "home", "OH": "home", "[1~": "home", "[F": "end", "OF": "end", "[4~": "end",
}

// parseKey returns the name of the first key in b (e.g. "j", "enter", "ctrl-d", "up"), and the bytes after it.
// Unrecognised escape sequences are named "".
func parseKey(b []byte) (string, []byte) {
	if b[0] != 0x1b {
		r, n := utf8.DecodeRune(b)
		switch {
		case r == '\r' || r == '\n':
			return "enter", b[n:]
		case r == 0x7f || r == 0x08:
			return "backspace", b[n:]
		case r < 0x20:
			return "ctrl-" + string(rune('a'+r-1)), b[n:]
		}
		return string(r), b[n:]
	}
	if len(b) == 1 {
		return "esc", nil
	}
	if b[1] == '[' || b[1] == 'O' {
		// A CSI or SS3 sequence ends at its first byte in 0x40–0x7e (after the [ or O).
		j := 2
		for j < len(b) && (b[j] < 0x40 || b[j] > 0x7e) {
			j++
		}
		if j == len(b) {
			return "", nil
		}
		return escapeKeys[string(b[1:j+1])], b[j+1:]
	}
	// ESC before another key is how terminals send alt+key (when option is set to act as alt, on macOS).
	key, rest := parseKey(b[1:])
	return "alt-" + key, rest
}

func plural(n int) string {
	if n == 1 {
		return ""
	}
	return "s"
}

func fgColour(hex string) string {
	var r, g, b int
	fmt.Sscanf(hex, "#%02x%02x%02x", &r, &g, &b)
	return fmt.Sprintf("\x1b[38;2;%d;%d;%dm", r, g, b)
}

func bgColour(hex string) string {
	var r, g, b int
	fmt.Sscanf(hex, "#%02x%02x%02x", &r, &g, &b)
	return fmt.Sprintf("\x1b[48;2;%d;%d;%dm", r, g, b)
}
