package config

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLoadEnvUsesServerFile(t *testing.T) {
	root := t.TempDir()
	server := filepath.Join(root, "server")
	if err := os.Mkdir(server, 0700); err != nil {
		t.Fatal(err)
	}
	for path, content := range map[string]string{
		filepath.Join(root, ".env"):   "ENV_TEST_VALUE=root\n",
		filepath.Join(server, ".env"): "# comment\n\nENV_TEST_VALUE='server'\nENV_TEST_EXPORTED=file\n",
	} {
		if err := os.WriteFile(path, []byte(content), 0600); err != nil {
			t.Fatal(err)
		}
	}
	cwd, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.Chdir(cwd) })
	t.Setenv("ENV_TEST_EXPORTED", "exported")
	t.Setenv("ENV_TEST_VALUE", "")
	for _, dir := range []string{root, server} {
		if err := os.Unsetenv("ENV_TEST_VALUE"); err != nil {
			t.Fatal(err)
		}
		if err := os.Chdir(dir); err != nil {
			t.Fatal(err)
		}
		if err := LoadEnv(); err != nil {
			t.Fatal(err)
		}
		if got := os.Getenv("ENV_TEST_VALUE"); got != "server" {
			t.Fatalf("from %s: got %q", dir, got)
		}
		if got := os.Getenv("ENV_TEST_EXPORTED"); got != "exported" {
			t.Fatalf("exported variable overwritten: %q", got)
		}
	}
	if err := os.Remove(filepath.Join(server, ".env")); err != nil {
		t.Fatal(err)
	}
	if err := os.Unsetenv("ENV_TEST_VALUE"); err != nil {
		t.Fatal(err)
	}
	if err := LoadEnv(); err != nil {
		t.Fatal(err)
	}
	if _, ok := os.LookupEnv("ENV_TEST_VALUE"); ok {
		t.Fatal("loaded root .env despite missing server file")
	}
}
