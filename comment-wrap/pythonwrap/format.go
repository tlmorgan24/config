package pythonwrap

import (
	"strings"

	"github.com/tlmorgan24/config/comment-wrap/commentwrap"
)

func Format(source []byte, width int) []byte {
	lines := strings.SplitAfter(string(source), "\n")
	var comments []commentwrap.Comment
	var quote byte
	triple := false
	escaped := false

	for lineNumber, rawLine := range lines {
		line := strings.TrimSuffix(strings.TrimSuffix(rawLine, "\n"), "\r")
		for column := 0; column < len(line); column++ {
			char := line[column]
			if escaped {
				escaped = false
				continue
			}
			if quote != 0 {
				if char == '\\' {
					escaped = true
				} else if triple && column+2 < len(line) && line[column:column+3] == strings.Repeat(string(quote), 3) {
					quote = 0
					triple = false
					column += 2
				} else if !triple && char == quote {
					quote = 0
				}
				continue
			}
			if char == '\'' || char == '"' {
				quote = char
				triple = column+2 < len(line) && line[column:column+3] == strings.Repeat(string(char), 3)
				if triple {
					column += 2
				}
				continue
			}
			if char != '#' {
				continue
			}
			comments = append(comments, commentwrap.Comment{
				Line: lineNumber, Column: column, Content: line[column+1:],
				Standalone: strings.TrimSpace(line[:column]) == "", LineContents: line,
			})
			break
		}
	}

	return []byte(strings.Join(commentwrap.Format(lines, comments, commentwrap.Style{Prefix: "#"}, width), ""))
}
