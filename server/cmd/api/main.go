package main

import (
	"log"

	"ai-closet-server/internal/bootstrap"
)

func main() {
	app, err := bootstrap.NewApp()
	if err != nil {
		log.Fatalf("bootstrap failed: %v", err)
	}

	if err := app.Run(); err != nil {
		log.Fatalf("server stopped: %v", err)
	}
}
