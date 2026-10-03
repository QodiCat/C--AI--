package oss

import (
	"bytes"
	"fmt"
	"image"
	"image/jpeg"
	_ "image/png"
	"io"
	"net/http"
	"time"

	"ai-closet-server/internal/config"
	"ai-closet-server/internal/httpapi"
	"ai-closet-server/internal/modules/auth"
	aliyunoss "github.com/aliyun/aliyun-oss-go-sdk/oss"
	"github.com/gin-gonic/gin"
	"golang.org/x/image/draw"
	_ "golang.org/x/image/webp"
)

func registerImageUpload(router *gin.Engine, cfg config.Config) {
	router.POST("/uploads/images", func(c *gin.Context) {
		if cfg.AliyunOSSBucket == "" || cfg.AliyunOSSRegion == "" || cfg.AliyunOSSAccessKeyID == "" || cfg.AliyunOSSAccessKeySecret == "" {
			httpapi.Error(c, 503, "OSS_NOT_CONFIGURED", "请先配置 OSS Bucket、Region 和访问凭据")
			return
		}
		c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, 11<<20)
		file, err := c.FormFile("file")
		if err != nil || file.Size > 10<<20 {
			httpapi.Error(c, 400, "INVALID_IMAGE", "请选择不超过10 MB的图片")
			return
		}
		if c.Request.MultipartForm != nil {
			defer c.Request.MultipartForm.RemoveAll()
		}
		input, err := file.Open()
		if err != nil {
			httpapi.Error(c, 400, "INVALID_IMAGE", "图片读取失败")
			return
		}
		defer input.Close()
		raw, err := io.ReadAll(io.LimitReader(input, (10<<20)+1))
		if err != nil || len(raw) > 10<<20 {
			httpapi.Error(c, 400, "INVALID_IMAGE", "图片过大")
			return
		}
		normalized, err := normalizeImage(raw)
		if err != nil {
			httpapi.Error(c, 400, "INVALID_IMAGE", err.Error())
			return
		}
		client, err := aliyunoss.New("https://"+cfg.AliyunOSSRegion+".aliyuncs.com", cfg.AliyunOSSAccessKeyID, cfg.AliyunOSSAccessKeySecret, aliyunoss.Timeout(10, 60))
		if err != nil {
			httpapi.Error(c, 503, "OSS_NOT_CONFIGURED", "OSS 配置无效")
			return
		}
		bucket, err := client.Bucket(cfg.AliyunOSSBucket)
		if err != nil {
			httpapi.Error(c, 503, "OSS_NOT_CONFIGURED", "OSS Bucket 无效")
			return
		}
		key := fmt.Sprintf("users/%s/originals/%d.jpg", auth.CurrentUserID(c), time.Now().UnixNano())
		if bucket.PutObject(key, bytes.NewReader(normalized), aliyunoss.ContentType("image/jpeg")) != nil {
			httpapi.Error(c, 502, "UPLOAD_FAILED", "图片上传 OSS 失败，请检查权限及网络")
			return
		}
		httpapi.OK(c, gin.H{"objectUri": "oss://" + cfg.AliyunOSSBucket + "/" + key})
	})
}

func normalizeImage(raw []byte) ([]byte, error) {
	config, _, err := image.DecodeConfig(bytes.NewReader(raw))
	if err != nil || config.Width <= 0 || config.Height <= 0 || int64(config.Width)*int64(config.Height) > 40000000 {
		return nil, fmt.Errorf("请选择有效的 JPEG、PNG 或 WebP 图片（不超过4000万像素）")
	}
	source, _, err := image.Decode(bytes.NewReader(raw))
	if err != nil {
		return nil, fmt.Errorf("图片无法解码")
	}
	width, height := config.Width, config.Height
	if width > 1900 || height > 1900 {
		if width >= height {
			height = max(1, height*1900/width)
			width = 1900
		} else {
			width = max(1, width*1900/height)
			height = 1900
		}
	}
	target := image.NewRGBA(image.Rect(0, 0, width, height))
	draw.Draw(target, target.Bounds(), image.White, image.Point{}, draw.Src)
	draw.ApproxBiLinear.Scale(target, target.Bounds(), source, source.Bounds(), draw.Over, nil)
	for _, quality := range []int{85, 70, 55} {
		var output bytes.Buffer
		if jpeg.Encode(&output, target, &jpeg.Options{Quality: quality}) != nil {
			return nil, fmt.Errorf("图片转换失败")
		}
		if output.Len() < 3<<20 {
			return output.Bytes(), nil
		}
	}
	return nil, fmt.Errorf("图片压缩后仍超过3 MB，请重新拍摄")
}
