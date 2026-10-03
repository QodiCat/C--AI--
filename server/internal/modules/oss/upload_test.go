package oss

import (
	"bytes"
	"image"
	"image/png"
	"testing"
)

func TestNormalizeLargePNGForSegmentation(t *testing.T) {
	source := image.NewRGBA(image.Rect(0, 0, 2400, 2100))
	var buffer bytes.Buffer
	if err := png.Encode(&buffer, source); err != nil {
		t.Fatal(err)
	}
	result, err := normalizeImage(buffer.Bytes())
	if err != nil {
		t.Fatal(err)
	}
	cfg, format, err := image.DecodeConfig(bytes.NewReader(result))
	if err != nil || format != "jpeg" || cfg.Width >= 2000 || cfg.Height >= 2000 || len(result) >= 3<<20 {
		t.Fatalf("invalid normalized image: %s %+v %v", format, cfg, err)
	}
}
func TestNormalizeRejectsNonImage(t *testing.T) {
	if _, err := normalizeImage([]byte("not an image")); err == nil {
		t.Fatal("accepted non-image")
	}
}
