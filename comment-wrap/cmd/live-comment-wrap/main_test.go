package main

import (
	"strings"
	"testing"
	"unicode/utf16"

	"github.com/tlmorgan24/config/comment-wrap/commentwrap"
)

func marked(s string) (string, commentwrap.Position) {
	at := strings.Index(s, "|")
	before := s[:at]
	line := strings.Count(before, "\n")
	start := strings.LastIndex(before, "\n") + 1
	return strings.Replace(s, "|", "", 1), commentwrap.Position{Line: line, Character: len(utf16.Encode([]rune(before[start:])))}
}

func liveMarked(t *testing.T, input, language string, width int, protected ...int) (string, *commentwrap.LiveResult) {
	t.Helper()
	source, cursor := marked(input)
	result := reflow(request{Source: source, Language: language, Cursor: cursor, Protected: protected, Width: width, TabWidth: 4, MinColWidth: 8})
	if result == nil || result.Edit == nil {
		return input, result
	}
	e := result.Edit
	lines := strings.Split(source, "\n")
	replacement := strings.Split(e.Text, "\n")
	lines = append(append(append([]string{}, lines[:e.First]...), replacement...), lines[e.Last+1:]...)
	line := lines[e.Cursor.Line]
	units, at := 0, 0
	for i, r := range line {
		if units == e.Cursor.Character {
			at = i
			break
		}
		units += utf16.RuneLen(r)
		at = i + len(string(r))
	}
	lines[e.Cursor.Line] = line[:at] + "|" + line[at:]
	return strings.Join(lines, "\n"), result
}

