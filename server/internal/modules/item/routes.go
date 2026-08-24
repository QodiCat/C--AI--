package item

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"ai-closet-server/internal/httpapi"
	"ai-closet-server/internal/models"
)

type createItemRequest struct {
	Name             string   `json:"name" binding:"required"`
	CategoryLevel1   string   `json:"categoryLevel1" binding:"required"`
	CategoryLevel2   string   `json:"categoryLevel2" binding:"required"`
	PrimaryColor     string   `json:"primaryColor" binding:"required"`
	Seasons          []string `json:"seasons"`
	Styles           []string `json:"styles"`
	Scenes           []string `json:"scenes"`
	OriginalImageURL string   `json:"originalImageUrl" binding:"required"`
	CutoutImageURL   string   `json:"cutoutImageUrl"`
	ManagementStatus string   `json:"managementStatus" binding:"required"`
	WearableStatus   string   `json:"wearableStatus" binding:"required"`
}

type updateStatusRequest struct {
	ManagementStatus string `json:"managementStatus" binding:"required"`
	WearableStatus   string `json:"wearableStatus" binding:"required"`
}

func RegisterRoutes(router *gin.Engine, db *gorm.DB) {
	router.GET("/items", func(c *gin.Context) {
		var items []models.Item
		if err := db.Order("created_at desc").Find(&items).Error; err != nil {
			httpapi.Error(c, http.StatusInternalServerError, "DB_QUERY_FAILED", "查询单品失败")
			return
		}

		httpapi.OK(c, items)
	})

	router.GET("/items/:itemId", func(c *gin.Context) {
		var item models.Item
		if err := db.First(&item, "id = ?", c.Param("itemId")).Error; err != nil {
			httpapi.Error(c, http.StatusNotFound, "ITEM_NOT_FOUND", "未找到对应单品")
			return
		}

		httpapi.OK(c, item)
	})

	router.POST("/items", func(c *gin.Context) {
		var req createItemRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			httpapi.Error(c, http.StatusBadRequest, "INVALID_REQUEST", "请求参数不合法")
			return
		}

		now := time.Now()
		item := models.Item{
			ID:               newID("item"),
			UserID:           "user_demo",
			Name:             req.Name,
			CategoryLevel1:   req.CategoryLevel1,
			CategoryLevel2:   req.CategoryLevel2,
			PrimaryColor:     req.PrimaryColor,
			Seasons:          toJSON(req.Seasons),
			Styles:           toJSON(req.Styles),
			Scenes:           toJSON(req.Scenes),
			OriginalImageURL: req.OriginalImageURL,
			CutoutImageURL:   req.CutoutImageURL,
			ManagementStatus: req.ManagementStatus,
			WearableStatus:   req.WearableStatus,
			CreatedAt:        now,
			UpdatedAt:        now,
		}

		if err := db.Create(&item).Error; err != nil {
			httpapi.Error(c, http.StatusInternalServerError, "ITEM_CREATE_FAILED", "创建单品失败")
			return
		}

		httpapi.OK(c, item)
	})

	router.PATCH("/items/:itemId/status", func(c *gin.Context) {
		var req updateStatusRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			httpapi.Error(c, http.StatusBadRequest, "INVALID_REQUEST", "请求参数不合法")
			return
		}

		var item models.Item
		if err := db.First(&item, "id = ?", c.Param("itemId")).Error; err != nil {
			httpapi.Error(c, http.StatusNotFound, "ITEM_NOT_FOUND", "未找到对应单品")
			return
		}

		item.ManagementStatus = req.ManagementStatus
		item.WearableStatus = req.WearableStatus
		item.UpdatedAt = time.Now()

		if err := db.Save(&item).Error; err != nil {
			httpapi.Error(c, http.StatusInternalServerError, "ITEM_UPDATE_FAILED", "更新单品状态失败")
			return
		}

		httpapi.OK(c, item)
	})
}
