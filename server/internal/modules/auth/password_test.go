package auth

import (
	"bytes"
	"encoding/json"
	"errors"
	"net/http/httptest"
	"regexp"
	"testing"
	"time"

	"ai-closet-server/internal/infrastructure/database"
	"ai-closet-server/internal/models"
	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

func TestPasswordRoutes(t *testing.T) {
	db, err := database.Open(":memory:")
	if err != nil {
		t.Fatal(err)
	}
	sqlDB, _ := db.DB()
	defer sqlDB.Close()
	if err := database.AutoMigrate(db); err != nil {
		t.Fatal(err)
	}
	hash, _ := bcrypt.GenerateFromPassword([]byte("oldpassword"), bcrypt.MinCost)
	user := models.User{ID: "user_password", Email: "password@example.com", PasswordHash: string(hash)}
	if err := db.Create(&user).Error; err != nil {
		t.Fatal(err)
	}
	session := models.Session{ID: "session_password", UserID: user.ID, Token: "token_password", ExpiresAt: time.Now().Add(time.Hour)}
	if err := db.Create(&session).Error; err != nil {
		t.Fatal(err)
	}
	mail := &fakeMail{}
	verifier := NewVerifier(mail)
	router := gin.New()
	RegisterRoutes(router, db, verifier)
	post := func(path, token string, body map[string]string) int {
		raw, _ := json.Marshal(body)
		req := httptest.NewRequest("POST", path, bytes.NewReader(raw))
		req.Header.Set("Content-Type", "application/json")
		if token != "" {
			req.Header.Set("Authorization", "Bearer "+token)
		}
		out := httptest.NewRecorder()
		router.ServeHTTP(out, req)
		return out.Code
	}
	check := func(got, want int) {
		t.Helper()
		if got != want {
			t.Fatalf("status got %d want %d", got, want)
		}
	}
	change := map[string]string{"currentPassword": "wrongpassword", "newPassword": "newpassword"}
	check(post("/auth/password/change", "", change), 401)
	check(post("/auth/password/change", session.Token, change), 400)
	change["currentPassword"] = "oldpassword"
	// A failed session revocation must roll back the password change.
	callback := "test:revoke_failure"
	if err := db.Callback().Delete().Before("gorm:delete").Register(callback, func(tx *gorm.DB) {
		if tx.Statement.Table == "sessions" {
			tx.AddError(gorm.ErrInvalidTransaction)
		}
	}); err != nil {
		t.Fatal(err)
	}
	check(post("/auth/password/change", session.Token, change), 500)
	db.First(&user, "id = ?", user.ID)
	if bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte("oldpassword")) != nil {
		t.Fatal("failed revocation changed password")
	}
	db.Callback().Delete().Remove(callback)
	check(post("/auth/password/change", session.Token, change), 200)
	check(post("/auth/password/change", session.Token, change), 401)
	check(post("/auth/login", "", map[string]string{"email": user.Email, "password": "oldpassword"}), 401)
	check(post("/auth/login", "", map[string]string{"email": user.Email, "password": "newpassword"}), 200)
	check(post("/auth/password/reset/code", "", map[string]string{"email": "unknown@example.com"}), 200)
	if mail.body != "" {
		t.Fatal("sent email for nonexistent account")
	}
	// Registration and reset codes cannot be substituted.
	if err := verifier.Send(user.Email, "test"); err != nil {
		t.Fatal(err)
	}
	registrationCode := regexp.MustCompile(`[0-9]{6}`).FindString(mail.body)
	reset := map[string]string{"email": user.Email, "code": registrationCode, "newPassword": "resetpassword"}
	check(post("/auth/password/reset", "", reset), 400)
	check(post("/auth/password/reset/code", "", map[string]string{"email": user.Email}), 200)
	resetCode := regexp.MustCompile(`[0-9]{6}`).FindString(mail.body)
	if err := verifier.Register("unregistered@example.com", resetCode, func() error { t.Fatal("reset code registered an account"); return nil }); err == nil {
		t.Fatal("missing registration rejection")
	}
	check(post("/auth/password/reset/code", "", map[string]string{"email": user.Email}), 429)
	reset["code"] = resetCode
	check(post("/auth/password/reset", "", reset), 200)
	check(post("/auth/password/reset", "", reset), 400)
	check(post("/auth/login", "", map[string]string{"email": user.Email, "password": "newpassword"}), 401)
	var count int64
	if err := db.Model(&models.Session{}).Where("user_id = ?", user.ID).Count(&count).Error; err != nil {
		t.Fatal(err)
	}
	if count != 0 {
		t.Fatal("reset left active sessions")
	}
	check(post("/auth/login", "", map[string]string{"email": user.Email, "password": "resetpassword"}), 200)
}

func TestPasswordResetForLegacyNullHash(t *testing.T) {
	db, err := database.Open(":memory:")
	if err != nil {
		t.Fatal(err)
	}
	sqlDB, _ := db.DB()
	defer sqlDB.Close()
	if err := database.AutoMigrate(db); err != nil {
		t.Fatal(err)
	}
	user := models.User{ID: "legacy", Email: "legacy@example.com"}
	if err := db.Create(&user).Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Model(&user).Update("password_hash", nil).Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Create(&models.Session{ID: "legacy-session", UserID: user.ID, Token: "legacy-token", ExpiresAt: time.Now().Add(time.Hour)}).Error; err != nil {
		t.Fatal(err)
	}
	mail := &fakeMail{}
	verifier := NewVerifier(mail)
	if err := verifier.SendPasswordReset(user.Email, "test"); err != nil {
		t.Fatal(err)
	}
	code := regexp.MustCompile(`[0-9]{6}`).FindString(mail.body)
	router := gin.New()
	RegisterRoutes(router, db, verifier)
	raw, _ := json.Marshal(map[string]string{"email": user.Email, "code": code, "newPassword": "newpassword"})
	req := httptest.NewRequest("POST", "/auth/password/reset", bytes.NewReader(raw))
	req.Header.Set("Content-Type", "application/json")
	out := httptest.NewRecorder()
	router.ServeHTTP(out, req)
	if out.Code != 200 {
		t.Fatalf("NULL password reset failed: status=%d body=%s", out.Code, out.Body.String())
	}
	if err := db.First(&user, "id = ?", user.ID).Error; err != nil {
		t.Fatal(err)
	}
	if bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte("newpassword")) != nil {
		t.Fatal("new password was not saved")
	}
	var count int64
	if err := db.Model(&models.Session{}).Where("user_id = ?", user.ID).Count(&count).Error; err != nil {
		t.Fatal(err)
	}
	if count != 0 {
		t.Fatal("old sessions were not revoked")
	}
	// Optimistic matching still prevents a stale update from replacing a newer password.
	stale := user
	stale.PasswordHash = ""
	if err := replacePassword(db, stale, "stalehash"); !errors.Is(err, errPasswordChanged) {
		t.Fatalf("stale update accepted: %v", err)
	}
}
