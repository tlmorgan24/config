package main

// checkout is an interactive `git checkout` of any commit, built from the same program as rebase (under the name
// checkout, see main), as it's the same list without the rebase: the history as it is (a graph of all branches), with
// a preview of the commit under the cursor. The cursor starts on HEAD, and enter checks out the commit under it, which
// leaves HEAD detached there, as `git checkout <commit>` does.
//
// Usage:
//
//	checkout [<git checkout args>]
//
// With any arguments, it just runs `git checkout` with them instead, without the list.

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
)

func checkoutMain() {
	status, err := runCheckout(os.Args[1:])
	if err != nil {
		fmt.Fprintln(os.Stderr, "checkout:", err)
		os.Exit(1)
	}
	os.Exit(status)
}

// runCheckout returns the exit status of `git checkout`, or 0 if the user quit without checking anything out. With any
// args, it runs `git checkout` with them straight away.
func runCheckout(args []string) (int, error) {
	if len(args) > 0 {
		return interactive(exec.Command("git", append([]string{"checkout"}, args...)...))
	}
	// Unlike the rebase, this doesn't need checkRepo's check that no rebase is in progress, as git checks for itself
	// whether it can check out (e.g. without overwriting changes).
	if _, err := git("rev-parse", "--verify", "--quiet", "HEAD"); err != nil {
		return 0, errors.New("no commits to check out: perhaps you are not in a git repository")
	}
	h, err := newHistory()
	if err != nil {
		return 0, err
	}
	// There's nothing to arrange, so the plan has no entries, and nothing more to load into it.
	res, err := choose(&plan{complete: true}, h, true)
	if err != nil || res.commit == "" {
		return 0, err
	}
	return interactive(exec.Command("git", "checkout", res.commit))
}
