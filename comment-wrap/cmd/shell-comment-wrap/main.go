package main

import (
	"fmt"
	"io"
	"os"

	"github.com/tlmorgan24/config/comment-wrap/commentwrap"
	"github.com/tlmorgan24/config/comment-wrap/config"
	"github.com/tlmorgan24/config/comment-wrap/shellwrap"
)

func main() {
	source, err := io.ReadAll(os.Stdin)
	if err != nil {
		fmt.Fprintf(os.Stderr, "shell-comment-wrap: %v\n", err)
		os.Exit(1)
	}
	settings, err := config.Load()
	if err != nil {
		fmt.Fprintf(os.Stderr, "shell-comment-wrap: %v\n", err)
		os.Exit(1)
	}
	if !settings.Shellscript.Enabled {
		_, err = os.Stdout.Write(source)
	} else {
		_, err = os.Stdout.Write(shellwrap.Format(source, commentwrap.Options{
			Width:    settings.Shellscript.Width,
			TabWidth: settings.Shellscript.TabWidth, MinColWidth: settings.Shellscript.MinColWidth,
		}))
	}
	if err != nil {
		fmt.Fprintf(os.Stderr, "shell-comment-wrap: %v\n", err)
		os.Exit(1)
	}
}
