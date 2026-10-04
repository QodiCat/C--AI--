package config

import "testing"

func TestReadSeparatesCloudCredentials(t *testing.T) {
	t.Setenv("ALIYUN_ACCESS_KEY_ID", "oss-id")
	t.Setenv("ALIYUN_ACCESS_KEY_SECRET", "oss-secret")
	t.Setenv("ALIYUN_VIAPI_ACCESS_KEY_ID", "vision-id")
	t.Setenv("ALIYUN_VIAPI_ACCESS_KEY_SECRET", "vision-secret")
	t.Setenv("ALIYUN_OSS_ACCESS_KEY_ID", "obsolete-id")
	t.Setenv("ALIYUN_OSS_ACCESS_KEY_SECRET", "obsolete-secret")
	cfg := Read()
	if cfg.AliyunOSSAccessKeyID != "oss-id" || cfg.AliyunOSSAccessKeySecret != "oss-secret" {
		t.Fatal("OSS credentials mapped incorrectly")
	}
	if cfg.AliyunVIAPIAccessKeyID != "vision-id" || cfg.AliyunVIAPIAccessKeySecret != "vision-secret" {
		t.Fatal("VIAPI credentials mapped incorrectly")
	}
	t.Setenv("ALIYUN_VIAPI_ACCESS_KEY_ID", "")
	t.Setenv("ALIYUN_VIAPI_ACCESS_KEY_SECRET", "")
	cfg = Read()
	if cfg.AliyunVIAPIAccessKeyID != "" || cfg.AliyunVIAPIAccessKeySecret != "" {
		t.Fatal("VIAPI must not reuse OSS credentials")
	}
}

func TestDatabaseURLFromPostgresVariables(t *testing.T) {
	t.Setenv("DATABASE_URL", "")
	t.Setenv("POSTGRES_HOST", "db.example.test")
	t.Setenv("POSTGRES_PORT", "5433")
	t.Setenv("POSTGRES_USER", "test-user")
	t.Setenv("POSTGRES_PASSWORD", "test:p@ss/word")
	t.Setenv("POSTGRES_DB", "closet")
	t.Setenv("POSTGRES_SSLMODE", "require")
	t.Setenv("PGHOST", "legacy.example.test")
	got := databaseURL()
	want := "postgresql://test-user:test%3Ap%40ss%2Fword@db.example.test:5433/closet?sslmode=require"
	if got != want {
		t.Fatalf("got %q, want %q", got, want)
	}
	t.Setenv("DATABASE_URL", "explicit-connection")
	if databaseURL() != "explicit-connection" {
		t.Fatal("DATABASE_URL must take priority")
	}
}
