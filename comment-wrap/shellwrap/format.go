package shellwrap

import (
	"strings"

	"github.com/tlmorgan24/config/comment-wrap/commentwrap"
)

func Format(source []byte, options commentwrap.Options) []byte {
	lines := strings.SplitAfter(string(source), "\n")
	return []byte(strings.Join(commentwrap.Format(lines, Comments(source), commentwrap.Style{Prefix: "#"}, options), ""))
}

// Comments scans source without requiring syntactically complete code.
func Comments(source []byte) []commentwrap.Comment {
	text := string(source)
	lines := strings.SplitAfter(text, "\n")
	var comments []commentwrap.Comment
	singleQuoted, doubleQuoted, escaped := false, false, false

	for lineNumber, rawLine := range lines {
		line := strings.TrimSuffix(strings.TrimSuffix(rawLine, "\n"), "\r")
		for column := 0; column < len(line); column++ {
			char := line[column]
			if escaped {
				escaped = false
				continue
			}
			if char == '\\' && !singleQuoted {
				escaped = true
				continue
			}
			if char == '\'' && !doubleQuoted {
				singleQuoted = !singleQuoted
				continue
			}
			if char == '"' && !singleQuoted {
				doubleQuoted = !doubleQuoted
				continue
			}
			if char != '#' || singleQuoted || doubleQuoted || !isShellCommentStart(line, column) {
				continue
			}

			comments = append(comments, commentwrap.Comment{
				Line:         lineNumber,
				Column:       column,
				Content:      line[column+1:],
				Standalone:   strings.TrimSpace(line[:column]) == "",
				LineContents: line,
			})
			break
		}
	}

	return comments
}

func isShellCommentStart(line string, column int) bool {
	if column == 0 {
		return true
	}
	switch line[column-1] {
	case ' ', '\t', ';', '|', '&', '(', ')', '<', '>':
		return true
	default:
		return false
	}
}
