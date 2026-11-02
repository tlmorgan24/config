package main

// cherry is an interactive `git cherry-pick`, built from the same program as rebase (under the name cherry, see main),
// as it's a rebase whose todo list picks other branches' commits. It lists the history (a graph of all branches) as it
// will be once cherry-picked, with a preview of the commit under the cursor. Marking a commit with an action, as in
// rebase, cherry-picks it, whichever branch it's on: p picks it as it is, and r, e, s and f also reword, edit, squash
// or fixup its copy. ⇧p also picks the commits between it and the commit last marked (following first parents), like
// shift-clicking selects everything up to the click. Each newly marked commit goes on top of the others, so it's
// cherry-picked last, and they can be moved up and down as in rebase. Their copies show on top of HEAD, where
// cherry-picking always puts them, while the commits themselves show where they are, labelled copied. Unmarking a
// commit takes it back out, with u or d, as dropping it would be the same as not picking it.
//
// Usage:
//
//	cherry [<commit> | <upstream>..<commit>]...
//
// The arguments are those of `git cherry-pick` (commits and ranges), and start the list off with the commits they name
// picked, in the same order: `cherry feature` picks just feature, and `cherry main..feature` all of feature's commits
// that main doesn't have (following first parents).
//
// Once confirmed, the todo list is handed to `git rebase -i --autostash HEAD`, so git carries out the cherry-pick as a
// rebase: stopping at edits and conflicts for `git rebase --continue` or `git rebase --abort`.

import (
	"cmp"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"slices"
	"strings"
)

func cherryMain() {
	revs := os.Args[1:]
	for _, rev := range revs {
		if strings.HasPrefix(rev, "-") {
			fmt.Fprintln(os.Stderr, "usage: cherry [<commit> | <upstream>..<commit>]...")
			os.Exit(2)
		}
	}
	status, err := runCherry(revs)
	if err != nil {
		fmt.Fprintln(os.Stderr, "cherry:", err)
		os.Exit(1)
	}
	os.Exit(status)
}

// runCherry returns the exit status of `git rebase`, or 0 if the user quit without cherry-picking. It starts the list
// off with the commits that revs (`git cherry-pick` arguments) name picked (see presetCherry).
func runCherry(revs []string) (int, error) {
	if err := checkRepo("cherry-pick onto"); err != nil {
		return 0, err
	}
	head, err := resolve("HEAD")
	if err != nil {
		return 0, err
	}
	h, err := newHistory()
	if err != nil {
		return 0, err
	}
	p := &plan{cherry: true, complete: true, base: head}
	if err := presetCherry(p, revs); err != nil {
		return 0, err
	}
	todo, _, upstream, err := choose(p, h)
	if err != nil || todo == "" {
		return 0, err
	}
	return rebase(todo, "", upstream)
}

// presetCherry picks the commits that revs (as in `git cherry-pick <revs>`) name, in the same order, as if the user had
// picked them, so they can be changed as usual. A range a..b (with either side HEAD if left out) names b's first-parent
// commits that a doesn't have.
func presetCherry(p *plan, revs []string) error {
	for _, rev := range revs {
		upstream, tip, isRange := strings.Cut(rev, "..")
		if !isRange {
			tip = rev
		}
		c, err := resolve(cmp.Or(tip, "HEAD"))
		if err != nil {
			return err
		}
		var commits []commit
		if isRange {
			up, err := resolve(cmp.Or(upstream, "HEAD"))
			if err != nil {
				return err
			}
			if commits, err = logCommits(c.hash, "--not", up.hash); err != nil {
				return err
			}
			if len(commits) == 0 {
				return fmt.Errorf("nothing to cherry-pick, as %s already has all of %s's commits", up.short, c.short)
			}
		} else if commits, err = logCommits("-1", c.hash); err != nil {
			return err
		}
		// The others are all newer, so the current branch doesn't have them either if it doesn't have the oldest.
		oldest := commits[len(commits)-1]
		if err := notInHead("pick", oldest.hash, oldest.short); err != nil {
			return err
		}
		p.insert(0, commits, "pick")
		p.last = c.hash
		if err := checkPreset(p, "pick", c); err != nil {
			return err
		}
	}
	return nil
}

// pickCommit marks the commit with the given hash and short hash with action, adding it to the entries (on top, so
// it's cherry-picked last) if it isn't already one of them, and makes it the commit last marked.
func pickCommit(p *plan, hash, short, action string) error {
	if i := p.index(hash); i >= 0 {
		p.entries[i].action = action
		p.last = hash
		return nil
	}
	if err := notInHead(action, hash, short); err != nil {
		return err
	}
	commits, err := logCommits("-1", hash)
	if err != nil {
		return err
	}
	p.insert(0, commits, action)
	p.last = hash
	return nil
}

// pickBack picks the commit with the given hash and short hash, and the commits between it and the commit last marked
// (following the first parents of whichever of them is newer), then makes it the commit last marked. Those not already
// entries go next to the commit last marked, above or below it as they are in the history, so they're cherry-picked
// in the same order.
func pickBack(p *plan, hash, short string) error {
	last := p.index(p.last)
	if last < 0 || p.last == hash {
		return pickCommit(p, hash, short, "pick")
	}
	if err := notInHead("pick", hash, short); err != nil {
		return err
	}
	at := last
	commits, err := between(p.last, hash)
	if err == nil && commits == nil {
		at = last + 1
		commits, err = between(hash, p.last)
	}
	if err != nil {
		return err
	}
	if commits == nil {
		return fmt.Errorf("can't pick %s back to %s, as neither is below the other", short, p.entries[last].short)
	}
	p.insert(at, commits, "pick")
	p.last = hash
	return nil
}

// insert adds those of commits (newest first) that aren't already entries at position at, marked with action.
func (p *plan) insert(at int, commits []commit, action string) {
	var added []entry
	for _, c := range commits {
		if p.index(c.hash) < 0 {
			added = append(added, entry{commit: c, action: action})
		}
	}
	p.entries = slices.Insert(p.entries, at, added...)
}

// unpick takes entry i back out of the commits to cherry-pick.
func (p *plan) unpick(i int) {
	if p.entries[i].hash == p.last {
		p.last = ""
	}
	p.entries = slices.Delete(p.entries, i, i+1)
}

// notInHead returns an error saying the user can't do what (an action) to the commit with the given hash and short hash
// if the current branch already has it, or nil if it doesn't.
func notInHead(what, hash, short string) error {
	has, err := isAncestor(hash, "HEAD")
	if err == nil && has {
		return errors.New(cant(what, short) + ", as the current branch already has it")
	}
	return err
}

// between returns the commits from from to to (newest first), following to's first parents, or nil if from isn't one
// of them.
func between(from, to string) ([]commit, error) {
	// Check from is below to first, as otherwise git would list all of to's history.
	if ok, err := isAncestor(from, to); err != nil || !ok {
		return nil, err
	}
	commits, err := logCommits(to, "--not", from+"^@") // from's parents, of which a root commit has none
	if err != nil || len(commits) == 0 || commits[len(commits)-1].hash != from {
		return nil, err // It isn't one of to's first parents, but is merged into one of them.
	}
	return commits, nil
}

// isAncestor returns whether the commit a is b or one of its ancestors.
func isAncestor(a, b string) (bool, error) {
	_, err := git("merge-base", "--is-ancestor", a, b)
	var exitErr *exec.ExitError
	if errors.As(err, &exitErr) && exitErr.ExitCode() == 1 {
		return false, nil
	}
	return err == nil, err
}
