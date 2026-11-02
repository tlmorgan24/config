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
//	rebase [--onto <newbase>] [<upstream>]
//
// The arguments are those of `git rebase`, and start the list off with the base and cutoff they imply, which can then
// be changed as usual: `rebase main` makes main the base, and `rebase --onto main feature` also makes the cutoff where
// the current branch meets feature. Without them, the rebase starts just below the oldest commit marked or moved,
// rather than at the branch's upstream as `git rebase` does. -i is accepted out of habit, as the rebase is always
// interactive.
//
// Once confirmed, the todo list is handed to `git rebase -i --autostash` (through $GIT_SEQUENCE_EDITOR), so git carries
// out the rebase as usual: stopping at edits and conflicts for `git rebase --continue` or `git rebase --abort`.
//
// Built under the name cherry, the same program is an interactive `git cherry-pick` instead (see cherry.go).
package main

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
)

const pageSize = 200 // Commits loaded from the history at a time, as it can be far longer than anyone scrolls

func main() {
	if filepath.Base(os.Args[0]) == "cherry" {
		cherryMain()
		return
	}
	onto, upstream, ok := parseArgs(os.Args[1:])
	if !ok {
		fmt.Fprintln(os.Stderr, "usage: rebase [--onto <newbase>] [<upstream>]")
		os.Exit(2)
	}
	status, err := run(onto, upstream)
	if err != nil {
		fmt.Fprintln(os.Stderr, "rebase:", err)
		os.Exit(1)
	}
	os.Exit(status)
}

// parseArgs returns the base (--onto) and upstream given as `git rebase` arguments ("" for each one not given), and
// whether the arguments are ones this accepts.
func parseArgs(args []string) (onto, upstream string, ok bool) {
	for i := 0; i < len(args); i++ {
		switch arg := args[i]; {
		case arg == "-i" || arg == "--interactive":
		case arg == "--onto" && i+1 < len(args):
			i++
			onto = args[i]
		case strings.HasPrefix(arg, "--onto="):
			onto = strings.TrimPrefix(arg, "--onto=")
		case strings.HasPrefix(arg, "-") || upstream != "":
			return "", "", false // Including git's <branch>, as switching to the branch first does the same.
		default:
			upstream = arg
		}
	}
	// Without an upstream, git would use the branch's (@{upstream}), which the list doesn't start from.
	return onto, upstream, onto == "" || upstream != ""
}

// run returns the exit status of `git rebase`, or 0 if the user quit without rebasing. It starts the list off as
// `git rebase [--onto <onto>] <upstream>` would (see preset).
func run(onto, upstream string) (int, error) {
	if err := checkRepo("rebase"); err != nil {
		return 0, err
	}
	h, err := newHistory()
	if err != nil {
		return 0, err
	}
	p := &plan{}
	if err := h.fill(p, pageSize); err != nil {
		return 0, err
	}
	if err := h.preset(p, onto, upstream); err != nil {
		return 0, err
	}
	todo, newBase, cutoff, err := choose(p, h)
	if err != nil || todo == "" {
		return 0, err
	}
	return rebase(todo, newBase, cutoff)
}

// checkRepo returns why there's nothing to do (verb, e.g. rebase) in the current directory, or nil if there's nothing
// stopping it.
func checkRepo(verb string) error {
	if _, err := git("rev-parse", "--verify", "--quiet", "HEAD"); err != nil {
		return fmt.Errorf("no commits to %s: perhaps you are not in a git repository", verb)
	}
	for _, dir := range []string{"rebase-merge", "rebase-apply"} {
		path, err := git("rev-parse", "--git-path", dir)
		if err != nil {
			return err
		}
		if _, err := os.Stat(strings.TrimSpace(path)); err == nil {
			return errors.New("a rebase is already in progress (finish it with git rebase --continue or --abort)")
		}
	}
	return nil
}

