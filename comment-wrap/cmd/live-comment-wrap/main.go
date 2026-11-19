// live-comment-wrap streams JSON requests and paragraph edits over stdin/stdout. It
// deliberately never invokes the code formatter used by Format Document.
package main

import (
	"encoding/json"
	"fmt"
	"io"
	"os"

	"github.com/tlmorgan24/config/comment-wrap/commentwrap"
	"github.com/tlmorgan24/config/comment-wrap/gowrap"
	"github.com/tlmorgan24/config/comment-wrap/jswrap"
	"github.com/tlmorgan24/config/comment-wrap/pythonwrap"
	"github.com/tlmorgan24/config/comment-wrap/shellwrap"
)

type request struct {
	Source      string               `json:"source"`
	Language    string               `json:"language"`
	Cursor      commentwrap.Position `json:"cursor"`
	Protected   []int                `json:"protected"`
	Width       int                  `json:"width"`
	TabWidth    int                  `json:"tabWidth"`
	MinColWidth int                  `json:"minColWidth"`
	TableGap    int                  `json:"tableGap"`
}

func reflow(r request) *commentwrap.LiveResult {
	var comments []commentwrap.Comment
	prefix := "//"
	switch r.Language {
	case "go":
		comments = gowrap.Comments([]byte(r.Source))
	case "python":
		comments = pythonwrap.Comments([]byte(r.Source))
		prefix = "#"
	case "shellscript":
		comments = shellwrap.Comments([]byte(r.Source))
		prefix = "#"
	case "javascript", "javascriptreact", "typescript", "typescriptreact", "json", "jsonc":
		comments = jswrap.Comments([]byte(r.Source))
	default:
		return nil
	}
	return commentwrap.Live(r.Source, comments, commentwrap.Style{Prefix: prefix}, commentwrap.Options{Width: r.Width, TabWidth: r.TabWidth, MinColWidth: r.MinColWidth, TableGap: r.TableGap}, r.Cursor, r.Protected)
}

func main() {
	decoder, encoder := json.NewDecoder(os.Stdin), json.NewEncoder(os.Stdout)
	for {
		r := request{TableGap: 2}
		if err := decoder.Decode(&r); err == io.EOF {
			return
		} else if err != nil {
			fatal(err)
		}
		if r.Width < 1 || r.TabWidth < 1 || r.MinColWidth < 1 {
			fatal(fmt.Errorf("width, tabWidth and minColWidth must be positive"))
		}
		if r.TableGap < 2 {
			fatal(fmt.Errorf("tableGap must be at least 2"))
		}
		if err := encoder.Encode(reflow(r)); err != nil {
			fatal(err)
		}
	}
}

func fatal(err error) { fmt.Fprintln(os.Stderr, "live-comment-wrap:", err); os.Exit(1) }
