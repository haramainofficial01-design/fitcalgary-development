package httpapi

import (
	"bytes"
	"context"
	"encoding/json"
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

func TestContentPublicationDatabaseFlow(t *testing.T) {
	raw := os.Getenv("CONTENT_TEST_DATABASE_URL")
	if raw == "" {
		t.Skip("requires explicit local CONTENT_TEST_DATABASE_URL")
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
	server := NewServer(pool, directoryVerifier{uuid.NewString()}, nil, nil, config.Config{}, slog.New(slog.NewTextHandler(io.Discard, nil)))
	handler := server.Router()
	request := func(method, path, token string, body any, status int) map[string]any {
		t.Helper()
		encoded, err := json.Marshal(body)
		if err != nil {
			t.Fatal(err)
		}
		r := httptest.NewRequest(method, path, bytes.NewReader(encoded))
		r.Header.Set("Content-Type", "application/json")
		if token != "" {
			r.Header.Set("Authorization", "Bearer "+token)
		}
		w := httptest.NewRecorder()
		handler.ServeHTTP(w, r)
		if w.Code != status {
			t.Fatalf("%s %s: got %d wanted %d: %s", method, path, w.Code, status, w.Body.String())
		}
		data := map[string]any{}
		if w.Body.Len() > 0 {
			if err := json.Unmarshal(w.Body.Bytes(), &data); err != nil {
				t.Fatal(err)
			}
		}
		return data
	}
	var city string
	if err := pool.QueryRow(ctx, `SELECT id::text FROM cities WHERE slug='calgary'`).Scan(&city); err != nil {
		t.Fatal(err)
	}
	for _, kind := range []string{"clubs", "events"} {
		t.Run(kind, func(t *testing.T) {
			slug := "development-content-" + uuid.NewString()
			body := map[string]any{"cityId": city, "slug": slug, "name": "Development content " + slug, "sport": "Running", "category": "Community", "description": "Synthetic publication workflow, not Client-approved content."}
			if kind == "events" {
				body["startAt"] = time.Now().Add(24 * time.Hour).UTC().Format(time.RFC3339)
				body["endAt"] = time.Now().Add(26 * time.Hour).UTC().Format(time.RFC3339)
			}
			admin := "/api/v1/admin/" + kind
			public := "/api/v1/" + kind + "/" + slug
			request("POST", admin, "", body, 401)
			request("POST", admin, "first", body, 403)
			created := request("POST", admin, "admin", body, 201)
			id := created["id"].(string)
			request("GET", public, "", nil, 404)
			body["publishStatus"] = "PUBLISHED"
			request("PUT", admin+"/"+id, "first", body, 403)
			request("PUT", admin+"/"+id, "admin", body, 200)
			detail := request("GET", public, "", nil, 200)
			if detail["description"] != body["description"] {
				t.Fatal("published detail lost content")
			}
			request("GET", public+"?city=unknown", "", nil, 404)
			listPath := "/api/v1/" + kind + "?q=" + slug + "&sport=Running&category=Community"
			list := request("GET", listPath, "", nil, 200)
			if list["total"] != float64(1) || len(list["data"].([]any)) != 1 {
				t.Fatal("search/category/sport did not return published record")
			}
			empty := request("GET", listPath+"&page=99", "", nil, 200)
			if empty["total"] != float64(1) || len(empty["data"].([]any)) != 0 {
				t.Fatal("out-of-range pagination lost total")
			}
			if kind == "events" {
				if detail["phase"] != "UPCOMING" {
					t.Fatal("upcoming phase incorrect")
				}
				body["eventStatus"] = "CANCELLED"
				request("PUT", admin+"/"+id, "admin", body, 200)
				cancelled := request("GET", public, "", nil, 200)
				if cancelled["phase"] != "CANCELLED" {
					t.Fatal("cancellation must override date")
				}
				open := request("GET", listPath+"&open=true", "", nil, 200)
				if open["total"] != float64(0) {
					t.Fatal("cancelled event offered open registration")
				}
				body["eventStatus"] = "ACTIVE"
				body["startAt"] = time.Now().Add(-time.Hour).UTC().Format(time.RFC3339)
				body["endAt"] = time.Now().Add(time.Hour).UTC().Format(time.RFC3339)
				request("PUT", admin+"/"+id, "admin", body, 200)
				current := request("GET", listPath+"&phase=CURRENT", "", nil, 200)
				if current["total"] != float64(1) {
					t.Fatal("current phase missing")
				}
				body["endAt"] = time.Now().Add(-time.Minute).UTC().Format(time.RFC3339)
				request("PUT", admin+"/"+id, "admin", body, 200)
				past := request("GET", public, "", nil, 200)
				if past["phase"] != "COMPLETED" {
					t.Fatal("completed phase missing")
				}
				body["endAt"] = "not-a-date"
				request("PUT", admin+"/"+id, "admin", body, 422)
				body["endAt"] = time.Now().Add(-2 * time.Hour).UTC().Format(time.RFC3339)
				request("PUT", admin+"/"+id, "admin", body, 422)
				delete(body, "endAt")
				body["registrationDeadline"] = "not-a-date"
				request("PUT", admin+"/"+id, "admin", body, 422)
				delete(body, "registrationDeadline")
				body["imageUrl"] = "javascript:alert(1)"
				request("PUT", admin+"/"+id, "admin", body, 422)
				delete(body, "imageUrl")
				request("GET", listPath+"&month=2026-99", "", nil, 422)
				request("GET", listPath+"&phase=invalid", "", nil, 422)
			} else {
				body["websiteUrl"] = "javascript:alert(1)"
				request("PUT", admin+"/"+id, "admin", body, 422)
				body["websiteUrl"] = "https://fixtures.example.invalid/club"
				body["seasonInformation"] = "Development season"
				request("PUT", admin+"/"+id, "admin", body, 200)
			}
			body["publishStatus"] = "DRAFT"
			request("PUT", admin+"/"+id, "admin", body, 200)
			request("GET", public, "", nil, 404)
			body["publishStatus"] = "ARCHIVED"
			request("PUT", admin+"/"+id, "admin", body, 200)
			request("GET", public, "", nil, 404)
			var auditCount int
			if err := pool.QueryRow(ctx, `SELECT count(*) FROM audit_logs WHERE entity_id=$1`, id).Scan(&auditCount); err != nil || auditCount < 4 {
				t.Fatal("missing committed content audit history")
			}
			request("PUT", admin+"/"+uuid.NewString(), "admin", body, 404)
			request("GET", admin, "first", nil, 403)
			request("GET", admin, "admin", nil, 200)
		})
	}
	// Force an audit foreign-key failure using a nonexistent actor. The content
	// insertion must roll back instead of succeeding without its required history.
	rollbackSlug := "development-rollback-" + uuid.NewString()
	encoded, _ := json.Marshal(map[string]any{"cityId": city, "slug": rollbackSlug, "name": "Development rollback test", "sport": "Running"})
	r := httptest.NewRequest("POST", "/api/v1/admin/clubs", bytes.NewReader(encoded))
	r = r.WithContext(context.WithValue(ctx, identityKey, requestIdentity{ProfileID: uuid.NewString(), Principal: auth.Principal{Roles: []auth.Role{auth.RoleAdmin}}}))
	if _, err := server.saveClub(httptest.NewRecorder(), r, false); err == nil {
		t.Fatal("expected audit foreign-key failure")
	}
	var count int
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM clubs WHERE slug=$1`, rollbackSlug).Scan(&count); err != nil || count != 0 {
		t.Fatal("content persisted despite audit failure")
	}
	t.Log("Club/event create, publish, detail, search, update, unpublish/archive, event phase, validation, roles, audit persistence and atomic rollback passed against PostgreSQL")
}

func TestSafeContentLinks(t *testing.T) {
	for _, tc := range []struct {
		value string
		valid bool
	}{{"https://example.invalid/path", true}, {"http://example.invalid", true}, {"javascript:alert(1)", false}, {"https://user:password@example.invalid", false}, {"//example.invalid", false}, {"https://", false}} {
		if safeContentURL(&tc.value) != tc.valid {
			t.Errorf("link validation mismatch for %q", tc.value)
		}
	}
}
