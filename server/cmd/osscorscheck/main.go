package main

import (
	"ai-closet-server/internal/config"
	"errors"
	"flag"
	"fmt"
	"github.com/aliyun/aliyun-oss-go-sdk/oss"
	"os"
	"slices"
	"strings"
)

func main() {
	apply := flag.Bool("apply", false, "Add image read CORS for configured frontend origins")
	flag.Parse()
	if config.LoadEnv() != nil {
		fmt.Println("env load failed")
		return
	}
	cfg := config.Read()
	client, err := oss.New("https://"+cfg.AliyunOSSRegion+".aliyuncs.com", cfg.AliyunOSSAccessKeyID, cfg.AliyunOSSAccessKeySecret, oss.Timeout(10, 20))
	if err != nil {
		fmt.Println("client init failed")
		return
	}
	result, err := client.GetBucketCORS(cfg.AliyunOSSBucket)
	if err != nil {
		var e oss.ServiceError
		if !errors.As(err, &e) || e.Code != "NoSuchCORSConfiguration" {
			if errors.As(err, &e) {
				fmt.Println("CORS check:", e.Code, e.StatusCode)
			} else {
				fmt.Printf("CORS check error type: %T\n", err)
			}
			os.Exit(1)
		}
	}
	origins := []string{}
	for _, origin := range strings.Split(cfg.CORSOrigin, ",") {
		if origin = strings.TrimSpace(origin); origin != "" && origin != "*" {
			origins = append(origins, origin)
		}
	}
	if len(origins) == 0 {
		fmt.Println("Set explicit CORS_ORIGIN in server/.env")
		os.Exit(1)
	}
	fmt.Println("Frontend origins:", origins)
	fmt.Println("Existing CORS rule count:", len(result.CORSRules))
	if !*apply {
		return
	}
	for _, rule := range result.CORSRules {
		if slices.Equal(rule.AllowedOrigin, origins) && slices.Contains(rule.AllowedMethod, "GET") && slices.Contains(rule.AllowedMethod, "HEAD") {
			fmt.Println("Image read CORS already configured")
			return
		}
	}
	result.CORSRules = append(result.CORSRules, oss.CORSRule{AllowedOrigin: origins, AllowedMethod: []string{"GET", "HEAD"}, AllowedHeader: []string{"*"}, ExposeHeader: []string{"ETag"}, MaxAgeSeconds: 300})
	if err := client.SetBucketCORSV2(cfg.AliyunOSSBucket, oss.PutBucketCORS{CORSRules: result.CORSRules, ResponseVary: result.ResponseVary}); err != nil {
		var e oss.ServiceError
		if errors.As(err, &e) {
			fmt.Println("CORS update:", e.Code, e.StatusCode)
		} else {
			fmt.Printf("CORS update error type: %T\n", err)
		}
		os.Exit(1)
	}
	fmt.Println("Image read CORS configured; bucket access policy unchanged")
}
