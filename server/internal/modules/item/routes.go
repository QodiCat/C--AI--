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
	SecondaryColor   string   `json:"secondaryColor"`
	Pattern          string   `json:"pattern"`
	Brand            string   `json:"brand"`
	Size             string   `json:"size"`
	Seasons          []string `json:"seasons"`
	Styles           []string `json:"styles"`
	Scenes           []string `json:"scenes"`
	Material         string   `json:"material"`
	Fit              string   `json:"fit"`
	PurchasePrice    float64  `json:"purchasePrice"`
	PurchaseDate     string   `json:"purchaseDate"`
	CustomTags       []string `json:"customTags"`
	OriginalImageURL string   `json:"originalImageUrl" binding:"required"`
	CutoutImageURL   string   `json:"cutoutImageUrl"`
	ManagementStatus string   `json:"managementStatus" binding:"required"`
	WearableStatus   string   `json:"wearableStatus" binding:"required"`
}

type updateItemRequest struct {
	Name             string   `json:"name" binding:"required"`
	CategoryLevel1   string   `json:"categoryLevel1" binding:"required"`
	CategoryLevel2   string   `json:"categoryLevel2" binding:"required"`
	PrimaryColor     string   `json:"primaryColor"`
	SecondaryColor   string   `json:"secondaryColor"`
	Pattern          string   `json:"pattern"`
	Brand            string   `json:"brand"`
	Size             string   `json:"size"`
	Seasons          []string `json:"seasons"`
	Styles           []string `json:"styles"`
	Scenes           []string `json:"scenes"`
	Material         string   `json:"material"`
	Fit              string   `json:"fit"`
	PurchasePrice    float64  `json:"purchasePrice"`
	PurchaseDate     string   `json:"purchaseDate"`
	CustomTags       []string `json:"customTags"`
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
		query := db.Model(&models.Item{}).Where("management_status <> ?", "discarded")
		if value := c.Query("q"); value != "" {
			like := "%" + value + "%"
			query = query.Where("name LIKE ? OR brand LIKE ? OR custom_tags LIKE ?", like, like, like)
		}
		for key, column := range map[string]string{"category": "category_level1", "color": "primary_color", "material": "material", "managementStatus": "management_status", "wearableStatus": "wearable_status"} {
			if value := c.Query(key); value != "" {
				query = query.Where(column+" = ?", value)
			}
		}
		for key, column := range map[string]string{"season": "seasons", "style": "styles", "scene": "scenes"} {
			if value := c.Query(key); value != "" {
				query = query.Where(column+" LIKE ?", "%\""+value+"\"%")
			}
		}
		order := "created_at desc"
		if c.Query("sort") == "oldest" {
			order = "created_at asc"
		}
		if err := query.Order(order).Find(&items).Error; err != nil {
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
			ID:             newID("item"),
			UserID:         "user_demo",
			Name:           req.Name,
			CategoryLevel1: req.CategoryLevel1,
			CategoryLevel2: req.CategoryLevel2,
			PrimaryColor:   req.PrimaryColor,
			SecondaryColor: req.SecondaryColor, Pattern: req.Pattern, Brand: req.Brand, Size: req.Size,
			Seasons:  toJSON(req.Seasons),
			Styles:   toJSON(req.Styles),
			Scenes:   toJSON(req.Scenes),
			Material: req.Material, Fit: req.Fit, PurchasePrice: req.PurchasePrice, PurchaseDate: req.PurchaseDate, CustomTags: toJSON(req.CustomTags),
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

	router.PATCH("/items/:itemId", func(c *gin.Context) {
		var req updateItemRequest
		if c.ShouldBindJSON(&req) != nil {
			httpapi.Error(c, 400, "INVALID_REQUEST", "请求参数不合法")
			return
		}
		var row models.Item
		if db.First(&row, "id = ?", c.Param("itemId")).Error != nil {
			httpapi.Error(c, 404, "ITEM_NOT_FOUND", "未找到对应单品")
			return
		}
		row.Name = req.Name
		row.CategoryLevel1 = req.CategoryLevel1
		row.CategoryLevel2 = req.CategoryLevel2
		row.PrimaryColor = req.PrimaryColor
		row.SecondaryColor = req.SecondaryColor
		row.Pattern = req.Pattern
		row.Brand = req.Brand
		row.Size = req.Size
		row.Seasons = toJSON(req.Seasons)
		row.Styles = toJSON(req.Styles)
		row.Scenes = toJSON(req.Scenes)
		row.Material = req.Material
		row.Fit = req.Fit
		row.PurchasePrice = req.PurchasePrice
		row.PurchaseDate = req.PurchaseDate
		row.CustomTags = toJSON(req.CustomTags)
		row.ManagementStatus = req.ManagementStatus
		row.WearableStatus = req.WearableStatus
		row.UpdatedAt = time.Now()
		if db.Save(&row).Error != nil {
			httpapi.Error(c, 500, "ITEM_UPDATE_FAILED", "更新单品失败")
			return
		}
		httpapi.OK(c, row)
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

	router.DELETE("/items/:itemId", func(c *gin.Context) {
		var row models.Item
		if db.First(&row, "id = ?", c.Param("itemId")).Error != nil {
			httpapi.Error(c, 404, "ITEM_NOT_FOUND", "未找到对应单品")
			return
		}
		row.ManagementStatus = "discarded"
		row.UpdatedAt = time.Now()
		if db.Save(&row).Error != nil {
			httpapi.Error(c, 500, "ITEM_DELETE_FAILED", "删除单品失败")
			return
		}
		httpapi.OK(c, gin.H{"deleted": true})
	})
}
