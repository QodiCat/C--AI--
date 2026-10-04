package main

import (
	"ai-closet-server/internal/config"
	"bytes"
	"fmt"
	"github.com/aliyun/aliyun-oss-go-sdk/oss"
	"image"
	"image/png"
	"io"
	"os"
	"time"
)

func fail(stage string, err error) {
	if service, ok := err.(oss.ServiceError); ok {
		fmt.Println(stage, service.Code, "HTTP", service.StatusCode)
		fmt.Println("Reason:", service.Message)
		fmt.Println("EC:", service.Ec, "RequestID:", service.RequestID)
	} else {
		fmt.Println(stage, err)
	}
	os.Exit(1)
}
func main() {
	if err := run(); err != nil {
		fail("OSS check: FAILED", err)
	}
}

func run() (result error) {
	if err := config.LoadEnv(); err != nil {
		return fmt.Errorf("读取 .env 失败: %w", err)
	}
	cfg := config.Read()
	if cfg.AliyunOSSRegion == "" || cfg.AliyunOSSBucket == "" || cfg.AliyunOSSAccessKeyID == "" || cfg.AliyunOSSAccessKeySecret == "" {
		return fmt.Errorf("请配置 ALIYUN_OSS_REGION、ALIYUN_OSS_BUCKET、ALIYUN_ACCESS_KEY_ID 和 ALIYUN_ACCESS_KEY_SECRET")
	}
	client, err := oss.New("https://"+cfg.AliyunOSSRegion+".aliyuncs.com", cfg.AliyunOSSAccessKeyID, cfg.AliyunOSSAccessKeySecret, oss.Timeout(10, 20))
	if err != nil {
		return err
	}
	bucket, err := client.Bucket(cfg.AliyunOSSBucket)
	if err != nil {
		return err
	}
	var data bytes.Buffer
	if err := png.Encode(&data, image.NewRGBA(image.Rect(0, 0, 1, 1))); err != nil {
		return err
	}
	key := fmt.Sprintf("users/local_connectivity_check/originals/check_%d.png", time.Now().UnixNano())
	if err := bucket.PutObject(key, bytes.NewReader(data.Bytes()), oss.ContentType("image/png")); err != nil {
		return err
	}
	fmt.Println("OSS upload: PASS")
	defer func() {
		if err := bucket.DeleteObject(key); err != nil {
			fmt.Println("Test cleanup failed; object:", key)
			if result == nil {
				result = err
			}
		} else {
			fmt.Println("Test cleanup: PASS")
		}
	}()
	reader, err := bucket.GetObject(key)
	if err != nil {
		return err
	}
	defer reader.Close()
	got, err := io.ReadAll(reader)
	if err != nil {
		return err
	}
	if !bytes.Equal(got, data.Bytes()) {
		return fmt.Errorf("读取内容与上传内容不一致")
	}
	fmt.Println("OSS read: PASS")
	return nil
}
