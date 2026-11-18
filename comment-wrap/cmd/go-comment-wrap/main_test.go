package main

import (
	"os"
	"os/exec"
	"path/filepath"
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
	got := formatterArgs([]string{"-m", "100", "--shorten-comments", "--base-formatter=gofmt"}, 80, 2)
	want := []string{"-m", "100", "--base-formatter=gofmt", "--tab-len=2"}
	if strings.Join(got, " ") != strings.Join(want, " ") {
		t.Fatalf("got %v, want %v", got, want)
	}
}

func TestGoCommandHelper(t *testing.T) {
	if os.Getenv("COMMENT_WRAP_TEST_HELPER") != "1" {
		return
	}
	// Discard the test runner's arguments, as the extension invokes the command.
	os.Args = []string{"go-comment-wrap", "--base-formatter=gofmt"}
	main()
	os.Exit(0)
}

func TestGoCommandWithGolines(t *testing.T) {
	golines, err := exec.LookPath("golines")
	if err != nil {
		home, homeErr := os.UserHomeDir()
		if homeErr != nil {
			t.Fatal(homeErr)
		}
		golines = filepath.Join(home, "go", "bin", "golines")
		if _, err := os.Stat(golines); err != nil {
			t.Skip("golines is not installed")
		}
	}
	executable, err := os.Executable()
	if err != nil {
		t.Fatal(err)
	}
	configPath, err := filepath.Abs("../../config.jsonc")
	if err != nil {
		t.Fatal(err)
	}
	t.Setenv("COMMENT_WRAP_CONFIG", configPath)
	t.Setenv("COMMENT_WRAP_LANGUAGE", "go")
	t.Setenv("COMMENT_WRAP_TAB_WIDTH", "2")
	t.Setenv("COMMENT_WRAP_TEST_HELPER", "1")
	t.Setenv("PATH", filepath.Dir(golines)+string(os.PathListSeparator)+os.Getenv("PATH"))
	command := exec.Command(executable, "-test.run=^TestGoCommandHelper$")
	command.Stdin = strings.NewReader("package example\n\n// This comment is deliberately longer than the configured width so the command must wrap it before golines formats the code.\nvar value=1\n")
	output, err := command.CombinedOutput()
	if err != nil {
		t.Fatalf("command failed: %v\n%s", err, output)
	}
	if !strings.Contains(string(output), "var value = 1") || strings.Count(string(output), "\n// ") < 2 {
		t.Fatalf("expected wrapped comments and formatted code:\n%s", output)
	}
}
