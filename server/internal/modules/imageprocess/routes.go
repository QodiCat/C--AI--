package imageprocess

import (
	"ai-closet-server/internal/config"
	"ai-closet-server/internal/httpapi"
	"ai-closet-server/internal/models"
	"ai-closet-server/internal/modules/auth"
	"context"
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

func RegisterRoutes(router *gin.Engine, db *gorm.DB, processor Processor, cfg config.Config) {
	db.Model(&models.AITask{}).Where("task_type = ? AND status = ?", "item_recognition", "processing").Updates(map[string]any{"status": "failed", "error_message": "服务重启，请重新提交识别", "updated_at": time.Now()})
	slots := make(chan struct{}, 2)
	router.POST("/ai/item-recognition/tasks", func(c *gin.Context) {
		var req request
		if c.ShouldBindJSON(&req) != nil {
			httpapi.Error(c, 400, "INVALID_REQUEST", "请选择1至9张图片")
			return
		}
		userID := auth.CurrentUserID(c)
		for _, uri := range req.ImageURLs {
			if _, err := objectKey(cfg, userID, uri); err != nil {
				httpapi.Error(c, 400, "INVALID_IMAGE", err.Error())
				return
			}
		}
		if err := processor.Ready(); err != nil {
			httpapi.Error(c, http.StatusServiceUnavailable, "IMAGE_SERVICE_NOT_CONFIGURED", err.Error())
			return
		}
		select {
		case slots <- struct{}{}:
		default:
			httpapi.Error(c, 429, "IMAGE_SERVICE_BUSY", "识别任务繁忙，请稍后重试")
			return
		}
		raw, _ := json.Marshal(req)
		now := time.Now()
		task := models.AITask{ID: fmt.Sprintf("task_%d", now.UnixNano()), UserID: userID, TaskType: "item_recognition", Status: "processing", RequestPayload: string(raw), ResultPayload: "[]", CreatedAt: now, UpdatedAt: now}
		if db.Create(&task).Error != nil {
			<-slots
			httpapi.Error(c, 500, "TASK_CREATE_FAILED", "创建识别任务失败")
			return
		}
		go func() {
			defer func() {
				<-slots
				if recover() != nil {
					db.Model(&models.AITask{}).Where("id = ?", task.ID).Updates(map[string]any{"status": "failed", "error_message": "图像处理异常，请重试", "updated_at": time.Now()})
				}
			}()
			ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
			defer cancel()
			candidates := make([]Candidate, 0, len(req.ImageURLs))
			for _, uri := range req.ImageURLs {
				result, err := processor.Process(ctx, userID, task.ID, uri)
				if err != nil {
					db.Model(&models.AITask{}).Where("id = ?", task.ID).Updates(map[string]any{"status": "failed", "error_message": err.Error(), "updated_at": time.Now()})
					return
				}
				candidates = append(candidates, result)
			}
			payload, _ := json.Marshal(candidates)
			db.Model(&models.AITask{}).Where("id = ?", task.ID).Updates(map[string]any{"status": "success", "result_payload": string(payload), "updated_at": time.Now()})
		}()
		httpapi.OK(c, gin.H{"id": task.ID, "status": task.Status})
	})
	router.GET("/ai/tasks/:taskId", func(c *gin.Context) {
		var task models.AITask
		if db.First(&task, "id = ? AND user_id = ?", c.Param("taskId"), auth.CurrentUserID(c)).Error != nil {
			httpapi.Error(c, 404, "TASK_NOT_FOUND", "未找到任务")
			return
		}
		var result any = []any{}
		_ = json.Unmarshal([]byte(task.ResultPayload), &result)
		httpapi.OK(c, gin.H{"id": task.ID, "taskType": task.TaskType, "status": task.Status, "result": result, "errorMessage": task.ErrorMessage})
	})
}
