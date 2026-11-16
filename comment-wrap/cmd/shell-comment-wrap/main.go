package main

import (
	"fmt"
	"io"
	"os"

	"github.com/tlmorgan24/config/comment-wrap/shellwrap"
)

func main() {
	source, err := io.ReadAll(os.Stdin)
	if err != nil {
		fmt.Fprintf(os.Stderr, "shell-comment-wrap: %v\n", err)
		os.Exit(1)
	}
	_, err = os.Stdout.Write(shellwrap.Format(source, 100))
	if err != nil {
		fmt.Fprintf(os.Stderr, "shell-comment-wrap: %v\n", err)
		os.Exit(1)
	}
}
