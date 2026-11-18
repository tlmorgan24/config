// go-doc-comment reads {source, line} from stdin and returns the declaration name
// and documented names for the declaration starting on that one-based line.
package main

import (
	"encoding/json"
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"os"
	"strings"
)

type signature struct {
	Name  string   `json:"name"`
	Names []string `json:"names"`
}

func declarationAt(source string, line int) *signature {
	fset := token.NewFileSet()
	// Keep the recovered AST: a function being edited may have an unfinished body.
	file, _ := parser.ParseFile(fset, "doc.go", source, parser.AllErrors|parser.SkipObjectResolution)
	if file == nil {
		return nil
	}
	startsLine := func(pos token.Pos) bool {
		position := fset.Position(pos)
		if position.Line != line {
			return false
		}
		lineStart := strings.LastIndexByte(source[:position.Offset], '\n') + 1
		return strings.TrimSpace(source[lineStart:position.Offset]) == ""
	}
	// Specs inside grouped declarations start on their own line, whereas an
	// ungrouped declaration starts at its type/var/const keyword. Inspecting the
	// tree also covers local declarations, without mistaking fields for specs.
	var declaration *signature
	ast.Inspect(file, func(node ast.Node) bool {
		if iface, ok := node.(*ast.InterfaceType); ok && iface.Methods != nil {
			for _, method := range iface.Methods.List {
				if len(method.Names) != 1 || !startsLine(method.Pos()) {
					continue
				}
				if fn, ok := method.Type.(*ast.FuncType); ok {
					declaration = functionSignature(method.Names[0].Name, fn, nil)
				}
			}
		}
		group, ok := node.(*ast.GenDecl)
		if !ok || group.Tok == token.IMPORT {
			return true
		}
		for _, spec := range group.Specs {
			start := spec.Pos()
			if !group.Lparen.IsValid() {
				start = group.Pos()
			}
			// Only declarations starting the line can follow the comment.
			if !startsLine(start) {
				continue
			}
			var names []*ast.Ident
			switch spec := spec.(type) {
			case *ast.TypeSpec:
				names = []*ast.Ident{spec.Name}
			case *ast.ValueSpec:
				names = spec.Names
			}
			var documented []string
			for _, name := range names {
				if name.Name != "_" {
					documented = append(documented, name.Name)
				}
			}
			if len(documented) > 0 {
				name := documented[0]
				if len(documented) == 2 {
					name = strings.Join(documented, " and ")
				} else if len(documented) > 2 {
					name = strings.Join(documented[:len(documented)-1], ", ") + ", and " + documented[len(documented)-1]
				}
				declaration = &signature{Name: name, Names: []string{}}
			}
		}
		return true
	})
	if declaration != nil {
		return declaration
	}
	for _, decl := range file.Decls {
		fn, ok := decl.(*ast.FuncDecl)
		if !ok || fset.Position(fn.Pos()).Line != line || fn.Name.Name == "_" {
			continue
		}
		return functionSignature(fn.Name.Name, fn.Type, fn.Recv)
	}
	return nil
}

// Both concrete functions and interface methods use the same validation and
// name collection, so nested function types never contribute their own names.
func functionSignature(name string, fn *ast.FuncType, receiver *ast.FieldList) *signature {
	if name == "_" {
		return nil
	}
	valid := fn.Params != nil && fn.Params.Closing.IsValid()
	ast.Inspect(fn, func(node ast.Node) bool {
		if _, bad := node.(*ast.BadExpr); bad {
			valid = false
		}
		return true
	})
	if !valid || (fn.Results != nil && fn.Results.Opening.IsValid() && !fn.Results.Closing.IsValid()) {
		return nil
	}
	result := &signature{Name: name, Names: []string{}}
	for _, fields := range []*ast.FieldList{receiver, fn.Params, fn.Results} {
		if fields == nil {
			continue
		}
		for _, field := range fields.List {
			for _, name := range field.Names {
				if name.Name != "_" {
					result.Names = append(result.Names, name.Name)
				}
			}
		}
	}
	return result
}

func main() {
	var request struct {
		Source string `json:"source"`
		Line   int    `json:"line"`
	}
	if err := json.NewDecoder(os.Stdin).Decode(&request); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	if err := json.NewEncoder(os.Stdout).Encode(declarationAt(request.Source, request.Line)); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
