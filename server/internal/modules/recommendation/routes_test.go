package recommendation

import (
	"ai-closet-server/internal/infrastructure/database"
	"ai-closet-server/internal/models"
	"ai-closet-server/internal/modules/ai"
	"ai-closet-server/internal/modules/auth"
	"ai-closet-server/internal/modules/weather"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"github.com/gin-gonic/gin"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

type testWeather struct {
	fail  bool
	calls int
}

func (p *testWeather) Fetch(_ context.Context, lat, lon float64) (weather.Snapshot, error) {
	p.calls++
	if p.fail {
		return weather.Snapshot{}, fmt.Errorf("offline")
	}
	return weather.Snapshot{Latitude: lat, Longitude: lon, Date: "2026-10-05", Timezone: "Asia/Shanghai", Weather: "雨", Temperature: 18, FeelsLike: 17, Minimum: 15, Maximum: 20, Wind: 12}, nil
}

type testAI struct {
	input ai.TodayInput
	calls int
}

func (p *testAI) GenerateToday(input ai.TodayInput) ([]ai.OutfitCandidate, error) {
	p.calls++
	p.input = input
	return []ai.OutfitCandidate{{Name: "雨天搭配", ItemIDs: []string{"owner-item"}, Scene: input.Scene}}, nil
}
func TestTodayUsesLocationWeatherAndRejectsManualWeather(t *testing.T) {
	db, err := database.Open(":memory:")
	if err != nil {
		t.Fatal(err)
	}
	sqlDB, _ := db.DB()
	defer sqlDB.Close()
	if err := database.AutoMigrate(db); err != nil {
		t.Fatal(err)
	}
	for _, id := range []string{"owner", "other"} {
		if err := db.Create(&models.User{ID: id, Email: id + "@example.com"}).Error; err != nil {
			t.Fatal(err)
		}
		if err := db.Create(&models.Item{ID: id + "-item", UserID: id, ManagementStatus: "normal", WearableStatus: "wearable"}).Error; err != nil {
			t.Fatal(err)
		}
	}
	if err := db.Create(&models.Session{ID: "session", UserID: "owner", Token: "owner", ExpiresAt: time.Now().Add(time.Hour)}).Error; err != nil {
		t.Fatal(err)
	}
	weatherProvider, provider := &testWeather{}, &testAI{}
	router := gin.New()
	router.Use(auth.RequireAuth(db))
	RegisterRoutes(router, ai.NewService(db, provider), weatherProvider)
	call := func(path, token, body string, want int) *httptest.ResponseRecorder {
		t.Helper()
		req := httptest.NewRequest("POST", path, bytes.NewBufferString(body))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+token)
		out := httptest.NewRecorder()
		router.ServeHTTP(out, req)
		if out.Code != want {
			t.Fatalf("%d %s", out.Code, out.Body.String())
		}
		return out
	}
	path := "/ai/today-recommendation/generate"
	call(path, "", `{"scene":"通勤","latitude":0,"longitude":0}`, 401)
	for _, body := range []string{`{"scene":"通勤","weather":"晴","temperature":"24"}`, `{"scene":"通勤","latitude":91,"longitude":0}`, `{"scene":"通勤","latitude":0,"longitude":181}`, `{"scene":"通勤","latitude":null,"longitude":0}`} {
		call(path, "owner", body, 400)
	}
	if weatherProvider.calls != 0 || provider.calls != 0 {
		t.Fatal("invalid requests reached providers")
	}
	result := call(path, "owner", `{"scene":"通勤","latitude":0,"longitude":0,"weather":"雪","temperature":"100"}`, 200)
	var response struct {
		Data struct {
			Candidates []ai.OutfitCandidate `json:"candidates"`
			Weather    weather.Snapshot     `json:"weather"`
		} `json:"data"`
	}
	if err := json.Unmarshal(result.Body.Bytes(), &response); err != nil {
		t.Fatal(err)
	}
	if response.Data.Weather.Weather != "雨" || len(response.Data.Candidates) != 1 || provider.input.Weather != "雨" || !strings.Contains(provider.input.Temperature, "15.0–20.0") || provider.input.Date != "2026-10-05" || len(provider.input.Items) != 1 || provider.input.Items[0].UserID != "owner" {
		t.Fatalf("wrong AI context: %+v", provider.input)
	}
	weatherProvider.fail = true
	call(path, "owner", `{"scene":"通勤","latitude":1,"longitude":1}`, 502)
	if provider.calls != 1 {
		t.Fatal("AI called after weather failure")
	}
	call("/ai/outfits/generate", "owner", `{}`, 404)
}
