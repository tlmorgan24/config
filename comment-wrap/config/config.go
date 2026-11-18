package config

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strconv"

	"github.com/tailscale/hujson"
)

type Language struct {
	Enabled     bool     `json:"enabled"`
	Width       int      `json:"width"`
	TabWidth    int      `json:"tabWidth"`
	MinColWidth int      `json:"minColWidth"`
	Formatter   string   `json:"formatter"`
	Args        []string `json:"args"`
}

type Config struct {
	Defaults  Language                   `json:"defaults"`
	Languages map[string]json.RawMessage `json:"languages"`
}

func Load() (Config, error) {
	path := os.Getenv("COMMENT_WRAP_CONFIG")
	if path == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return Config{}, fmt.Errorf("find home directory: %w", err)
		}
		path = filepath.Join(home, "comment-wrap", "config.jsonc")
	}
	source, err := os.ReadFile(path)
	if err != nil {
		return Config{}, fmt.Errorf("read %s: %w", path, err)
	}
	// hujson requires a newline to terminate a line comment at EOF.
	source, err = hujson.Standardize(append(source, '\n'))
	if err != nil {
		return Config{}, fmt.Errorf("parse %s: %w", path, err)
	}
	var settings Config
	if err := json.Unmarshal(source, &settings); err != nil {
		return Config{}, fmt.Errorf("parse %s: %w", path, err)
	}
	if len(settings.Languages) == 0 {
		return Config{}, fmt.Errorf("no languages configured in %s", path)
	}
	for id := range settings.Languages {
		if _, err := settings.Language(id); err != nil {
			return Config{}, fmt.Errorf("%s: %w", path, err)
		}
	}
	return settings, nil
}

func (c Config) Language(languageID string) (Language, error) {
	source, ok := c.Languages[languageID]
	if !ok {
		return Language{}, fmt.Errorf("missing configuration for %s", languageID)
	}
	language := c.Defaults
	if err := json.Unmarshal(source, &language); err != nil {
		return Language{}, fmt.Errorf("parse %s: %w", languageID, err)
	}
	// The extension supplies the document's effective indentation, including
	// workspace settings and detected indentation. Standalone commands use config.
	if value := os.Getenv("COMMENT_WRAP_TAB_WIDTH"); value != "" {
		width, err := strconv.Atoi(value)
		if err != nil || width < 1 {
			return Language{}, fmt.Errorf("COMMENT_WRAP_TAB_WIDTH must be a positive integer")
		}
		language.TabWidth = width
	}
	if language.Width < 1 || language.TabWidth < 1 || language.MinColWidth < 1 {
		return Language{}, fmt.Errorf("width, tabWidth and minColWidth for %s must be positive", languageID)
	}
	if language.Formatter == "" {
		return Language{}, fmt.Errorf("missing formatter for %s", languageID)
	}
	return language, nil
}

// LanguageID lets the editor select any configured language without passing a
// positional argument that an underlying formatter could mistake for a filename.
func LanguageID(fallback string) string {
	if id := os.Getenv("COMMENT_WRAP_LANGUAGE"); id != "" {
		return id
	}
	return fallback
}
