package bootstrap

import (
	"fmt"
	"os"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"

	"ai-closet-server/internal/config"
	"ai-closet-server/internal/httpapi"
	"ai-closet-server/internal/infrastructure/database"
	"ai-closet-server/internal/modules/ai"
	"ai-closet-server/internal/modules/item"
	"ai-closet-server/internal/modules/oss"
	"ai-closet-server/internal/modules/profile"
	"ai-closet-server/internal/modules/recommendation"
	"ai-closet-server/internal/modules/wearlog"
)

type App struct {
	engine *gin.Engine
	port   int
}

func NewApp() (*App, error) {
	cfg := config.Read()

	if err := os.MkdirAll("data", 0o755); err != nil {
		return nil, fmt.Errorf("create data dir: %w", err)
	}

	db, err := database.Open(cfg.DBPath)
	if err != nil {
		return nil, err
	}

	if err := database.AutoMigrate(db); err != nil {
		return nil, err
	}

	if err := database.SeedDemoData(db); err != nil {
		return nil, err
	}

	router := gin.Default()
	router.Use(cors.New(cors.Config{
		AllowOrigins:     []string{cfg.CORSOrigin},
		AllowMethods:     []string{"GET", "POST", "PATCH", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Authorization"},
		AllowCredentials: true,
	}))

	router.GET("/health", func(c *gin.Context) {
		httpapi.OK(c, gin.H{
			"status": "ok",
			"date":   "2026-08-24",
		})
	})

	aiProvider := ai.NewProvider(cfg)
	aiService := ai.NewService(db, aiProvider)

	item.RegisterRoutes(router, db)
	profile.RegisterRoutes(router, db)
	recommendation.RegisterRoutes(router, aiService)
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
