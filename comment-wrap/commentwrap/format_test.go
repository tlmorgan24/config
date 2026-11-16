package commentwrap

import "testing"

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
