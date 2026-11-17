package jswrap

import (
	"testing"

	"github.com/tlmorgan24/config/comment-wrap/commentwrap"
)

func TestFormatWrapsSlashCommentsWithoutTouchingStrings(t *testing.T) {
	source := "const url = \"https://example.com\";\n// this comment is long enough to wrap\n"
	got := string(Format([]byte(source), commentwrap.Options{Width: 30, TabWidth: 4, MinColWidth: 30}))
	want := "const url = \"https://example.com\";\n// this comment is long enough\n// to wrap\n"
	if got != want {
		t.Fatalf("got:\n%s\nwant:\n%s", got, want)
	}
}

func TestFormatIgnoresBlockComments(t *testing.T) {
	source := "/* not a line comment */\n// this comment is long enough to wrap\n"
	got := string(Format([]byte(source), commentwrap.Options{Width: 30, TabWidth: 4, MinColWidth: 30}))
	want := "/* not a line comment */\n// this comment is long enough\n// to wrap\n"
	if got != want {
		t.Fatalf("got:\n%s\nwant:\n%s", got, want)
	}
}
