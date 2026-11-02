package main

import (
	"errors"
	"fmt"
	"slices"
	"strings"
)

// actionKeys maps each key to the todo-list action it marks a commit with (the same letters as git's own abbreviations).
var actionKeys = map[string]string{"p": "pick", "r": "reword", "e": "edit", "s": "squash", "f": "fixup", "d": "drop"}

type commit struct {
	hash    string
	short   string
	parents int
	refs    string // Branch and tag names pointing at the commit, as in `git log --decorate`
	subject string
}

type entry struct {
	commit
	action string // Empty if not marked, in which case the commit is picked if it falls within the rebase.
	orig   int    // Position in the history (0 for HEAD), to tell whether the entry has been moved
}

// plan is HEAD's history (following first parents, newest first) as the user is arranging it, and where it goes.
//
// When cherry-picking, entries are instead the commits marked to cherry-pick, from any branch, all of which the rebase
// covers, and the base is HEAD, which they go on top of.
type plan struct {
	entries  []entry
	complete bool // Whether entries reach the root commit (always, when cherry-picking, as nothing more is loaded)
	// The commit chosen (with b) to rebase onto, or no commit (an empty hash) to keep the rebase where it is, on top of
	// the commit it stops at
	base     commit
	baseSize int    // How many entries the base doesn't contain (0 without a base), all of which the rebase covers
	cutoff   string // Hash of the entry chosen (with c) for the rebase to stop at, or "" to work it out
	cherry   bool   // Whether the plan is for cherry-picking (see pick.go) rather than rebasing
	last     string // When cherry-picking, hash of the entry last marked, which ⇧p picks back to ("" for none)
}

func (p *plan) add(commits []commit) {
	for _, c := range commits {
		p.entries = append(p.entries, entry{commit: c, orig: len(p.entries)})
	}
}

// clone returns a copy of p, to go back to if a change doesn't work.
func (p *plan) clone() *plan {
	c := *p
	c.entries = slices.Clone(p.entries)
	return &c
}

// size returns how many entries (from the top) the rebase covers. With a cutoff, that's the entries above it.
// Otherwise it's everything down to the oldest entry that is marked or out of its original position, and at least
// the entries the base doesn't contain (like `git rebase <base>`). All the entries below that are then in their
// original order, so the first of them is the commit the rebase stops at.
//
// Without a cutoff, if a squash/fixup would otherwise have nothing below it to fold into (only drops, or nothing at
// all), the rebase also covers the next commit down, so marking the commit just above the one to fold into is enough.
func (p *plan) size() int {
	if p.cherry {
		return len(p.entries)
	}
	if p.cutoff != "" {
		return max(p.index(p.cutoff), 0)
	}
	n := p.oldest() + 1
	if n < len(p.entries) && p.unfolded(n) >= 0 {
		n++
	}
	return max(n, p.baseSize)
}

// index returns the position of the entry with the given hash, or -1 if it isn't loaded.
func (p *plan) index(hash string) int {
	return slices.IndexFunc(p.entries, func(e entry) bool { return e.hash == hash })
}

// conflict is why a plan doesn't work as arranged: the rebase covers the commit it stops at (the base or the cutoff),
// a squash/fixup would have nothing to fold into, as only drops are between it and that commit (or, when
// cherry-picking, below it), or the rebase covers a merge commit, which a plain `git rebase -i` can't keep.
type conflict struct {
	// Position of the commit the rebase stops at (unused for a merge commit, and -1 when cherry-picking, as it stops at
	// HEAD, which isn't an entry)
	stop  int
	base  bool // Whether that commit is the base, rather than the cutoff
	entry int  // Position of the commit that's marked or moved at or below it, the squash/fixup or the merge commit
	fold  bool // Whether entry is the squash/fixup
	merge bool // Whether entry is the merge commit
}

