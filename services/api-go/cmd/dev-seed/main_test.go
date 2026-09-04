package main

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"

	"fitcalgary.ca/index/api/internal/config"
	database "fitcalgary.ca/index/api/internal/db"
	"fitcalgary.ca/index/api/internal/httpapi"
	"github.com/jackc/pgx/v5/pgxpool"
)

func TestValidateTarget(t *testing.T) {
	for _, tc := range []struct {
		name, environment, enabled, url string
		ok                              bool
	}{
		{"local development", "development", "true", "postgres://127.0.0.1/fitcalgary_development?sslmode=disable", true},
		{"local test", "test", "true", "postgres://[::1]/fitcalgary_test?sslmode=disable", true},
		{"production denied", "production", "true", "postgres://127.0.0.1/fitcalgary_test?sslmode=disable", false},
		{"no opt in", "development", "false", "postgres://127.0.0.1/fitcalgary_test?sslmode=disable", false},
		{"missing environment", "", "true", "postgres://127.0.0.1/fitcalgary_test?sslmode=disable", false},
		{"production database name", "development", "true", "postgres://127.0.0.1/fitcalgary?sslmode=disable", false},
		{"remote host", "development", "true", "postgres://192.0.2.1/fitcalgary_test?sslmode=disable", false},
		{"hostname denied", "development", "true", "postgres://localhost/fitcalgary_test?sslmode=disable", false},
		{"multiple hosts denied", "development", "true", "postgres://127.0.0.1,192.0.2.1/fitcalgary_test?sslmode=disable", false},
		{"staging denied", "staging", "true", "postgres://127.0.0.1/fitcalgary_test?sslmode=disable", false},
		{"empty connection", "development", "true", "", false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			if err := validateTarget(tc.environment, tc.enabled, tc.url); (err == nil) != tc.ok {
				t.Fatalf("unexpected result: %v", err)
			}
		})
	}
}

// The caller supplies a disposable, empty local database; no existing records
// are deleted. Normal unit runs explicitly skip this integration check.
func TestFixtureDatabaseIntegration(t *testing.T) {
	url := os.Getenv("FIXTURE_TEST_DATABASE_URL")
	if url == "" {
		t.Skip("requires disposable FIXTURE_TEST_DATABASE_URL")
	}
	if err := validateTarget("test", "true", url); err != nil {
		t.Fatal(err)
	}
	ctx := context.Background()
	pool, err := pgxpool.New(ctx, url)
	if err != nil {
		t.Fatal(err)
	}
	defer pool.Close()
	if err := database.ApplyMigrations(ctx, pool, "../../../api/migrations"); err != nil {
		t.Fatal(err)
	}
	if err := database.RejectDevelopmentData(ctx, pool); err != nil {
		t.Fatal(err)
	}
	// Create and later remove only this test's own record to exercise the
	// nonempty-database boundary before the successful fixture load.
	var probeID string
	if err := pool.QueryRow(ctx, `INSERT INTO gyms(city_id,slug,name) SELECT id,'fixture-refusal-probe','Fixture refusal test record' FROM cities WHERE slug='calgary' RETURNING id::text`).Scan(&probeID); err != nil {
		t.Fatal(err)
	}
	if inserted, err := seed(ctx, pool); err == nil || inserted {
		t.Fatalf("nonempty database accepted: inserted=%t err=%v", inserted, err)
	}
	var remaining int
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM gyms`).Scan(&remaining); err != nil || remaining != 1 {
		t.Fatalf("refused load altered existing records: count=%d err=%v", remaining, err)
	}
	if err := database.RejectDevelopmentData(ctx, pool); err != nil {
		t.Fatalf("refused load left a fixture marker: %v", err)
	}
	if _, err := pool.Exec(ctx, `DELETE FROM gyms WHERE id=$1`, probeID); err != nil {
		t.Fatal(err)
	}
	inserted, err := seed(ctx, pool)
	if err != nil || !inserted {
		t.Fatalf("first load: inserted=%t err=%v", inserted, err)
	}
	inserted, err = seed(ctx, pool)
	if err != nil || inserted {
		t.Fatalf("repeat load: inserted=%t err=%v", inserted, err)
	}
	if err := database.RejectDevelopmentData(ctx, pool); err == nil {
		t.Fatal("production guard accepted fixture database")
	}
	var gyms, clubs, events int
	if err := pool.QueryRow(ctx, `SELECT (SELECT count(*) FROM gyms),(SELECT count(*) FROM clubs),(SELECT count(*) FROM events)`).Scan(&gyms, &clubs, &events); err != nil {
		t.Fatal(err)
	}
	if gyms != 2 || clubs != 1 || events != 1 {
		t.Fatalf("unexpected fixture counts %d/%d/%d", gyms, clubs, events)
	}
	var monthly, firstYear int
	if err := pool.QueryRow(ctx, `SELECT ongoing_monthly_cents,first_year_monthly_cents FROM gym_pricing WHERE plan_name='Development fixture biweekly plan'`).Scan(&monthly, &firstYear); err != nil {
		t.Fatal(err)
	}
	if monthly != 3100 || firstYear != 3350 {
		t.Fatalf("normalization differs: %d/%d", monthly, firstYear)
	}
	var missing bool
	if err := pool.QueryRow(ctx, `SELECT ongoing_monthly_cents IS NULL FROM gym_pricing WHERE pricing_complete=false`).Scan(&missing); err != nil || !missing {
		t.Fatalf("incomplete pricing fabricated: %v", err)
	}
	// Exercise the real public handlers against PostgreSQL, not response mocks.
	router := httpapi.NewServer(pool, nil, nil, nil, config.Config{}, slog.New(slog.NewTextHandler(io.Discard, nil))).Router()
	for _, tc := range []struct {
		path  string
		count int
	}{
		{"/api/v1/gyms", 2},
		{"/api/v1/gyms?category=BUDGET", 1},
		{"/api/v1/gyms?q=Biweekly", 1},
		{"/api/v1/clubs", 1},
		{"/api/v1/events", 1},
		{"/api/v1/leaderboards", 0},
	} {
		response := httptest.NewRecorder()
		router.ServeHTTP(response, httptest.NewRequest(http.MethodGet, tc.path, nil))
		if response.Code != http.StatusOK {
			t.Fatalf("%s returned %d: %s", tc.path, response.Code, response.Body.String())
		}
		var payload struct {
			Data []struct {
				Name string `json:"name"`
			} `json:"data"`
		}
		if err := json.Unmarshal(response.Body.Bytes(), &payload); err != nil || len(payload.Data) != tc.count {
			t.Fatalf("%s returned unexpected data: %s (err=%v)", tc.path, response.Body.String(), err)
		}
		for _, record := range payload.Data {
			if !strings.HasPrefix(record.Name, "Development Fixture") {
				t.Fatalf("%s returned an unlabelled fixture", tc.path)
			}
		}
	}
}