// preset sets the base and cutoff that `git rebase [--onto <onto>] <upstream>` implies, as if the user had chosen
// them, so they can be changed as usual. Without --onto, upstream is the base (like b on it), so the branch moves onto
// it, or (if it's on the branch) the rebase stops there. With --onto, onto is the base, and the cutoff is where the
// branch meets upstream, as git rebases the commits that upstream doesn't contain.
func (h *history) preset(p *plan, onto, upstream string) error {
	if upstream == "" {
		return nil
	}
	up, err := resolve(upstream)
	if err != nil {
		return err
	}
	if onto == "" {
		if err := h.setBase(p, up); err != nil {
			return err
		}
		return checkPreset(p, "base", up)
	}
	base, err := resolve(onto)
	if err != nil {
		return err
	}
	n, err := countNotIn(up.hash)
	if err != nil {
		return err
	}
	if err := h.fill(p, n+1); err != nil {
		return err
	}
	if n >= len(p.entries) {
		return fmt.Errorf("%s has none of the current branch's commits", upstream)
	}
	stop := p.entries[n].commit
	if err := h.setBase(p, base); err != nil {
		return err
	}
	switch i := p.index(base.hash); {
	case i == n:
		return checkPreset(p, "base", base) // The same as no --onto, so it's a base that stops the rebase.
	case i >= 0 && i < n:
		return fmt.Errorf("can't rebase onto %s, as it's one of the commits after %s", onto, upstream)
	}
	p.setCutoff(stop.hash)
	return checkPreset(p, "cutoff", stop)
}

// checkPreset returns why the plan doesn't work with the base or cutoff (what) c that preset has just set, or nil if
// it works.
func checkPreset(p *plan, what string, c commit) error {
	if conflict := p.check(); conflict != nil {
		return errors.New(p.explain(*conflict, what, c.hash, c.short))
	}
	return nil
}

// setBase makes c the base, loading the entries down to the commit the rebase stops at.
func (h *history) setBase(p *plan, c commit) error {
	n, err := countNotIn(c.hash)
	if err != nil {
		return err
	}
	p.setBase(c, n)
	return h.fill(p, n+1)
}

// countNotIn returns how many of HEAD's first-parent commits the commit with the given hash doesn't contain, which is
// also the position of the first that it does.
func countNotIn(hash string) (int, error) {
	out, err := git("rev-list", "--first-parent", "--count", "HEAD", "^"+hash)
	if err != nil {
		return 0, err
	}
	return strconv.Atoi(strings.TrimSpace(out))
}

// resolve returns the commit that rev (e.g. main or HEAD~3) names.
func resolve(rev string) (commit, error) {
	hash, err := git("rev-parse", "--verify", "--quiet", "--end-of-options", rev+"^{commit}")
	if err != nil {
		return commit{}, fmt.Errorf("%s isn't a commit", rev)
	}
	out, err := git("log", "-1", "--format=%H%x00%h%x00%s", strings.TrimSpace(hash))
	if err != nil {
		return commit{}, err
	}
	fields := strings.SplitN(strings.TrimSuffix(out, "\n"), "\x00", 3)
	if len(fields) != 3 {
		return commit{}, fmt.Errorf("unexpected output from git log: %q", out)
	}
	return commit{hash: fields[0], short: fields[1], subject: fields[2]}, nil
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
		commits, err := logCommits(fmt.Sprintf("--skip=%d", len(p.entries)), fmt.Sprintf("--max-count=%d", count), "HEAD")
		if err != nil {
			return err
		}
		p.add(commits)
		p.complete = len(commits) < count
	}
	return nil
}

// logCommits returns the commits that `git log --first-parent` lists with the given arguments, newest first.
func logCommits(args ...string) ([]commit, error) {
	// Separate fields with NUL, which can't appear in any of them, and commits with newlines (%s is one line).
	out, err := git(append([]string{"log", "--first-parent", "--format=%H%x00%h%x00%P%x00%D%x00%s"}, args...)...)
	if err != nil {
		return nil, err
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
	return commits, nil
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
