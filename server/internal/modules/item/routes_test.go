package item

import (
	"bytes"
	"encoding/json"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"ai-closet-server/internal/infrastructure/database"
	"ai-closet-server/internal/models"
	"ai-closet-server/internal/modules/auth"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func TestEditItemAttributesAndNotes(t *testing.T) {
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
		if err := db.Create(&models.Session{ID: id, UserID: id, Token: id, ExpiresAt: time.Now().Add(time.Hour)}).Error; err != nil {
			t.Fatal(err)
		}
	}
	router := gin.New()
	router.Use(auth.RequireAuth(db))
	RegisterRoutes(router, db)
	call := func(method, path, token string, body any, want int) []byte {
		t.Helper()
		raw, _ := json.Marshal(body)
		req := httptest.NewRequest(method, path, bytes.NewReader(raw))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+token)
		out := httptest.NewRecorder()
		router.ServeHTTP(out, req)
		if out.Code != want {
			t.Fatalf("status=%d want=%d: %s", out.Code, want, out.Body.String())
		}
		return out.Body.Bytes()
	}
	body := map[string]any{"name": "衬衫", "categoryLevel1": "上装", "categoryLevel2": "衬衫", "primaryColor": "白", "originalImageUrl": "oss://original", "cutoutImageUrl": "oss://cutout", "managementStatus": "normal", "wearableStatus": "washing", "notes": "轻柔手洗\n勿烘干", "measurements": map[string]float64{"chest": 104.5, "length": 70}}
	var result struct {
		Data models.Item `json:"data"`
	}
	if err := json.Unmarshal(call("POST", "/items", "owner", body, 200), &result); err != nil {
		t.Fatal(err)
	}
	if result.Data.Measurements["chest"] != 104.5 {
		t.Fatal("create lost measurements")
	}
	id := result.Data.ID
	if result.Data.Notes != body["notes"] {
		t.Fatal("create lost notes")
	}
	body["measurements"] = map[string]float64{"chest": 106}
	body["name"] = "通勤衬衫"
	body["brand"] = "品牌"
	body["seasons"] = []string{"春", "秋"}
	body["customTags"] = []string{"常穿"}
	body["notes"] = strings.Repeat("衣", 2000)
	call("PATCH", "/items/"+id, "other", body, 404)
	call("GET", "/items/"+id, "other", nil, 404)
	call("PATCH", "/items/"+id, "owner", body, 200)
	var row models.Item
	read := func() {
		t.Helper()
		if err := db.First(&row, "id = ?", id).Error; err != nil {
			t.Fatal(err)
		}
	}
	read()
	if row.Name != "通勤衬衫" || row.Brand != "品牌" || row.Seasons != `["春","秋"]` || row.CustomTags != `["常穿"]` || len([]rune(row.Notes)) != 2000 || row.UserID != "owner" || row.OriginalImageURL != "oss://original" || row.CutoutImageURL != "oss://cutout" || row.WearableStatus != "washing" {
		t.Fatalf("edit lost attributes: %+v", row)
	}
	if row.Measurements["chest"] != 106 || len(row.Measurements) != 1 {
		t.Fatal("measurement replacement failed")
	}
	delete(body, "measurements")
	// Older clients omit notes; their edits must retain the existing text.
	delete(body, "notes")
	call("PATCH", "/items/"+id, "owner", body, 200)
	read()
	if len([]rune(row.Notes)) != 2000 {
		t.Fatal("omitted notes erased")
	}

	if row.Measurements["chest"] != 106 {
		t.Fatal("omitted measurements erased")
	}
	body["measurements"] = nil
	call("PATCH", "/items/"+id, "owner", body, 200)
	read()
	if row.Measurements["chest"] != 106 {
		t.Fatal("null measurements erased")
	}
	for _, bad := range []any{map[string]any{"chest": -1}, map[string]any{"chest": 0}, map[string]any{"chest": 501}, map[string]any{"unknown": 20}, map[string]any{"chest": nil}, map[string]any{"chest": "100"}, []int{1}} {
		body["measurements"] = bad
		call("PATCH", "/items/"+id, "owner", body, 400)
		call("POST", "/items", "owner", body, 400)
	}
	body["measurements"] = map[string]float64{}
	call("PATCH", "/items/"+id, "owner", body, 200)
	read()
	if len(row.Measurements) != 0 {
		t.Fatal("cannot clear measurements")
	}
	body["notes"] = strings.Repeat("衣", 2001)
	call("PATCH", "/items/"+id, "owner", body, 400)
	call("POST", "/items", "owner", body, 400)
	body["notes"] = ""
	call("PATCH", "/items/"+id, "owner", body, 200)
	read()
	if row.Notes != "" {
		t.Fatal("cannot clear notes")
	}
	body["notes"] = "should not persist"
	body["measurements"] = map[string]float64{"chest": 99}
	if err := db.Callback().Update().Before("gorm:update").Register("test:fail_update", func(tx *gorm.DB) { tx.AddError(gorm.ErrInvalidTransaction) }); err != nil {
		t.Fatal(err)
	}
	call("PATCH", "/items/"+id, "owner", body, 500)
	read()
	if row.Notes != "" || len(row.Measurements) != 0 {
		t.Fatal("failed edit changed notes or measurements")
	}
	var listed struct {
		Data []models.Item `json:"data"`
	}
	if err := json.Unmarshal(call("GET", "/items", "owner", nil, 200), &listed); err != nil {
		t.Fatal(err)
	}
	if len(listed.Data) != 1 || listed.Data[0].Notes != "" {
		t.Fatal("list did not return notes")
	}
}

func TestMigrateExistingItemNotes(t *testing.T) {
	db, err := database.Open(":memory:")
	if err != nil {
		t.Fatal(err)
	}
	sqlDB, _ := db.DB()
	defer sqlDB.Close()
	if err := db.Exec("CREATE TABLE items (id text PRIMARY KEY, user_id text, name text)").Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Exec("INSERT INTO items (id,user_id,name) VALUES ('old','owner','旧衣物')").Error; err != nil {
		t.Fatal(err)
	}
	if err := database.AutoMigrate(db); err != nil {
		t.Fatal(err)
	}
	var row models.Item
	if err := db.First(&row, "id = ?", "old").Error; err != nil {
		t.Fatal(err)
	}
	if row.Name != "旧衣物" || row.Notes != "" || row.Measurements == nil || len(row.Measurements) != 0 {
		t.Fatalf("migration lost old data: %+v", row)
	}
}
