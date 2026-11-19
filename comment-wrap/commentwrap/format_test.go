package commentwrap

import (
	"strings"
	"testing"
)

func TestFormatSupportsSlashAndHashCommentStyles(t *testing.T) {
	tests := []struct {
		name   string
		style  Style
		source []string
		want   []string
	}{
		{
			name:   "slash",
			style:  Style{Prefix: "//"},
			source: []string{"\t// this comment is long enough to wrap\n"},
			want:   []string{"\t// this comment is long\n", "\t// enough to wrap\n"},
		},
		{
			name:   "hash",
			style:  Style{Prefix: "#"},
			source: []string{"  # this comment is long enough to wrap\n"},
			want:   []string{"  # this comment is long\n", "  # enough to wrap\n"},
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			got := Format(test.source, []Comment{{
				Line:         0,
				Column:       strings.IndexAny(test.source[0], "/#"),
				Content:      " this comment is long enough to wrap",
				Standalone:   true,
				LineContents: test.source[0][:len(test.source[0])-1],
			}}, test.style, Options{Width: 27, TabWidth: 4, MinColWidth: 30})
			if len(got) != len(test.want) {
				t.Fatalf("got %q, want %q", got, test.want)
			}

			for i := range got {
				if got[i] != test.want[i] {
					t.Fatalf("got %q, want %q", got, test.want)
				}
			}

		})
	}
}

func TestFormatPreservesMissingSpaceAfterCommentMarker(t *testing.T) {
	source := []string{"//hello this comment is long enough to wrap\n"}
	comments := []Comment{{
		Line: 0, Column: 0, Content: "hello this comment is long enough to wrap",
		Standalone: true, LineContents: "//hello this comment is long enough to wrap",
	}}

	got := Format(source, comments, Style{Prefix: "//"}, Options{Width: 30, TabWidth: 4, MinColWidth: 30})
	want := []string{"//hello this comment is long\n", "//enough to wrap\n"}
	if strings.Join(got, "") != strings.Join(want, "") {
		t.Fatalf("got %q, want %q", strings.Join(got, ""), strings.Join(want, ""))
	}
}

func TestFormatReflowsAdjacentComments(t *testing.T) {
	source := []string{
		"// LONGLINEWITH ADDITIONALTEXT\n",
		"// shortline\n",
	}
	got := Format(source, []Comment{
		{Line: 0, Column: 0, Content: " LONGLINEWITH ADDITIONALTEXT", Standalone: true, LineContents: "// LONGLINEWITH ADDITIONALTEXT"},
		{Line: 1, Column: 0, Content: " shortline", Standalone: true, LineContents: "// shortline"},
	}, Style{Prefix: "//"}, Options{Width: 27, TabWidth: 4, MinColWidth: 30})
	want := []string{
		"// LONGLINEWITH\n",
		"// ADDITIONALTEXT shortline\n",
	}
	if strings.Join(got, "") != strings.Join(want, "") {
		t.Fatalf("got %q, want %q", got, want)
	}
}

func TestFormatKeepsCommentParagraphBoundaries(t *testing.T) {
	tests := []struct {
		name     string
		source   []string
		comments []Comment
		want     []string
	}{
		{
			name:   "blank comment",
			source: []string{"// first\n", "//\n", "// second\n"},
			comments: []Comment{
				{Line: 0, Column: 0, Content: " first", Standalone: true, LineContents: "// first"},
				{Line: 1, Column: 0, Content: "", Standalone: true, LineContents: "//"},
				{Line: 2, Column: 0, Content: " second", Standalone: true, LineContents: "// second"},
			},
			want: []string{"// first\n", "//\n", "// second\n"},
		},
		{
			name:   "different indent level",
			source: []string{"// first\n", "//   second\n"},
			comments: []Comment{
				{Line: 0, Column: 0, Content: " first", Standalone: true, LineContents: "// first"},
				{Line: 1, Column: 0, Content: "   second", Standalone: true, LineContents: "//   second"},
			},
			want: []string{"// first\n", "//   second\n"},
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			got := Format(test.source, test.comments, Style{Prefix: "//"}, Options{Width: 80, TabWidth: 4, MinColWidth: 30})
			if strings.Join(got, "") != strings.Join(test.want, "") {
				t.Fatalf("got %q, want %q", got, test.want)
			}
		})
	}
}

func TestFormatPreservesCommentIndentOnWrap(t *testing.T) {
	source := []string{"//   this comment is long enough to wrap\n"}
	got := Format(source, []Comment{{
		Line:         0,
		Column:       0,
		Content:      "   this comment is long enough to wrap",
		Standalone:   true,
		LineContents: source[0][:len(source[0])-1],
	}}, Style{Prefix: "//"}, Options{Width: 27, TabWidth: 4, MinColWidth: 30})
	want := []string{"//   this comment is long\n", "//   enough to wrap\n"}
	if strings.Join(got, "") != strings.Join(want, "") {
		t.Fatalf("got %q, want %q", got, want)
	}
}

