package main

import (
	"slices"
	"strings"
	"testing"
)

// explain returns the error for doing what to the entry with the given hash, which has left p as it is, or "" if p
// works.
func explain(p *plan, what, hash string) string {
	if c := p.check(); c != nil {
		return p.explain(*c, what, hash, strings.TrimPrefix(hash, "h"))
	}
	return ""
}

// expect fails t unless doing what to the entry with the given hash, which has left p as it is, gives the error want.
func expect(t *testing.T, p *plan, what, hash, want string) {
	t.Helper()
	if got := explain(p, what, hash); got != want {
		t.Fatalf("%s %s gave %q, want %q", what, hash, got, want)
	}
}

// newPlan returns a plan of commits named by subjects, newest first, each with a hash of "h" + its subject.
func newPlan(complete bool, subjects ...string) *plan {
	p := &plan{complete: complete}
	var commits []commit
	for _, s := range subjects {
		commits = append(commits, commit{hash: "h" + s, short: s, parents: 1, subject: s})
	}
	p.add(commits)
	return p
}

func TestSizeAndCutoff(t *testing.T) {
	p := newPlan(false, "e", "d", "c", "b", "a")
	if n := p.size(); n != 0 {
		t.Fatalf("unmarked plan has size %d, want 0", n)
	}

	p.entries[2].action = "edit"
	if n := p.size(); n != 3 {
		t.Fatalf("size %d, want 3", n)
	}
	if cutoff, _ := p.cutoffAt(3); cutoff != "hb" {
		t.Fatalf("cutoff %q, want hb", cutoff)
	}

	// Moving e down below b covers all of e..b, and unmarking c then mustn't shrink the rebase past the moved commit,
	// or it would lose commits.
	p.swap(0, 1)
	p.swap(1, 2)
	p.swap(2, 3)
	p.entries[1].action = ""
	if n := p.size(); n != 4 {
		t.Fatalf("size after move %d, want 4", n)
	}
	if cutoff, _ := p.cutoffAt(4); cutoff != "ha" {
		t.Fatalf("cutoff after move %q, want ha", cutoff)
	}

	// Moving it back to where it was leaves nothing to rebase.
	p.swap(3, 2)
	p.swap(2, 1)
	p.swap(1, 0)
	if n := p.size(); n != 0 {
		t.Fatalf("size after moving back %d, want 0", n)
	}
}

func TestSizeIncludesFoldTarget(t *testing.T) {
	// Moving the fix d down to just above b and marking it fixup folds it into b, so b must be in the rebase too.
	p := newPlan(false, "d", "c", "b", "a")
	p.entries[0].action = "fixup"
	p.swap(0, 1)
	if n := p.size(); n != 3 {
		t.Fatalf("size %d, want 3", n)
	}
	if todo, _ := p.todo(3); todo != "pick hb b\nfixup hd d\npick hc c\n" {
		t.Fatalf("todo\n%s", todo)
	}

	// The same through a dropped commit, which can't be folded into.
	p = newPlan(false, "c", "b", "a")
	p.entries[0].action = "squash"
	p.entries[1].action = "drop"
	if n := p.size(); n != 3 {
		t.Fatalf("size through a drop %d, want 3", n)
	}
}

func TestCutoffAtRoot(t *testing.T) {
	p := newPlan(true, "b", "a")
	p.entries[1].action = "reword"
	if cutoff, err := p.cutoffAt(p.size()); cutoff != "" || err != nil {
		t.Fatalf("cutoff %q, %v, want the root", cutoff, err)
	}

	p.complete = false
	if _, err := p.cutoffAt(p.size()); err == nil {
		t.Fatal("cutoff of an incompletely loaded history succeeded")
	}
}

