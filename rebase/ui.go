package main

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"regexp"
	"strings"
	"syscall"
	"unicode"
	"unicode/utf8"

	"golang.org/x/sys/unix"
	"golang.org/x/term"
)

// Colours from FZF_DEFAULT_OPTS in .zshrc (Catppuccin Mocha), so this looks like my fzf-based `switch`.
var (
	bg          = bgColour("#1e1e2e")
	bgCursor    = bgColour("#313244")
	bgPartner   = bgColour("#282839") // The other copy of the cursor's commit, when it's being moved
	text        = fgColour("#cdd6f4")
	dim         = fgColour("#6c7086")
	helpText    = fgColour("#a6adc8")
	border      = fgColour("#585b70")
	pointer     = fgColour("#cdd6f4") // Currently highlighted entry
	hash        = fgColour("#f9e2af")
	pushed      = fgColour("#f38ba8") // Red, like origin branches in display-logs
	refs        = fgColour("#94e2d5")
	errText     = fgColour("#f38ba8")
	baseLabel   = fgColour("#89dceb")
	cutoffLabel = fgColour("#f5c2e7")
	arrow       = fgColour("#9399b2")
	branchLine  = fgColour("#89b4fa") // HEAD's branch in the graph

	actionColours = map[string]string{
		"pick":   fgColour("#a6e3a1"),
		"reword": fgColour("#f5e0dc"),
		"edit":   fgColour("#f9e2af"),
		"squash": fgColour("#cba6f7"),
		"fixup":  fgColour("#fab387"),
		"drop":   fgColour("#f38ba8"),
	}
)

const (
	tabWidth   = 2  // As --tabstop in FZF_DEFAULT_OPTS
	minPreview = 10 // Fewest rows the preview has by default, as it's hidden if its share of the space would be fewer
	// Faint labels follow from the rest of the plan rather than being chosen, so their keys have nothing to undo.
	faint    = "\x1b[2m"
	notFaint = "\x1b[22m"
)

// help is the key and description of each item in the help shown at the top.
var help = []struct{ key, desc string }{
	{"p", "pick"}, {"r", "reword"}, {"e", "edit"}, {"s", "squash"}, {"f", "fixup"}, {"d", "drop"}, {"u", "unmark"},
	{"b", "base"}, {"c", "cutoff"}, {"⌥↑/↓", "swap"}, {"g/G", "top/bottom"}, {"enter", "rebase"}, {"esc", "quit"},
}

// cherryHelp is the help shown when cherry-picking, which leaves out d, as it only does what u does (see mark).
var cherryHelp = []struct{ key, desc string }{
	{"p", "pick"}, {"⇧p", "pick range"}, {"r", "reword"}, {"e", "edit"}, {"s", "squash"}, {"f", "fixup"},
	{"u", "unmark"}, {"⌥↑/↓", "swap"}, {"g/G", "top/bottom"}, {"enter", "rebase"}, {"esc", "quit"},
}

// checkoutHelp is the help shown when choosing a commit to check out, which has none of the keys for arranging a
// rebase.
var checkoutHelp = []struct{ key, desc string }{{"g/G", "top/bottom"}, {"enter", "checkout"}, {"esc", "quit"}}

// previewHelp is the help for the preview, shown in the row above it (hiddenPreviewHelp instead while it's hidden).
var (
	previewHelp       = []struct{ key, desc string }{{"⇧↑/↓", "scroll"}, {"⌘↑/↓", "resize"}}
	hiddenPreviewHelp = []struct{ key, desc string }{{"⌘↑", "show"}}
)

type ui struct {
	p        *plan
	h        *history
	v        *preview
	checkout bool  // Whether the user is choosing a commit to check out (see checkout.go), rather than arranging p
	rows     []row // The history as it will be once rebased
	limit    int   // How many commits to load into rows
	more     bool  // Whether there are more commits than rows has
	cursor   int   // Index of the row the cursor is on, which always has a commit
	offset   int   // Index of the row at the top of the list
	width    int
	height   int
	status   string              // Error shown under the help until the next key
	scroll   int                 // Lines of the preview scrolled past
	listRows int                 // Rows the list has been resized to (0 for the default, see listHeight)
	preview  map[string][]string // Each commit's preview lines by hash (nil while git is still producing them)
	events   chan func(*ui)      // Updates from other goroutines, applied by the main loop
	wake     *os.File            // Written to after sending an event, to wake the main loop up
}

// result is what the user confirmed: the todo list of the rebase and what it goes onto and stops at (see rebase), or
// when checking out, the commit to check out. It's empty if they quit.
type result struct{ todo, onto, cutoff, commit string }