func TestFormatWrapsBulletsAndPullsInAlignedComment(t *testing.T) {
	source := []string{
		"// - first item is long\n",
		"//   second item\n",
	}
	got := Format(source, []Comment{
		{Line: 0, Column: 0, Content: " - first item is long", Standalone: true, LineContents: "// - first item is long"},
		{Line: 1, Column: 0, Content: "   second item", Standalone: true, LineContents: "//   second item"},
	}, Style{Prefix: "//"}, Options{Width: 21, TabWidth: 4, MinColWidth: 30})
	want := []string{
		"// - first item is\n",
		"//   long second item\n",
	}
	if strings.Join(got, "") != strings.Join(want, "") {
		t.Fatalf("got %q, want %q", got, want)
	}
}

func TestFormatKeepsBulletsAndUnalignedCommentsSeparate(t *testing.T) {
	source := []string{
		"// - item\n",
		"//   aligned continuation\n",
		"//   * next bullet\n",
		"// other paragraph\n",
	}
	got := Format(source, []Comment{
		{Line: 0, Column: 0, Content: " - item", Standalone: true, LineContents: "// - item"},
		{Line: 1, Column: 0, Content: "   aligned continuation", Standalone: true, LineContents: "//   aligned continuation"},
		{Line: 2, Column: 0, Content: "   * next bullet", Standalone: true, LineContents: "//   * next bullet"},
		{Line: 3, Column: 0, Content: " other paragraph", Standalone: true, LineContents: "// other paragraph"},
	}, Style{Prefix: "//"}, Options{Width: 80, TabWidth: 4, MinColWidth: 30})
	want := []string{
		"// - item aligned continuation\n",
		"//   * next bullet\n",
		"// other paragraph\n",
	}
	if strings.Join(got, "") != strings.Join(want, "") {
		t.Fatalf("got %q, want %q", got, want)
	}
}

func TestStdBulletRecognizesMarkers(t *testing.T) {
	tests := []struct {
		rest      string
		wantStyle string
		wantLen   int
	}{
		{rest: "- item", wantStyle: "-", wantLen: 2},
		{rest: "* item", wantStyle: "*", wantLen: 2},
		{rest: "1. item", wantStyle: "n.", wantLen: 3},
		{rest: "12) item", wantStyle: "n)", wantLen: 4},
		{rest: "(3) item", wantStyle: "(n)", wantLen: 4},
		{rest: "-   item", wantStyle: "-", wantLen: 4},
		{rest: "- ", wantStyle: "-", wantLen: 2},
		{rest: "-", wantStyle: "-", wantLen: 1},
	}
	for _, test := range tests {
		got, ok := stdBullet(test.rest)
		if !ok || got.style != test.wantStyle || got.prefixLen != test.wantLen {
			t.Errorf("stdBullet(%q) = %+v, %t; want style %q, len %d", test.rest, got, ok, test.wantStyle, test.wantLen)
		}
	}
	for _, rest := range []string{"-item", "3.5 volts", "(x) item", "1 item", "()", "word"} {
		if _, ok := stdBullet(rest); ok {
			t.Errorf("stdBullet(%q) unexpectedly matched", rest)
		}
	}
}

func TestWordBulletRecognizesMarkers(t *testing.T) {
	tests := []struct {
		rest      string
		wantStyle string
		wantLen   int
	}{
		{rest: "foo: bar", wantStyle: "word:", wantLen: 5},
		{rest: "foo:   bar", wantStyle: "word:", wantLen: 7},
		{rest: "foo - bar", wantStyle: "word-", wantLen: 6},
		{rest: "foo: ", wantStyle: "word:", wantLen: 5},
		{rest: "foo:", wantStyle: "word:", wantLen: 4},
	}
	for _, test := range tests {
		got, ok := wordBullet(test.rest)
		if !ok || got.style != test.wantStyle || got.prefixLen != test.wantLen {
			t.Errorf("wordBullet(%q) = %+v, %t; want style %q, len %d", test.rest, got, ok, test.wantStyle, test.wantLen)
		}
	}
	for _, rest := range []string{"foo bar", "foo:bar baz", ": x"} {
		if _, ok := wordBullet(rest); ok {
			t.Errorf("wordBullet(%q) unexpectedly matched", rest)
		}
	}
}

