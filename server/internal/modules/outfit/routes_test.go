package outfit

import (
	"bytes"
	"encoding/json"
	"net/http/httptest"
	"testing"
	"time"

	"ai-closet-server/internal/infrastructure/database"
	"ai-closet-server/internal/models"
	"ai-closet-server/internal/modules/auth"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func TestOutfitEditingClassificationAndDeletion(t *testing.T) {
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
		if err := db.Create(&models.User{ID: id, Email: id + "@example.com"}).Error; err != nil {
			t.Fatal(err)
		}
		if err := db.Create(&models.Session{ID: id, UserID: id, Token: id, ExpiresAt: time.Now().Add(time.Hour)}).Error; err != nil {
			t.Fatal(err)
		}
	}
	for _, item := range []models.Item{{ID: "shirt", UserID: "owner"}, {ID: "pants", UserID: "owner"}, {ID: "foreign", UserID: "other"}} {
		if err := db.Create(&item).Error; err != nil {
			t.Fatal(err)
		}
	}
	row := models.Outfit{ID: "look", UserID: "owner", Name: "old", ItemIDs: `["shirt"]`, Source: "ai", AIReason: "original reason", Rating: 4}
	if err := db.Create(&row).Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Create(&models.WearLog{ID: "log", UserID: "owner", OutfitID: "look"}).Error; err != nil {
		t.Fatal(err)
	}
	router := gin.New()
	router.Use(auth.RequireAuth(db))
	RegisterRoutes(router, db)
	call := func(method, path, token string, body any) *httptest.ResponseRecorder {
		raw, _ := json.Marshal(body)
		req := httptest.NewRequest(method, path, bytes.NewReader(raw))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+token)
		out := httptest.NewRecorder()
		router.ServeHTTP(out, req)
		return out
	}
	check := func(out *httptest.ResponseRecorder, want int) {
		t.Helper()
		if out.Code != want {
			t.Fatalf("status=%d want=%d body=%s", out.Code, want, out.Body.String())
		}
	}
	body := map[string]any{"name": "new", "category": " 通勤 ", "itemIds": []string{"shirt", "pants"}, "scene": "office", "style": "simple", "season": "秋"}
	check(call("PATCH", "/outfits/look", "other", body), 404)
	check(call("DELETE", "/outfits/look", "other", nil), 404)
	body["itemIds"] = []string{"foreign"}
	check(call("PATCH", "/outfits/look", "owner", body), 400)
	body["itemIds"] = []string{"shirt", "shirt"}
	check(call("PATCH", "/outfits/look", "owner", body), 400)
	body["itemIds"] = []string{"shirt", "pants"}
	check(call("PATCH", "/outfits/look", "owner", body), 200)
	if err := db.First(&row, "id = ?", "look").Error; err != nil {
		t.Fatal(err)
	}
	if row.Category != "通勤" || row.Name != "new" || row.Source != "ai" || row.Rating != 4 || row.AIReason != "original reason" {
		t.Fatalf("edit lost metadata: %+v", row)
	}
	listed := call("GET", "/outfits?category=%E9%80%9A%E5%8B%A4", "owner", nil)
	check(listed, 200)
	var result struct {
		Data []models.Outfit `json:"data"`
	}
	if err := json.Unmarshal(listed.Body.Bytes(), &result); err != nil {
		t.Fatal(err)
	}
	if len(result.Data) != 1 {
		t.Fatal("classification filter failed")
	}
	listed = call("GET", "/outfits?category=missing", "owner", nil)
	json.Unmarshal(listed.Body.Bytes(), &result)
	if len(result.Data) != 0 {
		t.Fatal("filter returned unrelated category")
	}
	// Database failure must not be reported as successful deletion.
	if err := db.Callback().Delete().Before("gorm:delete").Register("test:delete_failure", func(tx *gorm.DB) { tx.AddError(gorm.ErrInvalidTransaction) }); err != nil {
		t.Fatal(err)
	}
	check(call("DELETE", "/outfits/look", "owner", nil), 500)
	db.Callback().Delete().Remove("test:delete_failure")
	check(call("DELETE", "/outfits/look", "owner", nil), 200)
	check(call("GET", "/outfits/look", "owner", nil), 404)
	var count int64
	db.Model(&models.WearLog{}).Where("id = ?", "log").Count(&count)
	if count != 1 {
		t.Fatal("deleting outfit removed history")
	}
	db.Model(&models.Item{}).Where("user_id = ?", "owner").Count(&count)
	if count != 2 {
		t.Fatal("deleting outfit removed garments")
	}
	check(call("POST", "/outfits", "owner", map[string]any{"name": "manual", "category": "周末", "itemIds": []string{"shirt", "pants"}}), 200)
}