// choose shows the history for the user to arrange (or with checkout, to choose a commit to check out from), and
// returns what they confirm.
func choose(p *plan, h *history, checkout bool) (result, error) {
	in, out := int(os.Stdin.Fd()), int(os.Stdout.Fd())
	if !term.IsTerminal(in) || !term.IsTerminal(out) {
		return result{}, fmt.Errorf("must be run in a terminal")
	}
	v, err := newPreview()
	if err != nil {
		return result{}, err
	}
	defer v.close()
	wakeRead, wakeWrite, err := os.Pipe()
	if err != nil {
		return result{}, err
	}
	defer wakeRead.Close()
	defer wakeWrite.Close()
	u := &ui{p: p, h: h, v: v, checkout: checkout, limit: pageSize, preview: map[string][]string{},
		events: make(chan func(*ui), 64), wake: wakeWrite}
	start := "" // When cherry-picking, the newest commit in the list, which is more likely another branch's than HEAD
	switch {
	case checkout:
		head, err := resolve("HEAD") // Starting from where the user already is
		if err != nil {
			return result{}, err
		}
		start = head.hash
	case !p.cherry:
		start = p.entries[0].hash
	}
	if err := u.load(start, plain); err != nil {
		return result{}, err
	}
	// Other branches' newer commits come first, so HEAD can be further down than the first page.
	for checkout && u.rows[u.cursor].hash != start && u.more {
		u.limit += pageSize
		if err := u.load(start, plain); err != nil {
			return result{}, err
		}
	}

	state, err := term.MakeRaw(in)
	if err != nil {
		return result{}, err
	}
	defer term.Restore(in, state)
	// Use the alternate screen (like fzf with --height=100%), and hide the cursor, as the cursor row shows where it is.
	os.Stdout.WriteString("\x1b[?1049h\x1b[?25l")
	defer os.Stdout.WriteString("\x1b[0m\x1b[?25h\x1b[?1049l")

	u.width, u.height, err = term.GetSize(out)
	if err != nil {
		return result{}, err
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
			return result{}, err
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
				return result{}, err
			}
			for b := buf[:n]; len(b) > 0; {
				var key string
				key, b = parseKey(b)
				if done, res := u.handle(key); done {
					return res, nil
				}
			}
		}
	}
}

func (u *ui) send(event func(*ui)) {
	u.events <- event
	u.wake.Write([]byte{0})
}

// handle acts on a key, and returns whether the user has finished, with what they confirmed (if they didn't quit).
func (u *ui) handle(key string) (bool, result) {
	u.status = ""
	if u.navigate(key) {
		return false, result{}
	}
	r := u.rows[u.cursor]
	switch {
	case key == "esc" || key == "q" || key == "ctrl-c":
		return true, result{}
	case u.checkout && key == "enter":
		return true, result{commit: r.hash}
	case u.checkout:
		return false, result{} // The other keys arrange the rebase, which there isn't one of.
	}
	return u.arrange(key, r)
}

// navigate acts on a key that moves around the list or the preview, and returns whether it was one.
func (u *ui) navigate(key string) bool {
	page := u.listHeight()
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
	case "cmd-up", "cmd-down": // As sent by Ghostty and VS Code (see their config), moving the separator up/down
		// Step from the list's height as drawn, so each key acts straight away, even if the height was limited.
		step := 3
		if key == "cmd-up" {
			step = -step
		}
		u.listRows = max(u.listHeight()+step, 1)
	default:
		return false
	}
	return true
}

