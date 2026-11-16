package main

import (
	"bytes"
	"fmt"
	"go/scanner"
	"go/token"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
)

func main() {
	source, err := io.ReadAll(os.Stdin)
	if err != nil {
		fatal(err)
	}

	width := maxLineLength(os.Args[1:])
	source = formatComments(source, width)

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

func formatComments(source []byte, width int) []byte {
	lines := strings.SplitAfter(string(source), "\n")
	fileSet := token.NewFileSet()
	file := fileSet.AddFile("", -1, len(source))
	var sourceScanner scanner.Scanner
	sourceScanner.Init(file, source, nil, scanner.ScanComments)

	type comment struct {
		line         int
		column       int
		text         string
		standalone   bool
		lineContents string
	}
	var comments []comment

	for {
		position, kind, text := sourceScanner.Scan()
		if kind == token.EOF {
			break
		}
		current := fileSet.Position(position)
		if kind != token.COMMENT || !strings.HasPrefix(text, "//") {
			continue
		}
		if current.Line < 1 || current.Line > len(lines) {
			continue
		}
		if isDirective(text) {
			continue
		}

		line := strings.TrimSuffix(strings.TrimSuffix(lines[current.Line-1], "\n"), "\r")
		commentStart := current.Column - 1
		if commentStart < 0 || commentStart > len(line) {
			continue
		}
		comments = append(comments, comment{
			line:         current.Line - 1,
			column:       commentStart,
			text:         text,
			standalone:   strings.TrimSpace(line[:commentStart]) == "",
			lineContents: line,
		})
	}

	for i := len(comments) - 1; i >= 0; i-- {
		comment := comments[i]
		indent := comment.lineContents[:len(comment.lineContents)-len(strings.TrimLeft(comment.lineContents, " \t"))]
		content := strings.TrimSpace(strings.TrimPrefix(comment.text, "//"))
		if content == "" {
			continue
		}
		if comment.standalone {
			wrapped := wrapComment(content, indent, width)
			lines = replaceLine(lines, comment.line, wrapped, lineEnding(lines[comment.line]))
			continue
		}
		if len(comment.lineContents) <= width {
			continue
		}
		code := strings.TrimRight(comment.lineContents[:comment.column], " \t")
		wrapped := wrapComment(content, indent, width)
		replacement := append(wrapped, code)
		lines = replaceLine(lines, comment.line, replacement, lineEnding(lines[comment.line]))
	}
	return []byte(strings.Join(lines, ""))
}

func replaceLine(lines []string, line int, replacement []string, ending string) []string {
	for i := range replacement {
		replacement[i] += ending
	}
	return append(lines[:line], append(replacement, lines[line+1:]...)...)
}

func wrapComment(content, indent string, width int) []string {
	prefix := indent + "// "
	available := width - len(prefix)
	if available < 1 {
		available = 1
	}
	words := strings.Fields(content)
	var result []string
	line := ""
	for _, word := range words {
		if line != "" && len(line)+1+len(word) > available {
			result = append(result, prefix+line)
			line = ""
		}
		if line != "" {
			line += " "
		}
		line += word
	}
	if line != "" {
		result = append(result, prefix+line)
	}
	return result
}

func isDirective(comment string) bool {
	text := strings.TrimSpace(strings.TrimPrefix(comment, "//"))
	return strings.HasPrefix(text, "go:") || strings.HasPrefix(text, "nolint") || strings.HasPrefix(text, "lint:")
}

func lineEnding(line string) string {
	if strings.HasSuffix(line, "\r\n") {
		return "\r\n"
	}
	if strings.HasSuffix(line, "\n") {
		return "\n"
	}
	return ""
}

func fatal(err error) {
	fmt.Fprintf(os.Stderr, "go-wrap-comments: %v\n", err)
	os.Exit(1)
}
