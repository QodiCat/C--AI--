package outfit

import (
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"ai-closet-server/internal/httpapi"
	"ai-closet-server/internal/models"
	"ai-closet-server/internal/modules/auth"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type writeRequest struct {
	Name     string   `json:"name" binding:"max=100"`
	Category string   `json:"category" binding:"max=50"`
	ItemIDs  []string `json:"itemIds" binding:"required,min=1"`
	Scene    string   `json:"scene"`
	Style    string   `json:"style"`
	Season   string   `json:"season"`
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
		q := db.Where("user_id = ?", auth.CurrentUserID(c)).Order("created_at desc")
		if values, exists := c.GetQueryArray("category"); exists && len(values) > 0 {
			q = q.Where("COALESCE(category, '') = ?", values[0])
		}
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
		if db.First(&row, "id = ? AND user_id = ?", c.Param("outfitId"), auth.CurrentUserID(c)).Error != nil {
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
		userID := auth.CurrentUserID(c)
		valid, err := itemsExist(db, userID, req.ItemIDs)
		if err != nil {
			httpapi.Error(c, 500, "DB_QUERY_FAILED", "查询衣物失败")
			return
		}
		if !valid {
			httpapi.Error(c, 400, "INVALID_ITEMS", "搭配包含不存在的单品")
			return
		}
		data, _ := json.Marshal(req.ItemIDs)
		now := time.Now()
		row := models.Outfit{ID: fmt.Sprintf("outfit_%d", now.UnixNano()), UserID: userID, Name: strings.TrimSpace(req.Name), Category: strings.TrimSpace(req.Category), ItemIDs: string(data), Scene: req.Scene, Style: req.Style, Season: req.Season, Source: "manual", CreatedAt: now, UpdatedAt: now}
		if db.Create(&row).Error != nil {
			httpapi.Error(c, 500, "OUTFIT_CREATE_FAILED", "创建搭配失败")
			return
		}
		httpapi.OK(c, row)
	})
	router.PATCH("/outfits/:outfitId", func(c *gin.Context) {
		var req writeRequest
		if c.ShouldBindJSON(&req) != nil || strings.TrimSpace(req.Name) == "" {
			httpapi.Error(c, 400, "INVALID_REQUEST", "请填写搭配名称并选择衣物")
			return
		}
		userID := auth.CurrentUserID(c)
		var row models.Outfit
		if err := db.First(&row, "id = ? AND user_id = ?", c.Param("outfitId"), userID).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				httpapi.Error(c, 404, "OUTFIT_NOT_FOUND", "未找到搭配")
			} else {
				httpapi.Error(c, 500, "DB_QUERY_FAILED", "查询搭配失败")
			}
			return
		}
		valid, err := itemsExist(db, userID, req.ItemIDs)
		if err != nil {
			httpapi.Error(c, 500, "DB_QUERY_FAILED", "查询衣物失败")
			return
		}
		if !valid {
			httpapi.Error(c, 400, "INVALID_ITEMS", "搭配包含不存在或重复的单品")
			return
		}
		ids, _ := json.Marshal(req.ItemIDs)
		updates := map[string]any{"name": strings.TrimSpace(req.Name), "category": strings.TrimSpace(req.Category), "item_ids": string(ids), "scene": strings.TrimSpace(req.Scene), "style": strings.TrimSpace(req.Style), "season": strings.TrimSpace(req.Season), "updated_at": time.Now()}
		result := db.Model(&row).Where("user_id = ?", userID).Updates(updates)
		if result.Error != nil {
			httpapi.Error(c, 500, "OUTFIT_UPDATE_FAILED", "修改搭配失败")
			return
		}
		if result.RowsAffected != 1 {
			httpapi.Error(c, 404, "OUTFIT_NOT_FOUND", "未找到搭配")
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
		if db.First(&row, "id = ? AND user_id = ?", c.Param("outfitId"), auth.CurrentUserID(c)).Error != nil {
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
		result := db.Delete(&models.Outfit{}, "id = ? AND user_id = ?", c.Param("outfitId"), auth.CurrentUserID(c))
		if result.Error != nil {
			httpapi.Error(c, 500, "OUTFIT_DELETE_FAILED", "删除搭配失败")
			return
		}
		if result.RowsAffected == 0 {
			httpapi.Error(c, 404, "OUTFIT_NOT_FOUND", "未找到搭配")
			return
		}
		httpapi.OK(c, gin.H{"deleted": true})
	})
	router.GET("/outfits/:outfitId/items", func(c *gin.Context) {
		var row models.Outfit
		userID := auth.CurrentUserID(c)
		if db.First(&row, "id = ? AND user_id = ?", c.Param("outfitId"), userID).Error != nil {
			httpapi.Error(c, 404, "OUTFIT_NOT_FOUND", "未找到搭配")
			return
		}
		var ids []string
		_ = json.Unmarshal([]byte(row.ItemIDs), &ids)
		var items []models.Item
		db.Where("id IN ? AND user_id = ?", ids, userID).Find(&items)
		httpapi.OK(c, items)
	})
}

func itemsExist(db *gorm.DB, userID string, ids []string) (bool, error) {
	var count int64
	err := db.Model(&models.Item{}).Where("id IN ? AND user_id = ?", ids, userID).Count(&count).Error
	return count == int64(len(ids)), err
}
