package jswrap

import (
	"strings"

	"github.com/tlmorgan24/config/comment-wrap/commentwrap"
)

func Format(source []byte, options commentwrap.Options) []byte {
	lines := strings.SplitAfter(string(source), "\n")
	return []byte(strings.Join(commentwrap.Format(lines, Comments(source), commentwrap.Style{Prefix: "//"}, options), ""))
}

// Comments scans source without requiring syntactically complete code.
func Comments(source []byte) []commentwrap.Comment {
	lines := strings.SplitAfter(string(source), "\n")
	var comments []commentwrap.Comment
	var quote byte
	blockComment := false
	escaped := false

	for lineNumber, rawLine := range lines {
		line := strings.TrimSuffix(strings.TrimSuffix(rawLine, "\n"), "\r")
		for column := 0; column < len(line); column++ {
			if blockComment {
				if column+1 < len(line) && line[column:column+2] == "*/" {
					blockComment = false
					column++
				}
				continue
			}
			char := line[column]
			if quote != 0 {
				if escaped {
					escaped = false
				} else if char == '\\' {
					escaped = true
				} else if char == quote {
					quote = 0
				}
				continue
			}
			if column+1 < len(line) && line[column:column+2] == "/*" {
				blockComment = true
				column++
				continue
			}
			if char == '"' || char == '\'' || char == '`' {
				quote = char
				continue
			}
			if column+1 >= len(line) || line[column:column+2] != "//" {
				continue
			}
			comments = append(comments, commentwrap.Comment{
				Line: lineNumber, Column: column, Content: line[column+2:],
				Standalone: strings.TrimSpace(line[:column]) == "", LineContents: line,
			})
			break
		}
	}

	return comments
}
