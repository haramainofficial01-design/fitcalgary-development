package config

import (
	"encoding/base64"
	"errors"
	"fmt"
	"net/url"
	"os"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	Environment           string
	Port                  int
	DatabaseURL           string
	KeycloakIssuer        string
	KeycloakAudience      string
	WebPublicURL          string
	S3Endpoint            string
	S3Region              string
	S3Bucket              string
	S3AccessKeyID         string
	S3SecretAccessKey     string
	SignedURLTTL          time.Duration
	MaxEvidenceBytes      int64
	EvidenceRetentionDays int
	MigrationsDir         string
	DeviceTokenKey        []byte
	FCMProjectID          string
	FCMClientEmail        string
	FCMPrivateKey         string
}

func Load() (Config, error) {
	environment := value("APP_ENV", "development")
	if environment == "production" {
		if raw := strings.TrimSpace(os.Getenv("DEMO_DATA")); raw != "" && raw != "false" {
			return Config{}, errors.New("DEMO_DATA must be false in production")
		}
	}
	cfg := Config{
		Environment:       environment,
		DatabaseURL:       os.Getenv("DATABASE_URL"),
		KeycloakIssuer:    strings.TrimRight(os.Getenv("KEYCLOAK_ISSUER"), "/"),
		KeycloakAudience:  value("KEYCLOAK_AUDIENCE", "fitcalgary-api"),
		WebPublicURL:      value("WEB_PUBLIC_URL", "http://localhost:3000"),
		S3Endpoint:        os.Getenv("S3_ENDPOINT"),
		S3Region:          value("S3_REGION", "ca-central-1"),
		S3Bucket:          value("S3_BUCKET", "fitcalgary-evidence"),
		S3AccessKeyID:     os.Getenv("S3_ACCESS_KEY_ID"),
		S3SecretAccessKey: os.Getenv("S3_SECRET_ACCESS_KEY"),
		MigrationsDir:     value("MIGRATIONS_DIR", "../api/migrations"),
		FCMProjectID:      os.Getenv("FCM_PROJECT_ID"),
		FCMClientEmail:    os.Getenv("FCM_CLIENT_EMAIL"),
		FCMPrivateKey:     strings.ReplaceAll(os.Getenv("FCM_PRIVATE_KEY"), `\n`, "\n"),
	}
	deviceKey := strings.TrimSpace(os.Getenv("DEVICE_TOKEN_ENCRYPTION_KEY"))
	decodedKey, decodeErr := base64.StdEncoding.DecodeString(deviceKey)
	if decodeErr != nil || len(decodedKey) != 32 {
		return Config{}, errors.New("DEVICE_TOKEN_ENCRYPTION_KEY must be base64-encoded 32-byte key material")
	}
	cfg.DeviceTokenKey = decodedKey

	var err error
	if cfg.Port, err = integer("PORT", 4000, 1, 65535); err != nil {
		return Config{}, err
	}
	ttl, err := integer("SIGNED_URL_TTL_SECONDS", 300, 30, 900)
	if err != nil {
		return Config{}, err
	}
	cfg.SignedURLTTL = time.Duration(ttl) * time.Second
	if cfg.EvidenceRetentionDays, err = integer("EVIDENCE_RETENTION_DAYS", 14, 1, 90); err != nil {
		return Config{}, err
	}
	maxEvidence, err := integer64("MAX_EVIDENCE_BYTES", 4_294_967_296, 1, 4_294_967_296)
	if err != nil {
		return Config{}, err
	}
	cfg.MaxEvidenceBytes = maxEvidence

	for name, current := range map[string]string{
		"DATABASE_URL": cfg.DatabaseURL, "KEYCLOAK_ISSUER": cfg.KeycloakIssuer,
		"S3_ENDPOINT": cfg.S3Endpoint, "S3_ACCESS_KEY_ID": cfg.S3AccessKeyID,
		"S3_SECRET_ACCESS_KEY": cfg.S3SecretAccessKey,
	} {
		if strings.TrimSpace(current) == "" {
			return Config{}, fmt.Errorf("%s is required", name)
		}
	}
	if cfg.Environment != "development" && cfg.Environment != "test" && cfg.Environment != "production" {
		return Config{}, errors.New("APP_ENV must be development, test, or production")
	}
	if cfg.Environment == "production" {
		if strings.TrimSpace(os.Getenv("DEMO_DATA")) != "false" {
			return Config{}, errors.New("DEMO_DATA must be explicitly set to false in production")
		}
		for name, endpoint := range map[string]string{
			"KEYCLOAK_ISSUER": cfg.KeycloakIssuer,
			"WEB_PUBLIC_URL":  cfg.WebPublicURL,
			"S3_ENDPOINT":     cfg.S3Endpoint,
		} {
			if err := productionURL(name, endpoint); err != nil {
				return Config{}, err
			}
		}
		if deviceKey == "MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=" {
			return Config{}, errors.New("DEVICE_TOKEN_ENCRYPTION_KEY must not use the development placeholder in production")
		}
	}
	return cfg, nil
}

func productionURL(name, value string) error {
	parsed, err := url.Parse(value)
	if err != nil || parsed.Scheme != "https" || parsed.Hostname() == "" {
		return fmt.Errorf("%s must be an HTTPS URL in production", name)
	}
	host := strings.ToLower(parsed.Hostname())
	if host == "localhost" || host == "127.0.0.1" || host == "::1" {
		return fmt.Errorf("%s must not point to a loopback host in production", name)
	}
	if parsed.User != nil {
		return fmt.Errorf("%s must not embed credentials", name)
	}
	return nil
}

func value(name, fallback string) string {
	if v := strings.TrimSpace(os.Getenv(name)); v != "" {
		return v
	}
	return fallback
}

func integer(name string, fallback, minimum, maximum int) (int, error) {
	v := fallback
	if raw := strings.TrimSpace(os.Getenv(name)); raw != "" {
		parsed, err := strconv.Atoi(raw)
		if err != nil {
			return 0, fmt.Errorf("%s must be an integer: %w", name, err)
		}
		v = parsed
	}
	if v < minimum || v > maximum {
		return 0, fmt.Errorf("%s must be between %d and %d", name, minimum, maximum)
	}
	return v, nil
}

func integer64(name string, fallback, minimum, maximum int64) (int64, error) {
	v := fallback
	if raw := strings.TrimSpace(os.Getenv(name)); raw != "" {
		parsed, err := strconv.ParseInt(raw, 10, 64)
		if err != nil {
			return 0, fmt.Errorf("%s must be an integer: %w", name, err)
		}
		v = parsed
	}
	if v < minimum || v > maximum {
		return 0, fmt.Errorf("%s is outside the allowed range", name)
	}
	return v, nil
}
