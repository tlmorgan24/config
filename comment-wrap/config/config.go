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
	Go          Language `json:"go"`
	Shellscript Language `json:"shellscript"`
}

func Load() (Config, error) {
	config := Config{
		Go:          Language{Enabled: true, Width: 100},
		Shellscript: Language{Enabled: true, Width: 100},
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
	if config.Go.Width < 1 || config.Shellscript.Width < 1 {
		return Config{}, fmt.Errorf("widths in %s must be positive", path)
	}
	return config, nil
}
