package main

import (
	"bufio"
	"database/sql"
	"errors"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

const (
	reset  = "\x1b[0m"
	bold   = "\x1b[1m"
	dim    = "\x1b[2m"
	red    = "\x1b[31m"
	green  = "\x1b[32m"
	yellow = "\x1b[33m"
)

// search prints one line per distinct command (its most recent run), newest first, for fzf:
//
//	id<TAB>time<TAB>status<TAB>command
//
// Newlines in a command are shown as ↵ (and tabs as spaces) so each command stays on one line;
// `cmdlog get <id>` then gives back the command exactly as typed.
func search() error {
	db, err := openDB()
	if err != nil {
		return err
	}
	defer db.Close()

	rows, err := db.Query(`
		SELECT c.id, c.started, c.status, c.command
		FROM commands c JOIN (SELECT max(id) AS id FROM commands GROUP BY command) latest ON c.id = latest.id
		ORDER BY c.id DESC`)
	if err != nil {
		return err
	}
	defer rows.Close()

	out := bufio.NewWriter(os.Stdout)
	defer out.Flush()
	for rows.Next() {
		var id int64
		var started float64
		var status sql.NullInt64
		var command string
		if err := rows.Scan(&id, &started, &status, &command); err != nil {
			return err
		}
		command = strings.NewReplacer("\r\n", " ↵ ", "\n", " ↵ ", "\t", " ").Replace(command)
		fmt.Fprintf(out, "%d\t%s%s%s\t%s\t%s\n", id, dim, formatTime(started, "2006-01-02 15:04"), reset, statusSymbol(status), command)
	}
	return rows.Err()
}

// show prints a command's details, then its output (for fzf's preview)
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

	if home, err := os.UserHomeDir(); err == nil && (dir == home || strings.HasPrefix(dir, home+"/")) {
		dir = "~" + dir[len(home):]
	}
	details := []string{dir, formatTime(started, "2006-01-02 15:04:05")}
	if ended.Valid {
		details = append(details, formatDuration(ended.Float64-started))
	}

	fmt.Printf("%s%s%s\n", bold, command, reset)
	fmt.Printf("%s%s%s  %s\n\n", dim, strings.Join(details, " · "), reset, statusText(status, ended.Valid))
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

// get prints a command exactly as it was typed (to put back on the command line)
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
	default:
		return fmt.Sprintf("%sexit %d%s", red, status.Int64, reset)
	}
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
