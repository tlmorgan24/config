package main

// drop is an interactive way to remove commits from history, built from the same program as rebase (under the name
// drop, see main), as it's a rebase whose list starts off with the commits to drop already marked. Everything else is
// as in rebase: the drops can be changed, other commits marked or moved, and the rebase starts just below the oldest
// commit marked or moved.
//
// Usage:
//
//	drop [<commit> | <upstream>..<commit>]...
//
// The arguments are commits and ranges, as in `git cherry-pick`, and start the list off with the commits they name
// marked drop: `drop HEAD` drops the newest commit, and `drop HEAD~3..` the newest three (following first parents).
//
// Once confirmed, the todo list is handed to `git rebase -i --autostash`, so git carries out the drops as a rebase:
// stopping at conflicts (from later commits that depend on a dropped one) for `git rebase --continue` or
// `git rebase --abort`.

import (
	"cmp"
	"fmt"
	"os"
	"strings"
)

func dropMain() {
	revs := os.Args[1:]
	for _, rev := range revs {
		if strings.HasPrefix(rev, "-") {
			fmt.Fprintln(os.Stderr, "usage: drop [<commit> | <upstream>..<commit>]...")
			os.Exit(2)
		}
	}
	status, err := run("drop", func(h *history, p *plan) error { return h.presetDrop(p, revs) })
	if err != nil {
		fmt.Fprintln(os.Stderr, "drop:", err)
		os.Exit(1)
	}
	os.Exit(status)
}

// presetDrop marks the commits that revs (as in `git cherry-pick <revs>`) name drop, as if the user had marked them,
// so they can be changed as usual. Each must be one of the current branch's commits (following first parents).
func (h *history) presetDrop(p *plan, revs []string) error {
	for _, rev := range revs {
		_, commits, err := revCommits(rev, "drop")
		if err != nil {
			return err
		}
		for _, c := range commits {
			n, err := countNotIn(c.hash)
			if err != nil {
				return err
			}
			if err := h.fill(p, n+1); err != nil {
				return err
			}
			// Otherwise it isn't one of HEAD's first parents, so isn't in the list (n is then where it was merged).
			if n >= len(p.entries) || p.entries[n].hash != c.hash {
				return fmt.Errorf("can't drop %s, as it isn't one of the current branch's commits", c.short)
			}
			p.entries[n].action = "drop"
			if err := checkPreset(p, "drop", c); err != nil {
				return err
			}
		}
	}
	return nil
}

// revCommits returns the commit that rev (a commit, or a range a..b with either side HEAD if left out) names, or the
// range's b, and the commits it names (newest first): b's first-parent commits that a doesn't have. An empty range is
// an error saying there's nothing to do (verb, e.g. drop).
func revCommits(rev, verb string) (commit, []commit, error) {
	upstream, tip, isRange := strings.Cut(rev, "..")
	if !isRange {
		tip = rev
	}
	c, err := resolve(cmp.Or(tip, "HEAD"))
	if err != nil {
		return commit{}, nil, err
	}
	if !isRange {
		commits, err := logCommits("-1", c.hash)
		return c, commits, err
	}
	up, err := resolve(cmp.Or(upstream, "HEAD"))
	if err != nil {
		return commit{}, nil, err
	}
	commits, err := logCommits(c.hash, "--not", up.hash)
	if err == nil && len(commits) == 0 {
		err = fmt.Errorf("nothing to %s, as %s already has all of %s's commits", verb, up.short, c.short)
	}
	return c, commits, err
}
