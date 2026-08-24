package models

import "time"

type User struct {
	ID                 string    `gorm:"primaryKey" json:"id"`
	Nickname           string    `json:"nickname"`
	AvatarURL          string    `json:"avatarUrl"`
	LoginType          string    `json:"loginType"`
	City               string    `json:"city"`
	BodyType           string    `json:"bodyType"`
	Gender             string    `json:"gender"`
	AgeRange           string    `json:"ageRange"`
	Height             float64   `json:"height"`
	Weight             float64   `json:"weight"`
	StylePreferences   string    `json:"stylePreferences"`
	AllowModelTraining bool      `json:"allowModelTraining"`
	CreatedAt          time.Time `json:"createdAt"`
	UpdatedAt          time.Time `json:"updatedAt"`
}

type Item struct {
	ID               string    `gorm:"primaryKey" json:"id"`
	UserID           string    `gorm:"index" json:"userId"`
	Name             string    `json:"name"`
	CategoryLevel1   string    `json:"categoryLevel1"`
	CategoryLevel2   string    `json:"categoryLevel2"`
	PrimaryColor     string    `json:"primaryColor"`
	SecondaryColor   string    `json:"secondaryColor"`
	Pattern          string    `json:"pattern"`
	Brand            string    `json:"brand"`
	Size             string    `json:"size"`
	Seasons          string    `json:"seasons"`
	Styles           string    `json:"styles"`
	Scenes           string    `json:"scenes"`
	Material         string    `json:"material"`
	Fit              string    `json:"fit"`
	PurchasePrice    float64   `json:"purchasePrice"`
	PurchaseDate     string    `json:"purchaseDate"`
	CustomTags       string    `json:"customTags"`
	OriginalImageURL string    `json:"originalImageUrl"`
	CutoutImageURL   string    `json:"cutoutImageUrl"`
	ManagementStatus string    `json:"managementStatus"`
	WearableStatus   string    `json:"wearableStatus"`
	CreatedAt        time.Time `json:"createdAt"`
	UpdatedAt        time.Time `json:"updatedAt"`
}

type Outfit struct {
	ID          string    `gorm:"primaryKey" json:"id"`
	UserID      string    `gorm:"index" json:"userId"`
	Name        string    `json:"name"`
	Scene       string    `json:"scene"`
	Style       string    `json:"style"`
	Season      string    `json:"season"`
	Source      string    `json:"source"`
	AIReason    string    `json:"aiReason"`
	ItemIDs     string    `json:"itemIds"`
	Rating      int       `json:"rating"`
	Feedback    string    `json:"feedback"`
	Comfort     int       `json:"comfort"`
	Compliments int       `json:"compliments"`
	CreatedAt   time.Time `json:"createdAt"`
	UpdatedAt   time.Time `json:"updatedAt"`
}

type WearLog struct {
	ID          string    `gorm:"primaryKey" json:"id"`
	UserID      string    `gorm:"index" json:"userId"`
	OutfitID    string    `json:"outfitId"`
	WearDate    string    `json:"wearDate"`
	Weather     string    `json:"weather"`
	Temperature string    `json:"temperature"`
	Scene       string    `json:"scene"`
	PhotoURL    string    `json:"photoUrl"`
	Mood        string    `json:"mood"`
	Rating      int       `json:"rating"`
	Note        string    `json:"note"`
	CreatedAt   time.Time `json:"createdAt"`
}

type Session struct {
	ID        string    `gorm:"primaryKey" json:"id"`
	UserID    string    `gorm:"index" json:"userId"`
	Token     string    `gorm:"uniqueIndex" json:"token"`
	ExpiresAt time.Time `json:"expiresAt"`
	CreatedAt time.Time `json:"createdAt"`
}

type AITask struct {
	ID             string    `gorm:"primaryKey" json:"id"`
	UserID         string    `gorm:"index" json:"userId"`
	TaskType       string    `json:"taskType"`
	Status         string    `json:"status"`
	RequestPayload string    `json:"requestPayload"`
	ResultPayload  string    `json:"resultPayload"`
	ErrorMessage   string    `json:"errorMessage"`
	CreatedAt      time.Time `json:"createdAt"`
	UpdatedAt      time.Time `json:"updatedAt"`
}
