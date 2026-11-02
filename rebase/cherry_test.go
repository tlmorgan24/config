package main

import (
	"strings"
	"testing"
)

// newCherryRepo changes to a new repository like newRepo's, but with main checked out, to cherry-pick topic's and
// feature's commits onto, and returns a plan for cherry-picking onto it.
func newCherryRepo(t *testing.T) *plan {
	newRepo(t)
	if _, err := git("switch", "-q", "main"); err != nil {
		t.Fatal(err)
	}
	head, err := resolve("HEAD")
	if err != nil {
		t.Fatal(err)
	}
	return &plan{cherry: true, complete: true, base: head}
}

// subjects returns the subjects of p's entries, newest first, each followed by its action unless it's pick.
func subjects(p *plan) string {
	var s []string
	for _, e := range p.entries {
		if e.action != "pick" {
			s = append(s, e.subject+" "+e.action)
		} else {
			s = append(s, e.subject)
		}
	}
	return strings.Join(s, ", ")
}

func mustResolve(t *testing.T, rev string) commit {
	t.Helper()
	c, err := resolve(rev)
	if err != nil {
		t.Fatal(err)
	}
	return c
}

func TestPick(t *testing.T) {
	p := newCherryRepo(t)
	check := func(what, want string) {
		t.Helper()
		if got := subjects(p); got != want {
			t.Fatalf("after %s, entries are %q, want %q", what, got, want)
		}
	}
	pick := func(rev, action string) error {
		c := mustResolve(t, rev)
		return pickCommit(p, c.hash, c.short, action)
	}
	back := func(rev string) error {
		c := mustResolve(t, rev)
		return pickBack(p, c.hash, c.short)
	}

	// Commits from anywhere add up, each on top of the last.
	if err := pick("feature~1", "pick"); err != nil {
		t.Fatal(err)
	}
	if err := pick("topic", "reword"); err != nil {
		t.Fatal(err)
	}
	check("picking", "use parser in cli reword, add parser")

	// Marking one already picked changes its action, in place.
	if err := pick("feature~1", "edit"); err != nil {
		t.Fatal(err)
	}
	check("re-marking", "use parser in cli reword, add parser edit")

	// ⇧p picks back to the last commit marked, keeping the history's order next to it, whichever is newer.
	if err := back("topic~1"); err != nil {
		t.Fatal(err)
	}
	check("picking back up", "use parser in cli reword, add cli flag, add tests, add parser edit")
	p.unpick(1)
	p.unpick(1)
	if err := pick("topic~1", "pick"); err != nil {
		t.Fatal(err)
	}
	if err := back("feature~1"); err != nil { // Already picked, so only "add tests" is new.
		t.Fatal(err)
	}
	check("picking back down", "add cli flag, add tests, use parser in cli reword, add parser edit")

	// ⇧p with nothing marked (or only itself) picks it alone.
	p.entries, p.last = nil, ""
	if err := back("feature"); err != nil {
		t.Fatal(err)
	}
	check("picking back with nothing marked", "add tests")
	p.unpick(0)
	if p.last != "" {
		t.Fatalf("last is still %q after unpicking it", p.last)
	}

	// Picking back across branches has no one history to follow.
	if err := pick("topic~1", "pick"); err != nil {
		t.Fatal(err)
	}
	if _, err := git("switch", "-q", "-c", "side", "main~1"); err != nil {
		t.Fatal(err)
	}
	if _, err := git("commit", "-q", "--allow-empty", "-m", "side"); err != nil {
		t.Fatal(err)
	}
	if _, err := git("switch", "-q", "main"); err != nil {
		t.Fatal(err)
	}
	err := back("side")
	if err == nil || !strings.Contains(err.Error(), "back to") || !strings.Contains(err.Error(), "neither is below") {
		t.Fatalf("picking back across branches gave %v", err)
	}

	// The current branch's commits are already there to cherry-pick.
	err = pick("main~1", "reword")
	if err == nil || !strings.Contains(err.Error(), "can't reword") || !strings.HasSuffix(err.Error(),
		", as the current branch already has it") {
		t.Fatalf("picking from main gave %v", err)
	}
}

