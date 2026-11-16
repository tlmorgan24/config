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

		if comment.Standalone {
			start := i
			for start > 0 {
				previous := comments[start-1]
				if !previous.Standalone ||
					strings.TrimSpace(previous.Content) == "" ||
					previous.Line+1 != comments[start].Line ||
					commentIndentLevel(previous.Content) != commentIndentLevel(comment.Content) {
					break
				}
				start--
			}

			paragraph := make([]string, 0, i-start+1)
			for paragraphComment := start; paragraphComment <= i; paragraphComment++ {
				paragraph = append(paragraph, strings.TrimSpace(comments[paragraphComment].Content))
			}
			firstComment := comments[start]
			indent := lineIndent(firstComment.LineContents, firstComment.Column)
			prefix := indent + style.Prefix + commentSeparator(firstComment.Content)
			wrapped := wrapWithPrefix(strings.Join(paragraph, " "), prefix, width)
			lines = ReplaceLines(lines, comments[start].Line, comment.Line, wrapped, LineEnding(lines[comments[start].Line]))
			i = start
			continue
		}
		if len(comment.LineContents) <= width {
			continue
		}

		indent := lineIndent(comment.LineContents, comment.Column)
		wrapped := Wrap(content, indent, style, width)
		code := strings.TrimRight(comment.LineContents[:comment.Column], " \t")
		lines = ReplaceLine(lines, comment.Line, append(wrapped, code), LineEnding(lines[comment.Line]))
	}
	return lines
}

// Wrap breaks comment content into lines using the supplied comment style.
func Wrap(content, indent string, style Style, width int) []string {
	return wrapWithPrefix(content, indent+style.Prefix+" ", width)
}

func wrapWithPrefix(content, prefix string, width int) []string {
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

func lineIndent(line string, column int) string {
	beforeComment := line
	if column > 0 {
		beforeComment = line[:column]
	}
	return beforeComment[:len(beforeComment)-len(strings.TrimLeft(beforeComment, " \t"))]
}

func commentIndent(content string) string {
	return content[:len(content)-len(strings.TrimLeft(content, " \t"))]
}

func commentSeparator(content string) string {
	indent := commentIndent(content)
	if indent == "" {
		return " "
	}
	return indent
}

func commentIndentLevel(content string) int {
	return len(commentIndent(content))
}

func ReplaceLine(lines []string, line int, replacement []string, ending string) []string {
	return ReplaceLines(lines, line, line, replacement, ending)
}

func ReplaceLines(lines []string, firstLine, lastLine int, replacement []string, ending string) []string {
	for i := range replacement {
		replacement[i] += ending
	}
	return append(lines[:firstLine], append(replacement, lines[lastLine+1:]...)...)
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
