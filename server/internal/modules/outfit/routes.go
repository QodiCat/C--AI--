package outfit

import (
	"encoding/json"
	"fmt"
	"time"

	"ai-closet-server/internal/httpapi"
	"ai-closet-server/internal/models"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type writeRequest struct {
	Name    string   `json:"name"`
	ItemIDs []string `json:"itemIds" binding:"required,min=1"`
	Scene   string   `json:"scene"`
	Style   string   `json:"style"`
	Season  string   `json:"season"`
}
type ratingRequest struct {
	Rating      int    `json:"rating" binding:"min=1,max=5"`
	Feedback    string `json:"feedback"`
	Comfort     int    `json:"comfort" binding:"min=0,max=5"`
	Compliments int    `json:"compliments" binding:"min=0"`
}

func RegisterRoutes(router *gin.Engine, db *gorm.DB) {
	router.GET("/outfits", func(c *gin.Context) {
		var rows []models.Outfit
		q := db.Order("created_at desc")
		if c.Query("source") != "" {
			q = q.Where("source = ?", c.Query("source"))
		}
		if q.Find(&rows).Error != nil {
			httpapi.Error(c, 500, "DB_QUERY_FAILED", "查询搭配失败")
			return
		}
		httpapi.OK(c, rows)
	})
	router.GET("/outfits/:outfitId", func(c *gin.Context) {
		var row models.Outfit
		if db.First(&row, "id = ?", c.Param("outfitId")).Error != nil {
			httpapi.Error(c, 404, "OUTFIT_NOT_FOUND", "未找到搭配")
			return
		}
		httpapi.OK(c, row)
	})
	router.POST("/outfits", func(c *gin.Context) {
		var req writeRequest
		if c.ShouldBindJSON(&req) != nil {
			httpapi.Error(c, 400, "INVALID_REQUEST", "至少选择一件单品")
			return
		}
		if !itemsExist(db, req.ItemIDs) {
			httpapi.Error(c, 400, "INVALID_ITEMS", "搭配包含不存在的单品")
			return
		}
		data, _ := json.Marshal(req.ItemIDs)
		now := time.Now()
		row := models.Outfit{ID: fmt.Sprintf("outfit_%d", now.UnixNano()), UserID: "user_demo", Name: req.Name, ItemIDs: string(data), Scene: req.Scene, Style: req.Style, Season: req.Season, Source: "manual", CreatedAt: now, UpdatedAt: now}
		if db.Create(&row).Error != nil {
			httpapi.Error(c, 500, "OUTFIT_CREATE_FAILED", "创建搭配失败")
			return
		}
		httpapi.OK(c, row)
	})
	router.PATCH("/outfits/:outfitId/rating", func(c *gin.Context) {
		var req ratingRequest
		if c.ShouldBindJSON(&req) != nil {
			httpapi.Error(c, 400, "INVALID_REQUEST", "评分参数不合法")
			return
		}
		var row models.Outfit
		if db.First(&row, "id = ?", c.Param("outfitId")).Error != nil {
			httpapi.Error(c, 404, "OUTFIT_NOT_FOUND", "未找到搭配")
			return
		}
		row.Rating = req.Rating
		row.Feedback = req.Feedback
		row.Comfort = req.Comfort
		row.Compliments = req.Compliments
		row.UpdatedAt = time.Now()
		db.Save(&row)
		httpapi.OK(c, row)
	})
	router.DELETE("/outfits/:outfitId", func(c *gin.Context) {
		result := db.Delete(&models.Outfit{}, "id = ?", c.Param("outfitId"))
		if result.RowsAffected == 0 {
			httpapi.Error(c, 404, "OUTFIT_NOT_FOUND", "未找到搭配")
			return
		}
		httpapi.OK(c, gin.H{"deleted": true})
	})
	router.GET("/outfits/:outfitId/items", func(c *gin.Context) {
		var row models.Outfit
		if db.First(&row, "id = ?", c.Param("outfitId")).Error != nil {
			httpapi.Error(c, 404, "OUTFIT_NOT_FOUND", "未找到搭配")
			return
		}
		var ids []string
		_ = json.Unmarshal([]byte(row.ItemIDs), &ids)
		var items []models.Item
		db.Where("id IN ?", ids).Find(&items)
		httpapi.OK(c, items)
	})
}

func itemsExist(db *gorm.DB, ids []string) bool {
	var count int64
	db.Model(&models.Item{}).Where("id IN ?", ids).Count(&count)
	return count == int64(len(ids))
}
