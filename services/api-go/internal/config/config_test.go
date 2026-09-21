package config

import (
	"encoding/base64"
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

func TestProductionRejectsLoopbackEndpoints(t *testing.T) {
	t.Setenv("APP_ENV", "production")
	t.Setenv("DEMO_DATA", "false")
	t.Setenv("DATABASE_URL", "postgres://db.example/fitcalgary")
	t.Setenv("KEYCLOAK_ISSUER", "http://localhost:8080/realms/fitcalgary")
	t.Setenv("S3_ENDPOINT", "http://localhost:9000")
	t.Setenv("S3_ACCESS_KEY_ID", "production-access")
	t.Setenv("S3_SECRET_ACCESS_KEY", "production-secret")
	t.Setenv("DEVICE_TOKEN_ENCRYPTION_KEY", base64.StdEncoding.EncodeToString([]byte("01234567890123456789012345678901")))
	if _, err := Load(); err == nil || !strings.Contains(err.Error(), "HTTPS") {
		t.Fatalf("expected loopback endpoint rejection, got %v", err)
	}
}

func TestProductionAcceptsExplicitSecureConfiguration(t *testing.T) {
	t.Setenv("APP_ENV", "production")
	t.Setenv("DEMO_DATA", "false")
	t.Setenv("DATABASE_URL", "postgres://db.example/fitcalgary")
	t.Setenv("KEYCLOAK_ISSUER", "https://identity.example/realms/fitcalgary")
	t.Setenv("WEB_PUBLIC_URL", "https://fitcalgary.example")
	t.Setenv("S3_ENDPOINT", "https://storage.example")
	t.Setenv("S3_ACCESS_KEY_ID", "production-access")
	t.Setenv("S3_SECRET_ACCESS_KEY", "production-secret")
	t.Setenv("DEVICE_TOKEN_ENCRYPTION_KEY", base64.StdEncoding.EncodeToString([]byte("01234567890123456789012345678901")))
	if _, err := Load(); err != nil {
		t.Fatalf("expected secure production configuration, got %v", err)
	}
}

func TestStorageURLStyleIsConfigurable(t *testing.T) {
	t.Setenv("DATABASE_URL", "postgres://db.example/fitcalgary")
	t.Setenv("KEYCLOAK_ISSUER", "https://identity.example/realms/fitcalgary")
	t.Setenv("S3_ENDPOINT", "https://storage.example")
	t.Setenv("S3_ACCESS_KEY_ID", "access")
	t.Setenv("S3_SECRET_ACCESS_KEY", "secret")
	t.Setenv("S3_USE_PATH_STYLE", "false")
	t.Setenv("DEVICE_TOKEN_ENCRYPTION_KEY", base64.StdEncoding.EncodeToString([]byte("01234567890123456789012345678901")))
	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.S3UsePathStyle {
		t.Fatal("expected virtual-hosted storage URL style")
	}
}
