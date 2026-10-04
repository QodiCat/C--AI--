package imageprocess

import (
	"bytes"
	"fmt"
	"log"
	"net"
	"net/url"
	"strings"
	"testing"

	"github.com/alibabacloud-go/tea/tea"
)

func TestSegmentationErrorIncludesSafeDiagnostics(t *testing.T) {
	var captured bytes.Buffer
	previous := log.Writer()
	log.SetOutput(&captured)
	defer log.SetOutput(previous)
	service := &tea.SDKError{Code: tea.String("InvalidAccessKeyId.NotFound"), StatusCode: tea.Int(403), Message: tea.String("SECRET_MESSAGE"), Data: tea.String(`{"RequestId":"req-123","AccessKeySecret":"SECRET_DATA"}`)}
	err := segmentationError(fmt.Errorf("wrapped: %w", service), "oss-cn-beijing")
	if !strings.Contains(err.Error(), "InvalidAccessKeyId.NotFound") || !strings.Contains(err.Error(), "req-123") {
		t.Fatal("missing diagnostics")
	}
	if !strings.Contains(captured.String(), "mode=file_upload") {
		t.Fatal("missing request mode")
	}
	if strings.Contains(err.Error()+captured.String(), "SECRET_") {
		t.Fatal("leaked SDK data")
	}
}

func TestSegmentationNetworkErrorRedactsURL(t *testing.T) {
	var captured bytes.Buffer
	previous := log.Writer()
	log.SetOutput(&captured)
	defer log.SetOutput(previous)
	network := &url.Error{Op: "Post", URL: "https://openplatform.aliyuncs.com/?AccessKeyId=SECRET_ID&Signature=SECRET_SIGNATURE", Err: &net.DNSError{Err: "SECRET_INTERNAL", Name: "openplatform.aliyuncs.com", IsNotFound: true}}
	err := segmentationError(network, "oss-cn-beijing")
	if !strings.Contains(err.Error(), "DNS解析失败") || !strings.Contains(captured.String(), "host=openplatform.aliyuncs.com") {
		t.Fatal("missing network diagnostics")
	}
	if strings.Contains(err.Error()+captured.String(), "SECRET_") {
		t.Fatal("network error leaked credentials")
	}
}
