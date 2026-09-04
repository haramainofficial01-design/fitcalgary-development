package config

import (
	"strings"
	"testing"
)

func TestProductionRejectsDemoData(t *testing.T) {
	for _, value := range []string{"true", "1", "TRUE", "yes", "invalid"} {
		t.Run(value, func(t *testing.T) {
			t.Setenv("APP_ENV", "production")
			t.Setenv("DEMO_DATA", value)
			_, err := Load()
			if err == nil || !strings.Contains(err.Error(), "DEMO_DATA") {
				t.Fatalf("expected fixture configuration rejection, got %v", err)
			}
		})
	}
}
