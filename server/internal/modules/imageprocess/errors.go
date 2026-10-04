package imageprocess

import (
	"context"
	"crypto/x509"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"net/url"
	"regexp"
	"syscall"

	"github.com/alibabacloud-go/tea/tea"
)

var diagnosticID = regexp.MustCompile(`^[A-Za-z0-9_.:-]{1,128}$`)

func safeDiagnosticID(value string) string {
	if diagnosticID.MatchString(value) {
		return value
	}
	return "unknown"
}

func segmentationError(err error, region string) error {
	mode := "signed_url"
	if region != "oss-cn-shanghai" {
		mode = "file_upload"
	}
	var service *tea.SDKError
	if errors.As(err, &service) {
		code := safeDiagnosticID(tea.StringValue(service.Code))
		requestID := "unknown"
		var data map[string]interface{}
		if json.Unmarshal([]byte(tea.StringValue(service.Data)), &data) == nil {
			for _, key := range []string{"RequestId", "requestId", "RequestID"} {
				if value, ok := data[key].(string); ok {
					requestID = safeDiagnosticID(value)
					break
				}
			}
		}
		// Raw SDK messages and data may contain AccessKeys, signed URLs, and upload credentials.
		log.Printf("Aliyun segmentation failed: mode=%s code=%s status=%d request_id=%s", mode, code, tea.IntValue(service.StatusCode), requestID)
		return fmt.Errorf("阿里云商品抠图失败（错误码：%s，请求ID：%s）", code, requestID)
	}
	var request *url.Error
	if errors.As(err, &request) {
		host := "unknown"
		if parsed, parseErr := url.Parse(request.URL); parseErr == nil {
			host = safeDiagnosticID(parsed.Hostname())
		}
		reason := networkReason(request.Err)
		log.Printf("Aliyun segmentation failed: mode=%s host=%s reason=%s cause_type=%T", mode, host, reason, request.Err)
		return fmt.Errorf("阿里云抠图连接失败（%s，目标：%s）", reason, host)
	}
	log.Printf("Aliyun segmentation failed: mode=%s error_type=%T", mode, err)
	return fmt.Errorf("阿里云抠图服务连接失败，请检查后端网络后重试")
}

func networkReason(err error) string {
	var dns *net.DNSError
	var certificate x509.UnknownAuthorityError
	var hostname x509.HostnameError
	var netErr net.Error
	switch {
	case errors.As(err, &dns):
		return "DNS解析失败"
	case errors.As(err, &certificate), errors.As(err, &hostname):
		return "TLS证书验证失败"
	case errors.Is(err, context.DeadlineExceeded):
		return "连接超时"
	case errors.As(err, &netErr) && netErr.Timeout():
		return "连接超时"
	case errors.Is(err, syscall.ECONNREFUSED):
		return "连接被拒绝"
	case errors.Is(err, syscall.ECONNRESET):
		return "连接被重置"
	case errors.Is(err, syscall.ENETUNREACH), errors.Is(err, syscall.EHOSTUNREACH):
		return "网络不可达"
	case errors.Is(err, io.EOF), errors.Is(err, io.ErrUnexpectedEOF):
		return "连接提前断开"
	default:
		return "网络请求失败"
	}
}
