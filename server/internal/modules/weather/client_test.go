package weather

import (
	"context"
	"encoding/json"
	"errors"
	"math"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

const convertPath = "/v3/assistant/coordinate/convert"
const regeoPath = "/v3/geocode/regeo"
const weatherPath = "/v3/weather/weatherInfo"
const converted = `{"status":"1","infocode":"10000","locations":"121.478123,31.228456"}`
const address = `{"status":"1","infocode":"10000","regeocode":{"addressComponent":{"adcode":"310101","city":[],"province":"上海市"}}}`
const live = `{"status":"1","infocode":"10000","lives":[{"adcode":"310101","city":"黄浦区","weather":"小雨","temperature":"24.5","winddirection":"东南","windpower":"≤3","reporttime":"2026-11-08 12:00:00"}]}`
const forecast = `{"status":"1","infocode":"10000","forecasts":[{"adcode":"310101","reporttime":"2026-11-08 11:00:00","casts":[{"date":"2026-11-08","daytemp":"26","nighttemp":"18"},{"date":"2026-11-09","daytemp":"20","nighttemp":"15"}]}]}`

func now() time.Time { return time.Date(2026, 11, 8, 4, 0, 0, 0, time.UTC) }
func payload(path, extension string) string {
	switch path {
	case convertPath:
		return converted
	case regeoPath:
		return address
	case weatherPath:
		if extension == "base" {
			return live
		}
		return forecast
	}
	return `{}`
}

func TestFetchAMap(t *testing.T) {
	paths := []string{}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		paths = append(paths, r.URL.Path)
		q := r.URL.Query()
		if q.Get("key") != "test-key" || q.Get("output") != "JSON" {
			t.Error("missing AMap credentials or format")
		}
		switch r.URL.Path {
		case convertPath:
			if q.Get("locations") != "121.474,31.230" || q.Get("coordsys") != "gps" {
				t.Error("coordinates must be rounded and longitude first")
			}
		case regeoPath:
			if q.Get("location") != "121.478,31.228" || q.Get("extensions") != "base" {
				t.Error("regeo must use converted coordinates")
			}
		case weatherPath:
			if q.Get("city") != "310101" {
				t.Error("weather must use resolved adcode")
			}
		default:
			t.Error("unexpected request path")
		}
		w.Write([]byte(payload(r.URL.Path, q.Get("extensions"))))
	}))
	defer server.Close()
	client := New(server.URL, "test-key")
	client.Now = now
	result, err := client.Fetch(context.Background(), 31.2301, 121.4737)
	if err != nil {
		t.Fatal(err)
	}
	if len(paths) != 4 || result.Weather != "小雨" || result.Temperature != 24.5 || result.DayTemperature != 26 || result.NightTemperature != 18 || result.WindPower != "≤3" || result.City != "黄浦区" || result.Date != "2026-11-08" || result.Timezone != "Asia/Shanghai" || result.Source != "高德地图" || result.Longitude != 121.474 || result.Latitude != 31.23 {
		t.Fatalf("wrong snapshot: %+v", result)
	}
	raw, _ := json.Marshal(result)
	for _, absent := range []string{"feelsLike", "minimum", "maximum", `"wind":`, "test-key"} {
		if strings.Contains(string(raw), absent) {
			t.Fatal("invented unsupported measurement or exposed key")
		}
	}
	if strings.Contains(result.TemperatureSummary(), "体感") || strings.Contains(result.TemperatureSummary(), "km/h") {
		t.Fatal("AI summary invented measurements")
	}
}