func TestLive(t *testing.T) {
	tests := []struct {
		name, input, want, language string
		width                       int
		protected                   []int
	}{
		{name: "overflow follows typed word", input: "// alpha beta gamma del|ta epsilon", want: "// alpha beta gamma\n// del|ta epsilon", width: 22},
		{name: "underflow pulls words up", input: "// alpha|\n// beta gamma", want: "// alpha| beta gamma", width: 30},
		{name: "trailing typing space survives", input: "// alpha beta gamma delta |", want: "// alpha beta gamma\n// delta |", width: 22},
		{name: "space at wrap follows next word", input: "// alpha beta gamma |delta", want: "// alpha beta gamma\n// |delta", width: 22},
		{name: "unicode caret uses UTF16", input: "// 🙂 alpha beta gam|ma delta", want: "// 🙂 alpha beta\n// gam|ma delta", width: 20},
		{name: "protected Enter stays split", input: "// alpha\n// be|ta gamma", want: "// alpha\n// be|ta gamma", width: 30, protected: []int{1}},
		{name: "protected lower segment still wraps", input: "// alpha\n// beta gamma delta eps|ilon", want: "// alpha\n// beta gamma delta\n// eps|ilon", width: 22, protected: []int{1}},
		{name: "protected upper segment still wraps", input: "// alpha beta gamma del|ta\n// epsilon", want: "// alpha beta gamma\n// del|ta\n// epsilon", width: 22, protected: []int{1}},
		{name: "several protected breaks", input: "// alpha\n// beta\n// gamma del|ta epsilon", want: "// alpha\n// beta\n// gamma del|ta epsilon", width: 25, protected: []int{1, 2}},
		{name: "standard bullet hanging indent", input: "// - alpha beta gamma del|ta", want: "// - alpha beta gamma\n//   del|ta", width: 22},
		{name: "bullet sibling separate", input: "// - alpha|\n// - beta gamma", want: "// - alpha|\n// - beta gamma", width: 30},
		{name: "word bullet keeps context", input: "# Args:\n#   name: alpha beta gam|ma delta\n#   next: untouched text", want: "# Args:\n#   name: alpha beta\n#         gam|ma delta\n#   next: untouched text", language: "python", width: 25},
		{name: "whitespace bullet keeps context", input: "# Args:\n#   alpha beta gamma del|ta\n#   next item", want: "# Args:\n#   alpha beta gamma\n#     del|ta\n#   next item", language: "python", width: 24},
		{name: "own line marker preserved", input: "# Args:\n#   name:\n#     alpha beta gamma del|ta", want: "# Args:\n#   name:\n#     alpha beta gamma\n#     del|ta", language: "python", width: 24},
		{name: "bare marker protection", input: "// -\n//   alpha beta gam|ma delta", want: "// -\n//   alpha beta gam|ma\n//   delta", width: 23, protected: []int{1}},
		{name: "new bullet typing space survives", input: "// - |", want: "// - |", width: 20},
		{name: "blank stays editable", input: "// alpha\n// |", want: "// alpha\n// |", width: 20, protected: []int{1}},
		{name: "directive excluded", input: "//go:generate some very long com|mand", want: "//go:generate some very long com|mand", width: 15},
		{name: "trailing comment excluded", input: "x := 1 // alpha beta gam|ma delta", want: "x := 1 // alpha beta gam|ma delta", width: 15},
		{name: "Go raw string excluded", input: "package p\nvar s = `\n// alpha beta gam|ma delta\n`", want: "package p\nvar s = `\n// alpha beta gam|ma delta\n`", width: 15},
		{name: "Python triple string excluded", input: "s = '''\n# alpha beta gam|ma delta\n'''", want: "s = '''\n# alpha beta gam|ma delta\n'''", language: "python", width: 15},
		{name: "JS template excluded", input: "const s = `\n// alpha beta gam|ma delta\n`;", want: "const s = `\n// alpha beta gam|ma delta\n`;", language: "javascript", width: 15},
		{name: "only active paragraph", input: "// alpha beta gamma delta\n//\n// eps|ilon\n// zeta eta", want: "// alpha beta gamma delta\n//\n// eps|ilon zeta eta", width: 25},

		{name: "table shrinks old padding", input: "// a        alpha be|ta\n// bb       gamma", want: "// a   alpha be|ta\n// bb  gamma", width: 40},
		{name: "table cursor in removed padding", input: "// a       | alpha\n// bb       gamma", want: "// a   |alpha\n// bb  gamma", width: 40},
		{name: "table continuation follows alignment", input: "// a        alpha beta\n//          gam|ma\n// bb       delta", want: "// a   alpha beta\n//     gam|ma\n// bb  delta", width: 20},
		{name: "table alignment and wrapping", input: "// a  alpha beta gamma del|ta\n// bb  epsilon zeta", want: "// a   alpha beta gamma\n//     del|ta\n// bb  epsilon zeta", width: 25},
		{name: "own-line marker typing gap", input: "# Args:\n#   name: |\n#     content", want: "# Args:\n#   name: |\n#     content", language: "python", width: 30},
		{name: "active multiple spaces preserved", input: "// alpha  |beta", want: "// alpha  |beta", width: 30},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			language := tt.language
			if language == "" {
				language = "go"
			}
			got, _ := liveMarked(t, tt.input, language, tt.width, tt.protected...)
			if got != tt.want {
				t.Fatalf("got:\n%s\nwant:\n%s", got, tt.want)
			}
		})
	}
}

func TestLiveCRLF(t *testing.T) {
	source, cursor := marked("// alpha beta gamma del|ta\r\ncode()")
	result := reflow(request{Source: source, Language: "go", Cursor: cursor, Width: 22, TabWidth: 4, MinColWidth: 8})
	if result == nil || result.Edit == nil || result.Edit.Text != "// alpha beta gamma\r\n// delta" {
		t.Fatalf("unexpected result: %+v", result)
	}
}

func TestLiveConfiguredTableGap(t *testing.T) {
	source, cursor := marked("// a        alpha|\n// bb       beta")
	result := reflow(request{Source: source, Language: "go", Cursor: cursor, Width: 40, TabWidth: 4, MinColWidth: 8, TableGap: 4})
	if result == nil || result.Edit == nil || result.Edit.Text != "// a     alpha\n// bb    beta" {
		t.Fatalf("unexpected result: %+v", result)
	}
}
