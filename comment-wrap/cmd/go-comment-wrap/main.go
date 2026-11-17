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

	"github.com/tlmorgan24/config/comment-wrap/commentwrap"
	"github.com/tlmorgan24/config/comment-wrap/config"
	"github.com/tlmorgan24/config/comment-wrap/gowrap"
)

func main() {
	source, err := io.ReadAll(os.Stdin)
	if err != nil {
		fatal(err)
	}

	settings, err := config.Load()
	if err != nil {
		fatal(err)
	}
	if !settings.Go.Enabled {
		_, err = os.Stdout.Write(source)
		if err != nil {
			fatal(err)
		}
		return
	}

	width := settings.Go.Width
	if configuredWidth := maxLineLength(os.Args[1:]); configuredWidth > 0 {
		width = configuredWidth
	}
	source = gowrap.Format(source, commentwrap.Options{
		Width:       width,
		TabWidth:    settings.Go.TabWidth,
		MinColWidth: settings.Go.MinColWidth,
	})

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

	command := exec.Command(golines, formatterArgs(os.Args[1:], width)...)
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
	return 0
}

func formatterArgs(args []string, width int) []string {
	filtered := make([]string, 0, len(args))
	hasWidth := false
	for _, arg := range args {
		if arg != "--shorten-comments" {
			filtered = append(filtered, arg)
		}
		if arg == "-m" || strings.HasPrefix(arg, "-m=") || strings.HasPrefix(arg, "--max-len=") {
			hasWidth = true
		}
	}
	if !hasWidth {
		filtered = append([]string{"-m", strconv.Itoa(width)}, filtered...)
	}
	return filtered
}

func fatal(err error) {
	fmt.Fprintf(os.Stderr, "go-comment-wrap: %v\n", err)
	os.Exit(1)
}
