package httpapi

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fitcalgary.ca/index/api/internal/auth"
	"fitcalgary.ca/index/api/internal/config"
	"fitcalgary.ca/index/api/internal/storage"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"strings"
	"testing"
	"time"
)

// Storage is deliberately mocked here; these tests prove API/SQL authorization
// and transactions, not an external object-storage deployment.
type workflowStore struct{}

func (workflowStore) Begin(_ context.Context, _, id, _ string, _ int64) (string, string, error) {
	return id, uuid.NewString(), nil
}
func (workflowStore) SignPart(context.Context, string, string, int32) (string, error) {
	return "https://storage.example.invalid/part", nil
}
func (workflowStore) Complete(context.Context, string, string, []storage.CompletedPart) (int64, error) {
	return 100, nil
}
func (workflowStore) PlaybackURL(context.Context, string) (string, error) {
	return "https://storage.example.invalid/private", nil
}
func (workflowStore) Delete(context.Context, string) error { return nil }

type workflowVerifier struct{ prefix string }

func (v workflowVerifier) Verify(_ context.Context, token string) (auth.Principal, error) {
	// Model new provider tokens retaining the same subject and stale role claim.
	// This tests application authorization, not the provider's token exchange.
	if token == "judge-refreshed" || token == "judge-relogin" {
		token = "judge"
	}
	roles := []auth.Role{auth.RoleUser}
	switch token {
	case "athlete", "other":
	case "judge":
		roles = append(roles, auth.RoleJudge)
	case "moderator":
		roles = append(roles, auth.RoleModerator)
	case "trainer":
		roles = append(roles, auth.RolePersonalTrainer)
	case "admin":
		roles = append(roles, auth.RoleAdmin)
	default:
		return auth.Principal{}, errors.New("invalid")
	}
	return auth.Principal{Subject: v.prefix + token, Username: "Development " + token, EmailVerified: true, Roles: roles}, nil
}
func TestCompetitionDatabaseWorkflow(t *testing.T) {
	raw := os.Getenv("DIRECTORY_TEST_DATABASE_URL")
	if raw == "" {
		t.Skip("requires seeded loopback test database")
	}
	cfg, err := pgxpool.ParseConfig(raw)
	if err != nil || cfg.ConnConfig.Host != "127.0.0.1" || !strings.HasSuffix(cfg.ConnConfig.Database, "_test") {
		t.Fatal("requires disposable local test database")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 40*time.Second)
	defer cancel()
	pool, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		t.Fatal(err)
	}
	defer pool.Close()
	var marker bool
	if err = pool.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM app_settings WHERE key='development_fixture_batch')`).Scan(&marker); err != nil || !marker {
		t.Fatal("development marker required")
	}
	var logs strings.Builder
	var evidenceStore storage.EvidenceStore = workflowStore{}
	realStorage := os.Getenv("STORAGE_TEST_ENDPOINT") != ""
	if realStorage {
		endpoint, parseErr := url.Parse(os.Getenv("STORAGE_TEST_ENDPOINT"))
		if parseErr != nil || endpoint.Hostname() != "127.0.0.1" {
			t.Fatal("loopback evidence storage required")
		}
		evidenceStore, err = storage.NewS3EvidenceStore(ctx, config.Config{S3Endpoint: endpoint.String(), S3Region: "us-east-1", S3Bucket: "fitcalgary-evidence-test", S3AccessKeyID: os.Getenv("STORAGE_TEST_ACCESS_KEY"), S3SecretAccessKey: os.Getenv("STORAGE_TEST_SECRET_KEY"), SignedURLTTL: time.Minute, MaxEvidenceBytes: 1024})
		if err != nil {
			t.Fatal(err)
		}
	}
	router := NewServer(pool, workflowVerifier{uuid.NewString()}, evidenceStore, nil, config.Config{MaxEvidenceBytes: 1024, EvidenceRetentionDays: 14, SignedURLTTL: time.Minute}, slog.New(slog.NewTextHandler(&logs, nil))).Router()
	request := func(method, path, token string, body any, status int) map[string]any {
		t.Helper()
		raw, _ := json.Marshal(body)
		r := httptest.NewRequest(method, "/api/v1"+path, strings.NewReader(string(raw)))
		if token != "" {
			r.Header.Set("Authorization", "Bearer "+token)
		}
		w := httptest.NewRecorder()
		router.ServeHTTP(w, r)
		if w.Code != status {
			t.Fatalf("%s %s: wanted %d got %d: %s\n%s", method, path, status, w.Code, w.Body.String(), logs.String())
		}
		result := map[string]any{}
		if w.Body.Len() > 0 {
			if err = json.Unmarshal(w.Body.Bytes(), &result); err != nil {
				t.Fatal(err)
			}
		}
		return result
	}
	city := request("GET", "/cities", "", nil, 200)["data"].([]any)[0].(map[string]any)["id"]
	judgeID := request("GET", "/profile", "judge", nil, 200)["id"].(string)
	rolePath := "/admin/users/" + judgeID + "/roles/JUDGE"
	request("DELETE", rolePath, "athlete", nil, 403)
	request("DELETE", rolePath, "admin", nil, 204)
	assertJudge := func(token string, allowed bool) {
		t.Helper()
		status := 403
		if allowed {
			status = 200
		}
		request("GET", "/judge/queue", token, nil, status)
		for _, path := range []string{"/profile", "/auth/context"} {
			response := request("GET", path, token, nil, 200)
			found := false
			for _, role := range response["roles"].([]any) {
				if role == "JUDGE" {
					found = true
				}
			}
			if found != allowed {
				t.Fatalf("%s %s: inconsistent effective roles: %v", token, path, response["roles"])
			}
		}
	}
	for _, token := range []string{"judge", "judge-refreshed", "judge-relogin"} {
		assertJudge(token, false)
		request("PUT", rolePath, token, nil, 403)
		request("DELETE", rolePath, token, nil, 403)
		request("PATCH", "/profile", token, map[string]any{"roles": []string{"ADMIN", "JUDGE"}}, 422)
		assertJudge(token, false)
	}
	request("PUT", rolePath, "admin", nil, 204)
	for _, token := range []string{"judge", "judge-refreshed", "judge-relogin"} {
		assertJudge(token, true)
	}
	// A subsequent revocation must also override the newly stored local grant.
	request("DELETE", rolePath, "admin", nil, 204)
	assertJudge("judge-relogin", false)
	request("PUT", rolePath, "admin", nil, 204)
	assertJudge("judge", true)
	athleteID := request("GET", "/profile", "athlete", nil, 200)["id"].(string)
	request("PUT", "/admin/users/"+athleteID+"/roles/ADMIN", "athlete", nil, 403)
	request("PATCH", "/profile", "athlete", map[string]any{"roles": []string{"ADMIN"}}, 422)
	request("GET", "/admin/users", "athlete", nil, 403)
	request("DELETE", "/admin/users/"+judgeID+"/roles/USER", "admin", nil, 422)
	for _, token := range []string{"athlete", "other", "judge"} {
		request("PATCH", "/profile", token, map[string]any{"cityId": city, "dateOfBirth": "1992-08-31", "sexCategory": "WOMEN"}, 200)
	}
	profile := request("GET", "/profile", "athlete", nil, 200)
	preferences := map[string]any{"notificationPreferences": map[string]bool{"eventUpdates": false}}
	request("PATCH", "/profile", "athlete", preferences, 200)
	updated := request("GET", "/profile", "athlete", nil, 200)["notification_preferences"].(map[string]any)
	if updated["eventUpdates"] != false || updated["announcements"] != true {
		t.Fatal("notification preference merge failed")
	}
	request("PATCH", "/profile", "athlete", map[string]any{"notificationPreferences": map[string]bool{"unknown": false}}, 422)
	var notificationID string
	if err := pool.QueryRow(ctx, `INSERT INTO notifications(profile_id,type,title,body,deep_link,dedupe_key) VALUES($1,'SUBMISSION_RECEIVED','Development notice','Owner isolation test','fitcalgary://notifications',$2) RETURNING id`, profile["id"], uuid.NewString()).Scan(&notificationID); err != nil {
		t.Fatal(err)
	}
	request("PUT", "/notifications/"+notificationID+"/opened", "", nil, 401)
	request("PUT", "/notifications/"+notificationID+"/opened", "other", nil, 404)
	request("PUT", "/notifications/"+notificationID+"/opened", "athlete", nil, 204)
	request("PUT", "/notifications/"+notificationID+"/opened", "athlete", nil, 204)
	var opened bool
	if err := pool.QueryRow(ctx, `SELECT opened_at IS NOT NULL FROM notifications WHERE id=$1`, notificationID).Scan(&opened); err != nil || !opened {
		t.Fatal("notification read state did not persist")
	}
	// Configuration is created through the actual admin API, not direct SQL.
	disciplineBody := map[string]any{"slug": "workflow-" + uuid.NewString(), "displayName": "Development competition test", "metricType": "REPETITIONS", "unit": "reps", "rankingDirection": "HIGHER_IS_BETTER", "evidenceType": "VIDEO", "officialEligible": true, "communityEligible": true, "active": true, "verificationChecklist": []any{map[string]string{"key": "form", "label": "Full form visible"}}}
	request("POST", "/admin/disciplines", "athlete", disciplineBody, 403)
	discipline := request("POST", "/admin/disciplines", "admin", disciplineBody, 201)["id"].(string)
	request("POST", "/admin/disciplines", "admin", disciplineBody, 409)
	request("PUT", "/admin/disciplines/"+discipline, "admin", disciplineBody, 200)
	for key := range administrativeQueries {
		request("GET", "/admin/"+key, "athlete", nil, 403)
		request("GET", "/admin/"+key, "admin", nil, 200)
	}
	divisionBody := map[string]any{"slug": "test-women-" + uuid.NewString(), "displayLabel": "Development women open", "minimumInclusive": true, "maximumInclusive": true, "open": true, "sexCategory": "WOMEN", "active": true}
	division := request("POST", "/admin/divisions", "admin", divisionBody, 201)["id"].(string)
	request("PUT", "/admin/divisions/"+division, "admin", divisionBody, 200)
	reference := request("GET", "/admin/reference-data", "admin", nil, 200)
	region := reference["regions"].([]any)[0].(map[string]any)["id"]
	boardBody := map[string]any{"regionId": region, "disciplineId": discipline, "divisionId": division, "boardType": "OFFICIAL", "visible": false}
	unpublished := request("POST", "/admin/leaderboards", "admin", boardBody, 201)["id"].(string)
	request("GET", "/leaderboards/"+unpublished, "", nil, 404)
	boardBody["visible"] = true
	request("PUT", "/admin/leaderboards/"+unpublished, "admin", boardBody, 200)
	request("GET", "/leaderboards/"+unpublished, "", nil, 200)
	request("PUT", "/admin/divisions/"+division, "admin", divisionBody, 409)
	body := func(metric float64) map[string]any {
		return map[string]any{"disciplineId": discipline, "claimedMetric": metric, "evidenceType": "VIDEO", "checklistAcceptance": map[string]bool{"form": true}}
	}
	request("POST", "/submissions", "athlete", body(2.5), 422)
	missing := body(20)
	missing["checklistAcceptance"] = map[string]bool{}
	request("POST", "/submissions", "athlete", missing, 422)
	request("POST", "/submissions", "", body(20), 401)
	first := request("POST", "/submissions", "athlete", body(20), 201)["id"].(string)
	request("PUT", "/admin/disciplines/"+discipline, "admin", disciplineBody, 409)
	request("GET", "/submissions/"+first, "other", nil, 404)
	request("GET", "/judge/queue", "athlete", nil, 403)
	request("POST", "/submissions/"+first+"/uploads", "other", map[string]any{"contentType": "video/mp4", "sizeBytes": 100}, 404)
	upload := func(id, token string) {
		t.Helper()
		u := request("POST", "/submissions/"+id+"/uploads", token, map[string]any{"contentType": "video/mp4", "sizeBytes": 100}, 201)["id"].(string)
		intruder := "other"
		if token == "other" {
			intruder = "athlete"
		}
		request("POST", "/uploads/"+u+"/parts/1", intruder, nil, 404)
		partURL := request("POST", "/uploads/"+u+"/parts/1", token, nil, 200)["url"].(string)
		etag := "part"
		if realStorage {
			req, _ := http.NewRequestWithContext(ctx, http.MethodPut, partURL, bytes.NewReader(bytes.Repeat([]byte{42}, 100)))
			response, uploadErr := http.DefaultClient.Do(req)
			if uploadErr != nil {
				t.Fatal("real signed upload failed")
			}
			io.Copy(io.Discard, response.Body)
			response.Body.Close()
			if response.StatusCode != 200 {
				t.Fatalf("real upload status %d", response.StatusCode)
			}
			etag = response.Header.Get("ETag")
		}
		request("POST", "/uploads/"+u+"/finalize", token, map[string]any{"parts": []any{map[string]any{"ETag": "part", "PartNumber": 2}}}, 422)
		parts := map[string]any{"parts": []any{map[string]any{"ETag": etag, "PartNumber": 1}}}
		if request("POST", "/uploads/"+u+"/finalize", token, parts, 200)["status"] != "PENDING_REVIEW" {
			t.Fatal("finalization returned stale state")
		}
		request("POST", "/uploads/"+u+"/finalize", token, parts, 200)
	}
	upload(first, "athlete")
	approval := map[string]any{"decision": "APPROVED", "checklistResponses": map[string]bool{"form": true}}
	request("POST", "/judge/submissions/"+first+"/decision", "athlete", approval, 403)
	request("POST", "/judge/submissions/"+first+"/decision", "judge", map[string]any{"decision": "APPROVED"}, 422)
	request("GET", "/judge/submissions/"+first+"/evidence", "other", nil, 403)
	playback := request("GET", "/judge/submissions/"+first+"/evidence", "judge", nil, 200)
	if realStorage {
		response, fetchErr := http.Get(playback["url"].(string))
		if fetchErr != nil {
			t.Fatal("judge playback unavailable")
		}
		data, readErr := io.ReadAll(response.Body)
		response.Body.Close()
		if readErr != nil || response.StatusCode != 200 || !bytes.Equal(data, bytes.Repeat([]byte{42}, 100)) {
			t.Fatal("judge playback did not return uploaded bytes")
		}
	}
	request("POST", "/judge/submissions/"+first+"/decision", "judge", approval, 200)
	request("POST", "/judge/submissions/"+first+"/decision", "judge", approval, 409)
	detail := request("GET", "/submissions/"+first, "athlete", nil, 200)
	result := detail["result"].(map[string]any)
	board := result["leaderboardId"].(string)
	if result["verificationType"] != "VIDEO_REVIEWED" {
		t.Fatal("approval not verified")
	}
	entries := func(id string) []any {
		t.Helper()
		return request("GET", "/leaderboards/"+id, "", nil, 200)["entries"].([]any)
	}
	if len(entries(board)) != 1 {
		t.Fatal("duplicate approval published multiple results")
	}
	// A weaker repeat must not claim a second leaderboard place.
	repeat := request("POST", "/submissions", "athlete", body(10), 201)["id"].(string)
	upload(repeat, "athlete")
	request("POST", "/judge/submissions/"+repeat+"/decision", "judge", approval, 200)
	if list := entries(board); len(list) != 1 || list[0].(map[string]any)["display_metric"] != "20 reps" {
		t.Fatal("personal best ranking lost")
	}
	// A second athlete overtakes, using a separately owned submission.
	second := request("POST", "/submissions", "other", body(30), 201)["id"].(string)
	upload(second, "other")
	request("POST", "/judge/submissions/"+second+"/decision", "judge", approval, 200)
	if list := entries(board); len(list) != 2 || list[0].(map[string]any)["display_metric"] != "30 reps" {
		t.Fatal("higher-is-better ranking failed")
	}
	request("PATCH", "/profile", "other", map[string]any{"privacy": map[string]bool{"publicProfile": false, "showGym": false}}, 200)
	private := entries(board)[0].(map[string]any)
	if private["display_name"] != "Private athlete" || private["profile_id"] != nil || private["gym_name"] != nil || private["rank"] != float64(1) {
		t.Fatal("privacy or rank consistency failed")
	}
	// Self-reported community results cannot pollute an official board.
	claim := request("POST", "/results/community", "athlete", map[string]any{"disciplineId": discipline, "metric": 99}, 201)
	if claim["verification_type"] != "UNVERIFIED" || len(entries(board)) != 2 {
		t.Fatal("community claim changed official board")
	}
	if len(entries(claim["leaderboard_id"].(string))) != 1 {
		t.Fatal("community claim not ranked")
	}
	// Changes preserve judge comments and require owner-only, one-child corrections.
	correctionSource := request("POST", "/submissions", "athlete", body(40), 201)["id"].(string)
	upload(correctionSource, "athlete")
	request("POST", "/judge/submissions/"+correctionSource+"/decision", "judge", map[string]any{"decision": "RESUBMISSION_REQUESTED", "comments": "Please show the full range."}, 200)
	correction := body(40)
	correction["parentSubmissionId"] = correctionSource
	request("POST", "/submissions", "other", correction, 403)
	child := request("POST", "/submissions", "athlete", correction, 201)["id"].(string)
	request("POST", "/submissions", "athlete", correction, 409)
	request("POST", "/submissions/"+child+"/cancel", "athlete", nil, 200)
	request("POST", "/submissions/"+child+"/uploads", "athlete", map[string]any{"contentType": "video/mp4", "sizeBytes": 100}, 409)
	request("POST", "/submissions", "athlete", correction, 201)
	// Lower elapsed time wins; ties retain a deterministic earlier-performance order.
	timeBody := map[string]any{"slug": "workflow-time-" + uuid.NewString(), "displayName": "Development time test", "metricType": "TIME", "unit": "seconds", "rankingDirection": "LOWER_IS_BETTER", "evidenceType": "ACTIVITY_OR_OFFICIAL", "active": true, "communityEligible": true, "officialEligible": true}
	timed := request("POST", "/admin/disciplines", "admin", timeBody, 201)["id"].(string)
	claimTime := func(token string, metric float64) string {
		return request("POST", "/results/community", token, map[string]any{"disciplineId": timed, "metric": metric}, 201)["leaderboard_id"].(string)
	}
	timeBoard := claimTime("athlete", 1000)
	claimTime("other", 900)
	claimTime("athlete", 900)
	rankedTimes := entries(timeBoard)
	if len(rankedTimes) != 2 || rankedTimes[0].(map[string]any)["display_name"] != "Private athlete" || rankedTimes[0].(map[string]any)["display_metric"] != "15:00" {
		t.Fatal("time direction, best performance or tie order failed")
	}
	var decisions, notifications int
	if err = pool.QueryRow(ctx, `SELECT count(*) FROM submission_reviews WHERE submission_id=$1`, first).Scan(&decisions); err != nil || decisions != 1 {
		t.Fatal("duplicate review committed")
	}
	if err = pool.QueryRow(ctx, `SELECT count(*) FROM outbox_jobs WHERE payload->>'leaderboardId'=$1 AND payload->>'type'='LEADERBOARD_PASSED'`, board).Scan(&notifications); err != nil || notifications != 1 {
		t.Fatal("rank movement notification missing or duplicated")
	}
	moderationPath := "/admin/users/" + judgeID + "/moderation"
	announcement := map[string]any{"requestId": uuid.NewString(), "profileIds": []string{judgeID}, "title": "Review update", "body": "Check the review queue."}
	for _, token := range []string{"athlete", "judge", "moderator", "trainer"} {
		request("POST", "/admin/announcements", token, announcement, 403)
	}
	request("POST", "/admin/announcements", "", announcement, 401)
	if request("POST", "/admin/announcements", "admin", announcement, 200)["queued"] != float64(1) {
		t.Fatal("announcement not queued")
	}
	if request("POST", "/admin/announcements", "admin", announcement, 200)["queued"] != float64(0) {
		t.Fatal("announcement retry duplicated delivery")
	}
	announcement["eventId"] = uuid.NewString()
	request("POST", "/admin/announcements", "admin", announcement, 422)
	note := map[string]any{"action": "NOTE", "reason": "Check account behavior."}
	for _, token := range []string{"athlete", "judge", "trainer"} {
		request("POST", moderationPath, token, note, 403)
	}
	request("POST", moderationPath, "", note, 401)
	request("POST", moderationPath, "moderator", note, 200)
	request("POST", moderationPath, "moderator", map[string]any{"action": "SUSPEND", "reason": "Check account behavior."}, 403)
	adminID := request("GET", "/profile", "admin", nil, 200)["id"].(string)
	request("POST", "/admin/users/"+adminID+"/moderation", "admin", map[string]any{"action": "BAN", "reason": "Self-ban not permitted."}, 409)
	request("POST", moderationPath, "admin", map[string]any{"action": "SUSPEND", "reason": ""}, 422)
	for _, action := range []string{"SUSPEND", "BAN"} {
		request("POST", moderationPath, "admin", map[string]any{"action": action, "reason": "Regression moderation check."}, 200)
		for _, token := range []string{"judge", "judge-refreshed", "judge-relogin"} {
			request("GET", "/profile", token, nil, 403)
			request("GET", "/judge/queue", token, nil, 403)
		}
		request("POST", moderationPath, "admin", map[string]any{"action": "RESTORE", "reason": "Restriction review completed."}, 200)
		assertJudge("judge", true)
	}
	var actions, audits int
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM moderation_actions WHERE target_profile_id=$1`, judgeID).Scan(&actions); err != nil || actions != 5 {
		t.Fatalf("moderation history missing: %d %v", actions, err)
	}
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM audit_logs WHERE entity_id=$1 AND action LIKE 'ACCOUNT_%'`, judgeID).Scan(&audits); err != nil || audits != 5 {
		t.Fatalf("moderation audit missing: %d %v", audits, err)
	}
	if _, err := pool.Exec(ctx, `INSERT INTO api_request_limits(profile_id,bucket,window_start,requests) VALUES($1,'submissions',date_trunc('minute',now()),40) ON CONFLICT(profile_id,bucket,window_start) DO UPDATE SET requests=40`, athleteID); err != nil {
		t.Fatal(err)
	}
	request("POST", "/submissions", "athlete", map[string]any{}, 429)
	request("GET", "/profile", "athlete", nil, 200)
	if _, err := pool.Exec(ctx, `DELETE FROM api_request_limits WHERE profile_id=$1 AND bucket='submissions'`, athleteID); err != nil {
		t.Fatal(err)
	}
	request("POST", "/submissions", "athlete", map[string]any{}, 422)
	var metrics int
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM product_metrics WHERE event_name='BOARD_VIEW' AND occurrences>0`).Scan(&metrics); err != nil || metrics == 0 {
		t.Fatal("successful product activity was not counted")
	}
	t.Logf("Verified creation, private evidence permissions, review validation, repeat approval protection, official/community separation, best-result ranking, privacy, resubmission, moderation and complete role boundaries against PostgreSQL; real storage: %t", realStorage)
}
