package bootstrap

import (
	"fmt"
	"gorm.io/gorm"
	"os"
	"strings"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"

	"ai-closet-server/internal/config"
	"ai-closet-server/internal/httpapi"
	"ai-closet-server/internal/infrastructure/database"
	"ai-closet-server/internal/infrastructure/mailer"
	"ai-closet-server/internal/modules/ai"
	"ai-closet-server/internal/modules/auth"
	"ai-closet-server/internal/modules/imageprocess"
	"ai-closet-server/internal/modules/item"
	"ai-closet-server/internal/modules/oss"
	"ai-closet-server/internal/modules/outfit"
	"ai-closet-server/internal/modules/profile"
	"ai-closet-server/internal/modules/recommendation"
	"ai-closet-server/internal/modules/wearlog"
	"ai-closet-server/internal/modules/weather"
)

type App struct {
	engine *gin.Engine
	port   int
}

func NewApp() (*App, error) { return newApp(mailer.New(config.Read())) }

func newApp(sender auth.MailSender) (*App, error) {
	cfg := config.Read()

	if err := os.MkdirAll("data", 0o755); err != nil {
		return nil, fmt.Errorf("create data dir: %w", err)
	}

	var db *gorm.DB
	var err error
	if cfg.DatabaseURL != "" {
		db, err = database.OpenPostgres(cfg.DatabaseURL)
	} else {
		if cfg.AppEnv != "test" {
			return nil, fmt.Errorf("DATABASE_URL is required; SQLite is reserved for tests")
		}
		db, err = database.Open(cfg.DBPath)
	}
	if err != nil {
		return nil, err
	}

	if err := database.AutoMigrate(db); err != nil {
		return nil, err
	}

	if cfg.SeedDemo {
		if cfg.AppEnv == "production" {
			return nil, fmt.Errorf("demo data is forbidden in production")
		}
		if err := database.SeedDemoData(db); err != nil {
			return nil, err
		}
	}

	router := gin.Default()
	router.Use(cors.New(cors.Config{
		AllowOrigins:     strings.Split(cfg.CORSOrigin, ","),
		AllowMethods:     []string{"GET", "POST", "PATCH", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Authorization"},
		AllowCredentials: true,
	}))

	router.GET("/health", func(c *gin.Context) {
		httpapi.OK(c, gin.H{
			"status": "ok",
		})
	})

	if cfg.AppEnv == "production" && cfg.AIProvider == "mock" {
		return nil, fmt.Errorf("mock AI is forbidden in production")
	}
	aiProvider := ai.NewProvider(cfg)
	aiService := ai.NewService(db, aiProvider)

	auth.RegisterRoutes(router, db, auth.NewVerifier(sender))
	router.Use(auth.RequireAuth(db))
	item.RegisterRoutes(router, db)
	imageprocess.RegisterRoutes(router, db, imageprocess.NewProcessor(cfg), cfg)
	outfit.RegisterRoutes(router, db)
	profile.RegisterRoutes(router, db)
	recommendation.RegisterRoutes(router, aiService, weather.New(cfg.WeatherBaseURL))
	wearlog.RegisterRoutes(router, db)
	oss.RegisterRoutes(router, cfg)

	return &App{
		engine: router,
		port:   cfg.Port,
	}, nil
}

func (app *App) Run() error {
	return app.engine.Run(fmt.Sprintf(":%d", app.port))
}