// formatText runs Format over a multi-line string of '#' comments, the way a
// scanner would present them.
func formatText(src string, width int, options ...Options) string {
	var lines []string
	for _, l := range strings.SplitAfter(src, "\n") {
		if l != "" {
			lines = append(lines, l)
		}
	}
	var comments []Comment
	for i, l := range lines {
		text := strings.TrimRight(l, "\r\n")
		idx := strings.Index(text, "#")
		if idx < 0 {
			continue
		}
		comments = append(comments, Comment{
			Line: i, Column: idx, Content: text[idx+1:],
			Standalone:   strings.TrimSpace(text[:idx]) == "",
			LineContents: text,
		})
	}
	if len(options) == 0 {
		return strings.Join(Format(lines, comments, Style{Prefix: "#"}, Options{Width: width, TabWidth: 4, MinColWidth: 30}), "")
	}
	return strings.Join(Format(lines, comments, Style{Prefix: "#"}, Options{
		Width: width, TabWidth: options[0].TabWidth, MinColWidth: options[0].MinColWidth, TableGap: options[0].TableGap,
	}), "")
}

// checkFormat verifies the output and that formatting it again changes nothing.
func checkFormat(t *testing.T, src, want string, width int) {
	t.Helper()
	got := formatText(src, width)
	if got != want {
		t.Fatalf("got:\n%s\nwant:\n%s", got, want)
	}
	if again := formatText(got, width); again != got {
		t.Fatalf("not idempotent, second pass gave:\n%s", again)
	}
}

func TestFormatTableAlignsColumnsAndKeepsEditedContinuation(t *testing.T) {
	// The continuation no longer lines up with any row's last column after the
	// edit of the middle row, but is still part of the table.
	src := "#  x  12345\n#  xyz  12345\n#       6789\n"
	want := "#  x    12345\n#  xyz  12345 6789\n"
	checkFormat(t, src, want, 100)
}

func TestFormatTableWrapsLastColumn(t *testing.T) {
	src := "# -a, --all    include everything in the output listing\n" +
		"# -b  short\n"
	// The last column would be 21 wide, so it is widened to the minimum of 30
	// and the table goes past the configured width.
	want := "# -a, --all  include everything in the\n" +
		"#            output listing\n" +
		"# -b         short\n"
	checkFormat(t, src, want, 34)
}

func TestFormatOptionsControlDisplayAndMinimumColumnWidths(t *testing.T) {
	table := "# -a, --all    include everything in the output listing\n" +
		"# -b  short\n"
	defaultOutput := formatText(table, 34)
	narrowMinimum := formatText(table, 34, Options{TabWidth: 4, MinColWidth: 10})
	if narrowMinimum != "# -a, --all  include everything in\n#            the output listing\n# -b         short\n" || narrowMinimum == defaultOutput {
		t.Fatalf("smaller minimum column width should allow different wrapping:\ndefault:\n%s\ncustom:\n%s", defaultOutput, narrowMinimum)
	}

	tabbed := "\t# first second third\n"
	narrowTabs := formatText(tabbed, 20, Options{TabWidth: 8, MinColWidth: 30})
	if len(strings.Split(narrowTabs, "\n")) <= len(strings.Split(formatText(tabbed, 20), "\n")) {
		t.Fatalf("wider tab width should reduce available text width:\n%s", narrowTabs)
	}
}

func TestFormatTableLastColumnNeverNarrowerThanMinimum(t *testing.T) {
	src := "# a-very-long-first-column-name-here  one two three four five six seven eight nine ten\n" +
		"# b  c\n"
	want := "# a-very-long-first-column-name-here  one two three four five six\n" +
		"#                                     seven eight nine ten\n" +
		"# b                                   c\n"
	checkFormat(t, src, want, 60)
}

func TestFormatTableEndsAtBlankAndBullet(t *testing.T) {
	src := "# a  b\n# c  d\n#\n# e  f\n# gg  h\n"
	want := "# a  b\n# c  d\n#\n# e   f\n# gg  h\n"
	checkFormat(t, src, want, 80)

	src = "# a  b\n# cc  d\n# - bullet\n"
	want = "# a   b\n# cc  d\n# - bullet\n"
	checkFormat(t, src, want, 80)
}

func TestFormatSingleRowIsATable(t *testing.T) {
	checkFormat(t, "# Hello.   World again\n", "# Hello.  World again\n", 80)
}

func TestFormatSingleRowTableSeparatesProse(t *testing.T) {
	checkFormat(t, "# prose above\n# a    last cell\n# prose below\n",
		"# prose above\n# a  last cell\n# prose below\n", 80)
}

func TestFormatSingleRowTableAfterIntro(t *testing.T) {
	checkFormat(t, "# Options:\n#   --all    alpha beta gamma delta\n#            epsilon zeta\n",
		"# Options:\n#   --all  alpha beta gamma delta epsilon\n#          zeta\n", 36)
}

