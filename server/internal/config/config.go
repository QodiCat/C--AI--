package config

import (
	"os"
	"strconv"
)

type Config struct {
	SMTPServer               string
	SMTPPort                 int
	SMTPUsername             string
	SMTPPassword             string
	FromEmail                string
	AppEnv                   string
	Port                     int
	CORSOrigin               string
	DBPath                   string
	AIProvider               string
	AIAPIBaseURL             string
	AIAPIKey                 string
	AliyunOSSRegion          string
	AliyunOSSBucket          string
	AliyunOSSAccessKeyID     string
	AliyunOSSAccessKeySecret string
}

func Read() Config {
	return Config{
		SMTPServer:               getEnv("SMTP_SERVER", ""),
		SMTPPort:                 getEnvInt("SMTP_PORT", 465),
		SMTPUsername:             getEnv("SMTP_USERNAME", ""),
		SMTPPassword:             getEnv("SMTP_PASSWORD", ""),
		FromEmail:                getEnv("FROM_EMAIL", ""),
		AppEnv:                   getEnv("APP_ENV", "development"),
		Port:                     getEnvInt("PORT", 3000),
		CORSOrigin:               getEnv("CORS_ORIGIN", "http://localhost:8080"),
		DBPath:                   getEnv("DB_PATH", "./data/ai_closet.db"),
		AIProvider:               getEnv("AI_PROVIDER", "mock"),
		AIAPIBaseURL:             getEnv("AI_API_BASE_URL", ""),
		AIAPIKey:                 getEnv("AI_API_KEY", ""),
		AliyunOSSRegion:          getEnv("ALIYUN_OSS_REGION", ""),
		AliyunOSSBucket:          getEnv("ALIYUN_OSS_BUCKET", ""),
		AliyunOSSAccessKeyID:     getEnv("ALIYUN_OSS_ACCESS_KEY_ID", ""),
		AliyunOSSAccessKeySecret: getEnv("ALIYUN_OSS_ACCESS_KEY_SECRET", ""),
	}
}

func getEnv(key string, fallback string) string {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}
	return value
}

func getEnvInt(key string, fallback int) int {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}

	parsed, err := strconv.Atoi(value)
	if err != nil {
		return fallback
	}

	return parsed
}
