package workers

import (
	"context"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

func TestNotificationDatabaseDelivery(t *testing.T) {
	raw := os.Getenv("DIRECTORY_TEST_DATABASE_URL")
	if raw == "" {
		t.Skip("requires isolated local test database")
	}
	cfg, err := pgxpool.ParseConfig(raw)
	if err != nil || cfg.ConnConfig.Host != "127.0.0.1" || !strings.HasSuffix(cfg.ConnConfig.Database, "_test") {
		t.Fatal("loopback _test database required")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	control, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		t.Fatal(err)
	}
	defer control.Close()
	schema := "notifications_" + strings.ReplaceAll(uuid.NewString(), "-", "")
	quoted := pgx.Identifier{schema}.Sanitize()
	if _, err := control.Exec(ctx, "CREATE SCHEMA "+quoted); err != nil {
		t.Fatal(err)
	}
	defer control.Exec(context.Background(), "DROP SCHEMA "+quoted+" CASCADE")
	// Copy the actual migrated structures while isolating this worker's queue.
	for _, table := range []string{"profiles", "notifications", "outbox_jobs"} {
		if _, err := control.Exec(ctx, "CREATE TABLE "+quoted+"."+table+" (LIKE public."+table+" INCLUDING ALL)"); err != nil {
			t.Fatal(err)
		}
	}
	cfg.ConnConfig.RuntimeParams["search_path"] = schema + ",public"
	pool, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		t.Fatal(err)
	}
	defer pool.Close()
	id := uuid.NewString()
	if _, err := pool.Exec(ctx, `INSERT INTO profiles(id,keycloak_subject,display_name,notification_preferences) VALUES($1::uuid,$1::text,'Notification test','{"eventUpdates":false,"announcements":false}')`, id); err != nil {
		t.Fatal(err)
	}
	enqueue := func(key, kind string) {
		t.Helper()
		_, err := pool.Exec(ctx, `INSERT INTO outbox_jobs(job_type,dedupe_key,payload) VALUES('NOTIFICATION',$1,$2)`, key, map[string]any{"type": kind, "profileId": id, "submissionId": uuid.NewString(), "eventId": uuid.NewString(), "title": "Test announcement", "body": "Test delivery"})
		if err != nil {
			t.Fatal(err)
		}
	}
	process := func() {
		t.Helper()
		if _, err := processNotification(ctx, pool); err != nil {
			t.Fatal(err)
		}
	}
	count := func(want int) {
		t.Helper()
		var got int
		if err := pool.QueryRow(ctx, `SELECT count(*) FROM notifications`).Scan(&got); err != nil || got != want {
			t.Fatalf("notification count: %d want %d (%v)", got, want, err)
		}
	}
	enqueue("essential", "SUBMISSION_APPROVED")
	process()
	count(1)
	enqueue("events-off", "EVENT_UPDATED")
	process()
	count(1)
	enqueue("announcements-off", "ADMIN_ANNOUNCEMENT")
	process()
	count(1)
	if _, err := pool.Exec(ctx, `UPDATE profiles SET notification_preferences='{"eventUpdates":true,"announcements":true}'`); err != nil {
		t.Fatal(err)
	}
	enqueue("events-on", "EVENT_UPDATED")
	process()
	count(2)
	enqueue("announcements-on", "ADMIN_ANNOUNCEMENT")
	process()
	count(3)
	if _, err := pool.Exec(ctx, `UPDATE outbox_jobs SET status='PENDING' WHERE dedupe_key='essential'`); err != nil {
		t.Fatal(err)
	}
	process()
	count(3)
	if _, err := pool.Exec(ctx, `UPDATE profiles SET account_status='SUSPENDED'`); err != nil {
		t.Fatal(err)
	}
	enqueue("inactive", "SUBMISSION_APPROVED")
	process()
	count(3)
	enqueue("poison", "UNKNOWN")
	for i := 0; i < 6; i++ {
		process()
		if _, err := pool.Exec(ctx, `UPDATE outbox_jobs SET available_at=now() WHERE dedupe_key='poison'`); err != nil {
			t.Fatal(err)
		}
	}
	var attempts int
	if err := pool.QueryRow(ctx, `SELECT attempt_count FROM outbox_jobs WHERE dedupe_key='poison'`).Scan(&attempts); err != nil || attempts != 5 {
		t.Fatalf("retry bound failed: %d %v", attempts, err)
	}
	t.Log("Actual PostgreSQL: essential inbox, opt-out/opt-in, idempotent retry, inactive-account suppression and bounded poison retries verified")
}
