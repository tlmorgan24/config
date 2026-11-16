package pythonwrap

import "testing"

func TestFormatWrapsCommentsWithoutTouchingStrings(t *testing.T) {
	source := "message = '# not a comment'\n# this comment is long enough to wrap\n"
	got := string(Format([]byte(source), 30))
	want := "message = '# not a comment'\n# this comment is long enough\n# to wrap\n"
	if got != want {
		t.Fatalf("got:\n%s\nwant:\n%s", got, want)
	}
}

func TestFormatIgnoresTripleQuotedStrings(t *testing.T) {
	source := "\"\"\"\n# not a comment\n\"\"\"\n# this comment is long enough to wrap\n"
	got := string(Format([]byte(source), 30))
	want := "\"\"\"\n# not a comment\n\"\"\"\n# this comment is long enough\n# to wrap\n"
	if got != want {
		t.Fatalf("got:\n%s\nwant:\n%s", got, want)
	}
}
