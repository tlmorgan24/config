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
	languageID := config.LanguageID("shellscript")
	if len(os.Args) > 1 {
		languageID = os.Args[1]
	}
	language, err := settings.Language(languageID)
	if err != nil {
		fmt.Fprintf(os.Stderr, "shell-comment-wrap: %v\n", err)
		os.Exit(1)
	}
	_, err = os.Stdout.Write(shellwrap.Format(source, commentwrap.Options{
		Width:    language.Width,
		TabWidth: language.TabWidth, MinColWidth: language.MinColWidth,
	}))
	if err != nil {
		fmt.Fprintf(os.Stderr, "shell-comment-wrap: %v\n", err)
		os.Exit(1)
	}
}
