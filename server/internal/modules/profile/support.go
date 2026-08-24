package profile

import "encoding/json"

func toJSON(values []string) string {
	if len(values) == 0 {
		return "[]"
	}

	encoded, _ := json.Marshal(values)
	return string(encoded)
}
