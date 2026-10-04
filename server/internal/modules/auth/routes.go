package auth

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"

	"ai-closet-server/internal/httpapi"
	"ai-closet-server/internal/models"
)

const userIDContextKey = "authenticatedUserID"

type credentialsRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required,min=8,max=72"`
	Nickname string `json:"nickname"`
	Code     string `json:"code"`
}

func RegisterRoutes(router *gin.Engine, db *gorm.DB, verifier *Verifier) {
	registerPasswordRoutes(router, db, verifier)
	router.POST("/auth/register/code", func(c *gin.Context) {
		var req struct {
			Email string `json:"email" binding:"required,email,max=254"`
		}
		if c.ShouldBindJSON(&req) != nil {
			httpapi.Error(c, 400, "INVALID_REQUEST", "请输入有效邮箱")
			return
		}
		email := strings.ToLower(strings.TrimSpace(req.Email))
		var count int64
		if err := db.Model(&models.User{}).Where("email = ?", email).Count(&count).Error; err != nil {
			httpapi.Error(c, 500, "SEND_FAILED", "暂时无法发送验证码")
			return
		}
		if count > 0 {
			httpapi.Error(c, 409, "EMAIL_EXISTS", "该邮箱已注册")
			return
		}
		if err := verifier.Send(email, c.RemoteIP()); err != nil {
			if errors.Is(err, ErrRateLimit) {
				httpapi.Error(c, 429, "RATE_LIMITED", err.Error())
			} else {
				httpapi.Error(c, 503, "SEND_FAILED", "验证码发送失败，请稍后重试")
			}
			return
		}
		httpapi.OK(c, gin.H{"sent": true, "expiresIn": 600, "retryAfter": 60})
	})
	router.POST("/auth/register", func(c *gin.Context) {
		var req credentialsRequest
		if c.ShouldBindJSON(&req) != nil {
			httpapi.Error(c, http.StatusBadRequest, "INVALID_REQUEST", "请输入有效邮箱和至少 8 位密码")
			return
		}
		email := strings.ToLower(strings.TrimSpace(req.Email))
		var count int64
		if err := db.Model(&models.User{}).Where("email = ?", email).Count(&count).Error; err != nil {
			httpapi.Error(c, 500, "REGISTER_FAILED", "数据库查询失败，请稍后重试")
			return
		}
		if count > 0 {
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
		session := newSession(user.ID)
		if err := verifier.Register(email, req.Code, func() error {
			return db.Transaction(func(tx *gorm.DB) error {
				if err := tx.Create(&user).Error; err != nil {
					return err
				}
				return tx.Create(&session).Error
			})
		}); err != nil {
			if errors.Is(err, ErrCode) {
				httpapi.Error(c, 400, "INVALID_CODE", err.Error())
				return
			}
			httpapi.Error(c, 500, "REGISTER_FAILED", "注册失败")
			return
		}
		respondWithCreatedSession(c, user, session)
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
	session := newSession(user.ID)
	if err := db.Create(&session).Error; err != nil {
		httpapi.Error(c, 500, "LOGIN_FAILED", "登录失败")
		return
	}
	respondWithCreatedSession(c, user, session)
}

func newSession(userID string) models.Session {
	now := time.Now()
	return models.Session{ID: newSecureID("session"), UserID: userID, Token: newSecureID("token"), ExpiresAt: now.Add(30 * 24 * time.Hour), CreatedAt: now}
}

func respondWithCreatedSession(c *gin.Context, user models.User, session models.Session) {
	httpapi.OK(c, gin.H{"accessToken": session.Token, "expiresAt": session.ExpiresAt, "user": user})
}

func newSecureID(prefix string) string {
	buf := make([]byte, 24)
	if _, err := rand.Read(buf); err != nil {
		return fmt.Sprintf("%s_%d", prefix, time.Now().UnixNano())
	}
	return prefix + "_" + hex.EncodeToString(buf)
}

func bearer(value string) string {
	const prefix = "Bearer "
	if len(value) > len(prefix) && value[:len(prefix)] == prefix {
		return value[len(prefix):]
	}
	return ""
}
