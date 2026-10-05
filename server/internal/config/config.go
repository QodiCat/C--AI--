package config

import (
	"net"
	"net/url"
	"os"
	"strconv"
	"strings"
)

type Config struct {
	WeatherBaseURL             string
	DashScopeAPIKey            string
	QwenBaseURL                string
	QwenVisionModel            string
	QwenTextModel              string
	AliyunVIAPIAccessKeyID     string
	AliyunVIAPIAccessKeySecret string
	SMTPServer                 string
	SMTPPort                   int
	SMTPUsername               string
	SMTPPassword               string
	FromEmail                  string
	AppEnv                     string
	Port                       int
	CORSOrigin                 string
	DatabaseURL                string
	SeedDemo                   bool
	DBPath                     string
	AIProvider                 string
	AIAPIBaseURL               string
	AIAPIKey                   string
	AliyunOSSRegion            string
	AliyunOSSBucket            string
	AliyunOSSAccessKeyID       string
	AliyunOSSAccessKeySecret   string
}

func Read() Config {
	return Config{
		WeatherBaseURL:             getEnv("WEATHER_BASE_URL", "https://api.open-meteo.com/v1/forecast"),
		DashScopeAPIKey:            getEnv("DASHSCOPE_API_KEY", ""),
		QwenBaseURL:                getEnv("QWEN_BASE_URL", "https://dashscope.aliyuncs.com/compatible-mode/v1"),
		QwenVisionModel:            getEnv("QWEN_VISION_MODEL", "qwen3-vl-plus"),
		QwenTextModel:              getEnv("QWEN_TEXT_MODEL", "qwen-plus"),
		AliyunVIAPIAccessKeyID:     getEnv("ALIYUN_VIAPI_ACCESS_KEY_ID", ""),
		AliyunVIAPIAccessKeySecret: getEnv("ALIYUN_VIAPI_ACCESS_KEY_SECRET", ""),
		SMTPServer:                 getEnv("SMTP_SERVER", ""),
		SMTPPort:                   getEnvInt("SMTP_PORT", 465),
		SMTPUsername:               getEnv("SMTP_USERNAME", ""),
		SMTPPassword:               getEnv("SMTP_PASSWORD", ""),
		FromEmail:                  getEnv("FROM_EMAIL", ""),
		AppEnv:                     getEnv("APP_ENV", "development"),
		Port:                       getEnvInt("PORT", 3000),
		CORSOrigin:                 getEnv("CORS_ORIGIN", "http://localhost:8080"),
		DatabaseURL:                databaseURL(),
		SeedDemo:                   getEnv("SEED_DEMO_DATA", "false") == "true",
		DBPath:                     getEnv("DB_PATH", "./data/ai_closet.db"),
		AIProvider:                 getEnv("AI_PROVIDER", "qwen"),
		AIAPIBaseURL:               getEnv("AI_API_BASE_URL", ""),
		AIAPIKey:                   getEnv("AI_API_KEY", ""),
		AliyunOSSRegion:            ossRegion(getEnv("ALIYUN_OSS_REGION", "")),
		AliyunOSSBucket:            getEnv("ALIYUN_OSS_BUCKET", getEnv("ALIYUN_OSS_BUCKET_NAME", "")),
		AliyunOSSAccessKeyID:       getEnv("ALIYUN_ACCESS_KEY_ID", ""),
		AliyunOSSAccessKeySecret:   getEnv("ALIYUN_ACCESS_KEY_SECRET", ""),
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

func databaseURL() string {
	if dsn := os.Getenv("DATABASE_URL"); dsn != "" {
		return dsn
	}
	host := getEnv("POSTGRES_HOST", os.Getenv("PGHOST"))
	if host == "" {
		return ""
	}
	connection := url.URL{Scheme: "postgresql", Host: net.JoinHostPort(host, getEnv("POSTGRES_PORT", getEnv("PGPORT", "5432"))), User: url.UserPassword(getEnv("POSTGRES_USER", getEnv("PGUSER", "ai_closet")), getEnv("POSTGRES_PASSWORD", os.Getenv("PGPASSWORD"))), Path: "/" + getEnv("POSTGRES_DB", getEnv("PGDATABASE", "ai_closet"))}
	params := connection.Query()
	params.Set("sslmode", getEnv("POSTGRES_SSLMODE", getEnv("PGSSLMODE", "require")))
	connection.RawQuery = params.Encode()
	return connection.String()
}

func ossRegion(region string) string {
	if region != "" && !strings.HasPrefix(region, "oss-") {
		return "oss-" + region
	}
	return region
}
