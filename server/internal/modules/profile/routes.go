package profile

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"ai-closet-server/internal/httpapi"
	"ai-closet-server/internal/models"
)

type updateProfileRequest struct {
	Nickname string `json:"nickname" binding:"required"`
	City     string `json:"city" binding:"required"`
	BodyType string `json:"bodyType" binding:"required"`
}

type updatePreferencesRequest struct {
	StylePreferences []string `json:"stylePreferences" binding:"required"`
}

type updatePrivacyRequest struct {
	AllowModelTraining bool `json:"allowModelTraining"`
}

func RegisterRoutes(router *gin.Engine, db *gorm.DB) {
	router.GET("/me", func(c *gin.Context) {
		var user models.User
		if err := db.First(&user, "id = ?", "user_demo").Error; err != nil {
			httpapi.Error(c, http.StatusNotFound, "USER_NOT_FOUND", "未找到当前用户")
			return
		}

		httpapi.OK(c, user)
	})

	router.PATCH("/me/profile", func(c *gin.Context) {
		var req updateProfileRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			httpapi.Error(c, http.StatusBadRequest, "INVALID_REQUEST", "请求参数不合法")
			return
		}

		var user models.User
		if err := db.First(&user, "id = ?", "user_demo").Error; err != nil {
			httpapi.Error(c, http.StatusNotFound, "USER_NOT_FOUND", "未找到当前用户")
			return
		}

		user.Nickname = req.Nickname
		user.City = req.City
		user.BodyType = req.BodyType
		user.UpdatedAt = time.Now()

		if err := db.Save(&user).Error; err != nil {
			httpapi.Error(c, http.StatusInternalServerError, "USER_UPDATE_FAILED", "更新资料失败")
			return
		}

		httpapi.OK(c, user)
	})

	router.PATCH("/me/style-preferences", func(c *gin.Context) {
		var req updatePreferencesRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			httpapi.Error(c, http.StatusBadRequest, "INVALID_REQUEST", "请求参数不合法")
			return
		}

		var user models.User
		if err := db.First(&user, "id = ?", "user_demo").Error; err != nil {
			httpapi.Error(c, http.StatusNotFound, "USER_NOT_FOUND", "未找到当前用户")
			return
		}

		user.StylePreferences = toJSON(req.StylePreferences)
		user.UpdatedAt = time.Now()

		if err := db.Save(&user).Error; err != nil {
			httpapi.Error(c, http.StatusInternalServerError, "PREFERENCES_UPDATE_FAILED", "更新风格偏好失败")
			return
		}

		httpapi.OK(c, user)
	})

	router.PATCH("/me/privacy", func(c *gin.Context) {
		var req updatePrivacyRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			httpapi.Error(c, http.StatusBadRequest, "INVALID_REQUEST", "请求参数不合法")
			return
		}

		var user models.User
		if err := db.First(&user, "id = ?", "user_demo").Error; err != nil {
			httpapi.Error(c, http.StatusNotFound, "USER_NOT_FOUND", "未找到当前用户")
			return
		}

		user.AllowModelTraining = req.AllowModelTraining
		user.UpdatedAt = time.Now()

		if err := db.Save(&user).Error; err != nil {
			httpapi.Error(c, http.StatusInternalServerError, "PRIVACY_UPDATE_FAILED", "更新隐私设置失败")
			return
		}

		httpapi.OK(c, user)
	})
}
