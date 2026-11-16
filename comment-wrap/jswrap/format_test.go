package jswrap

import "testing"

func TestFormatWrapsSlashCommentsWithoutTouchingStrings(t *testing.T) {
	source := "const url = \"https://example.com\";\n// this comment is long enough to wrap\n"
	got := string(Format([]byte(source), 30))
	want := "const url = \"https://example.com\";\n// this comment is long enough\n// to wrap\n"
	if got != want {
		t.Fatalf("got:\n%s\nwant:\n%s", got, want)
	}
}

func TestFormatIgnoresBlockComments(t *testing.T) {
	source := "/* not a line comment */\n// this comment is long enough to wrap\n"
	got := string(Format([]byte(source), 30))
	want := "/* not a line comment */\n// this comment is long enough\n// to wrap\n"
	if got != want {
		t.Fatalf("got:\n%s\nwant:\n%s", got, want)
	}
}
