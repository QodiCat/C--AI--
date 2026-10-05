package profile

import (
	"ai-closet-server/internal/httpapi"
	"ai-closet-server/internal/models"
	"ai-closet-server/internal/modules/auth"
	"encoding/json"
	"errors"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
	"net/http"
)

type wardrobeDisplayRequest struct {
	Categories *[]string `json:"categories"`
	Seasons    *[]string `json:"seasons"`
}

func validSelection(values []string, allowed map[string]bool) bool {
	seen := map[string]bool{}
	for _, value := range values {
		if !allowed[value] || seen[value] {
			return false
		}
		seen[value] = true
	}
	return true
}
func registerWardrobeDisplay(router *gin.Engine, db *gorm.DB) {
	router.PATCH("/me/wardrobe-display", func(c *gin.Context) {
		var req wardrobeDisplayRequest
		if c.ShouldBindJSON(&req) != nil || req.Categories == nil || req.Seasons == nil || !validSelection(*req.Categories, map[string]bool{"上装": true, "下装": true, "外套": true, "裙装": true, "鞋履": true, "包袋": true, "配饰": true}) || !validSelection(*req.Seasons, map[string]bool{"春": true, "夏": true, "秋": true, "冬": true}) {
			httpapi.Error(c, http.StatusBadRequest, "INVALID_DISPLAY_PREFERENCES", "请选择有效且不重复的衣物类型和季节")
			return
		}
		payload, err := json.Marshal(map[string][]string{"categories": *req.Categories, "seasons": *req.Seasons})
		if err != nil {
			httpapi.Error(c, 500, "DISPLAY_UPDATE_FAILED", "保存显示设置失败")
			return
		}
		var user models.User
		err = db.Transaction(func(tx *gorm.DB) error {
			if err := tx.First(&user, "id = ?", auth.CurrentUserID(c)).Error; err != nil {
				return err
			}
			if err := tx.Model(&user).Update("wardrobe_display_preferences", string(payload)).Error; err != nil {
				return err
			}
			return tx.First(&user, "id = ?", user.ID).Error
		})
		if errors.Is(err, gorm.ErrRecordNotFound) {
			httpapi.Error(c, 404, "USER_NOT_FOUND", "未找到当前用户")
			return
		}
		if err != nil {
			httpapi.Error(c, 500, "DISPLAY_UPDATE_FAILED", "保存显示设置失败，请重试")
			return
		}
		httpapi.OK(c, user)
	})
}
