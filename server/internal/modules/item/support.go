package item

import (
	"encoding/json"
	"fmt"
	"time"
)

func newID(prefix string) string {
	return fmt.Sprintf("%s_%d", prefix, time.Now().UnixNano())
}

func toJSON(values []string) string {
	if len(values) == 0 {
		return "[]"
	}

	encoded, _ := json.Marshal(values)
	return string(encoded)
}
