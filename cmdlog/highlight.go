package main

import (
	"bufio"
	"io"
	"os"
	"os/exec"
	"strings"
	"syscall"
)

// highlighter colours commands as zsh does on the command line, using the shell command in $CMDLOG_HIGHLIGHT (set by my
// ctrl+r widget in .zshrc, to run .zsh/highlight-commands.zsh). That's started once and kept running: it's sent
// <directory>\0<command>\0 for each command, and replies with the coloured command followed by \0.
type highlighter struct {
	cmd *exec.Cmd
	in  io.WriteCloser
	out *bufio.Reader
}

// startHighlighter returns nil (so commands aren't coloured) if $CMDLOG_HIGHLIGHT isn't set or can't be started.
func startHighlighter() *highlighter {
	command := os.Getenv("CMDLOG_HIGHLIGHT")
	if command == "" {
		return nil
	}
	cmd := exec.Command("/bin/sh", "-c", command)
	// In its own session, so it has no terminal. Otherwise, run from fzf (whose preview and reload commands are in a
	// background process group), the terminal stops it as soon as it touches the terminal, which zsh's `read -d` does
	// even when reading a pipe. (If cmdlog is killed, e.g. by fzf moving to another preview, it still exits, as its
	// input closes.)
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	in, err := cmd.StdinPipe()
	if err != nil {
		return nil
	}
	out, err := cmd.StdoutPipe()
	if err != nil {
		return nil
	}
	if err := cmd.Start(); err != nil {
		return nil
	}
	return &highlighter{cmd: cmd, in: in, out: bufio.NewReader(out)}
}

// highlight returns the coloured command (each of its lines ending in a reset), or false if it couldn't be coloured.
// After a failure, it stops trying.
func (h *highlighter) highlight(dir, command string) (string, bool) {
	if h == nil || h.cmd == nil {
		return "", false
	}
	if _, err := io.WriteString(h.in, dir+"\x00"+command+"\x00"); err == nil {
		if coloured, err := h.out.ReadString(0); err == nil {
			return strings.TrimSuffix(coloured, "\x00"), true
		}
	}
	h.close()
	*h = highlighter{}
	return "", false
}

func (h *highlighter) close() {
	if h == nil || h.cmd == nil {
		return
	}
	h.in.Close()
	h.cmd.Wait()
}