// arrange acts on a key that arranges the rebase (or confirms it) with the cursor on row r, and returns whether the
// user has finished, with what they confirmed.
func (u *ui) arrange(key string, r row) (bool, result) {
	switch key {
	case "u", "backspace":
		u.edit("unmark", func() error { return u.mark(r, "") }, r, r.kind)
	case "alt-up", "alt-down": // Option+up/down (with option acting as alt), as in VS Code
		// Follow the commit to its copy, as moving it adds it to the rebase if it isn't already.
		u.edit("move", func() error {
			if r.entry < 0 {
				return fmt.Errorf("%s, as %s", cant("move", r.short), u.outside())
			}
			if j := r.entry - 1; key == "alt-up" && j >= 0 {
				u.p.swap(r.entry, j)
			} else if j := r.entry + 1; key == "alt-down" && j < len(u.p.entries) {
				u.p.swap(r.entry, j)
			}
			return nil
		}, r, copied)
	case "P": // Shift+p
		if u.p.cherry {
			u.edit("pick", func() error { return pickBack(u.p, r.hash, r.short) }, r, u.stay(r))
		}
	case "b":
		if u.p.cherry {
			break
		}
		u.edit("base", func() error {
			if u.p.base.hash == r.hash {
				u.p.base, u.p.baseSize = commit{}, 0
				return nil
			}
			return u.h.setBase(u.p, commit{hash: r.hash, short: r.short, subject: r.subject})
		}, r, plain)
	case "c":
		if u.p.cherry {
			break
		}
		u.edit("cutoff", func() error {
			if r.entry < 0 {
				return fmt.Errorf("%s, as it isn't on the current branch", cant("cutoff", r.short))
			}
			if u.p.cutoff == r.hash {
				u.p.cutoff = ""
				return nil
			}
			u.p.setCutoff(r.hash)
			return nil
		}, r, r.kind)
	case "enter":
		size := u.p.size()
		todo, err := u.p.todo(size)
		cutoff := ""
		if err == nil && !u.p.cherry {
			cutoff, err = u.p.cutoffAt(size)
		}
		if err != nil {
			u.status = err.Error()
			return false, result{}
		}
		if u.p.cherry {
			// Stop at HEAD, so the todo list goes on top of it.
			return true, result{todo: todo, cutoff: u.p.base.hash}
		}
		return true, result{todo: todo, onto: u.p.base.hash, cutoff: cutoff}
	default:
		if action, ok := actionKeys[key]; ok {
			what := action
			if r.entry >= 0 && u.p.entries[r.entry].action == action {
				action, what = "", "unmark" // Pressing it again undoes it, as with b and c.
			}
			u.edit(what, func() error { return u.mark(r, action) }, r, u.stay(r))
		}
	}
	return false, result{}
}

// stay returns the kind of row to keep the cursor on after marking row r's commit: the same kind, except that when
// cherry-picking, a commit just picked stays where it is (rather than following it to its copy), to go on to pick more.
func (u *ui) stay(r row) int {
	if u.p.cherry && r.kind == plain {
		return ghost
	}
	return r.kind
}

// mark sets the action of row r's commit ("" to unmark it). When cherry-picking, that picks the commit if it isn't
// already being picked, and unmarking (or dropping, which would be the same) takes it back out.
func (u *ui) mark(r row, action string) error {
	if u.p.cherry && action != "" && action != "drop" {
		return pickCommit(u.p, r.hash, r.short, action)
	}
	if r.entry < 0 {
		what := action
		if what == "" {
			what = "unmark"
		}
		err := fmt.Sprintf("%s, as %s", cant(what, r.short), u.outside())
		// Point to the pick command for the actions that would bring the commit in, which only it can do.
		if !u.p.cherry && action != "" && action != "drop" {
			err += " (quit and run `pick` instead)"
		}
		return errors.New(err)
	}
	if u.p.cherry {
		u.p.unpick(r.entry)
		return nil
	}
	u.p.entries[r.entry].action = action
	return nil
}

// outside says why a commit that isn't an entry can't be marked or moved.
func (u *ui) outside() string {
	if u.p.cherry {
		return "it isn't one of the commits being cherry-picked"
	}
	return "it isn't on the current branch"
}

// edit applies a change the user tried (see explain) to row r's commit, and shows the result, with the cursor on the
// commit's row of the given kind (see load). If the change fails or leaves the plan not working, it's undone, and the
// error shown instead, starting from what the user tried, so it says why they can't do it.
func (u *ui) edit(what string, change func() error, r row, kind int) {
	saved := u.p.clone()
	err := change()
	if err == nil {
		if c := u.p.check(); c != nil {
			err = errors.New(u.p.explain(*c, what, r.hash, r.short))
		}
	}
	if err == nil {
		err = u.load(r.hash, kind)
	}
	if err != nil {
		*u.p = *saved // The rows are still those of the saved plan, as load only replaces them if it succeeds.
		u.status = err.Error()
	}
}

