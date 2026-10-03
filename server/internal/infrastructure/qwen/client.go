package qwen

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

type Client struct {
	BaseURL, APIKey, Model string
	HTTP                   *http.Client
}

func New(baseURL, key, model string) *Client {
	return &Client{BaseURL: strings.TrimRight(baseURL, "/"), APIKey: key, Model: model,
		HTTP: &http.Client{Timeout: 120 * time.Second}}
}

// CompleteJSON uses Alibaba Cloud's compatible chat API, with server-side credentials.
func (c *Client) CompleteJSON(ctx context.Context, prompt, imageURL string, target any) error {
	if c.APIKey == "" || c.Model == "" || c.BaseURL == "" {
		return fmt.Errorf("请配置 DASHSCOPE_API_KEY 和 Qwen 模型")
	}
	var content any = prompt
	if imageURL != "" {
		content = []map[string]any{
			{"type": "text", "text": prompt},
			{"type": "image_url", "image_url": map[string]string{"url": imageURL}},
		}
	}
	body, err := json.Marshal(map[string]any{
		"model": c.Model, "messages": []map[string]any{{"role": "user", "content": content}},
		"response_format": map[string]string{"type": "json_object"}, "stream": false,
		"max_tokens": 4096, "enable_thinking": false,
	})
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.BaseURL+"/chat/completions", bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("模型接口地址不合法")
	}
	req.Header.Set("Authorization", "Bearer "+c.APIKey)
	req.Header.Set("Content-Type", "application/json")
	resp, err := c.HTTP.Do(req)
	if err != nil {
		return fmt.Errorf("Qwen 服务连接失败，请检查网络或稍后重试")
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("Qwen 服务返回 HTTP %d，请检查凭据、模型权限和额度", resp.StatusCode)
	}
	var envelope struct {
		Choices []struct {
			FinishReason string `json:"finish_reason"`
			Message      struct {
				Content string `json:"content"`
			} `json:"message"`
		} `json:"choices"`
	}
	if json.NewDecoder(io.LimitReader(resp.Body, 1<<20)).Decode(&envelope) != nil || len(envelope.Choices) == 0 {
		return fmt.Errorf("Qwen 返回内容无效")
	}
	if envelope.Choices[0].FinishReason == "length" {
		return fmt.Errorf("Qwen 返回被截断，请重试")
	}
	if err := json.Unmarshal([]byte(envelope.Choices[0].Message.Content), target); err != nil {
		return fmt.Errorf("Qwen 返回的结构化 JSON 无效，请重试")
	}
	return nil
}
