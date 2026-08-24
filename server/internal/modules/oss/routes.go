package oss

import (
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"

	"ai-closet-server/internal/config"
	"ai-closet-server/internal/httpapi"
)

type signatureRequest struct {
	FileName    string `json:"fileName" binding:"required"`
	ContentType string `json:"contentType" binding:"required"`
	Directory   string `json:"directory" binding:"required"`
}

func RegisterRoutes(router *gin.Engine, cfg config.Config) {
	router.POST("/uploads/oss-signature", func(c *gin.Context) {
		var req signatureRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			httpapi.Error(c, http.StatusBadRequest, "INVALID_REQUEST", "请求参数不合法")
			return
		}

		if cfg.AliyunOSSBucket == "" || cfg.AliyunOSSRegion == "" {
			httpapi.Error(c, http.StatusNotImplemented, "OSS_NOT_CONFIGURED", "阿里云 OSS 尚未配置真实 Bucket 与 Region")
			return
		}

		objectKey := fmt.Sprintf("users/user_demo/%s/%d_%s", req.Directory, time.Now().Unix(), req.FileName)
		uploadURL := fmt.Sprintf("https://%s.%s.aliyuncs.com", cfg.AliyunOSSBucket, cfg.AliyunOSSRegion)

		httpapi.OK(c, gin.H{
			"provider":         "aliyun-oss",
			"bucket":           cfg.AliyunOSSBucket,
			"region":           cfg.AliyunOSSRegion,
			"objectKey":        objectKey,
			"uploadUrl":        uploadURL,
			"expiresInSeconds": 300,
			"formData": gin.H{
				"key":                   objectKey,
				"OSSAccessKeyId":        "REPLACE_WITH_REAL_SIGNATURE",
				"policy":                "REPLACE_WITH_REAL_POLICY",
				"signature":             "REPLACE_WITH_REAL_SIGNATURE",
				"success_action_status": "200",
			},
		})
	})
}
