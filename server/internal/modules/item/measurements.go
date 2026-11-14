package item

import "math"

var measurementKeys = map[string]bool{"length": true, "shoulderWidth": true, "chest": true, "waist": true, "hem": true, "sleeveLength": true, "centerBackSleeve": true, "upperArm": true, "armholeDepth": true, "backWidth": true, "cuff": true, "collar": true, "neckWidth": true, "frontNeckDepth": true, "hip": true, "frontRise": true, "backRise": true, "thigh": true, "outseam": true, "inseam": true, "knee": true, "calf": true, "legOpening": true, "waistPosition": true, "backWidthPosition": true, "hipPosition": true, "kneePosition": true, "calfPosition": true}

func validMeasurements(values *map[string]float64) bool {
	if values == nil {
		return true
	}
	for key, value := range *values {
		if !measurementKeys[key] || math.IsNaN(value) || math.IsInf(value, 0) || value <= 0 || value > 500 {
			return false
		}
	}
	return true
}
