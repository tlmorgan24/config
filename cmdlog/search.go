package main

import (
	"bufio"
	"database/sql"
	"errors"
	"fmt"
	"os"
	"strconv"
	"strings"
	"syscall"
	"time"
)

const (
	reset  = "\x1b[0m"
	bold   = "\x1b[1m"
	dim    = "\x1b[2m"
	red    = "\x1b[31m"
	green  = "\x1b[32m"
	yellow = "\x1b[33m"

	// Exact colours from my terminal's Catppuccin Mocha theme (24-bit, as the theme's 16 ANSI colours don't include
	// them)
	rosewater = "\x1b[38;2;245;224;220m" // #f5e0dc
	mauve     = "\x1b[38;2;203;166;247m" // #cba6f7
)

// search prints one line per distinct command (its most recent run), newest first, for fzf:
//
//	id<TAB>time<TAB>status<TAB>command
//
// Newlines in a command are shown as ↵ (and tabs as spaces) so each command stays on one line; `cmdlog get <id>` then
// gives back the command exactly as typed. With --here, only commands run in the current directory are included.
// Commands are coloured as zsh colours them if $CMDLOG_HIGHLIGHT is set (see highlight.go).
func search(args []string) error {
	dir := "" // Empty means any directory.
	switch {
	case len(args) == 1 && args[0] == "--here":
		// Getwd gives $PWD when it's valid, so this matches the directory zsh recorded (e.g. /tmp, not /private/tmp).
		wd, err := os.Getwd()
		if err != nil {
			return err
		}
		dir = wd
	case len(args) > 0:
		return errors.New("usage: cmdlog search [--here]")
	}

	db, err := openDB()
	if err != nil {
		return err
	}
	defer db.Close()

	rows, err := db.Query(`
		SELECT c.id, c.started, c.status, c.command, c.dir
		FROM commands c JOIN (SELECT max(id) AS id FROM commands WHERE ?1 = '' OR dir = ?1 GROUP BY command) latest ON c.id = latest.id
		ORDER BY c.id DESC`, dir)
	if err != nil {
		return err
	}
	defer rows.Close()

	h := startHighlighter()
	defer h.close()
	out := bufio.NewWriter(os.Stdout)
	defer out.Flush()
	for rows.Next() {
		var id int64
		var started float64
		var status sql.NullInt64
		var command, commandDir string
		if err := rows.Scan(&id, &started, &status, &command, &commandDir); err != nil {
			return err
		}
		if coloured, ok := h.highlight(commandDir, command); ok {
			command = coloured
		}
		command = strings.NewReplacer("\r\n", " ↵ ", "\n", " ↵ ", "\t", " ").Replace(command)
		fmt.Fprintf(out, "%d\t%s%s%s\t%s\t%s\n", id, dim, formatTime(started, "2006-01-02 15:04"), reset, statusSymbol(status), command)
	}
	return rows.Err()
}

// show prints a command's details, then its output (for fzf's preview). The command is coloured as zsh colours it if
// $CMDLOG_HIGHLIGHT is set (see highlight.go).
func show(args []string) error {
	db, id, err := openForID(args)
	if err != nil {
		return err
	}
	defer db.Close()

	var started float64
	var ended sql.NullFloat64
	var dir, command string
	var status sql.NullInt64
	var output sql.NullString
	var interactive, truncated bool
	err = db.QueryRow(`SELECT started, ended, dir, command, status, output, interactive, truncated FROM commands WHERE id = ?`, id).
		Scan(&started, &ended, &dir, &command, &status, &output, &interactive, &truncated)
	if err != nil {
		return err
	}

	h := startHighlighter()
	if coloured, ok := h.highlight(dir, command); ok {
		fmt.Println(coloured)
	} else {
		fmt.Printf("%s%s%s%s\n", bold, rosewater, command, reset)
	}
	h.close()

	if home, err := os.UserHomeDir(); err == nil && (dir == home || strings.HasPrefix(dir, home+"/")) {
		dir = "~" + dir[len(home):]
	}
	details := []string{formatTime(started, "2006-01-02 15:04:05")}
	if ended.Valid {
		details = append(details, formatDuration(ended.Float64-started))
	}

	fmt.Printf("%s%s%s%s · %s%s  %s\n\n", mauve, dir, reset, dim, strings.Join(details, " · "), reset, statusText(status, ended.Valid))
	if interactive {
		fmt.Printf("%s(interactive program: only output after it exited is kept)%s\n", dim, reset)
	}
	if truncated {
		fmt.Printf("%s(output too long: only the end is kept)%s\n", dim, reset)
	}
	if output.String == "" {
		fmt.Printf("%s(no output)%s\n", dim, reset)
	} else {
		fmt.Println(output.String)
	}
	return nil
}

// get prints a command exactly as it was typed (to put back on the command line).
func get(args []string) error {
	db, id, err := openForID(args)
	if err != nil {
		return err
	}
	defer db.Close()

	var command string
	if err := db.QueryRow(`SELECT command FROM commands WHERE id = ?`, id).Scan(&command); err != nil {
		return err
	}
	fmt.Print(command)
	return nil
}

func openForID(args []string) (*sql.DB, int64, error) {
	if len(args) != 1 {
		return nil, 0, errors.New("expected a single command id")
	}
	id, err := strconv.ParseInt(args[0], 10, 64)
	if err != nil {
		return nil, 0, fmt.Errorf("invalid command id %q", args[0])
	}
	db, err := openDB()
	return db, id, err
}

func statusSymbol(status sql.NullInt64) string {
	switch {
	case !status.Valid:
		return yellow + "?" + reset
	case status.Int64 == 0:
		return green + "✓" + reset
	case suspended(status.Int64):
		return yellow + "⏸" + reset
	default:
		return red + "✗" + reset
	}
}

func statusText(status sql.NullInt64, finished bool) string {
	switch {
	case !finished:
		return yellow + "did not finish" + reset
	case !status.Valid:
		return yellow + "exit status unknown" + reset
	case status.Int64 == 0:
		return green + "exit 0" + reset
	case suspended(status.Int64):
		return fmt.Sprintf("%ssuspended (exit %d)%s", yellow, status.Int64, reset)
	default:
		return fmt.Sprintf("%sexit %d%s", red, status.Int64, reset)
	}
}

// suspended reports whether an exit status means the command was suspended (e.g. with ctrl+z) rather than finished.
// zsh gives such a command the status 128 + the number of the signal that stopped it.
func suspended(status int64) bool {
	switch syscall.Signal(status - 128) {
	case syscall.SIGTSTP, syscall.SIGTTIN, syscall.SIGTTOU, syscall.SIGSTOP:
		return true
	}
	return false
}

func formatTime(unix float64, layout string) string {
	return time.Unix(0, int64(unix*1e9)).Format(layout)
}

func formatDuration(seconds float64) string {
	d := time.Duration(seconds * float64(time.Second))
	switch {
	case d < time.Second:
		return fmt.Sprintf("%dms", d.Milliseconds())
	case d < time.Minute:
		return fmt.Sprintf("%.1fs", d.Seconds())
	default:
		return d.Round(time.Second).String()
	}
}
