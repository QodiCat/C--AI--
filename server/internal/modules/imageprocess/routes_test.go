package imageprocess

import (
	"ai-closet-server/internal/config"
	"ai-closet-server/internal/infrastructure/database"
	"ai-closet-server/internal/models"
	"context"
	"encoding/json"
	"errors"
	"github.com/gin-gonic/gin"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

type testProcessor struct {
	failure bool
	release <-chan struct{}
}

func (p testProcessor) Ready() error { return nil }
func (p testProcessor) Process(ctx context.Context, user, task, uri string) (Candidate, error) {
	select {
	case <-p.release:
	case <-ctx.Done():
		return Candidate{}, ctx.Err()
	}
	if p.failure {
		return Candidate{}, errors.New("抠图失败")
	}
	return Candidate{Name: "运动鞋", CategoryLevel1: "鞋履", CategoryLevel2: "运动鞋", PrimaryColor: "白色", OriginalImageURL: uri, CutoutImageURL: "oss://bucket/users/u/cutouts/shoe.png"}, nil
}
func TestTaskPersistsResultsAndFailures(t *testing.T) {
	for _, failure := range []bool{false, true} {
		t.Run(map[bool]string{true: "failure", false: "success"}[failure], func(t *testing.T) {
			db, err := database.Open(filepath.Join(t.TempDir(), "tasks.db"))
			if err != nil {
				t.Fatal(err)
			}
			if database.AutoMigrate(db) != nil {
				t.Fatal("migration failed")
			}
			sqlDB, _ := db.DB()
			defer sqlDB.Close()
			release := make(chan struct{})
			defer func() {
				select {
				case <-release:
				default:
					close(release)
				}
			}()
			router := gin.New()
			router.Use(func(c *gin.Context) { c.Set("authenticatedUserID", "u"); c.Next() })
			RegisterRoutes(router, db, testProcessor{failure: failure, release: release}, config.Config{AliyunOSSBucket: "bucket"})
			req := httptest.NewRequest(http.MethodPost, "/ai/item-recognition/tasks", strings.NewReader(`{"imageUrls":["oss://bucket/users/u/originals/shoe.jpg"]}`))
			req.Header.Set("Content-Type", "application/json")
			response := httptest.NewRecorder()
			router.ServeHTTP(response, req)
			if response.Code != 200 {
				t.Fatalf("%d %s", response.Code, response.Body.String())
			}
			var envelope struct {
				Data struct {
					ID     string `json:"id"`
					Status string `json:"status"`
				} `json:"data"`
			}
			json.Unmarshal(response.Body.Bytes(), &envelope)
			if envelope.Data.Status != "processing" {
				t.Fatal("must return processing")
			}
			close(release)
			var task models.AITask
			deadline := time.Now().Add(3 * time.Second)
			for time.Now().Before(deadline) {
				db.First(&task, "id = ?", envelope.Data.ID)
				if task.Status != "processing" {
					break
				}
				time.Sleep(10 * time.Millisecond)
			}
			if failure {
				if task.Status != "failed" || task.ErrorMessage != "抠图失败" {
					t.Fatalf("failure not persisted: %+v", task)
				}
			} else {
				if task.Status != "success" || !strings.Contains(task.ResultPayload, "运动鞋") || !strings.Contains(task.ResultPayload, "cutouts/shoe.png") {
					t.Fatalf("result not persisted: %+v", task)
				}
			}
			other := gin.New()
			other.Use(func(c *gin.Context) { c.Set("authenticatedUserID", "other"); c.Next() })
			RegisterRoutes(other, db, testProcessor{}, config.Config{AliyunOSSBucket: "bucket"})
			response = httptest.NewRecorder()
			other.ServeHTTP(response, httptest.NewRequest("GET", "/ai/tasks/"+task.ID, nil))
			if response.Code != 404 {
				t.Fatal("other user could read recognition task")
			}
		})
	}
}
func TestOnlyUserOwnedOriginalsAreAccepted(t *testing.T) {
	cfg := config.Config{AliyunOSSBucket: "bucket"}
	for _, uri := range []string{"http://127.0.0.1/private", "oss://bucket/users/other/originals/a.jpg", "oss://bucket/users/u/originals/../secret", "oss://bucket/users/u/cutouts/a.png"} {
		if _, err := objectKey(cfg, "u", uri); err == nil {
			t.Errorf("accepted %s", uri)
		}
	}
}
func TestInvalidRecognitionIsRejected(t *testing.T) {
	for _, candidate := range []Candidate{{}, {Name: "鞋", CategoryLevel1: "不存在", CategoryLevel2: "鞋", PrimaryColor: "白"}, {Name: "鞋", CategoryLevel1: "鞋履", CategoryLevel2: "鞋", PrimaryColor: "白", Seasons: []string{"不存在"}}} {
		if validateCandidate(candidate) == nil {
			t.Fatal("accepted invalid structured data")
		}
	}
}
