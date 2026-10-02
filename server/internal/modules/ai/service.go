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

func (service *Service) GenerateOutfits(userID string, input OutfitInput) ([]OutfitCandidate, error) {
	items, err := service.availableItems(userID)
	if err != nil {
		return nil, err
	}
	if len(items) < 2 {
		return nil, fmt.Errorf("current wearable items are insufficient")
	}

	input.Items = items
	task, err := service.createTask(userID, "outfit_generation", input)
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

func (service *Service) GenerateToday(userID string, input TodayInput) ([]OutfitCandidate, error) {
	items, err := service.availableItems(userID)
	if err != nil {
		return nil, err
	}

	input.Items = items
	task, err := service.createTask(userID, "today_recommendation", input)
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

func (service *Service) SaveGeneratedOutfit(userID string, candidate OutfitCandidate) (*models.Outfit, error) {
	if len(candidate.ItemIDs) == 0 {
		return nil, fmt.Errorf("outfit must contain at least one item")
	}
	var count int64
	if err := service.db.Model(&models.Item{}).Where("id IN ? AND user_id = ? AND management_status = ? AND wearable_status = ?", candidate.ItemIDs, userID, "normal", "wearable").Count(&count).Error; err != nil || count != int64(len(candidate.ItemIDs)) {
		return nil, fmt.Errorf("outfit contains unavailable items")
	}
	now := time.Now()
	itemIDs, _ := json.Marshal(candidate.ItemIDs)

	outfit := &models.Outfit{
		ID:        fmt.Sprintf("outfit_%d", time.Now().UnixNano()),
		UserID:    userID,
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

func (service *Service) ReplaceItem(userID string, itemIDs []string, itemID string) (*OutfitCandidate, error) {
	if len(itemIDs) == 0 {
		return nil, fmt.Errorf("empty outfit")
	}
	var current models.Item
	if service.db.First(&current, "id = ? AND user_id = ?", itemID, userID).Error != nil {
		return nil, fmt.Errorf("item not found")
	}
	var replacement models.Item
	err := service.db.Where("user_id = ? AND category_level1 = ? AND id <> ? AND management_status = ? AND wearable_status = ?", userID, current.CategoryLevel1, itemID, "normal", "wearable").Order("updated_at desc").First(&replacement).Error
	if err != nil {
		return nil, fmt.Errorf("暂无合适的替换单品")
	}
	next := append([]string(nil), itemIDs...)
	found := false
	for i, id := range next {
		if id == itemID {
			next[i] = replacement.ID
			found = true
			break
		}
	}
	if !found {
		return nil, fmt.Errorf("item is not in outfit")
	}
	return &OutfitCandidate{Name: "局部焕新方案", ItemIDs: next, Reason: "已保留其余单品，并替换为衣橱中同品类的可穿单品。"}, nil
}

func (service *Service) availableItems(userID string) ([]models.Item, error) {
	var items []models.Item
	err := service.db.
		Where("user_id = ? AND management_status = ? AND wearable_status = ?", userID, "normal", "wearable").
		Order("created_at desc").
		Find(&items).Error

	return items, err
}

func (service *Service) createTask(userID string, taskType string, payload any) (*models.AITask, error) {
	requestPayload, _ := json.Marshal(payload)
	now := time.Now()

	task := &models.AITask{
		ID:             fmt.Sprintf("task_%d", time.Now().UnixNano()),
		UserID:         userID,
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
