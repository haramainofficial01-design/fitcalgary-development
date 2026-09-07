package workers

import (
	"context"
	"os"
	"strings"
	"testing"
	"time"

	"fitcalgary.ca/index/api/internal/notifications"
	"fitcalgary.ca/index/api/internal/security"
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
	for _, table := range []string{"profiles", "notifications", "outbox_jobs", "notification_devices", "notification_deliveries"} {
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
	testPushQueue(t, ctx, pool, id)
}

type testPushSender struct {
	calls  int
	result notifications.Result
}

func (s *testPushSender) Send(_ context.Context, token string, m notifications.Message) notifications.Result {
	s.calls++
	if token != "private-device-test-token" {
		panic("incorrect decrypted token")
	}
	return s.result
}
func testPushQueue(t *testing.T, ctx context.Context, pool *pgxpool.Pool, profile string) {
	t.Helper()
	if _, err := pool.Exec(ctx, `UPDATE profiles SET account_status='ACTIVE';UPDATE notifications SET delivery_status='SUPPRESSED'`); err != nil {
		t.Fatal(err)
	}
	cipher, err := security.NewTokenCipher([]byte(strings.Repeat("x", 32)))
	if err != nil {
		t.Fatal(err)
	}
	encrypted, err := cipher.Encrypt("private-device-test-token")
	if err != nil {
		t.Fatal(err)
	}
	device := uuid.NewString()
	if _, err := pool.Exec(ctx, `INSERT INTO notification_devices(id,profile_id,platform,token_hash,encrypted_token) VALUES($1,$2,'ANDROID',$3,$4)`, device, profile, security.HashToken("private-device-test-token"), encrypted); err != nil {
		t.Fatal(err)
	}
	enqueue := func() string {
		t.Helper()
		id := uuid.NewString()
		if _, err := pool.Exec(ctx, `INSERT INTO notifications(id,profile_id,type,title,body,deep_link,dedupe_key) VALUES($1::uuid,$2,'SUBMISSION_APPROVED','Verified','See result','fitcalgary://notifications',$1::text)`, id, profile); err != nil {
			t.Fatal(err)
		}
		return id
	}
	sender := &testPushSender{result: notifications.Result{Code: "PROVIDER_RETRY", Retry: true}}
	process := func() {
		t.Helper()
		if _, err := processPush(ctx, pool, sender, cipher); err != nil {
			t.Fatal(err)
		}
	}
	id := enqueue()
	process()
	if sender.calls != 1 {
		t.Fatal("first push not attempted")
	}
	process()
	if sender.calls != 1 {
		t.Fatal("backoff ignored")
	}
	if _, err := pool.Exec(ctx, `UPDATE notification_deliveries SET available_at=now() WHERE notification_id=$1`, id); err != nil {
		t.Fatal(err)
	}
	sender.result = notifications.Result{MessageID: "provider/test"}
	process()
	process()
	if sender.calls != 2 {
		t.Fatal("delivered device duplicated")
	}
	var state string
	if err := pool.QueryRow(ctx, `SELECT delivery_status FROM notifications WHERE id=$1`, id).Scan(&state); err != nil || state != "DELIVERED" {
		t.Fatalf("push state incorrect %s %v", state, err)
	}
	enqueue()
	sender.result = notifications.Result{Code: "TOKEN_UNREGISTERED", InvalidToken: true}
	process()
	var enabled bool
	if err := pool.QueryRow(ctx, `SELECT enabled FROM notification_devices WHERE id=$1`, device).Scan(&enabled); err != nil || enabled {
		t.Fatal("invalid device not disabled")
	}
	t.Log("Push queue: encrypted device lookup, retry/backoff, successful-device deduplication and invalid-token disabling PASS against SQL with test provider")
}
