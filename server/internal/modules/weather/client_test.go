package weather

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

const valid = `{"timezone":"Asia/Shanghai","current":{"time":"2026-10-05T12:00","temperature_2m":24.5,"apparent_temperature":25.1,"weather_code":63,"wind_speed_10m":10},"daily":{"time":["2026-10-05"],"temperature_2m_min":[18],"temperature_2m_max":[26]}}`

func TestFetch(t *testing.T) {
	body, status := valid, 200
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Query().Get("latitude") != "31.230" || r.URL.Query().Get("timezone") != "auto" || r.URL.Query().Get("forecast_days") != "1" {
			t.Error("wrong weather query")
		}
		w.WriteHeader(status)
		w.Write([]byte(body))
	}))
	defer server.Close()
	client := New(server.URL)
	client.Now = func() time.Time { return time.Date(2026, 10, 5, 4, 0, 0, 0, time.UTC) }
	result, err := client.Fetch(context.Background(), 31.2301, 121.4737)
	if err != nil || result.Weather != "雨" || result.Temperature != 24.5 || result.Minimum != 18 || result.Maximum != 26 || result.Date != "2026-10-05" || result.Longitude != 121.474 {
		t.Fatalf("%+v %v", result, err)
	}
	for _, bad := range []string{`{}`, `{"error":true}`, `not json`, strings.Replace(valid, `"weather_code":63`, `"weather_code":100`, 1), strings.Replace(valid, `"temperature_2m":24.5`, `"temperature_2m":null`, 1), strings.Replace(valid, `"2026-10-05T12:00"`, `"2026-10-04T12:00"`, 1)} {
		body = bad
		if _, err := client.Fetch(context.Background(), 31.2301, 121.4737); err == nil {
			t.Fatal("accepted incomplete weather")
		}
	}
	body = valid
	client.Now = func() time.Time { return time.Date(2026, 10, 6, 4, 0, 0, 0, time.UTC) }
	if _, err := client.Fetch(context.Background(), 31.2301, 121.4737); err == nil {
		t.Fatal("accepted yesterday weather")
	}
	client.Now = func() time.Time { return time.Date(2026, 10, 5, 8, 0, 0, 0, time.UTC) }
	if _, err := client.Fetch(context.Background(), 31.2301, 121.4737); err == nil {
		t.Fatal("accepted stale current conditions")
	}
	status = 503
	if _, err := client.Fetch(context.Background(), 31.2301, 121.4737); err == nil {
		t.Fatal("ignored provider failure")
	}
	if _, err := client.Fetch(context.Background(), 91, 0); err == nil {
		t.Fatal("accepted invalid location")
	}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if _, err := client.Fetch(ctx, 31.2301, 121.4737); err == nil {
		t.Fatal("ignored cancellation")
	}
}
func TestWeatherCodes(t *testing.T) {
	for _, code := range []int{0, 1, 2, 3, 45, 48, 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 71, 73, 75, 77, 80, 81, 82, 85, 86, 95, 96, 99} {
		if Description(code) == "" {
			t.Fatalf("missing code %d", code)
		}
	}
	if Description(100) != "" {
		t.Fatal("invented weather")
	}
}