func TestRejectsInvalidAMapResponses(t *testing.T) {
	cases := []struct {
		name, path, extension, body string
		status                      int
	}{
		{"invalid JSON", convertPath, "", "not json", 200},
		{"business error", convertPath, "", `{"status":"0","infocode":"10001","info":"test-key"}`, 200},
		{"invalid status", convertPath, "", strings.Replace(converted, `"status":"1"`, `"status":"0"`, 1), 200},
		{"HTTP error", convertPath, "", converted, 503},
		{"redirect", convertPath, "", converted, 302},
		{"oversized", convertPath, "", strings.Repeat(" ", 1<<20) + converted, 200},
		{"missing conversion", convertPath, "", `{"status":"1","infocode":"10000"}`, 200},
		{"invalid conversion", convertPath, "", strings.Replace(converted, "121.478123", "NaN", 1), 200},
		{"invalid converted range", convertPath, "", strings.Replace(converted, "31.228456", "91", 1), 200},
		{"invalid adcode", regeoPath, "", strings.Replace(address, "310101", "000000", 1), 200},
		{"missing adcode", regeoPath, "", strings.Replace(address, `"310101"`, `[]`, 1), 200},
		{"geocoding failure", regeoPath, "", `{"status":"0","infocode":"10003"}`, 200},
		{"live quota", weatherPath, "base", `{"status":"0","infocode":"10003"}`, 200},
		{"no live", weatherPath, "base", `{"status":"1","infocode":"10000","lives":[]}`, 200},
		{"live region mismatch", weatherPath, "base", strings.Replace(live, "310101", "110101", 1), 200},
		{"missing weather", weatherPath, "base", strings.Replace(live, "小雨", "", 1), 200},
		{"missing temperature", weatherPath, "base", strings.Replace(live, `"24.5"`, `""`, 1), 200},
		{"null temperature", weatherPath, "base", strings.Replace(live, `"24.5"`, `null`, 1), 200},
		{"bad temperature", weatherPath, "base", strings.Replace(live, "24.5", "NaN", 1), 200},
		{"temperature range", weatherPath, "base", strings.Replace(live, "24.5", "100", 1), 200},
		{"missing wind", weatherPath, "base", strings.Replace(live, "≤3", "", 1), 200},
		{"stale live", weatherPath, "base", strings.Replace(live, "12:00:00", "08:00:00", 1), 200},
		{"future live", weatherPath, "base", strings.Replace(live, "12:00:00", "13:00:00", 1), 200},
		{"invalid report date", weatherPath, "base", strings.Replace(live, "2026-11-08", "not-date", 1), 200},
		{"forecast failure", weatherPath, "all", `{"status":"0","infocode":"10003"}`, 200},
		{"no forecast", weatherPath, "all", `{"status":"1","infocode":"10000","forecasts":[]}`, 200},
		{"no today", weatherPath, "all", strings.Replace(forecast, "2026-11-08\",\"daytemp", "2026-11-07\",\"daytemp", 1), 200},
		{"bad day temp", weatherPath, "all", strings.Replace(forecast, `"26"`, `"invalid"`, 1), 200},
		{"bad night temp", weatherPath, "all", strings.Replace(forecast, `"18"`, `"Inf"`, 1), 200},
		{"forecast region mismatch", weatherPath, "all", strings.Replace(forecast, "310101", "110101", 1), 200},
		{"stale forecast", weatherPath, "all", strings.Replace(forecast, "2026-11-08 11:00", "2026-11-07 11:00", 1), 200},
		{"future forecast", weatherPath, "all", strings.Replace(forecast, "11:00:00", "13:00:00", 1), 200},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				if r.URL.Path == tc.path && (tc.extension == "" || r.URL.Query().Get("extensions") == tc.extension) {
					w.Header().Set("Location", "http://example.invalid/?key=test-key")
					w.WriteHeader(tc.status)
					w.Write([]byte(tc.body))
					return
				}
				w.Write([]byte(payload(r.URL.Path, r.URL.Query().Get("extensions"))))
			}))
			defer server.Close()
			client := New(server.URL, "test-key")
			client.Now = now
			if _, err := client.Fetch(context.Background(), 31.23, 121.47); err == nil {
				t.Fatal("accepted invalid weather")
			} else if strings.Contains(err.Error(), "test-key") || strings.Contains(err.Error(), "http") {
				t.Fatal("exposed upstream details")
			}
		})
	}
}

func TestAMapInputAndCancellation(t *testing.T) {
	calls := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { calls++; w.Write([]byte(converted)) }))
	defer server.Close()
	client := New(server.URL, "")
	if _, err := client.Fetch(context.Background(), 31, 121); !errors.Is(err, ErrNotConfigured) {
		t.Fatal("missing key not reported")
	}
	client.APIKey = "test-key"
	for _, coords := range [][2]float64{{91, 0}, {0, 181}, {math.NaN(), 0}, {0, math.Inf(1)}} {
		if _, err := client.Fetch(context.Background(), coords[0], coords[1]); err == nil {
			t.Fatal("accepted invalid input")
		}
	}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if _, err := client.Fetch(ctx, 31, 121); err == nil {
		t.Fatal("ignored cancellation")
	}
	if calls != 0 {
		t.Fatal("invalid requests reached AMap")
	}
	for _, base := range []string{"://invalid", "file:///tmp/key", "https://example.test?key=test-key"} {
		client.BaseURL = base
		if _, err := client.Fetch(context.Background(), 31, 121); err == nil || strings.Contains(err.Error(), "test-key") {
			t.Fatal("invalid endpoint or key exposure")
		}
	}
}

func TestAMapMidnightAndZeroTemperatures(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body := payload(r.URL.Path, r.URL.Query().Get("extensions"))
		body = strings.ReplaceAll(body, "2026-11-08 12:00:00", "2026-11-07 23:50:00")
		body = strings.ReplaceAll(body, "2026-11-08 11:00:00", "2026-11-07 18:00:00")
		body = strings.ReplaceAll(body, `"24.5"`, `"0"`)
		body = strings.ReplaceAll(body, `"18"`, `"-2"`)
		w.Write([]byte(body))
	}))
	defer server.Close()
	client := New(server.URL, "test-key")
	client.Now = func() time.Time { return time.Date(2026, 11, 7, 16, 5, 0, 0, time.UTC) }
	result, err := client.Fetch(context.Background(), 31, 121)
	if err != nil || result.Date != "2026-11-08" || result.Temperature != 0 || result.NightTemperature != -2 {
		t.Fatalf("midnight or zero weather rejected: %+v %v", result, err)
	}
}

func TestAMapRequestDeadline(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		<-r.Context().Done()
	}))
	defer server.Close()
	client := New(server.URL, "test-key")
	ctx, cancel := context.WithTimeout(context.Background(), 50*time.Millisecond)
	defer cancel()
	_, err := client.Fetch(ctx, 31, 121)
	if err == nil || ctx.Err() != context.DeadlineExceeded || strings.Contains(err.Error(), "test-key") {
		t.Fatal("request deadline not respected or transport details exposed")
	}
}
