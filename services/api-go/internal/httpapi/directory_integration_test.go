package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"

	"fitcalgary.ca/index/api/internal/auth"
	"fitcalgary.ca/index/api/internal/config"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type directoryVerifier struct{ prefix string }

func (v directoryVerifier) Verify(_ context.Context, token string) (auth.Principal, error) {
	if token != "first" && token != "second" && token != "admin" {
		return auth.Principal{}, errors.New("invalid test identity")
	}
	roles := []auth.Role{auth.RoleUser}
	if token == "admin" {
		roles = append(roles, auth.RoleAdmin)
	}
	return auth.Principal{Subject: v.prefix + token, Username: "Development test user", EmailVerified: true, Roles: roles}, nil
}

func TestDirectoryAccountDatabaseFlow(t *testing.T) {
	raw := os.Getenv("DIRECTORY_TEST_DATABASE_URL")
	if raw == "" {
		t.Skip("requires explicitly seeded local DIRECTORY_TEST_DATABASE_URL")
	}
	cfg, err := pgxpool.ParseConfig(raw)
	if err != nil || cfg.ConnConfig.Host != "127.0.0.1" || !strings.HasSuffix(cfg.ConnConfig.Database, "_test") {
		t.Fatal("requires loopback disposable _test database")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	pool, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		t.Fatal(err)
	}
	defer pool.Close()
	var marker bool
	if err := pool.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM app_settings WHERE key='development_fixture_batch')`).Scan(&marker); err != nil || !marker {
		t.Fatal("requires development fixture marker")
	}
	handler := NewServer(pool, directoryVerifier{uuid.NewString()}, nil, nil, config.Config{}, slog.New(slog.NewTextHandler(io.Discard, nil))).Router()
	request := func(method, path, token, body string, status int) map[string]any {
		t.Helper()
		r := httptest.NewRequest(method, path, strings.NewReader(body))
		if token != "" {
			r.Header.Set("Authorization", "Bearer "+token)
		}
		r.Header.Set("Content-Type", "application/json")
		w := httptest.NewRecorder()
		handler.ServeHTTP(w, r)
		if w.Code != status {
			t.Fatalf("%s %s status %d wanted %d: %s", method, path, w.Code, status, w.Body.String())
		}
		result := map[string]any{}
		if w.Body.Len() > 0 {
			if err := json.Unmarshal(w.Body.Bytes(), &result); err != nil {
				t.Fatal(err)
			}
		}
		return result
	}
	for _, tc := range []struct {
		query string
		count int
	}{
		{"?q=Biweekly", 1}, {"?category=BUDGET", 1}, {"?area=Test+South", 1}, {"?amenity=POOL", 1},
		{"?pricing=complete", 1}, {"?pricing=incomplete", 1}, {"?maxMonthlyCents=2600", 1}, {"?q=no-such-gym", 0},
	} {
		data := request("GET", "/api/v1/gyms"+tc.query, "", "", 200)["data"].([]any)
		if len(data) != tc.count {
			t.Fatalf("filter %s: %d results", tc.query, len(data))
		}
	}
	for _, q := range []string{"?sort=invalid", "?pricing=invalid", "?maxMonthlyCents=-1", "?page=0", "?pageSize=101", "?q=" + strings.Repeat("x", 121)} {
		request("GET", "/api/v1/gyms"+q, "", "", 422)
	}
	first := request("GET", "/api/v1/gyms?sort=cost&pageSize=1", "", "", 200)
	second := request("GET", "/api/v1/gyms?sort=cost&pageSize=1&page=2", "", "", 200)
	if first["total"] != float64(2) || second["total"] != float64(2) {
		t.Fatal("pagination lost total")
	}
	a := first["data"].([]any)[0].(map[string]any)
	b := second["data"].([]any)[0].(map[string]any)
	if a["slug"] != "development-monthly-gym" || b["slug"] != "development-biweekly-gym" {
		t.Fatal("incorrect price ordering")
	}
	detail := request("GET", "/api/v1/gyms/development-biweekly-gym", "", "", 200)
	if len(detail["pricing"].([]any)) != 2 {
		t.Fatal("missing membership plans")
	}
	request("GET", "/api/v1/gyms/development-monthly-gym?city=unknown", "", "", 404)
	request("GET", "/api/v1/profile", "", "", 401)
	request("GET", "/api/v1/admin/overview", "first", "", 403)
	profile := request("GET", "/api/v1/profile", "first", "", 200)
	request("PATCH", "/api/v1/profile", "first", `{"displayName":"Development Updated Athlete","bio":"Development profile persistence test"}`, 200)
	updated := request("GET", "/api/v1/profile", "first", "", 200)
	if updated["id"] != profile["id"] || updated["display_name"] != "Development Updated Athlete" {
		t.Fatal("profile did not persist")
	}
	request("GET", "/api/v1/profile/performance", "", "", 401)
	var boardID string
	if err := pool.QueryRow(ctx, `INSERT INTO leaderboards(region_id,discipline_id,division_id,board_type)