// load redraws the rows from the plan, and puts the cursor on the given commit: on its row of the given kind if it
// has one, and otherwise its other row (e.g. its copy, if it's just been added to the rebase). An empty hash puts it
// on the first commit.
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
		if r.hash != "" && r.hash == hash && (r.kind == kind || found < 0) {
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

// The window has the header (the help then the messages, each on as many rows as it wraps onto), then the list, a
// separator row and the preview. Unless resized, the list has 3/5 of the space, or all of it if the preview would
// otherwise have fewer than minPreview rows.
func (u *ui) listHeight() int {
	space := u.height - 1 - len(u.header())
	rows := space * 3 / 5
	if space-rows < minPreview {
		rows = space // Hide the preview, to show more of the list.
	}
	if u.listRows > 0 {
		rows = u.listRows
	}
	return max(min(rows, space, len(u.rows)), 1)
}

func (u *ui) previewHeight() int {
	return max(u.height-1-len(u.header())-u.listHeight(), 0)
}

// header returns the help, then the rows kept for messages (blank when there's none).
func (u *ui) header() []string {
	message := wrap(u.message(), u.width)
	for len(message) < u.messageRows() {
		message = append(message, "")
	}
	return append(u.helpLines(), message...)
}

// helpLines wraps the help onto as many rows as it needs at the window's width, breaking only between items.
func (u *ui) helpLines() []string {
	const gap = "  "
	var lines []string
	line, width := "", 0
	items := help
	switch {
	case u.checkout:
		items = checkoutHelp
	case u.p.cherry:
		items = cherryHelp
	}
	for _, h := range items {
		descColour, ok := actionColours[strings.Fields(h.desc)[0]] // Including "pick range" in pick's colour
		switch {
		case h.desc == "base":
			descColour = baseLabel
		case h.desc == "cutoff":
			descColour = cutoffLabel
		case !ok:
			descColour = helpText
		}
		item := text + h.key + " " + descColour + h.desc // Labels in their colours, as a key to the list
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
	lines = append(lines, u.line(u.separator(), bg))

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

// separator returns the row between the list and the preview, which has the preview's title at its left end and its
// help at its right end, as far as they fit.
func (u *ui) separator() string {
	const title = "diff"
	help := previewHelp
	if u.previewHeight() == 0 {
		help = hiddenPreviewHelp
	}
	s, width := "", 0
	for i, h := range help {
		if i > 0 {
			s += "  "
			width += 2
		}
		s += text + h.key + " " + helpText + h.desc
		width += utf8.RuneCountInString(h.key + " " + h.desc)
	}
	left := border + "─ " + text + title + " " + border
	leftWidth := utf8.RuneCountInString("─ " + title + " ")
	switch {
	case u.width >= leftWidth+width+5:
		return left + strings.Repeat("─", u.width-leftWidth-width-4) + " " + s + " " + border + "──"
	case u.width >= leftWidth+1:
		return left + strings.Repeat("─", u.width-leftWidth)
	}
	return border + strings.Repeat("─", u.width)
}

// message returns the error or note shown under the help, or "" for none.
func (u *ui) message() string {
	p := u.p
	size := p.size()
	switch {
	case u.status != "":
		return errText + u.status
	case size == 0 && p.cherry:
		return helpText + cherryHint
	case size == 0 && p.cutoff != "":
		return helpText + "Nothing to rebase above the cutoff"
	case size == 0 && p.base.hash != "":
		return helpText + "Nothing to rebase: " + p.base.short + " already has all of the current branch's commits"
	}
	return ""
}

// cherryHint is the note shown while no commits are picked to cherry-pick.
const cherryHint = "Press p on each commit to cherry-pick onto HEAD, or ⇧p to pick every commit back to the last one " +
	"picked"

// messageRows returns how many rows to keep under the help for messages: enough for the longest of them (or the
// current one, if a message from git is longer still), so the list doesn't move when one appears.
func (u *ui) messageRows() int {
	example := u.p.base.short // HEAD when cherry-picking, which has no entries until commits are picked
	if len(u.p.entries) > 0 {
		example = u.p.entries[0].short
	}
	short := strings.Repeat("0", len(example))
	rows := len(wrap(u.message(), u.width))
	messages := []string{
		`can't rebase, as ` + short + ` is marked "squash" with nothing below it to fold into`,
		"Nothing to rebase: " + short + " already has all of the current branch's commits",
	}
	switch {
	case u.checkout:
		messages = nil // Only errors, which can't be known in advance
	case u.p.cherry:
		messages = []string{"can't fixup " + short + ", as " + short + " would then have nothing to fold into", cherryHint}
	}
	for _, m := range messages {
		rows = max(rows, len(wrap(m, u.width)))
	}
	return rows
}

// labels is what the rows are drawn with besides their own commits.
type labels struct {
	base    string // Hash of the commit the rebase goes onto, labelled as its base ("" for none)
	cutoff  string // Hash of the commit the rebase stops at, if it isn't labelled as the base
	top     int    // First row of the arrow from moved commits' old positions to their copies (-1 for no arrow)
	bottom  int    // Last row of the arrow
	partner int    // Row of the cursor's commit's other copy, if it's being moved (else -1)
}

func (u *ui) labels(size int) labels {
	l := labels{top: -1, bottom: -1, partner: -1}
	cutoff, _ := u.p.cutoffAt(size)
	switch {
	case u.p.cherry:
		if size > 0 {
			l.base = u.p.base.hash
		}
	case u.p.base.hash != "":
		l.base = u.p.base.hash
		if u.p.moves(size) {
			l.cutoff = cutoff
		}
	case u.p.cutoff != "":
		l.cutoff = u.p.cutoff // The rebase goes onto it too, but it was chosen as the cutoff (so c undoes it, not b).
	case size > 0:
		l.base = cutoff
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

// commitMarks replaces the graph's * for the actions whose commits don't stay commits of their own once rebased.
var commitMarks = map[string]string{"drop": "×", "squash": "○", "fixup": "○"}

// row draws row i of the list: the cursor's pointer, the arrow, the action or label, the graph, the hash, then the
// refs and subject (in the order of `git log --oneline`).
func (u *ui) row(i, size int, l labels) string {
	r := u.rows[i]
	rowBg, mark := bg, " "
	switch i {
	case u.cursor:
		rowBg, mark = bgCursor, pointer+"▌"
	case l.partner:
		rowBg = bgPartner
	}
	// When checking out, leave out the arrow and the label, as they only show what the rebase does.
	start := mark + " "
	if r.hash == "" {
		if !u.checkout {
			start += u.arrow(i, l) + strings.Repeat(" ", 7)
		}
		return u.line(start+text+r.graph, rowBg)
	}

	label := fmt.Sprintf("%-6s", "")
	graph := r.graph
	subject := dim + r.subject // Dimmed beside the rebase's own commits, which are what matter
	if u.checkout {
		subject = text + r.subject // No rebase to stand out from, so as in `git log`
	}
	if r.lost {
		subject = dim + "\x1b[9m" + r.subject + "\x1b[29m" // Struck through
	}
	switch {
	case r.kind == copied:
		action := u.p.action(r.entry, size)
		label = actionColours[action] + fmt.Sprintf("%-6s", action)
		if u.p.entries[r.entry].action == "" {
			label = faint + label + notFaint // Picked only because it's in the rebase
		}
		subject = text + r.subject
		if action == "drop" {
			subject = dim + "\x1b[9m" + r.subject + "\x1b[29m"
		}
		if mark, ok := commitMarks[action]; ok {
			graph = strings.Replace(graph, "*", mark, 1)
		}
	case r.kind == ghost && r.lost:
		label = dim + "moved "
	case r.kind == ghost:
		label = dim + "copied" // As another branch still has it (always, when cherry-picking)
	case r.hash == l.base:
		label = baseLabel + "base  " // Show where the rebase goes, as it isn't part of the rebase itself.
		if u.p.base.hash == "" || u.p.cherry {
			label = faint + label + notFaint // Only where the rebase happens to stop, or HEAD when cherry-picking
		}
	case r.hash == l.cutoff:
		label = cutoffLabel + "cutoff"
		if r.hash != u.p.cutoff {
			label = faint + label + notFaint
		}
	}

	hashColour := hash
	if !u.h.unpushed[r.hash] {
		hashColour = pushed
	}
	if r.refs != "" {
		subject = refs + "(" + r.refs + ") " + subject
	}
	if !u.checkout {
		start += u.arrow(i, l) + label + " "
	}
	return u.line(start+text+graph+hashColour+r.short+" "+subject, rowBg)
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
	fitted, cols := fit(s, u.width, base)
	clear := "\x1b[K"
	if cols >= u.width {
		// The row is already full, so there's nothing to clear. Clearing anyway would erase its last character, as the
		// cursor stays on the last column (waiting to wrap) after it's written.
		clear = ""
	}
	return base + fitted + "\x1b[0m" + base + clear + "\x1b[0m"
}

// fit cuts s down to width columns, keeping its colours and expanding tabs, and returns it with how many columns it
// takes up. Each colour reset in s (e.g. from git's colours) is followed by base, so the line keeps its background.
// Other escape sequences are dropped, so they can't move the cursor and break the layout.
func fit(s string, width int, base string) (string, int) {
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
				return b.String(), col
			}
			b.WriteString(strings.Repeat(" ", spaces))
			col += spaces
		case r < 0x20 || r == 0x7f:
			// Drop other control characters, as they could move the cursor too.
		default:
			w := runeWidth(r)
			if col+w > width {
				return b.String(), col
			}
			b.WriteRune(r)
			col += w
		}
	}
	return b.String(), col
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
	"[1;9A": "cmd-up", "[1;9B": "cmd-down",
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
