package main

import (
	"database/sql"
	"strings"
	"syscall"
	"testing"
)

const testSecret = "s3cret"

// run feeds the stream to a parser split at the given positions, returning the output and markers.
func run(stream string, splits ...int) (string, []*marker) {
	p := &markerParser{secret: testSecret}
	var out strings.Builder
	var markers []*marker
	prev := 0
	for _, s := range append(splits, len(stream)) {
		for _, ev := range p.feed([]byte(stream[prev:s])) {
			if ev.marker != nil {
				markers = append(markers, ev.marker)
			} else {
				out.Write(ev.data)
			}
		}
		prev = s
	}
	out.Write(p.flush())
	return out.String(), markers
}

func TestMarkersRemovedAtEverySplitPoint(t *testing.T) {
	stream := "prompt$ \x1b]7777;s3cret;start;%2FUsers%2Fme;echo%20a%3Bb%0Ac\ahello\r\n\x1b]7777;s3cret;end;0\aprompt$ "
	for split := 0; split <= len(stream); split++ {
		out, markers := run(stream, split)
		if out != "prompt$ hello\r\nprompt$ " {
			t.Fatalf("split %d: output %q", split, out)
		}
		if len(markers) != 2 || markers[0].kind != "start" || markers[1].kind != "end" {
			t.Fatalf("split %d: markers %+v", split, markers)
		}
		if markers[0].fields[0] != "/Users/me" || markers[0].fields[1] != "echo a;b\nc" || markers[1].fields[0] != "0" {
			t.Fatalf("split %d: fields %q %q", split, markers[0].fields, markers[1].fields)
		}
	}
}

func TestWrongSecretPassesThrough(t *testing.T) {
	fake := "\x1b]7777;guess;end;0\a"
	out, markers := run("a" + fake + "b")
	if out != "a"+fake+"b" || len(markers) != 0 {
		t.Fatalf("output %q, markers %+v", out, markers)
	}
}

func TestUnterminatedLookalikeDoesNotHideRealMarker(t *testing.T) {
	out, markers := run("x\x1b]7777;junk \x1b]7777;s3cret;end;1\ay")
	if out != "x\x1b]7777;junk y" || len(markers) != 1 || markers[0].fields[0] != "1" {
		t.Fatalf("output %q, markers %+v", out, markers)
	}
}

func TestLoneEscapeIsReleasedByFlush(t *testing.T) {
	p := &markerParser{secret: testSecret}
	if evs := p.feed([]byte("abc\x1b")); len(evs) != 1 || string(evs[0].data) != "abc" {
		t.Fatalf("events %+v", evs)
	}
	if got := string(p.flush()); got != "\x1b" {
		t.Fatalf("flushed %q", got)
	}
}

func TestCleanOutput(t *testing.T) {
	cases := []struct {
		name, raw, colored, plain string
		keysPressed, interactive  bool
	}{
		{"colours kept only in colored", "\x1b[31merror\x1b[0m\r\nok\r\n", "\x1b[31merror\x1b[0m\nok\x1b[0m", "error\nok", false, false},
		{"progress bar keeps final state", "10%\r50%\r100%\r\ndone", "100%\ndone", "100%\ndone", false, false},
		{"other escapes removed", "\x1b]133;C\a\x1b[2Ka\x1b[?25lb\x1b(Bc", "abc", "abc", false, false},
		{"backspace overstrike", "N\bNA\bAM\bME\bE", "NAME", "NAME", false, false},
		{"only output after interactive program kept", "before\r\n\x1b[?1049hscreen junk\x1b[?1049lafter\r\n", "after", "after", false, true},
		{"bracketed paste counts as interactive (fzf --height)", "\x1b[?2004h\x1b[4Apicker\x1b[?2004l\x1b[Ja\r\n", "a", "a", false, true},
		{"pager scrolled through counts as interactive", "\x1b[?1h\x1b=line1\r\nline2\r\n:\r\x1b[K\x1b[?1l\x1b>", "", "", true, true},
		{"pager that exits by itself does not", "\x1b[?1h\x1b=\rcommit 1\r\n\r\x1b[K\x1b[?1l\x1b>", "commit 1", "commit 1", false, false},
		{"mouse mode counts as interactive", "\x1b[?1000;1006hpicker\x1b[?1000;1006lSwitched\r\n", "Switched", "Switched", false, true},
	}
	for _, c := range cases {
		colored, plain, interactive := cleanOutput([]byte(c.raw), c.keysPressed)
		if colored != c.colored || plain != c.plain || interactive != c.interactive {
			t.Errorf("%s: got %q %q %v", c.name, colored, plain, interactive)
		}
	}
}

func TestHighlighter(t *testing.T) {
	// A stand-in for highlight-commands.zsh that "colours" each command by prefixing its directory
	t.Setenv("CMDLOG_HIGHLIGHT", `while IFS= read -r -d '' dir && IFS= read -r -d '' cmd; do printf '%s: %s\0' "$dir" "$cmd"; done`)
	h := startHighlighter()
	defer h.close()
	for _, command := range []string{"ls", "echo a\necho b", ""} {
		if got, ok := h.highlight("/tmp", command); !ok || got != "/tmp: "+command {
			t.Fatalf("%q: got %q %v", command, got, ok)
		}
	}
}

func TestHighlighterFailures(t *testing.T) {
	t.Setenv("CMDLOG_HIGHLIGHT", "")
	if _, ok := startHighlighter().highlight("/tmp", "ls"); ok {
		t.Fatal("coloured without a highlighter")
	}
	t.Setenv("CMDLOG_HIGHLIGHT", "exit 1") // One that dies straight away
	h := startHighlighter()
	for range 2 { // And keeps failing, rather than crashing.
		if _, ok := h.highlight("/tmp", "ls"); ok {
			t.Fatal("coloured by a highlighter that exited")
		}
	}
}

func TestSuspended(t *testing.T) {
	stopped := 128 + int64(syscall.SIGTSTP) // What zsh gives a command suspended with ctrl+z (146 on macOS)
	for status, want := range map[int64]bool{stopped: true, 0: false, 1: false, 130: false, 137: false} {
		if got := suspended(status); got != want {
			t.Errorf("status %d: got %v", status, got)
		}
	}
	if got := statusSymbol(sql.NullInt64{Int64: stopped, Valid: true}); got != yellow+"⏸"+reset {
		t.Errorf("symbol %q", got)
	}
}