func TestBaseAndCutoff(t *testing.T) {
	// A base on another branch that lacks the newest three commits rebases those three onto it.
	p := newPlan(false, "e", "d", "c", "b", "a")
	p.base, p.baseSize = commit{hash: "hx", short: "x"}, 3
	size := p.size()
	if size != 3 || !p.moves(size) {
		t.Fatalf("size %d, moves %v, want 3 and true", size, p.moves(size))
	}
	if onto, _ := p.onto(size); onto != "hx" {
		t.Fatalf("onto %q, want hx", onto)
	}
	// Marking below that extends the rebase, as without a base.
	p.entries[3].action = "reword"
	if n := p.size(); n != 4 {
		t.Fatalf("size with a mark below %d, want 4", n)
	}

	// A cutoff fixes the size, so the mark below it is an error.
	p.cutoff = "hc"
	if n := p.size(); n != 2 {
		t.Fatalf("size with a cutoff %d, want 2", n)
	}
	// Each error starts from the key pressed, whether it marked the commit or set the cutoff above it.
	expect(t, p, "reword", "hb", "can't reword b while it's below the cutoff c")
	expect(t, p, "cutoff", "hc", "can't make c the cutoff while b below it is marked")
	p.entries[3].action = ""
	expect(t, p, "reword", "hb", "")
	// So is moving a commit down past it, or moving the cutoff itself.
	p.swap(1, 2)
	expect(t, p, "move", "hd", "can't move d below the cutoff c")
	expect(t, p, "move", "hc", "can't move c while it's the cutoff")
	p.swap(1, 2)

	// The base can't be one of the commits being rebased.
	p.base = commit{hash: "hd", short: "d"}
	expect(t, p, "base", "hd", "can't make d the base, as the base would be one of the commits being rebased")
	// But a base at the cutoff keeps the rebase where it is.
	p.base = commit{hash: "hc", short: "c"}
	if p.moves(p.size()) {
		t.Fatal("rebase onto its own cutoff moves")
	}
}

func TestSetBaseAndCutoff(t *testing.T) {
	p := newPlan(false, "e", "d", "c", "b", "a")
	c := commit{hash: "hc", short: "c"}
	d := commit{hash: "hd", short: "d"}

	// Setting the base on the cutoff replaces it, and vice versa, so a commit is never both.
	p.setCutoff("hc")
	p.setBase(c, 2)
	if p.cutoff != "" || p.base != c {
		t.Fatalf("base on the cutoff left cutoff %q, base %q", p.cutoff, p.base.hash)
	}
	p.setCutoff("hc")
	if p.cutoff != "hc" || p.base.hash != "" || p.baseSize != 0 {
		t.Fatalf("cutoff on the base left cutoff %q, base %q", p.cutoff, p.base.hash)
	}

	// A base among the commits being rebased stops the rebase there, replacing the cutoff below it.
	p.setBase(d, 1)
	if n := p.size(); p.cutoff != "" || n != 1 {
		t.Fatalf("base above the cutoff left cutoff %q, size %d", p.cutoff, n)
	}
	// Commits picked only because they were in the rebase drop out of it, but one marked with pick keeps it there.
	p.setBase(commit{hash: "hb", short: "b"}, 3)
	p.entries[2].action = "pick"
	p.setBase(d, 1)
	expect(t, p, "base", "hd", "can't make d the base while c below it is marked")
	expect(t, p, "pick", "hc", "can't pick c while it's below the base d")
	p.entries[2].action = ""
	p.entries[1].action = "reword"
	expect(t, p, "base", "hd", "can't make d the base while it's marked")
	expect(t, p, "reword", "hd", "can't reword d while it's the base")
	p.entries[1].action = ""
	// Nor can it be the commit a fixup just above it would fold into.
	p.entries[0].action = "fixup"
	expect(t, p, "fixup", "he", "can't fixup e while d below it is the base")
	expect(t, p, "base", "hd", `can't make d the base while e above it is marked "fixup"`)
	p.entries[0].action = ""
	// Dropping or moving the commit it would fold into is the same.
	p.setBase(c, 2)
	p.entries[0].action = "fixup"
	p.entries[1].action = "drop"
	expect(t, p, "drop", "hd", "can't drop d, as e would then have nothing to fold into")
	p.entries[1].action = ""
	p.swap(0, 1)
	expect(t, p, "move", "he", "can't move e, as it would then have nothing to fold into")
	expect(t, p, "move", "hd", "can't move d, as e would then have nothing to fold into")
	p.swap(0, 1)
	// So is a fixup just above the cutoff, as the cutoff isn't in the rebase either.
	p.setCutoff("hc")
	expect(t, p, "fixup", "he", "")
	p.entries[0].action = ""
	p.entries[1].action = "fixup"
	expect(t, p, "fixup", "hd", "can't fixup d while c below it is the cutoff")
	expect(t, p, "cutoff", "hc", `can't make c the cutoff while d above it is marked "fixup"`)
	p.entries[1].action = ""
	p.setBase(d, 1)

	// A cutoff below a base on the current branch extends the rebase, replacing the base.
	p.setCutoff("hb")
	if n := p.size(); p.base.hash != "" || n != 3 {
		t.Fatalf("cutoff below the base left base %q, size %d", p.base.hash, n)
	}

	// But a base below the cutoff, or on another branch, moves the rebase onto it, keeping the cutoff.
	p.setBase(commit{hash: "ha", short: "a"}, 4)
	if size := p.size(); p.cutoff != "hb" || size != 3 || !p.moves(size) {
		t.Fatalf("base below the cutoff left cutoff %q, size %d, moves %v", p.cutoff, size, p.moves(size))
	}
	p.setBase(commit{hash: "hx", short: "x"}, 3)
	p.setCutoff("hc")
	if size := p.size(); p.base.hash != "hx" || size != 2 || !p.moves(size) {
		t.Fatalf("cutoff with a base on another branch left base %q, size %d", p.base.hash, size)
	}
}

