package main

import (
	"strings"
	"testing"
)

// dropped returns the subjects of p's entries marked drop, newest first.
func dropped(p *plan) string {
	var s []string
	for _, e := range p.entries {
		if e.action == "drop" {
			s = append(s, e.subject)
		}
	}
	return strings.Join(s, ", ")
}

// TestPresetDrop checks the commits that drop's arguments start the list off with marked drop, in a real repository.
func TestPresetDrop(t *testing.T) {
	newRepo(t)
	// Entries are "use parser in cli", "add cli flag", "add tests", "add parser" and "init".
	for _, c := range []struct {
		revs      []string
		want, err string
		size      int
	}{
		{nil, "", "", 0},
		{[]string{"HEAD"}, "use parser in cli", "", 1},
		{[]string{"HEAD~2"}, "add tests", "", 3},
		{[]string{"HEAD~3", "HEAD~1"}, "add cli flag, add parser", "", 4},
		{[]string{"HEAD~2.."}, "use parser in cli, add cli flag", "", 2},
		{[]string{"main..feature"}, "add tests, add parser", "", 4},
		{[]string{"HEAD~1", "HEAD~2..", "HEAD"}, "use parser in cli, add cli flag", "", 2}, // Only once each
		{[]string{"HEAD.."}, "", "nothing to drop", 0},
		{[]string{"main"}, "", "can't drop", 0},
		{[]string{"nope"}, "", "nope isn't a commit", 0},
	} {
		h, err := newHistory()
		if err != nil {
			t.Fatal(err)
		}
		p := &plan{}
		if err := h.fill(p, pageSize); err != nil {
			t.Fatal(err)
		}
		err = h.presetDrop(p, c.revs)
		switch {
		case c.err != "" && (err == nil || !strings.Contains(err.Error(), c.err)):
			t.Errorf("%q gave error %v, want %q", c.revs, err, c.err)
		case c.err == "" && err != nil:
			t.Errorf("%q: %v", c.revs, err)
		case c.err == "" && (dropped(p) != c.want || p.size() != c.size):
			t.Errorf("%q dropped %q with size %d, want %q with %d", c.revs, dropped(p), p.size(), c.want, c.size)
		}
	}

	// A merge commit can't be dropped, and nor can a commit merged in, as neither is in the list.
	if _, err := git("merge", "-q", "--no-ff", "-m", "merge main", "main"); err != nil {
		t.Fatal(err)
	}
	for rev, want := range map[string]string{
		"HEAD":   "as it's a merge commit",
		"HEAD~2": "as merge commit",
		"main":   "isn't one of the current branch's commits",
	} {
		h, err := newHistory()
		if err != nil {
			t.Fatal(err)
		}
		if err := h.presetDrop(&plan{}, []string{rev}); err == nil || !strings.Contains(err.Error(), want) {
			t.Errorf("%s gave error %v, want %q", rev, err, want)
		}
	}
}
