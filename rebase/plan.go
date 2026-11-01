package main

import (
	"errors"
	"fmt"
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
	pushed  bool // Whether the upstream branch contains the commit, so rewriting it would need a force-push
}

type entry struct {
	commit
	action string // Empty if not marked, in which case the commit is picked if it falls within the rebase.
	orig   int    // Position in the history (0 for HEAD), to tell whether the entry has been moved
}

// plan is HEAD's history (following first parents, newest first) as the user is arranging it.
type plan struct {
	entries  []entry
	complete bool // Whether entries reach the root commit
}

func (p *plan) add(commits []commit) {
	for _, c := range commits {
		p.entries = append(p.entries, entry{commit: c, orig: len(p.entries)})
	}
}

// size returns how many entries (from the top) the rebase covers: everything down to the oldest entry that is marked
// or out of its original position. All the entries below that are then in their original order, so the first of them
// is the commit the rebase starts from.
//
// If a squash/fixup would otherwise have nothing below it to fold into (only drops, or nothing at all), the rebase also
// covers the next commit down, so marking the commit just above the one to fold into is enough.
func (p *plan) size() int {
	n := 0
	for i, e := range p.entries {
		if e.action != "" || e.orig != i {
			n = i + 1
		}
	}
	for i := n - 1; i >= 0 && n < len(p.entries); i-- {
		if a := p.entries[i].action; a == "squash" || a == "fixup" {
			return n + 1
		} else if a != "drop" {
			break
		}
	}
	return n
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

// base returns the commit the rebase starts from, or "" if the rebase includes the root commit.
func (p *plan) base(size int) (string, error) {
	switch {
	case size < len(p.entries):
		return p.entries[size].hash, nil
	case p.complete:
		return "", nil
	}
	return "", errors.New("the commit below the rebase hasn't been loaded yet")
}

// todo returns the todo list for `git rebase -i` (oldest commit first), after checking git can carry it out.
func (p *plan) todo(size int) (string, error) {
	if size == 0 {
		return "", errors.New("nothing to rebase: mark a commit first")
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

// pushed returns how many commits the rebase would rewrite that the upstream branch already contains. git keeps
// (fast-forwards) picks below the oldest change, so only commits from that change upwards count.
func (p *plan) pushed() int {
	changed := 0
	for i, e := range p.entries {
		if (e.action != "" && e.action != "pick") || e.orig != i {
			changed = i + 1
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
