package imageprocess

import (
	"ai-closet-server/internal/httpapi"
	"ai-closet-server/internal/models"
	"encoding/json"
	"fmt"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
	"net/http"
	"time"
)

type request struct {
	ImageURLs []string `json:"imageUrls" binding:"required,min=1,max=9"`
}

func RegisterRoutes(router *gin.Engine, db *gorm.DB) {
	router.POST("/ai/item-recognition/tasks", func(c *gin.Context) {
		var req request
		if c.ShouldBindJSON(&req) != nil {
			httpapi.Error(c, http.StatusBadRequest, "INVALID_REQUEST", "请选择1至9张图片")
			return
		}
		raw, _ := json.Marshal(req)
		now := time.Now()
		candidates := make([]map[string]any, 0, len(req.ImageURLs))
		for i, url := range req.ImageURLs {
			candidates = append(candidates, map[string]any{"candidateId": fmt.Sprintf("candidate_%d", i+1), "originalImageUrl": url, "cutoutImageUrl": url, "name": fmt.Sprintf("待确认单品 %d", i+1), "categoryLevel1": "上装", "categoryLevel2": "其他上装", "primaryColor": "待确认", "seasons": []string{}, "styles": []string{}, "scenes": []string{}})
		}
		result, _ := json.Marshal(candidates)
		task := models.AITask{ID: fmt.Sprintf("task_%d", now.UnixNano()), UserID: "user_demo", TaskType: "item_recognition", Status: "success", RequestPayload: string(raw), ResultPayload: string(result), CreatedAt: now, UpdatedAt: now}
		if db.Create(&task).Error != nil {
			httpapi.Error(c, 500, "TASK_CREATE_FAILED", "创建识别任务失败")
			return
		}
		httpapi.OK(c, task)
	})
	router.GET("/ai/tasks/:taskId", func(c *gin.Context) {
		var task models.AITask
		if db.First(&task, "id = ?", c.Param("taskId")).Error != nil {
			httpapi.Error(c, 404, "TASK_NOT_FOUND", "未找到任务")
			return
		}
		var result any = []any{}
		_ = json.Unmarshal([]byte(task.ResultPayload), &result)
		httpapi.OK(c, gin.H{"id": task.ID, "taskType": task.TaskType, "status": task.Status, "result": result, "errorMessage": task.ErrorMessage})
	})
}
