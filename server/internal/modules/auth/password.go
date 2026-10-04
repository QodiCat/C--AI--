package auth

import (
	"errors"
	"fmt"
	"log"
	"strings"
	"time"

	"ai-closet-server/internal/httpapi"
	"ai-closet-server/internal/models"
	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgconn"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

var errPasswordChanged = errors.New("password changed concurrently")

func registerPasswordRoutes(router *gin.Engine, db *gorm.DB, verifier *Verifier) {
	router.POST("/auth/password/reset/code", func(c *gin.Context) {
		var req struct {
			Email string `json:"email" binding:"required,email,max=254"`
		}
		if c.ShouldBindJSON(&req) != nil {
			httpapi.Error(c, 400, "INVALID_REQUEST", "请输入有效邮箱")
			return
		}
		email := strings.ToLower(strings.TrimSpace(req.Email))
		var user models.User
		err := db.Where("email = ?", email).First(&user).Error
		if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
			httpapi.Error(c, 500, "SEND_FAILED", "暂时无法发送验证码")
			return
		}
		if err == nil {
			if err := verifier.SendPasswordReset(email, c.RemoteIP()); err != nil {
				if errors.Is(err, ErrRateLimit) {
					httpapi.Error(c, 429, "RATE_LIMITED", err.Error())
				} else {
					httpapi.Error(c, 503, "SEND_FAILED", "验证码发送失败，请稍后重试")
				}
				return
			}
		}
		httpapi.OK(c, gin.H{"message": "如果该邮箱已注册，重置验证码将发送到邮箱", "retryAfter": 60, "expiresIn": 600})
	})
	router.POST("/auth/password/reset", func(c *gin.Context) {
		var req struct {
			Email       string `json:"email" binding:"required,email,max=254"`
			Code        string `json:"code" binding:"required,len=6"`
			NewPassword string `json:"newPassword" binding:"required,max=72"`
		}
		if c.ShouldBindJSON(&req) != nil || !validPassword(req.NewPassword) {
			httpapi.Error(c, 400, "INVALID_REQUEST", "请输入邮箱、6 位验证码和 8–72 字节的新密码")
			return
		}
		email := strings.ToLower(strings.TrimSpace(req.Email))
		hash, err := bcrypt.GenerateFromPassword([]byte(req.NewPassword), bcrypt.DefaultCost)
		if err != nil {
			httpapi.Error(c, 500, "RESET_FAILED", "重置失败，请稍后重试")
			return
		}
		err = verifier.ResetPassword(email, req.Code, func() error {
			var user models.User
			if err := db.Where("email = ?", email).First(&user).Error; err != nil {
				return err
			}
			return replacePassword(db, user, string(hash))
		})
		if err != nil {
			if errors.Is(err, ErrCode) || errors.Is(err, gorm.ErrRecordNotFound) {
				httpapi.Error(c, 400, "INVALID_CODE", ErrCode.Error())
			} else {
				logPasswordFailure("reset", err)
				httpapi.Error(c, 500, "RESET_FAILED", "密码暂时无法保存，请稍后重试")
			}
			return
		}
		httpapi.OK(c, gin.H{"message": "密码已重置，请使用新密码登录"})
	})
	router.POST("/auth/password/change", RequireAuth(db), func(c *gin.Context) {
		var req struct {
			CurrentPassword string `json:"currentPassword" binding:"required,max=72"`
			NewPassword     string `json:"newPassword" binding:"required,max=72"`
		}
		if c.ShouldBindJSON(&req) != nil || !validPassword(req.NewPassword) {
			httpapi.Error(c, 400, "INVALID_REQUEST", "请输入当前密码和 8–72 字节的新密码")
			return
		}
		var user models.User
		if err := db.First(&user, "id = ?", CurrentUserID(c)).Error; err != nil {
			httpapi.Error(c, 500, "CHANGE_FAILED", "暂时无法修改密码")
			return
		}
		if bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.CurrentPassword)) != nil {
			httpapi.Error(c, 400, "INVALID_PASSWORD", "当前密码错误")
			return
		}
		if req.CurrentPassword == req.NewPassword {
			httpapi.Error(c, 400, "INVALID_PASSWORD", "新密码不能与当前密码相同")
			return
		}
		hash, err := bcrypt.GenerateFromPassword([]byte(req.NewPassword), bcrypt.DefaultCost)
		if err != nil {
			httpapi.Error(c, 500, "CHANGE_FAILED", "修改失败，请稍后重试")
			return
		}
		if err := replacePassword(db, user, string(hash)); err != nil {
			logPasswordFailure("change", err)
			httpapi.Error(c, 500, "CHANGE_FAILED", "修改失败，请重新登录后重试")
			return
		}
		httpapi.OK(c, gin.H{"message": "密码已修改，请重新登录"})
	})
}

func validPassword(password string) bool {
	return len([]byte(password)) >= 8 && len([]byte(password)) <= 72
}

func replacePassword(db *gorm.DB, user models.User, hash string) error {
	return db.Transaction(func(tx *gorm.DB) error {
		result := tx.Model(&models.User{}).Where("id = ? AND COALESCE(password_hash, '') = ?", user.ID, user.PasswordHash).Updates(map[string]any{"password_hash": hash, "updated_at": time.Now()})
		if result.Error != nil {
			return fmt.Errorf("update password: %w", result.Error)
		}
		if result.RowsAffected != 1 {
			return errPasswordChanged
		}
		if err := tx.Where("user_id = ?", user.ID).Delete(&models.Session{}).Error; err != nil {
			return fmt.Errorf("revoke sessions: %w", err)
		}
		return nil
	})
}

// Log identifiers only: database errors can include password hashes or query values.
func logPasswordFailure(action string, err error) {
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) {
		log.Printf("password %s failed: sqlstate=%s table=%s constraint=%s", action, pgErr.Code, pgErr.TableName, pgErr.ConstraintName)
		return
	}
	if errors.Is(err, errPasswordChanged) {
		log.Printf("password %s failed: concurrent_password_change", action)
		return
	}
	log.Printf("password %s failed: error_type=%T", action, err)
}
