package config

import (
	"bufio"
	"fmt"
	"os"
	"strings"
)

// LoadEnv loads the first existing local environment file. Exported variables win.
func LoadEnv() error {
	for _, path := range []string{".env", "../.env"} {
		f, err := os.Open(path)
		if os.IsNotExist(err) {
			continue
		}
		if err != nil {
			return err
		}
		defer f.Close()
		scanner := bufio.NewScanner(f)
		for scanner.Scan() {
			line := strings.TrimSpace(scanner.Text())
			if line == "" || strings.HasPrefix(line, "#") {
				continue
			}
			key, value, ok := strings.Cut(line, "=")
			if !ok {
				return fmt.Errorf("invalid environment line in %s", path)
			}
			key = strings.TrimSpace(strings.TrimPrefix(key, "export "))
			value = strings.TrimSpace(value)
			if len(value) >= 2 && ((value[0] == '"' && value[len(value)-1] == '"') || (value[0] == '\'' && value[len(value)-1] == '\'')) {
				value = value[1 : len(value)-1]
			}
			if _, exists := os.LookupEnv(key); !exists {
				if err := os.Setenv(key, value); err != nil {
					return fmt.Errorf("invalid environment key in %s", path)
				}
			}
		}
		return scanner.Err()
	}
	return nil
}