func TestFormatTableEndsAtDifferentItemCount(t *testing.T) {
	checkFormat(t, "# a    first\n# bb    middle    last\n# c    final\n",
		"# a  first\n# bb  middle  last\n# c  final\n", 80)
}

func TestFormatBulletsTakePrecedenceOverSingleRowTables(t *testing.T) {
	checkFormat(t, "# - alpha  beta gamma\n", "# - alpha beta gamma\n", 80)
	checkFormat(t, "# Args:\n#   arg: alpha  beta gamma\n", "# Args:\n#   arg: alpha beta gamma\n", 80)
}

func TestFormatWhitespaceList(t *testing.T) {
	src := "# Items:\n#   one two three four five\n#   six\n#   seven\n"
	want := "# Items:\n#   one two three\n#     four five\n#   six\n#   seven\n"
	checkFormat(t, src, want, 20)

	// A single word with deeper content is a marker on its own line.
	src = "# Items:\n#   one\n#     two\n#   three\n"
	want = "# Items:\n#   one\n#     two\n#   three\n"
	checkFormat(t, src, want, 40)
}

func TestFormatWordColonList(t *testing.T) {
	src := "# Options:\n#   foo: does a thing that wraps\n#   bar: other\n# done\n"
	want := "# Options:\n#   foo: does a thing\n#        that wraps\n#   bar: other\n# done\n"
	checkFormat(t, src, want, 24)
}

func TestFormatWordColonOnlyAppliesAfterIntroColon(t *testing.T) {
	src := "# Author: me\n# Date: today\n"
	want := "# Author: me Date: today\n"
	checkFormat(t, src, want, 80)
}

func TestFormatNeverStartsLineLikeBullet(t *testing.T) {
	src := "# aaaa bbbb cccc dddd eeee ffff 2. gggg hhhh\n"
	want := "# aaaa bbbb cccc dddd eeee\n# ffff 2. gggg hhhh\n"
	checkFormat(t, src, want, 30)
}

func TestFormatLongWordGetsOwnLine(t *testing.T) {
	src := "# a supercalifragilisticexpialidocious b\n"
	want := "# a\n# supercalifragilisticexpialidocious\n# b\n"
	checkFormat(t, src, want, 20)
}

func TestFormatMisalignedCommentMarksAreSeparate(t *testing.T) {
	src := "# one\n  # two\n"
	checkFormat(t, src, src, 80)
}

func TestFormatLineNumbersStayValidAfterEarlierRewrap(t *testing.T) {
	src := "# this comment is long enough to wrap\ncode()  # trailing comment that is also long\n"
	got := formatText(src, 24)
	want := "# this comment is long\n# enough to wrap\n" +
		"# trailing comment that\n# is also long\ncode()\n"
	if got != want {
		t.Fatalf("got:\n%s\nwant:\n%s", got, want)
	}
}

func TestFormatKeepsMissingFinalNewline(t *testing.T) {
	got := formatText("# this comment is long enough to wrap", 24)
	want := "# this comment is long\n# enough to wrap"
	if got != want {
		t.Fatalf("got %q, want %q", got, want)
	}
}

func TestFormatTableShrinksAfterDeletingWidestRow(t *testing.T) {
	src := "# Options:\n#   --pages <selection>            page numbers\n#   --all <mm>                     amount to crop\n#                                  override selected sides\n#   --a long option, taking space  description\n"
	formatted := formatText(src, 46)
	lines := strings.SplitAfter(formatted, "\n")
	var remaining []string
	for _, line := range lines {
		if !strings.Contains(line, "--a long option") {
			remaining = append(remaining, line)
		}
	}
	want := "# Options:\n#   --pages <selection>  page numbers\n#   --all <mm>           amount to crop override\n#                        selected sides\n"
	checkFormat(t, strings.Join(remaining, ""), want, 46)
}

func TestFormatTableGap(t *testing.T) {
	src := "# a      x        one\n# bb     yyy      two\n"
	for _, gap := range []int{0, 1, 2, 4} {
		options := Options{TabWidth: 4, MinColWidth: 8, TableGap: gap}
		effective := gap
		if effective < 2 {
			effective = 2
		}
		want := "# a" + strings.Repeat(" ", effective+1) + "x" + strings.Repeat(" ", effective+2) + "one\n" +
			"# bb" + strings.Repeat(" ", effective) + "yyy" + strings.Repeat(" ", effective) + "two\n"
		got := formatText(src, 80, options)
		if got != want {
			t.Fatalf("gap %d: got %q, want %q", gap, got, want)
		}
		if again := formatText(got, 80, options); again != got {
			t.Fatalf("gap %d is not idempotent: %q", gap, again)
		}
	}
}
