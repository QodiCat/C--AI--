package profile

import (
	"ai-closet-server/internal/infrastructure/database"
	"ai-closet-server/internal/models"
	"ai-closet-server/internal/modules/auth"
	"bytes"
	"encoding/json"
	"fmt"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
	"net/http/httptest"
	"testing"
	"time"
)

func TestWardrobeDisplayPreferences(t *testing.T) {
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
		if err := db.Create(&models.User{ID: id, Email: id + "@example.com", Height: 170, StylePreferences: `["极简"]`}).Error; err != nil {
			t.Fatal(err)
		}
		if err := db.Create(&models.Session{ID: id, UserID: id, Token: id, ExpiresAt: time.Now().Add(time.Hour)}).Error; err != nil {
			t.Fatal(err)
		}
	}
	router := gin.New()
	router.Use(auth.RequireAuth(db))
	RegisterRoutes(router, db)
	call := func(method, path, token, body string, want int) *httptest.ResponseRecorder {
		t.Helper()
		req := httptest.NewRequest(method, path, bytes.NewBufferString(body))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+token)
		out := httptest.NewRecorder()
		router.ServeHTTP(out, req)
		if out.Code != want {
			t.Fatalf("%d %s", out.Code, out.Body.String())
		}
		return out
	}
	var initial models.User
	if err := db.First(&initial, "id = ?", "owner").Error; err != nil {
		t.Fatal(err)
	}
	if initial.WardrobeDisplayPreferences != "{}" {
		t.Fatal("existing/default users should display all")
	}
	path := "/me/wardrobe-display"
	body := `{"categories":["上装","下装","鞋履"],"seasons":["秋","冬"],"userId":"other"}`
	call("PATCH", path, "", body, 401)
	for _, bad := range []string{`{}`, `{"categories":null,"seasons":[]}`, `{"categories":[],"seasons":null}`, `{"categories":["上装","上装"],"seasons":[]}`, `{"categories":["未知"],"seasons":[]}`, `{"categories":[],"seasons":["秋","秋"]}`, `{"categories":[],"seasons":["秋冬"]}`} {
		call("PATCH", path, "owner", bad, 400)
	}
	call("PATCH", path, "owner", body, 200)
	fetched := call("GET", "/me", "owner", "", 200)
	var response struct {
		Data models.User `json:"data"`
	}
	if err := json.Unmarshal(fetched.Body.Bytes(), &response); err != nil {
		t.Fatal(err)
	}
	var saved struct {
		Categories []string `json:"categories"`
		Seasons    []string `json:"seasons"`
	}
	if err := json.Unmarshal([]byte(response.Data.WardrobeDisplayPreferences), &saved); err != nil {
		t.Fatal(err)
	}
	if len(saved.Categories) != 3 || len(saved.Seasons) != 2 || response.Data.Height != 170 || response.Data.StylePreferences != `["极简"]` {
		t.Fatal("preferences lost unrelated data")
	}
	var other models.User
	if err := db.First(&other, "id = ?", "other").Error; err != nil {
		t.Fatal(err)
	}
	if other.WardrobeDisplayPreferences != "{}" {
		t.Fatal("cross-user modification")
	}
	if err := db.Callback().Update().Before("gorm:update").Register("test:display_failure", func(tx *gorm.DB) { tx.AddError(fmt.Errorf("write failed")) }); err != nil {
		t.Fatal(err)
	}
	call("PATCH", path, "owner", `{"categories":[],"seasons":[]}`, 500)
	if err := db.Callback().Update().Remove("test:display_failure"); err != nil {
		t.Fatal(err)
	}
	var persisted models.User
	if err := db.First(&persisted, "id = ?", "owner").Error; err != nil {
		t.Fatal(err)
	}
	if persisted.WardrobeDisplayPreferences != response.Data.WardrobeDisplayPreferences {
		t.Fatal("failed write changed preferences")
	}
	call("PATCH", path, "owner", `{"categories":[],"seasons":[]}`, 200)
	if err := db.First(&persisted, "id = ?", "owner").Error; err != nil {
		t.Fatal(err)
	}
	if persisted.WardrobeDisplayPreferences != `{"categories":[],"seasons":[]}` {
		t.Fatal("cannot restore all")
	}
}

func TestWardrobeDisplayMigrationPreservesExistingUser(t *testing.T) {
	db, err := database.Open(":memory:")
	if err != nil {
		t.Fatal(err)
	}
	sqlDB, _ := db.DB()
	defer sqlDB.Close()
	if err := db.Exec("CREATE TABLE users (id text PRIMARY KEY, email text, height real)").Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Exec("INSERT INTO users (id,email,height) VALUES (?,?,?)", "existing", "existing@example.com", 172).Error; err != nil {
		t.Fatal(err)
	}
	if err := database.AutoMigrate(db); err != nil {
		t.Fatal(err)
	}
	var user models.User
	if err := db.First(&user, "id = ?", "existing").Error; err != nil {
		t.Fatal(err)
	}
	if user.WardrobeDisplayPreferences != "{}" || user.Height != 172 {
		t.Fatal("migration lost old data or default preferences")
	}
}
