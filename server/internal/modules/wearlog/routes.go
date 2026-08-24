package wearlog

import (
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"ai-closet-server/internal/httpapi"
	"ai-closet-server/internal/models"
)

type createWearLogRequest struct {
	OutfitID    string `json:"outfitId" binding:"required"`
	WearDate    string `json:"wearDate" binding:"required"`
	Weather     string `json:"weather" binding:"required"`
	Temperature string `json:"temperature" binding:"required"`
	Scene       string `json:"scene" binding:"required"`
	PhotoURL    string `json:"photoUrl"`
	Mood        string `json:"mood"`
	Rating      int    `json:"rating" binding:"min=0,max=5"`
	Note        string `json:"note"`
}

func RegisterRoutes(router *gin.Engine, db *gorm.DB) {
	router.GET("/wear-logs", func(c *gin.Context) {
		var logs []models.WearLog
		query := db.Order("wear_date desc, created_at desc")
		if c.Query("date") != "" {
			query = query.Where("wear_date = ?", c.Query("date"))
		}
		if c.Query("month") != "" {
			query = query.Where("wear_date LIKE ?", c.Query("month")+"%")
		}
		if err := query.Find(&logs).Error; err != nil {
			httpapi.Error(c, http.StatusInternalServerError, "DB_QUERY_FAILED", "查询穿搭记录失败")
			return
		}

		httpapi.OK(c, logs)
	})

	router.POST("/wear-logs", func(c *gin.Context) {
		var req createWearLogRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			httpapi.Error(c, http.StatusBadRequest, "INVALID_REQUEST", "请求参数不合法")
			return
		}

		log := models.WearLog{
			ID:          fmt.Sprintf("wearlog_%d", time.Now().UnixNano()),
			UserID:      "user_demo",
			OutfitID:    req.OutfitID,
			WearDate:    req.WearDate,
			Weather:     req.Weather,
			Temperature: req.Temperature,
			Scene:       req.Scene,
			PhotoURL:    req.PhotoURL, Mood: req.Mood, Rating: req.Rating,
			Note:      req.Note,
			CreatedAt: time.Now(),
		}

		if err := db.Create(&log).Error; err != nil {
			httpapi.Error(c, http.StatusInternalServerError, "WEAR_LOG_CREATE_FAILED", "创建穿搭记录失败")
			return
		}

		httpapi.OK(c, log)
	})

	router.PATCH("/wear-logs/:logId", func(c *gin.Context) {
		var req createWearLogRequest
		if c.ShouldBindJSON(&req) != nil {
			httpapi.Error(c, 400, "INVALID_REQUEST", "请求参数不合法")
			return
		}
		var row models.WearLog
		if db.First(&row, "id = ?", c.Param("logId")).Error != nil {
			httpapi.Error(c, 404, "WEAR_LOG_NOT_FOUND", "未找到穿搭记录")
			return
		}
		row.OutfitID = req.OutfitID
		row.WearDate = req.WearDate
		row.Weather = req.Weather
		row.Temperature = req.Temperature
		row.Scene = req.Scene
		row.PhotoURL = req.PhotoURL
		row.Mood = req.Mood
		row.Rating = req.Rating
		row.Note = req.Note
		db.Save(&row)
		httpapi.OK(c, row)
	})
	router.DELETE("/wear-logs/:logId", func(c *gin.Context) {
		result := db.Delete(&models.WearLog{}, "id = ?", c.Param("logId"))
		if result.RowsAffected == 0 {
			httpapi.Error(c, 404, "WEAR_LOG_NOT_FOUND", "未找到穿搭记录")
			return
		}
		httpapi.OK(c, gin.H{"deleted": true})
	})
}
