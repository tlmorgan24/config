package main

import (
	"bytes"
	"compress/zlib"
	"crypto/sha1"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"
)

// The list shows the history as it will be once rebased. git draws it (with `git log --graph`) from copies of the
// commits in the rebase, made on top of where the rebase puts them. The copies go in a temporary object directory,
// which git reads alongside the repository's own objects, so the repository itself is never changed.

// Kinds of row
const (
	plain  = iota // A commit as it is
	copied        // A copy of an entry, where the rebase puts it
	ghost         // An entry as it was, which the rebase copies
)

type row struct {
	graph   string // The graph to the left of the commit (in git's colours), or all of a row with no commit
	hash    string // The commit's hash, or the original's for a copy ("" if the row has no commit)
	short   string
	refs    string
	subject string
	entry   int // Index of the commit in the plan's entries, or -1 if it isn't one of them
	kind    int
	lost    bool // Whether no branch or tag will reach the commit once rebased
}

// preview draws the history as it will be once rebased.
type preview struct {
	dir     string            // Temporary object directory for the copies
	env     []string          // Environment that has git read the copies alongside the repository's objects
	sha256  bool              // Whether the repository names objects by SHA-256 rather than SHA-1
	now     int64             // Commit time of the copies, so git shows them above everything else
	head    string            // How `git log --decorate` shows HEAD (e.g. "HEAD -> main"), to move it to the copies
	exclude []string          // `git log` options to leave out HEAD and its branch, which the copies replace
	raw     map[string][]byte // Each entry's commit object by hash, as fetched from git
}

func newPreview() (*preview, error) {
	objects, err := git("rev-parse", "--path-format=absolute", "--git-path", "objects")
	if err != nil {
		return nil, err
	}
	format, err := git("rev-parse", "--show-object-format")
	if err != nil {
		return nil, err
	}
	dir, err := os.MkdirTemp("", "rebase-preview-")
	if err != nil {
		return nil, err
	}
	v := &preview{
		dir: dir,
		env: append(os.Environ(), "GIT_OBJECT_DIRECTORY="+dir,
			"GIT_ALTERNATE_OBJECT_DIRECTORIES="+strings.TrimSpace(objects)),
		sha256:  strings.TrimSpace(format) == "sha256",
		now:     time.Now().Unix(),
		head:    "HEAD",
		exclude: []string{"--exclude=HEAD"},
		raw:     map[string][]byte{},
	}
	if branch, err := git("symbolic-ref", "-q", "HEAD"); err == nil { // Fails if HEAD is detached.
		branch = strings.TrimSpace(branch)
		v.head = "HEAD -> " + strings.TrimPrefix(branch, "refs/heads/")
		v.exclude = append(v.exclude, "--exclude="+branch)
	}
	return v, nil
}

func (v *preview) close() {
	os.RemoveAll(v.dir)
}

