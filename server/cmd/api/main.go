package main

import (
	"ai-closet-server/internal/config"
	"log"

	"ai-closet-server/internal/bootstrap"
)

func main() {
	if err := config.LoadEnv(); err != nil {
		log.Fatalf("environment configuration failed: %v", err)
	}
	app, err := bootstrap.NewApp()
	if err != nil {
		log.Fatalf("bootstrap failed: %v", err)
	}

	if err := app.Run(); err != nil {
		log.Fatalf("server stopped: %v", err)
	}
}
