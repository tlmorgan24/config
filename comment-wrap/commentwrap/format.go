package commentwrap

import "strings"

// Comment describes a line comment found by a language-specific scanner.
type Comment struct {
	Line         int
	Column       int
	Content      string
	Standalone   bool
	LineContents string
}

// Style defines how wrapped comments are written.
type Style struct {
	Prefix string
}

// Format wraps comments from bottom to top so replacing a comment cannot
// invalidate the locations of comments that have not been processed yet.
func Format(lines []string, comments []Comment, style Style, width int) []string {
	for i := len(comments) - 1; i >= 0; i-- {
		comment := comments[i]
		content := strings.TrimSpace(comment.Content)
		if content == "" {
			continue
		}

		indent := comment.LineContents[:len(comment.LineContents)-len(strings.TrimLeft(comment.LineContents, " \t"))]
		wrapped := Wrap(content, indent, style, width)
		if comment.Standalone {
			lines = ReplaceLine(lines, comment.Line, wrapped, LineEnding(lines[comment.Line]))
			continue
		}
		if len(comment.LineContents) <= width {
			continue
		}

		code := strings.TrimRight(comment.LineContents[:comment.Column], " \t")
		lines = ReplaceLine(lines, comment.Line, append(wrapped, code), LineEnding(lines[comment.Line]))
	}
	return lines
}

// Wrap breaks comment content into lines using the supplied comment style.
func Wrap(content, indent string, style Style, width int) []string {
	prefix := indent + style.Prefix + " "
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

func ReplaceLine(lines []string, line int, replacement []string, ending string) []string {
	for i := range replacement {
		replacement[i] += ending
	}
	return append(lines[:line], append(replacement, lines[line+1:]...)...)
}

func LineEnding(line string) string {
	if strings.HasSuffix(line, "\r\n") {
		return "\r\n"
	}
	if strings.HasSuffix(line, "\n") {
		return "\n"
	}
	return ""
}
