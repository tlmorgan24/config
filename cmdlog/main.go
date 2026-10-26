// cmdlog records every command run in an interactive zsh session (timestamp, directory, command,
// exit status and output) into a SQLite database, and serves that history to my fzf-based ctrl+r.
//
// Usage:
//
//	cmdlog record <shell>   run <shell> under a pty, recording its commands (started by .zshrc)
//	cmdlog search [--here]  print history for fzf: id<TAB>time<TAB>status<TAB>command, newest first
//	                        (--here: only commands run in the current directory)
//	cmdlog show <id>        print a command's details and output (for fzf's preview)
//	cmdlog get <id>         print a command exactly as it was typed
//
// search and show colour commands as zsh does if $CMDLOG_HIGHLIGHT is set (see highlight.go).
//
// Each is a separate, independent process: the only thing they share is the database.
package main

import (
	"database/sql"
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"

	_ "modernc.org/sqlite"
)

const schema = `
CREATE TABLE IF NOT EXISTS commands (
	id           INTEGER PRIMARY KEY,
	session      TEXT NOT NULL,              -- random id of the shell session the command ran in
	started      REAL NOT NULL,              -- unix time, in seconds
	ended        REAL,                       -- NULL if the command never finished (e.g. its terminal was closed)
	dir          TEXT NOT NULL,              -- working directory the command was run from
	command      TEXT NOT NULL,              -- exactly as typed
	status       INTEGER,                    -- exit status, NULL if the command never finished
	output       TEXT,                       -- with colour codes kept, for display
	output_plain TEXT,                       -- without any escape codes, for searching
	interactive  INTEGER NOT NULL DEFAULT 0, -- 1 if a full-screen/mouse program ran, so only output after it exited was kept
	truncated    INTEGER NOT NULL DEFAULT 0  -- 1 if the output was too long, so only its end was kept
);
CREATE INDEX IF NOT EXISTS commands_command ON commands(command);
`

var logger = log.New(io.Discard, "", log.LstdFlags)

func main() {
	if len(os.Args) < 2 {
		usage()
	}
	var err error
	switch os.Args[1] {
	case "record":
		err = record(os.Args[2:])
	case "search":
		err = search(os.Args[2:])
	case "show":
		err = show(os.Args[2:])
	case "get":
		err = get(os.Args[2:])
	default:
		usage()
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, "cmdlog:", err)
		os.Exit(1)
	}
}

func usage() {
	fmt.Fprintln(os.Stderr, "usage: cmdlog record <shell> | search [--here] | show <id> | get <id>")
	os.Exit(2)
}

// dataDir holds the database and the error log: $CMDLOG_DIR, or ~/.local/share/cmdlog
func dataDir() (string, error) {
	if dir := os.Getenv("CMDLOG_DIR"); dir != "" {
		return dir, nil
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".local", "share", "cmdlog"), nil
}

// openDB opens (creating if needed) the database. Command output can contain secrets,
// so the directory and database are only readable by the user.
func openDB() (*sql.DB, error) {
	dir, err := dataDir()
	if err != nil {
		return nil, err
	}
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return nil, err
	}
	if err := os.Chmod(dir, 0o700); err != nil {
		return nil, err
	}
	path := filepath.Join(dir, "history.db")
	if f, err := os.OpenFile(path, os.O_CREATE|os.O_RDONLY, 0o600); err == nil {
		f.Close()
	}

	// WAL lets ctrl+r read while recorders (one per open terminal) write. busy_timeout makes
	// concurrent writers wait for each other instead of failing.
	db, err := sql.Open("sqlite", path+"?_pragma=busy_timeout(5000)&_pragma=journal_mode(WAL)&_pragma=synchronous(NORMAL)")
	if err != nil {
		return nil, err
	}
	if _, err := db.Exec(schema); err != nil {
		db.Close()
		return nil, err
	}
	return db, nil
}

// openLog sends errors to ~/.local/share/cmdlog/errors.log, as the recorder can't print them
// without them appearing in the middle of the terminal
func openLog() {
	dir, err := dataDir()
	if err != nil {
		return
	}
	f, err := os.OpenFile(filepath.Join(dir, "errors.log"), os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o600)
	if err != nil {
		return
	}
	logger.SetOutput(f)
}
