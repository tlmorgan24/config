package config

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

type Language struct {
	Enabled     bool `json:"enabled"`
	Width       int  `json:"width"`
	TabWidth    int  `json:"tabWidth"`
	MinColWidth int  `json:"minColWidth"`
}

type Config struct {
	Go              Language `json:"go"`
	Shellscript     Language `json:"shellscript"`
	Python          Language `json:"python"`
	Javascript      Language `json:"javascript"`
	Javascriptreact Language `json:"javascriptreact"`
	Typescript      Language `json:"typescript"`
	Typescriptreact Language `json:"typescriptreact"`
	Json            Language `json:"json"`
	Jsonc           Language `jsonc"`
}

func Load() (Config, error) {
	config := Config{
		Go:              Language{Enabled: true, Width: 100, TabWidth: 4, MinColWidth: 30},
		Shellscript:     Language{Enabled: true, Width: 100, TabWidth: 4, MinColWidth: 30},
		Python:          Language{Enabled: true, Width: 100, TabWidth: 4, MinColWidth: 30},
		Javascript:      Language{Enabled: true, Width: 100, TabWidth: 4, MinColWidth: 30},
		Javascriptreact: Language{Enabled: true, Width: 100, TabWidth: 4, MinColWidth: 30},
		Typescript:      Language{Enabled: true, Width: 100, TabWidth: 4, MinColWidth: 30},
		Typescriptreact: Language{Enabled: true, Width: 100, TabWidth: 4, MinColWidth: 30},
		Json:            Language{Enabled: true, Width: 100, TabWidth: 4, MinColWidth: 30},
		Jsonc:           Language{Enabled: true, Width: 100, TabWidth: 4, MinColWidth: 30},
	}

	path := os.Getenv("COMMENT_WRAP_CONFIG")
	if path == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return Config{}, fmt.Errorf("find home directory: %w", err)
		}
		path = filepath.Join(home, ".config", "comment-wrap", "config.json")
	}

	source, err := os.ReadFile(path)
	if os.IsNotExist(err) {
		return config, nil
	}

	if err != nil {
		return Config{}, fmt.Errorf("read %s: %w", path, err)
	}
	if err := json.Unmarshal(source, &config); err != nil {
		return Config{}, fmt.Errorf("parse %s: %w", path, err)
	}
	widths := []int{
		config.Go.Width, config.Shellscript.Width, config.Python.Width,
		config.Javascript.Width, config.Javascriptreact.Width,
		config.Typescript.Width, config.Typescriptreact.Width,
		config.Json.Width, config.Jsonc.Width,
	}
	tabWidths := []int{
		config.Go.TabWidth, config.Shellscript.TabWidth, config.Python.TabWidth,
		config.Javascript.TabWidth, config.Javascriptreact.TabWidth,
		config.Typescript.TabWidth, config.Typescriptreact.TabWidth,
		config.Json.TabWidth, config.Jsonc.TabWidth,
	}
	minColWidths := []int{
		config.Go.MinColWidth, config.Shellscript.MinColWidth, config.Python.MinColWidth,
		config.Javascript.MinColWidth, config.Javascriptreact.MinColWidth,
		config.Typescript.MinColWidth, config.Typescriptreact.MinColWidth,
		config.Json.MinColWidth, config.Jsonc.MinColWidth,
	}
	for _, width := range widths {
		if width < 1 {
			return Config{}, fmt.Errorf("widths in %s must be positive", path)
		}
	}
	for _, width := range tabWidths {
		if width < 1 {
			return Config{}, fmt.Errorf("tab widths in %s must be positive", path)
		}
	}
	for _, width := range minColWidths {
		if width < 1 {
			return Config{}, fmt.Errorf("minimum column widths in %s must be positive", path)
		}
	}
	return config, nil
}

func (c Config) Language(languageID string) (Language, error) {
	switch languageID {
	case "go":
		return c.Go, nil
	case "shellscript":
		return c.Shellscript, nil
	case "python":
		return c.Python, nil
	case "javascript":
		return c.Javascript, nil
	case "javascriptreact":
		return c.Javascriptreact, nil
	case "typescript":
		return c.Typescript, nil
	case "typescriptreact":
		return c.Typescriptreact, nil
	case "json":
		return c.Json, nil
	case "jsonc":
		return c.Jsonc, nil
	default:
		return Language{}, fmt.Errorf("missing configuration for %s", languageID)
	}
}
