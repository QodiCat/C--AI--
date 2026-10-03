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
	} else {
		fmt.Println(stage, "connection failed")
	}
	os.Exit(1)
}
func main() {
	cfg := config.Read()
	client, err := oss.New("https://"+cfg.AliyunOSSRegion+".aliyuncs.com", cfg.AliyunOSSAccessKeyID, cfg.AliyunOSSAccessKeySecret, oss.Timeout(10, 20))
	if err != nil {
		fail("configuration", err)
	}
	bucket, err := client.Bucket(cfg.AliyunOSSBucket)
	if err != nil {
		fail("bucket", err)
	}
	var data bytes.Buffer
	png.Encode(&data, image.NewRGBA(image.Rect(0, 0, 1, 1)))
	key := fmt.Sprintf("users/local_connectivity_check/originals/check_%d.png", time.Now().UnixNano())
	if err := bucket.PutObject(key, bytes.NewReader(data.Bytes()), oss.ContentType("image/png")); err != nil {
		fail("OSS upload", err)
	}
	fmt.Println("OSS upload: PASS")
	defer func() {
		if err := bucket.DeleteObject(key); err != nil {
			fmt.Println("Test cleanup failed; object:", key)
		} else {
			fmt.Println("Test cleanup: PASS")
		}
	}()
	reader, err := bucket.GetObject(key)
	if err != nil {
		fmt.Println("OSS read: FAILED")
		return
	}
	defer reader.Close()
	got, err := io.ReadAll(reader)
	if err != nil || !bytes.Equal(got, data.Bytes()) {
		fmt.Println("OSS read: FAILED")
		return
	}
	fmt.Println("OSS read: PASS")
}
