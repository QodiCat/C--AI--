package profile

import (
	"ai-closet-server/internal/infrastructure/database"
	"ai-closet-server/internal/models"
	"ai-closet-server/internal/modules/auth"
	"bytes"
	"github.com/gin-gonic/gin"
	"net/http/httptest"
	"testing"
	"time"
)

func TestBodyMeasurements(t *testing.T) {
	db, err := database.Open(":memory:")
	if err != nil {
		t.Fatal(err)
	}
	sqlDB, _ := db.DB()
	defer sqlDB.Close()
	if err := database.AutoMigrate(db); err != nil {
		t.Fatal(err)
	}
	for _, id := range []string{"owner", "other"} {
		if err := db.Create(&models.User{ID: id, Email: id + "@example.com", Nickname: id, Height: 170, Weight: 60}).Error; err != nil {
			t.Fatal(err)
		}
		if err := db.Create(&models.Session{ID: id, UserID: id, Token: id, ExpiresAt: time.Now().Add(time.Hour)}).Error; err != nil {
			t.Fatal(err)
		}
	}
	router := gin.New()
	router.Use(auth.RequireAuth(db))
	RegisterRoutes(router, db)
	call := func(path, token, body string, want int) {
		t.Helper()
		req := httptest.NewRequest("PATCH", path, bytes.NewBufferString(body))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+token)
		out := httptest.NewRecorder()
		router.ServeHTTP(out, req)
		if out.Code != want {
			t.Fatalf("%d: %s", out.Code, out.Body.String())
		}
	}
	call("/me/body-measurements", "", `{"bust":90}`, 401)
	call("/me/body-measurements", "owner", `{"height":175.5,"weight":65.2,"bust":90,"hip":95,"waist":75,"shoulderWidth":42,"thighCircumference":55,"legLength":90,"torsoLength":50}`, 200)
	for _, body := range []string{`{"bust":null}`, `{"bust":-1}`, `{"waist":301}`, `{"hip":"bad"}`, `{"userId":1}`, `{}`, `null`} {
		call("/me/body-measurements", "owner", body, 400)
	}
	call("/me/profile", "owner", `{"nickname":"new"}`, 200)
	var user models.User
	if err := db.First(&user, "id = ?", "owner").Error; err != nil {
		t.Fatal(err)
	}
	if user.Height != 175.5 || user.Weight != 65.2 || user.Bust != 90 || user.Hip != 95 || user.Waist != 75 || user.ShoulderWidth != 42 || user.ThighCircumference != 55 || user.LegLength != 90 || user.TorsoLength != 50 {
		t.Fatalf("measurements lost: %+v", user)
	}
	call("/me/body-measurements", "owner", `{"bust":0}`, 200)
	if err := db.First(&user, "id = ?", "owner").Error; err != nil {
		t.Fatal(err)
	}
	if user.Bust != 0 || user.Waist != 75 || user.Nickname != "new" {
		t.Fatal("clear changed unrelated data")
	}
	var other models.User
	if err := db.First(&other, "id = ?", "other").Error; err != nil {
		t.Fatal(err)
	}
	if other.Height != 170 || other.Bust != 0 {
		t.Fatal("cross-user modification")
	}
}
