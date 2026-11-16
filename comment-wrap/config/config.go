package config

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

type Language struct {
	Enabled bool `json:"enabled"`
	Width   int  `json:"width"`
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
		Go:              Language{Enabled: true, Width: 100},
		Shellscript:     Language{Enabled: true, Width: 100},
		Python:          Language{Enabled: true, Width: 100},
		Javascript:      Language{Enabled: true, Width: 100},
		Javascriptreact: Language{Enabled: true, Width: 100},
		Typescript:      Language{Enabled: true, Width: 100},
		Typescriptreact: Language{Enabled: true, Width: 100},
		Json:            Language{Enabled: true, Width: 100},
		Jsonc:           Language{Enabled: true, Width: 100},
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
	for _, width := range widths {
		if width < 1 {
			return Config{}, fmt.Errorf("widths in %s must be positive", path)
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
