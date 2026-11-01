package main

import (
	"strings"
	"testing"
)

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
	if err := p.check(); err == nil || !strings.Contains(err.Error(), "cutoff") {
		t.Fatalf("mark below the cutoff gave %v", err)
	}
	p.entries[3].action = ""
	if err := p.check(); err != nil {
		t.Fatal(err)
	}
	// So is moving a commit down past it.
	p.swap(1, 2)
	if err := p.check(); err == nil {
		t.Fatal("move below the cutoff succeeded")
	}
	p.swap(1, 2)

	// The base can't be one of the commits being rebased.
	p.base = commit{hash: "hd", short: "d"}
	if err := p.check(); err == nil || !strings.Contains(err.Error(), "onto d") {
		t.Fatalf("base in the rebase gave %v", err)
	}
	// But a base at the cutoff keeps the rebase where it is.
	p.base = commit{hash: "hc", short: "c"}
	if p.moves(p.size()) {
		t.Fatal("rebase onto its own cutoff moves")
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

func TestPushed(t *testing.T) {
	p := newPlan(false, "c", "b", "a")
	for i := range p.entries {
		p.entries[i].pushed = i > 0
	}
	// Picking b explicitly (to extend the rebase) changes nothing, as git keeps unchanged picks.
	p.entries[1].action = "pick"
	if n := p.pushed(); n != 0 {
		t.Errorf("pushed %d, want 0", n)
	}
	p.entries[2].action = "reword"
	if n := p.pushed(); n != 2 {
		t.Errorf("pushed %d, want 2", n)
	}
}

func TestPushedWhenMoving(t *testing.T) {
	// Moving onto a new base rewrites even unchanged picks.
	p := newPlan(false, "c", "b", "a")
	for i := range p.entries {
		p.entries[i].pushed = true
	}
	p.base, p.baseSize = commit{hash: "hx"}, 2
	if n := p.pushed(); n != 2 {
		t.Errorf("pushed %d, want 2", n)
	}
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
	var got []string
	for _, r := range rows {
		s := ""
		if r.hash != "" {
			s = []string{"", "copy ", "ghost "}[r.kind] + r.subject
			if r.refs != "" {
				s += " (" + r.refs + ")"
			}
		}
		got = append(got, s)
	}
	want := []string{"copy use parser in cli (HEAD -> topic)", "copy add cli flag", "bump deps (main)", "refactor",
		"ghost use parser in cli", "ghost add cli flag", "add tests (feature)", "add parser", "", "init"}
	if more || strings.Join(got, "|") != strings.Join(want, "|") {
		t.Errorf("rows (more %v)\n%s\nwant\n%s", more, strings.Join(got, "\n"), strings.Join(want, "\n"))
	}

	// Rebasing in place leaves out where the commits were.
	p.base = commit{}
	p.cutoff = ""
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
