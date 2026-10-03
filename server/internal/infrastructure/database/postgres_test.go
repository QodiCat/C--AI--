package database

import (
	"ai-closet-server/internal/models"
	"fmt"
	"net/url"
	"os"
	"strings"
	"testing"
	"time"
)

func TestPostgresMigrationsAndPersistence(t *testing.T) {
	dsn := os.Getenv("TEST_POSTGRES_DSN")
	if dsn == "" {
		t.Skip("TEST_POSTGRES_DSN not configured")
	}
	base, err := OpenPostgres(dsn)
	if err != nil {
		t.Fatal(err)
	}
	baseSQL, _ := base.DB()
	defer baseSQL.Close()
	schema := fmt.Sprintf("closet_test_%d", time.Now().UnixNano())
	if base.Exec("CREATE SCHEMA "+schema).Error != nil {
		t.Fatal("cannot create isolated test schema")
	}
	defer base.Exec("DROP SCHEMA " + schema + " CASCADE")
	isolatedDSN := dsn + " search_path=" + schema
	if strings.HasPrefix(dsn, "postgres://") || strings.HasPrefix(dsn, "postgresql://") {
		u, _ := url.Parse(dsn)
		q := u.Query()
		q.Set("search_path", schema)
		u.RawQuery = q.Encode()
		isolatedDSN = u.String()
	}
	db, err := OpenPostgres(isolatedDSN)
	if err != nil {
		t.Fatal(err)
	}
	sqlDB, _ := db.DB()
	defer sqlDB.Close()
	if err := AutoMigrate(db); err != nil {
		t.Fatal(err)
	}
	if err := AutoMigrate(db); err != nil {
		t.Fatalf("second migration failed: %v", err)
	}
	var count int64
	db.Model(&models.User{}).Count(&count)
	if count != 0 {
		t.Fatal("unexpected demo users")
	}
	now := time.Now()
	user := models.User{ID: "test-user", Email: "integration@example.org", Nickname: "真实数据测试", CreatedAt: now, UpdatedAt: now}
	item := models.Item{ID: "test-item", UserID: user.ID, Name: "运动鞋", CategoryLevel1: "鞋履", CategoryLevel2: "运动鞋", PrimaryColor: "白色", Seasons: `["春","秋"]`, OriginalImageURL: "oss://bucket/originals/shoe.jpg", CutoutImageURL: "oss://bucket/cutouts/shoe.png", CreatedAt: now, UpdatedAt: now}
	if db.Create(&user).Error != nil || db.Create(&item).Error != nil {
		t.Fatal("failed to create records")
	}
	sqlDB.Close()
	reopened, err := OpenPostgres(isolatedDSN)
	if err != nil {
		t.Fatal(err)
	}
	reopenedSQL, _ := reopened.DB()
	defer reopenedSQL.Close()
	var restored models.Item
	if reopened.First(&restored, "id = ?", item.ID).Error != nil || restored.CutoutImageURL != item.CutoutImageURL || restored.Seasons != item.Seasons {
		t.Fatalf("data not persisted: %+v", restored)
	}
}
