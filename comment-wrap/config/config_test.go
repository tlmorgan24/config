package config

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func fixture(t *testing.T, source string) {
	t.Helper()
	path := filepath.Join(t.TempDir(), "config.jsonc")
	if err := os.WriteFile(path, []byte(source), 0600); err != nil {
		t.Fatal(err)
	}
	t.Setenv("COMMENT_WRAP_CONFIG", path)
	t.Setenv("COMMENT_WRAP_TAB_WIDTH", "")
}

func TestLanguageDefaultsAndOverrides(t *testing.T) {
	fixture(t, `{
		"defaults": {"enabled":true,"width":100,"tabWidth":4,"minColWidth":30},
		"languages": {
			"new-language":{"formatter":"shell-comment-wrap"},
			"disabled":{"formatter":"js-comment-wrap","enabled":false,"width":80}
		}
	} // EOF comment without a final newline`)
	settings, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	language, err := settings.Language("new-language")
	if err != nil || !language.Enabled || language.Width != 100 || language.TabWidth != 4 || language.MinColWidth != 30 {
		t.Fatalf("inherited settings: %+v, %v", language, err)
	}
	language, err = settings.Language("disabled")
	if err != nil || language.Enabled || language.Width != 80 {
		t.Fatalf("overrides: %+v, %v", language, err)
	}
	t.Setenv("COMMENT_WRAP_TAB_WIDTH", "2")
	language, err = settings.Language("new-language")
	if err != nil || language.TabWidth != 2 {
		t.Fatalf("editor tab width: %+v, %v", language, err)
	}
	if _, err := settings.Language("unknown"); err == nil {
		t.Fatal("expected an error for an unconfigured language")
	}
}

func TestInvalidConfig(t *testing.T) {
	for _, source := range []string{
		`{`,
		`{"languages":{}}`,
		`{"defaults":{"width":100,"tabWidth":4,"minColWidth":30},"languages":{"go":{}}}`,
		`{"defaults":{"width":100,"tabWidth":4,"minColWidth":30},"languages":{"go":{"formatter":"go-comment-wrap","width":0}}}`,
	} {
		t.Run(source, func(t *testing.T) {
			fixture(t, source)
			if _, err := Load(); err == nil {
				t.Fatal("expected an invalid config error")
			}
		})
	}
}

func TestInstalledConfigPathAndMissingOverride(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("COMMENT_WRAP_CONFIG", "")
	if _, err := Load(); err == nil || !strings.Contains(err.Error(), filepath.Join(home, "comment-wrap", "config.jsonc")) {
		t.Fatalf("expected relocated config path in error: %v", err)
	}
	t.Setenv("COMMENT_WRAP_CONFIG", filepath.Join(home, "missing.json"))
	if _, err := Load(); err == nil {
		t.Fatal("an explicitly selected missing config must fail")
	}
}

func TestRepositoryConfig(t *testing.T) {
	t.Setenv("COMMENT_WRAP_CONFIG", "../config.jsonc")
	t.Setenv("COMMENT_WRAP_TAB_WIDTH", "")
	settings, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if _, err := settings.Language("jsonc"); err != nil {
		t.Fatal(err)
	}
	t.Setenv("COMMENT_WRAP_TAB_WIDTH", "auto")
	if _, err := settings.Language("go"); err == nil {
		t.Fatal("expected invalid editor tab width error")
	}
}
