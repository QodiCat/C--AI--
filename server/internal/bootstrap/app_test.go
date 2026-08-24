package bootstrap

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"testing"
)

func TestCoreMVPFlow(t *testing.T) {
	t.Setenv("DB_PATH", filepath.Join(t.TempDir(), "test.db"))
	app, err := NewApp()
	if err != nil {
		t.Fatal(err)
	}

	items := call(t, app, http.MethodGet, "/items", nil)
	data, ok := items["data"].([]any)
	if !ok || len(data) < 3 {
		t.Fatalf("expected seeded wardrobe, got %#v", items)
	}

	generated := call(t, app, http.MethodPost, "/ai/outfits/generate", map[string]any{"scene": "通勤", "season": "秋", "weather": "晴", "temperature": "24", "preferredStyle": "极简"})
	candidates := generated["data"].([]any)
	if len(candidates) != 3 {
		t.Fatalf("expected three candidates, got %d", len(candidates))
	}
	first := candidates[0].(map[string]any)
	saved := call(t, app, http.MethodPost, "/ai/outfits/save", map[string]any{"name": first["name"], "itemIds": first["itemIds"], "scene": first["scene"], "style": first["style"], "season": first["season"], "reason": first["reason"]})
	outfit := saved["data"].(map[string]any)
	call(t, app, http.MethodPost, "/wear-logs", map[string]any{"outfitId": outfit["id"], "wearDate": "2026-08-24", "weather": "晴", "temperature": "24", "scene": "通勤", "note": "舒适"})
	logs := call(t, app, http.MethodGet, "/wear-logs?month=2026-08", nil)
	if len(logs["data"].([]any)) != 1 {
		t.Fatal("wear log was not persisted")
	}
}

func call(t *testing.T, app *App, method, path string, body any) map[string]any {
	t.Helper()
	var payload []byte
	if body != nil {
		payload, _ = json.Marshal(body)
	}
	req := httptest.NewRequest(method, path, bytes.NewReader(payload))
	req.Header.Set("Content-Type", "application/json")
	res := httptest.NewRecorder()
	app.engine.ServeHTTP(res, req)
	if res.Code >= 400 {
		t.Fatalf("%s %s returned %d: %s", method, path, res.Code, res.Body.String())
	}
	var decoded map[string]any
	if err := json.Unmarshal(res.Body.Bytes(), &decoded); err != nil {
		t.Fatal(err)
	}
	return decoded
}