func TestTodo(t *testing.T) {
	p := newPlan(false, "d", "c", "b", "a")
	p.entries[0].action = "fixup"
	p.swap(0, 1) // Move the fixup d down onto b, below c.
	p.entries[2].action = "reword"
	todo, err := p.todo(p.size())
	if err != nil {
		t.Fatal(err)
	}
	want := "reword hb b\nfixup hd d\npick hc c\n"
	if todo != want {
		t.Fatalf("todo\n%s\nwant\n%s", todo, want)
	}
}

func TestTodoErrors(t *testing.T) {
	p := newPlan(false, "c", "b", "a")
	if _, err := p.todo(p.size()); err == nil {
		t.Error("empty todo succeeded")
	}

	// A fixup with only dropped commits below it, down to the root, has nothing to fold into.
	p = newPlan(true, "b", "a")
	p.entries[0].action = "fixup"
	p.entries[1].action = "drop"
	if _, err := p.todo(p.size()); err == nil || !strings.Contains(err.Error(), "fold") {
		t.Errorf("fixup onto nothing gave %v", err)
	}

	p = newPlan(false, "c", "b", "a")
	p.entries[1].parents = 2
	p.entries[1].action = "pick"
	if _, err := p.todo(p.size()); err == nil || !strings.Contains(err.Error(), "merge") {
		t.Errorf("merge in the rebase gave %v", err)
	}
}

func TestMergeErrors(t *testing.T) {
	// Whatever brings the merge commit b into the rebase is refused, rather than leaving it to the todo list.
	p := newPlan(false, "c", "b", "a")
	p.entries[1].parents = 2
	p.entries[1].action = "pick"
	expect(t, p, "pick", "hb", "can't pick b, as it's a merge commit")
	p.entries[1].action = ""
	p.entries[2].action = "reword"
	expect(t, p, "reword", "ha", "can't reword a, as merge commit b would then be in the rebase")
	p.entries[2].action = ""
	p.swap(1, 2)
	expect(t, p, "move", "ha", "can't move a, as merge commit b would then be in the rebase")
	expect(t, p, "move", "hb", "can't move b, as it's a merge commit")
	p.swap(1, 2)
	p.setBase(commit{hash: "hx", short: "x"}, 2)
	expect(t, p, "base", "hx", "can't make x the base, as merge commit b would then be in the rebase")
	p.setBase(commit{hash: "hb", short: "b"}, 1)
	expect(t, p, "base", "hb", "")
	p.setCutoff("ha")
	expect(t, p, "cutoff", "ha", "can't make a the cutoff, as merge commit b would then be in the rebase")

	// Commits above the merge commit can still be rebased.
	p = newPlan(false, "c", "b", "a")
	p.entries[1].parents = 2
	p.entries[0].action = "reword"
	expect(t, p, "reword", "hc", "")
}

