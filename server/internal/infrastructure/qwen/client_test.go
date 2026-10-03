package qwen

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestCompletionSendsImageAndDecodesJSON(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/chat/completions" || r.Header.Get("Authorization") != "Bearer test-credential" {
			t.Error("incorrect endpoint or auth")
		}
		var request map[string]any
		if json.NewDecoder(r.Body).Decode(&request) != nil {
			t.Fatal("invalid request")
		}
		content := request["messages"].([]any)[0].(map[string]any)["content"].([]any)
		if len(content) != 2 || content[1].(map[string]any)["image_url"].(map[string]any)["url"] != "https://example.org/shoe.jpg" {
			t.Error("missing image")
		}
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"choices":[{"finish_reason":"stop","message":{"content":"{\"name\":\"运动鞋\"}"}}]}`))
	}))
	defer server.Close()
	var result struct {
		Name string `json:"name"`
	}
	if err := New(server.URL, "test-credential", "vision-model").CompleteJSON(context.Background(), "输出 JSON", "https://example.org/shoe.jpg", &result); err != nil || result.Name != "运动鞋" {
		t.Fatalf("result=%+v error=%v", result, err)
	}
}

func TestCompletionRejectsInvalidAndTruncatedJSON(t *testing.T) {
	for _, body := range []string{`{"choices":[]}`, `{"choices":[{"finish_reason":"length","message":{"content":"{}"}}]}`, `{"choices":[{"message":{"content":"not JSON"}}]}`} {
		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.Write([]byte(body)) }))
		var result map[string]any
		if New(server.URL, "test-credential", "vision").CompleteJSON(context.Background(), "JSON", "", &result) == nil {
			t.Error("accepted invalid response")
		}
		server.Close()
	}
}

func TestCompletionDoesNotExposeProviderSecrets(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(401)
		w.Write([]byte("test-credential signed-secret-url"))
	}))
	defer server.Close()
	var result any
	err := New(server.URL, "test-credential", "vision").CompleteJSON(context.Background(), "JSON", "", &result)
	if err == nil || strings.Contains(err.Error(), "test-credential") || strings.Contains(err.Error(), "signed-secret") {
		t.Fatal("provider error exposed response")
	}
}
