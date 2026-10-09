package main

import (
	"bytes"
	"net/url"
	"strings"
)

// Markers are escape sequences printed by zsh's preexec/precmd hooks (see .zshrc), telling the recorder
// where each command's output starts and ends:
//
//	ESC ] 7777 ; <secret> ; start ; <dir> ; <command> BEL
//	ESC ] 7777 ; <secret> ; end ; <exit status> BEL
//
// <dir> and <command> are percent-encoded by zsh, so they can't contain ';', BEL or newlines.
// <secret> is random per session and only known to the recorder and its own zsh, so program output
// can't produce a valid marker by accident. Valid markers are removed from the stream, so they never
// reach the terminal (or its scrollback), meaning no copy exists anywhere for a program to replay.
// Anything that looks like a marker but has the wrong secret is passed through untouched as ordinary output.
const markerPrefix = "\x1b]7777;"

// a sequence longer than this without its closing BEL can't be one of ours, so stop holding it back
const maxMarkerLen = 1 << 20

type marker struct {
	kind   string // "start" or "end"
	fields []string
}

// event is either a run of ordinary output (data) or a valid marker
type event struct {
	data   []byte
	marker *marker
}

type markerParser struct {
	secret  string
	pending []byte // bytes held back because they might be the beginning of a marker split across reads
}

// feed takes the next chunk of the stream and returns, in stream order, the ordinary output and the markers found.
// Bytes that could be the start of a marker are held back until a later chunk completes (or rules out) the marker.
func (p *markerParser) feed(chunk []byte) []event {
	buf := append(p.pending, chunk...)
	p.pending = nil

	var events []event
	emit := func(data []byte) {
		if len(data) > 0 {
			events = append(events, event{data: data})
		}
	}

	outStart := 0 // start of output not yet emitted
	i := 0        // where to continue searching for a marker
	for {
		j := bytes.Index(buf[i:], []byte(markerPrefix))
		if j < 0 {
			// the end of buf may still be the first few bytes of a marker prefix
			k := partialPrefixLen(buf[i:])
			emit(buf[outStart : len(buf)-k])
			p.pending = buf[len(buf)-k:]
			return events
		}
		j += i

		end := bytes.IndexByte(buf[j:], '\a')
		if end < 0 {
			if len(buf)-j > maxMarkerLen {
				i = j + 1 // can't be ours: leave it in the output and look further on
				continue
			}
			emit(buf[outStart:j])
			p.pending = buf[j:]
			return events
		}
		end += j

		if m, ok := p.parse(buf[j+len(markerPrefix) : end]); ok {
			emit(buf[outStart:j])
			events = append(events, event{marker: m})
			outStart = end + 1
			i = end + 1
		} else {
			// not ours: it stays in the output. Search again from just after its start (not its end), in case
			// it is an unterminated look-alike whose BEL actually belongs to a real marker inside it
			i = j + 1
		}
	}
}

// flush gives up waiting for the rest of a possible marker, returning the held-back bytes as ordinary output.
// Called when no more data has arrived for a while, so output (e.g. a lone ESC) is never held back indefinitely.
func (p *markerParser) flush() []byte {
	out := p.pending
	p.pending = nil
	return out
}

func (p *markerParser) parse(body []byte) (*marker, bool) {
	fields := strings.Split(string(body), ";")
	if len(fields) < 2 || fields[0] != p.secret {
		return nil, false
	}
	m := &marker{kind: fields[1]}
	switch {
	case m.kind == "start" && len(fields) == 4:
	case m.kind == "end" && len(fields) == 3:
	default:
		return nil, false
	}
	for _, f := range fields[2:] {
		decoded, err := url.PathUnescape(f)
		if err != nil {
			return nil, false
		}
		m.fields = append(m.fields, decoded)
	}
	return m, true
}

// partialPrefixLen returns the length of the longest suffix of b that is a proper prefix of markerPrefix
func partialPrefixLen(b []byte) int {
	for k := min(len(markerPrefix)-1, len(b)); k > 0; k-- {
		if bytes.HasSuffix(b, []byte(markerPrefix[:k])) {
			return k
		}
	}
	return 0
}
