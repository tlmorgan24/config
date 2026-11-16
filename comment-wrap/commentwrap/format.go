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
	groups := commentGroups(comments)
	for i := len(groups) - 1; i >= 0; i-- {
		group := groups[i]
		firstComment := comments[group[0]]
		lastComment := comments[group[len(group)-1]]
		paragraph := make([]string, 0, len(group))
		for _, commentIndex := range group {
			paragraph = append(paragraph, strings.TrimSpace(comments[commentIndex].Content))
		}
		indent := lineIndent(firstComment.LineContents, firstComment.Column)
		var wrapped []string
		if marker, ok := bulletMarker(firstComment.Content); ok {
			bulletParagraph := append([]string{firstComment.Content}, paragraph[1:]...)
			wrapped = wrapBullet(bulletParagraph, indent+style.Prefix, marker, width)
		} else {
			prefix := indent + style.Prefix + commentSeparator(firstComment.Content)
			wrapped = wrapWithPrefix(strings.Join(paragraph, " "), prefix, width)
		}
		lines = ReplaceLines(lines, firstComment.Line, lastComment.Line, wrapped, LineEnding(lines[firstComment.Line]))
	}

	for i := len(comments) - 1; i >= 0; i-- {
		comment := comments[i]
		content := strings.TrimSpace(comment.Content)
		if content == "" || comment.Standalone {
			continue
		}
		if len(comment.LineContents) <= width {
			continue
		}

		indent := lineIndent(comment.LineContents, comment.Column)
		prefix := indent + style.Prefix + commentSeparator(comment.Content)
		wrapped := wrapWithPrefix(content, prefix, width)
		code := strings.TrimRight(comment.LineContents[:comment.Column], " \t")
		lines = ReplaceLine(lines, comment.Line, append(wrapped, code), LineEnding(lines[comment.Line]))
	}
	return lines
}

func commentGroups(comments []Comment) [][]int {
	var groups [][]int
	for i, comment := range comments {
		content := strings.TrimSpace(comment.Content)
		if !comment.Standalone || content == "" {
			continue
		}

		if _, ok := bulletMarker(comment.Content); ok {
			groups = append(groups, []int{i})
			continue
		}

		if len(groups) == 0 {
			groups = append(groups, []int{i})
			continue
		}
		group := groups[len(groups)-1]
		previous := comments[group[len(group)-1]]
		if previous.Line+1 != comment.Line {
			groups = append(groups, []int{i})
			continue
		}
		if previousMarker, isBullet := bulletMarker(comments[group[0]].Content); isBullet {
			if commentIndentLevel(comment.Content) == commentIndentLevel(comments[group[0]].Content)+len(previousMarker) {
				groups[len(groups)-1] = append(group, i)
				continue
			}
		} else if commentIndentLevel(previous.Content) == commentIndentLevel(comment.Content) {
			groups[len(groups)-1] = append(group, i)
			continue
		}
		groups = append(groups, []int{i})
	}
	return groups
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

func wrapBullet(paragraph []string, prefix, marker string, width int) []string {
	words := strings.Fields(strings.Join(paragraph[1:], " "))
	firstLine := strings.TrimSpace(marker)
	if len(paragraph) > 0 {
		firstContent := strings.TrimSpace(paragraph[0])
		if len(firstContent) >= len(marker) {
			words = append(strings.Fields(strings.TrimSpace(firstContent[len(marker):])), words...)
		}
	}

	firstPrefix := prefix + commentIndent(paragraph[0])
	continuationPrefix := firstPrefix + strings.Repeat(" ", len(marker))
	available := width - len(firstPrefix)
	if available < 1 {
		available = 1
	}
	var result []string
	for len(words) > 0 {
		candidate := firstLine + " " + words[0]
		if len(candidate) > available && firstLine != strings.TrimSpace(marker) {
			break
		}
		firstLine = candidate
		words = words[1:]
	}
	result = append(result, firstPrefix+firstLine)
	result = append(result, wrapWords(words, continuationPrefix, width)...)
	return result
}

func wrapWords(words []string, prefix string, width int) []string {
	available := width - len(prefix)
	if available < 1 {
		available = 1
	}
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
	return commentIndent(content)
}

func commentIndentLevel(content string) int {
	return len(commentIndent(content))
}

func bulletMarker(content string) (string, bool) {
	trimmed := strings.TrimLeft(content, " \t")
	if strings.HasPrefix(trimmed, "- ") || strings.HasPrefix(trimmed, "* ") {
		return trimmed[:2], true
	}
	if strings.HasPrefix(trimmed, "(") {
		end := 1
		for end < len(trimmed) && trimmed[end] >= '0' && trimmed[end] <= '9' {
			end++
		}
		if end > 1 && end+1 < len(trimmed) && trimmed[end] == ')' && trimmed[end+1] == ' ' {
			return trimmed[:end+2], true
		}
		return "", false
	}
	end := 0
	for end < len(trimmed) && trimmed[end] >= '0' && trimmed[end] <= '9' {
		end++
	}
	if end > 0 && end+1 < len(trimmed) &&
		(trimmed[end] == '.' || trimmed[end] == ')') && trimmed[end+1] == ' ' {
		return trimmed[:end+2], true
	}
	return "", false
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