func TestRebased(t *testing.T) {
	raw := "tree t1\nparent p1\nauthor A <a@x> 100 +0800\ncommitter C <c@x> 200 +0800\n" +
		"gpgsig -----BEGIN PGP SIGNATURE-----\n sig\n -----END PGP SIGNATURE-----\n\nsubject\n\nbody\n"
	want := "tree t1\nparent p2\nauthor A <a@x> 100 +0800\ncommitter C <c@x> 300 +0800\n\nsubject\n\nbody\n"
	if got := string(rebased([]byte(raw), "p2", 300)); got != want {
		t.Errorf("rebased\n%s\nwant\n%s", got, want)
	}
	want = "tree t1\nauthor A <a@x> 100 +0800\ncommitter C <c@x> 300 +0800\n\nsubject\n\nbody\n"
	if got := string(rebased([]byte(raw), "", 300)); got != want {
		t.Errorf("rebased onto nothing\n%s\nwant\n%s", got, want)
	}
}

// TestPreview checks the history drawn for moving a branch onto another, in a real repository.
func TestPreview(t *testing.T) {
	t.Chdir(t.TempDir())
	t.Setenv("GIT_CONFIG_GLOBAL", "/dev/null")
	for _, args := range [][]string{
		{"init", "-q", "-b", "main"}, {"commit", "-q", "--allow-empty", "-m", "init"},
		{"switch", "-qc", "feature"}, {"commit", "-q", "--allow-empty", "-m", "add parser"},
		{"commit", "-q", "--allow-empty", "-m", "add tests"},
		{"switch", "-qc", "topic"}, {"commit", "-q", "--allow-empty", "-m", "add cli flag"},
		{"commit", "-q", "--allow-empty", "-m", "use parser in cli"},
		{"switch", "-q", "main"}, {"commit", "-q", "--allow-empty", "-m", "refactor"},
		{"commit", "-q", "--allow-empty", "-m", "bump deps"}, {"switch", "-q", "topic"},
	} {
		args = append([]string{"-c", "user.name=T", "-c", "user.email=t@x"}, args...)
		if _, err := git(args...); err != nil {
			t.Fatal(err)
		}
	}
	h, err := newHistory()
	if err != nil {
		t.Fatal(err)
	}
	p := &plan{}
	if err := h.fill(p, pageSize); err != nil {
		t.Fatal(err)
	}
	v, err := newPreview()
	if err != nil {
		t.Fatal(err)
	}
	defer v.close()
	objects, _ := git("count-objects")

	// git rebase --onto main feature topic
	main, _ := git("rev-parse", "main")
	p.base = commit{hash: strings.TrimSpace(main)}
	p.cutoff = p.entries[2].hash
	rows, more, err := v.rows(p, pageSize)
	if err != nil {
		t.Fatal(err)
	}
	describe := func(rows []row) string {
		var got []string
		for _, r := range rows {
			s := ""
			if r.hash != "" {
				s = []string{"", "copy ", "ghost "}[r.kind] + r.subject
				if r.lost {
					s = "lost " + s
				}
				if r.refs != "" {
					s += " (" + r.refs + ")"
				}
			}
			got = append(got, s)
		}
		return strings.Join(got, "\n")
	}
	want := strings.Join([]string{"copy use parser in cli (HEAD -> topic)", "copy add cli flag", "bump deps (main)",
		"refactor", "lost ghost use parser in cli", "lost ghost add cli flag", "add tests (feature)", "add parser", "",
		"init"}, "\n")
	if got := describe(rows); more || got != want {
		t.Errorf("rows (more %v)\n%s\nwant\n%s", more, got, want)
	}
	for _, r := range rows {
		if !strings.HasPrefix(r.graph, branchLine) {
			t.Errorf("topic's line isn't leftmost and blue at %q: %q", r.subject, r.graph)
		}
	}

	// A commit that another branch still has isn't lost, nor are the ones below it, even once moved. Stopping at "add
	// parser" leaves it to feature alone.
	if _, err := git("branch", "keep", p.entries[1].hash); err != nil {
		t.Fatal(err)
	}
	p.cutoff = ""
	p.baseSize = 3
	rows, _, err = v.rows(p, pageSize)
	if err != nil {
		t.Fatal(err)
	}
	want = strings.Join([]string{"copy use parser in cli (HEAD -> topic)", "copy add cli flag", "copy add tests",
		"bump deps (main)", "refactor", "lost ghost use parser in cli", "ghost add cli flag (keep)",
		"ghost add tests (feature)", "add parser", "", "init"}, "\n")
	if got := describe(rows); got != want {
		t.Errorf("rows with another branch\n%s\nwant\n%s", got, want)
	}
	p.baseSize = 0

	// Rebasing in place shows where the commits were only where another branch still has them.
	p.base = commit{}
	p.entries[2].action = "reword"
	rows, _, err = v.rows(p, pageSize)
	if err != nil {
		t.Fatal(err)
	}
	// The order of commits on different branches depends on their times, which are all within the same second.
	lines := strings.Split(describe(rows), "\n")
	slices.Sort(lines)
	got := strings.TrimLeft(strings.Join(lines, "\n"), "\n")
	want = strings.Join([]string{"add parser", "bump deps (main)", "copy add cli flag", "copy add tests",
		"copy use parser in cli (HEAD -> topic)", "ghost add cli flag (keep)", "ghost add tests (feature)", "init",
		"refactor"}, "\n")
	if got != want {
		t.Errorf("rows in place with another branch\n%s\nwant\n%s", got, want)
	}
	p.entries[2].action = ""
	if _, err := git("branch", "-D", "keep"); err != nil {
		t.Fatal(err)
	}

	// Rebasing in place leaves out where the commits were, when nothing else has them.
	p.entries[1].action = "reword"
	rows, _, err = v.rows(p, pageSize)
	if err != nil {
		t.Fatal(err)
	}
	for _, r := range rows {
		if r.kind == ghost || (r.kind == plain && strings.Contains(r.subject, "cli")) {
			t.Errorf("rebase in place shows %q as it was", r.subject)
		}
	}

	// Commits below the first change are kept as they are, like git does, so picking them all changes nothing.
	p.entries[1].action = ""
	before, _, err := v.rows(p, pageSize)
	if err != nil {
		t.Fatal(err)
	}
	p.entries[1].action = "pick"
	rows, _, err = v.rows(p, pageSize)
	if err != nil {
		t.Fatal(err)
	}
	if len(rows) != len(before) {
		t.Fatalf("picking without changes drew %d rows, was %d", len(rows), len(before))
	}
	for i, r := range rows {
		if r.kind == copied && r.entry == 0 && r.refs != "HEAD -> topic" {
			t.Errorf("kept HEAD has refs %q", r.refs)
		}
		if r.hash != before[i].hash || r.graph != before[i].graph {
			t.Errorf("picking without changes drew row %d as %q, was %q", i, r.subject, before[i].subject)
		}
	}
	if after, _ := git("count-objects"); after != objects {
		t.Errorf("copies written to the repository: %s, before %s", after, objects)
	}
}

