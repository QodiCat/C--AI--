package oss

import (
	"crypto/hmac"
	"crypto/sha1"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"

	"ai-closet-server/internal/config"
	"ai-closet-server/internal/httpapi"
	"ai-closet-server/internal/modules/auth"
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
		if cfg.AliyunOSSAccessKeyID == "" || cfg.AliyunOSSAccessKeySecret == "" {
			httpapi.Error(c, http.StatusNotImplemented, "OSS_CREDENTIALS_MISSING", "阿里云 OSS 访问凭证尚未配置")
			return
		}
		allowedDirectory := map[string]bool{"originals": true, "cutouts": true, "wear-logs": true, "avatars": true}
		allowedContentType := map[string]bool{"image/jpeg": true, "image/png": true, "image/webp": true}
		if !allowedDirectory[req.Directory] || !allowedContentType[req.ContentType] || filepath.Base(req.FileName) != req.FileName {
			httpapi.Error(c, http.StatusBadRequest, "INVALID_UPLOAD_PATH", "上传目录或文件名不合法")
			return
		}

		objectKey := fmt.Sprintf("users/%s/%s/%d_%s", auth.CurrentUserID(c), req.Directory, time.Now().Unix(), req.FileName)
		uploadURL := fmt.Sprintf("https://%s.%s.aliyuncs.com", cfg.AliyunOSSBucket, cfg.AliyunOSSRegion)
		expiresAt := time.Now().UTC().Add(5 * time.Minute)
		policyJSON, _ := json.Marshal(gin.H{
			"expiration": expiresAt.Format(time.RFC3339),
			"conditions": []any{
				gin.H{"bucket": cfg.AliyunOSSBucket},
				gin.H{"key": objectKey},
				gin.H{"Content-Type": req.ContentType},
				[]any{"content-length-range", 1, 10 * 1024 * 1024},
			},
		})
		policy := base64.StdEncoding.EncodeToString(policyJSON)
		mac := hmac.New(sha1.New, []byte(cfg.AliyunOSSAccessKeySecret))
		_, _ = mac.Write([]byte(policy))
		signature := base64.StdEncoding.EncodeToString(mac.Sum(nil))

		httpapi.OK(c, gin.H{
			"provider":         "aliyun-oss",
			"bucket":           cfg.AliyunOSSBucket,
			"region":           cfg.AliyunOSSRegion,
			"objectKey":        objectKey,
			"uploadUrl":        uploadURL,
			"expiresInSeconds": 300,
			"objectUri":        fmt.Sprintf("oss://%s/%s", cfg.AliyunOSSBucket, objectKey),
			"formData": gin.H{
				"key":                   objectKey,
				"Content-Type":          req.ContentType,
				"OSSAccessKeyId":        cfg.AliyunOSSAccessKeyID,
				"policy":                policy,
				"signature":             signature,
				"success_action_status": "200",
			},
		})
	})

	router.GET("/uploads/oss-url", func(c *gin.Context) {
		if cfg.AliyunOSSBucket == "" || cfg.AliyunOSSRegion == "" ||
			cfg.AliyunOSSAccessKeyID == "" || cfg.AliyunOSSAccessKeySecret == "" {
			httpapi.Error(c, http.StatusNotImplemented, "OSS_NOT_CONFIGURED", "阿里云 OSS 尚未完整配置")
			return
		}
		prefix := fmt.Sprintf("oss://%s/users/%s/", cfg.AliyunOSSBucket, auth.CurrentUserID(c))
		objectURI := c.Query("objectUri")
		if !strings.HasPrefix(objectURI, prefix) {
			httpapi.Error(c, http.StatusBadRequest, "INVALID_OBJECT_URI", "对象地址不合法")
			return
		}
		objectKey := strings.TrimPrefix(objectURI, "oss://"+cfg.AliyunOSSBucket+"/")
		expires := time.Now().Add(5 * time.Minute).Unix()
		canonicalResource := fmt.Sprintf("/%s/%s", cfg.AliyunOSSBucket, objectKey)
		stringToSign := "GET\n\n\n" + strconv.FormatInt(expires, 10) + "\n" + canonicalResource
		mac := hmac.New(sha1.New, []byte(cfg.AliyunOSSAccessKeySecret))
		_, _ = mac.Write([]byte(stringToSign))
		signature := base64.StdEncoding.EncodeToString(mac.Sum(nil))
		readURL := url.URL{
			Scheme: "https",
			Host:   fmt.Sprintf("%s.%s.aliyuncs.com", cfg.AliyunOSSBucket, cfg.AliyunOSSRegion),
			Path:   "/" + objectKey,
		}
		query := readURL.Query()
		query.Set("OSSAccessKeyId", cfg.AliyunOSSAccessKeyID)
		query.Set("Expires", strconv.FormatInt(expires, 10))
		query.Set("Signature", signature)
		readURL.RawQuery = query.Encode()
		httpapi.OK(c, gin.H{"url": readURL.String(), "expiresInSeconds": 300})
	})
}
