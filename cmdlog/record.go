package main

import (
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"errors"
	"os"
	"os/exec"
	"os/signal"
	"strconv"
	"sync/atomic"
	"syscall"
	"time"

	"github.com/creack/pty"
	"golang.org/x/term"
)

// the most output kept per command (the end is kept, as that's usually where errors are)
const maxCapture = 4 << 20

// total bytes typed into the terminal, to tell whether keys were pressed while a command ran
var typed atomic.Int64

// how long to wait for the rest of a possible marker before passing the held-back bytes to the terminal
const flushDelay = 20 * time.Millisecond

// record runs the shell under a pty, sitting between it and the terminal:
//
//	terminal  <->  cmdlog record (this)  <->  shell
//
// Keystrokes pass to the shell unchanged. Output passes to the terminal unchanged except that markers
// (see marker.go) are removed: they tell us where each command starts and ends, and while a command
// runs, its output is captured to be saved to the database when it finishes.
//
// If anything goes wrong before the shell starts, the shell is run directly instead (unrecorded),
// so a broken cmdlog never leaves you without a shell.
func record(args []string) error {
	if len(args) != 1 {
		return errors.New("usage: cmdlog record <shell>")
	}
	shell := args[0]
	openLog()

	fallback := func(err error) error {
		logger.Printf("recording disabled for this session: %v", err)
		env := append(os.Environ(), "CMDLOG_SESSION=off") // stops .zshrc from trying to start cmdlog again
		return syscall.Exec(shell, []string{shell}, env)
	}

	if !term.IsTerminal(int(os.Stdin.Fd())) {
		return fallback(errors.New("stdin is not a terminal"))
	}
	db, err := openDB()
	if err != nil {
		return fallback(err)
	}
	session, secret := randomHex(8), randomHex(16)

	cmd := exec.Command(shell)
	cmd.Env = append(os.Environ(), "CMDLOG_SESSION="+session, "CMDLOG_SECRET="+secret)
	ptmx, err := pty.Start(cmd)
	if err != nil {
		return fallback(err)
	}

	// From here on, the shell is running: errors are logged, and recording carries on as best it can.

	// keep the shell's window size in step with the terminal's
	winch := make(chan os.Signal, 1)
	signal.Notify(winch, syscall.SIGWINCH)
	go func() {
		for range winch {
			if err := pty.InheritSize(os.Stdin, ptmx); err != nil {
				logger.Printf("resizing: %v", err)
			}
		}
	}()
	winch <- syscall.SIGWINCH

	// raw mode: every keystroke (including ctrl+c etc) goes straight through to the shell's pty,
	// whose own terminal settings then decide what it means
	oldState, err := term.MakeRaw(int(os.Stdin.Fd()))
	if err != nil {
		logger.Printf("raw mode: %v", err)
	}
	restore := func() {
		if oldState != nil {
			term.Restore(int(os.Stdin.Fd()), oldState)
		}
	}

	go func() {
		buf := make([]byte, 32*1024)
		for {
			n, err := os.Stdin.Read(buf)
			if n > 0 {
				typed.Add(int64(n))
				ptmx.Write(buf[:n])
			}
			if err != nil {
				return
			}
		}
	}()

	chunks := make(chan []byte, 64)
	go func() {
		defer close(chunks)
		buf := make([]byte, 32*1024)
		for {
			n, err := ptmx.Read(buf)
			if n > 0 {
				chunks <- append([]byte(nil), buf[:n]...)
			}
			if err != nil { // EIO once the shell (and anything else using its pty) has gone
				return
			}
		}
	}()

	shellDone := make(chan struct{})
	go func() {
		cmd.Wait()
		close(shellDone)
	}()

	// the terminal being closed (SIGHUP), or a request to stop (SIGTERM)
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGHUP, syscall.SIGTERM)

	w := newWriter(db, session)
	parser := &markerParser{secret: secret}
	var running *command // the command currently running, if any

	output := func(data []byte) {
		writeAll(os.Stdout, data)
		if running != nil {
			running.capture(data)
		}
	}

	var flushTimer, exitTimer <-chan time.Time