// rows returns the first limit commits of the history (with the graph rows between them) as it will be once rebased,
// and whether there are more. The commits the rebase copies also appear as they were, as ghosts, where other branches
// still reach them, or (if it moves them onto a new base) where they were. HEAD's branch is drawn in branchLine.
func (v *preview) rows(p *plan, limit int) ([]row, bool, error) {
	size := p.size()
	moves := p.moves(size)
	// Leave red and blue out of the colours git draws the branches in, as they mean drop and HEAD's branch here.
	args := []string{"-c", "log.graphColors=#a6e3a1,#f9e2af,#cba6f7,#fab387,#94e2d5,#f5c2e7", "log", "--graph",
		"--color=always", "--no-show-signature", "--format=%x00%H%x00%h%x00%D%x00%s%x00%P",
		fmt.Sprintf("--max-count=%d", limit)}
	copies := map[string]int{} // Index of the entry each copy (or kept commit) is of, by its hash
	lost := map[string]bool{}
	if size > 0 {
		tip, err := v.copy(p, size, copies)
		if err != nil {
			return nil, false, err
		}
		if moves {
			// HEAD's old commits stay in the list, to show where the rebase takes them from, so find out which of them
			// nothing will reach once HEAD's branch is on the copies.
			lostArgs := append(append([]string{"rev-list", "HEAD", "--not"}, v.exclude...), "--all", tip)
			out, err := gitWith(v.env, lostArgs...)
			if err != nil {
				return nil, false, err
			}
			for _, hash := range strings.Fields(out) {
				lost[hash] = true
			}
		} else {
			args = append(args, v.exclude...) // Only before --all, which they apply to
		}
		args = append(args, "--all", tip)
	} else {
		args = append(args, "--all")
	}
	out, err := gitWith(v.env, args...)
	if err != nil {
		return nil, false, err
	}

	entries := map[string]int{}
	for i, e := range p.entries {
		entries[e.hash] = i
	}
	var rows []row
	commits := 0
	// git keeps each commit's first parent in its column, so HEAD's branch runs down the leftmost column if its newest
	// commit comes first (as copies do, being the newest commits), until its root commit.
	onBranch := true
	for _, line := range strings.Split(strings.TrimSuffix(out, "\n"), "\n") {
		graph, rest, ok := strings.Cut(line, "\x00")
		if !ok {
			if onBranch {
				line = recolourFirst(line, branchLine)
			}
			rows = append(rows, row{graph: line, entry: -1})
			continue
		}
		fields := strings.Split(rest, "\x00")
		if len(fields) != 5 {
			continue // Can't happen, as no field can contain NUL.
		}
		commits++
		r := row{graph: graph, hash: fields[0], short: fields[1], refs: fields[2], subject: fields[3], entry: -1,
			lost: lost[fields[0]]}
		if i, ok := copies[r.hash]; ok {
			r.kind, r.entry, r.hash, r.short = copied, i, p.entries[i].hash, p.entries[i].short
			r.refs = withoutHead(r.refs) // Only a kept commit has any, which other branches still point at.
			if i == 0 {
				r.refs = strings.TrimSuffix(v.head+", "+r.refs, ", ") // The newest copy is where HEAD ends up.
			}
		} else {
			if i, ok := entries[r.hash]; ok {
				r.entry = i
				if i < size {
					r.kind = ghost
				}
			}
			if size > 0 {
				r.refs = withoutHead(r.refs)
			}
		}
		if commits == 1 {
			onBranch = r.entry == 0 && r.kind != ghost
		}
		if onBranch {
			r.graph = recolourFirst(r.graph, branchLine)
			onBranch = fields[4] != "" || !strings.HasPrefix(escapeSeq.ReplaceAllString(r.graph, ""), "*")
		}
		rows = append(rows, r)
	}
	return rows, commits == limit, nil
}

// recolourFirst returns graph with its first character (the leftmost column) in the given colour.
func recolourFirst(graph, colour string) string {
	rest := graph
	for {
		loc := escapeSeq.FindStringIndex(rest)
		if loc == nil || loc[0] != 0 {
			break
		}
		rest = rest[loc[1]:]
	}
	c, n := utf8.DecodeRuneInString(rest)
	if n == 0 || c == ' ' {
		return graph
	}
	return colour + string(c) + "\x1b[m" + strings.TrimPrefix(rest[n:], "\x1b[m")
}

// withoutHead removes HEAD (and the branch it's on) from a commit's decoration, e.g. "HEAD -> main, origin/main".
func withoutHead(refs string) string {
	var kept []string
	for _, ref := range strings.Split(refs, ", ") {
		if ref != "HEAD" && !strings.HasPrefix(ref, "HEAD -> ") {
			kept = append(kept, ref)
		}
	}
	return strings.Join(kept, ", ")
}

