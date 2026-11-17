package pythonwrap

import (
	"testing"

	"github.com/tlmorgan24/config/comment-wrap/commentwrap"
)

func TestFormatWrapsCommentsWithoutTouchingStrings(t *testing.T) {
	source := "message = '# not a comment'\n# this comment is long enough to wrap\n"
	got := string(Format([]byte(source), commentwrap.Options{Width: 30, TabWidth: 4, MinColWidth: 30}))
	want := "message = '# not a comment'\n# this comment is long enough\n# to wrap\n"
	if got != want {
		t.Fatalf("got:\n%s\nwant:\n%s", got, want)
	}
}

func TestFormatIgnoresTripleQuotedStrings(t *testing.T) {
	source := "\"\"\"\n# not a comment\n\"\"\"\n# this comment is long enough to wrap\n"
	got := string(Format([]byte(source), commentwrap.Options{Width: 30, TabWidth: 4, MinColWidth: 30}))
	want := "\"\"\"\n# not a comment\n\"\"\"\n# this comment is long enough\n# to wrap\n"
	if got != want {
		t.Fatalf("got:\n%s\nwant:\n%s", got, want)
	}
}
