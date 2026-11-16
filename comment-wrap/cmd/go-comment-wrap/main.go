package main

import (
	"bytes"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/tlmorgan24/config/comment-wrap/gowrap"
)

func main() {
	source, err := io.ReadAll(os.Stdin)
	if err != nil {
		fatal(err)
	}

	width := maxLineLength(os.Args[1:])
	source = gowrap.Format(source, width)

	golines, err := exec.LookPath("golines")
	if err != nil {
		goPath, goPathErr := exec.Command("go", "env", "GOPATH").Output()
		if goPathErr != nil {
			fatal(fmt.Errorf("find golines: %w", err))
		}
		golines = filepath.Join(strings.TrimSpace(string(goPath)), "bin", "golines")
		if _, statErr := os.Stat(golines); statErr != nil {
			fatal(fmt.Errorf("find golines: %w", err))
		}
	}

	command := exec.Command(golines, formatterArgs(os.Args[1:])...)
	command.Stdin = bytes.NewReader(source)
	command.Stdout = os.Stdout
	command.Stderr = os.Stderr
	if err := command.Run(); err != nil {
		fatal(err)
	}
}

func maxLineLength(args []string) int {
	for i, arg := range args {
		if arg == "-m" && i+1 < len(args) {
			if width, err := strconv.Atoi(args[i+1]); err == nil && width > 0 {
				return width
			}
		}
		if strings.HasPrefix(arg, "-m=") {
			if width, err := strconv.Atoi(strings.TrimPrefix(arg, "-m=")); err == nil && width > 0 {
				return width
			}
		}
		if strings.HasPrefix(arg, "--max-len=") {
			if width, err := strconv.Atoi(strings.TrimPrefix(arg, "--max-len=")); err == nil && width > 0 {
				return width
			}
		}
	}
	return 100
}

func formatterArgs(args []string) []string {
	filtered := make([]string, 0, len(args))
	for _, arg := range args {
		if arg != "--shorten-comments" {
			filtered = append(filtered, arg)
		}
	}
	return filtered
}

func fatal(err error) {
	fmt.Fprintf(os.Stderr, "go-comment-wrap: %v\n", err)
	os.Exit(1)
}
