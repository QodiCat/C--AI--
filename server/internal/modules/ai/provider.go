package ai

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"ai-closet-server/internal/config"
	"ai-closet-server/internal/infrastructure/qwen"
	"ai-closet-server/internal/models"
)

type OutfitCandidate struct {
	Name    string   `json:"name"`
	ItemIDs []string `json:"itemIds"`
	Scene   string   `json:"scene"`
	Style   string   `json:"style"`
	Season  string   `json:"season"`
	Reason  string   `json:"reason"`
}

type TodayInput struct {
	Location    string
	Date        string
	Weather     string
	Temperature string
	Scene       string
	Items       []models.Item
}

type Provider interface {
	GenerateToday(input TodayInput) ([]OutfitCandidate, error)
}

func NewProvider(cfg config.Config) Provider {
	if cfg.AIProvider == "qwen" {
		return QwenProvider{Client: qwen.New(cfg.QwenBaseURL, cfg.DashScopeAPIKey, cfg.QwenTextModel)}
	}
	if cfg.AIProvider == "mock" {
		return MockProvider{}
	}

	return HTTPProvider{
		BaseURL: cfg.AIAPIBaseURL,
		APIKey:  cfg.AIAPIKey,
		Client: &http.Client{
			Timeout: 120 * time.Second,
		},
	}
}

type MockProvider struct{}

func (MockProvider) GenerateToday(input TodayInput) ([]OutfitCandidate, error) {
	return buildCandidates(input.Scene, "当季", "今日推荐", input.Temperature, input.Items), nil
}

type HTTPProvider struct {
	BaseURL string
	APIKey  string
	Client  *http.Client
}

func (provider HTTPProvider) GenerateToday(input TodayInput) ([]OutfitCandidate, error) {
	requestBody := map[string]any{
		"scene":       input.Scene,
		"location":    input.Location,
		"date":        input.Date,
		"weather":     input.Weather,
		"temperature": input.Temperature,
		"items":       input.Items,
	}

	return provider.post("/today-recommendation/generate", requestBody)
}

func (provider HTTPProvider) post(path string, body map[string]any) ([]OutfitCandidate, error) {
	if provider.BaseURL == "" || provider.APIKey == "" {
		return nil, fmt.Errorf("external ai provider is not configured")
	}

	payload, err := json.Marshal(body)
	if err != nil {
		return nil, err
	}

	request, err := http.NewRequest(http.MethodPost, provider.BaseURL+path, bytes.NewReader(payload))
	if err != nil {
		return nil, err
	}

	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Authorization", "Bearer "+provider.APIKey)

	response, err := provider.Client.Do(request)
	if err != nil {
		return nil, err
	}
	defer response.Body.Close()

	if response.StatusCode >= 300 {
		return nil, fmt.Errorf("external ai returned status %d", response.StatusCode)
	}

	var result struct {
		Data []OutfitCandidate `json:"data"`
	}
	if err := json.NewDecoder(response.Body).Decode(&result); err != nil {
		return nil, err
	}

	return result.Data, nil
}

func buildCandidates(scene string, season string, style string, temperature string, items []models.Item) []OutfitCandidate {
	itemIDs := make([]string, 0, len(items))
	for index, item := range items {
		if index >= 3 {
			break
		}
		itemIDs = append(itemIDs, item.ID)
	}

	result := make([]OutfitCandidate, 0, 3)
	for index := 1; index <= 3; index++ {
		result = append(result, OutfitCandidate{
			Name:    fmt.Sprintf("%s方案 %d", style, index),
			ItemIDs: itemIDs,
			Scene:   scene,
			Style:   style,
			Season:  season,
			Reason:  fmt.Sprintf("基于当前%s场景与%s度温度，优先使用现有可穿单品，保证实穿性和风格统一。", scene, temperature),
		})
	}

	return result
}
