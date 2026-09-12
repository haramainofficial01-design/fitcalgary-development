// Command dev-seed explicitly loads synthetic development data into an empty,
// loopback-only database. It is never built into the production image.
package main

import (
	"context"
	_ "embed"
	"errors"
	"fmt"
	"log"
	"net"
	"os"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	database "fitcalgary.ca/index/api/internal/db"
	"fitcalgary.ca/index/api/internal/domain"
)

//go:embed fixtures/directory.sql
var fixtureSQL string

const batch = "directory-fixtures-v1"

func validateTarget(environment, enabled, databaseURL string) error {
	if (environment != "development" && environment != "test") || enabled != "true" {
		return errors.New("fixture loading requires APP_ENV=development or test and DEMO_DATA=true")
	}
	if databaseURL == "" {
		return errors.New("DATABASE_URL is required")
	}
	cfg, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		return errors.New("invalid fixture database configuration")
	}
	ip := net.ParseIP(cfg.ConnConfig.Host)
	if ip == nil || !ip.IsLoopback() || len(cfg.ConnConfig.Fallbacks) != 0 {
		return errors.New("fixture database must use one literal loopback IP with sslmode=disable")
	}
	name := cfg.ConnConfig.Database
	if !strings.HasSuffix(name, "_development") && !strings.HasSuffix(name, "_test") {
		return errors.New("fixture database name must end in _development or _test")
	}
	return nil
}

func seed(ctx context.Context, pool *pgxpool.Pool) (bool, error) {
	tx, err := pool.Begin(ctx)
	if err != nil {
		return false, err
	}
	defer tx.Rollback(ctx) //nolint:errcheck
	// Serialize fixture loads and refuse to merge synthetic records into a
	// database that already contains account or catalogue data.
	if _, err := tx.Exec(ctx, `LOCK TABLE app_settings,profiles,gyms,clubs,events,leaderboards IN EXCLUSIVE MODE`); err != nil {
		return false, err
	}
	var existing string
	if err := tx.QueryRow(ctx, `SELECT COALESCE((SELECT value->>'batch' FROM app_settings WHERE key='development_fixture_batch'),'')`).Scan(&existing); err != nil {
		return false, err
	}
	if existing == batch {
		return false, nil
	}
	if existing != "" {
		return false, errors.New("database already contains a different fixture batch")
	}
	var count int64
	if err := tx.QueryRow(ctx, `SELECT (SELECT count(*) FROM profiles)+(SELECT count(*) FROM gyms)+(SELECT count(*) FROM clubs)+(SELECT count(*) FROM events)+(SELECT count(*) FROM leaderboards)`).Scan(&count); err != nil {
		return false, err
	}
	if count != 0 {
		return false, errors.New("fixture loader refuses a database containing existing account or catalogue records")
	}
	for _, statement := range database.SplitMigration(fixtureSQL) {
		if _, err := tx.Exec(ctx, statement); err != nil {
			return false, fmt.Errorf("fixture insertion: %w", err)
		}
	}
	rows, err := tx.Query(ctx, `SELECT id::text,recurring_cents,billing_frequency,mandatory_recurring_fee_cents,mandatory_annual_fee_cents,initiation_fee_cents,pricing_complete FROM gym_pricing`)
	if err != nil {
		return false, err
	}
	type priceRow struct {
		id    string
		input domain.PriceInput
	}
	var prices []priceRow
	for rows.Next() {
		var p priceRow
		if err := rows.Scan(&p.id, &p.input.RecurringCents, &p.input.Frequency, &p.input.MandatoryRecurringFeeCents, &p.input.MandatoryAnnualFeeCents, &p.input.InitiationFeeCents, &p.input.Complete); err != nil {
			rows.Close()
			return false, err
		}
		prices = append(prices, p)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return false, err
	}
	for _, p := range prices {
		normalized := domain.NormalizePrice(p.input)
		if _, err := tx.Exec(ctx, `UPDATE gym_pricing SET ongoing_monthly_cents=$2,first_year_monthly_cents=$3 WHERE id=$1`, p.id, normalized.OngoingMonthlyCents, normalized.FirstYearMonthlyCents); err != nil {
			return false, err
		}
	}
	if _, err := tx.Exec(ctx, `INSERT INTO app_settings(key,value,public) VALUES('development_fixture_batch',jsonb_build_object('batch',$1::text,'label','DEVELOPMENT DATA — NOT CLIENT APPROVED'),true)`, batch); err != nil {
		return false, err
	}
	if err := tx.Commit(ctx); err != nil {
		return false, err
	}
	return true, nil
}

func run() error {
	url := os.Getenv("DATABASE_URL")
	if err := validateTarget(os.Getenv("APP_ENV"), os.Getenv("DEMO_DATA"), url); err != nil {
		return err
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	pool, err := pgxpool.New(ctx, url)
	if err != nil {
		return errors.New("cannot configure fixture database")
	}
	defer pool.Close()
	directory := os.Getenv("MIGRATIONS_DIR")
	if directory == "" {
		directory = "../api/migrations"
	}
	if err := database.ApplyMigrations(ctx, pool, directory); err != nil {
		return err
	}
	applied, err := seed(ctx, pool)
	if err != nil {
		return err
	}
	fmt.Printf("Development fixture batch %s ready (inserted=%t); not Client-approved data.\n", batch, applied)
	return nil
}

func main() {
	if err := run(); err != nil {
		log.Fatal(err)
	}
}