func TestParseKey(t *testing.T) {
	var keys []string
	for b := []byte("j\x1b[A\x1b[1;2B\r\x04\x1b\x1b[AK\x1b[9~"); len(b) > 0; {
		var key string
		key, b = parseKey(b)
		keys = append(keys, key)
	}
	got := strings.Join(keys, ",")
	if want := "j,up,shift-down,enter,ctrl-d,alt-up,K,"; got != want {
		t.Errorf("keys %q, want %q", got, want)
	}
	if key, _ := parseKey([]byte("\x1b")); key != "esc" {
		t.Errorf("lone ESC is %q", key)
	}
}

func TestFit(t *testing.T) {
	base := "<base>"
	tests := []struct{ in, want string }{
		{"hello world", "hello"},
		{"\x1b[31mred\x1b[m and", "\x1b[31mred\x1b[m<base> a"},
		{"\x1b[38;5;0mx", "\x1b[38;5;0mx"}, // The 0 is a colour, not a reset.
		{"\ta\x1b[2Jb", "  ab"},            // Tab expanded, screen clear dropped
		{"日本語", "日本"},                      // Wide characters take two columns each.
	}
	for _, tt := range tests {
		if got := fit(tt.in, 5, base); got != tt.want {
			t.Errorf("fit(%q) = %q, want %q", tt.in, got, tt.want)
		}
	}
}

func TestWrap(t *testing.T) {
	got := wrap("\x1b[1mRebase 2 commits \x1b[2monto abc1234 subject", 16)
	want := []string{"\x1b[1mRebase 2 commits", "\x1b[1m\x1b[2monto abc1234", "\x1b[2msubject"}
	if strings.Join(got, "|") != strings.Join(want, "|") {
		t.Errorf("wrap = %q, want %q", got, want)
	}
}
