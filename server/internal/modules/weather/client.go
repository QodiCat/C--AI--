package weather

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"math"
	"net/http"
	"net/url"
	"strconv"
	"time"
)

type Snapshot struct {
	Latitude    float64 `json:"latitude"`
	Longitude   float64 `json:"longitude"`
	Time        string  `json:"time"`
	Date        string  `json:"date"`
	Timezone    string  `json:"timezone"`
	Weather     string  `json:"weather"`
	Temperature float64 `json:"temperature"`
	FeelsLike   float64 `json:"feelsLike"`
	Minimum     float64 `json:"minimum"`
	Maximum     float64 `json:"maximum"`
	Wind        float64 `json:"wind"`
}
type Client struct {
	BaseURL string
	HTTP    *http.Client
	Now     func() time.Time
}

func New(baseURL string) *Client {
	return &Client{BaseURL: baseURL, HTTP: &http.Client{Timeout: 15 * time.Second}}
}
func (client *Client) Fetch(ctx context.Context, lat, lon float64) (Snapshot, error) {
	if math.IsNaN(lat) || math.IsInf(lat, 0) || math.IsNaN(lon) || math.IsInf(lon, 0) || lat < -90 || lat > 90 || lon < -180 || lon > 180 {
		return Snapshot{}, fmt.Errorf("invalid coordinates")
	}
	endpoint, err := url.Parse(client.BaseURL)
	if err != nil {
		return Snapshot{}, err
	}
	q := endpoint.Query()
	q.Set("latitude", strconv.FormatFloat(lat, 'f', 3, 64))
	q.Set("longitude", strconv.FormatFloat(lon, 'f', 3, 64))
	q.Set("current", "temperature_2m,apparent_temperature,weather_code,wind_speed_10m")
	q.Set("daily", "temperature_2m_min,temperature_2m_max")
	q.Set("timezone", "auto")
	q.Set("forecast_days", "1")
	endpoint.RawQuery = q.Encode()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint.String(), nil)
	if err != nil {
		return Snapshot{}, err
	}
	response, err := client.HTTP.Do(req)
	if err != nil {
		return Snapshot{}, fmt.Errorf("weather request failed")
	}
	defer response.Body.Close()
	if response.StatusCode != 200 {
		return Snapshot{}, fmt.Errorf("weather service unavailable")
	}
	var data struct {
		Timezone string `json:"timezone"`
		Current  struct {
			Time        string   `json:"time"`
			Temperature *float64 `json:"temperature_2m"`
			FeelsLike   *float64 `json:"apparent_temperature"`
			Code        *int     `json:"weather_code"`
			Wind        *float64 `json:"wind_speed_10m"`
		} `json:"current"`
		Daily struct {
			Time    []string   `json:"time"`
			Minimum []*float64 `json:"temperature_2m_min"`
			Maximum []*float64 `json:"temperature_2m_max"`
		} `json:"daily"`
	}
	if json.NewDecoder(io.LimitReader(response.Body, 1<<20)).Decode(&data) != nil {
		return Snapshot{}, fmt.Errorf("invalid weather response")
	}
	c, d := data.Current, data.Daily
	if c.Temperature == nil || c.FeelsLike == nil || c.Code == nil || c.Wind == nil || len(d.Time) != 1 || len(d.Minimum) != 1 || len(d.Maximum) != 1 || d.Minimum[0] == nil || d.Maximum[0] == nil || data.Timezone == "" {
		return Snapshot{}, fmt.Errorf("incomplete weather response")
	}
	zone, zoneErr := time.LoadLocation(data.Timezone)
	if zoneErr != nil {
		return Snapshot{}, fmt.Errorf("invalid weather timezone")
	}
	observed, err := time.ParseInLocation("2006-01-02T15:04", c.Time, zone)
	if err != nil || observed.Format("2006-01-02") != d.Time[0] {
		return Snapshot{}, fmt.Errorf("invalid weather date")
	}
	now := time.Now()
	if client.Now != nil {
		now = client.Now()
	}
	if now.In(zone).Format("2006-01-02") != d.Time[0] || now.Sub(observed) > 3*time.Hour || observed.Sub(now) > 30*time.Minute {
		return Snapshot{}, fmt.Errorf("stale weather response")
	}
	label := Description(*c.Code)
	if label == "" {
		return Snapshot{}, fmt.Errorf("unsupported weather code")
	}
	return Snapshot{Latitude: math.Round(lat*1000) / 1000, Longitude: math.Round(lon*1000) / 1000, Time: c.Time, Date: d.Time[0], Timezone: data.Timezone, Weather: label, Temperature: *c.Temperature, FeelsLike: *c.FeelsLike, Minimum: *d.Minimum[0], Maximum: *d.Maximum[0], Wind: *c.Wind}, nil
}
func Description(code int) string {
	switch code {
	case 0:
		return "晴"
	case 1, 2:
		return "少云"
	case 3:
		return "阴"
	case 45, 48:
		return "雾"
	case 51, 53, 55:
		return "毛毛雨"
	case 56, 57, 66, 67:
		return "冻雨"
	case 61, 63, 65:
		return "雨"
	case 71, 73, 75, 77:
		return "雪"
	case 80, 81, 82:
		return "阵雨"
	case 85, 86:
		return "阵雪"
	case 95:
		return "雷雨"
	case 96, 99:
		return "雷雨伴冰雹"
	default:
		return ""
	}
}