func TestCherryChecks(t *testing.T) {
	p := newPlan(true, "c", "b", "a")
	p.cherry = true
	for i := range p.entries {
		p.entries[i].action = "pick"
	}
	p.entries[2].action = "fixup"
	expect(t, p, "fixup", "ha", "can't fixup a, as it would then have nothing to fold into")
	p.entries[1].action = "squash"
	p.unpick(2)
	expect(t, p, "unmark", "ha", "can't unmark a, as b would then have nothing to fold into")
	p.entries[1].action = "pick"
	p.entries[1].parents = 2
	expect(t, p, "pick", "hb", "can't pick b, as it's a merge commit")
	expect(t, p, "pick", "hc", "can't pick c, as merge commit b would then be cherry-picked")

	p = newPlan(true)
	p.cherry = true
	if _, err := p.todo(p.size()); err == nil || !strings.Contains(err.Error(), "no commits are picked") {
		t.Errorf("empty todo gave %v", err)
	}
}

// TestPresetCherry checks the commits that `git cherry-pick` arguments start the list off with.
func TestPresetCherry(t *testing.T) {
	newCherryRepo(t)
	for _, c := range []struct {
		revs      []string
		want, err string
	}{
		{nil, "", ""},
		{[]string{"topic"}, "use parser in cli", ""},
		{[]string{"feature..topic"}, "use parser in cli, add cli flag", ""},
		{[]string{"main..topic"}, "use parser in cli, add cli flag, add tests, add parser", ""},
		{[]string{"..topic"}, "use parser in cli, add cli flag, add tests, add parser", ""},
		// In the order given, and only once each
		{[]string{"topic", "feature~1", "feature..topic"}, "add cli flag, add parser, use parser in cli", ""},
		{[]string{"topic..feature"}, "", "already has all of"},
		{[]string{"main"}, "", "can't pick"},
		{[]string{"topic.."}, "", ", as the current branch already has it"},
		{[]string{"nope"}, "", "nope isn't a commit"},
	} {
		head, _ := resolve("HEAD")
		p := &plan{cherry: true, complete: true, base: head}
		err := presetCherry(p, c.revs)
		switch {
		case c.err != "" && (err == nil || !strings.Contains(err.Error(), c.err)):
			t.Errorf("%q gave error %v, want %q", c.revs, err, c.err)
		case c.err == "" && err != nil:
			t.Errorf("%q: %v", c.revs, err)
		case c.err == "" && subjects(p) != c.want:
			t.Errorf("%q gave %q, want %q", c.revs, subjects(p), c.want)
		}
	}
}

// TestCherryPreview checks the history drawn for cherry-picking, and that git carries the cherry-pick out.
func TestCherryPreview(t *testing.T) {
	p := newCherryRepo(t)
	if err := presetCherry(p, []string{"feature..topic"}); err != nil {
		t.Fatal(err)
	}
	p.entries[0].action = "reword"
	v, err := newPreview()
	if err != nil {
		t.Fatal(err)
	}
	defer v.close()
	rows, _, err := v.rows(p, pageSize)
	if err != nil {
		t.Fatal(err)
	}
	var got []string
	for _, r := range rows {
		if r.hash != "" {
			got = append(got, []string{"", "copy ", "ghost "}[r.kind]+r.subject+" "+r.refs)
		}
	}
	// The copies are the newest commits; the rest are all within the same second, so only HEAD is sure to be next.
	for i, want := range []string{"copy use parser in cli HEAD -> main", "copy add cli flag ", "bump deps "} {
		if i >= len(got) || got[i] != want {
			t.Fatalf("rows %q, want %q first", got, want)
		}
	}
	for _, want := range []string{"ghost use parser in cli topic", "ghost add cli flag "} {
		if !strings.Contains(strings.Join(got, "\n"), want) {
			t.Errorf("rows %q, want %q", got, want)
		}
	}
	for _, r := range rows {
		if r.lost {
			t.Errorf("%q is struck through, though cherry-picking leaves it where it is", r.subject)
		}
	}

	p.entries[0].action = "pick"
	p.swap(0, 1)
	todo, err := p.todo(p.size())
	if err != nil {
		t.Fatal(err)
	}
	if status, err := rebase(todo, "", p.base.hash); status != 0 || err != nil {
		t.Fatalf("rebase gave status %d, error %v", status, err)
	}
	out, err := git("log", "--format=%s", "-4", "main")
	if err != nil {
		t.Fatal(err)
	}
	if want := "add cli flag\nuse parser in cli\nbump deps\nrefactor\n"; out != want {
		t.Errorf("main is\n%s\nwant\n%s", out, want)
	}
}
