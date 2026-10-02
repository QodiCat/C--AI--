package auth

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
	"golang.org/x/crypto/bcrypt"

	"ai-closet-server/internal/httpapi"
	"ai-closet-server/internal/models"
)

const userIDContextKey = "authenticatedUserID"

type credentialsRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required,min=8,max=72"`
	Nickname string `json:"nickname"`
}

func RegisterRoutes(router *gin.Engine, db *gorm.DB) {
	router.POST("/auth/register", func(c *gin.Context) {
		var req credentialsRequest
		if c.ShouldBindJSON(&req) != nil {
			httpapi.Error(c, http.StatusBadRequest, "INVALID_REQUEST", "请输入有效邮箱和至少 8 位密码")
			return
		}
		email := strings.ToLower(strings.TrimSpace(req.Email))
		var count int64
		if db.Model(&models.User{}).Where("email = ?", email).Count(&count); count > 0 {
			httpapi.Error(c, http.StatusConflict, "EMAIL_EXISTS", "该邮箱已注册")
			return
		}
		hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
		if err != nil {
			httpapi.Error(c, 500, "REGISTER_FAILED", "注册失败")
			return
		}
		now := time.Now()
		nickname := strings.TrimSpace(req.Nickname)
		if nickname == "" {
			nickname = strings.Split(email, "@")[0]
		}
		user := models.User{ID: newSecureID("user"), Email: email, PasswordHash: string(hash), Nickname: nickname, LoginType: "email", StylePreferences: "[]", CreatedAt: now, UpdatedAt: now}
		if err := db.Create(&user).Error; err != nil {
			httpapi.Error(c, 500, "REGISTER_FAILED", "注册失败")
			return
		}
		respondWithSession(c, db, user)
	})

	router.POST("/auth/login", func(c *gin.Context) {
		var req credentialsRequest
		if c.ShouldBindJSON(&req) != nil {
			httpapi.Error(c, http.StatusBadRequest, "INVALID_REQUEST", "请输入有效邮箱和密码")
			return
		}
		var user models.User
		if err := db.First(&user, "email = ?", strings.ToLower(strings.TrimSpace(req.Email))).Error; err != nil || bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)) != nil {
			httpapi.Error(c, http.StatusUnauthorized, "INVALID_CREDENTIALS", "邮箱或密码错误")
			return
		}
		respondWithSession(c, db, user)
	})

	router.POST("/auth/logout", func(c *gin.Context) {
		token := bearer(c.GetHeader("Authorization"))
		if token != "" {
			_ = db.Where("token = ?", token).Delete(&models.Session{}).Error
		}
		httpapi.OK(c, gin.H{"loggedOut": true})
	})
}

func RequireAuth(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		token := bearer(c.GetHeader("Authorization"))
		var session models.Session
		if token == "" || db.Where("token = ? AND expires_at > ?", token, time.Now()).First(&session).Error != nil {
			httpapi.Error(c, http.StatusUnauthorized, "UNAUTHORIZED", "请先登录")
			c.Abort()
			return
		}
		c.Set(userIDContextKey, session.UserID)
		c.Next()
	}
}

func CurrentUserID(c *gin.Context) string { return c.GetString(userIDContextKey) }

func respondWithSession(c *gin.Context, db *gorm.DB, user models.User) {
	now := time.Now()
	session := models.Session{ID: newSecureID("session"), UserID: user.ID, Token: newSecureID("token"), ExpiresAt: now.Add(30 * 24 * time.Hour), CreatedAt: now}
	if err := db.Create(&session).Error; err != nil {
		httpapi.Error(c, 500, "LOGIN_FAILED", "登录失败")
		return
	}
	httpapi.OK(c, gin.H{"accessToken": session.Token, "expiresAt": session.ExpiresAt, "user": user})
}

func newSecureID(prefix string) string {
	buf := make([]byte, 24)
	if _, err := rand.Read(buf); err != nil { return fmt.Sprintf("%s_%d", prefix, time.Now().UnixNano()) }
	return prefix + "_" + hex.EncodeToString(buf)
}

func bearer(value string) string {
	const prefix = "Bearer "
	if len(value) > len(prefix) && value[:len(prefix)] == prefix {
		return value[len(prefix):]
	}
	return ""
}
