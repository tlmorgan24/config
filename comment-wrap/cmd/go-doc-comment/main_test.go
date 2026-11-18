package main

import (
	"reflect"
	"testing"
)

func TestDeclarationAt(t *testing.T) {
	tests := []struct {
		name, source string
		want         *signature
	}{
		{"unnamed return", "func Format(source []byte, options commentwrap.Options) []byte {", &signature{"Format", []string{"source", "options"}}},
		{"named returns", "func foo(source []byte, options commentwrap.Options) (oo []byte, bb int) {", &signature{"foo", []string{"source", "options", "oo", "bb"}}},
		{"method", "func (r *Reader[T]) Read(a, b int, rest ...string) (n, m int, err error) {}", &signature{"Read", []string{"r", "a", "b", "rest", "n", "m", "err"}}},
		{"unnamed receiver", "func (*Reader) Read(p []byte) (n int) {}", &signature{"Read", []string{"p", "n"}}},
		{"blank receiver", "func (_ Reader) Read(p []byte) (n int) {}", &signature{"Read", []string{"p", "n"}}},
		{"generic multiline", "func Map[T, U any](\n values []T,\n f func(T, int) U,\n) (result []U) {", &signature{"Map", []string{"values", "f", "result"}}},
		{"nested types", "func Process(f func(inner int) (nested bool), c interface{ M(x int) }, s struct{ Field int }) (func(named int), error) {}", &signature{"Process", []string{"f", "c", "s"}}},
		{"blank names", "func Skip(_ int, value int) (_ bool, err error) {}", &signature{"Skip", []string{"value", "err"}}},
		{"unnamed params", "func Unnamed(int, string) (int, error)", &signature{"Unnamed", []string{}}},
		{"empty", "func Empty() {}", &signature{"Empty", []string{}}},
		{"one-line function with local declaration", "func Work(p int) { var local int }", &signature{"Work", []string{"p"}}},
		{"function variable", "var f = func(a int) {}", &signature{"f", []string{}}},
		{"raw string variable", "var text = `\nfunc Fake(a int) {}\n`", &signature{"text", []string{}}},
		{"struct", "type Options struct { Width int }", &signature{"Options", []string{}}},
		{"interface", "type Reader interface { Read(p []byte) (n int, err error) }", &signature{"Reader", []string{}}},
		{"alias", "type Alias = []byte", &signature{"Alias", []string{}}},
		{"generic type", "type Set[T comparable] map[T]bool", &signature{"Set", []string{}}},
		{"function type", "type Callback func(p []byte) (n int)", &signature{"Callback", []string{}}},
		{"variable", "var Default = Options{}", &signature{"Default", []string{}}},
		{"constant", "const Limit = 10", &signature{"Limit", []string{}}},
		{"two names", "var First, Second int", &signature{"First and Second", []string{}}},
		{"three names", "var first, second, third int", &signature{"first, second, and third", []string{}}},
		{"four names", "const first, second, third, fourth = 1, 2, 3, 4", &signature{"first, second, third, and fourth", []string{}}},
		{"multiple names with blank", "var first, _, second int", &signature{"first and second", []string{}}},
		{"blank variable", "var _ = check()", nil},
		{"mixed blank names", "var _, Value = pair()", &signature{"Value", []string{}}},
		{"import", "import named \"fmt\"", nil},
		{"group header", "const (\nFirst = iota\nSecond\n)", nil},
		{"one-line group header", "const ( First = 1; Second = 2 )", nil},
		{"block comment", "/*\nfunc Fake(a int) {}\n*/", nil},
		{"broken signature", "func Broken(value []", nil},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			source := "package example\n//\n" + tt.source
			if got := declarationAt(source, 3); !reflect.DeepEqual(got, tt.want) {
				t.Fatalf("got %#v, want %#v", got, tt.want)
			}
		})
	}
	if got := declarationAt("package p\n\nfunc Other(a int) {}", 2); got != nil {
		t.Fatalf("matched declaration on a different line: %#v", got)
	}
	for _, source := range []string{
		"package p\nvar text = `\nfunc Fake(a int) {}\n`",
		"package p\n/*\nfunc Fake(a int) {}\n*/",
	} {
		if got := declarationAt(source, 3); got != nil {
			t.Fatalf("matched function text inside a string or comment: %#v", got)
		}
	}
}

func TestNestedDeclarations(t *testing.T) {
	tests := []struct {
		name, source string
		line         int
		want         *signature
	}{
		{"grouped type", "package p\ntype (\n//\nOptions struct { Width int }\n)", 4, &signature{"Options", []string{}}},
		{"grouped variable", "package p\nvar (\n//\nFirst, Second int\n)", 4, &signature{"First and Second", []string{}}},
		{"implicit constant", "package p\nconst (\nFirst = iota\n//\nSecond\n)", 5, &signature{"Second", []string{}}},
		{"local variable", "package p\nfunc F() {\n//\nvar value int\n}", 4, &signature{"value", []string{}}},
		{"local type", "package p\nfunc F() {\n//\ntype item struct{}\n}", 4, &signature{"item", []string{}}},
		{"struct field", "package p\ntype T struct {\n//\nField int\n}", 4, nil},
		{"function struct field", "package p\ntype T struct {\n//\nRead func(p []byte) (n int)\n}", 4, nil},
		{"interface method", "package p\ntype I interface {\n//\nRead(p []byte) (n int)\n}", 4, &signature{"Read", []string{"p", "n"}}},
		{"assignment", "package p\nfunc F() {\n//\nvalue := 1\n}", 4, nil},
		{"blank line", "package p\n//\n\ntype Options struct{}", 3, nil},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := declarationAt(tt.source, tt.line); !reflect.DeepEqual(got, tt.want) {
				t.Fatalf("got %#v, want %#v", got, tt.want)
			}
		})
	}
}

func TestInterfaceMethods(t *testing.T) {
	tests := []struct {
		name, method string
		want         *signature
	}{
		{"named returns", "Read(p []byte) (n int, err error)", &signature{"Read", []string{"p", "n", "err"}}},
		{"unnamed returns", "Get(key string) ([]byte, error)", &signature{"Get", []string{"key"}}},
		{"grouped and variadic", "Write(a, b int, rest ...string) (n, m int)", &signature{"Write", []string{"a", "b", "rest", "n", "m"}}},
		{"multiline", "Read(\n p []byte,\n) (\n n int,\n err error,\n)", &signature{"Read", []string{"p", "n", "err"}}},
		{"blank names", "Read(_ []byte, p []byte) (_ int, err error)", &signature{"Read", []string{"p", "err"}}},
		{"nested function type", "Visit(f func(inner int) (out bool)) (err error)", &signature{"Visit", []string{"f", "err"}}},
		{"empty", "Close()", &signature{"Close", []string{}}},
		{"all unnamed", "Read([]byte) (int, error)", &signature{"Read", []string{}}},
		{"embedded interface", "Reader", nil},
		{"qualified embedded interface", "io.Reader", nil},
		{"constraint", "~int | ~string", nil},
		{"incomplete signature", "Read(p []", nil},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			source := "package p\ntype I interface {\n//\n" + tt.method + "\n}"
			if got := declarationAt(source, 4); !reflect.DeepEqual(got, tt.want) {
				t.Fatalf("got %#v, want %#v", got, tt.want)
			}
		})
	}
}
