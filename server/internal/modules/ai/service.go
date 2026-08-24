package ai

import (
	"encoding/json"
	"fmt"
	"time"

	"gorm.io/gorm"

	"ai-closet-server/internal/models"
)

type Service struct {
	db       *gorm.DB
	provider Provider
}

func NewService(db *gorm.DB, provider Provider) *Service {
	return &Service{
		db:       db,
		provider: provider,
	}
}

func (service *Service) GenerateOutfits(input OutfitInput) ([]OutfitCandidate, error) {
	items, err := service.availableItems()
	if err != nil {
		return nil, err
	}
	if len(items) < 2 {
		return nil, fmt.Errorf("current wearable items are insufficient")
	}

	input.Items = items
	task, err := service.createTask("outfit_generation", input)
	if err != nil {
		return nil, err
	}

	candidates, err := service.provider.GenerateOutfits(input)
	if err != nil {
		service.failTask(task, err)
		return nil, err
	}

	service.completeTask(task, candidates)
	return candidates, nil
}

func (service *Service) GenerateToday(input TodayInput) ([]OutfitCandidate, error) {
	items, err := service.availableItems()
	if err != nil {
		return nil, err
	}

	input.Items = items
	task, err := service.createTask("today_recommendation", input)
	if err != nil {
		return nil, err
	}

	candidates, err := service.provider.GenerateToday(input)
	if err != nil {
		service.failTask(task, err)
		return nil, err
	}

	service.completeTask(task, candidates)
	return candidates, nil
}

func (service *Service) SaveGeneratedOutfit(candidate OutfitCandidate) (*models.Outfit, error) {
	now := time.Now()
	itemIDs, _ := json.Marshal(candidate.ItemIDs)

	outfit := &models.Outfit{
		ID:        fmt.Sprintf("outfit_%d", time.Now().UnixNano()),
		UserID:    "user_demo",
		Name:      candidate.Name,
		Scene:     candidate.Scene,
		Style:     candidate.Style,
		Season:    candidate.Season,
		Source:    "ai",
		AIReason:  candidate.Reason,
		ItemIDs:   string(itemIDs),
		CreatedAt: now,
		UpdatedAt: now,
	}

	if err := service.db.Create(outfit).Error; err != nil {
		return nil, err
	}

	return outfit, nil
}

func (service *Service) availableItems() ([]models.Item, error) {
	var items []models.Item
	err := service.db.
		Where("management_status = ? AND wearable_status = ?", "normal", "wearable").
		Order("created_at desc").
		Find(&items).Error

	return items, err
}

func (service *Service) createTask(taskType string, payload any) (*models.AITask, error) {
	requestPayload, _ := json.Marshal(payload)
	now := time.Now()

	task := &models.AITask{
		ID:             fmt.Sprintf("task_%d", time.Now().UnixNano()),
		UserID:         "user_demo",
		TaskType:       taskType,
		Status:         "processing",
		RequestPayload: string(requestPayload),
		CreatedAt:      now,
		UpdatedAt:      now,
	}

	return task, service.db.Create(task).Error
}

func (service *Service) completeTask(task *models.AITask, payload any) {
	resultPayload, _ := json.Marshal(payload)
	task.Status = "success"
	task.ResultPayload = string(resultPayload)
	task.UpdatedAt = time.Now()
	_ = service.db.Save(task).Error
}

func (service *Service) failTask(task *models.AITask, failure error) {
	task.Status = "failed"
	task.ErrorMessage = failure.Error()
	task.UpdatedAt = time.Now()
	_ = service.db.Save(task).Error
}
