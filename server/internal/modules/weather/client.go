package weather

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math"
	"net/http"
	"net/url"
	"regexp"
	"strconv"
	"strings"
	"time"
)

var ErrNotConfigured = errors.New("AMap Web service key is not configured")
var adcodePattern = regexp.MustCompile(`^[1-9][0-9]{5}$`)

// Snapshot contains only measurements supplied by AMap, never estimated substitutes.
type Snapshot struct {
	Latitude         float64 `json:"latitude"`
	Longitude        float64 `json:"longitude"`
	Time             string  `json:"time"`
	Date             string  `json:"date"`
	Timezone         string  `json:"timezone"`
	Source           string  `json:"source"`
	City             string  `json:"city"`
	Adcode           string  `json:"adcode"`
	Weather          string  `json:"weather"`
	Temperature      float64 `json:"temperature"`
	DayTemperature   float64 `json:"dayTemperature"`
	NightTemperature float64 `json:"nightTemperature"`
	WindDirection    string  `json:"windDirection"`
	WindPower        string  `json:"windPower"`
}

func (s Snapshot) TemperatureSummary() string {
	return fmt.Sprintf("当前 %.1f°C，日间预报 %.1f°C，夜间预报 %.1f°C，风向 %s，风力 %s级", s.Temperature, s.DayTemperature, s.NightTemperature, s.WindDirection, s.WindPower)
}

type Client struct {
	BaseURL string
	APIKey  string
	HTTP    *http.Client
	Now     func() time.Time
}

func New(baseURL, apiKey string) *Client {
	return &Client{BaseURL: baseURL, APIKey: apiKey, HTTP: &http.Client{Timeout: 10 * time.Second}}
}

func (client *Client) Fetch(ctx context.Context, lat, lon float64) (Snapshot, error) {
	if !validCoordinates(lat, lon) {
		return Snapshot{}, errors.New("invalid coordinates")
	}
	if strings.TrimSpace(client.APIKey) == "" {
		return Snapshot{}, ErrNotConfigured
	}
	// Bound the entire conversion/geocoding/weather pipeline, not just each request.
	ctx, cancel := context.WithTimeout(ctx, 20*time.Second)
	defer cancel()
	lat, lon = math.Round(lat*1000)/1000, math.Round(lon*1000)/1000
	adcode, err := client.resolveAdcode(ctx, lat, lon)
	if err != nil {
		return Snapshot{}, err
	}
	var current liveResponse
	if err := client.get(ctx, "/v3/weather/weatherInfo", url.Values{"city": {adcode}, "extensions": {"base"}}, &current); err != nil {
		return Snapshot{}, err
	}
	var forecast forecastResponse
	if err := client.get(ctx, "/v3/weather/weatherInfo", url.Values{"city": {adcode}, "extensions": {"all"}}, &forecast); err != nil {
		return Snapshot{}, err
	}
	now := time.Now()
	if client.Now != nil {
		now = client.Now()
	}
	return parseSnapshot(current, forecast, adcode, lat, lon, now)
}

func validCoordinates(lat, lon float64) bool {
	return !math.IsNaN(lat) && !math.IsInf(lat, 0) && !math.IsNaN(lon) && !math.IsInf(lon, 0) && lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180
}

func (client *Client) resolveAdcode(ctx context.Context, lat, lon float64) (string, error) {
	var converted struct {
		Locations string `json:"locations"`
	}
	location := fmt.Sprintf("%.3f,%.3f", lon, lat)
	if err := client.get(ctx, "/v3/assistant/coordinate/convert", url.Values{"locations": {location}, "coordsys": {"gps"}}, &converted); err != nil {
		return "", err
	}
	parts := strings.Split(converted.Locations, ",")
	if len(parts) != 2 {
		return "", errors.New("invalid AMap converted coordinates")
	}
	convertedLon, lonErr := strconv.ParseFloat(parts[0], 64)
	convertedLat, latErr := strconv.ParseFloat(parts[1], 64)
	if lonErr != nil || latErr != nil || !validCoordinates(convertedLat, convertedLon) {
		return "", errors.New("invalid AMap converted coordinates")
	}
	var address struct {
		Regeocode struct {
			AddressComponent struct {
				Adcode string `json:"adcode"`
			} `json:"addressComponent"`
		} `json:"regeocode"`
	}
	if err := client.get(ctx, "/v3/geocode/regeo", url.Values{"location": {fmt.Sprintf("%.3f,%.3f", convertedLon, convertedLat)}, "extensions": {"base"}}, &address); err != nil {
		return "", err
	}
	adcode := address.Regeocode.AddressComponent.Adcode
	if !adcodePattern.MatchString(adcode) {
		return "", errors.New("AMap has no weather region for this location")
	}
	return adcode, nil
}

// Never include request URLs, keys, upstream messages or transport errors in errors.
func (client *Client) get(ctx context.Context, path string, params url.Values, target any) error {
	endpoint, err := url.Parse(client.BaseURL)
	if err != nil || endpoint.Host == "" || (endpoint.Scheme != "http" && endpoint.Scheme != "https") || endpoint.RawQuery != "" || endpoint.User != nil || endpoint.Fragment != "" {
		return errors.New("invalid AMap endpoint configuration")
	}
	endpoint.Path = strings.TrimRight(endpoint.Path, "/") + path
	params.Set("key", client.APIKey)
	params.Set("output", "JSON")
	endpoint.RawQuery = params.Encode()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint.String(), nil)
	if err != nil {
		return errors.New("invalid AMap request")
	}
	// A redirect must not forward the Web service key to another host.
	httpClient := *client.HTTP
	httpClient.CheckRedirect = func(_ *http.Request, _ []*http.Request) error { return http.ErrUseLastResponse }
	response, err := httpClient.Do(req)
	if err != nil {
		return errors.New("AMap request failed")
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return errors.New("AMap service unavailable")
	}
	body, err := io.ReadAll(io.LimitReader(response.Body, (1<<20)+1))
	if err != nil || len(body) > 1<<20 {
		return errors.New("invalid AMap response")
	}
	var status struct {
		Status   string `json:"status"`
		Infocode string `json:"infocode"`
	}
	if json.Unmarshal(body, &status) != nil {
		return errors.New("invalid AMap response")
	}
	if status.Status != "1" || status.Infocode != "10000" {
		return errors.New("AMap rejected the request; check service permissions and quota")
	}
	if json.Unmarshal(body, target) != nil {
		return errors.New("invalid AMap response fields")
	}
	return nil
}