// copy writes copies of the entries in the rebase, in todo-list order on top of where the rebase puts them, recording
// which entry each is a copy of in copies, and returns the hash of the newest. Like git, it keeps commits as they are
// (rather than copying them) from the oldest up to the first that changes: by being marked with another action than
// pick, or by getting a different parent.
func (v *preview) copy(p *plan, size int, copies map[string]int) (string, error) {
	var missing []string
	for _, e := range p.entries[:size] {
		if v.raw[e.hash] == nil {
			missing = append(missing, e.hash)
		}
	}
	if err := v.fetch(missing); err != nil {
		return "", err
	}
	parent, err := p.onto(size)
	if err != nil {
		return "", err
	}
	keep := true // Whether no commit has changed yet
	for i := size - 1; i >= 0; i-- {
		e := p.entries[i]
		raw := v.raw[e.hash]
		keep = keep && p.action(i, size) == "pick" && firstParent(raw) == parent
		hash := e.hash
		if !keep {
			if hash, err = v.write(rebased(raw, parent, v.now+int64(size-i))); err != nil {
				return "", err
			}
		}
		copies[hash] = i
		parent = hash
	}
	return parent, nil
}

// firstParent returns the hash of the commit object raw's first parent, or "" if it has none.
func firstParent(raw []byte) string {
	header, _, _ := bytes.Cut(raw, []byte("\n\n"))
	for _, line := range strings.Split(string(header), "\n") {
		if parent, ok := strings.CutPrefix(line, "parent "); ok {
			return parent
		}
	}
	return ""
}

// fetch reads the commit objects with the given hashes into v.raw.
func (v *preview) fetch(hashes []string) error {
	if len(hashes) == 0 {
		return nil
	}
	out, err := gitInput(strings.Join(hashes, "\n")+"\n", "cat-file", "--batch")
	if err != nil {
		return err
	}
	// Each object is a line of its hash, type and size, then its contents and a newline.
	for b := []byte(out); len(b) > 0; {
		header, rest, _ := bytes.Cut(b, []byte("\n"))
		fields := strings.Fields(string(header))
		n := -1
		if len(fields) == 3 {
			n, _ = strconv.Atoi(fields[2])
		}
		if n < 0 || len(rest) < n+1 {
			return fmt.Errorf("unexpected output from git cat-file: %q", header)
		}
		v.raw[fields[0]] = rest[:n]
		b = rest[n+1:]
	}
	return nil
}

// rebased returns a copy of the commit object raw with the given parent (or none, if ""), committed at the given time.
// It keeps the tree, author, encoding and message, and drops anything else (e.g. a signature, which wouldn't match).
func rebased(raw []byte, parent string, committed int64) []byte {
	header, message, _ := bytes.Cut(raw, []byte("\n\n"))
	var lines []string
	keep := false // Whether the last header is kept, for the lines continuing it (which start with a space)
	for _, line := range strings.Split(string(header), "\n") {
		if strings.HasPrefix(line, " ") {
			if keep {
				lines = append(lines, line)
			}
			continue
		}
		name, value, _ := strings.Cut(line, " ")
		keep = name == "tree" || name == "author" || name == "encoding"
		switch name {
		case "tree":
			lines = append(lines, line)
			if parent != "" {
				lines = append(lines, "parent "+parent)
			}
		case "committer":
			// The value is the name and email, then the time and time zone.
			fields := strings.Split(value, " ")
			if len(fields) >= 2 {
				fields[len(fields)-2] = strconv.FormatInt(committed, 10)
			}
			lines = append(lines, "committer "+strings.Join(fields, " "))
		default:
			if keep {
				lines = append(lines, line)
			}
		}
	}
	return append([]byte(strings.Join(lines, "\n")+"\n\n"), message...)
}

// write stores a commit object in v.dir, and returns its hash.
func (v *preview) write(content []byte) (string, error) {
	obj := append(fmt.Appendf(nil, "commit %d\x00", len(content)), content...)
	var sum []byte
	if v.sha256 {
		s := sha256.Sum256(obj)
		sum = s[:]
	} else {
		s := sha1.Sum(obj)
		sum = s[:]
	}
	hash := hex.EncodeToString(sum)
	path := filepath.Join(v.dir, hash[:2], hash[2:])
	if _, err := os.Stat(path); err == nil {
		return hash, nil // Already written for an earlier view
	}
	var b bytes.Buffer
	w := zlib.NewWriter(&b)
	w.Write(obj)
	if err := w.Close(); err != nil {
		return "", err
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return "", err
	}
	return hash, os.WriteFile(path, b.Bytes(), 0o400)
}
