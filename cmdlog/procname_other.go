//go:build !darwin

package main

import "os"

// foregroundName isn't implemented outside macOS, so the terminal's title is never set.
func foregroundName(ptmx *os.File) string {
	return ""
}
