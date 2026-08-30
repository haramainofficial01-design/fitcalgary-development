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
	"os"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"fitcalgary.ca/index/api/internal/auth"
	"fitcalgary.ca/index/api/internal/config"
	database "fitcalgary.ca/index/api/internal/db"
	"fitcalgary.ca/index/api/internal/httpapi"
	"fitcalgary.ca/index/api/internal/security"
)

const developmentToken = "phase1-development-token"

type developmentVerifier struct{}

func (developmentVerifier) Verify(_ context.Context, token string) (auth.Principal, error) {
	if token != developmentToken {
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
	cipher, err := security.NewTokenCipher([]byte("0123456789abcdef0123456789abcdef"))
	if err != nil {
		log.Fatal(err)
	}
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	server := httpapi.NewServer(pool, developmentVerifier{}, nil, cipher, config.Config{
		Environment:           "development",
		WebPublicURL:          "http://localhost:3000",
		SignedURLTTL:          5 * time.Minute,
		MaxEvidenceBytes:      4_294_967_296,
		EvidenceRetentionDays: 14,
	}, logger)
	address := fmt.Sprintf(":%s", port)
	log.Printf("phase1 development harness listening on %s", address)
	log.Fatal(http.ListenAndServe(address, server.Router()))
}