loop:
	for {
		select {
		case chunk, ok := <-chunks:
			if !ok {
				break loop
			}
			for _, ev := range parser.feed(chunk) {
				if ev.marker == nil {
					output(ev.data)
					continue
				}
				switch ev.marker.kind {
				case "start":
					if running != nil { // its end marker never came: save what we have
						w.finish(running, nil)
					}
					running = w.start(ev.marker.fields[0], ev.marker.fields[1])
				case "end":
					if running != nil {
						if status, err := strconv.Atoi(ev.marker.fields[0]); err == nil {
							w.finish(running, &status)
						} else {
							w.finish(running, nil)
						}
						running = nil
					}
				}
			}
			flushTimer = nil
			if len(parser.pending) > 0 {
				flushTimer = time.After(flushDelay)
			}
		case <-flushTimer:
			output(parser.flush())
			flushTimer = nil
		case <-shellDone:
			// normally the pty closes straight after, ending the loop. But a background job that is
			// still running can keep the pty open, so don't wait for it for long
			shellDone = nil
			exitTimer = time.After(200 * time.Millisecond)
		case <-exitTimer:
			break loop
		case <-stop:
			cmd.Process.Signal(syscall.SIGHUP)
			break loop
		}
	}

	output(parser.flush())
	if running != nil {
		w.finish(running, nil)
	}
	w.close()
	restore()

	code := 0
	if cmd.ProcessState != nil {
		code = cmd.ProcessState.ExitCode()
	}
	os.Exit(max(code, 0))
	return nil
}

func writeAll(f *os.File, data []byte) {
	for len(data) > 0 {
		n, err := f.Write(data)
		if err != nil {
			return
		}
		data = data[n:]
	}
}

func randomHex(n int) string {
	b := make([]byte, n)
	rand.Read(b)
	return hex.EncodeToString(b)
}

// command is a command that has started, whose output is being captured
type command struct {
	id        int64 // row id, only touched by the writer goroutine
	started   time.Time
	typedAt   int64 // value of `typed` when the command started
	output    []byte
	truncated bool
}

func (c *command) capture(data []byte) {
	c.output = append(c.output, data...)
	if len(c.output) > 2*maxCapture { // trim occasionally rather than on every write
		c.output = append([]byte(nil), c.output[len(c.output)-maxCapture:]...)
		c.truncated = true
	}
}

// writer does all database work on its own goroutine, so a slow write can never hold up the terminal
type writer struct {
	db      *sql.DB
	session string
	jobs    chan func()
	done    chan struct{}
}

func newWriter(db *sql.DB, session string) *writer {
	w := &writer{db: db, session: session, jobs: make(chan func(), 256), done: make(chan struct{})}
	go func() {
		for job := range w.jobs {
			job()
		}
		db.Close()
		close(w.done)
	}()
	return w
}

func (w *writer) submit(job func()) {
	select {
	case w.jobs <- job:
	default:
		logger.Printf("database writes backed up: dropped one")
	}
}

// start records a command as soon as it starts, so it's in the history even if it never finishes
func (w *writer) start(dir, cmdline string) *command {
	c := &command{started: time.Now(), typedAt: typed.Load()}
	w.submit(func() {
		res, err := w.db.Exec(`INSERT INTO commands (session, started, dir, command) VALUES (?, ?, ?, ?)`,
			w.session, unixSeconds(c.started), dir, cmdline)
		if err != nil {
			logger.Printf("saving command: %v", err)
			return
		}
		c.id, _ = res.LastInsertId()
	})
	return c
}

// finish saves a command's exit status (nil if unknown) and output
func (w *writer) finish(c *command, status *int) {
	ended := time.Now()
	raw := c.output
	truncated := c.truncated
	keysPressed := typed.Load() > c.typedAt
	if len(raw) > maxCapture {
		raw = raw[len(raw)-maxCapture:]
		truncated = true
	}
	c.output = nil
	w.submit(func() {
		if c.id == 0 { // its start was never saved
			return
		}
		colored, plain, interactive := cleanOutput(raw, keysPressed)
		var st sql.NullInt64
		if status != nil {
			st = sql.NullInt64{Int64: int64(*status), Valid: true}
		}
		_, err := w.db.Exec(`UPDATE commands SET ended = ?, status = ?, output = ?, output_plain = ?, interactive = ?, truncated = ? WHERE id = ?`,
			unixSeconds(ended), st, colored, plain, interactive, truncated, c.id)
		if err != nil {
			logger.Printf("saving output: %v", err)
		}
	})
}

// close waits for outstanding writes, giving up after a few seconds so the terminal can always close
func (w *writer) close() {
	close(w.jobs)
	select {
	case <-w.done:
	case <-time.After(3 * time.Second):
		logger.Printf("gave up waiting for database writes")
	}
}

func unixSeconds(t time.Time) float64 {
	return float64(t.UnixNano()) / 1e9
}
