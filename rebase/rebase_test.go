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

func TestSizeAndBase(t *testing.T) {
	p := newPlan(false, "e", "d", "c", "b", "a")
	if n := p.size(); n != 0 {
		t.Fatalf("unmarked plan has size %d, want 0", n)
	}

	p.entries[2].action = "edit"
	if n := p.size(); n != 3 {
		t.Fatalf("size %d, want 3", n)
	}
	if base, _ := p.base(3); base != "hb" {
		t.Fatalf("base %q, want hb", base)
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
	if base, _ := p.base(4); base != "ha" {
		t.Fatalf("base after move %q, want ha", base)
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

func TestBaseAtRoot(t *testing.T) {
	p := newPlan(true, "b", "a")
	p.entries[1].action = "reword"
	if base, err := p.base(p.size()); base != "" || err != nil {
		t.Fatalf("base %q, %v, want the root", base, err)
	}

	p.complete = false
	if _, err := p.base(p.size()); err == nil {
		t.Fatal("base of an incompletely loaded history succeeded")
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
