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
	pushed  bool // Whether a remote-tracking branch contains the commit, so others may already have it
}

type entry struct {
	commit
	action string // Empty if not marked, in which case the commit is picked if it falls within the rebase.
	orig   int    // Position in the history (0 for HEAD), to tell whether the entry has been moved
}

// plan is HEAD's history (following first parents, newest first) as the user is arranging it, and where it goes.
type plan struct {
	entries  []entry
	complete bool // Whether entries reach the root commit
	// The commit chosen (with b) to rebase onto, or no commit (an empty hash) to keep the rebase where it is, on top of
	// the commit it stops at
	base     commit
	baseSize int    // How many entries the base doesn't contain (0 without a base), all of which the rebase covers
	cutoff   string // Hash of the entry chosen (with c) for the rebase to stop at, or "" to work it out
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
	if p.cutoff != "" {
		return max(p.index(p.cutoff), 0)
	}
	n := 0
	for i, e := range p.entries {
		if e.action != "" || e.orig != i {
			n = i + 1
		}
	}
	for i := n - 1; i >= 0 && n < len(p.entries); i-- {
		if a := p.entries[i].action; a == "squash" || a == "fixup" {
			n++
			break
		} else if a != "drop" {
			break
		}
	}
	return max(n, p.baseSize)
}

// index returns the position of the entry with the given hash, or -1 if it isn't loaded.
func (p *plan) index(hash string) int {
	return slices.IndexFunc(p.entries, func(e entry) bool { return e.hash == hash })
}

// check returns why the plan doesn't work as arranged, for problems worth knowing about as soon as they're made (the
// todo list's own checks wait until it's confirmed).
func (p *plan) check() error {
	size := p.size()
	if p.cutoff != "" {
		for i := size; i < len(p.entries); i++ {
			if e := p.entries[i]; e.action != "" || e.orig != i {
				return fmt.Errorf("%s isn't above the cutoff, so it can't be marked or moved", e.short)
			}
		}
	}
	for _, e := range p.entries[:size] {
		if e.hash == p.base.hash {
			return fmt.Errorf("can't rebase onto %s, as it's one of the commits being rebased", e.short)
		}
	}
	return nil
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
	if size == 0 {
		return "", errors.New("nothing to rebase")
	}
	var b strings.Builder
	folded := false // Whether an earlier line keeps a commit that squash/fixup can fold into
	for i := size - 1; i >= 0; i-- {
		e := p.entries[i]
		action := p.action(i, size)
		// A plain `git rebase -i` flattens merges, and its todo list can't pick a merge commit.
		if e.parents > 1 {
			return "", fmt.Errorf("%s is a merge commit, so it can't be part of the rebase", e.short)
		}
		if (action == "squash" || action == "fixup") && !folded {
			return "", fmt.Errorf("can't %s %s, as there's no older commit in the rebase to fold it into", action, e.short)
		}
		if action != "drop" {
			folded = true
		}
		fmt.Fprintf(&b, "%s %s %s\n", action, e.hash, e.subject)
	}
	return b.String(), nil
}

// pushed returns how many commits the rebase would rewrite that a remote-tracking branch already contains. Moving onto
// a new base rewrites them all, but otherwise git keeps (fast-forwards) picks below the oldest change, so only commits
// from that change upwards count.
func (p *plan) pushed() int {
	size := p.size()
	changed := 0
	if p.moves(size) {
		changed = size
	} else {
		for i, e := range p.entries {
			if (e.action != "" && e.action != "pick") || e.orig != i {
				changed = i + 1
			}
		}
	}
	n := 0
	for _, e := range p.entries[:changed] {
		if e.pushed {
			n++
		}
	}
	return n
}