// check returns why the plan doesn't work as arranged, for problems worth knowing about as soon as they're made (the
// todo list's own checks wait until it's confirmed), or nil if it works.
func (p *plan) check() *conflict {
	size := p.size()
	if c := p.index(p.cutoff); c >= 0 {
		if i := p.oldest(); i >= c {
			return &conflict{stop: c, entry: i}
		}
		if i := p.unfolded(c); i >= 0 {
			return &conflict{stop: c, entry: i, fold: true}
		}
	}
	if b := p.index(p.base.hash); b >= 0 && b < size {
		if i := p.oldest(); i >= b {
			return &conflict{stop: b, base: true, entry: i}
		}
		if i := p.unfolded(b); i >= 0 {
			return &conflict{stop: b, base: true, entry: i, fold: true}
		}
		return &conflict{stop: b, base: true, entry: -1}
	}
	// git can't fold into HEAD, as the todo list starts after it.
	if i := p.unfolded(len(p.entries)); p.cherry && i >= 0 {
		return &conflict{stop: -1, entry: i, fold: true}
	}
	for i, e := range p.entries[:min(size, len(p.entries))] {
		if e.parents > 1 {
			return &conflict{entry: i, merge: true}
		}
	}
	return nil
}

// explain returns why the user can't do what they tried to the commit with the given hash and short hash, given the
// conflict it would cause. what is an action, "unmark", "move", "base" or "cutoff".
func (p *plan) explain(c conflict, what, hash, short string) string {
	i := p.index(hash) // -1 for a base that isn't on the current branch
	tried := cant(what, short)
	if c.merge {
		if i >= 0 && i < p.size() && p.entries[i].parents > 1 {
			return tried + ", as it's a merge commit"
		}
		covered := "in the rebase"
		if p.cherry {
			covered = "cherry-picked"
		}
		return fmt.Sprintf("%s, as merge commit %s would then be %s", tried, p.entries[c.entry].short, covered)
	}
	if c.stop < 0 {
		who := p.entries[c.entry].short
		if c.entry == i {
			who = "it"
		}
		return tried + ", as " + who + " would then have nothing to fold into"
	}
	stop := p.entries[c.stop]
	role := "cutoff"
	if c.base {
		role = "base"
	}
	switch {
	case c.entry < 0:
		return tried + ", as the base would be one of the commits being rebased"
	case what == "base" || what == "cutoff":
		if c.fold {
			e := p.entries[c.entry]
			return fmt.Sprintf(`%s while %s above it is marked "%s"`, tried, e.short, e.action)
		}
		return tried + " while " + p.marked(c.entry, c.stop)
	case c.fold && c.entry == i && (what == "squash" || what == "fixup"):
		return fmt.Sprintf("%s while %s below it is the %s", tried, stop.short, role)
	case c.fold:
		who := p.entries[c.entry].short
		if c.entry == i {
			who = "it"
		}
		return tried + ", as " + who + " would then have nothing to fold into"
	case hash == stop.hash:
		return tried + " while it's the " + role
	case p.entries[i].orig < stop.orig:
		// It was above where the rebase stops (as all the entries below are in their original positions until a
		// change), so the change moves it below.
		return fmt.Sprintf("%s below the %s %s", tried, role, stop.short)
	}
	return fmt.Sprintf("%s while it's below the %s %s", tried, role, stop.short)
}

// cant starts an error saying the user can't do what they tried (see explain) to the commit with the given short hash.
func cant(what, short string) string {
	if what == "base" || what == "cutoff" {
		return fmt.Sprintf("can't make %s the %s", short, what)
	}
	return fmt.Sprintf("can't %s %s", what, short)
}

// oldest returns the position of the oldest entry that is marked or out of its original position, or -1 for none.
func (p *plan) oldest() int {
	for i := len(p.entries) - 1; i >= 0; i-- {
		if e := p.entries[i]; e.action != "" || e.orig != i {
			return i
		}
	}
	return -1
}

// unfolded returns the position of the squash/fixup that would have nothing to fold into if the rebase covered only
// the first n entries (as only drops are below it), or -1 for none.
func (p *plan) unfolded(n int) int {
	for i := n - 1; i >= 0; i-- {
		if a := p.entries[i].action; a == "squash" || a == "fixup" {
			return i
		} else if a != "drop" {
			return -1
		}
	}
	return -1
}

