package main

import (
	"strings"
	"testing"

	"github.com/tlmorgan24/config/comment-wrap/commentwrap"
	"github.com/tlmorgan24/config/comment-wrap/gowrap"
)

func TestWrapsAndPromotesLongTrailingComments(t *testing.T) {
	source := "package example\n\nfunc example() {\n\tvalue := calculate() // this explanation is deliberately long enough to move above the code\n\tother := 1 // short\n}\n"
	got := string(gowrap.Format([]byte(source), commentwrap.Options{Width: 60, TabWidth: 4, MinColWidth: 30}))
	want := "package example\n\nfunc example() {\n\t// this explanation is deliberately long enough to move\n\t// above the code\n\tvalue := calculate()\n\tother := 1 // short\n}\n"
	if got != want {
		t.Fatalf("got:\n%s\nwant:\n%s", got, want)
	}
}

func TestDoesNotPromoteDirectivesOrStandaloneComments(t *testing.T) {
	source := "package example\n\n// short comment\nfunc example() { //go:noinline\n}\n"
	got := string(gowrap.Format([]byte(source), commentwrap.Options{Width: 40, TabWidth: 4, MinColWidth: 30}))
	if got != source {
		t.Fatalf("source changed:\n%s", got)
	}
}

func TestFormatterArgsDisableGolinesCommentWrapping(t *testing.T) {
	got := formatterArgs([]string{"-m", "100", "--shorten-comments", "--base-formatter=gofmt"}, 80)
	want := []string{"-m", "100", "--base-formatter=gofmt"}
	if strings.Join(got, " ") != strings.Join(want, " ") {
		t.Fatalf("got %v, want %v", got, want)
	}
}
