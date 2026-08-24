package auth

import (
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"ai-closet-server/internal/httpapi"
	"ai-closet-server/internal/models"
)

type loginRequest struct {
	LoginType  string `json:"loginType" binding:"required"`
	Credential string `json:"credential" binding:"required"`
}

func RegisterRoutes(router *gin.Engine, db *gorm.DB) {
	router.POST("/auth/login", func(c *gin.Context) {
		var req loginRequest
		if c.ShouldBindJSON(&req) != nil {
			httpapi.Error(c, http.StatusBadRequest, "INVALID_REQUEST", "请输入登录凭证")
			return
		}
		var user models.User
		if err := db.First(&user, "id = ?", "user_demo").Error; err != nil {
			httpapi.Error(c, http.StatusNotFound, "USER_NOT_FOUND", "用户不存在")
			return
		}
		now := time.Now()
		session := models.Session{ID: fmt.Sprintf("session_%d", now.UnixNano()), UserID: user.ID, Token: fmt.Sprintf("token_%d", now.UnixNano()), ExpiresAt: now.Add(30 * 24 * time.Hour), CreatedAt: now}
		if err := db.Create(&session).Error; err != nil {
			httpapi.Error(c, 500, "LOGIN_FAILED", "登录失败")
			return
		}
		httpapi.OK(c, gin.H{"accessToken": session.Token, "expiresAt": session.ExpiresAt, "user": user})
	})

	router.POST("/auth/logout", func(c *gin.Context) {
		token := bearer(c.GetHeader("Authorization"))
		if token != "" {
			_ = db.Where("token = ?", token).Delete(&models.Session{}).Error
		}
		httpapi.OK(c, gin.H{"loggedOut": true})
	})
}

func bearer(value string) string {
	const prefix = "Bearer "
	if len(value) > len(prefix) && value[:len(prefix)] == prefix {
		return value[len(prefix):]
	}
	return ""
}
