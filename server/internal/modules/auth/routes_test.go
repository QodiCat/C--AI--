package auth

import (
	"bytes"
	"errors"
	"net/http/httptest"
	"regexp"
	"testing"

	"ai-closet-server/internal/infrastructure/database"
	"ai-closet-server/internal/models"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func TestRegistrationRollsBackWhenSessionCreationFails(t *testing.T) {
	db, err := database.Open(":memory:")
	if err != nil {
		t.Fatal(err)
	}
	sqlDB, _ := db.DB()
	defer sqlDB.Close()
	if err := database.AutoMigrate(db); err != nil {
		t.Fatal(err)
	}
	mail := &fakeMail{}
	verifier := NewVerifier(mail)
	if err := verifier.Send("new@example.com", "test"); err != nil {
		t.Fatal(err)
	}
	code := regexp.MustCompile(`[0-9]{6}`).FindString(mail.body)
	router := gin.New()
	RegisterRoutes(router, db, verifier)
	callback := "test:session_failure"
	if err := db.Callback().Create().Before("gorm:create").Register(callback, func(tx *gorm.DB) {
		if tx.Statement.Table == "sessions" {
			tx.AddError(errors.New("session write failed"))
		}
	}); err != nil {
		t.Fatal(err)
	}
	register := func() int {
		body := `{"email":"new@example.com","password":"strongpass","code":"` + code + `"}`
		req := httptest.NewRequest("POST", "/auth/register", bytes.NewBufferString(body))
		req.Header.Set("Content-Type", "application/json")
		out := httptest.NewRecorder()
		router.ServeHTTP(out, req)
		return out.Code
	}
	if got := register(); got != 500 {
		t.Fatalf("got status %d", got)
	}
	var count int64
	if err := db.Model(&models.User{}).Count(&count).Error; err != nil {
		t.Fatal(err)
	}
	if count != 0 {
		t.Fatal("failed registration left an account behind")
	}
	if err := db.Callback().Create().Remove(callback); err != nil {
		t.Fatal(err)
	}
	if got := register(); got != 200 {
		t.Fatalf("retry with same email and code failed: %d", got)
	}
}