// marked describes entry i as marked or moved, for an error about entry at, which is entry i or above it. It doesn't
// say what with, as any mark is a problem, even pick.
func (p *plan) marked(i, at int) string {
	marked := p.entries[i].action != ""
	switch {
	case i == at && marked:
		return "it's marked"
	case i == at:
		return "it's been moved"
	case marked:
		return p.entries[i].short + " below it is marked"
	}
	return p.entries[i].short + " below it has been moved"
}

// action returns what entry i does in the todo list, or "" if it is below the rebase.
func (p *plan) action(i, size int) string {
	switch {
	case i >= size:
		return ""
	case p.entries[i].action == "":
		return "pick"
	}
	return p.entries[i].action
}

// setBase makes c the base, with size the number of entries it doesn't contain (see baseSize). It replaces a cutoff at
// or below it, which would put it back in the rebase, so a base among the commits being rebased stops the rebase there
// instead (unless commits below it are marked or moved, which check catches).
func (p *plan) setBase(c commit, size int) {
	if i := p.index(c.hash); i >= 0 && p.index(p.cutoff) >= i {
		p.cutoff = ""
	}
	p.base, p.baseSize = c, size
}

// setCutoff makes the entry with the given hash the cutoff. It replaces a base at or above it, which would be in the
// rebase, so a cutoff below a base on the current branch extends the rebase instead.
func (p *plan) setCutoff(hash string) {
	if i := p.index(p.base.hash); i >= 0 && i <= p.index(hash) {
		p.base, p.baseSize = commit{}, 0
	}
	p.cutoff = hash
}

// swap moves entry i to position j and vice versa.
func (p *plan) swap(i, j int) {
	p.entries[i], p.entries[j] = p.entries[j], p.entries[i]
}

// cutoffAt returns the commit the rebase stops at (git's upstream), or "" if the rebase includes the root commit.
func (p *plan) cutoffAt(size int) (string, error) {
	switch {
	case size < len(p.entries):
		return p.entries[size].hash, nil
	case p.complete:
		return "", nil
	}
	return "", errors.New("the commit below the rebase hasn't been loaded yet")
}

// onto returns the commit the rebase puts its commits on top of, or "" for none (a new root commit).
func (p *plan) onto(size int) (string, error) {
	if p.base.hash != "" {
		return p.base.hash, nil
	}
	return p.cutoffAt(size)
}

// moves returns whether the rebase moves its commits onto a different commit, rather than keeping them where they are.
func (p *plan) moves(size int) bool {
	cutoff, err := p.cutoffAt(size)
	return p.base.hash != "" && (err != nil || cutoff != p.base.hash)
}

// todo returns the todo list for `git rebase -i` (oldest commit first), after checking git can carry it out.
func (p *plan) todo(size int) (string, error) {
	switch {
	case size > 0:
	case p.cherry:
		return "", errors.New("can't cherry-pick, as no commits are picked")
	case p.cutoff != "":
		return "", errors.New("can't rebase, as nothing is above the cutoff")
	case p.base.hash != "":
		return "", fmt.Errorf("can't rebase, as %s already has all of the current branch's commits", p.base.short)
	default:
		return "", errors.New("can't rebase, as nothing is marked or moved")
	}
	var b strings.Builder
	folded := false // Whether an earlier line keeps a commit that squash/fixup can fold into
	for i := size - 1; i >= 0; i-- {
		e := p.entries[i]
		action := p.action(i, size)
		// A plain `git rebase -i` flattens merges, and its todo list can't pick a merge commit.
		if e.parents > 1 {
			return "", fmt.Errorf("can't rebase %s, as it's a merge commit", e.short)
		}
		if (action == "squash" || action == "fixup") && !folded {
			return "", fmt.Errorf(`can't rebase, as %s is marked "%s" with nothing below it to fold into`, e.short, action)
		}
		if action != "drop" {
			folded = true
		}
		fmt.Fprintf(&b, "%s %s %s\n", action, e.hash, e.subject)
	}
	return b.String(), nil
}
