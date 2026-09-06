// Command phase1-harness provides a deliberately gated, local-only API runtime
// for acceptance tests when production Keycloak and object-storage credentials
// are not available. The production image builds cmd/api and never this command.
package main

import (
	"context"
	"errors"
	"fmt"
	"io"
	"log"
	"log/slog"
	"net/http"
	"net/url"
	"os"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"fitcalgary.ca/index/api/internal/auth"
	"fitcalgary.ca/index/api/internal/config"
	database "fitcalgary.ca/index/api/internal/db"
	"fitcalgary.ca/index/api/internal/httpapi"
	"fitcalgary.ca/index/api/internal/security"
	"fitcalgary.ca/index/api/internal/storage"
	"fitcalgary.ca/index/api/internal/workers"
)

type developmentVerifier struct {
	userToken  string
	adminToken string
}

func (v developmentVerifier) Verify(_ context.Context, token string) (auth.Principal, error) {
	if token == v.adminToken {
		return auth.Principal{
			Subject:       "phase1-development-admin",
			Email:         "phase1-admin@example.invalid",
			EmailVerified: true,
			Username:      "phase1-administrator",
			Roles:         []auth.Role{auth.RoleUser, auth.RoleAdmin},
		}, nil
	}
	if token != v.userToken {
		return auth.Principal{}, errors.New("invalid development token")
	}
	return auth.Principal{
		Subject:       "phase1-development-user",
		Email:         "phase1@example.invalid",
		EmailVerified: true,
		Username:      "phase1-athlete",
		Roles:         []auth.Role{auth.RoleUser},
	}, nil
}

func main() {
	if os.Getenv("APP_ENV") != "development" || os.Getenv("PHASE1_HARNESS_ENABLED") != "true" {
		log.Fatal("phase1 harness requires APP_ENV=development and PHASE1_HARNESS_ENABLED=true")
	}
	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		log.Fatal("DATABASE_URL is required")
	}
	userToken := os.Getenv("PHASE1_USER_TOKEN")
	adminToken := os.Getenv("PHASE1_ADMIN_TOKEN")
	tokenCipherKey := os.Getenv("PHASE1_TOKEN_CIPHER_KEY")
	if userToken == "" || adminToken == "" || tokenCipherKey == "" {
		log.Fatal("PHASE1_USER_TOKEN, PHASE1_ADMIN_TOKEN, and PHASE1_TOKEN_CIPHER_KEY are required")
	}
	migrationsDir := os.Getenv("MIGRATIONS_DIR")
	if migrationsDir == "" {
		migrationsDir = "../api/migrations"
	}
	port := os.Getenv("PORT")
	if port == "" {
		port = "4400"
	}

	ctx := context.Background()
	pool, err := pgxpool.New(ctx, databaseURL)
	if err != nil {
		log.Fatal(err)
	}
	defer pool.Close()
	if err := pool.Ping(ctx); err != nil {
		log.Fatal(err)
	}
	if err := database.ApplyMigrations(ctx, pool, migrationsDir); err != nil {
		log.Fatal(err)
	}
	cipher, err := security.NewTokenCipher([]byte(tokenCipherKey))
	if err != nil {
		log.Fatal(err)
	}
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	var evidence storage.EvidenceStore
	if endpoint := os.Getenv("STORAGE_TEST_ENDPOINT"); endpoint != "" {
		parsed, parseErr := url.Parse(endpoint)
		if parseErr != nil || parsed.Hostname() != "127.0.0.1" {
			log.Fatal("development evidence endpoint must be loopback")
		}
		evidence, err = storage.NewS3EvidenceStore(ctx, config.Config{
			S3Endpoint: endpoint, S3Region: "us-east-1", S3Bucket: "fitcalgary-evidence-test",
			S3AccessKeyID: os.Getenv("STORAGE_TEST_ACCESS_KEY"), S3SecretAccessKey: os.Getenv("STORAGE_TEST_SECRET_KEY"),
			SignedURLTTL: 5 * time.Minute, MaxEvidenceBytes: 4_294_967_296,
		})
		if err != nil {
			log.Fatal("development evidence configuration failed")
		}
	}
	go workers.RunNotificationOutbox(ctx, pool, logger)
	server := httpapi.NewServer(pool, developmentVerifier{
		userToken:  userToken,
		adminToken: adminToken,
	}, evidence, cipher, config.Config{
		Environment:           "development",
		WebPublicURL:          "http://localhost:3000",
		SignedURLTTL:          5 * time.Minute,
		MaxEvidenceBytes:      4_294_967_296,
		EvidenceRetentionDays: 14,
	}, logger)
	address := fmt.Sprintf("127.0.0.1:%s", port)
	log.Printf("phase1 development harness listening on %s", address)
	log.Fatal(http.ListenAndServe(address, server.Router()))
}
