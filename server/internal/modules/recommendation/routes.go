package recommendation

import (
	"ai-closet-server/internal/modules/weather"
	"context"
	"fmt"
	"math"
	"net/http"

	"github.com/gin-gonic/gin"

	"ai-closet-server/internal/httpapi"
	"ai-closet-server/internal/modules/ai"
	"ai-closet-server/internal/modules/auth"
)

type saveOutfitRequest struct {
	Name    string   `json:"name" binding:"required"`
	ItemIDs []string `json:"itemIds" binding:"required"`
	Scene   string   `json:"scene" binding:"required"`
	Style   string   `json:"style" binding:"required"`
	Season  string   `json:"season" binding:"required"`
	Reason  string   `json:"reason" binding:"required"`
}

type todayRecommendationRequest struct {
	Latitude  *float64 `json:"latitude" binding:"required"`
	Longitude *float64 `json:"longitude" binding:"required"`
	Scene     string   `json:"scene" binding:"required"`
}
type WeatherProvider interface {
	Fetch(context.Context, float64, float64) (weather.Snapshot, error)
}

type replaceItemRequest struct {
	ItemIDs []string `json:"itemIds" binding:"required,min=1"`
	ItemID  string   `json:"itemId" binding:"required"`
}
type feedbackRequest struct {
	CandidateName string `json:"candidateName" binding:"required"`
	Feedback      string `json:"feedback" binding:"required,oneof=like dislike"`
}

func RegisterRoutes(router *gin.Engine, service *ai.Service, weatherProvider WeatherProvider) {
	router.POST("/ai/outfits/save", func(c *gin.Context) {
		var req saveOutfitRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			httpapi.Error(c, http.StatusBadRequest, "INVALID_REQUEST", "请求参数不合法")
			return
		}

		result, err := service.SaveGeneratedOutfit(auth.CurrentUserID(c), ai.OutfitCandidate{
			Name:    req.Name,
			ItemIDs: req.ItemIDs,
			Scene:   req.Scene,
			Style:   req.Style,
			Season:  req.Season,
			Reason:  req.Reason,
		})
		if err != nil {
			httpapi.Error(c, http.StatusInternalServerError, "OUTFIT_SAVE_FAILED", "保存 AI 搭配失败")
			return
		}

		httpapi.OK(c, result)
	})

	router.POST("/ai/today-recommendation/generate", func(c *gin.Context) {
		var req todayRecommendationRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			httpapi.Error(c, http.StatusBadRequest, "INVALID_REQUEST", "请求参数不合法")
			return
		}

		lat, lon := *req.Latitude, *req.Longitude
		if math.IsNaN(lat) || math.IsNaN(lon) || lat < -90 || lat > 90 || lon < -180 || lon > 180 {
			httpapi.Error(c, 400, "INVALID_LOCATION", "当前位置不合法，请重新定位")
			return
		}
		conditions, err := weatherProvider.Fetch(c.Request.Context(), lat, lon)
		if err != nil {
			httpapi.Error(c, 502, "WEATHER_UNAVAILABLE", "获取当前位置天气失败，请重试")
			return
		}
		result, err := service.GenerateToday(auth.CurrentUserID(c), ai.TodayInput{
			Weather:     conditions.Weather,
			Temperature: fmt.Sprintf("当前 %.1f°C，体感 %.1f°C，今日 %.1f–%.1f°C，风速 %.1f km/h", conditions.Temperature, conditions.FeelsLike, conditions.Minimum, conditions.Maximum, conditions.Wind),
			Scene:       req.Scene,
			Location:    conditions.Timezone,
			Date:        conditions.Date,
		})
		if err != nil {
			httpapi.Error(c, http.StatusBadGateway, "TODAY_RECOMMENDATION_FAILED", err.Error())
			return
		}

		httpapi.OK(c, gin.H{"candidates": result, "weather": conditions})
	})

	router.POST("/ai/outfits/replace-item", func(c *gin.Context) {
		var req replaceItemRequest
		if c.ShouldBindJSON(&req) != nil {
			httpapi.Error(c, 400, "INVALID_REQUEST", "请求参数不合法")
			return
		}
		result, err := service.ReplaceItem(auth.CurrentUserID(c), req.ItemIDs, req.ItemID)
		if err != nil {
			httpapi.Error(c, 422, "NO_REPLACEMENT", err.Error())
			return
		}
		httpapi.OK(c, result)
	})
	router.POST("/ai/outfits/feedback", func(c *gin.Context) {
		var req feedbackRequest
		if c.ShouldBindJSON(&req) != nil {
			httpapi.Error(c, 400, "INVALID_REQUEST", "反馈参数不合法")
			return
		}
		if err := service.RecordFeedback(auth.CurrentUserID(c), req.CandidateName, req.Feedback); err != nil {
			httpapi.Error(c, 500, "FEEDBACK_SAVE_FAILED", "反馈保存失败")
			return
		}
		httpapi.OK(c, gin.H{"recorded": true, "feedback": req.Feedback})
	})
}
