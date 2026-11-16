package main

import (
	"fmt"
	"io"
	"os"

	"github.com/tlmorgan24/config/comment-wrap/config"
	"github.com/tlmorgan24/config/comment-wrap/pythonwrap"
)

func main() {
	source, err := io.ReadAll(os.Stdin)
	if err != nil {
		fatal(err)
	}
	settings, err := config.Load()
	if err != nil {
		fatal(err)
	}
	languageID := "python"
	if len(os.Args) > 1 {
		languageID = os.Args[1]
	}
	language, err := settings.Language(languageID)
	if err != nil {
		fatal(err)
	}
	if language.Enabled {
		source = pythonwrap.Format(source, language.Width)
	}
	if _, err := os.Stdout.Write(source); err != nil {
		fatal(err)
	}
}

func fatal(err error) {
	fmt.Fprintf(os.Stderr, "python-comment-wrap: %v\n", err)
	os.Exit(1)
}
