package recommendation

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"ai-closet-server/internal/httpapi"
	"ai-closet-server/internal/modules/ai"
)

type generateOutfitsRequest struct {
	Scene          string `json:"scene" binding:"required"`
	Season         string `json:"season" binding:"required"`
	Weather        string `json:"weather" binding:"required"`
	Temperature    string `json:"temperature" binding:"required"`
	PreferredStyle string `json:"preferredStyle" binding:"required"`
}

type saveOutfitRequest struct {
	Name   string   `json:"name" binding:"required"`
	ItemIDs []string `json:"itemIds" binding:"required"`
	Scene  string   `json:"scene" binding:"required"`
	Style  string   `json:"style" binding:"required"`
	Season string   `json:"season" binding:"required"`
	Reason string   `json:"reason" binding:"required"`
}

type todayRecommendationRequest struct {
	Weather     string `json:"weather" binding:"required"`
	Temperature string `json:"temperature" binding:"required"`
	Scene       string `json:"scene" binding:"required"`
}

func RegisterRoutes(router *gin.Engine, service *ai.Service) {
	router.POST("/ai/outfits/generate", func(c *gin.Context) {
		var req generateOutfitsRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			httpapi.Error(c, http.StatusBadRequest, "INVALID_REQUEST", "请求参数不合法")
			return
		}

		result, err := service.GenerateOutfits(ai.OutfitInput{
			Scene:          req.Scene,
			Season:         req.Season,
			Weather:        req.Weather,
			Temperature:    req.Temperature,
			PreferredStyle: req.PreferredStyle,
		})
		if err != nil {
			httpapi.Error(c, http.StatusBadGateway, "AI_GENERATION_FAILED", err.Error())
			return
		}

		httpapi.OK(c, result)
	})

	router.POST("/ai/outfits/save", func(c *gin.Context) {
		var req saveOutfitRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			httpapi.Error(c, http.StatusBadRequest, "INVALID_REQUEST", "请求参数不合法")
			return
		}

		result, err := service.SaveGeneratedOutfit(ai.OutfitCandidate{
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

		result, err := service.GenerateToday(ai.TodayInput{
			Weather:     req.Weather,
			Temperature: req.Temperature,
			Scene:       req.Scene,
		})
		if err != nil {
			httpapi.Error(c, http.StatusBadGateway, "TODAY_RECOMMENDATION_FAILED", err.Error())
			return
		}

		httpapi.OK(c, result)
	})
}
