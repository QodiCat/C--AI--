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
	Note        string `json:"note"`
}

func RegisterRoutes(router *gin.Engine, db *gorm.DB) {
	router.GET("/wear-logs", func(c *gin.Context) {
		var logs []models.WearLog
		if err := db.Order("created_at desc").Find(&logs).Error; err != nil {
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
			Note:        req.Note,
			CreatedAt:   time.Now(),
		}

		if err := db.Create(&log).Error; err != nil {
			httpapi.Error(c, http.StatusInternalServerError, "WEAR_LOG_CREATE_FAILED", "创建穿搭记录失败")
			return
		}

		httpapi.OK(c, log)
	})
}
