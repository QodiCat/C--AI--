package weather

import (
	"errors"
	"math"
	"strconv"
	"strings"
	"time"
)

type liveResponse struct {
	Lives []struct {
		Adcode        string `json:"adcode"`
		City          string `json:"city"`
		Weather       string `json:"weather"`
		Temperature   string `json:"temperature"`
		WindDirection string `json:"winddirection"`
		WindPower     string `json:"windpower"`
		ReportTime    string `json:"reporttime"`
	} `json:"lives"`
}

type forecastResponse struct {
	Forecasts []struct {
		Adcode     string `json:"adcode"`
		ReportTime string `json:"reporttime"`
		Casts      []struct {
			Date      string `json:"date"`
			DayTemp   string `json:"daytemp"`
			NightTemp string `json:"nighttemp"`
		} `json:"casts"`
	} `json:"forecasts"`
}

func parseSnapshot(live liveResponse, forecast forecastResponse, adcode string, lat, lon float64, now time.Time) (Snapshot, error) {
	if len(live.Lives) != 1 || len(forecast.Forecasts) != 1 {
		return Snapshot{}, errors.New("incomplete AMap weather response")
	}
	current, daily := live.Lives[0], forecast.Forecasts[0]
	if current.Adcode != adcode || daily.Adcode != adcode || strings.TrimSpace(current.City) == "" || strings.TrimSpace(current.Weather) == "" || strings.TrimSpace(current.WindPower) == "" || strings.TrimSpace(current.WindDirection) == "" {
		return Snapshot{}, errors.New("invalid AMap weather region or fields")
	}
	// AMap timestamps are China standard time, independent of server timezone.
	zone := time.FixedZone("Asia/Shanghai", 8*3600)
	observed, err := time.ParseInLocation("2006-01-02 15:04:05", current.ReportTime, zone)
	if err != nil || now.Sub(observed) > 3*time.Hour || observed.Sub(now) > 30*time.Minute {
		return Snapshot{}, errors.New("stale AMap current weather")
	}
	published, err := time.ParseInLocation("2006-01-02 15:04:05", daily.ReportTime, zone)
	// The first forecast update is around 08:00; yesterday's publication can
	// still contain today's cast. Validate publication age and cast date separately.
	if err != nil || now.Sub(published) > 24*time.Hour || published.Sub(now) > 30*time.Minute {
		return Snapshot{}, errors.New("stale AMap forecast")
	}
	temperature, err := parseTemperature(current.Temperature)
	if err != nil {
		return Snapshot{}, err
	}
	date := now.In(zone).Format("2006-01-02")
	for _, cast := range daily.Casts {
		if cast.Date != date {
			continue
		}
		day, err := parseTemperature(cast.DayTemp)
		if err != nil {
			return Snapshot{}, err
		}
		night, err := parseTemperature(cast.NightTemp)
		if err != nil {
			return Snapshot{}, err
		}
		return Snapshot{Latitude: lat, Longitude: lon, Time: observed.Format("2006-01-02T15:04:05"), Date: date, Timezone: "Asia/Shanghai", Source: "高德地图", City: current.City, Adcode: adcode, Weather: current.Weather, Temperature: temperature, DayTemperature: day, NightTemperature: night, WindDirection: current.WindDirection, WindPower: current.WindPower}, nil
	}
	return Snapshot{}, errors.New("AMap forecast has no weather for today")
}

func parseTemperature(value string) (float64, error) {
	result, err := strconv.ParseFloat(value, 64)
	if err != nil || math.IsNaN(result) || math.IsInf(result, 0) || result < -100 || result > 70 {
		return 0, errors.New("invalid AMap temperature")
	}
	return result, nil
}
