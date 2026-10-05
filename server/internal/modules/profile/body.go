package profile

import (
	"errors"
	"math"

	"ai-closet-server/internal/httpapi"
	"ai-closet-server/internal/models"
	"ai-closet-server/internal/modules/auth"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// Zero clears a measurement; omitted fields retain their current values.
func registerBodyMeasurements(router *gin.Engine, db *gorm.DB) {
	router.PATCH("/me/body-measurements", func(c *gin.Context) {
		var values map[string]*float64
		if c.ShouldBindJSON(&values) != nil || len(values) == 0 {
			httpapi.Error(c, 400, "INVALID_REQUEST", "请填写身体数据")
			return
		}
		columns := map[string]string{"height": "height", "weight": "weight", "bust": "bust", "hip": "hip", "waist": "waist", "shoulderWidth": "shoulder_width", "thighCircumference": "thigh_circumference", "legLength": "leg_length", "torsoLength": "torso_length"}
		updates := map[string]any{}
		for key, supplied := range values {
			if supplied == nil {
				httpapi.Error(c, 400, "INVALID_MEASUREMENT", "身体数据须为数字，0 表示未填写")
				return
			}
			value := *supplied
			column, ok := columns[key]
			if !ok || math.IsNaN(value) || math.IsInf(value, 0) || value < 0 || value > 300 {
				httpapi.Error(c, 400, "INVALID_MEASUREMENT", "身体数据须为 0 到 300 的数字，0 表示未填写")
				return
			}
			updates[column] = value
		}
		var user models.User
		err := db.Transaction(func(tx *gorm.DB) error {
			if err := tx.First(&user, "id = ?", auth.CurrentUserID(c)).Error; err != nil {
				return err
			}
			if err := tx.Model(&user).Updates(updates).Error; err != nil {
				return err
			}
			return tx.First(&user, "id = ?", user.ID).Error
		})
		if errors.Is(err, gorm.ErrRecordNotFound) {
			httpapi.Error(c, 404, "USER_NOT_FOUND", "未找到当前用户")
			return
		}
		if err != nil {
			httpapi.Error(c, 500, "BODY_UPDATE_FAILED", "保存身体数据失败，请重试")
			return
		}
		httpapi.OK(c, user)
	})
}
