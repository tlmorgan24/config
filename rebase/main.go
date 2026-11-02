// rebase is an interactive `git rebase -i` that lists the history as it will be once rebased: a graph of all branches
// (newest first, like my `switch` and `checkout` in .zshrc), with a preview of the commit under the cursor. Mark the
// current branch's commits with an action (pick, reword, edit, squash, fixup or drop) and move them up and down, and
// the rebase starts just below the oldest commit marked or moved, so its base doesn't need to be known upfront. To move
// the branch onto another commit (`git rebase --onto`), choose that commit as the base, and optionally where on the
// branch the rebase stops (the cutoff). Labels that only follow from the rest of the plan (commits picked because
// they're in the rebase, and a base or cutoff that's just where it stops) are faint, as their keys have nothing to
// undo.
//
// Usage:
//
//	rebase
//
// Once confirmed, the todo list is handed to `git rebase -i --autostash` (through $GIT_SEQUENCE_EDITOR), so git carries
// out the rebase as usual: stopping at edits and conflicts for `git rebase --continue` or `git rebase --abort`.
package main

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

const pageSize = 200 // Commits loaded from the history at a time, as it can be far longer than anyone scrolls

func main() {
	if len(os.Args) > 1 {
		fmt.Fprintln(os.Stderr, "usage: rebase")
		os.Exit(2)
	}
	status, err := run()
	if err != nil {
		fmt.Fprintln(os.Stderr, "rebase:", err)
		os.Exit(1)
	}
	os.Exit(status)
}

// run returns the exit status of `git rebase`, or 0 if the user quit without rebasing.
func run() (int, error) {
	if _, err := git("rev-parse", "--verify", "--quiet", "HEAD"); err != nil {
		return 0, errors.New("no commits to rebase: perhaps you are not in a git repository")
	}
	for _, dir := range []string{"rebase-merge", "rebase-apply"} {
		path, err := git("rev-parse", "--git-path", dir)
		if err != nil {
			return 0, err
		}
		if _, err := os.Stat(strings.TrimSpace(path)); err == nil {
			return 0, errors.New("a rebase is already in progress (finish it with git rebase --continue or --abort)")
		}
	}

	h, err := newHistory()
	if err != nil {
		return 0, err
	}
	p := &plan{}
	if err := h.fill(p, pageSize); err != nil {
		return 0, err
	}
	todo, onto, cutoff, err := choose(p, h)
	if err != nil || todo == "" {
		return 0, err
	}
	return rebase(todo, onto, cutoff)
}

// history loads HEAD's history into a plan as the user scrolls down it.
type history struct {
	unpushed map[string]bool // Local commits that no remote-tracking branch contains (e.g. origin/main)
}

func newHistory() (*history, error) {
	out, err := git("rev-list", "--all", "--not", "--remotes")
	if err != nil {
		return nil, err
	}
	h := &history{unpushed: map[string]bool{}}
	for _, hash := range strings.Fields(out) {
		h.unpushed[hash] = true
	}
	return h, nil
}

// fill loads commits into p until it has at least n entries or reaches the root commit.
func (h *history) fill(p *plan, n int) error {
	for !p.complete && len(p.entries) < n {
		count := max(pageSize, n-len(p.entries))
		// Separate fields with NUL, which can't appear in any of them, and commits with newlines (%s is one line).
		out, err := git("log", "--first-parent", "--format=%H%x00%h%x00%P%x00%D%x00%s",
			fmt.Sprintf("--skip=%d", len(p.entries)), fmt.Sprintf("--max-count=%d", count), "HEAD")
		if err != nil {
			return err
		}
		var commits []commit
		for _, line := range strings.Split(strings.TrimSuffix(out, "\n"), "\n") {
			fields := strings.Split(line, "\x00")
			if len(fields) != 5 {
				continue // Only the empty line of an empty result, so nothing is lost.
			}
			c := commit{hash: fields[0], short: fields[1], parents: len(strings.Fields(fields[2])), refs: fields[3],
				subject: fields[4]}
			commits = append(commits, c)
		}
		p.add(commits)
		p.complete = len(commits) < count
	}
	return nil
}

// rebase runs `git rebase -i` with the given todo list in place of the one git would open in an editor. It rebases
// onto onto, or (if that's empty) onto cutoff, which is where the rebase stops; an empty cutoff rebases from the root
// commit.
func rebase(todo, onto, cutoff string) (int, error) {
	f, err := os.CreateTemp("", "rebase-todo-")
	if err != nil {
		return 0, err
	}
	defer os.Remove(f.Name())
	if _, err := f.WriteString(todo); err != nil {
		f.Close()
		return 0, err
	}
	if err := f.Close(); err != nil {
		return 0, err
	}

	args := []string{"rebase", "--interactive", "--autostash"}
	if onto != "" {
		args = append(args, "--onto", onto)
	}
	if cutoff == "" {
		args = append(args, "--root")
	} else {
		args = append(args, cutoff)
	}
	cmd := exec.Command("git", args...)
	// git runs the sequence editor with the todo file's path as its last argument, so this copies ours over it. Only
	// this rebase uses it: a later `git rebase --edit-todo` (or `--continue`, after a stop) opens the usual editor.
	cmd.Env = append(os.Environ(), "GIT_SEQUENCE_EDITOR=cp "+shellQuote(f.Name()))
	cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr
	err = cmd.Run()
	var exitErr *exec.ExitError
	if errors.As(err, &exitErr) {
		return exitErr.ExitCode(), nil // git has already explained what went wrong.
	}
	return 0, err
}

// git runs git and returns its output, or an error that includes what git printed to stderr.
func git(args ...string) (string, error) {
	return gitCmd(exec.Command("git", args...))
}

// gitWith runs git like git does, with the given environment.
func gitWith(env []string, args ...string) (string, error) {
	cmd := exec.Command("git", args...)
	cmd.Env = env
	return gitCmd(cmd)
}

// gitInput runs git like git does, with the given input.
func gitInput(input string, args ...string) (string, error) {
	cmd := exec.Command("git", args...)
	cmd.Stdin = strings.NewReader(input)
	return gitCmd(cmd)
}

func gitCmd(cmd *exec.Cmd) (string, error) {
	out, err := cmd.Output()
	var exitErr *exec.ExitError
	if errors.As(err, &exitErr) && len(exitErr.Stderr) > 0 {
		return "", fmt.Errorf("git %s: %s", cmd.Args[1], strings.TrimSpace(string(exitErr.Stderr)))
	}
	return string(out), err
}

func shellQuote(s string) string {
	return "'" + strings.ReplaceAll(s, "'", `'\''`) + "'"
}
