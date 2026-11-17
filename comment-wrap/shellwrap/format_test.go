package shellwrap

import (
	"testing"

	"github.com/tlmorgan24/config/comment-wrap/commentwrap"
)

func TestFormatWrapsHashCommentsWithoutTouchingStrings(t *testing.T) {
	source := "command --message '# this is not a comment'\n# this comment is long enough to wrap\n"
	got := string(Format([]byte(source), commentwrap.Options{Width: 30, TabWidth: 4, MinColWidth: 30}))
	want := "command --message '# this is not a comment'\n# this comment is long enough\n# to wrap\n"
	if got != want {
		t.Fatalf("got:\n%s\nwant:\n%s", got, want)
	}
}

func TestFormatPromotesLongTrailingComments(t *testing.T) {
	source := "value=1 # this trailing explanation is long enough to move above the code\n"
	got := string(Format([]byte(source), commentwrap.Options{Width: 40, TabWidth: 4, MinColWidth: 30}))
	want := "# this trailing explanation is long\n# enough to move above the code\nvalue=1\n"
	if got != want {
		t.Fatalf("got:\n%s\nwant:\n%s", got, want)
	}
}

func TestFormatRecognizesCommentsAfterShellOperators(t *testing.T) {
	source := "first;# this comment is long enough to wrap after an operator\n"
	got := string(Format([]byte(source), commentwrap.Options{Width: 30, TabWidth: 4, MinColWidth: 30}))
	want := "# this comment is long enough\n# to wrap after an operator\nfirst;\n"
	if got != want {
		t.Fatalf("got:\n%s\nwant:\n%s", got, want)
	}
}
