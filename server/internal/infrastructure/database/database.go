package database

import (
	"encoding/json"
	"fmt"
	"time"

	"github.com/glebarez/sqlite"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"

	"ai-closet-server/internal/models"
)

func OpenPostgres(dsn string) (*gorm.DB, error) {
	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		return nil, fmt.Errorf("open PostgreSQL: %w", err)
	}
	sqlDB, err := db.DB()
	if err != nil {
		return nil, err
	}
	sqlDB.SetMaxOpenConns(20)
	sqlDB.SetMaxIdleConns(5)
	sqlDB.SetConnMaxLifetime(30 * time.Minute)
	return db, nil
}

func Open(path string) (*gorm.DB, error) {
	db, err := gorm.Open(sqlite.Open(path), &gorm.Config{})
	if err != nil {
		return nil, fmt.Errorf("open sqlite: %w", err)
	}

	return db, nil
}

func AutoMigrate(db *gorm.DB) error {
	return db.AutoMigrate(
		&models.User{},
		&models.Item{},
		&models.Outfit{},
		&models.WearLog{},
		&models.AITask{},
		&models.Session{},
	)
}

func SeedDemoData(db *gorm.DB) error {
	var count int64
	if err := db.Model(&models.User{}).Count(&count).Error; err != nil {
		return err
	}
	if count > 0 {
		return ensureDemoCredentials(db)
	}

	now := time.Now()
	demoHash, _ := bcrypt.GenerateFromPassword([]byte("demo12345"), bcrypt.DefaultCost)
	user := models.User{
		ID:                 "user_demo",
		Email:              "demo@example.com",
		PasswordHash:       string(demoHash),
		Nickname:           "Qodi",
		LoginType:          "phone",
		City:               "Shanghai",
		BodyType:           "regular",
		StylePreferences:   `["minimal","commute","quiet-luxury"]`,
		AllowModelTraining: false,
		CreatedAt:          now,
		UpdatedAt:          now,
	}

	items := []models.Item{
		{
			ID:               "item_white_shirt",
			UserID:           user.ID,
			Name:             "白色衬衫",
			CategoryLevel1:   "上装",
			CategoryLevel2:   "衬衫",
			PrimaryColor:     "白色",
			Seasons:          `["春","秋"]`,
			Styles:           `["通勤","极简"]`,
			Scenes:           `["上班","通勤"]`,
			OriginalImageURL: "https://example.com/originals/white-shirt.jpg",
			CutoutImageURL:   "https://example.com/cutouts/white-shirt.png",
			ManagementStatus: "normal",
			WearableStatus:   "wearable",
			CreatedAt:        now,
			UpdatedAt:        now,
		},
		{
			ID:               "item_black_pants",
			UserID:           user.ID,
			Name:             "黑色西裤",
			CategoryLevel1:   "下装",
			CategoryLevel2:   "西裤",
			PrimaryColor:     "黑色",
			Seasons:          `["春","秋","冬"]`,
			Styles:           `["通勤","正式"]`,
			Scenes:           `["上班","正式活动"]`,
			OriginalImageURL: "https://example.com/originals/black-pants.jpg",
			CutoutImageURL:   "https://example.com/cutouts/black-pants.png",
			ManagementStatus: "normal",
			WearableStatus:   "wearable",
			CreatedAt:        now,
			UpdatedAt:        now,
		},
		{
			ID:               "item_loafers",
			UserID:           user.ID,
			Name:             "乐福鞋",
			CategoryLevel1:   "鞋履",
			CategoryLevel2:   "皮鞋",
			PrimaryColor:     "黑色",
			Seasons:          `["春","秋"]`,
			Styles:           `["通勤"]`,
			Scenes:           `["上班","出行"]`,
			OriginalImageURL: "https://example.com/originals/loafers.jpg",
			CutoutImageURL:   "https://example.com/cutouts/loafers.png",
			ManagementStatus: "normal",
			WearableStatus:   "wearable",
			CreatedAt:        now,
			UpdatedAt:        now,
		},
	}

	if err := db.Create(&user).Error; err != nil {
		return err
	}

	if err := db.Create(&items).Error; err != nil {
		return err
	}

	taskPayload, _ := json.Marshal(map[string]any{"seed": true})
	return db.Create(&models.AITask{
		ID:             "task_seed",
		UserID:         user.ID,
		TaskType:       "seed",
		Status:         "success",
		RequestPayload: string(taskPayload),
		ResultPayload:  string(taskPayload),
		CreatedAt:      now,
		UpdatedAt:      now,
	}).Error
}

func ensureDemoCredentials(db *gorm.DB) error {
	var user models.User
	if err := db.First(&user, "id = ?", "user_demo").Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil
		}
		return err
	}
	if user.Email != "" && user.PasswordHash != "" {
		return nil
	}
	hash, err := bcrypt.GenerateFromPassword([]byte("demo12345"), bcrypt.DefaultCost)
	if err != nil {
		return err
	}
	user.Email = "demo@example.com"
	user.PasswordHash = string(hash)
	return db.Save(&user).Error
}
