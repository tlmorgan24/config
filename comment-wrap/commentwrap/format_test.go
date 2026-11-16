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
				Content:      "this comment is long enough to wrap",
				Standalone:   true,
				LineContents: test.source[0][:len(test.source[0])-1],
			}}, test.style, 27)
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

func TestFormatReflowsAdjacentComments(t *testing.T) {
	source := []string{
		"// LONGLINEWITH ADDITIONALTEXT\n",
		"// shortline\n",
	}
	got := Format(source, []Comment{
		{Line: 0, Column: 0, Content: " LONGLINEWITH ADDITIONALTEXT", Standalone: true, LineContents: "// LONGLINEWITH ADDITIONALTEXT"},
		{Line: 1, Column: 0, Content: " shortline", Standalone: true, LineContents: "// shortline"},
	}, Style{Prefix: "//"}, 27)
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
			got := Format(test.source, test.comments, Style{Prefix: "//"}, 80)
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
	}}, Style{Prefix: "//"}, 27)
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
	}, Style{Prefix: "//"}, 21)
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
	}, Style{Prefix: "//"}, 80)
	want := []string{
		"// - item aligned continuation\n",
		"//   * next bullet\n",
		"// other paragraph\n",
	}
	if strings.Join(got, "") != strings.Join(want, "") {
		t.Fatalf("got %q, want %q", got, want)
	}
}

func TestBulletMarkerRecognizesNumericMarkers(t *testing.T) {
	tests := []struct {
		content string
		want    string
	}{
		{content: "1. item", want: "1. "},
		{content: "12) item", want: "12) "},
		{content: "(3) item", want: "(3) "},
	}
	for _, test := range tests {
		got, ok := bulletMarker(test.content)
		if !ok || got != test.want {
			t.Errorf("bulletMarker(%q) = %q, %t; want %q, true", test.content, got, ok, test.want)
		}
	}
}