SELECT r.id,d.id,v.id,'OFFICIAL' FROM regions r,disciplines d,divisions v
WHERE r.slug='calgary-region' AND d.slug='5k-run' AND v.slug='open-all' LIMIT 1 RETURNING id`).Scan(&boardID); err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(ctx, `INSERT INTO results(profile_id,leaderboard_id,normalized_metric,display_metric,verification_type,verified_at,verified_by,division_snapshot,profile_snapshot,discipline_rules_version)
VALUES($1,$2,1185,'19:45','IN_PERSON',now(),$1,'{"label":"Open"}'::jsonb,'{"displayName":"Development Updated Athlete"}'::jsonb,1)`, profile["id"], boardID); err != nil {
		t.Fatal(err)
	}
	performance := request("GET", "/api/v1/profile/performance", "first", "", 200)
	results := performance["results"].([]any)
	personalBests := performance["personalBests"].([]any)
	if len(results) != 1 || len(personalBests) != 1 {
		t.Fatal("profile performance did not return the athlete result and personal best")
	}
	entry := results[0].(map[string]any)
	if entry["board_type"] != "OFFICIAL" || entry["rank"] != float64(1) || entry["display_metric"] != "19:45" {
		t.Fatalf("unexpected profile performance: %#v", entry)
	}
	if len(request("GET", "/api/v1/profile/performance", "second", "", 200)["results"].([]any)) != 0 {
		t.Fatal("another athlete's performance leaked into the profile")
	}
	request("PATCH", "/api/v1/profile", "first", `{"homeGymId":"`+a["id"].(string)+`","dateOfBirth":"1992-08-31","sexCategory":"WOMEN","privacy":{"publicProfile":true,"showGym":true}}`, 200)
	affiliated := request("GET", "/api/v1/profile", "first", "", 200)
	if affiliated["home_gym_name"] != a["name"] || affiliated["sex_category"] != "WOMEN" || affiliated["date_of_birth"] != "1992-08-31T00:00:00Z" {
		t.Fatalf("athlete eligibility or gym affiliation did not persist: %#v", affiliated)
	}
	request("PATCH", "/api/v1/profile", "first", `{"homeGymId":"`+uuid.NewString()+`"}`, 422)
	request("PATCH", "/api/v1/profile", "first", `{"roles":["ADMIN"]}`, 422)
	path := "/api/v1/saved-gyms/" + a["id"].(string)
	request("PUT", path, "", "", 401)
	request("PUT", path, "first", "", 204)
	request("PUT", path, "first", "", 204)
	if len(request("GET", "/api/v1/saved-gyms", "first", "", 200)["data"].([]any)) != 1 {
		t.Fatal("saved gym missing or duplicated")
	}
	if len(request("GET", "/api/v1/saved-gyms", "second", "", 200)["data"].([]any)) != 0 {
		t.Fatal("saved gym leaked to another account")
	}
	request("DELETE", path, "second", "", 204)
	if len(request("GET", "/api/v1/saved-gyms", "first", "", 200)["data"].([]any)) != 1 {
		t.Fatal("another account removed saved gym")
	}
	request("PUT", "/api/v1/saved-gyms/"+uuid.NewString(), "first", "", 404)
	request("DELETE", path, "first", "", 204)
	if len(request("GET", "/api/v1/saved-gyms", "first", "", 200)["data"].([]any)) != 0 {
		t.Fatal("unsave failed")
	}
	pricingPath := "/api/v1/admin/gyms/" + a["id"].(string) + "/pricing"
	pricingBody := `{"planName":"Development future student plan","recurringCents":1000,"billingFrequency":"MONTHLY","pricingComplete":true,"effectiveFrom":"2099-01-01","effectiveTo":"2099-12-31","membershipType":"Student","contractMonths":12,"eligibility":"Test student eligibility","dropInCents":1500,"trialDetails":"Test trial terms","notes":"Development only"}`
	request("POST", pricingPath, "first", pricingBody, 403)
	plan := request("POST", pricingPath, "admin", pricingBody, 201)
	if plan["membership_type"] != "Student" || plan["contract_months"] != float64(12) {
		t.Fatal("membership terms did not persist")
	}
	current := request("GET", "/api/v1/gyms/development-monthly-gym", "", "", 200)
	if len(current["pricing"].([]any)) != 1 {
		t.Fatal("future plan leaked into current pricing")
	}
	request("POST", pricingPath, "admin", strings.Replace(pricingBody, `"contractMonths":12`, `"contractMonths":-1`, 1), 422)
	t.Log("Directory filters/detail, account and private favourites, membership terms, effective dates and permissions verified against PostgreSQL")
}
