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
