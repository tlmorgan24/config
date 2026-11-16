package gowrap

import (
	"go/scanner"
	"go/token"
	"strings"

	"github.com/tlmorgan24/config/comment-wrap/commentwrap"
)

func Format(source []byte, width int) []byte {
	lines := strings.SplitAfter(string(source), "\n")
	fileSet := token.NewFileSet()
	file := fileSet.AddFile("", -1, len(source))
	var sourceScanner scanner.Scanner
	sourceScanner.Init(file, source, nil, scanner.ScanComments)

	var comments []commentwrap.Comment
	for {
		position, kind, text := sourceScanner.Scan()
		if kind == token.EOF {
			break
		}
		current := fileSet.Position(position)
		if kind != token.COMMENT || !strings.HasPrefix(text, "//") {
			continue
		}
		if current.Line < 1 || current.Line > len(lines) || isDirective(text) {
			continue
		}

		line := strings.TrimSuffix(strings.TrimSuffix(lines[current.Line-1], "\n"), "\r")
		commentStart := current.Column - 1
		if commentStart < 0 || commentStart > len(line) {
			continue
		}
		comments = append(comments, commentwrap.Comment{
			Line:         current.Line - 1,
			Column:       commentStart,
			Content:      strings.TrimPrefix(text, "//"),
			Standalone:   strings.TrimSpace(line[:commentStart]) == "",
			LineContents: line,
		})
	}

	return []byte(strings.Join(commentwrap.Format(lines, comments, commentwrap.Style{Prefix: "//"}, width), ""))
}

func isDirective(comment string) bool {
	text := strings.TrimSpace(strings.TrimPrefix(comment, "//"))
	return strings.HasPrefix(text, "go:") || strings.HasPrefix(text, "nolint") || strings.HasPrefix(text, "lint:")
}
