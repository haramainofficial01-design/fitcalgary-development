package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
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

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
	if err := run(logger); err != nil {
		logger.Error("api stopped", "error", err)
		os.Exit(1)
	}
}

func run(logger *slog.Logger) error {
	cfg, err := config.Load()
	if err != nil {
		return fmt.Errorf("configuration: %w", err)
	}
	rootContext, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	poolConfig, err := pgxpool.ParseConfig(cfg.DatabaseURL)
	if err != nil {
		return fmt.Errorf("database configuration: %w", err)
	}
	poolConfig.MaxConns = 20
	poolConfig.MinConns = 2
	poolConfig.MaxConnLifetime = 30 * time.Minute
	pool, err := pgxpool.NewWithConfig(rootContext, poolConfig)
	if err != nil {
		return fmt.Errorf("database pool: %w", err)
	}
	defer pool.Close()
	if err := pool.Ping(rootContext); err != nil {
		return fmt.Errorf("database connection: %w", err)
	}
	if err := database.ApplyMigrations(rootContext, pool, cfg.MigrationsDir); err != nil {
		return fmt.Errorf("database migration: %w", err)
	}

	verifier, err := auth.NewOIDCVerifier(rootContext, cfg.KeycloakIssuer, cfg.KeycloakAudience)
	if err != nil {
		return fmt.Errorf("keycloak oidc discovery: %w", err)
	}
	evidence, err := storage.NewS3EvidenceStore(rootContext, cfg)
	if err != nil {
		return fmt.Errorf("evidence store: %w", err)
	}
	cipher, err := security.NewTokenCipher(cfg.DeviceTokenKey)
	if err != nil {
		return fmt.Errorf("device token encryption: %w", err)
	}
	go workers.RunNotificationOutbox(rootContext, pool, logger)
	go workers.RunEvidenceRetention(rootContext, pool, evidence, logger)

	api := httpapi.NewServer(pool, verifier, evidence, cipher, cfg, logger)
	server := &http.Server{
		Addr:              fmt.Sprintf(":%d", cfg.Port),
		Handler:           api.Router(),
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      60 * time.Second,
		IdleTimeout:       90 * time.Second,
		MaxHeaderBytes:    1 << 20,
	}

	errorChannel := make(chan error, 1)
	go func() {
		logger.Info("api listening", "port", cfg.Port, "environment", cfg.Environment)
		errorChannel <- server.ListenAndServe()
	}()

	select {
	case <-rootContext.Done():
		shutdownContext, cancel := context.WithTimeout(context.Background(), 15*time.Second)
		defer cancel()
		if err := server.Shutdown(shutdownContext); err != nil {
			return fmt.Errorf("graceful shutdown: %w", err)
		}
		return nil
	case err := <-errorChannel:
		if errors.Is(err, http.ErrServerClosed) {
			return nil
		}
		return err
	}
}
